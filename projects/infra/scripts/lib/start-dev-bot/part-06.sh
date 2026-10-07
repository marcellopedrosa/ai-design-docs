run_isolated_bounded_conversation_audit_command() {
    local timeout_seconds="$1"
    local command_status=0 pending_signal_status=""
    local proc_cmajflt proc_cminflt proc_cstime proc_cutime proc_flags proc_itrealvalue
    local proc_majflt proc_minflt proc_nice proc_num_threads proc_pgrp proc_ppid
    local proc_priority proc_session proc_starttime proc_state proc_stime proc_tpgid
    local proc_tty_nr proc_utime proc_stat_fields proc_stat_line attempt
    shift

    if [ "$CONVERSATION_AUDIT_SUPERVISED_COMMAND_STATE" != IDLE ]; then
        echo "ERROR: Nested conversation audit command supervision is not allowed." >&2
        return 125
    fi
    CONVERSATION_AUDIT_SUPERVISED_COMMAND_STATE=STARTING
    CONVERSATION_AUDIT_SUPERVISED_COMMAND_PID=""
    CONVERSATION_AUDIT_SUPERVISED_COMMAND_PGID=""
    CONVERSATION_AUDIT_SUPERVISED_COMMAND_STARTTIME=""
    CONVERSATION_AUDIT_SUPERVISED_COMMAND_GROUP_VERIFIED=false
    set +m
    setsid --wait bash -c 'kill -STOP "$$"; exec "$@"' \
        conversation-audit-bounded-command \
        timeout --foreground --signal=TERM \
            --kill-after="${CONVERSATION_AUDIT_CLEANUP_KILL_AFTER_SECONDS}s" \
            "${timeout_seconds}s" "$@" <&0 \
            {OUTBOUND_ATTEMPT_STAGE_LOCK_FD}>&- &
    CONVERSATION_AUDIT_SUPERVISED_COMMAND_PID=$!

    proc_state=""
    proc_pgrp=""
    proc_session=""
    proc_starttime=""
    for attempt in $(seq 1 50); do
        if [ ! -r "/proc/$CONVERSATION_AUDIT_SUPERVISED_COMMAND_PID/stat" ]; then
            break
        fi
        proc_stat_line="$(<"/proc/$CONVERSATION_AUDIT_SUPERVISED_COMMAND_PID/stat")"
        proc_stat_fields="${proc_stat_line##*) }"
        read -r proc_state proc_ppid proc_pgrp proc_session proc_tty_nr proc_tpgid \
            proc_flags proc_minflt proc_cminflt proc_majflt proc_cmajflt proc_utime \
            proc_stime proc_cutime proc_cstime proc_priority proc_nice proc_num_threads \
            proc_itrealvalue proc_starttime _ <<< "$proc_stat_fields"
        CONVERSATION_AUDIT_SUPERVISED_COMMAND_STARTTIME="$proc_starttime"
        if [ "$proc_state" = T ] \
            && [ "$proc_pgrp" = "$CONVERSATION_AUDIT_SUPERVISED_COMMAND_PID" ] \
            && [ "$proc_session" = "$CONVERSATION_AUDIT_SUPERVISED_COMMAND_PID" ]; then
            break
        fi
        /bin/sleep 0.01 || true
    done
    if [ "$proc_state" != T ] \
        || [ "$proc_pgrp" != "$CONVERSATION_AUDIT_SUPERVISED_COMMAND_PID" ] \
        || [ "$proc_session" != "$CONVERSATION_AUDIT_SUPERVISED_COMMAND_PID" ] \
        || [ -z "$proc_starttime" ]; then
        echo "ERROR: A bounded conversation audit command did not enter a dedicated process group." >&2
        terminate_conversation_audit_supervised_command_tree
        finalize_conversation_audit_supervised_command
        return 125
    fi

    CONVERSATION_AUDIT_SUPERVISED_COMMAND_PGID="$proc_pgrp"
    CONVERSATION_AUDIT_SUPERVISED_COMMAND_GROUP_VERIFIED=true
    CONVERSATION_AUDIT_SUPERVISED_COMMAND_STATE=RUNNING
    if ! record_conversation_audit_test_supervised_command_state; then
        echo "ERROR: Could not record the hermetic command-supervision checkpoint." >&2
        command_status=125
    fi
    if [ -n "$CONVERSATION_AUDIT_PENDING_SIGNAL_STATUS" ]; then
        pending_signal_status="$CONVERSATION_AUDIT_PENDING_SIGNAL_STATUS"
    elif [ "$command_status" -eq 0 ] \
        && ! kill -CONT -- "-$CONVERSATION_AUDIT_SUPERVISED_COMMAND_PGID" 2>/dev/null; then
        echo "ERROR: A bounded conversation audit command start gate could not be released." >&2
        command_status=125
    fi

    if [ -n "$pending_signal_status" ] || [ "$command_status" -ne 0 ]; then
        terminate_conversation_audit_supervised_command_tree
    else
        while :; do
            if [ -n "$CONVERSATION_AUDIT_PENDING_SIGNAL_STATUS" ]; then
                pending_signal_status="$CONVERSATION_AUDIT_PENDING_SIGNAL_STATUS"
                terminate_conversation_audit_supervised_command_tree
                break
            fi
            # The deterministic checkpoint sits after the pending read. A
            # subsequent signal cannot become a lost wakeup because RUNNING is
            # polled; wait is used only after procfs proves the leader exited.
            conversation_audit_test_before_supervised_wait_checkpoint
            if [ -n "$CONVERSATION_AUDIT_PENDING_SIGNAL_STATUS" ]; then
                continue
            fi
            if conversation_audit_supervised_command_exit_observed; then
                # Keep the verified zombie leader as an identity anchor while
                # killing any unauthorized descendant that outlived the
                # bounded command. Only then reap the leader and release PGID.
                if conversation_audit_supervised_command_identity_is_current; then
                    kill -KILL -- "-$CONVERSATION_AUDIT_SUPERVISED_COMMAND_PGID" \
                        2>/dev/null || true
                fi
                if ! drain_conversation_audit_supervised_command_group; then
                    echo "ERROR: A bounded conversation audit command left its process group alive." >&2
                    command_status=125
                fi
                if wait_for_conversation_audit_supervised_command true; then
                    [ "$command_status" -eq 125 ] || command_status=0
                else
                    [ "$command_status" -eq 125 ] || command_status=$?
                fi
                if [ -n "$CONVERSATION_AUDIT_PENDING_SIGNAL_STATUS" ]; then
                    pending_signal_status="$CONVERSATION_AUDIT_PENDING_SIGNAL_STATUS"
                fi
                break
            else
                command_status=$?
                if [ "$command_status" -eq 2 ]; then
                    echo "ERROR: A supervised conversation audit command changed identity." >&2
                    command_status=125
                    terminate_conversation_audit_supervised_command_tree
                    break
                fi
            fi
            /bin/sleep 0.02 || true
        done
    fi

    finalize_conversation_audit_supervised_command "$pending_signal_status"
    return "$command_status"
}

run_bounded_conversation_audit_cleanup_command() {
    run_isolated_bounded_conversation_audit_command \
        "$CONVERSATION_AUDIT_CLEANUP_TIMEOUT_SECONDS" "$@"
}

run_bounded_conversation_audit_post_promotion_compose() {
    run_isolated_bounded_conversation_audit_command \
        "$CONVERSATION_AUDIT_POST_PROMOTION_TIMEOUT_SECONDS" \
        "${COMPOSE[@]}" "${COMPOSE_ENV_FILES[@]}" "${COMPOSE_FILES[@]}" \
        "$@"
}

run_bounded_conversation_audit_compose_proof() {
    local expected_allowlist_digest="$1"
    local jq_filter='
        .services.backend.environment as $environment
        | select(
            $environment.APP_CONVERSATION_AUDIT_ENABLED == "true"
            and $environment.APP_CONVERSATION_AUDIT_API_ENABLED == "true"
            and $environment.APP_CONVERSATION_AUDIT_LEGACY_READ_ENABLED == "false"
            and $environment.APP_CONVERSATION_AUDIT_BACKFILL_ENABLED == "false"
            and $environment.APP_CONVERSATION_AUDIT_BACKFILL_TENANT_ID == ""
            and ($environment.APP_CONVERSATION_AUDIT_ALLOWED_TENANT_IDS
                | type == "string" and length > 0)
        )
        | $environment.APP_CONVERSATION_AUDIT_ALLOWED_TENANT_IDS
    '

    run_isolated_bounded_conversation_audit_command \
        "$CONVERSATION_AUDIT_POST_PROMOTION_TIMEOUT_SECONDS" \
        bash -c '
            set -o pipefail
            expected_digest="$1"
            jq_filter="$2"
            shift 2
            configured_digest="$(
                "$@" config --format json \
                    | jq -er "$jq_filter" \
                    | sha256sum \
                    | awk "{print \$1}"
            )" || exit 41
            [ "$configured_digest" = "$expected_digest" ] || exit 42
        ' conversation-audit-compose-proof \
            "$expected_allowlist_digest" "$jq_filter" \
            "${COMPOSE[@]}" "${COMPOSE_ENV_FILES[@]}" "${COMPOSE_FILES[@]}"
}

run_bounded_conversation_audit_compose_service_stopped_proof() {
    local service="$1"

    run_isolated_bounded_conversation_audit_command \
        "$CONVERSATION_AUDIT_CLEANUP_TIMEOUT_SECONDS" \
        bash -c '
            service="$1"
            shift
            running_services="$(
                "$@" ps --status running --services "$service" 2>/dev/null
            )" || exit $?
            [ -z "$running_services" ]
        ' conversation-audit-stopped-proof "$service" \
            "${COMPOSE[@]}" "${COMPOSE_ENV_FILES[@]}" "${COMPOSE_FILES[@]}"
}

run_bounded_conversation_audit_frontend_running_proof() {
    run_isolated_bounded_conversation_audit_command \
        "$CONVERSATION_AUDIT_POST_PROMOTION_TIMEOUT_SECONDS" \
        bash -c '
            running_services="$(
                "$@" ps --status running --services frontend
            )" || exit $?
            [ "$running_services" = frontend ]
        ' conversation-audit-frontend-proof \
            "${COMPOSE[@]}" "${COMPOSE_ENV_FILES[@]}" "${COMPOSE_FILES[@]}"
}

stop_and_verify_conversation_audit_cleanup_service() {
    local service="$1"
    local inspect_status=0
    local stop_status=0

    run_bounded_conversation_audit_cleanup_command \
        "${COMPOSE[@]}" "${COMPOSE_ENV_FILES[@]}" "${COMPOSE_FILES[@]}" \
        stop --timeout "$CONVERSATION_AUDIT_CLEANUP_TIMEOUT_SECONDS" "$service" \
        >/dev/null 2>&1 || stop_status=$?
    run_bounded_conversation_audit_compose_service_stopped_proof "$service" \
        || inspect_status=$?
    [ "$stop_status" -eq 0 ] \
        && [ "$inspect_status" -eq 0 ]
}

run_bounded_conversation_audit_close() {
    CONVERSATION_AUDIT_ACTIVATION_PROJECT_DIR="$PROJECT_DIR" \
        CONVERSATION_AUDIT_ACTIVATION_RUNTIME_ENV_FILE="$CONVERSATION_AUDIT_RUNTIME_ENV_FILE" \
        setsid --wait timeout --signal=TERM \
            --kill-after="${CONVERSATION_AUDIT_CLEANUP_KILL_AFTER_SECONDS}s" \
            "${CONVERSATION_AUDIT_CLOSE_OUTER_TIMEOUT_SECONDS}s" \
            bash "/proc/self/fd/$CONVERSATION_AUDIT_CLOSE_FD" \
            --close-exposure-only </dev/null \
            {OUTBOUND_ATTEMPT_STAGE_LOCK_FD}>&-
}

close_possible_conversation_audit_exposure() {
    local close_status=0

    if [ "$CONVERSATION_AUDIT_EXPOSURE_MAY_BE_OPEN" != true ]; then
        return 0
    fi

    if [ -z "$CONVERSATION_AUDIT_CLOSE_FD" ] \
        || ! conversation_audit_coordinator_fd_is_pinned "$CONVERSATION_AUDIT_CLOSE_FD"; then
        echo "ERROR: The pinned conversation audit closure coordinator could not be verified." >&2
        close_status=1
    elif ! run_bounded_conversation_audit_close; then
        echo "ERROR: Conversation audit exposure could not be closed by the coordinator." >&2
        close_status=1
    fi

    if [ "$close_status" -ne 0 ]; then
        echo "ERROR: Stopping the backend because conversation audit closure was not proven." >&2
        if ! stop_and_verify_conversation_audit_cleanup_service backend; then
            echo "ERROR: Could not prove the backend stopped after audit closure failed." >&2
        fi
    fi
    CONVERSATION_AUDIT_EXPOSURE_MAY_BE_OPEN=false
    return "$close_status"
}

cleanup_conversation_audit_startup_gate() {
    if [ "$CONVERSATION_AUDIT_STARTUP_CLEANUP_RUNNING" = true ]; then
        return 0
    fi
    CONVERSATION_AUDIT_STARTUP_CLEANUP_RUNNING=true

    # A promoted Docker/Compose proof or frontend start must be unable to
    # continue mutating state while fail-closed recovery runs.
    terminate_conversation_audit_supervised_command_tree

    if conversation_audit_startup_recovery_required; then
        if ! stop_and_verify_conversation_audit_cleanup_service frontend; then
            echo "ERROR: Could not prove the frontend stopped during audit startup cleanup." >&2
        fi
    fi

    terminate_conversation_audit_activator_tree

    if conversation_audit_startup_recovery_required; then
        close_possible_conversation_audit_exposure || true
    fi
    close_conversation_audit_activator_fd
    close_conversation_audit_close_fd
}

conversation_audit_startup_recovery_required() {
    [ "$CONVERSATION_AUDIT_STARTUP_GATE_ARMED" = true ] \
        || [ "$CONVERSATION_AUDIT_EXPOSURE_MAY_BE_OPEN" = true ]
}

handle_conversation_audit_startup_exit() {
    local status=$?

    trap - EXIT
    trap ':' INT TERM
    cleanup_conversation_audit_startup_gate
    exit "$status"
}

handle_conversation_audit_startup_signal() {
    local status="$1"

    if [ -n "$CONVERSATION_AUDIT_PENDING_SIGNAL_STATUS" ]; then
        # The first signal owns the externally visible status, including the
        # narrow transition from FINALIZING to IDLE.
        status="$CONVERSATION_AUDIT_PENDING_SIGNAL_STATUS"
    fi
    case "$CONVERSATION_AUDIT_SUPERVISED_COMMAND_STATE" in
        STARTING|RUNNING|CANCELLING|FINALIZING)
            if [ -z "$CONVERSATION_AUDIT_PENDING_SIGNAL_STATUS" ]; then
                CONVERSATION_AUDIT_PENDING_SIGNAL_STATUS="$status"
            fi
            return 0
            ;;
    esac

    if [ "$CONVERSATION_AUDIT_ACTIVATOR_SPAWN_IN_PROGRESS" = true ]; then
        if [ -z "$CONVERSATION_AUDIT_PENDING_SIGNAL_STATUS" ]; then
            CONVERSATION_AUDIT_PENDING_SIGNAL_STATUS="$status"
        fi
        return 0
    fi

    trap - EXIT
    trap ':' INT TERM
    cleanup_conversation_audit_startup_gate
    exit "$status"
}

conversation_audit_test_spawn_checkpoint() {
    local phase="$1"
    local attempt ready_file="${CONVERSATION_AUDIT_TEST_SPAWN_READY_FILE:-}"
    local signal_name="${CONVERSATION_AUDIT_TEST_SPAWN_SIGNAL:-}"
    local test_root="${TMPDIR:-/tmp}"

    # Deterministic race coverage is available only to the hermetic fixture.
    # Normal workspaces and the bundled /workspace runtime cannot activate it.
    [ "${START_DEV_BOT_TEST_MODE:-0}" = 1 ] \
        && [[ "$PROJECT_DIR" == "$test_root/"* ]] \
        && [ "${CONVERSATION_AUDIT_TEST_SPAWN_PHASE:-}" = "$phase" ] \
        || return 0
    case "$signal_name" in
        INT|TERM)
            ;;
        *)
            return 0
            ;;
    esac
    if [[ "$ready_file" == "$PROJECT_DIR/"* ]] && [ ! -L "$ready_file" ]; then
        for attempt in $(seq 1 200); do
            [ ! -s "$ready_file" ] || break
            /bin/sleep 0.01 || true
        done
    fi
    kill -s "$signal_name" "$$"
}

require_frontend_stopped() {
    local running_services

    if ! running_services=$("${COMPOSE[@]}" "${COMPOSE_ENV_FILES[@]}" "${COMPOSE_FILES[@]}" \
        ps --status running --services frontend \
        {OUTBOUND_ATTEMPT_STAGE_LOCK_FD}>&-); then
        echo "ERROR: Could not verify that the frontend is stopped while conversation audit activation is gated." >&2
        return 1
    fi
    if [ -n "$running_services" ]; then
        echo "ERROR: Frontend remained running before conversation audit activation completed." >&2
        return 1
    fi
}

run_conversation_audit_activator() {
    local activation_status attempt isolated_pgid pending_signal_status proc_ppid proc_session proc_state proc_stat_fields proc_stat_line

    if ! conversation_audit_coordinator_fd_is_pinned "$CONVERSATION_AUDIT_ACTIVATOR_FD"; then
        echo "ERROR: The pinned conversation audit activation coordinator could not be verified." >&2
        return 1
    fi
    CONVERSATION_AUDIT_EXPOSURE_MAY_BE_OPEN=true
    CONVERSATION_AUDIT_ACTIVATOR_SPAWN_IN_PROGRESS=true
    # Keep PID == PGID == SID deterministic even if a caller enabled job
    # control before invoking this non-interactive entrypoint.
    set +m
    CONVERSATION_AUDIT_ACTIVATION_PROJECT_DIR="$PROJECT_DIR" \
        CONVERSATION_AUDIT_ACTIVATION_RUNTIME_ENV_FILE="$CONVERSATION_AUDIT_RUNTIME_ENV_FILE" \
        setsid --wait bash -c 'kill -STOP "$$"; exec bash "$1"' \
            conversation-audit-activation \
            "/proc/self/fd/$CONVERSATION_AUDIT_ACTIVATOR_FD" </dev/null \
            {OUTBOUND_ATTEMPT_STAGE_LOCK_FD}>&- &
    conversation_audit_test_spawn_checkpoint before-pid
    CONVERSATION_AUDIT_ACTIVATOR_PID=$!
    conversation_audit_test_spawn_checkpoint before-pgid
    CONVERSATION_AUDIT_ACTIVATOR_PGID="$CONVERSATION_AUDIT_ACTIVATOR_PID"
    isolated_pgid=""
    proc_session=""
    proc_state=""
    # `setsid` may need a few scheduler ticks before procfs reflects the new
    # group. Keep the handshake bounded; a coordinator that already exited is
    # collected below with its original status.
    for attempt in $(seq 1 50); do
        if [ ! -r "/proc/$CONVERSATION_AUDIT_ACTIVATOR_PID/stat" ]; then
            break
        fi
        proc_stat_line="$(<"/proc/$CONVERSATION_AUDIT_ACTIVATOR_PID/stat")"
        proc_stat_fields="${proc_stat_line##*) }"
        read -r proc_state proc_ppid isolated_pgid proc_session _ <<< "$proc_stat_fields"
        if [ "$proc_state" = T ] \
            && [ "$isolated_pgid" = "$CONVERSATION_AUDIT_ACTIVATOR_PID" ] \
            && [ "$proc_session" = "$CONVERSATION_AUDIT_ACTIVATOR_PID" ]; then
            break
        fi
        /bin/sleep 0.01 || true
    done
    if [ "$proc_state" = T ] \
        && [ "$isolated_pgid" = "$CONVERSATION_AUDIT_ACTIVATOR_PID" ] \
        && [ "$proc_session" = "$CONVERSATION_AUDIT_ACTIVATOR_PID" ]; then
        CONVERSATION_AUDIT_ACTIVATOR_PGID="$isolated_pgid"
    else
        echo "ERROR: Conversation audit activation did not enter a dedicated process group." >&2
        terminate_conversation_audit_activator_tree
        CONVERSATION_AUDIT_ACTIVATOR_SPAWN_IN_PROGRESS=false
        if [ -n "$CONVERSATION_AUDIT_PENDING_SIGNAL_STATUS" ]; then
            pending_signal_status="$CONVERSATION_AUDIT_PENDING_SIGNAL_STATUS"
            CONVERSATION_AUDIT_PENDING_SIGNAL_STATUS=""
            handle_conversation_audit_startup_signal "$pending_signal_status"
        fi
        return 1
    fi
    CONVERSATION_AUDIT_ACTIVATOR_SPAWN_IN_PROGRESS=false
    if [ -n "$CONVERSATION_AUDIT_PENDING_SIGNAL_STATUS" ]; then
        pending_signal_status="$CONVERSATION_AUDIT_PENDING_SIGNAL_STATUS"
        CONVERSATION_AUDIT_PENDING_SIGNAL_STATUS=""
        handle_conversation_audit_startup_signal "$pending_signal_status"
    fi
    if ! kill -CONT -- "-$CONVERSATION_AUDIT_ACTIVATOR_PGID" 2>/dev/null; then
        echo "ERROR: Conversation audit activation start gate could not be released." >&2
        terminate_conversation_audit_activator_tree
        return 1
    fi
    if wait "$CONVERSATION_AUDIT_ACTIVATOR_PID"; then
        activation_status=0
    else
        activation_status=$?
    fi
    CONVERSATION_AUDIT_ACTIVATOR_PID=""
    CONVERSATION_AUDIT_ACTIVATOR_PGID=""
    close_conversation_audit_activator_fd

    if [ "$activation_status" -ne 0 ]; then
        echo "ERROR: Local conversation audit activation did not complete; closing any possible exposure." >&2
        return "$activation_status"
    fi
}
