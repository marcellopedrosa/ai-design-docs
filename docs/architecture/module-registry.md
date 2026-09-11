---
document_id: MODULE-REGISTRY
primary_nature: Contexto
objective: Mapear modulos, paths, responsabilidades, owners, dependencias, instrucoes e comandos.
scope: Todos os pacotes ativos do projeto de destino.
non_objectives: Nao substituir README de pacote, ADR, contrato ou documentacao de operacao detalhada.
owner: Arquitetura e owners dos modulos
status: Active
version: 1.0
date: 2026-09-10
last_reviewed: 2026-09-10
keywords: modulos, pacotes, paths, owners, comandos
related_files: README.md, ../README.md
code_references: backend/, frontend/, website/, infra/
principal_statement: As pastas base sao scaffolds documentais e nenhuma implementacao deve presumir stack, comando ou owner ainda nao materializado no projeto de destino.
---

# Manifesto de módulos

## Contrato de uma entrada

| Campo | Conteúdo |
| --- | --- |
| Módulo | Nome estável e responsabilidade principal |
| Path | Diretório real a partir da raiz |
| Owner | Pessoa ou equipe responsável |
| Entrypoints | Arquivos, serviços, APIs ou comandos principais |
| Dependências | Módulos consumidos e direção permitida |
| Instruções | Adaptador local e standards aplicáveis |
| Teste | Comando focalizado e suíte impactada |
| Quality gate | Comandos determinísticos aplicáveis |

## Scaffolds base

| Fronteira | Path | Responsabilidade possível | Owner inicial | Estado | Comandos e entrypoints |
| --- | --- | --- | --- | --- | --- |
| Backend | [`backend/`](../../backend/README.md) | Serviços, APIs, jobs e regras server-side | Equipe de Backend ou Aplicações | Scaffold | Não configurados |
| Frontend | [`frontend/`](../../frontend/README.md) | Aplicação cliente interativa | Equipe de Frontend ou Experiência | Scaffold | Não configurados |
| Website | [`website/`](../../website/README.md) | Superfície pública separada | Equipe de Website, Produto ou Conteúdo | Scaffold opcional | Não configurados |
| Infra | [`infra/`](../../infra/README.md) | IaC, automação, CI/CD e operação | Equipe de Plataforma, DevOps ou SRE | Scaffold | Não configurados |

`Scaffold` não significa módulo implementado ou `READY`. Durante a adoção, o owner
deve manter, renomear ou remover cada fronteira conforme a árvore real, registrar
dependências, instruções, testes, quality gates e entrypoints e atualizar este
manifesto antes do primeiro handoff executável.

## Módulos ativos

Nenhum módulo implementado no baseline.

## Regra de atualização

Criação, remoção, renomeação, mudança de owner, dependência ou comando de módulo
atualiza este manifesto na mesma mudança.
