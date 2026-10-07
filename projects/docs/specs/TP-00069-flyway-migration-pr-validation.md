---
document_id: TP-00069
primary_nature: Plano
objective: Comprovar as migrations Flyway ativas em PostgreSQL descartável antes de PR para main.
scope: Teste repository-local das oito trilhas e comando de validação pré-PR.
non_objectives: Não alterar deploy, workflows GitHub, banco de produção ou migrations históricas.
owner: Engenharia e Qualidade
status: In Progress
version: 1.4
date: 2026-10-01
last_reviewed: 2026-10-02
keywords: Flyway, PostgreSQL, Testcontainers, migrations, PR
related_files: TP-00067-admin-user-status-normalization.md, ../../product/requirements/REQ-00031-phase2-tenant-lifecycle-and-access.md, ../../agents/standards/global/software-quality-standard.md
code_references: backend/src/main/resources/db/migration/, backend/src/test/java/br/com/duoset/saas_service/config/persistence/, infra/scripts/
principal_statement: Um comando local falha se qualquer trilha Flyway ativa não migrar e validar em PostgreSQL descartável ou se o teste for ignorado.
---

# TP-00069 — Validação pré-PR das migrations Flyway

## Implementation Readiness Gate

**Result: READY** — auditoria de 2026-10-01 para esta task de teste e comando
repository-local. Uma mudança de escopo ou fonte exige nova auditoria.

### Gate Audit

- **Product Definition:** PRD not applicable. O pedido trata de garantia de engenharia para artefatos existentes; não altera comportamento de produto.
- **Fontes superiores:** solicitação explícita de 2026-10-01; REQ-00031 v1.7 `Approved` (BR-TEN-004/007/029 e AC-TEN-017 para persistência tenant); Software Quality Standard global v1.3; política Git v1.2; skill `migration-validation` v1.0.0.
- **User Story View:** mantenedor do backend comprova as migrations antes da PR para evitar falha no deploy; aceite abaixo.
- **Incertezas:** nenhuma decisão de produto ou arquitetura aberta para o teste local. O check obrigatório do servidor é dependência externa sob owner Infra e fica fora desta task.
- **Dependências:** Docker local disponível (29.8.0), imagem PostgreSQL 17 usada pelos testes existentes, Maven wrapper e dependências já declaradas. A disponibilidade efetiva da imagem e do Maven será verificada na execução; ausência produz `BLOCKED`.
- **What:** comando único executa teste PostgreSQL de todas as localizações Flyway ativas e falha em erro ou skip.
- **Where:** `backend/src/test/java/br/com/duoset/saas_service/config/persistence/AllFlywayMigrationsPostgresTest.java`; `infra/scripts/validate-migrations.sh`; `infra/scripts/validate-quality-metrics.mjs`; este plano e `docs/delivery/plans/README.md`.
- **Granularidade:** um resultado observável (validação repository-local), mesmo handoff e mesmo ciclo de teste. A configuração GitHub pertence à Infra e é uma entrega distinta.
- **Reuses:** Flyway, PostgreSQL Testcontainers, JUnit, Maven Surefire e padrão de scripts existente.
- **Requirements:** preservar migrations históricas e comportamento do backend; não alterar `.github/workflows/`; testar banco vazio, reexecução e upgrade V93→V94 com fixture sintética.
- **Reauditoria v1.1:** o gate de PR revelou um wrapper de métricas que importa a si próprio. A correção do import é necessária para a mesma entrega observável; seu path foi acrescentado ao escopo, sem decisão de produto ou dependência nova.
- **Reauditoria v1.3:** revisão pós-gate identificou duplicação da allowlist
  runtime/teste. O teste lê a declaração existente no source do runtime e
  falha se ela não puder ser reconhecida ou se divergir dos diretórios. A
  alternativa de editar `TenantDatabaseRegistry.java` foi descartada após A2
  apontar 727 linhas no arquivo (limite 500); o runtime permanece intacto.
  A execução focal e o gate de PR foram repetidos após esta mudança, com
  resultado `PASS`.

### Acceptance Tests

1. O teste descobre todas as localizações ativas e falha se diretório e allowlist divergirem.
2. Cada localização migra em banco PostgreSQL vazio, valida, reexecuta sem novas migrations e mantém histórico íntegro.
3. A trilha `tenant` aplica V93 sobre fixture sintética, executa V94 e comprova `admin_users.status = 'ATIVO'`.
4. O comando pré-PR termina com código diferente de zero se Docker não estiver disponível, algum teste falhar ou o teste de migrations for ignorado.
5. O comando e o handoff listam versões, trilhas, falhas e limitações; nenhuma edição de `.github/workflows/` ocorre.
6. O wrapper de métricas executa o validador canônico sem erro de importação.

### Prohibited

Produção, dados reais, segredos, rede sem autorização, `flyway repair`, edição de migration histórica, `.github/workflows/`, relaxamento de testes ou thresholds.

### Mandatory

`migration-validation`, A1/A2/A3 independentes pelo `quality-gate`, validador documental, revisão de diff e encaminhamento do check obrigatório à Infra.

### Definition of Done

- Teste das oito trilhas e comando pré-PR presentes e executados sem skips em PostgreSQL descartável.
- Wrapper de métricas de PR executável e testes focados aprovados.
- Evidência de V93→V94 com dados sintéticos e de reexecução Flyway registrada.
- A1, A2 e A3 publicados separadamente com resultado e limitações.
- Especificação do check obrigatório pronta para a Infra; sua configuração não é declarada concluída por esta task.

## Handoff para Infra

Solicitação pronta para a equipe de Infra, owner de `.github/workflows/` e das
regras de branch protection:

1. Executar `./infra/scripts/validate-migrations.sh` em toda PR candidata à
   `main` que altere `backend/src/main/resources/db/migration/`, o backend ou o
   próprio gate. O runner precisa de Docker, PostgreSQL Testcontainers,
   Python 3, JDK 25 e Maven. O script retorna não zero se qualquer caso falhar,
   for ignorado ou não produzir relatório atual.
2. Exigir o status desse job e o gate de qualidade backend nível `pr` como
   checks obrigatórios para merge na `main`.
3. Manter a gestão de downloads de imagens e dependências sob a política de
   rede da Infra. Não reutilizar bancos ou dados de produção nos testes.

O handoff documenta os critérios, mas não comprova que o GitHub recebeu ou
ativou os checks; essa confirmação cabe à Infra.

## Evidência e revisão de 2026-10-01 a 2026-10-02

- **A1 focal — PASS:** `./infra/scripts/validate-migrations.sh --offline` em
  PostgreSQL 17.11 / Docker 29.8.0; 3 testes, 0 falhas, 0 erros, 0 skips.
  O teste cobriu 8 localizações, SQL descoberto pelo Flyway, instalação limpa,
  reexecução, upgrade da versão anterior, checksum adulterado e V93→V94.
- **Fail-closed — PASS:** simulação de Docker indisponível retornou código 1
  antes de executar Maven.
- **A2 focal — PASS:** compilação backend/testes Maven offline, teste do validador
  de métricas, medição do arquivo novo, `bash -n`, validador documental,
  paridade dos adapters e Harness Doctor. O wrapper de métricas tinha import
  recursivo; a correção foi executada e testada.
- **A3 — PASS no recorte local:** revisão do delta conforme Security Standard
  v1.1; bancos, usuários e senhas de teste são descartáveis/sintéticos;
  entradas do script são fechadas (`--offline` opcional); nenhum acesso a
  produção, dado real ou segredo foi introduzido. Security-gate AppSec não
  aplicável porque não houve mudança em API, auth, superfície exposta ou dado
  sensível de aplicação.
- **Gate de PR — PASS no executor:** primeira execução retornou `FAIL` por
  fixture fiscal vencida; ver TP-00070. Após a correção e uma repetição final
  depois da reauditoria v1.3,
  `MAVEN_ARGS=-o ./infra/scripts/validate-quality-gates.sh --scope backend
  --level pr --target backend/src/test/java/br/com/duoset/saas_service/config/persistence/AllFlywayMigrationsPostgresTest.java
  --target backend/src/test/java/br/com/duoset/saas_service/contexts/fiscal/internal/application/usecase/EmitirDasUseCaseTest.java`
  retornou `QUALITY_GATE_RESULT=PASS`: Surefire 3266 testes, 0 falhas,
  0 erros e 7 skips legados; Failsafe 81 testes, 0 falhas, 0 erros e 0 skips;
  JaCoCo `check` aprovado e métricas de arquivo aprovadas. Na repetição final,
  o relatório JaCoCo registrou instruções 73,81% e branches 58,02%, com
  `QUALITY_GATE_RESULT=PASS failures=0 blocked=0` e
  `QUALITY_METRICS_RESULT=PASS violations=0 blocked=0`; os totais de testes
  permaneceram iguais. A execução anterior levou 50m43s com download inicial
  da imagem Keycloak. Os sete skips não pertencem ao gate Flyway e conservam suas
  justificativas nos testes, mas devem ser revistos pelos respectivos owners.

### Insights e limites

- `dashboard` possui apenas V1: a instalação limpa cobre sua primeira versão;
  não há versão anterior para cenário de upgrade.
- A lista de contextos de tenant permanece na fonte do runtime; o teste lê a
  declaração, compara com os diretórios e migra todos os contextos nessa ordem.
  Uma refatoração da declaração exige atualizar o parser do teste, que falha
  fechado quando não reconhece o formato.
- O teste não reproduz dados, grants ou histórico efetivos de produção.
  Qualificação operacional e ativação do check GitHub continuam com a Infra.
- A execução do gate de PR passou localmente, mas ainda não há status obrigatório
  de branch protection; a Infra precisa publicar e ativar esse controle.
