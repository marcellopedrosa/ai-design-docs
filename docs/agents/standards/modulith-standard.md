---
document_id: MODULITH-STANDARD
primary_nature: Regra
objective: Definir limites para sistemas que adotem arquitetura modular monolítica e, opcionalmente, Spring Modulith.
scope: Módulos, dependências, interfaces públicas, eventos, persistência e verificação estrutural.
non_objectives: Não impor monólito modular, Spring, linguagem, layout de pacotes ou boundaries específicos.
owner: Arquitetura e Engenharia de Backend
status: Active
version: 1.0
date: 2026-09-11
last_reviewed: 2026-09-11
keywords: modulith, modularidade, spring-modulith, boundaries, eventos
related_files: README.md, ddd-clean-architecture-standard.md, java-standard.md, backend-testing-standard.md
code_references: N/A - módulos e ferramentas dependem do projeto adotante.
principal_statement: Quando ativado, cada módulo possui responsabilidade e interface pública explícitas, sem ciclos ou acesso lateral aos seus internos.
---

# Modulith Standard

## Ativação

Condicional a ADR que escolha monólito modular. Regras específicas de Spring
Modulith aplicam-se somente se a stack o adotar.

## Regras

- Módulo representa capacidade coesa, possui owner, dependências permitidas e
  entrypoints documentados no manifesto.
- Código interno não é importado por outro módulo. Integração usa interface pública,
  port ou evento versionado.
- Grafo de dependências é acíclico e compatível com a direção arquitetural.
- Transação não atravessa módulo silenciosamente; consistência síncrona ou eventual
  e tratamento de falha devem ser explícitos.
- Evento entre módulos tem produtor, consumidor, schema, semântica, idempotência e
  comportamento de reprocessamento definidos.
- Persistência compartilhada não autoriza acesso direto às tabelas ou repositórios
  internos de outro módulo.
- Se Spring Modulith estiver ativo, declarar módulos e named interfaces na forma
  suportada pela versão escolhida e executar sua verificação estrutural.

## Evidência

Produzir grafo ou relatório de módulos, teste de ciclos e dependências proibidas,
testes de contrato/evento e lista de exceções aprovadas. Mudança de boundary exige
atualização do manifesto e decisão arquitetural quando material.

## Change log

| Versão | Data | Mudança |
| --- | --- | --- |
| 1.0 | 2026-09-11 | Extrai regras de modularidade sem assumir Spring ou domínio. |
