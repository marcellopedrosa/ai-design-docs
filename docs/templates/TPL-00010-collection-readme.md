---
document_id: TPL-00010
primary_nature: Template
objective: Fornecer o contrato minimo e o indice de uma colecao documental.
scope: README.md imediato de diretorio ativo em docs/.
non_objectives: Nao inventar owner, artefato ou ativar colecao sem necessidade.
owner: Arquitetura e Documentacao
status: Active
version: 1.0
date: 2026-09-10
last_reviewed: 2026-09-10
keywords: template, readme, colecao, indice
related_files: README.md, ../README.md
code_references: N/A - template documental.
principal_statement: Toda colecao ativa declara fronteira, convencao, estados e inventario individual completo.
---

# Template — Collection README

Crie como `README.md` da coleção e atualize o índice da coleção pai na mesma mudança.

```markdown
---
document_id: {{ID-INDEX}}
primary_nature: Contexto
objective: {{pergunta respondida pela colecao}}
scope: {{conteudo coberto}}
non_objectives: {{conteudo excluido}}
owner: {{owner real}}
status: Active
version: 1.0
date: YYYY-MM-DD
last_reviewed: YYYY-MM-DD
keywords: {{termos}}
related_files: {{indices e fontes}}
code_references: {{paths ou N/A justificado}}
principal_statement: {{afirmacao central}}
---

# {{Nome da coleção}}

## Contrato da coleção

- Conteúdo aceito: {{tipos permitidos}}.
- Nomes: {{convenção}}.
- Estados: {{estados permitidos}}.
- Critério de granularidade: {{gatilho semântico de revisão}}.

## Índice

Nenhum artefato ativo.
```

Substitua todos os marcadores por fatos. Owner desconhecido, natureza ambígua ou
destino incerto produz `Needs review` e não autoriza criação automática.

