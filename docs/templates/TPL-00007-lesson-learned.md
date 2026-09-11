---
document_id: TPL-00007
primary_nature: Template
objective: Fornecer o molde de uma licao generica e preventiva.
scope: Sintoma, causa estrutural, solucao, prevencao e aplicabilidade.
non_objectives: Nao expor segredo, dado real ou detalhe sem valor transferivel.
owner: Engenharia e Qualidade
status: Active
version: 1.0
date: 2026-09-10
last_reviewed: 2026-09-10
keywords: template, lesson-learned, causa, prevencao
related_files: README.md, ../lessons_learned/README.md
code_references: N/A - template documental.
principal_statement: A licao preserva o mecanismo da falha e a prevencao reutilizavel, nao a narrativa privada do incidente.
---

# Template — Lesson Learned

```markdown
---
document_id: LL-AREA-NNNNN
primary_nature: Historico
objective: Prevenir {{classe de falha}}.
scope: {{condicoes em que se aplica}}
non_objectives: {{casos excluidos}}
owner: {{owner}}
status: Draft
version: 0.1
date: YYYY-MM-DD
last_reviewed: YYYY-MM-DD
keywords: {{termos}}
related_files: {{standard/ADR/relatorio}}
code_references: {{paths genericos relevantes ou N/A}}
principal_statement: {{regra preventiva em uma frase}}
---

# LL-AREA-NNNNN — {{titulo}}

## Contexto sanitizado

{{situacao sem nomes privados, dados reais ou segredos}}

## Sintoma e impacto

{{comportamento observavel}}

## Causa estrutural

{{mecanismo, nao apenas evento superficial}}

## Solução aplicada

{{correcao e evidencia}}

## Regra preventiva

{{regra transferivel e verificavel}}

## Aplicabilidade e limites

- Aplica-se quando: {{condicoes}}
- Não se aplica quando: {{condicoes}}
- Fonte normativa a atualizar: {{standard/ADR ou N/A justificado}}
```

