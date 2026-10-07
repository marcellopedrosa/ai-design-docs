#!/usr/bin/env bash

set -Eeuo pipefail

REPOSITORY_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
RECONCILER="$REPOSITORY_ROOT/infra/keycloak/bootstrap/reconcile-admin-login-mfa.sh"
VALIDATOR="$REPOSITORY_ROOT/infra/keycloak/bootstrap/validate-keycloak-runtime-json.sh"
FAKE_KCADM_FIXTURE="$REPOSITORY_ROOT/infra/scripts/tests/fixtures/keycloak-admin-login-mfa-kcadm.sh"
FIXTURE_ROOT="$(mktemp -d)"
FAKE_KCADM="$FIXTURE_ROOT/kcadm.sh"
SESSION_FILE="$FIXTURE_ROOT/kcadm.config"
STATE_DIR="$FIXTURE_ROOT/state"
MUTATION_LOG="$FIXTURE_ROOT/mutations.log"
KCADM_LOG="$FIXTURE_ROOT/kcadm.log"

cleanup() {
    rm -rf -- "$FIXTURE_ROOT"
}
trap cleanup EXIT

fail() {
    echo "FAIL: $*" >&2
    exit 1
}

[ -f "$RECONCILER" ] \
    || fail "admin login MFA reconciler is unavailable"
[ -f "$FAKE_KCADM_FIXTURE" ] \
    || fail "admin login MFA kcadm fixture is unavailable"

mkdir -p "$STATE_DIR"
printf '%s\n' synthetic-session > "$SESSION_FILE"
chmod 600 "$SESSION_FILE"
: > "$MUTATION_LOG"
: > "$KCADM_LOG"

cp -- "$FAKE_KCADM_FIXTURE" "$FAKE_KCADM"
chmod 700 "$FAKE_KCADM"

reset_state() {
    printf '%s\n' "${1:-CONDITIONAL}" > "$STATE_DIR/parent-requirement"
    printf '%s\n' "${2:-ALTERNATIVE}" > "$STATE_DIR/otp-requirement"
    printf '%s\n' "${3:-true}" > "$STATE_DIR/configure-totp-enabled"
    printf '%s\n' 30 > "$STATE_DIR/parent-priority"
    printf '%s\n' 42 > "$STATE_DIR/otp-priority"
    : > "$MUTATION_LOG"
    : > "$KCADM_LOG"
}

mutation_count() {
    wc -l < "$MUTATION_LOG" | tr -d '[:space:]'
}

run_reconciler() {
    KEYCLOAK_ADMIN_LOGIN_MFA_ENABLED="$1" \
    KEYCLOAK_RUNTIME_ENVIRONMENT="$2" \
    FAKE_SCENARIO="${3:-normal}" \
    FAKE_STATE_DIR="$STATE_DIR" \
    FAKE_MUTATION_LOG="$MUTATION_LOG" \
    FAKE_KCADM_LOG="$KCADM_LOG" \
    FAKE_RUNTIME_JSON_VALIDATOR="$VALIDATOR" \
    FAKE_FAILURE_POINT="${5:-}" \
    KCADM_BIN="$FAKE_KCADM" \
    RUNTIME_JSON_VALIDATOR="$VALIDATOR" \
        "$RECONCILER" "$4" "$SESSION_FILE"
}

run_reconciler_without_enabled() {
    (
        unset KEYCLOAK_ADMIN_LOGIN_MFA_ENABLED
        export KEYCLOAK_RUNTIME_ENVIRONMENT="$1"
        export FAKE_SCENARIO="${2:-normal}"
        export FAKE_STATE_DIR="$STATE_DIR"
        export FAKE_MUTATION_LOG="$MUTATION_LOG"
        export FAKE_KCADM_LOG="$KCADM_LOG"
        export FAKE_RUNTIME_JSON_VALIDATOR="$VALIDATOR"
        export KCADM_BIN="$FAKE_KCADM"
        export RUNTIME_JSON_VALIDATOR="$VALIDATOR"
        "$RECONCILER" "$3" "$SESSION_FILE"
    )
}

assert_environment_toggle() {
    local environment="$1"
    local enabled="$2"
    local expected_parent

    if [ "$enabled" = true ]; then
        reset_state DISABLED ALTERNATIVE false
        expected_parent=CONDITIONAL
    else
        reset_state CONDITIONAL ALTERNATIVE true
        expected_parent=DISABLED
    fi

    run_reconciler "$enabled" "$environment" normal reconcile \
        > "$FIXTURE_ROOT/matrix-$environment-$enabled-reconcile.log"
    [ "$(cat "$STATE_DIR/parent-requirement")" = "$expected_parent" ] \
        || fail "$environment/$enabled did not reconcile the direct 2FA parent"
    [ "$(cat "$STATE_DIR/otp-requirement")" = ALTERNATIVE ] \
        || fail "$environment/$enabled changed the canonical OTP leaf"
    [ "$(cat "$STATE_DIR/configure-totp-enabled")" = "$enabled" ] \
        || fail "$environment/$enabled did not reconcile CONFIGURE_TOTP"
    [ "$(cat "$STATE_DIR/parent-priority")" = 30 ] \
        || fail "$environment/$enabled changed the 2FA parent priority"
    [ "$(cat "$STATE_DIR/otp-priority")" = 42 ] \
        || fail "$environment/$enabled changed the OTP execution priority"
    [ "$(mutation_count)" -eq 2 ] \
        || fail "$environment/$enabled did not make exactly two bounded mutations"

    run_reconciler "$enabled" "$environment" normal verify \
        > "$FIXTURE_ROOT/matrix-$environment-$enabled-verify.log"
    local mutations_before_repeat
    mutations_before_repeat="$(mutation_count)"
    run_reconciler "$enabled" "$environment" normal reconcile \
        > "$FIXTURE_ROOT/matrix-$environment-$enabled-repeat.log"
    [ "$(mutation_count)" -eq "$mutations_before_repeat" ] \
        || fail "$environment/$enabled reconciliation was not idempotent"
}

reset_state
if run_reconciler_without_enabled dev normal verify \
        > "$FIXTURE_ROOT/missing-toggle.log" 2>&1; then
    fail "missing KEYCLOAK_ADMIN_LOGIN_MFA_ENABLED was accepted"
fi
[ "$(mutation_count)" -eq 0 ] \
    || fail "missing toggle configuration mutated Keycloak state"
[ ! -s "$KCADM_LOG" ] \
    || fail "missing toggle configuration reached Keycloak"

matrix_count=0
for environment in dev hml production; do
    for enabled in false true; do
        assert_environment_toggle "$environment" "$enabled"
        matrix_count=$((matrix_count + 1))
    done
done
[ "$matrix_count" -eq 6 ] \
    || fail "the environment toggle matrix did not execute all six states"

for invalid_case in 'maybe dev' 'false staging'; do
    read -r enabled environment <<< "$invalid_case"
    reset_state
    if run_reconciler "$enabled" "$environment" normal reconcile \
            > "$FIXTURE_ROOT/invalid-environment.log" 2>&1; then
        fail "invalid toggle configuration was accepted: $invalid_case"
    fi
    [ "$(mutation_count)" -eq 0 ] \
        || fail "invalid toggle configuration mutated Keycloak state"
    [ ! -s "$KCADM_LOG" ] \
        || fail "invalid toggle configuration reached Keycloak: $invalid_case"
done

reset_state
if run_reconciler false dev normal verify \
        > "$FIXTURE_ROOT/disable-drift-verify.log" 2>&1; then
    fail "verify accepted an enabled OTP flow while the DEV waiver was requested"
fi
[ "$(mutation_count)" -eq 0 ] \
    || fail "verify mode mutated the enabled OTP flow"

run_reconciler false dev normal reconcile \
    > "$FIXTURE_ROOT/disable-reconcile.log"
[ "$(cat "$STATE_DIR/parent-requirement")" = DISABLED ] \
    || fail "DEV reconciliation did not disable the direct 2FA parent flow"
[ "$(cat "$STATE_DIR/otp-requirement")" = ALTERNATIVE ] \
    || fail "DEV reconciliation disabled the OTP leaf instead of preserving it"
[ "$(cat "$STATE_DIR/configure-totp-enabled")" = false ] \
    || fail "DEV reconciliation did not disable the CONFIGURE_TOTP provider"
[ "$(cat "$STATE_DIR/parent-priority")" = 30 ] \
    || fail "DEV reconciliation changed the 2FA parent priority"
[ "$(cat "$STATE_DIR/otp-priority")" = 42 ] \
    || fail "DEV reconciliation changed the OTP execution priority"
[ "$(mutation_count)" -eq 2 ] \
    || fail "DEV reconciliation did not make exactly two bounded mutations"
grep -Fxq \
    'flow-parent:88888888-8888-8888-8888-888888888888:CONDITIONAL>DISABLED' \
    "$MUTATION_LOG" \
    || fail "DEV reconciliation did not toggle the direct 2FA parent in place"
grep -Fxq 'required-action:true>false' "$MUTATION_LOG" \
    || fail "DEV reconciliation did not toggle CONFIGURE_TOTP in place"
if grep -q '^flow-otp:' "$MUTATION_LOG"; then
    fail "canonical DEV disablement mutated the OTP leaf"
fi
[ "$(sed -n '1p' "$MUTATION_LOG")" = \
    'flow-parent:88888888-8888-8888-8888-888888888888:CONDITIONAL>DISABLED' ] \
    || fail "DEV disablement did not disable the 2FA parent before enrollment"

run_reconciler false dev normal verify \
    > "$FIXTURE_ROOT/disabled-verify.log"
mutations_before_repeat="$(mutation_count)"
run_reconciler false dev normal reconcile \
    > "$FIXTURE_ROOT/disabled-repeat.log"
[ "$(mutation_count)" -eq "$mutations_before_repeat" ] \
    || fail "repeated DEV disablement was not idempotent"

if run_reconciler true dev normal verify \
        > "$FIXTURE_ROOT/rollback-drift-verify.log" 2>&1; then
    fail "verify accepted a disabled OTP flow after rollback was requested"
fi
[ "$(mutation_count)" -eq "$mutations_before_repeat" ] \
    || fail "rollback verify mode mutated Keycloak state"

run_reconciler true dev normal reconcile \
    > "$FIXTURE_ROOT/rollback-reconcile.log"
[ "$(cat "$STATE_DIR/parent-requirement")" = CONDITIONAL ] \
    || fail "rollback did not restore the direct 2FA parent"
[ "$(cat "$STATE_DIR/otp-requirement")" = ALTERNATIVE ] \
    || fail "rollback did not preserve the canonical OTP requirement"
[ "$(cat "$STATE_DIR/configure-totp-enabled")" = true ] \
    || fail "rollback did not re-enable the CONFIGURE_TOTP provider"
[ "$(cat "$STATE_DIR/parent-priority")" = 30 ] \
    || fail "rollback changed the 2FA parent priority"
[ "$(cat "$STATE_DIR/otp-priority")" = 42 ] \
    || fail "rollback changed the OTP execution priority"
[ "$(mutation_count)" -eq $((mutations_before_repeat + 2)) ] \
    || fail "rollback did not make exactly two bounded mutations"
grep -Fxq \
    'flow-parent:88888888-8888-8888-8888-888888888888:DISABLED>CONDITIONAL' \
    "$MUTATION_LOG" \
    || fail "rollback did not restore the same 2FA parent execution"
grep -Fxq 'required-action:false>true' "$MUTATION_LOG" \
    || fail "rollback did not re-enable CONFIGURE_TOTP in place"
rollback_tail="$FIXTURE_ROOT/rollback-tail.log"
tail -n 2 "$MUTATION_LOG" > "$rollback_tail"
[ "$(sed -n '1p' "$rollback_tail")" = 'required-action:false>true' ] \
    || fail "rollback did not enable CONFIGURE_TOTP before the 2FA parent"
[ "$(sed -n '2p' "$rollback_tail")" = \
    'flow-parent:88888888-8888-8888-8888-888888888888:DISABLED>CONDITIONAL' ] \
    || fail "rollback did not reactivate the 2FA parent last"

run_reconciler true dev normal verify \
    > "$FIXTURE_ROOT/rollback-verify.log"
mutations_before_repeat="$(mutation_count)"
run_reconciler true dev normal reconcile \
    > "$FIXTURE_ROOT/rollback-repeat.log"
[ "$(mutation_count)" -eq "$mutations_before_repeat" ] \
    || fail "repeated MFA rollback was not idempotent"

# Regression for KC-DEV-AUTH-001: the former reconciler accepted this topology
# and fresh browser logins failed only after a correct password.
reset_state CONDITIONAL DISABLED false
if run_reconciler false dev normal verify \
        > "$FIXTURE_ROOT/legacy-empty-conditional-verify.log" 2>&1; then
    fail "verify accepted the critical legacy conditional-flow/disabled-OTP state"
fi
[ "$(mutation_count)" -eq 0 ] \
    || fail "legacy-state verification mutated Keycloak state"
run_reconciler false dev normal reconcile \
    > "$FIXTURE_ROOT/legacy-empty-conditional-reconcile.log"
[ "$(cat "$STATE_DIR/parent-requirement")" = DISABLED ] \
    || fail "legacy-state repair did not disable the direct 2FA parent"
[ "$(cat "$STATE_DIR/otp-requirement")" = ALTERNATIVE ] \
    || fail "legacy-state repair did not restore the OTP leaf"
[ "$(cat "$STATE_DIR/configure-totp-enabled")" = false ] \
    || fail "legacy-state repair changed the requested enrollment state"
[ "$(mutation_count)" -eq 2 ] \
    || fail "legacy-state repair did not make exactly two bounded mutations"
[ "$(sed -n '1p' "$MUTATION_LOG")" = \
    'flow-parent:88888888-8888-8888-8888-888888888888:CONDITIONAL>DISABLED' ] \
    || fail "legacy-state repair did not disable the 2FA parent first"
[ "$(sed -n '2p' "$MUTATION_LOG")" = \
    'flow-otp:22222222-2222-2222-2222-222222222222:DISABLED>ALTERNATIVE' ] \
    || fail "legacy-state repair did not restore the same OTP leaf second"
run_reconciler false dev normal verify \
    > "$FIXTURE_ROOT/legacy-empty-conditional-repaired-verify.log"

reset_state CONDITIONAL ALTERNATIVE false
run_reconciler true dev normal reconcile \
    > "$FIXTURE_ROOT/provider-only-rollback-reconcile.log"
[ "$(cat "$STATE_DIR/parent-requirement")" = CONDITIONAL ] \
    || fail "provider-only rollback did not restore the direct 2FA parent"
[ "$(cat "$STATE_DIR/otp-requirement")" = ALTERNATIVE ] \
    || fail "provider-only rollback changed the canonical OTP leaf"
[ "$(cat "$STATE_DIR/configure-totp-enabled")" = true ] \
    || fail "provider-only rollback did not enable CONFIGURE_TOTP"
[ "$(mutation_count)" -eq 3 ] \
    || fail "provider-only rollback did not make exactly three bounded mutations"
[ "$(sed -n '1p' "$MUTATION_LOG")" = \
    'flow-parent:88888888-8888-8888-8888-888888888888:CONDITIONAL>DISABLED' ] \
    || fail "provider-only rollback did not quiesce the 2FA parent first"
[ "$(sed -n '2p' "$MUTATION_LOG")" = 'required-action:false>true' ] \
    || fail "provider-only rollback did not enable CONFIGURE_TOTP second"
[ "$(sed -n '3p' "$MUTATION_LOG")" = \
    'flow-parent:88888888-8888-8888-8888-888888888888:DISABLED>CONDITIONAL' ] \
    || fail "provider-only rollback did not reactivate the 2FA parent last"
if grep -q '^flow-otp:' "$MUTATION_LOG"; then
    fail "provider-only rollback mutated the canonical OTP leaf"
fi
run_reconciler true dev normal verify \
    > "$FIXTURE_ROOT/provider-only-rollback-verify.log"

reset_state CONDITIONAL DISABLED false
run_reconciler true dev normal reconcile \
    > "$FIXTURE_ROOT/legacy-rollback-reconcile.log"
[ "$(cat "$STATE_DIR/parent-requirement")" = CONDITIONAL ] \
    || fail "legacy rollback did not restore the direct 2FA parent"
[ "$(cat "$STATE_DIR/otp-requirement")" = ALTERNATIVE ] \
    || fail "legacy rollback did not restore the canonical OTP leaf"
[ "$(cat "$STATE_DIR/configure-totp-enabled")" = true ] \
    || fail "legacy rollback did not enable CONFIGURE_TOTP"
[ "$(mutation_count)" -eq 4 ] \
    || fail "legacy rollback did not make exactly four bounded mutations"
[ "$(sed -n '1p' "$MUTATION_LOG")" = \
    'flow-parent:88888888-8888-8888-8888-888888888888:CONDITIONAL>DISABLED' ] \
    || fail "legacy rollback did not quiesce the 2FA parent first"
[ "$(sed -n '2p' "$MUTATION_LOG")" = 'required-action:false>true' ] \
    || fail "legacy rollback did not enable CONFIGURE_TOTP second"
[ "$(sed -n '3p' "$MUTATION_LOG")" = \
    'flow-otp:22222222-2222-2222-2222-222222222222:DISABLED>ALTERNATIVE' ] \
    || fail "legacy rollback did not restore the OTP leaf third"
[ "$(sed -n '4p' "$MUTATION_LOG")" = \
    'flow-parent:88888888-8888-8888-8888-888888888888:DISABLED>CONDITIONAL' ] \
    || fail "legacy rollback did not reactivate the 2FA parent last"
run_reconciler true dev normal verify \
    > "$FIXTURE_ROOT/legacy-rollback-verify.log"
mutations_before_repeat="$(mutation_count)"
run_reconciler true dev normal reconcile \
    > "$FIXTURE_ROOT/legacy-rollback-repeat.log"
[ "$(mutation_count)" -eq "$mutations_before_repeat" ] \
    || fail "repeated legacy rollback was not idempotent"

reset_state CONDITIONAL DISABLED false
if run_reconciler true dev normal reconcile otp-update \
        > "$FIXTURE_ROOT/legacy-rollback-partial-failure.log" 2>&1; then
    fail "legacy rollback ignored an injected OTP repair failure"
fi
[ "$(cat "$STATE_DIR/parent-requirement")" = DISABLED ] \
    || fail "partial legacy rollback left the invalid 2FA parent active"
[ "$(cat "$STATE_DIR/otp-requirement")" = DISABLED ] \
    || fail "injected OTP repair failure unexpectedly changed the OTP leaf"
[ "$(cat "$STATE_DIR/configure-totp-enabled")" = true ] \
    || fail "partial legacy rollback did not perform the preceding enrollment repair"
[ "$(mutation_count)" -eq 2 ] \
    || fail "partial legacy rollback did not stop after two bounded mutations"
[ "$(sed -n '1p' "$MUTATION_LOG")" = \
    'flow-parent:88888888-8888-8888-8888-888888888888:CONDITIONAL>DISABLED' ] \
    || fail "partial legacy rollback did not quiesce the 2FA parent first"
[ "$(sed -n '2p' "$MUTATION_LOG")" = 'required-action:false>true' ] \
    || fail "partial legacy rollback did not enable CONFIGURE_TOTP second"
if grep -Fq \
        'flow-parent:88888888-8888-8888-8888-888888888888:DISABLED>CONDITIONAL' \
        "$MUTATION_LOG"; then
    fail "partial legacy rollback reactivated the 2FA parent after a child failure"
fi
mutations_before_verify="$(mutation_count)"
if run_reconciler true dev normal verify \
        > "$FIXTURE_ROOT/legacy-rollback-partial-verify.log" 2>&1; then
    fail "verify accepted the partially repaired legacy rollback"
fi
[ "$(mutation_count)" -eq "$mutations_before_verify" ] \
    || fail "partial legacy rollback verification mutated Keycloak state"
run_reconciler true dev normal reconcile \
    > "$FIXTURE_ROOT/legacy-rollback-recovery.log"
[ "$(cat "$STATE_DIR/parent-requirement")" = CONDITIONAL ] \
    && [ "$(cat "$STATE_DIR/otp-requirement")" = ALTERNATIVE ] \
    && [ "$(cat "$STATE_DIR/configure-totp-enabled")" = true ] \
    || fail "legacy rollback did not recover after the injected partial failure"
run_reconciler true dev normal verify \
    > "$FIXTURE_ROOT/legacy-rollback-recovery-verify.log"

for ambiguous_scenario in \
        missing-otp \
        duplicate-otp \
        malformed-priority \
        malformed-level \
        malformed-index \
        missing-parent \
        duplicate-parent \
        missing-condition \
        duplicate-condition \
        disabled-condition \
        unmanaged-parent-requirement \
        unmanaged-otp-requirement \
        unmanaged-conditional \
        wrong-required-action \
        default-action-enabled; do
    reset_state
    if run_reconciler false dev "$ambiguous_scenario" reconcile \
            > "$FIXTURE_ROOT/$ambiguous_scenario.log" 2>&1; then
        fail "ambiguous Keycloak state was accepted: $ambiguous_scenario"
    fi
    [ "$(mutation_count)" -eq 0 ] \
        || fail "ambiguous Keycloak state caused a partial mutation: $ambiguous_scenario"
done

if grep -Eq '^(delete |.*users/.*/credentials|.*disable-credential-types)' "$KCADM_LOG"; then
    fail "the reconciler removed or disabled a user credential"
fi

echo "PASS: admin login MFA toggling passed all 6 environment states and remained reversible, fail-closed, and idempotent."
