---
document_id: "BACKEND-TESTING-STANDARD"
primary_nature: "Regra"
objective: "Definir regras reutilizáveis e verificáveis para Backend Testing."
scope: "Estratégia, escopo, isolamento e gates de testes automatizados do backend."
non_objectives: "Não criar requisitos de produto, decisões arquiteturais concretas ou procedimentos fora do escopo deste standard."
owner: "Arquitetura e Qualidade"
status: "Active"
date: "2026-08-25"
version: "1.11"
last_reviewed: "2026-09-12"
keywords: "backend, testing, standard, standard"
related_files: "./README.md, ./software-quality-standard.md"
code_references: "backend/src/test/java/br/com/duoset/saas_service/architecture/, backend/pom.xml, backend/mvnw, infra/scripts/validate-quality-gates.sh"
principal_statement: "As regras de Backend Testing aplicam-se somente ao escopo e aos controles declarados neste standard."
---

# Backend Testing Standard — @TestAutomator / @ImplementerCore / @AdapterDev

> **Mandatory rules** for backend testing. This standard defines the testing pyramid (unit, integration, database), mocking strategy with Mockito, Testcontainers for database tests, ArchUnit for structural/architectural verification, naming conventions, fixture patterns, and quality gates.

> **Prerequisite:** Follow Clean Architecture test boundaries defined in the agent specifications — domain tests import only domain classes, use case tests mock only ports.

---

## 1. Dependencies

```xml
<!-- pom.xml — Test dependencies -->
<dependencies>
  <!-- JUnit 5 -->
  <dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-test</artifactId>
    <scope>test</scope>
  </dependency>

  <!-- Testcontainers -->
  <dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-testcontainers</artifactId>
    <scope>test</scope>
  </dependency>
  <dependency>
    <groupId>org.testcontainers</groupId>
    <artifactId>postgresql</artifactId>
    <scope>test</scope>
  </dependency>
  <dependency>
    <groupId>org.testcontainers</groupId>
    <artifactId>junit-jupiter</artifactId>
    <scope>test</scope>
  </dependency>

  <!-- ArchUnit — Architectural verification -->
  <dependency>
    <groupId>com.tngtech.archunit</groupId>
    <artifactId>archunit-junit5</artifactId>
    <version>1.3.0</version>
    <scope>test</scope>
  </dependency>

  <!-- WireMock — HTTP mocking for external APIs -->
  <dependency>
    <groupId>org.wiremock</groupId>
    <artifactId>wiremock-standalone</artifactId>
    <version>3.9.1</version>
    <scope>test</scope>
  </dependency>
</dependencies>
```

### Included via spring-boot-starter-test

| Library | Purpose |
|---|---|
| JUnit 5 (Jupiter) | Test framework |
| Mockito | Mock/stub creation |
| AssertJ | Fluent assertions |
| Spring Test | `@SpringBootTest`, `@WebMvcTest`, `@DataJpaTest` |
| JSONPath / JsonAssert | JSON response validation |

---

## 2. Test Directory Structure

```
src/test/java/com/saas/
├── architecture/                    # ArchUnit structural tests
│   ├── CleanArchitectureTest.java
│   ├── NamingConventionTest.java
│   └── PackageStructureTest.java
├── fiscal/                          # Module-level tests (mirror src/main)
│   ├── domain/
│   │   ├── CnpjTest.java           # Value Object unit test
│   │   ├── ConsultaFiscalTest.java  # Entity unit test
│   │   └── DebitoFiscalTest.java
│   ├── application/
│   │   └── ConsultarSituacaoFiscalUseCaseTest.java  # Use Case unit test
│   ├── infrastructure/
│   │   ├── persistence/
│   │   │   └── FiscalRepositoryIntegrationTest.java # DB integration test
│   │   ├── web/
│   │   │   └── FiscalControllerTest.java            # Controller test
│   │   └── adapter/
│   │       └── SerproGatewayAdapterTest.java        # WireMock test
│   └── fixtures/
│       ├── ConsultaFiscalTestBuilder.java
│       ├── CnpjTestBuilder.java
│       └── DebitoFiscalTestBuilder.java
├── billing/                         # Another module
│   ├── domain/ ...
│   ├── application/ ...
│   └── ...
├── shared/                          # Shared test infrastructure
│   ├── IntegrationTestBase.java     # Testcontainers base class
│   └── TestConstants.java           # Shared test constants
└── resources/
    ├── application-test.yml         # Test Spring profile
    └── wiremock/                    # WireMock mapping files
        └── serpro-api/
            ├── situacao-regular.json
            └── situacao-irregular.json
```

### Rules

1. Test packages **mirror** the source package structure: `com.saas.fiscal.domain` → `com.saas.fiscal.domain`.
2. `architecture/` package contains ArchUnit tests — these enforce structural rules.
3. `fixtures/` per module for Builder pattern test data.
4. `shared/` for cross-module test infrastructure (base classes, constants).
5. Test class name = `{SourceClass}Test` (unit) or `{SourceClass}IntegrationTest` (integration).

---

## 3. Test Profile

```yaml
# src/test/resources/application-test.yml
spring:
  profiles:
    active: test

  datasource:
    # Overridden by Testcontainers in integration tests
    url: jdbc:h2:mem:testdb
    driver-class-name: org.h2.Driver

  jpa:
    hibernate:
      ddl-auto: none
    show-sql: true

  flyway:
    enabled: true
    locations: classpath:db/migration

  cache:
    type: none  # Disable cache in tests unless explicitly testing cache

logging:
  level:
    com.saas: DEBUG
    org.springframework.test: WARN
```

---

## 4. Unit Tests — Domain Layer

### Value Object Tests

```java
// src/test/java/com/saas/fiscal/domain/CnpjTest.java
package com.saas.fiscal.domain;

import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Nested;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;

import static org.assertj.core.api.Assertions.*;

@DisplayName("Cnpj Value Object")
class CnpjTest {

    @Nested
    @DisplayName("Creation")
    class Creation {

        @Test
        @DisplayName("should create valid Documento from 14 digits")
        void should_create_valid_documento_from_14_digits() {
            Cnpj documento = Cnpj.of("12345678000190");
            assertThat(documento.value()).isEqualTo("12345678000190");
        }

        @Test
        @DisplayName("should strip formatting characters")
        void should_strip_formatting_characters() {
            Cnpj documento = Cnpj.of("12.345.678/0001-90");
            assertThat(documento.value()).isEqualTo("12345678000190");
        }

        @ParameterizedTest
        @ValueSource(strings = {"", "123", "1234567890123456", "abcdefghijklmn"})
        @DisplayName("should reject invalid Documento values")
        void should_reject_invalid_documento(String invalid) {
            assertThatThrownBy(() -> Cnpj.of(invalid))
                .isInstanceOf(DomainValidationException.class)
                .hasMessageContaining("Documento");
        }

        @Test
        @DisplayName("should reject null Documento")
        void should_reject_null() {
            assertThatThrownBy(() -> Cnpj.of(null))
                .isInstanceOf(NullPointerException.class);
        }
    }

    @Nested
    @DisplayName("Equality")
    class Equality {

        @Test
        @DisplayName("should be equal when same value")
        void should_equal_when_same_value() {
            assertThat(Cnpj.of("12345678000190"))
                .isEqualTo(Cnpj.of("12345678000190"));
        }

        @Test
        @DisplayName("should not be equal when different value")
        void should_not_equal_when_different_value() {
            assertThat(Cnpj.of("12345678000190"))
                .isNotEqualTo(Cnpj.of("98765432000110"));
        }
    }

    @Test
    @DisplayName("should format with mask")
    void should_format_with_mask() {
        assertThat(Cnpj.of("12345678000190").formatted())
            .isEqualTo("12.345.678/0001-90");
    }
}
```

### Entity Tests

```java
// src/test/java/com/saas/fiscal/domain/ConsultaFiscalTest.java
package com.saas.fiscal.domain;

import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Nested;
import org.junit.jupiter.api.Test;

import java.util.List;

import static com.saas.fiscal.fixtures.ConsultaFiscalTestBuilder.aConsultaFiscal;
import static com.saas.fiscal.fixtures.DebitoFiscalTestBuilder.aDebito;
import static org.assertj.core.api.Assertions.*;

@DisplayName("ConsultaFiscal Entity")
class ConsultaFiscalTest {

    @Nested
    @DisplayName("Creation")
    class Creation {

        @Test
        @DisplayName("should create with status PENDENTE")
        void should_create_with_status_pendente() {
            ConsultaFiscal consulta = aConsultaFiscal().build();
            assertThat(consulta.getStatus()).isEqualTo(StatusFiscal.PENDENTE);
        }

        @Test
        @DisplayName("should reject null Documento")
        void should_reject_null_documento() {
            assertThatThrownBy(() -> aConsultaFiscal().withCnpj(null).build())
                .isInstanceOf(NullPointerException.class);
        }
    }

    @Nested
    @DisplayName("Status Transitions")
    class StatusTransitions {

        @Test
        @DisplayName("should transition to REGULAR when no debitos")
        void should_transition_to_regular_when_no_debitos() {
            ConsultaFiscal consulta = aConsultaFiscal().withStatus(StatusFiscal.PENDENTE).build();
            consulta.registrarResultado(List.of());
            assertThat(consulta.getStatus()).isEqualTo(StatusFiscal.REGULAR);
        }

        @Test
        @DisplayName("should transition to IRREGULAR when debitos found")
        void should_transition_to_irregular_when_debitos_found() {
            ConsultaFiscal consulta = aConsultaFiscal().withStatus(StatusFiscal.PENDENTE).build();
            consulta.registrarResultado(List.of(aDebito().build()));
            assertThat(consulta.getStatus()).isEqualTo(StatusFiscal.IRREGULAR);
        }
    }

    @Nested
    @DisplayName("Domain Events")
    class DomainEvents {

        @Test
        @DisplayName("should emit ConsultaFiscalRealizada on result registration")
        void should_emit_event_on_result() {
            ConsultaFiscal consulta = aConsultaFiscal().build();
            consulta.registrarResultado(List.of());
            assertThat(consulta.getDomainEvents())
                .hasSize(1)
                .first()
                .isInstanceOf(ConsultaFiscalRealizada.class);
        }
    }
}
```

### Rules

1. **No mocks** in domain unit tests. Domain is pure logic — test with real objects.
2. Use `@Nested` to group related tests (Creation, Equality, Transitions, Events).
3. Use `@DisplayName` on every test class and method — readable test reports.
4. Use AssertJ (`assertThat`) for all assertions. Never JUnit `assertEquals`.
5. Use `@ParameterizedTest` + `@ValueSource` for boundary testing.
6. Use fixture builders (`aConsultaFiscal().build()`) — never inline construction.

---

## 5. Unit Tests — Use Case Layer

```java
// src/test/java/com/saas/fiscal/application/ConsultarSituacaoFiscalUseCaseTest.java
package com.saas.fiscal.application;

import com.saas.fiscal.application.port.out.FiscalRepositoryPort;
import com.saas.fiscal.application.port.out.SerproGatewayPort;
import com.saas.fiscal.application.port.out.EventPublisherPort;
import com.saas.fiscal.domain.*;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Nested;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import static com.saas.fiscal.fixtures.ConsultaFiscalTestBuilder.aConsultaFiscal;
import static org.assertj.core.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.BDDMockito.*;

@ExtendWith(MockitoExtension.class)
@DisplayName("ConsultarSituacaoFiscal Use Case")
class ConsultarSituacaoFiscalUseCaseTest {

    @Mock private FiscalRepositoryPort repository;
    @Mock private SerproGatewayPort serproGateway;
    @Mock private EventPublisherPort eventPublisher;
    @InjectMocks private ConsultarSituacaoFiscalUseCase useCase;

    @Nested
    @DisplayName("Happy Path")
    class HappyPath {

        @Test
        @DisplayName("should query Serpro, persist result, and publish event")
        void should_query_serpro_and_persist() {
            // given
            given(serproGateway.consultarSituacao(any())).willReturn(situacaoRegular());

            // when
            ConsultaResult result = useCase.execute(new ConsultaCommand("12345678000190"));

            // then
            assertThat(result.getStatus()).isEqualTo("REGULAR");
            then(repository).should().save(any(ConsultaFiscal.class));
            then(eventPublisher).should().publish(any(ConsultaFiscalRealizada.class));
        }
    }

    @Nested
    @DisplayName("Error Handling")
    class ErrorHandling {

        @Test
        @DisplayName("should throw when Documento is invalid")
        void should_throw_when_documento_invalid() {
            assertThatThrownBy(() -> useCase.execute(new ConsultaCommand("invalid")))
                .isInstanceOf(DomainValidationException.class);

            then(serproGateway).shouldHaveNoInteractions();
            then(repository).shouldHaveNoInteractions();
        }

        @Test
        @DisplayName("should throw when Serpro is unavailable")
        void should_throw_when_serpro_unavailable() {
            given(serproGateway.consultarSituacao(any()))
                .willThrow(new ExternalServiceException("Serpro unavailable"));

            assertThatThrownBy(() -> useCase.execute(new ConsultaCommand("12345678000190")))
                .isInstanceOf(ExternalServiceException.class);

            then(repository).shouldHaveNoInteractions();
        }
    }

    @Nested
    @DisplayName("Tenant Context")
    class TenantContext {

        @Test
        @DisplayName("should propagate tenant ID to repository")
        void should_propagate_tenant() {
            given(serproGateway.consultarSituacao(any())).willReturn(situacaoRegular());

            useCase.execute(new ConsultaCommand("12345678000190"));

            then(repository).should().save(argThat(consulta ->
                consulta.getTenantId() != null
            ));
        }
    }

    private SituacaoFiscal situacaoRegular() {
        return new SituacaoFiscal("REGULAR", List.of());
    }
}
```

### Rules

1. **Mock only output ports** (repository, gateway, event publisher). Never mock domain classes.
2. Use BDD style: `given()` → `when()` → `then()`.
3. Use `then(mock).should().method()` to verify interactions (BDD Mockito).
4. Use `then(mock).shouldHaveNoInteractions()` to verify no unintended calls.
5. `@ExtendWith(MockitoExtension.class)` — no `@SpringBootTest` for use case tests.
6. Verify **side effects**: repository saves, events published, gateway calls made.

---

## 6. Integration Tests — Database (Testcontainers)

### Base Class

```java
// src/test/java/com/saas/shared/IntegrationTestBase.java
package com.saas.shared;

import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.context.DynamicPropertyRegistry;
import org.springframework.test.context.DynamicPropertySource;
import org.testcontainers.containers.PostgreSQLContainer;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;

@Testcontainers
@ActiveProfiles("test")
public abstract class IntegrationTestBase {

    @Container
    static final PostgreSQLContainer<?> postgres =
        new PostgreSQLContainer<>("postgres:16-alpine")
            .withDatabaseName("saas_test")
            .withUsername("test")
            .withPassword("test");

    @DynamicPropertySource
    static void configureProperties(DynamicPropertyRegistry registry) {
        registry.add("spring.datasource.url", postgres::getJdbcUrl);
        registry.add("spring.datasource.username", postgres::getUsername);
        registry.add("spring.datasource.password", postgres::getPassword);
    }
}
```

### Repository Test

```java
// src/test/java/com/saas/fiscal/infrastructure/persistence/FiscalRepositoryIntegrationTest.java
package com.saas.fiscal.infrastructure.persistence;

import com.saas.fiscal.domain.ConsultaFiscal;
import com.saas.shared.IntegrationTestBase;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Nested;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.orm.jpa.DataJpaTest;
import org.springframework.boot.test.autoconfigure.jdbc.AutoConfigureTestDatabase;

import java.util.List;

import static com.saas.fiscal.fixtures.ConsultaFiscalTestBuilder.aConsultaFiscal;
import static org.assertj.core.api.Assertions.*;

@DataJpaTest
@AutoConfigureTestDatabase(replace = AutoConfigureTestDatabase.Replace.NONE)
@DisplayName("FiscalRepository — PostgreSQL Integration")
class FiscalRepositoryIntegrationTest extends IntegrationTestBase {

    @Autowired
    private JpaFiscalRepository repository;

    @Nested
    @DisplayName("CRUD Operations")
    class CrudOperations {

        @Test
        @DisplayName("should save and find consulta by ID")
        void should_save_and_find_by_id() {
            ConsultaFiscal consulta = aConsultaFiscal().build();
            ConsultaFiscal saved = repository.save(consulta);

            assertThat(repository.findById(saved.getId()))
                .isPresent()
                .get()
                .extracting(ConsultaFiscal::getCnpj)
                .isEqualTo(consulta.getCnpj());
        }
    }

    @Nested
    @DisplayName("Custom Queries")
    class CustomQueries {

        @Test
        @DisplayName("should find consultas by tenant and Documento")
        void should_find_by_tenant_and_documento() {
            repository.save(aConsultaFiscal().withTenant("t1").withCnpj("123").build());
            repository.save(aConsultaFiscal().withTenant("t2").withCnpj("123").build());

            List<ConsultaFiscal> result = repository.findByTenantIdAndCnpj("t1", "123");
            
            assertThat(result)
                .hasSize(1)
                .allMatch(c -> c.getTenantId().equals("t1"));
        }

        @Test
        @DisplayName("should paginate results correctly")
        void should_paginate() {
            for (int i = 0; i < 25; i++) {
                repository.save(aConsultaFiscal().withTenant("t1").build());
            }

            var page = repository.findByTenantId("t1", PageRequest.of(0, 10));

            assertThat(page.getContent()).hasSize(10);
            assertThat(page.getTotalElements()).isEqualTo(25);
            assertThat(page.getTotalPages()).isEqualTo(3);
        }
    }

    @Nested
    @DisplayName("Tenant Isolation")
    class TenantIsolation {

        @Test
        @DisplayName("should NOT return data from other tenants")
        void should_not_return_other_tenant_data() {
            repository.save(aConsultaFiscal().withTenant("tenant-A").build());
            repository.save(aConsultaFiscal().withTenant("tenant-B").build());

            List<ConsultaFiscal> result = repository.findByTenantId("tenant-A");

            assertThat(result)
                .hasSize(1)
                .noneMatch(c -> c.getTenantId().equals("tenant-B"));
        }
    }
}
```

### Rules

1. **Always use Testcontainers PostgreSQL** for DB tests. Never H2 for production-critical queries.
2. `@DataJpaTest` for repository tests (loads only JPA context).
3. `@AutoConfigureTestDatabase(replace = NONE)` — use the Testcontainers container, not the embedded.
4. Flyway migrations run automatically against the test container.
5. **Test tenant isolation** — every repository test must verify tenant data doesn't leak.

---

## 7. Integration Tests — Controller

```java
// src/test/java/com/saas/fiscal/infrastructure/web/FiscalControllerTest.java
package com.saas.fiscal.infrastructure.web;

import com.saas.fiscal.application.ConsultarSituacaoFiscalUseCase;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Nested;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.WebMvcTest;
import org.springframework.boot.test.mock.bean.MockBean;
import org.springframework.security.test.context.support.WithMockUser;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.test.web.servlet.MockMvc;

import static org.mockito.BDDMockito.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;
import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.jwt;

@WebMvcTest(FiscalController.class)
@DisplayName("FiscalController — API Tests")
class FiscalControllerTest {

    @Autowired private MockMvc mockMvc;
    @MockBean private ConsultarSituacaoFiscalUseCase useCase;

    @Nested
    @DisplayName("GET /api/v1/fiscal/situacao/{documento}")
    class GetSituacao {

        @Test
        @DisplayName("should return 200 with fiscal status when authorized")
        void should_return_200() throws Exception {
            given(useCase.execute(any())).willReturn(regularResult());

            mockMvc.perform(get("/api/v1/fiscal/situacao/12345678000190")
                    .with(jwt()
                        .jwt(token -> token.claim(
                            "tenant_id", "11111111-1111-1111-1111-111111111111"))
                        .authorities(new SimpleGrantedAuthority("ROLE_FISCAL_READ"))))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("REGULAR"))
                .andExpect(jsonPath("$.documento").value("12345678000190"));
        }

        @Test
        @DisplayName("should return 401 when unauthenticated")
        void should_return_401_when_unauthenticated() throws Exception {
            mockMvc.perform(get("/api/v1/fiscal/situacao/12345678000190"))
                .andExpect(status().isUnauthorized());
        }

        @Test
        @DisplayName("should return 403 when missing FISCAL_READ role")
        void should_return_403_when_unauthorized() throws Exception {
            mockMvc.perform(get("/api/v1/fiscal/situacao/12345678000190")
                    .with(jwt()
                        .jwt(token -> token.claim(
                            "tenant_id", "11111111-1111-1111-1111-111111111111"))
                        .authorities(new SimpleGrantedAuthority("ROLE_TENANT_USER"))))
                .andExpect(status().isForbidden());
        }

        @Test
        @DisplayName("should return 400 when Documento is invalid")
        void should_return_400_when_invalid_documento() throws Exception {
            given(useCase.execute(any())).willThrow(new DomainValidationException("Documento inválido"));

            mockMvc.perform(get("/api/v1/fiscal/situacao/invalid")
                    .with(jwt()
                        .jwt(token -> token.claim(
                            "tenant_id", "11111111-1111-1111-1111-111111111111"))
                        .authorities(new SimpleGrantedAuthority("ROLE_FISCAL_READ"))))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.message").value("Documento inválido"));
        }
    }
}
```

### Rules

1. `@WebMvcTest` loads only the web layer — fast, no database.
2. Use `@MockBean` for Use Cases — controller tests verify HTTP, not business logic.
3. **Always** test: 200 (success), 401 (unauthenticated), 403 (wrong role), 400 (validation).
4. For tenant-scoped endpoints, use a mock JWT with the signed `tenant_id` claim and explicit
   authorities. Reserve `@WithMockUser` for tests that do not exercise JWT/tenant extraction.
5. Verify that tenant identities do not need or emit `X-Tenant-ID`; test that header only in the
   explicit Super Admin impersonation flow, including forged-header rejection/override.

---

## 8. Integration Tests — External APIs (WireMock)

```java
// src/test/java/com/saas/fiscal/infrastructure/adapter/SerproGatewayAdapterTest.java
package com.saas.fiscal.infrastructure.adapter;

import com.github.tomakehurst.wiremock.junit5.WireMockRuntimeInfo;
import com.github.tomakehurst.wiremock.junit5.WireMockTest;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import static com.github.tomakehurst.wiremock.client.WireMock.*;
import static org.assertj.core.api.Assertions.*;

@WireMockTest
@DisplayName("SerproGateway — External API Integration")
class SerproGatewayAdapterTest {

    @Test
    @DisplayName("should return fiscal status from Serpro API")
    void should_return_fiscal_status(WireMockRuntimeInfo wmInfo) {
        stubFor(get(urlPathEqualTo("/serpro/v1/situacao/12345678000190"))
            .willReturn(aResponse()
                .withStatus(200)
                .withHeader("Content-Type", "application/json")
                .withBody("""
                    {"situacao": "REGULAR", "debitos": []}
                    """)));

        var adapter = new SerproGatewayAdapter(wmInfo.getHttpBaseUrl());
        var result = adapter.consultarSituacao("12345678000190");

        assertThat(result.getSituacao()).isEqualTo("REGULAR");
        assertThat(result.getDebitos()).isEmpty();
    }

    @Test
    @DisplayName("should throw when Serpro API returns 500")
    void should_throw_on_server_error(WireMockRuntimeInfo wmInfo) {
        stubFor(get(urlPathMatching("/serpro/v1/situacao/.*"))
            .willReturn(aResponse().withStatus(500)));

        var adapter = new SerproGatewayAdapter(wmInfo.getHttpBaseUrl());

        assertThatThrownBy(() -> adapter.consultarSituacao("12345678000190"))
            .isInstanceOf(ExternalServiceException.class);
    }

    @Test
    @DisplayName("should handle timeout gracefully")
    void should_handle_timeout(WireMockRuntimeInfo wmInfo) {
        stubFor(get(urlPathMatching("/serpro/v1/situacao/.*"))
            .willReturn(aResponse().withFixedDelay(5000))); // 5s delay

        var adapter = new SerproGatewayAdapter(wmInfo.getHttpBaseUrl());

        assertThatThrownBy(() -> adapter.consultarSituacao("12345678000190"))
            .isInstanceOf(ExternalServiceException.class)
            .hasMessageContaining("timeout");
    }
}
```

### Rules

1. **All external API calls** must have WireMock tests.
2. Test: success, error (4xx, 5xx), timeout, malformed response.
3. **Never** test against real external APIs (Serpro, payment gateways).

---

## 9. Test Fixtures — Builder Pattern

```java
// src/test/java/com/saas/fiscal/fixtures/ConsultaFiscalTestBuilder.java
package com.saas.fiscal.fixtures;

import com.saas.fiscal.domain.*;
import java.time.LocalDateTime;
import java.util.UUID;

public class ConsultaFiscalTestBuilder {
    private String id = UUID.randomUUID().toString();
    private String documento = "12345678000190";
    private String tenantId = "tenant-test";
    private StatusFiscal status = StatusFiscal.PENDENTE;
    private LocalDateTime createdAt = LocalDateTime.now();

    public static ConsultaFiscalTestBuilder aConsultaFiscal() {
        return new ConsultaFiscalTestBuilder();
    }

    public ConsultaFiscalTestBuilder withCnpj(String documento) {
        this.documento = documento;
        return this;
    }

    public ConsultaFiscalTestBuilder withTenant(String tenantId) {
        this.tenantId = tenantId;
        return this;
    }

    public ConsultaFiscalTestBuilder withStatus(StatusFiscal status) {
        this.status = status;
        return this;
    }

    public ConsultaFiscal build() {
        return new ConsultaFiscal(id, Cnpj.of(documento), tenantId, status, createdAt);
    }
}
```

### Rules

1. **One builder per entity/VO** in the `fixtures/` package.
2. Static factory: `aConsultaFiscal()`, `aDebito()`, `aCnpj()`.
3. Sensible defaults — `build()` returns a valid object without any `with*` calls.
4. **Never** hardcode test data directly in test methods. Always use builders.
5. Builders are shared across test classes within the same module.

---

## 10. ArchUnit — Structural Tests

### Clean Architecture Boundaries

```java
// src/test/java/com/saas/architecture/CleanArchitectureTest.java
package com.saas.architecture;

import com.tngtech.archunit.core.importer.ImportOption;
import com.tngtech.archunit.junit.AnalyzeClasses;
import com.tngtech.archunit.junit.ArchTest;
import com.tngtech.archunit.lang.ArchRule;

import static com.tngtech.archunit.lang.syntax.ArchRuleDefinition.*;
import static com.tngtech.archunit.library.Architectures.layeredArchitecture;

@AnalyzeClasses(packages = "com.saas", importOptions = ImportOption.DoNotIncludeTests.class)
class CleanArchitectureTest {

    @ArchTest
    static final ArchRule layer_dependencies_are_respected =
        layeredArchitecture()
            .consideringAllDependencies()
            .layer("Domain").definedBy("..domain..")
            .layer("Application").definedBy("..application..")
            .layer("Infrastructure").definedBy("..infrastructure..")
            .whereLayer("Domain").mayNotAccessAnyLayer()
            .whereLayer("Application").mayOnlyAccessLayers("Domain")
            .whereLayer("Infrastructure").mayOnlyAccessLayers("Domain", "Application");

    @ArchTest
    static final ArchRule domain_should_not_depend_on_spring =
        noClasses()
            .that().resideInAPackage("..domain..")
            .should().dependOnClassesThat()
            .resideInAnyPackage(
                "org.springframework..",
                "jakarta.persistence..",
                "jakarta.transaction.."
            )
            .because("Domain layer must be framework-independent");

    @ArchTest
    static final ArchRule use_cases_should_not_depend_on_infrastructure =
        noClasses()
            .that().resideInAPackage("..application..")
            .should().dependOnClassesThat()
            .resideInAPackage("..infrastructure..")
            .because("Use Cases must depend on ports, not adapters");

    @ArchTest
    static final ArchRule ports_should_be_interfaces =
        classes()
            .that().resideInAPackage("..application.port..")
            .should().beInterfaces()
            .because("Ports are contracts — always interfaces");
}
```

### Package Structure

```java
// src/test/java/com/saas/architecture/PackageStructureTest.java
package com.saas.architecture;

import com.tngtech.archunit.core.importer.ImportOption;
import com.tngtech.archunit.junit.AnalyzeClasses;
import com.tngtech.archunit.junit.ArchTest;
import com.tngtech.archunit.lang.ArchRule;

import static com.tngtech.archunit.lang.syntax.ArchRuleDefinition.*;

@AnalyzeClasses(packages = "com.saas", importOptions = ImportOption.DoNotIncludeTests.class)
class PackageStructureTest {

    @ArchTest
    static final ArchRule entities_should_reside_in_domain =
        classes()
            .that().areAnnotatedWith(jakarta.persistence.Entity.class)
            .should().resideInAPackage("..domain..")
            .orShould().resideInAPackage("..infrastructure.persistence..")
            .because("JPA entities live in domain or persistence layer");

    @ArchTest
    static final ArchRule controllers_should_reside_in_web_package =
        classes()
            .that().areAnnotatedWith(org.springframework.web.bind.annotation.RestController.class)
            .should().resideInAPackage("..infrastructure.web..")
            .because("Controllers belong in the web infrastructure layer");

    @ArchTest
    static final ArchRule repositories_should_reside_in_persistence =
        classes()
            .that().areAssignableTo(org.springframework.data.jpa.repository.JpaRepository.class)
            .should().resideInAPackage("..infrastructure.persistence..")
            .because("JPA repositories belong in the persistence infrastructure layer");

    @ArchTest
    static final ArchRule services_should_not_be_in_domain =
        noClasses()
            .that().resideInAPackage("..domain..")
            .should().beAnnotatedWith(org.springframework.stereotype.Service.class)
            .because("Domain classes should not use Spring @Service annotation");

    @ArchTest
    static final ArchRule configuration_should_reside_in_config =
        classes()
            .that().areAnnotatedWith(org.springframework.context.annotation.Configuration.class)
            .should().resideInAPackage("..infrastructure.config..")
            .orShould().resideInAPackage("..config..")
            .because("@Configuration classes belong in config packages");
}
```

### Naming Conventions

```java
// src/test/java/com/saas/architecture/NamingConventionTest.java
package com.saas.architecture;

import com.tngtech.archunit.core.importer.ImportOption;
import com.tngtech.archunit.junit.AnalyzeClasses;
import com.tngtech.archunit.junit.ArchTest;
import com.tngtech.archunit.lang.ArchRule;

import static com.tngtech.archunit.lang.syntax.ArchRuleDefinition.*;

@AnalyzeClasses(packages = "com.saas", importOptions = ImportOption.DoNotIncludeTests.class)
class NamingConventionTest {

    @ArchTest
    static final ArchRule controllers_should_end_with_Controller =
        classes()
            .that().areAnnotatedWith(org.springframework.web.bind.annotation.RestController.class)
            .should().haveSimpleNameEndingWith("Controller")
            .because("REST controllers must follow naming convention: *Controller");

    @ArchTest
    static final ArchRule use_cases_should_end_with_UseCase =
        classes()
            .that().resideInAPackage("..application..")
            .and().areNotInterfaces()
            .and().doNotHaveSimpleNameEndingWith("Command")
            .and().doNotHaveSimpleNameEndingWith("Result")
            .and().doNotHaveSimpleNameEndingWith("Port")
            .should().haveSimpleNameEndingWith("UseCase")
            .because("Application services must follow naming convention: *UseCase");

    @ArchTest
    static final ArchRule input_ports_should_end_with_Port =
        classes()
            .that().resideInAPackage("..application.port.in..")
            .should().haveSimpleNameEndingWith("Port")
            .orShould().haveSimpleNameEndingWith("UseCase")
            .because("Input ports must follow naming convention: *Port or *UseCase");

    @ArchTest
    static final ArchRule output_ports_should_end_with_Port =
        classes()
            .that().resideInAPackage("..application.port.out..")
            .should().haveSimpleNameEndingWith("Port")
            .because("Output ports must follow naming convention: *Port");

    @ArchTest
    static final ArchRule adapters_should_end_with_Adapter =
        classes()
            .that().resideInAPackage("..infrastructure.adapter..")
            .and().areNotInterfaces()
            .should().haveSimpleNameEndingWith("Adapter")
            .because("Infrastructure adapters must follow naming convention: *Adapter");

    @ArchTest
    static final ArchRule jpa_repositories_should_start_with_Jpa =
        classes()
            .that().resideInAPackage("..infrastructure.persistence..")
            .and().areAssignableTo(org.springframework.data.jpa.repository.JpaRepository.class)
            .should().haveSimpleNameStartingWith("Jpa")
            .because("JPA repositories must follow naming convention: Jpa*Repository");

    @ArchTest
    static final ArchRule dtos_should_end_with_specific_suffix =
        classes()
            .that().resideInAPackage("..infrastructure.web.dto..")
            .should().haveSimpleNameEndingWith("Request")
            .orShould().haveSimpleNameEndingWith("Response")
            .orShould().haveSimpleNameEndingWith("Dto")
            .because("DTOs must follow naming convention: *Request, *Response, or *Dto");

    @ArchTest
    static final ArchRule exceptions_should_end_with_Exception =
        classes()
            .that().areAssignableTo(Exception.class)
            .should().haveSimpleNameEndingWith("Exception")
            .because("Exception classes must follow naming convention: *Exception");

    @ArchTest
    static final ArchRule test_builders_should_end_with_TestBuilder =
        classes()
            .that().resideInAPackage("..fixtures..")
            .should().haveSimpleNameEndingWith("TestBuilder")
            .because("Test fixture builders must follow naming convention: *TestBuilder");
}
```

### Rules

1. ArchUnit tests run on **every build** — violations break the build.
2. Clean Architecture boundaries: Domain → no external deps. Application → only Domain. Infrastructure → Domain + Application.
3. Naming conventions are enforced by ArchUnit, not just code review.
4. Package structure validation ensures classes are in the correct layer.
5. ArchUnit tests go in `src/test/java/com/saas/architecture/` — separate from module tests.

---

## 11. JaCoCo Coverage Configuration

```xml
<!-- pom.xml -->
<properties>
  <!-- Empty fallbacks keep scoped profiles executable when coverage is inactive. -->
  <surefireArgLine></surefireArgLine>
  <failsafeArgLine></failsafeArgLine>
</properties>

<build>
  <plugins>
    <plugin>
      <groupId>org.apache.maven.plugins</groupId>
      <artifactId>maven-surefire-plugin</artifactId>
      <configuration>
        <argLine>@{surefireArgLine} -javaagent:${org.mockito:mockito-core:jar}</argLine>
        <forkCount>1</forkCount>
        <reuseForks>true</reuseForks>
        <failIfNoTests>true</failIfNoTests>
      </configuration>
    </plugin>
    <plugin>
      <groupId>org.apache.maven.plugins</groupId>
      <artifactId>maven-failsafe-plugin</artifactId>
      <configuration>
        <argLine>@{failsafeArgLine} -javaagent:${org.mockito:mockito-core:jar}</argLine>
        <forkCount>1</forkCount>
        <reuseForks>true</reuseForks>
        <failIfNoTests>true</failIfNoTests>
      </configuration>
    </plugin>
  </plugins>
</build>

<profile>
  <id>backend-pr-coverage</id>
  <activation>
    <activeByDefault>true</activeByDefault>
  </activation>
  <build>
    <plugins>
      <plugin>
        <groupId>org.jacoco</groupId>
        <artifactId>jacoco-maven-plugin</artifactId>
        <version>0.8.15</version>
        <executions>
          <execution>
            <id>jacoco-prepare-unit</id>
            <goals><goal>prepare-agent</goal></goals>
            <configuration>
              <propertyName>surefireArgLine</propertyName>
              <destFile>${project.build.directory}/jacoco-unit.exec</destFile>
              <append>false</append>
            </configuration>
          </execution>
          <execution>
            <id>jacoco-prepare-integration</id>
            <goals><goal>prepare-agent-integration</goal></goals>
            <configuration>
              <propertyName>failsafeArgLine</propertyName>
              <destFile>${project.build.directory}/jacoco-integration.exec</destFile>
              <append>false</append>
            </configuration>
          </execution>
          <execution>
            <id>jacoco-merge-current-run</id>
            <phase>post-integration-test</phase>
            <goals><goal>merge</goal></goals>
            <configuration>
              <fileSets>
                <fileSet>
                  <directory>${project.build.directory}</directory>
                  <includes>
                    <include>jacoco-unit.exec</include>
                    <include>jacoco-integration.exec</include>
                  </includes>
                </fileSet>
              </fileSets>
              <destFile>${project.build.directory}/jacoco.exec</destFile>
            </configuration>
          </execution>
          <execution>
            <id>jacoco-report</id>
            <phase>verify</phase>
            <goals><goal>report</goal></goals>
            <configuration>
              <dataFile>${project.build.directory}/jacoco.exec</dataFile>
            </configuration>
          </execution>
          <execution>
            <id>jacoco-check</id>
            <phase>verify</phase>
            <goals><goal>check</goal></goals>
            <configuration>
              <dataFile>${project.build.directory}/jacoco.exec</dataFile>
              <rules>
                <rule>
                  <element>BUNDLE</element>
                  <limits>
                    <limit>
                      <counter>INSTRUCTION</counter>
                      <value>COVEREDRATIO</value>
                      <minimum>0.73</minimum>
                    </limit>
                    <limit>
                      <counter>BRANCH</counter>
                      <value>COVEREDRATIO</value>
                      <minimum>0.58</minimum>
                    </limit>
                  </limits>
                </rule>
              </rules>
            </configuration>
          </execution>
        </executions>
        <configuration>
          <excludes>
            <exclude>**/SaasServiceApplication.*</exclude>
            <exclude>**/generated/**</exclude>
          </excludes>
        </configuration>
      </plugin>
    </plugins>
  </build>
</profile>
```

### Rules

1. **Minimum coverage:** 73% instructions, 58% branches.
2. **Exclude:** apenas o bootstrap `SaasServiceApplication` e generated code.
   Pacotes `config`/`dto` e sufixos `Dto`, `Application`, `Request` ou `Response`
   não podem ser excluídos: neste monorepo eles contêm mapeamento, parsers,
   contratos ou outro código executável manual.
3. Reports: HTML and XML in `target/site/jacoco/`; the canonical machine-readable
   artifact is `target/site/jacoco/jacoco.xml`.
4. A configuração acima é normativa e deve existir no `backend/pom.xml` com o goal
   `check` ligado a `verify`. Enquanto estiver ausente, cobertura backend é
   `BLOCKED`; quantidade de testes ou relatório histórico não substitui o check.
5. A versão do plugin deve suportar oficialmente a versão Java ativa no POM e
   deve ser um release estável. Para Java 25, o baseline é JaCoCo 0.8.15; a
   [matriz oficial de releases](https://www.jacoco.org/jacoco/trunk/doc/changes.html)
   registra suporte oficial a Java 25 desde 0.8.14 e a 0.8.15 como release estável
   posterior.
6. Surefire e Failsafe escrevem, com `append=false`, em arquivos distintos da
   execução atual. Um fork reutilizável por fase evita sobrescrita entre forks;
   `failIfNoTests=true` impede que um arquivo histórico substitua uma fase vazia.
   O goal `merge` cria `jacoco.exec` somente desses dois arquivos antes de
   `report` e `check`, preservando o `@{...ArgLine}` tardio e o agente Mockito.
7. O profile `backend-pr-coverage` é `activeByDefault` para o `verify` canônico.
   Os profiles parciais `tenant-isolation-gate`, `billing-read-api-postgres-gate`
   e `billing-provider-foundation-gate` o desativam pela semântica Maven de
   profile explícito e não podem ser combinados manualmente com ele.
8. O Quality Gate `backend/pr` DEVE executar `./mvnw -B clean verify`. A limpeza
   prévia remove dados e XML históricos; se a execução atual não produzir o
   report, a validação métrica encontra o artefato ausente e permanece fail-closed.

---

## 12. Test Naming Convention

| Pattern | Used For | Example |
|---|---|---|
| `should_[expected]_when_[condition]` | Behavior verification | `should_reject_invalid_documento` |
| `should_[expected]` | Simple assertion | `should_create_with_status_pendente` |
| `should_not_[unexpected]` | Negative assertion | `should_not_return_other_tenant_data` |

### Rules

1. **Test class names:** `{SourceClass}Test` (unit) or `{SourceClass}IntegrationTest` (integration).
2. **Test method names:** `should_*` pattern. No `test` prefix.
3. **@DisplayName** on every class and method — used in reports.
4. **@Nested** for logical grouping (Creation, Equality, ErrorHandling, TenantIsolation).

---

## 13. Quality Gates

| Gate | Threshold | Phase |
|---|---|---|
| Unit tests pass | 100% | `./mvnw test` |
| Integration tests pass | 100% | `./mvnw clean verify` |
| Code coverage (instruction) | ≥ 73% | `./mvnw clean verify` (JaCoCo) |
| Code coverage (branch) | ≥ 58% | `./mvnw clean verify` (JaCoCo) |
| Architecture rules | 0 violations | `./mvnw test` (ArchUnit) |
| Naming conventions | 0 violations | `./mvnw test` (ArchUnit) |
| Package structure | 0 violations | `./mvnw test` (ArchUnit) |

### Maven Commands

```bash
# Unit tests only
./mvnw test

# Unit + Integration tests + Coverage + ArchUnit
./mvnw clean verify

# Coverage report
./mvnw clean verify
```

### Rules

1. All ArchUnit tests run during `mvn test` — structural violations break the build.
2. Coverage below threshold fails `mvn clean verify`.
3. **No flaky tests.** Zero tolerance. Fix or quarantine with `@Disabled("flaky: #issue")`.
4. Full suite must complete in < 5 minutes locally.

## 14. Change log

| Versão | Data | Mudança |
| --- | --- | --- |
| 1.11 | 2026-09-12 | Remove a exclusão `*Dto` após comprovar métodos de mapeamento manuais; apenas bootstrap Spring exato e código gerado permanecem fora da cobertura. |
| 1.10 | 2026-09-12 | Remove a exclusão por pacote `dto`, mantendo requests, responses e parsers executáveis na medição; apenas o sufixo técnico exato `Dto` permanece excluído. |
| 1.9 | 2026-09-12 | Remove a exclusão ampla de `config` e restringe o bootstrap à classe exata `SaasServiceApplication`, mantendo código executável na cobertura. |
| 1.8 | 2026-09-12 | Torna `clean verify` o comando canônico do gate backend/pr, eliminando XML e execution data históricos antes da medição fail-closed. |
| 1.7 | 2026-09-12 | Torna a cobertura determinística por execução com arquivos Surefire/Failsafe separados, substituição fail-closed e merge explícito antes de report/check. |
| 1.6 | 2026-09-12 | Alinha JaCoCo 0.8.15 ao Java 25, compõe Surefire/Failsafe com append, isola gates parciais em profiles e restringe exclusions aos tipos inequivocamente técnicos. |
| 1.5 | 2026-09-08 | Torna explícito que JaCoCo/check ausente bloqueia o Quality Gate e adota o Maven Wrapper do pacote. |
