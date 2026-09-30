# Instruções do harness para Google Gemini

@./AGENTS.md

## Harness Project Lifecycle

- novo projeto: `node harness/tooling/harness.mjs onboard`;
- projeto legado: `node harness/tooling/harness.mjs onboard --source "<path>"`;
- clone configurado: `node harness/tooling/harness.mjs bootstrap`.

## Harness Governance

As regras canônicas de comportamento, proibições, segurança e filesystem estão em
`harness/governance/`; consulte-as por meio do `AGENTS.md` e não duplique seu conteúdo neste shim.

Consulte `harness/adapters/google-gemini.md` para o mapeamento Gemini/Antigravity.
Permissões especiais só são ativadas quando a capability correspondente for
aplicável; não duplique a política neutra do harness neste shim.
