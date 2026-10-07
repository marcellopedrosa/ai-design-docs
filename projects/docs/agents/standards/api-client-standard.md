---
document_id: "API-CLIENT-STANDARD"
primary_nature: "Regra"
objective: "Definir o contrato OpenAPI obrigatório e as regras verificáveis para produzir, implementar e consumir APIs HTTP do backend."
scope: "Especificações que criam, alteram ou consomem APIs HTTP do backend, contratos OpenAPI, controllers, clientes HTTP, autenticação, erros, versionamento, cache e estados de requisição."
non_objectives: "Não criar requisitos de produto, escolher regras de autorização sem fonte aprovada nem documentar como implementado um endpoint ainda planejado."
owner: "Arquitetura e Qualidade"
status: "Active"
date: "2026-09-09"
last_reviewed: "2026-09-10"
version: "2.2"
keywords: "api, openapi, contrato, contract-first, rfc-9110, rfc-9457, cliente, backend, frontend"
related_files: "./README.md, ./implementation-readiness-standard.md, keycloak-frontend-standard.md, nextjs-standard.md, docs/api_contracts/README.md, harness/templates/TPL-00011-api-contract.md, artefatos de análise/ANL-00055-backend-api-contract-coverage-inventory.md, artefatos de análise/ANL-00057-frontend-backend-api-contract-catalog.md, ../../specs/TP-00052-backend-api-contract-baseline.md"
code_references: "docs/api_contracts/, validate-api-contract-coverage.mjs, validate-api-contract-coverage.test.mjs, backend/src/main/java/, frontend/src/services/, frontend/src/schemas/, frontend/src/types/, website/src/"
principal_statement: "Toda especificação que cria, altera ou consome uma API HTTP do backend deve referenciar antes da implementação um contrato OpenAPI canônico, versionado e completo em docs/api_contracts/."
---

# API Contract, Client & Data Fetching Standard

> **Mandatory rules** for API specification, implementation, communication, error
> handling and data fetching. This standard applies to @RequirementAgent,
> @AgentOrchestrator, @AdapterDev, @FrontendWeb, @UIIntegrator and @TestAutomator.
> It extends the `apiClient` pattern from
> [`keycloak-frontend-standard.md`](keycloak-frontend-standard.md) and the
> TanStack Query patterns from [`nextjs-standard.md`](nextjs-standard.md).

> **Version:** 2.2 — **Last updated:** 2026-09-10. Tenant header handling follows
> ADR-0013 and REQ-00004. HTTP semantics and errors follow the RFC baseline below.

---

## 0. Contract-First API Gate

### 0.1 Applicability and hard rule

This section applies whenever a requirement, use case, ADR, task plan,
implementation plan, wireframe, backend adapter, frontend/website service, test,
mock, webhook or external integration **creates, changes or consumes** an HTTP API
exposed by the backend.

1. The canonical wire contract **MUST** be an OpenAPI `3.1.x` YAML file under
   [`docs/api_contracts/`](../../api_contracts/README.md), named `<domain>-vN.openapi.yaml`.
2. The contract **MUST exist before executable API work starts**. The responsible
   agent creates or updates it from this standard and deterministically promotes it
   to `Active`/`Auto-approved` after structural validation. Human approval or
   monitoring is not required and never blocks Implementation Readiness.
3. The OpenAPI file is the source of truth for the HTTP protocol. Spring
   controllers, Swagger annotations, generated specifications, Java DTOs,
   TypeScript types, Zod schemas, clients, fixtures and MSW handlers **MUST conform
   to it** and cannot silently redefine it.
4. A Markdown table, controller signature, Swagger UI snapshot, generated file in
   `target/`, TypeScript type or mock is evidence/consumer, not a substitute for
   the canonical contract.
5. Missing contract, missing operation, unresolved `$ref`, undocumented role,
   status, media type, body or error is an agent-owned repair item. The agent
   creates or corrects the contract automatically and records the change; it does
   not make the API task `BLOCKED` under the
   [Implementation Readiness Standard](./implementation-readiness-standard.md).
6. A specification with no backend API interaction must state
   `API Contract: N/A — <objective justification>`; omission is not `N/A`.
7. Inventory and change analysis **MUST run in both directions**: production
   frontend/website calls → contract and backend controller mappings → contract.
   Every pair belongs to the OpenAPI of its bounded context. A consumer call with
   no controller is recorded as `Draft` with
   `x-implementation-status: consumer-only-backend-unimplemented`; a controller
   with no web consumer remains cataloged as backend-only. Neither classification
   authorizes a software change.

The contract may be split by domain or independently evolving consumer surface.
It must not be split merely by controller when the same public API version and
owner evolve together.

### 0.2 Mandatory reference in official documents

Every affected artifact must use a relative Markdown link to the canonical
OpenAPI file and list the exact `info.version` and affected `operationId` values.

| Artifact | Mandatory API reference |
|---|---|
| Requirement | `API Impact` identifies contract path, version, status, consumer/provider, affected operations and compatibility class. |
| Use Case | Each API-backed main, alternative or exception flow maps to one or more `operationId` values and responses. |
| ADR | When it decides the interface, links the contract and states which decision constrains it; otherwise `N/A` with reason. |
| Task Plan / Implementation Plan | Lists the contract in `Related Files`, `Requirements`, `Depends on`, `Mandatory`, deliverables and contract tests. |
| Wireframe / frontend specification | Maps every remote state/action to contract operation, success response and documented Problem Details errors. |
| Controller/client/test/report | Records the contract path/version and produces parity evidence for the affected operations. |

If a document is already historical or implemented, it does not need a mass
rewrite. Its next API-affecting revision must adopt this reference contract. A
human validation failure is evidence for the agent repair loop, not a request for
human contract approval and not a reason to block implementation.

### 0.3 Minimum contract for every operation

Each OpenAPI operation must be implementable without inference and contain:

| Field | Required content |
|---|---|
| Identity | Unique, stable `operationId`, `tags`, `summary` and behaviorally precise `description`. |
| Version | SemVer-compatible `info.version`; filename retains the public major (`-vN`); change log and compatibility classification (`additive`, `behavioral-compatible`, `breaking`). |
| Method and path | HTTP method and canonical absolute path, with versioned public namespace where applicable. |
| Audience and authorization | OpenAPI `security` plus `x-required-roles` and `x-required-authorities` arrays. A public operation uses `security: []` and records why no role/authority applies. Roles and granular authorities are not interchangeable. |
| Parameters | Every path, query, header and cookie parameter with location, schema, format, bounds, required/default semantics and safe example when useful. |
| Request | `requestBody`, required flag, supported media types, closed schema where applicable, validation constraints and safe examples. |
| Success responses | Every real status code with non-empty `description`, required headers, media type and body schema/example; no-content responses explicitly omit content. |
| Error responses | Every expected error status with cause-specific description, required headers and `application/problem+json` schema carrying a stable domain `errorCode` extension when clients branch on cause. |
| Tenant/security boundary | Source of tenant identity, impersonation rules, anti-enumeration behavior, sensitive-field exclusions and applicable cache policy. |
| Concurrency/resilience | Idempotency, conditional request, retry, rate-limit, timeout and correlation headers whenever applicable; otherwise no invented default. |
| Lifecycle | `deprecated`, replacement, `Deprecation` and `Sunset` metadata when an operation is being retired. |

`default`, `4XX` or `5XX` response ranges may supplement unknown failures but must
not replace known status codes on which a consumer depends. A response body does
not need a duplicated `version` field unless required by the domain; the governing
wire version is `info.version`, while any version header/body member must itself be
declared in the operation.

Because OpenAPI has no standard operation-level field for application roles, this
repository uses the explicit extensions below in addition to the standard
`security` object:

```yaml
security:
  - bearerAuth: []
x-required-roles: [ROLE_TENANT_ADMIN]
x-required-authorities: [BILLING_PROVIDER_READ]
```

An empty role or authority list is explicit and justified in `description`; it is
never inferred from the absence of `@PreAuthorize`.

### 0.4 RFC baseline

- [RFC 9110 — HTTP Semantics](https://www.rfc-editor.org/rfc/rfc9110.html) is
  normative for method semantics, status codes, headers, content negotiation,
  validators and conditional requests. Contract descriptions must not assign a
  status meaning that conflicts with this RFC.
- [RFC 9457 — Problem Details for HTTP APIs](https://www.rfc-editor.org/rfc/rfc9457.html)
  is the default error representation. Errors use `application/problem+json` and
  document `type`, `title`, `status`, `detail`, `instance` when applicable, plus
  safe domain extensions such as `errorCode` and field violations. RFC 9457
  supersedes RFC 7807.
- [RFC 9745 — Deprecation HTTP Response Header](https://www.rfc-editor.org/rfc/rfc9745.html)
  governs the `Deprecation` header and deprecation link. When removal is planned,
  [RFC 8594 — Sunset HTTP Header](https://www.rfc-editor.org/rfc/rfc8594.html)
  governs `Sunset`; the contract must also identify the replacement operation.

A legacy error shape may remain only when an approved requirement or compatibility
decision demands it and the exact media type/schema is documented per response.
New generic `{message, errors}` contracts are prohibited.

### 0.5 Versioning and change control

1. Patch: documentation/schema correction that does not change accepted instances
   or consumer-observable behavior.
2. Minor: additive, backward-compatible operation, optional field or response.
3. Major: removed/renamed operation or field, narrower accepted input, changed
   requiredness/type/meaning, incompatible authorization or incompatible status/
   media type behavior.
4. A breaking change requires a new public major contract or an approved migration
   and deprecation window. Silent breaking changes are prohibited.
5. Contract changes update the contract index and all current requirements, use
   cases and plans that freeze the changed version. Historical evidence keeps the
   version it actually evaluated.

### 0.6 Required parity evidence

Before an affected API task is complete, tests must prove, in the applicable
directions:

- OpenAPI parses with unique keys and all local `$ref` values resolve;
- method/path/parameters, authorization and success/error status matrices match
  the controller and security configuration;
- actual Java serialization matches request/response schemas;
- TypeScript, Zod, generated/manual clients, fixtures and MSW match OpenAPI;
- negative drift sentinels fail when a required field, enum, role, status, media
  type, header or `errorCode` diverges.

The current backend coverage and legacy debt are recorded in
`ANL-00055`.
The bidirectional, operation-level classification is recorded in
`ANL-00057`.
Together they distinguish 228 implemented backend operations from ten production
consumer calls without a controller. All 214 Draft operations remain
non-implementable until their operation-level questions are resolved.

The permanent inventory sentinel is:

```bash
node --test validate-api-contract-coverage.test.mjs
node validate-api-contract-coverage.mjs --root .
```

It is also executed by `./infra/scripts/validate-docs.sh`. A green result proves
only that every implemented mapping has exactly one canonical method/path and that
Drafts expose their blocking metadata. It does not prove payload, serialization,
error, RBAC, tenant-boundary or consumer parity; those tests remain mandatory when
an operation is validated and promoted.

---

## 1. Dependencies

| Package | Version | Purpose |
|---|---|---|
| `@tanstack/react-query` | `^5.x` | Server state management, caching, mutations |
| `@tanstack/react-query-devtools` | `^5.x` | Dev-only query inspector |
| `zod` | `^3.x` | Runtime response validation (optional, for critical endpoints) |
| `msw` | `^2.x` | Mock Service Worker for dev/test without backend |

```bash
pnpm add @tanstack/react-query zod
pnpm add -D @tanstack/react-query-devtools msw
```

---

## 2. API Client Architecture

### File Structure

```
src/
├── lib/
│   ├── apiClient.ts        # Core HTTP client (fetch wrapper)
│   ├── apiError.ts         # Error classes and taxonomy
│   └── env.ts              # Environment variables (API base URL)
├── services/
│   ├── fiscalService.ts    # Fiscal module API calls
│   ├── billingService.ts   # Billing module API calls
│   ├── certificateService.ts
│   └── tenantService.ts
├── hooks/
│   └── queries/
│       ├── useFiscalQueries.ts   # React Query hooks for fiscal
│       ├── useBillingQueries.ts
│       └── useTenantQueries.ts
└── types/
    ├── fiscal.ts           # Fiscal request/response types
    ├── billing.ts
    └── api.ts              # Shared API types (pagination, errors)
```

### Rules

1. **Three layers:** `apiClient` → `services/` → `hooks/queries/`. Components only use hooks.
2. Components **never** import `apiClient` or `services/` directly. Always go through query hooks.
3. One service file per bounded context. One query hooks file per bounded context.

---

## 3. Core API Client

```tsx
// src/lib/apiClient.ts
import { getKeycloak } from '@/lib/keycloak';
import { env } from '@/lib/env';
import { ApiError, NetworkError, AuthError, ForbiddenError, ValidationError, NotFoundError } from '@/lib/apiError';
import { useImpersonateStore } from '@/stores/useImpersonateStore';

async function ensureFreshToken(): Promise<string> {
  const keycloak = getKeycloak();
  try {
    await keycloak.updateToken(10);
  } catch {
    keycloak.login();
    throw new AuthError('Session expired. Redirecting to login.');
  }
  return keycloak.token!;
}

function getImpersonatedTenantId(): string | undefined {
  const keycloak = getKeycloak();
  const parsed = keycloak.tokenParsed as Record<string, unknown> | undefined;
  if (!parsed) throw new AuthError('Session configuration error.');

  const roles = (parsed.realm_access as { roles?: string[] })?.roles ?? [];
  if (roles.includes('ROLE_SUPER_ADMIN')) {
    return useImpersonateStore.getState().selectedTenantId ?? undefined;
  }
  if (!parsed.tenant_id) throw new AuthError('Missing tenant_id in tenant identity.');
  return undefined;
}

async function request<T>(
  endpoint: string,
  options: RequestInit = {},
): Promise<T> {
  const token = await ensureFreshToken();
  const url = `${env.apiBaseUrl}${endpoint}`;

  const headers = new Headers(options.headers);
  headers.set('Content-Type', 'application/json');
  headers.set('Accept', 'application/json');
  headers.set('Authorization', `Bearer ${token}`);
  headers.delete('X-Tenant-ID');
  const impersonatedTenantId = getImpersonatedTenantId();
  if (impersonatedTenantId) headers.set('X-Tenant-ID', impersonatedTenantId);

  const response = await fetch(url, {
    ...options,
    headers,
  }).catch(() => {
    throw new NetworkError('Unable to connect to the server.');
  });

  if (!response.ok) {
    await handleErrorResponse(response);
  }

  if (response.status === 204) return undefined as T;
  return response.json();
}

async function handleErrorResponse(response: Response): Promise<never> {
  const body = await response.text().catch(() => '');

  switch (response.status) {
    case 401:
      getKeycloak().login();
      throw new AuthError('Session expired.');
    case 403:
      throw new ForbiddenError('You do not have permission for this action.');
    case 404:
      throw new NotFoundError('Resource not found.');
    case 422: {
      const parsed = tryParseJson(body);
      throw new ValidationError(
        parsed?.message ?? 'Validation failed.',
        parsed?.errors ?? [],
      );
    }
    default:
      throw new ApiError(response.status, body || 'An unexpected error occurred.');
  }
}

function tryParseJson(text: string): Record<string, unknown> | null {
  try { return JSON.parse(text); }
  catch { return null; }
}

export const apiClient = {
  get: <T>(endpoint: string) =>
    request<T>(endpoint),

  post: <T>(endpoint: string, body?: unknown) =>
    request<T>(endpoint, {
      method: 'POST',
      body: body ? JSON.stringify(body) : undefined,
    }),

  put: <T>(endpoint: string, body?: unknown) =>
    request<T>(endpoint, {
      method: 'PUT',
      body: body ? JSON.stringify(body) : undefined,
    }),

  patch: <T>(endpoint: string, body?: unknown) =>
    request<T>(endpoint, {
      method: 'PATCH',
      body: body ? JSON.stringify(body) : undefined,
    }),

  delete: <T>(endpoint: string) =>
    request<T>(endpoint, { method: 'DELETE' }),
};
```

### Rules

1. **All requests** go through `apiClient`. No raw `fetch()` anywhere else.
2. `env.apiBaseUrl` is the base — endpoints are relative paths (`/v1/fiscal/queries`).
3. Token refresh happens **before** every request (10s buffer).
4. `401` → auto-redirect to Keycloak login. `403` → throw, let UI show Forbidden.
5. `204 No Content` → returns `undefined`, no JSON parsing.
6. Identidade tenant usa a claim JWT e não envia `X-Tenant-ID`; Super Admin global também não
   envia. Somente a seleção explícita de tenant por Super Admin autoriza o header.
7. Headers fornecidos pelo service/caller nunca são fonte de tenant: o cliente remove qualquer
   `X-Tenant-ID` recebido e reinsere apenas o valor autoritativo da impersonação.

---

## 4. Error Taxonomy

```tsx
// src/lib/apiError.ts

export class ApiError extends Error {
  constructor(
    public readonly status: number,
    public readonly body: string,
  ) {
    super(`API Error ${status}`);
    this.name = 'ApiError';
  }
}

export class NetworkError extends Error {
  constructor(message = 'Network error') {
    super(message);
    this.name = 'NetworkError';
  }
}

export class AuthError extends Error {
  constructor(message = 'Authentication required') {
    super(message);
    this.name = 'AuthError';
  }
}

export class ForbiddenError extends Error {
  constructor(message = 'Access denied') {
    super(message);
    this.name = 'ForbiddenError';
  }
}

export class NotFoundError extends Error {
  constructor(message = 'Not found') {
    super(message);
    this.name = 'NotFoundError';
  }
}

export interface FieldError {
  field: string;
  message: string;
}

export class ValidationError extends Error {
  constructor(
    message: string,
    public readonly fieldErrors: FieldError[],
  ) {
    super(message);
    this.name = 'ValidationError';
  }
}
```

### Error Handling Matrix

| HTTP Status | Error Class | UI Behavior |
|---|---|---|
| Network failure | `NetworkError` | Show "Connection error" toast with retry |
| `401 Unauthorized` | `AuthError` | Auto-redirect to Keycloak login |
| `403 Forbidden` | `ForbiddenError` | Show Forbidden page or toast |
| `404 Not Found` | `NotFoundError` | Show "Not found" state or redirect |
| `422 Unprocessable` | `ValidationError` | Map `fieldErrors` to form fields |
| `429 Too Many Requests` | `ApiError` | Show "Too many requests" toast |
| `500+` Server Error | `ApiError` | Show generic error with retry |

### Rules

1. **Never** show raw HTTP status codes or error bodies to users.
2. **Always** use the typed error classes. Never throw plain `Error` in services.
3. `ValidationError.fieldErrors` maps directly to React Hook Form's `setError()`.
4. `AuthError` triggers login redirect. Components should **not** catch or display it.

---

## 5. Service Modules

```tsx
// src/services/fiscalService.ts
import { apiClient } from '@/lib/apiClient';
import type {
  FiscalQuery,
  FiscalQueryListResponse,
  CreateFiscalQueryRequest,
} from '@/types/fiscal';

const BASE = '/v1/fiscal/queries';

export const fiscalService = {
  list: (params?: Record<string, unknown>) => {
    const searchParams = new URLSearchParams();
    if (params) {
      Object.entries(params).forEach(([key, value]) => {
        if (value !== undefined && value !== '') {
          searchParams.set(key, String(value));
        }
      });
    }
    const query = searchParams.toString();
    return apiClient.get<FiscalQueryListResponse>(
      query ? `${BASE}?${query}` : BASE,
    );
  },

  getById: (id: string) =>
    apiClient.get<FiscalQuery>(`${BASE}/${id}`),

  create: (data: CreateFiscalQueryRequest) =>
    apiClient.post<FiscalQuery>(BASE, data),

  delete: (id: string) =>
    apiClient.delete<void>(`${BASE}/${id}`),
};
```

### Rules

1. **One service file** per bounded context (`fiscalService`, `billingService`, etc.).
2. **All methods** return typed promises. No `any` or `unknown` return types.
3. **Base path** as a `const` at the top of the file.
4. Query params built with `URLSearchParams` — skip `undefined` and empty values.
5. Service methods are **stateless functions**. No hooks, no React, no side effects.

---

## 6. Shared API Types

```tsx
// src/types/api.ts

/** Standard paginated response from backend */
export interface PaginatedResponse<T> {
  content: T[];
  page: number;
  size: number;
  totalElements: number;
  totalPages: number;
  first: boolean;
  last: boolean;
}

/** Standard filters for list endpoints */
export interface ListFilters {
  page?: number;
  size?: number;
  sort?: string;
  search?: string;
}

/** Backend error response format */
export interface ErrorResponse {
  message: string;
  errors?: { field: string; message: string }[];
  timestamp?: string;
  path?: string;
}
```

```tsx
// src/types/fiscal.ts
import type { PaginatedResponse } from './api';

export interface FiscalQuery {
  id: string;
  documento: string;
  status: 'PENDING' | 'COMPLETED' | 'ERROR';
  result?: FiscalResult;
  createdAt: string;
  updatedAt: string;
}

export interface FiscalResult {
  situation: string;
  lastQueryDate: string;
}

export interface CreateFiscalQueryRequest {
  documento: string;
}

export type FiscalQueryListResponse = PaginatedResponse<FiscalQuery>;
```

### Rules

1. **All** request/response types live in `src/types/`.
2. One type file per bounded context, plus `api.ts` for shared patterns.
3. Use `interface` for object shapes. Use `type` for unions and aliases.
4. Backend status enums expressed as string literal unions (not TypeScript `enum`).
5. Date fields are `string` (ISO 8601) — format in the UI layer with `Intl.DateTimeFormat`.

---

## 7. React Query Hooks

```tsx
// src/hooks/queries/useFiscalQueries.ts
'use client';

import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { fiscalService } from '@/services/fiscalService';
import type { CreateFiscalQueryRequest, FiscalQuery } from '@/types/fiscal';
import type { ListFilters } from '@/types/api';

// ---- Query Key Factory ----
export const fiscalKeys = {
  all: ['fiscal'] as const,
  lists: () => [...fiscalKeys.all, 'list'] as const,
  list: (filters: ListFilters) => [...fiscalKeys.lists(), filters] as const,
  details: () => [...fiscalKeys.all, 'detail'] as const,
  detail: (id: string) => [...fiscalKeys.details(), id] as const,
};

// ---- Queries ----
export const useFiscalQueryList = (filters: ListFilters = {}) =>
  useQuery({
    queryKey: fiscalKeys.list(filters),
    queryFn: () => fiscalService.list(filters),
  });

export const useFiscalQueryDetail = (id: string) =>
  useQuery({
    queryKey: fiscalKeys.detail(id),
    queryFn: () => fiscalService.getById(id),
    enabled: !!id,
  });

// ---- Mutations ----
export const useCreateFiscalQuery = () => {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: (data: CreateFiscalQueryRequest) => fiscalService.create(data),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: fiscalKeys.lists() });
    },
  });
};

export const useDeleteFiscalQuery = () => {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: (id: string) => fiscalService.delete(id),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: fiscalKeys.lists() });
    },
  });
};
```

### Usage in Components

```tsx
// src/components/fiscal/FiscalQueryPage.tsx
'use client';

import { useFiscalQueryList, useDeleteFiscalQuery } from '@/hooks/queries/useFiscalQueries';
import { ValidationError } from '@/lib/apiError';

export const FiscalQueryPage = () => {
  const { data, isLoading, isError, error, refetch } = useFiscalQueryList();
  const deleteMutation = useDeleteFiscalQuery();

  if (isLoading) return <QueryListSkeleton />;
  if (isError) return <ErrorState message="Erro ao carregar consultas" onRetry={refetch} />;
  if (!data?.content.length) return <EmptyState message="Nenhuma consulta encontrada" />;

  return (
    <ul>
      {data.content.map((query) => (
        <li key={query.id}>{query.documento} — {query.status}</li>
      ))}
    </ul>
  );
};
```

### Rules

1. **Query key factory** is mandatory (`fiscalKeys.list(filters)`). No inline string arrays.
2. Mutations **must** invalidate related queries on success.
3. `enabled: !!id` prevents queries from running with empty params.
4. Components **must** handle `isLoading`, `isError`, and empty data states.
5. **Never** use `useEffect` + `useState` for data fetching. Always React Query.

---

## 8. Error Handling in Forms

```tsx
// src/components/fiscal/CreateFiscalQueryForm.tsx
'use client';

import { useForm } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import { z } from 'zod';
import { useCreateFiscalQuery } from '@/hooks/queries/useFiscalQueries';
import { ValidationError } from '@/lib/apiError';
import { useToast } from '@/hooks/useToast';

const schema = z.object({
  documento: z.string().min(14, 'Documento é obrigatório'),
});

type FormData = z.infer<typeof schema>;

export const CreateFiscalQueryForm = () => {
  const { register, handleSubmit, setError, formState: { errors, isSubmitting } } = useForm<FormData>({
    resolver: zodResolver(schema),
  });

  const createMutation = useCreateFiscalQuery();
  const { toast } = useToast();

  const onSubmit = async (data: FormData) => {
    try {
      await createMutation.mutateAsync(data);
      toast.success('Consulta criada com sucesso!');
    } catch (err) {
      if (err instanceof ValidationError) {
        // Map backend field errors to form fields
        err.fieldErrors.forEach(({ field, message }) => {
          setError(field as keyof FormData, { message });
        });
      } else {
        toast.error('Erro ao criar consulta. Tente novamente.');
      }
    }
  };

  return (
    <form onSubmit={handleSubmit(onSubmit)}>
      <label htmlFor="documento">Documento *</label>
      <input id="documento" {...register('documento')} aria-invalid={!!errors.documento} />
      {errors.documento && <span role="alert">{errors.documento.message}</span>}

      <button type="submit" disabled={isSubmitting}>
        {isSubmitting ? 'Criando...' : 'Criar Consulta'}
      </button>
    </form>
  );
};
```

### Rules

1. `mutateAsync` (not `mutate`) when you need to catch errors in forms.
2. `ValidationError.fieldErrors` maps to `setError()` — field-level server validation.
3. Non-validation errors → toast notification (generic message).
4. Submit button **must** be disabled during submission with a loading indicator.
5. **Never** show stack traces or raw backend messages. Always pt-BR user-friendly text.

---

## 9. Pagination Hook

```tsx
// src/hooks/usePagination.ts
'use client';

import { useSearchParams, useRouter, usePathname } from 'next/navigation';
import { useCallback, useMemo } from 'react';

interface UsePaginationReturn {
  page: number;
  size: number;
  setPage: (page: number) => void;
  setSize: (size: number) => void;
}

export const usePagination = (defaultSize = 10): UsePaginationReturn => {
  const searchParams = useSearchParams();
  const router = useRouter();
  const pathname = usePathname();

  const page = Number(searchParams.get('page') ?? '0');
  const size = Number(searchParams.get('size') ?? String(defaultSize));

  const updateParams = useCallback(
    (updates: Record<string, string>) => {
      const params = new URLSearchParams(searchParams.toString());
      Object.entries(updates).forEach(([k, v]) => params.set(k, v));
      router.replace(`${pathname}?${params.toString()}`);
    },
    [searchParams, router, pathname],
  );

  const setPage = useCallback(
    (p: number) => updateParams({ page: String(p) }),
    [updateParams],
  );

  const setSize = useCallback(
    (s: number) => updateParams({ size: String(s), page: '0' }),
    [updateParams],
  );

  return useMemo(() => ({ page, size, setPage, setSize }), [page, size, setPage, setSize]);
};
```

### Rules

1. Pagination state lives in **URL search params**, not React state.
2. Changing page size resets to page 0.
3. Page is **zero-indexed** (matches Spring Data Pageable backend convention).
4. Combine with React Query: `useFiscalQueryList({ page, size })`.

---

## 10. Retry & Resilience

### React Query Global Config

```tsx
// In src/providers/Providers.tsx
const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      staleTime: 5 * 60 * 1000,      // 5 minutes
      gcTime: 10 * 60 * 1000,         // 10 minutes garbage collection
      retry: (failureCount, error) => {
        if (error instanceof AuthError) return false;      // Don't retry auth errors
        if (error instanceof ForbiddenError) return false;  // Don't retry 403s
        if (error instanceof NotFoundError) return false;   // Don't retry 404s
        return failureCount < 2;                            // Max 2 retries for others
      },
      retryDelay: (attempt) => Math.min(1000 * 2 ** attempt, 10000),
      refetchOnWindowFocus: false,
    },
    mutations: {
      retry: false, // Never auto-retry mutations
    },
  },
});
```

### Rules

1. **Queries** retry up to 2 times with exponential backoff (1s, 2s, capped at 10s).
2. **Auth/Forbidden/NotFound** errors are **not** retried.
3. **Mutations** are **never** auto-retried (user must explicitly retry).
4. `staleTime: 5min` prevents refetching data that was just loaded.
5. `refetchOnWindowFocus: false` — disable in SaaS admin panels (too aggressive).

---

## 11. Tenant-Aware Cache Invalidation

```tsx
// src/hooks/useTenantSwitch.ts
'use client';

import { useQueryClient } from '@tanstack/react-query';
import { getKeycloak } from '@/lib/keycloak';

export const useTenantSwitch = () => {
  const queryClient = useQueryClient();

  const switchTenant = () => {
    // 1. Invalidate ALL cached queries (cross-tenant data leak prevention)
    queryClient.clear();

    // 2. Re-authenticate (new tenant context from Keycloak)
    getKeycloak().login();
  };

  return { switchTenant };
};
```

### Rules

1. On tenant switch: **clear all React Query cache** before re-authenticating.
2. **Never** allow cached data from Tenant A to be displayed after switching to Tenant B.
3. This is a **security requirement**, not just a UX preference.

---

## 12. Mock Service Worker (MSW) — Development

```tsx
// src/mocks/handlers.ts
import { http, HttpResponse } from 'msw';

export const handlers = [
  http.get('/v1/fiscal/queries', () => {
    return HttpResponse.json({
      content: [
        { id: '1', documento: '12.345.678/0001-90', status: 'COMPLETED' },
        { id: '2', documento: '98.765.432/0001-10', status: 'PENDING' },
      ],
      page: 0,
      size: 10,
      totalElements: 2,
      totalPages: 1,
      first: true,
      last: true,
    });
  }),

  http.post('/v1/fiscal/queries', async ({ request }) => {
    const body = await request.json();
    return HttpResponse.json(
      { id: '3', ...body, status: 'PENDING', createdAt: new Date().toISOString() },
      { status: 201 },
    );
  }),
];
```

```tsx
// src/mocks/browser.ts
import { setupWorker } from 'msw/browser';
import { handlers } from './handlers';

export const worker = setupWorker(...handlers);
```

### Initialization (Dev Only)

```tsx
// src/lib/msw-init.ts
export async function initMsw() {
  if (process.env.NODE_ENV !== 'development') return;
  if (process.env.NEXT_PUBLIC_ENABLE_MSW !== 'true') return;

  const { worker } = await import('@/mocks/browser');
  await worker.start({ onUnhandledRequest: 'bypass' });
}
```

### Rules

1. MSW is **dev/test only**. Never ship to production.
2. Enable via `NEXT_PUBLIC_ENABLE_MSW=true` in `.env.local`.
3. Handlers mock the **exact same** response shapes as the backend OpenAPI spec.
4. `onUnhandledRequest: 'bypass'` allows Keycloak and other external calls to pass through.
5. Use MSW when the backend is unavailable or during frontend-first development.

---

## 13. Change Log

| Version | Date | Changes |
|---|---|---|
| 2.2 | 2026-09-10 | Makes bidirectional Frontend/Website ↔ Backend reconciliation mandatory, requires bounded-context placement and defines explicit Draft treatment for consumer-only and backend-only operations. |
| 2.1 | 2026-09-10 | Adds the permanent controller-to-OpenAPI inventory sentinel, links TP-00052/ANL-00055 v1.1 and distinguishes 226/226 inventory coverage from operation-level semantic parity. |
| 2.0 | 2026-09-09 | Makes a canonical OpenAPI 3.1 contract in `docs/api_contracts/` mandatory before API implementation; defines required roles/authorities, method/path, requests, status/body/error/version metadata, RFC 9110/9457/9745/8594 baseline, document linkage, versioning and cross-stack parity evidence. |
| 1.4 | 2026-08-25 | Converges the API client and tenant-aware data-fetching rules under the governed standards collection. |
