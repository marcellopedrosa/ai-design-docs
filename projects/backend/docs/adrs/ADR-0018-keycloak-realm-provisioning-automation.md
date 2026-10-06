---
document_id: "ADR-0018"
primary_nature: "Decisao"
objective: "Registrar a decisão arquitetural “Automacao do provisionamento de realms Keycloak”, seus motivadores, alternativas e consequências."
scope: "Decisão, componentes, integrações e limites explicitamente descritos em “Automacao do provisionamento de realms Keycloak”."
non_objectives: "Não implementar a decisão, substituir requisitos relacionados nem atestar capabilities ou ambientes sem evidência explícita."
owner: "@SecurityOAuth, @MultiTenantEng, @DevOps-Agent"
status: "Accepted"
date: "2026-07-24"
version: "4.1"
last_reviewed: "2026-09-24"
keywords: "adr, decisao, arquitetura, automacao, do, provisionamento, de, realms, keycloak"
related_files: "docs/adrs/README.md, docs/adrs/ADR-0005-multi-tenancy-architecture.md, docs/onboarding/keycloak-provisioning-identity.md, docs/product/use-cases/UC-00002-tenant-management.md, docs/product/use-cases/UC-00036-user-profile.md, docs/product/requirements/REQ-00041-chatbot-conversation-audit.md, docs/product/requirements/REQ-00058-keycloak-password-recovery-smtp.md, docs/product/requirements/REQ-00059-temporary-all-roles-mfa-disablement.md, docs/product/requirements/REQ-00061-temporary-tenant-first-login-mfa-disablement.md, artefatos de análise/ANL-00051-super-admin-dev-mfa-usage-inventory.md, artefatos de análise/ANL-00053-keycloak-empty-conditional-2fa-flow.md, artefatos de análise/ANL-00054-tenant-first-login-mfa-inventory.md, docs/delivery/plans/TP-00042-temporary-dev-super-admin-login-mfa-disablement.md, docs/delivery/plans/TP-00044-keycloak-password-recovery-smtp.md, docs/delivery/plans/TP-00047-temporary-super-admin-invoicing-mfa-waiver.md, docs/delivery/plans/TP-00050-temporary-tenant-first-login-mfa-disablement.md, docs/onboarding/conversation-audit-operations-runbook.md, docs/delivery/plans/implementation_plans/backend/IP-BE-5.2.3-keycloak-protocol-mapper-realm-template.md, docs/delivery/lessons-learned/backend/LL-BE-00078-keycloak-service-account-and-onboarding-compensation.md, docs/delivery/lessons-learned/backend/LL-BE-00080-super-admin-token-must-not-carry-tenant-id.md"
code_references: "TenantProvisionedEvent, RealmProvisioningPort, KeycloakRealmProvisioningAdapter, KeycloakTenantRealmRepresentationFactory, CanonicalAdminIdentityReconciler, KeycloakRealmSmtpProperties, KeycloakConfig, infra/keycloak/bootstrap/migrate-persisted-volume.sh, infra/keycloak/bootstrap/reconcile-super-admin-identity.sh, infra/keycloak/bootstrap/reconcile-realm-smtp.sh, infra/keycloak/bootstrap/reconcile-admin-login-mfa.sh, infra/keycloak/bootstrap/reconcile-tenant-first-login-mfa.sh, MultiRealmJwtConfig, TenantContextFilter, historical: infra/keycloak/dev/saas-admin-realm.json, historical: infra/keycloak/dev/saas-bpfarias-realm.json, historical: infra/keycloak/hml/saas-admin-realm.json, historical: infra/keycloak/hml/saas-bpfarias-realm.json, .env.example, docker-compose.yml, docker-compose.override.yml, docker-compose.hml.yml, docker-compose.prd.yml, infra/deploy/production.env.example, infra/scripts/deploy-production.sh"
principal_statement: "O backend acessa a Keycloak Admin API exclusivamente com client confidencial e Service Account via OAuth 2.0 Client Credentials; cada realm recebe SMTP ambiental, e os realms administrativos e de tenant preservam sua capacidade MFA sob toggles reversiveis temporariamente desativaveis em DEV, HML e PRD, enquanto credenciais administrativas permanecem restritas ao bootstrap."
---

# ADR-0018 - Automacao do provisionamento de realms Keycloak

- Data original: 2026-07-24
- Ultima revisao: 2026-09-23
- Status: Accepted
- Versao: 3.8
- Estado da extensao `ROLE_TENANT_AUDIT`: hardening estrutural Keycloak v2.6.1 IMPLEMENTED / STATIC GATES GREEN; volume persistido, reconciliacao viva, sessao/token novos, backfill/readiness e ambientes externos NOT EXECUTED por bloqueio de permissoes locais; API OFF
- Owners: @SecurityOAuth, @MultiTenantEng, @DevOps-Agent

## 1. Contexto

O projeto usa isolamento de autenticacao por realm e banco dedicado por escritorio, conforme a [ADR-0005](./ADR-0005-multi-tenancy-architecture.md). A criacao de um tenant precisa produzir, como uma unica operacao de negocio:

1. banco PostgreSQL `saas_{slug}`;
2. migrations e datasource dedicado;
3. metadados no banco da plataforma;
4. realm Keycloak `saas-{slug}` configurado pelo template vigente;
5. evento `TenantProvisionedEvent` somente depois das quatro etapas anteriores.

A implementacao anterior obtinha token administrativo com Password Grant no client `admin-cli`, usando `KEYCLOAK_ADMIN_USER` e `KEYCLOAK_ADMIN_PASSWORD`. Essas variaveis pertencem ao bootstrap de uma instalacao nova do Keycloak; elas nao redefinem a senha do realm `master` quando o volume PostgreSQL ja existe. Depois do hardening de seguranca, o backend continuou acoplado a essa senha humana e passou a receber `invalid_grant: Invalid user credentials` ao criar um escritorio.

A falha tambem revelou uma fronteira transacional incompleta: o banco fisico era removido, mas metadados do tenant podiam permanecer, bloqueando nova tentativa por documento ou slug.

## 2. Decisao

### 2.1 Identidade tecnica

O backend deve acessar a Keycloak Admin API exclusivamente com um client confidencial e Service Account no realm `master`, por OAuth 2.0 Client Credentials:

- client ID: configurado por `KEYCLOAK_PROVISIONING_CLIENT_ID`;
- secret: configurado por `KEYCLOAK_PROVISIONING_CLIENT_SECRET`;
- grant: `client_credentials`;
- role global minima: `create-realm`;
- grants diretos adicionais por realm administrado: somente `manage-users`, `query-users`,
  `view-users` e `view-realm` nos realms estaticos. No Keycloak 26.6.x, `view-users` e composite
  nativa de `query-users` e `query-groups`; portanto o conjunto efetivo exato possui tambem
  `query-groups`, sem que essa role receba grant direto.

`KEYCLOAK_ADMIN_USER` e `KEYCLOAK_ADMIN_PASSWORD` sao credenciais exclusivas do bootstrap do container Keycloak. Elas nao podem ser injetadas no backend nem usadas em requisicoes de runtime.

O client tecnico e criado ou verificado pelo servico one-shot `keycloak-provisioning-init`, que deve concluir com sucesso antes da inicializacao do backend.

### 2.2 Fronteira Clean Architecture

O caso de uso depende da porta de saida `RealmProvisioningPort`. O detalhe Keycloak fica no adaptador `KeycloakRealmProvisioningAdapter` e na configuracao `KeycloakConfig`.

Essa separacao implica:

- a camada de aplicacao nao conhece grant OAuth, endpoint REST, SDK ou representacoes do Keycloak;
- provisionamento e exclusao compensatoria fazem parte do contrato da porta;
- a exclusao de realm e idempotente: HTTP 404 significa compensacao concluida;
- testes do caso de uso usam um mock da porta, sem infraestrutura real.

### 2.3 Construção programática do realm tenant

O adaptador constrói `RealmRepresentation` e suas representações filhas diretamente
em Java. Realm, tenant ID, display name, frontend e SMTP são valores tipados; não
existe template, interpolação, import ou export JSON no caminho de criação de um
novo tenant. A factory é determinística e sem I/O, e o adapter mantém a chamada
única `keycloak.realms().create(...)` e a compensação vigente.
  ambientais do transporte.

Nao e permitida substituicao textual sobre o JSON bruto. Slug, UUID, nome e origin do frontend sao validados antes da chamada externa, evitando truncamento, JSON injection, realm path injection e redirects arbitrarios.

### 2.4 Consistencia do onboarding

O provisionamento continua sincrono porque o sucesso exibido ao Super Admin significa que banco, metadados e realm ja existem. O evento final nao pode ser publicado antes do realm.

Se qualquer etapa falhar, o caso de uso executa compensacoes idempotentes na ordem:

1. remover o realm se sua criacao foi tentada, inclusive no caso de timeout depois da criacao;
2. remover o datasource dinamico se registrado;
3. remover metadados do tenant pelo `TenantId` se persistidos;
4. remover o banco fisico dedicado.

A resposta externa e generica e nao inclui secret, credencial, URL interna nem mensagem do provedor. O erro tecnico completo permanece apenas no log protegido.

### 2.5 Volumes Keycloak existentes

Alterar as variaveis de bootstrap nao modifica usuarios no volume persistido. Para migrar um ambiente existente, deve ser usado `infra/keycloak/bootstrap/migrate-persisted-volume.sh`:

1. parar todos os nodes Keycloak;
2. criar uma conta administrativa temporaria com o comando oficial `bootstrap-admin user`;
3. iniciar o Keycloak e provisionar a Service Account permanente;
4. remover mapeadores legados de `tenant_id` do realm administrativo;
5. remover todas as identidades temporarias;
6. reiniciar e validar somente o fluxo permanente por Client Credentials.

Nao se deve apagar o volume como primeira resposta, pois isso elimina realms, usuarios e configuracoes locais. O procedimento operacional completo esta em [Keycloak Provisioning Identity](../onboarding/keycloak-provisioning-identity.md).

### 2.6 Contrato de contexto global e tenant

O realm `saas-admin` representa identidades globais. Nenhum client desse realm emite `tenant_id`. Um token com `ROLE_SUPER_ADMIN` e essa claim e rejeitado pelo Resource Server, mesmo que issuer, assinatura, audience e authorized party sejam validos.

Os realms `saas-{slug}` representam identidades tenant e seu SPA emite exatamente um `tenant_id` hardcoded com o UUID canonico do escritorio. Para um Super Admin entrar no contexto de um escritorio, o frontend envia `X-Tenant-ID`; o backend valida que o UUID existe e esta ativo antes de criar o contexto e a authority operacional temporaria.

Essa separacao e aplicada em quatro camadas:

1. exports e templates Keycloak;
2. migracao dos realms persistidos;
3. validacao fail-closed em `MultiRealmJwtConfig`;
4. resolucao explicita em `TenantContextFilter`.

### 2.7 Perfil explicito de auditoria conversacional

A decisao de 2026-08-22 introduz `ROLE_TENANT_AUDIT` como capacidade explicita e de menor
privilegio para a auditoria de conversas. A role deve existir tanto no realm administrativo quanto
nos realms tenant, mas sua presenca no token nao cria contexto tenant implicitamente:

- no `saas-admin`, o SPA pode emitir `ROLE_SUPER_ADMIN` e `ROLE_TENANT_AUDIT`, sempre sem
  `tenant_id`; o acesso a um tenant continua condicionado a impersonacao explicita por
  `X-Tenant-ID` validado;
- no `saas-{slug}`, o SPA pode emitir `ROLE_TENANT_AUDIT` como perfil tenant, sempre com o
  `tenant_id` hardcoded e canonico do escritorio;
- `saas-frontend-spa` permanece com `fullScopeAllowed=false`; o scope administrativo deve conter
  explicitamente apenas `ROLE_SUPER_ADMIN` e `ROLE_TENANT_AUDIT`, enquanto o scope tenant deve
  conter explicitamente as quatro roles tenant/fiscal vigentes e `ROLE_TENANT_AUDIT`;
- o usuario exato `djmarcellopedrosa@gmail.com` recebe a nova role somente no export de DEV do realm
  administrativo. Sua credencial inicial temporaria deve ser somente o placeholder
  `${KEYCLOAK_DEV_SUPERADMIN_INITIAL_PASSWORD}`, resolvido por secret local owner-only e jamais por
  valor literal versionado. HML, PRD e templates nao recebem usuario ou atribuicao humana
  predefinida; o validador exige `.users` vazio nesses dois ambientes;
- a reconciliacao do volume local opera somente sobre a allowlist exata
  `KEYCLOAK_EXISTING_MANAGED_REALMS`; um realm apenas compartilhar o prefixo `saas-` nao o torna
  alvo. A remocao de mapper tenant no realm administrativo identifica tanto nomes legados quanto
  `claim.name`/`user.attribute` iguais a `tenant_id`, evitando que um nome alternativo preserve a
  claim proibida;
- a identidade humana DEV usa `human_principal_id=dev-superadmin-primary` como ancora estavel.
  O reconciliador atualiza somente `username`, `email` e essa ancora para
  `djmarcellopedrosa@gmail.com`, exige `ROLE_SUPER_ADMIN`, rejeita destino pertencente a outro
  usuario e nao semeia identidade humana em HML/PRD.

O contrato de bootstrap deve ser materializado nos oito artefatos versionados abaixo:

1. `infra/keycloak/provision/dev.sh`;
2. `historical: infra/keycloak/dev/saas-bpfarias-realm.json`;
3. `historical: infra/keycloak/hml/saas-admin-realm.json`;
4. `historical: infra/keycloak/hml/saas-bpfarias-realm.json`;
5. `historical: infra/keycloak/prd/saas-admin-realm.json`;
6. `historical: infra/keycloak/prd/saas-bpfarias-realm.json`;
7. `infra/keycloak/realm-template.json` (referencia estatica historica do validador);
8. `KeycloakTenantRealmRepresentationFactory` (contrato executavel de novos tenants).

Esses arquivos governam realms novos e nao atualizam um volume ja persistido. Para realms
existentes, uma reconciliacao pela Admin API deve ser revisada, idempotente e fail-closed: criar a
role se ausente, conferir exatamente um client SPA por realm, adicionar somente o scope esperado,
localizar exatamente um usuario DEV pelo username e e-mail aprovados, preservar
`ROLE_SUPER_ADMIN`, adicionar `ROLE_TENANT_AUDIT` e verificar o estado final. Zero ou mais de um
usuario/client deve abortar sem atribuicao. A identidade permanente de onboarding nao recebe
`manage-realm` como atalho; a mutacao pontual reutiliza o recovery temporario, remove todas as
identidades temporarias e nao registra segredo ou token.

Depois da atribuicao ou mudanca de scope, as sessoes do usuario DEV devem ser invalidadas e o
login renovado antes da validacao do token. Token emitido anteriormente nao serve como evidencia.
HML/PRD exigem change, backup, janela e aprovacao separados e permanecem **NOT EXECUTED**. Depois
do freeze, os oito JSONs, a reconciliacao versionada, o validador e seus testes shell foram
implementados localmente. O validador de contratos e os dois testes shell passaram. Isso e
evidencia estatica: a reconciliacao do volume Keycloak vivo, a atribuicao persistida, a invalidacao
de sessao e o token novo permanecem **NOT EXECUTED / BLOCKED BY LOCAL HOST ACCESS**.

### 2.8 Freeze docs-first de hardening da reconciliacao Audit (2026-08-22)

Antes de novo patch dos scripts/validadores, ficam congeladas estas invariantes cumulativas:

- `ROLE_TENANT_AUDIT` e sempre uma realm role `composite=false`. Ela nao inclui
  `ROLE_TENANT_ADMIN`/`ROLE_SUPER_ADMIN` e nao pode ser membro de composite que faca qualquer uma
  dessas roles herda-la. Concessao conjunta ocorre apenas por mappings independentes;
- em realm persistido, o reconciliador inspeciona os dois sentidos dessa relacao. Drift simples e
  inequivoco dentro da allowlist gerida e removido; ambiguidade, falha de remocao ou composite
  residual aborta fail-closed. A verificacao final exige Audit non-composite e nenhuma aresta de
  heranca com Tenant Admin/Super Admin;
- a Service Account tecnica permanente e sempre reconciliada durante a migracao, mesmo quando
  `client_credentials` ja retorna sucesso. O procedimento compara privilegios efetivos com a
  allowlist minima da Secao 2.1: quatro grants diretos por realm e o conjunto efetivo de cinco
  roles que inclui somente a heranca nativa `query-groups`. O procedimento adiciona somente
  ausencias autorizadas, revoga grants diretos excedentes e verifica o estado final. Qualquer
  outro privilegio herdado/ambiguo que nao possa ser removido com seguranca aborta; token
  bem-sucedido nunca e criterio de early-success;
- a ausencia de `tenant_id` no realm administrativo e verificada sobre todos os caminhos efetivos
  de emissao: mappers diretos e mappers vindos de client scopes default/optional, inclusive scopes
  herdados/atribuídos ao client. O reconciliador remove a origem proibida somente quando o alvo e
  inequivocamente gerido; scope compartilhado/ambiguo ou claim residual falha fechado.

Os passes estaticos anteriores continuam evidencia historica do contrato v2.4, mas nao cobrem
estas novas asserts. Este hardening esta **FROZEN / PENDING IMPLEMENTATION / PENDING EVIDENCE**;
nao autoriza volume, sessao, HML ou PRD.

### 2.9 Freeze corretivo de credenciais, paginacao e prova exata (2026-08-22)

Uma revisao independente posterior aos testes estaticos v2.5 encontrou superficies que precisam
ser fechadas antes da migracao do volume persistido:

- senha/secret de recovery, bootstrap ou Service Account nao pode ser expandido em `argv`, nem no
  host Compose nem em processo filho dentro do container. O canal de entrada deve ser suportado
  pela ferramenta, efemero e owner-only, e o teste precisa observar semanticamente os argumentos;
- toda enumeracao paginada da Admin API, inclusive clients, users e composites, deve detectar
  pagina cheia repetida, item duplicado, falta de progresso e limite excedido, abortando
  fail-closed sem loop ou estado parcial declarado pronto;
- `client_credentials` funcional nao prova least privilege. O init normal somente pode retornar
  ready apos verificar o conjunto efetivo exato; se nao puder provar ou remediar sem credencial
  privilegiada, deve falhar e encaminhar para a reconciliacao forcada documentada;
- no `saas-admin`, mappers diretos e client scopes default/optional efetivos dos clients geridos
  devem ser reconciliados. Origem dedicada e inequivocamente gerida pode ser removida; origem
  compartilhada, client fora do escopo gerido ou claim residual aborta sem mutacao ambigua.

Esta correcao v2.6 esta **FROZEN / PENDING IMPLEMENTATION / PENDING EVIDENCE**. Os passes v2.5
continuam historicos, mas nao autorizam volume, sessao, backend-real ou qualquer ambiente externo.

### 2.10 Reconciliacao pos-freeze do hardening Keycloak v2.6 (2026-08-22)

Depois do freeze da Secao 2.9, os scripts versionados implementaram cumulativamente o hardening
v2.5/v2.6: nenhum password/secret segue em `argv` host/container; as enumeracoes administrativas
usam paginacao bounded com deteccao de pagina repetida, duplicacao e falta de progresso; o init
normal prova o conjunto efetivo exato da Service Account antes de declarar readiness; e a
reconciliacao de mappers/client scopes somente remove origens dedicadas e inequivocamente geridas,
falhando fechado para compartilhamento, origem desconhecida ou claim residual. Os gates de
composite/role inheritance e least privilege da Secao 2.8 permanecem cumulativos.

Os tres gates shell estaticos passaram:

- `infra/scripts/tests/keycloak-bootstrap-hardening-test.sh`;
- `infra/keycloak/bootstrap/validate-realm-token-contracts.sh`;
- `infra/scripts/tests/start-dev-bot-outbound-keyring-test.sh`.

Esta evidencia e **IMPLEMENTED / STATICALLY VERIFIED LOCAL**. Nenhum script de migracao foi
executado contra o volume Keycloak persistido; atribuicao viva, invalidacao de sessao, novo login,
token autenticado, backfill e readiness de dados continuam **NOT EXECUTED / BLOCKED BY LOCAL
PERMISSIONS**. A API de Auditoria permanece desligada, e HML/PRD nao foram acessados.

### 2.11 Fechamento estrutural v2.6.1 do bootstrap e da recuperacao (2026-08-22)

Uma revisão independente posterior ao primeiro passe v2.6 ampliou, sem mudar a decisão de menor
privilégio, a prova fail-closed necessária antes do runtime:

- first bootstrap pode usar a identidade humana apenas para inventariar o client técnico; somente
  ausência autoriza criação, enquanto client persistido inacessível, duplicado ou reservado aborta;
- clients geridos recebem marcadores de ownership versionados e fingerprint estritamente
  confidencial/service-account, com todos os fluxos interativos desabilitados;
- a ausência de herança de Audit cobre o grafo completo de realm roles e client roles, direto e
  transitivo; somente arestas diretas geridas de Tenant Admin/Super Admin podem ser removidas;
- inventários de recovery são estruturais e distinguem candidatos reservados de identificadores
  externos arbitrários, inclusive federados ou contendo vírgulas;
- token, client, mapper e recovery page são avaliados por um parser JSON Bash puro, bounded e
  fail-closed, que rejeita duplicações, decoys aninhados/escapados, profundidade/tamanho excedidos e
  trailing data;
- o mesmo parser é montado read-only nos serviços `keycloak` e `keycloak-provisioning-init`; sua
  ausência ou ilegibilidade aborta antes da autenticação ou mutação;
- arquivos de sessão `kcadm` são owner-only e a terminação por `INT`/`TERM` encerra com
  `130`/`143`, executando cleanup sem prosseguir a reconciliação.

O fechamento está **IMPLEMENTED / STATICALLY VERIFIED LOCAL** por 39 cenários estruturais, teste
adversarial do bootstrap, contrato dos realms, teste start-dev/keyring, sintaxe shell e renderização
Compose base+DEV com valores sintéticos. O pipeline versionado executa os novos gates. Essa prova
não consulta o volume persistido nem substitui atribuição viva, sessão/token novos ou smoke
autenticado; esses passos continuam **NOT EXECUTED / BLOCKED BY LOCAL HOST PERMISSIONS**. API off;
HML/PRD intocados.

### 2.12 Recuperação de senha e SMTP por realm

O link de recuperação do Keycloak depende simultaneamente de
`resetPasswordAllowed=true` e de `smtpServer` no realm que autentica o usuário.
Configurar SMTP no realm `master`, no container ou na Central de Notificações não
propaga essa configuração para `saas-admin` nem para `saas-{slug}`.

Fica decidido que:

- DEV usa Mailpit interno em `mailpit:1025`, sem autenticação/TLS, com UI
  publicada somente no loopback do host e armazenamento efêmero limitado;
- HML e PRD não contêm serviço Mailpit e exigem SMTP externo, autenticado,
  com exatamente um modo TLS habilitado e credencial fora de Git;
- `KeycloakRealmProvisioningAdapter` aplica a configuração ambiental ao template
  de todo novo tenant, sem pedir SMTP particular ao escritório;
- `reconcile-realm-smtp.sh` verifica a allowlist no startup normal e somente a
  identidade temporária de bootstrap/recovery pode corrigir realms persistidos;
- o SMTP de IAM permanece separado do provider-neutral Notification Center. A
  primeira versão usa um transporte da plataforma por ambiente; SMTP por tenant
  exigirá decisão posterior sobre domínio, custódia, rotação, auditoria e fallback;
- a senha SMTP nunca segue em `argv` ou log. Como o Keycloak pode devolvê-la
  mascarada, a verificação aceita apenas o marcador opaco conhecido e uma rotação
  sempre executa reconciliação privilegiada, sem inferir o valor secreto.
- o start de HML e PRD recebe `TF_VAR_contadorfiscal_smtp_password` do escopo
  protegido de cada ambiente, valida sua presença antes de qualquer mutação e a
  encaminha somente ao processo de provisionamento; o nome comum não implica
  compartilhar o valor entre ambientes;
- `saas-admin` e `saas-bpfarias` são reconciliados pelo mesmo provisionador Admin
  API na criação e nas reexecuções; DEV nunca depende dessa variável externa.

Esta decisão está implementada no repositório. Nenhum volume vivo, HML, PRD ou
provedor externo foi acessado; entrega real e reputação de e-mail permanecem gates
ambientais próprios.

### 2.13 Toggle reversível do MFA no login administrativo multiambiente

A decisão humana registrada no
[REQ-00059](../product/requirements/REQ-00059-temporary-all-roles-mfa-disablement.md)
mantém a capacidade MFA do realm `saas-admin`, mas suspende temporariamente sua
execução quando `KEYCLOAK_ADMIN_LOGIN_MFA_ENABLED=false`. Durante a dispensa
vigente, `false` é um estado válido em DEV, HML e PRD. O mecanismo e o caminho de
rollback continuam preservados; a reativação depende de decisão humana explícita
dos owners de Produto e Segurança, baseada no amadurecimento do uso da ferramenta.

O toggle altera somente estados já geridos e inequivocamente identificados:

- `CONFIGURE_TOTP.enabled` muda entre `true` e `false`;
- o pai direto do ramo condicional que contém a única execução `auth-otp-form`
  muda entre `CONDITIONAL` e `DISABLED`;
- `auth-otp-form` permanece `ALTERNATIVE` nos dois estados;
- provider TOTP, required action, execução OTP, credenciais existentes e mapper
  de `amr` permanecem presentes, permitindo rollback sem recriação ou evidência
  sintética.

O reconciliador identifica o pai pela relação estrutural `authenticationFlow` /
`level` devolvida pela Admin API e exige a condição
`conditional-user-configured` como irmã direta da folha OTP. Nome visual não é
identidade. Topologia ausente, duplicada ou ambígua falha antes de mutação. A
combinação `pai=CONDITIONAL` e `auth-otp-form=DISABLED` é proibida porque produz
um ramo selecionado sem autenticador executável. O diagnóstico e histórico desse
defeito existem somente na
ANL-00053.

O browser flow é uma configuração do realm, não de uma role. Portanto, o estado
temporário `false` afeta o login de todas as identidades do `saas-admin`, inclusive
o perfil Commercial, e não apenas `ROLE_SUPER_ADMIN`, nos três ambientes. Ela não
amplia autorização de aplicação: operações Billing protegidas continuam limitadas
pelas authorities e roles definidas no ADR-0050, e RBAC, tenant scope, purpose,
SoD, seals e auditoria continuam independentes.

Alterar arquivos versionados, importar export ou reiniciar containers não
reconcilia automaticamente um realm já gravado no volume PostgreSQL. A execução de
`migrate-persisted-volume.sh`, de reconciliação forçada ou de qualquer mutação
stateful exige autorização ambiental separada com ambiente, alvo e efeito
declarados; ela está excluída da autorização repository-local do REQ-00059. No
rollback autorizado, a flag volta a `true`, `CONFIGURE_TOTP` é habilitado, a
folha volta a `auth-otp-form=ALTERNATIVE` e somente então o pai é restaurado como
`CONDITIONAL`. O estado final é verificado fail-closed.

### 2.14 Toggle reversivel do enrollment MFA nos realms de tenant

REQ-00061 corrige uma fronteira omitida pelo inventario anterior: usuarios
convidados para um realm de tenant recebem `CONFIGURE_TOTP` diretamente em
`KeycloakAdminAdapter.createUserAndGetActionUrl`. O toggle
`KEYCLOAK_TENANT_FIRST_LOGIN_MFA_ENABLED` governa o estado `enabled` desse
required-action provider em cada realm tenant da allowlist, excluindo sempre
`saas-admin`.

O default seguro e `true`. Durante a dispensa temporaria vigente, DEV, HML e PRD
aceitam `false`.
O estado OFF preserva o provider, sua representacao integral, as required actions
ja atribuidas, usuarios, roles, credenciais e browser flows; apenas
`CONFIGURE_TOTP.enabled` passa a `false`. O codigo de convite continua atribuindo
`UPDATE_PASSWORD` e `CONFIGURE_TOTP`, de modo que o rollback para `true` reabilita
o enrollment pendente sem recriacao.

O estado do provider governa a selecao de uma nova required action, mas nao
retroage sobre uma authentication session que ja chegou a
`login-actions/required-action`. Aplicar OFF durante essa tela exige invalidar a
sessao efemera e iniciar uma nova autenticacao. Recarregar a URL antiga nao e
evidencia de falha do provider, e a invalidacao nao remove a action persistida.

Como required-action providers sao realm-wide, o efeito temporario alcanca todo
enrollment TOTP pendente no realm tenant, nao somente `ROLE_TENANT_ADMIN`. Isso
nao amplia RBAC. Realm ausente, alias/provider malformado, allowlist invalida ou
valor ambiental contraditorio falham antes de mutacao. A reconciliacao local
persistida foi autorizada pelo solicitante em 2026-09-09 e constitui evidencia
historica somente de DEV; a aplicacao em HML e PRD exige plano e autorizacao
ambiental proprios, sem reduzir o alvo normativo multiambiente.

## 3. Alternativas consideradas

### A. Password Grant com usuario administrador

Rejeitada. Acopla automacao a uma pessoa, exige senha reutilizavel, depende de Direct Access Grants e confunde credencial de bootstrap com credencial persistida.

### B. Credencial administrativa global compartilhada

Rejeitada. Aumenta blast radius, dificulta rotacao e nao permite atribuir ownership ou auditoria a uma workload.

### C. Service Account por Client Credentials e porta de infraestrutura

Selecionada. E adequada para comunicacao machine-to-machine, permite least privilege, rotacao independente e isolamento da tecnologia IAM na camada de infraestrutura.

### D. Provisionamento eventual por fila

Adiada. Pode ser adotada quando houver um estado de onboarding explicito e reconciliador. No contrato atual, retornar sucesso antes do realm criaria um tenant parcialmente utilizavel.

## 4. Consequencias

### Positivas

- nenhuma senha humana trafega no backend;
- restart nao depende da senha original usada para criar o volume;
- a identidade tecnica pode ser rotacionada e auditada isoladamente;
- falhas nao deixam documento, slug, banco ou realm orfaos;
- o adaptador pode ser substituido sem alterar o caso de uso;
- toda criacao usa o mesmo template versionado.

### Custos e riscos residuais

- `create-realm` e uma permissao sensivel e deve permanecer exclusiva da workload de onboarding;
- o secret tecnico precisa de secret manager em HML/PRD e procedimento de rotacao;
- um crash do processo durante compensacao ainda exige reconciliacao operacional;
- mudancas no template precisam de teste de contrato e rollout controlado;
- a identidade que cria um realm recebe acesso administrativo ao realm criado pelo Keycloak e nao deve ser reutilizada por outras workloads.
- sessoes antigas precisam ser renovadas depois de qualquer alteracao de protocol mapper.
- mudancas de role ou role scope tambem nao alteram tokens ja emitidos; logout/renovacao e prova com
  token novo fazem parte da mesma mudanca operacional.

## 5. Mapa de implementacao

| Responsabilidade | Artefato |
|---|---|
| Porta da aplicacao | `contexts/tenant/internal/application/port/out/RealmProvisioningPort.java` |
| Caso de uso e compensacao | `contexts/tenant/internal/application/TenantOnboardingUseCase.java` |
| Adaptador Keycloak | `contexts/tenant/internal/infrastructure/iam/KeycloakRealmProvisioningAdapter.java` |
| Client Credentials | `contexts/tenant/internal/infrastructure/iam/KeycloakConfig.java` |
| Representacao de novos realms | `KeycloakTenantRealmRepresentationFactory.java`, usando diretamente a API `RealmRepresentation` |
| Bootstrap idempotente | `infra/keycloak/bootstrap/ensure-management-service-account.sh` |
| Migracao de volume existente | `infra/keycloak/bootstrap/migrate-persisted-volume.sh` |
| Contrato estatico de tokens | `infra/keycloak/bootstrap/validate-realm-token-contracts.sh` |
| Validador JSON estrutural do runtime | `infra/keycloak/bootstrap/validate-keycloak-runtime-json.sh` |
| Configuracao SMTP de novos realms | `KeycloakRealmSmtpProperties`, `KeycloakTenantRealmRepresentationFactory` e `KeycloakRealmProvisioningAdapter` |
| SMTP de realms existentes | `infra/keycloak/bootstrap/reconcile-realm-smtp.sh` |
| Toggle de MFA do login administrativo multiambiente — alvo normativo DEV/HML/PRD, com evidencia executada somente em DEV | `infra/keycloak/bootstrap/reconcile-admin-login-mfa.sh`, `.env.example`, `docker-compose.yml`, `docker-compose.override.yml`, `infra/deploy/production.env.example` e `infra/scripts/deploy-production.sh` |
| Captura DEV/HML | Mailpit pinado em `docker-compose.override.yml` e `docker-compose.hml.yml` |
| Contrato PRD | `docker-compose.prd.yml`, `infra/deploy/production.env.example` e `infra/scripts/deploy-production.sh` |
| Contrato bootstrap de auditoria | Oito exports/templates listados na Section 2.7 - `IMPLEMENTED / STATICALLY VERIFIED LOCAL` |
| Hardening Keycloak v2.6.1 | Scripts de init/migracao, parser Bash puro, mounts e gates de argv, paginação, exact-init, ownership, grafo realm+client, sinais, recovery, least privilege e mapper ownership - `IMPLEMENTED / STATICALLY VERIFIED LOCAL` |
| Reconciliacao persistida de auditoria | Extensao idempotente versionada do recovery administrativo com hardening v2.6.1 - implementada estaticamente; execucao no volume vivo pendente |
| Validacao JWT e contexto | `MultiRealmJwtConfig.java`, `TenantContextFilter.java` |
| Orquestracao local | `docker-compose.yml`, `docker-compose.override.yml` e scripts `start-dev-*` |

## 6. Criterios de aceite

- o backend nao recebe `KEYCLOAK_ADMIN_USER` nem `KEYCLOAK_ADMIN_PASSWORD`;
- o token administrativo e obtido apenas por `client_credentials`;
- o inicializador tecnico termina antes do backend;
- um onboarding valido cria banco, metadados e realm com `tenant_id` completo;
- falha simulada do Keycloak remove realm, datasource, metadados e banco;
- uma segunda compensacao nao falha quando o realm ja nao existe;
- display name com aspas ou caracteres HTML continua sendo apenas um valor JSON;
- backend reinicia com volume Keycloak persistido sem depender de senha humana;
- nao existem usuarios ou clients temporarios apos a migracao.
- token de `saas-admin` com `ROLE_SUPER_ADMIN` nao possui `tenant_id`;
- token tenant possui UUID canonico e o Super Admin somente entra em tenant por `X-Tenant-ID` validado;
- o CI rejeita qualquer mapper de tenant nos exports administrativos.
- os oito artefatos definem `ROLE_TENANT_AUDIT` e scope explicito com
  `fullScopeAllowed=false` conforme o tipo de realm;
- somente o superadmin DEV aprovado recebe `ROLE_SUPER_ADMIN` e `ROLE_TENANT_AUDIT` no export;
- a reconciliacao de um volume persistido pode ser repetida sem duplicar role/scope/mapping e
  falha fechada diante de identidade ou client ambiguos;
- `ROLE_TENANT_AUDIT` permanece non-composite e sem qualquer heranca/composicao com
  `ROLE_TENANT_ADMIN` ou `ROLE_SUPER_ADMIN` depois da reconciliacao;
- a Service Account permanente termina com exatamente a allowlist minima da Secao 2.1, sem
  early-success por `client_credentials` nem privilegio efetivo excedente;
- nenhum mapper direto ou proveniente de client scope default/optional pode emitir `tenant_id` no
  realm administrativo; origem compartilhada/ambigua falha fechado;
- nenhum password/secret de bootstrap, recovery ou Service Account e transportado em `argv` no
  host ou no container;
- toda enumeracao Admin API bounded falha diante de pagina repetida, item duplicado, falta de
  progresso ou limite excedido;
- o init normal somente declara ready depois de provar o conjunto efetivo exato da Service Account;
- o first bootstrap cria somente client técnico ausente; client persistido inacessível, duplicado,
  reservado ou sem ownership/fingerprint admissível falha antes de update;
- nenhuma realm role ou client role diferente de Audit alcança `ROLE_TENANT_AUDIT` direta ou
  transitivamente;
- token, client, mapper e inventário recovery são classificados estruturalmente pelo parser Bash
  puro bounded, montado read-only nos dois serviços Keycloak;
- sessões temporárias do `kcadm` são owner-only e `INT`/`TERM` encerram sem mutação posterior;
- depois da invalidacao da sessao, um token DEV novo contem as duas roles administrativas, nao
  contem `tenant_id` e nao concede contexto tenant sem impersonacao;
- HML/PRD nao recebem atribuicao humana nem reconciliacao fora de change aprovado.
- todo realm novo recebe `smtpServer` junto de `resetPasswordAllowed=true`;
- realms persistidos da allowlist são verificados no startup normal e reconciliados
  somente no bootstrap/recovery privilegiado;
- Mailpit existe somente em DEV/HML, sem porta SMTP publicada, enquanto PRD rejeita
  host local/Mailpit, ausência de autenticação ou TLS inconsistente;
- SMTP de Keycloak e Central de Notificações permanecem configurações independentes.
- `KEYCLOAK_ADMIN_LOGIN_MFA_ENABLED=false` é aceito em DEV, HML e PRD durante a
  dispensa temporaria, desabilita `CONFIGURE_TOTP` e o pai direto do ramo
  condicional 2FA e preserva `auth-otp-form=ALTERNATIVE`, seus providers e o
  mapper AMR;
- o impacto realm-wide sobre identidades `saas-admin` é conhecido, enquanto cada
  operação continua submetida a RBAC e às authorities do domínio;
- reativar o toggle restaura enrollment/challenge MFA, e nenhum teste
  repository-local é apresentado como reconciliação de volume persistido;
- a reativacao em qualquer ambiente ocorre somente por decisao humana explicita
  dos owners de Produto e Seguranca, baseada no amadurecimento do uso da ferramenta.

## 7. Validacao minima

```bash
cd backend
./mvnw -Dtest=TenantOnboardingUseCaseTest,KeycloakRealmProvisioningAdapterTest,JpaTenantRepositoryAdapterTest test

cd ..
./start-dev-bot.sh --check

bash infra/keycloak/bootstrap/validate-realm-token-contracts.sh
bash infra/scripts/tests/keycloak-runtime-json-validator-test.sh
bash infra/scripts/tests/keycloak-bootstrap-hardening-test.sh
bash infra/scripts/tests/keycloak-realm-smtp-test.sh
bash infra/scripts/tests/keycloak-admin-login-mfa-toggle-test.sh
bash infra/scripts/tests/keycloak-tenant-first-login-mfa-toggle-test.sh
bash infra/scripts/tests/start-dev-bot-outbound-keyring-test.sh
```

Os gates `bash` do bloco acima incluem a regressão do toggle de login MFA; a
evidência histórica do checkpoint v2.6.1 permanece restrita aos gates então
executados. Esses comandos não acessam nem comprovam
o volume Keycloak persistido, sessao renovada, backfill/readiness ou API habilitada.

A validacao de release tambem deve criar um tenant descartavel ou controlado, verificar realm,
banco, metadados, role scopes e claim tenant, e entao validar o fluxo de login no novo realm. A
extensao de auditoria somente pode ser declarada **operacionalmente verificada** depois de teste
idempotente em volume persistido e de token novo apos invalidacao de sessao. A verificacao estatica
local nao substitui esse gate.

### 2.15 Bootstrap estatico pela Admin REST API

Os imports de startup dos realms `saas-admin` e `saas-bpfarias` ficam descontinuados. DEV, HML e PRD usam scripts versionados que chamam operações granulares da Keycloak Admin REST API por `kcadm.sh`; o JSON monolítico de `RealmRepresentation` não é mais fonte de bootstrap estático.

O inicializador autentica pela service account permanente e usa identidade de bootstrap apenas na primeira instalação. Realm ausente é criado de forma idempotente; realm existente é verificado e divergência falha fechado. Nenhuma senha humana é versionada: identidades novas recebem ações de primeiro acesso.

Nos três ambientes, `saas-admin` contém `djmarcellopedrosa@gmail.com` com `ROLE_SUPER_ADMIN` e `ROLE_TENANT_AUDIT`, e `saas-bpfarias` contém `contato@matrizcontabil.com.br` com `ROLE_TENANT_ADMIN`. O Keycloak atribui o UUID das identidades; o provisionador captura esse retorno e o usa nas role mappings. Após Flyway, `CanonicalAdminIdentityReconciler` busca o Super Admin canônico por username e e-mail exatos e substitui o placeholder `admin_users.iam_user_id` pelo UUID efetivo antes de a aplicação ficar pronta. Ausência, duplicidade ou UUID inválido falham fechado. `tenant_users` não armazena ID IAM e não exige essa atualização. Esta decisão sucede a restrição DEV-only das versões 2.2, 2.3 e 3.0 exclusivamente para essas duas identidades aprovadas; não autoriza outras contas em HML/PRD.

## 8. Referencias

- [Keycloak Server Administration Guide - Service accounts](https://www.keycloak.org/docs/latest/server_admin/#_service_accounts)
- [Keycloak Admin REST API](https://www.keycloak.org/docs-api/latest/rest-api/index.html)
- [Keycloak Bootstrap Admin Recovery](https://www.keycloak.org/server/bootstrap-admin-recovery)
- [UC-00002 - Tenant Management](../product/use-cases/UC-00002-tenant-management.md)
- [REQ-00041 - Chatbot Conversation Audit](../product/requirements/REQ-00041-chatbot-conversation-audit.md)
- [REQ-00058 - Recuperação de senha Keycloak e SMTP multiambiente](../product/requirements/REQ-00058-keycloak-password-recovery-smtp.md)
- [REQ-00059 - Dispensa temporária de MFA para todas as roles em DEV, HML e PRD](../product/requirements/REQ-00059-temporary-all-roles-mfa-disablement.md)
- ANL-00051 - Inventário do uso de MFA para Super Admin em DEV
- ANL-00053 - Falha do login por subfluxo 2FA condicional vazio
- [TP-00042 - Toggle temporário do MFA no login Super Admin DEV](../delivery/plans/TP-00042-temporary-dev-super-admin-login-mfa-disablement.md)
- [TP-00047 - Desligamento temporário do MFA do Super Admin em DEV](../delivery/plans/TP-00047-temporary-super-admin-invoicing-mfa-waiver.md)
- [REQ-00061 - Desligamento temporario do MFA no primeiro acesso de tenant](../product/requirements/REQ-00061-temporary-tenant-first-login-mfa-disablement.md)
- ANL-00054 - Inventario do MFA no primeiro acesso de tenant
- [TP-00050 - Toggle temporario do MFA no primeiro acesso de tenant](../delivery/plans/TP-00050-temporary-tenant-first-login-mfa-disablement.md)
- [UC-00036 - Autogestão de dados pessoais e senha](../product/use-cases/UC-00036-user-profile.md)
- [Conversation Audit Operations Runbook](../onboarding/conversation-audit-operations-runbook.md)
- [IP-BE-5.2.3-keycloak-protocol-mapper-realm-template — Implementation Plan](../delivery/plans/implementation_plans/backend/IP-BE-5.2.3-keycloak-protocol-mapper-realm-template.md)
- [LL-BE-00078 — Lesson Learned](../delivery/lessons-learned/backend/LL-BE-00078-keycloak-service-account-and-onboarding-compensation.md)
- [LL-BE-00080 — Lesson Learned](../delivery/lessons-learned/backend/LL-BE-00080-super-admin-token-must-not-carry-tenant-id.md)

## 9. Change Log

| Versao | Data | Mudanca |
|---|---|---|
| 4.1 | 2026-09-24 | Substitui o template JSON do onboarding por construção programática de `RealmRepresentation`, preservando contratos de realm e SMTP. |
| 4.0 | 2026-09-24 | Restringe Mailpit a DEV e decide SMTP externo no start de HML/PRD para `saas-admin` e `saas-bpfarias`, usando o segredo protegido `TF_VAR_contadorfiscal_smtp_password` de cada ambiente sem Git, argv ou log. |
| 3.9 | 2026-09-24 | Define o Keycloak como autoridade do UUID de usuário, captura o ID retornado para role mappings e reconcilia o Super Admin no banco da aplicação após Flyway. |
| 3.7 | 2026-09-11 | Reconcilia os toggles de login administrativo e primeiro acesso tenant com a dispensa temporaria de MFA para todas as roles em DEV/HML/PRD; preserva como historica a evidencia executada somente em DEV e exige decisao humana para reativacao. |
| 3.6 | 2026-09-09 | Explicita que uma authentication session ja posicionada em `login-actions` deve ser invalidada para o estado OFF governar uma nova autenticacao. |
| 3.5 | 2026-09-09 | Adiciona toggle DEV-only do provider `CONFIGURE_TOTP` nos realms tenant allowlisted, preservando required actions, rollback e exclusao do `saas-admin`. |
| 3.4 | 2026-09-09 | Explicita a ordem fail-closed do rollback: `CONFIGURE_TOTP`, folha OTP canônica e somente então pai `CONDITIONAL`. |
| 3.3 | 2026-09-09 | Corrige a topologia do toggle: OFF desabilita o pai direto do ramo 2FA e preserva `auth-otp-form=ALTERNATIVE`; proíbe o ramo condicional vazio e referencia ANL-00053 como diagnóstico exclusivo. |
| 1.0 | 2026-07-24 | Proposta inicial de provisionamento automatico. |
| 2.0 | 2026-08-14 | Decisao aceita; removido Password Grant; adotados Service Account, port/adaptador, compensacao integral e migracao segura de volumes persistidos. |
| 2.1 | 2026-08-14 | Separado contrato global/tenant; `saas-admin` sem `tenant_id`, impersonacao explicita e gate de CI. |
| 2.2 | 2026-08-22 | Antes da implementacao, definida `ROLE_TENANT_AUDIT` nos oito exports/templates, scopes explicitos com `fullScopeAllowed=false`, atribuicao somente ao superadmin DEV, reconciliacao idempotente de volume persistido e invalidacao/renovacao de sessao; HML/PRD e toda a extensao permanecem NOT IMPLEMENTED/NOT EXECUTED. |
| 2.3 | 2026-08-22 | Antes do runtime, endurecidos o contrato da credencial DEV por placeholder owner-only, a allowlist exata de realms, a remocao de mapper por semantica da claim e o gate `.users` vazio em HML/PRD; nenhum segredo literal, runtime ou ambiente externo e declarado alterado. |
| 2.4 | 2026-08-22 | Reconciliados os oito artefatos, a reconciliacao versionada e o gerador/contrato do secret owner-only como implementados; validador e dois testes shell passaram. Inclusao no `.env.dev.local` real, volume persistido, sessao/token novos, HML e PRD permanecem NOT EXECUTED. |
| 2.5 | 2026-08-22 | Antes de novo patch executavel, congelados Audit non-composite/sem heranca administrativa, remocao fail-closed de composite drift, reconciliacao obrigatoria da Service Account para allowlist minima sem early-success por client_credentials e deteccao de tenant_id tambem via client scopes. Evidencia v2.4 permanece historica; novo hardening esta PENDING IMPLEMENTATION/EVIDENCE. |
| 2.6 | 2026-08-22 | Antes de novo patch, congelados zero segredo em argv host/container, paginacao fail-closed para toda enumeracao Admin API, prova efetiva exata no init normal e reconciliacao segura de mappers/scopes geridos. Testes v2.5 permanecem historicos; runtime e v2.6 seguem PENDING. |
| 2.7 | 2026-08-22 | Reconciliado o hardening Keycloak v2.6 como implementado e estaticamente verificado pelos gates de hardening, contratos de realm e start-dev/keyring. Volume persistido, reconciliacao viva, sessao/token novos, backfill/readiness e API continuam NOT EXECUTED/OFF por bloqueio de permissoes locais; HML/PRD intocados. |
| 2.8 | 2026-08-22 | Reconciliado o fechamento estrutural v2.6.1: first-bootstrap e ownership fail-closed, fingerprint não interativo, grafo completo realm+client sem herança Audit, recovery estrutural, sessões/sinais seguros, parser JSON Bash puro bounded e mounts read-only. Quatro gates shell, 38 cenários, sintaxe e Compose sintético passaram; runtime vivo permanece bloqueado/API off. |
| 2.9 | 2026-08-25 | Separados os quatro grants diretos do conjunto efetivo de cinco roles da Service Account: `view-users` herda nativamente `query-users` e `query-groups` no Keycloak 26.6.x. O bootstrap continua rejeitando grant direto de `query-groups` e qualquer outra expansão; 39 cenários estruturais passaram. A reconciliacao viva e o restart do backend permanecem pendentes. |
| 3.0 | 2026-09-07 | Altera a identidade humana canônica do Super Admin DEV para `djmarcellopedrosa@gmail.com` e define reconciliação idempotente por `human_principal_id`/role, com conflito fail-closed e sem semeadura humana em HML/PRD. |
| 3.1 | 2026-09-07 | Decide e materializa SMTP por realm: Mailpit efêmero em DEV/HML, provedor externo fail-closed em PRD, herança automática em novos tenants e reconciliação privilegiada dos realms existentes. |
| 3.2 | 2026-09-09 | Registra a decisão humana de manter o mecanismo MFA e desabilitar temporariamente sua execução no login `saas-admin` apenas em DEV por toggle fail-closed; explicita o impacto realm-wide, o rollback e que nenhuma reconciliação stateful de volume está autorizada. |
