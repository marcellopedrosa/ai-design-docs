---
document_id: "FRONTEND-STANDARD"
primary_nature: "Regra"
objective: "Definir regras reutilizáveis e verificáveis para Frontend."
scope: "Organização, convenções e requisitos transversais da aplicação frontend."
non_objectives: "Não criar requisitos de produto, decisões arquiteturais concretas ou procedimentos fora do escopo deste standard."
owner: "Arquitetura e Qualidade"
status: "Active"
date: "2026-08-25"
version: "1.4"
keywords: "frontend, standard, standard"
related_files: "./README.md, ../FrontendWeb.md"
code_references: "frontend/src/services/, /api/v1/fiscal/situacao/${documento}, /api/v1/fiscal/consultas?page=${page}&size=${size}, frontend/src/components/shared/DocumentoInput.tsx, frontend/"
principal_statement: "As regras de Frontend aplicam-se somente ao escopo e aos controles declarados neste standard."
---

# Frontend Standard — @FrontendWeb

> **Mandatory rules** that @FrontendWeb must follow in every implementation. Referenced from the agent specification `../FrontendWeb.md`.

> **Version:** 1.1 — **Last updated:** 2026-08-22. Tenant context follows the signed-claim and
> explicit Super Admin impersonation contract in ADR-0013.

---

## 1. Framework & Project Structure

- **Framework:** Next.js 14+ with App Router, React 18+, TypeScript in strict mode.
- **Package Manager:** pnpm (preferred) or npm. No yarn.
- **Node:** 20 LTS.

### Directory Structure

```
src/
├── app/                    # Next.js App Router (pages, layouts, routes)
│   ├── (auth)/             # Route group: authenticated pages
│   ├── (public)/           # Route group: public pages (login, register)
│   ├── layout.tsx          # Root layout with providers
│   └── globals.css         # Tailwind directives + CSS custom properties
├── components/
│   ├── ui/                 # Primitive UI components (Button, Input, Badge, Modal)
│   ├── forms/              # Form components (FormField, FormSelect, MaskedInput)
│   ├── layout/             # Layout components (Sidebar, TopBar, AppShell)
│   └── [feature]/          # Feature-specific components (e.g., fiscal/, clients/)
├── hooks/                  # Custom hooks (useAuth, useTenant, useFetch, useForm)
├── services/               # API service modules (centralized HTTP calls)
├── types/                  # Shared TypeScript interfaces and types
├── assets/                 # Static assets (icons, images, fonts)
├── lib/                    # Utility functions, formatters, masks, constants
└── providers/              # React Context providers (AuthProvider, TenantProvider)
```

### Naming Rules

| Item | Convention | Example |
|---|---|---|
| Component files | PascalCase | `ClientCard.tsx` |
| Hook files | camelCase | `useAuth.ts` |
| Service files | camelCase | `fiscalService.ts` |
| Type files | camelCase | `fiscal.types.ts` |
| Utility files | camelCase | `formatCnpj.ts` |
| CSS modules | camelCase | `sidebar.module.css` |
| Directories | kebab-case or camelCase | `fiscal/`, `ui/` |

---

## 2. Tailwind CSS Patterns

### Rules

1. **Use design tokens only.** Never use arbitrary values like `bg-[#1E40AF]`. Always use the token classes defined by @WebDesigner's `tailwind.config.js`.
2. **Mobile-first responsive.** Use ascending breakpoints: `sm:`, `md:`, `lg:`, `xl:`.
3. **Dark mode.** Use the `dark:` variant. Never hardcode light-only colors.
4. **Class ordering convention (recommended order):**
   - Layout (`flex`, `grid`, `block`, `hidden`)
   - Sizing (`w-`, `h-`, `min-w-`, `max-w-`)
   - Spacing (`p-`, `m-`, `gap-`)
   - Typography (`text-`, `font-`, `leading-`, `tracking-`)
   - Colors (`bg-`, `text-`, `border-`)
   - Effects (`shadow-`, `rounded-`, `opacity-`)
   - States (`hover:`, `focus:`, `active:`, `disabled:`)
   - Responsive (`sm:`, `md:`, `lg:`)
5. **No `@apply` in components.** Keep utility classes in JSX. Use `@apply` only in `globals.css` for base element styles.
6. **Extract repeated patterns** into reusable components, not into CSS classes.

### Example

```tsx
// ✅ CORRECT
<button className="flex items-center gap-2 px-4 py-2 text-sm font-medium text-white bg-primary rounded-lg shadow-sm hover:bg-primary-dark focus:ring-2 focus:ring-primary/50 disabled:opacity-50">

// ❌ WRONG — arbitrary values
<button className="bg-[#1E40AF] text-[14px] p-[10px] rounded-[8px]">
```

---

## 3. Component Patterns

### Rules

1. **Functional components only.** No class components.
2. **Named exports.** No default exports (except Next.js pages).
3. **Props typed with `interface`.** Prefix with component name.
4. **Destructure props** in the function signature.
5. **Forward ref** for primitive UI components (Button, Input).
6. **Compound components** for complex UI (Tabs, Dropdown, DataTable).
7. **All visual states must be handled:** default, loading, error, empty, disabled.

### Example

```tsx
// ✅ CORRECT
interface ClientCardProps {
  client: Client;
  onEdit: (id: string) => void;
  isLoading?: boolean;
}

export const ClientCard = ({ client, onEdit, isLoading }: ClientCardProps) => {
  if (isLoading) return <ClientCardSkeleton />;

  return (
    <div className="flex flex-col gap-4 p-6 bg-white rounded-xl shadow-sm border border-neutral-200">
      <h3 className="text-lg font-semibold text-neutral-900">{client.name}</h3>
      {/* ... */}
    </div>
  );
};
```

---

## 4. Custom Hooks

### Rules

1. **Naming:** Always prefix with `use` (e.g., `useAuth`, `useFetch`).
2. **Single responsibility.** One hook = one concern.
3. **Return typed objects**, not arrays (except simple state hooks).
4. **Never call hooks conditionally.** Follow Rules of Hooks.

### Standard Hooks

| Hook | Purpose | Location |
|---|---|---|
| `useAuth` | Auth state, login/logout, user identity | `hooks/useAuth.ts` |
| `useTenant` | Tenant ID, tenant context | `hooks/useTenant.ts` |
| `useFetch<T>` | Data fetching with loading/error state | `hooks/useFetch.ts` |
| `useDebounce` | Debounced value for search inputs | `hooks/useDebounce.ts` |
| `usePagination` | Page/size state, total pages handling | `hooks/usePagination.ts` |
| `useMediaQuery` | Responsive breakpoint detection | `hooks/useMediaQuery.ts` |

### Example

```tsx
export const useFetch = <T>(fetcher: () => Promise<T>) => {
  const [data, setData] = useState<T | null>(null);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<Error | null>(null);

  useEffect(() => {
    setIsLoading(true);
    fetcher()
      .then(setData)
      .catch(setError)
      .finally(() => setIsLoading(false));
  }, [fetcher]);

  return { data, isLoading, error };
};
```

---

## 5. API Calls

### Rules

1. **All API calls live in `src/services/`.** Components never call `fetch()` directly.
2. **Typed request and response.** Every service function has typed parameters and return type.
3. **Tenant context** resolved centrally: tenant identity uses the signed `tenant_id` claim with
   no header; Super Admin global has no tenant/header; only explicit Super Admin impersonation
   injects `X-Tenant-ID`.
4. **`Authorization: Bearer` header** injected automatically from `AuthContext`.
5. **Centralized error handling.** Use an `apiClient` wrapper with interceptors.
6. **Loading, error, and empty states** are always handled in the consuming component.

### HTTP Client Pattern

```tsx
// src/lib/apiClient.ts
const apiClient = {
  async get<T>(url: string): Promise<T> {
    const response = await fetch(url, {
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${getAccessToken()}`,
        ...getImpersonationHeaders(), // empty except for explicit Super Admin impersonation
      },
    });
    if (!response.ok) throw new ApiError(response.status, await response.text());
    return response.json();
  },
  // post, put, delete follow the same pattern
};
```

### Service Pattern

```tsx
// src/services/fiscalService.ts
import { apiClient } from '@/lib/apiClient';
import type { SituacaoFiscalResult, ConsultaFiscalPage } from '@/types/fiscal.types';

export const fiscalService = {
  getSituacao: (documento: string) =>
    apiClient.get<SituacaoFiscalResult>(`/api/v1/fiscal/situacao/${documento}`),

  getConsultas: (page: number, size: number) =>
    apiClient.get<ConsultaFiscalPage>(`/api/v1/fiscal/consultas?page=${page}&size=${size}`),
};
```

---

## 6. Forms — React Hook Form + Zod

### Rules

1. **Form library:** React Hook Form (`useForm`) for all forms.
2. **Validation:** Zod schemas. Never inline validation logic.
3. **Error messages:** Displayed below the field with `role="alert"` and `aria-describedby`.
4. **Required indicator:** Asterisk `*` next to the label.
5. **Submit button:** Disabled during submission, shows spinner.
6. **Success feedback:** Toast notification after successful submission.

### Validation Schema Example

```tsx
import { z } from 'zod';

export const clientSchema = z.object({
  name: z.string().min(3, 'Name must have at least 3 characters'),
  documento: z.string().regex(/^\d{2}\.\d{3}\.\d{3}\/\d{4}-\d{2}$/, 'Invalid Documento'),
  email: z.string().email('Invalid email'),
  phone: z.string().regex(/^\(\d{2}\)\s\d{4,5}-\d{4}$/, 'Invalid phone'),
});

export type ClientFormData = z.infer<typeof clientSchema>;
```

### Form Component Pattern

```tsx
import { useForm } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';

export const ClientForm = ({ onSubmit }: ClientFormProps) => {
  const { register, handleSubmit, formState: { errors, isSubmitting } } = useForm<ClientFormData>({
    resolver: zodResolver(clientSchema),
  });

  return (
    <form onSubmit={handleSubmit(onSubmit)} noValidate>
      <div>
        <label htmlFor="name">Name *</label>
        <input id="name" {...register('name')} aria-describedby="name-error" />
        {errors.name && (
          <span id="name-error" role="alert" className="text-sm text-error">
            {errors.name.message}
          </span>
        )}
      </div>
      <button type="submit" disabled={isSubmitting}>
        {isSubmitting ? <Spinner /> : 'Save'}
      </button>
    </form>
  );
};
```

---

## 7. Field Masks

### Supported Masks

| Field | Mask | Format |
|---|---|---|
| Documento | `XX.XXX.XXX/XXXX-XX` | 14 digits |
| CPF | `XXX.XXX.XXX-XX` | 11 digits |
| Phone (mobile) | `(XX) XXXXX-XXXX` | 11 digits |
| Phone (landline) | `(XX) XXXX-XXXX` | 10 digits |
| CEP | `XXXXX-XXX` | 8 digits |
| Currency (BRL) | `R$ X.XXX,XX` | Decimal, 2 places |

### Rules

1. Masks are applied **on input** (progressive masking as user types).
2. Store the **raw value** (digits only) in form state; display the **masked value**.
3. Use a shared `MaskedInput` component in `src/components/forms/MaskedInput.tsx`.
4. Validation runs on the **masked format** (Zod regex) for user clarity.

---

## 8. Tab Navigation Pattern

### Rules

1. Use a `Tabs` compound component (`Tabs`, `TabList`, `Tab`, `TabPanel`).
2. **ARIA attributes required:** `role="tablist"`, `role="tab"`, `role="tabpanel"`, `aria-selected`, `aria-controls`, `aria-labelledby`.
3. **Keyboard navigation:** Arrow keys to move between tabs, Enter/Space to activate.
4. **Controlled state:** Active tab managed via `useState` or URL search params.
5. **Visual active state:** Bottom border in primary color, bold text.

### Example

```tsx
<Tabs defaultValue="general">
  <TabList>
    <Tab value="general">General</Tab>
    <Tab value="fiscal">Fiscal</Tab>
    <Tab value="documents">Documents</Tab>
  </TabList>
  <TabPanel value="general">
    {/* General content */}
  </TabPanel>
  <TabPanel value="fiscal">
    {/* Fiscal content */}
  </TabPanel>
</Tabs>
```

---

## 9. State Management

### Rules

1. **Local state first.** Use `useState` / `useReducer` for component state.
2. **Context for cross-cutting only:** `AuthContext`, `TenantContext`, `ThemeContext`.
3. **No Redux/Zustand** unless escalated and approved by @AgentOrchestrator.
4. **Server state:** Use React Query or SWR for API data caching and synchronization.
5. **URL state:** Use URL search params for filter/pagination state (shareable links).

---

## 10. Accessibility (WCAG 2.1 AA)

### Rules

1. Every `<input>` must have a `<label>` with `htmlFor`.
2. Every interactive element must be keyboard-accessible.
3. Every image must have `alt` text.
4. Color contrast: 4.5:1 minimum for normal text, 3:1 for large text.
5. Focus ring visible on all interactive elements (`focus:ring-2 focus:ring-primary/50`).
6. `data-testid` on all interactive elements for E2E tests.
7. `aria-describedby` on fields with helper text or error messages.

---

## 11. Loading, Error & Empty States

Every data-driven component **must** implement:

| State | Pattern |
|---|---|
| **Loading** | Skeleton screen or spinner with `aria-busy="true"` |
| **Error** | Error message + retry button. Never expose stack traces |
| **Empty** | Friendly message + illustration or call-to-action |

---

## 12. i18n

- Primary language: **pt-BR**.
- All user-facing strings go through an i18n system (e.g., `next-intl`).
- Date format: `dd/MM/yyyy`.
- Number format: `1.234,56` (dot for thousands, comma for decimals).
- Currency: `R$ 1.234,56`.
