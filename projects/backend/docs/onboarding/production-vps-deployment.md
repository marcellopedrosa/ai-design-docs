---
document_id: "ONBOARD-PRODUCTION-VPS-DEPLOYMENT"
primary_nature: "Regra"
objective: "Orientar a primeira instalação e as atualizações incrementais do sistema em uma VPS Linux de produção."
scope: "Topologia de réplica única, domínios públicos, Nginx, deploy, health, SMTP de recuperação Keycloak, webhooks, backup, rollback e verificações operacionais."
non_objectives: "Não provisionar infraestrutura externa, criar segredos, escalar o backend horizontalmente ou executar comandos sem os pré-requisitos e autorizações do ambiente."
owner: "DevOps e Operações"
status: "Active"
date: "2026-08-26"
version: "1.8"
last_reviewed: "2026-10-02"
keywords: "onboarding, runbook, VPS, producao, deploy, rollback, Keycloak, SMTP, recuperação de senha"
related_files: "docs/onboarding/github-production-cicd.md, docs/onboarding/keycloak-provisioning-identity.md, docs/onboarding/conversation-audit-hml-prd-onboarding.md, docs/onboarding/conversation-audit-keyring-provisioning.md, docs/onboarding/omnichannel-webhook-configuration.md, docs/onboarding/tenant-pool-policy-hml-prd-configuration.md, docs/onboarding/website-captcha-hml-prd-vps-configuration.md, infra/backup/README.md, docs/adrs/ADR-0016-infrastructure-environment-provisioning.md, docs/adrs/ADR-0018-keycloak-realm-provisioning-automation.md, docs/product/requirements/REQ-00058-keycloak-password-recovery-smtp.md"
code_references: "infra/scripts/deploy-production.sh, infra/deploy/production.env.example, docker-compose.yml, docker-compose.prd.yml, infra/keycloak/bootstrap/reconcile-realm-smtp.sh"
principal_statement: "A produção opera inicialmente em uma única VPS com uma réplica do backend e deploy incremental governado por health checks, backups, rollback e confirmação separada das integrações externas."
---

# Deploy de produção em VPS

Este runbook descreve a primeira instalação e as atualizações incrementais do sistema em uma única VPS Linux. O ponto de entrada operacional é o [deploy-production.sh](../../infra/scripts/deploy-production.sh), sempre executado a partir da raiz do repositório. O arquivo [production.env.example](../../infra/deploy/production.env.example) é apenas o modelo usado pelo comando `init`.

## Identificar o estado de PRD antes de escolher o procedimento

Este runbook não comprova o estado atual da VPS. Antes de qualquer `init`, `update`, provisionamento de realm ou mudança de configuração, o owner de Operações deve inventariar **sem alterar dados**: implantação e revisão em execução; checkout e `.env.production` existentes; `COMPOSE_PROJECT_NAME`; `.deploy/state/installed.env`, `volumes.env` e manifests; containers, volumes e bancos PostgreSQL; Keycloak, realms, usuários, roles e identidade técnica; backups off-site e restore drill. Registre apenas nomes, IDs técnicos, versões e resultados sanitizados, sem credenciais ou dados de clientes.

| Estado confirmado | Caminho permitido |
| --- | --- |
| VPS realmente nova, sem bancos, volumes ou Keycloak existentes | Seguir o roteiro de primeira instalação abaixo e as duas chamadas de `init`. |
| Instalação já gerenciada por `deploy-production.sh`, com marcadores e volumes consistentes | Preservar os dados e usar `status` para validar o contrato; mudanças seguem `update` e os runbooks da capacidade afetada. Não repetir o onboarding de primeiro usuário ou recriar segredos. |
| `init` anterior interrompido, sem `installed.env`, mas com containers, volumes e manifests criados pela tentativa registrada | Investigar a falha, preservar backup e seguir somente o procedimento documentado de `init --resume`. |
| Keycloak ou bancos já configurados fora do estado registrado pelo script, ou origem/identidade dos dados incerta | **Bloquear `init`, `--resume` e `update`** até haver inventário, backup restaurável, mapeamento de volumes/realms/migrations e plano de adoção ou migração aprovado pelos owners. O script não adota volumes desconhecidos. |

Não infira que um Keycloak ou PostgreSQL saudável pertence ao Compose deste projeto. Preserve a identidade, os dados e os acessos já existentes; não crie um segundo realm/banco, não importe JSON por cima do estado atual e não gere novas senhas ou chaves para uma instalação ativa.

## Roteiro completo da primeira instalação

Use esta ordem **somente depois de confirmar uma VPS realmente nova** na classificação acima. Cada link leva ao procedimento detalhado; registre responsável, revisão, resultado e evidência sanitizada por etapa. Uma falha interrompe a sequência. Configuração local de DEV (`.env.example`, `docker-compose.override.yml`, ngrok) não define o ambiente de produção.

1. **Entrega e host:** escolha a revisão aprovada, configure ruleset da `main`, Environment `production` e identidades SSH; prepare usuário de deploy, checkout, Docker, firewall e capacidade da VPS. Siga [GitHub Actions e preparação da VPS](github-production-cicd.md) e os [pré-requisitos](#pré-requisitos-da-vps).
2. **Identidade permanente e recuperação:** defina `COMPOSE_PROJECT_NAME` antes da primeira instalação e planeje custódia de `.env.production`, `.deploy/state`, backup off-site e [restore drill](../../infra/backup/README.md). Preserve os volumes existentes.
3. **Rede e configuração:** configure [DNS e TLS](#dns-e-tls). Faça a primeira chamada de [instalação em duas chamadas](#primeira-instalação-duas-chamadas), preencha o `.env.production` owner-only e valide as origens públicas. Configure [SMTP de recuperação](#smtp-de-recuperação-do-keycloak) e a [identidade técnica do Keycloak](keycloak-provisioning-identity.md).
4. **Criptografia antes de integrações:** provisione os três [keyrings de Conversation Audit](conversation-audit-keyring-provisioning.md), as seis variáveis `CONVERSATION_*` e a montagem somente leitura antes de registrar ou testar o webhook Telegram. Confirme init services e persistência durável conforme os gates especializados.
5. **Instalação e identidade humana:** execute a segunda chamada de `init`, confira `status` e `.deploy/state/installed.env`, depois crie o [primeiro usuário nominal `SUPER_ADMIN`](#primeiro-usuário-super_admin) e valide login e recuperação de senha.
6. **Proteção dos dados:** confirme backup-base criptografado off-site, marcador remoto, cópias seguras e drill isolado; só então habilite o timer de backup. Siga a [primeira instalação manual e liberação do CI](github-production-cicd.md#5-primeira-instalação-manual) e o [runbook de backup](../../infra/backup/README.md#envio-off-site-do-backup-gerado-pelo-deploy).
7. **Capacidades externas:** habilite [Conversation Audit](conversation-audit-hml-prd-onboarding.md) na ordem e com as aprovações próprias; configure [webhooks omnichannel](omnichannel-webhook-configuration.md) após seus gates. A [política de pool por tenant](tenant-pool-policy-hml-prd-configuration.md) está em `Draft` e requer aprovação e gates próprios antes de ativação.
8. **Liberação de releases:** grave o SHA instalado em `PRODUCTION_INITIAL_SHA`, conclua o [teste de aceite do CI/CD](github-production-cicd.md#7-teste-de-aceite-antes-do-primeiro-release-real) e faça o [checklist operacional](#checklist-operacional). O handoff deve incluir falhas, skips, pendências e owner; containers saudáveis, sozinhos, não comprovam as integrações.

A topologia atual possui exatamente uma réplica do backend: o Compose define um container nominal e o
script de deploy rejeita mais de um container para o serviço. O lock do lifecycle Telegram é local à JVM
e depende dessa restrição. Scale-out só pode ocorrer depois de introduzir claim/lease ou lock distribuído,
além de uma fila durável para as operações remotas.

O contrato público de produção usa domínios governados para cada camada:

- `https://app.contadorfiscal.com.br` para o frontend;
- `https://api.contadorfiscal.com.br` para a API;
- `https://auth.duoset.com.br` para o Keycloak.

## Origem pública e webhooks Telegram

Em produção, `APP_BASE_URL` resolve obrigatoriamente para `PUBLIC_API_URL`, isto é, a origem HTTPS
estável da API (`https://api.contadorfiscal.com.br` no contrato acima). Ngrok é exclusivo do ambiente de
desenvolvimento e nunca integra a topologia HML/PRD. Em HML, aplica-se a mesma regra com a origem HTTPS
estável de homologação, atualmente `https://api-hml.contadorfiscal.com.br`. Para o runbook detalhado
de configuração, testes com curl e checklist operacional de Telegram e WhatsApp, consulte
[Configuração de webhooks omnichannel](omnichannel-webhook-configuration.md).

`APP_BASE_URL` é usado para formar callbacks externos; ele não é a URL da Telegram Bot API e não contém
token, secret, path ou barra final. O deploy valida sua correspondência com `PUBLIC_API_URL` e a ausência
de serviços ngrok. O backend rejeita origem inválida ao registrar configs ativas.

Antes de qualquer registro ou teste externo do Telegram, conclua o gate criptográfico descrito em [conversation-audit-keyring-provisioning.md](conversation-audit-keyring-provisioning.md): três keyrings independentes, seis variáveis `CONVERSATION_*`, montagem somente leitura em `/run/saas-secrets` e execução dos init services do Compose. O workflow de produção que executa apenas `docker run --env-file` sem essa montagem não atende ao contrato e deve delegar ao `deploy-production.sh` ou reproduzir integralmente esse lifecycle. Se o backend emitir `503` com `PERSISTENCE_UNAVAILABLE`, interrompa o onboarding; a mensagem foi rejeitada antes da persistência durável.

Após `ApplicationReady`, o backend reconcilia idempotentemente todos os webhooks Telegram ativos e
repete o processo a cada 15 minutos por padrão. O registro só é considerado bem-sucedido quando
`setWebhook` retorna `ok=true` e `getWebhookInfo.url` corresponde exatamente à URL esperada. A métrica
`telegram.webhook.operations{operation,outcome}` diferencia `register`, `replace` e `delete`, com
outcomes `success`, `partial_success`, `failure` e `skipped`.

Depois da primeira criação de uma config ativa, ou após uma migração coordenada de domínio/origem:

1. confirme DNS, certificado e health da API pública;
2. faça rollout/restart do backend já com o novo `APP_BASE_URL` e acompanhe a reconciliação de startup;
3. confirme sucesso em logs sanitizados e na métrica; update da config ativa pode antecipar uma nova
   tentativa after-commit sem delete/recreate;
4. verifique `getWebhookInfo` com ferramenta que não coloque o bot token em argv, shell history, logs ou
   screenshots;
5. confirme que a URL é HTTPS e contém tenant/config ativos, além de revisar
   `pending_update_count`/último erro sanitizado;
6. envie uma mensagem e confirme separadamente webhook recebido, inbound persistido e outbound aceito.

Create/update/delete executam na transação tenant e só agendam o provedor after-commit. O domínio gera o
webhook secret e o rotaciona quando o token muda. Cada tarefa recarrega fresh-state e usa lock local;
troca de token tenta apagar o token antigo, mas prioriza registrar o token/secret atuais mesmo se esse
delete falhar. O executor é dedicado e limitado, e as chamadas têm timeouts HTTP. Falhas são registradas
sem token, secret ou mensagem upstream. Configs ativas serão tentadas novamente pelo reconciliador.

Desativação/exclusão é diferente: `deleteWebhook` é best-effort e não existe tombstone/retry durável
depois da remoção ou inativação local. A operação deve ser acompanhada até confirmação remota; o
reconciliador de configs ativas não fecha esse gap.

Não apague e recrie a configuração apenas para re-registrar. A recriação muda `channelAccountId`, e uma
conversa existente pode continuar apontando para o ID removido. A identidade canônica de conversa é
`tenantId + channel + channelAccountId + remoteId`. Reconciliar uma referência órfã só é seguro quando
há evidência de que o novo registro representa o mesmo bot lógico; para outra conta, encerre a sessão
antiga e mantenha histórico separado.

### Diagnóstico operacional do Telegram

O `200` do webhook pode ser um no-op para update não suportado/malformado, sem tarefa, ou um ACK de
comando processável submetido ao executor. Não há inbox persistida antes da resposta. Processamento,
persistência e outbound podem falhar depois e, como o Telegram já recebeu `200`, essa falha não provoca
retry do provedor. `200` no proxy ou Traffic Inspector não é prova de sucesso funcional.

Use esta ordem, sempre sem consultar conteúdo, remote IDs, tokens ou secrets:

1. valide `deploy-production.sh status`, DNS/TLS e health público da API;
2. compare a URL remota registrada com a origem e o path da config ativa;
3. consulte IDs técnicos/flags da config e compare `conversations.channel_account_id` com o config ativo;
4. compare contagens e timestamps de webhooks com mensagens `INBOUND/OUTBOUND`; não presuma que o
   publication registry do Spring Modulith seja inbox do update ou outbox do lifecycle Telegram;
5. procure nos logs do worker a primeira falha após o ACK, especialmente resolução de config inexistente;
6. corrija origem/reconciliação antes de considerar reparo de dados;
7. qualquer reparo de referência exige backup restaurável, aprovação, audit e validação posterior.

Também trate como alerta operacional qualquer `partial_success`/`failure` de replace/delete: a fila é
local ao processo e não oferece retry durável. Reinício/reconciliador ajuda configs ativas, mas não
reconstitui a intenção remota de uma config já desativada ou excluída.

Consulte [ADR-0015](../adrs/ADR-0015-telegram-integration.md),
[ADR-0016](../adrs/ADR-0016-infrastructure-environment-provisioning.md) e
[LL-BE-00088](../delivery/lessons-learned/backend/LL-BE-00088-conversation-identity-includes-channel-account.md).

## Invariantes que protegem os dados

O valor de `COMPOSE_PROJECT_NAME` identifica a instalação e os volumes persistentes. Escolha-o antes da primeira subida e nunca o altere depois. Com `COMPOSE_PROJECT_NAME=contadorfiscal-prd`, por exemplo, os volumes padrão ficam sob nomes como `contadorfiscal-prd_postgres-app-data` e `contadorfiscal-prd_postgres-kc-data`. O script registra projeto, domínio, endereços públicos da VPS e nomes efetivos dos volumes em `.deploy/state` e recusa uma atualização se essa identidade mudar. Troca de VPS/IP exige um procedimento explícito de migração de host e DNS.

Também são permanentes as senhas dos bancos e do Redis, a identidade técnica do Keycloak e as chaves de criptografia geradas no primeiro `init`. Não gere outro `.env.production`, não apague `.deploy/state` e não copie um arquivo de ambiente novo por cima do existente.

Em produção, nunca execute:

```text
docker compose down -v
docker volume rm ...
flyway clean
```

Não use comandos equivalentes para zerar bancos, não remova volumes para “corrigir” uma atualização e não importe realms com sobrescrita. Um `docker compose down` comum também não faz parte do procedimento: o script para e recria somente os serviços necessários.

## Pré-requisitos da VPS

Antes do primeiro deploy, prepare:

- uma VPS Linux com armazenamento persistente e capacidade para os dois PostgreSQL, Keycloak, backend, frontend e proxy; 4 GB de RAM é o mínimo prático e 8 GB ou mais é recomendado;
- relógio sincronizado por NTP e espaço em disco monitorado;
- Docker Engine e Docker Compose v2;
- Bash, Git, `jq`, OpenSSL, `curl`, `dig` (pacote `dnsutils`/`bind-utils`), `gzip`, `age`, AWS CLI v2, `flock`, `getent` e utilitários GNU como `awk`, `sed`, `find`, `stat`, `sha256sum`, `base64`, `cmp`, `comm`, `realpath`, `df`, `id`, `install`, `cut`, `wc` e `tr`;
- o repositório clonado em `/opt/saas-service`, com `origin` autorizado a ler o repositório e sem alterações locais rastreadas ou arquivos não ignorados;
- um usuário de deploy com acesso ao daemon Docker e permissão de escrita no checkout, sem compartilhar sua chave SSH;
- firewall permitindo da Internet somente SSH administrativo e TCP 80/443. Não publique PostgreSQL, Redis, backend, Keycloak ou SMTP diretamente;
- saída DNS e TCP para o host/porta do provedor SMTP transacional escolhido, além
  de domínio remetente verificado e registros SPF/DKIM/DMARC conforme o provider.

Mantenha espaço para o dump completo e seu arquivo cifrado coexistirem durante cada atualização. O preflight exige pelo menos duas vezes o tamanho lógico somado dos dois clusters PostgreSQL, mais `BACKUP_MIN_FREE_MB` de reserva (padrão: `2048` MiB); depois do dump, o uploader mede novamente o tamanho real antes de iniciar o `age`. Aumente a margem conforme crescimento, WAL, imagens Docker e características do filesystem. O script mede o espaço antes de parar escritores e aborta se não houver capacidade. Dimensione retenção, disco e alertas conforme o volume real dos clientes.

Para preparar uma VPS Ubuntu limpa, as duas identidades SSH e as proteções do repositório, siga [GitHub Actions e preparação da VPS](github-production-cicd.md). O bootstrap versionado é `infra/scripts/bootstrap-production-vps.sh`; ele instala e valida o host, mas deliberadamente não cria segredos, DNS, TLS ou containers da aplicação.

## DNS e TLS

Crie registros `A` para `app`, `api` e `auth` apontando para o IPv4 da VPS e grave esse endereço em `VPS_PUBLIC_IPV4` no `.env.production`. O script consulta cada nameserver autoritativo e exige exatamente esse endereço nos três hosts; `/etc/hosts`, cache local ou outro deploy saudável não satisfazem a validação. Se publicar registros `AAAA`, grave o endereço em `VPS_PUBLIC_IPV6` e garanta que os três hosts apontem exclusivamente para ele; caso contrário, deixe a variável vazia e remova todos os `AAAA`. Aguarde a propagação em todos os nameservers antes da segunda chamada de `init`.

O script não emite certificados. Obtenha externamente um certificado cujo SAN cubra os três hosts e coloque, no diretório indicado por `TLS_CERT_DIR`, arquivos regulares com estes nomes:

```text
fullchain.pem
privkey.pem
```

A chave deve corresponder ao certificado, não pode ser legível por “outros” e deve continuar acessível ao processo que executa o deploy; modo `0600` é o padrão recomendado. Não versione nenhum desses arquivos. Como o diretório é montado no proxy, não monte apenas links quebrados de `/etc/letsencrypt/live`: copie os arquivos desreferenciados de modo atômico ou disponibilize também toda a árvore de destino dos links.

Configure a renovação fora do script. Depois de renovar, valide os três SANs, substitua os dois arquivos atomicamente e recarregue o proxy sem recriar a stack:

```bash
docker exec saas-proxy-prd nginx -t
docker kill --signal HUP saas-proxy-prd
./infra/scripts/deploy-production.sh status
```

O script rejeita certificado inválido, chave incompatível ou certificado com menos de 24 horas de validade. Monitore a data servida publicamente, não apenas os arquivos no disco.

## Primeira instalação: provisionamento Admin API

O primeiro provisionamento de Keycloak em uma VPS ocorre dentro do `init`; não
importe realms por JSON e não copie arquivos de realm para a VPS. O Compose inicia
o Keycloak, aguarda o endpoint de saúde e executa o serviço one-shot
`keycloak-provisioning-init`. Esse serviço chama
`infra/keycloak/provision/production.sh`, que delega para
`provision-realms.sh` usando a Admin REST API oficial.

O wrapper PRD exige `PUBLIC_APP_URL` e usa essa origem para redirect URIs e web
origins. A Service Account técnica deve estar disponível por Client Credentials;
a credencial de bootstrap do realm `master` é somente fallback para a primeira
instalação e nunca deve ser registrada em logs, Git ou argumentos.

## Provisionamento inicial do Keycloak na VPS

O primeiro provisionamento ocorre dentro do comando `init`; não copie nem monte
exports JSON na VPS. O Compose inicia o Keycloak, aguarda o healthcheck e executa
o serviço one-shot `keycloak-provisioning-init`, que chama
`infra/keycloak/provision/production.sh` e `provision-realms.sh` usando a Admin REST
API oficial por `kcadm.sh`.

O wrapper PRD exige `PUBLIC_APP_URL` para configurar redirects e web origins. A
Service Account deve usar Client Credentials; a credencial de bootstrap do realm
`master` é apenas fallback da primeira instalação e não deve aparecer em logs,
Git ou argumentos.

Em uma VPS real, use o fluxo suportado abaixo. Não execute o provisionador manualmente
contra produção sem backup, janela e autorização operacional.

## Primeira instalação: duas chamadas

Entre no checkout e garanta que o branch/revisão desejado esteja limpo:

```bash
cd /opt/saas-service
git status --short
./infra/scripts/deploy-production.sh init --domain contadorfiscal.com.br
```

A primeira chamada cria `.env.production` com modo `0600`, gera os segredos internos uma única vez e termina intencionalmente com código `2`, sem iniciar containers. Esse código significa “configuração criada; intervenção necessária”, não falha de infraestrutura.

Antes de continuar:

1. Edite o arquivo existente, preencha `VPS_PUBLIC_IPV4` e substitua todos os demais valores `CHANGE_ME`, inclusive `TF_VAR_contadorfiscal_smtp_password`, pelas credenciais reais. Se um valor contiver `$` literal, envolva-o com aspas simples no `.env.production` (por exemplo, `SEGREDO='valor$literal'`); o script compara o valor efetivamente entregue pelo Compose e bloqueia qualquer expansão silenciosa.
2. Confirme `COMPOSE_PROJECT_NAME`; este é o último momento seguro para escolhê-lo.
3. Instale `fullchain.pem` e `privkey.pem` no `TLS_CERT_DIR`.
4. Se habilitar observabilidade, grave somente a URL HTTPS no arquivo indicado por `ALERT_WEBHOOK_URL_FILE` e use `--with-monitoring` nas chamadas, ou defina `WITH_MONITORING=true`.
5. Confirme `chmod 600 .env.production` e faça uma cópia segura do arquivo em um gerenciador de segredos. Não o armazene no Git.

Execute a mesma chamada pela segunda vez:

```bash
./infra/scripts/deploy-production.sh init --domain contadorfiscal.com.br
./infra/scripts/deploy-production.sh status
```

Com monitoramento:

```bash
./infra/scripts/deploy-production.sh init --domain contadorfiscal.com.br --with-monitoring
./infra/scripts/deploy-production.sh status --with-monitoring
```

O arquivo `.deploy/state/installed.env` é gravado por último, como ponto de commit da instalação. Se uma tentativa incompleta já tiver criado volumes mas ainda não houver esse marcador, não os apague nem crie o marcador manualmente. Inspecione o erro e o conteúdo existente, preserve uma cópia externa e somente então retome explicitamente:

```bash
./infra/scripts/deploy-production.sh init --domain contadorfiscal.com.br --resume
```

O modo `--resume` exige os dois containers PostgreSQL existentes e também os manifests gerados pela tentativa registrada; ele não adota volumes desconhecidos. Antes do rollout, cria um backup de emergência.

## SMTP de recuperação do Keycloak

Antes de criar usuários humanos, preencha no `.env.production` owner-only as
variáveis não secretas `KEYCLOAK_REALM_SMTP_*` e a senha somente em
`TF_VAR_contadorfiscal_smtp_password`. O deploy rejeita
Mailpit/localhost, autenticação desligada, TLS ausente/ambíguo e credencial fora
do formato transportável antes da primeira mutação. O one-shot converte a variável
protegida no contrato interno apenas dentro do processo, sem expô-la em argumentos
ou logs. Essa configuração é independente da Central de Notificações e será
aplicada a `saas-admin`, `saas-bpfarias`, realms tenant existentes da allowlist e
novos tenants.

Mailpit não integra PRD. Um e-mail externo, como `@gmail.com`, é suportado como
destinatário normal; a entrega depende da reputação e das políticas do provider.
Na janela aprovada, valide envio, expiração do link, atualização da senha e login
posterior sem registrar link, token ou conteúdo da mensagem como evidência.

## Primeiro usuário `SUPER_ADMIN`

Os JSON de realm não contêm usuários humanos. Depois do primeiro deploy, o script avisa enquanto `saas-admin` não possuir uma pessoa com `ROLE_SUPER_ADMIN`.

Em uma janela controlada, abra o Admin Console por `https://auth.duoset.com.br/admin/` a partir de uma estação confiável e autentique no realm `master` com a credencial de bootstrap guardada no gerenciador de segredos. Não imprima nem passe essa senha como argumento de processo. Então:

1. selecione o realm `saas-admin`;
2. crie um usuário nominal para a pessoa responsável, com e-mail verificado e ações obrigatórias apropriadas;
3. defina uma senha temporária entregue por canal separado e exija sua troca no primeiro login;
4. em Role mappings, atribua somente a role de realm `ROLE_SUPER_ADMIN`, sem roles tenant e sem mapper `tenant_id`;
5. teste login e token em uma sessão separada e confirme que o token não contém `tenant_id`;
6. teste **Esqueceu sua senha?** com o usuário nominal e confirme a entrega pelo
   provider sem copiar o link para logs ou tickets;
7. confirme que a identidade técnica permanente de provisionamento está saudável e desabilite o acesso humano de bootstrap que não será mantido.

O contrato e as verificações da identidade técnica estão em [Identidade de provisionamento do Keycloak](keycloak-provisioning-identity.md). Use MFA para as contas administrativas quando disponível, mantenha uma segunda conta nominal de emergência segundo a política da organização e nunca transforme a conta técnica em usuário interativo.

Nunca acrescente um usuário com senha ao JSON versionado de realm. Esse JSON serve apenas ao bootstrap de um realm inexistente.

## Atualização incremental manual

Selecione uma revisão aprovada, sincronize o checkout sem descartar alterações de operador e confirme que ele está limpo. Não altere o projeto Compose nem regenere o ambiente. Então execute:

```bash
cd /opt/saas-service
git status --short
./infra/scripts/deploy-production.sh update
./infra/scripts/deploy-production.sh status
```

O `update` adquire um lock exclusivo, verifica identidade da instalação, fingerprints dos segredos e imutabilidade das migrações Flyway. Antes de mexer nos containers em execução, ele constrói as novas imagens de backend e frontend a partir do checkout verificado. Em seguida, interrompe temporariamente os escritores, gera dumps consistentes dos dois clusters PostgreSQL, preserva os volumes nomeados, sobe os serviços e valida containers, bancos de tenants, históricos Flyway, realms e HTTPS público.

Nunca edite nem remova uma migração Flyway já registrada. Prefira migrações compatíveis no modelo expand/contract. Uma nova migração que contenha operação destrutiva exige revisão de impacto, backup externo confirmado e aprovação explícita:

```bash
./infra/scripts/deploy-production.sh update --allow-destructive-migrations
```

Essa opção não torna a mudança segura por si só. Rotação de credenciais de banco, domínio, chaves criptográficas ou identidade técnica é uma migração coordenada separada e não deve ser forçada pelo `update`.

## Deploy automático pelo GitHub Actions

O workflow de backend sincroniza a VPS exatamente com o SHA aprovado de `main` e chama o mesmo `deploy-production.sh`. Backend, frontend, argumentos públicos `NEXT_PUBLIC_*` e migrações Flyway são construídos na VPS a partir desse checkout verificado. O job falha se `origin/main` tiver avançado, se o checkout estiver sujo, se o host SSH não corresponder ao fingerprint cadastrado ou se o ambiente não estiver no modo local obrigatório. Uma execução mais nova deve então implantar o novo HEAD.

Para habilitá-lo, configure no ambiente protegido `production` os secrets `VPS_HOST`, `VPS_PORT`, `VPS_USERNAME`, `VPS_SSH_KEY` e `VPS_HOST_FINGERPRINT`. O último valor deve ser o campo completo `SHA256:...` da chave pública do host, obtido por um canal confiável — por exemplo, no console da VPS com `ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key.pub -E sha256` — e nunca aceito da primeira conexão de rede. Proteja o ambiente com aprovação e restrição ao branch `main`.

O `.env.production` da VPS deve manter:

```dotenv
DEPLOY_BUILD_LOCAL=true
BACKEND_IMAGE=
FRONTEND_IMAGE=
```

O modo de registry está deliberadamente desabilitado enquanto não houver metadados assinados que vinculem a imagem do frontend aos valores OAuth públicos e a imagem do backend aos SQL Flyway da mesma revisão. O workflow nunca altera nem regenera `.env.production` e não executa Compose diretamente. A chave usada na VPS para `git fetch` deve ter acesso somente de leitura. Se esses contratos não estiverem atendidos, o CI para antes do rollout em vez de cair no Compose local/development.

## Backup e status

Para validar toda a instalação sem implantar uma versão:

```bash
./infra/scripts/deploy-production.sh status
```

Para criar um backup consistente e confirmar a cópia cifrada off-site sob demanda:

```bash
./infra/scripts/deploy-production.sh backup --upload-offsite
```

No comando `backup`, os serviços escritores ficam interrompidos durante o snapshot consistente e são reiniciados antes da cifragem/upload. No `update` e no `init --resume`, eles permanecem parados desde o snapshot até o início do rollout: assim nenhuma escrita confirmada fica entre o backup pré-release e a versão nova. Dimensione e comunique essa janela de manutenção; o tempo inclui dump, cifragem e upload. `BACKUP_DIR` deve ser um diretório dedicado, não um link simbólico, pertencente ao usuário de deploy e com modo `0700`; um marcador interno impede reutilizá-lo por outro projeto/domínio. O diretório de cada execução contém dumps, catálogos e checksums, mas é um backup local de emergência. Enquanto a geração está em curso ele contém `.INCOMPLETE`; somente depois de validar dumps e checksums o script troca esse marcador por `COMPLETED`. Nunca envie, restaure nem considere válido um diretório que ainda tenha `.INCOMPLETE` ou não tenha `COMPLETED`. Uma falha da VPS pode eliminá-lo junto com os dados originais.

O `update` exige que esse diretório `COMPLETED` seja criptografado e confirmado no armazenamento off-site antes do rollout. O timer systemd instalado pelo bootstrap repete o fluxo duas vezes ao dia, mas só deve ser habilitado depois do primeiro teste bem-sucedido. Não execute `postgres-backup.sh` apontando para esse diretório: aquele script é um fluxo separado, conectado diretamente a um único cluster por execução. A configuração, o IAM mínimo, a retenção local segura e os comandos de monitoramento estão em [PostgreSQL Backup And Restore Drill](../../infra/backup/README.md#envio-off-site-do-backup-gerado-pelo-deploy). Guarde a identidade de descriptografia fora da VPS e do bucket, configure alerta para falha da unit e execute restauração de ensaio em infraestrutura isolada pelo menos trimestralmente.

Preserve também, em cofre off-site cifrado e com controle de versão, o `.env.production`, `.deploy/state` e os segredos operacionais de `.deploy/secrets`. Esses arquivos vinculam os dumps ao projeto, domínio, volumes, fingerprints e baselines corretos. Em recuperação de desastre, restaure um conjunto coerente com o backup escolhido; nunca sintetize `installed.env` ou outros manifests para fazer o script aceitar dados desconhecidos.

## Provisionamento e mudanças futuras no Keycloak

O provisionamento inicial e toda evolução de realm usam a Admin REST API oficial por `kcadm.sh`. Os wrappers DEV, HML e PRD são versionados em `infra/keycloak/provision/`; não existem mais exports JSON de ambiente para montar ou atualizar.

Alterações de roles, clients, mappers, redirects, SMTP ou identidades devem ser mudanças versionadas no provisionador, validadas em DEV e promovidas com backup e janela operacional. Quando o banco do Keycloak já contém o realm, alterar o JSON do repositório não atualiza usuários, clients, roles, mappers ou redirects persistidos.

Toda evolução de realms existentes deve ser uma migração versionada, auditável e idempotente pela Keycloak Admin API (ou `kcadm.sh` usando essa API). Ela deve:

1. criar um backup restaurável do banco Keycloak e copiá-lo off-site;
2. detectar a versão/estado atual antes de aplicar a mudança;
3. aplicar o mesmo contrato a todos os realms geridos, sem ampliar privilégios como atalho;
4. ser segura para nova execução e registrar sucesso por realm;
5. renovar sessões afetadas e testar login, refresh, logout, convites e criação de realm.

O `init` executa o provisionador idempotente e verifica o estado existente antes de alterar qualquer objeto. Nunca apague o volume Keycloak ou recrie o banco para propagar uma configuração.

O mesmo princípio vale para PostgreSQL, Keycloak e Redis: imagem e configuração efetivas desses serviços stateful ficam registradas no primeiro deploy. O `update` comum recusa qualquer diferença. Upgrades de versão, flags, mounts ou topologia precisam de plano de upgrade stateful próprio, backup off-site, compatibilidade/downgrade analisados e atualização explícita da baseline; não contorne a trava editando `.deploy/state` sem esse processo.

## Falha e rollback

Se uma atualização falhar antes do rollout, o script tenta reiniciar os escritores originais. Se a falha acontecer depois que o rollout começou — inclusive depois de uma migração Flyway — ele preserva o backup e deliberadamente não executa rollback cego de imagem nem restauração automática do banco. Registre o caminho de backup mostrado na saída e inspecione `status` e os logs indicados pelo próprio script.

Um rollback da aplicação é manual. Prepare uma nova revisão aprovada que reverta o código de backend/frontend, mas preserve todos os arquivos Flyway já registrados, os JSON de bootstrap do Keycloak e a configuração baseline dos serviços stateful. Não faça simplesmente checkout de um commit antigo que remova uma migração já aplicada: o script o bloqueará. Confirme que a aplicação revertida é compatível com o schema atual, sincronize essa revisão de forma auditável e execute novamente `update`; o script reconstruirá as duas aplicações. Faça uma alteração por vez e mantenha evidência da decisão. Migrações expand/contract são o que permite voltar a aplicação sem voltar o banco.

Não restaure o banco de produção automaticamente para acompanhar uma imagem antiga. Restore é recuperação de desastre: exige janela de indisponibilidade aprovada, cópia preservada do estado atual, restauração previamente ensaiada em ambiente isolado e decisão explícita sobre perda de dados após o backup. Downgrade incompatível do Keycloak também pode exigir restaurar o banco correspondente em vez de somente trocar sua imagem.

## Checklist operacional

Antes de cada mudança, confirme:

- checkout limpo e revisão aprovada;
- `COMPOSE_PROJECT_NAME`, domínio, senhas e chaves inalterados;
- certificado válido para `app`, `api` e `auth`;
- espaço suficiente para imagens e backup;
- último backup já criptografado off-site, timer saudável e restore drill vigente;
- migrações revisadas e compatíveis com rollback da aplicação;
- `APP_BASE_URL` continua igual à origem HTTPS estável de `PUBLIC_API_URL`;
- reconciliação Telegram permanece habilitada; se a origem mudou, sua observação está incluída na janela;
- SMTP Keycloak permanece externo, autenticado e cifrado; o smoke de recuperação
  está incluído quando houver criação, rotação ou reconciliação de realm;
- janela e comunicação definidas para a breve pausa de escritores.

Depois da mudança, execute `status`, valide login e fluxos críticos, confirme `OFFSITE_UPLOAD`/journal e registre SHA Git, IDs das imagens construídas, horário, operador e resultado. Quando houver migração de origem ou configuração Telegram, registre também a verificação remota do webhook sem armazenar URL com secrets, token ou PII.
