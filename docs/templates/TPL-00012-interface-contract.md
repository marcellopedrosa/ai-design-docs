---
document_id: TPL-00012
primary_nature: Template
objective: Fornecer a checklist documental de um contrato versionado entre boundaries.
scope: Identidade, schema, operacoes, seguranca, erros, compatibilidade e consumers.
non_objectives: Nao escolher formato, gerar schema ou substituir requirement e ADR.
owner: Arquitetura e owners das interfaces
status: Active
version: 1.0
date: 2026-09-10
last_reviewed: 2026-09-10
keywords: template, contrato, api, evento, schema
related_files: README.md, ../contracts/README.md
code_references: N/A - template documental.
principal_statement: Toda interface compartilhada tem uma fonte canonica completa, versionada e ligada aos comportamentos que a exigem.
---

# Template — Interface Contract

Use esta ficha ao criar o contrato no formato adequado ao projeto, como OpenAPI,
AsyncAPI, JSON Schema ou protobuf.

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
related_files: {{PRD, REQ, UC e ADRs}}
code_references: {{producer, consumers e artefato canonico}}
principal_statement: A versao {{versao}} define {{capacidade da interface}}.
---

# Contrato — {{nome e versão}}

## Identidade

- Artefato canônico: {{path}}
- Formato/versão da especificação: {{formato}}
- Producer/owner: {{owner}}
- Consumers: {{lista}}

## Operações ou mensagens

| ID estável | Direção | Entrada | Sucesso | Erros | Segurança |
| --- | --- | --- | --- | --- | --- |
| {{operation/message ID}} | {{sentido}} | {{schema}} | {{schema}} | {{erros}} | {{regra}} |

## Semântica

- Idempotência: {{regra ou N/A}}
- Ordenação/concorrência: {{regra ou N/A}}
- Paginação/retry/timeout: {{regra ou N/A}}
- Dados sensíveis e retenção: {{regra ou N/A}}

## Compatibilidade e lifecycle

- Estratégia de versão: {{regra}}
- Compatibilidade: {{backward/forward e testes}}
- Deprecation/removal: {{janela e owner}}
- Migração/rollback: {{procedimento}}

## Rastreabilidade e validação

| Requirement/AC | Operação/mensagem | Producer test | Consumer test |
| --- | --- | --- | --- |
| REQ-NNNNN/AC-01 | {{ID}} | {{teste}} | {{teste}} |

## Approval

- Producer owner: Pending
- Consumer owners: Pending
- Security/privacy: {{Pending ou N/A justificado}}
```

