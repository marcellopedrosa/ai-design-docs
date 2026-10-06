---
document_id: "ADR-0048"
primary_nature: "Decisao"
objective: "Fechar `D-11` definindo a fronteira entre faturamento comercial e emissao fiscal, a porta neutra para NFS-e e os gates que impedem operacao fiscal sem dados e evidencias validos."
scope: "Fatura comercial, obrigacao fiscal, NFS-e, rulesets fiscais versionados, integracao entre `contexts.billing` e `contexts.fiscal`, estados de solicitacao fiscal, contingencia, reconciliacao, cancelamento e substituicao."
non_objectives: "Implementar adapter, DDL, OpenAPI, UI ou processo fiscal; determinar obrigacao tributaria concreta; escolher municipio, regime, layout ou provider; atestar dados legais da GV Software; autorizar cobranca paga em producao."
owner: "Fiscal / Financeiro / Billing / Arquitetura"
status: "Accepted"
date: "2026-08-25"
version: "1.2"
keywords: "billing, fatura comercial, NFS-e, fiscal, ruleset, effective-dated, fail-closed, reconciliacao, contingencia, ASAAS"
related_files: "docs/product/requirements/REQ-00042-enterprise-multitenant-billing-invoicing.md`, `docs/product/use-cases/UC-00044-billing-tax-fiscal-documents.md`, `docs/delivery/plans/TP-00013-enterprise-billing-implementation-task-plan.md`, `docs/delivery/plans/implementation_plans/backend/IP-BE-13.7.1-billing-tax-fiscal-documents.md`, `docs/delivery/plans/implementation_plans/frontend/IP-FE-13.7.1-billing-tax-fiscal-documents.md`, `docs/adrs/ADR-0001-technology-stack-and-architecture.md`, `docs/adrs/ADR-0019-database-per-tenant.md`, `docs/adrs/ADR-0023-agnostic-payment-provider-integration.md`, `docs/adrs/ADR-0027-catalogo-global-faturamento-local.md"
code_references: "AS-IS em `backend/src/main/java/br/com/duoset/saas_service/contexts/billing/` e `backend/src/main/java/br/com/duoset/saas_service/contexts/fiscal/`; porta fiscal neutra, adapter e stores descritos neste ADR sao destinos planejados e ainda nao existem."
principal_statement: "Fatura comercial e NFS-e sao entidades e eixos de lifecycle independentes; Billing solicita capacidade fiscal por porta neutra da interface publica de `contexts.fiscal`, com ruleset imutavel e fail-closed, enquanto a automacao NFS-e inicial permanece desligada ate dados, obrigacao, processo e adapter possuirem evidencias de owner competente."
---

# ADR-0048 - Separacao entre fatura comercial e documento fiscal NFS-e

- Document ID: `ADR-0048`
- Primary Nature: `Decisao`
- Objective: Fechar `D-11` definindo a fronteira entre faturamento comercial e emissao fiscal, a porta neutra para NFS-e e os gates que impedem operacao fiscal sem dados e evidencias validos.
- Scope: Fatura comercial, obrigacao fiscal, NFS-e, rulesets fiscais versionados, integracao entre `contexts.billing` e `contexts.fiscal`, estados de solicitacao fiscal, contingencia, reconciliacao, cancelamento e substituicao.
- Non-objectives: Implementar adapter, DDL, OpenAPI, UI ou processo fiscal; determinar obrigacao tributaria concreta; escolher municipio, regime, layout ou provider; atestar dados legais da GV Software; autorizar cobranca paga em producao.
- Keywords: billing, fatura comercial, NFS-e, fiscal, ruleset, effective-dated, fail-closed, reconciliacao, contingencia, ASAAS
- Related Files: `docs/product/requirements/REQ-00042-enterprise-multitenant-billing-invoicing.md`, `docs/product/use-cases/UC-00044-billing-tax-fiscal-documents.md`, `docs/delivery/plans/TP-00013-enterprise-billing-implementation-task-plan.md`, `docs/delivery/plans/implementation_plans/backend/IP-BE-13.7.1-billing-tax-fiscal-documents.md`, `docs/delivery/plans/implementation_plans/frontend/IP-FE-13.7.1-billing-tax-fiscal-documents.md`, `docs/adrs/ADR-0001-technology-stack-and-architecture.md`, `docs/adrs/ADR-0019-database-per-tenant.md`, `docs/adrs/ADR-0023-agnostic-payment-provider-integration.md`, `docs/adrs/ADR-0027-catalogo-global-faturamento-local.md`
- Code References: AS-IS em `backend/src/main/java/br/com/duoset/saas_service/contexts/billing/` e `backend/src/main/java/br/com/duoset/saas_service/contexts/fiscal/`; porta fiscal neutra, adapter e stores descritos neste ADR sao destinos planejados e ainda nao existem.
- Principal Decision: Fatura comercial e NFS-e sao entidades e eixos de lifecycle independentes; Billing solicita capacidade fiscal por porta neutra da interface publica de `contexts.fiscal`, com ruleset imutavel e fail-closed, enquanto a automacao NFS-e inicial permanece desligada ate dados, obrigacao, processo e adapter possuirem evidencias de owner competente.
- Date: 2026-08-25
- Status: Accepted
- Version: 1.2
- Decision Provenance: `AI_DELEGATED`
- Decision Actor: `AI_AGENT — Codex (OpenAI)`
- Authority Basis: `OWNER_DELEGATION — AUTH-BILLING-2026-08-25-001`
- Human Review Status: `NOT_PERFORMED`
- Reviewability: `OPEN`
- Authors: Codex (AI), sob autoridade delegada
- Owners: Fiscal / Financeiro / Billing / Arquitetura
- Reviewers: AI — analise de arquitetura, dominio, seguranca e custo; Human — N/A, nenhuma revisao substantiva desta decisao foi realizada
- Stakeholders: Proprietario do SaaS, GV Software, tenants contratantes, Fiscal, Financeiro, Billing, Backend, Frontend, Seguranca, Suporte e Operacoes
- Supersedes: N/A; especializa ADR-0023 e ADR-0027 sem alterar a neutralidade do provider ou a autoridade tenant-local da fatura.
- Superseded by: N/A

---

# 0. Decision Provenance

| Field | Value |
| --- | --- |
| Normative status | `Accepted` |
| Decision provenance | `AI_DELEGATED` |
| Decision actor | `AI_AGENT — Codex (OpenAI)` |
| Authority holder | Solicitante, declarado proprietario do SaaS; identidade nao verificada criptograficamente pelo repositorio |
| Authority grant | `AUTH-BILLING-2026-08-25-001`, registrada no TP-00013 |
| Authority scope | Escolher e materializar decisoes documentais restantes de Billing a partir de `D-04.4-E` |
| Human substantive review | `NOT_PERFORMED` |
| Reviewability | `OPEN`; revisao humana pode ratificar, emendar ou superseder sem apagar a origem IA |
| Excluded attestations | Identidade/dados legais, obrigacao e enquadramento fiscais, municipio, cadastro municipal, provider/layout, Sandbox, producao, parecer juridico/contabil e implementacao |

`Accepted` indica vigencia normativa sob a autoridade delegada; nao representa
aprovacao humana, parecer fiscal ou prontidao operacional. A provenance
`AI_DELEGATED` e historica e nao deve ser substituida por autoria humana em uma
ratificacao futura.

---

# 1. Context

O Hub Contabil emite uma fatura comercial da GV Software contra o tenant. Esse
artefato descreve a obrigacao contratual e o valor a cobrar, mas nao comprova por
si so a emissao de um documento fiscal. Fundir os dois lifecycles faria uma falha
municipal reabrir uma invoice financeira, permitiria tratar um PDF comercial como
NFS-e e tornaria o provider de pagamento autoridade tributaria.

O projeto ainda nao entrou em producao, opera como monolito modular em uma unica
VPS e nao possui, no repositorio, atestacao completa dos dados fiscais da seller,
da obrigacao concreta, do municipio competente ou de um adapter NFS-e certificado.
A arquitetura pode ser fechada agora; fatos regulados e prontidao operacional nao
podem ser inventados por IA.

---

# 2. Decision Statement

## 2.1 Eixos e autoridades independentes

O sistema deve manter dois aggregates correlacionados, mas independentes:

| Eixo | Autoridade | Conteudo |
| --- | --- | --- |
| Fatura comercial | `contexts.billing`, banco dedicado do tenant | seller, payer, linhas, descontos, impostos informativos quando comprovados, total, vencimento, status de collection e artefatos comerciais |
| Documento fiscal | `contexts.fiscal`, por sua interface publica | solicitacao fiscal, ruleset aplicado, payload fiscal, protocolo, numero fiscal, autorizacao/rejeicao, XML/PDF oficial, cancelamento/substituicao e evidencias |

Uma invoice pode existir sem NFS-e quando o estado fiscal explicito assim indicar.
Numero comercial e numero fiscal pertencem a sequencias distintas e nunca sao
copiados, reutilizados ou apresentados como equivalentes. Pagamento nao converte
automaticamente uma invoice em documento fiscal autorizado; autorizacao fiscal
tambem nao confirma recebimento financeiro.

## 2.2 Boundary Clean Architecture

`contexts.billing` publica uma intencao fiscal imutavel e chama somente uma porta
neutra exposta pela interface publica de `contexts.fiscal`. O dominio de Billing
nao importa SDK, DTO, status ou erro de ASAAS, prefeitura ou padrao nacional.

O adapter fiscal concreto fica atras de `contexts.fiscal`; nao sera criado novo
microservico, banco, broker ou workflow engine no primeiro horizonte. A troca de
provider fiscal nao altera aggregates de invoice nem casos de uso de Billing. A
comunicacao usa contratos versionados, outbox/inbox e idempotencia, sem join, FK ou
transacao distribuida entre stores.

## 2.3 Intencao e lifecycle fiscal

Cada intencao fiscal sela, no minimo, `tenantId` opaco, `sellerLegalEntityId`,
`commercialInvoiceId`, revisao, hash do snapshot, periodos, moeda, valores em minor
units, identidade/hash do ruleset, purpose e chave idempotente. PII e dados fiscais
seguem minimizacao e nao transitam em evento ou log alem do estritamente exigido.

Estados normalizados minimos:

| Estado | Semantica |
| --- | --- |
| `NOT_REQUESTED` | Nenhuma emissao foi solicitada; estado default da primeira release. |
| `REVIEW_REQUIRED` | Obrigacao, dados, capability ou ruleset nao estao comprovados; efeito externo bloqueado. |
| `READY` | Pre-condicoes e approval aplicaveis estao satisfeitos. |
| `SUBMISSION_PENDING` | Command duravel existe, mas o efeito externo ainda nao tem desfecho. |
| `AUTHORIZED` | Fonte fiscal autenticada confirmou autorizacao e artefatos oficiais foram correlacionados. |
| `REJECTED` | Fonte fiscal rejeitou de forma conclusiva, preservando codigo/reason sanitizado. |
| `UNKNOWN` | Timeout ou resposta ambigua exige reconciliacao antes de retry. |
| `CANCELLATION_PENDING` | Cancelamento autorizado foi solicitado e aguarda desfecho. |
| `CANCELED` | Fonte fiscal confirmou cancelamento. |
| `SUBSTITUTED` | Um novo documento autorizado referencia causalmente o anterior. |

Estados fiscais nunca sao inferidos de redirect, tela, PDF local, status da
cobranca ou resposta nao autenticada.

## 2.4 Rulesets fiscais

Uma `FiscalRuleSetVersion` e tipada, effective-dated, versionada, imutavel depois
de publicada e selada por schema + canonical hash. Ela identifica as condicoes que
selecionam o processo, campos obrigatorios, validacoes, arredondamento e capacidades
permitidas, sem executar script, SQL ou expressao fornecida por usuario.

Selecao ausente, ambigua, fora da vigencia, com hash divergente ou com campo
obrigatorio nao comprovado resulta em `REVIEW_REQUIRED`. Nao existe fallback para
valor fiscal hardcoded, cadastro de outro tenant, resposta anterior ou configuracao
`latest`. Publicacao, revogacao e aplicacao produzem trilha append-only.

## 2.5 Capability inicial diferida

Na primeira release com ASAAS:

- automacao de NFS-e fica `OFF` por default;
- invoices nascem com eixo fiscal `NOT_REQUESTED` ou `REVIEW_REQUIRED`, nunca com
  emissao presumida;
- ASAAS como provider de pagamento nao implica ASAAS como provider fiscal;
- ambiente pago de producao fica bloqueado ate o owner Fiscal documentar a
  obrigacao aplicavel e um processo manual valido, ou certificar um adapter;
- feature flag so pode ser ligada depois de dados, layout, Sandbox, reconciliacao,
  cancelamento/substituicao, seguranca e ownership passarem seus gates.

Um processo manual valido precisa manter correlacao, evidencia, segregacao de
funcoes e upload/referencia verificavel dos artefatos oficiais; ele nao pode ser
representado por simples alteracao administrativa de status.

## 2.6 Pending Evidence e Owner Attestation

A IA deliberadamente nao decide nem preenche:

- razao social, nome fantasia, CNPJ, endereco e municipio da GV Software;
- inscricao municipal, regime tributario e enquadramentos;
- codigo/lista de servico, CNAE, aliquotas e retencoes;
- municipio competente, layout, endpoint ou provider fiscal;
- prazos e condicoes de emissao, cancelamento ou substituicao;
- regras concretas de IBS/CBS ou outra incidencia;
- credenciais, certificados, series, numeracao oficial ou ambientes externos.

Cada item permanece `PENDING_EVIDENCE` e requer `OWNER_ATTESTATION` de responsavel
Fiscal/Contabil/Juridico apropriado, com fonte, vigencia e data de revisao. Isso e
uma pendencia de evidencia, nao uma decisao arquitetural aberta para a IA.

## 2.7 Reconciliacao, retry e contingencia

Toda mutacao fiscal segue persist-before-call. Resultado `UNKNOWN` congela nova
submissao com a mesma obrigacao ate consulta/reconciliacao por referencia estavel.
Retry somente reutiliza a identidade logica quando a semantica externa o permite;
uma substituicao usa nova identidade e elo causal.

Contingencia nao autoriza fabricar XML/PDF oficial, numero, protocolo, autorizacao
ou data retroativa. Artefato local deve ser rotulado como comercial ou rascunho,
nunca como NFS-e. Cancelamento e substituicao so executam quando ruleset, prazo,
capability, estado externo e approval estiverem comprovados; falha fecha o fluxo
em review, sem editar ou apagar o documento anterior.

## 2.8 Boundary da aprovacao

`D-11` fica fechado arquiteturalmente. OpenAPI, DDL, adapters, dados legais,
rulesets concretos, obrigacao por jurisdicao, homologacao, testes e operacao
continuam como trabalho/evidencia futura. Esta ADR isolada nao libera
implementacao; a autorização humana separada registrou `D-00 =
RELEASED_WITH_SCOPE — HUMAN_EXPLICIT — TP-00013 local-only`.

---

# 3. Decision Drivers

- impedir confusao entre documento comercial e fiscal;
- falhar de forma segura diante de regra tributaria ausente ou ambigua;
- preservar auditabilidade, idempotencia e causalidade;
- manter dominio desacoplado de provider e municipio;
- respeitar Clean Architecture e Spring Modulith existentes;
- evitar novo servico e custo operacional na VPS;
- permitir processo manual valido sem declarar automacao inexistente;
- impedir que IA invente atestacoes legais ou contabeis.

---

# 4. Considered Options

## Option A - Eixos separados, porta fiscal neutra e capability diferida

Pros: separa autoridades, reduz lock-in, falha fechada, preserva custo e permite
evolucao segura.

Cons: exige reconciliacao entre eixos, owner fiscal e gates antes de producao.

## Option B - Tratar a invoice comercial como NFS-e

Rejected: produz representacao juridicamente enganosa, mistura numeracao e nao
possui autoridade fiscal.

## Option C - Delegar todo o lifecycle fiscal ao provider de pagamento

Rejected: acopla Billing, presume capabilities e nao elimina responsabilidade por
dados, obrigacao, reconciliacao ou contingencia.

---

# 5. Decision Outcome

A **Option A** foi selecionada pela IA sob delegacao. Ela fecha uma arquitetura
extensivel sem alegar que a operacao fiscal esta homologada. O custo permanece no
monolito modular e nos bancos existentes; a complexidade regulatoria fica isolada
em `contexts.fiscal` e condicionada a evidencia competente.

---

# 6. Consequences

## Positive Consequences

- Invoice e NFS-e podem evoluir e falhar independentemente.
- Provider fiscal pode mudar sem contaminar o dominio de Billing.
- Ausencia de fato regulatorio bloqueia efeito, em vez de aplicar default perigoso.
- Reconciliacao evita duplicidade em resultado ambiguo.
- Trilha deixa claro o que foi decidido por IA e o que requer owner humano.

## Negative Consequences

- A release inicial nao automatiza NFS-e.
- Operacao paga depende de trabalho fiscal externo ao codigo.
- Dois eixos exigem UI, suporte e monitoramento explicitos.

## Neutral Consequences

- Processo manual pode ser aceitavel somente se validado pelo owner competente.
- Estados e nomes finais de API/DDL serao congelados no plano de implementacao.

---

# 7. Impact

- Architecture: uma porta publica de Fiscal, sem nova aresta alem da dependencia ja declarada.
- Billing: preserva invoice/collection tenant-local e publica somente intencao fiscal.
- Fiscal: torna-se owner do lifecycle, ruleset, adapter e artefato fiscal.
- Security: minimizacao, approvals, idempotencia, reconciliacao e fail-closed.
- Operations: filas `REVIEW_REQUIRED`/`UNKNOWN`, runbook e alertas serao necessarios.
- Cost: nenhum microservico, broker ou banco adicional no primeiro horizonte.

---

# 8. AI Agent Considerations

Agentes devem preservar `AI_DELEGATED`, nunca preencher `PENDING_EVIDENCE`, nunca
tratar `Accepted` como parecer fiscal e nunca habilitar provider, Sandbox ou
producao com base apenas neste ADR. Diante de ambiguidade regulatoria, devem manter
`REVIEW_REQUIRED` e encaminhar ao owner competente.

---

# 9. Implementation Plan Boundary

1. obter owner attestations e inventario fiscal valido;
2. congelar contratos neutros, schemas, states e reason codes;
3. modelar rulesets e lifecycle puros em `contexts.fiscal`;
4. criar stores append-only, inbox/outbox e command journal;
5. implementar processo manual rastreavel ou adapter certificado;
6. integrar Billing somente pela interface publica de Fiscal;
7. validar rejeicao, timeout, retry, reconciliacao, cancelamento e substituicao;
8. habilitar por flag apenas apos materializar o ADR-0050 e comprovar os gates do
   ADR-0051.

A implementação hermética local pode avançar sob a liberação escopada de `D-00`;
nenhuma etapa externa foi iniciada por este ADR. Os ADRs-0050/0051 foram aceitos por IA sob
`AUTH-BILLING-2026-08-25-001`, com revisao humana `NOT_PERFORMED`/`OPEN`, mas isso
nao comprova implementacao, SLO, backup, Sandbox ou readiness.

---

# 10. Validation

- uma invoice comercial nunca e rotulada como NFS-e;
- numero/status comercial e fiscal permanecem independentes;
- ruleset ausente, ambiguo ou stale resulta em `REVIEW_REQUIRED`;
- Billing nao importa SDK/status de provider fiscal;
- `UNKNOWN` exige reconcile antes de retry;
- cancelamento/substituicao preservam causalidade e artefatos anteriores;
- ausencia de owner attestation mantem automacao e producao bloqueadas;
- testes de contrato/Modulith provam a fronteira Billing -> interface publica Fiscal;
- validacao documental e indices passam no conjunto integrado.

Testes executaveis nao foram criados porque esta mudanca e exclusivamente
documental e nao implementa comportamento.

---

# 11. Risks and Mitigations

| Risk | Mitigation |
| --- | --- |
| Documento comercial ser confundido com fiscal | Entidades, numeracao, labels e estados separados. |
| Regra tributaria errada ser aplicada | Ruleset versionado + owner attestation + fail-closed. |
| Timeout gerar NFS-e duplicada | Persist-before-call + `UNKNOWN` + reconcile-before-retry. |
| Provider contaminar o dominio | Porta neutra e adapter atras de `contexts.fiscal`. |
| Processo manual perder rastreabilidade | Correlacao, evidencia e SoD obrigatorias. |
| IA criar falsa certeza regulatoria | Campos explicitamente `PENDING_EVIDENCE`; revisao humana aberta. |
| Custo crescer prematuramente | Monolito modular, stores e outbox existentes. |

---

# 12. Related ADRs

- [ADR-0000 - Governanca documental](../../harness/governance/decisions/ADR-0000-governanca-do-harness-documental.md)
- [ADR-0001 - Stack e arquitetura](ADR-0001-technology-stack-and-architecture.md)
- [ADR-0019 - Database-per-tenant](ADR-0019-database-per-tenant.md)
- [ADR-0023 - Provider-neutral payments](ADR-0023-agnostic-payment-provider-integration.md)
- [ADR-0027 - Catalogo global e faturamento local](ADR-0027-catalogo-global-faturamento-local.md)
- [ADR-0046 - Correcao, cancelamento e reemissao](ADR-0046-correcao-cancelamento-reemissao-fatura.md)
- [ADR-0049 - Subledger tenant-local e MRR](ADR-0049-subledger-tenant-local-mrr-normalizado.md)
- [ADR-0050 - RBAC, SoD e aprovacoes](ADR-0050-rbac-sod-aprovacoes-financeiras.md)
- [ADR-0051 - SLO, capacidade e rollout](ADR-0051-slo-capacidade-rollout-billing.md)

---

# 13. References

- [REQ-00042](../product/requirements/REQ-00042-enterprise-multitenant-billing-invoicing.md)
- [UC-00044](../product/use-cases/UC-00044-billing-tax-fiscal-documents.md)
- [TP-00013](../delivery/plans/TP-00013-enterprise-billing-implementation-task-plan.md)
- [Module Registry](../architecture/module-registry.md)

---

# 14. Decision Lifecycle

Current State: **Accepted - AI_DELEGATED**.

Ratificacao humana futura pode validar dados e politica ou superseder a decisao,
mas deve preservar a provenance. Alteracao material da separacao de eixos, porta,
fail-closed ou boundary de responsabilidade exige nova versao aceita ou ADR
sucessor.

`D-12` a `D-14` estao aceitos nos ADR-0049 a ADR-0051 com a mesma provenance
delegada e revisao humana aberta. Dados/pareceres, Sandbox, piloto e produção
continuam pendentes/fail-closed; `D-00` libera somente implementação local TP-00013.

---

# 15. Change Log

| Version | Date | Author | Changes |
| --- | --- | --- | --- |
| 1.2 | 2026-08-25 | Solicitante humano, proprietário declarado / Codex (IA), materialização | Registra `D-00 = RELEASED_WITH_SCOPE — HUMAN_EXPLICIT — TP-00013 local-only`; permite implementação/DDL/OpenAPI/testes herméticos locais e mantém chamadas externas, automação fiscal, Sandbox ASAAS, piloto BP Farias, produção, flags `ON` e efeitos reais bloqueados. |
| 1.1 | 2026-08-25 | Codex (IA), sob `AUTH-BILLING-2026-08-25-001` | Reconcilia ADRs-0049–0051 como `AI_DELEGATED`, revisao humana `NOT_PERFORMED`/`OPEN`; mantém atestacoes fiscais e readiness como evidencias pendentes e `D-00` ativo. |
| 1.0 | 2026-08-25 | Codex (IA), sob `AUTH-BILLING-2026-08-25-001` | Fecha autonomamente `D-11` com invoice/NFS-e separadas, porta Fiscal neutra, ruleset fail-closed, automacao inicial OFF e fatos regulados como `PENDING_EVIDENCE`; revisao humana substantiva nao realizada. |

---

# 16. Repository Structure

Este ADR cria somente documentacao. Alvos planejados permanecem em
`contexts.billing` e `contexts.fiscal`, respeitando suas interfaces publicas e
camadas domain/application/adapters.

---

# 17. Review Process

Revisao humana permanece aberta. Ratificacao deve registrar ator, competencia,
data, fontes e escopo, sem apagar a origem IA. Atestacoes fiscais sao evidencias
separadas e nao devem ser adicionadas sem verificacao do owner competente.

---

# 18. Notes

Uma invoice explica o que a GV Software cobra do tenant. Uma NFS-e registra um
fato fiscal conforme autoridade competente. Correlacao nao significa identidade.
