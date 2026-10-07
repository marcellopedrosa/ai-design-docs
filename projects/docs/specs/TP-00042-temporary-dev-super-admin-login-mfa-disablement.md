---
document_id: TP-00042
primary_nature: Plano
objective: Desabilitar temporariamente o MFA no login do realm administrativo em DEV, HML e PRD, desativando com segurança o pai do ramo 2FA e sem remover configuração, atribuição ou credencial TOTP.
scope: Provider CONFIGURE_TOTP, pai condicional direto e execução auth-otp-form do browser flow saas-admin, flag multiambiente reversível, reparo do estado legado, contratos repository-local, testes e reconciliação ambiental separada.
non_objectives: Não remover CONFIGURE_TOTP, credencial OTP ou mapper AMR; não redefinir os waivers Billing governados pelo TP-00047; não remover UPDATE_PASSWORD; não acessar credenciais, dados reais, realms ou volumes e não executar deploy.
owner: Segurança e Infraestrutura
status: In Progress — F02 repository-local Done; F03 deploy contract pending
version: 1.8
date: 2026-09-06
last_reviewed: 2026-09-12
keywords: keycloak, dev, hml, prd, admin, mfa, totp, excecao temporaria
related_files: do../../product/requirements/REQ-00059-temporary-all-roles-mfa-disablement.md, docs/analysis/ANL-00053-keycloak-empty-conditional-2fa-flow.md, TP-00037-billing-mfa-amr-evidence-correction.md, TP-00038-billing-contract-context-temporary-mfa-disablement.md, ../../backend/docs/specs/IP-BE-42.1.2-admin-login-mfa-multi-environment-reconciler.md, ../../backend/docs/adrs/ADR-0018-keycloak-realm-provisioning-automation.md, ../../backend/docs/onboarding/keycloak-provisioning-identity.md
code_references: infra/keycloak/bootstrap/reconcile-admin-login-mfa.sh, infra/scripts/tests/keycloak-admin-login-mfa-toggle-test.sh, infra/scripts/tests/fixtures/keycloak-admin-login-mfa-kcadm.sh, docker-compose.yml, docker-compose.override.yml, docker-compose.hml.yml, docker-compose.prd.yml, .env.example, infra/deploy/production.env.example, infra/scripts/deploy-production.sh
principal_statement: CONFIGURE_TOTP, auth-otp-form, credenciais e AMR permanecem preservados; uma flag explícita pode desabilitar reversivelmente o provider e o pai direto 2FA em DEV, HML ou PRD, sem ampliar RBAC e com rollback true.
---

# TP-00042 — Desativação temporária multiambiente do MFA administrativo

## Autorização e limites

A decisão humana consolidada no PRD-00005 v1.36 e no REQ-00059 v1.10 amplia o
alvo repository-local para todas as identidades do `saas-admin` em DEV, HML e
PRD. MFA não é removido: configuração, atribuição e credenciais permanecem
disponíveis para reativação. A mudança não autoriza deploy, mutação de realm,
leitura de segredo ou enfraquecimento de RBAC e dos controles financeiros.

## Implementação

1. Preservar provider, required action, execução, credenciais e mapper AMR.
2. Manter `KEYCLOAK_ADMIN_LOGIN_MFA_ENABLED=true` como default seguro no Compose
   base; somente uma flag ambiental explícita pode solicitar `false`.
3. Em DEV, HML ou PRD com a flag `false`, desabilitar — sem excluir — o provider
   `CONFIGURE_TOTP` e o pai direto 2FA; manter `auth-otp-form=ALTERNATIVE`.
4. Quando a flag voltar a `true`, reabilitar o provider e restaurar o pai para
   `CONDITIONAL` somente depois de confirmar `auth-otp-form=ALTERNATIVE`,
   preservando credenciais já cadastradas.
5. Integrar a verificação ao startup least-privileged e a mutação somente ao
   bootstrap/recovery privilegiado já governado pelo ADR-0018.
6. Cobrir matriz DEV/HML/PRD × OFF/ON, flag ausente ou inválida, reparo legado,
   rollback, ordem segura, idempotência e drift ambíguo por testes herméticos.
7. Ler a representação completa de `CONFIGURE_TOTP`, validá-la
   estruturalmente e enviar um `PUT --no-merge` que substitui somente o nó
   booleano `enabled`; nome, alias, provider, prioridade e mapa `config`
   permanecem byte a byte iguais.

## Estado persistido e rollback

O JSON de importação só governa realms novos. Em volume existente, a reconciliação
controlada usa a Admin API com recovery temporário, preserva usuários e
credenciais, converge os três estados geridos e exige pós-condição exata. O
startup normal apenas verifica e continua least-privileged.

O rollback consiste em definir `KEYCLOAK_ADMIN_LOGIN_MFA_ENABLED=true` e executar
a mesma reconciliação controlada. Nenhuma credencial precisa ser recriada.

## Impacto temporário aceito

O toggle é realm-wide no `saas-admin`. Portanto, toda identidade interativa nesse
realm deixa de receber cadastro/desafio TOTP quando a flag explícita estiver
`false` em DEV, HML ou PRD. Isso não concede role, authority ou contexto tenant.

Os toggles Billing são controles de aplicação separados e não são realm-wide.
Seu alcance multiambiente e seu rollback permanecem governados pelo REQ-00059 e
pelo TP-00047, sem fabricar evidência `otp` nem ampliar RBAC.

## Critérios de aceite

- `CONFIGURE_TOTP` continua atribuído e o authenticator/AMR continuam presentes;
- em OFF, o pai direto 2FA fica `DISABLED` e `auth-otp-form` permanece
  `ALTERNATIVE`; em ON, o pai volta a `CONDITIONAL` por último;
- o estado legado com pai `CONDITIONAL` e folha OTP `DISABLED` é reparado e não
  pode ser aceito como pós-condição;
- DEV, HML e PRD não exigem cadastro nem desafio TOTP no login administrativo
  enquanto a flag explícita estiver `false`;
- `UPDATE_PASSWORD` continua obrigatório;
- ambiente fora de `dev|hml|production`, flag ausente ou valor malformado falha
  antes de qualquer chamada administrativa;
- reativação restaura MFA sem recriar configuração ou credencial;
- validações focalizada, impactada e documental passam.

## Registro canônico do incidente

Sintoma, reprodução, evidência sanitizada, causa raiz e explicação da mensagem
enganosa do Keycloak pertencem exclusivamente à
[ANL-00053](../../analysis/ANL-00053-keycloak-empty-conditional-2fa-flow.md). Este
plano não replica logs nem dados de autenticação.

## Decomposição semântica vigente

| Filho | Resultado observável | Estado | Handoff |
| --- | --- | --- | --- |
| `TP-00042-F01` | Corrigir a topologia do ramo 2FA vazio. | Done — histórico DEV | Evidência preservada nas seções abaixo. |
| `TP-00042-F02` | Aceitar a flag explícita OFF/ON em DEV, HML e PRD no reconciliador, com matriz hermética 3×2. | Done — 6/6 e Quality Gates PASS | [IP-BE-42.1.2-admin-login-mfa-multi-environment-reconciler](../../backend/docs/specs/IP-BE-42.1.2-admin-login-mfa-multi-environment-reconciler.md) |
| `TP-00042-F03` | Alinhar templates e validação de deploy ao waiver multiambiente sem default OFF implícito. | Pending — sem handoff executável | Exige IP próprio e refatoração dos validadores acima de 500 linhas antes do IRG. |

`F02` e `F03` são independentes: o primeiro torna o reconciliador capaz de
consumir uma decisão explícita; o segundo governa como templates e deploy
materializam essa decisão. Nenhum deles autoriza efeito ambiental.

## TP-00042-F02 — Contrato multiambiente do reconciliador

### What

Aceitar `KEYCLOAK_ADMIN_LOGIN_MFA_ENABLED=false|true` explicitamente em cada
ambiente suportado e provar a mesma máquina de estados nos seis pares.

### Where

Os três paths executáveis fechados estão no
IP-BE-42.1.2-admin-login-mfa-multi-environment-reconciler; nenhum template,
Compose, deploy script, realm ou volume integra este filho.

### Depends on / Reuses / Requirements

Depende de PRD-00005 v1.36, REQ-00059 v1.10, ADR-0018 v3.7 e da topologia
concluída por F01. Reutiliza o validador JSON, o fake `kcadm`, as pós-condições e
a ordem fail-closed. O contrato detalhado e o IRG estão no
IP-BE-42.1.2-admin-login-mfa-multi-environment-reconciler.

### Definition of Done / Result

- [x] matriz hermética DEV/HML/production × false/true passa 6/6;
- [x] flag ausente/malformada e ambiente inválido falham sem mutação;
- [x] regressões de topologia, rollback, idempotência e credenciais continuam verdes;
- [x] cada script alterado fica abaixo de 500 linhas e passa sintaxe/quality gates;
- [x] handoff informa zero acesso ou efeito ambiental.

`DONE — repository-local`: o `READY` auditado pelo AgentOrchestrator via
`implementation-readiness` em 2026-09-12 foi executado nos três paths congelados
no IP-BE-42.1.2-admin-login-mfa-multi-environment-reconciler v1.0. Nenhum
ambiente ou dado real foi acessado.

### Evidências TP-00042-F02 — 2026-09-12

- sintaxe dos três scripts e teste focal: `PASS`;
- matriz hermética DEV/HML/production × false/true: `6/6 PASS`, com `verify` e
  replay idempotente em cada par;
- flag ausente/malformada e ambiente inválido: falha antes da primeira chamada
  ao fake `kcadm` e zero mutação;
- regressões de topologia, ordem segura, falha parcial e estado ambíguo: `PASS`;
- testes impactados: validador JSON `46/46`, contratos de token e hardening
  Keycloak em `PASS`;
- Quality Gate infra `focused` e `pr`: `PASS`; métricas nos três targets:
  `382`, `391` e `351` linhas, zero violação;
- efeito externo: nenhum; zero rede, credencial, container, deploy, realm ou
  volume real.

## TP-00042-F03 — Templates e validação de deploy

### What / Where

Permitir que exemplos explícitos e o validador de deploy representem OFF e ON em
HML/PRD, mantendo ausência/má-formação fail-closed. Paths candidatos:
`.env.example`, `infra/deploy/production.env.example`,
`infra/scripts/deploy-production.sh`, seus testes e o runbook de identidade.

### Depends on / Reuses / Requirements

Depende de F02 concluído. Reutiliza o default `true` do Compose base, a lista de
variáveis obrigatórias, `validate_boolean` e a verificação do Compose efetivo.
Aplica PRD-00005 v1.36, REQ-00059 AC-59-002/007/010, ADR-0018 v3.7 e o Software
Quality Standard v1.3.

### Acceptance Tests / Prohibited / Mandatory

- provar OFF e rollback ON em HML/production por renderização sintética;
- rejeitar flag ausente ou malformada antes de qualquer comando mutável;
- não executar deploy, container, rede, realm, volume ou ler `.env` real;
- não tornar `false` default implícito onde a flag não foi fornecida;
- criar IP próprio, decompor os scripts acima de 500 linhas e obter novo `READY`
  antes da primeira edição executável.

### Definition of Done / Result

- [ ] templates e validador não contradizem a truth table do REQ-00059;
- [ ] teste focal, suíte impactada, métricas e documentação passam;
- [ ] rollback `true` e defaults fail-closed continuam comprovados;
- [ ] nenhum efeito ambiental é executado.

`PENDING` — nenhuma autorização executável foi emitida para F03 nesta versão.

## TP-00042-F01 — Correção do ramo 2FA vazio

### What

Corrigir o reconciliador para alternar o pai direto do ramo 2FA, preservar a
folha OTP e reparar de forma idempotente o estado legado que falha após senha
válida.

### Where

- `infra/keycloak/bootstrap/reconcile-admin-login-mfa.sh`;
- `infra/scripts/tests/keycloak-admin-login-mfa-toggle-test.sh`;
- `.env.example`;
- fontes e índices documentais diretamente ligados a REQ-00059, ADR-0018,
  ANL-00053, TP-00042 e ao runbook Keycloak.

### Depends on

- REQ-00059 v1.4 `Approved`;
- ADR-0018 v3.4 `Accepted`;
- ANL-00053 v1.2 `Current`;
- Admin API do Keycloak 26.6.3 e reconciliador/migração existentes disponíveis.

### Reuses

Reutiliza a flag `KEYCLOAK_ADMIN_LOGIN_MFA_ENABLED`, a sessão autenticada do
`kcadm`, o inventário bounded já existente, o update in-place de execuções, o
payload preservador de `CONFIGURE_TOTP` e a suíte shell hermética vigente.

### Requirements

- [REQ-00059 AC-59-002/010](../../product/requirements/REQ-00059-temporary-all-roles-mfa-disablement.md);
- [ADR-0018 §2.13](../../backend/docs/adrs/ADR-0018-keycloak-realm-provisioning-automation.md);
- [ANL-00053](../../analysis/ANL-00053-keycloak-empty-conditional-2fa-flow.md);
- `IMPLEMENTATION-READINESS-STANDARD` e guardrails de `infra/AGENTS.md`.

### Gate Audit

| Controle | Resultado | Evidência |
| --- | --- | --- |
| Fontes superiores | PASS | REQ-00059 v1.4 `Approved`; ADR-0018 v3.4 `Accepted`. |
| User Story View | PASS | REQ-00059 §2.1 cobre o login DEV em AC-59-002. |
| Use Case aplicável | PASS | N/A: correção técnica de topologia sem novo passo de usuário; AC-59-002 mapeia diretamente para teste do reconciliador. |
| Assumptions | PASS | ASM-59-002 `Validated` pela ANL-00053 e fontes primárias Keycloak 26.6.3. |
| Open Questions | PASS | OQ-59-001–005 permanecem `Resolved`; nenhuma pergunta nova está aberta. |
| Dependências | PASS | Scripts, fixture e Admin API já usados pelo fluxo estão disponíveis; nenhum ambiente externo é necessário. |
| Escopo | PASS | Somente reconciliador/teste/configuração explicativa e documentação relacionada; HML/PRD e volume persistido excluídos. |
| Tarefa | PASS | What, Where, Depends on, Reuses, Requirements, testes, proibições, obrigações e DoD são finitos. |

### Acceptance Tests

| Critério | Evidência planejada |
| --- | --- |
| OFF canônico | Teste exige pai `DISABLED`, folha `ALTERNATIVE` e provider `false`. |
| Reparo crítico | Fixture inicia em `CONDITIONAL/DISABLED/false` e termina no estado OFF canônico. |
| Rollback | Teste exige provider `true`, folha `ALTERNATIVE` e pai `CONDITIONAL`, nessa ordem segura. |
| Fail-closed | Pai/condição/OTP ausente, duplicado, nível inválido ou requirement não gerido falha sem mutação. |
| Preservação | Prioridades/IDs não mudam e nenhuma operação toca credencial de usuário. |
| Sintaxe e suíte impactada | `bash -n` nos scripts; teste focal, hardening Keycloak e contratos do realm passam. |
| Governança | `./infra/scripts/validate-docs.sh` passa. |

### Prohibited

- desabilitar a folha `auth-otp-form` como mecanismo do toggle;
- identificar o pai por texto visual, UUID fixo ou posição absoluta;
- remover required action, provider, execução, credencial ou mapper AMR;
- ler segredo, executar reconciliação stateful, reiniciar stack ou alterar HML/PRD;
- mascarar gate vermelho ou usar o sucesso do action token como smoke de login.

### Mandatory

- associação estrutural e única entre OTP, pai direto e
  `conditional-user-configured`;
- ordem de mutação que só reativa o pai após provider/folha válidos;
- pós-condição exata dos três estados e idempotência;
- teste de regressão que falhe com a implementação v1.3;
- documentação sem PII, token, UUID de usuário ou log bruto.

### Definition of Done

- [x] teste focal falha contra a implementação v1.3 pelo estado legado;
- [x] reconciliador converge OFF/ON e estado legado para a matriz de REQ-00059;
- [x] testes focal/impactados, sintaxe shell e Quality Gate aplicável passam;
- [x] ANL-00053 permanece o único registro do incidente e os índices validam;
- [x] handoff distingue correção repository-local de reconciliação ambiental não executada.

### Result

`READY` — auditor `AgentOrchestrator` via skill `implementation-readiness`, em
2026-09-09, para TP-00042-F01 e os paths exatos acima. Blockers: nenhum.
Reconciliação do volume DEV continua fora deste handoff.

## Evidências TP-00042-F01 v1.6

- RED controlado: a fixture do estado legado falhou antes do patch com
  `DEV reconciliation did not disable the direct 2FA parent flow`;
- `bash -n infra/keycloak/bootstrap/reconcile-admin-login-mfa.sh` e
  `bash -n infra/scripts/tests/keycloak-admin-login-mfa-toggle-test.sh`: PASS;
- `bash infra/scripts/tests/keycloak-admin-login-mfa-toggle-test.sh`: PASS, 39
  invocações — 16 sucessos e 23 recusas esperadas — incluindo rollback legado
  ON, provider-only e falha parcial injetada que mantém o pai `DISABLED`;
- `bash infra/scripts/tests/keycloak-runtime-json-validator-test.sh`: PASS, 46
  cenários;
- `bash infra/scripts/tests/keycloak-bootstrap-hardening-test.sh`: PASS;
- `bash infra/scripts/tests/keycloak-billing-mfa-amr-test.sh`: PASS;
- `bash infra/keycloak/bootstrap/validate-realm-token-contracts.sh`: PASS;
- `bash infra/scripts/tests/deploy-production-v40-config-test.sh`: PASS;
- `./infra/scripts/validate-quality-gates.sh --scope infra --level focused
  --focus infra/keycloak/bootstrap/reconcile-admin-login-mfa.sh`: PASS;
- `./infra/scripts/validate-quality-gates.sh --scope infra --level pr`: PASS;
- `./infra/scripts/validate-docs.sh`: PASS;
- revisão A3: nenhuma credencial/segredo manipulada; estados não DEV e topologias
  ambíguas falham antes da mutação;
- reconciliação do volume DEV e smoke OIDC em outro browser: `NOT EXECUTED`, por
  permanecerem fora da autorização repository-local.

## Evidências históricas da abordagem substituída

- `bash -n infra/keycloak/bootstrap/validate-realm-token-contracts.sh`: PASS;
- `bash infra/keycloak/bootstrap/validate-realm-token-contracts.sh`: PASS;
- `bash infra/scripts/tests/keycloak-bootstrap-hardening-test.sh`: PASS, inclusive
  reconciliação AMR idempotente e least privilege;
- `./infra/scripts/validate-docs.sh`: o contrato alterado não apresentou erro,
  mas o gate global permaneceu vermelho por divergência externa ao recorte em
  `docs/architecture/module-registry.md` (`Java 25`), arquivo não alterado aqui.

Essas evidências pertencem à implementação v1.1, agora substituída porque remover
a ação do export não desabilitava o desafio de uma credencial já configurada nem
reconciliava volume persistido. As evidências da implementação substituta estão
registradas abaixo. Nenhuma alteração ambiental foi executada neste recorte.

## Evidências históricas v1.3 — contrato de login invalidado

- `bash -n` nos reconciliadores, validador, bootstrap e testes alterados: PASS;
- `bash infra/scripts/tests/keycloak-runtime-json-validator-test.sh`: PASS em
  46 cenários, inclusive preservação integral do payload da required action;
- `bash infra/scripts/tests/keycloak-admin-login-mfa-toggle-test.sh`: PASS para
  OFF/rollback, idempotência, escopo DEV, prioridade preservada, estados
  ambíguos e ausência de remoção de credencial;
- `bash infra/scripts/tests/keycloak-bootstrap-hardening-test.sh`: PASS;
- `bash infra/keycloak/bootstrap/validate-realm-token-contracts.sh`: PASS;
- `bash infra/scripts/tests/keycloak-billing-mfa-amr-test.sh`: PASS;
- `bash infra/scripts/tests/start-dev-bot-outbound-keyring-test.sh`: PASS na
  repetição isolada; uma execução paralela anterior falhou no cenário de cleanup
  resistente a `TERM`, sem relação com o toggle e sem reprodução isolada;
- `./infra/scripts/validate-docs.sh`: PASS, incluindo governança, IP-INFRA e
  estrutura documental;
- renderização Compose/deploy: não concluída neste host porque o `docker compose`
  empacotado por Snap não obteve `cap_dac_override`; nenhuma stack foi iniciada;
- migração do volume DEV e smoke de login novo/incógnito: NOT EXECUTED. O estado
  persistido só receberá o toggle após o runbook operacional autorizado.

Embora esses comandos tenham passado, a expectativa
`auth-otp-form=DISABLED` codificava o defeito descrito em ANL-00053 e não constitui
mais evidência válida para AC-59-002.

## Change log

| Version | Date | Author | Changes |
| --- | --- | --- | --- |
| 1.8 | 2026-09-12 | Segurança, Infraestrutura e Qualidade / Codex | Conclui F02 repository-local com flag explícita, matriz multiambiente 6/6 e gates verdes; mantém F03 templates/deploy pendente e sem handoff executável. |
| 1.7 | 2026-09-12 | Segurança, Infraestrutura e Qualidade / Codex | Reconcilia o alvo DEV/HML/PRD e decompõe F02 reconciliador, em IRG READY, de F03 templates/deploy ainda sem handoff executável. |
| 1.6 | 2026-09-09 | Segurança, Infraestrutura, Qualidade / Codex | Reforça a ordem fail-closed no rollback legado, cobre falha parcial e reconcilia o alcance realm-wide do login com os waivers Billing separados do TP-00047. |
| 1.5 | 2026-09-09 | Segurança, Infraestrutura, Qualidade / Codex | Conclui TP-00042-F01 no repositório com prova red→green e gates infra verdes; preserva volume DEV e smoke OIDC como pendências operacionais. |
| 1.4 | 2026-09-09 | Segurança, Infraestrutura / Codex | Reabre o corretivo crítico TP-00042-F01 com IRG READY: desabilita o pai 2FA, preserva a folha OTP, repara o estado legado e vincula ANL-00053 como registro único do incidente. |
| 1.3 | 2026-09-07 | Codex | Implementa e valida o toggle reversível; o PUT preserva integralmente a representação CONFIGURE_TOTP e ficam explícitas as pendências de volume/smoke. |
| 1.2 | 2026-09-07 | Solicitante humano / Codex | Substitui a remoção incorreta por toggle reversível: preserva CONFIGURE_TOTP/credencial/AMR e desabilita provider + execução OTP somente em DEV, com reconciliação de volume persistido. |
| 1.1 | 2026-09-06 | Codex | Implementa a exceção no realm DEV, atualiza o contrato estático e registra os gates e a pendência ambiental. |
| 1.0 | 2026-09-06 | Solicitante humano / Codex | Persiste autorização, limites, rollback e critérios antes da edição transversal. |
