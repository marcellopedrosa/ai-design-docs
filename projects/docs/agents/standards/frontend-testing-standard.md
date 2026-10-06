---
document_id: "FRONTEND-TESTING-STANDARD"
primary_nature: "Regra"
objective: "Definir regras reutilizáveis e verificáveis para Frontend Testing."
scope: "Testes unitários, integração, componentes e E2E do frontend."
non_objectives: "Não criar requisitos de produto, decisões arquiteturais concretas ou procedimentos fora do escopo deste standard."
owner: "Arquitetura e Qualidade"
status: "Active"
date: "2026-08-25"
version: "1.5"
keywords: "frontend, testing, standard, standard"
related_files: "./README.md, ./software-quality-standard.md"
code_references: "frontend/src/test/, frontend/src/app/, frontend/vitest.config.ts, frontend/package.json, infra/scripts/validate-quality-gates.sh"
principal_statement: "As regras de Frontend Testing aplicam-se somente ao escopo e aos controles declarados neste standard."
---

# Frontend Testing Standard — @FrontendWeb / @UIIntegrator / @TestAutomator

> **Mandatory rules** for frontend testing. This standard complements all other frontend standards and defines unit testing (Vitest + React Testing Library), E2E testing (Playwright), mock patterns, and quality gates.

---

## 1. Dependencies

| Package | Version | Purpose |
|---|---|---|
| `vitest` | `^2.x` | Unit test runner (Vite-native, ESM-first) |
| `@testing-library/react` | `^16.x` | React component testing utilities |
| `@testing-library/jest-dom` | `^6.x` | Custom DOM matchers (`toBeInTheDocument`, etc.) |
| `@testing-library/user-event` | `^14.x` | Realistic user interaction simulation |
| `@playwright/test` | `^1.x` | End-to-end browser testing |
| `msw` | `^2.x` | API mocking for unit and integration tests |

```bash
pnpm add -D vitest @testing-library/react @testing-library/jest-dom @testing-library/user-event @playwright/test msw
```

---

## 2. Directory Structure

```
src/
├── components/
│   └── fiscal/
│       ├── FiscalQueryPage.tsx
│       └── __tests__/
│           └── FiscalQueryPage.test.tsx     # Unit tests co-located
├── hooks/
│   └── queries/
│       ├── useFiscalQueries.ts
│       └── __tests__/
│           └── useFiscalQueries.test.tsx
├── lib/
│   └── __tests__/
│       └── apiClient.test.ts
└── test/
    ├── setup.ts                # Vitest global setup
    ├── helpers/
    │   ├── renderWithProviders.tsx  # Test render helper
    │   └── mockAuth.ts             # Auth context mocks
    └── mocks/
        ├── handlers.ts             # MSW handlers (shared with dev)
        └── server.ts               # MSW server for tests

e2e/
├── fixtures/
│   └── auth.fixture.ts          # Playwright auth fixture
├── helpers/
│   └── auth.helper.ts           # Login helper functions
├── fiscal/
│   ├── query-list.spec.ts
│   └── query-create.spec.ts
├── auth/
│   └── login-flow.spec.ts
└── playwright.config.ts
```

### Rules

1. Unit tests go in `__tests__/` folders **co-located** with the source code.
2. E2E tests go in a top-level `e2e/` directory, organized by feature.
3. Test helpers and mocks go in `src/test/`.
4. **Never** put test files in `src/app/` (Next.js would try to route them).

---

## 3. Vitest Configuration

```tsx
// vitest.config.ts
import { defineConfig } from 'vitest/config';
import react from '@vitejs/plugin-react';
import path from 'path';

export default defineConfig({
  plugins: [react()],
  test: {
    environment: 'jsdom',
    globals: true,
    setupFiles: ['./src/test/setup.ts'],
    include: ['src/**/*.test.{ts,tsx}'],
    exclude: ['e2e/**'],
    coverage: {
      provider: 'v8',
      reporter: ['text', 'html', 'lcov'],
      include: ['src/components/**', 'src/hooks/**', 'src/lib/**', 'src/services/**'],
      exclude: ['**/__tests__/**', '**/*.d.ts', 'src/test/**'],
      thresholds: {
        branches: 70,
        functions: 70,
        lines: 70,
        statements: 70,
      },
    },
  },
  resolve: {
    alias: {
      '@': path.resolve(__dirname, './src'),
    },
  },
});
```

```tsx
// src/test/setup.ts
import '@testing-library/jest-dom/vitest';
import { cleanup } from '@testing-library/react';
import { afterEach, beforeAll, afterAll } from 'vitest';
import { server } from './mocks/server';

// MSW server for all tests
beforeAll(() => server.listen({ onUnhandledRequest: 'error' }));
afterEach(() => {
  cleanup();
  server.resetHandlers();
});
afterAll(() => server.close());
```

### Rules

1. **Environment:** `jsdom` for React component tests.
2. **Globals:** `true` — `describe`, `it`, `expect` available without imports.
3. **Coverage thresholds:** minimum 70% (branches, functions, lines, statements).
4. MSW server starts once, resets handlers between tests.
5. `cleanup()` runs after every test (prevents component state leakage).

---

## 4. Test Render Helper

```tsx
// src/test/helpers/renderWithProviders.tsx
import { render, type RenderOptions } from '@testing-library/react';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { AuthContext, type AuthContextValue } from '@/providers/AuthProvider';
import { type ReactElement } from 'react';

const defaultAuthValue: AuthContextValue = {
  isAuthenticated: true,
  isLoading: false,
  user: {
    id: 'user-1',
    username: 'test-user',
    email: 'test@example.com',
    tenantId: 'tenant-1',
    roles: ['TENANT_USER'],
    scopes: [],
  },
  token: 'mock-access-token',
  login: vi.fn(),
  logout: vi.fn(),
  hasRole: (role: string) => defaultAuthValue.user!.roles.includes(role),
  hasScope: (scope: string) => defaultAuthValue.user!.scopes.includes(scope),
};

interface CustomRenderOptions extends Omit<RenderOptions, 'wrapper'> {
  authOverrides?: Partial<AuthContextValue>;
  roles?: string[];
  scopes?: string[];
}

export function renderWithProviders(
  ui: ReactElement,
  options: CustomRenderOptions = {},
) {
  const { authOverrides, roles, scopes, ...renderOptions } = options;

  const authValue: AuthContextValue = {
    ...defaultAuthValue,
    ...authOverrides,
    user: {
      ...defaultAuthValue.user!,
      roles: roles ?? defaultAuthValue.user!.roles,
      scopes: scopes ?? defaultAuthValue.user!.scopes,
    },
    hasRole: (r: string) => (roles ?? defaultAuthValue.user!.roles).includes(r),
    hasScope: (s: string) => (scopes ?? defaultAuthValue.user!.scopes).includes(s),
  };

  const queryClient = new QueryClient({
    defaultOptions: {
      queries: { retry: false, gcTime: 0 },
      mutations: { retry: false },
    },
  });

  const Wrapper = ({ children }: { children: React.ReactNode }) => (
    <QueryClientProvider client={queryClient}>
      <AuthContext.Provider value={authValue}>
        {children}
      </AuthContext.Provider>
    </QueryClientProvider>
  );

  return {
    ...render(ui, { wrapper: Wrapper, ...renderOptions }),
    queryClient,
    authValue,
  };
}
```

### Rules

1. **Always** use `renderWithProviders()` instead of raw `render()`.
2. `retry: false` and `gcTime: 0` in tests — queries don't retry or cache between tests.
3. Override `roles` and `scopes` per test to verify RBAC behavior.
4. Each test gets a **fresh** `QueryClient` — no shared cache between tests.

---

## 5. MSW Mocks for Tests

```tsx
// src/test/mocks/server.ts
import { setupServer } from 'msw/node';
import { handlers } from './handlers';

export const server = setupServer(...handlers);
```

```tsx
// src/test/mocks/handlers.ts
import { http, HttpResponse } from 'msw';

export const handlers = [
  // Fiscal queries
  http.get('*/v1/fiscal/queries', () => {
    return HttpResponse.json({
      content: [
        { id: '1', documento: '12.345.678/0001-90', status: 'COMPLETED', createdAt: '2026-01-01T00:00:00Z' },
        { id: '2', documento: '98.765.432/0001-10', status: 'PENDING', createdAt: '2026-01-02T00:00:00Z' },
      ],
      page: 0, size: 10, totalElements: 2, totalPages: 1, first: true, last: true,
    });
  }),

  http.get('*/v1/fiscal/queries/:id', ({ params }) => {
    return HttpResponse.json({
      id: params.id, documento: '12.345.678/0001-90', status: 'COMPLETED', createdAt: '2026-01-01T00:00:00Z',
    });
  }),

  http.post('*/v1/fiscal/queries', async ({ request }) => {
    const body = await request.json() as Record<string, unknown>;
    return HttpResponse.json(
      { id: '3', ...body, status: 'PENDING', createdAt: new Date().toISOString() },
      { status: 201 },
    );
  }),
];
```

### Override Handlers Per Test

```tsx
import { server } from '@/test/mocks/server';
import { http, HttpResponse } from 'msw';

it('shows error state when API fails', async () => {
  // Override handler for this test only
  server.use(
    http.get('*/v1/fiscal/queries', () => {
      return HttpResponse.json({ message: 'Internal error' }, { status: 500 });
    }),
  );

  renderWithProviders(<FiscalQueryPage />);
  expect(await screen.findByText('Erro ao carregar consultas')).toBeInTheDocument();
});
```

### Rules

1. Default handlers return **success responses** — the happy path.
2. Override handlers per test for error scenarios using `server.use()`.
3. Handler URLs use `*/v1/...` glob to match regardless of base URL.
4. `server.resetHandlers()` runs after each test (in `setup.ts`) — overrides don't leak.

---

## 6. Unit Test Patterns

### Component Test

```tsx
// src/components/fiscal/__tests__/FiscalQueryPage.test.tsx
import { screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { renderWithProviders } from '@/test/helpers/renderWithProviders';
import { FiscalQueryPage } from '../FiscalQueryPage';
import { ROLES } from '@/lib/permissions';

describe('FiscalQueryPage', () => {
  it('renders fiscal query list', async () => {
    renderWithProviders(<FiscalQueryPage />, { roles: [ROLES.FISCAL_READER] });

    expect(await screen.findByText('12.345.678/0001-90')).toBeInTheDocument();
    expect(screen.getByText('98.765.432/0001-10')).toBeInTheDocument();
  });

  it('shows loading skeleton initially', () => {
    renderWithProviders(<FiscalQueryPage />, { roles: [ROLES.FISCAL_READER] });

    expect(screen.getByRole('status', { name: /carregando/i })).toBeInTheDocument();
  });

  it('shows empty state when no results', async () => {
    server.use(
      http.get('*/v1/fiscal/queries', () =>
        HttpResponse.json({ content: [], page: 0, size: 10, totalElements: 0, totalPages: 0, first: true, last: true }),
      ),
    );

    renderWithProviders(<FiscalQueryPage />, { roles: [ROLES.FISCAL_READER] });
    expect(await screen.findByText(/nenhuma consulta/i)).toBeInTheDocument();
  });
});
```

### Hook Test

```tsx
// src/hooks/queries/__tests__/useFiscalQueries.test.tsx
import { renderHook, waitFor } from '@testing-library/react';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { useFiscalQueryList } from '../useFiscalQueries';

const createWrapper = () => {
  const queryClient = new QueryClient({ defaultOptions: { queries: { retry: false } } });
  return ({ children }: { children: React.ReactNode }) => (
    <QueryClientProvider client={queryClient}>{children}</QueryClientProvider>
  );
};

describe('useFiscalQueryList', () => {
  it('returns fiscal queries', async () => {
    const { result } = renderHook(() => useFiscalQueryList(), { wrapper: createWrapper() });

    await waitFor(() => expect(result.current.isSuccess).toBe(true));
    expect(result.current.data?.content).toHaveLength(2);
  });
});
```

### Rules

1. **Test user behavior**, not implementation. Use `screen.getByRole`, `getByText`, `getByLabelText`.
2. **Never** test internal state (`useState` values). Test what the user sees.
3. Use `userEvent` for interactions (click, type), not `fireEvent`.
4. Use `waitFor` or `findBy*` for async content.
5. Each test must be **independent** — no shared state between tests.

---

## 7. RBAC Test Patterns

```tsx
describe('PermissionGate behavior', () => {
  it('shows delete button for FISCAL_ADMIN', async () => {
    renderWithProviders(<FiscalQueryPage />, { roles: [ROLES.FISCAL_ADMIN] });

    expect(await screen.findByTestId('delete-button')).toBeInTheDocument();
  });

  it('hides delete button for FISCAL_READER', async () => {
    renderWithProviders(<FiscalQueryPage />, { roles: [ROLES.FISCAL_READER] });

    await screen.findByText('12.345.678/0001-90'); // Wait for data
    expect(screen.queryByTestId('delete-button')).not.toBeInTheDocument();
  });

  it('shows forbidden page for unauthorized user', () => {
    renderWithProviders(<FiscalQueryPage />, { roles: [ROLES.TENANT_USER] });

    expect(screen.getByText(/acesso negado/i)).toBeInTheDocument();
  });
});
```

### Rules

1. **Every** `PermissionGate` and `ProtectedRoute` usage **must** have tests for both granted and denied.
2. Test with the **minimum required role** and with an **insufficient role**.
3. Use `data-testid` on elements guarded by permissions (for reliable E2E selection).

---

## 8. Playwright E2E Configuration

```tsx
// e2e/playwright.config.ts
import { defineConfig, devices } from '@playwright/test';

export default defineConfig({
  testDir: '.',
  timeout: 30_000,
  retries: process.env.CI ? 2 : 0,
  workers: process.env.CI ? 1 : undefined,
  reporter: [['html', { open: 'never' }], ['list']],

  use: {
    baseURL: 'http://localhost:3000',
    trace: 'on-first-retry',
    screenshot: 'only-on-failure',
  },

  projects: [
    { name: 'chromium', use: { ...devices['Desktop Chrome'] } },
    { name: 'mobile', use: { ...devices['Pixel 5'] } },
  ],

  webServer: {
    command: 'pnpm run dev',
    port: 3000,
    reuseExistingServer: !process.env.CI,
  },
});
```

---

## 9. Playwright Auth Helper

```tsx
// e2e/helpers/auth.helper.ts
import { type Page } from '@playwright/test';

const TEST_USERS = {
  'fiscal-reader': { username: 'fiscal.reader@test.com', password: 'test1234' },
  'fiscal-admin': { username: 'fiscal.admin@test.com', password: 'test1234' },
  'tenant-admin': { username: 'tenant.admin@test.com', password: 'test1234' },
  'tenant-user': { username: 'tenant.user@test.com', password: 'test1234' },
} as const;

type TestUserRole = keyof typeof TEST_USERS;

export async function loginAs(page: Page, role: TestUserRole) {
  const user = TEST_USERS[role];

  await page.goto('/');
  // Keycloak redirects to login page
  await page.waitForURL(/.*\/realms\/saas\/protocol\/openid-connect\/auth.*/);

  await page.fill('#username', user.username);
  await page.fill('#password', user.password);
  await page.click('#kc-login');

  // Wait for redirect back to app
  await page.waitForURL('http://localhost:3000/**');
}
```

---

## 10. E2E Test Patterns

```tsx
// e2e/fiscal/query-list.spec.ts
import { test, expect } from '@playwright/test';
import { loginAs } from '../helpers/auth.helper';

test.describe('Fiscal Query List', () => {
  test('FISCAL_READER can view query list', async ({ page }) => {
    await loginAs(page, 'fiscal-reader');
    await page.goto('/query');

    await expect(page.getByRole('heading', { name: 'Consulta Fiscal' })).toBeVisible();
    await expect(page.getByRole('table')).toBeVisible();
  });

  test('FISCAL_READER cannot see delete button', async ({ page }) => {
    await loginAs(page, 'fiscal-reader');
    await page.goto('/query');

    await expect(page.getByRole('table')).toBeVisible();
    await expect(page.getByTestId('delete-button')).not.toBeVisible();
  });

  test('FISCAL_ADMIN can see delete button', async ({ page }) => {
    await loginAs(page, 'fiscal-admin');
    await page.goto('/query');

    await expect(page.getByTestId('delete-button').first()).toBeVisible();
  });

  test('TENANT_USER is redirected to forbidden page', async ({ page }) => {
    await loginAs(page, 'tenant-user');
    await page.goto('/query');

    await expect(page.getByText('Acesso Negado')).toBeVisible();
  });
});
```

```tsx
// e2e/auth/login-flow.spec.ts
import { test, expect } from '@playwright/test';

test.describe('Authentication Flow', () => {
  test('unauthenticated user is redirected to Keycloak', async ({ page }) => {
    await page.goto('/dashboard');
    await expect(page).toHaveURL(/.*\/realms\/saas\/protocol\/openid-connect\/auth.*/);
  });

  test('user can login and see dashboard', async ({ page }) => {
    await page.goto('/');
    await page.waitForURL(/.*\/realms\/saas.*/);

    await page.fill('#username', 'tenant.admin@test.com');
    await page.fill('#password', 'test1234');
    await page.click('#kc-login');

    await page.waitForURL('http://localhost:3000/**');
    await expect(page.getByRole('heading', { name: /dashboard/i })).toBeVisible();
  });
});
```

### Rules

1. E2E tests authenticate against a **real local Keycloak** (Docker Compose).
2. Test users per role must be pre-seeded in Keycloak realm config.
3. Use `data-testid` for permission-guarded elements.
4. Use `getByRole`, `getByText`, `getByLabel` before `getByTestId`.
5. Mobile viewport tested via `Pixel 5` project.

---

## 11. NPM Scripts

```json
{
  "scripts": {
    "test": "vitest run",
    "test:watch": "vitest",
    "test:coverage": "vitest run --coverage",
    "test:e2e": "playwright test --config=e2e/playwright.config.ts",
    "test:e2e:ui": "playwright test --config=e2e/playwright.config.ts --ui"
  }
}
```

---

## 12. Quality Gates

| Gate | Tool | Threshold |
|---|---|---|
| Unit test pass rate | Vitest | 100% (all tests pass) |
| Code coverage | Vitest v8 | ≥ 70% lines/branches/functions |
| E2E critical paths | Playwright | 100% pass on Chromium |
| E2E mobile | Playwright | 100% pass on Pixel 5 viewport |

### What to Test (Priority)

| Priority | What | How |
|---|---|---|
| 🔴 Must | Auth flow (login, logout, token refresh) | E2E |
| 🔴 Must | RBAC guards (ProtectedRoute, PermissionGate) | Unit + E2E |
| 🔴 Must | Form submissions with validation | Unit |
| 🟠 Should | Data listing with loading/error/empty states | Unit |
| 🟠 Should | Pagination and filtering | Unit |
| 🟡 Nice | UI interactions (hover, tooltips, animations) | E2E |
| 🟡 Nice | Responsive layouts | E2E (mobile project) |

### Rules

1. **No PR merged** without passing unit tests and coverage threshold.
2. E2E tests run before **every release**, not on every PR (too slow).
3. RBAC tests are **security-critical** — treated as high priority.
4. Coverage threshold may be raised to 80% as codebase matures.

Os 70% desta seção pertencem ao pacote `frontend`; não redefinem backend nem
`website`. A configuração executável do Vitest é a evidência do limiar. Configuração
ausente ou inferior ao standard resulta em `BLOCKED` ou `FAIL`, conforme o
[Software Quality Standard](software-quality-standard.md).

## 13. Change log

| Versão | Data | Mudança |
| --- | --- | --- |
| 1.5 | 2026-09-08 | Delimita o limiar ao frontend e liga Test Gate e Quality Gate ao standard transversal. |
