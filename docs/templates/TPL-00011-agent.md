---
document_id: TPL-00011
primary_nature: Template
objective: Fornecer o molde de um papel de agente especializado e auditavel.
scope: Responsabilidade, gatilhos, entradas, saidas, tools, limites e handoffs.
non_objectives: Nao criar persona decorativa, conceder permissao ou duplicar standard.
owner: Plataforma de IA e Arquitetura
status: Active
version: 1.0
date: 2026-09-10
last_reviewed: 2026-09-10
keywords: template, agent, role, handoff
related_files: README.md, ../agents/README.md
code_references: N/A - template documental.
principal_statement: Agente especializado existe somente quando responsabilidade e handoff independentes justificam um papel proprio.
---

# Template — Agent

Crie em `docs/agents/<AGENT_FILE_STEM>.md` e atualize o `README.md` de agentes na
mesma mudança.

```markdown
---
document_id: AGENT-{{NAME}}
primary_nature: Regra
objective: {{responsabilidade unica}}
scope: {{dominio, paths e decisoes}}
non_objectives: {{limites e outros papeis}}
owner: {{owner}}
status: Draft
version: 0.1
date: YYYY-MM-DD
last_reviewed: YYYY-MM-DD
keywords: {{gatilhos de descoberta}}
related_files: {{standards, skills e agentes relacionados}}
code_references: {{paths governados ou N/A}}
principal_statement: O agente {{responsabilidade central}}.
---

# {{AgentName}}

## Responsabilidade e gatilhos

- Responsabilidade: {{resultado}}
- Use quando: {{condicoes}}
- Não use quando: {{condicoes}}

## Entradas

- {{fontes, estados e approvals necessários}}

## Procedimento

1. {{passo}}

## Tools e permissões

| Tool/capacidade | Uso | Limite/autorização |
| --- | --- | --- |
| {{tool}} | {{uso}} | {{limite}} |

## Standards aplicáveis

- {{link direto somente para standard consumido}}

## Saídas e evidências

- Saída: {{artefato/decisão}}
- Evidência: {{comando, link, estado}}

## Limites e escalonamento

- {{decisoes proibidas, dados vedados e owner a acionar}}

## Handoffs

| De | Para | Condição | Conteúdo |
| --- | --- | --- | --- |
| {{papel}} | {{papel}} | {{gate}} | {{artefatos/versoes/paths}} |

## Critério de conclusão

{{condicao terminal verificavel}}
```

