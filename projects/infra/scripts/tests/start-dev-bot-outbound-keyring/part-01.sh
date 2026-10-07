FIXTURE_ROOT="$(mktemp -d)"
FIXTURE_DIR="$FIXTURE_ROOT/saas-fixture"
mkdir -p "$FIXTURE_DIR"
OUTPUT_FILE="$FIXTURE_DIR/bootstrap-output.log"
AES_KEYRING_FILE="$FIXTURE_DIR/.dev-secrets/conversation-audit-aes-keyring.json"
AUDIT_HMAC_KEYRING_FILE="$FIXTURE_DIR/.dev-secrets/conversation-audit-hmac-keyring.json"
OUTBOUND_KEYRING_DIR="$FIXTURE_DIR/.dev-secrets/outbound-hmac"
OUTBOUND_KEYRING_FILE="$OUTBOUND_KEYRING_DIR/conversation-outbound-attempt-hmac-keyring.json"
OUTBOUND_LEGACY_KEYRING_FILE="$FIXTURE_DIR/.dev-secrets/conversation-outbound-attempt-hmac-keyring.json"
OUTBOUND_APPROVAL_DIR="$FIXTURE_DIR/.dev-secrets/approvals/outbound-hmac"
OUTBOUND_COMMIT_RECEIPT_FILE="$FIXTURE_DIR/.dev-secrets/outbound-hmac-commit-receipt.json"
OUTBOUND_COMMIT_RECEIPT_KEY_FILE="$FIXTURE_DIR/.dev-secrets/outbound-hmac-commit-receipt.key"
OUTBOUND_STAGE_LOCK_FILE="$FIXTURE_DIR/.dev-secrets/outbound-hmac-stage.lock"
GENERATED_ENV_FILE="$FIXTURE_DIR/.env.dev.local"
AES_KEY_ID=dev-conversation-audit-aes-v1
AUDIT_HMAC_KEY_ID=dev-conversation-audit-hmac-v1
OUTBOUND_KEY_ID=dev-outbound-v1
EXECUTOR_VARIABLES=(
    APP_CONVERSATION_AUDIT_WEBHOOK_EXECUTOR_WHATSAPP_CORE_POOL_SIZE
    APP_CONVERSATION_AUDIT_WEBHOOK_EXECUTOR_WHATSAPP_MAX_POOL_SIZE
    APP_CONVERSATION_AUDIT_WEBHOOK_EXECUTOR_WHATSAPP_QUEUE_CAPACITY
    APP_CONVERSATION_AUDIT_WEBHOOK_EXECUTOR_TELEGRAM_CORE_POOL_SIZE
    APP_CONVERSATION_AUDIT_WEBHOOK_EXECUTOR_TELEGRAM_MAX_POOL_SIZE
    APP_CONVERSATION_AUDIT_WEBHOOK_EXECUTOR_TELEGRAM_QUEUE_CAPACITY
)
EXECUTOR_DEFAULTS=(2 4 100 2 4 100)

cleanup() {
    rm -rf -- "$FIXTURE_ROOT"
}
trap cleanup EXIT

fail() {
    echo "FAIL: $*" >&2
    exit 1
}

copy_launcher() {
    local destination="$1"
    cp "$REPOSITORY_ROOT/start-dev-bot.sh" "$destination/start-dev-bot.sh"
    mkdir -p "$destination/infra/scripts/lib/start-dev-bot"
    cp "$REPOSITORY_ROOT/infra/scripts/lib/start-dev-bot/"part-*.sh \
        "$destination/infra/scripts/lib/start-dev-bot/"
}

validate_keyring() {
    local keyring_file="$1"
    local key_id="$2"
    local keyring_content keyring_pattern decoded_length

    [ -f "$keyring_file" ] || fail "keyring was not generated: $(basename "$keyring_file")"
    [ "$(stat -c '%a' "$keyring_file")" = "600" ] \
        || fail "source keyring must use mode 0600: $(basename "$keyring_file")"

    keyring_content="$(tr -d '\r\n' < "$keyring_file")"
    keyring_pattern="^\\{\\\"keys\\\":\\{\\\"${key_id}\\\":\\\"([A-Za-z0-9+/]+={0,2})\\\"\\}\\}$"
    if [[ ! "$keyring_content" =~ $keyring_pattern ]]; then
        fail "generated keyring structure is invalid: $(basename "$keyring_file")"
    fi
    VALIDATED_KEY_MATERIAL="${BASH_REMATCH[1]}"
    decoded_length="$(printf '%s' "$VALIDATED_KEY_MATERIAL" \
        | openssl base64 -d -A 2>/dev/null \
        | wc -c \
        | tr -d '[:space:]')"
    [ "$decoded_length" = "32" ] || fail "generated key must contain exactly 32 bytes"
}

for command_name in awk cmp env flock grep jq mktemp openssl sed sha256sum stat tr wc; do
    command -v "$command_name" >/dev/null 2>&1 \
        || fail "required command is unavailable: $command_name"
done

grep -Fqx 'KEYCLOAK_DEV_SUPERADMIN_INITIAL_PASSWORD=' "$REPOSITORY_ROOT/.env.example" \
    || fail ".env.example must declare the independent DEV Super Admin initial password"
grep -Eq '^RUN apk add --no-cache .*jq([[:space:]]|$)' \
    "$REPOSITORY_ROOT/Dockerfile.dev-bot" \
    || fail "the bundled dev-bot image must install jq required by the canonical start"
grep -Eq '^RUN apk add --no-cache .*util-linux([[:space:]]|$)' \
    "$REPOSITORY_ROOT/Dockerfile.dev-bot" \
    || fail "the bundled dev-bot image must install util-linux for flock"
grep -Eq '^RUN apk add --no-cache .*coreutils([[:space:]]|$)' \
    "$REPOSITORY_ROOT/Dockerfile.dev-bot" \
    || fail "the bundled dev-bot image must install coreutils for bounded cleanup timeouts"
LAUNCHER_BODY="$(cat "$REPOSITORY_ROOT/infra/scripts/lib/start-dev-bot/"part-*.sh)"
cat "$REPOSITORY_ROOT/infra/scripts/lib/start-dev-bot/"part-*.sh \
    > "$FIXTURE_ROOT/launcher-body.sh"
grep -Fq 'proc_stat_line="$(<"/proc/$CONVERSATION_AUDIT_ACTIVATOR_PID/stat")"' \
    <<<"$LAUNCHER_BODY" \
    || fail "activator process-group validation must use the dependency-free Linux procfs contract"
if grep -Fq 'ps -o pgid' <<<"$LAUNCHER_BODY"; then
    fail "activator supervision must not require procps in the bundled Docker-in-Docker image"
fi
grep -Fq '    set +m' <<<"$LAUNCHER_BODY" \
    || fail "activator supervision must explicitly disable job control before setsid"
grep -Fq 'if [ ! -r "$descriptor_path" ] || [ ! -f "$descriptor_path" ]; then' \
    <<<"$LAUNCHER_BODY" \
    || fail "pinned coordinator type validation must use the locale-independent regular-file test"
recovery_predicate="$({
    sed -n \
        '/^conversation_audit_startup_recovery_required() {$/,/^}$/p' \
        <<<"$LAUNCHER_BODY"
} 2>/dev/null)"
[ -n "$recovery_predicate" ] \
    || fail "startup must define one explicit audit recovery predicate"
for recovery_case in 'true false true' 'false true true' 'false false false'; do
    read -r recovery_gate recovery_exposure recovery_expected <<< "$recovery_case"
    if CONVERSATION_AUDIT_STARTUP_GATE_ARMED="$recovery_gate" \
        CONVERSATION_AUDIT_EXPOSURE_MAY_BE_OPEN="$recovery_exposure" \
        bash -c "$recovery_predicate; conversation_audit_startup_recovery_required"; then
        recovery_actual=true
    else
        recovery_actual=false
    fi
    [ "$recovery_actual" = "$recovery_expected" ] \
        || fail "audit recovery predicate rejected gate=$recovery_gate exposure=$recovery_exposure"
done
grep -Fq 'export DEV_BOT_DIND_STATE_DIR="$STATE_DIR"' \
    "$REPOSITORY_ROOT/infra/docker/dev-bot-entrypoint.sh" \
    || fail "the bundled entrypoint must declare its persisted state directory"
grep -Fq 'KEYCLOAK_RUNTIME_ENVIRONMENT: dev' \
    "$REPOSITORY_ROOT/docker-compose.override.yml" \
    || fail "the development Keycloak provisioner must use the DEV runtime contract"
grep -Fq 'KEYCLOAK_EXISTING_MANAGED_REALMS: ${KEYCLOAK_EXISTING_MANAGED_REALMS:?KEYCLOAK_EXISTING_MANAGED_REALMS is required}' \
    "$REPOSITORY_ROOT/docker-compose.yml" \
    || fail "the provisioning service must receive an explicit managed-realm allowlist"
for executor_index in "${!EXECUTOR_VARIABLES[@]}"; do
    executor_variable="${EXECUTOR_VARIABLES[$executor_index]}"
    expected_compose_binding="${executor_variable}: \${${executor_variable}:?${executor_variable} is required}"
    grep -Fq "$expected_compose_binding" "$REPOSITORY_ROOT/docker-compose.yml" \
        || fail "docker-compose.yml must require the generated $executor_variable setting"
done

copy_launcher "$FIXTURE_DIR"
mkdir -p "$FIXTURE_DIR/infra/scripts/lib"
cp "$REPOSITORY_ROOT/infra/scripts/lib/development-docker-access.sh" \
    "$FIXTURE_DIR/infra/scripts/lib/development-docker-access.sh"
cp "$REPOSITORY_ROOT/infra/scripts/generate-outbound-attempt-hmac-keyring.sh" \
    "$FIXTURE_DIR/infra/scripts/generate-outbound-attempt-hmac-keyring.sh"
printf '%s\n' \
    '#!/usr/bin/env bash' \
    'set -Eeuo pipefail' \
    'if [ "${CHECK_OUTBOUND_STAGE_LOCK_INHERITANCE:-0}" = 1 ]; then' \
    '  [ "$(readlink /proc/self/fd/0 2>/dev/null || true)" = /dev/null ] || { echo "fake activator received the pinned program through operational stdin" >&2; exit 78; }' \
    '  stage_lock_file="$PWD/.dev-secrets/outbound-hmac-stage.lock"' \
    '  for descriptor_path in /proc/self/fd/*; do' \
    '    [ "$(readlink "$descriptor_path" 2>/dev/null || true)" != "$stage_lock_file" ] || { echo "fake activator inherited the outbound stage lock" >&2; exit 76; }' \
    '  done' \
    '  exec {stage_lock_probe_fd}<>"$stage_lock_file"' \
    '  if flock -n "$stage_lock_probe_fd"; then echo "bootstrap parent did not retain the outbound stage lock" >&2; exit 77; fi' \
    '  exec {stage_lock_probe_fd}>&-' \
    'fi' \
    'runtime_file="${CONVERSATION_AUDIT_ACTIVATION_RUNTIME_ENV_FILE:?}"' \
    'mkdir -p -- "$(dirname "$runtime_file")"' \
    'runtime_tmp="${runtime_file}.tmp"' \
    'if [ "${1:-}" = "--close-exposure-only" ]; then' \
    '  [ -z "${TRANSITION_EVENT_LOG:-}" ] || printf "%s\n" "activator:close-exposure" >> "$TRANSITION_EVENT_LOG"' \
    '  printf "%s\\n" \' \
    '    "APP_CONVERSATION_AUDIT_ENABLED=true" \' \
    '    "APP_CONVERSATION_AUDIT_API_ENABLED=false" \' \
    '    "APP_CONVERSATION_AUDIT_ALLOWED_TENANT_IDS=" \' \
    '    "APP_CONVERSATION_AUDIT_LEGACY_READ_ENABLED=false" \' \
    '    "APP_CONVERSATION_AUDIT_BACKFILL_ENABLED=false" \' \
    '    "APP_CONVERSATION_AUDIT_BACKFILL_TENANT_ID=" > "$runtime_tmp"' \
    '  chmod 600 "$runtime_tmp"' \
    '  mv -f -- "$runtime_tmp" "$runtime_file"' \
    '  if [ "${HANG_AUDIT_CLOSE:-0}" = 1 ]; then' \
    '    [ -z "${CLOSE_HANG_PID_FILE:-}" ] || printf "%s\n" "$$" > "$CLOSE_HANG_PID_FILE"' \
    '    trap "" TERM' \
    '    while :; do /bin/sleep 1; done' \
    '  fi' \
    '  [ "${FAIL_AUDIT_CLOSE:-0}" != 1 ] || exit 49' \
    '  exit 0' \
    'fi' \
    '[ -z "${TRANSITION_EVENT_LOG:-}" ] || printf "%s\n" "activator:start" >> "$TRANSITION_EVENT_LOG"' \
    'if [ "${FAIL_AUDIT_ACTIVATOR:-0}" = 1 ]; then exit 47; fi' \
    'if [ "${WAIT_AUDIT_ACTIVATOR_FOR_TERM:-0}" = 1 ]; then' \
    '  trap '\''exit 143'\'' TERM' \
    '  bash -c '\''trap "" TERM; while :; do /bin/sleep 1; done'\'' &' \
    '  [ -z "${ACTIVATOR_DESCENDANT_PID_FILE:-}" ] || printf "%s\n" "$!" > "$ACTIVATOR_DESCENDANT_PID_FILE"' \
    '  [ -z "${TRANSITION_EVENT_LOG:-}" ] || printf "%s\n" "activator:waiting" >> "$TRANSITION_EVENT_LOG"' \
    '  while :; do /bin/sleep 1; done' \
    'fi' \
    'if [ "${DIVERGE_AUDIT_RUNTIME_POSTCONDITION:-0}" = 1 ]; then' \
    '  printf "%s\\n" \' \
    '    "APP_CONVERSATION_AUDIT_ENABLED=true" \' \
    '    "APP_CONVERSATION_AUDIT_API_ENABLED=false" \' \
    '    "APP_CONVERSATION_AUDIT_ALLOWED_TENANT_IDS=" \' \
    '    "APP_CONVERSATION_AUDIT_LEGACY_READ_ENABLED=false" \' \
    '    "APP_CONVERSATION_AUDIT_BACKFILL_ENABLED=false" \' \
    '    "APP_CONVERSATION_AUDIT_BACKFILL_TENANT_ID=" > "$runtime_tmp"' \
    'else' \
    '  printf "%s\\n" \' \
    '    "APP_CONVERSATION_AUDIT_ENABLED=true" \' \
    '    "APP_CONVERSATION_AUDIT_API_ENABLED=true" \' \
    '    "APP_CONVERSATION_AUDIT_ALLOWED_TENANT_IDS=13579bdf-2468-4ace-8bdf-0123456789ab" \' \
    '    "APP_CONVERSATION_AUDIT_LEGACY_READ_ENABLED=false" \' \
    '    "APP_CONVERSATION_AUDIT_BACKFILL_ENABLED=false" \' \
    '    "APP_CONVERSATION_AUDIT_BACKFILL_TENANT_ID=" > "$runtime_tmp"' \
    'fi' \
    'chmod 600 "$runtime_tmp"' \
    'mv -f -- "$runtime_tmp" "$runtime_file"' \
    > "$FIXTURE_DIR/infra/scripts/activate-dev-conversation-audit.sh"
chmod 700 "$FIXTURE_DIR/start-dev-bot.sh"
chmod 700 "$FIXTURE_DIR/infra/scripts/activate-dev-conversation-audit.sh"

ROOT_GUARD_DIR="$FIXTURE_ROOT/root-guard-fixture"
ROOT_GUARD_BIN="$FIXTURE_ROOT/root-guard-bin"
ROOT_GUARD_OUTPUT="$FIXTURE_ROOT/root-guard-output.log"
REAL_ID="$(command -v id)"
mkdir -p "$ROOT_GUARD_DIR" "$ROOT_GUARD_BIN"
copy_launcher "$ROOT_GUARD_DIR"
chmod 700 "$ROOT_GUARD_DIR/start-dev-bot.sh"
printf '%s\n' \
    '#!/usr/bin/env bash' \
    'case "${1:-}" in' \
    '  -u|-g) printf "0\\n" ;;' \
    "  *) exec $REAL_ID \"\$@\" ;;" \
    'esac' \
    > "$ROOT_GUARD_BIN/id"
chmod 700 "$ROOT_GUARD_BIN/id"
if (
    cd "$ROOT_GUARD_DIR"
    PATH="$ROOT_GUARD_BIN:$PATH" ./start-dev-bot.sh --prepare-env-only
) > "$ROOT_GUARD_OUTPUT" 2>&1; then
    fail "bootstrap accepted execution as root"
fi
grep -Fq 'must run as the login user, not with sudo/root' "$ROOT_GUARD_OUTPUT" \
    || fail "root rejection did not explain the supported execution identity"
[ ! -e "$ROOT_GUARD_DIR/.env.dev.local" ] \
    && [ ! -e "$ROOT_GUARD_DIR/.dev-secrets" ] \
    || fail "root rejection occurred after mutating local development secrets"

OWNER_GUARD_DIR="$FIXTURE_ROOT/owner-guard-fixture"
OWNER_GUARD_BIN="$FIXTURE_ROOT/owner-guard-bin"
OWNER_GUARD_OUTPUT="$FIXTURE_ROOT/owner-guard-output.log"
REAL_STAT="$(command -v stat)"
mkdir -p "$OWNER_GUARD_DIR" "$OWNER_GUARD_BIN"
copy_launcher "$OWNER_GUARD_DIR"
chmod 700 "$OWNER_GUARD_DIR/start-dev-bot.sh"
printf '%s\n' 'synthetic-owner-guard-content' > "$OWNER_GUARD_DIR/.env.dev.local"
chmod 600 "$OWNER_GUARD_DIR/.env.dev.local"
cp "$OWNER_GUARD_DIR/.env.dev.local" "$OWNER_GUARD_DIR/env.before"
printf '%s\n' \
    '#!/usr/bin/env bash' \
    'if [ "${1:-}" = "-Lc" ] && [ "${2:-}" = "%u" ]; then' \
    '  for argument in "$@"; do' \
    '    case "$argument" in' \
    '      */.env.dev.local) printf "65534\\n"; exit 0 ;;' \
    '    esac' \
    '  done' \
    'fi' \
    "exec $REAL_STAT \"\$@\"" \
    > "$OWNER_GUARD_BIN/stat"
chmod 700 "$OWNER_GUARD_BIN/stat"
if (
    cd "$OWNER_GUARD_DIR"
    PATH="$OWNER_GUARD_BIN:$PATH" ./start-dev-bot.sh --prepare-env-only
) > "$OWNER_GUARD_OUTPUT" 2>&1; then
    fail "bootstrap accepted .env.dev.local owned by another UID"
fi
grep -Fq '.env.dev.local belongs to UID 65534' "$OWNER_GUARD_OUTPUT" \
    || fail "foreign-owner rejection did not identify the ownership mismatch"
cmp -s "$OWNER_GUARD_DIR/env.before" "$OWNER_GUARD_DIR/.env.dev.local" \
    || fail "foreign-owner rejection changed .env.dev.local content"
[ ! -e "$OWNER_GUARD_DIR/.dev-secrets" ] \
    || fail "foreign-owner rejection occurred after creating local secret state"

HOST_OVERLAY_GUARD_DIR="$FIXTURE_ROOT/host-overlay-guard-fixture"
HOST_OVERLAY_GUARD_OUTPUT="$FIXTURE_ROOT/host-overlay-guard-output.log"
mkdir -p "$HOST_OVERLAY_GUARD_DIR"
copy_launcher "$HOST_OVERLAY_GUARD_DIR"
chmod 700 "$HOST_OVERLAY_GUARD_DIR/start-dev-bot.sh"
if (
    cd "$HOST_OVERLAY_GUARD_DIR"
    DEV_BOT_EXTRA_COMPOSE_FILE=docker-compose.dev-bot-image.yml \
        ./start-dev-bot.sh --prepare-env-only
) > "$HOST_OVERLAY_GUARD_OUTPUT" 2>&1; then
    fail "host bootstrap accepted the bundled-image Compose overlay"
fi
grep -Fq 'reserved for the bundled dev-bot wrapper' "$HOST_OVERLAY_GUARD_OUTPUT" \
    || fail "host overlay rejection did not explain the source-build boundary"
[ ! -e "$HOST_OVERLAY_GUARD_DIR/.env.dev.local" ] \
    && [ ! -e "$HOST_OVERLAY_GUARD_DIR/.dev-secrets" ] \
    || fail "host overlay rejection occurred after mutating local development state"

DIND_OVERLAY_GUARD_DIR="$FIXTURE_ROOT/dind-overlay-guard-fixture"
DIND_OVERLAY_GUARD_OUTPUT="$FIXTURE_ROOT/dind-overlay-guard-output.log"
DIND_OVERLAY_FAKE_BIN="$FIXTURE_ROOT/dind-overlay-fake-bin"
DIND_OVERLAY_STATE_DIR="$FIXTURE_ROOT/dind-overlay-state"
mkdir -p "$DIND_OVERLAY_GUARD_DIR" "$DIND_OVERLAY_FAKE_BIN" \
    "$DIND_OVERLAY_STATE_DIR"
chmod 700 "$DIND_OVERLAY_STATE_DIR"
copy_launcher "$DIND_OVERLAY_GUARD_DIR"
mkdir -p "$DIND_OVERLAY_GUARD_DIR/infra/scripts"
cp "$REPOSITORY_ROOT/infra/scripts/generate-outbound-attempt-hmac-keyring.sh" \
    "$DIND_OVERLAY_GUARD_DIR/infra/scripts/generate-outbound-attempt-hmac-keyring.sh"
chmod 700 "$DIND_OVERLAY_GUARD_DIR/start-dev-bot.sh"
: > "$DIND_OVERLAY_GUARD_DIR/docker-compose.dev-bot-image.yml"

if (
    cd "$DIND_OVERLAY_GUARD_DIR"
    DEV_BOT_DIND_WRAPPER=1 \
        DEV_BOT_EXTRA_COMPOSE_FILE=docker-compose.dev-bot-image.yml \
        ./start-dev-bot.sh --prepare-env-only
) > "$DIND_OVERLAY_GUARD_OUTPUT" 2>&1; then
    fail "non-root host spoofed the Docker-in-Docker wrapper mode"
fi
grep -Fq 'valid only in the root Docker-in-Docker entrypoint' "$DIND_OVERLAY_GUARD_OUTPUT" \
    || fail "wrapper spoof rejection did not explain the required runtime identity"
[ ! -e "$DIND_OVERLAY_GUARD_DIR/.env.dev.local" ] \
    && [ ! -e "$DIND_OVERLAY_GUARD_DIR/.dev-secrets" ] \
    || fail "wrapper spoof rejection occurred after mutating local development state"

printf '%s\n' \
    '#!/usr/bin/env bash' \
    'case "${1:-}" in' \
    '  -u|-g) printf "0\n" ;;' \
    "  *) exec $REAL_ID \"\$@\" ;;" \
    'esac' \
    > "$DIND_OVERLAY_FAKE_BIN/id"
printf '%s\n' \
    '#!/usr/bin/env bash' \
    'if { [ "${1:-}" = "-Lc" ] || [ "${1:-}" = "-c" ]; } && [ "${2:-}" = "%u" ]; then printf "0\n"; exit 0; fi' \
    "exec $REAL_STAT \"\$@\"" \
    > "$DIND_OVERLAY_FAKE_BIN/stat"
chmod 700 "$DIND_OVERLAY_FAKE_BIN/id" "$DIND_OVERLAY_FAKE_BIN/stat"

if (
    cd "$DIND_OVERLAY_GUARD_DIR"
    PATH="$DIND_OVERLAY_FAKE_BIN:$PATH" \
        DEV_BOT_DIND_WRAPPER=1 \
        DEV_BOT_EXTRA_COMPOSE_FILE=docker-compose.untrusted.yml \
        ./start-dev-bot.sh --prepare-env-only
) > "$DIND_OVERLAY_GUARD_OUTPUT" 2>&1; then
    fail "bundled wrapper accepted a non-canonical Compose overlay"
fi
grep -Fq 'requires docker-compose.dev-bot-image.yml' "$DIND_OVERLAY_GUARD_OUTPUT" \
    || fail "bundled wrapper did not require its canonical image overlay"
[ ! -e "$DIND_OVERLAY_GUARD_DIR/.env.dev.local" ] \
    && [ ! -e "$DIND_OVERLAY_GUARD_DIR/.dev-secrets" ] \
    || fail "bundled overlay rejection occurred after mutating local development state"

ln -s "$DIND_OVERLAY_STATE_DIR/not-the-canonical-env" \
    "$DIND_OVERLAY_GUARD_DIR/.env.dev.local"
if (
    cd "$DIND_OVERLAY_GUARD_DIR"
    PATH="$DIND_OVERLAY_FAKE_BIN:$PATH" \
        DEV_BOT_DIND_WRAPPER=1 \
        DEV_BOT_DIND_STATE_DIR="$DIND_OVERLAY_STATE_DIR" \
        DEV_BOT_EXTRA_COMPOSE_FILE=docker-compose.dev-bot-image.yml \
        ./start-dev-bot.sh --prepare-env-only
) > "$DIND_OVERLAY_GUARD_OUTPUT" 2>&1; then
    fail "bundled wrapper accepted a non-canonical persisted env symlink"
fi
if ! grep -Fq 'requires the canonical persisted .env.dev.local symlink' \
    "$DIND_OVERLAY_GUARD_OUTPUT"; then
    sed -n '1,20p' "$DIND_OVERLAY_GUARD_OUTPUT" >&2
    fail "bundled wrapper did not reject a non-canonical persisted env symlink"
fi
rm -- "$DIND_OVERLAY_GUARD_DIR/.env.dev.local"
ln -s "$DIND_OVERLAY_STATE_DIR/.env.dev.local" \
    "$DIND_OVERLAY_GUARD_DIR/.env.dev.local"

if ! (
    cd "$DIND_OVERLAY_GUARD_DIR"
    PATH="$DIND_OVERLAY_FAKE_BIN:$PATH" \
        DEV_BOT_DIND_WRAPPER=1 \
        DEV_BOT_DIND_STATE_DIR="$DIND_OVERLAY_STATE_DIR" \
        DEV_BOT_EXTRA_COMPOSE_FILE=docker-compose.dev-bot-image.yml \
        ./start-dev-bot.sh --prepare-env-only
) >> "$DIND_OVERLAY_GUARD_OUTPUT" 2>&1; then
    fail "bundled wrapper rejected its canonical image overlay"
fi
[ -f "$DIND_OVERLAY_STATE_DIR/.env.dev.local" ] \
    && [ -L "$DIND_OVERLAY_GUARD_DIR/.env.dev.local" ] \
    || fail "bundled wrapper rejected its canonical image overlay"

DIND_OVERLAY_DOCKER_LOG="$DIND_OVERLAY_GUARD_DIR/docker.log"
mkdir -p "$DIND_OVERLAY_GUARD_DIR/infra/scripts/lib"
cp "$REPOSITORY_ROOT/infra/scripts/lib/development-docker-access.sh" \
    "$DIND_OVERLAY_GUARD_DIR/infra/scripts/lib/development-docker-access.sh"
: > "$DIND_OVERLAY_GUARD_DIR/docker-compose.yml"
: > "$DIND_OVERLAY_GUARD_DIR/docker-compose.override.yml"
: > "$DIND_OVERLAY_GUARD_DIR/docker-compose.dev-bot.yml"
printf '%s\n' \
    '#!/usr/bin/env bash' \
    'if [ "${1:-}" = context ] && [ "${2:-}" = inspect ]; then printf "%s\n" unix:///var/run/docker.sock; exit 0; fi' \
    'if [ "${1:-}" = info ]; then exit 0; fi' \
    'printf "%s\n" "$*" >> "$DIND_OVERLAY_DOCKER_LOG"' \
    'exit 0' \
    > "$DIND_OVERLAY_FAKE_BIN/docker"
chmod 700 "$DIND_OVERLAY_FAKE_BIN/docker"
(
    cd "$DIND_OVERLAY_GUARD_DIR"
    PATH="$DIND_OVERLAY_FAKE_BIN:$PATH" \
        DIND_OVERLAY_DOCKER_LOG="$DIND_OVERLAY_DOCKER_LOG" \
        DEV_BOT_DIND_WRAPPER=1 \
        DEV_BOT_DIND_STATE_DIR="$DIND_OVERLAY_STATE_DIR" \
        DEV_BOT_EXTRA_COMPOSE_FILE=docker-compose.dev-bot-image.yml \
        NGROK_AUTHTOKEN=synthetic-local-token \
        APP_BASE_URL=https://synthetic.invalid \
        ./start-dev-bot.sh --check
) >> "$DIND_OVERLAY_GUARD_OUTPUT" 2>&1
grep -Fq -- '-f docker-compose.dev-bot-image.yml config --quiet' \
    "$DIND_OVERLAY_DOCKER_LOG" \
    || fail "bundled wrapper did not pass its canonical image overlay to Compose"
