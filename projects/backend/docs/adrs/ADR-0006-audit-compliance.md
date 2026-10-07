---
document_id: "ADR-0006"
primary_nature: "Decisao"
objective: "Registrar a decisão arquitetural “Audit and Compliance Strategy”, seus motivadores, alternativas e consequências."
scope: "Decisão, componentes, integrações e limites explicitamente descritos em “Audit and Compliance Strategy”."
non_objectives: "Não implementar a decisão, substituir requisitos relacionados nem atestar capabilities ou ambientes sem evidência explícita."
owner: "@AgentOrchestrator, @ComplianceAgent"
status: "Proposed"
date: "2026-03-09"
version: "1.1"
keywords: "adr, decisao, arquitetura, audit, and, compliance, strategy"
related_files: "README.md, ADR-0001-technology-stack-and-architecture.md, ADR-0002-separacao-banco-por-contexto-multitenancy.md, ADR-0003-multitenancy-schema-vs-tenant-id.md, ADR-0005-multi-tenancy-architecture.md"
code_references: "AuditPort, AuditService, AuditServiceAdapter, JpaAuditServiceAdapter, CreateTenantUseCase, CreateUserUseCase, UploadCertificateUseCase, RevokeCertificateUseCase, ConsultarSituacaoFiscalUseCase"
principal_statement: "The system will implement a custom `audit_log` table in the `saas_tenant` database with an application-layer `AuditPort` and an infrastructure-layer `AuditService` adapter. Sensitive actions across all bounded contexts will be audited through explicit port invocation in use cases and an optional `@Audited` AOP annotation. Audit records will capture the authenticated user, tenant, action type, affected resource, timestamp, client IP, and result."
---

# ADR-0006 - Audit and Compliance Strategy

- Date: 2026-03-09
- Status: Proposed
- Version: 1.1
- Authors / Owners: @AgentOrchestrator, @ComplianceAgent
- Reviewers: @CleanArchitecture, @SecurityOAuth, @ImplementerCore, @AdapterDev
- Stakeholders: Development Team, Accounting Firm Tenants, Data Protection Officer
- Supersedes: None
- Superseded by: None

---

# 1. Context

The Contador Fiscal Inteligente is a multi-tenant SaaS platform serving accounting firms that handle sensitive data daily: Documento records, digital certificates (e-CPF/e-Documento), fiscal situation queries against SERPRO, and financial billing information.

Several factors create an urgent need for a formal audit and compliance strategy:

- **LGPD (Lei Geral de Proteção de Dados):** As a data processor handling taxpayer information on behalf of accounting firms, the platform must demonstrate accountability for data access and modifications. Article 7 of LGPD requires a legal basis for data processing, and audit trails are a fundamental mechanism to prove compliance.
- **Multi-Tenant Accountability:** With row-level tenant isolation via `tenant_id` (ADR-0003), it is critical to trace which user within which tenant performed sensitive operations, especially when data crosses context boundaries (e.g., a fiscal query that consumes billing credits).
- **Digital Certificate Security:** Digital certificates stored in the `saas_certificate` database have high security sensitivity. Any access, upload, renewal, or revocation must be traceable.
- **Regulatory Exposure:** Accounting firms operate under CFC (Conselho Federal de Contabilidade) regulations. Clients of those firms may request proof of who accessed their fiscal data and when.
- **Incident Investigation:** In case of data breach, unauthorized access, or operational dispute, the platform must provide a forensic trail of all sensitive actions.
- **Existing Architecture Constraints:** ADR-0001 mandates a modular monolith with Spring Modulith on a single VPS with zero cloud cost. ADR-0002 separates databases per bounded context. The audit solution must work within these constraints without adding external infrastructure.

The goal is to define **where, how, and what** is audited across the platform, balancing compliance requirements with operational simplicity and zero-cost infrastructure.

---

# 2. Decision Statement

The system will implement a custom `audit_log` table in the `saas_tenant` database with an application-layer `AuditPort` and an infrastructure-layer `AuditService` adapter. Sensitive actions across all bounded contexts will be audited through explicit port invocation in use cases and an optional `@Audited` AOP annotation. Audit records will capture the authenticated user, tenant, action type, affected resource, timestamp, client IP, and result.

---

# 3. Decision Drivers

1. **LGPD Compliance:** The platform must demonstrate accountability and traceability for all operations involving personal and fiscal data.
2. **Multi-Tenant Isolation:** Audit records must be tenant-scoped while allowing cross-tenant queries for platform super-administrators.
3. **Zero Cloud Cost (ADR-0001):** No external SIEM, cloud audit services, or paid infrastructure. The solution must run entirely on the existing PostgreSQL + VPS setup.
4. **Operational Simplicity:** Minimize operational overhead. Avoid introducing message brokers or external services solely for audit logging.
5. **Developer Ergonomics:** Reduce the risk of developers forgetting to audit new sensitive use cases through annotation-based automation.
6. **Forensic Capability:** Support incident investigation with queryable, indexed, structured audit data.
7. **Data Retention:** Define clear retention and anonymization policies aligned with LGPD's data minimization principle.
8. **Evolution Path:** Allow future integration with external SIEM or event streaming without changing the application-layer API.
9. **Cross-Context Visibility:** Actions in fiscal, certificate, billing, and WhatsApp contexts must flow into a centralized audit store.

---

# 4. Considered Options

## Option 1: Hibernate Envers (Entity Versioning)

**Description:** Use Hibernate Envers annotations (`@Audited`) on JPA entities to automatically track all entity state changes in revision tables.

**Pros:**
- Automatic entity versioning with minimal code
- Rich "before/after" state comparison
- Built into Hibernate — no additional infrastructure

**Cons:**
- Focuses on entity state changes, not user actions ("who did what")
- Does not naturally capture user identity, client IP, or business action semantics
- Generates high storage volume (full entity snapshots per revision)
- Not aligned with compliance queries like "who cancelled contracts last month?"
- Difficult to correlate across bounded contexts with separate databases

## Option 2: Custom `audit_log` Table with `AuditPort` (Selected)

**Description:** A dedicated `audit_log` table in the `saas_tenant` database. An `AuditPort` interface in the application layer is called explicitly from use cases (or via `@Audited` AOP annotation). The infrastructure adapter persists the audit record.

**Pros:**
- Full control over record format: user, tenant, action, resource, timestamp, IP, result
- Aligned with "user action" auditing rather than "entity state" tracking
- Simple SQL queries for compliance reports
- No external infrastructure required
- Supports cross-context auditing through Spring Modulith inter-module API
- `@Audited` annotation reduces risk of missing audit points

**Cons:**
- Developers must invoke AuditPort or annotate use cases — risk of forgetting
- Single database for all audit records may grow large over time

## Option 3: Event-Driven Audit via Kafka/RabbitMQ

**Description:** Publish audit events to a message broker. A consumer service persists the events to a database or forwards them to an external SIEM.

**Pros:**
- Decoupled audit recording from business transaction
- Scalable and extensible
- Natural path to external SIEM integration

**Cons:**
- Requires message broker infrastructure (violates zero-cost constraint in ADR-0001)
- Delivery guarantees add complexity (at-least-once, idempotency)
- Delay between action and audit record persistence
- Overkill for current scale (few tenants, single VPS)

## Option 4: Structured JSON Logs Only

**Description:** Log audit events as structured JSON to application logs. Use log aggregation tools (ELK, Loki) for querying.

**Pros:**
- Minimal code changes
- No additional database tables
- Natural integration with observability stack

**Cons:**
- Not a "source of truth" for compliance — logs can be lost, rotated, or corrupted
- Requires a log aggregation tool for querying (adds infrastructure cost)
- Not suitable for LGPD compliance proofs without additional process
- Difficult to implement retention policies or targetted anonymization

## Option 5: External SIEM/Audit Service

**Description:** Send audit events to an external compliance platform (Splunk, Datadog, AWS CloudTrail equivalent).

**Pros:**
- Enterprise-grade compliance tooling
- Built-in retention, search, and alerting
- SOC2/ISO 27001 ready

**Cons:**
- Paid service — violates zero cloud cost constraint (ADR-0001)
- External dependency for a core compliance function
- Network latency and availability concerns on a single VPS

---

# 5. Decision Outcome

**Option 2 (Custom `audit_log` table with `AuditPort`) was selected** for the following reasons:

1. **Action-Oriented Auditing:** Unlike Envers (entity-state focused), the custom table captures "who did what" — the core requirement for LGPD compliance and incident investigation.
2. **Zero Infrastructure Cost:** Uses the existing PostgreSQL database with no additional services, respecting ADR-0001.
3. **Cross-Context Centralization:** By placing `audit_log` in `saas_tenant` (the context that owns users and tenants), all bounded contexts can publish audit records to a single, queryable store via Spring Modulith's inter-module API.
4. **Developer Safety Net:** The `@Audited` annotation with AOP reduces the risk of missing audit points in new use cases, addressing the primary weakness of explicit invocation.
5. **Evolution Ready:** The `AuditPort` interface in the application layer means the infrastructure implementation can later publish events to Kafka or a SIEM without changing any use case code.

**Rejected alternatives:**
- Envers: Not aligned with "user action" auditing; excessive storage.
- Kafka: Violates zero-cost constraint; overkill for current scale.
- Logs only: Insufficient as compliance source of truth.
- External SIEM: Paid service, violates cost constraints.

---

# 6. Consequences

**Positive Consequences:**
- Full traceability of sensitive actions across all bounded contexts
- LGPD compliance foundation with queryable audit records
- Super-admin can investigate cross-tenant incidents via SQL queries
- Extensible to external SIEM in the future without application changes
- `@Audited` annotation creates a discoverable, auditable pattern across the codebase

**Negative Consequences:**
- Developers must remember to annotate or invoke AuditPort in new sensitive use cases
- `saas_tenant` database size increases over time with audit records
- Audit table insert adds minor latency (~1-2ms) to audited operations
- Cross-context audit calls via Spring Modulith add slight coupling to the tenant module

**Neutral Consequences:**
- Retention jobs must be implemented and maintained according to the canonical requirement for each data slice
- Audit records become part of LGPD data subject access requests
- New development checklist item: "Is this use case auditable?"

---

# 7. Impact

**Architecture:**
- New `AuditPort` interface in shared/domain layer as an outbound port
- New `AuditServiceAdapter` in `saas_tenant` infrastructure layer
- Spring Modulith inter-module API exposes audit capability to other contexts
- New `@Audited` annotation and AOP aspect in shared infrastructure

**Infrastructure:**
- New `audit_log` table in `saas_tenant` PostgreSQL database
- Flyway migration script for table creation with appropriate indexes
- Scheduled retention enforcement delegated to the canonical requirement for each data slice; for Conversation Audit, see [REQ-00043](../product/requirements/REQ-00043-conversation-audit-data-governance.md)

**Security:**
- Audit records capture authenticated user context from JWT claims
- Access to audit data restricted to ADMIN role (per-tenant) and SUPER_ADMIN (cross-tenant)
- Audit records never contain raw PII in the `details` field — only resource identifiers

**Development Process:**
- PR checklist updated: "Sensitive use case? Add `@Audited` annotation"
- Code review must verify audit coverage for new sensitive operations

**Data Architecture:**
- `audit_log` schema: `id` (UUID), `user_id` (UUID, nullable), `tenant_id` (UUID), `action` (VARCHAR), `resource_type` (VARCHAR), `resource_id` (UUID, nullable), `occurred_at` (TIMESTAMP WITH TIME ZONE), `client_ip` (VARCHAR, nullable), `result` (VARCHAR), `details` (JSONB, nullable)
- Indexes: `(tenant_id, occurred_at)`, `(user_id, occurred_at)`, `(action, occurred_at)`

**Observability:**
- Audit table metrics exposed via Spring Boot Actuator: record count, insertion rate
- Structured log emitted alongside audit record for observability stack correlation

---

# 8. AI Agent Considerations (For Autonomous Agent Environments)

**Agent Roles Impacted:**

| Agent | Impact |
|-------|--------|
| @ImplementerCore | Must implement `AuditPort` interface and ensure all sensitive use cases invoke it or carry `@Audited` annotation |
| @AdapterDev | Must implement `AuditServiceAdapter` (JPA persistence), Flyway migration, and `@Audited` AOP aspect |
| @TestAutomator | Must write tests verifying audit record creation for every auditable action |
| @CodeGuardian | Must audit codebase for missing `@Audited` annotations on sensitive use cases |
| @ComplianceAgent | Must verify LGPD compliance of audit records, retention policy, and anonymization |
| @SecurityOAuth | Must ensure JWT authenticated user context is propagated to `AuditPort` |
| @ModulithConfig | Must configure inter-module API for audit access from other bounded contexts |
| @DevOps-Agent | Must integrate retention job into Docker Compose and CI/CD pipeline |

**Operational Considerations:**
- `AuditPort` is a cross-cutting concern exposed via Spring Modulith's public module API
- Audit recording happens synchronously within the same transaction as the business operation
- The `@Audited` AOP aspect intercepts at the use case layer, not the controller layer
- Human oversight: super-admin audit dashboard for cross-tenant investigation

**Safety Considerations:**
- Audit records are append-only for ordinary application writers; only a narrowly scoped, policy-governed retention process may delete the exact eligible slice
- Retention and erasure rules are not defined by this Proposed ADR. Conversation Audit uses [REQ-00043](../product/requirements/REQ-00043-conversation-audit-data-governance.md); other `audit_log` domains require their own approved policy
- Audit data access requires explicit authorization (ADMIN or SUPER_ADMIN)

---

# 9. Implementation Plan

## Phase 1 — Foundation (Sprint 1)

**Responsible:** @ImplementerCore, @AdapterDev

1. Create `AuditPort` interface in shared domain layer:
   ```java
   public interface AuditPort {
       void record(AuditEntry entry);
   }
   ```
2. Create `AuditEntry` domain record:
   ```java
   public record AuditEntry(
       UUID userId,
       UUID tenantId,
       String action,
       String resourceType,
       UUID resourceId,
       String clientIp,
       AuditResult result,
       Map<String, Object> details
   ) {}
   ```
3. Create `audit_log` table via Flyway migration in `saas_tenant` database
4. Implement `JpaAuditServiceAdapter` persisting `AuditEntry` to `audit_log`
5. Create `@Audited` annotation and AOP aspect

## Phase 2 — Pilot Integration (Sprint 1-2)

**Responsible:** @ImplementerCore

Integrate audit recording in 5 pilot use cases:
1. `CreateTenantUseCase` — action: `tenant:create`
2. `CreateUserUseCase` — action: `user:create`
3. `UploadCertificateUseCase` — action: `certificate:upload`
4. `RevokeCertificateUseCase` — action: `certificate:revoke`
5. `ConsultarSituacaoFiscalUseCase` — action: `fiscal:query`

## Phase 3 — Full Coverage (Sprint 2-3)

**Responsible:** @ImplementerCore, @CodeGuardian

Extend audit coverage to all sensitive actions:
- User CRUD operations
- Tenant suspension/activation
- Billing plan changes
- WhatsApp bot authorization changes
- Certificate renewal/deletion
- Fiscal batch queries

@CodeGuardian performs audit coverage analysis to identify missing `@Audited` annotations.

## Phase 4 — Retention and Compliance (Sprint 3)

**Responsible:** @AdapterDev, @ComplianceAgent

1. Implement bounded retention jobs from the approved policy for the affected data slice; do not apply a global `audit_log` cutoff by inference
2. Implement the approved erasure/anonymization technique and document residual re-identification risk; UUID, hash, HMAC or orphaning alone are pseudonymization, not proof of anonymization
3. Implement audit query API for tenant administrators
4. Document LGPD compliance procedures

---

# 10. Validation

**Architecture Review:**
- `AuditPort` interface exists in shared domain layer with no infrastructure dependencies
- `JpaAuditServiceAdapter` exists in `saas_tenant` infrastructure layer
- Spring Modulith module verification passes with audit as a public API of tenant module

**Functional Validation:**
- Every auditable action creates exactly one `audit_log` record
- Audit record contains correct `user_id`, `tenant_id`, `action`, and `resource_id`
- Cross-context audit works: fiscal query in `saas_fiscal` database produces audit record in `saas_tenant`
- `@Audited` AOP aspect correctly intercepts annotated use cases

**Compliance Validation:**
- LGPD erasure follows the approved data-slice policy and records its verification evidence without PII
- Retention jobs use explicit, versioned cutoffs, bounded batches and exact allowlists; missing or stale policy performs zero deletion
- Audit query API enforces tenant isolation (tenant admin sees only their tenant's records)
- Super-admin can query across all tenants

**Success Criteria:**
- 100% of defined sensitive actions produce audit records
- Audit record insertion latency < 5ms (p95)
- Retention job completes within 1 minute for up to 1 million records
- Zero audit records contain raw PII in the `details` field

---

# 11. Risks and Mitigations

## Risk 1: Missing Audit Coverage in New Use Cases

**Description:** Developers create new sensitive use cases without adding `@Audited` annotation or `AuditPort` invocation.

**Mitigation:**
- `@Audited` annotation with AOP reduces boilerplate and makes audit intent declarative
- PR checklist includes "Is this a sensitive action? Add `@Audited`"
- @CodeGuardian performs periodic audit coverage analysis
- Maintain a canonical list of auditable actions in this ADR (Section 9, Phase 3)

## Risk 2: Audit Table Growth

**Description:** High-volume actions (e.g., fiscal queries) may cause the `audit_log` table to grow rapidly, impacting database performance.

**Mitigation:**
- Appropriate indexes on `(tenant_id, occurred_at)`, `(user_id, occurred_at)`, `(action, occurred_at)`
- Data-slice retention periods and purge behavior come only from an approved requirement; Conversation Audit is governed by [REQ-00043](../product/requirements/REQ-00043-conversation-audit-data-governance.md)
- Table partitioning by `occurred_at` (monthly) when volume exceeds 10 million records
- Monitoring via Spring Boot Actuator metrics

## Risk 3: LGPD Right to Erasure Conflict

**Description:** A user requests data erasure under LGPD, but audit records reference their `user_id`. Deleting audit records would destroy compliance evidence.

**Mitigation:**
- Distinguish suppression, deletion, pseudonymization and risk-based anonymization; do not call an orphan UUID or stable keyed hash anonymous
- Apply the approved data-slice policy, legal hold and legal-basis review before erasure; Conversation Audit uses [REQ-00043](../product/requirements/REQ-00043-conversation-audit-data-governance.md)
- Preserve only aggregates whose re-identification risk has been assessed and documented; otherwise delete the personal-data graph at the cutoff

## Risk 4: Cross-Context Coupling

**Description:** All bounded contexts depend on the tenant module's `AuditPort`, creating coupling.

**Mitigation:**
- `AuditPort` is a minimal interface (single method) exposed via Spring Modulith public API
- Other contexts depend on the port interface, not the implementation
- When extracting to microservices, `AuditPort` becomes an HTTP/gRPC client adapter — no domain code change

## Risk 5: Transaction Failure Due to Audit

**Description:** If the audit record insertion fails, the entire business transaction rolls back.

**Mitigation:**
- Audit insertion is a simple INSERT with minimal failure surface
- Consider `@Transactional(propagation = REQUIRES_NEW)` for audit if business transaction integrity is prioritized over audit completeness
- Monitor audit insertion failure rate via metrics

---

# 12. Related ADRs

- [ADR-0001 - Technology Stack and Architecture Foundation](ADR-0001-technology-stack-and-architecture.md) — Defines zero-cost infrastructure constraint and Spring Modulith framework
- [ADR-0002 - Database Separation per Bounded Context](ADR-0002-separacao-banco-por-contexto-multitenancy.md) — Defines `saas_tenant` as the database hosting the `audit_log` table
- [ADR-0003 - Multi-Tenancy Strategy: tenant_id](ADR-0003-multitenancy-schema-vs-tenant-id.md) — Defines row-level isolation that audit records must respect
- [ADR-0005 - Multi-Tenancy Architecture](ADR-0005-multi-tenancy-architecture.md) — Defines the overall multi-tenancy architecture including user/tenant management

---

# 13. References

- External legacy reference `0010-abordagem-auditoria.md` — historical external inspiration; the referenced artifact is not present in this repository.
- [LGPD - Lei 13.709/2018](http://www.planalto.gov.br/ccivil_03/_ato2015-2018/2018/lei/l13709.htm) — Brazilian General Data Protection Law
- [Spring Modulith Documentation](https://docs.spring.io/spring-modulith/reference/) — Module public API and inter-module communication
- [OWASP Logging Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Logging_Cheat_Sheet.html) — Security logging best practices
- [CFC - Conselho Federal de Contabilidade](https://cfc.org.br/) — Accounting profession regulations

---

# 14. Decision Lifecycle

Current State: **Proposed**

This ADR has been created and is under review. Upon acceptance, it becomes the governing document for the audit and compliance mechanism across all bounded contexts. Any changes to the audit strategy (e.g., migration to event-driven audit via Kafka) require a new ADR that supersedes this one.

---

# 15. Change Log

Version: 1.1
Date: 2026-08-23
Author: Codex / @ComplianceAgent
Changes:
- Removed the unsupported fixed two-year retention and orphan-UUID anonymization claims.
- Delegated Conversation Audit retention, erasure, receipts and performance governance to REQ-00043.
- Clarified that append-only applies to ordinary writers and that only an exact, governed purge may delete records.

---

Version: 1.0
Date: 2026-03-09
Author: @AgentOrchestrator, @ComplianceAgent
Changes:
- Initial ADR creation
- Defined custom `audit_log` table approach with `AuditPort` and `@Audited` annotation
- Defined LGPD anonymization and retention policies
- Defined 4-phase implementation plan

---

# 16. Repository Structure

```
docs/
  adrs/
    ADR-0001-technology-stack-and-architecture.md
    ADR-0002-separacao-banco-por-contexto-multitenancy.md
    ADR-0003-multitenancy-schema-vs-tenant-id.md
    ADR-0004-whatsapp-integration-architecture.md
    ADR-0005-multi-tenancy-architecture.md
    ADR-0006-audit-compliance.md          ← This ADR
```

---

# 17. Review Process

1. This ADR was created in "Proposed" status by @AgentOrchestrator and @ComplianceAgent.
2. Reviewers (@CleanArchitecture, @SecurityOAuth, @ImplementerCore, @AdapterDev) must validate:
   - Audit table schema completeness for LGPD compliance
   - `AuditPort` placement in Clean Architecture layers
   - `@Audited` AOP strategy alignment with Spring Modulith module boundaries
   - Cross-context audit flow feasibility via inter-module API
3. @ComplianceAgent must review the approved data-slice requirement, re-identification risk and retention evidence; this Proposed ADR does not itself choose retention periods.
4. The startup founders must confirm that the audit granularity is sufficient for their compliance posture.
5. Upon approval, the status changes to "Accepted" and the ADR becomes immutable.

---

# 18. Notes

## Auditable Actions Catalog

The following actions must be audited across all bounded contexts:

| Context | Action Code | Description | Resource Type |
|---------|------------|-------------|---------------|
| Tenant | `tenant:create` | New accounting firm registered | Tenant |
| Tenant | `tenant:suspend` | Tenant suspended | Tenant |
| Tenant | `tenant:activate` | Tenant reactivated | Tenant |
| Tenant | `user:create` | New user created within tenant | User |
| Tenant | `user:update` | User profile or role modified | User |
| Tenant | `user:delete` | User removed from tenant | User |
| Certificate | `certificate:upload` | Digital certificate uploaded | Certificate |
| Certificate | `certificate:renew` | Certificate renewed | Certificate |
| Certificate | `certificate:revoke` | Certificate revoked | Certificate |
| Certificate | `certificate:access` | Certificate private key accessed | Certificate |
| Fiscal | `fiscal:query` | Fiscal situation queried via SERPRO | ConsultaFiscal |
| Fiscal | `fiscal:batch_query` | Batch fiscal query executed | ConsultaFiscal |
| Billing | `billing:plan_change` | Subscription plan changed | Subscription |
| Billing | `billing:credit_deduct` | Credits deducted for service usage | CreditBalance |
| Billing | `billing:invoice_generate` | Invoice generated | Invoice |
| WhatsApp | `whatsapp:authorize_contact` | Contact authorized for bot | ContatoAutorizado |
| WhatsApp | `whatsapp:revoke_contact` | Contact authorization revoked | ContatoAutorizado |

## `audit_log` Table DDL

```sql
CREATE TABLE audit_log (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         UUID,
    tenant_id       UUID NOT NULL,
    action          VARCHAR(100) NOT NULL,
    resource_type   VARCHAR(100) NOT NULL,
    resource_id     UUID,
    occurred_at     TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    client_ip       VARCHAR(45),
    result          VARCHAR(20) NOT NULL DEFAULT 'SUCCESS',
    details         JSONB,
    
    CONSTRAINT chk_result CHECK (result IN ('SUCCESS', 'FAILURE', 'DENIED'))
);

CREATE INDEX idx_audit_log_tenant_occurred ON audit_log (tenant_id, occurred_at DESC);
CREATE INDEX idx_audit_log_user_occurred ON audit_log (user_id, occurred_at DESC);
CREATE INDEX idx_audit_log_action_occurred ON audit_log (action, occurred_at DESC);
CREATE INDEX idx_audit_log_resource ON audit_log (resource_type, resource_id);
```

## `AuditPort` Interface

```java
package com.duoset.saas.shared.domain.port.out;

/**
 * Outbound port for recording audit entries.
 * 
 * <p>Implementations reside in the infrastructure layer of the tenant module.
 * Other bounded contexts access this port via Spring Modulith's inter-module API.
 */
public interface AuditPort {
    void record(AuditEntry entry);
}
```

## `@Audited` Annotation

```java
package com.duoset.saas.shared.application.annotation;

import java.lang.annotation.*;

/**
 * Marks a use case method as auditable.
 * The AOP aspect will automatically record an audit entry after method execution.
 *
 * @see AuditAspect
 */
@Target(ElementType.METHOD)
@Retention(RetentionPolicy.RUNTIME)
@Documented
public @interface Audited {
    String action();
    String resourceType();
}
```
