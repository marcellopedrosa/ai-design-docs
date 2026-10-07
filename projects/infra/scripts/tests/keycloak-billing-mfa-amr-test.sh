#!/usr/bin/env bash

set -Eeuo pipefail

REPOSITORY_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
RECONCILER="$REPOSITORY_ROOT/infra/keycloak/bootstrap/reconcile-billing-mfa-amr.sh"
VALIDATOR="$REPOSITORY_ROOT/infra/keycloak/bootstrap/validate-keycloak-runtime-json.sh"
FIXTURE_ROOT="$(mktemp -d)"
FAKE_KCADM="$FIXTURE_ROOT/kcadm.sh"
SESSION_FILE="$FIXTURE_ROOT/kcadm.config"
STATE_DIR="$FIXTURE_ROOT/state"
MUTATION_LOG="$FIXTURE_ROOT/mutations.log"

cleanup() {
    rm -rf -- "$FIXTURE_ROOT"
}
trap cleanup EXIT

fail() {
    echo "FAIL: $*" >&2
    exit 1
}

mkdir -p "$STATE_DIR"
printf '%s\n' synthetic-session > "$SESSION_FILE"
chmod 600 "$SESSION_FILE"
: > "$MUTATION_LOG"

cat > "$FAKE_KCADM" <<'EOF'
#!/bin/sh
set -eu

command_name="${1:-}"
resource="${2:-}"
pwd_execution=11111111-1111-1111-1111-111111111111
otp_execution=22222222-2222-2222-2222-222222222222
pwd_config=33333333-3333-3333-3333-333333333333
otp_config=44444444-4444-4444-4444-444444444444

case " $* " in
    *" --password "*|*" --secret "*) exit 91 ;;
esac

config_for() {
    target_kind="$1"
    target_config="$2"
    target_reference="$3"
    target_alias="$4"
    scenario="${FAKE_SCENARIO:?}"

    if [ "$target_kind" = otp ] && [ "$scenario" = external-drift ]; then
        printf '{"id":"%s","alias":"foreign-otp-policy","config":{"default.reference.value":"sms","default.reference.maxAge":"3600"}}\n' \
            "$target_config"
        return
    fi
    if [ "$target_kind" = otp ] && [ "$scenario" = managed-drift ] \
            && [ ! -f "${FAKE_STATE_DIR:?}/updated-otp" ]; then
        printf '{"id":"%s","alias":"%s","config":{"default.reference.value":"%s","default.reference.maxAge":"3600"}}\n' \
            "$target_config" "$target_alias" "$target_reference"
        return
    fi
    printf '{"id":"%s","alias":"%s","config":{"default.reference.value":"%s","default.reference.maxAge":"900"}}\n' \
        "$target_config" "$target_alias" "$target_reference"
}

if [ "$command_name" = get ] && [ "$resource" = realms/saas-admin ]; then
    printf '%s\n' '{"browserFlow":"browser"}'
    exit 0
fi

if [ "$command_name" = get ] \
        && [ "$resource" = authentication/flows/browser/executions ]; then
    scenario="${FAKE_SCENARIO:?}"
    if [ "$scenario" = duplicate-otp ]; then
        printf '%s,%s,%s\n' \
            "$pwd_execution" auth-username-password-form "$pwd_config" \
            "$otp_execution" auth-otp-form "$otp_config" \
            55555555-5555-5555-5555-555555555555 auth-otp-form 66666666-6666-6666-6666-666666666666
        exit 0
    fi

    if [ "$scenario" = missing ] && [ ! -f "${FAKE_STATE_DIR:?}/created-pwd" ]; then
        printf '%s,%s\n' "$pwd_execution" auth-username-password-form
    else
        printf '%s,%s,%s\n' "$pwd_execution" auth-username-password-form "$pwd_config"
    fi
    if [ "$scenario" = missing ] && [ ! -f "${FAKE_STATE_DIR:?}/created-otp" ]; then
        printf '%s,%s\n' "$otp_execution" auth-otp-form
    else
        printf '%s,%s,%s\n' "$otp_execution" auth-otp-form "$otp_config"
    fi
    exit 0
fi

if [ "$command_name" = get ] && [ "$resource" = "authentication/config/$pwd_config" ]; then
    config_for pwd "$pwd_config" pwd saas-billing-amr-pwd-v1
    exit 0
fi
if [ "$command_name" = get ] && [ "$resource" = "authentication/config/$otp_config" ]; then
    config_for otp "$otp_config" otp saas-billing-amr-otp-v1
    exit 0
fi

if [ "$command_name" = create ]; then
    case "$resource" in
        "authentication/executions/$pwd_execution/config") target_kind=pwd ;;
        "authentication/executions/$otp_execution/config") target_kind=otp ;;
        *) exit 92 ;;
    esac
    printf 'create:%s\n' "$target_kind" >> "${FAKE_MUTATION_LOG:?}"
    : > "${FAKE_STATE_DIR:?}/created-$target_kind"
    exit 0
fi

if [ "$command_name" = update ] && [ "$resource" = "authentication/config/$otp_config" ]; then
    printf '%s\n' update:otp >> "${FAKE_MUTATION_LOG:?}"
    : > "${FAKE_STATE_DIR:?}/updated-otp"
    exit 0
fi

exit 93
EOF
chmod 700 "$FAKE_KCADM"

run_reconciler() {
    FAKE_SCENARIO="$1" \
    FAKE_STATE_DIR="$STATE_DIR" \
    FAKE_MUTATION_LOG="$MUTATION_LOG" \
    KCADM_BIN="$FAKE_KCADM" \
    RUNTIME_JSON_VALIDATOR="$VALIDATOR" \
        "$RECONCILER" "$2" "$SESSION_FILE"
}

if run_reconciler missing verify > "$FIXTURE_ROOT/missing-verify.log" 2>&1; then
    fail "verify accepted missing AMR execution references"
fi
[ ! -s "$MUTATION_LOG" ] \
    || fail "verify mode mutated Keycloak state"
grep -Fq 'require controlled reconciliation' "$FIXTURE_ROOT/missing-verify.log" \
    || fail "missing execution references did not produce the bounded diagnostic"

run_reconciler missing reconcile > "$FIXTURE_ROOT/missing-reconcile.log"
[ "$(wc -l < "$MUTATION_LOG" | tr -d '[:space:]')" -eq 2 ] \
    || fail "missing execution references did not create exactly two configs"
grep -Fxq create:pwd "$MUTATION_LOG" \
    || fail "password AMR execution config was not created"
grep -Fxq create:otp "$MUTATION_LOG" \
    || fail "OTP AMR execution config was not created"
run_reconciler missing verify > "$FIXTURE_ROOT/created-verify.log"

mutation_count_before_repeat="$(wc -l < "$MUTATION_LOG" | tr -d '[:space:]')"
run_reconciler missing reconcile > "$FIXTURE_ROOT/repeated-reconcile.log"
mutation_count_after_repeat="$(wc -l < "$MUTATION_LOG" | tr -d '[:space:]')"
[ "$mutation_count_after_repeat" -eq "$mutation_count_before_repeat" ] \
    || fail "repeated reconciliation was not idempotent"

rm -f "$STATE_DIR"/*
: > "$MUTATION_LOG"
if run_reconciler external-drift reconcile > "$FIXTURE_ROOT/external-drift.log" 2>&1; then
    fail "reconciliation overwrote a divergent external authenticator config"
fi
[ ! -s "$MUTATION_LOG" ] \
    || fail "foreign drift caused a partial mutation before preflight completed"
grep -Fq 'no config was changed' "$FIXTURE_ROOT/external-drift.log" \
    || fail "foreign config drift did not produce the bounded diagnostic"

rm -f "$STATE_DIR"/*
: > "$MUTATION_LOG"
run_reconciler managed-drift reconcile > "$FIXTURE_ROOT/managed-drift.log"
[ "$(wc -l < "$MUTATION_LOG" | tr -d '[:space:]')" -eq 1 ] \
    || fail "managed drift did not issue exactly one update"
grep -Fxq update:otp "$MUTATION_LOG" \
    || fail "managed OTP drift was not reconciled"
run_reconciler managed-drift verify > "$FIXTURE_ROOT/managed-verify.log"

rm -f "$STATE_DIR"/*
: > "$MUTATION_LOG"
if run_reconciler duplicate-otp reconcile > "$FIXTURE_ROOT/duplicate.log" 2>&1; then
    fail "duplicate OTP executions were accepted"
fi
[ ! -s "$MUTATION_LOG" ] \
    || fail "duplicate OTP executions caused a mutation"

VALIDATOR_ROOT="$FIXTURE_ROOT/validator"
mkdir -p "$VALIDATOR_ROOT"
printf '%s\n' '{"id":"77777777-7777-7777-7777-777777777777","alias":"saas-billing-amr-otp-v1","config":{"default.reference.value":"otp","default.reference.maxAge":"900"}}' \
    > "$VALIDATOR_ROOT/exact.json"
printf '%s\n' '{"id":"77777777-7777-7777-7777-777777777777","alias":"saas-billing-amr-otp-v1","config":{"default.reference.value":"otp","default.reference.maxAge":"900","decoy":"allowed"}}' \
    > "$VALIDATOR_ROOT/extra.json"
printf '%s\n' '{"id":"77777777-7777-7777-7777-777777777777","alias":"external-policy","config":{"default.reference.value":"otp","default.reference.maxAge":"900"}}' \
    > "$VALIDATOR_ROOT/external-exact.json"

[ "$(bash "$VALIDATOR" billing-amr-config "$VALIDATOR_ROOT/exact.json" otp saas-billing-amr-otp-v1)" \
    = 'reference=otp exact=true ownership=managed' ] \
    || fail "exact managed OTP config was not classified correctly"
[ "$(bash "$VALIDATOR" billing-amr-config "$VALIDATOR_ROOT/extra.json" otp saas-billing-amr-otp-v1)" \
    = 'reference=otp exact=false ownership=managed' ] \
    || fail "extra managed config fields were not classified as drift"
[ "$(bash "$VALIDATOR" billing-amr-config "$VALIDATOR_ROOT/external-exact.json" otp saas-billing-amr-otp-v1)" \
    = 'reference=otp exact=true ownership=external' ] \
    || fail "semantically exact external config was not preserved"

echo "PASS: Billing MFA AMR reconciliation is bounded, fail-closed, and idempotent."
