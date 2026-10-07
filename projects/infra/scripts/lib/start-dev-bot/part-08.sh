# Recreate only the stateless backend process. Dependencies were proved during
# Prepare, so --no-deps prevents a backend update from replacing Redis,
# PostgreSQL or Keycloak as an incidental side effect.
if ! "${COMPOSE[@]}" "${COMPOSE_ENV_FILES[@]}" "${COMPOSE_FILES[@]}" \
    up -d --no-build --no-deps --force-recreate backend \
    {OUTBOUND_ATTEMPT_STAGE_LOCK_FD}>&-; then
    echo "ERROR: Docker Compose did not complete the DEV backend cutover."
    print_critical_startup_diagnostics
    exit 1
fi
if ! wait_for_backend_readiness; then
    exit 1
fi
if ! require_frontend_stopped; then
    exit 1
fi

# Ngrok is stateless and must resolve the address of the new backend container.
# Recreate it only after local readiness, without traversing dependencies.
if ! "${COMPOSE[@]}" "${COMPOSE_ENV_FILES[@]}" "${COMPOSE_FILES[@]}" \
    up -d --no-build --no-deps --force-recreate ngrok-bot \
    {OUTBOUND_ATTEMPT_STAGE_LOCK_FD}>&-; then
    echo "ERROR: Ngrok did not start after the DEV backend became ready." >&2
    exit 1
fi
if run_conversation_audit_activator; then
    :
else
    conversation_audit_activation_status=$?
    exit "$conversation_audit_activation_status"
fi

# The coordinator publishes the owner-only overlay atomically. Reopen it with
# the same metadata/inode defenses used at startup, then prove that shell
# state, resolved Compose input and the running backend agree before exposing
# the frontend. Compose JSON and the tenant ID flow only through pipes.
import_conversation_audit_runtime_env
if ! validate_promoted_conversation_audit_runtime \
    || ! validate_promoted_conversation_audit_compose \
    || ! validate_promoted_conversation_audit_backend; then
    exit 1
fi
write_outbound_attempt_commit_receipt

echo "Waiting for Ngrok to initialize (up to 60 seconds)..."

# Fetch the public URL from ngrok API (exposed on port 4041 by the bot container)
NGROK_URL=""
for _ in $(seq 1 30); do
    NGROK_URL=$(curl --fail --silent --show-error \
        --connect-timeout 1 --max-time 1 \
        http://localhost:4041/api/tunnels 2>/dev/null \
        | grep -o '"public_url":"https://[^"]*"' \
        | head -n 1 \
        | cut -d'"' -f4 || true)
    [ -n "$NGROK_URL" ] && break
    sleep 1
done

if [ -z "$NGROK_URL" ]; then
    echo "ERROR: Could not get public URL from Ngrok."
    echo "Configured public URL: $APP_BASE_URL"
    echo "Ngrok service status:"
    run_bounded_conversation_audit_cleanup_command \
        "${COMPOSE[@]}" "${COMPOSE_ENV_FILES[@]}" "${COMPOSE_FILES[@]}" \
        ps -a ngrok-bot || true
    echo "Last Ngrok log lines:"
    run_bounded_conversation_audit_cleanup_command \
        "${COMPOSE[@]}" "${COMPOSE_ENV_FILES[@]}" "${COMPOSE_FILES[@]}" \
        logs --no-color --tail 100 ngrok-bot || true
    exit 1
fi

NGROK_URL="${NGROK_URL%/}"
if [ "$NGROK_URL" != "$APP_BASE_URL" ]; then
    echo "ERROR: Ngrok public URL does not match APP_BASE_URL."
    echo "Configured public URL: $APP_BASE_URL"
    echo "Discovered public URL: $NGROK_URL"
    exit 1
fi
if ! wait_for_public_backend_readiness "$NGROK_URL"; then
    exit 1
fi

if ! run_bounded_conversation_audit_post_promotion_compose \
    up -d --build --force-recreate frontend; then
    echo "ERROR: Frontend did not start after conversation audit activation completed." >&2
    exit 1
fi
if ! run_bounded_conversation_audit_frontend_running_proof; then
    echo "ERROR: Could not verify the frontend state after conversation audit activation." >&2
    exit 1
fi
CONVERSATION_AUDIT_STARTUP_GATE_ARMED=false
CONVERSATION_AUDIT_EXPOSURE_MAY_BE_OPEN=false
close_conversation_audit_close_fd

echo "=========================================================="
echo "Hybrid Local Mode is Running!"
echo ""
echo "UI / Frontend:   http://localhost:3000"
echo "Keycloak Admin:  http://localhost:8180"
echo ""
echo "WEBHOOK URL FOR BOTS (Telegram/WhatsApp):"
echo "   -> $NGROK_URL/api/..."
echo "=========================================================="
