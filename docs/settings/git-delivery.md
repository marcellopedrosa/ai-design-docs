---
document_id: SETTINGS-GIT-DELIVERY
primary_nature: Regra
objective: Definir a integracao de trabalhos Git independentes e proteger a branch principal.
scope: Branches, commits, publicacao, revisao e integracao de mudancas deste projeto.
non_objectives: Nao definir fluxo de produto, convencao universal de nomes ou acesso a credenciais.
owner: Mantenedores do projeto
status: Active
version: 1.0
date: 2026-09-23
last_reviewed: 2026-09-23
keywords: git, branches, multiagentes, integracao, main, pull-request
related_files: settings.md, ../adrs/ADR-0000-governanca-do-harness-documental.md, ../../AGENTS.md, ../../.agents/skills/git-delivery/SKILL.md
code_references: N/A - politica documental.
principal_statement: Trabalhos podem ser desenvolvidos e integrados em branches independentes; a branch principal main nao recebe escrita direta nem force-push.
---

# Politica de entrega Git

Neste repositório, a branch principal é `main`.

## Principios

- Novos arquivos, caminhos, funcionalidades e alteracoes sao permitidos quando
  estiverem dentro do objetivo da tarefa e respeitarem os requisitos aplicaveis.
- Agentes e colaboradores devem desenvolver trabalho independente em branches
  separadas para permitir execucao paralela.
- PR, push, merge, rebase, tags e alteracao de remote podem ser usados para publicar,
  revisar e integrar trabalho, respeitando os gates e as protecoes do repositorio.
- Nenhuma operacao pode escrever diretamente na `main` ou fazer force-push nela.
- Integracao nao deve descartar silenciosamente commits ou mudancas validas de
  qualquer branch participante.
- Segredos e credenciais nao devem ser lidos, incluidos em commits ou expostos.

## Fluxo de trabalho

1. Atualize a branch de trabalho a partir da referencia apropriada sem alterar a
   `main` diretamente.
2. Desenvolva e valide as mudancas na branch isolada, preservando os paths e
   resultados produzidos por outros participantes.
3. Publique a branch e abra PR quando o fluxo do repositorio usar revisao por PR.
4. Antes de integrar, resolva conflitos considerando as intencoes de todas as
   mudancas envolvidas e execute novamente os gates afetados.
5. Integre por merge, rebase ou mecanismo equivalente permitido pelas protecoes do
   repositorio. A integracao deve preservar autoria e historico conforme a
   convencao local.
6. Confirme que a `main` recebeu mudancas pela integracao aprovada e que os gates
   exigidos passaram.

## Paths, gates e convencoes

Esta politica nao fixa uma lista fechada de paths autorizados, convencao de branch,
mensagem de commit, hook ou comando de publicacao. A tarefa e os mantenedores podem
definir convencoes adicionais para uma entrega, mas essas convencoes nao devem
impedir artefatos novos ou mudancas necessarias. O conjunto de paths e determinado
pelo escopo aprovado e revisto no handoff.

Os gates aplicaveis devem ser executados antes da integracao. Quando um gate falhar,
corrija a causa dentro do escopo e repita-o; nao remova arquivos, requisitos ou
validacoes apenas para obter resultado verde. Se duas mudancas forem incompatíveis,
registre o conflito e preserve ambas ate que os owners decidam como reconciliar.

## Protecao da branch principal

- Nao faca commit diretamente na `main`.
- Nao faca force-push na `main` nem remova protecoes do servidor.
- Mudancas chegam a `main` por PR ou outro mecanismo de integracao aprovado pelo
  repositorio, com os gates exigidos.
- Branches de trabalho podem ser atualizadas, rebaseadas ou integradas conforme
  necessario, desde que o trabalho dos participantes seja preservado.

## Evidencia de entrega

O handoff registra branches envolvidas, paths alterados, comandos de validacao,
resultado dos gates, metodo e referencia de integracao, conflitos resolvidos e
pendencias. Operacoes Git seguem ainda as permissoes efetivas do ambiente e as
protecões configuradas no servidor.

## Change log

| Versao | Data | Mudanca |
| --- | --- | --- |
| 1.0 | 2026-09-23 | Define integracao multiagente e protecao da branch principal. |
