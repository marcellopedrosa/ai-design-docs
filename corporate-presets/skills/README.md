# Skills corporativas

Esta pasta é a fonte versionada das skills reutilizáveis da empresa. Cada skill vive em `<nome>/SKILL.md`, com frontmatter `name` e `description`; recursos opcionais ficam junto dela.

Skill disponível: [documentation-routing](documentation-routing/SKILL.md), para localizar o destino correto de documentos do projeto.

Também disponível: [validate-relative-links](validate-relative-links/SKILL.md), para detectar referências locais quebradas após mudanças documentais. Requer Node.js para executar o verificador e seus evals.

Para criar outra skill, comece pelo [molde](../templates/skills/SKILL.md.template), copie-o para `skills/<nome>/SKILL.md` e substitua todos os textos de exemplo. Use um nome curto em kebab-case, uma descrição que delimite quando a skill se aplica e apenas as instruções necessárias. Acrescente `references/`, `scripts/` ou `assets/` somente se o procedimento precisar deles. Skills corporativas complementam o Spec Kit; não reproduzem seus comandos nem instalam fases ou gates paralelos.

Para publicar as skills em um projeto que usa este harness, execute da raiz. No Windows com PowerShell:

```powershell
powershell -File scripts/install-corporate-skills.ps1 -ProjectRoot projeto -Agent Both
```

No Linux ou macOS com Bash:

```bash
bash scripts/install-corporate-skills.sh --project-root projeto --agent both
```

`Codex` instala em `<projeto>/.agents/skills/` e `Claude` em `<projeto>/.claude/skills/`. Ambos os instaladores preservam destinos existentes e exigem `-Force` (PowerShell) ou `--force` (Bash) para atualizar arquivos. A atualização copia os arquivos da fonte, mas não apaga recursos extras encontrados no destino.

Para outros projetos, passe o caminho do projeto em `-ProjectRoot` ou `--project-root`. Os instaladores não inicializam o Spec Kit e não criam etapas de desenvolvimento.
