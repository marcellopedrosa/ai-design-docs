---
document_id: SOFTWARE-QUALITY-STANDARD
primary_nature: Regra
objective: Definir selecao, criterios, evidencias e resultados dos gates de Assurance.
scope: A1 Test, A2 Quality, A3 Security/Compliance, niveis de execucao, metricas e waivers.
non_objectives: Nao fixar framework, comando de stack, limiar de cobertura ou autorizar ambiente externo.
owner: Arquitetura e Qualidade
status: Active
version: 1.1
date: 2026-09-10
last_reviewed: 2026-09-11
keywords: quality-gate, testes, cobertura, seguranca, metricas, assurance
related_files: ../AgentOrchestrator.md, README.md, software-engineering-lifecycle.md, implementation-readiness-standard.md, development-standard.md, security-standard.md, backend-testing-standard.md, frontend-testing-standard.md, ../../automation/README.md
code_references: N/A - executores pertencem ao projeto de destino.
principal_statement: Testes demonstram comportamento; qualidade e seguranca exigem gates proprios, evidencia atual e correspondencia com o READY.
---

# Software Quality Standard

## Gates independentes

| Gate | Pergunta | Evidência mínima |
| --- | --- | --- |
| A1 — Test | O comportamento alterado foi exercitado e permaneceu correto? | Teste criado/atualizado, teste focal e suíte impactada |
| A2 — Quality | O artefato atende arquitetura, cobertura, análise, tipagem, build e manutenção? | Relatórios e comandos determinísticos atuais |
| A3 — Security/Compliance | A mudança respeita segurança, privacidade e obrigações aplicáveis? | Revisões e testes proporcionais ao risco |

Cada gate publica `PASS`, `FAIL` ou `BLOCKED`. Um subgate verde não aprova outro.

## Precondição

Assurance exige `READY` vigente para o mesmo task ID, fontes, escopo e paths.
Ausência ou divergência é `BLOCKED` processual e retorna ao planejamento. O Quality
Gate não decompõe retroativamente uma implementação.

## Níveis

| Nível | Uso | Obrigação mínima |
| --- | --- | --- |
| `focused` | Feedback durante implementação | Menor teste determinístico que reproduz o comportamento |
| `pr` | Handoff ou integração | Suíte impactada e todos os quality/security gates aplicáveis |
| `release` | Antes de promover artefato | Repetir `pr` e adicionar E2E, smoke e gates ambientais autorizados |

`focused` não substitui `pr`; `release` não concede acesso a produção ou rede.

## Seleção por mudança

- Documentação: metadados, links, índices, taxonomia e paridade de adapters/skills.
- Domínio/aplicação: unidade, integração, arquitetura e regressão.
- Persistência/migration: banco compatível, migração do zero e idempotência.
- API/evento/schema: produtor, consumidor, serialização, erros e compatibilidade.
- UI: unidades/componentes, tipagem, build, acessibilidade e E2E conforme risco.
- Infra/shell: teste de contrato, sintaxe, renderização segura e fail-closed.
- Dependência/supply chain: consumidores, licença, pinning e integridade.

Mudança transversal executa a união dos gates. Todo `N/A` tem justificativa.

## Critérios baseline

- Gates obrigatórios terminam com zero falhas e zero erros.
- Skip, disable, quarantine ou filtro exige justificativa rastreável; não pode
  ocultar ausência de teste.
- Cobertura só é comprovada por relatório atual e configuração com check
  executável. O projeto define limiar por pacote e risco.
- Arquitetura, lint, typecheck, build e contrato quebrados são bloqueantes quando
  aplicáveis.
- Arquivos de código acima de 500 linhas físicas acionam revisão de responsabilidade
  e falham até decomposição ou waiver humano temporário.
- Task Plan ou Implementation Plan acima de 500 linhas ou 64 KiB inclui a seção
  `Granularity / Decomposition Review`, com `Outcome`, `Rationale`, `Children` e
  `Reviewed on`.
- Comentários explicam intenção não evidente, não preservam código morto e todo
  `TODO`/`FIXME` aponta para ID ou URL rastreável.
- Arquivos gerados e dependências não são targets de manutenibilidade.

O projeto pode elevar o baseline. Mudá-lo ou reduzi-lo exige ADR aceito; plano não
reduz regra global.

## Ciclo de correção

`FAIL` causado pela mudança deve ser corrigido no escopo e reexecutado, primeiro no
menor gate capaz de demonstrar a correção e depois no gate impactado. Registre
resultado anterior, delta, comando e resultado novo. Três iterações consecutivas
sem progresso na mesma causa constituem impasse `BLOCKED`; não reduza limiar,
omita target, enfraqueça teste ou insira conteúdo artificial para obter verde.

## Evidência

Registre nível, pacote, targets explícitos, comandos e diretórios, códigos de saída,
contagens, cobertura/limiar, arquitetura, lint, tipagem, build, segurança, ambiente,
skips, iterações, limitações e referência ao `READY`.

Relatório ausente ou inválido é `BLOCKED`; violação observada é `FAIL`. Somente
todos os controles aplicáveis aprovados produzem `PASS`.

## Waiver

Waiver exige owner humano, justificativa, escopo, risco, compensação, expiração e
plano de remoção. Não transforma teste falho em aprovado, não oculta evidência, não
é permanente e não autoriza rede, produção, segredo, Git ou operação destrutiva.

O [AgentOrchestrator](../AgentOrchestrator.md) coordena a seleção e a independência
dos subgates; os standards de stack acrescentam evidência somente quando ativados.

## Change log

| Versão | Data | Mudança |
| --- | --- | --- |
| 1.1 | 2026-09-11 | Relaciona Assurance ao orquestrador e aos standards condicionais de teste e segurança. |
