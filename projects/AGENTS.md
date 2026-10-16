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

## Instalação do Context 7

Para habilitar a consulta e a instalação de skills de projeto por meio do
Context7, execute:

```bash
npx ctx7 setup
```

## Skills que podem ser utilizadas em `projects/`

### Arquitetural / Projeto

- `npx skills add https://github.com/NetBT/big-bang --skill design-pattern`
- `npx ctx7@latest skills install /ciembor/agent-rules-books clean-architecture --universal`

### Codificação

- `npx ctx7@latest skills install /ajaywadhara/modern-java modern-java --universal`
- `npx ctx7@latest skills install /pymodel/react-frontend-skills nextjs --universal`

### Banco de Dados

- `npx ctx7@latest skills install /github/awesome-copilot postgresql-optimization --universal`
- `npx skills add github/awesome-copilot --skill sql-optimization`

### Testes

- `npx ctx7@latest skills install /anivar/jest-skill jest --universal`
- `npx skills add https://github.com/giuseppe-trisciuoglio/developer-kit --skill spring-boot-test-patterns`
- `npm init playwright@latest`
- `npx playwright test`
- `npx playwright test --ui`

### Segurança

- `npx ctx7@latest skills install /microsoft/hve-core owasp-top-10 --universal`
- `npx ctx7@latest skills install /schalkneethling/webdev-agent-skills frontend-security --universal`
- `npx ctx7@latest skills install /xirothedev/skills nextjs-secure-bff --universal`
- `npx ctx7@latest skills install /owasp/secure-agent-playbook web-security-review --universal`
