#!/usr/bin/env bash

set -Eeuo pipefail

REPOSITORY_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
RECONCILER="$REPOSITORY_ROOT/infra/keycloak/bootstrap/reconcile-super-admin-identity.sh"
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

[ -f "$RECONCILER" ] || fail "Super Admin identity reconciler is unavailable"
mkdir -p "$STATE_DIR"
printf '%s\n' synthetic-session > "$SESSION_FILE"
chmod 600 "$SESSION_FILE"

apply_state() {
    printf '%s\n' "$1" > "$STATE_DIR/username"
    printf '%s\n' "$2" > "$STATE_DIR/email"
    printf '%s\n' "$3" > "$STATE_DIR/human-id"
    printf '%s\n' "$4" > "$STATE_DIR/role-count"
    printf '%s\n' "$5" > "$STATE_DIR/conflict"
    printf '%s\n' "${6:-absent}" > "$STATE_DIR/legacy-duplicate"
    : > "$MUTATION_LOG"
}

cat > "$FAKE_KCADM" <<'EOF'
#!/bin/sh
set -eu

primary_id=11111111-1111-1111-1111-111111111111
conflict_id=22222222-2222-2222-2222-222222222222
canonical=djmarcellopedrosa@gmail.com
legacy=superadmin@duoset.com.br
human_id=dev-superadmin-primary
command_name="${1:-}"
resource="${2:-}"

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

setting_value() {
    setting_name="$1"
    shift
    for argument in "$@"; do
        case "$argument" in
            "$setting_name"=*)
                printf '%s\n' "${argument#*=}"
                return
                ;;
        esac
    done
    printf '\n'
}

if [ "$command_name" = get ] && [ "$resource" = users ]; then
    username_query="$(option_value -q "$@")"
    all_arguments=" $* "
    case "$all_arguments" in
        *" -q username=$canonical "*)
            if [ "$(cat "${FAKE_STATE_DIR:?}/username")" = "$canonical" ]; then
                printf '%s\n' "$primary_id"
            fi
            if [ "$(cat "$FAKE_STATE_DIR/conflict")" = username ]; then
                printf '%s\n' "$conflict_id"
            fi
            ;;
        *" -q email=$canonical "*)
            if [ "$(cat "$FAKE_STATE_DIR/email")" = "$canonical" ]; then
                printf '%s\n' "$primary_id"
            fi
            if [ "$(cat "$FAKE_STATE_DIR/conflict")" = email ]; then
                printf '%s\n' "$conflict_id"
            fi
            ;;
        *" -q q=human_principal_id:$human_id "*)
            if [ "$(cat "$FAKE_STATE_DIR/human-id")" = "$human_id" ]; then
                printf '%s\n' "$primary_id"
            fi
            if [ "$(cat "$FAKE_STATE_DIR/conflict")" = human-id ]; then
                printf '%s\n' "$conflict_id"
            fi
            ;;
        *" -q username=$legacy "*)
            if [ "$(cat "$FAKE_STATE_DIR/username")" = "$legacy" ]; then
                printf '%s\n' "$primary_id"
            fi
            if [ "$(cat "$FAKE_STATE_DIR/legacy-duplicate")" = present ]; then
                printf '%s\n' "$conflict_id"
            fi
            ;;
        *" -q email=$legacy "*)
            if [ "$(cat "$FAKE_STATE_DIR/email")" = "$legacy" ]; then
                printf '%s\n' "$primary_id"
            fi
            if [ "$(cat "$FAKE_STATE_DIR/legacy-duplicate")" = present ]; then
                printf '%s\n' "$conflict_id"
            fi
            ;;
        *)
            printf 'unexpected users query: %s\n' "$username_query" >&2
            exit 91
            ;;
    esac
    exit 0
fi

if [ "$command_name" = get ] && [ "$resource" = roles/ROLE_SUPER_ADMIN/users ]; then
    role_count="$(cat "${FAKE_STATE_DIR:?}/role-count")"
    [ "$role_count" -lt 1 ] || printf '%s\n' "$primary_id"
    [ "$role_count" -lt 2 ] || printf '%s\n' "$conflict_id"
    exit 0
fi

if [ "$command_name" = get ] \
        && [ "$resource" = "users/$primary_id/role-mappings/realm" ]; then
    [ "$(cat "${FAKE_STATE_DIR:?}/role-count")" -ge 1 ] \
        && printf '%s\n' ROLE_SUPER_ADMIN
    exit 0
fi

if [ "$command_name" = get ] && [ "$resource" = "users/$primary_id" ]; then
    field="$(option_value --fields "$@")"
    case "$field" in
        username) cat "${FAKE_STATE_DIR:?}/username" ;;
        email) cat "${FAKE_STATE_DIR:?}/email" ;;
        *) exit 92 ;;
    esac
    exit 0
fi

if [ "$command_name" = update ] && [ "$resource" = "users/$primary_id" ]; then
    username="$(setting_value username "$@")"
    email="$(setting_value email "$@")"
    principal="$(setting_value attributes.human_principal_id "$@")"
    [ "$username" = "$canonical" ] && [ "$email" = "$canonical" ] \
        && [ "$principal" = "[\"$human_id\"]" ] || exit 93
    printf '%s\n' "$username" > "${FAKE_STATE_DIR:?}/username"
    printf '%s\n' "$email" > "$FAKE_STATE_DIR/email"
    printf '%s\n' "$human_id" > "$FAKE_STATE_DIR/human-id"
    printf '%s\n' reconcile >> "${FAKE_MUTATION_LOG:?}"
    exit 0
fi

if [ "$command_name" = delete ] && [ "$resource" = "users/$conflict_id" ]; then
    [ "$(cat "${FAKE_STATE_DIR:?}/legacy-duplicate")" = present ] || exit 95
    printf '%s\n' absent > "$FAKE_STATE_DIR/legacy-duplicate"
    printf '%s\n' remove-legacy >> "${FAKE_MUTATION_LOG:?}"
    exit 0
fi

exit 94
EOF
chmod 700 "$FAKE_KCADM"

run_reconciler() {
    KEYCLOAK_RUNTIME_ENVIRONMENT="$1" \
    FAKE_STATE_DIR="$STATE_DIR" \
    FAKE_MUTATION_LOG="$MUTATION_LOG" \
    KCADM_BIN="$FAKE_KCADM" \
        "$RECONCILER" "$2" "$SESSION_FILE"
}

apply_state superadmin@duoset.com.br superadmin@duoset.com.br absent 1 none
if run_reconciler dev verify > "$FIXTURE_ROOT/legacy-verify.log" 2>&1; then
    fail "verify accepted the previous DEV identity"
fi
[ ! -s "$MUTATION_LOG" ] || fail "verify mode mutated the previous identity"

run_reconciler dev reconcile > "$FIXTURE_ROOT/reconcile.log"
[ "$(cat "$STATE_DIR/username")" = djmarcellopedrosa@gmail.com ] \
    || fail "reconciliation did not update the username"
[ "$(cat "$STATE_DIR/email")" = djmarcellopedrosa@gmail.com ] \
    || fail "reconciliation did not update the email"
[ "$(cat "$STATE_DIR/human-id")" = dev-superadmin-primary ] \
    || fail "reconciliation did not preserve the stable human identity"
[ "$(wc -l < "$MUTATION_LOG" | tr -d '[:space:]')" -eq 1 ] \
    || fail "reconciliation did not perform one bounded user update"

run_reconciler dev verify > "$FIXTURE_ROOT/canonical-verify.log"
run_reconciler dev reconcile > "$FIXTURE_ROOT/idempotent.log"
[ "$(wc -l < "$MUTATION_LOG" | tr -d '[:space:]')" -eq 1 ] \
    || fail "repeated reconciliation was not idempotent"

apply_state old-admin@example.invalid old-admin@example.invalid absent 2 none
if run_reconciler dev reconcile > "$FIXTURE_ROOT/ambiguous-role.log" 2>&1; then
    fail "reconciliation accepted an unanchored ambiguous Super Admin role"
fi
[ ! -s "$MUTATION_LOG" ] || fail "ambiguous role membership mutated identity state"

apply_state old-admin@example.invalid old-admin@example.invalid dev-superadmin-primary 1 email
if run_reconciler dev reconcile > "$FIXTURE_ROOT/conflicting-email.log" 2>&1; then
    fail "reconciliation accepted a canonical email owned by another user"
fi
[ ! -s "$MUTATION_LOG" ] || fail "conflicting canonical email mutated identity state"

apply_state old-admin@example.invalid old-admin@example.invalid dev-superadmin-primary 0 none
if run_reconciler dev reconcile > "$FIXTURE_ROOT/missing-role.log" 2>&1; then
    fail "reconciliation accepted an identity without ROLE_SUPER_ADMIN"
fi
[ ! -s "$MUTATION_LOG" ] || fail "missing role mutated identity state"

apply_state djmarcellopedrosa@gmail.com djmarcellopedrosa@gmail.com \
    dev-superadmin-primary 1 none present
if run_reconciler dev verify > "$FIXTURE_ROOT/coexisting-legacy-verify.log" 2>&1; then
    fail "verify accepted the canonical and retired DEV identities together"
fi
[ ! -s "$MUTATION_LOG" ] || fail "verify mode removed the retired identity"

run_reconciler dev reconcile > "$FIXTURE_ROOT/remove-retired.log"
[ "$(cat "$STATE_DIR/legacy-duplicate")" = absent ] \
    || fail "reconciliation did not remove the retired DEV identity"
[ "$(cat "$MUTATION_LOG")" = remove-legacy ] \
    || fail "coexistence reconciliation performed an unexpected mutation"
run_reconciler dev verify > "$FIXTURE_ROOT/post-removal-verify.log"

apply_state superadmin@duoset.com.br superadmin@duoset.com.br absent 1 none
run_reconciler production reconcile > "$FIXTURE_ROOT/production-skip.log"
[ ! -s "$MUTATION_LOG" ] || fail "non-DEV execution mutated identity state"

echo "Keycloak Super Admin identity tests passed."
