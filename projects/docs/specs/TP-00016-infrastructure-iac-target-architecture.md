---
document_id: "TP-00016"
primary_nature: "Plano"
objective: "Coordenar a Etapa 2 de arquitetura-alvo IaC segura, transformando o diagnóstico AS-IS e o risco de cibersegurança em uma decisão revisável antes de qualquer piloto ou operação."
scope: "Fronteiras de ownership, critérios de ferramenta, state, locking, secrets, IAM, brownfield, ambientes, pipeline, drift, recovery e layout futuro dentro de infra/."
non_objectives: "Corrigir gaps; criar infra/iac/; instalar ferramentas; escrever HCL/playbooks; executar init, plan, apply, import, deploy ou drift; acessar ambientes, providers, dados ou secrets."
owner: "Arquitetura e DevOps, com revisão de Segurança, Dados e Qualidade e decisão final do Maintainer Humano de Infraestrutura"
status: "Completed"
date: "2026-08-23"
version: "1.1"
keywords: "infraestrutura, IaC, arquitetura-alvo, OpenTofu, Terraform, state, secrets, brownfield, revisão-humana"
related_files: "../../backend/docs/adrs/ADR-0031-governanca-topologia-infraestrutura.md, ../../backend/docs/adrs/ADR-0033-arquitetura-alvo-iac-segura.md, docs/analysis/ANL-00042-infrastructure-as-is-iac-gap-analysis.md, docs/analysis/ANL-00043-infrastructure-iac-options-security-analysis.md, TP-00015-infrastructure-as-is-gap-analysis.md, docs/delivery/reports/RPT-0004-frontend-backend-cibersecurity.md, TP-00006-frontend-backend-cibersecurity-implementation-plan.md, docs/architecture/module-registry.md, infra/README.md"
code_references: "infra/, docker-compose.yml, docker-compose.override.yml, docker-compose.hml.yml, docker-compose.prd.yml, .github/workflows/, backend/src/main/java/br/com/duoset/saas_service/contexts/tenant/"
principal_statement: "A Etapa 2 concluiu e obteve aceite humano para uma arquitetura IaC segura e incremental; a decisão não autoriza criação de configuração, adoção brownfield, piloto nem efeito externo."
last_reviewed: 2026-08-23
---

# TP-00016 — Arquitetura-alvo segura de infraestrutura como código

## 1. Overview

Este plano abre a etapa posterior ao Gate 1. A
[ANL-00042](../../analysis/ANL-00042-infrastructure-as-is-iac-gap-analysis.md)
demonstrou que o repositório possui configuração e automação como código, mas não
desired state completo da fundação externa. O Maintainer Humano aprovou `G1.6` e
`G1.7` em 2026-08-23 e solicitou o avanço com base na revisão do relatório de
cibersegurança.

A entrega desta etapa é uma decisão arquitetural aceita, não um piloto. A
[ANL-00043](../../analysis/ANL-00043-infrastructure-iac-options-security-analysis.md)
preserva critérios, opções e evidências atuais; o
[ADR-0033](../../backend/docs/adrs/ADR-0033-arquitetura-alvo-iac-segura.md) foi aceito pelo
Maintainer Humano no Gate 2 em 2026-08-23.

## 2. Fontes, interpretação e lifecycle

- [ADR-0031](../../backend/docs/adrs/ADR-0031-governanca-topologia-infraestrutura.md) preserva
  `infra/` como umbrella e exige uma decisão sucessora antes de layout ou tooling.
- [ANL-00042](../../analysis/ANL-00042-infrastructure-as-is-iac-gap-analysis.md) é o
  baseline `Current` do repositório, com estado externo classificado como não
  verificado.
- [RPT-0004](../reports/RPT-0004-frontend-backend-cibersecurity.md) e
  [TP-00006](TP-00006-frontend-backend-cibersecurity-implementation-plan.md) são
  evidência histórica/declarada, não certificação do estado atual de HML, PRD ou
  providers.
- [Visão do produto](../../product/business/product-vision.md) fornece o contexto do SaaS; a
  etapa corrente corresponde à Phase 2, Architecture Decision, do
  [lifecycle](../../agents/standards/software-engineering-lifecycle.md).

Requisito de implementação, análise de aderência, caso de uso e Implementation
Plan ainda são `N/A`: nenhuma configuração ou operação será implementada nesta
etapa. Depois do aceite do ADR, qualquer piloto deve reiniciar as fases aplicáveis
do lifecycle e possuir autorização humana separada.

## 3. Interpretação de segurança obrigatória

O snapshot RPT-0004 declara correções no repositório para `SEC-001` a `SEC-024`,
mas mantém risco residual alto até ações externas como rotação de credenciais,
saneamento do histórico Git, rollout Keycloak/TLS, restore drill e pentest. Assim:

1. o Gate 1 pode ser aprovado como diagnóstico completo;
2. a aprovação não declara produção pronta nem encerra achados de segurança;
3. controles externos continuam `E — External/unverified`;
4. a Etapa 2 deve tratar secrets, segregation of duties, recovery e HML como
   restrições de arquitetura, não como pendências opcionais;
5. nenhum piloto operacional avança enquanto seus pré-requisitos P0/P1 não
   possuírem owner, evidência e aceite próprios.

## 4. Owners e autoridade

| Papel | Responsabilidade no Gate 2 |
| --- | --- |
| Arquitetura | Consolidar fronteiras, alternativas, consequências e ADR. |
| DevOps | Validar operabilidade, pipeline, drift, state e recovery. |
| Segurança | Revisar IAM, rede, TLS, secrets, supply chain e segregation of duties. |
| Dados | Revisar state, bancos, volumes, backup, restore e proteção contra destruição. |
| Qualidade | Validar rastreabilidade, critérios de piloto e checks reproduzíveis. |
| Maintainer Humano de Infraestrutura | Aceitar/rejeitar a decisão e, separadamente, autorizar eventual piloto. |
| Agentes de IA | Analisar e propor; não aprovar o Gate 2 nem executar efeito externo. |

## 5. Execution Tracking Matrix

> Legenda: `Pending` · `In Progress` · `Done` · `Blocked` · `Cancelled`.

| ID | Atividade | Owner | Status | Decisão/evidência |
| --- | --- | --- | --- | --- |
| `G2.0` | Confirmar Gate 1, baseline e risco residual | Arquitetura / Segurança | Done | TP-00015 concluído; ANL-00042 `Current`; Section 3 deste plano. |
| `G2.1` | Converter gaps e cibersegurança em critérios de decisão | Segurança / DevOps / Dados | Done | Sections 3 e 12 da ANL-00043; nenhum controle externo é alegado como concluído. |
| `G2.2` | Propor matriz de ownership plataforma versus tenant | Arquitetura / Dados / Segurança | Done | ANL-00043 Section 4 e ADR-0033 Section 2.1 excluem provisioning tenant do primeiro escopo IaC. |
| `G2.3` | Comparar ferramentas e modelos com fontes oficiais atuais | Arquitetura / DevOps / Segurança | Done | OpenTofu preferencial condicional, Terraform fallback e Ansible adiado na ANL-00043 Sections 5–6. |
| `G2.4` | Propor layout, state, brownfield, ambientes, pipeline e drift | Arquitetura / DevOps | Done | ADR-0033 Sections 2.1–2.7 e ANL-00043 Sections 7–11. |
| `G2.5` | Publicar ADR-0033 como `Proposed` e validar documentação | Arquitetura / Qualidade | Done | ADR e índices publicados; gates documentais passaram; nenhuma `infra/iac/` ou configuração executável foi criada. |
| `G2.6` | Revisar decisão por DevOps, Segurança, Dados, Arquitetura e Qualidade | Owners humanos | Done | O Maintainer Humano registrou o aceite consolidado de `G2.6` em 2026-08-23. |
| `G2.7` | Aprovar/rejeitar Gate 2 e decidir se haverá piloto | Maintainer Humano | Done | O Maintainer Humano aceitou `G2.7` e o ADR-0033 em 2026-08-23; este aceite encerra a decisão arquitetural e não inicia piloto, que permanece sujeito a escopo, plano e autorização operacional separados. |

## 6. Critérios mínimos da decisão

- Matriz explícita de recurso, owner, source of truth, state e fronteira.
- Bancos, migrations, datasources e realms dinâmicos de tenant permanecem sob o
  runtime até ADR específica justificar mudança de ownership.
- State IaC é separado de `.deploy/state`, remoto, criptografado, versionado,
  bloqueável, auditável e recuperável.
- Secrets são referenciados; valores não entram em Git, HCL, outputs, planos ou
  state quando o provider permitir evitá-los.
- Brownfield segue `inventariar → importar/adotar → obter plano sem mudança →
  proteger contra recreate`, nunca adoção automática.
- HML fornece capacidade de validação pré-PRD para TLS, IAM/Keycloak, DAST,
  restore e alertas; sua forma operacional ainda deve ser decidida.
- Fluxo distingue `preview`, revisão e `apply`; apply e break-glass exigem pessoa,
  identidade e evidência explícitas; drift não é autocorrigido em PRD.
- Dependências, providers e actions são pinados; provenance e scans permanecem
  gates da supply chain.
- O piloto futuro é pequeno, reversível, isolado, sem dados reais e sem acesso
  implícito a produção.

## 7. Guardrails

1. Não criar `infra/iac/`, módulos, HCL, playbooks, workflow IaC ou backend de
   state nesta etapa.
2. Não instalar OpenTofu, Terraform, Ansible ou providers.
3. Não executar `init`, `validate`, `plan`, `apply`, `import`, `destroy`, drift,
   bootstrap, deploy, backup ou restore.
4. Não consultar nem alterar Hostinger, DNS, GitHub, AWS, Keycloak, HML ou PRD.
5. Não ler ou registrar secrets, states, planos salvos, `.env`, `.deploy/`,
   `.dev-secrets/`, chaves, dumps ou backups reais.
6. Não corrigir gaps P0/P1 de forma escondida; cada correção recebe fonte,
   plano, testes e gate próprios.
7. Pesquisa técnica atual usa somente fontes oficiais/primárias e registra data e
   limitação.

## 8. Verificação planejada

| Verificação | Objetivo | Estado |
| --- | --- | --- |
| `./infra/scripts/validate-docs.sh` | Validar contrato, IDs, índices e links. | Passed: `Documentation structure validation passed.` |
| `git diff --check` | Detectar patch documental malformado. | Passed. |
| Resolução focal de links | Confirmar ADR, TP, análises, relatório e entrypoints. | Passed: todos os alvos focais existem. |
| Nova execução efêmera do Codex em `infra/`, read-only | Confirmar descoberta da Etapa 2 e seus limites. | Passed antes do Gate 2: identificou ADR-0033 então `Proposed`, TP-00016, ANL-00043, OpenTofu não aprovado e operações proibidas; nenhum arquivo/ambiente foi alterado. |
| Revisões `G2.6`–`G2.7` | Confirmar arquitetura e preservar autorização separada de piloto. | Passed: aceite humano registrado em 2026-08-23; nenhum piloto autorizado por este gate. |

Não há teste de software, Compose ou ferramenta IaC aplicável: somente documentos
e entrypoints serão alterados.

## 9. Handoff concluído

O handoff aceito pelo Maintainer Humano registra:

- riscos residuais preservados e prioridades P0/P1;
- matriz de ownership aceita como arquitetura-alvo;
- comparação de opções e recomendação condicional;
- ADR-0033 em estado `Accepted`;
- itens ainda não decididos ou não verificados;
- evidências documentais, sem alegação de ambiente.

O Gate 2 aceitou a decisão e a preferência condicional por OpenTofu, mantendo
Terraform como fallback e Ansible adiado. O aceite não autoriza automaticamente
piloto, instalação, importação ou apply; esses efeitos exigem escopo, plano e
aprovação explícitos posteriores.

## 10. Change Log

| Version | Date | Owner | Change |
| --- | --- | --- | --- |
| 1.1 | 2026-08-23 | Maintainer Humano / Arquitetura | Registra `G2.6` e `G2.7` como aceitos, conclui a Etapa 2 e preserva autorização separada para qualquer piloto ou efeito externo. |
| 1.0 | 2026-08-23 | Arquitetura / DevOps / Segurança | Abre a Etapa 2 documental, materializa critérios, guardrails e Gate 2 incremental. |
