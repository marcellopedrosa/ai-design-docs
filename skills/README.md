# Fonte Canônica das Skills do Harness

Este diretório é a **fonte canônica única** de todas as skills operacionais do AI Engineering Harness.

## Arquitetura de Skills

1. Toda definição e evolução de capacidade reside em `skills/<skill-name>/`.
2. Os diretórios nativos de runtime (`.agents/skills/` e `.claude/skills/`) são **artefatos de distribuição derivados**, sincronizados pela ferramenta determinística `tooling/adapters/sync-adapters.mjs`.
3. Cada skill é um **capability package** completo que inclui:
   - Descritor operacional (`SKILL.md`);
   - Declaração de contrato e permissões (`contract.yaml`);
   - Referências técnicas sob demanda (`references/`);
   - Fixtures de teste (`fixtures/`);
   - Conjunto de avaliação de comportamento (`evals/`).

## Skills Catalogadas

| Skill | Natureza | Classe de Risco | Contrato | Evals |
|---|---|---|---|---|
| [`governanca-documental`](governanca-documental/) | Governança | R1 | [`contract.yaml`](governanca-documental/contract.yaml) | Sim |
| [`implementation-readiness`](implementation-readiness/) | Hard Gate | R0 | [`contract.yaml`](implementation-readiness/contract.yaml) | Sim |
| [`quality-gate`](quality-gate/) | Gate Aggregator | R2 | [`contract.yaml`](quality-gate/contract.yaml) | Sim |
| [`security-gate`](security-gate/) | Subgate A3 AppSec | R2 | [`contract.yaml`](security-gate/contract.yaml) | Sim |
| [`git-delivery`](git-delivery/) | Ação com side effect | R3 | [`contract.yaml`](git-delivery/contract.yaml) | Sim |
| [`antigravity-permissions`](antigravity-permissions/) | Governança de workspace | R1 | [`contract.yaml`](antigravity-permissions/contract.yaml) | Sim |
