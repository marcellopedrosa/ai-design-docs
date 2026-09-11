---
document_id: PROJECT-REPORTING-STANDARD
primary_nature: Regra
objective: Padronizar relatórios de progresso verificáveis sem substituir as fontes vigentes.
scope: Extração, cálculo, estado, blockers, decisões, riscos e handoff de relatórios.
non_objectives: Não definir roadmap, alterar status de fonte, estimar trabalho sem base ou criar percentual decorativo.
owner: Produto, Engenharia e Governança
status: Active
version: 1.0
date: 2026-09-11
last_reviewed: 2026-09-11
keywords: relatorio, progresso, evidencia, status, riscos, blockers
related_files: README.md, software-engineering-lifecycle.md, ../../templates/TPL-00008-report.md
code_references: N/A - fontes e métricas pertencem ao projeto adotante.
principal_statement: Relatório descreve um recorte temporal reproduzível a partir de fontes canônicas e nunca se torna a fonte do estado vigente.
---

# Project Reporting Standard

## Ativação

Use para status executivo, técnico, de sprint, programa ou release quando houver
necessidade real de comunicação recorrente.

## Regras

- Declarar data de corte, escopo, audiência, método e fontes com paths e versões.
- Derivar estado apenas de critérios observáveis; não transformar intenção,
  atividade iniciada ou texto produzido em conclusão.
- Se houver percentuais, publicar numerador, denominador, unidade, filtros e regra
  de arredondamento. Categorias devem ser mutuamente exclusivas e totalizar o
  universo declarado.
- Separar fato, inferência, risco, blocker, decisão pendente e recomendação.
- Para cada blocker, indicar impacto, owner, dependência e condição de retomada.
- Relacionar entregas a requisitos, task IDs e evidências de gate; marcar dado
  ausente como limitação, não o estimar silenciosamente.
- Gráficos e resumos devem ser matematicamente equivalentes à tabela-fonte.
- Publicar diferenças em relação ao período anterior sem reescrever o histórico.

## Evidência e conclusão

O handoff inclui consultas ou comandos usados, arquivos lidos, regras de cálculo,
checks de consistência e limitações. O relatório termina quando outra pessoa
consegue reproduzir seus totais e localizar cada fonte citada.

## Change log

| Versão | Data | Mudança |
| --- | --- | --- |
| 1.0 | 2026-09-11 | Cria standard portátil de reporting baseado em evidência. |
