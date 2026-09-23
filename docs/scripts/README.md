---
document_id: DOCUMENTATION-SCRIPTS-INDEX
primary_nature: Contexto
objective: Catalogar validadores executáveis do harness e suas verificações herméticas.
scope: Scripts em docs/scripts/ que implementam, após adaptação local, contratos definidos pelo ADR-0000 e docs/automation/.
non_objectives: Nao definir política por código, conter runtime do produto, migrações destrutivas ou automação com acesso externo.
owner: Arquitetura e Qualidade
status: Active
date: 2026-08-26
version: 1.21
last_reviewed: 2026-09-23
keywords: validacao-documental, governanca, ADR-0000, testes, quality-metrics, cobertura, node, portabilidade
related_files: ../README.md, ../adrs/ADR-0000-governanca-do-harness-documental.md, ../automation/README.md, ../agents/skills/README.md, ../agents/standards/software-quality-standard.md, ../agents/standards/implementation-readiness-standard.md
code_references: validate-documentation-governance.mjs, validate-documentation-governance.test.mjs, validate-google-runtime-governance.mjs, validate-google-runtime-governance.test.mjs, validate-api-contract-coverage.mjs, validate-api-contract-coverage.test.mjs, validate-quality-metrics.mjs, validate-quality-metrics.test.mjs, validate-plan-granularity.mjs, validate-plan-granularity.test.mjs, validate-quality-policy.mjs, validate-quality-policy.test.mjs; wrappers, hooks e thresholds pertencem ao projeto adotante.
principal_statement: Scripts portados só se tornam controles ativos depois de remover premissas do projeto de origem, configurar seus wrappers locais e aprovar seus testes herméticos.
---

# Scripts de governança documental

## Estado de portabilidade

Os scripts desta coleção foram migrados como material de adaptação e ainda contêm
premissas de topologia, stack, nomes de módulos, paths e wrappers de seu projeto de
origem. Portanto, não constituem o gate canônico deste harness nem podem ser
executados como evidência de `PASS` antes de uma unidade de trabalho com `READY`:

1. separar regras agnósticas de convenções locais;
2. parametrizar ou remover paths, stacks, módulos e workflows assumidos;
3. implementar o wrapper e os comandos do projeto adotante;
4. adaptar e executar os testes herméticos;
5. registrar a ativação em `docs/automation/README.md` e nos adaptadores.

Até então, o estado é `Partial` e a ausência de automação continua sendo reportada
como `Automação não configurada`.

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
  regras de ignore, rastreabilidade compacta do manifesto de módulos e o contrato
  dos PRDs e do Implementation Readiness Gate. A validação de PRD
  protege nome, identidade, lifecycle, seções, agrupamento de requisitos, IDs de
  feature, referências canônicas de aceite e coerência do Product Definition Gate.
  O scaffold protege a decisão de User Story,
  o contrato de incertezas, os campos finitos das tasks, decomposição semântica
  automática, relação pai → filhos, reauditoria por unidade, retorno processual do
  Quality Gate à Phase 7, a skill pareada e seus adaptadores. A travessia exclui
  segredos, dependências, builds e gerados.
- [Teste hermético do validador](validate-documentation-governance.test.mjs): cobre
  helpers com fixtures temporárias e executa também a validação integrada do
  repositório, inclusive presença, paridade e contratos de Implementation Readiness.
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
- [Validador da política de qualidade](validate-quality-policy.mjs): verifica a
  paridade das skills, os gates independentes e a referência à política Git local,
  sem impor convenção de branch, wrapper ou ferramenta específica.
- [Teste hermético da política](validate-quality-policy.test.mjs): cobre política
  completa, certificação ausente, divergência de skills, hook de commit, branch
  governada e descoberta Git proibida.

## Execução disponível

```bash
node --test "docs/scripts/*.test.mjs"
node docs/scripts/validate-documentation-governance.mjs --root .
```

Há testes e validadores executáveis nesta coleção, mas não há wrapper agregado
obrigatório nem contrato de CI. Execute apenas os comandos aplicáveis ao trabalho;
a ausência de ativação em um projeto adotante permanece `Automação não configurada`.
Os scripts não impõem convenção de branch nem condicionam contribuições à adoção
de um runtime, harness, hook, wrapper ou serviço externo.

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
| 1.21 | 2026-09-23 | Remove dependência de wrappers opcionais de infra e documenta os entrypoints portáveis disponíveis sem torná-los obrigatórios. |
| 1.20 | 2026-09-13 | Alinha o catalogo portavel ao hook de commit e a entrega Git governada adotavel. |
| 1.19 | 2026-09-13 | Reclassifica os scripts migrados como extensão condicional a ser adaptada e validada no destino. |
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
