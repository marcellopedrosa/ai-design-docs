#!/usr/bin/env bash

# Production deployment for a single Linux VPS.
#
# Safety invariants cover a stable Compose project, non-destructive updates,
# pre-update PostgreSQL backups, Admin API realm reconciliation, immutable
# credentials and encryption keys, and immutable recorded Flyway migrations.

set -Eeuo pipefail
umask 077

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPOSITORY_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
DEFAULT_ENV_FILE="${REPOSITORY_ROOT}/.env.production"
ENV_TEMPLATE="${REPOSITORY_ROOT}/infra/deploy/production.env.example"
BASE_COMPOSE_FILE="${REPOSITORY_ROOT}/docker-compose.yml"
PRODUCTION_COMPOSE_FILE="${REPOSITORY_ROOT}/docker-compose.prd.yml"
OFFSITE_BACKUP_SCRIPT="${SCRIPT_DIR}/upload-production-backup.sh"
OFFSITE_BACKUP_CONFIG="${REPOSITORY_ROOT}/.deploy/secrets/offsite-backup.env"
TELEGRAM_API_HOST="api.telegram.org"
TELEGRAM_API_ORIGIN="https://${TELEGRAM_API_HOST}"
OUTBOUND_ATTEMPT_HMAC_KEYRING_SOURCE_RELATIVE="./.deploy/secrets/conversation-outbound-attempt-hmac-keyring.json"
OUTBOUND_ATTEMPT_HMAC_APPROVAL_SOURCE_RELATIVE="./.deploy/approvals/outbound-hmac"
OUTBOUND_ATTEMPT_HMAC_KEYRING_TARGET="/run/saas-secrets/conversation-outbound-attempt-hmac-keyring.json"

COMMAND=""
ENV_FILE="$DEFAULT_ENV_FILE"
REQUESTED_DOMAIN=""
CLI_WITH_MONITORING=""
ALLOW_DESTRUCTIVE_MIGRATIONS=false
RESUME_INITIALIZATION=false
UPLOAD_OFFSITE=false
ADOPT_LEGACY_BACKUP_MARKERS=false

CFG_PROJECT_NAME=""
CFG_DOMAIN=""
CFG_VPS_PUBLIC_IPV4=""
CFG_VPS_PUBLIC_IPV6=""
CFG_APP_HOST=""
CFG_API_HOST=""
CFG_AUTH_HOST=""
CFG_APP_URL=""
CFG_API_URL=""
CFG_AUTH_URL=""
CFG_DB_USER=""
CFG_KEYCLOAK_DB_USER=""
CFG_PROVISIONING_CLIENT_ID=""
CFG_MANAGED_REALMS=""
CFG_BUILD_LOCAL=""
CFG_WITH_MONITORING=""
CFG_WAIT_TIMEOUT=""
CFG_BACKUP_DIR=""
CFG_BACKUP_MIN_FREE_MB=""
CFG_TLS_DIR=""
CFG_NGINX_CONFIG=""
CFG_ALERT_WEBHOOK_FILE=""
CFG_ALLOW_DIRTY_WORKTREE=""
CFG_OUTBOUND_ATTEMPT_HMAC_KEYRING_SOURCE=""

readonly -a DEPLOY_PRODUCTION_PROTECTED_COMPOSE_MAPPINGS=(
  "keycloak-provisioning-init|KEYCLOAK_ADMIN_LOGIN_MFA_ENABLED|KEYCLOAK_ADMIN_LOGIN_MFA_ENABLED"
  "keycloak-provisioning-init|KEYCLOAK_TENANT_FIRST_LOGIN_MFA_ENABLED|KEYCLOAK_TENANT_FIRST_LOGIN_MFA_ENABLED"
  "backend|CONVERSATION_OUTBOUND_ATTEMPT_HMAC_ACTIVE_KEY_ID|CONVERSATION_OUTBOUND_ATTEMPT_HMAC_ACTIVE_KEY_ID"
  "backend|CONVERSATION_OUTBOUND_ATTEMPT_HMAC_KEYRING_FILE|CONVERSATION_OUTBOUND_ATTEMPT_HMAC_KEYRING_FILE"
  "outbound-attempt-keyring-init|OUTBOUND_HMAC_ACTIVE_KEY_ID|CONVERSATION_OUTBOUND_ATTEMPT_HMAC_ACTIVE_KEY_ID"
  "backend|WEBSITE_CONTACT_TOKEN|CONTACT_WEBHOOK_TOKEN"
  "backend|BILLING_SECURITY_SUPER_ADMIN_MFA_ENABLED|BILLING_SECURITY_SUPER_ADMIN_MFA_ENABLED"
  "backend|BILLING_SECURITY_ADMIN_CONTRACT_CONTEXT_MFA_ENABLED|BILLING_SECURITY_ADMIN_CONTRACT_CONTEXT_MFA_ENABLED"
)

STATE_DIR="${REPOSITORY_ROOT}/.deploy/state"
MARKER_FILE="${STATE_DIR}/installed.env"
VOLUME_STATE_FILE="${STATE_DIR}/volumes.env"
FINGERPRINT_FILE="${STATE_DIR}/immutable.sha256"
MIGRATION_MANIFEST_FILE="${STATE_DIR}/migrations.sha256"
MIGRATION_MANIFEST_DIGEST_FILE="${STATE_DIR}/migrations.manifest.sha256"
KEYCLOAK_BOOTSTRAP_MANIFEST_FILE="${STATE_DIR}/keycloak-bootstrap.sha256"
STATEFUL_SERVICES_FILE="${STATE_DIR}/stateful-services.env"
LAST_BACKUP_STATE_FILE="${STATE_DIR}/last-backup.env"
WORK_DIR=""
ENV_SOURCE_FILE=""
BASE_COMPOSE_SOURCE_FILE="$BASE_COMPOSE_FILE"
PRODUCTION_COMPOSE_SOURCE_FILE="$PRODUCTION_COMPOSE_FILE"
ENV_SNAPSHOT_FILE=""
BASE_COMPOSE_SNAPSHOT_FILE=""
PRODUCTION_COMPOSE_SNAPSHOT_FILE=""
EFFECTIVE_COMPOSE_FILE=""
PINNED_COMPOSE_FILE=""
PINNED_BACKEND_IMAGE_ID=""
LAST_BACKUP_DIR=""
BACKUP_CATALOG_COMPLETE=true
WRITERS_STOPPED=false
ROLLOUT_STARTED=false
OUTBOUND_KEYRING_ACTIVATED=false
ORIGINAL_BACKEND_CONTAINER=""
ORIGINAL_KEYCLOAK_CONTAINER=""
DEPLOY_STARTED_AT=""

declare -a COMPOSE=()
declare -ar IMMUTABLE_KEYS=(
  PUBLIC_DOMAIN DB_USER DB_PASSWORD KEYCLOAK_DB_USER KEYCLOAK_DB_PASSWORD REDIS_PASSWORD
  KEYCLOAK_ADMIN_USER KEYCLOAK_ADMIN_PASSWORD
  KEYCLOAK_PROVISIONING_CLIENT_ID KEYCLOAK_PROVISIONING_CLIENT_SECRET
  APP_SECURITY_ENCRYPTION_SECRET_KEY APP_SECURITY_ENCRYPTION_KEY
  APP_SECURITY_DATA_ENCRYPTION_KEY APP_CRYPTO_SECRET
  SAAS_CERTIFICATE_ENCRYPTION_KEY SAAS_TENANT_ENCRYPTION_KEY WHATSAPP_ENCRYPTION_KEY
  APP_CRYPTO_LEGACY_SECRET APP_SECURITY_ENCRYPTION_LEGACY_SECRET_KEY
  APP_SECURITY_ENCRYPTION_LEGACY_KEY SAAS_CERTIFICATE_LEGACY_ENCRYPTION_KEY
  SAAS_TENANT_LEGACY_ENCRYPTION_KEY WHATSAPP_LEGACY_ENCRYPTION_KEY
)

log() {
  printf '[deploy] %s\n' "$*"
}

warn() {
  printf '[deploy] WARNING: %s\n' "$*" >&2
}

die() {
  printf '[deploy] ERROR: %s\n' "$*" >&2
  exit 1
}

usage() {
  cat <<'EOF'
Usage:
  deploy-production.sh init [options]
  deploy-production.sh update [options]
  deploy-production.sh backup [options]
  deploy-production.sh status [options]

Commands:
  init      Create .env.production when absent and perform/resume first deploy.
  update    Back up both PostgreSQL clusters, verify the encrypted off-site copy,
            and apply an incremental release.
  backup    Create a consistent logical backup without deploying a release.
  status    Validate containers, volumes, databases, Flyway and public HTTPS.

Options:
  --env-file FILE                  Production env file (default: .env.production).
  --domain DOMAIN                  Base domain, for example contadorfiscal.com.br.
  --with-monitoring                Start/validate the monitoring profile.
  --allow-destructive-migrations   Explicitly approve a new migration containing
                                   DROP TABLE/COLUMN, TRUNCATE or DELETE FROM.
  --resume                         Resume a failed init that already made volumes.
  --upload-offsite                 With backup, encrypt/upload the completed artifact
                                   using .deploy/secrets/offsite-backup.env.
  --adopt-legacy-markers           With backup --upload-offsite, perform only the
                                   lock-serialized legacy-marker adoption scan.
  -h, --help                       Show this help.

Examples:
  ./infra/scripts/deploy-production.sh init --domain contadorfiscal.com.br
  ./infra/scripts/deploy-production.sh update

The first init creates .env.production once and stops so external provider
credentials and TLS files can be supplied. Run the same init command again.
EOF
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || die "Required command not found: $1"
}

parse_arguments() {
  if (( $# == 0 )); then
    usage
    exit 2
  fi

  COMMAND="$1"
  shift
  case "$COMMAND" in
    init|update|backup|status) ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      usage >&2
      die "Unknown command: $COMMAND"
      ;;
  esac

  while (( $# > 0 )); do
    case "$1" in
      --env-file)
        (( $# >= 2 )) || die "--env-file requires a path"
        ENV_FILE="$2"
        shift 2
        ;;
      --domain)
        (( $# >= 2 )) || die "--domain requires a base domain"
        REQUESTED_DOMAIN="${2,,}"
        shift 2
        ;;
      --with-monitoring)
        CLI_WITH_MONITORING=true
        shift
        ;;
      --allow-destructive-migrations)
        ALLOW_DESTRUCTIVE_MIGRATIONS=true
        shift
        ;;
      --resume)
        RESUME_INITIALIZATION=true
        shift
        ;;
      --upload-offsite)
        UPLOAD_OFFSITE=true
        shift
        ;;
      --adopt-legacy-markers)
        ADOPT_LEGACY_BACKUP_MARKERS=true
        shift
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        die "Unknown option: $1"
        ;;
    esac
  done

  if [[ "$ENV_FILE" != /* ]]; then
    ENV_FILE="${PWD}/${ENV_FILE#./}"
  fi
  if [[ "$UPLOAD_OFFSITE" == true && "$COMMAND" != backup ]]; then
    die "--upload-offsite is valid only with the backup command"
  fi
  if [[ "$ADOPT_LEGACY_BACKUP_MARKERS" == true \
      && ( "$COMMAND" != backup || "$UPLOAD_OFFSITE" != true ) ]]; then
    die "--adopt-legacy-markers requires backup --upload-offsite"
  fi
}

# Test seam used only by the sourced shell regression. The executable script
# always defines this no-op itself, so callers cannot inject a hook through the
# environment.
snapshot_acquisition_test_hook() {
  :
}

capture_stable_file_snapshot() {
  local source="$1"
  local destination="$2"
  local confidential_source="$3"
  local label="$4"
  local source_fd=""
  local shell_pid="$BASHPID"
  local path_before descriptor_before path_after descriptor_after
  local digest_before digest_after snapshot_digest
  local mode mode_value owner temporary

  [[ "$confidential_source" == true || "$confidential_source" == false ]] \
    || die "Invalid internal confidentiality policy for $label"
  [[ ! -L "$source" && -f "$source" ]] \
    || die "$label source must be a regular non-symlink file"
  owner="$(stat -Lc '%u' -- "$source")" \
    || die "Cannot inspect $label source ownership"
  [[ "$owner" == "$(id -u)" ]] \
    || die "$label source must be owned by the deployment user"
  if [[ "$confidential_source" == true ]]; then
    mode="$(stat -Lc '%a' -- "$source")" \
      || die "Cannot inspect $label source permissions"
    mode_value=$((8#$mode))
    (( (mode_value & 077) == 0 )) \
      || die "$label source must not be accessible by group/others"
  fi

  exec {source_fd}<"$source" \
    || die "Cannot open $label source for a stable snapshot"
  path_before="$(stat -Lc '%d:%i:%f:%u:%g:%s:%Y:%Z' -- "$source")" \
    || die "Cannot inspect $label source before snapshot"
  descriptor_before="$(stat -Lc '%d:%i:%f:%u:%g:%s:%Y:%Z' -- "/proc/${shell_pid}/fd/${source_fd}")" \
    || die "Cannot inspect the opened $label descriptor"
  [[ "$path_before" == "$descriptor_before" ]] \
    || die "$label source changed while its descriptor was acquired"
  digest_before="$(sha256sum -- "/proc/${shell_pid}/fd/${source_fd}" | awk '{print $1}')" \
    || die "Cannot fingerprint the opened $label source"

  snapshot_acquisition_test_hook "$label" "$source"
  temporary="$(mktemp "${destination}.tmp.XXXXXX")"
  if ! install -m 400 -- "/proc/${shell_pid}/fd/${source_fd}" "$temporary"; then
    rm -f -- "$temporary"
    die "Cannot capture the $label snapshot"
  fi

  descriptor_after="$(stat -Lc '%d:%i:%f:%u:%g:%s:%Y:%Z' -- "/proc/${shell_pid}/fd/${source_fd}")" \
    || die "Cannot re-inspect the opened $label descriptor"
  path_after="$(stat -Lc '%d:%i:%f:%u:%g:%s:%Y:%Z' -- "$source" 2>/dev/null || true)"
  digest_after="$(sha256sum -- "/proc/${shell_pid}/fd/${source_fd}" | awk '{print $1}')" \
    || die "Cannot re-fingerprint the opened $label source"
  snapshot_digest="$(sha256sum -- "$temporary" | awk '{print $1}')" \
    || die "Cannot fingerprint the captured $label snapshot"
  exec {source_fd}<&-

  if [[ -L "$source" \
      || "$path_before" != "$path_after" \
      || "$descriptor_before" != "$descriptor_after" \
      || "$digest_before" != "$digest_after" \
      || "$digest_before" != "$snapshot_digest" ]]; then
    rm -f -- "$temporary"
    die "$label source changed while its snapshot was being acquired"
  fi
  mv -f -- "$temporary" "$destination"
  chmod 400 -- "$destination"
}

capture_deployment_inputs() {
  [[ -n "$WORK_DIR" && -d "$WORK_DIR" ]] \
    || die "The private deployment workspace must exist before input capture"
  [[ "$(stat -c '%a' -- "$WORK_DIR")" == 700 ]] \
    || die "The private deployment workspace must use mode 0700"

  ENV_SOURCE_FILE="$ENV_FILE"
  BASE_COMPOSE_SOURCE_FILE="$BASE_COMPOSE_FILE"
  PRODUCTION_COMPOSE_SOURCE_FILE="$PRODUCTION_COMPOSE_FILE"
  ENV_SNAPSHOT_FILE="${WORK_DIR}/production.env.snapshot"
  BASE_COMPOSE_SNAPSHOT_FILE="${WORK_DIR}/docker-compose.base.snapshot.yaml"
  PRODUCTION_COMPOSE_SNAPSHOT_FILE="${WORK_DIR}/docker-compose.production.snapshot.yaml"

  capture_stable_file_snapshot \
    "$ENV_SOURCE_FILE" "$ENV_SNAPSHOT_FILE" true "production environment"
  capture_stable_file_snapshot \
    "$BASE_COMPOSE_SOURCE_FILE" "$BASE_COMPOSE_SNAPSHOT_FILE" false "base Compose"
  capture_stable_file_snapshot \
    "$PRODUCTION_COMPOSE_SOURCE_FILE" "$PRODUCTION_COMPOSE_SNAPSHOT_FILE" false "production Compose"

  # From this point on no parser or Compose command receives a live source path.
  ENV_FILE="$ENV_SNAPSHOT_FILE"
  BASE_COMPOSE_FILE="$BASE_COMPOSE_SNAPSHOT_FILE"
  PRODUCTION_COMPOSE_FILE="$PRODUCTION_COMPOSE_SNAPSHOT_FILE"
}

env_value() {
  local key="$1"
  local fallback="${2:-}"
  local value

  value="$(awk -v wanted="$key" '
    {
      sub(/\r$/, "")
    }
    $0 ~ "^[[:space:]]*" wanted "[[:space:]]*=" {
      line = $0
      sub("^[[:space:]]*" wanted "[[:space:]]*=[[:space:]]*", "", line)
      sub(/[[:space:]]+$/, "", line)
      if ((substr(line, 1, 1) == "\"" && substr(line, length(line), 1) == "\"") ||
          (substr(line, 1, 1) == "\047" && substr(line, length(line), 1) == "\047")) {
        line = substr(line, 2, length(line) - 2)
      }
      print line
      found = 1
      exit
    }
    END {
      if (!found) exit 1
    }
  ' "$ENV_FILE" 2>/dev/null)" || value="$fallback"
  printf '%s' "$value"
}

set_env_value() {
  local file="$1"
  local key="$2"
  local value="$3"
  local temporary
  temporary="$(mktemp "${file}.tmp.XXXXXX")"

  if ! awk -v wanted="$key" -v replacement="$value" '
    BEGIN { replaced = 0 }
    $0 ~ "^[[:space:]]*" wanted "[[:space:]]*=" {
      print wanted "=" replacement
      replaced = 1
      next
    }
    { print }
    END {
      if (!replaced) print wanted "=" replacement
    }
  ' "$file" >"$temporary"; then
    rm -f -- "$temporary"
    return 1
  fi
  if ! chmod 600 "$temporary" || ! mv -f -- "$temporary" "$file"; then
    rm -f -- "$temporary"
    return 1
  fi
}

random_hex() {
  openssl rand -hex 32
}

random_aes256() {
  printf 'base64:'
  openssl rand -base64 32 | tr -d '\n'
}

create_environment_file() {
  local domain="$REQUESTED_DOMAIN"
  local key temporary_env
  local -a random_keys=(
    DB_PASSWORD
    KEYCLOAK_DB_PASSWORD
    REDIS_PASSWORD
    KEYCLOAK_ADMIN_PASSWORD
    KEYCLOAK_PROVISIONING_CLIENT_SECRET
    AUTH_SESSION_SECRET
    GRAFANA_ADMIN_PASSWORD
    WHATSAPP_WEBHOOK_VERIFY_TOKEN
    CONTACT_WEBHOOK_TOKEN
  )
  local -a aes_keys=(
    APP_SECURITY_ENCRYPTION_SECRET_KEY
    APP_SECURITY_ENCRYPTION_KEY
    APP_SECURITY_DATA_ENCRYPTION_KEY
    APP_CRYPTO_SECRET
    SAAS_CERTIFICATE_ENCRYPTION_KEY
    SAAS_TENANT_ENCRYPTION_KEY
    WHATSAPP_ENCRYPTION_KEY
    APP_CRYPTO_LEGACY_SECRET
    APP_SECURITY_ENCRYPTION_LEGACY_SECRET_KEY
    APP_SECURITY_ENCRYPTION_LEGACY_KEY
    SAAS_CERTIFICATE_LEGACY_ENCRYPTION_KEY
    SAAS_TENANT_LEGACY_ENCRYPTION_KEY
    WHATSAPP_LEGACY_ENCRYPTION_KEY
  )

  for key in openssl awk mktemp install ln mv chmod tr; do
    require_command "$key"
  done
  [[ -n "$domain" ]] || die "The first init requires --domain with the final public .com.br domain"
  validate_domain "$domain" || die "Invalid production domain: $domain"
  [[ -f "$ENV_TEMPLATE" ]] || die "Environment template not found: $ENV_TEMPLATE"
  [[ ! -e "$ENV_FILE" ]] || die "Refusing to overwrite existing environment file: $ENV_FILE"
  mkdir -p -- "$(dirname "$ENV_FILE")" "${REPOSITORY_ROOT}/.deploy/secrets"
  chmod 700 "${REPOSITORY_ROOT}/.deploy" "${REPOSITORY_ROOT}/.deploy/secrets"
  (
    temporary_env="$(mktemp "$(dirname "$ENV_FILE")/.production-env.tmp.XXXXXX")"
    trap 'rm -f -- "$temporary_env"' EXIT INT TERM
    install -m 600 "$ENV_TEMPLATE" "$temporary_env"
    set_env_value "$temporary_env" PUBLIC_DOMAIN "$domain"
    set_env_value "$temporary_env" KEYCLOAK_REALM_SMTP_FROM "no-reply@$domain"
    set_env_value "$temporary_env" KEYCLOAK_REALM_SMTP_REPLY_TO "suporte@$domain"

    for key in "${random_keys[@]}"; do
      set_env_value "$temporary_env" "$key" "$(random_hex)"
    done
    for key in "${aes_keys[@]}"; do
      set_env_value "$temporary_env" "$key" "$(random_aes256)"
    done

    ln "$temporary_env" "$ENV_FILE" 2>/dev/null \
      || die "Another process created $ENV_FILE; it was not overwritten"
  )
  if [[ ! -e "${REPOSITORY_ROOT}/.deploy/secrets/alert-webhook-url" ]]; then
    (set -o noclobber; : >"${REPOSITORY_ROOT}/.deploy/secrets/alert-webhook-url") 2>/dev/null || true
  fi
  chmod 600 "${REPOSITORY_ROOT}/.deploy/secrets/alert-webhook-url"

  log "Created $ENV_FILE with mode 0600."
  log "Generated database passwords and encryption keys exactly once."
  warn "Replace every CHANGE_ME value and install TLS fullchain.pem/privkey.pem."
  warn "Provision the owner-only outbound-attempt HMAC keyring before continuing; the deploy never generates or logs it."
  log "Then run the same init command again; this file will not be overwritten."
}

DEPLOY_PRODUCTION_LIB_DIR="${SCRIPT_DIR}/lib/deploy-production"
for deploy_production_module in \
  environment.sh \
  environment-validation.sh \
  compose.sh \
  state.sh \
  backup.sh \
  deployment.sh \
  commands.sh \
  main.sh; do
  source "${DEPLOY_PRODUCTION_LIB_DIR}/${deploy_production_module}"
done

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
