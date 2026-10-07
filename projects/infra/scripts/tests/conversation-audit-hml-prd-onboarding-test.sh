#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)
cd "$ROOT_DIR"

for compose in docker-compose.hml.yml docker-compose.prd.yml; do
  grep -q '^  conversation-audit-keyring-init:' "$compose"
  grep -q 'CONVERSATION_AUDIT_AES_ACTIVE_KEY_ID' "$compose"
  grep -q 'CONVERSATION_AUDIT_HMAC_ACTIVE_KEY_ID' "$compose"
  grep -q 'conversation-audit-keyring-init:' "$compose"
  grep -q 'conversation-audit-aes-keyring.json' "$compose"
  grep -q 'conversation-audit-hmac-keyring.json' "$compose"
done

grep -q 'APP_CONVERSATION_AUDIT_API_ENABLED=false' infra/deploy/production.env.example
grep -q 'CONVERSATION_AUDIT_AES_KEYRING_FILE=' infra/deploy/production.env.example
grep -q 'curl -s -D - -o /dev/null -X POST' docs/onboarding/conversation-audit-observability-rollback.md
grep -q 'Plano de Execução e Matriz de Paridade' docs/onboarding/conversation-audit-hml-prd-onboarding.md

printf '%s\n' 'conversation-audit HML/PRD onboarding contract: PASS'
