---
document_id: DATA-GRID-STANDARD
primary_nature: Regra
objective: Definir grids e tabelas de dados previsíveis, acessíveis e escaláveis.
scope: Colunas, paginação, ordenação, filtros, seleção, estados, desempenho e testes.
non_objectives: Não escolher componente, biblioteca, protocolo, paginação ou estilo visual.
owner: Design e Engenharia de Frontend
status: Active
version: 1.0
date: 2026-09-11
last_reviewed: 2026-09-11
keywords: data-grid, tabela, paginacao, ordenacao, filtros, acessibilidade
related_files: README.md, component-design-standard.md, state-management-standard.md, api-client-standard.md, a11y-standard.md
code_references: N/A - componentes e endpoints pertencem ao projeto adotante.
principal_statement: Grid explicita a origem de ordenação, filtro e paginação e preserva semântica, estado e desempenho para o volume declarado.
---

# Data Grid Standard

## Regras

- Declarar se paginação, ordenação e filtros são client-side ou server-side; não
  misturar modelos de forma que a UI mostre uma visão incompleta como total.
- Usar chave estável por linha e ordenação determinística com desempate definido.
- Representar filtros, sort e página na URL quando a visão precisar ser
  compartilhável ou restaurável.
- Definir colunas, tipos, alinhamento, truncamento, expansão e conteúdo acessível;
  tabela semântica é preferida quando os dados forem tabulares.
- Cobrir loading inicial, atualização, vazio, sem resultado, erro, permissão negada
  e dados parciais.
- Seleção em massa declara escopo visível versus total, confirmação e resultado por
  item; ação destrutiva nunca usa seleção ambígua.
- Virtualização e infinite scroll só são ativados por volume medido e devem manter
  foco, leitura e navegação previsíveis.

## Evidência

Testar combinações de filtro/sort/página, limites, persistência na URL, teclado,
leitura por tecnologia assistiva, seleção e desempenho no volume-alvo.

## Change log

| Versão | Data | Mudança |
| --- | --- | --- |
| 1.0 | 2026-09-11 | Cria standard portátil de data grid. |
