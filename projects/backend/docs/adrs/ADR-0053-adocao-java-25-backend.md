---
document_id: "ADR-0053"
primary_nature: "Decisao"
objective: "Adotar Java 25 como toolchain e runtime alvo do backend, definir o uso seguro de virtual threads e estabelecer uma redução de footprint orientada por evidência."
scope: "Backend Spring Boot/Spring Modulith, compilação e runtime Java, executores HTTP/assíncronos/agendados, propagação de contexto, backpressure, limites de recursos, dependências, artefato e imagem de container."
non_objectives: "Habilitar virtual threads ou flags experimentais; executar deploy ou produção; trocar Spring Boot, Spring Modulith, Maven, banco, topologia multitenant ou arquitetura modular; prometer ganho sem benchmark reproduzível."
owner: "Arquitetura / Backend / SRE / Qualidade"
status: "Accepted"
date: "2026-08-28"
last_reviewed: "2026-09-07"
version: "1.2"
keywords: "Java 25, LTS, virtual threads, Project Loom, performance, footprint, Maven, Spring Boot, backend"
related_files: "docs/adrs/README.md, docs/adrs/ADR-0001-technology-stack-and-architecture.md, docs/adrs/ADR-0011-resilience-retry-circuit-breaker.md, docs/adrs/ADR-0012-error-handling-observability.md, docs/adrs/ADR-0016-infrastructure-environment-provisioning.md, docs/adrs/ADR-0052-parametros-pool-conexao-por-tenant.md, artefatos de análise/ANL-00050-java-25-backend-impact-analysis.md, docs/product/requirements/REQ-00001-whatsapp-business-integration.md, docs/architecture/module-registry.md, backend/AGENTS.md"
code_references: "backend/pom.xml, backend/Dockerfile, backend/.mvn/wrapper/maven-wrapper.properties, backend/src/main/resources/application.yml, backend/src/main/java/br/com/duoset/saas_service/shared/config/async/AsyncConfig.java, backend/src/main/java/br/com/duoset/saas_service/shared/config/async/MdcTaskDecorator.java, backend/src/main/java/br/com/duoset/saas_service/shared/types/TenantContext.java, backend/src/main/java/br/com/duoset/saas_service/contexts/tenant/internal/infrastructure/cache/RedisTenantPoolPolicyCacheAdapter.java"
principal_statement: "Java 25 é o baseline qualificado do backend com platform threads; virtual threads somente serão adotadas por lane de I/O bloqueante após os gates de pools, contexto, deadlines, bulkheads e backpressure, e o enxugamento removerá apenas dependências ou módulos provadamente dispensáveis."
---

# ADR-0053 - Adoção de Java 25, virtual threads e eficiência do backend

- Document ID: `ADR-0053`
- Primary Nature: `Decisao`
- Objective: Adotar Java 25 como toolchain e runtime alvo do backend, definir o uso seguro de virtual threads e estabelecer uma redução de footprint orientada por evidência.
- Scope: Backend Spring Boot/Spring Modulith, compilação e runtime Java, executores HTTP, assíncronos e agendados, propagação de contexto, backpressure, limites de recursos, dependências, artefato e imagem de container.
- Non-objectives: Habilitar virtual threads ou flags experimentais; executar deploy ou produção; trocar Spring Boot, Spring Modulith, Maven, banco, topologia multitenant ou arquitetura modular; prometer ganho sem benchmark reproduzível.
- Keywords: Java 25, LTS, virtual threads, Project Loom, performance, footprint, Maven, Spring Boot, backend
- Related Files: [ADR-0001](ADR-0001-technology-stack-and-architecture.md), [ADR-0011](ADR-0011-resilience-retry-circuit-breaker.md), [ADR-0012](ADR-0012-error-handling-observability.md), [ADR-0016](ADR-0016-infrastructure-environment-provisioning.md), [ADR-0052](ADR-0052-parametros-pool-conexao-por-tenant.md), ANL-00050, [REQ-00001](../product/requirements/REQ-00001-whatsapp-business-integration.md), [module registry](../architecture/module-registry.md) e [instruções do backend](../../backend/AGENTS.md).
- Code References: `backend/pom.xml`, `backend/Dockerfile`, wrapper Maven, `application.yml`, `AsyncConfig`, `MdcTaskDecorator`, `TenantContext`, `RedisTenantPoolPolicyCacheAdapter` e workflows backend/security.
- Principal Decision: Java 25 é o baseline qualificado do backend com platform threads; virtual threads serão adotadas somente em lanes de I/O bloqueante com contexto, deadlines, bulkheads e backpressure preservados, e o enxugamento removerá apenas dependências ou módulos provadamente dispensáveis.
- Date: 2026-08-28
- Status: Accepted
- Version: 1.2
- Accepted on: 2026-08-28, por solicitação humana explícita
- Authors / Owners: Codex (OpenAI), sob solicitação do usuário / Arquitetura / Backend / SRE / Qualidade
- Reviewers: Arquitetura, Backend, Segurança, SRE, Qualidade e owners dos módulos afetados
- Stakeholders: Engenharia, Operações, Produto e tenants atendidos pelo backend
- Supersedes: [ADR-0001](ADR-0001-technology-stack-and-architecture.md) parcialmente, somente quanto à escolha de Java 21 como toolchain/runtime e às prescrições de concorrência e eficiência diretamente dependentes dessa versão.
- Superseded by: N/A

---

# 0. Limite de autoridade e estado da decisão

Em 2026-09-06, o solicitante autorizou explicitamente a implementação local e a
obtenção isolada do JDK/imagens necessários. O TP-00041 executou o primeiro corte:
POM, bytecode, builder/JRE Docker, jobs Java dos workflows e documentação ativa
passaram de 21 para 25 de forma coordenada e foram qualificados com fixtures
sintéticas. Isso comprova compatibilidade repository-local; não constitui deploy,
homologação, produção nem benchmark de performance.

O backend AS-IS passa a ser Java 25 com **platform threads**. Virtual threads,
tuning de Hikari, GC, heap e remoção de dependências continuam fora deste cutover.
Em especial, a promoção de qualquer lane virtual permanece dependente da
conclusão e da evidência aplicável dos planos de pools por tenant, para que a nova
concorrência não ultrapasse o recurso escasso.

## 0.1 Fronteira de supersessão

Este ADR substitui no ADR-0001 apenas:

- Java 21 como versão alvo de compilação e execução;
- afirmações de que virtual threads, por existirem no Java 21, já garantem
  concorrência ou redução de memória no backend;
- recomendações de eficiência do runtime que dependam da versão Java ou de
  executores.

Continuam vigentes no ADR-0001 Spring Boot 4, Spring Modulith, Clean Architecture,
DDD, SOLID, OpenAPI, monólito modular, Docker Compose, segurança, observabilidade
e evolução condicionada por escala. Esta decisão também não troca a ferramenta
de build: o Maven observado no backend permanece AS-IS; a menção histórica a
Gradle no ADR-0001 não integra esta fronteira de supersessão.

---

# 1. Context

No snapshot que originou esta decisão, o backend executava com Java 21. Após o
TP-00041, o estado repository-local é Java 25.0.4, Spring Boot 4.0.3, Spring
Modulith 2.0.3 e Maven 3.9.12. O POM compila em `release 25`; builder, JRE de
runtime e todos os jobs Java ativos dos workflows usam 25. O JDK foi extraído em
diretório temporário e não alterou o Java 21 padrão do host.

O [REQ-00001](../product/requirements/REQ-00001-whatsapp-business-integration.md), ainda
em `Draft`, explicita o envelope de produto relevante para esta decisão: retorno
do webhook abaixo de 500 ms, resposta completa abaixo de 5 s sem contar a
latência do SERPRO, no mínimo 50 mensagens/s sustentadas e 100 sessões WhatsApp
concorrentes em 2 vCPU/4 GiB. O benchmark de migração deve preservar esses
limites, sem converter o aceite deste ADR em alegação de que já foram provados.

Virtual threads já são API estável desde Java 21, mas não estão habilitadas
globalmente na aplicação. Existe um piloto explícito no cache Redis da política
de pools; o restante de `@Async` e dos eventos Modulith usa um
`applicationTaskExecutor` próprio baseado em platform threads. Os executores de
webhook possuem filas, rejeição, métricas e shutdown deliberadamente limitados.

O executor assíncrono genérico contém um problema anterior à migração: define
`corePoolSize=5` e `maxPoolSize=20`, não limita a fila e sombreia os valores
`4/16/100` declarados em `application.yml`. Assim, uma simples flag global não
resolve o modelo de concorrência e pode ocultar backpressure.

O custo operacional também não é explicado apenas pelo JDK. O fat JAR local
existente mede cerca de 139 MiB e reúne MVC, WebFlux/Netty, Keycloak Admin,
Hibernate, Modulith, observabilidade, PDFBox, Stripe e outros adapters. Parte é
necessária; parte possui sinais de não uso ou escopo inadequado. Enxugar exige
prova por símbolo, contrato, startup, teste e medição, não exclusão por tamanho.

Java 25 é a evolução alvo porque consolida quatro releases após o LTS anterior,
inclui a remoção do pinning causado por monitores entregue no JDK 24, torna
`ScopedValue` definitivo e oferece melhorias de observabilidade e startup. Esses
recursos reduzem riscos ou abrem experimentos; não transformam automaticamente
carga CPU-bound, banco, provedor externo ou pool Hikari em recurso ilimitado.

---

# 2. Decision Statement

## 2.1 Toolchain e runtime

O backend adotará Java 25 como versão de compilação (`release 25`) e runtime. A
mudança final deverá ser atômica entre:

- `backend/pom.xml` e plugins/annotation processors;
- builder e JRE de `backend/Dockerfile`, ambos com versão e digest compatíveis;
- jobs Java dos workflows backend e security;
- documentação AS-IS, standards e adaptadores operacionais ativos;
- imagem de rollback completa.

Bytecode 25 não será executado em JRE 21. Rollback significa restaurar o artefato
e a imagem Java 21 anteriores como unidade, sem reutilizar o JAR 25 no runtime 21.

APIs preview, incubator ou flags experimentais não entram no baseline de produção.
Em particular, Structured Concurrency preview e Compact Object Headers
experimental permanecem fora. CDS, AOT, `jlink` ou GC diferente serão avaliados
em experimentos separados; nenhuma dessas mudanças será combinada ao primeiro
cutover do JDK.

## 2.2 Virtual threads por lane

Virtual threads serão promovidas apenas para trabalho predominantemente bloqueado
em I/O e sempre atrás de configuração reversível. A ordem é:

1. Java 25 com o modelo atual de platform threads;
2. request handling HTTP em Java 25, medido separadamente;
3. executor genérico de `@Async`/eventos após corrigir limites, contexto e
   observabilidade;
4. lanes de integração específicas, uma por vez;
5. webhooks inbound e schedulers somente após preservar seus contratos próprios.

Continuarão em platform threads ou executores limitados:

- trabalho CPU-bound, criptografia, PDF e serialização pesada;
- filas cujo tamanho e rejeição representam admission control;
- scheduler enquanto não houver prova de ausência de head-of-line blocking e
  lifecycle correto;
- fluxo reativo/SSE enquanto seu contrato usar Reactor, sem empilhar dois modelos
  de concorrência para a mesma operação.

`spring.threads.virtual.enabled=true` não é a decisão completa. A propriedade pode
afetar superfícies auto-configuradas, mas não substitui executores customizados.
Se todos os executores que mantêm a aplicação viva se tornarem virtuais, o
rollout também deverá validar `spring.main.keep-alive=true` e shutdown gracioso.

## 2.3 Limites, transações e contexto

Cada lane virtual deverá possuir deadline e limite explícito do recurso escasso:
semaphore, bulkhead, rate limit, fila ou admission control. O menor limite entre
Hikari, Redis, SMTP, Keycloak, SERPRO, LLM, WhatsApp, Telegram e demais provedores
governa a concorrência; a quantidade de virtual threads não aumenta esse limite.

I/O externo dentro de transação que mantém conexão Hikari deverá ser removido,
encurtado ou provado seguro antes de ampliar concorrência. A migração não autoriza
aumentar pools de conexão, alterar GC ou relaxar circuit breaker para fabricar
resultado de benchmark.

`ThreadLocal` continuará no primeiro cutover com captura, restauração e limpeza
explícitas. A eventual adoção de `ScopedValue` será uma refatoração posterior,
porque MDC, Spring Security, contexto de request, transações e bibliotecas ainda
possuem escopos próprios. Nenhuma tarefa virtual poderá executar persistência sem
tenant correto ou reutilizar contexto residual.

## 2.4 Backend mais enxuto

“Enxuto” significa reduzir, sob a mesma funcionalidade, pelo menos um dos custos
medidos: fat JAR, imagem transferida, RSS, heap/non-heap, startup, CPU ou quantidade
de platform threads. A redução seguirá esta ordem:

1. remover dependência sem uso comprovado em fonte, configuração, reflection,
   templates, service loader ou contrato;
2. corrigir dependência de teste/build empacotada no runtime;
3. substituir starter amplo por módulo mínimo somente quando o contrato continuar
   coberto;
4. avaliar CDS/AOT ou runtime `jlink` em POC independente;
5. considerar native image apenas por nova decisão, devido a reflection, JPA,
   drivers, certificados, PDF, Keycloak e observabilidade.

Segurança, isolamento tenant, auditoria, métricas obrigatórias, resilience e gates
Modulith não serão removidos para reduzir tamanho. O resultado será comparado ao
baseline reproduzível, e não ao artefato local isolado.

## 2.5 Estado de transição

Java 25 é o baseline repository-local após o cutover do TP-00041. A combinação
anterior de artefato e imagem Java 21 continua sendo a unidade conceitual de
rollback até estabilização ambiental; um JAR de bytecode 69 nunca deve ser
executado em JRE 21. O estado implementado não autoriza virtual threads, deploy ou
remoção do rollback.

---

# 3. Decision Drivers

- **Performance sob I/O bloqueante:** aumentar throughput sem impor reescrita
  reativa ao monólito MVC/JPA.
- **Eficiência na VPS:** reduzir platform threads, memória e artefatos mantendo o
  envelope de 2 vCPU/4 GiB considerado pela fundação.
- **LTS e manutenção:** convergir para Java 25 com política de suporte do vendor.
- **Segurança e isolamento:** impedir que mais concorrência amplifique vazamento de
  tenant, exaustão Hikari ou chamadas externas sem limite.
- **Rollback:** separar troca do JDK, virtual threads e enxugamento para localizar
  regressões.
- **Observabilidade:** tornar o ganho e os gargalos reproduzíveis por métricas e
  JFR.
- **Manutenibilidade:** continuar com código imperativo onde ele é mais simples e
  não manter modelos concorrentes redundantes sem necessidade.

---

# 4. Considered Options

## Option 1: Permanecer em Java 21

**Pros:** nenhuma migração imediata; baseline já executado.

**Cons:** adia o novo LTS, não incorpora as melhorias do JDK 22–25 e mantém a
análise de pinning/contexto presa ao baseline anterior.

Resultado: rejeitada como alvo, preservada apenas como transição e rollback.

## Option 2: Java 25 e virtual threads globais em um único cutover

**Pros:** alteração aparente pequena e rápida exposição da concorrência virtual.

**Cons:** mistura compatibilidade do JDK com mudança comportamental, ignora
executores customizados, pode remover backpressure, amplificar contenção e torna o
rollback inconclusivo.

Resultado: rejeitada.

## Option 3: Java 25 em etapas, virtual threads por lane e footprint medido

**Pros:** separa causas, preserva limites, permite canário/rollback por
configuração e vincula ganho a evidência.

**Cons:** exige matriz de testes e benchmark, instrumentação e mais de um estágio
de rollout.

Resultado: selecionada.

## Option 4: Reescrever para reativo, native image ou microservices

**Pros:** pode atender workloads específicos quando comprovado.

**Cons:** amplia drasticamente o escopo, duplica modelos, afeta reflection e
integrações e não resolve por si só limites de banco/provedor.

Resultado: rejeitada para esta decisão; nova evidência poderá justificar ADR
próprio.

---

# 5. Decision Outcome

A Option 3 foi selecionada. Java 25 passa a ser o alvo normativo, mas o primeiro
incremento mantém platform threads para isolar compatibilidade. Virtual threads
só serão promovidas quando a lane demonstrar benefício material, preservar
contexto e respeitar o recurso escasso.

O objetivo não é maximizar o número de threads. É aumentar trabalho útil por
recurso da VPS sem ampliar erros, timeouts, contenção, cardinalidade ou risco de
isolamento.

---

# 6. Consequences

## Positive Consequences

- baseline em LTS mais recente e acesso às melhorias acumuladas do JDK;
- menor custo de espera em lanes bloqueantes que passarem os gates;
- remoção do pinning causado por monitores reduz um risco histórico, embora
  contenção continue existindo;
- concorrência, contexto e footprint passam a possuir baseline e critérios
  reproduzíveis;
- rollback por etapa reduz o raio de diagnóstico.

## Negative Consequences

- build, CI, container, bibliotecas, agentes e documentação precisam convergir;
- mais concorrência pode revelar limites antes ocultos em Hikari e provedores;
- ThreadLocal, MDC, SecurityContext e request context exigem testes adicionais;
- duas versões Java e configurações de executor coexistirão durante a transição;
- benchmark e observabilidade aumentam o custo inicial.

## Neutral Consequences

- Java 25 não reduz latência de rede nem acelera automaticamente trabalho
  CPU-bound;
- virtual threads não substituem pool de conexões, circuit breaker ou rate limit;
- redução de JAR/imagem e redução de RSS são métricas diferentes;
- Structured Concurrency e Compact Object Headers não fazem parte do baseline.

---

# 7. Impact

| Área | Impacto decidido |
| --- | --- |
| Build | Maven compilará e testará com Java 25; annotation processors e bytecode 69 serão verificados. |
| Runtime | Builder e JRE usarão a mesma linha Java 25 e digest fixo; imagem Java 21 ficará disponível para rollback até estabilização. |
| CI | Todos os jobs Java migrarão de forma coordenada; uma matriz temporária 21/25 poderá caracterizar a transição. |
| HTTP | Virtual threads serão testadas por flag em servidor real, não apenas MockMvc. |
| Async/Modulith | O executor genérico será corrigido e medido antes de qualquer conversão; contexto e limite serão obrigatórios. |
| Webhooks | Filas, `AbortPolicy`/`CallerRunsPolicy`, HTTP 503, drops, métricas e shutdown são contratos a preservar. |
| Schedulers | Terão lane e atraso observáveis; ativação virtual será independente do HTTP. |
| Persistência | Hikari continua limitador; nenhuma ampliação de concorrência pode manter conexão durante espera externa sem prova. |
| Segurança | Tenant, MDC, trace, SecurityContext e request context serão exercitados em cancelamento, timeout e reuso. |
| Dependências | Thymeleaf, Hypersistence, WebFlux/Netty, escopos de teste e Modulith runtime serão auditados; uso real prevalece sobre tamanho. |
| Operação | Startup, RSS, GC, threads, filas, rejeições, Hikari e JFR entram no gate. |
| Documentação | ADR-0001 fica parcialmente supersedido; baseline AS-IS muda somente no cutover. |

---

# 8. AI Agent Considerations

- Agentes não devem trocar `21` por `25` mecanicamente em arquivos históricos.
- Qualquer implementação deverá começar por plano persistido e separar JDK,
  virtual threads, GC e redução de dependências em mudanças observáveis.
- Nenhum agente poderá habilitar preview/experimental, aumentar Hikari ou remover
  backpressure para fazer benchmark passar.
- Dependência só será classificada como não usada após busca estática, inspeção de
  configuração/reflection e suíte relevante.
- Ausência de JDK 25, Docker ou provider sintético deverá ser reportada como
  `NOT_PROVEN`, nunca como aprovação por inferência.

---

# 9. Implementation Plan

## Phase 0 - Baseline Java 21

- congelar hardware/container, heap, GC, dataset, dependências e configuração;
- capturar startup, JAR/imagem, RSS, CPU, GC, threads, Hikari, filas e latência;
- tornar o executor genérico e seus limites observáveis sem mudar semântica.

## Phase 1 - Compatibilidade Java 25 com platform threads

- disponibilizar JDK 25 em ambiente isolado autorizado;
- compilar, empacotar e executar testes com virtual threads globais desligadas;
- configurar Mockito como `-javaagent` se a autoanexação dinâmica falhar;
- executar `jdeps --jdk-internals` e `jdeprscan`;
- validar TLS, PKCS12/JKS, PDF, Keycloak, Flyway, Hibernate, Redis, SSE e logging.

## Phase 2 - Cutover de toolchain e imagem

- atualizar POM, Dockerfile e todos os jobs Java no mesmo incremento;
- fixar imagens por digest e executar smoke/healthcheck em Alpine;
- atualizar manifesto, standards e adaptadores AS-IS;
- preservar a imagem Java 21 anterior e o rollback sem mudança de schema.

## Phase 3 - Piloto virtual HTTP

- habilitar request handling virtual por profile/flag local;
- executar carga HTTP real e JFR;
- provar isolamento tenant, MDC/trace/security/request, timeout e cancelamento;
- promover somente se os gates quantitativos passarem.

## Phase 4 - Async e integrações selecionadas

- corrigir a fila ilimitada e a divergência YAML/`AsyncConfig`;
- escolher lane bloqueante, adicionar deadline e bulkhead e migrar uma por vez;
- manter webhooks e scheduler fora até testes específicos de saturação/lifecycle;
- auditar o piloto Redis virtual, inclusive concorrência de `get/put/evict`.

## Phase 5 - Enxugamento

- remover candidatos comprovadamente sem uso em incrementos isolados;
- impedir bibliotecas de teste no fat JAR;
- avaliar o custo do único fluxo WebFlux/SSE contra alternativa que preserve o
  contrato;
- experimentar CDS/AOT/`jlink` separadamente e manter apenas ganho reproduzível.

## Phase 6 - Rollout

- canário por lane, janela de observação e rollback por configuração;
- rollout mais amplo somente após estabilidade de DB, providers, contexto e
  scheduler;
- remoção do rollback Java 21 somente por decisão operacional posterior.

---

# 10. Validation

## 10.1 Matriz obrigatória

No mesmo container/hardware, dataset e limites:

1. Java 21 + platform threads;
2. Java 25 + platform threads;
3. Java 25 + virtual threads somente no HTTP;
4. Java 25 + HTTP e uma lane assíncrona selecionada.

Cada célula terá aquecimento e repetições suficientes para separar ganho de ruído.

## 10.2 Métricas

- throughput, p50, p95, p99, erros e timeouts;
- CPU, RSS, heap, metaspace/direct memory, alocação e GC;
- platform/carrier/virtual threads, context switches e eventos JFR;
- Hikari active/idle/pending, tempo de aquisição e timeout por classe de pool;
- profundidade, capacidade, rejeição e atraso de cada executor/scheduler;
- circuit breaker, rate limit e deadline por provider;
- startup, fat JAR e imagem.

## 10.3 Gates funcionais e estruturais

- testes focados de `TenantContext`, MDC, async, Redis virtual, saturação de
  webhook, schedulers e HTTP concorrente em servidor real;
- Modulith e Clean Architecture;
- suíte Maven completa;
- isolamento tenant com PostgreSQL e Keycloak;
- perfis Failsafe de Billing e tenant isolation;
- event replay, Flyway, TLS/certificados, PDF, mail, Keycloak, LLM/SSE e adapters
  externos com doubles sintéticos;
- build e smoke da imagem, liveness/readiness e shutdown gracioso.

## 10.4 Critérios de promoção

Java 25 com platform threads deverá manter comportamento e não piorar p95/p99,
erro, timeout ou RSS em mais de 5% fora da variação do baseline. Uma lane virtual
só será promovida se produzir ao menos 10% de melhoria repetível em throughput ou
RSS no workload bloqueante alvo, sem regressão superior a 5% no p99 e sem aumento
de erro/timeout.

Também são obrigatórios:

- revalidar o envelope do REQ-00001: acknowledgment do webhook abaixo de 500 ms,
  resposta completa abaixo de 5 s sem a latência do SERPRO, pelo menos 50
  mensagens/s sustentadas e 100 sessões concorrentes em 2 vCPU/4 GiB;
- zero tenant incorreto, ausente ou residual;
- propagação integral dos contextos requeridos pela lane;
- zero timeout Hikari inesperado e limites de conexão inalterados;
- mesmas respostas 503, políticas de rejeição e drops intencionais;
- nenhum pinning sustentado ou contenção longa ocultada, conforme JFR;
- JVM abaixo de 1 GiB revalidada no mesmo cenário, sem tratar nenhum desses
  limites como já comprovado.

Falha em gate mantém a etapa anterior. Não autoriza tuning simultâneo de GC, heap,
pool ou provider.

---

# 11. Risks and Mitigations

| Risco | Mitigação |
| --- | --- |
| biblioteca ou plugin não suportar bytecode/JDK 25 | matriz Java 25, processors atualizados e gate completo antes do cutover |
| Mockito falhar por autoanexação do agent | `-javaagent` explícito em Surefire/Failsafe, sem bypass global |
| mais VTs exaurirem Hikari/provider | deadline, semaphore/bulkhead, métricas e concorrência limitada pelo recurso |
| perder backpressure dos webhooks | preservar fila/rejeição/503 e migrar essa lane por último |
| tenant/MDC/security vazar | captura/restauração/limpeza e testes concorrentes, cancelados e aninhados |
| scheduler virtual encerrar JVM ou bloquear jobs | lane própria, keep-alive, atraso e shutdown testados |
| I/O externo manter transação/conexão | encurtar transação ou bloquear promoção até prova de telemetria |
| pinning ser tratado como resolvido por grep | JFR e lock contention em carga; bibliotecas nativas continuam sob observação |
| remoção de dependência quebrar reflection/template/provider | incremento isolado, análise de uso e suíte/startup |
| misturar JDK, VT, GC e slimming impedir diagnóstico | uma variável arquitetural por etapa |
| bytecode 25 impedir rollback no JRE 21 | rollback do par JAR+imagem, preservado até estabilização |

---

# 12. Related ADRs

- [ADR-0001](ADR-0001-technology-stack-and-architecture.md) — fundação preservada,
  parcialmente supersedida apenas no recorte Java/runtime/concorrência.
- [ADR-0011](ADR-0011-resilience-retry-circuit-breaker.md) — bulkheads,
  timeouts e risco de exaustão continuam obrigatórios.
- [ADR-0012](ADR-0012-error-handling-observability.md) — MDC, tracing, métricas e
  JFR sustentam os gates.
- [ADR-0016](ADR-0016-infrastructure-environment-provisioning.md) — prescrições
  históricas de bootstrap JDK 21 ficam supersedidas, no backend, por este baseline.
- [ADR-0052](ADR-0052-parametros-pool-conexao-por-tenant.md) — orçamento Hikari e
  admission control não são ampliados por virtual threads.

---

# 13. References

- [OpenJDK JDK 25](https://openjdk.org/projects/jdk/25/)
- [JEP 444 — Virtual Threads](https://openjdk.org/jeps/444)
- [JEP 491 — Synchronize Virtual Threads without Pinning](https://openjdk.org/jeps/491)
- [JEP 506 — Scoped Values](https://openjdk.org/jeps/506)
- [JEP 514 — Ahead-of-Time Command-Line Ergonomics](https://openjdk.org/jeps/514)
- [JEP 515 — Ahead-of-Time Method Profiling](https://openjdk.org/jeps/515)
- [JEP 519 — Compact Object Headers](https://openjdk.org/jeps/519)
- [Spring Boot — Task Execution and Scheduling](https://docs.spring.io/spring-boot/reference/features/task-execution-and-scheduling.html)
- [Spring Boot 4.0 — System Requirements](https://docs.spring.io/spring-boot/4.0/system-requirements.html)
- ANL-00050 — Impacto de Java 25 no backend
- [REQ-00001 — Integração com WhatsApp Business Platform](../product/requirements/REQ-00001-whatsapp-business-integration.md)

---

# 14. Decision Lifecycle

Current State: **Accepted / JAVA 25 REPOSITORY-LOCAL QUALIFIED / VIRTUAL THREADS DEFERRED**.

O TP-00041 implementa e qualifica o baseline Java 25 sem mudar o modelo de
concorrência. Performance, virtual threads e slimming permanecem etapas separadas:
nenhum ganho é alegado antes do benchmark da Section 10.4, e falha em um gate de
lane bloqueia apenas essa promoção.

## 14.1 Evidência final do cutover

Em 2026-09-07, o snapshot consistente mais recente foi compilado com OpenJDK
`25.0.4`, Maven `3.9.12` e `release 25`. A suíte integral executou `2.836` testes,
com `0` falhas, `0` erros e `9` skips não críticos. Um delta paralelo posterior
no scheduler/outbox comercial foi recompilado integralmente e validado por `8`
testes focalizados, também sem falhas ou erros.

O package produziu fat JAR executável e classes `major version 69`; `jdeprscan
--release 25` não encontrou API removida no código da aplicação. `jdeps` não
apontou dependência direta do código próprio em API interna; os achados no
classpath pertencem a bibliotecas de terceiros, principalmente Lombok, Netty,
ArchUnit, AspectJ e WireMock, e permanecem como dívida monitorada. Os gates
arquiteturais, tenant isolation, Billing, Conversation Audit e a imagem Docker
Java 25 foram qualificados com fixtures sintéticas; o Dockerfile final também
passou em `docker build --check` sem warnings.

Os nove skips pertencem às verificações opcionais de publicação de eventos e aos
testes modulares de Billing, Certificate, Fiscal, Omnichannel e Tenant; nenhum
skip encobriu compilação, runtime Java, isolamento tenant ou contrato alterado.
Avisos de teardown Hikari/Surefire após encerramento dos containers são dívida de
lifecycle preexistente, não falha de compatibilidade Java 25.

---

# 15. Change Log

| Version | Date | Author | Changes |
| --- | --- | --- | --- |
| 1.2 | 2026-09-07 | Owner humano / Codex (OpenAI) | Consolida a evidência final: 2.836 testes sem falha/erro, delta concorrente validado, package bytecode 69, análise JDK e Dockerfile verdes; mantém virtual threads e performance fora do cutover. |
| 1.1 | 2026-09-06 | Owner humano / Codex (OpenAI) | Registra o cutover repository-local qualificado para Java 25 com platform threads; preserva virtual threads, tuning e slimming como etapas posteriores dependentes de pools e benchmark. |
| 1.0 | 2026-08-28 | Codex (OpenAI), sob solicitação humana explícita | Adota Java 25 como alvo, define virtual threads por lane, backpressure/contexto obrigatórios, slimming baseado em evidência, matriz de benchmark alinhada ao REQ-00001, rollout e rollback. |

---

# 16. Repository Structure

Este ADR está armazenado em:

```text
docs/adrs/ADR-0053-adocao-java-25-backend.md
```

---

# 17. Review Process

1. A solicitação humana de 2026-08-28 aceitou a mudança de alvo para Java 25.
2. Arquitetura e Backend mantêm a separação entre decisão e implementação.
3. SRE e Qualidade aprovam o método e a evidência do benchmark antes de promoção.
4. Segurança revisa contexto, TLS, certificados, providers e imagem.
5. Cada lane virtual e cada remoção de dependência possui rollback independente.
6. Mudança posterior de versão Java, uso de preview/native image ou relaxamento dos
   gates exige nova versão aceita ou ADR sucessor.

---

# 18. Notes

Virtual threads são uma ferramenta de throughput para espera bloqueante. A
arquitetura continua sendo um monólito modular imperativo e pode manter Reactor no
fluxo que realmente precisar de streaming. O desenho mais enxuto é o que conserva
somente complexidade comprovadamente necessária, não o que remove guardrails.
