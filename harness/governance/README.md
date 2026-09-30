---
document_id: GOVERNANCE-INDEX
document_scope: harness
primary_nature: Contexto
objective: Orientar a descoberta progressiva das regras canônicas do harness.
scope: Agentes, standards, policies e decisões aceitas.
non_objectives: Repetir procedimentos ou documentação do produto.
owner: Arquitetura e Qualidade
status: Active
version: 1.0
date: 2026-09-30
last_reviewed: 2026-09-30
keywords: governance, agentes, standards, policies, decisões
related_files: ../README.md, agents/README.md, ../../docs/agents/standards/README.md, policies/README.md, decisions/README.md
code_references: ../../AGENTS.md, ../../CLAUDE.md, ../../GEMINI.md
principal_statement: A descoberta começa no bootstrap e expande somente para fontes aplicáveis, sem enfraquecer decisões aceitas.
---

# Governança do harness

## Ordem de autoridade

1. Políticas organizacionais gerenciadas de segurança e compliance.
2. ADRs aceitos.
3. Standards e settings globais versionados.
4. Adaptadores globais de runtime.
5. Instruções e configurações específicas do pacote.
6. Plano e critérios de aceite da tarefa.
7. Preferências locais do usuário.

Fonte inferior especializa seu escopo, mas não reduz segurança ou gates.

## Coleções

- [Agentes](agents/README.md): AgentOrchestrator inicial e GateEvaluator isolado.
- [Standards do projeto](../../docs/agents/standards/README.md): conteúdo local,
  descoberto pelo Registry e ativado por escopo e risco.
- [Policies](policies/README.md): ambiente, permissões, documentação e Git.
- [Decisões](decisions/README.md): ADR-0000, boundary  e ownership .

Para produto, consulte [docs/](../../docs/README.md). Para capabilities executáveis,
consulte [skills/](../skills/README.md) e
[tooling/](../tooling/README.md). Carregue somente os documentos necessários à
tarefa; PRD/requirement, planos e contratos de projeto ficam sob `docs/`.
O shim [GEMINI.md](../../GEMINI.md) e a regra
`.agents/rules/documentation-governance.md` são projeções de runtime;
o mapeamento Google está em [google-gemini.md](../adapters/google-gemini.md).
