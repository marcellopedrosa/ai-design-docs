STAGING_CANDIDATE_DIR="$FIXTURE_DIR/staging-candidates"
TRANSITION_FAKE_BIN_DIR="$FIXTURE_DIR/transition-fake-bin"
TRANSITION_FAKE_DOCKER_LOG="$FIXTURE_DIR/transition-fake-docker.log"
TRANSITION_FAKE_CURL_LOG="$FIXTURE_DIR/transition-fake-curl.log"
TRANSITION_EVENT_LOG="$FIXTURE_DIR/transition-events.log"
TRANSITION_FRONTEND_STATE_FILE="$FIXTURE_DIR/transition-frontend.state"
TRANSITION_BACKEND_STATE_FILE="$FIXTURE_DIR/transition-backend.state"
POSTGRES_APP_CREDENTIAL_ONCE_FILE="$FIXTURE_DIR/postgres-app-credential-once.state"
export TRANSITION_FAKE_CURL_LOG TRANSITION_EVENT_LOG TRANSITION_FRONTEND_STATE_FILE \
    TRANSITION_BACKEND_STATE_FILE POSTGRES_APP_CREDENTIAL_ONCE_FILE
STAGING_ADD_FILE="$STAGING_CANDIDATE_DIR/add.json"
STAGING_MIXED_FILE="$STAGING_CANDIDATE_DIR/mixed.json"
STAGING_MISSING_ACTIVE_FILE="$STAGING_CANDIDATE_DIR/missing-active.json"
STAGING_DUPLICATE_FILE="$STAGING_CANDIDATE_DIR/duplicate.json"
STAGING_PADDING_FILE="$STAGING_CANDIDATE_DIR/invalid-padding.json"
STAGING_RETIRE_FILE="$STAGING_CANDIDATE_DIR/retire.json"
SECOND_OUTBOUND_KEY_ID=dev-outbound-v2
THIRD_OUTBOUND_KEY_ID=dev-outbound-v3
second_outbound_key_material="$(openssl rand -base64 32 | tr -d '\n')"
third_outbound_key_material="$(openssl rand -base64 32 | tr -d '\n')"
mkdir -p "$STAGING_CANDIDATE_DIR"
chmod 700 "$STAGING_CANDIDATE_DIR"
mkdir -p "$TRANSITION_FAKE_BIN_DIR"
printf '%s\n' \
    '#!/usr/bin/env bash' \
    'set -Eeuo pipefail' \
    'if [ "${CHECK_OUTBOUND_STAGE_LOCK_INHERITANCE:-0}" = 1 ]; then' \
    '  stage_lock_file="$PWD/.dev-secrets/outbound-hmac-stage.lock"' \
    '  for descriptor_path in /proc/self/fd/*; do' \
    '    [ "$(readlink "$descriptor_path" 2>/dev/null || true)" != "$stage_lock_file" ] || { echo "fake Docker inherited the outbound stage lock" >&2; exit 76; }' \
    '  done' \
    '  exec {stage_lock_probe_fd}<>"$stage_lock_file"' \
    '  if flock -n "$stage_lock_probe_fd"; then echo "bootstrap parent did not retain the outbound stage lock" >&2; exit 77; fi' \
    '  exec {stage_lock_probe_fd}>&-' \
    'fi' \
    'hang_post_promotion_if_requested() {' \
    '  local command_class="$1"' \
    '  [ "${APP_CONVERSATION_AUDIT_API_ENABLED:-false}" = true ] || return 0' \
    '  [ "${HANG_POST_PROMOTION_DOCKER_CLASS:-}" = "$command_class" ] || return 0' \
    '  [ -z "${POST_PROMOTION_HANG_PID_FILE:-}" ] || printf "%s\n" "$$" > "$POST_PROMOTION_HANG_PID_FILE"' \
    '  if [ -n "${POST_PROMOTION_HANG_DESCENDANT_PID_FILE:-}" ]; then' \
    '    bash -c '\''trap "" TERM; while :; do /bin/sleep 1; done'\'' </dev/null >/dev/null 2>&1 &' \
    '    printf "%s\n" "$!" > "$POST_PROMOTION_HANG_DESCENDANT_PID_FILE"' \
    '  fi' \
    '  [ -z "${TRANSITION_EVENT_LOG:-}" ] || printf "docker:hang:%s\n" "$command_class" >> "$TRANSITION_EVENT_LOG"' \
    '  [ "${EXIT_POST_PROMOTION_PARENT_AFTER_DESCENDANT:-0}" != 1 ] || return 0' \
    '  trap "" TERM' \
    '  while :; do /bin/sleep 1; done' \
    '}' \
    'if [ "${1:-}" = context ] && [ "${2:-}" = inspect ]; then printf "%s\n" unix:///var/run/docker.sock; exit 0; fi' \
    'if [ "${1:-}" = info ]; then exit 0; fi' \
    'if [ "${1:-}" = compose ]; then' \
    '  [ "${CONVERSATION_OUTBOUND_ATTEMPT_HMAC_ACTIVE_KEY_ID:-}" = "$EXPECTED_OUTBOUND_ACTIVE" ] || exit 91' \
    '  [ "${CONVERSATION_OUTBOUND_ATTEMPT_HMAC_KEYRING_FILE:-}" = "/run/saas-secrets/conversation-outbound-attempt-hmac-keyring.json" ] || exit 92' \
    '  case "${APP_CONVERSATION_AUDIT_API_ENABLED:-}" in' \
    '    false)' \
    '      [ -v APP_CONVERSATION_AUDIT_ALLOWED_TENANT_IDS ] && [ -z "$APP_CONVERSATION_AUDIT_ALLOWED_TENANT_IDS" ] || exit 95' \
    '      ;;' \
    '    true)' \
    '      [ "${APP_CONVERSATION_AUDIT_ENABLED:-}" = true ] || exit 94' \
    '      [[ "${APP_CONVERSATION_AUDIT_ALLOWED_TENANT_IDS:-}" =~ ^[0-9a-f-]{36}$ ]] || exit 95' \
    '      ;;' \
    '    *) exit 94 ;;' \
    '  esac' \
    '  [ "${APP_CONVERSATION_AUDIT_LEGACY_READ_ENABLED:-}" = false ] || exit 96' \
    '  [ "${APP_CONVERSATION_AUDIT_BACKFILL_ENABLED:-}" = false ] || exit 97' \
    '  [ -v APP_CONVERSATION_AUDIT_BACKFILL_TENANT_ID ] && [ -z "$APP_CONVERSATION_AUDIT_BACKFILL_TENANT_ID" ] || exit 98' \
    '  printf "%s\n" "$*" >> "$TRANSITION_FAKE_DOCKER_LOG"' \
    '  [ -z "${TRANSITION_EVENT_LOG:-}" ] || printf "docker:%s\n" "$*" >> "$TRANSITION_EVENT_LOG"' \
    '  if [ "${FAIL_BACKEND_BUILD:-0}" = 1 ] && [[ "$*" == *" build backend"* ]]; then exit 90; fi' \
    '  if [ "${FAIL_BASE_PREPARE:-0}" = 1 ] && [[ "$*" == *" up -d --no-build --no-recreate --wait --wait-timeout 300 postgres-app postgres-keycloak redis"* ]]; then exit 91; fi' \
    '  if [ "${FAIL_POSTGRES_WAIT:-0}" = 1 ] && [[ "$*" == *" pg_isready "* ]]; then exit 91; fi' \
    '  if [[ "$*" == *"exec -T postgres-app sh -eu -c"* ]] && [[ "$*" == *"verify-postgres-role-password"* ]] && [ -e "${POSTGRES_APP_CREDENTIAL_ONCE_FILE:-/nonexistent}" ]; then rm -f -- "$POSTGRES_APP_CREDENTIAL_ONCE_FILE"; exit 91; fi' \
    '  if [ "${FAIL_POSTGRES_APP_CREDENTIAL:-0}" = 1 ] && [[ "$*" == *"exec -T postgres-app sh -eu -c"* ]] && [[ "$*" == *"verify-postgres-role-password"* ]]; then exit 91; fi' \
    '  if [ "${FAIL_POSTGRES_KEYCLOAK_CREDENTIAL:-0}" = 1 ] && [[ "$*" == *"exec -T postgres-keycloak sh -eu -c"* ]] && [[ "$*" == *"verify-postgres-role-password"* ]]; then exit 91; fi' \
    '  if [[ "$*" == *"exec -T redis sh -eu -c"* ]] && [[ "$*" == *"verify-redis-password"* ]]; then [ "${FAIL_REDIS_CREDENTIAL:-0}" != 1 ] || exit 91; printf "%s\n" PONG; exit 0; fi' \
    '  if [ "${FAIL_TENANT_DB_PREPARE:-0}" = 1 ] && [[ "$*" == *"SELECT 1 FROM pg_database"* ]]; then exit 91; fi' \
    '  if [ "${FAIL_KEYCLOAK_PREPARE:-0}" = 1 ] && [[ "$*" == *" up -d --no-build --no-recreate --wait --wait-timeout 300 keycloak"* ]]; then exit 91; fi' \
    '  if [ "${FAIL_KEYCLOAK_PREFLIGHT:-0}" = 1 ] && [[ "$*" == *" run --rm --no-deps keycloak-provisioning-init"* ]]; then exit 92; fi' \
    '  if [ "${FAIL_OUTBOUND_INIT:-0}" = 1 ] && [[ "$*" == *" run --rm --no-deps outbound-attempt-keyring-init"* ]]; then exit 93; fi' \
    '  if [ "${FAIL_COMPOSE_UP:-0}" = 1 ] && [[ "$*" == *" up -d --no-build --no-deps --force-recreate backend"* ]]; then exit 94; fi' \
    '  if [[ "$*" == *" up -d --no-build --no-deps --force-recreate backend"* ]]; then printf "%s\n" running > "$TRANSITION_BACKEND_STATE_FILE"; fi' \
    '  if [[ "$*" == *" stop frontend"* ]]; then [ "${FAIL_FRONTEND_STOP_EFFECT:-0}" = 1 ] || printf "%s\n" stopped > "$TRANSITION_FRONTEND_STATE_FILE"; exit 0; fi' \
    '  if [[ "$*" == *" stop --timeout "* && "$*" == *" frontend" ]]; then' \
    '    printf "%s\n" stopped > "$TRANSITION_FRONTEND_STATE_FILE"' \
    '    if [ "${HANG_CLEANUP_FRONTEND_STOP:-0}" = 1 ]; then' \
    '      [ -z "${CLEANUP_FRONTEND_HANG_PID_FILE:-}" ] || printf "%s\n" "$$" > "$CLEANUP_FRONTEND_HANG_PID_FILE"' \
    '      trap "" TERM' \
    '      while :; do /bin/sleep 1; done' \
    '    fi' \
    '    exit 0' \
    '  fi' \
    '  if [[ "$*" == *" stop --timeout "* && "$*" == *" backend" ]]; then' \
    '    printf "%s\n" stopped > "$TRANSITION_BACKEND_STATE_FILE"' \
    '    if [ "${HANG_CLEANUP_BACKEND_STOP:-0}" = 1 ]; then' \
    '      [ -z "${CLEANUP_BACKEND_HANG_PID_FILE:-}" ] || printf "%s\n" "$$" > "$CLEANUP_BACKEND_HANG_PID_FILE"' \
    '      trap "" TERM' \
    '      while :; do /bin/sleep 1; done' \
    '    fi' \
    '    exit 0' \
    '  fi' \
    '  if [[ "$*" == *" ps --status running --services frontend"* ]]; then' \
    '    hang_post_promotion_if_requested frontend-ps' \
    '    [ "$(cat "$TRANSITION_FRONTEND_STATE_FILE" 2>/dev/null || true)" != running ] || printf "%s\n" frontend' \
    '    exit 0' \
    '  fi' \
    '  if [[ "$*" == *" ps --status running --services backend"* ]]; then' \
    '    [ "$(cat "$TRANSITION_BACKEND_STATE_FILE" 2>/dev/null || true)" != running ] || printf "%s\n" backend' \
    '    exit 0' \
    '  fi' \
    '  if [[ "$*" == *" ps --status running --services keycloak"* ]]; then printf "%s\n" keycloak; exit 0; fi' \
    '  if [[ "$*" == *" config --format json"* ]]; then' \
    '    hang_post_promotion_if_requested validate-compose' \
    '    resolved_api_enabled="$APP_CONVERSATION_AUDIT_API_ENABLED"' \
    '    [ "${FAIL_RESOLVED_COMPOSE_AUDIT:-0}" != 1 ] || resolved_api_enabled=false' \
    '    printf '\''{"services":{"backend":{"environment":{"APP_CONVERSATION_AUDIT_ENABLED":"%s","APP_CONVERSATION_AUDIT_API_ENABLED":"%s","APP_CONVERSATION_AUDIT_ALLOWED_TENANT_IDS":"%s","APP_CONVERSATION_AUDIT_LEGACY_READ_ENABLED":"%s","APP_CONVERSATION_AUDIT_BACKFILL_ENABLED":"%s","APP_CONVERSATION_AUDIT_BACKFILL_TENANT_ID":"%s"}}}}\n'\'' \' \
    '      "$APP_CONVERSATION_AUDIT_ENABLED" "$resolved_api_enabled" "$APP_CONVERSATION_AUDIT_ALLOWED_TENANT_IDS" \' \
    '      "$APP_CONVERSATION_AUDIT_LEGACY_READ_ENABLED" "$APP_CONVERSATION_AUDIT_BACKFILL_ENABLED" "$APP_CONVERSATION_AUDIT_BACKFILL_TENANT_ID"' \
    '    exit 0' \
    '  fi' \
    '  if [[ "$*" == *" exec -T backend sh -eu -c "* ]]; then' \
    '    hang_post_promotion_if_requested validate-backend' \
    '    IFS= read -r expected_allowlist' \
    '    [ "${FAIL_EFFECTIVE_BACKEND_AUDIT:-0}" != 1 ] || exit 89' \
    '    [ "$APP_CONVERSATION_AUDIT_ENABLED" = true ] || exit 81' \
    '    [ "$APP_CONVERSATION_AUDIT_API_ENABLED" = true ] || exit 82' \
    '    [ "$APP_CONVERSATION_AUDIT_ALLOWED_TENANT_IDS" = "$expected_allowlist" ] || exit 83' \
    '    [ "$APP_CONVERSATION_AUDIT_LEGACY_READ_ENABLED" = false ] || exit 84' \
    '    [ "$APP_CONVERSATION_AUDIT_BACKFILL_ENABLED" = false ] || exit 85' \
    '    [ -z "$APP_CONVERSATION_AUDIT_BACKFILL_TENANT_ID" ] || exit 86' \
    '    exit 0' \
    '  fi' \
    '  if [[ "$*" == *" up -d --build --force-recreate frontend"* ]]; then' \
    '    hang_post_promotion_if_requested frontend-up' \
    '    [ "${FAIL_FRONTEND_START:-0}" != 1 ] || exit 88' \
    '    printf "%s\n" running > "$TRANSITION_FRONTEND_STATE_FILE"' \
    '    exit 0' \
    '  fi' \
    '  if [ "${FAIL_NGROK_UP:-0}" = 1 ] && [[ "$*" == *" up -d --no-build --no-deps --force-recreate ngrok-bot"* ]]; then exit 90; fi' \
    '  if [[ "$*" == *" ps -a "* ]]; then hang_post_promotion_if_requested diagnostics-ps; fi' \
    '  if [[ "$*" == *" logs --no-color --tail 100 "* ]]; then hang_post_promotion_if_requested diagnostics-logs; fi' \
    '  if [[ "$*" == *"SELECT 1 FROM pg_database"* ]]; then printf "%s\n" 1; fi' \
    'fi' \
    'exit 0' \
    > "$TRANSITION_FAKE_BIN_DIR/docker"
printf '%s\n' \
    '#!/usr/bin/env bash' \
    'printf "unexpected-sudo:%s\\n" "$*" >> "$TRANSITION_FAKE_DOCKER_LOG"' \
    'exit 99' \
    > "$TRANSITION_FAKE_BIN_DIR/sudo"
printf '%s\n' \
    '#!/usr/bin/env bash' \
    'set -Eeuo pipefail' \
    'printf "%s\n" "$*" >> "$TRANSITION_FAKE_CURL_LOG"' \
    '[ -z "${TRANSITION_EVENT_LOG:-}" ] || printf "curl:%s\n" "$*" >> "$TRANSITION_EVENT_LOG"' \
    'if [[ "$*" == *"http://127.0.0.1:8080/actuator/health/readiness"* ]]; then' \
    '  [ "${FAIL_BACKEND_READINESS:-0}" != 1 ] || exit 22' \
    '  printf "%s\n" '\''{"status":"UP"}'\''' \
    'elif [[ "$*" == *"http://localhost:4041/api/tunnels"* ]]; then' \
    '  if [ "${FAIL_NGROK_DISCOVERY:-0}" = 1 ]; then printf "%s\n" '\''{"tunnels":[]}'\''; else printf '\''{"tunnels":[{"public_url":"%s"}]}\n'\'' "${MOCK_NGROK_PUBLIC_URL:-https://synthetic.invalid}"; fi' \
    'elif [[ "$*" == *"https://synthetic.invalid/actuator/health/readiness"* ]]; then' \
    '  [ "${FAIL_PUBLIC_READINESS:-0}" != 1 ] || exit 22' \
    '  printf "%s\n" '\''{"status":"UP"}'\''' \
    'else' \
    '  exit 23' \
    'fi' \
    > "$TRANSITION_FAKE_BIN_DIR/curl"
printf '%s\n' \
    '#!/usr/bin/env bash' \
    'exit 0' \
    > "$TRANSITION_FAKE_BIN_DIR/sleep"
chmod 700 \
    "$TRANSITION_FAKE_BIN_DIR/docker" \
    "$TRANSITION_FAKE_BIN_DIR/sudo" \
    "$TRANSITION_FAKE_BIN_DIR/curl" \
    "$TRANSITION_FAKE_BIN_DIR/sleep"
printf '%s\n' \
    'CONVERSATION_OUTBOUND_ATTEMPT_HMAC_ACTIVE_KEY_ID=stale-dotenv-active' \
    'CONVERSATION_OUTBOUND_ATTEMPT_HMAC_KEYRING_FILE=/stale/dotenv/keyring.json' \
    'APP_CONVERSATION_AUDIT_ENABLED=true' \
    'APP_CONVERSATION_AUDIT_API_ENABLED=true' \
    'APP_CONVERSATION_AUDIT_ALLOWED_TENANT_IDS=2468ace0-1357-4bdf-9ace-fedcba987654' \
    'APP_CONVERSATION_AUDIT_LEGACY_READ_ENABLED=true' \
    'APP_CONVERSATION_AUDIT_BACKFILL_ENABLED=true' \
    'APP_CONVERSATION_AUDIT_BACKFILL_TENANT_ID=2468ace0-1357-4bdf-9ace-fedcba987654' \
    'DEV_BOT_DIND_WRAPPER=1' \
    'DEV_BOT_EXTRA_COMPOSE_FILE=docker-compose.dev-bot-image.yml' \
    'DEV_BOT_DIND_STATE_DIR=/state' \
    > "$FIXTURE_DIR/.env"
chmod 600 "$FIXTURE_DIR/.env"

assert_audit_runtime_closed() {
    local case_name="$1"
    local runtime_file="$FIXTURE_DIR/.dev-secrets/conversation-audit-runtime.env"

    [ -f "$runtime_file" ] || fail "$case_name did not leave an audit runtime overlay"
    grep -qx 'APP_CONVERSATION_AUDIT_ENABLED=true' "$runtime_file" \
        || fail "$case_name changed the protected audit feature phase"
    grep -qx 'APP_CONVERSATION_AUDIT_API_ENABLED=false' "$runtime_file" \
        || fail "$case_name left the audit API enabled"
    grep -qx 'APP_CONVERSATION_AUDIT_ALLOWED_TENANT_IDS=' "$runtime_file" \
        || fail "$case_name left an audit tenant allowlist"
    grep -qx 'APP_CONVERSATION_AUDIT_LEGACY_READ_ENABLED=false' "$runtime_file" \
        || fail "$case_name left legacy audit reads enabled"
    grep -qx 'APP_CONVERSATION_AUDIT_BACKFILL_ENABLED=false' "$runtime_file" \
        || fail "$case_name left audit backfill enabled"
    grep -qx 'APP_CONVERSATION_AUDIT_BACKFILL_TENANT_ID=' "$runtime_file" \
        || fail "$case_name left a backfill tenant selected"
}

assert_audit_gate_closed() {
    local case_name="$1"
    local frontend_start_attempt_allowed="${2:-false}"

    [ "$(<"$TRANSITION_FRONTEND_STATE_FILE")" = stopped ] \
        || fail "$case_name left the frontend running"
    grep -Fq 'activator:close-exposure' "$TRANSITION_EVENT_LOG" \
        || fail "$case_name did not invoke the pinned close-only coordinator"
    if [ "$frontend_start_attempt_allowed" != true ] \
        && grep -Fq ' up -d --build --force-recreate frontend' "$TRANSITION_EVENT_LOG"; then
        fail "$case_name released the frontend gate"
    fi
    assert_audit_runtime_closed "$case_name"
}

reset_audit_transition_case() {
    rm -f "$OUTBOUND_COMMIT_RECEIPT_FILE"
    : > "$TRANSITION_EVENT_LOG"
    : > "$TRANSITION_FAKE_CURL_LOG"
    printf '%s\n' running > "$TRANSITION_FRONTEND_STATE_FILE"
    printf '%s\n' stopped > "$TRANSITION_BACKEND_STATE_FILE"
}

run_fake_initializer_commit() {
    local expected_active="$1"
    local local_readiness_line ngrok_discovery_line public_readiness_line
    local config_line build_line base_prepare_line postgres_app_credential_line
    local postgres_keycloak_credential_line redis_credential_line keycloak_up_line
    local keycloak_preflight_line stop_line first_frontend_stopped_proof_line
    local second_frontend_stopped_proof_line
    local outbound_init_line backend_up_line backend_readiness_event_line ngrok_up_line
    local activation_line compose_proof_line backend_proof_line frontend_up_line
    local frontend_running_line

    : > "$TRANSITION_FAKE_CURL_LOG"
    : > "$TRANSITION_EVENT_LOG"
    printf '%s\n' running > "$TRANSITION_FRONTEND_STATE_FILE"

    (
        cd "$FIXTURE_DIR"
        PATH="$TRANSITION_FAKE_BIN_DIR:$PATH" \
        TRANSITION_FAKE_DOCKER_LOG="$TRANSITION_FAKE_DOCKER_LOG" \
        TRANSITION_FAKE_CURL_LOG="$TRANSITION_FAKE_CURL_LOG" \
        EXPECTED_OUTBOUND_ACTIVE="$expected_active" \
        CHECK_OUTBOUND_STAGE_LOCK_INHERITANCE=1 \
        CONVERSATION_OUTBOUND_ATTEMPT_HMAC_ACTIVE_KEY_ID=stale-process-active \
        CONVERSATION_OUTBOUND_ATTEMPT_HMAC_KEYRING_FILE=/stale/process/keyring.json \
        NGROK_AUTHTOKEN=synthetic-local-token \
        APP_BASE_URL=https://synthetic.invalid \
        ./start-dev-bot.sh
    ) >> "$OUTPUT_FILE" 2>&1
    [ -f "$OUTBOUND_COMMIT_RECEIPT_FILE" ] \
        && [ ! -L "$OUTBOUND_COMMIT_RECEIPT_FILE" ] \
        && [ "$(stat -c '%a' "$OUTBOUND_COMMIT_RECEIPT_FILE")" = "600" ] \
        || fail "successful fake initializer did not emit an owner-only commit receipt"
    [ "$(<"$TRANSITION_FRONTEND_STATE_FILE")" = running ] \
        || fail "successful startup did not release the frontend gate"
    config_line="$(grep -nF ' config --quiet' "$TRANSITION_EVENT_LOG" \
        | head -n 1 | cut -d: -f1)"
    build_line="$(grep -nF ' build backend' "$TRANSITION_EVENT_LOG" \
        | head -n 1 | cut -d: -f1)"
    base_prepare_line="$(grep -nF \
        ' up -d --no-build --no-recreate --wait --wait-timeout 300 postgres-app postgres-keycloak redis' \
        "$TRANSITION_EVENT_LOG" | head -n 1 | cut -d: -f1)"
    postgres_app_credential_line="$(grep -nF ' exec -T postgres-app sh -eu -c' \
        "$TRANSITION_EVENT_LOG" | head -n 1 | cut -d: -f1)"
    postgres_keycloak_credential_line="$(grep -nF ' exec -T postgres-keycloak sh -eu -c' \
        "$TRANSITION_EVENT_LOG" | head -n 1 | cut -d: -f1)"
    redis_credential_line="$(grep -nF ' exec -T redis sh -eu -c' \
        "$TRANSITION_EVENT_LOG" | head -n 1 | cut -d: -f1)"
    keycloak_up_line="$(grep -nF \
        ' up -d --no-build --no-recreate --wait --wait-timeout 300 keycloak' \
        "$TRANSITION_EVENT_LOG" | head -n 1 | cut -d: -f1)"
    keycloak_preflight_line="$(grep -nF \
        ' run --rm --no-deps keycloak-provisioning-init' \
        "$TRANSITION_EVENT_LOG" | head -n 1 | cut -d: -f1)"
    stop_line="$(grep -nF 'docker:compose --project-name saas-fixture' "$TRANSITION_EVENT_LOG" \
        | grep -F ' stop frontend' | head -n 1 | cut -d: -f1)"
    first_frontend_stopped_proof_line="$(grep -nF \
        ' ps --status running --services frontend' "$TRANSITION_EVENT_LOG" \
        | sed -n '1p' | cut -d: -f1)"
    second_frontend_stopped_proof_line="$(grep -nF \
        ' ps --status running --services frontend' "$TRANSITION_EVENT_LOG" \
        | sed -n '2p' | cut -d: -f1)"
    outbound_init_line="$(grep -nF \
        ' run --rm --no-deps outbound-attempt-keyring-init' \
        "$TRANSITION_EVENT_LOG" | head -n 1 | cut -d: -f1)"
    backend_up_line="$(grep -nF ' up -d --no-build --no-deps --force-recreate backend' \
        "$TRANSITION_EVENT_LOG" | head -n 1 | cut -d: -f1)"
    backend_readiness_event_line="$(grep -nF \
        'curl:--fail --silent --show-error --connect-timeout 1 --max-time 1 http://127.0.0.1:8080/actuator/health/readiness' \
        "$TRANSITION_EVENT_LOG" | head -n 1 | cut -d: -f1)"
    ngrok_up_line="$(grep -nF ' up -d --no-build --no-deps --force-recreate ngrok-bot' \
        "$TRANSITION_EVENT_LOG" | head -n 1 | cut -d: -f1)"
    activation_line="$(grep -nF 'activator:start' "$TRANSITION_EVENT_LOG" \
        | head -n 1 | cut -d: -f1)"
    compose_proof_line="$(grep -nF ' config --format json' "$TRANSITION_EVENT_LOG" \
        | head -n 1 | cut -d: -f1)"
    backend_proof_line="$(grep -nF ' exec -T backend sh -eu -c' "$TRANSITION_EVENT_LOG" \
        | head -n 1 | cut -d: -f1)"
    frontend_up_line="$(grep -nF ' up -d --build --force-recreate frontend' \
        "$TRANSITION_EVENT_LOG" | head -n 1 | cut -d: -f1)"
    frontend_running_line="$(grep -nF ' ps --status running --services frontend' \
        "$TRANSITION_EVENT_LOG" | tail -n 1 | cut -d: -f1)"
    [ -n "$config_line" ] && [ -n "$build_line" ] \
        && [ -n "$base_prepare_line" ] \
        && [ -n "$postgres_app_credential_line" ] \
        && [ -n "$postgres_keycloak_credential_line" ] \
        && [ -n "$redis_credential_line" ] && [ -n "$keycloak_up_line" ] \
        && [ -n "$keycloak_preflight_line" ] && [ -n "$stop_line" ] \
        && [ -n "$first_frontend_stopped_proof_line" ] \
        && [ -n "$second_frontend_stopped_proof_line" ] \
        && [ -n "$outbound_init_line" ] && [ -n "$backend_up_line" ] \
        && [ -n "$backend_readiness_event_line" ] && [ -n "$ngrok_up_line" ] \
        && [ -n "$activation_line" ] && [ -n "$compose_proof_line" ] \
        && [ -n "$backend_proof_line" ] && [ -n "$frontend_up_line" ] \
        && [ -n "$frontend_running_line" ] \
        && [ "$config_line" -lt "$build_line" ] \
        && [ "$build_line" -lt "$base_prepare_line" ] \
        && [ "$base_prepare_line" -lt "$postgres_app_credential_line" ] \
        && [ "$postgres_app_credential_line" -lt "$postgres_keycloak_credential_line" ] \
        && [ "$postgres_keycloak_credential_line" -lt "$redis_credential_line" ] \
        && [ "$redis_credential_line" -lt "$keycloak_up_line" ] \
        && [ "$keycloak_up_line" -lt "$keycloak_preflight_line" ] \
        && [ "$keycloak_preflight_line" -lt "$stop_line" ] \
        && [ "$stop_line" -lt "$first_frontend_stopped_proof_line" ] \
        && [ "$first_frontend_stopped_proof_line" -lt "$outbound_init_line" ] \
        && [ "$outbound_init_line" -lt "$backend_up_line" ] \
        && [ "$backend_up_line" -lt "$backend_readiness_event_line" ] \
        && [ "$backend_readiness_event_line" -lt "$second_frontend_stopped_proof_line" ] \
        && [ "$second_frontend_stopped_proof_line" -lt "$ngrok_up_line" ] \
        && [ "$ngrok_up_line" -lt "$activation_line" ] \
        && [ "$activation_line" -lt "$compose_proof_line" ] \
        && [ "$compose_proof_line" -lt "$backend_proof_line" ] \
        && [ "$backend_proof_line" -lt "$frontend_up_line" ] \
        && [ "$frontend_up_line" -lt "$frontend_running_line" ] \
        || fail "startup did not preserve prepare, cutover, activation and postcondition order"
    local_readiness_line="$(grep -nF 'http://127.0.0.1:8080/actuator/health/readiness' \
        "$TRANSITION_FAKE_CURL_LOG" | head -n 1 | cut -d: -f1)"
    ngrok_discovery_line="$(grep -nF 'http://localhost:4041/api/tunnels' \
        "$TRANSITION_FAKE_CURL_LOG" | head -n 1 | cut -d: -f1)"
    public_readiness_line="$(grep -nF 'https://synthetic.invalid/actuator/health/readiness' \
        "$TRANSITION_FAKE_CURL_LOG" | head -n 1 | cut -d: -f1)"
    [ -n "$local_readiness_line" ] \
        && [ -n "$ngrok_discovery_line" ] \
        && [ -n "$public_readiness_line" ] \
        && [ "$local_readiness_line" -lt "$ngrok_discovery_line" ] \
        && [ "$ngrok_discovery_line" -lt "$public_readiness_line" ] \
        || fail "startup did not prove local readiness, ngrok discovery, and public readiness in order"
    grep -F 'http://localhost:4041/api/tunnels' "$TRANSITION_FAKE_CURL_LOG" \
        | grep -Fq -- '--connect-timeout 1 --max-time 1' \
        || fail "ngrok discovery curl is not bounded by connect and total timeouts"
    if grep -Fq 'docker-compose.dev-bot-image.yml' "$TRANSITION_FAKE_DOCKER_LOG"; then
        fail "dotenv runtime-mode selectors disabled the host source build"
    fi
}

run_pre_cutover_failure_case() {
    local case_name="$1"
    local failure_variable="$2"
    local expected_message="$3"
    local case_output="$FIXTURE_DIR/pre-cutover-${case_name}.log"

    : > "$TRANSITION_EVENT_LOG"
    : > "$TRANSITION_FAKE_CURL_LOG"
    printf '%s\n' running > "$TRANSITION_FRONTEND_STATE_FILE"
    printf '%s\n' running > "$TRANSITION_BACKEND_STATE_FILE"
    rm -f "$OUTBOUND_COMMIT_RECEIPT_FILE"

    if (
        cd "$FIXTURE_DIR"
        export PATH="$TRANSITION_FAKE_BIN_DIR:$PATH"
        export TRANSITION_FAKE_DOCKER_LOG TRANSITION_FAKE_CURL_LOG
        export EXPECTED_OUTBOUND_ACTIVE="$OUTBOUND_KEY_ID"
        export CHECK_OUTBOUND_STAGE_LOCK_INHERITANCE=1
        export NGROK_AUTHTOKEN=synthetic-local-token
        export APP_BASE_URL=https://synthetic.invalid
        case "$failure_variable" in
            FAIL_BACKEND_BUILD) export FAIL_BACKEND_BUILD=1 ;;
            FAIL_BASE_PREPARE) export FAIL_BASE_PREPARE=1 ;;
            FAIL_POSTGRES_WAIT) export FAIL_POSTGRES_WAIT=1 ;;
            FAIL_POSTGRES_APP_CREDENTIAL) export FAIL_POSTGRES_APP_CREDENTIAL=1 ;;
            FAIL_POSTGRES_KEYCLOAK_CREDENTIAL) export FAIL_POSTGRES_KEYCLOAK_CREDENTIAL=1 ;;
            FAIL_TENANT_DB_PREPARE) export FAIL_TENANT_DB_PREPARE=1 ;;
            FAIL_REDIS_CREDENTIAL) export FAIL_REDIS_CREDENTIAL=1 ;;
            FAIL_KEYCLOAK_PREPARE) export FAIL_KEYCLOAK_PREPARE=1 ;;
            FAIL_KEYCLOAK_PREFLIGHT) export FAIL_KEYCLOAK_PREFLIGHT=1 ;;
            *) exit 125 ;;
        esac
        ./start-dev-bot.sh
    ) > "$case_output" 2>&1; then
        fail "$case_name pre-cutover failure was accepted"
    fi

    if ! grep -Fq "$expected_message" "$case_output"; then
        tail -n 40 "$case_output" >&2
        fail "$case_name did not emit the pre-cutover preservation diagnosis"
    fi
    [ "$(<"$TRANSITION_FRONTEND_STATE_FILE")" = running ] \
        || fail "$case_name stopped the existing frontend before preflight completed"
    [ "$(<"$TRANSITION_BACKEND_STATE_FILE")" = running ] \
        || fail "$case_name stopped the existing backend before preflight completed"
    if grep -Fq ' stop frontend' "$TRANSITION_EVENT_LOG"; then
        fail "$case_name crossed the frontend gate before preflight completed"
    fi
    if grep -Fq ' up -d --no-build --no-deps --force-recreate backend' \
        "$TRANSITION_EVENT_LOG"; then
        fail "$case_name attempted the backend cutover after a failed preflight"
    fi
    if grep -Fq ' run --rm --no-deps outbound-attempt-keyring-init' \
        "$TRANSITION_EVENT_LOG"; then
        fail "$case_name crossed the outbound keyring commit boundary"
    fi
    if grep -Eq 'force-recreate.*(redis|postgres-app|postgres-keycloak|keycloak)' \
        "$TRANSITION_EVENT_LOG"; then
        fail "$case_name force-recreated a stateful dependency"
    fi
    case "$failure_variable" in
        FAIL_POSTGRES_APP_CREDENTIAL)
            if grep -Fq ' exec -T postgres-app psql -v ON_ERROR_STOP=1 -U' \
                "$TRANSITION_EVENT_LOG"; then
                fail "$case_name changed the application role below a running backend"
            fi
            ;;
        FAIL_POSTGRES_KEYCLOAK_CREDENTIAL)
            if grep -Fq ' exec -T postgres-keycloak psql -v ON_ERROR_STOP=1 -U' \
                "$TRANSITION_EVENT_LOG"; then
                fail "$case_name changed the Keycloak role below a running Keycloak"
            fi
            ;;
    esac
    [ ! -e "$OUTBOUND_COMMIT_RECEIPT_FILE" ] \
        || fail "$case_name emitted an outbound commit receipt"
}
