---
document_id: TP-00028
primary_nature: Plano
objective: Tornar reproduzivel a ativacao manual local da politica de pool por tenant para teste pela interface ja implementada.
scope: Launcher local opt-in, fixtures sinteticas A/B, bancos dedicados sinteticos, profile dev+tenant-pool-smoke, renovacao curta, status, cleanup e retorno ao DARK.
non_objectives: Alterar o default DARK, usar tenant ou dado real, habilitar ambiente compartilhado, HML, PRD ou producao, executar deploy, mudar contrato HTTP ou criar UI.
owner: Engenharia, Backend e Qualidade
status: In Progress
version: 1.1
date: 2026-09-01
last_reviewed: 2026-09-01
keywords: tenant, pool, local-smoke, launcher, super-admin, ui, docker
related_files: ../../backend/docs/adrs/ADR-0052-parametros-pool-conexao-por-tenant.md, do../../product/requirements/REQ-00049-tenant-pool-policy-authorized-test-rollout.md, do../../product/use-cases/UC-00046-super-admin-tenant-pool-policy-management.md, TP-00027-tenant-pool-policy-authorized-test-rollout.md, ../../backend/docs/specs/IP-BE-23.4.2-tenant-pool-policy-local-ui-activation.md, ../../backend/docs/onboarding/tenant-pool-policy-authorized-test-rollout-runbook.md
code_references: backend/scripts/tenant-pool-smoke-local.sh, backend/scripts/tenant-pool-smoke/, docker-compose.yml, docker-compose.override.yml, frontend/e2e/tenant/tenant-pool-policy.backend-real.spec.ts
principal_statement: A capability pode ser testada manualmente somente por um launcher local fail-closed que materializa A/B sinteticos, inicia o backend com o profile autorizado por uma lease curta e remove integralmente a fixture ao retornar ao DARK.
---

# TP-00028 — Ativacao local da UI de politica de pool por tenant

## 1. Contexto e autorizacao

O ADR-0052, o REQ-00049 e o UC-00046 ja especificam a capability, o profile
`tenant-pool-smoke`, a coorte A/B e o fluxo do Super Admin. A instrucao humana de
2026-09-01 autoriza ativar a funcionalidade para teste local. Este plano fecha
somente a lacuna operacional entre os testes automatizados aprovados e uma sessao
manual reproduzivel na aplicacao.

## 2. Escopo de seguranca

- preservar `application.yml` e o Compose normal em `DARK`;
- usar UUIDs, documentos, e-mails, slugs, cluster e runtime reservados e sinteticos;
- criar exclusivamente `saas_pool_smoke_a` e `saas_pool_smoke_b`;
- aceitar somente capacidade `80/10/5/15/1` e teto tenant `10`;
- limitar cada lease a menos de dez minutos, com renovacao explicita por restart;
- nunca ler ou imprimir arquivos de segredo; o Compose continua sendo seu owner;
- `stop` valida marcadores antes de remover dados/bancos e reinicia o backend DARK.

## 3. Plano de execucao

| # | Atividade | Estado | Evidencia esperada |
| --- | --- | :---: | --- |
| 1 | Persistir TP/IP antes do software | Concluida | documentos indexados |
| 2 | Implementar fixtures e launcher `start/renew/status/stop` | Concluida | scripts fail-closed |
| 3 | Criar testes hermeticos do launcher | Concluida | contrato `PASS` |
| 4 | Validar documentos e testes focais | Concluida | 679 Markdown/659 indexados; estrutura `PASS` |
| 5 | Ativar a sessao local e verificar health | Bloqueada no agente | daemon exige senha `sudo` interativa; comando entregue ao operador |
| 6 | Entregar rota da tela, janela da lease e rollback | Pendente | handoff reproduzivel |

## 4. Criterios de aceite

1. `start` faz bootstrap DARK/migrations, para o backend, cria somente os dois
   bancos marcados, aplica a fixture exata e inicia `dev,tenant-pool-smoke`.
2. A fixture materializa policies completas, heads, capacidade e membership com
   os mesmos valores fornecidos ao guard de startup.
3. `renew` atualiza a lease e reinicia apenas o backend smoke; não altera policy.
4. `status` não revela segredo e informa container, health, profile e deadline.
5. `stop` recusa alvos sem marcador, remove apenas a fixture reservada, derruba o
   backend smoke e restaura o backend normal em `DARK`.
6. Super Admin global, sem impersonacao, acessa `Principal > Escritorios >
   tenant A > Pool de conexoes` e pode consultar/alterar A; B permanece read-only.
7. Nenhum arquivo de Compose, infraestrutura externa, deploy ou producao muda.

## 5. Validacao

```bash
bash -n backend/scripts/tenant-pool-smoke-local.sh
bash backend/scripts/tests/tenant-pool-smoke-local-test.sh
./infra/scripts/validate-docs.sh
```

O smoke vivo usa Docker local e deve registrar separadamente startup, health e
eventuais bloqueios ambientais. Nenhuma falha ou skip e convertido em aceite.

## 6. Rollback

Executar `backend/scripts/tenant-pool-smoke-local.sh stop`. O comando deve parar e
remover o container opt-in, limpar apenas registros sinteticos reconhecidos,
remover somente bancos com o comentario marcador esperado e subir o backend
normal. Em qualquer divergencia de identidade, parar sem remover o alvo.

## 7. Change Log

| Version | Date | Author | Changes |
| --- | --- | --- | --- |
| 1.1 | 2026-09-01 | Codex (OpenAI) | Implementa e valida o harness; registra ativação viva pendente exclusivamente da sessão root interativa do operador. |
| 1.0 | 2026-09-01 | Codex (OpenAI), sob autorizacao humana explicita | Cria o plano complementar para ativacao manual exclusivamente local. |
