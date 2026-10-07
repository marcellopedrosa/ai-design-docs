---
document_id: "COMPONENT-DESIGN-STANDARD"
primary_nature: "Regra"
objective: "Definir regras reutilizáveis e verificáveis para Component Design System."
scope: "Contratos, composição e consistência dos componentes do design system."
non_objectives: "Não criar requisitos de produto, decisões arquiteturais concretas ou procedimentos fora do escopo deste standard."
owner: "Arquitetura e Qualidade"
status: "Active"
date: "2026-08-25"
version: "1.5"
last_reviewed: "2026-09-06"
keywords: "component, design, standard, date-input, calendar, date-picker"
related_files: "./README.md, nextjs-standard.md, i18n-standard.md"
code_references: "frontend/src/components/ui/, frontend/src/components/ui/DateInput/ - destino planejado, frontend/src/components/layout/, frontend/src/components/{module}/, frontend/src/components/shared/"
principal_statement: "Componentes reutilizáveis devem usar os primitives canônicos; todo campo de data civil usa DateInput com o calendário visual DateCalendar."
---

# Component Design System Standard — @FrontendWeb / @WebDesigner

> **Mandatory rules** for building reusable, composable UI components. This standard defines compound component patterns, controlled vs uncontrolled APIs, variant management with `cva`, prop API conventions, accessibility requirements, Storybook integration, and file organization.

> **Prerequisite:** Read [`nextjs-standard.md`](nextjs-standard.md) (Server vs Client Components) and [`i18n-standard.md`](i18n-standard.md) (all user-facing text through `t()`).

---

## 1. Dependencies

| Package | Version | Purpose |
|---|---|---|
| `class-variance-authority` | `^0.7.x` | Type-safe component variants (size, color, state) |
| `clsx` | `^2.x` | Conditional classname merging |
| `tailwind-merge` | `^2.x` | Deduplicate conflicting Tailwind classes |
| `@radix-ui/react-*` | latest | Headless, accessible base primitives |
| `lucide-react` | `^0.4.x` | Icon library |
| `@storybook/react` | `^8.x` | Component documentation and visual testing |

```bash
pnpm add class-variance-authority clsx tailwind-merge lucide-react
pnpm add -D @storybook/react @storybook/nextjs
```

---

## 2. Utility — cn() Helper

```tsx
// src/lib/cn.ts
import { clsx, type ClassValue } from 'clsx';
import { twMerge } from 'tailwind-merge';

export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs));
}
```

### Rules

1. **Every** component uses `cn()` for className composition. Never raw `clsx` or string concatenation.
2. `twMerge` ensures conflicting Tailwind classes are resolved (last wins).
3. Import: `import { cn } from '@/lib/cn'`.

---

## 3. Component File Structure

```
src/components/
├── ui/                          # Design system primitives
│   ├── Button/
│   │   ├── Button.tsx           # Component implementation
│   │   ├── Button.stories.tsx   # Storybook stories
│   │   └── index.ts             # Re-export
│   ├── Input/
│   │   ├── Input.tsx
│   │   ├── Input.stories.tsx
│   │   └── index.ts
│   ├── Card/
│   │   ├── Card.tsx             # Compound component (Card, CardHeader, CardContent, CardFooter)
│   │   ├── Card.stories.tsx
│   │   └── index.ts
│   ├── DataTable/
│   │   ├── DataTable.tsx
│   │   ├── DataTable.stories.tsx
│   │   └── index.ts
│   ├── Badge/
│   ├── Modal/
│   ├── Skeleton/
│   └── Toast/
├── layout/                      # Layout components
│   ├── AppShell.tsx
│   ├── Sidebar.tsx
│   └── Topbar.tsx
├── fiscal/                      # Module-specific components
│   ├── FiscalQueryPage.tsx
│   ├── FiscalQueryForm.tsx
│   └── FiscalStatusBadge.tsx
└── shared/                      # Cross-module components
    ├── ErrorState.tsx
    ├── EmptyState.tsx
    ├── LoadingSkeleton.tsx
    └── ConfirmDialog.tsx
```

### Rules

1. `src/components/ui/` — design system primitives. Reusable across all modules. **No business logic.**
2. `src/components/layout/` — layout shell (sidebar, topbar, app wrapper).
3. `src/components/{module}/` — module-specific components with business logic.
4. `src/components/shared/` — cross-module utility components (error, empty, loading states).
5. Each UI component gets **its own folder** with `Component.tsx`, `Component.stories.tsx`, and `index.ts`.
6. `index.ts` re-exports: `export { Button } from './Button'`.

---

## 4. Variants with CVA (class-variance-authority)

### Button Example

```tsx
// src/components/ui/Button/Button.tsx
'use client';

import { forwardRef, type ButtonHTMLAttributes } from 'react';
import { cva, type VariantProps } from 'class-variance-authority';
import { cn } from '@/lib/cn';
import { Loader2 } from 'lucide-react';

const buttonVariants = cva(
  // Base styles (always applied)
  'inline-flex items-center justify-center gap-2 rounded-lg font-medium transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2 disabled:pointer-events-none disabled:opacity-50',
  {
    variants: {
      variant: {
        primary:
          'bg-primary text-primary-foreground hover:bg-primary/90 shadow-sm',
        secondary:
          'bg-secondary text-secondary-foreground hover:bg-secondary/80',
        destructive:
          'bg-destructive text-destructive-foreground hover:bg-destructive/90',
        outline:
          'border border-input bg-transparent hover:bg-accent hover:text-accent-foreground',
        ghost:
          'hover:bg-accent hover:text-accent-foreground',
        link:
          'text-primary underline-offset-4 hover:underline',
      },
      size: {
        sm: 'h-8 px-3 text-xs',
        md: 'h-10 px-4 text-sm',
        lg: 'h-12 px-6 text-base',
        icon: 'h-10 w-10',
      },
    },
    defaultVariants: {
      variant: 'primary',
      size: 'md',
    },
  },
);

export interface ButtonProps
  extends ButtonHTMLAttributes<HTMLButtonElement>,
    VariantProps<typeof buttonVariants> {
  isLoading?: boolean;
}

export const Button = forwardRef<HTMLButtonElement, ButtonProps>(
  ({ className, variant, size, isLoading, disabled, children, ...props }, ref) => {
    return (
      <button
        ref={ref}
        className={cn(buttonVariants({ variant, size }), className)}
        disabled={disabled || isLoading}
        {...props}
      >
        {isLoading && <Loader2 className="h-4 w-4 animate-spin" />}
        {children}
      </button>
    );
  },
);
Button.displayName = 'Button';

// Export variants for Storybook and composition
export { buttonVariants };
```

### Badge Example

```tsx
// src/components/ui/Badge/Badge.tsx
import { cva, type VariantProps } from 'class-variance-authority';
import { cn } from '@/lib/cn';

const badgeVariants = cva(
  'inline-flex items-center rounded-full px-2.5 py-0.5 text-xs font-semibold transition-colors',
  {
    variants: {
      variant: {
        default: 'bg-primary/10 text-primary',
        success: 'bg-green-100 text-green-800 dark:bg-green-900/30 dark:text-green-400',
        warning: 'bg-amber-100 text-amber-800 dark:bg-amber-900/30 dark:text-amber-400',
        error: 'bg-red-100 text-red-800 dark:bg-red-900/30 dark:text-red-400',
        info: 'bg-blue-100 text-blue-800 dark:bg-blue-900/30 dark:text-blue-400',
        outline: 'border border-current bg-transparent',
      },
    },
    defaultVariants: {
      variant: 'default',
    },
  },
);

export interface BadgeProps
  extends React.HTMLAttributes<HTMLSpanElement>,
    VariantProps<typeof badgeVariants> {}

export const Badge = ({ className, variant, ...props }: BadgeProps) => (
  <span className={cn(badgeVariants({ variant }), className)} {...props} />
);
```

### Status Badge (Module-Specific)

```tsx
// src/components/fiscal/FiscalStatusBadge.tsx
'use client';

import { useTranslations } from 'next-intl';
import { Badge } from '@/components/ui/Badge';

const STATUS_VARIANT_MAP = {
  PENDING: 'warning',
  COMPLETED: 'success',
  ERROR: 'error',
} as const;

interface FiscalStatusBadgeProps {
  status: keyof typeof STATUS_VARIANT_MAP;
}

export const FiscalStatusBadge = ({ status }: FiscalStatusBadgeProps) => {
  const t = useTranslations('fiscal.status');

  return (
    <Badge variant={STATUS_VARIANT_MAP[status]}>
      {t(status)}
    </Badge>
  );
};
```

### Rules

1. **Every** visual variant uses `cva()`. No inline ternary chains for styles.
2. `defaultVariants` is mandatory — components must work without explicit variant props.
3. `className` prop is **always last** and merged via `cn()` — allows consumer overrides.
4. Export `*Variants` alongside the component for Storybook and composition.

---

## 5. Compound Components

### Card Example

```tsx
// src/components/ui/Card/Card.tsx
import { forwardRef, type HTMLAttributes } from 'react';
import { cn } from '@/lib/cn';

const Card = forwardRef<HTMLDivElement, HTMLAttributes<HTMLDivElement>>(
  ({ className, ...props }, ref) => (
    <div
      ref={ref}
      className={cn(
        'rounded-xl border bg-card text-card-foreground shadow-sm',
        className,
      )}
      {...props}
    />
  ),
);
Card.displayName = 'Card';

const CardHeader = forwardRef<HTMLDivElement, HTMLAttributes<HTMLDivElement>>(
  ({ className, ...props }, ref) => (
    <div ref={ref} className={cn('flex flex-col gap-1.5 p-6', className)} {...props} />
  ),
);
CardHeader.displayName = 'CardHeader';

const CardTitle = forwardRef<HTMLHeadingElement, HTMLAttributes<HTMLHeadingElement>>(
  ({ className, ...props }, ref) => (
    <h3 ref={ref} className={cn('text-lg font-semibold leading-none', className)} {...props} />
  ),
);
CardTitle.displayName = 'CardTitle';

const CardDescription = forwardRef<HTMLParagraphElement, HTMLAttributes<HTMLParagraphElement>>(
  ({ className, ...props }, ref) => (
    <p ref={ref} className={cn('text-sm text-muted-foreground', className)} {...props} />
  ),
);
CardDescription.displayName = 'CardDescription';

const CardContent = forwardRef<HTMLDivElement, HTMLAttributes<HTMLDivElement>>(
  ({ className, ...props }, ref) => (
    <div ref={ref} className={cn('p-6 pt-0', className)} {...props} />
  ),
);
CardContent.displayName = 'CardContent';

const CardFooter = forwardRef<HTMLDivElement, HTMLAttributes<HTMLDivElement>>(
  ({ className, ...props }, ref) => (
    <div ref={ref} className={cn('flex items-center p-6 pt-0', className)} {...props} />
  ),
);
CardFooter.displayName = 'CardFooter';

export { Card, CardHeader, CardTitle, CardDescription, CardContent, CardFooter };
```

### Usage

```tsx
<Card>
  <CardHeader>
    <CardTitle>Consulta Fiscal</CardTitle>
    <CardDescription>Última atualização: há 2 horas</CardDescription>
  </CardHeader>
  <CardContent>
    <FiscalStatusBadge status="COMPLETED" />
  </CardContent>
  <CardFooter>
    <Button variant="outline" size="sm">Ver detalhes</Button>
  </CardFooter>
</Card>
```

### Rules

1. Compound components are **named exports** from the same file.
2. Each sub-component has `displayName` set (for DevTools/Storybook).
3. All sub-components use `forwardRef` and accept `className`.
4. **No validation** of children composition (keep it flexible, not restrictive).
5. Use for: Card, Modal, DataTable, Dropdown, Tabs, Accordion.

---

## 6. Controlled vs Uncontrolled

### Pattern: Support Both

```tsx
// src/components/ui/Input/Input.tsx
'use client';

import { forwardRef, type InputHTMLAttributes } from 'react';
import { cn } from '@/lib/cn';

export interface InputProps extends InputHTMLAttributes<HTMLInputElement> {
  label?: string;
  error?: string;
  hint?: string;
}

export const Input = forwardRef<HTMLInputElement, InputProps>(
  ({ className, label, error, hint, id, ...props }, ref) => {
    const inputId = id || props.name;

    return (
      <div className="flex flex-col gap-1.5">
        {label && (
          <label htmlFor={inputId} className="text-sm font-medium text-foreground">
            {label}
          </label>
        )}
        <input
          ref={ref}
          id={inputId}
          className={cn(
            'flex h-10 w-full rounded-lg border border-input bg-background px-3 py-2 text-sm',
            'placeholder:text-muted-foreground',
            'focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring',
            'disabled:cursor-not-allowed disabled:opacity-50',
            error && 'border-destructive focus-visible:ring-destructive',
            className,
          )}
          aria-invalid={!!error}
          aria-describedby={error ? `${inputId}-error` : hint ? `${inputId}-hint` : undefined}
          {...props}
        />
        {error && (
          <p id={`${inputId}-error`} role="alert" className="text-xs text-destructive">
            {error}
          </p>
        )}
        {!error && hint && (
          <p id={`${inputId}-hint`} className="text-xs text-muted-foreground">
            {hint}
          </p>
        )}
      </div>
    );
  },
);
Input.displayName = 'Input';
```

### Controlled (React Hook Form)

```tsx
<Input
  label="Documento"
  error={errors.documento?.message}
  {...register('documento')}
/>
```

### Uncontrolled (Simple)

```tsx
<Input
  label="Buscar"
  defaultValue=""
  onChange={(e) => setSearch(e.target.value)}
/>
```

### Rules

1. UI primitives **must** support both controlled and uncontrolled modes.
2. Use `forwardRef` — required for React Hook Form `register()` integration.
3. `label`, `error`, and `hint` are **optional built-in props** (not external wrappers).
4. `aria-invalid` and `aria-describedby` are set automatically from `error` prop.
5. **Never** force `value` + `onChange` — let the consumer choose the mode.

---

## 7. Props API Conventions

| Convention | Example | Rationale |
|---|---|---|
| Extend native HTML attrs | `ButtonHTMLAttributes<HTMLButtonElement>` | Consumer can pass any native attr |
| `className` always accepted | `className?: string` | Override styles via `cn()` |
| `variant` for visual style | `variant: 'primary' \| 'outline'` | CVA-managed |
| `size` for dimensions | `size: 'sm' \| 'md' \| 'lg'` | CVA-managed |
| `is*` for boolean states | `isLoading`, `isDisabled` | Clear intent |
| `on*` for event handlers | `onConfirm`, `onDismiss` | Standard React pattern |
| `*Id` for element IDs | `triggerId`, `contentId` | Accessibility linking |
| Render props pattern | `renderIcon?: () => ReactNode` | Customizable slots |

### Rules

1. **Extend native attributes** — never create wrapper objects for HTML props.
2. Props interface **exported** alongside the component: `export interface ButtonProps`.
3. Boolean props use `is*` prefix: `isLoading`, `isOpen`, `isDisabled`.
4. Callback props use `on*` prefix: `onClose`, `onSelect`, `onConfirm`.
5. **Never** use `enum` for variant values. Use string literal union: `'sm' | 'md' | 'lg'`.

---

## 8. Accessibility (a11y)

| Component | Required ARIA | Keyboard |
|---|---|---|
| Button | `aria-disabled`, `aria-busy` | Enter/Space |
| Input | `aria-invalid`, `aria-describedby` | Tab focus |
| Modal | `role="dialog"`, `aria-modal`, `aria-labelledby` | Escape to close, focus trap |
| Dropdown | `role="menu"`, `aria-expanded` | Arrow keys, Escape |
| Toast | `role="status"`, `aria-live="polite"` | Auto-dismiss |
| Tabs | `role="tablist"`, `role="tab"`, `aria-selected` | Arrow keys |
| Badge | `role="status"` (if dynamic) | — |
| FileDropZone | `role="button"`, `aria-label`, `aria-describedby`, `aria-disabled` | Enter/Space to open picker, Tab focus |

### Rules

1. **Every** interactive component must be keyboard-accessible.
2. Use `@radix-ui/react-*` for complex interactions (Modal, Dropdown, Tabs) — they handle ARIA automatically.
3. Focus must be **visible** — never suppress `focus-visible` ring.
4. Color alone must NOT convey meaning — always pair with text or icon.
5. All images must have `alt` text (or `alt=""` for decorative).
6. Form errors use `role="alert"` for screen reader announcement.

---

## 9. Storybook Integration

### Configuration

```tsx
// .storybook/main.ts
import type { StorybookConfig } from '@storybook/nextjs';

const config: StorybookConfig = {
  stories: ['../src/components/**/*.stories.@(ts|tsx)'],
  addons: [
    '@storybook/addon-links',
    '@storybook/addon-essentials',
    '@storybook/addon-a11y',       // Accessibility audit panel
  ],
  framework: '@storybook/nextjs',
};

export default config;
```

### Button Story Example

```tsx
// src/components/ui/Button/Button.stories.tsx
import type { Meta, StoryObj } from '@storybook/react';
import { Button } from './Button';

const meta: Meta<typeof Button> = {
  title: 'UI/Button',
  component: Button,
  tags: ['autodocs'],
  argTypes: {
    variant: {
      control: 'select',
      options: ['primary', 'secondary', 'destructive', 'outline', 'ghost', 'link'],
    },
    size: {
      control: 'select',
      options: ['sm', 'md', 'lg', 'icon'],
    },
    isLoading: { control: 'boolean' },
    disabled: { control: 'boolean' },
  },
};

export default meta;
type Story = StoryObj<typeof Button>;

export const Primary: Story = {
  args: { children: 'Salvar', variant: 'primary' },
};

export const Secondary: Story = {
  args: { children: 'Cancelar', variant: 'secondary' },
};

export const Destructive: Story = {
  args: { children: 'Excluir', variant: 'destructive' },
};

export const Loading: Story = {
  args: { children: 'Salvando...', isLoading: true },
};

export const AllSizes: Story = {
  render: () => (
    <div className="flex items-center gap-4">
      <Button size="sm">Small</Button>
      <Button size="md">Medium</Button>
      <Button size="lg">Large</Button>
    </div>
  ),
};

export const AllVariants: Story = {
  render: () => (
    <div className="flex flex-wrap gap-4">
      <Button variant="primary">Primary</Button>
      <Button variant="secondary">Secondary</Button>
      <Button variant="destructive">Destructive</Button>
      <Button variant="outline">Outline</Button>
      <Button variant="ghost">Ghost</Button>
      <Button variant="link">Link</Button>
    </div>
  ),
};
```

### Compound Component Story

```tsx
// src/components/ui/Card/Card.stories.tsx
import type { Meta, StoryObj } from '@storybook/react';
import { Card, CardHeader, CardTitle, CardDescription, CardContent, CardFooter } from './Card';
import { Button } from '../Button';
import { Badge } from '../Badge';

const meta: Meta<typeof Card> = {
  title: 'UI/Card',
  component: Card,
  tags: ['autodocs'],
};

export default meta;
type Story = StoryObj<typeof Card>;

export const Default: Story = {
  render: () => (
    <Card className="w-[380px]">
      <CardHeader>
        <CardTitle>Consulta Fiscal</CardTitle>
        <CardDescription>Documento: 12.345.678/0001-90</CardDescription>
      </CardHeader>
      <CardContent>
        <Badge variant="success">Concluído</Badge>
      </CardContent>
      <CardFooter className="justify-end gap-2">
        <Button variant="outline" size="sm">Cancelar</Button>
        <Button size="sm">Ver detalhes</Button>
      </CardFooter>
    </Card>
  ),
};
```

### NPM Scripts

```json
{
  "scripts": {
    "storybook": "storybook dev -p 6006",
    "storybook:build": "storybook build -o storybook-static"
  }
}
```

### Rules

1. **Every** `src/components/ui/` component **must** have a `.stories.tsx` file.
2. Use `tags: ['autodocs']` for automatic documentation generation.
3. Stories demonstrate: all variants, all sizes, loading state, disabled state, dark mode.
4. Install `@storybook/addon-a11y` for automatic accessibility auditing.
5. Module-specific components (`src/components/fiscal/`) do **not** require stories (optional).

---

## 10. Shared Reusable Components

### ErrorState

```tsx
// src/components/shared/ErrorState.tsx
'use client';

import { useTranslations } from 'next-intl';
import { AlertCircle } from 'lucide-react';
import { Button } from '@/components/ui/Button';

interface ErrorStateProps {
  message?: string;
  onRetry?: () => void;
}

export const ErrorState = ({ message, onRetry }: ErrorStateProps) => {
  const t = useTranslations('common.states');
  const tBtn = useTranslations('common.buttons');

  return (
    <div className="flex flex-col items-center justify-center gap-4 py-12 text-center" role="alert">
      <AlertCircle className="h-12 w-12 text-destructive/60" />
      <p className="text-sm text-muted-foreground">{message ?? t('error')}</p>
      {onRetry && (
        <Button variant="outline" size="sm" onClick={onRetry}>
          {tBtn('retry')}
        </Button>
      )}
    </div>
  );
};
```

### EmptyState

```tsx
// src/components/shared/EmptyState.tsx
'use client';

import { useTranslations } from 'next-intl';
import { Inbox } from 'lucide-react';
import { Button } from '@/components/ui/Button';

interface EmptyStateProps {
  message?: string;
  action?: { label: string; onClick: () => void };
}

export const EmptyState = ({ message, action }: EmptyStateProps) => {
  const t = useTranslations('common.states');

  return (
    <div className="flex flex-col items-center justify-center gap-4 py-12 text-center">
      <Inbox className="h-12 w-12 text-muted-foreground/40" />
      <p className="text-sm text-muted-foreground">{message ?? t('empty')}</p>
      {action && (
        <Button variant="primary" size="sm" onClick={action.onClick}>
          {action.label}
        </Button>
      )}
    </div>
  );
};
```

### ConfirmDialog

```tsx
// src/components/shared/ConfirmDialog.tsx
'use client';

import { useTranslations } from 'next-intl';
import { Button } from '@/components/ui/Button';

interface ConfirmDialogProps {
  isOpen: boolean;
  title?: string;
  message?: string;
  onConfirm: () => void;
  onCancel: () => void;
  isLoading?: boolean;
  variant?: 'destructive' | 'primary';
}

export const ConfirmDialog = ({
  isOpen,
  title,
  message,
  onConfirm,
  onCancel,
  isLoading,
  variant = 'destructive',
}: ConfirmDialogProps) => {
  const t = useTranslations('common.confirmation');

  if (!isOpen) return null;

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50" role="dialog" aria-modal="true">
      <div className="w-full max-w-md rounded-xl bg-background p-6 shadow-xl">
        <h2 className="text-lg font-semibold">{title ?? t('deleteTitle')}</h2>
        <p className="mt-2 text-sm text-muted-foreground">{message ?? t('deleteMessage')}</p>
        <div className="mt-6 flex justify-end gap-3">
          <Button variant="outline" onClick={onCancel} disabled={isLoading}>
            {t('no')}
          </Button>
          <Button variant={variant} onClick={onConfirm} isLoading={isLoading}>
            {t('yes')}
          </Button>
        </div>
      </div>
    </div>
  );
};
```

### Rules

1. `ErrorState`, `EmptyState`, `ConfirmDialog` are **mandatory** shared components.
2. All use i18n (`useTranslations`) with fallback default text.
3. `ErrorState` always has a retry button when `onRetry` is provided.
4. `ConfirmDialog` uses `role="dialog"` and `aria-modal="true"`.

---

## 11. Canonical Date Field and Calendar

O componente canônico para entrada de data civil é
`frontend/src/components/ui/DateInput/DateInput.tsx`, exportado como `DateInput`. Seu popover visual
é `frontend/src/components/ui/DateInput/DateCalendar.tsx`, exportado como `DateCalendar`; ele é
parte interna da composição e não deve ser recriado por cada módulo.

A tela `/audit` é a implementação de referência: os campos **De** e **Até** usam `DateInput` e
abrem o mesmo `DateCalendar` quando o campo recebe foco ou clique.

### Mandatory rules

1. Toda tela nova ou alterada que possua campo de data civil **must** usar `DateInput`; é proibido
   criar outro calendário visual local ou usar diretamente `<input type="date">`.
2. O campo textual é o único gatilho visível. Não adicionar botão ou ícone lateral de calendário.
3. Foco e clique no campo abrem o calendário; `Escape`, foco externo e clique externo o fecham.
4. A apresentação brasileira usa `DD/MM/AAAA`; o valor civil trafegado para contratos usa
   `YYYY-MM-DD`, sem conversão por fuso horário.
5. Mês, dias da semana e nomes acessíveis usam o locale ativo via `Intl.DateTimeFormat`; textos de
   navegação, **Hoje** e **Limpar data** vêm do catálogo i18n do consumidor.
6. O calendário deve permanecer contido no viewport em desktop, tablet e mobile, inclusive dentro
   de áreas roláveis.
7. O input mantém `role="combobox"`, `aria-haspopup="dialog"`, `aria-expanded` e `aria-controls`;
   o calendário mantém `role="dialog"`, tabela semântica, data selecionada e data atual expostas.
8. A integração deve preservar digitação e máscara, navegação por teclado, foco do React Hook Form,
   estado desabilitado, erro e hint do `Input` canônico.
9. Mudanças no componente exigem teste unitário/componente, acessibilidade e pelo menos um teste de
   browser que cubra foco, seleção e contenção no viewport.

### Canonical usage

```tsx
import { DateInput } from '@/components/ui/DateInput';

<DateInput
  id="period-from"
  name="fromDate"
  label={t('filters.startDate')}
  value={field.value}
  placeholder={t('filters.datePlaceholder')}
  formatHint={t('filters.dateFormatHint')}
  calendarLabel={t('filters.openStartDateCalendar')}
  previousMonthLabel={t('filters.previousMonth')}
  nextMonthLabel={t('filters.nextMonth')}
  clearDateLabel={t('filters.clearDate')}
  todayLabel={t('filters.today')}
  onChange={field.onChange}
  onBlur={field.onBlur}
/>
```

---

## 12. Component Checklist

Before merging any new UI component, verify:

| # | Check | Required |
|---|---|---|
| 1 | Uses `cva()` for visual variants | ✅ |
| 2 | Accepts `className` prop via `cn()` | ✅ |
| 3 | Uses `forwardRef` for interactive elements | ✅ |
| 4 | Has `displayName` set | ✅ |
| 5 | Extends native HTML attributes | ✅ |
| 6 | Props interface exported | ✅ |
| 7 | ARIA attributes for accessibility | ✅ |
| 8 | Keyboard navigation works | ✅ |
| 9 | Storybook story (for `ui/` components) | ✅ |
| 10 | Dark mode variant tested | ✅ |
| 11 | User-facing text via `useTranslations()` | ✅ |
| 12 | No hardcoded colors — uses design tokens | ✅ |
