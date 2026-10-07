---
document_id: "ADR-0009"
primary_nature: "Decisao"
objective: "Registrar a decisão arquitetural “Dynamic RBAC Evolution Strategy”, seus motivadores, alternativas e consequências."
scope: "Decisão, componentes, integrações e limites explicitamente descritos em “Dynamic RBAC Evolution Strategy”."
non_objectives: "Não implementar a decisão, substituir requisitos relacionados nem atestar capabilities ou ambientes sem evidência explícita."
owner: "@AgentOrchestrator, @SecurityOAuth"
status: "Accepted"
date: "2026-03-12"
version: "1.5"
keywords: "adr, decisao, arquitetura, dynamic, rbac, evolution, strategy"
related_files: "README.md, ADR-0001-technology-stack-and-architecture.md, ADR-0005-multi-tenancy-architecture.md, ADR-0006-audit-compliance.md, ../../../docs/agents/standards/rbac-frontend-standard.md, ../../../docs/agents/standards/keycloak-frontend-standard.md"
code_references: "menuConfig, ConversationAuditSecurityFilter, TenantContextFilter, PermissionPort, RoleAdminPort, AuthorizationService, useMenuConfig"
principal_statement: "The system will maintain static RBAC as the active solution, with three governing system profiles and the separately inventoried module/technical authorities. `ROLE_TENANT_AUDIT` is the sole entitlement for the Conversation Audit feature and has no implicit inheritance from `ROLE_TENANT_ADMIN` or `ROLE_SUPER_ADMIN`. Local source/configuration gates are closed; persisted Keycloak/session, authenticated backend-real and external rollout gates remain open. When the separate dynamic-RBAC evolution triggers are met, the system will evolve to granular permissions stored in a database, administrable via web panel by the Super Admin and Tenant Admin, with automatic synchronization to Keycloak."
---

# ADR-0009 - Dynamic RBAC Evolution Strategy

- Date: 2026-03-12
- Status: Accepted
- Version: 1.5
- Last updated: 2026-08-22
- Authors / Owners: @AgentOrchestrator, @SecurityOAuth
- Reviewers: @FrontendWeb, @ImplementerCore, @CleanArchitecture, @ComplianceAgent
- Stakeholders: Development Team, Product Owner, Tenant Administrators
- Supersedes: None
- Superseded by: None

---

# 1. Context

The Contador Fiscal Inteligente keeps three governing system profiles in the scope of this ADR. The
third profile was documented before implementation and is now present in the local software and
versioned Keycloak baseline. Persisted-volume reconciliation, session renewal and authenticated
runtime proof remain separate operational gates:

| Role | Profile | Lifecycle at this checkpoint |
|---|---|---|
| `ROLE_SUPER_ADMIN` | Global platform administrator | Implemented baseline |
| `ROLE_TENANT_ADMIN` | Accounting firm administrator (also operates certificates and fiscal data) | Implemented baseline |
| `ROLE_TENANT_AUDIT` | Tenant-scoped, read-only conversation auditor | `IMPLEMENTED / FOCUSED-VERIFIED LOCAL`; live Keycloak/session proof pending |

The count of three refers only to the governing product profiles covered by this evolution
decision. It is **not** the complete inventory of Keycloak/Spring authorities: `ROLE_TENANT_USER`
and module entitlements such as Fiscal, Certificates and Chatbot remain catalogued in
`Role.java`, realm artifacts and REQ-00003/REQ-00004. A future migration must preserve every
static role/entitlement mapping, not only the three governing profiles.

These profiles are documented in requirements [REQ-00003](../product/requirements/REQ-00003-rbac-profile-responsibility-matrix.md) (RBAC Matrix × Profile) and [REQ-00004](../product/requirements/REQ-00004-rbac-security-mapping.md) (Frontend × Backend Security Mapping). The mapping `role → route/functionality` is **hardcoded** in the frontend (`PROTECTED_ROUTES`, `menuConfig` following `../../../docs/agents/standards/rbac-frontend-standard.md`) and backend (`@PreAuthorize`).

**Limitations of the current model:**

1. **Fixed roles:** It is not possible to create custom profiles (e.g., "Intern", "External Auditor", "Partner") without code changes and redeployment.
2. **Static mapping:** Adding a new functionality to a profile requires changing `PROTECTED_ROUTES`, `menuConfig`, `useModuleAccess`, `@PreAuthorize`, and performing a deployment.
3. **No tenant-level granularity:** All tenants use the same set of roles. A firm cannot create specific profiles for its operational needs.
4. **Administration via code:** The Tenant Admin can manage users and assign existing roles (via backend → Keycloak Admin API, per REQ-00004 §5.2), but cannot create new roles or redefine what functionalities each role can access.

**The target set of three governing system profiles meets the current product need** while preserving a
static, auditable and predictable model. `ROLE_TENANT_AUDIT` is a deliberately narrow system role
approved on 2026-08-22. Its source implementation and versioned role/scope contract now exist, but
that does not claim reconciliation of a persisted Keycloak volume, a renewed session or external
environment activation. It does not activate customizable or database-backed RBAC. As the
tenant base grows and accounting firms of different sizes and specializations adopt the platform,
there may still be demand for custom access profiles.

This ADR documents the **evolution strategy** from the static RBAC to a dynamic model, defining
triggers, target architecture, and migration path. Version 1.5 reconciles the local implementation
of the third governing profile and clarifies the complete authority inventory without activating
dynamic RBAC or claiming runtime/external rollout.

---

# 2. Decision Statement

The system will maintain static RBAC as the active solution, with three governing system profiles
and the separately inventoried module/technical authorities.
`ROLE_TENANT_AUDIT` is the sole entitlement for
the Conversation Audit feature and has no implicit inheritance from `ROLE_TENANT_ADMIN` or
`ROLE_SUPER_ADMIN`. Local source/configuration gates are closed; persisted Keycloak/session,
authenticated backend-real and external rollout gates remain open. When the separate dynamic-RBAC evolution
triggers are met, the system will evolve to granular permissions stored in a database,
administrable via web panel by the Super Admin and Tenant Admin, with automatic synchronization to
Keycloak.

The frontend will load `role → functionality` mappings via API instead of using static configuration.

## 2.1 Static Conversation Audit Entitlement (2026-08-22)

The following accepted contract is **IMPLEMENTED / FOCUSED-VERIFIED LOCAL** in the software and
versioned Keycloak artifacts. `ROLE_TENANT_AUDIT` is an immutable, tenant-invitable system role and
the **only** entitlement for Conversation Audit. Its assignment is additive and deliberately
narrow:

- `ROLE_TENANT_ADMIN` alone is denied.
- `ROLE_SUPER_ADMIN` alone is denied, including when an active tenant has been selected.
- A tenant user with `ROLE_TENANT_AUDIT` may access only the active tenant carried by the authenticated tenant context.
- A Super Admin must carry both `ROLE_SUPER_ADMIN` and `ROLE_TENANT_AUDIT` and explicitly impersonate an active tenant. The effective tenant must equal the `{tenantId}` path parameter.
- `ROLE_TENANT_AUDIT` grants no access to any other route, menu, endpoint or administrative capability.

The canonical frontend routes are `/audit` and `/audit/{conversationId}`. The canonical backend surface is limited to:

- `POST /api/v1/tenants/{tenantId}/chatbot/audit/conversations/search`
- `GET /api/v1/tenants/{tenantId}/chatbot/audit/conversations/{conversationId}`
- `GET /api/v1/tenants/{tenantId}/chatbot/audit/conversations/{conversationId}/messages`
- `POST /api/v1/tenants/{tenantId}/chatbot/audit/conversations/{conversationId}/remote-identifier/reveal`

The backend applies the feature-specific `ConversationAuditSecurityFilter` after `TenantContextFilter` and before controller dispatch. This filter must validate the effective tenant, the raw `ROLE_TENANT_AUDIT` authority, the tenant path boundary, API exposure, data-protection readiness and rate limits before conversation data is accessed. The controller keeps a second gate with `@PreAuthorize("hasRole('TENANT_AUDIT')")`. Neither the generic tenant-admin authority nor the tenant-admin authority added during Super Admin impersonation may satisfy these gates.

---

# 3. Decision Drivers

1. **Business Scalability:** Large accounting firms will need custom profiles (Intern, Auditor, Partner) with granular permissions.
2. **Tenant Self-Service:** Tenant Admins must be able to create and manage profiles without depending on the platform's development team.
3. **Deployment Reduction:** Permission changes should not require redeployment. They must be applicable in real-time via the admin panel.
4. **Frontend × Backend Consistency:** The `role → functionality` mapping needs a **single source of truth** (database) consumed by both layers.
5. **Security:** The evolution must follow the principle that the **backend is the authoritative layer** for authorization. The frontend only reflects it visually.
6. **System-role Stability:** A future dynamic migration must preserve the three governing
   profiles, every module/technical authority and their explicit permission boundaries. It must
   not recreate the previously broader Conversation Audit access for Tenant Admin or raw Super
   Admin identities.
7. **Pragmatism (ADR-0001):** Do not implement before there is real demand. Avoid over-engineering in the early stages.

---

# 4. Considered Options

## Option 1: Keep Static RBAC Indefinitely

**Description:** Continue with the three governing profiles plus the current explicit
module/technical authorities. Any further role requires an architectural and RBAC-matrix decision
before code.

**Pros:**
- Zero additional complexity
- Predictable and easy to audit
- No immediate development cost

**Cons:**
- Each new profile requires changes in 6+ files and deployment
- Does not scale for tenants with diverse needs
- The development team becomes a bottleneck for permission changes

## Option 2: Dynamic RBAC via Database (Selected)

**Description:** Granular permissions (`permission`) and customizable profiles (`custom_role`) stored in a database. Backend exposes an administration API. Frontend consumes mappings via API. Keycloak is synchronized via Admin API.

**Pros:**
- Self-service: Tenant Admin creates profiles without deployments
- Granularity: permissions per functionality, not just per module
- Single source of truth in the database
- Frontend and backend consume the same source
- Compatible with governing profiles and module/technical authorities (incremental migration)

**Cons:**
- Additional complexity in the authorization layer
- Need for a permission cache for performance
- Larger attack surface: an admin may accidentally grant excessive permissions
- Significant development cost

## Option 3: RBAC Entirely on Keycloak (Realm Roles + Client Scopes)

**Description:** Create all roles and permissions directly in Keycloak using `realm roles`, `client roles`, and `client scopes`. Frontend and backend read everything from the JWT.

**Pros:**
- Keycloak is the single source of truth
- JWT already carries all permissions
- No additional database needed

**Cons:**
- JWT can become very large with many permissions (overhead on every request)
- Managing granular permissions in the Keycloak UI is complex for Tenant Admins
- Does not allow business logic in permissions (e.g., "can edit only customers in their group")
- Requires exposing a customized Keycloak admin UI or building a complete wrapper
- Permission changes only reflect after a new login (new JWT)

## Option 4: External RBAC Solution (Casbin, Open Policy Agent, Cerbos)

**Description:** Use an external policy engine to evaluate permissions at runtime.

**Pros:**
- Declarative and flexible policies (ABAC, RBAC, ReBAC)
- Complete separation between authorization logic and business logic
- Supports complex scenarios (hierarchies, permission inheritance)

**Cons:**
- Additional infrastructure (would violate ADR-0001's zero-cost constraint in early stages)
- Additional latency on every authorization decision
- Significant learning curve
- Over-engineering for the current scenario

---

# 5. Decision Outcome

**Option 2 (Dynamic RBAC via Database) was selected as the future evolution strategy**, for the following reasons:

1. **Balance:** Offers enough granularity without the complexity of external solutions (OPA, Casbin).
2. **Self-Service:** Allows Tenant Admins to create custom profiles via web panel — meeting the customization demand per firm.
3. **Single Source of Truth:** The database centralizes permissions. Frontend queries via API, backend validates at the authorization layer. Keycloak continues as the identity provider (authentication + base roles).
4. **Compatibility:** The three governing profiles continue as immutable "system roles" and the
   existing module/technical entitlements retain their semantics. Custom profiles are additions.
5. **Pragmatism:** Will not be implemented at the moment (early-stage). Activation triggers are defined in Section 9.

**Rejected alternatives for the future:**
- Option 1 (indefinite static): Does not scale with tenant base growth.
- Option 3 (everything in Keycloak): Inflated JWT, poor administration UX, requires re-login.
- Option 4 (external engine): Over-engineering, infrastructure cost, learning curve.

---

# 6. Consequences

**Positive Consequences:**
- Tenants can customize access profiles without depending on the development team
- Permission changes applied in real-time, without deployment
- Extensible model for future ABAC scenarios (conditional permissions by resource)
- Frontend and backend share a single source of truth for permissions

**Negative Consequences:**
- Additional complexity in the authorization layer (cache, invalidation, synchronization)
- Larger attack surface: misconfigured permissions can expose functionalities
- Need for robust regression tests for the permission matrix
- Migration cost from static mappings to the database

**Neutral Consequences:**
- Keycloak continues as the identity provider, but no longer as the exclusive authorization source
- The three governing profiles become immutable "system roles" in the database; all other static
  role/entitlement mappings are also migrated without semantic loss
- Frontend evolves from a static `menuConfig` to API consumption

---

# 7. Impact

**Architecture:**
- New domain entities: `Permission`, `CustomRole`, `RolePermissionMapping`
- New port: `PermissionPort` (outbound, queries user permissions)
- New port: `RoleAdminPort` (outbound, CRUD roles in Keycloak via Admin API)
- `AuthorizationService` in the backend replaces hardcoded `@PreAuthorize` with dynamic verification
- Frontend: `useModuleAccess` evolves to query the API instead of using local logic

**Infrastructure:**
- New tables in the `saas_tenant` database: `permissions`, `custom_roles`, `role_permission_mappings`
- Redis/in-memory cache for permissions (avoids DB query on every request)
- Keycloak Admin REST API integrated via service account in the backend

**Security:**
- Backend continues as the authoritative layer: `AuthorizationService.hasPermission()` instead of `@PreAuthorize`
- Frontend continues as the visual layer: dynamic menu via API
- Admin UI for permissions protected by `ROLE_SUPER_ADMIN` and `ROLE_TENANT_ADMIN`
- Audit log (ADR-0006) records all permission changes

**Development Process:**
- When adding a new functionality: register `Permission` in seed data instead of editing 6+ files
- Standards updated: `../../../docs/agents/standards/rbac-frontend-standard.md`, `../../../docs/agents/standards/keycloak-frontend-standard.md`

**Data Architecture:**
- Conceptual schema of the new tables:

```sql
-- Granular system permissions
CREATE TABLE permissions (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code            VARCHAR(100) NOT NULL UNIQUE,   -- e.g., 'fiscal:query:read'
    module          VARCHAR(50) NOT NULL,            -- e.g., 'fiscal', 'billing'
    name            VARCHAR(100) NOT NULL,           -- e.g., 'Consult Fiscal Situation'
    description     TEXT,
    frontend_path   VARCHAR(200),                    -- e.g., '/fiscal/query' (associated route)
    is_menu_item    BOOLEAN DEFAULT FALSE,           -- whether it appears as a menu item
    icon            VARCHAR(50),                     -- lucide icon name, if menu item
    display_order   INT DEFAULT 0,
    created_at      TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Customizable roles per tenant
CREATE TABLE custom_roles (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id       UUID,                            -- NULL = system role (global)
    code            VARCHAR(50) NOT NULL,             -- e.g., 'intern', 'auditor'
    keycloak_role   VARCHAR(100) NOT NULL,            -- role name in Keycloak
    name            VARCHAR(100) NOT NULL,            -- e.g., 'Intern'
    description     TEXT,
    is_system       BOOLEAN DEFAULT FALSE,            -- true = non-editable governing/system role
    is_active       BOOLEAN DEFAULT TRUE,
    created_at      TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at      TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(tenant_id, code)
);

-- N:N mapping between roles and permissions
CREATE TABLE role_permission_mappings (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    custom_role_id  UUID NOT NULL REFERENCES custom_roles(id) ON DELETE CASCADE,
    permission_id   UUID NOT NULL REFERENCES permissions(id) ON DELETE CASCADE,
    granted_by      UUID,                            -- user_id who granted it
    granted_at      TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(custom_role_id, permission_id)
);

-- Indexes
CREATE INDEX idx_crp_role ON role_permission_mappings(custom_role_id);
CREATE INDEX idx_crp_permission ON role_permission_mappings(permission_id);
CREATE INDEX idx_cr_tenant ON custom_roles(tenant_id);
CREATE INDEX idx_permissions_module ON permissions(module);
```

---

# 8. AI Agent Considerations (For Autonomous Agent Environments)

**Agent Roles Impacted:**

| Agent | Impact |
|---|---|
| @SecurityOAuth | Implement integration with Keycloak Admin REST API for role CRUD. Synchronize `custom_roles` with Keycloak realm. |
| @ImplementerCore | Implement `PermissionPort`, `AuthorizationService`, role/permission CRUD use cases. |
| @AdapterDev | Implement adapters: Keycloak Admin API client, JPA repositories for `permissions`/`custom_roles`. |
| @FrontendWeb | Evolve sidebar from static `menuConfig` to API consumption. Implement permission management admin UI. |
| @CleanArchitecture | Validate that `PermissionPort` and `RoleAdminPort` respect Clean Architecture (ports in domain, adapters in infra). |
| @TestAutomator | Regression testing for the permission matrix. Integration testing for Keycloak synchronization. |
| @ComplianceAgent | Validate that permission changes are audited (ADR-0006). |

**Operational Considerations:**
- Permissions cached in memory with a 5-minute TTL. Invalidation by event upon permission changes.
- Keycloak sync is asynchronous (eventual consistency) — role created in the DB appears on the next login.
- Human oversight: permission changes recorded in the audit log (ADR-0006).

**Safety Considerations:**
- System roles (`ROLE_SUPER_ADMIN`, `ROLE_TENANT_ADMIN`, `ROLE_TENANT_AUDIT`) are `is_system=true` — neither editable nor deletable.
- `ROLE_TENANT_AUDIT` is tenant-scoped and tenant-invitable. It authorizes only the canonical Conversation Audit UI/API and grants no user-management, tenant-configuration, fiscal, certificate, billing, observability or global administration capability.
- `ROLE_TENANT_ADMIN` and `ROLE_SUPER_ADMIN` do not inherit `ROLE_TENANT_AUDIT`.
- A Super Admin must carry both `ROLE_SUPER_ADMIN` and `ROLE_TENANT_AUDIT` and establish an explicit, active-tenant impersonation context before accessing Conversation Audit. A raw global context remains denied.
- Super Admin has broad platform-administration access, but does not bypass dedicated entitlements such as Conversation Audit. A future `AuthorizationService` must preserve this explicit exception instead of treating `ROLE_SUPER_ADMIN` as an unconditional audit allow.
- Tenant Admin can only create roles and map permissions **within their tenant** — isolation by `tenant_id`.

---

# 9. Implementation Plan

## Current Phase — Static RBAC with Locally Implemented Audit Extension

**Status:** `ROLE_TENANT_AUDIT` is implemented and focused-verified locally across backend,
frontend and the versioned Keycloak contract. Reconciliation of a persisted Keycloak volume,
fresh-session proof, bounded backfill/readiness and authenticated backend-real remain not executed;
HML, PRD and release remain RED.

The implemented local extension exposes the accepted three governing system profiles through
hardcoded mappings in:
- Frontend: `PATHS`, `PROTECTED_ROUTES`, `menuConfig` (`../../../docs/agents/standards/rbac-frontend-standard.md` §10-14)
- Backend: `@PreAuthorize` annotations (`REQ-00004`)

### Evolution Triggers

The migration to dynamic RBAC should be **activated when at least 2 of these triggers are met:**

| # | Trigger | Indicator |
|---|---|---|
| G1 | Tenants requesting custom profiles | ≥3 tenants request profiles outside the governing/static catalog |
| G2 | Frequency of permission changes | ≥2 RBAC changes per month requiring deployment |
| G3 | Functionality growth | ≥15 protected functionalities in the system |
| G4 | Multi-vertical | The platform serves different segments with distinct access needs |
| G5 | Commercial demand | "Customizable profiles" feature becomes a competitive advantage |

---

## Phase 1 — Foundation (when activated)

**Responsible:** @ImplementerCore, @AdapterDev, @SecurityOAuth

1. Create `permissions`, `custom_roles`, `role_permission_mappings` tables via Flyway migration.
2. Seed data: migrate the three governing profiles to `custom_roles` with `is_system=true`.
3. Seed data: inventory and migrate every current module/technical authority without collapsing it
   into a governing profile; map all existing functionalities as `permissions`.
4. Seed data: create `role_permission_mappings` replicating the complete REQ-00003/REQ-00004 mappings.
5. Implement `PermissionPort` and `AuthorizationService`.
6. Implement integration with Keycloak Admin REST API (service account, role CRUD).

**Result:** Database populated. Governing profiles and all static entitlement mappings migrated.
System continues using `@PreAuthorize` in parallel as fallback.

## Phase 2 — Backend Migration

**Responsible:** @ImplementerCore, @SecurityOAuth

1. Replace `@PreAuthorize` with `AuthorizationService.hasPermission()` in use cases.
2. Implement permission cache (in-memory, 5min TTL, invalidation by event).
3. Implement admin endpoints for custom roles and permissions CRUD.
4. Integration tests confirming functional equivalence with the static model.

**Result:** Backend consumes permissions from the database. Keycloak continues managing identity.

## Phase 3 — Frontend Migration

**Responsible:** @FrontendWeb

1. Create `GET /api/v1/me/permissions` endpoint that returns the authenticated user's permissions.
2. Replace static `menuConfig` with API consumption (`useMenuConfig` hook).
3. Replace static `PROTECTED_ROUTES` with API consumption.
4. Implement admin UI: role and permission management (for Super Admin and Tenant Admin).
5. Update `../../../docs/agents/standards/rbac-frontend-standard.md` with the new patterns.

**Result:** Frontend 100% dynamic. Menu and routes controlled by the database.

## Phase 4 — Self-Service Tenant

**Responsible:** @FrontendWeb, @ImplementerCore

1. Tenant Admin UI: create/edit/delete custom roles.
2. Tenant Admin UI: map permissions to roles (visual checklist).
3. Automatic synchronization: role created in DB → created in Keycloak via Admin API.
4. E2E Tests: create role → assign to user → verify access on the frontend.

**Result:** Tenant Admin is self-service for profile management.

---

# 10. Validation

**Validation of Current Phase (static):**
- ✅ Target mappings documented in REQ-00003 and REQ-00004 before implementation
- ✅ `ROLE_TENANT_AUDIT` is non-composite and explicitly scoped in all eight versioned
  realm exports/templates required by the static contract
- ✅ Backend, frontend and invitation-flow source enforce the explicit least-privilege
  Conversation Audit boundary in focused local evidence
- ⬜ Persisted Keycloak reconciliation, fresh-session token and authenticated backend-real prove
  that the same boundary is effective in the live local runtime
- ⬜ AC-AUD-054–055 provide implementation evidence; historical evidence does not satisfy them

**Validation of Evolution (when implemented):**

- All static mappings migrated to the database without loss of functionality
- `AuthorizationService.hasPermission()` produces results identical to `@PreAuthorize` for all
  governing profiles and module/technical authorities
- Frontend `useMenuConfig` via API produces a menu identical to static `menuConfig`
- Tenant Admin creates custom role → assigns to user → user sees correct functionalities
- Permission change reflects in frontend in ≤5 minutes (cache TTL)
- Audit log (ADR-0006) records all role/permission CRUD operations

**Success Criteria:**
- Zero regression in the explicit permissions and denials of governing profiles and all
  module/technical authorities
- Permission check time ≤5ms (p95) with cache
- Tenant Admin creates custom role in ≤2 minutes via UI

---

# 11. Risks and Mitigations

## Risk 1: Premature Over-Engineering

**Description:** Implement dynamic RBAC before there is real demand, consuming development resources with no return.

**Mitigation:**
- This ADR defines explicit triggers (Section 9). Phase 1 only starts when ≥2 triggers are met.
- The current static model is sufficient and will not be changed until triggers are met.

## Risk 2: Misconfigured Permissions by Tenant Admin

**Description:** Tenant Admin may accidentally grant excessive permissions to a profile, compromising security.

**Mitigation:**
- System roles are `is_system=true` and non-editable.
- Super Admin can define "maximum permissions" per plan (permission ceiling).
- Audit log records all permission changes for traceability.
- UI displays visual warnings when granting sensitive permissions.

## Risk 3: Inconsistency between Database and Keycloak

**Description:** Role synchronization between the local DB and Keycloak might fail, causing divergence.

**Mitigation:**
- Database is the primary source. Keycloak is synchronized via a periodic reconciliation job.
- Health check verifies DB ↔ Keycloak equivalence.
- In case of divergence, backend resolves via database (authority).

## Risk 4: Performance on Permission Verification

**Description:** Querying the database on every request to verify permissions can degrade performance.

**Mitigation:**
- In-memory cache with 5-minute TTL.
- Invalidation by event (ApplicationEvent) when changing permissions.
- Optimized indexes on mapping tables.

## Risk 5: Migration of Static Mappings

**Description:** When migrating from static `@PreAuthorize` to dynamic `AuthorizationService`, there may be security gaps.

**Mitigation:**
- Parallel migration: keep `@PreAuthorize` as a fallback during transition.
- Equivalence testing: script that compares DB permissions with REQ-00004 mappings.
- Feature flag to enable/disable the new system per tenant.

---

# 12. Related ADRs

- [ADR-0001 - Technology Stack and Architecture Foundation](ADR-0001-technology-stack-and-architecture.md) — Zero-cost constraint and Spring Modulith
- [ADR-0005 - Multi-Tenancy Architecture](ADR-0005-multi-tenancy-architecture.md) — Keycloak, JWT, tenant_id, user management
- [ADR-0006 - Audit and Compliance Strategy](ADR-0006-audit-compliance.md) — Audit log for permission changes

---

# 13. References

**Requirements:**
- [REQ-00003 — RBAC Responsibility Matrix × Profile](../product/requirements/REQ-00003-rbac-profile-responsibility-matrix.md)
- [REQ-00004 — Frontend × Backend Security Mapping](../product/requirements/REQ-00004-rbac-security-mapping.md)
- [REQ-00005 — Features by Plan Matrix](../product/requirements/REQ-00005-plan-feature-matrix.md)

**Standards:**
- [../../../docs/agents/standards/rbac-frontend-standard.md](../../../docs/agents/standards/rbac-frontend-standard.md) — Frontend RBAC standards (future sections 10-14)
- [../../../docs/agents/standards/keycloak-frontend-standard.md](../../../docs/agents/standards/keycloak-frontend-standard.md) — Keycloak JS Integration

**External:**
- [Keycloak Admin REST API](https://www.keycloak.org/docs-api/latest/rest-api/) — Programmatic management API for roles and users
- [Spring Security Method Security](https://docs.spring.io/spring-security/reference/servlet/authorization/method-security.html) — `@PreAuthorize` annotations

---

# 14. Decision Lifecycle

Current State: **Accepted**

The target static system-role decision and the future evolution strategy are accepted. The Audit
extension is implemented in the local source/configuration baseline, while live identity/session
and rollout evidence remain pending. Dynamic-RBAC phases 1-4 remain separately deferred until the
triggers in Section 9 are met; this reconciliation activates neither those dynamic phases nor an
external environment.

---

# 15. Change Log

Version: 1.5
Date: 2026-08-22
Author: @AgentOrchestrator, @SecurityOAuth
Changes:
- Clarified that “three” counts governing product profiles, not the complete authority inventory;
  the future dynamic migration must preserve every module/technical entitlement.

---

Version: 1.4
Date: 2026-08-22
Author: @AgentOrchestrator, @SecurityOAuth
Changes:
- Split static source/artifact validation from persisted-volume, fresh-session and authenticated
  runtime validation.
- Marked the eight versioned realm/template contracts and focused local software boundary as
  complete without promoting AC-AUD-054–055 or release.

---

Version: 1.3
Date: 2026-08-22
Author: @AgentOrchestrator, @SecurityOAuth
Changes:
- Reconciled the post-freeze local backend/frontend implementation and focused evidence for
  `ROLE_TENANT_AUDIT`.
- Recorded the versioned Keycloak role/scope contract as statically verified while keeping
  persisted-volume/session, backfill/readiness, backend-real, HML, PRD and release gates open.

---

Version: 1.2
Date: 2026-08-22
Author: @AgentOrchestrator, @SecurityOAuth
Changes:
- Corrected lifecycle wording so the accepted `ROLE_TENANT_AUDIT` target is not presented as an
  already active runtime capability.
- Added explicit pending implementation/evidence gates while preserving the accepted matrix and
  the historical static baseline.

---

Version: 1.1
Date: 2026-08-22
Author: @AgentOrchestrator, @SecurityOAuth
Changes:
- Added `ROLE_TENANT_AUDIT` as the third immutable static system role.
- Established it as the only Conversation Audit entitlement, without inheritance from Tenant Admin or Super Admin.
- Required explicit active-tenant impersonation for identities combining Super Admin and Tenant Audit.
- Recorded canonical `/audit` UI routes, the four canonical API operations, and the dedicated two-layer backend gate.
- Preserved the deferred dynamic-RBAC migration strategy.

---

Version: 1.0
Date: 2026-03-12
Author: @AgentOrchestrator, @SecurityOAuth
Changes:
- Initial ADR creation
- Definition of the evolution strategy from static to dynamic RBAC
- Conceptual data model for `permissions`, `custom_roles`, `role_permission_mappings`
- Explicit activation triggers (5 criteria)
- 4-phase implementation plan
- Analysis of 4 alternative options with trade-offs

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
    ADR-0006-audit-compliance.md
    ADR-0007-multi-provider-llm-integration.md
    ADR-0008-stripe-billing-subscription.md
    ADR-0009-dynamic-rbac-evolution.md          ← This ADR
```

---

# 17. Review Process

1. This ADR was created in "Proposed" state by @AgentOrchestrator and @SecurityOAuth and later accepted; versions 1.1–1.2 record the strict third system-role target and its pending runtime lifecycle.
2. Reviewers must validate:
   - Sufficiency of the 5 activation triggers
   - Feasibility of the conceptual data model
   - Backward compatibility with the governing profiles and the complete static entitlement set
   - Integration with Keycloak Admin API
   - Alignment with ADR-0005 (multi-tenancy) and ADR-0006 (audit)
3. Product Owner must confirm that the triggers reflect the business strategy.
4. The dynamic-RBAC phases do not require immediate implementation. The separately authorized
   `ROLE_TENANT_AUDIT` extension is implemented locally, but operational and external evidence
   remains governed by REQ-00041 and TP-00008.
5. `ROLE_CONTADOR` was unified into `ROLE_TENANT_ADMIN` in the historical v2.0 RBAC matrix. On
   2026-08-22, `ROLE_TENANT_AUDIT` was accepted as the third narrow web system-role target; this
   local implementation does not claim that the target is active in a persisted or external
   runtime.

---

# 18. Notes

## Current Model vs. Future Model — Visual Comparison

```
CURRENT MODEL (Static)
========================
Keycloak → JWT with fixed roles → Frontend reads JWT → hardcoded menuConfig → Sidebar
                                → Backend reads JWT → hardcoded @PreAuthorize → Endpoint

FUTURE MODEL (Dynamic)
========================
Keycloak → JWT with roles     → Frontend queries API → dynamic menu → Sidebar
                              → Backend queries DB   → AuthorizationService → Endpoint
                                          ↑
                              Admin UI → CRUD roles/permissions → DB (single source)
                                                                  ↓
                                                      Sync → Keycloak Admin API
```

## Permission Administration Flow (Future)

```
1. Super Admin accesses: Admin → Permissions → Roles
2. Creates role "Intern" with selected permissions (checklist)
3. Backend saves to custom_roles + role_permission_mappings
4. Backend syncs role to Keycloak via Admin API
5. Tenant Admin assigns "Intern" role to a new user
6. New user logs in → JWT has "Intern" role
7. Frontend queries GET /api/v1/me/permissions → builds menu/routes
8. Backend checks AuthorizationService.hasPermission() → allows/denies
```
