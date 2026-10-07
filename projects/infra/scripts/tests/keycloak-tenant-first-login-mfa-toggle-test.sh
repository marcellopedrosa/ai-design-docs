#!/usr/bin/env bash

set -Eeuo pipefail

REPOSITORY_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
RECONCILER="$REPOSITORY_ROOT/infra/keycloak/bootstrap/reconcile-tenant-first-login-mfa.sh"
VALIDATOR="$REPOSITORY_ROOT/infra/keycloak/bootstrap/validate-keycloak-runtime-json.sh"
FIXTURE_ROOT="$(mktemp -d)"
FAKE_KCADM="$FIXTURE_ROOT/kcadm.sh"
SESSION_FILE="$FIXTURE_ROOT/kcadm.config"
STATE_DIR="$FIXTURE_ROOT/state"
KCADM_LOG="$FIXTURE_ROOT/kcadm.log"

cleanup() {
    rm -rf -- "$FIXTURE_ROOT"
}
trap cleanup EXIT

fail() {
    echo "FAIL: $*" >&2
    exit 1
}

[ -f "$RECONCILER" ] || fail "tenant first-login MFA reconciler is unavailable"
mkdir -p "$STATE_DIR"
printf '%s\n' synthetic-session > "$SESSION_FILE"
chmod 600 "$SESSION_FILE"
: > "$KCADM_LOG"
printf '%s\n' true > "$STATE_DIR/saas-tenant-a"
printf '%s\n' true > "$STATE_DIR/saas-tenant-b"

cat > "$FAKE_KCADM" <<'EOF'
#!/bin/sh
set -eu

command_name="${1:-}"
resource="${2:-}"
printf '%s\n' "$*" >> "${FAKE_KCADM_LOG:?}"

case " $* " in
    *" delete "*|*" users/"*|*" credentials"*|*" role-mappings"*|*" authentication/flows/"*)
        exit 91
        ;;
esac

option_value() {
    option_name="$1"
    shift
    previous_argument=""
    for argument in "$@"; do
        if [ "$previous_argument" = "$option_name" ]; then
            printf '%s\n' "$argument"
            return
        fi
        previous_argument="$argument"
    done
    printf '\n'
}

realm_name="$(option_value -r "$@")"
state_file="${FAKE_STATE_DIR:?}/$realm_name"

if [ "$command_name" = get ] \
        && [ "$resource" = authentication/required-actions/CONFIGURE_TOTP ]; then
    [ "${FAKE_SCENARIO:-normal}" != "missing-provider-$realm_name" ] || exit 1
    if [ "${FAKE_SCENARIO:-normal}" = "malformed-provider-$realm_name" ]; then
        printf '%s\n' '{"alias":"CONFIGURE_TOTP","enabled":true}'
        exit 0
    fi
    [ -f "$state_file" ] || exit 2
    enabled="$(cat "$state_file")"
    printf '%s\n' "{\"alias\":\"CONFIGURE_TOTP\",\"name\":\"Configure OTP\",\"providerId\":\"CONFIGURE_TOTP\",\"enabled\":$enabled,\"defaultAction\":false,\"priority\":10,\"config\":{}}"
    exit 0
fi

if [ "$command_name" = update ] \
        && [ "$resource" = authentication/required-actions/CONFIGURE_TOTP ]; then
    payload_file="$(option_value -f "$@")"
    [ -f "$payload_file" ] || exit 3
    result="$(/bin/bash "${FAKE_VALIDATOR:?}" admin-login-required-action "$payload_file")"
    case "$result" in
        enabled=true) printf '%s\n' true > "$state_file" ;;
        enabled=false) printf '%s\n' false > "$state_file" ;;
        *) exit 4 ;;
    esac
    exit 0
fi

exit 90
EOF
chmod +x "$FAKE_KCADM"

run_reconciler() {
    mode="$1"
    enabled="$2"
    environment="${3:-dev}"
    realms="${4:-saas-admin,saas-tenant-a,saas-tenant-b}"
    shift 4 || true
    env \
        KCADM_BIN="$FAKE_KCADM" \
        RUNTIME_JSON_VALIDATOR="$VALIDATOR" \
        KEYCLOAK_TENANT_FIRST_LOGIN_MFA_ENABLED="$enabled" \
        KEYCLOAK_RUNTIME_ENVIRONMENT="$environment" \
        KEYCLOAK_EXISTING_MANAGED_REALMS="$realms" \
        FAKE_STATE_DIR="$STATE_DIR" \
        FAKE_KCADM_LOG="$KCADM_LOG" \
        FAKE_VALIDATOR="$VALIDATOR" \
        "$@" \
        "$RECONCILER" "$mode" "$SESSION_FILE"
}

run_reconciler_without_enabled() {
    mode="$1"
    environment="$2"
    realms="$3"
    (
        unset KEYCLOAK_TENANT_FIRST_LOGIN_MFA_ENABLED
        export KCADM_BIN="$FAKE_KCADM"
        export RUNTIME_JSON_VALIDATOR="$VALIDATOR"
        export KEYCLOAK_RUNTIME_ENVIRONMENT="$environment"
        export KEYCLOAK_EXISTING_MANAGED_REALMS="$realms"
        export FAKE_STATE_DIR="$STATE_DIR"
        export FAKE_KCADM_LOG="$KCADM_LOG"
        export FAKE_VALIDATOR="$VALIDATOR"
        "$RECONCILER" "$mode" "$SESSION_FILE"
    )
}

assert_environment_toggle() {
    environment="$1"
    enabled="$2"
    if [ "$enabled" = true ]; then
        initial_state=false
    else
        initial_state=true
    fi
    case_log="$FIXTURE_ROOT/matrix-$environment-$enabled"

    printf '%s\n' "$initial_state" > "$STATE_DIR/saas-tenant-a"
    printf '%s\n' "$initial_state" > "$STATE_DIR/saas-tenant-b"
    : > "$KCADM_LOG"

    run_reconciler reconcile "$enabled" "$environment" \
        saas-admin,saas-tenant-a,saas-tenant-b > "$case_log-reconcile.log"
    [ "$(cat "$STATE_DIR/saas-tenant-a")" = "$enabled" ] \
        || fail "$environment/$enabled did not converge tenant A"
    [ "$(cat "$STATE_DIR/saas-tenant-b")" = "$enabled" ] \
        || fail "$environment/$enabled did not converge tenant B"
    ! grep -Fq -- '-r saas-admin' "$KCADM_LOG" \
        || fail "$environment/$enabled inspected or mutated the administrative realm"
    grep -Fq 'reconciled successfully' "$case_log-reconcile.log" \
        || fail "$environment/$enabled reconciliation did not complete"

    updates_after_reconcile="$(grep -c '^update ' "$KCADM_LOG" || true)"
    [ "$updates_after_reconcile" -eq 2 ] \
        || fail "$environment/$enabled did not update exactly the two divergent tenants"
    run_reconciler verify "$enabled" "$environment" \
        saas-admin,saas-tenant-a,saas-tenant-b > "$case_log-verify.log"
    run_reconciler reconcile "$enabled" "$environment" \
        saas-admin,saas-tenant-a,saas-tenant-b > "$case_log-replay.log"
    updates_after_replay="$(grep -c '^update ' "$KCADM_LOG" || true)"
    [ "$updates_after_reconcile" -eq "$updates_after_replay" ] \
        || fail "$environment/$enabled replay was not idempotent"
}

matrix_cases=0
for environment in dev hml production; do
    for enabled in false true; do
        assert_environment_toggle "$environment" "$enabled"
        matrix_cases=$((matrix_cases + 1))
    done
done
[ "$matrix_cases" -eq 6 ] || fail "the environment/toggle matrix was incomplete"

: > "$KCADM_LOG"
mutations_before="$(grep -c '^update ' "$KCADM_LOG" || true)"
if run_reconciler_without_enabled verify dev saas-admin,saas-tenant-a,saas-tenant-b \
        > "$FIXTURE_ROOT/missing-toggle.log" 2>&1; then
    fail "missing tenant first-login MFA toggle was accepted"
fi
mutations_after="$(grep -c '^update ' "$KCADM_LOG" || true)"
[ "$mutations_before" -eq "$mutations_after" ] || fail "missing toggle caused a mutation"

if run_reconciler verify invalid dev saas-admin,saas-tenant-a,saas-tenant-b \
        > "$FIXTURE_ROOT/invalid-toggle.log" 2>&1; then
    fail "malformed tenant first-login MFA toggle was accepted"
fi
mutations_after="$(grep -c '^update ' "$KCADM_LOG" || true)"
[ "$mutations_before" -eq "$mutations_after" ] || fail "malformed toggle caused a mutation"

if run_reconciler verify true qa saas-admin,saas-tenant-a,saas-tenant-b \
        > "$FIXTURE_ROOT/invalid-environment.log" 2>&1; then
    fail "unknown Keycloak runtime environment was accepted"
fi
mutations_after="$(grep -c '^update ' "$KCADM_LOG" || true)"
[ "$mutations_before" -eq "$mutations_after" ] || fail "invalid environment caused a mutation"

if run_reconciler verify false dev saas-admin > "$FIXTURE_ROOT/no-tenant.log" 2>&1; then
    fail "disabled state without a tenant realm was accepted"
fi
if run_reconciler verify true dev 'saas-admin, saas-tenant-a' \
        > "$FIXTURE_ROOT/unsafe-list.log" 2>&1; then
    fail "unsafe realm allowlist was accepted"
fi
if run_reconciler verify true dev saas-admin,saas-tenant-a,saas-tenant-a \
        > "$FIXTURE_ROOT/duplicate-list.log" 2>&1; then
    fail "duplicate realm allowlist was accepted"
fi

printf '%s\n' true > "$STATE_DIR/saas-tenant-a"
printf '%s\n' true > "$STATE_DIR/saas-tenant-b"
mutations_before="$(grep -c '^update ' "$KCADM_LOG" || true)"
if FAKE_SCENARIO=missing-provider-saas-tenant-b \
        run_reconciler reconcile false dev saas-admin,saas-tenant-a,saas-tenant-b \
        > "$FIXTURE_ROOT/missing-provider.log" 2>&1; then
    fail "missing provider was accepted"
fi
mutations_after="$(grep -c '^update ' "$KCADM_LOG" || true)"
[ "$mutations_before" -eq "$mutations_after" ] || fail "preflight failure caused partial mutation"

if FAKE_SCENARIO=malformed-provider-saas-tenant-b \
        run_reconciler reconcile false dev saas-admin,saas-tenant-a,saas-tenant-b \
        > "$FIXTURE_ROOT/malformed-provider.log" 2>&1; then
    fail "malformed provider was accepted"
fi
mutations_after_malformed="$(grep -c '^update ' "$KCADM_LOG" || true)"
[ "$mutations_before" -eq "$mutations_after_malformed" ] || fail "malformed preflight caused partial mutation"

if grep -Eq '(^| )(delete|users/|credentials|role-mappings|authentication/flows/)( |$)' "$KCADM_LOG"; then
    fail "reconciler touched a prohibited Keycloak resource"
fi

echo "Tenant first-login MFA toggle tests passed (6/6 environment states)."
