---
document_id: "ADR-0049"
primary_nature: "Decisao"
objective: "Fechar `D-12` definindo o subledger gerencial de Billing, sua autoridade tenant-local e uma metrica MRR/ARR reproduzivel para o primeiro horizonte."
scope: "Journal append-only, partidas dobradas, posting intents, reversoes, BRL, projecao analitica global, MRR, ARR, expansion, contraction, churn, autorizacao de rotas e capabilities contabeis diferidas."
non_objectives: "Implementar codigo, DDL, OpenAPI, UI, data warehouse, ERP ou plano de contas; definir reconhecimento estatutario de receita, fechamento contabil oficial, cambio, multi-moeda ou parecer contabil."
owner: "Billing / Financeiro / Dados / Arquitetura"
status: "Accepted"
date: "2026-08-25"
version: "1.2"
keywords: "billing subledger, double-entry, journal, tenant-local, MRR, ARR, churn, expansion, contraction, analytics, outbox, BRL"
related_files: "README.md, ../../../docs/specs/TP-00013-enterprise-billing-implementation-task-plan.md, ../specs/IP-BE-13.8.1-billing-financial-close-reporting.md, ../../../frontend/docs/specs/IP-FE-13.8.1-billing-financial-close-reporting.md, ADR-0019-database-per-tenant.md, ADR-0027-catalogo-global-faturamento-local.md, ADR-0038-pricing-tipado-moeda-cadencia.md, ADR-0044-lifecycle-contratual-proration-assinaturas.md"
code_references: "Destinos planejados em `app/src/main/java/br/com/duoset/saas_service/contexts/billing/` para domain/application/ports/adapters de subledger e analytics; rotas administrativas e tenant-scoped finais ainda nao existem e dependem de OpenAPI aprovado."
principal_statement: "Billing tera subledger gerencial append-only, tenant-local, double-entry e BRL-only dentro do monolito/DB existentes; MRR v1 sera derivado de revisoes contratuais recorrentes pre-tax e analytics global sera uma projecao minimizada por outbox, nunca um scan cross-tenant ou livro contabil estatutario."
---

# ADR-0049 - Subledger tenant-local e MRR normalizado

- Document ID: `ADR-0049`
- Primary Nature: `Decisao`
- Objective: Fechar `D-12` definindo o subledger gerencial de Billing, sua autoridade tenant-local e uma metrica MRR/ARR reproduzivel para o primeiro horizonte.
- Scope: Journal append-only, partidas dobradas, posting intents, reversoes, BRL, projecao analitica global, MRR, ARR, expansion, contraction, churn, autorizacao de rotas e capabilities contabeis diferidas.
- Non-objectives: Implementar codigo, DDL, OpenAPI, UI, data warehouse, ERP ou plano de contas; definir reconhecimento estatutario de receita, fechamento contabil oficial, cambio, multi-moeda ou parecer contabil.
- Keywords: billing subledger, double-entry, journal, tenant-local, MRR, ARR, churn, expansion, contraction, analytics, outbox, BRL
- Related Files: `docs/product/requirements/REQ-00042-enterprise-multitenant-billing-invoicing.md`, `docs/product/use-cases/UC-00045-billing-financial-close-reporting.md`, `../../../docs/specs/TP-00013-enterprise-billing-implementation-task-plan.md`, `../specs/IP-BE-13.8.1-billing-financial-close-reporting.md`, `../../../frontend/docs/specs/IP-FE-13.8.1-billing-financial-close-reporting.md`, `ADR-0019-database-per-tenant.md`, `ADR-0027-catalogo-global-faturamento-local.md`, `ADR-0038-pricing-tipado-moeda-cadencia.md`, `ADR-0044-lifecycle-contratual-proration-assinaturas.md`
- Code References: Destinos planejados em `app/src/main/java/br/com/duoset/saas_service/contexts/billing/` para domain/application/ports/adapters de subledger e analytics; rotas administrativas e tenant-scoped finais ainda nao existem e dependem de OpenAPI aprovado.
- Principal Decision: Billing tera subledger gerencial append-only, tenant-local, double-entry e BRL-only dentro do monolito/DB existentes; MRR v1 sera derivado de revisoes contratuais recorrentes pre-tax e analytics global sera uma projecao minimizada por outbox, nunca um scan cross-tenant ou livro contabil estatutario.
- Date: 2026-08-25
- Status: Accepted
- Version: 1.2
- Decision Provenance: `AI_DELEGATED`
- Decision Actor: `AI_AGENT — Codex (OpenAI)`
- Authority Basis: `OWNER_DELEGATION — AUTH-BILLING-2026-08-25-001`
- Human Review Status: `NOT_PERFORMED`
- Reviewability: `OPEN`
- Authors: Codex (AI), sob autoridade delegada
- Owners: Billing / Financeiro / Dados / Arquitetura
- Reviewers: AI — analise de arquitetura, dominio, seguranca e custo; Human — N/A, nenhuma revisao substantiva desta decisao foi realizada
- Stakeholders: Proprietario do SaaS, GV Software, tenants, Billing, Financeiro, Produto, Dados, Backend, Frontend, Seguranca e Operacoes
- Supersedes: N/A; especializa ADR-0027, ADR-0038 e ADR-0044 no eixo gerencial/analitico.
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
| Excluded attestations | Plano de contas, politica contabile, reconhecimento de receita, ERP, fiscalidade, numeros reais, fechamento oficial, capacidade medida e implementacao |

`Accepted` registra vigencia normativa por delegacao, nao revisao humana ou
conformidade contabil. O subledger aqui decidido e gerencial e sua origem
`AI_DELEGATED` permanece registrada mesmo apos ratificacao futura.

---

# 1. Context

Invoice, pagamento, credito, refund e disputa geram efeitos diferentes e nao podem
ser reduzidos a um unico status ou saldo mutavel. Ao mesmo tempo, a operacao em
database-per-tenant nao permite calcular receita global consultando todos os bancos
a cada dashboard. O projeto precisa de trilha reconciliavel e indicadores
comerciais sem antecipar um ERP, warehouse ou servico contabil incompatível com o
custo inicial da VPS.

MRR tambem precisa de uma definicao unica. Somar invoices pagas, usar valor atual
do provider ou incluir uso variavel produz numeros nao comparaveis e mistura
contrato, caixa e receita reconhecida.

---

# 2. Decision Statement

## 2.1 Autoridade e placement do subledger

Cada banco dedicado de tenant contem um subledger de Billing append-only. Ele e
um slice interno de `contexts.billing`, no mesmo monolito modular e PostgreSQL
existentes, sem novo servico, database, broker ou warehouse.

O subledger registra efeitos logicos/gerenciais de contratos, invoices,
pagamentos, allocations, credit/debit memos, refunds, disputes, chargebacks e
write-offs. Ele nao substitui os aggregates que originaram esses fatos e nao se
torna autoridade do provider, do documento fiscal ou do entitlement.

## 2.2 Invariantes double-entry

Cada `PostingBatch` deve:

- possuir ID, tenant, currency, effectiveAt, recordedAt, source type/ID/revision,
  reason, policy/hash, idempotency key/fingerprint e causal predecessor;
- conter no minimo duas entries e soma de debitos igual a soma de creditos em
  minor units;
- ser persistido atomically com outbox dentro de uma transacao tenant-local;
- ficar imutavel depois de `POSTED`;
- ser corrigido somente por reversal e novo batch causal, nunca update/delete;
- impedir reuse de chave com fingerprint divergente;
- preservar valores inteiros em minor units, sem `float`;
- usar accounts logicas tipadas e versionadas, nunca string livre.

O primeiro slice e `BRL_ONLY`. Todo batch contem uma unica moeda `BRL`; entries de
moedas diferentes nao podem balancear entre si. FX e multi-moeda ficam desligados.

## 2.3 Natureza gerencial, nao estatutaria

Os postings representam intents e movimentos gerenciais necessarios para
reconciliar Billing. Nomes logicos como receivable, collected cash, unapplied cash,
credit liability, refund pending e provider clearing nao constituem plano de
contas oficial, lancamento contabil estatutario ou politica de reconhecimento de
receita.

Export para razao oficial, mapeamento de contas, competencia, diferimento,
reconhecimento, impostos contabilizados e fechamento hard dependem de contador e
owner Financeiro. Ate essa ratificacao, interfaces e relatorios devem exibir
`MANAGEMENT_BILLING_SUBLEDGER`, nao `GENERAL_LEDGER` ou equivalente.

## 2.4 Periodos e fechamento

O subledger suporta `OPEN`, `SOFT_CLOSED` e `HARD_CLOSE_DISABLED`. `SOFT_CLOSED`
impede posting retroativo comum, mas aceita compensacao no primeiro periodo aberto
com referencia ao periodo de origem. Reopen exige fluxo de aprovacao do ADR-0050.

`HARD_CLOSE`, fechamento estatutario e lock irreversivel ficam `OFF` enquanto nao
existirem politica contabil, owner, runbook e testes de restauracao/reconciliacao.
Nenhum close apaga entry, altera effectiveAt ou reaproveita sequence.

## 2.5 Definicao canonica de MRR v1

`MRR_V1` e o valor recorrente contratado, pre-tax, vigente em um instante de
observacao, normalizado para um mes. A fonte e a revisao contratual/snapshot
tenant-local aceito, nunca invoice paga, saldo, evento do provider ou caixa.

Regras fechadas:

| Componente | Tratamento em `MRR_V1` |
| --- | --- |
| Base recorrente mensal | Inclui o valor integral mensal contratado. |
| Base recorrente anual | Inclui `annualRecurringAmount / 12`, com precisao decimal e rounding somente na apresentacao/agregacao definida. |
| Add-on recorrente | Inclui enquanto contratado e vigente. |
| Desconto recorrente contratado | Reduz MRR durante sua vigencia; preserva valor bruto e desconto separadamente. |
| One-time/setup/off-cycle | Exclui. |
| Usage e overage | Exclui, mesmo quando frequentes. |
| Impostos | Exclui. |
| Credit memo, refund e write-off | Exclui; afetam outros indicadores, nao reescrevem contrato. |
| Provider fees | Exclui. |
| Juros, multa e desconto por antecipacao | Exclui. |
| Prepaid, wallet ou unapplied cash | Exclui. |

Contrato mensal usa integral do recurring amount; anual usa divisao por 12, sem
inferir dias do mes. Cadencias futuras exigem `MonthlyNormalizationPolicyVersion`
explicita. Trial gratuito e contrato nao ativado contribuem zero. Contrato
cancelado contribui ate seu effective end exclusivo e zero depois dele.

## 2.6 ARR e movimentos de MRR

`ARR_V1 = 12 * MRR_V1`. Movimentos sao derivados da diferenca entre revisoes
contratuais consecutivas no mesmo lineage/effective boundary:

| Movimento | Regra |
| --- | --- |
| `NEW_MRR` | Zero para valor positivo na primeira ativacao paga. |
| `EXPANSION_MRR` | Delta positivo de contrato ja ativo. |
| `CONTRACTION_MRR` | Valor absoluto do delta negativo, ainda acima de zero. |
| `CHURNED_MRR` | MRR positivo para zero por cancelamento/expiracao efetivos. |
| `REACTIVATED_MRR` | Zero para positivo em novo lineage correlacionado como reativacao. |

Uma alteracao nunca pode ser classificada em dois movimentos para o mesmo delta.
Correcao de erro usa revision lineage/reason proprio e nao pode ser ocultada como
expansion comercial. MRR snapshot e movimentos preservam policy version, inputs,
hash e horario de observacao para replay.

## 2.7 Analytics global sem fan-out

Cada tenant calcula e persiste seus snapshots/movimentos localmente e publica uma
projecao minimizada por outbox. Um projector idempotente no store da plataforma
mantem apenas dimensoes allowlisted, IDs opacos, periodo, metrica, valor, currency,
version/hash e checkpoint.

E proibido:

- abrir conexao em todos os bancos para atender dashboard;
- fazer join cross-database/cross-tenant;
- copiar invoice lines, payer PII, payload de pagamento ou artefato fiscal para a
  projecao por conveniencia;
- usar Redis, Grafana, provider ou frontend como autoridade;
- corrigir agregado sem preservar evento/revisao causal.

Rebuild ocorre a partir dos outboxes/snapshots tenant-local com checkpoint e
reconciliacao; drift e observavel e nao e escondido por ajuste manual silencioso.

## 2.8 Autorizacao das consultas

A familia administrativa pode consultar MRR/ARR agregado somente com authority
global especifica, purpose registrado e politica do ADR-0050. Um tenant consulta
apenas seu proprio summary pelo contexto efetivo validado. Superadmin nao recebe
automaticamente detalhe financeiro cross-tenant.

OpenAPI definira paths, DTOs, granularidade e limites. Export detalhado, drill-down
cross-tenant e label por PII ficam desligados ate privacy/security review.

## 2.9 Capabilities diferidas

Permanecem `OFF`/`PENDING_EVIDENCE`:

- FX e multi-moeda;
- plano de contas e postings estatutarios;
- reconhecimento/diferimento oficial de receita;
- exportacao ou integracao ERP;
- data warehouse/lake ou BI externo;
- hard close contabil;
- declaracoes de receita, margem, caixa ou tributo oficial derivadas deste ledger.

Esses itens requerem owner Financeiro/Contabil, requisitos e evidencia; nao sao
decisoes abertas que a IA possa completar por inferencia.

## 2.10 Boundary da aprovacao

`D-12` fica fechado em arquitetura e definicao `MRR_V1`. `D-13`/`D-14` foram
fechados nos ADRs-0050/0051 por Codex sob `AUTH-BILLING-2026-08-25-001`, com
provenance `AI_DELEGATED`, revisao humana `NOT_PERFORMED` e
`Reviewability: OPEN`. Nomes finais de accounts, DDL, OpenAPI, retencao, backfill,
dashboards, reconciliacao e implementacao seguem os planos. Esta ADR isolada nao
libera codigo; a autorização humana separada registrou `D-00 =
RELEASED_WITH_SCOPE — HUMAN_EXPLICIT — TP-00013 local-only`.

---

# 3. Decision Drivers

- integridade financeira e replay deterministico;
- isolamento database-per-tenant;
- metrica comercial comparavel e explicavel;
- separacao entre contrato, caixa e contabilidade estatutaria;
- privacidade e menor privilegio em analytics global;
- custo compativel com monolito/PostgreSQL em VPS unica;
- evolucao posterior para ERP/warehouse sem acoplar o dominio.

---

# 4. Considered Options

## Option A - Subledger tenant-local + projecao global minimizada

Pros: preserva isolamento, causalidade, custo e replay; evita fan-out em leitura.

Cons: requer outbox, projector, reconciliacao e definicoes rigorosas.

## Option B - Ledger e invoices centralizados na plataforma

Rejected: enfraquece database-per-tenant e cria concentracao de dados/risco.

## Option C - Calcular indicadores diretamente do provider ou das invoices pagas

Rejected: mistura contrato, collection e caixa, produz MRR instavel e transfere
autoridade.

## Option D - Adotar ERP/warehouse imediatamente

Rejected: custo e complexidade prematuros; nao elimina a necessidade de fatos
tenant-local corretos.

---

# 5. Decision Outcome

A **Option A** foi escolhida autonomamente pela IA sob delegacao. Ela oferece a
trilha mais forte dentro do custo atual, sem transformar um ledger gerencial em
atestado contabil e sem introduzir infraestrutura distribuida antes da necessidade.

---

# 6. Consequences

## Positive Consequences

- Cada efeito financeiro possui partida, origem, reversao e replay.
- MRR/ARR deixam de depender de pagamento ou provider.
- Analytics administrativo nao varre bancos de tenants.
- PII e detalhes financeiros permanecem no tenant.
- O desenho permite futura integracao contabil por adapter.

## Negative Consequences

- Double-entry e projector aumentam a disciplina do modelo.
- Reconciliacao e rebuild precisam de ferramentas operacionais.
- Indicadores oficiais mais amplos permanecem indisponiveis no primeiro slice.

## Neutral Consequences

- MRR e indicador comercial, nao receita reconhecida.
- BRL-only e uma capability deliberada, nao limite estrutural permanente.

---

# 7. Impact

- Domain: posting batches/entries, metric policies e movement classification puros.
- Application: ports para journal, snapshot, outbox, projector e reconciliation.
- Persistence: append-only no tenant; projecao minimizada no platform store.
- API/UI: admin agregado e tenant own-summary, ambos server-authoritative.
- Security: scope, purpose, redaction, audit e ausencia de PII em labels/projecao.
- Infrastructure: usa PostgreSQL e workers existentes; sem warehouse/servico novo.

---

# 8. AI Agent Considerations

Agentes devem rotular o ledger como gerencial, conservar `MRR_V1`, nunca apresentar
MRR como receita/caixa, nunca inventar plano de contas ou policy contabil e manter
a provenance `AI_DELEGATED`. Uma necessidade estatutaria deve ser encaminhada ao
owner, nao preenchida com convencao generica.

---

# 9. Implementation Plan Boundary

1. congelar event taxonomy, accounts logicas e `MRR_V1` vectors;
2. modelar batches/entries/policies puros e invariantes de balanceamento;
3. criar migrations aditivas tenant-local e outbox;
4. integrar intents de invoice/payment/credit/refund/dispute por ports;
5. implementar snapshots/movimentos MRR reproduziveis;
6. criar projector platform minimizado com rebuild/reconcile;
7. publicar OpenAPI admin/tenant com autorizacao conforme ADR-0050;
8. validar concorrencia, isolamento, backfill, compensacao e performance conforme
   ADR-0051.

A implementação hermética local pode avançar sob a liberação escopada de `D-00`;
efeito, integração, piloto e rollout permanecem condicionados aos evidence gates
contábeis/operacionais aplicáveis.

---

# 10. Validation

- todo batch `POSTED` balanceia debitos e creditos por BRL;
- reuse idempotente divergente falha e reversal nunca edita origem;
- `MRR_V1` passa golden vectors mensal/anual/desconto/trial/cancelamento;
- usage, tax, refund, fee, juros e prepaid nao entram em MRR;
- movement deltas nao duplicam classificacao;
- projecao global nao contem PII nem exige scan cross-tenant;
- tenant A nao consulta summary do tenant B;
- rebuild reproduz valores e hashes;
- nenhuma tela chama o subledger de razao estatutario;
- docs e indices passam no validador integrado.

Testes executaveis nao foram criados porque esta mudanca e documental.

---

# 11. Risks and Mitigations

| Risk | Mitigation |
| --- | --- |
| Ledger desbalanceado | Constraint/application invariant + commit atomico. |
| Correcao apagar historia | Reversal + novo batch causal; sem update/delete. |
| MRR divergir entre telas | Uma policy versionada e calculo server-side. |
| Projecao global vazar PII | Schema allowlisted/minimizado e security review. |
| Projector ficar stale | Checkpoint, lag metric, rebuild e reconcile. |
| MRR ser tratado como receita oficial | Label gerencial explicito e capabilities estatutarias OFF. |
| Infraestrutura exceder a VPS | PostgreSQL/outbox/workers existentes e limites qualificados conforme ADR-0051. |

---

# 12. Related ADRs

- [ADR-0000 - Governanca documental](../../harness/governance/decisions/ADR-0000-governanca-do-harness-documental.md)
- [ADR-0001 - Stack e arquitetura](ADR-0001-technology-stack-and-architecture.md)
- [ADR-0019 - Database-per-tenant](ADR-0019-database-per-tenant.md)
- [ADR-0027 - Catalogo global e faturamento local](ADR-0027-catalogo-global-faturamento-local.md)
- [ADR-0038 - Pricing tipado](ADR-0038-pricing-tipado-moeda-cadencia.md)
- [ADR-0044 - Lifecycle contratual](ADR-0044-lifecycle-contratual-proration-assinaturas.md)
- [ADR-0047 - Ledger, creditos e refunds](ADR-0047-ledger-creditos-refunds-disputas-writeoff.md)
- [ADR-0048 - Fatura comercial e NFS-e](ADR-0048-separacao-fatura-comercial-documento-fiscal-nfse.md)
- [ADR-0050 - RBAC, SoD e aprovacoes](ADR-0050-rbac-sod-aprovacoes-financeiras.md)
- [ADR-0051 - SLO, capacidade e rollout](ADR-0051-slo-capacidade-rollout-billing.md)

---

# 13. References

- [REQ-00042](../product/requirements/REQ-00042-enterprise-multitenant-billing-invoicing.md)
- [UC-00045](../product/use-cases/UC-00045-billing-financial-close-reporting.md)
- [TP-00013](../../../docs/specs/TP-00013-enterprise-billing-implementation-task-plan.md)
- [Module Registry](../architecture/module-registry.md)

---

# 14. Decision Lifecycle

Current State: **Accepted - AI_DELEGATED**.

Revisao humana pode ratificar ou substituir definicoes, mas deve preservar a
origem. Mudanca material de autoridade, double-entry, `MRR_V1`, projection boundary
ou natureza gerencial exige nova versao aceita ou ADR sucessor.

`D-13`/`D-14` estao aceitos com a mesma origem delegada e revisao humana aberta;
isso nao atesta controls, performance, backup, Sandbox ou readiness. `D-00` foi
liberado por humano somente para implementação local dos planos TP-00013.

---

# 15. Change Log

| Version | Date | Author | Changes |
| --- | --- | --- | --- |
| 1.2 | 2026-08-25 | Solicitante humano, proprietário declarado / Codex (IA), materialização | Registra `D-00 = RELEASED_WITH_SCOPE — HUMAN_EXPLICIT — TP-00013 local-only`; permite implementação/DDL/OpenAPI/testes herméticos locais e mantém chamadas externas, Sandbox ASAAS, piloto BP Farias, produção, flags `ON`, hard close e efeitos reais bloqueados. |
| 1.1 | 2026-08-25 | Codex (IA), sob `AUTH-BILLING-2026-08-25-001` | Reconcilia ADRs-0050/0051 como `AI_DELEGATED`, revisao humana `NOT_PERFORMED`/`OPEN`; preserva evidence gates contabeis/operacionais e `D-00` ativo. |
| 1.0 | 2026-08-25 | Codex (IA), sob `AUTH-BILLING-2026-08-25-001` | Fecha autonomamente `D-12` com subledger tenant-local double-entry BRL-only, projecao global minimizada e `MRR_V1`/ARR/movimentos reproduziveis; revisao humana substantiva nao realizada. |

---

# 16. Repository Structure

Este ADR cria somente documentacao. Os alvos futuros sao slices internos de
`contexts.billing`, separados por domain, application, persistence tenant/platform
e presentation, sem modulo ou servico adicional.

---

# 17. Review Process

Revisao humana permanece aberta. Ratificacao contabil deve identificar
responsavel, data, competencia e escopo; nao transforma retroativamente a decisao
de IA em decisao humana.

---

# 18. Notes

MRR responde ao valor recorrente contratado. Collection responde ao que foi pago;
o subledger explica movimentos; contabilidade oficial depende de politica propria.
