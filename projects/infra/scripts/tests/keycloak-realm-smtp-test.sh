#!/usr/bin/env bash

set -Eeuo pipefail

REPOSITORY_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
RECONCILER="$REPOSITORY_ROOT/infra/keycloak/bootstrap/reconcile-realm-smtp.sh"
VALIDATOR="$REPOSITORY_ROOT/infra/keycloak/bootstrap/validate-keycloak-runtime-json.sh"
FIXTURE_ROOT="$(mktemp -d)"
FAKE_KCADM="$FIXTURE_ROOT/kcadm.sh"
KCADM_CONFIG="$FIXTURE_ROOT/kcadm.config"
KCADM_LOG="$FIXTURE_ROOT/kcadm.log"

cleanup() {
    rm -rf -- "$FIXTURE_ROOT"
}
trap cleanup EXIT

fail() {
    echo "FAIL: $*" >&2
    exit 1
}

cat > "$FAKE_KCADM" <<'EOF'
#!/bin/sh
set -eu

printf '%s\n' "$*" >> "${SMTP_TEST_KCADM_LOG:?}"
operation="${1:-}"
resource="${2:-}"
realm_name="${resource#realms/}"
state_file="${SMTP_TEST_STATE_ROOT:?}/$realm_name.json"
case "$operation" in
    get)
        [ -f "$state_file" ] || exit 91
        fields_filter=""
        previous_argument=""
        for argument in "$@"; do
            if [ "$previous_argument" = --fields ]; then
                fields_filter="$argument"
            fi
            previous_argument="$argument"
        done
        if [ "$fields_filter" = 'resetPasswordAllowed,smtpServer(*)' ]; then
            cat "$state_file"
        else
            # Match kcadm's real projection semantics: selecting an object
            # without a child pattern returns the object without its children.
            printf '%s\n' '{"resetPasswordAllowed":true,"smtpServer":{}}'
        fi
        ;;
    update)
        payload_file=""
        previous_argument=""
        for argument in "$@"; do
            if [ "$previous_argument" = -f ]; then
                payload_file="$argument"
            fi
            previous_argument="$argument"
        done
        [ -n "$payload_file" ] && [ -f "$payload_file" ] || exit 92
        cp "$payload_file" "$state_file"
        ;;
    *) exit 93 ;;
esac
EOF
chmod 700 "$FAKE_KCADM"
printf '{}\n' > "$KCADM_CONFIG"
: > "$KCADM_LOG"

write_mailpit_state() {
    realm_name="$1"
    cat > "$FIXTURE_ROOT/$realm_name.json" <<'EOF'
{"resetPasswordAllowed":true,"smtpServer":{"host":"mailpit","port":"1025","from":"no-reply@agentefiscal.local","fromDisplayName":"Contador Fiscal","replyTo":"suporte@agentefiscal.local","replyToDisplayName":"Contador Fiscal","auth":"false","starttls":"false","ssl":"false","user":"","password":""}}
EOF
}

run_dev() {
    SMTP_TEST_KCADM_LOG="$KCADM_LOG" \
    SMTP_TEST_STATE_ROOT="$FIXTURE_ROOT" \
    KCADM_BIN="$FAKE_KCADM" \
    RUNTIME_JSON_VALIDATOR="$VALIDATOR" \
    KEYCLOAK_RUNTIME_ENVIRONMENT=dev \
    KEYCLOAK_EXISTING_MANAGED_REALMS=saas-admin,saas-bpfarias \
    KEYCLOAK_REALM_SMTP_MODE=dev \
    KEYCLOAK_REALM_SMTP_HOST=mailpit \
    KEYCLOAK_REALM_SMTP_PORT=1025 \
    KEYCLOAK_REALM_SMTP_FROM=no-reply@agentefiscal.local \
    KEYCLOAK_REALM_SMTP_FROM_DISPLAY_NAME='Contador Fiscal' \
    KEYCLOAK_REALM_SMTP_REPLY_TO=suporte@agentefiscal.local \
    KEYCLOAK_REALM_SMTP_REPLY_TO_DISPLAY_NAME='Contador Fiscal' \
    KEYCLOAK_REALM_SMTP_AUTH=false \
    KEYCLOAK_REALM_SMTP_STARTTLS=false \
    KEYCLOAK_REALM_SMTP_SSL=false \
    KEYCLOAK_REALM_SMTP_USER= \
    KEYCLOAK_REALM_SMTP_PASSWORD= \
        "$RECONCILER" "$1" "$KCADM_CONFIG"
}

write_mailpit_state saas-admin
write_mailpit_state saas-bpfarias
run_dev verify > "$FIXTURE_ROOT/dev-verify.log"
grep -Fq 'password-recovery SMTP is valid' "$FIXTURE_ROOT/dev-verify.log" \
    || fail "DEV Mailpit contract did not verify"
grep -Fq -- '--fields resetPasswordAllowed,smtpServer(*)' "$KCADM_LOG" \
    || fail "realm SMTP readback did not request nested smtpServer fields"

cat > "$FIXTURE_ROOT/saas-admin.json" <<'EOF'
{"resetPasswordAllowed":false,"smtpServer":{}}
EOF
run_dev reconcile > "$FIXTURE_ROOT/dev-reconcile.log"
run_dev verify > "$FIXTURE_ROOT/dev-after.log"
[ "$(grep -c '^update realms/' "$KCADM_LOG")" -eq 2 ] \
    || fail "reconciliation did not update exactly the allowlisted realms"

SECRET_VALUE=Abcdefghijklmnop1234
cat > "$FIXTURE_ROOT/saas-admin.json" <<'EOF'
{"resetPasswordAllowed":true,"smtpServer":{"host":"smtp.example.com","port":"587","from":"no-reply@agentefiscal.com.br","fromDisplayName":"Contador Fiscal","replyTo":"suporte@agentefiscal.com.br","replyToDisplayName":"Contador Fiscal","auth":"true","starttls":"true","ssl":"false","user":"smtp-user@example.com","password":"**********"}}
EOF
: > "$KCADM_LOG"
SMTP_TEST_KCADM_LOG="$KCADM_LOG" \
SMTP_TEST_STATE_ROOT="$FIXTURE_ROOT" \
KCADM_BIN="$FAKE_KCADM" \
RUNTIME_JSON_VALIDATOR="$VALIDATOR" \
KEYCLOAK_RUNTIME_ENVIRONMENT=production \
KEYCLOAK_EXISTING_MANAGED_REALMS=saas-admin \
KEYCLOAK_REALM_SMTP_MODE=prd \
KEYCLOAK_REALM_SMTP_HOST=smtp.example.com \
KEYCLOAK_REALM_SMTP_PORT=587 \
KEYCLOAK_REALM_SMTP_FROM=no-reply@agentefiscal.com.br \
KEYCLOAK_REALM_SMTP_FROM_DISPLAY_NAME='Contador Fiscal' \
KEYCLOAK_REALM_SMTP_REPLY_TO=suporte@agentefiscal.com.br \
KEYCLOAK_REALM_SMTP_REPLY_TO_DISPLAY_NAME='Contador Fiscal' \
KEYCLOAK_REALM_SMTP_AUTH=true \
KEYCLOAK_REALM_SMTP_STARTTLS=true \
KEYCLOAK_REALM_SMTP_SSL=false \
KEYCLOAK_REALM_SMTP_USER=smtp-user@example.com \
KEYCLOAK_REALM_SMTP_PASSWORD="$SECRET_VALUE" \
    "$RECONCILER" verify "$KCADM_CONFIG" \
    > "$FIXTURE_ROOT/prd-verify.log" 2>&1
if grep -Fq "$SECRET_VALUE" "$KCADM_LOG" "$FIXTURE_ROOT/prd-verify.log"; then
    fail "production SMTP password appeared in argv, stdout or stderr"
fi

: > "$KCADM_LOG"
if SMTP_TEST_KCADM_LOG="$KCADM_LOG" \
        SMTP_TEST_STATE_ROOT="$FIXTURE_ROOT" \
        KCADM_BIN="$FAKE_KCADM" \
        RUNTIME_JSON_VALIDATOR="$VALIDATOR" \
        KEYCLOAK_RUNTIME_ENVIRONMENT=production \
        KEYCLOAK_EXISTING_MANAGED_REALMS=saas-admin \
        KEYCLOAK_REALM_SMTP_MODE=prd \
        KEYCLOAK_REALM_SMTP_HOST=mailpit \
        KEYCLOAK_REALM_SMTP_PORT=1025 \
        KEYCLOAK_REALM_SMTP_FROM=no-reply@agentefiscal.com.br \
        KEYCLOAK_REALM_SMTP_FROM_DISPLAY_NAME='Contador Fiscal' \
        KEYCLOAK_REALM_SMTP_REPLY_TO=suporte@agentefiscal.com.br \
        KEYCLOAK_REALM_SMTP_REPLY_TO_DISPLAY_NAME='Contador Fiscal' \
        KEYCLOAK_REALM_SMTP_AUTH=true \
        KEYCLOAK_REALM_SMTP_STARTTLS=true \
        KEYCLOAK_REALM_SMTP_SSL=false \
        KEYCLOAK_REALM_SMTP_USER=smtp-user@example.com \
        KEYCLOAK_REALM_SMTP_PASSWORD="$SECRET_VALUE" \
        "$RECONCILER" verify "$KCADM_CONFIG" \
        > "$FIXTURE_ROOT/prd-mailpit.log" 2>&1; then
    fail "production accepted Mailpit as its SMTP provider"
fi
[ ! -s "$KCADM_LOG" ] || fail "invalid production SMTP reached the Keycloak Admin API"

: > "$KCADM_LOG"
if SMTP_TEST_KCADM_LOG="$KCADM_LOG" \
        SMTP_TEST_STATE_ROOT="$FIXTURE_ROOT" \
        KCADM_BIN="$FAKE_KCADM" \
        RUNTIME_JSON_VALIDATOR="$VALIDATOR" \
        KEYCLOAK_RUNTIME_ENVIRONMENT=hml \
        KEYCLOAK_EXISTING_MANAGED_REALMS=saas-admin,saas-bpfarias \
        KEYCLOAK_REALM_SMTP_MODE=hml \
        KEYCLOAK_REALM_SMTP_HOST=smtp.hostinger.com \
        KEYCLOAK_REALM_SMTP_PORT=465 \
        KEYCLOAK_REALM_SMTP_FROM=no-reply@contadorfiscal.com.br \
        KEYCLOAK_REALM_SMTP_FROM_DISPLAY_NAME='Contador Fiscal' \
        KEYCLOAK_REALM_SMTP_REPLY_TO=contato@contadorfiscal.com.br \
        KEYCLOAK_REALM_SMTP_REPLY_TO_DISPLAY_NAME='Contador Fiscal' \
        KEYCLOAK_REALM_SMTP_AUTH=true \
        KEYCLOAK_REALM_SMTP_STARTTLS=false \
        KEYCLOAK_REALM_SMTP_SSL=true \
        KEYCLOAK_REALM_SMTP_USER=contato@contadorfiscal.com.br \
        KEYCLOAK_REALM_SMTP_PASSWORD= \
        "$RECONCILER" preflight "$KCADM_CONFIG" \
        > "$FIXTURE_ROOT/hml-missing-secret.log" 2>&1; then
    fail "HML preflight accepted an absent SMTP password"
fi
[ ! -s "$KCADM_LOG" ] || fail "failed HML preflight reached the Keycloak Admin API"

SMTP_TEST_KCADM_LOG="$KCADM_LOG" \
SMTP_TEST_STATE_ROOT="$FIXTURE_ROOT" \
KCADM_BIN="$FAKE_KCADM" \
RUNTIME_JSON_VALIDATOR="$VALIDATOR" \
KEYCLOAK_RUNTIME_ENVIRONMENT=hml \
KEYCLOAK_EXISTING_MANAGED_REALMS=saas-admin,saas-bpfarias \
KEYCLOAK_REALM_SMTP_MODE=hml \
KEYCLOAK_REALM_SMTP_HOST=smtp.hostinger.com \
KEYCLOAK_REALM_SMTP_PORT=465 \
KEYCLOAK_REALM_SMTP_FROM=no-reply@contadorfiscal.com.br \
KEYCLOAK_REALM_SMTP_FROM_DISPLAY_NAME='Contador Fiscal' \
KEYCLOAK_REALM_SMTP_REPLY_TO=contato@contadorfiscal.com.br \
KEYCLOAK_REALM_SMTP_REPLY_TO_DISPLAY_NAME='Contador Fiscal' \
KEYCLOAK_REALM_SMTP_AUTH=true \
KEYCLOAK_REALM_SMTP_STARTTLS=false \
KEYCLOAK_REALM_SMTP_SSL=true \
KEYCLOAK_REALM_SMTP_USER=contato@contadorfiscal.com.br \
KEYCLOAK_REALM_SMTP_PASSWORD="$SECRET_VALUE" \
    "$RECONCILER" preflight "$KCADM_CONFIG" \
    > "$FIXTURE_ROOT/hml-preflight.log" 2>&1
[ ! -s "$KCADM_LOG" ] || fail "successful HML preflight called the Keycloak Admin API"
if grep -Fq "$SECRET_VALUE" "$FIXTURE_ROOT/hml-preflight.log"; then
    fail "HML SMTP password appeared in preflight output"
fi

echo "PASS: Keycloak realm SMTP verification and reconciliation are fail-closed."
