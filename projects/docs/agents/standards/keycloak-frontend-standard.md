---
document_id: "KEYCLOAK-FRONTEND-STANDARD"
primary_nature: "Regra"
objective: "Definir regras reutilizáveis e verificáveis para Keycloak Frontend."
scope: "Integração de autenticação, sessão e redirecionamentos do frontend com Keycloak."
non_objectives: "Não criar requisitos de produto, decisões arquiteturais concretas ou procedimentos fora do escopo deste standard."
owner: "Arquitetura e Qualidade"
status: "Active"
date: "2026-08-25"
version: "1.4"
keywords: "keycloak, frontend, standard, standard"
related_files: "./README.md, ../FrontendWeb.md, ../UIIntegrator.md"
code_references: "frontend/"
principal_statement: "As regras de Keycloak Frontend aplicam-se somente ao escopo e aos controles declarados neste standard."
---

# Keycloak Frontend Integration Standard — @FrontendWeb / @UIIntegrator

> **Mandatory rules** for Keycloak JS integration in the frontend. Referenced from `../FrontendWeb.md` and `../UIIntegrator.md`. Configuration inputs provided by `@SecurityOAuth`.

> **Version:** 1.2 — **Last updated:** 2026-08-22. AuthContext and guard examples now use the
> implemented effective-role contract for tenant impersonation and Conversation Audit.

---

## 1. Dependencies & Versions

| Package | Version | Purpose |
|---|---|---|
| `keycloak-js` | `^26.2.3` | Official Keycloak JavaScript adapter |
| `jwt-decode` | `^4.x` | Decode JWT access tokens for role/scope extraction |

### Installation

```bash
pnpm add keycloak-js jwt-decode
```

### Rules

1. **Never** install unofficial Keycloak wrappers (`@react-keycloak/*`, `keycloak-react-web`). Use `keycloak-js` directly with React hooks.
2. **Never** pin to a Keycloak version older than the deployed Keycloak server.

---

## 2. Environment Configuration

### Required Variables

```env
# .env.local (development)
NEXT_PUBLIC_KEYCLOAK_URL=http://localhost:8080
NEXT_PUBLIC_KEYCLOAK_REALM=saas
NEXT_PUBLIC_KEYCLOAK_CLIENT_ID=saas-frontend-spa

# .env.production
NEXT_PUBLIC_KEYCLOAK_URL=https://auth.example.com
NEXT_PUBLIC_KEYCLOAK_REALM=saas
NEXT_PUBLIC_KEYCLOAK_CLIENT_ID=saas-frontend-spa
```

### Rules

1. All Keycloak config **must** use `NEXT_PUBLIC_` prefix (client-side accessible).
2. **Never** hardcode Keycloak URLs, realm, or client ID in source code.
3. Create a configuration module to centralize env var access:

```tsx
// src/lib/keycloak-config.ts
export const keycloakConfig = {
  url: process.env.NEXT_PUBLIC_KEYCLOAK_URL!,
  realm: process.env.NEXT_PUBLIC_KEYCLOAK_REALM!,
  clientId: process.env.NEXT_PUBLIC_KEYCLOAK_CLIENT_ID!,
} as const;
```

---

## 3. Keycloak Instance — Singleton Pattern

```tsx
// src/lib/keycloak.ts
import Keycloak from 'keycloak-js';
import { keycloakConfig } from './keycloak-config';

let keycloakInstance: Keycloak | null = null;

export const getKeycloak = (): Keycloak => {
  if (!keycloakInstance) {
    keycloakInstance = new Keycloak({
      url: keycloakConfig.url,
      realm: keycloakConfig.realm,
      clientId: keycloakConfig.clientId,
    });
  }
  return keycloakInstance;
};
```

### Rules

1. **Singleton only.** Never instantiate `new Keycloak()` outside of `getKeycloak()`.
2. The instance is created lazily, never at module import time (SSR safety).
3. **Never** export the raw Keycloak instance. Always access via `getKeycloak()`.

---

## 4. AuthProvider — React Context Pattern

```tsx
// src/providers/AuthProvider.tsx
'use client';

import {
  createContext,
  useCallback,
  useEffect,
  useMemo,
  useRef,
  useState,
  type ReactNode,
} from 'react';
import type Keycloak from 'keycloak-js';
import { jwtDecode } from 'jwt-decode';
import { getKeycloak } from '@/lib/keycloak';
import { hasEffectiveRole as checkEffectiveRole } from '@/lib/effective-roles';
import { useImpersonateStore } from '@/stores/useImpersonateStore';

// ---------- Types ----------

interface DecodedToken {
  sub: string;
  preferred_username: string;
  email?: string;
  tenant_id?: string;
  realm_access?: { roles: string[] };
  resource_access?: Record<string, { roles: string[] }>;
  scope?: string;
}

interface AuthUser {
  id: string;
  username: string;
  email?: string;
  tenantId: string | null;
  roles: string[];
  scopes: string[];
}

interface AuthContextValue {
  isAuthenticated: boolean;
  isLoading: boolean;
  user: AuthUser | null;
  token: string | null;
  login: () => void;
  logout: () => void;
  hasRole: (role: string) => boolean;
  hasEffectiveRole: (role: string) => boolean;
  hasScope: (scope: string) => boolean;
}

// ---------- Context ----------

export const AuthContext = createContext<AuthContextValue | undefined>(undefined);

// ---------- Token Parsing ----------

const parseUser = (keycloak: Keycloak): AuthUser | null => {
  if (!keycloak.token) return null;

  try {
    const decoded = jwtDecode<DecodedToken>(keycloak.token);
    const realmRoles = decoded.realm_access?.roles ?? [];
    const clientRoles =
      decoded.resource_access?.[keycloak.clientId!]?.roles ?? [];
    const scopes = decoded.scope?.split(' ') ?? [];

    return {
      id: decoded.sub,
      username: decoded.preferred_username,
      email: decoded.email,
      tenantId: decoded.tenant_id ?? null,
      roles: [...realmRoles, ...clientRoles],
      scopes,
    };
  } catch {
    return null;
  }
};

// ---------- Provider ----------

interface AuthProviderProps {
  children: ReactNode;
}

export const AuthProvider = ({ children }: AuthProviderProps) => {
  const [isLoading, setIsLoading] = useState(true);
  const [isAuthenticated, setIsAuthenticated] = useState(false);
  const [user, setUser] = useState<AuthUser | null>(null);
  const [token, setToken] = useState<string | null>(null);
  const didInit = useRef(false);

  // ---- Initialize Keycloak ----
  useEffect(() => {
    if (didInit.current) return;
    didInit.current = true;

    const keycloak = getKeycloak();

    keycloak
      .init({
        onLoad: 'check-sso',
        pkceMethod: 'S256',
        checkLoginIframe: false,
        silentCheckSsoRedirectUri:
          typeof window !== 'undefined'
            ? `${window.location.origin}/silent-check-sso.html`
            : undefined,
      })
      .then((authenticated) => {
        setIsAuthenticated(authenticated);
        if (authenticated) {
          setToken(keycloak.token ?? null);
          setUser(parseUser(keycloak));
        }
        setIsLoading(false);
      })
      .catch(() => {
        setIsLoading(false);
      });

    // ---- Token refresh ----
    keycloak.onTokenExpired = () => {
      keycloak
        .updateToken(30)
        .then((refreshed) => {
          if (refreshed) {
            setToken(keycloak.token ?? null);
            setUser(parseUser(keycloak));
          }
        })
        .catch(() => {
          keycloak.logout();
        });
    };

    // ---- Session events ----
    keycloak.onAuthLogout = () => {
      setIsAuthenticated(false);
      setUser(null);
      setToken(null);
    };
  }, []);

  // ---- Actions ----
  const login = useCallback(() => {
    getKeycloak().login();
  }, []);

  const logout = useCallback(() => {
    getKeycloak().logout({ redirectUri: window.location.origin });
  }, []);

  const selectedTenantId = useImpersonateStore((state) => state.selectedTenantId);

  const hasRole = useCallback(
    (role: string) => user?.roles.includes(role) ?? false,
    [user],
  );

  const hasEffectiveRole = useCallback(
    (role: string) =>
      user ? checkEffectiveRole(user.roles, selectedTenantId, role) : false,
    [user, selectedTenantId],
  );

  const hasScope = useCallback(
    (scope: string) => user?.scopes.includes(scope) ?? false,
    [user],
  );

  // ---- Context value ----
  const value = useMemo<AuthContextValue>(
    () => ({
      isAuthenticated,
      isLoading,
      user,
      token,
      login,
      logout,
      hasRole,
      hasEffectiveRole,
      hasScope,
    }),
    [
      isAuthenticated,
      isLoading,
      user,
      token,
      login,
      logout,
      hasRole,
      hasEffectiveRole,
      hasScope,
    ],
  );

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
};
```

### Rules

1. `AuthProvider` **must** wrap the entire application at the root layout.
2. **`onLoad: 'check-sso'`** — never use `'login-required'` at the provider level (allows public pages).
3. **`pkceMethod: 'S256'`** — PKCE is mandatory. Never use implicit flow.
4. **`checkLoginIframe: false`** — disabled for performance. Use `silentCheckSsoRedirectUri` instead.
5. **`didInit` ref** — prevents double initialization in React Strict Mode.
6. Token is held **in React state only** (in-memory). Never in `localStorage` or `sessionStorage`.
7. **Token refresh** via `onTokenExpired` with 30-second buffer.
8. On refresh failure → automatic logout (token compromised or session expired).

---

## 5. Silent SSO Check

Create a static HTML file for iframe-based SSO checks:

```html
<!-- public/silent-check-sso.html -->
<html>
<body>
  <script>
    parent.postMessage(location.href, location.origin);
  </script>
</body>
</html>
```

### Rules

1. This file **must** exist at `public/silent-check-sso.html`.
2. It enables Keycloak to check SSO status without a full redirect.
3. **Never** add JavaScript logic beyond the `postMessage` call.

---

## 6. useAuth Hook

```tsx
// src/hooks/useAuth.ts
'use client';

import { useContext } from 'react';
import { AuthContext } from '@/providers/AuthProvider';

export const useAuth = () => {
  const context = useContext(AuthContext);
  if (!context) {
    throw new Error('useAuth must be used within an AuthProvider');
  }
  return context;
};
```

### Usage

```tsx
import { ROLES } from '@/lib/permissions';

const {
  isAuthenticated,
  user,
  login,
  logout,
  hasRole,
  hasEffectiveRole,
  hasScope,
} = useAuth();

// UI/route decisions always use the effective workspace role set.
if (hasEffectiveRole(ROLES.FISCAL_READER)) { /* ... */ }

// Raw-token checks are reserved for explicit protocol/security assertions.
const tokenCarriesAudit = hasRole(ROLES.TENANT_AUDIT);

// Check scope
if (hasScope('fiscal:read')) { /* ... */ }

// Access tenant
const tenantId = user?.tenantId;
```

### Rules

1. **Always** use `useAuth()` hook. Never access `AuthContext` directly.
2. Throws if used outside `AuthProvider` — this is intentional (fail-fast).

---

## 7. Token Injection in API Calls

The `apiClient` (defined in `frontend-standard.md`) **must** obtain the token from Keycloak:

```tsx
// src/lib/apiClient.ts
import { getKeycloak } from '@/lib/keycloak';
import { AuthError } from '@/lib/apiError';
import { useImpersonateStore } from '@/stores/useImpersonateStore';

const getAccessToken = (): string | undefined => {
  const keycloak = getKeycloak();
  return keycloak.token;
};

const getImpersonatedTenantId = (): string | undefined => {
  const keycloak = getKeycloak();
  const parsed = keycloak.tokenParsed as Record<string, unknown> | undefined;
  if (!parsed) throw new AuthError('Session configuration error.');

  const roles = (parsed.realm_access as { roles?: string[] })?.roles ?? [];
  if (roles.includes('ROLE_SUPER_ADMIN')) {
    return useImpersonateStore.getState().selectedTenantId ?? undefined;
  }

  if (!parsed.tenant_id) {
    throw new AuthError('Missing tenant_id in tenant identity.');
  }

  // Tenant identities are confined by the signed claim; no header is sent.
  return undefined;
};

export const apiClient = {
  async request<T>(url: string, options: RequestInit = {}): Promise<T> {
    const keycloak = getKeycloak();

    // Ensure token is fresh (min 10s validity)
    try {
      await keycloak.updateToken(10);
    } catch {
      keycloak.login();
      throw new Error('Session expired');
    }

    const headers = new Headers(options.headers);
    headers.set('Content-Type', 'application/json');
    headers.set('Authorization', `Bearer ${getAccessToken()}`);
    headers.delete('X-Tenant-ID');
    const impersonatedTenantId = getImpersonatedTenantId();
    if (impersonatedTenantId) headers.set('X-Tenant-ID', impersonatedTenantId);

    const response = await fetch(url, {
      ...options,
      headers,
    });

    if (response.status === 401) {
      keycloak.login();
      throw new Error('Unauthorized');
    }

    if (!response.ok) {
      throw new ApiError(response.status, await response.text());
    }

    return response.json();
  },

  get: <T>(url: string) => apiClient.request<T>(url),

  post: <T>(url: string, body: unknown) =>
    apiClient.request<T>(url, {
      method: 'POST',
      body: JSON.stringify(body),
    }),

  put: <T>(url: string, body: unknown) =>
    apiClient.request<T>(url, {
      method: 'PUT',
      body: JSON.stringify(body),
    }),

  delete: <T>(url: string) =>
    apiClient.request<T>(url, { method: 'DELETE' }),
};

class ApiError extends Error {
  constructor(
    public status: number,
    public body: string,
  ) {
    super(`API Error ${status}: ${body}`);
    this.name = 'ApiError';
  }
}
```

### Rules

1. **Every request** calls `updateToken(10)` before sending — ensures token has ≥10s validity.
2. If token refresh fails → redirect to login (session expired).
3. If API returns `401` → redirect to login (token invalidated server-side).
4. Identidade tenant exige `tenant_id` no JWT e **não** envia `X-Tenant-ID`; Super Admin global
   também não envia o header. Somente Super Admin com tenant selecionado explicitamente envia
   `X-Tenant-ID`, obtido do estado de impersonação.
5. **Never** build a separate auth header mechanism. Always use this centralized `apiClient`.
6. `apiClient` remove qualquer `X-Tenant-ID` fornecido por service/caller e reinsere somente o
   valor autoritativo da impersonação, quando aplicável.

---

## 8. Route Protection

### ProtectedRoute Component

```tsx
// src/components/auth/ProtectedRoute.tsx
'use client';

import { type ReactNode } from 'react';
import { useAuth } from '@/hooks/useAuth';
import { useTenant } from '@/hooks/useTenant';

interface ProtectedRouteProps {
  children: ReactNode;
  requiredRoles?: string[];
  requiredScopes?: string[];
  requiresTenantContext?: boolean;
  fallback?: ReactNode;
}

export const ProtectedRoute = ({
  children,
  requiredRoles = [],
  requiredScopes = [],
  requiresTenantContext = false,
  fallback = null,
}: ProtectedRouteProps) => {
  const { isAuthenticated, isLoading, hasEffectiveRole, hasScope, login } = useAuth();
  const { tenantId } = useTenant();

  if (isLoading) {
    return <LoadingScreen />;
  }

  if (!isAuthenticated) {
    login();
    return <LoadingScreen />;
  }

  const hasAllRoles = requiredRoles.every((role) => hasEffectiveRole(role));
  const hasAllScopes = requiredScopes.every((scope) => hasScope(scope));
  const hasRequiredTenant = !requiresTenantContext || Boolean(tenantId);

  if (!hasAllRoles || !hasAllScopes || !hasRequiredTenant) {
    return fallback ?? <ForbiddenPage />;
  }

  return <>{children}</>;
};
```

### PermissionGate Component (Conditional Rendering)

```tsx
// src/components/auth/PermissionGate.tsx
'use client';

import { type ReactNode } from 'react';
import { useAuth } from '@/hooks/useAuth';

interface PermissionGateProps {
  children: ReactNode;
  roles?: string[];
  scopes?: string[];
  fallback?: ReactNode;
}

export const PermissionGate = ({
  children,
  roles = [],
  scopes = [],
  fallback = null,
}: PermissionGateProps) => {
  const { hasEffectiveRole, hasScope } = useAuth();

  const allowed =
    roles.every((r) => hasEffectiveRole(r)) &&
    scopes.every((s) => hasScope(s));

  return allowed ? <>{children}</> : <>{fallback}</>;
};
```

### Usage

```tsx
// Route protection (in layout or page wrapper)
<ProtectedRoute requiredRoles={['FISCAL_READER']}>
  <FiscalQueryPage />
</ProtectedRoute>

<ProtectedRoute
  requiredRoles={['ROLE_TENANT_AUDIT']}
  requiresTenantContext
>
  <ConversationAuditPage />
</ProtectedRoute>

// Conditional rendering within a page
<PermissionGate roles={['FISCAL_ADMIN']}>
  <DeleteButton onClick={handleDelete} />
</PermissionGate>
```

### Next.js Middleware (Optional — for SSR redirect)

```tsx
// src/middleware.ts
import { NextResponse, type NextRequest } from 'next/server';

const PUBLIC_PATHS = ['/login', '/public', '/silent-check-sso.html'];

export function middleware(request: NextRequest) {
  const { pathname } = request.nextUrl;

  if (PUBLIC_PATHS.some((path) => pathname.startsWith(path))) {
    return NextResponse.next();
  }

  // Client-side auth is handled by ProtectedRoute.
  // Middleware only applies for SSR scenarios that need server-side redirect.
  return NextResponse.next();
}

export const config = {
  matcher: ['/((?!_next/static|_next/image|favicon.ico).*)'],
};
```

### Rules

1. **All authenticated pages** must be wrapped with `<ProtectedRoute>`.
2. Roles and scopes use `every()` (AND logic). For OR logic, use separate gates.
3. **Never** check `keycloak.authenticated` directly in components. Use `useAuth()`.
4. `PermissionGate` is for UI elements (buttons, menus). `ProtectedRoute` is for pages.
5. Unauthenticated → redirect to Keycloak login. Unauthorized (wrong role) → show Forbidden.
6. Tenant-scoped pages use effective roles plus `requiresTenantContext`; raw token roles never
   make Super Admin+Audit global eligible for `/audit`.

---

## 9. Logout & Tenant Switch

### Logout

```tsx
const { logout } = useAuth();

// Full logout: clears Keycloak session, redirects to origin
logout();
```

### Tenant Switch (if supported)

```tsx
// On tenant switch, clear all client-side state and re-authenticate
const switchTenant = (newTenantId: string) => {
  // 1. Clear React Query cache
  queryClient.clear();

  // 2. Clear component state (trigger re-mount)
  // 3. Re-login with tenant hint (if Keycloak supports tenant selection)
  getKeycloak().login({
    loginHint: undefined,
    // Tenant selection handled at Keycloak login page or custom attribute
  });
};
```

### Rules

1. On **logout**: all in-memory state (token, user, tenant, cached data) must be cleared.
2. On **tenant switch**: React Query cache **must** be cleared to prevent cross-tenant data leakage.
3. **Never** allow stale tenant data to persist after logout or tenant switch.

---

## 10. Error Handling

| Scenario | Behavior |
|---|---|
| Keycloak server unreachable | Show connection error page with retry button |
| Token expired + refresh fails | Redirect to Keycloak login |
| API returns 401 | Redirect to Keycloak login |
| API returns 403 | Show Forbidden page (user lacks permission) |
| Identidade tenant sem `tenant_id` claim | Show error: "Session configuration error. Contact support." |
| Super Admin global sem `tenant_id` | Estado válido; não enviar `X-Tenant-ID` e negar superfícies tenant-scoped |
| Silent SSO check fails | Treat as unauthenticated, show login prompt |

### Rules

1. **Never** show raw Keycloak error messages to the user.
2. **Never** expose token contents in error messages or console logs in production.
3. All Keycloak errors must be caught and transformed into user-friendly messages.

---

## 11. Security Checklist

- [ ] Access tokens stored **only** in React state (in-memory). Never `localStorage`.
- [ ] PKCE (`S256`) enabled for authorization code flow.
- [ ] Identidade tenant validada com `tenant_id` no JWT e sem `X-Tenant-ID` duplicado.
- [ ] Super Admin global permanece sem tenant/header; `X-Tenant-ID` é emitido somente após
      seleção explícita de tenant e não pode ser sobrescrito por um service.
- [ ] Token refresh runs automatically before expiration (30s buffer).
- [ ] All sensitive state cleared on logout.
- [ ] All sensitive state cleared on tenant switch.
- [ ] No token values logged to browser console in production.
- [ ] `silent-check-sso.html` deployed to `/public` directory.
- [ ] `checkLoginIframe: false` to avoid third-party cookie issues.
