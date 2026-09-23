---
name: git-delivery
description: Prepara e integra entregas Git governadas em branches de trabalho, preservando a protecao da branch principal.
---

# Git Delivery

- Owner: Arquitetura e Qualidade
- Status: Active, opt-in

## Objetivo e ativação

Aplicar a política local de entrega Git sem ampliar permissões. Para este projeto,
siga [`docs/settings/git-delivery.md`](../../../docs/settings/git-delivery.md):
trabalhe em branches separadas, integre mudanças aprovadas preservando o trabalho de
todos os participantes e mantenha a `main` protegida contra escrita direta e
force-push. A tarefa define o escopo; não exija uma lista fechada de paths para
aceitar artefatos novos necessários ao resultado.

## Procedimento

1. Confirme o escopo aprovado e os gates aplicáveis.
2. Crie ou use uma branch de trabalho separada da `main`.
3. Inclua todos os paths necessários ao resultado aprovado, inclusive artefatos
   novos, sem descartar mudanças de outros participantes.
4. Execute os gates aplicáveis antes de publicar ou integrar.
5. Publique a branch e use PR, merge, rebase ou o fluxo de integração do repositório.
6. Resolva conflitos considerando as intenções de todos os trabalhos; repita gates
   afetados e registre branch, paths, SHA, comandos e resultados.
7. Confirme que nenhuma operação escreveu diretamente na `main` ou fez force-push
   nela.

## Limites

- Não escreva diretamente na `main` nem faça force-push nela.
- Não descarte silenciosamente commits, arquivos ou mudanças válidas de branches
  envolvidas na integração.
- Uma falha de gate deve ser corrigida ou registrada com seu impacto; não remova
  conteúdo ou cobertura apenas para obter aprovação.
- Não leia nem exponha credenciais. Respeite as proteções do servidor e as
  permissões efetivas do ambiente.

## Evidência e portabilidade

Registre a política aplicada, branches, paths, comandos, SHA, gates, conflitos,
método de integração e resultado `PASS` ou `BLOCKED`. Para criar enforcement em
outro projeto, consulte o [scaffold portátil](references/portable-commit-enforcement.md)
e adapte-o à política local antes de habilitar a skill.

## Critério de conclusão

Conclua com gates exigidos em `PASS`, integração compatível com as proteções da
branch principal e evidência reproduzível. Caso contrário, reporte `BLOCKED` com a
causa e preserve as mudanças pendentes.
