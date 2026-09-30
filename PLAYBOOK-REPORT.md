# PLAYBOOK-REPORT — Relatório de Execução do Harness Fix Playbook

**Data de Início:** 2026-09-29T19:03-03:00  
**Data de Conclusão:** 2026-09-29T19:58-03:00  
**Branch de Trabalho:** `fix/harness-playbook`  
**Base:** `main` (commit `9101cf6`)  
**Repositório:** `github.com/marcellopedrosa/ai-design-docs` (v2.0.0)

---

## 1. Tabela de Pacotes de Trabalho (WPs)

| WP | Título | Status | Commit | Divergências / Notas |
|---|---|---|---|---|
| **WP-00** | Pré-voo: baseline e mapa | Concluído | N/A | Baseline 100% verde confirmado (Doctor 6/6, Sync Adapters OK, 62 testes verdes, Governança documental 50 md / 37 artefatos OK). |
| **WP-01** | Limpezas rápidas | Concluído | `c3899d4` | Removido path Windows vazado no doctor, corrigido `supports_import: true` para Claude Code, mensagem descritiva de evals H0, corrigido off-by-one de description (`> 500`). |
| **WP-02** | CI mínimo | Concluído | `7131dec` | Criado `.github/workflows/harness.yml` com Node 20 executando os 7 comandos do baseline em pull request e push para `main`. |
| **WP-03** | Doctor: fixtures e drift check | Concluído | `4893ad2` | Adicionada integridade referencial de fixtures (`checkFixtureReferences`), adicionada fixture de security ausente e drift check com regex exata `\b`. |
| **WP-04** | `CLAUDE.md` importando `AGENTS.md` | Concluído | `071df5f` | `CLAUDE.md` reduzido a 3 linhas (`@AGENTS.md`), título de `AGENTS.md` neutralizado, scripts de validação atualizados para tolerar o import. |
| **WP-05** | `sync-adapters`: recursão e órfãos | Concluído | `b564067` | Cópia recursiva preservando bit de execução (scripts), detecção de órfãos e flag `--prune` restrita a diretórios gerenciados (`.agents/skills/`, `.claude/skills/`). |
| **WP-06** | Validação de contratos (JSON Schema) | Concluído | `828332a` | Implementada Opção B: validador determinístico puro em Node.js (`tooling/contracts/validator.mjs`), exemplos válidos e inválidos em `contracts/examples/`. |
| **WP-07** | Parser YAML robusto | Concluído | `95ee416` | Implementada Opção B: parser fail-loud rejeitando arrays/objetos inline, multiline scalars (`\|`, `>`), anchors e aliases fora de aspas. |
| **WP-08** | Enforcement Claude Code | Concluído | `46d6db3` | Criado `.claude/settings.json`, adicionados `allowed-tools` em todas as skills, hooks determinísticos de guard-paths e require-handoff. Item 08.e (`guard-ready`) pausado para aprovação de persistência de estado. |
| **WP-09** | Runner de evals H1 | Concluído | `3067c32` | Criado `tooling/eval-runner/index.mjs` executando 20 evals determinísticas H1 com CLI flags (`--suite`, `--case`). Integrado ao doctor e CI. |
| **WP-10** | Critério de parada e teto de retries | Concluído | `6213250` | Definido "progresso" como redução mensurável de falhas sem regressão. Teto estrito de 3 iterações sem progresso ou 5 no total em `AGENTS.md`, `core-policy.md` e `AgentOrchestrator.md`. Adicionada eval H1 correspondente (21/21). |
| **WP-11** | Subagente avaliador com ferramentas restritas | Concluído | `57514df` | Criado `docs/agents/GateEvaluator.md` com perfil read-only + execução de testes (sem ferramentas de escrita). Atualizado índice de agentes e adicionada eval H1 (22/22). |
| **WP-12.1**| Higiene: distinção de contratos | Concluído | `d7c8458` | Documentada a distinção entre `contracts/` (harness schemas) e `docs/contracts/` (APIs de produto) em ambos READMEs e no README raiz sem quebrar compatibilidade. |
| **WP-12.2**| Higiene: schema de manifesto de projeto | Concluído | `2249bbd` | Criado `contracts/harness-project.schema.json`, exemplos válidos/inválidos e doctor validando `harness.project.example.yaml` e `harness.project.yaml`. |
| **WP-12.5**| Higiene: guia de upgrade | Concluído | `4de4a27` | Criado `docs/UPGRADING.md` cobrindo detalhadamente a migração 1.x -> 2.0.0 com base no histórico do repositório; indexado em `docs/README.md`. |
| **WP-13** | Melhorias de processo [NÃO VERIFICADO] | Concluído | N/A | Analisadas as recomendações: caminho rápido já existe documentalmente; propostas de spike e política de merge documentadas para decisão humana (ver Seção 2). |
| **WP-14** | Perfil de exemplo Java/Spring | Concluído | `279ab07` | Criado `examples/profiles/java-spring.yaml` com comandos reais Maven/JaCoCo/OWASP; doctor valida perfis em `examples/profiles/`; referenciado no README raiz. |

---

## 2. Decisões Humanas Pendentes e Propostas de Política

### 2.1 Licença do Repositório (WP-12.3)
- **Situação:** O repositório atualmente não possui arquivo `LICENSE`.
- **Ação humana necessária:** Escolher a licença apropriada antes de publicação pública (ex.: `MIT`, `Apache-2.0` ou proprietária/interna).
- **Comando sugerido após decisão:** Criar arquivo `LICENSE` na raiz com o texto oficial e ano/detentor dos direitos.

### 2.2 Tags e Releases (WP-12.4)
- **Situação:** O repositório possui versões documentadas de 1.1 a 2.0.0 no changelog, mas nenhuma tag Git foi criada até o momento.
- **Mapeamento sugerido versão -> commit:**
  - `v1.1`: commit `2859b2b` (`docs: inclusao de regras para o runtime GEMINI.md`)
  - `v1.2`: commit `3e2ab34` (`Merge pull request #6`)
  - `v1.3`: commit `e9a7d2a` (`Merge pull request #7`)
  - `v1.4`: commit `fb8c6a1` (`Merge pull request #8`)
  - `v1.5`: commit `372976a` (`Merge pull request #10: clarify project adoption onboarding`)
  - `v1.6`: commit `5619fb3` (`docs: integrate security gate and classify standards`)
  - `v1.7`: commit `aabf1fe` (`Merge pull request #11: security-gate e antigravity-permissions`)
  - `v2.0.0`: commit `9101cf6` (`Merge pull request #12: feat/harness-agnostico-v2`)
- **Comandos sugeridos para aplicação humana:**
  ```bash
  git tag -a v1.1 2859b2b -m "Release v1.1: regras portáteis para Gemini CLI e Antigravity"
  git tag -a v1.2 3e2ab34 -m "Release v1.2: AgentOrchestrator e standards condicionais"
  git tag -a v1.3 e9a7d2a -m "Release v1.3: capacidade opt-in git-delivery"
  git tag -a v1.4 fb8c6a1 -m "Release v1.4: mapeamento de scripts como extensão"
  git tag -a v1.5 372976a -m "Release v1.5: diretrizes de adoção em projetos"
  git tag -a v1.6 5619fb3 -m "Release v1.6: standards de Application, API e Spring Security"
  git tag -a v1.7 aabf1fe -m "Release v1.7: subgate security-gate e antigravity-permissions"
  git tag -a v2.0.0 9101cf6 -m "Release v2.0.0: AI Engineering Harness agnóstico v2"
  # Push de tags: git push origin --tags
  ```

### 2.3 Branch Protection na Branch `main` (WP-02)
- **Situação:** O workflow de CI `.github/workflows/harness.yml` foi adicionado e testado com sucesso.
- **Ação humana necessária no GitHub:**
  1. Acessar **Settings > Branches > Branch protection rules** no GitHub para o repositório.
  2. Adicionar regra para `main`:
     - [x] Require a pull request before merging (Require approvals: 1).
     - [x] Require status checks to pass before merging: marcar o job `verify` do workflow `harness`.
     - [x] Require branches to be up to date before merging.
     - [x] Do not allow bypassing the above settings.

### 2.4 Persistência de Estado do Implementation Readiness Gate (WP-08.e)
- **Situação:** Atualmente, a transição para `READY` do IRG é declarada no Task Plan ou no chat do agente, sem uma fonte serializada em disco. O hook `guard-ready` precisa ler um arquivo estruturado para validar se a tarefa atual foi auditada como `READY` antes de permitir ferramentas de escrita.
- **Proposta técnica recomendada:**
  - Padronizar o arquivo `.harness/state/readiness.json` (ou `.harness/state/irg.json`), contendo o schema formal `contracts/readiness-result.schema.json`.
  - O agente/orquestrador escreve esse arquivo ao emitir `READY`.
  - O hook `tooling/hooks/guard-ready.mjs` valida a existência e a vigência (mesmo task ID e fingerprint do escopo) antes de autorizar `Edit` ou `Write`.

### 2.5 Propostas de Política de Processo (WP-13)
- **13.1 Rigidez do IRG para Spikes:**
  - *Proposta:* Permitir no manifesto `harness.project.yaml` a declaração `mode: spike | production`. No modo `spike`, tarefas exploratórias que operam sob diretórios de scaffold/poc (`docs/pocs/`, `docs/analysis/` ou pastas temporárias) podem ter Open Questions não bloqueantes marcadas como `RESOLVE_IN_SPIKE`. Saídas de spike são descartáveis e bloqueadas para `git-delivery`.
- **13.2 Caminho Rápido para Mudanças Triviais:**
  - *Constatação:* `skills/implementation-readiness/SKILL.md` (linhas 19-20) já codifica explicitamente: `"Não-gatilhos: auditoria de código pronto ou alteração exclusivamente documental"`. E `AGENTS.md` restringe o IRG a: `"antes de escrever código, configuração executável, migration ou IaC"`. Portanto, alterações puramente documentais (`docs/**`, `*.md`) já dispõem de caminho rápido formal.
- **13.3 Política de Merge Explícita:**
  - *Proposta:* Atualizar a redação de `AGENTS.md` e `docs/settings/git-delivery.md` para estipular expressamente: `"Agentes criam commits e abrem Pull Requests em branches de trabalho isoladas; o merge para a branch main é de autoridade e execução exclusiva do humano mantenedor, condicionado à aprovação dos gates de CI"`.
- **13.4 Limite de Orçamento de Contexto (Context Overhead):**
  - *Constatação:* O tamanho medido da inicialização com standards é de ~45 KB (moderado e bem abaixo da janela de contexto dos modelos atuais). Nenhuma ação necessária no momento.

### 2.6 Metadados do Repositório GitHub (About / Topics) (WP-12.6)
- **Descrição sugerida (About):**  
  `AI Engineering Harness agnóstico e determinístico para governança documental, readiness gates, quality/security gates e orquestração de agentes.`
- **Topics sugeridos:**  
  `ai-agents`, `harness`, `coding-assistant`, `agent-governance`, `prompt-engineering`, `json-schema`, `software-architecture`, `ai-engineering`

---

## 3. Verificação Final (Evidências de Aceite)

### 3.1 Baseline Completo (100% Verde)
```
==> Harness Doctor: 7/7 PASS
  - Registry: PASS
  - Contracts: PASS (7 schemas formais, exemplos válidos/inválidos e manifestos validados)
  - Skills: PASS (6 skills catalogadas com allowed-tools restritos e disable-model-invocation)
  - Adapters: PASS (paridade estrita entre skills/, .agents/ e .claude/)
  - Evals: PASS (H0: 48/48 estruturais, H1: 22/22 determinísticos)
  - Fixtures: PASS (todas as fixtures referenciadas por evals existem)
  - Drift: PASS (paridade exata entre registry e documentação)

==> Sync Adapters: Paridade confirmada (0 órfãos, 0 divergências)
==> Eval Runner H1: 22/22 PASS (0 falhas)
==> Testes Unitários Tooling: 32/32 PASS
==> Testes Unitários Docs/Scripts: 56/56 PASS
==> Validação de Governança Documental: PASS (52 Markdown, 25 diretórios, 39 artefatos indexados)
==> Validação de Política de Qualidade: PASS
```

### 3.2 Integridade e Portabilidade
- **Vazamento de caminhos Windows / absolutos:** `grep -rnE '[A-Za-z]:\\\\|GITLAB' . --exclude-dir=.git` retornou **0 ocorrências**.
- **Duplicação de instruções:** `CLAUDE.md` e `GEMINI.md` contêm exatamente 3 linhas importando `@AGENTS.md`.
- **Enfraquecimento de gates:** `git diff main...HEAD -- evals/ | grep -E '^-' | grep -v '^---'` retornou **0 remoções**.
- **Segredos:** Nenhuma credencial ou chave privada introduzida; apenas strings sintéticas em fixtures de teste para validação de detectores.
- **Commits:** Cada WP foi isolado em seu respectivo commit seguindo a especificação Conventional Commits.
