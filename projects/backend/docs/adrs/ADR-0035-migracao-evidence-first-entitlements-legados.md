---
document_id: "ADR-0035"
primary_nature: "Decisao"
objective: "Definir como tenants ainda governados por enum, settings e demais fontes legadas recebem baseline canônico de entitlement, shadow observacional e cutover tenant-local seguro."
scope: "População legada, inventário e classificação de evidências, fingerprint de origem, manifest de mapping versionado, baseline canônico, backfill idempotente, shadow comparison, reconciliação, cutover fenced, tratamento de commit ambíguo, reparo, aposentadoria do fallback e piloto BP Farias."
non_objectives: "Definir cache, last-known-good ou degraded mode depois do cutover; aprovar nomes físicos de tabelas, classes, ports, eventos, endpoints ou marker; criar DDL/OpenAPI; escolher TTLs, duração/volume do shadow, cohorts, alçadas finais, retention, backup, cleanup destrutivo, lifecycle, pricing, rating, invoice, cobrança, provider ou autorizar implementação."
owner: "Arquitetura / Billing / Produto / Segurança / Dados"
status: "Accepted"
date: "2026-08-25"
version: "1.4"
keywords: "legacy entitlement migration, evidence first, source fingerprint, mapping manifest, backfill, shadow comparison, reconciliation, fenced cutover, quarantine, BP Farias, no fallback"
related_files: "docs/product/requirements/REQ-00005-plan-feature-matrix.md`, `docs/product/requirements/REQ-00011-chatbot-usage-limits-and-billing.md`, `docs/product/requirements/REQ-00042-enterprise-multitenant-billing-invoicing.md`, `docs/product/use-cases/UC-00038-billing-catalog-pricing-promotions.md`, `docs/product/use-cases/UC-00039-billing-contract-subscription-amendments.md`, `docs/product/use-cases/UC-00040-billing-usage-rating-invoice-close.md`, `docs/delivery/plans/TP-00013-enterprise-billing-implementation-task-plan.md`, `docs/adrs/ADR-0034-efeitos-transicao-nao-destrutiva-entitlements.md`, `docs/adrs/ADR-0036-cache-lkg-fail-safe-entitlements.md`, `docs/adrs/ADR-0037-boundary-fisico-entitlements-billing.md"
code_references: "AS-IS em `Tenant.plan`, `SubscriptionPlan`, `tenant_subscriptions`, Billing `subscriptions`, `TenantSettings`, `chatbot_functions.required_plan`, migrations legadas e `TenantPlanInvoiceSourceAdapter`; boundary e destinos planejados sob `backend/src/main/java/br/com/duoset/saas_service/contexts/billing/` definidos no ADR-0037, ainda não implementados."
principal_statement: "Cada tenant legado será migrado isoladamente por inventário e evidência verificável, manifest imutável com target exato, backfill tenant-local e shadow sem efeitos; somente após reconciliação sem divergência material inexplicada ocorrerá cutover fenced para uma única autoridade canônica, sem fallback ao legado e sem participação do ASAAS."
---

# ADR-0035 - Migração evidence-first de entitlements legados por tenant

- Document ID: `ADR-0035`
- Primary Nature: `Decisao`
- Objective: Definir como tenants ainda governados por enum, settings e demais fontes legadas recebem baseline canônico de entitlement, shadow observacional e cutover tenant-local seguro.
- Scope: População legada, inventário e classificação de evidências, fingerprint de origem, manifest de mapping versionado, baseline canônico, backfill idempotente, shadow comparison, reconciliação, cutover fenced, tratamento de commit ambíguo, reparo, aposentadoria do fallback e piloto BP Farias.
- Non-objectives: Definir cache, last-known-good ou degraded mode depois do cutover; aprovar nomes físicos de tabelas, classes, ports, eventos, endpoints ou marker; criar DDL/OpenAPI; escolher TTLs, duração/volume do shadow, cohorts, alçadas finais, retention, backup, cleanup destrutivo, lifecycle, pricing, rating, invoice, cobrança, provider ou autorizar implementação.
- Keywords: legacy entitlement migration, evidence first, source fingerprint, mapping manifest, backfill, shadow comparison, reconciliation, fenced cutover, quarantine, BP Farias, no fallback
- Related Files: `docs/product/requirements/REQ-00005-plan-feature-matrix.md`, `docs/product/requirements/REQ-00011-chatbot-usage-limits-and-billing.md`, `docs/product/requirements/REQ-00042-enterprise-multitenant-billing-invoicing.md`, `docs/product/use-cases/UC-00038-billing-catalog-pricing-promotions.md`, `docs/product/use-cases/UC-00039-billing-contract-subscription-amendments.md`, `docs/product/use-cases/UC-00040-billing-usage-rating-invoice-close.md`, `docs/delivery/plans/TP-00013-enterprise-billing-implementation-task-plan.md`, `docs/adrs/ADR-0034-efeitos-transicao-nao-destrutiva-entitlements.md`, `docs/adrs/ADR-0036-cache-lkg-fail-safe-entitlements.md`, `docs/adrs/ADR-0037-boundary-fisico-entitlements-billing.md`
- Code References: AS-IS em `Tenant.plan`, `SubscriptionPlan`, `tenant_subscriptions`, Billing `subscriptions`, `TenantSettings`, `chatbot_functions.required_plan`, migrations legadas e `TenantPlanInvoiceSourceAdapter`; boundary e destinos planejados sob `backend/src/main/java/br/com/duoset/saas_service/contexts/billing/` definidos no ADR-0037, ainda não implementados.
- Principal Decision: Cada tenant legado será migrado isoladamente por inventário e evidência verificável, manifest imutável com target exato, backfill tenant-local e shadow sem efeitos; somente após reconciliação sem divergência material inexplicada ocorrerá cutover fenced para uma única autoridade canônica, sem fallback ao legado e sem participação do ASAAS.
- Date: 2026-08-25
- Status: Accepted
- Version: 1.4
- Authors / Owners: Arquitetura / Billing / Produto / Segurança / Dados
- Reviewers: Responsável pelo produto, com aprovação explícita de `D-04.2-F — opção A` em 2026-08-23; Arquitetura
- Stakeholders: Produto, Financeiro, Jurídico, Backend, Frontend, Segurança, Dados, Operações e tenants contratantes
- Supersedes: N/A; fecha a migração legada deixada aberta pelos ADR-0028, ADR-0032 e ADR-0034 e restringe bridges/fallbacks do ADR-0010.
- Superseded by: N/A

---

# 1. Context

O modelo-alvo dos ADR-0028 a ADR-0034 usa bundle global publicado, revisão e
snapshot completos no banco dedicado do tenant e avaliação por read model derivado.
O AS-IS, porém, distribui informações por fontes que não representam o mesmo fato:

- `Tenant.plan`/`SubscriptionPlan` e `tenant_subscriptions.plan`;
- Billing `subscriptions.plan/status`;
- limites numéricos e defaults técnicos de `TenantSettings`;
- requisitos de plano em `chatbot_functions.required_plan`;
- configuração server-side de preço/catálogo e faturas do Release 0;
- uso histórico sem todas as dimensões exigidas pelo modelo-alvo.

Essas fontes podem divergir. Um seed `START`, um default, uma fatura ou um provider
ID demonstra estado técnico ou financeiro observado, mas não comprova sozinho o
conteúdo contratual, a versão do bundle ou a origem tipada de cada concessão.
Mapeá-los por inferência permissiva poderia conceder ou retirar direitos em
silêncio; manter dual-read criaria duas autoridades.

BP Farias possui banco dedicado e evidências legadas úteis para um piloto, mas seu
seed e o Release 0 não substituem uma attestation explícita de migração.

---

# 2. Decision Statement

## 2.1 População e autoridade

A população legada deve ser congelada e identificável antes do rollout. O critério
e o instante operacional de congelamento seguem os targets e gates aceitos em
`D-14` no [ADR-0051](ADR-0051-slo-capacidade-rollout-billing.md); medição,
calibração e readiness continuam pendentes.

- antes do cutover de um tenant, somente o legado responde decisões operacionais;
- o candidato canônico e o shadow não constituem segunda autoridade;
- tenants criados depois da entrada canônica aprovada não passam pelo bridge;
- depois do cutover confirmado, somente snapshot e read model canônicos são usados;
- enum, settings, defaults e tabelas legadas nunca são fallback pós-cutover.

O processamento ocorre para exatamente um tenant e um datasource dedicado por vez.
Não existe transação distribuída, join ou fan-out atômico entre bancos de tenants.

## 2.2 Inventário e classificação de evidências

Cada tenant recebe um inventário completo das fontes aplicáveis e um fingerprint
imutável de seu conteúdo normalizado, versões de schema e instante observado. O
fingerprint prova igualdade/drift sem copiar segredo ou PII desnecessária para o
control plane.

Cada fato inventariado é classificado em exatamente uma categoria conceitual:

- `EXPLICIT_CONTRACT_EVIDENCE`;
- `CONSISTENT_LEGACY_OBSERVATION`;
- `TECHNICAL_DEFAULT_OR_SEED`;
- `HISTORICAL_FINANCIAL_FACT`;
- `CONFLICTING`;
- `MISSING`;
- `UNSUPPORTED`.

Sua persistência física segue as famílias de evidência/migração do ADR-0037.
Default, seed, invoice,
preço configurado e provider ID podem corroborar ou revelar conflito, mas não
criam entitlement automaticamente.

Uma evidência contratual explícita ou uma attestation de migração aprovada pode
selar o alvo. Observações consistentes somente são aceitas quando a regra explícita
do manifest e a alçada aplicável permitirem; ambiguidade, conflito, ausência
obrigatória ou valor não suportado colocam o candidato em quarentena, nunca em
default permissivo.

## 2.3 Manifest de mapping imutável

Todo backfill usa um manifest de mapping versionado, imutável e aprovado que fixa:

- identidade, versão e hash do próprio manifest;
- fontes, versões de schema e normalização esperadas;
- regra de classificação, precedência e conflito de evidências;
- versão e hash exatos do bundle-alvo, nunca `latest`;
- capability, tipo, operador, unidade, janela, dimensões, valor e modo;
- natureza tipada e lineage de cada contribuição;
- data impact policy aplicável;
- evidências e aprovações requeridas;
- critérios de quarentena e incompatibilidade.

Alterar mapping exige outro manifest/version/hash e nova execução. Limite customizado
não vira override genérico: sem evidência que permita classificá-lo como base,
add-on, promoção ou exceção válida, o tenant permanece em quarentena.

## 2.4 Baseline canônico inicial

O backfill candidato materializa, no banco dedicado do tenant:

- uma revisão canônica inicial cuja causa conceitual é migração legada;
- um `ContractEntitlementSnapshot` completo e imutável;
- o read model derivado e reconstruível;
- bundle version/hash exatos e lineage tipada;
- source fingerprint e manifest version/hash;
- referências sanitizadas de evidência e aprovação;
- instante observado, `effectiveAt` candidato e relatório de conflitos.

Esses itens são conceitos; seu placement e famílias de tabelas seguem o ADR-0037,
enquanto campos e DDL finais permanecem para os implementation plans.

Sem evidência exata, o sistema não inventa data contratual histórica. O baseline
torna-se prospectivo no cutover; períodos, uso, invoices e documentos anteriores
permanecem fatos legados imutáveis e não são redistribuídos, enriquecidos ou
reclassificados por suposição.

## 2.5 Backfill seguro, idempotente e resumível

Cada execução:

- abre somente o datasource do tenant resolvido e validado;
- usa transação local e identidade idempotente ligada a tenant, source fingerprint,
  manifest e target exatos;
- persiste evidência/checkpoint suficiente para retomar sem duplicar revisão;
- reproduz o mesmo snapshot/hash quando a entrada for idêntica;
- invalida o candidato e exige nova captura se a origem sofrer drift;
- isola falha, retry e quarentena de cada tenant;
- não atribui dimensão histórica ausente, inclusive channel de usage, por inferência;
- não altera invoice finalizada, provider command, cobrança, pagamento ou ledger.

Um orquestrador futuro poderá referenciar o tenant por identidade opaca, mas não
transportará dados comerciais entre bancos. Ownership e contrato físico pertencem
ao slice de Billing e aos stores separados do ADR-0037.

## 2.6 Shadow estritamente observacional

Durante shadow, o legado continua respondendo. O candidato canônico apenas calcula
a decisão que teria produzido e a compara por capability, valor, operador, modo,
estado, version/hash e lineage.

Shadow não pode:

- permitir ou negar operação real;
- reservar ou consumir quota;
- criar dívida, lease ou transição efetiva;
- gerar usage, rating, invoice, cobrança ou efeito financeiro;
- chamar ASAAS ou qualquer provider;
- escrever de volta no legado ou no runtime canônico autoritativo.

Divergências devem distinguir representação semanticamente equivalente, conflito
de fonte, ausência de target e mudança material de direito. O cutover exige zero
divergência material inexplicada. Duração, volume, amostragem e cohort seguem o
ADR-0051; eles não podem relaxar esse critério sem nova decisão normativa.

## 2.7 Reconciliação

Antes do cutover, a reconciliação prova ao menos:

- tenant, realm e datasource corretos;
- source fingerprint ainda vigente;
- manifest e target version/hash exatos;
- snapshot/read model completos, reconstruíveis e com hashes esperados;
- valores, tipos, modos, policies e lineage por capability;
- ocupação e dívida projetada conforme ADR-0034;
- uso e reservas preservados sem reset;
- conflitos entre plan, subscription, settings e required plan resolvidos ou
  explicitamente bloqueados;
- ausência de grant derivado apenas de seed/default;
- nenhuma alteração em invoices ou períodos finalizados;
- nenhuma divergência material inexplicada no shadow.

## 2.8 Cutover fenced por tenant

O protocolo conceitual de cutover é:

1. bloquear novas mutações legadas daquele tenant;
2. drenar ou concluir operações relevantes conforme políticas aprovadas;
3. recapturar e validar o source fingerprint;
4. revalidar manifest, evidências, snapshot, target hash e blockers;
5. ativar baseline, read model e autoridade canônica em uma transação tenant-local;
6. tornar a confirmação observável somente depois do commit;
7. verificar leituras canônicas e manter o legado read-only para auditoria.

O cutover deve usar fence/generation e expectativa de estado equivalentes, sem
aprovar aqui seu marker físico. Resposta ambígua entre commit e acknowledgement
mantém o fence e força reconciliação; não há retry cego nem alternância de
autoridade por tentativa.

O lifecycle conceitual pode representar `DISCOVERED`, `MAPPED`, `BACKFILLED`,
`SHADOW_VALIDATED`, `READY`, `CUTOVER_COMMITTED` e `VERIFIED`, com saídas seguras
de quarentena ou reparo. Esses rótulos não aprovam enum, tabela ou API; sua
representação operacional usa as famílias de migration/evidence e o marker
`LEGACY`/`SHADOW`/`CANONICAL`/`QUARANTINED` do ADR-0037.

## 2.9 Abort, recuperação e correção

- Antes do commit, o candidato pode ser abortado sem apagar evidência; o fence só
  é liberado depois de revalidação segura.
- Commit ambíguo é reconciliado antes de qualquer retry ou mudança de autoridade.
- Depois do commit, enum/settings não voltam a ser autoridade e não existe pointer
  rollback para o legado.
- Correção pós-cutover cria nova revisão/snapshot canônicos e preserva o baseline
  migrado como evidência.
- Rollback de aplicação deve continuar reconhecendo que o tenant já é canônico;
  uma versão antiga incapaz disso não é rollback seguro.

Ausência/corrupção/cache/LKG do estado canônico após cutover segue o ADR-0036:
somente `UNAVAILABLE` pode considerar LKG positivo low-risk allowlisted;
`MISSING`, `CORRUPT` e `CONFLICT` falham de forma segura, e nenhuma condição
reativa fallback legado.

## 2.10 Aposentadoria do legado

Depois do cutover verificado, escrita e leitura de runtime no legado cessam. O
legado pode permanecer read-only pelo período de auditoria aprovado, mas nunca
como decisão operacional oculta.

Cleanup físico ou exclusão exige janela comprovada de zero reads/writes, retenção,
backup/restore validado, gate destrutivo humano próprio, observabilidade e os
controles do ADR-0051. A liberação local-only de `D-00` não autoriza remover coluna,
tabela, seed ou migration.

## 2.11 BP Farias

BP Farias será candidato ao primeiro cohort controlado, não uma exceção hardcoded.

- seed `START`, defaults e invoice Release 0 são evidência diagnóstica, não contrato;
- Produto/Financeiro, conforme a autoridade e o maker-checker definidos em `D-13`
  no [ADR-0050](ADR-0050-rbac-sod-aprovacoes-financeiras.md), devem emitir
  attestation explícita com bundle version/hash e termos aplicáveis; os controles
  executáveis dessa alçada ainda precisam ser materializados e comprovados;
- somente então o manifest pode produzir baseline candidato;
- shadow e reconciliação precedem o cutover;
- invoices Release 0 permanecem imutáveis;
- nenhuma chamada ASAAS é necessária ou permitida neste processo;
- ausência de attestation suficiente mantém o tenant no legado/quarentena, sem
  fallback permissivo ou entitlement inventado.

## 2.12 Segurança e segregação

- execução usa identidade técnica de menor privilégio e acesso a um tenant por vez;
- seleção de tenant/datasource, autorização, maker-checker, MFA e alçadas seguem
  o ADR-0050; implementação, configuração e evidência desses controles permanecem
  gates obrigatórios;
- segredo, token ASAAS, payload financeiro e PII desnecessária não entram no
  manifest, fingerprint, log ou control plane;
- evidências são referenciadas, integras, redigidas e auditáveis;
- dry-run/shadow respeitam o mesmo isolamento de produção e não viram canal de
  enumeração cross-tenant;
- falha do tenant A não muda estado, retry, checkpoint ou autoridade do tenant B.

## 2.13 Boundary da aprovação

Esta decisão foi aprovada como `D-04.2-F — opção A`. Ela não remove o freeze do
TP-00013. Situação vigente:

- `D-04.2-G`: posteriormente aceita no ADR-0036 para ausência/corrupção, cache
  derivado, LKG limitado, epochs, TTLs e degraded mode fail-safe;
- `D-04.2-H`: posteriormente aceita no ADR-0037 para ownership físico, APIs,
  ports/adapters, stores, migrations, tabelas, marker, outbox e cache;
- `D-04.4-D`: aceita por decisão humana explícita no ADR-0042;
- `D-04.4-E` a `D-14`: aceitas como `AI_DELEGATED`, por `AI_AGENT — Codex
  (OpenAI)` sob `AUTH-BILLING-2026-08-25-001`, com revisão humana substantiva
  `NOT_PERFORMED` e `Reviewability: OPEN`; os ADR-0043 a ADR-0051 e as revisões
  vigentes dos ADR-0023 a ADR-0025 são suas fontes canônicas;
- `D-13`: RBAC, SoD, four-eyes, MFA e alçadas estão definidos no ADR-0050;
- `D-14`: cohorts, shadow, piloto, observabilidade e rollback operacional estão
  definidos no ADR-0051, sem evidência de readiness medida;
- `D-00`: `RELEASED_WITH_SCOPE — HUMAN_EXPLICIT — TP-00013 local-only`;
  implementação/migração herméticas locais são permitidas, cleanup e efeitos externos não.

---

# 3. Decision Drivers

- converter múltiplas observações legadas sem transformá-las em contrato por acaso;
- manter exatamente uma autoridade em cada instante;
- impedir grant, redução ou dado histórico inventado por default;
- preservar database-per-tenant e transações locais;
- tornar backfill, retry, shadow e cutover reproduzíveis e auditáveis;
- conter blast radius e permitir quarentena individual;
- preservar invoices e fatos financeiros finalizados;
- testar BP Farias sem tornar seu seed uma regra especial;
- manter provider e ASAAS fora da autoridade de entitlement.

---

# 4. Considered Options

## Option A: Migração evidence-first por tenant

Description: Inventário/fingerprint, manifest imutável, baseline candidato,
backfill idempotente, shadow observacional e cutover fenced individual.

Pros:

- preserva isolamento e reduz blast radius;
- explicita conflitos e impede defaults permissivos;
- produz evidência reexecutável e cutover reconciliável;
- elimina dual authority depois do corte;
- permite piloto realista sem reescrever histórico.

Cons:

- exige inventário, attestation, manifest e governança operacional;
- tenants ambíguos permanecem em quarentena até decisão humana válida;
- custa mais que converter enums diretamente.

## Option B: Big-bang por enum/default

Description: Mapear `START/BUSINESS/PREMIUM` e settings para bundles no deploy e
cortar todos os tenants simultaneamente.

Pros:

- menor trabalho inicial;
- caminho aparentemente curto.

Cons:

- transforma seed/default em contrato;
- não resolve fontes divergentes;
- possui grande blast radius e rollback difícil;
- pode conceder ou retirar direitos silenciosamente.

## Option C: Dual-read permanente com fallback legado

Description: Usar canônico quando disponível e enum/settings quando ausente,
indeterminado ou divergente.

Pros:

- reduz bloqueio aparente no rollout inicial.

Cons:

- mantém duas autoridades e recria `COALESCE`/fail-open;
- esconde corrupção e drift;
- torna auditoria, suporte e sunset não determinísticos;
- viola os ADR-0028, ADR-0030 e ADR-0034.

---

# 5. Decision Outcome

A **Option A** foi aceita.

O custo adicional de inventário e attestation é menor que o risco de conceder,
retirar ou cobrar direitos com base em seed técnico. Quarentena é resultado seguro,
não falha a ser mascarada por fallback.

---

# 6. Consequences

## Positive Consequences

- Um tenant pode ser migrado e verificado sem afetar os demais.
- A origem de cada entitlement permanece demonstrável.
- Shadow não cria efeito operacional ou financeiro.
- O cutover termina com uma única autoridade.
- Histórico e invoices permanecem reproduzíveis.

## Negative Consequences

- Será necessário governar manifests, fingerprints, evidências e checkpoints.
- Conflitos legados exigirão attestation ou remediação manual.
- Rollback pós-cutover precisa ser forward repair, não retorno ao enum.

## Neutral Consequences

- Nenhum schema, endpoint, port, evento, TTL ou tamanho de cohort foi escolhido.
- Nenhuma chamada ASAAS, reemissão, cobrança ou invoice foi autorizada.
- Nenhum tenant foi migrado por esta aprovação documental.

---

# 7. Impact

## Compatibility with prior decisions

| Decisão | Efeito desta ADR |
| --- | --- |
| ADR-0019 | Mantém execução e commit isolados no banco dedicado de cada tenant. |
| ADR-0028 | Materializa baseline no snapshot autoritativo; read model continua derivado e reconstruível. |
| ADR-0029 | Exige natureza tipada e lineage; seed/default não vira override genérico. |
| ADR-0030 | Shadow compara o resultado determinístico sem criar fallback. |
| ADR-0032 | Baseline inicial não reescreve revisões futuras nem usa `latest`. |
| ADR-0034 | Ocupação/dados no cutover seguem debt e policies não destrutivas. |
| ADR-0036 | Pós-cutover mantém snapshot como autoridade, proíbe fallback legado e limita cache/LKG por estado e classe de operação. |
| ADR-0037 | Dá placement a manifest/runs/evidence/differences/authority marker e outbox, com adapters e migrations platform/tenant separados. |
| ADR-0010 | Enum/settings permanecem evidência legada e deixam de ser runtime após o corte. |
| ADR-0023 | Provider não participa do mapping, backfill, shadow ou cutover. |

## Ownership boundaries

- Billing tenant-local será owner lógico do baseline e snapshot.
- Fontes legadas são lidas somente para inventário/migração antes do corte.
- O control plane não recebe dados comerciais tenant-scoped em massa.
- ASAAS não atesta contrato, não mapeia entitlement e não confirma cutover.
- Boundaries físicos seguem o ADR-0037.

---

# 8. AI Agent Considerations (For Autonomous Agent Environments)

Agentes DEVEM:

- trabalhar em um tenant/datasource por unidade de execução;
- tratar manifest e target por versão/hash exatos;
- manter shadow sem side effects;
- colocar ambiguidade/conflito em quarentena;
- reconciliar commit ambíguo antes de retry;
- preservar invoices, uso e evidências históricas;
- aplicar o ADR-0036 após o cutover e o ADR-0037 ao boundary físico, usando
  `D-00` somente no escopo hermético local.

Agentes NÃO DEVEM:

- mapear enum/default/seed diretamente como contrato;
- inventar dimensão, effective date, add-on, promoção ou exceção;
- usar `latest`, fallback legado ou dual-read após cutover;
- chamar ASAAS durante inventário, backfill, shadow ou cutover;
- executar fan-out cross-tenant ou transação distribuída;
- remover legado ou executar piloto BP Farias; DDL/API/código locais seguem o plano autorizado.

---

# 9. Implementation Plan

Sequência executável incremental, autorizada localmente por `D-00` e ainda sujeita
aos gates de artefatos/evidências aplicáveis:

1. implementar os contratos aceitos nos ADR-0036, ADR-0037, ADR-0050 e ADR-0051;
2. materializar contrato físico, alçadas, segurança, observabilidade e runbook;
3. implementar inventário/fingerprint e manifest validation puros;
4. implementar backfill tenant-local idempotente e dry-run;
5. implementar shadow sem side effects e relatório de reconciliação;
6. provar fence, commit ambíguo, single authority e forward repair;
7. executar BP Farias apenas como cohort aprovado e observado, fora desta liberação;
8. aposentar o legado somente após os critérios do ADR-0051 e gate destrutivo próprio.

Os itens herméticos locais 1 a 6 estão autorizados; piloto, cleanup e efeitos
externos permanecem bloqueados.

---

# 10. Validation

A implementação futura deverá provar ao menos:

- retry com mesma origem/manifest gera uma única revisão e o mesmo snapshot/hash;
- drift da origem invalida candidato antes do corte;
- `Tenant.plan` e subscription conflitantes produzem quarentena;
- seed/default isolado não produz grant;
- valor customizado sem lineage tipada não vira override genérico;
- falta de dimensão histórica permanece explicitamente desconhecida;
- shadow não nega, reserva, mede, fatura ou chama provider;
- diferença material inexplicada bloqueia cutover;
- falha do tenant A não toca tenant B;
- commit ambíguo reconcilia sem alternar autoridade;
- runtime verificado pós-cutover não consulta legado;
- rollback de aplicação preserva o marker canônico conceitual;
- correção pós-cutover cria nova revisão/snapshot;
- invoice finalizada e períodos anteriores permanecem byte/semanticamente imutáveis;
- BP Farias sem attestation permanece em quarentena;
- nenhuma credencial, PII ou payload ASAAS aparece em manifest/log/fingerprint.

---

# 11. Risks and Mitigations

| Risk | Mitigation decidida ou boundary |
| --- | --- |
| Seed virar contrato | Classificação técnica sem poder de grant; attestation/manifest aprovados. |
| Duas autoridades | Shadow observacional; cutover fenced; zero fallback pós-corte. |
| Drift durante backfill | Fingerprint revalidado antes do commit. |
| Retry duplicar baseline | Identidade idempotente e reconciliação tenant-local. |
| Cross-tenant leak | Um datasource por execução, identidade mínima e sem fan-out de dados. |
| Histórico ser inventado | Sem backdating ou enriquecimento sem evidência. |
| Rollback reativar enum | Marker canônico respeitado; correção forward-only. |
| BP Farias receber regra especial | Mesmo manifest/processo, com attestation explícita. |
| ASAAS virar autoridade | Provider completamente fora deste fluxo. |
| Cleanup destruir evidência | Gate destrutivo humano separado conforme ADR-0051, retenção e restore validados; `D-00` local-only não autoriza exclusão. |

---

# 12. Related ADRs

- [ADR-0000 - Governança documental](../../harness/governance/decisions/ADR-0000-governanca-do-harness-documental.md)
- [ADR-0006 - Auditoria e compliance](ADR-0006-audit-compliance.md)
- [ADR-0010 - Parametrização de planos e limites](ADR-0010-tenant-plan-parametrization.md)
- [ADR-0019 - Database per tenant](ADR-0019-database-per-tenant.md)
- [ADR-0023 - Integração agnóstica de pagamentos](ADR-0023-agnostic-payment-provider-integration.md)
- [ADR-0028 - Entitlements versionados tenant-local](ADR-0028-entitlements-versionados-tenant-local.md)
- [ADR-0029 - Taxonomia tipificada de entitlements](ADR-0029-taxonomia-tipificada-entitlements.md)
- [ADR-0030 - Composição determinística e enforcement](ADR-0030-composicao-deterministica-enforcement-entitlements.md)
- [ADR-0032 - Adoção versionada e grandfathering](ADR-0032-adocao-versionada-grandfathering-entitlements.md)
- [ADR-0034 - Efeitos não destrutivos](ADR-0034-efeitos-transicao-nao-destrutiva-entitlements.md)
- [ADR-0036 - Cache/LKG fail-safe de entitlements](ADR-0036-cache-lkg-fail-safe-entitlements.md)
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

A aprovação explícita de 2026-08-23 alcança `D-04.2-F — opção A`, conforme a
alternativa recomendada apresentada imediatamente antes do aceite. `D-04.2-G` foi
aceita no ADR-0036 e `D-04.2-H` no ADR-0037. `D-04.4-D` foi aceita por decisão
humana explícita no ADR-0042; `D-04.4-E` a `D-14` foram aceitas como
`AI_DELEGATED`, por `AI_AGENT — Codex (OpenAI)` sob
`AUTH-BILLING-2026-08-25-001`, com revisão humana `NOT_PERFORMED` e
`Reviewability: OPEN`. Essa conclusão decisória não comprova artefatos nem
readiness: `D-00` está `RELEASED_WITH_SCOPE — HUMAN_EXPLICIT — TP-00013
local-only`; implementação/migração herméticas são permitidas, cleanup e efeitos externos não.

---

# 15. Change Log

| Version | Date | Author | Changes |
| --- | --- | --- | --- |
| 1.4 | 2026-08-25 | Solicitante humano, proprietário declarado / Codex (IA), materialização | Registra `D-00 = RELEASED_WITH_SCOPE — HUMAN_EXPLICIT — TP-00013 local-only`; permite backend/frontend/DDL/migrations/testes herméticos locais e mantém chamadas externas, Sandbox ASAAS, piloto BP Farias, produção, flags `ON`, cleanup destrutivo e efeitos reais bloqueados. |
| 1.3 | 2026-08-25 | Codex / Arquitetura | Reconcilia `D-04.4-D` humana e `D-04.4-E` a `D-14` `AI_DELEGATED` sob `AUTH-BILLING-2026-08-25-001`, aponta alçadas e rollout aos ADR-0050/ADR-0051 e preserva `D-00`, artefatos, evidências e cleanup como gates pendentes. |
| 1.2 | 2026-08-24 | Responsável pelo produto / Arquitetura | Registra ADR-0037 como decisão subsequente de `D-04.2-H`: manifest platform, runs/evidence/differences e authority marker tenant-local recebem placement, migrations, outbox e fence definidos dentro de Billing; BP Farias continua sem hardcode e `D-00` aberto. |
| 1.1 | 2026-08-23 | Responsável pelo produto / Arquitetura | Registra ADR-0036 como decisão subsequente de `D-04.2-G`: pós-cutover não há fallback legado, cache/LKG é derivado e somente `UNAVAILABLE` low-risk allowlisted pode usar LKG positivo; mantém `D-04.2-H`, `D-00` e implementação abertos. |
| 1.0 | 2026-08-23 | Responsável pelo produto / Arquitetura | Aceite de `D-04.2-F — opção A`: inventário/fingerprint, manifest exato, baseline/backfill tenant-local, shadow sem efeitos, cutover fenced sem fallback, forward repair e piloto BP Farias com attestation. |

---

# 16. Repository Structure

Esta decisão reside em:

```text
docs/adrs/ADR-0035-migracao-evidence-first-entitlements-legados.md
```

Os alvos físicos estão registrados no ADR-0037 e podem ser materializados
incrementalmente no escopo local-only de `D-00`.

---

# 17. Review Process

1. A opção A foi recomendada ao responsável pelo produto; big-bang por enum/default
   e dual-read permanente foram apresentados com seus riscos.
2. O responsável pelo produto aprovou explicitamente a opção A em 2026-08-23.
3. Arquitetura materializou evidências, manifest, backfill, shadow, reconciliação,
   cutover, BP Farias, segurança e boundaries sem autorizar implementação.
4. Mudança normativa exige nova versão aceita ou ADR sucessora.
5. As aprovações subsequentes de `D-04.2-G` e `D-04.2-H` pertencem aos ADR-0036
   e ADR-0037; decisões posteriores não podem ser inferidas deste documento.
6. A reconciliação vigente registra `D-04.4-D` como `HUMAN_EXPLICIT` e
   `D-04.4-E` a `D-14` como `AI_DELEGATED` sob
   `AUTH-BILLING-2026-08-25-001`; nenhuma revisão humana substantiva dessas
   decisões delegadas foi realizada (`NOT_PERFORMED`), e a revisão permanece
   aberta (`OPEN`) sem apagar a origem de IA.

---

# 18. Notes

Os nomes de categorias, lifecycle, manifest, fingerprint, fence e marker são
vocabulário conceitual. Sua representação física segue o ADR-0037 e os detalhes
de DDL permanecem para os implementation plans.

O AS-IS continua legado e nenhum tenant foi migrado por esta decisão.
