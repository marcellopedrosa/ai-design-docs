---
document_id: TP-00052
primary_nature: Plano
objective: Coordenar a baseline OpenAPI das 207 operações originalmente descobertas e das 200 implementadas que permanecem Draft, seguindo a validação progressiva por risco.
scope: Controllers Spring MVC inventariados no ANL-00055, consumidores de produção catalogados no ANL-00057, contratos por bounded context em docs/contracts/, referências oficiais, validação humana e futura paridade contrato-runtime.
non_objectives: Alterar código ou comportamento runtime; inferir decisões ausentes; promover Draft a Active sem owner; acessar ambientes; executar Git.
owner: Arquitetura, Backend e Qualidade
status: In Progress
version: 1.36
date: 2026-09-10
last_reviewed: 2026-09-12
keywords: api, openapi, contratos, baseline, controllers, contract-first, paridade
related_files: docs/analysis/ANL-00055-backend-api-contract-coverage-inventory.md, docs/analysis/ANL-00056-api-contract-validation-loop.md, docs/analysis/ANL-00057-frontend-backend-api-contract-catalog.md, docs/contracts/README.md, ../agents/standards/api-client-standard.md, harne../../../harness/templates/TPL-00012-interface-contract.md
code_references: backend/src/main/java/br/com/duoset/saas_service/contexts/, backend/src/main/java/br/com/duoset/saas_service/infrastructure/security/SecurityConfig.java, backend/src/main/java/br/com/duoset/saas_service/shared/exception/GlobalExceptionHandler.java, frontend/, website/
principal_statement: As 228 operações backend permanecem rastreáveis ao contrato do bounded context; `getFiscalOverview` foi promovida em contrato próprio, as leituras Billing Active foram preservadas e 200 operações implementadas permanecem Draft.
---

# TP-00052 — Baseline dos contratos de API do backend

## 1. Objetivo e resultado

Materializar a estratégia de migração contract-first dos endpoints legados sem
confundir extração de código com decisão aprovada. O primeiro resultado é uma
baseline `Draft` por bounded context, com método, path, operação, segurança,
entrada, resposta, versão, fonte e gaps explícitos para todas as 207 operações
descobertas pelo ANL-00055. A etapa seguinte valida e promove operações por cinco
prioridades, atualiza os documentos oficiais consumidores e adiciona testes de
paridade.

A direção complementar do ANL-00057 parte dos consumidores reais. As dez chamadas
de produção originalmente encontradas sem controller foram removidas: cinco
divergências Fiscal pelo [TP-00056](TP-00056-expurgo-consumidores-fiscais-sem-backend.md)
e cinco Omnichannel/Tenant pelo
[TP-00057](TP-00057-expurgo-consumidores-orfaos-omnichannel-tenant.md). Não resta
operação consumer-only no catálogo.

O plano executa os sete passos acordados:

1. agrupar contratos por bounded context, não por controller;
2. extrair a baseline de controllers, DTOs, segurança e exception handlers;
3. registrar lacunas sem usar placeholder silencioso ou inventar comportamento;
4. validar as lacunas contra requisito, caso de uso, ADR e owners;
5. promover para `Active` somente contrato completo e aprovado;
6. referenciar versão e `operationId`s nos documentos oficiais afetados;
7. proteger contrato e runtime com testes de paridade positivos e negativos.

## 2. Fontes e limites

- [ANL-00055](../../analysis/ANL-00055-backend-api-contract-coverage-inventory.md):
  baseline de 51 controllers e 228 mappings; estado atual de 28 operações Active e
  200 Draft, sem gap de inventário.
- [ANL-00057](../../analysis/ANL-00057-frontend-backend-api-contract-catalog.md):
  catálogo linha a linha das 228 operações por bounded context e direção, sem
  chamada frontend órfã remanescente.
- [API Client Standard](../agents/standards/api-client-standard.md): contrato
  obrigatório, lifecycle, conteúdo mínimo e referências RFC.
- [TPL-00012](../../../harness/templates/TPL-00012-interface-contract.md):
  formato canônico para criação e revisão.
- `SecurityConfig`, `@PreAuthorize`, assinaturas dos controllers, DTOs e exception
  handlers: evidência do estado implementado; não equivalem a aprovação de design.
- Contratos `Active` existentes: preservados como fontes superiores para as 28
  operações cobertas e excluídos dos Drafts para evitar dupla autoridade.

Esta mudança é exclusivamente documental. Product Definition, Requirement, User
Story View, Use Case e Implementation Readiness são `not applicable` para criar a
baseline de dívida observada. Passam a ser obrigatórios por operação antes de
resolver decisões de produto, alterar software ou promover o contrato a `Active`.

## 3. Contratos da baseline

| Bounded context | Contrato Draft | Backend implementado | Frontend sem backend | Total Draft |
|---|---|---:|---:|---:|
| Billing | [billing-v1](../../contracts/billing-v1.openapi.yaml) | 58 | 0 | 58 |
| Certificate | [certificate-v1](../../contracts/certificate-v1.openapi.yaml) | 5 | 0 | 5 |
| Client | [client-v1](../../contracts/client-v1.openapi.yaml) | 9 | 0 | 9 |
| Commercial | [commercial-v1](../../contracts/commercial-v1.openapi.yaml) | 10 | 0 | 10 |
| Dashboard | [dashboard-v1](../../contracts/dashboard-v1.openapi.yaml) | 3 | 0 | 3 |
| Fiscal | [fiscal-v1](../../contracts/fiscal-v1.openapi.yaml) | 16 | 0 | 16 |
| LLM | [llm-v1](../../contracts/llm-v1.openapi.yaml) | 4 | 0 | 4 |
| Notification | [notification-v1](../../contracts/notification-v1.openapi.yaml) | 11 | 0 | 11 |
| Observability | [observability-v1](../../contracts/observability-v1.openapi.yaml) | 1 | 0 | 1 |
| Omnichannel | [omnichannel-v1](../../contracts/omnichannel-v1.openapi.yaml) | 54 | 0 | 54 |
| Tenant | [tenant-v1](../../contracts/tenant-v1.openapi.yaml) | 29 | 0 | 29 |
| **Total pendente** | **11 contratos** | **200** | **0** | **200** |

Todos iniciaram em `info.version: 0.1.0`, usam `x-contract-status: Draft` e versão
pública `v1` no nome. Após o refinamento integral P1–P5, Dashboard está em `0.4.0`;
Certificate, LLM e Observability estão em `0.2.0`; Client, Commercial e Notification estão em
`0.3.0`; Fiscal está em `0.6.0`, Billing em `0.5.2`, Omnichannel em `0.10.0` e
Tenant em `0.11.0`. O status proíbe uso como
autorização de implementação e evita concorrência com os sete contratos `Active`
existentes.

## 4. Ordem de priorização

| Prioridade | Corte | Backend implementado | Frontend sem backend | Critério de saída |
|---:|---|---:|---:|---|
| 1 | APIs com chamada estática encontrada em services de produção do `frontend/` ou rota server-side do `website/` | 90 | 0 | Consumers confirmados; schemas, erros e autorização validados; referências oficiais atualizadas. |
| 2 | Endpoints públicos e webhooks sem evidência do lote 1 | 4 | 0 | Autenticação alternativa, assinatura/replay, idempotência, rate limit e erros negativos validados. |
| 3 | Administração, autenticação e dados sensíveis sem evidência anterior | 50 | 0 | Roles/authorities, tenant boundary, auditoria, cache e redaction validados. |
| 4 | Billing e integrações externas sem evidência anterior | 37 | 0 | Idempotência, concorrência, provider errors, retries e versionamento validados. |
| 5 | APIs internas ou de baixo uso restantes | 19 | 0 | Lacunas restantes fechadas sem reduzir os critérios dos lotes anteriores. |
| **Total pendente** | | **200** | **0** | |

Uma operação que pertença a mais de um corte assume a menor prioridade numérica.
A evidência do lote 1 foi limitada a `frontend/src/services/`, services de feature
e `website/src/app/api/`, excluindo mocks e testes; ela ainda precisa de confirmação
do owner para provar uso runtime. O contrato continua organizado por domínio; a
prioridade é atributo da operação e do backlog de validação, não motivo para
duplicar arquivos.

## 5. Tasks

### TP-00052-T01 — Congelar o inventário e a autoridade

**What:** Reconciliar as 226 operações com os contratos `Active`, fixando 19
cobertas e 207 candidatas à baseline.

**Where:** ANL-00055, `docs/contracts/` e controllers do source set principal.

**Depends on:** Solicitação humana e fontes da Seção 2.

**Reuses:** Correspondência exata `(method, path)` do ANL-00055.

**Requirements:** Não duplicar operação governada por contrato `Active`.

**Gate Audit:** `not applicable`; leitura e reconciliação documental, sem software.

**Acceptance Tests:** 51 controllers, 226 mappings, 19 cobertos e 207 gaps; soma por
contexto fecha em 207.

**Prohibited:** Tratar contrato planejado como endpoint implementado ou inferir
paridade material da mera correspondência de rota.

**Mandatory:** Preservar as três fontes `Active` existentes.

**Definition of Done:** Inventário reproduzível e conjunto de 207 operações sem
interseção com as 19 já cobertas.

### TP-00052-T02 — Criar a baseline Draft por bounded context

**What:** Projetar os 207 gaps em 11 OpenAPIs com rastreabilidade ao código e gaps
explícitos.

**Where:** Arquivos listados na Seção 3 e `docs/contracts/README.md`.

**Depends on:** TP-00052-T01.

**Reuses:** TPL-00011, schemas de erro compartilhados por arquivo e semântica HTTP
do RFC 9110.

**Requirements:** Cada operação declara `operationId`, método/path, versão,
segurança, roles/authorities, parâmetros, request body aplicável, responses com
código/descrição/body e fonte Java.

**Gate Audit:** `not applicable`; baseline documental `Draft`, proibida para
handoff executável.

**Acceptance Tests:** YAML parseável; `operationId`s únicos; exatamente 207 pares
sem duplicação; referências locais resolvíveis; todos os gaps possuem identificador
e ação para validação.

**Prohibited:** Promover para `Active`, inventar roles/status/schema ou apagar
evidência de incerteza.

**Mandatory:** Indexar individualmente os 11 contratos e marcar a extração como
estado observado, não como design aprovado.

**Definition of Done:** Baseline presente, reconciliada e validada pelo gate
documental.

### TP-00052-T02B — Impedir regressão da cobertura de inventário

**What:** Criar um validador Node sem dependência externa que reconcilie mappings
Spring MVC e operações OpenAPI, valide o conteúdo mínimo dos Drafts e falhe quando
uma rota implementada ficar descoberta ou duplicada.

**Where:** `validate-api-contract-coverage.mjs`,
`validate-api-contract-coverage.test.mjs`,
`README.md` e `infra/scripts/validate-docs.sh`.

**Depends on:** TP-00052-T02 concluída; API Client Standard v2.1; ANL-00055 v1.1;
11 Drafts `0.1.0` e 3 contratos Active catalogados.

**Reuses:** Parser Node, fixtures temporárias herméticas e wrapper fail-closed da
governança documental.

**Requirements:** O gate conta e compara pares `(method, path)`, aceita operação
contratada ainda planejada, rejeita controller descoberto, par duplicado,
`operationId` repetido e Draft sem status, versão, segurança, roles/authorities,
fonte, prioridade, perguntas ou responses mínimos.

**Gate Audit:** `READY`, auditado pela skill `implementation-readiness` em
2026-09-10 para os quatro paths exatos acima e para este contrato v1.1.

- Product Definition: `not applicable`; o validador protege governança e não muda
  comportamento, público, valor, métrica ou wire protocol.
- Requirement/User Story/Use Case: `not applicable`; o comportamento verificável
  é integralmente definido por TP-00052-T02, API Client Standard v2.1 e
  ANL-00055 v1.1.
- Assumptions e Open Questions: nenhuma para este gate. Os gaps semânticos dos
  Drafts continuam bloqueando promoção, mas não impedem verificar presença,
  unicidade e campos explicitamente marcados para revisão.
- Granularidade: task atômica; parser, teste, catálogo e ligação ao wrapper formam
  uma única capacidade fail-closed e um único handoff.
- Dependências: somente Node e filesystem locais já usados pelo wrapper; sem
  instalação, rede, Git, ambiente ou dados reais.

**Result:** `READY`; mudança em paths, regras ou fontes invalida esta auditoria.

**Acceptance Tests:** Fixture positiva; negativas para rota descoberta, duplicata
e Draft incompleto; execução no repositório retorna 228/228 endpoints backend,
228 operações contratadas, 200 Drafts, 28 operações Active e zero operação
contratada sem controller.

**Prohibited:** Parser permissivo em falha, geração/alteração automática de
contrato, inferência semântica, dependência de Git/rede ou promoção de status.

**Mandatory:** Teste focal Node antes da integração; wrapper documental agregado;
resultado A1/A2/A3 registrado conforme o Quality Gate.

**Definition of Done:** Testes herméticos e execução repository-local passam com
código 0; o wrapper chama ambos e falha diante das regressões cobertas.

### TP-00052-T03 — Validar pelos cinco lotes de prioridade

**What:** Fechar gaps de contrato na ordem da Seção 4 com Produto, Arquitetura,
Backend, Segurança e owners de integrações aplicáveis.

**Where:** Contratos Draft, PRDs, requirements, use cases, ADRs e planos oficiais
afetados.

**Depends on:** TP-00052-T02 e owner competente por decisão.

**Reuses:** Evidências `x-source-*` da baseline e fontes superiores existentes.

**Requirements:** Cada mudança de comportamento deve nascer na fonte competente;
o OpenAPI referencia a decisão e não a substitui.

**Gate Audit:** `BLOCKED` para qualquer operação enquanto houver item em
`x-open-questions`, schema permissivo, autorização não resolvida ou resposta sem
paridade comprovada.

**Acceptance Tests:** Revisão positiva e negativa de segurança, requests,
responses, erros, versionamento e consumidores por operação.

**Prohibited:** Validação em massa por silêncio, defaults presumidos ou aprovação
do próprio agente.

**Mandatory:** Registrar owner, decisão, fonte e data de fechamento de cada gap.

**Definition of Done:** Operações do lote sem gaps e aprovadas individualmente.

### TP-00052-T04 — Promover, referenciar e provar paridade

**What:** Promover somente operações completas a `Active`, atualizar documentos
oficiais consumidores e criar testes contrato-runtime.

**Where:** Contratos, PRDs/requisitos/UCs/planos aplicáveis e testes backend/client.

**Depends on:** TP-00052-T03 concluída para o lote e novo IRG `READY` nos paths
exatos de qualquer mudança de software.

**Reuses:** `operationId`, versão SemVer, fixtures e testes focais existentes.

**Requirements:** Handoff cita arquivo, `info.version`, status `Active` e
`operationId`s; testes cobrem sucesso, erro, autorização e conteúdo negociado.

**Gate Audit:** `BLOCKED`; esta versão do plano não autoriza edição de software. O
gate deve ser reexecutado após fechar fontes, dependências, testes e DoD do lote.

**Acceptance Tests:** Paridade de método/path, entrada, saída, status, erro e
segurança; divergência quebra o gate.

**Prohibited:** Referenciar Draft como contrato implementável, mudar runtime antes
do contrato `Active` ou realizar breaking change sem nova major pública.

**Mandatory:** Atualizar os documentos oficiais na mesma mudança e registrar os
comandos do Quality Gate aplicável.

**Definition of Done:** Contrato `Active`, referências exatas e provas de paridade
verdes para o lote.

## 6. Riscos e mitigação

| Risco | Mitigação |
|---|---|
| Código legado ser confundido com especificação desejada | Todo arquivo nasce `Draft`, traz fonte e gaps e não autoriza implementação. |
| Dupla autoridade sobre uma rota | Pares já cobertos por contrato `Active` são excluídos e a reconciliação verifica unicidade. |
| Baseline grande ocultar endpoints críticos | Cinco lotes ordenam consumo, exposição, privilégio, integração e uso interno. |
| Schema permissivo virar contrato definitivo | `additionalProperties` extraído permanece gap bloqueante para promoção. |
| Erros atuais divergirem de RFC 9457 | Baseline registra o envelope legado observado; migração exige decisão versionada e teste. |
| Drift reaparecer após a migração | TP-00052-T04 torna a paridade automatizada parte do gate. |

## 7. Estado e evidências

- TP-00052-T01: `Completed` pelo ANL-00055 e reconciliação atual.
- TP-00052-T02: `Completed`; a baseline nasceu com 207 pares Draft. Após duas
  operações Billing, `listContacts`, `getUsageRecords` e `getFiscalOverview` graduarem por fluxos próprios,
  11 YAMLs mantêm 200 pares sem interseção com os Active. A distribuição corrente é
  `P1=90`, `P2=4`, `P3=50`, `P4=37`, `P5=19`; os dez consumers sem backend
  inicialmente catalogados foram expurgados, mantendo o total Draft em 200.
- TP-00052-T02B: `Completed`; o sentinel e seus oito testes herméticos, a cobertura
  228/228, as referências canônicas e o wrapper documental agregado estão verdes.
  As 12 referências abreviadas encontradas no gate anterior foram canonicalizadas
  sem mudança de produto ou runtime.
- TP-00052-T03: ciclo 1 de prontidão concluído nos cinco lotes e registrado no
  [ANL-00056](../../analysis/ANL-00056-api-contract-validation-loop.md); `BLOCKED` no
  passo 4 da prioridade P1 após concluir o refinamento AS-IS de P1–P5. As dezoito primeiras
  fatias refinaram seis operações Client, cinco Certificate, quatro Dashboard,
  quatro LLM, onze Notification, oito Fiscal, seis Commercial, duas Billing, uma
  Observability, 24 Omnichannel e 22 Tenant, totalizando 93/93 P1 originalmente
  classificadas; `listContacts` foi depois promovida por fluxo externo. A décima
  nona fatia refinou 4/4 P2 em Stripe, Telegram e WhatsApp; a vigésima refinou as
  primeiras 5/52 P3 em Commercial, quatro em Tenant, três em Fiscal, 14 em
  Omnichannel e 26 em Billing, totalizando 52/52 P3. A vigésima quinta refinou as
  primeiras 5/37 P4 em configurações Telegram/WhatsApp e credenciais SERPRO; a
  vigésima sexta refinou as 32 operações Billing restantes e concluiu 37/37 P4.
  A vigésima sétima refinou 19/19 P5 em Client, Fiscal, Omnichannel e Tenant. A
  auditoria global registrou zero sucesso opaco antes da promoção externa de
  `getPrice`, `getProduct`, `getUsageRecords` e `getFiscalOverview`; as 200 operações remanescentes preservam seus próprios
  blockers de schema, erro, autorização, paridade e Product Definition Gate.
- TP-00052-T04: `BLOCKED` por T03 e por novo Implementation Readiness Gate antes de
  qualquer mudança de software.

## 8. Evidência de Assurance

| Camada | Comando | Resultado em 2026-09-10 |
|---|---|---|
| A1 — testes focais | `node validate-api-contract-coverage.test.mjs` | `PASS`, 8 testes, zero falhas e zero skips. |
| A1 — cobertura | `node validate-api-contract-coverage.mjs --root .` | Esperado após a promoção fiscal: 51 controllers, 228 operações implementadas cobertas, 18 contratos, 228 operações contratadas, 200 Draft e zero sem controller. |
| A1 — referências | `perl infra/scripts/validate-doc-reference-identifiers.pl docs` | `PASS`; zero referência abreviada remanescente. |
| A2 — governança | `node infra/scripts/validate-docs.sh --root .` | `PASS`, 796 Markdown, 31 diretórios e 798 artefatos indexados. |
| A2 — wrapper documental | `./infra/scripts/validate-docs.sh` | `PASS`, código 0; todos os gates agregados e a validação de estrutura passaram. |

O resultado agregado conclui TP-00052-T02B e prova cobertura de inventário e
governança documental. Ele não prova paridade material de payload, erro, RBAC,
tenant boundary ou regra de negócio; essas evidências continuam bloqueadas em T03
e T04.

O loop solicitado permanece ativo e reinicia no primeiro passo incompleto. O ciclo
1 auditou a prontidão de P1 a P5, concluiu o refinamento AS-IS de todos os cinco
lotes e retorna ao passo 4/P1 para decisões dos owners; nenhum
status foi promovido por inferência e nenhum código de produto foi alterado.

## 9. Change log

| Version | Date | Changes |
|---|---|---|
| 1.36 | 2026-09-12 | Reconcilia a promoção de `getFiscalOverview` ao contrato Dashboard Fiscal Overview Active 1.0.0, preserva duas leituras Billing já Active e atualiza o backlog para 28 Active/200 Draft em 18 contratos. |
| 1.35 | 2026-09-11 | Reconciliado o expurgo das cinco divergências Omnichannel/Tenant: contratos 0.10.0/0.11.0, catálogo global com 228 operações e zero consumer-only, preservando callbacks/configurações reais. |
| 1.34 | 2026-09-11 | Reconciliado o expurgo das cinco divergências Fiscal: contrato 0.6.0 com 16 operações backend, catálogo global com 233 operações e cinco consumer-only remanescentes. |
| 1.33 | 2026-09-10 | Registra Tenant Billing Usage v1 Active e reconcilia 25 operações Active, 203 implementadas Draft e 213 Draft totais. |
| 1.32 | 2026-09-10 | Incorpora o catálogo direcional ANL-00057, registra dez chamadas frontend sem controller em Fiscal/Omnichannel/Tenant e reconcilia 238 contratos, 228 endpoints backend e 214 Draft sem alterar software. |
| 1.31 | 2026-09-10 | Canonicaliza as 12 referências que impediam o wrapper, conclui TP-00052-T02B com `validate-docs.sh` em PASS e mantém T03/T04 bloqueadas sem código ou promoção. |
| 1.30 | 2026-09-10 | Executa a vigésima sétima fatia, refina 19/19 P5 em Client/Fiscal/Omnichannel/Tenant, conclui P1–P5 AS-IS com zero sucesso opaco e mantém passos 4–7 bloqueados/parciais, sem código ou promoção. |
| 1.29 | 2026-09-10 | Executa a vigésima sexta fatia, refina 32 operações Billing com schemas fechados, contexto financeiro, ETag/no-store/idempotência e RFC 9457, conclui 37/37 P4 e avança a P5 sem código ou promoção. |
| 1.28 | 2026-09-10 | Executa a vigésima quinta fatia, refina cinco operações P4 de configurações Telegram/WhatsApp e credenciais SERPRO, avançando P4 a 5/37 sem código ou promoção. |
| 1.27 | 2026-09-10 | Executa a vigésima quarta fatia, refina 26 operações Billing Catalog P3 com schemas estritos, ETag/no-store, idempotência, approvals/MFA e RFC 9457, conclui P3 e avança a P4 sem mudança de código ou promoção. |
| 1.26 | 2026-09-10 | Executa a vigésima terceira fatia, refina 14 operações Omnichannel P3 de providers, prompts, funções e rotas de recibo WhatsApp sem alteração de código ou promoção. |
| 1.25 | 2026-09-10 | Executa a vigésima segunda fatia, refina três operações Fiscal P3 de migração PDF e traffic logs SERPRO sem alteração de código ou promoção. |
| 1.24 | 2026-09-10 | Executa a vigésima primeira fatia, refina quatro operações Tenant P3 de onboarding legado, SERPRO status e traffic inspector sem alteração de código ou promoção. |
| 1.23 | 2026-09-10 | Executa a vigésima fatia, refina cinco operações Commercial P3 com detalhe/PII, CAS, destinatários, soft delete e drift de autorização/consumer sem alteração de código ou promoção. |
| 1.22 | 2026-09-10 | Executa a décima nona fatia, fecha 4/4 P2 em Billing 0.3.0 e Omnichannel 0.5.0, reconcilia `listContacts` Active e avança para P3 sem alteração de código ou promoção pelo loop. |
| 1.21 | 2026-09-10 | Executa a décima oitava fatia, fecha as duas operações pool-policy com schemas estritos, ETag/idempotência/erros e conclui 93/93 P1 AS-IS sem alteração de código ou promoção. |
| 1.20 | 2026-09-10 | Executa a décima sétima fatia P1 nas seis operações de usuários Tenant e explicita roles, bodyless mutations, quota, boundary e riscos IAM/local/evento sem alteração de código ou promoção. |
| 1.19 | 2026-09-10 | Executa a décima sexta fatia P1 nas cinco operações Tenant de lifecycle/assinatura e explicita Page, compensation, boundary, placeholders e drifts sem alteração de código ou promoção. |
| 1.18 | 2026-09-10 | Executa a décima quinta fatia P1 em convite, discovery e perfil/senha Tenant e explicita enumeração, token, issuer/realm e password grant sem alteração de código ou promoção. |
| 1.17 | 2026-09-10 | Executa a décima quarta fatia P1 nas quatro operações Tenant de administradores globais e explicita schemas, IAM/local mirror, senha e falhas parciais sem alteração de código ou promoção. |
| 1.16 | 2026-09-10 | Executa a décima terceira fatia P1 nas sete operações Omnichannel restantes de funções, provider, extração, usage e logs sem alteração de código ou promoção. |
| 1.15 | 2026-09-10 | Executa a décima segunda fatia P1 em sete operações Omnichannel de configurações/acessos e explicita máscaras, boundaries, efeitos assíncronos e incompatibilidade de consumidor sem alteração de código ou promoção. |
| 1.14 | 2026-09-10 | Executa a décima primeira fatia P1 em dez operações Omnichannel de prompts/templates e explicita schemas, status, permissividade e drifts sem alteração de código ou promoção. |
| 1.13 | 2026-09-10 | Executa a décima fatia P1 em `getLogs`, registra binding, labels/limite Loki, exposição, drift frontend e falha externa convertida em 400 sem promoção. |
| 1.12 | 2026-09-10 | Executa a nona fatia P1 nas duas emissões Billing de contexto elevado e explicita schema V2, ETag/no-store, MFA, authorities e RFC 9457 sem promoção. |
| 1.11 | 2026-09-10 | Executa a oitava fatia P1 em seis operações Commercial e explicita página/DTOs, RBAC divergente, token técnico, idempotência e rate limit sem promoção. |
| 1.10 | 2026-09-10 | Executa a sétima fatia P1 em oito operações Fiscal, registra nove responses observados e drifts de DTO/SERPRO/425 sem promoção, e reconcilia 228 mappings/23 Active. |
| 1.9 | 2026-09-10 | Executa a sexta fatia P1 nas seis operações Notification globais, completa o refinamento AS-IS do contexto em Draft 0.3.0 e mantém zero promoção. |
| 1.8 | 2026-09-10 | Executa a quinta fatia P1 em cinco operações Notification tenant/local, explicita lista/SSE/Page e drifts de status/nullability/400 sem alterar código ou promover. |
| 1.7 | 2026-09-10 | Executa a quarta fatia P1 em LLM e reconcilia duas promoções Billing externas: 205 operações permanecem Draft, com distribuição 93/4/52/37/19 e zero promoção pelo loop. |
| 1.6 | 2026-09-10 | Executa a terceira fatia P1 em quatro operações Dashboard, fecha schemas AS-IS, registra limites/cache/autorização composta e mantém zero promoção. |
| 1.5 | 2026-09-10 | Executa a segunda fatia P1 em cinco operações Certificate, registra três drifts frontend/backend e mantém zero promoção. |
| 1.4 | 2026-09-10 | Executa a primeira fatia P1 em seis operações Client, registra drifts objetivos e mantém zero promoção por blockers de owner/produto/paridade. |
| 1.3 | 2026-09-10 | Liga o ANL-00056, registra o ciclo 1 integral de prontidão, mantém o loop em P1 com zero promoção e preserva o blocker agregado concorrente de settings. |
| 1.2 | 2026-09-10 | Implementa o sentinel permanente e oito testes, integra-o ao gate documental e registra A1 verde/A2 vermelho por referências concorrentes fora do escopo. |
| 1.1 | 2026-09-10 | Conclui a baseline Draft, fixa 93/4/53/38/19 operações nos cinco lotes e registra IRG READY para o gate repository-local de cobertura de inventário. |
| 1.0 | 2026-09-10 | Cria o plano persistente dos sete passos, 11 Drafts e cinco lotes de priorização para os 207 gaps do ANL-00055. |
