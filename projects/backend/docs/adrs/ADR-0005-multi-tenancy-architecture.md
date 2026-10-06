---
document_id: "ADR-0005"
primary_nature: "Decisao"
objective: "Registrar a decisão arquitetural “Multi-Tenancy Architecture”, seus motivadores, alternativas e consequências."
scope: "Decisão, componentes, integrações e limites explicitamente descritos em “Multi-Tenancy Architecture”."
non_objectives: "Não implementar a decisão, substituir requisitos relacionados nem atestar capabilities ou ambientes sem evidência explícita."
owner: "@AgentOrchestrator, @MultiTenantEng"
status: "Accepted"
date: "2026-03-08"
version: "1.1"
keywords: "adr, decisao, arquitetura, multi, tenancy, architecture"
related_files: "docs/adrs/README.md, docs/adrs/ADR-0001-technology-stack-and-architecture.md, docs/adrs/ADR-0002-separacao-banco-por-contexto-multitenancy.md, docs/adrs/ADR-0003-multitenancy-schema-vs-tenant-id.md, docs/adrs/ADR-0004-whatsapp-integration-architecture.md, docs/product/business/product-vision.md, docs/agents/README.md"
code_references: "TenantContext, @Filter, TenantContextFilter, TenantAwareEntity, @Entity"
principal_statement: "The system will implement a **three-level multi-tenancy architecture**: (1) Authentication isolation via Keycloak realms per tenant, (2) Application-level isolation via `TenantContext` (ThreadLocal) set by an HTTP filter from the JWT `tenant_id` claim, and (3) Database-level isolation via `tenant_id` column in every table with Hibernate `@Filter` enforcement. Each bounded context has its own PostgreSQL database with a single `public` schema."
---

# ADR-0005 - Multi-Tenancy Architecture

- Date: 2026-03-08
- Status: Accepted
- Version: 1.1
- Authors / Owners: @AgentOrchestrator, @MultiTenantEng
- Reviewers: @CleanArchitecture, @DomainExpert, @DevOps-Agent, @SecurityOAuth
- Stakeholders: Engineering Team, Product Owner, Startup Founders

---

# 1. Context

The Hub Contabil Inteligente is a multi-tenant micro-SaaS platform serving accounting firms. Each accounting firm (tenant) must have complete data isolation — clients, digital certificates, fiscal queries, billing records, and WhatsApp interaction logs must never be visible across tenants.

Business requirements:

- Three user profiles interact with the system: SaaS Administrator, Accounting Firm (Subscriber/Tenant), and End Client (Entrepreneur via WhatsApp).
- Three subscription plans: Start (up to 3 firms), Business (up to 50 firms), Premium (unlimited firms).
- LGPD compliance requires auditable tenant isolation, data erasure per tenant, and consent management.
- Security: WhatsApp number validation against registered Documentos per tenant, encrypted digital certificate storage per tenant, full audit logging of all interactions.
- Zero cloud cost: all infrastructure on a single VPS with Docker Compose.

Related architectural decisions:

- [ADR-0001](./ADR-0001-technology-stack-and-architecture.md) established Java 21, Spring Boot 4.x, Spring Modulith, PostgreSQL, and Clean Architecture.
- [ADR-0002](./ADR-0002-separacao-banco-por-contexto-multitenancy.md) established one database per bounded context and `tenant_id` discriminator.
- [ADR-0003](./ADR-0003-multitenancy-schema-vs-tenant-id.md) analyzed schema-per-tenant vs. `tenant_id` and chose `tenant_id` row-level isolation.

This ADR defines the **complete multi-tenancy architecture**: isolation levels, authentication flow, tenant context management, data layer configuration, and component design for the SaaS project.

---

# 2. Decision Statement

The system will implement a **three-level multi-tenancy architecture**: (1) Authentication isolation via Keycloak realms per tenant, (2) Application-level isolation via `TenantContext` (ThreadLocal) set by an HTTP filter from the JWT `tenant_id` claim, and (3) Database-level isolation via `tenant_id` column in every table with Hibernate `@Filter` enforcement. Each bounded context has its own PostgreSQL database with a single `public` schema.

---

# 3. Decision Drivers

- **Defense in depth:** Three isolation levels (authentication, application, database) ensure that a failure at one level does not expose cross-tenant data.
- **Scalability:** Row-level isolation (`tenant_id`) scales from 3 to unlimited tenants without DDL changes (as decided in ADR-0002 and ADR-0003).
- **Clean Architecture alignment:** Tenant context is a cross-cutting concern managed at the infrastructure layer — domain logic is unaware of multi-tenancy mechanics.
- **Spring Modulith compatibility:** `TenantContext` is shared infrastructure accessible by all modules without creating cross-module dependencies.
- **OAuth2 integration:** Keycloak provides tenant-scoped authentication with realm-per-tenant isolation, JWT claims include `tenant_id` for downstream use.
- **LGPD compliance:** Auditable isolation at every level — authentication (realm), application (context filter), database (`tenant_id` column).
- **Operational simplicity:** Single schema per database, single Flyway migration set per context, no schema management per tenant.
- **VPS resource efficiency:** No per-tenant schema metadata overhead. One connection pool per bounded context database.

---

# 4. Considered Options

## Option 1: Three-Level Isolation (Authentication + Application + Database) — Selected

Description: Keycloak realm per tenant for authentication. `TenantContextFilter` extracts `tenant_id` from JWT and sets ThreadLocal. Hibernate `@Filter` enforces row-level isolation at the ORM level. Every table has `tenant_id UUID NOT NULL`.

Pros:
- Defense in depth: three independent isolation barriers
- Any single layer failure does not expose data (e.g., missing filter is caught by Hibernate `@Filter`)
- Clean separation of concerns: security layer handles authentication, application layer handles context, data layer handles filtering
- Framework-level enforcement via Hibernate — not dependent on developer discipline

Cons:
- Three layers to maintain and test
- Keycloak realm-per-tenant adds Keycloak management overhead
- `TenantContext` ThreadLocal requires careful lifecycle management

## Option 2: Application + Database Only (No Per-Tenant Realm)

Description: Single Keycloak realm for all tenants. Tenant determined by JWT custom claim. Application filter + Hibernate `@Filter` for isolation.

Pros:
- Simpler Keycloak management (single realm)
- Fewer moving parts

Cons:
- No authentication-level isolation — all tenants share the same realm
- User email collisions across tenants if not carefully managed
- Less defense in depth

## Option 3: Database-Only Isolation

Description: Single Keycloak realm, no application-level filter. Rely entirely on `tenant_id` in queries.

Pros:
- Simplest implementation

Cons:
- No defense in depth — a single query without `tenant_id` exposes all data
- No clear tenant context for logging, auditing, or metrics
- Not suitable for a security-critical SaaS handling fiscal data and digital certificates

---

# 5. Decision Outcome

**Option 1 (Three-Level Isolation)** was selected.

Key factors:

- **Security requirements:** The system handles digital certificates, taxpayer data (Documentos), and fiscal query results. Defense in depth is mandatory for LGPD compliance.
- **Auditability:** Each isolation level produces its own audit trail — Keycloak logs realm access, `TenantContextFilter` logs tenant resolution, database ensures row-level isolation.
- **Independent failure modes:** Even if a developer forgets to check tenant context in business logic, Hibernate `@Filter` prevents cross-tenant data exposure at the ORM level.
- **Keycloak realm-per-tenant:** Provides user namespace isolation (the same email can exist in different tenants), role customization per tenant, and SSO configuration per tenant.

Tradeoffs accepted:

- Keycloak realm management complexity. Mitigated by: automated realm provisioning via Keycloak Admin API during tenant onboarding.
- ThreadLocal lifecycle management. Mitigated by: `TenantContextFilter` clears context in `finally` block; integration tests verify cleanup.
- Three layers to test. Mitigated by: @TestAutomator writes isolation tests for each level independently and combined.

---

# 6. Consequences

Positive Consequences:

- Three independent isolation barriers — cross-tenant data exposure requires simultaneous failure at all three levels.
- Clean separation: authentication (Keycloak), application (`TenantContext`), database (Hibernate `@Filter`).
- Auditable at every level: Keycloak audit log, application MDC logging with `tenantId`, database `tenant_id` column.
- Tenant-specific performance and billing are investigated through protected logs/traces and
  domain ledgers; ADR-0012 v1.2 prohibits tenant identity in metric labels.
- LGPD compliance: data erasure is `DELETE WHERE tenant_id = ?` across all tables.

Negative Consequences:

- Keycloak realm-per-tenant requires automation for tenant onboarding (realm creation, client configuration, role setup).
- Three isolation layers to maintain, test, and debug.
- `TenantContext` ThreadLocal requires careful cleanup to prevent cross-request tenant leakage.

Neutral Consequences:

- New tenant onboarding becomes a multi-step process: create Keycloak realm → register tenant in `saas_tenant` database → tenant is active.
- All integration tests must run in a multi-tenant context to validate isolation.

---

# 7. Impact

- **Architecture:** Multi-tenancy is a cross-cutting infrastructure concern. `TenantContext` is shared infrastructure. Domain layer is unaware of multi-tenancy mechanics. Adapters use `TenantAwareEntity` base class.
- **Infrastructure:** Keycloak with realm-per-tenant (Docker Compose). PostgreSQL with `tenant_id` in every table across 5 databases.
- **Security:** Three isolation levels. JWT validation + tenant context extraction + Hibernate filter. No single point of failure for tenant isolation.
- **Development Process:** Every entity extends `TenantAwareEntity`. Every request is automatically tenant-scoped. Developers never filter by `tenant_id` manually — Hibernate handles it.
- **Deployment Pipeline:** Keycloak realm creation automated via Keycloak Admin REST API. Database migrations include `tenant_id` column in every table.
- **Data Architecture:** Every table: `tenant_id UUID NOT NULL` with index. Cross-tenant queries impossible at ORM level.
- **Observability:** MDC is populated with `tenantId`, `userId`, `requestId`; metrics use only
  bounded allowlisted dimensions. Per-tenant dashboards query protected logs/traces or ledgers.
- **DevOps:** Docker Compose includes Keycloak service with pre-configured master realm. Init script creates 5 databases.
- **AI Agent Orchestration:** @MultiTenantEng owns the entire multi-tenancy stack. @SecurityOAuth owns Keycloak configuration. All agents must generate tenant-aware code.

---

# 8. AI Agent Considerations (For Autonomous Agent Environments)

Agent Roles Impacted:

- **@MultiTenantEng:** Implements the complete multi-tenancy stack: `TenantContext`, `TenantContextFilter`, `TenantAwareEntity`, `TenantHibernateInterceptor`, tenant onboarding service.
- **@SecurityOAuth:** Configures Keycloak realm-per-tenant, JWT validation, `tenant_id` claim extraction. Implements Keycloak Admin API client for automated realm provisioning.
- **@CleanArchitecture:** Validates that multi-tenancy is infrastructure-only — domain layer must not import `TenantContext` or `TenantAwareEntity` directly.
- **@AdapterDev:** Implements JPA repositories using correct `TransactionManager` per context. Entities extend `TenantAwareEntity`.
- **@ImplementerCore:** Implements use cases. Use cases receive `tenantId` as part of the command/query DTO — they do not access `TenantContext` directly.
- **@TestAutomator:** Writes three-level isolation tests: (1) Keycloak realm isolation, (2) TenantContext filter isolation, (3) Hibernate @Filter database isolation.
- **@CodeGuardian:** Reviews every PR for: entity extends `TenantAwareEntity`, migration includes `tenant_id`, no raw SQL bypassing Hibernate filter.
- **@ObservabilityDev:** Configures MDC/trace fields with `tenantId` for controlled correlation and
  keeps metric labels identity-free according to ADR-0012 v1.2.
- **@ComplianceAgent:** Audits that all PII tables have `tenant_id` and that LGPD erasure workflows use `tenant_id`.

Operational Considerations:

- Domain layer must never directly depend on `TenantContext`. Tenant information is passed via command/query DTOs.
- Use cases receive `tenantId` as an input port parameter, not from ThreadLocal.
- Only infrastructure adapters (filters, interceptors, repositories) interact with `TenantContext`.
- No agent may disable Hibernate `@Filter` without @MultiTenantEng and @SecurityOAuth approval.

LLM Considerations:

- Entity generation prompts must include `TenantAwareEntity` as the base class.
- Use case prompts must include `tenantId` as a command/query parameter.
- Repository prompts must not include explicit `tenant_id` in finder methods — Hibernate `@Filter` handles it automatically.
- Migration prompts must include `tenant_id UUID NOT NULL` with index.

Safety Considerations:

- `TenantContext.clear()` must be called in the `finally` block of every filter — tenant leakage is a critical security vulnerability.
- Native SQL queries (`@Query(nativeQuery = true)`) must include `WHERE tenant_id = :tenantId` manually.
- Keycloak realm creation must validate tenant uniqueness to prevent realm name collisions.
- Digital certificate operations require both `tenant_id` isolation AND role `TENANT_ADMIN` — double-gated security.

---

# 9. Implementation Plan

## Phase 1 — Multi-Tenancy Foundation (Sprint 1-2)

### Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    MULTI-TENANCY ARCHITECTURE                          │
│                                                                        │
│  ┌────────────────┐  ┌────────────────┐  ┌────────────────┐           │
│  │   Tenant A     │  │   Tenant B     │  │   Tenant C     │           │
│  │ (Escritório A) │  │ (Escritório B) │  │ (Escritório C) │           │
│  └───────┬────────┘  └───────┬────────┘  └───────┬────────┘           │
│          │ JWT (tenant_id)   │ JWT (tenant_id)   │ JWT (tenant_id)    │
│          ▼                   ▼                   ▼                    │
│  ┌────────────────────────────────────────────────────────────────┐   │
│  │                   LEVEL 1: Authentication                      │   │
│  │                         Keycloak                               │   │
│  │  Realm: tenant-a  │  Realm: tenant-b  │  Realm: tenant-c     │   │
│  │  Users isolated    │  Users isolated    │  Users isolated      │   │
│  │  JWT: tenant_id=A  │  JWT: tenant_id=B  │  JWT: tenant_id=C   │   │
│  └──────────────────────────────┬─────────────────────────────────┘   │
│                                 ▼                                     │
│  ┌────────────────────────────────────────────────────────────────┐   │
│  │                   LEVEL 2: Application                         │   │
│  │                    TenantContextFilter                         │   │
│  │  1. Extract tenant_id from JWT claim                          │   │
│  │  2. Validate tenant is ACTIVE                                 │   │
│  │  3. Set TenantContext.setCurrentTenantId(tenantId)            │   │
│  │  4. Populate MDC: tenantId, userId, requestId                 │   │
│  │  5. Clear TenantContext in finally block                      │   │
│  └──────────────────────────────┬─────────────────────────────────┘   │
│                                 ▼                                     │
│  ┌────────────────────────────────────────────────────────────────┐   │
│  │                   LEVEL 3: Database                            │   │
│  │                   Hibernate @Filter                            │   │
│  │  • Every entity extends TenantAwareEntity                     │   │
│  │  • @Filter("tenantFilter", condition="tenant_id = :tenantId") │   │
│  │  • Filter activated on every Session open                     │   │
│  │  • All JPQL/Criteria queries automatically filtered            │   │
│  └──────────────────────────────┬─────────────────────────────────┘   │
│                                 ▼                                     │
│  ┌────────────────────────────────────────────────────────────────┐   │
│  │                     PostgreSQL                                 │   │
│  │  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌─────────┐ ┌──────┐│   │
│  │  │saas_     │ │saas_     │ │saas_     │ │saas_    │ │saas_ ││   │
│  │  │tenant    │ │certific. │ │fiscal    │ │billing  │ │whats.││   │
│  │  │          │ │          │ │          │ │         │ │      ││   │
│  │  │tenant_id │ │tenant_id │ │tenant_id │ │tenant_id│ │t._id ││   │
│  │  │in every  │ │in every  │ │in every  │ │in every │ │in    ││   │
│  │  │table     │ │table     │ │table     │ │table    │ │every ││   │
│  │  └──────────┘ └──────────┘ └──────────┘ └─────────┘ └──────┘│   │
│  └────────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────────┘
```

### Implementation Tasks

1. **Keycloak setup (Docker Compose):** Keycloak service with master realm. Tenant realm auto-provisioning via Admin API.

2. **`TenantContext` (ThreadLocal):**
   ```java
   public class TenantContext {
       private static final ThreadLocal<UUID> current = new ThreadLocal<>();
       public static UUID getCurrentTenantId() { return current.get(); }
       public static void setCurrentTenantId(UUID id) { current.set(id); }
       public static void clear() { current.remove(); }
   }
   ```

3. **`TenantContextFilter` (HTTP Filter):**
   ```java
   @Component
   @Order(Ordered.HIGHEST_PRECEDENCE + 10)
   public class TenantContextFilter extends OncePerRequestFilter {
       @Override
       protected void doFilterInternal(HttpServletRequest request,
               HttpServletResponse response, FilterChain chain)
               throws ServletException, IOException {
           try {
               UUID tenantId = extractTenantIdFromJwt(request);
               if (tenantId != null) {
                   validateTenantIsActive(tenantId);
                   TenantContext.setCurrentTenantId(tenantId);
                   MDC.put("tenantId", tenantId.toString());
               }
               chain.doFilter(request, response);
           } finally {
               TenantContext.clear();
               MDC.remove("tenantId");
           }
       }
   }
   ```

4. **`TenantAwareEntity` (Base class):**
   ```java
   @MappedSuperclass
   @FilterDef(name = "tenantFilter",
       parameters = @ParamDef(name = "tenantId", type = UUID.class))
   @Filter(name = "tenantFilter", condition = "tenant_id = :tenantId")
   public abstract class TenantAwareEntity {
       @Column(name = "tenant_id", nullable = false, updatable = false)
       private UUID tenantId;
   }
   ```

5. **`TenantHibernateInterceptor`:** Activates `@Filter("tenantFilter")` on every `Session` open, setting `:tenantId` from `TenantContext`.

6. **Tenant onboarding service:** Creates Keycloak realm → registers tenant in `saas_tenant` database → returns tenant credentials.

### Authentication Flow

```
┌─────────┐      ┌──────────┐      ┌───────────┐      ┌───────────┐
│  Client  │      │ Keycloak │      │SaaS Service│      │ PostgreSQL│
└────┬─────┘      └────┬─────┘      └─────┬─────┘      └─────┬─────┘
     │                 │                   │                   │
     │ 1. Login        │                   │                   │
     │ (realm=tenant)  │                   │                   │
     │────────────────>│                   │                   │
     │                 │                   │                   │
     │ 2. JWT Token    │                   │                   │
     │ (tenant_id=uuid)│                   │                   │
     │<────────────────│                   │                   │
     │                 │                   │                   │
     │ 3. API Request  │                   │                   │
     │ Bearer {jwt}    │                   │                   │
     │────────────────────────────────────>│                   │
     │                 │                   │                   │
     │                 │ 4. Validate JWT   │                   │
     │                 │<──────────────────│                   │
     │                 │──────────────────>│                   │
     │                 │                   │                   │
     │                 │                   │ 5. Extract        │
     │                 │                   │    tenant_id      │
     │                 │                   │    from JWT       │
     │                 │                   │                   │
     │                 │                   │ 6. Validate       │
     │                 │                   │    tenant active  │
     │                 │                   │──────────────────>│
     │                 │                   │<──────────────────│
     │                 │                   │                   │
     │                 │                   │ 7. Set            │
     │                 │                   │    TenantContext   │
     │                 │                   │                   │
     │                 │                   │ 8. Activate       │
     │                 │                   │    Hibernate      │
     │                 │                   │    @Filter        │
     │                 │                   │                   │
     │                 │                   │ 9. Execute query  │
     │                 │                   │    (filtered by   │
     │                 │                   │     tenant_id)    │
     │                 │                   │──────────────────>│
     │                 │                   │<──────────────────│
     │                 │                   │                   │
     │ 10. Response    │                   │                   │
     │<────────────────────────────────────│                   │
```

### JWT Token Structure

```json
{
  "iss": "http://keycloak:8080/realms/tenant-escritorio-a",
  "sub": "user-uuid",
  "aud": "saas-service-api",
  "tenant_id": "550e8400-e29b-41d4-a716-446655440000",
  "exp": 1773100000,
  "iat": 1773096400,
  "realm_access": {
    "roles": ["ROLE_TENANT_ADMIN"]
  },
  "email": "admin@escritorioa.com.br",
  "name": "Admin User"
}
```

### Application Configuration

```yaml
# application.yml

# Multi-tenancy configuration
app:
  multitenancy:
    enabled: true

  datasource:
    tenant:
      url: jdbc:postgresql://${DB_HOST:localhost}:5432/saas_tenant
      username: ${DB_USER:saas_app}
      password: ${DB_PASSWORD}
    certificate:
      url: jdbc:postgresql://${DB_HOST:localhost}:5432/saas_certificate
      username: ${DB_USER:saas_app}
      password: ${DB_PASSWORD}
    fiscal:
      url: jdbc:postgresql://${DB_HOST:localhost}:5432/saas_fiscal
      username: ${DB_USER:saas_app}
      password: ${DB_PASSWORD}
    billing:
      url: jdbc:postgresql://${DB_HOST:localhost}:5432/saas_billing
      username: ${DB_USER:saas_app}
      password: ${DB_PASSWORD}
    whatsapp:
      url: jdbc:postgresql://${DB_HOST:localhost}:5432/saas_whatsapp
      username: ${DB_USER:saas_app}
      password: ${DB_PASSWORD}

# Keycloak configuration
spring:
  security:
    oauth2:
      resourceserver:
        jwt:
          issuer-uri: ${KEYCLOAK_URL:http://localhost:8180}/realms/master
          jwk-set-uri: ${KEYCLOAK_URL:http://localhost:8180}/realms/master/protocol/openid-connect/certs
```

### Docker Compose

```yaml
services:
  postgres:
    image: postgres:17-alpine
    environment:
      POSTGRES_USER: saas_app
      POSTGRES_PASSWORD: ${DB_PASSWORD:-saas_dev_123}
    volumes:
      - postgres_data:/var/lib/postgresql/data
      - ./docker/postgres/init:/docker-entrypoint-initdb.d
    ports:
      - "5432:5432"

  keycloak:
    image: quay.io/keycloak/keycloak:26.0
    environment:
      KEYCLOAK_ADMIN: admin
      KEYCLOAK_ADMIN_PASSWORD: ${KEYCLOAK_PASSWORD:-admin}
    command: start-dev
    ports:
      - "8180:8080"

volumes:
  postgres_data:
```

### Database Init Script

```sql
-- docker/postgres/init/01-create-databases.sql

CREATE DATABASE saas_tenant;
CREATE DATABASE saas_certificate;
CREATE DATABASE saas_fiscal;
CREATE DATABASE saas_billing;
CREATE DATABASE saas_whatsapp;
```

Responsible agents: @MultiTenantEng, @SecurityOAuth, @DevOps-Agent, @TestAutomator

Dependencies: ADR-0001, ADR-0002, ADR-0003.

Rollback plan: Multi-tenancy components can be disabled via `app.multitenancy.enabled=false` for single-tenant development mode.

---

# 10. Validation

Architecture Validation:

- ArchUnit test: every `@Entity` extends `TenantAwareEntity`.
- ArchUnit test: domain layer does not import `TenantContext`.
- Spring Modulith `ApplicationModules.verify()` confirms module isolation.

Three-Level Isolation Tests:

- Level 1 (Keycloak): Tenant A JWT cannot access Tenant B realm resources.
- Level 2 (Application): `TenantContextFilter` rejects requests with invalid or inactive `tenant_id`.
- Level 3 (Database): Tenant A inserts records. Tenant B queries — result set is empty.
- Combined: End-to-end test with two tenants, verifying complete isolation at all levels.

TenantContext Lifecycle Tests:

- Test: `TenantContext` is set before business logic executes.
- Test: `TenantContext` is cleared after request completes (even on exception).
- Test: `TenantContext` is `null` between requests — no leakage.

Performance Benchmarks:

- 100 tenants, 1,000 records each. Queries with indexed `tenant_id` < 10ms.
- `TenantContextFilter` overhead < 1ms per request.
- Keycloak JWT validation via cached JWKS < 5ms per request.

Success Criteria:

- All three isolation levels pass independently and combined.
- `TenantContext` cleanup verified — no cross-request leakage.
- All 5 DataSources initialize successfully.
- Keycloak realm provisioning completes < 5s per new tenant.
- End-to-end test with 3 tenants passes: each tenant sees only its own data.

---

# 11. Risks and Mitigations

Risk 1:
Description: `TenantContext` ThreadLocal leaks between HTTP requests, exposing data to wrong tenant.
Mitigation: `TenantContextFilter` clears context in `finally` block. Integration test verifies cleanup. Java 21 virtual threads consideration: evaluate `ScopedValue` as ThreadLocal alternative in future.

Risk 2:
Description: Native SQL queries bypass Hibernate `@Filter`, exposing cross-tenant data.
Mitigation: ArchUnit rule flags `@Query(nativeQuery = true)` without `tenant_id`. Code review by @CodeGuardian. Integration test validates native query isolation.

Risk 3:
Description: Keycloak realm-per-tenant creates management overhead as tenants scale.
Mitigation: Automated realm provisioning via Keycloak Admin REST API. Template realm that is cloned for each new tenant. @SecurityOAuth owns automation.

Risk 4:
Description: Domain layer accidentally depends on `TenantContext`, violating Clean Architecture.
Mitigation: ArchUnit rule: domain packages cannot import `TenantContext`. Tenant ID passed via command/query DTOs at the use case boundary.

Risk 5:
Description: New entity created without `tenant_id` column, missing tenant isolation.
Mitigation: Every entity must extend `TenantAwareEntity`. @CodeGuardian verifies in code review. @ComplianceAgent audits all tables for `tenant_id` presence.

---

# 12. Related ADRs

- [ADR-0001 - Technology Stack and Architecture Foundation](./ADR-0001-technology-stack-and-architecture.md) — Defines Spring Boot 4.x, Spring Modulith, PostgreSQL, Clean Architecture.
- [ADR-0002 - Multi-Tenant Database Isolation Strategy](./ADR-0002-separacao-banco-por-contexto-multitenancy.md) — Establishes database per bounded context and `tenant_id` discriminator.
- [ADR-0003 - Multi-Tenancy Schema vs tenant_id](./ADR-0003-multitenancy-schema-vs-tenant-id.md) — Detailed analysis choosing `tenant_id` row-level isolation over schema-per-tenant.
- [ADR-0004 - WhatsApp Integration Architecture](./ADR-0004-whatsapp-integration-architecture.md) — WhatsApp module design with multi-tenant message routing.
- (Future) ADR-0006 — Authentication and Authorization with Keycloak.
- (Future) ADR-0007 — SERPRO Integra Contador Integration Pattern.

---

# 13. References

- [Keycloak Multi-Tenancy — Realm per Tenant](https://www.keycloak.org/docs/latest/server_admin/)
- [Hibernate 6.x — @TenantId](https://docs.jboss.org/hibernate/orm/6.4/userguide/html_single/Hibernate_User_Guide.html#multitenacy)
- [Hibernate — @Filter and @FilterDef](https://docs.jboss.org/hibernate/orm/6.4/userguide/html_single/Hibernate_User_Guide.html#pc-filter)
- [Spring Security — OAuth2 Resource Server](https://docs.spring.io/spring-security/reference/servlet/oauth2/resource-server/index.html)
- [Multi-Tenant SaaS Patterns — Microsoft](https://learn.microsoft.com/en-us/azure/architecture/guide/multitenant/considerations/tenancy-models)
- [PostgreSQL — CREATE DATABASE](https://www.postgresql.org/docs/current/sql-createdatabase.html)
- [SLF4J MDC — Mapped Diagnostic Context](https://www.slf4j.org/manual.html#mdc)
- Business Requirements: [Visão de produto](../product/business/product-vision.md)
- Agent Factory Specification: [Catálogo de agentes](../agents/README.md)

---

# 14. Decision Lifecycle

Current State: **Accept**

This ADR has been created and is under review. Upon acceptance, it becomes the governing document for the complete multi-tenancy architecture of the Hub Contabil Inteligente project. Any changes to the multi-tenancy design require a new ADR that supersedes this one.

---

# 15. Change Log

Version: 1.1
Date: 2026-08-23
Author: Codex / @ObservabilityDev / @SecurityAgent
Changes:
- Reconciled tenant observability with ADR-0012 v1.2: identities remain protected log/trace or
  ledger fields and are prohibited in metric labels.

Version: 1.0
Date: 2026-03-08
Author: @AgentOrchestrator, @MultiTenantEng
Changes:
- Initial ADR creation defining the complete three-level multi-tenancy architecture for the Hub Contabil Inteligente.
- Covers authentication (Keycloak realm-per-tenant), application (TenantContext filter), and database (Hibernate @Filter with tenant_id).

---

# 16. Repository Structure

All ADRs are stored in:

```
docs/
  adrs/
    ADR-0001-technology-stack-and-architecture.md
    ADR-0002-separacao-banco-por-contexto-multitenancy.md
    ADR-0003-multitenancy-schema-vs-tenant-id.md
    ADR-0005-multi-tenancy-architecture.md
```

Future ADRs will follow the naming convention: `ADR-XXXX-short-title.md`

---

# 17. Review Process

1. This ADR was created in "Accept" status by @AgentOrchestrator and @MultiTenantEng.
2. Reviewers (@CleanArchitecture, @DomainExpert, @DevOps-Agent, @SecurityOAuth) must validate the three-level isolation architecture against security requirements, LGPD compliance, and VPS resource constraints.
3. The startup founders must confirm that the Keycloak realm-per-tenant model aligns with subscriber onboarding expectations.
4. Upon approval, the status changes to "Accepted" and the ADR becomes immutable.
5. If the multi-tenancy architecture needs to change, a new ADR must be created and this ADR marked as "Superseded."

---

# 18. Notes

This ADR is the **comprehensive multi-tenancy architecture document** for the Hub Contabil Inteligente project. It builds on ADR-0002 (database separation) and ADR-0003 (tenant_id selection) to define the complete isolation strategy.

ADR relationship hierarchy:

| ADR | Scope | Decision |
|-----|-------|----------|
| ADR-0002 | Database organization | One database per bounded context |
| ADR-0003 | Isolation mechanism | `tenant_id` column (row-level) |
| **ADR-0005** | **Complete architecture** | **Three-level isolation: Keycloak + TenantContext + Hibernate @Filter** |

Component ownership:

| Component | Owner Agent |
|-----------|-------------|
| `TenantContext` | @MultiTenantEng |
| `TenantContextFilter` | @MultiTenantEng |
| `TenantAwareEntity` | @MultiTenantEng |
| `TenantHibernateInterceptor` | @MultiTenantEng |
| Keycloak realm provisioning | @SecurityOAuth |
| JWT validation + tenant extraction | @SecurityOAuth |
| MDC logging with tenantId | @ObservabilityDev |
| Isolation integration tests | @TestAutomator |
| `tenant_id` compliance audit | @ComplianceAgent |

Key principles:

- Every table has `tenant_id UUID NOT NULL` with an index.
- Every entity extends `TenantAwareEntity`.
- Every request passes through `TenantContextFilter`.
- Domain layer is unaware of multi-tenancy — `tenantId` is a command/query parameter, not a ThreadLocal lookup.
- Hibernate `@Filter` is the primary database isolation mechanism — independent of developer discipline.
- `TenantContext` is always cleared after request processing.
