---
document_id: CONTRACTS-INDEX
primary_nature: Contexto
objective: Catalogar interfaces canonicas e versionadas entre produtores e consumidores.
scope: APIs, eventos, schemas, formatos e politicas de compatibilidade.
non_objectives: Nao substituir requirement, ADR ou implementacao.
owner: Arquitetura e owners das interfaces
status: Active
version: 1.0
date: 2026-09-10
last_reviewed: 2026-09-10
keywords: contratos, api, eventos, schema, compatibilidade
related_files: ../requirements/README.md, ../adrs/README.md
code_references: N/A - nenhum contrato ativo no baseline.
principal_statement: Interface compartilhada possui uma fonte canonica versionada, completa e ligada a produtores e consumidores.
---

# Contratos

## Contrato da coleção

- Conteúdo aceito: OpenAPI, AsyncAPI, JSON Schema, protobuf ou formato equivalente,
  mais política de versão e compatibilidade.
- Nomes: `<boundary>-<interface>-vN.<ext>` e documento auxiliar em kebab-case quando
  necessário.
- Estados: `Draft`, `Active`, `Deprecated`, `Retired`.
- Critério de granularidade: uma interface versionável e seus consumidores por
  artefato canônico.

Requirement, ADR e plano registram a versão e as operações/mensagens exatas. Contrato
ausente ou incompleto mantém a implementação de produtores e consumidores bloqueada.

## Índice

Nenhum contrato ativo.

