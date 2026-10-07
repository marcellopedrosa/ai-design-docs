---
document_id: TP-00029
primary_nature: Plano
objective: Coordenar a evolucao do smoke temporario para operacao gerenciada da politica de pool por tenant, utilizavel pela tela sem restart e configuravel com seguranca por ambiente.
scope: Governanca, runtime membership, heartbeat/fencing/readiness, bootstrap committed, reconcile de drift, DEV local, contratos de configuracao HML/PRD, regressao da UI e gates repository-local.
non_objectives: Executar deploy ou ativar HML/PRD; usar recursos externos, tenants ou dados reais; inventar capacidade produtiva; alterar o wireframe; editar Compose ou infraestrutura sem IP-INFRA proprio.
owner: Engenharia, Backend, Frontend, Arquitetura e Qualidade
status: In Progress
version: 2.3
date: 2026-09-01
last_reviewed: 2026-09-01
keywords: tenant, pool, runtime gerenciado, dev, hml, prd, ui, heartbeat
related_files: ../../backend/docs/adrs/ADR-0052-parametros-pool-conexao-por-tenant.md, do../../product/requirements/REQ-00051-tenant-pool-policy-managed-runtime-environments.md, do../../product/use-cases/UC-00046-super-admin-tenant-pool-policy-management.md, ../../backend/docs/specs/IP-BE-23.4.3-tenant-pool-policy-managed-runtime-environments.md, ../../frontend/docs/specs/IP-FE-23.3.1-tenant-pool-policy-super-admin-ui.md, ../../frontend/docs/specs/IP-FE-23.4.1-tenant-pool-managed-runtime-ui-regression.md
code_references: backend/src/main/java/br/com/duoset/saas_service/config/persistence/routing/, backend/src/main/java/br/com/duoset/saas_service/contexts/tenant/, backend/src/main/resources/application*.yml, frontend/src/app/(dashboard)/tenants/[id]/, frontend/src/services/tenantPoolPolicyService.ts
principal_statement: O trabalho progride somente depois desta memoria e do plano backend persistidos; DEV deve operar pela tela no start normal, enquanto HML/PRD recebem contrato fail-closed sem ativacao ou sizing inferido.
---

# TP-00029 — Runtime gerenciado da politica de pool por tenant

## 1. Contexto e autorizacao

O REQ-00051 especializa o ADR-0052 sem substituir REQ-00047–REQ-00049. A
instrucao humana de 2026-09-01 autoriza criar esta memoria e, depois de validada,
implementar backend/frontend repository-local para teste em DEV. HML/PRD devem
ficar configuraveis pelo mesmo artefato, mas qualquer ativacao externa, deploy,
tenant real, segredo ou sizing continua fora do escopo.

## 2. Estrategia selecionada

1. preservar `DARK` e `LOCAL_SMOKE` e adicionar `MANAGED_ENVIRONMENT`;
2. obter token, lease e versao do control plane e renova-los por heartbeat CAS;
3. publicar evidencia atomica para fencing e readiness;
4. iniciar/reparar pools a partir da revisao committed e binding epoch;
5. permitir em `ACTIVE` todos os tenants provisionados cobertos, sem allowlist
   estatica A/B;
6. tornar DEV local autoestruturado e manter HML/PRD fail-closed por ausencia de
   capacidade/identidade explicita;
7. reutilizar a UI e o contrato HTTP ja implementados, com o delta focal do
   `IP-FE-23.4.1-tenant-pool-managed-runtime-ui-regression` para bounds
   ambientais e polling por operacao;
8. no DEV local, convergir baseline provisorio para a revisao committed e
   aguardar de forma limitada a expiracao de uma lease anterior, sem takeover;
   HML/PRD permanecem fail-closed e sem essa excecao operacional local.
9. validar a capacidade agregada autoritativa antes do bootstrap committed e
   revalida-la antes de readiness, incluindo reservas retidas e soma vazia para
   zero tenants.
10. separar o estabelecimento de membership/fence da readiness final: nenhum
    runner de startup pode adquirir conexao tenant antes da evidence vigente, e
    nenhum heartbeat pode abrir readiness antes de todos esses runners; a
    renovacao usa scheduler dedicado e a margem e rechecada por aquisicao e
    depois de I/O do control plane. A conclusao ocorre no `ApplicationReadyEvent`
    e o indicador tenant-pool integra o grupo de readiness.
11. manter o coordinator como unico writer do fence no modo gerenciado; o
    reconciler nao pode promover evidence que falhou na revalidacao. Submeter
    bootstrap/Flyway/probe committed ao guard por aquisicao, preservando somente
    o datasource provisorio e invisivel do bootstrap DEV como excecao.
12. normalizar deadlines de membership para a precisao de microssegundos do
    PostgreSQL antes de persistir e devolver cada snapshot; register/renew devem
    permanecer exatamente iguais ao valor relido, sem tolerancia no comparador.
13. no boundary frontend da politica de pool, validar `tenantId` pela forma
    textual hexadecimal canonica `8-4-4-4-12` aceita por Java/PostgreSQL, sem
    impor nibble de versao ou variante. O schema e unico para path, recurso e
    operacao, normaliza caixa e nao altera a validacao estrita de `operationId`
    nem identificadores de outros modulos.

## 3. Work packages

| # | Entrega | Estado atual | Evidencia de saida |
| --- | --- | :---: | --- |
| WP-0 | REQ-00051, ADR-0052, UC-00046, TP-00029 e IP-BE-23.4.3-tenant-pool-policy-managed-runtime-environments persistidos/indexados | Concluido | `validate-docs.sh` PASS |
| WP-1 | API publica estreita de membership e autoridade dinamica no runtime Config | Concluido repository-local | register/renew/fence/readiness e precisao PostgreSQL em `11/11 PASS` |
| WP-2 | `MANAGED_ENVIRONMENT` e matrizes PREPARE/ACTIVE/DRAIN_ONLY fail-closed | Concluido repository-local | matrizes focais/complementares e contextos Spring aprovados |
| WP-3 | bootstrap e reparo pela revisao committed/binding epoch, com membership/fence estabelecido antes dos consumidores JDBC tenant | Concluido repository-local | startup/safety `80/80 PASS` e stack DEV `READY` |
| WP-4 | DEV local normal com capacidade sintetica exata, coverage gate, admissao agregada e readiness somente depois dos runners tenant | Concluido repository-local | PostgreSQL `18/18 PASS`, backfill sem drift/falha e backend healthy sem restart |
| WP-5 | configuracao tipada HML/PRD default-DARK, sem budget herdado | Concluido repository-local | contrato validado; HML/PRD permanecem `DARK`, sem sizing ou ativacao |
| WP-6 | regressao da tela existente e fluxo backend-real focal | Em andamento | correcao tenantId e gates repository-local concluidos; E2E autenticado e smoke humano A/B continuam pendentes |
| WP-7 | gates impactados e handoff | Concluido repository-local | architecture `29/29`; isolation gate `30/30`; governanca documental PASS |

## 4. Sequencia e dependencias

- WP-0 precede qualquer edicao de software.
- WP-1 e WP-2 precedem ativacao de DEV.
- WP-3 precede declarar alteracao duravel ou testar restart.
- WP-4 precede o smoke manual pela tela.
- WP-4 deve obter a decisao agregada sob a autoridade serializada do allocator
  antes de construir pools committed e revalida-la antes de readiness; coverage
  integral, isoladamente, nao autoriza abertura de pool.
- A sequencia de WP-3/WP-4 e `capacity -> membership/fence -> committed pools ->
  tenant JDBC runners -> ApplicationReadyEvent -> readiness`; o heartbeat pode
  renovar a lease durante a barreira, mas nao pode publicar readiness
  antecipadamente. Scheduler
  compartilhado, deadline sem margem ou validacao somente antes de I/O nao
  satisfazem WP-4.
- Evidence persistida nao equivale, sozinha, a autorizacao local. Em modo
  gerenciado, somente o coordinator promove/limpa o guard depois da validacao
  integral; reconcile, Flyway e probe nao podem reabrir ou contornar esse estado.
- WP-5 valida somente o contrato do artefato; nao executa ambiente externo.
- WP-6 reutiliza o IP-FE-23.3.1-tenant-pool-policy-super-admin-ui; novo visual nao e necessario.
- WP-7 encerra somente o recorte repository-local comprovado.

## 5. Boundary de infraestrutura

Este plano nao autoriza editar `docker-compose*.yml`, workflows de deploy,
templates produtivos ou `infra/`. Se a implementacao comprovar necessidade de
alterar esses artefatos, deve parar nesse boundary e solicitar gate humano proprio
para o ID e path exatos de um `IP-INFRA`, conforme o indice da colecao. Configurar
`application-dev.yml`, `application-hml.yml` e `application-prd.yml` permanece no
IP backend.

## 6. Validacao planejada

```bash
./infra/scripts/validate-docs.sh
cd backend
./mvnw -B -Dtest=<testes-focais> test
./mvnw -B -Dtest=ModuleStructureVerificationTest test
./mvnw -B -Dtest=CleanArchitectureRulesTest,CleanArchitectureRuleContractTest test
./mvnw -B clean -Ptenant-isolation-gate verify
cd ../frontend
npm test -- --no-file-parallelism --maxWorkers=1
npm run lint
```

O recorte corretivo de WP-6 deve provar adicionalmente que o tenant DEV
`aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa` gera a chamada HTTP esperada, que recurso
e operacao com esse `tenantId` passam pelo mesmo schema e que traversal, texto
nao hexadecimal ou forma fora de `8-4-4-4-12` falham antes da rede. Os testes
devem comprovar que `operationId` continua usando UUID versionado estrito.

Testes Docker/PostgreSQL usam apenas o Docker local autorizado e fixtures
sinteticas. Falha, indisponibilidade ou skip sao reportados, nunca convertidos em
aceite.

## 7. Rollback e kill switch

- rollback funcional cria nova revisao pela tela;
- perda de autoridade fenceia novas aquisicoes e derruba readiness;
- rollback operacional usa `ACTIVE -> DRAIN_ONLY -> DARK`;
- DEV pode voltar ao modo `DARK` sem remover revisoes/audit;
- nenhum drain fecha conexao em voo a forca.

## 8. Handoff esperado

O handoff deve listar arquivos, decisoes, comandos, resultados, skips/falhas e:

- se a tela esta utilizavel no DEV local pelo start normal;
- quais variaveis/autoridades HML e PRD ainda precisam receber de SRE/DBA;
- por que configuracao repository-local nao equivale a deploy/ativacao externa;
- se surgiu necessidade de `IP-INFRA` e qual gate exato permanece aberto.

## 9. Evidencia repository-local de 2026-09-01

| Recorte | Resultado reproduzivel |
| --- | --- |
| Governanca documental | `validate-docs.sh` PASS: 688 Markdown, 30 diretorios e 668 artefatos indexados; estrutura documental PASS |
| Backend startup/safety focal | `80/80 PASS` |
| Backend complementar impactado | `73/73 PASS` |
| Contextos Spring impactados | `5/5 PASS` |
| Membership precision focal + PostgreSQL | `11/11 PASS`; deadline canonico em microssegundos preservado no register/renew/snapshot |
| PostgreSQL tenant pool | `18/18 PASS` depois de preservar o wait nativo da fixture Testcontainers, sem listening-port generico |
| Arquitetura | `29/29 PASS`: Modulith, contratos e regras ArchUnit |
| Tenant isolation gate final | `BUILD SUCCESS`, `30/30 PASS`, sem falha, erro ou skip |
| Stack Compose DEV | backend `running/healthy`, `restart=0`; readiness `UP`; `tenantPoolRuntime=READY`; backfill `total=1`, `alreadyPresent=1`, `drift=0`, `failed=0` |
| Boundary HTTP local | frontend `/login` alcancavel; API administrativa sem autenticacao responde `401` |
| Frontend focal | tenantId `30/30 PASS`; feature impactada `50/50 PASS`; TypeScript PASS |
| Frontend serial | 153 arquivos e 995 testes PASS |
| Qualidade frontend | lint sem erros e 58 avisos preexistentes, build de 39 paginas PASS e Prettier focal PASS |
| E2E backend-real autenticado | nao executado: `E2E_KEYCLOAK_USERNAME`, `E2E_KEYCLOAK_PASSWORD` e `AUTH_SESSION_SECRET` ausentes; segredos nao foram extraidos dos containers |
| Correcao do tenant DEV legado | `tenantPoolTenantIdSchema` com `z.guid()`/lowercase aplicado somente a path, resource e operation tenantId; all-a, uppercase, isolamento, sete malformed/traversal e operationId estrito aprovados; frontend DEV `running`, `restart=0` |

O `npm run format:check` global continua encontrando arquivos preexistentes fora
do recorte sem formatacao; nenhum deles foi reformatado em massa. Os arquivos
tocados pelo delta frontend passam no Prettier focal. A matriz PostgreSQL foi
concluida depois de corrigir a readiness da fixture sem substituir o wait nativo
do `PostgreSQLContainer`. O gate Failsafe de isolamento tambem concluiu
`30/30 PASS`, sem skips. O smoke pela tela com Super Admin,
isolamento A/B, rollback e drain continua aceite humano local e nao deve ser
inferido da disponibilidade do `/login`, do `401` sem autenticacao ou da
descoberta estatica do Playwright. HML/PRD permanecem `DARK`, sem ativacao,
sizing, deploy ou autoridade externa fornecida por este plano.

## 10. Change Log

| Version | Date | Author | Changes |
| --- | --- | --- | --- |
| 2.3 | 2026-09-01 | Codex (OpenAI) | Fecha a correcao repository-local do tenantId DEV com schema tenant-scoped, regressao `30/30`, feature `50/50`, suite `995/995` e gates de qualidade; WP-6 permanece aberto somente para o aceite autenticado A/B/rollback/drain. |
| 2.2 | 2026-09-01 | Codex (OpenAI) | Registra antes do codigo a compatibilidade do `tenantId` da politica de pool com a forma hexadecimal canonica aceita pelo backend, mantendo isolamento, validacao de path e UUIDs operacionais estritos. |
| 2.1 | 2026-09-01 | Codex (OpenAI) | Consolida evidencias backend/PostgreSQL/arquitetura/isolation gate, stack DEV e governanca; fecha WP-0 a WP-5 e WP-7 no recorte repository-local, mantendo WP-6 em andamento apenas pelo E2E autenticado/smoke humano; HML/PRD seguem DARK. |
| 2.0 | 2026-09-01 | Codex (OpenAI) | Fecha no plano a precisao canonica de lease PostgreSQL exigida pela igualdade exata da autoridade gerenciada. |
| 1.9 | 2026-09-01 | Codex (OpenAI) | Define ownership exclusivo do fence pelo coordinator e fecha bypass de aquisicao fisica em Flyway/probe committed. |
| 1.8 | 2026-09-01 | Codex (OpenAI) | Inclui scheduler dedicado, fechamento do TOCTOU da margem, finalizador no ApplicationReadyEvent e health group fail-closed. |
| 1.7 | 2026-09-01 | Codex (OpenAI) | Registra a barreira de startup para que consumers JDBC tenant executem com fence vigente antes da readiness final. |
| 1.6 | 2026-09-01 | Codex (OpenAI) | Registra evidencias repository-local, o baseline de formatacao e os aceites Docker/UI ainda pendentes. |
| 1.5 | 2026-09-01 | Codex (OpenAI) | Publica a referencia canonica completa do plano frontend incremental. |
| 1.4 | 2026-09-01 | Codex (OpenAI) | Vincula o plano frontend incremental e registra o fechamento de bounds ambientais e polling por operacao. |
| 1.3 | 2026-09-01 | Codex (OpenAI) | Corrige a execucao serial da suite frontend para as flags suportadas pelo Vitest 3 (`--no-file-parallelism --maxWorkers=1`). |
| 1.2 | 2026-09-01 | Codex (OpenAI) | Inclui o gate agregado de capacidade antes do bootstrap committed/readiness e os cenarios de reservas retidas e zero tenants. |
| 1.1 | 2026-09-01 | Codex (OpenAI) | Registra a politica de restart seguro identificada na revisao: convergencia committed e retry local limitado por lease. |
| 1.0 | 2026-09-01 | Owner humano / Codex (OpenAI) | Cria o plano persistido anterior ao software e inicia o recorte repository-local autorizado. |
