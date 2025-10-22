# Estratégia para Criação de Testes Unitários

## 1. Análise e Identificação

**Dependências:**  
Verificar o `pom.xml` do módulo `domain` para confirmar que as dependências do **JUnit 5** (`junit-jupiter-api`, `junit-jupiter-engine`) e **Mockito** (`mockito-core`, `mockito-junit-jupiter`) estão configuradas.  
Caso não estejam, adicioná-las.

**Classes de Modelo:**  
Identificar as classes de negócio principais (entidades, objetos de valor) no pacote  
`br.com.csc.pix_service.domain` e seus subpacotes.  
Como não há um pacote `model` explícito, focar nas classes que representam os conceitos centrais do negócio **PIX**.

**Convenções Existentes:**  
Analisar testes existentes, como `RecTest.java`, para seguir as convenções de nomenclatura, estrutura e asserções já utilizadas no projeto.

---

## 2. Estrutura dos Testes

**Nomenclatura:**  
Para cada classe de modelo, como `MinhaClasse.java`, nomear o teste correspondente como `MinhaClasseTest.java`.

**Localização:**  
Criar os arquivos de teste no diretório:  
`pix-service/domain/src/test/java/`  
seguindo a mesma estrutura de pacotes da classe original.

**Anotações:**  
Usar as anotações do **JUnit 5**, como:
- `@Test` para definir um caso de teste;
- `@DisplayName` para dar nomes descritivos e legíveis aos testes;
- `@ExtendWith(MockitoExtension.class)` para habilitar a integração com o Mockito.

---

## 3. Casos de Teste

Para cada classe, criar testes que validem os seguintes cenários:

- **Construção de Objetos:**  
  Testar se os construtores criam objetos em um estado válido e se lançam exceções quando recebem parâmetros inválidos (ex: nulos, vazios, fora do padrão esperado).

- **Validações de Regras de Negócio:**  
  Verificar se os métodos que contêm lógica de negócio se comportam como esperado (ex: mudar o estado de um objeto, realizar cálculos).

- **Métodos de Acesso (Getters/Setters):**  
  Garantir que os getters retornem os valores corretos e que os setters alterem os estados corretamente, especialmente se houver alguma lógica de validação neles.

- **Contratos (`equals` e `hashCode`):**  
  Quando aplicável, testar se os métodos `equals` e `hashCode` funcionam corretamente, garantindo a unicidade e a comparação adequada dos objetos.

---

## 4. Uso de Mocks (Mockito)

Usar **Mockito** para isolar a classe em teste de suas dependências externas.  
Por exemplo, se uma classe de modelo de negócio precisar consultar um repositório ou outro serviço, *mockar* essa dependência.  
Isso garante que o teste foque exclusivamente na lógica da classe em questão.

Para classes de modelo que são apenas contêineres de dados (*POJOs*), o uso de mocks pode não ser necessário.

---

## 5. Documentação e Clareza

Em cada método de teste (`@Test`), incluir um comentário ou um `@DisplayName` claro e conciso, explicando o que exatamente está sendo testado.

### Exemplo de comentário em método:

```java
@Test
@DisplayName("Deve criar um objeto PIX válido quando todos os parâmetros são fornecidos corretamente")
void deveCriarObjetoPixValido() {
    // Arrange, Act, Assert
}
