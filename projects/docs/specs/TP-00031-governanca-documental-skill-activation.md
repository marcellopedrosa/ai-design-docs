---
document_id: TP-00031
primary_nature: Plano
objective: Ativar a skill operacional de governança documental e tornar o wrapper global o entrypoint canônico executável do ADR-0000.
scope: ADR-0000, catálogos e settings documentais, skills nativas Codex e Claude Code, infra/scripts/validate-docs.sh, validador Node e testes herméticos.
non_objectives: Nao alterar regras funcionais do produto, criar skills por agente ou standard, acessar ambientes externos ou modificar historico Git.
owner: Arquitetura e Documentacao
status: Completed
date: 2026-09-02
version: 1.3
keywords: governanca-documental, ADR-0000, skill, codex, claude-code, validacao
related_files: harness/governance/decisions/ADR-0000-governanca-do-harness-documental.md, do../../agents/skills/README.md, README.md, harness/governance/project-settings/codex.md, harness/governance/project-settings/claude-code.md
code_references: infra/scripts/validate-docs.sh, infra/scripts/validate-docs.sh, validate-documentation-governance.test.mjs, .agents/skills/governanca-documental/SKILL.md, .claude/skills/governanca-documental/SKILL.md
principal_statement: A ativacao somente termina quando os dois runtimes descobrem a mesma skill, ela usa o wrapper agregado e o gate impede regressao do contrato.
---

# TP-00031 — Ativação da skill de governança documental

## Fontes superiores

- [ADR-0000](../../../harness/governance/decisions/ADR-0000-governanca-do-harness-documental.md), especialmente Sections 8.9.3, 8.9.4, 10.11 e 16.
- [Catálogo operacional](../../agents/skills/README.md).
- [Catálogo de validadores](../../../../infra/scripts/validate-docs.sh).

## Escopo de execução

1. Promover `./infra/scripts/validate-docs.sh` a entrypoint canônico agregado no ADR-0000.
2. Criar a skill `governanca-documental` nos diretórios nativos de Codex e Claude Code com núcleo semanticamente equivalente.
3. Ativar e ligar a skill nos mapas, settings e catálogo operacional.
4. Fazer o validador exigir os dois artefatos, sua paridade mínima e o uso do wrapper.
5. Executar validações focalizadas e o gate agregado; registrar evidência reproduzível.
6. Documentar no ADR-0000 o bootstrap técnico mínimo do wrapper para que sua
   portabilidade não dependa de um arquivo previamente existente.

## Restrições

- A skill não substitui ADRs, standards, agentes ou índices; apenas executa o procedimento governado.
- O wrapper é a ferramenta obrigatória de conclusão; scripts internos podem servir somente ao diagnóstico focalizado.
- Não executar Git, rede, instalação, produção, dados reais ou leitura de segredos.
- Não alterar software funcional de backend, frontend ou website.

## Critérios de aceite

- O ADR-0000 declara `./infra/scripts/validate-docs.sh` como entrypoint canônico agregado e o script Node como implementação interna do contrato.
- `.agents/skills/governanca-documental/SKILL.md` e `.claude/skills/governanca-documental/SKILL.md` existem, são catalogados e passam na validação de skill.
- O validador falha se uma variante da skill ou a referência à ferramenta canônica desaparecer.
- Um repositório que porte o ADR consegue materializar `infra/scripts/validate-docs.sh`
  a partir da seção técnica, antes da primeira execução do gate.
- `./infra/scripts/validate-docs.sh` termina com código `0` no estado final.

## Handoff e evidência

- `node --check infra/scripts/validate-docs.sh`: aprovado.
- `node validate-documentation-governance.test.mjs`: `20/20` testes
  aprovados, incluindo as novas regressões da skill e do entrypoint agregado.
- `bash -n infra/scripts/validate-docs.sh`: aprovado.
- O bloco `bash` extraído diretamente da Section 10.11.1 do ADR-0000 passou em
  `bash -n`, comprovando que o baseline documentado é sintaticamente materializável.
- `quick_validate.py` aplicado separadamente às variantes Codex e Claude Code:
  ambas aprovadas como skills válidas.
- `cmp` entre as variantes Codex e Claude Code: aprovado, sem divergência.
- `./infra/scripts/validate-docs.sh`: aprovado com `692` documentos Markdown, `30`
  diretórios, `672` artefatos indexados, `1` plano IP-INFRA específico e validação
  estrutural concluída.
- Nenhum comando Git, acesso à rede, instalação, produção, dado real ou segredo foi
  executado. A criação dos diretórios nativos exigiu somente elevação do sandbox
  restrita aos dois caminhos autorizados pelo pedido.

## Change log

| Versão | Data | Mudança |
| --- | --- | --- |
| 1.3 | 2026-09-02 | Conclui o bootstrap portátil após validar o código extraído do ADR, as skills pareadas e o gate agregado. |
| 1.2 | 2026-09-02 | Reabre o plano para tornar autocontido no ADR o bootstrap técnico do wrapper em projetos portados. |
| 1.1 | 2026-09-02 | Conclui a ativação pareada após validações focalizadas e aprovação do gate agregado do ADR-0000. |
| 1.0 | 2026-09-02 | Registra o plano transversal e inicia a ativação pareada da skill de governança documental. |
