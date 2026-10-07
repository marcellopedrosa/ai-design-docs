---
document_id: "TP-00007"
primary_nature: "Plano"
objective: "Evolui memória conversacional e tool calling do chatbot omnichannel."
scope: "Coordenacao de Memória Arquitetural: LLM Tool Calling + Botões de Confirmação Omnichannel nos componentes, fases, dependencias e verificacoes explicitamente descritos no plano."
non_objectives: "N/A - o documento original nao explicita nao-objetivos adicionais."
owner: "Engenharia"
status: Draft
date: "2026-08-26"
version: "1.0"
keywords: "plano, coordenacao, arch, memory, llm, tool, calling, omnichannel"
related_files: "docs/architecture/omnichannel-conversational-function-lifecycle.md, docs/delivery/plans/README.md"
code_references: "GeminiLlmAdapter, SpringAiLlmAdapter, LlmResponsePort, FixedTemplateFallbackAdapter, LlmToolCallResult, NoOpLlmResponseAdapter, QuickReplyButton, InlineKeyboardMarkup, ChannelMessagePort, WhatsAppCloudApiAdapter, TelegramBotApiAdapter, ChatbotState.java"
principal_statement: "Evolui memória conversacional e tool calling do chatbot omnichannel."
---

# TP-00007 — Memória Arquitetural: LLM Tool Calling + Botões de Confirmação Omnichannel

**Document ID:** `TP-00007`  

> **Gerado em:** 2026-08-08  
> **Contexto:** UC-00025 / REQ-00027  
> **Status:** Em implementação

> [!IMPORTANT]
> As seções históricas deste documento que descrevem formatação e tool calling na mesma resposta foram substituídas pela referência obrigatória [Ciclo de Vida Conversacional Omnichannel](../../architecture/omnichannel-conversational-function-lifecycle.md). Desde 2026-08-12, a ordem canônica é template preenchido e entregue antes das tools finais.

---

## 1. Decisão Arquitetural Central

O LLM é usado em **dois modos distintos** no sistema:

| Modo | Quando | Output |
|---|---|---|
| **Formatação** (já existe) | Sempre que o SERPRO retorna dados | Texto livre formatado para o canal |
| **Intenção / Tool Calling** (novo) | Quando o relatório fiscal contém condição de negócio mapeada | `tool_calls` estruturado (nome + argumentos JSON) |

O **backend Java é o único renderizador de UI interativa**. O LLM nunca produz botões, menus ou payloads de canal.

---

## 2. Por Que Não Criamos um `GeminiLlmAdapter` Específico

O `SpringAiLlmAdapter` já usa o protocolo **OpenAI-compatible** (`/chat/completions`) para todos os provedores:
- Gemini → endpoint `/openai/chat/completions` (modo de compatibilidade)
- OpenAI → endpoint padrão `/v1/chat/completions`
- Ollama → endpoint local `/v1/chat/completions`

O Function Calling usa o mesmo protocolo `tools[]` em todos os três. Um único adapter cobre tudo, preservando o plug-n-play do ADR-0021.

---

## 3. Contrato: `LlmResponsePort` Estendido

```java
// NOVO método — default garante compatibilidade reversa com NoOp e FixedTemplate
default LlmToolCallResult generateWithTools(
    String systemPrompt, String userPrompt,
    LlmConfig config, List<ToolDefinition> tools)
// → lança UnsupportedOperationException se não suportado
// → LlmProviderChain captura e tenta o próximo provider

// Novos tipos internos da interface:
record ToolDefinition(String name, String description, String parametersSchemaJson) {}
record ToolCallResult(String name, String argumentsJson) {}
record LlmToolCallResult(
    String textContent,             // null se foi tool_call puro
    List<ToolCallResult> toolCalls, // vazio se foi texto puro
    int inputTokens, int outputTokens,
    String model, LlmProviderType providerType, boolean wasFallback
) {}
```

**Adapters que NÃO precisam de alteração:**
- `FixedTemplateFallbackAdapter` — herda `default` (lança exceção, Chain captura e usa como `LlmToolCallResult` com texto fixo)
- `NoOpLlmResponseAdapter` — herda `default`

---

## 4. Value Object: `QuickReplyButton`

```java
// Localização: domain/model/valueobjects/QuickReplyButton.java
public record QuickReplyButton(String id, String label) {}
```

**Serialização no banco:** JSONB na coluna `confirmation_buttons` da tabela `chatbot_functions`:
```json
[
  {"id": "das_sim_hoje",      "label": "✅ Emitir hoje"},
  {"id": "das_escolher_data", "label": "📅 Escolher data"},
  {"id": "das_nao",           "label": "❌ Não"}
]
```

**Limites por canal:**
| Canal | Máx. botões | Mecanismo |
|---|---|---|
| WhatsApp | 3 | `interactive.type=button` — truncar com log.warn |
| Telegram | Ilimitado (prático: ~10) | `InlineKeyboardMarkup` |
| SMS/texto | ∞ (lista numerada) | Fallback gracioso do `default` da interface |

---

## 5. `ChannelMessagePort`: Novo Método

```java
// default com fallback gracioso (lista numerada em texto)
default String sendConfirmationMenu(
    String channelAccountId, String recipientId,
    String bodyText, List<QuickReplyButton> buttons)
```

Canais que implementam nativamente:
- `WhatsAppCloudApiAdapter` → `interactive.type=button`
- `TelegramBotApiAdapter` → `InlineKeyboardMarkup`

---

## 6. Novos Estados na State Machine

```
FISCAL_QUERY → [LLM retorna tool_call] → DAS_GENERATE_CONFIRMATION
                                              ├─ "das_sim_hoje" → DAS_GENERATE → MENU
                                              ├─ "das_escolher_data" → DAS_AWAITING_DATE → DAS_GENERATE → MENU
                                              └─ "das_nao" → MENU

FISCAL_QUERY → [LLM retorna texto] → COMPLETED  (comportamento atual mantido)
```

**Arquivo:** `ChatbotState.java`  
**Novos valores:** `DAS_GENERATE_CONFIRMATION`, `DAS_AWAITING_DATE`

---

## 7. Campo `pending_function_context` na Sessão

**Problema:** o LLM extrai `periodoApuracao` e `cnpj` do PDF quando retorna `tool_calls`. Esses argumentos precisam sobreviver ao clique do botão (que chega como webhook separado).

**Solução:** persistir em `conversations.pending_function_context` (JSONB):
```json
{"periodoApuracao": "202606", "cnpj": "27847725000176"}
```

**Limpeza:** ao transicionar para `MENU` ou `COMPLETED`.

---

## 8. Fluxo de Resolução de Tool Call

```
HandleSituacaoFiscalQueryResultUseCase.on(ConsultaFiscalRealizadaEvent)
  ↓
LlmToolCallingService.callWithTools(tenantId, functions, variables)
  ↓
LlmProviderChain.executeChainWithTools(providers, prompt, tools)
  ↓
SpringAiLlmAdapter.generateWithTools(...) → LlmToolCallResult

Se result.toolCalls() não vazio:
  → resolveToolCall(conversation, toolCall, activeFunctions)
     → validar function_code (TOOL-001 se não encontrado)
     → parsear argumentos JSON
     → session.setPendingFunctionContext(args)
     → session.transitionTo(ChatbotState.valueOf(function.targetState))
     → interpolate(function.confirmationBody, args) → "Encontrei débito ref. 202606..."
     → parseButtons(function.confirmationButtons) → List<QuickReplyButton>
     → channelRouter.resolve(canal).sendConfirmationMenu(...)
     → auditar + métricas

Se result.textContent() não nulo:
  → sendTextMessage (comportamento atual)
  → session.transitionTo(COMPLETED)
```

---

## 9. Schema da Migration V41

```sql
-- Tabela chatbot_functions: campos de Tool Calling
ALTER TABLE chatbot_functions
    ADD COLUMN llm_tool_description       TEXT,      -- "quando invocar" enviado ao LLM
    ADD COLUMN llm_tool_parameters_schema JSONB,     -- JSON Schema dos argumentos
    ADD COLUMN confirmation_body          TEXT,      -- corpo da mensagem (${}  vars)
    ADD COLUMN confirmation_buttons       JSONB,     -- List<QuickReplyButton>
    ADD COLUMN target_state               VARCHAR(64); -- ChatbotState a transicionar

-- Tabela conversations: contexto de função pendente
ALTER TABLE conversations
    ADD COLUMN pending_function_context   JSONB;     -- Map<String, String> de args
```

**Próxima versão:** `V41` (atual última: `V40__insert_situacao_fiscal_templates.sql`)

---

## 10. Mapa Completo de Arquivos Afetados

### Backend

| Camada | Arquivo | Tipo de Mudança |
|---|---|---|
| DB | `V41__add_llm_tool_calling_fields.sql` | NEW |
| Domain | `ChatbotState.java` | MODIFY (+2 estados) |
| Domain | `ChatbotFunction.java` | MODIFY (+5 campos) |
| Domain | `ChatbotSession.java` | MODIFY (+pendingFunctionContext) |
| Domain | `QuickReplyButton.java` | NEW (value object) |
| Port | `LlmResponsePort.java` | MODIFY (+generateWithTools + 3 records) |
| Port | `ChannelMessagePort.java` | MODIFY (+sendConfirmationMenu default) |
| Infra | `SpringAiLlmAdapter.java` | MODIFY (+generateWithTools impl) |
| Infra | `LlmProviderChain.java` | MODIFY (+executeChainWithTools) |
| Infra | `WhatsAppCloudApiAdapter.java` | MODIFY (+sendConfirmationMenu) |
| Infra | `TelegramBotApiAdapter.java` | MODIFY (+sendConfirmationMenu) |
| Infra | `ConversationEntity.java` | MODIFY (+pendingFunctionContext) |
| Infra | `ChatbotFunctionEntity.java` | MODIFY (+5 campos) |
| Infra | `ChatbotFunctionMapper.java` | MODIFY (mapear novos campos) |
| Infra | `MapStringConverter.java` | NEW (JSONB ↔ Map<String,String>) |
| App | `ChatbotFunctionDto.java` | MODIFY (+5 campos) |
| App | `LlmToolCallingService.java` | NEW |
| App | `HandleSituacaoFiscalQueryResultUseCase.java` | MODIFY (trocar generateResponse por callWithTools) |
| App | `ManageChatbotFunctionsUseCase.java` | MODIFY (passar novos campos) |
| App | `ChatbotFlowUseCase.java` | MODIFY (+2 cases no switch +3 handlers) |
| Presentation | `ChatbotFunctionAdminController.java` | MODIFY (DTO com novos campos) |

### Frontend

| Arquivo | Tipo de Mudança |
|---|---|
| `types/chatbot.ts` | MODIFY (+QuickReplyButton + 5 campos em ChatbotFunction) |
| `components/chatbot/QuickReplyButtonBuilder.tsx` | NEW |
| Formulário de edição de ChatbotFunction | MODIFY (+seção Tool Calling) |
| Zod schema de ChatbotFunction | MODIFY (+novos campos + validação JSON) |

---

## 11. Métricas Adicionadas

| Métrica | Tags | Evento |
|---|---|---|
| `chatbot_tool_call_total` | `function_code`, `tenant_id`, `outcome` | Toda resolução de tool_call |
| `chatbot_tool_call_unknown_total` | `function_code`, `tenant_id` | TOOL-001: function_code desconhecido |

---

## 12. Codes de Erro Mapeados (UC-00025 §9)

| Código | Cenário | Ação |
|---|---|---|
| `TOOL-001` | `function_code` do tool_call não encontrado no registro | Log + fallback texto + MENU |
| `TOOL-002` | Argumentos obrigatórios ausentes no tool_call | Pedir info faltante via texto |
| `TOOL-003` | Adapter de canal não implementa `sendConfirmationMenu` | `default` fallback: lista numerada |
| `TOOL-004` | Sessão expirada antes do clique no botão | `pendingFunctionContext == null` → WELCOME |

---

## 13. Pitfalls e Lições Preventivas

1. **Interpolação de variáveis em `confirmationBody`:** usar regex simples `\$\{(\w+)\}` para substituir variáveis do `pendingFunctionContext`. Não usar SpEL (acoplamento desnecessário).

2. **Parsing de `argumentsJson` do LLM:** o campo `arguments` no protocolo OpenAI vem como **String JSON** (não como objeto). Sempre fazer `new ObjectMapper().readTree(toolCall.argumentsJson())` antes de acessar campos.

3. **`tool_calls` pode ser nulo OU array vazio:** verificar ambos os casos. O Gemini retorna `null` no campo `content` quando há `tool_calls`; o OpenAI pode retornar `content = ""`.

4. **WhatsApp truncagem de botões:** o WABA retorna erro HTTP 400 se `buttons.length > 3` em `interactive.type=button`. Truncar silenciosamente com `log.warn` e nunca propagar a exceção ao usuário.

5. **Estado `DAS_GENERATE_CONFIRMATION` na máquina de estados:** o `ChatbotFlowUseCase` precisa do `canTransitionTo()` do `FISCAL_QUERY` atualizado para incluir `DAS_GENERATE_CONFIRMATION`. Sem isso, `transitionTo()` lança `BusinessException` em produção.

6. **Cache Redis de Tool Definitions:** se implementado futuramente, o `@CacheEvict` deve ser chamado ao salvar/atualizar qualquer `ChatbotFunction` com `llm_tool_description` preenchido.

---

## 14. Como Adicionar uma Nova Função de Tool Calling (sem código)

1. Cadastrar no painel admin: preencher `llm_tool_description`, `llm_tool_parameters_schema`, `confirmation_body`, `confirmation_buttons` e `target_state`.
2. Adicionar o novo `ChatbotState` ao enum se o `target_state` for inédito.
3. Adicionar o handler do novo estado no switch do `ChatbotFlowUseCase`.
4. Pronto — o LLM reconhece automaticamente na próxima requisição (sem deploy, sem prompt hardcoded).
