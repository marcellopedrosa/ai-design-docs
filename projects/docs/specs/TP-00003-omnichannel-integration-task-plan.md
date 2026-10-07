---
document_id: "TP-00003"
primary_nature: "Plano"
objective: "Este documento orquestra a sequência de execução cross-layer (Backend e Frontend) para a refatoração e integração completa do ecossistema Omnichannel (WhatsApp e Telegram). A divisão em 4 fases garante uma evolução estável: a base de dados primeiro, as APIs em seguida e a transição profunda da UI por último, minimizando o risco de quebras nos contratos da API."
scope: "Coordenacao de Omnichannel Integration & Refactoring Sequence nos componentes, fases, dependencias e verificacoes explicitamente descritos no plano."
non_objectives: "N/A - o documento original nao explicita nao-objetivos adicionais."
owner: "@AgentOrchestrator"
status: "Completed"
date: "2026-06-03"
version: "1.0"
keywords: "plano, coordenacao, omnichannel, integration"
related_files: "TP-00001-backend-spring-modulith-task-plan.md, TP-00002-frontend-nextjs-task-plan.md, ../../backend/docs/specs/IP-BE-3.1.13-omnichannel-config-management.md, ../../backend/docs/specs/IP-BE-3.1.14-omnichannel-access-and-billing.md, ../../backend/docs/specs/IP-BE-3.1.15-chatbot-function-registry-api.md, ../../backend/docs/specs/IP-BE-3.1.16-chatbot-inbound-state-machine-and-dynamic-menus.md, ../../backend/docs/specs/IP-BE-3.1.18-chatbot-channel-templates-api.md, ../../frontend/docs/specs/IP-FE-3.8.1-omnichannel-inbox-and-settings.md, ../../frontend/docs/specs/IP-FE-3.8.2-omnichannel-access-and-billing-ui.md, ../../frontend/docs/lessons-learned/LL-FE-00028-orphan-routes-and-stub-forms.md, ../../backend/docs/lessons-learned/LL-BE-00090-telegram-answer-callback-query-mandatory.md, ../../backend/docs/lessons-learned/LL-BE-00059-state-machine-security-transitions.md, docs/delivery/plans/README.md"
code_references: "MessageEntity, PhoneNumber.java, RemoteIdentifier, AccessValidationRepository, WhatsAppPlatformConfigRepository, SubscriptionSuspendedEvent, WhatsAppAdminController, ChatbotAdminController, /api/v1/tenants/{tenantId}/chatbot, ConversationSummaryDto, ConversationDetailDto, MessageDto"
principal_statement: "Conduz a evolução de WhatsApp isolado para uma base omnichannel."
---

# TP-00003 — �� Omnichannel Integration & Refactoring Sequence

**Document ID:** `TP-00003`  

**Agent:** @AgentOrchestrator
**Status:** ✅ Done
**Date:** 2026-06-03

**Task Plans Originais (Épicos):**
- [TP-00001-backend-spring-modulith-task-plan.md](TP-00001-backend-spring-modulith-task-plan.md) (Seções 3.1.13 e 3.1.14)
- [TP-00002-frontend-nextjs-task-plan.md](TP-00002-frontend-nextjs-task-plan.md) (Seções 3.8.1 e 3.8.2)

**Implementation Plans Detalhados (O "Como"):**
- [../../backend/docs/specs/IP-BE-3.1.13-omnichannel-config-management.md](../../backend/docs/specs/IP-BE-3.1.13-omnichannel-config-management.md)
- [../../backend/docs/specs/IP-BE-3.1.14-omnichannel-access-and-billing.md](../../backend/docs/specs/IP-BE-3.1.14-omnichannel-access-and-billing.md)
- [../../backend/docs/specs/IP-BE-3.1.15-chatbot-function-registry-api.md](../../backend/docs/specs/IP-BE-3.1.15-chatbot-function-registry-api.md)
- [../../backend/docs/specs/IP-BE-3.1.16-chatbot-inbound-state-machine-and-dynamic-menus.md](../../backend/docs/specs/IP-BE-3.1.16-chatbot-inbound-state-machine-and-dynamic-menus.md)
- [../../backend/docs/specs/IP-BE-3.1.18-chatbot-channel-templates-api.md](../../backend/docs/specs/IP-BE-3.1.18-chatbot-channel-templates-api.md)
- [../../frontend/docs/specs/IP-FE-3.8.1-omnichannel-inbox-and-settings.md](../../frontend/docs/specs/IP-FE-3.8.1-omnichannel-inbox-and-settings.md)
- [../../frontend/docs/specs/IP-FE-3.8.2-omnichannel-access-and-billing-ui.md](../../frontend/docs/specs/IP-FE-3.8.2-omnichannel-access-and-billing-ui.md)

---

## 1. Goal

Este documento orquestra a sequência de execução cross-layer (Backend e Frontend) para a refatoração e integração completa do ecossistema Omnichannel (WhatsApp e Telegram). A divisão em 4 fases garante uma evolução estável: a base de dados primeiro, as APIs em seguida e a transição profunda da UI por último, minimizando o risco de quebras nos contratos da API.

---

## 2. Execution Phases

### Phase 1: Backend Foundation & Persistence
*Preparação da fundação do banco de dados e modelos sem expor ainda novos contratos na API.*

- `[x]` **1.1. Flyway & Constraints:** Criar a migration V4 renomeando `whatsapp_message_id` para `external_message_id`. Avaliar e renomear limites de tabela de tenant/billing (se existirem fisicamente sob o nome whatsapp). *(Ref: [IP-BE-3.1.13-omnichannel-config-management — Plan](../../backend/docs/specs/IP-BE-3.1.13-omnichannel-config-management.md))*
- `[x]` **1.2. JPA Entity Updates:** Atualizar `MessageEntity` (`whatsappMessageId` → `externalMessageId`). *(Ref: [IP-BE-3.1.13-omnichannel-config-management — Plan](../../backend/docs/specs/IP-BE-3.1.13-omnichannel-config-management.md))*
- `[x]` **1.3. Value Objects:** Modificar `PhoneNumber.java` para aceitar formatações não-E.164 (como os Chat IDs numéricos/negativos do Telegram) ou adotar `RemoteIdentifier`. *(Ref: [IP-BE-3.1.14-omnichannel-access-and-billing — Plan](../../backend/docs/specs/IP-BE-3.1.14-omnichannel-access-and-billing.md))*
- `[x]` **1.4. Repositórios Core:** Implementar `findAllByTenantId` e `deleteById` no `AccessValidationRepository`. Criar a port e adapter `WhatsAppPlatformConfigRepository`. *(Ref: [IP-BE-3.1.13-omnichannel-config-management — Plan](../../backend/docs/specs/IP-BE-3.1.13-omnichannel-config-management.md) e [IP-BE-3.1.14-omnichannel-access-and-billing — Plan](../../backend/docs/specs/IP-BE-3.1.14-omnichannel-access-and-billing.md))*
- `[x]` **1.5. Billing MetricType:** Renomear o enum `WHATSAPP_MSG` → `CHATBOT_MSG` e adaptar os Eventos de Suspensão de Assinatura (`SubscriptionSuspendedEvent`). *(Ref: [IP-BE-3.1.14-omnichannel-access-and-billing — Plan](../../backend/docs/specs/IP-BE-3.1.14-omnichannel-access-and-billing.md))*

---

### Phase 2: Backend APIs (Inbox, Config & Access)
*Exposição das novas APIs REST e refatoração da Inbox. Esta fase quebra intencionalmente os contratos antigos para forçar a adaptação no front.*

- `[x]` **2.1. Inbox Refactoring:** Renomear `WhatsAppAdminController` para `ChatbotAdminController` e alterar a base path para `/api/v1/tenants/{tenantId}/chatbot`. *(Ref: [IP-BE-3.1.13-omnichannel-config-management — Plan](../../backend/docs/specs/IP-BE-3.1.13-omnichannel-config-management.md))*
- `[x]` **2.2. DTOs & Projeção:** Adicionar o campo `channelType` nos DTOs (`ConversationSummaryDto`, `ConversationDetailDto` e `MessageDto`). Alterar o `ChatbotAdminQueryAdapter` para realizar essa projeção na listagem. *(Ref: [IP-BE-3.1.13-omnichannel-config-management — Plan](../../backend/docs/specs/IP-BE-3.1.13-omnichannel-config-management.md))*
- `[x]` **2.3. Config APIs:** Criar `TelegramBotConfigController` e `WhatsAppPlatformConfigController` para o gerenciamento de bots (com `RegisterTelegramWebhookUseCase`). *(Ref: [IP-BE-3.1.13-omnichannel-config-management — Plan](../../backend/docs/specs/IP-BE-3.1.13-omnichannel-config-management.md))*
- `[x]` **2.4. Access API:** Implementar `ChatbotAccessValidationController` provendo as rotas de gerenciamento manual de acessos via Documento. *(Ref: [IP-BE-3.1.14-omnichannel-access-and-billing — Plan](../../backend/docs/specs/IP-BE-3.1.14-omnichannel-access-and-billing.md))*
- `[x]` **2.5. Backend Tests & Verificação:** Atualizar testes unitários e de integração quebrados pelas renomeações de rotas e DTOs. Executar `./mvnw verify` e `grep -r "WHATSAPP_MSG" --include="*.java"` para garantir zero referências residuais. *(Ref: [IP-BE-3.1.13-omnichannel-config-management — Plan](../../backend/docs/specs/IP-BE-3.1.13-omnichannel-config-management.md) e [IP-BE-3.1.14-omnichannel-access-and-billing — Plan](../../backend/docs/specs/IP-BE-3.1.14-omnichannel-access-and-billing.md))*

---

### Phase 3: Frontend Foundation & Deep Refactoring (Concluída)
*Adequação massiva do ecossistema React/Next.js para eliminar nomenclatura fixa do WhatsApp e adotar as novas APIs.*

- `[x]` **3.1. Types & Models:** Renomear `types/whatsappAdvanced.ts` para `chatbot.ts`, injetando a propriedade `channel` nas interfaces. Em `types/tenant.ts` e `billing.ts`, renomear os campos limitadores (`whatsappLimit` → `chatbotLimit`). *(Ref: [IP-FE-3.8.1-omnichannel-inbox-and-settings — Plan](../../frontend/docs/specs/IP-FE-3.8.1-omnichannel-inbox-and-settings.md) e [IP-FE-3.8.2-omnichannel-access-and-billing-ui — Plan](../../frontend/docs/specs/IP-FE-3.8.2-omnichannel-access-and-billing-ui.md))*
- `[x]` **3.2. RBAC & Module Access:** Atualizar `permissions.ts` substituindo as Roles e Scopes (`WHATSAPP_ADMIN` → `CHATBOT_ADMIN`). Renomear a chave correspondente em `useModuleAccess.ts`. *(Ref: [IP-FE-3.8.1-omnichannel-inbox-and-settings — Plan](../../frontend/docs/specs/IP-FE-3.8.1-omnichannel-inbox-and-settings.md))*
- `[x]` **3.3. Roteamento & Navegação:** Renomear constantes em `paths.ts` (`WHATSAPP` → `INBOX`). Renomear diretórios e rótulos de Menu/Breadcrumbs (`lib/menu-config.ts` e `route-labels.ts`). Atualizar testes de asserção. *(Ref: [IP-FE-3.8.1-omnichannel-inbox-and-settings — Plan](../../frontend/docs/specs/IP-FE-3.8.1-omnichannel-inbox-and-settings.md))*
- `[x]` **3.4. Serviços & Queries:** Adaptar `whatsappAdvancedService.ts` para `chatbotService.ts` e mudar `BASE_URL` para bater no novo backend de `chatbot`. Atualizar os query keys e hooks do React Query. *(Ref: [IP-FE-3.8.1-omnichannel-inbox-and-settings — Plan](../../frontend/docs/specs/IP-FE-3.8.1-omnichannel-inbox-and-settings.md))*
- `[x]` **3.5. Mock Data (MSW):** Renomear os handlers de MSW. Injetar conversas de teste com `channel` Telegram e simular as respostas das novas APIs de Access Validation e Config. *(Ref: [IP-FE-3.8.1-omnichannel-inbox-and-settings — Plan](../../frontend/docs/specs/IP-FE-3.8.1-omnichannel-inbox-and-settings.md) e [IP-FE-3.8.2-omnichannel-access-and-billing-ui — Plan](../../frontend/docs/specs/IP-FE-3.8.2-omnichannel-access-and-billing-ui.md))*

---

### Phase 4: Frontend UI (Components & Pages) — Concluída
*Desenvolvimento das interfaces finais de usuário para Omnichannel, usando o Foundation da Fase 3.*

- `[x]` **4.1. Inbox UI:** Refatorar `ConversationList` e `ConversationTimeline` (agora sob `components/inbox`) para que renderizem o ícone do provedor correto usando o dado de `channel`. *(Ref: [IP-FE-3.8.1-omnichannel-inbox-and-settings — Plan](../../frontend/docs/specs/IP-FE-3.8.1-omnichannel-inbox-and-settings.md))*
- `[x]` **4.2. Chatbot Settings:** Desenvolver abas na UI de configurações que permitam o cadastro de chaves para Telegram e WhatsApp. *(Ref: [IP-FE-3.8.1-omnichannel-inbox-and-settings — Plan](../../frontend/docs/specs/IP-FE-3.8.1-omnichannel-inbox-and-settings.md))*
- `[x]` **4.3. Access Validations UI:** Construir tabela e modal de "Nova Autorização" em `settings/chatbot/access`. Aplicar schema Zod dinâmico `createAccessValidationSchema` para lidar com validação de telefones E.164 (WhatsApp) ou numéricos (Telegram). *(Ref: [IP-FE-3.8.2-omnichannel-access-and-billing-ui — Plan](../../frontend/docs/specs/IP-FE-3.8.2-omnichannel-access-and-billing-ui.md))*
- `[x]` **4.4. UI Labels (Billing & Tenant):** Eliminar visualizações textuais fixas de "Mensagens WhatsApp", substituindo por "Mensagens Chatbot" nas páginas de Assinatura e Planos. *(Ref: [IP-FE-3.8.2-omnichannel-access-and-billing-ui — Plan](../../frontend/docs/specs/IP-FE-3.8.2-omnichannel-access-and-billing-ui.md))*

> **Nota de Code Review (2026-06-05):** 7 GAPs identificados e 5 corrigidos. 2 GAPs aceitos/deferidos (Config Forms são stubs — dependem de backend). Lição aprendida [LL-FE-00028](../../frontend/docs/lessons-learned/LL-FE-00028-orphan-routes-and-stub-forms.md) registrada. `npx tsc --noEmit` = 0 erros.

---

### Phase 5: Frontend API Integration
*Conexão dos formulários de configuração criados na Fase 4 (atualmente stubs) com os endpoints reais do Backend construídos na Fase 2.*

- `[x]` **5.1. Telegram Service:** Implement `frontend/src/services/telegramConfigService.ts` using the shared `apiClient`. Provide `getTelegramConfigs`, `createTelegramConfig`, `updateTelegramConfig`, `deleteTelegramConfig`. Include tenant ID via `useTenant()` (adds `X‑Tenant‑ID` header). Define interface `TelegramBotConfig` matching `TelegramBotConfigDto` (id, botToken, webhookSecret, botUsername, active). Export consistent error handling.

- `[x]` **5.2. WhatsApp Service:** Implement `frontend/src/services/whatsappPlatformConfigService.ts` similarly, exposing the same CRUD functions. Include tenant handling. Define interface `WhatsAppPlatformConfig` matching `WhatsAppPlatformConfigDto` (id, wabaId, accessToken, apiBaseUrl, webhookVerifyToken, active). Provide default `apiBaseUrl` (`https://graph.facebook.com/v19.0`) on creation.

- `[x]` **5.3. React Query Hooks:** Create `useTelegramConfigQueries.ts` and `useWhatsAppConfigQueries.ts`. Export `useTelegramConfigs`, `useCreateTelegramConfig`, `useUpdateTelegramConfig`, `useDeleteTelegramConfig` (and equivalents). Use query keys `['telegramConfigs']` / `['whatsappConfigs']`. Mutations must call `queryClient.invalidateQueries(['telegramConfigs'])` etc. Include optimistic update placeholders and error toast handling.

- `[x]` **5.4. Conectar TelegramConfigForm:** Replace stub logic with a real form using `react-hook-form` + `zodResolver` with `createTelegramConfigSchema`. Load existing config via `useTelegramConfigs`, pre‑populate fields, and invoke create/update mutations on submit. Disable submit while `isLoading` or `isSubmitting`. Show success/error toasts (`toast({ variant: 'default' })`). Update i18n keys for success/error messages.

- `[x]` **5.5. Conectar WhatsAppConfigForm:** Same pattern as Telegram, using `createWhatsAppConfigSchema`. Map fields to `wabaId`, `accessToken`, `webhookVerifyToken`. Include default `apiBaseUrl`. Use toasts for feedback.

- `[x]` **5.6. Tipos & Schemas:** Ensure `frontend/src/types/chatbot.ts` exports interfaces `TelegramBotConfig` & `WhatsAppPlatformConfig` plus payload types `CreateTelegramBotConfigPayload` & `CreateWhatsAppPlatformConfigPayload`. In `frontend/src/schemas/chatbotSchemas.ts` define `createTelegramConfigSchema` and `createWhatsAppConfigSchema` with field constraints (token regex, URL validation). Export for form consumption.

- `[x]` **5.7. Documentação:** Atualizar `frontend/src/services/README.md` com exemplos de uso, explicação de query keys, cabeçalho de tenant e referência aos schemas Zod.

- `[x]` **5.8. Testes Unitários:** Escrever testes Jest + MSW para os serviços e hooks, garantindo cobertura de sucesso, erro de rede e invalidação de cache.

---

### Phase 6: Inbound State Machine & Dynamic Menus (Concluída)
*Integra o Function Registry dinâmico arquitetado na fase anterior com o processador de Inbounds (Webhook) nativo para responder com Dynamic Menus aos clientes.*

- `[x]` **6.1. Domain Isolation (InteractiveMenu):** Criar `valueobjects/InteractiveMenu.java` agnóstico com uma lista de `MenuButton` para padronizar os intents de cliques, substituindo o tráfego brutal de payload JSON nos casos de uso. *(Ref: [IP-BE-3.1.16-chatbot-inbound-state-machine-and-dynamic-menus — Plan](../../backend/docs/specs/IP-BE-3.1.16-chatbot-inbound-state-machine-and-dynamic-menus.md))*
- `[x]` **6.2. Port/Adapter Contract:** Ajustar `ChannelMessagePort`. Mudar a signature de `sendInteractiveMessage` para esperar o domínio puro `InteractiveMenu`. *(Ref: [IP-BE-3.1.16-chatbot-inbound-state-machine-and-dynamic-menus — Plan](../../backend/docs/specs/IP-BE-3.1.16-chatbot-inbound-state-machine-and-dynamic-menus.md))*
- `[x]` **6.3. ChatbotFlowUseCase Update:** Injetar o `ListChatbotFunctionsUseCase` para puxar funções "enabled=true" por Tenant. Alterar os metódos de Welcome e Menu para construírem o `InteractiveMenu` populando os botões com base no BD em vez de Strings hardcoded ("1", "2"). Transacionar ChatbotState de acordo com o `functionCode` recuperado no evento de clique de quem enviou a msg. *(Ref: [IP-BE-3.1.16-chatbot-inbound-state-machine-and-dynamic-menus — Plan](../../backend/docs/specs/IP-BE-3.1.16-chatbot-inbound-state-machine-and-dynamic-menus.md))*
- `[x]` **6.4. Telegram Adapter Serialization:** Atualizar `TelegramBotApiAdapter` para compilar o modelo puro do `InteractiveMenu` na estrutura rígida exigida de `reply_markup`/`inline_keyboard` do Bot API da API do Telegram. *(Ref: [IP-BE-3.1.16-chatbot-inbound-state-machine-and-dynamic-menus — Plan](../../backend/docs/specs/IP-BE-3.1.16-chatbot-inbound-state-machine-and-dynamic-menus.md))*
- `[x]` **6.5. WhatsApp Adapter Serialization:** Deixar o logger placeholder ou implementação futura do `InteractiveMenu` para os botões List Menssage do Meta Cloud API dentro do `WhatsAppCloudApiAdapter`. *(Ref: [IP-BE-3.1.16-chatbot-inbound-state-machine-and-dynamic-menus — Plan](../../backend/docs/specs/IP-BE-3.1.16-chatbot-inbound-state-machine-and-dynamic-menus.md))*

> **Nota de Code Review (2026-06-15):** 3 GAPs identificados e corrigidos. GAP F6-01 (CRÍTICO): Missing `answerCallbackQuery` no Telegram — botão inline ficava em loading 30s. GAP F6-02 (CRÍTICO): Transição inválida MENU/FISCAL_QUERY/DARF_GENERATE → VALIDATE_ACCESS causava `BusinessException`. GAP F6-03 (MODERADO): `ListChatbotFunctionsUseCase` sem qualificador de `whatsappTransactionManager`. Lições aprendidas [LL-BE-00090](../../backend/docs/lessons-learned/LL-BE-00090-telegram-answer-callback-query-mandatory.md) e [LL-BE-00059](../../backend/docs/lessons-learned/LL-BE-00059-state-machine-security-transitions.md) registradas.


---

## 3. Verification & Sign-off
Ao fim das 5 fases, um script grep de validação deve ser rodado, e as integrações validadas end-to-end:
```bash
grep -r "whatsapp" --include="*.ts" --include="*.tsx" --include="*.java" src/ backend/ | grep -v "WHATSAPP_REGEX\|whatsapp.*contato\|whatsapp-templates\|V1\|V2\|V3"
```
*(Deve retornar vazio indicando a erradicação de acoplamento)*

---

## 4. Change Log

| Version | Date | Author | Changes |
|---|---|---|---|
| 1.0 | 2026-06-03 | @AgentOrchestrator | Criação inicial — 4 fases cross-layer. |
| 2.0 | 2026-06-04 | @CodeGuardian | Code Review Phase 3: GAPs F01-F10 identificados e corrigidos. |
| 3.0 | 2026-06-05 | @CodeGuardian | Implementação Phase 4 completa. Code Review: 7 GAPs (F4-01~F4-07), 5 corrigidos, 2 deferidos. LL-FE-00028 registrada. Build ✅. |
| 4.0 | 2026-06-15 | @CodeGuardian | Code Review Phase 6: 3 GAPs (F6-01~F6-03), todos corrigidos. Lições LL-BE-00058 e LL-BE-00059 registradas. |
