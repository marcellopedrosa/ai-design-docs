---
document_id: "A11Y-STANDARD"
primary_nature: "Regra"
objective: "Definir regras reutilizáveis e verificáveis para Accessibility (a11y)."
scope: "Acessibilidade de interfaces, navegação por teclado, semântica e verificação WCAG."
non_objectives: "Não criar requisitos de produto, decisões arquiteturais concretas ou procedimentos fora do escopo deste standard."
owner: "Arquitetura e Qualidade"
status: "Active"
date: "2026-08-25"
version: "1.4"
keywords: "a11y, standard, standard"
related_files: "./README.md, ./component-design-standard.md, ./i18n-standard.md"
code_references: "frontend/"
principal_statement: "As regras de Accessibility (a11y) aplicam-se somente ao escopo e aos controles declarados neste standard."
---

# Accessibility (a11y) Standard — @FrontendWeb / @WebDesigner / @UIIntegrator

> **Mandatory rules** for WCAG 2.1 AA accessibility compliance. This standard defines ARIA patterns, keyboard navigation, screen reader support, focus management, color contrast requirements, semantic HTML, and accessibility testing.

> **Prerequisite:** Read [`component-design-standard.md`](./component-design-standard.md) (component ARIA table) and [`i18n-standard.md`](./i18n-standard.md) (translatable accessible labels).

---

## 1. Target Compliance

| Standard | Level | Status |
|---|---|---|
| WCAG 2.1 | **AA** | Required |
| WCAG 2.1 | AAA | Optional (recommended for critical flows) |
| WAI-ARIA 1.2 | Full | Required for interactive components |

### Why AA (Not AAA)

- AA is the legal standard in most jurisdictions (including Lei Brasileira de Inclusão).
- AAA is aspirational — some criteria conflict with visual design goals.
- Critical flows (login, billing, error pages) **should** aim for AAA where feasible.

---

## 2. Semantic HTML

### Rules

1. **One `<h1>` per page.** Heading hierarchy: `h1` → `h2` → `h3`. Never skip levels.
2. Use `<main>` for primary content, `<nav>` for navigation, `<aside>` for sidebar, `<footer>` for footer.
3. Use `<button>` for actions, `<a>` for navigation. **Never** `<div onClick>`.
4. Use `<ul>`/`<ol>` for lists. **Never** divs with bullet point characters.
5. Use `<table>` with `<thead>`, `<th scope="col">` for data tables. **Never** grid divs for tabular data.
6. Use `<form>` with `<label>` for forms. Every input **must** have an associated `<label>`.
7. Use `<time datetime="...">` for dates.

### Component Mapping

| Intent | Element | NOT |
|---|---|---|
| Navigate to page | `<a href>` / `<Link>` | `<span onClick>` |
| Trigger action | `<button>` | `<div onClick>` |
| Display data | `<table>` | `<div class="grid">` |
| Group form fields | `<fieldset>` + `<legend>` | `<div>` |
| Show/hide content | `<details>` + `<summary>` | Custom accordion (unless Radix) |
| Primary content | `<main>` | `<div id="content">` |
| Navigation | `<nav aria-label="...">` | `<div class="nav">` |

---

## 3. ARIA Patterns by Component

### Interactive Components

| Component | Role | Required ARIA | States |
|---|---|---|---|
| **Button** | `button` (implicit) | `aria-disabled`, `aria-busy` (loading) | — |
| **Link** | `link` (implicit) | — | — |
| **Input** | `textbox` (implicit) | `aria-invalid`, `aria-describedby`, `aria-required` | — |
| **Select** | `combobox` | `aria-expanded`, `aria-activedescendant` | — |
| **Checkbox** | `checkbox` (implicit) | `aria-checked` (implicit) | — |
| **Switch/Toggle** | `switch` | `aria-checked` | — |

### Composite Components

| Component | Container Role | Item Role | Key ARIA |
|---|---|---|---|
| **Modal/Dialog** | `dialog` | — | `aria-modal="true"`, `aria-labelledby`, `aria-describedby` |
| **Dropdown Menu** | `menu` | `menuitem` | `aria-expanded`, `aria-haspopup` |
| **Tabs** | `tablist` | `tab` + `tabpanel` | `aria-selected`, `aria-controls` |
| **Accordion** | — | — | `aria-expanded`, `aria-controls` |
| **Toast** | `status` | — | `aria-live="polite"` |
| **Alert** | `alert` | — | `aria-live="assertive"` |
| **DataTable** | `table` | `row`, `cell` | `aria-sort`, `aria-label` |
| **Sidebar Nav** | `navigation` | — | `aria-label="Menu principal"`, `aria-current="page"` |
| **Breadcrumb** | `navigation` | — | `aria-label="Breadcrumb"`, `aria-current="page"` |
| **FileDropZone** | `button` | — | `aria-label`, `aria-describedby`, `aria-disabled` |
| **Pagination** | `navigation` | — | `aria-label="Paginação"`, `aria-current="page"` |

### Implementation

```tsx
// ✅ CORRECT — Modal with full ARIA
<div
  role="dialog"
  aria-modal="true"
  aria-labelledby="modal-title"
  aria-describedby="modal-description"
>
  <h2 id="modal-title">Confirmar Exclusão</h2>
  <p id="modal-description">Tem certeza que deseja excluir?</p>
</div>

// ✅ CORRECT — Sidebar navigation
<nav aria-label="Menu principal">
  <ul>
    <li><a href="/dashboard" aria-current="page">Dashboard</a></li>
    <li><a href="/fiscal">Fiscal</a></li>
  </ul>
</nav>

// ✅ CORRECT — Loading button
<button aria-busy={isLoading} disabled={isLoading}>
  {isLoading ? 'Salvando...' : 'Salvar'}
</button>
```

### Rules

1. **Use Radix UI** for Modal, Dropdown, Tabs, Accordion — they handle all ARIA automatically.
2. When ARIA role is implicit from the HTML element, do **not** add redundant `role` attributes.
3. Every `aria-labelledby` and `aria-describedby` **must** reference a valid `id`.
4. `aria-live="polite"` for non-urgent updates (toasts). `aria-live="assertive"` for errors.

---

## 4. Keyboard Navigation

### Global Shortcuts

| Key | Action | Context |
|---|---|---|
| `Tab` | Move focus forward | Everywhere |
| `Shift + Tab` | Move focus backward | Everywhere |
| `Enter` / `Space` | Activate button/link | Focused interactive element |
| `Escape` | Close modal/dropdown/popover | Open overlay |
| `Arrow keys` | Navigate within tabs/menus/lists | Composite widgets |

### Focus Order

```
Topbar (logo, user menu)
  ↓
Sidebar Navigation (menu items)
  ↓
Main Content (page heading, actions, data)
  ↓
Footer (if any)
```

### Skip Link

```tsx
// src/app/layout.tsx — First element in body
<a
  href="#main-content"
  className="sr-only focus:not-sr-only focus:absolute focus:top-4 focus:left-4 focus:z-50 focus:px-4 focus:py-2 focus:bg-background focus:text-foreground focus:rounded-lg focus:shadow-lg"
>
  Pular para o conteúdo principal
</a>

// In the main content area:
<main id="main-content" tabIndex={-1}>
  {children}
</main>
```

### Rules

1. **Every** interactive element must be reachable via `Tab`.
2. **Skip link** is mandatory — first focusable element in the DOM.
3. `tabIndex="0"` to make non-interactive elements focusable (use sparingly).
4. `tabIndex="-1"` for programmatic focus (e.g., `main` after skip link click).
5. **Never** use `tabIndex > 0` — it breaks natural tab order.
6. `Escape` **must** close any overlay (modal, dropdown, popover).

---

## 5. Focus Management

### Focus Trap — Modals

```tsx
// Use @radix-ui/react-dialog — automatic focus trap
// Manual alternative:
import { useEffect, useRef } from 'react';

export const useFocusTrap = (isActive: boolean) => {
  const containerRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    if (!isActive || !containerRef.current) return;

    const container = containerRef.current;
    const focusableElements = container.querySelectorAll<HTMLElement>(
      'a[href], button:not([disabled]), input:not([disabled]), select:not([disabled]), textarea:not([disabled]), [tabindex]:not([tabindex="-1"])',
    );

    const firstElement = focusableElements[0];
    const lastElement = focusableElements[focusableElements.length - 1];

    // Focus first element on open
    firstElement?.focus();

    const handleKeyDown = (e: KeyboardEvent) => {
      if (e.key !== 'Tab') return;

      if (e.shiftKey && document.activeElement === firstElement) {
        e.preventDefault();
        lastElement?.focus();
      } else if (!e.shiftKey && document.activeElement === lastElement) {
        e.preventDefault();
        firstElement?.focus();
      }
    };

    container.addEventListener('keydown', handleKeyDown);
    return () => container.removeEventListener('keydown', handleKeyDown);
  }, [isActive]);

  return containerRef;
};
```

### Focus Restore — After Modal Close

```tsx
const triggerRef = useRef<HTMLButtonElement>(null);

const handleClose = () => {
  setIsOpen(false);
  // Restore focus to the button that opened the modal
  triggerRef.current?.focus();
};

<button ref={triggerRef} onClick={() => setIsOpen(true)}>
  Abrir modal
</button>
```

### Rules

1. **Modals must trap focus** — Tab cycles within the modal only.
2. **On open:** focus the first focusable element (or the close button).
3. **On close:** restore focus to the element that triggered the open.
4. Use `@radix-ui/react-dialog` whenever possible (handles all of this).

---

## 6. Color & Contrast

### Minimum Contrast Ratios (WCAG 2.1 AA)

| Element | Ratio | Example |
|---|---|---|
| Normal text (< 18px) | **4.5:1** | Body text, labels, table cells |
| Large text (≥ 18px or ≥ 14px bold) | **3:1** | Headings, large buttons |
| UI components & graphics | **3:1** | Icons, borders, focus rings |
| Decorative elements | No requirement | Background patterns, dividers |

### Color Rules

1. **Never** convey meaning through color alone. Always pair with text, icon, or pattern.
   ```tsx
   // ✅ CORRECT — Color + text
   <Badge variant="error"><AlertCircle /> Erro</Badge>

   // ❌ WRONG — Color only
   <span className="text-red-500">●</span>
   ```

2. **Status indicators** must have both color and label:
   ```tsx
   // ✅ CORRECT
   <span className="text-green-600">✓ Concluído</span>

   // ❌ WRONG — relies on color
   <span className="text-green-600">●</span>
   ```

3. **Form errors** must be announced and visible:
   ```tsx
   <input aria-invalid="true" aria-describedby="email-error" />
   <p id="email-error" role="alert" className="text-destructive">
     Email inválido
   </p>
   ```

### Dark Mode Contrast

1. Test contrast ratios in **both** light and dark themes.
2. Use CSS custom properties for colors — ensure dark mode variants meet AA.
3. `text-muted-foreground` must meet 4.5:1 against `bg-background` in both modes.

---

## 7. Screen Reader Support

### Live Regions

```tsx
// Toast notifications — polite (non-interrupting)
<div role="status" aria-live="polite">
  {notification.message}
</div>

// Form error — assertive (interrupts immediately)
<div role="alert" aria-live="assertive">
  {validationError}
</div>

// Loading state — polite
<div role="status" aria-live="polite" aria-busy={isLoading}>
  {isLoading ? 'Carregando...' : 'Dados carregados'}
</div>
```

### Visually Hidden Text (sr-only)

```tsx
// When an icon-only button needs a label
<button aria-label="Excluir consulta">
  <Trash2 className="h-4 w-4" aria-hidden="true" />
</button>

// Or use sr-only class
<button>
  <Trash2 className="h-4 w-4" aria-hidden="true" />
  <span className="sr-only">Excluir consulta</span>
</button>
```

### Tailwind sr-only Class

```css
/* Already built into Tailwind */
.sr-only {
  position: absolute;
  width: 1px;
  height: 1px;
  padding: 0;
  margin: -1px;
  overflow: hidden;
  clip: rect(0, 0, 0, 0);
  white-space: nowrap;
  border-width: 0;
}
```

### Rules

1. **Every** icon-only button must have `aria-label` or `sr-only` text.
2. Decorative icons use `aria-hidden="true"`.
3. Loading states announce via `aria-live="polite"` + `aria-busy`.
4. Error messages use `role="alert"` for immediate screen reader announcement.
5. **Never** use `title` attribute as the only accessible label.

---

## 8. Forms Accessibility

```tsx
// ✅ CORRECT — Fully accessible form
<form onSubmit={handleSubmit} aria-label="Criar consulta fiscal">
  <fieldset>
    <legend className="sr-only">Dados da consulta</legend>

    <label htmlFor="documento">
      Documento <span aria-hidden="true">*</span>
      <span className="sr-only">(obrigatório)</span>
    </label>
    <input
      id="documento"
      type="text"
      required
      aria-required="true"
      aria-invalid={!!errors.documento}
      aria-describedby={errors.documento ? 'documento-error' : 'documento-hint'}
      {...register('documento')}
    />
    {errors.documento ? (
      <p id="documento-error" role="alert">{errors.documento.message}</p>
    ) : (
      <p id="documento-hint">Formato: 00.000.000/0001-00</p>
    )}
  </fieldset>

  <button type="submit" aria-busy={isSubmitting} disabled={isSubmitting}>
    {isSubmitting ? 'Criando...' : 'Criar Consulta'}
  </button>
</form>
```

### Rules

1. Every `<input>` must have an associated `<label htmlFor="id">`.
2. Required fields use `aria-required="true"` (not just the `*` visual indicator).
3. Error messages linked via `aria-describedby` + `role="alert"`.
4. Submit button has `aria-busy` during submission.
5. `<fieldset>` + `<legend>` for logically grouped fields.

---

## 9. Images & Media

```tsx
// Informative image — describe the content
<Image src="/chart.png" alt="Gráfico mostrando 87% de compliance fiscal" />

// Decorative image — empty alt
<Image src="/pattern.svg" alt="" aria-hidden="true" />

// Icon — hidden from screen readers when paired with text
<button>
  <Search className="h-4 w-4" aria-hidden="true" />
  Buscar
</button>
```

### Rules

1. **Informative images** must have descriptive `alt` text.
2. **Decorative images** use `alt=""` and `aria-hidden="true"`.
3. **Icons paired with text** use `aria-hidden="true"` on the icon.
4. `next/image` supports `alt` natively — always provide it.

---

## 10. Data Tables

```tsx
<table aria-label="Consultas fiscais">
  <thead>
    <tr>
      <th scope="col">Documento</th>
      <th scope="col" aria-sort={sortDirection}>
        <button onClick={toggleSort}>
          Data
          <span className="sr-only">
            {sortDirection === 'ascending' ? ', ordenado crescente' : ', ordenado decrescente'}
          </span>
        </button>
      </th>
      <th scope="col">Status</th>
      <th scope="col">
        <span className="sr-only">Ações</span>
      </th>
    </tr>
  </thead>
  <tbody>
    {data.map((row) => (
      <tr key={row.id}>
        <td>{formatDocumento(row.documento)}</td>
        <td><DateDisplay date={row.createdAt} /></td>
        <td><FiscalStatusBadge status={row.status} /></td>
        <td>
          <button aria-label={`Excluir consulta ${row.documento}`}>
            <Trash2 aria-hidden="true" />
          </button>
        </td>
      </tr>
    ))}
  </tbody>
</table>
```

### Rules

1. Use `<th scope="col">` for column headers.
2. `aria-sort` on sortable columns (`ascending`, `descending`, `none`).
3. Action columns have `sr-only` header text.
4. Row action buttons have `aria-label` with context (e.g., Documento).

---

## 10.1 File Upload / Drop Zone

> **Added:** 2026-04-12 — Required by Certificate Management Module (3.2.1)

### ARIA Pattern

```tsx
// FileDropZone — Accessible file upload area
<div
  role="button"
  tabIndex={0}
  aria-label="Área de upload de certificado digital"
  aria-describedby="dropzone-hint"
  aria-disabled={isUploading}
  onKeyDown={(e) => {
    if (e.key === 'Enter' || e.key === ' ') {
      e.preventDefault();
      fileInputRef.current?.click();
    }
  }}
  onClick={() => fileInputRef.current?.click()}
  onDragOver={handleDragOver}
  onDragLeave={handleDragLeave}
  onDrop={handleDrop}
>
  <Upload className="h-8 w-8" aria-hidden="true" />
  <p>Arraste o arquivo ou clique para selecionar</p>
  <p id="dropzone-hint" className="text-xs text-muted-foreground">
    Formatos aceitos: .pfx, .p12 — Tamanho máximo: 10MB
  </p>
  <input
    ref={fileInputRef}
    type="file"
    accept=".pfx,.p12"
    className="sr-only"
    aria-hidden="true"
    tabIndex={-1}
    onChange={handleFileSelect}
  />
</div>

{/* File selected — announce to screen readers */}
{selectedFile && (
  <div aria-live="polite" role="status">
    <p>Arquivo selecionado: {selectedFile.name} ({formatSize(selectedFile.size)})</p>
    <button
      aria-label={`Remover arquivo ${selectedFile.name}`}
      onClick={handleRemoveFile}
    >
      <X className="h-4 w-4" aria-hidden="true" />
      <span className="sr-only">Remover</span>
    </button>
  </div>
)}

{/* Upload progress — announce to screen readers */}
{isUploading && (
  <div
    role="progressbar"
    aria-label="Progresso do upload"
    aria-valuemin={0}
    aria-valuemax={100}
    aria-valuenow={progress}
    aria-live="polite"
  >
    <span className="sr-only">{progress}% enviado</span>
  </div>
)}

{/* Validation error — immediate announcement */}
{validationError && (
  <p role="alert" aria-live="assertive" className="text-destructive">
    {validationError}
  </p>
)}
```

### Keyboard Support

| Key | Action | Context |
|---|---|---|
| `Enter` / `Space` | Open file picker dialog | FileDropZone focused |
| `Tab` | Move focus to/from drop zone | Standard tab order |
| `Delete` / `Backspace` | Remove selected file | File preview focused |
| `Escape` | Cancel drag operation | During drag |

### Rules

1. The drop zone **must** use `role="button"` with `tabIndex={0}` — it is an interactive element.
2. The hidden `<input type="file">` uses `aria-hidden="true"` and `tabIndex={-1}` — the drop zone div is the accessible trigger.
3. `Enter` and `Space` **must** open the native file picker via programmatic click on the hidden input.
4. File selection **must** be announced via `aria-live="polite"` with filename and size.
5. Upload progress uses `role="progressbar"` with `aria-valuenow`, `aria-valuemin`, `aria-valuemax`.
6. Validation errors (wrong extension, oversized file) use `role="alert"` + `aria-live="assertive"`.
7. The remove file button **must** have `aria-label` with the filename context.
8. During upload (`aria-disabled="true"`), the drop zone **must not** accept new files or keyboard activation.
9. **Password field** for `.pfx` files uses `autoComplete="off"` — prevent browser autofill for security-sensitive fields.

---

## 11. Testing Accessibility

### Automated Tools

| Tool | Where | What |
|---|---|---|
| `@storybook/addon-a11y` | Storybook | Per-component ARIA audit |
| `eslint-plugin-jsx-a11y` | ESLint | Static JSX accessibility rules |
| `@axe-core/playwright` | E2E tests | Full-page WCAG audit |

### ESLint Config

```bash
pnpm add -D eslint-plugin-jsx-a11y
```

```json
// .eslintrc.json
{
  "extends": ["plugin:jsx-a11y/recommended"],
  "plugins": ["jsx-a11y"]
}
```

### Playwright Axe Audit

```tsx
// e2e/a11y/audit.spec.ts
import { test, expect } from '@playwright/test';
import AxeBuilder from '@axe-core/playwright';
import { loginAs } from '../helpers/auth.helper';

test.describe('Accessibility Audit', () => {
  test('dashboard has no WCAG AA violations', async ({ page }) => {
    await loginAs(page, 'fiscal-admin');
    await page.goto('/dashboard');

    const results = await new AxeBuilder({ page })
      .withTags(['wcag2a', 'wcag2aa'])
      .analyze();

    expect(results.violations).toEqual([]);
  });

  test('fiscal query page is accessible', async ({ page }) => {
    await loginAs(page, 'fiscal-reader');
    await page.goto('/query');

    const results = await new AxeBuilder({ page })
      .withTags(['wcag2a', 'wcag2aa'])
      .analyze();

    expect(results.violations).toEqual([]);
  });

  test('login page has no violations', async ({ page }) => {
    await page.goto('/');
    // Keycloak login page — audit what we can control
    const results = await new AxeBuilder({ page })
      .withTags(['wcag2a', 'wcag2aa'])
      .exclude('#kc-login') // Exclude Keycloak-controlled elements
      .analyze();

    expect(results.violations).toEqual([]);
  });
});
```

### Rules

1. `eslint-plugin-jsx-a11y` is **mandatory** in the ESLint config.
2. Storybook addon-a11y **must** be installed (defined in `component-design-standard`).
3. Playwright + axe-core audit runs on **every critical page** in E2E tests.
4. Zero WCAG 2.1 AA violations is the target. Violations block merge.

---

## 12. Accessibility Checklist

| # | Check | WCAG Criterion |
|---|---|---|
| 1 | All images have `alt` text (or `alt=""` for decorative) | 1.1.1 |
| 2 | Content is readable at 200% zoom | 1.4.4 |
| 3 | Color contrast ≥ 4.5:1 for normal text, ≥ 3:1 for large text | 1.4.3 |
| 4 | Color is NOT the sole means of conveying information | 1.4.1 |
| 5 | All interactive elements are keyboard-accessible | 2.1.1 |
| 6 | No keyboard trap (user can always Tab out) | 2.1.2 |
| 7 | Skip link present and functional | 2.4.1 |
| 8 | Page has descriptive `<title>` | 2.4.2 |
| 9 | Focus order matches visual order | 2.4.3 |
| 10 | Focus is visible on all interactive elements | 2.4.7 |
| 11 | One `<h1>` per page, logical heading hierarchy | 1.3.1 |
| 12 | All form inputs have associated `<label>` | 1.3.1 |
| 13 | Error messages are programmatically linked (`aria-describedby`) | 3.3.1 |
| 14 | `aria-live` on dynamic content (toasts, loading, errors) | 4.1.3 |
| 15 | Modals trap focus and restore on close | 2.4.3 |
| 16 | File drop zones use `role="button"` + keyboard activation (Enter/Space) | 2.1.1 |
| 17 | Upload progress uses `role="progressbar"` with `aria-valuenow` | 4.1.3 |
| 18 | File validation errors use `role="alert"` for immediate announcement | 4.1.3 |
