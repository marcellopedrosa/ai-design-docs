---
document_id: "ADR-0008"
primary_nature: "Decisao"
objective: "Registrar a decisão arquitetural “Stripe Billing & Subscription Management Architecture”, seus motivadores, alternativas e consequências."
scope: "Decisão, componentes, integrações e limites explicitamente descritos em “Stripe Billing & Subscription Management Architecture”."
non_objectives: "Não implementar a decisão, substituir requisitos relacionados nem atestar capabilities ou ambientes sem evidência explícita."
owner: "@ImplementerCore, @AgentOrchestrator"
status: "Superseded"
date: "2026-03-11"
version: "1.2"
keywords: "adr, decisao, arquitetura, stripe, billing, subscription, management, architecture"
related_files: "README.md, ADR-0023-agnostic-payment-provider-integration.md, ADR-0001-technology-stack-and-architecture.md, ADR-0002-separacao-banco-por-contexto-multitenancy.md, ADR-0004-whatsapp-integration-architecture.md, ADR-0005-multi-tenancy-architecture.md, ADR-0007-multi-provider-llm-integration.md"
code_references: "PaymentGatewayPort, StripePaymentAdapter, SubscriptionActivatedEvent, SubscriptionSuspendedEvent, PaymentReceivedEvent, BillingService, StripeWebhookController, BillingEvent, SubscriptionCanceledEvent, PlanChangedEvent, PaymentFailedEvent"
principal_statement: "A gestão de assinaturas, faturamento recorrente e cobrança de excedentes será implementada via integração com **Stripe Billing** usando o modelo de **Stripe Subscriptions + Usage-Based Billing**. A integração seguirá Clean Architecture com um outbound port (`PaymentGatewayPort`) no módulo Billing, e um adapter (`StripePaymentAdapter`) na camada de infraestrutura. Webhooks da Stripe serão usados para manter o estado da assinatura sincronizado. Pix e Boleto Bancário serão configurados como métodos de pagamento via Stripe."
---

# ADR-0008 - Stripe Billing & Subscription Management Architecture

- Date: 2026-03-11
- Status: Superseded
- Version: 1.2
- Authors / Owners: @ImplementerCore, @AgentOrchestrator
- Reviewers: @CleanArchitecture, @DomainExpert, @SecurityOAuth, @AdapterDev
- Stakeholders: Engineering Team, Product Owner, Startup Founders
- Superseded by: [ADR-0023 - Integração agnóstica de provedores de pagamento](ADR-0023-agnostic-payment-provider-integration.md)

---

# 1. Context

> **Historical decision:** este ADR registra a seleção original da Stripe. A
> arquitetura vigente, o provider primário e a política de contingência são
> definidos pelo [ADR-0023](ADR-0023-agnostic-payment-provider-integration.md).
> Referências Stripe abaixo descrevem a decisão e o baseline legados.

O Contador Fiscal Inteligente opera como um micro-SaaS com modelo de receita baseado em **assinatura mensal recorrente**. Os escritórios de contabilidade (tenants) escolhem um plano (Start, Business ou Premium) e pagam mensalmente para utilizar a plataforma.

Contexto do problema:

- Cada tenant precisa de um mecanismo para **assinar um plano, pagar mensalmente, e gerenciar sua assinatura** (upgrade, downgrade, cancelamento).
- O modelo de negócio não é apenas "valor fixo mensal" — o plano Business inclui **cobrança de excedentes** (consultas fiscais além da cota inclusa) e possibilidade de **ampliação de limites** (Documentos adicionais) com cobrança proporcional (REQ-00001 BR-016, BR-017).
- O custo operacional do SaaS envolve: infraestrutura (VPS), **tokens LLM** (Gemini — rastreados via `llm_usage_log`, ADR-0007), **mensagens WhatsApp** (custo por conversa da Meta, variável por tier), e **consultas SERPRO** (custo por consulta).
- O sistema precisa de **faturas automáticas**, **notificação de inadimplência**, **suspensão por falta de pagamento**, e **reativação após regularização**.
- A plataforma opera no Brasil com tenants brasileiros — Pix e Boleto Bancário são métodos de pagamento essenciais, além de cartão de crédito.
- Na fase inicial (VPS única, ADR-0001), o sistema de pagamento não pode exigir infraestrutura adicional complexa.

Restrições:

- Infraestrutura em VPS única com Docker Compose (ADR-0001).
- Multi-tenancy: cada tenant tem seu próprio plano e ciclo de faturamento (ADR-0005).
- Clean Architecture: o gateway de pagamento é um detalhe de infraestrutura — o domínio não pode depender de SDKs de provedores (Stripe, PagSeguro, etc.).
- LGPD: dados de pagamento (cartão, dados bancários) não devem ser armazenados pelo sistema — devem ficar no provedor de pagamento.
- O Super Admin Global gerencia planos e faturamento (REQ-00003). O Tenant Admin visualiza faturas e gerencia método de pagamento.

---

# 2. Decision Statement

A gestão de assinaturas, faturamento recorrente e cobrança de excedentes será implementada via integração com **Stripe Billing** usando o modelo de **Stripe Subscriptions + Usage-Based Billing**. A integração seguirá Clean Architecture com um outbound port (`PaymentGatewayPort`) no módulo Billing, e um adapter (`StripePaymentAdapter`) na camada de infraestrutura. Webhooks da Stripe serão usados para manter o estado da assinatura sincronizado. Pix e Boleto Bancário serão configurados como métodos de pagamento via Stripe.

---

# 3. Decision Drivers

- **Clean Architecture:** O gateway de pagamento é um detalhe de infraestrutura. O domínio (planos, assinaturas, faturamento) deve depender de uma interface (`PaymentGatewayPort`), não do SDK da Stripe.
- **Métodos de pagamento brasileiros:** Pix e Boleto Bancário são essenciais para o público-alvo (escritórios de contabilidade no Brasil). Stripe suporta ambos nativamente no Brasil.
- **Billing complexo:** Não é apenas "valor fixo mensal". O plano Business tem excedentes por consulta, e todos os planos podem ter ampliação de limites (Documentos adicionais). Stripe Billing suporta usage-based billing integrado com assinaturas.
- **Segurança e PCI Compliance:** Stripe é PCI DSS Level 1. Dados de cartão nunca transitam pelo nosso sistema — são tokenizados no frontend (Stripe.js/Elements).
- **Webhooks:** O modelo event-driven da Stripe se encaixa no padrão de eventos do Spring Modulith. Eventos como `invoice.paid`, `customer.subscription.updated` mantêm o estado do tenant sincronizado.
- **Resiliência:** Se a Stripe falhar momentaneamente, o tenant não perde acesso imediato — o sistema usa o estado local da assinatura com reconciliação assíncrona.
- **Zero infraestrutura adicional:** Stripe é SaaS externo — sem containers adicionais na VPS.
- **Observabilidade de custos:** O `llm_usage_log` (ADR-0007) e os contadores de consultas SERPRO alimentam o usage-based billing da Stripe.

---

# 4. Considered Options

## Option 1: Stripe Billing com Subscriptions + Usage Records (Selecionada)

Description: Usar Stripe Billing para gerenciar assinaturas com planos fixos + usage-based pricing para excedentes. Stripe Checkout para coleta de pagamento. Webhooks para sincronização de estado.

Pros:
- PCI Compliance built-in (dados de cartão nunca no nosso servidor)
- Pix e Boleto Bancário suportados nativamente no Brasil
- Usage-based billing permite cobrança de excedentes sem lógica de billing customizada
- Customer Portal da Stripe para self-service (trocar cartão, ver faturas, cancelar)
- Smart Retries e Revenue Recovery nativos para inadimplência
- Webhooks robustos para manter estado sincronizado
- Free tier disponível (0% até o volume de receita certa)

Cons:
- Taxa por transação: 3.99% + R$0.39 (cartão BR), 3.99% (Pix), variável para Boleto
- Vendor lock-in ao ecossistema Stripe (mitigado por port/adapter)
- Complexidade de integração com usage-based billing para excedentes
- Fatura da Stripe em inglês por padrão (customizável)

## Option 2: Integração Direta com Gateway Nacional (PagSeguro/Asaas)

Description: Usar PagSeguro, Asaas ou outro gateway brasileiro para cobranças recorrentes via API direta.

Pros:
- Foco no mercado brasileiro
- Pix e Boleto com menor taxa em alguns casos
- Suporte em português

Cons:
- **Sem billing engine nativo** — lógica de assinatura, retry, dunning seria construída manualmente
- Sem usage-based billing — excedentes teriam que ser calculados e cobrados por fatura customizada
- APIs menos maduras e documentação inferior
- Sem Customer Portal built-in
- Menor ecossistema de ferramentas e dashboards

## Option 3: Billing Engine Próprio + Gateway Genérico

Description: Construir motor de billing internamente (cálculo de faturas, proration, dunning) e integrar com qualquer gateway para cobrança.

Pros:
- Controle total
- Zero dependência externa para lógica de billing
- Sem taxa de billing (apenas taxa do gateway)

Cons:
- **Enorme complexidade** — billing engine é um produto por si só
- Meses de desenvolvimento para atingir paridade com Stripe Billing
- Bugs de billing são bugs de receita — risco altíssimo para uma startup
- Distração do core business (automação fiscal, não billing)
- Violaria o princípio de "fase de startup, focar no produto core" (ADR-0001)

---

# 5. Decision Outcome

**Option 1 (Stripe Billing com Subscriptions + Usage Records)** foi selecionada.

Fatores-chave:

- **Consistência arquitetural:** Assim como LLM (ADR-0007) e WhatsApp (ADR-0004), o payment gateway é um detalhe de infraestrutura acessado via port/adapter. O domínio não importa SDK da Stripe.
- **Billing-as-a-Service:** A Stripe resolve billing, dunning, retry, proration, receipts e customer portal — funcionalidades que levariam meses para construir. A startup foca no core (automação fiscal).
- **Usage-based billing nativo:** Os excedentes do plano Business (consultas fiscais + consultas LLM além da cota) são reportados à Stripe via Usage Records e cobrados automaticamente na próxima fatura. Sem lógica de billing customizada no código.
- **Pix e Boleto:** Essenciais para o mercado-alvo brasileiro. Stripe suporta ambos como métodos de pagamento no Checkout e em faturas.
- **Segurança financeira:** Dados de cartão nunca transitam pelo backend. O frontend usa Stripe.js para tokenização. PCI Compliance sem esforço.

Tradeoffs aceitos:

- Taxas da Stripe (3.99% + R$0.39 por cartão). Aceitável — inferior ao custo de construir e manter um billing engine. Stripe conecta Pix (3,99%) e Boleto.
- Vendor lock-in à Stripe. Aceitável — mitigado pelo port/adapter. Trocar para outro gateway exige apenas novo adapter, sem alterar domínio.
- Faturas da Stripe. Customizáveis via API e dashboard para português.

---

# 6. Consequences

Positive Consequences:

- Cobrança recorrente automatizada para todos os planos (Start, Business, Premium).
- Excedentes cobrados automaticamente via usage-based billing (sem lógica de faturamento manual).
- Pix e Boleto Bancário disponíveis como métodos de pagamento desde o Day 1.
- Customer Portal: o tenant gerencia método de pagamento e visualiza faturas sem suporte humano.
- Smart Retries e Revenue Recovery: redução de involuntary churn.
- Suspensão automática por inadimplência com reativação após pagamento.

Negative Consequences:

- Dependência da taxa da Stripe (3.99% + R$0.39 por transação em cartão).
- Novas tabelas no banco para sincronizar estado Stripe ↔ sistema.
- Complexidade de webhooks: ordenação de eventos, idempotência, retry handling.

Neutral Consequences:

- Novo módulo Spring Modulith: `billing`.
- Novos endpoints para gerenciamento de assinatura.
- Stripe dashboard como ferramenta complementar de monitoramento financeiro.

---

# 7. Impact

- **Architecture:** Novo módulo Spring Modulith `billing` com outbound port `PaymentGatewayPort` e adapter `StripePaymentAdapter`. Novas entidades de domínio: `Subscription`, `Invoice`, `PaymentMethod`, `UsageRecord`. Novos eventos: `SubscriptionActivatedEvent`, `SubscriptionSuspendedEvent`, `PaymentReceivedEvent`.
- **Infrastructure:** Sem containers adicionais. Stripe é SaaS externo. Webhook endpoint exposto via Caddy (HTTPS). Stripe API Keys em variável de ambiente ou Vault.
- **Security:** Dados de cartão tokenizados via Stripe.js no frontend — nunca transitam pelo backend. Webhook validado via Stripe Signature (HMAC SHA-256). API Keys criptografadas em repouso (AES-256). RBAC: endpoints de billing exigem `ROLE_TENANT_ADMIN` ou `ROLE_SUPER_ADMIN` conforme REQ-00004.
- **Development Process:** Adapter para novo gateway requer apenas implementação de `PaymentGatewayPort` (uma classe).
- **Data Architecture:** 3 novas tabelas: `subscriptions` (estado da assinatura por tenant), `invoices` (histórico de faturas), `usage_records` (contadores de uso para excedentes). Todas com `tenant_id`.
- **Observability:** Métricas históricas: `billing_subscription_status_total`, `billing_payment_received_total`, `billing_payment_failed_total`, `billing_usage_reported_total`, `billing_mrr_total`. ADR-0012 v1.2 substitui apenas o contrato de labels: não há `tenant_id`; `plan=START|BUSINESS|PREMIUM` e `payment_method=CARD|PIX|BOLETO` são as dimensões fechadas. Reconciliação por tenant permanece no ledger financeiro protegido.
- **Cost Management:** Usage records alimentados por: `llm_usage_log` (ADR-0007) + contadores de consultas SERPRO + contadores de mensagens WhatsApp.

---

# 8. AI Agent Considerations (For Autonomous Agent Environments)

Agent Roles Impacted:

- **@DomainExpert:** Modela `Subscription`, `Invoice`, `UsageRecord` como entidades do bounded context Billing. Define regras de suspensão e reativação como lógica de domínio.
- **@CleanArchitecture:** Define `PaymentGatewayPort` (outbound port) e valida que o domínio não importa SDKs da Stripe. Valida isolamento via ArchUnit.
- **@ImplementerCore:** Implementa `BillingService` (orquestra criação de assinatura, reportar uso, tratar webhooks). Integra com módulo Tenant para sincronizar plano ↔ assinatura.
- **@AdapterDev:** Implementa `StripePaymentAdapter` (adapter para Stripe Billing API). Implementa `StripeWebhookController` (recebe eventos da Stripe).
- **@SecurityOAuth:** Valida Stripe webhook signatures (HMAC SHA-256 com WebhookSecret). Garante que dados de cartão nunca transitam pelo backend.
- **@FrontendWeb:** Integra Stripe.js/Elements para coleta de pagamento. Implementa telas de gerenciamento de assinatura e faturas no painel do tenant.
- **@TestAutomator:** Testes com Stripe CLI (stripe listen) para simular webhooks localmente. Mock de `PaymentGatewayPort` para testes unitários.

Operational Considerations:

- Stripe API Keys (publishable + secret) armazenadas em variáveis de ambiente.
- Webhook endpoint deve ser idempotente — Stripe reenvia eventos em caso de falha.
- Rate limiting na API da Stripe: 100 req/s (read), 25 req/s (write). Suficiente para a escala atual.

Safety Considerations:

- Dados de cartão de crédito **nunca** transitam pelo backend — tokenização via Stripe.js.
- Webhooks validados via Stripe Signature antes de qualquer processamento.
- Suspensão de tenant: acesso ao chatbot é mantido por um grace period (3 dias) após inadimplência, com mensagens de aviso.

---

# 9. Implementation Plan

## Phase 1 — Assinatura Básica com Stripe Checkout (Sprint 4)

### Stripe Object Model

```
┌─────────────────────────────────────────────────────────────────┐
│                    STRIPE (Cloud)                                │
│                                                                  │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐       │
│  │   Product     │    │    Price     │    │   Customer   │       │
│  │              │    │              │    │              │       │
│  │  "Hub Start" │────│  R$X/mês     │    │  Tenant A    │       │
│  │  "Hub Biz"   │────│  R$Y/mês     │────│  Tenant B    │       │
│  │  "Hub Premium│────│  R$Z/mês     │    │  Tenant C    │       │
│  └──────────────┘    │  +R$W/query  │    └──────┬───────┘       │
│                      │   (metered)  │           │               │
│                      └──────────────┘    ┌──────▼───────┐       │
│                                          │ Subscription │       │
│                                          │              │       │
│                                          │ status:active│       │
│                                          │ plan: Biz    │       │
│                                          └──────┬───────┘       │
│                                                 │               │
│                                          ┌──────▼───────┐       │
│                                          │   Invoice     │       │
│                                          │              │       │
│                                          │  R$Y + R$Wn  │       │
│                                          │  (fixo+uso)  │       │
│                                          └──────────────┘       │
└─────────────────────────────────────────────────────────────────┘
```

### Fluxo de Assinatura

```
1.  Tenant Admin clica "Assinar Plano Business"
2.  Frontend cria Stripe Checkout Session via backend
       POST /api/v1/tenant/billing/checkout
       → StripePaymentAdapter.createCheckoutSession(plan, tenantId)
       → Stripe retorna checkout_session.url
3.  Tenant é redirecionado ao Stripe Checkout
       Seleciona método: Cartão / Pix / Boleto
4.  Pagamento confirmado
       Stripe envia webhook: checkout.session.completed
       → StripeWebhookController recebe
       → BillingService.handleCheckoutCompleted()
       → Cria Subscription no banco local
       → Publica SubscriptionActivatedEvent
       → Módulo Tenant atualiza plano do escritório
5.  Todo mês: Stripe gera fatura automática
       Stripe envia webhook: invoice.paid
       → BillingService.handleInvoicePaid()
       → Atualiza Invoice no banco local
6.  Se pagamento falhar:
       Stripe envia: invoice.payment_failed
       → BillingService.handlePaymentFailed()
       → Alerta ao Tenant Admin
       → Após grace period (3 dias): suspensão
       → Publica SubscriptionSuspendedEvent
       → Módulo Tenant desativa recursos premium
```

### Data Model

```sql
-- Database: saas_billing

-- Estado da assinatura do tenant (sincronizado com Stripe)
CREATE TABLE subscriptions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL UNIQUE,
    stripe_customer_id VARCHAR(100) NOT NULL,        -- cus_xxx
    stripe_subscription_id VARCHAR(100) UNIQUE,      -- sub_xxx
    plan VARCHAR(20) NOT NULL,                       -- START, BUSINESS, PREMIUM
    status VARCHAR(30) NOT NULL DEFAULT 'INCOMPLETE', -- ACTIVE, PAST_DUE, SUSPENDED, CANCELED, TRIALING
    payment_method_type VARCHAR(20),                 -- CARD, PIX, BOLETO
    current_period_start TIMESTAMP WITH TIME ZONE,
    current_period_end TIMESTAMP WITH TIME ZONE,
    cancel_at_period_end BOOLEAN DEFAULT FALSE,
    suspended_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
CREATE INDEX idx_sub_tenant ON subscriptions(tenant_id);
CREATE INDEX idx_sub_stripe_cust ON subscriptions(stripe_customer_id);
CREATE INDEX idx_sub_status ON subscriptions(status);

-- Histórico de faturas (sincronizado com Stripe)
CREATE TABLE invoices (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL,
    stripe_invoice_id VARCHAR(100) NOT NULL UNIQUE,  -- in_xxx
    stripe_invoice_url VARCHAR(500),                 -- URL da fatura hospedada na Stripe
    stripe_pdf_url VARCHAR(500),                     -- URL do PDF da fatura
    amount_due_cents INT NOT NULL,                   -- valor em centavos (BRL)
    amount_paid_cents INT,
    currency VARCHAR(3) DEFAULT 'brl',
    status VARCHAR(20) NOT NULL,                     -- DRAFT, OPEN, PAID, VOID, UNCOLLECTIBLE
    period_start TIMESTAMP WITH TIME ZONE,
    period_end TIMESTAMP WITH TIME ZONE,
    paid_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
CREATE INDEX idx_inv_tenant ON invoices(tenant_id);
CREATE INDEX idx_inv_status ON invoices(status);

-- Registros de uso para billing de excedentes
CREATE TABLE usage_records (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL,
    metric_type VARCHAR(30) NOT NULL,    -- SERPRO_QUERY, LLM_TOKEN, WHATSAPP_MSG, Documento_EXTRA
    quantity INT NOT NULL,
    period_start TIMESTAMP WITH TIME ZONE NOT NULL,
    period_end TIMESTAMP WITH TIME ZONE NOT NULL,
    reported_to_stripe BOOLEAN DEFAULT FALSE,
    stripe_usage_record_id VARCHAR(100),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
CREATE INDEX idx_usage_tenant ON usage_records(tenant_id);
CREATE INDEX idx_usage_metric ON usage_records(metric_type);
CREATE INDEX idx_usage_reported ON usage_records(reported_to_stripe);
```

### Stripe Products e Prices (Configuração)

```
Products:
  - Hub Start       → Price: R$X/mês (flat)
  - Hub Business    → Price: R$Y/mês (flat) + R$W/consulta excedente (metered)
  - Hub Premium     → Price: R$Z/mês (flat)
  - Documento Adicional  → Price: R$A/Documento/mês (per-unit, add-on)
```

### Implementation Tasks

1. **Domain Model:** `Subscription` (entity), `Invoice` (entity), `UsageRecord` (entity), `Plan` (enum: START, BUSINESS, PREMIUM), `SubscriptionStatus` (enum), `BillingEvent` (value object).

2. **Outbound Port:** `PaymentGatewayPort` (interface):
   - `CheckoutSession createCheckoutSession(TenantId, Plan, SuccessUrl, CancelUrl)`
   - `void reportUsage(TenantId, MetricType, quantity)`
   - `CustomerPortalSession createPortalSession(TenantId, ReturnUrl)`
   - `void cancelSubscription(SubscriptionId, atPeriodEnd)`

3. **Primary Adapter:** `StripePaymentAdapter` implements `PaymentGatewayPort`. Usa Stripe Java SDK (`com.stripe:stripe-java`). Comunica com Stripe Billing API.

4. **Webhook Controller:** `StripeWebhookController` — valida Stripe Signature, parseia eventos, delega ao `BillingService`. Eventos tratados: `checkout.session.completed`, `invoice.paid`, `invoice.payment_failed`, `customer.subscription.updated`, `customer.subscription.deleted`.

5. **Domain Service:** `BillingService` — orquestra criação de assinatura, tratamento de webhooks, suspensão por inadimplência, e reportar usage records.

6. **Usage Reporter:** Job agendado (Spring `@Scheduled`) que agrega contadores de uso (consultas SERPRO, tokens LLM, mensagens WhatsApp) de cada tenant e reporta à Stripe via Usage Records API. Execução: a cada 1 hora.

7. **Events:** `SubscriptionActivatedEvent`, `SubscriptionSuspendedEvent`, `SubscriptionCanceledEvent`, `PlanChangedEvent`, `PaymentReceivedEvent`, `PaymentFailedEvent`. Consumidos pelo módulo Tenant para atualizar plano e limites.

8. **Flyway Migrations:** Tabelas `subscriptions`, `invoices`, `usage_records`. Database: `saas_billing` (conforme ADR-0002).

9. **Frontend:** Stripe.js para Checkout. Tela de faturas no painel do tenant. Link para Stripe Customer Portal.

Responsible agents: @DomainExpert, @ImplementerCore, @AdapterDev, @SecurityOAuth, @FrontendWeb, @TestAutomator

Dependencies: ADR-0005 (multi-tenancy), módulo Tenant operacional. Stripe account ativo com Pix e Boleto habilitados.

Rollback plan: Se a Stripe falhar, o sistema mantém o estado local da assinatura. O tenant não perde acesso imediato. O Super Admin pode gerenciar planos manualmente via painel enquanto a integração é restaurada.

## Phase 2 — Usage-Based Billing + Excedentes (Sprint 6)

- Implementar job de agregação de uso (SERPRO queries, LLM tokens, WhatsApp msgs)
- Reportar usage records à Stripe via `UsageRecord` API
- Cobrança automática de excedentes na fatura mensal do plano Business
- Dashboard do tenant: consumo vs. cota do plano

## Phase 3 — Customer Portal + Self-Service (Sprint 7+)

- Integrar Stripe Customer Portal (troca de cartão, cancelar, ver faturas)
- Upgrade/downgrade de plano via painel do tenant (proration automática via Stripe)
- Notificações de inadimplência via email e WhatsApp (reuso do módulo WhatsApp)
- Trial period para plano Start (14 dias sem cartão, via Stripe Trials)

---

# 10. Validation

Architecture Validation:

- ArchUnit: módulo Billing domain não importa SDK da Stripe (`com.stripe`).
- ArchUnit: `PaymentGatewayPort` é interface no package `..application.port.out..`.
- Spring Modulith `ApplicationModules.verify()` passa sem erros.

Unit Tests:

- Test: `BillingService` cria checkout session via mock de `PaymentGatewayPort`.
- Test: Webhook `invoice.paid` atualiza status da assinatura para ACTIVE.
- Test: Webhook `invoice.payment_failed` suspende tenant após grace period.
- Test: Usage Reporter agrega contadores corretamente.
- Test: Proration calculada corretamente para upgrade Business→Premium.

Integration Tests:

- Test: Stripe Checkout Session criada com sucesso (Stripe Test Mode).
- Test: Webhook com signature válida é processado. Signature inválida → rejeição.
- Test: Fluxo completo: checkout → payment → subscription active → tenant plan updated.
- Test: Cancelamento ao final do período (`cancel_at_period_end=true`).

Performance Benchmarks:

- Webhook processing: < 2 segundos por evento.
- Usage reporter job: < 30 segundos para 100 tenants.

Success Criteria:

- Tenants conseguem assinar plano via Stripe Checkout com Pix, Boleto ou Cartão.
- Faturas mensais geradas automaticamente pela Stripe.
- Excedentes cobrados automaticamente no plano Business.
- Inadimplência → grace period → suspensão → reativação automática após pagamento.
- Super Admin visualiza MRR e status de todas assinaturas.

---

# 11. Risks and Mitigations

Risk 1:
Description: Stripe indisponível — tenant não consegue assinar ou pagar.
Mitigation: O sistema mantém estado local da assinatura. O Super Admin pode ativar plano manualmente. Stripe tem SLA de 99.99% uptime. Circuit breaker (Resilience4j) na chamada à API Stripe.

Risk 2:
Description: Webhooks perdidos — estado do tenant fica dessincronizado com Stripe.
Mitigation: Reconciliação periódica: job diário compara estado local com Stripe API (`Subscription.retrieve()`). Stripe retenta webhooks por até 72h. Log de todos os eventos webhooks recebidos para audit trail.

Risk 3:
Description: Taxas da Stripe impactam margem — especialmente para plano Start (menor ticket).
Mitigation: Monitorar unit economics por plano. Se Start tiver margem negativa, considerar: (a) aumentar preço, (b) limitar trial, (c) exigir plano Business como mínimo pago. Pix (3.99%) pode ter taxa menor que cartão (3.99% + R$0.39).

Risk 4:
Description: Excedentes mal calculados geram cobranças incorretas — reclamação de clientes.
Mitigation: Dashboard de uso visível ao tenant (transparência). Contadores no banco com audit trail. Reconciliação de usage records vs. llm_usage_log e contadores SERPRO. Preview de fatura antes do fechamento.

Risk 5:
Description: Tenant tenta burlar limites do plano criando múltiplas contas.
Mitigation: Validação de Documento do escritório (Documento obrigatório no cadastro). Documento unique constraint. Monitoramento de padrões anômalos pelo Super Admin.

---

# 12. Related ADRs

- [ADR-0001 — Technology Stack and Architecture Foundation](ADR-0001-technology-stack-and-architecture.md) — Java 21, Spring Boot 4.x, Spring Modulith, VPS única.
- [ADR-0002 — Multi-Tenant Database Isolation](ADR-0002-separacao-banco-por-contexto-multitenancy.md) — Database `saas_billing` para o módulo Billing.
- [ADR-0004 — WhatsApp Integration Architecture](ADR-0004-whatsapp-integration-architecture.md) — Contadores de mensagens WhatsApp alimentam usage-based billing.
- [ADR-0005 — Multi-Tenancy Architecture](ADR-0005-multi-tenancy-architecture.md) — Keycloak, plano do tenant, realm isolation.
- [ADR-0007 — Multi-Provider LLM Integration](ADR-0007-multi-provider-llm-integration.md) — `llm_usage_log` alimenta usage-based billing para tokens LLM.

---

# 13. References

- [Stripe Billing — Subscriptions](https://docs.stripe.com/billing/subscriptions/overview)
- [Stripe Checkout — Quickstart](https://docs.stripe.com/checkout/quickstart)
- [Stripe Usage-Based Billing](https://docs.stripe.com/billing/subscriptions/usage-based)
- [Stripe Webhooks — Best Practices](https://docs.stripe.com/webhooks/best-practices)
- [Stripe Customer Portal](https://docs.stripe.com/customer-management)
- [Stripe — Pix Payments (Brazil)](https://docs.stripe.com/payments/pix)
- [Stripe — Boleto Bancário (Brazil)](https://docs.stripe.com/payments/boleto)
- [Stripe Java SDK](https://github.com/stripe/stripe-java)
- [Stripe CLI — Local Webhook Testing](https://docs.stripe.com/stripe-cli)
- Business Requirements: [Visão de produto](../product/business/product-vision.md)
- Requirement: [REQ-00005 — Plan × Feature Matrix](../product/requirements/REQ-00005-plan-feature-matrix.md)

---

# 14. Decision Lifecycle

Current State: **Superseded**

Este ADR foi substituído pelo
[ADR-0023](ADR-0023-agnostic-payment-provider-integration.md), que mantém o Billing
independente do fornecedor, define ASAAS como provider primário e Stripe como
contingência controlada.

---

# 15. Change Log

| Version | Date | Changes |
| --- | --- | --- |
| 1.0 | 2026-03-11 | Decisão original de billing e assinatura via Stripe Billing. |
| 1.1 | 2026-08-21 | Marcado como superseded pelo ADR-0023; conteúdo preservado como registro histórico do baseline Stripe. |
| 1.2 | 2026-08-23 | Reconciliado o contrato histórico de labels com ADR-0012 v1.2: tenant deixa Prometheus; plano/método usam allowlists e o ledger financeiro preserva investigação tenant-scoped. |

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
    ADR-0008-stripe-billing-subscription.md    ← NEW
```

---

# 17. Review Process

1. Este ADR foi criado em status "Proposed" por @ImplementerCore e @AgentOrchestrator.
2. Reviewers (@CleanArchitecture, @DomainExpert, @SecurityOAuth, @AdapterDev) devem validar: isolamento de infraestrutura de pagamento, segurança PCI, padrão de webhooks, e modelo de usage-based billing.
3. Os fundadores da startup devem confirmar: escolha da Stripe como gateway, modelo de pricing dos planos (valores em BRL), e estratégia de cobrança de excedentes.
4. Após aprovação, status muda para "Accepted" e o ADR torna-se imutável.

---

# 18. Notes

Este ADR define a **integração de billing** como um módulo Spring Modulith independente (`billing`). O billing **não faz parte** do módulo WhatsApp nem do módulo Tenant — ele é um bounded context próprio que se comunica via eventos Spring Modulith.

Pontos-chave:

- **Stripe é o billing engine, não nós.** Não construímos lógica de cálculo de faturas, proration, dunning ou retry. A Stripe resolve tudo isso. Nosso sistema sincroniza estado e reporta uso.
- **Dados de cartão nunca no nosso servidor.** Stripe.js tokeniza no frontend. O backend recebe apenas IDs tokenizados. Zero responsabilidade PCI.
- **Pix e Boleto são first-class citizens.** No Brasil, escritórios de contabilidade frequentemente preferem boleto para dedução fiscal. Pix é a opção instantânea. Ambos suportados desde o Day 1.
- **Usage records fecham o ciclo de negócio.** Os contadores de `llm_usage_log` (ADR-0007), consultas SERPRO, e mensagens WhatsApp alimentam a Stripe para cobrança automática de excedentes. Sem planilha manual.
- **Evolução gradual.** Phase 1: assinatura simples (checkout + webhook). Phase 2: excedentes via usage records. Phase 3: self-service completo com Customer Portal.

Fluxo de receita simplificado:

```
Tenant assina → Stripe cobra mensal → Webhook confirma → Sistema ativa plano
                                    ↓
            Uso do mês (SERPRO + LLM + WhatsApp)
                                    ↓
         Usage Reporter → Stripe Usage Records → Fatura com excedentes
```
