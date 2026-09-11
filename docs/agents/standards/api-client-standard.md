---
document_id: API-CLIENT-STANDARD
primary_nature: Regra
objective: Governar contratos HTTP e clientes de API de forma portável e contract-first.
scope: Especificação, geração ou implementação de clientes, autenticação, erros, compatibilidade e testes de paridade.
non_objectives: Não escolher protocolo, gerador, framework, autenticação ou convenção de URL do projeto.
owner: Arquitetura e Engenharia de Integração
status: Active
version: 1.0
date: 2026-09-11
last_reviewed: 2026-09-11
keywords: api, http, openapi, cliente, contrato, compatibilidade
related_files: README.md, development-standard.md, security-standard.md, software-quality-standard.md
code_references: N/A - contrato e consumidores devem ser registrados pelo projeto adotante.
principal_statement: Produtores e consumidores implementam a mesma interface canônica versionada e demonstram paridade positiva e negativa.
---

# API Client Standard

## Ativação

Condicional à criação, alteração ou consumo de API HTTP. O projeto deve declarar a
fonte canônica, preferencialmente uma especificação OpenAPI versionada.

## Contrato mínimo

- operation ID estável, método, path, parâmetros e regras de serialização;
- schema de request e response, exemplos não sensíveis e limites;
- respostas de sucesso e erro, incluindo formato problem-details quando adotado;
- autenticação, autorização, escopos e efeitos de isolamento;
- idempotência, paginação, ordenação, filtros, concorrência e rate limits quando
  aplicáveis;
- versão, política de compatibilidade e procedimento de depreciação.

## Regras do cliente

- Não inventar endpoint, campo, enum, role ou semântica ausente do contrato.
- Centralizar base URL, autenticação, headers, serialização e mapeamento de erros;
  feature code não duplica transporte.
- Aplicar timeout e cancelamento. Retry só ocorre para operações comprovadamente
  seguras, com limite e backoff; mutação exige idempotência explícita.
- Não expor token, segredo, payload sensível ou detalhe interno em logs e erros.
- Cliente gerado e manual seguem o mesmo contrato; customização não altera a
  interface sem atualizar sua fonte.

## Evidência

Testar produtor e consumidor contra a mesma versão, requests válidos e inválidos,
status documentados, autenticação/autorização, serialização e drift. Mudança
incompatível exige versão e plano de migração próprios.

## Change log

| Versão | Data | Mudança |
| --- | --- | --- |
| 1.0 | 2026-09-11 | Extrai regras contract-first sem paths ou stack de origem. |
