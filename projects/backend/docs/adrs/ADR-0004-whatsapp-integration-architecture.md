---
document_id: "ADR-0004"
primary_nature: "Decisao"
objective: "Registrar a decisão arquitetural “WhatsApp Integration Architecture”, seus motivadores, alternativas e consequências."
scope: "Decisão, componentes, integrações e limites explicitamente descritos em “WhatsApp Integration Architecture”."
non_objectives: "Não implementar a decisão, substituir requisitos relacionados nem atestar capabilities ou ambientes sem evidência explícita."
owner: "@AgentOrchestrator, @ImplementerCore"
status: "Accepted"
date: "2026-03-11"
version: "1.2"
keywords: "adr, decisao, arquitetura, whatsapp, integration, architecture"
related_files: "README.md, ADR-0001-technology-stack-and-architecture.md, ADR-0002-separacao-banco-por-contexto-multitenancy.md, ADR-0003-multitenancy-schema-vs-tenant-id.md, ADR-0005-multi-tenancy-architecture.md"
code_references: "WhatsAppMessagePort, ProcessIncomingMessageUseCase, SendOutboundMessageUseCase, FiscalQueryRequestedEvent, FiscalQueryPort, WhatsAppMetaCloudApiAdapter, WhatsAppWebhookController, FiscalQueryEventAdapter, ValidateAccessUseCase, GetConversationHistoryUseCase, FiscalQueryRequestPort, ConversationRepository"
principal_statement: "The WhatsApp integration will be implemented as an isolated **Spring Modulith module** (`whatsapp`) following Clean Architecture principles. The module will expose inbound ports (use cases) for message processing and outbound ports for WhatsApp API communication and cross-module queries. The WhatsApp Business API adapter will be implemented behind a `WhatsAppMessagePort` interface, making the provider replaceable. All interactions will be persisted in the `saas_whatsapp` database with `tenant_id` isolation. Cross-module communication (fiscal queries, certificate lookups) will use Spring Modulith Events."
---

# ADR-0004 - WhatsApp Integration Architecture

- Date: 2026-03-11
- Status: Accepted
- Version: 1.2
- Authors / Owners: @AgentOrchestrator, @ImplementerCore
- Reviewers: @CleanArchitecture, @DomainExpert, @SecurityOAuth, @MultiTenantEng
- Stakeholders: Engineering Team, Product Owner, Startup Founders

---

# 1. Context

The Hub Contabil Inteligente is a micro-SaaS platform that enables accounting firms to offer a self-service WhatsApp channel to their clients (companies/Documentos). The WhatsApp channel is the **primary user-facing interface** of the entire system — entrepreneurs interact with their accounting firm's chatbot to perform fiscal queries and generate DARFs (tax payment guides).

Business requirements:

- End Clients (entrepreneurs) interact exclusively via WhatsApp — there is no web portal for end clients.
- The chatbot flow: welcome → access validation (phone number vs. registered Documento) → fiscal menu → fiscal query (SERPRO) → DARF generation → completion.
- Security: only WhatsApp numbers previously authorized and linked to a specific Documento in the database may access fiscal data. Unauthorized numbers are rejected with a clear message.
- Multi-tenancy: each accounting firm (tenant) has a **dedicated WhatsApp phone number** (provided by the firm) provisioned into one of the platform's WhatsApp Business Accounts (WABAs). Tenant isolation must be enforced at every level (as defined in ADR-0005).
- Audit: complete log of all WhatsApp interactions — every message sent and received is recorded and available on the accounting firm's web dashboard.
- Resilience: SERPRO integration may be unavailable. The chatbot must handle failures gracefully, informing the user and logging a `correlationId`.
- Three subscription plans define the number of firms (Documentos) per tenant: Start (3), Business (50), Premium (unlimited).

Technical constraints:

- WhatsApp Business API requires a registered WhatsApp Business Account. To scale efficiently, the platform uses **multiple shared WABAs**, bypassing the 20-number per WABA limit. Each tenant phone number is mapped to a specific WABA in the cluster.
- Messages must be processed asynchronously — WhatsApp sends webhooks that must be acknowledged within 5 seconds.
- The WhatsApp adapter must be a replaceable port (Clean Architecture) to allow switching between WhatsApp Business API providers (Meta Cloud API, 360dialog, Twilio, etc.).
- All infrastructure on a single VPS with Docker Compose (ADR-0001). No external message brokers in Phase 1 — Spring Modulith Events for internal communication.

Related architectural decisions:

- [ADR-0001](ADR-0001-technology-stack-and-architecture.md) — Technology stack: Java 21, Spring Boot 4.x, Spring Modulith.
- [ADR-0002](ADR-0002-separacao-banco-por-contexto-multitenancy.md) — Database isolation: `saas_whatsapp` database for the WhatsApp bounded context.
- [ADR-0003](ADR-0003-multitenancy-schema-vs-tenant-id.md) — Multi-tenancy via `tenant_id` row-level isolation.
- [ADR-0005](ADR-0005-multi-tenancy-architecture.md) — Three-level tenant isolation (Keycloak + TenantContext + Hibernate @Filter).

---

# 2. Decision Statement

The WhatsApp integration will be implemented as an isolated **Spring Modulith module** (`whatsapp`) following Clean Architecture principles. The module will expose inbound ports (use cases) for message processing and outbound ports for WhatsApp API communication and cross-module queries. The WhatsApp Business API adapter will be implemented behind a `WhatsAppMessagePort` interface, making the provider replaceable. All interactions will be persisted in the `saas_whatsapp` database with `tenant_id` isolation. Cross-module communication (fiscal queries, certificate lookups) will use Spring Modulith Events.

---

# 3. Decision Drivers

- **Clean Architecture:** WhatsApp API is an infrastructure detail. Domain logic (chatbot flow, access validation, audit) must not depend on the specific WhatsApp provider.
- **Replaceable provider:** The WhatsApp Business API ecosystem has multiple providers (Meta Cloud API, 360dialog, Twilio). The adapter must be swappable without changing business logic.
- **Multi-tenancy:** Each tenant has a **dedicated phone number** hosted in one of the platform's WABAs. Messages are routed to the correct tenant based on the destination `phone_number_id`, which internally resolves both the `tenant_id` and the `waba_config_id` required to respond. The WABAs are owned and managed by the SaaS platform (Super Admin).
- **Audit and compliance:** Every WhatsApp interaction must be logged for the accounting firm's audit dashboard. LGPD requires all interaction data to be tenant-isolated and erasable.
- **Resilience:** SERPRO may be unavailable. The chatbot must handle failures gracefully with user-friendly messages and retry mechanisms.
- **Asynchronous processing:** WhatsApp webhooks must be acknowledged within 5 seconds. Business logic runs asynchronously after acknowledgment.
- **Spring Modulith isolation:** The WhatsApp module communicates with Fiscal and Certificate modules exclusively via domain events — no direct imports.
- **VPS constraints:** No external message broker. Spring Modulith Events handle internal async communication. Redis can queue messages if needed.

---

# 4. Considered Options

## Option 1: Spring Modulith Module with Clean Architecture Ports (Selected)

Description: WhatsApp channel implemented as an isolated Spring Modulith module. `WhatsAppMessagePort` (outbound port) abstracts the API provider. `ProcessIncomingMessageUseCase` and `SendOutboundMessageUseCase` are inbound ports. Cross-module communication via Spring Modulith Events.

Pros:
- Clean Architecture: domain logic independent of WhatsApp provider
- Replaceable adapter: swap Meta Cloud API for Twilio by changing one adapter class
- Module isolation: Spring Modulith enforces boundaries
- Testable: mock the `WhatsAppMessagePort` for unit tests without real API calls
- Event-driven: fiscal queries triggered via domain events, decoupled from WhatsApp module

Cons:
- More abstraction layers to maintain
- Spring Modulith Events are eventually consistent — must handle edge cases
- Webhook processing requires careful async handling

## Option 2: Direct API Integration (No Port Abstraction)

Description: WhatsApp Business API called directly from service classes. No port/adapter abstraction.

Pros:
- Faster initial implementation
- Fewer classes to create

Cons:
- Tight coupling to specific WhatsApp provider
- Switching providers requires rewriting business logic
- Violates Clean Architecture — domain depends on infrastructure
- Harder to test without real API calls

## Option 3: External Chatbot Platform (Dialogflow, Botpress)

Description: Use an external chatbot platform for conversation management, with webhooks back to the SaaS service for fiscal queries.

Pros:
- NLP capabilities out of the box
- Visual flow builder

Cons:
- External dependency adds cost and latency
- Multi-tenancy must be managed in the external platform
- Sensitive fiscal data passes through a third party — LGPD risk
- Vendor lock-in
- Does not align with zero cloud cost constraint (ADR-0001)

---

# 5. Decision Outcome

**Option 1 (Spring Modulith Module with Clean Architecture Ports)** was selected.

Key factors:

- **Provider independence:** The WhatsApp Business API landscape is fragmented. Starting with Meta Cloud API, but the architecture must allow switching to 360dialog or Twilio without changing domain logic.
- **Testability:** Mocking `WhatsAppMessagePort` enables full chatbot flow testing without API calls. Critical for CI/CD on a self-hosted runner.
- **Multi-tenancy:** Tenant routing based on destination `phone_number_id` is a domain concern (multiple WABAs → multiple numbers → one number per tenant). Clean Architecture keeps this routing logic in the domain layer.
- **Spring Modulith Events:** The WhatsApp module triggers `FiscalQueryRequestedEvent` which is consumed by the Fiscal module. No direct dependency.
- **Audit:** All messages are persisted in `saas_whatsapp` with `tenant_id`. The web dashboard queries this data.

Tradeoffs accepted:

- More abstraction layers (port + adapter) for the WhatsApp API. Acceptable for provider flexibility and testability.
- Spring Modulith Events are eventually consistent. Mitigated by: user-facing responses include "processing..." message while waiting for fiscal query results.
- No NLP — the chatbot is menu-driven. Acceptable for the structured fiscal query flow; NLP can be added later if needed.

---

# 6. Consequences

Positive Consequences:

- WhatsApp provider can be switched without modifying domain logic or chatbot flow.
- Full chatbot flow is testable without external API dependencies.
- Audit log is complete: every message (inbound and outbound) is persisted with `tenant_id`.
- Cross-module communication via events prevents coupling between WhatsApp and Fiscal modules.
- The module can be extracted as a microservice when scale demands it (Spring Modulith design).

Negative Consequences:

- Port/adapter abstraction adds development overhead for the initial implementation.
- Webhook acknowledgment must happen within 5 seconds — async processing adds complexity.
- Conversation state management (multi-step chatbot flow) requires a state machine or session store.

Neutral Consequences:

- Redis can be used for conversation session state if ThreadLocal is insufficient for multi-step flows.
- The chatbot is menu-driven, not NLP-based. Future NLP integration would be an adapter change.

---

# 7. Impact

- **Architecture:** New Spring Modulith module: `whatsapp`. Clean Architecture layers: `domain/model` (Message, Conversation, AccessValidation), `domain/port/in` (ProcessIncomingMessageUseCase), `domain/port/out` (WhatsAppMessagePort, FiscalQueryPort), `application/usecase`, `adapter/in/webhook` (WhatsApp webhook controller), `adapter/out/whatsapp` (Meta Cloud API client).
- **Infrastructure:** Multiple shared WABAs with platform-level credentials stored in `whatsapp_platform_config`. Per-tenant phone numbers mapped in `saas_whatsapp.whatsapp_phone_numbers` table with a foreign key to the WABA config. Webhook endpoint exposed via Nginx/Caddy reverse proxy. A generic webhook architecture is used so a single endpoint can receive messages from multiple WABAs.
- **Security:** Access validation: phone number must be linked to a Documento in the tenant's database. Unauthorized numbers receive a rejection message. All message content encrypted at rest.
- **Development Process:** Chatbot flow defined as a state machine. Each state transition is a domain event. Flow changes require only domain logic updates.
- **Deployment Pipeline:** A single webhook URL is registered across all the platform's WABAs. Requires HTTPS endpoint (Caddy with Let's Encrypt). New tenants only need their phone number provisioned in an available WABA.
- **Data Architecture:** `saas_whatsapp` database tables: `conversations`, `messages`, `access_validations`, `chatbot_sessions`. All with `tenant_id`.
- **Observability:** Metrics: messages processed per second, webhook latency, SERPRO query success rate, conversation completion rate. MDC includes `tenantId`, `conversationId`, `correlationId`.
- **DevOps:** No additional Docker containers needed. WhatsApp API is external. Caddy handles HTTPS for webhook endpoint.
- **AI Agent Orchestration:** @ImplementerCore implements chatbot flow use cases. @AdapterDev implements WhatsApp API adapter. @SecurityOAuth validates access. @TestAutomator writes chatbot flow integration tests.

---

# 8. AI Agent Considerations (For Autonomous Agent Environments)

Agent Roles Impacted:

- **@DomainExpert:** Models the WhatsApp bounded context: Message (aggregate), Conversation (aggregate), AccessValidation (value object), ChatbotSession (entity). Defines the chatbot state machine transitions.
- **@CleanArchitecture:** Defines port interfaces: `ProcessIncomingMessageUseCase`, `SendOutboundMessageUseCase` (inbound ports), `WhatsAppMessagePort`, `FiscalQueryPort` (outbound ports). Validates module isolation.
- **@ImplementerCore:** Implements chatbot flow use cases: access validation, menu navigation, fiscal query request, DARF generation request, error handling.
- **@AdapterDev:** Implements `WhatsAppMetaCloudApiAdapter` (outbound adapter for Meta Cloud API), `WhatsAppWebhookController` (inbound webhook adapter). Implements `FiscalQueryEventAdapter` (Spring Modulith Event publisher/listener).
- **@SecurityOAuth:** Validates that only authorized phone numbers can access tenant data. Implements phone-to-Documento validation logic.
- **@MultiTenantEng:** Ensures all WhatsApp data is isolated by `tenant_id`. Routes incoming messages to correct tenant based on destination phone number.
- **@TestAutomator:** Writes chatbot flow tests (mock WhatsApp API), access validation tests, tenant isolation tests, webhook acknowledgment timing tests.
- **@Kafka-Agent:** (Future) When the WhatsApp module is extracted as a microservice, replaces Spring Modulith Events with Kafka/RabbitMQ for cross-service communication.

Operational Considerations:

- The WhatsApp module must not import classes from the Fiscal or Certificate modules directly. All cross-module communication via Spring Modulith Events.
- Webhook endpoints must be idempotent — WhatsApp may retry the same webhook multiple times.
- Message deduplication based on WhatsApp message ID is required.

LLM Considerations:

- Chatbot flow generation prompts must include the state machine definition and transition rules.
- Adapter generation prompts must reference `WhatsAppMessagePort` interface as the contract.
- Test generation prompts must include mock WhatsApp API responses for each chatbot state.

Safety Considerations:

- No agent may expose the webhook endpoint without rate limiting and signature validation (WhatsApp webhook signature).
- No agent may bypass access validation (phone number → Documento linkage).
- Fiscal data returned via WhatsApp must be masked or summarized — no full CPF/Documento in plain text messages.
- All WhatsApp API credentials must be stored encrypted — managed by @SecurityOAuth.

---

# 9. Implementation Plan

## Phase 3 — WhatsApp Channel (Sprint 6-7)

### Architecture Diagram

```
┌──────────────────────────────────────────────────────────────────────┐
│                    WHATSAPP MODULE (Spring Modulith)                   │
│                                                                       │
│  ┌──────────────────────────────────────────────────────────────┐    │
│  │                    ADAPTER IN (Webhook)                      │    │
│  │  ┌────────────────────────────┐                              │    │
│  │  │ WhatsAppWebhookController  │  POST /api/v1/whatsapp/hook │    │
│  │  │ • Validates webhook sig.   │  (acknowledged < 5s)        │    │
│  │  │ • Resolves tenant by phone │                              │    │
│  │  │ • Delegates to use case    │                              │    │
│  │  └────────────┬───────────────┘                              │    │
│  └───────────────┼──────────────────────────────────────────────┘    │
│                  ▼                                                    │
│  ┌──────────────────────────────────────────────────────────────┐    │
│  │                    DOMAIN (Use Cases)                         │    │
│  │                                                               │    │
│  │  ┌──────────────────────┐  ┌──────────────────────┐          │    │
│  │  │ProcessIncomingMessage│  │ SendOutboundMessage   │          │    │
│  │  │      UseCase         │  │      UseCase          │          │    │
│  │  └──────────┬───────────┘  └──────────┬───────────┘          │    │
│  │             │                          │                      │    │
│  │  ┌──────────▼────────────────────────────────────────┐       │    │
│  │  │              ChatbotFlowService                    │       │    │
│  │  │  State Machine:                                    │       │    │
│  │  │  WELCOME → VALIDATE_ACCESS → MENU → FISCAL_QUERY  │       │    │
│  │  │                                    → DARF_GENERATE │       │    │
│  │  │                                    → HELP          │       │    │
│  │  │                              COMPLETED             │       │    │
│  │  └───────┬──────────────┬─────────────────────────────┘       │    │
│  │          │              │                                      │    │
│  │  ┌──────▼──────┐ ┌─────▼──────────┐                          │    │
│  │  │AccessValid. │ │AuditLogService │                           │    │
│  │  │(Phone→Documento) │ │(All messages)  │                           │    │
│  │  └─────────────┘ └────────────────┘                           │    │
│  └──────────────────────────────────────────────────────────────┘    │
│                  │                          │                         │
│  ┌───────────────┼──────────────────────────┼────────────────────┐   │
│  │               │  PORTS (Outbound)        │                    │   │
│  │  ┌────────────▼──────┐  ┌────────────────▼──────┐            │   │
│  │  │WhatsAppMessagePort│  │FiscalQueryRequestPort │            │   │
│  │  │  (interface)      │  │  (Spring Modulith     │            │   │
│  │  │                   │  │   Event Publisher)     │            │   │
│  │  └────────┬──────────┘  └────────────┬──────────┘            │   │
│  └───────────┼──────────────────────────┼────────────────────────┘   │
│              ▼                          ▼                             │
│  ┌──────────────────┐    ┌──────────────────────────────┐           │
│  │  ADAPTER OUT      │    │  SPRING MODULITH EVENTS      │           │
│  │  Meta Cloud API   │    │                               │           │
│  │  (WhatsApp Busn.) │    │  FiscalQueryRequestedEvent    │           │
│  │                   │    │  → Fiscal Module consumes     │           │
│  │  Replaceable:     │    │  → Returns FiscalQueryResult  │           │
│  │  360dialog/Twilio │    │     via response event        │           │
│  └──────────────────┘    └──────────────────────────────┘           │
│                                                                       │
│  ┌──────────────────────────────────────────────────────────────┐    │
│  │                    DATABASE (saas_whatsapp)                   │    │
│  │  conversations | messages | access_validations | sessions    │    │
│  │  All tables: tenant_id UUID NOT NULL (indexed)               │    │
│  └──────────────────────────────────────────────────────────────┘    │
└──────────────────────────────────────────────────────────────────────┘
```

### Chatbot Flow State Machine

```
                        ┌─────────────┐
                        │   WELCOME   │
                        │ "Olá! Sou   │
                        │ o assistente│
                        │ do Escritório│
                        │  Contábil"  │
                        └──────┬──────┘
                               │
                        ┌──────▼──────┐
                        │  VALIDATE   │
                        │  ACCESS     │
                    ┌───│ Phone→Documento? │───┐
                    │   └─────────────┘   │
                 INVALID              VALID
                    │                     │
             ┌──────▼──────┐       ┌──────▼──────┐
             │ UNAUTHORIZED│       │    MENU     │
             │ "Seu número │       │ 1. Situação │
             │ não está    │       │    Fiscal   │
             │ autorizado" │       │ 2. DARF     │
             └─────────────┘       │ 3. Ajuda    │
                                   └──┬──┬──┬────┘
                                      │  │  │
                            ┌─────────┘  │  └─────────┐
                            │            │            │
                     ┌──────▼──────┐ ┌───▼────┐ ┌────▼─────┐
                     │FISCAL_QUERY │ │  DARF  │ │   HELP   │
                     │ Consulta    │ │Generate│ │ Info do  │
                     │ SERPRO API  │ │ Guia   │ │ escritório│
                     └──────┬──────┘ └───┬────┘ └────┬─────┘
                            │            │            │
                     ┌──────▼──────────────────────────▼──────┐
                     │              COMPLETED                  │
                     │ "Obrigado! Até a próxima."             │
                     │ (Session expires after 24h)            │
                     └────────────────────────────────────────┘
```

### Implementation Tasks

1. **Domain Model:** `Message` (aggregate root), `Conversation` (aggregate root), `AccessValidation` (entity), `ChatbotSession` (entity with state machine), `PhoneNumber` (value object), `WhatsAppPhoneNumber` (entity — maps a phone number to a tenant and to a specific WABA config).

2. **Inbound Ports:** `ProcessIncomingMessageUseCase`, `SendOutboundMessageUseCase`, `ValidateAccessUseCase`, `GetConversationHistoryUseCase` (for audit dashboard).

3. **Outbound Ports:** `WhatsAppMessagePort` (send/receive messages), `FiscalQueryRequestPort` (event publisher), `ConversationRepository`, `MessageRepository`.

4. **Webhook Adapter:** `WhatsAppWebhookController` — validates webhook signature, resolves tenant by destination phone number, acknowledges within 5 seconds, delegates to use case asynchronously.

5. **WhatsApp API Adapter:** `WhatsAppMetaCloudApiAdapter` implements `WhatsAppMessagePort`. Uses WebClient (non-blocking) for Meta Cloud API calls. Handles message templates, media messages, and interactive buttons.

6. **Chatbot Flow Service:** State machine implementation. Each state produces a response message and determines the next state based on user input.

7. **Access Validation:** Phone number → Documento linkage query. Validates number is authorized for the tenant. Rejects unauthorized access with audit log entry.

8. **Audit Logging:** Every inbound/outbound message persisted in `saas_whatsapp.messages` with `tenant_id`, `conversation_id`, `timestamp`, `direction` (IN/OUT), `content`.

9. **Spring Modulith Events:** `FiscalQueryRequestedEvent` published by WhatsApp module. Consumed by Fiscal module. `FiscalQueryResultEvent` returned with query results.

10. **Flyway Migrations:** Tables: `whatsapp_business_accounts`, `conversations`, `messages`, `access_validations`, `chatbot_sessions`. All with `tenant_id UUID NOT NULL`.

Responsible agents: @DomainExpert, @ImplementerCore, @AdapterDev, @SecurityOAuth, @TestAutomator

Dependencies: ADR-0001 (foundation), ADR-0002 (database), ADR-0003 (tenant_id), ADR-0005 (multi-tenancy architecture). Fiscal Integration module (Sprint 3-5) must be available for cross-module events. Certificate Management module must be available for SERPRO authentication.

Rollback plan: The WhatsApp module can be disabled by removing the webhook route in Caddy. The Fiscal module continues to operate via REST API without WhatsApp. Messages in `saas_whatsapp` are retained for audit.

---

# 10. Validation

Architecture Validation:

- Spring Modulith `ApplicationModules.verify()` confirms WhatsApp module does not import Fiscal or Certificate module classes directly.
- ArchUnit test: WhatsApp domain does not depend on WhatsApp adapter (Clean Architecture).
- ArchUnit test: WhatsApp module entities extend `TenantAwareEntity`.

Chatbot Flow Tests:

- Test: Complete happy path — welcome → validate → menu → fiscal query → result → completion.
- Test: Unauthorized access — phone number not registered → rejection message → audit log entry.
- Test: SERPRO unavailable — fiscal query returns error → chatbot shows friendly error with `correlationId`.
- Test: Invalid Documento format — chatbot prompts for correction.
- Test: Multi-tenant isolation — messages from Tenant A are not visible to Tenant B.

Webhook Tests:

- Test: Webhook acknowledged within 5 seconds — business logic runs asynchronously.
- Test: Duplicate message ID — idempotent processing, no duplicate entries.
- Test: Invalid webhook signature — request rejected with 401.

Performance Benchmarks:

- Webhook processing latency: acknowledgment < 500ms, full response < 5s (excluding SERPRO latency).
- 100 concurrent WhatsApp sessions on a single VPS (2 vCPU, 4GB RAM).
- Message throughput: 50 messages/second sustained.

Success Criteria:

- All chatbot flow states tested and passing.
- Access validation blocks unauthorized phone numbers.
- Tenant isolation verified — Tenant A messages invisible to Tenant B.
- Audit log captures 100% of WhatsApp interactions.
- Webhook signature validation prevents unauthorized requests.
- `WhatsAppMessagePort` adapter is replaceable — test with mock adapter passes identical flow.

---

# 11. Risks and Mitigations

Risk 1:
Description: WhatsApp Business API rate limits or policy changes disrupt service.
Mitigation: Implement rate limiting per tenant. Queue-based message processing (Redis queue if needed). Design `WhatsAppMessagePort` as replaceable port to allow switching providers. Monitor API quota usage via Prometheus metrics.

Risk 2:
Description: SERPRO API unavailable during fiscal query — chatbot flow blocked.
Mitigation: Circuit breaker (Resilience4j) on SERPRO calls. Cached results in Redis with configurable TTL. Chatbot returns user-friendly error with `correlationId` and suggests retrying later.

Risk 3:
Description: Webhook endpoint becomes a DDoS target.
Mitigation: Webhook signature validation (WhatsApp signs every request). Rate limiting at Caddy/Nginx level. IP allowlisting for WhatsApp API servers. Fail2ban for repeated invalid signatures.

Risk 4:
Description: Conversation state lost between messages (stateless HTTP).
Mitigation: `ChatbotSession` entity persisted in `saas_whatsapp` database with `conversation_id` and current state. Session expires after 24 hours of inactivity.

Risk 5:
Description: Multi-tenant phone number routing error or WABA mismatch — message routed to wrong tenant or API fails due to wrong credentials.
Mitigation: Tenant resolution based on `phone_number_id` → `tenant_id` and `waba_config_id` mapping stored in `saas_whatsapp.whatsapp_phone_numbers` table. Each tenant has a unique phone number linked to the correct WABA context. Integration test validates routing and correct credential selection for multiple WABAs. The mapping is managed exclusively by the Super Admin.

Risk 6:
Description: LGPD violation — WhatsApp message content (potentially containing PII) not properly handled.
Mitigation: All messages encrypted at rest in `saas_whatsapp` database. `tenant_id` isolation ensures data erasure per tenant is straightforward. Message retention policy configurable per tenant. @ComplianceAgent audits data flows.

---

# 12. Related ADRs

- [ADR-0001 - Technology Stack and Architecture Foundation](ADR-0001-technology-stack-and-architecture.md) — Java 21, Spring Boot 4.x, Spring Modulith, Clean Architecture.
- [ADR-0002 - Multi-Tenant Database Isolation Strategy](ADR-0002-separacao-banco-por-contexto-multitenancy.md) — `saas_whatsapp` database for WhatsApp bounded context.
- [ADR-0003 - Multi-Tenancy Schema vs tenant_id](ADR-0003-multitenancy-schema-vs-tenant-id.md) — `tenant_id` row-level isolation for all WhatsApp tables.
- [ADR-0005 - Multi-Tenancy Architecture](ADR-0005-multi-tenancy-architecture.md) — Three-level isolation applied to WhatsApp module.
- (Future) ADR-0006 — SERPRO Integra Contador Integration Pattern (WhatsApp module depends on this for fiscal queries).
- (Future) ADR-0007 — Observability and Monitoring Stack (WhatsApp metrics and dashboards).

---

# 13. References

- [WhatsApp Business Platform — Cloud API](https://developers.facebook.com/docs/whatsapp/cloud-api)
- [WhatsApp Business API — Webhooks](https://developers.facebook.com/docs/whatsapp/cloud-api/webhooks)
- [WhatsApp Business API — Message Templates](https://developers.facebook.com/docs/whatsapp/message-templates)
- [Spring Modulith — Events](https://docs.spring.io/spring-modulith/reference/events.html)
- [Resilience4j — Circuit Breaker](https://resilience4j.readme.io/docs/circuitbreaker)
- [SERPRO Integra Contador](https://www.serpro.gov.br/links-fixos-702702/integra-contador)
- Business Requirements: [Visão de produto](../product/business/product-vision.md)
- Agent Factory Specification: [Catálogo de agentes](../agents/README.md)

---

# 14. Decision Lifecycle

Current State: **Accept**

This ADR has been created and is under review. Upon acceptance, it becomes the governing document for all WhatsApp integration design decisions. Any changes to the WhatsApp architecture require a new ADR that supersedes this one.

---

# 15. Change Log

Version: 1.0
Date: 2026-03-08
Author: @AgentOrchestrator, @ImplementerCore
Changes:
- Initial ADR creation defining WhatsApp integration architecture for the Hub Contabil Inteligente.
- Covers Clean Architecture module design, chatbot state machine, webhook processing, multi-tenancy, audit logging, and Spring Modulith event-driven cross-module communication.

Version: 1.1
Date: 2026-03-11
Author: @ImplementerCore
Changes:
- Migrated from per-tenant WABA model to **Shared WABA model (Model B)**: the SaaS platform owns a single WABA with multiple phone numbers, one per tenant.

Version: 1.2
Date: 2026-03-11
Author: @RequirementAgent
Changes:
- Evolved Shared WABA to **Multi-WABA scale architecture**: SaaS platform provisions multiple WABAs to bypass Meta's 20-number limit per WABA.
- Adjusted tenant configuration logic: number is supplied by the firm (tenant), but hosted in a platform WABA.
- Domain Model: `phone_number_id` now resolves to a specific `waba_config_id` to route outbound traffic using the correct account credentials.

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
```

Future ADRs will follow the naming convention: `ADR-XXXX-short-title.md`

---

# 17. Review Process

1. This ADR was created in "Accept" status by @AgentOrchestrator and @ImplementerCore.
2. Reviewers (@CleanArchitecture, @DomainExpert, @SecurityOAuth, @MultiTenantEng) must validate the WhatsApp module design against Clean Architecture principles, security requirements, and multi-tenancy constraints.
3. The startup founders must confirm alignment with the chatbot flow and subscription plan structure.
4. Upon approval, the status changes to "Accepted" and the ADR becomes immutable.
5. If the WhatsApp integration architecture needs to change, a new ADR must be created and this ADR marked as "Superseded."

---

# 18. Notes

This ADR defines the **WhatsApp Integration Architecture** for the Hub Contabil Inteligente project. WhatsApp is the primary user-facing channel — it is how end clients (entrepreneurs) interact with their accounting firm's services.

Module boundary summary:

| Concern | Owner Module | Communication |
|---------|-------------|---------------|
| Incoming WhatsApp messages | WhatsApp module | Webhook adapter |
| Access validation (phone → Documento) | WhatsApp module | Internal domain logic |
| Chatbot flow and state management | WhatsApp module | State machine service |
| Fiscal query execution | Fiscal module | Spring Modulith Event |
| Certificate authentication for SERPRO | Certificate module | Spring Modulith Event |
| Message audit log | WhatsApp module | `saas_whatsapp` database |
| Outbound WhatsApp messages | WhatsApp module | `WhatsAppMessagePort` adapter |

Key design decisions:

- **`WhatsAppMessagePort`** is the critical abstraction. The entire WhatsApp provider dependency is behind this single interface. Swapping from Meta Cloud API to Twilio requires implementing one new adapter class.
- **Chatbot flow is a state machine**, not hard-coded if/else. Each state is a domain object with transitions. This enables flow customization per tenant in the future.
- **Webhook acknowledgment within 5 seconds** — business logic runs asynchronously. This is enforced by the `WhatsAppWebhookController` which returns 200 immediately and processes the message in a separate thread.
- **No external message broker** in Phase 1. Spring Modulith Events provide sufficient async communication for a single-VPS deployment. When the WhatsApp module is extracted as a microservice, events are replaced by Kafka/RabbitMQ (managed by @Kafka-Agent).
- **Access validation** is a security gate: unauthorized phone numbers are rejected at the domain level, not at the adapter level. This ensures the validation logic is testable independently of the WhatsApp provider.
