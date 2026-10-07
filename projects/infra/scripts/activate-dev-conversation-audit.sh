#!/usr/bin/env bash

set -Eeuo pipefail

# Local-only coordinator for the fail-closed Conversation Audit activation
# lifecycle. It intentionally emits only phase-level evidence: tenant/database
# identifiers, readiness fingerprints, paths and backup material stay private.
umask 077

SCRIPT_SOURCE="${BASH_SOURCE[0]:-}"
if [ -n "${CONVERSATION_AUDIT_ACTIVATION_PROJECT_DIR:-}" ]; then
    # A pinned /proc/self/fd path may be closed by Bash after it loads the
    # program, leaving BASH_SOURCE intentionally ephemeral. The caller-pinned
    # repository root is validated below and must win before dirname/cd.
    DEFAULT_PROJECT_DIR="$CONVERSATION_AUDIT_ACTIVATION_PROJECT_DIR"
elif [ -n "$SCRIPT_SOURCE" ]; then
    SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_SOURCE")" && pwd -P)"
    DEFAULT_PROJECT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd -P)"
else
    echo "[conversation-audit-activation] ERROR: descriptor/stdin execution requires an explicit activation project directory" >&2
    exit 1
fi
PROJECT_DIR="${CONVERSATION_AUDIT_ACTIVATION_PROJECT_DIR:-$DEFAULT_PROJECT_DIR}"
RUNTIME_ENV_FILE="${CONVERSATION_AUDIT_ACTIVATION_RUNTIME_ENV_FILE:-$PROJECT_DIR/.dev-secrets/conversation-audit-runtime.env}"
MAX_ATTEMPTS="${CONVERSATION_AUDIT_ACTIVATION_MAX_ATTEMPTS:-200}"
COMMAND_TIMEOUT_SECONDS="${CONVERSATION_AUDIT_ACTIVATION_COMMAND_TIMEOUT_SECONDS:-300}"
BACKUP_ROOT="${CONVERSATION_AUDIT_ACTIVATION_BACKUP_ROOT:-/tmp/saas-service-conversation-audit-backups-$(id -u)}"
BACKUP_ROOT_WAS_CONFIGURED=false
[ -z "${CONVERSATION_AUDIT_ACTIVATION_BACKUP_ROOT+x}" ] \
    || BACKUP_ROOT_WAS_CONFIGURED=true

GENERATED_ENV_FILE="$PROJECT_DIR/.env.dev.local"
OPTIONAL_ENV_FILE="$PROJECT_DIR/.env"
BASE_COMPOSE_FILE="$PROJECT_DIR/docker-compose.yml"
DEV_COMPOSE_FILE="$PROJECT_DIR/docker-compose.override.yml"
BOT_COMPOSE_FILE="$PROJECT_DIR/docker-compose.dev-bot.yml"
BACKFILL_COMPOSE_FILE="$PROJECT_DIR/docker-compose.conversation-audit-backfill.yml"
AES_KEYRING_FILE="$PROJECT_DIR/.dev-secrets/conversation-audit-aes-keyring.json"
HMAC_KEYRING_FILE="$PROJECT_DIR/.dev-secrets/conversation-audit-hmac-keyring.json"
DEV_SECRETS_DIRECTORY="$PROJECT_DIR/.dev-secrets"
EXTRA_COMPOSE_FILE=""

WORK_DIR=""
RUNTIME_TEMP=""
BACKUP_RUN_DIR=""
BACKUP_CUSTODY_DIR=""
BACKUP_VERIFIED=false
DRILL_DATABASE=""
ROLLBACK_REQUIRED=false
KEY_CONFIGURATION_VALIDATED=false
LEGACY_ZERO_RISK=false
EXISTING_RUNTIME_OVERLAY_PRESENT=false
EXISTING_RUNTIME_FEATURE_ENABLED=false
EXISTING_RUNTIME_LEGACY_READ_ENABLED=false
LOCK_FD=""
LIFECYCLE_LOCK_ACQUIRED=false
TENANT_ID=""
TENANT_DATABASE=""
REQUESTED_TENANT_ID="${CONVERSATION_AUDIT_ACTIVATION_TENANT_ID:-}"
EXPECTED_LEGACY_FINGERPRINT=""
EXPECTED_FINAL_FINGERPRINT=""
ATTEMPTS_USED=0
CLOSE_EXPOSURE_ONLY=false
CLOSE_EXPOSURE_COMPLETED=false

declare -a COMPOSE_PREFIX=()
declare -a COMPOSE_ENV_ARGS=()
declare -a COMPOSE_FILES=()

log() {
    printf '[conversation-audit-activation] %s\n' "$*"
}

die() {
    printf '[conversation-audit-activation] ERROR: %s\n' "$*" >&2
    exit 1
}

case "$#" in
    0)
        ;;
    1)
        [ "$1" = "--close-exposure-only" ] \
            || die "unsupported Conversation Audit activation argument"
        CLOSE_EXPOSURE_ONLY=true
        ;;
    *)
        die "Conversation Audit activation accepts either zero arguments or --close-exposure-only"
        ;;
esac

require_command() {
    command -v "$1" >/dev/null 2>&1 \
        || die "required local command is unavailable: $1"
}

validate_regular_file() {
    local file="$1"
    local label="$2"

    if [ -L "$file" ] || [ ! -f "$file" ]; then
        die "$label must be a regular non-symbolic-link file"
    fi
}

validate_owner_only_file() {
    local file="$1"
    local label="$2"
    local owner mode

    validate_regular_file "$file" "$label"
    owner="$(stat -Lc '%u' -- "$file")"
    mode="$(stat -Lc '%a' -- "$file")"
    if [ "$owner" != "$(id -u)" ] || [ "$mode" != "600" ]; then
        die "$label must be owned by the current user with mode 0600"
    fi
}

validate_owner_only_directory() {
    local directory="$1"
    local label="$2"
    local owner mode

    if [ -L "$directory" ] || [ ! -d "$directory" ]; then
        die "$label must be a regular non-symbolic-link directory"
    fi
    owner="$(stat -Lc '%u' -- "$directory")"
    mode="$(stat -Lc '%a' -- "$directory")"
    if [ "$owner" != "$(id -u)" ] || [ "$mode" != "700" ]; then
        die "$label must be owned by the current user with mode 0700"
    fi
}

configure_local_runtime_topology() {
    local requested_runtime_file="$RUNTIME_ENV_FILE"
    local state_directory state_owner state_mode
    local expected_secrets_link expected_generated_link expected_runtime_link

    if [ "${DEV_BOT_DIND_WRAPPER:-}" = "1" ]; then
        state_directory="${DEV_BOT_DIND_STATE_DIR:-}"
        if [ -z "$state_directory" ] \
            || [[ "$state_directory" != /* ]] \
            || [ "$state_directory" = "/" ] \
            || [ -L "$state_directory" ] \
            || [ ! -d "$state_directory" ]; then
            die "bundled DEV activation requires its canonical regular state directory"
        fi
        state_directory="$(realpath -e -- "$state_directory")"
        state_owner="$(stat -Lc '%u' -- "$state_directory")"
        state_mode="$(stat -Lc '%a' -- "$state_directory")"
        if [ "$state_owner" != "0" ] \
            || (( (8#$state_mode & 8#022) != 0 )); then
            die "bundled DEV state must be root-owned and not writable by group or others"
        fi
        [ "$(id -u)" = "0" ] \
            || die "bundled DEV activation must run inside its root DIND wrapper"

        expected_secrets_link="$state_directory/dev-secrets"
        expected_generated_link="$state_directory/.env.dev.local"
        expected_runtime_link="$PROJECT_DIR/.dev-secrets/conversation-audit-runtime.env"
        if [ ! -L "$PROJECT_DIR/.dev-secrets" ] \
            || [ "$(readlink -- "$PROJECT_DIR/.dev-secrets")" != "$expected_secrets_link" ]; then
            die "bundled DEV secrets symlink does not target canonical state"
        fi
        if [ ! -L "$PROJECT_DIR/.env.dev.local" ] \
            || [ "$(readlink -- "$PROJECT_DIR/.env.dev.local")" != "$expected_generated_link" ]; then
            die "bundled DEV environment symlink does not target canonical state"
        fi
        if [ "$requested_runtime_file" != "$expected_runtime_link" ] \
            && [ "$requested_runtime_file" != "$expected_secrets_link/conversation-audit-runtime.env" ]; then
            die "bundled DEV runtime overlay does not use canonical state"
        fi
        case "${DEV_BOT_EXTRA_COMPOSE_FILE:-}" in
            docker-compose.dev-bot-image.yml|./docker-compose.dev-bot-image.yml|"$PROJECT_DIR/docker-compose.dev-bot-image.yml")
                ;;
            *)
                die "bundled DEV activation requires its canonical image overlay"
                ;;
        esac

        DEV_SECRETS_DIRECTORY="$expected_secrets_link"
        GENERATED_ENV_FILE="$expected_generated_link"
        RUNTIME_ENV_FILE="$expected_secrets_link/conversation-audit-runtime.env"
        AES_KEYRING_FILE="$expected_secrets_link/conversation-audit-aes-keyring.json"
        HMAC_KEYRING_FILE="$expected_secrets_link/conversation-audit-hmac-keyring.json"
        EXTRA_COMPOSE_FILE="$PROJECT_DIR/docker-compose.dev-bot-image.yml"
        if [ "$BACKUP_ROOT_WAS_CONFIGURED" != true ]; then
            BACKUP_ROOT="$state_directory/conversation-audit-backups"
        fi
        return 0
    fi

    if [ -n "${DEV_BOT_EXTRA_COMPOSE_FILE:-}" ] \
        || [ -n "${DEV_BOT_DIND_STATE_DIR:-}" ]; then
        die "bundled DEV runtime selectors are forbidden outside the DIND wrapper"
    fi
    [ "$requested_runtime_file" = "$PROJECT_DIR/.dev-secrets/conversation-audit-runtime.env" ] \
        || die "runtime overlay must use the canonical local DEV location"
}

runtime_state_is_safe() {
    local feature_enabled="$1"
    local api_enabled="$2"
    local allowed_tenant_ids="$3"
    local legacy_read_enabled="$4"
    local backfill_enabled="$5"
    local backfill_tenant_id="$6"
    local uuid_pattern='^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'

    case "$feature_enabled:$api_enabled:$legacy_read_enabled:$backfill_enabled" in
        true:true:true:true|true:true:true:false|true:true:false:true|true:true:false:false|true:false:true:true|true:false:true:false|true:false:false:true|true:false:false:false|false:true:true:true|false:true:true:false|false:true:false:true|false:true:false:false|false:false:true:true|false:false:true:false|false:false:false:true|false:false:false:false)
            ;;
        *) return 1 ;;
    esac
    if { [ -n "$allowed_tenant_ids" ] && [[ ! "$allowed_tenant_ids" =~ $uuid_pattern ]]; } \
        || { [ -n "$backfill_tenant_id" ] && [[ ! "$backfill_tenant_id" =~ $uuid_pattern ]]; }; then
        return 1
    fi
    if [ "$api_enabled" = true ] \
        && { [ "$feature_enabled" != true ] \
            || [ -z "$allowed_tenant_ids" ] \
            || [ "$legacy_read_enabled" != false ] \
            || [ "$backfill_enabled" != false ] \
            || [ -n "$backfill_tenant_id" ]; }; then
        return 1
    fi
    if [ -n "$allowed_tenant_ids" ] \
        && { [ "$feature_enabled" != true ] \
            || [ "$legacy_read_enabled" != false ] \
            || [ "$backfill_enabled" != false ] \
            || [ -n "$backfill_tenant_id" ]; }; then
        return 1
    fi
    if [ "$backfill_enabled" = true ]; then
        [ "$feature_enabled" = true ] \
            && [ "$api_enabled" = false ] \
            && [ -z "$allowed_tenant_ids" ] \
            && [ -n "$backfill_tenant_id" ] \
            || return 1
    elif [ -n "$backfill_tenant_id" ]; then
        return 1
    fi
    if [ "$legacy_read_enabled" = true ] \
        && { [ "$feature_enabled" != true ] \
            || [ "$api_enabled" != false ] \
            || [ -n "$allowed_tenant_ids" ]; }; then
        return 1
    fi
    if [ "$feature_enabled" = false ] \
        && { [ "$api_enabled" != false ] \
            || [ -n "$allowed_tenant_ids" ] \
            || [ "$legacy_read_enabled" != false ] \
            || [ "$backfill_enabled" != false ] \
            || [ -n "$backfill_tenant_id" ]; }; then
        return 1
    fi
    return 0
}

read_existing_runtime_overlay() {
    local line key value line_number=0
    local -A seen=()
    local -A values=()
    local -a required_keys=(
        APP_CONVERSATION_AUDIT_ENABLED
        APP_CONVERSATION_AUDIT_API_ENABLED
        APP_CONVERSATION_AUDIT_ALLOWED_TENANT_IDS
        APP_CONVERSATION_AUDIT_LEGACY_READ_ENABLED
        APP_CONVERSATION_AUDIT_BACKFILL_ENABLED
        APP_CONVERSATION_AUDIT_BACKFILL_TENANT_ID
    )

    if [ ! -e "$RUNTIME_ENV_FILE" ] && [ ! -L "$RUNTIME_ENV_FILE" ]; then
        return 0
    fi
    validate_owner_only_file "$RUNTIME_ENV_FILE" "conversation audit runtime overlay"

    while IFS= read -r line || [ -n "$line" ]; do
        ((line_number += 1))
        if [[ "$line" != *=* ]] || [[ "$line" == *$'\r'* ]]; then
            die "conversation audit runtime overlay contains a malformed line"
        fi
        key="${line%%=*}"
        value="${line#*=}"
        if [ -n "${seen[$key]+configured}" ]; then
            die "conversation audit runtime overlay contains a duplicate key"
        fi
        case "$key" in
            APP_CONVERSATION_AUDIT_ENABLED|APP_CONVERSATION_AUDIT_API_ENABLED|APP_CONVERSATION_AUDIT_LEGACY_READ_ENABLED|APP_CONVERSATION_AUDIT_BACKFILL_ENABLED)
                [ "$value" = "true" ] || [ "$value" = "false" ] \
                    || die "conversation audit runtime overlay contains an invalid boolean"
                ;;
            APP_CONVERSATION_AUDIT_ALLOWED_TENANT_IDS|APP_CONVERSATION_AUDIT_BACKFILL_TENANT_ID)
                if [ -n "$value" ] \
                    && [[ ! "$value" =~ ^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$ ]]; then
                    die "conversation audit runtime overlay contains an invalid tenant identifier"
                fi
                ;;
            *)
                die "conversation audit runtime overlay contains an unknown key"
                ;;
        esac
        seen["$key"]=true
        values["$key"]="$value"
    done < "$RUNTIME_ENV_FILE"

    for key in "${required_keys[@]}"; do
        [ -n "${seen[$key]+configured}" ] \
            || die "conversation audit runtime overlay is incomplete"
    done
    runtime_state_is_safe \
        "${values[APP_CONVERSATION_AUDIT_ENABLED]}" \
        "${values[APP_CONVERSATION_AUDIT_API_ENABLED]}" \
        "${values[APP_CONVERSATION_AUDIT_ALLOWED_TENANT_IDS]}" \
        "${values[APP_CONVERSATION_AUDIT_LEGACY_READ_ENABLED]}" \
        "${values[APP_CONVERSATION_AUDIT_BACKFILL_ENABLED]}" \
        "${values[APP_CONVERSATION_AUDIT_BACKFILL_TENANT_ID]}" \
        || die "conversation audit runtime overlay contains an unsafe lifecycle state"

    EXISTING_RUNTIME_OVERLAY_PRESENT=true
    EXISTING_RUNTIME_FEATURE_ENABLED="${values[APP_CONVERSATION_AUDIT_ENABLED]}"
    EXISTING_RUNTIME_LEGACY_READ_ENABLED="${values[APP_CONVERSATION_AUDIT_LEGACY_READ_ENABLED]}"
}

owner_only_directory_is_valid() {
    local directory="$1"
    [ ! -L "$directory" ] \
        && [ -d "$directory" ] \
        && [ "$(stat -Lc '%u' -- "$directory" 2>/dev/null)" = "$(id -u)" ] \
        && [ "$(stat -Lc '%a' -- "$directory" 2>/dev/null)" = "700" ]
}

owner_only_file_is_valid() {
    local file="$1"
    [ ! -L "$file" ] \
        && [ -f "$file" ] \
        && [ "$(stat -Lc '%u' -- "$file" 2>/dev/null)" = "$(id -u)" ] \
        && [ "$(stat -Lc '%a' -- "$file" 2>/dev/null)" = "600" ]
}

write_runtime_overlay_safely() {
    local feature_enabled="$1"
    local api_enabled="$2"
    local allowed_tenant_ids="$3"
    local legacy_read_enabled="$4"
    local backfill_enabled="$5"
    local backfill_tenant_id="$6"
    local runtime_directory

    runtime_directory="$(dirname "$RUNTIME_ENV_FILE")"
    owner_only_directory_is_valid "$runtime_directory" || return 1
    if [ -e "$RUNTIME_ENV_FILE" ] || [ -L "$RUNTIME_ENV_FILE" ]; then
        owner_only_file_is_valid "$RUNTIME_ENV_FILE" || return 1
    fi
    runtime_state_is_safe "$feature_enabled" "$api_enabled" "$allowed_tenant_ids" \
        "$legacy_read_enabled" "$backfill_enabled" "$backfill_tenant_id" \
        || return 1

    RUNTIME_TEMP="$(mktemp "$runtime_directory/.conversation-audit-runtime.tmp.XXXXXX")" \
        || return 1
    if ! {
        printf 'APP_CONVERSATION_AUDIT_ENABLED=%s\n' "$feature_enabled"
        printf 'APP_CONVERSATION_AUDIT_API_ENABLED=%s\n' "$api_enabled"
        printf 'APP_CONVERSATION_AUDIT_ALLOWED_TENANT_IDS=%s\n' "$allowed_tenant_ids"
        printf 'APP_CONVERSATION_AUDIT_LEGACY_READ_ENABLED=%s\n' "$legacy_read_enabled"
        printf 'APP_CONVERSATION_AUDIT_BACKFILL_ENABLED=%s\n' "$backfill_enabled"
        printf 'APP_CONVERSATION_AUDIT_BACKFILL_TENANT_ID=%s\n' "$backfill_tenant_id"
    } > "$RUNTIME_TEMP" \
        || ! chmod 600 -- "$RUNTIME_TEMP" \
        || ! mv -f -- "$RUNTIME_TEMP" "$RUNTIME_ENV_FILE"; then
        rm -f -- "$RUNTIME_TEMP" 2>/dev/null || true
        RUNTIME_TEMP=""
        return 1
    fi
    RUNTIME_TEMP=""
    owner_only_file_is_valid "$RUNTIME_ENV_FILE" || return 1

    export APP_CONVERSATION_AUDIT_ENABLED="$feature_enabled"
    export APP_CONVERSATION_AUDIT_API_ENABLED="$api_enabled"
    export APP_CONVERSATION_AUDIT_ALLOWED_TENANT_IDS="$allowed_tenant_ids"
    export APP_CONVERSATION_AUDIT_LEGACY_READ_ENABLED="$legacy_read_enabled"
    export APP_CONVERSATION_AUDIT_BACKFILL_ENABLED="$backfill_enabled"
    export APP_CONVERSATION_AUDIT_BACKFILL_TENANT_ID="$backfill_tenant_id"
}

write_runtime_overlay() {
    write_runtime_overlay_safely "$@" \
        || die "could not persist the owner-only Conversation Audit runtime overlay"
}

run_regular_compose() {
    timeout --signal=TERM --kill-after=2s "$COMMAND_TIMEOUT_SECONDS" \
        "${COMPOSE_PREFIX[@]}" "${COMPOSE_ENV_ARGS[@]}" "${COMPOSE_FILES[@]}" "$@"
}

run_backfill_compose() {
    timeout --signal=TERM --kill-after=2s "$COMMAND_TIMEOUT_SECONDS" \
        "${COMPOSE_PREFIX[@]}" "${COMPOSE_ENV_ARGS[@]}" "${COMPOSE_FILES[@]}" \
        -f "$BACKFILL_COMPOSE_FILE" "$@"
}

wait_for_backend_readiness() {
    local attempt response_file="$WORK_DIR/backend-readiness.json"

    for ((attempt = 1; attempt <= COMMAND_TIMEOUT_SECONDS; attempt++)); do
        if curl --fail --silent --show-error \
            --connect-timeout 1 --max-time 1 \
            http://127.0.0.1:8080/actuator/health/readiness \
            > "$response_file" 2>/dev/null \
            && jq -e '.status == "UP"' "$response_file" >/dev/null 2>&1; then
            return 0
        fi
        sleep 1
    done
    return 1
}

recreate_regular_backend() {
    if ! run_regular_compose up -d --no-deps --force-recreate backend \
        >/dev/null 2>&1; then
        printf '[conversation-audit-activation] ERROR: regular backend Compose recreate failed or exceeded %s seconds\n' \
            "$COMMAND_TIMEOUT_SECONDS" >&2
        return 1
    fi
    if ! wait_for_backend_readiness; then
        printf '[conversation-audit-activation] ERROR: regular backend readiness did not become UP within %s seconds\n' \
            "$COMMAND_TIMEOUT_SECONDS" >&2
        return 1
    fi
}

recreate_backfill_backend() {
    if ! run_backfill_compose up -d --no-deps --force-recreate backend \
        >/dev/null 2>&1; then
        printf '[conversation-audit-activation] ERROR: backfill backend Compose recreate failed or exceeded %s seconds\n' \
            "$COMMAND_TIMEOUT_SECONDS" >&2
        return 1
    fi
    if ! wait_for_backend_readiness; then
        printf '[conversation-audit-activation] ERROR: backfill backend readiness did not become UP within %s seconds\n' \
            "$COMMAND_TIMEOUT_SECONDS" >&2
        return 1
    fi
}

validate_closed_regular_compose_configuration() {
    local feature_enabled="$1"
    local legacy_read_enabled="$2"

    run_regular_compose config --format json 2>/dev/null \
        | jq -e --arg feature "$feature_enabled" --arg legacy "$legacy_read_enabled" '
            .services.backend.environment as $environment
            | $environment.APP_CONVERSATION_AUDIT_ENABLED == $feature
              and $environment.APP_CONVERSATION_AUDIT_API_ENABLED == "false"
              and $environment.APP_CONVERSATION_AUDIT_ALLOWED_TENANT_IDS == ""
              and $environment.APP_CONVERSATION_AUDIT_LEGACY_READ_ENABLED == $legacy
              and $environment.APP_CONVERSATION_AUDIT_BACKFILL_ENABLED == "false"
              and $environment.APP_CONVERSATION_AUDIT_BACKFILL_TENANT_ID == ""
        ' >/dev/null 2>&1
}

validate_running_backend_closed_configuration() {
    local feature_enabled="$1"
    local legacy_read_enabled="$2"

    printf '%s\n%s\n' "$feature_enabled" "$legacy_read_enabled" \
        | run_regular_compose exec -T backend sh -eu -c '
            IFS= read -r expected_feature
            IFS= read -r expected_legacy
            [ "${APP_CONVERSATION_AUDIT_ENABLED:-}" = "$expected_feature" ]
            [ "${APP_CONVERSATION_AUDIT_API_ENABLED:-}" = "false" ]
            [ -z "${APP_CONVERSATION_AUDIT_ALLOWED_TENANT_IDS:-}" ]
            [ "${APP_CONVERSATION_AUDIT_LEGACY_READ_ENABLED:-}" = "$expected_legacy" ]
            [ "${APP_CONVERSATION_AUDIT_BACKFILL_ENABLED:-}" = "false" ]
            [ -z "${APP_CONVERSATION_AUDIT_BACKFILL_TENANT_ID:-}" ]
        ' >/dev/null 2>&1
}

stop_and_verify_regular_backend() {
    local stop_status=0
    local running_backend=""
    local inspect_status=0

    if (( ${#COMPOSE_PREFIX[@]} == 0 )); then
        return 1
    fi
    run_regular_compose stop --timeout "$COMMAND_TIMEOUT_SECONDS" backend \
        >/dev/null 2>&1 || stop_status=$?
    running_backend="$(
        run_regular_compose ps --status running -q backend 2>/dev/null
    )" || inspect_status=$?
    [ "$stop_status" -eq 0 ] \
        && [ "$inspect_status" -eq 0 ] \
        && [ -z "$running_backend" ]
}

close_conversation_audit_exposure_only() {
    write_runtime_overlay \
        "$EXISTING_RUNTIME_FEATURE_ENABLED" false "" \
        "$EXISTING_RUNTIME_LEGACY_READ_ENABLED" false ""
    validate_closed_regular_compose_configuration \
        "$EXISTING_RUNTIME_FEATURE_ENABLED" \
        "$EXISTING_RUNTIME_LEGACY_READ_ENABLED" \
        || die "Docker Compose did not confirm the fail-closed Conversation Audit state"
    recreate_regular_backend \
        || die "backend did not become ready with Conversation Audit exposure closed"
    validate_running_backend_closed_configuration \
        "$EXISTING_RUNTIME_FEATURE_ENABLED" \
        "$EXISTING_RUNTIME_LEGACY_READ_ENABLED" \
        || die "running backend did not confirm the fail-closed Conversation Audit state"
    CLOSE_EXPOSURE_COMPLETED=true
    log "Conversation Audit exposure is closed and the regular backend state was verified."
}

postgres_psql() {
    local database="$1"
    shift
    run_regular_compose exec -T postgres-app \
        psql -v ON_ERROR_STOP=1 -U "$DB_USER" -d "$database" -Atq "$@"
}

resolve_single_provisioned_tenant() {
    local selection_file="$WORK_DIR/provisioned-tenant"
    local sql
    local -a rows=()

    if [ -n "$REQUESTED_TENANT_ID" ]; then
        [[ "$REQUESTED_TENANT_ID" =~ ^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$ ]] \
            || die "explicit local activation tenant must be a canonical UUID"
        sql=$'/* conversation-audit-activation:tenant-selection */\nSELECT id::text || chr(9) || database_slug\n  FROM tenants\n WHERE active = TRUE\n   AND database_provisioned = TRUE\n   AND database_slug IS NOT NULL\n   AND id = :\'activation_tenant_id\'::uuid\n ORDER BY id;'
        printf '%s\n' "$sql" \
            | postgres_psql saas_tenant -v "activation_tenant_id=$REQUESTED_TENANT_ID" \
                > "$selection_file" 2>/dev/null \
            || die "could not resolve the explicit local activation tenant"
    else
        sql=$'/* conversation-audit-activation:tenant-selection */\nSELECT id::text || chr(9) || database_slug\n  FROM tenants\n WHERE active = TRUE\n   AND database_provisioned = TRUE\n   AND database_slug IS NOT NULL\n ORDER BY id;'
        printf '%s\n' "$sql" \
            | postgres_psql saas_tenant > "$selection_file" 2>/dev/null \
            || die "could not resolve the local provisioned tenant"
    fi
    mapfile -t rows < "$selection_file"
    if [ -n "$REQUESTED_TENANT_ID" ]; then
        [ "${#rows[@]}" -eq 1 ] \
            || die "explicit local activation tenant must match one active provisioned tenant"
    else
        [ "${#rows[@]}" -eq 1 ] \
            || die "local activation requires exactly one active provisioned tenant"
    fi
    if [[ ! "${rows[0]}" =~ ^([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})$'\t'([a-z0-9][a-z0-9-]{1,49})$ ]]; then
        die "the provisioned tenant catalog entry is not canonical"
    fi
    TENANT_ID="${BASH_REMATCH[1]}"
    TENANT_DATABASE="saas_${BASH_REMATCH[2]}"
    if [ -n "$REQUESTED_TENANT_ID" ] && [ "$TENANT_ID" != "$REQUESTED_TENANT_ID" ]; then
        die "explicit local activation tenant resolution was not exact"
    fi
}

read_generated_env_value() {
    local key="$1"
    local result

    result="$(awk -F= -v wanted="$key" '
        $1 == wanted {
            count++
            value=substr($0, index($0, "=") + 1)
        }
        END {
            if (count != 1 || value == "") exit 1
            print value
        }
    ' "$GENERATED_ENV_FILE")" || return 1
    [[ "$result" =~ ^[A-Za-z0-9._-]{1,64}$ ]] || return 1
    printf '%s' "$result"
}

keyring_java_list() {
    local keyring_file="$1"
    local active_key_id="$2"
    local output key_id result="" separator="" active_present=false
    local -a key_ids=()

    output="$(jq -er '
        if (. | type) == "object"
           and (keys == ["keys"])
           and ((.keys | type) == "object")
           and ((.keys | length) >= 1 and (.keys | length) <= 32)
        then .keys | keys | sort | .[]
        else error("invalid keyring")
        end
    ' "$keyring_file")" || return 1
    mapfile -t key_ids <<< "$output"
    for key_id in "${key_ids[@]}"; do
        [[ "$key_id" =~ ^[A-Za-z0-9._-]{1,64}$ ]] || return 1
        [ "$key_id" = "$active_key_id" ] && active_present=true
        result+="$separator$key_id"
        separator=", "
    done
    [ "$active_present" = true ] || return 1
    printf '[%s]' "$result"
}

compute_protection_fingerprint() {
    local legacy_read_enabled="$1"
    local aes_active hmac_active aes_read hmac_read policy digest remainder

    aes_active="$(read_generated_env_value CONVERSATION_AUDIT_AES_ACTIVE_KEY_ID)" \
        || return 1
    hmac_active="$(read_generated_env_value CONVERSATION_AUDIT_HMAC_ACTIVE_KEY_ID)" \
        || return 1
    aes_read="$(keyring_java_list "$AES_KEYRING_FILE" "$aes_active")" \
        || return 1
    hmac_read="$(keyring_java_list "$HMAC_KEYRING_FILE" "$hmac_active")" \
        || return 1
    policy="remote-identifier-v1|aes-active=$aes_active|aes-read=$aes_read|hmac-active=$hmac_active|hmac-read=$hmac_read|legacy-read=$legacy_read_enabled"
    read -r digest remainder < <(printf '%s' "$policy" | sha256sum)
    [[ "$digest" =~ ^[0-9a-f]{64}$ ]] || return 1
    unset policy aes_active hmac_active aes_read hmac_read
    printf 'sha256:%s' "$digest"
}

validate_effective_key_configuration() {
    local generated_aes_active generated_hmac_active

    generated_aes_active="$(read_generated_env_value CONVERSATION_AUDIT_AES_ACTIVE_KEY_ID)" \
        || return 1
    generated_hmac_active="$(read_generated_env_value CONVERSATION_AUDIT_HMAC_ACTIVE_KEY_ID)" \
        || return 1
    if [ -n "${CONVERSATION_AUDIT_AES_ACTIVE_KEY_ID:-}" ] \
        && [ "$CONVERSATION_AUDIT_AES_ACTIVE_KEY_ID" != "$generated_aes_active" ]; then
        return 1
    fi
    if [ -n "${CONVERSATION_AUDIT_HMAC_ACTIVE_KEY_ID:-}" ] \
        && [ "$CONVERSATION_AUDIT_HMAC_ACTIVE_KEY_ID" != "$generated_hmac_active" ]; then
        return 1
    fi
    if [ -n "${CONVERSATION_AUDIT_AES_KEYRING_FILE:-}" ] \
        && [ "$CONVERSATION_AUDIT_AES_KEYRING_FILE" != "/run/saas-secrets/conversation-audit-aes-keyring.json" ]; then
        return 1
    fi
    if [ -n "${CONVERSATION_AUDIT_HMAC_KEYRING_FILE:-}" ] \
        && [ "$CONVERSATION_AUDIT_HMAC_KEYRING_FILE" != "/run/saas-secrets/conversation-audit-hmac-keyring.json" ]; then
        return 1
    fi
    export CONVERSATION_AUDIT_AES_ACTIVE_KEY_ID="$generated_aes_active"
    export CONVERSATION_AUDIT_HMAC_ACTIVE_KEY_ID="$generated_hmac_active"
    export CONVERSATION_AUDIT_AES_KEYRING_FILE=/run/saas-secrets/conversation-audit-aes-keyring.json
    export CONVERSATION_AUDIT_HMAC_KEYRING_FILE=/run/saas-secrets/conversation-audit-hmac-keyring.json
}

database_signature() {
    local database="$1"
    local sql signature

    sql=$'/* conversation-audit-activation:database-signature */\nCREATE TEMP TABLE conversation_audit_activation_migration_count (total BIGINT NOT NULL);\nDO $activation$\nDECLARE\n    history RECORD;\n    row_count BIGINT;\n    migration_total BIGINT := 0;\nBEGIN\n    FOR history IN\n        SELECT table_name\n          FROM information_schema.tables\n         WHERE table_schema = \'public\'\n           AND table_name LIKE \'flyway_schema_history_%\'\n         ORDER BY table_name\n    LOOP\n        EXECUTE format(\'SELECT count(*) FROM %I WHERE success = TRUE\', history.table_name)\n           INTO row_count;\n        migration_total := migration_total + row_count;\n    END LOOP;\n    INSERT INTO conversation_audit_activation_migration_count VALUES (migration_total);\nEND\n$activation$;\nSELECT (SELECT count(*) FROM information_schema.tables WHERE table_schema = \'public\')::text\n       || \'|\' || total::text\n  FROM conversation_audit_activation_migration_count;'
    signature="$(postgres_psql "$database" -c "$sql" 2>/dev/null)" || return 1
    [[ "$signature" =~ ^[0-9]+\|[0-9]+$ ]] || return 1
    printf '%s' "$signature"
}

create_encrypted_backup_and_restore_drill() {
    local artifact_root custody_root protected_directory backup_id backup_key signing_private
    local verification_public signature_file encrypted_dump
    local source_signature restored_signature

    artifact_root="$BACKUP_ROOT/artifacts"
    custody_root="$BACKUP_ROOT/custody"
    for protected_directory in "$artifact_root" "$custody_root"; do
        [ ! -L "$protected_directory" ] || return 1
        if [ ! -e "$protected_directory" ]; then
            mkdir -m 700 -- "$protected_directory" || return 1
        fi
        owner_only_directory_is_valid "$protected_directory" || return 1
    done
    backup_id="$(openssl rand -hex 8)" || return 1
    [[ "$backup_id" =~ ^[0-9a-f]{16}$ ]] || return 1
    BACKUP_RUN_DIR="$artifact_root/$backup_id"
    BACKUP_CUSTODY_DIR="$custody_root/$backup_id"
    mkdir -m 700 -- "$BACKUP_RUN_DIR" || return 1
    mkdir -m 700 -- "$BACKUP_CUSTODY_DIR" || return 1
    owner_only_directory_is_valid "$BACKUP_RUN_DIR" || return 1
    owner_only_directory_is_valid "$BACKUP_CUSTODY_DIR" || return 1

    backup_key="$BACKUP_CUSTODY_DIR/encryption.passphrase"
    signing_private="$BACKUP_CUSTODY_DIR/signing-private.pem"
    verification_public="$BACKUP_RUN_DIR/verification-public.pem"
    signature_file="$BACKUP_RUN_DIR/signature.ed25519"
    encrypted_dump="$BACKUP_RUN_DIR/tenant.dump.enc"
    openssl rand -hex 32 > "$backup_key"
    chmod 600 -- "$backup_key"
    timeout --signal=TERM "$COMMAND_TIMEOUT_SECONDS" \
        openssl genpkey -algorithm ED25519 -out "$signing_private" \
        >/dev/null 2>&1 || return 1
    [ -s "$signing_private" ] || return 1
    chmod 600 -- "$signing_private"
    timeout --signal=TERM "$COMMAND_TIMEOUT_SECONDS" \
        openssl pkey -in "$signing_private" -pubout -out "$verification_public" \
        >/dev/null 2>&1 || return 1
    [ -s "$verification_public" ] || return 1
    chmod 600 -- "$verification_public"

    if ! timeout --signal=TERM "$COMMAND_TIMEOUT_SECONDS" \
        "${COMPOSE_PREFIX[@]}" "${COMPOSE_ENV_ARGS[@]}" "${COMPOSE_FILES[@]}" \
        exec -T postgres-app pg_dump -U "$DB_USER" -d "$TENANT_DATABASE" \
            --format=custom --no-owner --no-privileges 2>/dev/null \
        | timeout --signal=TERM "$COMMAND_TIMEOUT_SECONDS" \
            openssl enc -aes-256-cbc -salt -pbkdf2 \
                -pass "file:$backup_key" -out "$encrypted_dump" 2>/dev/null; then
        return 1
    fi
    [ -s "$encrypted_dump" ] || return 1
    chmod 600 -- "$encrypted_dump"
    timeout --signal=TERM "$COMMAND_TIMEOUT_SECONDS" \
        openssl pkeyutl -sign -inkey "$signing_private" -rawin \
            -in "$encrypted_dump" -out "$signature_file" \
        >/dev/null 2>&1 || return 1
    [ -s "$signature_file" ] || return 1
    chmod 600 -- "$signature_file"
    timeout --signal=TERM "$COMMAND_TIMEOUT_SECONDS" \
        openssl pkeyutl -verify -pubin -inkey "$verification_public" \
            -sigfile "$signature_file" -rawin -in "$encrypted_dump" \
        >/dev/null 2>&1 || return 1

    source_signature="$(database_signature "$TENANT_DATABASE")" || return 1
    DRILL_DATABASE="conversation_audit_drill_${backup_id}"

    run_regular_compose exec -T postgres-app \
        createdb -U "$DB_USER" -O "$DB_USER" "$DRILL_DATABASE" \
        >/dev/null 2>&1 || return 1
    if ! timeout --signal=TERM "$COMMAND_TIMEOUT_SECONDS" \
        openssl enc -d -aes-256-cbc -pbkdf2 \
            -pass "file:$backup_key" -in "$encrypted_dump" 2>/dev/null \
        | timeout --signal=TERM "$COMMAND_TIMEOUT_SECONDS" \
            "${COMPOSE_PREFIX[@]}" "${COMPOSE_ENV_ARGS[@]}" "${COMPOSE_FILES[@]}" \
            exec -T postgres-app pg_restore -U "$DB_USER" -d "$DRILL_DATABASE" \
                --exit-on-error --no-owner --no-privileges >/dev/null 2>&1; then
        return 1
    fi
    restored_signature="$(database_signature "$DRILL_DATABASE")" || return 1
    [ "$source_signature" = "$restored_signature" ] || return 1
    run_regular_compose exec -T postgres-app \
        dropdb -U "$DB_USER" --if-exists --force "$DRILL_DATABASE" \
        >/dev/null 2>&1 || return 1
    DRILL_DATABASE=""

    {
        printf 'created_at=%s\n' "$(date -u +'%Y-%m-%dT%H:%M:%SZ')"
        printf 'ciphertext_authentication=ED25519_VERIFIED\n'
        printf 'restore_drill=PASS\n'
        printf 'database_signature=%s\n' "$source_signature"
    } > "$BACKUP_RUN_DIR/receipt.env"
    chmod 600 -- "$BACKUP_RUN_DIR/receipt.env"
    BACKUP_VERIFIED=true
}

readiness_status() {
    local expected_fingerprint="$1"
    local sql status

    sql=$'/* conversation-audit-activation:readiness-status */\nWITH readiness AS (\n    SELECT *\n      FROM conversation_audit_data_protection_readiness\n     WHERE tenant_id = :\'audit_tenant_id\'::uuid\n       AND operation = \'remote-identifier-v1\'\n       AND migration_version = \'V39\'\n       AND protection_fingerprint = :\'expected_fingerprint\'\n), checkpoint AS (\n    SELECT *\n      FROM conversation_audit_backfill_checkpoint\n     WHERE tenant_id = :\'audit_tenant_id\'::uuid\n       AND operation = \'remote-identifier-v1\'\n       AND migration_version = \'V39\'\n       AND protection_fingerprint = :\'expected_fingerprint\'\n)\nSELECT concat_ws(\'|\',\n    CASE WHEN EXISTS (SELECT 1 FROM readiness) THEN 1 ELSE 0 END,\n    COALESCE((SELECT checkpoint_completed::int FROM readiness), 0),\n    COALESCE((SELECT verification_completed::int FROM readiness), 0),\n    COALESCE((SELECT ready::int FROM readiness), 0),\n    COALESCE((SELECT (verified_at IS NOT NULL)::int FROM readiness), 0),\n    COALESCE((SELECT eligible_plaintext FROM readiness), 0),\n    COALESCE((SELECT missing_or_invalid_hash FROM readiness), 0),\n    COALESCE((SELECT unknown_or_invalid_key_id FROM readiness), 0),\n    COALESCE((SELECT missing_or_stale_attestation FROM readiness), 0),\n    COALESCE((SELECT pending_activity FROM readiness), 0),\n    (SELECT count(*) FROM conversations c, checkpoint cp\n      WHERE c.tenant_id = :\'audit_tenant_id\'::uuid\n        AND cp.last_conversation_id IS NOT NULL\n        AND c.id <= cp.last_conversation_id),\n    (SELECT count(*) FROM conversations c, readiness r\n      WHERE c.tenant_id = :\'audit_tenant_id\'::uuid\n        AND r.scan_last_conversation_id IS NOT NULL\n        AND c.id <= r.scan_last_conversation_id),\n    (SELECT count(*) FROM conversations c\n      WHERE c.tenant_id = :\'audit_tenant_id\'::uuid\n        AND c.remote_identifier_protection_fingerprint IS DISTINCT FROM :\'expected_fingerprint\')\n);'
    status="$(printf '%s\n' "$sql" \
        | postgres_psql "$TENANT_DATABASE" \
            -v "audit_tenant_id=$TENANT_ID" \
            -v "expected_fingerprint=$expected_fingerprint" \
            2>/dev/null)" || return 1
    if [[ ! "$status" =~ ^[01]\|[01]\|[01]\|[01]\|[01]\|[0-9]+\|[0-9]+\|[0-9]+\|[0-9]+\|[0-9]+\|[0-9]+\|[0-9]+\|[0-9]+$ ]]; then
        return 1
    fi
    printf '%s' "$status"
}

phase_is_complete() {
    local status="$1"
    local legacy_read_enabled="$2"
    local present checkpoint_completed verification_completed ready verified
    local plaintext invalid_hash invalid_key stale_attestation pending_activity
    local checkpoint_prefix verification_prefix live_stale

    IFS='|' read -r present checkpoint_completed verification_completed ready verified \
        plaintext invalid_hash invalid_key stale_attestation pending_activity \
        checkpoint_prefix verification_prefix live_stale <<< "$status"
    [ "$present" = "1" ] \
        && [ "$checkpoint_completed" = "1" ] \
        && [ "$verification_completed" = "1" ] \
        && [ "$verified" = "1" ] \
        && [ "$plaintext" = "0" ] \
        && [ "$invalid_hash" = "0" ] \
        && [ "$invalid_key" = "0" ] \
        && [ "$stale_attestation" = "0" ] \
        && [ "$pending_activity" = "0" ] \
        && [ "$live_stale" = "0" ] \
        || return 1
    if [ "$legacy_read_enabled" = "true" ]; then
        [ "$ready" = "0" ]
    else
        [ "$ready" = "1" ]
    fi
}

validate_effective_backfill_configuration() {
    local legacy_read_enabled="$1"
    local rendered="$WORK_DIR/backfill-config.json"

    run_backfill_compose config --format json > "$rendered" 2>/dev/null \
        || return 1
    jq -e --arg tenant "$TENANT_ID" --arg legacy "$legacy_read_enabled" '
        .services.backend.restart == "no"
        and .services.backend.environment.APP_CONVERSATION_AUDIT_ENABLED == "true"
        and .services.backend.environment.APP_CONVERSATION_AUDIT_API_ENABLED == "false"
        and .services.backend.environment.APP_CONVERSATION_AUDIT_ALLOWED_TENANT_IDS == ""
        and .services.backend.environment.APP_CONVERSATION_AUDIT_LEGACY_READ_ENABLED == $legacy
        and .services.backend.environment.APP_CONVERSATION_AUDIT_BACKFILL_ENABLED == "true"
        and .services.backend.environment.APP_CONVERSATION_AUDIT_BACKFILL_TENANT_ID == $tenant
        and .services.backend.environment.APP_CONVERSATION_AUDIT_BACKFILL_BATCH_SIZE == "50"
        and .services.backend.environment.APP_CONVERSATION_AUDIT_BACKFILL_MAX_BATCHES == "1"
    ' "$rendered" >/dev/null 2>&1
}

run_backfill_phase() {
    local legacy_read_enabled="$1"
    local expected_fingerprint="$2"
    local status previous_status no_progress_count=0

    write_runtime_overlay true false "" "$legacy_read_enabled" true "$TENANT_ID"
    validate_effective_backfill_configuration "$legacy_read_enabled" || return 1
    status="$(readiness_status "$expected_fingerprint")" || return 1
    phase_is_complete "$status" "$legacy_read_enabled" && return 0
    previous_status="$status"

    while (( ATTEMPTS_USED < MAX_ATTEMPTS )); do
        ((ATTEMPTS_USED += 1))
        recreate_backfill_backend || return 1
        status="$(readiness_status "$expected_fingerprint")" || return 1
        phase_is_complete "$status" "$legacy_read_enabled" && return 0
        if [ "$status" = "$previous_status" ]; then
            ((no_progress_count += 1))
            (( no_progress_count < 2 )) || return 1
        else
            no_progress_count=0
        fi
        previous_status="$status"
    done
    return 1
}

rollback_activation() {
    local rollback_feature_enabled=false
    local rollback_legacy_read_enabled=false

    if [ "$KEY_CONFIGURATION_VALIDATED" = true ]; then
        rollback_feature_enabled=true
        rollback_legacy_read_enabled=true
    elif [ "$EXISTING_RUNTIME_OVERLAY_PRESENT" = true ] \
        && [ "$EXISTING_RUNTIME_FEATURE_ENABLED" = true ]; then
        # Never downgrade an already-protected writer merely because the new
        # activation could not validate or advance its lifecycle.
        rollback_feature_enabled=true
        rollback_legacy_read_enabled="$EXISTING_RUNTIME_LEGACY_READ_ENABLED"
    fi
    if [ "$LEGACY_ZERO_RISK" = true ]; then
        rollback_legacy_read_enabled=false
    fi

    if ! write_runtime_overlay_safely \
        "$rollback_feature_enabled" false "" \
        "$rollback_legacy_read_enabled" false ""; then
        stop_and_verify_regular_backend >/dev/null 2>&1 || true
        return 1
    fi
    if (( ${#COMPOSE_PREFIX[@]} == 0 )) \
        || ! validate_closed_regular_compose_configuration \
            "$rollback_feature_enabled" "$rollback_legacy_read_enabled" \
        || ! recreate_regular_backend >/dev/null 2>&1 \
        || ! validate_running_backend_closed_configuration \
            "$rollback_feature_enabled" "$rollback_legacy_read_enabled"; then
        stop_and_verify_regular_backend >/dev/null 2>&1 || true
        return 1
    fi
    return 0
}

cleanup() {
    local status=$?
    trap - EXIT INT TERM

    if [ "$status" -ne 0 ] \
        && [ "$CLOSE_EXPOSURE_ONLY" = true ] \
        && [ "$CLOSE_EXPOSURE_COMPLETED" != true ] \
        && [ "$LIFECYCLE_LOCK_ACQUIRED" = true ]; then
        if stop_and_verify_regular_backend; then
            log "Close-only recovery stopped and verified the regular backend."
        else
            printf '[conversation-audit-activation] ERROR: CLOSE-ONLY FAIL-SAFE COULD NOT VERIFY THE BACKEND AS STOPPED.\n' >&2
        fi
    elif [ "$status" -ne 0 ] && [ "$ROLLBACK_REQUIRED" = true ]; then
        if rollback_activation; then
            log "Activation aborted; the Conversation Audit API was verified in fail-closed state."
        else
            printf '[conversation-audit-activation] ERROR: ROLLBACK FAILED; a backend stop was requested as the fail-safe.\n' >&2
        fi
    fi
    if [ -n "$DRILL_DATABASE" ] && [ -n "${COMPOSE_PREFIX[*]:-}" ]; then
        set +e
        run_regular_compose exec -T postgres-app \
            dropdb -U "${DB_USER:-invalid}" --if-exists --force "$DRILL_DATABASE" \
            >/dev/null 2>&1
        set -e
    fi
    if [ -n "$RUNTIME_TEMP" ] && [ -f "$RUNTIME_TEMP" ] && [ ! -L "$RUNTIME_TEMP" ]; then
        rm -f -- "$RUNTIME_TEMP"
    fi
    if [ -n "$WORK_DIR" ] && [ -d "$WORK_DIR" ] && [ ! -L "$WORK_DIR" ]; then
        rm -r -- "$WORK_DIR"
    fi
    if [ -n "$BACKUP_RUN_DIR" ] && [ "$BACKUP_VERIFIED" != true ] \
        && [ -d "$BACKUP_RUN_DIR" ] && [ ! -L "$BACKUP_RUN_DIR" ]; then
        rm -r -- "$BACKUP_RUN_DIR"
    fi
    if [ -n "$BACKUP_CUSTODY_DIR" ] && [ "$BACKUP_VERIFIED" != true ] \
        && [ -d "$BACKUP_CUSTODY_DIR" ] && [ ! -L "$BACKUP_CUSTODY_DIR" ]; then
        rm -r -- "$BACKUP_CUSTODY_DIR"
    fi
    exit "$status"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

for command_name in basename chmod curl dirname docker flock id jq mktemp mv pwd \
    readlink realpath rm sleep stat timeout; do
    require_command "$command_name"
done
if [ "$CLOSE_EXPOSURE_ONLY" != true ]; then
    for command_name in awk date mkdir openssl sha256sum; do
        require_command "$command_name"
    done
fi

PROJECT_DIR="$(realpath -e -- "$PROJECT_DIR")"
[ "$PROJECT_DIR" != "/" ] || die "repository root cannot be the filesystem root"
[ "$PROJECT_DIR" = "$DEFAULT_PROJECT_DIR" ] \
    || [ -f "$PROJECT_DIR/AGENTS.md" ] \
    || die "activation project directory is not a repository root"
PROJECT_NAME="$(basename "$PROJECT_DIR")"
[[ "$PROJECT_NAME" =~ ^[a-z0-9][a-z0-9_-]*$ ]] \
    || die "local Compose project name is invalid"
[[ ! "$PROJECT_NAME" =~ (^|[-_])(prod|prd|production)([-_]|$) ]] \
    || die "conversation audit activation is restricted to local DEV"

configure_local_runtime_topology
validate_owner_only_directory "$DEV_SECRETS_DIRECTORY" "local DEV secrets directory"
validate_owner_only_file "$GENERATED_ENV_FILE" "generated local DEV environment"
for required_file in "$BASE_COMPOSE_FILE" "$DEV_COMPOSE_FILE" "$BOT_COMPOSE_FILE" \
    "$PROJECT_DIR/infra/scripts/lib/development-docker-access.sh"; do
    validate_regular_file "$required_file" "required local activation input"
done
if [ "$CLOSE_EXPOSURE_ONLY" != true ]; then
    validate_owner_only_file "$AES_KEYRING_FILE" "conversation audit AES keyring"
    validate_owner_only_file "$HMAC_KEYRING_FILE" "conversation audit HMAC keyring"
    validate_regular_file "$BACKFILL_COMPOSE_FILE" "required local activation input"
fi
if [ -n "$EXTRA_COMPOSE_FILE" ]; then
    validate_regular_file "$EXTRA_COMPOSE_FILE" "bundled DEV image overlay"
fi
if [ -e "$OPTIONAL_ENV_FILE" ] || [ -L "$OPTIONAL_ENV_FILE" ]; then
    validate_regular_file "$OPTIONAL_ENV_FILE" "optional local environment"
fi
if [ "$CLOSE_EXPOSURE_ONLY" != true ]; then
    [[ "$MAX_ATTEMPTS" =~ ^[1-9][0-9]*$ ]] \
        && (( MAX_ATTEMPTS <= 1000 )) \
        || die "activation attempt limit must be between 1 and 1000"
fi
[[ "$COMMAND_TIMEOUT_SECONDS" =~ ^[1-9][0-9]*$ ]] \
    && (( COMMAND_TIMEOUT_SECONDS <= 300 )) \
    || die "command timeout must be between 1 and 300 seconds"

COMPOSE_PREFIX=(docker compose --project-name "$PROJECT_NAME")
COMPOSE_ENV_ARGS=(--env-file "$GENERATED_ENV_FILE")
if [ -f "$OPTIONAL_ENV_FILE" ]; then
    COMPOSE_ENV_ARGS+=(--env-file "$OPTIONAL_ENV_FILE")
fi
COMPOSE_FILES=(-f "$BASE_COMPOSE_FILE" -f "$DEV_COMPOSE_FILE" -f "$BOT_COMPOSE_FILE")
if [ -n "$EXTRA_COMPOSE_FILE" ]; then
    COMPOSE_FILES+=(-f "$EXTRA_COMPOSE_FILE")
fi

# Capture and hold the lifecycle lock before reading prior state. A contender
# must exit without rewriting the overlay or recreating the backend, and a
# successful waiter must never act on a snapshot captured before the lock.
LOCK_FILE="$DEV_SECRETS_DIRECTORY/conversation-audit-activation.lock"
if [ ! -e "$LOCK_FILE" ] && [ ! -L "$LOCK_FILE" ]; then
    (set -o noclobber; : > "$LOCK_FILE") 2>/dev/null || true
fi
validate_owner_only_file "$LOCK_FILE" "conversation audit activation lock"
LOCK_PATH_IDENTITY="$(stat -Lc '%d:%i' -- "$LOCK_FILE")"
exec {LOCK_FD}<>"$LOCK_FILE"
LOCK_DESCRIPTOR_IDENTITY="$(stat -Lc '%d:%i' -- "/proc/self/fd/$LOCK_FD")"
[ "$LOCK_PATH_IDENTITY" = "$LOCK_DESCRIPTOR_IDENTITY" ] \
    || die "conversation audit activation lock changed during capture"
[ "$(stat -Lc '%u' -- "/proc/self/fd/$LOCK_FD")" = "$(id -u)" ] \
    && [ "$(stat -Lc '%a' -- "/proc/self/fd/$LOCK_FD")" = "600" ] \
    || die "conversation audit activation lock descriptor is not owner-only"
flock -n "$LOCK_FD" || die "another local conversation audit activation is running"
[ "$(stat -Lc '%d:%i' -- "$LOCK_FILE")" = "$LOCK_DESCRIPTOR_IDENTITY" ] \
    || die "conversation audit activation lock changed after acquisition"
LIFECYCLE_LOCK_ACQUIRED=true

# shellcheck source=infra/scripts/lib/development-docker-access.sh
source "$PROJECT_DIR/infra/scripts/lib/development-docker-access.sh"
require_direct_development_docker_access "$PROJECT_DIR" start-dev-bot \
    || die "direct local Docker access is not ready"

read_existing_runtime_overlay
WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/conversation-audit-activation.XXXXXX")"
chmod 700 -- "$WORK_DIR"

if [ "$CLOSE_EXPOSURE_ONLY" = true ]; then
    close_conversation_audit_exposure_only
    exit 0
fi

if [ -z "${DB_USER:-}" ]; then
    DB_USER="$(read_generated_env_value DB_USER)" \
        || die "DB_USER is unavailable from the local DEV configuration"
    export DB_USER
fi
[[ "$DB_USER" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]] \
    || die "DB_USER must be available as a canonical local PostgreSQL role"

validate_effective_key_configuration \
    || die "effective Conversation Audit key IDs do not match the generated local keyrings"
KEY_CONFIGURATION_VALIDATED=true
EXPECTED_LEGACY_FINGERPRINT="$(compute_protection_fingerprint true)" \
    || die "could not derive the legacy-read protection policy fingerprint"
EXPECTED_FINAL_FINGERPRINT="$(compute_protection_fingerprint false)" \
    || die "could not derive the final protection policy fingerprint"

if [ -L "$BACKUP_ROOT" ]; then
    die "encrypted local backup directory must not be a symbolic link"
fi
if [ ! -e "$BACKUP_ROOT" ]; then
    mkdir -m 700 -p -- "$BACKUP_ROOT"
fi
BACKUP_ROOT="$(realpath -e -- "$BACKUP_ROOT")"
[ "$BACKUP_ROOT" != "/" ] || die "backup root cannot be the filesystem root"
case "$BACKUP_ROOT/" in
    "$PROJECT_DIR/"*) die "encrypted local backups must remain outside the worktree" ;;
esac
validate_owner_only_directory "$BACKUP_ROOT" "encrypted local backup directory"

# A ready or partially migrated installation must never reopen a plaintext
# writer window during an idempotent startup. Close only HTTP exposure,
# allowlist and backfill while preserving any previously enabled protection
# and its compatible legacy-read state.
ROLLBACK_REQUIRED=true
write_runtime_overlay \
    "$EXISTING_RUNTIME_FEATURE_ENABLED" false "" \
    "$EXISTING_RUNTIME_LEGACY_READ_ENABLED" false ""
recreate_regular_backend \
    || die "backend did not confirm the initial fail-closed state"
log "Conversation Audit API is closed while local readiness is reconciled."

resolve_single_provisioned_tenant
CURRENT_FINAL_STATUS="$(readiness_status "$EXPECTED_FINAL_FINGERPRINT")" \
    || die "could not read aggregate Conversation Audit readiness"
if phase_is_complete "$CURRENT_FINAL_STATUS" false; then
    LEGACY_ZERO_RISK=true
    write_runtime_overlay true true "$TENANT_ID" false false ""
    recreate_regular_backend \
        || die "backend did not restore the already-ready audit state"
    IDEMPOTENT_FINAL_STATUS="$(readiness_status "$EXPECTED_FINAL_FINGERPRINT")" \
        || die "could not recheck readiness after idempotent API activation"
    phase_is_complete "$IDEMPOTENT_FINAL_STATUS" false \
        || die "aggregate readiness changed during idempotent API activation"
    ROLLBACK_REQUIRED=false
    log "Conversation Audit was already ready; the local API overlay was reconciled without reprocessing rows."
    exit 0
fi

create_encrypted_backup_and_restore_drill \
    || die "encrypted backup or isolated restore drill failed"
log "Encrypted local backup and isolated restore drill completed."

run_backfill_phase true "$EXPECTED_LEGACY_FINGERPRINT" \
    || die "bounded legacy-read backfill did not reach zero aggregate risk"
LEGACY_ZERO_RISK=true
log "Legacy-read backfill reached zero aggregate risk."

run_backfill_phase false "$EXPECTED_FINAL_FINGERPRINT" \
    || die "bounded final-fingerprint backfill did not reach durable readiness"
log "Final-fingerprint backfill reached durable aggregate readiness."

write_runtime_overlay true false "" false false ""
recreate_regular_backend \
    || die "backend did not stabilize with backfill disabled"
STABLE_STATUS="$(readiness_status "$EXPECTED_FINAL_FINGERPRINT")" \
    || die "could not perform the stable aggregate readiness recheck"
phase_is_complete "$STABLE_STATUS" false \
    || die "aggregate readiness did not remain valid after backfill shutdown"

write_runtime_overlay true false "$TENANT_ID" false false ""
recreate_regular_backend \
    || die "backend did not stabilize with the unitary audit allowlist"
ALLOWLIST_STATUS="$(readiness_status "$EXPECTED_FINAL_FINGERPRINT")" \
    || die "could not recheck readiness after allowlist activation"
phase_is_complete "$ALLOWLIST_STATUS" false \
    || die "aggregate readiness changed before API activation"

write_runtime_overlay true true "$TENANT_ID" false false ""
recreate_regular_backend \
    || die "backend did not become ready after local audit API activation"
FINAL_API_STATUS="$(readiness_status "$EXPECTED_FINAL_FINGERPRINT")" \
    || die "could not recheck readiness after local audit API activation"
phase_is_complete "$FINAL_API_STATUS" false \
    || die "aggregate readiness changed during local audit API activation"

ROLLBACK_REQUIRED=false
log "Conversation Audit local activation completed with API exposure enabled for one ready tenant."
