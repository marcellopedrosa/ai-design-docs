# Projeto

Esta pasta contém a documentação e os domínios dos projetos.

A árvore canônica e as regras de colocação estão em
`../corporate-presets/standards/documentation-structure-standard.md`. Consulte
esse documento antes de criar uma nova coleção documental.

- Documentação transversal fica em `docs/`.
- Documentação específica fica em `frontend/docs/` ou `backend/docs/`.
- Especificações do Spec Kit devem ser salvas em `<dominio>/docs/specs/`.
- Templates corporativos ficam em `../corporate-presets/` e o core fica em `../spec-kit/`.
- Standards aplicáveis devem ser registrados no plano da mudança.

Para classificar pedidos e reunir contexto, consulte `docs/agents/AgentOrchestrator.md`. Esse papel usa os processos do Spec Kit e não os substitui.

Skills corporativas disponíveis para este projeto ficam em `.agents/skills/` (Codex) e `.claude/skills/` (Claude Code). A fonte compartilhada está em `../corporate-presets/skills/`.

As skills operacionais disponíveis incluem `implementation-readiness`, `git-delivery`,
`security-gate`, `documentation-governance`, `document-number-sequence` e
`validate-relative-links`. `document-number-sequence` nunca se aplica a `docs/specs/`.
