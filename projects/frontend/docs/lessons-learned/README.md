---
document_id: FRONTEND-LESSONS-INDEX
primary_nature: Historico
objective: Indexar lições transferiveis provenientes do frontend.
scope: UI, acessibilidade, estado, segurança, testes e build frontend.
non_objectives: Nao representar regra vigente sem referência normativa.
owner: Frontend e Qualidade
status: Active
version: 1.6
date: 2026-08-26
last_reviewed: 2026-08-26
keywords: frontend, licoes, prevencao, incidentes
related_files: ../README.md, ../adrs/README.md, ../specs/README.md
code_references: app/
principal_statement: Cada lição registra causa, resolução, prevenção e fontes vigentes relacionadas.
---

# Índice de Lições Aprendidas: Frontend

## Contrato da coleção

- Conteúdo aceito: lições transferíveis de UI, acessibilidade, estado, autenticação, integrações, testes e build do frontend.
- Owner: Frontend e Qualidade.
- Nomes: `LL-FE-NNNNN-short-title.md`; o mesmo `LL-FE-NNNNN` aparece nos metadados, título e catálogo.
- Estados permitidos: `Draft`, `Validated` e `Deprecated`.
- Critério de granularidade: separar uma lição quando causa, resolução, prevenção, owner ou ciclo de validação forem independentes.
- Inventário atual: nenhum documento está registrado neste baseline. O catálogo
  histórico abaixo foi preservado apenas como referência textual e não representa
  artefatos ativos.

Este diretório centraliza e categoriza os principais aprendizados técnicos de arquitetura, renderização e infraestrutura relativas ao Next.js e ao ecosistema de Frontend em geral.

Convenção obrigatória: `LL-FE-NNNNN-short-title.md`; título, `Document ID` e
referências usam `LL-FE-NNNNN`. Estados: `Draft`, `Validated`, `Deprecated`.

~~~text

---

| ID | Lição | Resumo do Problema | Resumo da Solução |
| :--- | :--- | :--- | :--- |
| **CSS, Layout & UX Styling** ||||
| [LL-FE-00001](LL-FE-00001-tailwind-v4-cascade-layers.md) | Tailwind v4 & CSS Resets | Regra _unlayered_ num reset trivial apagava/nulificava paddings e utility bounds essenciais do Tailwind v4. | Acomodar resets de design explícitos e estilos puros em `@layer base`. |
| [LL-FE-00002](LL-FE-00002-route-groups-a11y-semantics.md) | Route Groups Semantics (a11y) | Route Groups divididos guparam a omissão acidental ou a duplicação errônea dos root tags de leitor (`<main>`). | Proibir containers root aninhados e forçar layouts group apartados como as bridges ao skip-link. |
| [LL-FE-00023](LL-FE-00023-visual-standardization-flat-design.md) | Visual Standardization & Flat Design | Drift estético (mistura de bordas, rounded-xl e shadows) gerava inconsistência visual entre componentes, inputs e grids. | Padronizar containers globalmente para visual Flat puro: uso obrigatório de `rounded-lg`, `border-input` e proibição de sombras em containers estruturais. |
| **Rendering Boundaries & Contextual States** ||||
| [LL-FE-00004](LL-FE-00004-suspense-boundary-use-client.md) | Suspense Loading Hydration | O fallback padrão de Loading do Router travava exclusivamente numa navegação Client-Side exigindo resolução de UI. | Exigir a diretiva `'use client'` no topo absoluto de Loaders/Errors que dependem implicitamente de sub-componentes visuais ou translations iterativas. |
| [LL-FE-00007](LL-FE-00007-providers-wrapper-architecture.md) | Centralized Provider Wrap | Renderizações em Server Component Layouts entupiam com bindings isoladas e custom providers (Auth/Locale) dispersas. | Encapsular a hierarquia unificada injetando providers globais ordenados numa Bridge estrita de Client `<Providers>`. |
| **Security, RBAC & Context Management** ||||
| [LL-FE-00008](LL-FE-00008-usepermission-hook-logic-bug.md) | RBAC Logic Short-Circuits | Inputs brancos com matrizes vazias reincindiam permissões absolutas baseadas num by-pass de validações `.every()`. | Proibir falsos true com checagem nula de tamanhos de array de scope/roles antes de derivar as asserções OR/AND. |
| [LL-FE-00009](LL-FE-00009-tenant-missing-claims-super-admin.md) | Missing Claims for Super Admins | Abortar requisições em bloco por inconsistência de _tenantId_ nula penalizava fatalmente profiles inter-locatários. | Incluir flexibilidades dinâmicas para papéis administrativos incondicionais que pulhem nativamente o vinculo organizacional. |
| [LL-FE-00011](LL-FE-00011-msw-keycloak-init-deadlock.md) | MSW vs Keycloak Init Race Condition | `ProtectedRoute` coercia falhas 404 via redirects prematuros de `login` atrelado ao MSW timeout loop em ambientes Dockerless. | Ignorar bypass client-side de `login` explicitamente provendo loadings ad-hoc se a flag `enableMsw` sinalizar latência intencional em Dev. |
| [LL-FE-00091](LL-FE-00091-session-sync-timeout-is-not-auth-expiration.md) | Session Sync Timeout Is Not Auth Expiration | Falhas ao estabelecer conexão consumiam o deadline no `next dev`; o controle compilado no host concluiu oito sincronizações em menos de 100 ms, enquanto duas falhas transitórias indistintas ainda poderiam encerrar a sessão. | Comparar dev frio, bundle compilado e imagem publicada, fornecer `AUTH_*` no runtime, diagnosticar a fase temporal e separar indisponibilidade de identidade inválida. |
| **Integrations, APIs & Forms Infrastructure** ||||
| [LL-FE-00003](LL-FE-00003-error-boundaries-i18n-tradeoff.md) | Error Boundaries vs Translations | Injetar Hooks do Next-Intl em catchers do core (`error.tsx`) impunha loops vazios caso o prórprio provider internacional falhasse. | Aplicar string estáticas aos Fallbacks Fatais Raíz sem atrelar a recuperação primária ao provedor custom de lingua localisado. |
| [LL-FE-00005](LL-FE-00005-msw-url-mismatch-cross-origin.md) | MSW Cross-Origin Misses | Configurações baseadas em rota invisível ("relativo") derivavam endpoints contra Hosts virtuais não-alocados ignorando calls reais atrelados à Backends em Ports separados (`8080`). | Forjar as listeners handlers de Service-Workers (MSW) em assinaturas explicitamente construídas do absolutism domain env `process.env.NEXT...`. |
| [LL-FE-00006](LL-FE-00006-react-hook-form-autofill-race-condition.md) | Form Fill Race Conditions | Escutar estados autônomos (`useEffect`) para carregar regras complexas sob dependentes esmagava overrides humanos em renderizações flutuantes. | Ligar hooks ou atualizações cruzadas do Hook-Form direto no handler/emitter passivo da interface reativa. |
| [LL-FE-00012](LL-FE-00012-radix-ui-select-empty-value-crash.md) | Radix Select Empty String Crash | Instanciar um fallback `value=""` nativo em `<Select.Item>` do Radix explodia domínios visuais desestabilizando o Client side-effect subjacente de renderização pura. | Tipar sentinelas de Null/Object literals ("\_\_ALL\_\_") para ancorar placeholders inertes na lista de Options primitiva. |
| [LL-FE-00013](LL-FE-00013-tanstack-query-broad-invalidation.md) | Broad Cache Invalidations | Usar suffix key `.all` para limpar lixos numa Mutation provocava recarregamentos acidentais e massivos de detalhes imutáveis subjacentes na árvore do React Query. | Apontar Invalidations pontuais e rastreadas `.lists()` ou sub-keys puras como alvo para preservar sub-consultas isoladas. |
| [LL-FE-00014](LL-FE-00014-spec-drift-inert-buttons-feature-components.md) | Spec-Drift & Botões Inertes | Colunas especificadas no wireframe foram omitidas na implementação; botão de upgrade renderizado sem handler/navegação. | Verificar colunas/ações 1:1 contra a tabela do wireframe; nunca deixar `<button>` sem `onClick` ou `<Link>` sem `href`. |
| [LL-FE-00015](LL-FE-00015-hardcoded-dynamic-routes-omission.md) | Hardcoded Dynamic Routes | Omissão de builders no `DYNAMIC_PATHS` levando ao uso de template strings manuais para navegação de detalhes. | Forçar centralização de builders em `@/lib/paths.ts` para garantir single source of truth de URLs. |
| **Testing Architecture & Libraries** ||||
| [LL-FE-00010](LL-FE-00010-responsive-sidebar-rendering-tests.md) | Dual Rendering on RTL Tests | Testings semânticos esbarravam cegamente em contêineres duplicados forjados via Design Responsivo (mobile/desktop). | Utilizar aferições em arrays de quantitativos visuais (`getAllByText.length > 0`) prevenindo dependências frágeis a elementos únicos falsos. |
| [LL-FE-00016](LL-FE-00016-playwright-syntax-errors-silent-failures.md) | Playwright Syntax Parse Errors | Faltar o fechamento de um `test()` em arquivos copiados/injetados fazia com que o parseamento de toda a suíte sofresse falha fatal. | Sempre validar e executar pontualmente os `.spec.ts` modificados para garantir o parse sem erros antes de empurrar o commit. |
| [LL-FE-00017](LL-FE-00017-schema-drift-zod-in-types.md) | Schema Drift: Zod em Types | Zod schemas colocados em `types/client.ts` violando separação ADR-0013. | Extrair schemas para `schemas/clientSchemas.ts`; `types/` nunca importa `zod`. |
| [LL-FE-00018](LL-FE-00018-confirm-dialog-premature-close.md) | ConfirmDialog Premature Close | Dialog de confirmação fechando antes da mutation completar; spinner e feedback de erro invisíveis ao usuário. | Mover o fechamento do dialog para `onSettled` da mutation ao invés da mesma tick do `mutate()`. |
| [LL-FE-00019](LL-FE-00019-prop-spread-order-masked-inputs.md) | Prop Spread Order em Masked Inputs | `{...props}` espalhado após props internas em wrappers `forwardRef` permite que o consumidor sobrescreva `maxLength`, `onChange` e `placeholder` silenciosamente. | Espalhar `{...props}` **antes** das propriedades protegidas; quem declara por último, vence. |
| **Design Specifications & Wireframes** ||||
| [LL-FE-00020](LL-FE-00020-wireframe-shallow-spec-drift.md) | Wireframe Shallow Spec Drift | Wireframe aprovado com 43 linhas (sem Domain Model, RBAC, Stitch Matrix) gerou implementações ad-hoc sem rastreabilidade. Tipos, rotas e componentes definidos fora do spec. | Exigir ≥7 seções obrigatórias (Domain Model, Components, State, RBAC, Stitch, Routing, Next Steps). Rejeitar wireframes que não atendam o template mínimo antes de avançar para implementação. |
| [LL-FE-00021](LL-FE-00021-strict-union-type-bypass.md) | Strict Union Type Bypass | O uso de `| string` em union types (ex: `Type A | Type B | string`) desativa o check de exaustão do TS e o autocompletar da IDE. | Proibir o uso de `| string` em contratos de domínio fixos; usar enums rigorosos em Types e Zod Schemas. |
| [LL-FE-00022](LL-FE-00022-prop-spread-zone-classification.md) | Prop Spread Zone Classification | LL-FE-00019 aplicada sem distinção entre props "protegidas" e "defaultáveis" causou placeholder hardcoded sobrescrevendo i18n do consumidor. | Classificar props em 3 zonas: (1) Defaults antes do spread, (2) Consumer no spread, (3) Protegidos depois do spread. |
| [LL-FE-00024](LL-FE-00024-i18n-drift-admin-components.md) | i18n Drift em Componentes Admin | ~30 strings hardcoded em pt-BR nos componentes de billing admin (tabelas, modais, filtros, paginação) + uso de `any` em 3 callbacks de `.map()`. | Zero hardcode em todo `.tsx`; namespace i18n estruturado para subcomponentes (filters/table/pagination/modal); nunca usar `any` em `.map()` — importar o tipo real. |
| [LL-FE-00025](LL-FE-00025-atomic-field-i18n-rename.md) | Atomic Field & i18n Rename | Renomeação de métricas e limites (`whatsappLimit` → `chatbotLimit`) sem renomear a chave de i18n atrelada causa vazamento de chave bruta na UI. | Sempre alterar as chaves de i18n em conjunto (atomicamente no mesmo commit) com as propriedades de dados que elas espelham. |
| [LL-FE-00026](LL-FE-00026-tests-consume-constants.md) | Testes Consomem Constantes | Refatorações de constants/RBAC (ex: `WHATSAPP_OPERATOR` → `CHATBOT_OPERATOR`) ou textos invisíveis quebram asserções de testes desatualizadas. | Varredura completa nos testes `.test.ts` após alterar valores textuais estritos de domínio. Os testes são os maiores consumidores do software. |
| [LL-FE-00027](LL-FE-00027-final-grep-sweep-before-commit.md) | Final Grep Sweep Before Commit | Marcar refatoração como concluída sem escopo limpo gera dívida técnica com menções isoladas espalhadas (em mocks e tipos obsoletos). | Executar um último `grep` estrito contra o termo refatorado ("whatsapp") validando e excluindo intencionalmente os falsos-positivos de domínio cruzado. |
| [LL-FE-00028](LL-FE-00028-orphan-routes-and-stub-forms.md) | Orphan Routes & Stub Forms | Páginas criadas como sub-rotas (`/settings/chatbot/access`) sem link de navegação ficam "órfãs" — inacessíveis ao usuário. Formulários com `console.log` ao invés de service layer real criam dívida técnica silenciosa. | Toda nova rota criada **deve** ter pelo menos um link/tab/menu que conduza até ela. Formulários stub devem usar `// TODO:` ao invés de `console.log` e nunca devem ser marcados como "concluídos" no task plan. |
| [LL-FE-00029](LL-FE-00029-llm-prompt-binding-mismatch.md) | LLM Prompt Entity Binding Mismatch | Formulário do LLM Prompt enviava UUID de *Channel Template* para um endpoint que aguardava Enum de *Business Function* (`functionType`), causando falha de parsing no Jackson. | Checar a topologia real (`Enum/DTO`) no backend antes de popular dropdowns no frontend com hooks arbitrários; LLM Prompts se ligam a Funções, não a Layouts Visuais. |
| [LL-FE-00030](LL-FE-00030-protected-route-map-desync.md) | Protected Route Map Desync | Nova rota registrada no `menu-config.ts` e protegida no backend, mas **ausente** do `protected-routes.ts` — qualquer usuário autenticado podia acessar via URL direta. | Regra do "Triângulo RBAC": toda rota protegida deve constar em `paths.ts`, `menu-config.ts` **e** `protected-routes.ts` simultaneamente. |
| [LL-FE-00031](LL-FE-00031-hook-api-signature-mismatch.md) | Hook API Signature Mismatch | Hook `useToast` chamado com assinatura de objeto `{title, description, variant}` (padrão shadcn) quando a API real era posicional `(variant, title, description?)` — toast não aparecia. | Antes de usar qualquer hook pela primeira vez num novo módulo, abrir a implementação e confirmar a assinatura. |
| [LL-FE-00032](LL-FE-00032-frontend-backend-dto-contract-drift.md) | Frontend-Backend DTO Contract Drift | Interface TS do service layer incluía campos inexistentes no record Java (`iamUserId`, `updatedAt`) e marcava `password` como opcional quando backend exige `@NotBlank`. | Interface TS deve ser derivada diretamente do record/DTO Java; handlers MSW devem retornar a mesma shape sem campos extras. |
| [LL-FE-00033](LL-FE-00033-spa-multi-realm-auth-mismatch.md) | SPA Multi-Realm Auth Mismatch | Redirecionar para raiz (`/`) com Tenant salvo ao invés do IdP gera loops de Check-SSO injetando tokens falhos ou de Realms antigos em rotas montadas. | Sempre inicie nova instância OIDC e force `keycloak.login({redirectUri: ...})` delegando PKCE cruzado direto para o servidor de identidade. |
~~~
