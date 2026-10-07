configure_compose_command() {
  COMPOSE=(
    docker compose
    --project-name "$CFG_PROJECT_NAME"
    --project-directory "$REPOSITORY_ROOT"
    --env-file "$ENV_FILE"
    --file "$BASE_COMPOSE_FILE"
    --file "$PRODUCTION_COMPOSE_FILE"
  )
  if [[ "$CFG_WITH_MONITORING" == true ]]; then
    COMPOSE+=(--profile monitoring)
  fi
}

use_frozen_compose_model() {
  local compose_file="$1"

  [[ ! -L "$compose_file" && -f "$compose_file" ]] \
    || die "Frozen Compose model is unavailable"
  [[ "$(stat -c '%a' -- "$compose_file")" == 400 ]] \
    || die "Frozen Compose model must use mode 0400"
  COMPOSE=(
    docker compose
    --project-name "$CFG_PROJECT_NAME"
    --project-directory "$REPOSITORY_ROOT"
    --file "$compose_file"
  )
  if [[ "$CFG_WITH_MONITORING" == true ]]; then
    COMPOSE+=(--profile monitoring)
  fi
}

render_effective_compose_snapshot() {
  local temporary
  local backend_context="${WORK_DIR}/build-context/backend"
  local frontend_context="${WORK_DIR}/build-context/frontend"

  [[ -n "$WORK_DIR" && -d "$WORK_DIR" ]] \
    || die "The private deployment workspace is unavailable"
  EFFECTIVE_COMPOSE_FILE="${WORK_DIR}/compose.effective.json"
  temporary="$(mktemp "${EFFECTIVE_COMPOSE_FILE}.tmp.XXXXXX")"
  if ! BACKEND_BUILD_CONTEXT="$backend_context" \
      FRONTEND_BUILD_CONTEXT="$frontend_context" \
      "${COMPOSE[@]}" config --format json >"$temporary"; then
    rm -f -- "$temporary"
    die "Cannot render the frozen effective Compose model"
  fi
  jq -e '.services | type == "object"' "$temporary" >/dev/null \
    || die "Rendered effective Compose model is invalid"
  chmod 400 -- "$temporary"
  mv -f -- "$temporary" "$EFFECTIVE_COMPOSE_FILE"
  validate_effective_compose_config "$EFFECTIVE_COMPOSE_FILE"
  use_frozen_compose_model "$EFFECTIVE_COMPOSE_FILE"
}

render_production_assets() {
  local source temporary
  mkdir -p -- "$(dirname "$CFG_NGINX_CONFIG")"
  source="${REPOSITORY_ROOT}/infra/proxy/nginx.prd.conf"
  [[ -f "$source" ]] || die "NGINX production source not found: $source"
  temporary="$(mktemp "${CFG_NGINX_CONFIG}.tmp.XXXXXX")"
  sed -e "s/auth\.duoset\.com\.br/${CFG_AUTH_HOST}/g" \
      -e "s/auth\.agentefiscal\.com\.br/${CFG_AUTH_HOST}/g" \
      -e "s/contadorfiscal\.com\.br/${CFG_DOMAIN}/g" \
      -e "s/agentefiscal\.com\.br/${CFG_DOMAIN}/g" "$source" >"$temporary"
  chmod 644 "$temporary"
  mv -f -- "$temporary" "$CFG_NGINX_CONFIG"
}

validate_tls() {
  local certificate="${CFG_TLS_DIR}/fullchain.pem"
  local private_key="${CFG_TLS_DIR}/privkey.pem"
  local cert_hash key_hash key_mode key_mode_value host

  [[ -r "$certificate" ]] || die "TLS certificate is missing/unreadable: $certificate"
  [[ -r "$private_key" ]] || die "TLS private key is missing/unreadable: $private_key"
  openssl x509 -in "$certificate" -noout -checkend 86400 >/dev/null \
    || die "TLS certificate is invalid or expires in less than 24 hours"

  for host in "$CFG_APP_HOST" "$CFG_API_HOST" "$CFG_AUTH_HOST"; do
    openssl x509 -in "$certificate" -noout -checkhost "$host" >/dev/null \
      || die "TLS certificate does not cover $host"
  done

  cert_hash="$(openssl x509 -in "$certificate" -pubkey -noout \
    | openssl pkey -pubin -outform DER 2>/dev/null | sha256sum | awk '{print $1}')"
  key_hash="$(openssl pkey -in "$private_key" -pubout -outform DER 2>/dev/null \
    | sha256sum | awk '{print $1}')"
  [[ -n "$cert_hash" && "$cert_hash" == "$key_hash" ]] \
    || die "TLS private key does not match fullchain.pem"

  key_mode="$(stat -c '%a' "$private_key")"
  key_mode_value=$((8#$key_mode))
  (( (key_mode_value & 037) == 0 )) \
    || die "TLS private key must not be readable by other users (recommended mode 600 or 640)"
}

validate_dns() {
  local host name_server ipv4_records ipv6_records normalized
  local ipv6_record normalized_ipv6 host_zone
  local -a host_name_servers=()

  for host in "$CFG_APP_HOST" "$CFG_API_HOST" "$CFG_AUTH_HOST"; do
    host_zone="$CFG_DOMAIN"
    if [[ "$host" != *"$CFG_DOMAIN" ]]; then
      if [[ "$host" =~ \.([^.]+\.[^.]+\.[^.]+)$ ]] && [[ "$host" =~ \.(com|net|org|gov|edu|mil|ind|adv|app)\.[a-z]{2}$ ]]; then
        host_zone="${BASH_REMATCH[1]}"
      elif [[ "$host" =~ \.([^.]+\.[^.]+)$ ]]; then
        host_zone="${BASH_REMATCH[1]}"
      fi
    fi
    host_name_servers=()
    mapfile -t host_name_servers < <(
      dig +time=5 +tries=1 +short "$host_zone" NS \
        | sed 's/\.$//' | sed '/^$/d' | sort -u
    )
    (( ${#host_name_servers[@]} > 0 )) \
      || die "No authoritative name servers found for $host_zone"

    for name_server in "${host_name_servers[@]}"; do
      ipv4_records="$(
        dig +time=5 +tries=1 +short @"$name_server" "$host" A \
          | awk '/^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$/ { print }' | sort -u
      )" || die "Authoritative DNS query failed: $name_server / $host A"
      [[ "$ipv4_records" == "$CFG_VPS_PUBLIC_IPV4" ]] \
        || die "$host must have exactly one authoritative A record pointing to VPS_PUBLIC_IPV4 on $name_server"

      ipv6_records="$(
        dig +time=5 +tries=1 +short @"$name_server" "$host" AAAA \
          | awk '/^[0-9A-Fa-f:.]+$/ && /:/ { print }' | sort -u
      )" || die "Authoritative DNS query failed: $name_server / $host AAAA"
      normalized=""
      if [[ -n "$ipv6_records" ]]; then
        while IFS= read -r ipv6_record; do
          [[ -n "$ipv6_record" ]] || continue
          normalized_ipv6="$(normalize_ipv6 "$ipv6_record")" \
            || die "Authoritative DNS returned an invalid IPv6 address for $host"
          normalized+="${normalized_ipv6}"$'\n'
        done <<<"$ipv6_records"
        normalized="$(printf '%s' "$normalized" | sed '/^$/d' | sort -u)"
      fi
      if [[ -z "$CFG_VPS_PUBLIC_IPV6" && -n "$normalized" ]]; then
        die "$host publishes AAAA on $name_server but VPS_PUBLIC_IPV6 is empty"
      fi
      if [[ -n "$CFG_VPS_PUBLIC_IPV6" && "$normalized" != "$CFG_VPS_PUBLIC_IPV6" ]]; then
        die "$host must have exactly one authoritative AAAA record pointing to VPS_PUBLIC_IPV6 on $name_server"
      fi
    done
  done
}

validate_alert_webhook() {
  local webhook=""
  mkdir -p -- "$(dirname "$CFG_ALERT_WEBHOOK_FILE")"
  if [[ ! -e "$CFG_ALERT_WEBHOOK_FILE" ]]; then
    : >"$CFG_ALERT_WEBHOOK_FILE"
    chmod 600 "$CFG_ALERT_WEBHOOK_FILE"
  fi
  if [[ "$CFG_WITH_MONITORING" == true ]]; then
    webhook="$(tr -d '\r\n' <"$CFG_ALERT_WEBHOOK_FILE")"
    [[ "$webhook" == https://* ]] \
      || die "Monitoring requires an HTTPS URL in $CFG_ALERT_WEBHOOK_FILE"
  fi
}

validate_worktree() {
  local changes
  require_command git
  git -C "$REPOSITORY_ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1 \
    || die "Production must run from a verified Git checkout"
  git -C "$REPOSITORY_ROOT" rev-parse --verify 'HEAD^{commit}' >/dev/null 2>&1 \
    || die "Production Git checkout has no valid HEAD commit"
  changes="$(git -C "$REPOSITORY_ROOT" status --porcelain --untracked-files=normal)"
  if [[ -n "$changes" && "$CFG_ALLOW_DIRTY_WORKTREE" != true ]]; then
    printf '%s\n' "$changes" >&2
    die "Production deploy requires a clean Git worktree (or explicit ALLOW_DIRTY_WORKTREE=true)"
  fi
  [[ -z "$changes" ]] || warn "Deploying from a dirty Git worktree by explicit configuration"
}

docker_preflight() {
  local command_name
  for command_name in docker jq openssl sha256sum base64 awk sed grep sort comm cmp gzip tar flock curl dig getent stat find cut wc tr install realpath df id; do
    require_command "$command_name"
  done
  docker info >/dev/null 2>&1 \
    || die "Docker is unavailable. Run this script as a user allowed to access the Docker daemon."
  docker compose version >/dev/null 2>&1 || die "Docker Compose v2 is required"
  "${COMPOSE[@]}" config --quiet
  validate_effective_compose_config "${PINNED_COMPOSE_FILE:-$EFFECTIVE_COMPOSE_FILE}"
}

validate_telegram_backend_egress() {
  local backend_container
  backend_container="$(container_for_service backend)"
  [[ -n "$backend_container" ]] \
    || die "Backend container is absent; cannot validate Telegram API egress"
  container_is_running "$backend_container" \
    || die "Backend container is not running; cannot validate Telegram API egress"

  log "Validating token-free Telegram API HTTPS egress from the backend container"
  docker exec "$backend_container" wget -q --spider -T 20 "${TELEGRAM_API_ORIGIN}/" \
    >/dev/null 2>&1 \
    || die "Backend cannot resolve or establish trusted HTTPS connectivity to $TELEGRAM_API_HOST"
}

validate_telegram_egress_preflight() {
  local backend_container

  log "Validating token-free Telegram API DNS/TLS/HTTPS egress from the deployment host"
  getent ahosts "$TELEGRAM_API_HOST" >/dev/null 2>&1 \
    || die "Deployment host cannot resolve $TELEGRAM_API_HOST"
  curl --fail --silent --show-error \
    --connect-timeout 10 --max-time 20 \
    --noproxy '*' --proto '=https' --tlsv1.2 \
    --output /dev/null "${TELEGRAM_API_ORIGIN}/" \
    || die "Deployment host cannot establish trusted HTTPS connectivity to $TELEGRAM_API_HOST"

  backend_container="$(container_for_service backend)"
  if container_is_running "$backend_container"; then
    validate_telegram_backend_egress
  else
    log "Backend is not running yet; its Telegram API egress check is deferred until after rollout"
  fi
}

prepare_backup_directory() {
  local marker="${CFG_BACKUP_DIR}/.agentefiscal-production-backups"
  local expected_default owner mode mode_value temporary existing_entry

  [[ ! -L "$CFG_BACKUP_DIR" ]] || die "BACKUP_DIR must not be a symbolic link"
  if [[ ! -e "$CFG_BACKUP_DIR" ]]; then
    install -d -m 700 -- "$CFG_BACKUP_DIR"
  fi
  [[ -d "$CFG_BACKUP_DIR" ]] || die "BACKUP_DIR is not a directory: $CFG_BACKUP_DIR"

  owner="$(stat -c '%u' "$CFG_BACKUP_DIR")"
  [[ "$owner" == "$(id -u)" ]] \
    || die "BACKUP_DIR must be owned by the deployment user: $CFG_BACKUP_DIR"
  mode="$(stat -c '%a' "$CFG_BACKUP_DIR")"
  mode_value=$((8#$mode))
  (( (mode_value & 077) == 0 )) \
    || die "BACKUP_DIR must not be accessible by group/others (use mode 700)"

  if [[ ! -f "$marker" ]]; then
    expected_default="$(realpath -m -- "${REPOSITORY_ROOT}/.deploy/backups")"
    existing_entry="$(find "$CFG_BACKUP_DIR" -mindepth 1 -maxdepth 1 -print -quit)"
    if [[ -n "$existing_entry" && "$CFG_BACKUP_DIR" != "$expected_default" ]]; then
      die "BACKUP_DIR is non-empty and has no production marker; choose a dedicated empty directory"
    fi
    temporary="$(mktemp "${CFG_BACKUP_DIR}/.backup-marker.tmp.XXXXXX")"
    printf 'project=%s\ndomain=%s\n' "$CFG_PROJECT_NAME" "$CFG_DOMAIN" >"$temporary"
    chmod 600 "$temporary"
    mv -f -- "$temporary" "$marker"
  fi
  [[ "$(state_value "$marker" project)" == "$CFG_PROJECT_NAME" \
      && "$(state_value "$marker" domain)" == "$CFG_DOMAIN" ]] \
    || die "BACKUP_DIR belongs to another project/domain: $CFG_BACKUP_DIR"
}

initialize_invocation_workspace() {
  local lock_file

  install -d -m 700 -- \
    "${REPOSITORY_ROOT}/.deploy" \
    "$STATE_DIR"
  lock_file="${STATE_DIR}/deploy.lock"
  [[ ! -L "$lock_file" ]] || die "Production deployment lock must not be a symbolic link"
  exec 9>"$lock_file"
  chmod 600 -- "$lock_file"
  [[ "$(stat -c '%u:%a' -- "$lock_file")" == "$(id -u):600" ]] \
    || die "Production deployment lock must be owner-only and owned by the deploy user"
  flock -n 9 || die "Another production deployment/backup is already running"
  WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/agentefiscal-deploy.XXXXXXXX")"
  chmod 700 -- "$WORK_DIR"
}

initialize_runtime() {
  validate_outbound_attempt_hmac_approval_directory \
    "$(resolve_repository_path "$OUTBOUND_ATTEMPT_HMAC_APPROVAL_SOURCE_RELATIVE")" \
    || die "Outbound-attempt HMAC approval directory lost its owner-only boundary"
  prepare_backup_directory
}
