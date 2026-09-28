# Registry Machine-Readable do Harness

Este diretório contém os registros estruturados do harness agnóstico v2 em formato YAML.

O objetivo do registry é servir como **fonte única de verdade (SSOT)** para inventários, relacionamentos, ativação e metadados que anteriormente dependiam de manutenção manual dispersa em múltiplos documentos Markdown.

## Conteúdo

- [`harness.yaml`](harness.yaml): Metadados estruturais, versão, princípios e ciclo de vida do harness.
- [`skills.yaml`](skills.yaml): Inventário formal de skills, capacidades, fases, contratos, owners, gatilhos e perfis de side effects.
- [`standards.yaml`](standards.yaml): Catálogo de standards baseline e condicionais, regras de ativação e consumidores.
- [`runtimes.yaml`](runtimes.yaml): Runtimes de agentes suportados (Codex, Claude Code, Gemini CLI, Antigravity) e seus caminhos de adaptação.
- [`tooling.yaml`](tooling.yaml): Ferramentas determinísticas, validadores e entrypoints do harness.

## Regras de Governança

1. Informações inventariáveis devem ser declaradas aqui antes de serem refletidas na documentação de leitura humana.
2. Nenhuma skill, standard ou ferramenta deve constar como ativa no repositório sem a respectiva entrada no registry.
3. Os índices humanos (como `docs/agents/skills/README.md` e `README.md`) devem manter paridade semântica com o registry, verificada pelo `harness doctor`.
