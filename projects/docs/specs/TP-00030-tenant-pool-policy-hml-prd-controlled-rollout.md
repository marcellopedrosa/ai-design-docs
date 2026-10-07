---
document_id: TP-00030
primary_nature: Plano
objective: Coordenar a especificacao, autorizacao separada e futura execucao controlada do rollout da politica de pool por tenant primeiro em HML e depois em PRD.
scope: Governanca documental, alocacao aprovada e plano Proposed do IP-INFRA HML, capacity proof, proposta de IP-INFRA PRD, PREPARE, coverage, canary, observabilidade, rollback, go/no-go e handoffs HML/PRD.
non_objectives: Aprovar ou iniciar IP-INFRA; alocar ou criar o IP-INFRA PRD; editar codigo, Compose, workflow ou infra; acessar ambiente, tenant, dado ou segredo real; executar deploy, comando externo ou ativacao; inferir sizing, thresholds ou janela.
owner: Engenharia, Arquitetura, SRE/DBA, DevOps, Seguranca, Dados e Qualidade
status: Completed
related_files: docs/product/requirements/REQ-00052-tenant-pool-policy-controlled-hml-prd-rollout.md, TP-00030-tenant-pool-policy-hml-prd-controlled-rollout.md
version: 1.1
date: 2026-09-01
last_reviewed: 2026-09-02
keywords: tenant, pool, hml, prd, rollout, ip-infra, canary, rollback
code_references: backend/src/main/resources/application-hml.yml, backend/src/main/resources/application-prd.yml, infra/
principal_statement: Este plano esta aprovado somente para coordenacao repository-local; HML precede PRD, o IP HML existe somente em Proposed e o IP PRD permanece nao alocado, sem qualquer efeito ambiental.
---

# TP-00030 — Rollout controlado da politica de pool por tenant em HML e PRD

## 1. Contexto e estado de autoridade

O [REQ-00052](../../product/requirements/REQ-00052-tenant-pool-policy-controlled-hml-prd-rollout.md)
foi aprovado em 2026-09-02 como quinto componente operacional do ADR-0052. Este
Task Plan foi aprovado na mesma decisao somente para coordenacao repository-local
e persiste a sequencia e as dependencias antes de qualquer efeito externo.

Estado atual:

- `TP-00030`: `Approved`;
- `REQ-00052`: `Approved` v1.1;
- ADR-0052: `Accepted` v1.12, com autoridade repository-local limitada;
- IP-INFRA HML: alocacao aprovada; arquivo criado em `Proposed`;
- IP-INFRA PRD: somente ID/path propostos, nao alocados;
- HML e PRD: permanecem `DARK`, sem acesso, sizing, deploy ou ativacao.

A unica alocacao aprovada e a do IP HML, registrada no REQ-00052. Nenhuma
mencao deste plano constitui aprovacao, inicio ou conclusao de IP-INFRA.

## 2. Estrategia selecionada

1. preservar os recortes repository-local do TP-00029 e do
   IP-BE-23.4.3-tenant-pool-policy-managed-runtime-environments;
2. preservar a fonte normativa operacional aprovada e seu limite repository-local;
3. separar HML e PRD porque ambiente, risco, capacidade e ciclo de autorizacao
   evoluem independentemente;
4. provar HML integralmente antes de permitir qualquer gate de inicio PRD;
5. medir capacidade por ambiente, sem copiar budget DEV/HML;
6. promover cada ambiente por `DARK -> PREPARE -> ACTIVE`;
7. usar canary, observabilidade e go/no-go humano antes de ampliar efeito;
8. preservar `ACTIVE -> DRAIN_ONLY -> DARK` como kill switch;
9. manter cache `OFF` no primeiro rollout;
10. registrar evidencia sanitizada e bloquear promocao diante de falha, skip ou
    pendencia humana.

## 3. IDs, paths e estado de alocacao

| Ambiente | Document ID proposto | Path proposto | Estado |
| --- | --- | --- | --- |
| HML | `IP-INFRA-23.5.1-tenant-pool-policy-managed-hml-activation` | [IP-INFRA-23.5.1](IP-INFRA-23.5.1-tenant-pool-policy-managed-hml-activation.md) | `ALLOCATED / PROPOSED` |
| PRD | `IP-INFRA-23.5.2-tenant-pool-policy-managed-prd-rollout` | `docs/delivery/plans/implementation_plans/infra/IP-INFRA-23.5.2-tenant-pool-policy-managed-prd-rollout.md` | `NOT_ALLOCATED` |

O arquivo HML existe somente em `Proposed`; isso nao permite aprova-lo, iniciar
trabalho ou produzir efeito. O arquivo PRD nao existe. Antes da alocacao PRD, o
Maintainer Humano de Infraestrutura ainda deve aprovar explicitamente ID/path,
objetivo, escopo, nao objetivos, alcadas, ambientes, tenants/dados proibidos,
comandos e validacoes. Cada plano percorre o lifecycle fail-closed sem saltos.

## 4. Work packages e gates

| # | Entrega | Dependencias | Gate humano | Estado |
| --- | --- | --- | --- | --- |
| WP-0 | REQ-00052 e TP-00030 criados/indexados como pre-autorizacao | documentacao vigente | revisao documental | Concluido |
| WP-1 | Decisao sobre revisao do ADR-0052 e aprovacao do REQ-00052/TP-00030 | WP-0 | Produto + Arquitetura + owners tecnicos | Concluido |
| WP-2 | Alocacao exata e criacao `Proposed` do IP-INFRA HML | WP-1 | Maintainer Humano de Infraestrutura | Concluido; arquivo criado e indexado em `Proposed` |
| WP-3 | Revisao e transicoes `Approved`/`In Progress` do IP HML | WP-2 e plano HML criado em `Proposed` | gates distintos da colecao IP-INFRA | Bloqueado |
| WP-4 | Capacity proof, PREPARE, canary, A/B, rollback, drain e go/no-go HML | WP-3 | SRE/DBA + DevOps + Seguranca + Dados + Qualidade | Bloqueado |
| WP-5 | Handoff terminal de HML e autorizacao para planejar PRD | WP-4 | Maintainer Humano + owners | Bloqueado |
| WP-6 | Alocacao exata do IP-INFRA PRD | WP-5 | Maintainer Humano de Infraestrutura | Bloqueado |
| WP-7 | Revisao e transicoes `Approved`/`In Progress` do IP PRD | WP-6 e plano PRD criado em `Proposed` | gates distintos da colecao IP-INFRA | Bloqueado |
| WP-8 | Capacity proof, deploy protegido, canary, rollback e go/no-go PRD | WP-7 | SRE/DBA + DevOps + Seguranca + Dados + Qualidade + reviewer de producao | Bloqueado |
| WP-9 | Handoff final e reconciliacao documental | WP-8 | owners das fontes e Maintainer Humano | Bloqueado |

## 5. Dependencias obrigatorias

- REQ-00052 v1.1 aprovado por autoridade humana apropriada;
- ADR-0052 v1.12 aceito com limite repository-local explicito;
- IP-INFRA separado para cada ambiente;
- adapter ambiental homologado ou decisao explicita de onde reside essa
  responsabilidade;
- inventario nao secreto da topologia e do mecanismo de deploy de HML/PRD;
- capacity proof medido e aprovado por SRE/DBA;
- revisao de Seguranca para rede, TLS, IAM, secrets, RBAC e auditoria;
- revisao de Dados para PostgreSQL, backup, restore e efeito stateful;
- runbooks separados de HML e PRD criados/indexados antes da operacao;
- janela, thresholds, tenant canario/controle e operadores identificados;
- testes e quality gates definidos pelo plano de cada ambiente.

Ausencia de qualquer dependencia mantem o work package correspondente bloqueado.

## 6. Capacity proof e configuracao

Cada IP futuro deve registrar, para seu ambiente, valores medidos/aprovados de:

- budget seguro PostgreSQL;
- maximo de replicas;
- pool da plataforma;
- teto de pool tenant;
- reserva de migration/admin;
- emergency headroom;
- committed e reservas retidas considerados;
- bounds ambientais dos parametros Hikari.

O calculo reutiliza a decisao atomica do REQ-00051. O ambiente falha fechado diante
de ausencia, overflow, divergencia de cluster/epoch/replicas, target acima do teto,
coverage incompleta ou tentativa de usar defaults DEV. A interface nao edita esses
valores.

## 7. Sequencia HML

1. aprovar e iniciar o IP HML pelos gates proprios;
2. concluir inventario e capacity proof sem expor segredo;
3. configurar autoridade e identidade exclusivas de HML;
4. entrar em `PREPARE`, renovar membership e completar coverage de 100%;
5. provar readiness sanitizada e committed/binding exatos;
6. executar telemetria/read na coorte sintetica;
7. executar canary de um tenant dedicado nao real com tenant controle;
8. provar alteracao A, isolamento B, rollback e drain;
9. observar pela janela/thresholds aprovados;
10. decidir go/no-go, registrar handoff e retornar a `DARK` diante de degradacao.

PRD continua bloqueado ate WP-5.

## 8. Sequencia PRD

1. exigir evidencia terminal e go/no-go de HML;
2. aprovar e iniciar o IP PRD pelos seus proprios gates;
3. repetir inventario/capacity proof sem herdar valores HML;
4. confirmar revisao aprovada, Environment protegido, reviewer e ausencia de
   auto-apply;
5. confirmar backup/restore e janela operacional exigidos pelo deploy vigente;
6. entrar em `PREPARE`, completar coverage e readiness;
7. executar canary e observacao aprovados antes de `ACTIVE`;
8. limitar a primeira mutacao ao tenant canario autorizado;
9. decidir go/no-go separado para ampliar o uso;
10. preservar kill switch, rollback por revisao e handoff sanitizado.

## 9. Canary, observabilidade e stop conditions

Os futuros IPs e runbooks devem definir thresholds numericos, janela e responsavel
por decidir. No minimo, observar:

- saturacao, aquisicao e timeout de conexoes;
- erro de candidate/probe/commit/swap/reconcile;
- drift de revisao e autoridade;
- heartbeat, fencing, readiness e runtimes esperados;
- drain prolongado e reserva retida;
- rejeicao por capacidade e headroom restante;
- disponibilidade da API administrativa e auditoria.

Qualquer threshold excedido, readiness `DOWN`, authority stale, isolamento A/B
inconclusivo, drain preso, ausencia de audit ou gate humano pendente e stop
condition. Nao existe promocao automatica por decurso de tempo.

## 10. Rollback e kill switch

- rollback funcional cria nova revisao do tenant;
- bloquear mutacoes/candidates antes de desligar o runtime;
- completar commit/swap/drain ja persistidos quando seguro;
- seguir `ACTIVE -> DRAIN_ONLY -> DARK`;
- nunca force-close conexao/transacao em voo;
- preservar store, revisoes, heads, intents, reservations, applications e audit;
- tratar rollback de aplicacao como revisao forward compatível com migrations;
- nao restaurar banco como rollback automatico de release.

## 11. Documentos operacionais futuros

Depois dos respectivos gates de plano, criar e indexar:

- `docs/onboarding/tenant-pool-policy-managed-hml-rollout-runbook.md`;
- `docs/onboarding/tenant-pool-policy-managed-prd-rollout-runbook.md`.

Os runbooks devem conter comandos exatos, precondicoes, owners, evidencias,
stop conditions e recuperacao do ambiente correspondente. Esta pre-autorizacao
nao cria nem aprova esses procedimentos.

## 12. Validacao documental desta etapa

Depois da criacao/indexacao, o agente principal deve executar:

```bash
./infra/scripts/validate-docs.sh
```

Como o plano HML foi alocado e criado, os validadores `IP-INFRA` sao obrigatorios
nesta etapa. A validacao nao executa deploy, rede, provider ou ambiente.

## 13. Definition of Done desta etapa

Esta etapa documental esta `Approved`, com WP-0, WP-1 e WP-2 concluidos e o
arquivo HML exato criado em `Proposed`. Continuam pendentes:

- revisar o conteudo do IP HML criado;
- obter gate humano distinto para promove-lo a `Approved`;
- obter outro gate distinto para inicia-lo em `In Progress`;
- manter o IP PRD nao alocado ate a evidencia terminal de HML.

Conclusao deste documento nao equivale a conclusao de HML ou PRD. Nenhuma etapa
operacional pode iniciar enquanto o IP do ambiente nao estiver validamente em
`In Progress`.

## 14. Change Log

| Version | Date | Author | Changes |
| --- | --- | --- | --- |
| 1.1 | 2026-09-02 | Owner humano / Codex (OpenAI) | Promove o TP a `Approved`, conclui WP-0/WP-1/WP-2 e registra o IP HML alocado, criado e indexado somente em `Proposed`; todos os demais WPs e o IP PRD permanecem bloqueados. |
| 1.0 | 2026-09-01 | Codex (OpenAI), sob solicitacao humana de documentacao previa | Cria o plano Proposed, separa HML de PRD e registra dois IDs/paths IP-INFRA apenas como propostas nao alocadas. |
