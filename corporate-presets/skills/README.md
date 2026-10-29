# Skills corporativas

Esta pasta é a fonte versionada das skills reutilizáveis da empresa. Cada skill vive em `<nome>/SKILL.md`, com frontmatter `name` e `description`; recursos opcionais ficam junto dela.

Skills disponíveis: [stone-documentation-routing](stone-documentation-routing/SKILL.md), [stone-documentation-governance](stone-documentation-governance/SKILL.md), [stone-document-number-sequence](stone-document-number-sequence/SKILL.md), [stone-implementation-readiness](stone-implementation-readiness/SKILL.md), [stone-git-delivery](stone-git-delivery/SKILL.md), [stone-security-gate](stone-security-gate/SKILL.md) e [stone-check-relative-links](stone-check-relative-links/SKILL.md).

Esta pasta é a fonte canônica. O harness disponibiliza as skills em
`.agents/skills/` na raiz do projeto.

[stone-check-relative-links](stone-check-relative-links/SKILL.md) detecta referências locais quebradas após mudanças documentais. Requer Node.js para executar o verificador e seus evals.

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

Codex, Claude e Gemini usam `<project>/.agents/skills/`. As skills
complementam o Spec Kit sem criar etapas de desenvolvimento paralelas.
