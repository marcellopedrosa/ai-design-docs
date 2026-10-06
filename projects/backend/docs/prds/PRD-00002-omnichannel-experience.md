---
document_id: PRD-00002
primary_nature: Requisito
objective: Definir a intencao, os resultados e o gate de validacao da experiencia omnichannel de autoatendimento fiscal.
scope: Descoberta e autori
acao do contato, entrada e resposta por WhatsApp/Telegram, menu e modo conversacional, continuidade, quotas, auditoria e operacao dos canais.
non_objectives: Repetir acceptance criteria, detalhar fluxos conversacionais, decidir arquitetura ou provider LLM, autorizar integracoes externas, definir a operacao fiscal ou afirmar validacao de usuario inexistente.
owner: Produto e Operacoes Omnichannel
status: Validated
version: 1.35
date: 2026-09-09
last_reviewed: 2026-09-13
keywords: prd, omnichannel, whatsapp, telegram, chatbot, autoatendimento, auditoria
related_files: docs/product/requirements/README.md, projects/backend/docs/prds/PRD-00006-conversation-audit-retention-administration.md, docs/product/business/product-vision.md, docs/product/requirements/REQ-00001-whatsapp-business-integration.md, docs/product/requirements/REQ-00002-function-registry-dynamic-menu.md, docs/product/requirements/REQ-00007-telegram-contact-discovery-authorization.md, docs/product/requirements/REQ-00027-chatbot-llm-function-calling-orchestration.md, docs/product/requirements/REQ-00028-chatbot-llm-conversational-mode.md, docs/product/requirements/REQ-00035-phase3-whatsapp-omnichannel-foundation.md, docs/product/requirements/REQ-00036-phase3-omnichannel-administration-and-channels.md, docs/product/requirements/REQ-00037-phase3-llm-and-administration-observability.md, docs/product/requirements/REQ-00041-chatbot-conversation-audit.md, docs/product/requirements/REQ-00043-conversation-audit-data-governance.md, docs/product/requirements/REQ-00050-omnichannel-durable-inbound-processing.md, docs/product/requirements/REQ-00062-omnichannel-event-audit-action-taxonomy.md, docs/architecture/omnichannel-conversational-function-lifecycle.md, docs/delivery/plans/TP-00003-omnichannel-integration-task-plan.md, docs/delivery/plans/implementation_plans/backend/IP-BE-3.2.17-fiscal-report-terminal-publication-serialization.md
code_references: backend/src/main/java/br/com/duoset/saas_service/contexts/omnichannel/, backend/src/main/java/br/com/duoset/saas_service/contexts/llm/, frontend/, infra/
principal_statement: O cliente autorizado deve obter uma experiencia fiscal confiavel e coerente no canal disponível, enquanto o escritorio mantém controle, auditoria e limites da operacao.
---

# PRD-00002 — Experiência Omnichannel

## 1. Executive summary

A visão do produto propõe que escritórios de contabilidade ofereçam autoatendimento
fiscal por mensagem, com autorização, isolamento e auditoria. Embora a visão
original ancore a oferta no WhatsApp, o primeiro ciclo validável prioriza o
Telegram, cuja implementação já existe no repositório. WhatsApp permanece como
canal posterior e não prioritário neste ciclo. A base omnichannel também contempla
menus, intenção por LLM, processamento durável e administração dos canais.
O primeiro ciclo funcional no Telegram inclui consulta de situação fiscal e geração
de DAS Regular. Ambas permanecem acessíveis por linguagem natural mesmo sem
funções globais cadastradas no menu; o catálogo futuro apenas acrescenta descoberta
por clique.

Este PRD reúne a intenção e os resultados dessa experiência sem reproduzir o
comportamento detalhado dos requisitos ou os fluxos dos casos de uso. A base
técnica e o primeiro ciclo Telegram estão implementados e validados. Os requisitos
aplicáveis foram aprovados conforme o comportamento vigente, e Produto, Operações
Omnichannel e Segurança/Compliance concederam aprovação integral em 2026-09-12;
por isso o estado é `Validated`.

## Problema e evidência

### Problem statement

Clientes de escritórios precisam obter serviços fiscais com baixo atrito, mas o
canal de mensagem só gera valor quando identidade, autorização, contexto e resposta
permanecem coerentes. Para o escritório, operar canais distintos sem uma experiência
comum aumenta risco de acesso indevido, perda de mensagem, inconsistência e falta
de evidência sobre o atendimento.

### Evidence currently available

| Evidence | What it supports | Limitation |
| --- | --- | --- |
| [Visão do produto](../business/product-vision.md) | WhatsApp como canal de autoatendimento fiscal e princípios de autorização/auditoria. | Não registra pesquisa, volume, adoção ou satisfação. |
| [REQ-00035](../requirements/REQ-00035-phase3-whatsapp-omnichannel-foundation.md) e [REQ-00036](../requirements/REQ-00036-phase3-omnichannel-administration-and-channels.md) | Baseline funcional da fundação e administração omnichannel. | Parte do conteúdo descreve AS-IS técnico, não resultado de usuário. |
| [Lifecycle conversacional](../../architecture/omnichannel-conversational-function-lifecycle.md) e [IP-BE-3.2.13-authenticated-office-menu-bootstrap](../../delivery/plans/implementation_plans/backend/IP-BE-3.2.13-authenticated-office-menu-bootstrap.md) | Bootstrap autenticado apresenta o menu e preserva a continuidade por texto livre no core omnichannel. | Evidência arquitetural e repository-local não aprova os requisitos funcionais nem certifica provider externo. |
| [REQ-00050](../requirements/REQ-00050-omnichannel-durable-inbound-processing.md) | Processamento inbound durável implementado localmente. | Confiabilidade técnica local não prova conclusão bem-sucedida da jornada. |
| [REQ-00041](../requirements/REQ-00041-chatbot-conversation-audit.md) e [REQ-00043](../requirements/REQ-00043-conversation-audit-data-governance.md) | Auditoria e governança de dados aprovadas. | Operação ambiental e percepção do escritório não estão demonstradas. |
| [REQ-00001](../requirements/REQ-00001-whatsapp-business-integration.md) | Intenção funcional do canal principal da visão. | Permanece `Draft`; não pode sustentar fechamento do PRD. |
| Declaração do owner registrada nesta revisão | Situação Fiscal e DAS Regular foram submetidas a testes técnicos nos quais clientes reais interagiram diretamente com o bot usando dados reais. Os clientes informaram que a experiência precisava ser mais conversacional; após a melhoria, retestaram e consideraram a nova experiência adequada. | Relato histórico do owner, sem artefato versionado, identidade ou payload; não constitui métrica nem critério formal de validação desta fase. |

Por decisão do owner, nenhuma evidência qualitativa ou quantitativa será exigida ou
tratada como métrica de validação nesta fase. Não haverá coleta, instrumentação ou
telemetria para esse fim. As declarações históricas acima permanecem apenas como
contexto e não criam pendência de medição.

## Público e contexto

| Audience | Need / job | Expected value |
| --- | --- | --- |
| Cliente final autorizado | Solicitar e receber serviço fiscal pelo canal acessível. | Menos atrito e resposta confiável sem perder segurança. |
| Escritório assinante / Tenant Admin | Configurar canais, funções e contatos autorizados. | Controle operacional e redução de atendimento manual repetitivo. |
| Contador responsável | Preservar contexto e evidência do serviço fiscal. | Continuidade e auditabilidade do atendimento. |
| Auditor / Compliance | Consultar interações conforme autoridade e retenção. | Evidência rastreável com proteção de dados. |
| Operações Omnichannel | Detectar falhas, backlog e degradação por canal. | Recuperação controlada e visão operacional comparável. |

## Outcomes e não-objetivos

> Outcomes quantitativos de tempo, qualidade, cobertura e garantia não são aplicáveis ao escopo MVP.


1. Permitir que um contato elegível inicie e conclua uma jornada autorizada pelo
   canal suportado.
2. Oferecer experiência coerente de apresentação, menu, intenção e resposta entre
   WhatsApp e Telegram, respeitando capacidades do canal.
3. Reduzir perda, duplicidade e abandono decorrentes de falhas de processamento.
4. Dar ao escritório controle sobre funções, templates, quotas e auditoria.

### Non-goals

- Definir o conteúdo funcional de cada serviço fiscal.
- Tornar o LLM autoridade de negócio ou substituir regras determinísticas.
- Aprovar acesso de contato, retenção ou tratamento de dados fora dos requisitos.
- Autorizar Meta, Telegram, LLM ou outro sistema externo.
- Especificar webhooks, filas, schemas, state machines ou topologia.
- Recontar fluxos de conversa já mantidos em casos de uso.

## 5. Product scope and limits

### In scope

- descoberta, vínculo e autorização do contato;
- entrada, identidade visual e resposta nos canais suportados;
- apresentação de funções e modo conversacional;
- continuidade e confiabilidade percebida da jornada;
- quotas e limites compreensíveis;
- configuração pelo escritório;
- auditoria e governança da interação.

### Out of scope for this validation cycle

- implementação ou priorização do canal WhatsApp, reservado a um ciclo posterior;
- novos canais além de WhatsApp e Telegram;
- jornada fiscal específica que ainda não possua requisito aprovado;
- campanha outbound, marketing conversacional ou CRM;
- promessa de resposta totalmente autônoma para toda intenção;
- métricas ou métodos de validação qualitativos ou quantitativos, inclusive
  entrevistas, pesquisas, baselines, targets, instrumentação e qualquer telemetria
  voltada à validação do produto nesta fase;
- novo acesso, reutilização ou exposição de credenciais, dados reais ou integração
  externa; o relato histórico de testes não autoriza sua repetição nem versionamento
  de identidade ou payload.

Decisão humana de 2026-09-12: `F-OMNI-001` e `REQ-00001` ficam em quarentena
documental não bloqueante até que a configuração da WABA seja compreendida e
finalizada. Não há prazo de implementação e a feature pode permanecer sem
implementação; sua reativação exige decisão humana, requisito aprovado e novo
readiness. A quarentena não bloqueia Telegram nem as demais features do ciclo ativo.

## 6. Product validation criteria

O PRD somente pode mudar para `Validated` quando Produto e Operações registrarem as
decisões aplicáveis e os requisitos/reviews necessários estiverem aprovados, sem
depender de medição qualitativa ou quantitativa nesta fase:

- jornada e segmento prioritários do primeiro ciclo;
- proposta de valor e limites do autoatendimento;
- papel de cada canal na oferta inicial;
- encerramento das perguntas `OQ-OMNI-*`;
- requisito primário do canal escolhido em estado compatível com a próxima fase;
- aprovação dos reviewers de Segurança/Compliance quando aplicável.

Esses são critérios de fechamento do PRD, não acceptance criteria de software.

zados. Não haverá baseline, target, janela, fonte de
coleta, instrumentação, telemetria ou medição qualitativa/quantitativa; eventual
medição pertence a uma fase futura aprovada separadamente e não constitui pendência
deste ciclo.

Registros funcionais exigidos por requisitos de auditoria e segurança permanecem
governados por suas fontes próprias e não são métricas de validação deste PRD.

## Métricas

Não aplicável ao escopo MVP; métricas de tempo, qualidade, cobertura e garantia ficam fora desta fase.

## Product Hypotheses

Por decisões do owner em 2026-09-11, `H-OMNI-001`–`H-OMNI-004` foram expurgadas
do escopo de validação desta fase. `H-OMNI-003` e `H-OMNI-004` também foram
retiradas porque seu fechamento exigiria validação qualitativa ou quantitativa,
expressamente excluída do ciclo. Não há hipóteses ativas; os IDs aposentados não
serão reutilizados e o histórico permanece no change log.

## Features e mapa de requirements

| Requirement | Contribution | Current documentary state |
| --- | --- | --- |
| [REQ-00001](../requirements/REQ-00001-whatsapp-business-integration.md) | Canal WhatsApp que ancora a visão original. | Draft |
| [REQ-00002](../requirements/REQ-00002-function-registry-dynamic-menu.md) | Menu sem catálogo global de negócio inicialmente obrigatório; Situação Fiscal e DAS Regular permanecem acessíveis por linguagem natural, enquanto funções de menu e funções customizadas tenant-scoped sob add-on evoluem gradualmente. | Approved v1.10 para o primeiro ciclo Telegram; funções customizadas/add-on permanecem evolução futura independente. |
| [REQ-00007](../requirements/REQ-00007-telegram-contact-discovery-authorization.md) | Descoberta e autorização via Telegram. | Approved v1.6; implementado e validado conforme o fluxo vigente. |
| [REQ-00027](../requirements/REQ-00027-chatbot-llm-function-calling-orchestration.md) | Intenção e orquestração do chatbot. | Approved |
| [REQ-00028](../requirements/REQ-00028-chatbot-llm-conversational-mode.md) | Interação conversacional livre. | Approved v1.16; 43/43 critérios comprovados repository-local/DEV, incluindo a serialização terminal concorrente fechada pelo IP-BE-3.2.17-fiscal-report-terminal-publication-serialization. |
| [REQ-00035](../requirements/REQ-00035-phase3-whatsapp-omnichannel-foundation.md) | Fundação omnichannel AS-IS. | Approved baseline |
| [REQ-00036](../requirements/REQ-00036-phase3-omnichannel-administration-and-channels.md) | Administração, canais, funções, templates e quotas. | Approved v1.7; inbound durável fechado localmente, Traffic Inspector e demais gaps preservados. |
| [REQ-00037](../requirements/REQ-00037-phase3-llm-and-administration-observability.md) | LLM e observabilidade administrativa. | Approved v1.2; AC-P3-005/036 comprovados repository-local/DEV. |
| [REQ-00041](../requirements/REQ-00041-chatbot-conversation-audit.md) | Consulta e administração da auditoria conversacional. | Approved |
| [REQ-00043](../requirements/REQ-00043-conversation-audit-data-governance.md) | Governança técnica dos dados de conversa. | Approved |
| [REQ-00050](../requirements/REQ-00050-omnichannel-durable-inbound-processing.md) | Inbound durável e recuperável. | Implemented locally v1.6; 16/16 critérios reconciliados em DEV. |
| [REQ-00062](../requirements/REQ-00062-omnichannel-event-audit-action-taxonomy.md) | Taxonomia neutra e minimizada para os dois listeners de auditoria cross-channel. | Approved v1.1; implementação e testes repository-local concluídos nos quatro paths. |

Os acceptance criteria permanecem exclusivamente nesses requisitos.

### 9.1 Feature inventory and acceptance coverage

| Feature ID | Product feature / audience outcome | Requirements | Canonical acceptance coverage | Documentary state |
| --- | --- | --- | --- | --- |
| `F-01` | Atender contatos autorizados pelo WhatsApp no contexto correto do escritório. | [REQ-00001](../requirements/REQ-00001-whatsapp-business-integration.md) | [REQ-00001 AC-001–AC-017](../requirements/REQ-00001-whatsapp-business-integration.md#7-acceptance-criteria) | Quarantined — não bloqueante até entendimento e conclusão da configuração WABA. |
| `F-02` | Apresentar no primeiro ciclo Telegram a estrutura de menu sem exigir função global de negócio inicial; com zero funções, manter saída segura e permitir que o cliente autorizado acesse Situação Fiscal e DAS Regular por linguagem natural. | [REQ-00002](../requirements/REQ-00002-function-registry-dynamic-menu.md) | [REQ-00002 AC-016–AC-021 e AC-028–AC-029](../requirements/REQ-00002-function-registry-dynamic-menu.md#7-acceptance-criteria) | Implemented/tested para fallback seguro e linguagem natural do primeiro ciclo; catálogo tipado de seções permanece fora de readiness até congelar códigos e gates. |
| `F-03` | Descobrir e autorizar contatos que chegam pelo Telegram. | [REQ-00007](../requirements/REQ-00007-telegram-contact-discovery-authorization.md) | [REQ-00007 AC-001–AC-012](../requirements/REQ-00007-telegram-contact-discovery-authorization.md#7-acceptance-criteria) | Approved v1.6; implementado e validado conforme o comportamento vigente. |
| `F-04` | Traduzir uma intenção conversacional em função fiscal governada. | [REQ-00027](../requirements/REQ-00027-chatbot-llm-function-calling-orchestration.md) | [REQ-00027 AC-001–AC-035](../requirements/REQ-00027-chatbot-llm-function-calling-orchestration.md#7-acceptance-criteria) | Implemented/tested para Situação Fiscal e DAS Regular do primeiro ciclo; execução universal de função futura continua condicionada ao handler governado correspondente. |
| `F-05` | Manter conversa livre com contexto, limites e resposta compreensível. | [REQ-00028](../requirements/REQ-00028-chatbot-llm-conversational-mode.md) | [REQ-00028 AC-001–AC-043](../requirements/REQ-00028-chatbot-llm-conversational-mode.md#7-acceptance-criteria) | Implemented/tested repository-local/DEV para 43/43 critérios. O AC-020 passou focal `24/24`, concorrência PostgreSQL `2/2` em `16.14`, impactada `41/41`, arquitetura `29/29` e Quality Gate `26/26`, todos zero-skip; a prova termina na publicação lógica vinculada ao commit terminal e não promete delivery/consumer exactly-once. WABA permanece em quarentena. |
| `F-06` | Evitar reenvio cego e preservar evidência durável quando o resultado outbound é terminal ou ambíguo. | [REQ-00041](../requirements/REQ-00041-chatbot-conversation-audit.md) | [REQ-00041 AC-AUD-050](../requirements/REQ-00041-chatbot-conversation-audit.md#12-acceptance-criteria) | Implemented/tested repository-local com ledger sem conteúdo, dispatch fence e reconciliação query-only. A proposta histórica de DLQ do `REQ-00026` está `Deprecated`. |
| `F-07` | Operar a fundação WhatsApp/omnichannel com isolamento e continuidade. | [REQ-00035](../requirements/REQ-00035-phase3-whatsapp-omnichannel-foundation.md), [REQ-00062](../requirements/REQ-00062-omnichannel-event-audit-action-taxonomy.md) | [REQ-00035 AC-OMNI-001–AC-OMNI-020](../requirements/REQ-00035-phase3-whatsapp-omnichannel-foundation.md#9-acceptance-criteria), [REQ-00062 AC-62-001–AC-62-006](../requirements/REQ-00062-omnichannel-event-audit-action-taxonomy.md#5-acceptance-criteria) | Partial — a taxonomia neutra dos dois listeners foi implementada e testada repository-local (11/11 focais, 29/29 arquitetura, Quality Gate `PASS`); fidelidade tenant/status do Traffic Inspector continua em recorte independente. WhatsApp externo permanece em quarentena. |
| `F-08` | Administrar canais, funções, templates, contatos e quotas do tenant. | [REQ-00036](../requirements/REQ-00036-phase3-omnichannel-administration-and-channels.md) | [REQ-00036 AC-OMNI-001–AC-OMNI-055](../requirements/REQ-00036-phase3-omnichannel-administration-and-channels.md#9-acceptance-criteria) | Partial — AC-OMNI-043/047 estão implementados/testados em DEV; AC-OMNI-030/031 permanecem parciais, assim como ownership do toggle, DELETE/tombstone, backend de templates e leitura persistente do Traffic Inspector. |
| `F-09` | Observar uso de LLM, operação administrativa e degradações da experiência. | [REQ-00037](../requirements/REQ-00037-phase3-llm-and-administration-observability.md) | [REQ-00037 AC-P3-001–AC-P3-036](../requirements/REQ-00037-phase3-llm-and-administration-observability.md#11-acceptance-criteria) | Partial AS-IS — AC-P3-005 passou em `LlmProviderChainTest` 5/5 e AC-P3-036 em arquitetura 29/29; prioridade integral, catálogo LLM, fallback persistido, resilience, conteúdo do prompt, telemetria e semântica de logs/top-tenants seguem independentes. |
| `F-10` | Consultar conversas e administrar auditoria conforme autoridade. | [REQ-00041](../requirements/REQ-00041-chatbot-conversation-audit.md) | [REQ-00041 AC-AUD-001–AC-AUD-073](../requirements/REQ-00041-chatbot-conversation-audit.md#12-acceptance-criteria) | Partial — read API/UI e baseline GET/preview/PUT estão implementados/testados; hardenings duráveis seguem no PRD-00006. |
| `F-11` | Governar retenção, privacidade, acesso e evidência dos dados conversacionais. | [REQ-00043](../requirements/REQ-00043-conversation-audit-data-governance.md) | [REQ-00043 AC-AUD-GOV-001–AC-AUD-GOV-066](../requirements/REQ-00043-conversation-audit-data-governance.md#15-acceptance-criteria) | Partial — administração da retenção delegada ao [PRD-00006 Validated](PRD-00006-conversation-audit-retention-administration.md), com transição `V91` → normalizador → `V92` e stores duráveis em implementação repository-local. |
| `F-12` | Aceitar, deduplicar, processar e recuperar mensagens inbound de forma durável. | [REQ-00050](../requirements/REQ-00050-omnichannel-durable-inbound-processing.md) | [REQ-00050 AC-001–AC-016](../requirements/REQ-00050-omnichannel-durable-inbound-processing.md#7-acceptance-criteria) | Implemented/tested repository-local/DEV para 16/16 critérios por prova composta: PostgreSQL 6/6, suítes de worker/dispatcher/scheduler/controllers e arquitetura 29/29. Não alega cenário literal multithread/restart, provider real, WABA ou delivery exactly-once. |
| `F-13` | Permitir que o tenant administre funções customizadas sem SERPRO em quantidade ilimitada quando contratar o add-on. | [REQ-00002](../requirements/REQ-00002-function-registry-dynamic-menu.md) | [REQ-00002 AC-022–AC-027](../requirements/REQ-00002-function-registry-dynamic-menu.md#7-acceptance-criteria) | Evolução futura; fora do primeiro ciclo Telegram e sem alegação de implementação. |

As faixas indicam cobertura documental, não que todo critério se aplique a cada
recorte da feature. O requisito linkado continua sendo a fonte para essa decisão.

## 10. Use cases and decisions by reference

- Fundação e canais: [UC-00032](../use-cases/UC-00032-phase3-whatsapp-omnichannel-foundation.md)
  e [UC-00033](../use-cases/UC-00033-phase3-omnichannel-administration-and-channels.md).
- Conversação: [UC-00025](../use-cases/UC-00025-chatbot-llm-function-calling-orchestration.md)
  e [UC-00037](../use-cases/UC-00037-chatbot-llm-conversational-mode.md).
- Quotas: [UC-00022](../use-cases/UC-00022-chatbot-quota-enforcement.md).
- Confiabilidade outbound: [REQ-00041, AC-AUD-050](../requirements/REQ-00041-chatbot-conversation-audit.md#12-acceptance-criteria).
  O [UC-00024](../use-cases/UC-00024-omnichannel-outbound-dlq.md) permanece apenas
  como registro histórico `Deprecated` da proposta não implementada.
- Auditoria: [UC-00035](../use-cases/UC-00035-chatbot-conversation-audit.md).
- Decisões arquiteturais: selecionar somente os ADRs de Omnichannel/Notificações,
  LLM, Segurança e Resiliência pelo [índice](../../adrs/README.md); este PRD não as
  redefine.

## 11. Current phase assessment

| Dimension | Observed state | Product implication |
| --- | --- | --- |
| Product vision | A visão original ancora o autoatendimento no WhatsApp; a decisão corrente prioriza Telegram no primeiro ciclo e reserva WhatsApp para depois. | Segmento, canal inicial, método de autorização e jornadas fiscais terminais estão definidos. |
| Functional definition | Administração, LLM, auditoria e durabilidade possuem requisitos aprovados para o primeiro ciclo; o CRUD customizado/add-on está explicitamente separado como evolução futura. | A definição do primeiro ciclo está aprovada e a experiência conversacional melhorada foi considerada adequada no reteste. |
| Repository implementation | Telegram, estrutura de menu com fallback seguro seguida de texto livre, fundação AS-IS e inbound durável possuem evidência local; o owner confirma Situação Fiscal e DAS Regular como funcionais e informa, em relato histórico, que clientes consideraram adequada a melhoria conversacional após o reteste. | Viabiliza o primeiro ciclo funcional no Telegram; cadastro gradual de funções e CRUD customizado/add-on não são alegados como implementados. |
| External operation | O owner declara que clientes reais interagiram diretamente com o bot usando dados reais, sem versionar identidades, payloads, ambiente ou evidência de consentimento; este PRD não autoriza novo acesso ou repetição. | O relato não amplia a evidência versionada de ambiente, consentimento ou base legal exigida pelos controles aplicáveis. |
| Product evidence | Métricas qualitativas ou quantitativas, instrumentação e telemetria foram expurgadas desta fase por decisão do owner. A participação direta dos clientes, o pedido por maior conversacionalidade e o reteste permanecem apenas como contexto histórico. | Não há pendência de medição neste ciclo; eventual programa de métricas exige uma fase futura aprovada separadamente. |

## 12. Dependencies and product risks

| Item | Impact | Owner |
| --- | --- | --- |
| Continuidade das jornadas fiscais | Situação Fiscal e DAS Regular não dependem de entrada global no menu; a linguagem natural deve preservar autenticação, autorização e as regras próprias das jornadas. | Produto e Fiscal |
| Revisão do método de autorização no Telegram | Fluxo e controles aprovados por Segurança/Compliance em 2026-09-12. | Segurança e Compliance |
| Consentimento, autorização e retenção | Condicionam a descoberta sem ampliar coleta indevida; o relato de testes com dados reais não contém evidência versionada de consentimento ou base legal. | Produto, Segurança e Compliance |

## Assumptions e Open Questions

| ID | Question / decision needed | Decision owner | Resolution / evidence | Date | State |
| --- | --- | --- | --- | --- | --- |
| `OQ-OMNI-001` | Qual segmento, canal e método de autorização compõem o primeiro ciclo validável? | Produto | O primeiro ciclo atende clientes finais de micro e pequenas empresas, já cadastrados pelo escritório assinante, pelo Telegram. O Tenant Admin cadastra previamente o celular; ao iniciar o bot, o cliente compartilha um contato por payload estruturado do Telegram; o sistema autoriza somente quando o número corresponde a um contato TELEGRAM previamente cadastrado no mesmo tenant. Número digitado manualmente não é aceito. A comparação entre `contact.user_id` e `message.from.id` não é exigida nesta fase. WhatsApp será implementado depois e não é prioritário neste ciclo. Decisões humanas desta revisão, alinhadas ao fluxo documentado no `REQ-00007`. | 2026-09-11 | Resolved |
| `OQ-OMNI-002` | Qual jornada fiscal terminal compõe o primeiro ciclo? | Produto e Fiscal | O primeiro ciclo funcional pelo Telegram inclui consulta de situação fiscal e geração de DAS Regular. Ambas permanecem acessíveis por linguagem natural mesmo sem função global cadastrada no menu e foram confirmadas pelo owner como funcionais, testadas e validadas em testes técnicos com clientes reais e dados reais; nenhum identificador ou payload foi incorporado a este PRD. Seu comportamento terminal continua governado pelos requisitos e casos de uso fiscais aplicáveis. O cadastro futuro no menu apenas acrescenta descoberta por clique. Decisão humana desta revisão. | 2026-09-11 | Resolved |
| `OQ-OMNI-003` | O que conta como resolução sem atendimento humano? | Produto e Operações | Uma jornada é resolvida sem atendimento humano quando, após o cliente iniciar a conversa, o Telegram conclui a autorização e entrega a situação fiscal ou a DAS Regular sem intervenção do escritório. O cadastro prévio do cliente é precondition e não conta como intervenção; qualquer ajuda manual após o início da conversa descaracteriza a resolução autônoma. Decisão humana desta revisão. | 2026-09-11 | Resolved |
| `OQ-OMNI-005` | Quais requisitos Draft precisam ser fechados antes do primeiro piloto? | Produto e Arquitetura | O ciclo Telegram começa pela estrutura de menu e depois aceita linguagem natural, comportamento já funcional sob a referência arquitetural ativa; nenhuma função global de negócio é inicialmente obrigatória. O recorte atual inclui o fallback seguro quando há zero funções elegíveis e o acesso por linguagem natural a Situação Fiscal e DAS Regular, validado pelo owner. `REQ-00007`, esse recorte de `REQ-00002` e `REQ-00028` são aplicáveis e precisam ser reconciliados e aprovados. `REQ-00001` fica fora por governar o WhatsApp posterior; `REQ-00002 AC-022`–`AC-027` ficam fora por serem evolução futura de funções customizadas/add-on. A auditoria repository-local confirmou que o `REQ-00026` não descreve o sistema atual; ele foi marcado `Deprecated` e substituído pelo `REQ-00041 AC-AUD-050` aprovado e coberto pelo ledger outbound vigente. | 2026-09-11 | Resolved |
| `OQ-OMNI-006` | Nos testes técnicos com clientes e dados reais, os próprios clientes operaram a conversa e avaliaram o resultado, ou a equipe técnica executou usando seus cadastros e dados? | Produto | Os próprios clientes interagiram diretamente com o bot usando dados reais e informaram que a experiência precisava ser mais conversacional. O comportamento foi melhorado depois desse feedback. Nenhuma identidade ou payload foi incorporado ao documento. | 2026-09-11 | Resolved |
| `OQ-OMNI-007` | Após a melhoria que tornou o bot mais conversacional, clientes reais retestaram a experiência e aprovaram o resultado? | Produto | Sim. Os clientes retestaram a versão melhorada e consideraram a experiência adequada. O registro é apenas histórico, não constitui métrica ou gate de validação e não introduz dados identificáveis no PRD. | 2026-09-11 | Resolved |

## Approval

| Role | Accountable party | Decision | Date | Evidence |
| --- | --- | --- | --- | --- |
| Owner | Produto e Operações Omnichannel | Aprovação integral do primeiro ciclo Telegram conforme implementado: boas-vindas no primeiro inbound, validação e solicitação de contato na interação seguinte, autorização tenant-scoped por telefone, menu e linguagem natural, Situação Fiscal e DAS Regular e modo conversacional vigente. | 2026-09-12 | Decisão humana registrada nesta revisão e requisitos REQ-00002 v1.10, REQ-00007 v1.6 e REQ-00028 v1.16; AC-020 foi materializado e testado repository-local/DEV pelo IP-BE-3.2.17-fiscal-report-terminal-publication-serialization, sem alterar WABA ou externalidades. |
| Required reviewer | Segurança/Compliance para autorização, auditoria e dados | Aprovado integralmente, inclusive autorização tenant-scoped por telefone sem comparação entre IDs, expiração lógica, retenção física nesta fase, ciclos renováveis, auditoria e tratamento de dados referenciados. | 2026-09-12 | Aprovação humana explícita registrada nesta revisão. |

## Product Definition Gate

**Product Definition Gate:** `PASS` para `PRD-00002 v1.35`, incluindo o primeiro
ciclo Telegram aprovado e a taxonomia de auditoria repository-local comprovada
em `F-OMNI-007`. `F-OMNI-005` possui 43/43 critérios comprovados no recorte
repository-local/DEV; `F-OMNI-012` possui 16/16 critérios reconciliados e os dois
critérios LLM novos são apenas AC-P3-005/036. O gate e a evidência não certificam
F-OMNI-008/009 integrais, WABA, provider externo nem delivery exactly-once.

## 15. Change log

| Version | Date | Change |
| --- | --- | --- |
| 1.35 | 2026-09-13 | Reconcilia F-OMNI-012 em 16/16 por prova composta repository-local/DEV e registra AC-P3-005 5/5 e AC-P3-036 29/29; preserva F-OMNI-008/009 como parciais, WABA em quarentena e os limites de multithread/restart literal, provider externo e exactly-once. |
| 1.34 | 2026-09-12 | Fecha `F-OMNI-005` em 43/43 critérios repository-local/DEV após o AC-020 passar prova concorrente PostgreSQL normal/diagnóstica, regressões, arquitetura e Quality Gate canônico zero-skip; preserva integralmente a quarentena WABA e não alega provider externo nem delivery/consumer exactly-once. |
| 1.33 | 2026-09-12 | Aprova a definição de `REQ-00028 AC-020` como publicação lógica única ligada ao commit terminal sob dois pollers tenant-scoped, referencia o IP-BE-3.2.17-fiscal-report-terminal-publication-serialization em IRG READY e mantém o critério pendente até código/gates PostgreSQL, sem prometer delivery exactly-once nem alterar a quarentena WABA. |
| 1.32 | 2026-09-12 | Reconcilia `F-OMNI-005` com `REQ-00028 v1.14`: 42/43 critérios possuem evidência DEV no conjunto de 278 testes zero-skip; `AC-020` permanece como hardening concorrente independente, sem afetar a quarentena WABA. |
| 1.31 | 2026-09-12 | Registra a taxonomia de audit cross-channel de `F-OMNI-007` implementada e testada repository-local em 11/11 focais, 29/29 arquiteturais e Quality Gate focal `PASS`; Traffic Inspector e quarentena WABA permanecem independentes. |
| 1.30 | 2026-09-12 | Aprova e liga `REQ-00062`/IP-BE-3.1.20-omnichannel-event-audit-action-taxonomy à `F-OMNI-007` para substituir as duas actions legadas dos listeners cross-channel por taxonomia omnichannel neutra e minimizada; Traffic Inspector e quarentena WABA permanecem independentes. |
| 1.29 | 2026-09-12 | Reconcilia a matriz evidence-first: preserva o primeiro ciclo Telegram implementado/testado e a quarentena WABA, fecha o outbound e o inbound locais, delega os hardenings de retenção ao PRD-00006 e explicita os gaps/decisões restantes de fundação, administração e observabilidade. Também completa `related_files` e alinha o Product Definition Gate à versão corrente. |
| 1.28 | 2026-09-12 | Coloca `F-OMNI-001`/REQ-00001 em quarentena não bloqueante até entendimento e conclusão da configuração WABA, sem reabrir o primeiro ciclo Telegram validado. |
| 1.27 | 2026-09-12 | Promove o PRD a Validated após aprovação integral de Produto e Operações Omnichannel e de Segurança/Compliance; aprova REQ-00002 para o primeiro ciclo Telegram, REQ-00007 e REQ-00028 conforme arquitetura e implementação vigentes. |
| 1.26 | 2026-09-11 | Reconcilia REQ-00007 v1.5 com o comportamento atual aprovado: a terceira solicitação expira o vínculo pendente depois do envio, e interações futuras iniciam novo ciclo sem bloqueio definitivo nem mensagem terminal. |
| 1.25 | 2026-09-11 | Reconcilia REQ-00007 v1.4: tentativas Telegram expiram logicamente sob demanda após 24 horas, sem exclusão ou anonimização automática; o owner aceita a retenção física e o crescimento gradual nesta fase. |
| 1.24 | 2026-09-11 | Expurga da autorização Telegram a comparação entre `contact.user_id` e `message.from.id`; o primeiro ciclo passa a depender somente do payload estruturado e do match tenant-scoped com telefone TELEGRAM previamente cadastrado, conforme decisão do owner e REQ-00007 v1.3. |
| 1.23 | 2026-09-11 | Expurga do ciclo todas as métricas e formas de validação qualitativa/quantitativa, inclusive `M-OMNI-001`–`M-OMNI-005`, instrumentação e telemetria de produto; retira `H-OMNI-003` e `H-OMNI-004`, deixando a fase sem métricas ou hipóteses ativas e preservando os IDs históricos. |
| 1.22 | 2026-09-11 | Expurga `H-OMNI-002`, comparação entre WhatsApp e Telegram, das pendências e dos critérios de validação do ciclo; preserva os IDs remanescentes e o histórico da decisão. |
| 1.21 | 2026-09-11 | Expurga `H-OMNI-001` e a preferência de canal como pendência e critério de validação do ciclo por decisão do owner; preserva os IDs das hipóteses remanescentes e o histórico da decisão. |
| 1.20 | 2026-09-11 | Resolve `OQ-OMNI-007`: clientes retestaram a melhoria conversacional e consideraram a experiência adequada; preserva o caráter qualitativo da evidência e não infere métricas de erro/abandono ou preferência de canal. |
| 1.19 | 2026-09-11 | Registra o feedback dos clientes de que o bot precisava ser mais conversacional e a melhoria já realizada; resolve `OQ-OMNI-006` e abre `OQ-OMNI-007` para confirmar reteste e aprovação da experiência melhorada. |
| 1.18 | 2026-09-11 | Registra que os próprios clientes interagiram diretamente com o bot durante os testes técnicos com dados reais; mantém `OQ-OMNI-006` aberta apenas quanto à avaliação/feedback e não infere preferência ou usabilidade. |
| 1.17 | 2026-09-11 | Qualifica a validação das jornadas como testes técnicos com clientes reais e dados reais, sem incorporar dados sensíveis nem inferir preferência/usabilidade; abre `OQ-OMNI-006` para esclarecer quem operou a conversa e se houve feedback. |
| 1.16 | 2026-09-11 | Incorpora o `REQ-00002 v1.9`: Situação Fiscal e DAS Regular, confirmadas como funcionais, testadas e validadas, permanecem acessíveis por linguagem natural sem função global cadastrada; o menu futuro somente adiciona descoberta por clique. |
| 1.15 | 2026-09-11 | Corrige `F-OMNI-002` e incorpora o `REQ-00002 v1.8`: não existe função global de negócio inicialmente obrigatória; o catálogo será criado gradualmente, e o estado com zero funções elegíveis mantém apenas o controle sistêmico seguro de saída. |
| 1.14 | 2026-09-11 | Separa `F-OMNI-002`, primeiro ciclo Telegram com funções globais já cadastradas, de `F-OMNI-013`, evolução futura gradual de funções customizadas sob add-on; a feature futura deixa de bloquear o primeiro ciclo e não é alegada como implementada. |
| 1.13 | 2026-09-11 | Incorpora o `REQ-00002 v1.6`: o add-on usa capability FLAG e libera quantidade ilimitada de funções customizadas, sem cobrança por unidade; limites técnicos do canal são resolvidos por paginação. |
| 1.12 | 2026-09-11 | Incorpora o `REQ-00002 v1.5`: função customizada sem SERPRO pode ser administrada pelo Tenant Admin no próprio tenant e pelo Super Admin somente sob personificação válida, preservando isolamento, entitlement/RBAC e auditoria do ator real. |
| 1.11 | 2026-09-11 | Incorpora a decisão do `REQ-00002 v1.4`: seções do menu são fixas; seus itens exigem cumulativamente entitlement comercial do tenant, RBAC do perfil e habilitação no canal, sem atribuir ROLE por contratação de add-on. |
| 1.10 | 2026-09-11 | Resolve `OQ-OMNI-005`: a auditoria confirmou que a DLQ do `REQ-00026` não foi implementada nem corresponde ao runtime; deprecia essa referência histórica e passa `F-OMNI-006` à cobertura aprovada do `REQ-00041 AC-AUD-050`, aderente ao ledger sem conteúdo, dispatch fence e reconciliação query-only existentes. |
| 1.9 | 2026-09-11 | Registra que o ciclo Telegram inicia pelo menu e preserva linguagem natural, com comportamento funcional e arquitetura ativa; torna `REQ-00002`, `REQ-00007` e `REQ-00028` aplicáveis à reconciliação, mantendo apenas a decisão sobre `REQ-00026` aberta em `OQ-OMNI-005`. |
| 1.8 | 2026-09-11 | Resolve `OQ-OMNI-003`: resolução autônoma começa após o cliente iniciar a conversa, admite o cadastro prévio como precondition e termina quando Telegram entrega situação fiscal ou DAS Regular sem ajuda manual do escritório. |
| 1.7 | 2026-09-11 | Declara `M-OMNI-001`–`M-OMNI-005` `Not applicable` no ciclo pre-market sem telemetria e resolve `OQ-OMNI-004`; a medição somente reabre por decisão humana explícita antes de futuro piloto ou operação com clientes reais. |
| 1.6 | 2026-09-11 | Resolve `OQ-OMNI-002` com consulta de situação fiscal e geração de DAS Regular no primeiro ciclo Telegram; registra que não haverá telemetria agora e mantém as métricas abertas até aprovação do gatilho de reativação. |
| 1.5 | 2026-09-11 | Resolve `OQ-OMNI-001`: registra o fluxo de autorização Telegram por celular pré-cadastrado e compartilhamento nativo do próprio contato, sem aceitar número digitado; preserva a revisão obrigatória de Segurança/Compliance. |
| 1.4 | 2026-09-11 | Define Telegram, já implementado localmente, como canal do primeiro ciclo validável e reserva WhatsApp para implementação posterior, sem prioridade neste ciclo; método de autorização permanece aberto. |
| 1.3 | 2026-09-11 | Registra a decisão humana sobre o segmento prioritário do primeiro ciclo validável; canal inicial e método de autorização permanecem abertos em `OQ-OMNI-001`. |
