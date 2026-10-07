---
document_id: TP-00045
primary_nature: Plano
objective: Materializar no ADR-0000 o gate Teste x QA do ciclo C.L.E.A.R. como capacidade portátil, executável, métrica e descoberta pelos runtimes de agentes.
scope: ADR-0000, lifecycle, standards de qualidade e desenvolvimento, política Git, templates, skills nativas Codex e Claude Code, executores de quality gate e métricas, testes de contrato, validadores documentais e enforcement JaCoCo do backend.
non_objectives: Corrigir em massa a dívida legada de cobertura ou arquivos grandes, executar ambientes externos, fazer deploy, obter credenciais, forçar push, integrar branches ou modificar histórico Git.
owner: Arquitetura e Qualidade
status: In Progress
date: 2026-09-08
version: 1.8
keywords: clear, quality-gate, cobertura, métricas, comentários, tamanho-de-arquivo, git, branch, push, conventional-commits, skill, scaffold, ADR-0000
related_files: harness/governance/decisions/ADR-0000-governanca-do-harness-documental.md, harness/governance/project-settings/settings.md, do../../agents/standards/software-engineering-lifecycle.md, do../../agents/standards/software-quality-standard.md, ../agents/standards/backend-testing-standard.md, do../../agents/standards/development-standard.md, do../../agents/skills/README.md, ../../backend/docs/specs/IP-BE-45.1.1-backend-jacoco-enforcement.md, ../../backend/docs/specs/IP-BE-45.1.2-backend-failsafe-global-discovery.md
code_references: backend/pom.xml, backend/src/test/java/br/com/duoset/saas_service/BackendFailsafeEffectivePomContractTest.java, infra/scripts/validate-quality-metrics.mjs, validate-quality-metrics.test.mjs, infra/scripts/validate-plan-granularity.mjs, validate-plan-granularity.test.mjs, validate-quality-policy.mjs, validate-quality-policy.test.mjs, infra/scripts/validate-quality-metrics.mjs, infra/scripts/validate-plan-granularity.mjs, infra/scripts/validate-quality-gates.sh, infra/scripts/tests/validate-quality-gates-test.sh, .agents/skills/quality-gate/SKILL.md, .claude/skills/quality-gate/SKILL.md
principal_statement: A portabilidade do ADR-0000 exige métricas locais determinísticas, correção iterativa limitada e entrega Git somente após todos os gates aplicáveis em PASS, sem duplicar limiares normativos nas skills.
---

# TP-00045 — Governança do Quality Gate C.L.E.A.R.

## Extensão v1.8 — discovery materializado e gates globais ainda abertos

O filho `IP-BE-45.1.2-backend-failsafe-global-discovery` v1.1 materializou os
dois paths autorizados. O teste de contrato passou `3/3`, o profile focal
preservado passou EPP `29/29` mais PackagingIT `3/3`, a arquitetura passou
`29/29` e o Quality Gate focused terminou em `PASS`, todos sem falha, erro ou
skip.

Esses resultados fecham somente implementação e Assurance focal de
`BE-COV-IT-DISCOVERY`. A descoberta Failsafe global de 19 ITs/81 testes,
`clean verify`, cobertura e Quality Gate PR não foram executados nem aprovados.
Cinco classes que totalizam oito testes permanecem com `@Disabled`, e a imagem
local `quay.io/keycloak/keycloak:26.6.3` necessária ao IT de realm está ausente;
portanto ainda não existe execução global zero-skip. A cobertura global não foi
avaliada, e nenhum percentual é inferido dos gates focais.

### Definition of Done da extensão v1.8

- [x] configuração global sem selector e teste de contrato materializados;
- [x] focal BE-COV `3/3`, packaging EPP `29/29` + PackagingIT `3/3`, arquitetura
  `29/29` e Quality Gate focused `PASS`;
- [ ] discovery global de 19 ITs/81 testes e `clean verify` executam uma vez, sem
  falha, erro ou skip;
- [ ] cobertura global e Quality Gate PR passam sem reduzir limiar ou exclusion;
- [x] skips, imagem ausente e limites da evidência permanecem explícitos.
- [x] governança documental agregada retorna `0`: 829 Markdown, 835 artefatos
  indexados e 228/228 operações de API cobertas.

O TP permanece `In Progress` até os dois itens globais abertos serem comprovados.

## Extensão v1.7 — descoberta global completa dos testes de integração

A auditoria do primeiro gate de retenção mostrou que o profile
`backend-pr-coverage` sobrescreveu a execution Failsafe herdada com um include
exclusivo do PackagingIT. O resultado focal permaneceu correto, mas o lifecycle
global deixou 18 classes e 78 testes invisíveis. O inventário atual possui 19
classes `*IT` e 81 testes: seis são locais, incluindo o PackagingIT, e treze usam
Testcontainers locais sem acessar providers reais.

O filho `IP-BE-45.1.2-backend-failsafe-global-discovery` possui um único handoff:
restaurar a descoberta Failsafe sem selector no profile PR e preservar o profile
focal que executa apenas EPP e PackagingIT. O effective POM corrente será gerado
no próprio lifecycle, sem Maven aninhado, e um teste de contrato impedirá que um
include, exclude ou segundo binding volte a ocultar ITs.

Esta extensão não reduz limiares, não amplia exclusions JaCoCo e não transforma
falha quantitativa de cobertura em sucesso. O `clean verify` só poderá sustentar
uma alegação global após executar os 19 ITs uma vez, com zero falha, erro ou skip;
dívida de cobertura continua pertencendo ao filho 45.1.1 e a remediações por
bounded context.

## Extensão v1.6 — cobertura atual e fail-closed

A reauditoria do bootstrap identificou que JaCoCo pode ignorar uma fase sem dados
e preservar `target/site/jacoco/jacoco.xml` de uma execução anterior. A unidade
`BE-COV-BOOT` continua semanticamente única, mas passa a abranger o executor e seu
teste de contrato: `backend/pr` executa `clean verify`, removendo o diretório
gerado antes de produzir os arquivos unitário/integrado atuais, consolidá-los e
aplicar report/check. ADR-0000 v4.21 e Backend Testing v1.11 congelam esse contrato;
somente o bootstrap Spring exato e código gerado ficam fora da cobertura.

O IRG detalhado do `IP-BE-45.1.1-backend-jacoco-enforcement` v1.3 autoriza somente o POM, o executor e seu
teste hermético. Não altera código de produto, limiares, exclusions, profiles
parciais nem CI externo. O resultado observável é único: XML ausente, histórico ou
abaixo do limiar nunca pode concluir `backend/pr` em `PASS`.

## Extensão v1.5 — enforcement JaCoCo no backend Java 25

Esta extensão reabre o plano para remover o blocker global e fail-closed do gate
`backend/pr`. O trabalho foi decomposto semanticamente:
`IP-BE-45.1.1-backend-jacoco-enforcement` ativa a
instrumentação, o report XML e o check global; eventual dívida quantitativa
descoberta pelo primeiro relatório será repartida depois por bounded context, sem
reduzir limiares ou ampliar antecipadamente os paths do filho de bootstrap.

### Gate Audit

- **Product Definition:** `N/A`; configuração de Assurance não altera
  comportamento de produto.
- **Requirements:** pedido humano de executar o loop C.L.E.A.R. até todos os PRDs
  materializados e contrato normativo do Quality Gate.
- **ADRs:** ADR-0000 v4.21 `Accepted`.
- **Use Cases / API Contract:** `N/A`; não há jornada nem operação HTTP.
- **Assumptions / Open Questions:** nenhuma; Java, limiares, exclusions e lifecycle
  Maven estão definidos.
- **Dependencies:** Java 25 concluído no TP-00041 v1.3; executor e métricas do
  TP-00045 v1.4 disponíveis; Backend Testing Standard v1.11 ativo.
- **Granularity / Decomposition:** `PASS`; pai `TP-00045` → filho
  `IP-BE-45.1.1-backend-jacoco-enforcement` para bootstrap do enforcement →
  filhos futuros somente se a
  medição provar dívida em contextos independentes.

### Contrato e estado

- **What:** fazer `backend/pr` executar `clean verify`, produzir JaCoCo XML atual e
  exigir 80% de instruções e 70% de branches.
- **Where:** standard de testes, plano filho e `backend/pom.xml`.
- **Prohibited:** snapshot, exclusão além do standard, redução de limiar, skip,
  falso verde ou acesso a provider externo.
- **Mandatory:** preservar a composição dos agentes JaCoCo/Mockito, executar
  testes e registrar o primeiro baseline sem ocultar falha.
- **Estado:** `In Progress`; o readiness detalhado e os paths exatos estão no
  `IP-BE-45.1.1-backend-jacoco-enforcement`. O pai volta a `Completed` somente
  com o gate `backend/pr` em
  `PASS` e eventuais filhos de remediação concluídos.

## Extensão v1.4 — enforcement de granularidade de TP/IP

Esta extensão adiciona uma única unidade observável, `TP-00045-PG`: detectar em
targets explícitos todo Task Plan ou Implementation Plan acima de 500 linhas ou
64 KiB, exigir evidência estruturada de revisão semântica e impedir o `PASS` do
Quality Gate enquanto a revisão ou decomposição automática pelo IRG não estiver
materializada.

### Gate Audit

- **Product Definition:** `N/A`; governança e tooling interno sem comportamento de
  produto.
- **Requirements:** pedido humano explícito e contrato vigente dos índices de
  TP/IP.
- **ADRs:** ADR-0000 v4.18 `Accepted`, a ser versionado nesta extensão.
- **Use Cases:** `N/A`; nenhuma interação de usuário ou API.
- **Assumptions:** nenhuma; limites, estados e integração já estão definidos.
- **Open Questions:** nenhuma.
- **Dependencies:** quality profile e executor do TP-00045 v1.3 disponíveis.
- **API Contract:** `N/A`; nenhuma API HTTP é criada, alterada ou consumida.
- **Granularity / Decomposition:** `PASS`; um resultado único e reversível, com
  parser, wrapper, testes e integração documental pertencentes ao mesmo gate.

### Contrato atômico

- **What:** tornar o limiar de tamanho de TP/IP uma regra executável do Quality
  Gate sem substituir a avaliação semântica do IRG.
- **Where:** ADR-0000, Software Quality Standard, templates e índices de planos,
  skills pareadas, scripts portáteis em ``, wrappers/testes em
  `infra/scripts/` e adaptadores Git afetados.
- **Depends on:** TP-00045-QM e Implementation Readiness Standard v1.5.
- **Reuses:** interface `--target`, estados `PASS`/`FAIL`/`BLOCKED`, Node.js nativo,
  wrapper fino e teste hermético já adotados pelo quality profile.

### Acceptance Tests

- Plano abaixo dos limites resulta em `PASS` sem exigir revisão.
- Plano acima de qualquer limite sem revisão estruturada resulta em `FAIL` e
  aciona retorno ao IRG, nunca `BLOCKED` final por granularidade.
- Resultado `Decomposed` exige ao menos dois IDs filhos; resultado
  `Semantically indivisible` exige justificativa não vazia e rastreável.
- Target inexistente ou fora de `docs/delivery/plans/` resulta em `BLOCKED` ou erro de
  uso, conforme a classe do problema.
- O executor chama o validador para targets TP/IP em `docs` e `all`, preservando
  targets explícitos e o gate documental agregado.
- A política Git autoriza somente preparar e publicar a branch para futuro PR por
  `git add`, `git commit` e `git push` depois dos gates; não autoriza criar o PR,
  fazer merge, tag ou deploy.

### Prohibited

- Inferir qualidade semântica apenas pelo tamanho, dividir por contagem de linhas,
  aceitar placeholder como justificativa, descobrir targets por Git ou tornar
  falha de granularidade um `BLOCKED` final.
- Executar Git, rede, instalação, produção ou ler credenciais nesta extensão.

### Mandatory

- Atualizar teste do validador, contrato do executor e regressão normativa.
- Manter corpo canônico e teste em ``, com wrapper fino em
  `infra/scripts/`.
- Reexecutar o gate após cada correção até `PASS` ou blocker real não relacionado
  à granularidade.

### Resultado de readiness

`READY` para `TP-00045-PG` e os paths declarados nesta extensão. As fontes são
determinísticas, não há decisão pendente e a Definition of Done é binária pelos
testes acima. A extensão não autoriza operação Git; apenas altera sua política
documentada.

### Handoff da extensão v1.4

- O corpo canônico e o teste hermético de granularidade residem em
  ``; o wrapper de `infra/scripts/` apenas encaminha `main()`.
- TP/IP abaixo de 500 linhas e 64 KiB passa sem revisão adicional. Acima de
  qualquer limiar, revisão ausente, incompleta ou incoerente produz `FAIL`.
- O executor chama o controle para targets documentais explícitos e preserva
  `BLOCKED` apenas para target/ferramenta ausente; a correção semântica retorna ao
  IRG e é reexecutada até `PASS` ou blocker real.
- Standards, ADR, templates, índices, skills pareadas e adaptadores foram
  reconciliados. O fluxo Git ficou limitado à preparação/publicação da branch para
  PR por add explícito, commit e push, sem abertura ou integração do PR.
- Testes unitários, contrato do executor, regressão normativa, governança agregada
  e Quality Gate `infra/pr` terminaram em `PASS`. Nenhum comando Git, rede,
  instalação, produção ou credencial foi usado.

## Extensão v1.2 — métricas, correção iterativa e entrega Git

Esta extensão reabre o plano em três unidades semânticas independentes, coordenadas
por este documento e sem criar um novo produto ou serviço externo:

| Unidade | What | Where | Depends on | Resultado esperado |
| --- | --- | --- | --- | --- |
| TP-00045-QM | Medir cobertura, tamanho e higiene de comentários com saída local semelhante a um quality profile do SonarQube. | `infra/scripts/validate-quality-metrics.mjs`, wrapper em `infra/scripts/` e testes. | ADR-0000 v4.17 e Software Quality Standard v1.1. | `PASS`, `FAIL` ou `BLOCKED`, legível por humano e máquina. |
| TP-00045-QL | Tornar obrigatório o ciclo medir, corrigir e reexecutar enquanto houver progresso verificável. | ADR, lifecycle, standards, templates, agentes e skills. | TP-00045-QM. | Handoff apenas com A1/A2/A3 aplicáveis em `PASS`; impasse real permanece `BLOCKED`. |
| TP-00045-GIT | Autorizar branch, commit e push governados depois do quality gate integral. | ADR, settings, adapters e quality gate. | TP-00045-QL e branch conforme contrato. | Push somente da branch de trabalho exata; nenhuma autorização de merge, tag, force-push ou branch protegida. |

### Contrato atômico TP-00045-QM

- **Reuses:** relatórios JaCoCo XML, LCOV, Node.js nativo e os estados
  `PASS`/`FAIL`/`BLOCKED`; nenhuma instalação ou serviço externo.
- **Requirements:** backend exige no mínimo 80% de instruções e 70% de branches;
  frontend e website exigem no mínimo 70% de lines, branches e functions. Relatório
  ausente ou inválido produz `BLOCKED`.
- **Targets:** os arquivos alterados são entradas explícitas `--target`; o executor
  não usa Git para descobri-los. Arquivo fonte selecionado acima de 500 linhas,
  comentário textual acima de 100 caracteres, bloco contíguo acima de 12 linhas,
  código comentado ou `TODO`/`FIXME` sem identificador rastreável produz `FAIL`.
  Densidade de comentários é apenas informativa e nunca incentiva comentários
  artificiais.
- **Compatibilidade:** dívida preexistente fora dos targets não falha o recorte;
  um arquivo legado acima do limite passa a exigir decomposição quando selecionado
  por uma mudança.

### Gate Audit

- PRD: não aplicável; a mudança é governança/tooling interno sem comportamento de
  produto.
- Fontes: pedido humano explícito, ADR-0000 v4.17, Software Quality Standard v1.1,
  Lifecycle v1.10 e TP-00045 v1.2.
- Incertezas resolvidas: `X.Y.Z` é a coordenada numérica da task/IP; o tipo é
  `docs`, `feat` ou `fix`; a descrição é kebab-case minúscula.
- Contrato de API: não aplicável; nenhuma API HTTP é criada ou alterada.
- Granularity / Decomposition: `PASS`; QM, QL e GIT têm handoffs e ciclos de
  validação próprios, com dependências explícitas acima.
- Segurança operacional: push não lê credenciais, não muda remote e não inclui
  branch protegida; falha de autenticação, rede ou proteção termina `BLOCKED`.

### Acceptance Tests

- Fixtures herméticas aprovam e rejeitam JaCoCo, LCOV, tamanho e comentários.
- O executor canônico encaminha targets, certifica o modo de entrega e permanece
  fail-closed quando faltarem relatório, target ou branch válida.
- O validador documental reconhece a expressão canônica de branch e impede que
  adapters ou skills restabeleçam autorização mais ampla.

### Prohibited

- Descobrir escopo por Git, reduzir limiar, criar densidade mínima de comentários,
  repetir sem progresso, ocultar `FAIL`/`BLOCKED` ou editar código fora dos targets.
- Push para `main`, `master`, `develop` ou `release/*`; force-push, exclusão remota,
  tag, merge, rebase, reset, alteração de remote, leitura de credencial ou deploy.

### Mandatory

- Testes focais e impactados, saída humana e JSON, registro das iterações e parada
  segura em `PASS` ou blocker externo/decisão humana real.
- Branch `X.Y.Z-{docs,feat,fix}-short-description` e commits compatíveis com
  Conventional Commits 1.0.0, com tipo coerente com a natureza da branch.

### Definition of Done da extensão

- [x] Ferramenta métrica portátil, wrapper e testes aprovados.
- [x] Executor, standards, lifecycle, templates, agentes e skills reconciliados.
- [x] Política Git restrita e verificável reconciliada em ADR, settings e adapters.
- [x] Quality gate focal e validação documental executados, sem falso verde.

### Resultado de readiness

`READY` para os paths e versões declarados nesta extensão. A divergência documental
preexistente do TP/IP-00054 é externa a QM/QL/GIT: não autoriza corrigi-la neste
plano, mas impede o gate documental agregado e, portanto, qualquer push até sua
resolução pelo owner daquele escopo.

## Fontes superiores

- [ADR-0000](../../../harness/governance/decisions/ADR-0000-governanca-do-harness-documental.md).
- [Software Engineering Lifecycle](../../agents/standards/software-engineering-lifecycle.md).
- [Standards de teste](../agents/standards/backend-testing-standard.md) e
  [frontend](../agents/standards/frontend-testing-standard.md).
- [TPL-00009 — Template de skill](../../../harness/templates/TPL-00009-skill-operacional.md).

## Escopo de execução

1. Definir explicitamente no lifecycle a decomposição Test Gate, Quality Gate e
   Security/Compliance Gate da etapa Assurance do C.L.E.A.R.
2. Criar um standard transversal para seleção, critérios, evidência, waiver e
   resultado dos quality gates, preservando limiares específicos nos standards de
   cada pacote.
3. Tornar obrigatórios no scaffold do ADR-0000 o standard, a skill `quality-gate`
   pareada, o executor `validate-quality-gates.sh` e seu teste hermético.
4. Documentar no próprio ADR o código-base portável, a ordem de bootstrap e o modo
   de uso do executor, inclusive quando o projeto de destino ainda não possui o
   arquivo.
5. Fazer o validador documental impedir ausência, divergência entre runtimes ou
   perda do contrato técnico portável.
6. Atualizar templates, mapas, catálogos e settings diretamente afetados.

## Restrições

- Standards preservam regras, critérios e limiares; skills preservam workflow e
  não duplicam a fonte normativa.
- O executor não descobre mudanças por Git, não instala dependências, não acessa
  rede, produção, dados reais ou segredos.
- Um gate não executável ou sem evidência termina como `BLOCKED`, nunca como
  aprovação implícita.
- Gaps preexistentes de cobertura/configuração serão reportados com honestidade;
  sua remediação funcional exige plano próprio quando extrapolar este corte.

## Critérios de aceite

- O ADR-0000 memoriza os quatro artefatos obrigatórios, a ordem de scaffold, o
  código-base e o uso do executor.
- O lifecycle e o novo standard distinguem Teste de QA e definem a matriz mínima
  por escopo e nível.
- As duas variantes de `quality-gate` são idênticas, válidas e usam exclusivamente
  o executor canônico para orquestração.
- O executor é fail-closed, possui ajuda, escopos e níveis explícitos e emite
  `PASS`, `FAIL` ou `BLOCKED` sem usar Git.
- O teste hermético cobre sucesso, erro de uso, configuração ausente e bloqueio do
  build diante de arquivo local de ambiente.
- `./infra/scripts/validate-docs.sh` executa o teste de contrato e termina com
  código `0` no estado final.

## Estratégia de validação

- `bash -n` no executor, no wrapper documental e no teste shell.
- Teste hermético focal de `validate-quality-gates.sh`.
- `node --check` e suíte do validador de governança documental.
- Validação das duas skills com `quick_validate.py` e comparação byte a byte.
- Gate agregado `./infra/scripts/validate-docs.sh`.

## Handoff e evidência

O recorte de governança foi concluído. A execução reproduzível produziu:

| Verificação | Resultado |
| --- | --- |
| `bash -n infra/scripts/validate-quality-gates.sh` | `PASS`. |
| `bash -n infra/scripts/tests/validate-quality-gates-test.sh` | `PASS`. |
| `bash infra/scripts/tests/validate-quality-gates-test.sh` | `PASS`, 7 cenários herméticos. |
| `node validate-documentation-governance.test.mjs` | `PASS`, 22/22 testes. |
| `quick_validate.py` nas duas variantes de `quality-gate` | `PASS`; comparação byte a byte também aprovada. |
| `npm run typecheck`, em `frontend/` | `PASS` após introdução do `tsconfig.quality.json`, isolado de outputs `.next*`. |
| `./infra/scripts/validate-docs.sh` | `PASS` no fechamento; inclui contrato documental, teste do Quality Gate, IP-INFRA e estrutura legada. |

O primeiro gate real `frontend/pr`, executado antes do endurecimento de arquivos de
ambiente, comprovou A1 com 190 arquivos e 1.184 testes aprovados, mas terminou
`FAIL`: cobertura de linhas/statements em 67,92% abaixo do limiar configurado de
70%, format check não conforme e build impedido pelo sandbox ao tentar abrir porta.
Lint terminou com zero erros e 54 warnings; typecheck passou. O Next anunciou a
presença de `.env.local`; nenhum valor foi inspecionado ou registrado. Em resposta,
o executor e o baseline do ADR passaram a detectar somente a existência dos paths
`.env*` e bloquear o build antes de invocá-lo.

Os dry-runs finais preservam os gaps do produto como estado explícito, fora do
objetivo deste plano:

- `frontend/pr`: `BLOCKED` pela presença de `frontend/.env.local`; comandos de
  cobertura, lint, typecheck e format check permanecem selecionados.
- `backend/pr`: `BLOCKED` porque `backend/pom.xml` não materializa plugin JaCoCo e
  goal `check`.
- `website/pr`: `BLOCKED` porque não há configuração/limiares Vitest de cobertura
  nem script `test:coverage`.

Não houve Git, instalação, download, rede, produção ou sistema externo. A correção
dos três gaps de pacote exige planejamento próprio; eles não invalidam a conclusão
do scaffold, que agora os reporta sem falso verde.

## Handoff da extensão v1.3

As unidades QM, QL e GIT foram concluídas no repositório. Para não ampliar o
validador legado acima de 1.600 linhas, o enforcement novo foi decomposto no
`validate-quality-policy.mjs` e em seu teste; todos os novos arquivos executáveis e
os scripts de infra alterados permaneceram abaixo de 500 linhas e passaram no
próprio profile.

| Evidência | Resultado |
| --- | --- |
| `node --test validate-quality-metrics.test.mjs` | `PASS`. |
| `node --test validate-quality-policy.test.mjs` | `PASS`. |
| `node validate-quality-policy.mjs --root .` | `PASS`. |
| `bash infra/scripts/tests/validate-quality-gates-test.sh` | `PASS`, 10 cenários. |
| `./infra/scripts/validate-quality-gates.sh --scope infra --level pr ...` | `PASS`; sintaxe de todos os scripts, testes do tooling e métricas dos quatro targets aprovados. |
| Quality metrics nos quatro sources de `` da extensão | `PASS`; 301, 115, 155 e 51 linhas. |
| Quality metrics nos quatro scripts alterados de `infra/` | `PASS`; maior arquivo com 377 linhas. |
| Governança documental integrada e cobertura OpenAPI | `PASS`; 791 Markdown, 31 diretórios, 790 indexados e 228/228 operações implementadas cobertas. |
| `./infra/scripts/validate-docs.sh` | `BLOCKED` somente na travessia final por referências canônicas abreviadas em TP/IPs concorrentes 00054, 8.x e 36.x. |

Não houve comando Git nem push. Embora a política nova esteja materializada, a
entrega permanece inelegível enquanto o blocker externo impedir todos os gates
aplicáveis em `PASS`.

## Change log

| Versão | Data | Mudança |
| --- | --- | --- |
| 1.8 | 2026-09-12 | Registra BE-COV-IT-DISCOVERY implementado e gates focal `3/3`, packaging `29/29+3/3`, arquitetura `29/29` e QG focused verdes; preserva discovery/clean verify, cobertura e PR/global abertos por cinco classes/oito testes disabled e imagem Keycloak 26.6.3 ausente. |
| 1.7 | 2026-09-12 | Decompõe BE-COV-IT-DISCOVERY no IP-BE-45.1.2-backend-failsafe-global-discovery para restaurar 19 ITs/81 testes no Failsafe global, preservar o PackagingIT focal e impedir novo selector oculto pelo effective POM. |
| 1.6 | 2026-09-12 | Torna o bootstrap fail-closed contra artefatos históricos: arquivos JaCoCo por fase, merge atual e `clean verify` no executor canônico. |
| 1.5 | 2026-09-12 | Reabre o plano e decompõe o blocker global do backend no IP-BE-45.1.1-backend-jacoco-enforcement, com JaCoCo estável compatível com Java 25 e remediações quantitativas condicionadas à primeira medição. |
| 1.4 | 2026-09-10 | Reabre PG com readiness READY para tornar executável o limiar e a revisão semântica de TP/IP no Quality Gate e esclarecer a entrega Git como preparação/publicação da branch para PR. |
| 1.3 | 2026-09-10 | Conclui QM/QL/GIT com ferramenta, testes, enforcement pequeno, documentação reconciliada e bloqueio externo preservado sem realizar push. |
| 1.2 | 2026-09-10 | Reabre o plano com readiness READY e decomposição QM/QL/GIT para métricas locais, loop de correção limitado e push governado pós-gates. |
| 1.1 | 2026-09-08 | Conclui standard, skill pareada, executor, teste, templates e scaffold portátil; registra gates reais e gaps fail-closed por pacote. |
| 1.0 | 2026-09-08 | Persiste o plano transversal antes das edições de governança, skills, scripts e templates. |
