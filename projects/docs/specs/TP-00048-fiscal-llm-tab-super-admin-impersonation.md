---
document_id: "TP-00048"
primary_nature: Plano
objective: Corrigir e verificar a visibilidade da aba Extração LLM em /fiscal durante personificação de Super Admin.
scope: Frontend /fiscal, teste focalizado, gates frontend e reconciliação documental.
non_objectives: Não alterar backend, effective roles, Keycloak, DAS Cobrança, deploy ou runtime externo.
owner: Engenharia e Frontend
status: Completed — repository-local
version: v1.1
date: 2026-09-09
last_reviewed: 2026-09-09
keywords: fiscal, LLM, Super Admin, personificação, correção
related_files: do../../product/requirements/REQ-00060-fiscal-llm-tab-super-admin-impersonation.md
code_references: frontend/src/app/(dashboard)/fiscal/page.tsx, frontend/src/lib/fiscal/llmExtractionAccess.ts, frontend/src/lib/fiscal/__tests__/llmExtractionAccess.test.ts
principal_statement: A visibilidade administrativa usa a role global original; permissões tenant continuam usando roles efetivas.
---

# TP-00048 — Aba Extração LLM na personificação

**Document ID:** `TP-00048`

## Task TP-00048-F01

- **What:** trocar somente a decisão de visibilidade da aba Extração LLM para a credencial global e cobrir a matriz de acesso.
- **Where:** `frontend/src/app/(dashboard)/fiscal/page.tsx`, helper e teste focalizados em `frontend/src/lib/fiscal/`.
- **Depends on:** REQ-00060 aprovado e `useAuth().hasRole` existente.
- **Reuses:** `ROLES.SUPER_ADMIN`, `hasRole` e a resolução atual de papéis efetivos.
- **Requirements:** REQ-00060 `AC-001` a `AC-005`.
- **Gate Audit:** `READY` em 2026-09-09; fonte aprovada, decisão humana materializada, paths e comportamento finitos, zero assumptions/open questions/TBD e nenhuma dependência externa.
- **Acceptance Tests:** Super Admin original permitido mesmo quando seu papel efetivo é Tenant Admin; Tenant Admin nativo negado; papel efetivo das operações não é alterado.
- **Prohibited:** modificar `effective-roles.ts`, ampliar a mudança para outras rotas, reduzir RBAC backend ou executar deploy.
- **Mandatory:** teste focalizado, lint dos arquivos afetados, typecheck e validação documental.
- **Definition of Done:** código e regressão verdes, documentação reconciliada e resultados dos gates registrados sem ocultar falhas.

## Execution

| Atividade | Status |
| --- | --- |
| Materializar requisito e readiness | Concluída |
| Implementar decisão de visibilidade | Concluída |
| Executar Quality Gate | Concluída: 9/9 testes; lint sem erros; typecheck PASS |
| Reconciliar evidências | Concluída; gate documental agregado bloqueado por três artefatos concorrentes fora do escopo sem índice |

## Evidências do Quality Gate

- `vitest`: `9/9 PASS` no helper de acesso e na resolução de papéis efetivos.
- `eslint` focalizado: `0` erros; três warnings preexistentes em `fiscal/page.tsx`.
- `typecheck`: `PASS`.
- `validate-docs.sh`: o contrato e a indexação deste REQ/TP passaram; o agregado
  encerrou com `23/24` por `ANL-00052`, `LL-BE-00100` e `IP-BE-13.3.4-chatbot-quota-atomic-admission`, arquivos
  concorrentes fora deste escopo que ainda não possuem link no índice imediato.
