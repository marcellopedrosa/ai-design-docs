---
document_id: "STATE-MANAGEMENT-STANDARD"
primary_nature: "Regra"
objective: "Definir regras reutilizáveis e verificáveis para State Management & Hooks."
scope: "Estado local/remoto, hooks, sincronização e responsabilidades de cache."
non_objectives: "Não criar requisitos de produto, decisões arquiteturais concretas ou procedimentos fora do escopo deste standard."
owner: "Arquitetura e Qualidade"
status: "Active"
date: "2026-08-25"
version: "1.4"
keywords: "state, management, standard, standard"
related_files: "./README.md, ./nextjs-standard.md, ./api-client-standard.md"
code_references: "src/stores/, src/hooks/, src/hooks/queries/, frontend/"
principal_statement: "As regras de State Management & Hooks aplicam-se somente ao escopo e aos controles declarados neste standard."
---

# State Management & Hooks Standard — @FrontendWeb / @UIIntegrator

> **Mandatory rules** for state management and custom hook architecture. This standard classifies state into categories, defines when to use each tool (React state, Context, Zustand, React Query, URL), and establishes patterns for custom hook design, composition, and testing.

> **Prerequisite:** Read [`nextjs-standard.md`](./nextjs-standard.md) and [`api-client-standard.md`](./api-client-standard.md) first.

---

## 1. State Categories

| Category | Tool | Example | Persistence |
|---|---|---|---|
| **Server state** | TanStack React Query | API data: fiscal queries, user list, billing | Cache with staleTime |
| **Auth state** | React Context (`AuthProvider`) | User, token, roles, scopes, tenantId | In-memory (session) |
| **UI state (local)** | `useState` / `useReducer` | Modal open, sidebar collapsed, tab index | Component lifecycle |
| **UI state (global)** | Zustand | Theme, sidebar collapsed, notification queue | In-memory (app lifecycle) |
| **Form state** | React Hook Form + Zod | Input values, validation errors, dirty flags | Component lifecycle |
| **URL state** | `useSearchParams` / `usePathname` | Pagination, filters, active tab, sort order | URL (shareable) |

### Rules

1. **Never** use React Query for client-only state. React Query is for **server state only**.
2. **Never** use React Context for frequently updating values (causes full subtree re-renders).
3. **Never** use `localStorage`/`sessionStorage` for auth tokens — in-memory only.
4. **Always** default to the simplest tool: `useState` first, escalate only when needed.
5. State that should survive page refresh → URL params or Zustand with persist middleware.
6. State that should be shareable via link → URL params (filters, pagination, tabs).

---

## 2. Local State — useState & useReducer

### useState (Simple Values)

```tsx
// ✅ CORRECT — Simple toggle
const [isOpen, setIsOpen] = useState(false);

// ✅ CORRECT — Derived state computed inline, no separate state
const filteredItems = items.filter((item) => item.status === activeFilter);

// ❌ WRONG — Derived state stored separately
const [filteredItems, setFilteredItems] = useState<Item[]>([]);
useEffect(() => {
  setFilteredItems(items.filter((item) => item.status === activeFilter));
}, [items, activeFilter]);
```

### useReducer (Complex State Logic)

```tsx
// src/hooks/useMultiStepForm.ts
'use client';

import { useReducer } from 'react';

interface FormState {
  step: number;
  data: Record<string, unknown>;
  errors: Record<string, string>;
}

type FormAction =
  | { type: 'NEXT_STEP' }
  | { type: 'PREV_STEP' }
  | { type: 'SET_DATA'; payload: Record<string, unknown> }
  | { type: 'SET_ERRORS'; payload: Record<string, string> }
  | { type: 'RESET' };

const initialState: FormState = { step: 0, data: {}, errors: {} };

function formReducer(state: FormState, action: FormAction): FormState {
  switch (action.type) {
    case 'NEXT_STEP':
      return { ...state, step: state.step + 1, errors: {} };
    case 'PREV_STEP':
      return { ...state, step: Math.max(0, state.step - 1) };
    case 'SET_DATA':
      return { ...state, data: { ...state.data, ...action.payload } };
    case 'SET_ERRORS':
      return { ...state, errors: action.payload };
    case 'RESET':
      return initialState;
    default:
      return state;
  }
}

export const useMultiStepForm = (totalSteps: number) => {
  const [state, dispatch] = useReducer(formReducer, initialState);

  return {
    ...state,
    isFirstStep: state.step === 0,
    isLastStep: state.step === totalSteps - 1,
    nextStep: () => dispatch({ type: 'NEXT_STEP' }),
    prevStep: () => dispatch({ type: 'PREV_STEP' }),
    setData: (data: Record<string, unknown>) =>
      dispatch({ type: 'SET_DATA', payload: data }),
    setErrors: (errors: Record<string, string>) =>
      dispatch({ type: 'SET_ERRORS', payload: errors }),
    reset: () => dispatch({ type: 'RESET' }),
  };
};
```

### Rules

1. Use `useState` for **independent, simple values** (booleans, strings, numbers).
2. Use `useReducer` when state has **multiple related values** or **complex transitions**.
3. **Never** store derived/computed state. Compute inline or use `useMemo`.
4. **Never** use `useEffect` to sync state — this is a code smell.

---

## 3. React Context — When and How

### When to Use Context

| ✅ Use Context For | ❌ Do NOT Use Context For |
|---|---|
| Auth state (changes infrequently) | Theme toggle (use Zustand) |
| Feature flags (set once at startup) | Sidebar collapsed state (use Zustand) |
| Tenant config (changes on tenant switch) | Notification queue (use Zustand) |
| Toast/snackbar provider | Form state (use React Hook Form) |

### Context Pattern

```tsx
// src/providers/TenantProvider.tsx
'use client';

import { createContext, useContext, useMemo, type ReactNode } from 'react';
import { useAuth } from '@/hooks/useAuth';

interface TenantContextValue {
  tenantId: string;
  tenantName: string;
}

const TenantContext = createContext<TenantContextValue | undefined>(undefined);

export const TenantProvider = ({ children }: { children: ReactNode }) => {
  const { user } = useAuth();

  const value = useMemo(
    () => ({
      tenantId: user?.tenantId ?? '',
      tenantName: user?.tenantId ?? '', // Resolved from tenant API if needed
    }),
    [user?.tenantId],
  );

  return (
    <TenantContext.Provider value={value}>{children}</TenantContext.Provider>
  );
};

export const useTenant = () => {
  const context = useContext(TenantContext);
  if (!context) throw new Error('useTenant must be used within TenantProvider');
  return context;
};
```

### Rules

1. Every Context **must** have a corresponding `use[Name]` hook. Never `useContext()` directly.
2. Every Context hook **must** throw if used outside its Provider (fail-fast).
3. Context value **must** be memoized with `useMemo` to prevent unnecessary re-renders.
4. **Maximum 5 Context providers** in the app. Beyond that, use Zustand.
5. Nesting order in `Providers.tsx`: `QueryClient` → `Auth` → `Tenant` → `Theme` → `Toast`.

---

## 4. Zustand — Global UI State

### Dependencies

```bash
pnpm add zustand
```

### Store Pattern

```tsx
// src/stores/useUIStore.ts
import { create } from 'zustand';

interface UIState {
  sidebarCollapsed: boolean;
  toggleSidebar: () => void;
  setSidebarCollapsed: (collapsed: boolean) => void;
}

export const useUIStore = create<UIState>((set) => ({
  sidebarCollapsed: false,
  toggleSidebar: () => set((s) => ({ sidebarCollapsed: !s.sidebarCollapsed })),
  setSidebarCollapsed: (collapsed) => set({ sidebarCollapsed: collapsed }),
}));
```

### Store with Persist

```tsx
// src/stores/usePreferencesStore.ts
import { create } from 'zustand';
import { persist } from 'zustand/middleware';

interface PreferencesState {
  theme: 'light' | 'dark' | 'system';
  locale: string;
  pageSize: number;
  setTheme: (theme: PreferencesState['theme']) => void;
  setLocale: (locale: string) => void;
  setPageSize: (size: number) => void;
}

export const usePreferencesStore = create<PreferencesState>()(
  persist(
    (set) => ({
      theme: 'system',
      locale: 'pt-BR',
      pageSize: 10,
      setTheme: (theme) => set({ theme }),
      setLocale: (locale) => set({ locale }),
      setPageSize: (pageSize) => set({ pageSize }),
    }),
    {
      name: 'user-preferences', // localStorage key
    },
  ),
);
```

### Notification Store

```tsx
// src/stores/useNotificationStore.ts
import { create } from 'zustand';

export interface Notification {
  id: string;
  type: 'success' | 'error' | 'warning' | 'info';
  message: string;
  duration?: number;
}

interface NotificationState {
  notifications: Notification[];
  addNotification: (notification: Omit<Notification, 'id'>) => void;
  removeNotification: (id: string) => void;
  clearAll: () => void;
}

export const useNotificationStore = create<NotificationState>((set) => ({
  notifications: [],
  addNotification: (notification) =>
    set((s) => ({
      notifications: [
        ...s.notifications,
        { ...notification, id: crypto.randomUUID() },
      ],
    })),
  removeNotification: (id) =>
    set((s) => ({
      notifications: s.notifications.filter((n) => n.id !== id),
    })),
  clearAll: () => set({ notifications: [] }),
}));
```

### File Structure

```
src/stores/
├── useUIStore.ts              # Sidebar, modals, layout
├── usePreferencesStore.ts     # Theme, locale, page size (persisted)
└── useNotificationStore.ts    # Toast/notification queue
```

### Rules

1. **One store per concern.** Never create a single god-store.
2. Use `persist` middleware only for **user preferences** (theme, locale, page size).
3. **Never** persist auth tokens or sensitive data in Zustand/localStorage.
4. Store files go in `src/stores/`. Naming: `use[Domain]Store.ts`.
5. Selectors for performance: `useUIStore((s) => s.sidebarCollapsed)` — subscribe to slices, not the full store.

---

## 5. URL State

URL state is defined in [`api-client-standard.md`](./api-client-standard.md) Section 9 (`usePagination`). Additionally:

### useFilters Hook

```tsx
// src/hooks/useFilters.ts
'use client';

import { useSearchParams, useRouter, usePathname } from 'next/navigation';
import { useCallback, useMemo } from 'react';

export const useFilters = <T extends Record<string, string>>() => {
  const searchParams = useSearchParams();
  const router = useRouter();
  const pathname = usePathname();

  const filters = useMemo(() => {
    const result: Record<string, string> = {};
    searchParams.forEach((value, key) => {
      result[key] = value;
    });
    return result as T;
  }, [searchParams]);

  const setFilter = useCallback(
    (key: keyof T, value: string | undefined) => {
      const params = new URLSearchParams(searchParams.toString());
      if (value === undefined || value === '') {
        params.delete(key as string);
      } else {
        params.set(key as string, value);
      }
      params.set('page', '0'); // Reset pagination on filter change
      router.replace(`${pathname}?${params.toString()}`);
    },
    [searchParams, router, pathname],
  );

  const clearFilters = useCallback(() => {
    router.replace(pathname);
  }, [router, pathname]);

  return { filters, setFilter, clearFilters };
};
```

### Rules

1. Filters, pagination, sort, and active tab **must** live in URL search params.
2. Changing a filter **must** reset pagination to page 0.
3. Clearing filters removes all search params (clean URL).
4. URL state is the **source of truth** — components read from `useSearchParams`.

---

## 6. Custom Hook Design Rules

### Naming

| Pattern | Purpose | Example |
|---|---|---|
| `use[Feature]` | Domain-specific behavior | `useAuth`, `useTenant` |
| `use[Feature]Queries` | React Query wrappers | `useFiscalQueries` |
| `use[Action]` | Imperative action | `useLogout`, `useTenantSwitch` |
| `use[UI]` | UI behavior | `useDebounce`, `useMediaQuery`, `useClickOutside` |
| `use[Store]Store` | Zustand store | `useUIStore`, `usePreferencesStore` |

### Structure

```tsx
// src/hooks/useDebounce.ts
'use client';

import { useState, useEffect } from 'react';

export const useDebounce = <T>(value: T, delayMs = 300): T => {
  const [debouncedValue, setDebouncedValue] = useState(value);

  useEffect(() => {
    const timer = setTimeout(() => setDebouncedValue(value), delayMs);
    return () => clearTimeout(timer);
  }, [value, delayMs]);

  return debouncedValue;
};
```

```tsx
// src/hooks/useClickOutside.ts
'use client';

import { useEffect, type RefObject } from 'react';

export const useClickOutside = (
  ref: RefObject<HTMLElement | null>,
  handler: () => void,
) => {
  useEffect(() => {
    const listener = (event: MouseEvent | TouchEvent) => {
      if (!ref.current || ref.current.contains(event.target as Node)) return;
      handler();
    };

    document.addEventListener('mousedown', listener);
    document.addEventListener('touchstart', listener);
    return () => {
      document.removeEventListener('mousedown', listener);
      document.removeEventListener('touchstart', listener);
    };
  }, [ref, handler]);
};
```

```tsx
// src/hooks/useMediaQuery.ts
'use client';

import { useState, useEffect } from 'react';

export const useMediaQuery = (query: string): boolean => {
  const [matches, setMatches] = useState(false);

  useEffect(() => {
    const media = window.matchMedia(query);
    setMatches(media.matches);

    const listener = (e: MediaQueryListEvent) => setMatches(e.matches);
    media.addEventListener('change', listener);
    return () => media.removeEventListener('change', listener);
  }, [query]);

  return matches;
};

// Convenience exports
export const useIsMobile = () => useMediaQuery('(max-width: 768px)');
export const useIsDesktop = () => useMediaQuery('(min-width: 1024px)');
```

### Rules

1. **Every hook** starts with `use`. No exceptions.
2. **Every hook** has `'use client'` directive (hooks are client-only in Next.js).
3. **Every hook** lives in `src/hooks/` (flat) or `src/hooks/queries/` (React Query).
4. Hooks **must** be pure functions — same inputs, same outputs. No hidden side effects.
5. Hooks **must** clean up: `useEffect` returns a cleanup function when subscribing to events.
6. **Never** create a hook that wraps a single `useState` — that's over-abstraction.

---

## 7. Hook Composition

### Pattern: Compose Multiple Hooks

```tsx
// src/hooks/useFiscalSearch.ts
'use client';

import { useDebounce } from './useDebounce';
import { useFilters } from './useFilters';
import { usePagination } from './usePagination';
import { useFiscalQueryList } from './queries/useFiscalQueries';

interface FiscalFilters {
  search?: string;
  status?: string;
}

export const useFiscalSearch = () => {
  const { filters, setFilter, clearFilters } = useFilters<FiscalFilters>();
  const { page, size, setPage } = usePagination();
  const debouncedSearch = useDebounce(filters.search ?? '', 400);

  const query = useFiscalQueryList({
    search: debouncedSearch,
    status: filters.status,
    page,
    size,
  });

  return {
    // Query state
    ...query,
    // Filter controls
    filters,
    setFilter,
    clearFilters,
    // Pagination
    page,
    size,
    setPage,
  };
};
```

### Usage in Component

```tsx
export const FiscalQueryPage = () => {
  const {
    data, isLoading, isError, refetch,
    filters, setFilter, clearFilters,
    page, setPage,
  } = useFiscalSearch();

  return (
    <div>
      <SearchInput
        value={filters.search ?? ''}
        onChange={(value) => setFilter('search', value)}
      />
      <StatusFilter
        value={filters.status}
        onChange={(value) => setFilter('status', value)}
      />
      <button onClick={clearFilters}>Limpar filtros</button>

      {isLoading && <Skeleton />}
      {isError && <ErrorState onRetry={refetch} />}
      {data && <QueryTable data={data.content} />}
      {data && <Pagination page={page} totalPages={data.totalPages} onPageChange={setPage} />}
    </div>
  );
};
```

### Rules

1. **Compose hooks** to build feature-specific hooks from generic ones.
2. The feature hook encapsulates **all state** for a page/feature (query + filters + pagination).
3. Components receive a **flat API** from the composed hook — no nested objects.
4. **Never** call hooks conditionally. Hooks must always be called in the same order.
5. **Never** pass hooks as props. Pass the **values** from hooks as props.

---

## 8. Anti-Patterns

| ❌ Anti-Pattern | ✅ Correct Approach |
|---|---|
| `useEffect` to sync state from props | Compute inline or use `useMemo` |
| `useState` + `useEffect` for API data | React Query (`useQuery`) |
| `useContext` for rapidly changing values | Zustand store with selectors |
| Prop drilling through 5+ levels | Context (if infrequent) or Zustand |
| Multiple `useState` for related values | `useReducer` |
| Storing derived state | Compute inline: `const total = items.reduce(...)` |
| `useCallback` / `useMemo` on everything | Only memoize when profiling shows re-render issues |
| Global state for form values | React Hook Form (local to the form) |
| `localStorage` for auth tokens | In-memory via `AuthProvider` |

### Rules

1. **Never** use `useEffect` for state synchronization. This is the #1 React anti-pattern.
2. **Never** prematurely optimize with `useMemo`/`useCallback`. Profile first.
3. **Never** put form state in global stores. Forms are local by nature.

---

## 9. Hook Inventory

Standard hooks available in `src/hooks/`:

| Hook | Source | Purpose |
|---|---|---|
| `useAuth` | `keycloak-frontend-standard` | Auth state, login, logout, hasRole, hasScope |
| `usePermission` | `rbac-frontend-standard` | Check roles/scopes with AND/OR logic |
| `useModuleAccess` | `rbac-frontend-standard` | Full module access map for sidebar |
| `usePagination` | `api-client-standard` | URL-based pagination state |
| `useTenantSwitch` | `api-client-standard` | Clear cache and re-authenticate |
| `useFilters` | This standard | URL-based generic filter state |
| `useDebounce` | This standard | Debounce a value for search |
| `useClickOutside` | This standard | Detect click outside a ref |
| `useMediaQuery` | This standard | Responsive breakpoint detection |
| `useIsMobile` | This standard | `max-width: 768px` shortcut |
| `useIsDesktop` | This standard | `min-width: 1024px` shortcut |
| `useTenant` | This standard | Tenant context (tenantId, tenantName) |

Zustand stores in `src/stores/`:

| Store | Purpose |
|---|---|
| `useUIStore` | Sidebar, modals, layout state |
| `usePreferencesStore` | Theme, locale, page size (persisted) |
| `useNotificationStore` | Toast/notification queue |
