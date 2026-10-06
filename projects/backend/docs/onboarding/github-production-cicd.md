---
document_id: "ONBOARD-GITHUB-PRODUCTION-CICD"
primary_nature: "Regra"
objective: "Orientar a preparação segura da VPS e do pipeline GitHub Actions para deploy incremental de produção."
scope: "Ruleset da main, Environment protegido, identidades SSH, bootstrap da VPS, workflow CI/CD, rede e gates de deploy."
non_objectives: "Não inicializar a aplicação em uma VPS vazia, criar segredos, substituir .env.production ou executar deploy por meio deste documento."
owner: "DevOps e Segurança"
status: "Active"
date: "2026-08-26"
version: "1.1"
last_reviewed: "2026-09-25"
keywords: "onboarding, GitHub-Actions, CI-CD, VPS, SSH, producao"
related_files: "docs/onboarding/production-vps-deployment.md, docs/adrs/ADR-0016-infrastructure-environment-provisioning.md"
code_references: "infra/scripts/bootstrap-production-vps.sh, infra/scripts/deploy-production.sh"
principal_statement: "O pipeline de produção separa identidades SSH, exige gates e aprovação de ambiente e executa deploy incremental somente em uma VPS previamente preparada."
---

# GitHub Actions e preparação da VPS de produção

Este guia configura o caminho completo `pull request aprovado -> merge em main -> gates -> aprovação do ambiente -> deploy incremental`. O workflow versionado é [harness.yml](../../); ele nunca inicializa uma VPS vazia e nunca cria ou substitui `.env.production`.

## 1. Duas identidades SSH diferentes

Use chaves exclusivas e não reutilize a chave pessoal de um administrador:

1. **GitHub Actions -> VPS:** a chave privada fica no secret `VPS_SSH_KEY`; a pública entra no `authorized_keys` do usuário `saas-deploy`.
2. **VPS -> repositório GitHub:** a chave privada permanece somente na VPS; a pública é cadastrada como Deploy key de leitura do repositório.

Em uma estação administrativa confiável, gere a primeira chave:

```bash
umask 077
ssh-keygen -t ed25519 \
  -C github-actions-agentefiscal-production \
  -f ./agentefiscal-actions-vps
```

Não use passphrase nessa chave de automação. Transfira apenas `agentefiscal-actions-vps.pub` para a VPS. Guarde temporariamente a privada até cadastrá-la no Environment protegido do GitHub e trate qualquer cópia como segredo de produção.

## 2. Bootstrap da VPS Ubuntu

Antes do primeiro clone, envie o bootstrap e a chave pública usando o acesso administrativo inicial da VPS:

```bash
scp infra/scripts/bootstrap-production-vps.sh \
  agentefiscal-actions-vps.pub root@IP_DA_VPS:/tmp/

ssh root@IP_DA_VPS
chmod 0755 /tmp/bootstrap-production-vps.sh
/tmp/bootstrap-production-vps.sh \
  --ci-public-key-file /tmp/agentefiscal-actions-vps.pub
```

O script instala os utilitários necessários, Docker Engine/Buildx/Compose pelo repositório oficial, cria o usuário sem `sudo`, prepara `/opt/saas-service`, restringe a chave inbound e imprime:

- a chave pública de leitura que a VPS usará no GitHub;
- o fingerprint SHA-256 da chave SSH da VPS.

No repositório GitHub, abra **Settings -> Deploy keys -> Add deploy key**, cadastre a chave pública impressa e mantenha **Allow write access desmarcado**. Depois conclua o clone:

```bash
/tmp/bootstrap-production-vps.sh \
  --ci-public-key-file /tmp/agentefiscal-actions-vps.pub \
  --clone
```

O bootstrap não altera firewall, não emite TLS, não cria secrets da aplicação e não sobe containers. Essas ações continuam explícitas no [runbook de produção](production-vps-deployment.md).

### Rede e firewall

O workflow atual usa runner GitHub padrão, cujo IP de saída é dinâmico. Portanto, uma allowlist contendo apenas o IP do administrador bloqueará o deploy. Escolha conscientemente uma destas topologias:

- **Inicial/compatível com o YAML atual:** permita TCP/22 no firewall do provedor, mas somente OpenSSH deve escutar; mantenha login por senha desabilitado para `saas-deploy`, chave `restrict`, Environment protegido e rotação da chave. Restrinja o usuário administrativo separadamente sempre que possível.
- **Recomendada para uma allowlist estrita:** use GitHub-hosted larger runner com faixa estática, ou um runner/bastion controlado, e permita TCP/22 somente a essa origem. Altere apenas o `runs-on` do job `deploy`; não execute jobs de pull request em um runner com acesso à produção.

Não tente manter allowlist manual das faixas dos runners padrão: elas são numerosas e mudam. Independentemente da opção, publique para a Internet somente TCP/80 e TCP/443 do Nginx, além do SSH administrativo escolhido. PostgreSQL, Redis, backend e Keycloak não podem ter portas públicas. Aplique a restrição também no firewall do provedor e na cadeia `DOCKER-USER`, porque portas publicadas pelo Docker podem contornar regras simples de UFW.

A VPS também precisa de saída para DNS autoritativo (TCP/UDP 53), NTP (UDP 123), GitHub por SSH e HTTPS para os mirrors Ubuntu, `download.docker.com`, Snap Store/CDN, Docker Hub, Quay, imagens Alpine, Maven Central, npm, o armazenamento off-site e os próprios hosts `app.contadorfiscal.com.br`, `api.contadorfiscal.com.br` e `auth.duoset.com.br`. Registre e monitore qualquer bloqueio de egress em vez de liberar portas internas inbound.

## 3. Ruleset obrigatório da `main`

Em **Settings -> Rules -> Rulesets**, crie um ruleset ativo para `main`:

- exigir pull request antes de merge;
- exigir pelo menos uma aprovação de pessoa diferente do autor;
- invalidar aprovações antigas quando houver novos commits;
- exigir aprovação do push revisável mais recente;
- exigir resolução de todas as conversas;
- exigir que o branch esteja atualizado antes do merge;
- habilitar somente **merge commit** e/ou **squash merge**; desabilitar rebase merge;
- manter merge queue/batching desabilitado: cada commit de primeira linha da `main` deve corresponder a exatamente um PR aprovado;
- bloquear force push e exclusão da branch;
- não conceder bypass habitual a administradores, bots ou times;
- exigir o status check **Production release gate**, com GitHub Actions como fonte.

O workflow roda esse gate em todo pull request e em todo push de `main`, sem filtro de paths. Ele agrega frontend, backend, isolamento de tenants, Gitleaks, Trivy, dependency review e builds Docker. O deploy ainda recusa force-push, confere que `main` está protegida e usa o último Deployment `production` bem-sucedido como checkpoint. Todos os commits de primeira linha desde esse SHA precisam corresponder individualmente a um merge/squash de PR; para cada PR, o workflow rejeita solicitação de mudanças vigente e exige que o head final tenha aprovação de outra pessoa com permissão `write` ou superior. Assim, um push direto que falhou não pode ser incorporado silenciosamente pelo PR seguinte. Não apague os Deployment records usados como trilha de autorização. Essas verificações complementam o ruleset; não o substituem.

Proteja alterações em `.github/`, `infra/`, Dockerfiles, Compose e migrations com `CODEOWNERS` assim que o usuário ou time GitHub responsável estiver definido. Não versione um placeholder inválido como owner.

## 4. Environment `production`

Em **Settings -> Environments**, crie explicitamente `production` antes do primeiro merge de release:

- permita deploy somente da branch `main`;
- configure um reviewer independente;
- habilite **Prevent self-review**;
- se o plano GitHub não oferecer required reviewers para repositório privado, mantenha o ruleset e a checagem independente do próprio workflow e restrinja quem pode executar Actions;
- grave os secrets abaixo somente no Environment, sem duplicá-los no escopo do repositório ou organização.

| Secret | Valor |
|---|---|
| `VPS_HOST` | IP ou hostname administrativo da VPS |
| `VPS_PORT` | Porta SSH, normalmente `22` |
| `VPS_USERNAME` | `saas-deploy` |
| `VPS_SSH_KEY` | Conteúdo integral da chave privada `agentefiscal-actions-vps` |
| `VPS_HOST_FINGERPRINT` | Valor `SHA256:...` impresso pelo bootstrap e conferido pelo console da VPS |

O `.env.production`, certificados, chaves de criptografia, senhas de banco e credenciais de provedores não são secrets do workflow. Permanecem protegidos na VPS e no cofre de recuperação.

Crie também, em **Settings -> Secrets and variables -> Actions -> Variables**, a variável de repositório `PRODUCTION_INITIAL_SHA`. O valor será preenchido somente depois do `init` manual validado na próxima seção. Esse checkpoint explícito permite o primeiro deploy automático mesmo que já existam Deployment records fracassados; depois do primeiro sucesso, o workflow usa exclusivamente o histórico de Deployments bem-sucedidos.

## 5. Primeira instalação manual

O CI só executa atualizações depois que a instalação foi comprometida com sucesso. Como `saas-deploy`:

```bash
sudo -iu saas-deploy
cd /opt/saas-service
git status --short
./infra/scripts/deploy-production.sh init --domain contadorfiscal.com.br
```

Preencha o `.env.production` criado, configure DNS/TLS e execute novamente `init`, conforme o runbook. Confirme ao final:

```bash
./infra/scripts/deploy-production.sh status
test -f .deploy/state/installed.env
initial_sha="$(awk -F= '$1 == "git_revision" { print $2 }' .deploy/state/installed.env)"
printf '%s\n' "$initial_sha"
```

Confirme que a saída é um SHA de 40 caracteres e grave exatamente esse valor na variável de repositório `PRODUCTION_INITIAL_SHA` criada anteriormente. Não use o SHA de uma branch móvel e não altere essa variável para contornar um gate; ela representa apenas a instalação inicial já inspecionada.

Uma instalação realmente nova ainda não tinha dados para copiar antes do `init`. Antes de liberar o primeiro deploy automático, configure o destino off-site, gere o backup-base, confirme o marcador remoto e só então habilite o timer:

```bash
install -d -m 700 .deploy/secrets
install -m 600 infra/deploy/offsite-backup.env.example \
  .deploy/secrets/offsite-backup.env
${EDITOR:-vi} .deploy/secrets/offsite-backup.env

./infra/scripts/deploy-production.sh backup --upload-offsite
backup_path="$(awk -F= '$1 == "backup_path" { print substr($0, index($0, "=") + 1) }' \
  .deploy/state/last-backup.env)"
test -f "$backup_path/COMPLETED"
test -f "$backup_path/OFFSITE_UPLOAD"
```

Depois, em uma sessão administrativa/root (não como `saas-deploy`, que não possui `sudo`):

```bash
systemctl enable --now agentefiscal-production-backup.timer
systemctl status agentefiscal-production-backup.timer
```

O procedimento completo, IAM mínimo e monitoramento estão em [Backup e restore drill](../../infra/backup/README.md#envio-off-site-do-backup-gerado-pelo-deploy). Mantenha também uma cópia cifrada e versionada de `.env.production`, `.deploy/state` e `.deploy/secrets` fora da VPS; a identidade privada `age` nunca deve ficar na VPS nem no mesmo bucket.

## 6. O que ocorre depois de aprovar um PR

Aprovar não publica sozinho; é necessário fazer o merge em `main`. A sequência então é:

1. GitHub testa novamente o SHA de `main` e fecha o **Production release gate**.
2. O workflow comprova ruleset, PR merged e aprovação independente.
3. O job aguarda a aprovação do Environment `production`, quando configurada.
4. O GitHub conecta por SSH com fingerprint fixado.
5. A VPS confirma checkout limpo, busca somente `origin/main` e faz checkout detached do SHA exato.
6. `deploy-production.sh update` constrói imagens, abre uma janela sem escritores, faz backup dos dois PostgreSQL, confirma a cópia cifrada off-site, preserva volumes/realms, aplica migrations e valida a publicação.
7. `deploy-production.sh status` confirma a instalação pública.

Nenhum comando manual é necessário na VPS para uma release comum. Intervenção é necessária quando o gate falha, o Environment não é aprovado, o checkout está sujo, falta espaço/backup/TLS, há migration destrutiva ou existe mudança de serviço stateful.

## 7. Teste de aceite antes do primeiro release real

Faça um PR sem mudança funcional e confirme:

- push direto e force push para `main` são recusados;
- novo commit invalida aprovação anterior;
- falha de frontend, backend, Gitleaks ou Trivy impede o gate final;
- branch diferente de `main` não acessa os secrets de produção;
- fingerprint errado falha antes do SSH;
- checkout sujo na VPS falha antes do backup;
- após merge/aprovação, o SHA exibido em `.deploy/state/releases` corresponde ao SHA do GitHub.

Depois faça uma migration aditiva controlada e confirme que IDs dos volumes, tenants, usuários e realms permanecem os mesmos.

## Referências oficiais

- [GitHub: regras disponíveis em rulesets](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/available-rules-for-rulesets)
- [GitHub: deployments e environments protegidos](https://docs.github.com/en/actions/reference/workflows-and-actions/deployments-and-environments)
- [GitHub: deploy keys de repositório](https://docs.github.com/en/authentication/connecting-to-github-with-ssh/managing-deploy-keys)
- [GitHub: fingerprints SSH publicados](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/githubs-ssh-key-fingerprints)
- [GitHub: runners maiores e faixas IP estáticas](https://docs.github.com/en/actions/reference/runners/larger-runners)
- [Docker: instalação oficial no Ubuntu](https://docs.docker.com/engine/install/ubuntu/)
