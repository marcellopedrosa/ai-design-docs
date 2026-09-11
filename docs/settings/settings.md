---
document_id: SETTINGS-GLOBAL
primary_nature: Regra
objective: Definir limites agnosticos de ambiente, permissao e seguranca para assistentes de IA.
scope: Operacoes no workspace de desenvolvimento e teste.
non_objectives: Nao definir requisitos, regras de negocio, arquitetura do produto ou configuracao pessoal.
owner: Plataforma de IA e DevOps
status: Active
version: 1.0
date: 2026-09-10
last_reviewed: 2026-09-10
keywords: permissoes, seguranca, testes, git, segredos
related_files: ../adrs/ADR-0000-governanca-do-harness-documental.md, ../../AGENTS.md, ../../CLAUDE.md
code_references: N/A - o projeto de destino deve registrar controles deterministas.
principal_statement: Operacoes seguem menor privilegio; autonomia segura nunca amplia acesso a rede, producao ou segredos.
---

# Política do ambiente e do assistente

## Matriz de autonomia baseline

| Categoria | Política inicial |
| --- | --- |
| Leitura, busca e diagnóstico local | `allow` no escopo |
| Edição reversível solicitada | `allow` no workspace e escopo |
| Criar, manter e executar testes seguros | `allow`; obrigatório em mudança de software |
| Git de leitura e diagnóstico | `allow`, sem ler credenciais |
| Git de escrita, push, PR ou integração | `deny` até política explícita do projeto |
| Instalação, download, rede ou sistema externo | `ask`, com escopo explícito |
| Produção ou dados reais | `deny` |
| Segredos e credenciais | `deny`; não ler, registrar, transmitir ou versionar |
| Exclusão ampla ou ação irreversível | `ask`, após verificar o alvo |
| Bypass de permissão | `deny`, salvo isolamento e autorização específicos |

## Proteção de dados

- Configuração pessoal ou dependente de máquina permanece local e ignorada.
- Testes usam dados sintéticos, fixtures e ambientes não produtivos.
- Arquivos gerados, builds, dependências vendorizadas e áreas sensíveis devem ser
  excluídos da descoberta padrão e protegidos por controles deterministas.
- Configuração compartilhada deve ser versionada, validada e livre de segredos.

## Mudança da matriz

Alterar autonomia, precedência ou acesso externo exige decisão aceita e atualização
coordenada dos adaptadores de todos os runtimes suportados.

