---
document_id: PRD-00004
primary_nature: Requisito
objective: Definir a intenção, os resultados e o gate de validação das Operações Fiscais.
scope: Certificados, integração SERPRO, situação fiscal, relatórios, mensagens, dashboard, emissão e lifecycle de DAS, conciliação, documentos e visibilidade operacional.
non_objectives: Repetir acceptance criteria, detalhar fluxos fiscais, decidir arquitetura ou provider, interpretar legislação, autori
ar produção ou afirmar conformidade externa não demonstrada.
owner: Produto Fiscal e Operações Fiscais
status: Validated
version: 1.15
date: 2026-09-11
last_reviewed: 2026-09-13
keywords: prd, fiscal, serpro, sitfis, pgdasd, das, certificado, relatorio, conciliacao
related_files: docs/product/requirements/README.md, projects/backend/docs/prds/PRD-00003-tenant-platform-lifecycle.md, docs/product/business/product-vision.md, docs/product/requirements/REQ-00005-plan-feature-matrix.md, docs/product/requirements/REQ-00009-serpro-apoiar-protocolo-relatorio.md, docs/product/requirements/REQ-00010-serpro-emitir-relatorio-pdf.md, docs/product/requirements/REQ-00016-serpro-das-regular-emission.md, docs/product/requirements/REQ-00033-phase2-fiscal-serpro-operations.md, docs/product/requirements/REQ-00038-serpro-traffic-inspector-diagnostic.md, docs/product/requirements/REQ-00057-tenant-dashboard-fiscal-overview.md, docs/product/use-cases/UC-00001-dashboard-view.md, docs/product/use-cases/UC-00006-configuracao-integracao-serpro.md, docs/product/use-cases/UC-00007-solicitacao-relatorio-situacao-fiscal.md, docs/product/use-cases/UC-00019-emissao-das-serpro.md, docs/product/use-cases/UC-00030-phase2-fiscal-operations.md, docs/architecture/omnichannel-conversational-function-lifecycle.md, docs/api_contracts/dashboard-fiscal-overview-v1.openapi.yaml, docs/delivery/plans/implementation_plans/backend/IP-BE-2.3.4-fiscal-adapters.md, docs/delivery/plans/implementation_plans/backend/IP-BE-2.3.10-serpro-traffic-inspector.md, docs/delivery/plans/implementation_plans/backend/IP-BE-2.3.14-fiscal-business-zone-default.md, docs/delivery/plans/implementation_plans/backend/IP-BE-2.3.15-das-regular-future-date-guard.md, docs/delivery/plans/implementation_plans/backend/IP-BE-2.3.16-das-regular-request-tag-contract.md, docs/delivery/plans/implementation_plans/backend/IP-BE-2.3.17-das-regular-http200-business-outcome-contract.md, docs/delivery/plans/implementation_plans/backend/IP-BE-3.2.17-fiscal-report-terminal-publication-serialization.md, docs/delivery/plans/implementation_plans/frontend/IP-FE-3.2.8.1-serpro-external-cost-warning-evidence.md
code_references: backend/src/main/resources/application.yml, backend/src/main/java/br/com/duoset/saas_service/contexts/dashboard/internal/infrastructure/config/DashboardFiscalTimeConfiguration.java, backend/src/main/java/br/com/duoset/saas_service/contexts/omnichannel/internal/application/service/toolcall/DasToolCallHandler.java, backend/src/main/java/br/com/duoset/saas_service/contexts/fiscal/internal/infrastructure/adapters/serpro/SerproRegularDasEmitterAdapter.java, backend/src/test/java/br/com/duoset/saas_service/contexts/fiscal/internal/infrastructure/adapters/serpro/SerproRegularDasEmitterAdapterTest.java, backend/src/test/java/br/com/duoset/saas_service/contexts/fiscal/internal/infrastructure/persistence/SerproRequestLogRepositoryPostgresTest.java, backend/src/test/java/br/com/duoset/saas_service/contexts/omnichannel/internal/application/service/toolcall/DasToolCallHandlerConsolidationDateTest.java, frontend/src/mocks/data/dashboard.ts
principal_statement: O escritório deve consultar, emitir, acompanhar e comprovar serviços fiscais com resultado compreensível, documentos íntegros e operação segura por empresa atendida.
---

# PRD-00004 — Operações Fiscais e DAS

## 1. Executive summary

A automação fiscal é a proposta de valor central da visão do produto. O acervo
abrange certificados, autenticação SERPRO, situação fiscal, relatório PDF,
catálogos de mensagens, dashboard e DAS regular por `GERARDAS12`.
`DARF_GENERATION` não possui mapeamento no negócio e não integra este PRD.

Parte da situação fiscal possui requisitos aceitos ou implementados localmente.
O primeiro ciclo validado preserva o fluxo síncrono vigente de Situação Fiscal/PDF
e emissão explícita de DAS Regular por `GERARDAS12`; roteamento entre modalidades,
consulta prévia de elegibilidade e as demais modalidades permanecem fora do ciclo.

## Problema e evidência

### Problem statement

Escritórios precisam consultar obrigações e entregar documentos fiscais de forma
repetível, porém integrações externas, certificados, modalidades, mensagens e
desfechos incertos tornam a jornada manual, sujeita a erro e difícil de auditar.
O cliente precisa de resultado compreensível; o contador precisa de integridade,
rastreabilidade e segurança para confiar na automação.

### Evidence currently available

| Evidence | What it supports | Limitation |
| --- | --- | --- |
| [Visão do produto](../business/product-vision.md) | SERPRO, situação fiscal e emissão de guias compõem o valor central. | Não aprova o recorte executável do primeiro ciclo. |
| [REQ-00008](../requirements/REQ-00008-serpro-authentication.md)–[REQ-00010](../requirements/REQ-00010-serpro-emitir-relatorio-pdf.md) | Autenticação, protocolo e relatório fiscal possuem definição documental; REQ-00009 v1.7 e REQ-00010 v1.4 estão Approved, com os critérios concorrentes implementados/testados repository-local/DEV. | A evidência hermética não prova operação SERPRO externa. |
| [REQ-00033](../requirements/REQ-00033-phase2-fiscal-serpro-operations.md) | Baseline consolidada de operações fiscais/SERPRO. | É baseline AS-IS, não resultado de produto. |
| [REQ-00016 v1.10](../requirements/REQ-00016-serpro-das-regular-emission.md) e [REQ-00021](../requirements/REQ-00021-das-lifecycle-reissuance-idempotency.md)–[REQ-00025](../requirements/REQ-00025-das-integration-testing-strategy.md) | Emissão regular síncrona, lifecycle, documento, resultado desconhecido, segurança e testes do primeiro ciclo. | Doze critérios do adapter Regular e três critérios temporais possuem evidência repository-local/DEV; o restante mantém implementação e Quality Gate próprios. |
| [REQ-00038 v1.2](../requirements/REQ-00038-serpro-traffic-inspector-diagnostic.md), [UC-00006 v1.8](../use-cases/UC-00006-configuracao-integracao-serpro.md), [IP-BE-2.3.10-serpro-traffic-inspector](../../delivery/plans/implementation_plans/backend/IP-BE-2.3.10-serpro-traffic-inspector.md) e [IP-FE-3.2.8.1-serpro-external-cost-warning-evidence](../../delivery/plans/implementation_plans/frontend/IP-FE-3.2.8.1-serpro-external-cost-warning-evidence.md) | `AC-SERPRO-DIAG-004/005/008/010/012` estão implementados/testados repository-local/DEV: response replayable, isolamento tenant, exclusão do scheduler/comercial, histórico redigido no modal e aviso pré-GERARDAS12. | Não certifica operação SERPRO nem `AC-001–003/006/007/009/011`; o conflito de resultado `UNKNOWN`/revisão manual continua fora. |
| [REQ-00057](../requirements/REQ-00057-tenant-dashboard-fiscal-overview.md), contrato [Dashboard Fiscal Overview v1](../../../docs/api_contracts/dashboard-fiscal-overview-v1.openapi.yaml) e [REQ-00060](../requirements/REQ-00060-fiscal-llm-tab-super-admin-impersonation.md) | Baseline BASIC e visões fiscais implementadas e testadas no repositório; `getFiscalOverview` possui contrato ativo próprio. | A ampliação de roles e os indicadores ADVANCED ainda possuem implementação própria pendente. |

Não foi localizada evidência de operação real com o SERPRO; este fato permanece
como limitação operacional, não como métrica de validação do produto.

## Público e contexto

| Audience | Need / job | Expected value |
| --- | --- | --- |
| Contador responsável | Consultar situação e emitir documentos para empresas da carteira. | Menor esforço com resultado íntegro e rastreável. |
| Escritório assinante / Tenant Admin | Configurar pré-condições e acompanhar operação fiscal. | Controle e previsibilidade por tenant. |
| Cliente final autorizado | Receber resposta e documento fiscal compreensíveis. | Menos espera sem perda de segurança. |
| Super Admin / Operações | Diagnosticar integrações e apoiar exceções. | Resolução mais rápida sem acesso irrestrito. |
| Auditor / Compliance | Verificar origem, acesso, retenção e resultado. | Evidência governada e separação de responsabilidades. |

## Outcomes e não-objetivos

> Outcomes quantitativos de tempo, qualidade, cobertura e garantia não são aplicáveis ao escopo MVP.


1. Permitir conclusão confiável das jornadas fiscais priorizadas.
2. Tratar exceções e resultado desconhecido sem reexecução automática.
3. Entregar mensagens e documentos coerentes entre interfaces autorizadas.
4. Dar ao escritório visibilidade de situação, andamento, falha e pagamento.
5. Aplicar capacidades e quotas comerciais de forma determinística por tenant.

### Non-goals

- Emitir parecer fiscal ou interpretar legislação.
- Aprovar credenciais, certificados, endpoints ou acesso externo por este PRD.
- Definir topologia, storage, protocolo, retry, modelo LLM ou tecnologia.
- Declarar todas as modalidades de DAS prontas enquanto os requisitos estão `Draft`.
- Duplicar o comportamento dos requisitos ou fluxos dos casos de uso.

## 5. Product scope and limits

### In scope

- custódia e lifecycle percebido de certificados;
- autenticação e disponibilidade da integração fiscal;
- situação fiscal, protocolo e relatório PDF;
- mensagens públicas coerentes para PGDAS-D e SITFIS;
- dashboard e visibilidade operacional autorizada;
- emissão de DAS regular exclusivamente por `GERARDAS12` no primeiro ciclo;
- lifecycle, reemissão segura, resultado desconhecido e entrega do DAS regular;
- integridade, entrega, resiliência e auditabilidade dos documentos;
- piloto controlado das jornadas fiscais selecionadas.

O primeiro ciclo não depende de `REQ-00012`–`REQ-00015`: a fundação e a API
assíncrona propostas não representam o fluxo síncrono vigente, e a emissão regular
não consulta snapshot PGDAS-D nem roteia modalidades. Também não depende de
`REQ-00017`–`REQ-00020`, que governam Cobrança, Processo, Avulso e conciliação.

Decisão humana de 2026-09-12: o contador definiu `GERARDAS12` como a única
modalidade DAS do escopo ativo. `REQ-00012`–`REQ-00015` e `REQ-00017`–`REQ-00020`,
assim como `F-FIS-010`–`F-FIS-012` e `F-FIS-014`–`F-FIS-017`, ficam em quarentena
documental não bloqueante e podem nunca ser implementados. Reativação exige nova
decisão humana de produto, revisão das fontes afetadas e aprovação/readiness
próprios; sua existência histórica em `Draft` não bloqueia o ciclo `GERARDAS12`.

### Advanced Dashboard exclusivo do PREMIUM

O `ADVANCED_DASHBOARD` deve complementar, para tenants do plano PREMIUM, os
indicadores do Dashboard básico com três visualizações analíticas de tamanho médio:

1. **Resultados das consultas fiscais no mês:** gráfico de pizza com a distribuição
   das consultas entre sucesso, erro e pendente no mês civil atual, conforme a zona
   do tenant. Erro usa identificação visual vermelha; sucesso e pendente devem ser
   distinguíveis visualmente e por texto, sem depender somente de cor.
2. **Cobertura de consultas da carteira no mês:** gráfico de pizza que compara os
   clientes ativos com pelo menos uma consulta fiscal no mês civil atual com os
   clientes ativos sem consulta no mesmo período, conforme a zona do tenant.
3. **Top 5 clientes por consultas fiscais:** gráfico de pizza com os cinco clientes
   que concentram o maior número de consultas fiscais em todo o histórico do tenant,
   usando o nome do cliente como label e desempate alfabético.

As três visualizações são tenant-scoped e exclusivas do `ADVANCED_DASHBOARD`; não
integram o `BASIC_DASHBOARD` de START ou BUSINESS. Estados vazios, acessibilidade,
contrato de dados, autorização por entitlement e demais comportamentos observáveis
devem ser definidos em requisito próprio antes da implementação.

### Out of scope for this validation cycle

- NFS-e, folha, obrigações não documentadas ou novos provedores fiscais;
- produção, dados reais, credenciais ou certificados reais;
- DAS Cobrança (`GERARDASCOBRANCA17`), Processo, Avulso e outras modalidades;
- `DARF_GENERATION` e fluxos de DARF sem requisito de negócio aprovado;
- canal conversacional, coberto pelo PRD-00002;
- arquitetura ou contratos técnicos das integrações.

## 6. Product validation criteria

O PRD somente pode mudar para `Validated` quando Produto Fiscal e Operações
registrarem evidência versionada de:

- segmento, serviço fiscal e modalidade do primeiro ciclo;
- definição de sucesso terminal, exceção e encaminhamento humano;
- resolução das perguntas `OQ-FIS-*`;
- requisitos do ciclo inicial em estado compatível com a fase seguinte;
- aprovação obrigatória de Segurança/Compliance e responsável fiscal.

Esses são critérios de validação do produto; os critérios funcionais permanecem
somente nos requisitos linkados.

zado; START `15`, BUSINESS `500`, PREMIUM conforme contrato;
- somente retorno confirmado como sucesso consome uma unidade; falha, timeout,
  ausência de PDF e diagnóstico do Traffic Inspector não consomem;
- Situação Fiscal concluída com PDF e `GERARDAS12` concluído consomem uma unidade;
- reset no primeiro dia do mês civil na zona do tenant; esgotamento bloqueia até o reset;
- a zona fiscal aprovada para decisões de calendário deste ciclo é `America/Recife`;
- `BASIC_DASHBOARD` atende START/BUSINESS; `ADVANCED_DASHBOARD` atende PREMIUM,
  que recebe o BASIC real, sem mocks, acrescido dos três indicadores analíticos
  definidos na Seção 5;
- `MGMT_CERTIFICATES` existe em todos os planos: vários certificados podem
  permanecer no histórico, mas somente um pode estar vigente por tenant.

## Métricas

Não aplicável ao escopo MVP; métricas de tempo, qualidade, cobertura e garantia ficam fora desta fase.

## Product Hypotheses

Não há hipóteses de produto ativas neste PRD. As hipóteses anteriores baseadas em
métricas de tempo, qualidade, quantidade ou comportamento foram expurgadas. As
decisões operacionais aprovadas são:

- Situação Fiscal termina com PDF útil; sem PDF, orientar nova solicitação mais
  tarde, sem atendimento humano e sem retry automático.
- Em resultado ambíguo de DAS, alertar que a tentativa anterior pode ter sido
  processada e exigir confirmação explícita antes de outra solicitação.
- Todos os perfis autenticados do tenant visualizam os KPIs permitidos pelo plano;
  Super Admin somente sob personificação; contatos externos não acessam Dashboard.
- O BASIC usa dados reais de clientes ativos, validade do certificado, consultas
  fiscais no mês, interações WhatsApp/chatbot, total de mensagens, evolução de
  Situação Fiscal/DAS e movimentações recentes. Valores simulados são proibidos.

## Features e mapa de requirements

| Requirement | Contribution | Current documentary state |
| --- | --- | --- |
| [REQ-00008](../requirements/REQ-00008-serpro-authentication.md) | Autenticação M2M SERPRO. | Accepted. |
| [REQ-00009](../requirements/REQ-00009-serpro-apoiar-protocolo-relatorio.md) | Protocolo de relatório fiscal. | Approved v1.7; AC-010 implementado/testado repository-local/DEV pelo IP-BE-3.2.17-fiscal-report-terminal-publication-serialization. |
| [REQ-00010](../requirements/REQ-00010-serpro-emitir-relatorio-pdf.md) | Emissão/captura do relatório PDF. | Approved v1.4; AC-009/AC-014 implementados/testados repository-local/DEV pelo IP-BE-3.2.17-fiscal-report-terminal-publication-serialization. |
| [REQ-00016](../requirements/REQ-00016-serpro-das-regular-emission.md) | Emissão síncrona e explícita de DAS Regular por `GERARDAS12`. | Approved v1.10; AC-001/002/003/004/005/006/007/009/011/016/017/018 e AC-023/024/025 implementados/testados repository-local/DEV. |
| [REQ-00021](../requirements/REQ-00021-das-lifecycle-reissuance-idempotency.md)–[REQ-00025](../requirements/REQ-00025-das-integration-testing-strategy.md) | Lifecycle, documento, resultado desconhecido, segurança e testes. | Approved para o primeiro ciclo; implementação permanece sujeita aos gates próprios. |
| [REQ-00012](../requirements/REQ-00012-das-clean-architecture-foundation.md)–[REQ-00015](../requirements/REQ-00015-serpro-pgdasd-declaration-query.md) | Fundação futura, orquestração assíncrona, roteamento e consulta PGDAS-D. | Fora do primeiro ciclo validado. |
| [REQ-00017](../requirements/REQ-00017-serpro-das-collection-emission.md)–[REQ-00020](../requirements/REQ-00020-das-payment-reconciliation.md) | Cobrança, Processo, Avulso e conciliação. | Fora do primeiro ciclo validado. |
| [REQ-00032](../requirements/REQ-00032-phase2-certificate-lifecycle-security.md) | Lifecycle e segurança do certificado. | Approved. |
| [REQ-00033](../requirements/REQ-00033-phase2-fiscal-serpro-operations.md) | Baseline consolidada Fiscal/SERPRO. | Approved — AS-IS baseline. |
| [REQ-00038](../requirements/REQ-00038-serpro-traffic-inspector-diagnostic.md) | Diagnóstico sanitizado das integrações. | Approved v1.2; AC-SERPRO-DIAG-004/005/008/010/012 implementados/testados repository-local/DEV, demais critérios mantêm gates próprios. |
| [REQ-00039](../requirements/REQ-00039-pgdasd-message-catalog.md) | Catálogo de mensagens PGDAS-D. | Implemented. |
| [REQ-00040](../requirements/REQ-00040-serpro-sitfis-message-catalog.md) | Catálogo de mensagens SITFIS. | Implemented. |
| [REQ-00057](../requirements/REQ-00057-tenant-dashboard-fiscal-overview.md) | Visão fiscal do escritório. | Baseline BASIC e default fiscal implementados repository-local; `getFiscalOverview` Active 1.0.0; ampliação ADVANCED pendente. |
| [REQ-00060](../requirements/REQ-00060-fiscal-llm-tab-super-admin-impersonation.md) | Extração LLM na visão fiscal personificada. | Implemented repository-local. |

Os acceptance criteria permanecem exclusivamente nesses requisitos.

### 9.1 Feature inventory and acceptance coverage

| Feature ID | Product feature / audience outcome | Requirements | Canonical acceptance coverage | Documentary state |
| --- | --- | --- | --- | --- |
| `F-01` | Cadastrar, acompanhar, renovar e revogar certificado do escritório. | [REQ-00032](../requirements/REQ-00032-phase2-certificate-lifecycle-security.md) | [REQ-00032 AC-CERT-001–AC-CERT-032](../requirements/REQ-00032-phase2-certificate-lifecycle-security.md#7-acceptance-criteria) | Approved. |
| `F-02` | Autenticar o tenant para executar serviços fiscais autorizados no SERPRO. | [REQ-00008](../requirements/REQ-00008-serpro-authentication.md) | [REQ-00008 AC-001–AC-008](../requirements/REQ-00008-serpro-authentication.md#7-acceptance-criteria) | Accepted. |
| `F-03` | Solicitar e acompanhar protocolo de situação fiscal. | [REQ-00009](../requirements/REQ-00009-serpro-apoiar-protocolo-relatorio.md) | [REQ-00009 AC-001–AC-015](../requirements/REQ-00009-serpro-apoiar-protocolo-relatorio.md#7-acceptance-criteria) | Implemented/tested repository-local/DEV no limite comprovado por REQ-00009 v1.7. AC-010 passou com uma chamada ao provider, um commit terminal e uma publicação lógica sob dois pollers; outro tenant obteve vazio. Não certifica operação SERPRO externa. |
| `F-04` | Emitir, capturar e entregar relatório fiscal em PDF. | [REQ-00010](../requirements/REQ-00010-serpro-emitir-relatorio-pdf.md) | [REQ-00010 AC-001–AC-014](../requirements/REQ-00010-serpro-emitir-relatorio-pdf.md#7-acceptance-criteria) | Implemented/tested repository-local/DEV no limite comprovado por REQ-00010 v1.4. AC-009/AC-014 passaram no fluxo normal com publicação lógica `1` e no diagnóstico com evento `0`; não há garantia de provider externo nem delivery exactly-once. |
| `F-05` | Operar a baseline integrada de certificados, SERPRO, situação e DAS. | [REQ-00033](../requirements/REQ-00033-phase2-fiscal-serpro-operations.md) | [REQ-00033 AC-FIS-001–AC-FIS-028](../requirements/REQ-00033-phase2-fiscal-serpro-operations.md#8-acceptance-criteria) | Approved — AS-IS baseline. |
| `F-06` | Diagnosticar interações SERPRO por visão sanitizada e tenant-scoped. | [REQ-00038](../requirements/REQ-00038-serpro-traffic-inspector-diagnostic.md) | [REQ-00038 AC-SERPRO-DIAG-001–AC-SERPRO-DIAG-012](../requirements/REQ-00038-serpro-traffic-inspector-diagnostic.md#9-acceptance-criteria) | Approved v1.2; AC-SERPRO-DIAG-004/005/008/010/012 implementados/testados repository-local/DEV. AC-SERPRO-DIAG-001–003/006/007/009/011 mantêm evidências e gates próprios; a feature inteira não é promovida. |
| `F-07` | Comunicar outcomes PGDAS-D de forma consistente nas interfaces. | [REQ-00039](../requirements/REQ-00039-pgdasd-message-catalog.md) | [REQ-00039 AC-PGDASD-001–AC-PGDASD-009](../requirements/REQ-00039-pgdasd-message-catalog.md#7-acceptance-criteria) | Implemented. |
| `F-08` | Comunicar outcomes SITFIS e tempo de espera de forma consistente. | [REQ-00040](../requirements/REQ-00040-serpro-sitfis-message-catalog.md) | [REQ-00040 AC-SITFIS-001–AC-SITFIS-018](../requirements/REQ-00040-serpro-sitfis-message-catalog.md#8-acceptance-criteria) | Implemented. |
| `F-09` | Visualizar a situação agregada da carteira e movimentações recentes. | [REQ-00057](../requirements/REQ-00057-tenant-dashboard-fiscal-overview.md) | [REQ-00057 AC-001–AC-016 e AC-024](../requirements/REQ-00057-tenant-dashboard-fiscal-overview.md#7-acceptance-criteria) | Baseline BASIC e default fiscal `America/Recife` implementados e testados repository-local pelo IP-BE-2.3.14-fiscal-business-zone-default; roles adicionais e ADVANCED mantêm gates próprios. |
| `F-10` | Consultar declaração e histórico PGDAS-D antes da ação fiscal. | [REQ-00015](../requirements/REQ-00015-serpro-pgdasd-declaration-query.md) | [REQ-00015 AC-001–AC-015](../requirements/REQ-00015-serpro-pgdasd-declaration-query.md#7-acceptance-criteria) | Quarantined — fora do escopo ativo e não bloqueante. |
| `F-11` | Solicitar emissão de DAS por uma jornada interna coerente e rastreável. | [REQ-00012](../requirements/REQ-00012-das-clean-architecture-foundation.md), [REQ-00013](../requirements/REQ-00013-das-issuance-orchestration.md) | [REQ-00012 AC-001–AC-015](../requirements/REQ-00012-das-clean-architecture-foundation.md#7-acceptance-criteria); [REQ-00013 AC-001–AC-018](../requirements/REQ-00013-das-issuance-orchestration.md#7-acceptance-criteria) | Quarantined — fora do escopo ativo e não bloqueante. |
| `F-12` | Determinar a modalidade elegível antes de emitir a guia. | [REQ-00014](../requirements/REQ-00014-das-eligibility-routing.md) | [REQ-00014 AC-001–AC-015](../requirements/REQ-00014-das-eligibility-routing.md#7-acceptance-criteria) | Quarantined — fora do escopo ativo e não bloqueante. |
| `F-13` | Emitir DAS Regular para solicitação explícita e precondições locais válidas. | [REQ-00016](../requirements/REQ-00016-serpro-das-regular-emission.md) | [REQ-00016 AC-001–AC-025](../requirements/REQ-00016-serpro-das-regular-emission.md#7-acceptance-criteria) | Approved v1.11; AC-001/002/003/004/005/006/007/008/009/011/016/017/018 e AC-023/024/025 possuem evidência repository-local/DEV. AC-010/012–015/019–022 mantêm gates próprios; a feature inteira não é promovida. |
| `F-14` | Emitir DAS Cobrança para intenção elegível. | [REQ-00017](../requirements/REQ-00017-serpro-das-collection-emission.md) | [REQ-00017 AC-001–AC-021](../requirements/REQ-00017-serpro-das-collection-emission.md#7-acceptance-criteria) | Quarantined — fora do escopo ativo e não bloqueante. |
| `F-15` | Emitir DAS de Processo para intenção elegível. | [REQ-00018](../requirements/REQ-00018-serpro-das-process-emission.md) | [REQ-00018 AC-001–AC-020](../requirements/REQ-00018-serpro-das-process-emission.md#7-acceptance-criteria) | Quarantined — fora do escopo ativo e não bloqueante. |
| `F-16` | Emitir DAS Avulso para intenção elegível. | [REQ-00019](../requirements/REQ-00019-serpro-das-ad-hoc-emission.md) | [REQ-00019 AC-001–AC-023](../requirements/REQ-00019-serpro-das-ad-hoc-emission.md#7-acceptance-criteria) | Quarantined — fora do escopo ativo e não bloqueante. |
| `F-17` | Consultar e conciliar pagamento de DAS. | [REQ-00020](../requirements/REQ-00020-das-payment-reconciliation.md) | [REQ-00020 AC-001–AC-017](../requirements/REQ-00020-das-payment-reconciliation.md#7-acceptance-criteria) | Quarantined — fora do escopo ativo e não bloqueante. |
| `F-18` | Acompanhar lifecycle, reemissão e repetição segura da mesma intenção. | [REQ-00021](../requirements/REQ-00021-das-lifecycle-reissuance-idempotency.md) | [REQ-00021 AC-001–AC-026](../requirements/REQ-00021-das-lifecycle-reissuance-idempotency.md#7-acceptance-criteria) | Approved; implementação integral pendente. |
| `F-19` | Preservar integridade, retenção e entrega do documento DAS. | [REQ-00022](../requirements/REQ-00022-das-document-storage-delivery.md) | [REQ-00022 AC-001–AC-031](../requirements/REQ-00022-das-document-storage-delivery.md#7-acceptance-criteria) | Approved; implementação integral pendente. |
| `F-20` | Conter timeout e resultado desconhecido sem reemissão cega. | [REQ-00023](../requirements/REQ-00023-das-resilience-unknown-outcome.md) | [REQ-00023 AC-001–AC-020](../requirements/REQ-00023-das-resilience-unknown-outcome.md#7-acceptance-criteria) | Approved; implementação integral pendente. |
| `F-21` | Auditar e observar a jornada DAS sem expor conteúdo sensível. | [REQ-00024](../requirements/REQ-00024-das-observability-audit-security.md) | [REQ-00024 AC-001–AC-025](../requirements/REQ-00024-das-observability-audit-security.md#7-acceptance-criteria) | Approved; implementação integral pendente. |
| `F-22` | Qualificar a jornada DAS por testes herméticos e operação externa somente quando autorizada. | [REQ-00025](../requirements/REQ-00025-das-integration-testing-strategy.md) | [REQ-00025 AC-001–AC-022](../requirements/REQ-00025-das-integration-testing-strategy.md#7-acceptance-criteria) | Approved; execução do Quality Gate pendente. |
| `F-23` | Consultar extração estruturada de relatório sob personificação autorizada. | [REQ-00060](../requirements/REQ-00060-fiscal-llm-tab-super-admin-impersonation.md) | [REQ-00060 AC-001–AC-005](../requirements/REQ-00060-fiscal-llm-tab-super-admin-impersonation.md#acceptance-criteria) | Implemented repository-local. |
| `F-24` | Permitir que o Tenant Admin PREMIUM compreenda a distribuição mensal de sucesso, erro e pendência das consultas fiscais. | [REQ-00057](../requirements/REQ-00057-tenant-dashboard-fiscal-overview.md) | [REQ-00057 AC-020 e AC-023](../requirements/REQ-00057-tenant-dashboard-fiscal-overview.md#7-acceptance-criteria) | Approved; implementação pendente. |
| `F-25` | Permitir que o Tenant Admin PREMIUM identifique a cobertura mensal de consultas entre os clientes ativos da carteira. | [REQ-00057](../requirements/REQ-00057-tenant-dashboard-fiscal-overview.md) | [REQ-00057 AC-021 e AC-023](../requirements/REQ-00057-tenant-dashboard-fiscal-overview.md#7-acceptance-criteria) | Approved; implementação pendente. |
| `F-26` | Permitir que o Tenant Admin PREMIUM identifique os cinco clientes com maior volume histórico de consultas fiscais. | [REQ-00057](../requirements/REQ-00057-tenant-dashboard-fiscal-overview.md) | [REQ-00057 AC-022 e AC-023](../requirements/REQ-00057-tenant-dashboard-fiscal-overview.md#7-acceptance-criteria) | Approved; implementação pendente. |

As faixas indicam cobertura documental. `REQ-00039` e `REQ-00040` receberam IDs
estáveis sem mudança do comportamento implementado.

## 10. Use cases and decisions by reference

- Operações fiscais consolidadas: [UC-00030](../use-cases/UC-00030-phase2-fiscal-operations.md).
- Configuração/diagnóstico SERPRO: [UC-00006](../use-cases/UC-00006-configuracao-integracao-serpro.md).
- Situação fiscal e PDF: [UC-00007](../use-cases/UC-00007-solicitacao-relatorio-situacao-fiscal.md).
- Emissão de DAS: [UC-00019](../use-cases/UC-00019-emissao-das-serpro.md) e
  [UC-00023](../use-cases/UC-00023-frontend-das-cobranca.md).
- Extração fiscal: [UC-00010](../use-cases/UC-00010-extracao-llm-situacao-fiscal.md).
- Decisões: selecionar Fiscal, Segurança e Resiliência pelo
  [índice de ADRs](../../adrs/README.md); este PRD não as redefine.

## 11. Current phase assessment

| Dimension | Observed state | Product implication |
| --- | --- | --- |
| Product vision | Automação fiscal com SERPRO e guias é o valor central declarado. | Primeiro ciclo de Situação Fiscal/PDF e DAS Regular validado. |
| Functional definition | Situação fiscal e o conjunto mínimo de DAS Regular estão aprovados; demais modalidades continuam Draft e fora do ciclo. | Progressão permitida somente após readiness dos paths e versões aplicáveis. |
| Repository implementation | Dashboard, catálogos, extração, adapter Regular, cálculo de amanhã e guarda da data manual do GERARDAS12, default fiscal `America/Recife`, serialização terminal da Situação Fiscal, isolamento do Traffic Inspector e aviso pré-execução possuem evidência local. | IP-BE-2.3.4-fiscal-adapters e IP-BE-2.3.10-serpro-traffic-inspector reconciliam somente os critérios literalmente demonstrados pelos testes DEV; nenhum deles prova jornada externa real ou promove as features integrais. |
| External operation | Credenciais, certificados e operação SERPRO real não foram autorizados nem demonstrados. | Não há evidência de confiabilidade externa. |
| Product decision | O primeiro ciclo e as regras comerciais foram definidos. | Permite reconciliar os requisitos do recorte selecionado. |

## 12. Dependencies and product risks

| Item | Impact | Owner |
| --- | --- | --- |
| Jornada/modalidade inicial | Sem prioridade, não há coorte, target ou piloto finito. | Produto Fiscal |
| Requisitos DAS fora do primeiro ciclo | Permanecem `Draft` e não autorizam Cobrança, Processo, Avulso, conciliação ou nova API assíncrona. | Produto, Fiscal e Arquitetura |
| Dependência SERPRO/certificado | Condiciona prova real e disponibilidade. | Operações e Segurança |
| Integridade e responsabilidade fiscal | Erro pode afetar obrigação e confiança profissional. | Fiscal e Compliance |
| Implementação do `ADVANCED_DASHBOARD` | A definição e os ACs estão aprovados, mas contrato, código e testes ainda exigem plano/readiness próprios. | Produto Fiscal e Arquitetura |
| Regressão do default fiscal | Alteração futura pode voltar a divergir `application.yml`, Dashboard e o handler GERARDAS12. | Backend e Qualidade; testes herméticos do IP-BE-2.3.14-fiscal-business-zone-default protegem default, override e fronteira civil. |

## Assumptions e Open Questions

| ID | Question / decision needed | Decision owner | State |
| --- | --- | --- | --- |
| `OQ-FIS-001` | Situação Fiscal/PDF e DAS regular `GERARDAS12`, em todos os planos e tenants elegíveis. | Produto Fiscal | Resolved 2026-09-11 |
| `OQ-FIS-002` | PDF/sucesso confirmado é terminal; sem atendimento humano ou retry automático. | Fiscal e Operações | Resolved 2026-09-11 |
| `OQ-FIS-003` | O primeiro ciclo usa `REQ-00008`–`REQ-00010`, `REQ-00016`, `REQ-00021`–`REQ-00025`, `REQ-00032`, `REQ-00033`, `REQ-00039`, `REQ-00040`, `REQ-00057` e `REQ-00060`; os demais requisitos DAS permanecem fora do ciclo. | Produto Fiscal e Arquitetura | Resolved 2026-09-12 |
| `OQ-FIS-004` | Métricas de tempo, qualidade, quantidade e comportamento foram expurgadas. | Produto e Fiscal | Removed 2026-09-11 |
| `OQ-FIS-005` | A fronteira proposta foi expurgada; a plataforma apoia atividades do contador. | Fiscal e Compliance | Removed 2026-09-11 |
| `OQ-FIS-006` | Transferida aos próprios REQ-00039/REQ-00040; não bloqueia o produto. | Produto Fiscal e Documentação | Transferred 2026-09-11 |
| `OQ-FIS-007` | Os três gráficos de pizza são exclusivos do `ADVANCED_DASHBOARD`; resultados e cobertura usam o mês civil do tenant, resultados incluem sucesso/erro/pendente, cobertura considera clientes ativos e o Top 5 usa todo o histórico com label pelo nome e desempate alfabético. | Owner humano do produto | Resolved 2026-09-12 |

## Approval

| Role | Accountable party | Decision | Date | Evidence |
| --- | --- | --- | --- | --- |
| Owner | Produto Fiscal e Operações Fiscais | Validated para problema, público, objetivos, limites, features e conjunto mínimo do primeiro ciclo. | 2026-09-12 | Aprovação humana explícita das decisões 1–7 e do conjunto revisado. |
| Required reviewer | Responsável Fiscal e Segurança/Compliance | Approved para integridade documental, proteção de dados, ausência de retry cego e validação documental sem operação com dados reais. | 2026-09-12 | Aprovação humana explícita com representação dos reviewers obrigatórios. |

## Product Definition Gate

**Product Definition Gate:** `PASS` para o PRD-00004 v1.14 e somente para o
primeiro ciclo explicitamente delimitado. Implementação, contratos, readiness,
integração externa e Quality Gate continuam independentes. O recorte concorrente
de F-FIS-003/F-FIS-004 está implementado e testado repository-local/DEV pelo
IP-BE-3.2.17-fiscal-report-terminal-publication-serialization, com PostgreSQL e
Quality Gate zero-skip. Em F-FIS-006, AC-SERPRO-DIAG-004/005/008/010 possuem
evidência DEV reconciliada pelo IP-BE-2.3.10-serpro-traffic-inspector e
AC-SERPRO-DIAG-012 pelo IP-FE-3.2.8.1-serpro-external-cost-warning-evidence; os
testes focais de replay, HTTP/tenant, PostgreSQL, scheduler,
projeção comercial e migration passaram respectivamente `5/5`, `5/5`, `3/3`,
`1/1`, `7/7` e `2/2`, todos zero-skip. A evidência frontend preservada passou
impactada `9/9`, build Webpack `54/54` e Quality Gate focused `5/5`. Nenhuma
quarentena DAS foi reativada, e o
conflito GERARDAS12 entre timeout/resultado `UNKNOWN` e revisão manual permanece
fora deste crédito.

Em `F-FIS-013`, os relatórios DEV atuais de
`SerproRegularDasEmitterAdapterTest` (`16/16`),
`SerproApiAdapterDasBridgeTest` (`1/1`) e
`FiscalTelemetryPrivacyCanaryTest` (`2/2`) creditam somente
REQ-00016 AC-001/002/003/004/005/006/007/009/011/016/017/018. O crédito temporal anterior
de AC-023/024/025 permanece. O recorte `X-Request-Tag` passou também impactada
`18/18`, arquitetura `29/29` e Quality Gate focused `47/47`, todos zero-skip.
O recorte HTTP/envelope `200` com `MSG_ISN_070` passou focal `16/16`, impactada
`19/19`, arquitetura `29/29` e Quality Gate focused `48/48`, todos zero-skip e
somente com WireMock local. AC-008/010/012–015/019–022, emissão externa,
feature integral, quarentenas e conflito UNKNOWN/manual continuam fora.

## 15. Change log

| Version | Date | Change |
| --- | --- | --- |
| `1.15` | `2026-09-13` | Fecha somente `F-FIS-013`/REQ-00016 AC-008 pelo IP-BE-2.3.18-das-regular-response-alias-contract após focal `17/17`; prova alias `detalhamento` com mock local e preserva feature integral, provider, mTLS, quarentenas e UNKNOWN/manual. |
| `1.14` | `2026-09-13` | Fecha somente `F-FIS-013`/REQ-00016 AC-006 pelo IP-BE-2.3.17-das-regular-http200-business-outcome-contract após focal `16/16`, impactada `19/19`, arquitetura `29/29` e Quality Gate focused `48/48`, zero-skip; preserva feature integral, provider, mTLS, quarentenas e UNKNOWN/manual. |
| `1.13` | `2026-09-12` | Fecha somente `F-FIS-013`/REQ-00016 AC-004 pelo IP-BE-2.3.16-das-regular-request-tag-contract após focal `15/15`, impactada `18/18`, arquitetura `29/29` e Quality Gate focused `47/47`, zero-skip; preserva feature integral, provider, mTLS, quarentenas e UNKNOWN/manual. |
| `1.12` | `2026-09-12` | Reconcilia 14 falsos pendentes com evidência DEV atual: em `F-FIS-013`, somente REQ-00016 AC-001/002/003/005/007/009/011/016/017/018 após `12/12 + 1/1 + 2/2`; em `F-FIS-006`, somente REQ-00038 AC-SERPRO-DIAG-004/005/008/010 após provas focais, PostgreSQL, scheduler, projeção comercial, migration e UI zero-skip. Não promove features integrais, provider, quarentenas ou conflito UNKNOWN/manual. |
| `1.11` | `2026-09-12` | Fecha somente `F-FIS-013`/REQ-00016 AC-025 repository-local/DEV pelo `IP-BE-2.3.15-das-regular-future-date-guard`: focal `4/4`, impactada `30/30`, regressão adicional `41/41`, arquitetura `29/29` e QG focused `59/59`, zero-skip e zero provider; preserva AC-001–022, feature integral, quarentenas e conflito UNKNOWN/manual. |
| `1.10` | `2026-09-12` | Fecha somente `F-FIS-006`/`REQ-00038 AC-SERPRO-DIAG-012` repository-local/DEV pelo `IP-FE-3.2.8.1-serpro-external-cost-warning-evidence`: aviso pt-BR pré-GERARDAS12 passou focal `5/5`, impactada `9/9`, build Webpack sanitizado `54/54` e Quality Gate focused `5/5`, zero-skip e zero mutation/provider. Preserva AC-001–011, conflito `UNKNOWN`/manual, externalidade e todas as quarentenas DAS. |
| `1.9` | `2026-09-12` | Fecha o recorte concorrente de `F-FIS-003`/`F-FIS-004` repository-local/DEV após REQ-00009 AC-010 e REQ-00010 AC-009/AC-014 passarem prova PostgreSQL normal/diagnóstica e Quality Gate canônico zero-skip; preserva GERARDAS12, o conflito timeout/manual e todas as quarentenas DAS, sem alegar provider externo ou delivery exactly-once. |
| `1.8` | `2026-09-12` | Promove REQ-00009 v1.6 e REQ-00010 v1.3 a Approved, fecha a definição de serialização terminal fiscal no IP-BE-3.2.17-fiscal-report-terminal-publication-serialization READY e mantém os ACs concorrentes abertos até código/teste PostgreSQL; preserva GERARDAS12 e todas as quarentenas DAS sem promessa de delivery exactly-once. |
| `1.7` | `2026-09-12` | Registra o slice `FIS-TZ-DEFAULT-B` como implementado e testado repository-local: default `America/Recife`, override preservado e fronteiras BASIC/GERARDAS12 cobertas, sem reativar as sete features DAS em quarentena. |
| `1.6` | `2026-09-12` | Reconcilia o default fiscal aprovado com o slice atômico `FIS-TZ-DEFAULT-B`, liga `getFiscalOverview` ao contrato Active próprio e preserva separadamente as pendências de roles/ADVANCED e todas as quarentenas DAS. |
| `1.5` | `2026-09-12` | Registra `GERARDAS12` como única modalidade ativa e coloca `REQ-00012`–`REQ-00015`, `REQ-00017`–`REQ-00020` e `F-FIS-010`–`F-FIS-012`/`F-FIS-014`–`F-FIS-017` em quarentena documental não bloqueante. |
| `1.4` | `2026-09-12` | Valida o primeiro ciclo síncrono de Situação Fiscal/PDF e DAS Regular, fixa `America/Recife`, resolve OQ-FIS-003, aprova os indicadores PREMIUM e registra aprovação de Produto, Fiscal e Segurança/Compliance. |
| `1.3` | `2026-09-12` | Define os três indicadores analíticos exclusivos do `ADVANCED_DASHBOARD` PREMIUM, registra as decisões de período, estados, população e ranking e abre a dependência do requisito específico. |
