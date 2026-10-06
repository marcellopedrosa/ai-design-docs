---
document_id: PRD-00003
primary_nature: Requisito
objective: Definir a intenção, os resultados e o gate de validação da Plataforma Tenant.
scope: Onboarding, provisionamento, isolamento, lifecycle, usuários, limites e operação de recursos por tenant.
non_objectives: Repetir acceptance criteria, detalhar fluxos, decidir arquitetura multitenant, definir oferta comercial, validar valor fiscal, autori
ar rollout ambiental ou afirmar validação inexistente.
owner: Produto Plataforma Tenant e Operações
status: Validated
version: 1.14
date: 2026-09-10
last_reviewed: 2026-09-13
keywords: prd, tenant, onboarding, lifecycle, isolamento, provisionamento, usuarios, pool
related_files: docs/product/requirements/README.md, projects/backend/docs/prds/PRD-00004-fiscal-operations.md, docs/product/business/product-vision.md, docs/product/requirements/REQ-00031-phase2-tenant-lifecycle-and-access.md, docs/product/use-cases/UC-00028-phase2-tenant-lifecycle-and-user-management.md, docs/delivery/plans/implementation_plans/backend/IP-BE-2.1.3.1-tenant-onboarding-grant-compensation.md, docs/delivery/plans/implementation_plans/backend/IP-BE-2.1.5.1-tenant-standalone-module-gate.md
code_references: backend/src/main/java/br/com/duoset/saas_service/contexts/tenant/internal/application/TenantOnboardingUseCase.java, backend/src/test/java/br/com/duoset/saas_service/contexts/tenant/internal/application/TenantOnboardingUseCaseTest.java, backend/src/test/java/br/com/duoset/saas_service/contexts/tenant/TenantModuleTest.java, frontend/, infra/
principal_statement: O escritório assinante deve entrar em operação, administrar sua organização e evoluir com isolamento, previsibilidade e controle durante todo o ciclo de vida.
---

# PRD-00003 — Plataforma Tenant e Lifecycle

## 1. Executive summary

A visão do produto depende de uma fronteira organizacional confiável para cada
escritório. O acervo atual cobre criação, provisionamento, assinatura, usuários,
isolamento de dados e administração de recursos do tenant.

Este PRD organiza essas capacidades como uma experiência de plataforma, sem
transformar decisões técnicas de multitenancy em resultado de produto. Há requisitos
aprovados e implementações locais, mas as métricas baseadas em tempo, experiência ou
testes com clientes reais foram expurgadas por decisão do owner. Com as decisões
funcionais e as aprovações obrigatórias registradas, o documento está `Validated`.

## Problema e evidência

### Problem statement

Um escritório não consegue obter valor fiscal ou omnichannel se sua organização
não puder ser criada, isolada, configurada e administrada com segurança. Falhas ou
opacidade nesse lifecycle elevam o tempo de ativação, o suporte manual, o risco de
exposição entre clientes e a imprevisibilidade operacional.

### Evidence currently available

| Evidence | What it supports | Limitation |
| --- | --- | --- |
| [Visão do produto](../business/product-vision.md) | Multitenancy e isolamento são princípios centrais. | Não contém pesquisa, volume ou metas de ativação. |
| [REQ-00031](../requirements/REQ-00031-phase2-tenant-lifecycle-and-access.md) | Baseline funcional de onboarding, lifecycle e usuários. | Aprovação funcional não valida facilidade de uso ou valor percebido. |
| [IP-BE-2.1.5.1-tenant-standalone-module-gate](../../delivery/plans/implementation_plans/backend/IP-BE-2.1.5.1-tenant-standalone-module-gate.md) | Bootstrap standalone Tenant executado em focal `1/1`, matriz impactada `33/33` e Quality Gate focused `PASS`, todos zero-skip. | Fecha somente REQ-00031 AC-TEN-004; não comprova jornada, provider, PostgreSQL amplo ou AC-TEN-025. |
| [IP-BE-2.1.3.1-tenant-onboarding-grant-compensation](../../delivery/plans/implementation_plans/backend/IP-BE-2.1.3.1-tenant-onboarding-grant-compensation.md) | CREATE confirmado/GRANT falho compensado e comprovado em focal `6/6`, impactada `14/14`, arquitetura `33/33` e QG `47/47`, todos zero-skip. | Fecha somente a fronteira síncrona de AC-TEN-002/BR-TEN-006; não comprova saga ou reconciliação durável. |
| [REQ-00030](../requirements/REQ-00030-multitenancy-isolation-verification.md) | Gate verificável de isolamento L1/L2/L3. | Evidência técnica não mede confiança do escritório. |
| [REQ-00047](../requirements/REQ-00047-super-admin-tenant-pool-policy-administration.md)–[REQ-00052](../requirements/REQ-00052-tenant-pool-policy-controlled-hml-prd-rollout.md) | Controle e progressão operacional de recursos por tenant. | HML/PRD e sizing não estão autorizados por este PRD. |
| [REQ-00057](../requirements/REQ-00057-tenant-dashboard-fiscal-overview.md) | Dashboard fiscal implementado no repositório. | Sua validação de valor pertence ao PRD-00004 e não compõe o estado terminal do onboarding. |

Evidências de tempo de onboarding, taxa de ativação, falhas de provisionamento,
carga de suporte, adoção da administração ou satisfação do Tenant Admin não compõem
métricas ativas deste PRD por decisão do owner.

## Público e contexto

| Audience | Need / job | Expected value |
| --- | --- | --- |
| Escritório assinante / Tenant Admin | Iniciar e administrar a organização. | Ativação previsível e autonomia operacional. |
| Contador responsável | Acessar o workspace correto e acompanhar a carteira. | Contexto confiável e menor risco de mistura de dados. |
| Usuário do escritório | Entrar, ser convidado e operar conforme seu vínculo. | Acesso compreensível sem suporte recorrente. |
| Super Admin / Operações | Provisionar, suspender, recuperar e dimensionar tenants. | Controle auditável e menor esforço manual. |
| Segurança e Compliance | Verificar isolamento e lifecycle de dados. | Evidência de segregação e tratamento governado. |

## Outcomes e não-objetivos

> Outcomes quantitativos de tempo, qualidade, cobertura e garantia não são aplicáveis ao escopo MVP.


1. Reduzir o tempo e a intervenção manual entre criação e tenant operacional.
2. Tornar estados, limites e ações administrativas compreensíveis aos responsáveis.
3. Impedir que falhas ou mudanças de um tenant afetem dados e disponibilidade de outro.
4. Permitir gestão segura de usuários e do lifecycle organizacional.

### Non-goals

- Definir preço, catálogo ou estratégia comercial de planos.
- Especificar banco, realm, cache, pool, endpoint ou mecanismo de provisionamento.
- Prometer rollout em HML/PRD ou sizing sem aprovação própria.
- Definir jornadas fiscais, de cobrança ou de canal em detalhe.
- Tratar implementação local como validação do problema ou da adoção.

## 5. Product scope and limits

### In scope

- onboarding e estado de ativação do tenant;
- provisionamento percebido e recuperação de falha;
- isolamento entre organizações;
- assinatura, plano e limites enquanto contexto do workspace;
- convite, descoberta e administração de usuários do tenant;
- ativação, suspensão, retomada e encerramento governado;
- controles operacionais de capacidade por tenant;

### Out of scope for this validation cycle

- estratégia comercial e faturamento, cobertos pelo PRD-00001;
- serviço fiscal detalhado, coberto pelo PRD-00004;
- política completa de identidade e autorização, coberta pelo PRD-00005;
- validação de uso e valor do dashboard fiscal, coberta pelo PRD-00004; sua
  disponibilidade técnica inicial não altera o estado terminal do onboarding;
- migração de tenants reais, produção, credenciais ou dados reais;
- decisão de topologia, persistência, IAM ou infraestrutura.

## 6. Product validation criteria

Este PRD somente pode mudar para `Validated` quando Produto Plataforma Tenant e
Operações registrarem evidência versionada de:

- segmento e jornada de onboarding prioritários;
- definição de tenant ativado e de falha recuperável;
- decisão explícita do owner de não manter métricas baseadas em tempo, experiência
  ou testes com clientes reais neste ciclo, com os IDs expurgados e reservados;
- decisão explícita do owner de não manter hipóteses ativas neste ciclo, com os
  IDs expurgados ou transferidos e reservados;
- resolução das perguntas `OQ-TEN-*`;
- limite do primeiro ciclo e aprovação de Segurança/Compliance.

Essas condições validam a definição do produto e não substituem acceptance
criteria dos requisitos.

zados.

## Métricas

Não aplicável ao escopo MVP; métricas de tempo, qualidade, cobertura e garantia ficam fora desta fase.

## Product Hypotheses

Não há hipóteses ativas neste PRD.

`H-TEN-001`, `H-TEN-002` e `H-TEN-003` foram expurgadas do conjunto ativo deste
PRD em 2026-09-11 por decisão do owner. A primeira dependia de teste controlado e
análise do funil com tenants; a segunda, de teste de usabilidade e medição de
tarefas do Tenant Admin; a terceira, de piloto autorizado com métricas de falha,
capacidade e esforço. Os identificadores permanecem reservados e não serão
reutilizados.

`H-TEN-004` foi retirada do conjunto ativo deste PRD em 2026-09-11 e transferida,
sem validação ou rejeição do seu mérito, para `H-FIS-003` no
[PRD-00004](PRD-00004-fiscal-operations.md). O identificador não será reutilizado.

## Features e mapa de requirements

| Requirement | Contribution | Current documentary state |
| --- | --- | --- |
| [REQ-00005](../requirements/REQ-00005-plan-feature-matrix.md) | Funcionalidades e limites por plano/perfil. | Approved. |
| [REQ-00030](../requirements/REQ-00030-multitenancy-isolation-verification.md) | Gate de isolamento L1/L2/L3. | Approved. |
| [REQ-00031](../requirements/REQ-00031-phase2-tenant-lifecycle-and-access.md) | Onboarding, lifecycle, assinatura, usuários e LGPD. | Approved. |
| [REQ-00047](../requirements/REQ-00047-super-admin-tenant-pool-policy-administration.md) | Administração de política de recursos por tenant. | Implemented. |
| [REQ-00048](../requirements/REQ-00048-tenant-pool-policy-cache-isolation-resilience.md) | Isolamento e resiliência da política derivada. | Implemented. |
| [REQ-00049](../requirements/REQ-00049-tenant-pool-policy-authorized-test-rollout.md) | Habilitação e rollout de teste. | Implemented. |
| [REQ-00051](../requirements/REQ-00051-tenant-pool-policy-managed-runtime-environments.md) | Operação gerenciada multiambiente. | Approved. |
| [REQ-00052](../requirements/REQ-00052-tenant-pool-policy-controlled-hml-prd-rollout.md) | Progressão controlada em HML/PRD. | Approved. |
| [REQ-00053](../requirements/REQ-00053-billing-tenant-plan-offer-discovery.md) | Descoberta de ofertas elegíveis pelo tenant. | Implemented repository-local; provas pendentes. |

Os acceptance criteria permanecem exclusivamente nesses requisitos.

### 9.1 Feature inventory and acceptance coverage

| Feature ID | Product feature / audience outcome | Requirements | Canonical acceptance coverage | Documentary state |
| --- | --- | --- | --- | --- |
| `F-01` | Criar e provisionar um escritório até o estado operacional. | [REQ-00031](../requirements/REQ-00031-phase2-tenant-lifecycle-and-access.md) | [REQ-00031 AC-TEN-001–AC-TEN-027](../requirements/REQ-00031-phase2-tenant-lifecycle-and-access.md#16-acceptance-criteria) | Approved; AC-TEN-004 e a fronteira síncrona CREATE/GRANT de AC-TEN-002 estão implementados/testados repository-local/DEV, sem promover a feature integral. |
| `F-02` | Preservar isolamento verificável entre organizações. | [REQ-00030](../requirements/REQ-00030-multitenancy-isolation-verification.md) | [REQ-00030 AC-001–AC-015](../requirements/REQ-00030-multitenancy-isolation-verification.md#7-acceptance-criteria) | Approved. |
| `F-03` | Exibir plano, funcionalidades, limites e ofertas aplicáveis ao workspace. | [REQ-00005](../requirements/REQ-00005-plan-feature-matrix.md), [REQ-00053](../requirements/REQ-00053-billing-tenant-plan-offer-discovery.md) | [REQ-00005 AC-001–AC-030](../requirements/REQ-00005-plan-feature-matrix.md#7-acceptance-criteria); [REQ-00053 AC-001–AC-018](../requirements/REQ-00053-billing-tenant-plan-offer-discovery.md#7-acceptance-criteria) | Approved / Implemented repository-local. |
| `F-04` | Administrar ativação, suspensão, retomada e estado da assinatura do tenant. | [REQ-00031](../requirements/REQ-00031-phase2-tenant-lifecycle-and-access.md) | [REQ-00031 AC-TEN-001–AC-TEN-027](../requirements/REQ-00031-phase2-tenant-lifecycle-and-access.md#16-acceptance-criteria) | Approved. |
| `F-05` | Convidar, descobrir, ativar e administrar usuários do escritório. | [REQ-00031](../requirements/REQ-00031-phase2-tenant-lifecycle-and-access.md) | [REQ-00031 AC-TEN-001–AC-TEN-027](../requirements/REQ-00031-phase2-tenant-lifecycle-and-access.md#16-acceptance-criteria) | Approved. |
| `F-06` | Atender exportação, anonimização, exclusão e retenção legal no lifecycle. | [REQ-00031](../requirements/REQ-00031-phase2-tenant-lifecycle-and-access.md) | [REQ-00031 AC-TEN-001–AC-TEN-027](../requirements/REQ-00031-phase2-tenant-lifecycle-and-access.md#16-acceptance-criteria) | Approved. |
| `F-07` | Administrar política de capacidade por tenant com mudança auditável. | [REQ-00047](../requirements/REQ-00047-super-admin-tenant-pool-policy-administration.md) | [REQ-00047 AC-001–AC-033](../requirements/REQ-00047-super-admin-tenant-pool-policy-administration.md#7-acceptance-criteria) | Implemented. |
| `F-08` | Conter falha e estado derivado da política no tenant afetado. | [REQ-00048](../requirements/REQ-00048-tenant-pool-policy-cache-isolation-resilience.md) | [REQ-00048 AC-NFR-CACHE-001–AC-NFR-CACHE-016](../requirements/REQ-00048-tenant-pool-policy-cache-isolation-resilience.md#7-acceptance-criteria) | Implemented. |
| `F-09` | Habilitar teste controlado da política sem ampliar o rollout implicitamente. | [REQ-00049](../requirements/REQ-00049-tenant-pool-policy-authorized-test-rollout.md) | [REQ-00049 AC-NFR-TEST-001–AC-NFR-TEST-020](../requirements/REQ-00049-tenant-pool-policy-authorized-test-rollout.md#7-acceptance-criteria) | Implemented repository-local. |
| `F-10` | Operar a política de tenant em runtime gerenciado e reversível. | [REQ-00051](../requirements/REQ-00051-tenant-pool-policy-managed-runtime-environments.md) | [REQ-00051 AC-NFR-MANAGED-001–AC-NFR-MANAGED-017](../requirements/REQ-00051-tenant-pool-policy-managed-runtime-environments.md#8-criterios-de-aceite) | Approved. |
| `F-11` | Promover a capacidade em HML/PRD somente por rollout aprovado e observável. | [REQ-00052](../requirements/REQ-00052-tenant-pool-policy-controlled-hml-prd-rollout.md) | [REQ-00052 AC-NFR-ROLLOUT-001–AC-NFR-ROLLOUT-012](../requirements/REQ-00052-tenant-pool-policy-controlled-hml-prd-rollout.md#9-criterios-de-aceite) | Approved; execução ambiental não autorizada por este PRD. |

`F-TEN-012` foi retirada do inventário ativo e encaminhada ao PRD-00004 junto com
o REQ-00057. O identificador permanece reservado e não será reutilizado.

As faixas indicam cobertura documental. A aplicabilidade de cada critério é decidida
exclusivamente no requisito correspondente.

## 10. Use cases and decisions by reference

- Lifecycle: [UC-00028](../use-cases/UC-00028-phase2-tenant-lifecycle-and-user-management.md).
- Isolamento: [UC-00027](../use-cases/UC-00027-multitenancy-isolation-gate.md).
- Administração de recursos: [UC-00046](../use-cases/UC-00046-super-admin-tenant-pool-policy-management.md).
- Dashboard fiscal, somente como capacidade encaminhada: [PRD-00004](PRD-00004-fiscal-operations.md),
  `H-FIS-003` e [UC-00001](../use-cases/UC-00001-dashboard-view.md).
- Decisões: selecionar Multitenancy, Segurança/IAM e Resiliência pelo
  [índice de ADRs](../../adrs/README.md); este PRD não as redefine.

## 11. Current phase assessment

| Dimension | Observed state | Product implication |
| --- | --- | --- |
| Product vision | Multitenancy isolado é parte central da proposta. | Direção clara, ainda sem jornada/segmento priorizado. |
| Functional definition | Lifecycle e isolamento estão Approved; controles operacionais têm requisitos próprios. | Cobertura ampla, mas não equivale a fechamento de produto. |
| Repository implementation | A política de pool possui evidência local e o bootstrap standalone Tenant passou `1/1` + `33/33` + Quality Gate; o dashboard implementado é evidência do PRD-00004. | Fecha somente AC-TEN-004 e permite avaliação futura, sem provar operação real ou a feature integral. |
| External operation | HML/PRD, tenants reais e sizing não estão autorizados. | Resultado ambiental e escala permanecem desconhecidos. |
| Product evidence | Métricas baseadas em tempo, experiência ou testes com clientes reais e hipóteses dependentes dessas validações foram expurgadas por decisão do owner. | Não bloqueia o ciclo; owner e Segurança/Compliance já aprovaram o PRD. |

## 12. Dependencies and product risks

| Item | Impact | Owner |
| --- | --- | --- |
| Limites entre Tenant, Billing e Acesso | Evita promessa duplicada ou owner ambíguo. | Produto e Arquitetura |
| Operação ambiental e capacidade | Condiciona prova de confiabilidade e escala. | Operações |

## Assumptions e Open Questions

| ID | Question / decision needed | Decision owner | Resolution / evidence | Date | State |
| --- | --- | --- | --- | --- | --- |
| `OQ-TEN-001` | Qual segmento, evento inicial e estado terminal definem o primeiro onboarding validável? | Produto | O primeiro ciclo validável atende escritórios contábeis de pequeno porte participantes de uma coorte piloto autorizada. O evento inicial é a criação do tenant autorizada e aceita pela plataforma. O estado terminal é o tenant `ACTIVE`, com provisionamento concluído e primeiro Tenant Admin apto a acessar o workspace. Decisão humana materializada nesta revisão; o comportamento funcional permanece no `REQ-00031`. | 2026-09-11 | Resolved |
| `OQ-TEN-002` | Quais etapas podem exigir operação manual e qual limite é aceitável? | Produto e Operações | Após a criação aceita, o provisionamento deve concluir automaticamente em uma única execução da jornada. O envio do convite ao primeiro Tenant Admin pelo Super Admin é uma etapa manual planejada, e a ativação do convite é ação do próprio usuário. Intervenção de Suporte ou Operações é admitida somente como exceção quando uma falha deixa recursos que exigem limpeza e nova execução integral; o primeiro ciclo não pressupõe estado persistido `PROVISIONING_FAILED`, retomada ou retry. O limite operacional aprovado permanece zero intervenção excepcional em fluxo bem-sucedido: qualquer limpeza ou reinício assistido caracteriza exceção operacional, enquanto as ações planejadas dos atores ficam excluídas. `M-TEN-002` foi posteriormente expurgada por decisão do owner, sem revogar essa definição de comportamento. Decisão humana aprovada após inspeção do comportamento implementado e das evidências locais; os detalhes funcionais permanecem no `REQ-00031`. | 2026-09-11 | Resolved |
| `OQ-TEN-003` | Quais tarefas administrativas compõem a medida de autonomia do Tenant Admin? | Produto | O catálogo de tarefas e sua régua não serão definidos neste PRD. `M-TEN-005`, que media a experiência e a autonomia do Tenant Admin e dependia de futura observação de usuários, foi expurgada do inventário ativo por decisão do owner. Seu identificador permanece reservado e não há gatilho de reativação neste documento. Decisão humana registrada nesta revisão. | 2026-09-11 | Resolved |
| `OQ-TEN-004` | Quais targets/janelas de falha, recuperação e impacto cruzado serão exigidos? | Operações e Segurança | `M-TEN-003`, que combinava taxa de falha e tempo de recuperação, e `M-TEN-004`, que dependia da observação operacional de uma coorte piloto, foram expurgadas do inventário ativo por decisão do owner. O expurgo não reduz os requisitos técnicos de isolamento nem a tolerância de segurança: o gate L1/L2/L3 permanece governado pelo `REQ-00030`, mas não constitui métrica de produto deste PRD. Decisão humana registrada nesta revisão. | 2026-09-11 | Resolved |
| `OQ-TEN-005` | O dashboard fiscal pertence ao primeiro ciclo validável ou a uma validação posterior? | Produto e Fiscal | O dashboard pode estar tecnicamente disponível desde o primeiro acesso, inclusive em estado vazio, mas não compõe o estado terminal do onboarding. Sua validação de uso, priorização da carteira e valor percebido ocorrerá em ciclo fiscal posterior, governado pelo PRD-00004 quando houver atividade fiscal real. `H-TEN-004` e `F-TEN-012` deixam o conjunto ativo deste PRD e são encaminhadas, respectivamente, para `H-FIS-003` e para a cobertura do REQ-00057 no PRD-00004. Decisão humana aprovada após evidência repository-local de 14/14 testes backend, incluindo PostgreSQL real e RBAC, e 27/27 testes frontend; esses testes não substituem validação de produto com clientes. | 2026-09-11 | Resolved |

## Approval

| Role | Accountable party | Decision | Date | Evidence |
| --- | --- | --- | --- | --- |
| Owner | Produto Plataforma Tenant e Operações | Approved. | 2026-09-11 | Aprovação humana explícita do `PRD-00003 v1.10`, incorporada nesta revisão. |
| Required reviewer | Segurança/Compliance | Approved. | 2026-09-11 | Aprovação humana explícita do `PRD-00003 v1.11`, incorporada nesta revisão. |

## Product Definition Gate

**Product Definition Gate:** `PASS`.

O owner de Produto Plataforma Tenant e Operações e o reviewer obrigatório de
Segurança/Compliance aprovaram o ciclo. Não há métricas, hipóteses ou perguntas
abertas no inventário ativo.

## 15. Change log

| Version | Date | Change |
| --- | --- | --- |
| 1.14 | 2026-09-13 | Registra `TENANT-ONBOARDING-GRANT-COMP-001` concluído após focal 6/6, impactada 14/14, arquitetura 33/33 e QG 47/47 zero-skip; credita somente a fronteira síncrona CREATE confirmado/GRANT falho, sem promover F-TEN-001 ou AC-TEN-002 integral. |
| 1.13 | 2026-09-12 | Registra a evidência repository-local/DEV do bootstrap standalone Tenant: focal `1/1`, matriz impactada `33/33` e Quality Gate focused `PASS`, todos zero-skip; fecha somente REQ-00031 AC-TEN-004, sem promover F-TEN-001 integral, provider, PostgreSQL amplo ou AC-TEN-025. |
| 1.12 | 2026-09-11 | Promove o PRD a `Validated` após as aprovações explícitas de Produto/Operações e Segurança/Compliance, com perguntas, métricas e hipóteses do ciclo resolvidas. |
