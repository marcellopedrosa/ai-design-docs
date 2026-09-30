# Harness Onboarding

## Purpose

Este diretório contém as definições declarativas usadas para incorporar o harness a um projeto.

O onboarding possui dois modos: projeto novo e importação de projeto legado. Um projeto já configurado deve usar `bootstrap`.

## New Project

Use `node harness/tooling/harness.mjs onboard`.

O comando carrega as perguntas e o Registry, gera e confirma o manifesto, executa scaffold e Doctor.

## Legacy Project Import

Use `node harness/tooling/harness.mjs onboard --source "<path>"`.

A origem é somente leitura; artefatos são classificados pela policy, conflitos/ambiguidades interrompem e a confirmação precede qualquer cópia.

## Clone of a Configured Project

Use `node harness/tooling/harness.mjs bootstrap`. O bootstrap não repete onboarding.

## Declarative Sources

- Perguntas: `harness/onboarding/questions.yaml`
- Importação: `harness/onboarding/migration-policy.yaml`
- Profiles: `harness/registry/profiles.yaml`
- Rotas: `harness/registry/artifact-routes.yaml`
- Templates: `harness/templates/`

O runtime não inventa perguntas, paths, operações ou estruturas.
