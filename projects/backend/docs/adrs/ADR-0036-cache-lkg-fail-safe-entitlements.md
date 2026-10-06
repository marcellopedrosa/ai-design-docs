---
document_id: "ADR-0036"
primary_nature: "Decisao"
objective: "Definir a resposta segura e determinística a cache miss, indisponibilidade, ausência, corrupção, conflito e recuperação da autoridade canônica de entitlements."
scope: "Cache de decisão derivado, last-known-good (LKG), classes de operação, estados indeterminados, TTLs máximos, epochs, invalidação, cold start, degraded mode, recuperação, isolamento tenant-local, integridade e observabilidade."
non_objectives: "Definir ownership físico, packages, classes, ports, eventos, tabelas, chaves Redis ou marker de cutover; criar DDL, OpenAPI, código ou migrações; aprovar pricing, rating, invoice, cobrança, provider, alçadas finais, rollout, SLOs definitivos ou implementação."
owner: "Arquitetura / Billing / Produto / Segurança / Dados / Operações"
status: "Accepted"
date: "2026-08-25"
version: "1.3"
keywords: "entitlement cache, last known good, LKG, fail safe, fail closed, degraded mode, risk epoch, contract epoch, stale read, cache poisoning, tenant isolation"
related_files: "docs/product/requirements/REQ-00005-plan-feature-matrix.md`, `docs/product/requirements/REQ-00011-chatbot-usage-limits-and-billing.md`, `docs/product/requirements/REQ-00042-enterprise-multitenant-billing-invoicing.md`, `docs/product/use-cases/UC-00038-billing-catalog-pricing-promotions.md`, `docs/product/use-cases/UC-00039-billing-contract-subscription-amendments.md`, `docs/product/use-cases/UC-00040-billing-usage-rating-invoice-close.md`, `docs/delivery/plans/TP-00013-enterprise-billing-implementation-task-plan.md`, `docs/adrs/ADR-0035-migracao-evidence-first-entitlements-legados.md`, `docs/adrs/ADR-0037-boundary-fisico-entitlements-billing.md"
code_references: "AS-IS em `BillingApiAdapter`, `ChatbotFlowUseCase`, `TenantApiImpl`, `TenantRoutingDataSource`, `CacheConfig`, `TenantAwareCacheKey`, `ConversationAuditRetentionPolicyService`, `RedisConversationAuditRetentionPolicyCacheAdapter`, `BoundedConversationAuditRateLimitAdapter` e `BillingController`; cache/LKG canônico ainda não existe, e seu boundary/keyspace planejados seguem o ADR-0037."
principal_statement: "O snapshot tenant-local permanece autoridade; projeção, cache e LKG são derivados. Somente indisponibilidade técnica comprovada pode considerar LKG positivo, e apenas para operação explicitamente allowlisted de baixo risco; quota/capacidade/custo, mutação ampliativa, financeiro/provider, administração e risco exigem estado atual e falham de forma segura."
---

# ADR-0036 - Cache derivado, LKG limitado e fail-safe de entitlements

- Document ID: `ADR-0036`
- Primary Nature: `Decisao`
- Objective: Definir a resposta segura e determinística a cache miss, indisponibilidade, ausência, corrupção, conflito e recuperação da autoridade canônica de entitlements.
- Scope: Cache de decisão derivado, last-known-good (LKG), classes de operação, estados indeterminados, TTLs máximos, epochs, invalidação, cold start, degraded mode, recuperação, isolamento tenant-local, integridade e observabilidade.
- Non-objectives: Definir ownership físico, packages, classes, ports, eventos, tabelas, chaves Redis ou marker de cutover; criar DDL, OpenAPI, código ou migrações; aprovar pricing, rating, invoice, cobrança, provider, alçadas finais, rollout, SLOs definitivos ou implementação.
- Keywords: entitlement cache, last known good, LKG, fail safe, fail closed, degraded mode, risk epoch, contract epoch, stale read, cache poisoning, tenant isolation
- Related Files: `docs/product/requirements/REQ-00005-plan-feature-matrix.md`, `docs/product/requirements/REQ-00011-chatbot-usage-limits-and-billing.md`, `docs/product/requirements/REQ-00042-enterprise-multitenant-billing-invoicing.md`, `docs/product/use-cases/UC-00038-billing-catalog-pricing-promotions.md`, `docs/product/use-cases/UC-00039-billing-contract-subscription-amendments.md`, `docs/product/use-cases/UC-00040-billing-usage-rating-invoice-close.md`, `docs/delivery/plans/TP-00013-enterprise-billing-implementation-task-plan.md`, `docs/adrs/ADR-0035-migracao-evidence-first-entitlements-legados.md`, `docs/adrs/ADR-0037-boundary-fisico-entitlements-billing.md`
- Code References: AS-IS em `BillingApiAdapter`, `ChatbotFlowUseCase`, `TenantApiImpl`, `TenantRoutingDataSource`, `CacheConfig`, `TenantAwareCacheKey`, `ConversationAuditRetentionPolicyService`, `RedisConversationAuditRetentionPolicyCacheAdapter`, `BoundedConversationAuditRateLimitAdapter` e `BillingController`; cache/LKG canônico ainda não existe, e seu boundary/keyspace planejados seguem o ADR-0037.
- Principal Decision: O snapshot tenant-local permanece autoridade; projeção, cache e LKG são derivados. Somente indisponibilidade técnica comprovada pode considerar LKG positivo, e apenas para operação explicitamente allowlisted de baixo risco; quota/capacidade/custo, mutação ampliativa, financeiro/provider, administração e risco exigem estado atual e falham de forma segura.
- Date: 2026-08-25
- Status: Accepted
- Version: 1.3
- Authors / Owners: Arquitetura / Billing / Produto / Segurança / Dados / Operações
- Reviewers: Responsável pelo produto, com aprovação explícita de `D-04.2-G — opção A` em 2026-08-23; Arquitetura
- Stakeholders: Produto, Financeiro, Jurídico, Backend, Frontend, Segurança, Dados, Operações e tenants contratantes
- Supersedes: N/A; fecha a failure policy deixada aberta pelos ADR-0028, ADR-0030, ADR-0034 e ADR-0035 e proíbe que comportamentos fail-open legados sejam transportados ao modelo-alvo.
- Superseded by: N/A

---

# 1. Context

Os ADR-0028 a ADR-0035 definem uma autoridade tenant-local, snapshot completo e
imutável, projeção reconstruível, composição determinística, transições seguras e
cutover sem fallback legado. Ainda faltava responder o que ocorre quando uma
avaliação não pode ser obtida no instante da operação.

O AS-IS possui comportamentos que não podem virar contrato do modelo-alvo:

- ausência de subscription em Billing permite passagem em vez de produzir uma
  decisão íntegra;
- o fluxo do chatbot captura falha de quota e prossegue em modo fail-open;
- a API de tenant devolve defaults quando tenant/settings não estão disponíveis;
- ausência de contexto no roteamento pode alcançar o datasource compartilhado;
- o cache compartilhado possui TTLs genéricos e chave tenant/identificador, sem
  revision/hash/epoch de entitlement;
- não há implementação física de snapshot, projeção, LKG ou epochs canônicos.

Há precedentes úteis, mas não autoridades de entitlement: retention usa cache
derivado com fallback para fonte durável, e o rate limiter só conserva estado
bounded quando já existe espelho anterior; na ausência dele, bloqueia. Esses
padrões ajudam a conter falhas, mas não autorizam copiar classes, TTLs ou
semânticas para Billing fora do boundary físico aceito no ADR-0037.

O problema exige separar indisponibilidade transitória de ausência, corrupção e
conflito. Tratar todos como cache miss, usar enum/default ou aceitar qualquer valor
stale recriaria dual authority e poderia aumentar direito, consumo ou cobrança.

---

# 2. Decision Statement

## 2.1 Autoridade e natureza derivada

O `ContractEntitlementSnapshot` no banco dedicado do tenant continua sendo a
autoridade. A projeção efetiva é read model reconstruível; cache e LKG são cópias
derivadas e descartáveis.

- cache/LKG nunca cria, altera, renova ou prova contrato;
- uma entrada somente é utilizável quando sua origem canônica, integridade,
  versão, hashes, epochs e limites temporais forem verificáveis;
- perda total de cache deve afetar disponibilidade, não correção do snapshot;
- após o cutover do ADR-0035, enum, settings, defaults, seed e tabelas legadas não
  voltam como fallback, inclusive em cold start;
- ausência de uma fonte opcional tipada significa contribuição zero daquela
  fonte, e não ausência do snapshot completo.

## 2.2 Classificação conceitual do resultado

Uma avaliação deve distinguir, conceitualmente:

- `GRANTED`: autoridade íntegra concede a operação nos termos avaliados;
- `NOT_GRANTED`: autoridade íntegra nega ou não concede a operação;
- `INDETERMINATE_UNAVAILABLE`: a autoridade/projeção esperada existe, mas não pode
  ser consultada ou reconstruída temporariamente;
- `INDETERMINATE_MISSING`: fato obrigatório, snapshot, revisão ou projeção
  requerida não existe;
- `INDETERMINATE_CORRUPT`: integridade, schema, assinatura, hash ou decode falhou;
- `INDETERMINATE_CONFLICT`: versões, epochs, hashes ou autoridades observadas são
  incompatíveis.

Esses rótulos são vocabulário normativo, não aprovação de enum físico.

Somente `INDETERMINATE_UNAVAILABLE` pode consultar uma política de LKG positivo.
`MISSING`, `CORRUPT` e `CONFLICT` nunca recebem grant por LKG; geram bloqueio seguro,
evidência de integridade e, quando aplicável, quarentena/incidente. Um LKG antigo
pode permanecer acessível a operadores autorizados como evidência forense, mas
não participa da decisão operacional.

## 2.3 Classes de operação e matriz obrigatória

| Classe | Estado atual disponível | Somente LKG durante `UNAVAILABLE` | Regra segura |
| --- | --- | --- | --- |
| Leitura de status/UI | Exibe resultado atual. | Pode exibir cópia stale read-only dentro do limite, com idade, origem e motivo; não autoriza outra ação. | `MISSING/CORRUPT/CONFLICT` ficam indisponíveis/incidente; dado antigo é somente forense. |
| Operação explicitamente allowlisted de baixo risco | Executa se a decisão atual conceder. | Pode executar apenas se política específica permitir LKG positivo e todas as condições da Section 2.4 forem válidas. | Default é negar; ausência de allowlist não é permissão. |
| Admissão com quota, capacidade, custo ou chamada externa | Exige projeção atual e contador/reserva autoritativos. | Proibido. | Nega/retry sem consumir, reservar ou chamar provider. |
| Escrita que aumenta direito ou capacidade | Exige autoridade atual e nova revisão válida. | Proibido. | Nega/retry; cache não cria amendment. |
| Escrita neutra ou redutora | Exige policy explícita e precondições atuais. | LKG não concede; só pode terminar comando previamente autorizado se o domínio provar aumento líquido zero, RBAC/risco atuais e lease válida. | Default é negar; dados não são apagados automaticamente. |
| Rating, invoice, fechamento, cobrança ou provider | Exige fatos e políticas atuais. | Proibido. | Pausa/pula tenant ou enfileira; nunca estima, fecha, emite ou chama ASAAS via LKG. |
| Mutação administrativa, contratual ou de catálogo | Exige estado atual, alçada e auditoria. | Proibido. | Somente leitura stale sinalizada é possível. |
| Segurança, abuso, compliance e risco | Exige `riskEpoch` atual. | Proibido conceder com epoch não validado. | Falha fechada; restrição corrente domina grant antigo. |

Uma operação já admitida pode terminar somente pela admission lease bounded do
ADR-0034. LKG não cria, renova ou amplia lease.

Para `max_chatbot_msg_daily`, a allowlist positiva inicial de LKG é **zero**. A
capability envolve quota, custo e efeito externo; uma exceção futura exigirá nova
classificação normativa de operação que seja comprovadamente sem quota, custo,
mutação, irreversibilidade ou risco.

## 2.4 Condições cumulativas de LKG positivo

Uma política de LKG positivo só pode existir quando todas as condições abaixo
forem demonstradas:

1. o resultado corrente é exclusivamente `INDETERMINATE_UNAVAILABLE`;
2. capability e classe de operação constam de allowlist explícita e versionada;
3. a operação não consome quota, não aumenta capacidade/direito, não gera custo,
   não muda contrato e não produz efeito externo irreversível;
4. RBAC, tenant ativo, contexto efetivo e `riskEpoch` foram validados no presente;
5. entrada LKG passa integridade, tenant binding, schema/evaluator, hash, epoch e
   tempo de validade;
6. nenhuma boundary conhecida, restrição nova ou cutover a tornou obsoleta;
7. a resposta e a auditoria registram que a origem foi LKG.

Falhar uma condição produz deny/retry, nunca fallback encadeado.

## 2.5 Envelope conceitual de cache e LKG

Cada decisão derivada precisa vincular, no mínimo:

- tenant efetivo, capability e classe de operação;
- contract revision, snapshot version/hash e bundle version/hash;
- projection/decision hash;
- `contractEpoch` monotônico;
- `riskEpoch` monotônico, separado e dominante;
- schema version, policy version e evaluator version;
- estado, valor, modo e lineage tipada;
- `evaluatedAt`, `staleAt`, `expiresAt` e próxima boundary conhecida;
- motivo da avaliação e prova autenticada de integridade.

Uma epoch inferior nunca substitui uma superior. Ler, copiar entre camadas de
cache ou repetir falha não renova `evaluatedAt`, TTL ou LKG.

O keyspace, port e placement do envelope seguem o ADR-0037. Campos finais,
serialização e rotação de integridade permanecem para os implementation plans,
sem ampliar a semântica e os TTLs desta ADR.

## 2.6 TTLs iniciais e limites temporais

Os limites iniciais aprovados são:

| Uso | Default | Máximo | Renovação por leitura |
| --- | --- | --- | --- |
| Cache fresco de decisão | 30 segundos | 60 segundos | Não |
| LKG positivo para operação de baixo risco allowlisted | — | 5 minutos desde a avaliação autoritativa | Não |
| Quota/capacidade ampliativa, financeiro e mutação administrativa | 0 | 0 | Não aplicável |
| Leitura stale read-only | — | 60 minutos | Não |
| Resultado restritivo usado somente para negar | — | 5 minutos | Não; não afirma contrato atual |
| Validação independente de `riskEpoch` | 30 segundos | 30 segundos | Não |

Jitter pode reduzir stampede no cache fresco, mas não ultrapassa o máximo nem
estende o instante original. `expiresAt` é sempre o menor entre:

- o limite da tabela;
- próximo `effectiveAt` conhecido;
- expiração de grant, promoção, add-on ou exceção;
- boundary da janela de quota/uso;
- restrição ou mudança programada conhecida.

O rollout de `D-14`, aceito no
[ADR-0051](ADR-0051-slo-capacidade-rollout-billing.md), pode reduzir esses valores
quando houver evidência operacional. Aumentá-los exige nova aprovação normativa;
configuração de ambiente nunca amplia silenciosamente o limite.

## 2.7 Invalidação e ordering

Depois do commit local e por publicação confiável/outbox quando cruzar boundary,
devem invalidar ou substituir entradas afetadas:

- nova revisão, snapshot ou projeção;
- chegada de `effectiveAt`;
- início ou fim de promoção, add-on ou exceção;
- suspensão do contrato ou tenant;
- nova restrição de risco ou incidente de segurança;
- cutover do ADR-0035;
- mudança de schema, policy ou evaluator;
- divergência de hash em rebuild;
- quarentena ou invalidação administrativa autorizada.

Consumidores aceitam somente atualização compare-and-set com epoch igual ou
superior conforme precondição válida. Perda de evento de invalidação é limitada
pelo TTL absoluto; cache hit não prolonga a janela. `riskEpoch` mais novo e
restritivo domina grant contratual/cache antigo mesmo quando `contractEpoch` não
muda.

## 2.8 Cold start e degraded mode

Persistência Redis ou existência de uma chave não tornam uma entrada confiável.
Após restart, failover ou perda da projeção, cada entrada deve revalidar tenant,
integridade, schema/evaluator, hashes, epochs, TTL e boundaries.

Sem autoridade acessível nem LKG válido:

- leitura/status responde indisponibilidade explícita;
- admission e escrita negam ou orientam retry sem side effect;
- jobs financeiros pulam/enfileiram somente o tenant afetado;
- não se consulta enum, settings, default, seed ou fonte legada;
- rebuild ocorre tenant-local, single-flight, com concorrência e backoff bounded;
- readiness/degradação é por tenant; falha do tenant A não degrada tenant B.

Uma leitura stale expõe `stale`, idade, instante/origem da avaliação e motivo
sanitizado. Não expõe PII, segredo, payload financeiro ou token. Identidade de
tenant não vira label de métrica de alta cardinalidade; pode existir em log/trace
protegido e autorizado.

## 2.9 Financeiro, provider e comandos já persistidos

LKG nunca autoriza rating, fechamento, geração/reemissão/cancelamento de invoice,
cobrança, refund, write-off ou chamada ASAAS.

Um comando de provider já comprometido localmente pode continuar a partir de
journal/outbox duráveis e idempotentes somente quando:

- a autorização de negócio ocorreu antes do commit;
- o processamento não exige uma nova decisão de entitlement;
- idempotency key, payload autorizado e precondições permanecem válidos;
- policies de provider, segurança e reconciliação do TP-00011 permitem.

Isso é recuperação de comando previamente autorizado, não grant por cache/LKG.
Comando meramente enfileirado para decisão posterior deve ser revalidado antes de
qualquer efeito externo.

## 2.10 Segurança e isolamento

- entitlement exige tenant efetivo validado; contexto ausente não pode usar
  datasource compartilhado nem inferir tenant;
- somente identidade técnica autenticada e de menor privilégio escreve
  cache/projeção/LKG;
- payload usa integridade autenticada, decode estrito, allowlist de schema e limite
  de tamanho;
- tenant binding, hashes e epochs impedem poisoning, replay, rollback e
  substituição cross-tenant;
- RBAC nunca é herdado da decisão em cache;
- tenant ativo, risco e demais boundaries de segurança são revalidados;
- PII, tokens, payloads ASAAS e credenciais de provider não entram na entrada;
- reparo administrativo exige maker-checker, MFA e alçadas de `D-13`, definidos no
  [ADR-0050](ADR-0050-rbac-sod-aprovacoes-financeiras.md); seus controles
  executáveis e evidências continuam pendentes;
- falha de integridade é auditada sem registrar material sensível.

## 2.11 Recuperação e forward repair

A recuperação segue esta ordem:

1. restaurar acesso à autoridade tenant-local;
2. carregar snapshot íntegro ou reconstruir projeção;
3. comparar revision, hashes, `contractEpoch` e `riskEpoch`;
4. publicar somente por CAS que preserve o estado mais novo;
5. invalidar entradas inferiores, expiradas ou corruptas;
6. reconciliar o tenant e suas boundaries conhecidas;
7. retomar cada classe de operação conforme sua policy;
8. revalidar comandos enfileirados, autorização, idempotência e precondições, sem
   replay cego;
9. manter corrupção persistente em quarentena e corrigir por nova revisão/forward
   repair, sem fallback legado.

Recuperação não reescreve invoice finalizada, não retroage contrato e não apaga
evidência.

## 2.12 Boundary da aprovação

Esta decisão foi aprovada como `D-04.2-G — opção A`. Ela não remove o freeze do
TP-00013. Situação vigente:

- `D-04.2-H`: posteriormente aceita no ADR-0037 para ownership físico, APIs,
  ports/adapters, stores, migrations, tabelas, marker, outbox e cache keyspace;
- `D-04.4-D`: aceita por decisão humana explícita no ADR-0042;
- `D-04.4-E` a `D-14`: aceitas como `AI_DELEGATED`, por `AI_AGENT — Codex
  (OpenAI)` sob `AUTH-BILLING-2026-08-25-001`, com revisão humana substantiva
  `NOT_PERFORMED` e `Reviewability: OPEN`; os ADR-0043 a ADR-0051 e as revisões
  vigentes dos ADR-0023 a ADR-0025 são suas fontes canônicas;
- `D-13`: RBAC, SoD, four-eyes, MFA e alçadas estão definidos no ADR-0050;
- `D-14`: rollout, SLOs, thresholds e reduções evidence-based estão definidos no
  ADR-0051, sem declarar medição ou readiness comprovada;
- `D-00`: `RELEASED_WITH_SCOPE — HUMAN_EXPLICIT — TP-00013 local-only`; código,
  DDL, cache keys e testes herméticos locais são permitidos, sem effects/rollout.

---

# 3. Decision Drivers

- preservar snapshot tenant-local como única autoridade;
- distinguir indisponibilidade de ausência, corrupção e conflito;
- não aumentar direito, custo ou efeito financeiro com dado stale;
- manter leituras úteis quando o risco é estritamente observacional;
- impedir fail-open, default e fallback legado após cutover;
- conter replay, poisoning e vazamento cross-tenant;
- recuperar sem rollback de epoch ou retry cego;
- limitar blast radius por tenant e classe de operação;
- manter ASAAS fora da decisão de entitlement.

---

# 4. Considered Options

## Option A: Cache derivado com LKG tipado por operação e fail-safe

Description: Usar cache fresco derivado; admitir LKG positivo somente em
`UNAVAILABLE`, por allowlist de baixo risco, prazo curto e epochs verificadas;
falhar fechado nos demais casos e classes críticas.

Pros:

- mantém segurança e single authority;
- preserva leitura degradada sem transformar stale em autorização ampla;
- diferencia falha transitória de corrupção e conflito;
- limita custo e blast radius com TTL, epochs e operação tipada;
- permite recuperação tenant-local reproduzível.

Cons:

- exige envelope, policies, invalidation e testes de corrida rigorosos;
- algumas operações ficarão temporariamente indisponíveis;
- aumenta complexidade observacional e de recuperação.

## Option B: Apenas cache fresco, sem LKG

Description: Descartar toda entrada ao expirar e bloquear qualquer resultado
enquanto a autoridade estiver indisponível.

Pros:

- modelo menor e muito conservador;
- reduz superfície de replay/staleness.

Cons:

- torna leituras e operações inofensivas indisponíveis em falhas curtas;
- piora experiência e suporte sem ganho material em cenários read-only;
- pode aumentar carga de rebuild e efeito de stampede.

## Option C: Fail-open, default/enum ou LKG amplo

Description: Em falha, usar último valor, default, plano legado ou permissão
otimista para manter disponibilidade.

Pros:

- menor indisponibilidade aparente;
- implementação inicial aparentemente simples.

Cons:

- cria segunda autoridade e permite grant/replay indevidos;
- pode consumir quota, gerar custo, faturar ou chamar provider incorretamente;
- mascara corrupção e conflito;
- viola os ADR-0028, ADR-0030 e ADR-0035.

---

# 5. Decision Outcome

A **Option A** foi aceita.

O sistema privilegia correção e segurança para operações que alteram direitos,
consomem recursos ou produzem efeitos financeiros. Disponibilidade degradada é
mantida somente onde o dado stale é explicitamente observacional ou a operação é
formalmente comprovada como de baixo risco.

---

# 6. Consequences

## Positive Consequences

- Falha transitória não se confunde com contrato ausente ou corrompido.
- Cache comprometido não concede direito sem integridade e epochs válidas.
- Leitura stale é distinguível e não alimenta admission/escrita.
- Quota, financeiro, administração e risco permanecem fail-safe.
- A recuperação não reativa fonte legada nem reduz epoch.

## Negative Consequences

- Entitlement passa a exigir policies por classe de operação e testes de corrida.
- Jobs e ações críticas podem pausar durante indisponibilidade tenant-local.
- Será necessário manter invalidação confiável e reconstrução bounded.

## Neutral Consequences

- Nenhum nome de classe, port, tabela, evento, keyspace ou campo foi aprovado.
- Nenhuma rota, DTO, migration ou configuração foi alterada.
- Nenhuma chamada ASAAS, invoice ou operação do BP Farias foi executada.

---

# 7. Impact

## Compatibility with prior decisions

| Decisão | Efeito desta ADR |
| --- | --- |
| ADR-0010 | Proíbe transportar fail-open, enum, setting ou default ao modelo-alvo. |
| ADR-0011 | Resiliência técnica não pode ampliar direito; retry/circuit breaker respeitam a matriz por operação. |
| ADR-0019 | Rebuild, falha e recovery permanecem isolados por datasource/tenant. |
| ADR-0023 | Provider não decide entitlement; comandos já autorizados dependem de journal/outbox idempotentes. |
| ADR-0028 | Snapshot permanece autoridade e projeção/cache continuam derivados. |
| ADR-0029 | A entrada preserva natureza e lineage tipadas. |
| ADR-0030 | Estado, modo e quota são avaliados de forma determinística; contador atual é obrigatório para admission. |
| ADR-0032 | Boundaries temporais de adoção limitam `expiresAt`. |
| ADR-0034 | Admission lease, debt e efeitos não destrutivos não são substituídos por LKG. |
| ADR-0035 | Não existe fallback legado após cutover, inclusive em cold start/recovery. |
| ADR-0037 | Dá placement ao cache port/keyspace/envelope, aos epochs/outbox e ao tenant guard, sem tornar Redis autoridade. |

## Ownership boundaries

- Billing tenant-local continua owner lógico da autoridade contratual.
- Cache/LKG não pertence semanticamente ao módulo compartilhado apenas por ser
  infraestrutura de cache.
- Módulos consumidores não podem reconstruir entitlement por conta própria.
- A fronteira física e os contratos públicos seguem o ADR-0037.

---

# 8. AI Agent Considerations (For Autonomous Agent Environments)

Agentes DEVEM:

- exigir tenant efetivo e autoridade canônica identificável;
- diferenciar `UNAVAILABLE`, `MISSING`, `CORRUPT` e `CONFLICT`;
- usar os menores TTLs e nunca renová-los por leitura;
- revalidar RBAC/risco no presente;
- pausar quota, custo, financeiro, admin e provider sem estado atual;
- preservar epochs, hashes, lineage e idempotência;
- aplicar o ADR-0037 ao boundary físico e `D-00` somente ao escopo hermético local.

Agentes NÃO DEVEM:

- usar LKG em qualquer falha indistinta;
- usar stale read para admission, escrita, rating ou cobrança;
- aplicar LKG positivo ao chatbot quota/cost path;
- inferir tenant ou usar datasource compartilhado;
- usar enum/settings/default/legado após cutover;
- renovar TTL, reduzir epoch ou fazer replay cego;
- criar código, DDL, APIs, cache keys ou migrations fora do implementation plan autorizado.

---

# 9. Implementation Plan

Sequência executável incremental, autorizada localmente por `D-00` e ainda sujeita
aos gates de artefatos/evidências aplicáveis:

1. implementar os contratos aceitos nos ADR-0037, ADR-0050 e ADR-0051;
2. materializar contracts físicos, envelope, keyspace, ports, events e ownership;
3. implementar evaluator e projeção determinísticos antes do cache;
4. implementar cache fresco e integridade/epoch validation;
5. implementar somente as policies LKG explicitamente aprovadas;
6. implementar invalidation/outbox, cold start e rebuild tenant-local;
7. provar matriz de falha, segurança, corrida, observabilidade e recovery;
8. executar rollout apenas após evidência e autorização operacional próprias.

Itens herméticos locais estão autorizados; rollout e efeitos reais permanecem bloqueados.

---

# 10. Validation

A implementação futura deverá provar ao menos:

- somente `UNAVAILABLE` seleciona LKG positivo;
- `MISSING`, `CORRUPT` e `CONFLICT` nunca produzem grant;
- entrada expirada, hash inválido, tenant divergente, schema desconhecido, epoch
  inferior ou `riskEpoch` não verificável falha fechada;
- cache hit, cópia ou repetição de falha não renova TTL;
- `effectiveAt`, expiração e boundary de janela cortam a entrada antecipadamente;
- nova restrição/epoch de risco invalida ou domina grant antigo;
- contador/reserva indisponível nunca admite aumento de quota/capacidade;
- rating, invoice, cobrança e ASAAS nunca usam LKG;
- stale read não alimenta admission nem escrita;
- mutação administrativa nunca usa stale;
- cold start não consulta defaults, enum, settings ou legado;
- falha/rebuild do tenant A não degrada ou contamina tenant B;
- payload adulterado, replayado ou de schema desconhecido é descartado e auditado;
- recovery publica somente epoch compatível mais nova;
- comando enfileirado é revalidado e idempotente, sem replay cego;
- BP Farias segue a mesma policy pós-cutover, sem exceção hardcoded;
- métricas evitam tenant ID como label de alta cardinalidade;
- testes cobrem corrida invalidation/read, risk epoch, expiry, clock skew, cold
  start, Redis restart, rebuild e recovery.

---

# 11. Risks and Mitigations

| Risk | Mitigation decidida ou boundary |
| --- | --- |
| LKG virar segunda autoridade | Derivado, operação tipada, prazo absoluto e somente `UNAVAILABLE`. |
| Stale ampliar quota/custo | LKG zero para admission, quota, capacidade, financeiro e provider. |
| Restrição nova perder para grant antigo | `riskEpoch` separado, atual e dominante. |
| Poisoning/replay cross-tenant | Tenant binding, integridade autenticada, hashes, epochs e decode estrito. |
| Cache hit eternizar valor | TTL não deslizante e sem renovação por leitura/cópia/falha. |
| Evento de invalidação perdido | TTL absoluto e CAS monotônico. |
| Cold start reativar legado | Proibição explícita de enum/settings/default/fallback. |
| Rebuild causar stampede | Single-flight, bounded concurrency, jitter e backoff. |
| Falha global por um tenant | Readiness, fila, retry e rebuild isolados por tenant. |
| Recuperação duplicar efeito externo | Journal/outbox idempotente e revalidação; sem replay cego. |

---

# 12. Related ADRs

- [ADR-0000 - Governança documental](../../harness/governance/decisions/ADR-0000-governanca-do-harness-documental.md)
- [ADR-0010 - Parametrização de planos e limites](ADR-0010-tenant-plan-parametrization.md)
- [ADR-0011 - Resiliência](ADR-0011-resilience-retry-circuit-breaker.md)
- [ADR-0019 - Database per tenant](ADR-0019-database-per-tenant.md)
- [ADR-0023 - Integração agnóstica de pagamentos](ADR-0023-agnostic-payment-provider-integration.md)
- [ADR-0028 - Entitlements versionados tenant-local](ADR-0028-entitlements-versionados-tenant-local.md)
- [ADR-0029 - Taxonomia tipificada de entitlements](ADR-0029-taxonomia-tipificada-entitlements.md)
- [ADR-0030 - Composição determinística e enforcement](ADR-0030-composicao-deterministica-enforcement-entitlements.md)
- [ADR-0032 - Adoção versionada e grandfathering](ADR-0032-adocao-versionada-grandfathering-entitlements.md)
- [ADR-0034 - Efeitos não destrutivos](ADR-0034-efeitos-transicao-nao-destrutiva-entitlements.md)
- [ADR-0035 - Migração evidence-first do legado](ADR-0035-migracao-evidence-first-entitlements-legados.md)
- [ADR-0037 - Boundary físico e ownership de entitlements](ADR-0037-boundary-fisico-entitlements-billing.md)

---

# 13. References

- [REQ-00005 - Matriz de funcionalidades por plano](../product/requirements/REQ-00005-plan-feature-matrix.md)
- [REQ-00011 - Limites de uso e billing do chatbot](../product/requirements/REQ-00011-chatbot-usage-limits-and-billing.md)
- [REQ-00042 - Billing enterprise](../product/requirements/REQ-00042-enterprise-multitenant-billing-invoicing.md)
- [UC-00038 - Catálogo, pricing e promoções](../product/use-cases/UC-00038-billing-catalog-pricing-promotions.md)
- [UC-00039 - Contratos, assinaturas e amendments](../product/use-cases/UC-00039-billing-contract-subscription-amendments.md)
- [UC-00040 - Uso, rating e fechamento](../product/use-cases/UC-00040-billing-usage-rating-invoice-close.md)
- [TP-00013 - Enterprise Billing Implementation](../delivery/plans/TP-00013-enterprise-billing-implementation-task-plan.md)
- [Manifesto de módulos](../architecture/module-registry.md)

---

# 14. Decision Lifecycle

Current State: **Accepted**

A aprovação explícita de 2026-08-23 alcança `D-04.2-G — opção A`, conforme a
alternativa recomendada apresentada imediatamente antes do aceite. `D-04.2-H` foi
aceita no ADR-0037. `D-04.4-D` foi aceita por decisão humana explícita no ADR-0042;
`D-04.4-E` a `D-14` foram aceitas como `AI_DELEGATED`, por `AI_AGENT — Codex
(OpenAI)` sob `AUTH-BILLING-2026-08-25-001`, com revisão humana `NOT_PERFORMED` e
`Reviewability: OPEN`. Essa conclusão decisória não comprova artefatos nem
readiness: `D-00` está `RELEASED_WITH_SCOPE — HUMAN_EXPLICIT — TP-00013
local-only`; implementação/testes herméticos são permitidos e evidências/readiness continuam pendentes.

---

# 15. Change Log

| Version | Date | Author | Changes |
| --- | --- | --- | --- |
| 1.3 | 2026-08-25 | Solicitante humano, proprietário declarado / Codex (IA), materialização | Registra `D-00 = RELEASED_WITH_SCOPE — HUMAN_EXPLICIT — TP-00013 local-only`; permite backend/frontend/DDL/migrations/cache keys/testes herméticos locais e mantém chamadas externas, Sandbox ASAAS, piloto BP Farias, produção, flags `ON` e efeitos reais bloqueados. |
| 1.2 | 2026-08-25 | Codex / Arquitetura | Reconcilia `D-04.4-D` humana e `D-04.4-E` a `D-14` `AI_DELEGATED` sob `AUTH-BILLING-2026-08-25-001`, aponta alçadas e rollout aos ADR-0050/ADR-0051 e preserva `D-00`, artefatos e evidências como gates pendentes. |
| 1.1 | 2026-08-24 | Responsável pelo produto / Arquitetura | Registra ADR-0037 como decisão subsequente de `D-04.2-H`: cache port/keyspace/envelope Redis derivado, sem L1 ou SQL-LKG, epochs/outbox e tenant guard recebem placement em Billing; `D-00` continua aberto. |
| 1.0 | 2026-08-23 | Responsável pelo produto / Arquitetura | Aceite de `D-04.2-G — opção A`: cache derivado, LKG apenas para indisponibilidade e operação allowlisted de baixo risco, TTLs absolutos, epochs, invalidação, cold start, recuperação e fail-safe para quota, financeiro, administração, provider e risco. |

---

# 16. Repository Structure

Esta decisão reside em:

```text
docs/adrs/ADR-0036-cache-lkg-fail-safe-entitlements.md
```

Os alvos físicos estão registrados no ADR-0037 e podem ser materializados
incrementalmente no escopo local-only de `D-00`.

---

# 17. Review Process

1. A opção A foi recomendada ao responsável pelo produto; cache sem LKG e
   fail-open/default/LKG amplo foram apresentados com seus trade-offs.
2. O responsável pelo produto aprovou explicitamente a opção A em 2026-08-23.
3. Arquitetura materializou classes de operação, failure states, TTLs, epochs,
   invalidação, cold start, segurança e recovery sem autorizar implementação.
4. Mudança normativa exige nova versão aceita ou ADR sucessora.
5. A aprovação subsequente de `D-04.2-H` pertence ao ADR-0037; decisões
   posteriores não podem ser inferidas deste documento.
6. A reconciliação vigente registra `D-04.4-D` como `HUMAN_EXPLICIT` e
   `D-04.4-E` a `D-14` como `AI_DELEGATED` sob
   `AUTH-BILLING-2026-08-25-001`; nenhuma revisão humana substantiva dessas
   decisões delegadas foi realizada (`NOT_PERFORMED`), e a revisão permanece
   aberta (`OPEN`) sem apagar a origem de IA.

---

# 18. Notes

Estados, envelope, epochs, cache, LKG, allowlist e CAS são contratos conceituais.
Sua representação física segue o ADR-0037 e os detalhes executáveis permanecem
para os implementation plans.

O AS-IS continua inalterado; em especial, esta ADR não corrige ainda o fail-open
do chatbot, os defaults de tenant, o fallback de datasource ou as rotas Billing.
