---
document_id: "ADR-0013"
primary_nature: "Decisao"
objective: "Registrar a decisão arquitetural “Arquitetura e Gerenciamento de Estado do Frontend (Next.js / React)”, seus motivadores, alternativas e consequências."
scope: "Decisão, componentes, integrações e limites explicitamente descritos em “Arquitetura e Gerenciamento de Estado do Frontend (Next.js / React)”."
non_objectives: "Não implementar a decisão, substituir requisitos relacionados nem atestar capabilities ou ambientes sem evidência explícita."
owner: "@AgentOrchestrator, @FrontendWeb"
status: "Accepted"
date: "2026-04-17"
version: "1.2"
keywords: "adr, decisao, arquitetura, arquitetura, e, gerenciamento, de, estado, do, frontend, next, js, react"
related_files: "projects/frontend/docs/adrs/README.md, projects/backend/docs/adrs/ADR-0001-technology-stack-and-architecture.md, projects/backend/docs/adrs/ADR-0005-multi-tenancy-architecture.md, projects/backend/docs/adrs/ADR-0009-dynamic-rbac-evolution.md, projects/backend/docs/adrs/ADR-0010-tenant-plan-parametrization.md, projects/backend/docs/adrs/ADR-0011-resilience-retry-circuit-breaker.md, projects/backend/docs/adrs/ADR-0012-error-handling-observability.md"
code_references: "useQuery"
principal_statement: "O frontend será construído com **Next.js 16 (App Router)** como meta-framework, seguindo uma **Arquitetura Orientada a Features** para organização de código. O gerenciamento de estado seguirá a separação estrita: **TanStack Query** para server state (dados da API) e **Zustand** exclusivamente para client state efêmero (UI). Formulários serão gerenciados por **React Hook Form + Zod**, com schema factories que recebem a função de tradução `t()` para mensagens i18n. A autenticação multi-tenant será encapsulada por um `AuthProvider` que gerencia o ciclo de vida do Keycloak e resolve o contexto efetivo: identidades tenant usam exclusivamente a claim assinada `tenant_id`; Super Admin global não envia contexto tenant; somente uma impersonação explícita de Super Admin injeta `X-Tenant-ID` pelo `apiClient`. Erros do backend serão parseados como RFC 7807 (ADR-0012) por um hook `useApiError` centralizado."
---

# ADR-0013 - Arquitetura e Gerenciamento de Estado do Frontend (Next.js / React)

- Date: 2026-04-17
- Status: Accepted
- Version: 1.2
- Last updated: 2026-08-22
- Authors / Owners: @AgentOrchestrator, @FrontendWeb
- Reviewers: @CleanArchitecture, @DomainExpert, @ImplementerCore, @SecurityOAuth
- Stakeholders: Engineering Team, Product Owner, Startup Founders

---

# 1. Context

O Contador Fiscal Inteligente possui ADRs que detalham minuciosamente a arquitetura do backend (ADR-0001 a ADR-0012), mas o frontend foi tratado apenas como "será React" (ADR-0001). Após meses de desenvolvimento iterativo, o frontend evoluiu organicamente para **Next.js 16 (App Router) + React 19 + TypeScript + TanStack Query + Zustand + Zod + React Hook Form + next-intl + Keycloak.js + Tailwind CSS v4 + Radix UI**, validado por 16 lições aprendidas documentadas em `docs/delivery/lessons-learned/frontend/`.

**O problema:** Sem um ADR formal, os padrões do frontend estão dispersos em:
- Lições aprendidas (16 documentos de bug fixes e correções reativas)
- Convenções implícitas no código (padrões que surgiram organicamente mas nunca foram declarados)
- Standards de agentes em `/docs/agents/standards/` (api-client-standard, form-validation-standard)

Isso causa riscos concretos:

1. **Inconsistência de estado:** O projeto usa TanStack Query para server state (cache, refetch) E Zustand para client state (sidebar, notifications). Não há uma regra documentada de **quando** usar cada um. Um novo desenvolvedor ou agente IA pode tentar colocar dados do servidor no Zustand.

2. **Schema drift front↔back:** O backend define validações no `DomainException` com `errorCode` e `i18nKey` (ADR-0012), e o frontend define validações no Zod schema com `t('required')`. Sem regra, as validações podem divergir — o frontend pode aceitar um Documento que o backend rejeita.

3. **Diretórios sem padrão:** A estrutura `src/components/` mistura componentes por feature (`certificates/`, `clients/`) com componentes por camada (`ui/`, `shared/`, `layout/`). Não está claro onde um novo componente deve residir.

4. **Keycloak multi-tenant desprotegido:** A sessão Keycloak é inicializada por realm (ADR-0005), e o `apiClient.ts` extrai `tenant_id` do JWT. Mas não há regra formal sobre como o frontend deve reagir a mudanças de tenant (Super Admin alternando entre tenants), expiração de sessão, ou conflitos de token.

5. **Provider hell potencial:** O `Providers.tsx` define a hierarquia: QueryClient → Auth → Intl → Toast. Se novos providers forem adicionados (Theme, Tenant, FeatureFlags), sem regra formal o arquivo vira inmantenível.

**Stack atual consolidada (de fato):**

| Categoria | Tecnologia | Versão | Uso |
|---|---|---|---|
| Framework | Next.js (App Router) | 16.2.1 | SSR, routing, layouts, middleware |
| UI Library | React | 19.2.4 | Components, hooks |
| Linguagem | TypeScript | 5.x | Type safety |
| Server State | TanStack Query | 5.95.2 | Data fetching, cache, mutations |
| Client State | Zustand | 5.0.12 | UI state local (sidebar, notifications) |
| Forms | React Hook Form | 7.72.1 | Form state, submission |
| Validation | Zod | 4.3.6 | Schema validation (frontend) |
| i18n | next-intl | 4.8.3 | Internacionalização |
| Auth | keycloak-js | 26.2.3 | OAuth2, JWT, sessions |
| Styling | Tailwind CSS | 4.x | Utility-first CSS |
| UI Primitives | Radix UI | vários | Accessible headless components |
| Icons | Lucide React | 1.7.0 | Icon library |
| HTTP Client | fetch (nativo) | - | Via `apiClient.ts` wrapping |
| Testing (Unit) | Vitest + Testing Library | 3.x + 16.x | Unit e componente |
| Testing (E2E) | Playwright | 1.x | End-to-end |
| Mocking | MSW | 2.x | Mock Service Worker |
| Linting | ESLint 9 + Prettier | 9.x + 3.x | Code quality |

Restrições:

- Multi-tenancy: frontend opera sob Keycloak realm-per-tenant (ADR-0005). Super Admin pode atuar cross-tenant.
- RBAC: 3 roles de sistema fixas (`ROLE_SUPER_ADMIN`, `ROLE_TENANT_ADMIN`,
  `ROLE_TENANT_AUDIT`) com possibilidade de evolução dinâmica (ADR-0009). O frontend usa a
  política de roles efetivas para menu, rota e landing; Audit é um entitlement dedicado,
  read-only e condicionado a tenant efetivo, nunca herdado de Admin/Super Admin.
- RFC 7807: backend retorna erros em `application/problem+json` (ADR-0012). O frontend DEVE parsear esse formato.
- i18n obrigatório: toda string visível ao usuário DEVE ser internacionalizada (pt-BR como default, preparado para en-US).
- Acessibilidade: componentes DEVEM usar Radix UI como base para WCAG 2.1 AA compliance.
- Zero cloud cost: sem Vercel, Netlify ou serviço de deploy frontend. Build estático servido por Nginx/Caddy na VPS (ADR-0001).

---

# 2. Decision Statement

O frontend será construído com **Next.js 16 (App Router)** como meta-framework, seguindo uma **Arquitetura Orientada a Features** para organização de código. O gerenciamento de estado seguirá a separação estrita: **TanStack Query** para server state (dados da API) e **Zustand** exclusivamente para client state efêmero (UI). Formulários serão gerenciados por **React Hook Form + Zod**, com schema factories que recebem a função de tradução `t()` para mensagens i18n. A autenticação multi-tenant será encapsulada por um `AuthProvider` que gerencia o ciclo de vida do Keycloak e resolve o contexto efetivo: identidades tenant usam exclusivamente a claim assinada `tenant_id`; Super Admin global não envia contexto tenant; somente uma impersonação explícita de Super Admin injeta `X-Tenant-ID` pelo `apiClient`. Erros do backend serão parseados como RFC 7807 (ADR-0012) por um hook `useApiError` centralizado.

---

# 3. Decision Drivers

- **Separação clara Server State vs Client State:** TanStack Query gerencia dados do servidor (cache, stale time, background refetch, optimistic updates). Zustand gerencia estado local da UI (sidebar aberta/fechada, notificações temporárias). Misturar os dois causa bugs de cache stale e re-renders desnecessários.
- **Feature-first architecture:** Escalar a codebase por features (fiscal, billing, certificates) isola contextos e facilita remoção/refatoração de módulos inteiros.
- **Validação unificada front↔back:** Zod schemas no frontend espelham as regras do backend. Schema factories (`createTenantSchema(t)`) garantem i18n nas mensagens de erro de validação.
- **Tipo-safety end-to-end:** TypeScript strict mode garante type safety do DTO da API até o JSX renderizado.
- **Multi-tenancy no frontend:** O `AuthProvider` resolve a claim `tenant_id` do JWT para identidade tenant e mantém Super Admin global sem tenant efetivo. O `apiClient` não replica a claim em header; `X-Tenant-ID` é emitido somente quando um Super Admin selecionou explicitamente um tenant para impersonação.
- **Acessibilidade by default:** Radix UI primitives fornecem ARIA attributes, keyboard navigation e focus management.
- **i18n first-class:** next-intl com namespaces por feature garante que toda string é traduzível. Sem strings hardcoded.
- **Contrato RFC 7807:** O frontend trata erros do backend via o formato padronizado definido no ADR-0012, usando `errorCode` para lógica e `i18nKey` para mensagem ao usuário.

---

# 4. Considered Options

## Option 1: Next.js App Router + Feature Architecture + TanStack/Zustand Split (Selecionada)

Description: Next.js 16 com App Router para SSR/SSG e routing file-based. Arquitetura orientada a features para organização de código. TanStack Query para server state, Zustand para client state. React Hook Form + Zod para formulários. next-intl para i18n.

Pros:
- App Router fornece layouts aninhados, loading/error boundaries, e server components nativamente
- Feature-first mantém coesão por domínio de negócio
- TanStack Query é o padrão de mercado para server state em React — cache, deduplação, background refetch
- Zustand é leve (~1KB) e funcional — sem boilerplate de Redux
- Zod schema factories com `t()` garantem i18n + validação unificada
- next-intl integra nativamente com Next.js App Router

Cons:
- Next.js 16 é bleeding-edge — menos documentação comunitária que 14/15
- App Router tem complexidades de Server vs Client Components que exigem disciplina (lessons learned: LL-FE-00004, LL-FE-00007)
- Dual-state (TanStack + Zustand) requer regras claras para evitar confusão

## Option 2: Vite + React SPA (sem SSR)

Description: Build SPA puro com Vite. Sem server-side rendering. React Router para routing.

Pros:
- Build simples, sem complexidade de SSR
- Menor curva de aprendizado
- Vite é mais rápido em dev mode

Cons:
- Sem SSR/SSG — pior SEO e first-load performance (aceitável para dashboard B2B, mas limitante para páginas públicas futuras)
- Sem file-based routing — React Router requer configuração manual
- Sem layouts aninhados nativos — precisaria implementar manualmente
- Perde Server Components — todo bundle JS vai para o client

## Option 3: Next.js Pages Router (Legacy)

Description: Usar o Pages Router do Next.js ao invés do App Router.

Pros:
- API mais estável e documentada
- Communidade maior com exemplos

Cons:
- Pages Router é considerado legacy pelo Next.js team — investimento em feature-set parou
- Sem React Server Components, Streaming SSR, parallel routing
- Pattern de data fetching (`getServerSideProps`) é mais verboso que o App Router

## Option 4: Remix / React Router v7

Description: Usar Remix como meta-framework.

Pros:
- Data loading patterns elegantes (loader/action)
- Form handling progressivo (funciona sem JS)

Cons:
- Ecossistema menor que Next.js
- Equipe sem experiência
- Menor integração com Vercel/deploy ecosystem (menos relevante dada a VPS — ADR-0001)
- Menos libraries e plugins comunitários

---

# 5. Decision Outcome

**Option 1 (Next.js App Router + Feature Architecture + TanStack/Zustand Split)** foi selecionada.

Fatores decisivos:

- **Já é a stack em produção:** O projeto já usa Next.js 16 + TanStack + Zustand + Zod + RHF + next-intl. Este ADR formaliza e documenta as decisões que foram tomadas iterativamente e validadas por 16 lições aprendidas.
- **App Router é o futuro do Next.js:** Server Components reduzem o bundle JS enviado ao client. Layouts aninhados eliminam re-renders de shells comuns. Loading/Error boundaries por rota são built-in.
- **TanStack Query é o padrão consolidado:** Cache automático, deduplicação de requests, background refetch, optimistic updates — tudo out-of-the-box. A alternativa (fetch manual + useState) é propensa a bugs de race condition e stale data.
- **Zustand para UI state é minimal:** Sidebar open/close, notification queue — estado efêmero que não vem do servidor. ~1KB de bundle. Sem boilerplate de actions/reducers.
- **Zod + RHF + i18n é validado:** O padrão de schema factory (`createTenantSchema(t)`) já funciona e foi documentado em standards e lessons learned.

Trade-offs aceitos:

- Next.js 16 App Router tem complexidades de Server vs Client Components. Mitigado por: diretivas `'use client'` explícitas, lições aprendidas documentadas (LL-FE-00004, LL-FE-00007), e regra "quando em dúvida, use Client Component".
- Dual-state (TanStack + Zustand) requer disciplina. Mitigado por este ADR com regras explícitas de "onde colocar o quê".

---

# 6. Consequences

Positive Consequences:

- Estrutura de pastas previsível — novos desenvolvedores e agentes IA sabem exatamente onde criar componentes, hooks, schemas e services para cada feature.
- Server state nunca fica stale silenciosamente — TanStack Query com `staleTime` configurado por entidade garante refetch automático.
- Formulários são tipo-safe e i18n-ready by default — Zod infere o tipo TypeScript do schema; mensagens de validação vêm do `t()`.
- Erros do backend são tratados uniformemente — `useApiError` parseia RFC 7807 e mapeia para toast/form errors.
- UI state é isolado e não persiste indevidamente — Zustand stores são efêmeros (resetam no refresh). Dados que devem persistir estão no servidor (via TanStack Query).

Negative Consequences:

- O projeto depende do ecossistema Next.js (Vercel). Mitigação: deploy self-hosted via `next start` em container Docker (ADR-0001).
- Server Components adicionam complexidade cognitiva (onde colocar `'use client'`). Mitigação: regra explícita neste ADR + lições aprendidas.
- TanStack Query DevTools adicionam ~20KB ao bundle de desenvolvimento. Mitigação: carregados apenas em `NODE_ENV=development` via `@tanstack/react-query-devtools`.

Neutral Consequences:

- Toda nova feature requer criar a pasta correspondente na estrutura de diretórios padronizada.
- MSW handlers devem ser criados por feature para testes isolados.

---

# 7. Impact

## 7.1 Arquitetura de Diretórios — Feature-First

```
frontend/src/
├── app/                          # Next.js App Router — APENAS routing e layouts
│   ├── (public)/                 # Route group: páginas públicas (login, landing)
│   │   └── login/
│   │       └── page.tsx
│   ├── (dashboard)/              # Route group: painel autenticado
│   │   ├── layout.tsx            # Shell: Sidebar + Header + Main
│   │   ├── loading.tsx           # Skeleton global do dashboard
│   │   ├── error.tsx             # Error boundary do dashboard
│   │   ├── dashboard/
│   │   │   └── page.tsx          # Home do dashboard
│   │   ├── tenants/
│   │   │   ├── page.tsx          # Lista de tenants
│   │   │   └── [id]/
│   │   │       └── page.tsx      # Detalhe do tenant
│   │   ├── fiscal/
│   │   │   ├── page.tsx          # Consultas fiscais
│   │   │   └── [id]/
│   │   │       └── page.tsx      # Detalhe da consulta
│   │   ├── certificates/
│   │   │   └── page.tsx
│   │   ├── billing/
│   │   │   └── page.tsx
│   │   ├── clients/
│   │   │   └── page.tsx
│   │   └── profile/
│   │       └── page.tsx
│   ├── layout.tsx                # Root layout: <html>, <body>, <Providers>
│   ├── error.tsx                 # Root error boundary
│   ├── loading.tsx               # Root loading
│   ├── not-found.tsx             # 404 page
│   └── globals.css               # CSS global + Tailwind
│
├── components/                    # Componentes organizados por camada
│   ├── ui/                        # Design system primitives (Button, Input, Dialog, Select, Toast)
│   │   ├── Button.tsx             # Wrapper sobre Radix + CVA
│   │   ├── Input.tsx
│   │   ├── Dialog.tsx
│   │   ├── Select.tsx
│   │   ├── Toast.tsx
│   │   └── DataTable.tsx
│   ├── layout/                    # Shell components (Sidebar, Header, Breadcrumbs)
│   │   ├── Sidebar.tsx
│   │   ├── Header.tsx
│   │   └── Breadcrumbs.tsx
│   ├── shared/                    # Compostos reutilizáveis cross-feature
│   │   ├── ConfirmDialog.tsx
│   │   ├── EmptyState.tsx
│   │   ├── ErrorFallback.tsx
│   │   └── PageHeader.tsx
│   └── features/                  # Compostos específicos por feature
│       ├── tenants/
│       │   ├── TenantForm.tsx
│       │   ├── TenantTable.tsx
│       │   └── TenantDetailCard.tsx
│       ├── fiscal/
│       │   ├── FiscalQueryForm.tsx
│       │   ├── FiscalQueryTable.tsx
│       │   ├── FiscalQueryDetailModal.tsx
│       │   ├── DarfCard.tsx
│       │   ├── ServiceStatusBanner.tsx
│       │   └── FiscalUsageAlert.tsx
│       ├── certificates/
│       │   ├── CertificateUploadForm.tsx
│       │   └── CertificateTable.tsx
│       ├── billing/
│       │   ├── PlanCard.tsx
│       │   ├── InvoiceTable.tsx
│       │   └── UsageSummary.tsx
│       └── clients/
│           ├── ClientForm.tsx
│           └── ClientTable.tsx
│
├── hooks/                         # Custom hooks
│   ├── queries/                   # TanStack Query hooks (server state)
│   │   ├── useTenantQueries.ts
│   │   ├── useCertificateQueries.ts
│   │   ├── useClientQueries.ts
│   │   ├── useFiscalQueries.ts    # (futuro)
│   │   └── useBillingQueries.ts   # (futuro)
│   ├── useAuth.ts                 # Keycloak/auth context
│   ├── usePermission.ts           # RBAC hook
│   ├── useModuleAccess.ts         # Module-level access control
│   ├── useTenant.ts               # Tenant context extraction
│   ├── useToast.ts                # Toast notifications
│   ├── useBreadcrumbs.ts          # Dynamic breadcrumbs
│   └── useApiError.ts             # RFC 7807 error parser (ADR-0012)
│
├── schemas/                       # Zod validation schemas (factories)
│   ├── tenantSchemas.ts
│   ├── certificateSchemas.ts
│   ├── clientSchemas.ts
│   ├── fiscalSchemas.ts           # (futuro)
│   └── billingSchemas.ts          # (futuro)
│
├── services/                      # API service functions (thin layer sobre apiClient)
│   ├── tenantService.ts
│   ├── certificateService.ts
│   ├── clientService.ts
│   ├── fiscalService.ts           # (futuro)
│   └── billingService.ts          # (futuro)
│
├── providers/                     # React Context Providers
│   ├── Providers.tsx              # Root wrapper (nesting order defined)
│   ├── AuthProvider.tsx           # Keycloak lifecycle
│   └── QueryProvider.tsx          # TanStack QueryClient config
│
├── stores/                        # Zustand stores (CLIENT STATE ONLY)
│   ├── useSidebarStore.ts
│   └── useNotificationStore.ts
│
├── lib/                           # Utility functions e configurações
│   ├── apiClient.ts               # HTTP client wrapper (fetch + auth + tenant)
│   ├── apiError.ts                # Error classes (ApiError, ValidationError, etc.)
│   ├── queryKeys.ts               # Query key factory (createQueryKeys)
│   ├── paths.ts                   # Route path constants + builders
│   ├── permissions.ts             # Permission constants
│   ├── protected-routes.ts        # Route protection config
│   ├── menu-config.ts             # Sidebar menu structure (RBAC-aware)
│   ├── menu-utils.ts              # Menu filtering utilities
│   ├── keycloak.ts                # Keycloak instance
│   ├── keycloak-config.ts         # Keycloak config
│   ├── env.ts                     # Environment variables (typed)
│   ├── cn.ts                      # Class name merger (clsx + tailwind-merge)
│   ├── formatters.ts              # Date, currency, Documento formatters
│   └── msw-init.ts                # MSW initialization (dev only)
│
├── i18n/                          # Internacionalização
│   ├── config.ts                  # Locale config
│   ├── request.ts                 # next-intl request handler
│   └── messages/
│       ├── pt-BR/                  # Português (default)
│       │   ├── common.json
│       │   ├── dashboard.json
│       │   ├── tenants.json
│       │   ├── fiscal.json
│       │   ├── certificates.json
│       │   ├── billing.json
│       │   ├── clients.json
│       │   └── validation.json    # Mensagens de validação de forms
│       └── en-US/                  # (futuro)
│           └── ...
│
├── types/                         # TypeScript type definitions
│   ├── tenant.ts                  # Tenant DTOs
│   ├── certificate.ts             # Certificate DTOs
│   ├── client.ts                  # Client DTOs
│   ├── fiscal.ts                  # Fiscal DTOs (futuro)
│   ├── billing.ts                 # Billing DTOs (futuro)
│   ├── auth.ts                    # Auth/JWT types
│   └── api.ts                     # API response wrappers (PaginatedResponse, etc.)
│
├── styles/                        # CSS modules e overrides
│   └── ...
│
├── mocks/                         # MSW handlers (test doubles)
│   ├── handlers/
│   │   ├── tenantHandlers.ts
│   │   ├── certificateHandlers.ts
│   │   └── clientHandlers.ts
│   └── browser.ts
│
├── test/                          # Test utilities e setup
│   └── setup.ts
│
└── middleware.ts                   # Next.js middleware (locale, auth redirect)
```

**Regras de diretório:**

| Diretório | O que vai aqui | O que NÃO vai aqui |
|---|---|---|
| `app/` | Apenas `page.tsx`, `layout.tsx`, `loading.tsx`, `error.tsx` do Next.js routing | Lógica de negócio, componentes reutilizáveis, hooks |
| `components/ui/` | Design system primitives (1 componente = 1 arquivo) | Componentes com lógica de negócio |
| `components/shared/` | Compostos reutilizáveis em 2+ features | Componentes usados em apenas 1 feature |
| `components/features/{feature}/` | Compostos específicos de 1 feature | Componentes genéricos |
| `hooks/queries/` | Hooks TanStack Query (useQuery, useMutation) | Hooks de UI pura (useSidebar) |
| `stores/` | Zustand stores para client state efêmero | Dados que vêm do servidor (usar TanStack Query) |
| `schemas/` | Zod schema factories com `t()` | Schemas sem i18n, schemas que duplicam o backend |
| `services/` | Funções de API pura (get, create, update, delete) | Lógica de UI, hooks, gerenciamento de cache |
| `types/` | DTOs e interfaces TypeScript | Implementações, classes, lógica |
| `lib/` | Utilities puras, configurações, constants | Componentes React, hooks com state |

## 7.2 Gerenciamento de Estado — Regra de Alocação

```
┌──────────────────────────────────────────────────────────┐
│                    FONTE DE VERDADE                       │
├──────────────────────────────────────────────────────────┤
│                                                          │
│  SERVER STATE (dados da API backend)                     │
│  ► Engine: TanStack Query                                │
│  ► Exemplos: lista de tenants, certificados, consultas   │
│    fiscais, faturas, dados do perfil do usuário          │
│  ► Cache: automático com staleTime e gcTime por entidade │
│  ► Mutations: optimistic updates + invalidation seletiva │
│  ► Regra: SE o dado vem de uma API → TanStack Query      │
│                                                          │
├──────────────────────────────────────────────────────────┤
│                                                          │
│  CLIENT STATE (UI efêmero, não persiste no servidor)     │
│  ► Engine: Zustand                                       │
│  ► Exemplos: sidebar open/close, notification queue,     │
│    form wizard step, modal visibility, theme preference  │
│  ► Regra: SE o dado é local ao browser e efêmero         │
│           → Zustand                                      │
│  ► PROIBIDO: colocar dados do servidor no Zustand        │
│                                                          │
├──────────────────────────────────────────────────────────┤
│                                                          │
│  URL STATE (estado visível e compartilhável)             │
│  ► Engine: Next.js searchParams / useRouter              │
│  ► Exemplos: filtros de tabela, paginação, aba ativa,    │
│    ID do recurso selecionado                             │
│  ► Regra: SE o estado deve sobreviver a refresh e ser    │
│           compartilhável via link → URL searchParams     │
│                                                          │
├──────────────────────────────────────────────────────────┤
│                                                          │
│  FORM STATE (dados de formulário em edição)              │
│  ► Engine: React Hook Form                               │
│  ► Validação: Zod (via @hookform/resolvers/zod)          │
│  ► Regra: SE o dado é input do usuário em um formulário  │
│           → React Hook Form + Zod schema                 │
│                                                          │
└──────────────────────────────────────────────────────────┘
```

**Decisão tree para devs e agentes IA:**

```
O dado vem do backend via API?
  ├── SIM → TanStack Query (useQuery/useMutation)
  └── NÃO
      O dado é input do usuário em formulário?
      ├── SIM → React Hook Form + Zod schema
      └── NÃO
          O dado deve ser compartilhável via URL?
          ├── SIM → searchParams (URL state)
          └── NÃO → Zustand store (ephemeral UI state)
```

## 7.3 TanStack Query — Configuração e Padrões

**QueryClient global:**

```typescript
// providers/QueryProvider.tsx
const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      staleTime: 5 * 60 * 1000,      // 5 minutos — dados fresh por 5 min
      gcTime: 30 * 60 * 1000,         // 30 minutos — garbage collect após 30 min
      refetchOnWindowFocus: true,      // Refetch ao voltar para a aba
      retry: 1,                        // 1 retry em falha transitória
      refetchOnReconnect: true,        // Refetch ao reconectar internet
    },
    mutations: {
      retry: 0,                        // Mutations nunca auto-retry
    },
  },
});
```

**Query Key Factory (padrão obrigatório):**

```typescript
// lib/queryKeys.ts
export const createQueryKeys = (entity: string) => ({
  all: [entity] as const,
  lists: () => [entity, 'list'] as const,
  list: (filters: Record<string, unknown>) => [entity, 'list', filters] as const,
  details: () => [entity, 'detail'] as const,
  detail: (id: string) => [entity, 'detail', id] as const,
});

// hooks/queries/useTenantQueries.ts
const tenantKeys = createQueryKeys('tenant');
```

**Invalidação seletiva (LL-FE-00013):**

```typescript
// Após mutation de criação:
onSuccess: () => {
  queryClient.invalidateQueries({ queryKey: tenantKeys.lists() }); // ✅ Invalida listas
  // NÃO usar: queryClient.invalidateQueries({ queryKey: tenantKeys.all }); // ❌ Invalida TUDO
};
```

## 7.4 Formulários — React Hook Form + Zod + i18n

**Padrão: Schema Factory com função de tradução:**

```typescript
// schemas/tenantSchemas.ts
type TValidation = (key: string, params?: Record<string, string | number>) => string;

export const createTenantSchema = (t: TValidation) =>
  z.object({
    name: z.string().min(1, t('required')).max(150, t('maxLength', { max: 150 })),
    taxId: z.string().min(1, t('required')).regex(Documento_REGEX, t('documentoFormat')),
    email: z.string().min(1, t('required')).email(t('email')),
    // ...
  });

// Uso no componente:
const t = useTranslations('validation');
const schema = createTenantSchema(t);
const form = useForm({ resolver: zodResolver(schema) });
```

**Regras:**

1. **Schema = factory function** — recebe `t()` e retorna o Zod schema. Nunca criar schema no top-level sem i18n.
2. **Tipo inferido** — `type CreateTenantFormData = z.infer<ReturnType<typeof createTenantSchema>>`. Nunca criar tipo manualmente.
3. **Validação no client é UX, não segurança** — o backend SEMPRE revalidará (DomainException, ADR-0012). O Zod existe para dar feedback imediato ao usuário.
4. **Erros do backend mapeados ao form** — quando o backend retorna RFC 7807 com `violations[]`, o `useApiError` hook mapeia `field → setError()` do RHF.

## 7.5 Internacionalização (i18n) — next-intl

**Estrutura de namespaces (1 arquivo JSON por feature):**

```
i18n/messages/pt-BR/
├── common.json         # Rótulos globais: "Salvar", "Cancelar", "Carregando..."
├── validation.json     # Mensagens de validação: "Campo obrigatório", "Documento inválido"
├── dashboard.json      # Textos do dashboard home
├── tenants.json        # Textos da feature tenants
├── fiscal.json         # Textos da feature fiscal
├── certificates.json   # Textos da feature certificates
├── billing.json        # Textos da feature billing
└── clients.json        # Textos da feature clients
```

**Regras:**

1. **Nenhuma string hardcoded** — todo texto visível ao usuário vem do `useTranslations(namespace)`.
2. **Namespace por feature** — `useTranslations('tenants')` no componente TenantTable.
3. **`validation.json` é transversal** — usado por Zod schema factories em todas as features.
4. **Fallback para pt-BR** — se a chave não existir em `en-US`, cai para `pt-BR`.
5. **Valores dinâmicos** — usar interpolação: `t('maxLength', { max: 150 })` → "Máximo de 150 caracteres".

## 7.6 Autenticação Multi-Tenant — Keycloak Integration

**Fluxo de autenticação no frontend:**

```
┌────────────┐     ┌──────────────────┐     ┌───────────────────┐
│  Browser   │────▶│  Next.js App     │────▶│  Keycloak         │
│            │     │  (middleware.ts)  │     │  (realm=tenant)   │
│            │     │                  │     │                   │
│  page.tsx  │◀────│  AuthProvider     │◀────│  JWT Token        │
│  render    │     │  keycloak.init()  │     │  {tenant_id,      │
│            │     │  updateToken()    │     │   roles, sub}     │
└────────────┘     └──────────────────┘     └───────────────────┘
                          │
                          ▼
                   ┌──────────────────┐
                   │  apiClient.ts    │
                   │  Authorization:  │
                   │  Bearer {token}  │
                   │  X-Tenant-ID:    │
                   │  only explicit  │
                   │  Super Admin    │
                   │  impersonation  │
                   └──────────────────┘
```

Para identidade tenant, o backend deriva o contexto da claim assinada `tenant_id` e o cliente
não envia o header. Para Super Admin global, não há tenant efetivo nem header.

**Provider hierarchy (ordem obrigatória):**

```tsx
// providers/Providers.tsx
<QueryProvider>          {/* 1. Query cache — disponível em todos os providers abaixo */}
  <AuthProvider>         {/* 2. Auth — Keycloak init, token lifecycle */}
    <NextIntlClientProvider> {/* 3. i18n — traduções disponíveis em toda a app */}
      {children}
      <Toaster />        {/* 4. Toast — notificações (usa i18n) */}
    </NextIntlClientProvider>
  </AuthProvider>
</QueryProvider>
```

**Regras de provider:**

1. **Novos providers** DEVEM ser inseridos nesta hierarquia com aprovação de @FrontendWeb.
2. **QueryProvider** é sempre o mais externo — garante que auth e i18n hooks possam usar useQuery se necessário.
3. **Theme/FeatureFlags providers** (futuro) entrarão entre AuthProvider e NextIntlClientProvider.

## 7.7 Tratamento de Erros no Frontend — RFC 7807

**Integração com ADR-0012:**

```typescript
// hooks/useApiError.ts (a ser implementado)
import { useTranslations } from 'next-intl';
import { useToast } from '@/hooks/useToast';

interface ProblemDetail {
  type: string;
  title: string;
  status: number;
  detail: string;
  instance: string;
  timestamp: string;
  traceId: string;
  tenantId: string | null;
  errorCode: string;
  i18nKey: string;
  violations: { field: string; message: string; i18nKey: string; rejectedValue: unknown }[];
}

export function useApiError() {
  const t = useTranslations('errors');
  const { toast } = useToast();

  const handleError = (error: unknown) => {
    if (error instanceof ValidationError) {
      // Mapear violations para React Hook Form setError
      return { fieldErrors: error.fieldErrors };
    }
    if (error instanceof ApiError) {
      // Parsear RFC 7807 body
      const problem: ProblemDetail = JSON.parse(error.body);
      toast({
        variant: 'destructive',
        title: t(problem.i18nKey, { default: problem.title }),
        description: `Código: ${problem.traceId}`,
      });
    }
    // ... NetworkError, AuthError handlers
  };

  return { handleError };
}
```

## 7.8 Regras de Server Components vs Client Components

| Cenário | Tipo | Diretiva |
|---|---|---|
| `page.tsx` simples sem interatividade | Server Component | nenhuma |
| `page.tsx` com hooks (useState, useQuery) | Client Component | `'use client'` |
| `layout.tsx` com apenas children | Server Component | nenhuma |
| Componente com form (React Hook Form) | Client Component | `'use client'` |
| Componente com onClick/onChange handlers | Client Component | `'use client'` |
| Loading skeleton (sem hooks) | Client Component | `'use client'` (LL-FE-00004) |
| Error boundary | Client Component | `'use client'` (LL-FE-00003) |
| `Providers.tsx` | Client Component | `'use client'` (LL-FE-00007) |

**Regra geral:** Na dúvida, use `'use client'`. Server Components são uma otimização — Client Components são o default seguro.

---

# 8. AI Agent Considerations (For Autonomous Agent Environments)

Agent Roles Impacted:

- **@FrontendWeb:** Owner principal. Implementa componentes, hooks, schemas e services seguindo este ADR. Todo código frontend DEVE seguir a arquitetura de diretórios e padrões definidos aqui.
- **@ImplementerCore:** Ao criar endpoints backend, DEVE criar o DTO TypeScript correspondente em `types/` e o service function em `services/`.
- **@CleanArchitecture:** Valida que server state está em TanStack Query e client state em Zustand. Nunca o inverso.
- **@DomainExpert:** Valida que Zod schemas no frontend espelham as regras de validação do backend domain.

Operational Considerations:

- Ao criar um novo módulo/feature, o agente DEVE criar a pasta completa: `components/features/{feature}/`, `hooks/queries/use{Feature}Queries.ts`, `schemas/{feature}Schemas.ts`, `services/{feature}Service.ts`, `types/{feature}.ts`, `i18n/messages/pt-BR/{feature}.json`.
- Ao criar um novo formulário, o agente DEVE usar o padrão schema factory: `create{Entity}Schema(t: TValidation)`.
- Ao criar uma nova query, o agente DEVE usar `createQueryKeys` do `lib/queryKeys.ts`.
- Ao tratar erros de mutation, o agente DEVE usar o hook `useApiError` para parsear RFC 7807.

LLM Considerations:

- Prompts de geração de código frontend DEVEM incluir o contexto deste ADR para evitar que o agente crie patterns incompatíveis (ex: `useState` para server state, strings hardcoded, schemas sem i18n).
- O agente deve verificar `docs/delivery/lessons-learned/frontend/README.md` antes de implementar padrões que envolvam Tailwind v4, Radix Select, Suspense boundaries ou MSW — há armadilhas documentadas.

Safety Considerations:

- NUNCA armazenar tokens ou secrets no client state (Zustand, localStorage). Tokens residem exclusivamente no Keycloak.js.
- NUNCA expor dados de PII no frontend sem máscara (CPF, Documento) — mesmo em `console.log`.
- Zod validation no frontend é UX, não segurança. O backend SEMPRE revalida (ADR-0012).
- `ROLE_TENANT_AUDIT` autoriza somente `/audit` e `/audit/{conversationId}` quando há tenant
  efetivo. `ROLE_TENANT_ADMIN`/`ROLE_SUPER_ADMIN` não implicam Audit; Super Admin+Audit global
  permanece negado até impersonação explícita de tenant ativo.

---

# 9. Implementation Plan

## Phase 1 — Formalização da Estrutura Existente (Sprint Atual)

- Criar este ADR formalizando decisões já implementadas.
- Reorganizar `components/` para separar `features/` de `ui/` e `shared/`.
- Mover componentes que estão em `components/{feature}/` para `components/features/{feature}/`.
- Responsible: @FrontendWeb

## Phase 2 — useApiError e RFC 7807 Integration (Sprint N)

- Implementar hook `useApiError` que parseia `application/problem+json`.
- Atualizar `apiClient.ts` (handleErrorResponse) para extrair campos RFC 7807.
- Mapear `violations[]` do RFC 7807 para `form.setError()` do React Hook Form.
- Responsible: @FrontendWeb

## Phase 3 — Schemas para Módulos Faltantes (Sprint N+1)

- Criar `fiscalSchemas.ts`, `billingSchemas.ts`, `certificateSchemas.ts`.
- Garantir que todos seguem o padrão schema factory com `t()`.
- Responsible: @FrontendWeb, @DomainExpert

## Phase 4 — Preparação para en-US (Sprint N+2)

- Criar estrutura `i18n/messages/en-US/` com traduções dos JSONs existentes.
- Implementar locale switcher no header.
- Testar fallback pt-BR → en-US.
- Responsible: @FrontendWeb

Dependencies:

- Phase 2 depende de ADR-0012 (backend retornando RFC 7807).
- Phase 3 depende dos módulos backend correspondentes estarem com endpoints definidos.

Rollback Plan:

- Phase 1 (reorganização de pastas) é reversível via git. Nenhuma lógica muda — apenas localização de arquivos.
- Phase 2 (useApiError) é aditivo. Se houver bugs, o fallback é o tratamento de erro atual no `apiClient.ts`.

---

# 10. Validation

Architecture Validation:

- ESLint rules: validar que imports inter-feature não existem (ex: `components/features/billing/` NÃO importa de `components/features/fiscal/`). Features são isoladas.
- ESLint: todo `useQuery`/`useMutation` deve usar chave do `createQueryKeys` — proibir query keys ad-hoc.
- Code review por @FrontendWeb em todo novo componente para verificar alocação correta de diretório.

Type Safety Validation:

- TypeScript strict mode (`strict: true` no tsconfig) garante tipagem em todos os componentes.
- Zod schema infere tipo automaticamente — validar que componentes usam o tipo inferido, não interfaces manuais.

Accessibility Validation:

- `vitest-axe` em todo componente de UI para WCAG 2.1 AA compliance.
- Playwright E2E tests com `axe-playwright` para validação de acessibilidade em páginas completas.

Performance Validation:

- TanStack Query DevTools: verificar que não há queries redundantes (N+1) ou invalidações excessivas.
- Next.js `@next/bundle-analyzer`: verificar que nenhum client component importa libraries server-only.
- Lighthouse score > 80 em Performance, > 90 em Accessibility.

Success Criteria:

- [ ] Estrutura de diretórios segue o padrão Feature-First documentado neste ADR.
- [ ] Todo server state usa TanStack Query. Zero uso de Zustand para dados da API.
- [ ] Todo formulário usa React Hook Form + Zod schema factory com i18n.
- [ ] Erros do backend parseados como RFC 7807 pelo `useApiError`.
- [ ] Nenhuma string hardcoded — 100% internacionalizada via next-intl.
- [ ] Provider hierarchy documentada e testada (LL-FE-00007).
- [ ] Query keys usam `createQueryKeys` factory (LL-FE-00013).

---

# 11. Risks and Mitigations

Risk 1:
Description: Next.js 16 App Router tem breaking changes em versões futuras, forçando refatoração.
Mitigation: Componentes de negócio (features/) não dependem de APIs do Next.js — são Client Components puros. Apenas `app/` depende do App Router. Migração afetaria routing, não lógica de negócio.

Risk 2:
Description: TanStack Query staleTime mal configurado causa dados desatualizados ou requests excessivos.
Mitigation: `staleTime: 5 min` como default seguro. Entidades com alta frequência de mudança (ex: WhatsApp messages) terão staleTime menor (30s). Monitorar via TanStack Query DevTools em desenvolvimento.

Risk 3:
Description: Zod schemas divergem das regras de validação do backend, causando UX confusa (frontend aceita, backend rejeita).
Mitigation: Schema drift é detectado quando o backend retorna RFC 7807 com `errorCode: VALIDATION.FAILED` para dados que o frontend considerou válidos. Tratar esse cenário no `useApiError` (mapear `violations[]` para form errors). Code review cruzado (frontend + backend) em regras de validação.

Risk 4:
Description: Provider nesting order incorreto causa null reference em hooks aninhados (ex: useTranslations fora do IntlProvider).
Mitigation: Order documentado e fixo no `Providers.tsx`. Testes unitários que renderizam Provider tree e verificam que todos os hooks funcionam.

Risk 5:
Description: Super Admin sem `tenant_id` no JWT causa crashes em componentes que assumem tenant sempre presente.
Mitigation: LL-FE-00009 documenta a solução. Hook `useTenant()` retorna `null` para Super Admin. Componentes DEVEM tratar `tenantId === null` como caso válido (Super Admin cross-tenant).

---

# 12. Related ADRs

- [ADR-0001 - Technology Stack and Architecture Foundation](../../../backend/docs/adrs/ADR-0001-technology-stack-and-architecture.md) — Define "React" como frontend. Este ADR concretiza a stack completa.
- [ADR-0005 - Multi-Tenancy Architecture](../../../backend/docs/adrs/ADR-0005-multi-tenancy-architecture.md) — Define Keycloak realm-per-tenant e JWT com `tenant_id`. Este ADR define como o frontend consome a claim para identidades tenant e reserva `X-Tenant-ID` à impersonação explícita de Super Admin.
- [ADR-0009 - Dynamic RBAC Evolution](../../../backend/docs/adrs/ADR-0009-dynamic-rbac-evolution.md) — Define RBAC estático com 3 roles de sistema. Este ADR define a renderização condicional e a política de roles efetivas no frontend.
- [ADR-0010 - Tenant Plan Parametrization](../../../backend/docs/adrs/ADR-0010-tenant-plan-parametrization.md) — Define limites de plano. Este ADR define como o frontend renderiza condicionalmente baseado em limites.
- [ADR-0011 - Resilience Strategy](../../../backend/docs/adrs/ADR-0011-resilience-retry-circuit-breaker.md) — Define fallbacks do backend. Este ADR define como o frontend exibe mensagens de serviço indisponível.
- [ADR-0012 - Error Handling & Observability](../../../backend/docs/adrs/ADR-0012-error-handling-observability.md) — Define RFC 7807 e o contrato frontend↔backend de erros.

---

# 13. References

- [Next.js 16 Documentation](https://nextjs.org/docs)
- [Next.js App Router](https://nextjs.org/docs/app)
- [React 19 Documentation](https://react.dev/)
- [TanStack Query v5 Documentation](https://tanstack.com/query/latest)
- [TanStack Query — Query Key Factory Pattern](https://tkdodo.eu/blog/effective-react-query-keys)
- [Zustand Documentation](https://docs.pmnd.rs/zustand)
- [React Hook Form Documentation](https://react-hook-form.com/)
- [Zod Documentation](https://zod.dev/)
- [next-intl Documentation](https://next-intl-docs.vercel.app/)
- [Radix UI Primitives](https://www.radix-ui.com/primitives)
- [Tailwind CSS v4](https://tailwindcss.com/docs)
- [Keycloak.js Documentation](https://www.keycloak.org/docs/latest/securing_apps/#_javascript_adapter)
- [RFC 7807 — Problem Details for HTTP APIs](https://www.rfc-editor.org/rfc/rfc7807)
- [Bulletproof React — Feature Folder Architecture](https://github.com/alan2207/bulletproof-react)
- [MSW — Mock Service Worker](https://mswjs.io/)
- [Vitest Documentation](https://vitest.dev/)
- [Playwright Documentation](https://playwright.dev/)

---

# 14. Decision Lifecycle

Current State: **Accepted**

Este ADR formaliza e consolida decisões que foram tomadas iterativamente ao longo do desenvolvimento do frontend, validadas por 16 lições aprendidas e 3 meses de uso em produção. Ele transforma convenções implícitas em regras explícitas.

O perfil dedicado de auditoria e sua política de rota foram reconciliados com ADR-0009,
REQ-00003, REQ-00004 e TP-00008. Evidência de runtime Keycloak/backend-real permanece um gate
operacional separado.

---

# 15. Change Log

Version: 1.0
Date: 2026-04-17
Author: @AgentOrchestrator
Changes:
- Initial ADR creation formalizing frontend architecture decisions.
- Documented feature-first directory structure based on existing codebase.
- Formalized state management strategy (TanStack Query vs Zustand vs URL vs RHF).
- Documented i18n pattern with next-intl namespaces and Zod schema factories.
- Documented Keycloak multi-tenant integration pattern.
- Documented RFC 7807 frontend integration with useApiError hook.
- Referenced 16 frontend lessons learned as empirical validation.

Version: 1.1
Date: 2026-08-22
Author: Codex / @FrontendWeb / @SecurityOAuth
Changes:
- Reconciled the third fixed system role `ROLE_TENANT_AUDIT` and its effective-tenant-only
  `/audit` policy; removed the obsolete two-role statement without changing the dynamic-RBAC
  deferral.

Version: 1.2
Date: 2026-08-22
Author: Codex / @FrontendWeb / @SecurityOAuth
Changes:
- Reconciled the three-state tenant contract: tenant JWT claim without a duplicated header,
  Super Admin global without tenant context, and `X-Tenant-ID` only for explicit Super Admin
  impersonation.

---

# 16. Repository Structure

Frontend codebase:

```
frontend/
├── src/
│   ├── app/              # Next.js App Router (routing only)
│   ├── components/       # UI = primitives, shared = cross-feature, features/ = per-feature
│   ├── hooks/            # Custom hooks + queries/
│   ├── schemas/          # Zod schema factories
│   ├── services/         # API functions
│   ├── providers/        # React Context providers
│   ├── stores/           # Zustand stores (client state only)
│   ├── lib/              # Utilities e configs
│   ├── i18n/             # Internacionalizaçã
│   ├── types/            # TypeScript DTOs
│   ├── mocks/            # MSW handlers
│   ├── test/             # Test setup
│   └── styles/           # CSS
├── e2e/                  # Playwright E2E tests
├── package.json
├── tsconfig.json
├── tailwind.config.ts
├── next.config.ts
└── vitest.config.ts
```

---

# 17. Review Process

1. Este ADR foi criado em status "Proposed" por @AgentOrchestrator.
2. Revisores (@FrontendWeb, @CleanArchitecture, @ImplementerCore, @SecurityOAuth) devem validar:
   - A estrutura de diretórios reflete fielmente o código existente.
   - A regra de alocação de estado (TanStack vs Zustand vs URL vs RHF) é clara e completa.
   - O padrão de schema factory com i18n é aplicável a todos os módulos futuros.
   - A provider hierarchy está correta e documentada.
   - O hook `useApiError` é compatível com o formato RFC 7807 do ADR-0012.
3. @DomainExpert deve validar que os Zod schemas espelham corretamente as regras de negócio do backend.
4. Após aprovação, o status muda para "Accepted" e as regras tornam-se mandatórias para todo novo código frontend.

---

# 18. Notes

Este ADR documenta o frontend **como ele é**, não como ele deveria ser em um mundo ideal. As decisões foram validadas empiricamente por:

- 16 lições aprendidas documentadas (bugs corrigidos, patterns anti-fragile estabelecidos)
- 3 módulos implementados (tenants, certificates, clients) com a arquitetura em uso
- 4 módulos planejados (fiscal, billing, whatsapp dashboard, profile) que estenderão a mesma arquitetura

Princípios codificados por este ADR:

- **Feature-first, não layer-first:** Código organizado por domínio de negócio (`tenants/`, `fiscal/`), não por tipo técnico (`controllers/`, `models/`).
- **Server state ≠ client state:** TanStack Query é o cache do servidor. Zustand é o estado da UI. Nunca misturar.
- **Validação é UX, não segurança:** Zod no frontend dá feedback rápido. O backend sempre revalida. O `useApiError` lida com a divergência.
- **i18n é obrigatório, não opcional:** Nenhuma string hardcoded. `validation.json` compartilhado por todos os forms.
- **Lessons learned são ADR empírico:** Cada bug documentado em `docs/delivery/lessons-learned/frontend/` é uma micro-decisão arquitetural validada pela dor.
- **`'use client'` não é um erro:** Server Components são uma otimização. Client Components são o default seguro.
