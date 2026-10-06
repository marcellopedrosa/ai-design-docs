---
document_id: PRD-00006
primary_nature: Requisito
objective: Validar o recorte de produto da administração segura da política de retenção da Auditoria de Conversas por Super Admin personificado.
scope: Leitura e configuração tenant-scoped da política na aba de retenção de /audit, períodos independentes de 1 a 180 dias, ativação opcional, preview de impacto e execução assíncrona fail-closed.
non_objectives: Validar toda a experiência Omnichannel ou IAM, conceder acesso a Tenant Admin ou ROLE_TENANT_AUDIT, definir acceptance criteria, executar purge síncrono, autori
ar produção ou operar backup externo.
owner: Produto da Auditoria, Segurança e Compliance
status: Validated
version: 1.9
date: 2026-09-10
last_reviewed: 2026-09-12
keywords: prd, auditoria, conversas, retenção, super-admin, personificação, 180-dias
related_files: docs/product/requirements/README.md, projects/backend/docs/prds/PRD-00002-omnichannel-experience.md, projects/backend/docs/prds/PRD-00005-identity-access-governance.md, docs/product/requirements/REQ-00003-rbac-profile-responsibility-matrix.md, docs/product/requirements/REQ-00004-rbac-security-mapping.md, docs/product/requirements/REQ-00041-chatbot-conversation-audit.md, docs/product/requirements/REQ-00043-conversation-audit-data-governance.md, docs/product/use-cases/UC-00035-chatbot-conversation-audit.md, docs/delivery/plans/implementation_plans/backend/IP-BE-8.1.11-conversation-audit-retention-bounded-preview-counts.md, docs/delivery/plans/implementation_plans/backend/IP-BE-8.1.12-conversation-audit-retention-capacity-reconciliation.md
code_references: N/A - PRD de produto; requisitos, contrato OpenAPI e planos mantêm as referências executáveis.
principal_statement: O Super Admin personificado deve administrar a retenção do tenant com limites claros e confirmação de impacto, sem ampliar o acesso do Tenant Admin ou provocar exclusão síncrona.
---

# PRD-00006 — Administração da retenção da Auditoria de Conversas

## 1. Executive summary

A auditoria de conversas precisa de uma política por tenant que seja compreensível,
limitada e administrável pela autoridade responsável. O recorte é independente da
validação ampla da experiência Omnichannel e de IAM: seu público é o Super Admin em
personificação ativa, seu resultado é a governança segura do ciclo de vida dos dados
e seu risco central é excluir dados ou ampliar privilégios indevidamente.

O solicitante humano aprovou explicitamente, em 2026-09-10, a criação e validação
da v1.1 deste PRD com Super Admin personificado, prazo de `1..180` dias e Phase A
em dry-run/purge desligado. REQ-00041, REQ-00043, REQ-00003, REQ-00004 e UC-00035
já contêm o comportamento e o aceite aprovados. Em 2026-09-11, o owner determinou
o expurgo das métricas baseadas em tempo, telemetria, qualidade ou quantidade e,
depois de revisar as pendências, aprovou todas as features, regras de negócio e a
cobertura canônica específica de aceite, inclusive por Segurança e Compliance. A
v1.3 está `Validated` somente para esse recorte.

## Problema e evidência

### Problem statement

Sem uma política tenant-scoped acessível e durável, o responsável não consegue
conhecer ou configurar por quanto tempo conversas e eventos de acesso são mantidos.
Uma solução improvisada também pode expor o controle ao perfil errado, aceitar
prazos excessivos ou acionar exclusão sem confirmação e sem guardas operacionais.

### Evidence currently available

| Evidence | What it supports | Limitation |
| --- | --- | --- |
| [REQ-00041](../requirements/REQ-00041-chatbot-conversation-audit.md) | A aba separada e o ator Super Admin personificado foram aprovados. | Não comprova operação ambiental. |
| [REQ-00043](../requirements/REQ-00043-conversation-audit-data-governance.md) | Define teto de 180 dias, toggle, preview, política durável e expurgo assíncrono. | Backup real e promoção permanecem fora deste PRD. |
| [UC-00035](../use-cases/UC-00035-chatbot-conversation-audit.md) | Fluxos e exceções do ator estão aprovados. | Não substitui evidência backend-real. |
| [IP-BE-8.1.6-conversation-audit-retention-policy-administration-api](../../delivery/plans/implementation_plans/backend/IP-BE-8.1.6-conversation-audit-retention-policy-administration-api.md) e testes backend versionados | GET, bootstrap durável `insert-only`, projeção sanitizada, CORS e boundary Super Admin personificado estão implementados e testados no repositório/DEV. | Não comprova HML, produção nem habilitação destrutiva. |
| [IP-BE-8.1.7-conversation-audit-retention-preview-save](../../delivery/plans/implementation_plans/backend/IP-BE-8.1.7-conversation-audit-retention-preview-save.md) e [IP-FE-8.2.3-conversation-audit-retention-policy-tab](../../delivery/plans/implementation_plans/frontend/IP-FE-8.2.3-conversation-audit-retention-policy-tab.md) | Rotas baseline de preview/PUT, consumidor, formulário, confirmação, mocks e E2E local estão implementados e testados. | Os stores, budgets, contagens e commits distribuídos do plano backend amplo ainda não estão materializados. |
| [IP-BE-8.1.8-conversation-audit-retention-phase-a-preflight-and-schema](../../delivery/plans/implementation_plans/backend/IP-BE-8.1.8-conversation-audit-retention-phase-a-preflight-and-schema.md) | O preflight, marker A e V91 estão materializados e passaram pelos gates repository-local/focados sem skip. | O PR/global agregado permanece no loop; V92 é Phase B posterior. |
| [IP-BE-8.1.9-conversation-audit-retention-phase-a-normalization](../../delivery/plans/implementation_plans/backend/IP-BE-8.1.9-conversation-audit-retention-phase-a-normalization.md) | `BE-RET-004` materializou normalizador, VERIFY, barreira Redis, `COMPLETE` e fence preview/PUT; focal/QG `56/56`, impactada `99/99`, arquitetura `29/29` e packaging regression EPP `29/29` + PackagingIT `3/3` passaram sem skip. | PR/global, V92, purge e ambientes externos estão fora do handoff. |
| [IP-BE-8.1.11-conversation-audit-retention-bounded-preview-counts](../../delivery/plans/implementation_plans/backend/IP-BE-8.1.11-conversation-audit-retention-bounded-preview-counts.md) | `BE-RET-005A2` materializou snapshot PostgreSQL e counts bounded reais; focal `24/24`, impactada `15/15`, arquitetura `29/29` e QG canônico `68/68` passaram zero-skip em PostgreSQL `16.14`, com revisão `PASS`. | Token continua transitório; não comprova admission, cleanup, idempotência ou capability positiva. |
| [IP-BE-8.1.12-conversation-audit-retention-capacity-reconciliation v1.2](../../delivery/plans/implementation_plans/backend/IP-BE-8.1.12-conversation-audit-retention-capacity-reconciliation.md) | `BE-RET-009A` materializou a reconciliação commit-safe dos quatro stores; focal `11/11`, PostgreSQL `12/12`, impactada `18/18`, arquitetura `29/29` e QG canônico `70/70` passaram zero-skip em PostgreSQL `16.14`. | Sem crédito por writer, N/N+1, admission/deltas, cleanup ou readiness positiva; quatro gauges permanecem em `0`. |
| Aprovação humana explícita de 2026-09-10, materializada na v1.1 | Aprova o recorte, público, limites e estratégia segura de Phase A. | Não autoriza produção, dados reais ou purge ativo. |
| Aprovação humana explícita de 2026-09-11, materializada na v1.3 | Reconfirma todas as features e regras de negócio, aprova a cobertura específica de aceite e representa Segurança e Compliance após o expurgo das métricas. | Permanece limitada ao escopo deste PRD e não autoriza operação ambiental ou destrutiva. |

## Público e contexto

| Audience | Need / job | Expected value |
| --- | --- | --- |
| Super Admin em personificação ativa | Consultar e configurar a política do tenant alvo. | Governança consistente sem acesso direto ao banco ou comando manual. |
| Segurança e Compliance | Impedir configuração pelo perfil errado e preservar evidência. | Menor risco de privilégio indevido e mudança não auditável. |
| Escritório personificado | Ter uma política explícita e limitada para seus dados auditáveis. | Previsibilidade do ciclo de vida sem exclusão imediata pela tela. |

## Outcomes e não-objetivos

> Outcomes quantitativos de tempo, qualidade, cobertura e garantia não são aplicáveis ao escopo MVP.


1. Tornar a política efetiva legível e configurável na aba de retenção de `/audit`
   somente pelo Super Admin personificado.
2. Impedir valores fora de `1..180` dias e impedir divergência entre os toggles
   internos expostos como uma única decisão pública.
3. Exigir preview/confirmacão para habilitação ou redução de prazo e manter toda
   exclusão fora da requisição HTTP.
4. Preservar comportamento fail-closed quando policy, dependência ou guarda
   operacional não estiver pronta.

### Non-goals

- Validar as iniciativas completas Omnichannel e IAM.
- Dar acesso à política para Tenant Admin ou `ROLE_TENANT_AUDIT`.
- Prometer data de início ou conclusão do expurgo.
- Ativar purge, remover legal hold, declarar backup pronto ou acessar dados reais.
- Redefinir contratos, fluxos ou critérios já mantidos nas fontes funcionais.

## 5. Product scope and limits

### In scope

- aba de retenção visível somente ao Super Admin sob personificação ativa;
- leitura da policy efetiva e estado sanitizado de execução;
- períodos de conversas e eventos de acesso entre 1 e 180 dias;
- ativação/desativação única, preview de impacto e confirmação vinculada;
- persistência durável, auditoria e processamento assíncrono sob guardas.
- inicialização não destrutiva e `insert-only` de um default desativado, por
  controle separado da master flag, para que a leitura da policy não dependa da
  habilitação do motor de expurgo.

### Out of scope for this validation cycle

- acesso por Tenant Admin, auditor ou identidade Super Admin sem personificação;
- exportação, consulta do conteúdo ou alteração da auditoria read-only;
- HML, PRD, canary, produção, dados reais e backup/restore externo;
- purge síncrono ou habilitação destrutiva durante a Phase A.

## 6. Product validation criteria

Este PRD está `Validated` porque o owner humano reconfirmou as quatro features, as
regras de negócio descritas no recorte aprovado e a cobertura específica pelos
acceptance criteria canônicos dos requisitos relacionados. As fontes funcionais
aplicáveis permanecem aprovadas, as hipóteses estão encerradas e não há decisão
aberta. Qualquer ampliação de ator, prazo, ambiente ou efeito destrutivo exige nova
decisão explícita e reabre o documento.

zados. Evidências exigidas pelos acceptance criteria continuam em
suas fontes canônicas e não constituem métricas de sucesso deste PRD.

## Métricas

Não aplicável ao escopo MVP; métricas de tempo, qualidade, cobertura e garantia ficam fora desta fase.

## Product Hypotheses

| ID | Hypothesis | Validation method | Evidence | Owner | State |
| --- | --- | --- | --- | --- | --- |
| `H-AUDRET-001` | O responsável precisa administrar retenção por tenant sem comando de banco. | Revisão do requisito e aprovação explícita do owner. | REQ-00041/REQ-00043 aprovados e confirmação humana em 2026-09-10. | Produto da Auditoria | Validated |
| `H-AUDRET-002` | Restringir a aba ao Super Admin personificado preserva a separação entre leitura e administração. | Revisão RBAC e aprovação explícita do recorte. | REQ-00003/REQ-00004/UC-00035 e confirmação humana em 2026-09-10. | Segurança | Validated |
| `H-AUDRET-003` | Preview e expurgo assíncrono reduzem o risco de uma alteração destrutiva acidental. | Revisão das guardas e decisão do owner. | REQ-00043 e aprovação da Phase A dry-run/purge off em 2026-09-10. | Compliance | Validated |

## Features e mapa de requirements

| Requirement | Contribution | Current documentary state |
| --- | --- | --- |
| [REQ-00003](../requirements/REQ-00003-rbac-profile-responsibility-matrix.md) | Responsabilidade exclusiva do Super Admin personificado. | Implemented baseline. |
| [REQ-00004](../requirements/REQ-00004-rbac-security-mapping.md) | Enforcement coerente entre frontend e backend. | Approved. |
| [REQ-00041](../requirements/REQ-00041-chatbot-conversation-audit.md) | Experiência da aba e separação da consulta read-only. | Approved. |
| [REQ-00043](../requirements/REQ-00043-conversation-audit-data-governance.md) | Política durável, limites, preview, guardas e expurgo. | Approved. |

Os acceptance criteria permanecem exclusivamente nos requisitos.

### 9.1 Feature inventory and acceptance coverage

| Feature ID | Product feature / audience outcome | Requirements | Canonical acceptance coverage | Documentary state |
| --- | --- | --- | --- | --- |
| `F-01` | Consultar policy efetiva e estado sanitizado do tenant personificado. | [REQ-00041](../requirements/REQ-00041-chatbot-conversation-audit.md), [REQ-00043](../requirements/REQ-00043-conversation-audit-data-governance.md) | [REQ-00041 AC-AUD-064 e AC-AUD-066](../requirements/REQ-00041-chatbot-conversation-audit.md#12-acceptance-criteria); [REQ-00043 AC-AUD-GOV-057 e AC-AUD-GOV-062](../requirements/REQ-00043-conversation-audit-data-governance.md#15-acceptance-criteria) | Implemented and tested — repository-local/DEV; sem pendência local. |
| `F-02` | Configurar `1..180` dias e ativação mediante preview/confirmacão. | [REQ-00041](../requirements/REQ-00041-chatbot-conversation-audit.md), [REQ-00043](../requirements/REQ-00043-conversation-audit-data-governance.md) | [REQ-00041 AC-AUD-065 e AC-AUD-067–AC-AUD-069](../requirements/REQ-00041-chatbot-conversation-audit.md#12-acceptance-criteria); [REQ-00043 AC-AUD-GOV-056, AC-AUD-GOV-058–AC-AUD-GOV-059 e AC-AUD-GOV-066](../requirements/REQ-00043-conversation-audit-data-governance.md#15-acceptance-criteria) | Partial — UI, baseline HTTP, clock/snapshot PostgreSQL, counts bounded e reconciliação física dos quatro stores testados; faltam token/digest e idempotência duráveis, budgets, admission/deltas/cleanup e commit transacional. |
| `F-03` | Impedir acesso de Tenant Admin/auditor e exigir personificação coerente. | [REQ-00003](../requirements/REQ-00003-rbac-profile-responsibility-matrix.md), [REQ-00004](../requirements/REQ-00004-rbac-security-mapping.md), [REQ-00041](../requirements/REQ-00041-chatbot-conversation-audit.md), [REQ-00043](../requirements/REQ-00043-conversation-audit-data-governance.md) | [REQ-00003 AC-008 e AC-012–AC-014](../requirements/REQ-00003-rbac-profile-responsibility-matrix.md#8-acceptance-criteria); [REQ-00004 AC-010, AC-018–AC-019 e AC-021](../requirements/REQ-00004-rbac-security-mapping.md#8-acceptance-criteria); [REQ-00041 AC-AUD-064 e AC-AUD-072](../requirements/REQ-00041-chatbot-conversation-audit.md#12-acceptance-criteria); [REQ-00043 AC-AUD-GOV-057](../requirements/REQ-00043-conversation-audit-data-governance.md#15-acceptance-criteria) | Implemented and tested — repository-local/DEV; sem pendência local. |
| `F-04` | Aplicar mudança sem delete HTTP e processar expurgo apenas de forma assíncrona e guardada. | [REQ-00041](../requirements/REQ-00041-chatbot-conversation-audit.md), [REQ-00043](../requirements/REQ-00043-conversation-audit-data-governance.md) | [REQ-00041 AC-AUD-067 e AC-AUD-070–AC-AUD-073](../requirements/REQ-00041-chatbot-conversation-audit.md#12-acceptance-criteria); [REQ-00043 AC-AUD-GOV-060–AC-AUD-GOV-064](../requirements/REQ-00043-conversation-audit-data-governance.md#15-acceptance-criteria) | Partial — zero delete HTTP, motor assíncrono guardado, V91 e normalizador+barreira estão testados; faltam somente fila due/coalescing e a Phase B/V92 posterior. |

## 10. Use cases and decisions by reference

- [UC-00035](../use-cases/UC-00035-chatbot-conversation-audit.md): ator,
  precondições, fluxo de consulta/configuração e exceções.
- ADRs aplicáveis são selecionados pelo [índice](../../adrs/README.md); este PRD não
  redefine arquitetura, persistência, protocolo ou estratégia de rollout.

## 11. Current phase assessment

| Dimension | Observed state | Product implication |
| --- | --- | --- |
| Product definition | Recorte, público, valor, limites, features, regras de negócio e cobertura específica de aceite foram aprovados para a v1.3 em 2026-09-11. | Product Definition Gate fechado somente para esta iniciativa e versão. |
| Functional definition | [REQ-00003](../requirements/REQ-00003-rbac-profile-responsibility-matrix.md), [REQ-00004](../requirements/REQ-00004-rbac-security-mapping.md), [REQ-00041 v1.74](../requirements/REQ-00041-chatbot-conversation-audit.md), [REQ-00043 v1.33](../requirements/REQ-00043-conversation-audit-data-governance.md) e [UC-00035 v1.54](../use-cases/UC-00035-chatbot-conversation-audit.md) estão aprovados. | Não há lacuna funcional conhecida; novo handoff deve reexecutar readiness com a v1.9. |
| Repository implementation | `F-AUDRET-001` e `F-AUDRET-003` estão implementadas e testadas; frontend, GET, bootstrap, CORS, rotas baseline, BE-RET-004, A2 snapshot/counts e 009A capacity reconciliation existem. `F-AUDRET-002` e `F-AUDRET-004` continuam parciais somente nos hardenings duráveis descritos na matriz. | Existem duas pendências funcionais: F-AUDRET-002 em token/idempotência/budgets/admission/deltas/cleanup; F-AUDRET-004 somente em due/coalescing e Phase B/V92. 009A está concluído local/focado sem crédito de capability positiva; 009B deve permanecer capacity-first antes de introduzir writers. |
| DEV operation | Evidências versionadas registram backend saudável, policy default desativada, rotas fora de 404/503 causal e gates focais verdes. | Pela premissa aprovada, implementação testada em DEV não é pendência; isso não liga purge nem qualifica ambiente externo. |
| External operation | Não avaliada nem autorizada. | HML/PRD/canary/release permanecem gates separados. |

## 12. Dependencies and product risks

| Item | Impact | Owner |
| --- | --- | --- |
| Promoção Phase B (`V92`) | V91 e o normalizador+barreira já existem e estão testados no recorte focal; a promoção posterior continua necessária antes de autorizar ativação segura sobre legado. | Backend e Dados |
| RBAC original antes do contexto efetivo | Ordem incorreta pode conceder administração ao Tenant Admin. | Segurança |
| Preview e idempotência | Ausência pode permitir confirmação ambígua ou mutation duplicada. | Backend e Segurança |
| Guardas de purge e backup | Ativação prematura pode apagar dados sem readiness operacional. | Compliance e DevOps |

## Assumptions e Open Questions

| ID | Question / decision needed | Decision owner | State |
| --- | --- | --- | --- |
| `OQ-AUDRET-001` | Quem pode acessar a aba? Resposta: somente autoridade bruta `ROLE_SUPER_ADMIN` sob personificação ativa e coerente. | Produto e Segurança | Resolved — [REQ-00041](../requirements/REQ-00041-chatbot-conversation-audit.md), [REQ-00043](../requirements/REQ-00043-conversation-audit-data-governance.md) e aprovação humana de 2026-09-10. |
| `OQ-AUDRET-002` | Qual faixa e estado inicial seguro? Resposta: `1..180`; Phase A em dry-run, master e ambos os purges off. Uma flag independente pode apenas inserir o default desativado quando ausente, sem atualizá-lo. | Produto, Segurança e Compliance | Resolved — [REQ-00043](../requirements/REQ-00043-conversation-audit-data-governance.md) e aprovação humana de 2026-09-10. |
| `OQ-AUDRET-003` | A alteração pode apagar dados na requisição? Resposta: não; processamento somente assíncrono sob guardas. | Compliance | Resolved — [REQ-00043](../requirements/REQ-00043-conversation-audit-data-governance.md) e aprovação humana de 2026-09-10. |

Não há nova dúvida de produto. Em 2026-09-11, o owner reconfirmou integralmente o
conjunto de features e regras de negócio e aprovou a cobertura específica de
aceite após o expurgo das métricas, inclusive por Segurança e Compliance.

## Approval

| Role | Accountable party | Decision | Date | Evidence |
| --- | --- | --- | --- | --- |
| Owner — v1.1 histórica | Solicitante humano atuando como owner de Produto da Auditoria | Validated para o recorte explícito da v1.1. | 2026-09-10 | Aprovação explícita “Sim! Aprovado!” após apresentação do escopo completo. |
| Owner — v1.3 | Solicitante humano atuando como owner de Produto da Auditoria | Validated — todas as features, regras de negócio e a cobertura específica de aceite foram aprovadas após o expurgo das métricas. | 2026-09-11 | Aprovação explícita: “Aprovo todas as decisões e a cobertura proposta, inclusive por Segurança e Compliance.” |
| Required reviewer — v1.3 | Segurança e Compliance, representados na aprovação humana explícita | Validated — guardas, negativas de acesso, ausência de delete síncrono e cobertura de aceite reconfirmadas. | 2026-09-11 | A mesma aprovação explícita declara representação de Segurança e Compliance; REQ-00003, REQ-00004, REQ-00041 e REQ-00043 permanecem as fontes canônicas. |

## Product Definition Gate

**Product Definition Gate:** `PASS` para `PRD-00006 v1.9` e somente para a
administração de retenção descrita neste documento. A correção técnica da ordem de
commit não altera a decisão de produto aprovada na v1.3; PRD-00002 e PRD-00005
continuam independentes deste recorte.

## 15. Change log

| Version | Date | Changes |
| --- | --- | --- |
| `1.9` | `2026-09-12` | Reconcilia BE-RET-009A como materializado/testado no IP-BE-8.1.12-conversation-audit-retention-capacity-reconciliation v1.2: focal `11/11`, PostgreSQL `12/12`, impactada `18/18`, arquitetura `29/29` e QG canônico `70/70`, zero-skip em PostgreSQL `16.14`. Preserva writers, N/N+1, admission/deltas, cleanup, due e as quatro capabilities positivas sem crédito. |
| `1.8` | `2026-09-12` | Revoga o READY 009A v1.0 e referencia o fresh READY v1.1 nos mesmos 11 paths: identidade não ordena commits, portanto nova passagem usa capacity-first + fence `SHARE` + watermark na mesma transação e timeout com rollback integral. Confirma zero writers runtime atuais e obriga 009B capacity→entry antes de introduzi-los. Não altera o escopo de produto validado nem dá crédito de implementação, migration, cleanup ou capability positiva. |
| `1.7` | `2026-09-12` | Reconcilia BE-RET-005A2 como materializado/testado no IP-BE-8.1.11-conversation-audit-retention-bounded-preview-counts v1.1 (`24/24`, `15/15`, `29/29`, QG canônico `68/68`, zero-skip, PostgreSQL `16.14`, revisão `PASS`) e registra IP-BE-8.1.12-conversation-audit-retention-capacity-reconciliation/BE-RET-009A apenas como IRG READY. Preserva N/N+1, cleanup, capability positiva e due sem crédito. |
| `1.6` | `2026-09-12` | Reconcilia BE-RET-004 como materializado e testado no recorte repository-local/focado: focal e Quality Gate focused `56/56`, impactada `99/99`, arquitetura `29/29` e packaging regression EPP `29/29` + PackagingIT `3/3`, todos sem skip. F-AUDRET-004 permanece parcial somente por fila due/coalescing e Phase B/V92; PR/global, purge e externalidades não foram promovidos. |
| `1.5` | `2026-09-12` | Reconcilia a evidência de BE-RET-003: preflight, marker A e V91 estão materializados/testados; distingue a exceção bootstrap insert-only segura do bootstrap regular e liga BE-RET-004 ao plano READY de normalizador+barreira. F-AUDRET-004 permanece parcial também por fila due/coalescing e Phase B/V92 futura. |
| `1.4` | `2026-09-12` | Reconcilia o estado evidence-first: `F-AUDRET-001/003` implementadas e testadas no repositório/DEV; `F-AUDRET-002/004` parciais somente nos hardenings duráveis; remove GET parcial/503 do estado corrente e registra `V91/V92` como IDs livres planejados. |
| `1.3` | `2026-09-11` | Registra a aprovação humana de todas as features e regras de negócio, inclusive por Segurança e Compliance; substitui faixas genéricas pela cobertura específica de aceite e promove o PRD a `Validated`. |
| `1.2` | `2026-09-11` | Expurga `M-AUDRET-001`–`M-AUDRET-004` e qualquer dependência de tempo, telemetria, qualidade ou medição quantitativa; reabre a validação somente para reconfirmar features, regras de negócio e cobertura canônica de aceite. |
| `1.1` | `2026-09-10` | Separa a inicialização legível da policy da master destrutiva: autoriza somente default desativado `insert-only`, com master/purges off, legal hold e dry-run ativos, para corrigir o 503 sem habilitar exclusão. |
| `1.0` | `2026-09-10` | Valida o recorte de administração de retenção por Super Admin personificado. |
