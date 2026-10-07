validate_domain() {
  local domain="$1"
  local label
  local old_ifs="$IFS"
  local -a labels=()

  [[ ${#domain} -le 253 ]] || return 1
  [[ "$domain" != *..* && "$domain" == *.* ]] || return 1
  [[ "$domain" == *.com.br ]] || return 1
  IFS='.' read -r -a labels <<<"$domain"
  IFS="$old_ifs"
  for label in "${labels[@]}"; do
    [[ ${#label} -ge 1 && ${#label} -le 63 ]] || return 1
    [[ "$label" =~ ^[a-z0-9]([a-z0-9-]*[a-z0-9])?$ ]] || return 1
  done
}

validate_ipv4() {
  local address="$1"
  local octet
  local old_ifs="$IFS"
  local -a octets=()

  [[ "$address" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]] || return 1
  IFS='.' read -r -a octets <<<"$address"
  IFS="$old_ifs"
  (( ${#octets[@]} == 4 )) || return 1
  for octet in "${octets[@]}"; do
    [[ "$octet" =~ ^(0|[1-9][0-9]{0,2})$ ]] || return 1
    (( 10#$octet <= 255 )) || return 1
  done
}

normalize_ipv6() {
  local address="$1"
  [[ "$address" == *:* && "$address" != *[^0-9A-Fa-f:.]* ]] || return 1
  getent ahostsv6 "$address" 2>/dev/null \
    | awk '$2 == "STREAM" { print tolower($1); found=1; exit } END { if (!found) exit 1 }'
}

resolve_repository_path() {
  local path="$1"
  if [[ "$path" == /* ]]; then
    realpath -m -- "$path"
  else
    realpath -m -- "${REPOSITORY_ROOT}/${path#./}"
  fi
}

expand_public_references() {
  local value="$1"
  value="${value//\$\{PUBLIC_DOMAIN\}/$CFG_DOMAIN}"
  value="${value//\$\{PUBLIC_APP_URL\}/$CFG_APP_URL}"
  value="${value//\$\{PUBLIC_API_URL\}/$CFG_API_URL}"
  value="${value//\$\{PUBLIC_AUTH_URL\}/$CFG_AUTH_URL}"
  printf '%s' "$value"
}

validate_boolean() {
  [[ "$1" == true || "$1" == false ]]
}

validate_outbound_reconciliation_flags() {
  local reconciliation_enabled="$1"
  local terminal_gap_enabled="$2"

  validate_boolean "$reconciliation_enabled" || return 1
  validate_boolean "$terminal_gap_enabled" || return 1
  [[ "$terminal_gap_enabled" == false || "$reconciliation_enabled" == true ]]
}

validate_outbound_attempt_hmac_references() {
  local active_key_id="$1"
  local keyring_file="$2"

  [[ "$active_key_id" =~ ^[A-Za-z0-9._-]{1,64}$ ]] || return 1
  [[ "$active_key_id" != CHANGE_ME && "$active_key_id" != __GENERATE__ ]] || return 1
  [[ "$keyring_file" == "$OUTBOUND_ATTEMPT_HMAC_KEYRING_TARGET" ]]
}

validate_outbound_attempt_hmac_approval_directory() {
  local approval_directory="$1"
  local approval_parent approval_mode approval_owner

  approval_parent="$(dirname -- "$approval_directory")"
  [[ ! -L "$approval_parent" && -d "$approval_parent" ]] || return 1
  [[ ! -L "$approval_directory" && -d "$approval_directory" ]] || return 1
  approval_mode="$(stat -c '%a' -- "$approval_directory" 2>/dev/null)" || return 1
  approval_owner="$(stat -c '%u' -- "$approval_directory" 2>/dev/null)" || return 1
  [[ "$approval_mode" == 700 && "$approval_owner" == "$(id -u)" ]]
}

prepare_outbound_attempt_hmac_approval_directory() {
  local deployment_root approval_directory approval_parent

  [[ "$OUTBOUND_ATTEMPT_HMAC_APPROVAL_SOURCE_RELATIVE" == "./.deploy/approvals/outbound-hmac" ]] \
    || die "Outbound-attempt HMAC approval directory must use its fixed repository-relative path"
  deployment_root="${REPOSITORY_ROOT}/.deploy"
  approval_directory="${REPOSITORY_ROOT}/.deploy/approvals/outbound-hmac"
  approval_parent="$(dirname -- "$approval_directory")"
  [[ ! -L "$deployment_root" \
      && ! -L "$approval_parent" \
      && ! -L "$approval_directory" ]] \
    || die "Outbound-attempt HMAC approval directories must not be symbolic links"
  install -d -m 700 -- "$deployment_root" "$approval_parent" "$approval_directory"
  validate_outbound_attempt_hmac_approval_directory "$approval_directory" \
    || die "Outbound-attempt HMAC approval directory must be owner-only (0700) and owned by the deploy user"
}

validate_outbound_attempt_hmac_keyring_file() {
  local keyring_path="$1"
  local active_key_id="$2"
  local parent_dir parent_mode parent_owner file_mode file_owner file_size encoded_key decoded_size
  local current_index previous_index
  local -a encoded_keys=()

  parent_dir="$(dirname -- "$keyring_path")"
  [[ ! -L "$parent_dir" && -d "$parent_dir" && -x "$parent_dir" ]] || return 1
  parent_mode="$(stat -c '%a' -- "$parent_dir" 2>/dev/null)" || return 1
  parent_owner="$(stat -c '%u' -- "$parent_dir" 2>/dev/null)" || return 1
  [[ "$parent_mode" == 700 && "$parent_owner" == "$(id -u)" ]] || return 1

  [[ ! -L "$keyring_path" && -f "$keyring_path" && -r "$keyring_path" ]] || return 1
  file_mode="$(stat -c '%a' -- "$keyring_path" 2>/dev/null)" || return 1
  file_owner="$(stat -c '%u' -- "$keyring_path" 2>/dev/null)" || return 1
  file_size="$(stat -c '%s' -- "$keyring_path" 2>/dev/null)" || return 1
  [[ ( "$file_mode" == 400 || "$file_mode" == 600 ) \
      && "$file_owner" == "$(id -u)" \
      && "$file_size" =~ ^[1-9][0-9]*$ \
      && 10#$file_size -le 16384 ]] || return 1

  jq -e --arg active "$active_key_id" '
    type == "object"
    and keys == ["keys"]
    and (.keys | type == "object")
    and ((.keys | length) >= 1 and (.keys | length) <= 32)
    and ([.keys | to_entries[]
          | select(((.key | test("^[A-Za-z0-9._-]{1,64}$")) | not)
                   or ((.value | type) != "string"))] | length == 0)
    and (.keys | has($active))
  ' "$keyring_path" >/dev/null 2>&1 || return 1

  mapfile -t encoded_keys < <(jq -er '.keys | to_entries[].value' "$keyring_path" 2>/dev/null)
  (( ${#encoded_keys[@]} >= 1 && ${#encoded_keys[@]} <= 32 )) || return 1
  for encoded_key in "${encoded_keys[@]}"; do
    decoded_size="$(printf '%s' "$encoded_key" \
      | base64 --decode 2>/dev/null \
      | wc -c \
      | tr -d ' ')" || return 1
    [[ "$decoded_size" == 32 ]] || return 1
  done
  for (( current_index=0; current_index<${#encoded_keys[@]}; current_index++ )); do
    for (( previous_index=0; previous_index<current_index; previous_index++ )); do
      if cmp -s \
        <(printf '%s' "${encoded_keys[$current_index]}" | base64 --decode 2>/dev/null) \
        <(printf '%s' "${encoded_keys[$previous_index]}" | base64 --decode 2>/dev/null); then
        return 1
      fi
    done
  done
}

validate_outbound_attempt_hmac_effective_compose() {
  local config_json="$1"
  local source_path="$2"
  local target_path="$3"
  local volume_name="$4"
  local approval_source_path="$5"
  local source_mount_target="$6"
  local source_parent="$7"

  jq -e \
    --arg source "$source_path" \
    --arg target "$target_path" \
    --arg volume "$volume_name" \
    --arg approval_source "$approval_source_path" \
    --arg source_mount_target "$source_mount_target" \
    --arg source_parent "$source_parent" '
      (.services.backend.volumes
        | any(.type == "volume"
              and .source == $volume
              and .target == "/run/saas-secrets"
              and .read_only == true))
      and .services.backend.depends_on["outbound-attempt-keyring-init"].condition
          == "service_completed_successfully"
      and .services.backend.depends_on["outbound-attempt-keyring-init"].required == true
      and .services.backend.environment.CONVERSATION_OUTBOUND_ATTEMPT_HMAC_KEYRING_FILE
          == $target
      and (.volumes | has($volume))
      and .services["outbound-attempt-keyring-init"].image == .services.backend.image
      and .services["outbound-attempt-keyring-init"].user == "root"
      and .services["outbound-attempt-keyring-init"].entrypoint
          == ["/opt/saas/bin/outbound-hmac-keyring-lifecycle.sh"]
      and (.services["outbound-attempt-keyring-init"].command // null) == null
      and .services["outbound-attempt-keyring-init"].environment == {
          "OUTBOUND_HMAC_ACTIVE_KEY_ID": .services.backend.environment.CONVERSATION_OUTBOUND_ATTEMPT_HMAC_ACTIVE_KEY_ID,
          "OUTBOUND_HMAC_APPROVAL_DIRECTORY": "/approval",
          "OUTBOUND_HMAC_APPROVAL_FILE": "/approval/outbound-hmac-key-removal.json",
          "OUTBOUND_HMAC_PENDING_FILE": "/target/.outbound-hmac-lifecycle-pending.json",
          "OUTBOUND_HMAC_SOURCE_FILE": "/source/conversation-outbound-attempt-hmac-keyring.json",
          "OUTBOUND_HMAC_SOURCE_PARENT": $source_parent,
          "OUTBOUND_HMAC_STATE_FILE": "/target/.outbound-hmac-lifecycle-state.json",
          "OUTBOUND_HMAC_TARGET_FILE": "/target/conversation-outbound-attempt-hmac-keyring.json",
          "OUTBOUND_HMAC_TARGET_OWNER": "spring:spring"
      }
      and .services["outbound-attempt-keyring-init"].network_mode == "none"
      and .services["outbound-attempt-keyring-init"].restart == "no"
      and .services["outbound-attempt-keyring-init"].read_only == true
      and (.services["outbound-attempt-keyring-init"].privileged // false) == false
      and .services["outbound-attempt-keyring-init"].pids_limit <= 32
      and ((.services["outbound-attempt-keyring-init"].networks // {}) | length) == 0
      and ((.services["outbound-attempt-keyring-init"].ports // []) | length) == 0
      and (.services["outbound-attempt-keyring-init"].tmpfs
        | index("/tmp:rw,noexec,nosuid,size=1m,mode=0700") != null)
      and (.services["outbound-attempt-keyring-init"].cap_drop | index("ALL") != null)
      and (.services["outbound-attempt-keyring-init"].cap_add | index("CHOWN") != null)
      and (.services["outbound-attempt-keyring-init"].cap_add | index("DAC_READ_SEARCH") != null)
      and (.services["outbound-attempt-keyring-init"].security_opt
        | index("no-new-privileges:true") != null)
      and (.services["outbound-attempt-keyring-init"].volumes | length) == 3
      and (.services["outbound-attempt-keyring-init"].volumes
        | any(.type == "bind"
              and .source == $source
              and .target == $source_mount_target
              and .read_only == true
              and .bind.create_host_path == false))
      and (.services["outbound-attempt-keyring-init"].volumes
        | any(.type == "bind"
              and .source == $approval_source
              and .target == "/approval"
              and .read_only == true
              and .bind.create_host_path == false))
      and (.services["outbound-attempt-keyring-init"].volumes
        | any(.type == "volume"
              and .source == $volume
              and .target == "/target"
              and (.read_only // false) == false))
      and $target == "/run/saas-secrets/conversation-outbound-attempt-hmac-keyring.json"
  ' <<<"$config_json" >/dev/null 2>&1
}

validate_positive_integer() {
  [[ "$1" =~ ^[1-9][0-9]*$ ]]
}

validate_positive_spring_duration() {
  [[ "$1" =~ ^[1-9][0-9]*(ms|s|m)$ ]]
}

spring_duration_to_millis() {
  local value="$1"
  local number multiplier

  validate_positive_spring_duration "$value" || return 1
  if [[ "$value" == *ms ]]; then
    number="${value%ms}"
    multiplier=1
  elif [[ "$value" == *s ]]; then
    number="${value%s}"
    multiplier=1000
  else
    number="${value%m}"
    multiplier=60000
  fi
  (( ${#number} <= 12 )) || return 1
  printf '%s\n' "$((10#$number * multiplier))"
}

validate_outbound_dispatch_bound() {
  local dispatch_lease="$1"
  local safety_margin="$2"
  local telegram_connect="$3"
  local telegram_read="$4"
  local whatsapp_connect="$5"
  local whatsapp_read="$6"
  local telegram_rate_limiter_wait="${7:-2s}"
  local lease_ms margin_ms telegram_ms whatsapp_ms maximum_provider_ms

  lease_ms="$(spring_duration_to_millis "$dispatch_lease")" || return 1
  margin_ms="$(spring_duration_to_millis "$safety_margin")" || return 1
  telegram_ms="$((
    $(spring_duration_to_millis "$telegram_rate_limiter_wait")
    + $(spring_duration_to_millis "$telegram_connect")
    + $(spring_duration_to_millis "$telegram_read")
  ))" || return 1
  whatsapp_ms="$((2 * (
    $(spring_duration_to_millis "$whatsapp_connect")
    + $(spring_duration_to_millis "$whatsapp_read")
  )))" || return 1

  (( lease_ms >= 60000 && lease_ms <= 1800000 )) || return 1
  (( margin_ms >= 1000 && margin_ms <= 300000 )) || return 1
  maximum_provider_ms="$telegram_ms"
  (( whatsapp_ms <= maximum_provider_ms )) || maximum_provider_ms="$whatsapp_ms"
  (( lease_ms > maximum_provider_ms + margin_ms ))
}

integer_greater_or_equal() {
  local candidate="$1"
  local minimum="$2"

  if (( ${#candidate} != ${#minimum} )); then
    (( ${#candidate} > ${#minimum} ))
    return
  fi
  [[ "$candidate" == "$minimum" || "$candidate" > "$minimum" ]]
}

validate_aes_key() {
  local name="$1"
  local value="$2"
  local decoded_size

  if [[ "$value" == base64:* ]]; then
    decoded_size="$(printf '%s' "${value#base64:}" | base64 --decode 2>/dev/null | wc -c | tr -d ' ')" \
      || die "$name is not valid Base64"
  else
    decoded_size="$(LC_ALL=C printf '%s' "$value" | wc -c | tr -d ' ')"
  fi
  [[ "$decoded_size" == 32 ]] \
    || die "$name must contain exactly 32 bytes (base64:<bytes> is recommended)"
}

validate_keycloak_realm_smtp_production() {
  local key value

  [[ "$(env_value KEYCLOAK_REALM_SMTP_MODE)" == prd ]] \
    || die "KEYCLOAK_REALM_SMTP_MODE must be prd in production"
  value="$(env_value KEYCLOAK_REALM_SMTP_HOST)"
  [[ "$value" =~ ^[A-Za-z0-9]([A-Za-z0-9.-]{0,251}[A-Za-z0-9])?$ \
      && "$value" != *..* ]] \
    || die "KEYCLOAK_REALM_SMTP_HOST is invalid"
  case "${value,,}" in
    mailpit|localhost|127.0.0.1|*.local)
      die "Production Keycloak realm SMTP must use an external provider"
      ;;
  esac
  value="$(env_value KEYCLOAK_REALM_SMTP_PORT)"
  [[ "$value" =~ ^[1-9][0-9]{0,4}$ ]] && (( value >= 1 && value <= 65535 )) \
    || die "KEYCLOAK_REALM_SMTP_PORT is outside the supported range"
  [[ "$(env_value KEYCLOAK_REALM_SMTP_AUTH)" == true ]] \
    || die "Production Keycloak realm SMTP must enable authentication"
  validate_boolean "$(env_value KEYCLOAK_REALM_SMTP_STARTTLS)" \
    || die "KEYCLOAK_REALM_SMTP_STARTTLS must be true or false"
  validate_boolean "$(env_value KEYCLOAK_REALM_SMTP_SSL)" \
    || die "KEYCLOAK_REALM_SMTP_SSL must be true or false"
  [[ "$(env_value KEYCLOAK_REALM_SMTP_STARTTLS)" != "$(env_value KEYCLOAK_REALM_SMTP_SSL)" ]] \
    || die "Production Keycloak realm SMTP requires exactly one TLS mode"
  for key in KEYCLOAK_REALM_SMTP_FROM KEYCLOAK_REALM_SMTP_REPLY_TO; do
    value="$(env_value "$key")"
    [[ "$value" =~ ^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,63}$ ]] \
      || die "$key is not a supported email address"
  done
  for key in KEYCLOAK_REALM_SMTP_FROM_DISPLAY_NAME KEYCLOAK_REALM_SMTP_REPLY_TO_DISPLAY_NAME; do
    value="$(env_value "$key")"
    [[ ${#value} -le 160 && "$value" =~ ^[A-Za-z0-9._\ @()+-]+$ ]] \
      || die "$key contains unsupported characters"
  done
  value="$(env_value KEYCLOAK_REALM_SMTP_USER)"
  [[ "$value" =~ ^[A-Za-z0-9._@+:/=-]{1,256}$ ]] \
    || die "KEYCLOAK_REALM_SMTP_USER contains unsupported characters"
  value="$(env_value TF_VAR_contadorfiscal_smtp_password)"
  [[ ${#value} -ge 16 && ${#value} -le 256 \
      && "$value" =~ ^[A-Za-z0-9._~:/+=-]+$ ]] \
    || die "TF_VAR_contadorfiscal_smtp_password must be a 16-256 character transport-safe secret"
}

validate_billing_mfa_production() {
  [[ "${1:-}" == true ]] \
    || die "BILLING_SECURITY_SUPER_ADMIN_MFA_ENABLED must remain true in production"
  [[ "${2:-}" == true ]] \
    || die "BILLING_SECURITY_ADMIN_CONTRACT_CONTEXT_MFA_ENABLED must remain true in production"
}
