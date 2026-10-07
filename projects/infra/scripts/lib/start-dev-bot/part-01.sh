ALERT_WEBHOOK_FILE="$DEV_SECRETS_DIR/alert-webhook-url"
CONVERSATION_AUDIT_RUNTIME_ENV_FILE="$DEV_SECRETS_DIR/conversation-audit-runtime.env"
CONVERSATION_AUDIT_RUNTIME_ENV_IMPORTED=false
CONVERSATION_AUDIT_ACTIVATOR_FD=""
CONVERSATION_AUDIT_CLOSE_FD=""
CONVERSATION_AUDIT_ACTIVATOR_DIGEST=""
CONVERSATION_AUDIT_ACTIVATOR_PID=""
CONVERSATION_AUDIT_ACTIVATOR_PGID=""
CONVERSATION_AUDIT_ACTIVATOR_SPAWN_IN_PROGRESS=false
CONVERSATION_AUDIT_PENDING_SIGNAL_STATUS=""
CONVERSATION_AUDIT_SUPERVISED_COMMAND_STATE=IDLE
CONVERSATION_AUDIT_SUPERVISED_COMMAND_PID=""
CONVERSATION_AUDIT_SUPERVISED_COMMAND_PGID=""
CONVERSATION_AUDIT_SUPERVISED_COMMAND_STARTTIME=""
CONVERSATION_AUDIT_SUPERVISED_COMMAND_GROUP_VERIFIED=false
CONVERSATION_AUDIT_STARTUP_GATE_ARMED=false
CONVERSATION_AUDIT_EXPOSURE_MAY_BE_OPEN=false
CONVERSATION_AUDIT_STARTUP_CLEANUP_RUNNING=false
CONVERSATION_AUDIT_SHUTDOWN_GRACE_SECONDS="${CONVERSATION_AUDIT_SHUTDOWN_GRACE_SECONDS:-10}"
CONVERSATION_AUDIT_CLEANUP_TIMEOUT_SECONDS="${CONVERSATION_AUDIT_CLEANUP_TIMEOUT_SECONDS:-30}"
CONVERSATION_AUDIT_CLEANUP_KILL_AFTER_SECONDS="${CONVERSATION_AUDIT_CLEANUP_KILL_AFTER_SECONDS:-5}"
CONVERSATION_AUDIT_CLOSE_OUTER_TIMEOUT_SECONDS="${CONVERSATION_AUDIT_CLOSE_OUTER_TIMEOUT_SECONDS:-600}"
CONVERSATION_AUDIT_POST_PROMOTION_TIMEOUT_SECONDS="${CONVERSATION_AUDIT_POST_PROMOTION_TIMEOUT_SECONDS:-300}"
CONVERSATION_AUDIT_AES_KEY_ID=dev-conversation-audit-aes-v1
CONVERSATION_AUDIT_AES_KEYRING_SOURCE_FILE="$DEV_SECRETS_DIR/conversation-audit-aes-keyring.json"
CONVERSATION_AUDIT_AES_KEYRING_CONTAINER_FILE=/run/saas-secrets/conversation-audit-aes-keyring.json
CONVERSATION_AUDIT_HMAC_KEY_ID=dev-conversation-audit-hmac-v1
CONVERSATION_AUDIT_HMAC_KEYRING_SOURCE_FILE="$DEV_SECRETS_DIR/conversation-audit-hmac-keyring.json"
CONVERSATION_AUDIT_HMAC_KEYRING_CONTAINER_FILE=/run/saas-secrets/conversation-audit-hmac-keyring.json
OUTBOUND_ATTEMPT_KEY_ID=dev-outbound-v1
OUTBOUND_ATTEMPT_KEYRING_SOURCE_DIR="$DEV_SECRETS_DIR/outbound-hmac"
OUTBOUND_ATTEMPT_KEYRING_SOURCE_FILE="$OUTBOUND_ATTEMPT_KEYRING_SOURCE_DIR/conversation-outbound-attempt-hmac-keyring.json"
OUTBOUND_ATTEMPT_KEYRING_GENERATOR="$PROJECT_DIR/infra/scripts/generate-outbound-attempt-hmac-keyring.sh"
OUTBOUND_ATTEMPT_LEGACY_KEYRING_SOURCE_FILE="$DEV_SECRETS_DIR/conversation-outbound-attempt-hmac-keyring.json"
OUTBOUND_ATTEMPT_KEYRING_CONTAINER_FILE=/run/saas-secrets/conversation-outbound-attempt-hmac-keyring.json
OUTBOUND_ATTEMPT_APPROVAL_DIR="$DEV_SECRETS_DIR/approvals/outbound-hmac"
OUTBOUND_ATTEMPT_COMMIT_RECEIPT_FILE="$DEV_SECRETS_DIR/outbound-hmac-commit-receipt.json"
OUTBOUND_ATTEMPT_COMMIT_RECEIPT_KEY_FILE="$DEV_SECRETS_DIR/outbound-hmac-commit-receipt.key"
OUTBOUND_ATTEMPT_STAGE_LOCK_FILE="$DEV_SECRETS_DIR/outbound-hmac-stage.lock"
OUTBOUND_ATTEMPT_STAGE_LOCK_FD=""
OUTBOUND_STAGE_REQUESTED=false
OUTBOUND_STAGE_CANDIDATE_FILE=""
OUTBOUND_STAGE_ACTIVE_KEY_ID=""
OUTBOUND_STAGE_SNAPSHOT_DIR=""
OUTBOUND_STAGE_SNAPSHOT_FILE=""
OUTBOUND_STAGE_SOURCE_TEMP=""
OUTBOUND_STAGE_ENV_TEMP=""
OUTBOUND_VALIDATED_KEY_IDS=()
OUTBOUND_VALIDATED_KEY_DIGESTS=()
OUTBOUND_ENV_ACTIVE_KEY_ID=""
OUTBOUND_ENV_KEYRING_FILE=""

if [ "${1:-}" = "--stage-outbound-hmac-keyring" ]; then
    if [ "$#" -ne 3 ]; then
        echo "ERROR: outbound HMAC staging requires one candidate file and one active key ID."
        exit 1
    fi
    OUTBOUND_STAGE_REQUESTED=true
    if [[ "$2" = /* ]]; then
        OUTBOUND_STAGE_CANDIDATE_FILE="$2"
    else
        OUTBOUND_STAGE_CANDIDATE_FILE="$(pwd -P)/$2"
    fi
    OUTBOUND_STAGE_ACTIVE_KEY_ID="$3"
fi

cd "$PROJECT_DIR"

CURRENT_USER_UID="$(id -u)"
CURRENT_USER_GID="$(id -g)"
if [ "$CURRENT_USER_UID" = "0" ] \
    && [ "${DEV_BOT_DIND_WRAPPER:-}" != "1" ]; then
    echo "ERROR: start-dev-bot.sh must run as the login user, not with sudo/root." >&2
    echo "Docker access must be prepared before this entrypoint; it never elevates Docker Compose." >&2
    if [[ "${SUDO_UID:-}" =~ ^[1-9][0-9]*$ ]] \
        && [[ "${SUDO_GID:-}" =~ ^[0-9]+$ ]]; then
        echo "If sudo changed .env.dev.local ownership, repair only its metadata:" >&2
        printf '  sudo chown -- %s:%s %q\n' \
            "$SUDO_UID" "$SUDO_GID" "$GENERATED_ENV_FILE" >&2
        printf '  sudo chmod 600 %q\n' "$GENERATED_ENV_FILE" >&2
    fi
    developer_user_hint="${SUDO_USER:-<login-user>}"
    echo "From the developer login, run the canonical bootstrap and continuation:" >&2
    printf '  sudo ./infra/scripts/bootstrap-development-host.sh --developer-user %q --docker-access rootful-group --continue start-dev-bot\n' \
        "$developer_user_hint" >&2
    exit 1
fi
if [ "${DEV_BOT_DIND_WRAPPER:-}" = "1" ] \
    && [ "$CURRENT_USER_UID" != "0" ]; then
    echo "ERROR: DEV_BOT_DIND_WRAPPER is valid only in the root Docker-in-Docker entrypoint." >&2
    exit 1
fi

# The bundled-image override intentionally removes backend.build and is owned by
# the Docker-in-Docker wrapper. On a source checkout it would make --build
# ineffective and could restart stale code, so ambient host configuration is
# rejected before any local environment or secret file is changed.
if [ "${DEV_BOT_DIND_WRAPPER:-}" = "1" ]; then
    case "${DEV_BOT_EXTRA_COMPOSE_FILE:-}" in
        docker-compose.dev-bot-image.yml|./docker-compose.dev-bot-image.yml|"$PROJECT_DIR/docker-compose.dev-bot-image.yml")
            if [ ! -f "$PROJECT_DIR/docker-compose.dev-bot-image.yml" ] \
                || [ -L "$PROJECT_DIR/docker-compose.dev-bot-image.yml" ]; then
                echo "ERROR: The bundled Compose overlay must be a regular file." >&2
                exit 1
            fi
            DEV_BOT_EXTRA_COMPOSE_FILE=docker-compose.dev-bot-image.yml
            ;;
        *)
            echo "ERROR: The bundled dev-bot wrapper requires docker-compose.dev-bot-image.yml." >&2
            exit 1
            ;;
    esac
    BUNDLED_STATE_DIR="${DEV_BOT_DIND_STATE_DIR:-}"
    if [ -z "$BUNDLED_STATE_DIR" ] \
        || [[ "$BUNDLED_STATE_DIR" != /* ]] \
        || [ "$BUNDLED_STATE_DIR" = "/" ] \
        || [ ! -d "$BUNDLED_STATE_DIR" ] \
        || [ -L "$BUNDLED_STATE_DIR" ]; then
        echo "ERROR: The bundled dev-bot wrapper requires a regular absolute state directory." >&2
        exit 1
    fi
    bundled_state_owner="$(stat -Lc '%u' -- "$BUNDLED_STATE_DIR")"
    bundled_state_mode="$(stat -Lc '%a' -- "$BUNDLED_STATE_DIR")"
    if [ "$bundled_state_owner" != "0" ] \
        || (( (8#$bundled_state_mode & 8#022) != 0 )); then
        echo "ERROR: The bundled dev-bot state directory must be root-owned and not writable by group or others." >&2
        exit 1
    fi
    BUNDLED_GENERATED_ENV_FILE="$BUNDLED_STATE_DIR/.env.dev.local"
    if [ ! -L "$PROJECT_DIR/.env.dev.local" ] \
        || [ "$(readlink -- "$PROJECT_DIR/.env.dev.local")" != "$BUNDLED_GENERATED_ENV_FILE" ]; then
        echo "ERROR: The bundled dev-bot wrapper requires the canonical persisted .env.dev.local symlink." >&2
        exit 1
    fi
    GENERATED_ENV_FILE="$BUNDLED_GENERATED_ENV_FILE"
elif [ -n "${DEV_BOT_EXTRA_COMPOSE_FILE:-}" ]; then
    echo "ERROR: DEV_BOT_EXTRA_COMPOSE_FILE is reserved for the bundled dev-bot wrapper." >&2
    echo "Unset it so the local backend is rebuilt from the current workspace." >&2
    exit 1
elif [ -n "${DEV_BOT_DIND_STATE_DIR:-}" ]; then
    echo "ERROR: DEV_BOT_DIND_STATE_DIR is reserved for the bundled dev-bot wrapper." >&2
    exit 1
fi

preflight_generated_dev_env_metadata() {
    local env_owner env_mode

    if [ -L "$GENERATED_ENV_FILE" ]; then
        echo "ERROR: .env.dev.local must be a regular owner-only file, not a symbolic link." >&2
        exit 1
    fi
    [ -e "$GENERATED_ENV_FILE" ] || return 0
    if [ ! -f "$GENERATED_ENV_FILE" ]; then
        echo "ERROR: .env.dev.local must be a regular owner-only file." >&2
        exit 1
    fi

    env_owner="$(stat -Lc '%u' -- "$GENERATED_ENV_FILE")"
    env_mode="$(stat -Lc '%a' -- "$GENERATED_ENV_FILE")"
    if [ "$env_owner" != "$CURRENT_USER_UID" ]; then
        echo "ERROR: .env.dev.local belongs to UID $env_owner; expected login UID $CURRENT_USER_UID." >&2
        echo "Repair only its ownership and mode, without replacing or reading the file:" >&2
        printf '  sudo chown -- %s:%s %q\n' \
            "$CURRENT_USER_UID" "$CURRENT_USER_GID" "$GENERATED_ENV_FILE" >&2
        printf '  sudo chmod 600 %q\n' "$GENERATED_ENV_FILE" >&2
        echo "Then run: ./start-dev-bot.sh" >&2
        exit 1
    fi

    if [ "$env_mode" != "600" ]; then
        chmod 600 -- "$GENERATED_ENV_FILE"
    fi
}

preflight_generated_dev_env_metadata

random_secret() {
    openssl rand -hex 32
}

random_encryption_key() {
    printf 'base64:%s' "$(openssl rand -base64 32 | tr -d '\n')"
}

random_keyring_key() {
    openssl rand -base64 32 | tr -d '\n'
}

inbound_webhook_executor_default() {
    case "$1" in
        APP_CONVERSATION_AUDIT_WEBHOOK_EXECUTOR_WHATSAPP_CORE_POOL_SIZE|APP_CONVERSATION_AUDIT_WEBHOOK_EXECUTOR_TELEGRAM_CORE_POOL_SIZE)
            printf '%s' '2'
            ;;
        APP_CONVERSATION_AUDIT_WEBHOOK_EXECUTOR_WHATSAPP_MAX_POOL_SIZE|APP_CONVERSATION_AUDIT_WEBHOOK_EXECUTOR_TELEGRAM_MAX_POOL_SIZE)
            printf '%s' '4'
            ;;
        APP_CONVERSATION_AUDIT_WEBHOOK_EXECUTOR_WHATSAPP_QUEUE_CAPACITY|APP_CONVERSATION_AUDIT_WEBHOOK_EXECUTOR_TELEGRAM_QUEUE_CAPACITY)
            printf '%s' '100'
            ;;
        *)
            return 1
            ;;
    esac
}

ensure_generated_inbound_webhook_executor_settings() {
    local temp_file line key value default_value occurrence_count
    local changed=false
    local -a executor_variables=(
        APP_CONVERSATION_AUDIT_WEBHOOK_EXECUTOR_WHATSAPP_CORE_POOL_SIZE
        APP_CONVERSATION_AUDIT_WEBHOOK_EXECUTOR_WHATSAPP_MAX_POOL_SIZE
        APP_CONVERSATION_AUDIT_WEBHOOK_EXECUTOR_WHATSAPP_QUEUE_CAPACITY
        APP_CONVERSATION_AUDIT_WEBHOOK_EXECUTOR_TELEGRAM_CORE_POOL_SIZE
        APP_CONVERSATION_AUDIT_WEBHOOK_EXECUTOR_TELEGRAM_MAX_POOL_SIZE
        APP_CONVERSATION_AUDIT_WEBHOOK_EXECUTOR_TELEGRAM_QUEUE_CAPACITY
    )
    local -A seen=()

    if [ -L "$GENERATED_ENV_FILE" ] || [ ! -f "$GENERATED_ENV_FILE" ]; then
        echo "ERROR: .env.dev.local must be a regular owner-only file, not a symbolic link."
        exit 1
    fi
    chmod 600 "$GENERATED_ENV_FILE"

    for key in "${executor_variables[@]}"; do
        occurrence_count="$(awk -F= -v variable_name="$key" '
            $1 == variable_name { count++ }
            END { print count + 0 }
        ' "$GENERATED_ENV_FILE")"
        if [ "$occurrence_count" -gt 1 ]; then
            echo "ERROR: .env.dev.local contains a duplicate inbound webhook executor setting: $key."
            exit 1
        fi
    done

    umask 077
    temp_file="$(mktemp "$GENERATED_ENV_FILE.tmp.XXXXXX")"
    while IFS= read -r line || [ -n "$line" ]; do
        key="${line%%=*}"
        if default_value="$(inbound_webhook_executor_default "$key")"; then
            seen["$key"]=true
            value="${line#*=}"
            if [ -z "$value" ] || [ "$value" = '""' ] || [ "$value" = "''" ]; then
                line="$key=$default_value"
                changed=true
            fi
        fi
        printf '%s\n' "$line" >> "$temp_file"
    done < "$GENERATED_ENV_FILE"

    for key in "${executor_variables[@]}"; do
        if [ -z "${seen[$key]+configured}" ]; then
            default_value="$(inbound_webhook_executor_default "$key")"
            printf '%s=%s\n' "$key" "$default_value" >> "$temp_file"
            changed=true
        fi
    done

    if [ "$changed" = true ]; then
        chmod 600 "$temp_file"
        mv "$temp_file" "$GENERATED_ENV_FILE"
        chmod 600 "$GENERATED_ENV_FILE"
        echo "Repaired owner-only DEV inbound webhook executor settings."
    else
        rm -f "$temp_file"
    fi
}

ensure_outbound_attempt_approval_directory() {
    if [ -L "$DEV_SECRETS_DIR/approvals" ] \
        || [ -L "$OUTBOUND_ATTEMPT_APPROVAL_DIR" ]; then
        echo "ERROR: Local outbound HMAC approval directories must not be symbolic links."
        exit 1
    fi
    mkdir -p "$OUTBOUND_ATTEMPT_APPROVAL_DIR"
    chmod 700 "$DEV_SECRETS_DIR" \
        "$DEV_SECRETS_DIR/approvals" \
        "$OUTBOUND_ATTEMPT_APPROVAL_DIR"
}

prepare_outbound_attempt_keyring_directory() {
    if [ -L "$OUTBOUND_ATTEMPT_KEYRING_SOURCE_DIR" ]; then
        echo "ERROR: Local outbound HMAC source directory must not be a symbolic link."
        exit 1
    fi
    mkdir -p "$OUTBOUND_ATTEMPT_KEYRING_SOURCE_DIR"
    chmod 700 "$DEV_SECRETS_DIR" "$OUTBOUND_ATTEMPT_KEYRING_SOURCE_DIR"
}

acquire_outbound_attempt_stage_lock() {
    local command_name lock_owner lock_mode path_identity descriptor_identity

    for command_name in flock id stat; do
        command -v "$command_name" >/dev/null 2>&1 || {
            echo "ERROR: A required local outbound HMAC lock command is unavailable."
            exit 1
        }
    done

    if [ ! -e "$OUTBOUND_ATTEMPT_STAGE_LOCK_FILE" ] \
        && [ ! -L "$OUTBOUND_ATTEMPT_STAGE_LOCK_FILE" ]; then
        (set -o noclobber; : > "$OUTBOUND_ATTEMPT_STAGE_LOCK_FILE") 2>/dev/null || true
    fi
    if [ -L "$OUTBOUND_ATTEMPT_STAGE_LOCK_FILE" ] \
        || [ ! -f "$OUTBOUND_ATTEMPT_STAGE_LOCK_FILE" ]; then
        echo "ERROR: Local outbound HMAC host lock must be a regular non-symlink file."
        exit 1
    fi
    chmod 600 "$OUTBOUND_ATTEMPT_STAGE_LOCK_FILE"
    lock_owner="$(stat -Lc '%u' "$OUTBOUND_ATTEMPT_STAGE_LOCK_FILE")"
    lock_mode="$(stat -Lc '%a' "$OUTBOUND_ATTEMPT_STAGE_LOCK_FILE")"
    if [ "$lock_owner" != "$(id -u)" ] || [ "$lock_mode" != "600" ]; then
        echo "ERROR: Local outbound HMAC host lock must be owner-only."
        exit 1
    fi
    exec {OUTBOUND_ATTEMPT_STAGE_LOCK_FD}<>"$OUTBOUND_ATTEMPT_STAGE_LOCK_FILE"
    path_identity="$(stat -Lc '%d:%i' "$OUTBOUND_ATTEMPT_STAGE_LOCK_FILE")"
    descriptor_identity="$(stat -Lc '%d:%i' \
        "/proc/self/fd/$OUTBOUND_ATTEMPT_STAGE_LOCK_FD")"
    if [ "$path_identity" != "$descriptor_identity" ] \
        || ! flock -n "$OUTBOUND_ATTEMPT_STAGE_LOCK_FD"; then
        echo "ERROR: Another local outbound HMAC operation is already running."
        exit 1
    fi
}

migrate_legacy_outbound_attempt_keyring() {

    if [ -e "$OUTBOUND_ATTEMPT_LEGACY_KEYRING_SOURCE_FILE" ] \
        || [ -L "$OUTBOUND_ATTEMPT_LEGACY_KEYRING_SOURCE_FILE" ]; then
        if [ -L "$OUTBOUND_ATTEMPT_LEGACY_KEYRING_SOURCE_FILE" ] \
            || [ ! -f "$OUTBOUND_ATTEMPT_LEGACY_KEYRING_SOURCE_FILE" ]; then
            echo "ERROR: Legacy local outbound HMAC keyring is not a regular file."
            exit 1
        fi
        if [ -e "$OUTBOUND_ATTEMPT_KEYRING_SOURCE_FILE" ]; then
            echo "ERROR: Both legacy and lifecycle-managed outbound HMAC keyrings exist; refusing an ambiguous migration."
            exit 1
        fi
        mv "$OUTBOUND_ATTEMPT_LEGACY_KEYRING_SOURCE_FILE" \
            "$OUTBOUND_ATTEMPT_KEYRING_SOURCE_FILE"
        chmod 600 "$OUTBOUND_ATTEMPT_KEYRING_SOURCE_FILE"
        echo "Migrated the stable local outbound HMAC keyring into its owner-only lifecycle directory."
    fi
}

cleanup_outbound_stage_files() {
    if [ -n "$OUTBOUND_STAGE_SOURCE_TEMP" ]; then
        rm -f -- "$OUTBOUND_STAGE_SOURCE_TEMP"
        OUTBOUND_STAGE_SOURCE_TEMP=""
    fi
    if [ -n "$OUTBOUND_STAGE_ENV_TEMP" ]; then
        rm -f -- "$OUTBOUND_STAGE_ENV_TEMP"
        OUTBOUND_STAGE_ENV_TEMP=""
    fi
    if [ -n "$OUTBOUND_STAGE_SNAPSHOT_FILE" ]; then
        rm -f -- "$OUTBOUND_STAGE_SNAPSHOT_FILE"
        OUTBOUND_STAGE_SNAPSHOT_FILE=""
    fi
    if [ -n "$OUTBOUND_STAGE_SNAPSHOT_DIR" ]; then
        rmdir -- "$OUTBOUND_STAGE_SNAPSHOT_DIR" 2>/dev/null || true
        OUTBOUND_STAGE_SNAPSHOT_DIR=""
    fi
}

capture_outbound_stage_candidate() {
    local candidate_file="$1"
    local candidate_parent candidate_mode candidate_owner parent_mode parent_owner
    local before_identity descriptor_identity after_identity candidate_fd

    candidate_parent="$(dirname -- "$candidate_file")"
    if [ -L "$candidate_file" ] || [ ! -f "$candidate_file" ]; then
        echo "ERROR: Outbound HMAC staging candidate must be a regular non-symlink file."
        exit 1
    fi
    if [ -L "$candidate_parent" ] || [ ! -d "$candidate_parent" ]; then
        echo "ERROR: Outbound HMAC staging candidate parent must be a regular directory."
        exit 1
    fi

    candidate_mode="$(stat -Lc '%a' "$candidate_file")"
    candidate_owner="$(stat -Lc '%u' "$candidate_file")"
    parent_mode="$(stat -Lc '%a' "$candidate_parent")"
    parent_owner="$(stat -Lc '%u' "$candidate_parent")"
    if { [ "$candidate_mode" != "400" ] && [ "$candidate_mode" != "600" ]; } \
        || [ "$candidate_owner" != "$(id -u)" ]; then
        echo "ERROR: Outbound HMAC staging candidate must be owner-only and owned by the current user."
        exit 1
    fi
    if [[ ! "$parent_mode" =~ ^[0-7]00$ ]] || [ "$parent_owner" != "$(id -u)" ]; then
        echo "ERROR: Outbound HMAC staging candidate parent must be owner-only."
        exit 1
    fi

    umask 077
    OUTBOUND_STAGE_SNAPSHOT_DIR="$(mktemp -d "$DEV_SECRETS_DIR/.outbound-stage.XXXXXX")"
    chmod 700 "$OUTBOUND_STAGE_SNAPSHOT_DIR"
    OUTBOUND_STAGE_SNAPSHOT_FILE="$OUTBOUND_STAGE_SNAPSHOT_DIR/candidate.json"
    trap cleanup_outbound_stage_files EXIT

    before_identity="$(stat -Lc '%d:%i' "$candidate_file")"
    exec {candidate_fd}<"$candidate_file"
    descriptor_identity="$(stat -Lc '%d:%i' "/proc/self/fd/$candidate_fd")"
    if [ "$before_identity" != "$descriptor_identity" ]; then
        exec {candidate_fd}<&-
        echo "ERROR: Outbound HMAC staging candidate changed during capture."
        exit 1
    fi
    cp -- "/proc/self/fd/$candidate_fd" "$OUTBOUND_STAGE_SNAPSHOT_FILE"
    chmod 400 "$OUTBOUND_STAGE_SNAPSHOT_FILE"
    after_identity="$(stat -Lc '%d:%i' "/proc/self/fd/$candidate_fd")"
    if [ "$descriptor_identity" != "$after_identity" ] \
        || ! cmp -s "/proc/self/fd/$candidate_fd" "$OUTBOUND_STAGE_SNAPSHOT_FILE"; then
        exec {candidate_fd}<&-
        echo "ERROR: Outbound HMAC staging candidate changed during capture."
        exit 1
    fi
    exec {candidate_fd}<&-
}
