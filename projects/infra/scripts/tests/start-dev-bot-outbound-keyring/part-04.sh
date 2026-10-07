run_pre_cutover_failure_case \
    backend-build FAIL_BACKEND_BUILD \
    'Backend image preparation failed before cutover; the existing DEV application was preserved.'
run_pre_cutover_failure_case \
    base-services FAIL_BASE_PREPARE \
    'DEV base services did not become ready before cutover; the existing application was preserved.'
run_pre_cutover_failure_case \
    postgres-readiness FAIL_POSTGRES_WAIT \
    'DEV PostgreSQL preparation failed before cutover; the existing application was preserved.'
run_pre_cutover_failure_case \
    postgres-app-credential FAIL_POSTGRES_APP_CREDENTIAL \
    'DEV PostgreSQL preparation failed before cutover; the existing application was preserved.'
run_pre_cutover_failure_case \
    postgres-keycloak-credential FAIL_POSTGRES_KEYCLOAK_CREDENTIAL \
    'DEV PostgreSQL preparation failed before cutover; the existing application was preserved.'
run_pre_cutover_failure_case \
    tenant-database FAIL_TENANT_DB_PREPARE \
    'DEV PostgreSQL preparation failed before cutover; the existing application was preserved.'
run_pre_cutover_failure_case \
    redis-credential FAIL_REDIS_CREDENTIAL \
    'Redis credentials differ from the desired DEV configuration; the existing application was preserved and an explicit credential lifecycle is required.'
run_pre_cutover_failure_case \
    keycloak-service FAIL_KEYCLOAK_PREPARE \
    'Keycloak did not become ready before cutover; the existing application was preserved.'
run_pre_cutover_failure_case \
    keycloak-identity FAIL_KEYCLOAK_PREFLIGHT \
    'Keycloak provisioning identity preflight failed before cutover; the existing DEV application was preserved.'

rm -f "$OUTBOUND_COMMIT_RECEIPT_FILE"
reset_audit_transition_case
printf '%s\n' running > "$TRANSITION_BACKEND_STATE_FILE"
if (
    cd "$FIXTURE_DIR"
    PATH="$TRANSITION_FAKE_BIN_DIR:$PATH" \
    TRANSITION_FAKE_DOCKER_LOG="$TRANSITION_FAKE_DOCKER_LOG" \
    EXPECTED_OUTBOUND_ACTIVE="$OUTBOUND_KEY_ID" \
    FAIL_FRONTEND_STOP_EFFECT=1 \
    NGROK_AUTHTOKEN=synthetic-local-token \
    APP_BASE_URL=https://synthetic.invalid \
    ./start-dev-bot.sh
) >> "$OUTPUT_FILE" 2>&1; then
    fail "bootstrap accepted a frontend that remained open at the commit gate"
fi
grep -Fq 'Frontend remained running before conversation audit activation completed.' \
    "$OUTPUT_FILE" \
    || fail "ineffective frontend stop did not emit its explicit diagnosis"
if grep -Fq ' run --rm --no-deps outbound-attempt-keyring-init' \
    "$TRANSITION_EVENT_LOG"; then
    fail "ineffective frontend stop crossed the outbound keyring boundary"
fi
assert_audit_gate_closed "ineffective frontend stop"

rm -f "$OUTBOUND_COMMIT_RECEIPT_FILE"
reset_audit_transition_case
printf '%s\n' running > "$TRANSITION_BACKEND_STATE_FILE"
if (
    cd "$FIXTURE_DIR"
    PATH="$TRANSITION_FAKE_BIN_DIR:$PATH" \
    TRANSITION_FAKE_DOCKER_LOG="$TRANSITION_FAKE_DOCKER_LOG" \
    EXPECTED_OUTBOUND_ACTIVE="$OUTBOUND_KEY_ID" \
    FAIL_OUTBOUND_INIT=1 \
    NGROK_AUTHTOKEN=synthetic-local-token \
    APP_BASE_URL=https://synthetic.invalid \
    ./start-dev-bot.sh
) >> "$OUTPUT_FILE" 2>&1; then
    fail "bootstrap accepted a failed outbound keyring commit"
fi
grep -Fq 'The outbound keyring could not be installed after the DEV cutover started.' \
    "$OUTPUT_FILE" \
    || fail "failed outbound keyring commit did not emit its explicit diagnosis"
[ "$(<"$TRANSITION_FRONTEND_STATE_FILE")" = stopped ] \
    || fail "failed outbound keyring commit reopened the frontend gate"
[ "$(<"$TRANSITION_BACKEND_STATE_FILE")" = running ] \
    || fail "failed outbound keyring commit did not leave a safely closed backend running"
if grep -Fq ' up -d --no-build --no-deps --force-recreate backend' \
    "$TRANSITION_EVENT_LOG"; then
    fail "failed outbound keyring commit attempted the backend cutover"
fi
[ ! -e "$OUTBOUND_COMMIT_RECEIPT_FILE" ] \
    || fail "failed outbound keyring commit emitted a commit receipt"
assert_audit_gate_closed "failed outbound keyring commit"

rm -f "$OUTBOUND_COMMIT_RECEIPT_FILE"
reset_audit_transition_case
printf '%s\n' running > "$TRANSITION_BACKEND_STATE_FILE"
if (
    cd "$FIXTURE_DIR"
    PATH="$TRANSITION_FAKE_BIN_DIR:$PATH" \
    TRANSITION_FAKE_DOCKER_LOG="$TRANSITION_FAKE_DOCKER_LOG" \
    EXPECTED_OUTBOUND_ACTIVE="$OUTBOUND_KEY_ID" \
    FAIL_COMPOSE_UP=1 \
    NGROK_AUTHTOKEN=synthetic-local-token \
    APP_BASE_URL=https://synthetic.invalid \
    ./start-dev-bot.sh
) >> "$OUTPUT_FILE" 2>&1; then
    fail "bootstrap accepted a failed DEV backend cutover"
fi
grep -Fq 'Docker Compose did not complete the DEV backend cutover.' "$OUTPUT_FILE" \
    || fail "failed backend cutover did not emit its explicit diagnosis"
[ ! -e "$OUTBOUND_COMMIT_RECEIPT_FILE" ] \
    || fail "failed Compose startup emitted an outbound commit receipt"
assert_audit_gate_closed "failed backend cutover"

reset_audit_transition_case
if (
    cd "$FIXTURE_DIR"
    PATH="$TRANSITION_FAKE_BIN_DIR:$PATH" \
    TRANSITION_FAKE_DOCKER_LOG="$TRANSITION_FAKE_DOCKER_LOG" \
    EXPECTED_OUTBOUND_ACTIVE="$OUTBOUND_KEY_ID" \
    FAIL_BACKEND_READINESS=1 \
    NGROK_AUTHTOKEN=synthetic-local-token \
    APP_BASE_URL=https://synthetic.invalid \
    ./start-dev-bot.sh
) >> "$OUTPUT_FILE" 2>&1; then
    fail "bootstrap accepted a backend that never became ready"
fi
grep -Fq 'Backend did not become ready within 300 seconds.' "$OUTPUT_FILE" \
    || fail "backend readiness timeout did not emit its explicit diagnosis"
[ ! -e "$OUTBOUND_COMMIT_RECEIPT_FILE" ] \
    || fail "unready backend emitted an outbound commit receipt"
assert_audit_gate_closed "unready backend after cutover"
grep -Fq 'ps -a outbound-attempt-keyring-init keycloak keycloak-provisioning-init backend ngrok-bot' \
    "$TRANSITION_FAKE_DOCKER_LOG" \
    || fail "startup failure path did not inspect critical service states"
grep -Fq 'logs --no-color --tail 100 outbound-attempt-keyring-init keycloak keycloak-provisioning-init backend' \
    "$TRANSITION_FAKE_DOCKER_LOG" \
    || fail "startup failure path did not collect bounded critical logs"

reset_audit_transition_case
if (
    cd "$FIXTURE_DIR"
    PATH="$TRANSITION_FAKE_BIN_DIR:$PATH" \
    TRANSITION_FAKE_DOCKER_LOG="$TRANSITION_FAKE_DOCKER_LOG" \
    EXPECTED_OUTBOUND_ACTIVE="$OUTBOUND_KEY_ID" \
    FAIL_NGROK_UP=1 \
    NGROK_AUTHTOKEN=synthetic-local-token \
    APP_BASE_URL=https://synthetic.invalid \
    ./start-dev-bot.sh
) >> "$OUTPUT_FILE" 2>&1; then
    fail "bootstrap accepted a failed ngrok verify transition"
fi
grep -Fq 'Ngrok did not start after the DEV backend became ready.' "$OUTPUT_FILE" \
    || fail "failed ngrok start did not emit its explicit diagnosis"
[ ! -e "$OUTBOUND_COMMIT_RECEIPT_FILE" ] \
    || fail "failed ngrok start emitted an outbound commit receipt"
assert_audit_gate_closed "failed ngrok start"

AUDIT_GATE_CASE_OUTPUT="$FIXTURE_DIR/audit-gate-case-output.log"
reset_audit_transition_case
if (
    cd "$FIXTURE_DIR"
    PATH="$TRANSITION_FAKE_BIN_DIR:$PATH" \
    TRANSITION_FAKE_DOCKER_LOG="$TRANSITION_FAKE_DOCKER_LOG" \
    EXPECTED_OUTBOUND_ACTIVE="$OUTBOUND_KEY_ID" \
    CHECK_OUTBOUND_STAGE_LOCK_INHERITANCE=1 \
    FAIL_AUDIT_ACTIVATOR=1 \
    NGROK_AUTHTOKEN=synthetic-local-token \
    APP_BASE_URL=https://synthetic.invalid \
    ./start-dev-bot.sh
) > "$AUDIT_GATE_CASE_OUTPUT" 2>&1; then
    fail "bootstrap accepted a failed conversation audit activator"
else
    audit_activator_status=$?
fi
[ "$audit_activator_status" = 47 ] \
    || fail "bootstrap did not preserve the conversation audit activator exit status"
assert_audit_gate_closed "failed conversation audit activation"
grep -Fq 'Local conversation audit activation did not complete' "$AUDIT_GATE_CASE_OUTPUT" \
    || fail "failed conversation audit activation did not emit its explicit diagnosis"
[ ! -e "$OUTBOUND_COMMIT_RECEIPT_FILE" ] \
    || fail "failed conversation audit activation emitted an outbound commit receipt"

reset_audit_transition_case
if (
    cd "$FIXTURE_DIR"
    PATH="$TRANSITION_FAKE_BIN_DIR:$PATH" \
    TRANSITION_FAKE_DOCKER_LOG="$TRANSITION_FAKE_DOCKER_LOG" \
    EXPECTED_OUTBOUND_ACTIVE="$OUTBOUND_KEY_ID" \
    DIVERGE_AUDIT_RUNTIME_POSTCONDITION=1 \
    NGROK_AUTHTOKEN=synthetic-local-token \
    APP_BASE_URL=https://synthetic.invalid \
    ./start-dev-bot.sh
) > "$AUDIT_GATE_CASE_OUTPUT" 2>&1; then
    fail "bootstrap accepted a divergent conversation audit runtime postcondition"
fi
assert_audit_gate_closed "divergent conversation audit runtime postcondition"
grep -Fq 'exact promoted runtime postcondition' "$AUDIT_GATE_CASE_OUTPUT" \
    || fail "divergent conversation audit postcondition did not emit its explicit diagnosis"
[ ! -e "$OUTBOUND_COMMIT_RECEIPT_FILE" ] \
    || fail "divergent conversation audit postcondition emitted an outbound commit receipt"

reset_audit_transition_case
if (
    cd "$FIXTURE_DIR"
    PATH="$TRANSITION_FAKE_BIN_DIR:$PATH" \
    TRANSITION_FAKE_DOCKER_LOG="$TRANSITION_FAKE_DOCKER_LOG" \
    EXPECTED_OUTBOUND_ACTIVE="$OUTBOUND_KEY_ID" \
    FAIL_RESOLVED_COMPOSE_AUDIT=1 \
    NGROK_AUTHTOKEN=synthetic-local-token \
    APP_BASE_URL=https://synthetic.invalid \
    ./start-dev-bot.sh
) > "$AUDIT_GATE_CASE_OUTPUT" 2>&1; then
    fail "bootstrap accepted a divergent resolved Compose audit environment"
fi
assert_audit_gate_closed "divergent resolved Compose audit environment"
grep -Fq 'Docker Compose did not resolve the promoted conversation audit postcondition' \
    "$AUDIT_GATE_CASE_OUTPUT" \
    || fail "resolved Compose divergence did not emit its explicit diagnosis"

reset_audit_transition_case
if (
    cd "$FIXTURE_DIR"
    PATH="$TRANSITION_FAKE_BIN_DIR:$PATH" \
    TRANSITION_FAKE_DOCKER_LOG="$TRANSITION_FAKE_DOCKER_LOG" \
    EXPECTED_OUTBOUND_ACTIVE="$OUTBOUND_KEY_ID" \
    FAIL_EFFECTIVE_BACKEND_AUDIT=1 \
    NGROK_AUTHTOKEN=synthetic-local-token \
    APP_BASE_URL=https://synthetic.invalid \
    ./start-dev-bot.sh
) > "$AUDIT_GATE_CASE_OUTPUT" 2>&1; then
    fail "bootstrap accepted a backend with a divergent effective audit environment"
fi
assert_audit_gate_closed "divergent effective backend audit environment"
grep -Fq 'running backend does not have the promoted conversation audit postcondition' \
    "$AUDIT_GATE_CASE_OUTPUT" \
    || fail "effective backend divergence did not emit its explicit diagnosis"

NGROK_CASE_OUTPUT="$FIXTURE_DIR/ngrok-case-output.log"
reset_audit_transition_case
if (
    cd "$FIXTURE_DIR"
    PATH="$TRANSITION_FAKE_BIN_DIR:$PATH" \
    TRANSITION_FAKE_DOCKER_LOG="$TRANSITION_FAKE_DOCKER_LOG" \
    EXPECTED_OUTBOUND_ACTIVE="$OUTBOUND_KEY_ID" \
    FAIL_NGROK_DISCOVERY=1 \
    NGROK_AUTHTOKEN=synthetic-local-token \
    APP_BASE_URL=https://synthetic.invalid \
    ./start-dev-bot.sh
) > "$NGROK_CASE_OUTPUT" 2>&1; then
    fail "bootstrap accepted missing ngrok tunnel discovery"
fi
grep -Fq 'Could not get public URL from Ngrok' "$NGROK_CASE_OUTPUT" \
    || fail "missing ngrok discovery did not emit an explicit diagnosis"
if grep -Fq 'Hybrid Local Mode is Running' "$NGROK_CASE_OUTPUT"; then
    fail "bootstrap announced ready without an ngrok tunnel"
fi
assert_audit_gate_closed "missing ngrok tunnel discovery"

reset_audit_transition_case
if (
    cd "$FIXTURE_DIR"
    PATH="$TRANSITION_FAKE_BIN_DIR:$PATH" \
    TRANSITION_FAKE_DOCKER_LOG="$TRANSITION_FAKE_DOCKER_LOG" \
    EXPECTED_OUTBOUND_ACTIVE="$OUTBOUND_KEY_ID" \
    MOCK_NGROK_PUBLIC_URL=https://unexpected.invalid \
    NGROK_AUTHTOKEN=synthetic-local-token \
    APP_BASE_URL=https://synthetic.invalid \
    ./start-dev-bot.sh
) > "$NGROK_CASE_OUTPUT" 2>&1; then
    fail "bootstrap accepted an ngrok URL different from APP_BASE_URL"
fi
grep -Fq 'Ngrok public URL does not match APP_BASE_URL' "$NGROK_CASE_OUTPUT" \
    || fail "ngrok URL mismatch did not emit an explicit diagnosis"
if grep -Fq 'Hybrid Local Mode is Running' "$NGROK_CASE_OUTPUT"; then
    fail "bootstrap announced ready after an ngrok URL mismatch"
fi
assert_audit_gate_closed "ngrok URL mismatch"

reset_audit_transition_case
if (
    cd "$FIXTURE_DIR"
    PATH="$TRANSITION_FAKE_BIN_DIR:$PATH" \
    TRANSITION_FAKE_DOCKER_LOG="$TRANSITION_FAKE_DOCKER_LOG" \
    EXPECTED_OUTBOUND_ACTIVE="$OUTBOUND_KEY_ID" \
    FAIL_PUBLIC_READINESS=1 \
    NGROK_AUTHTOKEN=synthetic-local-token \
    APP_BASE_URL=https://synthetic.invalid \
    ./start-dev-bot.sh
) > "$NGROK_CASE_OUTPUT" 2>&1; then
    fail "bootstrap accepted an unreachable public backend ingress"
fi
grep -Fq 'Public backend readiness through ngrok was not confirmed' "$NGROK_CASE_OUTPUT" \
    || fail "public ingress failure did not emit an explicit diagnosis"
if grep -Fq 'Hybrid Local Mode is Running' "$NGROK_CASE_OUTPUT"; then
    fail "bootstrap announced ready without public ingress readiness"
fi
assert_audit_gate_closed "public backend readiness failure"

reset_audit_transition_case
if (
    cd "$FIXTURE_DIR"
    PATH="$TRANSITION_FAKE_BIN_DIR:$PATH" \
    TRANSITION_FAKE_DOCKER_LOG="$TRANSITION_FAKE_DOCKER_LOG" \
    EXPECTED_OUTBOUND_ACTIVE="$OUTBOUND_KEY_ID" \
    FAIL_FRONTEND_START=1 \
    NGROK_AUTHTOKEN=synthetic-local-token \
    APP_BASE_URL=https://synthetic.invalid \
    ./start-dev-bot.sh
) > "$AUDIT_GATE_CASE_OUTPUT" 2>&1; then
    fail "bootstrap accepted a failed post-activation frontend start"
fi
grep -Fq 'Frontend did not start after conversation audit activation completed' \
    "$AUDIT_GATE_CASE_OUTPUT" \
    || fail "frontend start failure did not emit its explicit diagnosis"
assert_audit_gate_closed "failed post-activation frontend start" true

reset_audit_transition_case
if (
    cd "$FIXTURE_DIR"
    PATH="$TRANSITION_FAKE_BIN_DIR:$PATH" \
    TRANSITION_FAKE_DOCKER_LOG="$TRANSITION_FAKE_DOCKER_LOG" \
    EXPECTED_OUTBOUND_ACTIVE="$OUTBOUND_KEY_ID" \
    FAIL_EFFECTIVE_BACKEND_AUDIT=1 \
    FAIL_AUDIT_CLOSE=1 \
    NGROK_AUTHTOKEN=synthetic-local-token \
    APP_BASE_URL=https://synthetic.invalid \
    ./start-dev-bot.sh
) > "$AUDIT_GATE_CASE_OUTPUT" 2>&1; then
    fail "bootstrap accepted a failed close-only audit transition"
fi
assert_audit_gate_closed "failed close-only audit transition"
[ "$(<"$TRANSITION_BACKEND_STATE_FILE")" = stopped ] \
    || fail "failed close-only transition did not stop the backend"
grep -Fq ' stop --timeout 30 backend' "$TRANSITION_EVENT_LOG" \
    || fail "failed close-only transition did not invoke the backend fail-safe stop"
grep -Fq 'Stopping the backend because conversation audit closure was not proven' \
    "$AUDIT_GATE_CASE_OUTPUT" \
    || fail "failed close-only transition did not emit its fail-safe diagnosis"

process_is_live_non_zombie() {
    local process_id="$1"
    local process_state

    [ -r "/proc/$process_id/stat" ] || return 1
    process_state="$(awk '{print $3}' "/proc/$process_id/stat" 2>/dev/null || true)"
    [ -n "$process_state" ] && [ "$process_state" != Z ]
}

BOUNDED_CLEANUP_OUTPUT="$FIXTURE_DIR/audit-bounded-cleanup.log"
BOUNDED_FRONTEND_PID_FILE="$FIXTURE_DIR/audit-bounded-frontend.pid"
BOUNDED_CLOSE_PID_FILE="$FIXTURE_DIR/audit-bounded-close.pid"
BOUNDED_BACKEND_PID_FILE="$FIXTURE_DIR/audit-bounded-backend.pid"
reset_audit_transition_case
rm -f "$BOUNDED_FRONTEND_PID_FILE" "$BOUNDED_CLOSE_PID_FILE" \
    "$BOUNDED_BACKEND_PID_FILE"
if (
    cd "$FIXTURE_DIR"
    PATH="$TRANSITION_FAKE_BIN_DIR:$PATH" \
    TRANSITION_FAKE_DOCKER_LOG="$TRANSITION_FAKE_DOCKER_LOG" \
    EXPECTED_OUTBOUND_ACTIVE="$OUTBOUND_KEY_ID" \
    FAIL_EFFECTIVE_BACKEND_AUDIT=1 \
    HANG_CLEANUP_FRONTEND_STOP=1 \
    CLEANUP_FRONTEND_HANG_PID_FILE="$BOUNDED_FRONTEND_PID_FILE" \
    HANG_AUDIT_CLOSE=1 \
    CLOSE_HANG_PID_FILE="$BOUNDED_CLOSE_PID_FILE" \
    HANG_CLEANUP_BACKEND_STOP=1 \
    CLEANUP_BACKEND_HANG_PID_FILE="$BOUNDED_BACKEND_PID_FILE" \
    CONVERSATION_AUDIT_CLEANUP_TIMEOUT_SECONDS=1 \
    CONVERSATION_AUDIT_CLEANUP_KILL_AFTER_SECONDS=1 \
    CONVERSATION_AUDIT_CLOSE_OUTER_TIMEOUT_SECONDS=1 \
    NGROK_AUTHTOKEN=synthetic-local-token \
    APP_BASE_URL=https://synthetic.invalid \
    ./start-dev-bot.sh
) > "$BOUNDED_CLEANUP_OUTPUT" 2>&1; then
    fail "bootstrap accepted cleanup commands that ignored TERM"
fi
assert_audit_gate_closed "bounded cleanup after TERM-resistant commands"
[ "$(<"$TRANSITION_BACKEND_STATE_FILE")" = stopped ] \
    || fail "bounded cleanup did not leave the backend stopped"
for bounded_pid_file in "$BOUNDED_FRONTEND_PID_FILE" "$BOUNDED_CLOSE_PID_FILE" \
    "$BOUNDED_BACKEND_PID_FILE"; do
    [ -s "$bounded_pid_file" ] \
        || fail "bounded cleanup did not exercise a TERM-resistant child"
    bounded_pid="$(<"$bounded_pid_file")"
    [[ "$bounded_pid" =~ ^[1-9][0-9]*$ ]] \
        || fail "bounded cleanup recorded an invalid child PID"
    if process_is_live_non_zombie "$bounded_pid"; then
        fail "bounded cleanup left a TERM-resistant child alive"
    fi
done
grep -Fq 'Conversation audit exposure could not be closed by the coordinator' \
    "$BOUNDED_CLEANUP_OUTPUT" \
    || fail "bounded close-only timeout did not reach the backend fail-safe"

run_post_promotion_docker_hang_case() {
    local command_class="$1"
    local induce_public_failure="${2:-false}"
    local frontend_attempt_allowed="${3:-false}"
    local case_output="$FIXTURE_DIR/audit-post-promotion-${command_class}.log"
    local hang_pid_file="$FIXTURE_DIR/audit-post-promotion-${command_class}.pid"
    local command_status hang_pid
    local -a failure_environment=()

    if [ "$induce_public_failure" = true ]; then
        failure_environment+=(FAIL_PUBLIC_READINESS=1)
    fi
    reset_audit_transition_case
    rm -f "$hang_pid_file"
    if (
        cd "$FIXTURE_DIR"
        env "${failure_environment[@]}" \
            PATH="$TRANSITION_FAKE_BIN_DIR:$PATH" \
            TRANSITION_FAKE_DOCKER_LOG="$TRANSITION_FAKE_DOCKER_LOG" \
            EXPECTED_OUTBOUND_ACTIVE="$OUTBOUND_KEY_ID" \
            HANG_POST_PROMOTION_DOCKER_CLASS="$command_class" \
            POST_PROMOTION_HANG_PID_FILE="$hang_pid_file" \
            CONVERSATION_AUDIT_POST_PROMOTION_TIMEOUT_SECONDS=1 \
            CONVERSATION_AUDIT_CLEANUP_TIMEOUT_SECONDS=1 \
            CONVERSATION_AUDIT_CLEANUP_KILL_AFTER_SECONDS=1 \
            NGROK_AUTHTOKEN=synthetic-local-token \
            APP_BASE_URL=https://synthetic.invalid \
            ./start-dev-bot.sh
    ) > "$case_output" 2>&1; then
        command_status=0
    else
        command_status=$?
    fi
    [ "$command_status" -ne 0 ] \
        || fail "$command_class TERM-resistant Docker command was accepted"
    assert_audit_gate_closed \
        "$command_class TERM-resistant Docker command" "$frontend_attempt_allowed"
    if [ ! -s "$hang_pid_file" ]; then
        sed -n '1,120p' "$case_output" >&2
        fail "$command_class did not exercise its TERM-resistant Docker fake"
    fi
    hang_pid="$(<"$hang_pid_file")"
    if process_is_live_non_zombie "$hang_pid"; then
        fail "$command_class left a TERM-resistant Docker process alive"
    fi
    grep -Fq "docker:hang:$command_class" "$TRANSITION_EVENT_LOG" \
        || fail "$command_class did not record the bounded Docker boundary"
    if grep -Fq 'Hybrid Local Mode is Running' "$case_output"; then
        fail "$command_class timeout announced a ready environment"
    fi
}

run_post_promotion_docker_hang_case validate-compose
run_post_promotion_docker_hang_case validate-backend
run_post_promotion_docker_hang_case diagnostics-ps true
run_post_promotion_docker_hang_case diagnostics-logs true
run_post_promotion_docker_hang_case frontend-up false true
run_post_promotion_docker_hang_case frontend-ps false true
