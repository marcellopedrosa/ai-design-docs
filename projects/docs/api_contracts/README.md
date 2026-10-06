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
related_files: ../requirements/README.md
code_references: projects/backend, projects/frontend, projects/website e consumidores documentados nos metadados de cada contrato.
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

> [!NOTE] Distinção entre `projects/docs/api_contracts/` e `.agents/contracts/`
> `projects/docs/api_contracts/` cataloga as interfaces canônicas e versionadas do produto final. Os schemas formais que regem o próprio harness de IA residem nos contratos dos runtimes em `projects/.agents/contracts/` e `projects/.claude/contracts/`.

## Índice

- [billing-super-admin-decisions-v1.openapi.yaml](billing-super-admin-decisions-v1.openapi.yaml)
- [billing-usage-v1.openapi.yaml](billing-usage-v1.openapi.yaml)
- [billing-v1.openapi.yaml](billing-v1.openapi.yaml)
- [certificate-v1.openapi.yaml](certificate-v1.openapi.yaml)
- [client-v1.openapi.yaml](client-v1.openapi.yaml)
- [commercial-contacts-v1.openapi.yaml](commercial-contacts-v1.openapi.yaml)
- [commercial-v1.openapi.yaml](commercial-v1.openapi.yaml)
- [conversation-audit-retention-policy-v1.openapi.yaml](conversation-audit-retention-policy-v1.openapi.yaml)
- [conversation-audit-v1.openapi.yaml](conversation-audit-v1.openapi.yaml)
- [dashboard-fiscal-overview-v1.openapi.yaml](dashboard-fiscal-overview-v1.openapi.yaml)
- [dashboard-v1.openapi.yaml](dashboard-v1.openapi.yaml)
- [fiscal-v1.openapi.yaml](fiscal-v1.openapi.yaml)
- [llm-v1.openapi.yaml](llm-v1.openapi.yaml)
- [notification-v1.openapi.yaml](notification-v1.openapi.yaml)
- [observability-v1.openapi.yaml](observability-v1.openapi.yaml)
- [omnichannel-v1.openapi.yaml](omnichannel-v1.openapi.yaml)
- [payment-provider-console-v1.openapi.yaml](payment-provider-console-v1.openapi.yaml)
- [tenant-v1.openapi.yaml](tenant-v1.openapi.yaml)
