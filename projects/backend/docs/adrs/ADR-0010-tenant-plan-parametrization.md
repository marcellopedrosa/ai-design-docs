---
document_id: "ADR-0010"
primary_nature: "Decisao"
objective: "Registrar a decisão arquitetural “Tenant Plan Parametrization and Resource Limit Override Architecture”, seus motivadores, alternativas e consequências."
scope: "Decisão, componentes, integrações e limites explicitamente descritos em “Tenant Plan Parametrization and Resource Limit Override Architecture”."
non_objectives: "Não implementar a decisão, substituir requisitos relacionados nem atestar capabilities ou ambientes sem evidência explícita."
owner: "@DomainExpert, @ImplementerCore"
status: "Accepted"
date: "2026-08-25"
version: "3.7"
keywords: "adr, decisao, arquitetura, tenant, plan, parametrization, and, resource, limit, override, architecture"
related_files: "docs/adrs/README.md, docs/adrs/ADR-0028-entitlements-versionados-tenant-local.md, docs/adrs/ADR-0029-taxonomia-tipificada-entitlements.md, docs/adrs/ADR-0030-composicao-deterministica-enforcement-entitlements.md, docs/adrs/ADR-0032-adocao-versionada-grandfathering-entitlements.md, docs/adrs/ADR-0034-efeitos-transicao-nao-destrutiva-entitlements.md, docs/adrs/ADR-0035-migracao-evidence-first-entitlements-legados.md, docs/adrs/ADR-0036-cache-lkg-fail-safe-entitlements.md, docs/adrs/ADR-0037-boundary-fisico-entitlements-billing.md, docs/adrs/ADR-0038-pricing-tipado-moeda-cadencia.md"
code_references: "EntitlementBundleVersion, ContractEntitlementSnapshot, PriceVersion, PromotionVersion, PromotionCombinationPolicyVersion, FeatureGateService, AuditPort, ResourceLimitService, TenantResourceLimitsChangedEvent, EnforceLimitUseCase, TenantLimitAlertEvent, PlanDefaultsChangedEvent"
principal_statement: "O ADR permanece Accepted apenas para objetivos não conflitantes; suas cláusulas mutáveis de entitlement, pricing, promoções e Billing foram restringidas ou substituídas pelos ADRs subsequentes até ADR-0051 e não devem ser implementadas como autoridade vigente."
---

# ADR-0010 - Tenant Plan Parametrization and Resource Limit Override Architecture

- Date: 2026-08-25
- Status: Accepted
- Version: 3.7
- Authors / Owners: @DomainExpert, @ImplementerCore
- Reviewers: @CleanArchitecture, @BillingEng, @SecurityOAuth, @AdapterDev
- Stakeholders: Engineering Team, Product Owner, Startup Founders, SaaS Administrators

---

> **Subsequent decision notice — ADR-0028/ADR-0029/ADR-0030/ADR-0032/ADR-0034/ADR-0035/ADR-0036/ADR-0037/ADR-0038/ADR-0039/ADR-0040/ADR-0041/ADR-0042/ADR-0043/ADR-0044/ADR-0045/ADR-0047/ADR-0048/ADR-0049/ADR-0050/ADR-0051 (Accepted,
> até 2026-08-25):** este ADR
> permanece histórico e `Accepted` para objetivos não conflitantes, mas não pode
> mais ser executado como autoridade mutável de entitlement. O
> [ADR-0028](./ADR-0028-entitlements-versionados-tenant-local.md) tem precedência
> sobre `plan_default_limits` vivo, propagação retroativa, resolução por
> `COALESCE`, enum/default/hardcode como fallback e `NULL` como autorização
> implícita. O alvo aprovado é `EntitlementBundleVersion` global imutável,
> `ContractEntitlementSnapshot` completo tenant-local e projeção local derivada.
> O [ADR-0029](./ADR-0029-taxonomia-tipificada-entitlements.md) também proíbe
> override numérico genérico e separa base comercial, add-on, promoção, exceção
> operacional, restrição de segurança/abuso/compliance e uso observado.
> O [ADR-0030](./ADR-0030-composicao-deterministica-enforcement-entitlements.md)
> substitui semanticamente `last-write-wins`, `NULL=UNLIMITED`, sentinelas e
> inferência hard/soft por plano por tipos, operadores, estados e modos explícitos.
> O [ADR-0032](./ADR-0032-adocao-versionada-grandfathering-entitlements.md)
> substitui propagação automática, reset implícito e adoção de default vivo por
> contrato pinned e transição para versão exata mediante policy aceita, nova
> revisão e novo snapshot tenant-local.
> O [ADR-0034](./ADR-0034-efeitos-transicao-nao-destrutiva-entitlements.md)
> invalida reset/delete destrutivo, dual-snapshot grace e retroatividade: redução
> preserva dados, representa excesso como dívida de capacidade e só permite uma
> operação anteriormente admitida terminar por lease bounded.
> O [ADR-0035](./ADR-0035-migracao-evidence-first-entitlements-legados.md)
> torna enum/settings/default/seed apenas evidência legada, exige manifest exato,
> backfill/shadow tenant-local e cutover fenced, e proíbe fallback pós-cutover.
> O [ADR-0036](./ADR-0036-cache-lkg-fail-safe-entitlements.md) substitui qualquer
> fail-open/cache/LKG histórico: cache é derivado, somente `UNAVAILABLE` pode
> considerar LKG positivo low-risk allowlisted, e quota/capacidade/custo,
> financeiro/provider, administração e risco exigem estado atual. Os TTLs/epochs
> da ADR-0036 prevalecem e nenhum contexto tenant ausente pode usar datasource
> compartilhado.
> O [ADR-0037](./ADR-0037-boundary-fisico-entitlements-billing.md) mantém
> Entitlements como slice coeso dentro de `contexts.billing`, substitui as
> fronteiras físicas históricas por APIs públicas estreitas, adapters
> platform/tenant, migrations separadas, marker/outbox e cache derivado, e exige
> `TenantScopeGuard` antes de toda transação tenant-local.
> O [ADR-0038](./ADR-0038-pricing-tipado-moeda-cadencia.md) substitui preços,
> cadências, timing, aritmética, rounding e overrides negociados implícitos por
> `PriceVersion` tipada, publicada imutável e pinada no contrato. Somente BRL e os
> modelos/cadências allowlisted podem ser publicados inicialmente; preço de
> overage segue o rating/billability já definido em `D-06`/ADR-0045, ainda não
> implementado.
> O [ADR-0039](./ADR-0039-taxonomia-beneficios-promocionais.md) substitui
> qualquer interpretação de desconto, cortesia ou promoção como override livre:
> `PromotionVersion` publicada é imutável, benefícios usam tipos fechados e
> outputs monetários, `PROMOTIONAL_GRANT` e crédito/saldo permanecem separados.
> O [ADR-0040](./ADR-0040-elegibilidade-promocional-seguranca-cupons.md)
> substitui filtros, segmentos, claims, settings e cupons livres como autoridade
> promocional: cada promoção fixa policy versionada, somente facts server-derived
> alimentam a álgebra tri-state e `INDETERMINATE` falha fechado. Código de cupom é
> identificador opaco tenant/account-scoped, protegido por HMAC sem plaintext e
> nunca autenticação, grant, reserva ou consumo.
> O [ADR-0041](./ADR-0041-stacking-waterfall-promocional-deterministico.md)
> substitui prioridade, combinação ou desconto acumulado implícitos por
> `PromotionCombinationPolicyVersion` publicada/imutável e função pura sobre
> `PricingResult` pinado e candidatas `ELIGIBLE`. `PromotionVersion` é pacote
> atômico, a ordem é canônica, best price compara somente resultado monetário BRL
> pre-tax/pre-credit/pre-provider e caps/alocação são tipados e determinísticos.
> O mapeamento Start/Business/Premium e a billability de excedente não foram
> ratificados. `D-04.3` foi fechado no ADR-0038 e `D-04.4-A` no ADR-0039;
> `D-04.4-B` foi fechado no ADR-0040, `D-04.4-C` no ADR-0041,
> `D-04.4-D` no ADR-0042 e `D-04.4-E` no ADR-0043. As decisões seguintes foram
> fechadas nos ADRs canônicos até o ADR-0051. `D-00 = RELEASED_WITH_SCOPE —
> HUMAN_EXPLICIT — TP-00013 local-only` permite implementação hermética local;
> artefatos restantes e evidências ainda bloqueiam readiness/efeitos.
> Não implemente as cláusulas
> restringidas deste documento.

# 1. Context

O Contador Fiscal Inteligente opera com três planos de assinatura (`START`, `BUSINESS`, `PREMIUM`), cada um com limites quantitativos bem definidos na documentação de requisitos (REQ-00005 §3.2, REQ-00001 BR-015, BR-016). O módulo Billing consolida localmente uso, fatura e cobrança; qualquer interação financeira externa segue o [ADR-0023](./ADR-0023-agnostic-payment-provider-integration.md).

Limites atuais por plano conforme documentação oficial:

| Recurso | Start | Business | Premium | Fonte |
|---|:---:|:---:|:---:|---|
| Documentos cadastrados (base) | 3 | 50 | Ilimitado | [Visão de produto](../product/business/product-vision.md), REQ-00001 BR-005 |
| Ampliação máxima de Documentos | Até 10 | Até 200 | N/A | REQ-00001 BR-016 |
| Mensagens de chatbot/dia por canal | 5 | 1.000 | 10.000 | REQ-00011 BR-003/BR-004 |
| Consultas fiscais/mês | 15 | 500 | Ilimitado | REQ-00001 BR-015 |
| Tokens LLM/mês | — | — | — | ADR-0007 (quotas por tenant) |
| Sessões Simultâneas (Usuários Acesso Web) | 5 | 25 | 100 | REQ-00001 BR-015, UC-00016 |
| Cobrança de excedentes | Não | Sim (BR-017) | Tarifa reduzida | REQ-00001 BR-017 |

**Problema atual:**

No backend, os planos são representados apenas por Enums sem valores numéricos (`SubscriptionPlan` no módulo tenant, `Plan` no módulo billing). Não existe mecanismo para:

1. **Armazenar os limites-base de cada plano** no banco de dados (hoje vivem apenas na documentação).
2. **Sobrescrever limites por tenant** para add-ons comerciais (ex: "+10 Documentos para o escritório X" sem mudar o plano — REQ-00001 BR-016).
3. **Distinguir soft-limit de hard-limit** — o plano Start bloqueia ao exceder, enquanto Business cobra excedente (REQ-00005 BR-005, REQ-00001 BR-017).
4. **Validar localmente** se uma operação excede o limite antes de gerar a cobrança externa, sem consultar o provider em tempo de request.
5. **Definir comportamento de upgrade/downgrade** — o que acontece com os overrides quando um tenant muda de plano (REQ-00005 BR-003).

Essa lacuna impacta diretamente o `FeatureGateService` (REQ-00005 §5.2), o `ConsultaFiscalCreditDeductionListener` (billing — task 2.4.5 pendente) e a cadeia local de registro de uso → fechamento de fatura → cobrança pelo provider definido no [ADR-0023](./ADR-0023-agnostic-payment-provider-integration.md).

---

# 2. Original Decision Statement — Historical / Non-executable

> **Do not implement:** Sections 2 through 11 preserve the original `v1.x` design
> for audit history. Their tables, SQL, pseudocode, endpoint, event, cache, reset,
> rollout and validation instructions are not an implementation plan after
> ADR-0028, ADR-0029, ADR-0030 and ADR-0032. Any future design must start from the
> tenant-local snapshot/projection authority, aplicar os efeitos do ADR-0034, a
> migração do ADR-0035, failure/cache/LKG do ADR-0036 e o boundary físico do
> ADR-0037, e aguardar `D-06` e `D-00` conforme
> aplicável.

O sistema implementará um **modelo híbrido de duas tabelas** para parametrização de limites de plano:

1. **`plan_default_limits`** (módulo `billing`, database `saas_billing`) — Tabela de referência com os limites-padrão de cada plano. Gerenciada pelo Product Owner. Mutável globalmente (quando se decide que "Business agora terá 600 consultas/mês", atualiza-se uma única linha e todos os tenants Business sem override são afetados).

2. **`tenant_resource_overrides`** (módulo `tenant`, database `saas_tenant`) — Tabela de exceções por tenant. Contém apenas os campos sobrescritos pelo Super Admin. Campos `NULL` significam "usar o padrão do plano".

O **limite vigente** de qualquer recurso para um tenant é calculado como:

```
limite_vigente = COALESCE(tenant_resource_overrides.campo, plan_default_limits.campo)
```

Adicionalmente, a semântica de **"Ilimitado"** é representada por `NULL` na coluna do limite (ex: Premium `max_documentos = NULL`). Qualquer lógica de verificação que encontra `NULL` trata como ilimitado, sem necessidade de constantes mágicas.

---

# 3. Decision Drivers

- **Modelo de negócio exige flexibilidade de add-ons:** Clientes Business frequentemente contratam "+10 Documentos" ou "+200 consultas/mês" mediante cobrança adicional, sem upgrade obrigatório de plano (REQ-00001 BR-016, REQ-00001 BR-017). O sistema precisa persistir essas exceções por tenant.
- **Desacoplamento do provider de pagamento:** Validações de limite (rate limiting, bloqueio de cadastro de Documento) devem ser resolvidas localmente com latência sub-milissegundo. Billing é responsável pela fatura e o provider definido no [ADR-0023](./ADR-0023-agnostic-payment-provider-integration.md) executa somente capacidades financeiras externas, sem aplicar limites do produto.
- **Distinção soft-limit vs hard-limit:** O plano Start bloqueia (hard-limit), enquanto Business permite excedente com cobrança (soft-limit). Esta lógica precisa de dados estruturados no banco, não hardcoded no Enum (REQ-00005 BR-005).
- **Auditabilidade:** Alterações nos limites de um tenant impactam faturamento e devem ser auditáveis via `AuditPort` (ADR-0006 — ação `tenant:limits_override`).
- **Upgrade/downgrade previsível:** A mudança de plano deve ter comportamento determinístico sobre os limites vigentes (REQ-00005 BR-003). Separar defaults de overrides torna isso trivial.
- **Evolução dos planos sem migration per-tenant:** Quando o Product Owner altera um default do plano, todos os tenants sem override são afetados automaticamente. Sem necessidade de UPDATE em massa.

---

# 4. Considered Options

## Option 1: Tabela única `tenant_resource_limits` por tenant

Description: Cada tenant recebe uma linha com todos os limites copiados do seu plano na criação. Overrides atualizam essa linha diretamente.

Pros:
- Query simples: uma única tabela, um único `SELECT`.
- Sem necessidade de `COALESCE`.

Cons:
- **Impossível distinguir "valor é padrão do plano" de "valor é override intencional do Admin".** Se Business muda de 500 para 600 consultas/mês, não há como saber quais tenants têm 500 por default vs por override.
- **Upgrade/downgrade complexo:** Ao mudar de plano, quais campos resetar e quais preservar?
- **Evolução global dos planos exige UPDATE em massa** em todos os tenants daquele plano que não possuem override — mas não há flag confiável para isso.

## Option 2: Configuração via metadata do provider

Description: Armazenar limites como metadados do cliente no provider de pagamento, usando um sistema externo como source of truth.

Pros:
- Single source of truth entre billing e limites.

Cons:
- **Latência inaceitável** para validações em tempo de request (chatbot WhatsApp → validar limite diário → chamada remota em vez de leitura local).
- **Viola Clean Architecture:** O domínio dependeria de um provedor externo para regras core de negócio.
- **Indisponibilidade do provider bloqueia operações locais** que não deveriam depender de rede.

## Option 3: Design Híbrido — `plan_default_limits` + `tenant_resource_overrides` (Selecionada)

Description: Tabela de referência com defaults por plano + tabela de exceções por tenant com campos nullable. O limite vigente é `COALESCE(override, default)`.

Pros:
- **Distinção clara entre default e override:** Campo `NULL` no override = usar default. Campo preenchido = override intencional.
- **Evolução global sem migration:** Alterar o default do plano impacta todos os tenants sem override automaticamente.
- **Upgrade/downgrade trivial:** Apagar a linha de override e os novos defaults do plano entram automaticamente.
- **Teto de amplificação nativo:** `plan_default_limits.max_documentos_amplification` limita até onde o Admin pode sobrescrever.
- **Semântica de ilimitado clara:** `NULL` = ilimitado, sem constantes mágicas.

Cons:
- Requer `COALESCE` em toda query de limite (ou um domain service que encapsula).
- Duas tabelas em dois databases (billing e tenant) — exige consulta cross-module via Spring Modulith API.

---

# 5. Original Decision Outcome — Historical / Non-executable

**Option 3 (Design Híbrido)** foi selecionada.

Fatores-chave:

- **Source of truth dos defaults centralizada:** A tabela `plan_default_limits` é a referência canônica dos limites de cada plano, substituindo dados hardcoded em Enums e erradicando a dispersão documental.
- **Override por tenant sem ambiguidade:** Se o campo é `NULL` no override, usa-se o default — sem flags booleanas imprecisas como `overridden_by_admin`.
- **Upgrade/downgrade limpo:** `DELETE FROM tenant_resource_overrides WHERE tenant_id = ?` reseta os limites para o novo plano. Somente se o Admin re-aplicar overrides ao novo plano, eles reaparecerão.
- **Evolução natural:** Quando o Product Owner decide "Business agora tem 600 consultas/mês", um `UPDATE plan_default_limits SET max_serpro_query_monthly = 600 WHERE plan = 'BUSINESS'` afeta todos os tenants Business sem override — zero trabalho adicional.

Tradeoffs aceitos:

- Complexidade de duas tabelas em dois databases. Mitigado por: `ResourceLimitService` (domain service no módulo tenant) encapsula a lógica de `COALESCE` e expõe uma API simplificada para os consumidores.
- Cross-module dependency tenant → billing para buscar defaults. Mitigado por: `BillingApi` (API pública do módulo billing conforme Spring Modulith) expõe um método `getPlanDefaults(Plan)` que retorna os defaults de um plano.

---

# 6. Consequences

Positive Consequences:

- Limites de plano persistidos no banco — eliminada a dependência de valores hardcoded/documentação.
- Add-ons comerciais (ampliação de Documentos, pacotes de consultas extras) suportados nativamente.
- `FeatureGateService` ganha uma fonte de dados estruturada para validações em tempo de request.
- Evolução dos planos (alterar limites globais) sem impacto em overrides existentes.
- Upgrade/downgrade com comportamento determinístico e testável.
- Auditoria integrada para alterações de limites (ADR-0006).

Negative Consequences:

- Duas tabelas em dois databases adicionam complexidade na query de limite vigente.
- O domain service `ResourceLimitService` torna-se um componente crítico — falha nele implica incapacidade de resolver limites.
- Migração inicial requer popular `plan_default_limits` com os valores documentados.

Neutral Consequences:

- Ponto de entrada administrativo para uma futura UI de "Gestão de Planos" pelo Product Owner (self-service de alteração de defaults).
- Novos recursos adicionados ao SaaS precisarão de coluna correspondente em ambas as tabelas.

---

# 7. Impact

- **Architecture:** Novo Value Object `ResourceLimits` no shared/types. Novo domain service `ResourceLimitService` no módulo tenant. Nova API pública `BillingApi.getPlanDefaults(Plan)` no módulo billing. Evento `TenantResourceLimitsChangedEvent` publicado quando overrides são alterados.
- **Infrastructure:** Flyway migration para `plan_default_limits` em `saas_billing` e `tenant_resource_overrides` em `saas_tenant`. Seeds com valores de REQ-00005 §3.2.
- **Security:** Endpoint `PUT /api/v1/admin/tenants/{tenantId}/resource-overrides` restrito a `ROLE_SUPER_ADMIN`. Validação de teto de amplificação impede overrides além do permitido pelo plano.
- **Development Process:** Todo novo recurso com limite por plano exige: (1) coluna em `plan_default_limits`, (2) coluna nullable em `tenant_resource_overrides`, (3) campo no VO `ResourceLimits`.
- **Data Architecture:** 2 novas tabelas. `plan_default_limits` em `saas_billing` (3 linhas iniciais — START, BUSINESS, PREMIUM). `tenant_resource_overrides` em `saas_tenant` (0 a N linhas, apenas quando overrides existem).
- **Observability:** Métricas agregadas: `tenant_resource_override_count` (gauge) e `tenant_limit_exceeded_total` (counter com `metric_type` e `enforcement` somente quando seus valores forem allowlisted). ADR-0012 v1.2 proíbe `tenant_id` como label; investigação tenant-scoped usa `audit_log` protegido.

---

# 8. Historical AI Agent Instructions — Do Not Execute

Agent Roles Impacted:

- **@DomainExpert:** Modela `ResourceLimits` (Value Object), `TenantResourceOverride` (Entity), e `PlanDefaultLimits` (Entity/Reference Data). Define regra de `COALESCE` como lógica de domínio pura.
- **@ImplementerCore:** Implementa `ResourceLimitService` (domain service que resolve limite vigente). Implementa `EnforceLimitUseCase` (verifica se operação excede limite, decide soft/hard-block). Integra com `ConsultaFiscalCreditDeductionListener` e `FeatureGateService`.
- **@CleanArchitecture:** Valida que `ResourceLimitService` não importa SDKs externos. Valida que `plan_default_limits` é acessada via `BillingApi` (API pública do módulo billing) e não por acesso direto ao repository do billing.
- **@AdapterDev:** Implementa repositories JPA para ambas as tabelas. Implementa endpoint REST `PUT /api/v1/admin/tenants/{tenantId}/resource-overrides`. Cria Flyway migrations com dados seed.
- **@BillingEng:** Expõe `BillingApi.getPlanDefaults(Plan)` como API pública do módulo billing. Integra teto de amplificação na validação do endpoint de override.
- **@SecurityOAuth:** Garante que endpoint de override é restrito a `ROLE_SUPER_ADMIN`. Valida que alterações de limites geram entrada no `AuditPort`.
- **@TestAutomator:** Testes: resolução de limite vigente (default puro, override parcial, override total), upgrade/downgrade reseta overrides, teto de amplificação impede override inválido, soft-limit vs hard-limit enforcement, integração com `UsageRecord` para detecção de excedente.

Operational Considerations:

> **Histórico não executável:** os caches, eventos e TTLs abaixo foram substituídos
> pela policy por classe de operação, epochs e limites absolutos do ADR-0036.

- `ResourceLimitService` é invocado em hot path (chatbot WhatsApp, cadastro de Documento). Deve usar cache local (Caffeine, TTL 60s com invalidação por evento `TenantResourceLimitsChangedEvent`).
- `plan_default_limits` é uma tabela de referência com 3 linhas — pode ser cacheada em memória no startup.
- Domain layer nunca acessa `plan_default_limits` diretamente — recebe os dados via DTO do `BillingApi`.

Safety Considerations:

- Alterações em `plan_default_limits` impactam todos os tenants de um plano. Devem ser protegidas por role `ROLE_SUPER_ADMIN` e auditadas.
- Override que excede `max_amplification` do plano é rejeitado com `BusinessException`.
- Mudança de plano (upgrade/downgrade) executa `DELETE tenant_resource_overrides` dentro da mesma transação — sem estado órfão.

---

# 9. Cancelled Historical Implementation Plan — Do Not Execute

## Phase 1 — Data Model e Domain (Sprint atual)

### Data Model — `saas_billing`

```sql
-- Flyway: V__xxx__create_plan_default_limits.sql
-- Database: saas_billing

CREATE TABLE plan_default_limits (
    plan                        VARCHAR(20) PRIMARY KEY,

    -- Limites-base de recursos (NULL = ilimitado)
    max_documentos                   INT,
    max_documentos_amplification     INT,
    max_chatbot_msg_daily       INT,
    max_serpro_query_monthly     INT,
    max_llm_tokens_monthly      INT,
    max_concurrent_sessions     INT,

    -- Política de enforcement
    overage_allowed             BOOLEAN NOT NULL DEFAULT FALSE,
    alert_threshold_pct         INT NOT NULL DEFAULT 80,

    created_at  TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at  TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Seed data (REQ-00005 §3.2, REQ-00001 BR-015, BR-016)
INSERT INTO plan_default_limits
    (plan, max_documentos, max_documentos_amplification, max_chatbot_msg_daily,
     max_serpro_query_monthly, max_llm_tokens_monthly, max_concurrent_sessions,
     overage_allowed, alert_threshold_pct)
VALUES
    ('START',    3,    10,    5,     15,   1000,   5,   FALSE, 80),
    ('BUSINESS', 50,  200,  1000,  500,  50000,  25,   TRUE,  80),
    ('PREMIUM',  NULL, NULL, 10000, NULL, NULL,   100,  TRUE,  80);
```

### Data Model — `saas_tenant`

```sql
-- Flyway: V__xxx__create_tenant_resource_overrides.sql
-- Database: saas_tenant

CREATE TABLE tenant_resource_overrides (
    tenant_id                   UUID PRIMARY KEY REFERENCES tenants(id),

    -- Campos nullable: NULL = usar default do plano vigente
    max_documentos                   INT,
    max_chatbot_msg_daily       INT,
    max_serpro_query_monthly     INT,
    max_llm_tokens_monthly      INT,
    max_concurrent_sessions     INT,

    -- Metadata de auditoria
    overridden_by               UUID,
    overridden_at               TIMESTAMP WITH TIME ZONE,
    created_at                  TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at                  TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
```

### Domain Model

```java
// shared/types/ResourceLimits.java — Value Object imutável
public record ResourceLimits(
    Integer maxCnpjs,                // null = ilimitado
    Integer maxChatbotMsgDaily,      // null = ilimitado; teto independente por canal
    Integer maxSerproQueryMonthly,   // null = ilimitado
    Integer maxLlmTokensMonthly,    // null = ilimitado
    Integer maxConcurrentSessions,   // null = ilimitado
    boolean overageAllowed,
    int alertThresholdPct
) {
    /**
     * Verifica se um recurso específico está dentro do limite.
     * @return true se dentro do limite OU se o limite é ilimitado (null)
     */
    public boolean isWithinLimit(Integer limit, long currentUsage) {
        return limit == null || currentUsage < limit;
    }

    public boolean isAlertThresholdReached(Integer limit, long currentUsage) {
        if (limit == null) return false;
        return currentUsage >= (limit * alertThresholdPct / 100);
    }
}
```

```java
// tenant/internal/domain/service/ResourceLimitService.java
@Service
@RequiredArgsConstructor
public class ResourceLimitService {

    private final TenantResourceOverrideRepository overrideRepo;
    private final BillingApi billingApi; // API pública do módulo billing

    /**
     * Resolve o limite vigente para um tenant.
     * Regra: COALESCE(override, plan_default)
     */
    public ResourceLimits resolveEffectiveLimits(TenantId tenantId, SubscriptionPlan plan) {
        PlanDefaultLimitsDTO defaults = billingApi.getPlanDefaults(plan.name());
        Optional<TenantResourceOverride> override = overrideRepo.findByTenantId(tenantId);

        return new ResourceLimits(
            coalesce(override.map(TenantResourceOverride::getMaxCnpjs), defaults.maxCnpjs()),
            coalesce(override.map(TenantResourceOverride::getMaxChatbotMsgDaily), defaults.maxChatbotMsgDaily()),
            coalesce(override.map(TenantResourceOverride::getMaxSerproQueryMonthly), defaults.maxSerproQueryMonthly()),
            coalesce(override.map(TenantResourceOverride::getMaxLlmTokensMonthly), defaults.maxLlmTokensMonthly()),
            coalesce(override.map(TenantResourceOverride::getMaxConcurrentSessions), defaults.maxConcurrentSessions()),
            defaults.overageAllowed(),
            defaults.alertThresholdPct()
        );
    }

    private Integer coalesce(Optional<Integer> override, Integer fallback) {
        return override.orElse(fallback);
    }
}
```

### Fluxo de Enforcement (Soft-Limit vs Hard-Limit)

```
┌──────────────────────────────────────────────────────────────────────┐
│                    LIMIT ENFORCEMENT FLOW                            │
│                                                                      │
│  1. Operação solicitada (ex: cadastrar Documento, enviar msg WhatsApp)   │
│              │                                                       │
│              ▼                                                       │
│  2. ResourceLimitService.resolveEffectiveLimits(tenantId, plan)     │
│     → COALESCE(override, default) → ResourceLimits VO               │
│              │                                                       │
│              ▼                                                       │
│  3. Consulta uso atual (UsageRecordRepository ou contagem local)    │
│     → currentUsage = 501 consultas SERPRO                           │
│              │                                                       │
│              ▼                                                       │
│  4. ResourceLimits.isWithinLimit(maxSerproQueryMonthly, 501)?       │
│        │                        │                                    │
│        │ SIM                    │ NÃO (excedeu)                     │
│        ▼                        ▼                                    │
│  ✅ Permite                  5. overageAllowed?                     │
│                                 │            │                       │
│                                 │ TRUE       │ FALSE                │
│                                 ▼            ▼                       │
│                          6a. SOFT-LIMIT   6b. HARD-LIMIT            │
│                          (Business/Prem.) (Start)                    │
│                          │                │                          │
│                          ▼                ▼                          │
│                    Permite +            Bloqueia com                 │
│                    Registra UsageRecord  BusinessException           │
│                    como OVERAGE          ("Limite atingido.          │
│                    → Billing inclui na    Faça upgrade.")            │
│                       próxima fatura                                 │
│                                                                      │
│  Alert check: isAlertThresholdReached(limit, 400)?                  │
│  → Se SIM (≥80%): publica TenantLimitAlertEvent                    │
│  → Módulo notification envia alerta ao Tenant Admin                 │
└──────────────────────────────────────────────────────────────────────┘
```

### Fluxo de Upgrade/Downgrade

```
┌──────────────────────────────────────────────────────────────────────┐
│                    PLAN CHANGE FLOW                                   │
│                                                                      │
│  1. Tenant Business → Premium (upgrade)                             │
│              │                                                       │
│              ▼                                                       │
│  2. Tenant.changePlan(PREMIUM) — atualiza o enum do plano           │
│              │                                                       │
│              ▼                                                       │
│  3. DELETE FROM tenant_resource_overrides WHERE tenant_id = ?        │
│     → Todos os overrides anteriores são removidos                   │
│     → Os novos defaults do Premium entram automaticamente           │
│              │                                                       │
│              ▼                                                       │
│  4. Publica SubscriptionPlanChangedEvent                            │
│     → Billing atualiza o contrato local e, se necessário, envia     │
│       comando ao provider conforme o ADR-0023                       │
│     → Módulo tenant recalcula limites na próxima request            │
│                                                                      │
│  Nota (REQ-00005 BR-003): Downgrade NÃO exclui dados existentes.   │
│  Se o tenant tinha 47 Documentos e faz downgrade para Start (max 3),    │
│  os Documentos permanecem cadastrados (dados preservados), mas novas     │
│  inserções são bloqueadas até que o número fique ≤ limite vigente.  │
└──────────────────────────────────────────────────────────────────────┘
```

Responsible agents: @DomainExpert, @ImplementerCore, @AdapterDev, @BillingEng

Dependencies: ADR-0005 (multi-tenancy), [ADR-0023](./ADR-0023-agnostic-payment-provider-integration.md) (integração de pagamentos), módulo tenant operacional, módulo billing operacional.

Rollback plan: As novas tabelas são aditivas — não alteram tabelas existentes. Se necessário reverter, os módulos voltam a validar limites por Enum hardcoded (comportamento atual). Flyway migrations são forward-only; rollback via migration reversa dedicada.

## Phase 2 — Integração com Billing e Usage Reporter (Sprint seguinte)

- Integrar `ResourceLimitService` no `ConsultaFiscalCreditDeductionListener` para decidir soft/hard-block.
- Integrar o fechamento de usage ao modelo local de fatura e emitir o comando de cobrança pela porta definida no [ADR-0023](./ADR-0023-agnostic-payment-provider-integration.md).
- Implementar endpoint `PUT /api/v1/admin/tenants/{tenantId}/resource-overrides` com validação de teto de amplificação e integração com `AuditPort`.
- Cache de `ResourceLimits` com Caffeine (TTL 60s) invalidado por `TenantResourceLimitsChangedEvent`.

## Phase 3 — Alertas e Observabilidade (Sprint posterior)

- Implementar `TenantLimitAlertEvent` publicado quando uso atinge 80% do limite (REQ-00001 BR-015).
- Dashboard admin: consumo vs. cota por tenant por recurso.

---

# 10. Historical Validation Plan — Do Not Execute

Architecture Validation:

- ArchUnit: módulo tenant domain não importa módulo billing domain diretamente — acessa via `BillingApi` (Spring Modulith public API).
- ArchUnit: `ResourceLimits` (Value Object) está em `shared.types` — acessível por todos os módulos.
- Spring Modulith `ApplicationModules.verify()` passa sem erros.

Unit Tests:

- Test: `ResourceLimitService.resolveEffectiveLimits()` retorna default do plano quando não existe override.
- Test: `ResourceLimitService.resolveEffectiveLimits()` retorna override quando existe (override parcial e total).
- Test: `ResourceLimits.isWithinLimit(null, 99999)` retorna `true` (ilimitado).
- Test: `ResourceLimits.isWithinLimit(500, 501)` retorna `false` (excedido).
- Test: `ResourceLimits.isAlertThresholdReached(1000, 800)` retorna `true` (80%).
- Test: Override com valor acima do `max_amplification` lança `BusinessException`.
- Test: Upgrade de plano remove overrides existentes.
- Test: Downgrade preserva dados existentes (Documentos cadastrados) mas bloqueia novas inserções.

Integration Tests:

- Test: Fluxo completo: criar tenant Start → cadastrar 3 Documentos (OK) → tentar 4º (bloqueio) → Admin aplica override `max_documentos=5` → cadastrar 4º (OK).
- Test: Tenant Business atinge 501ª consulta SERPRO (limite 500) → soft-limit → UsageRecord criado como OVERAGE.
- Test: Tenant Start atinge 16ª consulta SERPRO (limite 15) → hard-limit → BusinessException.
- Test: Alteração de override gera entrada no `audit_log` (ADR-0006).
- Test: `plan_default_limits` alterado → tenants sem override refletem novo valor na próxima resolução.

Performance Benchmarks:

- `ResourceLimitService.resolveEffectiveLimits()`: < 2ms (p95) com cache ativo.
- Cache miss (consulta ao banco): < 10ms.
- Endpoint de override: < 50ms.

Success Criteria:

- Todos os 5 recursos parametrizados (Documentos, mensagens de chatbot/dia por canal, SERPRO/mês, LLM tokens/mês, Sessões Simultâneas (Usuários Acesso Web)) possuem defaults persistidos e são resolvidos via `COALESCE`.
- Overrides são validados contra teto de amplificação do plano.
- Soft-limit (Business/Premium) e hard-limit (Start) funcionam conforme documentado.
- Upgrade/downgrade reseta overrides corretamente.
- Alterações de limites auditadas via `AuditPort`.

---

# 11. Risks and Mitigations

Risk 1:
Description: Cache de `ResourceLimits` fica stale — override aplicado pelo Admin não reflete imediatamente.
Mitigation: Publicar `TenantResourceLimitsChangedEvent` no UPDATE de override. O cache listener faz `evict(tenantId)`. TTL máximo de 60 segundos como safety net.

Risk 2:
Description: `plan_default_limits` alterado sem notificação — tenants sem override continuam com valor antigo em cache.
Mitigation: Alteração de `plan_default_limits` publica `PlanDefaultsChangedEvent`. Cache de defaults é invalidado globalmente. Operação rara (alteração estratégica de plano).

Risk 3:
Description: Override que excede `max_amplification` é aplicado por bug — tenant recebe limite além do contratado.
Mitigation: Validação no domain service `applyOverride()` compara `override.maxCnpjs` com `defaults.maxCnpjsAmplification`. Se exceder, lança `BusinessException("Override excede o teto de amplificação do plano")`. Testes automatizados cobrem esse cenário.

Risk 4:
Description: Downgrade de plano com dados existentes acima do novo limite gera estado "proibido" (ex: 47 Documentos cadastrados, limite Start = 3).
Mitigation: Downgrade preserva dados (REQ-00005 BR-003). Novas operações são bloqueadas. Tenant Admin recebe alerta: "Seu plano atual permite 3 Documentos. Você possui 47 cadastrados. Novas inserções bloqueadas até adequação ou upgrade."

Risk 5:
Description: Cross-module dependency: módulo tenant depende de `BillingApi` para resolver defaults.
Mitigation: `BillingApi` é uma interface pública do módulo billing com método único (`getPlanDefaults`). Se necessário, os defaults podem ser replicados via evento `PlanDefaultsChangedEvent` para cache local no módulo tenant, eliminando a dependência síncrona.

---

# 12. Related ADRs

- [ADR-0001 — Technology Stack and Architecture Foundation](./ADR-0001-technology-stack-and-architecture.md) — Java 21, Spring Boot 4.x, Spring Modulith, VPS única.
- [ADR-0002 — Multi-Tenant Database Isolation](./ADR-0002-separacao-banco-por-contexto-multitenancy.md) — Database `saas_billing` e `saas_tenant`.
- [ADR-0005 — Multi-Tenancy Architecture](./ADR-0005-multi-tenancy-architecture.md) — `tenant_id` em toda tabela, `TenantContext`, isolamento.
- [ADR-0006 — Audit and Compliance Strategy](./ADR-0006-audit-compliance.md) — `AuditPort` para auditoria de alterações de limites.
- [ADR-0007 — Multi-Provider LLM Integration](./ADR-0007-multi-provider-llm-integration.md) — LLM token quotas por tenant.
- [ADR-0023 — Integração agnóstica de provedores de pagamento](./ADR-0023-agnostic-payment-provider-integration.md) — Porta de cobrança, seleção do provider, idempotência e reconciliação.
- [ADR-0008 — Stripe Billing & Subscription Management](./ADR-0008-stripe-billing-subscription.md) — Baseline histórico substituído pelo ADR-0023.
- [ADR-0009 — Dynamic RBAC Evolution](./ADR-0009-dynamic-rbac-evolution.md) — `ROLE_SUPER_ADMIN` para gerenciamento de overrides.
- [ADR-0038 — Pricing tipado, moeda e cadência](./ADR-0038-pricing-tipado-moeda-cadencia.md) — Substitui preços/defaults implícitos por modelos allowlisted e `PriceVersion` contratual imutável.
- [ADR-0039 — Taxonomia tipada de benefícios promocionais](./ADR-0039-taxonomia-beneficios-promocionais.md) — Substitui desconto/promoção por override livre por `PromotionVersion` imutável e benefícios tipados com autoridades separadas.
- [ADR-0040 — Elegibilidade promocional e segurança de cupons](./ADR-0040-elegibilidade-promocional-seguranca-cupons.md) — Substitui filtros/settings/cupons livres por policy e facts versionados, tri-state fail-closed e verificação HMAC tenant/account-scoped.
- [ADR-0041 — Stacking e waterfall promocional determinísticos](./ADR-0041-stacking-waterfall-promocional-deterministico.md) — Substitui prioridade, stacking, best price, waterfall e alocação implícitos por policy imutável, ordem canônica e resultado pinado.
- [ADR-0042 — Capacidade e redemption promocional concorrente](./ADR-0042-capacidade-redemption-promocional-concorrente.md) — Governa reserva stateful atômica, limites, fencing, saga e recombinação bounded.
- [ADR-0043 — Governança e lifecycle promocional](./ADR-0043-governanca-lifecycle-promocional.md) — Governa publicação, pause, retire, expiry, revoke e compensação promocional.
- [ADR-0045 — Metering, rating e fechamento](./ADR-0045-metering-rating-fechamento-fatura.md) — Governa quota/admission, uso, billability, rating e fechamento tenant-local.

---

# 13. References

- Business Requirements: [Visão de produto](../product/business/product-vision.md) — Planos Start, Business, Premium e limites.
- Requirement: [REQ-00001 — WhatsApp Business Integration](../product/requirements/REQ-00001-whatsapp-business-integration.md) — BR-015, BR-016, BR-017 (rate limits, ampliação, excedentes).
- Requirement: [REQ-00005 — Plan × Feature Matrix](../product/requirements/REQ-00005-plan-feature-matrix.md) — Limites por plano, feature-gating, soft-limits.
- [ADR-0023 — Integração agnóstica de provedores de pagamento](./ADR-0023-agnostic-payment-provider-integration.md) — Referências externas e requisitos de integração de pagamentos centralizados.
- [ADR-0028 — Entitlements versionados e snapshots tenant-local](./ADR-0028-entitlements-versionados-tenant-local.md) — Restringe autoridade mutável, herança viva e fallbacks deste ADR.
- [ADR-0029 — Taxonomia tipificada de entitlements](./ADR-0029-taxonomia-tipificada-entitlements.md) — Proíbe override genérico e separa fontes comerciais, promocionais, operacionais, de risco e uso observado.
- [ADR-0030 — Composição determinística e enforcement de entitlements](./ADR-0030-composicao-deterministica-enforcement-entitlements.md) — Define tipos/operadores fechados, restrições dominantes, unlimited explícito, estados e modos sem inferência por plano.
- [ADR-0032 — Adoção versionada e grandfathering de entitlements](./ADR-0032-adocao-versionada-grandfathering-entitlements.md) — Mantém contratos pinned por default e exige versão exata, revisão e snapshot para adoção.
- [ADR-0034 — Efeitos não destrutivos de transições](./ADR-0034-efeitos-transicao-nao-destrutiva-entitlements.md) — Preserva dados/ocupação, representa dívida de capacidade e governa cutoff/operações em voo sem retroatividade.
- [ADR-0035 — Migração evidence-first de entitlements legados](./ADR-0035-migracao-evidence-first-entitlements-legados.md) — Trata enum/settings/defaults como evidência, exige manifest/backfill/shadow e elimina fallback após cutover.
- [ADR-0036 — Cache/LKG fail-safe de entitlements](./ADR-0036-cache-lkg-fail-safe-entitlements.md) — Mantém cache derivado, limita LKG positivo a indisponibilidade low-risk allowlisted e exige fail-safe em quota, financeiro, admin e risco.
- [ADR-0037 — Boundary físico e ownership de entitlements](./ADR-0037-boundary-fisico-entitlements-billing.md) — Mantém o slice em Billing e define APIs, adapters, stores, migrations, tabelas, marker, outbox, cache e tenant guard planejados.
- [ADR-0038 — Pricing tipado, moeda e cadência](./ADR-0038-pricing-tipado-moeda-cadencia.md) — Governa moeda, cadência, timing, modelos, aritmética, versionamento e simulação de preço.
- [ADR-0039 — Taxonomia tipada de benefícios promocionais](./ADR-0039-taxonomia-beneficios-promocionais.md) — Governa tipos de benefício, `PROMOTIONAL_GRANT`, funding attribution e separação de crédito/saldo.
- [ADR-0040 — Elegibilidade promocional e segurança de cupons](./ADR-0040-elegibilidade-promocional-seguranca-cupons.md) — Governa policy/facts de eligibility, tri-state, modos de cupom, HMAC, anti-enumeration, scope e placement dos snapshots aceitos.
- [ADR-0041 — Stacking e waterfall promocional determinísticos](./ADR-0041-stacking-waterfall-promocional-deterministico.md) — Governa seleção atômica, grupos de exclusividade, ordem de descontos, best price, caps stateless, alocação e hash do resultado promocional.
- [Spring Modulith — Exposed Functional API](https://docs.spring.io/spring-modulith/reference/) — Inter-module communication via public APIs.

---

# 14. Decision Lifecycle

Current State: **Accepted**

Este ADR substitui e expande a versão 1.0 anterior. Desde 2026-08-23, o ADR-0028
tem precedência sobre suas cláusulas de autoridade mutável, herança viva,
`COALESCE`, propagação retroativa e fallback; o ADR-0029 tem precedência sobre
override genérico e natureza das fontes; o ADR-0030 tem precedência sobre
composição, `NULL=UNLIMITED`, estados e enforcement; o ADR-0032 tem precedência
sobre propagação, grandfathering e reset implícitos; o ADR-0034 tem precedência
sobre efeitos destrutivos, cutoff e retroatividade; o ADR-0035 sobre migração,
backfill, shadow e cutover legado; o ADR-0036 sobre ausência/corrupção,
cache/LKG, epochs, TTLs, degraded mode e recuperação; e o ADR-0037 sobre boundary,
APIs, packages, adapters, stores, migrations, marker, outbox, cache físico e
tenant guard. As demais regras executáveis podem avançar hermeticamente sob a
liberação local-only de `D-00`. O ADR-0038 tem precedência sobre pricing/default/override implícito deste
ADR e exige `PriceVersion` allowlisted e pinada. A cobrança externa segue `D-08`
nos ADR-0023/ADR-0024 aceitos, com capabilities condicionadas às evidências
aplicáveis. O ADR-0039 tem
precedência sobre desconto, cortesia ou promoção por override genérico e exige
`PromotionVersion`/benefício tipados sem misturar preço, entitlement ou saldo.
O ADR-0040 tem precedência sobre eligibility, audience, segmento, claim, setting
ou cupom livre e exige policy/facts versionados, decisão tri-state fail-closed e
verificação opaca tenant/account-scoped. O ADR-0041 tem precedência sobre
stacking, exclusividade, best price, waterfall e caps/alocação stateless e exige
combinação pura de pacote promocional atômico. Budget, reservation/redemption e
lifecycle promocional seguem os ADR-0042 e ADR-0043 aceitos; implementação
hermética local está liberada por `D-00`, enquanto effects/rollout aguardam evidências.

---

# 15. Change Log

Version: 3.7
Date: 2026-08-25
Author: Solicitante humano, proprietário declarado / Codex (IA), materialização
Changes:
- Registra `D-00 = RELEASED_WITH_SCOPE — HUMAN_EXPLICIT — TP-00013 local-only`;
  permite backend/frontend/DDL/migrations/testes herméticos locais e mantém
  chamadas externas, Sandbox ASAAS, piloto BP Farias, produção, flags `ON` e
  efeitos reais bloqueados pelos respectivos gates.

Version: 3.6
Date: 2026-08-25
Author: Codex (IA), sob `AUTH-BILLING-2026-08-25-001`
Changes:
- Reconcilia `D-04.4-D` a `D-14` com os ADRs aceitos, registra a origem
  `AI_DELEGATED` das decisões posteriores sem alterar a proveniência humana deste
  ADR e substitui blockers decisórios obsoletos por `D-00`, artefatos e evidências.

Version: 3.5
Date: 2026-08-24
Author: Responsável pelo produto / Arquitetura
Changes:
- Registra a precedência do ADR-0041 para `D-04.4-C`: stacking/waterfall usa
  policy imutável, `PricingResult` pinado, candidatas `ELIGIBLE`, pacote
  promocional atômico, ordem/caps/alocação determinísticos e best price BRL
  pre-tax/pre-credit; preserva `D-04.4-D`, `D-04.4-E` e `D-00` como bloqueadores.

Version: 3.4
Date: 2026-08-24
Author: Responsável pelo produto / Arquitetura
Changes:
- Registra a precedência do ADR-0040 para `D-04.4-B`: eligibility promocional
  usa policy/facts versionados e tri-state fail-closed, enquanto cupom é opaco,
  HMAC-protected e tenant/account-scoped; preserva `D-04.4-C` a `D-04.4-E` e
  `D-00` como bloqueadores.

Version: 3.3
Date: 2026-08-24
Author: Responsável pelo produto / Arquitetura
Changes:
- Registra a precedência do ADR-0039 para `D-04.4-A` sobre promoção/desconto por
  override genérico; preserva `D-04.4-B` a `D-04.4-E` e `D-00` como bloqueadores.

Version: 3.2
Date: 2026-08-24
Author: Responsável pelo produto / Arquitetura
Changes:
- Registra a precedência do ADR-0038 para `D-04.3` sobre pricing, moeda,
  cadência, timing, aritmética, rounding e preço negociado; preserva valores
  concretos e rating de overage como não ratificados e `D-00` como bloqueador.

Version: 1.0
Date: 2026-04-05
Author: @RequirementAgent, @DomainExpert
Changes:
- Criação inicial do ADR com tabela única `tenant_resource_limits`.

Version: 2.0
Date: 2026-04-05
Author: @DomainExpert, @ImplementerCore
Changes:
- Reescrita completa após Análise de Aderência.
- Migração para design híbrido: `plan_default_limits` + `tenant_resource_overrides`.
- Resolução de 9 gaps identificados: semântica de ilimitado, LLM_TOKEN, teto de amplificação, upgrade/downgrade, soft/hard-limit, source of truth dos defaults, integração de usage à cobrança, auditoria ADR-0006, schema incompleto.
- Adequação ao template completo de 18 seções.

Version: 2.1
Date: 2026-08-21
Author: @AgentOrchestrator
Changes:
- Substituição da dependência vigente de Stripe pelo contrato agnóstico do ADR-0023; referências nominais preservadas somente no baseline histórico.

Version: 2.2
Date: 2026-08-21
Author: Produto / Codex
Changes:
- Generalizado `max_whatsapp_msg_daily` para `max_chatbot_msg_daily`.
- Definido enforcement diário independente por canal conversacional, preservando `channel_type` na métrica `CHATBOT_MSG`.

Version: 2.3
Date: 2026-08-23
Author: Responsável pelo produto / Arquitetura
Changes:
- Registra a precedência parcial do ADR-0028 para D-04.2-A sem reescrever o
  histórico deste ADR.
- Bloqueia como instrução executável defaults vivos, `COALESCE`, propagação
  retroativa, enum/hardcode e fallback permissivo como autoridade de entitlement.

Version: 2.4
Date: 2026-08-23
Author: Responsável pelo produto / Arquitetura
Changes:
- Registra a precedência parcial do ADR-0029 para D-04.2-B.
- Proíbe implementar override genérico para misturar add-on, promoção, exceção,
  restrição ou uso observado; `D-04.2-C` a `D-04.2-H` continuam abertas.

Version: 2.5
Date: 2026-08-23
Author: Responsável pelo produto / Arquitetura
Changes:
- Registra a precedência parcial do ADR-0030 para D-04.2-C.
- Invalida como instrução executável `NULL=UNLIMITED`, sentinelas,
  `last-write-wins`, modo inferido por plano e cobrança implícita em soft limit;
  `D-04.2-D` a `D-04.2-H` continuam abertas.

Version: 2.6
Date: 2026-08-23
Author: Responsável pelo produto / Arquitetura
Changes:
- Registra a precedência parcial do ADR-0032 para `D-04.2-D`.
- Invalida propagação automática, reset de override, `latest`, fan-out e adoção de
  default vivo; contratos ficam pinned por default e `D-04.2-E` a `D-04.2-H`
  continuam abertas.
- Rotula explicitamente as instruções, SQL, APIs, eventos e testes originais como
  histórico não executável, sem alterar o registro da decisão original.

Version: 2.7
Date: 2026-08-23
Author: Responsável pelo produto / Arquitetura
Changes:
- Registra a precedência parcial do ADR-0034 para `D-04.2-E`.
- Invalida reset/delete destrutivo, dual-snapshot grace, interrupção indiscriminada
  e efeitos financeiros retroativos; `D-04.2-F` a `D-04.2-H` continuam abertas.

Version: 2.8
Date: 2026-08-23
Author: Responsável pelo produto / Arquitetura
Changes:
- Registra a precedência parcial do ADR-0035 para `D-04.2-F`.
- Classifica enum/settings/default/seed como evidência legada, exige migração
  evidence-first tenant-local e proíbe dual-read/fallback pós-cutover; `D-04.2-G`,
  `D-04.2-H` e implementação continuam abertas.

Version: 2.9
Date: 2026-08-23
Author: Codex / @ObservabilityDev / @SecurityAgent
Changes:
- Reconciliadas as labels históricas com ADR-0012 v1.2: `tenant_id` sai de Prometheus e a
  investigação por tenant permanece no `audit_log`; dimensões restantes exigem allowlist.

Version: 3.0
Date: 2026-08-23
Author: Responsável pelo produto / Arquitetura
Changes:
- Registra a precedência do ADR-0036 para `D-04.2-G`.
- Invalida fail-open, cache/LKG genérico, TTL histórico e fallback de datasource
  como instruções do modelo-alvo; `D-04.2-H` e `D-00` continuam abertos.

Version: 3.1
Date: 2026-08-24
Author: Responsável pelo produto / Arquitetura
Changes:
- Registra a precedência do ADR-0037 para `D-04.2-H`.
- Substitui boundaries físicos históricos por slice coeso em `contexts.billing`,
  APIs públicas estreitas, adapters platform/tenant, migrations separadas,
  marker/outbox/cache derivados e tenant guard; `D-00` continua bloqueando
  implementação.

---

# 16. Repository Structure

All ADRs are stored in:

```
docs/
  adrs/
    ADR-0001-technology-stack-and-architecture.md
    ADR-0002-separacao-banco-por-contexto-multitenancy.md
    ADR-0003-multitenancy-schema-vs-tenant-id.md
    ADR-0004-whatsapp-integration-architecture.md
    ADR-0005-multi-tenancy-architecture.md
    ADR-0006-audit-compliance.md
    ADR-0007-multi-provider-llm-integration.md
    ADR-0008-stripe-billing-subscription.md
    ADR-0009-dynamic-rbac-evolution.md
    ADR-0010-tenant-plan-parametrization.md    ← THIS ADR
    ADR-0023-agnostic-payment-provider-integration.md
```

---

# 17. Review Process

1. Este ADR foi reescrito em status "Proposed" por @DomainExpert e @ImplementerCore após Análise de Aderência que identificou 9 gaps na v1.0.
2. As validações originais de duas tabelas, `COALESCE`, seeds e reset de overrides
   permanecem somente registro histórico não executável.
3. Autoridade, taxonomia, composição, adoção, efeitos, migração e failure/cache
   atuais seguem os ADR-0028, ADR-0029, ADR-0030, ADR-0032, ADR-0034, ADR-0035 e
   ADR-0036.
4. Upgrade/downgrade não reseta overrides nem apaga dados; aplica debt/policies e
   cutoff não destrutivos do ADR-0034.
5. Após aprovação, status muda para "Accepted" e o ADR torna-se imutável. Alterações exigem novo ADR ou versão incremental.

---

# 18. Historical Notes — Non-executable

> **Registro histórico:** toda esta seção preserva contratos, nomes físicos,
> representações, action codes e pseudocódigo do desenho original. Nada abaixo é
> instrução executável depois dos ADR-0028 a ADR-0036; `NULL=UNLIMITED`, tabelas,
> overrides, endpoints e códigos citados não estão aprovados para o modelo-alvo.

## Catálogo de Ações Auditáveis (Integração ADR-0006)

| Action Code | Description | Resource Type |
|---|---|---|
| `tenant:limits_override_apply` | Super Admin aplica override de limites para um tenant | TenantResourceOverride |
| `tenant:limits_override_remove` | Override removido (manual ou por mudança de plano) | TenantResourceOverride |
| `billing:plan_defaults_update` | Product Owner altera defaults de um plano | PlanDefaultLimits |

## Representação de "Ilimitado"

| Contexto | Representação | Exemplo |
|---|---|---|
| **Banco de dados** | `NULL` | `max_documentos = NULL` (Premium) |
| **Java (VO)** | `Integer null` | `ResourceLimits.maxCnpjs() == null` |
| **Verificação** | `limit == null → permitido` | `isWithinLimit(null, 99999) → true` |
| **Frontend (UI)** | Texto "Ilimitado" | Quando API retorna `maxCnpjs: null` |
| **Provider de pagamento** | Sem cobrança de excedente | Premium não gera comando externo de cobrança para `Documento_EXTRA` |

## Mapeamento MetricType ↔ Coluna de Limite

| `MetricType` (billing) | Coluna em `plan_default_limits` | Coluna em `tenant_resource_overrides` |
|---|---|---|
| `Documento_EXTRA` | `max_documentos` | `max_documentos` |
| `CHATBOT_MSG` | `max_chatbot_msg_daily` | `max_chatbot_msg_daily` |
| `SERPRO_QUERY` | `max_serpro_query_monthly` | `max_serpro_query_monthly` |
| `LLM_TOKEN` | `max_llm_tokens_monthly` | `max_llm_tokens_monthly` |
| — (não é MetricType) | `max_concurrent_sessions` | `max_concurrent_sessions` | *(Controla logins ativos e limite de convites de usuários)*

`max_chatbot_msg_daily` é um default do plano aplicado separadamente a cada
`channel_type`. A leitura de consumo usa a chave
`tenant_id + channel_type + billing_day`; somar canais é permitido para reporting e
fatura, mas não para bloquear a franquia diária de outro canal.

## Regra de Teto de Amplificação

```java
// Validação no endpoint de override
public void validateAmplification(SubscriptionPlan plan, Integer requestedMaxCnpjs) {
    PlanDefaultLimitsDTO defaults = billingApi.getPlanDefaults(plan.name());

    if (defaults.maxCnpjsAmplification() != null && requestedMaxCnpjs != null) {
        if (requestedMaxCnpjs > defaults.maxCnpjsAmplification()) {
            throw new BusinessException(
                "Override de Documentos (%d) excede o teto de amplificação do plano %s (%d)"
                    .formatted(requestedMaxCnpjs, plan, defaults.maxCnpjsAmplification())
            );
        }
    }
}
```
