---
document_id: "ONBOARD-CONVERSATION-AUDIT-ACTIVATION"
primary_nature: "Regra"
objective: "Orientar o agente de IA de infraestrutura na ativação da API de Auditoria, configuração da allowlist de tenants, recriação forçada do backend e coordenação de deployment em HML e PRD."
scope: "Ativação de rotas HTTP de auditoria, governança de exposição por tenant, recarga de keyrings em memória e cutover de serviços em HML e PRD."
non_objectives: "Não ativar a API com allowlist vazia; não fazer deploy sem force-recreate do backend; não expor rotas sem prova de prontidão criptográfica prévia."
owner: "DevOps e SRE"
status: "Active"
date: "2026-09-29"
version: "1.0"
keywords: "onboarding, api-activation, allowlist, cutover, force-recreate, deployment, hml, prd"
related_files: "docs/onboarding/README.md, docs/onboarding/conversation-audit-hml-prd-onboarding.md, docs/onboarding/conversation-audit-backfill-readiness.md, docs/onboarding/conversation-audit-observability-rollback.md, docs/product/requirements/REQ-00041-chatbot-conversation-audit.md"
code_references: "infra/scripts/deploy-production.sh, docker-compose.prd.yml, docker-compose.hml.yml, backend/src/main/java/br/com/duoset/saas_service/contexts/omnichannel/internal/infrastructure/security/ConversationAuditApiExposurePolicy.java, backend/src/main/java/br/com/duoset/saas_service/contexts/omnichannel/internal/presentation/rest/ConversationAuditController.java"
principal_statement: "A ativação da API de auditoria exige parametrização explícita de allowlist de tenants, recriação forçada do container backend para recarga de memória e coordenação sequencial de saúde."
---

# Ativação de Exposição de API e Governança de Tenants — Conversation Audit

**Document ID:** `ONBOARD-CONVERSATION-AUDIT-ACTIVATION`  
**Owner:** DevOps e SRE  
**Status:** `Active`  
**Date:** 2026-09-29  
**Version:** 1.0  
**Ambientes Alvo:** HML e PRD  
**Documento Pai:** [Onboarding Geral de Conversation Audit em HML e PRD](conversation-audit-hml-prd-onboarding.md)

---

## 1. Responsabilidade da Feature

Esta especificação governa o procedimento de **ativação da API REST** (`/api/v1/tenants/{tenantId}/chatbot/audit/conversations/**`), a gestão da **allowlist de tenants autorizados** e a execução segura do **cutover de containers** em Homologação (`HML`) e Produção (`PRD`).

### 1.1 Política de Exposição *Default-Deny*

O [`ConversationAuditApiExposurePolicy`](../../backend/src/main/java/br/com/duoset/saas_service/contexts/omnichannel/internal/infrastructure/security/ConversationAuditApiExposurePolicy.java) implementa isolamento rigoroso:

- **Se a API estiver desligada (`APP_CONVERSATION_AUDIT_API_ENABLED=false`):** Qualquer chamada a `/search`, `/detail`, `/messages` ou `/reveal` retorna `404 Not Found` (`AUD-404-NOT_FOUND`).
- **Se o tenant não estiver na allowlist:** Retorna `404 Not Found` (`AUD-404-NOT_FOUND`), ocultando ativamente a existência do recurso para tenants não habilitados.
- **Fail-Closed em Allowlist Vazia:** Se `APP_CONVERSATION_AUDIT_API_ENABLED=true`, a propriedade `APP_CONVERSATION_AUDIT_ALLOWED_TENANT_IDS` NÃO pode ser vazia; caso contrário, a aplicação falha logo no bootstrap com `IllegalArgumentException`.

---

## 2. Pré-requisitos para Ativação

O agente de infraestrutura DEVE comprovar as seguintes condições antes de ligar a API:

1. [Keyrings provisionados e montados](conversation-audit-keyring-provisioning.md) em `/run/saas-secrets`.
2. [Prontidão durável comprovada](conversation-audit-backfill-readiness.md) para o tenant com os 5 contadores de risco zerados.
3. [RBAC e Role Mapping configurados](conversation-audit-keycloak-rbac.md) no Keycloak.

> [!CAUTION]
> Tentar ativar a API para um tenant cuja prontidão durável não foi atestada resultará em erros imediatos `503 Service Unavailable` em todas as consultas da interface.

---

## 3. Procedimento Operacional de Cutover

### 3.1 Passo 1: Atualização das Variáveis de Ambiente no Host

Edite o arquivo de ambiente seguro (`.env.production` em PRD ou `.env.hml` em HML):

```properties
# Confirma os keyrings carregados pelo serviço antes do cutover
CONVERSATION_AUDIT_AES_ACTIVE_KEY_ID=<hml-ou-prd-audit-aes-vN>
CONVERSATION_AUDIT_AES_KEYRING_FILE=/run/saas-secrets/conversation-audit-aes-keyring.json
CONVERSATION_AUDIT_HMAC_ACTIVE_KEY_ID=<hml-ou-prd-audit-hmac-vN>
CONVERSATION_AUDIT_HMAC_KEYRING_FILE=/run/saas-secrets/conversation-audit-hmac-keyring.json

# Habilita a exposição da API de Auditoria
APP_CONVERSATION_AUDIT_API_ENABLED=true

# Lista de UUIDs canônicos autorizados (separados por vírgula)
APP_CONVERSATION_AUDIT_ALLOWED_TENANT_IDS=11111111-2222-3333-4444-555555555555

# Assegura que o backfill e a leitura legada permaneçam desligados
APP_CONVERSATION_AUDIT_BACKFILL_ENABLED=false
APP_CONVERSATION_AUDIT_LEGACY_READ_ENABLED=false
```

### 3.2 Passo 2: Recriação Forçada do Backend (`--force-recreate`)

Como as chaves criptográficas e as flags são carregadas em memória no momento de inicialização da JVM, uma reinicialização simples (`restart`) pode não forçar a releitura adequada de variáveis ou volumes. A recriação do container é obrigatória.

#### Em Ambiente de Homologação (HML):
```bash
docker compose --env-file /path/to/owner-only-hml.env \
  -f docker-compose.yml -f docker-compose.hml.yml \
  up -d --no-build --no-deps --force-recreate backend
```

#### Em Ambiente de Produção (PRD):
Execute o script canônico de deploy que coordena o ciclo de atualização e verificação de saúde:
```bash
./infra/scripts/deploy-production.sh update
```

### 3.3 Passo 3: Verificação de Saúde do Backend

Aguarde a estabilização do container e consulte o Actuator Health:

```bash
curl -s -f http://localhost:8080/actuator/health | grep '"status":"UP"'
```

Se o Actuator não responder em até 120 segundos ou reportar `DOWN`, consulte os logs sanitizados para verificar se houve colisão de keyrings ou erro de allowlist:
```bash
docker logs --tail 100 saas-backend
```

### 3.4 Passo 4: Sincronização do Frontend

Após o backend confirmar status `UP`:

1. Em HML/PRD, garanta que o container `frontend` está ativo e recriado com as variáveis de roteamento corretas.
2. Acesse a aplicação no navegador ou execute o probe de status em `https://app.agentefiscal.com.br/audit` ou `https://app-hml.agentefiscal.com.br/audit`.

---

## 4. Governança Multi-Tenant da Allowlist

Para adicionar novos tenants à auditoria em momentos posteriores:

1. Execute o processo de [Backfill e Prontidão Durável](conversation-audit-backfill-readiness.md) exclusivamente para o novo tenant (`APP_CONVERSATION_AUDIT_BACKFILL_TENANT_ID=<NOVO_UUID>`).
2. Adicione o novo UUID à lista separada por vírgulas em `APP_CONVERSATION_AUDIT_ALLOWED_TENANT_IDS`:
   ```properties
   APP_CONVERSATION_AUDIT_ALLOWED_TENANT_IDS=11111111-2222-3333-4444-555555555555,66666666-7777-8888-9999-000000000000
   ```
3. Execute o reload ou `update` do backend.

---

## 5. Próximo Passo

Com a API ativada e os tenants governados:
- Execute a bateria de validação descrita em [Observabilidade, Validação Sanitizada e Playbook de Rollback](conversation-audit-observability-rollback.md).
