#!/usr/bin/env bash

# Activates one reviewed outbound-attempt HMAC keyring generation in HML.
# This is intentionally narrower than a full environment deployment: stateful
# dependencies and images must already have been provisioned by the approved HML
# release procedure.

set -Eeuo pipefail
umask 077

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPOSITORY_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
BASE_COMPOSE_FILE="${REPOSITORY_ROOT}/docker-compose.yml"
HML_COMPOSE_FILE="${REPOSITORY_ROOT}/docker-compose.hml.yml"
HML_OUTBOUND_SOURCE_PATH="${REPOSITORY_ROOT}/.deploy/hml/secrets/outbound-hmac"
HML_OUTBOUND_APPROVAL_PATH="${REPOSITORY_ROOT}/.deploy/hml/approvals/outbound-hmac"
OUTBOUND_KEYRING_VOLUME="hml-outbound-attempt-keyring"
OUTBOUND_KEYRING_TARGET="/run/saas-secrets/conversation-outbound-attempt-hmac-keyring.json"

ENV_FILE=""
WAIT_TIMEOUT_SECONDS=180
BACKEND_ACTIVATED=false
ROLLOUT_STARTED=false
PRIVATE_SNAPSHOT_DIR=""
ENV_SOURCE_FILE=""
ENV_SNAPSHOT_FILE=""
BASE_COMPOSE_SNAPSHOT_FILE=""
HML_COMPOSE_SNAPSHOT_FILE=""
COMPOSE_CANDIDATE_FILE=""
EFFECTIVE_COMPOSE_FILE=""
EFFECTIVE_COMPOSE_TEMPORARY_FILE=""
PINNED_BACKEND_IMAGE_ID=""
HML_STATE_DIR="${REPOSITORY_ROOT}/.deploy/hml/state"
HML_HOST_LOCK_FILE="${HML_STATE_DIR}/outbound-hmac-transition.lock"
HML_HOST_LOCK_FD=""

declare -a COMPOSE=()

log() {
  printf '[hml-outbound-hmac] %s\n' "$*"
}

warn() {
  printf '[hml-outbound-hmac] WARNING: %s\n' "$*" >&2
}

die() {
  printf '[hml-outbound-hmac] ERROR: %s\n' "$*" >&2
  exit 1
}

usage() {
  printf '%s\n' \
    'Usage: deploy-hml-outbound-hmac-keyring.sh --env-file FILE [--wait-timeout SECONDS]' \
    '' \
    'Installs the reviewed HML keyring, force-recreates the backend, waits for' \
    'health, and only then reconciles frontend and proxy. It never creates an' \
    'environment file or reads a default .env.'
}

parse_arguments() {
  while (( $# > 0 )); do
    case "$1" in
      --env-file)
        (( $# >= 2 )) || die '--env-file requires a value'
        ENV_FILE="$2"
        shift 2
        ;;
      --wait-timeout)
        (( $# >= 2 )) || die '--wait-timeout requires a value'
        WAIT_TIMEOUT_SECONDS="$2"
        shift 2
        ;;
      --help|-h)
        usage
        exit 0
        ;;
      *)
        die 'unsupported argument'
        ;;
    esac
  done

  [[ -n "$ENV_FILE" ]] || die '--env-file is required'
  [[ "$WAIT_TIMEOUT_SECONDS" =~ ^[0-9]+$ ]] \
    && (( WAIT_TIMEOUT_SECONDS >= 10 && WAIT_TIMEOUT_SECONDS <= 900 )) \
    || die '--wait-timeout must be an integer from 10 through 900 seconds'
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || die 'a required local command is unavailable'
}

acquire_host_lock() {
  local component owner mode path_identity descriptor_identity

  for component in \
    "${REPOSITORY_ROOT}/.deploy" \
    "${REPOSITORY_ROOT}/.deploy/hml" \
    "$HML_STATE_DIR"; do
    [[ ! -L "$component" ]] \
      || die 'the HML transition state path must not contain symbolic links'
  done
  install -d -m 700 -- "$HML_STATE_DIR" \
    || die 'the private HML transition state directory could not be prepared'
  [[ ! -L "$HML_STATE_DIR" && -d "$HML_STATE_DIR" ]] \
    || die 'the HML transition state directory is not a private regular directory'
  owner="$(stat -c '%u' -- "$HML_STATE_DIR")"
  mode="$(stat -c '%a' -- "$HML_STATE_DIR")"
  [[ "$owner" == "$(id -u)" && "$mode" == 700 ]] \
    || die 'the HML transition state directory must be owner-only'

  if [[ ! -e "$HML_HOST_LOCK_FILE" && ! -L "$HML_HOST_LOCK_FILE" ]]; then
    (set -o noclobber; : >"$HML_HOST_LOCK_FILE") 2>/dev/null || true
  fi
  [[ ! -L "$HML_HOST_LOCK_FILE" && -f "$HML_HOST_LOCK_FILE" ]] \
    || die 'the HML transition lock must be a regular file, not a symbolic link'
  chmod 600 -- "$HML_HOST_LOCK_FILE" \
    || die 'the HML transition lock could not be made owner-only'
  owner="$(stat -c '%u' -- "$HML_HOST_LOCK_FILE")"
  mode="$(stat -c '%a' -- "$HML_HOST_LOCK_FILE")"
  [[ "$owner" == "$(id -u)" && "$mode" == 600 ]] \
    || die 'the HML transition lock must be owned by the deployment user with mode 0600'

  exec {HML_HOST_LOCK_FD}<>"$HML_HOST_LOCK_FILE" \
    || die 'the HML transition lock could not be opened'
  path_identity="$(stat -c '%d:%i' -- "$HML_HOST_LOCK_FILE")"
  descriptor_identity="$(stat -Lc '%d:%i' -- "/proc/self/fd/${HML_HOST_LOCK_FD}")"
  [[ "$path_identity" == "$descriptor_identity" ]] \
    || die 'the HML transition lock changed while it was opened'
  flock -n "$HML_HOST_LOCK_FD" \
    || die 'another HML outbound HMAC transition is already running'
}

initialize_private_snapshot_directory() {
  local owner mode

  PRIVATE_SNAPSHOT_DIR="$(mktemp -d "${TMPDIR:-/tmp}/agentefiscal-hml-transition.XXXXXXXX")" \
    || die 'the private HML transition snapshot directory could not be created'
  chmod 700 -- "$PRIVATE_SNAPSHOT_DIR" \
    || die 'the private HML transition snapshot directory could not be protected'
  [[ ! -L "$PRIVATE_SNAPSHOT_DIR" && -d "$PRIVATE_SNAPSHOT_DIR" ]] \
    || die 'the private HML transition snapshot path is invalid'
  owner="$(stat -c '%u' -- "$PRIVATE_SNAPSHOT_DIR")"
  mode="$(stat -c '%a' -- "$PRIVATE_SNAPSHOT_DIR")"
  [[ "$owner" == "$(id -u)" && "$mode" == 700 ]] \
    || die 'the private HML transition snapshot directory must be owner-only'

  ENV_SNAPSHOT_FILE="${PRIVATE_SNAPSHOT_DIR}/environment.snapshot"
  BASE_COMPOSE_SNAPSHOT_FILE="${PRIVATE_SNAPSHOT_DIR}/compose-base.snapshot.yaml"
  HML_COMPOSE_SNAPSHOT_FILE="${PRIVATE_SNAPSHOT_DIR}/compose-hml.snapshot.yaml"
  COMPOSE_CANDIDATE_FILE="${PRIVATE_SNAPSHOT_DIR}/compose-candidate.snapshot.json"
  EFFECTIVE_COMPOSE_FILE="${PRIVATE_SNAPSHOT_DIR}/compose-effective.snapshot.json"
  EFFECTIVE_COMPOSE_TEMPORARY_FILE="${PRIVATE_SNAPSHOT_DIR}/compose-effective.temporary.json"
}

capture_stable_file() {
  local source="$1"
  local destination="$2"
  local source_policy="$3"
  local source_fd=""
  local path_identity path_identity_after descriptor_identity
  local metadata_before metadata_after path_metadata_after mode owner snapshot_mode

  [[ ! -L "$source" && -f "$source" ]] \
    || die 'an HML transition input must be a regular file, not a symbolic link'
  exec {source_fd}<"$source" \
    || die 'an HML transition input could not be opened'
  [[ -f "/proc/self/fd/${source_fd}" ]] \
    || die 'an HML transition input descriptor is not a regular file'
  path_identity="$(stat -c '%d:%i' -- "$source" 2>/dev/null)" \
    || die 'an HML transition input changed while it was opened'
  descriptor_identity="$(stat -Lc '%d:%i' -- "/proc/self/fd/${source_fd}" 2>/dev/null)" \
    || die 'an HML transition input descriptor changed while it was opened'
  [[ "$path_identity" == "$descriptor_identity" ]] \
    || die 'an HML transition input changed while it was opened'

  if [[ "$source_policy" == environment ]]; then
    mode="$(stat -Lc '%a' -- "/proc/self/fd/${source_fd}")"
    [[ "$mode" == 400 || "$mode" == 600 ]] \
      || die 'the explicit HML environment file must use owner-only mode 0400 or 0600'
  elif [[ "$source_policy" != compose ]]; then
    die 'the internal HML snapshot source policy is invalid'
  fi

  metadata_before="$(stat -Lc '%d:%i:%s:%y:%z' -- "/proc/self/fd/${source_fd}" 2>/dev/null)" \
    || die 'an HML transition input descriptor changed before capture'
  install -m 600 -- "/proc/self/fd/${source_fd}" "$destination" \
    || die 'an HML transition input could not be captured'
  cmp -s -- "/proc/self/fd/${source_fd}" "$destination" \
    || die 'an HML transition input changed while it was captured'
  metadata_after="$(stat -Lc '%d:%i:%s:%y:%z' -- "/proc/self/fd/${source_fd}" 2>/dev/null)" \
    || die 'an HML transition input descriptor changed during capture'
  [[ "$metadata_before" == "$metadata_after" ]] \
    || die 'an HML transition input changed while it was captured'
  [[ ! -L "$source" && -f "$source" ]] \
    || die 'an HML transition input path changed while it was captured'
  path_identity_after="$(stat -c '%d:%i' -- "$source" 2>/dev/null)" \
    || die 'an HML transition input path changed while it was captured'
  path_metadata_after="$(stat -c '%d:%i:%s:%y:%z' -- "$source" 2>/dev/null)" \
    || die 'an HML transition input path changed while it was captured'
  [[ "$path_identity_after" == "$descriptor_identity" \
      && "$path_metadata_after" == "$metadata_after" ]] \
    || die 'an HML transition input path changed while it was captured'
  exec {source_fd}<&-

  chmod 400 -- "$destination" \
    || die 'an HML transition snapshot could not be made read-only'
  [[ ! -L "$destination" && -f "$destination" ]] \
    || die 'an HML transition snapshot is not a regular file'
  owner="$(stat -c '%u' -- "$destination")"
  snapshot_mode="$(stat -c '%a' -- "$destination")"
  [[ "$owner" == "$(id -u)" && "$snapshot_mode" == 400 ]] \
    || die 'an HML transition snapshot must be owner-only and read-only'
}

capture_transition_inputs() {
  ENV_SOURCE_FILE="$ENV_FILE"
  capture_stable_file "$ENV_SOURCE_FILE" "$ENV_SNAPSHOT_FILE" environment
  capture_stable_file "$BASE_COMPOSE_FILE" "$BASE_COMPOSE_SNAPSHOT_FILE" compose
  capture_stable_file "$HML_COMPOSE_FILE" "$HML_COMPOSE_SNAPSHOT_FILE" compose
  ENV_FILE="$ENV_SNAPSHOT_FILE"
}

validate_effective_hmac_boundary() {
  local compose_file="$1"

  jq -e \
    --arg source "$HML_OUTBOUND_SOURCE_PATH" \
    --arg approval "$HML_OUTBOUND_APPROVAL_PATH" \
    --arg volume "$OUTBOUND_KEYRING_VOLUME" \
    --arg target "$OUTBOUND_KEYRING_TARGET" '
      (.services.backend.environment.CONVERSATION_OUTBOUND_ATTEMPT_HMAC_ACTIVE_KEY_ID
        | type == "string"
          and test("^[A-Za-z0-9._-]{1,64}$")
          and . != "CHANGE_ME"
          and . != "__GENERATE__")
      and .services.backend.environment.CONVERSATION_OUTBOUND_ATTEMPT_HMAC_KEYRING_FILE
          == $target
      and ([.services.backend.volumes[]?
            | select(.target == "/run/saas-secrets")] | length) == 1
      and (.services.backend.volumes
        | any(.type == "volume"
              and .source == $volume
              and .target == "/run/saas-secrets"
              and .read_only == true))
      and .services.backend.depends_on["outbound-attempt-keyring-init"].condition
          == "service_completed_successfully"
      and .services.backend.depends_on["outbound-attempt-keyring-init"].required == true
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
          "OUTBOUND_HMAC_SOURCE_PARENT": "/source",
          "OUTBOUND_HMAC_STATE_FILE": "/target/.outbound-hmac-lifecycle-state.json",
          "OUTBOUND_HMAC_TARGET_FILE": "/target/conversation-outbound-attempt-hmac-keyring.json",
          "OUTBOUND_HMAC_TARGET_OWNER": "spring:spring"
      }
      and .services["outbound-attempt-keyring-init"].network_mode == "none"
      and .services["outbound-attempt-keyring-init"].restart == "no"
      and .services["outbound-attempt-keyring-init"].read_only == true
      and (.services["outbound-attempt-keyring-init"].privileged // false) == false
      and (.services["outbound-attempt-keyring-init"].pids_limit
        | type == "number" and . > 0 and . <= 32)
      and ((.services["outbound-attempt-keyring-init"].networks // {}) | length) == 0
      and ((.services["outbound-attempt-keyring-init"].ports // []) | length) == 0
      and .services["outbound-attempt-keyring-init"].tmpfs
          == ["/tmp:rw,noexec,nosuid,size=1m,mode=0700"]
      and (.services["outbound-attempt-keyring-init"].cap_drop | sort) == ["ALL"]
      and (.services["outbound-attempt-keyring-init"].cap_add | sort)
          == ["CHOWN", "DAC_READ_SEARCH"]
      and (.services["outbound-attempt-keyring-init"].security_opt | sort)
          == ["no-new-privileges:true"]
      and (.services["outbound-attempt-keyring-init"].volumes | length) == 3
      and (.services["outbound-attempt-keyring-init"].volumes
        | any(.type == "bind"
              and .source == $source
              and .target == "/source"
              and .read_only == true
              and .bind.create_host_path == false))
      and (.services["outbound-attempt-keyring-init"].volumes
        | any(.type == "bind"
              and .source == $approval
              and .target == "/approval"
              and .read_only == true
              and .bind.create_host_path == false))
      and (.services["outbound-attempt-keyring-init"].volumes
        | any(.type == "volume"
              and .source == $volume
              and .target == "/target"
              and (.read_only // false) == false))
    ' "$compose_file" >/dev/null 2>&1
}

render_pinned_effective_compose() {
  local backend_image_reference initializer_image_reference image_id
  local -a source_compose=(
    docker compose
    --project-name agentefiscal-hml
    --project-directory "$REPOSITORY_ROOT"
    --env-file "$ENV_SNAPSHOT_FILE"
    --file "$BASE_COMPOSE_SNAPSHOT_FILE"
    --file "$HML_COMPOSE_SNAPSHOT_FILE"
  )

  "${source_compose[@]}" config --format json >"$COMPOSE_CANDIDATE_FILE" \
    || die 'the captured HML Compose model could not be rendered'
  chmod 600 -- "$COMPOSE_CANDIDATE_FILE" \
    || die 'the captured HML Compose model could not be protected'
  validate_effective_hmac_boundary "$COMPOSE_CANDIDATE_FILE" \
    || die 'the effective HML Compose model violates the outbound HMAC security boundary'
  backend_image_reference="$(
    jq -er '.services.backend.image | select(type == "string" and length > 0)' \
      "$COMPOSE_CANDIDATE_FILE"
  )" || die 'the captured HML backend image reference is absent'
  initializer_image_reference="$(
    jq -er '.services["outbound-attempt-keyring-init"].image | select(type == "string" and length > 0)' \
      "$COMPOSE_CANDIDATE_FILE"
  )" || die 'the captured HML initializer image reference is absent'
  [[ "$backend_image_reference" == "$initializer_image_reference" ]] \
    || die 'the captured HML backend and initializer image references differ'

  image_id="$(docker image inspect --format '{{.Id}}' "$backend_image_reference" 2>/dev/null)" \
    || die 'the reviewed HML backend image is not available locally'
  [[ "$image_id" =~ ^sha256:[0-9a-f]{64}$ ]] \
    || die 'the reviewed HML backend image did not resolve to an immutable image ID'
  PINNED_BACKEND_IMAGE_ID="$image_id"

  jq --arg image_id "$PINNED_BACKEND_IMAGE_ID" '
    .services.backend.image = $image_id
    | del(.services.backend.build)
    | .services["outbound-attempt-keyring-init"].image = $image_id
  ' "$COMPOSE_CANDIDATE_FILE" >"$EFFECTIVE_COMPOSE_TEMPORARY_FILE" \
    || die 'the pinned HML Compose model could not be rendered'
  chmod 400 -- "$EFFECTIVE_COMPOSE_TEMPORARY_FILE" \
    || die 'the pinned HML Compose model could not be protected'
  mv -- "$EFFECTIVE_COMPOSE_TEMPORARY_FILE" "$EFFECTIVE_COMPOSE_FILE" \
    || die 'the pinned HML Compose model could not be finalized'
  rm -f -- "$COMPOSE_CANDIDATE_FILE" \
    || die 'the unpinned HML Compose candidate could not be removed'

  jq -e --arg image_id "$PINNED_BACKEND_IMAGE_ID" '
    .services.backend.image == $image_id
    and (.services.backend | has("build") | not)
    and .services["outbound-attempt-keyring-init"].image == $image_id
  ' "$EFFECTIVE_COMPOSE_FILE" >/dev/null \
    || die 'the effective HML Compose model did not preserve the immutable image pin'
  validate_effective_hmac_boundary "$EFFECTIVE_COMPOSE_FILE" \
    || die 'the pinned HML Compose model violates the outbound HMAC security boundary'

  COMPOSE=(
    docker compose
    --project-name agentefiscal-hml
    --project-directory "$REPOSITORY_ROOT"
    --env-file "$ENV_SNAPSHOT_FILE"
    --file "$EFFECTIVE_COMPOSE_FILE"
  )
  "${COMPOSE[@]}" config --quiet \
    || die 'the pinned HML Compose model is invalid'
}

cleanup_private_snapshots() {
  local failed=false artifact

  if [[ -n "$PRIVATE_SNAPSHOT_DIR" ]]; then
    for artifact in \
      "$ENV_SNAPSHOT_FILE" \
      "$BASE_COMPOSE_SNAPSHOT_FILE" \
      "$HML_COMPOSE_SNAPSHOT_FILE" \
      "$COMPOSE_CANDIDATE_FILE" \
      "$EFFECTIVE_COMPOSE_FILE" \
      "$EFFECTIVE_COMPOSE_TEMPORARY_FILE"; do
      [[ -z "$artifact" ]] || rm -f -- "$artifact" || failed=true
    done
    rmdir -- "$PRIVATE_SNAPSHOT_DIR" 2>/dev/null || failed=true
  fi
  [[ "$failed" == false ]]
}

container_for_service() {
  local service="$1"
  local result count

  result="$("${COMPOSE[@]}" ps --all --quiet "$service")"
  count="$(printf '%s\n' "$result" | sed '/^$/d' | wc -l | tr -d ' ')"
  (( count <= 1 )) || die 'more than one container exists for an HML service'
  printf '%s' "$result"
}

wait_for_service() {
  local service="$1"
  local require_health="${2:-false}"
  local deadline=$((SECONDS + WAIT_TIMEOUT_SECONDS))
  local container_id status health

  [[ "$require_health" == true || "$require_health" == false ]] \
    || die 'the internal health requirement must be true or false'

  log "Waiting for ${service} health."
  while (( SECONDS < deadline )); do
    container_id="$(container_for_service "$service")"
    if [[ -n "$container_id" ]]; then
      status="$(docker inspect --format '{{.State.Status}}' "$container_id" 2>/dev/null || true)"
      health="$(docker inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' "$container_id" 2>/dev/null || true)"
      if [[ "$status" == running && "$health" == healthy ]]; then
        return 0
      fi
      if [[ "$status" == running && "$health" == none && "$require_health" == false ]]; then
        return 0
      fi
      if [[ "$status" == exited || "$health" == unhealthy ]]; then
        "${COMPOSE[@]}" logs --tail 120 "$service" >&2 || true
        die 'an HML service failed before becoming healthy'
      fi
    fi
    sleep 3
  done

  "${COMPOSE[@]}" logs --tail 120 "$service" >&2 || true
  die 'timed out waiting for an HML service'
}

cleanup_on_exit() {
  local status=$?
  trap - EXIT INT TERM

  if (( status != 0 )) \
      && [[ "$ROLLOUT_STARTED" == true && "$BACKEND_ACTIVATED" == false ]]; then
    warn 'Keyring installation completed without a healthy recreated backend; stopping stale HML application traffic.'
    "${COMPOSE[@]}" stop --timeout 60 proxy >/dev/null 2>&1 \
      || warn 'Failed to stop the HML proxy after activation failure.'
    "${COMPOSE[@]}" stop --timeout 60 backend >/dev/null 2>&1 \
      || warn 'Failed to stop the stale HML backend after activation failure.'
  fi

  if ! cleanup_private_snapshots; then
    warn 'Failed to remove one or more private HML transition snapshots.'
    (( status == 0 )) && status=1
  fi

  exit "$status"
}

main() {
  local command_name

  parse_arguments "$@"
  for command_name in chmod cmp docker flock id install jq mktemp mv rm rmdir sed sleep stat tr wc; do
    require_command "$command_name"
  done

  trap cleanup_on_exit EXIT
  trap 'exit 130' INT
  trap 'exit 143' TERM

  acquire_host_lock
  initialize_private_snapshot_directory
  capture_transition_inputs

  docker info >/dev/null 2>&1 || die 'Docker daemon is unavailable'
  render_pinned_effective_compose

  # Enter the fail-closed boundary before the initializer so a signal cannot
  # leave the previous in-memory generation serving after a target transition.
  ROLLOUT_STARTED=true
  log 'Installing the reviewed keyring generation.'
  "${COMPOSE[@]}" run --rm --no-deps outbound-attempt-keyring-init

  log 'Force-recreating the backend so it loads the installed generation.'
  "${COMPOSE[@]}" up -d --no-build --no-deps --force-recreate backend
  wait_for_service backend true
  BACKEND_ACTIVATED=true

  "${COMPOSE[@]}" up -d --no-build --no-deps frontend
  wait_for_service frontend
  "${COMPOSE[@]}" up -d --no-build --no-deps --force-recreate proxy
  wait_for_service proxy

  log 'HML outbound HMAC generation is active in a healthy recreated backend.'
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
