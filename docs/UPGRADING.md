---
document_id: DOCS-UPGRADE-V2
primary_nature: Contexto
objective: Orientar a migracao estrutural de projetos adotantes da versao 1.x para o AI Engineering Harness 2.0.0.
scope: Mudancas arquiteturais, novas pastas raiz, schemas formais, registry, canonical skills e tooling.
non_objectives: Nao substituir a documentacao de arquitetura nem inventar mudancas fora do changelog oficial.
owner: Mantenedores do harness
status: Active
version: 2.0.0
date: 2026-09-29
last_reviewed: 2026-09-29
keywords: upgrade, migracao, versao-2, harness, breaking-changes, registry, contracts, tooling, evals
related_files: README.md, docs/README.md, docs/adrs/ADR-0000-governanca-do-harness-documental.md, docs/architecture/module-registry.md
code_references: registry/, contracts/, skills/, tooling/, adapters/, .agents/skills/, .claude/skills/
principal_statement: A migracao para o harness v2 preserva as politicas normativas da v1 e introduz control plane deterministico desacoplado dos runtimes.
---

# Guia de Migração: AI Engineering Harness 1.x para 2.0.0

Este documento orienta mantenedores e adotantes na transição da versão 1.x (focada exclusivamente em governança documental normativa) para o **AI Engineering Harness 2.0.0** (que combina governança documental com control plane determinístico de machine-readable registry, contratos JSON Schema, canonical skills, suíte de evals e harness doctor).

## Visão Geral das Mudanças

A versão 2.0.0 não enfraquece nenhuma regra normativa ou ciclo de vida C.L.E.A.R. da versão 1.x. O objetivo central é desacoplar fontes canônicas de projeções específicas de runtimes e fornecer tooling determinístico portátil.

| Dimensão | Versão 1.x | Versão 2.0.0 |
| --- | --- | --- |
| **Fonte de Skills** | Projeções duplicadas em `.agents/skills/` e `.claude/skills/` | Fonte canônica única em `skills/`, sincronizada deterministicamente para runtimes |
| **Metadados do Harness** | Descrições textuais dispersas | `registry/` com schemas YAML para skills, standards, runtimes e tooling |
| **Contratos Estruturais** | Textuais em documentos Markdown | Schemas JSON Schema formais em `contracts/` (Draft-07 / 2020-12) |
| **Diagnóstico** | Inspeção manual ou scripts avulsos | `node tooling/harness-doctor/index.mjs` com diagnóstico unificado |
| **Evals e Assurance** | Descrições de casos de teste em prosa | Suíte de evals (`evals/`) com runner determinístico H1 (`tooling/eval-runner/`) |
| **Manifesto de Projeto** | Não padronizado | `harness.project.yaml` validado formalmente contra schema |

## Principais Alterações Estruturais

### 1. Novas Pastas na Raiz
Projetos adotantes devem incorporar a nova topologia modular:
- `registry/`: catálogo único de verdade (`harness.yaml`, `skills.yaml`, `standards.yaml`, `runtimes.yaml`, `tooling.yaml`);
- `contracts/`: schemas JSON formais para gates, evidências, handoffs, solicitações de capacidade e manifesto de projeto;
- `skills/`: implementação canônica de capability packages;
- `evals/`: suíte de evals de confiabilidade do harness (lifecycle, orquestração, permissões, regressão);
- `tooling/`: ferramentas portáteis em Node.js puro (`harness-doctor`, `sync-adapters`, `eval-runner`, `contracts/validator`);
- `adapters/`: políticas e regras compartilhadas entre os diferentes runtimes.

### 2. Distinção de Contratos
- `contracts/` (raiz): contratos JSON Schema da infraestrutura do harness;
- `docs/contracts/`: mantido exclusivamente para documentar contratos de negócio/interfaces do produto final (APIs OpenAPI, eventos AsyncAPI).

### 3. Sincronização de Skills
Não edite skills diretamente dentro de `.agents/skills/` ou `.claude/skills/`. Toda edição deve ocorrer na fonte canônica `skills/<skill-name>/SKILL.md` e ser propagada via:
```bash
node tooling/adapters/sync-adapters.mjs
```
A verificação de paridade pode ser executada com:
```bash
node tooling/adapters/sync-adapters.mjs --check
```

### 4. Diagnóstico e Verificação de Bootstrap
Em qualquer novo ambiente ou após atualizações estruturais, execute o harness doctor:
```bash
node tooling/harness-doctor/index.mjs
```
O doctor verifica integridade do registry, contratos, paridade de skills, integridade de fixtures e paridade entre registry e documentação.

## Passos para Atualização de um Projeto Adotante

1. **Backup da branch de trabalho:** certifique-se de que a árvore Git local está limpa.
2. **Atualização da estrutura raiz:** copie os diretórios `registry/`, `contracts/`, `skills/`, `evals/`, `tooling/` e `adapters/` da release 2.0.0.
3. **Criação do manifesto de projeto:** copie `harness.project.example.yaml` para `harness.project.yaml` na raiz do projeto e ajuste IDs, comandos e runtimes.
4. **Sincronização dos adaptadores de runtime:** execute `node tooling/adapters/sync-adapters.mjs` para atualizar `.agents/skills/` e `.claude/skills/`.
5. **Execução do harness doctor:** execute `node tooling/harness-doctor/index.mjs` e garanta que todos os checks resultam em `PASS`.
6. **Validação documental:** execute `node docs/scripts/validate-documentation-governance.mjs --root .` para garantir conformidade contínua.
