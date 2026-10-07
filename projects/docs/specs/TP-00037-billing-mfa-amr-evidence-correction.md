---
document_id: TP-00037
primary_nature: Plano
objective: Corrigir o ciclo de reautenticação MFA do Billing garantindo que uma execução OTP recente seja representada no claim OIDC amr e reconhecida pelo backend.
scope: Diagnóstico, contrato Keycloak do realm administrativo, bootstrap de instalações novas, recovery de volume persistido, validação estrutural, testes herméticos e teste focalizado frontend/backend.
non_objectives: Não relaxar a autorização financeira, não aceitar iat/acr isolado como MFA, não mudar maker-checker, não chamar ASAAS, não acessar dados reais e não executar rollout DEV/HML/PRD.
owner: Engenharia, Segurança e Billing
status: Completed — repository-local; historical MFA evidence baseline preserved
version: 1.2
date: 2026-09-06
last_reviewed: 2026-09-06
keywords: billing, mfa, amr, keycloak, step-up, super-admin, fail-closed
related_files: ../../backend/docs/adrs/ADR-0018-keycloak-realm-provisioning-automation.md, ../../backend/docs/adrs/ADR-0050-rbac-sod-aprovacoes-financeiras.md, do../../product/requirements/REQ-00054-super-admin-unified-billing-price-version.md, TP-00035-super-admin-unified-billing-management.md, TP-00038-billing-contract-context-temporary-mfa-disablement.md
code_references: frontend/src/providers/AuthProvider.tsx, backend/src/main/java/br/com/duoset/saas_service/contexts/billing/internal/infrastructure/security/SpringSecurityBillingCatalogActorAdapter.java, infra/keycloak/bootstrap/reconcile-billing-mfa-amr.sh, infra/keycloak/bootstrap/ensure-management-service-account.sh, infra/keycloak/bootstrap/migrate-persisted-volume.sh, infra/keycloak/bootstrap/validate-keycloak-runtime-json.sh
principal_statement: Este plano preserva a evidência AMR correta para todo fluxo que exige MFA; o TP-00038 sucede apenas a aplicação dessa exigência no contexto Super Admin exclusivamente contratual, sem remover ou fabricar evidência.
---

# TP-00037 — Correção da evidência MFA/AMR do Billing

References: [ADR-0018](../../backend/docs/adrs/ADR-0018-keycloak-realm-provisioning-automation.md) ·
[ADR-0050](../../backend/docs/adrs/ADR-0050-rbac-sod-aprovacoes-financeiras.md) ·
[REQ-00054](../../product/requirements/REQ-00054-super-admin-unified-billing-price-version.md) ·
[TP-00035](TP-00035-super-admin-unified-billing-management.md) ·
[TP-00038](TP-00038-billing-contract-context-temporary-mfa-disablement.md) ·
[Keycloak Server Administration Guide](https://www.keycloak.org/docs/latest/server_admin/#_step-up-flow)

> **Nota histórica/sucessão:** as seções abaixo preservam a causa, a solução e as
> evidências executadas por este plano em 2026-09-06. O TP-00038 não desfaz o
> contrato AMR/Keycloak nem reclassifica senha como MFA; ele sucede somente a
> exigência de prova MFA na emissão e no uso do contexto Super Admin composto
> exclusivamente pela allowlist contratual, enquanto a flag reversível estiver
> `false`. Catálogo, invoice/run, Tenant Admin e os demais fluxos continuam sob o
> baseline deste plano.

## 1. Resultado esperado

Depois de selecionar **Refazer autenticação com MFA**, concluir senha e TOTP e
retornar para `/admin/billing/tenants`, o access token do
`saas-frontend-spa` deve conter `amr` com `otp` e `auth_time` recente. A emissão
de `BillingElevatedContext` então prossegue se tenant, purpose e authority também
forem válidos. O mesmo token deixa de ser aceito quando a prova ultrapassa 900
segundos.

O backend permanece como autoridade. O navegador não cria, corrige nem atesta
MFA; ele apenas inicia uma autenticação interativa com `prompt=login` e
`max_age=0` e apresenta o erro tipado devolvido pela API.

## 2. Evidência e causa raiz

### 2.1 Caminho observado

1. `BillingTenantLauncher` envia `POST /api/v1/admin/billing/elevated-contexts`.
2. `ManageBillingElevatedContextUseCase` exige ator humano, authority fina,
   purpose e `BillingMfaEvidence` fresca por no máximo 15 minutos.
3. `SpringSecurityBillingCatalogActorAdapter` constrói a prova apenas de claims
   assinadas: método em `amr` e instante em `mfa_time` ou `auth_time`.
4. `AuthProvider.reauthenticate()` já força autenticação interativa e preserva a
   rota de retorno.
5. Os realms possuem o protocol mapper `oidc-amr-mapper`, mas as execuções
   `auth-username-password-form` e `auth-otp-form` não possuem Authenticator
   Reference Value/Max Age.

### 2.2 Causa

No Keycloak 26.6.3 o mapper AMR não deduz `pwd` ou `otp` pelo nome do
authenticator. Ele lê somente `default.reference.value` das configurações das
execuções concluídas e descarta a referência quando
`default.reference.maxAge` expirou. Portanto, o usuário pode concluir TOTP e,
mesmo assim, receber `amr` vazio. O backend interpreta corretamente esse token
como ausência de prova MFA e devolve `BILLING_MFA_REQUIRED`.

### 2.3 Hipóteses rejeitadas

- usar `iat` como instante de MFA: refresh de token pareceria nova MFA sem novo
  fator;
- aceitar `acr` genérico sem uma execução autenticadora correspondente;
- confiar em flag do frontend, cookie/local storage ou parâmetro enviado pelo
  browser;
- remover a checagem de 15 minutos ou aceitar autenticação somente por senha;
- habilitar reconciliação privilegiada silenciosa no `start-dev-bot.sh`.

## 3. Solução selecionada

### 3.1 Contrato canônico

| Execução Keycloak | Referência AMR | Max age | Interpretação backend |
| --- | --- | ---: | --- |
| `auth-username-password-form` | `pwd` | 900 s | Primeiro fator; nunca satisfaz MFA sozinho. |
| `auth-otp-form` | `otp` | 900 s | Segundo fator aceito por `BillingMfaEvidence`. |

Os aliases gerenciados serão versionados e explícitos:
`saas-billing-amr-pwd-v1` e `saas-billing-amr-otp-v1`. Um config exato existente
é reutilizado independentemente do alias. Drift sob alias gerenciado pode ser
reconciliado; configuração estrangeira divergente falha fechada e não é
sobrescrita.

### 3.2 Instalação nova e volume persistido

- `ensure-management-service-account.sh` fará verificação read-only do contrato
  antes de declarar a identidade técnica pronta.
- No primeiro bootstrap ou em `KEYCLOAK_FORCE_RECONCILE=true`, quando uma
  identidade administrativa revisada já está ativa, o mesmo script cria ou
  corrige somente os dois configs de execução no `saas-admin`.
- No start normal, a identidade técnica permanente conserva o conjunto mínimo
  de privilégios. Se houver drift, o init termina antes do cutover e orienta o
  recovery controlado; ele não eleva privilégios para reparar.
- Em volume persistido, `migrate-persisted-volume.sh` continua sendo o único
  caminho autorizado: cria administrador temporário, chama o reconciliador em
  modo forçado, verifica com a identidade permanente e remove a identidade
  temporária.

### 3.3 Fronteiras de segurança

- Somente o realm exato `saas-admin` e o browser flow efetivamente vinculado são
  inspecionados.
- A enumeração é limitada, rejeita IDs/formato ambíguos e exige exatamente uma
  execução de senha e uma de OTP.
- Toda mutação é precedida de classificação estrutural; configuração de origem
  desconhecida não é adotada nem apagada.
- A verificação pós-mudança exige os dois valores e max ages exatos.
- Nenhum token, senha, OTP ou conteúdo do arquivo de sessão `kcadm` aparece em
  stdout, argumento de processo, log ou documento.
- A regra backend `amr + auth_time/mfa_time + freshness` não muda.

## 4. Plano de implementação

| # | Atividade | Dependência | Saída | Estado |
| --- | --- | --- | --- | :---: |
| 1 | Persistir diagnóstico, decisão e limites | ADR-0018, ADR-0050 e REQ-00054 | Este TP e índice | ✅ |
| 2 | Criar reconciliador isolado e idempotente de AMR | 1 | Script POSIX testável sem Docker | ✅ |
| 3 | Integrar verify/reconcile ao bootstrap Keycloak | 2 | Fresh install e start normal fail-closed | ✅ |
| 4 | Acoplar recovery existente sem ampliar privilégios permanentes | 3 | Volume persistido corrigível pelo migrador | ✅ |
| 5 | Adicionar validação estrutural e testes de drift | 2 | Provas positiva, negativa e idempotente | ✅ |
| 6 | Reexecutar testes frontend/backend que congelam a fronteira | 3 | Reauth interativa e AMR server-side preservadas | ✅ |
| 7 | Executar gates, registrar evidências e concluir o plano | 1–6 | Handoff reproduzível | ✅ |

## 5. Casos de teste

### 5.1 Reconciliador hermético

- config ausente nas duas execuções: cria exatamente dois configs;
- segunda execução: zero mutações e verificação verde;
- `pwd` correto e `otp` ausente: cria somente OTP;
- alias gerenciado com valor/max age em drift: atualiza somente o config
  gerenciado;
- alias externo divergente: falha sem update/delete;
- provider ausente, duplicado, ID inválido, flow vazio/ambíguo ou paginação acima
  do limite: falha sem mutação;
- config com campo extra/decoy, tipo não-string ou max age diferente de `900`:
  não é classificado como exato;
- `verify` nunca executa create/update/delete.

### 5.2 Fronteiras existentes

- frontend continua enviando `prompt=login`, `maxAge=0` e a rota atual;
- backend aceita `amr=[pwd, otp]` com `auth_time` válido;
- backend rejeita `amr=[pwd]`, claim ausente/ambígua e prova vencida;
- realm token contract mantém mapper AMR exato no access token;
- bootstrap hardening comprova privilégios permanentes inalterados e recovery
  temporário removido.

## 6. Comandos de validação

```bash
bash -n infra/keycloak/bootstrap/reconcile-billing-mfa-amr.sh
bash -n infra/keycloak/bootstrap/ensure-management-service-account.sh
bash -n infra/keycloak/bootstrap/migrate-persisted-volume.sh
bash infra/scripts/tests/keycloak-billing-mfa-amr-test.sh
bash infra/scripts/tests/keycloak-bootstrap-hardening-test.sh
bash infra/keycloak/bootstrap/validate-realm-token-contracts.sh
cd frontend && npm test -- --run src/providers/__tests__/AuthProvider.session.test.tsx
cd backend && ./mvnw -B -Dtest=SpringSecurityBillingCatalogActorAdapterTest,ManageBillingElevatedContextUseCaseTest test
./infra/scripts/validate-docs.sh
```

O gate Docker/Keycloak real é ambiental e só será executado mediante ambiente e
autorização próprios. Esta mudança não acessa o Keycloak em execução nem aplica
o recovery no volume do desenvolvedor.

## 7. Critérios de aceite

- [x] AC-01: o contrato repository-local configura a execução TOTP para produzir
  `amr` com `otp` por no máximo 900 segundos; a comprovação em token vivo fica no
  gate operacional posterior.
- [x] AC-02: senha isolada nunca satisfaz `BillingMfaEvidence`.
- [x] AC-03: o start normal verifica o contrato e falha antes do cutover quando
  o volume persistido precisa de recovery.
- [x] AC-04: first install/forced recovery reconciliam somente os configs
  gerenciados e verificam o resultado.
- [x] AC-05: a identidade técnica permanente mantém seus privilégios exatos;
  `manage-realm` não é adicionado.
- [x] AC-06: configuração estrangeira divergente não é sobrescrita ou apagada.
- [x] AC-07: nenhum mecanismo client-side vira evidência de autorização.
- [x] AC-08: testes herméticos, focalizados e governança documental ficam verdes.

## 8. Evidências repository-local

| Gate | Resultado |
| --- | --- |
| Sintaxe dos quatro scripts Keycloak afetados | PASS |
| `keycloak-billing-mfa-amr-test.sh` | PASS: ausente, exato, drift gerenciado, drift externo, duplicidade, pós-condição e idempotência |
| `keycloak-runtime-json-validator-test.sh` | PASS: 39 cenários existentes; os novos casos AMR são cobertos adicionalmente pelo teste focal |
| `keycloak-bootstrap-hardening-test.sh` | PASS, incluindo o teste AMR agregado e least privilege |
| `validate-realm-token-contracts.sh` | PASS |
| `start-dev-bot-outbound-keyring-test.sh` | PASS |
| Compose base + DEV com valores dummy e `config --quiet` | PASS; nenhum container iniciado |
| `AuthProvider.session.test.tsx` | 11/11 PASS |
| `SpringSecurityBillingCatalogActorAdapterTest` + `ManageBillingElevatedContextUseCaseTest` | 7/7 PASS |
| `validate-docs.sh` | PASS após expandir a referência documental compacta indicada pelo primeiro diagnóstico do gate |

A primeira renderização Compose revelou uma variável dummy ausente; a segunda,
com o conjunto completo, encontrou a limitação `snap-confine` do sandbox. A mesma
renderização read-only foi repetida fora do sandbox, ainda somente com valores
fictícios, e retornou código zero.

Não foram executados: mutação do volume Keycloak local, invalidação de sessão,
novo login/TOTP, inspeção de token real, smoke autenticado, HML, PRD ou ASAAS.
Assim, `Completed — repository-local` não afirma ativação ambiental.

## 9. Rollback e operação posterior

O rollback de código remove a integração do reconciliador, mas não deve remover
automaticamente configs já criados: eles apenas fazem o token descrever métodos
realmente executados. Se rollback operacional for necessário, deve ser um novo
procedimento aprovado, com inventário dos IDs e prova de que nenhuma política
depende de `amr`.

Após merge e antes de testar a UI com o volume local existente, o operador deve
executar explicitamente:

```bash
infra/keycloak/bootstrap/migrate-persisted-volume.sh
./start-dev-bot.sh
```

Isso interrompe/reinicia o Keycloak local de forma controlada; não faz parte da
codificação repository-local desta tarefa.

## 10. Registro de decisão

| Data | Autor | Decisão |
| --- | --- | --- |
| 2026-09-06 | Codex (IA), por solicitação humana de diagnóstico/plano/correção | Corrigir a emissão AMR na origem Keycloak, preservar o backend fail-closed, não promover `acr`/`iat`/frontend a prova de MFA e reutilizar o recovery privilegiado explícito já governado. |

## 11. Change log

| Versão | Data | Autor | Mudança |
| --- | --- | --- | --- |
| 1.2 | 2026-09-06 | Codex (IA) | Preserva o resultado histórico e registra que TP-00038 sucede somente a exigência MFA do contexto Super Admin exclusivamente contratual; AMR/Keycloak e demais fluxos permanecem vigentes. |
| 1.1 | 2026-09-06 | Codex (IA) | Conclui reconciliador, integração first-bootstrap/recovery, verificação least-privilege, testes e gates repository-local; mantém execução no volume e smoke real fora do escopo. |
| 1.0 | 2026-09-06 | Codex (IA) | Cria diagnóstico, solução, plano, testes, critérios e limites antes da implementação. |
