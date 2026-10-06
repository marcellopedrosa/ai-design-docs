---
document_id: "ADR-0012"
primary_nature: "Decisao"
objective: "Registrar a decisão arquitetural “Padronização de Tratamento de Erros e Observabilidade (Logs, Trace e Métricas)”, seus motivadores, alternativas e consequências."
scope: "Decisão, componentes, integrações e limites explicitamente descritos em “Padronização de Tratamento de Erros e Observabilidade (Logs, Trace e Métricas)”."
non_objectives: "Não implementar a decisão, substituir requisitos relacionados nem atestar capabilities ou ambientes sem evidência explícita."
owner: "@AgentOrchestrator, @ImplementerCore"
status: "Accepted"
date: "2026-04-17"
version: "1.2"
keywords: "adr, decisao, arquitetura, padronização, de, tratamento, de, erros, e, observabilidade, logs, trace, e, métricas"
related_files: "docs/adrs/README.md, docs/adrs/ADR-0001-technology-stack-and-architecture.md, docs/adrs/ADR-0002-separacao-banco-por-contexto-multitenancy.md, docs/adrs/ADR-0004-whatsapp-integration-architecture.md, docs/adrs/ADR-0005-multi-tenancy-architecture.md, docs/adrs/ADR-0006-audit-compliance.md, docs/adrs/ADR-0007-multi-provider-llm-integration.md, docs/adrs/ADR-0023-agnostic-payment-provider-integration.md, docs/adrs/ADR-0008-stripe-billing-subscription.md, docs/adrs/ADR-0010-tenant-plan-parametrization.md"
code_references: "FiscalQueryRequestedEvent, FiscalQueryResultEvent, docker-compose.yml, TenantContextFilter, ModuleMdcFilter, ResponseEntity, TraceIdResponseFilter, TenantLimitAlertEvent"
principal_statement: "O sistema padroniza erros HTTP em RFC 7807, exceções de domínio, correlation ID, logs JSON, observabilidade self-hosted e métricas com dimensões finitas e allowlisted, sem identificadores de tenant, usuário ou recurso como labels."
---

# ADR-0012 - Padronização de Tratamento de Erros e Observabilidade (Logs, Trace e Métricas)

- Date: 2026-04-17
- Status: Accepted
- Version: 1.2
- Authors / Owners: @AgentOrchestrator, @ImplementerCore
- Reviewers: @CleanArchitecture, @DomainExpert, @AdapterDev, @DevOps-Agent
- Stakeholders: Engineering Team, Product Owner, Startup Founders

---

# 1. Context

O Contador Fiscal Inteligente é um SaaS multi-tenant (ADR-0005) com 5 bounded contexts (ADR-0002), comunicação assíncrona via Spring Modulith Events (ADR-0001), e 4 integrações externas críticas protegidas por Resilience4j (ADR-0011). A aplicação roda numa VPS única com Docker Compose (ADR-0001).

**O problema:** Atualmente, não existe um padrão unificado para:

1. **Como erros são representados no domínio** — cada módulo usa exceções diferentes, com mensagens inconsistentes. O frontend não sabe como parsear respostas de erro de maneira previsível.
2. **Como erros HTTP são retornados ao cliente** — não há formato padronizado de response body de erro. Cada controller pode retornar um JSON diferente, dificultando o tratamento genérico no frontend React (ADR-0001).
3. **Como rastrear uma requisição cross-module** — quando o cliente WhatsApp faz uma consulta fiscal, a request atravessa: Webhook WhatsApp → módulo `whatsapp` → evento `FiscalQueryRequestedEvent` → módulo `fiscal` → SERPRO → evento `FiscalQueryResultEvent` → módulo `whatsapp` → LLM → Meta Cloud API. Se algo falha no meio, como achar o ponto de falha?
4. **Como logs são estruturados** — sem padrão, logs aparecem como texto livre inconsistente, impossibilitando queries no Grafana/Loki.
5. **Como métricas de negócio são expostas** — Spring Boot Actuator fornece métricas técnicas (JVM, HTTP), mas métricas de negócio agregadas (consultas fiscais/dia, mensagens por canal e faturas por plano/meio de pagamento) precisam ser definidas explicitamente. Recortes por tenant pertencem aos ledgers e relatórios tenant-scoped, nunca às tags de métricas.

**Por que é crítico agora:**

- **Debug cross-module é cego:** Se o `FiscalQueryResultEvent` falha no handler do módulo `whatsapp`, o log do módulo `fiscal` mostra sucesso (a consulta SERPRO retornou dados), mas o log do `whatsapp` mostra erro (o evento não foi processado). Sem um `correlationId` comum, o desenvolvedor precisa correlacionar timestamps manualmente — inviável com múltiplos tenants simultâneos.
- **O frontend React não tem contrato de erro:** Se o controller `/api/fiscal/queries` retorna `{ "error": "..." }` e o `/api/billing/subscriptions` retorna `{ "message": "...", "code": 500 }`, o frontend precisa de `if/else` por endpoint. Isso é inaceitável para manutenção.
- **Observabilidade inexistente em produção:** A VPS única (ADR-0001) significa que não há um time de SRE monitorando 24/7. A observabilidade precisa ser **proativa** — dashboards e alertas que antecipem problemas antes que o cliente reclame via WhatsApp.
- **Multi-tenancy nos logs:** Um log sem `tenant_id` é inútil para debug de problemas específicos de um escritório contábil. O MDC (Mapped Diagnostic Context) já é mencionado no ADR-0005, mas nunca foi formalizado como padrão obrigatório.
- **LGPD em logs:** Logs podem conter CPF, Documento, dados fiscais. Sem padrão de sanitização, logs viram um risco de compliance (ADR-0006).

Restrições:

- Infraestrutura em VPS única com Docker Compose (ADR-0001) — a stack de observabilidade deve rodar em containers Docker na mesma VPS.
- Spring Boot 4.x com Spring Boot Actuator e Micrometer já estão na stack (ADR-0001).
- Clean Architecture: tratamento de erros do domínio não deve depender de frameworks HTTP (Spring MVC) nem de libraries de logging.
- Multi-tenancy: logs/traces de acesso controlado podem conter `tenantId` como campo sanitizado;
  métricas nunca usam tenant, usuário ou identificador de recurso como label.
- Budget zero de cloud: sem Datadog, New Relic, Splunk ou qualquer SaaS de observabilidade pago.

---

# 2. Decision Statement

O sistema adotará:

1. **RFC 7807 (Problem Details for HTTP APIs)** como formato padrão para todas as respostas de erro HTTP, implementado via `@ControllerAdvice` global.
2. **Hierarquia de exceções de domínio** padronizada (`DomainException`, `BusinessRuleViolationException`, `ResourceNotFoundException`, `AccessDeniedException`) mapeada automaticamente para HTTP status codes.
3. **Correlation ID (traceId)** propagado em toda requisição — HTTP headers, MDC de logs, Spring Modulith Events, e chamadas a APIs externas — usando Micrometer Tracing com Brave (OpenZipkin).
4. **Logs estruturados em JSON** via Logback com encoder JSON, contendo obrigatoriamente: `timestamp`, `level`, `traceId`, `spanId`, `tenantId`, `userId`, `module`, `message`.
5. **Stack de observabilidade self-hosted:** Prometheus (métricas) + Loki (logs) + Tempo (traces) + Grafana (visualização e alertas), todos em containers Docker Compose.
6. **Métricas de negócio customizadas** via Micrometer, expostas ao Prometheus somente com tags
   finitas/allowlisted como `module`, operação, outcome, status, direction, plan ou provider;
   `tenant_id`, user ID e identificadores de recurso são proibidos como labels.

Esta decisão de labels v1.2 tem precedência sobre prescrições anteriores conflitantes em ADRs,
requisitos e planos. Trechos AS-IS/históricos podem permanecer como evidência do desvio somente se
marcados como não conformes/superseded; não são autorização para reintroduzir identidade ou valor
livre em séries.

---

# 3. Decision Drivers

- **Contrato previsível de erros para o frontend:** O React precisa de um formato único e documentado de response body de erro para implementar tratamento genérico (`useApiError` hook). RFC 7807 é o padrão da indústria.
- **Rastreabilidade cross-module (Distributed Tracing):** Uma requisição do chatbot WhatsApp atravessa 3+ módulos, 2+ APIs externas, e eventos assíncronos. Sem trace distribuído, debug é impossível.
- **Logs como infraestrutura, não como arte:** Logs estruturados em JSON permitem queries (por `tenantId`, por `traceId`, por nível de erro) no Grafana/Loki. Logs em texto livre são pesquisáveis apenas por `grep`.
- **Métricas de negócio para decisões:** O Product Owner precisa acompanhar totais e taxas agregados de consultas fiscais, fallback do LLM e latência do SERPRO. Quando a análise exigir corte por tenant, a fonte é o ledger/relatório tenant-scoped; séries Micrometer permanecem limitadas a dimensões finitas.
- **Compliance LGPD em logs:** Dados pessoais (CPF, email) em logs são um risco. O ADR-0006 define auditoria; este ADR define como logs operacionais tratam PII.
- **Zero custo:** Prometheus + Loki + Tempo + Grafana são open-source e rodam em containers Docker. Sem licença, sem SaaS externo.
- **Single Pane of Glass:** Grafana como dashboard unificado para métricas (Prometheus), logs (Loki) e traces (Tempo) — sem alternar entre 3 ferramentas.

---

# 4. Considered Options

## Option 1: RFC 7807 + Micrometer Tracing (Brave) + Logback JSON + PLG Stack (Selecionada)

Description: Formato de erro padronizado via RFC 7807 (`application/problem+json`). Distributed tracing via Micrometer Tracing com Brave (B3 propagation), integrado com Spring Boot Actuator. Logs em JSON via Logback com `logstash-logback-encoder`. Stack PLG (Prometheus + Loki + Tempo + Grafana) em Docker Compose para métricas, logs e traces.

Pros:
- RFC 7807 é specification-driven — frontend e backend falam a mesma linguagem de erro
- Micrometer Tracing integra nativamente com Spring Boot — zero configuração de interceptors manuais
- B3 propagation é compatível com Spring Modulith Events (via `TaskDecorator`) e WebClient (via `ExchangeFilterFunction`)
- Logback JSON encoder produz logs parseáveis por Loki sem regex complexo
- PLG stack é a alternativa open-source mais madura ao ELK stack, com footprint de memória muito menor
- Grafana unifica métricas + logs + traces em um único dashboard
- Todo o stack roda em Docker Compose — compatível com ADR-0001

Cons:
- PLG stack adiciona 4 containers Docker na VPS (Prometheus, Loki, Tempo, Grafana) — impacto de ~500MB-1GB RAM
- Loki tem limitações de full-text search comparado ao Elasticsearch (mitigado por labels estruturadas)
- Configuração inicial do Tempo (traces backend) requer tuning

## Option 2: ELK Stack (Elasticsearch + Logstash + Kibana)

Description: Stack tradicional de observabilidade com Elasticsearch para logs e traces, Logstash para pipeline, Kibana para visualização.

Pros:
- ELK é o stack mais maduro e documentado para logs
- Elasticsearch oferece full-text search poderoso
- Kibana tem visualizações avançadas

Cons:
- Elasticsearch consome 2-4GB RAM mínimo — inviável na VPS de 4GB (ADR-0001)
- Logstash consome 500MB+ RAM — pipeline heavyweight
- Licenciamento do Elastic mudou (SSPL) — não é mais open-source puro
- Kibana separado do Grafana — duas ferramentas para métricas e logs

## Option 3: Logs em Arquivo + Prometheus Only (Sem Centralização de Logs)

Description: Manter logs em arquivos locais (`/var/log/app/`) com logrotate. Usar apenas Prometheus/Grafana para métricas.

Pros:
- Zero overhead de infra adicional para logs
- Simples de configurar

Cons:
- Logs não pesquisáveis sem SSH + grep manual
- Sem correlação logs ↔ métricas ↔ traces
- Sem alertas baseados em padrões de log (ex: taxa de erros por minuto)
- Não escala para múltiplos tenants
- Logs perdidos se o disco da VPS encher

## Option 4: SaaS de Observabilidade (Datadog, New Relic)

Description: Usar plataforma SaaS de observabilidade gerenciada.

Pros:
- Zero configuração de infraestrutura
- Features avançadas (APM, error tracking, synthetic monitoring)
- Suporte enterprise

Cons:
- Custo mensal significativo ($15-50/host/mês) — viola ADR-0001 (zero cloud cost)
- Dados saem da VPS para cloud externo — risco LGPD para dados de log contendo informações de tenants

---

# 5. Decision Outcome

**Option 1 (RFC 7807 + Micrometer Tracing + Logback JSON + PLG Stack)** foi selecionada.

Fatores decisivos:

- **Compatibilidade com ADR-0001:** PLG stack cabe em ~1GB RAM (Prometheus ~200MB, Loki ~200MB, Tempo ~200MB, Grafana ~200MB). Junto com o JVM (~1GB) e PostgreSQL (~500MB), totaliza ~2.5GB — viável numa VPS de 4GB.
- **Integração nativa Spring Boot:** Micrometer Tracing com Brave é auto-configurado pelo Spring Boot 4.x. Adicionar `spring-boot-starter-actuator` + `micrometer-tracing-bridge-brave` fornece tracing out-of-the-box para RestTemplate, WebClient, JDBC, Spring Modulith Events.
- **RFC 7807 é specification-driven:** O frontend React implementa um **único** error handler baseado no schema `application/problem+json`. Não precisa de `if/else` por endpoint.
- **Single source of truth:** Grafana unifica métricas (Prometheus), logs (Loki) e traces (Tempo) — o desenvolvedor não precisa alternar entre 3 ferramentas para investigar um problema.
- **Custo zero:** Todas as ferramentas são open-source Apache 2.0 ou AGPLv3 (Grafana). Sem licença, sem SaaS.

Trade-offs aceitos:

- 4 containers Docker adicionais na VPS (~1GB RAM). Aceitável porque a alternativa (debug sem observabilidade) é insustentável em produção.
- Loki é menos poderoso que Elasticsearch para full-text search. Aceitável porque logs estruturados
  em JSON permitem extrair campos como `tenantId` em consulta; identidade não vira label de stream.
- Configuração inicial do PLG stack é moderadamente complexa. Mitigado por documentação neste ADR e por Docker Compose declarativo.

---

# 6. Consequences

Positive Consequences:

- O frontend React terá um **único contrato de erro** (`application/problem+json`) com campos padronizados (`type`, `title`, `status`, `detail`, `instance`, `traceId`, `tenantId`). O hook `useApiError` trata todos os erros de forma genérica.
- Toda requisição carrega um `traceId` do ingresso HTTP até a resposta final. Um desenvolvedor cola o `traceId` no Grafana e vê logs + métricas + traces correlacionados em uma timeline.
- Logs são pesquisáveis no Grafana/Loki por campos JSON como `tenantId`, `userId`, `module`,
  `traceId`, `level` e `message`, sem promover IDs a labels de stream.
- Métricas de negócio agregadas são visualizáveis por dimensões finitas. Investigação por tenant
  usa logs/traces com acesso controlado ou relatório/audit store próprio, nunca séries Prometheus
  por UUID.
- PII é sanitizado em logs operacionais — CPF aparece como `***.***.***-XX`, Documento como `**.***.***/****-XX`.

Negative Consequences:

- 4 containers Docker adicionais na VPS consumindo ~1GB RAM no total. Mitigação: configurar limites de memória (`mem_limit`) no Docker Compose.
- `logstash-logback-encoder` produz logs em JSON, que são menos legíveis no console durante desenvolvimento local. Mitigação: profile `dev` usa `PatternLayout` texto; profile `prod` usa JSON encoder.
- Dependências Gradle adicionais: `micrometer-tracing-bridge-brave`, `logstash-logback-encoder`, `loki-logback-appender`.

Neutral Consequences:

- Todos os controllers e event handlers precisarão ser revisados para garantir que exceções de domínio são corretamente mapeadas para HTTP status codes via `@ControllerAdvice`.
- O `docker-compose.yml` da raiz ganhará 4 novos serviços (prometheus, loki, tempo, grafana) com volumes persistentes.

---

# 7. Impact

## 7.1 Hierarquia de Exceções de Domínio

Cada módulo lança exceções de domínio tipadas. O `@ControllerAdvice` global mapeia para HTTP status + RFC 7807:

```
DomainException (abstract)
├── BusinessRuleViolationException        → 422 Unprocessable Entity
│   ├── TenantLimitExceededException      → 422
│   ├── InvalidCnpjException              → 422
│   ├── CertificateExpiredException       → 422
│   ├── InsufficientCreditsException      → 422
│   └── DuplicateResourceException        → 409 Conflict
├── ResourceNotFoundException             → 404 Not Found
│   ├── TenantNotFoundException           → 404
│   ├── SubscriptionNotFoundException     → 404
│   └── ConversationNotFoundException     → 404
├── AccessDeniedException                 → 403 Forbidden
│   ├── TenantAccessDeniedException       → 403
│   └── UnauthorizedPhoneNumberException  → 403
├── ExternalServiceException              → 502 Bad Gateway
│   ├── SerproUnavailableException        → 502
│   ├── WhatsAppApiException              → 502
│   ├── PaymentProviderException          → 502
│   └── LlmProviderException             → 502
└── ConcurrencyConflictException          → 409 Conflict
```

Localização: `shared/domain/exception/` — package compartilhado entre todos os módulos.

```java
// shared/domain/exception/DomainException.java
public abstract class DomainException extends RuntimeException {
    private final String errorCode;     // ex: "TENANT.LIMIT_EXCEEDED"
    private final String i18nKey;       // ex: "error.tenant.limit.exceeded"

    protected DomainException(String errorCode, String i18nKey, String message) {
        super(message);
        this.errorCode = errorCode;
        this.i18nKey = i18nKey;
    }

    protected DomainException(String errorCode, String i18nKey, String message, Throwable cause) {
        super(message, cause);
        this.errorCode = errorCode;
        this.i18nKey = i18nKey;
    }

    public String getErrorCode() { return errorCode; }
    public String getI18nKey() { return i18nKey; }
}
```

## 7.2 RFC 7807 — Formato Padrão de Resposta de Erro

Toda resposta de erro HTTP seguirá o schema RFC 7807 (`application/problem+json`):

```json
{
  "type": "https://hub-contabil.com/errors/tenant-limit-exceeded",
  "title": "Limite de Recursos Excedido",
  "status": 422,
  "detail": "O tenant atingiu o limite máximo de 3 Documentos para o plano Start. Faça upgrade para Business.",
  "instance": "/api/v1/tenants/uuid-abc/documentos",
  "timestamp": "2026-04-17T14:00:00Z",
  "traceId": "6f4c3b2a1d0e9f8a",
  "tenantId": "uuid-abc-123",
  "errorCode": "TENANT.LIMIT_EXCEEDED",
  "i18nKey": "error.tenant.limit.exceeded",
  "violations": []
}
```

**Campos obrigatórios:**

| Campo | Tipo | Origem | Descrição |
|---|---|---|---|
| `type` | URI | Mapeamento por exception class | URI identificador do tipo de erro (serve como documentação) |
| `title` | String | Mapeamento por exception class | Resumo curto e humano do erro |
| `status` | Integer | HTTP status code | Código HTTP (422, 404, 403, 500, 502) |
| `detail` | String | `exception.getMessage()` | Descrição detalhada específica à instância do erro |
| `instance` | String | `request.getRequestURI()` | URI da request que causou o erro |
| `timestamp` | ISO 8601 | `Instant.now()` | Momento exato do erro |
| `traceId` | String | MDC / Micrometer Tracing | ID de rastreamento para busca no Grafana |
| `tenantId` | String | `TenantContext.getCurrentTenantId()` | ID do tenant (null para erros de autenticação) |
| `errorCode` | String | `DomainException.getErrorCode()` | Código estruturado para programmatic handling |
| `i18nKey` | String | `DomainException.getI18nKey()` | Chave de internacionalização para o frontend |

**Campo opcional:**

| Campo | Tipo | Quando presente | Descrição |
|---|---|---|---|
| `violations` | Array | Erros de validação (400) | Lista de campos inválidos com messages |

Exemplo de validation error (Bean Validation):

```json
{
  "type": "https://hub-contabil.com/errors/validation-failed",
  "title": "Erro de Validação",
  "status": 400,
  "detail": "Um ou mais campos contêm valores inválidos.",
  "instance": "/api/v1/tenants",
  "timestamp": "2026-04-17T14:00:00Z",
  "traceId": "6f4c3b2a1d0e9f8a",
  "tenantId": null,
  "errorCode": "VALIDATION.FAILED",
  "i18nKey": "error.validation.failed",
  "violations": [
    {
      "field": "documento",
      "message": "Documento inválido",
      "i18nKey": "error.validation.documento.invalid",
      "rejectedValue": "12.345"
    },
    {
      "field": "email",
      "message": "Email é obrigatório",
      "i18nKey": "error.validation.email.required",
      "rejectedValue": null
    }
  ]
}
```

## 7.3 GlobalExceptionHandler — @ControllerAdvice

```java
// shared/adapter/in/web/GlobalExceptionHandler.java
@ControllerAdvice
@Order(Ordered.HIGHEST_PRECEDENCE)
public class GlobalExceptionHandler {

    // 422 — Regras de negócio violadas
    @ExceptionHandler(BusinessRuleViolationException.class)
    public ResponseEntity<ProblemDetail> handleBusinessRule(
            BusinessRuleViolationException ex, HttpServletRequest request) {
        return buildProblem(ex, HttpStatus.UNPROCESSABLE_ENTITY, request);
    }

    // 404 — Recurso não encontrado
    @ExceptionHandler(ResourceNotFoundException.class)
    public ResponseEntity<ProblemDetail> handleNotFound(
            ResourceNotFoundException ex, HttpServletRequest request) {
        return buildProblem(ex, HttpStatus.NOT_FOUND, request);
    }

    // 403 — Acesso negado
    @ExceptionHandler(AccessDeniedException.class)
    public ResponseEntity<ProblemDetail> handleAccessDenied(
            AccessDeniedException ex, HttpServletRequest request) {
        return buildProblem(ex, HttpStatus.FORBIDDEN, request);
    }

    // 502 — Serviço externo falhou
    @ExceptionHandler(ExternalServiceException.class)
    public ResponseEntity<ProblemDetail> handleExternalService(
            ExternalServiceException ex, HttpServletRequest request) {
        return buildProblem(ex, HttpStatus.BAD_GATEWAY, request);
    }

    // 409 — Conflito de concorrência
    @ExceptionHandler(ConcurrencyConflictException.class)
    public ResponseEntity<ProblemDetail> handleConflict(
            ConcurrencyConflictException ex, HttpServletRequest request) {
        return buildProblem(ex, HttpStatus.CONFLICT, request);
    }

    // 400 — Validação de campos (Bean Validation)
    @ExceptionHandler(MethodArgumentNotValidException.class)
    public ResponseEntity<ProblemDetail> handleValidation(
            MethodArgumentNotValidException ex, HttpServletRequest request) {
        // Monta violations array a partir dos FieldErrors
        // ...
    }

    // 500 — Erro inesperado (catch-all)
    @ExceptionHandler(Exception.class)
    public ResponseEntity<ProblemDetail> handleUnexpected(
            Exception ex, HttpServletRequest request) {
        log.error("Erro inesperado: traceId={}", MDC.get("traceId"), ex);
        // NUNCA expor stack trace ao cliente
        return buildProblem("INTERNAL.ERROR", "error.internal",
                "Erro interno. Use o código de rastreamento para suporte.",
                HttpStatus.INTERNAL_SERVER_ERROR, request);
    }

    private ResponseEntity<ProblemDetail> buildProblem(
            DomainException ex, HttpStatus status, HttpServletRequest request) {
        ProblemDetail problem = ProblemDetail.forStatus(status);
        problem.setType(URI.create("https://hub-contabil.com/errors/" + ex.getErrorCode().toLowerCase().replace('.', '-')));
        problem.setTitle(status.getReasonPhrase());
        problem.setDetail(ex.getMessage());
        problem.setInstance(URI.create(request.getRequestURI()));
        problem.setProperty("timestamp", Instant.now());
        problem.setProperty("traceId", MDC.get("traceId"));
        problem.setProperty("tenantId", TenantContext.getCurrentTenantId().orElse(null));
        problem.setProperty("errorCode", ex.getErrorCode());
        problem.setProperty("i18nKey", ex.getI18nKey());
        problem.setProperty("violations", Collections.emptyList());
        return ResponseEntity.status(status)
                .contentType(MediaType.APPLICATION_PROBLEM_JSON)
                .body(problem);
    }
}
```

## 7.4 Correlation ID / Distributed Tracing

**Componente:** Micrometer Tracing com Brave (OpenZipkin B3 propagation).

```yaml
# application.yml
management:
  tracing:
    enabled: true
    sampling:
      probability: 1.0    # 100% em fase inicial (VPS com volume baixo)
    propagation:
      type: B3             # Header: X-B3-TraceId, X-B3-SpanId

  endpoints:
    web:
      exposure:
        include: health, info, prometheus, metrics

spring:
  application:
    name: hub-contabil
```

**Propagação do traceId em cada camada:**

```
┌─────────────────────────────────────────────────────────────────┐
│  1. HTTP Request (Ingresso)                                     │
│     Micrometer Tracing auto-injeta traceId no MDC              │
│     Header X-B3-TraceId adicionado automaticamente              │
├─────────────────────────────────────────────────────────────────┤
│  2. TenantContextFilter (ADR-0005)                              │
│     Adiciona tenantId e userId ao MDC                          │
│     MDC: {traceId, spanId, tenantId, userId}                   │
├─────────────────────────────────────────────────────────────────┤
│  3. Controller → Use Case → Domain                             │
│     MDC propagado automaticamente na mesma thread              │
├─────────────────────────────────────────────────────────────────┤
│  4. Spring Modulith Event (Assíncrono)                          │
│     TaskDecorator propaga MDC para thread do @Async handler     │
│     traceId preservado no serialized event (event_publication)  │
├─────────────────────────────────────────────────────────────────┤
│  5. Adapter → API Externa (SERPRO, WhatsApp, provider, LLM)    │
│     WebClient/RestClient propaga X-B3-TraceId automaticamente   │
│     Cria novo span child para a chamada externa                 │
├─────────────────────────────────────────────────────────────────┤
│  6. HTTP Response (Saída)                                       │
│     ResponseHeader: X-Trace-Id: {traceId}                      │
│     Body de erro (RFC 7807): "traceId": "{traceId}"             │
│     Cliente pode usar o traceId para suporte                    │
└─────────────────────────────────────────────────────────────────┘
```

**Propagação em Spring Modulith Events (crítica):**

```java
// shared/config/MdcTaskDecorator.java
public class MdcTaskDecorator implements TaskDecorator {
    @Override
    public Runnable decorate(Runnable runnable) {
        Map<String, String> contextMap = MDC.getCopyOfContextMap();
        return () -> {
            try {
                if (contextMap != null) {
                    MDC.setContextMap(contextMap);
                }
                runnable.run();
            } finally {
                MDC.clear();
            }
        };
    }
}

// shared/config/AsyncConfig.java
@Configuration
@EnableAsync
public class AsyncConfig implements AsyncConfigurer {
    @Override
    public Executor getAsyncExecutor() {
        ThreadPoolTaskExecutor executor = new ThreadPoolTaskExecutor();
        executor.setTaskDecorator(new MdcTaskDecorator());
        executor.setCorePoolSize(5);
        executor.setMaxPoolSize(20);
        executor.setThreadNamePrefix("modulith-event-");
        executor.initialize();
        return executor;
    }
}
```

**Response Header com traceId:**

```java
// shared/adapter/in/web/TraceIdResponseFilter.java
@Component
public class TraceIdResponseFilter extends OncePerRequestFilter {
    @Override
    protected void doFilterInternal(HttpServletRequest request,
                                     HttpServletResponse response,
                                     FilterChain filterChain) throws ... {
        filterChain.doFilter(request, response);
        String traceId = MDC.get("traceId");
        if (traceId != null) {
            response.setHeader("X-Trace-Id", traceId);
        }
    }
}
```

## 7.5 Logs Estruturados — Logback JSON

**Formato de log (JSON):**

```json
{
  "timestamp": "2026-04-17T14:00:00.123Z",
  "level": "ERROR",
  "logger": "c.h.fiscal.adapter.out.external.SerproFiscalAdapter",
  "message": "Falha ao consultar SERPRO: timeout após 8s",
  "traceId": "6f4c3b2a1d0e9f8a",
  "spanId": "1a2b3c4d5e6f7890",
  "tenantId": "uuid-abc-123",
  "userId": "uuid-user-456",
  "module": "fiscal",
  "errorCode": "SERPRO.TIMEOUT",
  "stackTrace": "java.net.SocketTimeoutException: Read timed out..."
}
```

**Campos MDC obrigatórios:**

| Campo MDC | Origem | Obrigatório | Descrição |
|---|---|---|---|
| `traceId` | Micrometer Tracing (automático) | ✅ | Identificador único da request/trace |
| `spanId` | Micrometer Tracing (automático) | ✅ | Identificador do span atual |
| `tenantId` | `TenantContextFilter` (ADR-0005) | ✅ | UUID do tenant (null em /health, /login) |
| `userId` | `TenantContextFilter` (ADR-0005) | ⚠️ Quando disponível | UUID do usuário autenticado |
| `module` | `ModuleMdcFilter` (por package) | ✅ | Nome do bounded context (tenant, fiscal, etc.) |

**Configuração Logback — Dual-profile:**

```xml
<!-- logback-spring.xml -->
<configuration>
    <!-- Profile DEV: texto legível no console -->
    <springProfile name="dev">
        <appender name="CONSOLE" class="ch.qos.logback.core.ConsoleAppender">
            <encoder>
                <pattern>%d{HH:mm:ss.SSS} %highlight(%-5level) [%X{traceId:-}] [%X{tenantId:-}] %cyan(%-40.40logger{39}) : %msg%n</pattern>
            </encoder>
        </appender>
        <root level="INFO">
            <appender-ref ref="CONSOLE" />
        </root>
    </springProfile>

    <!-- Profile PROD: JSON estruturado para Loki -->
    <springProfile name="prod">
        <appender name="LOKI" class="com.github.loki4j.logback.Loki4jAppender">
            <http>
                <url>http://loki:3100/loki/api/v1/push</url>
            </http>
            <format>
                <label>
                    <pattern>app=hub-contabil,level=%level,module=%X{module:-unknown}</pattern>
                </label>
                <message class="com.github.loki4j.logback.JsonLayout">
                    <customProviders>
                        <customProvider class="net.logstash.logback.composite.loggingevent.MdcJsonProvider"/>
                    </customProviders>
                </message>
            </format>
        </appender>
        <root level="INFO">
            <appender-ref ref="LOKI" />
        </root>
    </springProfile>
</configuration>
```

**Regras de Sanitização de PII em logs:**

| Dado | Formato Original | Formato Sanitizado | Regra |
|---|---|---|---|
| CPF | `123.456.789-00` | `***.***.*89-00` | Últimos 5 caracteres visíveis |
| Documento | `12.345.678/0001-90` | `**.***.**8/0001-90` | Últimos 8 caracteres visíveis |
| Email | `joao@email.com` | `j***@email.com` | Primeira letra + domínio |
| Phone | `+5511999887766` | `+55119****7766` | Primeiros 5 + últimos 4 dígitos |

Implementado via `PiiMaskingConverter` no Logback:

```java
// shared/config/logging/PiiMaskingConverter.java
public class PiiMaskingConverter extends ClassicConverter {
    private static final Pattern CPF = Pattern.compile("\\d{3}\\.\\d{3}\\.\\d{3}-\\d{2}");
    private static final Pattern Documento = Pattern.compile("\\d{2}\\.\\d{3}\\.\\d{3}/\\d{4}-\\d{2}");
    // ... sanitiza message antes de logar
}
```

## 7.6 Métricas de Negócio Customizadas

Além das métricas técnicas do Actuator (JVM, HTTP, HikariCP) e das métricas de resiliência do Resilience4j (ADR-0011), o sistema expõe métricas de negócio via Micrometer:

```java
// Exemplo de métricas de negócio customizadas
@Component
public class FiscalMetrics {
    private final MeterRegistry registry;

    // Counter: Consultas fiscais realizadas
    public void recordFiscalQuery(String queryType, String result) {
        Counter.builder("business.fiscal.queries.total")
            .tag("query_type", queryType)    // "pendencias", "darf", "cnd"
            .tag("result", result)           // "success", "failure", "fallback"
            .register(registry)
            .increment();
    }

    // Timer: Latência end-to-end de consulta fiscal
    public Timer.Sample startFiscalQueryTimer() {
        return Timer.start(registry);
    }
    public void stopFiscalQueryTimer(Timer.Sample sample) {
        sample.stop(Timer.builder("business.fiscal.query.duration").register(registry));
    }

    // Gauge: documentos ativos agregados
    public void registerActiveDocumentosGauge(Supplier<Number> supplier) {
        Gauge.builder("business.tenant.active_documentos", supplier).register(registry);
    }
}
```

**Catálogo de Métricas de Negócio:**

| Métrica | Tipo | Tags | Descrição |
|---|---|---|---|
| `business.fiscal.queries.total` | Counter | `query_type`, `result` | Total agregado de consultas fiscais |
| `business.fiscal.query.duration` | Timer | nenhuma | Latência end-to-end agregada |
| `business.whatsapp.messages.total` | Counter | `direction` (in/out) | Mensagens WhatsApp enviadas/recebidas |
| `business.whatsapp.sessions.active` | Gauge | nenhuma | Sessões de chatbot ativas agregadas |
| `business.billing.invoices.generated` | Counter | `plan` | Faturas geradas |
| `business.billing.revenue.total` | Counter | `plan`, `payment_method` | Receita processada (em centavos) |
| `business.tenant.active_documentos` | Gauge | nenhuma | Documentos ativos agregados |
| `business.tenant.active_users` | Gauge | nenhuma | Usuários ativos agregados |
| `business.llm.tokens.consumed` | Counter | `provider` | Tokens LLM consumidos; modelo fica no ledger de uso, não em série |
| `business.serpro.cost.accumulated` | Counter | nenhuma | Custo SERPRO acumulado (centavos) |

**Contrato fechado de dimensões (v1.2):**

| Dimensão | Valores admitidos |
|---|---|
| `module` | `admin`, `billing`, `certificates`, `clients`, `dashboard`, `fiscal`, `global`, `llm-models`, `metrics`, `notifications`, `public`, `telegram`, `tenant`, `tenants`, `user-profile`, `webhooks`, `whatsapp`, `actuator`, `swagger`, `system`, `unknown` |
| `query_type` | `pendencias`, `darf`, `cnd`, `situacao_cadastral` |
| `result` | `success`, `failure`, `fallback` |
| `direction` | `in`, `out` |
| `channel_type` | `WHATSAPP`, `TELEGRAM` |
| `reason` de bloqueio de uso | `BLOCKED`, `ERR-USAGE-001`, `ERR-USAGE-002` |
| `plan` | `START`, `BUSINESS`, `PREMIUM` |
| `payment_method` | `CARD`, `PIX`, `BOLETO` |
| `provider` de consumo LLM | `OPENAI`, `GEMINI`, `ANTHROPIC`, `CUSTOM`, `OLLAMA` |
| `provider` de latência LLM | os cinco providers de consumo mais `FALLBACK` quando nenhum provider efetivo respondeu |
| `metric_type` de uso | `SERPRO_QUERY`, `LLM_TOKEN`, `CHATBOT_MSG`, `Documento_EXTRA`, `FISCAL_QUERY` |

Valores nulos, livres ou fora da allowlist falham antes de registrar/incrementar qualquer Meter;
adicionar um valor exige alterar este ADR e o código no mesmo ciclo docs-first. `tenant_id`, modelo
LLM, código de função e demais identidades ficam nos ledgers/logs/traces protegidos, nunca em tags.
Cada gauge acima representa um total agregado e aceita exatamente um supplier por instância do
serviço/registry. Uma segunda inscrição — inclusive concorrente — é rejeitada explicitamente; se
o registro Micrometer falhar, o estado de coordenação é revertido para permitir retry seguro.

## 7.7 Stack de Observabilidade — Docker Compose

```yaml
# docker-compose.yml (serviços de observabilidade)
services:
  # ... serviços existentes (app, postgres, redis, keycloak) ...

  # ============================================================
  # OBSERVABILIDADE (PLG Stack)
  # ============================================================

  prometheus:
    image: prom/prometheus:v2.52.0
    container_name: hub-prometheus
    mem_limit: 256m
    volumes:
      - ./infra/prometheus/prometheus.yml:/etc/prometheus/prometheus.yml
      - prometheus_data:/prometheus
    ports:
      - "9090:9090"
    networks:
      - hub-network
    restart: unless-stopped

  loki:
    image: grafana/loki:3.0.0
    container_name: hub-loki
    mem_limit: 256m
    volumes:
      - ./infra/loki/loki-config.yml:/etc/loki/local-config.yaml
      - loki_data:/loki
    ports:
      - "3100:3100"
    networks:
      - hub-network
    restart: unless-stopped

  tempo:
    image: grafana/tempo:2.4.1
    container_name: hub-tempo
    mem_limit: 256m
    volumes:
      - ./infra/tempo/tempo-config.yml:/etc/tempo.yaml
      - tempo_data:/var/tempo
    ports:
      - "3200:3200"      # Tempo API
      - "4318:4318"      # OTLP HTTP
    command: [ "-config.file=/etc/tempo.yaml" ]
    networks:
      - hub-network
    restart: unless-stopped

  grafana:
    image: grafana/grafana:11.0.0
    container_name: hub-grafana
    mem_limit: 256m
    environment:
      - GF_SECURITY_ADMIN_USER=admin
      - GF_SECURITY_ADMIN_PASSWORD=${GRAFANA_ADMIN_PASSWORD}
      - GF_USERS_ALLOW_SIGN_UP=false
    volumes:
      - ./infra/grafana/provisioning:/etc/grafana/provisioning
      - grafana_data:/var/lib/grafana
    ports:
      - "3000:3000"
    depends_on:
      - prometheus
      - loki
      - tempo
    networks:
      - hub-network
    restart: unless-stopped

volumes:
  prometheus_data:
  loki_data:
  tempo_data:
  grafana_data:
```

**Diretórios de configuração em `/infra/`:**

```
infra/
├── prometheus/
│   └── prometheus.yml          # Scrape config: app:8080/actuator/prometheus
├── loki/
│   └── loki-config.yml         # Storage: filesystem, retention: 30d
├── tempo/
│   └── tempo-config.yml        # Backend: local, receiver: OTLP HTTP
└── grafana/
    └── provisioning/
        ├── datasources/
        │   └── datasources.yml # Prometheus, Loki, Tempo auto-provisioned
        └── dashboards/
            ├── dashboards.yml
            ├── jvm-overview.json
            ├── resilience.json         # ADR-0011 métricas
            ├── business-metrics.json
            └── tenant-overview.json
```

## 7.8 Dashboards Grafana Recomendados

| Dashboard | Data Source | Conteúdo |
|---|---|---|
| **JVM & Application** | Prometheus | Heap memory, GC pauses, threads, HTTP request rate, latency percentiles |
| **Resilience — External Integrations** | Prometheus | Circuit breaker states, retry counts, bulkhead available, rate limiter usage (ADR-0011) |
| **Business Metrics** | Prometheus | Consultas fiscais/dia, mensagens agregadas por canal, faturas, receita, tokens LLM por provider |
| **Tenant Overview** | Ledger/audit store + Loki/Tempo | Documentos, sessões, erros e atividade tenant-scoped sob controle de acesso |
| **Error Analysis** | Loki + Tempo | Taxa de erros por módulo, top 10 error codes, drill-down em traces por traceId |
| **SLA / Uptime** | Prometheus | Disponibilidade por integração (SERPRO, Meta, provider de pagamento e LLM) calculada via circuit breaker |

## 7.9 Alertas Grafana Prioritários

| Alerta | Condição | Severidade | Canal |
|---|---|---|---|
| Alta taxa de erros HTTP | `rate(http_server_requests_seconds_count{status=~"5.."}[5m]) > 0.1` | 🔴 Critical | Slack/Discord |
| JVM Heap > 80% | `jvm_memory_used_bytes{area="heap"} / jvm_memory_max_bytes > 0.8` | 🟡 Warning | Slack/Discord |
| Zero consultas fiscais em 1h (horário comercial) | `increase(business.fiscal.queries.total[1h]) == 0` AND `hour() >= 8 AND hour() <= 18` | 🟡 Warning | Slack/Discord |
| Erros HTTP agregados > 100 em 5 min | `increase(http_server_requests_seconds_count{status=~"4..|5.."}[5m]) > 100` | 🔴 Critical | Slack/Discord |
| Disco > 85% | `node_filesystem_avail_bytes / node_filesystem_size_bytes < 0.15` | 🔴 Critical | Slack/Discord |
| Loki ingestão parada | Nenhum log recebido em 5 min | 🔴 Critical | Slack/Discord |

---

# 8. AI Agent Considerations (For Autonomous Agent Environments)

Agent Roles Impacted:

- **@ImplementerCore:** DEVE lançar exceções da hierarquia de domínio definida neste ADR. NUNCA retornar `ResponseEntity` com JSON ad-hoc no controller — usar `throw new BusinessRuleViolationException(...)` e deixar o `GlobalExceptionHandler` tratar.
- **@AdapterDev:** DEVE usar `@Slf4j` com mensagens que incluem contexto estruturado (`log.error("Falha SERPRO: queryType={}, tenantId={}", queryType, tenantId, ex)`). NUNCA concatenar strings em log messages.
- **@CleanArchitecture:** Valida que `DomainException` e subclasses residem em `shared/domain/exception/`. O `GlobalExceptionHandler` reside em `shared/adapter/in/web/`. O domain NUNCA importa Spring MVC.
- **@DevOps-Agent:** Configura os containers PLG no Docker Compose e os dashboards Grafana. Gerencia retenção de logs (30 dias) e traces (7 dias).
- **@FrontendWeb:** Implementa hook `useApiError` no React que parseia o formato RFC 7807 e exibe mensagens ao usuário usando a chave `i18nKey`.

Operational Considerations:

- Ao gerar controllers, agentes DEVEM incluir `@Valid` nos request bodies e confiar no `GlobalExceptionHandler` para mapear `MethodArgumentNotValidException` → RFC 7807.
- Ao gerar log statements, agentes DEVEM usar placeholders (`{}`) ao invés de concatenação, e NUNCA logar PII sem sanitização.
- Ao criar novos módulos/bounded contexts, agentes DEVEM registrar o nome do módulo no `ModuleMdcFilter` para que logs contenham o campo `module` correto.

LLM Considerations:

- Prompts para geração de código de controllers devem incluir o contexto do `GlobalExceptionHandler` e do formato RFC 7807 para evitar que o agente crie tratamento de erro ad-hoc.
- Prompts para geração de adapters devem incluir o padrão de logging estruturado (placeholder-based, não concatenação).

Safety Considerations:

- O `GlobalExceptionHandler` catch-all (500) NUNCA expõe stack trace ao cliente — apenas o `traceId` para correlação.
- Logs de nível ERROR contendo stack traces de exceções inesperadas DEVEM ser sanitizados para PII antes de envio ao Loki.
- Credenciais e tokens de API NUNCA devem aparecer em logs — mesmo em nível DEBUG.

---

# 9. Implementation Plan

## Phase 1 — Error Handling Foundation (Sprint N)

- Criar hierarquia de `DomainException` em `shared/domain/exception/`.
- Implementar `GlobalExceptionHandler` com `@ControllerAdvice` para RFC 7807.
- Implementar `ProblemDetailResponse` record com campos estendidos (traceId, tenantId, errorCode, i18nKey).
- Refatorar controllers existentes para lançar exceções de domínio em vez de `ResponseEntity.status(xxx).body(...)`.
- Responsible: @ImplementerCore, @CleanArchitecture

## Phase 2 — Distributed Tracing (Sprint N)

- Adicionar dependências: `micrometer-tracing-bridge-brave`, `zipkin-reporter-brave`.
- Configurar `management.tracing` no `application.yml`.
- Implementar `MdcTaskDecorator` para propagação de traceId em Spring Modulith Events.
- Implementar `TraceIdResponseFilter` para retornar `X-Trace-Id` em responses HTTP.
- Verificar propagação automática em WebClient/RestClient para chamadas externas.
- Responsible: @ImplementerCore, @AdapterDev

## Phase 3 — Structured Logging (Sprint N+1)

- Adicionar dependência: `loki-logback-appender` (ou `logstash-logback-encoder`).
- Configurar `logback-spring.xml` com dual-profile (dev=texto, prod=JSON).
- Implementar `PiiMaskingConverter` para sanitização de CPF, Documento, email, phone em logs.
- Implementar `ModuleMdcFilter` para injetar nome do módulo no MDC baseado no package da classe.
- Atualizar `TenantContextFilter` (ADR-0005) para adicionar `tenantId` e `userId` ao MDC.
- Responsible: @ImplementerCore, @AdapterDev

## Phase 4 — PLG Stack (Sprint N+1)

- Criar diretórios `/infra/prometheus/`, `/infra/loki/`, `/infra/tempo/`, `/infra/grafana/`.
- Criar arquivos de configuração para cada serviço.
- Adicionar 4 serviços ao `docker-compose.yml` com `mem_limit`.
- Provisionar datasources Grafana (Prometheus, Loki, Tempo) via YAML.
- Responsible: @DevOps-Agent

## Phase 5 — Business Metrics & Dashboards (Sprint N+2)

- Implementar classes `*Metrics` por módulo (FiscalMetrics, WhatsAppMetrics, BillingMetrics).
- Registrar counters, timers e gauges de negócio conforme catálogo da seção 7.6.
- Criar dashboards Grafana: JVM, Resilience, Business Metrics, Tenant Overview, Error Analysis.
- Configurar alertas Grafana conforme tabela da seção 7.9.
- Responsible: @ImplementerCore, @DevOps-Agent

## Phase 6 — Frontend Integration (Sprint N+2)

- Implementar hook `useApiError` no React para parsear RFC 7807.
- Implementar interceptor Axios/Fetch que extrai `traceId` do header `X-Trace-Id` para exibição ao usuário.
- Implementar componente `ErrorBoundary` global que utiliza `i18nKey` para mensagens localizadas.
- Responsible: @FrontendWeb

Dependencies:

- Phase 1 e 2 podem ser paralelas (sem dependência entre si).
- Phase 3 depende de Phase 2 (traceId no MDC).
- Phase 4 é independente (infraestrutura pura).
- Phase 5 depende de Phase 4 (Grafana rodando) e Phase 3 (logs estruturados).
- Phase 6 depende de Phase 1 (RFC 7807 implementado no backend).

Rollback Plan:

- Phase 1: reverter `GlobalExceptionHandler` restaura comportamento default do Spring (respostas de erro genéricas).
- Phase 2: remover dependência `micrometer-tracing-bridge-brave` desabilita tracing (logs e métricas continuam).
- Phase 3: trocar perfil para `dev` restaura logs em texto.
- Phase 4: remover serviços do `docker-compose.yml` libera ~1GB RAM na VPS (app continua funcional sem observabilidade).

---

# 10. Validation

Architecture Validation:

- ArchUnit test: classes do package `domain` não devem importar `org.springframework.http.*`. DomainExceptions não dependem de Spring MVC.
- ArchUnit test: classes do package `adapter.in.web` não devem lançar `ResponseEntity` com status de erro diretamente — devem lançar `DomainException`.
- Todo controller testado com `MockMvc` verifica que respostas de erro seguem schema RFC 7807 (verifica presença de `type`, `title`, `status`, `detail`, `traceId`).

Performance Benchmarks:

- Overhead de tracing: latência adicional por request < 1ms (Brave é sampling-based, não instrumentation-heavy).
- Overhead de logging JSON: throughput de log não deve cair mais que 5% comparado ao texto plain.
- Memória PLG stack: total < 1GB com `mem_limit` configurado.

Observability Metrics (meta-observability):

- Prometheus scrape: verificar que `/actuator/prometheus` retorna métricas de negócio `business.*`.
- Loki: verificar que query `{app="hub-contabil"} |= "traceId"` retorna logs estruturados.
- Tempo: verificar que um trace completo (HTTP → Modulith Event → External API) aparece no Grafana.
- Grafana: verificar que todos os 6 dashboards renderizam corretamente.

Success Criteria:

- [ ] Todas as respostas de erro HTTP seguem RFC 7807 (`application/problem+json`).
- [ ] `traceId` presente em 100% das respostas HTTP (header `X-Trace-Id`).
- [ ] `traceId` propagado em Spring Modulith Events (verificável via teste de integração).
- [ ] Logs em JSON no profile `prod` com campos obrigatórios (traceId, tenantId, module).
- [ ] PII sanitizado em logs (CPF, Documento, email, phone) — verificável via teste unitário do `PiiMaskingConverter`.
- [ ] PLG stack rodando e acessível (Grafana em `:3000`, Prometheus em `:9090`).
- [ ] Métricas de negócio `business.*` visíveis no Prometheus.
- [ ] Nenhum meter ou low-cardinality key possui `tenant_id`, user ID, UUID, modelo LLM ou
      identificador de recurso; `tenant_id` pode existir somente como high-cardinality key de trace
      protegido. Testes percorrem os Meter IDs, exercitam `http.server.requests`, todas as
      allowlists e o registro único/concorrente/rollback dos gauges.
- [ ] Dashboard Grafana "Error Analysis" com drill-down de traceId → logs → traces.
- [ ] Frontend `useApiError` hook parseando RFC 7807 corretamente.

---

# 11. Risks and Mitigations

Risk 1:
Description: PLG stack consome mais memória que estimado na VPS, competindo com o JVM e PostgreSQL.
Mitigation: `mem_limit` estrito no Docker Compose (256MB por container). Monitorar com `docker stats`. Se necessário, reduzir sampling rate do Tempo de 100% para 10%, e aumentar agressividade do cleanup de logs no Loki (retenção de 7 dias ao invés de 30).

Risk 2:
Description: Log volume explode em produção (ex: chatbot gerando milhares de mensagens/hora), enchendo o disco da VPS.
Mitigation: Loki configurado com `retention_period: 30d` e `max_global_streams_per_user: 5000`. Alerta de disco > 85%. Rate limiting no Logback: `<turboFilter class="ch.qos.logback.classic.turbo.DuplicateMessageFilter"/>`.

Risk 3:
Description: PiiMaskingConverter tem regex incorretos que não capturam todas as variantes de CPF/Documento (ex: sem pontuação).
Mitigation: Testes unitários com 20+ variantes de formato (com/sem pontuação, com/sem máscara). Regex defensivos que capturam tanto `123.456.789-00` quanto `12345678900`.

Risk 4:
Description: Micrometer Tracing com Brave adiciona overhead de latência perceptível em virtual threads.
Mitigation: Brave é sampling-based — overhead é microsegundos por span. Se necessário, reduzir `sampling.probability` de 1.0 para 0.1 em produção (10% das requests tracadas).

Risk 5:
Description: Frontend React não adota RFC 7807, continuando a tratar erros de forma ad-hoc.
Mitigation: Documentar o formato RFC 7807 no OpenAPI (schema `ProblemDetail`). Code review obrigatório por @FrontendWeb para garantir uso do hook `useApiError`. Testes E2E verificam que erros são exibidos corretamente.

Risk 6:
Description: `GlobalExceptionHandler` captura exceções que deveriam ser tratadas por Spring Security (ex: `AuthenticationException`), causando conflito de response format.
Mitigation: `@Order(Ordered.HIGHEST_PRECEDENCE)` no GlobalExceptionHandler, mas com `@ExceptionHandler` específico para `AuthenticationException` e `org.springframework.security.access.AccessDeniedException` que delegam ao handler default do Spring Security ou formatam como RFC 7807 com status 401/403.

---

# 12. Related ADRs

- [ADR-0001 - Technology Stack and Architecture Foundation](./ADR-0001-technology-stack-and-architecture.md) — Define Spring Boot Actuator e Micrometer como base de observabilidade. Este ADR concretiza com PLG stack e métricas de negócio.
- [ADR-0002 - Multi-Tenant Database Isolation Strategy](./ADR-0002-separacao-banco-por-contexto-multitenancy.md) — Define 5 databases. A tag `module` em logs e métricas mapeia para o bounded context correspondente.
- [ADR-0004 - WhatsApp Integration Architecture](./ADR-0004-whatsapp-integration-architecture.md) — Fluxo cross-module (WhatsApp → Fiscal → SERPRO) é o principal caso de uso de distributed tracing.
- [ADR-0005 - Multi-Tenancy Architecture](./ADR-0005-multi-tenancy-architecture.md) — Define `TenantContextFilter` e MDC. Este ADR estende o MDC com campos adicionais (module, traceId via Micrometer).
- [ADR-0006 - Audit and Compliance](./ADR-0006-audit-compliance.md) — Audit log é complementar aos logs operacionais. Audit log captura **ações de negócio**; logs operacionais capturam **comportamento técnico**.
- [ADR-0007 - Multi-Provider LLM Integration](./ADR-0007-multi-provider-llm-integration.md) — Métricas de tokens LLM e fallback são expostas via Micrometer (catálogo deste ADR).
- [ADR-0023 - Integração agnóstica de provedores de pagamento](./ADR-0023-agnostic-payment-provider-integration.md) — Métricas financeiras usam dimensões neutras e `provider_code` somente na infraestrutura/observabilidade.
- [ADR-0008 - Stripe Billing & Subscription Management](./ADR-0008-stripe-billing-subscription.md) — Baseline histórico substituído pelo ADR-0023.
- [ADR-0010 - Tenant Plan Parametrization](./ADR-0010-tenant-plan-parametrization.md) — `TenantLimitAlertEvent` (80% threshold) gera log + métrica rastreável por este ADR.
- [ADR-0011 - Resilience Strategy](./ADR-0011-resilience-retry-circuit-breaker.md) — Métricas Resilience4j são visualizadas no Grafana configurado por este ADR. Fallbacks geram logs estruturados com traceId.

---

# 13. References

- [RFC 7807 — Problem Details for HTTP APIs](https://www.rfc-editor.org/rfc/rfc7807)
- [RFC 9457 — Problem Details for HTTP APIs (atualização)](https://www.rfc-editor.org/rfc/rfc9457) — Sucessor do RFC 7807, adotado pelo Spring Framework 6.x
- [Spring Boot ProblemDetail Support](https://docs.spring.io/spring-framework/reference/web/webmvc/mvc-ann-rest-exceptions.html)
- [Micrometer Tracing Documentation](https://micrometer.io/docs/tracing)
- [Micrometer Tracing — Brave Bridge](https://docs.spring.io/spring-boot/docs/current/reference/htmlsingle/#actuator.micrometer-tracing)
- [OpenZipkin Brave](https://github.com/openzipkin/brave)
- [Logstash Logback Encoder](https://github.com/logfellow/logstash-logback-encoder)
- [Loki4j Logback Appender](https://github.com/loki4j/loki-logback-appender)
- [Grafana Loki Documentation](https://grafana.com/docs/loki/latest/)
- [Grafana Tempo Documentation](https://grafana.com/docs/tempo/latest/)
- [Prometheus Documentation](https://prometheus.io/docs/)
- [Grafana Documentation](https://grafana.com/docs/grafana/latest/)
- [SLF4J MDC Documentation](https://www.slf4j.org/manual.html#mdc)
- [Spring Modulith Events — Event Publication Registry](https://docs.spring.io/spring-modulith/reference/events.html)
- [Twelve-Factor App — Logs](https://12factor.net/logs)
- [LGPD — Art. 16 (Dados Anonimizados)](https://www.planalto.gov.br/ccivil_03/_ato2015-2018/2018/lei/l13709.htm)
- Business Requirements: [Visão de produto](../product/business/product-vision.md)

---

# 14. Decision Lifecycle

Current State: **Accepted**

Este ADR preenche a lacuna de observabilidade identificada após a análise dos ADRs ADR-0001–ADR-0011. O ADR-0001 definiu Actuator e Prometheus como princípios; o ADR-0005 definiu MDC com tenant_id; o ADR-0011 definiu métricas Resilience4j. Este ADR unifica e concretiza essas menções, enquanto o ADR-0023 especializa métricas e erros dos providers de pagamento.

---

# 15. Change Log

Version: 1.0
Date: 2026-04-17
Author: @AgentOrchestrator
Changes:
- Initial ADR creation defining error handling standardization (RFC 7807) and observability stack (PLG).
- Defined domain exception hierarchy with automatic HTTP status mapping.
- Documented distributed tracing strategy with Micrometer Tracing (Brave) and MDC propagation.
- Defined structured JSON logging with PII sanitization.
- Documented PLG stack (Prometheus, Loki, Tempo, Grafana) Docker Compose configuration.
- Created catalog of 10 custom business metrics via Micrometer.
- Defined 6 Grafana dashboards and 6 priority alerts.

Version: 1.1
Date: 2026-08-21
Author: @AgentOrchestrator
Changes:
- Neutralização de exceções, integrações e dashboards de pagamento; a identidade do provider passa a seguir o ADR-0023.

Version: 1.2
Date: 2026-08-23
Author: Codex / @CodeGuardian / @ObservabilityDev / @SecurityAgent
Changes:
- Antes do código, corrigida a contradição de cardinalidade: tenant/user/resource IDs permanecem
  campos controlados de logs/traces, mas são proibidos em labels de métricas/Observations.
- Métricas de negócio passam a usar somente dimensões finitas; investigação por tenant usa
  logs/traces protegidos ou stores auditáveis.
- Congelados valores exatos das dimensões, remoção de `model`, gauges agregados single-registration
  com rollback e regressão global sobre `http.server.requests` e todos os meter IDs.

---

# 16. Repository Structure

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
    ADR-0007-multi-provider-llm-integration.md
    ADR-0008-stripe-billing-subscription.md
    ADR-0009-dynamic-rbac-evolution.md
    ADR-0010-tenant-plan-parametrization.md
    ADR-0011-resilience-retry-circuit-breaker.md
    ADR-0012-error-handling-observability.md   ← NEW
    ADR-0023-agnostic-payment-provider-integration.md
    README.md
```

Observability infrastructure configs:

```
infra/
  prometheus/
    prometheus.yml
  loki/
    loki-config.yml
  tempo/
    tempo-config.yml
  grafana/
    provisioning/
      datasources/
        datasources.yml
      dashboards/
        dashboards.yml
        jvm-overview.json
        resilience.json
        business-metrics.json
        tenant-overview.json
        error-analysis.json
        sla-uptime.json
```

---

# 17. Review Process

1. Este ADR foi criado em status "Proposed" por @AgentOrchestrator.
2. Revisores (@CleanArchitecture, @DomainExpert, @AdapterDev, @DevOps-Agent) devem validar:
   - A hierarquia de `DomainException` cobre todos os cenários de erro dos módulos existentes.
   - O formato RFC 7807 está correto e completo para o frontend React consumir.
   - A propagação de traceId funciona com virtual threads (Java 21) e Spring Modulith Events.
   - Os limites de memória da PLG stack são viáveis na VPS target.
   - As regras de sanitização de PII cobrem todos os tipos de dados sensíveis do domínio.
3. @FrontendWeb deve validar que o schema RFC 7807 é suficiente para implementar tratamento de erro genérico no React.
4. Após aprovação, o status muda para "Accepted".

---

# 18. Notes

Este ADR é transversal a todos os módulos e camadas da aplicação. Ele toca:

- **Domain layer:** Hierarquia de `DomainException` (package `shared/domain/exception/`).
- **Application layer:** Use cases lançam exceções tipadas, nunca manipulam HTTP diretamente.
- **Adapter layer (in):** `GlobalExceptionHandler` converte exceções em RFC 7807. `TraceIdResponseFilter` adiciona header.
- **Adapter layer (out):** Logs estruturados com traceId propagado. Métricas de negócio registradas.
- **Infrastructure:** PLG stack em Docker Compose. Configurações em `/infra/`.
- **Frontend:** Hook `useApiError` e `ErrorBoundary` baseados em RFC 7807.

Princípios codificados por este ADR:

- **Erros são cidadãos de primeira classe:** Exceções de domínio são tipadas, documentadas, e têm mapeamento automático para HTTP.
- **Logs são dados, não texto:** JSON estruturado com campos padronizados permite queries, alertas e dashboards.
- **PII em logs é um bug:** CPF, Documento, email e telefone DEVEM ser sanitizados antes de logar.
- **Tracing é mandatório, não opcional:** Toda request carrega um traceId do ingresso à resposta. Sem exceção.
- **Observabilidade não é pós-facto:** Métricas, logs e traces são definidos junto com o código, não depois de um incidente.
- **O frontend merece um contrato:** RFC 7807 é o contrato. `i18nKey` permite localização. `traceId` permite suporte.
