---
document_id: TP-00043
primary_nature: Plano
objective: Substituir a identidade humana do Super Admin DEV de superadmin@duoset.com.br para djmarcellopedrosa@gmail.com em provisionamento, reconciliação, contratos, testes e documentação.
scope: Export do realm saas-admin DEV, reconciliação segura de volume Keycloak persistido, validadores estáticos, mocks e testes frontend e referências documentais vigentes.
non_objectives: Não alterar senha, roles, MFA, AMR ou tenant_id; não promover a mudança em HML/PRD; não acessar ou mutar realms em execução; não reescrever migrations Flyway já publicadas; não ler, registrar ou versionar segredos.
owner: Segurança, Infraestrutura e Engenharia
status: Completed
version: 1.1
date: 2026-09-07
last_reviewed: 2026-09-07
keywords: keycloak, super admin, identidade, desenvolvimento, provisionamento
related_files: ../../backend/docs/adrs/ADR-0018-keycloak-realm-provisioning-automation.md, TP-00042-temporary-dev-super-admin-login-mfa-disablement.md, do../../product/requirements/REQ-00041-chatbot-conversation-audit.md
code_references: historical: infra/keycloak/dev/saas-admin-realm.json, infra/keycloak/bootstrap/migrate-persisted-volume.sh, infra/keycloak/bootstrap/validate-realm-token-contracts.sh, frontend/src/mocks/data/user.ts
principal_statement: A identidade canônica do Super Admin DEV passa a ser djmarcellopedrosa@gmail.com, preservando privilégios, MFA, ausência de tenant_id e limites ambientais existentes.
---

# TP-00043 — Renomeação da identidade Super Admin DEV

## Autorização e limites

A solicitação humana de 2026-09-07 autoriza substituir a conta
`superadmin@duoset.com.br` por `djmarcellopedrosa@gmail.com` em todas as
referências mutáveis do repositório, incluindo provisionamento do realm e
documentação. A autorização não inclui deploy, acesso ao Keycloak em execução,
leitura de senha, envio de e-mail ou alteração de privilégios.

O endereço identifica uma conta externa ao domínio da aplicação. Isso não muda
o contrato de autenticação: a identidade continua humana, global, sem
`tenant_id`, com `ROLE_SUPER_ADMIN` e com os controles de MFA/AMR já definidos.

## Inventário e execução

| Área | Mudança prevista | Restrição |
| --- | --- | --- |
| Realm DEV novo | Atualizar `username` e `email` no export `saas-admin` | Preservar ID lógico, roles, required actions e demais atributos |
| Volume DEV persistido | Reconciliar de forma idempotente a identidade antiga para a nova | Falhar fechado diante de conflito, duplicidade ou identidade ambígua |
| Contrato estático | Passar a exigir a nova identidade | Não relaxar validações de role, MFA, AMR ou `tenant_id` |
| Frontend | Atualizar mock canônico e testes associados | Não alterar comportamento de autorização |
| Documentação | Atualizar referências vigentes e registros que nomeiam a identidade canônica | Preservar significado, datas e evidências históricas |
| Flyway | Manter migration histórica publicada sem alteração | Evitar checksum divergente em bancos que já aplicaram a migration |

## Estratégia para realm persistido

O JSON de importação governa somente realms novos. Para um volume DEV existente,
o reconciliador privilegiado deve localizar a identidade por correspondência
exata, recusar a operação se a conta de destino já pertencer a outro usuário,
atualizar `username` e `email` no mesmo usuário e comprovar a pós-condição antes
de continuar. O startup normal permanece apenas verificável e
least-privileged.

Nenhuma reconciliação ambiental será executada nesta tarefa. Depois da mudança
repository-local, o volume DEV continuará pendente de execução humana autorizada
do runbook aplicável.

## Critérios de aceite

- realms DEV novos provisionam somente `djmarcellopedrosa@gmail.com` como Super
  Admin humano canônico;
- a reconciliação de volume persistido é idempotente e falha fechado em conflito;
- roles, MFA, AMR, required actions e ausência de `tenant_id` permanecem
  inalterados;
- mocks, testes e documentação vigente apontam para a nova identidade;
- a migration Flyway histórica permanece byte a byte estável;
- validadores Keycloak, testes focalizados e gate documental passam;
- nenhuma stack, volume, realm remoto ou conta real é alterada.

## Evidências

- `bash -n` nos scripts Keycloak alterados e nos testes shell: PASS;
- `jq empty historical: infra/keycloak/dev/saas-admin-realm.json`: PASS;
- `bash infra/scripts/tests/keycloak-super-admin-identity-test.sh`: PASS para
  migração, verificação, idempotência, conflito, papel ausente e escopo DEV;
- `bash infra/scripts/tests/keycloak-bootstrap-hardening-test.sh`: PASS;
- `bash infra/scripts/tests/keycloak-admin-login-mfa-toggle-test.sh`: PASS;
- `bash infra/scripts/tests/keycloak-billing-mfa-amr-test.sh`: PASS;
- `bash infra/keycloak/bootstrap/validate-realm-token-contracts.sh`: PASS;
- `bash infra/scripts/tests/start-dev-bot-outbound-keyring-test.sh`: PASS sem
  saída de erro;
- frontend focalizado: 2 arquivos e 14 testes PASS, com ESLint e Prettier PASS;
- frontend integral: 190 arquivos e 1.184 testes PASS; avisos React/a11y
  preexistentes não causaram falha;
- `./infra/scripts/validate-docs.sh`: PASS para 741 Markdown, 30 diretórios e
  722 artefatos indexados, além da estrutura documental;
- `docker compose ... config --quiet`: não executado até o fim porque o Docker
  empacotado por Snap não possui `cap_dac_override`; nenhum container foi
  iniciado;
- `shellcheck`: SKIP porque o binário não está instalado;
- reconciliação do volume DEV e novo login/token: NOT EXECUTED, dependentes de
  execução humana autorizada.

A busca final preserva o endereço anterior somente na descrição desta transição
e em `V21__seed_bpfarias_admin_user.sql`. A migration Flyway é histórica,
imutável e não representa a conta administrativa atual; alterá-la quebraria o
checksum em bancos que já a aplicaram.

## Change log

| Version | Date | Author | Changes |
| --- | --- | --- | --- |
| 1.1 | 2026-09-07 | Codex | Conclui export, reconciliação idempotente, contratos, mocks, testes e documentação com gates repository-local verdes; preserva migration Flyway e explicita pendência ambiental. |
| 1.0 | 2026-09-07 | Solicitante humano / Codex | Autoriza e delimita a troca transversal da identidade Super Admin DEV antes das edições de software. |
