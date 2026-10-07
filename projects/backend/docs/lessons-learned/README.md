---
document_id: BACKEND-LESSONS-INDEX
primary_nature: Historico
objective: Indexar lições transferiveis provenientes do backend.
scope: Arquitetura, dados, segurança, testes e operação backend.
non_objectives: Nao representar regra vigente sem referência normativa.
owner: Backend e Qualidade
status: Active
version: 1.21
date: 2026-10-01
last_reviewed: 2026-10-01
keywords: backend, licoes, prevencao, incidentes
related_files: ../README.md, ../adrs/README.md, ../prds/README.md
code_references: app/
principal_statement: Cada lição registra causa, resolução, prevenção e fontes vigentes relacionadas.
---

# Índice de Lições Aprendidas: Backend

## Contrato da coleção

- Conteúdo aceito: lições transferíveis de arquitetura, domínio, dados, integrações, segurança, testes e operação do backend.
- Owner: Backend e Qualidade.
- Nomes: `LL-BE-NNNNN-short-title.md`; o mesmo `LL-BE-NNNNN` aparece nos metadados, título e catálogo.
- Estados permitidos: `Draft`, `Validated` e `Deprecated`.
- Critério de granularidade: separar uma lição quando causa, resolução, prevenção, owner ou ciclo de validação forem independentes.
- Inventário atual: nenhum documento está registrado neste baseline. O catálogo
  histórico abaixo foi preservado apenas como referência textual e não representa
  artefatos ativos.

Este diretório centraliza e mapeia os principais aprendizados técnicos de arquitetura do backend.

Convenção obrigatória: `LL-BE-NNNNN-short-title.md`; título, `Document ID` e
referências usam `LL-BE-NNNNN`. Estados: `Draft`, `Validated`, `Deprecated`.

~~~text

---

| ID | Categoria | Lição | Resumo do Problema |
| :--- | :--- | :--- | :--- |
| [LL-BE-00001](LL-BE-00001-filter-registration-npe-cglib-proxying.md) | **Segurança** | Filter Registration NPE | Proxy CGLIB não repassava propriedades base em `OncePerRequestFilter`. |
| [LL-BE-00002](LL-BE-00002-spring-modulith-schema-evolution.md) | **Arquitetura** | Spring Modulith Schema | O módulo de Eventos estava defasado na estrutura DDL exigida. |
| [LL-BE-00003](LL-BE-00003-event-package-exposure.md) | **Arquitetura** | Event Package Exposure | Classes de Eventos não podiam ser lidas externamente por restrições Modulith. |
| [LL-BE-00004](LL-BE-00004-named-interface-dependencies.md) | **Arquitetura** | Named Interface Syntax | Referência ambígua injetando falhas nas barreiras de pacotes abertos. |
| [LL-BE-00005](LL-BE-00005-cyclic-dependencies-via-events.md) | **Arquitetura** | Cyclic Dependencies | Publicações bidirecionais de Eventos fechavam o DAG causando ciclo arquitetural. |
| [LL-BE-00006](LL-BE-00006-h2-test-dialect-conflicts.md) | **Persistência** | H2 Test Dialect Conflicts | Migrações postgres incompatíveis rodando sobre o banco in-memory nativo. |
| [LL-BE-00007](LL-BE-00007-testcontainers-ci-constraints.md) | **Infraestrutura**| Testcontainers CI Constraints | Ausência remota do Docker daemon crachando pipelines inteiros invés de pular testes. |
| [LL-BE-00008](LL-BE-00008-postgresql-15-schema-grants.md) | **Infraestrutura**| PostgreSQL 15+ Grants | Engine do Postgres fechou revogação ao SCHEMA PUBLIC criando Access Denied na subida. |
| [LL-BE-00009](LL-BE-00009-keycloak-health-check-no-curl.md) | **Infraestrutura**| Keycloak Check (No Curl) | Container de Auth limou biblioteca cURL quebrando inteiramente todos os Healthchecks. |
| [LL-BE-00010](LL-BE-00010-dev-credentials-externalization.md) | **Infraestrutura**| Dev Cred. Externalization | Chaves primarias restritas expostas diretamente nos root descriptors Docker Compose. |
| [LL-BE-00011](LL-BE-00011-docker-compose-root-placement.md) | **Infraestrutura**| Compose Root Placement | Contextos isolados docker perdendo resoluções de paths devida a posição em subpastas. |
| [LL-BE-00012](LL-BE-00012-archunit-fail-on-empty-should.md) | **Arquitetura** | ArchUnit Empty Should | Camadas puras ainda não implementadas ativavam falsos positivos no Linter. |
| [LL-BE-00013](LL-BE-00013-jackson-dependency-catch-all.md) | **Arquitetura** | Jackson Dependency Missing | Modelo de Domínio maculado silenciosamente por importações abusivas do FasterXML. |
| [LL-BE-00014](LL-BE-00014-partial-naming-conventions-checked.md) | **Arquitetura** | Partial Naming Checked | Automação ArchUnit omitiu a validação de 8 designações core do Clean Architecture. |
| [LL-BE-00015](LL-BE-00015-scheduled-placement-rule-missing.md) | **Arquitetura** | Scheduled Placement Rule | Anotações temporizadas `@Scheduled` evadindo restrições pacotadas sem serem rastreadas. |
| [LL-BE-00016](LL-BE-00016-explicit-null-guard-entity-fields.md) | **Persistência** | Explicit Entity Null Guard | Modelos aceitavam silenciosamente IDs de Tenant nulos propagando poluição massiva. |
| [LL-BE-00017](LL-BE-00017-defensive-entitymanager-guard.md) | **Persistência** | Defensive Entity Guard | Filtros do BD deflagrados prematuramente pelo Hibernate gerando pane sistêmica no boot. |
| [LL-BE-00018](LL-BE-00018-aop-starter-dependency.md) | **Persistência** | AOP Starter Dependency | Conflito transitivo do Spring-Boot e AOP quebrando a compilação POM completa localmente. |
| [LL-BE-00019](LL-BE-00019-tenantcontext-null-guard.md) | **Segurança** | TenantContext Null Guard | Escapamentos em handlers liberando a Thread principal para sobrescrever Nulls aos Locatários. |
| [LL-BE-00020](LL-BE-00020-threadlocal-cleanup-tests.md) | **Segurança** | ThreadLocal Cleanup Test | Runners unitários poluídos e reaproveitados espalhando contexto inter-testes pelo Try/Catch. |
| [LL-BE-00021](LL-BE-00021-ide-modulith-false-positives.md) | **Arquitetura** | IDE Modulith False Positives | Linter gráfico hostil desabilitando interfaces Type.OPEN sob avisos fakes de subversão interna. |
| [LL-BE-00022](LL-BE-00022-audit-requires-new-transaction.md) | **Persistência** | Audit REQUIRES_NEW Transaction | Registros FAILURE de auditoria sendo perdidos no rollback da transação de negócio por ausência de REQUIRES_NEW. |
| [LL-BE-00023](LL-BE-00023-silent-audit-data-loss-constraint.md) | **Segurança** | Silent Audit Data Loss | Perda silenciosa de audit entries por mismatch entre `tenantId=null` no Java e `NOT NULL` no banco. |
| [LL-BE-00024](LL-BE-00024-client-ip-extraction-aop.md) | **Observabilidade** | Client IP in AOP Aspects | Registros `@Audited` sem IP do cliente por falta de extração via `RequestContextHolder`. |
| [LL-BE-00025](LL-BE-00025-operator-precedence-conditional-guard.md) | **Segurança** | Operator Precedence Bug | Precedência de `&&` sobre `\|\|` sem parênteses causava AIOOBE em paths curtos no `ModuleMdcFilter`. |
| [LL-BE-00026](LL-BE-00026-alertmanager-invalid-discord-configs.md) | **Infraestrutura** | Alertmanager Invalid Config | Chave `discord_configs` inexistente e `${ENV}` não suportado impediam o container de iniciar. |
| [LL-BE-00027](LL-BE-00027-profile-config-fragmentation.md) | **Infraestrutura** | Profile Config Fragmentation | Duplicação `.properties` vs `.yml` e ausência de Keycloak OAuth2 em profiles hml/prd. |
| [LL-BE-00028](LL-BE-00028-domain-model-duplication-refactoring.md) | **Arquitetura** | Domain Model Duplication | Falha de refactoring (cópia vs. mover) gerando entidades órfãs sem auditoria e Use Cases comentados em no-op. |
| [LL-BE-00029](LL-BE-00029-ddl-jpa-entity-mismatch.md) | **Persistência** | DDL/JPA Entity Mismatch | Colunas ausentes no Flyway DDL e divergência de modelo de identidade (composite key vs UUID) entre JPA entity e domínio. |
| [LL-BE-00030](LL-BE-00030-archunit-anonymous-class-false-positive.md) | **Arquitetura** | ArchUnit Anonymous Class False Positive | Regras de nomenclatura ArchUnit capturavam classes anônimas geradas pelo compilador (switch expressions). |
| [LL-BE-00031](LL-BE-00031-pii-leak-via-exception-messages-audit.md) | **LGPD** | PII Leak via Exception Messages | Mensagens de `BusinessException` com e-mail/Documento vazavam para tabela imutável `audit_log` via `AuditAspect.detail("errorMessage")`. |
| [LL-BE-00032](LL-BE-00032-duplicate-event-package-orphan.md) | **Arquitetura** | Duplicate Event Package Orphan | Pacote `event/` (singular) órfão sem `@NamedInterface` coexistia com `events/` (canônico), gerando eventos fantasma sem `DomainEvent`. |
| [LL-BE-00033](LL-BE-00033-dead-code-blueprint-placeholders.md) | **Arquitetura** | Dead Code Blueprint Placeholders | Interfaces placeholder (`Optional<?>`) e VOs não utilizados sobreviveram ao refactoring entre Blueprint e Use Cases. |
| [LL-BE-00034](LL-BE-00034-aes-ecb-deterministic-encryption.md) | **Segurança** | AES/ECB Deterministic Encryption | `Cipher.getInstance("AES")` usa ECB por default — criptografia determinística vulnerável a pattern analysis. |
| [LL-BE-00035](LL-BE-00035-public-api-interface-missing-implementation.md) | **Arquitetura** | Public API Missing Implementation | A interface pública exposta entre módulos (`FiscalApi`) não possuía bean implementador, quebrando a injeção no boot. |
| [LL-BE-00036](LL-BE-00036-entity-fields-lost-in-acl-translation.md) | **Arquitetura** | Entity Fields Lost in ACL Translation | Campos do `EmitirDarfCommand` (`codigoReceita`, `periodo`, `consultaId`) eram silenciosamente descartados na construção da entidade `Darf` dentro do adapter SERPRO. |
| [LL-BE-00037](LL-BE-00037-domain-invariant-leaked-into-constructor.md) | **Arquitetura** | Domain Invariant Leaked into Constructor | Validação de invariante de negócio (valor positivo) colocada no construtor privado impede reconstituição de dados históricos do banco e acopla detalhe de representação (`BigDecimal`) ao núcleo da entidade. |
| [LL-BE-00038](LL-BE-00038-primitive-type-in-cross-module-event-loses-semantics.md) | **Arquitetura** | Primitive Type in Cross-Module Event Loses Semantics | Campos monetários (`BigDecimal`) em eventos de domínio cross-module sem campo `currency` companheiro fazem consumidores assumirem a moeda silenciosamente, criando risco de inconsistência em ambientes multi-moeda. |
| [LL-BE-00039](LL-BE-00039-infra-details-leaking-into-port-signatures.md) | **Arquitetura** | Infrastructure Details Leaking into Port Signatures | Parâmetros de infra (`byte[] certificatePayload`, `String certificatePassword`) na assinatura de uma porta de saída violam o princípio de inversão de dependência — detalhes de mTLS devem ser encapsulados no adaptador, não expostos na interface de domínio. |
| [LL-BE-00040](LL-BE-00040-duplicate-event-listeners-for-cache-eviction.md) | **Arquitetura** | Duplicate Event Listeners for Cache Eviction | Múltiplos listeners do mesmo evento para evictar caches diferentes causam overhead desnecessário de transação e registro no Spring Modulith; use @Caching. |
| [LL-BE-00041](LL-BE-00041-circular-reference-in-observability-bootstrap.md) | **Observabilidade** | Observability Bootstrap Cycle | Referência circular no `observationRegistry` forçada pela autodescoberta precoce de `ObservationFilter`. |
| [LL-BE-00042](LL-BE-00042-darf-entity-field-mismatch-data-loss.md) | **Persistência** | Domain ↔ Entity ↔ DDL Mismatch | Campos `codigoReceita`, `periodo`, `consultaId` presentes no domínio `Darf` mas ausentes na entity JPA e no DDL, causando perda silenciosa de dados. |
| [LL-BE-00043](LL-BE-00043-circuitbreaker-placement-adr-violation.md) | **Resiliência** | CircuitBreaker Placement Violation | `@CircuitBreaker` posicionado nos use cases violava ADR-0011 — deve existir exclusivamente na camada `adapter.out.external`. |
| [LL-BE-00044](LL-BE-00044-domain-entity-leak-via-rest-response.md) | **Clean Architecture** | Domain Entity Leak via REST | Controller retornava aggregate root de domínio diretamente, expondo Value Objects internos (`TenantId`, `Cnpj`) na serialização JSON. |
| [LL-BE-00045](LL-BE-00045-fetch-type-eager-n1-and-lazy-init-exception.md) | **Persistência** | FetchType.EAGER N+1 e LazyInit | `FetchType.EAGER` em `@OneToMany` causa N+1 queries; corrigir para `LAZY` sem `@Transactional` no adapter lança `LazyInitializationException`. |
| [LL-BE-00046](LL-BE-00046-cache-self-cancel-evict-same-flow.md) | **Caching** | Cache Self-Cancel via Event | `@CacheEvict` acionado por evento publicado pelo mesmo fluxo que populou o cache torna o cache permanentemente ineficaz — `fiscal:situacao` era populado e evicado na mesma operação. |
| [LL-BE-00047](LL-BE-00047-adapter-todomain-create-vs-reconstitute.md) | **Persistência** | Adapter toDomain create vs reconstitute | `toDomain()` usando `Entity.create()` gera novo UUID e reseta status, perdendo silenciosamente todo estado persistido. Usar `reconstitute()`. |
| [LL-BE-00048](LL-BE-00048-webmvctest-securityconfig-default-fallback.md) | **Segurança** | WebMvcTest Security Fallback | Remoção do `@Import(SecurityConfig.class)` em testes unitários engatilha bloqueio HTTP 401 automático pelo Spring Boot. |
| [LL-BE-00049](LL-BE-00049-record-constructor-argument-order-swap.md) | **Arquitetura** | Record Argument Order Swap | Inversão silenciosa de argumentos `long` em Records Java causa dados trocados sem erro de compilação. |
| [LL-BE-00050](LL-BE-00050-triple-audit-duplication-aop-service-event.md) | **Observabilidade** | Triple Audit Duplication | Mesma ação (`WHATSAPP_MESSAGE_RECEIVED`) registrada 3x por `@Audited` + `Service.log*()` + `@ApplicationModuleListener`, triplicando I/O e poluindo o audit trail. |
| [LL-BE-00051](LL-BE-00051-omnichannel-chatbot-refactoring.md) | **Arquitetura** | Omnichannel Chatbot Refactoring | Abstração do domínio (ex: `phoneNumberId` para `channelAccountId`) e uso de Strategy Pattern para adicionar o Telegram sem duplicar a state machine. |
| [LL-BE-00052](LL-BE-00052-omnichannel-test-refactoring.md) | **Arquitetura** | Omnichannel Test Refactoring | Refatoração de testes para suportar `ChannelType` omnichannel sem quebrar cobertura existente. |
| [LL-BE-00053](LL-BE-00053-npe-external-api-response-dto-contract.md) | **Arquitetura** | NPE em DTO de Resposta de API Externa | `response.result()` acessado sem null-check após `ok == true`, e `int` subdimensionado para IDs de APIs externas. |
| [LL-BE-00054](LL-BE-00054-telegram-webhook-security-token.md) | **Segurança** | Telegram Webhook Security Token | Ausência de validação do header `X-Telegram-Bot-Api-Secret-Token` expunha o endpoint de webhook a requisições forjadas usando o secret exposto na path variable. |
| [LL-BE-00055](LL-BE-00055-derived-delete-missing-transactional.md) | **Persistência** | Derived Delete Missing @Transactional | Método derivado `deleteByXxx()` no Spring Data JPA sem `@Transactional` causa crash em runtime (`InvalidDataAccessApiUsageException`) mascarado por testes com mocks. |
| [LL-BE-00056](LL-BE-00056-keycloak-local-volume-persistence.md) | **Infraestrutura** | Keycloak Local Volume Persistence | O Keycloak não re-importa o realm a partir do `saas-dev-realm.json` se o banco local persistente já estiver criado, causando perca da sincronia (`Invalid user credentials`). |
| [LL-BE-00057](LL-BE-00057-webhook-registration-url-mismatch.md) | **Integração** | Webhook Registration URL Mismatch | `RegisterTelegramWebhookUseCase` registrava path `/api/v1/webhooks/telegram/` divergente do `TelegramWebhookController` (`/api/v1/telegram/webhook/`), causando 404 silencioso sem logs no backend. |
| [LL-BE-00058](LL-BE-00058-global-external-auth-vs-per-tenant.md) | **Arquitetura** | Global Auth vs Per-Tenant | Injeo global esttica de credenciais via @Value impedia o SAAS de escalar para autenticaes multi-inquilinos na API do SERPRO. |
| [LL-BE-00059](LL-BE-00059-state-machine-security-transitions.md) | **Segurança** | State Machine Security Transitions | Transições de revogação para `VALIDATE_ACCESS` não estavam permitidas a partir dos estados autenticados. |
| [LL-BE-00060](LL-BE-00060-multi-datasource-jpa-scanning.md) | **Persistência** | Multi-DataSource JPA Scanning | Entidades em novos pacotes sofrem falha silenciosa de injeção (NoSuchBeanDefinitionException) se não registradas no `setPackagesToScan` e `@EnableJpaRepositories` do `DataSourceConfig` específico no ecossistema multi-database. |
| [LL-BE-00061](LL-BE-00061-super-admin-impersonation-architecture.md) | **Segurança** | Super Admin Impersonation | Personificação exigia propagação explícita do tenant, autorização coerente e auditoria sem tenant implícito. |
| [LL-BE-00062](LL-BE-00062-serpro-io-null-stale-restclient-connection.md) | **Integração** | SERPRO Stale RestClient | Ausência de timeouts, conexões stale e logging incompleto mascaravam falhas de I/O do SERPRO. |
| [LL-BE-00063](LL-BE-00063-serpro-av02-rate-limit-retry-pattern.md) | **Resiliência** | SERPRO AV02 Retry Pattern | O aviso AV02 exige Result Object, persistência do tempo de espera e polling assíncrono, sem bloquear a thread HTTP. |
| [LL-BE-00064](LL-BE-00064-temporary-credentials-in-url-query-string.md) | **Segurança** | Temporary Credentials in URL | Credenciais temporárias (senhas, tokens de sessão) expostas via query string vazam em logs, browser history e Referer headers. |
| [LL-BE-00065](LL-BE-00065-blind-save-masked-credentials.md) | **Segurança** | Blind Save Masked Credentials | Frontend reenvia string de máscara (`********`) que o Backend persiste cegamente, corrompendo a credencial real. |
| [LL-BE-00066](LL-BE-00066-cross-tenant-findbyid-without-tenant-filter.md) | **Segurança** | Cross-Tenant findById sem Tenant Filter | Método `findById(UUID id)` sem filtro de `tenant_id` na interface do repositório cria vetor latente de acesso cross-tenant quando consumido por endpoints REST. |
| [LL-BE-00067](LL-BE-00067-flyway-injected-with-routing-datasource.md) | **Persistência** | Flyway Injected with Routing DataSource | Injetar `AbstractRoutingDataSource` (ThreadLocal-based) no Flyway de startup causa falha no boot ou migração no banco errado silenciosamente. Use sempre o `*DefaultDataSource` estático. |
| [LL-BE-00068](LL-BE-00068-ddl-injection-via-dynamic-database-name.md) | **Segurança** | DDL Injection via Dynamic Database Name | Nomes de objetos DDL (bancos, schemas) derivados de entrada de usuário sem allow-list estrita criam vetor de SQL Injection — `PreparedStatement` não protege DDL. |
| [LL-BE-00069](LL-BE-00069-missing-grant-after-create-database.md) | **Segurança** | Missing GRANT After CREATE DATABASE | Banco criado programaticamente sem `GRANT` subsequente impede acesso do usuário de aplicação, especialmente no PostgreSQL 15+ onde permissões padrão são mais restritivas. |
| [LL-BE-00070](LL-BE-00070-domain-reconstitution-signature-fragility.md) | **Arquitetura** | Domain Reconstitution Signature Fragility | O crescimento do número de parâmetros no método de fábrica/reconstituição quebra todos os adaptadores e arrisca inversão de argumentos em tempo de execução. Utilizar Padrão Builder ou State Context. |
| [LL-BE-00071](LL-BE-00071-multitenant-threadlocal-async-realm-routing.md) | **Arquitetura** | ThreadLocal Perdido em Async | ThreadLocal falha em fluxos assíncronos (IdP/BD) e realm fixo quebra multi-tenancy. Exige TaskDecorator e resolução de tenant por token. |
| [LL-BE-00072](LL-BE-00072-inconsistent-naming-conventions-hyphen-vs-underscore.md) | **Arquitetura** | Naming Dialects (Hyphen vs Underscore) | Conflito silencioso (404) na resolução de slugs quando injetados usando underscores (Padrão BD) no Keycloak ao invés de hifens (Dialeto Web). |
| [LL-BE-00073](LL-BE-00073-multi-realm-jwt-docker-network-fallback.md) | **Segurança** | OIDC Discovery & Fallback | Falha na resolução de nomes do container OIDC via Docker Network em ambientes isolados causava erro de conexão no boot do Keycloak. |
| [LL-BE-00074](LL-BE-00074-authentication-manager-resolver-null-npe.md) | **Segurança** | AuthenticationManagerResolver NPE | Retornar `null` do AuthenticationManagerResolver no Spring Security 6+ causa `NullPointerException` interno no `BearerTokenAuthenticationFilter`. O correto é lançar exceção ou tratar via `BearerTokenResolver`. |
| [LL-BE-00075](LL-BE-00075-template-delivery-before-final-tool-calling.md) | **Arquitetura** | Template antes de Tool Calling | Unir relatório e ação na mesma resposta LLM permite `content=null`; a entrega do template deve ser uma barreira anterior às tools finais. |
| [LL-BE-00076](LL-BE-00076-controller-tenant-context-and-provisioned-rbac.md) | **Segurança** | Tenant Context e RBAC provisionado | Controllers devem consumir o tenant da fonte canonica e autorizar somente roles realmente provisionadas. |
| [LL-BE-00077](LL-BE-00077-jwt-audience-emission-and-validation-contract.md) | **Segurança** | Contrato de Audience JWT | A API nao pode exigir uma audience que o Keycloak nao emite; template, exports e validacao precisam evoluir juntos. |
| [LL-BE-00078](LL-BE-00078-keycloak-service-account-and-onboarding-compensation.md) | **Segurança** | Service Account e compensacao | Credencial de bootstrap nao e identidade de runtime; onboarding distribuido exige Service Account e compensacao integral. |
| [LL-BE-00079](LL-BE-00079-gitignore-out-hides-clean-architecture-ports.md) | **Supply Chain** | Gitignore ocultando ports | Regra global de output ocultava novas interfaces em `application/port/out`, fazendo workspace compilar e clone limpo falhar. |
| [LL-BE-00080](LL-BE-00080-super-admin-token-must-not-carry-tenant-id.md) | **Segurança** | Super Admin sem tenant implícito | Realm administrativo emitia UUID tenant fictício; token global agora não possui `tenant_id` e impersonação exige header validado. |
| [LL-BE-00081](LL-BE-00081-jackson3-write-dto-server-owned-primitive.md) | **Clean Architecture** | Jackson 3 e DTO de escrita | DTO de resposta exigia o primitivo protegido `isSystem`; requests e comandos de escrita agora sao separados. |
| [LL-BE-00082](LL-BE-00082-conversational-history-outbound-persistence-inbound-once.md) | **Arquitetura** | Histórico conversacional canônico | Resposta da LLM enviada sem `OUTBOUND` persistido e `INBOUND` corrente duplicado no prompt quebravam a continuidade em qualquer canal. |
| [LL-BE-00083](LL-BE-00083-fiscal-report-protocol-loss-must-not-lock-conversation.md) | **Resiliência** | Protocolo perdido não bloqueia conversa | Regra histórica supersedida pelo REQ-00040: ER04 repete `/Emitir`; ER05 reinicia `/Apoiar`; falha terminal libera `FISCAL_QUERY` em todos os canais. |
| [LL-BE-00084](LL-BE-00084-disabled-architecture-gates-mask-structural-debt.md) | **Arquitetura** | Gates desabilitados mascaram dívida | Gate ignorado torna a suíte verde inválida e acumula violações cross-context. |
| [LL-BE-00085](LL-BE-00085-tenant-context-before-transaction-and-real-postgres.md) | **Segurança** | Tenant antes da transação | Isolamento só é comprovado com contexto anterior ao boundary e PostgreSQL/Flyway reais. |
| [LL-BE-00086](LL-BE-00086-previous-state-is-not-workflow-origin.md) | **Arquitetura** | Estado anterior não é origem do workflow | Funções multi-step precisam de pós-condição explícita; usar `previousState` como retorno pode levar uma conversa autenticada a `COMPLETED/WELCOME`. |
| [LL-BE-00087](LL-BE-00087-control-commands-must-bypass-the-llm.md) | **Arquitetura** | Comandos de controle fora da LLM | Logout/reset e outros comandos reservados devem ser determinísticos, limpar a sessão e criar fronteira de histórico sem depender de provider, quota ou canal. |
| [LL-BE-00088](LL-BE-00088-conversation-identity-includes-channel-account.md) | **Arquitetura** | Identidade inclui conta do canal | Omitir `channelAccountId` da chave reaproveita a sessão órfã após delete/recreate; ACK `200` assíncrono não comprova commit nem outbound. |
| [LL-BE-00089](LL-BE-00089-flyway-concurrent-index-self-block.md) | **Persistência** | Índice concorrente autobloqueia Flyway | `CREATE INDEX CONCURRENTLY` no startup aguardou uma transação do próprio Flyway via `virtualxid`; DDL online deve respeitar o lifecycle e ter diagnóstico/timeout. |
| [LL-BE-00090](LL-BE-00090-telegram-answer-callback-query-mandatory.md) | **Integração** | Telegram callback query obrigatório | Callbacks do Telegram exigem confirmação explícita para encerrar o estado de loading do cliente. |
| [LL-BE-00091](LL-BE-00091-long-lived-chatbot-transaction-exhausts-tenant-pool.md) | **Resiliência** | Transação longa e inversão pai/filho | Rede/lock prolongados e flush do pai antes de filho `REQUIRES_NEW` bloqueiam o worker; ordem transacional, admissão e limites evitam starvation. |
| [LL-BE-00092](LL-BE-00092-postgresql-jdbc-instant-binding.md) | **Persistência** | `Instant` exige binding JDBC explícito | PostgreSQL JDBC não inferiu o tipo SQL de `Instant`; adapters convertem para `Timestamp` e testes usam PostgreSQL real. |
| [LL-BE-00093](LL-BE-00093-webhook-ack-is-not-worker-completion.md) | **Resiliência** | ACK não é conclusão do worker | Sucesso após fila in-memory cria perda pós-ACK; custódia exige commit, recovery e retry separado por checkpoint de efeito. |
| [LL-BE-00094](LL-BE-00094-fallback-must-be-terminal-and-truthful.md) | **Resiliência** | Fallback deve ser terminal e verdadeiro | A resposta de degradação encerra o turno, preserva estado retomável e não promete trabalho futuro inexistente. |
| [LL-BE-00095](LL-BE-00095-visible-menu-does-not-define-conversation-state.md) | **Arquitetura** | Menu visível não define o estado | Identidade do escritório e menu são saídas determinísticas do core; provider ativo define o estado e adapters apenas renderizam. |
| [LL-BE-00096](LL-BE-00096-social-language-is-not-a-lifecycle-command.md) | **Arquitetura** | Linguagem social não é lifecycle | O core classifica efeitos antes da geração: comando exato, texto sem tools, callback fixo ou tool calling; adapters apenas normalizam e renderizam. |
| [LL-BE-00097](LL-BE-00097-quarantine-must-not-poison-fifo.md) | **Resiliência** | Quarentena não envenena FIFO | `Validated`: revisão preserva o resultado incerto sem bloquear sucessoras; trabalho ativo renova lease com owner e fence. |
| [LL-BE-00098](LL-BE-00098-progress-must-not-contend-with-authoritative-aggregate.md) | **Persistência** | Progresso não disputa aggregate | `Validated`: notificação efêmera usa ledger de entrega sem transformar listeners assíncronos em writers concorrentes do aggregate funcional. |
| [LL-BE-00099](LL-BE-00099-operational-history-is-not-conversational-truth.md) | **Arquitetura** | Histórico operacional não é verdade conversacional | `Validated`: mensagem transitória permanece auditável, mas uma fronteira explícita impede que continue sendo tratada pela LLM como autoridade vigente. |
| [LL-BE-00100](LL-BE-00100-plan-compliance-requires-atomic-admission.md) | **Arquitetura** | Compliance de plano exige admissão atômica | `Validated v1.4`: enforcement reserva atomicamente; KPI reconcilia somente consumo confirmado na mesma unidade/janela, sem dupla contagem. |
| [LL-BE-00101](LL-BE-00101-conversation-audit-coordinator-permissions-and-pinning.md) | **Infraestrutura** | Permissões e pinagem do coordenador | Proteção fail-closed em DEV rejeita coordenador com escrita para grupo (máscara 022); script exige 0755/0700 e UID do executor. |

~~~

## Change log

| Versão | Data | Mudança |
| --- | --- | --- |
| 1.21 | 2026-10-01 | Indexa a LL-BE-00101 sobre permissões POSIX, umask e pinagem fail-closed do coordenador de Conversation Audit em DEV. |
| 1.20 | 2026-09-10 | Atualiza LL-BE-00100 para v1.4 com reconciliação monotônica, separação entre reservas e confirmados e evidência do KPI inbound-only. |
| 1.19 | 2026-09-10 | Atualiza LL-BE-00100 para v1.3 com a regra agnóstica de paridade semântica entre enforcement e KPI contratual. |
| 1.18 | 2026-09-09 | Atualiza LL-BE-00100 para v1.2 com lifecycle canônico e Quality Gate focused verdes, separando o blocker JaCoCo do PR. |
| 1.17 | 2026-09-09 | Promove LL-BE-00100 a `Validated` após 46/46 testes de persistência, enforcement, lifecycle e arquitetura. |
| 1.16 | 2026-09-09 | Indexa a LL-BE-00100 sobre decisão, reserva e observação em hard limits de plano, capacidade e compliance. |
| 1.15 | 2026-09-04 | Promove a LL-BE-00099 a `Validated` após provas de ledger, fronteira, prompt e arquitetura. |
| 1.14 | 2026-09-04 | Indexa a LL-BE-00099 sobre separar evidência operacional durável do contexto generativo vigente. |
| 1.13 | 2026-09-03 | Promove a LL-BE-00098 a `Validated` após provas focalizadas, omnichannel e arquiteturais. |
| 1.12 | 2026-09-03 | Indexa a LL-BE-00098 sobre separar progresso transitório, evidência durável e persistência do aggregate em qualquer canal. |
| 1.11 | 2026-09-03 | Amplia a LL-BE-00091 com a inversão de lock entre conversa pai e tentativa outbound filha, válida para qualquer canal. |
| 1.10 | 2026-09-02 | Promove a LL-BE-00097 a `Validated` após testes unitários e PostgreSQL parametrizados por canal. |
| 1.9 | 2026-09-02 | Indexa a LL-BE-00097 sobre quarentena terminal, poison head-of-line e heartbeat fenced agnósticos de canal. |
| 1.8 | 2026-09-01 | Indexa individualmente a LL-BE-00096 sobre separar linguagem social, comandos de lifecycle, workflows fixos e tool calling pelo efeito autorizado. |
| 1.7 | 2026-09-01 | Indexa individualmente a LL-BE-00095 sobre a separação entre apresentação do menu, identidade tenant-scoped e estado conversacional. |
