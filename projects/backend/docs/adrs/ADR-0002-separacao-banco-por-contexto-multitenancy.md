---
document_id: "ADR-0002"
primary_nature: "Decisao"
objective: "Registrar a decisão arquitetural “Multi-Tenant Database Isolation Strategy and Bounded Context Separation”, seus motivadores, alternativas e consequências."
scope: "Decisão, componentes, integrações e limites explicitamente descritos em “Multi-Tenant Database Isolation Strategy and Bounded Context Separation”."
non_objectives: "Não implementar a decisão, substituir requisitos relacionados nem atestar capabilities ou ambientes sem evidência explícita."
owner: "@AgentOrchestrator, @MultiTenantEng"
status: "Partially Superseded"
date: "2026-03-08"
version: "1.1"
keywords: "adr, decisao, arquitetura, multi, tenant, database, isolation, strategy, and, bounded, context, separation"
related_files: "docs/adrs/README.md, docs/adrs/ADR-0001-technology-stack-and-architecture.md, docs/adrs/ADR-0005-multi-tenancy-architecture.md, docs/adrs/ADR-0052-parametros-pool-conexao-por-tenant.md, docs/product/business/product-vision.md, docs/agents/README.md"
code_references: "@Filter, @Configuration, TenantAwareEntity, TenantContext, TenantFilter"
principal_statement: "The system will use a **discriminator-based multi-tenancy** strategy (`tenant_id` column in every table, row-level isolation via Hibernate `@Filter`) across all bounded contexts. Each bounded context will have its own **dedicated PostgreSQL database** from day one, enabling zero-migration microservice extraction. Communication between bounded contexts will use Spring Modulith Events exclusively — no cross-database JOINs."
---

# ADR-0002 - Multi-Tenant Database Isolation Strategy and Bounded Context Separation

- Date: 2026-03-08
- Status: Partially Superseded
- Version: 1.1
- Authors / Owners: @AgentOrchestrator, @MultiTenantEng
- Reviewers: @CleanArchitecture, @DomainExpert, @DevOps-Agent
- Stakeholders: Engineering Team, Product Owner, Startup Founders
- Partially superseded by: [ADR-0052](ADR-0052-parametros-pool-conexao-por-tenant.md), exclusivamente quanto ao sizing uniforme aplicado a pools dedicados por tenant.


---

> [!IMPORTANT]
> O ADR-0052 substitui somente as prescrições numéricas uniformes de HikariCP
> deste documento quando aplicadas a pools dedicados por tenant. Topologia,
> isolamento, `tenant_id`, boundaries, eventos, Flyway e todas as demais decisões
> deste ADR permanecem preservadas por esta reconciliação.

# 1. Context

The Hub Contabil Inteligente is a multi-tenant micro-SaaS platform serving accounting firms. Each firm (tenant) requires strict data isolation: clients, digital certificates, fiscal queries, and billing must be completely separated.

Business requirements:

- Three subscription plans (Start: 3 firms, Business: 50 firms, Premium: unlimited) require a multi-tenancy strategy that scales from 3 to thousands of tenants.
- LGPD compliance mandates auditable tenant data isolation and the ability to delete all data for a specific tenant on request.
- The system handles sensitive data: digital certificates (A1/A3), taxpayer information (Documentos), fiscal query results, and WhatsApp interaction logs.
- Zero cloud cost constraint: all infrastructure runs on a single VPS with Docker Compose (as defined in ADR-0001).

Technical constraints:

- Spring Boot 4.x + Spring Modulith architecture with 5 bounded contexts (as defined in ADR-0001).
- Clean Architecture: persistence is an infrastructure detail, not a domain concern. Each module manages its own data layer.
- The architecture must support evolution from modular monolith to microservices without data migration.
- PostgreSQL is the chosen database (as defined in ADR-0001).

Industry lessons:

- Using schema-per-tenant in a single shared database for all bounded contexts creates operational complexity when planning microservice extraction — moving schemas between databases is non-trivial.
- Multiple `EntityManagerFactory` per context in a monolith works but adds configuration complexity.
- Delaying database separation decisions accumulates technical debt that increases future migration cost.

The decision is needed to define: (1) how tenant data isolation is enforced across all bounded contexts, and (2) how persistence is organized to enable future microservice extraction without data migration.

---

# 2. Decision Statement

The system will use a **discriminator-based multi-tenancy** strategy (`tenant_id` column in every table, row-level isolation via Hibernate `@Filter`) across all bounded contexts. Each bounded context will have its own **dedicated PostgreSQL database** from day one, enabling zero-migration microservice extraction. Communication between bounded contexts will use Spring Modulith Events exclusively — no cross-database JOINs.

---

# 3. Decision Drivers

- **Scalability:** Row-level isolation (`tenant_id`) scales linearly from 3 to unlimited tenants without DDL replication. Schema-per-tenant would require N schemas × M databases.
- **Operational Simplicity:** One schema per database. Flyway runs a single set of migrations per context. No schema management per tenant.
- **Microservice Readiness:** Each bounded context already has its own database. Extraction requires only moving the DataSource configuration — no data migration.
- **LGPD Compliance:** Tenant data deletion is a simple `DELETE WHERE tenant_id = ?` across all tables. Auditable via `tenant_id` in every query.
- **Zero Cloud Cost:** A single PostgreSQL instance with 5 databases is resource-efficient on a VPS (versus 5 separate PostgreSQL instances).
- **Clean Architecture Alignment:** Persistence isolation per bounded context reinforces the dependency rule — modules cannot access each other's data layer.
- **Greenfield advantage:** Schema-per-tenant generates complexity during architectural evolution. `tenant_id` is simpler for new projects.
- **Spring Modulith Compatibility:** `@TenantId` with Hibernate `@Filter` works natively. Filter applied via global interceptor.

---

# 4. Considered Options

## Multi-Tenancy Options

Option A: Schema per tenant

Description: Each tenant has its own schema (`tenant_<uuid>`) within each context database. Tables replicated per schema. Flyway executes migrations in each schema.

Pros:
- Strong isolation at schema level
- Proven approach in enterprise multi-tenant systems
- Common in legacy applications with established schema-per-tenant patterns

Cons:
- N schemas × M databases = high operational overhead
- Flyway must execute migrations in every schema for every tenant
- Adding a new tenant requires DDL execution
- Does not scale well beyond ~500 tenants on a single VPS

Option B: Discriminator (`tenant_id` in every table) — Selected

Description: Single schema (`public`) per database. All tables contain a `tenant_id` column. Row-level filtering via Hibernate `@Filter` or `@TenantId` annotation.

Pros:
- One schema per database — Flyway runs once per context
- Scales linearly to unlimited tenants
- Standard SaaS multi-tenancy pattern
- Simple tenant deletion: `DELETE WHERE tenant_id = ?`
- New tenant requires zero DDL — just insert into tenant registry

Cons:
- Logical isolation (row-level) — weaker than schema-level
- Risk of cross-tenant data exposure if `tenant_id` filter is missing
- Requires discipline: every query must include tenant filter

Option C: Database per tenant

Description: A physical database per tenant per context (e.g., `saas_fiscal_tenant1`, `saas_fiscal_tenant2`).

Pros:
- Maximum isolation
- Complete physical separation of tenant data

Cons:
- N tenants × 5 contexts = potentially hundreds of databases
- Connection pool explosion
- Infeasible on a single VPS
- Impractical for SaaS with many tenants

## Bounded Context Separation Options

Option X: Single database for all contexts

Description: All bounded contexts share one database (`saas`).

Pros:
- Maximum simplicity — single DataSource
- Cross-context JOINs possible

Cons:
- Persistence coupling between modules
- Microservice extraction requires massive data migration
- Violates Clean Architecture data isolation principle

Option Y: Database per bounded context from day one — Selected

Description: Each bounded context has its own database: `saas_tenant`, `saas_certificate`, `saas_fiscal`, `saas_billing`, `saas_whatsapp`.

Pros:
- Aligned with Clean Architecture — each module manages its own persistence
- Natural microservice extraction — database already isolated
- Independent Flyway migrations per context
- No cross-context JOINs forces event-driven communication

Cons:
- Multiple DataSources, EntityManagerFactories, TransactionManagers in the monolith
- More configuration code
- Cross-context reporting requires CQRS or event-driven read models

Option Z: Single database now, separate later

Description: Use a single database initially. Document and plan separation for the future.

Pros:
- No immediate cost

Cons:
- Technical debt accumulation — deferring separation increases future migration cost
- Complex migration when extraction is needed
- Cross-context coupling becomes entrenched

---

# 5. Decision Outcome

**Multi-Tenancy: Option B (Discriminator `tenant_id`)** and **Separation: Option Y (Database per bounded context from day one)** were selected.

Key factors:

- **Cost efficiency:** A single PostgreSQL instance with 5 databases on Docker Compose is operationally simple and resource-efficient on a VPS.
- **Scalability:** Row-level isolation scales from 3 tenants (Start plan) to unlimited (Premium plan) without schema management overhead.
- **Microservice readiness:** When a bounded context is extracted as a microservice, it takes its database with it. Zero data migration required.
- **LGPD compliance:** `tenant_id` in every table enables auditable data isolation and simple tenant data erasure.
- **Proactive separation:** Starting with separated databases avoids the complexity of separating a shared database later.

Tradeoffs accepted:

- Row-level isolation is weaker than schema-level isolation. Mitigated by global Hibernate `@Filter` and mandatory code review by @CodeGuardian.
- 5 DataSources increase configuration complexity. Mitigated by standardized `@Configuration` classes per module.
- No cross-context JOINs. Mitigated by Spring Modulith Events for inter-module communication and CQRS for reporting.

Options rejected:

- Schema-per-tenant (Option A): Too much operational complexity for a SaaS that needs to scale to many tenants on a single VPS.
- Database-per-tenant (Option C): Infeasible on a single VPS.
- Single database (Option X): Creates coupling and migration debt.
- Separate later (Option Z): Accumulates technical debt — deferred separation increases migration cost significantly.

---

# 6. Consequences

Positive Consequences:

- Each bounded context has its own database from day one — microservice extraction requires no data migration.
- Every record has a `tenant_id` — tenant data deletion is a simple `DELETE WHERE tenant_id = ?`.
- Flyway is simple: 1 schema, 1 set of migrations per context. No DDL replication per tenant.
- LGPD compliance is facilitated: `tenant_id` is auditable in every query.
- Docker Compose efficient: one PostgreSQL instance with 5 databases (~100MB additional memory).

Negative Consequences:

- 5 `DataSource`/`EntityManagerFactory`/`TransactionManager` beans in the monolith. More configuration code.
- Cross-context queries require domain events or internal API calls — no JOINs between databases.
- Risk of forgetting `tenant_id` filter exposing cross-tenant data. Mitigated by global Hibernate `@Filter`.
- Every new entity must extend `TenantAwareEntity`. Enforced by @CodeGuardian code review.

Neutral Consequences:

- HikariCP connection pool per DataSource. Each pool with 5-10 connections = 25-50 total (within PostgreSQL default limit of 100). This numeric sizing is historical and does not govern dedicated tenant pools, whose independent policies are defined by ADR-0052.
- Backups can be done per database or per PostgreSQL instance.

---

# 7. Impact

- **Architecture:** Each Spring Modulith module manages its own DataSource, EntityManagerFactory, and TransactionManager. No cross-module database access.
- **Infrastructure:** Single PostgreSQL Docker container with 5 databases. Init script creates all databases on first startup.
- **Security:** `tenant_id` extracted from JWT claims by @SecurityOAuth and injected into `TenantContext`. Hibernate `@Filter` enforces row-level isolation globally.
- **Development Process:** Every entity must extend `TenantAwareEntity`. Every repository query is automatically filtered by `tenant_id`.
- **Deployment Pipeline:** Flyway migrations run per context. Each module has its own `db/migration/<context>/` directory.
- **Data Architecture:** PostgreSQL with `tenant_id` discriminator. Indexed `tenant_id` column on all tables.
- **Observability:** Metrics per database: connection pool usage, query latency, migration status.
- **DevOps:** Docker Compose init script creates 5 databases. Backup strategy per database.
- **AI Agent Orchestration:** @MultiTenantEng owns the `TenantContext` implementation. @AdapterDev implements tenant-aware repositories. @TestAutomator writes isolation tests.

---

# 8. AI Agent Considerations (For Autonomous Agent Environments)

Agent Roles Impacted:

- **@MultiTenantEng:** Implements `TenantContext`, `TenantFilter`, `TenantAwareEntity`, Hibernate `@Filter`, and DataSource configurations per module.
- **@CleanArchitecture:** Validates that no module accesses another module's database. Enforces via ArchUnit rules.
- **@ModulithConfig:** Configures `EntityManagerFactory` and `TransactionManager` per Spring Modulith module.
- **@AdapterDev:** Implements JPA repositories with tenant-aware `@Filter` per module. Uses `@Transactional(transactionManager = "<context>TransactionManager")`.
- **@DevOps-Agent:** Docker Compose with database init scripts, backup strategy, connection pool monitoring.
- **@TestAutomator:** Writes multi-tenant isolation integration tests using Testcontainers PostgreSQL.
- **@ComplianceAgent:** Validates that `tenant_id` exists in all tables containing PII.
- **@SecurityOAuth:** Extracts `tenant_id` from JWT and injects into `TenantContext`.

Operational Considerations:

- No agent may create cross-database queries or JOINs between bounded context databases.
- Every entity class generated by agents must extend `TenantAwareEntity`.
- @CodeGuardian must verify `tenant_id` presence in all new entity classes during code review.
- @TestAutomator must include multi-tenant isolation tests for every new repository.

LLM Considerations:

- Prompts for code generation must include the `TenantAwareEntity` base class to ensure `tenant_id` is always present.
- Repository generation prompts must reference the correct `TransactionManager` for the bounded context.
- Migration generation prompts must specify the correct `db/migration/<context>/` directory.

Safety Considerations:

- Any query that does not filter by `tenant_id` is a critical security vulnerability. Global Hibernate `@Filter` prevents this at the ORM level.
- No agent may modify the `TenantContext` implementation without approval from @MultiTenantEng and @SecurityOAuth.
- All Flyway migration scripts require human review before execution.

---

# 9. Implementation Plan

## Phase 1 — Foundation (Sprint 1-2)

Database infrastructure:

```
PostgreSQL (Docker Compose — single instance)
├── saas_tenant        → Tenant Management module
├── saas_certificate   → Certificate Management module
├── saas_fiscal        → Fiscal Integration module
├── saas_billing       → Billing module
└── saas_whatsapp      → WhatsApp Channel module
```

Implementation tasks:

1. Create Docker Compose PostgreSQL service with init script (`docker/postgres/init/01-create-databases.sql`).
2. Implement `TenantContext` (ThreadLocal with `UUID tenantId`).
3. Implement `TenantFilter` (HTTP interceptor extracting `X-Tenant-Id` header or JWT `tenant_id` claim).
4. Implement `TenantAwareEntity` base class with `@FilterDef` and `@Filter` annotations.
5. Create `@Configuration` class per module: DataSource, EntityManagerFactory, TransactionManager.
6. Configure Flyway per context with `db/migration/<context>/` directories.
7. Write multi-tenant isolation integration test (Testcontainers).

Responsible agents: @MultiTenantEng, @ModulithConfig, @DevOps-Agent, @SecurityOAuth, @TestAutomator

Dependencies: ADR-0001 project foundation must be complete.

Rollback plan: Revert to single database with single DataSource by removing per-context configuration classes.

## Phase 2 — Microservice Extraction (Future)

When a bounded context is extracted as a microservice:

1. The microservice receives the database that already belongs to it (e.g., `saas_fiscal`).
2. The DataSource is moved from the monolith to the microservice.
3. Flyway migrations are copied to the microservice repository.
4. Inter-module communication (previously Spring Modulith Events) is replaced by Kafka/RabbitMQ (managed by @Kafka-Agent).
5. Zero data migration required.

---

# 10. Validation

Architecture Validation:

- ArchUnit test: no module imports persistence classes from another module.
- Spring Modulith `ApplicationModules.verify()` confirms module isolation.
- Code review by @CodeGuardian: every entity extends `TenantAwareEntity`.

Multi-Tenant Isolation Test:

- Integration test with 2 tenants in the same database. Tenant A inserts records, Tenant B queries and sees nothing.
- Integration test verifying that Hibernate `@Filter` is active in all repository queries.

Performance Benchmarks:

- 100 tenants with 1,000 records each. Queries with indexed `tenant_id` complete in < 10ms.
- Connection pool: 5 DataSources × 10 max connections = 50 total (within PostgreSQL 100 connection limit). This is a historical benchmark baseline; dedicated tenant pools follow the per-tenant capacity model of ADR-0052.

Flyway Validation:

- Each context executes its migrations independently without conflict.
- Migration rollback scripts verified for each migration file.

Success Criteria:

- Multi-tenant isolation test passes: Tenant A cannot access Tenant B data.
- All 5 DataSources initialize successfully on application startup.
- Flyway migrations complete without errors for all 5 databases.
- ArchUnit test passes: no cross-module persistence access.
- `docker compose up` creates all 5 databases via init script.

---

# 11. Risks and Mitigations

Risk 1:
Description: A query without `tenant_id` filter exposes cross-tenant data.
Mitigation: Global Hibernate `@Filter` activated by interceptor on every session. Mandatory code review by @CodeGuardian for all repository changes. Integration test validating isolation for every new repository.

Risk 2:
Description: Overhead of 5 DataSources and connection pools on a single VPS.
Mitigation: the original baseline configured HikariCP with `minimumIdle=2`, `maximumPoolSize=10` per DataSource and 50 total connections. For dedicated tenant pools, those uniform values are superseded by ADR-0052; capacity is admitted and versioned per tenant. Pool usage remains monitored without tenant identifiers in metric labels.

Risk 3:
Description: Flyway migration fails in one context while others have already been applied.
Mitigation: Migrations execute sequentially per context. Each migration includes a rollback script. Health check monitors migration status.

Risk 4:
Description: Cross-context JOIN needed for a business report.
Mitigation: Create read model (CQRS pattern) or query via domain events. Never JOIN between databases. Document reporting patterns for @AdapterDev.

Risk 5:
Description: `TenantContext` not cleared after request, leaking tenant ID to subsequent requests.
Mitigation: `TenantFilter` clears `TenantContext` in the `finally` block of every request. Unit test verifies cleanup.

---

# 12. Related ADRs

- [ADR-0001 - Technology Stack and Architecture Foundation](./ADR-0001-technology-stack-and-architecture.md) — Defines Spring Boot 4.x, Spring Modulith, PostgreSQL, Clean Architecture.

- (Future) ADR-0003 — Authentication and Authorization with Keycloak.
- (Future) ADR-0004 — WhatsApp Integration Architecture.
- [ADR-0005 - Multi-Tenancy Architecture](./ADR-0005-multi-tenancy-architecture.md)
- [ADR-0052 - Pools de conexão exclusivos e configuráveis por tenant](./ADR-0052-parametros-pool-conexao-por-tenant.md) — supersedes only uniform numeric sizing when applied to dedicated tenant pools.
- (Future) ADR-0006 — SERPRO Integra Contador Integration Pattern.

---

# 13. References


- [Spring Modulith — Events](https://docs.spring.io/spring-modulith/reference/events.html)
- [Hibernate Multi-Tenancy](https://docs.jboss.org/hibernate/orm/6.4/userguide/html_single/Hibernate_User_Guide.html#multitenacy)
- [Flyway Documentation](https://documentation.red-gate.com/fd)
- [PostgreSQL — CREATE DATABASE](https://www.postgresql.org/docs/current/sql-createdatabase.html)
- [HikariCP — Pool Sizing](https://github.com/brettwooldridge/HikariCP/wiki/About-Pool-Sizing)
- Business Requirements: [Visão de produto](../product/business/product-vision.md)
- Agent Factory Specification: [Catálogo de agentes](../agents/README.md)

---

# 14. Decision Lifecycle

Current State: **Partially Superseded**

This ADR was accepted on 2026-03-09. As of 2026-08-27, ADR-0052 partially supersedes only its uniform numeric HikariCP sizing when applied to dedicated tenant pools. Every other decision in this ADR remains preserved by this reconciliation. Any further change to the multi-tenancy strategy requires a new accepted ADR with an explicit supersession boundary.

---

# 15. Change Log

Version: 1.0
Date: 2026-03-08
Author: @AgentOrchestrator, @MultiTenantEng
Changes:
- Initial ADR creation defining multi-tenant database isolation strategy and bounded context separation for the Hub Contabil Inteligente micro-SaaS project.
- Analysis of multi-tenancy and database separation strategies. `tenant_id` discriminator and database-per-context from day one selected for scalability and operational simplicity.

Version: 1.1
Date: 2026-08-27
Author: Codex (OpenAI), sob aprovação humana explícita
Changes:
- Marked `Partially Superseded` only for uniform HikariCP sizing applied to dedicated tenant pools, now governed by ADR-0052.
- Preserved every other topology, isolation, boundary, event and migration decision without expansion of the supersession scope.
- Reconciled the review process so lifecycle annotations and exact partial supersession remain possible without rewriting the historical decision.

---

# 16. Repository Structure

All ADRs are stored in:

```
docs/
  adrs/
    ADR-0001-technology-stack-and-architecture.md
    ADR-0002-separacao-banco-por-contexto-multitenancy.md
```

Future ADRs will follow the naming convention: `ADR-XXXX-short-title.md`

---

# 17. Review Process

1. This ADR was created in "Proposed" status by @AgentOrchestrator and @MultiTenantEng.
2. Reviewers (@CleanArchitecture, @DomainExpert, @DevOps-Agent) must validate the multi-tenancy strategy against the business requirements, LGPD constraints, and VPS resource limits.
3. The startup founders must confirm alignment with the subscription plan structure (Start/Business/Premium tenant counts).
4. Upon approval, the status changes to "Accepted"; the original decision remains
   historical, while lifecycle annotations, explicit supersession boundaries and
   the change log may be reconciled under ADR-0000.
5. If the multi-tenancy strategy needs to change in the future, a new ADR must be
   created and this ADR marked as `Superseded` or `Partially Superseded`, with the
   exact superseded scope stated. ADR-0052 currently supersedes only the uniform
   numeric HikariCP sizing applied to dedicated tenant pools.

---

# 18. Notes

This ADR defines two critical infrastructure decisions for the Hub Contabil Inteligente project:

1. **Multi-tenancy via `tenant_id` discriminator** — chosen over schema-per-tenant for SaaS scalability, operational simplicity, and microservice readiness.
2. **Database per bounded context from day one** — chosen to prevent the technical debt that accumulates when database separation is deferred.

Key principles codified by this ADR:

- Every table must have a `tenant_id` column.
- Every entity must extend `TenantAwareEntity`.
- Every module must have its own DataSource, EntityManagerFactory, and TransactionManager.
- Cross-module communication is via Spring Modulith Events — never via database JOINs.
- Tenant isolation is enforced at the ORM level via Hibernate `@Filter` — not dependent on developer discipline in individual queries.

Docker Compose configuration (`docker/postgres/init/01-create-databases.sql`):

```sql
CREATE DATABASE saas_tenant;
CREATE DATABASE saas_certificate;
CREATE DATABASE saas_fiscal;
CREATE DATABASE saas_billing;
CREATE DATABASE saas_whatsapp;
```
