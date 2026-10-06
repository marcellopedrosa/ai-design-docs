---
document_id: "ONBOARD-LOCAL-DEVELOPMENT-HOST"
primary_nature: "Regra"
objective: "Preparar com segurança o acesso Docker do usuário de desenvolvimento antes de iniciar a stack local."
scope: "Linux local, Docker rootful já instalado, grupo docker, validação fresh-session, continuação allowlisted e preflight dos caminhos Docker DEV."
non_objectives: "Instalar/migrar Docker; alterar HML/PRD; executar backfill; remover volumes; usar endpoint remoto; modificar socket, ACL ou sudoers."
owner: "DevOps e Segurança"
status: "Active"
date: "2026-08-25"
version: "1.4"
keywords: "onboarding, bootstrap, docker, grupo, desenvolvimento-local"
related_files: "docs/product/requirements/REQ-00045-local-development-host-bootstrap.md, docs/delivery/plans/TP-00019-local-development-host-bootstrap.md, docs/onboarding/local-dns-development-setup.md"
code_references: "infra/scripts/bootstrap-development-host.sh, infra/scripts/lib/development-docker-access.sh, infra/scripts/health-check.sh, infra/keycloak/bootstrap/migrate-persisted-volume.sh, start-dev-bot.sh, start-dev-dns-bot.sh, start-dev-bot-exposed-ngrok.sh, stop-dev-bot.sh, reset-dev-bot.sh"
principal_statement: "Execute o bootstrap do host antes do primeiro Compose; no start incremental, conclua build e preflights antes de fechar a UI e substitua somente os componentes stateless após o início explícito do cutover."
last_reviewed: "2026-09-05"
---

# Bootstrap do host de desenvolvimento local

O grupo `docker` concede controle equivalente a root. Revise o usuário-alvo e o
modo antes de executar. O bootstrap não lê configuração da aplicação, não toca
containers/volumes e não instala nem migra Docker.

## 1. Pré-requisitos

- Linux com Docker Engine/Compose já instalado e daemon local saudável;
- socket rootful canônico `/var/run/docker.sock`, `root:docker`, modo `0660`;
- conta de desenvolvimento regular com UID igual ou superior a 1000;
- acesso administrativo para a preparação única do host;
- repositório sob ownership do usuário de desenvolvimento.

Docker remoto, rootless novo, socket symlink/inseguro ou migração Snap/Desktop não
são corrigidos automaticamente. Interrompa e abra um ciclo específico nesses
casos.

## 2. Inicialização única com continuação imediata

Da raiz do repositório, o fluxo canônico para a stack principal é:

```bash
sudo ./infra/scripts/bootstrap-development-host.sh \
  --developer-user "$(id -un)" \
  --docker-access rootful-group \
  --continue start-dev-bot
```

Exemplo:

```bash
sudo ./infra/scripts/bootstrap-development-host.sh --developer-user duoset --docker-access rootful-group --continue start-dev-bot
``` 

Para DNS local ou exposição controlada, substitua apenas o valor de `--continue`
por `start-dev-dns-bot` ou `start-dev-bot-exposed-ngrok`.

A mesma invocação:

1. valida host, usuário, daemon, Compose, grupo e socket;
2. inclui o usuário no grupo somente se necessário;
3. valida `docker info` em sessão nova com grupos atualizados;
4. inicia o entrypoint escolhido como o usuário, com ambiente administrativo
   descartado.

Para serializar execuções concorrentes, o bootstrap usa o lock
`/run/saas-development-host-bootstrap.lock`, criado por `root` com modo `0600`.
Ele não usa `/run/lock`: em Ubuntu/Debian esse diretório compartilhado normalmente
tem modo `1777`, adequado para locks de vários usuários, mas incompatível com a
validação sem corrida exigida por este bootstrap privilegiado.

Não existe comando corretivo depois dessa sequência. O shell/IDE/Codex que já
estava aberto não pode ter seus grupos alterados retroativamente; reabra-o uma
vez para que comandos futuros usem a nova associação. A stack iniciada pelo modo
`--continue` já usa a sessão renovada.

## 3. Preparar sem iniciar a stack

Para preparar o host e não executar qualquer entrypoint:

```bash
sudo ./infra/scripts/bootstrap-development-host.sh \
  --developer-user "$(id -un)" \
  --docker-access rootful-group
```

Depois, abra uma nova sessão antes de usar Docker diretamente. Essa variante é
útil para onboarding anterior à abertura da IDE.

## 4. Comportamentos fail-closed

O bootstrap termina sem Compose quando encontra:

- usuário root/system/inexistente ou diferente de `SUDO_USER`;
- endpoint Docker remoto ou socket não canônico;
- socket que seja symlink, não seja `root:docker` ou não tenha modo `0660`;
- daemon ou Compose indisponível;
- `/run` fora de `root:root` ou gravável por grupo/outros, ou lock que seja
  symlink, não regular, não pertença a `root:root` ou não tenha modo `0600`;
- falha ao persistir ou comprovar a associação em sessão nova.

Se a associação foi criada pela execução corrente e a última validação falhar,
o script tenta remover apenas essa associação. Não use `chmod 666`, `chown`/ACL no
socket, `sudo -E`, `sudo docker compose` nem regra sudoers como atalho.

## 5. Reexecução incremental sem interromper a stack atual

Uma nova execução de `./start-dev-bot.sh` separa a atualização em duas partes:

1. **Prepare:** constrói a imagem backend no modo host, mantém
   PostgreSQL/Redis/Keycloak existentes com `--no-recreate`, aguarda sua saúde e
   executa o verifier normal `keycloak-provisioning-init` sem reconciliação
   privilegiada implícita.
2. **Commit:** somente depois do Prepare verde, fecha o frontend, instala o
   keyring outbound, recria apenas o backend, comprova readiness local, recria o
   ngrok stateless e só então reabre o frontend após as provas de ativação.

Falha de build, serviço base ou verifier Keycloak acontece antes do gate e não
para os containers backend/frontend já ativos nem recria Redis. Drift de
privilégios Keycloak deve ser tratado pelo
[runbook da identidade de provisionamento](keycloak-provisioning-identity.md);
o start normal não define `KEYCLOAK_FORCE_RECONCILE=true`.

## 6. Reset Docker global

`./reset-dev-bot.sh` é uma operação separada do start e afeta todo o daemon
Docker local, inclusive contêineres, imagens e volumes não utilizados de outros
projetos. Revise o aviso do script e digite `LIMPAR` em um terminal somente
quando esse alcance for desejado. O reset não aceita endpoint remoto nem inicia
a stack. Para iniciar depois da limpeza, execute `./start-dev-bot.sh` em uma
etapa separada. A decisão vigente está no
[ADR-0056](../adrs/ADR-0056-global-docker-development-reset.md).

Este guia não autoriza executar a limpeza em ambiente compartilhado, HML ou PRD.
Os testes do repositório usam um Docker falso e não alteram o daemon real.

Depois do início do Commit, a aplicação local continua single-replica: pode haver
uma janela curta de indisponibilidade e qualquer falha mantém a UI fechada pelo
cleanup fail-closed. Este fluxo reduz interrupções evitáveis, mas não promete
blue/green ou rollback automático pós-commit.

Um warning Lettuce de reconexão imediatamente seguido do shutdown ordenado de
Tomcat, JPA e Hikari não caracteriza, isoladamente, timeout por ociosidade ou
falha do pool tenant. Correlacione o timestamp com o lifecycle dos containers. No
incidente de 2026-09-05, Compose recriou Redis e enviou `SIGTERM` ao backend; os
logs Hikari eram apenas o cleanup gracioso. O startup incremental corrigido não
usa mais `--force-recreate` em Redis, PostgreSQL ou Keycloak.

## 6. Validação e suporte

Após reabrir a sessão, estas verificações não expõem secrets:

```bash
id -nG
docker info
docker compose version
```

O resultado deve incluir o grupo `docker` e mostrar client/server/Compose. Se
Docker via Snap funcionar fora de ambiente restrito mas falhar dentro de sandbox,
não remova Snap nem migre volumes automaticamente; registre o conflito para um
plano de migração separado.

O health check e o recovery local de volume Keycloak reutilizam exatamente o
mesmo preflight e nunca elevam Docker. Se falharem, prepare o host primeiro e
repita a operação como o usuário de login. Publicação de imagens DockerHub é um
lifecycle separado e não faz parte da inicialização da stack DEV.

## 7. Change Log

| Version | Date | Owner | Change |
| --- | --- | --- | --- |
| 1.3 | 2026-09-05 | DevOps e Segurança | Documenta o preflight incremental não disruptivo, o boundary explícito de Commit, o cleanup fail-closed e o diagnóstico do shutdown externo observado durante a recriação Compose. |
| 1.2 | 2026-08-25 | DevOps e Segurança | Corrigido o falso bloqueio em hosts Ubuntu/Debian: lock privilegiado movido do `/run/lock` compartilhado para `/run`, com parent root-only e arquivo `0600`. |
| 1.1 | 2026-08-25 | DevOps e Segurança | Reconciliado o preflight compartilhado nos cinco entrypoints, health check e recovery Keycloak locais, sem fallback sudo tardio. |
| 1.0 | 2026-08-25 | DevOps e Segurança | Procedimento canônico anterior ao Compose, com continuação em sessão nova e sem receita hardcoded. |
