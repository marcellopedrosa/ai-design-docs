---
document_id: "ADR-0019"
primary_nature: "Decisao"
objective: "Registrar a decisão arquitetural “Estratégia de Single Database-per-Tenant”, seus motivadores, alternativas e consequências."
scope: "Decisão, componentes, integrações e limites explicitamente descritos em “Estratégia de Single Database-per-Tenant”."
non_objectives: "Não implementar a decisão, substituir requisitos relacionados nem atestar capabilities ou ambientes sem evidência explícita."
owner: "@MultiTenantEng"
status: "Partially Superseded"
date: "2026-07-24"
version: "1.1"
keywords: "adr, decisao, arquitetura, estratégia, de, single, database, per, tenant"
related_files: "README.md, ADR-0052-parametros-pool-conexao-por-tenant.md"
code_references: "TenantOnboardingUseCase"
principal_statement: "A aplicação migrará sua estratégia de persistência para **Single Database-per-Tenant**."
---

# ADR-0019 - Estratégia de Single Database-per-Tenant

- Date: 2026-07-24  
- Status: Partially Superseded  
- Version: 1.1  
- Authors / Owners: @MultiTenantEng  
- Reviewers: @AgentOrchestrator, Duoset (Admin)  
- Stakeholders: Backend Team, DBA, Compliance Team  
- Supersedes: ADR-0005 (Parcialmente: Altera a topologia de persistência, mas mantém isolamento lógico)  
- Partially superseded by: [ADR-0052](ADR-0052-parametros-pool-conexao-por-tenant.md), exclusivamente quanto ao fallback legado do §7.  

---

> [!IMPORTANT]
> O ADR-0052 substitui somente o fallback legado do §7. A decisão central deste
> ADR — um banco dedicado e um pool compartilhado apenas pelos bounded contexts do
> mesmo tenant — permanece vigente sem alteração.

# 1. Context

O sistema foi arquitetado usando Spring Modulith e 7 bancos de dados compartilhados (um para cada bounded context + plataforma) com isolamento Multi-Tenant em nível de linha (coluna `tenant_id`).

À medida que o SaaS escala para centenas de escritórios de contabilidade, identificamos três problemas graves no isolamento por nível de linha (Row-Level Security):
1. **LGPD (Direito ao Esquecimento)**: Deletar todos os dados de um cliente exige executar `DELETE FROM tabela WHERE tenant_id = ?` em dezenas de tabelas ao longo de 6 bancos de dados separados.
2. **Performance e Escala**: Tabelas grandes (ex: DAS, mensagens do WhatsApp) misturam dados de todos os clientes, degradando índices.
3. **Isolamento de Segurança (Físico)**: Dados muito sensíveis de diferentes escritórios residem no mesmo disco e mesma tabela, o que pode afastar clientes *Enterprise*.

Surgiu a necessidade de migrar para um modelo *Database-per-Tenant*, onde os dados de clientes diferentes não se tocam fisicamente.

---

# 2. Decision Statement

A aplicação migrará sua estratégia de persistência para **Single Database-per-Tenant**.

Para cada novo escritório contábil (Tenant), será criado **1 único banco de dados PostgreSQL dedicado** (ex: `saas_contabilidadexyz`), que conterá todas as tabelas de todos os bounded contexts (Fiscal, Certificados, Billing, WhatsApp, etc.).

As aplicações Spring Modulith continuarão mantendo a separação lógica e seus respectivos `EntityManagerFactory`, mas os `DataSource` de todos os contextos serão roteados em tempo de execução (`TenantRoutingDataSource`) para apontar para o mesmo banco e compartilhar o mesmo pool de conexões (HikariCP) desse escritório específico.

---

# 3. Decision Drivers

- **Isolamento Absoluto**: Evitar qualquer possibilidade de vazamento de dados entre inquilinos por falhas no filtro `tenant_id`.
- **Conformidade LGPD Avançada**: Capacidade de deletar instantaneamente os dados de um cliente fazendo `DROP DATABASE`.
- **Uso Otimizado de Recursos**: Ao invés de criar 6 bancos dedicados por escritório (1 por módulo), o que geraria uma explosão de 600 bancos a cada 100 clientes, a abordagem Single DB per Tenant cria 100 bancos a cada 100 clientes, reduzindo conexões HikariCP drasticamente.
- **Backup e Restauração Granular**: A capacidade de realizar `pg_dump` e restaurar dados de um único escritório sem impactar toda a plataforma.

---

# 4. Considered Options

**Option 1: Database-per-Context-per-Tenant (6 bancos por inquilino)**
- Pros: Separação física completa entre módulos (cumpre a restrição purista de microsserviços).
- Cons: Overhead monstruoso no PostgreSQL. 100 inquilinos = 600 bancos, 600 pools de conexão, exaurindo conexões do servidor rapidamente.

**Option 2: Single Database-per-Tenant (1 banco por inquilino contendo todas as tabelas)**
- Pros: Simples de gerenciar. Backup e exclusão são atômicos (`DROP DATABASE`). Número de conexões otimizado (1 Hikari Pool por inquilino).
- Cons: Requer que os módulos do Modulith quebrem parcialmente o isolamento físico no nível do banco, armazenando tabelas juntas (porém mantêm isolamento de código/schema).

**Option 3: Manter Shared Database com Schema-per-Tenant**
- Pros: 1 único banco para toda a aplicação com schemas dinâmicos.
- Cons: Spring e Flyway têm dificuldades com gerenciamento dinâmico de schemas, gerando milhares de schemas lentos de migrar no startup.

---

# 5. Decision Outcome

**Option 2 (Single Database-per-Tenant)** foi selecionada.

A relação custo-benefício de usar 1 banco dedicado por inquilino supera o purismo arquitetural de segregar bounded contexts em discos separados. Para garantir que tabelas de contextos diferentes não tenham colisões no controle de versão do banco, o Flyway manterá tabelas de histórico separadas (ex: `flyway_schema_history_fiscal`, `flyway_schema_history_whatsapp`) dentro desse banco único.

---

# 6. Consequences

**Positive Consequences:**
- `DROP DATABASE saas_<nome>` exclui definitivamente os dados do cliente (100% LGPD compliance automático).
- Redução na complexidade das queries (tabelas muito menores que as compartilhadas globais).
- Possibilidade de alocar um DataSource de leitura/réplica dedicado apenas para escritórios muito grandes.

**Negative Consequences:**
- A aplicação terá que manter em memória um pool de conexão `HikariDataSource` ativo para cada tenant logado (o que consumirá RAM e conexões no DB host).
- A longo prazo, poderá ser necessário o uso de um pooler como o **PgBouncer** para suportar a escala de milhares de conexões.

**Neutral Consequences:**
- A tabela `tenants` no banco compartilhado (agora renomeado logicamente para `saas_platform`) precisa de colunas `database_slug` e `database_provisioned` para orquestrar o roteamento.

---

# 7. Impact

- **Architecture (partially superseded)**: permanece a inclusão de `AbstractRoutingDataSource`, mas o fallback legado para banco/pool compartilhado deixou de ser normativo. Conforme ADR-0052, workload tenant-aware sem contexto, binding ou geração committed válida falha fechado; operações reais de plataforma usam persistence unit próprio e explícito.
- **DevOps**: Rotina de inicialização de novo cliente (Onboarding) passará a executar comandos administrativos DDL no PostgreSQL (via Java JDBC).
- **Data Architecture**: Cada banco recém-criado executará os 6 scripts do Flyway correspondentes.

---

# 8. Implementation Plan

1. Criar entidade auxiliar para registro em memória dos bancos ativos (`TenantDatabaseRegistry`).
2. Criar `TenantRoutingDataSource` que roteia em tempo real baseado no contexto da Request (extraindo do JWT).
3. Alterar os `*DataSourceConfig.java` para injetarem a camada de roteamento ao invés da configuração estática.
4. Desenvolver o Caso de Uso `TenantOnboardingUseCase` para executar CREATE DATABASE, configurar Permissões, e disparar as Migrations do Flyway programaticamente para um novo Inquilino.

---

# 9. Related ADRs

- [ADR-0052 - Pools de conexão exclusivos e configuráveis por tenant](ADR-0052-parametros-pool-conexao-por-tenant.md) — substitui somente o fallback legado do §7; preserva um banco e um pool por tenant.

---

# 10. Decision Lifecycle

Current State: **Partially Superseded**

Em 2026-08-27, o ADR-0052 substituiu exclusivamente a cláusula de fallback legado
do §7. A topologia Single Database-per-Tenant, o pool único compartilhado apenas
pelos contextos do mesmo tenant, o onboarding e todas as demais decisões deste ADR
permanecem vigentes.

---

# 11. Change Log

| Version | Date | Author | Changes |
| --- | --- | --- | --- |
| 1.0 | 2026-07-24 | @MultiTenantEng | Criação e aceite da estratégia Single Database-per-Tenant. |
| 1.1 | 2026-08-27 | Codex (OpenAI), sob aprovação humana explícita | Marca supersessão parcial somente do fallback legado do §7 pelo ADR-0052 e preserva todo o restante da decisão. |
