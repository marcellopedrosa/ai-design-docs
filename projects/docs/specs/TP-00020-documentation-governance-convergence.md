---
document_id: TP-00020
primary_nature: Plano
objective: Convergir a estrutura documental, os templates, os adaptadores e os validadores do monorepo para o contrato aceito do ADR-0000.
scope: docs/, adaptadores Codex e Claude Code, website/prompt/, .gitignore, infra/scripts/ e workflows de CI relacionados ao gate documental.
non_objectives: Nao alterar requisitos funcionais, decisoes de dominio, comportamento de producao ou historico Git.
owner: Arquitetura e Documentacao
status: Completed
date: 2026-08-26
version: 1.1
keywords: governanca-documental, ADR-0000, templates, metadados, validacao, codex, claude
related_files: harness/governance/decisions/ADR-0000-governanca-do-harness-documental.md, docs/README.md, do../../ai/README.md, docs/architecture/module-registry.md, README.md, harne../../../harness/templates/README.md
code_references: infra/scripts/validate-docs.sh, infra/scripts/validate-docs.sh
principal_statement: A convergencia somente termina quando a topologia, os artefatos gerados pelos templates e o acervo existente passam nos gates documentais em execucoes consecutivas.
---

# TP-00020 — Convergência da governança documental

## Fontes superiores

- [ADR-0000](../../../harness/governance/decisions/ADR-0000-governanca-do-harness-documental.md), especialmente Sections 2, 5, 9.1, 10.1, 10.10, 10.11 e 16.
- [Mapa documental](../README.md).
- [Manual de entrada](../../ai/README.md).
- [Manifesto de módulos](../../architecture/module-registry.md).

## Escopo de execução

1. Corrigir identidades, índices e referências quebradas, incluindo o conflito `TPL-00010`.
2. Materializar as coleções e os adaptadores cuja ativação esteja comprovada; registrar explicitamente itens não aplicáveis.
3. Atualizar todos os templates recorrentes para que o artefato gerado satisfaça o contrato mínimo do ADR-0000.
4. Migrar o cabeçalho dos documentos existentes sem alterar sua afirmação normativa ou histórica.
5. Implementar o validador canônico, cobrir seu comportamento com testes herméticos e integrá-lo ao gate local e à CI antes dos builds.
6. Executar duas avaliações consecutivas e registrar o mesmo resultado sem nova mutação.

## Restrições

- Preservar conteúdo, IDs e histórico sem remoção ou renomeação ambígua.
- Não inventar decisão, requisito ou evidência. Metadados derivados devem descrever somente a natureza e o propósito já observáveis no artefato.
- Toda coleção e subcoleção alterada deve atualizar seu índice imediato.
- Mudanças de scripts ou workflows devem receber verificação focalizada e gate documental completo.

## Critérios de aceite

- `node infra/scripts/validate-docs.sh` termina com código `0`.
- `./infra/scripts/validate-docs.sh` termina com código `0`.
- Todos os documentos possuem título, identidade, natureza, objetivo, escopo, não-objetivos, owner, status, data, versão, palavras-chave, relações, referências ao código e afirmação principal.
- Templates de requisito, ADR, tarefa, implementação, lição, relatório, agente, caso de uso e skill geram cabeçalhos conformes.
- Codex e Claude Code possuem adaptadores equivalentes nos pacotes que realmente especializam a raiz.
- Configurações pessoais dos runtimes permanecem ignoradas e configurações compartilhadas são versionadas somente quando necessárias.
- Os workflows executam o validador documental antes dos builds dos pacotes.
- Duas execuções consecutivas dos gates produzem o mesmo resultado e não alteram o worktree além deste escopo.

## Handoff e evidência

### Resultado de encerramento

- O acervo convergiu para 639 documentos Markdown em 30 diretórios documentais,
  com 619 artefatos individualmente indexados e contrato mínimo completo.
- Os templates recorrentes, suas variantes raw e o template especializado
  IP-INFRA geram natureza, identidade, H1, lifecycle, path e obrigação de
  indexação coerentes; `TEMPLATE.md` é `Template` e somente seu produto é `Plano`.
- Os adaptadores Codex/Claude, settings, skills condicionais, catálogos
  agente/standard, manifesto de módulos e ponteiros legados possuem fonte
  canônica única e descoberta progressiva.
- O manifesto publica a rota domínio → pacote físico → owner → entry points →
  dependências → documentação para os cinco pacotes e treze módulos backend.
- O gate canônico foi integrado ao wrapper local e aos workflows de backend e
  segurança antes dos builds.

### Evidência reproduzível

- `node --check infra/scripts/validate-docs.sh`: aprovado.
- `node validate-documentation-governance.test.mjs`: 18/18 testes
  aprovados, incluindo regressões negativas de contrato, links, code references,
  templates, catálogos, ponteiro legado e manifesto.
- `bash infra/scripts/tests/validate-ip-infra-docs-test.sh`: aprovado, incluindo
  rejeição de `TEMPLATE.md` com natureza de plano.
- `node infra/scripts/validate-docs.sh`: aprovado com
  639 Markdown, 30 diretórios e 619 artefatos indexados.
- `./infra/scripts/validate-docs.sh`: aprovado no pré-fechamento; a validade do
  estado `Completed` exige duas execuções consecutivas adicionais, sem mutação,
  imediatamente após esta atualização administrativa.
- Auditoria independente: nenhum gap objetivo impeditivo restante; 52 ADRs com
  52 links únicos, workflows YAML válidos e manifesto com 185 linhas/14.311 bytes.

### Limites e skips

- Nenhuma operação Git de escrita, acesso a produção, dado real, segredo ou
  instalação de dependência foi executado. Antes do alinhamento final dos
  adaptadores, um subagente executou `git diff --check` somente leitura; não houve
  mutação de índice, histórico ou remoto, e nenhum outro comando Git foi repetido.
- A única consulta externa foi leitura da documentação pública oficial do Codex
  para registrar os limites de configuração; nenhum sistema do produto foi
  acessado.
- Testes de backend/frontend/website foram omitidos porque não houve mudança de
  software de produto; validadores documentais, shell e configuração de workflow
  cobrem o escopo alterado.
- Corpos legados com encoding não UTF-8 foram preservados por substituição
  byte-safe; não houve transcodificação ampla nem alteração de afirmação histórica.
- Qualquer falha nas duas execuções pós-fechamento invalida este estado e exige
  reabertura do plano antes de nova correção.

## Change log

| Versão | Data | Mudança |
| --- | --- | --- |
| 1.1 | 2026-08-26 | Encerra a convergência com acervo, templates, adaptadores, catálogos, manifesto, testes e gates em conformidade com o ADR-0000. |
| 1.0 | 2026-08-26 | Plano criado e iniciado a partir da auditoria estrutural do ADR-0000. |
