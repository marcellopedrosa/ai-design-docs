---
document_id: DDD-CLEAN-ARCHITECTURE-STANDARD
primary_nature: Regra
objective: Definir limites reutilizáveis para DDD e arquiteturas orientadas a dependências internas.
scope: Domínio, aplicação, ports, adapters, módulos, agregados, eventos e testes arquiteturais.
non_objectives: Não impor DDD, Clean Architecture, estrutura de pastas, framework ou granularidade de serviços.
owner: Arquitetura e Engenharia
status: Active
version: 1.0
date: 2026-09-11
last_reviewed: 2026-09-11
keywords: ddd, clean-architecture, boundaries, ports, adapters, dominio
related_files: README.md, development-standard.md, modulith-standard.md, api-client-standard.md
code_references: N/A - ativação e boundaries pertencem ao projeto adotante.
principal_statement: Quando ativado, decisões de domínio permanecem independentes de mecanismos externos e cruzam boundaries apenas por interfaces explícitas.
---

# DDD and Clean Architecture Standard

## Ativação

Condicional a uma decisão arquitetural aceita. Não use a nomenclatura como camada
decorativa em sistemas que não adotam o padrão.

## Regras

- Cada bounded context possui linguagem, invariantes, owner e interface explícitos.
- Dependências apontam de mecanismos externos para políticas internas; domínio não
  depende de UI, banco, transporte ou framework.
- Casos de uso coordenam fluxo e transação sem absorver regra pertencente ao
  domínio ou detalhe pertencente ao adapter.
- Ports representam necessidades estáveis; adapters traduzem protocolos e não
  vazam tipos de infraestrutura para o núcleo.
- Agregado define consistência e fronteira transacional. Acesso a seu estado ocorre
  por comportamento que preserva invariantes.
- Comunicação entre contexts usa contrato ou evento versionado, tradução explícita
  e política de compatibilidade; import interno cruzado é proibido.
- Eventos descrevem fatos concluídos e têm identidade, tempo, schema e tratamento
  de duplicidade definidos quando cruzam processo ou boundary.

## Evidência

Registrar mapa de boundaries, direção de dependências, interfaces públicas,
transações, contratos e testes arquiteturais que detectem ciclos e acessos
proibidos. Exceções exigem ADR e prazo de remoção quando temporárias.

## Change log

| Versão | Data | Mudança |
| --- | --- | --- |
| 1.0 | 2026-09-11 | Extrai regras de DDD e Clean Architecture sem domínio de origem. |
