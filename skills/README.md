# Fonte Canônica das Skills do Harness v2

Este diretório é a **fonte canônica única** de todas as skills operacionais do AI Engineering Harness.

Anteriormente, as skills eram mantidas em caminhos de runtime paralelos (`.agents/skills/` e `.claude/skills/`), o que gerava risco de duplicação, drift e incompatibilidade entre runtimes.

Na arquitetura v2:
1. Toda edição e evolução ocorre aqui em `skills/<skill-name>/`.
2. Os diretórios `.agents/skills/` e `.claude/skills/` são **artefatos de distribuição derivados**, sincronizados pela ferramenta determinística `tooling/adapters/sync-adapters.mjs`.
3. Cada skill é um **capability package** que inclui seu descritor (`SKILL.md`), declaração de contrato e permissões (`contract.yaml`), referências sob demanda (`references/`), fixtures (`fixtures/`) e conjunto de evals (`evals/`).

## Skills Catalogadas

| Skill | Natureza | Classe de Risco | Contrato | Evals |
|---|---|---|---|---|
| [`governanca-documental`](governanca-documental/) | Governança | R1 | [`contract.yaml`](governanca-documental/contract.yaml) | Sim |
| [`implementation-readiness`](implementation-readiness/) | Hard Gate | R0 | [`contract.yaml`](implementation-readiness/contract.yaml) | Sim |
| [`quality-gate`](quality-gate/) | Gate Aggregator | R2 | [`contract.yaml`](quality-gate/contract.yaml) | Sim |
| [`security-gate`](security-gate/) | Subgate A3 AppSec | R2 | [`contract.yaml`](security-gate/contract.yaml) | Sim |
| [`git-delivery`](git-delivery/) | Ação com side effect | R3 | [`contract.yaml`](git-delivery/contract.yaml) | Sim |
| [`antigravity-permissions`](antigravity-permissions/) | Governança de workspace | R1 | [`contract.yaml`](antigravity-permissions/contract.yaml) | Sim |
