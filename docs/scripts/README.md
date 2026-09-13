---
document_id: DOCUMENTATION-SCRIPTS-INDEX
primary_nature: Contexto
objective: Catalogar validadores executáveis da governança documental e suas verificações herméticas.
scope: Scripts Node.js em docs/scripts/ e wrappers shell relacionados que comprovam o contrato do ADR-0000.
non_objectives: Nao conter scripts de runtime do produto, migrações destrutivas ou automação com acesso externo.
owner: Arquitetura e Qualidade
status: Active
date: 2026-08-26
version: 1.18
last_reviewed: 2026-09-11
keywords: validacao-documental, governanca, ADR-0000, testes, quality-metrics, cobertura, node, gemini, antigravity
related_files: docs/adrs/ADR-0000-governanca-documentacao-agentes-ia.md, docs/product_requirements/README.md, docs/contracts/README.md, docs/settings/google-gemini.md, docs/agents/standards/software-quality-standard.md, docs/agents/standards/implementation-readiness-standard.md, infra/scripts/validate-docs.sh, infra/scripts/validate-quality-gates.sh, docs/task_plans/TP-00020-documentation-governance-convergence.md, docs/task_plans/TP-00045-clear-quality-gate-governance.md, docs/task_plans/TP-00046-implementation-readiness-governance.md, docs/task_plans/TP-00051-product-requirements-governance.md, docs/task_plans/TP-00052-backend-api-contract-baseline.md, docs/task_plans/TP-00058-google-gemini-antigravity-documentation-governance.md
code_references: GEMINI.md, .agents/rules/documentation-governance.md, backend/GEMINI.md, frontend/GEMINI.md, website/GEMINI.md, infra/GEMINI.md, docs/scripts/validate-google-runtime-governance.mjs, docs/scripts/validate-google-runtime-governance.test.mjs, docs/scripts/validate-documentation-governance.mjs, docs/scripts/validate-documentation-governance.test.mjs, docs/scripts/validate-api-contract-coverage.mjs, docs/scripts/validate-api-contract-coverage.test.mjs, docs/scripts/validate-quality-metrics.mjs, docs/scripts/validate-quality-metrics.test.mjs, docs/scripts/validate-plan-granularity.mjs, docs/scripts/validate-plan-granularity.test.mjs, docs/scripts/validate-quality-policy.mjs, docs/scripts/validate-quality-policy.test.mjs, infra/scripts/validate-docs.sh, infra/scripts/validate-quality-metrics.mjs, infra/scripts/validate-plan-granularity.mjs, infra/scripts/validate-quality-gates.sh, infra/scripts/tests/validate-quality-gates-test.sh, infra/scripts/validate-ip-infra-docs.sh, infra/scripts/tests/validate-ip-infra-docs-test.sh, .github/workflows/backend-ci-cd.yml, .github/workflows/security-ci.yml
principal_statement: O gate canônico falha quando estrutura, contrato, índices, links, adaptadores, templates ou skills divergem do ADR-0000.
---

# Scripts de governança documental

## Contrato da coleção

- Conteúdo aceito: validadores determinísticos e testes herméticos da documentação.
- Nomes: `validate-<assunto>.mjs` para executáveis e `<nome>.test.mjs` para testes.
- Estados: `Active`, `Deprecated`.
- Critério de granularidade: separar um script quando possuir entrada, owner ou ciclo de release independente.

## Índice

- [Implementação do contrato do ADR-0000](validate-documentation-governance.mjs): verifica contrato
  mínimo, identidade e lifecycle por coleção, índices imediatos, links, referências
  de código resolvíveis, templates e variantes raw, skills, adaptadores, settings,
  catálogos semânticos bidirecionais, status e data original no catálogo de ADRs,
  ponteiros legados sem fonte concorrente, natureza e paths gerados por templates,
  regras de ignore, rastreabilidade compacta do manifesto de módulos, o contrato
  dos PRDs e o scaffold do Implementation Readiness Gate. A validação de PRD
  protege nome, identidade, lifecycle, seções, agrupamento de requisitos, IDs de
  feature, referências canônicas de aceite e coerência do Product Definition Gate.
  O scaffold protege a decisão de User Story,
  o contrato de incertezas, os campos finitos das tasks, decomposição semântica
  automática, relação pai → filhos, reauditoria por unidade, retorno processual do
  Quality Gate à Phase 7, a skill pareada e seus adaptadores. A travessia exclui
  segredos, dependências, builds e gerados.
- [Teste hermético do validador](validate-documentation-governance.test.mjs): cobre
  helpers com fixtures temporárias e executa também a validação integrada do
  repositório, inclusive presença, paridade e scaffolds portáteis de Quality Gate
  e Implementation Readiness.
- [Validador dos runtimes Google](validate-google-runtime-governance.mjs): protege
  adapters `GEMINI.md`, regra Antigravity, skills interoperáveis, fontes oficiais,
  settings e ativação documentada sem ampliar o validador geral legado.
- [Teste hermético da governança Google](validate-google-runtime-governance.test.mjs):
  cobre composição válida e rejeita adapters divergentes, modo inseguro e skills
  duplicadas.
- [Validador de cobertura dos contratos HTTP](validate-api-contract-coverage.mjs):
  extrai mappings Spring MVC do source set principal, reconcilia método/path com
  todos os OpenAPIs canônicos, aceita operações planejadas sem confundi-las com
  runtime e valida o conteúdo bloqueante mínimo das baselines Draft.
- [Teste hermético da cobertura HTTP](validate-api-contract-coverage.test.mjs):
  cobre extração, parsing, baseline válida, controller descoberto, duplicidade,
  campo Draft ausente e operação contratada ainda não implementada.
- [Quality profile portátil](validate-quality-metrics.mjs): lê JaCoCo XML e LCOV,
  mede cobertura, tamanho e higiene de comentários nos targets explícitos, valida a
  branch de entrega e emite `PASS`, `FAIL` ou `BLOCKED` com JSON, usando somente
  Node.js nativo.
- [Teste hermético das métricas](validate-quality-metrics.test.mjs): cobre parsers,
  limiares, arquivo grande, comentários, relatório ausente e branch governada.
- [Validador de granularidade de planos](validate-plan-granularity.mjs): mede linhas
  e bytes dos TP/IP informados por target e exige revisão semântica estruturada
  acima de 500 linhas ou 64 KiB, com saída humana e JSON.
- [Teste hermético de granularidade](validate-plan-granularity.test.mjs): cobre os
  dois limiares, revisão ausente, indivisibilidade, decomposição, filhos e targets
  inválidos sem rede ou Git.
- [Validador da política de qualidade](validate-quality-policy.mjs): impede que
  ADR, standards, adapters, templates, skills, executores e wrappers percam os
  contratos de métricas, loop corretivo e entrega Git mínima.
- [Teste hermético da política](validate-quality-policy.test.mjs): cobre política
  completa, certificação ausente, divergência de skills e descoberta Git proibida.

## Execução canônica

```bash
./infra/scripts/validate-docs.sh
```

O wrapper é o entrypoint canônico agregado definido pelo ADR-0000. Ele executa os
testes e a implementação da governança geral, os testes e a reconciliação de
contratos HTTP e então os gates documentais legados ainda aplicáveis. Os workflows
de backend e segurança usam o mesmo wrapper para manter paridade entre execução
local e CI. O gate é hermético: não instala dependências, não acessa rede e não lê
`.env*`.

Quando o ADR for portado para um repositório sem o wrapper, sua Section 10.11.1
define o código mínimo, o path, a permissão executável e as verificações de
bootstrap. O arquivo local é uma extensão desse núcleo portátil e acrescenta os
controles específicos deste monorepo sem criar outro entrypoint.

O reconhecimento de Implementation Plans no wrapper cobre `IP-BE`, `IP-FE` e
`IP-INFRA`. Para a coleção Infra, o ID canônico pode ser publicado pelo
frontmatter `document_id`, conforme o template da própria coleção, e o validador
especializado continua responsável pelo lifecycle e pelas evidências de gate.

O wrapper também executa o teste hermético
`infra/scripts/tests/validate-quality-gates-test.sh`. O executor funcional
`infra/scripts/validate-quality-gates.sh` pertence a `infra/`, enquanto este
catálogo documenta a regressão que impede o contrato do ADR-0000 de divergir.
O corpo portátil integral do teste está na Section 10.12.3.1 do ADR-0000, e o
validador exige seus marcadores, compara o corpo integral com o arquivo versionado,
preserva a interface hermética `--root` e os dez cenários mínimos para que o
scaffold possa ser reconstruído sem inferência.

O corpo das ferramentas métricas e de granularidade reside deliberadamente nesta
coleção: copiar as especificações do ADR inclui implementações e testes. Os
entrypoints homônimos em `infra/scripts/` são apenas wrappers importáveis; assim,
não há duas fontes de código nem necessidade de reconstruir a lógica por prosa.

Não existe `validate-implementation-readiness.sh`: a prontidão depende de decisão
semântica e, quando necessário, de resposta humana. O validador documental garante
que standard, templates, agentes, adaptadores e skill continuem a exigir a auditoria;
a skill registra `READY` ou `BLOCKED` no plano, sem transformar palavras-chave em
falso aceite automático.

Referência de código inexistente deve ser qualificada no próprio segmento como
destino planejado, histórico, removido, condicional ou gerado. Reticências não são
aceitas como caminho canônico; use caminho, sufixo, basename ou glob explícito.

## Change log

| Versão | Data | Mudança |
| --- | --- | --- |
| 1.18 | 2026-09-11 | Separa a governança Google em validador e teste pequenos para preservar o limite de manutenção dos targets. |
| 1.17 | 2026-09-11 | Protege a presença e composição dos adapters Gemini CLI/Antigravity e seu mapeamento de settings. |
| 1.16 | 2026-09-10 | Indexa o validador portátil de tamanho/revisão semântica de TP/IP, seu teste e wrapper integrado ao Quality Gate. |
| 1.15 | 2026-09-10 | Separa em validador pequeno a regressão documental do quality profile e da entrega Git governada. |
| 1.14 | 2026-09-10 | Indexa o quality profile portátil e seu teste, mantendo o corpo canônico junto das especificações transportáveis. |
| 1.13 | 2026-09-10 | Protege decomposição automática, pai → filhos, reauditoria, retorno do Quality Gate à Phase 7 e baseline integral portátil do seu teste de contrato. |
| 1.12 | 2026-09-10 | Exige nos PRDs a matriz feature → REQ → IDs/seção de aceite → estado e rejeita duplicação de texto de critério. |
| 1.11 | 2026-09-10 | Indexa o gate contrato↔controller e sua regressão hermética, integrados ao wrapper para impedir nova operação HTTP sem OpenAPI canônico. |
| 1.10 | 2026-09-09 | Integra `docs/product_requirements/` e TPL-00012 ao gate, com contrato semântico e regressões herméticas de PRD. |
| 1.9 | 2026-09-08 | Protege e documenta o scaffold portátil do Implementation Readiness Gate, inclusive sua validação semântica pela skill. |
| 1.8 | 2026-09-08 | Integra ao gate documental a validação do standard, skill pareada, executor e teste portátil do Quality Gate C.L.E.A.R. |
| 1.7 | 2026-09-02 | Documenta a relação entre o baseline portátil do ADR-0000 e as extensões locais do wrapper agregado. |
| 1.6 | 2026-09-02 | Promove o wrapper a entrypoint canônico agregado e registra o script Node como implementação interna testada do contrato do ADR-0000. |
| 1.5 | 2026-09-02 | Alinha o wrapper global ao primeiro plano IP-INFRA real: reconhece seu short ID e o `document_id` canônico em frontmatter, preservando o gate especializado. |
| 1.4 | 2026-08-26 | Acrescenta fixtures negativas para paths de agente e rastreabilidade, orçamento e não duplicação do manifesto. |
| 1.3 | 2026-08-26 | Protege a natureza do template IP-INFRA, o path gerado para agentes e o orçamento/rota completa do manifesto de módulos. |
| 1.2 | 2026-08-26 | Acrescenta paridade reversa agente/standard, coerência do catálogo de ADRs e proteção contra a reintrodução do prompt concorrente do website. |
| 1.1 | 2026-08-26 | Documenta o gate canônico, os testes herméticos e a paridade entre wrapper local e CI. |
