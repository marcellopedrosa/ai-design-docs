---
document_id: "ADR-0026"
primary_nature: "Decisao"
objective: "Definir os namespaces canonicos das APIs de Billing e a estrategia de cutover entre frontend e backend sem ambiguidade de tenant ou dependencia de MSW em runtime."
scope: "Rotas HTTP tenant-scoped e administrativas de Billing, autorizacao por contexto efetivo, compatibilidade pre-producao, consumo frontend e limite contratual de MRR."
non_objectives: "Implementar ou habilitar endpoints; definir schemas completos de DTOs; redefinir a formula `MRR_V1` aceita no ADR-0049; alterar pricing, cobranca ASAAS, fiscal ou dados persistidos."
owner: "Arquitetura / Billing; Codex (IA) como editor da reconciliacao de `D-12`"
status: "Accepted"
date: "2026-08-25"
version: "2.2"
last_reviewed: "2026-09-04"
keywords: "billing API, tenant scope, admin scope, BOLA, MRR, MSW, cutover, compatibility, frontend, backend"
related_files: "docs/product/requirements/REQ-00042-enterprise-multitenant-billing-invoicing.md`, `docs/delivery/plans/TP-00011-billing-asaas-first-release-task-plan.md`, `docs/delivery/plans/TP-00013-enterprise-billing-implementation-task-plan.md`, `docs/adrs/ADR-0019-database-per-tenant.md`, `docs/adrs/ADR-0023-agnostic-payment-provider-integration.md`, `docs/adrs/ADR-0049-subledger-tenant-local-mrr-normalizado.md"
code_references: "`backend/src/main/java/br/com/duoset/saas_service/contexts/billing/internal/presentation/rest/BillingController.java`, `frontend/src/services/billingService.ts`, `frontend/src/hooks/queries/useBillingQueries.ts`, `frontend/src/mocks/handlers/billingHandlers.ts`; contratos OpenAPI/DTO exatos permanecem destinos planejados."
principal_statement: "Billing separa APIs tenant-scoped em `/api/v1/tenants/{tenantId}/billing/**` e APIs globais em `/api/v1/admin/billing/**`, sem aliases `/api/v1/billing/**` e sem MSW como fallback de runtime; `MRR_V1` gerencial esta definido no ADR-0049, mas sua habilitação permanece indisponível até contrato/runtime/reconciliação/autorização/evidência, embora artefatos locais possam ser implementados sob `D-00`."
---

# ADR-0026 - Escopo tenant/admin e cutover das APIs de Billing

- Document ID: `ADR-0026`
- Primary Nature: `Decisao`
- Objective: Definir os namespaces canonicos das APIs de Billing e a estrategia de cutover entre frontend e backend sem ambiguidade de tenant ou dependencia de MSW em runtime.
- Scope: Rotas HTTP tenant-scoped e administrativas de Billing, autorizacao por contexto efetivo, compatibilidade pre-producao, consumo frontend e limite contratual de MRR.
- Non-objectives: Implementar ou habilitar endpoints; definir schemas completos de DTOs; redefinir a formula `MRR_V1` aceita no ADR-0049; alterar pricing, cobranca ASAAS, fiscal ou dados persistidos.
- Keywords: billing API, tenant scope, admin scope, BOLA, MRR, MSW, cutover, compatibility, frontend, backend
- Related Files: `docs/product/requirements/REQ-00042-enterprise-multitenant-billing-invoicing.md`, `docs/delivery/plans/TP-00011-billing-asaas-first-release-task-plan.md`, `docs/delivery/plans/TP-00013-enterprise-billing-implementation-task-plan.md`, `docs/adrs/ADR-0019-database-per-tenant.md`, `docs/adrs/ADR-0023-agnostic-payment-provider-integration.md`, `docs/adrs/ADR-0049-subledger-tenant-local-mrr-normalizado.md`
- Code References: `backend/src/main/java/br/com/duoset/saas_service/contexts/billing/internal/presentation/rest/BillingController.java`, `frontend/src/services/billingService.ts`, `frontend/src/hooks/queries/useBillingQueries.ts`, `frontend/src/mocks/handlers/billingHandlers.ts`; contratos OpenAPI/DTO exatos permanecem destinos planejados.
- Principal Decision: Billing separa APIs tenant-scoped em `/api/v1/tenants/{tenantId}/billing/**` e APIs globais em `/api/v1/admin/billing/**`, sem aliases `/api/v1/billing/**` e sem MSW como fallback de runtime; `MRR_V1` gerencial esta definido no ADR-0049, mas sua habilitação permanece indisponível até contrato/runtime/reconciliação/autorização/evidência, embora artefatos locais possam ser implementados sob `D-00`.
- Date: 2026-08-25
- Status: Accepted
- Version: 2.2
- Decision Provenance: `HUMAN_EXPLICIT` para `D-01`; a dependencia consumida `D-12` e `AI_DELEGATED`
- Authority Basis for D-12: `OWNER_DELEGATION — AUTH-BILLING-2026-08-25-001`
- Human Review Status for D-12: `NOT_PERFORMED`
- Reviewability for D-12: `OPEN`
- Authors / Owners: Arquitetura / Billing; Codex (IA) como editor da reconciliacao de `D-12`
- Reviewers: Responsavel pelo produto, com aprovacao explicita humana de `D-01` em 2026-08-23; Arquitetura; nenhuma revisao humana substantiva de `D-12`
- Stakeholders: Produto, Backend, Frontend, Seguranca, Financeiro e operadores da plataforma
- Supersedes: N/A
- Superseded by: N/A

---

# 0. Decision Provenance and Reconciliation

| Decision | Normative source | Provenance | Actor / authority | Human review | Reviewability |
| --- | --- | --- | --- | --- | --- |
| `D-01` | Este ADR | `HUMAN_EXPLICIT` | Responsavel pelo produto, aprovacao explicita em 2026-08-23 | `PERFORMED` para `D-01` | Alteracoes futuras exigem nova decisao governada. |
| `D-01.1` | Este ADR | `HUMAN_EXPLICIT` | Proprietário do SaaS, declaração explícita em 2026-09-04 | `PERFORMED` para acesso via personificação | Vigente e revisável; implementação materializada por IA. |
| `D-12` / `MRR_V1` | [ADR-0049](ADR-0049-subledger-tenant-local-mrr-normalizado.md) | `AI_DELEGATED` | `AI_AGENT — Codex (OpenAI)`, sob `OWNER_DELEGATION — AUTH-BILLING-2026-08-25-001` | `NOT_PERFORMED` | `OPEN`; revisao humana pode ratificar, emendar ou superseder, sem apagar a origem IA. |

Este ADR nao reatribui a decisao humana `D-01` e nao passa a ser a fonte normativa
da formula de MRR. Ele apenas reconcilia sua dependencia com `D-12`, aceita por IA
sob delegacao. O aceite de `MRR_V1` e documental/arquitetural: nao comprova API,
runtime, projector, reconciliacao, autorizacao, testes, capacidade ou readiness.
`D-00 = RELEASED_WITH_SCOPE — HUMAN_EXPLICIT — TP-00013 local-only` permite
código/contratos/testes herméticos locais e não autoriza habilitação ou efeito real.

---

# 1. Context

O backend de Billing ja declara o controller tenant-scoped sob
`/api/v1/tenants/{tenantId}/billing`, incluindo `subscription`, `usage` e
`invoices`. Parte do frontend, entretanto, ainda usa a base global
`/api/v1/billing`; handlers MSW reproduzem essas rotas divergentes. O resultado em
runtime real inclui `404` para `/api/v1/billing/subscription`,
`/api/v1/billing/usage` e `/api/v1/billing/mrr`.

Uma rota global sem distinguir operacao tenant-scoped de agregacao administrativa
tambem torna o ownership do tenant ambiguo e aumenta o risco de BOLA. O projeto
ainda nao entrou em producao e nao possui consumidor externo aprovado que exija
preservar os aliases divergentes.

O [ADR-0019](ADR-0019-database-per-tenant.md) exige roteamento seguro para o banco
do tenant, enquanto o [ADR-0023](ADR-0023-agnostic-payment-provider-integration.md)
mantem Billing como fonte de verdade local. O contrato HTTP precisa refletir essas
fronteiras sem permitir que mocks ou DTOs legados se tornem autoridade.

---

# 2. Decision Statement

O sistema DEVE usar namespaces distintos para operacoes tenant-scoped e globais:

1. operacoes pertencentes a um tenant usam
   `/api/v1/tenants/{tenantId}/billing/**`;
2. operacoes globais da plataforma usam `/api/v1/admin/billing/**`;
3. `/api/v1/billing/**` NAO possui alias de compatibilidade;
4. o `tenantId` do path DEVE corresponder ao tenant efetivo autenticado antes de
   qualquer repository, transacao ou roteamento de datasource;
5. operacoes globais exigem endpoint administrativo explicito e
   `ROLE_SUPER_ADMIN`; personificação explícita não é operação global e PODE
   acessar rota tenant-scoped quando `X-Tenant-ID` canônico coincide com o path,
   o tenant está ativo e o contexto/authority temporários são removidos ao fim;
6. MSW PODE apoiar testes isolados, mas NAO PODE responder, ocultar falha ou atuar
   como fallback no runtime integrado;
7. `D-12` esta aceita como `AI_DELEGATED` no ADR-0049 e define o indicador
   gerencial `MRR_V1`; a API de MRR permanece indisponivel ate que OpenAPI/DTOs,
   implementacao, projecao, reconciliacao, autorizacao, testes e evidencias sejam
   produzidos; artefatos locais podem avançar sob `D-00`;
8. o cutover futuro sera atomico entre contrato, backend, frontend e testes, sem
   dual routing.

Esta decisao de rotas foi aprovada como `D-01` pelo responsavel do produto em
2026-08-23, com provenance `HUMAN_EXPLICIT`. A reconciliacao de MRR consome
`D-12`, aceita posteriormente por Codex como `AI_DELEGATED` sob
`AUTH-BILLING-2026-08-25-001`, com revisao humana `NOT_PERFORMED` e
`Reviewability: OPEN`. A autorização humana separada registrou `D-00 =
RELEASED_WITH_SCOPE — HUMAN_EXPLICIT — TP-00013 local-only` no
[TP-00013](../delivery/plans/TP-00013-enterprise-billing-implementation-task-plan.md),
sem liberar chamadas externas, Sandbox, piloto ou produção.

Em 2026-09-04, o proprietário do SaaS aprovou `D-01.1` com provenance
`HUMAN_EXPLICIT`: Super Admin personificado também acessa Billing do tenant
selecionado. Isso não concede consulta global, wildcard ou header livre; path,
header e tenant ativo continuam validados server-side. A implementação atual
permanece limitada por `D-00` ao ambiente local; promoção para homologação ou
produção depende dos controles de propósito, duração, auditoria e segregação de
funções do ADR-0050.

---

# 3. Canonical Route Families

| Audience | Canonical family | Authorization boundary | Current decision |
| --- | --- | --- | --- |
| Tenant Billing | `/api/v1/tenants/{tenantId}/billing/subscription` | Tenant efetivo igual ao path; permissao tenant aplicavel | Canonica |
| Tenant Billing | `/api/v1/tenants/{tenantId}/billing/usage` | Tenant efetivo igual ao path; permissao tenant aplicavel | Canonica; resposta dummy nao satisfaz implementacao |
| Tenant Billing | `/api/v1/tenants/{tenantId}/billing/invoices` | Tenant efetivo igual ao path; permissao tenant aplicavel | Canonica |
| Tenant Billing | `/api/v1/tenants/{tenantId}/billing/**` | Tenant Admin direto ou Super Admin sob personificação explícita; header/path iguais e tenant ativo | Sufixos/DTOs exatos dependem do contrato do slice |
| Platform Billing | `/api/v1/admin/billing/subscriptions` | `ROLE_SUPER_ADMIN` | Familia reservada para contrato aprovado |
| Platform Billing | `/api/v1/admin/billing/subscriptions/{subscriptionId}` | `ROLE_SUPER_ADMIN` | Familia reservada para contrato aprovado |
| Platform Billing | `/api/v1/admin/billing/mrr` | Authority global especifica, purpose registrado e politica do ADR-0050; sem detalhe cross-tenant implicito | `MRR_V1` aceito no ADR-0049; rota reservada, ainda nao implementada/publicavel |
| Legacy divergent | `/api/v1/billing/**` | Ambigua | Nao suportada |

Reservar uma familia nao equivale a declarar que o endpoint existe. Cada rota so
pode ser publicada pelo requisito e plano do slice correspondente.

---

# 4. Decision Drivers

- isolamento e autorizacao multitenant fail-closed;
- eliminacao da causa dos `404` sem criar aliases inseguros;
- projeto pre-producao, sem custo justificado de dual routing;
- distincao entre dado do tenant e agregacao global autorizada;
- contrato backend/frontend unico e verificavel;
- proibicao de mock como prova de integracao real;
- necessidade de traduzir a semantica aceita de `MRR_V1` em contrato, runtime,
  reconciliacao e evidencias reproduziveis antes de publicar a rota.

---

# 5. Considered Options

## Option 1: Manter `/api/v1/billing/**` para todas as operacoes

**Rejected.** Reduz alteracao imediata no frontend, mas deixa ownership de tenant
implicito, mistura operacoes tenant e globais e perpetua o drift com o backend.

## Option 2: Criar aliases temporarios globais e tenant-scoped

**Rejected.** Poderia ajudar consumidores em producao, mas o projeto ainda nao
possui essa necessidade comprovada. Duplicaria autorizacao, testes, telemetria e
sunset e manteria o risco de um consumidor nunca migrar.

## Option 3: Separar tenant/admin e executar cutover atomico

**Accepted.** Torna a fronteira de seguranca explicita, segue as convencoes atuais
do repositorio e elimina compatibilidade sem valor em um produto pre-producao.

---

# 6. Consequences

## Positive Consequences

- Paths tornam tenant e audiencia administrativa explicitos.
- BOLA pode ser negada antes de repository e datasource routing.
- Frontend e backend passam a compartilhar um contrato verificavel.
- A ausencia de MRR deixa de ser mascarada por dado simulado.
- Nao surge uma segunda superficie HTTP para manter e aposentar.

## Negative Consequences

- Todos os consumidores internos divergentes deverao migrar no mesmo slice.
- Telas administrativas de MRR permanecem indisponiveis ate existirem contrato,
  runtime, projecao/reconciliacao e evidencias aceitas; `D-00` já permite os
  artefatos/testes herméticos locais, não a habilitação.
- Fixtures e testes baseados nas rotas antigas precisarao ser atualizados na futura implementacao.

## Neutral Consequences

- MSW continua permitido em teste unitario/componente explicitamente isolado.
- Esta decisao nao define DTO, paginacao ou regras financeiras de cada recurso.

---

# 7. Security and Compatibility Invariants

- O browser nao escolhe livremente tenant, role ou escopo administrativo.
- Tenant do path e tenant efetivo precisam coincidir antes de qualquer efeito.
- Super Admin usa APIs administrativas ou impersonacao explicita governada; nao
  recebe bypass silencioso numa rota de tenant.
- Respostas financeiras usam `Cache-Control: no-store` quando aplicavel.
- Listagens sao paginadas e limitadas; filtros e sorts usam allowlist.
- Erros seguem RFC 7807 e nao revelam existencia de recurso de outro tenant.
- Nenhum Service Worker/MSW responde ao caminho backend-real.

---

# 8. Impact

- **Backend:** consolidacao futura de controllers tenant-scoped e criacao separada
  de controllers administrativos quando os respectivos casos de uso existirem.
- **Frontend:** eliminacao futura da base global de Billing e passagem de tenant
  efetivo aos servicos tenant-scoped.
- **Security:** testes 401/403/BOLA e separacao `TENANT_ADMIN`/`SUPER_ADMIN` por familia.
- **Contracts:** OpenAPI, TypeScript, Zod e fixtures precisarao compartilhar sentinels de drift.
- **Operations:** telemetria futura deve confirmar que nenhum consumidor usa o
  namespace rejeitado antes de qualquer rollout.

---

# 9. Future Implementation Sequence

Esta sequencia e planejamento futuro, nao autorizacao de software:

1. consumir `D-01` a `D-14` como baseline decisoria fechada, preservando a
   provenance humana ou `AI_DELEGATED` registrada para cada item;
2. congelar OpenAPI e DTOs exatos do slice;
3. alterar backend, frontend, fixtures e testes no mesmo lote;
4. provar BOLA, RBAC, contrato e E2E backend-real sem MSW;
5. remover chamadas/handlers divergentes somente depois dos sentinels verdes;
6. manter MRR desabilitado ate implementar `MRR_V1`, projetar e reconciliar seus
   dados e provar autorização/isolamento; `D-00` cobre somente implementação local.

Rollback do cutover restaura a versao anterior da aplicacao como unidade; nao cria
aliases globais nem reescreve fatos financeiros.

---

# 10. Validation

- busca estatica nao encontra consumo runtime de `/api/v1/billing/**`;
- contrato lista separadamente familias tenant e admin;
- testes provam path/context match e mismatch antes do repository;
- `ROLE_TENANT_ADMIN` nao acessa agregacoes globais;
- `ROLE_SUPER_ADMIN` nao obtém dados tenant por bypass implícito; acesso exige personificação explícita e tenant único coincidente;
- E2E autenticado prova chamadas backend-real sem Service Worker/MSW;
- nenhuma rota MRR responde apenas em razao do aceite documental de `D-12`; sua
  publicacao exige OpenAPI/DTOs, runtime, projecao/reconciliacao, autorizacao e
  testes/evidencias; `D-00` já cobre somente a construção local;
- o validador documental confirma links, indice e metadados.

---

# 11. Risks and Mitigations

| Risk | Mitigation |
| --- | --- |
| Frontend voltar a usar base global | Contract sentinel e busca estatica no CI. |
| Path tenant divergir do contexto | Guard anterior ao repository e testes tenant A/path B. |
| Super Admin ganhar bypass excessivo | Namespace administrativo e permissao explicita por use case. |
| MSW esconder novo drift | E2E backend-real e proibicao de Service Worker no ensaio. |
| MRR incorreto ser tratado como receita | `MRR_V1` permanece gerencial; endpoint fica desabilitado até contrato/runtime/reconciliação/evidências, embora possa ser construído/testado localmente sob `D-00`. |
| Cutover parcial quebrar telas | Contrato congelado e mudanca backend/frontend/testes no mesmo slice. |

---

# 12. Related ADRs

- [ADR-0000 - Governanca documental](../../harness/governance/decisions/ADR-0000-governanca-do-harness-documental.md)
- [ADR-0012 - Error handling and observability](ADR-0012-error-handling-observability.md)
- [ADR-0013 - Frontend architecture](ADR-0013-frontend-architecture-state-management.md)
- [ADR-0019 - Database per tenant](ADR-0019-database-per-tenant.md)
- [ADR-0023 - Integracao agnostica de provedores de pagamento](ADR-0023-agnostic-payment-provider-integration.md)
- [ADR-0049 - Subledger tenant-local e MRR normalizado](ADR-0049-subledger-tenant-local-mrr-normalizado.md)
- [ADR-0050 - RBAC, SoD e aprovacoes](ADR-0050-rbac-sod-aprovacoes-financeiras.md)

---

# 13. Decision Lifecycle

Current State: **Accepted**

A aprovacao arquitetural humana de `D-01` e vigente. `D-12` tambem esta aceita,
mas com provenance `AI_DELEGATED`, revisao humana `NOT_PERFORMED` e revisao futura
`OPEN`, conforme ADR-0049. A definicao gerencial `MRR_V1` esta fechada; API,
runtime, projecao/reconciliacao, controles, testes e evidencias continuam
pendentes. `D-00` permite implementação hermética local e mantém habilitação `OFF`.

---

# 14. Change Log

| Version | Date | Author | Changes |
| --- | --- | --- | --- |
| 2.2 | 2026-09-04 | Proprietário do SaaS / Codex (IA), materialização | Registra `D-01.1 = HUMAN_EXPLICIT`: Super Admin personificado acessa Billing tenant-scoped somente com header/path coincidentes e tenant ativo; acesso global continua em namespace administrativo. |
| 2.1 | 2026-08-25 | Solicitante humano, proprietário declarado / Codex (IA), materialização | Registra `D-00 = RELEASED_WITH_SCOPE — HUMAN_EXPLICIT — TP-00013 local-only`; permite contrato/backend/frontend/testes herméticos locais sem MSW runtime e mantém chamadas externas, Sandbox ASAAS, piloto BP Farias, produção, flags `ON`, MRR habilitado e efeitos reais bloqueados. |
| 2.0 | 2026-08-25 | Codex (IA), sob `AUTH-BILLING-2026-08-25-001` | Reconcilia `D-12` como `AI_DELEGATED` aceita via ADR-0049, com `MRR_V1` gerencial fechado, revisao humana `NOT_PERFORMED`/`OPEN`, artefatos executaveis e evidencias ainda pendentes e `D-00` ativo; preserva `D-01` como decisao humana. |
| 1.0 | 2026-08-23 | Responsavel pelo produto / Arquitetura | Decisao `D-01` aceita: namespaces tenant/admin, ausencia de aliases globais, cutover atomico, MSW fora do runtime e MRR dependente de `D-12`. |

---

# 15. Repository Structure

```text
docs/
  adrs/
    ADR-0026-billing-api-tenant-admin-cutover.md
```

---

# 16. Notes

- A decisao nao declara endpoint planejado como implementado.
- Compatibilidade futura so pode ser reaberta por evidencia de consumidor real e
  decisao arquitetural que defina janela, telemetria, sunset e rollback.
- Termos `D-01` e `D-12` pertencem ao registro incremental do TP-00013. A
  dependencia historica registrada em `1.0` nao altera o estado corrente de
  `D-12`, aceito em 2026-08-25 no ADR-0049.
