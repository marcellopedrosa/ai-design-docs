---
document_id: ADR-0001
primary_nature: Decisao
objective: Estabelecer a arquitetura v2 do harness com fonte canonica de skills, registry machine-readable, contratos estruturados, evals e tooling deterministico.
scope: Registry, contratos, fonte canonica em skills/, evals, adaptadores gerados, tooling deterministico e governanca de drift.
non_objectives: Nao transformar o harness em plataforma proprietaria, framework pesado de agentes ou catalogo de tecnologias especificas.
owner: Arquitetura e Engenharia
status: Accepted
date: 2026-09-28
version: 1.0
keywords: harness, v2, registry, contracts, skills, evals, tooling, doctor, portabilidade, agnostico
related_files: ADR-0000-governanca-do-harness-documental.md, README.md, ../agents/AgentOrchestrator.md, ../agents/skills/README.md, ../automation/README.md
code_references: ../../registry/, ../../contracts/, ../../skills/, ../../evals/, ../../tooling/; evolucao estrutural v2 do harness.
principal_statement: O harness evolui de um modelo estritamente documental para um sistema agnostico testavel e mensuravel, guiado por contratos, registry e tooling deterministico.
---

# ADR-0001 — Evolução estrutural para harness de engenharia agnóstico v2

## 1. Contexto

O `ai-design-docs` estabeleceu um baseline conceitual sólido através do ADR-0000:
lifecycle C.L.E.A.R., `AgentOrchestrator` como agente inicial único, Implementation
Readiness Gate antes da escrita executável, separação independente entre A1 Test,
A2 Quality e A3 Security/Compliance, e adaptadores enxutos para diferentes runtimes
de agentes (Codex, Claude Code, Gemini CLI, Antigravity).

Entretanto, na medida em que novas capacidades e skills foram adicionadas, o modelo
de manutenção exclusivamente manual e documental atingiu limites estruturais:
1. **Drift entre fontes humanas**: inventários repetidos em múltiplos READMEs divergiam
   com o tempo.
2. **Duplicação de skills entre runtimes**: diretórios paralelos (`.agents/skills/` e
   `.claude/skills/`) abriam margem para versões desiguais do mesmo procedimento.
3. **Falta de testabilidade estruturada**: skills funcionavam como procedimentos em prosa
   sem contratos formais de entrada/saída, fixtures ou baterias de avaliação (evals).
4. **Acoplamento em gates**: o `quality-gate` misturava avaliação e remediação direta,
   gerando risco de autocertificação; e o `security-gate` acoplava verificações
   diretamente a tecnologias específicas no corpo da skill.
5. **Ambiguidade entre "documental" e "executável"**: a existência de scripts de
   governança e testes herméticos contrastava com a afirmação de que não havia tooling.

## 2. Decisões Arquiteturais (v2)

Ficam aprovadas as seguintes decisões estruturais para a versão 2 do harness:

### DEC-01: Adotar `skills/` como fonte canônica neutra
As skills operacionais deixam de ser editadas concorrentemente em `.agents/skills/`
e `.claude/skills/`. A autoridade primária passa a residir em `skills/<skill-name>/`,
sendo os caminhos de runtime gerados/sincronizados como adaptadores de distribuição.

### DEC-02: Criar registry machine-readable
Informações inventariáveis (skills, standards, runtimes, ferramentas) passam a ter
como fonte única da verdade arquivos estruturados em `registry/` (`harness.yaml`,
`skills.yaml`, `standards.yaml`, `runtimes.yaml`, `tooling.yaml`).

### DEC-03: Manter standards em Markdown como fonte normativa
Standards e ADRs permanecem em Markdown como referências normativas legíveis por
humanos e agentes. O registry armazena apenas metadados e relacionamentos.

### DEC-04: Formalizar interfaces com JSON Schema/YAML
Interfaces entre agentes, capacidades e ferramentas são formalizadas em `contracts/`
(`capability-request`, `readiness-result`, `gate-result`, `evidence`, `security-finding`,
`handoff`). Findings de segurança exigem comprovação quádrupla (Evidência + Reachability +
Control Gap + Impacto) antes de confirmação.

### DEC-05: Adicionar evals em toda skill baseline
Cada skill torna-se um capability package com seu `SKILL.md`, `contract.yaml`,
fixtures e bateria de testes em `evals/evals.json`.

### DEC-06: Adicionar evals do harness completo
Suítes globais em `evals/` testam o comportamento emergente do sistema em termos de
Lifecycle, Orquestração, Permissões, Portabilidade cross-runtime e Regressão.

### DEC-07: Separar quality evaluation de remediation
O `quality-gate` atua estritamente como gate aggregator e decisor (`PASS`, `FAIL`,
`BLOCKED`). Em caso de falha, a remediação é roteada pelo `AgentOrchestrator` para a
capacidade de implementação, evitando autocertificação.

### DEC-08: Tornar `security-gate` agnóstico de stack e dirigido por registry
O procedimento central do `security-gate` passa a lidar apenas com conceitos
universais (fronteiras de confiança, identidades, autorização, sinks, reachability).
Heurísticas contra falsos positivos e modelagem de ameaças migram para referências sob
demanda, e standards específicos são ativados via registry e manifesto local.

### DEC-09: Reposicionar scripts como tooling, mantendo docs como contrato
`docs/automation/` permanece como o contrato normativo. As ferramentas executáveis
residem em `tooling/` (como `harness-doctor` e `sync-adapters`).

### DEC-10: Criar `harness doctor`
Criar entrypoint unificado `node tooling/harness-doctor/index.mjs` para verificar
automaticamente registry, contratos, skills, adapters, evals e prevenir drift.

## 3. Consequências

- **Positivas**:
  - Eliminação de divergência e drift entre adaptadores e documentação;
  - Rastreabilidade rigorosa de evidências com scope fingerprint;
  - Testabilidade automatizável de skills através de evals e fixtures;
  - Preservação integral da portabilidade agnóstica entre runtimes de IA;
  - Diagnóstico em comando único via `harness doctor`.
- **Negativas/Trade-offs**:
  - Exige sincronização via `tooling/adapters/sync-adapters.mjs` ao alterar skills canônicas;
  - Requer conformidade de novos artefatos com schemas formais em `contracts/`.

## 4. Rastreabilidade

- Complementa e especializa: [ADR-0000](ADR-0000-governanca-do-harness-documental.md).
- Manifestos relacionados: `registry/harness.yaml`, `registry/skills.yaml`, `registry/standards.yaml`.
- Contratos governantes: `contracts/`.
