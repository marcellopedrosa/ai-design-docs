---
document_id: "RBAC-FRONTEND-STANDARD"
primary_nature: "Regra"
objective: "Definir regras reutilizáveis e verificáveis para RBAC Frontend."
scope: "Representação e aplicação de permissões e perfis de acesso na interface."
non_objectives: "Não criar requisitos de produto, decisões arquiteturais concretas ou procedimentos fora do escopo deste standard."
owner: "Arquitetura e Qualidade"
status: "Active"
date: "2026-08-25"
version: "1.8"
last_reviewed: "2026-09-11"
keywords: "rbac, frontend, standard, standard"
related_files: "./README.md, ./keycloak-frontend-standard.md, ./i18n-standard.md, ./nextjs-standard.md, ../../adrs/ADR-0050-rbac-sod-aprovacoes-financeiras.md, docs/architecture/rbac-access-control-matrix.md, docs/product/requirements/REQ-00003-rbac-profile-responsibility-matrix.md, docs/product/requirements/REQ-00004-rbac-security-mapping.md, docs/product/requirements/REQ-00041-chatbot-conversation-audit.md, docs/product/requirements/REQ-00043-conversation-audit-data-governance.md, docs/product/use-cases/UC-00035-chatbot-conversation-audit.md"
code_references: "src/lib/permissions.ts, src/lib/paths.ts, src/lib/protected-routes.ts, src/lib/menu-config.ts, src/i18n/messages/*/navigation.json, src/hooks/useModuleAccess.ts, backend/, frontend/"
principal_statement: "A política de retenção de /audit é exclusiva da role bruta ROLE_SUPER_ADMIN sob personificação ativa; ROLE_TENANT_ADMIN nunca recebe essa capability, enquanto conversas e aliases permanecem ROLE_TENANT_AUDIT-only."
---

# RBAC Frontend Patterns Standard — @FrontendWeb / @UIIntegrator

> **Mandatory rules** for implementing Role-Based Access Control in the frontend UI. This standard builds upon [`keycloak-frontend-standard.md`](./keycloak-frontend-standard.md) (which provides `useAuth`, `hasRole`, `hasEffectiveRole`, `hasScope`, `ProtectedRoute`, `PermissionGate`). This standard defines **how to organize permissions, map them to UI elements, and enforce RBAC across the application**.

> **Prerequisite:** Read [`keycloak-frontend-standard.md`](./keycloak-frontend-standard.md) first.

> **Version:** 1.7 — **Last updated:** 2026-09-09. This revision defines capability-level
> authorization for the `/audit` shell: Audit reads conversations, while retention is exclusive
> to a raw Super Admin identity with an active tenant impersonation. Tenant Admin never inherits
> retention access.

---

## 1. Permission Model — Roles vs. Scopes

### Definitions

| Concept | Source | Example | Frontend Usage |
|---|---|---|---|
| **Role** | Keycloak realm/client role | `ROLE_FISCAL_READER`, `ROLE_FISCAL_ADMIN`, `ROLE_TENANT_ADMIN`, `ROLE_TENANT_AUDIT` | Route protection, menu visibility |
| **Scope** | OAuth2 scope in token | `fiscal:read`, `fiscal:write`, `tenant:manage` | Action-level guards (buttons, forms) |

### Rules

1. **Roles** control **page-level** access (which pages you can see).
2. **Scopes** control **action-level** access (which operations you can perform).
3. A user may have a role that grants multiple scopes. Always check the most granular level.
4. **Never** invent roles or scopes in the frontend. They must match `@SecurityOAuth`'s Keycloak configuration.
5. Frontend RBAC is **visual-only** (hide/disable UI). The **backend always enforces** authorization.

> ⚠ Frontend RBAC is a UX enhancement, not a security boundary. The backend `@PreAuthorize` is the authoritative enforcement.

---

## 2. Permission Registry

Centralize all permission constants in a single file to avoid string duplication:

```tsx
// src/lib/permissions.ts

// ---- Roles ----
export const ROLES = {
  // Global
  SUPER_ADMIN: 'ROLE_SUPER_ADMIN',
  TENANT_ADMIN: 'ROLE_TENANT_ADMIN',
  TENANT_AUDIT: 'ROLE_TENANT_AUDIT',
  TENANT_USER: 'ROLE_TENANT_USER',

  // Fiscal module
  FISCAL_READER: 'ROLE_FISCAL_READER',
  FISCAL_ADMIN: 'ROLE_FISCAL_ADMIN',

  // Certificate module
  CERT_MANAGER: 'ROLE_CERT_MANAGER',

  // Chatbot module
  CHATBOT_OPERATOR: 'ROLE_CHATBOT_OPERATOR',
  CHATBOT_ADMIN: 'ROLE_CHATBOT_ADMIN',
} as const;

export type Role = (typeof ROLES)[keyof typeof ROLES];

// ---- Scopes ----
export const SCOPES = {
  // Fiscal
  FISCAL_READ: 'fiscal:read',
  FISCAL_WRITE: 'fiscal:write',

  // Certificate
  CERT_READ: 'certificate:read',
  CERT_WRITE: 'certificate:write',

  // Billing
  BILLING_READ: 'billing:read',
  BILLING_WRITE: 'billing:write',

  // Tenant
  TENANT_MANAGE: 'tenant:manage',

  // Chatbot
  CHATBOT_READ: 'chatbot:read',
  CHATBOT_WRITE: 'chatbot:write',
} as const;

export type Scope = (typeof SCOPES)[keyof typeof SCOPES];
```

### Rules

1. **All** role and scope strings used in the frontend **must** come from `src/lib/permissions.ts`.
2. **Never** use raw strings like `'ROLE_FISCAL_READER'` directly in components. Import from `ROLES`.
3. This file is the **single source of truth** in the frontend. It must mirror `@SecurityOAuth`'s Keycloak realm configuration.
4. When `@SecurityOAuth` adds a new role or scope, `permissions.ts` must be updated.

---

## 3. Permission Hooks

### usePermission — Single Check

```tsx
// src/hooks/usePermission.ts
'use client';

import { useMemo } from 'react';
import { useAuth } from '@/hooks/useAuth';
import type { Role, Scope } from '@/lib/permissions';

interface UsePermissionOptions {
  roles?: Role[];
  scopes?: Scope[];
  requireAll?: boolean; // true = AND logic (default), false = OR logic
}

export const usePermission = ({
  roles = [],
  scopes = [],
  requireAll = true,
}: UsePermissionOptions): boolean => {
  const { hasEffectiveRole, hasScope, isAuthenticated } = useAuth();

  return useMemo(() => {
    if (!isAuthenticated) return false;

    const checkFn = requireAll ? 'every' : 'some';

    const rolesOk =
      roles.length === 0 || roles[checkFn]((r) => hasEffectiveRole(r));
    const scopesOk =
      scopes.length === 0 || scopes[checkFn]((s) => hasScope(s));

    return requireAll ? rolesOk && scopesOk : rolesOk || scopesOk;
  }, [isAuthenticated, roles, scopes, requireAll, hasEffectiveRole, hasScope]);
};
```

### useModuleAccess — Module-Level Access Map

```tsx
// src/hooks/useModuleAccess.ts
'use client';

import { useMemo } from 'react';
import { useAuth } from '@/hooks/useAuth';
import { useTenant } from '@/hooks/useTenant';
import { ROLES } from '@/lib/permissions';
import { useImpersonateStore } from '@/stores/useImpersonateStore';

export interface ModuleAccessMap {
  tenants: { canView: boolean; canManage: boolean };
  fiscal: { canView: boolean; canAdmin: boolean };
  certificates: { canView: boolean; canManage: boolean };
  billing: { canView: boolean; canAdmin: boolean };
  chatbot: { canView: boolean; canAdmin: boolean };
  conversationAudit: {
    canAccessShell: boolean;
    canReadConversations: boolean;
    canManageRetention: boolean;
  };
  clients: { canView: boolean; canManage: boolean };
  tenantSettings: { canAccess: boolean };
}

export const useModuleAccess = (): ModuleAccessMap => {
  const { hasRole, hasEffectiveRole } = useAuth();
  const { tenantId } = useTenant();
  const selectedTenantId = useImpersonateStore((state) => state.selectedTenantId);

  return useMemo(() => {
    const hasEffectiveTenant = Boolean(tenantId);
    const canReadConversations =
      hasEffectiveTenant && hasEffectiveRole(ROLES.TENANT_AUDIT);
    const canManageRetention =
      hasEffectiveTenant &&
      Boolean(selectedTenantId) &&
      hasRole(ROLES.SUPER_ADMIN);

    return {
      tenants: {
        canView: hasEffectiveRole(ROLES.SUPER_ADMIN),
        canManage: hasEffectiveRole(ROLES.SUPER_ADMIN),
      },
      fiscal: {
        canView:
          hasEffectiveRole(ROLES.FISCAL_READER) ||
          hasEffectiveRole(ROLES.FISCAL_ADMIN) ||
          hasEffectiveRole(ROLES.TENANT_ADMIN),
        canAdmin:
          hasEffectiveRole(ROLES.FISCAL_ADMIN) || hasEffectiveRole(ROLES.TENANT_ADMIN),
      },
      certificates: {
        canView:
          hasEffectiveRole(ROLES.CERT_MANAGER) || hasEffectiveRole(ROLES.TENANT_ADMIN),
        canManage:
          hasEffectiveRole(ROLES.CERT_MANAGER) || hasEffectiveRole(ROLES.TENANT_ADMIN),
      },
      billing: {
        canView: hasEffectiveRole(ROLES.TENANT_ADMIN),
        canAdmin: hasEffectiveRole(ROLES.TENANT_ADMIN),
      },
      chatbot: {
        canView:
          hasEffectiveRole(ROLES.CHATBOT_OPERATOR) ||
          hasEffectiveRole(ROLES.CHATBOT_ADMIN) ||
          hasEffectiveRole(ROLES.TENANT_ADMIN) ||
          hasEffectiveRole(ROLES.SUPER_ADMIN),
        canAdmin:
          hasEffectiveRole(ROLES.CHATBOT_ADMIN) ||
          hasEffectiveRole(ROLES.TENANT_ADMIN) ||
          hasEffectiveRole(ROLES.SUPER_ADMIN),
      },
      conversationAudit: {
        canAccessShell: canReadConversations || canManageRetention,
        canReadConversations,
        canManageRetention,
      },
      clients: {
        canView:
          hasEffectiveRole(ROLES.TENANT_ADMIN) || hasEffectiveRole(ROLES.SUPER_ADMIN),
        canManage:
          hasEffectiveRole(ROLES.TENANT_ADMIN) || hasEffectiveRole(ROLES.SUPER_ADMIN),
      },
      tenantSettings: {
        canAccess:
          hasEffectiveRole(ROLES.TENANT_ADMIN) || hasEffectiveRole(ROLES.SUPER_ADMIN),
      },
    };
  }, [hasEffectiveRole, hasRole, selectedTenantId, tenantId]);
};
```

### Rules

1. `usePermission` is for **specific checks** (buttons, form fields).
2. `useModuleAccess` is for **navigation/sidebar** — returns the full access map.
3. Both hooks **must** be memoized to avoid unnecessary re-renders.
4. **Never** call `useAuth().hasRole()` directly in render logic. Use these hooks.
5. Tenant-scoped capabilities normally combine the **effective** role set with an effective tenant
   context. The retention capability is the explicit exception: it requires both raw
   `ROLE_SUPER_ADMIN` and non-null `selectedTenantId`; effective `ROLE_TENANT_ADMIN` is never a
   substitute. This raw-role check belongs in the centralized capability policy, never ad hoc in
   render logic.
6. `conversationAudit.canAccessShell` is only an OR gate for the page shell. Each tab and each
   request must use `canReadConversations` or `canManageRetention`; shell access never grants the
   other capability.
7. A Tenant Admin that also has `ROLE_TENANT_AUDIT` sees only `Conversas`; only a raw Super Admin
   under active impersonation may see `Política de retenção`, and it sees both tabs only when Audit
   is also explicit in the raw token.

---

## 4. Sidebar & Navigation Filtering

The sidebar **must** hide menu items the user has no access to. The compact example below includes
the dedicated Audit entitlement; the canonical production implementation is the data-driven
`menuConfig`/`getVisibleMenuConfig` pattern in Section 12.

```tsx
// src/components/layout/Sidebar.tsx
'use client';

import { useModuleAccess } from '@/hooks/useModuleAccess';
import { PATHS } from '@/lib/paths';
import {
  FileText,
  Shield,
  CreditCard,
  MessageCircle,
  Search,
  Settings,
  type LucideIcon,
} from 'lucide-react';

interface MenuItem {
  label: string;
  href: string;
  icon: LucideIcon;
  visible: boolean;
}

interface MenuGroup {
  title: string;
  items: MenuItem[];
}

export const Sidebar = () => {
  const access = useModuleAccess();

  const menuGroups: MenuGroup[] = [
    {
      title: 'Operações',
      items: [
        {
          label: 'Consulta Fiscal',
          href: PATHS.FISCAL_QUERY,
          icon: FileText,
          visible: access.fiscal.canView,
        },
        {
          label: 'Certificados',
          href: PATHS.CERTIFICATES,
          icon: Shield,
          visible: access.certificates.canView,
        },
        {
          label: 'Chatbot',
          href: PATHS.SETTINGS_CHATBOT,
          icon: MessageCircle,
          visible: access.chatbot.canView,
        },
        {
          label: 'Auditoria de Conversas',
          href: PATHS.AUDIT,
          icon: Search,
          visible: access.conversationAudit.canAccessShell,
        },
      ],
    },
    {
      title: 'Administração',
      items: [
        {
          label: 'Faturamento',
          href: PATHS.BILLING,
          icon: CreditCard,
          visible: access.billing.canView,
        },
        {
          label: 'Configurações',
          href: PATHS.SETTINGS,
          icon: Settings,
          visible: access.tenantSettings.canAccess,
        },
      ],
    },
  ];

  return (
    <nav aria-label="Menu principal">
      {menuGroups.map((group) => {
        const visibleItems = group.items.filter((item) => item.visible);
        if (visibleItems.length === 0) return null;

        return (
          <div key={group.title}>
            <h3 className="text-xs font-semibold text-neutral-400 uppercase tracking-wider px-4 mt-6">
              {group.title}
            </h3>
            <ul>
              {visibleItems.map((item) => (
                <li key={item.href}>
                  <a href={item.href} className="flex items-center gap-3 px-4 py-2.5 rounded-lg text-sm font-medium text-neutral-600 hover:bg-neutral-200/50 hover:text-neutral-800">
                    <item.icon className="w-5 h-5" />
                    {item.label}
                  </a>
                </li>
              ))}
            </ul>
          </div>
        );
      })}
    </nav>
  );
};
```

### Rules

1. Menu items with `visible: false` are **never** rendered. Not hidden via CSS, not rendered at all.
2. Menu groups with zero visible items are **never** rendered.
3. **Never** show a disabled/grayed-out menu item the user cannot access. Remove it entirely.
4. Sidebar visibility comes from the centralized policy: the production sidebar uses
   `menuConfig` + `getVisibleMenuConfig`; `useModuleAccess()` exposes the same policy for
   module-level checks. The retention entry combines effective Audit with the centrally declared
   raw-Super alternative and tenant-context predicate. Ad-hoc raw-role conditionals remain
   forbidden.

---

## 5. Action-Level Guards — Buttons, Forms, and Links

### Pattern: Guard a Destructive Action

```tsx
import { PermissionGate } from '@/components/auth/PermissionGate';
import { ROLES, SCOPES } from '@/lib/permissions';

// ✅ CORRECT — Delete button only visible to admins
<PermissionGate roles={[ROLES.FISCAL_ADMIN]} scopes={[SCOPES.FISCAL_WRITE]}>
  <button onClick={handleDelete} className="text-error">
    Excluir Consulta
  </button>
</PermissionGate>

// ✅ CORRECT — Edit button visible but disabled for read-only users
const canEdit = usePermission({ scopes: [SCOPES.FISCAL_WRITE] });

<button onClick={handleEdit} disabled={!canEdit} className={!canEdit ? 'opacity-50 cursor-not-allowed' : ''}>
  Editar
</button>
```

### Pattern: Guard a Form Section

```tsx
import { usePermission } from '@/hooks/usePermission';
import { SCOPES } from '@/lib/permissions';

export const ClientForm = () => {
  const canEditBilling = usePermission({ scopes: [SCOPES.BILLING_WRITE] });

  return (
    <form>
      {/* Always visible */}
      <fieldset>
        <legend>Dados Gerais</legend>
        <input name="name" />
        <input name="documento" />
      </fieldset>

      {/* Only visible for billing admins */}
      {canEditBilling && (
        <fieldset>
          <legend>Dados de Faturamento</legend>
          <input name="billingEmail" />
          <input name="paymentMethod" />
        </fieldset>
      )}
    </form>
  );
};
```

### Rules

1. **Read-only data** → show to all who have the module role, but **disable** edit actions.
2. **Destructive actions** (delete, revoke, cancel) → hide completely with `PermissionGate`.
3. **Create/Edit forms** → guard the submit button, or hide entire form sections.
4. **Never** remove data from a view that the user should be able to read. Only hide actions.
5. Use `usePermission` hook for conditional logic. Use `PermissionGate` for JSX blocks.

---

## 6. Route-Level RBAC with Next.js App Router

### Layout-Based Protection

```
src/app/
├── (public)/           # No auth required
│   ├── login/
│   └── layout.tsx      # Public layout (no sidebar)
├── (auth)/             # Requires authentication (any role)
│   ├── layout.tsx      # Wraps with <ProtectedRoute>, includes sidebar
│   ├── dashboard/
│   └── profile/
├── (fiscal)/           # Requires FISCAL_READER role
│   ├── layout.tsx      # Wraps with <ProtectedRoute requiredRoles={[ROLES.FISCAL_READER]}>
│   └── query/
├── (admin)/            # Requires TENANT_ADMIN role
│   ├── layout.tsx      # Wraps with <ProtectedRoute requiredRoles={[ROLES.TENANT_ADMIN]}>
│   └── settings/
```

### Layout Pattern

```tsx
// src/app/(fiscal)/layout.tsx
'use client';

import { ProtectedRoute } from '@/components/auth/ProtectedRoute';
import { AppShell } from '@/components/layout/AppShell';
import { ROLES } from '@/lib/permissions';

export default function FiscalLayout({ children }: { children: React.ReactNode }) {
  return (
    <ProtectedRoute requiredRoles={[ROLES.FISCAL_READER]}>
      <AppShell>{children}</AppShell>
    </ProtectedRoute>
  );
}
```

### Rules

1. Route groups map to **role requirements**. Each group has its own layout with `ProtectedRoute`.
2. Nested route groups inherit parent protection unless an approved capability split defines a
   stricter child policy. `/audit` is the canonical example: its shell is shared, while every
   conversation child remains Audit-only.
3. **Public pages** go in `(public)/` group — no `ProtectedRoute` wrapper.
4. **Authenticated-but-any-role** pages go in `(auth)/` group.
5. **Never** leave a page without explicit route group assignment.

---

## 7. Forbidden & Unauthorized Pages

### ForbiddenPage (403)

```tsx
// src/components/auth/ForbiddenPage.tsx
'use client';

import { ShieldAlert } from 'lucide-react';
import { useAuth } from '@/hooks/useAuth';

export const ForbiddenPage = () => {
  const { user } = useAuth();

  return (
    <div className="flex flex-col items-center justify-center min-h-[60vh] gap-4">
      <ShieldAlert className="w-16 h-16 text-error" />
      <h1 className="text-2xl font-bold text-neutral-900">
        Acesso Negado
      </h1>
      <p className="text-neutral-500 text-center max-w-md">
        Você não tem permissão para acessar esta página.
        {user && (
          <span className="block mt-2 text-sm">
            Usuário: {user.username}
          </span>
        )}
      </p>
      <a href="/" className="px-4 py-2 bg-primary text-white rounded-md hover:bg-primary-dark">
        Voltar ao início
      </a>
    </div>
  );
};
```

### Rules

1. **Never** show which role was required (security through obscurity for role names).
2. **Always** show the current user's name so they know which account is logged in.
3. Provide a "Go back" or "Go home" action.
4. Log the 403 attempt for auditing (via `@ObservabilityDev` frontend telemetry, if configured).

---

## 8. Role-to-Feature Mapping Table

This table must be kept in sync with `@SecurityOAuth`'s Keycloak realm configuration.
The detailed AS-IS inventory of routes, menus, local guards and known drift is the
[central RBAC access-control matrix](../../architecture/rbac-access-control-matrix.md).

| Role | Module Access | Allowed Scopes | UI Visibility |
|---|---|---|---|
| `ROLE_SUPER_ADMIN` | Global platform administration; tenant workspace only under explicit impersonation | Administrative scopes explicitly mapped per module | Global administration without impersonation; only the raw role plus active tenant impersonation grants the “Política de retenção” tab; Audit remains explicit and is never inferred |
| `ROLE_TENANT_ADMIN` | Tenant administration, Billing workspace and explicitly mapped operational modules | Module-specific scopes | Never sees or operates the retention policy; reaches `/audit` only when it also has `ROLE_TENANT_AUDIT`, in which case it sees only “Conversas” |
| `ROLE_TENANT_AUDIT` | Conversation Audit | Read/search/detail/timeline/reveal operations defined by the audit contract | Opens `/audit` only on the “Conversas” tab and may access `/audit/{conversationId}`; cannot manage retention |
| `ROLE_FISCAL_READER` | Fiscal | `fiscal:read` | Fiscal query (read-only) |
| `ROLE_FISCAL_ADMIN` | Fiscal | `fiscal:read`, `fiscal:write` | Fiscal query + admin actions |
| `ROLE_CERT_MANAGER` | Certificates | `certificate:read`, `certificate:write` | Certificate management; current navigation gap is tracked in the AS-IS matrix |
| `ROLE_CHATBOT_OPERATOR` | Chatbot | `chatbot:read` | Intended operational bundle; current route/menu gap is tracked in the AS-IS matrix |
| `ROLE_CHATBOT_ADMIN` | Chatbot | `chatbot:read`, `chatbot:write` | Intended administrative bundle; current route/menu gap is tracked in the AS-IS matrix |
| `ROLE_TENANT_USER` | Base tenant self-service | Module-specific read scopes | Dashboard, basic fiscal journey and subscription self-service as mapped AS-IS |

### Rules

1. This table is **documentation only**. The runtime source is `permissions.ts` + Keycloak token.
2. `ROLE_TENANT_ADMIN` has no universal override and never manages the retention policy. It can
   read conversations only when `ROLE_TENANT_AUDIT` is also explicit.
3. `ROLE_TENANT_AUDIT` is tenant-scoped and read-only. `ROLE_SUPER_ADMIN` may use it only when the raw token contains Audit and an explicit tenant impersonation is active; neither role is inferred client-side.
4. When `@SecurityOAuth` adds a new bounded context, this table, `permissions.ts`, `useModuleAccess`, and the sidebar must all be updated.
5. Super Admin impersonation never creates a wildcard. Billing requires a single effective tenant and backend validation of canonical header/path equality; sensitive actions retain the ADR-0050 controls.

---

## 9. Testing RBAC in the Frontend

### Unit Test Pattern

```tsx
// __tests__/components/auth/PermissionGate.test.tsx
import { render, screen } from '@testing-library/react';
import { PermissionGate } from '@/components/auth/PermissionGate';
import { ROLES } from '@/lib/permissions';
import { AuthContext } from '@/providers/AuthProvider';

const renderWithAuth = (roles: string[], scopes: string[], ui: React.ReactElement) => {
  const mockAuthValue = {
    isAuthenticated: true,
    isLoading: false,
    user: { id: '1', username: 'test', tenantId: 't1', roles, scopes },
    token: 'mock-token',
    login: vi.fn(),
    logout: vi.fn(),
    hasRole: (r: string) => roles.includes(r),
    hasEffectiveRole: (r: string) => roles.includes(r),
    hasScope: (s: string) => scopes.includes(s),
  };

  return render(
    <AuthContext.Provider value={mockAuthValue}>{ui}</AuthContext.Provider>,
  );
};

describe('PermissionGate', () => {
  it('renders children when user has required role', () => {
    renderWithAuth([ROLES.FISCAL_ADMIN], [], (
      <PermissionGate roles={[ROLES.FISCAL_ADMIN]}>
        <button>Delete</button>
      </PermissionGate>
    ));
    expect(screen.getByText('Delete')).toBeInTheDocument();
  });

  it('hides children when user lacks required role', () => {
    renderWithAuth([ROLES.FISCAL_READER], [], (
      <PermissionGate roles={[ROLES.FISCAL_ADMIN]}>
        <button>Delete</button>
      </PermissionGate>
    ));
    expect(screen.queryByText('Delete')).not.toBeInTheDocument();
  });

  it('renders fallback when user lacks permission', () => {
    renderWithAuth([], [], (
      <PermissionGate roles={[ROLES.FISCAL_ADMIN]} fallback={<span>No access</span>}>
        <button>Delete</button>
      </PermissionGate>
    ));
    expect(screen.getByText('No access')).toBeInTheDocument();
  });
});
```

### E2E Test Pattern (Playwright)

```tsx
// e2e/rbac/fiscal-access.spec.ts
import { test, expect } from '@playwright/test';
import { loginAs } from '../helpers/auth.helper';

test('FISCAL_READER can see fiscal query but not delete button', async ({ page }) => {
  await loginAs(page, 'fiscal-reader-user');
  await page.goto('/fiscal/query');

  await expect(page.getByLabel('Documento')).toBeVisible();
  await expect(page.getByTestId('delete-button')).not.toBeVisible();
});

test('TENANT_AUDIT sees conversations but not retention policy', async ({ page }) => {
  await loginAs(page, 'tenant-audit-user');
  await page.goto('/audit');

  await expect(page.getByRole('heading', { name: 'Auditoria de Conversas' })).toBeVisible();
  await expect(page.getByRole('tab', { name: 'Conversas' })).toBeVisible();
  await expect(page.getByRole('tab', { name: 'Política de retenção' })).not.toBeVisible();
});

test('TENANT_ADMIN cannot open the audit shell or request either capability', async ({ page }) => {
  await loginAs(page, 'tenant-admin-without-audit');
  const conversationRequests: string[] = [];
  const retentionRequests: string[] = [];
  page.on('request', (request) => {
    if (request.url().includes('/chatbot/audit/conversations')) {
      conversationRequests.push(request.url());
    }
    if (request.url().includes('/settings/conversation-audit-retention')) {
      retentionRequests.push(request.url());
    }
  });
  await page.goto('/audit');

  await expect(page.getByText('Acesso Negado')).toBeVisible();
  await expect(page.getByRole('tab', { name: 'Política de retenção' })).not.toBeVisible();
  await expect(page.getByRole('tab', { name: 'Conversas' })).not.toBeVisible();
  expect(conversationRequests).toEqual([]);
  expect(retentionRequests).toEqual([]);
});

test('TENANT_ADMIN plus Audit sees only conversations', async ({ page }) => {
  await loginAs(page, 'tenant-admin-audit-user');
  await page.goto('/audit');

  await expect(page.getByRole('tab', { name: 'Conversas' })).toBeVisible();
  await expect(page.getByRole('tab', { name: 'Política de retenção' })).not.toBeVisible();
});

test('raw SUPER_ADMIN sees retention only while actively impersonating a tenant', async ({ page }) => {
  await loginAs(page, 'super-admin-without-audit', {
    impersonatedTenant: { id: 'tenant-a', name: 'Tenant A' },
  });
  await page.goto('/audit');

  await expect(page.getByRole('tab', { name: 'Política de retenção' })).toBeVisible();
  await expect(page.getByRole('tab', { name: 'Conversas' })).not.toBeVisible();
});

test('TENANT_ADMIN without Audit cannot open a conversation detail', async ({ page }) => {
  await loginAs(page, 'tenant-admin-without-audit');
  await page.goto('/audit/018f8f74-4889-7c62-bc49-8a6ccbca2c32');

  await expect(page.getByText('Acesso Negado')).toBeVisible();
});
```

### Rules

1. Every `PermissionGate` and `ProtectedRoute` usage **must** have unit tests.
2. Every role-restricted page **must** have E2E tests verifying both granted and denied access.
3. Use `renderWithAuth` helper for unit tests — mock the `AuthContext` with controlled roles/scopes.
4. Use `loginAs` helper for E2E tests — authenticate with Keycloak test users per role.

---

## 10. Centralized Route Paths

All application route paths **must** be centralized in a single file to avoid string duplication and enable safe refactoring:

```tsx
// src/lib/paths.ts

export const PATHS = {
  // Core
  DASHBOARD: '/dashboard',
  PROFILE: '/profile',

  // Fiscal module
  FISCAL_QUERY: '/fiscal',
  FISCAL_DAS: '/fiscal/das-cobranca',

  // Certificates module
  CERTIFICATES: '/certificates',

  // Billing module
  BILLING: '/billing',
  BILLING_PLANS: '/billing/plans',
  BILLING_INVOICES: '/billing/invoices',

  // Conversation audit
  AUDIT: '/audit',

  // Chatbot settings
  SETTINGS_CHATBOT: '/settings/chatbot',

  // Admin
  SETTINGS: '/settings',
  USERS: '/settings/users',

  // Auth
  LOGIN: '/login',
  LOGOUT: '/api/auth/logout',
} as const;

export type AppPath = (typeof PATHS)[keyof typeof PATHS];

// Compatibility aliases are isolated and never used for new navigation.
export const LEGACY_PATHS = {
  INBOX: '/inbox',
} as const;
```

### Rules

1. **All** route paths used in navigation, redirects, middleware, or tests **must** come from `src/lib/paths.ts`.
2. **Never** use raw path strings like `'/fiscal/query'` directly in components, Link `href`, or `router.push()`. Import from `PATHS`.
3. Use `as const` for type-safe literal inference. This enables exhaustive checks and autocomplete.
4. When a new page is added, the path **must** be registered in `PATHS` first.
5. `PATHS` is the **single source of truth** for canonical URL structure; `LEGACY_PATHS` contains
   only explicit compatibility redirects. Neither includes locale prefixes (see Section 14).
6. Group paths by **module** (bounded context), matching the same grouping used in `ROLES` and `SCOPES`.

---

## 11. Protected Routes Mapping

Centralize the mapping between routes and their required roles in a single object. This map is consumed by middleware and/or client-side route guards:

```tsx
// src/lib/protected-routes.ts

import { LEGACY_PATHS, PATHS } from './paths';
import { ROLES, type Role } from './permissions';

/**
 * Maps each protected route to the roles required for access.
 * A user must have at least ONE of the listed roles to access the route.
 * Routes not listed here are considered public or authentication-only.
 *
 * This map must be kept in sync with:
 * - Keycloak realm/client roles (@SecurityOAuth)
 * - PATHS (../../../frontend/src/lib/paths.ts)
 * - ROLES (../../../frontend/src/lib/permissions.ts)
 * - useModuleAccess (../../../frontend/src/hooks/useModuleAccess.ts)
 * - menuConfig (../../../frontend/src/lib/menu-config.ts)
 */
export const PROTECTED_ROUTES: Record<string, Role[]> = {
  [PATHS.DASHBOARD]: [ROLES.TENANT_USER, ROLES.TENANT_ADMIN, ROLES.SUPER_ADMIN],
  [PATHS.FISCAL_QUERY]: [
    ROLES.TENANT_USER,
    ROLES.FISCAL_READER,
    ROLES.FISCAL_ADMIN,
    ROLES.TENANT_ADMIN,
    ROLES.SUPER_ADMIN,
  ],
  [PATHS.CERTIFICATES]: [ROLES.CERT_MANAGER, ROLES.TENANT_ADMIN, ROLES.SUPER_ADMIN],
  [PATHS.BILLING]: [ROLES.TENANT_ADMIN],
  [PATHS.AUDIT]: [ROLES.TENANT_AUDIT, ROLES.SUPER_ADMIN],
  [LEGACY_PATHS.INBOX]: [ROLES.TENANT_AUDIT],
  [PATHS.SETTINGS]: [ROLES.TENANT_ADMIN, ROLES.SUPER_ADMIN],
  [PATHS.USERS]: [ROLES.TENANT_ADMIN, ROLES.SUPER_ADMIN],
} as const;
```

### Helper: Check Route Access

```tsx
// src/lib/protected-routes.ts (continued)

import type { Role } from './permissions';
import { asRoles, resolveEffectiveRoles } from './effective-roles';

export const findProtectedRoute = (pathname: string): string | undefined =>
  Object.keys(PROTECTED_ROUTES)
    .sort((left, right) => right.length - left.length)
    .find((route) => pathname === route || pathname.startsWith(`${route}/`));

/**
 * Checks raw roles plus authenticated/impersonated tenant context. Effective
 * roles remain appropriate for ordinary tenant routes, but retention requires
 * proof of raw Super Admin plus active impersonation.
 * Returns true if the route is not in the protected map (public route)
 * or if the user has at least one of the required roles.
 */
export const canAccessRoute = (
  pathname: string,
  userRoles: readonly string[],
  impersonatedTenantId?: string | null,
  authenticatedTenantId?: string | null,
): boolean => {
  const matchedRoute = findProtectedRoute(pathname);
  if (!matchedRoute) return true; // Not protected

  const effectiveRoles = asRoles(resolveEffectiveRoles(userRoles, impersonatedTenantId));
  const effectiveTenantId = userRoles.includes(ROLES.SUPER_ADMIN)
    ? impersonatedTenantId
    : authenticatedTenantId;

  const isAuditShell = pathname === PATHS.AUDIT;
  const isAuditConversationChild = pathname.startsWith(`${PATHS.AUDIT}/`);
  const isLegacyInbox = matchedRoute === LEGACY_PATHS.INBOX;

  // All audit capabilities are tenant-scoped. The shell is shared, but every
  // canonical child and every legacy /inbox alias remains Audit-only.
  if ((isAuditShell || isAuditConversationChild || isLegacyInbox) && !effectiveTenantId) {
    return false;
  }
  if (isAuditConversationChild || isLegacyInbox) {
    return effectiveRoles.includes(ROLES.TENANT_AUDIT);
  }

  if (isAuditShell) {
    return (
      effectiveRoles.includes(ROLES.TENANT_AUDIT) ||
      (userRoles.includes(ROLES.SUPER_ADMIN) && Boolean(impersonatedTenantId))
    );
  }

  return PROTECTED_ROUTES[matchedRoute].some((role) => effectiveRoles.includes(role));
};
```

### Rules

1. **Every** protected route **must** be registered in `PROTECTED_ROUTES`.
2. The map uses `PATHS` constants as keys; explicit compatibility redirects use
   `LEGACY_PATHS` — **never** raw strings.
3. The map uses `ROLES` constants as values — **never** raw strings.
4. Access logic is **OR** (any listed role grants access). For AND logic, use `ProtectedRoute` component with `requiredRoles`.
5. There is no implicit administrator override. Exact `/audit` is the deliberate mixed-source
   exception: effective Audit may enter for conversations, while retention requires raw Super
   Admin plus non-null impersonated tenant. Tenant Admin alone is denied.
6. When `@SecurityOAuth` adds a new protected route, update `PATHS`, `PROTECTED_ROUTES`, `menuConfig`, and `useModuleAccess` together.
7. `canAccessRoute` receives raw roles and both tenant sources so it can distinguish a Tenant Admin
   from a Super Admin personified as Tenant Admin. Super+Audit global remains denied; the same
   explicitly entitled identity is allowed after valid impersonation.
8. Route lookup is longest-prefix, but `/audit` is a deliberate exception to inherited role
   breadth: canonical child resources `/audit/{conversationId}` and legacy `/inbox` aliases are
   explicitly restricted to `ROLE_TENANT_AUDIT`. The retention tab remains state inside the exact
   `/audit` route and is never represented by an Audit-readable child route.

---

## 12. Data-Driven Menu Configuration

The sidebar menu **must** be declared as a data structure, not hardcoded in the Sidebar component. This enables:

- Centralized control of menu visibility per role
- Easy addition/removal of menu items
- Consistent i18n integration
- Testability (unit test the config, not the component)

```tsx
// src/lib/menu-config.ts

import type { Role } from './permissions';
import { ROLES } from './permissions';
import { PATHS } from './paths';
import type { LucideIcon } from 'lucide-react';
import {
  LayoutDashboard,
  FileText,
  Shield,
  CreditCard,
  MessageCircle,
  Settings,
  Users,
} from 'lucide-react';

// ---------- Types ----------

export interface MenuItem {
  /** i18n key from navigation.json (e.g., 'navigation.sidebar.dashboard') */
  labelKey: string;
  /** Route path from PATHS. Omit for parent items with subItems only */
  path?: string;
  /** Lucide icon component reference */
  icon: LucideIcon;
  /** Roles required to see this item (OR logic: any role grants visibility) */
  roles: Role[];
  /** Optional alternate raw-token authorities */
  requiredAnyAuthorities?: string[];
  /** ROLE_OR_AUTHORITY is reserved for an approved mixed-source boundary */
  accessMode?: 'ROLE' | 'AUTHORITY' | 'ROLE_OR_AUTHORITY';
  /** Whether an effective tenant must also exist */
  requiresTenantContext?: boolean;
  /** Sub-items for collapsible menu groups */
  subItems?: MenuItem[];
}

export interface MenuGroup {
  /** i18n key for the group title (e.g., 'navigation.sidebar.operations') */
  titleKey: string;
  /** Menu items in this group */
  items: MenuItem[];
}

// ---------- Menu Configuration ----------

export const menuConfig: MenuGroup[] = [
  {
    titleKey: 'navigation.sidebar.operations',
    items: [
      {
        labelKey: 'navigation.sidebar.dashboard',
        path: PATHS.DASHBOARD,
        icon: LayoutDashboard,
        roles: [ROLES.TENANT_USER, ROLES.TENANT_ADMIN, ROLES.SUPER_ADMIN],
      },
      {
        labelKey: 'navigation.sidebar.fiscalQuery',
        path: PATHS.FISCAL_QUERY,
        icon: FileText,
        roles: [
          ROLES.TENANT_USER,
          ROLES.FISCAL_READER,
          ROLES.FISCAL_ADMIN,
          ROLES.TENANT_ADMIN,
        ],
      },
      {
        labelKey: 'navigation.sidebar.certificates',
        path: PATHS.CERTIFICATES,
        icon: Shield,
        roles: [ROLES.TENANT_ADMIN],
      },
      {
        labelKey: 'navigation.sidebar.conversationAudit',
        path: PATHS.AUDIT,
        icon: MessageCircle,
        roles: [ROLES.TENANT_AUDIT],
        requiredAnyAuthorities: [ROLES.SUPER_ADMIN],
        accessMode: 'ROLE_OR_AUTHORITY',
        requiresTenantContext: true,
      },
    ],
  },
  {
    titleKey: 'navigation.sidebar.administration',
    items: [
      {
        labelKey: 'navigation.sidebar.billing',
        path: PATHS.BILLING,
        icon: CreditCard,
        roles: [ROLES.TENANT_ADMIN],
      },
      {
        labelKey: 'navigation.sidebar.settings',
        icon: Settings,
        roles: [ROLES.TENANT_ADMIN],
        subItems: [
          {
            labelKey: 'navigation.sidebar.users',
            path: PATHS.USERS,
            icon: Users,
            roles: [ROLES.TENANT_ADMIN],
          },
        ],
      },
    ],
  },
];
```

### Sidebar Consuming the Config

```tsx
// src/components/layout/Sidebar.tsx
'use client';

import Link from 'next/link';
import { useTranslations } from 'next-intl';
import { useAuth } from '@/hooks/useAuth';
import { useTenant } from '@/hooks/useTenant';
import { menuConfig, type MenuItem, type MenuGroup } from '@/lib/menu-config';
import { getVisibleMenuConfig } from '@/lib/menu-utils';

export const Sidebar = () => {
  const t = useTranslations();
  const { hasEffectiveRole, user } = useAuth();
  const { tenantId } = useTenant();
  const visibleConfig = getVisibleMenuConfig(
    menuConfig,
    hasEffectiveRole,
    Boolean(tenantId),
    (authority) => user?.roles.includes(authority) ?? false,
  );

  const renderItem = (item: MenuItem) => {
    // Parent with sub-items
    if (item.subItems) {
      return (
        <div key={item.labelKey}>
          <button className="flex items-center gap-3 px-4 py-2.5 w-full text-sm font-medium text-neutral-600">
            <item.icon className="w-5 h-5" />
            {t(item.labelKey)}
          </button>
          <ul className="ml-4">
            {item.subItems.map((sub) => (
              <li key={sub.labelKey}>
                <Link href={sub.path!} className="flex items-center gap-3 px-4 py-2 text-sm text-neutral-500 hover:text-neutral-800">
                  <sub.icon className="w-4 h-4" />
                  {t(sub.labelKey)}
                </Link>
              </li>
            ))}
          </ul>
        </div>
      );
    }

    // Leaf item
    return (
      <li key={item.labelKey}>
        <Link href={item.path!} className="flex items-center gap-3 px-4 py-2.5 rounded-lg text-sm font-medium text-neutral-600 hover:bg-neutral-200/50 hover:text-neutral-800">
          <item.icon className="w-5 h-5" />
          {t(item.labelKey)}
        </Link>
      </li>
    );
  };

  return (
    <nav aria-label="Menu principal">
      {visibleConfig.map((group) => {
        return (
          <div key={group.titleKey}>
            <h3 className="text-xs font-semibold text-neutral-400 uppercase tracking-wider px-4 mt-6">
              {t(group.titleKey)}
            </h3>
            <ul>{group.items.map(renderItem)}</ul>
          </div>
        );
      })}
    </nav>
  );
};
```

### Adding a New Feature to the Menu

To expose a new feature to specific roles:

1. Add the path to `src/lib/paths.ts` → `PATHS.NEW_FEATURE`
2. Add the role to `src/lib/permissions.ts` → `ROLES.NEW_FEATURE_READER`
3. Add the route to `src/lib/protected-routes.ts` → `PROTECTED_ROUTES`
4. Add the menu item to `src/lib/menu-config.ts` → `menuConfig`
5. Add the i18n key to `src/i18n/messages/*/navigation.json`
6. Update `useModuleAccess` in `src/hooks/useModuleAccess.ts`
7. Register the role in Keycloak via `@SecurityOAuth`

### Rules

1. Menu structure is declared in `src/lib/menu-config.ts`. The Sidebar component **only renders** — it does not define items.
2. `MenuItem.roles` uses `ROLES` constants — **never** raw strings.
3. `MenuItem.path` uses `PATHS` constants — **never** raw strings.
4. `MenuItem.labelKey` uses i18n keys from `navigation.json` — **never** hardcoded display labels.
5. `MenuItem.icon` stores the **component reference** (`LucideIcon`), not a rendered element. Never pre-render icons in the config with `React.createElement()`.
6. Parent items (with `subItems`) are hidden when **all** sub-items are hidden.
7. Administrator roles do not receive a visibility override. `/audit` declares effective Audit OR
   raw Super Admin through `ROLE_OR_AUTHORITY`, still gated by tenant context; this exception must
   not be implemented as a global hybrid role callback, which would re-expose global menus during
   impersonation.
8. Menu items with `visible: false` must **never** be rendered — not hidden via CSS, removed from the DOM entirely.
9. Tenant-scoped items declare `requiresTenantContext: true`; raw role is permitted only as a
   centrally declared alternative such as retention's raw Super Admin requirement, never as an
   ad-hoc component conditional.

---

## 13. i18n Integration in RBAC Sidebar

Menu labels in the sidebar **must** use `next-intl` translations, integrated with the data-driven menu config from Section 12.

### Navigation Translation File

```json
// src/i18n/messages/pt-BR/navigation.json
{
  "navigation": {
    "sidebar": {
      "operations": "Operações",
      "administration": "Administração",
      "dashboard": "Dashboard",
      "fiscalQuery": "Consulta Fiscal",
      "certificates": "Certificados",
      "whatsapp": "WhatsApp",
      "billing": "Faturamento",
      "settings": "Configurações",
      "users": "Usuários"
    },
    "topbar": {
      "profile": "Meu Perfil",
      "logout": "Sair"
    }
  }
}
```

```json
// src/i18n/messages/en/navigation.json
{
  "navigation": {
    "sidebar": {
      "operations": "Operations",
      "administration": "Administration",
      "dashboard": "Dashboard",
      "fiscalQuery": "Fiscal Query",
      "certificates": "Certificates",
      "whatsapp": "WhatsApp",
      "billing": "Billing",
      "settings": "Settings",
      "users": "Users"
    },
    "topbar": {
      "profile": "My Profile",
      "logout": "Log out"
    }
  }
}
```

### Rules

1. All sidebar labels come from `navigation.json` via `useTranslations()`. **Never** hardcode display text in menu config or components.
2. `MenuItem.labelKey` matches the **full namespace** path: `'navigation.sidebar.dashboard'`.
3. When adding a new menu item, the i18n key **must** be added to **all** locale files (`pt-BR`, `en`) simultaneously.
4. Menu group titles (`MenuGroup.titleKey`) also use i18n keys from `navigation.json`.
5. This pattern complements the i18n standard (./i18n-standard.md)) — sidebar keys follow the same `namespace.section.key` convention.

---

## 14. Locale-Prefixed Routes (i18n Routing)

When the application uses locale-based routing (e.g., `/pt-BR/dashboard`, `/en/dashboard`), the menu config and path generation must handle locale prefixes consistently.

### Path with Locale Helper

```tsx
// src/lib/paths.ts (extended)

import type { Locale } from '@/i18n/config';

/**
 * Generates a locale-prefixed path for navigation.
 * @param path - A path constant from PATHS
 * @param locale - Current locale (e.g., 'pt-BR', 'en')
 * @returns Locale-prefixed path (e.g., '/pt-BR/dashboard')
 */
export const localePath = (path: string, locale: Locale): string => {
  return `/${locale}${path}`;
};
```

### Sidebar Usage with Locale

```tsx
// src/components/layout/Sidebar.tsx (locale-aware)
'use client';

import Link from 'next/link';
import { useTranslations, useLocale } from 'next-intl';
import { useAuth } from '@/hooks/useAuth';
import { menuConfig } from '@/lib/menu-config';
import { localePath } from '@/lib/paths';

export const Sidebar = () => {
  const t = useTranslations();
  const locale = useLocale();
  const { hasEffectiveRole } = useAuth();

  // ... isVisible logic from Section 12

  // When rendering a leaf item:
  <Link href={localePath(item.path!, locale)}>
    <item.icon className="w-5 h-5" />
    {t(item.labelKey)}
  </Link>
};
```

### Next.js i18n Routing Configuration

When using `next-intl` with locale-prefixed URLs, the directory structure uses a `[locale]` dynamic segment:

```
src/app/
├── [locale]/
│   ├── layout.tsx           # Root layout with NextIntlClientProvider
│   ├── (auth)/
│   │   ├── layout.tsx       # ProtectedRoute wrapper
│   │   └── dashboard/
│   │       └── page.tsx
│   ├── (fiscal)/
│   │   ├── layout.tsx       # ProtectedRoute + FISCAL_READER
│   │   └── query/
│   │       └── page.tsx
│   └── (public)/
│       └── login/
│           └── page.tsx
└── middleware.ts             # Locale detection + redirect
```

### Middleware for Locale Detection

```tsx
// src/middleware.ts (locale-aware)
import createMiddleware from 'next-intl/middleware';
import { locales, defaultLocale } from '@/i18n/config';

export default createMiddleware({
  locales,
  defaultLocale,
  localePrefix: 'always', // or 'as-needed'
});

export const config = {
  matcher: ['/((?!_next|api|favicon.ico|silent-check-sso.html).*)'],
};
```

### Rules

1. **PATHS constants** must **not** include the locale prefix. The prefix is added at navigation time via `localePath()`.
2. `localePath()` is the **only** function that prepends the locale to a path. **Never** concatenate locale manually: `` `/${locale}/dashboard` ``.
3. `PROTECTED_ROUTES` keys use paths **without** locale prefix. The middleware or route guard strips the locale before checking.
4. When using `next-intl` middleware for locale detection, **combine** it with the security headers middleware from [`nextjs-standard.md`](./nextjs-standard.md).
5. `useLocale()` from `next-intl` is the **only** source for the current locale. **Never** parse `window.location.pathname` manually.
6. If the application does **not** use locale-prefixed URLs (single locale), `localePath()` is still used but returns the path unchanged. This ensures a consistent API for future locale expansion.

---

## 15. Change Log

| Version | Date | Changes |
|---|---|---|
| `1.8` | `2026-09-11` | Reconciles the centralized-path example with the executable frontend after unsupported fiscal DARF, batch and generic document routes were expunged. |
| `1.7` | `2026-09-09` | Restricts retention to raw `ROLE_SUPER_ADMIN` with active tenant impersonation; denies Tenant Admin, preserves Tenant Admin+Audit as conversations-only, and keeps canonical children and `/inbox*` Audit-only. |
| `1.6` | `2026-09-08` | Define `/audit` as a tenant-scoped shell shared by Audit and Tenant Admin, separates conversation and retention capabilities per tab, keeps `/audit/{conversationId}` and `/inbox` Audit-only, and adds the corresponding unit/E2E policy examples. |
| `1.5` | `2026-09-04` | Points role semantics to the centralized AS-IS matrix and records Super Admin impersonation for Billing. |
