# Instruções do harness para Claude

Este repositório usa as skills compartilhadas em `.agents/skills/` como fonte
operacional para o Claude. Consulte e aplique sempre a skill correspondente
antes de executar uma tarefa que se enquadre em sua descrição.

Skills corporativas disponíveis:

- `stone-documentation-routing`
- `stone-documentation-governance`
- `stone-document-number-sequence`
- `stone-implementation-readiness`
- `stone-git-delivery`
- `stone-security-gate`
- `stone-check-relative-links`

Use como fonte de instruções as regras gerais  em [`AGENTS.md`](AGENTS.md), e as regras do domínio devem ser consultadas no
`AGENTS.md` correspondente dentro de `projects/`.

Preserve o core protegido em `spec-kit/`. Skills corporativas complementam o
Spec Kit e não criam fases ou gates concorrentes.
