---
document_id: TPL-00008
primary_nature: Template
objective: Fornecer o molde de um relatorio historico reproduzivel.
scope: Escopo, periodo, metodo, evidencia, achados, limitacoes e pendencias.
non_objectives: Nao transformar evidencia antiga em estado vigente ou approval.
owner: Qualidade e Documentacao
status: Active
version: 1.0
date: 2026-09-10
last_reviewed: 2026-09-10
keywords: template, report, evidencia, auditoria
related_files: README.md, ../reports/README.md
code_references: N/A - template documental.
principal_statement: Relatorio registra o que foi observado em um recorte temporal e explicita seus limites.
---

# Template — Report

```markdown
---
document_id: RPT-NNNNN
primary_nature: Historico
objective: Registrar {{avaliacao ou execucao}}.
scope: {{periodo, paths, modulos e ambiente}}
non_objectives: {{exclusoes}}
owner: {{owner}}
status: Draft
version: 0.1
date: YYYY-MM-DD
last_reviewed: YYYY-MM-DD
keywords: {{termos}}
related_files: {{planos, requisitos, ADRs e relatórios}}
code_references: {{paths e simbolos avaliados}}
principal_statement: {{resultado principal com recorte temporal}}
---

# RPT-NNNNN — {{titulo}}

## Resumo executivo

- Resultado: {{PASS, FAIL, BLOCKED ou informativo}}
- Período: {{inicio/fim}}
- Escopo: {{recorte}}

## Método

1. {{fonte, comando ou procedimento}}

## Evidências

| Controle | Comando/fonte | Resultado | Data |
| --- | --- | --- | --- |
| {{controle}} | {{evidencia reproduzivel}} | {{estado}} | YYYY-MM-DD |

## Achados

| ID | Severidade | Achado | Evidência | Owner |
| --- | --- | --- | --- | --- |
| F-01 | {{nivel}} | {{fato}} | {{fonte}} | {{owner}} |

## Limitações e skips

- {{controle nao executado, motivo e efeito}}

## Pendências

| Ação | Owner | Prazo/gatilho | Fonte canônica a atualizar |
| --- | --- | --- | --- |
| {{acao}} | {{owner}} | {{data/gatilho}} | {{path}} |
```

