# Documentation Structure Standard

Status: Active  
Owner: Harness corporativo  
Version: 1.2
Last reviewed: 2026-10-07

## Objetivo

Definir a árvore canônica da documentação dos projetos que usam este harness,
separando o core do Spec Kit, os presets corporativos, a documentação
transversal e a documentação específica de cada domínio.

## Princípios

1. `spec-kit/` contém o core upstream e não recebe regras de um produto.
2. `corporate-presets/` contém templates, standards, políticas, restrições,
   contratos e skills reutilizáveis.
3. `projects/docs/` contém conhecimento transversal do produto.
4. `<dominio>/docs/` contém conhecimento específico de um domínio.
5. Artefatos do Spec Kit devem ficar em `docs/specs/` do escopo afetado.
6. Uma pasta só deve ser criada quando houver conteúdo aplicável; a árvore é
   um catálogo de possibilidades, não uma obrigação de criar diretórios vazios.

## Árvore canônica

```text
harness-corporativo/
├── AGENTS.md
├── spec-kit/                         # Core upstream, protegido
├── corporate-presets/                # Camada corporativa reutilizável
│   ├── templates/
│   ├── standards/                    # Padrões corporativos
│   ├── contracts/                    # Contratos do harness e exemplos
│   ├── policies/                     # Políticas operacionais
│   ├── restrictions/                 # Restrições universais
│   └── skills/                       # Procedimentos operacionais
└── projects/
    ├── AGENTS.md
    ├── docs/                         # Escopo transversal
    │   ├── specs/
    │   ├── architecture/             # Modelos e blueprints arquiteturais
    │   ├── use-cases/                 # Casos de uso transversais
    │   ├── requirements/
    │   ├── agents/                    # Agentes e standards operacionais do projeto
    │   ├── api_contracts/             # Contratos de API do produto
    │   ├── prds/                      # PRDs transversais do produto
    │   ├── adrs/
    │   ├── standards/
    │   ├── lessons-learned/
    │   └── onboarding/
    ├── frontend/
    │   ├── AGENTS.md
    │   ├── app/                       # Implementação do domínio frontend
    │   └── docs/
    │       ├── specs/
    │       ├── requirements/
    │       ├── adrs/
    │       ├── standards/
    │       ├── lessons-learned/
    │       └── onboarding/
    ├── backend/
    │   ├── AGENTS.md
    │   ├── app/                       # Implementação do domínio backend
    │   └── docs/
    │       ├── specs/
    │       ├── requirements/
    │       ├── adrs/
    │       ├── standards/
    │       ├── lessons-learned/
    │       └── onboarding/
```

## Regra de decisão

Use `projects/docs/` quando o conteúdo afetar dois ou mais domínios ou representar
o produto como um todo. Use `<dominio>/docs/` quando o conteúdo puder ser
entendido, implementado e revisado dentro de um único domínio.

Exemplos:

| Conteúdo | Local |
| --- | --- |
| Standard técnico ou arquitetural transversal do projeto | `projects/docs/standards/` |
| Blueprint ou modelo arquitetural transversal | `projects/docs/architecture/` |
| Caso de uso transversal do produto | `projects/docs/use-cases/` |
| Requirement transversal ou compartilhado | `projects/docs/requirements/` |
| PRD transversal do produto | `projects/docs/prds/` |
| Agentes, skills e standards operacionais específicos do projeto | `projects/docs/agents/` |
| Contrato versionado de API do produto | `projects/docs/api_contracts/` |
| ADR sobre arquitetura do sistema | `projects/docs/adrs/` |
| Decisão sobre estado de tela | `projects/frontend/docs/adrs/` |
| Especificação de uma mudança somente no backend | `projects/backend/docs/specs/` |
| Especificação que atravessa domínios | `projects/docs/specs/` |
| Lição aprendida de uma entrega transversal | `projects/docs/lessons-learned/` |
| Lição aprendida de uma implementação frontend | `projects/frontend/docs/lessons-learned/` |

`projects/docs/standards/` é a coleção canônica de padrões técnicos e
arquiteturais transversais utilizados pelos projetos. Estado arquitetural,
fronteiras de módulos, dependências, matrizes e manifestos ficam ali quando forem
artefatos normativos; decisões formais continuam em `projects/docs/adrs/` ou no
`adrs/` do domínio e os standards devem referenciá-las quando aplicável.

`projects/docs/architecture/` é a coleção canônica de blueprints, modelos e
descrições arquiteturais transversais. Use `standards/` para regras prescritivas
e critérios que devem ser seguidos; use `architecture/` para registrar a forma,
as fronteiras e a composição do sistema. Requisitos compartilhados ficam em
`projects/docs/requirements/`, e casos de uso que atravessam domínios ficam em
`projects/docs/use-cases/`.

`projects/docs/agents/` contém os agentes e standards operacionais específicos do
projeto. Ele não substitui `corporate-presets/skills/` nem o ciclo do Spec Kit.

Ao criar um novo agente de projeto, use `projects/docs/agents/<AgentName>.md`.
Os padrões que ele deve seguir ficam em `projects/docs/agents/standards/` e
devem ser referenciados explicitamente pelo agente. Padrões aplicáveis a todos
os projetos permanecem em `corporate-presets/standards/`.

`projects/frontend/app/` e `projects/backend/app/` são fronteiras de implementação,
não coleções documentais. A documentação correspondente permanece em `docs/` do
domínio.

## Artefatos do Spec Kit

O Spec Kit fornece o processo e os templates de especificação, plano, tarefas,
checklist e convergência. Neste harness, esses artefatos devem ser publicados
no `docs/specs/` do escopo correspondente, em vez de misturados com o core:

```text
projects/frontend/docs/specs/<feature>/
├── spec.md
├── plan.md
├── tasks.md
└── checklists/
```

O `.specify/` pode conter apenas configuração e memória operacional do Spec Kit;
o conteúdo documental canônico deve permanecer em `projects/`.

## Nomenclatura

- Diretórios usam nomes minúsculos e kebab-case quando houver mais de uma palavra.
- ADRs ficam em `adrs/` e usam `ADR-<número>-<slug>.md`.
- Especificações usam um diretório por feature em `docs/specs/<feature>/`.
- Templates corporativos não devem ser copiados para dentro do core.
- Cada coleção documental ativa deve possuir um `README.md` imediato, mesmo quando
  o conteúdo inicial for apenas o contrato da coleção.

## Extensões corporativas

Os seguintes diretórios fazem parte da camada corporativa e não devem ser
reclassificados como documentação de produto:

- `corporate-presets/contracts/`: contratos do harness e exemplos reutilizáveis;
- `corporate-presets/policies/`: políticas operacionais e de colocação;
- `corporate-presets/restrictions/`: limites universais de segurança e autonomia;
- `corporate-presets/templates/`, `standards/` e `skills/`: formas, regras e
  procedimentos corporativos.
