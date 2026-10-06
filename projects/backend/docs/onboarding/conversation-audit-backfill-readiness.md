---
document_id: "ONBOARD-CONVERSATION-AUDIT-BACKFILL"
primary_nature: "Regra"
objective: "Orientar o agente de IA de infraestrutura na execução do backfill supervisionado e na validação da prova durável de prontidão criptográfica (Data Protection Readiness) em HML e PRD."
scope: "Migração de identificadores em texto plano, geração de blind index, atestação no fingerprint definitivo e verificação dos 5 contadores de risco zerados na tabela de prontidão durável em HML e PRD."
non_objectives: "Não executar backfill em múltiplos tenants simultaneamente; não expor valores de identificadores em logs; não pular a verificação SQL canônica."
owner: "DevOps, SRE e Segurança"
status: "Active"
date: "2026-09-29"
version: "1.0"
keywords: "onboarding, backfill, readiness, data-protection, fingerprint, sql, hml, prd"
related_files: "docs/onboarding/README.md, docs/onboarding/conversation-audit-hml-prd-onboarding.md, docs/onboarding/conversation-audit-keyring-provisioning.md, docs/onboarding/conversation-audit-api-activation.md, docs/product/requirements/REQ-00041-chatbot-conversation-audit.md, docs/product/requirements/REQ-00043-conversation-audit-data-governance.md"
code_references: "backend/src/main/java/br/com/duoset/saas_service/contexts/omnichannel/internal/infrastructure/crypto/ConversationAuditBackfillRunner.java, backend/src/main/java/br/com/duoset/saas_service/contexts/omnichannel/internal/infrastructure/crypto/ConversationAuditBackfillProcessor.java, backend/src/main/java/br/com/duoset/saas_service/contexts/omnichannel/internal/infrastructure/crypto/ConversationAuditReadinessQuery.java, backend/src/main/resources/db/migration/omnichannel/V34__add_conversation_audit_data_protection_readiness.sql, backend/src/main/resources/db/migration/omnichannel/V39__enforce_continuous_conversation_audit_readiness.sql"
principal_statement: "A prontidão durável de dados é um requisito bloqueante da API de auditoria, exigindo execução de backfill unitário 50x1 e verificação de zero riscos sob o fingerprint definitivo na tabela conversation_audit_data_protection_readiness."
---

# Backfill Supervisionado e Prontidão Criptográfica Durável — Conversation Audit

**Document ID:** `ONBOARD-CONVERSATION-AUDIT-BACKFILL`  
**Owner:** DevOps, SRE e Segurança  
**Status:** `Active`  
**Date:** 2026-09-29  
**Version:** 1.0  
**Ambientes Alvo:** HML e PRD  
**Documento Pai:** [Onboarding Geral de Conversation Audit em HML e PRD](conversation-audit-hml-prd-onboarding.md)

---

## 1. Responsabilidade da Feature

Esta especificação governa o procedimento operacional de **migração retroativa de dados (Backfill)** e a comprovação da **prova durável de prontidão (*Data Protection Readiness*)** de um tenant antes da liberação da API de Auditoria em Homologação (`HML`) e Produção (`PRD`).

### 1.1 Por Que a Prontidão Durável é Necessária?

Mesmo com as chaves criptográficas configuradas, o [`ConversationAuditSecurityFilter`](../../backend/src/main/java/br/com/duoset/saas_service/contexts/omnichannel/internal/infrastructure/security/ConversationAuditSecurityFilter.java) e o [`ConversationAuditReadinessQuery`](../../backend/src/main/java/br/com/duoset/saas_service/contexts/omnichannel/internal/infrastructure/crypto/ConversationAuditReadinessQuery.java) bloqueiam qualquer requisição de auditoria com status **`503 Service Unavailable`** caso a tabela `conversation_audit_data_protection_readiness` não ateste que **100%** dos registros do tenant estão protegidos contra vazamento de texto plano.

---

## 2. Invariantes de Execução do Backfill

O agente de infraestrutura DEVE obedecer rigorosamente às seguintes restrições:

1. **Alvo Estritamente Unitário:** É proibido executar backfill em lote para todos os tenants simultaneamente. O parâmetro `APP_CONVERSATION_AUDIT_BACKFILL_TENANT_ID` DEVE conter exatamente um UUID canônico de tenant registrado e provisionado.
2. **Dimensionamento Bounded:** O tamanho de lote (`batch-size`) DEVE ser fixado em no máximo `50` (`APP_CONVERSATION_AUDIT_BACKFILL_BATCH_SIZE=50`), e `max-batches-per-run` DEVE ser `1`.
3. **Timeout de Transação:** O tempo limite do processador (`APP_CONVERSATION_AUDIT_BACKFILL_TIMEOUT_SECONDS`) é fixado em `30` segundos (máximo permitido de `300`). Caso uma transação atinja o timeout, a operação é revertida atomicamente sem corrupção de estado.
4. **Sem Reinício Automático:** Durante as janelas de backfill, o container do backend DEVE rodar com a flag de reinício desativada (`restart: "no"`), evitando loops em caso de falha.
5. **Composição em Duas Fases:** A migração exige transição em duas etapas:
   - **Fase A (Legacy Read On):** Cifra conversas legadas em texto plano e calcula os blind indexes;
   - **Fase B (Definitiva - Legacy Read Off):** Remove a compatibilidade de leitura em texto plano e atesta a base no fingerprint criptográfico final.

---

## 3. Procedimento Operacional Passo a Passo

### 3.1 Pré-requisito: Backup Pré-Backfill

Antes de disparar o primeiro lote de migração, confirme a existência de backup recente:
- Em **PRD**: execute `./infra/scripts/deploy-production.sh backup --upload-offsite` e comprove status de sucesso.
- Em **HML**: gere dump dos bancos via pg_dump em storage local `0700`.

---

### 3.2 Fase A — Cifragem de Texto Plano Legado

Se o tenant contiver conversas gravadas antes da introdução da criptografia:

1. **Configurar o arquivo de ambiente (`.env.production` ou `.env.hml`):**
   ```properties
   # Habilita contexto geral e mantém API pública fechada
   APP_CONVERSATION_AUDIT_ENABLED=true
   APP_CONVERSATION_AUDIT_API_ENABLED=false
   APP_CONVERSATION_AUDIT_ALLOWED_TENANT_IDS=

   # Habilita backfill unitário supervisionado
   APP_CONVERSATION_AUDIT_BACKFILL_ENABLED=true
   APP_CONVERSATION_AUDIT_BACKFILL_TENANT_ID=<CANONICAL_TENANT_UUID>
   APP_CONVERSATION_AUDIT_BACKFILL_BATCH_SIZE=50
   APP_CONVERSATION_AUDIT_BACKFILL_MAX_BATCHES=1
   APP_CONVERSATION_AUDIT_BACKFILL_TIMEOUT_SECONDS=30

   # Habilita temporariamente a leitura de texto plano para migração
   APP_CONVERSATION_AUDIT_LEGACY_READ_ENABLED=true
   ```

2. **Executar a Invocação do Backfill:**
   Dispare a execução do runner. O processador seleciona até 50 linhas com texto plano ou attestation nula, aplica o algoritmo AES-256 GCM e grava o hash cego HMAC.

3. **Repetição e Monitoramento:**
   Repita a execução de lote até que os logs sanitizados registrem:
   - `eligible_plaintext = 0`
   - `processed >= 0`
   - `failed = 0`

---

### 3.3 Fase B — Atestação no Fingerprint Definitivo

Com todo texto plano convertido para envelopes `enc:v1:`, a base DEVE ser atestada com a leitura legada desligada:

1. **Desabilitar a leitura legada no ambiente:**
   ```properties
   APP_CONVERSATION_AUDIT_LEGACY_READ_ENABLED=false
   ```
   *(Mantenha `APP_CONVERSATION_AUDIT_BACKFILL_ENABLED=true` e o mesmo `TENANT_ID`).*

2. **Executar a Verificação Definitiva:**
   Dispare o runner novamente. Ele recalculará o fingerprint criptográfico sem a permissão legada e fará uma varredura de integridade independente na tabela de conversas.

3. **Desativar o Backfill:**
   Assim que o lote finalizar com sucesso:
   ```properties
   APP_CONVERSATION_AUDIT_BACKFILL_ENABLED=false
   APP_CONVERSATION_AUDIT_BACKFILL_TENANT_ID=
   ```

---

## 4. Query SQL de Validação da Prontidão Durável

O agente de infraestrutura DEVE conectar-se ao PostgreSQL do tenant e executar a consulta canônica para comprovar a prontidão:

```sql
SELECT 
    tenant_id,
    operation,
    ready,
    checkpoint_completed,
    verification_completed,
    eligible_plaintext,
    missing_or_invalid_hash,
    unknown_or_invalid_key_id,
    missing_or_stale_attestation,
    pending_activity,
    verified_at
FROM conversation_audit_data_protection_readiness
WHERE tenant_id = '<CANONICAL_TENANT_UUID>'
  AND operation = 'CONVERSATION_AUDIT_DATA_PROTECTION';
```

### 4.1 Critérios Rígidos de Aprovação (Zero-Risk Proof)

A tabela abaixo define os valores esperados. **Qualquer divergência reprova a prontidão:**

| Coluna | Valor Obrigatório | Significado |
|---|:---:|---|
| `ready` | `TRUE` | O tenant está formalmente pronto para expor a auditoria. |
| `checkpoint_completed` | `TRUE` | O lote de checkpoint concluiu seu ciclo. |
| `verification_completed` | `TRUE` | A validação independente de integridade foi executada. |
| `eligible_plaintext` | `0` | **Zero** registros contendo texto plano. |
| `missing_or_invalid_hash` | `0` | **Zero** registros com blind index ausente ou divergente. |
| `unknown_or_invalid_key_id`| `0` | **Zero** registros cifrados com chaves não cadastradas no keyring. |
| `missing_or_stale_attestation`| `0` | **Zero** registros com hash de atestação desatualizado. |
| `pending_activity` | `0` | **Zero** mensagens órfãs com timestamps posteriores à conversa. |
| `verified_at` | `IS NOT NULL` | Timestamp UTC comprovando a data/hora da atestação. |

### 4.2 Verificação de Ausência de Registros Não Protegidos

Adicionalmente, execute a consulta de sanidade na tabela `conversations`:

```sql
SELECT COUNT(*) AS unencrypted_count
FROM conversations
WHERE tenant_id = '<CANONICAL_TENANT_UUID>'
  AND (remote_identifier_protection_fingerprint IS NULL);
```

> **Resultado Esperado:** `unencrypted_count = 0`. Se o resultado for maior que zero, o tenant permanece inapto para ativação da API.

---

## 5. Invalidação Contínua de Prontidão (Regra V39)

A prontidão durável não é um passe perpétuo. A migration `V39` instalou triggers e restrições de integridade contínua:

- Se uma nova mensagem ou conversa for inserida violando a integridade ou sem proteção criptográfica adequada, o marcador de prontidão é automaticamente invalidado no banco.
- Caso isso ocorra, o `ConversationAuditSecurityFilter` detectará a violação na próxima requisição e voltará a responder `503 Service Unavailable` em regime *fail-closed*.

---

## 6. Próximo Passo

Uma vez comprovada a prontidão durável e os 5 riscos em zero:
- Proceda para o [Provisionamento de RBAC no Keycloak](conversation-audit-keycloak-rbac.md);
- E em seguida, para a [Ativação de Exposição de API](conversation-audit-api-activation.md).
