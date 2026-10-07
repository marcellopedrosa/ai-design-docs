---
document_id: TP-00058
primary_nature: Plano
objective: Integrar Google Gemini CLI e Google Antigravity ao harness documental agnostico e a governanca executavel deste monorepo.
scope: Adaptadores GEMINI.md, regra de workspace Antigravity, settings de runtime, ADR-0000, mapas, catalogos, manifesto, validadores e testes documentais no harness ai-design-docs e no repositorio atual.
non_objectives: Nao instalar ou configurar runtimes no host, alterar preferencia global em ~/.gemini, acessar servicos Google, mudar comportamento do produto ou publicar Git.
owner: Arquitetura e Plataforma de IA
status: Completed
version: 1.3
date: 2026-09-11
last_reviewed: 2026-09-11
keywords: gemini, google-antigravity, harness, adaptadores, skills, governanca-documental
related_files: harness/governance/decisions/ADR-0000-governanca-do-harness-documental.md, harness/governance/project-settings/README.md, harness/governance/project-settings/settings.md, do../../agents/skills/README.md, do../../agents/standards/implementation-readiness-standard.md
code_references: GEMINI.md, .agents/rules/documentation-governance.md, backend/GEMINI.md, frontend/GEMINI.md, website/GEMINI.md, infra/GEMINI.md, validate-google-runtime-governance.mjs, validate-google-runtime-governance.test.mjs, validate-quality-policy.mjs, validate-quality-policy.test.mjs, infra/scripts/validate-docs.sh, ai-design-docs/GEMINI.md, ai-design-docs/.agents/rules/documentation-governance.md
principal_statement: A mesma politica agnostica deve chegar aos runtimes Google por adaptadores nativos pequenos, sem triplicar skills nem versionar configuracao pessoal.
---

# TP-00058 — Governança documental para Google Gemini e Antigravity

## Fontes e decisão técnica

- [ADR-0000](../../../harness/governance/decisions/ADR-0000-governanca-do-harness-documental.md) `Accepted`
  v4.20 e [Implementation Readiness Standard](../../agents/standards/implementation-readiness-standard.md)
  `Active` v1.6.
- [Google Antigravity Agent Settings](https://antigravity.google/docs/agent-settings/),
  [Rules](https://antigravity.google/docs/rules-workflows),
  [Skills](https://antigravity.google/docs/skills/),
  [Permissions](https://antigravity.google/docs/permissions/),
  [Sandbox](https://antigravity.google/docs/sandbox/) e
  [Projects](https://antigravity.google/docs/projects/), consultados em
  2026-09-11.
- [Gemini CLI project context](https://geminicli.com/docs/cli/gemini-md/) e
  [Agent Skills](https://geminicli.com/docs/cli/skills/), consultados em
  2026-09-11.

As fontes oficiais distinguem dois mecanismos: Gemini CLI usa `GEMINI.md`
hierárquico e imports `@file`; Antigravity usa regras de workspace em
`.agents/rules/`. Ambos reconhecem skills do workspace em `.agents/skills/`, de
modo que essa árvore compartilhada é reutilizada e não recebe uma terceira cópia.
Preferências, permissões e settings globais sob `~/.gemini/` permanecem pessoais e
fora do repositório.

## Granularidade e sequência

O pedido possui dois resultados independentemente adotáveis e reversíveis. O pai
coordena os filhos abaixo, sem tratá-los como uma única entrega artificial:

| Filho | Resultado observável | Dependência | Estado |
| --- | --- | --- | --- |
| `TP-00058-T01` | O pacote `ai-design-docs` documenta e entrega adaptadores Google portáveis. | Fontes oficiais Google. | Completed |
| `TP-00058-T02` | O monorepo atual aplica e valida os mesmos adaptadores em toda a sua topologia. | `TP-00058-T01` como padrão reutilizado. | Completed |

## TP-00058-T01 — Harness portável

| Campo | Contrato |
| --- | --- |
| **What** | Tornar o harness clonável compatível com Gemini CLI e Antigravity, preservando uma única política agnóstica. |
| **Where** | `ai-design-docs/GEMINI.md`, `ai-design-docs/.agents/rules/documentation-governance.md`, `ai-design-docs/README.md`, `ai-design-docs/AGENTS.md`, `ai-design-docs/CLAUDE.md`, `ai-design-docs/docs/README.md`, `ai-design-docs/do../../ai/README.md`, `ai-design-docs/docs/adrs/README.md`, `ai-design-docs/harness/governance/decisions/ADR-0000-governanca-do-harness-documental.md`, `ai-design-docs/harness/governance/project-settings/README.md`, `ai-design-docs/harness/governance/project-settings/settings.md`, `ai-design-docs/harness/governance/project-settings/google-gemini.md`, `ai-design-docs/do../../agents/skills/README.md` e `ai-design-docs/docs/automation/README.md`. |
| **Depends on** | Documentação oficial Google listada nas fontes. |
| **Reuses** | `ai-design-docs/AGENTS.md` como política operacional canônica; `.agents/skills/` como caminho interoperável. |
| **Requirements** | ADR-0000 do harness `Accepted` v1.1 e contrato dos índices imediatos. |

### Gate Audit

| Controle | Evidência | Resultado |
| --- | --- | --- |
| Product Definition | `PRD not applicable`: a mudança só adiciona mapeamento de runtime, sem público, valor, métrica ou comportamento do produto. | N/A |
| Fontes superiores | ADR-0000 do harness está `Accepted`; documentação oficial identifica paths e limites. | PASS |
| User Story / Use Case / API | `N/A`: não há interação funcional nem API HTTP. | N/A |
| Assumptions / Open Questions | Nenhuma: a distinção Gemini CLI versus Antigravity e o reuso de `.agents/skills/` estão documentados pelas fontes oficiais. | PASS |
| Dependências | Todos os artefatos do harness existem; skills pareadas atuais são idênticas. | PASS |
| Granularidade / Decomposição | Um resultado portátil e um handoff; separado do rollout local em `T02`. | PASS |

### Acceptance Tests

- Todos os links relativos do harness resolvem.
- Todos os documentos em `ai-design-docs/docs/` mantêm o contrato mínimo.
- As três skills em `.agents/skills/` permanecem idênticas às variantes Claude.
- A busca por termos do produto de origem continua vazia fora de exemplos e
  scaffolds explicitamente agnósticos.

### Prohibited

- Não criar `.gemini/skills/` duplicando `.agents/skills/`.
- Não versionar `~/.gemini/`, settings pessoais, credenciais ou project IDs.
- Não afirmar que uma preferência da UI Antigravity é validável pelo repositório.

### Mandatory

- Diferenciar `GEMINI.md` do Gemini CLI e `.agents/rules/` do Antigravity.
- Manter adapters pequenos por import e registrar a ativação `Always On` como
  verificação de sessão, não como estado falsamente comprovado no Git.
- Atualizar todo índice imediato afetado.

### Definition of Done

- [x] Adaptadores Google existem e reutilizam `AGENTS.md` sem copiar a política.
- [x] ADR, mapa, settings, catálogo de skills e guia de adoção incluem Google.
- [x] Auditoria manual do harness termina sem metadado, link, índice ou paridade quebrados.

### Result

`READY` reexecutado em 2026-09-11 por `@AgentOrchestrator using
implementation-readiness`, para o ADR do harness v1.1 e os paths acima; blockers:
`N/A`.

## TP-00058-T02 — Aplicação no monorepo atual

| Campo | Contrato |
| --- | --- |
| **What** | Tornar a governança Google descobrível, equivalente e fail-closed no monorepo e em seus quatro pacotes especializados. |
| **Where** | `GEMINI.md`, `.agents/rules/documentation-governance.md`, `backend/GEMINI.md`, `frontend/GEMINI.md`, `website/GEMINI.md`, `infra/GEMINI.md`, `docs/README.md`, `do../../ai/README.md`, `docs/adrs/README.md`, `harness/governance/decisions/ADR-0000-governanca-do-harness-documental.md`, `docs/architecture/module-registry.md`, `harness/governance/project-settings/README.md`, `harness/governance/project-settings/settings.md`, `harness/governance/project-settings/google-gemini.md`, `do../../agents/skills/README.md`, `README.md`, `validate-google-runtime-governance.mjs`, `validate-google-runtime-governance.test.mjs`, `validate-quality-policy.mjs`, `validate-quality-policy.test.mjs`, `infra/scripts/validate-docs.sh`, `TP-00058-google-gemini-antigravity-documentation-governance.md` e `docs/delivery/plans/README.md`. |
| **Depends on** | `TP-00058-T01`; validadores atuais presentes e executáveis localmente. |
| **Reuses** | `AGENTS.md` raiz e locais; `.agents/skills/`; wrapper `./infra/scripts/validate-docs.sh`; padrão validado no harness. |
| **Requirements** | ADR-0000 `Accepted` v4.20, política global v2.5, Implementation Readiness Standard v1.6 e Software Quality Standard v1.3. |

### Gate Audit

| Controle | Evidência | Resultado |
| --- | --- | --- |
| Product Definition | `PRD not applicable`: integração de runtime documental, sem comportamento do produto. | N/A |
| Fontes superiores | ADR-0000 `Accepted`; settings `Active`; documentação oficial Google consultada. | PASS |
| User Story / Use Case / API | `N/A`: nenhuma feature, fluxo ou API HTTP é alterada. | N/A |
| Assumptions / Open Questions | Nenhuma; ativação efetiva de regra e fontes fica como teste de sessão explicitamente manual, sem alegação antecipada. | PASS |
| Dependências | Adaptadores Codex/Claude, skills e validadores existem; nenhuma dependência externa será instalada. | PASS |
| Granularidade / Decomposição | Um resultado local com código de validação e evidência inseparáveis; separado do harness em `T01`. | PASS |

### Acceptance Tests

- Testes Node do validador Google rejeitam ausência/divergência de `GEMINI.md`, regra
  Antigravity, adapters locais e mapeamento de settings Google.
- `bash -n infra/scripts/validate-docs.sh` retorna código `0`.
- `node --test validate-google-runtime-governance.test.mjs` e
  `node --test validate-quality-policy.test.mjs` retornam código `0`.
- `./infra/scripts/validate-docs.sh` retorna código `0` com todos os targets finais.

### Prohibited

- Não tocar em código funcional, `.env*`, credenciais, produção ou sistemas Google.
- Não duplicar as skills em `.gemini/skills/`.
- Não sobrescrever alterações preexistentes em PRDs nem usar Git de escrita.

### Mandatory

- Validar presença, composição e concisão dos novos adaptadores.
- Preservar os modos e permissões mais restritivos definidos pela política global.
- Atualizar versões, changelogs, referências, índices imediatos e manifesto.

### Definition of Done

- [x] Google Gemini CLI e Antigravity estão mapeados no ADR e em settings.
- [x] Adaptadores raiz/pacote e regra de workspace compõem `AGENTS.md`.
- [x] Skills `.agents/skills/` estão catalogadas como compartilhadas com Google.
- [x] Regressões focais e wrapper documental agregado retornam `PASS`.
- [x] Handoff registra a verificação manual pendente em sessão Google nova.

### Result

`READY` reexecutado em 2026-09-11 por `@AgentOrchestrator using
implementation-readiness`, para ADR-0000 v4.20, política global v2.5,
Implementation Readiness Standard v1.6, Software Quality Standard v1.3 e os paths
acima. A responsabilidade Google foi separada do validador geral de 1.730 linhas;
blockers: `N/A`.

## Handoff e evidência

### `TP-00058-T01`

- Auditoria read-only em Node sobre `ai-design-docs/docs/`: `43` Markdown, `24`
  diretórios e `0` erros de contrato mínimo, H1, links ou índices imediatos.
- `cmp -s` entre cada dupla `.agents/skills/<skill>/SKILL.md` e
  `.claude/skills/<skill>/SKILL.md`: `3/3 PASS`.
- Imports e limite: `GEMINI.md` e a regra Antigravity compõem `AGENTS.md`; regra
  com `248` caracteres, abaixo de `12.000`.
- Busca por `duoset`, `saas-service`, `Contador Fiscal Inteligente` e namespace Java
  do produto, fora dos exemplos/scaffolds: zero ocorrências.

### `TP-00058-T02`

- `node --test validate-google-runtime-governance.test.mjs`:
  `PASS`; o validador integrado também retorna `PASS`.
- `node --test validate-quality-policy.test.mjs`: `PASS`; política
  integrada `PASS`.
- `./infra/scripts/validate-docs.sh`: código `0`, incluindo governança geral,
  Google, OpenAPI `228/228`, quality policy e estrutura documental.
- Quality Gate `docs/pr`: `PASS`; scripts medidos com `165`, `61`, `202` e `68`
  linhas, zero violações; TP com `176` linhas e `11.372` bytes, sem revisão extra.
- Quality Gate `infra/pr`: `PASS`; todos os shells passaram em `bash -n`, contrato
  com `10` cenários e `infra/scripts/validate-docs.sh` com `413` linhas, zero
  violações.
- A3: não houve segredo, dado real, instalação, acesso a Google, rede ou ambiente
  externo. O mapeamento preserva sandbox, revisão de acesso externo e precedência
  `Deny > Ask > Allow`.
- Git: nenhum comando de escrita foi executado pelo agente. Durante o trabalho, o
  `HEAD` avançou externamente em checkpoints que absorveram mudanças em andamento;
  alterações concorrentes de PRD foram preservadas e ficaram fora deste escopo.

### Verificação operacional pendente

O estado entregue é `configuração versionada presente / runtime não verificado`.
Uma sessão nova no Gemini CLI ainda deve confirmar `/memory show` e `/skills list`;
no Antigravity, um humano deve confirmar Project folders, regra `Always On`,
sandbox, `Proceed in Sandbox` e listas efetivas de permissões. Esse skip é a
fronteira deliberada da tarefa e não reduz o `PASS` da camada versionada.

## Change log

| Versão | Data | Mudança |
| --- | --- | --- |
| 1.3 | 2026-09-11 | Conclui as duas unidades com gates `PASS`, evidência do harness e verificação operacional Google explicitamente pendente. |
| 1.2 | 2026-09-11 | Corrige a granularidade do código: substitui mudanças no validador geral por validador/teste Google dedicados e reexecuta o IRG. |
| 1.1 | 2026-09-11 | Reexecuta o IRG contra ADRs e settings finais e explicita os targets do Quality Gate. |
| 1.0 | 2026-09-11 | Decompõe o suporte Google em harness portável e aplicação local, registra fontes oficiais e autoriza os paths exatos após IRG `READY`. |
