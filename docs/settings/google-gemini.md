---
document_id: SETTINGS-GOOGLE-GEMINI
primary_nature: Regra
objective: Mapear a politica agnostica do harness para Google Gemini CLI e Google Antigravity.
scope: GEMINI.md, regras e skills de workspace, projetos, permissoes, sandbox e verificacao de descoberta nos runtimes Google.
non_objectives: Nao configurar runtime no host, versionar preferencias globais em ~/.gemini, armazenar project IDs ou duplicar skills interoperaveis.
owner: Plataforma de IA e DevOps
status: Active
version: 1.0
date: 2026-09-11
last_reviewed: 2026-09-11
keywords: google-gemini, gemini-cli, antigravity, GEMINI.md, rules, skills, permissions, sandbox
related_files: settings.md, ../ai/README.md, ../agents/skills/README.md, ../adrs/ADR-0000-governanca-do-harness-documental.md
code_references: ../../GEMINI.md, ../../.agents/rules/documentation-governance.md, ../../.agents/skills/
principal_statement: Google Gemini e Antigravity reutilizam a politica e as skills do harness por caminhos nativos, sem transformar configuracao pessoal em fonte versionada.
---

# Mapeamento do Google Gemini e Antigravity

## Superfícies e paths

| Superfície | Mecanismo oficial | Baseline do harness |
| --- | --- | --- |
| Gemini CLI | Contexto hierárquico em `GEMINI.md` e import `@file`. | `GEMINI.md` raiz importa `AGENTS.md`; um adotante cria o mesmo par em pacote somente quando existir especialização local. |
| Google Antigravity | Regras de workspace em `.agents/rules/`. | `.agents/rules/documentation-governance.md` importa `AGENTS.md` e deve ser marcada `Always On` no Project adotante. |
| Skills dos dois runtimes | Skills de workspace em `.agents/skills/`; Gemini CLI também aceita `.gemini/skills/`. | Reutilizar somente `.agents/skills/`, sem terceira cópia. |
| Configuração global | `~/.gemini/GEMINI.md` e configurações em `~/.gemini/`. | Pessoal, externa ao Git e subordinada à política do projeto. |

## Baseline de segurança

- No Antigravity, habilite `Terminal Sandbox Mode` e use `Proceed in Sandbox` para
  comandos seguros; comandos fora do sandbox continuam sujeitos a revisão.
- Mantenha `Agent Non-Workspace File Access` desabilitado ou sob aprovação
  explícita. Não use os presets `Full machine` ou `Turbo mode` como baseline.
- Rede e atuação web permanecem em `Ask` salvo allowlist explícita do projeto.
- A precedência de permissões é `Deny > Ask > Allow`. Evite `Ask command(*)` quando
  houver allows específicos, pois a regra mais ampla prevalece.
- Projects podem conter múltiplas pastas; cada pasta autorizada, seus settings e
  suas regras devem ser verificados sem presumir propagação entre repositórios.

Settings e permissões do Project são estado operacional do Antigravity. O harness
não inventa arquivo ou schema versionado para preferências que as fontes oficiais
apresentam como configuração da aplicação.

## Verificação após adoção

### Gemini CLI

1. Em sessão nova, use `/memory list` e `/memory show` para confirmar o
   `GEMINI.md` raiz e as especializações aplicáveis.
2. Use `/skills list` para confirmar as skills vindas de `.agents/skills/`.
3. Após uma mudança, use `/memory reload` e `/skills reload`.

### Google Antigravity

1. Confirme as pastas do Project.
2. Confirme `documentation-governance.md` como regra de workspace `Always On`.
3. Confirme a descoberta das skills em `.agents/skills/`.
4. Revise sandbox, acesso fora do workspace e permissões efetivas.
5. Teste a raiz e um pacote representativo em conversa nova.

Sem essa observação, reporte `configuração versionada presente / runtime não
verificado`.

## Fontes oficiais

- [Antigravity Agent Settings](https://antigravity.google/docs/agent-settings/)
- [Antigravity Rules](https://antigravity.google/docs/rules-workflows)
- [Antigravity Skills](https://antigravity.google/docs/skills/)
- [Antigravity Permissions](https://antigravity.google/docs/permissions/)
- [Antigravity Sandbox](https://antigravity.google/docs/sandbox/)
- [Antigravity Projects](https://antigravity.google/docs/projects/)
- [Gemini CLI project context](https://geminicli.com/docs/cli/gemini-md/)
- [Gemini CLI Agent Skills](https://geminicli.com/docs/cli/skills/)

## Change log

| Versão | Data | Mudança |
| --- | --- | --- |
| 1.0 | 2026-09-11 | Adiciona o mapeamento portátil dos dois runtimes Google sem duplicar política ou skills. |
