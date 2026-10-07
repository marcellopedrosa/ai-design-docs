#!/usr/bin/env bash

set -Eeuo pipefail

REPOSITORY_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
OVERRIDE_FILE="$REPOSITORY_ROOT/docker-compose.conversation-audit-backfill.yml"
DEV_BOT_FILE="$REPOSITORY_ROOT/docker-compose.dev-bot.yml"

fail() {
    echo "FAIL: $*" >&2
    exit 1
}

for command_name in grep sed; do
    command -v "$command_name" >/dev/null 2>&1 \
        || fail "required command is unavailable: $command_name"
done

[ -f "$OVERRIDE_FILE" ] || fail "backfill Compose override is missing"
[ -f "$DEV_BOT_FILE" ] || fail "dev-bot Compose override is missing"

grep -Fq 'APP_CONVERSATION_AUDIT_BACKFILL_ENABLED: "false"' \
    "$DEV_BOT_FILE" \
    || fail "regular dev-bot startup must force conversation audit backfill off"
grep -Fq 'APP_CONVERSATION_AUDIT_BACKFILL_TENANT_ID: ""' \
    "$DEV_BOT_FILE" \
    || fail "regular dev-bot startup must clear a stale backfill tenant target"

normalized_override="$(sed '/^[[:space:]]*#/d; /^[[:space:]]*$/d' "$OVERRIDE_FILE")"
expected_override='services:
  backend:
    restart: "no"
    environment:
      APP_CONVERSATION_AUDIT_BACKFILL_ENABLED: "true"
      APP_CONVERSATION_AUDIT_BACKFILL_TENANT_ID: "${APP_CONVERSATION_AUDIT_BACKFILL_TENANT_ID:?APP_CONVERSATION_AUDIT_BACKFILL_TENANT_ID is required}"
      APP_CONVERSATION_AUDIT_BACKFILL_BATCH_SIZE: "50"
      APP_CONVERSATION_AUDIT_BACKFILL_MAX_BATCHES: "1"'
[ "$normalized_override" = "$expected_override" ] \
    || fail "backfill Compose override must require one target and pin enabled, restart: no, and bounded 50 x 1 execution"

grep -Fqx 'APP_CONVERSATION_AUDIT_BACKFILL_TENANT_ID=' \
    "$REPOSITORY_ROOT/.env.example" \
    || fail ".env.example must keep the backfill tenant target empty by default"
grep -Fqx 'APP_CONVERSATION_AUDIT_BACKFILL_TIMEOUT_SECONDS=30' \
    "$REPOSITORY_ROOT/.env.example" \
    || fail ".env.example must declare the bounded default timeout"
grep -Fqx 'APP_CONVERSATION_AUDIT_BACKFILL_BATCH_SIZE=50' \
    "$REPOSITORY_ROOT/.env.example" \
    || fail ".env.example must declare the maximum bounded batch size"
grep -Fqx 'APP_CONVERSATION_AUDIT_BACKFILL_MAX_BATCHES=1' \
    "$REPOSITORY_ROOT/.env.example" \
    || fail ".env.example must declare exactly one batch per invocation"

grep -Fq 'tenant-id: ${APP_CONVERSATION_AUDIT_BACKFILL_TENANT_ID:}' \
    "$REPOSITORY_ROOT/backend/app/src/main/resources/application.yml" \
    || fail "application.yml must bind the dedicated backfill tenant target"
grep -Fq 'timeout-seconds: ${APP_CONVERSATION_AUDIT_BACKFILL_TIMEOUT_SECONDS:30}' \
    "$REPOSITORY_ROOT/backend/app/src/main/resources/application.yml" \
    || fail "application.yml must bind the bounded default timeout"
grep -Fq 'batch-size: ${APP_CONVERSATION_AUDIT_BACKFILL_BATCH_SIZE:50}' \
    "$REPOSITORY_ROOT/backend/app/src/main/resources/application.yml" \
    || fail "application.yml must use the maximum bounded batch-size default"
grep -Fq 'max-batches-per-run: ${APP_CONVERSATION_AUDIT_BACKFILL_MAX_BATCHES:1}' \
    "$REPOSITORY_ROOT/backend/app/src/main/resources/application.yml" \
    || fail "application.yml must default to exactly one batch per invocation"

grep -Fq 'APP_CONVERSATION_AUDIT_BACKFILL_TENANT_ID: ${APP_CONVERSATION_AUDIT_BACKFILL_TENANT_ID:-}' \
    "$REPOSITORY_ROOT/docker-compose.yml" \
    || fail "base Compose must pass the dedicated backfill tenant target"
grep -Fq 'APP_CONVERSATION_AUDIT_BACKFILL_TIMEOUT_SECONDS: ${APP_CONVERSATION_AUDIT_BACKFILL_TIMEOUT_SECONDS:-30}' \
    "$REPOSITORY_ROOT/docker-compose.yml" \
    || fail "base Compose must pass the bounded default timeout"
grep -Fq 'APP_CONVERSATION_AUDIT_BACKFILL_BATCH_SIZE: ${APP_CONVERSATION_AUDIT_BACKFILL_BATCH_SIZE:-50}' \
    "$REPOSITORY_ROOT/docker-compose.yml" \
    || fail "base Compose must pass the maximum bounded batch-size default"
grep -Fq 'APP_CONVERSATION_AUDIT_BACKFILL_MAX_BATCHES: ${APP_CONVERSATION_AUDIT_BACKFILL_MAX_BATCHES:-1}' \
    "$REPOSITORY_ROOT/docker-compose.yml" \
    || fail "base Compose must pass exactly one batch per invocation"

grep -Fq 'static final int MAX_BATCH_SIZE = 50;' \
    "$REPOSITORY_ROOT/backend/app/src/main/java/br/com/duoset/saas_service/contexts/omnichannel/internal/infrastructure/crypto/ConversationAuditBackfillProcessor.java" \
    || fail "processor must cap each backfill batch at 50 rows"
grep -Fq 'static final int MAX_BATCHES_PER_RUN = 1;' \
    "$REPOSITORY_ROOT/backend/app/src/main/java/br/com/duoset/saas_service/contexts/omnichannel/internal/infrastructure/crypto/ConversationAuditBackfillProcessor.java" \
    || fail "processor must cap each invocation at one batch"

echo "Conversation audit backfill safety contract passed"
