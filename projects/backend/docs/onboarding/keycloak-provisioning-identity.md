---
document_id: "ONBOARD-KEYCLOAK-PROVISIONING-IDENTITY"
primary_nature: "Regra"
objective: "Orientar criação, manutenção e migração da identidade técnica usada para provisionar realms Keycloak."
scope: "Desenvolvimento local, HML e PRD; Service Account, variáveis, volumes persistidos, reconciliação e validação da identidade de provisionamento."
non_objectives: "Não expor ou gerar segredos reais, promover API ou afirmar execução em volume, sessão e ambientes sem evidência."
owner: "DevOps, Segurança e Tenant"
status: "Active"
date: "2026-08-25"
version: "2.8"
last_reviewed: "2026-09-25"
keywords: "onboarding, Keycloak, Service-Account, provisioning, identidade, secrets, SMTP, Mailpit, recuperação de senha, saas-theme, OTP"
related_files: "docs/adrs/ADR-0018-keycloak-realm-provisioning-automation.md, docs/product/requirements/REQ-00031-phase2-tenant-lifecycle-and-access.md, docs/product/requirements/REQ-00058-keycloak-password-recovery-smtp.md, docs/product/requirements/REQ-00059-temporary-all-roles-mfa-disablement.md, docs/product/use-cases/UC-00028-phase2-tenant-lifecycle-and-user-management.md, artefatos de análise/ANL-00053-keycloak-empty-conditional-2fa-flow.md, docs/delivery/plans/TP-00042-temporary-dev-super-admin-login-mfa-disablement.md, docs/delivery/plans/TP-00044-keycloak-password-recovery-smtp.md, docs/onboarding/local-development-host-bootstrap.md"
code_references: "infra/keycloak/bootstrap/ensure-management-service-account.sh, infra/keycloak/bootstrap/reconcile-billing-mfa-amr.sh, infra/keycloak/bootstrap/reconcile-admin-login-mfa.sh, infra/keycloak/bootstrap/reconcile-super-admin-identity.sh, infra/keycloak/bootstrap/reconcile-realm-smtp.sh, infra/keycloak/bootstrap/migrate-persisted-volume.sh, infra/keycloak/provision/provision-realms.sh, infra/keycloak/themes/saas-theme/login/, backend/src/main/java/br/com/duoset/saas_service/contexts/tenant/internal/infrastructure/iam/KeycloakTenantRealmRepresentationFactory.java, backend/src/main/java/br/com/duoset/saas_service/contexts/tenant/internal/application/TenantOnboardingUseCase.java, backend/src/main/java/br/com/duoset/saas_service/contexts/tenant/internal/application/service/InviteTenantUserService.java, docker-compose.yml, docker-compose.override.yml, docker-compose.hml.yml, docker-compose.prd.yml"
principal_statement: "A senha administrativa de bootstrap não é credencial de runtime; o provisionamento usa Service Account de menor privilégio, saas-theme nos realms estáticos, identidades sem OTP e SMTP externo em HML/PRD."
---

# Referencia Operacional - Identidade de provisionamento Keycloak

**Ultima atualizacao:** 2026-09-25
**Status:** Operacao vigente; hardening estrutural, identidade Super Admin DEV, AMR e toggle temporário de login MFA DEV `IMPLEMENTED / REPOSITORY-LOCAL`; volume persistido, sessao/token novos e ambientes externos dependem de evidência explícita
**Versao:** 2.8
**Escopo:** desenvolvimento local, HML e PRD  
**Decisao arquitetural:** [ADR-0018](../adrs/ADR-0018-keycloak-realm-provisioning-automation.md)

## 1. Objetivo

Este documento define como o projeto cria e mantem a identidade machine-to-machine usada para provisionar realms e administrar identidades. Ele tambem descreve a migracao de volumes Keycloak criados antes da adocao de Service Account.

Regra central: a senha do administrador de bootstrap nunca e uma credencial de runtime do backend.

## 2. Arquivos de ambiente

| Arquivo | Uso | Pode conter valor local? | Deve ser versionado? |
|---|---|---:|---:|
| `.env` | Configuracao e segredos reais do ambiente local. | Sim | Nao |
| `.env.dev.local` | Valores tecnicos estaveis gerados pelos scripts de desenvolvimento, inclusive a identidade de provisionamento. | Sim | Nao |
| `.env.example` | Contrato das variaveis, sem segredos validos. | Nao | Sim |

Os scripts `start-dev-bot.sh`, `start-dev-dns-bot.sh`, `start-dev-bot-exposed-ngrok.sh` e `start-dev-bot.bat` carregam `.env.dev.local` antes de `.env`. O arquivo `.env.example` nunca deve ser usado como arquivo de runtime.

## 3. Contrato de variaveis

| Variavel | Consumidor | Finalidade | Regra |
|---|---|---|---|
| `KEYCLOAK_ADMIN_USER` | container Keycloak e inicializador one-shot | Criar o primeiro administrador em um banco Keycloak novo. | Bootstrap apenas; nao vai para o backend. |
| `KEYCLOAK_ADMIN_PASSWORD` | container Keycloak e inicializador one-shot | Senha do primeiro administrador em um banco novo. | Nao redefine usuario de volume existente. |
| `KEYCLOAK_DEV_SUPERADMIN_INITIAL_PASSWORD` | import DEV do Keycloak | Credencial inicial aleatoria do superadmin DEV. | Gerador/contrato implementado; inclusao real em `.env.dev.local` pendente. Nunca versionar/logar. |
| `KEYCLOAK_PROVISIONING_CLIENT_ID` | inicializador e backend | Identificador da workload tecnica. | Estavel por ambiente. |
| `KEYCLOAK_PROVISIONING_CLIENT_SECRET` | inicializador e backend | Autenticacao Client Credentials da workload. | Aleatorio, protegido e rotacionavel. |
| `KEYCLOAK_EXISTING_MANAGED_REALMS` | inicializador | Realms estaticos nos quais a workload recebe roles de gestao de usuario. | Lista explicita, separada por virgula. |
| `KEYCLOAK_ADMIN_LOGIN_MFA_ENABLED` | inicializador | Habilita/desabilita provider e o pai direto do ramo 2FA sem remover a folha TOTP. | `false` aceito somente com ambiente `dev`; base/HML/PRD usam `true`; `auth-otp-form` permanece `ALTERNATIVE`. |
| `KEYCLOAK_REALM_SMTP_MODE` | inicializador e backend | Seleciona o contrato `dev`, `hml` ou `prd`. | Deve coincidir com o ambiente; PRD não aceita Mailpit. |
| `KEYCLOAK_REALM_SMTP_HOST`, `KEYCLOAK_REALM_SMTP_PORT` | inicializador e backend | Endereço do transporte de recuperação. | DEV fixa `mailpit:1025`; HML/PRD usam `smtp.hostinger.com:465`. |
| `KEYCLOAK_REALM_SMTP_FROM*`, `KEYCLOAK_REALM_SMTP_REPLY_TO*` | inicializador e backend | Remetente e reply-to de IAM. | São da plataforma e independentes da Central de Notificações. |
| `KEYCLOAK_REALM_SMTP_AUTH`, `KEYCLOAK_REALM_SMTP_STARTTLS`, `KEYCLOAK_REALM_SMTP_SSL` | inicializador e backend | Política de autenticação e transporte. | DEV usa `false/false/false`; HML/PRD usam `true/false/true`. |
| `TF_VAR_contadorfiscal_smtp_password` | start/deploy HML e PRD | Fonte protegida da senha da conta SMTP. | Obrigatória antes da primeira mutação; valores independentes por ambiente; nunca em Git, argv ou logs. |
| `KEYCLOAK_REALM_SMTP_USER`, `KEYCLOAK_REALM_SMTP_PASSWORD` | inicializador e backend | Contrato interno da credencial SMTP. | O usuário é `contato@contadorfiscal.com.br`; a senha é derivada da variável protegida, não configurada como segunda fonte. |
| `KEYCLOAK_URL` | backend | URL interna do Keycloak. | Sem fallback inseguro em ambientes implantados. |

Em HML e PRD, secrets devem vir do mecanismo de secrets da plataforma. Variaveis de ambiente locais sao apenas uma conveniencia de desenvolvimento.

### 3.1 Matriz de recuperação de senha

| Ambiente | SMTP do realm | Como inspecionar/entregar | Limite |
| --- | --- | --- | --- |
| DEV | Mailpit interno sem auth/TLS | `http://127.0.0.1:8025` | Caixa efêmera; não envia para Gmail ou outro destino |
| HML | `smtp.hostinger.com:465`, auth e SSL | caixa de homologação e observabilidade do provider | Mailpit e hosts locais são rejeitados |
| PRD | `smtp.hostinger.com:465`, auth e SSL | caixa real do destinatário e observabilidade do provider | Mailpit e hosts locais são rejeitados |

`Alterar senha` em `/profile` é autenticado, exige a senha atual e não usa SMTP.
`Esqueceu sua senha?` é pré-login, pertence ao Keycloak e lê o `smtpServer` do
realm emissor. A regra é a mesma para tenants e `saas-admin`; uma conta
`@gmail.com` recebe normalmente quando o provider de PRD permite entrega externa.

### 3.2 Pré-condição de identidade por realm

Cada realm possui seu próprio diretório de usuários. Uma identidade existente em
`saas-admin` não existe automaticamente em `saas-{slug}`, mesmo quando o endereço
de e-mail é igual. No baseline vigente, o e-mail informado na criação do escritório
é contato/metadado do Tenant: o onboarding cria banco, metadados e realm, mas não
cria implicitamente o primeiro `TENANT_ADMIN`. A identidade tenant nasce pelo fluxo
de convite de usuário.

O Keycloak só envia a recuperação quando encontra, no realm exato que recebeu a
solicitação, um usuário habilitado correspondente ao nome de usuário/e-mail. Quando
não encontra, registra `RESET_PASSWORD_ERROR` com `error="user_not_found"` e mantém
uma resposta visual neutra para não permitir enumeração de contas; nenhuma conexão
SMTP é tentada nesse caso.

Procedimento canônico:

1. confirme o realm presente na URL de login;
2. no detalhe do Tenant, consulte a aba de usuários;
3. se o endereço ainda não estiver cadastrado, convide-o com o perfil tenant
   aprovado e conclua a ativação recebida no Mailpit/provider;
4. somente depois teste **Esqueceu sua senha?** no mesmo realm;
5. se o usuário aparecer na aplicação, mas o evento do Keycloak continuar como
   `user_not_found`, interrompa o fluxo: há divergência entre persistência local e
   IAM, que exige reconciliação controlada. Não tente corrigir alterando SMTP nem
   criando uma segunda identidade manualmente.

## 4. Primeiro start local (DEV)

No primeiro start local, os realms não são importados de arquivos JSON. O serviço
`keycloak-provisioning-init` executa `infra/keycloak/bootstrap/provision-and-bootstrap.sh`,
que chama `infra/keycloak/provision/dev.sh` e provisiona os realms pela Admin REST API.

Pré-requisitos: Docker Compose v2, `.env`, `.env.dev.local` e portas locais livres.
Execute a partir da raiz:

```bash
./start-dev-bot.sh --check
sudo docker compose --env-file .env.dev.local --env-file .env \
  -f docker-compose.yml -f docker-compose.override.yml up -d
```

Valide o primeiro start:

```bash
sudo docker compose --env-file .env.dev.local --env-file .env \
  -f docker-compose.yml -f docker-compose.override.yml ps -a
sudo docker logs saas-keycloak-provisioning-init
bash infra/keycloak/bootstrap/validate-realm-token-contracts.sh
```

O resultado esperado é `saas-keycloak-provisioning-init` com `Exited (0)` e o
backend saudável. O provisionador cria ou verifica `saas-admin`, `saas-bpfarias`,
clients, mappers, roles e as identidades canônicas. Os dois realms são configurados
com o tema visual `saas-theme` (de `infra/keycloak/themes/saas-theme`). As identidades
canônicas (`djmarcellopedrosa@gmail.com` em `saas-admin` e `contato@matrizcontabil.com.br`
em `saas-bpfarias`) são provisionadas sem a ação obrigatória de OTP (`CONFIGURE_TOTP`),
mantendo exclusivamente `UPDATE_PASSWORD` para primeiro acesso via fluxo de redefinição
de senha e recuperação por SMTP, sem exigência de MFA/TOTP na configuração do usuário.
O Keycloak gera os UUIDs e o backend concilia o UUID do Super Admin em `admin_users` durante
o startup; falha de conciliação impede o backend de ficar pronto. Não use `--import-realm`, não
monte exports JSON e não passe senhas humanas em argumentos ou logs. Se falhar,
repita após corrigir a causa; a operação é idempotente e falha fechada diante de
drift ou ambiguidade.

## 4.1 Primeiro start em HML e PRD

Antes de renderizar o Compose ou executar o start, disponibilize no mecanismo de
segredos protegido do ambiente:

```bash
TF_VAR_contadorfiscal_smtp_password=<valor-fornecido-pelo-provider>
```

Não coloque o valor em arquivo versionado, argumento, log ou evidência. O mesmo
nome é usado nos dois ambientes, mas cada ambiente possui seu próprio valor e
controle de acesso. O preflight valida a presença e o formato antes da primeira
chamada mutável à Admin API.

O one-shot cria ou verifica `saas-admin` e `saas-bpfarias`, reconcilia em ambos
`loginTheme=saas-theme`, `resetPasswordAllowed=true` e o SMTP da plataforma e então lê o estado final pela
API. A reexecução é idempotente e também corrige realms preexistentes (reconciliando
`saas-theme` e removendo `CONFIGURE_TOTP` residual dos usuários estáticos). Falha do
preflight ou da verificação final impede a subida do backend.

Em PRD, use somente `infra/scripts/deploy-production.sh init|update` conforme o
runbook de VPS. Em HML, use o Compose explícito com o arquivo owner-only aprovado;
nunca deixe o Compose descobrir `.env` implicitamente. Smokes de entrega real
exigem autorização ambiental separada.

## 5. Inicializacao com banco novo

1. Execute o script de desenvolvimento aplicavel ao canal.
2. O script cria ou completa `.env.dev.local` com um client ID e um secret tecnico aleatorio.
3. O Keycloak inicializa o realm `master` com a credencial de bootstrap.
4. `keycloak-provisioning-init` executa `ensure-management-service-account.sh`.
5. O inicializador cria o client confidencial, habilita Service Account e atribui as roles minimas.
6. Ainda sob a identidade administrativa de primeiro bootstrap, configura `pwd` e `otp` nas execucoes do browser flow do `saas-admin`, com max age de 900 segundos.
7. O reconciliador mantém `CONFIGURE_TOTP`, `auth-otp-form`, a credencial e o
   mapper AMR; no override DEV com a flag `false`, aplica
   `CONFIGURE_TOTP.enabled=false`, desabilita o pai direto do ramo 2FA e preserva
   `auth-otp-form=ALTERNATIVE`.
8. O reconciliador aplica `smtpServer` e `resetPasswordAllowed=true` somente nos
   realms da allowlist. O template backend aplica o mesmo contrato a novos tenants.
9. Depois disso, a Service Account permanente apenas verifica esses contratos; ela nao recebe `manage-realm` para repara-los.
10. O backend somente inicia se o inicializador terminar com codigo zero.

Validacao de configuracao sem subir os containers:

```bash
./start-dev-bot.sh --check
```

Validacao do estado:

```bash
sudo docker compose --env-file .env.dev.local --env-file .env \
  -f docker-compose.yml -f docker-compose.override.yml ps -a

sudo docker logs saas-keycloak-provisioning-init
```

Resultado esperado: o inicializador esta `Exited (0)` e o backend esta `healthy`.

## 5. Migracao de volume persistido

### Sintoma

O recovery e necessario em dois sintomas conhecidos. O primeiro e falha no token endpoint do realm `master` com:

```text
invalid_grant: Invalid user credentials
```

Isso significa que o backend antigo tentou Password Grant com uma senha que nao corresponde ao estado persistido. O segundo sintoma e o usuario concluir TOTP, retornar para Billing e receber novamente `BILLING_MFA_REQUIRED`: nesse caso, o mapper AMR existe, mas as execucoes de senha/OTP ainda nao possuem Authenticator Reference Value/Max Age. O terceiro é o login DEV ainda desafiar TOTP depois de `KEYCLOAK_ADMIN_LOGIN_MFA_ENABLED=false`: o realm persistido ainda não recebeu o toggle. Alterar `KEYCLOAK_ADMIN_PASSWORD` ou editar um export JSON nao atualiza o volume.

### Procedimento local preservando dados

```bash
infra/keycloak/bootstrap/migrate-persisted-volume.sh
```

O script:

1. preserva os volumes PostgreSQL;
2. para todos os nodes Keycloak, requisito do comando oficial de recovery;
3. cria um administrador temporario de recovery;
4. configura a identidade tecnica permanente;
5. reconcilia, no browser flow ativo do `saas-admin`, `pwd` e `otp` com max age de 900 segundos, sem sobrescrever config estrangeiro divergente;
6. reconcilia o toggle de login: em DEV/`false`, mantém os componentes, aplica
   `CONFIGURE_TOTP.enabled=false`, preserva `auth-otp-form=ALTERNATIVE` e define o
   pai direto 2FA como `DISABLED`; em `true`, habilita provider/folha antes de
   restaurar o pai como `CONDITIONAL`;
7. remove dos clients do `saas-admin` os mapeadores legados `tenant_id` e `tenant_id-mapper`;
8. configura os role scopes explicitos do `saas-frontend-spa` somente nos realms da allowlist exata `KEYCLOAK_EXISTING_MANAGED_REALMS`, mantendo `fullScopeAllowed=false`;
9. valida que o realm administrativo nao possui os mapeadores legados, que cada role esperada esta no scope do SPA e que os contratos MFA/AMR e do toggle podem ser lidos pela identidade permanente;
10. remove todos os usuarios e clients temporarios criados pelo procedimento;
11. reinicia o Keycloak;
12. valida Client Credentials permanentes.

O toggle é realm-wide no `saas-admin` DEV. Com ele desligado, outras identidades
interativas desse realm também não recebem TOTP e não conseguem gerar `amr=otp`.
Operações que ainda exigem MFA permanecem fail-closed e podem ficar indisponíveis;
a flag não constitui bypass dessas autorizações.

Nao interrompa o script depois da criacao da identidade temporaria. Se houver interrupcao, execute-o novamente; a limpeza e idempotente para identidades com o prefixo de recovery adotado pelo script.

### Contrato de claims por tipo de realm

| Realm | Papel | Regra de `tenant_id` |
|---|---|---|
| `saas-admin` | `ROLE_SUPER_ADMIN` global | Claim proibida em access token. |
| `saas-{slug}` | Papeis tenant | Claim obrigatoria com UUID canonico do tenant. |

O Super Admin somente entra em contexto tenant quando envia `X-Tenant-ID`; o backend valida que o tenant existe e esta ativo. Nao adicione um UUID ficticio ao realm administrativo para contornar ausencia de contexto.

### Freeze docs-first de `ROLE_TENANT_AUDIT` - 2026-08-22

A extensao aprovada define a role nos dois tipos de realm sem transformar o realm administrativo em
tenant. O bootstrap versionado deve ser atualizado de forma consistente nos oito artefatos:

| Tipo | Artefatos obrigatorios |
|---|---|
| Admin DEV/HML/PRD | `infra/keycloak/provision/dev.sh`, `infra/keycloak/provision/hml.sh`, `infra/keycloak/provision/production.sh` |
| Tenant DEV/HML/PRD | `infra/keycloak/provision/dev.sh`, `infra/keycloak/provision/hml.sh`, `infra/keycloak/provision/production.sh` |
| Provisionamento tenant | `KeycloakTenantRealmRepresentationFactory` constroi a `RealmRepresentation` diretamente; nenhum JSON de realm e carregado pelo backend. |

Em todos eles, `saas-frontend-spa` continua com `fullScopeAllowed=false`. O scope administrativo
passa a declarar somente `ROLE_SUPER_ADMIN` e `ROLE_TENANT_AUDIT`; o scope tenant declara
explicitamente `ROLE_FISCAL_ADMIN`, `ROLE_FISCAL_READER`, `ROLE_TENANT_ADMIN`,
`ROLE_TENANT_USER` e `ROLE_TENANT_AUDIT`. Apenas o export
`infra/keycloak/provision/dev.sh` atribui a nova role ao usuario exato
`djmarcellopedrosa@gmail.com`, preservando `ROLE_SUPER_ADMIN`. HML, PRD e templates definem o contrato,
mas nao semeiam esse usuario nem qualquer atribuicao humana.

O export DEV nao pode versionar senha humana, ainda que temporaria. O unico valor admitido no campo
de credencial e `${KEYCLOAK_DEV_SUPERADMIN_INITIAL_PASSWORD}`; `start-dev-bot.sh` gera o secret
aleatorio estavel em `.env.dev.local` com permissao `0600`, o Compose o injeta somente no container
local e logs/validadores nunca exibem o valor. HML/PRD devem manter `.users` vazio.

Realm importado na inicializacao nao substitui realm ja salvo no PostgreSQL do Keycloak. Portanto,
o ciclo operacional separa obrigatoriamente:

1. **bootstrap novo:** os oito JSONs versionados criam role e scope no primeiro import;
2. **volume persistido local:** reconciliacao Admin API idempotente, pela identidade temporaria de
   recovery, percorre somente a allowlist `KEYCLOAK_EXISTING_MANAGED_REALMS`, cria a role se ausente,
   confere exatamente um SPA por realm, adiciona o scope sem duplicacao, remove qualquer mapper
   administrativo cuja semantica produza `tenant_id`; o reconciliador da identidade ancora o
   usuario DEV em `human_principal_id=dev-superadmin-primary` ou, para volumes legados sem a ancora,
   na associação unica de `ROLE_SUPER_ADMIN`, rejeita conflito de destino e atualiza somente
   `username`/`email` para `djmarcellopedrosa@gmail.com` antes do role mapping;
3. **sessao:** apos role/scope mapping, logout/invalida as sessoes do usuario DEV e exige login e
   token novos; token antigo nao comprova a alteracao;
4. **HML/PRD:** nenhuma reconciliacao ou atribuicao e executada sem backup restauravel, change,
   janela, owner e aprovacao especifica.

Zero ou mais de um client/usuario aborta a reconciliacao. O processo nao imprime secret, token ou
credencial, remove identidades temporarias ao final e nao concede `manage-realm` ao
`saas-realm-provisioner` permanente como atalho. A extensão dos scripts de provisionamento e os testes
permanecem **NOT IMPLEMENTED / NOT EXECUTED** no instante historico deste freeze documental.

#### Reconciliacao pos-freeze local - 2026-08-22

Depois do registro acima, os oito artefatos, a reconciliacao versionada, a allowlist exata, a
remocao semantica de mapper e o gerador/contrato da credencial DEV por placeholder owner-only foram
implementados. O validador de contratos e dois testes shell passaram. O export DEV atribui
`ROLE_SUPER_ADMIN` e `ROLE_TENANT_AUDIT` ao usuario aprovado; HML/PRD preservam `.users` vazio.

Esta e evidencia **STATICALLY VERIFIED LOCAL**. A inclusao no `.env.dev.local` real, o volume
Keycloak persistido, a atribuicao viva, a sessao/login/token novo e o backend-real permanecem
**NOT EXECUTED / BLOCKED BY LOCAL HOST ACCESS**. HML/PRD nao foram acessados ou alterados.

#### Freeze docs-first de hardening composite/service-account/client-scope - 2026-08-22

Antes de alterar novamente os scripts, o contrato operacional passa a exigir:

1. `ROLE_TENANT_AUDIT` realm role com `composite=false`, sem incluir nem ser herdada por
   `ROLE_TENANT_ADMIN`/`ROLE_SUPER_ADMIN`; mappings conjuntos devem continuar independentes;
2. o reconciliador enumera composites nos dois sentidos, remove somente drift inequivoco dentro da
   allowlist gerida e aborta diante de ambiguidade, erro de remocao ou aresta residual; a
   verificacao final repete todos esses asserts;
3. a Service Account permanente e reconciliada mesmo se seu `client_credentials` ja funcionar.
   Seus grants diretos devem terminar exatamente na allowlist minima da ADR-0018: role global
   `create-realm` e, apenas nos realms estaticos geridos, `manage-users`, `query-users`,
   `view-users` e `view-realm`. No Keycloak 26.6.x, `view-users` herda nativamente `query-users` e
   `query-groups`; por isso o conjunto efetivo exato por realm tem cinco roles, mas
   `query-groups` continua proibida como grant direto. Outros grants ou herancas falham fechado.
   Sucesso no token nao encerra a migracao cedo;
4. no `saas-admin`, a busca por emissao proibida de `tenant_id` cobre mappers diretos e todos os
   client scopes default/optional efetivamente atribuidos, inclusive os herdados. Origem gerida e
   inequivoca e removida; scope compartilhado/ambiguo ou claim residual aborta fail-closed;
5. o estado final e reconsultado antes de remover recovery identities e antes de considerar a
   reconciliacao concluida; logs continuam sem secrets ou tokens.

O validator e os dois testes shell anteriores nao cobrem ainda essas asserts. Eles permanecem
evidencia historica do contrato anterior; este hardening esta **FROZEN / PENDING IMPLEMENTATION /
PENDING EVIDENCE** e nao promove volume, sessao, backend-real, HML ou PRD.

#### Freeze corretivo v2.6 - argumentos, paginacao e init exato - 2026-08-22

Antes de nova alteracao executavel, a operacao passa a exigir cumulativamente:

1. nenhum valor de password/secret de recovery, bootstrap ou Service Account aparece no `argv`
   do host ou do container; somente canal suportado, efemero e owner-only e aceito;
2. clients, users, composites e qualquer outra colecao paginada detectam pagina repetida, item
   duplicado, ausencia de progresso e limite excedido, sempre com aborto fail-closed;
3. o init sem `FORCE_RECONCILE` nao declara ready apenas porque obteve token. Ele precisa provar
   os privilegios efetivos exatos ou falhar orientando a migracao/reconciliacao forcada;
4. mappers diretos e scopes default/optional efetivos dos clients geridos no `saas-admin` sao
   reconciliados quando a origem e dedicada e inequivoca; compartilhamento, origem desconhecida
   ou claim residual aborta sem remocao ampla.

Estado: **FROZEN / PENDING IMPLEMENTATION / PENDING EVIDENCE**. Nao execute a migracao viva ate
o gate semantico correspondente passar; HML/PRD continuam fora do escopo.

#### Reconciliacao pos-freeze estatica do hardening v2.6 - 2026-08-22

Depois do freeze acima, os scripts de init e migracao implementaram o contrato cumulativo v2.6:
zero password/secret em `argv` host/container, paginacao administrativa bounded e fail-closed,
prova exata dos privilegios efetivos antes do init ready e reconciliacao limitada a mapper/scope
dedicado e inequivocamente gerido. As invariantes anteriores de Audit non-composite, ausencia de
heranca administrativa e Service Account least-privilege continuam obrigatorias.

Passaram como gates shell estaticos:

```bash
bash infra/scripts/tests/keycloak-bootstrap-hardening-test.sh
bash infra/keycloak/bootstrap/validate-realm-token-contracts.sh
bash infra/scripts/tests/start-dev-bot-outbound-keyring-test.sh
```

Essa evidencia e **IMPLEMENTED / STATICALLY VERIFIED LOCAL**. A migracao nao foi executada no
volume persistido; atribuicao viva, invalidacao de sessao, login/token novos, backfill/readiness e
smoke autenticado permanecem **NOT EXECUTED / BLOCKED BY LOCAL PERMISSIONS**. A API continua off;
HML/PRD nao foram acessados.

#### Reconciliacao estrutural v2.6.1 - 2026-08-22

Uma segunda revisão independente fechou os riscos restantes antes da execução no volume:

1. first bootstrap cria o client técnico somente quando o inventário estrutural prova ausência;
   client persistido inacessível, duplicado, reservado ou não gerido falha sem update;
2. ownership versionado e fingerprint exclusivamente `client_credentials` são obrigatórios;
   `implicitFlowEnabled`, Standard Flow e Direct Grants ficam desabilitados;
3. a invariável standalone de Audit cobre todas as realm roles e client roles, inclusive caminhos
   transitivos; origem customizada/fiscal/client composite aborta;
4. token, client, mapper e páginas de recovery são parseados estruturalmente por
   `validate-keycloak-runtime-json.sh`, em Bash puro e com limites de bytes, profundidade e página;
5. o parser rejeita chaves duplicadas, decoys aninhados ou escapados, trailing data e ownership
   textual falso; identificadores externos arbitrários são ignorados e nunca viram comandos;
6. o arquivo do parser é montado read-only no `keycloak` e no `keycloak-provisioning-init` e sua
   ausência/ilegibilidade interrompe o fluxo antes da autenticação/mutação;
7. toda sessão temporária `kcadm` usa `umask 077` e modo `0600`; `INT` retorna 130, `TERM` 143 e o
   cleanup ocorre sem nova mutação.

Gates estáticos executados:

```bash
bash infra/scripts/tests/keycloak-runtime-json-validator-test.sh
bash infra/scripts/tests/keycloak-bootstrap-hardening-test.sh
bash infra/keycloak/bootstrap/validate-realm-token-contracts.sh
bash infra/scripts/tests/start-dev-bot-outbound-keyring-test.sh
```

Resultado: **PASS**, incluindo `38/38` cenários do parser, sintaxe shell e Compose base+DEV
renderizado com valores sintéticos. O CI versionado repete os gates estruturais. Isso não autoriza
nem comprova migração viva, atribuição ao usuário persistido, renovação de sessão/token,
backfill/readiness ou API; todos continuam **NOT EXECUTED / BLOCKED BY LOCAL HOST PERMISSIONS**.

### Guia de acesso a `/audit`

O acesso e cumulativo: exige a authority bruta `ROLE_TENANT_AUDIT` **e** um tenant efetivo valido.
Nenhuma role administrativa substitui Audit.

| Identidade/contexto | Resultado para `/audit` |
|---|---|
| `ROLE_TENANT_AUDIT` em realm tenant, com `tenant_id` valido | Permitido somente para o proprio tenant, sujeito aos gates da API. |
| `ROLE_TENANT_ADMIN` sem Audit | Negado. |
| `ROLE_SUPER_ADMIN` sem Audit, inclusive impersonando tenant | Negado. |
| `ROLE_SUPER_ADMIN + ROLE_TENANT_AUDIT` no contexto global | Negado: a role nao cria tenant implicitamente. |
| `ROLE_SUPER_ADMIN + ROLE_TENANT_AUDIT` com impersonacao explicita de tenant ativo | Elegivel quando o tenant efetivo coincide com o path; ainda sujeito aos gates da API. |

O provisionador DEV `infra/keycloak/provision/dev.sh` atribui
`ROLE_SUPER_ADMIN + ROLE_TENANT_AUDIT` ao usuario exato `djmarcellopedrosa@gmail.com`. Isso governa
import novo, nao o realm ja persistido: o volume local exige a migracao/reconciliacao controlada,
invalidacao da sessao e novo login antes de o token servir como evidencia.

A rota frontend canonica e `/audit` (e `/audit/{conversationId}` no detalhe). `/index` nao existe e
nao e alias. `/inbox` e seus filhos existem somente como redirect legado HTTP `307` para o path
canonico. Mesmo com rota, role e tenant corretos, a API somente abre depois de protecao habilitada,
allowlist exata e readiness duravel+live do fingerprint final com os cinco riscos em zero. No
checkpoint atual, backfill/readiness nao foram executados e a API permanece desligada.

Valide o contrato dos realms antes de iniciar ou publicar uma imagem:

```bash
bash infra/keycloak/bootstrap/validate-realm-token-contracts.sh
```

Depois de migrar um realm persistido, encerre as sessoes antigas ou force a renovacao do access token. Alterar o script nao sobrescreve automaticamente todo o estado salvo no banco Keycloak; use os reconciliadores versionados.

### HML e PRD

Nao execute recovery diretamente sem change aprovado. O procedimento exige:

- backup restauravel do banco Keycloak;
- janela com todos os nodes Keycloak parados;
- secret tecnico previamente criado no secret manager;
- registro de owner, horario e evidencias, sem registrar o material secreto;
- remocao e verificacao das identidades temporarias;
- smoke test de login, refresh, logout, convite e criacao de realm.

## 6. Rotacao do secret tecnico

### Desenvolvimento local

1. Pare o backend para evitar requisicoes com o secret antigo.
2. Gere um novo valor de alta entropia e atualize somente `KEYCLOAK_PROVISIONING_CLIENT_SECRET` em `.env.dev.local`.
3. Execute `migrate-persisted-volume.sh`; ele atualiza o client persistido usando recovery controlado.
4. Suba a stack e confirme o inicializador e o backend.
5. Verifique que o secret anterior nao autentica mais.

### HML e PRD

Use rotacao coordenada pelo administrador da plataforma ou por automacao privilegiada separada. Atualize primeiro o Keycloak e o secret manager dentro da mesma janela, reinicie as workloads consumidoras e revogue o valor anterior. Nunca reative uma senha humana como fallback.

## 7. Troubleshooting

| Sintoma | Causa provavel | Acao |
|---|---|---|
| `invalid_grant` no `admin-cli` | Imagem/backend antigo ainda usa Password Grant. | Rebuild do backend e verificacao de que `KeycloakConfig` usa `client_credentials`. |
| `unauthorized_client` no client tecnico | Service Account desabilitada ou secret divergente. | Rodar o inicializador em banco novo ou a migracao em volume existente. |
| `403` ao criar realm | Role `create-realm` ausente no Service Account. | Corrigir role no realm `master`; nao conceder `realm-admin` global como atalho. |
| `403` ao gerir usuarios | Roles minimas nao atribuidas no realm alvo. | Incluir o realm em `KEYCLOAK_EXISTING_MANAGED_REALMS` e executar bootstrap administrativo controlado. |
| Usuario convidado autentica, mas `/dashboard` mostra acesso negado | O SPA esta com `fullScopeAllowed=false` sem role scope explicito; o token nao carrega `ROLE_TENANT_USER`/`ROLE_TENANT_ADMIN`. | Executar a migracao controlada do volume, renovar a sessao e confirmar `realm_access.roles` no token. Nao habilitar Full Scope como atalho. |
| `/audit` continua negado ao superadmin DEV apos a reconciliacao | Role/scope ausente no realm persistido ou access token anterior ainda ativo. | Confirmar a reconciliacao exata, invalidar somente as sessoes do usuario aprovado, autenticar novamente e verificar as duas roles administrativas sem `tenant_id`; nao habilitar Full Scope. |
| Billing pede MFA novamente logo depois do TOTP | O mapper `oidc-amr-mapper` existe, mas o volume nao possui as referencias `pwd`/`otp`, ou a sessao ainda usa token anterior. | Executar a migracao controlada, iniciar novamente, concluir **Refazer autenticacao com MFA** e usar o novo token; nunca aceitar `iat`, cookie ou flag frontend como prova. |
| Super Admin aparece com tenant `aaaaaaaa-...` | Mapper de teste permaneceu no `saas-admin` persistido. | Executar a migracao controlada, renovar a sessao e confirmar que o token novo nao possui `tenant_id`. |
| Backend nao inicia depois do init | Variavel tecnica ausente ou composicao Spring invalida. | Verificar logs do init e backend; nao contornar removendo `depends_on`. |
| `Esqueceu sua senha?` confirma a solicitação, mas o evento mostra `RESET_PASSWORD_ERROR`/`user_not_found` e nada chega | O usuário não existe ou não está habilitado no realm exato; o contato do Tenant e usuários de `saas-admin` não são copiados para o realm tenant. | Confirmar o realm da URL e consultar a aba de usuários. Se ausente, convidar/ativar o usuário no Tenant; se existir apenas na aplicação, tratar como divergência local-IAM e reconciliar de forma controlada. Não alterar SMTP. |
| `Esqueceu sua senha?` encontra o usuário, mas não envia mensagem | `smtpServer` ausente/divergente no realm persistido ou Mailpit/provider indisponível. | Em DEV/HML, conferir Mailpit no loopback e executar a migração controlada; em PRD, validar provider e change sem expor credencial. |
| Mensagem aparece no Mailpit, mas não chega ao Gmail | Comportamento esperado: Mailpit captura e não entrega. | Use Mailpit somente em DEV/HML; a entrega real é gate do SMTP transacional de PRD. |
| Senha nova funciona na sessão do link, mas um login novo termina em `AuthenticationFlowException`/credenciais inválidas | Estado legado do toggle deixou o pai 2FA `CONDITIONAL` e a folha OTP `DISABLED`; não é cache do navegador. | Aplicar a versão corrigida e executar a migração DEV autorizada; validar em fluxo OIDC novo. Diagnóstico exclusivo: ANL-00053. |
| Startup PRD rejeita SMTP | Host local/Mailpit, auth desligada, TLS ambíguo ou credencial incompatível. | Corrigir o arquivo owner-only conforme o provider; não relaxar o validador nem habilitar Mailpit. |
| Documento/slug aparece ocupado sem banco/realm | Onboarding antigo deixou metadado orfao. | Executar reconciliacao e remocao transacional guardada; nao apagar registro sem conferir dependencias. |

## 8. Verificacoes de seguranca

- o ambiente do backend nao contem `KEYCLOAK_ADMIN_USER` nem `KEYCLOAK_ADMIN_PASSWORD`;
- o client tecnico usa `serviceAccountsEnabled=true` e Direct Grants desabilitado;
- a conta possui `create-realm` no `master` e somente roles necessarias nos realms geridos;
- nao existem usuarios ou clients com prefixo temporario de recovery;
- logs nao exibem secrets, access tokens ou senhas;
- nenhum client do `saas-admin` emite `tenant_id`;
- `MultiRealmJwtConfig` rejeita Super Admin que carregue contexto tenant;
- o Super Admin sem `X-Tenant-ID` nao inicializa `TenantContext`;
- o realm criado contem `tenant_id`, audience da API, origins e redirect URIs do template vigente;
- o `saas-frontend-spa` mantem `fullScopeAllowed=false` e possui role scopes explicitos: somente
  `ROLE_SUPER_ADMIN` e `ROLE_TENANT_AUDIT` no realm administrativo e somente as roles
  tenant/fiscal aprovadas mais `ROLE_TENANT_AUDIT` nos realms tenant;
- `ROLE_TENANT_AUDIT` e non-composite e nao possui aresta de composicao/heranca com Tenant Admin
  ou Super Admin;
- os scripts v2.6.1 reconciliam a Service Account para a allowlist minima e o gate estatico rejeita
  privilegio excedente ou early-success por token funcional; a execucao no volume vivo esta pendente;
- first bootstrap, ownership/fingerprint do client técnico, grafo completo realm+client, inventário
  recovery, sessões `kcadm` e sinais são verificados fail-closed;
- o browser flow administrativo possui exatamente uma execucao de senha com AMR `pwd` e uma de OTP com AMR `otp`, ambas com max age de 900 segundos; a identidade permanente somente verifica e drift exige recovery explicito;
- o toggle de login preserva a execução OTP em `ALTERNATIVE`, sua prioridade,
  `CONFIGURE_TOTP` e credenciais; alterna o pai direto 2FA entre `DISABLED` e
  `CONDITIONAL`, valida integralmente o provider e recusa `false` fora de DEV;
- o reconciliador `reconcile-super-admin-identity.sh` atua somente em DEV, exige
  `ROLE_SUPER_ADMIN`, ancora a pessoa por `human_principal_id`, rejeita duplicidade/conflito e
  comprova `username` e `email` canônicos após a mutação;
- `reconcile-realm-smtp.sh` percorre somente a allowlist, mantém a senha fora de
  `argv`/logs, reconcilia apenas sob bootstrap/recovery e deixa a identidade
  permanente em modo de verificação;
- Mailpit existe apenas nos overrides DEV/HML, não publica SMTP no host, expõe a
  UI somente no loopback e usa armazenamento efêmero limitado;
- PRD não contém serviço Mailpit e o deploy exige host externo, auth e exatamente
  um modo TLS antes de renderizar a configuração efetiva;
- o parser JSON Bash puro está montado read-only nos dois serviços Keycloak e passa 46 cenários
  contra duplicações, decoys, trailing data e limites excedidos;
- nenhum mapper direto ou mapper alcancavel por client scope default/optional emite `tenant_id` no
  realm administrativo;
- somente o export DEV administrativo atribui `ROLE_TENANT_AUDIT` ao
  `djmarcellopedrosa@gmail.com`; HML/PRD/templates nao contem essa atribuicao;
- um token DEV novo, emitido depois da invalidacao da sessao, deve conter as duas roles
  administrativas e continuar sem `tenant_id`; essa prova viva permanece NOT EXECUTED;
- backfill/readiness permanecem NOT EXECUTED e a API de Auditoria permanece off;
- nenhum tenant ativo/provisionado aponta para banco fisico inexistente.

## 9. Rollback e recuperacao

Nao reverta para Password Grant e nao injete senha administrativa no backend. Se o rollout falhar:

1. interrompa novos onboardings;
2. preserve banco da plataforma, bancos tenant e banco Keycloak;
3. restaure a configuracao tecnica anterior a partir do secret manager, se ainda valida;
4. execute a reconciliacao de recursos parciais;
5. se necessario, restaure o backup Keycloak em ambiente isolado antes de qualquer acao no ambiente principal;
6. abra incidente com correlacao entre tenant ID, slug, banco e realm, sem incluir credenciais.

Para falha durante a reconciliacao de `ROLE_TENANT_AUDIT`, nao remova roles preexistentes e
nao restaure Full Scope. Interrompa antes de habilitar `/audit`, preserve o volume, remova a
identidade temporaria e repita a reconciliacao idempotente somente depois de corrigir a causa. Se a
sessao ja foi invalidada, um novo login continua obrigatorio mesmo quando a role mapping final nao
mudou.

Para reativar o MFA do login DEV, defina
`KEYCLOAK_ADMIN_LOGIN_MFA_ENABLED=true`, execute novamente
`infra/keycloak/bootstrap/migrate-persisted-volume.sh` e faça novo login. O
rollback não recria TOTP: ele reabilita os mesmos componentes e reaproveita a
credencial existente.

## 10. Referencias

- [ADR-0018](../adrs/ADR-0018-keycloak-realm-provisioning-automation.md)
- [REQ-00058](../product/requirements/REQ-00058-keycloak-password-recovery-smtp.md)
- [REQ-00059](../product/requirements/REQ-00059-temporary-all-roles-mfa-disablement.md)
- ANL-00053 — Diagnóstico canônico KC-DEV-AUTH-001
- [TP-00042](../delivery/plans/TP-00042-temporary-dev-super-admin-login-mfa-disablement.md)
- [TP-00044](../delivery/plans/TP-00044-keycloak-password-recovery-smtp.md)
- [UC-00002](../product/use-cases/UC-00002-tenant-management.md)
- [LL-BE-00056 — Lesson Learned](../delivery/lessons-learned/backend/LL-BE-00056-keycloak-local-volume-persistence.md)
- [LL-BE-00078 — Lesson Learned](../delivery/lessons-learned/backend/LL-BE-00078-keycloak-service-account-and-onboarding-compensation.md)
- [LL-BE-00080 — Lesson Learned](../delivery/lessons-learned/backend/LL-BE-00080-super-admin-token-must-not-carry-tenant-id.md)
- [Conversation Audit Operations Runbook](conversation-audit-operations-runbook.md)
- [Keycloak Bootstrap Admin Recovery](https://www.keycloak.org/server/bootstrap-admin-recovery)
- [Keycloak Server Administration Guide](https://www.keycloak.org/docs/latest/server_admin/)

## 11. Change Log

| Versao | Data | Mudanca |
|---|---|---|
| 2.8 | 2026-09-25 | Configura saas-theme em saas-admin e saas-bpfarias e dispensa obrigatoriedade de OTP (CONFIGURE_TOTP) nas identidades canônicas provisionadas. |
| 2.7 | 2026-09-24 | Documenta provisionamento multiambiente pela Admin REST API com isolamento SMTP e conciliação de UUID. |
| 2.6 | 2026-09-24 | Documenta UUID atribuído pelo Keycloak, conciliação fail-closed do Super Admin após Flyway e remove orientação residual baseada em exports JSON. |
| 2.5 | 2026-09-10 | Distingue `user_not_found` de falha SMTP, registra o isolamento de identidades por realm e define convite/ativação como pré-condição da recuperação tenant. |
| 2.4 | 2026-09-09 | Corrige o runbook do toggle: desabilita o pai direto 2FA, preserva `auth-otp-form=ALTERNATIVE`, orienta a recuperação do estado legado e aponta ANL-00053 como diagnóstico único. |
| 1.0 | 2026-08-14 | Referencia operacional consolidada para Service Account, bootstrap e recovery de volumes persistidos. |
| 1.1 | 2026-08-22 | Antes da implementacao, congelados os oito artefatos de `ROLE_TENANT_AUDIT`, scopes explicitos com `fullScopeAllowed=false`, atribuicao somente ao superadmin DEV, reconciliacao idempotente de volume persistido e invalidacao/renovacao de sessao; HML/PRD permanecem NOT EXECUTED. |
| 1.2 | 2026-08-22 | Antes do runtime, congelados placeholder owner-only para a credencial temporaria DEV, allowlist exata de realms, remocao de mapper pela claim/atributo `tenant_id` e gate de zero usuarios em HML/PRD. |
| 1.3 | 2026-08-22 | Reconciliados exports/scripts e gerador/contrato do secret local como implementados e estaticamente verificados por validator+2 testes shell; inclusao no `.env.dev.local`, volume persistido, sessao nova, backend-real e HML/PRD permanecem NOT EXECUTED. |
| 1.4 | 2026-08-22 | Antes de novo patch de script, congelados Audit non-composite/sem heranca administrativa, tratamento fail-closed de drift, reconciliacao forcada da Service Account para allowlist minima e deteccao de tenant_id tambem em client scopes. O novo hardening permanece PENDING IMPLEMENTATION/EVIDENCE. |
| 1.5 | 2026-08-22 | Antes de novo patch, congelados zero segredo em argv host/container, paginacao administrativa fail-closed, prova exata no init normal e reconciliacao segura dos mappers/scopes geridos. v2.6 e runtime permanecem PENDING. |
| 1.6 | 2026-08-22 | Reconciliado o hardening v2.6 como implementado e estaticamente verificado pelos tres gates shell; adicionada a matriz operacional de acesso a `/audit`, incluindo o superadmin DEV no JSON, migracao/sessao exigidas, inexistencia de `/index`, redirect legado `/inbox` e dependencia de readiness. Volume/sessao/backfill/readiness seguem NOT EXECUTED e API off. |
| 1.7 | 2026-08-22 | Reconciliado o fechamento estrutural v2.6.1: first-bootstrap/ownership, fingerprint não interativo, grafo completo realm+client, recovery estrutural, sessões/sinais seguros, parser JSON Bash puro bounded e mounts read-only. Quatro gates shell e 38 cenários passaram; volume/sessão/backfill/readiness continuam bloqueados e API off. |
| 1.8 | 2026-08-25 | Corrigido o contrato operacional da Service Account para distinguir quatro grants diretos do conjunto efetivo de cinco roles produzido pela heranca nativa de `view-users` para `query-groups`; o parser estrutural passa 39 cenarios. Reconciliacao viva e restart do backend permanecem pendentes. |
| 1.9 | 2026-09-06 | Documenta o corretivo repository-local TP-00037: referencias AMR `pwd`/`otp` com 900 segundos, verificacao least-privilege no start e reconciliacao somente no first bootstrap/recovery; volume e token reais permanecem nao executados. |
| 2.0 | 2026-09-07 | Documenta TP-00042 corrigido: preserva CONFIGURE_TOTP, credenciais e AMR; desabilita apenas provider/execução no realm DEV, com rollback pela mesma reconciliação e impacto fail-closed explícito. |
| 2.1 | 2026-09-07 | Endurece TP-00042: valida a representação completa de CONFIGURE_TOTP e preserva nome, identidade, prioridade e config no PUT explícito; registra 46 cenários estruturais verdes. |
| 2.2 | 2026-09-07 | Atualiza a identidade Super Admin DEV para `djmarcellopedrosa@gmail.com` e documenta a reconciliação segura de realms persistidos por identidade humana estável, sem atuação em HML/PRD. |
| 2.3 | 2026-09-07 | Documenta recuperação por realm, Mailpit efêmero em DEV/HML, SMTP externo em PRD e herança/reconciliação automática para tenants e saas-admin. |
