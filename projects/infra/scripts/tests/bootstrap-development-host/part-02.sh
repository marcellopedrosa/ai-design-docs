# The lock lives directly in root-owned /run. Shared or group-writable parents,
# hostile paths, unsafe metadata and a concurrent holder all fail before the
# root-equivalent Docker group mutation.
reset_fixture
export FAKE_LOCK_MODE=1777
assert_failed_without_mutation "world-writable lock parent" \
  --developer-user developer --docker-access rootful-group
reset_fixture
export FAKE_LOCK_MODE=775
assert_failed_without_mutation "group-writable lock parent" \
  --developer-user developer --docker-access rootful-group
reset_fixture
export FAKE_LOCK_UID=1000
assert_failed_without_mutation "wrong lock parent owner" \
  --developer-user developer --docker-access rootful-group
reset_fixture
export FAKE_LOCK_GID=1000
assert_failed_without_mutation "wrong lock parent group" \
  --developer-user developer --docker-access rootful-group
reset_fixture
ln -s -- "$TEST_ROOT/missing-lock-target" "$FAKE_LOCK_FILE"
assert_failed_without_mutation "symbolic-link lock file" \
  --developer-user developer --docker-access rootful-group
reset_fixture
mkdir -- "$FAKE_LOCK_FILE"
assert_failed_without_mutation "non-regular lock path" \
  --developer-user developer --docker-access rootful-group
reset_fixture
: >"$FAKE_LOCK_FILE"
export FAKE_LOCK_FILE_UID=1000
assert_failed_without_mutation "wrong lock file owner" \
  --developer-user developer --docker-access rootful-group
reset_fixture
: >"$FAKE_LOCK_FILE"
export FAKE_LOCK_FILE_GID=1000
assert_failed_without_mutation "wrong lock file group" \
  --developer-user developer --docker-access rootful-group
reset_fixture
: >"$FAKE_LOCK_FILE"
export FAKE_LOCK_FILE_MODE=620
assert_failed_without_mutation "unsafe lock file mode" \
  --developer-user developer --docker-access rootful-group
reset_fixture
export FAKE_FLOCK_EXIT=1
assert_failed_without_mutation "concurrent bootstrap lock" \
  --developer-user developer --docker-access rootful-group

# First execution is additive, preserves pre-existing groups and validates from
# a new runuser session after the exact membership change.
reset_fixture false
run_bootstrap --developer-user developer --docker-access rootful-group \
  || fail "authorized first bootstrap failed: $(<"$OUTPUT_FILE")"
[[ "$(<"$MEMBERSHIP_STATE")" == true ]] || fail "success did not persist membership"
[[ "$(stat -c '%a' -- "$FAKE_LOCK_FILE")" == 600 ]] \
  || fail "new bootstrap lock was not created with mode 0600"
[[ "$(grep -Fc $'usermod\t-aG\tdocker\tdeveloper' "$MOCK_LOG")" == 1 ]] \
  || fail "success did not use exactly one additive usermod invocation"
if grep -Eq '^usermod[[:space:]]+-G([[:space:]]|$)' "$MOCK_LOG"; then
  fail "success replaced supplementary groups instead of preserving them"
fi
if grep -Eq '^gpasswd([[:space:]]|$)' "$MOCK_LOG"; then
  fail "success unexpectedly rolled back membership"
fi
usermod_line="$(grep -nF $'usermod\t-aG\tdocker\tdeveloper' "$MOCK_LOG" | cut -d: -f1)"
fresh_line="$(grep -nE '^runuser.*--host.*info([[:space:]]|$)' "$MOCK_LOG" | tail -1 | cut -d: -f1)"
[[ -n "$fresh_line" && "$usermod_line" -lt "$fresh_line" ]] \
  || fail "fresh-session docker info did not occur after usermod"
assert_contains "$MOCK_LOG" $'id\t-G\tdeveloper' \
  "success did not verify effective numeric supplementary groups"
(( $(grep -Fc $'id\t-G\tdeveloper' "$MOCK_LOG") >= 2 )) \
  || fail "success did not re-read membership after usermod"

# Reconciliation is idempotent but still proves Docker access in a new process.
reset_fixture true
run_bootstrap --developer-user developer --docker-access rootful-group \
  || fail "idempotent bootstrap failed: $(<"$OUTPUT_FILE")"
assert_no_mutation "idempotent bootstrap changed membership"
grep -Eq '^runuser.*--host.*info([[:space:]]|$)' "$MOCK_LOG" \
  || fail "idempotent bootstrap skipped fresh-session validation"

# A failed fresh session compensates only the association created now.
reset_fixture false
export FAKE_FRESH_EXIT=1
if run_bootstrap --developer-user developer --docker-access rootful-group; then
  fail "fresh-session failure unexpectedly succeeded"
fi
[[ "$(<"$MEMBERSHIP_STATE")" == false ]] || fail "rollback left the new membership active"
[[ "$(grep -Fc $'usermod\t-aG\tdocker\tdeveloper' "$MOCK_LOG")" == 1 ]] \
  || fail "rollback scenario did not create exactly one association"
[[ "$(grep -Fc $'gpasswd\t-d\tdeveloper\tdocker' "$MOCK_LOG")" == 1 ]] \
  || fail "rollback did not remove exactly the association created now"
rollback_line="$(grep -nF $'gpasswd\t-d\tdeveloper\tdocker' "$MOCK_LOG" | cut -d: -f1)"
failed_fresh_line="$(grep -nE '^runuser.*--host.*info([[:space:]]|$)' "$MOCK_LOG" | tail -1 | cut -d: -f1)"
[[ -n "$failed_fresh_line" && "$failed_fresh_line" -lt "$rollback_line" ]] \
  || fail "rollback did not happen after the failed fresh-session validation"

# A mutating tool may report failure after changing NSS. The bootstrap re-reads
# membership and compensates that partial application instead of leaving an
# unverified root-equivalent grant behind.
reset_fixture false
export FAKE_USERMOD_EXIT=1
if run_bootstrap --developer-user developer --docker-access rootful-group; then
  fail "partially applied usermod failure unexpectedly succeeded"
fi
[[ "$(<"$MEMBERSHIP_STATE")" == false ]] \
  || fail "partially applied usermod failure left membership active"
[[ "$(grep -Fc $'usermod\t-aG\tdocker\tdeveloper' "$MOCK_LOG")" == 1 ]] \
  || fail "partial usermod scenario did not invoke the additive mutation once"
[[ "$(grep -Fc $'gpasswd\t-d\tdeveloper\tdocker' "$MOCK_LOG")" == 1 ]] \
  || fail "partial usermod scenario did not compensate the observed association"

# A pre-existing association is never removed when its fresh-session check
# fails; it was not created by this transaction.
reset_fixture true
export FAKE_FRESH_EXIT=1
if run_bootstrap --developer-user developer --docker-access rootful-group; then
  fail "existing-membership fresh-session failure unexpectedly succeeded"
fi
assert_no_mutation "fresh-session failure removed a pre-existing membership"
[[ "$(<"$MEMBERSHIP_STATE")" == true ]] \
  || fail "fresh-session failure changed pre-existing membership state"

# Continue accepts only the three repository entrypoints and crosses the
# boundary through env -i/runuser; arbitrary caller state is not serialized.
reset_fixture true
assert_failed_without_mutation "non-allowlisted continuation" \
  --developer-user developer --docker-access rootful-group --continue ../../evil
for continue_target in start-dev-bot start-dev-dns-bot start-dev-bot-exposed-ngrok; do
  reset_fixture true
  run_bootstrap --developer-user developer --docker-access rootful-group \
    --continue "$continue_target" \
    || fail "allowlisted continuation failed: $continue_target: $(<"$OUTPUT_FILE")"
  grep -Eq "^runuser.*env[[:space:]]+-i.*DOCKER_HOST=.*${continue_target}\.sh([[:space:]]|$)" \
    "$MOCK_LOG" || fail "continuation did not use the sanitized fresh session: $continue_target"
  if grep -Fq 'must-not-cross-the-fresh-session-boundary' "$MOCK_LOG" \
      || grep -Fq 'must-not-cross-the-fresh-session-boundary' "$OUTPUT_FILE"; then
    fail "continuation exposed arbitrary caller environment: $continue_target"
  fi
done

# The existing PRD bootstrap is never executed here. Its static order remains
# association first, fresh-session proof second.
production_usermod_line="$(grep -nF 'usermod -aG docker "$DEPLOY_USER"' \
  "$PRODUCTION_BOOTSTRAP" | head -1 | cut -d: -f1)"
production_runuser_line="$(grep -nF 'runuser -u "$DEPLOY_USER" -- docker info' \
  "$PRODUCTION_BOOTSTRAP" | head -1 | cut -d: -f1)"
[[ -n "$production_usermod_line" && -n "$production_runuser_line" \
    && "$production_usermod_line" -lt "$production_runuser_line" ]] \
  || fail "production bootstrap no longer associates before fresh-session Docker validation"

grep -Fq 'if [[ "${BASH_SOURCE[0]}" == "$0" ]]' "$BOOTSTRAP" \
  || fail "development bootstrap lost its source-safe main guard"
grep -Fq '[[ ! -L "$DOCKER_SOCKET" ]]' "$BOOTSTRAP" \
  || fail "development bootstrap lost its socket symlink guard"
grep -Fq "stat -c '%u:%g:%a' -- \"\$DOCKER_SOCKET\"" "$BOOTSTRAP" \
  || fail "development bootstrap lost exact socket ownership/mode validation"
if grep -Eq 'chmod[[:space:]]+0?666|setfacl|sudo[[:space:]]+(-E[[:space:]]+)?docker' "$BOOTSTRAP"; then
  fail "development bootstrap contains a prohibited Docker access shortcut"
fi

# Every Docker path governed by the local-stack bootstrap must remain direct.
# DockerHub publishing is a separate lifecycle and is intentionally not part of
# this host-initialization contract.
for governed_path in \
    "$REPOSITORY_ROOT/start-dev-bot.sh" \
    "$REPOSITORY_ROOT/start-dev-dns-bot.sh" \
    "$REPOSITORY_ROOT/start-dev-bot-exposed-ngrok.sh" \
    "$REPOSITORY_ROOT/stop-dev-bot.sh" \
    "$REPOSITORY_ROOT/reset-dev-bot.sh" \
    "$HEALTH_CHECK" \
    "$KEYCLOAK_RECOVERY"; do
  inspected_path="$governed_path"
  if [[ "$governed_path" == "$REPOSITORY_ROOT/start-dev-bot.sh" ]]; then
    inspected_path="$TEST_ROOT/start-dev-bot-source.sh"
    cat "$REPOSITORY_ROOT/infra/scripts/lib/start-dev-bot/"part-*.sh \
      > "$inspected_path"
  fi
  if grep -Eq 'sudo[[:space:]]+(-E[[:space:]]+)?docker|sudo[[:space:]]+[^[:space:]]*[[:space:]]+docker[[:space:]]+compose' \
      "$inspected_path"; then
    fail "governed local Docker path contains a sudo fallback: $governed_path"
  fi
  grep -Fq 'development-docker-access.sh' "$inspected_path" \
    || fail "governed local Docker path does not source the shared preflight: $governed_path"
  grep -Fq 'require_direct_development_docker_access' "$inspected_path" \
    || fail "governed local Docker path does not invoke the shared preflight: $governed_path"
done

recovery_preflight_line="$(grep -nF 'require_direct_development_docker_access "$PROJECT_DIR"' \
  "$KEYCLOAK_RECOVERY" | cut -d: -f1)"
recovery_config_line="$(grep -nF 'resolve_managed_realm_allowlist' "$KEYCLOAK_RECOVERY" \
  | tail -1 | cut -d: -f1)"
[[ -n "$recovery_preflight_line" && -n "$recovery_config_line" \
    && "$recovery_preflight_line" -lt "$recovery_config_line" ]] \
  || fail "Keycloak recovery must preflight direct Docker before reading managed-realm configuration"
if grep -Eq '\(\((PASS|FAIL|WARN)\+\+\)\)' "$HEALTH_CHECK"; then
  fail "health-check counters can abort on their first post-increment under set -e"
fi
for counter_name in PASS FAIL WARN; do
  expected_counter_line="${counter_name}=\$((${counter_name} + 1))"
  grep -Fq "$expected_counter_line" "$HEALTH_CHECK" \
    || fail "health-check does not update $counter_name with a set -e-safe assignment"
done

# The failing-preflight branch exercises check_fail with FAIL=0. Reaching the
# explicit abort message proves the counter update itself did not trigger set -e.
reset_fixture
set +e
PATH="$MOCK_BIN:$HOST_PATH" bash "$HEALTH_CHECK" >"$OUTPUT_FILE" 2>&1
health_check_status=$?
set -e
[[ "$health_check_status" -eq 1 ]] \
  || fail "health-check direct-Docker preflight must fail with status 1 in the hermetic negative"
assert_contains "$OUTPUT_FILE" "Prepare the host before starting the stack. Aborting." \
  "health-check aborted inside its first failure counter under set -e"
assert_no_mutation "health-check preflight attempted a host group mutation"

printf 'Development host bootstrap hermetic test passed.\n'
