---
name: antigravity-permissions
description: Configura politicas de auto-aprovacao para operacoes rotineiras e exige confirmacao para comandos destrutivos no Antigravity/VS Code; nao use fora do escopo do projeto.
---

# Antigravity Permissions

- Owner: Plataforma de IA e Segurança
- Status: Active

## Objetivo

Configurar e auditar as permissões da extensão Antigravity no VS Code para o escopo exclusivo do projeto adotante, autorizando leituras e comandos operacionais seguros sem prompts repetitivos, mantendo a solicitação obrigatória de aprovação para comandos destrutivos.

## Gatilhos e não-gatilhos

- Use quando: o desenvolvedor solicitar a redução de confirmações repetitivas ("Allow listing...", "Allow viewing...") na extensão Antigravity para o workspace atual, preservando travas de segurança.
- Não use quando: a solicitação visar desativar a segurança global do ambiente, permitir comandos destrutivos sem aprovação ou aplicar regras fora do escopo do projeto.

## Escopo e não-objetivos

- Escopo: Configuração do gerenciador `/permissions` no escopo de projeto (`Project`), regras de precedência `Deny > Ask > Allow` e registro documental em `docs/settings/README.md`.
- Não-objetivos: Alterar políticas globais da máquina sem autorização, modificar binários do VS Code ou permitir exclusão cega de arquivos.

## Pré-condições

1. Extensão do Antigravity instalada e ativa no Visual Studio Code.
2. Projeto adotante do harness aberto como workspace ativo no editor.
3. Especificação de segurança consultada em `docs/settings/README.md`.

## Procedimento

1. Abrir a interface de comandos interativos do Antigravity no chat do VS Code digitando `/permissions`.
2. Selecionar explicitamente o escopo **Project** para isolar as regras apenas ao repositório local.
3. Na aba **Allow**, registrar as permissões para operações de rotina:
   - `read_file(*)`
   - `list_directory(*)`
   - `command(*)`
4. Na aba **Ask**, registrar os filtros estritos para operações destrutivas e comandos de alto risco:
   - `command(*del*)`
   - `command(*remove*)`
   - `command(*rm*)`
   - `command(Remove-Item*)`
   - `command(git reset*)`
   - `command(git clean*)`
   - `delete_file(*)`
5. Confirmar a precedência rigorosa da engine (`Deny > Ask > Allow`), assegurando que comandos presentes na lista `Ask` pausem a execução e exijam aprovação do usuário mesmo com `command(*)` na lista `Allow`.

## Limites de segurança

- É proibido remover comandos destrutivos da lista `Ask`.
- Comandos como `rm`, `del`, `Remove-Item` e `git reset --hard` nunca devem ser executados sem autorização humana explícita.
- Toda regra criada deve ficar restrita ao escopo do projeto (`Project`).

## Entradas, saídas e evidências

- Entradas: Especificação de comandos de `docs/settings/README.md` e escopo `Project`.
- Saídas: Regras configuradas no gerenciador `/permissions` do Antigravity para o workspace.
- Evidências: Arquivo `docs/settings/README.md` atualizado e regras visíveis no painel de permissões.

## Critério de conclusão

A extensão executa leituras de arquivos e listagens sem exibir modais de confirmação, enquanto qualquer tentativa de remoção ou comando destrutivo é obrigatoriamente interceptada pelo diálogo de aprovação (`Ask`).
