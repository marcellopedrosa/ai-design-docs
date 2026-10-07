#!/usr/bin/env bash
set -Eeuo pipefail

# Prepare one explicitly authorized local developer account for an existing
# rootful Docker Engine. This script never installs Docker, changes the socket,
# reads application configuration, or starts Compose except through one of the
# explicitly allowlisted development entrypoints.

umask 077

BOOTSTRAP_PREFIX="dev-host-bootstrap"
SYSTEM_PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/snap/bin"
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
REPOSITORY_ROOT="$(cd -- "$SCRIPT_DIR/../.." && pwd -P)"
DOCKER_SOCKET="/var/run/docker.sock"
DOCKER_ENDPOINT="unix:///var/run/docker.sock"
LOCK_FILE="/run/saas-development-host-bootstrap.lock"

DEVELOPER_USER=""
DOCKER_ACCESS=""
CONTINUE_TARGET=""
CONTINUE_PATH=""
DEVELOPER_UID=""
DEVELOPER_GID=""
DEVELOPER_HOME=""
DEVELOPER_SHELL=""
DOCKER_GID=""
DOCKER_BIN=""
LOCK_FD=""
MEMBERSHIP_CREATED=false
MEMBERSHIP_COMMITTED=false
ROLLBACK_ATTEMPTED=false

usage() {
  cat <<'USAGE'
Usage:
  sudo ./infra/scripts/bootstrap-development-host.sh \
    --developer-user USER \
    --docker-access rootful-group \
    [--continue start-dev-bot|start-dev-dns-bot|start-dev-bot-exposed-ngrok]

This one-time bootstrap grants root-equivalent Docker group access only after
validating an existing local rootful daemon. It does not install or migrate
Docker and does not alter the Docker socket, ACLs, sudoers, containers, or data.

Options:
  --developer-user USER       Explicit regular local account to prepare.
  --docker-access MODE        Required explicit opt-in; only rootful-group.
  --continue ENTRYPOINT       Optionally start one allowlisted DEV entrypoint in
                              a fresh, sanitized session after validation.
  -h, --help                  Show this help.
USAGE
}

log() {
  printf '[%s] %s\n' "$BOOTSTRAP_PREFIX" "$*"
}

die() {
  printf '[%s] ERROR: %s\n' "$BOOTSTRAP_PREFIX" "$*" >&2
  exit 1
}

require_root() {
  local effective_uid="${1:-$EUID}"
  [[ "$effective_uid" =~ ^[0-9]+$ && "$effective_uid" == 0 ]] \
    || die "Run this bootstrap as root with sudo."
}

parse_args() {
  while (( $# > 0 )); do
    case "$1" in
      --developer-user)
        (( $# >= 2 )) || die "--developer-user requires a value."
        [[ -z "$DEVELOPER_USER" ]] || die "--developer-user may be provided only once."
        DEVELOPER_USER="$2"
        shift 2
        ;;
      --docker-access)
        (( $# >= 2 )) || die "--docker-access requires a value."
        [[ -z "$DOCKER_ACCESS" ]] || die "--docker-access may be provided only once."
        DOCKER_ACCESS="$2"
        shift 2
        ;;
      --continue)
        (( $# >= 2 )) || die "--continue requires a value."
        [[ -z "$CONTINUE_TARGET" ]] || die "--continue may be provided only once."
        CONTINUE_TARGET="$2"
        shift 2
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

  [[ -n "$DEVELOPER_USER" ]] || die "--developer-user is required."
  [[ "$DOCKER_ACCESS" == rootful-group ]] \
    || die "--docker-access must be the explicit value rootful-group."

  case "$CONTINUE_TARGET" in
    "")
      CONTINUE_PATH=""
      ;;
    start-dev-bot)
      CONTINUE_PATH="$REPOSITORY_ROOT/start-dev-bot.sh"
      ;;
    start-dev-dns-bot)
      CONTINUE_PATH="$REPOSITORY_ROOT/start-dev-dns-bot.sh"
      ;;
    start-dev-bot-exposed-ngrok)
      CONTINUE_PATH="$REPOSITORY_ROOT/start-dev-bot-exposed-ngrok.sh"
      ;;
    *)
      die "--continue accepts only start-dev-bot, start-dev-dns-bot, or start-dev-bot-exposed-ngrok."
      ;;
  esac
}

validate_developer_user() {
  local passwd_entry passwd_name passwd_marker passwd_gecos extra home_uid

  [[ "$DEVELOPER_USER" =~ ^[a-z_][a-z0-9_-]{0,31}$ ]] \
    || die "Invalid developer user name."
  [[ "$DEVELOPER_USER" != root ]] || die "The developer user must not be root."

  passwd_entry="$(getent passwd "$DEVELOPER_USER")" \
    || die "Developer user does not exist in NSS."
  [[ -n "$passwd_entry" && "$passwd_entry" != *$'\n'* ]] \
    || die "Developer user must resolve to exactly one NSS entry."
  IFS=: read -r passwd_name passwd_marker DEVELOPER_UID DEVELOPER_GID \
    passwd_gecos DEVELOPER_HOME DEVELOPER_SHELL extra <<<"$passwd_entry"
  [[ "$passwd_name" == "$DEVELOPER_USER" && -z "${extra:-}" ]] \
    || die "Developer NSS entry is malformed or ambiguous."
  [[ "$DEVELOPER_UID" =~ ^[0-9]+$ && "$DEVELOPER_GID" =~ ^[0-9]+$ ]] \
    || die "Developer NSS identity contains an invalid UID or GID."
  (( DEVELOPER_UID >= 1000 && DEVELOPER_UID < 65534 )) \
    || die "Developer user must have a regular, non-system UID."
  [[ "$DEVELOPER_HOME" == /* && "$DEVELOPER_HOME" != / ]] \
    || die "Developer user must have a dedicated absolute home directory."
  [[ -d "$DEVELOPER_HOME" && ! -L "$DEVELOPER_HOME" ]] \
    || die "Developer home must be an existing, non-symbolic-link directory."
  home_uid="$(stat -c '%u' -- "$DEVELOPER_HOME")" \
    || die "Cannot inspect developer home ownership."
  [[ "$home_uid" == "$DEVELOPER_UID" ]] \
    || die "Developer home must be owned by the selected developer user."
  case "$DEVELOPER_SHELL" in
    ""|*/false|*/nologin)
      die "Developer user must have an interactive login shell."
      ;;
  esac

  if [[ -n "${SUDO_USER:-}" && "${SUDO_USER}" != "$DEVELOPER_USER" ]]; then
    die "--developer-user must match SUDO_USER for a sudo invocation."
  fi
  if [[ -n "${SUDO_UID:-}" ]]; then
    [[ "$SUDO_UID" =~ ^[0-9]+$ && "$SUDO_UID" == "$DEVELOPER_UID" ]] \
      || die "SUDO_UID does not match the selected developer user."
  fi
  if [[ -n "${SUDO_GID:-}" ]]; then
    [[ "$SUDO_GID" =~ ^[0-9]+$ && "$SUDO_GID" == "$DEVELOPER_GID" ]] \
      || die "SUDO_GID does not match the selected developer user."
  fi
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || die "Required host command is absent: $1"
}

run_as_developer_clean() {
  runuser -u "$DEVELOPER_USER" -- env -i \
    "HOME=$DEVELOPER_HOME" \
    "USER=$DEVELOPER_USER" \
    "LOGNAME=$DEVELOPER_USER" \
    "SHELL=$DEVELOPER_SHELL" \
    "PATH=$SYSTEM_PATH" \
    "$@"
}

validate_docker_socket() {
  local socket_metadata socket_uid socket_gid socket_mode extra

  [[ ! -L "$DOCKER_SOCKET" ]] \
    || die "$DOCKER_SOCKET must not be a symbolic link."
  [[ -S "$DOCKER_SOCKET" ]] \
    || die "$DOCKER_SOCKET must be an existing Unix socket."
  socket_metadata="$(stat -c '%u:%g:%a' -- "$DOCKER_SOCKET")" \
    || die "Cannot inspect Docker socket metadata."
  IFS=: read -r socket_uid socket_gid socket_mode extra <<<"$socket_metadata"
  [[ -z "${extra:-}" && "$socket_uid" == 0 && "$socket_gid" == "$DOCKER_GID" ]] \
    || die "Docker socket must be owned by root:docker."
  [[ "$socket_mode" == 660 ]] \
    || die "Docker socket mode must be exactly 0660."
}

validate_docker_context() {
  local context_name context_endpoint

  context_name="$(run_as_developer_clean "$DOCKER_BIN" context show 2>/dev/null)" \
    || die "Cannot resolve the developer Docker context."
  [[ -n "$context_name" && "$context_name" != *$'\n'* ]] \
    || die "Developer Docker context is empty or ambiguous."
  context_endpoint="$(run_as_developer_clean "$DOCKER_BIN" context inspect \
    --format '{{ (index .Endpoints "docker").Host }}' "$context_name" 2>/dev/null)" \
    || die "Cannot inspect the developer Docker context."
  [[ "$context_endpoint" == "$DOCKER_ENDPOINT" ]] \
    || die "Developer Docker context must use $DOCKER_ENDPOINT."
}

validate_continue_target() {
  local repository_uid entrypoint_uid

  [[ -n "$CONTINUE_TARGET" ]] || return 0
  [[ -d "$REPOSITORY_ROOT" && ! -L "$REPOSITORY_ROOT" ]] \
    || die "Repository root must be a real directory."
  repository_uid="$(stat -c '%u' -- "$REPOSITORY_ROOT")" \
    || die "Cannot inspect repository ownership."
  [[ "$repository_uid" == "$DEVELOPER_UID" ]] \
    || die "Repository root must be owned by the selected developer user."
  [[ -f "$CONTINUE_PATH" && ! -L "$CONTINUE_PATH" && -x "$CONTINUE_PATH" ]] \
    || die "Allowlisted development entrypoint is absent or unsafe."
  entrypoint_uid="$(stat -c '%u' -- "$CONTINUE_PATH")" \
    || die "Cannot inspect development entrypoint ownership."
  [[ "$entrypoint_uid" == "$DEVELOPER_UID" ]] \
    || die "Development entrypoint must be owned by the selected developer user."
}

validate_docker_prerequisites() {
  local command_name docker_group_entry docker_group_name docker_group_marker
  local docker_group_members extra docker_context_variable

  [[ "$(uname -s)" == Linux ]] || die "This bootstrap supports Linux hosts only."
  for command_name in docker env flock getent gpasswd id runuser stat uname usermod; do
    require_command "$command_name"
  done

  for docker_context_variable in DOCKER_HOST DOCKER_CONTEXT DOCKER_TLS_VERIFY DOCKER_CERT_PATH; do
    [[ -z "${!docker_context_variable:-}" ]] \
      || die "$docker_context_variable must be unset; only the canonical local Docker socket is allowed."
  done

  DOCKER_BIN="$(command -v docker)"
  [[ "$DOCKER_BIN" == /* ]] || die "Docker executable must resolve to an absolute path."
  "$DOCKER_BIN" compose version >/dev/null 2>&1 \
    || die "Docker Compose v2 is unavailable."

  docker_group_entry="$(getent group docker)" \
    || die "Docker group does not exist in NSS."
  [[ -n "$docker_group_entry" && "$docker_group_entry" != *$'\n'* ]] \
    || die "Docker group must resolve to exactly one NSS entry."
  IFS=: read -r docker_group_name docker_group_marker DOCKER_GID \
    docker_group_members extra <<<"$docker_group_entry"
  [[ "$docker_group_name" == docker && "$DOCKER_GID" =~ ^[0-9]+$ && -z "${extra:-}" ]] \
    || die "Docker group NSS entry is malformed or ambiguous."

  validate_docker_context
  validate_docker_socket
  "$DOCKER_BIN" --host "$DOCKER_ENDPOINT" info >/dev/null 2>&1 \
    || die "The canonical local Docker daemon is unavailable or unhealthy."
  validate_continue_target
}

acquire_lock() {
  local lock_directory lock_directory_metadata lock_uid lock_gid lock_mode extra
  local lock_file_metadata lock_file_uid lock_file_gid lock_file_mode

  lock_directory="${LOCK_FILE%/*}"
  [[ -d "$lock_directory" && ! -L "$lock_directory" ]] \
    || die "Bootstrap lock directory is absent or unsafe."
  lock_directory_metadata="$(stat -c '%u:%g:%a' -- "$lock_directory")" \
    || die "Cannot inspect bootstrap lock directory."
  IFS=: read -r lock_uid lock_gid lock_mode extra <<<"$lock_directory_metadata"
  [[ -z "${extra:-}" && "$lock_uid" == 0 && "$lock_gid" == 0 \
      && "$lock_mode" =~ ^[0-7]{3,4}$ ]] \
    || die "Bootstrap lock directory must be owned by root:root."
  (( (8#$lock_mode & 0022) == 0 )) \
    || die "Bootstrap lock directory must not be writable outside its root owner."
  [[ ! -L "$LOCK_FILE" ]] || die "Bootstrap lock file must not be a symbolic link."
  if [[ -e "$LOCK_FILE" ]]; then
    [[ -f "$LOCK_FILE" ]] || die "Bootstrap lock path must be a regular file."
    lock_file_metadata="$(stat -c '%u:%g:%a' -- "$LOCK_FILE")" \
      || die "Cannot inspect bootstrap lock file."
    IFS=: read -r lock_file_uid lock_file_gid lock_file_mode extra <<<"$lock_file_metadata"
    [[ -z "${extra:-}" && "$lock_file_uid" == 0 && "$lock_file_gid" == 0 ]] \
      || die "Bootstrap lock file must be owned by root:root."
    [[ "$lock_file_mode" == 600 ]] \
      || die "Bootstrap lock file mode must be exactly 0600."
  fi
  exec {LOCK_FD}>>"$LOCK_FILE" || die "Cannot open bootstrap lock file."
  flock -n -x "$LOCK_FD" || die "Another development host bootstrap is already running."
}

user_in_docker_group() {
  local numeric_groups
  numeric_groups="$(id -G "$DEVELOPER_USER")" \
    || die "Cannot resolve developer supplementary groups."
  [[ " $numeric_groups " == *" $DOCKER_GID "* ]]
}

add_docker_group_membership() {
  usermod -aG docker "$DEVELOPER_USER"
}

remove_docker_group_membership() {
  gpasswd -d "$DEVELOPER_USER" docker >/dev/null
}

validate_fresh_session() {
  run_as_developer_clean "$DOCKER_BIN" --host "$DOCKER_ENDPOINT" info >/dev/null 2>&1
}

rollback_pending_membership() {
  [[ "$MEMBERSHIP_CREATED" == true && "$MEMBERSHIP_COMMITTED" != true ]] || return 0
  [[ "$ROLLBACK_ATTEMPTED" != true ]] || return 1
  ROLLBACK_ATTEMPTED=true
  if remove_docker_group_membership; then
    MEMBERSHIP_CREATED=false
    log "Rolled back the Docker group association created by this execution."
    return 0
  fi
  printf '[%s] ERROR: Could not roll back the Docker group association created by this execution.\n' \
    "$BOOTSTRAP_PREFIX" >&2
  return 1
}

cleanup_transaction() {
  local status=$?
  if [[ "$MEMBERSHIP_CREATED" == true && "$MEMBERSHIP_COMMITTED" != true \
      && "$ROLLBACK_ATTEMPTED" != true ]]; then
    rollback_pending_membership || true
  fi
  return "$status"
}

continue_entrypoint() {
  [[ -n "$CONTINUE_TARGET" ]] || return 0
  log "Starting $CONTINUE_TARGET in a fresh developer session."
  run_as_developer_clean \
    "DOCKER_HOST=$DOCKER_ENDPOINT" \
    "$CONTINUE_PATH"
}

main() {
  PATH="$SYSTEM_PATH"
  export PATH

  parse_args "$@"
  require_root
  validate_developer_user
  validate_docker_prerequisites
  acquire_lock

  trap cleanup_transaction EXIT
  trap 'exit 130' INT
  trap 'exit 143' TERM
  trap 'exit 129' HUP

  if user_in_docker_group; then
    log "$DEVELOPER_USER is already a member of the Docker group; no host change is needed."
  else
    log "Adding the explicitly authorized developer user to the Docker group."
    if ! add_docker_group_membership; then
      if user_in_docker_group; then
        MEMBERSHIP_CREATED=true
        if rollback_pending_membership; then
          die "usermod failed after making the Docker association visible; the partial change was rolled back."
        fi
        die "usermod failed after making the Docker association visible and rollback was not completed; stop and review the host membership state."
      fi
      die "Could not add the developer user to the Docker group."
    fi
    MEMBERSHIP_CREATED=true
    if ! user_in_docker_group; then
      if rollback_pending_membership; then
        die "Docker group membership was not visible after usermod; the new association was rolled back."
      fi
      die "Docker group membership was not visible after usermod and rollback was not completed; stop and review the host membership state."
    fi
  fi

  if ! validate_fresh_session; then
    if [[ "$MEMBERSHIP_CREATED" == true ]]; then
      if rollback_pending_membership; then
        die "Fresh-session Docker validation failed; the new association was rolled back."
      fi
      die "Fresh-session Docker validation failed and rollback was not completed; stop and review the host membership state."
    fi
    die "Fresh-session Docker validation failed; no existing group association was changed."
  fi

  MEMBERSHIP_COMMITTED=true
  trap - EXIT INT TERM HUP
  log "Docker access is ready for $DEVELOPER_USER in a fresh session."
  if [[ "$MEMBERSHIP_CREATED" == true ]]; then
    log "Reopen any previously running shell, IDE, or agent once before using Docker there."
  fi

  continue_entrypoint
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
