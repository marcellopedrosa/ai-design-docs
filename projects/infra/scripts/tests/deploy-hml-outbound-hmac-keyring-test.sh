#!/usr/bin/env bash

set -Eeuo pipefail

TEST_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPOSITORY_ROOT="$(cd "${TEST_SCRIPT_DIR}/../../.." && pwd)"
DEPLOY_SCRIPT="${TEST_SCRIPT_DIR}/../deploy-hml-outbound-hmac-keyring.sh"
VERSIONED_HML_COMPOSE="${REPOSITORY_ROOT}/docker-compose.hml.yml"
TEST_ROOT="$(mktemp -d)"
ENV_SOURCE_DIR="${TEST_ROOT}/env-source"
LIVE_ENV_FILE="${ENV_SOURCE_DIR}/hml.env"
LIVE_BASE_COMPOSE_FILE="${TEST_ROOT}/docker-compose.yml"
LIVE_HML_COMPOSE_FILE="${TEST_ROOT}/docker-compose.hml.yml"
SNAPSHOT_PARENT="${TEST_ROOT}/snapshots"
STATE_DIR="${TEST_ROOT}/state"
SUCCESS_LOG="${TEST_ROOT}/success-docker.log"
FAILURE_LOG="${TEST_ROOT}/failure-docker.log"
INITIALIZER_FAILURE_LOG="${TEST_ROOT}/initializer-failure-docker.log"
MISSING_HEALTH_LOG="${TEST_ROOT}/missing-health-docker.log"
ACQUISITION_FAILURE_LOG="${TEST_ROOT}/acquisition-failure-docker.log"
LOCKED_LOG="${TEST_ROOT}/locked-docker.log"
ARTIFACT_LOG="${TEST_ROOT}/artifact.log"
TAG_STATE_FILE="${TEST_ROOT}/tag-state"
OUTPUT_FILE="${TEST_ROOT}/output.log"
IMAGE_A="sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
IMAGE_B="sha256:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"

cleanup() {
  rm -rf -- "$TEST_ROOT"
}
trap cleanup EXIT INT TERM

fail() {
  printf 'deploy-hml-outbound-hmac-keyring-test: FAIL: %s\n' "$*" >&2
  exit 1
}

line_for() {
  local pattern="$1"
  local file="$2"
  grep -nF "$pattern" "$file" | cut -d: -f1
}

write_generation_a_sources() {
  rm -rf -- \
    "$ENV_SOURCE_DIR" \
    "${ENV_SOURCE_DIR}.original" \
    "${ENV_SOURCE_DIR}.replacement"
  mkdir -m 700 -- "$ENV_SOURCE_DIR"
  printf '%s\n' 'ENV_GENERATION=A' >"$LIVE_ENV_FILE"
  chmod 600 "$LIVE_ENV_FILE"
  printf '%s\n' 'BASE_GENERATION=A' >"$LIVE_BASE_COMPOSE_FILE"
  printf '%s\n' 'HML_GENERATION=A' >"$LIVE_HML_COMPOSE_FILE"
  printf '%s\n' "$IMAGE_A" >"$TAG_STATE_FILE"
}

fake_error() {
  printf 'fake Docker contract violation: %s\n' "$*" >&2
  return 90
}

assert_private_snapshot() {
  local file="$1"
  local expected="$2"
  local directory

  [[ -f "$file" && ! -L "$file" ]] \
    || fake_error 'a required private snapshot is absent or is a link'
  [[ "$(stat -c '%a' -- "$file")" == 400 ]] \
    || fake_error 'a required private snapshot is not mode 0400'
  directory="$(dirname "$file")"
  [[ "$(stat -c '%a' -- "$directory")" == 700 ]] \
    || fake_error 'the private snapshot directory is not mode 0700'
  grep -Fqx "$expected" "$file" \
    || fake_error 'a private snapshot did not preserve generation A'
}

install() {
  command install "$@"
  if [[ "$*" == *'/proc/self/fd/'* && "$*" == *'environment.snapshot'* ]]; then
    if [[ "${FAKE_MUTATE_DURING_ENV_CAPTURE:-false}" == true ]]; then
      printf '%s\n' 'ENV_GENERATION=B' >"$LIVE_ENV_FILE"
      chmod 600 "$LIVE_ENV_FILE"
    elif [[ "${FAKE_RENAME_DURING_ENV_CAPTURE:-false}" == true ]]; then
      mv -- "$ENV_SOURCE_DIR" "${ENV_SOURCE_DIR}.original"
      mkdir -m 700 -- "$ENV_SOURCE_DIR"
      printf '%s\n' 'ENV_GENERATION=B' >"$LIVE_ENV_FILE"
      chmod 600 "$LIVE_ENV_FILE"
    elif [[ "${FAKE_SYMLINK_DURING_ENV_CAPTURE:-false}" == true ]]; then
      mv -- "$ENV_SOURCE_DIR" "${ENV_SOURCE_DIR}.original"
      mkdir -m 700 -- "${ENV_SOURCE_DIR}.replacement"
      printf '%s\n' 'ENV_GENERATION=B' >"${ENV_SOURCE_DIR}.replacement/hml.env"
      chmod 600 "${ENV_SOURCE_DIR}.replacement/hml.env"
      ln -s "${ENV_SOURCE_DIR}.replacement" "$ENV_SOURCE_DIR"
    fi
  fi
}

sleep() {
  command sleep 1
}

render_effective_fixture() {
  jq -n --arg repository "$REPOSITORY_ROOT" '
    {
      name: "agentefiscal-hml",
      services: {
        backend: {
          image: "saas-backend:mutable",
          build: {context: "/captured/generation-a"},
          environment: {
            ENV_GENERATION: "A",
            CONVERSATION_OUTBOUND_ATTEMPT_HMAC_ACTIVE_KEY_ID: "hml-outbound-v1",
            CONVERSATION_OUTBOUND_ATTEMPT_HMAC_KEYRING_FILE:
              "/run/saas-secrets/conversation-outbound-attempt-hmac-keyring.json"
          },
          volumes: [{
            type: "volume",
            source: "hml-outbound-attempt-keyring",
            target: "/run/saas-secrets",
            read_only: true
          }],
          depends_on: {
            "outbound-attempt-keyring-init": {
              condition: "service_completed_successfully",
              required: true
            }
          }
        },
        "outbound-attempt-keyring-init": {
          image: "saas-backend:mutable",
          user: "root",
          entrypoint: ["/opt/saas/bin/outbound-hmac-keyring-lifecycle.sh"],
          environment: {
            OUTBOUND_HMAC_ACTIVE_KEY_ID: "hml-outbound-v1",
            OUTBOUND_HMAC_APPROVAL_DIRECTORY: "/approval",
            OUTBOUND_HMAC_APPROVAL_FILE: "/approval/outbound-hmac-key-removal.json",
            OUTBOUND_HMAC_PENDING_FILE: "/target/.outbound-hmac-lifecycle-pending.json",
            OUTBOUND_HMAC_SOURCE_FILE: "/source/conversation-outbound-attempt-hmac-keyring.json",
            OUTBOUND_HMAC_SOURCE_PARENT: "/source",
            OUTBOUND_HMAC_STATE_FILE: "/target/.outbound-hmac-lifecycle-state.json",
            OUTBOUND_HMAC_TARGET_FILE: "/target/conversation-outbound-attempt-hmac-keyring.json",
            OUTBOUND_HMAC_TARGET_OWNER: "spring:spring"
          },
          network_mode: "none",
          restart: "no",
          read_only: true,
          privileged: false,
          pids_limit: 32,
          networks: {},
          ports: [],
          tmpfs: ["/tmp:rw,noexec,nosuid,size=1m,mode=0700"],
          cap_drop: ["ALL"],
          cap_add: ["CHOWN", "DAC_READ_SEARCH"],
          security_opt: ["no-new-privileges:true"],
          volumes: [
            {
              type: "bind",
              source: ($repository + "/.deploy/hml/secrets/outbound-hmac"),
              target: "/source",
              read_only: true,
              bind: {create_host_path: false}
            },
            {
              type: "bind",
              source: ($repository + "/.deploy/hml/approvals/outbound-hmac"),
              target: "/approval",
              read_only: true,
              bind: {create_host_path: false}
            },
            {
              type: "volume",
              source: "hml-outbound-attempt-keyring",
              target: "/target",
              read_only: false
            }
          ]
        },
        frontend: {image: "saas-frontend:test"},
        proxy: {image: "nginx:test"}
      },
      volumes: {"hml-outbound-attempt-keyring": {driver: "local"}}
    }
  '
}

docker() {
  local -a arguments=("$@") compose_files=()
  local env_file="" action="" index token effective_file="" candidate

  printf '%s\n' "$*" >>"$FAKE_DOCKER_LOG"

  if [[ "${1:-}" == info ]]; then
    if [[ "${FAKE_MUTATE_LIVE_INPUTS_ON_INFO:-false}" == true ]]; then
      printf '%s\n' 'ENV_GENERATION=B' >"$LIVE_ENV_FILE"
      chmod 600 "$LIVE_ENV_FILE"
      printf '%s\n' 'BASE_GENERATION=B' >"$LIVE_BASE_COMPOSE_FILE"
      printf '%s\n' 'HML_GENERATION=B' >"$LIVE_HML_COMPOSE_FILE"
    fi
    return 0
  fi

  if [[ "${1:-}" == image && "${2:-}" == inspect ]]; then
    [[ "${!#}" == 'saas-backend:mutable' ]] \
      || fake_error 'the backend image was not resolved from the captured model'
    printf '%s\n' "$IMAGE_A"
    printf '%s\n' "$IMAGE_B" >"$TAG_STATE_FILE"
    return 0
  fi

  if [[ "${1:-}" == inspect && "$*" == *'.State.Status'* ]]; then
    printf '%s\n' running
    return 0
  fi
  if [[ "${1:-}" == inspect && "$*" == *'.State.Health'* ]]; then
    if [[ "${FAKE_HEALTH_NONE:-false}" == true ]]; then
      printf '%s\n' none
    else
      printf '%s\n' healthy
    fi
    return 0
  fi

  [[ "${1:-}" == compose ]] || return 0
  for (( index = 1; index < ${#arguments[@]}; index++ )); do
    token="${arguments[$index]}"
    case "$token" in
      --env-file)
        (( index++ ))
        env_file="${arguments[$index]}"
        ;;
      --file)
        (( index++ ))
        compose_files+=("${arguments[$index]}")
        ;;
      config|run|up|ps|logs|stop)
        [[ -n "$action" ]] || action="$token"
        ;;
    esac
  done

  assert_private_snapshot "$env_file" 'ENV_GENERATION=A'
  printf 'snapshot_dir=%s\n' "$(dirname "$env_file")" >>"$ARTIFACT_LOG"

  if (( ${#compose_files[@]} == 2 )); then
    assert_private_snapshot "${compose_files[0]}" 'BASE_GENERATION=A'
    assert_private_snapshot "${compose_files[1]}" 'HML_GENERATION=A'
    [[ "$action" == config && "$*" == *'--format json'* ]] \
      || fake_error 'captured source files were used outside the one-time render'
    printf '%s\n' 'phase=source' >>"$ARTIFACT_LOG"
    candidate="$(render_effective_fixture)"
    if [[ -n "${FAKE_BROKEN_BOUNDARY_FILTER:-}" ]]; then
      jq "$FAKE_BROKEN_BOUNDARY_FILTER" <<<"$candidate"
    else
      printf '%s\n' "$candidate"
    fi
    return 0
  fi

  (( ${#compose_files[@]} == 1 )) \
    || fake_error 'the transition did not use one effective Compose model'
  effective_file="${compose_files[0]}"
  [[ "$(stat -c '%a' -- "$effective_file")" == 400 ]] \
    || fake_error 'the effective Compose model is not mode 0400'
  [[ "$(dirname "$effective_file")" == "$(dirname "$env_file")" ]] \
    || fake_error 'env and effective Compose snapshots do not share the private execution scope'
  jq -e --arg image "$IMAGE_A" '
    .services.backend.image == $image
    and (.services.backend | has("build") | not)
    and .services["outbound-attempt-keyring-init"].image == $image
    and .services.backend.environment.ENV_GENERATION == "A"
  ' "$effective_file" >/dev/null \
    || fake_error 'the effective Compose model is not pinned to generation/image A'
  [[ "$(<"$TAG_STATE_FILE")" == "$IMAGE_B" ]] \
    || fake_error 'the mutable tag was not changed after its one-time resolution'
  printf 'phase=effective\neffective_file=%s\n' "$effective_file" >>"$ARTIFACT_LOG"

  if [[ "$action" == ps && "$*" == *'--all --quiet'* ]]; then
    printf 'fake-%s\n' "${!#}"
    return 0
  fi
  if [[ "${FAKE_FAIL_INITIALIZER:-false}" == true \
      && "$*" == *'run --rm --no-deps outbound-attempt-keyring-init'* ]]; then
    return 41
  fi
  if [[ "${FAKE_FAIL_BACKEND_RECREATE:-false}" == true \
      && "$*" == *'up -d --no-build --no-deps --force-recreate backend'* ]]; then
    return 42
  fi
  return 0
}

run_deploy() {
  local docker_log="$1"
  local state_dir="$2"
  local requested_env="${3:-$LIVE_ENV_FILE}"

  DEPLOY_TEST_SCRIPT="$DEPLOY_SCRIPT" \
  DEPLOY_TEST_BASE_COMPOSE="$LIVE_BASE_COMPOSE_FILE" \
  DEPLOY_TEST_HML_COMPOSE="$LIVE_HML_COMPOSE_FILE" \
  DEPLOY_TEST_STATE_DIR="$state_dir" \
  DEPLOY_TEST_ENV_FILE="$requested_env" \
  DEPLOY_TEST_SNAPSHOT_PARENT="$SNAPSHOT_PARENT" \
  FAKE_DOCKER_LOG="$docker_log" \
  FAKE_MUTATE_LIVE_INPUTS_ON_INFO="${FAKE_MUTATE_LIVE_INPUTS_ON_INFO:-false}" \
  FAKE_MUTATE_DURING_ENV_CAPTURE="${FAKE_MUTATE_DURING_ENV_CAPTURE:-false}" \
  FAKE_RENAME_DURING_ENV_CAPTURE="${FAKE_RENAME_DURING_ENV_CAPTURE:-false}" \
  FAKE_SYMLINK_DURING_ENV_CAPTURE="${FAKE_SYMLINK_DURING_ENV_CAPTURE:-false}" \
  FAKE_BROKEN_BOUNDARY_FILTER="${FAKE_BROKEN_BOUNDARY_FILTER:-}" \
  FAKE_FAIL_INITIALIZER="${FAKE_FAIL_INITIALIZER:-false}" \
  FAKE_FAIL_BACKEND_RECREATE="${FAKE_FAIL_BACKEND_RECREATE:-false}" \
  FAKE_HEALTH_NONE="${FAKE_HEALTH_NONE:-false}" \
    bash -Eeuo pipefail -c '
      source "$DEPLOY_TEST_SCRIPT"
      BASE_COMPOSE_FILE="$DEPLOY_TEST_BASE_COMPOSE"
      HML_COMPOSE_FILE="$DEPLOY_TEST_HML_COMPOSE"
      HML_STATE_DIR="$DEPLOY_TEST_STATE_DIR"
      HML_HOST_LOCK_FILE="${DEPLOY_TEST_STATE_DIR}/outbound-hmac-transition.lock"
      TMPDIR="$DEPLOY_TEST_SNAPSHOT_PARENT"
      main --env-file "$DEPLOY_TEST_ENV_FILE" --wait-timeout 10
    '
}

[[ -f "$DEPLOY_SCRIPT" ]] || fail 'versioned HML activation entrypoint is absent'
grep -Fq './infra/scripts/deploy-hml-outbound-hmac-keyring.sh --env-file' "$VERSIONED_HML_COMPOSE" \
  || fail 'HML Compose does not point operators to the versioned activation entrypoint'
grep -Fq 'up -d --build --force-recreate' "$VERSIONED_HML_COMPOSE" \
  || fail 'HML Compose fresh/full guidance does not require force-recreate'

# Source the guarded entrypoint so the regression can replace only local
# inputs/state and fake Docker without exposing a lock-path override to operators.
source "$DEPLOY_SCRIPT"
export ENV_SOURCE_DIR LIVE_ENV_FILE LIVE_BASE_COMPOSE_FILE LIVE_HML_COMPOSE_FILE
export ARTIFACT_LOG TAG_STATE_FILE IMAGE_A IMAGE_B
export -f fake_error assert_private_snapshot install sleep render_effective_fixture docker
mkdir -p "$SNAPSHOT_PARENT"
chmod 700 "$SNAPSHOT_PARENT"

main_source="$(sed -n '/^main() {$/,/^}$/p' "$DEPLOY_SCRIPT")"
lock_line="$(grep -n '^  acquire_host_lock$' <<<"$main_source" | cut -d: -f1)"
capture_line="$(grep -n '^  capture_transition_inputs$' <<<"$main_source" | cut -d: -f1)"
render_line="$(grep -n '^  render_pinned_effective_compose$' <<<"$main_source" | cut -d: -f1)"
rollout_line="$(grep -n '^  ROLLOUT_STARTED=true$' <<<"$main_source" | cut -d: -f1)"
initializer_line="$(grep -nF \
  '"${COMPOSE[@]}" run --rm --no-deps outbound-attempt-keyring-init' \
  <<<"$main_source" | cut -d: -f1)"
backend_line="$(grep -nF \
  '"${COMPOSE[@]}" up -d --no-build --no-deps --force-recreate backend' \
  <<<"$main_source" | cut -d: -f1)"
backend_health_line="$(grep -n '^  wait_for_service backend true$' \
  <<<"$main_source" | cut -d: -f1)"
activated_line="$(grep -n '^  BACKEND_ACTIVATED=true$' \
  <<<"$main_source" | cut -d: -f1)"
frontend_line="$(grep -nF \
  '"${COMPOSE[@]}" up -d --no-build --no-deps frontend' \
  <<<"$main_source" | cut -d: -f1)"
[[ -n "$lock_line" && -n "$capture_line" && -n "$render_line" \
    && -n "$rollout_line" && -n "$initializer_line" && -n "$backend_line" \
    && -n "$backend_health_line" && -n "$activated_line" && -n "$frontend_line" \
    && 10#$lock_line -lt 10#$capture_line \
    && 10#$capture_line -lt 10#$render_line \
    && 10#$render_line -lt 10#$rollout_line \
    && 10#$rollout_line -lt 10#$initializer_line \
    && 10#$initializer_line -lt 10#$backend_line \
    && 10#$backend_line -lt 10#$backend_health_line \
    && 10#$backend_health_line -lt 10#$activated_line \
    && 10#$activated_line -lt 10#$frontend_line ]] \
  || fail 'HML order is not lock -> snapshots -> pinned model -> boundary -> initializer -> backend health -> frontend'

cleanup_source="$(sed -n '/^cleanup_on_exit() {$/,/^}$/p' "$DEPLOY_SCRIPT")"
grep -Fq '[[ "$ROLLOUT_STARTED" == true && "$BACKEND_ACTIVATED" == false ]]' \
  <<<"$cleanup_source" \
  && grep -Fq '"${COMPOSE[@]}" stop --timeout 60 proxy' <<<"$cleanup_source" \
  && grep -Fq '"${COMPOSE[@]}" stop --timeout 60 backend' <<<"$cleanup_source" \
  && grep -Fq 'cleanup_private_snapshots' <<<"$cleanup_source" \
  || fail 'HML entrypoint lacks fail-closed cleanup followed by private snapshot removal'

write_generation_a_sources
: >"$ARTIFACT_LOG"
FAKE_MUTATE_LIVE_INPUTS_ON_INFO=true \
  run_deploy "$SUCCESS_LOG" "$STATE_DIR" >"$OUTPUT_FILE" 2>&1

success_initializer_line="$(line_for 'run --rm --no-deps outbound-attempt-keyring-init' "$SUCCESS_LOG")"
success_backend_line="$(line_for 'up -d --no-build --no-deps --force-recreate backend' "$SUCCESS_LOG")"
success_frontend_line="$(line_for 'up -d --no-build --no-deps frontend' "$SUCCESS_LOG")"
success_proxy_line="$(line_for 'up -d --no-build --no-deps --force-recreate proxy' "$SUCCESS_LOG")"
[[ -n "$success_initializer_line" && -n "$success_backend_line" \
    && -n "$success_frontend_line" && -n "$success_proxy_line" \
    && 10#$success_initializer_line -lt 10#$success_backend_line \
    && 10#$success_backend_line -lt 10#$success_frontend_line \
    && 10#$success_frontend_line -lt 10#$success_proxy_line ]] \
  || fail 'fake-Docker success flow did not preserve initializer/backend/app/frontend/proxy order'
[[ "$(sort -u "$ARTIFACT_LOG" | grep -c '^effective_file=')" == 1 ]] \
  || fail 'the transition used more than one effective Compose artifact'
first_snapshot_dir="$(grep '^snapshot_dir=' "$ARTIFACT_LOG" | head -n 1 | cut -d= -f2-)"
first_effective_file="$(grep '^effective_file=' "$ARTIFACT_LOG" | head -n 1 | cut -d= -f2-)"
[[ -n "$first_snapshot_dir" && ! -e "$first_snapshot_dir" && ! -e "$first_effective_file" ]] \
  || fail 'private HML transition snapshots survived successful cleanup'
[[ "$(stat -c '%a' -- "$STATE_DIR")" == 700 \
    && "$(stat -c '%a' -- "$STATE_DIR/outbound-hmac-transition.lock")" == 600 ]] \
  || fail 'the persistent HML wrapper lock is not owner-only'
if grep -Fq "$LIVE_ENV_FILE" "$OUTPUT_FILE" \
    || grep -Fq "$IMAGE_A" "$OUTPUT_FILE" \
    || grep -Fq 'ENV_GENERATION' "$OUTPUT_FILE" \
    || grep -Fq 'compose-effective.snapshot' "$OUTPUT_FILE"; then
  fail 'the wrapper exposed protected snapshot/image/evidence details in operator output'
fi

write_generation_a_sources
: >"$ARTIFACT_LOG"
if FAKE_MUTATE_LIVE_INPUTS_ON_INFO=true \
    FAKE_FAIL_BACKEND_RECREATE=true \
    run_deploy "$FAILURE_LOG" "$STATE_DIR" >>"$OUTPUT_FILE" 2>&1; then
  fail 'HML entrypoint accepted a failed backend force-recreate'
fi
grep -Fq 'stop --timeout 60 proxy' "$FAILURE_LOG" \
  && grep -Fq 'stop --timeout 60 backend' "$FAILURE_LOG" \
  || fail 'activation failure did not stop stale HML proxy/backend traffic'
if grep -Fq 'up -d --no-build --no-deps frontend' "$FAILURE_LOG"; then
  fail 'HML entrypoint started frontend after backend activation failure'
fi
second_snapshot_dir="$(grep '^snapshot_dir=' "$ARTIFACT_LOG" | head -n 1 | cut -d= -f2-)"
[[ -n "$second_snapshot_dir" && "$second_snapshot_dir" != "$first_snapshot_dir" \
    && ! -e "$second_snapshot_dir" ]] \
  || fail 'private snapshots were reused or survived failure cleanup'

write_generation_a_sources
: >"$ARTIFACT_LOG"
if FAKE_MUTATE_LIVE_INPUTS_ON_INFO=true \
    FAKE_FAIL_INITIALIZER=true \
    run_deploy "$INITIALIZER_FAILURE_LOG" "$STATE_DIR" >>"$OUTPUT_FILE" 2>&1; then
  fail 'HML entrypoint accepted a failed keyring initializer'
fi
grep -Fq 'stop --timeout 60 proxy' "$INITIALIZER_FAILURE_LOG" \
  && grep -Fq 'stop --timeout 60 backend' "$INITIALIZER_FAILURE_LOG" \
  || fail 'pre-init fail-closed boundary did not stop stale traffic after initializer failure'
if grep -Fq 'up -d --no-build --no-deps --force-recreate backend' "$INITIALIZER_FAILURE_LOG"; then
  fail 'HML entrypoint attempted backend activation after initializer failure'
fi

write_generation_a_sources
: >"$ARTIFACT_LOG"
if FAKE_MUTATE_LIVE_INPUTS_ON_INFO=true \
    FAKE_HEALTH_NONE=true \
    run_deploy "$MISSING_HEALTH_LOG" "$STATE_DIR" >>"$OUTPUT_FILE" 2>&1; then
  fail 'HML entrypoint accepted a recreated backend without a HEALTHCHECK'
fi
grep -Fq 'stop --timeout 60 proxy' "$MISSING_HEALTH_LOG" \
  && grep -Fq 'stop --timeout 60 backend' "$MISSING_HEALTH_LOG" \
  || fail 'missing backend health did not stop stale HML proxy/backend traffic'
if grep -Fq 'up -d --no-build --no-deps frontend' "$MISSING_HEALTH_LOG"; then
  fail 'HML entrypoint started frontend without strict backend health'
fi

write_generation_a_sources
: >"$ACQUISITION_FAILURE_LOG"
if FAKE_MUTATE_DURING_ENV_CAPTURE=true \
    run_deploy "$ACQUISITION_FAILURE_LOG" "$STATE_DIR" >>"$OUTPUT_FILE" 2>&1; then
  fail 'HML entrypoint accepted an environment file mutated during acquisition'
fi
[[ ! -s "$ACQUISITION_FAILURE_LOG" ]] \
  || fail 'Docker was reached after an unstable environment acquisition'
grep -Fq 'changed while it was captured' "$OUTPUT_FILE" \
  || fail 'unstable acquisition did not fail with the bounded diagnostic'

write_generation_a_sources
RENAME_FAILURE_LOG="${TEST_ROOT}/rename-during-acquisition-docker.log"
if FAKE_RENAME_DURING_ENV_CAPTURE=true \
    run_deploy "$RENAME_FAILURE_LOG" "$STATE_DIR" >>"$OUTPUT_FILE" 2>&1; then
  fail 'HML entrypoint accepted a renamed environment path during acquisition'
fi
[[ ! -s "$RENAME_FAILURE_LOG" ]] \
  || fail 'rename swap reached Docker/lifecycle after an unstable acquisition'
grep -Fq 'input path changed while it was captured' "$OUTPUT_FILE" \
  || fail 'rename swap did not fail with the bounded path diagnostic'

write_generation_a_sources
SYMLINK_SWAP_FAILURE_LOG="${TEST_ROOT}/symlink-swap-during-acquisition-docker.log"
if FAKE_SYMLINK_DURING_ENV_CAPTURE=true \
    run_deploy "$SYMLINK_SWAP_FAILURE_LOG" "$STATE_DIR" >>"$OUTPUT_FILE" 2>&1; then
  fail 'HML entrypoint accepted a symbolic-link swap during acquisition'
fi
[[ ! -s "$SYMLINK_SWAP_FAILURE_LOG" ]] \
  || fail 'symbolic-link swap reached Docker/lifecycle after an unstable acquisition'
grep -Fq 'input path changed while it was captured' "$OUTPUT_FILE" \
  || fail 'symbolic-link swap did not fail with the bounded path diagnostic'

declare -a broken_boundary_filters=(
  '.services["outbound-attempt-keyring-init"].image = "different:mutable"'
  '.services["outbound-attempt-keyring-init"].user = "spring"'
  '.services["outbound-attempt-keyring-init"].entrypoint = ["/bin/true"]'
  '.services["outbound-attempt-keyring-init"].command = ["noop"]'
  '.services["outbound-attempt-keyring-init"].environment.EXTRA = "drift"'
  '.services["outbound-attempt-keyring-init"].network_mode = "bridge"'
  '.services["outbound-attempt-keyring-init"].restart = "always"'
  '.services["outbound-attempt-keyring-init"].read_only = false'
  '.services["outbound-attempt-keyring-init"].privileged = true'
  '.services["outbound-attempt-keyring-init"].pids_limit = 64'
  '.services["outbound-attempt-keyring-init"].networks = {default: {}}'
  '.services["outbound-attempt-keyring-init"].ports = [{target: 8080, published: "8080"}]'
  '.services["outbound-attempt-keyring-init"].tmpfs = []'
  '.services["outbound-attempt-keyring-init"].cap_drop = []'
  '.services["outbound-attempt-keyring-init"].cap_add = ["CHOWN", "DAC_READ_SEARCH", "SYS_ADMIN"]'
  '.services["outbound-attempt-keyring-init"].security_opt = []'
  '.services["outbound-attempt-keyring-init"].volumes[0].source = "/tmp/drift-source"'
  '.services["outbound-attempt-keyring-init"].volumes[0].target = "/wrong-source"'
  '.services["outbound-attempt-keyring-init"].volumes[0].read_only = false'
  '.services["outbound-attempt-keyring-init"].volumes[0].bind.create_host_path = true'
  '.services["outbound-attempt-keyring-init"].volumes[1].source = "/tmp/drift-approval"'
  '.services["outbound-attempt-keyring-init"].volumes[1].target = "/wrong-approval"'
  '.services["outbound-attempt-keyring-init"].volumes[1].read_only = false'
  '.services["outbound-attempt-keyring-init"].volumes[1].bind.create_host_path = true'
  '.services["outbound-attempt-keyring-init"].volumes[2].type = "bind"'
  '.services["outbound-attempt-keyring-init"].volumes[2].source = "wrong-volume"'
  '.services["outbound-attempt-keyring-init"].volumes[2].target = "/wrong-target"'
  '.services["outbound-attempt-keyring-init"].volumes[2].read_only = true'
  '.services["outbound-attempt-keyring-init"].volumes += [{type: "bind", source: "/tmp/extra", target: "/extra", read_only: true, bind: {create_host_path: false}}]'
  '.services.backend.volumes[0].type = "bind"'
  '.services.backend.volumes[0].source = "wrong-volume"'
  '.services.backend.volumes[0].target = "/wrong-target"'
  '.services.backend.volumes[0].read_only = false'
  '.services.backend.volumes += [{type: "volume", source: "hml-outbound-attempt-keyring", target: "/run/saas-secrets", read_only: true}]'
  '.services.backend.environment.CONVERSATION_OUTBOUND_ATTEMPT_HMAC_ACTIVE_KEY_ID = "bad/id"'
  '.services.backend.environment.CONVERSATION_OUTBOUND_ATTEMPT_HMAC_KEYRING_FILE = "/tmp/keyring.json"'
  '.services.backend.depends_on["outbound-attempt-keyring-init"].condition = "service_started"'
  '.services.backend.depends_on["outbound-attempt-keyring-init"].required = false'
  'del(.volumes["hml-outbound-attempt-keyring"])'
)
declare -a initializer_environment_keys=(
  OUTBOUND_HMAC_ACTIVE_KEY_ID
  OUTBOUND_HMAC_APPROVAL_DIRECTORY
  OUTBOUND_HMAC_APPROVAL_FILE
  OUTBOUND_HMAC_PENDING_FILE
  OUTBOUND_HMAC_SOURCE_FILE
  OUTBOUND_HMAC_SOURCE_PARENT
  OUTBOUND_HMAC_STATE_FILE
  OUTBOUND_HMAC_TARGET_FILE
  OUTBOUND_HMAC_TARGET_OWNER
)
for initializer_environment_key in "${initializer_environment_keys[@]}"; do
  broken_boundary_filters+=(
    ".services[\"outbound-attempt-keyring-init\"].environment[\"${initializer_environment_key}\"] = \"drift\""
  )
done

boundary_case=0
for broken_boundary_filter in "${broken_boundary_filters[@]}"; do
  (( boundary_case += 1 ))
  write_generation_a_sources
  boundary_log="${TEST_ROOT}/broken-boundary-${boundary_case}.docker.log"
  boundary_output="${TEST_ROOT}/broken-boundary-${boundary_case}.output.log"
  if FAKE_BROKEN_BOUNDARY_FILTER="$broken_boundary_filter" \
      run_deploy "$boundary_log" "$STATE_DIR" >"$boundary_output" 2>&1; then
    fail "HML entrypoint accepted broken effective boundary case ${boundary_case}"
  fi
  grep -Fq 'effective HML Compose model violates the outbound HMAC security boundary' \
    "$boundary_output" \
    || fail "broken boundary case ${boundary_case} did not use the bounded diagnostic"
  if grep -Eq '(^|[[:space:]])(run|up)([[:space:]]|$)' "$boundary_log" \
      || grep -Fq 'image inspect' "$boundary_log"; then
    fail "broken boundary case ${boundary_case} reached image pin or lifecycle/application commands"
  fi
done

write_generation_a_sources
LOCKED_STATE_DIR="${TEST_ROOT}/locked-state"
command install -d -m 700 -- "$LOCKED_STATE_DIR"
: >"$LOCKED_STATE_DIR/outbound-hmac-transition.lock"
chmod 600 "$LOCKED_STATE_DIR/outbound-hmac-transition.lock"
exec {held_lock_fd}<>"$LOCKED_STATE_DIR/outbound-hmac-transition.lock"
flock -n "$held_lock_fd" || fail 'test fixture could not acquire the competing host lock'
if run_deploy "$LOCKED_LOG" "$LOCKED_STATE_DIR" >>"$OUTPUT_FILE" 2>&1; then
  fail 'HML entrypoint accepted a concurrent wrapper execution'
fi
[[ ! -s "$LOCKED_LOG" ]] \
  || fail 'a rejected concurrent wrapper reached Docker'
grep -Fq 'another HML outbound HMAC transition is already running' "$OUTPUT_FILE" \
  || fail 'concurrent HML transition did not use the fixed bounded diagnostic'
exec {held_lock_fd}<&-

write_generation_a_sources
chmod 644 "$LIVE_ENV_FILE"
if run_deploy "${TEST_ROOT}/unsafe.log" "$STATE_DIR" >>"$OUTPUT_FILE" 2>&1; then
  fail 'HML entrypoint accepted a group/world-readable environment file'
fi
[[ ! -s "${TEST_ROOT}/unsafe.log" ]] \
  || fail 'Docker was reached with an unsafe environment source'

write_generation_a_sources
REGULAR_ENV_COPY="${TEST_ROOT}/regular-hml.env"
cp "$LIVE_ENV_FILE" "$REGULAR_ENV_COPY"
ENV_SYMLINK="${TEST_ROOT}/hml-link.env"
ln -s "$REGULAR_ENV_COPY" "$ENV_SYMLINK"
if run_deploy "${TEST_ROOT}/symlink.log" "$STATE_DIR" "$ENV_SYMLINK" >>"$OUTPUT_FILE" 2>&1; then
  fail 'HML entrypoint accepted a symbolic-link environment source'
fi
[[ ! -s "${TEST_ROOT}/symlink.log" ]] \
  || fail 'Docker was reached with a symbolic-link environment source'

printf 'deploy-hml-outbound-hmac-keyring-test: PASS\n'
