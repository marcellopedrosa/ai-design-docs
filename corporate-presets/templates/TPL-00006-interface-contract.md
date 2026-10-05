---
document_id: TPL-00006
primary_nature: Template
objective: Orientar a documentação de um contrato de interface com referências normativas aplicáveis.
scope: Identidade, formato canônico, operações, schemas, segurança, erros, compatibilidade e consumidores.
non_objectives: Não impor HTTP a interfaces não HTTP, gerar o schema executável ou substituir a especificação do Spec Kit e ADRs.
owner: Arquitetura e owners das interfaces
status: Active
version: 1.1
date: 2026-09-10
last_reviewed: 2026-09-10
keywords: template, contrato, api, evento, schema
related_files: README.md, ../../projects/docs/api_contracts/README.md
code_references: N/A - template documental.
principal_statement: Toda interface compartilhada tem uma fonte canonica completa, versionada e ligada aos comportamentos que a exigem.
---

# Template — Interface Contract

No projeto consumidor, crie o artefato canônico em `projects/docs/api_contracts/` para
interfaces transversais ou em `projects/<domínio>/docs/api_contracts/` para interfaces
locais. Atualize o `README.md` da coleção na mesma mudança.

Esta ficha acompanha o contrato formal escolhido pelo projeto. Para uma API HTTP,
use uma especificação OpenAPI versionada como fonte técnica canônica quando essa
for a convenção adotada. Para eventos ou outros protocolos, registre o formato
pertinente, como AsyncAPI, JSON Schema ou protobuf. A ficha não substitui esse
artefato nem cria uma etapa adicional no ciclo do Spec Kit.

## Referências para APIs HTTP

Não existe uma RFC única que defina toda a especificação de contratos de API.
Selecione as referências conforme o protocolo e as decisões do projeto:

| Referência | Aplicação no contrato |
| --- | --- |
| [RFC 9110 — HTTP Semantics](https://www.rfc-editor.org/rfc/rfc9110.html) | Métodos, segurança e idempotência dos métodos, códigos de status, headers e negociação de conteúdo. |
| [OpenAPI Specification](https://spec.openapis.org/oas/) | Descrição formal de operações HTTP, parâmetros, requests, responses, schemas e segurança; registre a versão adotada. OpenAPI não é uma RFC. |
| [RFC 9457 — Problem Details for HTTP APIs](https://www.rfc-editor.org/rfc/rfc9457.html) | Formato de erros `application/problem+json` quando adotado; substitui a RFC 7807. |
| [RFC 8259 — JSON](https://www.rfc-editor.org/rfc/rfc8259.html) | Sintaxe e interoperabilidade quando o payload usa JSON. |
| [JSON Schema Draft 2020-12](https://json-schema.org/draft/2020-12) | Validação de payloads quando o projeto usa JSON Schema; registre o dialeto efetivo. Não é RFC. |
| [RFC 9745 — Deprecation](https://www.rfc-editor.org/rfc/rfc9745.html) e [RFC 8594 — Sunset](https://www.rfc-editor.org/rfc/rfc8594.html) | Sinalização HTTP opcional de descontinuação e encerramento de recursos. |

Não marque todas as referências como obrigatórias por padrão. Indique no
contrato quais se aplicam e quais decisões locais completam as lacunas,
especialmente autenticação, paginação, limites e política de versionamento.

```markdown
---
document_id: CONTRACT-NNNNN
primary_nature: Contexto
objective: Definir a interface {{nome}} entre {{producer}} e {{consumers}}.
scope: {{operacoes/mensagens e versao}}
non_objectives: {{interfaces excluidas}}
owner: {{owner}}
status: Draft
version: {{versao do contrato}}
date: YYYY-MM-DD
last_reviewed: YYYY-MM-DD
keywords: {{termos}}
related_files: {{especificação do Spec Kit, PRD, ADRs e contratos relacionados}}
code_references: {{producer, consumers e artefato canonico}}
principal_statement: A versao {{versao}} define {{capacidade da interface}}.
---

# Contrato — {{nome e versão}}

## Identidade

- Artefato canônico: {{path}}
- Protocolo e formato/versão da especificação: {{ex.: HTTP + OpenAPI 3.x}}
- Producer/owner: {{owner}}
- Consumers: {{lista}}
- Normas aplicáveis: {{RFCs, especificação do formato e versões; N/A justificado}}
- Ambiente e base URI ou canal: {{endereços sem segredos; N/A quando não aplicável}}

## Operações ou mensagens

| ID estável | Método/canal e path | Entrada | Sucesso e status | Erros e status | Segurança |
| --- | --- | --- | --- | --- | --- |
| {{operation/message ID}} | {{método e URI ou tópico}} | {{parâmetros, media type e schema}} | {{status, media type e schema}} | {{status, formato e schema}} | {{mecanismo e autorização}} |

## Semântica

- Métodos e códigos HTTP: {{justificativa conforme RFC 9110 ou N/A}}
- Headers e negociação de conteúdo: {{Content-Type, Accept e outros aplicáveis}}
- Idempotência: {{semântica do método e política para repetição/retry ou N/A}}
- Ordenação/concorrência: {{regra ou N/A}}
- Paginação/retry/timeout: {{regra ou N/A}}
- Erros: {{RFC 9457 com tipos de problema e media type, outro formato aprovado ou N/A}}
- Autenticação e autorização: {{esquema, escopos e regras por operação; sem credenciais}}
- Dados sensíveis e retenção: {{regra ou N/A}}

## Compatibilidade e lifecycle

- Estratégia de versão: {{regra}}
- Compatibilidade: {{backward/forward e testes}}
- Deprecation/removal: {{janela e owner}}
- Sinalização HTTP: {{RFC 9745 e/ou RFC 8594, quando adotadas; N/A caso contrário}}
- Migração/rollback: {{procedimento}}

## Rastreabilidade e validação

| Spec Kit / critério de aceite | Operação/mensagem | Teste do produtor | Teste do consumidor |
| --- | --- | --- | --- |
| {{spec/critério}} | {{ID}} | {{teste}} | {{teste}} |

Valide também o artefato canônico com ferramenta compatível com sua versão,
além de testar respostas positivas e negativas, autorização e compatibilidade
com consumidores existentes.

## Approval

- Producer owner: Pending
- Consumer owners: Pending
- Security/privacy: {{Pending ou N/A justificado}}
```
