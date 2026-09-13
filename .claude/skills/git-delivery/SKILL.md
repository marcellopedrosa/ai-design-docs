---
name: git-delivery
description: Prepara commit e publicacao Git governados quando o projeto adotou essa politica. Use para criar ou trocar branch, commitar ou publicar uma entrega; nao use para PR, merge, rebase, historico ou integracao.
---

# Git Delivery

- Owner: Arquitetura e Qualidade
- Status: Active, opt-in

## Objetivo e ativação

Aplicar a política local de entrega Git sem ampliar permissões. Use somente quando
o ADR-0000, os adaptadores e a automação do projeto registrarem explicitamente a
convenção de branch e mensagem, paths autorizados, gates, hook e publicação.

Sem essa adoção verificável, Git de escrita permanece `BLOCKED`.

## Procedimento

1. Confirme o `READY` vigente, paths autorizados e gates aplicáveis em `PASS`.
2. Confirme a branch, a mensagem e o hook conforme a política local; crie ou troque
   branch somente se isso estiver autorizado pela mesma política.
3. Instale ou verifique o hook versionado antes do commit.
4. Adicione somente os paths autorizados e execute o commit sem bypass de hook.
5. Antes da publicação, repita os gates definidos para entrega com branch, paths e
   referência ao `READY` explícitos.
6. Publique somente pelo comando e remote autorizados. Registre branch, mensagem,
   paths, SHA, comandos e resultados.

## Limites

- Não infira convenção, coordenada, remote, paths, gates ou autorização ausentes.
- Detached HEAD, hook ausente, convenção inválida, gate não aprovado ou autorização
  incompleta resultam em `BLOCKED`.
- Não abra PR, faça merge, rebase, reset, force-push, tag, alteração de remote,
  integração, release ou leitura de credenciais.
- O hook local não substitui proteção de servidor; rede e push ainda obedecem à
  política de autorização efetiva do ambiente.

## Evidência e portabilidade

Registre a política aplicada, branch, mensagem, paths, hook, comandos, SHA, gates e
resultado `PASS` ou `BLOCKED`. Para criar enforcement no destino, consulte o
[scaffold portátil](references/portable-commit-enforcement.md) e adapte-o à decisão
local antes de habilitar a skill.

## Critério de conclusão

Conclua somente com commit ou publicação autorizados, enforcement verificado, gates
exigidos em `PASS` e evidência reproduzível. Caso contrário, reporte `BLOCKED` sem
contornar controles.
