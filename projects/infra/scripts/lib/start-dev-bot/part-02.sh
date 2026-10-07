load_dotenv_if_unset() {
    local file="$1"
    local line key value

    [ -f "$file" ] || return 0

    while IFS= read -r line || [ -n "$line" ]; do
        line="${line%$'\r'}"
        [[ "$line" =~ ^[[:space:]]*$ ]] && continue
        [[ "$line" =~ ^[[:space:]]*# ]] && continue
        [[ "$line" =~ ^[A-Za-z_][A-Za-z0-9_]*= ]] || continue

        key="${line%%=*}"
        value="${line#*=}"
        case "$key" in
            DEV_BOT_DIND_WRAPPER|DEV_BOT_EXTRA_COMPOSE_FILE|DEV_BOT_DIND_STATE_DIR)
                # Runtime-mode selectors are accepted only from the initial
                # process environment established by the bundled entrypoint.
                continue
                ;;
        esac
        if [[ "$value" == \"*\" && "$value" == *\" ]]; then
            value="${value:1:${#value}-2}"
        elif [[ "$value" == \'*\' && "$value" == *\' ]]; then
            value="${value:1:${#value}-2}"
        fi

        # Process environment has precedence; empty dotenv placeholders do not.
        if [ -z "${!key-}" ] && [ -n "$value" ]; then
            export "$key=$value"
        fi
    done < "$file"
}

import_conversation_audit_runtime_env() {
    local runtime_owner runtime_mode runtime_path_identity runtime_descriptor_identity
    local runtime_fd line key value line_number=0
    local uuid_pattern='^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
    local -a required_keys=(
        APP_CONVERSATION_AUDIT_ENABLED
        APP_CONVERSATION_AUDIT_API_ENABLED
        APP_CONVERSATION_AUDIT_ALLOWED_TENANT_IDS
        APP_CONVERSATION_AUDIT_LEGACY_READ_ENABLED
        APP_CONVERSATION_AUDIT_BACKFILL_ENABLED
        APP_CONVERSATION_AUDIT_BACKFILL_TENANT_ID
    )
    local -A seen=()
    local -A values=()

    if [ ! -e "$CONVERSATION_AUDIT_RUNTIME_ENV_FILE" ] \
        && [ ! -L "$CONVERSATION_AUDIT_RUNTIME_ENV_FILE" ]; then
        return 0
    fi
    if [ -L "$CONVERSATION_AUDIT_RUNTIME_ENV_FILE" ] \
        || [ ! -f "$CONVERSATION_AUDIT_RUNTIME_ENV_FILE" ]; then
        echo "ERROR: Local conversation audit runtime configuration must be a regular non-symlink file." >&2
        exit 1
    fi

    runtime_owner="$(stat -Lc '%u' -- "$CONVERSATION_AUDIT_RUNTIME_ENV_FILE")"
    runtime_mode="$(stat -Lc '%a' -- "$CONVERSATION_AUDIT_RUNTIME_ENV_FILE")"
    if [ "$runtime_owner" != "$CURRENT_USER_UID" ] || [ "$runtime_mode" != "600" ]; then
        echo "ERROR: Local conversation audit runtime configuration must be owned by the current user with mode 0600." >&2
        exit 1
    fi

    runtime_path_identity="$(stat -Lc '%d:%i' -- "$CONVERSATION_AUDIT_RUNTIME_ENV_FILE")"
    exec {runtime_fd}<"$CONVERSATION_AUDIT_RUNTIME_ENV_FILE"
    runtime_descriptor_identity="$(stat -Lc '%d:%i' -- "/proc/self/fd/$runtime_fd")"
    if [ "$runtime_path_identity" != "$runtime_descriptor_identity" ] \
        || [ "$(stat -Lc '%u' -- "/proc/self/fd/$runtime_fd")" != "$CURRENT_USER_UID" ] \
        || [ "$(stat -Lc '%a' -- "/proc/self/fd/$runtime_fd")" != "600" ]; then
        exec {runtime_fd}<&-
        echo "ERROR: Local conversation audit runtime configuration changed during validation." >&2
        exit 1
    fi

    while IFS= read -r line <&"$runtime_fd" || [ -n "$line" ]; do
        ((line_number += 1))
        if [[ "$line" != *=* ]] || [[ "$line" == *$'\r'* ]]; then
            exec {runtime_fd}<&-
            echo "ERROR: Local conversation audit runtime configuration contains a malformed line at $line_number." >&2
            exit 1
        fi

        key="${line%%=*}"
        value="${line#*=}"
        case "$key" in
            APP_CONVERSATION_AUDIT_ENABLED|APP_CONVERSATION_AUDIT_API_ENABLED|APP_CONVERSATION_AUDIT_LEGACY_READ_ENABLED|APP_CONVERSATION_AUDIT_BACKFILL_ENABLED)
                if [ "$value" != "true" ] && [ "$value" != "false" ]; then
                    exec {runtime_fd}<&-
                    echo "ERROR: Local conversation audit runtime configuration contains an invalid boolean for $key." >&2
                    exit 1
                fi
                ;;
            APP_CONVERSATION_AUDIT_ALLOWED_TENANT_IDS|APP_CONVERSATION_AUDIT_BACKFILL_TENANT_ID)
                if [ -n "$value" ] && [[ ! "$value" =~ $uuid_pattern ]]; then
                    exec {runtime_fd}<&-
                    echo "ERROR: Local conversation audit runtime configuration contains an invalid tenant identifier for $key." >&2
                    exit 1
                fi
                ;;
            *)
                exec {runtime_fd}<&-
                echo "ERROR: Local conversation audit runtime configuration contains an unknown key at line $line_number." >&2
                exit 1
                ;;
        esac
        if [ -n "${seen[$key]+configured}" ]; then
            exec {runtime_fd}<&-
            echo "ERROR: Local conversation audit runtime configuration contains a duplicate key: $key." >&2
            exit 1
        fi
        seen["$key"]=true
        values["$key"]="$value"
    done
    if [ -L "$CONVERSATION_AUDIT_RUNTIME_ENV_FILE" ] \
        || [ ! -f "$CONVERSATION_AUDIT_RUNTIME_ENV_FILE" ] \
        || [ "$(stat -Lc '%d:%i' -- "$CONVERSATION_AUDIT_RUNTIME_ENV_FILE")" != "$runtime_path_identity" ] \
        || [ "$(stat -Lc '%d:%i' -- "/proc/self/fd/$runtime_fd")" != "$runtime_descriptor_identity" ]; then
        exec {runtime_fd}<&-
        echo "ERROR: Local conversation audit runtime configuration changed during validation." >&2
        exit 1
    fi
    exec {runtime_fd}<&-

    for key in "${required_keys[@]}"; do
        if [ -z "${seen[$key]+configured}" ]; then
            echo "ERROR: Local conversation audit runtime configuration is missing the required key: $key." >&2
            exit 1
        fi
    done

    if [ "${values[APP_CONVERSATION_AUDIT_API_ENABLED]}" = "true" ]; then
        if [ "${values[APP_CONVERSATION_AUDIT_ENABLED]}" != "true" ] \
            || [ -z "${values[APP_CONVERSATION_AUDIT_ALLOWED_TENANT_IDS]}" ] \
            || [ "${values[APP_CONVERSATION_AUDIT_LEGACY_READ_ENABLED]}" != "false" ] \
            || [ "${values[APP_CONVERSATION_AUDIT_BACKFILL_ENABLED]}" != "false" ] \
            || [ -n "${values[APP_CONVERSATION_AUDIT_BACKFILL_TENANT_ID]}" ]; then
            echo "ERROR: Local conversation audit runtime configuration contains an unsafe promoted state." >&2
            exit 1
        fi
    elif [ -n "${values[APP_CONVERSATION_AUDIT_ALLOWED_TENANT_IDS]}" ] \
        && { [ "${values[APP_CONVERSATION_AUDIT_ENABLED]}" != "true" ] \
            || [ "${values[APP_CONVERSATION_AUDIT_LEGACY_READ_ENABLED]}" != "false" ] \
            || [ "${values[APP_CONVERSATION_AUDIT_BACKFILL_ENABLED]}" != "false" ] \
            || [ -n "${values[APP_CONVERSATION_AUDIT_BACKFILL_TENANT_ID]}" ]; }; then
        echo "ERROR: Local conversation audit runtime configuration contains an unsafe staged allowlist state." >&2
        exit 1
    fi
    if [ "${values[APP_CONVERSATION_AUDIT_BACKFILL_ENABLED]}" = "true" ]; then
        if [ "${values[APP_CONVERSATION_AUDIT_ENABLED]}" != "true" ] \
            || [ -z "${values[APP_CONVERSATION_AUDIT_BACKFILL_TENANT_ID]}" ]; then
            echo "ERROR: Local conversation audit runtime configuration contains an unsafe backfill state." >&2
            exit 1
        fi
    elif [ -n "${values[APP_CONVERSATION_AUDIT_BACKFILL_TENANT_ID]}" ]; then
        echo "ERROR: Local conversation audit runtime configuration contains a backfill tenant while backfill is disabled." >&2
        exit 1
    fi
    if [ "${values[APP_CONVERSATION_AUDIT_LEGACY_READ_ENABLED]}" = "true" ] \
        && [ "${values[APP_CONVERSATION_AUDIT_ENABLED]}" != "true" ]; then
        echo "ERROR: Local conversation audit runtime configuration cannot enable legacy reads while protection is disabled." >&2
        exit 1
    fi

    # Unlike ordinary dotenv loading, the lifecycle-owned overlay is
    # authoritative for these six non-secret switches. Exporting the validated
    # values also gives them precedence over Docker Compose env-file lookup.
    for key in "${required_keys[@]}"; do
        export "$key=${values[$key]}"
    done
    CONVERSATION_AUDIT_RUNTIME_ENV_IMPORTED=true
}

create_generated_dev_env() {
    [ -f "$GENERATED_ENV_FILE" ] && return 0

    command -v openssl >/dev/null 2>&1 || {
        echo "ERROR: openssl is required to generate local development secrets."
        exit 1
    }

    umask 077
    mkdir -p "$DEV_SECRETS_DIR"
    printf '%s\n' 'https://example.invalid/local-alert-webhook' > "$ALERT_WEBHOOK_FILE"

    cat > "$GENERATED_ENV_FILE" <<EOF
# Generated exclusively for local development. Never commit this file.
SPRING_PROFILES_ACTIVE=dev
APP_BASE_URL=http://localhost:8080
APP_FRONTEND_BASE_URL=http://localhost:3000
KEYCLOAK_URL=http://keycloak:8080
APP_SECURITY_CORS_ALLOWED_ORIGINS=http://localhost:3000
APP_SECURITY_JWT_TRUSTED_ISSUER_BASES=http://localhost:8180
DB_USER=saas_app
DB_PASSWORD=$(random_secret)
KEYCLOAK_DB_USER=keycloak
KEYCLOAK_DB_PASSWORD=$(random_secret)
KEYCLOAK_ADMIN_USER=admin_local
KEYCLOAK_ADMIN_PASSWORD=$(random_secret)
KEYCLOAK_DEV_SUPERADMIN_INITIAL_PASSWORD=$(random_secret)
KEYCLOAK_PROVISIONING_CLIENT_ID=saas-realm-provisioner
KEYCLOAK_PROVISIONING_CLIENT_SECRET=$(random_secret)
KEYCLOAK_EXISTING_MANAGED_REALMS=saas-admin,saas-bpfarias
GRAFANA_ADMIN_USER=admin_local
GRAFANA_ADMIN_PASSWORD=$(random_secret)
AUTH_SESSION_SECRET=$(random_secret)
APP_SECURITY_ENCRYPTION_SECRET_KEY=$(random_encryption_key)
APP_SECURITY_ENCRYPTION_KEY=$(random_encryption_key)
APP_SECURITY_DATA_ENCRYPTION_KEY=$(random_encryption_key)
APP_CRYPTO_SECRET=$(random_encryption_key)
SAAS_CERTIFICATE_ENCRYPTION_KEY=$(random_encryption_key)
SAAS_TENANT_ENCRYPTION_KEY=$(random_encryption_key)
WHATSAPP_ENCRYPTION_KEY=$(random_encryption_key)
APP_CRYPTO_LEGACY_SECRET=legacy-key-not-configured
APP_SECURITY_ENCRYPTION_LEGACY_SECRET_KEY=legacy-key-not-configured
APP_SECURITY_ENCRYPTION_LEGACY_KEY=legacy-key-not-configured
SAAS_CERTIFICATE_LEGACY_ENCRYPTION_KEY=legacy-key-not-configured
SAAS_TENANT_LEGACY_ENCRYPTION_KEY=legacy-key-not-configured
WHATSAPP_LEGACY_ENCRYPTION_KEY=legacy-key-not-configured
WHATSAPP_WEBHOOK_VERIFY_TOKEN=$(random_secret)
WHATSAPP_WEBHOOK_APP_SECRET=$(random_secret)
CONTACT_WEBHOOK_TOKEN=$(random_secret)
APP_CONVERSATION_AUDIT_WEBHOOK_EXECUTOR_WHATSAPP_CORE_POOL_SIZE=2
APP_CONVERSATION_AUDIT_WEBHOOK_EXECUTOR_WHATSAPP_MAX_POOL_SIZE=4
APP_CONVERSATION_AUDIT_WEBHOOK_EXECUTOR_WHATSAPP_QUEUE_CAPACITY=100
APP_CONVERSATION_AUDIT_WEBHOOK_EXECUTOR_TELEGRAM_CORE_POOL_SIZE=2
APP_CONVERSATION_AUDIT_WEBHOOK_EXECUTOR_TELEGRAM_MAX_POOL_SIZE=4
APP_CONVERSATION_AUDIT_WEBHOOK_EXECUTOR_TELEGRAM_QUEUE_CAPACITY=100
STRIPE_API_KEY=sk_test_local_$(random_secret)
STRIPE_WEBHOOK_SECRET=whsec_$(random_secret)
ALERT_WEBHOOK_URL_FILE=$ALERT_WEBHOOK_FILE
BOT_CHANNEL=telegram
EOF
    chmod 600 "$GENERATED_ENV_FILE" "$ALERT_WEBHOOK_FILE"
    echo "Generated stable local secrets in .env.dev.local (git-ignored)."
}

ensure_generated_auth_session_secret() {
    local temp_file="$GENERATED_ENV_FILE.tmp.$$"

    [ -f "$GENERATED_ENV_FILE" ] || return 0
    grep -q '^AUTH_SESSION_SECRET=.' "$GENERATED_ENV_FILE" && return 0

    umask 077
    cp "$GENERATED_ENV_FILE" "$temp_file"
    printf 'AUTH_SESSION_SECRET=%s\n' "$(random_secret)" >> "$temp_file"
    mv "$temp_file" "$GENERATED_ENV_FILE"
    chmod 600 "$GENERATED_ENV_FILE"
    echo "Added a stable frontend authentication session secret to .env.dev.local."
}

ensure_generated_contact_webhook_token() {
    local temp_file="$GENERATED_ENV_FILE.tmp.$$"
    local occurrence_count existing_value generated_value line

    [ -f "$GENERATED_ENV_FILE" ] || return 0
    if [ -L "$GENERATED_ENV_FILE" ]; then
        echo "ERROR: .env.dev.local must be a regular owner-only file, not a symbolic link."
        exit 1
    fi

    occurrence_count="$(grep -c '^CONTACT_WEBHOOK_TOKEN=' "$GENERATED_ENV_FILE" || true)"
    if [ "$occurrence_count" -gt 1 ]; then
        echo "ERROR: .env.dev.local contains duplicate website contact-token entries."
        exit 1
    fi

    if [ "$occurrence_count" -eq 1 ]; then
        existing_value="$(sed -n 's/^CONTACT_WEBHOOK_TOKEN=//p' "$GENERATED_ENV_FILE")"
        if [ -n "$existing_value" ]; then
            if [[ ! "$existing_value" =~ ^[0-9a-f]{64}$ ]]; then
                echo "ERROR: the website contact token in .env.dev.local is not a generated 32-byte hex secret."
                exit 1
            fi
            chmod 600 "$GENERATED_ENV_FILE"
            return 0
        fi
    fi

    command -v openssl >/dev/null 2>&1 || {
        echo "ERROR: openssl is required to generate the local website contact token."
        exit 1
    }

    generated_value="$(random_secret)"
    while grep -Fq "=$generated_value" "$GENERATED_ENV_FILE"; do
        generated_value="$(random_secret)"
    done

    umask 077
    if [ "$occurrence_count" -eq 0 ]; then
        cp "$GENERATED_ENV_FILE" "$temp_file"
        printf 'CONTACT_WEBHOOK_TOKEN=%s\n' "$generated_value" >> "$temp_file"
    else
        : > "$temp_file"
        while IFS= read -r line || [ -n "$line" ]; do
            case "$line" in
                CONTACT_WEBHOOK_TOKEN=*)
                    printf 'CONTACT_WEBHOOK_TOKEN=%s\n' "$generated_value" >> "$temp_file"
                    ;;
                *)
                    printf '%s\n' "$line" >> "$temp_file"
                    ;;
            esac
        done < "$GENERATED_ENV_FILE"
    fi
    chmod 600 "$temp_file"
    mv "$temp_file" "$GENERATED_ENV_FILE"
    chmod 600 "$GENERATED_ENV_FILE"
    unset existing_value generated_value
    echo "Added a stable owner-only website contact token to .env.dev.local."
}

ensure_generated_keycloak_dev_superadmin_password() {
    local temp_file="$GENERATED_ENV_FILE.tmp.$$"
    local occurrence_count existing_value generated_value line

    [ -f "$GENERATED_ENV_FILE" ] || return 0
    if [ -L "$GENERATED_ENV_FILE" ]; then
        echo "ERROR: .env.dev.local must be a regular owner-only file, not a symbolic link."
        exit 1
    fi

    occurrence_count="$(grep -c '^KEYCLOAK_DEV_SUPERADMIN_INITIAL_PASSWORD=' "$GENERATED_ENV_FILE" || true)"
    if [ "$occurrence_count" -gt 1 ]; then
        echo "ERROR: .env.dev.local contains duplicate DEV Super Admin initial-password entries."
        exit 1
    fi

    if [ "$occurrence_count" -eq 1 ]; then
        existing_value="$(sed -n 's/^KEYCLOAK_DEV_SUPERADMIN_INITIAL_PASSWORD=//p' "$GENERATED_ENV_FILE")"
        if [ -n "$existing_value" ]; then
            if [[ ! "$existing_value" =~ ^[0-9a-f]{64}$ ]]; then
                echo "ERROR: the DEV Super Admin initial password in .env.dev.local is not a generated 32-byte hex secret."
                exit 1
            fi
            chmod 600 "$GENERATED_ENV_FILE"
            return 0
        fi
    fi

    command -v openssl >/dev/null 2>&1 || {
        echo "ERROR: openssl is required to generate the local DEV Super Admin initial password."
        exit 1
    }

    generated_value="$(random_secret)"
    while grep -Fq "=$generated_value" "$GENERATED_ENV_FILE"; do
        generated_value="$(random_secret)"
    done

    umask 077
    if [ "$occurrence_count" -eq 0 ]; then
        cp "$GENERATED_ENV_FILE" "$temp_file"
        printf 'KEYCLOAK_DEV_SUPERADMIN_INITIAL_PASSWORD=%s\n' "$generated_value" >> "$temp_file"
    else
        : > "$temp_file"
        while IFS= read -r line || [ -n "$line" ]; do
            case "$line" in
                KEYCLOAK_DEV_SUPERADMIN_INITIAL_PASSWORD=*)
                    printf 'KEYCLOAK_DEV_SUPERADMIN_INITIAL_PASSWORD=%s\n' "$generated_value" >> "$temp_file"
                    ;;
                *)
                    printf '%s\n' "$line" >> "$temp_file"
                    ;;
            esac
        done < "$GENERATED_ENV_FILE"
    fi
    chmod 600 "$temp_file"
    mv "$temp_file" "$GENERATED_ENV_FILE"
    chmod 600 "$GENERATED_ENV_FILE"
    unset existing_value generated_value
    echo "Added a stable owner-only DEV Super Admin initial password to .env.dev.local."
}

ensure_generated_keycloak_service_account() {
    local temp_file="$GENERATED_ENV_FILE.tmp.$$"
    local changed=false

    [ -f "$GENERATED_ENV_FILE" ] || return 0
    umask 077
    cp "$GENERATED_ENV_FILE" "$temp_file"

    if ! grep -q '^KEYCLOAK_PROVISIONING_CLIENT_ID=' "$temp_file"; then
        printf '%s\n' 'KEYCLOAK_PROVISIONING_CLIENT_ID=saas-realm-provisioner' >> "$temp_file"
        changed=true
    fi
    if ! grep -q '^KEYCLOAK_PROVISIONING_CLIENT_SECRET=' "$temp_file"; then
        printf 'KEYCLOAK_PROVISIONING_CLIENT_SECRET=%s\n' "$(random_secret)" >> "$temp_file"
        changed=true
    fi
    if ! grep -q '^KEYCLOAK_EXISTING_MANAGED_REALMS=' "$temp_file"; then
        printf '%s\n' 'KEYCLOAK_EXISTING_MANAGED_REALMS=saas-admin,saas-bpfarias' >> "$temp_file"
        changed=true
    fi

    if [ "$changed" = true ]; then
        mv "$temp_file" "$GENERATED_ENV_FILE"
        chmod 600 "$GENERATED_ENV_FILE"
        echo "Added the stable Keycloak technical identity to .env.dev.local."
    else
        rm -f "$temp_file"
    fi
}
