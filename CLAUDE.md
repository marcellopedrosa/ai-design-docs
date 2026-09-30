# Instruções globais do projeto para Claude Code

@AGENTS.md

Consulte `harness/adapters/claude-code.md` para o mapeamento deste runtime.
`.claude/skills/` é derivado de `harness/skills/`, não uma fonte canônica.
Se houver drift, execute `node harness/tooling/adapters/sync-adapters.mjs --check`
e sincronize somente após revisar o diff da fonte canônica.
