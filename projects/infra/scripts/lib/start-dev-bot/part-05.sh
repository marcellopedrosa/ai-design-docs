terminate_conversation_audit_activator_tree() {
    local attempt

    if [ -z "$CONVERSATION_AUDIT_ACTIVATOR_PID" ]; then
        return 0
    fi

    # Always use TERM for the isolated process group. In particular, forwarding
    # INT to an asynchronous Bash child is unsafe because Bash may inherit it as
    # ignored. The entrypoint's externally visible 130/143 status is preserved
    # independently by its signal handler.
    if [ -n "$CONVERSATION_AUDIT_ACTIVATOR_PGID" ]; then
        kill -TERM -- "-$CONVERSATION_AUDIT_ACTIVATOR_PGID" 2>/dev/null \
            || kill -TERM -- "$CONVERSATION_AUDIT_ACTIVATOR_PID" 2>/dev/null \
            || true
        # The supervised bootstrap waits in SIGSTOP until its group is proven.
        # CONT lets a pending TERM take effect without waiting for forced KILL.
        kill -CONT -- "-$CONVERSATION_AUDIT_ACTIVATOR_PGID" 2>/dev/null || true
    else
        kill -TERM -- "$CONVERSATION_AUDIT_ACTIVATOR_PID" 2>/dev/null || true
    fi

    for ((attempt = 0; attempt < CONVERSATION_AUDIT_SHUTDOWN_GRACE_SECONDS; attempt++)); do
        if [ -n "$CONVERSATION_AUDIT_ACTIVATOR_PGID" ]; then
            kill -0 -- "-$CONVERSATION_AUDIT_ACTIVATOR_PGID" 2>/dev/null || break
        else
            kill -0 -- "$CONVERSATION_AUDIT_ACTIVATOR_PID" 2>/dev/null || break
        fi
        /bin/sleep 1 || true
    done

    if [ -n "$CONVERSATION_AUDIT_ACTIVATOR_PGID" ] \
        && kill -0 -- "-$CONVERSATION_AUDIT_ACTIVATOR_PGID" 2>/dev/null; then
        kill -KILL -- "-$CONVERSATION_AUDIT_ACTIVATOR_PGID" 2>/dev/null || true
    elif kill -0 -- "$CONVERSATION_AUDIT_ACTIVATOR_PID" 2>/dev/null; then
        kill -KILL -- "$CONVERSATION_AUDIT_ACTIVATOR_PID" 2>/dev/null || true
    fi
    wait "$CONVERSATION_AUDIT_ACTIVATOR_PID" 2>/dev/null || true
    CONVERSATION_AUDIT_ACTIVATOR_PID=""
    CONVERSATION_AUDIT_ACTIVATOR_PGID=""
}

conversation_audit_supervised_command_identity_is_current() {
    local proc_cmajflt proc_cminflt proc_cstime proc_cutime proc_flags proc_itrealvalue
    local proc_majflt proc_minflt proc_nice proc_num_threads proc_pgrp proc_ppid
    local proc_priority proc_session proc_starttime proc_state proc_stime proc_tpgid
    local proc_tty_nr proc_utime proc_stat_fields proc_stat_line

    [ -n "$CONVERSATION_AUDIT_SUPERVISED_COMMAND_PID" ] \
        && [ -n "$CONVERSATION_AUDIT_SUPERVISED_COMMAND_STARTTIME" ] \
        && [ -r "/proc/$CONVERSATION_AUDIT_SUPERVISED_COMMAND_PID/stat" ] \
        || return 1
    proc_stat_line="$(<"/proc/$CONVERSATION_AUDIT_SUPERVISED_COMMAND_PID/stat")"
    proc_stat_fields="${proc_stat_line##*) }"
    read -r proc_state proc_ppid proc_pgrp proc_session proc_tty_nr proc_tpgid \
        proc_flags proc_minflt proc_cminflt proc_majflt proc_cmajflt proc_utime \
        proc_stime proc_cutime proc_cstime proc_priority proc_nice proc_num_threads \
        proc_itrealvalue proc_starttime _ <<< "$proc_stat_fields"
    [ "$proc_starttime" = "$CONVERSATION_AUDIT_SUPERVISED_COMMAND_STARTTIME" ] \
        || return 1
    if [ "$CONVERSATION_AUDIT_SUPERVISED_COMMAND_GROUP_VERIFIED" = true ]; then
        [ "$proc_pgrp" = "$CONVERSATION_AUDIT_SUPERVISED_COMMAND_PGID" ] \
            && [ "$proc_session" = "$CONVERSATION_AUDIT_SUPERVISED_COMMAND_PID" ]
    fi
}

conversation_audit_supervised_command_exit_observed() {
    local proc_cmajflt proc_cminflt proc_cstime proc_cutime proc_flags proc_itrealvalue
    local proc_majflt proc_minflt proc_nice proc_num_threads proc_pgrp proc_ppid
    local proc_priority proc_session proc_starttime proc_state proc_stime proc_tpgid
    local proc_tty_nr proc_utime proc_stat_fields proc_stat_line

    if [ ! -r "/proc/$CONVERSATION_AUDIT_SUPERVISED_COMMAND_PID/stat" ]; then
        return 0
    fi
    proc_stat_line="$(<"/proc/$CONVERSATION_AUDIT_SUPERVISED_COMMAND_PID/stat")"
    proc_stat_fields="${proc_stat_line##*) }"
    read -r proc_state proc_ppid proc_pgrp proc_session proc_tty_nr proc_tpgid \
        proc_flags proc_minflt proc_cminflt proc_majflt proc_cmajflt proc_utime \
        proc_stime proc_cutime proc_cstime proc_priority proc_nice proc_num_threads \
        proc_itrealvalue proc_starttime _ <<< "$proc_stat_fields"
    if [ "$proc_starttime" != "$CONVERSATION_AUDIT_SUPERVISED_COMMAND_STARTTIME" ]; then
        return 2
    fi
    if [ "$CONVERSATION_AUDIT_SUPERVISED_COMMAND_GROUP_VERIFIED" = true ] \
        && { [ "$proc_pgrp" != "$CONVERSATION_AUDIT_SUPERVISED_COMMAND_PGID" ] \
            || [ "$proc_session" != "$CONVERSATION_AUDIT_SUPERVISED_COMMAND_PID" ]; }; then
        return 2
    fi
    [ "$proc_state" = Z ]
}

wait_for_conversation_audit_supervised_command() {
    local ignore_pending_signal="${1:-false}"
    local observation_status wait_status=0

    [ -n "$CONVERSATION_AUDIT_SUPERVISED_COMMAND_PID" ] || return 0
    while :; do
        if [ "$ignore_pending_signal" != true ] \
            && [ -n "$CONVERSATION_AUDIT_PENDING_SIGNAL_STATUS" ]; then
            return 130
        fi
        if conversation_audit_supervised_command_exit_observed; then
            if wait "$CONVERSATION_AUDIT_SUPERVISED_COMMAND_PID"; then
                wait_status=0
            else
                wait_status=$?
            fi
            return "$wait_status"
        else
            observation_status=$?
            [ "$observation_status" -ne 2 ] || return 125
        fi
        # Polling avoids a consumed-signal/lost-wakeup gap before a future wait.
        /bin/sleep 0.01 || true
    done
}

conversation_audit_supervised_group_has_live_descendants() {
    local member_pid member_pgrp member_session member_state member_stat_fields
    local member_stat_line member_stat_path

    for member_stat_path in /proc/[0-9]*/stat; do
        member_pid="${member_stat_path#/proc/}"
        member_pid="${member_pid%/stat}"
        [ "$member_pid" != "$CONVERSATION_AUDIT_SUPERVISED_COMMAND_PID" ] \
            || continue
        # A process may exit after the glob is expanded but before procfs is
        # read. Use cat so the disappearing-path diagnostic is redirected with
        # the command itself; a shell input-redirection failure bypasses the
        # read command's stderr redirection in Bash.
        if ! member_stat_line="$(cat -- "$member_stat_path" 2>/dev/null)"; then
            continue
        fi
        member_stat_fields="${member_stat_line##*) }"
        read -r member_state _ member_pgrp member_session _ <<< "$member_stat_fields"
        if [ "$member_pgrp" = "$CONVERSATION_AUDIT_SUPERVISED_COMMAND_PGID" ] \
            && [ "$member_session" = "$CONVERSATION_AUDIT_SUPERVISED_COMMAND_PID" ] \
            && [ "$member_state" != Z ] \
            && [ "$member_state" != X ]; then
            return 0
        fi
    done
    return 1
}

signal_conversation_audit_supervised_live_descendants() {
    local signal_name="$1" member_pid member_stat_fields member_stat_line member_stat_path
    local -a current_fields member_fields

    for member_stat_path in /proc/[0-9]*/stat; do
        member_pid="${member_stat_path#/proc/}"
        member_pid="${member_pid%/stat}"
        [ "$member_pid" != "$CONVERSATION_AUDIT_SUPERVISED_COMMAND_PID" ] \
            || continue
        if ! member_stat_line="$(cat -- "$member_stat_path" 2>/dev/null)"; then
            continue
        fi
        member_stat_fields="${member_stat_line##*) }"
        read -r -a member_fields <<< "$member_stat_fields"
        [ "${#member_fields[@]}" -ge 20 ] || continue
        [ "${member_fields[2]}" = "$CONVERSATION_AUDIT_SUPERVISED_COMMAND_PGID" ] \
            && [ "${member_fields[3]}" = "$CONVERSATION_AUDIT_SUPERVISED_COMMAND_PID" ] \
            && [ "${member_fields[0]}" != Z ] \
            && [ "${member_fields[0]}" != X ] \
            || continue

        # Re-read starttime, pgrp and SID immediately before addressing this
        # PID. A recycled or migrated process is never signalled.
        if ! IFS= read -r member_stat_line < "$member_stat_path" 2>/dev/null; then
            continue
        fi
        member_stat_fields="${member_stat_line##*) }"
        read -r -a current_fields <<< "$member_stat_fields"
        [ "${#current_fields[@]}" -ge 20 ] || continue
        [ "${current_fields[19]}" = "${member_fields[19]}" ] \
            && [ "${current_fields[2]}" = "$CONVERSATION_AUDIT_SUPERVISED_COMMAND_PGID" ] \
            && [ "${current_fields[3]}" = "$CONVERSATION_AUDIT_SUPERVISED_COMMAND_PID" ] \
            && [ "${current_fields[0]}" != Z ] \
            && [ "${current_fields[0]}" != X ] \
            || continue
        kill -s "$signal_name" -- "$member_pid" 2>/dev/null || true
    done
}

drain_conversation_audit_supervised_command_group() {
    local attempt

    [ "$CONVERSATION_AUDIT_SUPERVISED_COMMAND_GROUP_VERIFIED" = true ] \
        && [ -n "$CONVERSATION_AUDIT_SUPERVISED_COMMAND_PGID" ] \
        || return 0
    for attempt in $(seq 1 20); do
        conversation_audit_supervised_group_has_live_descendants || return 0
        /bin/sleep 0.01 || true
    done

    # A bounded command is not complete while a pipeline/background descendant
    # can still mutate the promoted environment. Revalidate the unreaped leader
    # before every group signal; after wait, this function is never called.
    if conversation_audit_supervised_command_identity_is_current; then
        kill -TERM -- "-$CONVERSATION_AUDIT_SUPERVISED_COMMAND_PGID" 2>/dev/null || true
        kill -CONT -- "-$CONVERSATION_AUDIT_SUPERVISED_COMMAND_PGID" 2>/dev/null || true
    else
        signal_conversation_audit_supervised_live_descendants TERM
        signal_conversation_audit_supervised_live_descendants CONT
    fi
    for ((attempt = 0; attempt < CONVERSATION_AUDIT_CLEANUP_KILL_AFTER_SECONDS; attempt++)); do
        conversation_audit_supervised_group_has_live_descendants || return 0
        /bin/sleep 1 || true
    done
    if conversation_audit_supervised_command_identity_is_current; then
        kill -KILL -- "-$CONVERSATION_AUDIT_SUPERVISED_COMMAND_PGID" 2>/dev/null || true
    else
        signal_conversation_audit_supervised_live_descendants KILL
    fi
    for attempt in $(seq 1 100); do
        conversation_audit_supervised_group_has_live_descendants || return 0
        /bin/sleep 0.01 || true
    done
    return 1
}

terminate_conversation_audit_supervised_command_tree() {
    local attempt identity_is_current=false use_verified_group=false

    [ -n "$CONVERSATION_AUDIT_SUPERVISED_COMMAND_PID" ] || return 0
    CONVERSATION_AUDIT_SUPERVISED_COMMAND_STATE=CANCELLING
    if conversation_audit_supervised_command_identity_is_current; then
        identity_is_current=true
        if [ "$CONVERSATION_AUDIT_SUPERVISED_COMMAND_GROUP_VERIFIED" = true ] \
            && [ -n "$CONVERSATION_AUDIT_SUPERVISED_COMMAND_PGID" ]; then
            use_verified_group=true
        fi
    fi

    if [ "$identity_is_current" = true ]; then
        if [ "$use_verified_group" = true ]; then
            kill -TERM -- "-$CONVERSATION_AUDIT_SUPERVISED_COMMAND_PGID" 2>/dev/null || true
            kill -CONT -- "-$CONVERSATION_AUDIT_SUPERVISED_COMMAND_PGID" 2>/dev/null || true
        else
            # Before PID == PGID == SID is proven, never address a process group.
            kill -TERM -- "$CONVERSATION_AUDIT_SUPERVISED_COMMAND_PID" 2>/dev/null || true
            kill -CONT -- "$CONVERSATION_AUDIT_SUPERVISED_COMMAND_PID" 2>/dev/null || true
        fi
    fi
    if [ "$CONVERSATION_AUDIT_SUPERVISED_COMMAND_GROUP_VERIFIED" = true ]; then
        signal_conversation_audit_supervised_live_descendants TERM
        signal_conversation_audit_supervised_live_descendants CONT
    fi

    for ((attempt = 0; attempt < CONVERSATION_AUDIT_SHUTDOWN_GRACE_SECONDS; attempt++)); do
        if [ "$use_verified_group" = true ]; then
            kill -0 -- "-$CONVERSATION_AUDIT_SUPERVISED_COMMAND_PGID" 2>/dev/null || break
        else
            kill -0 -- "$CONVERSATION_AUDIT_SUPERVISED_COMMAND_PID" 2>/dev/null || break
        fi
        /bin/sleep 1 || true
    done

    if [ "$use_verified_group" = true ] \
        && conversation_audit_supervised_command_identity_is_current; then
        kill -KILL -- "-$CONVERSATION_AUDIT_SUPERVISED_COMMAND_PGID" 2>/dev/null || true
    elif conversation_audit_supervised_command_identity_is_current \
        && kill -0 -- "$CONVERSATION_AUDIT_SUPERVISED_COMMAND_PID" 2>/dev/null; then
        kill -KILL -- "$CONVERSATION_AUDIT_SUPERVISED_COMMAND_PID" 2>/dev/null || true
    fi
    if [ "$CONVERSATION_AUDIT_SUPERVISED_COMMAND_GROUP_VERIFIED" = true ]; then
        signal_conversation_audit_supervised_live_descendants KILL
        for attempt in $(seq 1 100); do
            conversation_audit_supervised_group_has_live_descendants || break
            /bin/sleep 0.01 || true
        done
    fi
    wait_for_conversation_audit_supervised_command true >/dev/null 2>&1 || true
}

finalize_conversation_audit_supervised_command() {
    local pending_signal_status="${1:-}"

    CONVERSATION_AUDIT_SUPERVISED_COMMAND_STATE=FINALIZING
    conversation_audit_test_supervised_finalizing_checkpoint
    CONVERSATION_AUDIT_SUPERVISED_COMMAND_PID=""
    CONVERSATION_AUDIT_SUPERVISED_COMMAND_PGID=""
    CONVERSATION_AUDIT_SUPERVISED_COMMAND_STARTTIME=""
    CONVERSATION_AUDIT_SUPERVISED_COMMAND_GROUP_VERIFIED=false
    if [ -z "$pending_signal_status" ] \
        && [ -n "$CONVERSATION_AUDIT_PENDING_SIGNAL_STATUS" ]; then
        pending_signal_status="$CONVERSATION_AUDIT_PENDING_SIGNAL_STATUS"
    fi
    if [ -n "$pending_signal_status" ]; then
        # Keep FINALIZING until the first signal is captured and traps are
        # non-recursive. Only then publish IDLE and begin fail-closed recovery.
        trap - EXIT
        trap ':' INT TERM
        CONVERSATION_AUDIT_PENDING_SIGNAL_STATUS=""
        CONVERSATION_AUDIT_SUPERVISED_COMMAND_STATE=IDLE
        cleanup_conversation_audit_startup_gate
        exit "$pending_signal_status"
    fi
    CONVERSATION_AUDIT_SUPERVISED_COMMAND_STATE=IDLE
    if [ -n "$CONVERSATION_AUDIT_PENDING_SIGNAL_STATUS" ]; then
        # A signal delivered after the first read but before IDLE was latched by
        # the FINALIZING handler. Dispatch it before returning to the caller.
        pending_signal_status="$CONVERSATION_AUDIT_PENDING_SIGNAL_STATUS"
        trap - EXIT
        trap ':' INT TERM
        CONVERSATION_AUDIT_PENDING_SIGNAL_STATUS=""
        cleanup_conversation_audit_startup_gate
        exit "$pending_signal_status"
    fi
}

record_conversation_audit_test_supervised_command_state() {
    local state_file="${CONVERSATION_AUDIT_TEST_SUPERVISED_STATE_FILE:-}"
    local state_tmp=""
    local test_root="${TMPDIR:-/tmp}"

    [ "${START_DEV_BOT_TEST_MODE:-0}" = 1 ] \
        && [[ "$PROJECT_DIR" == "$test_root/"* ]] \
        && [[ "$state_file" == "$PROJECT_DIR/"* ]] \
        && [ ! -L "$state_file" ] \
        && { [ ! -e "$state_file" ] || [ -f "$state_file" ]; } \
        || return 0
    state_tmp="${state_file}.tmp.$$"
    (
        umask 077
        set -C
        printf '%s %s %s\n' \
            "$CONVERSATION_AUDIT_SUPERVISED_COMMAND_PID" \
            "$CONVERSATION_AUDIT_SUPERVISED_COMMAND_PGID" \
            "$CONVERSATION_AUDIT_SUPERVISED_COMMAND_STARTTIME" \
            > "$state_tmp"
    )
    mv -f -- "$state_tmp" "$state_file"
}

conversation_audit_test_supervised_finalizing_checkpoint() {
    local signal_name="${CONVERSATION_AUDIT_TEST_FINALIZING_SIGNAL:-}"
    local second_signal_name="${CONVERSATION_AUDIT_TEST_FINALIZING_SECOND_SIGNAL:-}"
    local test_root="${TMPDIR:-/tmp}"

    [ "${START_DEV_BOT_TEST_MODE:-0}" = 1 ] \
        && [[ "$PROJECT_DIR" == "$test_root/"* ]] \
        || return 0
    case "$signal_name" in
        INT|TERM)
            ;;
        *)
            return 0
            ;;
    esac
    # One-shot: cleanup commands must not retrigger the deterministic checkpoint.
    CONVERSATION_AUDIT_TEST_FINALIZING_SIGNAL=""
    CONVERSATION_AUDIT_TEST_FINALIZING_SECOND_SIGNAL=""
    kill -s "$signal_name" "$$"
    case "$second_signal_name" in
        INT|TERM)
            kill -s "$second_signal_name" "$$"
            ;;
    esac
}

conversation_audit_test_before_supervised_wait_checkpoint() {
    local signal_name="${CONVERSATION_AUDIT_TEST_BEFORE_WAIT_SIGNAL:-}"
    local ready_file="${CONVERSATION_AUDIT_TEST_BEFORE_WAIT_READY_FILE:-}"
    local test_root="${TMPDIR:-/tmp}" attempt

    [ "${START_DEV_BOT_TEST_MODE:-0}" = 1 ] \
        && [[ "$PROJECT_DIR" == "$test_root/"* ]] \
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
            [ -s "$ready_file" ] && break
            /bin/sleep 0.01 || true
        done
    fi
    CONVERSATION_AUDIT_TEST_BEFORE_WAIT_SIGNAL=""
    kill -s "$signal_name" "$$"
}
