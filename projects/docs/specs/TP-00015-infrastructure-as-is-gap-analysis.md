---
document_id: "TP-00015"
primary_nature: "Plano"
objective: "Coordenar a Etapa 1 de inventário AS-IS e análise de gaps de infraestrutura/IaC com evidência de repositório e revisão humana incremental."
scope: "infra/, Compose e Dockerfiles da raiz, workflows, runbooks e provisioning executado pelo runtime que integrem a topologia operacional versionada."
non_objectives: "Inspecionar ambientes ou secrets; escolher ferramenta ou arquitetura IaC alvo; criar diretórios; alterar configuração; executar Compose, scripts, deploy, provisionamento, backup, restore ou provider."
owner: "Arquitetura e DevOps, com decisão final do Maintainer Humano de Infraestrutura"
status: "Completed"
date: "2026-08-23"
version: "1.1"
keywords: "infraestrutura, AS-IS, gap, IaC, inventário, evidência, revisão-humana"
related_files: "../../backend/docs/adrs/ADR-0031-governanca-topologia-infraestrutura.md, ../../backend/docs/adrs/ADR-0016-infrastructure-environment-provisioning.md, docs/analysis/ANL-00042-infrastructure-as-is-iac-gap-analysis.md, TP-00014-infrastructure-governance-stage-zero.md, TP-00016-infrastructure-iac-target-architecture.md, docs/delivery/reports/RPT-0004-frontend-backend-cibersecurity.md, TP-00006-frontend-backend-cibersecurity-implementation-plan.md, docs/architecture/module-registry.md, infra/README.md"
code_references: "infra/, docker-compose.yml, docker-compose.override.yml, docker-compose.hml.yml, docker-compose.prd.yml, .github/workflows/, backend/src/main/java/br/com/duoset/saas_service/contexts/tenant/, backend/src/main/java/br/com/duoset/saas_service/config/persistence/routing/"
principal_statement: "A Etapa 1 descreve somente o que o repositório prova, separa estado externo não verificado e entrega gaps e perguntas ao humano sem antecipar ferramenta, layout ou execução."
last_reviewed: 2026-08-23
---

# TP-00015 — Inventário AS-IS e gaps de infraestrutura/IaC

## 1. Overview

Este plano coordena a etapa posterior ao Gate 0. O resultado principal é a
[ANL-00042](../../analysis/ANL-00042-infrastructure-as-is-iac-gap-analysis.md), que
classifica a topologia operacional versionada e identifica gaps para uma decisão
futura de IaC.

O plano não transforma diagnóstico em arquitetura alvo. O Gate 1 foi aprovado
explicitamente pelo Maintainer Humano em 2026-08-23, depois da revisão do relatório
de cibersegurança, e a decisão seguinte foi aberta pelo
[TP-00016](TP-00016-infrastructure-iac-target-architecture.md).

## 2. Fontes e aplicabilidade do lifecycle

- [ADR-0031](../../backend/docs/adrs/ADR-0031-governanca-topologia-infraestrutura.md) autoriza o
  inventário read-only e mantém o freeze operacional.
- [ADR-0016](../../backend/docs/adrs/ADR-0016-infrastructure-environment-provisioning.md) é fonte
  histórica parcialmente superseded e deve ser confrontada com executáveis e
  runbooks vigentes.
- [Catálogo de `infra/`](../../../infra/README.md) e
  [manifesto](../../architecture/module-registry.md) delimitam a descoberta.
- A solicitação humana de 2026-08-23, após aprovar o Gate 0, autoriza avançar para
  esta etapa documental.

Business Context, requisito, análise de aderência a requisito, caso de uso e
Implementation Plan são `N/A`: a Etapa 1 é diagnóstico documental/read-only, não
introduz comportamento de produto nem altera configuração ou ambiente. Qualquer
mudança executável descoberta interrompe este fluxo e exige lifecycle e plano
próprios.

## 3. Modelo de evidência

| Nível | Significado | Uso permitido |
| --- | --- | --- |
| `O — Observed in repository` | Arquivo, referência ou ausência verificada no snapshot do repositório. | Sustenta descrição AS-IS versionada. |
| `V — Validated locally` | Comando seguro e read-only confirmou uma propriedade. | Sustenta somente a propriedade testada. |
| `D — Declared only` | Runbook ou ADR declara comportamento não exercitado nesta etapa. | Deve permanecer identificado como declaração. |
| `E — External/unverified` | Depende de host, provider, GitHub, volume, secret ou dado externo não consultado. | Não permite afirmar existência, saúde ou drift real. |

Inferência deve ser rotulada e nunca promovida a fato externo. A baseline temporal
e suas limitações ficam registradas na análise.

## 4. Owners e revisões

| Papel | Responsabilidade no Gate 1 |
| --- | --- |
| DevOps | Validar completude do catálogo, callers, ambientes e automações. |
| Arquitetura | Validar precedência, fronteiras e separação AS-IS versus target. |
| Segurança | Revisar classificação de IAM, rede, TLS, SSH e secrets sem acessar material secreto. |
| Dados | Revisar bancos, volumes, state, backup, restore e provisioning tenant. |
| Maintainer Humano de Infraestrutura | Priorizar perguntas e aprovar ou devolver o Gate 1. |
| Agentes de IA | Coletar evidência read-only, produzir o diagnóstico e não aprovar gates. |

## 5. Execution Tracking Matrix

> Legenda: `Pending` · `In Progress` · `Done` · `Blocked` · `Cancelled`.

| ID | Atividade | Owner | Status | Decisão/evidência |
| --- | --- | --- | --- | --- |
| `G1.0` | Confirmar Gate 0 e decisão canônica | Arquitetura | Done | TP-00014 concluído e ADR-0031 `Accepted`. |
| `G1.1` | Congelar baseline, escopo e níveis de evidência | Arquitetura / DevOps | Done | Sections 2–3 e baseline da ANL-00042. |
| `G1.2` | Inventariar superfícies e callers versionados | DevOps | Done | Sections 3–6 da ANL-00042. |
| `G1.3` | Mapear ownership, state, secrets e fronteiras externas | DevOps / Segurança / Dados | Done | Sections 7–8 da ANL-00042; revisão humana consolidada em `G1.6`. |
| `G1.4` | Priorizar gaps e perguntas para decisão futura | Arquitetura | Done | Sections 9–11 da ANL-00042. |
| `G1.5` | Executar gates documentais e focados | Qualidade | Done | Evidências na Section 8 deste plano. |
| `G1.6` | Revisar completude por DevOps, Segurança, Dados e Arquitetura | Owners humanos | Done | Revisão consolidada aceita pelo Maintainer Humano em 2026-08-23, apoiada por ANL-00042 e pela leitura histórica do RPT-0004/TP-00006; controles externos permanecem não verificados. |
| `G1.7` | Aprovar Gate 1 e prioridades da Etapa 2 | Maintainer Humano | Done | Solicitação explícita do Maintainer em 2026-08-23 aprova o diagnóstico e a repriorização de segurança; não aprova produção, piloto ou Gate 2. |

## 6. Guardrails

1. Não ler `.env`, `.deploy/`, `.dev-secrets/`, chaves, dumps ou backups reais.
2. Não consultar HML, produção, Hostinger, DNS, GitHub, AWS/S3/KMS, Keycloak ou
   qualquer provider externo.
3. Não executar Compose, scripts, workflows, deploy, backup, restore, bootstrap,
   `plan`, `apply` ou comandos de infraestrutura.
4. Não criar `iac/`, reorganizar `infra/` ou escolher ferramenta/state.
5. Não corrigir gaps detectados dentro deste plano; cada correção requer triagem e
   artefatos próprios.
6. Preservar fatos, declarações, inferências e estado externo como categorias
   distintas.

## 7. Critérios de aceite do Gate 1

- A ANL-00042 possui baseline, método e limitações reproduzíveis.
- Superfícies dentro e fora de `infra/` estão representadas por capacidade,
  ambiente, natureza, owner, state e fonte de verdade.
- Provisionamento de plataforma e provisioning tenant pelo runtime estão
  explicitamente separados.
- Gaps de cobertura, state/drift, secrets, CI/CD, observabilidade, backup e
  documentação possuem evidência e prioridade, sem solução antecipada.
- Estado real de ambiente não é inferido do repositório.
- Owners humanos revisam suas fronteiras e o Maintainer registra `Approved` ou
  solicita ajustes.

## 8. Verificação e evidência

| Verificação | Objetivo | Resultado |
| --- | --- | --- |
| `./infra/scripts/validate-docs.sh` | Validar contratos, IDs, índices e links. | Passed: `Documentation structure validation passed.` |
| `git diff --check` e whitespace/newline focados | Detectar patch documental malformado. | Passed. |
| Contagem e busca read-only de superfícies versionadas | Tornar o inventário reproduzível. | Passed: `67` arquivos em `infra/`, `10` Compose, `3` Dockerfiles e `2` workflows; buscas de IaC e `CODEOWNERS` registradas na ANL-00042. |
| Resolução de links relativos | Confirmar rotas entre ADR, TP, análise, manifesto e catálogo. | Passed. |
| Nova execução efêmera do Codex em `infra/`, sandbox read-only | Confirmar instrução raiz → local e descoberta da Etapa 1. | Passed: identificou ADR-0031, TP-00015, ANL-00042 e os limites de autorização. |
| Revisões humanas `G1.6` e `G1.7` | Validar diagnóstico e prioridades. | Passed: aprovação humana explícita registrada em 2026-08-23, com ressalvas de segurança preservadas na ANL-00042 e no TP-00016. |

Não há teste de software ou Compose aplicável. Nenhum executável foi alterado e
nenhum comportamento de ambiente é alegado.

## 9. Handoff entregue para a Etapa 2

O Gate 1 entregou perguntas, não respostas pré-aprovadas, sobre:

- recursos que entrarão no escopo de IaC e fronteira com provisioning runtime;
- provider, modelo de módulos e paridade entre ambientes;
- state, locking, drift, importação brownfield e recuperação;
- secrets e referências seguras entre IaC, GitHub e runtime;
- fluxo de preview/review/apply e segregation of duties;
- estrutura futura dentro de `infra/` e migração de consumers.

O RPT-0004 foi tratado como snapshot histórico: suas correções declaradas no
repositório não comprovam HML/PRD, providers, rotação, TLS, restore ou pentest. A
aprovação do Gate 1 mantém esse risco residual e o transfere como restrição para o
[TP-00016](TP-00016-infrastructure-iac-target-architecture.md), sem reclassificá-lo
como resolvido.

## 10. Change Log

| Version | Date | Owner | Change |
| --- | --- | --- | --- |
| 1.1 | 2026-08-23 | Maintainer Humano / Arquitetura / DevOps / Segurança | Registra G1.6 e G1.7 aprovados, preserva o risco residual do RPT-0004, conclui a Etapa 1 e abre o TP-00016. |
| 1.0 | 2026-08-23 | Arquitetura e DevOps | Abre a Etapa 1, define evidência, owners, guardrails, gates e handoff para decisão IaC futura. |
