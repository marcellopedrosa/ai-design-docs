---
document_id: TP-00055
primary_nature: Plano
objective: Promover e implementar o contrato RBAC da listagem administrativa de contatos comerciais.
scope: GET /api/v1/admin/commercial/contacts, contrato OpenAPI, matcher HTTP e testes de paridade/RBAC.
non_objectives: Não alterar detalhe, status, destinatários, configurações, payloads, persistência, IAM ou ambientes.
owner: Produto de Identidade, Segurança, Backend e Comercial
status: Completed — repository-local
version: 1.2
date: 2026-09-10
last_reviewed: 2026-09-10
keywords: commercial, contacts, api, openapi, rbac, role-commercial
related_files: ../../docs/prds/PRD-00007-commercial-contacts-operational-access.md, do../../product/requirements/REQ-00055-commercial-contact-capture-management.md, do../../product/use-cases/UC-00052-super-admin-commercial-contact-management.md, docs/contracts/commercial-contacts-v1.openapi.yaml, TP-00036-commercial-contact-integration.md
code_references: backend/src/main/java/br/com/duoset/saas_service/infrastructure/security/SecurityConfig.java, backend/src/main/java/br/com/duoset/saas_service/infrastructure/security/MultiRealmJwtConfig.java, backend/src/test/java/br/com/duoset/saas_service/infrastructure/security/SecurityConfigTest.java, backend/src/test/java/br/com/duoset/saas_service/infrastructure/security/MultiRealmJwtConfigTest.java
principal_statement: O READY autoriza corrigir listContacts para ROLE_COMMERCIAL/SUPER_ADMIN sem remover a validação global do token.
---

# TP-00055 — Contrato RBAC da listagem de contatos comerciais

## Task contract

**What:** tornar observável e testável que `ROLE_COMMERCIAL` e
`ROLE_SUPER_ADMIN` recebem `200` em `listContacts`, enquanto anônimo recebe `401`
e demais perfis recebem `403`.

**Where:** operação `listContacts` em contrato Active próprio ou promoção
governada, `SecurityConfig.authorizeHttpRequests` e testes HTTP/contratuais.

**Depends on:** [PRD-00007 v1.0](../../docs/prds/PRD-00007-commercial-contacts-operational-access.md)
Validated e [Commercial Contacts Active 1.0.0](../../contracts/commercial-contacts-v1.openapi.yaml),
operação `listContacts`.

**Reuses:** REQ-00055 AC-010/AC-044, UC-00052 passos 1–2, DTO/paginação atuais,
`KeycloakJwtRoleConverter` e testes MVC existentes.

**Requirements:** REQ-00055, UC-00052, API Client Standard 2.1, Backend Testing
Standard e ADR-0000. PRD aplicável: PRD-00007 v1.0.

## Gate Audit

| Controle | Evidência |
| --- | --- |
| Product Definition | `PASS`: PRD-00007 v1.0 está `Validated`, com M-COM-001 Defined, sem hipótese ou pergunta aberta. |
| Fontes superiores | REQ-00055 AC-010 e UC-00052 passos 1–2 estão coerentes com o PRD específico aprovado. |
| User Story View | Como operador Comercial, quero listar contatos cadastrados para acompanhar os leads; REQ-00055 AC-010/AC-044. |
| API Contract | `PASS`: Commercial Contacts v1 Active 1.0.0, `operationId: listContacts`, possui schemas, respostas, RBAC, boundary e compatibilidade aprovados. |
| Assumptions | Nenhuma; roles, issuer, ausência de tenant/personificação e respostas foram decisões humanas. |
| Open Questions | Nenhuma; COMMERCIAL-LISTCONTACTS-001/002 foram resolvidas e a operação saiu do Draft. |
| Dependências | Aprovação humana das Etapas 1–4 registrada em 2026-09-10. |
| Escopo | Uma operação GET e um resultado observável; detalhe/status permanecem fora. |
| Granularidade / Decomposição | Atômico; um contrato, um matcher e um handoff de listagem. |

## Acceptance Tests

| Critério | Evidência planejada |
| --- | --- |
| `ROLE_COMMERCIAL` global | MVC com JWT realista (`iss`, `azp`, audience e `realm_access.roles`) retorna `200`. |
| `ROLE_SUPER_ADMIN` global | Mesmo endpoint retorna `200`. |
| Outros perfis/anônimo | Retornam respectivamente `403`/`401` com erro documentado. |
| Paridade | Sentinel compara roles, método, path, parâmetros e respostas com o OpenAPI Active. |

## Prohibited

- Não promover o Draft por inferência nem marcar PRD como Validated sem os owners.
- Não liberar destinatários/configurações, wildcard de role, tenant ou personificação.
- Não alterar código enquanto este task estiver `Blocked`.

## Mandatory

- Resolver Product Definition e perguntas COMMERCIAL-LISTCONTACTS-001/002.
- Publicar contrato Active com `info.version`, `operationId: listContacts`, erros
  RFC 9457/compatibilidade e boundary completos.
- Reexecutar o IRG para os paths exatos antes de qualquer edição executável.

## READY — paths exatos autorizados

- `backend/src/main/java/br/com/duoset/saas_service/infrastructure/security/SecurityConfig.java`;
- `backend/src/main/java/br/com/duoset/saas_service/infrastructure/security/MultiRealmJwtConfig.java`;
- `backend/src/test/java/br/com/duoset/saas_service/infrastructure/security/SecurityConfigTest.java`;
- `backend/src/test/java/br/com/duoset/saas_service/infrastructure/security/MultiRealmJwtConfigTest.java`;
- este plano e suas fontes/indexadores documentais diretamente relacionados.

Decisão técnica limitada: a operação GET exata usará as authorities aprovadas no
matcher; o validador JWT central vinculará `ROLE_COMMERCIAL` ao realm `saas-admin`
e recusará claim tenant. As demais rotas comerciais preservam o boundary atual.

## Definition of Done

- PRD-00005 aplicável em `Validated` ou sucessor Validated explicitamente ligado.
- Contrato `listContacts` Active, indexado e referenciado nas fontes oficiais.
- IRG `READY`; testes focais, suíte impactada e Quality Gate com todos os targets em `PASS`.

## Result

`Completed — repository-local` em 2026-09-10. A documentação governada e a
cobertura OpenAPI passaram; o teste Maven e o Quality Gate focal executaram 54
testes com zero falha. O agregador documental continua acusando somente referências
abreviadas em planos concorrentes de Auditoria, fora deste escopo. Rebuild/smoke do
container em execução não foi realizado e permanece handoff local.

## Change Log

| Version | Date | Changes |
| --- | --- | --- |
| 1.2 | 2026-09-10 | Registra implementação local, 54/54 testes e Quality Gate focal em PASS. |
| 1.1 | 2026-09-10 | Registra aprovações, PRD Validated, contrato Active e IRG READY para paths exatos. |
| 1.0 | 2026-09-10 | Registra o IRG bloqueado antes da promoção do contrato e da alteração do backend. |
