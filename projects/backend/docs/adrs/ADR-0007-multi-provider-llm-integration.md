---
document_id: "ADR-0007"
primary_nature: "Decisao"
objective: "Registrar a decisão arquitetural “Multi-Provider LLM Integration Architecture”, seus motivadores, alternativas e consequências."
scope: "Decisão, componentes, integrações e limites explicitamente descritos em “Multi-Provider LLM Integration Architecture”."
non_objectives: "Não implementar a decisão, substituir requisitos relacionados nem atestar capabilities ou ambientes sem evidência explícita."
owner: "@ImplementerCore, @AgentOrchestrator"
status: "Accepted"
date: "2026-03-11"
version: "1.2"
keywords: "adr, decisao, arquitetura, multi, provider, llm, integration, architecture"
related_files: "docs/adrs/README.md, docs/adrs/ADR-0001-technology-stack-and-architecture.md, docs/adrs/ADR-0004-whatsapp-integration-architecture.md, docs/adrs/ADR-0005-multi-tenancy-architecture.md, docs/product/business/product-vision.md"
code_references: "LlmResponsePort, WhatsAppMessagePort, SerproGatewayPort, GeminiLlmAdapter, OpenAiLlmAdapter, OllamaLlmAdapter, LlmResponseService, ChatbotFlowService, LlmConfig, FixedTemplateFallbackAdapter"
principal_statement: "A integração com LLM será implementada como um **outbound port** (`LlmResponsePort`) dentro do módulo WhatsApp, seguindo Clean Architecture. O provedor inicial será **Google Gemini**. A arquitetura suportará múltiplos provedores via adapter pattern, com seleção configurável por tenant e fallback automático. Os prompts para formatação de respostas SERPRO serão armazenados como **templates configuráveis** no banco de dados, editáveis pelo painel administrativo sem alteração de código."
---

# ADR-0007 - Multi-Provider LLM Integration Architecture

- Date: 2026-03-11
- Status: Accepted
- Version: 1.2
- Authors / Owners: @ImplementerCore, @AgentOrchestrator
- Reviewers: @CleanArchitecture, @DomainExpert, @SecurityOAuth, @AdapterDev
- Stakeholders: Engineering Team, Product Owner, Startup Founders

---

# 1. Context

O Contador Fiscal Inteligente utiliza um chatbot via WhatsApp (ADR-0004) como interface principal com os clientes finais dos escritórios de contabilidade. O chatbot consulta APIs do SERPRO para obter dados fiscais (pendências, DARFs, certidões) e precisa **devolver essas informações ao cliente de forma amigável e formatada** — não como dados brutos.

Contexto do problema:

- O SERPRO devolve dados em formato JSON técnico ou PDFs estruturados. Enviar esses dados crus ao cliente no WhatsApp é inaceitável do ponto de vista de UX.
- Cada tipo de consulta SERPRO (pendências, DARF, CND, situação cadastral) requer uma formatação de resposta diferente — com emojis, agrupamentos, totais, e tom adequado.
- Os escritórios de contabilidade (tenants) podem preferir tons de comunicação diferentes — uns mais formais, outros mais descontraídos.
- O volume de tipos de consulta vai crescer conforme novas integrações SERPRO são adicionadas. A solução precisa escalar sem alteração de código.
- O custo de tokens LLM é uma preocupação operacional — modelos mais baratos devem ser usados para tarefas simples, modelos mais poderosos para análises complexas.
- A indisponibilidade de um provedor LLM não pode parar o chatbot — fallback é obrigatório.

Decisão necessária: Como integrar modelos de linguagem (LLM) na arquitetura do chatbot WhatsApp de forma que suporte múltiplos provedores (iniciando pelo Gemini), permita configuração de prompts por função, e garanta resiliência com fallback.

Restrições:

- Infraestrutura em VPS única com Docker Compose (ADR-0001).
- O módulo WhatsApp é um módulo Spring Modulith isolado (ADR-0004).
- Clean Architecture: a LLM é um detalhe de infraestrutura — o domínio não pode depender de nenhum provedor específico.
- Multi-tenancy: configurações de LLM podem variar por tenant (ADR-0005).
- LGPD: dados fiscais enviados ao LLM devem ser tratados com cuidado — preferir modelos com data processing agreements (DPA).

---

# 2. Decision Statement

A integração com LLM será implementada como um **outbound port** (`LlmResponsePort`) dentro do módulo WhatsApp, seguindo Clean Architecture. O provedor inicial será **Google Gemini**. A arquitetura suportará múltiplos provedores via adapter pattern, com seleção configurável por tenant e fallback automático. Os prompts para formatação de respostas SERPRO serão armazenados como **templates configuráveis** no banco de dados, editáveis pelo painel administrativo sem alteração de código.

---

# 3. Decision Drivers

- **Clean Architecture:** A LLM é um detalhe de infraestrutura. O domínio (chatbot flow, functions) deve depender de uma interface (`LlmResponsePort`), não de um SDK específico.
- **Custo operacional:** Modelos diferentes têm custos diferentes. Gemini Flash é ideal para formatação simples; modelos mais potentes podem ser usados para análise de dados complexos. A configuração deve permitir escolha de modelo por função.
- **Resiliência:** Se o Gemini estiver indisponível, o chatbot precisa de fallback — seja outro provedor LLM ou um template fixo sem IA.
- **Multi-tenancy:** Cada escritório pode ter preferências diferentes de tom, modelo, ou até provedor de LLM — porém a configuração é feita exclusivamente pelo **super admin global** do SaaS.
- **Escalabilidade de funções:** Cada nova integração SERPRO traz um tipo de dados diferente. Os prompts de formatação devem ser adicionáveis via painel do super admin global, não por deploy.
- **Segurança (LGPD):** Dados fiscais transitam pelo LLM para formatação. Provedores devem ter DPA adequado. Dados de PII devem ser mascarados antes de enviar ao LLM.
- **Observabilidade:** Tokens consumidos, latência, e taxa de erro por provedor devem ser monitoráveis por tenant.

---

# 4. Considered Options

## Option 1: Port/Adapter com Multi-Provider e Prompt Registry (Selecionada)

Description: Interface `LlmResponsePort` com adapters para cada provedor (Gemini, OpenAI, Ollama). Prompts armazenados em tabela `llm_prompt_templates` com variáveis substituíveis. Configuração de provedor/modelo por tenant. Fallback automático para provedor secundário ou template fixo.

Pros:
- Clean Architecture — domínio isolado do provedor
- Troca de provedor por configuração, sem deploy
- Prompts editáveis pelo super admin global sem desenvolvedor
- Fallback em cascata (provedor B → template fixo → erro graceful)
- Custo otimizável por modelo/função
- Multi-tenant com configurações independentes

Cons:
- Mais tabelas no banco (configuração de provedores e prompts)
- Complexidade inicial maior que hardcoded
- Cache de prompts necessário para performance

## Option 2: Integração Direta com SDK do Gemini

Description: Usar o SDK Java do Gemini diretamente nos use cases. Prompts hardcoded no código.

Pros:
- Implementação mais rápida
- Menos abstrações

Cons:
- Vendor lock-in ao Gemini — trocar provedor exige reescrita
- Prompts hardcoded — cada ajuste exige deploy
- Sem fallback — Gemini fora = chatbot sem formatação
- Viola Clean Architecture — use case depende do SDK

## Option 3: Serviço LLM Externo (LiteLLM / LangChain4j como proxy)

Description: Deploy de um serviço intermediário (LiteLLM ou LangChain4j) que abstrai múltiplos provedores.

Pros:
- Abstração de providers out-of-the-box
- Comunidade ativa

Cons:
- Mais um container Docker na VPS — recurso limitado (ADR-0001)
- Dependência externa adicional para manter atualizada
- Overhead de rede entre serviços
- Configuração de prompts ainda precisaria ser resolvida

---

# 5. Decision Outcome

**Option 1 (Port/Adapter com Multi-Provider e Prompt Registry)** foi selecionada.

Fatores-chave:

- **Consistência arquitetural:** A mesma estratégia port/adapter já é usada para WhatsApp (`WhatsAppMessagePort`), SERPRO (`SerproGatewayPort`), e repository. A LLM segue o mesmo padrão — sem surpresas.
- **Zero vendor lock-in:** Começar com Gemini, adicionar OpenAI ou modelo local (Ollama) quando necessário, sem alterar domínio.
- **Prompts como dados, não código:** Cada nova integração SERPRO ganha um prompt configurável. O **super admin global** do SaaS pode ajustar o tom sem desenvolvedor.

> **⚠️ IMPORTANTE — Governança de Acesso:** Todas as configurações de LLM (provedores, API keys, modelos, prompts) são de competência **exclusiva do super admin global** da plataforma SaaS. O admin do escritório (tenant) **NÃO** possui permissão para gerenciar essas configurações. Esta é uma decisão estratégica da plataforma, não uma configuração por escritório.
- **Resiliência operacional:** Fallback automático garante que o chatbot nunca para — no pior caso, usa template fixo.
- **Sem infra adicional:** Não requer container extra (vs. Option 3). O adapter é uma classe Java que chama a API externa.

### Modelo de Herança: Global com Override por Tenant

A configuração de LLM segue um **modelo de herança explícito** gerenciado exclusivamente pelo super admin global:

```
┌─────────────────────────────────────────────────────────────────┐
│              CONFIGURAÇÃO GLOBAL (tenant_id = NULL)             │
│                                                                 │
│  ✅ Provedor padrão: Gemini Flash                               │
│  ✅ Prompts padrão para cada function_type                      │
│  ✅ Rate limits padrão                                          │
│  ✅ Aplica-se automaticamente a TODOS os tenants                │
└─────────────────────┬───────────────────────────────────────────┘
                      │ herança automática
         ┌────────────┼────────────┐
         ▼            ▼            ▼
   ┌──────────┐ ┌──────────┐ ┌──────────┐
   │ Tenant A │ │ Tenant B │ │ Tenant C │
   │ (herda   │ │ (OVERRIDE│ │ (herda   │
   │  global) │ │  pelo    │ │  global) │
   │          │ │  super   │ │          │
   │          │ │  admin)  │ │          │
   └──────────┘ └──────────┘ └──────────┘
```

**Regras de herança:**

1. **Novo tenant → herança automática.** Quando um escritório é criado, ele automaticamente utiliza a configuração global. Nenhuma ação manual do super admin é necessária.
2. **Override sob demanda.** O super admin pode criar configuração específica para um tenant (ex: provedor diferente, modelo diferente, tom diferente) apenas quando necessário.
3. **Resolução por prioridade:** `tenant_id = X` (override) > `tenant_id = NULL` (global). Se não existe override para o tenant, usa-se o global. **Quando um tenant possui configuração própria de LLM (override), a configuração global é completamente ignorada para aquele tenant.** O sistema utiliza exclusivamente o provedor e prompts do tenant — a LLM global não é chamada nem como fallback.
4. **Remoção de override = volta ao global.** Se o super admin remove a configuração específica de um tenant, ele volta a herdar a configuração global automaticamente.
5. **Admin do escritório (tenant) não tem acesso** a nenhuma tela ou API de configuração de LLM. Essa restrição é aplicada por RBAC no nível da API.

**Consequência para manutenabilidade:** Na maioria dos casos, o super admin gerencia **apenas a configuração global**. Overrides por tenant são exceções, não a regra — reduzindo a carga administrativa de O(N tenants) para O(1 + exceções).

Tradeoffs aceitos:

- Mais tabelas no banco para prompts e configuração de provedores. Aceitável — são tabelas de configuração com poucos registros.
- Cache de prompts em memória necessário. Aceitável — revalidação a cada 5 minutos via TTL.
- Complexidade inicial. Aceitável — o port/adapter isolado justifica pela flexibilidade futura.

---

# 6. Consequences

Positive Consequences:

- Troca de provedor LLM sem deploy. Apenas atualizar a configuração no banco.
- Prompts editáveis pelo super admin global da plataforma. Novos tipos de formatação sem desenvolvedor.
- Fallback em cascata previne downtime do chatbot por falha de LLM.
- Custo otimizável: usar Flash para formatação simples, Pro para análise complexa.
- Observabilidade de custo por tenant: tokens consumidos, latência, provedor usado.

Negative Consequences:

- Mais tabelas e entidades para gerenciar (llm_providers, llm_prompt_templates).
- Cache de prompts adiciona complexidade (invalidação, TTL).
- Mascaramento de PII antes de enviar ao LLM requer lógica adicional.

Neutral Consequences:

- O módulo WhatsApp ganha uma nova dependência de outbound port (`LlmResponsePort`).
- Métricas Prometheus adicionais para LLM.

---

# 7. Impact

- **Architecture:** Novo outbound port `LlmResponsePort` no módulo WhatsApp. Adapters: `GeminiLlmAdapter` (Phase 1), futuramente `OpenAiLlmAdapter`, `OllamaLlmAdapter`. Novas entidades de domínio: `LlmProvider` (configuração), `LlmPromptTemplate` (prompts). Nova tabela de configuração: `llm_providers`.
- **Infrastructure:** Sem containers adicionais. APIs de LLM são externas (Gemini API). API keys armazenadas com criptografia AES-256 (padrão existente para tokens WhatsApp).
- **Security:** Dados de PII (Documento, nome, valores) devem ser mascarados ou categorizados antes de enviar ao LLM. API keys criptografadas em repouso. Auditoria de chamadas LLM por tenant.
- **Development Process:** Adapter de novo provedor LLM requer apenas implementação de `LlmResponsePort` (uma classe). Novos prompts adicionados via painel do super admin global ou migration SQL.
- **Data Architecture:** 4 tabelas: `llm_providers` (configuração de provedores), `llm_prompt_templates` (prompts configuráveis por função), `llm_usage_log` (log de consumo por tenant), `llm_tenant_quotas` (quotas por tenant). Providers e templates com `tenant_id` nullable (NULL = global).
- **Observability:** Métricas: `llm_request_total`, `llm_request_duration_seconds`, `llm_tokens_input_total`, `llm_tokens_output_total`, `llm_errors_total`, `llm_fallback_total`. Conforme ADR-0012 v1.2, consumo aceita `provider=OPENAI|GEMINI|ANTHROPIC|CUSTOM|OLLAMA`; apenas o timer de latência também aceita `FALLBACK`, que representa ausência de provider efetivo. Tenant, modelo e função permanecem no `llm_usage_log`/trace protegido.
- **Cost Management:** Cada chamada LLM gera um registro em `llm_usage_log` com tokens consumidos e custo estimado. Dashboard do super admin agrega custo por tenant, por provedor, e por período. Quotas configuráveis por tenant em `llm_tenant_quotas`.
- **DevOps:** API key do Gemini em variável de ambiente ou Vault. Sem alteração na infraestrutura Docker Compose.

---

# 8. Governança de Configuração e Gestão de Custos LLM

## 8.1 Governança de Acesso

| Ação | Super Admin Global | Admin do Escritório (Tenant) |
|---|---|---|
| Cadastrar/editar provedor LLM | ✅ Permitido | ❌ Sem acesso |
| Cadastrar/editar prompt templates | ✅ Permitido | ❌ Sem acesso |
| Definir provedor/modelo por tenant (override) | ✅ Permitido | ❌ Sem acesso |
| Configurar quotas por tenant | ✅ Permitido | ❌ Sem acesso |
| Visualizar dashboard de custos (todos os tenants) | ✅ Permitido | ❌ Sem acesso |
| Visualizar consumo próprio (somente seu tenant) | ❌ N/A | ❌ Sem acesso (fase 1) |
| Gerenciar API keys de provedores | ✅ Permitido | ❌ Sem acesso |

**Aplicação técnica:** O controle de acesso é aplicado via **RBAC** na camada de API (Spring Security). Endpoints de configuração de LLM (`/api/admin/llm/**`) exigem a role `ROLE_SUPER_ADMIN`. Nenhuma role de tenant admin concede acesso a esses endpoints.

## 8.2 Gestão de Custos e Rastreabilidade de Consumo

O super admin precisa de **visibilidade total** sobre o consumo de LLM para tomar decisões de custo e identificar anomalias. A rastreabilidade é implementada em 3 camadas:

### Camada 1 — Log de Consumo (`llm_usage_log`)

Cada chamada LLM gera um registro com:
- **tenant_id** — qual escritório originou a chamada
- **provider_type + model** — qual provedor e modelo foi usado
- **input_tokens + output_tokens** — tokens consumidos
- **estimated_cost_usd** — custo estimado baseado na tabela de preços do provedor
- **was_fallback** — se o fallback foi ativado (indica problemas no provedor principal)
- **latency_ms** — latência para monitoramento de performance

Este log permite ao super admin **auditar e atribuir custo** por tenant de forma granular.

### Camada 2 — Quotas por Tenant (`llm_tenant_quotas`)

O super admin pode definir limites por tenant para evitar consumo excessivo:
- **max_requests_per_day** — número máximo de chamadas LLM por dia
- **max_tokens_per_day** — tokens máximos por dia
- **max_cost_usd_per_month** — teto de custo mensal em USD

Quando um tenant atinge a quota, o sistema automaticamente usa o **fallback (template fixo)** em vez de chamar o LLM — sem interromper o chatbot. O super admin recebe alerta via Prometheus/Grafana.

**Tenants sem quota configurada** não possuem limite individual, mas estão sujeitos ao rate limiting global da API key do provedor.

### Camada 3 — Dashboard e Métricas

O painel do super admin deve exibir:
- **Custo total** por período (diário, semanal, mensal)
- **Custo por tenant** — ranking de consumo
- **Custo por provedor/modelo** — comparação entre Gemini Flash vs Pro vs OpenAI
- **Tendência de crescimento** — projeção de custo futuro baseada no volume atual
- **Alertas** — tenant excedendo 80% da quota, custo total acima do orçamento

**Métricas Prometheus adicionais:**
- `llm_cost_usd_total` (label allowlisted: `provider`) — counter agregado de custo;
- `llm_quota_exceeded_total` (sem identidade) — counter agregado de quotas atingidas.

`llm_quota_usage_ratio` por tenant não é exportado ao Prometheus: a razão e os rankings por
tenant/modelo/função são derivados do `llm_usage_log` sob RBAC. Essa emenda do ADR-0012 v1.2
substitui apenas as labels antigas; não altera ledger, quotas, atribuição de custo ou dashboard.

### Modelo de Repasse de Custos

O custo de LLM pode ser tratado de 3 formas no modelo de negócio do SaaS (decisão do Product Owner):

1. **Incluso no plano** — custo absorvido pela plataforma. Quotas funcionam como proteção contra abuso.
2. **Cobrado à parte** — consumo de tokens faturado mensalmente por tenant com base no `llm_usage_log`.
3. **Modelo híbrido** — quota inclusa no plano (ex: 10.000 tokens/dia) + excedente cobrado à parte.

> **Nota:** A decisão de modelo de repasse é de negócio, não técnica. A arquitetura suporta os 3 cenários com os dados já capturados no `llm_usage_log`.

---

# 9. AI Agent Considerations (For Autonomous Agent Environments)

Agent Roles Impacted:

- **@DomainExpert:** Modela `LlmProvider` e `LlmPromptTemplate` como entidades do bounded context WhatsApp. Define regras de fallback como lógica de domínio.
- **@CleanArchitecture:** Define `LlmResponsePort` (outbound port) e valida que o domínio não importa SDKs de LLM. Valida isolamento via ArchUnit.
- **@ImplementerCore:** Implementa `LlmResponseService` (orquestra prompt + chamada LLM + fallback). Integra o serviço no `ChatbotFlowService` entre resultado SERPRO e envio WhatsApp.
- **@AdapterDev:** Implementa `GeminiLlmAdapter` (adapter para Gemini API via REST). Futuramente `OpenAiLlmAdapter`, `OllamaLlmAdapter`.
- **@SecurityOAuth:** Implementa mascaramento de PII antes de enviar dados ao LLM. Gerencia criptografia de API keys.
- **@TestAutomator:** Testes unitários: mock de `LlmResponsePort`, fallback chain. Testes de integração: chamada real ao Gemini com prompt de teste. Testes de arquitetura: ArchUnit valida que domínio não importa SDKs.
- **@FrontendWeb:** Implementa telas do painel do **super admin global**: CRUD de provedores LLM, CRUD de prompt templates, preview de resposta. Essas telas **não** são acessíveis ao admin do escritório (tenant).

Operational Considerations:

- API keys de LLM devem ser injetadas via variáveis de ambiente, nunca hardcoded.
- Rate limiting por tenant para chamadas LLM — evitar que um tenant consuma toda a quota.
- Circuit breaker (Resilience4j) na chamada ao LLM. Tempo limite de 10 segundos por chamada.
- Log de tokens consumidos por chamada para estimativa de custo.

LLM Considerations:

- **Token optimization:** Para formatação de dados SERPRO, o input é estruturado (JSON). Usar system prompt conciso para minimizar tokens.
- **Modelo por complexidade:** `gemini-2.0-flash` para formatação simples (pendências, CND). `gemini-2.0-pro` para análise de dados complexos (se necessário futuro).
- **Temperatura baixa (0.2-0.3):** Respostas de formatação devem ser consistentes, não criativas.
- **Max tokens:** 1024 é suficiente para maioria das respostas WhatsApp (limite de 4096 chars da Cloud API).
- **Custo estimado:** ~$0.10/1M tokens (Gemini Flash). Para 1000 consultas/dia com ~500 tokens/consulta = ~$0.05/dia = ~R$1.50/mês.

Safety Considerations:

- LLM **nunca** gera dados fiscais — apenas formata dados reais vindos do SERPRO.
- Se o LLM "alucinar" dados que não estavam no input SERPRO, o fallback (template fixo) deve ser usado.
- Mascarar CPF/Documento completo antes de enviar ao LLM: `56.917.836/0001-00` → `**.917.836/****-**`.
- Nunca enviar certificados digitais ou tokens de acesso ao LLM.

---

# 10. Implementation Plan

## Phase 1 — Gemini Adapter + Prompt Templates (Sprint 3)

### Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                  WHATSAPP MODULE                             │
│                                                              │
│  ChatbotFlowService                                          │
│       │                                                      │
│       ▼                                                      │
│  ┌───────────────────────────────────────┐                  │
│  │       LlmResponseService              │                  │
│  │                                       │                  │
│  │  1. Busca prompt template por função  │                  │
│  │  2. Substitui {{variáveis}}           │                  │
│  │  3. Mascara PII                       │                  │
│  │  4. Chama LlmResponsePort            │                  │
│  │  5. Se falhar → fallback             │                  │
│  │  6. Retorna texto formatado           │                  │
│  └───────────┬───────────────────────────┘                  │
│              │                                               │
│  ┌───────────▼───────────────────────────┐                  │
│  │       LlmResponsePort (interface)     │                  │
│  │                                       │                  │
│  │  String generateResponse(             │                  │
│  │    String systemPrompt,               │                  │
│  │    String userPrompt,                 │                  │
│  │    LlmConfig config                   │                  │
│  │  )                                    │                  │
│  └───────────┬───────────────────────────┘                  │
│              │                                               │
│  ─ ─ ─ ─ ─ ─│─ ─ ─ ─ ─ ADAPTER LAYER ─ ─ ─ ─ ─ ─ ─ ─    │
│              │                                               │
│  ┌───────────▼──────────┐  ┌────────────────────┐          │
│  │  GeminiLlmAdapter    │  │  FallbackAdapter    │          │
│  │  (Phase 1 — default) │  │  (Template fixo)    │          │
│  │                      │  │                     │          │
│  │  Gemini API REST     │  │  String.format()    │          │
│  │  gemini-2.0-flash    │  │  sem LLM            │          │
│  └──────────────────────┘  └─────────────────────┘          │
│                                                              │
│  ┌──────────────────────────────────────────┐               │
│  │   DATABASE (saas_whatsapp)               │               │
│  │   llm_providers | llm_prompt_templates   │               │
│  └──────────────────────────────────────────┘               │
└─────────────────────────────────────────────────────────────┘
```

### Fluxo de Execução

```
1. Usuário clica [Consulta de Pendências] no WhatsApp
2. ChatbotFlowService → publica FiscalQueryRequestedEvent
3. Módulo Fiscal → consulta SERPRO → retorna FiscalQueryResultEvent
4. ChatbotFlowService recebe resultado SERPRO
    ↓
5. LlmResponseService.formatResponse(functionType, serproData, tenant)
    ↓
6. Busca LlmPromptTemplate WHERE function_type='PENDENCIAS' AND tenant_id=?
   (ou global se tenant não tem template próprio)
    ↓
7. Substitui variáveis: {{nome_cliente}}, {{razao_social}}, {{dados_serpro}}
    ↓
8. Mascara PII no prompt montado
    ↓
9. Busca LlmProvider ativo do tenant (ou default global)
    ↓
10. Chama LlmResponsePort.generateResponse(systemPrompt, userPrompt, config)
    ↓
11. GeminiLlmAdapter → POST https://generativelanguage.googleapis.com/v1beta/...
    ↓
    ┌─ SUCESSO → retorna texto formatado
    └─ FALHA → FallbackAdapter → template fixo String.format()
    ↓
12. ChatbotFlowService envia mensagem formatada via WhatsAppMessagePort
```

### Data Model

```sql
-- Provedores de LLM configurados
CREATE TABLE llm_providers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID,                          -- NULL = global (default do sistema)
    name VARCHAR(50) NOT NULL,               -- "Gemini", "OpenAI", "Ollama"
    provider_type VARCHAR(30) NOT NULL,      -- GEMINI, OPENAI, OLLAMA
    api_key_encrypted TEXT,                  -- API key criptografada (AES-256)
    base_url VARCHAR(500),                   -- URL base (para Ollama local)
    default_model VARCHAR(100) NOT NULL,     -- "gemini-2.0-flash"
    default_temperature FLOAT DEFAULT 0.3,
    default_max_tokens INT DEFAULT 1024,
    is_primary BOOLEAN DEFAULT TRUE,         -- provedor principal
    is_fallback BOOLEAN DEFAULT FALSE,       -- provedor de fallback
    is_active BOOLEAN DEFAULT TRUE,
    priority INT DEFAULT 0,                  -- 0 = principal, 1 = fallback
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Templates de prompt por função
CREATE TABLE llm_prompt_templates (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID,                          -- NULL = global (default do sistema)
    function_type VARCHAR(50) NOT NULL,      -- PENDENCIAS, DARF, CND, SITUACAO_CADASTRAL
    name VARCHAR(200) NOT NULL,              -- "Pendências - Amigável"
    system_prompt TEXT NOT NULL,             -- instrução do sistema
    user_prompt_template TEXT NOT NULL,      -- template com {{variáveis}}
    fallback_template TEXT,                  -- template fixo (sem LLM)
    tone VARCHAR(20) DEFAULT 'FRIENDLY',    -- FRIENDLY, FORMAL, CONCISE
    model_override VARCHAR(100),            -- sobrescreve o modelo default do provider
    temperature_override FLOAT,
    max_tokens_override INT,
    variables JSONB NOT NULL,               -- ["nome_escritorio", "nome_cliente", ...]
    version INT DEFAULT 1,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
CREATE INDEX idx_llm_prompt_tenant ON llm_prompt_templates(tenant_id);
CREATE INDEX idx_llm_prompt_function ON llm_prompt_templates(function_type);

-- Log de consumo de LLM por tenant (rastreabilidade de custo)
CREATE TABLE llm_usage_log (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL,                 -- tenant que originou a chamada
    provider_id UUID NOT NULL REFERENCES llm_providers(id),
    provider_type VARCHAR(30) NOT NULL,      -- GEMINI, OPENAI, OLLAMA
    model VARCHAR(100) NOT NULL,             -- modelo usado (ex: gemini-2.0-flash)
    function_type VARCHAR(50) NOT NULL,      -- PENDENCIAS, DARF, CND, etc.
    input_tokens INT NOT NULL,               -- tokens de entrada consumidos
    output_tokens INT NOT NULL,              -- tokens de saída consumidos
    total_tokens INT GENERATED ALWAYS AS (input_tokens + output_tokens) STORED,
    estimated_cost_usd NUMERIC(10,6),        -- custo estimado em USD
    latency_ms INT,                          -- latência da chamada em ms
    was_fallback BOOLEAN DEFAULT FALSE,      -- se usou fallback
    status VARCHAR(20) NOT NULL,             -- SUCCESS, FALLBACK, ERROR
    error_message TEXT,                      -- mensagem de erro (se houve)
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
CREATE INDEX idx_llm_usage_tenant ON llm_usage_log(tenant_id);
CREATE INDEX idx_llm_usage_created ON llm_usage_log(created_at);
CREATE INDEX idx_llm_usage_provider ON llm_usage_log(provider_type);

-- Configuração de quotas de LLM por tenant
CREATE TABLE llm_tenant_quotas (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL UNIQUE,          -- um registro por tenant
    max_requests_per_day INT,                -- limite de chamadas LLM por dia (NULL = sem limite)
    max_tokens_per_day INT,                  -- limite de tokens por dia (NULL = sem limite)
    max_cost_usd_per_month NUMERIC(10,2),   -- limite de custo mensal em USD (NULL = sem limite)
    is_active BOOLEAN DEFAULT TRUE,          -- se quotas estão ativas para este tenant
    created_by VARCHAR(100) NOT NULL,        -- super admin que configurou
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
```

### Implementation Tasks

1. **Domain Model:** `LlmProvider` (entity), `LlmPromptTemplate` (entity), `LlmConfig` (value object — model, temperature, maxTokens), `FormattedResponse` (value object — text + metadata).

2. **Outbound Port:** `LlmResponsePort` (interface) — `String generateResponse(String systemPrompt, String userPrompt, LlmConfig config)`.

3. **Primary Adapter:** `GeminiLlmAdapter` implements `LlmResponsePort`. Usa REST client (WebClient) para Gemini API. Endpoint: `POST https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent`.

4. **Fallback Adapter:** `FixedTemplateFallbackAdapter` implements `LlmResponsePort`. Usa `String.format()` com template fixo da coluna `fallback_template`.

5. **Domain Service:** `LlmResponseService` — orquestra busca de prompt, substituição de variáveis, mascaramento de PII, chamada ao port, e lógica de fallback.

6. **Integration:** `ChatbotFlowService` chama `LlmResponseService.formatResponse()` após receber resultado do SERPRO e antes de enviar via `WhatsAppMessagePort`.

7. **Flyway Migrations:** Tabelas `llm_providers` e `llm_prompt_templates`. Seeds com templates default para pendências e DARF.

8. **Admin API:** REST endpoints para CRUD de providers e prompt templates.

Responsible agents: @DomainExpert, @ImplementerCore, @AdapterDev, @SecurityOAuth, @TestAutomator, @FrontendWeb

Dependencies: ADR-0004 (módulo WhatsApp), módulo Fiscal operacional (eventos SERPRO). Gemini API key disponível.

Rollback plan: Se a LLM falhar completamente, o `FixedTemplateFallbackAdapter` assume. O chatbot continua funcionando com formatação básica (sem IA). O fallback é automático — sem intervenção humana.

## Phase 2 — Segundo Provedor + Painel Admin (Sprint 5+)

- Implementar `OpenAiLlmAdapter` como provedor de fallback
- Tela **super admin global**: CRUD de provedores (API key, modelo, prioridade)
- Tela **super admin global**: CRUD de prompt templates (edição, preview, teste com dados fictícios)
- Seleção de provedor por tenant (configurada pelo super admin global)

## Phase 3 — Modelo Local (Futuro)

- Implementar `OllamaLlmAdapter` para modelos locais (custo zero de tokens)
- Deploy de Ollama como container Docker na VPS
- Ideal para escritórios com volume alto e preocupação com LGPD (dados não saem do servidor)

---

# 11. Validation

Architecture Validation:

- ArchUnit: módulo WhatsApp domain não importa SDK do Gemini (`com.google.cloud` ou `dev.langchain4j`).
- ArchUnit: `LlmResponsePort` é interface no package `..application.port.out..`.
- Spring Modulith `ApplicationModules.verify()` passa sem erros.

Unit Tests:

- Test: `LlmResponseService` formata resposta corretamente com mock de `LlmResponsePort`.
- Test: Fallback ativado quando `LlmResponsePort` lança exceção.
- Test: Substituição de variáveis `{{nome_cliente}}` funciona corretamente no prompt template.
- Test: Mascaramento de PII — Documento mascarado antes de enviar ao LLM.
- Test: Template fixo (fallback) formata dados mínimos sem LLM.

Integration Tests:

- Test: `GeminiLlmAdapter` — chamada real ao Gemini API com prompt de teste (usar WireMock para CI).
- Test: Fluxo completo: resultado SERPRO → LlmResponseService → resposta formatada.
- Test: Provedor desabilitado → fallback automático.
- Test: Multi-tenant — tenant A usa Gemini, tenant B usa template fixo.

Performance Benchmarks:

- Latência do Gemini API: < 3 segundos por chamada (p95).
- Custo: < R$5/mês para 1000 consultas/dia (Gemini Flash).

Success Criteria:

- Respostas do chatbot formatadas com emojis, agrupamentos e totais — indistinguíveis do ContaMatriz atual.
- Fallback funciona sem intervenção manual.
- Troca de provedor por configuração, sem deploy.
- Super admin global pode editar prompt e ver preview imediato.

---

# 12. Risks and Mitigations

Risk 1:
Description: Gemini API indisponível — chatbot para de formatar respostas.
Mitigation: Fallback automático em cascata: provedor secundário (se configurado) → template fixo (`FixedTemplateFallbackAdapter`) → mensagem básica com dados tabulados. O chatbot nunca para.

Risk 2:
Description: LLM "alucina" dados fiscais que não estavam no input SERPRO.
Mitigation: Temperatura baixa (0.2-0.3). Prompt explícito: "Use APENAS os dados fornecidos. NÃO invente valores." Validação pós-resposta: verificar se valores numéricos na resposta existem no input SERPRO. Se divergir, usar fallback.

Risk 3:
Description: Custo de tokens excede orçamento conforme volume de mensagens cresce.
Mitigation: Monitoramento de tokens por tenant via `llm_usage_log` protegido e métricas Prometheus
agregadas por provider allowlisted. Rate limiting de chamadas LLM por tenant. Cache de respostas
LLM para consultas idênticas (TTL 1h). Migração para modelo mais barato (`flash-lite`) ou local
(`Ollama`).

Risk 4:
Description: Dados de PII (Documento, razão social, valores) enviados ao provedor LLM violam LGPD.
Mitigation: Mascaramento de PII antes de enviar ao LLM. Documento mascarado: `**.917.836/****-**`. Razão social mantida (informação pública). Valores financeiros mantidos (necessários para formatação). Fase 3: opção de modelo local (Ollama) onde dados não saem do servidor.

Risk 5:
Description: Prompts mal configurados geram respostas inadequadas ou incorretas.
Mitigation: Botão "Preview" no painel do super admin global: testa o prompt com dados fictícios antes de salvar. Templates default criados pelo time SaaS como baseline. Histórico de versões de prompts para rollback.

---

# 13. Related ADRs

- [ADR-0001 — Technology Stack and Architecture Foundation](./ADR-0001-technology-stack-and-architecture.md) — Java 21, Spring Boot 4.x, Spring Modulith, Clean Architecture.
- [ADR-0004 — WhatsApp Integration Architecture](./ADR-0004-whatsapp-integration-architecture.md) — Módulo WhatsApp, `ChatbotFlowService`, `WhatsAppMessagePort`. A LLM se integra entre o resultado SERPRO e o envio WhatsApp.
- [ADR-0005 — Multi-Tenancy Architecture](./ADR-0005-multi-tenancy-architecture.md) — Configuração de LLM pode variar por tenant.
- (Futuro) ADR-0008 — Function Registry e Menu Dinâmico do Chatbot.

---

# 14. References

- [Google Gemini API](https://ai.google.dev/gemini-api/docs)
- [Gemini API — Generate Content](https://ai.google.dev/gemini-api/docs/text-generation)
- [Gemini Pricing](https://ai.google.dev/pricing)
- [OpenAI API](https://platform.openai.com/docs/api-reference)
- [Ollama](https://ollama.com/) — Run LLMs locally
- [WhatsApp Integration Architecture — ADR-0004](./ADR-0004-whatsapp-integration-architecture.md)
- Business Requirements: [Visão de produto](../product/business/product-vision.md)

---

# 15. Decision Lifecycle

Current State: **Accept**

Este ADR foi criado e está aguardando revisão. Após aceite, torna-se o documento governante para todas as decisões de integração LLM no Contador Fiscal Inteligente.

---

# 16. Change Log

Version: 1.2
Date: 2026-08-23
Author: Codex / @ObservabilityDev / @SecurityAgent
Changes:
- Reconciliada observabilidade com ADR-0012 v1.2: removidos tenant/modelo/função de labels;
  `provider` usa allowlist fechada e análises tenant-scoped permanecem no ledger protegido.
- Removido o gauge Prometheus tenant-scoped de quota; dashboard continua derivado do
  `llm_usage_log`, sem perda de atribuição financeira.

Version: 1.1
Date: 2026-03-11
Author: @AgentOrchestrator
Changes:
- Adicionada seção 8: Governança de Configuração e Gestão de Custos LLM.
- Formalizado modelo de herança: configuração global (tenant_id = NULL) como default obrigatório, com override por tenant sob demanda do super admin.
- Clarificado que **todas** as configurações de LLM são competência exclusiva do **super admin global** — admin do escritório (tenant) não tem acesso.
- Adicionadas tabelas: `llm_usage_log` (rastreabilidade de consumo/custo por tenant) e `llm_tenant_quotas` (quotas configuráveis por tenant).
- Adicionada matriz RBAC de governança de acesso.
- Adicionadas métricas Prometheus: `llm_cost_usd_total`, `llm_quota_usage_ratio`, `llm_quota_exceeded_total`.
- Documentadas 3 opções de modelo de repasse de custos (incluso no plano, cobrado à parte, híbrido).
- Data Architecture atualizada de 2 para 4 tabelas.

Version: 1.0
Date: 2026-03-11
Author: @ImplementerCore, @AgentOrchestrator
Changes:
- Criação inicial do ADR definindo a arquitetura de integração multi-provedor LLM.
- Cobre: Clean Architecture com `LlmResponsePort`, Gemini como provedor inicial, prompt templates configuráveis, fallback em cascata, mascaramento de PII, modelo de dados, e integração com o fluxo do chatbot WhatsApp (ADR-0004).

---

# 17. Repository Structure

All ADRs are stored in:

```
docs/
  adrs/
    ADR-0001-technology-stack-and-architecture.md
    ADR-0002-separacao-banco-por-contexto-multitenancy.md
    ADR-0003-multitenancy-schema-vs-tenant-id.md
    ADR-0004-whatsapp-integration-architecture.md
    ADR-0005-multi-tenancy-architecture.md
    ADR-0006-audit-compliance.md
    ADR-0007-multi-provider-llm-integration.md    ← NEW
```

---

# 18. Review Process

1. Este ADR foi criado em status "Proposed" por @ImplementerCore e @AgentOrchestrator.
2. Reviewers (@CleanArchitecture, @DomainExpert, @SecurityOAuth, @AdapterDev) devem validar: isolamento de infraestrutura LLM, mascaramento de PII, e padrão de fallback.
3. Os fundadores da startup devem confirmar: escolha do Gemini como provedor inicial, e estratégia de custo.
4. Após aprovação, status muda para "Accepted" e o ADR torna-se imutável.

---

# 19. Notes

Este ADR define a **integração LLM** como componente do módulo WhatsApp. A LLM **não é um módulo separado** — ela é um outbound port do módulo WhatsApp, assim como o `WhatsAppMessagePort` e o `SerproGatewayPort`.

Pontos-chave:

- **A LLM não gera dados** — ela apenas **formata** dados reais vindos do SERPRO. Isso reduz drasticamente o risco de alucinação.
- **Fallback é obrigatório** — o chatbot funciona com ou sem LLM. A IA é um "upgrade" de UX, não uma dependência crítica.
- **Custo previsível** — com Gemini Flash e volume estimado (1000 consultas/dia), o custo é ~R$1.50/mês. Inferior ao custo de um template formatter manual.
- **Evolução gradual** — Phase 1 apenas Gemini. Phase 2 adiciona segundo provedor e admin panel. Phase 3 opção local (Ollama) para LGPD.

Fluxo de dados simplificado:

```
SERPRO (dados crus) → Mascaramento PII → Prompt Template → LLM → Resposta formatada → WhatsApp
```
