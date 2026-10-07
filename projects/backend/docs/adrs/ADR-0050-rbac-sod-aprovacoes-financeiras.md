---
document_id: "ADR-0050"
primary_nature: "Decisao"
objective: "Fechar `D-13` definindo authorities, escopo efetivo, autonomia auditável do SUPER_ADMIN, MFA e break-glass para operacoes sensiveis de Billing."
scope: "Keycloak, authorities finas, capabilities operacionais, acesso cross-tenant, purpose, transições explícitas, MFA step-up, break-glass e auditoria."
non_objectives: "Implementar realm, roles, annotations, endpoints, UI ou audit store; criar dynamic policy engine; definir identidade dos ocupantes, processo de RH ou threshold financeiro futuro; conceder acesso a producao."
owner: "Seguranca / Billing / Financeiro / Arquitetura"
status: "Accepted"
date: "2026-08-25"
version: "1.10"
last_reviewed: "2026-09-10"
keywords: "billing security, RBAC, Keycloak, segregation of duties, SoD, four-eyes, maker-checker, approval seal, MFA, break-glass, cross-tenant"
related_files: "README.md, ../../../docs/specs/TP-00013-enterprise-billing-implementation-task-plan.md, ../../../docs/specs/TP-00038-billing-contract-context-temporary-mfa-disablement.md, ../../../docs/specs/TP-00047-temporary-super-admin-invoicing-mfa-waiver.md, ADR-0005-multi-tenancy-architecture.md, ADR-0009-dynamic-rbac-evolution.md, ADR-0018-keycloak-realm-provisioning-automation.md, ADR-0026-billing-api-tenant-admin-cutover.md, ADR-0055-payment-provider-operational-control-plane.md"
code_references: "AS-IS em app/src/main/java/br/com/duoset/saas_service/contexts/billing/, app/src/main/java/br/com/duoset/saas_service/infrastructure/security/, app/src/main/resources/application.yml, app/src/main/resources/application-dev.yml, app/src/main/resources/db/migration/tenant/, frontend/src/components/billing/, frontend/src/schemas/billingManagementSchemas.ts, frontend/src/lib/permissions.ts, frontend/src/lib/effective-roles.ts, frontend/src/lib/protected-routes.ts, frontend/src/lib/menu-config.ts, .env.example, docker-compose.yml, docker-compose.override.yml, infra/deploy/production.env.example e configuracao Keycloak; authorities, approval aggregates/ports e guards finos desta ADR permanecem destinos planejados."
principal_statement: "Billing usa authorities finas e auditoria; D-13.3 remove a exigência de segundo aprovador para SUPER_ADMIN e D-13.5 dispensa MFA de todas as roles em DEV, HML e PRD, preservando RBAC, histórico, escopo e transições explícitas."
---

# ADR-0050 - RBAC, segregacao de funcoes e aprovacoes financeiras

- Document ID: `ADR-0050`
- Primary Nature: `Decisao`
- Objective: Fechar `D-13` definindo authorities, escopo efetivo, autonomia auditável do SUPER_ADMIN, MFA e break-glass para operacoes sensiveis de Billing.
- Scope: Keycloak, authorities finas, capabilities operacionais, acesso cross-tenant, purpose, transições explícitas, MFA step-up, break-glass e auditoria.
- Non-objectives: Implementar realm, roles, annotations, endpoints, UI ou audit store; criar dynamic policy engine; definir identidade dos ocupantes, processo de RH ou threshold financeiro futuro; conceder acesso a producao.
- Keywords: billing security, RBAC, Keycloak, segregation of duties, SoD, four-eyes, maker-checker, approval seal, MFA, break-glass, cross-tenant
- Related Files: `docs/product/requirements/REQ-00042-enterprise-multitenant-billing-invoicing.md`, `docs/product/requirements/REQ-00054-super-admin-unified-billing-price-version.md`, [REQ-00059](../product/requirements/REQ-00059-temporary-all-roles-mfa-disablement.md), ANL-00051, `../../../docs/specs/TP-00013-enterprise-billing-implementation-task-plan.md`, `../../../docs/specs/TP-00038-billing-contract-context-temporary-mfa-disablement.md`, [TP-00047](../../../docs/specs/TP-00047-temporary-super-admin-invoicing-mfa-waiver.md), casos de uso de Billing, ADRs de IAM/RBAC e `docs/architecture/rbac-access-control-matrix.md`.
- Code References: AS-IS em `app/src/main/java/br/com/duoset/saas_service/contexts/billing/`, `app/src/main/java/br/com/duoset/saas_service/infrastructure/security/`, `app/src/main/resources/application.yml`, `app/src/main/resources/application-dev.yml`, `app/src/main/resources/db/migration/tenant/`, `frontend/src/components/billing/`, `frontend/src/schemas/billingManagementSchemas.ts`, `.env.example`, `docker-compose.yml`, `docker-compose.override.yml`, `infra/deploy/production.env.example` e configuração Keycloak.
- Principal Decision: Billing usa Keycloak, authorities finas, tenant/purpose scope e auditoria. `D-13.3` remove a exigência de checker distinto para operações de `SUPER_ADMIN` em DEV, HML e PRD; qualquer `SUPER_ADMIN` autorizado executa transições explícitas dentro da alçada, com identificação no log e sem publicação automática.
- Date: 2026-08-25
- Status: Accepted
- Version: 1.10
- Decision Provenance: `AI_DELEGATED` para `D-13`; `HUMAN_EXPLICIT` para as emendas `D-01.1`, `D-13.1`, `D-13.2`, `D-13.3`, `D-13.4` e `D-13.5`
- Decision Actor: `AI_AGENT — Codex (OpenAI)` para `D-13`; proprietário do SaaS para `D-01.1`, `D-13.1`, `D-13.2` e `D-13.3`
- Authority Basis: `OWNER_DELEGATION — AUTH-BILLING-2026-08-25-001`
- Human Review Status: `NOT_PERFORMED` para `D-13`; `PERFORMED` para `D-01.1`, `D-13.1`, `D-13.2` e `D-13.3`
- Reviewability: `OPEN`
- Authors: Codex (AI), sob autoridade delegada
- Owners: Seguranca / Billing / Financeiro / Arquitetura
- Reviewers: IA — análise de arquitetura, domínio, segurança e custo de `D-13`; Humano — aprovação substantiva das emendas `D-01.1`, `D-13.1`, `D-13.2` e `D-13.3`, sem ratificação das demais decisões
- Stakeholders: Proprietario do SaaS, operadores de Billing/Financeiro/Fiscal, tenants, Seguranca, Suporte, Backend, Frontend, Auditoria e Operacoes
- Supersedes: N/A; especializa ADR-0009 e ADR-0026 para operacoes de Billing sem antecipar RBAC dinamico.
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
| Excluded attestations | Identidades reais, atribuicao de cargos, MFA/producao configurados, auditoria executada, compliance certificado e implementacao |
| Emenda `D-01.1` | `HUMAN_EXPLICIT` pelo proprietário do SaaS em 2026-09-04; Super Admin personificado pode acessar Billing do tenant selecionado, dentro dos limites deste ADR. |
| Emenda `D-13.1` | `HUMAN_EXPLICIT` pelo proprietário do SaaS em 2026-09-06; somente o `POST /api/v1/admin/billing/elevated-contexts` pode emitir sem prova MFA o contexto Super Admin para conjunto não vazio composto exclusivamente pela allowlist `BILLING_CONTRACT_*`, e esse waiver pode ser usado apenas nas mesmas authorities contratuais enquanto a flag reversível estiver desativada. |
| Emenda `D-13.2` | `HUMAN_EXPLICIT` pelo proprietário do SaaS em 2026-09-09; substitui o recorte ativo de `D-13.1` por desligamento temporário da prova MFA para Super Admin humano em DEV em todos os enforcement points Billing AS-IS inventariados no ANL-00051, sem remover o mecanismo ou os demais controles. |
| Emenda `D-13.3` | `HUMAN_EXPLICIT` pelo proprietário do SaaS em 2026-09-10; elimina a exigência atual e futura de segundo aprovador neste escopo, permite a qualquer `SUPER_ADMIN` autorizado preparar e efetivar transições explícitas em DEV/HML/PRD e preserva drafts e registros antigos como histórico não bloqueante. |
| Emenda `D-13.4` | `HUMAN_EXPLICIT` pelo proprietário do SaaS em 2026-09-10; substitui o waiver temporário de `D-13.2` por dispensa permanente de MFA exclusivamente para `SUPER_ADMIN` em DEV/HML/PRD, preservando RBAC, authorities finas, tenant/purpose, seals, idempotência e auditoria. Demais perfis continuam MFA-bound. |
| Emenda `D-13.5` | `HUMAN_EXPLICIT` pelo proprietário do SaaS em 2026-09-10; supera o limite de `D-13.4` e dispensa MFA de `SUPER_ADMIN`, `TENANT_ADMIN`, `USER` e `COMMERCIAL` em DEV/HML/PRD, preservando RBAC, isolamento, tenant/purpose e auditoria. A autonomia maker/checker continua exclusiva do `SUPER_ADMIN`, conforme D-13.3. |

`Accepted` indica uma policy arquitetural vigente por delegacao. Nao comprova que
Keycloak, MFA, usuarios ou controles estejam configurados e nao equivale a revisao
humana de Seguranca.

A emenda `D-01.1` possui revisão humana substantiva apenas quanto ao acesso por
personificação. Ela não ratifica automaticamente as decisões `AI_DELEGATED` de
maker-checker, MFA, approval seal ou break-glass.

A emenda `D-13.1` permanece como histórico da primeira exceção contratual. A
emenda `D-13.2` possui revisão humana substantiva para o recorte temporário e
repository-local descrito na Section 2.7.2: contextos puros de contrato, invoice e
leitura de interação de provider, as seis operações AS-IS de catálogo e as seis
mutações AS-IS de configuração de provider. Ela não remove maker-checker,
ApprovalSeal, SoD, RBAC, tenant/purpose, TTL, idempotência, switches ou auditoria.
Tenant Admin, ator sem `ROLE_SUPER_ADMIN`, HML, PRD, break-glass, administração de
roles e funções não implementadas continuam exigindo MFA; waiver nunca é convertido
em evidência MFA.

`D-13.3` remove a obrigatoriedade de uma segunda identidade humana e tem
precedência sobre toda formulação anterior deste ADR que declare maker/checker
sempre obrigatório, capability `OFF` ou `AWAITING_INDEPENDENT_APPROVAL` apenas pela
ausência de checker. Não existe toggle para reativar maker-checker neste escopo.
Ela não desativa authority fina, tenant/purpose scope,
hash/revisão, idempotência, concorrência, imutabilidade, audit trail ou controles
externos. A decisão e a execução pelo mesmo ator devem permanecer explícitas; não
há aprovação tácita nem promoção automática. Drafts e registros antigos de
aprovação permanecem imutáveis para auditoria, mas deixam de bloquear o draft e não
recebem status novo.

---

# 1. Context

Billing concentra operacoes capazes de alterar preco, contrato, invoice, caixa,
credito, refund, documento fiscal e acesso do tenant. Um unico papel amplo ou a
suposicao de que superadmin pode tudo permitiria fraude, erro irreversivel e acesso
cross-tenant sem finalidade. Por outro lado, introduzir agora um policy engine
dinamico aumentaria custo e superficie de falha antes de existir demanda provada.

O projeto ja usa Keycloak e roles/authorities. A decisao deve especializar esse
baseline com controles simples, testaveis e compativeis com o monolito modular,
sem simular segregacao quando a operacao possui apenas uma pessoa disponivel.

---

# 2. Decision Statement

## 2.1 Modelo de autorizacao inicial

O primeiro horizonte usa:

- autenticacao e MFA federadas pelo Keycloak;
- authorities finas, estaticas e versionadas em codigo/contrato;
- guards server-side para actor, tenant scope, purpose, resource state e approval;
- auditoria append-only de allow/deny/attempt/result;
- nenhuma DSL, script, SQL, tabela de policy dinamica ou engine externa.

O frontend apenas oculta/desabilita affordances; nunca constitui controle de
acesso. O dominio recebe um `AuthorizationDecision`/approval verificado por porta,
sem importar JWT, Spring Security ou Keycloak.

## 2.2 Familias de capabilities

Authorities devem permanecer separadas por verbo e boundary, sem role onipotente:

| Familia | Exemplos de capability separada |
| --- | --- |
| Catalog | draft, review, publish, pause, retire |
| Pricing | simulate, propose, publish, resume |
| Promotion | simulate, propose, publish, revoke, capacity-operate |
| Contract | quote, accept, amend, pause, cancel, reactivate |
| Invoice | read, generate, finalize, resend |
| Collection | read, reconcile, retry-safe, provider-operate, manual-payment |
| Correction | propose, approve, void, credit-memo, debit-memo |
| Refund | propose, approve, execute, reconcile |
| Write-off | propose, approve, execute |
| Fiscal | read, review, submit, cancel, substitute, ruleset-publish |
| Close | preview, soft-close, reopen, hard-close-future |
| Audit | read own scope, read cross-tenant authorized, export authorized |

Roles sao bundles operacionais de authorities e nao fonte de regra de dominio.
Nomes finais e least-privilege matrix devem ser congelados no contrato de
implementacao. Atribuir uma role nao elimina tenant scope, purpose ou approval.

## 2.3 Superadmin e acesso cross-tenant

`ROLE_SUPER_ADMIN` nao recebe acesso financeiro cross-tenant automatico. Uma
operacao sobre tenant exige, cumulativamente:

1. authority especifica;
2. tenant efetivo selecionado por mecanismo server-side governado;
3. purpose/reason code allowlisted e registrado;
4. expiracao curta do contexto elevado;
5. correspondencia entre path, command, tenant efetivo e datasource;
6. transição explícita pelo `SUPER_ADMIN` autorizado, registrada em auditoria.

Enumeracao indiscriminada, header livre, slug de banco, impersonacao permanente e
scope curinga sao proibidos. Consultas globais agregadas usam projecoes autorizadas;
nao concedem acesso ao detalhe de todos os tenants.

`D-01.1 = HUMAN_EXPLICIT` especializa este limite: um Super Admin sob
personificação explícita pode acessar as funcionalidades tenant-scoped de Billing
do tenant selecionado. No frontend, sua role efetiva passa a ser Tenant Admin; no
backend, `X-Tenant-ID` deve ser UUID canônico, coincidir com o tenant do path e
referenciar tenant ativo. Sem personificação, o Super Admin global continua sem
acesso implícito ao Billing tenant-scoped.

Esta permissão não torna Super Admin uma role financeira onipotente e não remove
authority específica, purpose, TTL ou approval aplicáveis à operação. MFA também
permanece obrigatório, salvo a exceção temporária, server-authoritative e exata da
emenda `D-13.2`; a exceção não se estende a ator, ambiente, função ou conjunto de
authority fora da allowlist fechada. A implementação corrente permanece local sob `D-00`;
promoção ambiental depende da materialização desses controles. O inventário
executável frontend está na
[matriz central de RBAC](../architecture/rbac-access-control-matrix.md).

## 2.4 Approval request e seal

Uma operacao controlada primeiro cria preview server-authoritative e
`ApprovalRequest` no modelo legado. O `ApprovalSeal` histórico fixa:

- action e policy version;
- resource type, ID, tenant e expected revision/generation;
- canonical preview hash e input fingerprint;
- amount/minor units e currency quando aplicaveis;
- provider/rail e effectiveAt quando aplicaveis;
- maker, checker, purpose, requestedAt, approvedAt e expiresAt;
- limites de uso, por default uma unica execucao;
- assinatura/integridade e audit correlation.

No fluxo vigente após `D-13.3`, maker e decision actor podem ser a mesma identidade
`SUPER_ADMIN`; a auditoria registra explicitamente o ator e a transição. Requests e
seals anteriores permanecem históricos e não bloqueiam drafts.
Mudanca de revision, amount, currency, linhas, hash, provider, policy, tenant,
effectiveAt ou dado material invalida o seal e exige novo preview/aprovacao. Seal
expirado, revogado ou reutilizado falha fechado.

## 2.5 Autonomia auditável do SUPER_ADMIN

Em DEV, HML e PRD não se exige aprovação independente para operações realizadas
por `SUPER_ADMIN`. Qualquer `SUPER_ADMIN`, desde que possua a authority e o contexto aplicáveis,
pode preparar, validar e efetivar as seguintes ações dentro de sua alçada:

- publicar ou retomar preco;
- publicar, retomar ou revogar promocao com efeito em novas aplicacoes;
- mudanca retroativa de contrato/policy;
- void, credit memo, debit memo ou outra correcao financeira;
- registrar pagamento manual;
- refund parcial ou total;
- write-off;
- trocar provider/merchant/rail de uma obrigacao;
- emitir/cancelar/substituir fiscalmente quando configurado como ato manual;
- soft-close, reopen e qualquer hard-close futuro.

Não há threshold nem política futura de segundo aprovador neste escopo. Cada
transição é explícita, auditável e atribuída ao `SUPER_ADMIN` efetivo. O sistema
preserva drafts e aprovações antigas sem reescrevê-los, deixa de usá-los como gate
e nunca publica automaticamente.

## 2.6 Operacoes sem approval previo

Nao exigem four-eyes, embora exijam authority/scope e auditoria:

- leitura no proprio escopo;
- resend/reprint do mesmo artefato/hash;
- simulacao/dry-run sem persistencia financeira ou efeito externo;
- preview;
- consulta/reconciliacao segura que apenas observa provider e converge fatos ja
  autorizados de forma idempotente;
- retry estritamente idempotente de command ja aprovado, dentro do mesmo seal;
- processamento automatico de webhook autenticado conforme policy publicada.

Se reconcile criar nova cobranca, refund, allocation discricionaria, mudanca de
provider ou outro efeito nao contido no command original, deixa de ser seguro e
entra na matriz four-eyes.

## 2.7 MFA step-up

MFA recente e obrigatorio para:

- aprovar ou executar operacao four-eyes;
- configurar, habilitar, trocar ou pausar provider/merchant/webhook;
- acessar break-glass;
- exportar detalhe financeiro/fiscal cross-tenant;
- alterar roles/authorities de Billing.

O token deve carregar evidencia de metodo/tempo de autenticacao conforme contrato
Keycloak. Ausencia, idade acima da policy ou claim ambiguo exige reautenticacao;
nao se aceita confirmacao apenas no frontend.

`D-13.2` ressalva temporariamente esta regra apenas para Super Admin humano em DEV
nos enforcement points Billing AS-IS inventariados no ANL-00051. Ela não decide a
identidade do checker; essa matéria passou a ser governada por D-13.3. ApprovalSeal
e os demais controles continuam independentes. `D-13.1` permanece registrado
abaixo como o recorte contratual inicial que a nova emenda ampliou.

### 2.7.1 Excecao contratual inicial — histórico D-13.1

`D-13.1 = HUMAN_EXPLICIT` cria uma excecao estreita e reversivel. Enquanto
`billing.security.admin-contract-context-mfa-enabled=false`, somente o
`POST /api/v1/admin/billing/elevated-contexts`, no fluxo Super Admin, pode emitir
um `BillingElevatedContext` sem prova MFA quando o conjunto solicitado for nao
vazio e contiver exclusivamente estas authorities exatas:

- `BILLING_CONTRACT_DRAFT`;
- `BILLING_CONTRACT_SUBMIT`;
- `BILLING_CONTRACT_ACCEPT`;
- `BILLING_CONTRACT_ACCEPT_RECORD`;
- `BILLING_CONTRACT_ACCEPT_VALIDATE`.

Prefixo livre, wildcard, `BILLING_CONTRACT_ALL`, authority desconhecida, conjunto
misto, invoice/run, catalogo, provider, break-glass e emissao para Tenant Admin
nao satisfazem a excecao. `ROLE_SUPER_ADMIN`, `BILLING_TENANT_IMPERSONATE`, ator
humano efetivo, tenant ativo, purpose, idempotencia, hard/idle TTL, revogacao,
path/header/context guard, SoD, approval e audit continuam obrigatorios.

Somente esse POST emite o waiver; depois de emitido, o contexto pode ser aceito
sem MFA apenas por actions protegidas por uma das cinco authorities contratuais
listadas, inclusive a validação four-eyes com
`BILLING_CONTRACT_ACCEPT_VALIDATE`. O contexto dispensado registra
`mfaRequired=false` e evidencia MFA ausente; ele nunca atesta segundo fator. Ao
configurar a flag como `true`, a validacao de uso rejeita imediatamente qualquer
waiver ainda vigente. O rollback nao aguarda TTL, nao apaga linha e nao converte
o contexto em prova MFA. Antes de `D-13.2`, todos os demais caminhos continuavam
sob a regra desta Section 2.7.

### 2.7.2 Desligamento temporário completo do MFA do Super Admin DEV

`D-13.2 = HUMAN_EXPLICIT`, registrada em 2026-09-09 pelo proprietário do SaaS,
substitui o recorte ativo de `D-13.1` enquanto
`billing.security.super-admin-mfa-enabled=false` no profile DEV. O estado default
da flag é `true`; configuração `false` fora de DEV deve impedir o backend de servir
requests. Somente identidade humana com `ROLE_SUPER_ADMIN` é elegível. Tenant
Admin, Commercial e qualquer ator sem essa role permanecem MFA-bound no Billing.

Nos contextos elevados, o POST administrativo pode registrar
`mfaRequired=false` e evidência ausente apenas quando o conjunto não vazio pertence
integralmente a uma única destas famílias fechadas:

- contrato: `BILLING_CONTRACT_DRAFT`, `BILLING_CONTRACT_SUBMIT`,
  `BILLING_CONTRACT_ACCEPT`, `BILLING_CONTRACT_ACCEPT_RECORD` e
  `BILLING_CONTRACT_ACCEPT_VALIDATE`;
- faturamento: `BILLING_INVOICE_PREVIEW`, `BILLING_INVOICE_APPROVE` e
  `BILLING_INVOICE_FINALIZE`;
- leitura de interação de provider: somente
  `BILLING_PROVIDER_INTERACTION_READ`.

Conjunto misto entre famílias, vazio, wildcard, prefixo livre, authority
desconhecida ou qualquer outra operação falha fechado. O uso do contexto reavalia
a policy; um contexto waived nunca se torna prova MFA.

No catálogo, a mesma policy pode dispensar somente a prova MFA nas seis operações
executáveis existentes: `approve`, `reject`, `publishPrice`, `retirePrice`,
`publishOffer` e `retireOffer`. A decisão checker persistida distingue
`MFA_REQUIRED` de `MFA_WAIVED`; waiver guarda evidência nula, sem `otp`, AMR ou
timestamp sintético. Authority específica, maker diferente de checker,
ApprovalSeal action-specific, revision/hash, idempotência, optimistic concurrency,
estado do aggregate e auditoria permanecem obrigatórios.

As seis mutações AS-IS da configuração de payment provider seguem o mesmo recorte
sob a especialização do ADR-0055. O toggle não habilita mutation switch, adapter,
provider, Sandbox, chamada externa ou efeito financeiro.

Rollback define a flag como `true` e restaura MFA imediatamente para nova emissão,
uso ou consumo ainda não concluído. Contexto ou approval waived pendente passa a
falhar fechado; efeitos já concluídos não são apagados nem reescritos e permanecem
imutáveis e auditáveis. O mecanismo `BillingMfaEvidence`, os adapters que extraem
AMR/tempo do JWT, o erro `BILLING_MFA_REQUIRED` e os caminhos de reautenticação
continuam presentes para rollback, Tenant Admin e ambientes protegidos.

## 2.8 Break-glass

Break-glass possui purpose de incidente, escopo minimo, duracao curta, MFA,
notificacao e revisao posterior obrigatoria. Ele pode:

- pausar novas mutacoes externas;
- acionar kill switch;
- manter ingress/reconciliacao/recovery seguros;
- executar diagnostico read-only e recuperacao tecnica preautorizada.

Break-glass nunca concede alçada nem altera D-13.3. A execução pelo mesmo
`SUPER_ADMIN` decorre de sua authority e alçada, não de break-glass.

## 2.9 Ausencia de segunda pessoa

Ausência de segunda pessoa não bloqueia o `SUPER_ADMIN` dentro da alçada. Estados
legados como `AWAITING_INDEPENDENT_APPROVAL` permanecem apenas como histórico e
não bloqueiam o draft. O sistema nunca:

- usa duas contas da mesma pessoa;
- aceita IA, service account ou job como segundo humano;
- reduz o threshold;
- reutiliza approval de outro recurso;
- promove superadmin/break-glass a checker automatico.

Automacoes podem executar command previamente aprovado e selado; nao concedem a
propria aprovacao.

## 2.10 Auditoria e privacidade

Decisoes de autorizacao e approval produzem audit event com actor, effective
tenant, purpose, resource, action, revision/hash, result, reason e correlation,
sem PAN, CVV, token, cupom plaintext, segredo, payload fiscal completo ou PII
desnecessaria. Negacoes e tentativas stale tambem sao auditadas, com protecao
contra enumeracao.

## 2.11 Boundary da aprovacao

`D-13` fica fechado. Matriz completa, nomes exatos, realm/client roles, TTL de MFA,
OpenAPI, audit retention, runbooks e testes dependem de implementacao e owner
review. Este ADR nao cria acesso nem configura producao. `D-00 =
RELEASED_WITH_SCOPE — HUMAN_EXPLICIT — TP-00013 local-only` autoriza somente
validações e testes herméticos locais dos planos TP-00013.
O rollout correspondente foi decidido no ADR-0051, também como `AI_DELEGATED`
sob `AUTH-BILLING-2026-08-25-001`, com revisão humana `NOT_PERFORMED`/`OPEN`;
targets aceitos não constituem evidência de controles ativos.

---

# 3. Decision Drivers

- menor privilegio e isolamento cross-tenant;
- integridade financeira e prevencao de fraude/erro;
- approval vinculada exatamente ao efeito revisado;
- controls testaveis sem engine dinamica prematura;
- compatibilidade com Keycloak e Spring Modulith existentes;
- operacao segura em equipe pequena, sem fingir SoD;
- auditabilidade de decisoes humanas e automatizadas.

---

# 4. Considered Options

## Option A - Authorities finas + approval seal + maker-checker

Pros: forte rastreabilidade, least privilege, baixo custo de runtime e verificacao
deterministica.

Cons: operacoes sensiveis param quando nao ha segundo aprovador e exigem UX/runbook.

## Option B - Superadmin irrestrito com log posterior

Rejected: auditoria posterior nao previne erro, fraude ou acesso cross-tenant.

## Option C - Policy engine dinamico desde o primeiro slice

Rejected: adiciona custo, DSL e superficie operacional sem demanda comprovada.

## Option D - Threshold financeiro para autoaprovacao

Rejected no primeiro horizonte: pequenos valores repetidos tambem acumulam risco e
nao ha base empirica/owner review para um threshold.

---

# 5. Decision Outcome

A **Option A** foi escolhida autonomamente pela IA sob delegacao. O modelo usa
capacidades existentes da stack, aplica SOLID por ports/guards e mantem controls
financeiros indisponiveis quando a organizacao nao consegue satisfazer SoD.

---

# 6. Consequences

## Positive Consequences

- Nenhum papel isolado altera dinheiro e aprova o proprio ato.
- Approval invalida automaticamente quando o efeito muda.
- Superadmin e break-glass possuem limites verificaveis.
- Authorities podem evoluir por bundle sem engine dinamica.
- Logs distinguem tentativa, aprovacao e execucao.

## Negative Consequences

- Operacao de equipe individual nao executa atos controlados.
- Preview/seal e MFA adicionam etapas e estados de fila.
- Matriz de authorities exige manutencao coordenada com Keycloak/UI/API.

## Neutral Consequences

- Dynamic RBAC continua uma evolucao futura governada pelo ADR-0009.
- Service accounts executam automacao, mas nao representam checker humano.

---

# 7. Impact

- Security: fine-grained authorities, purpose, tenant scope, MFA e SoD.
- Domain/Application: approval contracts e guards por ports, sem JWT no dominio.
- API: preview -> request approval -> approve -> execute como workflow explicito.
- Frontend: exibe estado/impacto, nunca calcula hash ou autoriza localmente.
- Operations: break-glass/kill switch separados de atos financeiros.
- Cost: Keycloak e monolito existentes; nenhuma engine adicional.

---

# 8. AI Agent Considerations

Agentes podem implementar validacoes no escopo local-only liberado por `D-00`, mas
nao podem atuar como checker humano, atribuir roles reais, desabilitar MFA/SoD
fora da emenda humana `D-13.2`, usar superadmin como atalho ou apagar
`AI_DELEGATED`. A IA pode produzir preview/análise; a aprovacao humana substantiva
de um efeito financeiro continua distinta.

---

# 9. Implementation Plan Boundary

1. congelar catalogo de authorities e matriz action -> approval;
2. definir contratos de effective tenant/purpose/MFA;
3. modelar approval request/seal e canonical preview hash;
4. integrar guards server-side e audit events;
5. configurar Keycloak em ambiente local/teste sem credenciais reais;
6. implementar UX maker/checker e filas expiradas/stale;
7. implementar break-glass/kill switch com limites negativos;
8. testar tenancy, privilege escalation, replay, drift e indisponibilidade do checker;
9. habilitar somente por rollout/evidence gates do ADR-0051 e owner review.

O recorte contratual histórico de `D-13.1` é rastreado pelo
[TP-00038](../../../docs/specs/TP-00038-billing-contract-context-temporary-mfa-disablement.md).
O desligamento temporário completo de `D-13.2` é coordenado pelo
[TP-00047](../../../docs/specs/TP-00047-temporary-super-admin-invoicing-mfa-waiver.md),
com inventário no ANL-00051, toggle default-on/fail-closed, famílias fechadas,
persistência explícita da decisão e regressão de rollback.

A implementação hermética local pode avançar sob `D-00`; atribuição de roles reais,
acesso, efeito financeiro, Sandbox, piloto e rollout exigem autorização própria.

---

# 10. Validation

- qualquer `SUPER_ADMIN` autorizado pode executar a transição dentro da alçada;
- seal fixa tenant/revision/hash/amount/currency/expiry e drift invalida;
- operacoes da matriz exigem approval para qualquer valor;
- leitura/resend/dry-run/safe reconcile nao criam efeito novo;
- superadmin sem purpose/scope nao acessa detalhe financeiro tenant-local;
- superadmin personificado só alcança Billing do único tenant cujo header/path
  coincidem; sem personificação permanece negado;
- MFA é validado server-side para approvals/provider/break-glass; `D-13.2`
  ressalva somente os enforcement points AS-IS de Super Admin humano em DEV e
  nunca o break-glass;
- sem MFA, o POST administrativo emite contexto apenas para uma família pura e
  não vazia de contrato, invoice ou provider-interaction-read, com a flag DEV
  desativada;
- o contexto dispensado só é aceito no uso da mesma família fechada; mistura,
  vazio, wildcard, prefixo e authority desconhecida falham fechados;
- as seis operações de catálogo e as seis mutações de configuração de provider
  preservam authority, switches e auditoria, sem exigir segundo aprovador;
- Tenant Admin, ator sem `ROLE_SUPER_ADMIN`, HML e PRD continuam falhando sem MFA;
- ligar a flag invalida imediatamente no uso qualquer contexto com waiver ativo;
- break-glass nao executa atos monetarios;
- ausência de checker não bloqueia capability, draft ou transição explícita;
- domain nao importa Keycloak/Spring Security;
- docs e indices passam no validador integrado.

Na decisão original `D-13`/v1.0, testes executáveis não foram criados porque a
mudança era somente documental. A materialização posterior de `D-13.1` é coberta
pelo TP-00038; `D-13.2` é coberta pelo TP-00047 com testes de domínio, caso de uso,
MVC, configuração, persistência PostgreSQL, frontend e rollback. Evidências e
eventuais skips pertencem aos respectivos planos.

---

# 11. Risks and Mitigations

| Risk | Mitigation |
| --- | --- |
| Role ampla contornar least privilege | Authorities por verbo + guards cumulativos. |
| Approval de preview diferente | Canonical hash/revision/amount/currency selados. |
| Duas contas da mesma pessoa simularem SoD | Identidade humana efetiva e owner process; operacao OFF sem prova. |
| Superadmin acessar todos os tenants | Purpose + effective tenant + TTL + audit. |
| Break-glass virar bypass financeiro | Deny invariants independentes da role. |
| MFA apenas visual | Claim/idade verificados no backend. |
| Waiver MFA escapar do recorte | Elegibilidade cumulativa DEV + Super Admin humano + flag, famílias/actions exatas, persistência sem evidência sintética, revalidação no consumo e testes negativos/rollback. |
| Complexidade operacional | Workflow pequeno no monolito, sem policy engine. |

---

# 12. Related ADRs

- [ADR-0000 - Governanca documental](../../harness/governance/decisions/ADR-0000-governanca-do-harness-documental.md)
- [ADR-0005 - Arquitetura multitenant](ADR-0005-multi-tenancy-architecture.md)
- [ADR-0009 - Evolucao de RBAC](ADR-0009-dynamic-rbac-evolution.md)
- [ADR-0018 - Provisionamento Keycloak](ADR-0018-keycloak-realm-provisioning-automation.md)
- [ADR-0026 - APIs Billing tenant/admin](ADR-0026-billing-api-tenant-admin-cutover.md)
- [ADR-0051 - SLO, capacidade e rollout](ADR-0051-slo-capacidade-rollout-billing.md)
- [ADR-0055 - Control plane operacional de provedores de pagamento](ADR-0055-payment-provider-operational-control-plane.md)

---

# 13. References

- [REQ-00042](../product/requirements/REQ-00042-enterprise-multitenant-billing-invoicing.md)
- [REQ-00054](../product/requirements/REQ-00054-super-admin-unified-billing-price-version.md)
- [REQ-00059](../product/requirements/REQ-00059-temporary-all-roles-mfa-disablement.md)
- ANL-00051
- [TP-00013](../../../docs/specs/TP-00013-enterprise-billing-implementation-task-plan.md)
- [TP-00038](../../../docs/specs/TP-00038-billing-contract-context-temporary-mfa-disablement.md)
- [TP-00047](../../../docs/specs/TP-00047-temporary-super-admin-invoicing-mfa-waiver.md)
- [Module Registry](../architecture/module-registry.md)
- [Matriz central de RBAC e aplicação no frontend](../architecture/rbac-access-control-matrix.md)

---

# 14. Decision Lifecycle

Current State: **Accepted — AI_DELEGATED core; HUMAN_EXPLICIT amendments D-01.1,
D-13.1, D-13.2, D-13.3, D-13.4 and D-13.5**.

Ratificacao humana futura deve manter provenance. `D-13.2` satisfaz essa exigencia
somente para a excecao temporaria nela delimitada e substitui o recorte ativo de
`D-13.1` sem apagar seu histórico. Qualquer outra alteracao
material de maker-checker além de D-13.3, seal, MFA, superadmin ou break-glass exige
nova versao aceita ou ADR sucessor.

`D-14` esta aceito no ADR-0051 com a mesma origem delegada e revisao humana
aberta. Readiness, SLO/backup medidos, Sandbox/piloto/produção continuam
separadamente pendentes; `D-00` libera somente implementação local TP-00013.

---

# 15. Change Log

| Version | Date | Author | Changes |
| --- | --- | --- | --- |
| 1.10 | 2026-09-10 | Proprietário do SaaS / Codex (IA), materialização | Emenda D-13.5: dispensa MFA de todas as roles em DEV/HML/PRD, preserva RBAC e auditoria e mantém a autoaprovação exclusiva do `SUPER_ADMIN`. |
| 1.9 | 2026-09-10 | Proprietário do SaaS / Codex (IA), materialização | Emenda D-13.4: dispensa MFA somente para `SUPER_ADMIN` em DEV/HML/PRD, mantém RBAC e todos os demais controles e não amplia a dispensa a outros perfis. |
| 1.8 | 2026-09-10 | Proprietário do SaaS / Codex (IA), materialização | Emenda D-13.3: elimina segundo aprovador atual e futuro para SUPER_ADMIN em DEV/HML/PRD; preserva drafts, cadeia de catálogo e registros antigos como histórico não bloqueante; exige transição explícita e veda publicação automática. |
| 1.7 | 2026-09-10 | Proprietário do SaaS / Codex (IA), materialização | Incorpora `D-13.3 = HUMAN_EXPLICIT`: revisão independente configurável, inicialmente desativada em DEV/HML/PRD; o mesmo SUPER_ADMIN pode decidir e efetivar ações dentro da alçada, preservando auditabilidade e permitindo ativação futura de maker-checker distinto. Superada pela v1.8. |
| 1.6 | 2026-09-09 | Proprietário do SaaS / Codex (IA), materialização | Incorpora `D-13.2 = HUMAN_EXPLICIT`: desliga temporariamente somente a prova MFA do Super Admin humano em DEV nos enforcement points Billing AS-IS — famílias puras de contrato/invoice/provider-read, seis operações de catálogo e seis mutações de configuração provider — preservando controles, evidência honesta e rollback imediato. |
| 1.5 | 2026-09-06 | Codex / revisão de consistência | Distingue a validação documental histórica de `D-13` das suítes executáveis que materializam `D-13.1` no TP-00038 e esclarece o estado de revisão humana. |
| 1.4 | 2026-09-06 | Proprietário do SaaS / Codex (IA), materialização | Incorpora `D-13.1 = HUMAN_EXPLICIT`: somente o POST administrativo emite o waiver, aceito no uso das cinco authorities contratuais, inclusive `ACCEPT_VALIDATE`; preserva SoD/approval e MFA de catálogo, invoice/run, Tenant Admin, provider, break-glass, roles e demais actions. |
| 1.3 | 2026-09-04 | Proprietário do SaaS / Codex (IA), materialização | Incorpora `D-01.1 = HUMAN_EXPLICIT`, distingue Super Admin global/personificado, preserva authorities/SoD e referencia a matriz central AS-IS do frontend. |
| 1.2 | 2026-08-25 | Solicitante humano, proprietário declarado / Codex (IA), materialização | Registra `D-00 = RELEASED_WITH_SCOPE — HUMAN_EXPLICIT — TP-00013 local-only`; permite validações/código/testes herméticos locais e mantém roles/configuração reais, chamadas externas, Sandbox ASAAS, piloto BP Farias, produção, flags `ON` e efeitos reais bloqueados. |
| 1.1 | 2026-08-25 | Codex (IA), sob `AUTH-BILLING-2026-08-25-001` | Reconcilia `D-14` com ADR-0051 aceito `AI_DELEGATED`, revisao humana `NOT_PERFORMED`/`OPEN`; mantém controls/readiness como evidencias pendentes e `D-00` ativo. |
| 1.0 | 2026-08-25 | Codex (IA), sob `AUTH-BILLING-2026-08-25-001` | Fecha autonomamente `D-13` com authorities finas, tenant/purpose scope, approval seal, four-eyes sem threshold, MFA, limites de superadmin/break-glass e capability OFF sem checker; revisao humana substantiva nao realizada. |

---

# 16. Repository Structure

Este ADR cria somente documentacao. Os alvos planejados ficam nas fronteiras
publicas/internas ja existentes de Billing e Security, sem novo modulo ou engine.

---

# 17. Review Process

A revisão humana substantiva permanece aberta para `D-13` e para as demais
decisões não ratificadas. `D-13.1` e `D-13.2` foram explicitamente solicitadas e
revisadas pelo humano nos respectivos escopos temporários aqui registrados;
configuração real de ocupantes/roles
requer verificação separada e não pode ser inferida deste documento.

---

# 18. Notes

Break-glass recupera o sistema; approval autoriza o efeito. Uma funcao nunca deve
ser usada para simular a outra.
