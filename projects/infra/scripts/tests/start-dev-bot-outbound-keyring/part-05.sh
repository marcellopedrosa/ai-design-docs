run_post_promotion_real_signal_case() {
    local command_class="$1"
    local signal_name="$2"
    local expected_status="$3"
    local second_signal="${4:-}"
    local force_close_failure="${5:-false}"
    local frontend_attempt_allowed="${6:-false}"
    local case_output="$FIXTURE_DIR/audit-post-promotion-signal-${command_class}.log"
    local hang_pid_file="$FIXTURE_DIR/audit-post-promotion-signal-${command_class}.pid"
    local descendant_pid_file="$FIXTURE_DIR/audit-post-promotion-signal-${command_class}.descendant.pid"
    local supervision_state_file="$FIXTURE_DIR/audit-post-promotion-signal-${command_class}.supervision"
    local entrypoint_pid entrypoint_status hang_pid descendant_pid
    local supervised_pid supervised_pgid supervised_starttime signal_started elapsed_seconds
    local proc_cmajflt proc_cminflt proc_cstime proc_cutime proc_flags proc_itrealvalue
    local proc_majflt proc_minflt proc_nice proc_num_threads proc_pgrp proc_ppid
    local proc_priority proc_session proc_starttime proc_state proc_stime proc_tpgid
    local proc_tty_nr proc_utime proc_stat_fields proc_stat_line attempt
    local -a close_failure_environment=()

    if [ "$force_close_failure" = true ]; then
        close_failure_environment+=(FAIL_AUDIT_CLOSE=1)
    fi
    reset_audit_transition_case
    rm -f "$hang_pid_file" "$descendant_pid_file" "$supervision_state_file"
    (
        cd "$FIXTURE_DIR"
        exec env --default-signal=INT --default-signal=TERM \
            "${close_failure_environment[@]}" \
            PATH="$TRANSITION_FAKE_BIN_DIR:$PATH" \
            TRANSITION_FAKE_DOCKER_LOG="$TRANSITION_FAKE_DOCKER_LOG" \
            EXPECTED_OUTBOUND_ACTIVE="$OUTBOUND_KEY_ID" \
            START_DEV_BOT_TEST_MODE=1 \
            CONVERSATION_AUDIT_TEST_SUPERVISED_STATE_FILE="$supervision_state_file" \
            HANG_POST_PROMOTION_DOCKER_CLASS="$command_class" \
            POST_PROMOTION_HANG_PID_FILE="$hang_pid_file" \
            POST_PROMOTION_HANG_DESCENDANT_PID_FILE="$descendant_pid_file" \
            CONVERSATION_AUDIT_POST_PROMOTION_TIMEOUT_SECONDS=300 \
            CONVERSATION_AUDIT_SHUTDOWN_GRACE_SECONDS=1 \
            CONVERSATION_AUDIT_CLEANUP_TIMEOUT_SECONDS=1 \
            CONVERSATION_AUDIT_CLEANUP_KILL_AFTER_SECONDS=1 \
            NGROK_AUTHTOKEN=synthetic-local-token \
            APP_BASE_URL=https://synthetic.invalid \
            ./start-dev-bot.sh
    ) > "$case_output" 2>&1 &
    entrypoint_pid=$!

    for attempt in $(seq 1 200); do
        if grep -Fq "docker:hang:$command_class" "$TRANSITION_EVENT_LOG" \
            && [ -s "$hang_pid_file" ] \
            && [ -s "$descendant_pid_file" ] \
            && [ -s "$supervision_state_file" ]; then
            break
        fi
        if ! kill -0 "$entrypoint_pid" 2>/dev/null; then
            break
        fi
        /bin/sleep 0.05
    done
    if ! grep -Fq "docker:hang:$command_class" "$TRANSITION_EVENT_LOG"; then
        sed -n '1,120p' "$case_output" >&2
        fail "$command_class signal case did not reach the supervised Docker command"
    fi
    [ -s "$hang_pid_file" ] && [ -s "$descendant_pid_file" ] \
        && [ -s "$supervision_state_file" ] \
        || fail "$command_class signal case did not publish its process identities"

    read -r supervised_pid supervised_pgid supervised_starttime \
        < "$supervision_state_file"
    [[ "$supervised_pid" =~ ^[1-9][0-9]*$ ]] \
        && [ "$supervised_pid" = "$supervised_pgid" ] \
        && [[ "$supervised_starttime" =~ ^[1-9][0-9]*$ ]] \
        || fail "$command_class signal case recorded an invalid parent supervision identity"
    [ -r "/proc/$supervised_pid/stat" ] \
        || fail "$command_class supervised wrapper exited before the signal"
    proc_stat_line="$(<"/proc/$supervised_pid/stat")"
    proc_stat_fields="${proc_stat_line##*) }"
    read -r proc_state proc_ppid proc_pgrp proc_session proc_tty_nr proc_tpgid \
        proc_flags proc_minflt proc_cminflt proc_majflt proc_cmajflt proc_utime \
        proc_stime proc_cutime proc_cstime proc_priority proc_nice proc_num_threads \
        proc_itrealvalue proc_starttime _ <<< "$proc_stat_fields"
    [ "$proc_pgrp" = "$supervised_pid" ] \
        && [ "$proc_session" = "$supervised_pid" ] \
        && [ "$proc_starttime" = "$supervised_starttime" ] \
        || fail "$command_class parent did not retain a verified PID/PGID/SID identity"

    hang_pid="$(<"$hang_pid_file")"
    descendant_pid="$(<"$descendant_pid_file")"
    [[ "$hang_pid" =~ ^[1-9][0-9]*$ ]] \
        && [[ "$descendant_pid" =~ ^[1-9][0-9]*$ ]] \
        || fail "$command_class signal case recorded an invalid Docker process PID"

    signal_started=$SECONDS
    kill -s "$signal_name" "$entrypoint_pid"
    if [ -n "$second_signal" ]; then
        /bin/sleep 0.05
        kill -s "$second_signal" "$entrypoint_pid" 2>/dev/null || true
    fi
    for attempt in $(seq 1 100); do
        kill -0 "$entrypoint_pid" 2>/dev/null || break
        /bin/sleep 0.05
    done
    if kill -0 "$entrypoint_pid" 2>/dev/null; then
        kill -KILL "$entrypoint_pid" 2>/dev/null || true
        wait "$entrypoint_pid" 2>/dev/null || true
        fail "$command_class signal shutdown exceeded its bounded grace"
    fi
    if wait "$entrypoint_pid"; then
        entrypoint_status=0
    else
        entrypoint_status=$?
    fi
    elapsed_seconds=$((SECONDS - signal_started))
    [ "$elapsed_seconds" -le 5 ] \
        || fail "$command_class signal shutdown used the 300-second command timeout"
    [ "$entrypoint_status" = "$expected_status" ] \
        || fail "$command_class $signal_name returned $entrypoint_status instead of $expected_status"
    assert_audit_gate_closed \
        "$command_class $signal_name interruption" "$frontend_attempt_allowed"
    if process_is_live_non_zombie "$hang_pid" \
        || process_is_live_non_zombie "$descendant_pid" \
        || process_is_live_non_zombie "$supervised_pid"; then
        fail "$command_class $signal_name interruption left a supervised process alive"
    fi
    if [ "$force_close_failure" = true ] \
        && [ "$(<"$TRANSITION_BACKEND_STATE_FILE")" != stopped ]; then
        fail "$command_class failed close did not stop the backend"
    fi
    if grep -Fq 'Hybrid Local Mode is Running' "$case_output"; then
        fail "$command_class signal interruption announced a ready environment"
    fi
    /bin/sleep 0.1
    assert_audit_runtime_closed "$command_class delayed signal recheck"
    if process_is_live_non_zombie "$hang_pid" \
        || process_is_live_non_zombie "$descendant_pid" \
        || process_is_live_non_zombie "$supervised_pid"; then
        fail "$command_class delayed signal recheck found a supervised process alive"
    fi
}

# INT wins over a subsequent TERM while the former command-substitution proof
# is now directly supervised by the entrypoint shell.
run_post_promotion_real_signal_case validate-compose INT 130 TERM
run_post_promotion_real_signal_case frontend-up TERM 143 '' true true

FINALIZING_SIGNAL_OUTPUT="$FIXTURE_DIR/audit-supervisor-finalizing-signal.log"
reset_audit_transition_case
if (
    cd "$FIXTURE_DIR"
    exec env --default-signal=INT --default-signal=TERM \
        PATH="$TRANSITION_FAKE_BIN_DIR:$PATH" \
        TRANSITION_FAKE_DOCKER_LOG="$TRANSITION_FAKE_DOCKER_LOG" \
        EXPECTED_OUTBOUND_ACTIVE="$OUTBOUND_KEY_ID" \
        START_DEV_BOT_TEST_MODE=1 \
        CONVERSATION_AUDIT_TEST_FINALIZING_SIGNAL=INT \
        CONVERSATION_AUDIT_TEST_FINALIZING_SECOND_SIGNAL=TERM \
        NGROK_AUTHTOKEN=synthetic-local-token \
        APP_BASE_URL=https://synthetic.invalid \
        ./start-dev-bot.sh
) > "$FINALIZING_SIGNAL_OUTPUT" 2>&1; then
    finalizing_signal_status=0
else
    finalizing_signal_status=$?
fi
[ "$finalizing_signal_status" = 130 ] \
    || fail "FINALIZING INT then TERM returned $finalizing_signal_status instead of first-signal 130"
assert_audit_gate_closed "FINALIZING INT then TERM interruption"
if grep -Fq 'Hybrid Local Mode is Running' "$FINALIZING_SIGNAL_OUTPUT"; then
    fail "FINALIZING INT then TERM interruption announced a ready environment"
fi

BEFORE_WAIT_SIGNAL_OUTPUT="$FIXTURE_DIR/audit-supervisor-before-wait-signal.log"
BEFORE_WAIT_HANG_PID_FILE="$FIXTURE_DIR/audit-supervisor-before-wait.pid"
BEFORE_WAIT_DESCENDANT_PID_FILE="$FIXTURE_DIR/audit-supervisor-before-wait.descendant.pid"
reset_audit_transition_case
rm -f "$BEFORE_WAIT_HANG_PID_FILE" "$BEFORE_WAIT_DESCENDANT_PID_FILE"
before_wait_signal_started=$SECONDS
if (
    cd "$FIXTURE_DIR"
    exec env --default-signal=INT --default-signal=TERM \
        PATH="$TRANSITION_FAKE_BIN_DIR:$PATH" \
        TRANSITION_FAKE_DOCKER_LOG="$TRANSITION_FAKE_DOCKER_LOG" \
        EXPECTED_OUTBOUND_ACTIVE="$OUTBOUND_KEY_ID" \
        START_DEV_BOT_TEST_MODE=1 \
        CONVERSATION_AUDIT_TEST_BEFORE_WAIT_SIGNAL=INT \
        CONVERSATION_AUDIT_TEST_BEFORE_WAIT_READY_FILE="$BEFORE_WAIT_DESCENDANT_PID_FILE" \
        HANG_POST_PROMOTION_DOCKER_CLASS=validate-compose \
        POST_PROMOTION_HANG_PID_FILE="$BEFORE_WAIT_HANG_PID_FILE" \
        POST_PROMOTION_HANG_DESCENDANT_PID_FILE="$BEFORE_WAIT_DESCENDANT_PID_FILE" \
        EXIT_POST_PROMOTION_PARENT_AFTER_DESCENDANT=1 \
        CONVERSATION_AUDIT_POST_PROMOTION_TIMEOUT_SECONDS=300 \
        CONVERSATION_AUDIT_SHUTDOWN_GRACE_SECONDS=1 \
        CONVERSATION_AUDIT_CLEANUP_TIMEOUT_SECONDS=1 \
        CONVERSATION_AUDIT_CLEANUP_KILL_AFTER_SECONDS=1 \
        NGROK_AUTHTOKEN=synthetic-local-token \
        APP_BASE_URL=https://synthetic.invalid \
        ./start-dev-bot.sh
) > "$BEFORE_WAIT_SIGNAL_OUTPUT" 2>&1; then
    before_wait_signal_status=0
else
    before_wait_signal_status=$?
fi
before_wait_signal_elapsed=$((SECONDS - before_wait_signal_started))
[ "$before_wait_signal_status" = 130 ] \
    || fail "before-supervised-wait INT returned $before_wait_signal_status instead of 130"
[ "$before_wait_signal_elapsed" -le 5 ] \
    || fail "before-supervised-wait INT was lost until the 300-second timeout"
assert_audit_gate_closed "before-supervised-wait INT interruption"
[ -s "$BEFORE_WAIT_HANG_PID_FILE" ] && [ -s "$BEFORE_WAIT_DESCENDANT_PID_FILE" ] \
    || fail "before-supervised-wait INT did not exercise the TERM-resistant tree"
before_wait_hang_pid="$(<"$BEFORE_WAIT_HANG_PID_FILE")"
before_wait_descendant_pid="$(<"$BEFORE_WAIT_DESCENDANT_PID_FILE")"
if process_is_live_non_zombie "$before_wait_hang_pid" \
    || process_is_live_non_zombie "$before_wait_descendant_pid"; then
    fail "before-supervised-wait INT left a supervised process alive"
fi
/bin/sleep 0.1
if process_is_live_non_zombie "$before_wait_hang_pid" \
    || process_is_live_non_zombie "$before_wait_descendant_pid"; then
    fail "before-supervised-wait delayed recheck found a supervised process alive"
fi
if grep -Fq 'Hybrid Local Mode is Running' "$BEFORE_WAIT_SIGNAL_OUTPUT"; then
    fail "before-supervised-wait INT announced a ready environment"
fi

run_spawn_checkpoint_signal_case() {
    local phase="$1"
    local signal_name="$2"
    local expected_status="$3"
    local signal_output="$FIXTURE_DIR/audit-spawn-${phase}.log"
    local descendant_pid_file="$FIXTURE_DIR/audit-spawn-${phase}.descendant.pid"
    local entrypoint_status descendant_pid

    reset_audit_transition_case
    rm -f "$descendant_pid_file"
    if (
        cd "$FIXTURE_DIR"
        PATH="$TRANSITION_FAKE_BIN_DIR:$PATH" \
        TRANSITION_FAKE_DOCKER_LOG="$TRANSITION_FAKE_DOCKER_LOG" \
        EXPECTED_OUTBOUND_ACTIVE="$OUTBOUND_KEY_ID" \
        START_DEV_BOT_TEST_MODE=1 \
        CONVERSATION_AUDIT_TEST_SPAWN_PHASE="$phase" \
        CONVERSATION_AUDIT_TEST_SPAWN_SIGNAL="$signal_name" \
        WAIT_AUDIT_ACTIVATOR_FOR_TERM=1 \
        ACTIVATOR_DESCENDANT_PID_FILE="$descendant_pid_file" \
        CONVERSATION_AUDIT_SHUTDOWN_GRACE_SECONDS=1 \
        NGROK_AUTHTOKEN=synthetic-local-token \
        APP_BASE_URL=https://synthetic.invalid \
        ./start-dev-bot.sh
    ) > "$signal_output" 2>&1; then
        entrypoint_status=0
    else
        entrypoint_status=$?
    fi
    [ "$entrypoint_status" = "$expected_status" ] \
        || fail "$phase $signal_name case returned $entrypoint_status instead of $expected_status"
    assert_audit_gate_closed "$phase $signal_name interruption"
    if grep -Fq 'activator:start' "$TRANSITION_EVENT_LOG"; then
        fail "$phase $signal_name interruption released the activator start gate"
    fi
    if [ -s "$descendant_pid_file" ]; then
        descendant_pid="$(<"$descendant_pid_file")"
        if process_is_live_non_zombie "$descendant_pid"; then
            fail "$phase $signal_name interruption left an activator descendant alive"
        fi
    fi
    /bin/sleep 0.1
    assert_audit_runtime_closed "$phase $signal_name interruption after delayed recheck"
}

run_spawn_checkpoint_signal_case before-pid INT 130
run_spawn_checkpoint_signal_case before-pgid TERM 143

run_audit_signal_case() {
    local signal_name="$1"
    local expected_status="$2"
    local signal_output="$FIXTURE_DIR/audit-signal-${signal_name}.log"
    local descendant_pid_file="$FIXTURE_DIR/audit-signal-${signal_name}.descendant.pid"
    local entrypoint_pid entrypoint_status descendant_pid attempt

    reset_audit_transition_case
    rm -f "$descendant_pid_file"
    (
        cd "$FIXTURE_DIR"
        exec env --default-signal=INT --default-signal=TERM \
            PATH="$TRANSITION_FAKE_BIN_DIR:$PATH" \
            TRANSITION_FAKE_DOCKER_LOG="$TRANSITION_FAKE_DOCKER_LOG" \
            EXPECTED_OUTBOUND_ACTIVE="$OUTBOUND_KEY_ID" \
            WAIT_AUDIT_ACTIVATOR_FOR_TERM=1 \
            ACTIVATOR_DESCENDANT_PID_FILE="$descendant_pid_file" \
            CONVERSATION_AUDIT_SHUTDOWN_GRACE_SECONDS=1 \
            NGROK_AUTHTOKEN=synthetic-local-token \
            APP_BASE_URL=https://synthetic.invalid \
            ./start-dev-bot.sh
    ) > "$signal_output" 2>&1 &
    entrypoint_pid=$!

    for attempt in $(seq 1 100); do
        if grep -Fq 'activator:waiting' "$TRANSITION_EVENT_LOG" \
            && [ -s "$descendant_pid_file" ]; then
            break
        fi
        if ! kill -0 "$entrypoint_pid" 2>/dev/null; then
            break
        fi
        /bin/sleep 0.05
    done
    grep -Fq 'activator:waiting' "$TRANSITION_EVENT_LOG" \
        || fail "$signal_name case did not reach the supervised activator wait"
    [ -s "$descendant_pid_file" ] \
        || fail "$signal_name case did not record the activator descendant"
    descendant_pid="$(<"$descendant_pid_file")"
    [[ "$descendant_pid" =~ ^[1-9][0-9]*$ ]] \
        || fail "$signal_name case recorded an invalid descendant PID"

    kill -s "$signal_name" "$entrypoint_pid"
    /bin/sleep 0.05
    kill -s "$signal_name" "$entrypoint_pid" 2>/dev/null || true
    if wait "$entrypoint_pid"; then
        entrypoint_status=0
    else
        entrypoint_status=$?
    fi
    [ "$entrypoint_status" = "$expected_status" ] \
        || fail "$signal_name case returned $entrypoint_status instead of $expected_status"
    assert_audit_gate_closed "$signal_name interruption"
    if process_is_live_non_zombie "$descendant_pid"; then
        fail "$signal_name interruption left an activator descendant alive"
    fi
    if grep -Fq 'Hybrid Local Mode is Running' "$signal_output"; then
        fail "$signal_name interruption announced a ready environment"
    fi
}

run_audit_signal_case TERM 143
run_audit_signal_case INT 130
rm -f "$OUTBOUND_COMMIT_RECEIPT_FILE"
: > "$OUTPUT_FILE"

printf '{"keys":{"%s":"%s","%s":"%s"}}\n' \
    "$OUTBOUND_KEY_ID" "$outbound_key_material" \
    "$SECOND_OUTBOUND_KEY_ID" "$second_outbound_key_material" \
    > "$STAGING_ADD_FILE"
chmod 600 "$STAGING_ADD_FILE"
(
    cd "$FIXTURE_DIR"
    ./start-dev-bot.sh --stage-outbound-hmac-keyring \
        "$STAGING_ADD_FILE" "$OUTBOUND_KEY_ID"
) >> "$OUTPUT_FILE" 2>&1
cmp -s "$STAGING_ADD_FILE" "$OUTBOUND_KEYRING_FILE" \
    || fail "DEV staging did not publish the additive outbound keyring atomically"
grep -qx "CONVERSATION_OUTBOUND_ATTEMPT_HMAC_ACTIVE_KEY_ID=${OUTBOUND_KEY_ID}" \
    "$GENERATED_ENV_FILE" \
    || fail "add staging changed the outbound active key"

(
    cd "$FIXTURE_DIR"
    ./start-dev-bot.sh --prepare-env-only
) >> "$OUTPUT_FILE" 2>&1
cmp -s "$STAGING_ADD_FILE" "$OUTBOUND_KEYRING_FILE" \
    || fail "bootstrap did not preserve an existing valid multi-key outbound keyring"

cp "$OUTBOUND_KEYRING_FILE" "$FIXTURE_DIR/outbound.before-uncommitted-switch"
cp "$GENERATED_ENV_FILE" "$FIXTURE_DIR/env.before-uncommitted-switch"
if (
    cd "$FIXTURE_DIR"
    ./start-dev-bot.sh --stage-outbound-hmac-keyring \
        "$STAGING_ADD_FILE" "$SECOND_OUTBOUND_KEY_ID"
) >> "$OUTPUT_FILE" 2>&1; then
    fail "prepare-only incorrectly authorized an outbound active-key switch"
fi
cmp -s "$FIXTURE_DIR/outbound.before-uncommitted-switch" "$OUTBOUND_KEYRING_FILE" \
    && cmp -s "$FIXTURE_DIR/env.before-uncommitted-switch" "$GENERATED_ENV_FILE" \
    || fail "rejected uncommitted switch changed source or environment"

printf '%s\n' stopped > "$TRANSITION_BACKEND_STATE_FILE"
: > "$POSTGRES_APP_CREDENTIAL_ONCE_FILE"
run_fake_initializer_commit "$OUTBOUND_KEY_ID"
first_app_credential_line="$(grep -nF ' exec -T postgres-app sh -eu -c' \
    "$TRANSITION_EVENT_LOG" | sed -n '1p' | cut -d: -f1)"
app_role_sync_line="$(grep -nF \
    ' exec -T postgres-app psql -v ON_ERROR_STOP=1 -U' \
    "$TRANSITION_EVENT_LOG" | sed -n '1p' | cut -d: -f1)"
second_app_credential_line="$(grep -nF ' exec -T postgres-app sh -eu -c' \
    "$TRANSITION_EVENT_LOG" | sed -n '2p' | cut -d: -f1)"
[ -n "$first_app_credential_line" ] && [ -n "$app_role_sync_line" ] \
    && [ -n "$second_app_credential_line" ] \
    && [ "$first_app_credential_line" -lt "$app_role_sync_line" ] \
    && [ "$app_role_sync_line" -lt "$second_app_credential_line" ] \
    || fail "stopped-consumer credential recovery did not synchronize and reverify the role"
valid_receipt_signature="$(jq -er '.signature' "$OUTBOUND_COMMIT_RECEIPT_FILE")"
jq '.signature = "0000000000000000000000000000000000000000000000000000000000000000"' \
    "$OUTBOUND_COMMIT_RECEIPT_FILE" > "$FIXTURE_DIR/tampered-receipt.json"
mv "$FIXTURE_DIR/tampered-receipt.json" "$OUTBOUND_COMMIT_RECEIPT_FILE"
chmod 600 "$OUTBOUND_COMMIT_RECEIPT_FILE"
if (
    cd "$FIXTURE_DIR"
    ./start-dev-bot.sh --stage-outbound-hmac-keyring \
        "$STAGING_ADD_FILE" "$SECOND_OUTBOUND_KEY_ID"
) >> "$OUTPUT_FILE" 2>&1; then
    fail "DEV staging accepted a tampered initializer commit receipt"
fi
cmp -s "$FIXTURE_DIR/outbound.before-uncommitted-switch" "$OUTBOUND_KEYRING_FILE" \
    && cmp -s "$FIXTURE_DIR/env.before-uncommitted-switch" "$GENERATED_ENV_FILE" \
    || fail "tampered receipt rejection changed source or environment"

run_fake_initializer_commit "$OUTBOUND_KEY_ID"
exec {held_stage_lock_fd}<>"$OUTBOUND_STAGE_LOCK_FILE"
flock -n "$held_stage_lock_fd" || fail "test fixture could not hold the outbound host lock"
if (
    cd "$FIXTURE_DIR"
    ./start-dev-bot.sh --stage-outbound-hmac-keyring \
        "$STAGING_ADD_FILE" "$SECOND_OUTBOUND_KEY_ID"
) >> "$OUTPUT_FILE" 2>&1; then
    fail "DEV staging accepted a concurrent host operation"
fi
exec {held_stage_lock_fd}<&-
cmp -s "$FIXTURE_DIR/outbound.before-uncommitted-switch" "$OUTBOUND_KEYRING_FILE" \
    && cmp -s "$FIXTURE_DIR/env.before-uncommitted-switch" "$GENERATED_ENV_FILE" \
    || fail "concurrent staging rejection changed source or environment"

(
    cd "$FIXTURE_DIR"
    ./start-dev-bot.sh --stage-outbound-hmac-keyring \
        "$STAGING_ADD_FILE" "$SECOND_OUTBOUND_KEY_ID"
) >> "$OUTPUT_FILE" 2>&1
grep -qx "CONVERSATION_OUTBOUND_ATTEMPT_HMAC_ACTIVE_KEY_ID=${SECOND_OUTBOUND_KEY_ID}" \
    "$GENERATED_ENV_FILE" \
    || fail "switch staging did not select the already committed outbound key"

printf '{"keys":{"%s":"%s"}}\n' \
    "$SECOND_OUTBOUND_KEY_ID" "$second_outbound_key_material" \
    > "$STAGING_RETIRE_FILE"
chmod 600 "$STAGING_RETIRE_FILE"
cp "$OUTBOUND_KEYRING_FILE" "$FIXTURE_DIR/outbound.before-uncommitted-retirement"
cp "$GENERATED_ENV_FILE" "$FIXTURE_DIR/env.before-uncommitted-retirement"
if (
    cd "$FIXTURE_DIR"
    ./start-dev-bot.sh --stage-outbound-hmac-keyring \
        "$STAGING_RETIRE_FILE" "$SECOND_OUTBOUND_KEY_ID"
) >> "$OUTPUT_FILE" 2>&1; then
    fail "DEV staging retired a key before the active switch was committed"
fi
cmp -s "$FIXTURE_DIR/outbound.before-uncommitted-retirement" "$OUTBOUND_KEYRING_FILE" \
    && cmp -s "$FIXTURE_DIR/env.before-uncommitted-retirement" "$GENERATED_ENV_FILE" \
    || fail "rejected uncommitted retirement changed source or environment"
run_fake_initializer_commit "$SECOND_OUTBOUND_KEY_ID"
