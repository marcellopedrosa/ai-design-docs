---
document_id: TP-00064
primary_nature: Plano
objective: Integrar ao start de HML e PRD a configuração SMTP idempotente dos realms saas-admin e saas-bpfarias pela Keycloak Admin REST API.
scope: Provisionador de realms estáticos, wrappers HML/PRD, fronteira do segredo SMTP, Compose/deploy, testes herméticos e onboarding operacional.
non_objectives: Alterar o SMTP de DEV; acessar HML/PRD; enviar e-mail real; versionar credenciais; configurar SMTP particular por tenant; substituir o provisionamento dinâmico do backend.
owner: Engenharia de Plataforma e Segurança/IAM
status: Completed
version: 1.1
date: 2026-09-24
last_reviewed: 2026-09-24
keywords: keycloak, smtp, startup, hml, prd, secret, admin-rest-api
related_files: do../../product/requirements/REQ-00058-keycloak-password-recovery-smtp.md, ../../backend/docs/adrs/ADR-0018-keycloak-realm-provisioning-automation.md, TP-00063-keycloak-admin-api-realm-provisioning.md, ../../backend/docs/onboarding/keycloak-provisioning-identity.md
code_references: infra/keycloak/provision/provision-realms.sh, infra/keycloak/provision/dev.sh, infra/keycloak/provision/hml.sh, infra/keycloak/provision/production.sh, infra/keycloak/bootstrap/reconcile-realm-smtp.sh, docker-compose.hml.yml, docker-compose.prd.yml, infra/scripts/deploy-production.sh, infra/scripts/tests/
principal_statement: O start de HML e PRD deve consumir o segredo ambiental TF_VAR_contadorfiscal_smtp_password sem expô-lo e convergir o SMTP dos dois realms estáticos pela API oficial; DEV permanece no Mailpit.
---

# TP-00064 — SMTP dos realms estáticos no start de HML e PRD

## 1. Resultado esperado

Ao iniciar o projeto pela primeira vez em HML ou PRD, o mesmo pipeline que cria
`saas-admin` e `saas-bpfarias` configura o `smtpServer` de ambos pela Admin REST
API do Keycloak. Reexecuções convergem realms novos ou existentes sem duplicação.
DEV continua usando Mailpit e não exige o segredo externo.

`TF_VAR_contadorfiscal_smtp_password` é o nome da entrada secreta em cada
ambiente. O nome é igual, mas HML e PRD mantêm valores e custódia independentes.
O provisionador não consulta Terraform nem persiste a variável: o entrypoint de
cada ambiente apenas a transforma, em memória, no contrato interno consumido pelo
reconciliador.

## 2. Decomposição semântica

| Task | Resultado observável | Dependência | Handoff |
| --- | --- | --- | --- |
| `KC-SMTP-001` | Política DEV/HML/PRD e fronteira do segredo ficam consistentes. | Decisão humana de 2026-09-24 | Requisito, ADR e documentação alinhados. |
| `KC-SMTP-002` | Start HML/PRD valida e encaminha o segredo sem log, argv ou arquivo versionado. | `KC-SMTP-001` | Wrappers/Compose falham antes de mutação quando ausente. |
| `KC-SMTP-003` | Os dois realms recebem SMTP no create e na reconciliação idempotente. | `KC-SMTP-002`, TP-00063 | Estado final verificado pela Admin API. |
| `KC-SMTP-004` | Testes provam matriz ambiental, idempotência e não vazamento. | `KC-SMTP-003` | Testes focalizados e Quality Gate verdes. |
| `KC-SMTP-005` | Onboarding local, HML e PRD descreve primeiro start e rotação. | `KC-SMTP-004` | Runbook e índices validados. |

## 3. Contrato de configuração

Para HML e PRD, a configuração desejada é:

| Campo Keycloak | Valor |
| --- | --- |
| `host` | `smtp.hostinger.com` |
| `port` | `465` |
| `from` | `no-reply@contadorfiscal.com.br` |
| `fromDisplayName` | `Contador Fiscal` |
| `replyTo` / usuário SMTP | `contato@contadorfiscal.com.br` |
| `replyToDisplayName` | `Contador Fiscal` |
| `auth` / `ssl` / `starttls` | `true` / `true` / `false` |
| `password` | entrada `TF_VAR_contadorfiscal_smtp_password`, nunca literal |

Os valores não secretos vieram da evidência visual fornecida pelo solicitante;
a decisão normativa sobre ambientes e segredo é a solicitação humana atual.

## 4. Implementation Readiness Gate

### 4.1 Gate Audit

| Controle | Evidência | Resultado |
| --- | --- | --- |
| Product Definition | Não altera comportamento de produto; automatiza configuração IAM já requerida. | N/A |
| Requirements | REQ-00058 v1.4 aprova Mailpit somente em DEV e SMTP externo em HML/PRD. | PASS |
| ADRs | ADR-0018 v4.0 aceita a fronteira do start e do segredo. | PASS |
| Use Cases | Recuperação de senha do UC-00036 permanece inalterada. | PASS |
| API Contract | Não altera API HTTP do backend; usa Admin REST API oficial já adotada no TP-00063. | N/A |
| Assumptions | Nenhuma; ambientes, realms, transporte, conta e variável foram definidos. | PASS |
| Open Questions | Nenhuma. Valores da variável são deliberadamente environment-scoped. | PASS |
| Dependencies | TP-00063 v1.4 concluído; `kcadm.sh` 26.6.3 e reconciliador SMTP existentes. | PASS |
| Granularity | Cinco resultados independentes com dependências e handoffs explícitos. | PASS |

### 4.2 Acceptance Tests

| Critério | Evidência esperada |
| --- | --- |
| `AC-SMTP-01` | Primeira execução HML/PRD cria cada realm e grava exatamente o contrato SMTP esperado. |
| `AC-SMTP-02` | Segunda execução e realm preexistente convergem sem duplicação nem alteração fora da allowlist. |
| `AC-SMTP-03` | Ausência ou valor vazio de `TF_VAR_contadorfiscal_smtp_password` aborta antes da primeira mutação. |
| `AC-SMTP-04` | DEV funciona sem a variável e permanece em `mailpit:1025`, sem autenticação/TLS. |
| `AC-SMTP-05` | Senha sintética não aparece em Git, stdout, stderr, argv, fixtures persistidas ou evidências. |
| `AC-SMTP-06` | Leitura final pela Admin API comprova SMTP e `resetPasswordAllowed=true` em `saas-admin` e `saas-bpfarias`. |
| `AC-SMTP-07` | Testes rejeitam Mailpit, transporte sem SSL, conta divergente e realm fora da allowlist em HML/PRD. |

### 4.3 Prohibited

- ler ou registrar o valor real do segredo; colocá-lo em argumento de comando,
  arquivo versionado, log, mensagem de erro ou evidência;
- acessar HML/PRD ou enviar e-mail real durante a implementação repository-local;
- alterar realm fora de `saas-admin` e `saas-bpfarias` neste pipeline;
- introduzir JSON de export/import de realm ou depender de estrutura privada do
  banco do Keycloak;
- fazer DEV depender do SMTP externo.

### 4.4 Mandatory

- reutilizar uma única função/reconciliador SMTP e `kcadm.sh`, sem duplicar a
  montagem do payload nos wrappers;
- validar toda configuração antes da criação do primeiro realm e limpar qualquer
  materialização temporária com `umask 077` e trap;
- configurar e verificar SMTP tanto para realm recém-criado quanto preexistente;
- usar segredos sintéticos nos testes e inspecionar explicitamente argv e saídas;
- executar `bash -n`/`sh -n`, testes SMTP e provisionamento, Compose sintético,
  Quality Gate aplicável e `validate-docs.sh`.

### 4.5 Definition of Done

- [x] HML e PRD consomem `TF_VAR_contadorfiscal_smtp_password` no start e falham
  fechado antes de mutação quando ela não está disponível.
- [x] `saas-admin` e `saas-bpfarias` convergem para o SMTP definido neste plano em
  primeira execução e reexecução.
- [x] DEV continua isolado no Mailpit e sem dependência da variável externa.
- [x] Nenhum segredo é exposto em Git, argv, logs ou artefatos de teste.
- [x] Testes focalizados, suíte impactada, Compose e Quality Gate passam.
- [x] Onboarding documenta primeiro start, preflight, rotação e diagnóstico sem
  revelar credenciais.

### 4.6 Result

**Resultado: `READY`.** Auditor: Codex, 2026-09-24. Escopo autorizado para a
implementação futura: `KC-SMTP-001..005` e somente os paths declarados neste
plano. A autorização é repository-local; deploy, acesso a HML/PRD e envio real
continuam excluídos.

## 5. Sequência de implementação

1. Extrair do reconciliador atual uma interface reutilizável pelo provisionador e
   aceitar `hml|production` como SMTP externo, preservando `dev` como Mailpit.
2. Adicionar preflight nos wrappers HML/PRD: validar a variável de origem e
   encaminhá-la ao processo filho sem impressão; manter o contrato interno
   `KEYCLOAK_REALM_SMTP_PASSWORD` somente dentro do processo do provisionador.
3. Fazer `provision-realms.sh` aplicar SMTP após criar cada realm e também
   reconciliar realms existentes, seguido de leitura/verificação fail-closed.
4. Alinhar Compose e deploy para entregar a variável ao one-shot somente durante
   o bootstrap. O backend recebe apenas o contrato que ainda necessita para criar
   tenants dinâmicos; não recebe `TF_VAR_*` diretamente.
5. Atualizar testes e onboarding; executar gates. Smokes ambientais e envio real
   ficam como handoff operacional separado, com aprovação do ambiente.

## 6. Rollback e rotação

Rollback de código restaura o pipeline anterior sem apagar realms ou usuários.
Rotação troca o valor no cofre/variável protegida do respectivo ambiente e
reexecuta o provisionador privilegiado, que força a reconciliação porque o
Keycloak mascara a senha em leituras. HML e PRD são rotacionados separadamente.

## 7. Evidências de encerramento

- A1 `PASS`: testes de provisionamento estático, reconciliação SMTP, matriz
  Mailpit/SMTP externo, validação PRD e deploy modular passaram sem skips.
- A2 `PASS`: Quality Gate `infra/focused` e `infra/pr` retornaram `PASS`; todos os
  scripts alterados têm sintaxe válida e permanecem abaixo de 500 linhas.
- A3 `PASS`: teste com segredo sintético comprova ausência em argv/stdout/stderr;
  preflight HML sem senha aborta com zero chamada à Admin API.
- Compose HML e PRD renderizaram com `config --quiet`, arquivo de exemplo explícito
  e segredo sintético; nenhum container foi iniciado.
- Nenhum ambiente real, provider, `.env`, credencial ou dado foi acessado. Envio
  real e rollout permanecem handoffs operacionais separados.

## 8. Change Log

| Version | Date | Change |
| --- | --- | --- |
| 1.1 | 2026-09-24 | Conclui scripts, preflight, reconciliação, Compose, testes, onboarding e gates repository-local. |
| 1.0 | 2026-09-24 | Aprova o plano para SMTP externo no start de HML/PRD, com segredo environment-scoped e reconciliação Admin API dos dois realms estáticos. |
