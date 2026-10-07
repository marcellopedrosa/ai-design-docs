---
document_id: "ADR-0003"
primary_nature: "Decisao"
objective: "Registrar a decisão arquitetural “Multi-Tenancy Strategy per Context Database: Schema vs tenant_id”, seus motivadores, alternativas e consequências."
scope: "Decisão, componentes, integrações e limites explicitamente descritos em “Multi-Tenancy Strategy per Context Database: Schema vs tenant_id”."
non_objectives: "Não implementar a decisão, substituir requisitos relacionados nem atestar capabilities ou ambientes sem evidência explícita."
owner: "@AgentOrchestrator, @MultiTenantEng"
status: "Accepted"
date: "2026-03-08"
version: "1.2"
keywords: "adr, decisao, arquitetura, multi, tenancy, strategy, per, context, database, schema, vs, tenant, id"
related_files: "README.md, ADR-0002-separacao-banco-por-contexto-multitenancy.md, ADR-0001-technology-stack-and-architecture.md, ADR-0005-multi-tenancy-architecture.md"
code_references: "@Filter, SchemaCreationService, TenantContext, TenantAwareEntity, TenantFilter, @Entity"
principal_statement: "The system will use **`tenant_id` column-based (row-level) multi-tenancy** within each bounded context database. All tables will contain a `tenant_id` column. Tenant isolation will be enforced at the ORM level by Hibernate `@Filter` activated globally via a session interceptor. There will be no per-tenant schemas."
---

# ADR-0003 - Multi-Tenancy Strategy per Context Database: Schema vs tenant_id

- Date: 2026-03-08
- Status: Accepted
- Version: 1.2
- Authors / Owners: @AgentOrchestrator, @MultiTenantEng
- Reviewers: @CleanArchitecture, @DomainExpert, @DevOps-Agent, @SecurityOAuth
- Stakeholders: Engineering Team, Product Owner, Startup Founders


---

# 1. Context

[ADR-0002](ADR-0002-separacao-banco-por-contexto-multitenancy.md) established **one database per bounded context** for the SaaS Hub Contabil Inteligente project: `saas_tenant`, `saas_certificate`, `saas_fiscal`, `saas_billing`, and `saas_whatsapp`. ADR-0002 also recommended `tenant_id` discriminator-based isolation.

This ADR provides the detailed technical analysis behind the multi-tenancy choice **within** each context database: should the project use **(a) a schema per tenant** (`tenant_<uuid>` with `SET search_path`) or **(b) a single schema with `tenant_id` column** (row-level filtering via Hibernate `@Filter`)?

Business context:

- The Hub Contabil Inteligente serves accounting firms (tenants) with three subscription plans: Start (up to 3 firms), Business (up to 50 firms), Premium (unlimited firms). The multi-tenancy strategy must scale from single-digit to hundreds or thousands of tenants.
- LGPD compliance requires auditable tenant data isolation and the ability to erase all data for a specific tenant upon request.
- Zero cloud cost: all infrastructure runs on a single VPS with Docker Compose. Resource efficiency is critical.

Industry considerations:

- Schema-per-tenant is a valid approach but creates operational overhead: N schemas × M databases, Flyway migrations per schema per context, and growing DDL complexity as tenants scale.
- Many mature SaaS platforms (Salesforce, Stripe) use row-level `tenant_id` isolation for its scalability and operational simplicity.
- Schema-per-tenant is better suited for projects with strong regulatory isolation requirements or a small, fixed number of tenants.

Key context: The SaaS project is **greenfield** — there is no existing multi-tenancy implementation. The decision is being made before any code exists, eliminating migration cost as a factor.

---

# 2. Decision Statement

The system will use **`tenant_id` column-based (row-level) multi-tenancy** within each bounded context database. All tables will contain a `tenant_id` column. Tenant isolation will be enforced at the ORM level by Hibernate `@Filter` activated globally via a session interceptor. There will be no per-tenant schemas.

---

# 3. Decision Drivers

- **Greenfield advantage:** No existing schema-per-tenant implementation to migrate. The decision carries zero migration cost.
- **SaaS scalability:** The Premium plan supports unlimited tenants. Schema-per-tenant requires DDL execution per tenant registration. `tenant_id` requires only a row insert.
- **Operational simplicity:** One schema per database. Flyway runs once per context, not once per tenant × context.
- **VPS resource efficiency:** Schema metadata consumes PostgreSQL catalog memory. Hundreds of schemas across 5 databases would strain a small VPS.
- **Microservice readiness:** `tenant_id` is the dominant SaaS multi-tenancy pattern. When bounded contexts are extracted as microservices, no conversion is needed.
- **Hibernate native support:** `@TenantId` (Hibernate 6.x) and `@FilterDef`/`@Filter` provide framework-level enforcement without relying on developer discipline per query.
- **LGPD compliance:** Tenant data erasure is `DELETE FROM <table> WHERE tenant_id = ?` — straightforward and auditable.
- **Backup simplicity:** `pg_dump` per database (not per schema) is simpler to automate and restore.
- **Greenfield project:** No existing multi-tenancy implementation to migrate. The technical merits of `tenant_id` can be evaluated purely on their own.

---

# 4. Considered Options

## Option A: Schema per tenant

Description: Each tenant has its own PostgreSQL schema (`tenant_<uuid>`) within each context database. The connection provider sets `search_path` to the tenant's schema. Flyway executes migrations in every tenant schema.

Pros:
- Strong physical isolation boundary — a query cannot accidentally access another tenant's data even without filters
- Backup and restore per tenant is a direct `pg_dump -n tenant_<uuid>` per schema
- Audit and compliance: data boundaries are physically visible in the database catalog
- Proven approach in enterprise multi-tenant systems

Cons:
- N schemas × 5 databases = high catalog/metadata overhead on a VPS
- Flyway must execute migrations in every schema for every tenant — slow for large tenant counts
- New tenant registration requires DDL execution (CREATE SCHEMA, run all migrations) — slow and error-prone at scale
- Does not scale well beyond ~500 tenants on a single PostgreSQL instance
- Requires `SchemaCreationService` and `SchemaMultiTenantConnectionProvider` — custom infrastructure code
- Not the dominant SaaS pattern — most cloud-native SaaS platforms use row-level isolation

## Option B: Discriminator `tenant_id` (row-level) — Selected

Description: Single schema (`public`) per context database. All tables contain a `tenant_id` UUID column (NOT NULL, indexed). Hibernate `@Filter` with `@FilterDef` enforces row-level isolation globally. `TenantContext` (ThreadLocal) is set by an HTTP interceptor from the JWT `tenant_id` claim.

Pros:
- One schema per database — Flyway runs once per context
- Linear scalability: no DDL per tenant, no catalog bloat
- New tenant registration: insert a row, no schema creation needed
- Standard SaaS multi-tenancy pattern — compatible with cloud-native tooling
- Hibernate 6.x `@TenantId` annotation provides framework-level enforcement
- Simple backup: `pg_dump` per database, no per-schema management
- Microservice-ready: `tenant_id` column travels with the data when extracted

Cons:
- Logical isolation — a missing filter could theoretically expose cross-tenant data
- Requires global Hibernate `@Filter` activation and `TenantAwareEntity` base class
- Per-tenant backup/restore requires custom scripts (`pg_dump` with `WHERE tenant_id = ?` or `COPY` commands)
- Every query in the system is filtered — slight performance overhead (mitigated by indexed `tenant_id`)

## Option C: Hybrid (schema for some contexts, tenant_id for others)

Description: Use schema-per-tenant for high-sensitivity contexts (Certificate Management) and `tenant_id` for others.

Pros:
- Maximum isolation for the most sensitive data
- Flexibility per bounded context

Cons:
- Two different multi-tenancy mechanisms in the same application
- Double the infrastructure code (SchemaMultiTenantConnectionProvider + TenantFilter)
- Confusion for developers: different isolation models per module
- Inconsistent testing strategy
- Rejected due to complexity with no clear benefit

---

# 5. Decision Outcome

**Option B (`tenant_id` row-level discriminator)** was selected for all 5 context databases.

Key factors:

- **Zero migration cost:** This is a greenfield project. There is no existing schema-per-tenant to migrate. The decision is based purely on technical merits.
- **Scalability:** The Premium plan allows unlimited tenants. Schema-per-tenant requires DDL per tenant; `tenant_id` requires only a row insert. At 1,000 tenants, schema-per-tenant would create 5,000 schemas (1,000 × 5 databases) on a VPS.
- **Operational simplicity:** One Flyway migration set per context. No `SchemaCreationService`. No `SchemaMultiTenantConnectionProvider`.
- **Industry standard:** `tenant_id` is the dominant SaaS multi-tenancy pattern used by Salesforce, Stripe, and most B2B SaaS platforms. It aligns with best practices for cloud-native evolution.
- **Hibernate 6.x support:** The `@TenantId` annotation and `@Filter`/`@FilterDef` mechanism provide ORM-level enforcement that does not depend on developer discipline in individual queries.

Tradeoffs accepted:

- Logical isolation is weaker than physical schema isolation. Mitigated by: (1) Hibernate `@Filter` activated globally — every query is automatically filtered; (2) @CodeGuardian enforces that every entity extends `TenantAwareEntity`; (3) @TestAutomator writes isolation integration tests for every repository.
- Per-tenant backup/restore is more complex. Mitigated by: (1) full database backup covers all tenants; (2) tenant-specific export scripts can be created when needed.

Why `tenant_id` was chosen over schema-per-tenant:

- In existing projects with schema-per-tenant already implemented, migration cost often justifies keeping that approach. However, the SaaS project has no existing implementation — the "cost of change" argument is irrelevant. Evaluating purely on technical merits, `tenant_id` wins on scalability, operational simplicity, Flyway efficiency, and industry alignment.

---

# 6. Consequences

Positive Consequences:

- One schema per database — Flyway runs once per context, not N times per tenant.
- New tenant onboarding requires zero DDL — just a row insert in the tenant registry.
- PostgreSQL catalog stays lean: no schema metadata bloat.
- Microservice extraction requires no multi-tenancy conversion.
- Aligns with dominant SaaS industry practices.
- Simpler infrastructure code: no `SchemaCreationService`, no `SchemaMultiTenantConnectionProvider`.

Negative Consequences:

- A missing `tenant_id` filter would expose cross-tenant data. Mitigated by Hibernate `@Filter` at ORM level.
- Per-tenant backup/restore requires custom scripts instead of `pg_dump -n <schema>`.
- Every entity must extend `TenantAwareEntity`. Enforced by @CodeGuardian in code review.
- Every table must have an indexed `tenant_id` column. Enforced by @ComplianceAgent audit.

Neutral Consequences:

- `tenant_id` index adds marginal storage and write overhead. Negligible for this workload.
- All integration tests must validate tenant isolation — standard practice regardless of approach.

---

# 7. Impact

- **Architecture:** All entities extend `TenantAwareEntity` base class. All repositories are automatically filtered by `tenant_id`. No per-tenant schemas exist.
- **Infrastructure:** PostgreSQL databases contain only the `public` schema. No `SchemaCreationService` needed.
- **Security:** `tenant_id` extracted from JWT by `TenantFilter` and injected into `TenantContext`. Hibernate `@Filter` enforces isolation at ORM level. Defense-in-depth: code review + integration tests + ORM filter.
- **Development Process:** Developers never write `WHERE tenant_id = ?` manually. Hibernate handles it. New entity checklist: extend `TenantAwareEntity`, add `tenant_id` column to migration.
- **Deployment Pipeline:** Flyway runs 5 migration sets (one per database) on startup. No per-tenant migration loop.
- **Data Architecture:** Every table has `tenant_id UUID NOT NULL` indexed column. Foreign keys within a context stay within the same tenant implicitly.
- **Observability:** `tenant_id` remains a protected log/trace field and storage discriminator;
  ADR-0012 v1.2 prohibits it as a metric label. Per-tenant analysis uses controlled logs/traces or
  domain/audit stores.
- **DevOps:** `docker compose up` creates 5 empty databases. No tenant-specific initialization required.
- **AI Agent Orchestration:** @MultiTenantEng owns `TenantContext` and `TenantAwareEntity`. Agents generating entities must always extend the base class.

---

# 8. AI Agent Considerations (For Autonomous Agent Environments)

Agent Roles Impacted:

- **@MultiTenantEng:** Implements `TenantContext` (ThreadLocal), `TenantFilter` (HTTP interceptor), `TenantAwareEntity` (base class with `@FilterDef` and `@Filter`), and `TenantInterceptor` (Hibernate session filter activation).
- **@CleanArchitecture:** Validates that `tenant_id` isolation is applied consistently across all bounded contexts. ArchUnit rule: every `@Entity` must extend `TenantAwareEntity`.
- **@AdapterDev:** Implements JPA repositories. Must **not** manually add `WHERE tenant_id = ?` — Hibernate `@Filter` handles it. Must use correct `TransactionManager` per context.
- **@TestAutomator:** Writes multi-tenant isolation tests for every repository: insert as Tenant A, query as Tenant B, assert empty result set.
- **@CodeGuardian:** Reviews every PR for: (1) entity extends `TenantAwareEntity`, (2) migration includes `tenant_id` column, (3) no raw SQL bypassing Hibernate filter.
- **@ComplianceAgent:** Audits that all tables with PII have `tenant_id` column and that LGPD erasure queries use `tenant_id`.
- **@SecurityOAuth:** Extracts `tenant_id` from JWT claims and sets `TenantContext`. Validates that the authenticated user belongs to the requested tenant.

Operational Considerations:

- No agent may create a repository method that bypasses Hibernate `@Filter` (e.g., native SQL without `tenant_id` filter).
- Every database migration generated by agents must include `tenant_id UUID NOT NULL` with an index.
- @TestAutomator must add isolation tests to the test suite for every new repository.

LLM Considerations:

- Entity generation prompts must include `TenantAwareEntity` as the base class in the context.
- Migration generation prompts must include `tenant_id UUID NOT NULL` and `CREATE INDEX idx_<table>_tenant_id ON <table>(tenant_id)` as standard columns.
- Repository prompts must not include explicit `tenant_id` parameters in finder methods — Hibernate handles filtering automatically.

Safety Considerations:

- Raw SQL queries (via `@Query(nativeQuery = true)`) must always include `tenant_id = :tenantId` manually, since Hibernate `@Filter` does not apply to native queries. This must be flagged in code review.
- `TenantContext` must be cleared in the `finally` block of `TenantFilter` to prevent tenant ID leakage between requests.
- No agent may disable or modify the Hibernate `@Filter` configuration without approval from @MultiTenantEng and @SecurityOAuth.

---

# 9. Implementation Plan

## Phase 1 — Foundation (Sprint 1-2)

Implementation tasks for `tenant_id` multi-tenancy:

1. **`TenantAwareEntity` base class:**
   ```java
   @MappedSuperclass
   @FilterDef(name = "tenantFilter", parameters = @ParamDef(name = "tenantId", type = UUID.class))
   @Filter(name = "tenantFilter", condition = "tenant_id = :tenantId")
   public abstract class TenantAwareEntity {
       @Column(name = "tenant_id", nullable = false, updatable = false)
       private UUID tenantId;
   }
   ```

2. **`TenantContext` (ThreadLocal):**
   ```java
   public class TenantContext {
       private static final ThreadLocal<UUID> current = new ThreadLocal<>();
       public static UUID getCurrentTenantId() { return current.get(); }
       public static void setCurrentTenantId(UUID id) { current.set(id); }
       public static void clear() { current.remove(); }
   }
   ```

3. **`TenantFilter` (HTTP interceptor):** For a tenant identity, extracts the signed `tenant_id`
   claim from the JWT and ignores/rejects a caller-controlled tenant header as an alternative.
   A global Super Admin carries no tenant context; only explicit, authorized impersonation may
   establish a temporary tenant through `X-Tenant-ID`. The filter validates that context against
   the requested resource, sets `TenantContext` and clears it in `finally`.

4. **`TenantHibernateInterceptor`:** Activates Hibernate `@Filter("tenantFilter")` on every `Session` open, setting the `:tenantId` parameter from `TenantContext`.

5. **Flyway migrations:** Every `V1__create_*_tables.sql` includes `tenant_id UUID NOT NULL` with index on all tables.

6. **Integration test:** Two tenants insert data in same database. Each tenant queries and sees only its own data.

Responsible agents: @MultiTenantEng, @SecurityOAuth, @TestAutomator

Dependencies: ADR-0001 project foundation and ADR-0002 database infrastructure.

Rollback plan: If schema-per-tenant is later required (e.g., regulatory mandate), add `SchemaMultiTenantConnectionProvider` and migrate data from `public` schema to per-tenant schemas.

---

# 10. Validation

Architecture Validation:

- ArchUnit test: every `@Entity` class extends `TenantAwareEntity`.
- ArchUnit test: no `@Query(nativeQuery = true)` method without `tenant_id` in the query string.
- Spring Modulith `ApplicationModules.verify()` confirms module isolation.

Multi-Tenant Isolation Tests:

- Test 1: Tenant A inserts 10 records. Tenant B queries — result set is empty.
- Test 2: Tenant A inserts records. Tenant A queries — sees all 10 records.
- Test 3: Mixed tenants in same table. Each tenant query returns only its own data.
- Test 4: `TenantContext` not set — query throws exception (no null tenant allowed).

Performance Benchmarks:

- 100 tenants, 1,000 records each per table. Query with indexed `tenant_id` completes in < 10ms.
- `EXPLAIN ANALYZE` confirms index scan on `tenant_id` for all repository queries.

LGPD Validation:

- Tenant deletion test: `DELETE FROM <table> WHERE tenant_id = ?` removes all tenant data.
- Audit: all tables with PII have `tenant_id` column verified by @ComplianceAgent.

Success Criteria:

- All isolation tests pass on Testcontainers PostgreSQL.
- Zero cross-tenant data leakage in any test scenario.
- Flyway migrations run once per context (not per tenant).
- New tenant onboarding requires zero DDL execution.

---

# 11. Risks and Mitigations

Risk 1:
Description: A query missing `tenant_id` filter exposes cross-tenant data.
Mitigation: Hibernate `@Filter` is activated globally on every session — JPQL and Criteria queries are automatically filtered. Native SQL queries require manual `tenant_id` filter — flagged in code review by @CodeGuardian. Integration tests by @TestAutomator validate isolation for every repository.

Risk 2:
Description: `TenantContext` ThreadLocal leaks between HTTP requests.
Mitigation: `TenantFilter` clears `TenantContext` in the `finally` block. Unit test verifies cleanup. Virtual threads (Java 21) require `ScopedValue` consideration — documented for future evaluation.

Risk 3:
Description: Native SQL queries bypass Hibernate `@Filter`.
Mitigation: ArchUnit rule flags `@Query(nativeQuery = true)` without `tenant_id`. Code review checklist includes native SQL audit. Integration test validates native queries return tenant-scoped results.

Risk 4:
Description: Per-tenant backup/restore is more complex than with schema-per-tenant.
Mitigation: Full database backup is the primary strategy. Per-tenant export scripts (`COPY ... WHERE tenant_id = ?`) can be created for LGPD erasure verification. Acceptable tradeoff for operational simplicity.

Risk 5:
Description: Index on `tenant_id` increases write overhead and storage.
Mitigation: `tenant_id` UUID index adds ~16 bytes per row + B-tree overhead. Negligible for this workload size. Monitored via Prometheus PostgreSQL metrics.

---

# 12. Related ADRs

- [ADR-0001 - Technology Stack and Architecture Foundation](ADR-0001-technology-stack-and-architecture.md) — Defines Spring Boot 4.x, Spring Modulith, PostgreSQL, Clean Architecture.
- [ADR-0002 - Multi-Tenant Database Isolation Strategy](ADR-0002-separacao-banco-por-contexto-multitenancy.md) — Establishes database per bounded context and recommends `tenant_id` discriminator.

- (Future) ADR-0004 — WhatsApp Integration Architecture.
- [ADR-0005 - Multi-Tenancy Architecture](ADR-0005-multi-tenancy-architecture.md)
- (Future) ADR-0006 — Authentication and Authorization with Keycloak.

---

# 13. References


- [Hibernate 6.x Multi-Tenancy — @TenantId](https://docs.jboss.org/hibernate/orm/6.4/userguide/html_single/Hibernate_User_Guide.html#multitenacy)
- [Hibernate @Filter and @FilterDef](https://docs.jboss.org/hibernate/orm/6.4/userguide/html_single/Hibernate_User_Guide.html#pc-filter)
- [PostgreSQL — Schema Management](https://www.postgresql.org/docs/current/ddl-schemas.html)
- [Multi-Tenant SaaS Patterns — Microsoft](https://learn.microsoft.com/en-us/azure/architecture/guide/multitenant/considerations/tenancy-models)
- [Salesforce Multi-Tenancy Architecture](https://developer.salesforce.com/wiki/multi_tenant_architecture)
- Business Requirements: [Visão de produto](../product/business/product-vision.md)
- Agent Factory Specification: [Catálogo de agentes](../agents/README.md)

---

# 14. Decision Lifecycle

Current State: **Accept**

This ADR was accepted on 2026-03-09. It becomes the governing document for the multi-tenancy isolation mechanism within each context database. Any changes to the isolation strategy (e.g., migration to schema-per-tenant for regulatory reasons) require a new ADR that supersedes this one.

---

# 15. Change Log

Version: 1.2
Date: 2026-08-23
Author: Codex / @ObservabilityDev / @SecurityAgent
Changes:
- Reconciled observability with ADR-0012 v1.2: tenant identity stays in protected traces/logs and
  tenant-scoped stores, never in Prometheus labels.

Version: 1.1
Date: 2026-08-22
Author: Codex, @MultiTenantEng, @SecurityOAuth
Changes:
- Clarified the authoritative tenant-context sources: JWT claim for tenant identities, no context
  for global Super Admin and `X-Tenant-ID` only for explicit Super Admin impersonation.

Version: 1.0
Date: 2026-03-08
Author: @AgentOrchestrator, @MultiTenantEng
Changes:
- Initial ADR creation defining `tenant_id` discriminator as the multi-tenancy strategy within each context database.
- Analysis of schema-per-tenant vs. `tenant_id` row-level isolation. `tenant_id` selected because the project is greenfield with no migration cost and requires scalability to unlimited tenants.

---

# 16. Repository Structure

All ADRs are stored in:

```
docs/
  adrs/
    ADR-0001-technology-stack-and-architecture.md
    ADR-0002-separacao-banco-por-contexto-multitenancy.md
    ADR-0003-multitenancy-schema-vs-tenant-id.md
```

Future ADRs will follow the naming convention: `ADR-XXXX-short-title.md`

---

# 17. Review Process

1. This ADR was created in "Accepted" status by @AgentOrchestrator and @MultiTenantEng.
2. Reviewers (@CleanArchitecture, @DomainExpert, @DevOps-Agent, @SecurityOAuth) must validate the `tenant_id` strategy against LGPD requirements, VPS resource constraints, and scalability needs.
3. The startup founders must confirm that row-level isolation is acceptable for their compliance posture.
4. Upon approval, the status changes to "Accepted" and the ADR becomes immutable.
5. If schema-per-tenant is later required (e.g., regulatory mandate), a new ADR must be created and this ADR marked as "Superseded."

---

# 18. Notes

This ADR complements ADR-0002 by providing the detailed technical analysis for the multi-tenancy mechanism choice. While ADR-0002 made the high-level recommendation, this ADR documents the full comparison between schema-per-tenant and `tenant_id` discriminator.

Decision rationale summary:

| Factor | Schema-per-tenant | `tenant_id` (selected) |
|--------|-------------------|------------------------|
| Tenant scale | ~500 tenants max (VPS constraint) | Unlimited |
| Flyway execution | Per tenant × per context | Once per context |
| New tenant DDL | CREATE SCHEMA + migrations | Zero DDL (row insert) |
| Isolation level | Physical (schema boundary) | Logical (row-level filter) |
| Operational complexity | High (N schemas × 5 databases) | Low (1 schema × 5 databases) |
| Microservice readiness | Requires conversion or schema migration | Ready — `tenant_id` travels with data |

Key principles codified by this ADR:

- Every table has `tenant_id UUID NOT NULL` with an index.
- Every entity extends `TenantAwareEntity`.
- Hibernate `@Filter` is the primary isolation mechanism — not developer discipline.
- Native SQL queries must explicitly include `tenant_id` filter.
- `TenantContext` is always cleared after request processing.
