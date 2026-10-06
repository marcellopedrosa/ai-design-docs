---
document_id: "PROJECT-DEVELOPMENT-STANDARD"
primary_nature: "Regra"
objective: "Definir regras reutilizáveis e verificáveis para Development."
scope: "Fluxo geral de desenvolvimento, qualidade, validação e práticas compartilhadas."
non_objectives: "Não criar requisitos de produto, decisões arquiteturais concretas ou procedimentos fora do escopo deste standard."
owner: "Arquitetura e Qualidade"
status: "Active"
date: "2026-08-25"
last_reviewed: "2026-09-13"
version: "1.11"
keywords: "development, standard, openapi, api-contract, contract-first, comentarios, tamanho-de-arquivo, git, branch, conventional-commits"
related_files: "./README.md, ./ddd-clean-architecture-standard.md, ./api-client-standard.md, ./software-quality-standard.md, docs/api_contracts/README.md"
code_references: "docs/api_contracts/, infra/scripts/validate-quality-metrics.mjs, backend/, frontend/, infra/"
principal_statement: "Código deve permanecer pequeno, legível e mensurável; APIs seguem contract-first e entrega Git autônoma ocorre somente em branch governada após todos os gates aplicáveis em PASS."
---

# Guia de Desenvolvimento

Este documento fornece diretrizes para desenvolvedores que trabalham no SAAS Service.

## Sumário

1. [Ambiente de Desenvolvimento](#ambiente-de-desenvolvimento)
2. [Estrutura de um Bounded Context](#estrutura-de-um-bounded-context)
3. [Criando um Novo Endpoint](#criando-um-novo-endpoint)
4. [Criando um Novo Use Case](#criando-um-novo-use-case)
5. [Trabalhando com Eventos](#trabalhando-com-eventos)
6. [Escrevendo Testes](#escrevendo-testes)
7. [Convenções de Código](#convenções-de-código)
8. [Checklist de Pull Request](#checklist-de-pull-request)

---

## Ambiente de Desenvolvimento

### Pré-requisitos

```
┌─────────────────────────────────────────────────────────────────────────┐
│                      DEVELOPMENT ENVIRONMENT                            │
│                                                                         │
│  Required Software                                                      │
│  ─────────────────                                                      │
│  • Java 25 (OpenJDK ou distribuição compatível)                        │
│  • Maven 3.9+                                                           │
│  • Docker & Docker Compose                                              │
│  • IDE (Google Antigravity)                                      │
│                                                                         │
│  Optional                                                               │
│  ────────                                                               │
│  • DBeaver (visualizar banco)                                           │
│  • Postman/Insomnia (testar APIs)                                       │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

### Inicialização

```bash
# 1. Clonar repositório
git clone <repo-url>
cd saas-service

# 2. Subir infraestrutura
cd src/main/docker
docker compose up -d

# 3. Executar aplicação
cd ../../..
mvn spring-boot:run -Dspring-boot.run.profiles=dev

# 4. Executar testes
mvn test
```

### Comandos Úteis

```bash
# Build sem testes
mvn clean package -DskipTests

# Gerar código OpenAPI
mvn generate-sources

# Executar apenas testes unitários
mvn test -Dtest="*Test"

# Executar testes de um módulo
mvn test -Dtest="ServiceOrderModuleTest"

# Verificar estilo de código
mvn spotless:check

# Formatar código
mvn spotless:apply
```

---

## Estrutura de um Bounded Context

> 📘 Consulte [`ddd-clean-architecture-standard.md`](./ddd-clean-architecture-standard.md) para o diagrama completo de pacotes, camadas Clean Architecture e a estrutura interna de cada Bounded Context.



## Criando um Novo Endpoint

Antes de código ou configuração executável, crie ou atualize o contrato OpenAPI
3.1.x canônico em [`docs/api_contracts/`](../../api_contracts/README.md), referencie sua
`info.version` e seus `operationId`s nos documentos oficiais e obtenha readiness
`READY`. O contrato deve explicitar método/path, roles/authorities, parâmetros,
request, responses de sucesso, bodies, erros `application/problem+json` e
compatibilidade conforme o
[`api-client-standard.md`](api-client-standard.md). Controller ou documentação
gerada são evidência de paridade, não fonte concorrente.

### Passo a Passo

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    CREATING A NEW ENDPOINT                              │
│                                                                         │
│  1. OPENAPI SPEC                                                        │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │  Editar: docs/api_contracts/{context}-vN.openapi.yaml                 │
│  │                                                                  │   │
│  │  paths:                                                          │   │
│  │    /v1/my-entities:                                              │   │
│  │      post:                                                       │   │
│  │        operationId: createMyEntity                               │   │
│  │        security: [{ bearerAuth: [] }]                            │   │
│  │        x-required-roles: [ROLE_<ROLE>]                           │   │
│  │        x-required-authorities: [<CONTEXT>_CREATE]                │   │
│  │        requestBody:                                              │   │
│  │          content:                                                │   │
│  │            application/json:                                     │   │
│  │              schema:                                             │   │
│  │                $ref: '#/components/schemas/CreateMyEntityRequest'│   │
│  │        responses:                                                │   │
│  │          '201':                                                  │   │
│  │            description: Created                                  │   │
│  │            content:                                              │   │
│  │              application/json:                                   │   │
│  │                schema:                                           │   │
│  │                  $ref: '#/components/schemas/MyEntityResponse'   │   │
│  │          '400': { $ref: '#/components/responses/BadRequest' }    │   │
│  │          '401': { $ref: '#/components/responses/Unauthorized' }  │   │
│  │          '403': { $ref: '#/components/responses/Forbidden' }     │   │
│  │                                                                  │   │
│  └─────────────────────────────────────────────────────────────────┘   │
│                               │                                         │
│                               ▼                                         │
│  2. GENERATE CODE                                                       │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │  mvn generate-sources                                            │   │
│  │                                                                  │   │
│  │  Gerado em target/generated-sources/openapi/{context}/           │   │
│  │  ├── {Context}Api.java  (interface)                              │   │
│  │  └── dto/                                                        │   │
│  │      ├── CreateMyEntityRequestDTO.java                           │   │
│  │      └── MyEntityResponseDTO.java                                │   │
│  └─────────────────────────────────────────────────────────────────┘   │
│                               │                                         │
│                               ▼                                         │
│  3. IMPLEMENT CONTROLLER                                                │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │  @RestController                                                 │   │
│  │  public class MyEntityController implements MyEntitiesApi {      │   │
│  │                                                                  │   │
│  │      @Override                                                   │   │
│  │      @PreAuthorize("hasAnyRole('ADMIN', 'USER')")                │   │
│  │      public ResponseEntity<MyEntityResponseDTO> createMyEntity(  │   │
│  │              CreateMyEntityRequestDTO request) {                 │   │
│  │          var command = OpenApiMapper.toCommand(request);         │   │
│  │          var response = createUseCase.execute(command);          │   │
│  │          var dto = OpenApiMapper.toResponseDto(response);        │   │
│  │          return ResponseEntity.status(HttpStatus.CREATED)        │   │
│  │                               .body(dto);                        │   │
│  │      }                                                           │   │
│  │  }                                                               │   │
│  │                                                                  │   │
│  └─────────────────────────────────────────────────────────────────┘   │
│                               │                                         │
│                               ▼                                         │
│  4. CREATE MAPPER                                                       │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │  public class OpenApiMapper {                                    │   │
│  │                                                                  │   │
│  │      public static CreateMyEntityCommandDTO toCommand(           │   │
│  │              CreateMyEntityRequestDTO request) {                 │   │
│  │          return new CreateMyEntityCommandDTO(                    │   │
│  │              request.getName(),                                  │   │
│  │              request.getDescription()                            │   │
│  │          );                                                      │   │
│  │      }                                                           │   │
│  │                                                                  │   │
│  │      public static MyEntityResponseDTO toResponseDto(            │   │
│  │              MyEntityApplicationResponseDTO response) {          │   │
│  │          var dto = new MyEntityResponseDTO();                    │   │
│  │          dto.setId(response.id());                               │   │
│  │          dto.setName(response.name());                           │   │
│  │          return dto;                                             │   │
│  │      }                                                           │   │
│  │  }                                                               │   │
│  │                                                                  │   │
│  └─────────────────────────────────────────────────────────────────┘   │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## Criando um Novo Use Case

### Template

```java
package br.com.duoset.saas_service.contexts.{context}.internal.application.usecase;

import br.com.duoset.saas_service.contexts.{context}.internal.application.dto.*;
import br.com.duoset.saas_service.contexts.{context}.internal.domain.model.*;
import br.com.duoset.saas_service.contexts.{context}.internal.domain.repository.*;
import br.com.duoset.saas_service.contexts.{context}.events.*;
import br.com.duoset.saas_service.shared.exception.BusinessException;
import br.com.duoset.saas_service.shared.messaging.DomainEventPublisher;
import lombok.RequiredArgsConstructor;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * Use case para criar uma nova entidade.
 *
 * <p>Responsabilidades:
 * <ul>
 *   <li>Validar dados de entrada</li>
 *   <li>Verificar regras de negócio</li>
 *   <li>Criar aggregate</li>
 *   <li>Persistir no repositório</li>
 *   <li>Publicar evento de domínio</li>
 * </ul>
 */
@Service
@RequiredArgsConstructor
public class CreateMyEntityUseCase {

    private static final Logger log = LoggerFactory.getLogger(CreateMyEntityUseCase.class);

    private final MyEntityRepository repository;
    private final DomainEventPublisher eventPublisher;
    private final TenantContextPort tenantContext;

    /**
     * Executa o caso de uso.
     *
     * @param command dados para criação
     * @return DTO com dados da entidade criada
     * @throws BusinessException se regras de negócio forem violadas
     */
    @Transactional
    public MyEntityResponseDTO execute(CreateMyEntityCommandDTO command) {
        // 1. Obter tenant atual
        var tenantId = tenantContext.requireCurrentTenant();
        log.debug("Creating MyEntity for tenant: {}", tenantId);

        // 2. Validar regras de negócio
        validateBusinessRules(command);

        // 3. Criar aggregate
        var entity = MyEntity.create(
            tenantId,
            command.name(),
            command.description()
        );

        // 4. Persistir
        entity = repository.save(entity);
        log.info("MyEntity created: {} ({})", entity.id(), entity.name());

        // 5. Publicar evento
        eventPublisher.publish(new MyEntityCreatedEvent(
            entity.id().value(),
            tenantId.value(),
            entity.name()
        ));

        // 6. Retornar resposta
        return toResponseDTO(entity);
    }

    private void validateBusinessRules(CreateMyEntityCommandDTO command) {
        // Exemplo: verificar duplicação
        if (repository.existsByName(command.name())) {
            throw new BusinessException("Entity with name already exists: " + command.name());
        }
    }

    private MyEntityResponseDTO toResponseDTO(MyEntity entity) {
        return new MyEntityResponseDTO(
            entity.id().value(),
            entity.name(),
            entity.description(),
            entity.createdAt(),
            entity.updatedAt()
        );
    }
}
```

---

## Trabalhando com Eventos

### Criando um Evento

```java
// Em contexts/{context}/events/

/**
 * Evento publicado quando uma entidade é criada.
 *
 * <p>Este evento é consumido por:
 * <ul>
 *   <li>AuditListener - para registrar log de auditoria</li>
 *   <li>NotificationListener - para enviar notificações</li>
 * </ul>
 *
 * @param entityId ID da entidade criada
 * @param tenantId ID do tenant
 * @param name Nome da entidade
 */
public record MyEntityCreatedEvent(
    UUID entityId,
    UUID tenantId,
    String name
) {}
```

### Consumindo Eventos

```java
// Em contexts/{other-context}/internal/application/listener/

@Component
@RequiredArgsConstructor
public class MyEntityEventListener {

    private static final Logger log = LoggerFactory.getLogger(MyEntityEventListener.class);

    private final SomeRepository repository;

    /**
     * Processa evento de criação de entidade.
     *
     * <p>Este handler é executado de forma síncrona na mesma transação
     * do publicador. Se falhar, toda a transação será revertida.
     */
    @EventListener
    @Transactional
    public void handle(MyEntityCreatedEvent event) {
        log.info("Processing MyEntityCreatedEvent: {}", event.entityId());

        try {
            // Lógica de processamento
            doSomething(event);
        } catch (Exception e) {
            log.error("Failed to process event: {}", event.entityId(), e);
            // Decidir: relançar (rollback) ou apenas logar
            throw e;
        }
    }

    /**
     * Handler assíncrono para operações não críticas.
     */
    @EventListener
    @Async
    public void handleAsync(MyEntityCreatedEvent event) {
        // Operações que podem falhar sem afetar a transação principal
        sendNotification(event);
    }
}
```

---

## Escrevendo Testes

### Estrutura de Testes

```
src/test/java/br/com/duoset/saas_service/contexts/{context}/
│
├── {Context}ModuleTest.java           # Testes de módulo (API pública + eventos)
│
└── internal/
    ├── domain/
    │   └── model/
    │       ├── {Entity}Test.java      # Testes do aggregate
    │       └── valueobjects/
    │           └── {VO}Test.java      # Testes de value objects
    │
    └── application/
        └── usecase/
            ├── Create{Entity}UseCaseTest.java
            ├── Get{Entity}UseCaseTest.java
            └── ...
```

### Template de Teste de Use Case

```java
@DisplayName("CreateMyEntityUseCase")
@ExtendWith(MockitoExtension.class)
class CreateMyEntityUseCaseTest {

    @Mock
    private MyEntityRepository repository;

    @Mock
    private DomainEventPublisher eventPublisher;

    @Mock
    private TenantContextPort tenantContext;

    private CreateMyEntityUseCase useCase;

    @BeforeEach
    void setUp() {
        useCase = new CreateMyEntityUseCase(
            repository,
            eventPublisher,
            tenantContext
        );
    }

    @Nested
    @DisplayName("Criação bem-sucedida")
    class SuccessfulCreation {

        @Test
        @DisplayName("Deve criar entidade com sucesso")
        void shouldCreateEntitySuccessfully() {
            // Given
            var command = new CreateMyEntityCommandDTO("Name", "Description");
            setupMocksForSuccess();

            when(repository.save(any(MyEntity.class)))
                .thenAnswer(inv -> inv.getArgument(0));

            // When
            var response = useCase.execute(command);

            // Then
            assertThat(response).isNotNull();
            assertThat(response.name()).isEqualTo("Name");

            verify(repository).save(any(MyEntity.class));
            verify(eventPublisher).publish(any(MyEntityCreatedEvent.class));
        }
    }

    @Nested
    @DisplayName("Validações de erro")
    class ErrorValidations {

        @Test
        @DisplayName("Deve rejeitar quando nome já existe")
        void shouldRejectWhenNameExists() {
            // Given
            var command = new CreateMyEntityCommandDTO("Existing", "Desc");
            when(repository.existsByName("Existing")).thenReturn(true);

            // When/Then
            assertThatThrownBy(() -> useCase.execute(command))
                .isInstanceOf(BusinessException.class)
                .hasMessageContaining("already exists");

            verify(repository, never()).save(any());
            verify(eventPublisher, never()).publish(any());
        }
    }

    private void setupMocksForSuccess() {
        var tenantId = TenantId.generate();
        when(tenantContext.requireCurrentTenant())
            .thenReturn(TenantId.fromRealmName("test-tenant"));
        when(repository.existsByName(anyString())).thenReturn(false);
    }
}
```

### Template de Teste de Módulo

```java
@DisplayName("MyEntity Module Tests")
@ExtendWith(MockitoExtension.class)
class MyEntityModuleTest {

    @Nested
    @DisplayName("Event Contract Tests")
    class EventContractTests {

        @Test
        @DisplayName("MyEntityCreatedEvent deve conter todos os campos")
        void eventShouldHaveAllRequiredFields() {
            // Given
            var entityId = UUID.randomUUID();
            var tenantId = UUID.randomUUID();
            var name = "Test Entity";

            // When
            var event = new MyEntityCreatedEvent(entityId, tenantId, name);

            // Then
            assertThat(event.entityId()).isEqualTo(entityId);
            assertThat(event.tenantId()).isEqualTo(tenantId);
            assertThat(event.name()).isEqualTo(name);
        }
    }

    @Nested
    @DisplayName("Public API Tests")
    class PublicApiTests {
        // Testes da interface MyEntityApi
    }
}
```

---

## Convenções de Código

### Nomenclatura

| Tipo | Padrão | Exemplo |
|------|--------|---------|
| Package | lowercase | `br.com.duoset.saas_service.contexts.tenant` |
| Class | PascalCase | `ServiceOrderController` |
| Interface | PascalCase | `ServiceOrderRepository` |
| Method | camelCase | `createServiceOrder()` |
| Constant | UPPER_SNAKE | `DEFAULT_PAGE_SIZE` |
| DTO | PascalCase + DTO | `CreateServiceOrderCommandDTO` |
| Event | PascalCase + Event | `ServiceOrderCreatedEvent` |
| Test | PascalCase + Test | `CreateServiceOrderUseCaseTest` |

### Sufixos

| Camada | Sufixo | Exemplo |
|--------|--------|---------|
| Controller | Controller | `ServiceOrderController` |
| Use Case | UseCase | `CreateServiceOrderUseCase` |
| Repository | Repository | `ServiceOrderRepository` |
| Adapter | Adapter | `KeycloakAdapter` |
| Port | Port | `EmailPort` |
| DTO (command) | CommandDTO | `CreateServiceOrderCommandDTO` |
| DTO (response) | ResponseDTO | `ServiceOrderResponseDTO` |
| Event | Event | `ServiceOrderCreatedEvent` |
| Mapper | Mapper | `ServiceOrderOpenApiMapper` |

### Comentários

Comentários devem ser curtos e diretos e explicar intenção, restrição ou decisão que
o código não comunica sozinho. Não narre a instrução seguinte nem preserve código
desativado em comentário: remova-o e use o histórico versionado. Cada linha textual
tem no máximo 100 caracteres e cada bloco contíguo no máximo 12 linhas. `TODO` e
`FIXME` exigem ID ou URL rastreável. Não há densidade mínima obrigatória.

```java
@Service
public class CreateServiceOrderUseCase {
    // Persiste antes de publicar para impedir evento de uma transação rejeitada.
    private void createAndPublish(CreateServiceOrderCommandDTO command) { }
}
```

### Granularidade de arquivos

Arquivo fonte alterado deve possuir no máximo 500 linhas físicas. Ao ultrapassar o
limite, a implementação é decomposta por responsabilidade coesa antes do handoff;
recortar por quantidade sem preservar coesão não satisfaz a regra. O Quality Gate
mede somente os `--target` explícitos, portanto dívida legada não tocada permanece
fora do recorte e passa a ser exigível quando o arquivo for alterado.

---

## Checklist de Pull Request

### Antes de Abrir PR

```
┌─────────────────────────────────────────────────────────────────────────┐
│                      PULL REQUEST CHECKLIST                             │
│                                                                         │
│  ☐ Código                                                               │
│    ├── Segue convenções de nomenclatura                                 │
│    ├── Sem código comentado                                             │
│    ├── Comentários curtos, diretos e rastreáveis                         │
│    ├── Arquivos alterados com até 500 linhas                             │
│    ├── Sem System.out.println                                           │
│    ├── Tratamento de erros apropriado                                   │
│    └── Logs em nível adequado (DEBUG, INFO, ERROR)                      │
│                                                                         │
│  ☐ Testes                                                               │
│    ├── Testes unitários para use cases                                  │
│    ├── Testes de contrato para eventos                                  │
│    ├── Testes passando localmente (mvn test)                            │
│    └── Cobertura adequada dos casos de erro                             │
│                                                                         │
│  ☐ Documentação                                                         │
│    ├── OpenAPI canônico em docs/api_contracts/ atualizado e Active          │
│    ├── Versão/operações referenciadas nos documentos oficiais           │
│    ├── Paridade método/path/RBAC/bodies/errors testada                   │
│    ├── Javadoc em métodos públicos                                      │
│    └── PROGRESS.md atualizado (se feature significativa)                │
│                                                                         │
│  ☐ Segurança                                                            │
│    ├── @PreAuthorize em endpoints                                       │
│    ├── Validação de entrada                                             │
│    ├── Sem dados sensíveis em logs                                      │
│    └── Tenant isolation verificado                                      │
│                                                                         │
│  ☐ Build                                                                │
│    ├── mvn clean package -DskipTests passa                              │
│    ├── mvn spotless:check passa                                         │
│    └── Sem warnings de compilação                                       │
│                                                                         │
│  ☐ Git                                                                  │
│    ├── Commits atômicos e bem descritos                                 │
│    ├── Branch X.Y.Z-{docs,feat,fix}-short-description                    │
│    └── Push somente após readiness e A1/A2/A3 aplicáveis em PASS         │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

### Mensagem de Commit

Mensagens seguem [Conventional Commits 1.0.0](https://www.conventionalcommits.org/en/v1.0.0/).
O tipo do commit descreve o delta; `feat`, `fix` e `docs` devem permanecer coerentes
com a natureza da branch, embora commits auxiliares `test`, `refactor`, `build` ou
`chore` possam existir na mesma entrega quando necessários ao objetivo.

```bash
# Formato obrigatório no repositório
<type>(<coordenada-da-branch>): <description>

# Tipos
feat:     Nova funcionalidade
fix:      Correção de bug
refactor: Refatoração
test:     Adição/modificação de testes
docs:     Documentação
chore:    Manutenção (build, deps, etc.)

# Exemplos
feat(301.1.2): adiciona endpoint de agendamento
fix(302.1.0): corrige validação de data de início
refactor(303.2.1): extrai validação de documento para value object
test(301.1.2): adiciona testes para CreateServiceOrderUseCase
docs(45.1.0): documenta fluxo de eventos
```

`<coordenada-da-branch>` é obrigatório para commits criados autonomamente. No
worktree que receberá o commit, execute `git branch --show-current`; extraia da
branch governada sua coordenada inicial `X.Y.Z` e use exatamente esse valor no
escopo (`^[0-9]+\.[0-9]+\.[0-9]+$`). Exemplo: a branch
`301.1.2-feat-cash-in` exige `feat(301.1.2): ...`. O caminho do diretório não é
autoritativo. Em detached HEAD, branch ausente ou nome fora do contrato, pare em
`BLOCKED`; não infira o escopo. A regra especializa o `scope` opcional de
Conventional Commits sem mudar sua sintaxe.

Antes do primeiro commit do clone, execute `./infra/scripts/install-git-hooks.sh`.
Isso configura `core.hooksPath=.githooks`; o hook `commit-msg` recusa mensagens
fora do contrato e `--no-verify` não é permitido.

### Branch e push governado

- Formato: `X.Y.Z-{docs,feat,fix}-short-description`.
- Estando em `main`, `master`, `develop`, `release/*` ou outra branch fora do
  contrato, o agente cria ou troca autonomamente para a branch governada antes de
  preparar o commit.
- `X.Y.Z`: coordenada numérica da task ou Implementation Plan que autoriza o
  trabalho; para TP-00045 v1.2, por exemplo, `45.1.2-feat-quality-metrics`.
- Descrição: kebab-case minúscula, alfanumérica e sem barras.
- Antes do push, execute o quality gate em `pr` ou `release` com todos os targets,
  `--delivery` e `--branch-name`.
- Somente o `PASS` integral permite `git push --set-upstream origin <branch-exata>`.
  `main`, `master`, `develop`, `release/*`, force-push, exclusão remota, tags,
  merge, rebase, reset, alteração de remote e inclusão de paths fora do escopo são
  proibidos para a autonomia do agente.
- Falha de autenticação, rede, proteção da branch ou divergência de gate produz
  `BLOCKED`; o agente não contorna a proteção e não lê credenciais.

---

*Última atualização: 2026-09-13 — v1.11: agente cria/troca para branch governada antes do commit.*
