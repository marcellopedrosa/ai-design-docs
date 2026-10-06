---
document_id: "ONBOARD-CONVERSATION-AUDIT-RETENTION"
primary_nature: "Regra"
objective: "Orientar o agente de IA de infraestrutura na governança, configuração e habilitação segura da administração da política de retenção do Conversation Audit em HML e PRD."
scope: "Aba Política de Retenção de /audit, endpoints REST de settings/conversation-audit-retention, autorização de Super Admin personificado e guardas operacionais de expurgo em HML e PRD."
non_objectives: "Não autorizar expurgo destrutivo sem aprovação formal de DPO/Compliance e SRE; não permitir acesso de Tenant Admin ou Auditor à configuração de retenção; não executar delete síncrono via HTTP."
owner: "DevOps, Segurança e Governança"
status: "Active"
date: "2026-09-29"
version: "1.0"
keywords: "onboarding, retencao, expurgo, super-admin, personificacao, policy-version, hml, prd"
related_files: "docs/onboarding/README.md, docs/onboarding/conversation-audit-hml-prd-onboarding.md, docs/product/requirements/REQ-00041-chatbot-conversation-audit.md, docs/product/requirements/REQ-00043-conversation-audit-data-governance.md, docs/api_contracts/conversation-audit-retention-policy-v1.openapi.yaml"
code_references: "docs/api_contracts/conversation-audit-retention-policy-v1.openapi.yaml, backend/src/main/resources/db/migration/tenant/V59__create_conversation_audit_retention_policy.sql, backend/src/main/resources/db/migration/tenant/V61__harden_conversation_audit_retention_policy.sql, backend/src/main/resources/db/migration/tenant/V91__prepare_conversation_audit_retention_policy_administration.sql, backend/src/main/java/br/com/duoset/saas_service/contexts/tenant/internal/presentation/rest/ConversationAuditRetentionPolicyController.java"
principal_statement: "A administração da política de retenção é exclusiva para Super Admin sob personificação ativa do tenant, com limites de 1 a 180 dias, preview com token opaco e expurgo fail-closed estritamente assíncrono."
---

# Administração da Política de Retenção de Conversas e Acesso — Conversation Audit

**Document ID:** `ONBOARD-CONVERSATION-AUDIT-RETENTION`  
**Owner:** DevOps, Segurança e Governança  
**Status:** `Active`  
**Date:** 2026-09-29  
**Version:** 1.0  
**Ambientes Alvo:** HML e PRD  
**Documento Pai:** [Onboarding Geral de Conversation Audit em HML e PRD](conversation-audit-hml-prd-onboarding.md)

---

## 1. Responsabilidade da Feature

Esta especificação governa o controle de acesso, o contrato de API e a ativação das **políticas de retenção e expurgo de dados conversacionais e eventos de auditoria** (`/api/v1/tenants/{tenantId}/settings/conversation-audit-retention/**`), refletida na aba "Política de Retenção" da interface web `/audit` em Homologação (`HML`) e Produção (`PRD`).

### 1.1 Invariantes de Autorização e Governança

1. **Acesso Exclusivo por Super Admin com Personificação Ativa:**  
   Nem `ROLE_TENANT_ADMIN` nem `ROLE_TENANT_AUDIT` possuem permissão para visualizar ou editar a política de retenção. O acesso exige que a identidade possua autoridade bruta **`ROLE_SUPER_ADMIN`** no realm `saas-admin` **E** esteja sob **personificação ativa e coerente** do tenant alvo (enviando o header `X-Tenant-ID`).
2. **Faixa Estrita de Dias (1 a 180):**  
   Os prazos de retenção de conversas e de eventos de acesso aceitam unicamente inteiros no intervalo fechado de **`1..180` dias**. Qualquer valor fora desse intervalo é rejeitado no frontend, controller, domínio e banco de dados.
3. **Zero Delete via HTTP (Expurgo Estritamente Assíncrono):**  
   Salvar uma política via `PUT` nunca remove dados de forma síncrona. O expurgo físico é sempre executado em segundo plano por workers agendados, sob múltiplas guardas operacionais.
4. **Previsão Bounded (*Preview Token*):**  
   A ativação de expurgo ou a redução de prazos exige geração prévia de preview (`POST .../preview`) que retorna contagens agregadas delimitadas e um token opaco criptográfico com validade máxima de **300 segundos**, que deve ser apresentado no `PUT`.
5. **Controle de Concorrência Otimista:**  
   O `PUT` exige o cabeçalho `If-Policy-Version` ou o campo `policyVersion` correspondente à versão atual, impedindo sobrescritas acidentais concorrentes.

---

## 2. Guardas Operacionais de Expurgo Destrutivo

Mesmo que um Super Admin configure a retenção na interface, o worker de expurgo físico só deleta dados se **todas** as seguintes guardas de infraestrutura estiverem simultaneamente satisfeitas no backend:

| Guarda Operacional | Propriedade no `application.yml` | Valor Requerido para Deletar | Comportamento Fail-Closed |
|---|---|:---:|---|
| **Master Switch de Retenção** | `app.conversation-audit.retention.enabled` | `true` | Se `false`, nenhum worker destrutivo é agendado. |
| **Legal Hold da Organização** | `app.conversation-audit.retention.legal-hold` | `false` | Se `true`, nenhum registro de conversa é excluído. |
| **Prontidão de Backup & Restore** | `app.conversation-audit.retention.backup-restore-ready` | `true` | Se `false`, o expurgo é cancelado e gera alerta. |
| **Modo Dry-Run Desativado** | `app.conversation-audit.retention.dry-run` | `false` | Se `true`, apenas calcula e loga contagens, sem delete. |
| **Flag na Linha da Policy** | `conversation_purge_enabled` / `audit_access_purge_enabled` | `true` | Se `false`, a limpeza não atua no respectivo dataset. |

> [!CAUTION]
> Em HML e PRD, mantenha `app.conversation-audit.retention.backup-restore-ready=false` e `dry-run=true` até que todos os relatórios formais de restore drill isolado e retenção estejam aprovados pelo DPO e SRE.

---

## 3. Contrato de Endpoints da API

Os endpoints estão sob o caminho seguro do tenant:

### 3.1 Consulta da Política Vigente
- **Método:** `GET /api/v1/tenants/{tenantId}/settings/conversation-audit-retention`
- **Autoridade:** `ROLE_SUPER_ADMIN` sob personificação ativa.
- **Headers de Retorno:** `Cache-Control: no-store`, `Policy-Version: <versao>`.

### 3.2 Simulação e Emissão de Token de Preview
- **Método:** `POST /api/v1/tenants/{tenantId}/settings/conversation-audit-retention/preview`
- **Corpo:** JSON contendo os prazos pretendidos (`conversationDays`, `auditAccessDays`, `enabled`).
- **Retorno:** Contagens estimadas de exclusão e token opaco de preview (`previewToken`).

### 3.3 Persistência da Política
- **Método:** `PUT /api/v1/tenants/{tenantId}/settings/conversation-audit-retention`
- **Headers:** `If-Policy-Version: <versao>`
- **Corpo:** JSON contendo prazos, flags e `previewToken`.
- **Efeito:** Gravação atômica da política e registro imutável no ledger de auditoria (`conversation_audit_retention_policy_mutation_ledger`), sem exclusão síncrona.

---

## 4. Reconciliação de Cache e Namespace no Redis

A política de retenção ativa é projetada em cache no Redis através da chave namespaced:
`conversation-audit:retention-policy:v1:namespace`

- A geração global utiliza um token opaco CSPRNG de 32 bytes codificado em Base64URL (exatamente 43 caracteres).
- Caso o cache esteja ausente ou seja rotacionado, o backend busca a versão canônica no PostgreSQL (`saas_tenant`) via fallback sem indisponibilidade.

---

## 5. Critérios de Aceitação para o Agente de IA

- [ ] Usuários comuns e Tenant Admins recebem `403 Forbidden` ao tentar acessar a aba ou a API de retenção.
- [ ] Super Admin sem header `X-Tenant-ID` recebe `403 Forbidden`.
- [ ] Super Admin sob personificação de tenant ativo visualiza a política e recebe status `200 OK`.
- [ ] Valores de dias menores que 1 ou maiores que 180 são rejeitados com `400 Bad Request`.
- [ ] As variáveis de infraestrutura em HML/PRD mantêm `backup-restore-ready=false` e `dry-run=true` até assinatura formal do DPO.
