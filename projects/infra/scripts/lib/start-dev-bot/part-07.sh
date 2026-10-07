validate_promoted_conversation_audit_runtime() {
    local uuid_pattern='^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'

    if [ "$CONVERSATION_AUDIT_RUNTIME_ENV_IMPORTED" != true ] \
        || [ "${APP_CONVERSATION_AUDIT_ENABLED:-}" != true ] \
        || [ "${APP_CONVERSATION_AUDIT_API_ENABLED:-}" != true ] \
        || [[ ! "${APP_CONVERSATION_AUDIT_ALLOWED_TENANT_IDS:-}" =~ $uuid_pattern ]] \
        || [ "${APP_CONVERSATION_AUDIT_LEGACY_READ_ENABLED:-}" != false ] \
        || [ "${APP_CONVERSATION_AUDIT_BACKFILL_ENABLED:-}" != false ] \
        || [ -n "${APP_CONVERSATION_AUDIT_BACKFILL_TENANT_ID:-}" ]; then
        echo "ERROR: Conversation audit activation did not publish the exact promoted runtime postcondition." >&2
        return 1
    fi
}

validate_promoted_conversation_audit_compose() {
    local expected_allowlist_digest proof_status=0

    expected_allowlist_digest=$(printf '%s\n' "$APP_CONVERSATION_AUDIT_ALLOWED_TENANT_IDS" \
        | sha256sum | awk '{print $1}')
    run_bounded_conversation_audit_compose_proof "$expected_allowlist_digest" \
        || proof_status=$?
    if [ "$proof_status" -eq 42 ]; then
        echo "ERROR: Docker Compose resolved a different conversation audit allowlist." >&2
        return 1
    fi
    if [ "$proof_status" -ne 0 ]; then
        echo "ERROR: Docker Compose did not resolve the promoted conversation audit postcondition." >&2
        return 1
    fi
}

validate_promoted_conversation_audit_backend() {
    if ! run_bounded_conversation_audit_post_promotion_compose \
        exec -T backend sh -eu -c '
                IFS= read -r expected_allowlist
                [ "${APP_CONVERSATION_AUDIT_ENABLED:-}" = "true" ]
                [ "${APP_CONVERSATION_AUDIT_API_ENABLED:-}" = "true" ]
                [ "${APP_CONVERSATION_AUDIT_ALLOWED_TENANT_IDS:-}" = "$expected_allowlist" ]
                [ "${APP_CONVERSATION_AUDIT_LEGACY_READ_ENABLED:-}" = "false" ]
                [ "${APP_CONVERSATION_AUDIT_BACKFILL_ENABLED:-}" = "false" ]
                [ -z "${APP_CONVERSATION_AUDIT_BACKFILL_TENANT_ID:-}" ]
            ' <<< "$APP_CONVERSATION_AUDIT_ALLOWED_TENANT_IDS"; then
        echo "ERROR: The running backend does not have the promoted conversation audit postcondition." >&2
        return 1
    fi
}

sync_postgres_role_password() {
    local service="$1"
    local user="$2"
    local database="$3"
    local password="$4"
    local escaped_password

    [[ "$user" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]] || {
        echo "ERROR: Invalid PostgreSQL role name configured for $service."
        return 1
    }

    # Password travels only through psql stdin and never appears in argv/logs.
    escaped_password="${password//\'/\'\'}"
    printf 'ALTER ROLE "%s" WITH PASSWORD '\''%s'\'';\n' "$user" "$escaped_password" \
        | "${COMPOSE[@]}" "${COMPOSE_ENV_FILES[@]}" "${COMPOSE_FILES[@]}" \
            exec -T "$service" psql -v ON_ERROR_STOP=1 -U "$user" -d "$database" \
            {OUTBOUND_ATTEMPT_STAGE_LOCK_FD}>&- >/dev/null
}

prepare_postgres_role_password() {
    local service="$1"
    local user="$2"
    local database="$3"
    local password="$4"
    local consumer="$5"
    local consumer_status

    if postgres_role_password_is_current "$service" "$user" "$database" "$password"; then
        return 0
    fi

    if compose_service_is_running "$consumer"; then
        echo "ERROR: $service credentials differ from the desired DEV configuration while $consumer is running; an explicit credential lifecycle is required." >&2
        return 1
    else
        consumer_status=$?
        [ "$consumer_status" -eq 1 ] || return "$consumer_status"
    fi

    if ! sync_postgres_role_password "$service" "$user" "$database" "$password" \
        || ! postgres_role_password_is_current "$service" "$user" "$database" "$password"; then
        echo "ERROR: Could not synchronize and verify $service credentials while $consumer was stopped." >&2
        return 1
    fi
}

ensure_initial_tenant_database() {
    local service="$1"
    local user="$2"
    local platform_database="$3"
    local tenant_database="saas_bpfarias"
    local database_exists

    [[ "$user" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]] || {
        echo "ERROR: Invalid PostgreSQL role name configured for $service."
        return 1
    }

    if ! database_exists=$("${COMPOSE[@]}" "${COMPOSE_ENV_FILES[@]}" "${COMPOSE_FILES[@]}" \
        exec -T "$service" psql -v ON_ERROR_STOP=1 -Atq \
            -U "$user" -d "$platform_database" \
            -c "SELECT 1 FROM pg_database WHERE datname = '$tenant_database'" \
            {OUTBOUND_ATTEMPT_STAGE_LOCK_FD}>&-); then
        return 1
    fi

    if [ "$database_exists" != "1" ]; then
        echo "Recreating missing initial tenant database: $tenant_database..."
        if ! "${COMPOSE[@]}" "${COMPOSE_ENV_FILES[@]}" "${COMPOSE_FILES[@]}" \
            exec -T "$service" createdb -U "$user" -O "$user" "$tenant_database" \
            {OUTBOUND_ATTEMPT_STAGE_LOCK_FD}>&-; then
            return 1
        fi
    fi

    # Keep privileges correct both for a newly created database and for a
    # database restored from an older development volume.
    if ! printf 'GRANT ALL PRIVILEGES ON DATABASE %s TO "%s";\nGRANT ALL ON SCHEMA public TO "%s";\n' \
        "$tenant_database" "$user" "$user" \
        | "${COMPOSE[@]}" "${COMPOSE_ENV_FILES[@]}" "${COMPOSE_FILES[@]}" \
            exec -T "$service" psql -v ON_ERROR_STOP=1 -U "$user" -d "$tenant_database" \
            {OUTBOUND_ATTEMPT_STAGE_LOCK_FD}>&- >/dev/null; then
        return 1
    fi
}

echo "Starting Hybrid Local Mode (Ngrok -> Backend ONLY)..."

# Explicit environment and .env values take precedence over generated dev values.
load_dotenv_if_unset "$PROJECT_DIR/.env"
WHATSAPP_SECRET_WAS_CONFIGURED=false
if [ -n "${WHATSAPP_WEBHOOK_APP_SECRET:-}" ]; then
    WHATSAPP_SECRET_WAS_CONFIGURED=true
fi

create_generated_dev_env
ensure_generated_inbound_webhook_executor_settings
ensure_generated_auth_session_secret
ensure_generated_contact_webhook_token
ensure_generated_keycloak_dev_superadmin_password
ensure_generated_keycloak_service_account
ensure_generated_keyring \
    "conversation audit AES" \
    "$CONVERSATION_AUDIT_AES_KEY_ID" \
    "$CONVERSATION_AUDIT_AES_KEYRING_SOURCE_FILE" \
    "$CONVERSATION_AUDIT_AES_KEYRING_CONTAINER_FILE" \
    CONVERSATION_AUDIT_AES_ACTIVE_KEY_ID \
    CONVERSATION_AUDIT_AES_KEYRING_FILE
ensure_generated_keyring \
    "conversation audit HMAC" \
    "$CONVERSATION_AUDIT_HMAC_KEY_ID" \
    "$CONVERSATION_AUDIT_HMAC_KEYRING_SOURCE_FILE" \
    "$CONVERSATION_AUDIT_HMAC_KEYRING_CONTAINER_FILE" \
    CONVERSATION_AUDIT_HMAC_ACTIVE_KEY_ID \
    CONVERSATION_AUDIT_HMAC_KEYRING_FILE
prepare_outbound_attempt_keyring_directory
acquire_outbound_attempt_stage_lock
migrate_legacy_outbound_attempt_keyring
ensure_outbound_attempt_commit_receipt_key
if [ "$OUTBOUND_STAGE_REQUESTED" = true ]; then
    stage_outbound_attempt_keyring \
        "$OUTBOUND_STAGE_CANDIDATE_FILE" "$OUTBOUND_STAGE_ACTIVE_KEY_ID"
    exit 0
fi
ensure_generated_outbound_attempt_keyring
ensure_outbound_attempt_approval_directory
ensure_conversation_keyrings_are_distinct
export_canonical_outbound_attempt_compose_configuration
repair_generated_dev_encryption_keys
load_dotenv_if_unset "$GENERATED_ENV_FILE"
import_conversation_audit_runtime_env

for encryption_variable in \
    APP_SECURITY_ENCRYPTION_SECRET_KEY \
    APP_SECURITY_ENCRYPTION_KEY \
    APP_SECURITY_DATA_ENCRYPTION_KEY \
    APP_CRYPTO_SECRET \
    SAAS_CERTIFICATE_ENCRYPTION_KEY \
    SAAS_TENANT_ENCRYPTION_KEY \
    WHATSAPP_ENCRYPTION_KEY; do
    validate_encryption_key "$encryption_variable"
done

if [ "${1:-}" = "--prepare-env-only" ]; then
    echo "Development environment files are prepared."
    exit 0
fi

[[ "$DEV_BOT_COMPOSE_PROJECT_NAME" =~ ^[a-z0-9][a-z0-9_-]*$ ]] || {
    echo "ERROR: Invalid dev-bot Compose project directory name: $DEV_BOT_COMPOSE_PROJECT_NAME"
    exit 1
}
if [[ "$DEV_BOT_COMPOSE_PROJECT_NAME" =~ (^|[-_])(prod|prd|production)([-_]|$) ]]; then
    echo "ERROR: Refusing to start dev-bot from a production-like project directory: $DEV_BOT_COMPOSE_PROJECT_NAME"
    exit 1
fi

# `flyway-reset` is intentionally hidden behind this Compose profile because it
# executes `clean migrate`. Never let a regular startup (including a Docker Hub
# image update) activate that destructive maintenance service through the
# process environment or the client-provided .env file.
ACTIVE_COMPOSE_PROFILES="${COMPOSE_PROFILES:-}"
ACTIVE_COMPOSE_PROFILES="${ACTIVE_COMPOSE_PROFILES//[[:space:]]/}"
case ",$ACTIVE_COMPOSE_PROFILES," in
    *,destructive-reset,* | *,\*,*)
        echo "ERROR: COMPOSE_PROFILES must not enable destructive-reset during normal dev-bot startup."
        exit 1
        ;;
esac

if [ "${BOT_CHANNEL:-telegram}" = "whatsapp" ] && [ "$WHATSAPP_SECRET_WAS_CONFIGURED" = false ]; then
    echo "ERROR: BOT_CHANNEL=whatsapp requires the real WHATSAPP_WEBHOOK_APP_SECRET in .env."
    exit 1
fi

if [ "$WHATSAPP_SECRET_WAS_CONFIGURED" = false ]; then
    echo "INFO: Using a generated local WhatsApp placeholder; Telegram remains fully available."
fi

if [ -z "${NGROK_AUTHTOKEN:-}" ]; then
    echo "ERROR: NGROK_AUTHTOKEN is not set in .env"
    exit 1
fi

if [[ ! "${APP_BASE_URL:-}" =~ ^https://[A-Za-z0-9.-]+(:[0-9]+)?/?$ ]]; then
    echo "ERROR: APP_BASE_URL must be a complete public HTTPS origin (for example, https://example.ngrok-free.dev)."
    exit 1
fi

# Keep one canonical origin for both ngrok's reserved endpoint and the backend
# webhook URL builder. Shell exports take precedence over Compose env files.
APP_BASE_URL="${APP_BASE_URL%/}"
export APP_BASE_URL

# A previous complete lifecycle overlay may preserve the protection/legacy
# phase, but the first backend start is always closed to HTTP audit exposure.
# Only the activation coordinator promotes the API after rechecking durable
# readiness for the current protection fingerprint.
if [ "$CONVERSATION_AUDIT_RUNTIME_ENV_IMPORTED" != "true" ]; then
    APP_CONVERSATION_AUDIT_ENABLED=false
    APP_CONVERSATION_AUDIT_LEGACY_READ_ENABLED=false
    export APP_CONVERSATION_AUDIT_ENABLED
    export APP_CONVERSATION_AUDIT_LEGACY_READ_ENABLED
fi
APP_CONVERSATION_AUDIT_API_ENABLED=false
APP_CONVERSATION_AUDIT_ALLOWED_TENANT_IDS=
export APP_CONVERSATION_AUDIT_API_ENABLED
export APP_CONVERSATION_AUDIT_ALLOWED_TENANT_IDS

# A regular dev-bot startup is never a supervised migration invocation. Force
# stale backfill values inherited from every source to the fail-closed state,
# the dedicated backfill override must be invoked separately and applied last.
APP_CONVERSATION_AUDIT_BACKFILL_ENABLED=false
APP_CONVERSATION_AUDIT_BACKFILL_TENANT_ID=
export APP_CONVERSATION_AUDIT_BACKFILL_ENABLED
export APP_CONVERSATION_AUDIT_BACKFILL_TENANT_ID

# Validate interpolation before starting any container. This prevents a Compose
# failure from being misreported later as an Ngrok initialization failure.
COMPOSE_FILES=(-f docker-compose.yml -f docker-compose.override.yml -f docker-compose.dev-bot.yml)
if [ -n "${DEV_BOT_EXTRA_COMPOSE_FILE:-}" ]; then
    COMPOSE_FILES+=(-f "$DEV_BOT_EXTRA_COMPOSE_FILE")
fi
COMPOSE_ENV_FILES=(--env-file "$GENERATED_ENV_FILE")
if [ -f "$PROJECT_DIR/.env" ]; then
    # Real local configuration overrides generated development defaults.
    COMPOSE_ENV_FILES+=(--env-file "$PROJECT_DIR/.env")
fi

# The host bootstrap is a prerequisite, but malformed/destructive local
# configuration must still fail before any Docker client call.
# shellcheck source=infra/scripts/lib/development-docker-access.sh
source "$PROJECT_DIR/infra/scripts/lib/development-docker-access.sh"
require_direct_development_docker_access "$PROJECT_DIR" start-dev-bot \
    {OUTBOUND_ATTEMPT_STAGE_LOCK_FD}>&-
COMPOSE=(docker compose --project-name "$DEV_BOT_COMPOSE_PROJECT_NAME")
"${COMPOSE[@]}" "${COMPOSE_ENV_FILES[@]}" "${COMPOSE_FILES[@]}" config --quiet \
    {OUTBOUND_ATTEMPT_STAGE_LOCK_FD}>&-

if [ "${1:-}" = "--check" ]; then
    echo "Development bot configuration is valid."
    exit 0
fi

conversation_audit_activator="$PROJECT_DIR/infra/scripts/activate-dev-conversation-audit.sh"
for conversation_audit_supervision_command in setsid timeout; do
    if ! command -v "$conversation_audit_supervision_command" >/dev/null 2>&1; then
        echo "ERROR: $conversation_audit_supervision_command is required to supervise conversation audit activation safely." >&2
        exit 1
    fi
done
if ! [[ "$CONVERSATION_AUDIT_SHUTDOWN_GRACE_SECONDS" =~ ^([1-9]|10)$ ]]; then
    echo "ERROR: CONVERSATION_AUDIT_SHUTDOWN_GRACE_SECONDS must be an integer from 1 to 10." >&2
    exit 1
fi
if ! [[ "$CONVERSATION_AUDIT_CLEANUP_TIMEOUT_SECONDS" =~ ^([1-9]|[12][0-9]|30)$ ]]; then
    echo "ERROR: CONVERSATION_AUDIT_CLEANUP_TIMEOUT_SECONDS must be an integer from 1 to 30." >&2
    exit 1
fi
if ! [[ "$CONVERSATION_AUDIT_CLEANUP_KILL_AFTER_SECONDS" =~ ^[1-5]$ ]]; then
    echo "ERROR: CONVERSATION_AUDIT_CLEANUP_KILL_AFTER_SECONDS must be an integer from 1 to 5." >&2
    exit 1
fi
if ! [[ "$CONVERSATION_AUDIT_CLOSE_OUTER_TIMEOUT_SECONDS" =~ ^[1-9][0-9]{0,2}$ ]] \
    || (( CONVERSATION_AUDIT_CLOSE_OUTER_TIMEOUT_SECONDS > 900 )); then
    echo "ERROR: CONVERSATION_AUDIT_CLOSE_OUTER_TIMEOUT_SECONDS must be an integer from 1 to 900." >&2
    exit 1
fi
if ! [[ "$CONVERSATION_AUDIT_POST_PROMOTION_TIMEOUT_SECONDS" =~ ^[1-9][0-9]{0,2}$ ]] \
    || (( CONVERSATION_AUDIT_POST_PROMOTION_TIMEOUT_SECONDS > 600 )); then
    echo "ERROR: CONVERSATION_AUDIT_POST_PROMOTION_TIMEOUT_SECONDS must be an integer from 1 to 600." >&2
    exit 1
fi
if [ -L "$conversation_audit_activator" ] \
    || [ ! -f "$conversation_audit_activator" ]; then
    echo "ERROR: The local conversation audit activation coordinator must be a regular repository file." >&2
    exit 1
fi
conversation_audit_activator_identity="$(stat -Lc '%d:%i' -- "$conversation_audit_activator")"
CONVERSATION_AUDIT_ACTIVATOR_DIGEST="$(sha256sum "$conversation_audit_activator" | awk '{print $1}')"
exec {CONVERSATION_AUDIT_ACTIVATOR_FD}<"$conversation_audit_activator"
exec {CONVERSATION_AUDIT_CLOSE_FD}<"$conversation_audit_activator"
if ! conversation_audit_coordinator_fd_is_pinned "$CONVERSATION_AUDIT_ACTIVATOR_FD" \
    || ! conversation_audit_coordinator_fd_is_pinned "$CONVERSATION_AUDIT_CLOSE_FD"; then
    close_conversation_audit_activator_fd
    close_conversation_audit_close_fd
    echo "ERROR: The local conversation audit activation coordinator changed during validation." >&2
    exit 1
fi

# Complete every reversible preparation step while the currently running DEV
# stack is still available. In host mode the new backend image is built before
# any frontend/app/backend cutover; the bundled wrapper must keep using its pinned
# image and therefore skips a source build explicitly.
if [ "${DEV_BOT_DIND_WRAPPER:-}" = "1" ]; then
    echo "Using the bundled backend image; source build is not applicable."
elif ! "${COMPOSE[@]}" "${COMPOSE_ENV_FILES[@]}" "${COMPOSE_FILES[@]}" \
    build backend {OUTBOUND_ATTEMPT_STAGE_LOCK_FD}>&-; then
    echo "ERROR: Backend image preparation failed before cutover; the existing DEV application was preserved." >&2
    exit 1
fi

# Existing stateful services must not be force-recreated by an incremental
# backend startup. Prepare PostgreSQL and Redis first so persisted credentials
# can be checked before Keycloak is started or its verifier is invoked.
if ! "${COMPOSE[@]}" "${COMPOSE_ENV_FILES[@]}" "${COMPOSE_FILES[@]}" \
    up -d --no-build --no-recreate --wait --wait-timeout 300 \
    postgres-app postgres-keycloak redis \
    {OUTBOUND_ATTEMPT_STAGE_LOCK_FD}>&-; then
    echo "ERROR: DEV base services did not become ready before cutover; the existing application was preserved." >&2
    exit 1
fi

# Existing volumes retain their first initialization credentials. Authenticate
# with the desired configuration before cutover. A role may be synchronized
# only when its consumer is stopped; rotating it below a live backend/app/Keycloak
# would contradict the promise that a failed Prepare preserves that runtime.
if ! wait_for_postgres postgres-app "$DB_USER" saas_tenant \
    || ! wait_for_postgres postgres-keycloak "$KEYCLOAK_DB_USER" keycloak \
    || ! prepare_postgres_role_password \
        postgres-app "$DB_USER" saas_tenant "$DB_PASSWORD" backend \
    || ! prepare_postgres_role_password \
        postgres-keycloak "$KEYCLOAK_DB_USER" keycloak "$KEYCLOAK_DB_PASSWORD" keycloak \
    || ! ensure_initial_tenant_database postgres-app "$DB_USER" saas_tenant; then
    echo "ERROR: DEV PostgreSQL preparation failed before cutover; the existing application was preserved." >&2
    exit 1
fi
if ! validate_redis_effective_password; then
    echo "ERROR: Redis credentials differ from the desired DEV configuration; the existing application was preserved and an explicit credential lifecycle is required." >&2
    exit 1
fi
echo "Local PostgreSQL and Redis credentials are verified."

# Keycloak is started only after its database role is compatible. An existing
# healthy container is retained; a missing/stopped one may now use the verified
# desired credential without forcing any replacement.
if ! "${COMPOSE[@]}" "${COMPOSE_ENV_FILES[@]}" "${COMPOSE_FILES[@]}" \
    up -d --no-build --no-recreate --wait --wait-timeout 300 keycloak \
    {OUTBOUND_ATTEMPT_STAGE_LOCK_FD}>&-; then
    echo "ERROR: Keycloak did not become ready before cutover; the existing application was preserved." >&2
    exit 1
fi

# The normal verifier remains fail-closed and never grants privileges
# implicitly. A drift must be reconciled by the approved procedure, but its
# detection must not stop an already healthy frontend/app/backend pair.
if ! "${COMPOSE[@]}" "${COMPOSE_ENV_FILES[@]}" "${COMPOSE_FILES[@]}" \
    run --rm --no-deps keycloak-provisioning-init \
    {OUTBOUND_ATTEMPT_STAGE_LOCK_FD}>&-; then
    echo "ERROR: Keycloak provisioning identity preflight failed before cutover; the existing DEV application was preserved." >&2
    exit 1
fi

# Keep the UI unavailable until activation, resolved Compose configuration and
# the effective backend environment all prove the same promoted allowlist.
# Every failure or signal while the gate is armed stops the frontend again.
CONVERSATION_AUDIT_STARTUP_GATE_ARMED=true
# A previous successful execution may already have promoted the Audit API in
# the running backend. From the first availability gate onward, assume exposure
# is possible so every error invokes the pinned close-only coordinator (or
# stops the backend if closure cannot be proved).
CONVERSATION_AUDIT_EXPOSURE_MAY_BE_OPEN=true
trap handle_conversation_audit_startup_exit EXIT
trap 'handle_conversation_audit_startup_signal 130' INT
trap 'handle_conversation_audit_startup_signal 143' TERM
if ! "${COMPOSE[@]}" "${COMPOSE_ENV_FILES[@]}" "${COMPOSE_FILES[@]}" \
    stop frontend {OUTBOUND_ATTEMPT_STAGE_LOCK_FD}>&-; then
    echo "ERROR: Could not stop the frontend before conversation audit activation." >&2
    exit 1
fi
if ! require_frontend_stopped; then
    exit 1
fi

# Installing the keyring crosses the cutover boundary because the backend loads
# it at startup. From this point onward the existing fail-closed cleanup owns all
# failures and signals.
if ! "${COMPOSE[@]}" "${COMPOSE_ENV_FILES[@]}" "${COMPOSE_FILES[@]}" \
    run --rm --no-deps outbound-attempt-keyring-init \
    {OUTBOUND_ATTEMPT_STAGE_LOCK_FD}>&-; then
    echo "ERROR: The outbound keyring could not be installed after the DEV cutover started." >&2
    print_critical_startup_diagnostics
    exit 1
fi
