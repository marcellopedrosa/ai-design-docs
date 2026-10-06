---
document_id: "ADR-0051"
primary_nature: "Decisao"
objective: "Fechar `D-14` definindo targets de confiabilidade, piso de qualificacao sintetica, backup/recovery, rollout progressivo, kill switches e rollback para Billing na VPS inicial."
scope: "VPS unica, sizing recomendado, SLO piloto, latencia, workers, recovery, carga sintetica, RPO/RTO, restore drill, feature flags, allowlist BP Farias, shadow, progressive rollout, kill switches e rollback forward-only."
non_objectives: "Declarar capacidade medida, aprovar piloto/producao, comprar ou provisionar VPS, executar load/Sandbox/restore tests, definir SLA contratual, acessar BP Farias real, credenciais ou ambientes externos."
owner: "Operacoes / SRE / Billing / Seguranca / Arquitetura"
status: "Accepted"
date: "2026-08-25"
version: "1.2"
keywords: "billing reliability, SLO, VPS, capacity, load test, RPO, RTO, backup, restore drill, rollout, feature flag, kill switch, BP Farias, rollback"
related_files: "docs/product/requirements/REQ-00042-enterprise-multitenant-billing-invoicing.md`, `docs/product/use-cases/UC-00040-billing-usage-rating-invoice-close.md`, `docs/product/use-cases/UC-00042-billing-payment-reconciliation-dunning.md`, `docs/product/use-cases/UC-00045-billing-financial-close-reporting.md`, `docs/delivery/plans/TP-00013-enterprise-billing-implementation-task-plan.md`, `docs/delivery/plans/implementation_plans/backend/IP-BE-11.3.5-billing-release-readiness-and-acceptance.md`, `docs/adrs/ADR-0001-technology-stack-and-architecture.md`, `docs/adrs/ADR-0011-resilience-retry-circuit-breaker.md`, `docs/adrs/ADR-0012-error-handling-observability.md`, `docs/adrs/ADR-0016-infrastructure-environment-provisioning.md`, `docs/adrs/ADR-0031-governanca-topologia-infraestrutura.md`, `docs/adrs/ADR-0033-arquitetura-alvo-iac-segura.md"
code_references: "Destinos planejados em `backend/`, `frontend/` e `infra/` para flags, workers, metrics, dashboards, backup/restore e rollout; este ADR nao altera configuracao executavel nem declara o estado AS-IS como qualificado."
principal_statement: "Billing permanecera na VPS unica, recomendando no minimo 8 GB para piloto pago e qualificando-se por SLOs/carga/restore medidos; o rollout sera dark-to-GA com flags OFF, BP Farias por allowlist configurada sem hardcode e kill switch de mutacao externa que nunca desliga ingress, reconciliacao ou recovery."
---

# ADR-0051 - SLO, capacidade e rollout seguro de Billing

- Document ID: `ADR-0051`
- Primary Nature: `Decisao`
- Objective: Fechar `D-14` definindo targets de confiabilidade, piso de qualificacao sintetica, backup/recovery, rollout progressivo, kill switches e rollback para Billing na VPS inicial.
- Scope: VPS unica, sizing recomendado, SLO piloto, latencia, workers, recovery, carga sintetica, RPO/RTO, restore drill, feature flags, allowlist BP Farias, shadow, progressive rollout, kill switches e rollback forward-only.
- Non-objectives: Declarar capacidade medida, aprovar piloto/producao, comprar ou provisionar VPS, executar load/Sandbox/restore tests, definir SLA contratual, acessar BP Farias real, credenciais ou ambientes externos.
- Keywords: billing reliability, SLO, VPS, capacity, load test, RPO, RTO, backup, restore drill, rollout, feature flag, kill switch, BP Farias, rollback
- Related Files: `docs/product/requirements/REQ-00042-enterprise-multitenant-billing-invoicing.md`, `docs/product/use-cases/UC-00040-billing-usage-rating-invoice-close.md`, `docs/product/use-cases/UC-00042-billing-payment-reconciliation-dunning.md`, `docs/product/use-cases/UC-00045-billing-financial-close-reporting.md`, `docs/delivery/plans/TP-00013-enterprise-billing-implementation-task-plan.md`, `docs/delivery/plans/implementation_plans/backend/IP-BE-11.3.5-billing-release-readiness-and-acceptance.md`, `docs/adrs/ADR-0001-technology-stack-and-architecture.md`, `docs/adrs/ADR-0011-resilience-retry-circuit-breaker.md`, `docs/adrs/ADR-0012-error-handling-observability.md`, `docs/adrs/ADR-0016-infrastructure-environment-provisioning.md`, `docs/adrs/ADR-0031-governanca-topologia-infraestrutura.md`, `docs/adrs/ADR-0033-arquitetura-alvo-iac-segura.md`
- Code References: Destinos planejados em `backend/`, `frontend/` e `infra/` para flags, workers, metrics, dashboards, backup/restore e rollout; este ADR nao altera configuracao executavel nem declara o estado AS-IS como qualificado.
- Principal Decision: Billing permanecera na VPS unica, recomendando no minimo 8 GB para piloto pago e qualificando-se por SLOs/carga/restore medidos; o rollout sera dark-to-GA com flags OFF, BP Farias por allowlist configurada sem hardcode e kill switch de mutacao externa que nunca desliga ingress, reconciliacao ou recovery.
- Date: 2026-08-25
- Status: Accepted
- Version: 1.2
- Decision Provenance: `AI_DELEGATED`
- Decision Actor: `AI_AGENT — Codex (OpenAI)`
- Authority Basis: `OWNER_DELEGATION — AUTH-BILLING-2026-08-25-001`
- Human Review Status: `NOT_PERFORMED`
- Reviewability: `OPEN`
- Authors: Codex (AI), sob autoridade delegada
- Owners: Operacoes / SRE / Billing / Seguranca / Arquitetura
- Reviewers: AI — analise de arquitetura, confiabilidade, seguranca e custo; Human — N/A, nenhuma revisao substantiva desta decisao foi realizada
- Stakeholders: Proprietario do SaaS, GV Software, BP Farias como candidato a piloto, tenants, Billing, Financeiro, Suporte, Backend, Frontend, Seguranca e Operacoes
- Supersedes: N/A; especializa ADR-0001, ADR-0011, ADR-0012, ADR-0016, ADR-0031 e ADR-0033 para readiness de Billing.
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
| Excluded attestations | Capacidade real, SLO atingido, restore bem-sucedido, readiness ASAAS/Sandbox, readiness BP Farias, piloto, producao, on-call e implementacao |

`Accepted` torna targets e gates normativos sob delegacao; nao afirma que qualquer
metrica foi medida ou que um ambiente esta pronto. A provenance `AI_DELEGATED`
permanece mesmo se os targets forem posteriormente ratificados por humanos.

---

# 1. Context

O projeto nasce em VPS unica para controlar custo. Billing, porem, combina
transacoes financeiras, jobs por tenant, webhooks, reconciliacao, fechamento e
efeitos externos. Apenas o build passar ou a rota responder localmente nao prova
que a plataforma suporta carga, perda de processo, indisponibilidade do provider
ou restauracao de banco.

A estrategia deve manter a topologia simples sem tratar sizing nominal como
evidencia. Tambem precisa permitir interromper novas cobrancas sem desligar os
mecanismos que recebem webhooks e recuperam estados ambiguos.

---

# 2. Decision Statement

## 2.1 Topologia e sizing

O primeiro horizonte permanece em uma unica VPS com o monolito modular,
PostgreSQL, Redis derivado e componentes de observabilidade aprovados. Nao se cria
microservico, cluster, broker ou database adicional apenas para Billing.

Recomendacao de baseline:

| Ambiente | Memoria da VPS | Classificacao |
| --- | ---: | --- |
| Desenvolvimento/Sandbox | 4 GB | Permitido para trabalho funcional; nao qualifica carga paga. |
| Piloto pago | minimo recomendado de 8 GB | Candidato somente apos benchmark e headroom medidos. |

CPU, disco/IOPS, throughput, latencia, conexoes, headroom e comportamento sob
falha permanecem `PENDING_EVIDENCE`. A recomendacao de 8 GB nao e capacity proof e
nao substitui medicao no mesmo perfil de containers/configuracao do candidato.

## 2.2 SLO targets do piloto

Targets iniciais, medidos server-side com clocks e janelas documentados:

| Indicador | Target |
| --- | --- |
| Disponibilidade do plano de Billing do piloto | `>= 99.5%` na janela mensal definida, antes de SLA comercial |
| API reads online | `p95 <= 500 ms`; `p99 <= 1.5 s` |
| Writes locais de Billing | `p95 <= 1 s` ate commit tenant-local, sem contar provider assincrono |
| Webhook durable ACK | `p99 <= 2 s` ate autenticacao minima + persistencia duravel; processamento fica fora do ACK |
| Worker latency | `p95 <= 60 s` entre trabalho elegivel/enfileirado e processamento concluido ou estado terminal/retry explicito |
| Recovery financeiro elegivel | `p95 <= 5 min`; `p99 <= 15 min` entre fato reconciliavel e convergencia local/entitlement |

Availability scope, endpoint classes, exclusoes, maintenance e error-budget
formula devem ser publicados antes da medicao. Exclusao nao pode ocultar erro de
codigo, saturacao, falha de dependency interna ou incidente causado pela release.
Nenhum target acima e declarado atingido neste ADR.

## 2.3 Piso de qualificacao sintetica

O candidato a piloto deve passar, no minimo, carga controlada com:

| Dimensao | Piso |
| --- | ---: |
| Tenants sinteticos isolados | 50 |
| Sessoes concorrentes | 100 |
| Usage events sustentados | 10 eventos/s |
| Volume mensal equivalente | 1.000.000 eventos |
| Linhas por invoice | ate 1.000 |
| Batch de tenants | 100 por lote |
| Concorrencia maxima inicial do batch | 4 |
| Contencao de promocao hot | 20 concorrentes sobre a mesma capacidade |

O teste precisa misturar API, close, outbox, webhook, reconcile e queries de
operacao, incluindo tenant lento/falho, restart de worker, provider stub local de
contrato e saturacao controlada. Nao usa producao, dados reais, credenciais reais
ou chamada financeira externa.

Passar o piso significa satisfazer SLOs, zero violacao tenant A/B, zero invoice ou
cobranca duplicada, nenhuma perda de evento confirmado, backlog drenavel e
headroom definido pelo owner. Numeros acima sao qualification floor, nao capacity
ceiling nem promessa de escala.

## 2.4 Backup, RPO e RTO

Para operacao paga:

- target `RPO <= 15 min`, por mecanismo equivalente a WAL/backup incremental
  offsite, criptografado e monitorado;
- target `RTO <= 4 h`, demonstrado por restore drill completo em ambiente isolado;
- restore deve recuperar platform store, registry/rotas e bancos tenant necessarios
  de forma consistente com journal/outbox, seguido de integrity/reconcile checks;
- backup sem restore observado nao e evidencia;
- chaves/credenciais de recuperacao nao ficam no repositorio nem no mesmo failure
  domain sem protecao adequada.

Um schedule de backup duas vezes ao dia sugere janela nominal de ate cerca de 12
horas e e insuficiente para o target pago. Ele tambem nao prova RPO real nem RTO.
Enquanto WAL/offsite, monitoramento e restore drill nao forem evidenciados, o gate
de piloto pago permanece fechado.

## 2.5 Sequencia de rollout

O rollout segue obrigatoriamente:

```text
DARK
  -> LOCAL_AND_SANDBOX_SYNTHETIC
  -> SHADOW
  -> BP_FARIAS_ALLOWLIST
  -> PROGRESSIVE_ALLOWLIST
  -> GENERAL_AVAILABILITY
```

Semantica das fases:

| Fase | Efeitos permitidos |
| --- | --- |
| `DARK` | Codigo/schema aditivo presente, capabilities e schedules OFF. |
| `LOCAL_AND_SANDBOX_SYNTHETIC` | Fluxos controlados, sem dados/credenciais/producao reais. |
| `SHADOW` | Le, calcula e compara; nao envia mutacao a provider, nao ativa entitlement pago e nao comunica cliente. |
| `BP_FARIAS_ALLOWLIST` | Um tenant piloto explicitamente configurado, apos consentimento/readiness/evidencias. |
| `PROGRESSIVE_ALLOWLIST` | Coortes pequenas com bake time, metricas e stop conditions. |
| `GENERAL_AVAILABILITY` | Somente apos gates, error budget e sign-off dos owners. |

BP Farias e referencia de produto ao candidato a piloto, nao ID tecnico. A
allowlist usa identificador opaco/configuracao governada, nunca nome, Documento,
email ou UUID hardcoded no codigo/migration/teste. O ADR nao declara esse tenant
consentido, configurado ou pronto.

Cada promocao de fase exige evidence bundle imutavel com build/config/hash,
periodo observado, resultados, falhas/skips, aprovadores e rollback rehearsal. Uma
fase nao e saltada por pressao comercial.

## 2.6 Feature flags e default seguro

Todas as capabilities de mutacao Billing nascem `OFF`, com escopo por ambiente,
capability e allowlist. Ausencia, parse invalido ou store indisponivel resolve para
OFF. Flags nao ficam sob controle do frontend/tenant e toda mudanca e auditada.

No minimo, flags independentes separam:

- catalog/contract writes;
- usage admission/rating/close;
- invoice finalization;
- provider payment mutation por rail;
- fiscal mutation;
- refund/correction/write-off;
- dunning restriction;
- projection/reporting.

Uma flag nao substitui authorization, approval, capability check ou idempotencia.

## 2.7 Kill switches

O kill switch de `EXTERNAL_MUTATION` interrompe novas criacoes/cancelamentos/refunds
ou alteracoes no provider, preservando:

- ingress e durable ACK de webhook;
- inbox processing seguro;
- consulta e reconciliacao;
- recovery de commands ja ambiguos;
- leitura, export de suporte autorizado e observabilidade;
- compensacoes internas necessarias para convergir fatos confirmados.

Existem switches separados para close, fiscal e dunning. Desligar mutacao nao
pode descartar evento externo, ocultar pagamento ou impedir recuperacao. Acionamento
e liberacao exigem reason, actor, timestamp, scope e policy do ADR-0050.

## 2.8 Rollback forward-only

Rollback operacional usa, nesta ordem:

1. interromper promocao/coorte;
2. acionar flag/kill switch apropriado;
3. retornar a versao de aplicacao compativel quando seguro;
4. drenar/reconciliar inbox, outbox e commands;
5. corrigir por migration aditiva/forward e compensacao causal;
6. reabrir apenas depois de evidence review.

E proibido usar down migration destrutiva, apagar invoice/journal/evento, reduzir
schema de forma incompativel, reutilizar sequence ou desfazer efeito financeiro
externo por delete local. Uma invoice/pagamento confirmado e corrigido por
compensacao, nao por restauração seletiva de linha.

## 2.9 Gates de piloto e producao

Este ADR nao aprova piloto ou producao. O candidato so avanca quando houver
evidencia, no minimo, de:

- suites funcionais, tenancy, seguranca, concorrencia e carga aprovadas;
- SLOs e headroom medidos no ambiente candidato;
- backup offsite/WAL e restore drill dentro de RPO/RTO;
- ASAAS Sandbox/capabilities/webhook/reconcile comprovados para rails habilitados;
- controls do ADR-0050, owners, on-call, alertas e runbooks ativos;
- gates fiscais do ADR-0048 para qualquer obrigacao aplicavel;
- kill switch e rollback ensaiados;
- consentimento/readiness do tenant allowlisted e ausencia de hardcode.

Qualquer item sem prova fica `PENDING_EVIDENCE`; a IA nao o converte em aprovado.

## 2.10 Boundary da aprovacao

`D-14` fica fechado em targets, pisos e estrategia. Capacity real, readiness e
sign-offs continuam pendentes. `D-00 = RELEASED_WITH_SCOPE — HUMAN_EXPLICIT —
TP-00013 local-only`; este ADR isolado não amplia o escopo para chamada externa,
Sandbox, piloto, produção, flag `ON` ou efeito real.

---

# 3. Decision Drivers

- custo inicial de VPS unica;
- integridade financeira sob restart, timeout e backlog;
- evidencia medida em vez de sizing presumido;
- recuperacao de dados proporcional ao risco pago;
- rollout reversivel e blast radius pequeno;
- separacao entre parar mutacao e continuar reconciliacao;
- database-per-tenant e ausencia de transacao distribuida.

---

# 4. Considered Options

## Option A - VPS unica qualificada + rollout progressivo evidence-first

Pros: preserva custo, cria gates objetivos, limita blast radius e permite evoluir
somente quando medido.

Cons: exige testes, observabilidade, restore drills e promocao gradual antes de GA.

## Option B - Liberacao direta apos testes funcionais

Rejected: nao prova capacidade, recovery, idempotencia sob falha ou resposta a
incidente.

## Option C - Microservicos/cluster antes do piloto

Rejected: eleva custo e operacao sem evidenciar que a topologia atual e o gargalo.

## Option D - Kill switch unico que desliga todo Billing

Rejected: impediria webhook/reconcile e aumentaria divergencia financeira durante
o incidente.

---

# 5. Decision Outcome

A **Option A** foi escolhida autonomamente pela IA sob delegacao. Ela conserva o
perfil de custo do projeto, mas impede que a economia de infraestrutura seja
interpretada como permissao para operar sem carga, backup ou rollback comprovados.

---

# 6. Consequences

## Positive Consequences

- Readiness passa a depender de evidencia reproduzivel.
- Rollout reduz blast radius e preserva BP Farias sem hardcode.
- Kill switch interrompe risco novo sem cegar reconciliacao.
- RPO/RTO pagos ficam alinhados ao risco financeiro.
- A topologia pode evoluir quando metricas mostrarem necessidade real.

## Negative Consequences

- Piloto pago exige pelo menos baseline recomendado e varios gates.
- Carga, restore drill e bake time aumentam o tempo ate GA.
- Observabilidade/flags/runbooks exigem manutencao operacional.

## Neutral Consequences

- 8 GB e recomendacao de entrada, nao garantia.
- SLO piloto ainda nao e SLA contratual.
- Falha de gate adia rollout; nao invalida a arquitetura.

---

# 7. Impact

- Infrastructure: VPS unica, backup incremental/offsite e restore isolado.
- Backend: flags/kill switches, bounded workers, metrics e recovery paths.
- Frontend: estados de capability/readiness, sem override client-side.
- Security: allowlists opacas, audit e ausencia de dados reais em carga.
- Operations: SLO dashboards, error budget, on-call, runbooks e evidence bundles.
- Product: BP Farias somente apos gate e consentimento; GA progressivo.

---

# 8. AI Agent Considerations

Agentes devem distinguir target de resultado medido, nunca marcar piloto/production
ready com base neste ADR, nunca usar dado real de BP Farias e nunca apagar a origem
`AI_DELEGATED`. Automacao pode coletar evidence; sign-offs humanos/externos
continuam explicitamente separados.

---

# 9. Implementation Plan Boundary

1. aplicar a liberação local-only de `D-00` e congelar metric definitions/gates
   sem habilitar efeitos;
2. implementar flags OFF e kill switches fail-safe;
3. instrumentar SLOs, queue lag, saturation e reconciliation;
4. implementar backup/WAL/offsite e runbook de restore;
5. construir workload sintetico isolado e fault injection segura;
6. executar restore drill e load qualification no candidato;
7. executar local/Sandbox, shadow e rollback rehearsal;
8. obter owner evidence/sign-offs e configurar allowlist opaca;
9. promover coortes com bake time/stop conditions ate GA.

Etapas herméticas locais são autorizadas pela liberação humana separada de `D-00`;
este ADR não autoriza chamadas externas, Sandbox, piloto ou produção.

---

# 10. Validation

- SLOs sao calculados por metrica/janela publicada e nao por amostra manual;
- workload minimo passa sem cross-tenant leak, duplicate charge/invoice ou perda;
- batch respeita concorrencia inicial maxima 4 e tenant falho nao contamina outro;
- webhook durable ACK permanece dentro do target sob backlog;
- restore drill demonstra RPO/RTO e reconcile posterior;
- flags ausentes/invalidas ficam OFF;
- kill de mutacao preserva ingress/reconcile/recovery;
- rollback nao usa down migration/delete;
- BP Farias nao aparece hardcoded e nao usa dados reais nos testes;
- evidence bundle determina promocao/no-go;
- docs e indices passam no validador integrado.

Testes executaveis nao foram criados porque este ADR e uma mudanca documental e
nao executa qualificacao.

---

# 11. Risks and Mitigations

| Risk | Mitigation |
| --- | --- |
| 8 GB ser insuficiente | Benchmark/headroom medidos; sizing nao e prova. |
| Teste sintetico nao representar fluxo | Mix de API/jobs/webhooks/reconcile + fault injection. |
| Backup existir e restore falhar | Restore drill isolado obrigatorio. |
| Kill switch perder eventos | Ingress/reconcile/recovery em caminho independente. |
| Rollback corromper historico | Forward migration + compensacao; sem delete/down. |
| Piloto vazar para tenants nao autorizados | Flags OFF + allowlist opaca + coortes. |
| IA declarar readiness inexistente | Gates `PENDING_EVIDENCE` e sign-offs separados. |

---

# 12. Related ADRs

- [ADR-0000 - Governanca documental](../../harness/governance/decisions/ADR-0000-governanca-do-harness-documental.md)
- [ADR-0001 - Stack e arquitetura](ADR-0001-technology-stack-and-architecture.md)
- [ADR-0011 - Resiliencia](ADR-0011-resilience-retry-circuit-breaker.md)
- [ADR-0012 - Observabilidade](ADR-0012-error-handling-observability.md)
- [ADR-0016 - Provisionamento de infraestrutura](ADR-0016-infrastructure-environment-provisioning.md)
- [ADR-0031 - Governanca de infraestrutura](ADR-0031-governanca-topologia-infraestrutura.md)
- [ADR-0033 - IaC segura](ADR-0033-arquitetura-alvo-iac-segura.md)
- [ADR-0023 - Provider-neutral payments](ADR-0023-agnostic-payment-provider-integration.md)
- [ADR-0048 - Fatura comercial e NFS-e](ADR-0048-separacao-fatura-comercial-documento-fiscal-nfse.md)
- [ADR-0050 - RBAC, SoD e aprovacoes](ADR-0050-rbac-sod-aprovacoes-financeiras.md)

---

# 13. References

- [REQ-00042](../product/requirements/REQ-00042-enterprise-multitenant-billing-invoicing.md)
- [UC-00040](../product/use-cases/UC-00040-billing-usage-rating-invoice-close.md)
- [UC-00042](../product/use-cases/UC-00042-billing-payment-reconciliation-dunning.md)
- [UC-00045](../product/use-cases/UC-00045-billing-financial-close-reporting.md)
- [TP-00013](../delivery/plans/TP-00013-enterprise-billing-implementation-task-plan.md)
- [Module Registry](../architecture/module-registry.md)

---

# 14. Decision Lifecycle

Current State: **Accepted - AI_DELEGATED**.

Revisao humana pode ratificar ou ajustar targets mediante evidencia, preservando a
origem. Alteracao material de topology baseline, rollout stages, kill-switch
boundary, RPO/RTO ou rollback exige nova versao aceita ou ADR sucessor.

`D-00` está `RELEASED_WITH_SCOPE — HUMAN_EXPLICIT — TP-00013 local-only`. Fechar
`D-14` nao converte target em resultado medido, nao satisfaz ASAAS/PCI/Sandbox/
fiscal/backup/piloto e nao autoriza execução externa ou rollout.

---

# 15. Change Log

| Version | Date | Author | Changes |
| --- | --- | --- | --- |
| 1.2 | 2026-08-25 | Solicitante humano, proprietário declarado / Codex (IA), materialização | Registra `D-00 = RELEASED_WITH_SCOPE — HUMAN_EXPLICIT — TP-00013 local-only`; permite implementação/testes herméticos locais e mantém capacity/readiness, chamadas externas, Sandbox ASAAS, piloto BP Farias, produção, flags `ON` e efeitos reais bloqueados. |
| 1.1 | 2026-08-25 | Codex (IA), sob `AUTH-BILLING-2026-08-25-001` | Torna explicito o estado vigente de `D-00` (`ACTIVE`) e referencia ADRs-0048/0050 aceitos; preserva readiness, SLO/backup, ASAAS/Sandbox e piloto como evidencias pendentes, com revisao humana `NOT_PERFORMED`/`OPEN`. |
| 1.0 | 2026-08-25 | Codex (IA), sob `AUTH-BILLING-2026-08-25-001` | Fecha autonomamente `D-14` com VPS unica, baseline recomendado 8 GB para piloto, SLOs/piso sintetico, RPO/RTO, rollout dark-to-GA, flags/kill switches e rollback forward-only; revisao humana substantiva e readiness nao realizadas. |

---

# 16. Repository Structure

Este ADR cria somente documentacao. Instrumentacao e controles futuros permanecem
em `backend/`, `frontend/` e `infra/` conforme seus planos/instrucoes, sem nova
topologia executavel neste momento.

---

# 17. Review Process

Revisao humana permanece aberta. Ratificacao deve registrar actor, ambiente,
periodo, comandos, resultados, falhas/skips e evidence bundle; declaracao sem
evidencia nao promove nenhuma fase.

---

# 18. Notes

Simplicidade de infraestrutura e uma escolha de custo. Confiabilidade continua
dependendo de medicao, recuperacao e limites operacionais provados.
