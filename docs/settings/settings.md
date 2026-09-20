---
document_id: SETTINGS-GLOBAL
primary_nature: Regra
objective: Definir limites agnosticos de ambiente, permissao e seguranca para assistentes de IA.
scope: Operacoes no workspace de desenvolvimento e teste.
non_objectives: Nao definir requisitos, regras de negocio, arquitetura do produto ou configuracao pessoal.
owner: Plataforma de IA e DevOps
status: Active
version: 1.3
date: 2026-09-10
last_reviewed: 2026-09-13
keywords: permissoes, seguranca, testes, qualidade, git, branch, push, segredos, codex, claude-code, gemini, antigravity
related_files: ../adrs/ADR-0000-governanca-do-harness-documental.md, codex.md, claude-code.md, google-gemini.md, ../../AGENTS.md, ../../CLAUDE.md, ../../GEMINI.md
code_references: ../../.agents/rules/documentation-governance.md; o projeto de destino deve registrar outros controles deterministas.
principal_statement: Operacoes seguem menor privilegio; a unica publicacao Git permitida envia a branch governada depois dos gates locais aplicaveis.
---

# Política do ambiente e do assistente

## Matriz de autonomia baseline

| Categoria | Política inicial |
| --- | --- |
| Leitura, busca e diagnóstico local | `allow` no escopo |
| Edição reversível solicitada | `allow` no workspace e escopo |
| Criar, manter e executar testes seguros | `allow`; obrigatório em mudança de software |
| Git de leitura e diagnóstico | `allow`, sem ler credenciais |
| Criar/trocar branch, adicionar e commitar | `allow` somente se a entrega Git governada tiver sido adotada; adicionar significa paths explicitos e autorizados |
| Push da branch governada | `allow` somente apos certificacao de entrega e gates aplicaveis em `PASS`; publica a branch destinada ao PR, sem abrir o PR |
| Git destrutivo, integrador, tag, remote ou branch protegida | `deny` |
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
coordenada dos adaptadores de todos os runtimes suportados. A autorização de entrega
Git precisa delimitar branch, mensagem, paths, gates, hook, push e operações
proibidas; não autoriza PR, integração, histórico, credenciais ou alteração de remote.

O nome da branch deve seguir o padrão local governado, normalmente
`X.Y.Z-{docs,feat,fix}-short-description`, e commits gerados por agente devem usar
Conventional Commits com escopo derivado da coordenada da branch. Detached HEAD,
divergência entre branch e escopo, falha de hook, falha de rede, autenticação ou
proteção de branch resultam em `BLOCKED`, sem bypass ou leitura de credenciais.

Os mapeamentos [Codex](codex.md), [Claude Code](claude-code.md) e
[Google](google-gemini.md) especializam esta matriz para seus mecanismos nativos
sem duplicar a politica nem as skills compartilhadas.

## Change log

| Versão | Data | Mudança |
| --- | --- | --- |
| 1.3 | 2026-09-13 | Alinha a matriz a entrega Git governada com branch, hook, escopo de commit e push delimitados. |
| 1.2 | 2026-09-13 | Mantém Git bloqueado por padrão e define a ativação explícita da entrega Git governada. |
| 1.1 | 2026-09-11 | Liga a política agnóstica aos mecanismos nativos de Gemini CLI e Antigravity. |
