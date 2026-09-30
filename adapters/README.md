# Adaptadores de Runtime do Harness

Este diretório gerencia a governança e alinhamento dos adaptadores de runtime de agentes (`AGENTS.md`, `CLAUDE.md`, `GEMINI.md`).

## Princípio Fundamental

Os adaptadores de runtime são camadas de tradução sintática e descoberta para cada ferramenta de IA.

Um adaptador **pode**:
- Usar sintaxe específica do runtime (ex: `@./AGENTS.md` para imports no Gemini);
- Especificar caminhos nativos de discovery e flags de sandbox;
- Orientar o desenvolvedor sobre como configurar o assistente.

Um adaptador **NÃO PODE**:
- Alterar ou enfraquecer a precedência de políticas;
- Reduzir limiares de gates (readiness ou quality);
- Alterar semântica de status (`PASS`, `FAIL`, `BLOCKED`, `READY`);
- Ampliar permissões de ambiente ou política de proteção da branch `main`;
- Conceder aprovação implícita por ausência de ferramenta.

## Conteúdo

- [`core-policy.md`](core-policy.md): Política neutra de referência compartilhada por todos os adaptadores.
- [`../AGENTS.md`](../AGENTS.md): Mapeamento para OpenAI Codex e baseline agnóstico.
- [`../CLAUDE.md`](../CLAUDE.md): Mapeamento para Anthropic Claude Code.
- [`../GEMINI.md`](../GEMINI.md): Mapeamento para Google Gemini CLI e Antigravity.
