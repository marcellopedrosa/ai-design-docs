---
document_id: HARNESS-README
primary_nature: Contexto
objective: Disponibilizar um harness documental agnostico, clonavel e adaptavel a projetos de software.
scope: Governanca documental, descoberta progressiva, planejamento, readiness, assurance e adaptadores de agentes.
non_objectives: Nao fornecer codigo, scripts executaveis, stack, dominio, credenciais ou decisoes do projeto de origem.
owner: Mantenedores do harness
status: Active
version: 1.0
date: 2026-09-10
last_reviewed: 2026-09-10
keywords: harness, documentacao, agentes, clear, readiness, quality-gate, template
related_files: AGENTS.md, CLAUDE.md, backend/README.md, frontend/README.md, website/README.md, infra/README.md, docs/README.md, docs/adrs/ADR-0000-governanca-do-harness-documental.md
code_references: N/A - pacote exclusivamente documental.
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

- adaptadores globais para Codex e Claude Code;
- skills operacionais documentais pareadas;
- ADR de governança e mapa de precedência;
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
5. Ative somente as coleções necessárias. Cada coleção ativa precisa de `README.md`,
   owner, convenção de nomes, estados e inventário completo.
6. Crie os primeiros artefatos pelos templates de [`docs/templates/`](docs/templates/README.md).
7. Configure no projeto de destino os validadores e comandos descritos em
   [`docs/automation/README.md`](docs/automation/README.md). Enquanto eles não
   existirem, reporte `Automação não configurada`; não declare um gate automático
   como aprovado por inspeção subjetiva.
8. Revise `AGENTS.md` e `CLAUDE.md` para manter equivalência sem inserir regras de
   stack que pertençam a um pacote específico.
9. Execute a checklist de bootstrap do ADR-0000 e repita o inventário. A segunda
   execução deve produzir delta vazio.

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
.agents/skills/{governanca-documental,implementation-readiness,quality-gate}/SKILL.md
.claude/skills/{governanca-documental,implementation-readiness,quality-gate}/SKILL.md
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
  agents/{README.md,skills/README.md,standards/...}
  templates/{README.md,TPL-*.md}
  automation/README.md
  <colecoes de produto e historico>/README.md
```

## Limites de portabilidade

- Os limiares de cobertura, comandos de teste, nomes de módulos e regras de release
  pertencem ao projeto de destino.
- As quatro pastas de aplicação/infraestrutura são scaffolds base, não afirmações
  de que todo projeto precisa desses quatro módulos. Remoção ou renomeação durante
  a adoção deve reconciliar o mapa e o manifesto.
- Codex e Claude Code são adaptadores opcionais. Remova um adaptador e sua árvore de
  skills apenas se o runtime não for suportado, atualizando o catálogo na mesma
  mudança.
- O pacote não escolhe licença. Antes de publicar um repositório público, o owner
  deve adicionar uma licença compatível com o uso pretendido.
- Este diretório não executa `git push`, cria repositório remoto nem publica no
  GitHub. Essas ações exigem destino, política e autorização próprios.
