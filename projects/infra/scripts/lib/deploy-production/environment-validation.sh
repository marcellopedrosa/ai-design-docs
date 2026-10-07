validate_environment_file() {
  local mode mode_value key value duplicates runtime_root
  local telegram_core_pool_size telegram_max_pool_size telegram_queue_capacity
  local telegram_connect_timeout telegram_read_timeout
  local whatsapp_connect_timeout whatsapp_read_timeout
  local outbound_reconciliation_enabled outbound_terminal_gap_enabled
  local outbound_dispatch_lease outbound_dispatch_margin
  local outbound_attempt_hmac_active_key_id outbound_attempt_hmac_keyring_file
  local -a required_values=(
    COMPOSE_PROJECT_NAME PUBLIC_DOMAIN VPS_PUBLIC_IPV4 PUBLIC_APP_URL PUBLIC_API_URL PUBLIC_AUTH_URL
    DEPLOY_BUILD_LOCAL WITH_MONITORING DEPLOY_WAIT_TIMEOUT ALLOW_DIRTY_WORKTREE
    SPRING_PROFILES_ACTIVE APP_BASE_URL APP_FRONTEND_BASE_URL KEYCLOAK_URL
    APP_SECURITY_CORS_ALLOWED_ORIGINS APP_SECURITY_JWT_TRUSTED_ISSUER_BASES
    APP_SECURITY_RATE_LIMIT_TRUSTED_PROXY_CIDRS
    NGINX_CONFIG_FILE
    TLS_CERT_DIR ALERT_WEBHOOK_URL_FILE BACKUP_DIR BACKUP_MIN_FREE_MB
    DB_USER DB_PASSWORD KEYCLOAK_DB_USER KEYCLOAK_DB_PASSWORD REDIS_PASSWORD
    KEYCLOAK_ADMIN_USER KEYCLOAK_ADMIN_PASSWORD
    KEYCLOAK_PROVISIONING_CLIENT_ID KEYCLOAK_PROVISIONING_CLIENT_SECRET
    AUTH_SESSION_SECRET
    KEYCLOAK_EXISTING_MANAGED_REALMS KEYCLOAK_ADMIN_LOGIN_MFA_ENABLED
    KEYCLOAK_TENANT_FIRST_LOGIN_MFA_ENABLED
    KEYCLOAK_REALM_SMTP_MODE KEYCLOAK_REALM_SMTP_HOST KEYCLOAK_REALM_SMTP_PORT
    KEYCLOAK_REALM_SMTP_FROM KEYCLOAK_REALM_SMTP_FROM_DISPLAY_NAME
    KEYCLOAK_REALM_SMTP_REPLY_TO KEYCLOAK_REALM_SMTP_REPLY_TO_DISPLAY_NAME
    KEYCLOAK_REALM_SMTP_AUTH KEYCLOAK_REALM_SMTP_STARTTLS KEYCLOAK_REALM_SMTP_SSL
    KEYCLOAK_REALM_SMTP_USER TF_VAR_contadorfiscal_smtp_password
    GRAFANA_ADMIN_USER GRAFANA_ADMIN_PASSWORD
    NEXT_PUBLIC_KEYCLOAK_REALM NEXT_PUBLIC_KEYCLOAK_CLIENT_ID NEXT_PUBLIC_APP_NAME
    APP_SECURITY_ENCRYPTION_SECRET_KEY APP_SECURITY_ENCRYPTION_KEY
    APP_SECURITY_DATA_ENCRYPTION_KEY APP_CRYPTO_SECRET
    SAAS_CERTIFICATE_ENCRYPTION_KEY SAAS_TENANT_ENCRYPTION_KEY WHATSAPP_ENCRYPTION_KEY
    APP_CRYPTO_LEGACY_SECRET APP_SECURITY_ENCRYPTION_LEGACY_SECRET_KEY
    APP_SECURITY_ENCRYPTION_LEGACY_KEY SAAS_CERTIFICATE_LEGACY_ENCRYPTION_KEY
    SAAS_TENANT_LEGACY_ENCRYPTION_KEY WHATSAPP_LEGACY_ENCRYPTION_KEY
    WHATSAPP_WEBHOOK_VERIFY_TOKEN WHATSAPP_WEBHOOK_APP_SECRET CONTACT_WEBHOOK_TOKEN
    WHATSAPP_API_CONNECT_TIMEOUT WHATSAPP_API_READ_TIMEOUT
    APP_CONVERSATION_AUDIT_OUTBOUND_RECONCILIATION_ENABLED
    APP_CONVERSATION_AUDIT_OUTBOUND_RECONCILIATION_TERMINAL_GAP_DETECTION_ENABLED
    APP_CONVERSATION_AUDIT_OUTBOUND_DISPATCH_LEASE_DURATION
    APP_CONVERSATION_AUDIT_OUTBOUND_DISPATCH_SAFETY_MARGIN
    CONVERSATION_OUTBOUND_ATTEMPT_HMAC_ACTIVE_KEY_ID
    CONVERSATION_OUTBOUND_ATTEMPT_HMAC_KEYRING_FILE
    STRIPE_API_KEY STRIPE_WEBHOOK_SECRET
    BILLING_SECURITY_SUPER_ADMIN_MFA_ENABLED BILLING_SECURITY_ADMIN_CONTRACT_CONTEXT_MFA_ENABLED
  )
  local -a aes_values=(
    APP_SECURITY_ENCRYPTION_SECRET_KEY APP_SECURITY_ENCRYPTION_KEY
    APP_SECURITY_DATA_ENCRYPTION_KEY APP_CRYPTO_SECRET
    SAAS_CERTIFICATE_ENCRYPTION_KEY SAAS_TENANT_ENCRYPTION_KEY WHATSAPP_ENCRYPTION_KEY
  )

  [[ -f "$ENV_FILE" ]] || die "Environment file not found: $ENV_FILE"
  mode="$(stat -c '%a' "$ENV_FILE")"
  mode_value=$((8#$mode))
  (( (mode_value & 077) == 0 )) || die "$ENV_FILE must not be readable by group/others (use chmod 600)"

  duplicates="$(awk -F= '
    /^[[:space:]]*[A-Za-z_][A-Za-z0-9_]*[[:space:]]*=/ {
      key=$1
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", key)
      count[key]++
    }
    END { for (key in count) if (count[key] > 1) print key }
  ' "$ENV_FILE" | sort)"
  if [[ -n "$duplicates" ]]; then
    printf '[deploy] Duplicate variables in %s:\n%s\n' "$ENV_FILE" "$duplicates" >&2
    die "Each production variable must be declared exactly once"
  fi

  for key in "${required_values[@]}"; do
    value="$(env_value "$key")"
    [[ -n "$value" ]] || die "Required production variable is empty: $key"
    [[ "$value" != *CHANGE_ME* && "$value" != __GENERATE__ && "$value" != __GENERATE_AES256__ ]] \
      || die "Replace the placeholder for $key in $ENV_FILE"
  done

  CFG_PROJECT_NAME="$(env_value COMPOSE_PROJECT_NAME)"
  CFG_DOMAIN="$(env_value PUBLIC_DOMAIN)"
  CFG_VPS_PUBLIC_IPV4="$(env_value VPS_PUBLIC_IPV4)"
  CFG_VPS_PUBLIC_IPV6="$(env_value VPS_PUBLIC_IPV6)"
  CFG_DB_USER="$(env_value DB_USER)"
  CFG_KEYCLOAK_DB_USER="$(env_value KEYCLOAK_DB_USER)"
  CFG_PROVISIONING_CLIENT_ID="$(env_value KEYCLOAK_PROVISIONING_CLIENT_ID)"
  CFG_MANAGED_REALMS="$(env_value KEYCLOAK_EXISTING_MANAGED_REALMS)"
  CFG_BUILD_LOCAL="$(env_value DEPLOY_BUILD_LOCAL true)"
  CFG_WITH_MONITORING="$(env_value WITH_MONITORING false)"
  CFG_WAIT_TIMEOUT="$(env_value DEPLOY_WAIT_TIMEOUT 600)"
  CFG_BACKUP_MIN_FREE_MB="$(env_value BACKUP_MIN_FREE_MB 2048)"
  CFG_ALLOW_DIRTY_WORKTREE="$(env_value ALLOW_DIRTY_WORKTREE false)"

  [[ -z "$REQUESTED_DOMAIN" || "$REQUESTED_DOMAIN" == "$CFG_DOMAIN" ]] \
    || die "--domain does not match PUBLIC_DOMAIN already stored in $ENV_FILE"
  validate_domain "$CFG_DOMAIN" || die "Invalid PUBLIC_DOMAIN: $CFG_DOMAIN"
  validate_ipv4 "$CFG_VPS_PUBLIC_IPV4" || die "VPS_PUBLIC_IPV4 is not a valid IPv4 address"
  if [[ -n "$CFG_VPS_PUBLIC_IPV6" ]]; then
    CFG_VPS_PUBLIC_IPV6="$(normalize_ipv6 "$CFG_VPS_PUBLIC_IPV6")" \
      || die "VPS_PUBLIC_IPV6 is not a valid IPv6 address"
  fi
  [[ "$CFG_PROJECT_NAME" =~ ^[a-z0-9][a-z0-9_-]*$ ]] || die "Invalid COMPOSE_PROJECT_NAME"
  [[ "$CFG_DB_USER" == saas_app ]] \
    || die "DB_USER must be saas_app because infra/db/init-databases.sql grants that fixed role"
  [[ "$CFG_DB_USER" =~ ^[a-z_][a-z0-9_]*$ ]] || die "Invalid DB_USER"
  [[ "$CFG_KEYCLOAK_DB_USER" =~ ^[a-z_][a-z0-9_]*$ ]] || die "Invalid KEYCLOAK_DB_USER"
  [[ "$CFG_PROVISIONING_CLIENT_ID" =~ ^[A-Za-z0-9._-]+$ ]] \
    || die "Invalid KEYCLOAK_PROVISIONING_CLIENT_ID"
  [[ "$(env_value KEYCLOAK_ADMIN_LOGIN_MFA_ENABLED)" == true ]] \
    || die "KEYCLOAK_ADMIN_LOGIN_MFA_ENABLED must remain true in production"
  [[ "$(env_value KEYCLOAK_TENANT_FIRST_LOGIN_MFA_ENABLED)" == true ]] \
    || die "KEYCLOAK_TENANT_FIRST_LOGIN_MFA_ENABLED must remain true in production"
  validate_billing_mfa_production \
    "$(env_value BILLING_SECURITY_SUPER_ADMIN_MFA_ENABLED)" \
    "$(env_value BILLING_SECURITY_ADMIN_CONTRACT_CONTEXT_MFA_ENABLED)"
  validate_keycloak_realm_smtp_production
  [[ "$(env_value NEXT_PUBLIC_KEYCLOAK_REALM)" == saas-admin ]] \
    || die "NEXT_PUBLIC_KEYCLOAK_REALM must be saas-admin for the current frontend contract"
  [[ "$(env_value NEXT_PUBLIC_KEYCLOAK_CLIENT_ID)" == saas-frontend-spa ]] \
    || die "NEXT_PUBLIC_KEYCLOAK_CLIENT_ID must be saas-frontend-spa for the current frontend contract"
  value="$(env_value AUTH_SESSION_SECRET)"
  (( ${#value} >= 32 )) || die "AUTH_SESSION_SECRET must contain at least 32 characters"
  value="$(env_value AUTH_SESSION_PREVIOUS_SECRET)"
  [[ -z "$value" || ${#value} -ge 32 ]] \
    || die "AUTH_SESSION_PREVIOUS_SECRET must be empty or contain at least 32 characters"
  validate_boolean "$CFG_BUILD_LOCAL" || die "DEPLOY_BUILD_LOCAL must be true or false"
  [[ "$CFG_BUILD_LOCAL" == true ]] \
    || die "DEPLOY_BUILD_LOCAL=false is disabled: frontend OAuth values and Flyway files must be built from this verified checkout"
  [[ -z "$(env_value BACKEND_IMAGE)" && -z "$(env_value FRONTEND_IMAGE)" ]] \
    || die "BACKEND_IMAGE and FRONTEND_IMAGE must stay empty while DEPLOY_BUILD_LOCAL=true"
  validate_boolean "$CFG_WITH_MONITORING" || die "WITH_MONITORING must be true or false"
  validate_boolean "$CFG_ALLOW_DIRTY_WORKTREE" || die "ALLOW_DIRTY_WORKTREE must be true or false"
  [[ "$CFG_WAIT_TIMEOUT" =~ ^[1-9][0-9]*$ ]] || die "DEPLOY_WAIT_TIMEOUT must be a positive integer"
  [[ "$CFG_BACKUP_MIN_FREE_MB" =~ ^[1-9][0-9]*$ ]] \
    || die "BACKUP_MIN_FREE_MB must be a positive integer"
  value="$(env_value TELEGRAM_WEBHOOK_RECONCILIATION_INITIAL_DELAY_MS 60000)"
  validate_positive_integer "$value" \
    || die "TELEGRAM_WEBHOOK_RECONCILIATION_INITIAL_DELAY_MS must be a positive integer"
  value="$(env_value TELEGRAM_WEBHOOK_RECONCILIATION_DELAY_MS 900000)"
  validate_positive_integer "$value" \
    || die "TELEGRAM_WEBHOOK_RECONCILIATION_DELAY_MS must be a positive integer"
  telegram_connect_timeout="$(env_value TELEGRAM_API_CONNECT_TIMEOUT 5s)"
  validate_positive_spring_duration "$telegram_connect_timeout" \
    || die "TELEGRAM_API_CONNECT_TIMEOUT must be a positive Spring duration using ms, s or m"
  telegram_read_timeout="$(env_value TELEGRAM_API_READ_TIMEOUT 10s)"
  validate_positive_spring_duration "$telegram_read_timeout" \
    || die "TELEGRAM_API_READ_TIMEOUT must be a positive Spring duration using ms, s or m"
  whatsapp_connect_timeout="$(env_value WHATSAPP_API_CONNECT_TIMEOUT 5s)"
  validate_positive_spring_duration "$whatsapp_connect_timeout" \
    || die "WHATSAPP_API_CONNECT_TIMEOUT must be a positive Spring duration using ms, s or m"
  whatsapp_read_timeout="$(env_value WHATSAPP_API_READ_TIMEOUT 10s)"
  validate_positive_spring_duration "$whatsapp_read_timeout" \
    || die "WHATSAPP_API_READ_TIMEOUT must be a positive Spring duration using ms, s or m"
  outbound_reconciliation_enabled="$(env_value APP_CONVERSATION_AUDIT_OUTBOUND_RECONCILIATION_ENABLED false)"
  outbound_terminal_gap_enabled="$(env_value APP_CONVERSATION_AUDIT_OUTBOUND_RECONCILIATION_TERMINAL_GAP_DETECTION_ENABLED false)"
  validate_outbound_reconciliation_flags \
    "$outbound_reconciliation_enabled" \
    "$outbound_terminal_gap_enabled" \
    || die "Terminal gap detection requires outbound reconciliation and both flags must be true or false"
  outbound_dispatch_lease="$(env_value APP_CONVERSATION_AUDIT_OUTBOUND_DISPATCH_LEASE_DURATION 5m)"
  validate_positive_spring_duration "$outbound_dispatch_lease" \
    || die "APP_CONVERSATION_AUDIT_OUTBOUND_DISPATCH_LEASE_DURATION must be a positive Spring duration using ms, s or m"
  outbound_dispatch_margin="$(env_value APP_CONVERSATION_AUDIT_OUTBOUND_DISPATCH_SAFETY_MARGIN 30s)"
  validate_positive_spring_duration "$outbound_dispatch_margin" \
    || die "APP_CONVERSATION_AUDIT_OUTBOUND_DISPATCH_SAFETY_MARGIN must be a positive Spring duration using ms, s or m"
  validate_outbound_dispatch_bound \
    "$outbound_dispatch_lease" \
    "$outbound_dispatch_margin" \
    "$telegram_connect_timeout" \
    "$telegram_read_timeout" \
    "$whatsapp_connect_timeout" \
    "$whatsapp_read_timeout" \
    || die "Outbound dispatch lease must be 1m..30m and strictly exceed the maximum provider call plus a 1s..5m safety margin"
  outbound_attempt_hmac_active_key_id="$(env_value CONVERSATION_OUTBOUND_ATTEMPT_HMAC_ACTIVE_KEY_ID)"
  outbound_attempt_hmac_keyring_file="$(env_value CONVERSATION_OUTBOUND_ATTEMPT_HMAC_KEYRING_FILE)"
  validate_outbound_attempt_hmac_references \
    "$outbound_attempt_hmac_active_key_id" \
    "$outbound_attempt_hmac_keyring_file" \
    || die "Outbound-attempt HMAC requires an opaque active key ID and its canonical container keyring reference"
  CFG_OUTBOUND_ATTEMPT_HMAC_KEYRING_SOURCE="$(resolve_repository_path \
    "$OUTBOUND_ATTEMPT_HMAC_KEYRING_SOURCE_RELATIVE")"
  validate_outbound_attempt_hmac_keyring_file \
    "$CFG_OUTBOUND_ATTEMPT_HMAC_KEYRING_SOURCE" \
    "$outbound_attempt_hmac_active_key_id" \
    || die "Outbound-attempt HMAC keyring preflight failed (regular owner-only file, bounded strict JSON and active 32-byte key are required)"
  telegram_core_pool_size="$(env_value TELEGRAM_WEBHOOK_EXECUTOR_CORE_POOL_SIZE 2)"
  telegram_max_pool_size="$(env_value TELEGRAM_WEBHOOK_EXECUTOR_MAX_POOL_SIZE 4)"
  telegram_queue_capacity="$(env_value TELEGRAM_WEBHOOK_EXECUTOR_QUEUE_CAPACITY 100)"
  validate_positive_integer "$telegram_core_pool_size" \
    || die "TELEGRAM_WEBHOOK_EXECUTOR_CORE_POOL_SIZE must be a positive integer"
  validate_positive_integer "$telegram_max_pool_size" \
    || die "TELEGRAM_WEBHOOK_EXECUTOR_MAX_POOL_SIZE must be a positive integer"
  validate_positive_integer "$telegram_queue_capacity" \
    || die "TELEGRAM_WEBHOOK_EXECUTOR_QUEUE_CAPACITY must be a positive integer"
  integer_greater_or_equal "$telegram_max_pool_size" "$telegram_core_pool_size" \
    || die "TELEGRAM_WEBHOOK_EXECUTOR_MAX_POOL_SIZE must be greater than or equal to TELEGRAM_WEBHOOK_EXECUTOR_CORE_POOL_SIZE"
  inbound_whatsapp_core_pool_size="$(env_value APP_CONVERSATION_AUDIT_WEBHOOK_EXECUTOR_WHATSAPP_CORE_POOL_SIZE)"
  inbound_whatsapp_max_pool_size="$(env_value APP_CONVERSATION_AUDIT_WEBHOOK_EXECUTOR_WHATSAPP_MAX_POOL_SIZE)"
  inbound_whatsapp_queue_capacity="$(env_value APP_CONVERSATION_AUDIT_WEBHOOK_EXECUTOR_WHATSAPP_QUEUE_CAPACITY)"
  inbound_telegram_core_pool_size="$(env_value APP_CONVERSATION_AUDIT_WEBHOOK_EXECUTOR_TELEGRAM_CORE_POOL_SIZE)"
  inbound_telegram_max_pool_size="$(env_value APP_CONVERSATION_AUDIT_WEBHOOK_EXECUTOR_TELEGRAM_MAX_POOL_SIZE)"
  inbound_telegram_queue_capacity="$(env_value APP_CONVERSATION_AUDIT_WEBHOOK_EXECUTOR_TELEGRAM_QUEUE_CAPACITY)"
  for inbound_pool_value in \
    "$inbound_whatsapp_core_pool_size" \
    "$inbound_whatsapp_max_pool_size" \
    "$inbound_whatsapp_queue_capacity" \
    "$inbound_telegram_core_pool_size" \
    "$inbound_telegram_max_pool_size" \
    "$inbound_telegram_queue_capacity"; do
    validate_positive_integer "$inbound_pool_value" \
      || die "All APP_CONVERSATION_AUDIT_WEBHOOK_EXECUTOR_* values must be positive integers"
  done
  (( 10#$inbound_whatsapp_core_pool_size <= 64 \
      && 10#$inbound_whatsapp_max_pool_size <= 64 \
      && 10#$inbound_telegram_core_pool_size <= 64 \
      && 10#$inbound_telegram_max_pool_size <= 64 )) \
    || die "Inbound webhook executor pool sizes must be between 1 and 64"
  (( 10#$inbound_whatsapp_queue_capacity <= 10000 \
      && 10#$inbound_telegram_queue_capacity <= 10000 )) \
    || die "Inbound webhook executor queue capacities must be between 1 and 10000"
  integer_greater_or_equal \
    "$inbound_whatsapp_max_pool_size" "$inbound_whatsapp_core_pool_size" \
    || die "WhatsApp inbound webhook max pool size must be greater than or equal to core pool size"
  integer_greater_or_equal \
    "$inbound_telegram_max_pool_size" "$inbound_telegram_core_pool_size" \
    || die "Telegram inbound webhook max pool size must be greater than or equal to core pool size"
  if [[ -n "$CLI_WITH_MONITORING" ]]; then
    CFG_WITH_MONITORING=true
  fi

  for key in "${aes_values[@]}"; do
    validate_aes_key "$key" "$(env_value "$key")"
  done

  CFG_APP_HOST="app.${CFG_DOMAIN}"
  CFG_API_HOST="api.${CFG_DOMAIN}"
  CFG_APP_URL="https://${CFG_APP_HOST}"
  CFG_API_URL="https://${CFG_API_HOST}"

  local configured_auth_url
  configured_auth_url="$(env_value PUBLIC_AUTH_URL)"
  if [[ "$configured_auth_url" == 'https://${PUBLIC_DOMAIN}' || "$configured_auth_url" == "https://${CFG_DOMAIN}" ]]; then
    CFG_AUTH_HOST="auth.${CFG_DOMAIN}"
  elif [[ "$configured_auth_url" == 'https://auth.${PUBLIC_DOMAIN}' || "$configured_auth_url" == "https://auth.${CFG_DOMAIN}" ]]; then
    CFG_AUTH_HOST="auth.${CFG_DOMAIN}"
  elif [[ "$configured_auth_url" =~ ^https://([a-zA-Z0-9.-]+)$ ]]; then
    CFG_AUTH_HOST="${BASH_REMATCH[1]}"
  else
    CFG_AUTH_HOST="auth.${CFG_DOMAIN}"
  fi
  validate_domain "$CFG_AUTH_HOST" || die "Invalid host in PUBLIC_AUTH_URL: $CFG_AUTH_HOST"
  CFG_AUTH_URL="https://${CFG_AUTH_HOST}"

  value="$(expand_public_references "$(env_value PUBLIC_APP_URL)")"
  [[ "$value" == "$CFG_APP_URL" ]] || die "PUBLIC_APP_URL must be $CFG_APP_URL"
  value="$(expand_public_references "$(env_value PUBLIC_API_URL)")"
  [[ "$value" == "$CFG_API_URL" ]] || die "PUBLIC_API_URL must be $CFG_API_URL"
  value="$(expand_public_references "$(env_value PUBLIC_AUTH_URL)")"
  [[ "$value" == "$CFG_AUTH_URL" ]] || die "PUBLIC_AUTH_URL must be $CFG_AUTH_URL"

  [[ "$(env_value SPRING_PROFILES_ACTIVE)" == prd ]] \
    || die "SPRING_PROFILES_ACTIVE must be prd"
  [[ "$(expand_public_references "$(env_value APP_BASE_URL)")" == "$CFG_API_URL" ]] \
    || die "APP_BASE_URL must resolve to $CFG_API_URL"
  [[ "$(expand_public_references "$(env_value APP_FRONTEND_BASE_URL)")" == "$CFG_APP_URL" ]] \
    || die "APP_FRONTEND_BASE_URL must resolve to $CFG_APP_URL"
  [[ "$(env_value KEYCLOAK_URL)" == http://keycloak:8080 ]] \
    || die "KEYCLOAK_URL must stay on the private Docker network: http://keycloak:8080"
  [[ "$(expand_public_references "$(env_value APP_SECURITY_CORS_ALLOWED_ORIGINS)")" == "$CFG_APP_URL" ]] \
    || die "APP_SECURITY_CORS_ALLOWED_ORIGINS must resolve to $CFG_APP_URL"
  [[ "$(expand_public_references "$(env_value APP_SECURITY_JWT_TRUSTED_ISSUER_BASES)")" == "$CFG_AUTH_URL" ]] \
    || die "APP_SECURITY_JWT_TRUSTED_ISSUER_BASES must resolve to $CFG_AUTH_URL"

  CFG_BACKUP_DIR="$(resolve_repository_path "$(env_value BACKUP_DIR)")"
  CFG_TLS_DIR="$(resolve_repository_path "$(env_value TLS_CERT_DIR)")"
  CFG_NGINX_CONFIG="$(resolve_repository_path "$(env_value NGINX_CONFIG_FILE)")"
  CFG_ALERT_WEBHOOK_FILE="$(resolve_repository_path "$(env_value ALERT_WEBHOOK_URL_FILE)")"

  runtime_root="$(realpath -m -- "${REPOSITORY_ROOT}/.deploy")"
  for value in "$CFG_NGINX_CONFIG" "$CFG_ALERT_WEBHOOK_FILE"; do
    [[ "$value" == "${runtime_root}/"* ]] \
      || die "Rendered configs and local secret files must stay below ${runtime_root}: $value"
  done
  [[ "$CFG_NGINX_CONFIG" != "$CFG_ADMIN_REALM_FILE" \
      && "$CFG_NGINX_CONFIG" != "$CFG_TENANT_REALM_FILE" \
      && "$CFG_NGINX_CONFIG" != "$CFG_ALERT_WEBHOOK_FILE" \
      && "$CFG_ADMIN_REALM_FILE" != "$CFG_TENANT_REALM_FILE" \
      && "$CFG_ADMIN_REALM_FILE" != "$CFG_ALERT_WEBHOOK_FILE" \
      && "$CFG_TENANT_REALM_FILE" != "$CFG_ALERT_WEBHOOK_FILE" ]] \
    || die "Rendered production asset paths must be distinct"

  [[ "$CFG_BACKUP_DIR" != / && "$CFG_BACKUP_DIR" != "$REPOSITORY_ROOT" ]] \
    || die "BACKUP_DIR must be a dedicated directory, never / or the repository root"
  [[ "${REPOSITORY_ROOT}/" != "${CFG_BACKUP_DIR}/"* ]] \
    || die "BACKUP_DIR cannot be an ancestor of the repository"
  for value in "$CFG_NGINX_CONFIG" "$CFG_ALERT_WEBHOOK_FILE"; do
    [[ "$value" != "$CFG_BACKUP_DIR" && "$value" != "${CFG_BACKUP_DIR}/"* ]] \
      || die "BACKUP_DIR must not contain rendered runtime assets: $CFG_BACKUP_DIR"
  done
}

sanitize_compose_environment() {
  local key
  while IFS= read -r key; do
    [[ -n "$key" ]] && unset "$key" || true
  done < <(
    {
      awk -F= '/^[[:space:]]*[A-Za-z_][A-Za-z0-9_]*[[:space:]]*=/{
        key=$1
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", key)
        print key
      }' "$ENV_FILE"
      grep -hEo '\$\{[A-Za-z_][A-Za-z0-9_]*' "$BASE_COMPOSE_FILE" "$PRODUCTION_COMPOSE_FILE" \
        | sed 's/^${//'
    } | sort -u
  )
  unset COMPOSE_FILE COMPOSE_PROFILES COMPOSE_PROJECT_NAME || true
}

validate_effective_compose_config() {
  local frozen_config_file="${1:-}"
  local config_json mapping service compose_key env_key expected actual
  local -a protected_environment_mappings=(
    "backend|DB_USER|DB_USER"
    "backend|DB_PASSWORD|DB_PASSWORD"
    "backend|REDIS_PASSWORD|REDIS_PASSWORD"
    "backend|KEYCLOAK_PROVISIONING_CLIENT_ID|KEYCLOAK_PROVISIONING_CLIENT_ID"
    "backend|KEYCLOAK_PROVISIONING_CLIENT_SECRET|KEYCLOAK_PROVISIONING_CLIENT_SECRET"
    "backend|KEYCLOAK_REALM_SMTP_HOST|KEYCLOAK_REALM_SMTP_HOST"
    "backend|KEYCLOAK_REALM_SMTP_PORT|KEYCLOAK_REALM_SMTP_PORT"
    "backend|KEYCLOAK_REALM_SMTP_FROM|KEYCLOAK_REALM_SMTP_FROM"
    "backend|KEYCLOAK_REALM_SMTP_FROM_DISPLAY_NAME|KEYCLOAK_REALM_SMTP_FROM_DISPLAY_NAME"
    "backend|KEYCLOAK_REALM_SMTP_REPLY_TO|KEYCLOAK_REALM_SMTP_REPLY_TO"
    "backend|KEYCLOAK_REALM_SMTP_REPLY_TO_DISPLAY_NAME|KEYCLOAK_REALM_SMTP_REPLY_TO_DISPLAY_NAME"
    "backend|KEYCLOAK_REALM_SMTP_AUTH|KEYCLOAK_REALM_SMTP_AUTH"
    "backend|KEYCLOAK_REALM_SMTP_STARTTLS|KEYCLOAK_REALM_SMTP_STARTTLS"
    "backend|KEYCLOAK_REALM_SMTP_SSL|KEYCLOAK_REALM_SMTP_SSL"
    "backend|KEYCLOAK_REALM_SMTP_USER|KEYCLOAK_REALM_SMTP_USER"
    "backend|KEYCLOAK_REALM_SMTP_PASSWORD|TF_VAR_contadorfiscal_smtp_password"
    "backend|APP_SECURITY_ENCRYPTION_SECRET_KEY|APP_SECURITY_ENCRYPTION_SECRET_KEY"
    "backend|APP_SECURITY_ENCRYPTION_KEY|APP_SECURITY_ENCRYPTION_KEY"
    "backend|APP_SECURITY_DATA_ENCRYPTION_KEY|APP_SECURITY_DATA_ENCRYPTION_KEY"
    "backend|APP_CRYPTO_SECRET|APP_CRYPTO_SECRET"
    "backend|SAAS_CERTIFICATE_ENCRYPTION_KEY|SAAS_CERTIFICATE_ENCRYPTION_KEY"
    "backend|SAAS_TENANT_ENCRYPTION_KEY|SAAS_TENANT_ENCRYPTION_KEY"
    "backend|WHATSAPP_ENCRYPTION_KEY|WHATSAPP_ENCRYPTION_KEY"
    "backend|APP_CRYPTO_LEGACY_SECRET|APP_CRYPTO_LEGACY_SECRET"
    "backend|APP_SECURITY_ENCRYPTION_LEGACY_SECRET_KEY|APP_SECURITY_ENCRYPTION_LEGACY_SECRET_KEY"
    "backend|APP_SECURITY_ENCRYPTION_LEGACY_KEY|APP_SECURITY_ENCRYPTION_LEGACY_KEY"
    "backend|SAAS_CERTIFICATE_LEGACY_ENCRYPTION_KEY|SAAS_CERTIFICATE_LEGACY_ENCRYPTION_KEY"
    "backend|SAAS_TENANT_LEGACY_ENCRYPTION_KEY|SAAS_TENANT_LEGACY_ENCRYPTION_KEY"
    "backend|WHATSAPP_LEGACY_ENCRYPTION_KEY|WHATSAPP_LEGACY_ENCRYPTION_KEY"
    "backend|CONVERSATION_OUTBOUND_ATTEMPT_HMAC_ACTIVE_KEY_ID|CONVERSATION_OUTBOUND_ATTEMPT_HMAC_ACTIVE_KEY_ID"
    "backend|CONVERSATION_OUTBOUND_ATTEMPT_HMAC_KEYRING_FILE|CONVERSATION_OUTBOUND_ATTEMPT_HMAC_KEYRING_FILE"
    "outbound-attempt-keyring-init|OUTBOUND_HMAC_ACTIVE_KEY_ID|CONVERSATION_OUTBOUND_ATTEMPT_HMAC_ACTIVE_KEY_ID"
    "backend|WHATSAPP_WEBHOOK_VERIFY_TOKEN|WHATSAPP_WEBHOOK_VERIFY_TOKEN"
    "backend|WHATSAPP_WEBHOOK_APP_SECRET|WHATSAPP_WEBHOOK_APP_SECRET"
    "backend|WEBSITE_CONTACT_TOKEN|CONTACT_WEBHOOK_TOKEN"
    "backend|STRIPE_API_KEY|STRIPE_API_KEY"
    "backend|STRIPE_WEBHOOK_SECRET|STRIPE_WEBHOOK_SECRET"
    "backend|BILLING_SECURITY_SUPER_ADMIN_MFA_ENABLED|BILLING_SECURITY_SUPER_ADMIN_MFA_ENABLED"
    "backend|BILLING_SECURITY_ADMIN_CONTRACT_CONTEXT_MFA_ENABLED|BILLING_SECURITY_ADMIN_CONTRACT_CONTEXT_MFA_ENABLED"
    "frontend|AUTH_SESSION_SECRET|AUTH_SESSION_SECRET"
    "frontend|AUTH_SESSION_PREVIOUS_SECRET|AUTH_SESSION_PREVIOUS_SECRET"
    "postgres-app|POSTGRES_USER|DB_USER"
    "postgres-app|POSTGRES_PASSWORD|DB_PASSWORD"
    "postgres-keycloak|POSTGRES_USER|KEYCLOAK_DB_USER"
    "postgres-keycloak|POSTGRES_PASSWORD|KEYCLOAK_DB_PASSWORD"
    "redis|REDIS_PASSWORD|REDIS_PASSWORD"
    "keycloak|KC_BOOTSTRAP_ADMIN_USERNAME|KEYCLOAK_ADMIN_USER"
    "keycloak|KCRAW_BOOTSTRAP_ADMIN_PASSWORD|KEYCLOAK_ADMIN_PASSWORD"
    "keycloak|KC_DB_USERNAME|KEYCLOAK_DB_USER"
    "keycloak|KCRAW_DB_PASSWORD|KEYCLOAK_DB_PASSWORD"
    "keycloak-provisioning-init|KEYCLOAK_BOOTSTRAP_ADMIN_USER|KEYCLOAK_ADMIN_USER"
    "keycloak-provisioning-init|KEYCLOAK_BOOTSTRAP_ADMIN_PASSWORD|KEYCLOAK_ADMIN_PASSWORD"
    "keycloak-provisioning-init|KEYCLOAK_PROVISIONING_CLIENT_ID|KEYCLOAK_PROVISIONING_CLIENT_ID"
    "keycloak-provisioning-init|KEYCLOAK_PROVISIONING_CLIENT_SECRET|KEYCLOAK_PROVISIONING_CLIENT_SECRET"
    "keycloak-provisioning-init|KEYCLOAK_EXISTING_MANAGED_REALMS|KEYCLOAK_EXISTING_MANAGED_REALMS"
    "keycloak-provisioning-init|KEYCLOAK_ADMIN_LOGIN_MFA_ENABLED|KEYCLOAK_ADMIN_LOGIN_MFA_ENABLED"
    "keycloak-provisioning-init|KEYCLOAK_TENANT_FIRST_LOGIN_MFA_ENABLED|KEYCLOAK_TENANT_FIRST_LOGIN_MFA_ENABLED"
    "keycloak-provisioning-init|KEYCLOAK_REALM_SMTP_HOST|KEYCLOAK_REALM_SMTP_HOST"
    "keycloak-provisioning-init|KEYCLOAK_REALM_SMTP_PORT|KEYCLOAK_REALM_SMTP_PORT"
    "keycloak-provisioning-init|KEYCLOAK_REALM_SMTP_FROM|KEYCLOAK_REALM_SMTP_FROM"
    "keycloak-provisioning-init|KEYCLOAK_REALM_SMTP_FROM_DISPLAY_NAME|KEYCLOAK_REALM_SMTP_FROM_DISPLAY_NAME"
    "keycloak-provisioning-init|KEYCLOAK_REALM_SMTP_REPLY_TO|KEYCLOAK_REALM_SMTP_REPLY_TO"
    "keycloak-provisioning-init|KEYCLOAK_REALM_SMTP_REPLY_TO_DISPLAY_NAME|KEYCLOAK_REALM_SMTP_REPLY_TO_DISPLAY_NAME"
    "keycloak-provisioning-init|KEYCLOAK_REALM_SMTP_AUTH|KEYCLOAK_REALM_SMTP_AUTH"
    "keycloak-provisioning-init|KEYCLOAK_REALM_SMTP_STARTTLS|KEYCLOAK_REALM_SMTP_STARTTLS"
    "keycloak-provisioning-init|KEYCLOAK_REALM_SMTP_SSL|KEYCLOAK_REALM_SMTP_SSL"
    "keycloak-provisioning-init|KEYCLOAK_REALM_SMTP_USER|KEYCLOAK_REALM_SMTP_USER"
    "keycloak-provisioning-init|TF_VAR_contadorfiscal_smtp_password|TF_VAR_contadorfiscal_smtp_password"
  )
  if [[ -n "$frozen_config_file" ]]; then
    [[ ! -L "$frozen_config_file" && -f "$frozen_config_file" ]] \
      || die "Frozen effective Compose model is unavailable"
    config_json="$(<"$frozen_config_file")"
  else
    config_json="$("${COMPOSE[@]}" config --format json)"
  fi
  jq -e \
    --arg project "$CFG_PROJECT_NAME" \
    --arg app "$CFG_APP_URL" \
    --arg api "$CFG_API_URL" \
    --arg auth "$CFG_AUTH_URL" \
    --arg realm "$(env_value NEXT_PUBLIC_KEYCLOAK_REALM)" \
    --arg client "$(env_value NEXT_PUBLIC_KEYCLOAK_CLIENT_ID)" \
    --arg app_name "$(env_value NEXT_PUBLIC_APP_NAME)" \
    --arg outbound_reconciliation \
      "$(env_value APP_CONVERSATION_AUDIT_OUTBOUND_RECONCILIATION_ENABLED false)" \
    --arg terminal_gap \
      "$(env_value APP_CONVERSATION_AUDIT_OUTBOUND_RECONCILIATION_TERMINAL_GAP_DETECTION_ENABLED false)" '
      .name == $project
      and .services.backend.environment.SPRING_PROFILES_ACTIVE == "prd"
      and .services.backend.environment.APP_BASE_URL == $api
      and .services.backend.environment.APP_FRONTEND_BASE_URL == $app
      and .services.backend.environment.KEYCLOAK_URL == "http://keycloak:8080"
      and .services.backend.environment.KEYCLOAK_REALM_SMTP_MODE == "prd"
      and .services["keycloak-provisioning-init"].environment.KEYCLOAK_REALM_SMTP_MODE == "prd"
      and .services.backend.environment.APP_SECURITY_CORS_ALLOWED_ORIGINS == $app
      and .services.backend.environment.APP_SECURITY_JWT_TRUSTED_ISSUER_BASES == $auth
      and .services.frontend.build.args.NEXT_PUBLIC_API_BASE_URL == $api
      and .services.frontend.build.args.NEXT_PUBLIC_KEYCLOAK_URL == $auth
      and .services.frontend.build.args.NEXT_PUBLIC_KEYCLOAK_REALM == $realm
      and .services.frontend.build.args.NEXT_PUBLIC_KEYCLOAK_CLIENT_ID == $client
      and .services.frontend.build.args.NEXT_PUBLIC_APP_NAME == $app_name
      and .services.frontend.environment.NEXT_PUBLIC_API_BASE_URL == $api
      and .services.frontend.environment.NEXT_PUBLIC_KEYCLOAK_URL == $auth
      and .services.frontend.environment.NEXT_PUBLIC_KEYCLOAK_REALM == $realm
      and .services.frontend.environment.NEXT_PUBLIC_KEYCLOAK_CLIENT_ID == $client
      and .services.frontend.environment.NEXT_PUBLIC_APP_NAME == $app_name
      and .services.frontend.environment.AUTH_TRUSTED_ISSUER_BASES == ($auth + "/realms")
      and .services.frontend.environment.AUTH_KEYCLOAK_INTERNAL_URL == "http://keycloak:8080"
      and .services.frontend.environment.AUTH_SESSION_PUBLIC_ORIGIN == $app
      and .services.frontend.environment.AUTH_EXPECTED_AUDIENCE == "saas-service-api"
      and .services.frontend.environment.AUTH_EXPECTED_AUTHORIZED_PARTY == $client
      and .services.keycloak.environment.KC_HOSTNAME == $auth
      and .services.keycloak.environment.KC_HTTP_ENABLED == "true"
      and .services.backend.environment.TELEGRAM_API_BASE_URL == "https://api.telegram.org"
      and .services.backend.environment.TELEGRAM_WEBHOOK_RECONCILIATION_ENABLED == "true"
      and .services.backend.environment.APP_CONVERSATION_AUDIT_OUTBOUND_RECONCILIATION_ENABLED == $outbound_reconciliation
      and .services.backend.environment.APP_CONVERSATION_AUDIT_OUTBOUND_RECONCILIATION_TERMINAL_GAP_DETECTION_ENABLED == $terminal_gap
      and ([.services | keys[] | select(ascii_downcase | contains("ngrok"))] | length == 0)
      and (.services | has("mailpit") | not)
    ' <<<"$config_json" >/dev/null \
    || die "Effective Compose configuration does not match the validated production domain/auth/Telegram/no-ngrok contract"

  validate_outbound_attempt_hmac_effective_compose \
    "$config_json" \
    "$CFG_OUTBOUND_ATTEMPT_HMAC_KEYRING_SOURCE" \
    "$(env_value CONVERSATION_OUTBOUND_ATTEMPT_HMAC_KEYRING_FILE)" \
    "prd-outbound-attempt-keyring" \
    "$(resolve_repository_path "$OUTBOUND_ATTEMPT_HMAC_APPROVAL_SOURCE_RELATIVE")" \
    "/source/conversation-outbound-attempt-hmac-keyring.json" \
    "" \
    || die "Effective Compose configuration does not preserve the isolated read-only outbound HMAC keyring boundary"

  # Compare sensitive values without printing or passing them as process
  # arguments. Canonical `compose config` escapes literal dollars as `$$`; the
  # frozen model restores one literal dollar when Compose consumes it again.
  for mapping in "${protected_environment_mappings[@]}"; do
    IFS='|' read -r service compose_key env_key <<<"$mapping"
    expected="$(env_value "$env_key")"
    actual="$(
      jq -er \
        --arg service "$service" \
        --arg variable "$compose_key" \
        '.services[$service].environment[$variable] // empty' \
        <<<"$config_json"
    )" || die "Protected Compose value is missing: ${service}.${compose_key}"
    # Canonical `compose config` escapes every literal dollar as `$$` so the
    # generated model can be consumed again without another interpolation.
    actual="${actual//\$\$/\$}"
    [[ "$actual" == "$expected" ]] \
      || die "Effective Compose service value differs from the protected $env_key value"
  done

  if [[ "$CFG_WITH_MONITORING" == true ]]; then
    for mapping in \
      "grafana|GF_SECURITY_ADMIN_USER|GRAFANA_ADMIN_USER" \
      "grafana|GF_SECURITY_ADMIN_PASSWORD|GRAFANA_ADMIN_PASSWORD"; do
      IFS='|' read -r service compose_key env_key <<<"$mapping"
      expected="$(env_value "$env_key")"
      actual="$(
        jq -er \
          --arg service "$service" \
          --arg variable "$compose_key" \
          '.services[$service].environment[$variable] // empty' \
          <<<"$config_json"
      )" || die "Protected Compose value is missing: ${service}.${compose_key}"
      actual="${actual//\$\$/\$}"
      [[ "$actual" == "$expected" ]] \
        || die "Effective Compose service value differs from the protected $env_key value"
    done
  fi
}
