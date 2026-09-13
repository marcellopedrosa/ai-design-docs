---
document_id: HARNESS-README
primary_nature: Contexto
objective: Disponibilizar um harness documental agnostico, clonavel e adaptavel a projetos de software.
scope: Governanca documental, descoberta progressiva, planejamento, readiness, assurance e adaptadores de agentes.
non_objectives: Nao fornecer codigo, scripts executaveis, stack, dominio, credenciais ou decisoes do projeto de origem.
owner: Mantenedores do harness
status: Active
version: 1.3
date: 2026-09-10
last_reviewed: 2026-09-13
keywords: harness, documentacao, agentes, orquestrador, standards, clear, readiness, quality-gate, entrega-git, gemini, antigravity
related_files: AGENTS.md, CLAUDE.md, GEMINI.md, backend/README.md, frontend/README.md, website/README.md, infra/README.md, docs/README.md, docs/agents/AgentOrchestrator.md, docs/agents/standards/README.md, docs/agents/skills/README.md, docs/settings/settings.md, docs/settings/google-gemini.md, docs/adrs/ADR-0000-governanca-do-harness-documental.md
code_references: .agents/rules/documentation-governance.md, .agents/skills/, .claude/skills/; pacote exclusivamente documental, sem hooks ou scripts executáveis.
principal_statement: O pacote fornece as fontes e os contratos necessarios para adotar a mesma governanca sem transportar contexto de produto ou de stack.
---

# Harness documental agnóstico

Este diretório é um pacote independente, pronto para se tornar um repositório Git
próprio. Ele preserva a lógica documental do harness: fontes de verdade tipadas,
descoberta progressiva, gates antes e depois da implementação, instruções enxutas
para agentes e rastreabilidade do problema até a evidência final.

Todo o conteúdo é Markdown. Não há aplicação, dependência, segredo, configuração
de produção, script executável ou decisão pertencente ao projeto de origem.

## O que está incluído

- adaptadores globais para Codex, Claude Code e Gemini CLI, mais regra de
  workspace para Google Antigravity;
- skills operacionais documentais pareadas;
- skill `git-delivery` opt-in, com scaffold de enforcement adaptável ao projeto de
  destino;
- ADR de governança e mapa de precedência;
- `AgentOrchestrator` como único agente inicial do bootstrap;
- biblioteca portátil de standards transversais e condicionais por capacidade ou
  stack, cada um com ativação explícita;
- lifecycle C.L.E.A.R.;
- Implementation Readiness Gate;
- Test, Quality e Security/Compliance Gates;
- estrutura base de coleções e índices;
- pastas base de backend, frontend, website, infraestrutura e documentação, cada
  uma com seu próprio `README.md`;
- templates para os artefatos recorrentes;
- contrato para conectar validadores específicos do projeto de destino.

## Adoção em outro projeto

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
7. Selecione no [catálogo portátil](docs/agents/standards/README.md) o baseline e
   apenas os standards condicionais compatíveis com a stack e o risco registrados.
8. Crie os primeiros artefatos pelos templates de [`docs/templates/`](docs/templates/README.md).
9. Configure no projeto de destino os validadores e comandos descritos em
   [`docs/automation/README.md`](docs/automation/README.md). Enquanto eles não
   existirem, reporte `Automação não configurada`; não declare um gate automático
   como aprovado por inspeção subjetiva.
10. Revise `AGENTS.md`, `CLAUDE.md`, `GEMINI.md` e a regra Antigravity para manter
   equivalência sem inserir regras de stack que pertençam a um pacote específico.
11. Se usar Antigravity, configure a regra de workspace como `Always On`, habilite o
   sandbox e confira permissões conforme
   [`docs/settings/google-gemini.md`](docs/settings/google-gemini.md). Se usar
   Gemini CLI, confirme contexto e skills com `/memory` e `/skills`.
12. Execute a checklist de bootstrap do ADR-0000 e repita o inventário. A segunda
   execução deve produzir delta vazio.
13. Se adotar entrega Git governada, aceite a política local, implemente e teste o
   hook/validador, atualize os adaptadores e só então habilite `git-delivery`.

## Fluxo C.L.E.A.R.

| Estágio | Resultado esperado |
| --- | --- |
| **C — Context** | Problema, público, resultado e comportamento estão definidos e aprovados. |
| **L — Logic & Layout** | Decisões, arquitetura, fluxos e plano atômico estão prontos; o IRG termina em `READY`. |
| **E — Execution** | A implementação ocorre somente no escopo, versão e paths auditados. |
| **A — Assurance** | A1 Test, A2 Quality e A3 Security/Compliance têm resultados independentes. |
| **R — Release** | Entrega e verificação seguem autorização e procedimentos próprios do projeto. |

## Árvore distribuída

```text
AGENTS.md
CLAUDE.md
GEMINI.md
.agents/rules/documentation-governance.md
.agents/skills/{governanca-documental,implementation-readiness,quality-gate,git-delivery}/SKILL.md
.claude/skills/{governanca-documental,implementation-readiness,quality-gate,git-delivery}/SKILL.md
backend/README.md
frontend/README.md
website/README.md
infra/README.md
docs/
  README.md
  ai/README.md
  adrs/{README.md,ADR-0000-governanca-do-harness-documental.md}
  architecture/{README.md,module-registry.md}
  settings/{README.md,settings.md}
  agents/{README.md,AgentOrchestrator.md,skills/README.md,standards/...}
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
| 1.3 | 2026-09-13 | Inclui a capacidade opt-in `git-delivery` sem transportar scripts nem permissões do projeto de origem. |
| 1.2 | 2026-09-11 | Inclui AgentOrchestrator como único agente inicial e a biblioteca portátil de standards com ativação condicional. |
| 1.1 | 2026-09-11 | Adiciona suporte portátil a Gemini CLI e Antigravity e sua verificação de adoção. |
