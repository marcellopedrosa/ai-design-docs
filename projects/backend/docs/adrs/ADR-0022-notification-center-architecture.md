---
document_id: "ADR-0022"
primary_nature: "Decisao"
objective: "Definir uma arquitetura centralizada para notificacoes outbound multicanal."
scope: "Email, SMS, WhatsApp e Telegram, isolamento por tenant, entrega e auditoria."
non_objectives: "Nao escolher definitivamente provedores, definir conteúdo funcional de cada mensagem nem intermediar e-mails de credencial emitidos nativamente pelo Keycloak."
owner: "@AgentOrchestrator, @MultiTenantEng, @RequirementAgent"
status: "Accepted"
date: "2026-07-12"
version: "1.1"
last_reviewed: "2026-09-07"
keywords: "notification center, outbound, multichannel, tenant, audit"
related_files: "README.md, ADR-0004-whatsapp-integration-architecture.md, ADR-0018-keycloak-realm-provisioning-automation.md"
code_references: "backend/ - contexto de notificacoes e adapters de provider planejados ou vigentes; infra/keycloak/bootstrap/reconcile-realm-smtp.sh - boundary separado de credenciais IAM."
principal_statement: "Comunicacoes outbound de negócio atravessam a Central de Notificações; mensagens de credencial e recuperação permanecem no Keycloak e usam o SMTP próprio do realm."
---

# ADR-0022 - Notification Center Architecture

- Document ID: `ADR-0022`
- Primary Nature: `Decisao`
- Objective: Definir uma arquitetura centralizada para notificacoes outbound multicanal.
- Scope: Email, SMS, WhatsApp e Telegram, isolamento por tenant, entrega e auditoria.
- Non-objectives: Nao escolher definitivamente provedores, definir conteúdo funcional de cada mensagem nem intermediar e-mails de credencial emitidos pelo Keycloak.
- Keywords: notification center, outbound, multichannel, tenant, audit
- Related Files: `docs/product/use-cases/UC-00017-gestao-central-de-notificacoes.md`, `ADR-0004-whatsapp-integration-architecture.md`
- Code References: `backend/` - contexto de notificacoes e adapters de provider planejados ou vigentes.
- Principal Decision: Comunicacoes outbound de negócio atravessam a Central de Notificações; e-mails de credencial permanecem no Keycloak com SMTP por realm.
- Date: 2026-07-12
- Status: Accepted
- Version: 1.1
- Authors / Owners: @AgentOrchestrator, @MultiTenantEng, @RequirementAgent
- Reviewers: @CleanArchitecture, @DomainExpert, @DevOps-Agent
- Stakeholders: Engineering Team, Product Owner

---

# 1. Context

The Contador Fiscal Inteligente SaaS platform currently handles communications via WhatsApp (as established in ADR-0004). However, with the introduction of new user flows, such as the Office User Invitation Flow (UC-00016), there is a need to support additional communication channels like transactional emails.

Furthermore, the system lacks a centralized mechanism to track, log, and audit outbound messages sent across different channels (Email, SMS, WhatsApp, Telegram) per tenant. Sending messages directly from disparate bounded contexts (e.g., billing sending emails, user management sending emails) violates DRY principles, complicates auditing, and makes it difficult to switch providers (e.g., from SendGrid to AWS SES).

Business requirements:
- Create a centralized "Notification Center" to handle all outbound communications.
- Support multiple agnostic channels (Email, SMS, WhatsApp, Telegram).
- Ensure strict multi-tenant isolation for notification logs.
- Provide a robust audit trail of what was sent, when, to whom, and its delivery status.

---

# 2. Decision Statement

We will implement a **Centralized Notification Center** as a distinct bounded context within the Spring Modulith architecture. 

It will have its own dedicated database (`saas_notification`) adhering to the multi-tenancy rules (ADR-0005) with `tenant_id` isolation. The context will expose a generic `NotificationGateway` interface that internal modules can call to dispatch messages. The Notification Center will log the message request, persist the payload and metadata, and use provider-specific adapters (e.g., SMTP Adapter, Twilio Adapter, Meta API Adapter) to deliver the message asynchronously.

## 2.1 Boundary de identidade

Recuperação de senha, verificação de e-mail e execute-actions que contenham token
de credencial não atravessam a Central de Notificações. O Keycloak gera, expira e
envia essas mensagens diretamente pelo `smtpServer` do realm, conforme ADR-0018
e REQ-00058. Isso evita persistir links/tokens sensíveis em
`saas_notification` e preserva as proteções nativas contra enumeração e replay.

DEV/HML podem apontar tanto a Central quanto o Keycloak para o mesmo processo
Mailpit, mas as configurações, credenciais e trilhas continuam independentes.
PRD exige provider transacional; compartilhar o vendor não transforma os dois
bounded contexts em uma única configuração.

---

# 3. Decision Drivers

- **Auditability and Compliance**: Must keep a historical log of all communications sent on behalf of a tenant for legal and compliance reasons.
- **Provider Agnosticism**: The core system must not be coupled to specific email or SMS providers.
- **Resilience**: Outbound communications should ideally be asynchronous to prevent external API latency from blocking business transactions.
- **Multi-Tenancy**: A tenant must only be able to view and manage notifications generated within its own context.

---

# 4. Considered Options

## Option 1: Direct Integration per Module
Description: Each module (e.g., Identity, Billing) integrates directly with email/SMS providers and manages its own logs.
Pros: Minimal upfront architectural work.
Cons: High code duplication, inconsistent logging, difficult to audit centrally, hard to change providers globally.

## Option 2: Centralized Notification Center Module (Selected)
Description: A dedicated `saas_notification` bounded context with its own database. Modules send an internal event or call an API to request a notification. The Notification Center logs it and dispatches it via agnostic adapters.
Pros: Single source of truth for communications, easy provider swapping, consistent audit logs per tenant.
Cons: Requires setting up a new bounded context and database.

---

# 5. Decision Outcome

**Option 2 (Centralized Notification Center Module)** was selected.

This approach aligns with our Clean Architecture and Spring Modulith strategy. The `saas_notification` context will act as the single source of truth for outbound messages, providing the necessary audit logs required by the business.

---

# 6. Architecture & Implementation Plan

## 6.1 Database Schema (`saas_notification`)

The database will store the log of all notifications.
```sql
CREATE TABLE notification_log (
    id UUID PRIMARY KEY,
    tenant_id UUID NOT NULL,
    channel VARCHAR(50) NOT NULL, -- EMAIL, SMS, WHATSAPP, TELEGRAM
    recipient VARCHAR(255) NOT NULL,
    subject VARCHAR(255),
    content TEXT NOT NULL,
    status VARCHAR(50) NOT NULL, -- PENDING, SENT, FAILED, DELIVERED
    provider_reference VARCHAR(255),
    created_at TIMESTAMP NOT NULL,
    sent_at TIMESTAMP,
    error_message TEXT
);
CREATE INDEX idx_notification_tenant ON notification_log(tenant_id);
```

## 6.2 Internal Interface

Modules will interact with the Notification Center via a Spring Modulith internal event or a local service interface:

```java
public interface NotificationGateway {
    void dispatch(NotificationRequest request);
}

public record NotificationRequest(
    UUID tenantId,
    NotificationChannel channel,
    String recipient,
    String subject,
    String content,
    Map<String, Object> metadata
) {}
```

## 6.3 Flow Example (Office User Invitation)

1. **Identity Module** (or Admin Module) creates a user in Keycloak.
2. Uma mensagem de negócio sem token de credencial pode seguir pelo
   `NotificationGateway`, ser auditada e entregue pelo adapter de e-mail.
3. A ação de definir/recuperar senha é solicitada ao Keycloak por mecanismo
   nativo; o Keycloak gera o link temporário e envia pelo SMTP daquele realm.
4. A Central não recebe, persiste nem renderiza o link/token de credencial.

---

# 7. Impact

- **Infrastructure:** A new PostgreSQL database `saas_notification` will be added to the `docker-compose.yml` initialization scripts.
- **Development:** Developers must use the `NotificationGateway` for all future outbound messages instead of writing direct provider integrations.
- **Multi-Tenancy:** The `notification_log` table includes `tenant_id` and must be mapped as a `TenantAwareEntity` (ADR-0005).
- **IAM:** `smtpServer` do Keycloak possui lifecycle por realm e configuração
  separada; falha nesse transporte não deve ser compensada por persistência de
  link de recuperação na Central.

---

# 8. Related ADRs

- [ADR-0001 - Technology Stack and Architecture Foundation](ADR-0001-technology-stack-and-architecture.md)
- [ADR-0004 - WhatsApp Integration Architecture](ADR-0004-whatsapp-integration-architecture.md)
- [ADR-0005 - Multi-Tenancy Architecture](ADR-0005-multi-tenancy-architecture.md)
- [ADR-0018 - Keycloak Realm Provisioning Automation](ADR-0018-keycloak-realm-provisioning-automation.md)
- [REQ-00058 - Recuperação de senha Keycloak e SMTP multiambiente](../product/requirements/REQ-00058-keycloak-password-recovery-smtp.md)

---

# 9. Change Log

| Version | Date | Changes |
| --- | --- | --- |
| 1.1 | 2026-09-07 | Separa e-mails de credencial do Keycloak da Central de Notificações e proíbe persistir links/tokens de recuperação no contexto de negócio. |
| 1.0 | 2026-07-12 | Define a Central de Notificações outbound provider-neutral. |
