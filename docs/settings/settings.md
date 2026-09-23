---
document_id: SETTINGS-GLOBAL
primary_nature: Regra
objective: Definir limites agnosticos de ambiente, permissao e seguranca para assistentes de IA.
scope: Operacoes no workspace de desenvolvimento e teste.
non_objectives: Nao definir requisitos, regras de negocio, arquitetura do produto ou configuracao pessoal.
owner: Plataforma de IA e DevOps
status: Active
version: 1.4
date: 2026-09-10
last_reviewed: 2026-09-13
keywords: permissoes, seguranca, testes, qualidade, git, branch, push, segredos, codex, claude-code, gemini, antigravity
related_files: ../adrs/ADR-0000-governanca-do-harness-documental.md, git-delivery.md, codex.md, claude-code.md, google-gemini.md, ../../AGENTS.md, ../../CLAUDE.md, ../../GEMINI.md
code_references: ../../.agents/rules/documentation-governance.md; o projeto de destino deve registrar outros controles deterministas.
principal_statement: Operacoes seguem menor privilegio; a politica local governa a integracao de branches e protege a branch principal.
---

# Política do ambiente e do assistente

## Ordem de autoridade

1. Políticas organizacionais gerenciadas de segurança e compliance.
2. ADRs aceitos, incluindo o ADR-0000.
3. Standards e configurações globais versionadas do repositório.
4. Adaptadores globais de runtime.
5. Instruções e configurações específicas do pacote.
6. Plano e critérios de aceite da tarefa.
7. Preferências locais do usuário.

Uma fonte inferior pode especializar seu escopo, mas não enfraquecer uma fonte
superior. Em caso de conflito não resolvido, prevalece temporariamente o limite mais
restritivo e o owner da decisão deve ser acionado.

## Matriz de autonomia baseline

| Categoria | Política inicial |
| --- | --- |
| Leitura, busca e diagnóstico local | `allow` no escopo |
| Edição reversível solicitada | `allow` no workspace e escopo |
| Criar, manter e executar testes seguros | `allow`; obrigatório em mudança de software |
| Git de leitura e diagnóstico | `allow`, sem ler credenciais |
| Criar/trocar branch, adicionar e commitar | `allow` em branches de trabalho, conforme a política local |
| Push, PR, merge, rebase, tag e alteração de remote | `allow` conforme `git-delivery.md` e os gates aplicáveis |
| Escrita direta ou force-push na branch principal `main` | `deny` |
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
coordenada dos adaptadores de todos os runtimes suportados. A política local de
entrega Git define branches, paths, gates, hooks e proteção da branch principal.
Operações de integração seguem essa política; credenciais nunca devem ser lidas ou
expostas.

Convenções de branch, commit e hook podem ser definidas por entrega ou pelo
repositório, mas não restringem os paths necessários ao escopo. Branches de trabalho
podem ser atualizadas e integradas conforme `git-delivery.md`; falha de gate exige
correção ou registro explícito, sem bypass nem leitura de credenciais.

Os mapeamentos [Codex](codex.md), [Claude Code](claude-code.md) e
[Google](google-gemini.md) especializam esta matriz para seus mecanismos nativos
sem duplicar a politica nem as skills compartilhadas.

## Change log

| Versão | Data | Mudança |
| --- | --- | --- |
| 1.4 | 2026-09-23 | Permite integração Git sob política local e protege a branch principal contra escrita direta. |
| 1.3 | 2026-09-13 | Alinha a matriz a entrega Git governada com branch, hook, escopo de commit e push delimitados. |
| 1.2 | 2026-09-13 | Mantém Git bloqueado por padrão e define a ativação explícita da entrega Git governada. |
| 1.1 | 2026-09-11 | Liga a política agnóstica aos mecanismos nativos de Gemini CLI e Antigravity. |
