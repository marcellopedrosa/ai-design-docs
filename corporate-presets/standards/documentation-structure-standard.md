# Documentation Structure Standard

Status: Active  
Owner: Harness corporativo  
Version: 1.0

## Objetivo

Definir a árvore canônica da documentação dos projetos que usam este harness,
separando o core do Spec Kit, os presets corporativos, a documentação
transversal e a documentação específica de cada domínio.

## Princípios

1. `spec-kit/` contém o core upstream e não recebe regras de um produto.
2. `corporate-presets/` contém templates, standards, políticas e contratos
   reutilizáveis.
3. `projeto/docs/` contém conhecimento transversal do produto.
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
│   ├── standards/
│   ├── governance/
│   └── contracts/
└── projeto/
    ├── AGENTS.md
    ├── docs/                         # Escopo transversal
    │   ├── product/
    │   │   ├── prd/
    │   │   ├── requirements/
    │   │   ├── use-cases/
    │   │   ├── capabilities/
    │   │   └── business/
    │   ├── architecture/
    │   │   └── adr/
    │   ├── domains/
    │   ├── contracts/
    │   ├── compliance/
    │   ├── security/
    │   ├── standards/
    │   ├── analysis/
    │   ├── delivery/
    │   │   ├── plans/
    │   │   ├── reports/
    │   │   ├── pocs/
    │   │   └── lessons-learned/
    │   └── onboarding/
    ├── frontend/
    │   ├── AGENTS.md
    │   └── docs/
    │       ├── specs/
    │       ├── requirements/
    │       ├── architecture/
    │       ├── contracts/
    │       ├── decisions/
    │       ├── standards/
    │       ├── checklists/
    │       ├── analysis/
    │       ├── delivery/
    │       │   ├── plans/
    │       │   ├── reports/
    │       │   └── lessons-learned/
    │       └── onboarding/
    ├── backend/
    │   ├── AGENTS.md
    │   └── docs/
    │       ├── specs/
    │       ├── requirements/
    │       ├── architecture/
    │       ├── contracts/
    │       ├── decisions/
    │       ├── standards/
    │       ├── checklists/
    │       ├── analysis/
    │       ├── delivery/
    │       │   ├── plans/
    │       │   ├── reports/
    │       │   └── lessons-learned/
    │       └── onboarding/
    └── mobile/
        ├── AGENTS.md
        └── docs/
            ├── specs/
            ├── requirements/
            ├── architecture/
            ├── contracts/
            ├── decisions/
            ├── standards/
            ├── checklists/
            ├── analysis/
            ├── delivery/
            │   ├── plans/
            │   ├── reports/
            │   └── lessons-learned/
            └── onboarding/
```

## Regra de decisão

Use `projeto/docs/` quando o conteúdo afetar dois ou mais domínios ou representar
o produto como um todo. Use `<dominio>/docs/` quando o conteúdo puder ser
entendido, implementado e revisado dentro de um único domínio.

Exemplos:

| Conteúdo | Local |
| --- | --- |
| PRD de uma capacidade do produto | `projeto/docs/product/prd/` |
| Requisito compartilhado entre frontend e backend | `projeto/docs/product/requirements/` |
| Contrato geral de uma API | `projeto/docs/contracts/` |
| Contrato de consumo específico do frontend | `projeto/frontend/docs/contracts/` |
| ADR sobre arquitetura do sistema | `projeto/docs/architecture/adr/` |
| Decisão sobre estado de tela | `projeto/frontend/docs/decisions/` |
| Especificação de uma mudança somente no backend | `projeto/backend/docs/specs/` |
| Especificação que atravessa domínios | `projeto/docs/specs/` |
| Lição aprendida de uma entrega transversal | `projeto/docs/delivery/lessons-learned/` |
| Lição aprendida de uma implementação frontend | `projeto/frontend/docs/delivery/lessons-learned/` |

## Artefatos do Spec Kit

O Spec Kit fornece o processo e os templates de especificação, plano, tarefas,
checklist e convergência. Neste harness, esses artefatos devem ser publicados
no `docs/specs/` do escopo correspondente, em vez de misturados com o core:

```text
projeto/frontend/docs/specs/<feature>/
├── spec.md
├── plan.md
├── tasks.md
└── checklists/
```

O `.specify/` pode conter apenas configuração e memória operacional do Spec Kit;
o conteúdo documental canônico deve permanecer em `projeto/`.

## Relação com o ai-design-docs-old

| Origem | Destino canônico |
| --- | --- |
| `docs/product/` | `projeto/docs/product/` |
| `docs/architecture/` | `projeto/docs/architecture/` |
| `docs/domains/` | `projeto/docs/domains/` |
| `docs/contracts/` | `projeto/docs/contracts/` |
| `docs/compliance/` | `projeto/docs/compliance/` |
| `docs/analysis/` | `projeto/docs/analysis/` |
| `docs/delivery/` | `projeto/docs/delivery/` |
| `docs/onboarding/` | `projeto/docs/onboarding/` |
| `docs/agents/standards/` | `corporate-presets/standards/` ou `projeto/*/docs/standards/` |
| `harness/templates/` | `corporate-presets/templates/` |
| `harness/governance/` | `corporate-presets/governance/` |
| `harness/contracts/` | `corporate-presets/contracts/` |

## Nomenclatura

- Diretórios usam nomes minúsculos e kebab-case quando houver mais de uma palavra.
- ADRs ficam em `adr/` e usam `ADR-<número>-<slug>.md`.
- Especificações usam um diretório por feature em `docs/specs/<feature>/`.
- Templates corporativos não devem ser copiados para dentro do core.
- Cada coleção deve possuir um `README.md` quando tiver mais de um artefato.
