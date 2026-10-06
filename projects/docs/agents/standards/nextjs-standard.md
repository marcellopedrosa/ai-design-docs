---
document_id: "NEXTJS-STANDARD"
primary_nature: "Regra"
objective: "Definir regras reutilizáveis e verificáveis para Next.js App Router."
scope: "Rotas, layouts e fronteiras entre componentes server/client no App Router."
non_objectives: "Não criar requisitos de produto, decisões arquiteturais concretas ou procedimentos fora do escopo deste standard."
owner: "Arquitetura e Qualidade"
status: "Active"
date: "2026-08-25"
version: "1.4"
keywords: "nextjs, standard, standard"
related_files: "./README.md, ./frontend-standard.md, ./keycloak-frontend-standard.md, ./rbac-frontend-standard.md"
code_references: "src/app/, src/app/not-found.tsx, src/lib/env.ts, src/hooks/queries/, condicional - src/app/(group)/route/ representa um placeholder de route group, condicional - src/app/(group)/ representa um placeholder de route group, src/components/[feature]/, src/services/, src/types/, src/components/, frontend/"
principal_statement: "As regras de Next.js App Router aplicam-se somente ao escopo e aos controles declarados neste standard."
---

# Next.js App Router Standard — @FrontendWeb / @UIIntegrator

> **Mandatory rules** for Next.js 14+ App Router patterns. This standard complements [`frontend-standard.md`](./frontend-standard.md) (project structure), [`keycloak-frontend-standard.md`](./keycloak-frontend-standard.md) (auth), and [`rbac-frontend-standard.md`](./rbac-frontend-standard.md) (permissions).

---

## 1. Server Components vs. Client Components

### Default: Server Components

Every `.tsx` file inside `src/app/` is a **Server Component** by default. Only add `'use client'` when the component needs:

- React hooks (`useState`, `useEffect`, `useContext`, etc.)
- Browser APIs (`window`, `document`, `localStorage`)
- Event handlers (`onClick`, `onChange`, `onSubmit`)
- Third-party client libraries (`keycloak-js`, `react-hook-form`, `lucide-react`)

### Rules

1. **Minimize `'use client'` surface.** Push `'use client'` as deep as possible in the component tree.
2. **Never** add `'use client'` to layout files unless they use hooks (prefer composing client components inside server layouts).
3. **Server Components** can import Client Components, but **not** vice versa.
4. **Never** import server-only modules (DB, fs, env secrets) in Client Components.

### Pattern: Mixed Layout

```tsx
// src/app/(auth)/layout.tsx — Server Component (no 'use client')
import { AppShell } from '@/components/layout/AppShell'; // Client

export default function AuthLayout({ children }: { children: React.ReactNode }) {
  return <AppShell>{children}</AppShell>;
}
```

```tsx
// src/components/layout/AppShell.tsx — Client Component
'use client';

import { Sidebar } from './Sidebar';
import { TopBar } from './TopBar';

export const AppShell = ({ children }: { children: React.ReactNode }) => {
  // hooks, state, sidebar collapse toggle, etc.
  return (
    <div className="flex h-screen">
      <Sidebar />
      <div className="flex-1 flex flex-col">
        <TopBar />
        <main className="flex-1 overflow-auto p-6">{children}</main>
      </div>
    </div>
  );
};
```

---

## 2. Route Groups & Directory Structure

```
src/app/
├── layout.tsx              # Root layout: <html>, <body>, fonts, global providers
├── globals.css             # Tailwind directives + CSS custom properties
├── not-found.tsx           # Global 404 page
│
├── (public)/               # No authentication required
│   ├── layout.tsx          # Public layout (no sidebar, no topbar)
│   ├── login/
│   │   └── page.tsx        # Login page (triggers Keycloak redirect)
│   └── callback/
│       └── page.tsx        # OAuth2 callback handler (if needed)
│
├── (auth)/                 # Requires authentication (any role)
│   ├── layout.tsx          # <ProtectedRoute> + <AppShell> wrapper
│   ├── dashboard/
│   │   └── page.tsx        # Dashboard home
│   └── profile/
│       └── page.tsx        # User profile
│
├── (fiscal)/               # Requires FISCAL_READER role
│   ├── layout.tsx          # <ProtectedRoute requiredRoles={[ROLES.FISCAL_READER]}>
│   ├── query/
│   │   ├── page.tsx        # Fiscal query list
│   │   └── [id]/
│   │       └── page.tsx    # Fiscal query detail
│   └── reports/
│       └── page.tsx        # Fiscal reports
│
├── (admin)/                # Requires TENANT_ADMIN role
│   ├── layout.tsx          # <ProtectedRoute requiredRoles={[ROLES.TENANT_ADMIN]}>
│   ├── settings/
│   │   └── page.tsx        # Tenant settings
│   └── users/
│       ├── page.tsx        # User list
│       └── [id]/
│           └── page.tsx    # User detail/edit
│
└── api/                    # API Routes (if needed for BFF patterns)
    └── health/
        └── route.ts        # Health check endpoint
```

### Rules

1. Route groups `(groupName)/` **do not** affect the URL path. `(fiscal)/query/page.tsx` → `/query`.
2. Each route group **must** have its own `layout.tsx` with appropriate `ProtectedRoute` wrapper.
3. **Never** mix public and authenticated pages in the same route group.
4. Dynamic routes use `[param]` syntax: `[id]/page.tsx` → `/123`.
5. Catch-all routes use `[...slug]`: `[...slug]/page.tsx` → `/a/b/c`.
6. Route groups exist for **layout separation and RBAC**, not URL structure.

---

## 3. Layouts

### Root Layout (Required)

```tsx
// src/app/layout.tsx — Server Component
import type { Metadata } from 'next';
import { Inter } from 'next/font/google';
import { Providers } from '@/providers/Providers';
import './globals.css';

const inter = Inter({ subsets: ['latin'], variable: '--font-inter' });

export const metadata: Metadata = {
  title: {
    template: '%s | Contador Fiscal',
    default: 'Contador Fiscal',
  },
  description: 'Plataforma inteligente de gestão contábil',
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="pt-BR" className={inter.variable}>
      <body className="font-sans antialiased bg-background text-neutral-900">
        <Providers>{children}</Providers>
      </body>
    </html>
  );
}
```

### Providers Wrapper (Client Component)

```tsx
// src/providers/Providers.tsx
'use client';

import { type ReactNode } from 'react';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { AuthProvider } from './AuthProvider';
import { ThemeProvider } from './ThemeProvider';
import { ToastProvider } from './ToastProvider';

const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      staleTime: 5 * 60 * 1000,    // 5 minutes
      retry: 1,
      refetchOnWindowFocus: false,
    },
  },
});

export const Providers = ({ children }: { children: ReactNode }) => (
  <QueryClientProvider client={queryClient}>
    <AuthProvider>
      <ThemeProvider>
        <ToastProvider>{children}</ToastProvider>
      </ThemeProvider>
    </AuthProvider>
  </QueryClientProvider>
);
```

### Rules

1. Root layout is a **Server Component**. All providers go into a `'use client'` `Providers` component.
2. Provider nesting order: `QueryClient` → `Auth` → `Theme` → `Toast` (outside → inside).
3. **One** `<html>` and `<body>` per application — only in root layout.
4. The `Inter` font is loaded via `next/font/google` (no external CSS links).
5. `metadata` **must** use `template` pattern for consistent page titles.
6. Nested layouts **must not** redefine `<html>` or `<body>`.

---

## 4. Page Files

### Standard Page Pattern

```tsx
// src/app/(fiscal)/query/page.tsx
import type { Metadata } from 'next';
import { FiscalQueryPage } from '@/components/fiscal/FiscalQueryPage';

export const metadata: Metadata = {
  title: 'Consulta Fiscal',
  description: 'Consulte situação fiscal de empresas por Documento',
};

export default function Page() {
  return <FiscalQueryPage />;
}
```

### Dynamic Route Page

```tsx
// src/app/(fiscal)/query/[id]/page.tsx
import type { Metadata } from 'next';
import { FiscalQueryDetail } from '@/components/fiscal/FiscalQueryDetail';

interface PageProps {
  params: Promise<{ id: string }>;
}

export async function generateMetadata({ params }: PageProps): Promise<Metadata> {
  const { id } = await params;
  return {
    title: `Consulta #${id}`,
  };
}

export default async function Page({ params }: PageProps) {
  const { id } = await params;
  return <FiscalQueryDetail queryId={id} />;
}
```

### Rules

1. Page files **must** be thin. They define metadata and delegate to feature components.
2. **Never** put business logic, hooks, or data fetching directly in `page.tsx`.
3. **Every** page **must** export a `metadata` object or `generateMetadata` function.
4. Page components use `default export`. All other components use **named exports**.
5. Dynamic `params` is a `Promise` in Next.js 15+ — always `await` it.

---

## 5. Loading, Error & Not Found Boundaries

### Loading (per-route)

```tsx
// src/app/(fiscal)/query/loading.tsx
import { QueryListSkeleton } from '@/components/fiscal/QueryListSkeleton';

export default function Loading() {
  return <QueryListSkeleton />;
}
```

### Error (per-route)

```tsx
// src/app/(fiscal)/query/error.tsx
'use client';

import { AlertTriangle } from 'lucide-react';

export default function Error({
  error,
  reset,
}: {
  error: Error & { digest?: string };
  reset: () => void;
}) {
  return (
    <div className="flex flex-col items-center justify-center min-h-[40vh] gap-4">
      <AlertTriangle className="w-12 h-12 text-error" />
      <h2 className="text-xl font-semibold text-neutral-900">
        Algo deu errado
      </h2>
      <p className="text-neutral-500 text-center max-w-md">
        Ocorreu um erro ao carregar esta página. Tente novamente.
      </p>
      <button
        onClick={reset}
        className="px-4 py-2 bg-primary text-white rounded-md hover:bg-primary-dark"
      >
        Tentar novamente
      </button>
    </div>
  );
}
```

### Not Found (per-route or global)

```tsx
// src/app/not-found.tsx
import { FileQuestion } from 'lucide-react';
import Link from 'next/link';

export default function NotFound() {
  return (
    <div className="flex flex-col items-center justify-center min-h-[60vh] gap-4">
      <FileQuestion className="w-16 h-16 text-neutral-300" />
      <h1 className="text-2xl font-bold text-neutral-900">
        Página não encontrada
      </h1>
      <p className="text-neutral-500">
        A página que você procura não existe ou foi removida.
      </p>
      <Link
        href="/"
        className="px-4 py-2 bg-primary text-white rounded-md hover:bg-primary-dark"
      >
        Voltar ao início
      </Link>
    </div>
  );
}
```

### Rules

1. **Every** route group **must** have `loading.tsx` and `error.tsx`.
2. **Global** `not-found.tsx` at `src/app/not-found.tsx` is mandatory.
3. `loading.tsx` **must** use skeleton screens that match the page layout (not generic spinners).
4. `error.tsx` **must** be a Client Component (`'use client'`).
5. `error.tsx` **must** provide a retry button via `reset()`.
6. **Never** show raw error messages or stack traces. Show user-friendly messages in pt-BR.

---

## 6. Middleware

```tsx
// src/middleware.ts
import { NextResponse, type NextRequest } from 'next/server';

const PUBLIC_PATHS = [
  '/login',
  '/callback',
  '/silent-check-sso.html',
];

const STATIC_PATHS = [
  '/_next',
  '/favicon.ico',
  '/images',
  '/fonts',
];

export function middleware(request: NextRequest) {
  const { pathname } = request.nextUrl;

  // Skip static assets
  if (STATIC_PATHS.some((p) => pathname.startsWith(p))) {
    return NextResponse.next();
  }

  // Allow public paths
  if (PUBLIC_PATHS.some((p) => pathname.startsWith(p))) {
    return NextResponse.next();
  }

  // Security headers
  const response = NextResponse.next();
  response.headers.set('X-Frame-Options', 'DENY');
  response.headers.set('X-Content-Type-Options', 'nosniff');
  response.headers.set('Referrer-Policy', 'strict-origin-when-cross-origin');
  response.headers.set(
    'Permissions-Policy',
    'camera=(), microphone=(), geolocation=()',
  );

  return response;
}

export const config = {
  matcher: ['/((?!_next/static|_next/image|favicon.ico).*)'],
};
```

### Rules

1. Middleware runs on the **Edge Runtime** (server-side). No access to Keycloak JS here.
2. Auth redirect logic is handled by `ProtectedRoute` (client-side), **not** middleware.
3. Middleware is used for **security headers** and **public path allowlisting**.
4. **Never** call external APIs or databases from middleware.
5. Keep middleware fast (< 50ms execution).

---

## 7. Environment Variables

### Naming Convention

| Prefix | Access | Example |
|---|---|---|
| `NEXT_PUBLIC_` | Client + Server | `NEXT_PUBLIC_KEYCLOAK_URL` |
| (no prefix) | Server only | `DATABASE_URL`, `KEYCLOAK_ADMIN_SECRET` |

### Required Variables

```env
# .env.local
# ---- Public (client-accessible) ----
NEXT_PUBLIC_API_BASE_URL=http://localhost:8081
NEXT_PUBLIC_KEYCLOAK_URL=http://localhost:8080
NEXT_PUBLIC_KEYCLOAK_REALM=saas
NEXT_PUBLIC_KEYCLOAK_CLIENT_ID=saas-frontend-spa
NEXT_PUBLIC_APP_NAME=Contador Fiscal

# ---- Server-only ----
# (none initially — SPA pattern, all API calls from client)
```

### Env Config Module

```tsx
// src/lib/env.ts
export const env = {
  apiBaseUrl: process.env.NEXT_PUBLIC_API_BASE_URL!,
  keycloak: {
    url: process.env.NEXT_PUBLIC_KEYCLOAK_URL!,
    realm: process.env.NEXT_PUBLIC_KEYCLOAK_REALM!,
    clientId: process.env.NEXT_PUBLIC_KEYCLOAK_CLIENT_ID!,
  },
  appName: process.env.NEXT_PUBLIC_APP_NAME ?? 'Contador Fiscal',
} as const;
```

### Rules

1. **All** env vars accessed via `src/lib/env.ts`. Never use `process.env.` directly in components.
2. Non-prefixed vars are **invisible** to the browser — use for server-only secrets.
3. `.env.local` is gitignored. `.env.example` with all keys (no values) **must** be committed.
4. Missing required env vars **must** fail at build time, not silently at runtime.

---

## 8. Navigation (Link & Router)

### Link Component

```tsx
import Link from 'next/link';

// ✅ CORRECT — Always use next/link
<Link href="/fiscal/query">Consulta Fiscal</Link>

// ✅ CORRECT — Dynamic route
<Link href={`/fiscal/query/${queryId}`}>Ver detalhes</Link>

// ❌ WRONG — Never use <a> for internal navigation
<a href="/fiscal/query">Consulta Fiscal</a>
```

### Programmatic Navigation

```tsx
'use client';

import { useRouter } from 'next/navigation';

export const MyComponent = () => {
  const router = useRouter();

  const handleSave = async () => {
    await saveData();
    router.push('/fiscal/query');
  };

  const handleCancel = () => {
    router.back();
  };

  return (/* ... */);
};
```

### Rules

1. **Always** use `next/link` for navigation. Never `<a href>` for internal routes.
2. **Always** import `useRouter` from `next/navigation`, **not** from `next/router`.
3. Use `router.push()` for programmatic navigation after actions (save, delete).
4. Use `router.back()` for cancel actions.
5. Use `router.replace()` when redirecting (e.g., after login) — avoids back button returning to login.
6. **Never** use `window.location.href` for internal navigation.

---

## 9. Data Fetching Pattern

This application uses a **client-side SPA pattern** with TanStack Query (React Query). Server-side data fetching is reserved for static/SEO pages only.

### Client-Side (Primary Pattern)

```tsx
// src/hooks/queries/useFiscalQueries.ts
'use client';

import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { fiscalService } from '@/services/fiscalService';
import type { FiscalQuery, CreateFiscalQueryRequest } from '@/types/fiscal';

// ---- Query Keys ----
export const fiscalKeys = {
  all: ['fiscal'] as const,
  lists: () => [...fiscalKeys.all, 'list'] as const,
  list: (filters: Record<string, unknown>) =>
    [...fiscalKeys.lists(), filters] as const,
  details: () => [...fiscalKeys.all, 'detail'] as const,
  detail: (id: string) => [...fiscalKeys.details(), id] as const,
};

// ---- Queries ----
export const useFiscalQueryList = (filters: Record<string, unknown> = {}) =>
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
    mutationFn: (data: CreateFiscalQueryRequest) =>
      fiscalService.create(data),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: fiscalKeys.lists() });
    },
  });
};
```

### Rules

1. **Primary pattern: client-side** with TanStack Query. All API calls are from the browser.
2. Query keys use a **factory pattern** (`fiscalKeys.list(filters)`).
3. Mutations **must** invalidate related queries via `queryClient.invalidateQueries()`.
4. `enabled: !!id` prevents queries from running with empty/undefined params.
5. **Never** fetch data in `page.tsx` directly. Create hooks in `src/hooks/queries/`.
6. **Never** use `getServerSideProps` or `getStaticProps` — App Router uses different patterns.
7. Server Components with `fetch` are reserved for **public/SEO pages only** (if ever needed).

---

## 10. Image & Font Optimization

### Images

```tsx
import Image from 'next/image';

// ✅ CORRECT
<Image src="/images/logo.svg" alt="Contador Fiscal" width={120} height={40} priority />

// ❌ WRONG — Never use raw <img>
<img src="/images/logo.svg" alt="Contador Fiscal" />
```

### Fonts

```tsx
// Loaded in root layout (see Section 3)
import { Inter } from 'next/font/google';
const inter = Inter({ subsets: ['latin'], variable: '--font-inter' });
```

### Rules

1. **Always** use `next/image` for images. Enables automatic optimization, lazy loading, and WebP conversion.
2. **Always** use `next/font/google` for fonts. Eliminates layout shift and external requests.
3. Use `priority` on above-the-fold images (logo, hero).
4. Use `fill` prop for responsive images inside a container.
5. **Always** provide `alt` text. Empty `alt=""` only for purely decorative images.

---

## 11. SEO & Metadata

### Static Metadata

```tsx
// src/app/(fiscal)/query/page.tsx
import type { Metadata } from 'next';

export const metadata: Metadata = {
  title: 'Consulta Fiscal',
  description: 'Consulte a situação fiscal de empresas por Documento',
};
```

### Dynamic Metadata

```tsx
export async function generateMetadata({ params }: PageProps): Promise<Metadata> {
  const { id } = await params;
  return {
    title: `Consulta #${id}`,
    description: `Detalhes da consulta fiscal ${id}`,
  };
}
```

### Rules

1. **Every page** must have `metadata` or `generateMetadata`.
2. Root layout defines `title.template: '%s | Contador Fiscal'`.
3. Page titles are **pt-BR**, concise, and descriptive.
4. **Never** duplicate the app name in page titles (already in template).

---

## 12. File Organization Checklist

For each new route/feature, create:

| File | Location | Required |
|---|---|---|
| `page.tsx` | `src/app/(group)/route/` | ✅ Always |
| `loading.tsx` | `src/app/(group)/route/` | ✅ Always |
| `error.tsx` | `src/app/(group)/route/` | ✅ Always |
| `layout.tsx` | `src/app/(group)/` | ✅ Per route group |
| Feature component | `src/components/[feature]/` | ✅ Always |
| Query hooks | `src/hooks/queries/` | ✅ If fetching data |
| Service module | `src/services/` | ✅ If calling API |
| Types | `src/types/` | ✅ If shared types |

### Rules

1. **Never** put component logic directly in `page.tsx`. Delegate to `src/components/`.
2. **Never** create a route without `loading.tsx` and `error.tsx`.
3. Group query hooks by domain module: `useFiscalQueries.ts`, `useBillingQueries.ts`.
4. Group services by domain module: `fiscalService.ts`, `billingService.ts`.
