---
document_id: TP-00071
primary_nature: Plano
objective: Restaurar a compatibilidade Flyway da trilha tenant com o histórico já aplicado e preservar os templates de marca vigentes.
scope: Quatro migrations tenant historicamente reescritas, uma migration evolutiva e regressão PostgreSQL local.
non_objectives: Não acessar ou modificar PRD, executar Flyway repair, alterar workflows ou implantar em ambiente externo.
owner: Engenharia Backend; operação e verificação ambiental pela Infra
status: In Progress
version: 1.3
date: 2026-10-02
last_reviewed: 2026-10-02
keywords: Flyway, checksum, tenant, PostgreSQL, templates, incidente
related_files: TP-00069-flyway-migration-pr-validation.md, ../../product/requirements/REQ-00031-phase2-tenant-lifecycle-and-access.md, ../../product/requirements/REQ-00055-commercial-contact-capture-management.md
code_references: backend/src/main/resources/db/migration/tenant/, backend/src/test/java/br/com/duoset/saas_service/config/persistence/AllFlywayMigrationsPostgresTest.java, backend/src/test/java/br/com/duoset/saas_service/config/persistence/CommercialContactPlatformMigrationTest.java
principal_statement: Restaurar exatamente os checksums aplicados de V53, V80, V85 e V86 e transferir a mudança de marca para uma nova migration forward-only.
---

# TP-00071 — Recuperação dos checksums históricos Flyway

## Diagnóstico

O log de inicialização fornecido pelo solicitante em 2026-10-02 termina em
`FlywayValidateException` na trilha `tenant`. `tenantFlyway` falha antes da
criação do `platformEntityManagerFactory`; as falhas JPA e Tomcat são efeitos
subsequentes. O log informa os pares de checksum abaixo. Nenhum banco de PRD
foi consultado.

| Versão | Aplicado no log | SQL atual | Revisão Git cujo SQL coincide com o aplicado |
| --- | ---: | ---: | --- |
| V53 | -1397881323 | 1010443098 | `516489a8e13b` |
| V80 | -768732245 | -1729276064 | `a55074a02c11` |
| V85 | -1834534273 | -23059183 | `5283c5ae15af` |
| V86 | 1081924623 | -1934307446 | `d2a6f85845e0` |

O cálculo reproduz o CRC32 Flyway sobre as linhas UTF-8 sem separadores. O diff
entre cada revisão aplicada e o SQL atual mostra somente substituições de
`Agente Fiscal` por `Contador Fiscal` em conteúdo dos templates. A substituição
foi feita dentro de migrations já aplicadas; um banco limpo passa nos testes,
mas um histórico anterior rejeita a mudança de checksum.

## Implementation Readiness Gate

**Resultado: READY para o recorte local abaixo.** Não autoriza operação ou
verificação em PRD.

### Gate Audit

- **Product Definition:** PRD not applicable. Esta task corrige a compatibilidade
  técnica do histórico e preserva o conteúdo final já codificado, sem decidir
  texto de produto novo.
- **Fontes superiores:** solicitação e log de 2026-10-02; REQ-00031 v1.7
  `Approved`, BR-TEN-007 e AC-TEN-017; contrato de migração do TP-00069 v1.4;
  Software Quality Standard global v1.3. REQ-00055 v3.5 documenta os
  templates vigentes como contexto de regressão, sem criar uma decisão nova.
- **Ator e valor:** mantenedor do backend restaura a inicialização em bancos
  que já aplicaram as quatro versões, preservando defaults e personalizações.
- **Incertezas:** o log identifica os quatro checksums aplicados e cada um
  coincide com uma única revisão local. A confirmação de todas as instâncias
  e do estado ambiental cabe à Infra após publicação; não é precondição para
  preparar e validar o patch local.
- **Dependências:** JDK 25, Maven offline, Docker/Testcontainers e PostgreSQL
  descartável; disponibilidade confirmada na execução do TP-00069, a repetir.
- **What:** migrar e validar tanto banco limpo quanto banco com histórico dos
  quatro checksums anteriores, mantendo o conteúdo final esperado.
- **Where:** os quatro SQLs V53/V80/V85/V86, novo V95 na trilha `tenant`,
  `AllFlywayMigrationsPostgresTest.java`,
  `CommercialContactPlatformMigrationTest.java`, este plano e seu índice imediato.
- **Granularidade:** restauração das revisões aplicadas e V95 são inseparáveis
  para compatibilidade mais comportamento final; compartilham o mesmo teste,
  gate e handoff. Deploy ambiental permanece com a Infra.
- **Reuses:** Flyway, Testcontainers e comando `validate-migrations.sh`.
- **Requirements:** recuperar bytes anteriores comprovados, não reparar a
  tabela de histórico, atualizar somente defaults de marca e conservar
  templates customizados.
- **Reauditoria v1.1:** o primeiro gate de PR encontrou teste estático que
  exigia a marca nova dentro de V80/V85/V86. O teste deve verificar os bytes
  históricos e a atualização em V95; sua alteração está incluída no mesmo
  aceite e nos paths, sem nova decisão de produto.

### Acceptance Tests

1. Os checksums resolvidos de V53/V80/V85/V86 são exatamente os quatro
   valores aplicados no log, e Flyway valida um banco descartável migrado
   até V94 antes de aplicar V95.
2. V95 produz `Contador Fiscal` nos assuntos e corpos dos três templates
   canônicos em instalação limpa e upgrade.
3. V95 não altera assunto ou corpo customizado; reexecutar Flyway não cria
   migration adicional ou mudança de dados.
4. Todas as oito localizações Flyway passam no gate focal sem skips; o gate de
   PR backend e os subgates A1/A2/A3 são registrados separadamente.
5. O teste estático verifica os seeds originais e a migration evolutiva sem
   exigir reescrita de V80/V85/V86.

### Prohibited

`flyway repair`, edição de schema history real, acesso a PRD, dados reais,
segredos, `.github/workflows/`, desativação de `validateOnMigrate` ou relaxamento
de testes. A restauração dos quatro SQLs devolve o conteúdo exato já aplicado;
nenhuma nova instrução entra em versões históricas.

### Mandatory

Conferência de checksums antes e depois; `migration-validation`; A1/A2/A3
independentes por `quality-gate`; validador documental e revisão do diff.

### Definition of Done

- [x] Quatro arquivos históricos correspondem byte a byte às revisões Git
  identificadas e aos checksums do log.
- [x] V95 é a única nova mudança de dados e preserva campos customizados.
- [x] Testes focal e de PR terminam com os resultados exigidos e evidência atual.
- [x] Plano e índice registram comandos, resultados, skips, limitações e handoff.

## Handoff ambiental

Após publicação e gates de PR, a Infra compara os quatro checksums do log com
os checksums resolvidos no artefato candidato. Antes do deploy, deve também
comparar os SHA-256 dos quatro SQLs com `.deploy/state/migrations.sha256`:
`deploy-production.sh update` executa `validate_migration_immutability`
antes de construir imagens ou gerar o backup de atualização e pode bloquear a
restauração como `migration edited`. Se o manifesto não coincidir, a Infra
precisa de exceção versionada e testada, limitada aos quatro arquivos e
aprovada após comprovar histórico e backup restaurável/off-site; não pode
editar o manifesto manualmente nem desligar a validação inteira. O
[TP-00071 — texto de card para Jira](TP-00071-jira-prd-execution.txt) detalha o fluxo
condicional. Com o preflight resolvido, a Infra executa o caminho aprovado de
deploy e observa se `tenantFlyway` conclui e se a aplicação inicializa. Caso
apareça outro checksum incompatível, interrompe a promoção e devolve o log
para nova análise. Não executar `repair` nem alterar histórico em PRD como
atalho. A resolução efetiva em PRD exige essa evidência operacional, que esta
task local não pode produzir.

## Evidência de execução — 2026-10-02

- **Revisão do histórico — PASS:** comparação binária com as quatro revisões
  Git da tabela e CRC32 calculado produziram exatamente os checksums do log.
  Nenhum `repair` ou acesso ao banco real foi realizado.
- **A1 focal — PASS após correção:** a primeira execução de
  `./infra/scripts/validate-migrations.sh --offline` falhou porque o teste
  V93→V94 supunha que V94 era a última versão. Após separá-lo em V94 e V95,
  o comando passou com 4 testes, 0 falhas, 0 erros e 0 skips em PostgreSQL
  17.11. `./mvnw -B -o
  -Dtest=CommercialContactPlatformMigrationTest,AllFlywayMigrationsPostgresTest
  test` passou com 5 testes e zero skips.
- **A1 PR — PASS após correção:** a primeira execução do gate completo
  encontrou o teste estático `CommercialContactPlatformMigrationTest`
  exigindo a marca nova em V80/V85/V86. O teste passou a verificar o seed
  histórico e V95. A repetição de
  `MAVEN_ARGS=-o ./infra/scripts/validate-quality-gates.sh --scope backend
  --level pr --target backend/src/test/java/br/com/duoset/saas_service/config/persistence/AllFlywayMigrationsPostgresTest.java
  --target backend/src/test/java/br/com/duoset/saas_service/config/persistence/CommercialContactPlatformMigrationTest.java
  --target backend/src/main/resources/db/migration/tenant/V95__refresh_default_notification_template_brand.sql`
  retornou `QUALITY_GATE_RESULT=PASS failures=0 blocked=0`: Surefire 3267
  testes, 0 falhas, 0 erros, 7 skips legados; Failsafe 81 testes, 0 falhas,
  0 erros, 0 skips. O teste Flyway executou sem skip. Os sete skips legados
  não são da trilha de migrations e continuam sob revisão dos respectivos
  owners.
- **A2 — PASS:** build Maven, JaCoCo `check`, instruções 73,81%, branches
  58,02%, `QUALITY_METRICS_RESULT=PASS violations=0 blocked=0`, arquivos
  de teste abaixo de 500 linhas, `git diff --check`, comparação binária e
  validador documental aprovados.
- **A3 — PASS no recorte local:** revisão pelo Security Standard global v1.1
  e security-gate. V95 contém SQL estático, sem input externo ou segredo,
  atualiza apenas três códigos de template e campos que correspondem aos
  defaults históricos. Os fingerprints MD5 identificam conteúdo padrão,
  não autenticam dados. Fixture e banco são sintéticos; nenhum controle de
  acesso, endpoint ou superfície exposta foi alterado.

### Insights e limite operacional

- Um teste de instalação limpa não detecta divergência com checksums de
  migrations já aplicadas. O novo teste fixa os quatro checksums observados
  e reproduz upgrade em banco descartável.
- V95 preserva campos cujo conteúdo difere dos defaults anteriores. Uma
  customização byte a byte idêntica ao default é indistinguível de um campo
  não customizado e recebe a atualização de marca.
- O resultado em PRD ainda depende da publicação do artefato e da observação
  de startup pela Infra. Não há evidência ambiental nem autorização para
  declarar o incidente encerrado em produção.
