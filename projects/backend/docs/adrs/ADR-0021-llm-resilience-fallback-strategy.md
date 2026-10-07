---
document_id: "ADR-0021"
primary_nature: "Decisao"
objective: "Registrar a decisão arquitetural “LLM Resilience and Fallback Strategy”, seus motivadores, alternativas e consequências."
scope: "Decisão, componentes, integrações e limites explicitamente descritos em “LLM Resilience and Fallback Strategy”."
non_objectives: "Não implementar a decisão, substituir requisitos relacionados nem atestar capabilities ou ambientes sem evidência explícita."
owner: "Antigravity AI, Marcello Pedrosa"
status: "Accepted"
date: "2026-07-27"
last_reviewed: "2026-09-01"
version: "1.3"
keywords: "adr, decisao, arquitetura, llm, resilience, and, fallback, strategy"
related_files: "README.md, ADR-0054-omnichannel-tenant-local-durable-inbox.md, ../lessons-learned/LL-BE-00093-webhook-ack-is-not-worker-completion.md, ../lessons-learned/LL-BE-00094-fallback-must-be-terminal-and-truthful.md"
code_references: "app/src/main/java/br/com/duoset/saas_service/contexts/omnichannel/internal/infrastructure/external/llm/LlmProviderChain.java, app/src/main/java/br/com/duoset/saas_service/contexts/omnichannel/internal/infrastructure/external/llm/SpringAiLlmAdapter.java, app/src/test/java/br/com/duoset/saas_service/contexts/omnichannel/internal/infrastructure/external/llm/LlmProviderChainTest.java"
principal_statement: "A estratégia de fallback em cascata respeita prioridade e circuit breaker dentro de um orçamento monotônico global; um provider só começa quando resta tempo para uma tentativa completa, evitando reter indefinidamente o worker conversacional."
---

# ADR-0021 - LLM Resilience and Fallback Strategy

- Document ID: `ADR-0021`

- Date: 2026-07-27  
- Status: Accepted  
- Version: 1.3  
- Authors / Owners: Antigravity AI, Marcello Pedrosa  
- Reviewers: Arquitetura, DevOps  
- Stakeholders: Operações, Produto, Engenharia de IA  

---

# 1. Context

O Módulo de Agentes Corporativos depende fundamentalmente de Modelos de Inteligência Artificial (LLMs) externos ou hospedados localmente para funcionar. Provedores de nuvem como OpenAI, Azure e AWS Bedrock frequentemente sofrem com:
- **Rate Limits (Quota Excedida / 429 Too Many Requests):** Picos de acessos corporativos (ex: 5.000 funcionários enviando mensagens simultâneas) podem ultrapassar o limite financeiro mensal ou o limite de requisições por segundo acordados.
- **Indisponibilidade (Timeouts / 500 Internal Server Error):** Degradações de rede ou problemas no provedor podem deixar a plataforma fora do ar.

Foi identificada a ausência de um Documento de Requisitos Não Funcionais (NFR) que definisse como a aplicação deve se comportar durante esses eventos para garantir a alta disponibilidade.

---

# 2. Decision Statement

O sistema implementará uma **Estratégia de Resiliência e Fallback em Cascata** para provedores de IA, baseada em um Indexador de Prioridades (1 = Principal, 2 = Secundário, 3 = Terciário), gerida por um **Circuit Breaker**.
As chamadas de rede aos provedores (via Spring RestClient) serão protegidas pelo Resilience4j, tratando erros de HTTP 429 e Timeouts com re-tentativas (Retries) curtas, e, em caso de falha persistente, desviando o tráfego de forma transparente para o próximo modelo na fila de prioridade.

### 2.1 Orçamento global da cadeia

A cascata inteira possui um deadline monotônico independente do relógio de parede.
Antes de iniciar cada provider, a cadeia deve verificar se o tempo restante comporta
uma tentativa completa, definida pela soma dos connect e read timeouts vigentes. Se
não comportar, não abre nova conexão e retorna o fallback fixo.

Os limites `llm.provider-chain-timeout`, `llm.api.connect-timeout` e
`llm.api.read-timeout` são positivos. O orçamento da cadeia deve ser maior ou igual
à soma dos limites de uma tentativa. Circuit breaker, retry interno e troca de
provider não podem ampliar esse deadline. Esgotamento registra somente operação e
outcome finitos, nunca prompt, tenant, identidade remota, chave, URL ou conteúdo.

Esse complemento protege o lease e a capacidade do worker definidos pelo
[REQ-00050](../product/requirements/REQ-00050-omnichannel-durable-inbound-processing.md)
e pelo [ADR-0054](ADR-0054-omnichannel-tenant-local-durable-inbox.md). O orçamento
foi comprovado por testes monotônicos, fallback e privacidade; o gate PostgreSQL
pendente da inbox não altera essa evidência específica da cadeia LLM.

### 2.2 Semântica terminal do fallback conversacional

Quando a cadeia termina com `wasFallback=true`, a aplicação não pode encaminhar
como resposta um texto técnico ou de progresso produzido pelo adapter. No fluxo de
Tool Calling, deve entregar uma mensagem final verdadeira, não executar tool e
preservar `LLM_CONVERSATION`. A regra é idêntica em Telegram e WhatsApp.

---

# 3. Decision Drivers

- Alta Disponibilidade (Evitar que os funcionários fiquem sem respostas por indisponibilidade momentânea).
- Otimização de Custos (Priorizar modelos mais baratos internos e deixar APIs caras de nuvem apenas para tarefas complexas ou como backup extremo).
- Tratamento de Limites (Garantir que picos de uso não derrubem o serviço).
- Transparência para o usuário (A troca de provedor deve ocorrer no backend, preservando o contexto do chat).
- Duração bounded do worker: fallback não pode multiplicar indefinidamente os
  timeouts por número de providers.

---

# 4. Considered Options

### Option 1: Circuit Breaker e Fallback Manual na Camada de Aplicação
Description: Lógica em `try-catch` dentro dos services, mudando a chave do banco manualmente.
Pros: Simples de implementar na primeira iteração.
Cons: Difícil de escalar. Código complexo cheio de "Ifs".

### Option 2: Fallback Dinâmico via Gateway de IA e Resilience4j (Escolhida)
Description: O backend possui um `LlmHealthCheckAdapter` e um `LlmCompletionAdapter` encapsulados no Resilience4j. Se o provedor primário disparar a abertura do circuito ou der timeout, o gateway captura a exceção de fallback e busca o próximo `fallback_model_id` na base de dados para reencaminhar o prompt.
Pros: Padronizado, permite Retries curtos antes do Fallback, métricas automáticas para Observabilidade (Prometheus/Grafana).
Cons: Adiciona dependência à biblioteca Resilience4j (ou similar do Spring Cloud).

---

# 5. Decision Outcome

A **Opção 2** foi selecionada. Ela delega a complexidade de tempo de timeout, rate-limits (HTTP 429) e abertura do circuito para a biblioteca padrão do ecossistema Spring (Resilience4j).
Em caso de erro `429` (Quota/Rate Limit), o sistema fará até 3 re-tentativas com backoff exponencial. Se o erro persistir, o circuito abre e redireciona automaticamente o prompt para a próxima prioridade cadastrada no UC-00009 (`fallbackPriorityList`).

O redirecionamento é condicionado pelo orçamento global: uma prioridade seguinte
só pode iniciar se ainda couber connect + read timeout completos. A ausência desse
tempo encerra a cascata no fallback fixo, ainda que existam providers ativos.

---

# 6. Consequences

**Positive Consequences:**
- Usuários finais raramente perceberão indisponibilidades.
- A engenharia pode cadastrar LLMs baratos locais como Prioridade 1 e APIs caras como Prioridade 2 para fallback imediato, barateando a operação.

**Negative Consequences:**
- A complexidade do fluxo assíncrono e das métricas aumenta. O painel do Grafana deverá ter dashboards específicos para monitorar o status do Circuit Breaker.
- O último provider elegível pode não ser tentado quando o orçamento restante for
  insuficiente; o comportamento bounded prevalece sobre exaurir toda a lista.

---

# 7. Impact

- **Backend:** Inclusão de `@CircuitBreaker`, `@Retry` e `@Fallback` nos adapters de LLM.
- **Banco de Dados:** Criação da tabela/jsonb de `fallbackPriorityList` para estabelecer o indexador.
- **Observabilidade:** Monitorar métricas de circuito aberto (AlertManager) para avisar os gestores quando o sistema precisar recorrer ao fallback.
- **Worker Omnichannel:** O orçamento usa relógio monotônico e impede que a soma de
  fallbacks retenha lease, admissão tenant ou thread além do limite contratado.
- **Métrica de budget:** `llm.provider.chain.budget.exhausted{operation=response|tool_call}`
  registra o corte da cascata com cardinalidade finita e sem conteúdo do prompt.

---

# 8. AI Agent Considerations (For Autonomous Agent Environments)

- **LLM Considerations:** Se o provedor principal responder parcialmente e cair (streaming), o sistema não deve misturar metadados do modelo A com o modelo B na mesma mensagem, lidando adequadamente com o fluxo de Server-Sent Events (SSE).

---

# 9. Implementation Plan

Phase 1 – Estrutura do BD e CRUD do UC-00009 (Configurar o indexador).
Phase 2 – Configuração do Resilience4j com Circuit Breaker no ChatGateway.
Phase 3 – Testes de carga forçando Timeouts e HTTP 429 em HML.
Phase 4 – Validar orçamento monotônico para resposta e tool calling, incluindo
configuração inválida e ausência de tempo para uma segunda tentativa.

---

# 10. Validation

- A arquitetura será validada se, ao retirar o endpoint da OpenAI do ar ou estourar o quota de token limit (429), a resposta continuar chegando no frontend utilizando, por exemplo, AWS Bedrock.
- A cadeia também deve provar que não inicia outro provider quando o restante do
  deadline é menor que connect + read timeout, que mudança do relógio de parede não
  altera a decisão e que o fallback/métrica não expõem prompt ou identificadores.

---

# 11. Risks and Mitigations

**Risk 1:** Perda de contexto se os provedores exigirem formatos de payload incompatíveis.
**Mitigation:** O sistema utiliza um padrão agnóstico interno de DTO de Conversas. O Adapter de cada provedor deve traduzir o padrão universal para a API específica.

**Risk 2:** Retries e providers em cascata multiplicarem o tempo total e expirarem
lease ou ocuparem admissão tenant.
**Mitigation:** Orçamento monotônico único, validação de configuração e proibição de
iniciar tentativa que não caiba integralmente no restante.

---

# 12. Related ADRs

- ADR-0007 Local LLM and Model Gateway
- ADR-0054 Inbox durável omnichannel no banco do tenant

---

# 13. References

- Resilience4j CircuitBreaker Documentation
- [UC-00009 — Configuração Agnóstica de Provedores e Modelos de IA](../product/use-cases/UC-00009-llm-admin-config.md)
- [REQ-00050 — Processamento inbound durável omnichannel](../product/requirements/REQ-00050-omnichannel-durable-inbound-processing.md)
- [ADR-0054 — Inbox durável omnichannel no banco do tenant](ADR-0054-omnichannel-tenant-local-durable-inbox.md)
- [LL-BE-00093 — ACK de webhook não é conclusão do worker](../lessons-learned/LL-BE-00093-webhook-ack-is-not-worker-completion.md)
- [LL-BE-00094 — Fallback deve ser terminal e verdadeiro](../lessons-learned/LL-BE-00094-fallback-must-be-terminal-and-truthful.md)

---

# 14. Decision Lifecycle

Accepted.

---

# 15. Change Log

Version: 1.0  
Date: 2026-07-27  
Author: Antigravity AI, Marcello Pedrosa  
Changes:
- Initial ADR creation focado na política de Fallback e Resiliência (Circuit Breakers / Rate Limiting).

Version: 1.1  
Date: 2026-08-29  
Author: Codex  
Changes:
- Adicionado orçamento monotônico global para resposta e tool calling.
- Proibido iniciar provider quando não resta connect + read timeout completos.
- Vinculados worker durável, métrica de budget e prevenção agnóstica a REQ-00050,
  ADR-0054 e LL-BE-00093, mantendo os gates pendentes.

Version: 1.2  
Date: 2026-08-29  
Author: Codex  
Changes:
- Registrada a evidência verde dos testes monotônicos, fallback e privacidade da
  cadeia; a pendência PostgreSQL da inbox foi separada deste critério.

Version: 1.3  
Date: 2026-09-01  
Author: Codex  
Changes:
- Determinado que fallback conversacional é terminal, não executa tool, não expõe
  texto de progresso técnico e preserva estado retomável em todos os canais.
