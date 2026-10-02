# Harness Onboarding

## Purpose

Este diretório contém as definições declarativas usadas para incorporar o harness a um projeto.

O onboarding possui dois modos: questionário para projeto novo e importação de
projeto legado. O questionário é executado uma única vez; um projeto já
configurado usa `bootstrap` para validar o ambiente.

## New Project

Use `node harness/tooling/harness.mjs onboard`.

O comando apresenta um quiz curto para nome, tipo, owner e contextos documentais.
Os profiles selecionados determinam os agents, sem uma pergunta adicional. Após a
revisão e confirmação, o comando cria somente `docs/project-manifest.yaml` e grava:

```yaml
onboarding:
  status: completed
  questionnaire_version: 2
  completed_on: YYYY-MM-DD
```

Uma nova execução encontra esse estado e encerra sem repetir perguntas. Para
compatibilidade, um manifesto anterior sem o bloco `onboarding` também evita a
repetição e é reportado como `legacy-manifest`.

O quiz não executa scaffold nem Doctor. Depois de revisar o manifesto, use:

```bash
node harness/tooling/harness.mjs scaffold --check
node harness/tooling/harness.mjs scaffold --create
node harness/tooling/harness.mjs bootstrap
```

## Legacy Project Import

Use `node harness/tooling/harness.mjs onboard --source "<path>"`.

A origem é somente leitura; artefatos são classificados pela policy, conflitos/ambiguidades interrompem e a confirmação precede qualquer cópia.

## Clone of a Configured Project

Use `node harness/tooling/harness.mjs bootstrap`. O bootstrap valida o manifesto,
os artefatos e o Doctor; não repete o quiz.

## Declarative Sources

- Perguntas: `harness/onboarding/questions.yaml`
- Importação: `harness/onboarding/migration-policy.yaml`
- Profiles: `harness/registry/profiles.yaml`
- Rotas: `harness/registry/artifact-routes.yaml`
- Templates: `harness/templates/`

O runtime não inventa perguntas, paths, operações ou estruturas. As perguntas do
quiz permanecem declaradas em `questions.yaml`; profiles e agents vêm do Registry.
