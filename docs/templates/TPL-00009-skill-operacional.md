---
document_id: TPL-00009
primary_nature: Template
objective: Fornecer o molde de uma skill operacional portavel e autocontida.
scope: Metadados, gatilhos, procedimento, seguranca, evidencia e descoberta progressiva.
non_objectives: Nao criar skill de negocio, regra normativa ou permissao implicita.
owner: Plataforma de IA e Documentacao
status: Active
version: 1.0
date: 2026-09-10
last_reviewed: 2026-09-10
keywords: template, skill, runtime, procedimento
related_files: README.md, ../agents/skills/README.md
code_references: ../../.agents/skills/, ../../.claude/skills/
principal_statement: Skill instrui um procedimento repetivel e aponta para standards; nao copia fontes normativas nem amplia autoridade.
---

# Template — Operational Skill

Crie o mesmo núcleo semântico em cada runtime suportado e atualize o catálogo.

```markdown
---
name: {{nome-curto-em-kebab-case}}
description: {{quando usar}}; nao use quando {{nao-gatilho discriminante}}.
---

# {{Nome da skill}}

- Owner: {{owner}}
- Status: Active

## Objetivo

{{resultado verificavel do procedimento}}

## Gatilhos e não-gatilhos

- Use quando: {{condicoes}}
- Não use quando: {{condicoes}}

## Escopo e não-objetivos

- Escopo: {{artefatos/operacoes}}
- Não-objetivos: {{exclusoes}}

## Pré-condições

1. {{fonte, estado ou autorização necessária}}

## Procedimento

1. {{passo observavel}}
2. {{ferramenta ou fonte somente quando necessaria}}
3. {{validacao e iteracao}}

## Descoberta progressiva

- Fontes mínimas: {{paths/secoes}}
- Leituras condicionais: {{condicao → path/secao}}
- Não carregar por padrão: {{colecoes/recursos}}

## Limites de segurança

- {{operacoes vedadas e autorizacoes exigidas}}

## Entradas, saídas e evidências

- Entradas: {{dados necessários}}
- Saída: {{resultado}}
- Evidência: {{comandos, artefatos e estados}}

## Critério de conclusão

{{condicao terminal verificavel}}
```

Recursos `references/`, `scripts/` ou `assets/` entram somente quando uma condição
do workflow os exige. Script executável precisa de contrato, testes, segurança e
decisão de bootstrap próprios no projeto de destino.

