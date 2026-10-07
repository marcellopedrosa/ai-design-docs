#!/usr/bin/env bash

set -Eeuo pipefail

REPOSITORY_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
ACTIVATOR="$REPOSITORY_ROOT/infra/scripts/activate-dev-conversation-audit.sh"
TEST_ROOT="$(mktemp -d)"
TENANT_ID=13579bdf-2468-4ace-8bdf-0123456789ab
TENANT_SLUG=fixture-tenant

cleanup() {
    rm -rf -- "$TEST_ROOT"
}
trap cleanup EXIT

fail() {
    echo "FAIL: $*" >&2
    exit 1
}

line_of_first() {
    local pattern="$1"
    local file="$2"
    grep -nF -- "$pattern" "$file" | head -n 1 | cut -d: -f1
}

assert_runtime_closed() {
    local runtime_file="$1"
    local expected_legacy="${2:-false}"
    local expected_feature="${3:-true}"
    local expected="APP_CONVERSATION_AUDIT_ENABLED=$expected_feature
APP_CONVERSATION_AUDIT_API_ENABLED=false
APP_CONVERSATION_AUDIT_ALLOWED_TENANT_IDS=
APP_CONVERSATION_AUDIT_LEGACY_READ_ENABLED=$expected_legacy
APP_CONVERSATION_AUDIT_BACKFILL_ENABLED=false
APP_CONVERSATION_AUDIT_BACKFILL_TENANT_ID="

    [ -f "$runtime_file" ] && [ ! -L "$runtime_file" ] \
        || fail "rollback did not leave a regular runtime overlay"
    [ "$(stat -c '%a' "$runtime_file")" = 600 ] \
        || fail "rollback runtime overlay is not mode 0600"
    [ "$(<"$runtime_file")" = "$expected" ] \
        || fail "rollback did not leave the exact fail-closed runtime state"
}

write_runtime_state() {
    local runtime_file="$1"
    local feature_enabled="$2"
    local api_enabled="$3"
    local allowed_tenant_ids="$4"
    local legacy_read_enabled="$5"
    local backfill_enabled="$6"
    local backfill_tenant_id="$7"

    printf '%s\n' \
        "APP_CONVERSATION_AUDIT_ENABLED=$feature_enabled" \
        "APP_CONVERSATION_AUDIT_API_ENABLED=$api_enabled" \
        "APP_CONVERSATION_AUDIT_ALLOWED_TENANT_IDS=$allowed_tenant_ids" \
        "APP_CONVERSATION_AUDIT_LEGACY_READ_ENABLED=$legacy_read_enabled" \
        "APP_CONVERSATION_AUDIT_BACKFILL_ENABLED=$backfill_enabled" \
        "APP_CONVERSATION_AUDIT_BACKFILL_TENANT_ID=$backfill_tenant_id" \
        > "$runtime_file"
    chmod 600 "$runtime_file"
}

assert_close_only_has_no_data_lifecycle() {
    local case_root="$1"

    if grep -Eq 'tenant-selection|database-signature|readiness-(legacy|final)|backup-dump|restore-|backfill-|openssl' \
        "$case_root/events.log"; then
        fail "close-only crossed a tenant, data-readiness, backup, restore, crypto, or backfill boundary"
    fi
    if grep -Fq "$TENANT_ID" "$case_root/output.log" \
        || grep -Fq "$TENANT_SLUG" "$case_root/output.log"; then
        fail "close-only output exposed tenant identity"
    fi
    [ -z "$(find "$case_root/backups" -type f -print -quit)" ] \
        || fail "close-only created a backup artifact"
}

assert_runtime_ready() {
    local runtime_file="$1"
    local expected="APP_CONVERSATION_AUDIT_ENABLED=true
APP_CONVERSATION_AUDIT_API_ENABLED=true
APP_CONVERSATION_AUDIT_ALLOWED_TENANT_IDS=$TENANT_ID
APP_CONVERSATION_AUDIT_LEGACY_READ_ENABLED=false
APP_CONVERSATION_AUDIT_BACKFILL_ENABLED=false
APP_CONVERSATION_AUDIT_BACKFILL_TENANT_ID="

    [ -f "$runtime_file" ] && [ ! -L "$runtime_file" ] \
        || fail "activation did not leave a regular runtime overlay"
    [ "$(stat -c '%a' "$runtime_file")" = 600 ] \
        || fail "ready runtime overlay is not mode 0600"
    [ "$(wc -l < "$runtime_file" | tr -d '[:space:]')" = 6 ] \
        || fail "ready runtime overlay must contain exactly six keys"
    [ "$(<"$runtime_file")" = "$expected" ] \
        || fail "activation did not leave the exact ready runtime state"
    if grep -Eq '(KEYRING|SECRET|PASSWORD|MATERIAL)' "$runtime_file"; then
        fail "runtime overlay contains material outside the six non-secret switches"
    fi
}

for command_name in awk cp cut dirname find flock grep head mkdir mkfifo mktemp sed stat timeout tr wc; do
    command -v "$command_name" >/dev/null 2>&1 \
        || fail "required command is unavailable: $command_name"
done

[ -f "$ACTIVATOR" ] || fail "local conversation audit activation coordinator is missing"
[ -x "$ACTIVATOR" ] || fail "local conversation audit activation coordinator is not executable"

grep -Fq '/chatbot/audit/conversations' \
    "$REPOSITORY_ROOT/frontend/app/src/services/conversationAuditService.ts" \
    || fail "frontend canonical conversation audit route changed"
grep -Fq '${basePath(tenantId)}/search' \
    "$REPOSITORY_ROOT/frontend/app/src/services/conversationAuditService.ts" \
    || fail "frontend conversation audit search suffix changed"
grep -Fq '@RequestMapping("/api/v1/tenants/{tenantId}/chatbot/audit/conversations")' \
    "$REPOSITORY_ROOT/backend/app/src/main/java/br/com/duoset/saas_service/contexts/omnichannel/internal/presentation/rest/ConversationAuditController.java" \
    || fail "backend canonical conversation audit route changed"
grep -Fq 'APP_CONVERSATION_AUDIT_BACKFILL_BATCH_SIZE: "50"' \
    "$REPOSITORY_ROOT/docker-compose.conversation-audit-backfill.yml" \
    || fail "backfill override no longer pins a 50-row batch"
grep -Fq 'APP_CONVERSATION_AUDIT_BACKFILL_MAX_BATCHES: "1"' \
    "$REPOSITORY_ROOT/docker-compose.conversation-audit-backfill.yml" \
    || fail "backfill override no longer pins one batch per invocation"
grep -Fq 'restart: "no"' \
    "$REPOSITORY_ROOT/docker-compose.conversation-audit-backfill.yml" \
    || fail "backfill override no longer disables restart"
grep -Fq 'state_directory="${DEV_BOT_DIND_STATE_DIR:-}"' "$ACTIVATOR" \
    || fail "bundled activation no longer resolves the canonical DIND state directory"
grep -Fq 'DEV_SECRETS_DIRECTORY="$expected_secrets_link"' "$ACTIVATOR" \
    && grep -Fq 'GENERATED_ENV_FILE="$expected_generated_link"' "$ACTIVATOR" \
    && grep -Fq 'RUNTIME_ENV_FILE="$expected_secrets_link/conversation-audit-runtime.env"' "$ACTIVATOR" \
    || fail "bundled activation no longer resolves env and secrets through persisted DIND state"
grep -Fq 'EXTRA_COMPOSE_FILE="$PROJECT_DIR/docker-compose.dev-bot-image.yml"' "$ACTIVATOR" \
    && grep -Fq 'COMPOSE_FILES+=(-f "$EXTRA_COMPOSE_FILE")' "$ACTIVATOR" \
    || fail "bundled activation no longer appends its canonical image overlay"
grep -Fq -- '-f "$BACKFILL_COMPOSE_FILE" "$@"' "$ACTIVATOR" \
    || fail "backfill override is no longer applied after every regular/image Compose file"
[ "$(grep -Fc 'timeout --signal=TERM --kill-after=2s "$COMMAND_TIMEOUT_SECONDS"' "$ACTIVATOR")" = 2 ] \
    || fail "regular and backfill Compose wrappers no longer enforce bounded TERM-to-KILL escalation"
grep -Fq 'COMMAND_TIMEOUT_SECONDS="${CONVERSATION_AUDIT_ACTIVATION_COMMAND_TIMEOUT_SECONDS:-300}"' \
    "$ACTIVATOR" \
    || fail "activation default no longer matches the five-minute backend readiness budget"

make_fixture() {
    local case_name="$1"
    local case_root="$TEST_ROOT/$case_name"
    local project_dir="$case_root/saas-audit-fixture"
    local fake_bin="$case_root/fake-bin"

    mkdir -p \
        "$project_dir/.dev-secrets" \
        "$project_dir/infra/scripts/lib" \
        "$fake_bin" \
        "$case_root/backups" \
        "$case_root/state"
    chmod 700 "$project_dir/.dev-secrets" "$case_root/backups" "$case_root/state"

    cp "$REPOSITORY_ROOT/docker-compose.yml" "$project_dir/docker-compose.yml"
    cp "$REPOSITORY_ROOT/docker-compose.override.yml" "$project_dir/docker-compose.override.yml"
    cp "$REPOSITORY_ROOT/docker-compose.dev-bot.yml" "$project_dir/docker-compose.dev-bot.yml"
    cp "$REPOSITORY_ROOT/docker-compose.conversation-audit-backfill.yml" \
        "$project_dir/docker-compose.conversation-audit-backfill.yml"
    cp "$REPOSITORY_ROOT/infra/scripts/lib/development-docker-access.sh" \
        "$project_dir/infra/scripts/lib/development-docker-access.sh"
    printf '%s\n' '# Hermetic repository fixture.' > "$project_dir/AGENTS.md"

    # The coordinator reads only identifiers from the synthetic keyrings while
    # deriving the same policy fingerprint as the backend.
    printf '%s\n' \
        'DB_USER=saas_app' \
        'CONVERSATION_AUDIT_AES_ACTIVE_KEY_ID=fixture-aes-v1' \
        'CONVERSATION_AUDIT_HMAC_ACTIVE_KEY_ID=fixture-hmac-v1' \
        > "$project_dir/.env.dev.local"
    printf '%s\n' \
        '{"keys":{"fixture-aes-v1":"AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="}}' \
        > "$project_dir/.dev-secrets/conversation-audit-aes-keyring.json"
    printf '%s\n' \
        '{"keys":{"fixture-hmac-v1":"BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB="}}' \
        > "$project_dir/.dev-secrets/conversation-audit-hmac-keyring.json"
    chmod 600 \
        "$project_dir/.env.dev.local" \
        "$project_dir/.dev-secrets/conversation-audit-aes-keyring.json" \
        "$project_dir/.dev-secrets/conversation-audit-hmac-keyring.json"

    printf '%s\n' \
        '#!/usr/bin/env bash' \
        'set -Eeuo pipefail' \
        'runtime_value() {' \
        '  local wanted="$1"' \
        '  sed -n "s/^${wanted}=//p" "$FAKE_RUNTIME_FILE"' \
        '}' \
        'log_event() { printf "%s\\n" "$1" >> "$FAKE_EVENT_LOG"; }' \
        'if [ "${1:-}" = context ] && [ "${2:-}" = inspect ]; then printf "%s\\n" unix:///var/run/docker.sock; exit 0; fi' \
        'if [ "${1:-}" = info ]; then exit 0; fi' \
        'if [ "${1:-}" = compose ] && [ "${2:-}" = version ]; then exit 0; fi' \
        'all_args="$*"' \
        'stdin_payload=""' \
        'if [[ "$all_args" == *" exec -T postgres-app psql "* && "$all_args" != *" -c "* ]]; then stdin_payload="$(cat)"; fi' \
        'for argument in "$@"; do [ "$argument" != "$FAKE_RUNTIME_FILE" ] || exit 79; done' \
        'if [[ "$all_args" == *"conversation-audit-activation:tenant-selection"* || "$stdin_payload" == *"conversation-audit-activation:tenant-selection"* ]]; then' \
        '  log_event tenant-selection' \
        '  selected_tenant=""' \
        '  for argument in "$@"; do' \
        '    case "$argument" in activation_tenant_id=*) selected_tenant="${argument#activation_tenant_id=}" ;; esac' \
        '  done' \
        '  case "${FAKE_TENANT_MODE:-one}" in' \
        '    one)' \
        '      if [ -z "$selected_tenant" ] || [ "$selected_tenant" = "$FAKE_TENANT_ID" ]; then' \
        '        printf "%s\\t%s\\n" "$FAKE_TENANT_ID" "$FAKE_TENANT_SLUG"' \
        '      fi' \
        '      ;;' \
        '    none) : ;;' \
        '    two)' \
        '      if [ -z "$selected_tenant" ]; then' \
        '        printf "%s\\t%s\\n%s\\t%s\\n" "$FAKE_TENANT_ID" "$FAKE_TENANT_SLUG" "2468ace0-1357-4bdf-9ace-fedcba987654" second-fixture' \
        '      elif [ "$selected_tenant" = "$FAKE_TENANT_ID" ]; then' \
        '        printf "%s\\t%s\\n" "$FAKE_TENANT_ID" "$FAKE_TENANT_SLUG"' \
        '      elif [ "$selected_tenant" = "2468ace0-1357-4bdf-9ace-fedcba987654" ]; then' \
        '        printf "%s\\t%s\\n" "2468ace0-1357-4bdf-9ace-fedcba987654" second-fixture' \
        '      fi' \
        '      ;;' \
        '  esac' \
        '  exit 0' \
        'fi' \
        'if [[ "$all_args" == *"conversation-audit-activation:database-signature"* ]]; then' \
        '  log_event database-signature' \
        '  printf "%s\\n" "${FAKE_DATABASE_SIGNATURE:-42|123}"' \
        '  exit 0' \
        'fi' \
        'if [[ "$all_args" == *" -c "* && "$all_args" == *"conversation-audit-activation:readiness-status"* ]]; then' \
        '  log_event readiness-invalid-c-argument' \
        '  exit 78' \
        'fi' \
        'if [[ "$stdin_payload" == *"conversation-audit-activation:readiness-status"* ]]; then' \
        '  legacy="$(runtime_value APP_CONVERSATION_AUDIT_LEGACY_READ_ENABLED)"' \
        '  if [ "$legacy" = true ]; then' \
        '    log_event readiness-legacy' \
        '    if [ -f "$FAKE_STATE_DIR/legacy.done" ]; then' \
        '      log_event readiness-legacy-complete' \
        '      printf "%s\\n" "1|1|1|0|1|0|0|0|0|0|1|1|0"' \
        '    else' \
        '      log_event readiness-legacy-pending' \
        '      printf "%s\\n" "0|0|0|0|0|2|1|1|1|1|0|0|1"' \
        '    fi' \
        '  else' \
        '    log_event readiness-final' \
        '    if [ -f "$FAKE_STATE_DIR/final.done" ]; then' \
        '      log_event readiness-final-complete' \
        '      printf "%s\\n" "1|1|1|1|1|0|0|0|0|0|1|1|0"' \
        '    else' \
        '      log_event readiness-final-pending' \
        '      printf "%s\\n" "0|0|0|0|0|2|1|1|1|1|0|0|1"' \
        '    fi' \
        '  fi' \
        '  exit 0' \
        'fi' \
        'if [[ "$all_args" == *" pg_dump "* ]]; then' \
        '  log_event backup-dump' \
        '  printf "%s\\n" synthetic-custom-dump' \
        '  exit 0' \
        'fi' \
        'if [[ "$all_args" == *" createdb "* ]]; then log_event restore-createdb; exit 0; fi' \
        'if [[ "$all_args" == *" pg_restore "* ]]; then' \
        '  log_event restore-pg-restore' \
        '  while IFS= read -r _line; do :; done' \
        '  [ "${FAKE_FAIL_RESTORE:-0}" != 1 ] || exit 97' \
        '  exit 0' \
        'fi' \
        'if [[ "$all_args" == *" dropdb "* ]]; then log_event restore-dropdb; exit 0; fi' \
        'if [[ "$all_args" == *" exec -T backend sh -eu -c "* ]]; then' \
        '  log_event effective-backend-closed' \
        '  IFS= read -r expected_feature' \
        '  IFS= read -r expected_legacy' \
        '  [ "${FAKE_BAD_EFFECTIVE_BACKEND:-0}" != 1 ] || exit 96' \
        '  [ "$(runtime_value APP_CONVERSATION_AUDIT_ENABLED)" = "$expected_feature" ]' \
        '  [ "$(runtime_value APP_CONVERSATION_AUDIT_API_ENABLED)" = false ]' \
        '  [ -z "$(runtime_value APP_CONVERSATION_AUDIT_ALLOWED_TENANT_IDS)" ]' \
        '  [ "$(runtime_value APP_CONVERSATION_AUDIT_LEGACY_READ_ENABLED)" = "$expected_legacy" ]' \
        '  [ "$(runtime_value APP_CONVERSATION_AUDIT_BACKFILL_ENABLED)" = false ]' \
        '  [ -z "$(runtime_value APP_CONVERSATION_AUDIT_BACKFILL_TENANT_ID)" ]' \
        '  exit 0' \
        'fi' \
        'if [[ "$all_args" == *"config --format json"* ]]; then' \
        '  if [[ "$all_args" == *"docker-compose.conversation-audit-backfill.yml"* ]]; then' \
        '    log_event backfill-config' \
        '    restart=no; batch=50; batches=1' \
        '    if [ "${FAKE_BAD_BACKFILL_CONFIG:-0}" = 1 ]; then restart=always; batch=500; fi' \
        '    legacy="$(runtime_value APP_CONVERSATION_AUDIT_LEGACY_READ_ENABLED)"' \
        '    printf "%s\\n" "{\"services\":{\"backend\":{\"restart\":\"$restart\",\"environment\":{\"APP_CONVERSATION_AUDIT_ENABLED\":\"true\",\"APP_CONVERSATION_AUDIT_API_ENABLED\":\"false\",\"APP_CONVERSATION_AUDIT_ALLOWED_TENANT_IDS\":\"\",\"APP_CONVERSATION_AUDIT_LEGACY_READ_ENABLED\":\"$legacy\",\"APP_CONVERSATION_AUDIT_BACKFILL_ENABLED\":\"true\",\"APP_CONVERSATION_AUDIT_BACKFILL_TENANT_ID\":\"$FAKE_TENANT_ID\",\"APP_CONVERSATION_AUDIT_BACKFILL_BATCH_SIZE\":\"$batch\",\"APP_CONVERSATION_AUDIT_BACKFILL_MAX_BATCHES\":\"$batches\"}}}}"' \
        '  else' \
        '    log_event regular-config' \
        '    if [ "${FAKE_IGNORE_TERM_ON_REGULAR_CONFIG:-0}" = 1 ]; then' \
        '      trap "" TERM' \
        '      while :; do /bin/sleep 1; done' \
        '    fi' \
        '    enabled="$(runtime_value APP_CONVERSATION_AUDIT_ENABLED)"' \
        '    api="$(runtime_value APP_CONVERSATION_AUDIT_API_ENABLED)"' \
        '    allowed="$(runtime_value APP_CONVERSATION_AUDIT_ALLOWED_TENANT_IDS)"' \
        '    legacy="$(runtime_value APP_CONVERSATION_AUDIT_LEGACY_READ_ENABLED)"' \
        '    backfill="$(runtime_value APP_CONVERSATION_AUDIT_BACKFILL_ENABLED)"' \
        '    target="$(runtime_value APP_CONVERSATION_AUDIT_BACKFILL_TENANT_ID)"' \
        '    [ "${FAKE_BAD_REGULAR_CONFIG:-0}" != 1 ] || api=true' \
        '    printf "%s\\n" "{\"services\":{\"backend\":{\"restart\":\"unless-stopped\",\"environment\":{\"APP_CONVERSATION_AUDIT_ENABLED\":\"$enabled\",\"APP_CONVERSATION_AUDIT_API_ENABLED\":\"$api\",\"APP_CONVERSATION_AUDIT_ALLOWED_TENANT_IDS\":\"$allowed\",\"APP_CONVERSATION_AUDIT_LEGACY_READ_ENABLED\":\"$legacy\",\"APP_CONVERSATION_AUDIT_BACKFILL_ENABLED\":\"$backfill\",\"APP_CONVERSATION_AUDIT_BACKFILL_TENANT_ID\":\"$target\"}}}}"' \
        '  fi' \
        '  exit 0' \
        'fi' \
        'if [[ "$all_args" == *" stop --timeout "*" backend"* ]]; then' \
        '  log_event backend-stop' \
        '  [ "${FAKE_FAIL_BACKEND_STOP:-0}" != 1 ] || exit 95' \
        '  : > "$FAKE_STATE_DIR/backend.stopped"' \
        '  exit 0' \
        'fi' \
        'if [[ "$all_args" == *" ps --status running -q backend"* ]]; then' \
        '  log_event backend-stop-verify' \
        '  [ "${FAKE_FAIL_BACKEND_PS:-0}" != 1 ] || exit 94' \
        '  [ -f "$FAKE_STATE_DIR/backend.stopped" ] || printf "%s\\n" synthetic-running-backend' \
        '  exit 0' \
        'fi' \
        'if [[ "$all_args" == *" up -d --no-deps --force-recreate backend"* ]]; then' \
        '  rm -f -- "$FAKE_STATE_DIR/backend.stopped"' \
        '  enabled="$(runtime_value APP_CONVERSATION_AUDIT_ENABLED)"' \
        '  api="$(runtime_value APP_CONVERSATION_AUDIT_API_ENABLED)"' \
        '  allowed="$(runtime_value APP_CONVERSATION_AUDIT_ALLOWED_TENANT_IDS)"' \
        '  legacy="$(runtime_value APP_CONVERSATION_AUDIT_LEGACY_READ_ENABLED)"' \
        '  backfill="$(runtime_value APP_CONVERSATION_AUDIT_BACKFILL_ENABLED)"' \
        '  target="$(runtime_value APP_CONVERSATION_AUDIT_BACKFILL_TENANT_ID)"' \
        '  if [[ "$all_args" == *"docker-compose.conversation-audit-backfill.yml"* ]]; then' \
        '    [ "${FAKE_FAIL_BACKFILL_UP:-0}" != 1 ] || exit 87' \
        '    [ "$enabled" = true ] && [ "$api" = false ] && [ -z "$allowed" ] && [ "$backfill" = true ] && [ "$target" = "$FAKE_TENANT_ID" ] || exit 88' \
        '    last_override=""; previous=""' \
        '    for argument in "$@"; do' \
        '      if [ "$previous" = -f ]; then last_override="$argument"; fi' \
        '      previous="$argument"' \
        '    done' \
        '    [[ "$last_override" == *docker-compose.conversation-audit-backfill.yml ]] || exit 89' \
        '    if [ "$legacy" = true ]; then' \
        '      log_event backfill-legacy-on-50x1' \
        '      [ "${FAKE_NO_PROGRESS:-0}" = 1 ] || : > "$FAKE_STATE_DIR/legacy.done"' \
        '    else' \
        '      log_event backfill-legacy-off-50x1' \
        '      [ "${FAKE_NO_PROGRESS:-0}" = 1 ] || : > "$FAKE_STATE_DIR/final.done"' \
        '    fi' \
        '  else' \
        '    [ "${FAKE_FAIL_REGULAR_UP:-0}" != 1 ] || exit 93' \
        '    if [ "$api" = true ]; then' \
        '      [ "$enabled" = true ] && [ "$allowed" = "$FAKE_TENANT_ID" ] && [ "$legacy" = false ] && [ "$backfill" = false ] && [ -z "$target" ] || exit 90' \
        '      log_event regular-up-api-on' \
        '    else' \
        '      [ "$backfill" = false ] && [ -z "$target" ] || exit 91' \
        '      if [ -n "$allowed" ]; then' \
        '        [ "$enabled" = true ] && [ "$allowed" = "$FAKE_TENANT_ID" ] && [ "$legacy" = false ] || exit 92' \
        '        log_event regular-up-allowlist-api-off' \
      '      else' \
        '        log_event regular-up-api-off' \
        '        log_event "regular-up-api-off-protection-$enabled-legacy-$legacy"' \
        '      fi' \
        '    fi' \
        '  fi' \
        '  exit 0' \
        'fi' \
        'exit 0' \
        > "$fake_bin/docker"

    printf '%s\n' \
        '#!/usr/bin/env bash' \
        'set -Eeuo pipefail' \
        'printf "%s\\n" openssl >> "$FAKE_EVENT_LOG"' \
        'if [ "${1:-}" = rand ] && [ "${2:-}" = -hex ] && [ "${3:-}" = 32 ]; then printf "%064d\\n" 0; exit 0; fi' \
        'if [ "${1:-}" = rand ] && [ "${2:-}" = -hex ] && [ "${3:-}" = 8 ]; then printf "%016d\\n" 1; exit 0; fi' \
        'if [ "${1:-}" = genpkey ]; then' \
        '  previous=""; output_file=""' \
        '  for argument in "$@"; do [ "$previous" != -out ] || output_file="$argument"; previous="$argument"; done' \
        '  printf "%s\\n" fixture-ed25519-private > "$output_file"' \
        '  exit 0' \
        'fi' \
        'if [ "${1:-}" = pkey ]; then' \
        '  previous=""; output_file=""' \
        '  for argument in "$@"; do [ "$previous" != -out ] || output_file="$argument"; previous="$argument"; done' \
        '  printf "%s\\n" fixture-ed25519-public > "$output_file"' \
        '  exit 0' \
        'fi' \
        'if [ "${1:-}" = pkeyutl ]; then' \
        '  previous=""; output_file=""' \
        '  for argument in "$@"; do [ "$previous" != -out ] || output_file="$argument"; previous="$argument"; done' \
        '  if [[ " $* " == *" -sign "* ]]; then printf "%s\\n" fixture-ed25519-signature > "$output_file"; fi' \
        '  exit 0' \
        'fi' \
        'input_file=""; output_file=""; previous=""' \
        'for argument in "$@"; do' \
        '  if [ "$previous" = -in ]; then input_file="$argument"; fi' \
        '  if [ "$previous" = -out ]; then output_file="$argument"; fi' \
        '  previous="$argument"' \
        'done' \
        'if [ -n "$output_file" ]; then' \
        '  if [ -n "$input_file" ]; then cp -- "$input_file" "$output_file"; else sed "s/^/cipher:/" > "$output_file"; fi' \
        'elif [ -n "$input_file" ]; then' \
        '  sed "s/^cipher://" "$input_file"' \
        'else' \
        '  sed "s/^/cipher:/"' \
        'fi' \
        > "$fake_bin/openssl"

    printf '%s\n' \
        '#!/usr/bin/env bash' \
        'set -Eeuo pipefail' \
        'printf "%s\\n" readiness-http >> "$FAKE_EVENT_LOG"' \
        '[ "${FAKE_FAIL_HTTP_READINESS:-0}" != 1 ] || exit 93' \
        'printf "%s\\n" "{\"status\":\"UP\"}"' \
        > "$fake_bin/curl"
    printf '%s\n' '#!/usr/bin/env bash' 'exit 0' > "$fake_bin/sleep"
    chmod 700 "$fake_bin/docker" "$fake_bin/openssl" "$fake_bin/curl" "$fake_bin/sleep"

    printf '%s\n' "$case_root"
}

run_activator() {
    local case_root="$1"
    shift
    local project_dir="$case_root/saas-audit-fixture"
    local runtime_file="$project_dir/.dev-secrets/conversation-audit-runtime.env"
    local output_file="$case_root/output.log"
    local event_log="$case_root/events.log"
    [ -e "$event_log" ] || : > "$event_log"

    env \
        PATH="$case_root/fake-bin:$PATH" \
        CONVERSATION_AUDIT_ACTIVATION_PROJECT_DIR="$project_dir" \
        CONVERSATION_AUDIT_ACTIVATION_RUNTIME_ENV_FILE="$runtime_file" \
        CONVERSATION_AUDIT_ACTIVATION_BACKUP_ROOT="$case_root/backups" \
        CONVERSATION_AUDIT_ACTIVATION_MAX_ATTEMPTS=2 \
        CONVERSATION_AUDIT_ACTIVATION_COMMAND_TIMEOUT_SECONDS=2 \
        DB_USER=saas_app \
        FAKE_RUNTIME_FILE="$runtime_file" \
        FAKE_EVENT_LOG="$event_log" \
        FAKE_STATE_DIR="$case_root/state" \
        FAKE_TENANT_ID="$TENANT_ID" \
        FAKE_TENANT_SLUG="$TENANT_SLUG" \
        "$@" \
        timeout 15 bash "$ACTIVATOR" > "$output_file" 2>&1
}

run_activator_from_stdin() {
    local case_root="$1"
    local project_dir="$case_root/saas-audit-fixture"
    local runtime_file="$project_dir/.dev-secrets/conversation-audit-runtime.env"
    local output_file="$case_root/output.log"
    local event_log="$case_root/events.log"

    env \
        PATH="$case_root/fake-bin:$PATH" \
        CONVERSATION_AUDIT_ACTIVATION_PROJECT_DIR="$project_dir" \
        CONVERSATION_AUDIT_ACTIVATION_RUNTIME_ENV_FILE="$runtime_file" \
        CONVERSATION_AUDIT_ACTIVATION_BACKUP_ROOT="$case_root/backups" \
        CONVERSATION_AUDIT_ACTIVATION_MAX_ATTEMPTS=2 \
        CONVERSATION_AUDIT_ACTIVATION_COMMAND_TIMEOUT_SECONDS=2 \
        DB_USER=saas_app \
        FAKE_RUNTIME_FILE="$runtime_file" \
        FAKE_EVENT_LOG="$event_log" \
        FAKE_STATE_DIR="$case_root/state" \
        FAKE_TENANT_ID="$TENANT_ID" \
        FAKE_TENANT_SLUG="$TENANT_SLUG" \
        timeout 15 bash < "$ACTIVATOR" > "$output_file" 2>&1
}

run_activator_from_pinned_fd() {
    local case_root="$1"
    local project_dir="$case_root/saas-audit-fixture"
    local runtime_file="$project_dir/.dev-secrets/conversation-audit-runtime.env"
    local output_file="$case_root/output.log"
    local event_log="$case_root/events.log"
    local pinned_fd status=0

    exec {pinned_fd}<"$ACTIVATOR"
    env \
        PATH="$case_root/fake-bin:$PATH" \
        CONVERSATION_AUDIT_ACTIVATION_PROJECT_DIR="$project_dir" \
        CONVERSATION_AUDIT_ACTIVATION_RUNTIME_ENV_FILE="$runtime_file" \
        CONVERSATION_AUDIT_ACTIVATION_BACKUP_ROOT="$case_root/backups" \
        CONVERSATION_AUDIT_ACTIVATION_MAX_ATTEMPTS=2 \
        CONVERSATION_AUDIT_ACTIVATION_COMMAND_TIMEOUT_SECONDS=2 \
        DB_USER=saas_app \
        FAKE_RUNTIME_FILE="$runtime_file" \
        FAKE_EVENT_LOG="$event_log" \
        FAKE_STATE_DIR="$case_root/state" \
        FAKE_TENANT_ID="$TENANT_ID" \
        FAKE_TENANT_SLUG="$TENANT_SLUG" \
        timeout 15 bash "/proc/self/fd/$pinned_fd" </dev/null \
        > "$output_file" 2>&1 || status=$?
    exec {pinned_fd}<&-
    return "$status"
}

run_close_activator() {
    local case_root="$1"
    shift
    local project_dir="$case_root/saas-audit-fixture"
    local runtime_file="$project_dir/.dev-secrets/conversation-audit-runtime.env"
    local output_file="$case_root/output.log"
    local event_log="$case_root/events.log"
    [ -e "$event_log" ] || : > "$event_log"

    env \
        PATH="$case_root/fake-bin:$PATH" \
        CONVERSATION_AUDIT_ACTIVATION_PROJECT_DIR="$project_dir" \
        CONVERSATION_AUDIT_ACTIVATION_RUNTIME_ENV_FILE="$runtime_file" \
        CONVERSATION_AUDIT_ACTIVATION_BACKUP_ROOT="$case_root/backups" \
        CONVERSATION_AUDIT_ACTIVATION_MAX_ATTEMPTS=2 \
        CONVERSATION_AUDIT_ACTIVATION_COMMAND_TIMEOUT_SECONDS=2 \
        FAKE_RUNTIME_FILE="$runtime_file" \
        FAKE_EVENT_LOG="$event_log" \
        FAKE_STATE_DIR="$case_root/state" \
        FAKE_TENANT_ID="$TENANT_ID" \
        FAKE_TENANT_SLUG="$TENANT_SLUG" \
        "$@" \
        timeout 15 bash "$ACTIVATOR" --close-exposure-only \
        > "$output_file" 2>&1
}

run_close_activator_from_stdin() {
    local case_root="$1"
    shift
    local project_dir="$case_root/saas-audit-fixture"
    local runtime_file="$project_dir/.dev-secrets/conversation-audit-runtime.env"
    local output_file="$case_root/output.log"
    local event_log="$case_root/events.log"
    [ -e "$event_log" ] || : > "$event_log"

    env \
        PATH="$case_root/fake-bin:$PATH" \
        CONVERSATION_AUDIT_ACTIVATION_PROJECT_DIR="$project_dir" \
        CONVERSATION_AUDIT_ACTIVATION_RUNTIME_ENV_FILE="$runtime_file" \
        CONVERSATION_AUDIT_ACTIVATION_BACKUP_ROOT="$case_root/backups" \
        CONVERSATION_AUDIT_ACTIVATION_MAX_ATTEMPTS=2 \
        CONVERSATION_AUDIT_ACTIVATION_COMMAND_TIMEOUT_SECONDS=2 \
        FAKE_RUNTIME_FILE="$runtime_file" \
        FAKE_EVENT_LOG="$event_log" \
        FAKE_STATE_DIR="$case_root/state" \
        FAKE_TENANT_ID="$TENANT_ID" \
        FAKE_TENANT_SLUG="$TENANT_SLUG" \
        "$@" \
        timeout 15 bash -s -- --close-exposure-only < "$ACTIVATOR" \
        > "$output_file" 2>&1
}

run_activator_with_arguments() {
    local case_root="$1"
    shift
    local project_dir="$case_root/saas-audit-fixture"
    local runtime_file="$project_dir/.dev-secrets/conversation-audit-runtime.env"
    local output_file="$case_root/output.log"
    local event_log="$case_root/events.log"
    [ -e "$event_log" ] || : > "$event_log"

    env \
        PATH="$case_root/fake-bin:$PATH" \
        CONVERSATION_AUDIT_ACTIVATION_PROJECT_DIR="$project_dir" \
        CONVERSATION_AUDIT_ACTIVATION_RUNTIME_ENV_FILE="$runtime_file" \
        FAKE_RUNTIME_FILE="$runtime_file" \
        FAKE_EVENT_LOG="$event_log" \
        FAKE_STATE_DIR="$case_root/state" \
        FAKE_TENANT_ID="$TENANT_ID" \
        FAKE_TENANT_SLUG="$TENANT_SLUG" \
        timeout 15 bash "$ACTIVATOR" "$@" > "$output_file" 2>&1
}

CLOSE_ROOT="$(make_fixture close-ready)"
CLOSE_RUNTIME="$CLOSE_ROOT/saas-audit-fixture/.dev-secrets/conversation-audit-runtime.env"
write_runtime_state "$CLOSE_RUNTIME" true true "$TENANT_ID" false false ""
run_close_activator "$CLOSE_ROOT" \
    || { sed -n '1,160p' "$CLOSE_ROOT/output.log" >&2; fail "close-only ready-state invocation failed"; }
assert_runtime_closed "$CLOSE_RUNTIME" false true
assert_close_only_has_no_data_lifecycle "$CLOSE_ROOT"
[ "$(grep -Fc regular-config "$CLOSE_ROOT/events.log")" = 1 ] \
    && [ "$(grep -Fc regular-up-api-off "$CLOSE_ROOT/events.log")" -ge 1 ] \
    && [ "$(grep -Fc readiness-http "$CLOSE_ROOT/events.log")" = 1 ] \
    && [ "$(grep -Fc effective-backend-closed "$CLOSE_ROOT/events.log")" = 1 ] \
    || fail "close-only did not prove Compose, regular backend recreation, readiness, and effective environment"
close_config_line="$(line_of_first regular-config "$CLOSE_ROOT/events.log")"
close_up_line="$(line_of_first regular-up-api-off "$CLOSE_ROOT/events.log")"
close_readiness_line="$(line_of_first readiness-http "$CLOSE_ROOT/events.log")"
close_effective_line="$(line_of_first effective-backend-closed "$CLOSE_ROOT/events.log")"
[ "$close_config_line" -lt "$close_up_line" ] \
    && [ "$close_up_line" -lt "$close_readiness_line" ] \
    && [ "$close_readiness_line" -lt "$close_effective_line" ] \
    || fail "close-only proof order is not Compose -> recreate -> readiness -> effective environment"
if grep -Fq backend-stop "$CLOSE_ROOT/events.log"; then
    fail "successful close-only unexpectedly stopped the verified fail-closed backend"
fi

CLOSE_STDIN_ROOT="$(make_fixture close-stdin)"
CLOSE_STDIN_RUNTIME="$CLOSE_STDIN_ROOT/saas-audit-fixture/.dev-secrets/conversation-audit-runtime.env"
write_runtime_state "$CLOSE_STDIN_RUNTIME" true true "$TENANT_ID" false false ""
run_close_activator_from_stdin "$CLOSE_STDIN_ROOT" \
    || { sed -n '1,160p' "$CLOSE_STDIN_ROOT/output.log" >&2; fail "stdin close-only invocation failed"; }
assert_runtime_closed "$CLOSE_STDIN_RUNTIME" false true
assert_close_only_has_no_data_lifecycle "$CLOSE_STDIN_ROOT"

CLOSE_LEGACY_ROOT="$(make_fixture close-preserves-legacy)"
CLOSE_LEGACY_RUNTIME="$CLOSE_LEGACY_ROOT/saas-audit-fixture/.dev-secrets/conversation-audit-runtime.env"
write_runtime_state "$CLOSE_LEGACY_RUNTIME" true false "" true false ""
run_close_activator "$CLOSE_LEGACY_ROOT" \
    || { sed -n '1,160p' "$CLOSE_LEGACY_ROOT/output.log" >&2; fail "close-only did not accept protected legacy state"; }
assert_runtime_closed "$CLOSE_LEGACY_RUNTIME" true true
assert_close_only_has_no_data_lifecycle "$CLOSE_LEGACY_ROOT"

CLOSE_DEFAULT_ROOT="$(make_fixture close-defaults)"
CLOSE_DEFAULT_PROJECT="$CLOSE_DEFAULT_ROOT/saas-audit-fixture"
CLOSE_DEFAULT_RUNTIME="$CLOSE_DEFAULT_PROJECT/.dev-secrets/conversation-audit-runtime.env"
rm -f -- \
    "$CLOSE_DEFAULT_PROJECT/.dev-secrets/conversation-audit-aes-keyring.json" \
    "$CLOSE_DEFAULT_PROJECT/.dev-secrets/conversation-audit-hmac-keyring.json" \
    "$CLOSE_DEFAULT_PROJECT/docker-compose.conversation-audit-backfill.yml" \
    "$CLOSE_DEFAULT_ROOT/fake-bin/openssl"
run_close_activator "$CLOSE_DEFAULT_ROOT" \
    || { sed -n '1,160p' "$CLOSE_DEFAULT_ROOT/output.log" >&2; fail "close-only depended on keyrings, crypto, backfill, or a prior overlay"; }
assert_runtime_closed "$CLOSE_DEFAULT_RUNTIME" false false
assert_close_only_has_no_data_lifecycle "$CLOSE_DEFAULT_ROOT"

UNKNOWN_ARGUMENT_ROOT="$(make_fixture unknown-argument)"
if run_activator_with_arguments "$UNKNOWN_ARGUMENT_ROOT" --unexpected; then
    fail "activation accepted an unsupported argument"
fi
[ ! -e "$UNKNOWN_ARGUMENT_ROOT/saas-audit-fixture/.dev-secrets/conversation-audit-runtime.env" ] \
    && [ ! -e "$UNKNOWN_ARGUMENT_ROOT/saas-audit-fixture/.dev-secrets/conversation-audit-activation.lock" ] \
    && [ ! -s "$UNKNOWN_ARGUMENT_ROOT/events.log" ] \
    || fail "unsupported argument reached a filesystem or Docker mutation"
if run_activator_with_arguments "$UNKNOWN_ARGUMENT_ROOT" --close-exposure-only extra; then
    fail "activation accepted close-only with an extra argument"
fi
[ ! -e "$UNKNOWN_ARGUMENT_ROOT/saas-audit-fixture/.dev-secrets/conversation-audit-activation.lock" ] \
    && [ ! -s "$UNKNOWN_ARGUMENT_ROOT/events.log" ] \
    || fail "extra close-only argument reached a filesystem or Docker mutation"

CLOSE_CONTENDED_ROOT="$(make_fixture close-contended-lock)"
CLOSE_CONTENDED_RUNTIME="$CLOSE_CONTENDED_ROOT/saas-audit-fixture/.dev-secrets/conversation-audit-runtime.env"
CLOSE_CONTENDED_LOCK="$CLOSE_CONTENDED_ROOT/saas-audit-fixture/.dev-secrets/conversation-audit-activation.lock"
write_runtime_state "$CLOSE_CONTENDED_RUNTIME" true true "$TENANT_ID" false false ""
: > "$CLOSE_CONTENDED_LOCK"
chmod 600 "$CLOSE_CONTENDED_LOCK"
close_contended_before="$(<"$CLOSE_CONTENDED_RUNTIME")"
exec {CLOSE_CONTENDED_LOCK_FD}<>"$CLOSE_CONTENDED_LOCK"
flock -n "$CLOSE_CONTENDED_LOCK_FD" || fail "test could not hold the close-only lifecycle lock"
if (
    exec {CLOSE_CONTENDED_LOCK_FD}>&-
    run_close_activator "$CLOSE_CONTENDED_ROOT"
); then
    exec {CLOSE_CONTENDED_LOCK_FD}>&-
    fail "close-only unexpectedly succeeded while another lifecycle held the lock"
fi
exec {CLOSE_CONTENDED_LOCK_FD}>&-
[ "$(<"$CLOSE_CONTENDED_RUNTIME")" = "$close_contended_before" ] \
    || fail "close-only lock contender rewrote the runtime overlay"
[ ! -s "$CLOSE_CONTENDED_ROOT/events.log" ] \
    || fail "close-only lock contender reached a Docker mutation without lifecycle ownership"

INVALID_CLOSE_ROOT="$(make_fixture close-invalid-overlay)"
INVALID_CLOSE_RUNTIME="$INVALID_CLOSE_ROOT/saas-audit-fixture/.dev-secrets/conversation-audit-runtime.env"
write_runtime_state "$INVALID_CLOSE_RUNTIME" true true "$TENANT_ID" true false ""
invalid_close_before="$(<"$INVALID_CLOSE_RUNTIME")"
if run_close_activator "$INVALID_CLOSE_ROOT"; then
    fail "close-only accepted an unsafe runtime overlay"
fi
[ "$(<"$INVALID_CLOSE_RUNTIME")" = "$invalid_close_before" ] \
    || fail "close-only guessed and rewrote protection from an invalid overlay"
grep -Fq backend-stop "$INVALID_CLOSE_ROOT/events.log" \
    && grep -Fq backend-stop-verify "$INVALID_CLOSE_ROOT/events.log" \
    || fail "invalid close-only overlay did not stop and verify the backend"
if grep -Eq 'regular-config|regular-up-|effective-backend|tenant-selection|backup-|backfill-' \
    "$INVALID_CLOSE_ROOT/events.log"; then
    fail "invalid close-only overlay crossed a mutation boundary before fail-safe stop"
fi

CLOSE_CONFIG_FAILURE_ROOT="$(make_fixture close-config-failure)"
CLOSE_CONFIG_FAILURE_RUNTIME="$CLOSE_CONFIG_FAILURE_ROOT/saas-audit-fixture/.dev-secrets/conversation-audit-runtime.env"
write_runtime_state "$CLOSE_CONFIG_FAILURE_RUNTIME" true true "$TENANT_ID" false false ""
if run_close_activator "$CLOSE_CONFIG_FAILURE_ROOT" FAKE_BAD_REGULAR_CONFIG=1; then
    fail "close-only accepted a divergent regular Compose rendering"
fi
assert_runtime_closed "$CLOSE_CONFIG_FAILURE_RUNTIME" false true
grep -Fq regular-config "$CLOSE_CONFIG_FAILURE_ROOT/events.log" \
    && grep -Fq backend-stop "$CLOSE_CONFIG_FAILURE_ROOT/events.log" \
    && grep -Fq backend-stop-verify "$CLOSE_CONFIG_FAILURE_ROOT/events.log" \
    || fail "Compose divergence did not execute verified backend fail-safe stop"
if grep -Eq 'regular-up-|effective-backend' "$CLOSE_CONFIG_FAILURE_ROOT/events.log"; then
    fail "Compose divergence reached backend recreation or effective-environment proof"
fi
assert_close_only_has_no_data_lifecycle "$CLOSE_CONFIG_FAILURE_ROOT"

CLOSE_TERM_IGNORED_ROOT="$(make_fixture close-term-ignored)"
CLOSE_TERM_IGNORED_RUNTIME="$CLOSE_TERM_IGNORED_ROOT/saas-audit-fixture/.dev-secrets/conversation-audit-runtime.env"
write_runtime_state "$CLOSE_TERM_IGNORED_RUNTIME" true true "$TENANT_ID" false false ""
if run_close_activator "$CLOSE_TERM_IGNORED_ROOT" \
    FAKE_IGNORE_TERM_ON_REGULAR_CONFIG=1; then
    fail "close-only accepted a Compose command that ignored TERM"
fi
assert_runtime_closed "$CLOSE_TERM_IGNORED_RUNTIME" false true
grep -Fq regular-config "$CLOSE_TERM_IGNORED_ROOT/events.log" \
    && grep -Fq backend-stop "$CLOSE_TERM_IGNORED_ROOT/events.log" \
    && grep -Fq backend-stop-verify "$CLOSE_TERM_IGNORED_ROOT/events.log" \
    && grep -Fq 'Docker Compose did not confirm the fail-closed Conversation Audit state' \
        "$CLOSE_TERM_IGNORED_ROOT/output.log" \
    || fail "TERM-ignoring Compose command did not return through diagnostic and verified fail-safe stop"
if grep -Eq 'regular-up-|effective-backend' "$CLOSE_TERM_IGNORED_ROOT/events.log"; then
    fail "TERM-ignoring Compose rendering advanced beyond its bounded failure"
fi
assert_close_only_has_no_data_lifecycle "$CLOSE_TERM_IGNORED_ROOT"

CLOSE_EFFECTIVE_FAILURE_ROOT="$(make_fixture close-effective-failure)"
CLOSE_EFFECTIVE_FAILURE_RUNTIME="$CLOSE_EFFECTIVE_FAILURE_ROOT/saas-audit-fixture/.dev-secrets/conversation-audit-runtime.env"
write_runtime_state "$CLOSE_EFFECTIVE_FAILURE_RUNTIME" true true "$TENANT_ID" false false ""
if run_close_activator "$CLOSE_EFFECTIVE_FAILURE_ROOT" FAKE_BAD_EFFECTIVE_BACKEND=1; then
    fail "close-only accepted a divergent running backend environment"
fi
assert_runtime_closed "$CLOSE_EFFECTIVE_FAILURE_RUNTIME" false true
grep -Fq effective-backend-closed "$CLOSE_EFFECTIVE_FAILURE_ROOT/events.log" \
    && grep -Fq backend-stop "$CLOSE_EFFECTIVE_FAILURE_ROOT/events.log" \
    && grep -Fq backend-stop-verify "$CLOSE_EFFECTIVE_FAILURE_ROOT/events.log" \
    || fail "effective backend divergence did not execute verified fail-safe stop"
assert_close_only_has_no_data_lifecycle "$CLOSE_EFFECTIVE_FAILURE_ROOT"

CLOSE_READINESS_FAILURE_ROOT="$(make_fixture close-readiness-failure)"
CLOSE_READINESS_FAILURE_RUNTIME="$CLOSE_READINESS_FAILURE_ROOT/saas-audit-fixture/.dev-secrets/conversation-audit-runtime.env"
write_runtime_state "$CLOSE_READINESS_FAILURE_RUNTIME" true true "$TENANT_ID" false false ""
if run_close_activator "$CLOSE_READINESS_FAILURE_ROOT" FAKE_FAIL_HTTP_READINESS=1; then
    fail "close-only accepted a backend that never became ready"
fi
assert_runtime_closed "$CLOSE_READINESS_FAILURE_RUNTIME" false true
grep -Fq readiness-http "$CLOSE_READINESS_FAILURE_ROOT/events.log" \
    && grep -Fq backend-stop "$CLOSE_READINESS_FAILURE_ROOT/events.log" \
    && grep -Fq backend-stop-verify "$CLOSE_READINESS_FAILURE_ROOT/events.log" \
    && grep -Fq 'regular backend readiness did not become UP within 2 seconds' \
        "$CLOSE_READINESS_FAILURE_ROOT/output.log" \
    || fail "readiness failure did not execute verified backend fail-safe stop"
if grep -Fq effective-backend-closed "$CLOSE_READINESS_FAILURE_ROOT/events.log"; then
    fail "readiness failure reached the effective running-backend proof"
fi
assert_close_only_has_no_data_lifecycle "$CLOSE_READINESS_FAILURE_ROOT"

CLOSE_COMPOSE_FAILURE_ROOT="$(make_fixture close-compose-failure)"
CLOSE_COMPOSE_FAILURE_RUNTIME="$CLOSE_COMPOSE_FAILURE_ROOT/saas-audit-fixture/.dev-secrets/conversation-audit-runtime.env"
write_runtime_state "$CLOSE_COMPOSE_FAILURE_RUNTIME" true true "$TENANT_ID" false false ""
if run_close_activator "$CLOSE_COMPOSE_FAILURE_ROOT" FAKE_FAIL_REGULAR_UP=1; then
    fail "close-only accepted a failed regular backend Compose recreate"
fi
assert_runtime_closed "$CLOSE_COMPOSE_FAILURE_RUNTIME" false true
grep -Fq 'regular backend Compose recreate failed or exceeded 2 seconds' \
    "$CLOSE_COMPOSE_FAILURE_ROOT/output.log" \
    && grep -Fq backend-stop "$CLOSE_COMPOSE_FAILURE_ROOT/events.log" \
    && grep -Fq backend-stop-verify "$CLOSE_COMPOSE_FAILURE_ROOT/events.log" \
    || fail "regular Compose recreate failure did not emit its diagnosis and verified fail-safe stop"
if grep -Fq effective-backend-closed "$CLOSE_COMPOSE_FAILURE_ROOT/events.log"; then
    fail "regular Compose recreate failure reached the effective running-backend proof"
fi
assert_close_only_has_no_data_lifecycle "$CLOSE_COMPOSE_FAILURE_ROOT"

CLOSE_UNVERIFIED_STOP_ROOT="$(make_fixture close-unverified-stop)"
CLOSE_UNVERIFIED_STOP_RUNTIME="$CLOSE_UNVERIFIED_STOP_ROOT/saas-audit-fixture/.dev-secrets/conversation-audit-runtime.env"
write_runtime_state "$CLOSE_UNVERIFIED_STOP_RUNTIME" true true "$TENANT_ID" false false ""
if run_close_activator "$CLOSE_UNVERIFIED_STOP_ROOT" \
    FAKE_BAD_EFFECTIVE_BACKEND=1 FAKE_FAIL_BACKEND_PS=1; then
    fail "close-only accepted a fail-safe stop it could not verify"
fi
grep -Fq backend-stop "$CLOSE_UNVERIFIED_STOP_ROOT/events.log" \
    && grep -Fq backend-stop-verify "$CLOSE_UNVERIFIED_STOP_ROOT/events.log" \
    && grep -Fq 'CLOSE-ONLY FAIL-SAFE COULD NOT VERIFY THE BACKEND AS STOPPED' \
        "$CLOSE_UNVERIFIED_STOP_ROOT/output.log" \
    || fail "unverified fail-safe stop was not attempted and reported"
assert_close_only_has_no_data_lifecycle "$CLOSE_UNVERIFIED_STOP_ROOT"

SUCCESS_ROOT="$(make_fixture success)"
SUCCESS_RUNTIME="$SUCCESS_ROOT/saas-audit-fixture/.dev-secrets/conversation-audit-runtime.env"
run_activator "$SUCCESS_ROOT" \
    || {
        sed -n '1,160p' "$SUCCESS_ROOT/output.log" >&2
        sed -n '1,160p' "$SUCCESS_ROOT/events.log" >&2
        find "$SUCCESS_ROOT/state" -maxdepth 1 -type f -printf '%f\n' >&2
        sed -n '1,20p' "$SUCCESS_RUNTIME" >&2 2>/dev/null || true
        fail "happy-path activation failed"
    }
SUCCESS_EVENTS="$SUCCESS_ROOT/events.log"
assert_runtime_ready "$SUCCESS_RUNTIME"

run_activator_from_stdin "$SUCCESS_ROOT" \
    || {
        sed -n '1,160p' "$SUCCESS_ROOT/output.log" >&2
        fail "file-descriptor-compatible stdin activation failed"
    }
assert_runtime_ready "$SUCCESS_RUNTIME"

run_activator_from_pinned_fd "$SUCCESS_ROOT" \
    || {
        sed -n '1,160p' "$SUCCESS_ROOT/output.log" >&2
        fail "pinned /proc/self/fd activation with null operational stdin failed"
    }
assert_runtime_ready "$SUCCESS_RUNTIME"

closed_line="$(line_of_first regular-up-api-off "$SUCCESS_EVENTS")"
tenant_line="$(line_of_first tenant-selection "$SUCCESS_EVENTS")"
backup_line="$(line_of_first backup-dump "$SUCCESS_EVENTS")"
restore_line="$(line_of_first restore-pg-restore "$SUCCESS_EVENTS")"
legacy_on_line="$(line_of_first backfill-legacy-on-50x1 "$SUCCESS_EVENTS")"
legacy_off_line="$(line_of_first backfill-legacy-off-50x1 "$SUCCESS_EVENTS")"
api_on_line="$(line_of_first regular-up-api-on "$SUCCESS_EVENTS")"
post_api_readiness_line="$(awk -v api_line="$api_on_line" \
    'NR > api_line && $0 == "readiness-final" { print NR; exit }' \
    "$SUCCESS_EVENTS")"
[ -n "$closed_line" ] && [ -n "$tenant_line" ] && [ -n "$backup_line" ] \
    && [ -n "$restore_line" ] && [ -n "$legacy_on_line" ] \
    && [ -n "$legacy_off_line" ] && [ -n "$api_on_line" ] \
    && [ "$closed_line" -lt "$tenant_line" ] \
    && [ "$tenant_line" -lt "$backup_line" ] \
    && [ "$backup_line" -lt "$restore_line" ] \
    && [ "$restore_line" -lt "$legacy_on_line" ] \
    && [ "$legacy_on_line" -lt "$legacy_off_line" ] \
    && [ "$legacy_off_line" -lt "$api_on_line" ] \
    && [ -n "$post_api_readiness_line" ] \
    && [ "$api_on_line" -lt "$post_api_readiness_line" ] \
    || fail "activation order is not fail-closed -> select -> backup/restore -> legacy on/off -> API on"
[ "$(grep -Fc backfill-legacy-on-50x1 "$SUCCESS_EVENTS")" = 1 ] \
    && [ "$(grep -Fc backfill-legacy-off-50x1 "$SUCCESS_EVENTS")" = 1 ] \
    || fail "happy path did not execute exactly one bounded invocation per backfill phase"
if grep -Fq "$TENANT_ID" "$SUCCESS_ROOT/output.log" \
    || grep -Fq "$TENANT_SLUG" "$SUCCESS_ROOT/output.log"; then
    fail "activation output exposed the selected tenant"
fi
backup_count_before="$(grep -Fc backup-dump "$SUCCESS_EVENTS")"
backfill_count_before="$(grep -Fc 'backfill-legacy-' "$SUCCESS_EVENTS")"
rerun_event_start="$(( $(wc -l < "$SUCCESS_EVENTS") + 1 ))"
run_activator "$SUCCESS_ROOT" \
    || { sed -n '1,160p' "$SUCCESS_ROOT/output.log" >&2; fail "ready rerun failed"; }
assert_runtime_ready "$SUCCESS_RUNTIME"
[ "$(grep -Fc backup-dump "$SUCCESS_EVENTS")" = "$backup_count_before" ] \
    && [ "$(grep -Fc 'backfill-legacy-' "$SUCCESS_EVENTS")" = "$backfill_count_before" ] \
    || fail "ready rerun repeated backup or backfill instead of remaining idempotent"
sed -n "${rerun_event_start},\$p" "$SUCCESS_EVENTS" > "$SUCCESS_ROOT/rerun-events.log"
grep -Fq 'regular-up-api-off-protection-true-legacy-false' \
    "$SUCCESS_ROOT/rerun-events.log" \
    || fail "ready rerun did not preserve protected writes while closing API exposure"
if grep -Fq 'regular-up-api-off-protection-false' "$SUCCESS_ROOT/rerun-events.log"; then
    fail "ready rerun reopened a plaintext-writer race while closing API exposure"
fi

CONTENDED_LOCK="$SUCCESS_ROOT/saas-audit-fixture/.dev-secrets/conversation-audit-activation.lock"
contended_runtime_before="$(<"$SUCCESS_RUNTIME")"
contended_event_count_before="$(wc -l < "$SUCCESS_EVENTS" | tr -d '[:space:]')"
exec {CONTENDED_LOCK_FD}<>"$CONTENDED_LOCK"
flock -n "$CONTENDED_LOCK_FD" || fail "test could not hold the activation lock"
if (
    exec {CONTENDED_LOCK_FD}>&-
    run_activator "$SUCCESS_ROOT"
); then
    exec {CONTENDED_LOCK_FD}>&-
    fail "activation unexpectedly succeeded while another lifecycle held the lock"
fi
exec {CONTENDED_LOCK_FD}>&-
[ "$(<"$SUCCESS_RUNTIME")" = "$contended_runtime_before" ] \
    || fail "lock contention rewrote the runtime overlay without ownership"
[ "$(wc -l < "$SUCCESS_EVENTS" | tr -d '[:space:]')" = "$contended_event_count_before" ] \
    || fail "lock contention reached a Docker-backed mutation without ownership"
grep -Fq 'another local conversation audit activation is running' \
    "$SUCCESS_ROOT/output.log" \
    || fail "lock contention did not report the bounded lifecycle conflict"

mapfile -t backup_files < <(find "$SUCCESS_ROOT/backups" -type f -print)
[ "${#backup_files[@]}" -ge 1 ] || fail "activation did not retain an encrypted rollback artifact"
for backup_file in "${backup_files[@]}"; do
    [ ! -L "$backup_file" ] && [ "$(stat -c '%a' "$backup_file")" = 600 ] \
        || fail "rollback artifact is not a regular mode-0600 file"
done
mapfile -t encrypted_dumps < <(find "$SUCCESS_ROOT/backups/artifacts" \
    -type f -name tenant.dump.enc -print)
mapfile -t private_keys < <(find "$SUCCESS_ROOT/backups/custody" \
    -type f -name signing-private.pem -print)
[ "${#encrypted_dumps[@]}" = 1 ] && [ "${#private_keys[@]}" = 1 ] \
    || fail "backup artifact and signing custody were not materialized separately"
[ "$(dirname "${encrypted_dumps[0]}")" != "$(dirname "${private_keys[0]}")" ] \
    || fail "encrypted backup and private signing key share the same custody directory"
while IFS= read -r backup_directory; do
    [ ! -L "$backup_directory" ] && [ "$(stat -c '%a' "$backup_directory")" = 700 ] \
        || fail "backup artifact/custody directory is not regular mode 0700"
done < <(find "$SUCCESS_ROOT/backups" -mindepth 1 -type d -print)

RESTORE_FAILURE_ROOT="$(make_fixture restore-failure)"
if run_activator "$RESTORE_FAILURE_ROOT" FAKE_FAIL_RESTORE=1; then
    fail "activation accepted a failed restore drill"
fi
assert_runtime_closed \
    "$RESTORE_FAILURE_ROOT/saas-audit-fixture/.dev-secrets/conversation-audit-runtime.env" true
if grep -Fq 'backfill-legacy-' "$RESTORE_FAILURE_ROOT/events.log"; then
    fail "backfill ran before a successful restore drill"
fi
restore_failure_line="$(line_of_first restore-pg-restore "$RESTORE_FAILURE_ROOT/events.log")"
rollback_line="$(grep -nF regular-up-api-off "$RESTORE_FAILURE_ROOT/events.log" \
    | tail -n 1 | cut -d: -f1)"
[ -n "$restore_failure_line" ] && [ -n "$rollback_line" ] \
    && [ "$restore_failure_line" -lt "$rollback_line" ] \
    || fail "restore failure did not trigger a fail-closed backend recreation"

CARDINALITY_ROOT="$(make_fixture tenant-cardinality)"
if run_activator "$CARDINALITY_ROOT" FAKE_TENANT_MODE=two; then
    fail "activation accepted more than one provisioned active tenant"
fi
assert_runtime_closed \
    "$CARDINALITY_ROOT/saas-audit-fixture/.dev-secrets/conversation-audit-runtime.env" true
if grep -Fq backup-dump "$CARDINALITY_ROOT/events.log"; then
    fail "tenant cardinality failure reached the backup mutation boundary"
fi
if grep -Fq "$TENANT_ID" "$CARDINALITY_ROOT/output.log" \
    || grep -Fq "$TENANT_SLUG" "$CARDINALITY_ROOT/output.log"; then
    fail "tenant cardinality failure exposed tenant identity"
fi

EXPLICIT_TARGET_ROOT="$(make_fixture explicit-tenant-target)"
EXPLICIT_TARGET_RUNTIME="$EXPLICIT_TARGET_ROOT/saas-audit-fixture/.dev-secrets/conversation-audit-runtime.env"
run_activator "$EXPLICIT_TARGET_ROOT" \
    FAKE_TENANT_MODE=two \
    CONVERSATION_AUDIT_ACTIVATION_TENANT_ID="$TENANT_ID" \
    || {
        sed -n '1,160p' "$EXPLICIT_TARGET_ROOT/output.log" >&2
        fail "explicit tenant activation failed in a multi-tenant catalog"
    }
assert_runtime_ready "$EXPLICIT_TARGET_RUNTIME"
if grep -Fq "$TENANT_ID" "$EXPLICIT_TARGET_ROOT/output.log" \
    || grep -Fq "$TENANT_SLUG" "$EXPLICIT_TARGET_ROOT/output.log"; then
    fail "explicit tenant activation exposed tenant identity"
fi

UNKNOWN_TARGET_ROOT="$(make_fixture unknown-tenant-target)"
if run_activator "$UNKNOWN_TARGET_ROOT" \
    FAKE_TENANT_MODE=two \
    CONVERSATION_AUDIT_ACTIVATION_TENANT_ID=00000000-0000-4000-8000-000000000001; then
    fail "activation accepted an explicit tenant absent from the active provisioned catalog"
fi
assert_runtime_closed \
    "$UNKNOWN_TARGET_ROOT/saas-audit-fixture/.dev-secrets/conversation-audit-runtime.env" true
if grep -Fq backup-dump "$UNKNOWN_TARGET_ROOT/events.log"; then
    fail "unknown explicit tenant reached the backup mutation boundary"
fi

INVALID_TARGET_ROOT="$(make_fixture invalid-tenant-target)"
if run_activator "$INVALID_TARGET_ROOT" \
    CONVERSATION_AUDIT_ACTIVATION_TENANT_ID=not-a-canonical-uuid; then
    fail "activation accepted a malformed explicit tenant identifier"
fi
assert_runtime_closed \
    "$INVALID_TARGET_ROOT/saas-audit-fixture/.dev-secrets/conversation-audit-runtime.env" true
if grep -Fq tenant-selection "$INVALID_TARGET_ROOT/events.log" \
    || grep -Fq backup-dump "$INVALID_TARGET_ROOT/events.log"; then
    fail "malformed explicit tenant crossed the catalog or backup boundary"
fi

BAD_CONFIG_ROOT="$(make_fixture bad-backfill-config)"
if run_activator "$BAD_CONFIG_ROOT" FAKE_BAD_BACKFILL_CONFIG=1; then
    fail "activation accepted an unbounded or restartable backfill Compose rendering"
fi
assert_runtime_closed \
    "$BAD_CONFIG_ROOT/saas-audit-fixture/.dev-secrets/conversation-audit-runtime.env" true
if grep -Fq 'backfill-legacy-on-50x1' "$BAD_CONFIG_ROOT/events.log"; then
    fail "invalid 50 x 1/restart contract reached a backfill invocation"
fi

BACKFILL_COMPOSE_FAILURE_ROOT="$(make_fixture backfill-compose-failure)"
if run_activator "$BACKFILL_COMPOSE_FAILURE_ROOT" FAKE_FAIL_BACKFILL_UP=1; then
    fail "activation accepted a failed backfill backend Compose recreate"
fi
assert_runtime_closed \
    "$BACKFILL_COMPOSE_FAILURE_ROOT/saas-audit-fixture/.dev-secrets/conversation-audit-runtime.env" true
grep -Fq 'backfill backend Compose recreate failed or exceeded 2 seconds' \
    "$BACKFILL_COMPOSE_FAILURE_ROOT/output.log" \
    || fail "backfill Compose recreate failure did not emit its bounded phase diagnosis"
if grep -Fq regular-up-api-on "$BACKFILL_COMPOSE_FAILURE_ROOT/events.log"; then
    fail "failed backfill Compose recreate advanced toward API exposure"
fi

NO_PROGRESS_ROOT="$(make_fixture no-progress)"
if run_activator "$NO_PROGRESS_ROOT" FAKE_NO_PROGRESS=1; then
    fail "activation accepted a backfill that made no aggregate progress"
fi
assert_runtime_closed \
    "$NO_PROGRESS_ROOT/saas-audit-fixture/.dev-secrets/conversation-audit-runtime.env" true
[ "$(grep -Fc backfill-legacy-on-50x1 "$NO_PROGRESS_ROOT/events.log")" -le 2 ] \
    || fail "no-progress guard exceeded its bounded attempt allowance"
if grep -Fq backfill-legacy-off-50x1 "$NO_PROGRESS_ROOT/events.log" \
    || grep -Fq regular-up-api-on "$NO_PROGRESS_ROOT/events.log"; then
    fail "no-progress legacy phase advanced toward API exposure"
fi

UNSAFE_ROOT="$(make_fixture unsafe-runtime)"
UNSAFE_RUNTIME="$UNSAFE_ROOT/saas-audit-fixture/.dev-secrets/conversation-audit-runtime.env"
UNSAFE_VICTIM="$UNSAFE_ROOT/runtime-victim"
printf '%s\n' do-not-overwrite > "$UNSAFE_VICTIM"
chmod 600 "$UNSAFE_VICTIM"
ln -s "$UNSAFE_VICTIM" "$UNSAFE_RUNTIME"
if run_activator "$UNSAFE_ROOT"; then
    fail "activation accepted a symbolic-link runtime overlay"
fi
[ "$(<"$UNSAFE_VICTIM")" = do-not-overwrite ] \
    || fail "unsafe runtime rejection overwrote the symbolic-link target"
[ ! -s "$UNSAFE_ROOT/events.log" ] \
    || fail "unsafe runtime overlay reached Docker or crypto commands"

FIFO_LOCK_ROOT="$(make_fixture fifo-lock)"
FIFO_LOCK="$FIFO_LOCK_ROOT/saas-audit-fixture/.dev-secrets/conversation-audit-activation.lock"
mkfifo -m 600 "$FIFO_LOCK"
if run_activator "$FIFO_LOCK_ROOT"; then
    fail "activation accepted a FIFO as its lifecycle lock"
fi
[ ! -e "$FIFO_LOCK_ROOT/saas-audit-fixture/.dev-secrets/conversation-audit-runtime.env" ] \
    && [ ! -L "$FIFO_LOCK_ROOT/saas-audit-fixture/.dev-secrets/conversation-audit-runtime.env" ] \
    || fail "unsafe lock rejection mutated the runtime overlay before lock ownership"
[ ! -s "$FIFO_LOCK_ROOT/events.log" ] \
    || fail "unsafe lock rejection reached Docker before lock ownership"
grep -Fq 'lock must be a regular non-symbolic-link file' "$FIFO_LOCK_ROOT/output.log" \
    || fail "FIFO lock rejection did not identify the unsafe file type"

echo "PASS: local conversation audit activation is bounded, private, idempotent, and fail-closed"
