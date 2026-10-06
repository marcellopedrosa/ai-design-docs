# Standard de carregamento de contexto para agentes

## Objetivo

Orientar agentes a carregar somente a documentação necessária para uma tarefa,
preservando fontes canônicas e evitando contexto redundante.

## Ordem de autoridade

1. Restrições do ambiente e políticas organizacionais aplicáveis.
2. `corporate-presets/restrictions/`.
3. `AGENTS.md` da raiz e do domínio.
4. ADRs aceitos e standards corporativos aplicáveis.
5. Policies e skills operacionais do harness.
6. Especificação, plano, tarefas e critérios de aceite da tarefa.
7. Preferências locais do usuário, quando não conflitarem com as camadas superiores.

Uma fonte inferior pode especializar o escopo, mas não enfraquecer uma fonte
superior. Em conflito não resolvido, registre a lacuna e aplique o limite mais
restritivo até obter decisão do owner.

## Seleção de contexto

Comece pelo `AGENTS.md` aplicável e pelo README da coleção afetada. Carregue apenas
as fontes que compartilhem domínio, requisito, decisão, contrato, owner ou path com
a tarefa. Expanda o contexto somente quando uma referência ou lacuna comprovada
exigir isso.

Para mudanças executáveis, leia a especificação do Spec Kit em
`projects/<dominio>/docs/specs/<feature>/` e as fontes diretamente relacionadas.
Os artefatos `spec.md`, `plan.md`, `tasks.md` e checklists seguem exclusivamente a
convenção do Spec Kit; skills de numeração documental nunca se aplicam a `docs/specs/`.

## Rotas principais

| Necessidade | Fonte inicial |
| --- | --- |
| Estrutura e colocação documental | `corporate-presets/standards/documentation-structure-standard.md` |
| Governança de README e coleções | `corporate-presets/standards/documentation-governance-standard.md` |
| Restrições universais | `corporate-presets/restrictions/` |
| Política de colocação ou Git | `corporate-presets/policies/` |
| Mudança executável | `projects/<dominio>/docs/specs/<feature>/` |
| Decisão técnica | `projects/<dominio>/docs/adrs/` ou `projects/docs/adrs/` |
| Validação documental | `validate-relative-links` e `documentation-governance` |

## Exclusões padrão

Não carregue por padrão documentos fora do escopo, ADRs não selecionados, lições
aprendidas, templates, fixtures, contratos não relacionados ou o conteúdo protegido
de `spec-kit/`. Não crie uma segunda fonte de verdade para registrar um resumo que
já pertence a outra coleção.
