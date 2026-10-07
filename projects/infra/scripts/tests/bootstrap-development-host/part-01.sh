BOOTSTRAP="$REPOSITORY_ROOT/infra/scripts/bootstrap-development-host.sh"
PRODUCTION_BOOTSTRAP="$REPOSITORY_ROOT/infra/scripts/bootstrap-production-vps.sh"
DOCKER_ACCESS_HELPER="$REPOSITORY_ROOT/infra/scripts/lib/development-docker-access.sh"
HEALTH_CHECK="$REPOSITORY_ROOT/infra/scripts/health-check.sh"
KEYCLOAK_RECOVERY="$REPOSITORY_ROOT/infra/keycloak/bootstrap/migrate-persisted-volume.sh"
TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/saas-development-host-bootstrap-test.XXXXXXXX")"
HARNESS_BOOTSTRAP="$TEST_ROOT/bootstrap-development-host.instrumented.sh"
MOCK_BIN="$TEST_ROOT/bin"
MOCK_LOG="$TEST_ROOT/commands.log"
MEMBERSHIP_STATE="$TEST_ROOT/docker-membership"
OUTPUT_FILE="$TEST_ROOT/output.log"
FAKE_HOME="$TEST_ROOT/home/developer"
FAKE_SOCKET="$TEST_ROOT/docker.sock"
FAKE_LOCK_DIR="$TEST_ROOT/lock"
FAKE_LOCK_FILE="$FAKE_LOCK_DIR/bootstrap.lock"
RUNNER="$TEST_ROOT/run-bootstrap.sh"
HOST_PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

cleanup() {
  rm -rf -- "$TEST_ROOT"
}
trap cleanup EXIT INT TERM

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

assert_contains() {
  local file="$1"
  local expected="$2"
  local message="$3"
  grep -Fq -- "$expected" "$file" || fail "$message"
}

assert_no_mutation() {
  local message="$1"
  if grep -Eq '^(usermod|gpasswd)([[:space:]]|$)' "$MOCK_LOG"; then
    fail "$message"
  fi
}

assert_failed_without_mutation() {
  local label="$1"
  shift
  if run_bootstrap "$@"; then
    fail "$label unexpectedly succeeded"
  fi
  assert_no_mutation "$label reached a group mutation"
}

make_socket() {
  rm -f -- "$FAKE_SOCKET"
  : >"$FAKE_SOCKET"
  chmod 0660 "$FAKE_SOCKET"
}

reset_fixture() {
  local initial_membership="${1:-false}"
  rm -rf -- "$FAKE_LOCK_FILE"
  : >"$MOCK_LOG"
  : >"$OUTPUT_FILE"
  printf '%s\n' "$initial_membership" >"$MEMBERSHIP_STATE"
  make_socket
  export FAKE_DOCKER_CONTEXT=default
  export FAKE_DOCKER_ENDPOINT="unix://$FAKE_SOCKET"
  export FAKE_COMPOSE_EXIT=0
  export FAKE_DAEMON_EXIT=0
  export FAKE_FRESH_EXIT=0
  export FAKE_CONTINUE_EXIT=0
  export FAKE_USERMOD_APPLY=true
  export FAKE_USERMOD_EXIT=0
  export FAKE_SOCKET_UID=0
  export FAKE_SOCKET_GID=998
  export FAKE_SOCKET_MODE=660
  export FAKE_LOCK_UID=0
  export FAKE_LOCK_GID=0
  export FAKE_LOCK_MODE=755
  export FAKE_LOCK_FILE_UID=0
  export FAKE_LOCK_FILE_GID=0
  export FAKE_LOCK_FILE_MODE=600
  export FAKE_FLOCK_EXIT=0
  export FAKE_UID=1000
  export FAKE_GID=1000
  export SUDO_USER=developer
  export SUDO_UID=1000
  export SUDO_GID=1000
  unset DOCKER_HOST DOCKER_CONTEXT DOCKER_TLS_VERIFY DOCKER_CERT_PATH
}

run_bootstrap() {
  set +e
  BOOTSTRAP_CALLER_SECRET='must-not-cross-the-fresh-session-boundary' \
    bash "$RUNNER" "$@" >"$OUTPUT_FILE" 2>&1
  local status=$?
  set -e
  return "$status"
}

[[ -f "$BOOTSTRAP" ]] || fail "development host bootstrap is absent"
[[ -f "$PRODUCTION_BOOTSTRAP" ]] || fail "production bootstrap is absent"
[[ -f "$DOCKER_ACCESS_HELPER" ]] || fail "shared Docker access helper is absent"
[[ -f "$HEALTH_CHECK" ]] || fail "development health check is absent"
[[ -f "$KEYCLOAK_RECOVERY" ]] || fail "local Keycloak recovery is absent"
# A privileged script must remain interceptable by PATH in the hermetic harness.
# Abort before sourcing it if a future edit bypasses the fakes for mutating tools.
if grep -Eq '/(usr/)?sbin/(usermod|gpasswd|runuser)|/usr/bin/docker' "$BOOTSTRAP"; then
  fail "bootstrap hardcodes a privileged executable and cannot be tested hermetically"
fi

# The sandboxed test never creates or opens a live Unix daemon socket. An exact
# temporary copy replaces only Bash's non-injectable -S predicate with a fake
# predicate; the production artifact retains and is statically checked for -S.
[[ "$(grep -Fc '[[ -S "$DOCKER_SOCKET" ]]' "$BOOTSTRAP")" == 1 ]] \
  || fail "bootstrap must contain exactly one canonical Unix-socket type check"
cp -- "$BOOTSTRAP" "$HARNESS_BOOTSTRAP"
sed -i 's/\[\[ -S "\$DOCKER_SOCKET" \]\]/socket_is_unix "\$DOCKER_SOCKET"/' \
  "$HARNESS_BOOTSTRAP"
grep -Fq 'socket_is_unix "$DOCKER_SOCKET"' "$HARNESS_BOOTSTRAP" \
  || fail "could not instrument the temporary socket predicate"

mkdir -p "$MOCK_BIN" "$FAKE_HOME" "$FAKE_LOCK_DIR"
chmod 0700 "$FAKE_HOME"
chmod 0755 "$FAKE_LOCK_DIR"

cat >"$MOCK_BIN/getent" <<'MOCK_GETENT'
#!/usr/bin/env bash
set -Eeuo pipefail
case "${1:-}:${2:-}" in
  passwd:developer)
    printf 'developer:x:%s:%s:Developer:%s:/bin/bash\n' \
      "$FAKE_UID" "$FAKE_GID" "$FAKE_HOME"
    ;;
  passwd:root)
    printf 'root:x:0:0:root:/root:/bin/bash\n'
    ;;
  passwd:systemuser)
    printf 'systemuser:x:999:999:System:%s:/bin/bash\n' "$FAKE_HOME"
    ;;
  passwd:missing)
    exit 2
    ;;
  group:docker)
    if [[ "$(<"$MEMBERSHIP_STATE")" == true ]]; then
      printf 'docker:x:998:legacy,developer\n'
    else
      printf 'docker:x:998:legacy\n'
    fi
    ;;
  *)
    exit 2
    ;;
esac
MOCK_GETENT

cat >"$MOCK_BIN/id" <<'MOCK_ID'
#!/usr/bin/env bash
set -Eeuo pipefail
printf 'id' >>"$MOCK_LOG"
printf '\t%s' "$@" >>"$MOCK_LOG"
printf '\n' >>"$MOCK_LOG"
case "${1:-}:${2:-}" in
  -G:developer)
    if [[ "$(<"$MEMBERSHIP_STATE")" == true ]]; then
      printf '1000 27 998\n'
    else
      printf '1000 27\n'
    fi
    ;;
  *)
    exit 64
    ;;
esac
MOCK_ID

cat >"$MOCK_BIN/docker" <<'MOCK_DOCKER'
#!/usr/bin/env bash
set -Eeuo pipefail
printf 'docker' >>"$MOCK_LOG"
printf '\t%s' "$@" >>"$MOCK_LOG"
printf '\n' >>"$MOCK_LOG"
if [[ "${1:-}" == compose && "${2:-}" == version ]]; then
  exit "$FAKE_COMPOSE_EXIT"
fi
if [[ "${1:-}" == --host && "${3:-}" == info ]]; then
  [[ "${2:-}" == "$FAKE_DOCKER_ENDPOINT" ]] || exit 65
  exit "$FAKE_DAEMON_EXIT"
fi
exit 64
MOCK_DOCKER

cat >"$MOCK_BIN/stat" <<'MOCK_STAT'
#!/usr/bin/env bash
set -Eeuo pipefail
format=''
target=''
while (( $# > 0 )); do
  case "$1" in
    -c)
      format="$2"
      shift 2
      ;;
    --)
      shift
      target="${1:-}"
      shift || true
      ;;
    *)
      target="$1"
      shift
      ;;
  esac
done
case "$target:$format" in
  "$FAKE_SOCKET:%u:%g:%a")
    printf '%s:%s:%s\n' "$FAKE_SOCKET_UID" "$FAKE_SOCKET_GID" "$FAKE_SOCKET_MODE"
    ;;
  "$FAKE_LOCK_DIR:%u:%g:%a")
    printf '%s:%s:%s\n' "$FAKE_LOCK_UID" "$FAKE_LOCK_GID" "$FAKE_LOCK_MODE"
    ;;
  "$FAKE_LOCK_DIR:%u:%a")
    printf '%s:%s\n' "$FAKE_LOCK_UID" "$FAKE_LOCK_MODE"
    ;;
  "$FAKE_LOCK_FILE:%u:%g:%a")
    printf '%s:%s:%s\n' \
      "$FAKE_LOCK_FILE_UID" "$FAKE_LOCK_FILE_GID" "$FAKE_LOCK_FILE_MODE"
    ;;
  *:%u)
    printf '%s\n' "$FAKE_UID"
    ;;
  *)
    printf 'unexpected stat contract: target=%s format=%s\n' "$target" "$format" >&2
    exit 64
    ;;
esac
MOCK_STAT

cat >"$MOCK_BIN/usermod" <<'MOCK_USERMOD'
#!/usr/bin/env bash
set -Eeuo pipefail
printf 'usermod' >>"$MOCK_LOG"
printf '\t%s' "$@" >>"$MOCK_LOG"
printf '\n' >>"$MOCK_LOG"
[[ "$#" == 3 && "$1" == -aG && "$2" == docker && "$3" == developer ]] || exit 64
if [[ "$FAKE_USERMOD_APPLY" == true ]]; then
  printf 'true\n' >"$MEMBERSHIP_STATE"
fi
exit "$FAKE_USERMOD_EXIT"
MOCK_USERMOD

cat >"$MOCK_BIN/gpasswd" <<'MOCK_GPASSWD'
#!/usr/bin/env bash
set -Eeuo pipefail
printf 'gpasswd' >>"$MOCK_LOG"
printf '\t%s' "$@" >>"$MOCK_LOG"
printf '\n' >>"$MOCK_LOG"
[[ "$#" == 3 && "$1" == -d && "$2" == developer && "$3" == docker ]] || exit 64
printf 'false\n' >"$MEMBERSHIP_STATE"
MOCK_GPASSWD

cat >"$MOCK_BIN/runuser" <<'MOCK_RUNUSER'
#!/usr/bin/env bash
set -Eeuo pipefail
printf 'runuser' >>"$MOCK_LOG"
printf '\t%s' "$@" >>"$MOCK_LOG"
printf '\n' >>"$MOCK_LOG"

[[ "${1:-}" == -u && "${2:-}" == developer && "${3:-}" == -- && "${4:-}" == env \
    && "${5:-}" == -i ]] || exit 64
shift 5
while (( $# > 0 )) && [[ "$1" == *=* ]]; do
  case "$1" in
    HOME=*|USER=developer|LOGNAME=developer|SHELL=/bin/bash|PATH=*|DOCKER_HOST=*) ;;
    *) exit 65 ;;
  esac
  shift
done

if [[ "${1:-}" == "$MOCK_BIN/docker" && "${2:-}" == context && "${3:-}" == show ]]; then
  printf '%s\n' "$FAKE_DOCKER_CONTEXT"
  exit 0
fi
if [[ "${1:-}" == "$MOCK_BIN/docker" && "${2:-}" == context \
    && "${3:-}" == inspect ]]; then
  printf '%s\n' "$FAKE_DOCKER_ENDPOINT"
  exit 0
fi
if [[ "${1:-}" == "$MOCK_BIN/docker" && "${2:-}" == --host \
    && "${3:-}" == "$FAKE_DOCKER_ENDPOINT" && "${4:-}" == info ]]; then
  [[ "$(<"$MEMBERSHIP_STATE")" == true ]] || exit 77
  exit "$FAKE_FRESH_EXIT"
fi
case "${1:-}" in
  */start-dev-bot.sh|*/start-dev-dns-bot.sh|*/start-dev-bot-exposed-ngrok.sh)
    exit "$FAKE_CONTINUE_EXIT"
    ;;
esac
exit 64
MOCK_RUNUSER

cat >"$MOCK_BIN/flock" <<'MOCK_FLOCK'
#!/usr/bin/env bash
set -Eeuo pipefail
printf 'flock' >>"$MOCK_LOG"
printf '\t%s' "$@" >>"$MOCK_LOG"
printf '\n' >>"$MOCK_LOG"
exit "$FAKE_FLOCK_EXIT"
MOCK_FLOCK

chmod 0755 "$MOCK_BIN"/*

cat >"$RUNNER" <<'RUN_BOOTSTRAP'
#!/usr/bin/env bash
set -Eeuo pipefail
source "$HARNESS_BOOTSTRAP"

# The real executable always evaluates EUID. Only this unprivileged, temporary
# sourced harness replaces that one guard; every privileged tool remains fake.
require_root() { :; }
socket_is_unix() {
  [[ "${FAKE_SOCKET_KIND:-socket}" == socket && -e "$1" ]]
}
SYSTEM_PATH="$MOCK_BIN:$HOST_PATH"
REPOSITORY_ROOT="$SOURCE_REPOSITORY_ROOT"
DOCKER_SOCKET="$FAKE_SOCKET"
DOCKER_ENDPOINT="unix://$FAKE_SOCKET"
LOCK_FILE="$FAKE_LOCK_FILE"
main "$@"
RUN_BOOTSTRAP
chmod 0700 "$RUNNER"

export BOOTSTRAP HARNESS_BOOTSTRAP PRODUCTION_BOOTSTRAP MOCK_BIN MOCK_LOG MEMBERSHIP_STATE
export FAKE_HOME FAKE_SOCKET FAKE_LOCK_DIR FAKE_LOCK_FILE HOST_PATH
export SOURCE_REPOSITORY_ROOT="$REPOSITORY_ROOT"

grep -Fq 'LOCK_FILE="/run/saas-development-host-bootstrap.lock"' "$BOOTSTRAP" \
  || fail "development bootstrap lock must live directly under root-owned /run"
if grep -Fq 'LOCK_FILE="/run/lock/' "$BOOTSTRAP"; then
  fail "development bootstrap must not place its lock in shared sticky /run/lock"
fi

# Root guard is exercised directly without invoking main or any host tool.
: >"$MOCK_LOG"
if (
  source "$BOOTSTRAP"
  require_root 1000
) >"$OUTPUT_FILE" 2>&1; then
  fail "root guard accepted a non-root effective UID"
fi
assert_no_mutation "root guard invoked a group mutation"
(
  source "$BOOTSTRAP"
  require_root 0
) >"$OUTPUT_FILE" 2>&1 || fail "root guard rejected effective UID 0"

# CLI validation must precede all host mutation.
reset_fixture
assert_failed_without_mutation "missing arguments"
reset_fixture
assert_failed_without_mutation "missing developer value" --developer-user
reset_fixture
assert_failed_without_mutation "missing opt-in" --developer-user developer
reset_fixture
assert_failed_without_mutation "wrong opt-in" \
  --developer-user developer --docker-access rootless
reset_fixture
assert_failed_without_mutation "unknown option" \
  --developer-user developer --docker-access rootful-group --unexpected
reset_fixture
assert_failed_without_mutation "duplicate developer option" \
  --developer-user developer --developer-user developer --docker-access rootful-group

# Identity and sudo provenance are fail-closed before usermod.
for invalid_user in 'bad;name' missing root systemuser; do
  reset_fixture
  export SUDO_USER="$invalid_user"
  case "$invalid_user" in
    root) export SUDO_UID=0 SUDO_GID=0 ;;
    systemuser) export SUDO_UID=999 SUDO_GID=999 ;;
    *) export SUDO_UID=1000 SUDO_GID=1000 ;;
  esac
  assert_failed_without_mutation "invalid user $invalid_user" \
    --developer-user "$invalid_user" --docker-access rootful-group
done
reset_fixture
export SUDO_USER=another-user
assert_failed_without_mutation "SUDO_USER mismatch" \
  --developer-user developer --docker-access rootful-group
reset_fixture
export SUDO_UID=1001
assert_failed_without_mutation "SUDO_UID mismatch" \
  --developer-user developer --docker-access rootful-group

# Remote/ambient endpoints, unsafe sockets, absent Compose and unhealthy daemon
# all stop before a membership change.
reset_fixture
export DOCKER_HOST=tcp://127.0.0.1:2375
assert_failed_without_mutation "ambient remote endpoint" \
  --developer-user developer --docker-access rootful-group
reset_fixture
export FAKE_DOCKER_ENDPOINT=tcp://127.0.0.1:2375
assert_failed_without_mutation "context remote endpoint" \
  --developer-user developer --docker-access rootful-group
reset_fixture
rm -f -- "$FAKE_SOCKET"
assert_failed_without_mutation "missing Docker socket" \
  --developer-user developer --docker-access rootful-group
reset_fixture
rm -f -- "$FAKE_SOCKET"
ln -s -- "$TEST_ROOT/not-a-socket" "$FAKE_SOCKET"
assert_failed_without_mutation "symbolic-link Docker socket" \
  --developer-user developer --docker-access rootful-group
reset_fixture
export FAKE_SOCKET_UID=1000
assert_failed_without_mutation "wrong Docker socket owner" \
  --developer-user developer --docker-access rootful-group
reset_fixture
export FAKE_SOCKET_MODE=666
assert_failed_without_mutation "wrong Docker socket mode" \
  --developer-user developer --docker-access rootful-group
reset_fixture
export FAKE_COMPOSE_EXIT=1
assert_failed_without_mutation "Compose unavailable" \
  --developer-user developer --docker-access rootful-group
reset_fixture
export FAKE_DAEMON_EXIT=1
assert_failed_without_mutation "daemon unavailable" \
  --developer-user developer --docker-access rootful-group
