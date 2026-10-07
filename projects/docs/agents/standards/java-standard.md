---
document_id: "JAVA-STANDARD"
primary_nature: "Regra"
objective: "Definir regras reutilizáveis e verificáveis para Java."
scope: "Convenções de linguagem, modelagem, legibilidade e manutenção do código Java."
non_objectives: "Não criar requisitos de produto, decisões arquiteturais concretas ou procedimentos fora do escopo deste standard."
owner: "Arquitetura e Qualidade"
status: "Active"
date: "2026-08-25"
version: "1.4"
keywords: "java, standard, standard"
related_files: "./README.md, ddd-clean-architecture-standard.md"
code_references: "backend/, infra/"
principal_statement: "As regras de Java aplicam-se somente ao escopo e aos controles declarados neste standard."
---

# Convencoes Java

## Nomenclatura de Classes

| Camada | Sufixo | Exemplo | Pacote |
|--------|--------|---------|--------|
| Controller | `Controller` | `UserController` | `presentation/rest/` |
| Use Case | `UseCase` | `CreateUserUseCase` | `application/usecase/` |
| Service | `Service` | `MonitoringStatusService` | `application/service/` |
| Repository Interface | `Repository` | `UserRepository` | `domain/repository/` |
| Repository JPA | `JpaRepository` | `UserJpaRepository` | `infrastructure/persistence/` |
| Adapter | `Adapter` | `MailAdapter` | `infrastructure/adapter/` |
| Port | `Port` | `EmailPort` | `application/port/` |
| DTO | `DTO` | `UserResponseDTO` | Varia (gerados ou manuais) |
| Event | `Event` | `TenantCreatedEvent` | `events/` |
| Entity JPA | `JpaEntity` | `UserJpaEntity` | `infrastructure/persistence/` |
| Entity Domain | (sem sufixo) | `User` | `domain/model/` |
| Value Object | (sem sufixo) | `Email`, `TenantId` | `domain/model/valueobjects/` |
| Mapper | `Mapper` | `UserPersistenceMapper` | `infrastructure/persistence/` |
| Exception | `Exception` | `UserNotFoundException` | `domain/exception/` |
| Validator (HTTP/seguranca) | `Validator` | `WebhookSecretValidator` | `presentation/rest/` quando acoplado ao request |

## Estrutura de Pacotes por Contexto

> 📘 Consulte [`ddd-clean-architecture-standard.md`](ddd-clean-architecture-standard.md) para a estrutura completa de pacotes, camadas Clean Architecture e Bounded Context Map.

## Padroes de Codigo

### Entidades de Dominio (Clean Architecture)
```java
public class User {
    private UserId id;
    private Email email;
    private TenantId tenantId;

    // Factory method para criacao
    public static User create(Email email, TenantId tenantId) {
        return new User(UserId.generate(), email, tenantId);
    }

    // Factory method para reconstituicao (do banco)
    public static User reconstruct(UserId id, Email email, TenantId tenantId) {
        return new User(id, email, tenantId);
    }

    // Construtor privado
    private User(UserId id, Email email, TenantId tenantId) {
        this.id = Objects.requireNonNull(id);
        this.email = Objects.requireNonNull(email);
        this.tenantId = Objects.requireNonNull(tenantId);
    }
}
```

### Use Cases
```java
@Service
@RequiredArgsConstructor
public class CreateUserUseCase {
    private final UserRepository userRepository;
    private final TenantContextPort tenantContext;

    @Transactional
    public User execute(CreateUserCommand command) {
        var tenantId = tenantContext.getCurrentTenantId();
        var user = User.create(command.email(), tenantId);
        return userRepository.save(user);
    }
}
```

### Controllers
```java
@RestController
@RequestMapping("/v1/users")
@RequiredArgsConstructor
public class UserController implements UsersApi {
    private final CreateUserUseCase createUserUseCase;

    @Override
    public ResponseEntity<UserResponseDTO> createUser(CreateUserRequestDTO request) {
        var command = new CreateUserCommand(new Email(request.getEmail()));
        var user = createUserUseCase.execute(command);
        return ResponseEntity.status(HttpStatus.CREATED)
            .body(UserMapper.toDTO(user));
    }
}
```

### Value Objects
```java
public record Email(String value) {
    public Email {
        Objects.requireNonNull(value);
        if (!value.matches("^[\\w-\\.]+@[\\w-]+\\.[a-z]{2,}$")) {
            throw new InvalidEmailException(value);
        }
    }
}
```

## Anotacoes Comuns

| Anotacao | Uso |
|----------|-----|
| `@Service` | Use Cases, Services |
| `@Repository` | Repositorios JPA |
| `@Component` | Adapters, Mappers |
| `@RestController` | Controllers REST |
| `@Transactional` | Metodos que modificam dados |
| `@RequiredArgsConstructor` | Injecao via construtor (Lombok) |
| `@Slf4j` | Logging (Lombok) |
| `@ApplicationModuleListener` | Listeners de eventos Spring Modulith |

## Lombok

Usar com moderacao:
- `@RequiredArgsConstructor` - OK
- `@Slf4j` - OK
- `@Getter` / `@Setter` - Evitar em entidades de dominio
- `@Data` - NUNCA em entidades de dominio
- `@Builder` - OK para DTOs

## Records vs Classes

- **Records**: Value Objects, DTOs, Commands, Events
- **Classes**: Entidades de dominio (precisam de factory methods)

## Null Safety

- Usar `Objects.requireNonNull()` em construtores
- Retornar `Optional<T>` quando valor pode ser ausente
- Nunca retornar `null` de metodos publicos
