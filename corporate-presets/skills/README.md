# Skills corporativas

Esta pasta é a fonte versionada das skills reutilizáveis da empresa. Cada skill vive em `<nome>/SKILL.md`, com frontmatter `name` e `description`; recursos opcionais ficam junto dela.

Skills disponíveis: [documentation-routing](documentation-routing/SKILL.md), [documentation-governance](documentation-governance/SKILL.md), [document-number-sequence](document-number-sequence/SKILL.md), [implementation-readiness](implementation-readiness/SKILL.md), [git-delivery](git-delivery/SKILL.md), [security-gate](security-gate/SKILL.md) e [validate-relative-links](validate-relative-links/SKILL.md).

Esta pasta é a fonte canônica. As skills são projetadas para `projects/.agents/skills/`
e `projects/.claude/skills/` pelos instaladores ou pela sincronização do projeto.

Também disponível: [validate-relative-links](validate-relative-links/SKILL.md), para detectar referências locais quebradas após mudanças documentais. Requer Node.js para executar o verificador e seus evals.

Para criar outra skill, comece pelo [molde](../templates/skills/SKILL.md.template), copie-o para `skills/<nome>/SKILL.md` e substitua todos os textos de exemplo. Use um nome curto em kebab-case, uma descrição que delimite quando a skill se aplica e apenas as instruções necessárias. Acrescente `references/`, `scripts/` ou `assets/` somente se o procedimento precisar deles. Skills corporativas complementam o Spec Kit; não reproduzem seus comandos nem instalam fases ou gates paralelos.

## Referências obrigatórias para criação

Ao criar ou revisar uma skill, use explicitamente estas referências oficiais:

1. **Referência principal — Claude Managed Agents:** [Claude Managed Agents overview](https://platform.claude.com/docs/en/managed-agents/overview)
2. **Referência complementar — OpenAI Skills:** [OpenAI Skills](https://developers.openai.com/api/docs/guides/tools-skills)

A referência principal deve orientar a modelagem da skill como capacidade de um
agente, incluindo contexto, ferramentas, ambiente e sessão. A referência da
OpenAI deve ser usada como complemento para validar descoberta, empacotamento,
recursos auxiliares e compatibilidade com agentes OpenAI/Codex. Quando houver
diferença entre plataformas, documente a adaptação na própria skill sem alterar
o contrato canônico `SKILL.md`.

Para publicar as skills em um projeto que usa este harness, execute da raiz. No Windows com PowerShell:

```powershell
powershell -File scripts/install-corporate-skills.ps1 -ProjectRoot projects -Agent Both
```

No Linux ou macOS com Bash:

```bash
bash scripts/install-corporate-skills.sh --project-root projects --agent both
```

`Codex` instala em `<projects>/.agents/skills/` e `Claude` em `<projects>/.claude/skills/`. Ambos os instaladores preservam destinos existentes e exigem `-Force` (PowerShell) ou `--force` (Bash) para atualizar arquivos. A atualização copia os arquivos da fonte, mas não apaga recursos extras encontrados no destino.

Para outros projetos, passe o caminho do projeto em `-ProjectRoot` ou `--project-root`. Os instaladores não inicializam o Spec Kit e não criam etapas de desenvolvimento.
