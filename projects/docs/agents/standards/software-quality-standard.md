---
document_id: PROJECT-SOFTWARE-QUALITY-STANDARD
primary_nature: Regra
objective: Definir a seleção, os critérios, as evidências e o resultado dos quality gates transversais do ciclo C.L.E.A.R.
scope: Separação Teste x QA, níveis focused, pr e release, critérios cross-stack, waivers e orquestração pelo executor canônico.
non_objectives: Não definir requisitos de produto, substituir standards de teste por pacote, fixar tecnologia inexistente ou autorizar ambiente externo.
owner: Arquitetura e Qualidade
status: Active
date: 2026-09-08
version: 1.3
keywords: quality-gate, teste, qa, clear, cobertura, métricas, comentários, tamanho-de-arquivo, loop-corretivo, git, readiness, escopo-atomico
related_files: harness/governance/decisions/ADR-0000-governanca-do-harness-documental.md, ./software-engineering-lifecycle.md, ./implementation-readiness-standard.md, backend-testing-standard.md, frontend-testing-standard.md
code_references: infra/scripts/validate-quality-metrics.mjs, validate-quality-metrics.test.mjs, infra/scripts/validate-plan-granularity.mjs, validate-plan-granularity.test.mjs, infra/scripts/validate-quality-metrics.mjs, infra/scripts/validate-plan-granularity.mjs, infra/scripts/validate-quality-gates.sh, infra/scripts/tests/validate-quality-gates-test.sh, backend/pom.xml, frontend/vitest.config.ts, frontend/tsconfig.quality.json, website/vitest.config.ts
principal_statement: Testes verdes demonstram comportamento observado; o Quality Gate mede cobertura e manutenibilidade no escopo atômico, exige correção iterativa de resultados inaceitáveis e somente autoriza entrega Git quando todos os gates aplicáveis estão em PASS.
---

# Software Quality Standard

## 1. Separação normativa entre Teste e QA

O macroestágio **[A] Assurance** do C.L.E.A.R. contém três gates independentes:

| Gate | Pergunta respondida | Evidência mínima | Owner principal |
| --- | --- | --- | --- |
| A1 — Test Gate | O comportamento alterado foi exercitado e permaneceu correto? | Testes focalizados, suíte impactada e regressões aplicáveis. | Implementador e TestAutomator |
| A2 — Quality Gate | O artefato satisfaz cobertura, arquitetura, análise estática, tipagem, build e critérios de manutenção? | Relatórios e comandos determinísticos definidos neste standard e nos standards do pacote. | CodeGuardian e owner do pacote |
| A3 — Security & Compliance Gate | A mudança respeita segurança, privacidade e compliance? | Revisões e testes especializados conforme risco e dados tratados. | SecurityAgent, SecurityOAuth e ComplianceAgent |

Um resultado verde em A1 não aprova A2 ou A3. Cada gate produz sua própria
evidência e todos os gates aplicáveis precisam estar aprovados para avançar.

## 2. Fontes e precedência

1. Este standard define critérios transversais, seleção, evidência e semântica do
   resultado.
2. [Backend Testing](backend-testing-standard.md) e
   [Frontend Testing](frontend-testing-standard.md) definem pirâmide, ferramentas e
   limiares quantitativos de seus pacotes.
3. Standards de segurança, acessibilidade, arquitetura e domínio acrescentam gates
   quando o risco ou a mudança os ativa.
4. Um plano pode elevar um limiar, mas não pode reduzi-lo. Exceção exige waiver
   explícito conforme a Section 7.
5. A skill `quality-gate` guarda o workflow. Ela não é fonte de limiares.

### 2.1 Precondição de readiness e fronteira da decomposição

Antes de A1 ou A2, o handoff deve conter `implementation-readiness` `READY` vigente
para o mesmo task ID, versões, escopo e paths implementados. Ausência, `BLOCKED`,
evidência stale ou divergência produz `BLOCKED` processual e devolve a mudança à
Phase 7 do lifecycle.

O Quality Gate não decompõe retrospectivamente uma implementação. O
`AgentOrchestrator` corrige a granularidade no IRG, atualiza a relação pai → filhos
e reaudita cada unidade antes de `[E] Execution`. Se Assurance descobrir que mais
de um resultado independente foi executado sob um único `READY`, ele registra a
divergência exata e retorna o trabalho ao planejamento sem aprovar parcialmente.

## 3. Níveis de execução

| Nível | Momento | Obrigação mínima |
| --- | --- | --- |
| `focused` | Durante implementação e correção | Executar o menor teste determinístico que reproduz o comportamento alterado; seletor explícito é obrigatório. |
| `pr` | Antes do handoff ou integração | Executar suíte impactada, cobertura configurada, arquitetura/análise estática, lint, tipagem e build aplicáveis. |
| `release` | Antes de promover um artefato | Repetir `pr` e acrescentar E2E, smoke, integração realista e gates ambientais autorizados pelo plano. |

`focused` acelera feedback, mas nunca substitui `pr`. `release` não autoriza deploy,
rede, segredo, produção ou mutação ambiental por si só.

## 4. Matriz mínima por escopo de mudança

| Escopo observado | A1 — Test Gate | A2 — Quality Gate | Gates condicionais |
| --- | --- | --- | --- |
| Documentação | Validador documental focal ou agregado. | Contrato, links, índices, taxonomia, paridade de skills e tamanho/revisão semântica de TP/IP alterado. | Segurança quando publicar informação sensível. |
| Backend de domínio/aplicação | Teste focal, suíte do contexto e regressão completa aplicável. | Cobertura configurada, ArchUnit, compilação e zero falhas/erros/skips em gate obrigatório. | PostgreSQL, concorrência, contrato e isolamento por tenant quando afetados. |
| Persistência ou migração | Teste focal mais integração em banco compatível. | Flyway do zero, reexecução/idempotência aplicável e arquitetura. | Backup/restore, volume ou rollout sob plano operacional. |
| API, evento ou contrato | Testes de produtor, consumidor, serialização e erros. | Compatibilidade, schema e build. | Segurança/RBAC e auditoria conforme superfície. |
| Frontend | Unitários/componentes focalizados e suíte impactada. | Cobertura Vitest, lint, typecheck, format check e build. | a11y e E2E para fluxo crítico, autenticação, RBAC ou UI nova. |
| Website | Unitários/componentes e scripts locais. | Cobertura Vitest configurada, lint, typecheck, format check e build. | E2E no release e validação comercial quando alterar promessa. |
| Infraestrutura ou shell | Teste de contrato focal e `bash -n`. | Validadores do pacote, renderização segura e comportamento fail-closed. | Ambiente real somente com autorização e plano próprios. |
| Dependência ou supply chain | Testes e build dos consumidores. | Auditoria, licença, pinning e integridade aplicáveis. | Gate humano e rede explicitamente autorizada. |

A mudança que cruza linhas executa a união dos gates, nunca apenas a linha mais
conveniente. O plano registra o motivo de todo gate classificado como não aplicável.

## 5. Critérios de qualidade

- Testes obrigatórios, lint, typecheck, build, arquitetura e verificadores de
  contrato têm taxa de aprovação de 100%.
- Gate obrigatório termina com zero falhas e zero erros. Skip, disable, quarantine
  ou filtro que possa ocultar ausência de testes exige justificativa rastreável; um
  gate que exija zero skips deve falhar quando houver qualquer skip.
- Cobertura somente é comprovada por relatório atual gerado por configuração que
  contém check executável. Percentual descrito em Markdown, relatório histórico ou
  quantidade de testes não constitui evidência.
- Os limiares quantitativos são os dos standards do pacote. Configuração ausente,
  limiar inferior, relatório vazio ou execução que não aplica o check resulta em
  `BLOCKED` ou `FAIL`, nunca em aprovação.
- Violações arquiteturais, falhas de lint/tipagem e build quebrado são bloqueantes.
- Achados Critical e Major de qualidade permanecem em zero antes da aprovação, ou
  possuem waiver válido, limitado e aprovado.
- Métrica ainda sem ferramenta determinística não pode ser declarada aprovada por
  avaliação subjetiva. Ela deve ser materializada, receber waiver ou permanecer
  `BLOCKED`.
- Uma mudança não pode reduzir o baseline de cobertura ou qualidade observado, mesmo
  quando o limiar global ainda seja atendido.

### 5.1 Perfil métrico local

O quality profile portátil é executado sem servidor, instalação, rede ou descoberta
Git. Seus limiares mínimos são:

| Escopo | Cobertura mínima | Manutenibilidade nos `--target` explícitos |
| --- | --- | --- |
| Backend | 73% de instruções e 58% de branches em JaCoCo XML atual. | Até 500 linhas físicas por arquivo fonte. |
| Frontend e website | 70% de lines, branches e functions em LCOV atual. | Até 500 linhas físicas por arquivo fonte. |
| Infra | Cobertura não aplicável salvo standard especializado. | Até 500 linhas físicas por script fonte. |
| Task Plan e Implementation Plan | Cobertura não aplicável. | Até 500 linhas físicas e 64 KiB sem revisão adicional; acima de qualquer limite exige revisão semântica estruturada. |

Em todos os targets de código, comentários devem ser curtos, diretos e explicar
intenção não evidente: texto de comentário tem no máximo 100 caracteres por linha e
bloco contíguo no máximo 12 linhas. Código comentado é proibido. `TODO` ou `FIXME`
exige ID ou URL rastreável. A quantidade e a densidade de comentários são apenas
informativas; não existe mínimo, pois código claro não deve receber comentário
artificial.

O limite de 500 linhas é um gatilho obrigatório de decomposição da implementação.
Um target acima dele resulta em `FAIL` até que responsabilidades sejam separadas ou
exista waiver humano temporário conforme a Section 7. Dívida fora dos targets não
é promovida a falha do recorte, mas passa a ser exigível assim que o arquivo for
alterado. Arquivos gerados e dependências não são targets.

Para TP/IP informado por `--target`, `validate-plan-granularity.mjs` mede linhas e
bytes UTF-8. Acima de 500 linhas ou 64 KiB, o plano deve conter a seção exata
`## Granularity / Decomposition Review`, com os campos `Outcome`, `Rationale`,
`Children` e `Reviewed on`. `Outcome` aceita somente `Decomposed` ou
`Semantically indivisible`; o primeiro exige ao menos dois IDs filhos, e o segundo
exige `Children: N/A` e justificativa objetiva. Data usa `YYYY-MM-DD`.

Revisão ausente ou inválida resulta em `FAIL`, nunca em `BLOCKED` final apenas pelo
tamanho. O AgentOrchestrator retorna o artefato ao IRG, decompõe automaticamente
quando houver resultados/handoffs independentes ou registra a indivisibilidade
semântica, atualiza índices e relações pai → filhos e reexecuta readiness e Quality
Gate. O validador comprova medida e presença da evidência; não substitui julgamento
semântico nem permite divisão puramente numérica.

### 5.2 Ciclo de correção obrigatório

`FAIL` causado pela mudança não encerra a execução: o agente diagnostica o achado,
corrige somente o escopo autorizado, atualiza teste quando aplicável e reexecuta o
menor gate capaz de demonstrar a correção, seguido do gate impactado. Cada iteração
registra resultado anterior, delta, comando e novo resultado.

O ciclo continua enquanto houver progresso verificável; três iterações consecutivas
com a mesma causa e sem redução de violações constituem impasse; dependência,
autorização, decisão humana, ferramenta ou ambiente ausente termina `BLOCKED` com
owner e próximo passo. É proibido repetir indefinidamente, reduzir limiar, omitir
target, inserir comentários artificiais ou alterar testes apenas para obter verde.

## 6. Execução canônica e evidência

O entrypoint de orquestração é:

```bash
./infra/scripts/validate-quality-gates.sh --scope <escopo> --level <nivel> \
  --target <path-alterado> [--target <outro-path>]
```

O executor não descobre mudanças por Git. Escopo, nível e seletor são entradas
explícitas fornecidas pelo plano ou pelo agente. Comandos específicos adicionais
continuam registrados na matriz de evidência.

Em `pr` ou `release`, ao menos um `--target` é obrigatório. Para código, o
executor chama `validate-quality-metrics.mjs`, que lê JaCoCo XML ou LCOV atual,
inspeciona tamanho e comentários e publica saída humana mais
`QUALITY_METRICS_JSON`. Relatório ausente/inválido é `BLOCKED`; limiar ou regra
violada é `FAIL`. Para targets TP/IP, o executor chama também
`validate-plan-granularity.mjs` e publica `PLAN_GRANULARITY_JSON`.

Para certificar a preparação e publicação da branch destinada a um futuro PR
depois dos gates, use adicionalmente
`--delivery --branch-name <nome>`. Essa opção apenas valida o contrato da branch;
`git add` dos paths autorizados, `git commit` e o push só são permitidos pela
política global depois de A1, A2 e A3 aplicáveis em `PASS`. A certificação não abre
o PR e não autoriza `gh pr create`, merge, tag, deploy ou branch protegida.

Antes de executar build de framework que carregue arquivos de ambiente por
convenção, o executor verifica somente a existência de `.env`, `.env.local` e
variantes locais por modo, sem abrir seu conteúdo. A presença de qualquer um desses
arquivos termina o build em `BLOCKED`; a execução segura deve usar fixture isolada
ou variáveis sintéticas explicitamente autorizadas, nunca ler credenciais locais.

Cada handoff registra:

| Campo | Conteúdo obrigatório |
| --- | --- |
| Escopo e nível | Pacotes, módulos e `focused`, `pr` ou `release`. |
| Comando | Linha exata executada e diretório de trabalho. |
| Resultado | Código de saída e `PASS`, `FAIL` ou `BLOCKED`. |
| Contagem | Testes, falhas, erros, skips e duração quando a ferramenta publicar. |
| Qualidade | Cobertura e limiar, lint, tipagem, arquitetura e build aplicáveis. |
| Métricas locais | Relatório, targets, linhas, higiene de comentários, violações e JSON. |
| Granularidade de plano | Linhas, bytes, necessidade de revisão, outcome, filhos e `PLAN_GRANULARITY_JSON`. |
| Iterações | Resultado anterior, correção feita, progresso e resultado atual. |
| Ambiente | Local/CI, dependências simuladas ou reais e limitações. |
| Pendências | Gate não executado, causa, owner e próximo passo. |
| Readiness | Task ID, versões e paths do `READY` vigente; qualquer divergência e o retorno à Phase 7. |

Um gate é `PASS` somente se todos os controles aplicáveis forem executados e
aprovados. Falha observada é `FAIL`. Ferramenta, configuração, dependência,
autorização ou ambiente ausente é `BLOCKED`.

## 7. Waivers

Waiver de quality gate é excepcional e deve conter owner humano, justificativa,
escopo exato, risco, compensação, expiração e plano de remoção. Ele não pode:

- transformar teste falho em aprovado;
- ocultar ausência de evidência;
- ser permanente ou valer para escopo maior que a deficiência;
- autorizar produção, segredo, rede, Git ou operação destrutiva;
- ser criado ou aprovado pelo mesmo agente que precisa dele para concluir.

## 8. Critério de conclusão

Assurance está concluído quando A1, A2 e A3 aplicáveis têm evidência reproduzível,
nenhum achado bloqueante aberto e todo waiver válido está registrado. Qualquer
controle não executado é reportado explicitamente e impede a declaração de
conformidade plena.

## 9. Change log

| Versão | Data | Mudança |
| --- | --- | --- |
| 1.3 | 2026-09-10 | Integra ao Quality Gate a medição de TP/IP em 500 linhas/64 KiB, revisão semântica estruturada e retorno corretivo ao IRG; delimita Git à branch destinada ao PR. |
| 1.2 | 2026-09-10 | Define perfil métrico portátil, limite de 500 linhas, higiene de comentários, ciclo corretivo limitado e certificação de branch para entrega pós-PASS. |
| 1.1 | 2026-09-10 | Exige readiness vigente e correspondência do escopo atômico antes de Assurance; divergência retorna à Phase 7 sem decomposição retrospectiva pelo Quality Gate. |
| 1.0 | 2026-09-08 | Define a separação Teste x QA, matriz de seleção, critérios, evidência, waivers e executor canônico do C.L.E.A.R. |
