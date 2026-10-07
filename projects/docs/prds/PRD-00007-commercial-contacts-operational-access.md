---
document_id: PRD-00007
primary_nature: Requisito
objective: Garantir que o operador Comercial consulte contatos sem ampliar acesso tenant ou administrativo.
scope: Listagem global por ROLE_COMMERCIAL e ROLE_SUPER_ADMIN.
non_objectives: Não definir detalhe, status, equipe, ingestão, arquitetura ou acceptance criteria.
owner: Produto Comercial e Segurança
status: Validated
version: 1.5
date: 2026-09-10
last_reviewed: 2026-09-11
keywords: comercial, contatos, listagem, rbac, acesso-global
related_files: docs/product/requirements/README.md, docs/product/requirements/REQ-00003-rbac-profile-responsibility-matrix.md, docs/product/requirements/REQ-00004-rbac-security-mapping.md, docs/product/requirements/REQ-00055-commercial-contact-capture-management.md, docs/product/use-cases/UC-00052-super-admin-commercial-contact-management.md, docs/api_contracts/commercial-contacts-v1.openapi.yaml, ../../../docs/specs/TP-00055-commercial-contacts-list-api-rbac-contract.md
code_references: N/A - PRD de produto; requisito, contrato e plano mantêm referências executáveis.
principal_statement: O time Comercial consulta os contatos comerciais globais com os limites aprovados para o perfil.
---

# PRD-00007 — Acesso operacional à listagem de contatos comerciais

## 1. Executive summary

O perfil Comercial recebe `403` ao consultar contatos, embora acompanhar leads
seja sua função aprovada. Este recorte valida a leitura global para Comercial e
Super Admin sem expandir acesso tenant ou administrativo.

## Problema e evidência

### Problem statement

O bloqueio impede o trabalho do time Comercial e indu
 o uso de perfil excessivo.

### Evidence currently available

| Evidence | What it supports | Limitation |
| --- | --- | --- |
| Reprodução e screenshot do solicitante em 2026-09-10 | GET retorna 403 para ROLE_COMMERCIAL. | Evidência local. |
| [REQ-00055 AC-010](../requirements/REQ-00055-commercial-contact-capture-management.md#7-acceptance-criteria) | Comercial e Super Admin são atores aprovados. | Não substitui contrato HTTP. |
| Aprovação humana desta versão | Confirma atores, boundary e compatibilidade. | Não aprova deploy. |

## Público e contexto

| Audience | Need / job | Expected value |
| --- | --- | --- |
| Operador Comercial | Consultar todos os contatos comerciais globais. | Atender contatos sem credencial excessiva. |
| Super Admin | Manter a consulta existente. | Continuidade sem regressão. |

## Outcomes e não-objetivos

> Outcomes quantitativos de tempo, qualidade, cobertura e garantia não são aplicáveis ao escopo MVP.


1. Restaurar a consulta para Comercial global.
2. Preservar Super Admin e as recusas dos demais perfis.
3. Manter a fronteira global sem tenant.

### Non-goals

- Alterar representação, filtros ou paginação.
- Autorizar outras rotas, detalhe ou mutação.
- Autorizar ambiente externo.

## 5. Product scope and limits

### In scope

- `ROLE_COMMERCIAL` e `ROLE_SUPER_ADMIN` no realm `saas-admin`;
- ausência de claim/header tenant e personificação;
- resultados positivos e negativos da listagem.

Todos os operadores comerciais autorizados consultam a mesma listagem global,
inclusive contatos acompanhados por outros operadores. Não existe segmentação por
vendedor, carteira, tenant ou ownership neste recorte.

Claim tenant, `X-Tenant-ID` ou personificação tornam o contexto inválido e
prevalecem como negação sobre `ROLE_COMMERCIAL` ou `ROLE_SUPER_ADMIN`. Esses
marcadores nunca são ignorados para transformar silenciosamente a requisição em
acesso global.

### Out of scope for this validation cycle

- equipe, configurações, detalhe, status, ingestão, HML e PRD.

## 6. Product validation criteria

Público, valor, feature, visibilidade global compartilhada, respostas, boundary,
compatibilidade e cobertura canônica de aceite foram aprovados pelos owners e
reviewers. Todas as hipóteses estão validadas, todas as perguntas estão resolvidas
e métricas de tempo, telemetria, qualidade técnica ou quantidade permanecem
expurgadas deste ciclo.

za um KPI de produto para uma fase futura, separada deste corretivo.

## Métricas

Não aplicável ao escopo MVP; métricas de tempo, qualidade, cobertura e garantia ficam fora desta fase.

## Product Hypotheses

| ID | Hypothesis | Validation method | Evidence | Owner | State |
| --- | --- | --- | --- | --- | --- |
| H-COM-001 | Comercial precisa listar leads sem usar Super Admin. | Revisão e decisão do owner. | REQ-00055, UC-00052 e aprovação de 2026-09-10. | Produto Comercial | Validated |

## Features e mapa de requirements

| Requirement | Contribution | Current documentary state |
| --- | --- | --- |
| [REQ-00003](../requirements/REQ-00003-rbac-profile-responsibility-matrix.md) | Matriz geral de perfis. | Implemented. |
| [REQ-00004](../requirements/REQ-00004-rbac-security-mapping.md) | Enforcement e negação padrão. | Approved. |
| [REQ-00055](../requirements/REQ-00055-commercial-contact-capture-management.md) | Operação de contatos pelo Comercial. | Implemented v3.4. |

Este PRD permanece independente com apenas o REQ-00055 como requisito principal
porque governa um corretivo atômico da feature `listContacts`; REQ-00003 e
REQ-00004 são fontes de suporte IAM. Criar outro requisito ou ampliar a iniciativa
seria artificial. A delimitação foi aprovada pelo owner em 2026-09-11.

### 9.1 Feature inventory and acceptance coverage

| Feature ID | Product feature / audience outcome | Requirements | Canonical acceptance coverage | Documentary state |
| --- | --- | --- | --- | --- |
| `F-01` | Comercial consulta a listagem global compartilhada de contatos, inclusive os acompanhados por outros operadores. | [REQ-00055](../requirements/REQ-00055-commercial-contact-capture-management.md) | [REQ-00055 AC-047–AC-048](../requirements/REQ-00055-commercial-contact-capture-management.md#7-acceptance-criteria) | Implemented repository-local; definição de produto validada. |

## 10. Use cases and decisions by reference

- [UC-00052](../use-cases/UC-00052-super-admin-commercial-contact-management.md): atores e objetivo da consulta.
- ADRs são selecionados pelo [índice](../../adrs/README.md); este PRD não redefine arquitetura.

## 11. Current phase assessment

| Dimension | Observed state | Product implication |
| --- | --- | --- |
| Product vision | Feature, visibilidade compartilhada, boundary e requisito principal único aprovados em 2026-09-11. | Gate de definição do produto fechado para `listContacts`. |
| Functional definition | REQ-00055 v3.4 possui aceite exclusivo para `listContacts`, visibilidade global e precedência fail-closed do boundary. | A cobertura canônica da feature está definida. |
| Repository implementation | O corretivo da operação está concluído repository-local. | Implementação não substitui a validação da definição do produto. |
| External operation | Não avaliada. | Deploy está fora do escopo. |
| Product evidence | Métricas de tempo, telemetria, qualidade técnica ou quantidade foram expurgadas do ciclo. | Features, regras de negócio e critérios de aceite permanecem como fontes de validação. |

## 12. Dependencies and product risks

| Item | Impact | Owner |
| --- | --- | --- |
| Validação JWT central | Deve preservar issuer global e ausência de tenant. | Segurança |
| Contrato Active | Evita ampliar a operação por interpretação. | Arquitetura |

## Assumptions e Open Questions

| ID | Question / decision needed | Decision owner | State |
| --- | --- | --- | --- |
| OQ-COM-001 | Atores: Comercial/Super Admin; demais negados. | Produto e Segurança | Resolved — aprovação de 2026-09-10. |
| OQ-COM-002 | Boundary: saas-admin sem tenant ou personificação. | Segurança | Resolved — aprovação de 2026-09-10. |
| OQ-COM-003 | Sem alteração de wire. | Produto e Backend | Resolved — aprovação de 2026-09-10. |
| OQ-COM-004 | A feature desta versão cobre exclusivamente a operação `GET listContacts`, mantendo UI, detalhe e mutação fora do recorte, e o REQ-00055 deve receber um critério de aceite estável e exclusivo para essa operação? | Produto Comercial e Backend | Resolved — sim; `REQ-00055 AC-047`–`AC-048`, decisão humana de 2026-09-11. |
| OQ-COM-005 | Todo operador com `ROLE_COMMERCIAL` autorizado enxerga a mesma listagem global completa, sem atribuição por vendedor, tenant, carteira ou ownership? | Produto Comercial | Resolved — sim; o Comercial vê inclusive os contatos de outros operadores, decisão humana de 2026-09-11. |
| OQ-COM-006 | A presença de tenant, `X-Tenant-ID` ou personificação deve prevalecer como negação mesmo quando o token também possui `ROLE_COMMERCIAL` ou `ROLE_SUPER_ADMIN`; fora desses contextos proibidos, possuir ao menos uma das roles permitidas é suficiente? | Segurança | Resolved — sim; contexto proibido prevalece como `403`, decisão humana de 2026-09-11 materializada em `REQ-00055 AC-047` e `BR-020`. |
| OQ-COM-007 | O owner aprova manter este PRD independente com apenas o REQ-00055 como requisito principal, apoiado por REQ-00003 e REQ-00004, por se tratar de um corretivo atômico da feature `listContacts`, sem criar requisito ou iniciativa artificial? | Produto Comercial e Arquitetura | Resolved — sim; decisão humana de 2026-09-11. |

## Approval

| Role | Accountable party | Decision | Date | Evidence |
| --- | --- | --- | --- | --- |
| Owner | Solicitante humano, owner de Produto Comercial | Validated v1.4. | 2026-09-11 | Respostas explícitas para `OQ-COM-004`–`OQ-COM-007` e confirmação final. |
| Reviewer | Segurança, Backend e Arquitetura | Validated v1.4 para a definição repository-local. | 2026-09-11 | Aprovação humana explícita dos itens 1–5, inclusive precedência fail-closed do boundary. |

## Product Definition Gate

**Product Definition Gate:** `PASS` para PRD-00007 v1.4 e somente para
`listContacts`; o PRD-00005 v1.36 está `Validated` para IAM amplo e não amplia o
recorte funcional deste PRD.

## 15. Change log

| Version | Date | Changes |
| --- | --- | --- |
| 1.4 | 2026-09-11 | Resolve `OQ-COM-006`: contexto tenant ou personificado prevalece como `403` sobre role permitida; atualiza `REQ-00055` v3.4 e registra a aprovação humana integral que promove o PRD a `Validated`. |
| 1.3 | 2026-09-11 | Resolve `OQ-COM-004`, `OQ-COM-005` e `OQ-COM-007`: limita a feature a `listContacts`, adiciona cobertura em `REQ-00055 AC-047`–`AC-048`, define visibilidade global inclusive entre operadores e aprova a exceção de requisito único; somente a precedência do boundary permanece aberta. |
| 1.2 | 2026-09-11 | Expurga `M-COM-001` e métricas de tempo, telemetria, qualidade técnica ou quantidade; reabre o gate para delimitar a feature, explicitar regras de visibilidade/autorização, corrigir a cobertura canônica de aceite e justificar o PRD com um único requisito. |
| 1.1 | 2026-09-11 | Atualiza a referência de governança após o PRD-00005 v1.36 alcançar `Validated`, sem ampliar o recorte de `listContacts`. |
| 1.0 | 2026-09-10 | Valida o corretivo de acesso global à listagem. |
