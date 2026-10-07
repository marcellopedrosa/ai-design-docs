---
document_id: TP-00044
primary_nature: Plano
objective: Planejar, implementar e verificar a recuperação de senha Keycloak com Mailpit em DEV/HML, SMTP externo em PRD e provisionamento automático para realms novos e existentes.
scope: Backend de provisionamento, templates e exports Keycloak, bootstrap/reconciliação, Compose DEV/HML/PRD, configuração de exemplo, testes e documentação de referência.
non_objectives: Executar deploy; acessar realms ou volumes vivos; enviar e-mail real; contratar provedor SMTP; usar Mailpit em PRD; criar configuração SMTP individual por tenant; alterar a Central de Notificações.
owner: Segurança, Infraestrutura e Engenharia
status: In Progress — formulário repository-local verde; smokes runtime e de credencial pendentes
version: v1.10
date: 2026-09-07
last_reviewed: 2026-09-08
keywords: keycloak, recuperação de senha, mailpit, smtp, dev, hml, prd, provisionamento
related_files: do../../product/requirements/REQ-00058-keycloak-password-recovery-smtp.md, ../../backend/docs/adrs/ADR-0018-keycloak-realm-provisioning-automation.md, ../../backend/docs/adrs/ADR-0022-notification-center-architecture.md, do../../product/use-cases/UC-00036-user-profile.md, ../../backend/docs/onboarding/keycloak-provisioning-identity.md
code_references: backend/src/main/java/br/com/duoset/saas_service/contexts/tenant/internal/infrastructure/iam/KeycloakRealmProvisioningAdapter.java, backend/src/main/java/br/com/duoset/saas_service/contexts/tenant/internal/infrastructure/iam/KeycloakRealmSmtpProperties.java, backend/src/main/java/br/com/duoset/saas_service/contexts/tenant/internal/infrastructure/iam/KeycloakTenantRealmRepresentationFactory.java, infra/keycloak/, infra/keycloak/themes/saas-theme/login/login-reset-password.ftl, infra/scripts/tests/, docker-compose.yml, docker-compose.override.yml, docker-compose.hml.yml, docker-compose.prd.yml, .env.example, infra/deploy/production.env.example
principal_statement: A implementação deve provar no repositório que DEV/HML capturam resets em Mailpit, PRD aceita somente SMTP externo seguro e todo realm gerido recebe ou reconcilia a configuração sem expor segredos.
---

# TP-00044 — Recuperação de senha Keycloak com SMTP multiambiente

## Autorização e decisão de desenho

A solicitação humana de 2026-09-07 autoriza planejar, documentar e implementar a
mudança no repositório. Não autoriza subir stacks, mutar volumes, acessar HML/PRD,
enviar mensagens reais ou inserir credenciais.

Mailpit será incorporado somente em DEV/HML. PRD receberá contrato fail-closed
para SMTP transacional externo porque Mailpit captura mensagens em vez de
entregá-las. A configuração é aplicada por realm, inclusive `saas-admin`; novos
tenants herdam o SMTP da plataforma no adaptador de provisionamento. SMTP
particular por escritório não faz parte desta primeira versão.

## Corretivo DEV — execução do Mailpit

O runtime DEV comprovou `exec /mailpit: operation not permitted`. O override já
documentava e aplicava aos serviços backend, frontend e inicializador a exceção
local necessária quando Docker Desktop/Snap combina `cap_drop: ALL` com
`no-new-privileges`; o Mailpit foi incluído sem a mesma exceção.

O corretivo deve remover somente em DEV essa combinação, preservando filesystem
read-only, tmpfs efêmero, limite de processos, porta SMTP não publicada e UI no
loopback. HML mantém `cap_drop: ALL` e `no-new-privileges`; PRD continua sem
Mailpit. O teste de contrato deve impedir regressão dessas três políticas.

O override e o teste foram corrigidos conforme esse contrato. A recriação do
container já existente e o smoke de readiness permanecem operação local humana;
não exigem `down`, remoção de volume ou relaxamento em HML.

## Implementation Readiness — link de recuperação oculto

### Contrato atômico da tarefa

| Campo | Contrato |
| --- | --- |
| **What** | Exibir **Esqueceu sua senha?** no formulário Keycloak sempre que `realm.password` e `realm.resetPasswordAllowed` estiverem ativos, independentemente de cadastro público. |
| **Where** | `infra/keycloak/themes/saas-theme/login/login.ftl`, `infra/scripts/tests/keycloak-login-theme-visual-test.sh` e os documentos diretamente relacionados a `TP-00044-CF-03`. |
| **Depends on** | REQ-00058 v1.2, UC-00036 v1.2, ADR-0018 v3.1 e configuração SMTP/reset já implementada por realm. |
| **Reuses** | `url.loginResetCredentialsUrl`, o bloco `auth-links` existente e o teste focal do tema Keycloak. |
| **Requirements** | REQ-00058 `AC-006`, UC-00036 extensão `0a`, ADR-0018 §2.12, Implementation Readiness Standard e Software Quality Standard. |

### Gate Audit

- Task: `TP-00044-CF-03`, reauditada por Codex em 2026-09-08 contra REQ-00058
  v1.2, UC-00036 v1.2, ADR-0018 v3.1 e este plano v1.7; a atualização de versão
  registra somente evidências pós-implementação e não amplia `What`/`Where`.
- Fontes superiores: o requisito foi aprovado em v1.0 e permanece `Implemented`
  repository-local; o caso de uso está `Approved`; o ADR está `Accepted`.
- Evidência runtime sanitizada: a captura do login `saas-admin` mostra o
  formulário sem **Esqueceu sua senha?**. O export DEV mantém
  `resetPasswordAllowed=true`.
- Causa validada: `login.ftl` entrega `displayInfo=true` somente quando
  `registrationAllowed=true`; como o link de reset está dentro da seção `info`,
  desabilitar cadastro público oculta indevidamente também a recuperação.
- Assumption `A-CF03-01` (`Validated`, owner: Segurança/IAM e Engenharia,
  2026-09-08): recuperação e cadastro são capacidades independentes. Evidências:
  REQ-00058 `AC-006`, UC-00036 extensão `0a`, captura runtime e condição observada
  no template.
- Open Question `OQ-CF02-01` (`Resolved`, owner: mantenedor humano DEV,
  2026-09-08): a nova senha também falhou em janela anônima com um fluxo novo;
  eventos com `code_id` distintos eliminam cache, autofill e sessão anterior.
- Open Question `OQ-CF02-02` (`Resolved`, owner: Segurança/IAM, 2026-09-08): as
  claims sanitizadas confirmaram realm, usuário e client corretos, mas o link
  testado era `execute-actions` administrativo; o token exposto não foi
  materializado e não pode ser reutilizado.
- Open Question `OQ-CF02-03` (`Resolved`, owner: mantenedor humano DEV,
  2026-09-08): o fluxo nativo não pôde ser iniciado porque seu entrypoint não é
  renderizado; a captura transforma a pendência em defeito reproduzível com causa
  e paths exatos.
- Não existem assumptions propostas, perguntas abertas, dependências ausentes ou
  decisões de produto pendentes no escopo repository-local desta tarefa.

### Acceptance Tests

| Critério | Fluxo | Teste/evidência esperada |
| --- | --- | --- |
| REQ-00058 `AC-006` | UC-00036 `0a`, passo 1 | Teste shell comprova que `displayInfo` considera reset habilitado mesmo com cadastro desabilitado e que o link usa `url.loginResetCredentialsUrl`. |
| Preservação visual | Login normal | Teste existente continua protegendo painel esquerdo e hashes do wrapper/formulário não alterados por esta tarefa. |
| Segurança | Recuperação pré-login | Nenhum realm, SMTP, MFA, senha ou token é alterado/registrado; o token anteriormente exposto não é reutilizado. |
| Smoke DEV | UC-00036 `0a`, passos 1–4 | Página local exibe o link; mantenedor solicita um novo e-mail pelo próprio link e valida reset + login sem compartilhar credencial/token. |

### Prohibited

- não alterar painel esquerdo, CSS, realm, SMTP, flow, required action ou MFA;
- não habilitar cadastro público nem tornar sua flag precondition do reset;
- não redefinir credencial pela Admin API, consultar hash/banco ou registrar
  senha/link/token;
- não reutilizar o token exposto nem acessar HML/PRD.

### Mandatory

- corrigir somente a condição e o encapsulamento necessários em `login.ftl`;
- ampliar o teste focal do tema para impedir novo acoplamento entre reset e
  cadastro;
- executar sintaxe shell, teste focal, Quality Gate de Infra e governança
  documental; o smoke de credencial continua sob execução humana.

### Definition of Done

- [x] `resetPasswordAllowed=true` torna a seção do link elegível mesmo quando
  `registrationAllowed=false`.
- [x] O cartão administrativo mantém o comportamento anterior e não aparece
  apenas por o reset estar habilitado.
- [x] Teste focal e sintaxe shell retornam código `0`.
- [x] Quality Gate aplicável e `validate-docs.sh` têm resultado registrado sem
  ocultar falhas externas ao escopo.
- [ ] O mantenedor confirma no runtime DEV a presença do link e executa o smoke
  nativo sem expor senha ou token.

### Result

**Resultado: `READY`.** Auditor: Codex, 2026-09-08. O handoff executável está
limitado aos dois paths de runtime/teste declarados em **Where**; o smoke DEV não
autoriza acesso a credenciais, HML ou PRD.

## Implementation Readiness — formulário nativo de recuperação

### Contrato atômico da tarefa

| Campo | Contrato |
| --- | --- |
| **What** | Criar o template de solicitação de recuperação para que o painel direito reutilize a qualidade visual do login e preserve integralmente o fluxo nativo do Keycloak e o painel esquerdo existente. |
| **Where** | `infra/keycloak/themes/saas-theme/login/login-reset-password.ftl`, `infra/scripts/tests/keycloak-login-theme-visual-test.sh` e os documentos diretamente relacionados a `TP-00044-CF-04`. |
| **Depends on** | REQ-00058 v1.3, UC-00036 v1.3, ADR-0018 v3.1, Keycloak 26.6.3 pinado no Compose e o tema `saas-theme` existente. |
| **Reuses** | Contrato oficial `login-reset-password.ftl` do Keycloak 26.6.3, macro `registrationLayout`, `url.loginAction`, `url.loginUrl`, `auth.attemptedUsername`, `messagesPerField` e classes visuais já usadas por `login.ftl`. |
| **Requirements** | REQ-00058 `AC-006` e `AC-009`, UC-00036 extensão `0a`, ADR-0018 §2.12, Implementation Readiness Standard e Software Quality Standard. |

### Gate Audit

- Task: `TP-00044-CF-04`, auditada por Codex em 2026-09-08 contra REQ-00058
  v1.3, UC-00036 v1.3, ADR-0018 v3.1 e este plano v1.8.
- Fontes superiores: o requisito está `Implemented` repository-local, o caso de
  uso está `Approved` e o ADR está `Accepted`; a solicitação humana autoriza a
  correção visual repository-local sem efeito ambiental.
- Evidência runtime sanitizada: a captura da URL nativa `reset-credentials` mostra
  o painel esquerdo do tema e, no painel direito, inputs, link e botão sem os
  estilos do login.
- Causa validada: o tema não contém `login-reset-password.ftl`; por herança
  `parent=keycloak`, o Keycloak renderiza seu template pai com classes que não
  pertencem ao design customizado.
- Dependência validada: o Compose fixa Keycloak 26.6.3 e o template oficial dessa
  versão define o formulário `kc-reset-password-form`, POST em
  `url.loginAction`, campo `username`, erro acessível e retorno por
  `url.loginUrl`.
- Assumption `A-CF04-01` (`Validated`, owner: Segurança/IAM e Engenharia,
  2026-09-08): um override mínimo do template, sem alteração de CSS ou do macro,
  reutiliza os componentes visuais já existentes e mantém a lateral esquerda
  idêntica.
- Open Questions: nenhuma. Não existem assumptions propostas, conflitos,
  dependências ausentes, `TBD` ou decisões de produto pendentes neste escopo.

### Acceptance Tests

| Critério | Fluxo | Teste/evidência esperada |
| --- | --- | --- |
| REQ-00058 `AC-009` | UC-00036 `0a`, passos 1–2 | Teste shell exige template próprio e as classes `login-form`, `form-group`, `input-label`, `input-wrapper`, `form-input`, `btn-primary` e `auth-links`. |
| Semântica nativa | Solicitar recuperação | Teste shell exige `kc-reset-password-form`, POST em `url.loginAction`, `name=username`, valor tentado, mensagens do realm, erro com `aria-live` e retorno por `url.loginUrl`. |
| Preservação visual | Todas as telas do tema | Os hashes existentes do wrapper direito e do CSS permanecem iguais; `template.ftl` e `styles.css` não são alterados. |
| Smoke DEV | Página pública de recuperação | Uma sessão OIDC sintética, sem credencial, abre um link novo e comprova HTTP `200` com o template customizado; nenhum link/token é registrado. |

### Prohibited

- não alterar `template.ftl`, `styles.css`, painel esquerdo, formulário de login,
  realm, SMTP, flow, required action, MFA ou credencial;
- não criar endpoint, JavaScript, POST alternativo nem URL hard-coded;
- não revelar se o usuário existe, registrar identificador, link, token ou acessar
  HML/PRD.

### Mandatory

- manter as variáveis e mensagens nativas do Keycloak 26.6.3;
- sanitizar a mensagem de erro, preservar `aria-invalid`/`aria-live` e permitir
  retorno ao login;
- criar o template pelo menor override possível e ampliar o teste focal antes da
  implementação;
- executar sintaxe shell, teste focal, Quality Gate de Infra e governança
  documental; o smoke de envio/login continua sob execução humana.

### Definition of Done

- [x] O teste focal falha antes da implementação pela ausência do template.
- [x] O formulário customizado usa os componentes visuais do login e retorna ao
  fluxo normal.
- [x] O contrato nativo e a acessibilidade estão protegidos pelo teste.
- [x] `template.ftl`, `styles.css` e a lateral esquerda permanecem inalterados.
- [x] Teste focal, Quality Gate e documentação têm resultado registrado.
- [ ] O smoke HTTP comprova a renderização no runtime DEV com o Keycloak ativo.

### Result

**Resultado: `READY`.** Auditor: Codex, 2026-09-08. O handoff executável está
limitado aos dois paths de runtime/teste declarados em **Where** e não autoriza
mutação de realm, envio de e-mail, autenticação ou acesso ambiental.

## Plano de execução

| Fase | Entrega | Validação mínima | Estado |
| --- | --- | --- | --- |
| 1 | Congelar requisito, limites ambientais e estratégia de provisionamento | índices e gate documental | Concluída |
| 2 | Adicionar configuração tipada/validada e renderização SMTP no backend | testes unitários do adaptador e template | Concluída repository-local |
| 3 | Adicionar Mailpit pinado em DEV/HML e contrato SMTP externo em PRD | Compose `config --quiet`, testes estáticos e ausência de porta SMTP publicada | Concluída estaticamente; parser Compose bloqueado pelo Docker Snap do host |
| 4 | Reconciliar e verificar SMTP/reset nos realms existentes da allowlist | testes shell idempotentes, drift e segredo ausente da saída | Concluída repository-local |
| 5 | Atualizar ADR, caso de uso, runbooks, exemplos e índices | `validate-docs.sh` | Concluída |
| 6 | Executar suíte impactada e registrar evidências/limites | backend, shell, JSON, Compose e documentação | Concluída com limites ambientais explícitos |

## Contrato de configuração

O mesmo conjunto lógico deve alimentar backend e bootstrap:

- host, porta, remetente e nome de exibição;
- reply-to e respectivo nome, quando definidos;
- autenticação, STARTTLS e SSL como booleanos explícitos;
- usuário e senha somente quando autenticação estiver habilitada.

DEV/HML usam `mailpit:1025`, sem autenticação, STARTTLS ou SSL. PRD exige
autenticação e exatamente um modo cifrado compatível com o provedor. O valor da
senha nunca será versionado nem passado em linha de comando.

## Estratégia de provisionamento e reconciliação

```text
criação de tenant
  -> configuração SMTP validada do ambiente
  -> template JSON em árvore
  -> realm saas-{slug} com smtpServer + reset habilitado

realm existente da allowlist
  -> startup normal verifica
  -> drift exige bootstrap/recovery privilegiado
  -> reconciliador aplica estado desejado
  -> verificação final antes do backend
```

O reconciliador não ampliará as roles permanentes da Service Account. Mutação de
realm continuará confinada à identidade temporária do procedimento de bootstrap,
enquanto o startup normal apenas prova a pós-condição.

## Riscos e controles

| Risco | Controle |
| --- | --- |
| Mailpit ser promovido a PRD | serviço ausente do Compose PRD e validação que rejeita host local/Mailpit |
| Link aparecer sem transporte funcional | configuração obrigatória no provisionamento e verificação de realms existentes |
| Vazamento de senha ou token de reset | segredo fora de Git/argv/log; Mailpit efêmero, limitado e em loopback |
| Confundir SMTP de IAM com notificações | configuração, owner e documentação separados |
| Drift entre realms | template único para novos realms e reconciliação exata da allowlist |
| SMTP particular de tenant ampliar risco | adiado até contrato próprio de custódia, domínio, rotação e fallback |

## Critérios de conclusão repository-local

- todos os critérios `AC-001` a `AC-009` do REQ-00058 possuem evidência;
- nenhuma imagem usa tag flutuante e o pin do Mailpit é verificável;
- nenhum arquivo versionado contém credencial SMTP real;
- testes focalizados e suíte impactada passam;
- validadores JSON, shell, Compose e documentação passam;
- o plano registra explicitamente o que não foi executado em ambiente vivo.

## Evidências

### Aprovadas

- `KeycloakRealmProvisioningAdapterTest`: `4/4` testes; configuração SMTP e
  renderização de novo realm comprovadas com Java 21 em modo diagnóstico.
- gates arquiteturais `ModuleStructureVerificationTest`,
  `CleanArchitectureRulesTest` e `CleanArchitectureRuleContractTest`: `29/29`.
- `validate-realm-token-contracts.sh`, `keycloak-realm-smtp-test.sh`,
  `keycloak-mailpit-compose-contract-test.sh`,
  `keycloak-production-smtp-validation-test.sh`,
  `keycloak-runtime-json-validator-test.sh`,
  `keycloak-bootstrap-hardening-test.sh`,
  `keycloak-super-admin-identity-test.sh` e
  `keycloak-payment-provider-authorities-test.sh`: aprovados.
- `validate-docs.sh`: aprovado com 743 Markdown, 30 diretórios e 724 artefatos
  indexados.
- Sintaxe shell dos arquivos alterados e parse JSON dos templates/exports:
  aprovados.
- Corretivo Mailpit DEV: teste focalizado e suíte agregada de hardening aprovados,
  comprovando a exceção somente no override DEV e a preservação de HML/PRD.
- Corretivo do entrypoint: o teste focal foi observado vermelho antes da mudança e
  verde depois; Quality Gate `infra/focused` e `infra/pr` retornaram `PASS`, assim
  como `keycloak-realm-smtp-test.sh`.
- Smoke público local: o endpoint OIDC com PKCE sintético retornou HTTP `200`,
  renderizou **Esqueceu sua senha?** e não renderizou **Primeiro acesso** nem o
  cartão administrativo; nenhuma autenticação ou credencial foi usada.
- Corretivo do formulário: o teste focal foi observado vermelho pela ausência de
  `login-reset-password.ftl` e verde após o override; o template preserva o POST,
  campo, mensagens, erro acessível e retorno nativos e reutiliza as classes do
  login sem alterar `template.ftl` ou `styles.css`.
- Quality Gate atual do formulário: `infra/focused` e `infra/pr` retornaram
  `PASS`; `keycloak-realm-smtp-test.sh` também permaneceu verde.
- Gate documental final: `validate-docs.sh` retornou código `0` com 749 Markdown,
  30 diretórios e 731 artefatos indexados. Uma execução anterior encontrou
  referências inconsistentes em planos backend concorrentes; a repetição final
  passou sem que este corretivo alterasse esses artefatos alheios.

### Limites preservados

- O gate Maven oficial requer Java 25, mas o host da sessão possui somente Java
  21; a sobreposição foi usada apenas para diagnóstico, não como substituição do
  gate canônico.
- O Docker Snap falhou antes do `docker compose config --quiet` por ausência de
  `cap_dac_override`; nenhum container foi iniciado. O teste estático garante a
  topologia esperada, mas não substitui o parser Compose.
- O teste amplo e não relacionado do launcher DEV
  `start-dev-bot-outbound-keyring-test.sh` permanece vermelho porque sua própria
  fixture encontrou o identificador sintético protegido no log de bootstrap; os
  arquivos desse launcher não foram alterados por este plano.
- Nenhum volume, realm vivo, HML/PRD, credencial ou provedor externo foi acessado;
  nenhum e-mail foi enviado.
- O container Mailpit DEV existente ainda precisa ser recriado e inspecionado no
  runtime pelo mantenedor humano para substituir a configuração anterior.
- O smoke de reset + login permanece humano porque exige senha e token que não
  podem ser lidos ou registrados pelo agente.
- O smoke HTTP do formulário customizado ficou `BLOCKED`: `localhost:8180` não
  possuía listener durante a validação (`curl` retornou HTTP `000`). A tentativa
  usou sessão OIDC sintética e não registrou link, usuário, senha ou token.

## Change log

| Version | Date | Author | Changes |
| --- | --- | --- | --- |
| v1.10 | 2026-09-08 | Solicitante humano / Codex | Registra o `validate-docs.sh` final verde após a divergência concorrente desaparecer, mantendo apenas os smokes runtime/credencial como pendências. |
| v1.9 | 2026-09-08 | Solicitante humano / Codex | Implementa e valida estaticamente o formulário temático nativo; registra Quality Gates verdes, smoke HTTP bloqueado pelo Keycloak local indisponível e falha documental concorrente. |
| v1.8 | 2026-09-08 | Solicitante humano / Codex | Materializa `TP-00044-CF-04` como `READY` para corrigir o fallback sem estilo da solicitação nativa, com paths, invariantes e DoD finitos. |
| v1.7 | 2026-09-08 | Solicitante humano / Codex | Implementa e valida a visibilidade independente do reset, comprova o HTML no endpoint local e mantém apenas o smoke de credencial humano e o gate documental externo como pendências. |
| v1.6 | 2026-09-08 | Solicitante humano / Codex | Classifica o entrypoint oculto pela dependência indevida de `registrationAllowed`, fecha as perguntas runtime e autoriza o corretivo mínimo em `login.ftl` com regressão focal. |
| v1.5 | 2026-09-08 | Solicitante humano / Codex | Encerra as dúvidas de sessão e identidade do link, classifica o token sanitizado como `execute-actions` administrativo e mantém o gate bloqueado até um teste novo iniciado em **Esqueceu sua senha?**. |
| v1.4 | 2026-09-08 | Solicitante humano / Codex | Registra readiness BLOCKED para a falha pós-reset: SMTP está funcional, mas login fresco/realm do link ainda precisam classificar a causa antes de qualquer patch executável. |
| v1.3 | 2026-09-08 | Solicitante humano / Codex | Conclui o corretivo repository-local: DEV aplica a exceção Docker Desktop/Snap ao Mailpit, HML retém hardening e os testes focal/agregado ficam verdes; recriação runtime permanece pendente. |
| v1.2 | 2026-09-08 | Solicitante humano / Codex | Reabre o plano antes do corretivo para `exec /mailpit: operation not permitted`, limitado à exceção Docker Desktop/Snap do override DEV. |
| v1.1 | 2026-09-08 | Solicitante humano / Codex | Conclui a implementação repository-local, registra gates aprovados e mantém JDK 25, parser Compose, rollout e entrega real como validações ambientais pendentes. |
| 1.0 | 2026-09-07 | Solicitante humano / Codex | Persiste o plano transversal antes das edições de software e congela Mailpit em DEV/HML, SMTP externo em PRD e provisionamento por realm. |
