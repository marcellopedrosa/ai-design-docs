---
document_id: "ADR-0001"
primary_nature: "Decisao"
objective: "Registrar a decisão arquitetural “Technology Stack and Architecture Foundation”, seus motivadores, alternativas e consequências."
scope: "Decisão, componentes, integrações e limites explicitamente descritos em “Technology Stack and Architecture Foundation”."
non_objectives: "Não implementar a decisão, substituir requisitos relacionados nem atestar capabilities ou ambientes sem evidência explícita."
owner: "AgentOrchestrator"
status: "Partially Superseded"
date: "2026-03-06"
last_reviewed: "2026-08-28"
version: "1.1"
keywords: "adr, decisao, arquitetura, technology, stack, and, architecture, foundation"
related_files: "docs/adrs/README.md, docs/adrs/ADR-0005-multi-tenancy-architecture.md, docs/adrs/ADR-0053-adocao-java-25-backend.md, artefatos de análise/ANL-00050-java-25-backend-impact-analysis.md, docs/product/business/product-vision.md, docs/agents/README.md"
code_references: "backend/, frontend/, docker-compose.yml"
principal_statement: "The Spring Boot 4, Spring Modulith, Clean Architecture, DDD, SOLID, OpenAPI, Docker Compose and evolutionary-modulith foundation remains accepted; ADR-0053 supersedes only Java 21 as the target toolchain/runtime and its version-dependent concurrency and runtime-efficiency prescriptions."
---

# ADR-0001 - Technology Stack and Architecture Foundation

- Date: 2026-03-06
- Status: Partially Superseded
- Version: 1.1
- Authors / Owners: AgentOrchestrator
- Reviewers: ArquitetoHexagonal, DomainExpert, DevOps-Agent
- Stakeholders: Engineering Team, Product Owner, Startup Founders
- Partially superseded by: [ADR-0053](ADR-0053-adocao-java-25-backend.md), exclusively for Java 21 as target toolchain/runtime and the concurrency/runtime-efficiency prescriptions that depend on that version.

---

> [!IMPORTANT]
> Since 2026-08-28, ADR-0053 governs the target Java version, staged use of
> virtual threads and measured backend footprint. Java 21 references below
> preserve the original decision and remain the AS-IS implementation baseline
> until the Java 25 cutover gates pass. Spring Boot 4, Spring Modulith, Clean
> Architecture, DDD, SOLID, OpenAPI, Docker Compose and the evolutionary
> modulith remain governed by this ADR.

# 1. Context

The project "Hub Contabil Inteligente" is a multi-tenant micro-SaaS platform designed for accounting firms. It automates federal tax queries and DARF issuance through WhatsApp integration, using digital certificates per tenant and the SERPRO Integra Contador API.

Key business context:

- The platform serves three distinct user profiles: SaaS Administrator, Accounting Firm (Subscriber), and End Client (Entrepreneur via WhatsApp).
- Multi-tenancy with strict data isolation between accounting firms is mandatory.
- Security is critical: WhatsApp number validation against registered Documentos, encrypted digital certificate storage, and full audit logging.
- The startup operates with minimal financial resources and cannot afford cloud provider costs.
- A single VPS server is the available infrastructure for initial deployment.
- The system must be designed for future scalability (migration from modulith to microservices) without requiring a full rewrite.

Technical constraints:

- No cloud spending (AWS, GCP, Azure) in the initial phases.
- All infrastructure must run on a single VPS with Docker.
- The architecture must support incremental evolution from monolith to microservices.
- The domain is complex enough to warrant Domain-Driven Design: tenants, digital certificates, fiscal queries, billing, WhatsApp integration.
- Integration with external government APIs (SERPRO) requires resilience patterns.
- LGPD compliance is required for handling taxpayer data.

The decision is needed to establish the foundational technology stack and architectural principles that will guide all development, ensuring the platform can be built cost-effectively while maintaining quality, security, and a clear path to scale.

---

# 2. Decision Statement

The system will be built using Java 21 with Spring Boot 4.x and Spring Modulith as the primary framework, following Clean Architecture and Domain-Driven Design (DDD) principles. The codebase will adhere to SOLID principles and Clean Code practices. All APIs will be documented via OpenAPI (Swagger). The initial deployment target is a single VPS server using Docker Compose, with the architecture designed to evolve into independently deployable microservices when business scale demands it.

---

# 3. Decision Drivers

- **Zero Cloud Cost:** The startup cannot afford cloud provider bills. All services must run on a self-hosted VPS.
- **Scalability Path:** The architecture must support a clear evolution from a modular monolith to microservices without rewriting core business logic.
- **Domain Complexity:** Multi-tenancy, fiscal integrations, digital certificates, and WhatsApp chatbot logic require a well-structured domain model.
- **Maintainability:** Clean Architecture and SOLID ensure long-term code health as the team and codebase grow.
- **Team Expertise:** Java/Spring is the primary team competency. Minimizing technology diversification reduces ramp-up time.
- **Security Requirements:** Digital certificate handling, tenant data isolation, and LGPD compliance require a mature security ecosystem.
- **API-First Development:** OpenAPI-driven development ensures frontend/backend decoupling and enables future third-party integrations.
- **Resilience:** Integration with SERPRO (government API) requires circuit breakers, retries, and fallback strategies.
- **Observability:** Spring Boot Actuator provides zero-cost monitoring and health checks.
- **AI Agent Orchestration:** The architecture must produce structured, machine-readable artifacts compatible with the autonomous agent factory.

---

# 4. Considered Options

## Option 1: Java 21 + Spring Boot 4.x + Spring Modulith (Selected)

Description: Modular monolith using Spring Modulith for bounded context isolation, with Java 21 virtual threads for concurrency, and Spring Boot ecosystem for security, data, and web.

Pros:
- Mature ecosystem with extensive library support
- Spring Modulith enforces module boundaries at compile time, enabling future microservice extraction
- Virtual threads (Project Loom) provide high concurrency without reactive complexity
- Spring Security provides built-in OAuth2, certificate handling, and multi-tenant support
- Spring Boot Actuator enables zero-cost observability
- Single deployable artifact simplifies VPS deployment
- Strong DDD and Clean Architecture community patterns

Cons:
- JVM memory footprint is higher than native alternatives
- Spring Modulith is relatively newer compared to Spring Cloud for microservices
- Requires discipline to maintain module boundaries over time

## Option 2: Node.js + NestJS + TypeScript

Description: Event-driven architecture using NestJS framework with TypeScript for type safety.

Pros:
- Lower memory footprint per process
- Fast development cycle for API-centric applications
- Native async/event-driven model

Cons:
- Weaker DDD/Clean Architecture tooling compared to Java/Spring
- TypeScript type system less robust than Java for complex domain models
- Multi-tenancy and certificate handling require custom implementation
- Team would need significant ramp-up time
- Less mature security ecosystem for government API integration

## Option 3: Go + Custom Framework

Description: Lightweight microservices from day one using Go for performance and minimal resource usage.

Pros:
- Extremely low memory footprint
- Compiled binary simplifies deployment
- Built-in concurrency model

Cons:
- No equivalent to Spring Modulith for gradual microservice extraction
- Significantly more boilerplate for DDD patterns
- Team has no Go expertise -- high ramp-up cost
- Immature ORM and security ecosystem compared to Spring
- Premature microservice decomposition increases operational complexity for a startup

## Option 4: N8N Workflow Automation + Spring Boot Backend

Description: Use N8N for orchestration and workflow automation with a Spring Boot backend for domain logic.

Pros:
- Visual workflow designer accelerates integration development
- Low-code approach for WhatsApp and SERPRO integrations
- Can be self-hosted on VPS

Cons:
- N8N is not designed for complex domain logic or multi-tenant isolation
- Introduces a separate runtime dependency with its own resource requirements
- Workflow logic is harder to test, version, and audit than code
- Tight coupling between visual workflows and business rules creates technical debt
- Limited support for DDD patterns and Clean Architecture

---

# 5. Decision Outcome

**Option 1 (Java 21 + Spring Boot 3.x + Spring Modulith)** was selected.

Key factors:

- **Cost efficiency:** A single Spring Modulith application running on Docker on a VPS is the most operationally simple and cost-effective option. No orchestration layer, no service mesh, no cloud dependencies.
- **Evolutionary architecture:** Spring Modulith provides compile-time enforcement of module boundaries. Each bounded context (Tenant Management, Fiscal Integration, Certificate Management, WhatsApp Channel, Billing) can be developed as an isolated module that can be extracted into an independent microservice when scale demands it.
- **Java 21 virtual threads:** Eliminates the need for reactive programming complexity while maintaining high concurrency for handling WhatsApp messages and SERPRO API calls simultaneously.
- **Security maturity:** Spring Security provides proven OAuth2, digital certificate integration, and multi-tenant security patterns out of the box.
- **DDD alignment:** Java's strong type system, combined with Spring Data and Spring Modulith's event publishing, provides an ideal foundation for DDD aggregates, domain events, and bounded context boundaries.

Tradeoffs accepted:

- Higher JVM memory footprint compared to Node.js or Go (mitigated by virtual threads reducing thread pool overhead).
- Spring Modulith is newer than Spring Cloud (mitigated by strong Spring team support and active development).
- Single deployable artifact limits horizontal scaling initially (acceptable for a startup with one VPS).

Other options were rejected because they either required team ramp-up (Go, Node.js), introduced premature complexity (microservices from day one), or lacked the domain modeling rigor required for this project (N8N, Node.js).

---

# 6. Consequences

Positive Consequences:

- Single application deployment simplifies DevOps on a VPS (Docker Compose with one application container, one database container, one Redis container).
- Module boundaries enforced by Spring Modulith prevent accidental coupling between bounded contexts.
- Java 21 virtual threads enable handling hundreds of concurrent WhatsApp sessions without reactive programming boilerplate.
- OpenAPI-first approach enables parallel frontend and backend development.
- Clean Architecture ensures business logic is independent of frameworks and infrastructure, facilitating testing and future migration.
- Spring Boot Actuator provides production-ready health checks, metrics, and monitoring at zero additional cost.

Negative Consequences:

- JVM requires approximately 512MB-1GB RAM baseline, which consumes a significant portion of a small VPS.
- The team must maintain discipline in respecting module boundaries; Spring Modulith detects violations but does not prevent all forms of coupling.
- A single JVM process is a single point of failure on the VPS (mitigated by systemd restart policies and health checks).

Neutral Consequences:

- The project will use Gradle as the build tool for multi-module support.
- Database migrations will use Flyway for version-controlled schema management.
- The project will require a structured package layout following Clean Architecture conventions.

---

# 7. Impact

- **Architecture:** All bounded contexts (Tenant Management, Fiscal Integration, Certificate Management, WhatsApp Channel, Billing) will be implemented as Spring Modulith modules with explicit public APIs (ports) and internal implementations (adapters).
- **Infrastructure:** Docker Compose on VPS with containers for: application (Spring Boot), database (PostgreSQL), cache (Redis), and reverse proxy (Nginx/Caddy).
- **Security:** Spring Security OAuth2 Resource Server for API authentication, custom multi-tenant security filters, encrypted certificate storage using Java KeyStore.
- **Development Process:** API-first development using OpenAPI Generator. Domain models reviewed by @DomainExpert before implementation.
- **Deployment Pipeline:** GitHub Actions with self-hosted runner on VPS, or local CI with Act. Docker image build, test, and deploy via SSH.
- **Data Architecture:** PostgreSQL with schema-per-tenant or discriminator-based isolation. Flyway migrations per tenant schema.
- **Observability:** Spring Boot Actuator endpoints exposed to Prometheus (Docker container), visualized in Grafana (Docker container).
- **DevOps:** Single Docker Compose file for all services. Caddy for automatic HTTPS with Let's Encrypt.
- **AI Agent Orchestration:** All architectural decisions and module boundaries are documented as .md artifacts consumable by the agent factory.

---

# 8. AI Agent Considerations (For Autonomous Agent Environments)

Agent Roles Impacted:

- **@ArquitetoHexagonal:** Defines hexagonal port/adapter boundaries within each Spring Modulith module.
- **@DomainExpert:** Models domain entities, value objects, and aggregates per bounded context module.
- **@ImplementerCore:** Implements use cases and domain services in Java 21 within Spring Modulith modules.
- **@AdapterDev:** Implements REST adapters (OpenAPI), JPA repositories, and external API integrations.
- **@ModulithConfig:** Configures Spring Modulith annotations, module declarations, and coupling verification.
- **@MultiTenantEng:** Implements tenant isolation at the database and application layers.
- **@DevOps-Agent:** Manages Docker Compose, GitHub Actions, and VPS deployment scripts.
- **@SecurityOAuth:** Configures Spring Security OAuth2 and digital certificate handling.
- **@CodeGuardian:** Enforces Clean Code and SOLID principles across all modules.
- **@TestAutomator:** Writes hexagonal unit and integration tests per module.

Operational Considerations:

- Agents must operate within Spring Modulith module boundaries. No agent may introduce cross-module dependencies without @ArquitetoHexagonal approval.
- Each agent's output must be a self-contained artifact (code, configuration, or documentation) that can be integrated without side effects.
- Token budget constraint of less than 5,000 tokens per agent per sprint must be respected.
- @AgentOrchestrator coordinates handoffs: @ArquitetoHexagonal defines the module, @DomainExpert models the domain, @ImplementerCore codes the logic, @AdapterDev wires the adapters.

LLM Considerations:

- Prompts must include Spring Modulith module context to avoid generating code that violates module boundaries.
- OpenAPI specifications serve as shared contracts between agents, reducing ambiguity in API implementation tasks.
- Code generation prompts should reference the project's Clean Architecture package structure to maintain consistency.

Safety Considerations:

- No agent may generate code that handles digital certificates without @SecurityOAuth review.
- No agent may modify tenant isolation logic without @MultiTenantEng and @SecurityOAuth approval.
- All database migration scripts require human review before execution.

---

# 9. Implementation Plan

## Phase 1 -- Project Foundation (Sprint 1-2)

- Initialize Spring Boot 3.x + Spring Modulith project with Gradle multi-module structure.
- Define Clean Architecture package layout: `domain`, `application`, `adapter.in.web`, `adapter.out.persistence`, `adapter.out.external`.
- Configure Spring Security with OAuth2 (Keycloak on Docker).
- Set up PostgreSQL with Flyway migrations on Docker Compose.
- Set up Redis for caching on Docker Compose.
- Configure OpenAPI (springdoc-openapi) for automatic API documentation.
- Implement Spring Boot Actuator health and metrics endpoints.
- Set up CI/CD pipeline with GitHub Actions self-hosted runner or Act.

## Phase 2 -- Core Bounded Contexts (Sprint 3-5)

- Implement Tenant Management module (tenant CRUD, subscription plans, user management).
- Implement Certificate Management module (encrypted upload, storage, retrieval).
- Implement Fiscal Integration module (SERPRO Integra Contador API client with circuit breaker).
- Implement Billing module (credit consumption tracking, plan management).

## Phase 3 -- WhatsApp Channel (Sprint 6-7)

- Implement WhatsApp Integration module (WhatsApp Business API adapter).
- Implement chatbot flow: authentication, menu, fiscal query, DARF generation.
- Implement access validation (phone number vs. registered Documento).
- Implement audit logging for all WhatsApp interactions.

## Phase 4 -- Observability and Hardening (Sprint 8)

- Deploy Prometheus + Grafana stack on Docker Compose.
- Configure alerting (Slack/Discord webhooks).
- LGPD compliance audit with @ComplianceAgent.
- Security penetration testing with @SecurityAgent.
- Performance testing under simulated multi-tenant load.

Dependencies:

- Phase 2 depends on Phase 1 (project foundation).
- Phase 3 depends on Phase 2 (fiscal integration and certificate modules).
- Phase 4 runs in parallel with Phase 3 for non-WhatsApp modules.

Rollback Plan:

- Each phase is deployed independently. If a phase introduces regressions, the previous Docker image version is redeployed via `docker compose up -d --force-recreate`.
- Database migrations include rollback scripts for every Flyway migration.

Responsible Teams / Agents:

- Phase 1: @ArquitetoHexagonal, @ModulithConfig, @DevOps-Agent, @SecurityOAuth
- Phase 2: @DomainExpert, @ImplementerCore, @AdapterDev, @MultiTenantEng
- Phase 3: @DomainExpert, @ImplementerCore, @AdapterDev, @FrontendWeb
- Phase 4: @ObservabilityDev, @Monitoring-Agent, @ComplianceAgent, @SecurityAgent

---

# 10. Validation

Architecture Validation:

- Spring Modulith `ApplicationModules.verify()` tests confirm no illegal cross-module dependencies.
- ArchUnit tests enforce Clean Architecture layer rules (domain must not depend on adapters).
- Code review by @CodeGuardian for SOLID and Clean Code compliance.

Performance Benchmarks:

- API response time under 200ms for fiscal queries (excluding SERPRO latency).
- Support for 100 concurrent WhatsApp sessions on a single VPS (2 vCPU, 4GB RAM).
- JVM memory usage under 1GB under normal load.

Security Audits:

- OWASP Top 10 scan by @SecurityAgent.
- Penetration testing on multi-tenant isolation.
- Digital certificate storage encryption verification.

Observability Metrics:

- Spring Boot Actuator health endpoint confirms all modules are operational.
- Prometheus metrics validate request latency, error rates, and JVM health.
- Audit log completeness: 100% of WhatsApp interactions are logged.

Success Criteria:

- All Spring Modulith module boundary tests pass.
- All ArchUnit Clean Architecture tests pass.
- API test coverage exceeds 80%.
- Zero critical or high-severity OWASP vulnerabilities.
- Successful multi-tenant isolation test (Tenant A cannot access Tenant B data).
- Docker Compose stack starts and passes health checks on target VPS within 60 seconds.

---

# 11. Risks and Mitigations

Risk 1:
Description: JVM memory consumption exceeds VPS capacity under multi-tenant load.
Mitigation: Use JVM flags (`-Xmx768m`, `-XX:+UseZGC`) to constrain heap. Monitor with Actuator/Prometheus. Upgrade VPS RAM if needed (incremental cost).

Risk 2:
Description: SERPRO Integra Contador API becomes unavailable or changes its contract.
Mitigation: Implement circuit breaker (Resilience4j) with fallback responses. Cache successful query results in Redis with configurable TTL. Version the API client adapter for contract changes.

Risk 3:
Description: Spring Modulith module boundaries erode over time as team grows.
Mitigation: `ApplicationModules.verify()` runs on every CI build. @CodeGuardian audits module dependencies. ArchUnit rules enforce architectural constraints automatically.

Risk 4:
Description: Single VPS is a single point of failure.
Mitigation: Automated backups (database and Docker volumes). Systemd auto-restart policies. Health check monitoring with alerting. Documented disaster recovery procedure (re-deploy from Docker image + latest backup).

Risk 5:
Description: WhatsApp Business API rate limits or policy changes disrupt service.
Mitigation: Implement rate limiting and queue-based message processing. Monitor API quota usage. Design the WhatsApp adapter as a replaceable port to allow switching providers.

Risk 6:
Description: LGPD non-compliance due to improper handling of taxpayer data.
Mitigation: @ComplianceAgent audits data flows. Tenant data isolation enforced at database level. PII encryption at rest. Audit logs for all data access. Data retention policies implemented per LGPD requirements.

---

# 12. Related ADRs

- [ADR-0053 - Adoção de Java 25, virtual threads e eficiência do backend](./ADR-0053-adocao-java-25-backend.md) — partially supersedes the Java 21 toolchain/runtime and version-dependent concurrency/efficiency scope.
- (Future) ADR-0002 - Multi-Tenant Database Isolation Strategy
- (Future) ADR-0003 - Authentication and Authorization with Keycloak
- (Future) ADR-0004 - WhatsApp Integration Architecture
- [ADR-0005 - Multi-Tenancy Architecture](./ADR-0005-multi-tenancy-architecture.md)
- (Future) ADR-0006 - SERPRO Integra Contador Integration Pattern
- (Future) ADR-0007 - Observability and Monitoring Stack

---

# 13. References

- [Spring Modulith Documentation](https://docs.spring.io/spring-modulith/reference/)
- [Spring Boot 3.x Reference](https://docs.spring.io/spring-boot/docs/current/reference/html/)
- [Java 21 Virtual Threads (JEP 444)](https://openjdk.org/jeps/444)
- [ADR-0053 - Java 25 target and staged virtual-thread adoption](./ADR-0053-adocao-java-25-backend.md)
- ANL-00050 - Java 25 backend impact analysis
- [Clean Architecture - Robert C. Martin](https://blog.cleancoder.com/uncle-bob/2012/08/13/the-clean-architecture.html)
- [Domain-Driven Design - Eric Evans](https://www.domainlanguage.com/ddd/)
- [OpenAPI Specification](https://spec.openapis.org/oas/v3.1.0)
- [AWS ADR Best Practices](https://docs.aws.amazon.com/prescriptive-guidance/latest/architectural-decision-records/best-practices.html)
- [SERPRO Integra Contador](https://www.serpro.gov.br/links-fixos-702702/integra-contador)
- [LGPD - Lei Geral de Protecao de Dados](https://www.planalto.gov.br/ccivil_03/_ato2015-2018/2018/lei/l13709.htm)
- Business Requirements: [Visão de produto](../product/business/product-vision.md)
- Agent Factory Specification: [Catálogo de agentes](../agents/README.md)

---

# 14. Decision Lifecycle

Current State: **Partially Superseded**

This ADR was accepted as the architectural foundation. Since 2026-08-28,
ADR-0053 supersedes only Java 21 as the target toolchain/runtime and the
version-dependent concurrency and runtime-efficiency prescriptions. The original
Java 21 text remains historical and describes the implementation baseline until
the gated Java 25 cutover. Every other foundation decision remains accepted.

---

# 15. Change Log

Version: 1.1
Date: 2026-08-28
Author: Codex (OpenAI), under explicit human request
Changes:
- Marked the ADR as `Partially Superseded` only for the Java 21 target and its
  version-dependent concurrency/runtime-efficiency scope, now governed by
  ADR-0053.
- Preserved the original decision text and distinguished the Java 21 AS-IS
  baseline from the accepted Java 25 target.

Version: 1.0
Date: 2026-03-06
Author: AgentOrchestrator
Changes:
- Initial ADR creation defining technology stack and architecture foundation for the Hub Contabil Inteligente micro-SaaS project.

---

# 16. Repository Structure

All ADRs are stored in:

```
docs/
  adrs/
    ADR-0001-technology-stack-and-architecture.md
```

Future ADRs will follow the naming convention: `ADR-XXXX-short-title.md`

---

# 17. Review Process

1. This ADR was created in "Proposed" status by @AgentOrchestrator.
2. Reviewers (@ArquitetoHexagonal, @DomainExpert, @DevOps-Agent) must validate the technology choices against the business requirements and operational constraints.
3. The startup founders must confirm alignment with budget constraints and business priorities.
4. The original foundation was approved and became `Accepted`.
5. ADR-0053 satisfies the required successor process for the Java version change;
   this ADR is `Partially Superseded` with the exact retained and replaced scopes
   documented above.

---

# 18. Notes

This ADR establishes the foundational technology decisions for the entire Hub Contabil Inteligente project. All subsequent architectural decisions (database strategy, authentication, integrations) should reference this ADR and build upon the principles defined here.

Key principles codified by this ADR:

- Modulith-first: Start simple, extract to microservices only when proven necessary.
- Zero cloud cost: All infrastructure on a self-hosted VPS with Docker Compose.
- Clean Architecture: Business logic must never depend on frameworks or infrastructure.
- DDD-driven: Bounded contexts map to Spring Modulith modules.
- API-first: OpenAPI contracts are the source of truth for all API interfaces.
- Security by design: Multi-tenant isolation, encrypted certificates, and LGPD compliance from day one.
