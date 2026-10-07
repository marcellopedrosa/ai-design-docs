#!/usr/bin/env bash

set -Eeuo pipefail

REPOSITORY_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
DEV_BOT_FILE="$REPOSITORY_ROOT/docker-compose.dev-bot.yml"
BASE_COMPOSE_FILE="$REPOSITORY_ROOT/docker-compose.yml"
APPLICATION_FILE="$REPOSITORY_ROOT/backend/app/src/main/resources/application.yml"
ENV_EXAMPLE="$REPOSITORY_ROOT/.env.example"

fail() {
    echo "FAIL: $*" >&2
    exit 1
}

assert_line() {
    local expected="$1"
    local file="$2"
    grep -Fqx "$expected" "$file" || fail "missing safe retention setting: $expected"
}

for command_name in grep; do
    command -v "$command_name" >/dev/null 2>&1 \
        || fail "required command is unavailable: $command_name"
done

[ -f "$DEV_BOT_FILE" ] || fail "dev-bot Compose override is missing"

assert_line '      APP_CONVERSATION_AUDIT_RETENTION_ENABLED: "false"' "$DEV_BOT_FILE"
assert_line '      APP_CONVERSATION_AUDIT_RETENTION_POLICY_BOOTSTRAP_ENABLED: "true"' "$DEV_BOT_FILE"
assert_line '      APP_CONVERSATION_AUDIT_RETENTION_CONVERSATION_DEFAULT_DAYS: "180"' "$DEV_BOT_FILE"
assert_line '      APP_CONVERSATION_AUDIT_RETENTION_ACCESS_DEFAULT_DAYS: "180"' "$DEV_BOT_FILE"
assert_line '      APP_CONVERSATION_AUDIT_RETENTION_CONVERSATION_PURGE_ENABLED: "false"' "$DEV_BOT_FILE"
assert_line '      APP_CONVERSATION_AUDIT_RETENTION_ACCESS_PURGE_ENABLED: "false"' "$DEV_BOT_FILE"
assert_line '      APP_CONVERSATION_AUDIT_RETENTION_LEGAL_HOLD: "true"' "$DEV_BOT_FILE"
assert_line '      APP_CONVERSATION_AUDIT_RETENTION_BACKUP_RESTORE_READY: "false"' "$DEV_BOT_FILE"
assert_line '      APP_CONVERSATION_AUDIT_RETENTION_EFFECTIVE_FROM: "2026-09-10T00:00:00Z"' "$DEV_BOT_FILE"
assert_line '      APP_CONVERSATION_AUDIT_RETENTION_DRY_RUN: "true"' "$DEV_BOT_FILE"

grep -Fq 'APP_CONVERSATION_AUDIT_RETENTION_POLICY_BOOTSTRAP_ENABLED: ${APP_CONVERSATION_AUDIT_RETENTION_POLICY_BOOTSTRAP_ENABLED:-false}' \
    "$BASE_COMPOSE_FILE" || fail "base Compose must keep policy bootstrap default-off"
grep -Fq 'policy-bootstrap-enabled: ${APP_CONVERSATION_AUDIT_RETENTION_POLICY_BOOTSTRAP_ENABLED:false}' \
    "$APPLICATION_FILE" || fail "application.yml must bind the separate policy bootstrap control"
assert_line 'APP_CONVERSATION_AUDIT_RETENTION_POLICY_BOOTSTRAP_ENABLED=false' "$ENV_EXAMPLE"

echo "Conversation audit retention DEV bootstrap safety contract passed"
