---
document_id: ADR-0055
primary_nature: Decisao
objective: Decidir a fonte de verdade, os limites de segurança e o modelo de observabilidade da gestão operacional de provedores de pagamento.
scope: Configuração global provider-neutral, perfis ASAAS e Stripe, referências opacas de segredo, projeção sanitizada de comunicações, APIs administrativas e tenant-scoped e console Conecta Pagamentos.
non_objectives: Implementar o adapter ASAAS ou Stripe; guardar segredo, PAN, CVV, token de cartão ou payload bruto; autorizar Sandbox, produção, fallback automático, replay/reprocessamento operacional de interação/provider ou efeito financeiro real.
owner: Arquitetura, Billing, Segurança e Operações
status: Accepted
version: 1.8
date: 2026-09-06
last_reviewed: 2026-09-11
keywords: adr, billing, payment-provider, control-plane, asaas, stripe, observabilidade, configuracao, timeline
related_files: "README.md"
code_references: app/src/main/java/br/com/duoset/saas_service/contexts/billing/, app/src/main/resources/application.yml, app/src/main/resources/application-dev.yml, app/src/main/resources/db/migration/tenant/, frontend/src/app/, frontend/src/components/billing/, frontend/src/services/
principal_statement: O Billing manterá um control plane global, versionado e sem segredos para providers e uma projeção operacional append-only sanitizada; D-13.5 e REQ-00059 dispensam temporariamente MFA de todas as roles em DEV, HML e PRD, enquanto as seis mutações AS-IS continuam exclusivas do Super Admin por RBAC e todo efeito externo permanece sujeito a adapter certificado, kill switch de deploy e autorização ambiental independente.
---

# ADR-0055 - Control plane operacional de provedores de pagamento

- Document ID: `ADR-0055`
- Primary Nature: `Decisao`
- Objective: permitir configurar provedores e reconstruir sua comunicação sem criar uma segunda verdade financeira nem ampliar o escopo PCI.
- Scope: configuração platform-scoped, readiness, referências opacas, projeção operacional, API administrativa e console `Conecta > Pagamentos`.
- Non-objectives: adapters ASAAS/Stripe, tráfego externo, credenciais reais, Sandbox, produção, fallback automático, replay/reprocessamento operacional de interação/provider e alteração direta de fatos financeiros. Essa exclusão não abrange o replay HTTP idempotente exato das mutações locais definido nesta decisão.
- Keywords: Billing, payment provider, ASAAS, Stripe, control plane, interaction timeline, observabilidade.
- Related Files: [TP-00039](../../../docs/specs/TP-00039-payment-provider-management-console.md), [TP-00047](../../../docs/specs/TP-00047-temporary-super-admin-invoicing-mfa-waiver.md), [REQ-00056](../product/requirements/REQ-00056-payment-provider-management-observability.md), [REQ-00059](../product/requirements/REQ-00059-temporary-all-roles-mfa-disablement.md), ANL-00051, [UC-00053](../product/use-cases/UC-00053-manage-payment-provider-configuration.md), [UC-00054](../product/use-cases/UC-00054-inspect-payment-provider-interactions.md), [Payment Provider Console OpenAPI v1](../../../docs/api_contracts/payment-provider-console-v1.openapi.yaml) e [ADR-0023](ADR-0023-agnostic-payment-provider-integration.md).
- Code References: módulo `billing`, migrations globais e frontend administrativo.
- Principal Decision: separar metadata operacional global e evidência sanitizada dos fatos financeiros tenant-local, sempre fail-closed e sem material secreto; `D-13.5` e REQ-00059 dispensam temporariamente MFA de todas as roles em DEV/HML/PRD, sem remover RBAC nem qualquer outro controle.
- Date: 2026-09-06
- Status: Accepted
- Authorization Scope: repository-local implementation authorized; external calls and provider enablement excluded
- Version: 1.8
- Decision Provenance: `HUMAN_EXPLICIT` para a implementação repository-local solicitada e para a emenda temporária `D-13.2`; `AI_MATERIALIZATION` para a decomposição técnica, sem autoridade ambiental.
- Decision Actor: proprietário do SaaS para `D-13.2`, em 2026-09-09.
- Human Review Status: `PERFORMED` somente para a exceção temporária delimitada; as demais decisões conservam sua proveniência anterior.
- Owner: Arquitetura, Billing, Segurança e Operações
- Authors / Owners: Codex, sob solicitação humana explícita de implementação local
- Reviewers: Arquitetura, Backend, Frontend, Segurança, QA, Compliance e SRE
- Stakeholders: Produto, Operações Financeiras, Suporte, Auditoria e tenants
- Supersedes: N/A
- Superseded by: N/A

# 1. Context

O Billing já possui decisões para integração provider-neutral, tokenização hosted,
separação das APIs administrativas e tenant-scoped, RBAC financeiro e rollout
seguro. Também existe uma fundação de portas para providers e um command journal no
banco do tenant. Porém, ainda não há uma fonte mutável e governada para a
configuração operacional nem uma consulta única capaz de explicar, de forma
sanitizada, o caminho entre command, tentativa, retorno, webhook, evento canônico e
reconciliação.

O produto precisa de uma superfície chamada `Conecta > Pagamentos`, inicialmente
com ASAAS, organizada em dois escopos:

1. `Configuração`, para visualizar e manter o perfil operacional do provider;
2. `Comunicações e Transações`, para investigar o fluxo e suas falhas.

O mesmo desenho deve representar Stripe e providers futuros sem transformar sua
presença no catálogo em certificação ou disponibilidade. A decisão precisa preservar
as seguintes fronteiras:

- invoice, obligation, payment, allocation e reconciliation continuam tenant-local
  e autoritativos no Billing;
- seleção de provider é global e server-side, nunca enviada pelo browser ou tenant;
- segredo e dado de cartão não pertencem ao banco de negócio nem ao frontend;
- um resultado externo ambíguo não pode ser convertido em retry ou sucesso pela UI;
- documentação e código locais não autorizam acesso a Sandbox, produção ou contas
  reais do ASAAS.

A solicitação humana autorizou criar os contratos e implementar localmente o
TP-00039. Essa autorização aceita a materialização técnica descrita neste ADR, mas
não é autorização ambiental nem operacional.

# 2. Decision Statement

Adotar dois componentes complementares dentro do bounded context Billing:

1. um **Provider Configuration Control Plane** global, persistido no datasource da
   plataforma, com metadata não secreta, revisões monotônicas, optimistic
   concurrency, autoria, justificativa e histórico append-only;
2. um **Provider Interaction Projection** global, append-only, sanitizado e com
   retenção limitada, construído a partir de fatos já persistidos nos bancos dos
   tenants e dos boundaries de integração.

O control plane conhece apenas providers compilados e allowlisted pelo backend. O
primeiro catálogo contém `ASAAS` como `PRIMARY` e `STRIPE` como `CONTINGENCY`; ambos
nascem sem tráfego externo, e Stripe permanece `NOT_CERTIFIED/OFF`. Nenhuma entrada
dinâmica carrega código executável, URL arbitrária ou plugin.

Valores de segredo continuam exclusivamente em secret store ou configuração segura
do servidor. Banco e API guardam apenas um identificador lógico preexistente. A
gramática distingue `secret:<namespace>/<segments>` de
`webhook-profile:<namespace>/<segments>` e cada valor deve existir em catálogo
server-side. URI, scheme genérico, path absoluto/relativo, query, fragment,
traversal e referência desconhecida são rejeitados antes do store. A projeção expõe
somente o identificador e estado sanitizado (`MISSING`, `AVAILABLE`, `INVALID`,
`ROTATION_DUE`), nunca valor, hash reversível ou fragmento da credencial. Essa
fronteira impede que o console se torne entrada indireta para URL livre ou SSRF.

O estado efetivo será calculado pela conjunção fail-closed:

```text
effective = deployedAdapter
         AND providerCertified
         AND environmentAuthorized
         AND deploymentKillSwitch
         AND desiredState == ENABLED
         AND secretReferenceHealthy
         AND requiredCapabilitiesReady
```

Falha, ausência ou estado desconhecido em qualquer parcela produz `DISABLED` ou
`DEGRADED`, nunca habilitação. Criar ou editar um `DRAFT` altera apenas uma revisão
candidata. Submissão congela seu hash; uma mudança material só pode tornar-se
revisão ativa depois de decisão de checker humano distinto, decisão MFA aplicável
(prova recente ou waiver estrito de `D-13.2`) e `ApprovalSeal`
vinculados exatamente a provider, revisão, hash, `activeRevisionId` e versão do
profile congelados na submissão. A ativação revalida esse baseline sob lock; drift
gera conflito e exige novo workflow, impedindo que uma aprovação contra A substitua
silenciosamente B. Nenhuma dessas etapas cria adapter,
testa conexão, dispara cobrança, registra webhook ou supera kill switch de deploy.

A projeção operacional não é ledger financeiro. Ela armazena somente campos de uma
allowlist, aponta para identificadores canônicos e permite reconstruir correlações
sem corpo HTTP, header, stack trace, segredo, PAN, CVV, token de cartão ou payload
proprietário. Os fatos financeiros continuam sendo consultados em seus read models
autoritativos; divergências são exibidas, não corrigidas pela projeção.

# 3. Decision Drivers

- permitir diagnóstico ponta a ponta sem acesso direto a logs ou bancos;
- manter ASAAS como prioridade sem acoplar UI e domínio ao seu vocabulário;
- preparar Stripe e providers futuros sem sugerir fallback ou certificação;
- impedir que configuração no navegador habilite efeitos externos por acidente;
- preservar database-per-tenant para fatos financeiros e evitar fan-out em uma
  visão administrativa cross-tenant;
- excluir credenciais e dados de cartão do escopo da plataforma;
- oferecer concorrência, auditoria e rollback lógico verificáveis;
- evitar alta cardinalidade nas métricas e exposição de payloads em telemetria;
- suportar estados ambíguos e reconciliação sem retry cego;
- permitir implementação e testes herméticos antes da certificação ASAAS.

# 4. Considered Options

## 4.1 Configuração somente por variáveis de ambiente

**Pros:** superfície de ataque pequena e operação conhecida.  
**Cons:** não entrega governança na aplicação, histórico, concorrência, visão de
readiness ou preparação de múltiplos providers; toda alteração exige deploy.

## 4.2 Configuração mutável completa, incluindo segredos no banco e na UI

**Pros:** experiência administrativa aparentemente centralizada.  
**Cons:** amplia materialmente o escopo de segurança e PCI, cria risco de vazamento
em DOM/log/audit e mistura gestão de segredo com regra de negócio. Rejeitada.

## 4.3 Control plane global sem segredos e com kill switch composto — escolhida

**Pros:** oferece gestão versionada, auditável e provider-neutral sem permitir que a
UI, isoladamente, gere tráfego externo; mantém credenciais no boundary correto.  
**Cons:** exige distinguir estado desejado, readiness e estado efetivo, além de uma
integração futura com secret store e processo de certificação.

## 4.4 Consultar cada banco de tenant para montar a timeline

**Pros:** evita projeção central.  
**Cons:** fan-out caro e frágil, indisponibilidade parcial difícil de representar e
risco de consulta cross-tenant sem limites. Rejeitada para a console global.

## 4.5 Copiar payloads e fatos financeiros completos para uma timeline central

**Pros:** investigação aparentemente rica.  
**Cons:** cria segunda verdade, replica PII e dados proprietários e amplia retenção e
blast radius. Rejeitada.

## 4.6 Projeção global append-only, sanitizada e não autoritativa — escolhida

**Pros:** consulta bounded e correlacionada, sem fan-out e com contrato explícito de
minimização.  
**Cons:** consistência é eventual; gaps e atraso precisam ser visíveis, e o operador
deve navegar ao read model canônico quando necessitar do fato financeiro completo.

# 5. Decision Outcome

A combinação escolhida entrega os dois escopos da console com limites verificáveis.
Configuração operacional vira uma capacidade do control plane; comunicação vira uma
projeção diagnóstica. A separação impede três erros perigosos: segredo tratado como
campo de negócio, timeline tratada como ledger e botão da UI tratado como autorização
de tráfego externo.

O rótulo inicial será `Conecta > Pagamentos`, materializado em
`/admin/conecta/payments`. Ele descreve a área agregadora de integrações
financeiras e não se confunde semanticamente com um provider. A rota e os contratos
são provider-neutral; ASAAS é apenas o primeiro perfil visível.

# 6. Consequences

**Positive Consequences:**

- ASAAS e providers futuros compartilham API, modelos e componentes de frontend;
- o operador visualiza desired/effective/readiness sem conhecer credenciais;
- intents concorrentes divergentes falham com conflito em vez de sobrescrever
  silenciosamente; replay concorrente da mesma intenção converge ao resultado exato;
- investigação usa correlation IDs e estados normalizados;
- comunicação pode ser testada hermeticamente com registros sintéticos;
- Stripe aparece honestamente como contingência não certificada e desligada.

**Negative Consequences:**

- existe uma projeção adicional com lag, retenção e rotina de purge;
- estado efetivo requer composição de sinais e pode parecer mais conservador;
- adapters futuros precisam publicar evidência sanitizada além de fatos canônicos;
- ações como replay e reconcile exigirão casos de uso e controles próprios.

**Neutral Consequences:**

- a configuração global usa o datasource da plataforma; os fatos financeiros
  permanecem nos bancos dedicados dos tenants;
- a primeira versão da aba de comunicações pode estar vazia até adapters e fluxos
  reais publicarem fatos, sem recorrer a dados simulados em runtime;
- rollout externo continua pertencendo ao TP-00011 e aos gates do ADR-0051.

# 7. Impact

## 7.1 Data ownership

| Dado | Owner / armazenamento | Regra |
| --- | --- | --- |
| Provider profile e desired state | Billing control plane / plataforma | Metadata não secreta, versionada e auditada. |
| Valor de API key ou webhook secret | Secret store/configuração segura | Nunca retornado à aplicação cliente nem persistido nas tabelas do TP-00039. |
| Provider customer/payment identifier | Billing tenant-local | Referência opaca conforme necessidade do fato canônico. |
| Invoice, payment, allocation, balance | Billing tenant-local | Fonte autoritativa financeira. |
| Interaction projection | Billing control plane / plataforma | Cópia sanitizada, eventual, descartável e não autoritativa. |
| Logs, traces e métricas | Observabilidade | Redaction; labels de baixa cardinalidade. |

## 7.2 Configuration contract

Cada provider expõe, no mínimo:

- código e nome estáveis;
- papel `PRIMARY`, `CONTINGENCY` ou `FUTURE`;
- ambiente lógico `SANDBOX` ou `PRODUCTION`, sem URL arbitrária;
- desired state `OFF`, `PAUSED` ou `ENABLED`;
- effective state e reason codes calculados server-side;
- certification/readiness e capabilities conhecidas;
- merchant/account alias opaco;
- aliases lógicos de credential e webhook secret;
- versão monotônica do profile e da revisão, lifecycle (`DRAFT`,
  `PENDING_APPROVAL`, `APPROVED`, `REJECTED`, `INVALIDATED`, `ACTIVATED`,
  `SUPERSEDED`), hash canônico, maker/checker, justificativa e timestamps;
- sinal de freshness, sem retorno de valores sensíveis.

`merchantAccountAlias`, purpose, reason code, `secretReferenceId` e
`webhookReferenceId` são metadata, nunca canais alternativos para cartão ou
credencial. Ingress, domínio e consumidor frontend aplicam uma policy fail-closed
antes de persistir, transmitir ou renderizar: normalização NFKC somente para
detecção; PAN-like válido por Luhn com 13–19 dígitos Unicode e separadores bounded;
CVV/CVC/CID, validade, bearer, JWT, prefixos de token e atribuições de segredo. A
rejeição é genérica e jamais ecoa o valor inspecionado.

Criação por `POST` e substituição completa de um draft ainda em `DRAFT` por `PUT`
usam `BILLING_PROVIDER_CONFIGURE`, decisão MFA aplicável, idempotency key e
`If-Match`/expected version. Submissão usa `BILLING_PROVIDER_SUBMIT`, calcula e
congela o hash no servidor e move para `PENDING_APPROVAL`. Aprovação/rejeição exige
`BILLING_PROVIDER_APPROVE`, checker humano distinto e decisão MFA aplicável; aprovação
produz seal de uso único. Ativação usa `BILLING_PROVIDER_ACTIVATE` e revalida
revisão, hash, seal e readiness em uma transação, movendo para `ACTIVATED`.
Drift material invalida a revisão como `INVALIDATED`; sucessora ativada move a
anterior para `SUPERSEDED`. Ausência ou divergência retorna conflito sem
persistência parcial. `providerCode`, certificação e capabilities declaradas pelo
adapter não são editáveis pelo browser.

`PAUSED` e `ENABLED` são valores do `desiredState` versionado. Pausar ou retomar
elegibilidade exige criar/substituir um `DRAFT`, submeter, obter decisão independente
e ativar a revisão aprovada. O primeiro contrato não oferece atalhos `/pause` ou
`/resume`: sem um produtor maker-checker específico, um seal action-specific não
poderia ser obtido legitimamente. A ativação de `PAUSED` continua preservando o
recovery plane e nenhuma revisão supera o kill switch independente de deploy.

Idempotência é serializada por namespace exato de ator, operação e digest da
`Idempotency-Key`. Requisições concorrentes com o mesmo provider e request hash
aguardam uma fence transacional bounded; após o primeiro commit, a concorrente relê
o journal terminal antes de qualquer validação mutável e devolve o mesmo status,
body/snapshot, `ETag`/`Location` quando aplicáveis, `X-Correlation-ID` e timestamps
originais. Não há segundo efeito, evento de negócio ou ApprovalSeal. O mesmo
namespace com payload ou provider divergente retorna
`409 BILLING_IDEMPOTENCY_CONFLICT`. Timeout ou
indisponibilidade antes de existir resultado terminal retorna `503` com
`Retry-After`; retry posterior relê o terminal exato, sem fabricar sucesso.

O primeiro approval bem-sucedido persiste somente o identificador da chave de
assinatura (`seal_key_id`) e o digest/binding necessários; não persiste o
ApprovalSeal raw nem ciphertext reversível. A primeira resposta emite o seal uma
vez. Um replay terminal rederiva deterministicamente o mesmo valor com
`reissue(binding, persistedKeyId)`, verifica key ID e digest e o devolve sem criar
novo approval, seal, evento ou efeito. Rotação não pode remover uma chave histórica
enquanto qualquer approval ou operação idempotente persistida puder referenciá-la.
Como o journal atual não possui TTL, não é válido inferir uma janela curta, como dez
minutos, para descarte; custódia e remoção segura do keyring são gate de rollout.
Chave ausente ou drift retorna `503` fail-closed, sem resposta inventada.

Toda mutação repository-local possui ainda a barreira independente
`PAYMENT_PROVIDER_CONTROL_PLANE_MUTATIONS_ENABLED`, cujo default é `false`. Ela
não é o kill switch de execução no provider nem a flag de purge. O journal
idempotente terminal é consultado antes da barreira: replay exato já concluído
continua devolvendo a resposta original mesmo com a flag `OFF`; sem terminal
preexistente, qualquer nova operação retorna
`422 BILLING_PROVIDER_ACTION_NOT_ALLOWED` antes de repository write, evento, seal
ou efeito. Leituras, auditoria e recovery permanecem disponíveis. Este ADR não
autoriza ligar a flag fora de teste hermético.

### 7.2.1 Dispensa temporária D-13.5 nas mutações AS-IS

Conforme [ADR-0050/D-13.5](ADR-0050-rbac-sod-aprovacoes-financeiras.md) e
[REQ-00059](../product/requirements/REQ-00059-temporary-all-roles-mfa-disablement.md),
quando `billing.security.super-admin-mfa-enabled=false` em DEV, HML ou PRD, a
prova MFA fica dispensada. As seis mutações já executáveis do control plane
continuam acessíveis somente ao ator humano com `ROLE_SUPER_ADMIN` por RBAC:

- `createRevision`;
- `replaceDraft`;
- `submit`;
- `approve`;
- `reject`;
- `activate`.

O waiver é decisão de policy, não segundo fator concluído. Aprovação e rejeição
persistem `mfa_required=false` com evidência nula; não podem gravar `otp`, AMR,
referência ou timestamp MFA sintético. Tenant Admin e ator sem a role continuam
sem acesso às mutações por RBAC, não por exigência de MFA.

Authority fina, política maker/checker de D-13.3, hash/revisão, ApprovalSeal,
idempotência, optimistic concurrency, auditoria, state machine e
`PAYMENT_PROVIDER_CONTROL_PLANE_MUTATIONS_ENABLED` continuam obrigatórios. O
waiver não certifica nem habilita provider, adapter, segredo, Sandbox, tráfego
externo ou efeito financeiro. Ao reativar MFA, decisão waived ainda não consumida
falha fechado; decisão ou efeito concluído permanece imutável e auditável.

## 7.3 Interaction allowlist

A projeção representa uma thread estável por `interactionId` e eventos imutáveis
por `eventId`. A listagem usa apenas o evento efetivo apontado pela thread, escolhido
por progressão monotônica de estágio; duplicata e reorder incrementam `eventCount`
e permanecem na timeline sem substituir o resumo. O detalhe ordena os eventos por
`arrivalSequence ASC`; `occurredAt` descreve tempo do evento, não a ordem observada.

A projeção pode conter:

- ID interno da interação e timestamp UTC;
- tenant ID autorizado para filtro e controle BOLA, nulo somente em evidência
  `SANITIZED_WEBHOOK_INBOX`, `INBOUND`, categoria `WEBHOOK`, sem account/command/
  invoice/payment/reconciliation refs, com reason fechado de rejeição, quarentena
  ou DLQ e visível apenas no admin;
- provider code, ambiente e direção (`OUTBOUND`, `INBOUND`, `INTERNAL`);
- categoria (`COMMAND`, `PROVIDER_RESULT`, `WEBHOOK`, `NORMALIZED_EVENT`,
  `RECONCILIATION`);
- operação e outcome normalizados;
- correlation ID interno;
- IDs internos opcionais de command, invoice, payment e reconciliation case;
- classe de status HTTP e código de erro normalizado, quando aplicáveis;
- latência, tentativa, retryable e estado de reconciliação;
- timestamps de projeção/expiração.

O detalhe admin e tenant retorna duas coleções obrigatórias e bounded. `gaps`
possui no máximo 16 itens únicos; cada `ProviderInteractionGap` contém
`fromStage`, `toStage`, `missingStages` (1–6 stages únicos) e somente
`reasonCode=EVIDENCE_NOT_OBSERVED`. Ele descreve lacuna entre stages efetivamente
observados, sem prever futuro. `canonicalLinks` possui no máximo 16
`CanonicalResourceLink` únicos, cada qual apenas com `resourceKind` em
`COMMAND|INVOICE|PAYMENT|RECONCILIATION_CASE` e `resourceId` UUID interno; URL,
tenant e decisão de autorização são proibidos. No detalhe global não impersonado,
essas referências são sempre texto não clicável. Somente o detalhe tenant com
contexto elevado já validado pode montar, por mapa client-owned allowlisted, uma
rota canônica realmente existente — no V1, apenas invoice — e a rota destino
reautoriza; nunca se deriva tenant do DTO ou do link. Interação admin com tenant
não resolvido tem `canonicalLinks=[]`.

É proibido registrar request/response body, headers, query string, URL assinada,
stack trace, e-mail, documento fiscal, nome, dado bancário, valor de segredo, PAN,
CVV, validade, portador, token de cartão ou idempotency key em claro. IDs externos só
podem aparecer como fingerprint HMAC com separação de domínio quando a correlação
não puder ser feita por ID interno.

## 7.4 Retention and consistency

A projeção diagnóstica terá retenção padrão de 90 dias, configurável entre 30 e 365
dias por política da plataforma. `expiresAt` é definido no insert; purge é bounded,
auditável e não remove o fato financeiro de origem. Replay da mesma identidade de
origem cria evento duplicado ligado por ID lógico, sem FK capaz de reter o original,
e herda a expiração original com somente uma graça técnica mínima bounded. Uma
redelivery externa real precisa de novo `sourceRecordId` e recebe sua própria janela.
Quando o evento efetivo expira, a thread deixa imediatamente list/detail: marker
remanescente nunca é promovido a verdade atual e só subsiste até sua graça de purge.
Legal hold ou exportação exigem requisito e base de acesso próprios.

Consistência é eventual e explicitada por `projectedAt` e freshness. Uma leitura
tenant nunca deriva freshness de checkpoint global: sem watermark atribuível ao
tenant, responde conservadoramente `PARTIAL`, evitando inferência de atividade de
outros tenants. Falha de projeção não faz rollback do fato tenant-local já commitado;
um mecanismo durável de publicação/recovery deve ser usado quando o adapter real for
integrado. A primeira implementação fornece o port de gravação e consultas, sem
afirmar entrega externa end-to-end antes do TP-00011.

## 7.5 API and authorization

As APIs de configuração ficam sob
`/api/v1/admin/billing/payment-providers/**`; resumo/lista/detalhe operacional
global ficam sob `/api/v1/admin/billing/payment-provider-interactions/**`; e a
consulta de um tenant fica sob
`/api/v1/tenants/{tenantId}/billing/payment-provider-interactions/**`. Não existe
alias `/api/v1/billing/**`, e nenhuma API aceita provider via header de roteamento.
As rotas tenant-scoped exigem correspondência path/token/contexto, um
`X-Billing-Context-ID` válido e `X-Billing-Purpose` antes do primeiro store.
Authorities mínimas:

| Operação | Authority | Controle adicional |
| --- | --- | --- |
| Listar/detalhar providers | `BILLING_PROVIDER_READ` | Cache `no-store`, auditoria de acesso administrativo. |
| Criar/editar draft | `BILLING_PROVIDER_CONFIGURE` | Decisão MFA aplicável, justificativa, idempotência, optimistic lock e auditoria. |
| Submeter draft | `BILLING_PROVIDER_SUBMIT` | Decisão MFA aplicável; congela hash e maker; sem ativação implícita. |
| Aprovar/rejeitar revisão | `BILLING_PROVIDER_APPROVE` | Checker humano distinto, decisão MFA aplicável e decisão auditada. |
| Ativar revisão aprovada | `BILLING_PROVIDER_ACTIVATE` | Decisão MFA aplicável, ApprovalSeal de uso único, revalidação e composição fail-closed; não supera kill switch. |
| Pausar/retomar elegibilidade desejada | Workflow de revisão (`CONFIGURE` → `SUBMIT` → `APPROVE` → `ACTIVATE`) | `desiredState=PAUSED/ENABLED`; sem endpoint direto ou seal sem produtor; recovery plane permanece ligado. |
| Consultar interações | `BILLING_PROVIDER_INTERACTION_READ` | Filtro tenant server-authoritative, contexto financeiro nas rotas tenant e redaction. |
| Replay, reconcile, probe ou switch | Não exposta neste slice | Exige contrato, MFA/SoD/approval e idempotência específicos. |

`ROLE_SUPER_ADMIN` não substitui nem é requisito cumulativo da authority fina. A
rota administrativa exige identidade autenticada, boundary global sem impersonação
e a authority correspondente; operações humanas registram o principal humano
quando aplicável. Configurações de realm/IAM declaram/scopam as novas authorities,
mas grants/composites reais são um passo de rollout separado; testes locais usam
identidades sintéticas.

Somente para obter o waiver temporário de `D-13.2`, `ROLE_SUPER_ADMIN` torna-se
condição cumulativa de elegibilidade; a role não substitui a authority da operação.

Todo sucesso autenticado do contrato exige `Cache-Control: no-store` e
`X-Correlation-ID` UUID; quando o body contém `correlationId`, ambos precisam ser
iguais. Cada operação aceita somente seu status declarado (`201` create, `202`
submit e `200` nas demais) e o ETag decimal quoted precisa corresponder à revisão do
recurso primário. Create devolve apenas a `Location` local canônica da revisão.
Erros usam `application/problem+json`, status/correlation coerentes com HTTP e
errorCode allowlisted por rota; `401` exige `WWW-Authenticate: Bearer` e `503`
exige `Retry-After` inteiro positivo. Contrato divergente falha fechado no cliente.

## 7.6 Observability

Métricas usam provider, operação, outcome e ambiente como dimensões bounded. Tenant,
correlation ID, command ID e IDs externos ficam apenas em registros autorizados,
nunca como labels. Logs carregam identificadores internos minimizados e reason codes,
sem serializar DTOs completos. O frontend exibe freshness e não interpreta ausência
de evento como sucesso.

# 8. AI Agent Considerations

Agentes podem criar documentação, migrations aditivas, backend, frontend e testes
locais com dados sintéticos. Não podem acessar secret store real, recuperar API key,
registrar webhook, chamar ASAAS/Stripe, liberar parâmetro Sandbox, habilitar flag
ambiental, executar replay ou deploy.

Agentes também não podem remover o mecanismo MFA, fabricar evidência ou aplicar o
waiver fora de `D-13.2`. A autorização cobre somente artefatos repository-local;
Tenant Admin, HML, PRD e efeitos externos permanecem excluídos.

O agente não pode fabricar sucesso de provider para popular runtime. Fixtures ficam
somente nos testes. A tela vazia é o comportamento correto enquanto não houver
interações reais persistidas por um fluxo autorizado.

Qualquer pedido futuro de probe, envio, replay, reconciliação mutável, habilitação em
Sandbox ou produção requer escopo explícito e verificação dos gates próprios.

# 9. Implementation Plan

1. aprovar REQ-00056 e os casos de uso de configuração e investigação;
2. criar os cinco IPs filhos do TP-00039;
3. adicionar migration global forward-only para configuração, histórico e projeção;
4. implementar domínio, ports, casos de uso, JDBC e APIs administrativas;
5. implementar `Conecta > Pagamentos` com as duas abas e guards;
6. provar contratos, concorrência, redaction, RBAC, a11y e integração frontend/backend
   em testes herméticos;
7. manter adapters, Sandbox, probes, replay e rollout bloqueados até os planos
   responsáveis produzirem evidência e autorização.

A emenda temporária `D-13.2` é implementada separadamente pelo
[TP-00047](../../../docs/specs/TP-00047-temporary-super-admin-invoicing-mfa-waiver.md),
sem alterar os gates externos deste plano.

Rollback de código não remove tabelas nem histórico. O desired state pode ser
forçado para `OFF`; o deployment kill switch permanece a barreira independente.

# 10. Validation

O slice local é válido quando:

- migration instala de forma limpa e os seeds retornam ASAAS primário e Stripe
  contingencial `OFF/NOT_CERTIFIED` sem segredo;
- APIs de listagem, draft, submission, approval e activation aplicam authorities,
  idempotência, decisão MFA/SoD, redaction e optimistic concurrency;
- em DEV e somente com o toggle desligado, as seis mutações aceitam Super Admin
  humano sem prova MFA e persistem waiver sem evidência sintética; Tenant Admin,
  outro ator, HML e PRD falham fechados;
- reativar MFA recusa decisão waived ainda não consumida sem apagar histórico;
- nenhum update da UI produz chamada externa ou muda o estado efetivo sem todos os
  gates server-side;
- a API de interações pagina e filtra registros sintéticos allowlisted sem payload;
- testes sentinela rejeitam nomes/valores proibidos em API e DOM;
- a flag local de mutation nasce `OFF`, bloqueia nova operação com `422` e não
  impede replay terminal exato, leitura ou recovery;
- gaps e referências canônicas respeitam shape/bounds, nenhuma URL é aceita, o
  admin não navega e o tenant navega somente a invoice por mapa local com nova
  autorização no destino;
- a UI usa o backend real no contrato, cobre loading/empty/error/forbidden/conflict e
  permanece provider-neutral;
- testes focalizados, suíte impactada e governança documental passam.

Certificação ASAAS em Sandbox e tráfego real não fazem parte do critério de conclusão
deste ADR.

# 11. Risks and Mitigations

| Risk | Mitigation |
| --- | --- |
| Operador confunde desired state com provider ativo | Exibir desired, effective, readiness e reason codes separadamente; composição fail-closed server-side. |
| Alias de segredo vaza seu valor | Aceitar apenas identificador lógico validado; nunca resolver ou devolver material na API. |
| Metadata vira canal para PAN/credencial | Policy NFKC/Luhn e sentinelas equivalentes no backend e Zod para alias, purpose, reason e referências; erro não ecoa o input. |
| Timeline vira segunda verdade financeira | Projeção read-only, links para IDs canônicos e proibição de editar status financeiro. |
| Projeção central amplia exposição cross-tenant | Allowlist mínima, authority específica, filtro server-side, retenção e auditoria. |
| Concorrência perde atualização ou duplica efeito | `If-Match` para intents distintas; fence idempotente bounded e exact replay do resultado terminal para a mesma intenção. |
| Stripe aparece como fallback pronto | Estado inicial e badge permanentes `CONTINGENCY`, `OFF`, `NOT_CERTIFIED`; sem adapter por este plano. |
| Botão de configuração gera tráfego | Kill switch de deploy e readiness independentes; update local não chama provider. |
| Mutação local fica acessível antes da qualificação | `PAYMENT_PROVIDER_CONTROL_PLANE_MUTATIONS_ENABLED=false` por default; terminal idempotente é relido antes do gate e nova intenção recebe 422. |
| Dispensa MFA ser confundida com autorização de mutação | Exigir cumulativamente toggle `false`, humano, `ROLE_SUPER_ADMIN` e authority fina em DEV/HML/PRD; manter mutation/kill switches independentes. |
| Waiver persistido aparenta MFA real | Persistir `mfa_required=false` com evidência nula e rejeitar método/AMR/timestamp sintético. |
| Rotação remove chave ainda referenciada por replay | Persistir `seal_key_id`, rederivar/verificar o seal sem raw persistido e reter a chave histórica enquanto qualquer approval/operação idempotente a referenciar; ausência/drift retorna 503 e bloqueia rollout. |
| Link global contorna boundary tenant | Admin renderiza UUID como referência não clicável; somente rota tenant contextualizada constrói destino allowlisted e o destino reautoriza. |
| Retry após timeout duplica cobrança | Nenhum replay operacional/provider neste slice; o replay HTTP idempotente do control plane só reproduz o terminal local exato, e `UNKNOWN` externo continua sujeito a reconciliação. |
| Métricas explodem cardinalidade | Allowlist de labels bounded; IDs apenas em consulta autorizada. |
| Payload sensível entra por erro de adapter futuro | DTO fechado, recorder sanitizante, testes sentinela e rejeição de campo livre. |

# 12. Related ADRs

- [ADR-0011](ADR-0011-resilience-retry-circuit-breaker.md) — retry e efeito incerto;
- [ADR-0012](ADR-0012-error-handling-observability.md) — erros e observabilidade;
- [ADR-0023](ADR-0023-agnostic-payment-provider-integration.md) — providers, ASAAS primário e fallback desligado;
- [ADR-0024](ADR-0024-seguranca-tokenizacao-cartao-recorrente.md) — hosted checkout e exclusão de PAN/CVV;
- [ADR-0026](ADR-0026-billing-api-tenant-admin-cutover.md) — namespace administrativo e tenant;
- [ADR-0027](ADR-0027-catalogo-global-faturamento-local.md) — control plane global e fatos tenant-local;
- [ADR-0050](ADR-0050-rbac-sod-aprovacoes-financeiras.md) — authority fina, MFA e SoD;
- [ADR-0051](ADR-0051-slo-capacidade-rollout-billing.md) — kill switches e rollout.

# 13. References

- [TP-00039 — Payment Provider Management Console](../../../docs/specs/TP-00039-payment-provider-management-console.md)
- [REQ-00056 — Gestão e observabilidade de provedores de pagamento](../product/requirements/REQ-00056-payment-provider-management-observability.md)
- [REQ-00059 — Dispensa temporária de MFA para todas as roles em DEV, HML e PRD](../product/requirements/REQ-00059-temporary-all-roles-mfa-disablement.md)
- ANL-00051 — Inventário do uso de MFA para Super Admin em DEV
- [TP-00047 — Desligamento temporário do MFA do Super Admin em DEV](../../../docs/specs/TP-00047-temporary-super-admin-invoicing-mfa-waiver.md)
- [UC-00053 — Manage Payment Provider Configuration](../product/use-cases/UC-00053-manage-payment-provider-configuration.md)
- [UC-00054 — Inspect Payment Provider Interactions](../product/use-cases/UC-00054-inspect-payment-provider-interactions.md)
- [Payment Provider Console OpenAPI v1](../../../docs/api_contracts/payment-provider-console-v1.openapi.yaml)
- [Documentação central ASAAS](https://central.ajuda.asaas.com/hc/pt-br/sections/32107364983451)
- [Códigos de respostas e erros de webhook ASAAS](https://central.ajuda.asaas.com/hc/pt-br/articles/32107653311643-C%C3%B3digos-de-respostas-e-erros-de-webhook)
- [Como utilizar o Sandbox ASAAS](https://central.ajuda.asaas.com/hc/pt-br/articles/32107684279579-Como-utilizar-nosso-Sandbox-%C3%A1rea-de-testes)
- [Funcionalidades testáveis em Sandbox](https://central.ajuda.asaas.com/hc/pt-br/articles/32107816472219-Quais-funcionalidades-podem-ser-testadas-em-Sandbox)
- [Liberação de parâmetros em Sandbox](https://central.ajuda.asaas.com/hc/pt-br/articles/43327091402011-Como-liberar-par%C3%A2metros-na-conta-em-Sandbox)
- [Checkout transparente ASAAS](https://central.ajuda.asaas.com/hc/pt-br/articles/32108011423643-O-Asaas-possui-checkout-transparente)
- [Links de Pagamento ASAAS](https://central.ajuda.asaas.com/hc/pt-br/articles/32108068317979-Links-de-Pagamento)
- [Tokenização ASAAS](https://central.ajuda.asaas.com/hc/pt-br/articles/32108539373083-Tokeniza%C3%A7%C3%A3o)
- [Como gerar uma chave de API ASAAS](https://central.ajuda.asaas.com/hc/pt-br/articles/33618186066331-Como-gerar-uma-chave-de-API)

# 14. Decision Lifecycle

`Accepted` em 2026-09-06 e emendada em 2026-09-09. Proveniência:
`HUMAN_EXPLICIT` para criar documentação e implementar localmente o TP-00039 e
para a exceção temporária `D-13.2`; `AI_MATERIALIZATION` para a decomposição técnica
provider-neutral, sujeita aos ADRs aceitos e às invariantes descritas. A decisão não
concede autorização para integração externa, credenciais, Sandbox, produção, rollout
ou efeitos financeiros reais.

Revisar quando houver: primeiro adapter certificado; necessidade de replay/probe;
roteamento por tenant; novo provider; secret store definitivo; mudança de retenção;
ou requisito legal de export/legal hold.

# 15. Change Log

| Version | Date | Author | Changes |
| --- | --- | --- | --- |
| 1.8 | 2026-09-11 | Proprietário do SaaS / Codex (IA), reconciliação | Supera o recorte histórico D-13.2 e alinha o control plane a D-13.5/REQ-00059 v1.8: dispensa temporária de MFA nos três ambientes e autorização das mutações preservada por RBAC. |
| 1.7 | 2026-09-09 | Proprietário do SaaS / Codex (IA), materialização | Aplica `D-13.2` às seis mutações AS-IS de configuração provider somente para Super Admin humano em DEV, distinguindo waiver de evidência MFA e preservando SoD, seals, switches, auditoria, rollback e proibição de efeitos externos. |
| 1.6 | 2026-09-06 | Codex / hardening de contrato e frontend | Fecha shapes de gaps/links sem URL e navegação tenant, policy de metadata, kill switch local default OFF, envelope HTTP estrito e custódia do keyring: `seal_key_id` persistido, reemissão determinística sem raw/ciphertext e retenção enquanto houver referência, com 503 fail-closed em ausência/drift. |
| 1.5 | 2026-09-06 | Codex / revisão de concorrência | Torna exact replay concorrente um invariante: uma única execução por namespace idempotente, releitura do terminal original, 409 para divergência e 503/Retry-After sem resultado fabricado quando a fence expira. |
| 1.4 | 2026-09-06 | Codex / revisão de paridade e segurança | Decide thread/evento efetivo monotônico, timeline por chegada, quarantine sem topologia, freshness tenant conservadora, authority fina sem role cumulativa e retenção anti-pinning para replay. |
| 1.3 | 2026-09-06 | Codex / revisão de segurança | Fecha referências catalogadas contra URI/path/SSRF e vincula approval ao baseline ativo/versionado, recusando activation após drift concorrente. |
| 1.2 | 2026-09-06 | Codex / decisão técnica derivada da revisão de segurança | Torna explícita a quarentena admin com tenant ainda não resolvido e elimina atalhos pause/resume sem produtor maker-checker; elegibilidade muda apenas por revisão aprovada e ativada. |
| 1.1 | 2026-09-06 | Codex / solicitação humana explícita | Alinha lifecycle, authorities, endpoints, contexto tenant, proveniência e contrato OpenAPI ao REQ-00056 v1.1, UC-00053 e UC-00054; externalidade permanece OFF. |
| 1.0 | 2026-09-06 | Codex / solicitação humana explícita | Decide control plane global sem segredos, projeção operacional sanitizada, ASAAS primário, Stripe contingencial desligado e gates fail-closed para qualquer efeito externo. |
