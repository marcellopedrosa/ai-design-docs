# Projetos

Esta pasta contém a documentação e os domínios dos projetos adotantes do
harness. As regras obrigatórias de execução ficam em [AGENTS.md](AGENTS.md).

## Sugestões de skills do Context7

### Instalação do Context7

```bash
npx ctx7 setup
```

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
