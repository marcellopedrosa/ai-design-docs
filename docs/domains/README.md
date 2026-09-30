---
document_id: DOMAINS-INDEX
document_scope: project
primary_nature: Contexto
objective: Indexar somente domínios realmente existentes no projeto.
scope: Documentação de domínios implementados e seus owners.
non_objectives: Criar scaffolds por stack ou presumir módulos futuros.
owner: Arquitetura do projeto
status: Active
version: 1.0
date: 2026-09-30
last_reviewed: 2026-09-30
keywords: domínios, módulos, ownership
related_files: ../README.md, ../architecture/module-registry.md
code_references: N/A - nenhum módulo de domínio implementado.
principal_statement: O baseline não contém domínios ativos; novos diretórios surgem apenas após um módulo real ser registrado.
---

# Domínios

## Contrato da coleção

- Nomes: diretório pelo nome estável do domínio real registrado no manifesto.
- Estados: `Active` ou `Deprecated` conforme lifecycle do módulo.
- Granularidade: um domínio por fronteira funcional e owner independentes.

## Índice

Nenhum domínio implementado no baseline. Crie um diretório e indexe-o aqui
somente quando o [manifesto](../architecture/module-registry.md) registrar
módulo, owner e comandos reais.
