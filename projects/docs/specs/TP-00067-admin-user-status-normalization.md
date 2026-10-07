---
document_id: TP-00067
primary_nature: Plano
objective: Corrigir a incompatibilidade de status do administrador canônico que quebra GET /api/v1/admin/users.
scope: Migração tenant forward-only, regressão backend e validação repository-local.
non_objectives: Não alterar o fluxo de recuperação de senha, o Keycloak ou contratos HTTP.
owner: Engenharia
status: In Progress
version: 1.0
date: 2026-10-01
last_reviewed: 2026-10-01
keywords: admin-users, UserStatus, Flyway, Keycloak, tenant
related_files: TP-00063-keycloak-admin-api-realm-provisioning.md, TP-00065-keycloak-programmatic-tenant-realm-provisioning.md
code_references: backend/src/main/resources/db/migration/tenant/V93__seed_canonical_admin_identities.sql, backend/src/main/java/br/com/duoset/saas_service/contexts/tenant/internal/domain/model/valueobjects/UserStatus.java
principal_statement: V93 grava ACTIVE, enquanto o domínio aceita ATIVO, INATIVO e PENDENTE; V94 normaliza somente o valor legado sem editar uma migração aplicada.
---

# TP-00067 — Normalização do status de usuários administradores

## Implementation Readiness Gate

**Result: READY** — task atômica, autorização explícita do solicitante, paths exatos,
critério observável e dependências disponíveis.

- **Sources:** REQ-00031 v1.7 Approved; ADR-0018 Accepted; TP-00063 v1.5 Completed (V93/AC-TEN-028-D); enum `UserStatus` e adapter atuais; incidente reproduzido no log fornecido.
- **What:** fazer `/api/v1/admin/users` listar o administrador canônico e preservar o contrato de status do domínio.
- **Where:** `backend/src/main/resources/db/migration/tenant/V94__normalize_admin_user_status_values.sql`; `backend/src/test/java/br/com/duoset/saas_service/contexts/tenant/internal/infrastructure/iam/CanonicalAdminIdentityReconcilerTest.java`; teste de migração/adapter aplicável; este plano e seu índice.
- **Depends on:** migrações tenant V16/V88/V93 e enum/adapter existentes. Nenhuma dependência externa ou ambiental.
- **Reuses:** contrato de status `ATIVO|INATIVO|PENDENTE`, estratégia Flyway forward-only e testes de reconciliação canônicos.
- **Requirements:** não editar V93; converter apenas `admin_users.status = 'ACTIVE'` para `ATIVO`; impedir regressão da reconciliação; manter API sem mudança de contrato.
- **Open questions:** nenhuma aberta para este corretivo.
- **PRD/API contract:** não aplicável; a correção é de persistência interna, sem alteração de endpoint, payload ou fluxo autorizado.
- **Prohibited:** adicionar `ACTIVE` ao enum; editar V93; alterar Keycloak/produção; ler segredos; fazer force-push ou escrever em `main`.
- **Mandatory:** migration nova e reversível por backup/rollback operacional; teste focalizado; A1, A2 e A3 independentes; validador documental; commit e push em branch de trabalho.

## Acceptance Tests

1. Após aplicar V94, toda linha legada `admin_users.status = 'ACTIVE'` torna-se `ATIVO`.
2. O adapter não lança `IllegalArgumentException` ao materializar o administrador canônico.
3. A reconciliação canônica permanece idempotente e usa `ATIVO`.
4. `GET /api/v1/admin/users` deixa de falhar por `No enum constant UserStatus.ACTIVE`.

## Definition of Done

- V94 criada sem alteração de V93.
- Regressões adicionadas/atualizadas e testes focados aprovados.
- Governança documental validada e índice atualizado.
- A1 Test, A2 Quality e A3 Security/Compliance registrados separadamente como PASS ou limitação explícita.
- Commit criado na branch `fix/tp-00067-admin-user-status-normalization` e push confirmado.

## Rollback e risco

A alteração é forward-only e limitada a valores conhecidos. Rollback requer restauração
operacional do backup da tabela; não há downgrade Flyway. O risco residual é existir
algum valor fora da taxonomia do domínio, que será identificado pelos testes/diagnóstico,
sem conversão silenciosa.
