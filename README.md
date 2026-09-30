---
document_id: HARNESS-README
primary_nature: Contexto
objective: Disponibilizar um harness documental agnóstico, clonável e adaptável a projetos de software.
scope: Governança documental, descoberta progressiva, planejamento, readiness, assurance e adaptadores de agentes.
non_objectives: Não fornecer código de produto, stack, domínio, credenciais ou decisões do projeto de origem. O tooling determinístico do próprio harness (tooling/) é a única exceção executável.
owner: Mantenedores do harness
status: Active
version: 2.0.0
date: 2026-09-10
last_reviewed: 2026-09-30
keywords: harness, documentacao, agentes, orquestrador, standards, clear, readiness, quality-gate, security-gate, security, appsec, entrega-git, gemini, antigravity, registry, contracts, evals, tooling
related_files: AGENTS.md, CLAUDE.md, GEMINI.md, backend/README.md, frontend/README.md, website/README.md, infra/README.md, docs/README.md, docs/scripts/README.md, docs/agents/AgentOrchestrator.md, docs/agents/standards/README.md, docs/agents/skills/README.md, docs/settings/settings.md, docs/settings/google-gemini.md, docs/adrs/ADR-0000-governanca-do-harness-documental.md, registry/README.md, contracts/README.md, skills/README.md, evals/README.md, tooling/README.md, adapters/README.md, examples/profiles/java-spring.yaml, examples/profiles/node-web.yaml, examples/profiles/python-service.yaml
code_references: .agents/rules/documentation-governance.md, .agents/skills/, .claude/skills/, registry/, contracts/, skills/, evals/, tooling/, adapters/, examples/; pacote agnóstico com control plane documental e tooling determinístico opcional.
principal_statement: O pacote fornece as fontes e os contratos necessários para adotar a mesma governança sem transportar contexto de produto ou de stack.
---

# Harness de engenharia de IA agnóstico

Este diretório é um pacote independente, pronto para se tornar um repositório Git
próprio. Ele preserva a lógica de governança do harness: fontes de verdade tipadas,
descoberta progressiva, gates antes e depois da implementação, instruções enxutas
para agentes e rastreabilidade do problema até a evidência final.

O harness é agnóstico de stack e de provedor de IA, combinando governança documental
normativa com tooling determinístico opcional em `tooling/` e `docs/scripts/` para
prevenção de drift, validação de contratos e evals de confiabilidade.

## O que está incluído

- adaptadores globais para Codex, Claude Code e Gemini CLI, mais regra de
  workspace para Google Antigravity;
- registry machine-readable (`registry/`) como fonte única de verdade para inventário,
  ativação, metadados e ferramentas;
- contratos formais JSON Schema (`contracts/`) para requisições, readiness, evidências,
  gates e findings;
- fonte canônica única de skills (`skills/`) estruturada em capability packages,
  com sincronização determinística para os caminhos de runtime `.agents/` e `.claude/`;
- `security-gate` como subgate/executor especializado de segurança de aplicação para
  A3, subordinado ao `quality-gate` e sem criar um Assurance Gate paralelo;
- skill `git-delivery` opt-in com side effects explicitamente governados;
- skill `antigravity-permissions` para controle de permissões no escopo de projeto;
- suíte de evals do harness completo (`evals/`) cobrindo lifecycle, orquestração,
  permissões, portabilidade cross-runtime e regressão;
- tooling determinístico portátil (`tooling/`) com `harness doctor` para diagnóstico
  unificado;
- ADR de governança estrutural e mapa de precedência;
- `AgentOrchestrator` como único agente orquestrador do bootstrap;
  [`GateEvaluator`](docs/agents/GateEvaluator.md) como subagente de assurance;
- biblioteca portátil de standards transversais e catálogo de exemplos condicionais
  por capacidade ou stack;
- lifecycle C.L.E.A.R.;
- Implementation Readiness Gate e Test, Quality e Security/Compliance Gates;
- estrutura base de coleções e índices;
- pastas base de backend, frontend, website, infraestrutura e documentação;
- templates para os artefatos recorrentes;
- extensão `docs/scripts/` com validadores determinísticos de conformidade;
- perfis de exemplo de projeto adotante em [`examples/profiles/`](examples/profiles/java-spring.yaml) (Java/Spring, Node.js e Python).

### Distinção entre contratos de harness e contratos de produto

Para evitar ambiguidades estruturais:
- `contracts/` (raiz): schemas JSON formais que regem a engenharia do harness (mensagens, gates, evidências, handoffs e manifestos de projeto);
- `docs/contracts/`: coleção documental para catalogar interfaces de negócio/técnicas do produto final (especificações OpenAPI, eventos AsyncAPI).

## Adoção em outro projeto

### Identidade do projeto adotante

Faça esta adaptação quando este conteúdo deixar de ser apenas o repositório-fonte
`ai-design-docs` e passar a compor um projeto ou repositório de destino. Antes do
primeiro commit de adoção:

- Atualize o título e os metadados deste `README.md` para descrever o projeto
  adotante, com objetivo, escopo, owner e links reais do destino.
- Procure referências ao repositório-fonte e substitua somente nomes, URLs e
  instruções que realmente identifiquem a origem. Não faça substituição global:
  nomes de coleções, paths canônicos, IDs de templates e conceitos do harness
  permanecem quando continuarem aplicáveis.
- Mantenha, renomeie ou remova os scaffolds conforme a topologia adotante e
  reconcilie links, índices, manifesto e adaptadores na mesma mudança.
- Antes de qualquer push, confira que o remote e a branch de trabalho apontam para
  o repositório de destino, nunca para o remoto-fonte nem para a branch principal.

1. Copie todo o conteúdo deste diretório, incluindo `.agents/` e `.claude/`, para a
   raiz do projeto de destino. Em um repositório dedicado, clone-o e copie ou faça
   merge somente dos paths documentais desejados.
2. Preserve arquivos já existentes. Compare a árvore de destino com
   [`docs/architecture/module-registry.md`](docs/architecture/module-registry.md) e
   aplique somente o delta aditivo e reversível.
3. Registre módulos, owners, comandos e pontos de entrada reais no manifesto. Não
   invente informação ausente.
4. Mantenha, renomeie ou remova os scaffolds [backend](backend/README.md),
   [frontend](frontend/README.md), [website](website/README.md) e
   [infra](infra/README.md) conforme a topologia real, atualizando o manifesto e
   este índice na mesma mudança.
5. Preserve o [AgentOrchestrator](docs/agents/AgentOrchestrator.md) como único
   agente inicial. Crie agentes adicionais somente quando houver responsabilidade,
   autoridade e handoff independentes.
6. Ative somente as coleções necessárias. Cada coleção ativa precisa de `README.md`,
   owner, convenção de nomes, estados e inventário completo.
7. Selecione no [catálogo portátil](docs/agents/standards/README.md) o núcleo
   agnóstico e apenas os standards condicionais compatíveis com a stack e o risco
   registrados; não copie capacidades sem correspondente no projeto adotante.
8. Crie os primeiros artefatos pelos templates de [`docs/templates/`](docs/templates/README.md).
9. Configure no projeto de destino os validadores e comandos descritos em
   [`docs/automation/README.md`](docs/automation/README.md). Enquanto eles não
   existirem, reporte `Automação não configurada`; não declare um gate automático
   como aprovado por inspeção subjetiva.
10. Revise `AGENTS.md`, `CLAUDE.md`, `GEMINI.md` e a regra Antigravity; os
   adaptadores importam `AGENTS.md` (o doctor verifica o import) — não insira regras de stack que pertençam a um pacote específico.
11. Se usar Antigravity, configure a regra de workspace como `Always On`, habilite o
   sandbox e confira permissões conforme
   [`docs/settings/google-gemini.md`](docs/settings/google-gemini.md). Se usar
   Gemini CLI, confirme contexto e skills com `/memory` e `/skills`.
12. Execute `node tooling/harness-doctor/index.mjs` para validar a integridade estrutural
   do bootstrap. A execução deve produzir diagnóstico verde sem erros.
13. Se adotar entrega Git governada, aceite a política local, implemente e teste o
   hook/validador, atualize os adaptadores e só então habilite `git-delivery`.

## Fluxo C.L.E.A.R.

| Estágio | Resultado esperado |
| --- | --- |
| **C — Context** | Problema, público, resultado e comportamento estão definidos e aprovados. |
| **L — Logic & Layout** | Decisões, arquitetura, fluxos e plano atômico estão prontos; o IRG termina em `READY`. |
| **E — Execution** | A implementação ocorre somente no escopo, versão e paths auditados. |
| **A — Assurance** | A1 Test, A2 Quality e A3 Security/Compliance têm resultados independentes; `security-gate` executa a verificação especializada que compõe a evidência de A3. |
| **R — Release** | Entrega e verificação seguem autorização e procedimentos próprios do projeto. |

## Árvore distribuída

```text
AGENTS.md
CLAUDE.md
GEMINI.md
registry/{README.md,harness.yaml,skills.yaml,standards.yaml,runtimes.yaml,tooling.yaml}
contracts/{README.md,*.schema.json}
skills/{governanca-documental,implementation-readiness,quality-gate,security-gate,git-delivery,antigravity-permissions}/
evals/{README.md,schema/,lifecycle/,orchestration/,permissions/,portability/,regression/}
tooling/{README.md,harness-doctor/,adapters/,contracts/,eval-runner/,hooks/}
adapters/{README.md,core-policy.md}
examples/profiles/{java-spring.yaml,node-web.yaml,python-service.yaml}
.agents/rules/documentation-governance.md
.agents/skills/{governanca-documental,implementation-readiness,quality-gate,security-gate,git-delivery,antigravity-permissions}/SKILL.md
.claude/agents/GateEvaluator.md
.claude/skills/{governanca-documental,implementation-readiness,quality-gate,security-gate,git-delivery,antigravity-permissions}/SKILL.md
backend/README.md
frontend/README.md
website/README.md
infra/README.md
docs/
  README.md
  scripts/{README.md,validate-*.mjs,validate-*.test.mjs}
  ai/README.md
  adrs/{README.md,ADR-0000-governanca-do-harness-documental.md}
  architecture/{README.md,module-registry.md}
  settings/{README.md,settings.md}
  agents/{README.md,AgentOrchestrator.md,GateEvaluator.md,skills/README.md,standards/...}
  templates/{README.md,TPL-*.md}
  automation/README.md
  <colecoes de produto e historico>/README.md
```

## Limites de portabilidade

- Os limiares de cobertura, comandos de teste, nomes de módulos e regras de release
  pertencem ao projeto de destino.
- Os standards de tecnologia permanecem disponíveis, mas inativos até serem
  selecionados por ADR, manifesto, contrato, escopo ou risco. A cópia adotada é a
  referência canônica local e não depende deste repositório de origem.
- As quatro pastas de aplicação/infraestrutura são scaffolds base, não afirmações
  de que todo projeto precisa desses quatro módulos. Remoção ou renomeação durante
  a adoção deve reconciliar o mapa e o manifesto.
- Codex, Claude Code, Gemini CLI e Antigravity são opcionais. `.agents/skills/` é
  compartilhado por Codex e Google; remova um adapter ou variante de skill apenas
  se nenhum runtime consumidor permanecer, atualizando o catálogo na mesma mudança.
- O pacote não escolhe licença. Antes de publicar um repositório público, o owner
  deve adicionar uma licença compatível com o uso pretendido.
- Este diretório não executa `git push`, cria repositório remoto nem publica no
  GitHub. A skill distribuída só descreve o contrato para o projeto adotante; push
  exige destino, política, enforcement e autorização próprios.

## Change log

| Versão | Data | Mudança |
| --- | --- | --- |
| 2.0.0 | 2026-09-28 | Atualiza a arquitetura para harness de engenharia agnóstico (registry, contracts, canonical skills, evals e harness doctor). |
| 1.7 | 2026-09-28 | Adiciona `security-gate` como executor especializado subordinado ao A3 do `quality-gate` e atualiza a árvore do harness. |
| 1.6 | 2026-09-28 | Adiciona revisão especializada e standards de Application, API e Spring Security integrados ao A3 do quality-gate. |
| 1.5 | 2026-09-23 | Explicita quando e como adaptar identidade, referências e remoto ao adotar o harness. |
| 1.4 | 2026-09-13 | Mapeia os scripts migrados como extensão condicional, sem declarar automação portátil ativa. |
| 1.3 | 2026-09-13 | Inclui a capacidade opt-in `git-delivery` sem transportar scripts nem permissões do projeto de origem. |
| 1.2 | 2026-09-11 | Inclui AgentOrchestrator como único agente inicial e a biblioteca portátil de standards com ativação condicional. |
| 1.1 | 2026-09-11 | Adiciona suporte portátil a Gemini CLI e Antigravity e sua verificação de adoção. |
