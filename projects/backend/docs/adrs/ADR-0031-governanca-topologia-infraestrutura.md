---
document_id: "ADR-0031"
primary_nature: "Decisao"
objective: "Materializar a decisão aprovada no Gate 0 sobre nome, função, descoberta, ownership e evolução incremental do pacote operacional `infra/`."
scope: "`infra/`, arquivos Compose e Dockerfiles da raiz, workflows relacionados, fontes documentais e adaptadores de instrução usados para descobrir essa fronteira."
non_objectives: "Definir ferramenta ou arquitetura IaC alvo, backend de state, módulos declarativos, modelo de ambientes, importação brownfield ou executar qualquer mudança operacional."
owner: "Arquitetura e DevOps"
status: "Accepted"
date: "2026-08-23"
version: "1.0"
keywords: "infraestrutura, governança, topologia, infra, IaC, ownership, gate humano, agentes, provisionamento"
related_files: "README.md, ../../../docs/specs/TP-00014-infrastructure-governance-stage-zero.md, ../../../docs/specs/TP-00015-infrastructure-as-is-gap-analysis.md, ADR-0016-infrastructure-environment-provisioning.md"
code_references: "infra/`, `docker-compose.yml`, `docker-compose.override.yml`, `docker-compose.hml.yml`, `docker-compose.prd.yml`, `.github/workflows/`, `app/Dockerfile`, `frontend/Dockerfile`, `docker-compose.dev-bot-image.yml"
principal_statement: "`infra/` permanece o pacote operacional umbrella canônico e evolui incrementalmente, mediante inventário AS-IS, fontes de verdade explícitas e gates humanos, sem rename imediato nem alegação de IaC completo."
---

# ADR-0031 - Governança e topologia do pacote de infraestrutura

- Document ID: `ADR-0031`
- Primary Nature: `Decisao`
- Objective: Materializar a decisão aprovada no Gate 0 sobre nome, função, descoberta, ownership e evolução incremental do pacote operacional `infra/`.
- Scope: `infra/`, arquivos Compose e Dockerfiles da raiz, workflows relacionados, fontes documentais e adaptadores de instrução usados para descobrir essa fronteira.
- Non-objectives: Definir ferramenta ou arquitetura IaC alvo, backend de state, módulos declarativos, modelo de ambientes, importação brownfield ou executar qualquer mudança operacional.
- Keywords: infraestrutura, governança, topologia, infra, IaC, ownership, gate humano, agentes, provisionamento
- Related Files: `../../../docs/specs/TP-00014-infrastructure-governance-stage-zero.md`, `../../../docs/specs/TP-00015-infrastructure-as-is-gap-analysis.md`, `artefatos de análise/ANL-00042-infrastructure-as-is-iac-gap-analysis.md`, `docs/architecture/module-registry.md`, `infra/README.md`, `infra/AGENTS.md`, `infra/CLAUDE.md`, `ADR-0016-infrastructure-environment-provisioning.md`
- Code References: `infra/`, `docker-compose.yml`, `docker-compose.override.yml`, `docker-compose.hml.yml`, `docker-compose.prd.yml`, `.github/workflows/`, `app/Dockerfile`, `frontend/Dockerfile`, `infra/docker/dev-bot/Dockerfile`
- Principal Decision: `infra/` permanece o pacote operacional umbrella canônico e evolui incrementalmente, mediante inventário AS-IS, fontes de verdade explícitas e gates humanos, sem rename imediato nem alegação de IaC completo.
- Date: 2026-08-23
- Status: Accepted
- Version: 1.0
- Authors / Owners: Arquitetura e DevOps
- Reviewers: Maintainer Humano de Infraestrutura, com aprovação explícita do Gate 0 em 2026-08-23
- Stakeholders: Engenharia, DevOps, Arquitetura, Segurança, Dados, Observabilidade e responsáveis pela operação da plataforma
- Supersedes: N/A; especializa a governança do ADR-0016 sem substituir seus trechos ainda vigentes nem reativar procedimentos superseded.
- Superseded by: N/A

---

# 1. Context

O monorepo já possuía um diretório raiz `infra/` com Compose, configurações,
scripts, bootstrap, deploy, backup, proxy, IAM e observabilidade. A presença desses
artefatos não provava, porém, que o ambiente SaaS fosse integralmente reproduzível
como IaC, nem tornava explícitos ownership, state, drift, fontes de verdade e gates
de mudança.

Renomear o diretório para `iac/` antes desse diagnóstico misturaria uma escolha de
nomenclatura com uma alegação de maturidade técnica. Também criaria churn em
Compose, workflows, scripts, runbooks e rotas operacionais antes de conhecer seus
consumidores e estados externos.

O [TP-00014](../../../docs/specs/TP-00014-infrastructure-governance-stage-zero.md)
estabeleceu o marco zero, e o Maintainer Humano de Infraestrutura registrou
explicitamente “Gate 0 aprovado” em 2026-08-23. Esta ADR promove as decisões
normativas desse gate à fonte canônica apropriada.

---

# 2. Decision Statement

## 2.1 Nome e função canônicos

1. `infra/` permanece o pacote operacional umbrella canônico do monorepo.
2. O nome não significa que todo o conteúdo seja IaC declarativo.
3. O diretório não deve ser confundido com o módulo Java `infrastructure` do
   backend.
4. Não será criado diretório raiz `iac/`, nem executado rename ou movimento dos
   artefatos atuais sem decisão sucessora, análise de consumidores, plano de
   migração e gate humano.
5. Uma futura subárvore declarativa, caso aprovada, poderá ser organizada dentro
   de `infra/`; seu nome e layout continuam abertos até a decisão de arquitetura
   IaC alvo.

## 2.2 Descoberta e fontes de verdade

Os entrypoints canônicos são:

- [`infra/README.md`](../../infra/README.md), para catálogo e contexto;
- [`infra/AGENTS.md`](../../infra/AGENTS.md), para especialização operacional do
  Codex;
- [`infra/CLAUDE.md`](../../infra/CLAUDE.md), para carregar a mesma especialização
  no Claude Code;
- [manifesto de módulos e pacotes](../architecture/module-registry.md), para a
  topologia canônica do monorepo;
- esta ADR, para a decisão normativa;
- planos, análises e runbooks tipados, para coordenação, diagnóstico e execução
  respectivamente.

README, plano, análise ou instrução de agente não substituem ADR, requisito,
standard ou runbook. Uma conclusão normativa descoberta em análise deve ser
promovida à coleção canônica antes de orientar implementação.

## 2.3 Ownership e aprovação

- **Maintainer Humano de Infraestrutura:** decide escopo e aprova o gate final de
  cada etapa.
- **Arquitetura:** preserva topologia, fronteiras, precedência documental e
  decisões.
- **DevOps:** responde por automações, configuração operacional, evidências e
  runbooks.
- **Segurança:** revisa rede, TLS, IAM, SSH, secrets e permissões.
- **Dados:** revisa bancos, volumes, backup, restore e mudanças stateful.
- **Agentes de IA:** inventariam, propõem patches pequenos e produzem evidência;
  não aprovam gates nem ampliam autorização implicitamente.

O ocupante do papel humano fica identificado na revisão corrente ou no PR, sem
gravar nome pessoal durável na decisão.

## 2.4 Evolução incremental

A evolução seguirá etapas pequenas, cada uma com plano persistido, resultado
revisável e gate humano:

1. **Gate 0 — governança e descoberta:** concluído pelo TP-00014.
2. **Gate 1 — inventário AS-IS e gaps:** autorizado somente para leitura do
   repositório e produção de diagnóstico.
3. **Etapas posteriores:** podem decidir escopo IaC, ferramenta, state, secrets,
   brownfield, layout e automação somente após o Gate 1.

A aprovação de uma etapa não aprova a seguinte, salvo autorização humana expressa
e limitada ao novo escopo.

## 2.5 Fronteira de execução

Esta decisão não autoriza `plan`, `apply`, deploy, provisionamento, restore, reset,
rotação, acesso a HML/produção, consulta a provider, leitura de secrets, importação
de state ou alteração de recurso externo. Essas ações exigem plano próprio,
ambiente e efeito identificados, evidências proporcionais e autorização humana.

---

# 3. Decision Drivers

- evitar rename sem benefício operacional comprovado;
- separar pacote operacional de uma alegação de IaC completa;
- tornar a fronteira encontrável por pessoas e agentes;
- preservar fontes de verdade e reduzir decisões escondidas em scripts;
- permitir revisão incremental do legado brownfield;
- manter Segurança e Dados como gates por impacto;
- impedir que documentação seja interpretada como autorização de ambiente.

---

# 4. Considered Options

## Option A: Renomear imediatamente `infra/` para `iac/`

Pros:

- nome familiar para artefatos declarativos;
- sinalização visual da intenção futura.

Cons:

- afirma uma maturidade ainda não comprovada;
- exige migração transversal de paths e consumidores;
- não resolve ownership, state, drift, secrets ou procedimentos manuais;
- mistura automação operacional e IaC sob um rótulo impreciso.

## Option B: Manter `infra/` sem governança formal

Pros:

- nenhuma mudança documental imediata;
- preserva paths existentes.

Cons:

- agentes e humanos continuam sem entrypoint e ownership claros;
- scripts e runbooks podem ser confundidos com fontes declarativas;
- decisões e gaps permanecem implícitos.

## Option C: Manter `infra/` como umbrella governado e decidir IaC após inventário

Pros:

- preserva compatibilidade e reduz churn;
- distingue fatos AS-IS de arquitetura alvo;
- cria ownership, rastreabilidade e gates antes de mudanças stateful;
- permite incluir futura IaC sem expulsar scripts, runbooks e configuração.

Cons:

- mantém temporariamente um pacote heterogêneo;
- exige disciplina documental e revisão humana por etapa;
- adia a escolha de ferramenta e layout declarativo.

---

# 5. Decision Outcome

A **Option C** foi aceita.

O benefício imediato está na governança e na visibilidade, não em um rename. O
inventário AS-IS deve primeiro determinar quais recursos são declarativos,
imperativos, manuais, externos ou provisionados pelo runtime. Somente então uma
decisão sucessora poderá escolher a arquitetura IaC e seu layout.

---

# 6. Consequences

## Positive Consequences

- `infra/` possui identidade, owners e entrypoints canônicos.
- Agentes carregam regras locais antes de tocar a fronteira operacional.
- Rename, ferramenta e state deixam de ser decisões acidentais.
- Gaps podem ser priorizados sem acessar ambientes reais.

## Negative Consequences

- A heterogeneidade atual permanece visível até etapas posteriores.
- Cada avanço exige manutenção do tracker e revisão humana.
- A decisão não entrega reprodutibilidade de provider ou host por si só.

## Neutral Consequences

- Compose, scripts, workflows e runbooks continuam nos paths atuais.
- O ADR-0016 permanece histórico e parcialmente vigente conforme seu próprio
  cabeçalho; procedimentos marcados superseded continuam não executáveis.

---

# 7. Impact

| Área | Efeito da decisão |
| --- | --- |
| Topologia | `infra/` integra explicitamente o manifesto do monorepo. |
| Documentação | ADR decide; README cataloga; TP coordena; análise diagnostica; runbook executa. |
| DevOps | Mudanças devem declarar owner, ambiente, estado afetado, validação e rollback aplicável. |
| Segurança | Rede, TLS, IAM, SSH, secrets e providers mantêm gate específico. |
| Dados | Banco, volume, backup, restore e stateful upgrade mantêm gate específico. |
| Agentes | Instrução raiz é combinada com `infra/AGENTS.md`; o gate humano não pode ser autoaprovado. |

---

# 8. AI Agent Considerations

Agentes DEVEM:

- iniciar pela topologia e pelos entrypoints locais;
- distinguir evidência observada, declaração documental e estado externo não
  verificado;
- preservar alterações concorrentes e limitar patches a um incremento;
- produzir handoff com comandos, resultados, skips, riscos e gate pendente.

Agentes NÃO DEVEM:

- tratar todo `infra/` como IaC;
- criar `iac/`, escolher ferramenta ou mover paths a partir desta ADR;
- ler `.env`, `.deploy/`, `.dev-secrets/`, chaves, dumps ou backups reais;
- executar operação externa como consequência de análise ou documentação;
- promover inferência da análise a decisão sem ADR ou fonte equivalente.

---

# 9. Implementation Plan

1. Concluir o TP-00014 e publicar esta decisão.
2. Executar o TP-00015 e a ANL-00042 em modo documental e read-only.
3. Submeter inventário, gaps e perguntas abertas ao Gate 1 humano.
4. Criar ADR sucessora para arquitetura IaC alvo somente após o Gate 1.
5. Criar plano de implementação separado antes de qualquer configuração,
   migração brownfield ou operação de ambiente.

Rollback deste incremento documental consiste em superseder esta ADR por nova
decisão; não há rollback operacional porque nenhum recurso é alterado.

---

# 10. Validation

- `infra/` aparece no manifesto com links para catálogo e adaptadores.
- TP-00014 registra a aprovação humana e termina como `Completed`.
- Esta ADR possui entrada individual no índice semântico.
- TP-00015 e ANL-00042 mantêm ferramenta, ambiente e execução fora do escopo.
- O validador documental e os checks focados passam, ou falhas externas ao
  incremento ficam isoladas com evidência.

---

# 11. Risks and Mitigations

| Risco | Mitigação |
| --- | --- |
| O freeze virar inércia permanente | Tracker por etapa, owner e próximo gate explícitos. |
| README ou análise criar regra silenciosa | Promover decisões normativas a ADR antes de implementar. |
| Agente interpretar script como autorização | Instrução local e gate humano por ambiente/efeito. |
| Novo layout quebrar consumidores ocultos | Inventário e plano de migração antes de qualquer movimento. |
| Ferramenta ser escolhida por preferência | Exigir gaps, critérios, state, brownfield e operação como drivers documentados. |

---

# 12. Related ADRs

- [ADR-0000 — Governança documental e agentes de IA](../../harness/governance/decisions/ADR-0000-governanca-do-harness-documental.md)
- [ADR-0001 — Technology Stack and Architecture Foundation](ADR-0001-technology-stack-and-architecture.md)
- [ADR-0016 — Infrastructure Environment Provisioning](ADR-0016-infrastructure-environment-provisioning.md)
- [ADR-0018 — Keycloak Realm Provisioning Automation](ADR-0018-keycloak-realm-provisioning-automation.md)
- [ADR-0019 — Single Database-per-Tenant](ADR-0019-database-per-tenant.md)

---

# 13. References

- [TP-00014 — Marco zero](../../../docs/specs/TP-00014-infrastructure-governance-stage-zero.md)
- [TP-00015 — Inventário AS-IS/gap](../../../docs/specs/TP-00015-infrastructure-as-is-gap-analysis.md)
- ANL-00042 — Inventário AS-IS e gaps
- [Catálogo de infraestrutura](../../infra/README.md)
- [Manifesto de módulos e pacotes](../architecture/module-registry.md)

---

# 14. Decision Lifecycle

`Accepted`. O aceite humano “Gate 0 aprovado” materializa somente esta decisão e
o encerramento do TP-00014. Gate 1, arquitetura IaC alvo e execução posterior não
estão aprovados por esta ADR.

---

# 15. Change Log

| Version | Date | Owner | Change |
| --- | --- | --- | --- |
| 1.0 | 2026-08-23 | Arquitetura e DevOps | Materializa as decisões aceitas no Gate 0 sobre topologia, ownership, descoberta e evolução incremental de `infra/`. |
