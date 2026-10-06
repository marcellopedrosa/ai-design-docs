---
document_id: "ONBOARD-CONVERSATION-AUDIT-OBSERVABILITY"
primary_nature: "Regra"
objective: "Orientar o agente de IA de infraestrutura na execução de smoke tests sanitizados, monitoramento de métricas, regras de alerta e execução do playbook de contenção rápida e rollback em HML e PRD."
scope: "Validação pós-ativação de auditoria de conversas, telemetria Prometheus/Grafana e procedimentos de contingência fail-closed em HML e PRD."
non_objectives: "Não registrar payloads, tokens ou PII em evidências; não deletar keyrings de leitura em incidentes; não realizar testes destrutivos em produção."
owner: "SRE e DevOps"
status: "Active"
date: "2026-09-29"
version: "1.0"
keywords: "onboarding, observabilidade, smoke-tests, prometheus, grafana, rollback, fail-closed, hml, prd"
related_files: "docs/onboarding/README.md, docs/onboarding/conversation-audit-hml-prd-onboarding.md, docs/onboarding/conversation-audit-api-activation.md, docs/product/requirements/REQ-00041-chatbot-conversation-audit.md, docs/product/requirements/REQ-00043-conversation-audit-data-governance.md"
code_references: "infra/monitoring/prometheus/alert_rules.yml, infra/monitoring/grafana/dashboards/conversation-audit.json, backend/src/main/java/br/com/duoset/saas_service/contexts/omnichannel/internal/infrastructure/adapter/MicrometerConversationAuditMetricsAdapter.java, backend/src/main/java/br/com/duoset/saas_service/contexts/omnichannel/internal/infrastructure/security/ConversationAuditSecurityFilter.java"
principal_statement: "A validação operacional do Conversation Audit é estritamente sanitizada e sem PII, com telemetria contínua via Prometheus e rollback determinístico por fechamento imediato de flags sem perda de chaves."
---

# Observabilidade, Validação Sanitizada e Playbook de Rollback — Conversation Audit

**Document ID:** `ONBOARD-CONVERSATION-AUDIT-OBSERVABILITY`  
**Owner:** SRE e DevOps  
**Status:** `Active`  
**Date:** 2026-09-29  
**Version:** 1.0  
**Ambientes Alvo:** HML e PRD  
**Documento Pai:** [Onboarding Geral de Conversation Audit em HML e PRD](conversation-audit-hml-prd-onboarding.md)

---

## 1. Responsabilidade da Feature

Esta especificação governa a **bateria de smoke tests sanitizados de validação pós-deploy**, a **telemetria operacional** (métricas Prometheus e painéis Grafana) e o **playbook de contenção e rollback de emergência** em Homologação (`HML`) e Produção (`PRD`).

---

## 2. Bateria de Smoke Tests Sanitizados (Caixa-Preta)

O agente de infraestrutura DEVE realizar a validação dos endpoints REST da auditoria através de requisições HTTP dirigidas, avaliando códigos de status e headers.

> [!IMPORTANT]
> **Regra de Zero PII:** O agente NUNCA deve inspecionar, copiar ou armazenar o corpo JSON de conversas, telefones, mensagens ou tokens JWT em relatórios ou transcripts. Registre exclusivamente os códigos HTTP observados (`200`, `400`, `403`, `404`) e a presença dos cabeçalhos esperados.

### 2.1 Teste 1: Camuflagem de Tenant Fora da Allowlist (Esperado: 404)

Dispare uma busca utilizando um UUID aleatório inexistente ou não constante em `APP_CONVERSATION_AUDIT_ALLOWED_TENANT_IDS`:

```bash
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -X POST \
  -H "Authorization: Bearer <TOKEN_VALIDO_AUDITOR>" \
  -H "Content-Type: application/json" \
  -d '{"page":0,"size":10}' \
  "https://<API_URL>/api/v1/tenants/00000000-0000-0000-0000-000000000000/chatbot/audit/conversations/search")

[ "$HTTP_CODE" = "404" ] || { echo "FAIL: Esperava 404 na camuflagem, obteve $HTTP_CODE"; exit 1; }
```

### 2.2 Teste 2: Bloqueio de Usuário Sem Perfil de Auditoria (Esperado: 403)

Dispare uma requisição utilizando token de usuário que possui apenas `ROLE_TENANT_ADMIN` (sem `ROLE_TENANT_AUDIT`):

```bash
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -X POST \
  -H "Authorization: Bearer <TOKEN_ADMIN_SEM_AUDIT>" \
  -H "Content-Type: application/json" \
  -d '{"page":0,"size":10}' \
  "https://<API_URL>/api/v1/tenants/<CANONICAL_TENANT_UUID>/chatbot/audit/conversations/search")

[ "$HTTP_CODE" = "403" ] || { echo "FAIL: Esperava 403 por falta de role, obteve $HTTP_CODE"; exit 1; }
```

### 2.3 Teste 3: Rejeição de UUID Malformado (Esperado: 400)

Dispare uma requisição informando um tenant não canônico (ex.: com espaços, maiúsculas ou caracteres inválidos):

```bash
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -X POST \
  -H "Authorization: Bearer <TOKEN_VALIDO_AUDITOR>" \
  -H "Content-Type: application/json" \
  -d '{"page":0,"size":10}' \
  "https://<API_URL>/api/v1/tenants/invalid-uuid-segment/chatbot/audit/conversations/search")

[ "$HTTP_CODE" = "400" ] || { echo "FAIL: Esperava 400 por UUID inválido, obteve $HTTP_CODE"; exit 1; }
```

### 2.4 Teste 4: Sucesso de Busca Autenticada e Headers de Segurança (Esperado: 200)

Dispare a busca com token válido de auditor para o tenant autorizado:

```bash
HEADERS_DUMP=$(curl -s -D - -o /dev/null -X POST \
  -H "Authorization: Bearer <TOKEN_VALIDO_AUDITOR>" \
  -H "Content-Type: application/json" \
  -d '{"page":0,"size":10}' \
  "https://<API_URL>/api/v1/tenants/<CANONICAL_TENANT_UUID>/chatbot/audit/conversations/search")

echo "$HEADERS_DUMP" | grep -q "HTTP/.* 200" || { echo "FAIL: Busca não retornou 200 OK"; exit 1; }
echo "$HEADERS_DUMP" | grep -qi "Cache-Control:.*no-store" || { echo "FAIL: Header Cache-Control no-store ausente"; exit 1; }
echo "$HEADERS_DUMP" | grep -qi "X-RateLimit-Limit:" || { echo "FAIL: Header X-RateLimit-Limit ausente"; exit 1; }
```

---

## 3. Telemetria e Monitoramento Contínuo

### 3.1 Métricas Micrometer / Prometheus

O backend expõe métricas dedicadas para monitorar a operação de auditoria:

| Métrica | Tags | Descrição |
|---|---|---|
| `conversation_audit_access_total` | `operation`, `outcome`, `status` | Total de tentativas de acesso à auditoria (outcome: `SUCCESS`, `FORBIDDEN`, `UNAVAILABLE`, `RATE_LIMITED`). |
| `conversation_audit_rate_limit_decisions_total` | `operation`, `decision` | Decisões do limitador de taxa (`ALLOW` vs `REJECT`). |
| `conversation_audit_crypto_operations_total` | `operation`, `outcome` | Operações criptográficas executadas (`DECRYPT`, `BLIND_INDEX`). |

### 3.2 Regras de Alerta no Prometheus (`alert_rules.yml`)

As seguintes regras em `infra/monitoring/prometheus/alert_rules.yml` devem ser mantidas ativas:

1. **`ConversationAuditReadinessFailed`:** Dispara se o resultado de acesso indicar `UNAVAILABLE` por quebra contínua de prontidão durável (`ready = false` no banco).
2. **`ConversationAuditCryptoFailures`:** Dispara se a taxa de erro criptográfico for superior a zero em uma janela de 5 minutos (possível problema de keyring).
3. **`ConversationAuditRateLimitSpike`:** Dispara se o volume de rejeições por rate limit ultrapassar 20% do volume total de requisições de auditoria.

### 3.3 Painel no Grafana

O painel dedicado de auditoria está versionado em:
`infra/monitoring/grafana/dashboards/conversation-audit.json`.  
Ele exibe:
- Taxa de requisições por segundo e latência p95/p99;
- Distribuição de códigos de retorno HTTP;
- Utilização de orçamentos de rate limit por usuário e tenant.

---

## 4. Playbook de Contenção Rápida e Rollback (*Fail-Closed*)

Caso ocorra degradação no banco, indisponibilidade ou suspeita de comprometimento de credenciais:

### 4.1 Contenção Imediata (Fast Containment)

A exposição externa da auditoria pode ser desligada instantaneamente sem reiniciar os bancos ou interromper os chatbots de WhatsApp e Telegram:

1. **Desligar a Exposição no Arquivo `.env` do Host:**
   ```properties
   APP_CONVERSATION_AUDIT_API_ENABLED=false
   APP_CONVERSATION_AUDIT_ALLOWED_TENANT_IDS=
   ```
2. **Recriar o Backend:**
   - Em **PRD**: `./infra/scripts/deploy-production.sh update`
   - Em **HML**:
     ```bash
     docker compose --env-file /path/to/.env.hml \
       -f docker-compose.yml -f docker-compose.hml.yml \
       up -d --no-build --no-deps --force-recreate backend
     ```
3. **Comprovar Fechamento:**
   Execute a chamada de busca e comprove retorno `404 Not Found`.

### 4.2 Invariantes em Situação de Emergência

- **NUNCA DELETA ARQUIVOS DE KEYRING:** Mesmo em rollback de versão, os keyrings AES e HMAC DEVEM ser preservados no disco. A exclusão de um keyring torna todos os identificadores de conversas já gravados no banco permanentemente indecifráveis.
- **NUNCA FAÇA DOWN MIGRATIONS NO FLYWAY:** O schema de banco é aditivo e estritamente *forward-only*.
- **Restauração em Caso de Corrupção:** Se ocorrer corrupção de tabelas, isole o tenant e utilize o backup previamente validado na Seção 3 do onboarding principal.

## Dependência do webhook Telegram

Em HML/PRD, `503` com `PERSISTENCE_UNAVAILABLE` ou `Inbound durable acceptance unavailable` significa que o update foi recusado antes da persistência durável, normalmente por keyring ausente/montado incorretamente, variável `CONVERSATION_*` ausente ou falha de conexão/transação. Trate como incidente de provisionamento, não como falha do Telegram: preserve o `errorId`, valide os três arquivos em `/run/saas-secrets` sem imprimir conteúdo e confirme os seis IDs ativos.

O rollback deve recriar o backend pelo fluxo canônico e preservar os keyrings e seus backups. Nunca remova volumes de segredo, use `drop_pending_updates` ou registre novamente o webhook como tentativa de “limpar” o erro. Depois do health check, valide `getWebhookInfo`, ausência de erro recente e um smoke controlado.
