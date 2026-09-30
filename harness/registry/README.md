# Registry Machine-Readable do Harness

Este diretório contém os registros estruturados do harness agnóstico em formato YAML.

O objetivo do registry é servir como **fonte única de verdade (SSOT)** para inventários, relacionamentos, ativação e metadados estruturados do harness.

## Conteúdo

- [`harness.yaml`](harness.yaml): Metadados estruturais, versão, princípios e ciclo de vida do harness.
- [`skills.yaml`](skills.yaml): Inventário formal de skills, capacidades, fases, contratos, owners, gatilhos e perfis de side effects.
- [`standards.yaml`](standards.yaml): Catálogo de standards baseline e condicionais, regras de ativação e consumidores.
- [`runtimes.yaml`](runtimes.yaml): Runtimes de agentes suportados (Codex, Claude Code, Gemini CLI, Antigravity) e seus caminhos de adaptação.
- [`tooling.yaml`](tooling.yaml): Ferramentas determinísticas, validadores e entrypoints do harness.
- [`profiles.yaml`](profiles.yaml): Artefatos requeridos por contexto; não contém conteúdo final dos projetos.
- [`artifact-routes.yaml`](artifact-routes.yaml): Localização física e template de cada tipo de artefato.

Cada Registry tem responsabilidade única: `harness.yaml` identifica/configura o
harness; `runtimes.yaml` descreve runtimes; `skills.yaml` inventaria capacidades;
`standards.yaml` descobre standards conhecidos; `tooling.yaml` inventaria
executáveis; `profiles.yaml` decide **quais** artefatos um contexto exige;
`artifact-routes.yaml` decide **onde** materializá-los. Nenhum substitui os demais.

## Regras de Governança

1. Informações inventariáveis devem ser declaradas aqui antes de serem refletidas na documentação de leitura humana.
2. Nenhuma skill, standard ou ferramenta deve constar como ativa no repositório sem a respectiva entrada no registry.
3. Os índices humanos (como `harness/skills/README.md` e `README.md`) devem manter paridade semântica com o registry, verificada pelo `node harness/tooling/harness.mjs doctor` nos checks implementados; isso não substitui revisão semântica completa.
