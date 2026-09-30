# Instruções globais do projeto para Claude Code

@AGENTS.md

## Harness Governance

As regras canônicas de comportamento, proibições, segurança e filesystem estão em
`harness/governance/`; consulte-as por meio do `AGENTS.md` e não duplique seu conteúdo neste shim.

Consulte `harness/adapters/claude-code.md` para o mapeamento deste runtime.
`.claude/skills/` é derivado de `harness/skills/`, não uma fonte canônica.
Se houver drift, execute `node harness/tooling/adapters/sync-adapters.mjs --check`
e sincronize somente após revisar o diff da fonte canônica.
