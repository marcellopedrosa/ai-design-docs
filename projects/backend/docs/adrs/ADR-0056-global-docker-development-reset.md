---
document_id: ADR-0056
primary_nature: Decisao
objective: Definir o contrato intencional do reset Docker global acionado pelo entrypoint DEV.
scope: reset-dev-bot.sh no daemon Docker local selecionado pelo usuário.
non_objectives: Executar a limpeza, acessar HML/PRD, alterar bootstrap do host ou o start incremental.
owner: Arquitetura, DevOps e Segurança
status: Accepted
version: 1.0
date: 2026-10-02
last_reviewed: 2026-10-02
keywords: docker, reset, desenvolvimento, destrutivo, host
related_files: ADR-0016-infrastructure-environment-provisioning.md, ../product/requirements/REQ-00045-local-development-host-bootstrap.md, ../delivery/plans/TP-00073-outbound-hmac-keyring-generator.md
code_references: ../../reset-dev-bot.sh, ../../infra/scripts/tests/reset-dev-bot-test.sh
principal_statement: O reset DEV explicitamente confirmado limpa recursos de todo o daemon Docker local, inclusive de outros projetos, sem reconstruir automaticamente a stack.
---

# ADR-0056 — Reset Docker global de desenvolvimento

## Contexto e aprovação

O `reset-dev-bot.sh` vigente limpa o daemon Docker inteiro. O ADR-0016 §7.2 e o
REQ-00045 v1.10 ainda descrevem o contrato anterior, limitado ao projeto e com
continuação pelo launcher. Em 2026-10-02, o Maintainer Humano escolheu conservar
expressamente a limpeza global, após confirmação de que ela alcança contêineres,
imagens e volumes de outros projetos. Esta decisão substitui somente o contrato
de reset do ADR-0016 §7.2 e os critérios de reset conflitantes do REQ-00045.

## Decisão

`reset-dev-bot.sh` é uma operação destrutiva separada do start. Após confirmação
literal interativa `LIMPAR`, remove todos os contêineres do daemon selecionado,
tenta remover suas imagens e executa `docker system prune -a -f` e
`docker volume prune -a -f`. Volumes em uso e imagens protegidas pelo daemon podem
permanecer; falhas de remoção de contêineres ou dos prunes terminam com erro.
O script não invoca `start-dev-bot.sh` nem manipula diretamente arquivos locais
de configuração ou segredos. O operador inicia a stack em passo posterior.

A operação só pode alcançar um daemon Docker local. Antes de qualquer mutação,
o script deve recusar `DOCKER_HOST` remoto e contexto Docker cujo endpoint não
seja o socket Unix local canônico. A confirmação deve informar que outros projetos
e dados de volumes não utilizados serão afetados. Testes usam um Docker falso e
nenhuma operação de reset real faz parte da validação de repositório.

## Alternativas e consequências

O reset limitado ao Compose do projeto foi rejeitado pelo Maintainer para este
entrypoint. A limpeza global pode interromper outros projetos e apagar dados em
volumes não utilizados. A operação exige confirmação humana a cada execução; não
há variável de ambiente para contornar o prompt. A escolha não autoriza executar
o reset neste workspace, em outro host ou em HML/PRD.

## Rastreabilidade

- Decisão humana: resposta explícita de 2026-10-02 para manter o comportamento
  atual, seguida de confirmação explícita do alcance global e da sucessão do
  contrato anterior.
- Requisito: REQ-00045 v1.11, AC-012 e AC-014 revisados.
- Plano e gates: TP-00073-T09; A1 hermético, A2 shell/documentação, A3 segurança.
- API Contract: N/A; não há API HTTP do backend envolvida.
