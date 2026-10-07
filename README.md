# AI Engineering Harness

Harness corporativo para desenvolvimento de software orientado por especificações.
O projeto combina o [GitHub Spec Kit](https://github.com/github/spec-kit) como
base do ciclo de desenvolvimento com padrões documentais, templates e skills
reutilizáveis para os projetos da empresa.

## O que este projeto usa como base

O núcleo é o **GitHub Spec Kit**, toolkit de Spec-Driven Development (SDD).
Ele orienta a criação de especificações, planos, tarefas, implementação e
validação antes e durante o desenvolvimento.

O harness não substitui nem replica o ciclo do Spec Kit. Ele acrescenta o
contexto corporativo necessário para organizar documentação, padrões técnicos,
contratos de API e skills compartilhadas.

## Estrutura

```text
AI Engineering Harness/
├── spec-kit/                 # Core do GitHub Spec Kit; protegido e intocável
├── corporate-presets/        # Templates, standards, contratos e políticas corporativas
├── projects/                 # Documentação e domínios dos projetos adotantes
├── scripts/                  # Automação de instalação e validação
├── AGENTS.md                 # Regras gerais para agentes
└── README.md
```

### `spec-kit/`

Contém a distribuição utilizada do GitHub Spec Kit, incluindo seus templates,
comandos, integrações e memória operacional. Este diretório é o core do harness
e não deve receber regras específicas de um produto ou alterações corporativas.

### `corporate-presets/`

É a camada complementar da empresa:

- `templates/`: modelos para PRD, ADR, lições aprendidas, contratos de API,
  relatórios e outros documentos;
- `standards/`: padrões de estrutura documental e padrões técnicos;
- `contracts/`: contratos do harness e exemplos reutilizáveis;
- `policies/`: políticas operacionais e de colocação;
- `restrictions/`: restrições universais para agentes e tooling;
- `skills/`: skills corporativas reutilizáveis por Codex, Claude Code e outros
  agentes compatíveis.

### `projects/`

Representa o espaço documental dos projetos. A documentação transversal fica em
`projects/docs/`; a documentação específica fica em `projects/frontend/docs/` ou
`projects/backend/docs/`.

Exemplos de coleções:

```text
projects/
├── docs/
│   ├── specs/
│   ├── requirements/
│   ├── agents/
│   ├── api_contracts/
│   ├── prds/
│   ├── adrs/
│   ├── standards/
│   └── lessons-learned/
├── frontend/docs/
│   ├── adrs/
│   └── specs/
└── backend/docs/
    ├── adrs/
    └── specs/
```

As fronteiras de implementação ficam em `projects/frontend/app/` e
`projects/backend/app/`; sua documentação permanece nas respectivas árvores
`docs/`. A referência normativa completa está em
`corporate-presets/standards/documentation-structure-standard.md`.

Use `projects/docs/` quando o conhecimento afetar mais de um domínio. Use o
diretório do domínio quando o conteúdo puder ser implementado e revisado
isoladamente.

## Skills corporativas

As skills são mantidas em `corporate-presets/skills/` e publicadas nos destinos
nativos dos agentes. O padrão de criação utiliza como referência principal a
[documentação do Claude Managed Agents](https://platform.claude.com/docs/en/managed-agents/overview)
e, como complemento, a [documentação de Skills da OpenAI](https://developers.openai.com/api/docs/guides/tools-skills).

Para instalar as skills em um projeto:

```powershell
powershell -File scripts/install-corporate-skills.ps1 -ProjectRoot projects -Agent Both
```

```bash
bash scripts/install-corporate-skills.sh --project-root projects --agent both
```

## Fluxo recomendado

1. Consulte `AGENTS.md` e o padrão de estrutura documental.
2. Classifique o escopo: transversal, frontend ou backend.
3. Use o Spec Kit para o ciclo de especificação e desenvolvimento.
4. Use os templates corporativos para documentos complementares.
5. Salve os artefatos no diretório documental correspondente.
6. Execute a validação de referências relativas antes de concluir a mudança.

## Validação documental

O harness possui uma skill para detectar links e referências locais quebradas:

```bash
node corporate-presets/skills/validate-relative-links/scripts/check-links.mjs --root .
```

O diretório `spec-kit/` é validado separadamente quando necessário, mas não deve
ser alterado como consequência de uma mudança nos projetos ou nos presets.

## Princípios

- O Spec Kit rege o ciclo de desenvolvimento.
- O `spec-kit/` permanece protegido e independente do produto.
- Presets corporativos complementam, mas não duplicam, fases ou gates do Spec Kit.
- Documentos devem ser salvos no escopo correto e usar referências relativas válidas.
- Cada projeto pode adicionar seus domínios sem modificar o core do harness.
