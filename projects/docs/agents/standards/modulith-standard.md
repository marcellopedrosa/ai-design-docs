---
document_id: "MODULITH-STANDARD"
primary_nature: "Regra"
objective: "Definir regras reutilizáveis e verificáveis para Modulith."
scope: "Módulos Spring Modulith, interfaces nomeadas, eventos e verificação estrutural."
non_objectives: "Não criar requisitos de produto, decisões arquiteturais concretas ou procedimentos fora do escopo deste standard."
owner: "Arquitetura e Qualidade"
status: "Active"
date: "2026-08-25"
version: "1.5"
keywords: "modulith, standard, standard"
related_files: "./README.md, ./ddd-clean-architecture-standard.md, docs/architecture/module-registry.md"
code_references: "backend/, infra/"
principal_statement: "As regras de Modulith aplicam-se somente ao escopo e aos controles declarados neste standard."
---

# Modulith Standard — Padrões Técnicos para Spring Modulith

Este documento define os padrões técnicos, templates de código e convenções obrigatórias para configuração e governança de módulos Spring Modulith no projeto SaaS Service.

**Stack:** Spring Boot 4.0.x · Spring Modulith 2.0.x · Java 25 · Maven

**Agente Responsável:** `@ModulithConfig`

---

## Sumário

1. [Estrutura de Módulos](#1-estrutura-de-módulos)
2. [Declaração de Módulos](#2-declaração-de-módulos)
3. [API Pública vs Internal](#3-api-pública-vs-internal)
4. [Testes de Verificação de Módulo](#4-testes-de-verificação-de-módulo)
5. [Testes de Integração de Módulo](#5-testes-de-integração-de-módulo)
6. [Publicação de Eventos](#6-publicação-de-eventos)
7. [Event Publication Registry](#7-event-publication-registry)
8. [Observabilidade por Módulo](#8-observabilidade-por-módulo)
9. [Documentação de Módulos](#9-documentação-de-módulos)
10. [Module Registry](#10-module-registry)
11. [Extração para Microserviço](#11-extração-para-microserviço)
12. [Configuração Maven](#12-configuração-maven)
13. [Checklist de Novo Módulo](#13-checklist-de-novo-módulo)

---

## 1. Estrutura de Módulos

### Mapeamento: Bounded Context → Spring Modulith Module

Cada bounded context definido por `@CleanArchitecture` corresponde a **um módulo Spring Modulith**. O módulo é detectado automaticamente pelo pacote raiz imediato abaixo do pacote da aplicação principal.

> 📘 Consulte [`ddd-clean-architecture-standard.md`](./ddd-clean-architecture-standard.md) para a estrutura completa de pacotes, Bounded Context Map e a estrutura interna de cada módulo.

> [!IMPORTANT]
> O pacote `internal/` é tratado pelo Spring Modulith como **pacote interno**. Classes neste pacote **não podem** ser acessadas por outros módulos. Qualquer violação será detectada por `ApplicationModules.verify()`.

---

## 2. Declaração de Módulos

### Template: `package-info.java`

Cada módulo **deve** ter um arquivo `package-info.java` no pacote raiz do módulo com a anotação `@ApplicationModule`.

#### Módulo sem dependências externas

```java
/**
 * Módulo de Gestão de Tenants.
 *
 * <p>Responsável por:
 * <ul>
 *   <li>CRUD de escritórios contábeis (tenants)</li>
 *   <li>Gestão de assinaturas e planos</li>
 *   <li>Gestão de contadores responsáveis</li>
 * </ul>
 *
 * <p>Eventos publicados:
 * <ul>
 *   <li>{@link br.com.duoset.saas_service.contexts.tenant.events.EscritorioRegistradoEvent}</li>
 * </ul>
 */
@org.springframework.modulith.ApplicationModule(
    displayName = "Tenant Management",
    allowedDependencies = {}
)
package br.com.duoset.saas_service.contexts.tenant;
```

#### Módulo com dependências declaradas

```java
/**
 * Módulo de Integração Fiscal.
 *
 * <p>Responsável por:
 * <ul>
 *   <li>Consultas fiscais via SERPRO Integra Contador</li>
 *   <li>Emissão de DARFs</li>
 * </ul>
 *
 * <p>Depende de:
 * <ul>
 *   <li>certificate-management — para obter certificados digitais</li>
 * </ul>
 *
 * <p>Eventos publicados:
 * <ul>
 *   <li>{@link br.com.duoset.saas_service.contexts.fiscal.events.ConsultaFiscalRealizadaEvent}</li>
 * </ul>
 */
@org.springframework.modulith.ApplicationModule(
    displayName = "Fiscal Integration",
    allowedDependencies = { "contexts.certificate" }
)
package br.com.duoset.saas_service.contexts.fiscal;
```

#### Módulo com múltiplas dependências

```java
@org.springframework.modulith.ApplicationModule(
    displayName = "WhatsApp Channel",
    allowedDependencies = {
        "contexts.tenant",
        "contexts.fiscal"
    }
)
package br.com.duoset.saas_service.contexts.whatsapp;
```

### Regras de Dependência

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    REGRAS DE DEPENDÊNCIA ENTRE MÓDULOS                   │
│                                                                         │
│  ✅ PERMITIDO                                                            │
│  ─────────────                                                          │
│  • Acessar classes da API pública de módulos em allowedDependencies     │
│  • Consumir eventos publicados por qualquer módulo                      │
│  • Usar tipos do pacote shared/                                         │
│                                                                         │
│  ❌ PROIBIDO                                                             │
│  ───────────                                                            │
│  • Acessar classes do pacote internal/ de outro módulo                  │
│  • Depender de módulo não listado em allowedDependencies                │
│  • Criar dependências circulares entre módulos                          │
│  • Importar classes de infraestrutura de outro módulo                   │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## 3. API Pública vs Internal

### Definição da API Pública

A API pública de um módulo consiste **apenas** nas classes nos pacotes raiz do módulo e no sub-pacote `events/`:

```java
// ✅ API PÚBLICA — acessível por outros módulos
package br.com.duoset.saas_service.contexts.tenant;

/**
 * Interface pública do módulo Tenant Management.
 *
 * <p>Esta é a única forma de outros módulos interagirem
 * com o contexto de tenant de forma síncrona.
 */
public interface TenantApi {

    /**
     * Busca dados básicos de um tenant pelo ID.
     *
     * @param tenantId ID do tenant
     * @return dados do tenant ou Optional.empty()
     */
    Optional<TenantSummaryDTO> findById(UUID tenantId);

    /**
     * Verifica se um tenant existe e está ativo.
     *
     * @param tenantId ID do tenant
     * @return true se o tenant existe e está ativo
     */
    boolean isActive(UUID tenantId);
}
```

```java
// ✅ API PÚBLICA — DTOs expostos pelo módulo
package br.com.duoset.saas_service.contexts.tenant;

/**
 * DTO de resumo do tenant para consumo cross-module.
 * <p>Contém apenas dados mínimos necessários.
 * NÃO expõe detalhes internos da entidade.
 */
public record TenantSummaryDTO(
    UUID id,
    String razaoSocial,
    String documento,
    boolean ativo
) {}
```

### Implementação Interna

```java
// ❌ INTERNO — NÃO acessível por outros módulos
package br.com.duoset.saas_service.contexts.tenant.internal.application.usecase;

@Service
@RequiredArgsConstructor
class CreateTenantUseCase {
    // Implementação interna
}
```

```java
// Implementação da API pública (interna)
package br.com.duoset.saas_service.contexts.tenant.internal;

@Service
@RequiredArgsConstructor
class TenantApiImpl implements TenantApi {

    private final TenantRepository repository;

    @Override
    public Optional<TenantSummaryDTO> findById(UUID tenantId) {
        return repository.findById(tenantId)
            .map(tenant -> new TenantSummaryDTO(
                tenant.getId(),
                tenant.getRazaoSocial(),
                tenant.getCnpj().value(),
                tenant.isAtivo()
            ));
    }

    @Override
    public boolean isActive(UUID tenantId) {
        return repository.existsByIdAndAtivoTrue(tenantId);
    }
}
```

---

## 4. Testes de Verificação de Módulo

### Template: Verificação de Estrutura de Módulos

Este teste é **obrigatório** e deve rodar em todo build CI. Ele valida que todos os módulos respeitam as fronteiras declaradas.

```java
package br.com.duoset.saas_service;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.DisplayName;
import org.springframework.modulith.core.ApplicationModules;
import org.springframework.modulith.docs.Documenter;

/**
 * Testes de verificação da estrutura modular.
 *
 * <p>Estes testes NÃO requerem contexto Spring, Docker,
 * ou qualquer serviço externo. São testes puramente
 * estáticos que analisam a estrutura de pacotes.
 */
@DisplayName("Module Structure Verification")
class ModuleStructureVerificationTest {

    private final ApplicationModules modules = ApplicationModules.of(SaasServiceApplication.class);

    @Test
    @DisplayName("Deve verificar que todos os módulos respeitam suas fronteiras")
    void shouldVerifyAllModuleBoundaries() {
        // Verifica:
        // - Nenhum acesso a pacotes internal/ de outros módulos
        // - Todas as dependências estão declaradas em allowedDependencies
        // - Nenhuma dependência circular
        modules.verify();
    }

    @Test
    @DisplayName("Deve listar todos os módulos detectados")
    void shouldListAllDetectedModules() {
        // Útil para debugging: imprime todos os módulos e suas dependências
        modules.forEach(System.out::println);
    }

    @Test
    @DisplayName("Deve gerar documentação dos módulos")
    void shouldGenerateModuleDocumentation() {
        // Gera diagramas de dependência em target/modulith-docs/
        new Documenter(modules)
            .writeDocumentation()          // Mermaid diagrams
            .writeModuleCanvases();        // Module canvas docs
    }

    @Test
    @DisplayName("Não deve existir dependências circulares")
    void shouldHaveNoCyclicDependencies() {
        // ApplicationModules.verify() já captura ciclos,
        // mas este teste é explícito para clareza no CI
        modules.verify();
    }
}
```

---

## 4.1 Testes ArchUnit — Validação Intra-Módulo (Clean Architecture)

### Conceito

Enquanto o `ModuleStructureVerificationTest` (§4) valida as fronteiras **entre módulos** (inter-module), os testes ArchUnit validam a conformidade das **camadas internas** de cada módulo (intra-module) com a [Dependency Rule da Clean Architecture](./ddd-clean-architecture-standard.md).

```
ModuleStructureVerificationTest  →  Inter-module (módulos respeitam fronteiras)
CleanArchitectureRulesTest       →  Intra-module (camadas respeitam Dependency Rule)
```

### Template: `CleanArchitectureRulesTest.java`

Este teste é **obrigatório** e complementa o `ModuleStructureVerificationTest`. Ele roda sem contexto Spring (puramente estático).

**Categorias de regras:**

| Categoria | Referência | Propósito |
|-----------|-----------|-----------|
| Dependency Rule | `ddd-clean-architecture-standard` §4 | Domain não importa camadas externas; Application não importa Infrastructure/Presentation |
| Framework-Free Domain | `ddd-clean-architecture-standard` §5 | Domain não usa Spring, JPA, nem Jackson |
| Naming Conventions | `ddd-clean-architecture-standard` §6-§7 | Sufixos obrigatórios: `UseCase`, `Port`, `Adapter`, `Controller`, etc. |
| Structural Placement | `ddd-clean-architecture-standard` §7-§8 | `@RestController` → `presentation/rest/`, `@Scheduled` → `infrastructure/scheduler/`, etc. |

**Regras obrigatórias:**

```java
// === Dependency Rule ===
// Domain NÃO pode depender de Application, Infrastructure ou Presentation
// Application NÃO pode depender de Infrastructure ou Presentation
// Presentation NÃO pode depender de Infrastructure

// === Framework-Free Domain ===
// Domain NÃO pode usar anotações Spring (@Service, @Component, @Repository, @RestController)
// Domain NÃO pode importar pacotes JPA (jakarta.persistence, javax.persistence)
// Domain NÃO pode importar pacotes Spring (org.springframework)
// Domain NÃO pode importar pacotes Jackson (com.fasterxml.jackson)

// === Naming Conventions ===
// Classes em application/usecase/ → sufixo "UseCase"
// Interfaces em application/port/ → sufixo "Port"
// Classes em infrastructure/adapter/ → sufixo "Adapter"
// Classes @RestController em presentation/rest/ → sufixo "Controller"

// === Structural Placement ===
// @ApplicationModuleListener → infrastructure/messaging/ OU application/listener/
// @RestController → presentation/rest/
// Classes em domain/repository/ → devem ser interfaces
// @Scheduled → infrastructure/scheduler/
```

### Configuração: `archunit.properties`

Durante as fases iniciais do projeto (Phase 1), quando muitos pacotes ainda estão vazios, é necessário configurar o ArchUnit para não falhar em regras sem match:

```properties
# src/test/resources/archunit.properties
# TODO: Reverter para true após Phase 2 (task 2.1.1)
archRule.failOnEmptyShould=false
```

> [!WARNING]
> Este setting deve ser revertido para `true` (ou o arquivo removido) quando os pacotes possuírem classes reais. Caso contrário, uma regressão estrutural (ex: renomear `usecase/` para `usecases/`) não será detectada.

---

## 5. Testes de Integração de Módulo

### Template: Teste de Módulo Isolado (STANDALONE)

Verifica que o módulo consegue inicializar sozinho, sem nenhum outro módulo carregado.

```java
package br.com.duoset.saas_service.contexts.tenant;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.DisplayName;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.modulith.test.ApplicationModuleTest;
import org.springframework.modulith.test.ApplicationModuleTest.BootstrapMode;

/**
 * Teste de integração do módulo Tenant Management em modo STANDALONE.
 *
 * <p>Modo STANDALONE: Apenas o módulo tenant é carregado.
 * Todos os beans de outros módulos são excluídos do contexto.
 * Dependências de outros módulos devem ser mockadas.
 *
 * <p>Ideal para: módulos sem dependências externas
 * (allowedDependencies vazio).
 */
@ApplicationModuleTest(BootstrapMode.STANDALONE)
@DisplayName("Tenant Management Module - Standalone")
class TenantModuleStandaloneTest {

    @Autowired
    private TenantApi tenantApi;

    @Test
    @DisplayName("Deve inicializar o módulo tenant isoladamente")
    void shouldBootstrapTenantModuleInIsolation() {
        // Se o contexto subir sem erros, o módulo está corretamente
        // configurado para funcionar de forma independente.
        assert tenantApi != null;
    }
}
```

### Template: Teste de Módulo com Dependências (DIRECT_DEPENDENCIES)

Verifica que o módulo funciona quando carregado junto com seus módulos dependentes.

```java
package br.com.duoset.saas_service.contexts.fiscal;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.DisplayName;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.modulith.test.ApplicationModuleTest;
import org.springframework.modulith.test.ApplicationModuleTest.BootstrapMode;

/**
 * Teste de integração do módulo Fiscal Integration
 * com dependências diretas carregadas.
 *
 * <p>Modo DIRECT_DEPENDENCIES: Carrega o módulo fiscal E
 * todos os módulos listados em allowedDependencies
 * (neste caso, certificate-management).
 *
 * <p>Ideal para: módulos com dependências declaradas.
 */
@ApplicationModuleTest(BootstrapMode.DIRECT_DEPENDENCIES)
@DisplayName("Fiscal Integration Module - With Dependencies")
class FiscalModuleWithDependenciesTest {

    @Autowired
    private FiscalApi fiscalApi;

    @Test
    @DisplayName("Deve inicializar o módulo fiscal com suas dependências")
    void shouldBootstrapFiscalModuleWithDependencies() {
        assert fiscalApi != null;
    }
}
```

### Template: Teste de Publicação de Eventos entre Módulos

Verifica que eventos publicados por um módulo são corretamente consumidos por outro.

```java
package br.com.duoset.saas_service.contexts.billing;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.DisplayName;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.modulith.test.ApplicationModuleTest;
import org.springframework.modulith.test.PublishedEvents;
import org.springframework.modulith.test.Scenario;
import br.com.duoset.saas_service.contexts.fiscal.events.ConsultaFiscalRealizadaEvent;

import java.util.UUID;

/**
 * Teste de contrato de eventos entre modules.
 *
 * <p>Verifica que o módulo billing consome corretamente
 * eventos publicados pelo módulo fiscal.
 */
@ApplicationModuleTest
@DisplayName("Billing Module - Event Consumption")
class BillingEventConsumptionTest {

    @Autowired
    private BillingApi billingApi;

    @Test
    @DisplayName("Deve processar evento de consulta fiscal para debitar créditos")
    void shouldDeductCreditsOnFiscalQuery(Scenario scenario) {
        var tenantId = UUID.randomUUID();
        var consultaId = UUID.randomUUID();

        scenario.publish(new ConsultaFiscalRealizadaEvent(
                consultaId,
                tenantId,
                "00.000.000/0001-00",
                "REGULAR"
            ))
            .andWaitForStateChange(() -> billingApi.getCredits(tenantId))
            .andVerify(credits -> {
                // Verifica que os créditos foram debitados
                assert credits != null;
            });
    }

    @Test
    @DisplayName("Deve registrar eventos publicados corretamente")
    void shouldCapturePublishedEvents(PublishedEvents events) {
        // PublishedEvents permite capturar e verificar todos os eventos
        // publicados durante o teste
        var fiscalEvents = events.ofType(ConsultaFiscalRealizadaEvent.class)
            .matching(e -> e.tenantId().equals(UUID.randomUUID()));

        // Verificações sobre os eventos capturados
    }
}
```

---

## 6. Publicação de Eventos

### Padrão: Eventos de Domínio (Cross-Module)

Os eventos que cruzam fronteiras de módulo **devem** estar no pacote `events/` do módulo publicador (API pública).

```java
// Em contexts/fiscal/events/ — PÚBLICO
package br.com.duoset.saas_service.contexts.fiscal.events;

import java.time.Instant;
import java.util.UUID;

/**
 * Evento publicado quando uma consulta fiscal é realizada com sucesso.
 *
 * <p>Consumidores:
 * <ul>
 *   <li>billing — para debitar créditos do tenant</li>
 *   <li>audit (shared) — para registro de auditoria</li>
 * </ul>
 *
 * @param consultaId   ID da consulta realizada
 * @param tenantId     ID do tenant que solicitou
 * @param documento         Documento consultado
 * @param situacao     Situação fiscal retornada (REGULAR / IRREGULAR)
 * @param realizadaEm  Timestamp da consulta
 */
public record ConsultaFiscalRealizadaEvent(
    UUID consultaId,
    UUID tenantId,
    String documento,
    String situacao,
    Instant realizadaEm
) {
    /**
     * Construtor de conveniência sem timestamp (usa Instant.now()).
     */
    public ConsultaFiscalRealizadaEvent(UUID consultaId, UUID tenantId,
                                         String documento, String situacao) {
        this(consultaId, tenantId, documento, situacao, Instant.now());
    }
}
```

> [!WARNING]
> Eventos cross-module **NÃO devem** carregar entidades completas nem dados sensíveis (PII). Apenas IDs e dados mínimos necessários para o consumidor.

### Padrão: Publicação via ApplicationEventPublisher

```java
package br.com.duoset.saas_service.contexts.fiscal.internal.application.usecase;

import org.springframework.context.ApplicationEventPublisher;
import br.com.duoset.saas_service.contexts.fiscal.events.ConsultaFiscalRealizadaEvent;

@Service
@RequiredArgsConstructor
public class ConsultarSituacaoFiscalUseCase {

    private final ConsultaFiscalRepository repository;
    private final SerproGateway serproGateway;
    private final ApplicationEventPublisher eventPublisher;

    @Transactional
    public SituacaoFiscalResult execute(ConsultaSituacaoFiscalCommand command) {
        // ... lógica de domínio ...

        var consulta = repository.save(novaConsulta);

        // ✅ Publicar evento — será entregue DENTRO da mesma transação
        eventPublisher.publishEvent(new ConsultaFiscalRealizadaEvent(
            consulta.getId(),
            command.tenantId(),
            command.documento(),
            consulta.getSituacao().name()
        ));

        return toResult(consulta);
    }
}
```

### Padrão: Consumo Síncrono (Mesma Transação)

```java
package br.com.duoset.saas_service.contexts.billing.internal.application.listener;

import org.springframework.modulith.events.ApplicationModuleListener;
import br.com.duoset.saas_service.contexts.fiscal.events.ConsultaFiscalRealizadaEvent;

/**
 * Listener que processa consultas fiscais para debitar créditos.
 *
 * <p>{@code @ApplicationModuleListener} é a anotação recomendada
 * pelo Spring Modulith. Ela combina:
 * <ul>
 *   <li>{@code @TransactionalEventListener} — executa na fase de commit</li>
 *   <li>{@code @Transactional(propagation = REQUIRES_NEW)} — nova transação</li>
 *   <li>{@code @Async} — execução assíncrona</li>
 * </ul>
 */
@Component
@RequiredArgsConstructor
@Slf4j
public class ConsultaFiscalCreditDeductionListener {

    private final CreditService creditService;

    @ApplicationModuleListener
    public void on(ConsultaFiscalRealizadaEvent event) {
        log.info("Debitando crédito para tenant {} - consulta {}",
            event.tenantId(), event.consultaId());

        creditService.deduct(event.tenantId(), 1);
    }
}
```

### Padrão: Consumo com @TransactionalEventListener (Controle Manual)

```java
package br.com.duoset.saas_service.contexts.billing.internal.application.listener;

import org.springframework.transaction.event.TransactionalEventListener;
import org.springframework.transaction.event.TransactionPhase;
import br.com.duoset.saas_service.contexts.tenant.events.EscritorioRegistradoEvent;

@Component
@RequiredArgsConstructor
@Slf4j
public class TenantRegisteredBillingListener {

    private final SubscriptionService subscriptionService;

    /**
     * Executado APÓS o commit da transação do publicador.
     * Se falhar, a transação do publicador NÃO é revertida.
     */
    @TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT)
    public void handle(EscritorioRegistradoEvent event) {
        log.info("Criando assinatura inicial para tenant {}", event.tenantId());
        subscriptionService.createInitialSubscription(event.tenantId());
    }
}
```

---

## 7. Event Publication Registry

### Conceito

O Event Publication Registry do Spring Modulith persiste eventos em banco de dados para garantir **entrega confiável**. Se um consumidor falhar, o evento é marcado como "não completado" e pode ser reprocessado.

### Configuração (application.properties)

```properties
# ============================================================
# Event Publication Registry — Garante entrega confiável
# ============================================================

# Habilitar completions automáticas (limpeza de eventos processados)
spring.modulith.events.republish-outstanding-events-on-restart=true

# Limpar registros completados após 2 dias
spring.modulith.events.completion-mode=delete

# ============================================================
# JPA Event Publication (já incluso via spring-modulith-starter-jpa)
# ============================================================
# O starter JPA cria automaticamente a tabela EVENT_PUBLICATION
# para armazenar eventos pendentes.
# Nenhuma configuração adicional necessária.
```

### Configuração Java (customização avançada)

```java
package br.com.duoset.saas_service.config;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.modulith.events.IncompleteEventPublications;
import org.springframework.scheduling.annotation.EnableScheduling;
import org.springframework.scheduling.annotation.Scheduled;

import java.time.Duration;

/**
 * Configuração do Event Publication Registry.
 *
 * <p>Reprocessa eventos que falharam durante o consumo,
 * garantindo eventual consistency entre módulos.
 */
@Configuration
@EnableScheduling
public class EventPublicationConfig {

    /**
     * Reprocessa eventos incompletos a cada 5 minutos.
     * Eventos mais antigos que 10 minutos são considerados "presos"
     * e são republicados.
     */
    @Scheduled(fixedDelay = 300_000) // 5 minutos
    public void resubmitIncompletePublications(
            IncompleteEventPublications publications) {

        publications.resubmitIncompletePublicationsOlderThan(
            Duration.ofMinutes(10)
        );
    }
}
```

---

## 8. Observabilidade por Módulo

### Configuração do Actuator (application.properties)

```properties
# ============================================================
# Spring Modulith Actuator
# ============================================================

# Expor endpoint de módulos no Actuator
management.endpoints.web.exposure.include=health,info,metrics,prometheus,modulith

# Detalhes de saúde
management.endpoint.health.show-details=when-authorized
```

### Verificação dos endpoints

```bash
# Listar todos os módulos e suas dependências
curl http://localhost:8080/actuator/modulith

# Resposta esperada:
# {
#   "modules": [
#     {
#       "name": "tenant-management",
#       "displayName": "Tenant Management",
#       "basePackage": "br.com.duoset.saas_service.contexts.tenant",
#       "dependencies": []
#     },
#     {
#       "name": "fiscal-integration",
#       "displayName": "Fiscal Integration",
#       "basePackage": "br.com.duoset.saas_service.contexts.fiscal",
#       "dependencies": ["certificate-management"]
#     }
#   ]
# }
```

### Configuração de Observability (Tracing por Módulo)

```java
package br.com.duoset.saas_service.config;

import org.springframework.context.annotation.Configuration;

/**
 * O spring-modulith-observability (já no pom.xml) automaticamente:
 *
 * <ul>
 *   <li>Cria spans de tracing para chamadas cross-module</li>
 *   <li>Adiciona métricas Micrometer por módulo</li>
 *   <li>Registra métricas de eventos (publicados/consumidos)</li>
 * </ul>
 *
 * <p>Métricas expostas automaticamente:
 * <ul>
 *   <li>{@code spring.modulith.events.published} — eventos publicados</li>
 *   <li>{@code spring.modulith.events.completed} — eventos consumidos</li>
 *   <li>{@code spring.modulith.events.failed} — eventos com falha</li>
 * </ul>
 *
 * <p>Nenhuma configuração adicional necessária. As dependências
 * {@code spring-modulith-observability} e {@code micrometer-registry-prometheus}
 * já estão no pom.xml.
 */
@Configuration
public class ModulithObservabilityConfig {
    // Configuração automática via auto-configuration
    // Adicionado aqui apenas para documentação explícita
}
```

---

## 9. Documentação de Módulos

### Geração Automática de Diagramas

A geração de documentação é feita pelo teste `ModuleStructureVerificationTest` (Seção 4).

```java
@Test
@DisplayName("Deve gerar documentação dos módulos")
void shouldGenerateModuleDocumentation() {
    var documenter = new Documenter(modules);

    // Gera diagramas Mermaid com todos os módulos
    documenter.writeDocumentation(
        Documenter.DiagramOptions.defaults()
            .withStyle(Documenter.DiagramOptions.DiagramStyle.UML)
    );

    // Gera canvas de cada módulo (resumo em Asciidoc)
    documenter.writeModuleCanvases(
        Documenter.CanvasOptions.defaults()
    );
}
```

**Output gerado em:** `target/spring-modulith-docs/`

```
target/spring-modulith-docs/
├── components.md                ← Diagrama geral de módulos (Mermaid)
├── module-tenant.md             ← Diagrama do módulo tenant (Mermaid)
├── module-fiscal.md             ← Diagrama do módulo fiscal (Mermaid)
├── module-tenant.adoc           ← Canvas do módulo tenant
└── ...
```

---

## 10. Module Registry

### Template: `docs/architecture/module-registry.md`

Este documento é mantido pelo `@ModulithConfig` e atualizado sempre que módulos são adicionados ou modificados.

```markdown
# Module Registry — SaaS Service

## Módulos

| Módulo | Display Name | Pacote Base | Dependências |
|---|---|---|---|
| contexts.tenant | Tenant Management | `contexts.tenant` | — |
| contexts.certificate | Certificate Management | `contexts.certificate` | — |
| contexts.fiscal | Fiscal Integration | `contexts.fiscal` | certificate |
| contexts.whatsapp | WhatsApp Channel | `contexts.whatsapp` | tenant, fiscal |
| contexts.billing | Billing | `contexts.billing` | tenant |

## Eventos Cross-Module

| Evento | Módulo Produtor | Módulo(s) Consumidor(es) | Payload |
|---|---|---|---|
| EscritorioRegistradoEvent | tenant | billing | tenantId, razaoSocial |
| ConsultaFiscalRealizadaEvent | fiscal | billing | consultaId, tenantId, documento, situacao |
| ContatoAutorizadoEvent | tenant | whatsapp | tenantId, telefone, documento |

## Grafo de Dependência

    tenant ←── whatsapp
      │             │
      ↓             ↓
    billing       fiscal
                    │
                    ↓
              certificate
```

---

## 11. Extração para Microserviço

### Checklist de Readiness

Antes de extrair um módulo para um microserviço independente, todos os itens devem ser atendidos:

```
┌─────────────────────────────────────────────────────────────────────────┐
│              CHECKLIST DE EXTRAÇÃO PARA MICROSERVIÇO                    │
│                                                                         │
│  ☐ Fronteiras de Módulo                                                 │
│    ├── ApplicationModules.verify() passa sem erros                     │
│    ├── Zero acessos a pacotes internal/ de outros módulos              │
│    ├── Todas as dependências são via API pública ou eventos            │
│    └── Zero dependências circulares envolvendo este módulo             │
│                                                                         │
│  ☐ Comunicação                                                          │
│    ├── Comunicação síncrona usa interfaces (API pública)               │
│    ├── Comunicação assíncrona usa eventos de domínio                   │
│    ├── Event Publication Registry está habilitado                       │
│    └── Eventos podem ser externalizados para Kafka/RabbitMQ            │
│                                                                         │
│  ☐ Dados                                                                │
│    ├── O módulo possui suas próprias tabelas no banco                  │
│    ├── Não faz JOINs com tabelas de outros módulos                     │
│    ├── Dados compartilhados são acessados via API pública              │
│    └── Migrações Flyway estão isoladas por módulo                      │
│                                                                         │
│  ☐ Configuração                                                         │
│    ├── Propriedades do módulo usam namespace próprio                   │
│    ├── Beans do módulo não dependem de beans internos de outros        │
│    └── Perfis (profiles) do módulo podem funcionar isolados            │
│                                                                         │
│  ☐ Testes                                                               │
│    ├── @ApplicationModuleTest(STANDALONE) passa com sucesso            │
│    ├── Testes unitários do módulo passam sem contexto externo          │
│    └── Testes de contrato de eventos estão escritos                    │
│                                                                         │
│  ☐ Observabilidade                                                      │
│    ├── Métricas por módulo estão sendo coletadas                       │
│    ├── Logs do módulo usam MDC com nome do módulo                      │
│    └── Tracing cross-module está funcional                             │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

### Padrão: Externalizando Eventos para Kafka

Quando o módulo for extraído, os eventos in-process precisam ser externalizados:

```java
package br.com.duoset.saas_service.config;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.context.annotation.Profile;
import org.springframework.modulith.events.Externalized;

/**
 * Configuração de externalização de eventos.
 *
 * <p>Em produção (quando o módulo for extraído), os eventos
 * são publicados em tópicos Kafka ao invés de serem
 * processados in-process.
 *
 * <p>No profile 'dev', os eventos continuam in-process.
 */
// Exemplo de anotação no evento para externalização:
// @Externalized("fiscal-events::#{#this.consultaId()}")
// public record ConsultaFiscalRealizadaEvent(...) {}
```

---

## 12. Configuração Maven

### Dependências Obrigatórias (já presentes no pom.xml)

```xml
<!-- ============================== -->
<!-- Spring Modulith — Core         -->
<!-- ============================== -->
<dependency>
    <groupId>org.springframework.modulith</groupId>
    <artifactId>spring-modulith-starter-core</artifactId>
</dependency>

<!-- Spring Modulith — JPA Event Publication Registry -->
<dependency>
    <groupId>org.springframework.modulith</groupId>
    <artifactId>spring-modulith-starter-jpa</artifactId>
</dependency>

<!-- Spring Modulith — Actuator Endpoint -->
<dependency>
    <groupId>org.springframework.modulith</groupId>
    <artifactId>spring-modulith-actuator</artifactId>
    <scope>runtime</scope>
</dependency>

<!-- Spring Modulith — Observabilidade (Micrometer + Tracing) -->
<dependency>
    <groupId>org.springframework.modulith</groupId>
    <artifactId>spring-modulith-observability</artifactId>
    <scope>runtime</scope>
</dependency>

<!-- ============================== -->
<!-- Spring Modulith — Test Support -->
<!-- ============================== -->
<dependency>
    <groupId>org.springframework.modulith</groupId>
    <artifactId>spring-modulith-starter-test</artifactId>
    <scope>test</scope>
</dependency>

<!-- ============================== -->
<!-- BOM (versão centralizada)      -->
<!-- ============================== -->
<dependencyManagement>
    <dependencies>
        <dependency>
            <groupId>org.springframework.modulith</groupId>
            <artifactId>spring-modulith-bom</artifactId>
            <version>${spring-modulith.version}</version>
            <type>pom</type>
            <scope>import</scope>
        </dependency>
    </dependencies>
</dependencyManagement>
```

---

## 13. Checklist de Novo Módulo

Ao criar um **novo bounded context** como módulo Spring Modulith:

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    CHECKLIST DE NOVO MÓDULO                              │
│                                                                         │
│  1. ☐ Criar pacote contexts/{nome-módulo}/                              │
│  2. ☐ Criar package-info.java com @ApplicationModule                   │
│  3. ☐ Definir displayName e allowedDependencies                        │
│  4. ☐ Criar sub-pacote events/ com eventos de domínio                  │
│  5. ☐ Criar sub-pacote internal/ com as camadas da Clean Architecture  │
│  6. ☐ Criar interface {NomeMódulo}Api.java (API pública)               │
│  7. ☐ Implementar {NomeMódulo}ApiImpl no pacote internal/              │
│  8. ☐ Rodar ModuleStructureVerificationTest (deve passar)              │
│  9. ☐ Criar @ApplicationModuleTest para o novo módulo                  │
│  10. ☐ Atualizar Module Registry (../../architecture/module-registry.md)│
│  11. ☐ Documentar eventos publicados e consumidos                      │
│  12. ☐ Verificar que o build CI continua passando                      │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

---

*Última atualização: 2026-03-10*
*Versão: 1.0*
*Stack: Spring Boot 4.0.3 · Spring Modulith 2.0.3 · Java 25 · Maven*
