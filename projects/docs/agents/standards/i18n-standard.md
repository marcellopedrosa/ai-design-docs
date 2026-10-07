---
document_id: "I18N-STANDARD"
primary_nature: "Regra"
objective: "Definir regras reutilizáveis e verificáveis para Internationalization (i18n)."
scope: "Locales, chaves, traduções, fallback e conteúdo internacionalizado."
non_objectives: "Não criar requisitos de produto, decisões arquiteturais concretas ou procedimentos fora do escopo deste standard."
owner: "Arquitetura e Qualidade"
status: "Active"
date: "2026-08-25"
version: "1.4"
keywords: "i18n, standard, standard"
related_files: "./README.md"
code_references: "src/lib/formatters.ts, backend/, frontend/"
principal_statement: "As regras de Internationalization (i18n) aplicam-se somente ao escopo e aos controles declarados neste standard."
---

# Internationalization (i18n) Standard — @FrontendWeb / @UIIntegrator

> **Mandatory rules** for internationalization in the frontend. Default locale is `pt-BR`. This standard defines translation file organization, formatting patterns (dates, numbers, currency, documents), pluralization, and component-level i18n integration using `next-intl`.

---

## 1. Dependencies

| Package | Version | Purpose |
|---|---|---|
| `next-intl` | `^4.x` | Next.js App Router-native i18n (messages, formatting, routing) |

```bash
npm install next-intl
```

### Why next-intl

1. Built for Next.js App Router (Server + Client Components).
2. Type-safe message keys via generated types.
3. Built-in formatting (dates, numbers, lists) using `Intl` API.
4. No runtime bundle for unused locales (tree-shaking).

### Rules

1. **Never** use `react-i18next` or `react-intl` — they are not optimized for App Router.
2. **Never** hardcode user-facing strings in components. All text goes through `t()`.

---

## 2. Supported Locales

| Locale | Language | Status |
|---|---|---|
| `pt-BR` | Portuguese (Brazil) | **Default** — full coverage required |
| `en` | English | Future — structure prepared, translations deferred |

### Rules

1. `pt-BR` is the **default** and **only required** locale at launch.
2. The architecture supports additional locales without refactoring.
3. Adding a new locale requires: create message file, add to `locales` array, translate.
4. **Never** remove `pt-BR` as the default fallback.

---

## 3. File Structure

```
src/
├── i18n/
│   ├── config.ts                # Locale config and defaults
│   ├── request.ts               # next-intl request config
│   └── messages/
│       ├── pt-BR/
│       │   ├── common.json      # Shared: buttons, labels, states
│       │   ├── navigation.json  # Sidebar, topbar, breadcrumbs
│       │   ├── auth.json        # Login, logout, forbidden, session
│       │   ├── fiscal.json      # Fiscal module strings
│       │   ├── billing.json     # Billing module strings
│       │   ├── certificates.json
│       │   ├── whatsapp.json
│       │   ├── settings.json    # Tenant settings
│       │   └── errors.json      # Error messages
│       └── en/
│           ├── common.json
│           └── ...              # Same structure as pt-BR
```

### Rules

1. **One JSON file per module** (bounded context). Never a single giant file.
2. `common.json` for shared strings (buttons, states, labels) used across modules.
3. `errors.json` for all error messages (API errors, validation, generic).
4. File names match the bounded context: `fiscal.json`, `billing.json`, etc.
5. Locale folders mirror each other — same file names and key structure.

---

## 4. Configuration

```tsx
// src/i18n/config.ts
export const locales = ['pt-BR', 'en'] as const;
export type Locale = (typeof locales)[number];
export const defaultLocale: Locale = 'pt-BR';
```

```tsx
// src/i18n/request.ts
import { getRequestConfig } from 'next-intl/server';
import { defaultLocale } from './config';

export default getRequestConfig(async () => {
  const locale = defaultLocale; // or resolve from cookie/header/URL

  const messages = {
    ...(await import(`./messages/${locale}/common.json`)).default,
    ...(await import(`./messages/${locale}/navigation.json`)).default,
    ...(await import(`./messages/${locale}/auth.json`)).default,
    ...(await import(`./messages/${locale}/fiscal.json`)).default,
    ...(await import(`./messages/${locale}/billing.json`)).default,
    ...(await import(`./messages/${locale}/certificates.json`)).default,
    ...(await import(`./messages/${locale}/whatsapp.json`)).default,
    ...(await import(`./messages/${locale}/settings.json`)).default,
    ...(await import(`./messages/${locale}/errors.json`)).default,
  };

  return { locale, messages };
});
```

```tsx
// next.config.ts
import createNextIntlPlugin from 'next-intl/plugin';

const withNextIntl = createNextIntlPlugin('./src/i18n/request.ts');

const nextConfig = {
  // ... other config
};

export default withNextIntl(nextConfig);
```

### Provider in Root Layout

```tsx
// src/app/layout.tsx
import { NextIntlClientProvider } from 'next-intl';
import { getMessages, getLocale } from 'next-intl/server';

export default async function RootLayout({ children }: { children: React.ReactNode }) {
  const locale = await getLocale();
  const messages = await getMessages();

  return (
    <html lang={locale}>
      <body>
        <NextIntlClientProvider locale={locale} messages={messages}>
          <Providers>{children}</Providers>
        </NextIntlClientProvider>
      </body>
    </html>
  );
}
```

### Rules

1. `NextIntlClientProvider` wraps the entire app at root layout level.
2. Messages are loaded **server-side** and passed to the client provider.
3. `locale` is set to `pt-BR` by default — future: resolve from user preferences or URL.

---

## 5. Translation File Format

### common.json (Shared Strings)

```json
{
  "common": {
    "buttons": {
      "save": "Salvar",
      "cancel": "Cancelar",
      "delete": "Excluir",
      "edit": "Editar",
      "create": "Criar",
      "search": "Buscar",
      "filter": "Filtrar",
      "clearFilters": "Limpar filtros",
      "back": "Voltar",
      "next": "Próximo",
      "confirm": "Confirmar",
      "close": "Fechar",
      "retry": "Tentar novamente",
      "loading": "Carregando..."
    },
    "states": {
      "loading": "Carregando...",
      "empty": "Nenhum resultado encontrado",
      "error": "Ocorreu um erro. Tente novamente.",
      "noData": "Sem dados disponíveis"
    },
    "labels": {
      "status": "Status",
      "createdAt": "Criado em",
      "updatedAt": "Atualizado em",
      "actions": "Ações",
      "total": "Total",
      "page": "Página",
      "of": "de"
    },
    "confirmation": {
      "deleteTitle": "Confirmar exclusão",
      "deleteMessage": "Tem certeza que deseja excluir? Esta ação não pode ser desfeita.",
      "yes": "Sim, excluir",
      "no": "Não, cancelar"
    }
  }
}
```

### fiscal.json (Module-Specific)

```json
{
  "fiscal": {
    "title": "Consulta Fiscal",
    "description": "Consulte a situação fiscal de empresas por Documento",
    "form": {
      "documento": "Documento",
      "documentoPlaceholder": "00.000.000/0001-00",
      "submit": "Consultar"
    },
    "status": {
      "PENDING": "Pendente",
      "COMPLETED": "Concluído",
      "ERROR": "Erro"
    },
    "table": {
      "documento": "Documento",
      "status": "Situação",
      "date": "Data da consulta",
      "result": "Resultado"
    },
    "messages": {
      "createSuccess": "Consulta fiscal criada com sucesso",
      "deleteSuccess": "Consulta fiscal excluída",
      "notFound": "Consulta fiscal não encontrada"
    }
  }
}
```

### errors.json

```json
{
  "errors": {
    "generic": "Ocorreu um erro inesperado. Tente novamente.",
    "network": "Não foi possível conectar ao servidor. Verifique sua conexão.",
    "forbidden": "Você não tem permissão para esta ação.",
    "notFound": "O recurso solicitado não foi encontrado.",
    "sessionExpired": "Sua sessão expirou. Faça login novamente.",
    "validation": "Verifique os campos e tente novamente.",
    "tooManyRequests": "Muitas requisições. Aguarde um momento.",
    "tenantMissing": "Erro de configuração da sessão. Contate o suporte."
  }
}
```

### auth.json

```json
{
  "auth": {
    "login": "Entrar",
    "logout": "Sair",
    "logoutConfirm": "Tem certeza que deseja sair?",
    "forbidden": {
      "title": "Acesso Negado",
      "message": "Você não tem permissão para acessar esta página.",
      "user": "Usuário: {username}",
      "backHome": "Voltar ao início"
    },
    "session": {
      "expired": "Sua sessão expirou",
      "refreshing": "Atualizando sessão..."
    }
  }
}
```

### Key Naming Rules

1. Keys use **camelCase**: `createSuccess`, `documentoPlaceholder`.
2. Keys are **namespaced** by module: `fiscal.form.documento`, `common.buttons.save`.
3. Interpolation uses `{variable}` syntax: `"Usuário: {username}"`.
4. **Never** nest deeper than 3 levels: `module.section.key`.
5. Status/enum translations match the **exact backend enum value** as key.

---

## 6. Using Translations in Components

### Server Component

```tsx
// src/app/(fiscal)/query/page.tsx
import { useTranslations } from 'next-intl';
import type { Metadata } from 'next';
import { getTranslations } from 'next-intl/server';

export async function generateMetadata(): Promise<Metadata> {
  const t = await getTranslations('fiscal');
  return { title: t('title'), description: t('description') };
}

export default function Page() {
  // For Server Components that render Client Components
  return <FiscalQueryPage />;
}
```

### Client Component

```tsx
// src/components/fiscal/FiscalQueryPage.tsx
'use client';

import { useTranslations } from 'next-intl';

export const FiscalQueryPage = () => {
  const t = useTranslations('fiscal');
  const tCommon = useTranslations('common');

  return (
    <div>
      <h1>{t('title')}</h1>
      <p>{t('description')}</p>

      <button>{tCommon('buttons.search')}</button>
      <button>{tCommon('buttons.clearFilters')}</button>
    </div>
  );
};
```

### With Interpolation

```tsx
const t = useTranslations('auth.forbidden');

// "Usuário: {username}" → "Usuário: joao.silva"
<p>{t('user', { username: user.username })}</p>
```

### Rules

1. `useTranslations('namespace')` — always pass the namespace (module name).
2. Use `getTranslations()` (async) in Server Components; `useTranslations()` in Client Components.
3. One `useTranslations()` call per namespace used. Multiple calls are OK.
4. **Never** concatenate translated strings. Use interpolation `{variable}`.
5. **Never** put HTML in translation strings. Use rich text or separate components.

---

## 7. Formatting — Dates, Numbers, Currency, Documents

### Date Formatting

```tsx
'use client';

import { useFormatter } from 'next-intl';

export const DateDisplay = ({ date }: { date: string }) => {
  const format = useFormatter();

  return (
    <time dateTime={date}>
      {format.dateTime(new Date(date), {
        day: '2-digit',
        month: '2-digit',
        year: 'numeric',
      })}
      {/* Output: 15/03/2026 */}
    </time>
  );
};

// With time
format.dateTime(new Date(date), {
  day: '2-digit',
  month: '2-digit',
  year: 'numeric',
  hour: '2-digit',
  minute: '2-digit',
});
// Output: 15/03/2026 14:30
```

### Relative Time

```tsx
format.relativeTime(new Date(date));
// Output: "há 2 dias", "em 3 horas"
```

### Currency

```tsx
format.number(1500.5, {
  style: 'currency',
  currency: 'BRL',
});
// Output: R$ 1.500,50
```

### Percentage

```tsx
format.number(0.87, { style: 'percent' });
// Output: 87%
```

### Document Formatting (CPF, Documento, Phone)

```tsx
// src/lib/formatters.ts
// These are NOT locale-dependent — they are Brazil-specific masks

export const formatCPF = (value: string): string => {
  const digits = value.replace(/\D/g, '').slice(0, 11);
  return digits.replace(/(\d{3})(\d{3})(\d{3})(\d{2})/, '$1.$2.$3-$4');
};

export const formatDocumento = (value: string): string => {
  const digits = value.replace(/\D/g, '').slice(0, 14);
  return digits.replace(/(\d{2})(\d{3})(\d{3})(\d{4})(\d{2})/, '$1.$2.$3/$4-$5');
};

export const formatPhone = (value: string): string => {
  const digits = value.replace(/\D/g, '');
  if (digits.length === 11) {
    return digits.replace(/(\d{2})(\d{5})(\d{4})/, '($1) $2-$3');
  }
  return digits.replace(/(\d{2})(\d{4})(\d{4})/, '($1) $2-$3');
};

export const formatCEP = (value: string): string => {
  const digits = value.replace(/\D/g, '').slice(0, 8);
  return digits.replace(/(\d{5})(\d{3})/, '$1-$2');
};
```

### Rules

1. **Dates and numbers** use `useFormatter()` from `next-intl` (locale-aware).
2. **Documents** (CPF, Documento, phone, CEP) use custom formatters in `src/lib/formatters.ts` — these are Brazil-specific, not locale-dependent.
3. **Never** use `toLocaleDateString()` or `Intl.DateTimeFormat` directly. Use `useFormatter()`.
4. **Never** format dates as strings on the backend. Pass ISO 8601 strings, format in the UI.
5. Currency is **always BRL** (`R$`) unless multi-currency is explicitly added.

---

## 8. Pluralization

```json
{
  "fiscal": {
    "queryCount": "Nenhuma consulta encontrada|{count} consulta encontrada|{count} consultas encontradas"
  }
}
```

```tsx
const t = useTranslations('fiscal');

// 0 → "Nenhuma consulta encontrada"
// 1 → "1 consulta encontrada"
// 5 → "5 consultas encontradas"
t('queryCount', { count: totalElements });
```

### Rules

1. Pluralization uses the pipe `|` separator: `zero|one|other`.
2. **Always** handle the zero case explicitly (empty state message).
3. The `{count}` variable is interpolated automatically.

---

## 9. Enum/Status Translations

Backend enums are translated in the frontend using a convention:

```tsx
// Translate a backend status enum
const t = useTranslations('fiscal.status');

const statusLabel = t(query.status);
// 'PENDING' → 'Pendente'
// 'COMPLETED' → 'Concluído'
// 'ERROR' → 'Erro'
```

### Helper for Type-Safe Enum Translation

```tsx
// src/lib/i18n-helpers.ts
import { useTranslations } from 'next-intl';

export const useEnumTranslation = (namespace: string) => {
  const t = useTranslations(namespace);

  return (enumValue: string): string => {
    try {
      return t(enumValue);
    } catch {
      console.warn(`Missing translation: ${namespace}.${enumValue}`);
      return enumValue;
    }
  };
};

// Usage:
const translateStatus = useEnumTranslation('fiscal.status');
<span>{translateStatus(query.status)}</span>
```

### Rules

1. Translation keys for enums **must** match the exact backend enum string.
2. Always provide a fallback (raw enum value) if translation is missing.
3. Group enum translations under `module.status` or `module.type` namespace.

---

## 10. Testing i18n

### Unit Tests — Provide Messages

```tsx
// src/test/helpers/renderWithProviders.tsx
import { NextIntlClientProvider } from 'next-intl';
import commonMessages from '@/i18n/messages/pt-BR/common.json';
import fiscalMessages from '@/i18n/messages/pt-BR/fiscal.json';

const messages = { ...commonMessages, ...fiscalMessages };

// Add to the existing Wrapper:
const Wrapper = ({ children }: { children: React.ReactNode }) => (
  <NextIntlClientProvider locale="pt-BR" messages={messages}>
    <QueryClientProvider client={queryClient}>
      <AuthContext.Provider value={authValue}>
        {children}
      </AuthContext.Provider>
    </QueryClientProvider>
  </NextIntlClientProvider>
);
```

### Rules

1. Tests **must** wrap components with `NextIntlClientProvider`.
2. Use real `pt-BR` message files in tests — ensures translations are correct.
3. Test that user-facing text matches expected translations (not raw keys).
