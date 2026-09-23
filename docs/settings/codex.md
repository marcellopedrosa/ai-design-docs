---
document_id: SETTINGS-CODEX
primary_nature: Regra
objective: Mapear a politica agnostica do harness para descoberta e adaptadores versionados do Codex.
scope: AGENTS.md raiz e locais, inicio de sessao, precedencia e catalogo de skills Codex do projeto adotante.
non_objectives: Nao duplicar ADRs, standards, requisitos ou preferencias pessoais de CODEX_HOME.
owner: Plataforma de IA e DevOps
status: Active
date: 2026-09-13
version: 1.0
keywords: codex, AGENTS.md, descoberta, precedencia, skills, quality-metrics, git, push
related_files: settings.md, ../ai/README.md, ../agents/skills/README.md
code_references: ../../AGENTS.md, ../../.agents/skills/governanca-documental/SKILL.md, ../../.agents/skills/implementation-readiness/SKILL.md, ../../.agents/skills/quality-gate/SKILL.md
principal_statement: O Codex compoe adaptadores progressivos e so prepara ou publica entrega Git quando a politica local, os hooks e os gates estiverem ativos.
---

# Mapeamento do Codex

## Configuracao efetiva

- O adaptador global versionado e `AGENTS.md` na raiz do projeto adotante.
- Adaptadores locais em pacotes ou subarvores devem existir apenas quando houver
  especializacao real e devem apontar para a politica global.
- Skills pessoais permanecem fora do projeto. Skills compartilhadas do harness usam
  `.agents/skills/<nome>/SKILL.md`.
- A skill `governanca-documental` executa a validacao agregada; `implementation-readiness`
  bloqueia handoff executavel sem fontes e DoD prontos; `quality-gate` orquestra
  Teste x QA quando software for alterado; `git-delivery` segue a politica local
  de integracao e protecao da branch principal.

## Baseline versionado e configuracao pessoal

- O harness publica `AGENTS.md` como nome canonico. Fallbacks, perfis e overrides
  pessoais de Codex pertencem ao ambiente do operador e nao sao fonte normativa do
  projeto.
- O projeto adotante deve medir a cadeia de adaptadores efetivamente carregada
  sempre que alterar `AGENTS.md` raiz ou local.
- Segredos, tokens, perfis pessoais e configuracoes fora do workspace nao devem ser
  lidos, copiados ou versionados.

## Precedencia e validacao

Aplicam-se a precedencia e a matriz de autonomia de `settings.md`. Mudanca de
adaptador deve reexecutar o validador documental local e confirmar, em sessao nova,
quais arquivos foram carregados pelo runtime.

A permissao Git do runtime deve representar a politica local em
[`git-delivery.md`](git-delivery.md): trabalho em branches separadas e integracao
por PR, merge, rebase ou push sao permitidos conforme os gates. Escrita direta e
force-push na branch principal sao proibidos; credenciais nao podem ser acessadas.

## Change log

| Versao | Data | Mudanca |
| --- | --- | --- |
| 1.0 | 2026-09-13 | Adiciona mapeamento portavel do Codex para o harness agnostico. |
