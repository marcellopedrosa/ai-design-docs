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

## Configuracao inicial do harness

Configure o ambiente nesta ordem:

1. **Instale o Spec Kit.** Consulte a [documentacao oficial de instalacao do Spec Kit](spec-kit/docs/installation.md) para instalar o `specify-cli` e confirmar os pre-requisitos. A [pagina do projeto upstream](https://github.com/github/spec-kit) e a referencia para versoes e atualizacoes.
2. **Inicialize o Spec Kit na raiz do harness.** A partir desta pasta, selecione a integracao da sua IA:

   ```powershell
   specify init --here --integration <codex|claude|copilot|gemini|outro>
   ```

   Use o identificador aceito pela versao instalada do Spec Kit. As skills e os artefatos de integracao do Spec Kit ficam na raiz do harness, em `.agents/`, `.claude/` ou no diretorio equivalente da IA. Nao coloque artefatos de produtos em `spec-kit/.specify/`.
3. **Configure os presets corporativos.** Instale as skills corporativas para os projetos adotantes, escolhendo `Codex`, `Claude` ou ambos:

   ```powershell
   powershell -File scripts/install-corporate-skills.ps1 -ProjectRoot projects -Agent Both
   ```

   Para Linux ou macOS, use o [instalador Bash](scripts/install-corporate-skills.sh). Essas skills sao aplicadas ao escopo dos produtos em `projects/`, e nao ao core em `spec-kit/`.
4. **Valide a instalacao.** Confira a versao do CLI com `specify version`, revise os artefatos gerados e execute o verificador de [links relativos](corporate-presets/skills/validate-relative-links/scripts/check-links.mjs).

Este repositorio ja versiona o core upstream em `spec-kit/`. Portanto, a instalacao do CLI e a inicializacao sao etapas de configuracao do ambiente; nao reclone nem personalize o conteudo de `spec-kit/` durante o uso normal.

### Organizacao recomendada

O harness possui duas camadas de skills, com responsabilidades e destinos diferentes:

```text
ai-design-docs/
├── .agents/ ou .claude/       # skills e integracao do Spec Kit no harness
├── spec-kit/                  # core upstream, protegido e sem customizacoes
├── corporate-presets/         # fonte das skills, templates e standards corporativos
└── projects/
    ├── .agents/skills/        # skills corporativas para Codex
    ├── .claude/skills/        # skills corporativas para Claude
    ├── frontend/              # produto ou dominio frontend
    └── backend/               # produto ou dominio backend
```

As skills do Spec Kit orientam o ciclo de especificacao, planejamento, tarefas,
implementacao e validacao. As skills corporativas complementam esse ciclo com
padroes, politicas e convencoes da empresa e sao publicadas no escopo de
`projects/`. Quando `frontend` ou `backend` for um projeto independente, sua
configuracao especifica pode ser inicializada dentro do respectivo diretorio,
sem mover o core ou criar regras dentro de `spec-kit/`.

## Estrutura

```text
AI Engineering Harness/
├── spec-kit/                 # Core do GitHub Spec Kit; protegido e intocável
├── corporate-presets/        # Templates, standards e skills corporativas
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
