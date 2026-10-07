if (
    cd "$FIXTURE_DIR"
    START_DEV_BOT_TEST_MODE=1 \
    OUTBOUND_HMAC_TEST_FAIL_AFTER_SOURCE=1 \
    ./start-dev-bot.sh --stage-outbound-hmac-keyring \
        "$STAGING_ADD_FILE" "$OUTBOUND_KEY_ID"
) >> "$OUTPUT_FILE" 2>&1; then
    fail "DEV staging failpoint did not interrupt between source and environment publication"
fi
cmp -s "$STAGING_ADD_FILE" "$OUTBOUND_KEYRING_FILE" \
    || fail "interrupted switch staging corrupted the outbound keyring"
grep -qx "CONVERSATION_OUTBOUND_ATTEMPT_HMAC_ACTIVE_KEY_ID=${SECOND_OUTBOUND_KEY_ID}" \
    "$GENERATED_ENV_FILE" \
    || fail "interrupted switch staging changed the active-key environment setting"
(
    cd "$FIXTURE_DIR"
    ./start-dev-bot.sh --prepare-env-only
) >> "$OUTPUT_FILE" 2>&1

STAGING_MAX_FILE="$STAGING_CANDIDATE_DIR/max-32.json"
STAGING_TOO_MANY_FILE="$STAGING_CANDIDATE_DIR/too-many-33.json"
cp "$STAGING_ADD_FILE" "$STAGING_MAX_FILE"
for extra_index in $(seq 3 32); do
    printf -v synthetic_raw 'synthetic-outbound-key-%09d' "$extra_index"
    synthetic_material="$(printf '%s' "$synthetic_raw" | openssl base64 -A)"
    jq --arg key_id "dev-outbound-extra-${extra_index}" \
        --arg key_material "$synthetic_material" \
        '.keys[$key_id] = $key_material' \
        "$STAGING_MAX_FILE" > "$STAGING_CANDIDATE_DIR/max-next.json"
    mv "$STAGING_CANDIDATE_DIR/max-next.json" "$STAGING_MAX_FILE"
done
chmod 600 "$STAGING_MAX_FILE"
(
    cd "$FIXTURE_DIR"
    ./start-dev-bot.sh --stage-outbound-hmac-keyring \
        "$STAGING_MAX_FILE" "$SECOND_OUTBOUND_KEY_ID"
) >> "$OUTPUT_FILE" 2>&1
[ "$(jq -er '.keys | length' "$OUTBOUND_KEYRING_FILE")" = "32" ] \
    || fail "DEV staging did not accept the documented 32-key boundary"

cp "$STAGING_MAX_FILE" "$STAGING_TOO_MANY_FILE"
printf -v synthetic_raw 'synthetic-outbound-key-%09d' 33
synthetic_material="$(printf '%s' "$synthetic_raw" | openssl base64 -A)"
jq --arg key_id 'dev-outbound-extra-33' \
    --arg key_material "$synthetic_material" \
    '.keys[$key_id] = $key_material' \
    "$STAGING_TOO_MANY_FILE" > "$STAGING_CANDIDATE_DIR/too-many-next.json"
mv "$STAGING_CANDIDATE_DIR/too-many-next.json" "$STAGING_TOO_MANY_FILE"
chmod 600 "$STAGING_TOO_MANY_FILE"
cp "$OUTBOUND_KEYRING_FILE" "$FIXTURE_DIR/outbound.before-too-many"
cp "$GENERATED_ENV_FILE" "$FIXTURE_DIR/env.before-too-many"
if (
    cd "$FIXTURE_DIR"
    ./start-dev-bot.sh --stage-outbound-hmac-keyring \
        "$STAGING_TOO_MANY_FILE" "$SECOND_OUTBOUND_KEY_ID"
) >> "$OUTPUT_FILE" 2>&1; then
    fail "DEV staging accepted more than 32 outbound keys"
fi
cmp -s "$FIXTURE_DIR/outbound.before-too-many" "$OUTBOUND_KEYRING_FILE" \
    && cmp -s "$FIXTURE_DIR/env.before-too-many" "$GENERATED_ENV_FILE" \
    || fail "33-key rejection changed source or environment"

run_fake_initializer_commit "$SECOND_OUTBOUND_KEY_ID"
(
    cd "$FIXTURE_DIR"
    ./start-dev-bot.sh --stage-outbound-hmac-keyring \
        "$STAGING_ADD_FILE" "$SECOND_OUTBOUND_KEY_ID"
) >> "$OUTPUT_FILE" 2>&1
cmp -s "$STAGING_ADD_FILE" "$OUTBOUND_KEYRING_FILE" \
    || fail "DEV staging did not return from 32 keys through a separate retirement"
run_fake_initializer_commit "$SECOND_OUTBOUND_KEY_ID"

printf '{"keys":{"%s":"%s","%s":"%s"}}\n' \
    "$SECOND_OUTBOUND_KEY_ID" "$second_outbound_key_material" \
    "$THIRD_OUTBOUND_KEY_ID" "$third_outbound_key_material" \
    > "$STAGING_MIXED_FILE"
printf '{"keys":{"%s":"%s"}}\n' \
    "$OUTBOUND_KEY_ID" "$outbound_key_material" \
    > "$STAGING_MISSING_ACTIVE_FILE"
printf '{"keys":{"%s":"%s","%s":"%s"}}\n' \
    "$OUTBOUND_KEY_ID" "$outbound_key_material" \
    "$SECOND_OUTBOUND_KEY_ID" "$outbound_key_material" \
    > "$STAGING_DUPLICATE_FILE"
printf '{"keys":{"%s":"%s","%s":"%s="}}\n' \
    "$OUTBOUND_KEY_ID" "$outbound_key_material" \
    "$SECOND_OUTBOUND_KEY_ID" "$second_outbound_key_material" \
    > "$STAGING_PADDING_FILE"
printf '{"keys":{"%s":"%s"}}\n' \
    "$SECOND_OUTBOUND_KEY_ID" "$second_outbound_key_material" \
    > "$STAGING_RETIRE_FILE"
chmod 600 \
    "$STAGING_MIXED_FILE" \
    "$STAGING_MISSING_ACTIVE_FILE" \
    "$STAGING_DUPLICATE_FILE" \
    "$STAGING_PADDING_FILE" \
    "$STAGING_RETIRE_FILE"
cp "$OUTBOUND_KEYRING_FILE" "$FIXTURE_DIR/outbound.before-invalid-staging"
cp "$GENERATED_ENV_FILE" "$FIXTURE_DIR/env.before-invalid-staging"

for invalid_case in \
    "$STAGING_MIXED_FILE:$SECOND_OUTBOUND_KEY_ID" \
    "$STAGING_MISSING_ACTIVE_FILE:$SECOND_OUTBOUND_KEY_ID" \
    "$STAGING_DUPLICATE_FILE:$OUTBOUND_KEY_ID" \
    "$STAGING_PADDING_FILE:$SECOND_OUTBOUND_KEY_ID"; do
    invalid_file="${invalid_case%%:*}"
    invalid_active_id="${invalid_case#*:}"
    if (
        cd "$FIXTURE_DIR"
        ./start-dev-bot.sh --stage-outbound-hmac-keyring \
            "$invalid_file" "$invalid_active_id"
    ) >> "$OUTPUT_FILE" 2>&1; then
        fail "DEV staging accepted an invalid or mixed outbound transition"
    fi
    cmp -s "$FIXTURE_DIR/outbound.before-invalid-staging" "$OUTBOUND_KEYRING_FILE" \
        || fail "invalid DEV staging changed the outbound source"
    cmp -s "$FIXTURE_DIR/env.before-invalid-staging" "$GENERATED_ENV_FILE" \
        || fail "invalid DEV staging changed the generated environment"
done

cp "$STAGING_ADD_FILE" "$STAGING_CANDIDATE_DIR/unsafe-mode.json"
chmod 640 "$STAGING_CANDIDATE_DIR/unsafe-mode.json"
ln -s "$STAGING_ADD_FILE" "$STAGING_CANDIDATE_DIR/candidate-link.json"
for unsafe_candidate in \
    "$STAGING_CANDIDATE_DIR/unsafe-mode.json" \
    "$STAGING_CANDIDATE_DIR/candidate-link.json"; do
    if (
        cd "$FIXTURE_DIR"
        ./start-dev-bot.sh --stage-outbound-hmac-keyring \
            "$unsafe_candidate" "$SECOND_OUTBOUND_KEY_ID"
    ) >> "$OUTPUT_FILE" 2>&1; then
        fail "DEV staging accepted an unsafe candidate source"
    fi
    cmp -s "$FIXTURE_DIR/outbound.before-invalid-staging" "$OUTBOUND_KEYRING_FILE" \
        && cmp -s "$FIXTURE_DIR/env.before-invalid-staging" "$GENERATED_ENV_FILE" \
        || fail "unsafe candidate rejection changed source or environment"
done

(
    cd "$FIXTURE_DIR"
    ./start-dev-bot.sh --stage-outbound-hmac-keyring \
        "$STAGING_RETIRE_FILE" "$SECOND_OUTBOUND_KEY_ID"
) >> "$OUTPUT_FILE" 2>&1
cmp -s "$STAGING_RETIRE_FILE" "$OUTBOUND_KEYRING_FILE" \
    || fail "DEV staging did not publish a separate retirement candidate"
grep -qx "CONVERSATION_OUTBOUND_ATTEMPT_HMAC_ACTIVE_KEY_ID=${SECOND_OUTBOUND_KEY_ID}" \
    "$GENERATED_ENV_FILE" \
    || fail "retirement staging changed the active outbound key"
(
    cd "$FIXTURE_DIR"
    ./start-dev-bot.sh --prepare-env-only
) >> "$OUTPUT_FILE" 2>&1
cmp -s "$STAGING_RETIRE_FILE" "$OUTBOUND_KEYRING_FILE" \
    || fail "bootstrap did not preserve the staged retirement candidate"
[ "$(grep -Fc 'build backend' "$TRANSITION_FAKE_DOCKER_LOG")" -ge 5 ] \
    || fail "fake initializer path did not exercise backend preparation"
[ "$(grep -Fc 'up -d --no-build --no-deps --force-recreate backend' "$TRANSITION_FAKE_DOCKER_LOG")" -ge 5 ] \
    || fail "fake initializer path did not exercise the gated backend cutover"
[ "$(grep -Fc 'up -d --build --force-recreate frontend' "$TRANSITION_FAKE_DOCKER_LOG")" -ge 3 ] \
    || fail "fake initializer path did not exercise post-activation frontend release"
if grep -Fq 'unexpected-sudo:' "$TRANSITION_FAKE_DOCKER_LOG"; then
    fail "fake initializer path unexpectedly elevated Docker"
fi

protected_value_index=0
for protected_value in \
    "$OUTBOUND_KEY_ID" \
    "$SECOND_OUTBOUND_KEY_ID" \
    "$THIRD_OUTBOUND_KEY_ID" \
    "$outbound_key_material" \
    "$second_outbound_key_material" \
    "$third_outbound_key_material" \
    "$(<"$OUTBOUND_COMMIT_RECEIPT_KEY_FILE")" \
    "$valid_receipt_signature" \
    'dev-outbound-extra-' \
    "$synthetic_raw" \
    "$synthetic_material" \
    "$STAGING_CANDIDATE_DIR"; do
    protected_value_index=$((protected_value_index + 1))
    [ -n "$protected_value" ] \
        || fail "outbound staging protected candidate fixture $protected_value_index is empty"
    if grep -Fq "$protected_value" "$OUTPUT_FILE"; then
        fail "outbound staging emitted protected candidate data (fixture $protected_value_index)"
    fi
done

RUNTIME_ENV_FILE="$FIXTURE_DIR/.dev-secrets/conversation-audit-runtime.env"
FAKE_DOCKER_DIR="$FIXTURE_DIR/fake-bin"
FAKE_DOCKER_LOG="$FIXTURE_DIR/fake-docker-arguments.log"
mkdir -p "$FAKE_DOCKER_DIR"
printf '%s\n' \
    '#!/usr/bin/env bash' \
    'if [ "${1:-}" = context ] && [ "${2:-}" = inspect ]; then printf "%s\n" unix:///var/run/docker.sock; exit 0; fi' \
    'if [ "${1:-}" = info ]; then exit 0; fi' \
    'if [ "${1:-}" = compose ] && [ "${2:-}" = version ]; then exit 0; fi' \
    '[ "${APP_CONVERSATION_AUDIT_ENABLED:-}" = true ] || exit 81' \
    '[ "${APP_CONVERSATION_AUDIT_API_ENABLED:-}" = false ] || exit 82' \
    '[ -v APP_CONVERSATION_AUDIT_ALLOWED_TENANT_IDS ] && [ -z "$APP_CONVERSATION_AUDIT_ALLOWED_TENANT_IDS" ] || exit 83' \
    '[ "${APP_CONVERSATION_AUDIT_LEGACY_READ_ENABLED:-}" = false ] || exit 84' \
    '[ "${APP_CONVERSATION_AUDIT_BACKFILL_ENABLED:-}" = false ] || exit 85' \
    '[ -v APP_CONVERSATION_AUDIT_BACKFILL_TENANT_ID ] && [ -z "$APP_CONVERSATION_AUDIT_BACKFILL_TENANT_ID" ] || exit 86' \
    'printf "%s\\n" "$@" > "$FAKE_DOCKER_LOG"' \
    > "$FAKE_DOCKER_DIR/docker"
chmod 700 "$FAKE_DOCKER_DIR/docker"
printf '%s\n' \
    'APP_CONVERSATION_AUDIT_ENABLED=true' \
    'APP_CONVERSATION_AUDIT_API_ENABLED=true' \
    'APP_CONVERSATION_AUDIT_ALLOWED_TENANT_IDS=13579bdf-2468-4ace-8bdf-0123456789ab' \
    'APP_CONVERSATION_AUDIT_LEGACY_READ_ENABLED=false' \
    'APP_CONVERSATION_AUDIT_BACKFILL_ENABLED=false' \
    'APP_CONVERSATION_AUDIT_BACKFILL_TENANT_ID=' \
    > "$RUNTIME_ENV_FILE"
chmod 600 "$RUNTIME_ENV_FILE"

if ! (
    cd "$FIXTURE_DIR"
    PATH="$FAKE_DOCKER_DIR:$PATH" \
    FAKE_DOCKER_LOG="$FAKE_DOCKER_LOG" \
    NGROK_AUTHTOKEN=synthetic-local-token \
    APP_BASE_URL=https://example.invalid \
    APP_CONVERSATION_AUDIT_ENABLED=false \
    APP_CONVERSATION_AUDIT_API_ENABLED=true \
    APP_CONVERSATION_AUDIT_ALLOWED_TENANT_IDS=2468ace0-1357-4bdf-9ace-fedcba987654 \
    APP_CONVERSATION_AUDIT_LEGACY_READ_ENABLED=true \
    APP_CONVERSATION_AUDIT_BACKFILL_ENABLED=true \
    APP_CONVERSATION_AUDIT_BACKFILL_TENANT_ID=2468ace0-1357-4bdf-9ace-fedcba987654 \
    ./start-dev-bot.sh --check
) >> "$OUTPUT_FILE" 2>&1; then
    tail -n 20 "$OUTPUT_FILE" >&2
    fail "bootstrap did not accept the regular audit runtime env overlay"
fi
if grep -Fxq "$RUNTIME_ENV_FILE" "$FAKE_DOCKER_LOG"; then
    fail "validated audit runtime overlay must not be reopened by Docker Compose"
fi
grep -Fxq "$GENERATED_ENV_FILE" "$FAKE_DOCKER_LOG" \
    && grep -Fxq "$FIXTURE_DIR/.env" "$FAKE_DOCKER_LOG" \
    || fail "Compose check did not receive the generated and operator env files"
[ "$(grep -Fxc -- '--env-file' "$FAKE_DOCKER_LOG")" = "2" ] \
    || fail "Compose check must receive only generated and operator env files exactly once"

printf '%s\n' \
    'APP_CONVERSATION_AUDIT_ENABLED=false' \
    'APP_CONVERSATION_AUDIT_API_ENABLED=true' \
    'APP_CONVERSATION_AUDIT_ALLOWED_TENANT_IDS=13579bdf-2468-4ace-8bdf-0123456789ab' \
    'APP_CONVERSATION_AUDIT_LEGACY_READ_ENABLED=false' \
    'APP_CONVERSATION_AUDIT_BACKFILL_ENABLED=false' \
    'APP_CONVERSATION_AUDIT_BACKFILL_TENANT_ID=' \
    > "$RUNTIME_ENV_FILE"
chmod 600 "$RUNTIME_ENV_FILE"
: > "$FAKE_DOCKER_LOG"
if (
    cd "$FIXTURE_DIR"
    PATH="$FAKE_DOCKER_DIR:$PATH" \
    FAKE_DOCKER_LOG="$FAKE_DOCKER_LOG" \
    NGROK_AUTHTOKEN=synthetic-local-token \
    APP_BASE_URL=https://example.invalid \
    ./start-dev-bot.sh --check
) >> "$OUTPUT_FILE" 2>&1; then
    fail "bootstrap accepted an incoherent promoted audit runtime state"
fi
[ ! -s "$FAKE_DOCKER_LOG" ] \
    || fail "incoherent promoted audit state reached the Docker boundary"
grep -Fq 'contains an unsafe promoted state' "$OUTPUT_FILE" \
    || fail "incoherent promoted state rejection did not identify the invariant"

printf '%s\n' \
    'APP_CONVERSATION_AUDIT_ENABLED=true' \
    'APP_CONVERSATION_AUDIT_API_ENABLED=true' \
    'APP_CONVERSATION_AUDIT_ALLOWED_TENANT_IDS=13579bdf-2468-4ace-8bdf-0123456789ab' \
    'APP_CONVERSATION_AUDIT_LEGACY_READ_ENABLED=false' \
    'APP_CONVERSATION_AUDIT_BACKFILL_ENABLED=false' \
    'APP_CONVERSATION_AUDIT_BACKFILL_TENANT_ID=' \
    > "$RUNTIME_ENV_FILE"
chmod 600 "$RUNTIME_ENV_FILE"

mv "$RUNTIME_ENV_FILE" "$FIXTURE_DIR/runtime-env.saved"
ln -s "$FIXTURE_DIR/runtime-env.saved" "$RUNTIME_ENV_FILE"
if (
    cd "$FIXTURE_DIR"
    PATH="$FAKE_DOCKER_DIR:$PATH" \
    FAKE_DOCKER_LOG="$FAKE_DOCKER_LOG" \
    NGROK_AUTHTOKEN=synthetic-local-token \
    APP_BASE_URL=https://example.invalid \
    ./start-dev-bot.sh --check
) >> "$OUTPUT_FILE" 2>&1; then
    fail "bootstrap accepted a symbolic-link audit runtime env overlay"
fi

for key_material in "$aes_key_material" "$audit_hmac_key_material" "$outbound_key_material"; do
    if grep -Fq "$key_material" "$OUTPUT_FILE"; then
        fail "key material appeared in bootstrap output"
    fi
done

for password_material in \
    "$dev_superadmin_initial_password" \
    "$repaired_dev_superadmin_initial_password"; do
    if grep -Fq "$password_material" "$OUTPUT_FILE"; then
        fail "DEV Super Admin initial password appeared in bootstrap output"
    fi
done

for protected_tenant_id in \
    '13579bdf-2468-4ace-8bdf-0123456789ab' \
    '2468ace0-1357-4bdf-9ace-fedcba987654'; do
    for diagnostic_file in \
        "$OUTPUT_FILE" \
        "$AUDIT_GATE_CASE_OUTPUT" \
        "$NGROK_CASE_OUTPUT" \
        "$BOUNDED_CLEANUP_OUTPUT" \
        "$FIXTURE_DIR/audit-spawn-before-pid.log" \
        "$FIXTURE_DIR/audit-spawn-before-pgid.log" \
        "$FIXTURE_DIR/audit-post-promotion-validate-compose.log" \
        "$FIXTURE_DIR/audit-post-promotion-validate-backend.log" \
        "$FIXTURE_DIR/audit-post-promotion-diagnostics-ps.log" \
        "$FIXTURE_DIR/audit-post-promotion-diagnostics-logs.log" \
        "$FIXTURE_DIR/audit-post-promotion-frontend-up.log" \
        "$FIXTURE_DIR/audit-post-promotion-frontend-ps.log" \
        "$FIXTURE_DIR/audit-post-promotion-signal-validate-compose.log" \
        "$FIXTURE_DIR/audit-post-promotion-signal-frontend-up.log" \
        "$FINALIZING_SIGNAL_OUTPUT" \
        "$BEFORE_WAIT_SIGNAL_OUTPUT" \
        "$FIXTURE_DIR/audit-signal-TERM.log" \
        "$FIXTURE_DIR/audit-signal-INT.log" \
        "$TRANSITION_FAKE_DOCKER_LOG" \
        "$TRANSITION_FAKE_CURL_LOG" \
        "$TRANSITION_EVENT_LOG"; do
        if [ -f "$diagnostic_file" ] \
            && grep -Fq "$protected_tenant_id" "$diagnostic_file"; then
            fail "conversation audit startup emitted a protected tenant identifier"
        fi
    done
done

echo "PASS: local conversation keyrings, multi-key staging, DEV Super Admin secret and inbound executors are stable, bounded and fail-closed"
