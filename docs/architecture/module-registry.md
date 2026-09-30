---
document_id: MODULE-REGISTRY
primary_nature: Contexto
objective: Mapear modulos, paths, responsabilidades, owners, dependencias, instrucoes e comandos.
scope: Todos os pacotes ativos do projeto de destino.
non_objectives: Nao substituir README de pacote, ADR, contrato ou documentacao de operacao detalhada.
owner: Arquitetura e owners dos modulos
status: Active
version: 1.1
date: 2026-09-10
last_reviewed: 2026-09-11
keywords: modulos, pacotes, paths, owners, comandos
related_files: README.md, ../README.md, ../../harness/governance/agents/AgentOrchestrator.md, ../agents/standards/README.md
code_references: N/A - nenhum módulo de aplicação implementado no baseline.
principal_statement: Nenhum módulo de aplicação é presumido; paths, owners e comandos são registrados somente para módulos reais.
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
| Instruções | Adaptador local, AgentOrchestrator e standards aplicáveis com versões |
| Teste | Comando focalizado e suíte impactada |
| Quality gate | Comandos determinísticos aplicáveis |

## Baseline

Nenhum módulo de aplicação ou scaffold de stack é distribuído. Um projeto
adotante registra aqui apenas módulos reais, com seus paths, owners, comandos,
dependências e gates, antes do primeiro handoff executável.

## Módulos ativos

Nenhum módulo implementado no baseline.

## Regra de atualização

Criação, remoção, renomeação, mudança de owner, dependência ou comando de módulo
atualiza este manifesto na mesma mudança.

## Change log

| Versão | Data | Mudança |
| --- | --- | --- |
| 1.1 | 2026-09-11 | Exige registrar o orquestrador e os standards selecionados nas instruções de cada módulo ativo. |
