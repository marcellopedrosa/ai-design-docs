ensure_generated_outbound_attempt_keyring() {
    local active_key_id

    [ -f "$GENERATED_ENV_FILE" ] || return 0
    command -v openssl >/dev/null 2>&1 || {
        echo "ERROR: openssl is required to provision the local outbound attempt HMAC keyring."
        exit 1
    }
    command -v jq >/dev/null 2>&1 || {
        echo "ERROR: jq is required to provision the local outbound attempt HMAC keyring."
        exit 1
    }
    read_outbound_attempt_env_configuration

    if [ -L "$OUTBOUND_ATTEMPT_KEYRING_SOURCE_FILE" ]; then
        echo "ERROR: Local outbound attempt HMAC keyring must not be a symbolic link."
        exit 1
    fi
    if [ ! -e "$OUTBOUND_ATTEMPT_KEYRING_SOURCE_FILE" ]; then
        if [ -n "$OUTBOUND_ENV_ACTIVE_KEY_ID" ]; then
            echo "ERROR: Configured local outbound attempt HMAC keyring is missing; refusing to rotate it implicitly."
            exit 1
        fi
        [ -x "$OUTBOUND_ATTEMPT_KEYRING_GENERATOR" ] || {
            echo "ERROR: The outbound attempt HMAC keyring generator is unavailable."
            exit 1
        }
        "$OUTBOUND_ATTEMPT_KEYRING_GENERATOR" \
            --output "$OUTBOUND_ATTEMPT_KEYRING_SOURCE_FILE" \
            --active-key-id "$OUTBOUND_ATTEMPT_KEY_ID" >/dev/null
        echo "Generated a stable local outbound attempt HMAC keyring in .dev-secrets."
    fi
    if [ ! -f "$OUTBOUND_ATTEMPT_KEYRING_SOURCE_FILE" ]; then
        echo "ERROR: Local outbound attempt HMAC keyring is not a regular file."
        exit 1
    fi
    chmod 600 "$OUTBOUND_ATTEMPT_KEYRING_SOURCE_FILE"

    active_key_id="$OUTBOUND_ENV_ACTIVE_KEY_ID"
    if [ -z "$active_key_id" ]; then
        if ! active_key_id="$(discover_single_outbound_attempt_key_id \
            "$OUTBOUND_ATTEMPT_KEYRING_SOURCE_FILE")"; then
            echo "ERROR: A multi-key outbound attempt HMAC keyring requires an explicit active key ID."
            exit 1
        fi
    fi
    validate_outbound_attempt_keyring "$OUTBOUND_ATTEMPT_KEYRING_SOURCE_FILE" "$active_key_id"
    write_outbound_attempt_env_configuration "$active_key_id"
}

stage_outbound_attempt_keyring() {
    local candidate_file="$1"
    local candidate_active_key_id="$2"
    local current_configured=false current_active_key_id=""
    local audit_aes_digest audit_hmac_digest candidate_digest key_id
    local added_count=0 removed_count=0
    local -a candidate_ids=() candidate_digests=() current_ids=()
    local -A candidate_id_set=() current_id_set=()

    capture_outbound_stage_candidate "$candidate_file"
    validate_outbound_attempt_keyring "$OUTBOUND_STAGE_SNAPSHOT_FILE" "$candidate_active_key_id"
    candidate_ids=("${OUTBOUND_VALIDATED_KEY_IDS[@]}")
    candidate_digests=("${OUTBOUND_VALIDATED_KEY_DIGESTS[@]}")
    for key_id in "${candidate_ids[@]}"; do candidate_id_set["$key_id"]=true; done

    read_outbound_attempt_env_configuration
    if [ -n "$OUTBOUND_ENV_ACTIVE_KEY_ID" ]; then
        if [ -L "$OUTBOUND_ATTEMPT_KEYRING_SOURCE_FILE" ] \
            || [ ! -f "$OUTBOUND_ATTEMPT_KEYRING_SOURCE_FILE" ]; then
            echo "ERROR: Existing outbound attempt HMAC staging state is incomplete."
            exit 1
        fi
        current_configured=true
        current_active_key_id="$OUTBOUND_ENV_ACTIVE_KEY_ID"
        validate_outbound_attempt_keyring \
            "$OUTBOUND_ATTEMPT_KEYRING_SOURCE_FILE" "$current_active_key_id"
        current_ids=("${OUTBOUND_VALIDATED_KEY_IDS[@]}")
        for key_id in "${current_ids[@]}"; do current_id_set["$key_id"]=true; done

        for key_id in "${candidate_ids[@]}"; do
            [ -n "${current_id_set[$key_id]+present}" ] || ((added_count += 1))
        done
        for key_id in "${current_ids[@]}"; do
            [ -n "${candidate_id_set[$key_id]+present}" ] || ((removed_count += 1))
        done
        if { [ "$added_count" -gt 0 ] && [ "$removed_count" -gt 0 ]; } \
            || { [ "$candidate_active_key_id" != "$current_active_key_id" ] \
                && { [ "$added_count" -gt 0 ] || [ "$removed_count" -gt 0 ]; }; } \
            || { [ "$added_count" -gt 0 ] \
                && [ "$candidate_active_key_id" != "$current_active_key_id" ]; } \
            || { [ "$removed_count" -gt 0 ] \
                && [ "$candidate_active_key_id" != "$current_active_key_id" ]; }; then
            echo "ERROR: Outbound attempt HMAC add, switch and retirement must be staged separately."
            exit 1
        fi
        if { [ "$candidate_active_key_id" != "$current_active_key_id" ] \
            || [ "$removed_count" -gt 0 ]; } \
            && ! validate_outbound_attempt_commit_receipt; then
            echo "ERROR: Outbound attempt HMAC switch or retirement requires a current initializer commit receipt."
            exit 1
        fi
    fi

    audit_aes_digest="$(keyring_material_digest \
        "$CONVERSATION_AUDIT_AES_KEYRING_SOURCE_FILE" \
        "$CONVERSATION_AUDIT_AES_KEY_ID")"
    audit_hmac_digest="$(keyring_material_digest \
        "$CONVERSATION_AUDIT_HMAC_KEYRING_SOURCE_FILE" \
        "$CONVERSATION_AUDIT_HMAC_KEY_ID")"
    [ "$audit_aes_digest" != "$audit_hmac_digest" ] || {
        echo "ERROR: Local conversation keyrings must use pairwise distinct key material."
        exit 1
    }
    for candidate_digest in "${candidate_digests[@]}"; do
        if [ "$candidate_digest" = "$audit_aes_digest" ] \
            || [ "$candidate_digest" = "$audit_hmac_digest" ]; then
            echo "ERROR: Local conversation keyrings must use pairwise distinct key material."
            exit 1
        fi
    done

    umask 077
    OUTBOUND_STAGE_SOURCE_TEMP="$(mktemp \
        "$OUTBOUND_ATTEMPT_KEYRING_SOURCE_DIR/.staged-keyring.tmp.XXXXXX")"
    cp -- "$OUTBOUND_STAGE_SNAPSHOT_FILE" "$OUTBOUND_STAGE_SOURCE_TEMP"
    chmod 600 "$OUTBOUND_STAGE_SOURCE_TEMP"
    mv "$OUTBOUND_STAGE_SOURCE_TEMP" "$OUTBOUND_ATTEMPT_KEYRING_SOURCE_FILE"
    OUTBOUND_STAGE_SOURCE_TEMP=""

    if [ "${START_DEV_BOT_TEST_MODE:-0}" = "1" ] \
        && [ "${OUTBOUND_HMAC_TEST_FAIL_AFTER_SOURCE:-0}" = "1" ]; then
        echo "ERROR: Outbound attempt HMAC staging was interrupted safely."
        exit 1
    fi

    write_outbound_attempt_env_configuration "$candidate_active_key_id"
    cleanup_outbound_stage_files
    trap - EXIT
    unset candidate_digest audit_aes_digest audit_hmac_digest current_active_key_id
    echo "Outbound attempt HMAC candidate staged without starting Compose."
}

keyring_material_digest() {
    local source_file="$1"
    local key_id="$2"
    local keyring_content keyring_pattern key_material

    keyring_content="$(tr -d '\r\n' < "$source_file")"
    keyring_pattern="^\\{\\\"keys\\\":\\{\\\"${key_id}\\\":\\\"([A-Za-z0-9+/]+={0,2})\\\"\\}\\}$"
    [[ "$keyring_content" =~ $keyring_pattern ]] || return 1
    key_material="${BASH_REMATCH[1]}"
    printf '%s' "$key_material" \
        | openssl base64 -d -A 2>/dev/null \
        | openssl dgst -sha256 -binary \
        | openssl base64 -A
}

ensure_conversation_keyrings_are_distinct() {
    local audit_aes_digest audit_hmac_digest outbound_digest

    audit_aes_digest="$(keyring_material_digest \
        "$CONVERSATION_AUDIT_AES_KEYRING_SOURCE_FILE" \
        "$CONVERSATION_AUDIT_AES_KEY_ID")"
    audit_hmac_digest="$(keyring_material_digest \
        "$CONVERSATION_AUDIT_HMAC_KEYRING_SOURCE_FILE" \
        "$CONVERSATION_AUDIT_HMAC_KEY_ID")"
    read_outbound_attempt_env_configuration
    validate_outbound_attempt_keyring \
        "$OUTBOUND_ATTEMPT_KEYRING_SOURCE_FILE" "$OUTBOUND_ENV_ACTIVE_KEY_ID"

    if [ "$audit_aes_digest" = "$audit_hmac_digest" ]; then
        echo "ERROR: Local conversation keyrings must use pairwise distinct key material."
        exit 1
    fi
    for outbound_digest in "${OUTBOUND_VALIDATED_KEY_DIGESTS[@]}"; do
        if [ "$audit_aes_digest" = "$outbound_digest" ] \
            || [ "$audit_hmac_digest" = "$outbound_digest" ]; then
            echo "ERROR: Local conversation keyrings must use pairwise distinct key material."
            exit 1
        fi
    done
    unset audit_aes_digest audit_hmac_digest outbound_digest
}

export_canonical_outbound_attempt_compose_configuration() {
    read_outbound_attempt_env_configuration
    validate_outbound_attempt_keyring \
        "$OUTBOUND_ATTEMPT_KEYRING_SOURCE_FILE" "$OUTBOUND_ENV_ACTIVE_KEY_ID"
    CONVERSATION_OUTBOUND_ATTEMPT_HMAC_ACTIVE_KEY_ID="$OUTBOUND_ENV_ACTIVE_KEY_ID"
    CONVERSATION_OUTBOUND_ATTEMPT_HMAC_KEYRING_FILE="$OUTBOUND_ENV_KEYRING_FILE"
    export CONVERSATION_OUTBOUND_ATTEMPT_HMAC_ACTIVE_KEY_ID
    export CONVERSATION_OUTBOUND_ATTEMPT_HMAC_KEYRING_FILE
}

repair_generated_dev_encryption_keys() {
    local temp_file="$GENERATED_ENV_FILE.tmp.$$"
    local line key value
    local changed=false

    [ -f "$GENERATED_ENV_FILE" ] || return 0
    umask 077
    : > "$temp_file"

    while IFS= read -r line || [ -n "$line" ]; do
        key="${line%%=*}"
        value="${line#*=}"
        case "$key" in
            APP_SECURITY_ENCRYPTION_SECRET_KEY|APP_SECURITY_ENCRYPTION_KEY|APP_SECURITY_DATA_ENCRYPTION_KEY|APP_CRYPTO_SECRET|SAAS_CERTIFICATE_ENCRYPTION_KEY|SAAS_TENANT_ENCRYPTION_KEY|WHATSAPP_ENCRYPTION_KEY)
                if [[ "$value" =~ ^[0-9a-f]{64}$ ]]; then
                    line="$key=$(random_encryption_key)"
                    changed=true
                fi
                ;;
            APP_CRYPTO_LEGACY_SECRET|APP_SECURITY_ENCRYPTION_LEGACY_SECRET_KEY|APP_SECURITY_ENCRYPTION_LEGACY_KEY|SAAS_CERTIFICATE_LEGACY_ENCRYPTION_KEY|SAAS_TENANT_LEGACY_ENCRYPTION_KEY|WHATSAPP_LEGACY_ENCRYPTION_KEY)
                if [[ "$value" =~ ^[0-9a-f]{64}$ || "$value" == base64:* ]]; then
                    line="$key=legacy-key-not-configured"
                    changed=true
                fi
                ;;
        esac
        printf '%s\n' "$line" >> "$temp_file"
    done < "$GENERATED_ENV_FILE"

    if [ "$changed" = true ]; then
        mv "$temp_file" "$GENERATED_ENV_FILE"
        chmod 600 "$GENERATED_ENV_FILE"
        echo "Normalized generated encryption keys and legacy-key placeholders."
    else
        rm -f "$temp_file"
    fi
}

validate_encryption_key() {
    local variable_name="$1"
    local value="${!variable_name-}"
    local decoded_length

    if [ ${#value} -eq 32 ]; then
        return 0
    fi
    if [[ "$value" == base64:* ]]; then
        if decoded_length=$(printf '%s' "${value#base64:}" \
            | openssl base64 -d -A 2>/dev/null \
            | wc -c); then
            [ "${decoded_length//[[:space:]]/}" = "32" ] && return 0
        fi
    fi

    echo "ERROR: $variable_name must contain exactly 32 bytes or base64: followed by 32 encoded bytes."
    exit 1
}

wait_for_postgres() {
    local service="$1"
    local user="$2"
    local database="$3"

    echo "Waiting for $service to accept local connections..."
    for _ in $(seq 1 30); do
        if "${COMPOSE[@]}" "${COMPOSE_ENV_FILES[@]}" "${COMPOSE_FILES[@]}" \
            exec -T "$service" pg_isready -U "$user" -d "$database" \
            {OUTBOUND_ATTEMPT_STAGE_LOCK_FD}>&- >/dev/null 2>&1; then
            return 0
        fi
        sleep 1
    done

    echo "ERROR: $service did not become ready within 30 seconds." >&2
    return 1
}

compose_service_is_running() {
    local service="$1"
    local running_services

    if ! running_services=$("${COMPOSE[@]}" "${COMPOSE_ENV_FILES[@]}" "${COMPOSE_FILES[@]}" \
        ps --status running --services "$service" \
        {OUTBOUND_ATTEMPT_STAGE_LOCK_FD}>&-); then
        echo "ERROR: Could not inspect the current $service state before credential preparation." >&2
        return 2
    fi
    if [ -z "$running_services" ]; then
        return 1
    fi
    if [ "$running_services" != "$service" ]; then
        echo "ERROR: Docker Compose returned an unexpected state for $service." >&2
        return 2
    fi
    return 0
}

postgres_role_password_is_current() {
    local service="$1"
    local user="$2"
    local database="$3"
    local password="$4"

    [[ "$user" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]] \
        && [[ "$database" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]] \
        || return 1

    # The desired password crosses only stdin. It is never placed in the Docker
    # argv, event log or diagnostic output.
    printf '%s\n' "$password" \
        | "${COMPOSE[@]}" "${COMPOSE_ENV_FILES[@]}" "${COMPOSE_FILES[@]}" \
            exec -T "$service" sh -eu -c '
                IFS= read -r PGPASSWORD
                export PGPASSWORD
                exec psql -h 127.0.0.1 -U "$1" -d "$2" -Atq \
                    -c "SELECT 1"
            ' verify-postgres-role-password "$user" "$database" \
            {OUTBOUND_ATTEMPT_STAGE_LOCK_FD}>&- >/dev/null 2>&1
}

validate_redis_effective_password() {
    local response
    local desired_password="${REDIS_PASSWORD:-dev-only-redis-password}"

    # REDISCLI_AUTH is populated inside the container from stdin so neither the
    # secret nor its escaped representation appears in argv or logs.
    if ! response=$(printf '%s\n' "$desired_password" \
        | "${COMPOSE[@]}" "${COMPOSE_ENV_FILES[@]}" "${COMPOSE_FILES[@]}" \
            exec -T redis sh -eu -c '
                IFS= read -r REDISCLI_AUTH
                export REDISCLI_AUTH
                exec redis-cli --no-auth-warning ping
            ' verify-redis-password \
            {OUTBOUND_ATTEMPT_STAGE_LOCK_FD}>&- 2>/dev/null); then
        return 1
    fi
    [ "$response" = "PONG" ]
}

print_critical_startup_diagnostics() {
    echo "Critical service states:"
    run_bounded_conversation_audit_cleanup_command \
        "${COMPOSE[@]}" "${COMPOSE_ENV_FILES[@]}" "${COMPOSE_FILES[@]}" \
        ps -a outbound-attempt-keyring-init keycloak keycloak-provisioning-init backend ngrok-bot \
        || true
    echo "Critical startup logs:"
    run_bounded_conversation_audit_cleanup_command \
        "${COMPOSE[@]}" "${COMPOSE_ENV_FILES[@]}" "${COMPOSE_FILES[@]}" \
        logs --no-color --tail 100 \
        outbound-attempt-keyring-init keycloak keycloak-provisioning-init backend \
        || true
}

wait_for_backend_readiness() {
    echo "Waiting for backend readiness (up to 300 seconds)..."
    # Each local request is bounded to one second. Together with the one-second
    # interval, 150 attempts keep the complete wait bounded to five minutes.
    for _ in $(seq 1 150); do
        if curl --fail --silent --show-error \
            --connect-timeout 1 --max-time 1 \
            http://127.0.0.1:8080/actuator/health/readiness \
            >/dev/null 2>&1; then
            echo "Backend readiness confirmed."
            return 0
        fi
        sleep 1
    done

    echo "ERROR: Backend did not become ready within 300 seconds."
    print_critical_startup_diagnostics
    return 1
}

wait_for_public_backend_readiness() {
    local public_readiness_url="$1/actuator/health/readiness"

    echo "Waiting for public backend readiness through ngrok (up to 60 seconds)..."
    for _ in $(seq 1 30); do
        if curl --fail --silent --show-error \
            --header 'ngrok-skip-browser-warning: true' \
            --connect-timeout 1 --max-time 1 \
            "$public_readiness_url" 2>/dev/null \
            | grep -Eq '"status"[[:space:]]*:[[:space:]]*"UP"'; then
            echo "Public webhook ingress readiness confirmed."
            return 0
        fi
        sleep 1
    done

    echo "ERROR: Public backend readiness through ngrok was not confirmed within 60 seconds."
    print_critical_startup_diagnostics
    return 1
}

close_conversation_audit_activator_fd() {
    if [ -n "$CONVERSATION_AUDIT_ACTIVATOR_FD" ]; then
        exec {CONVERSATION_AUDIT_ACTIVATOR_FD}<&- || true
        CONVERSATION_AUDIT_ACTIVATOR_FD=""
    fi
}

close_conversation_audit_close_fd() {
    if [ -n "$CONVERSATION_AUDIT_CLOSE_FD" ]; then
        exec {CONVERSATION_AUDIT_CLOSE_FD}<&- || true
        CONVERSATION_AUDIT_CLOSE_FD=""
    fi
}

conversation_audit_coordinator_fd_is_pinned() {
    local descriptor="$1"
    local descriptor_path="/proc/self/fd/$descriptor"
    local descriptor_digest descriptor_identity descriptor_mode descriptor_owner

    if [ ! -r "$descriptor_path" ] || [ ! -f "$descriptor_path" ]; then
        return 1
    fi
    descriptor_identity="$(stat -Lc '%d:%i' -- "$descriptor_path")" || return 1
    [ "$descriptor_identity" = "$conversation_audit_activator_identity" ] || return 1
    descriptor_owner="$(stat -Lc '%u' -- "$descriptor_path")" || return 1
    [ "$descriptor_owner" = "$CURRENT_USER_UID" ] || return 1
    descriptor_mode="$(stat -Lc '%a' -- "$descriptor_path")" || return 1
    [[ "$descriptor_mode" =~ ^[0-7]{3,4}$ ]] || return 1
    (( (8#$descriptor_mode & 8#022) == 0 )) || return 1
    descriptor_digest="$(sha256sum "$descriptor_path" | awk '{print $1}')" || return 1
    [ "$descriptor_digest" = "$CONVERSATION_AUDIT_ACTIVATOR_DIGEST" ]
}
