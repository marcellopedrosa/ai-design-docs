---
document_id: TP-00073
primary_nature: Plano
objective: Extrair a geração do keyring HMAC de tentativas outbound para um script seguro e de responsabilidade única.
scope: Gerador local, integração do bootstrap DEV, testes herméticos, proteção Git dos destinos de keyrings e documentação operacional HML/PRD.
non_objectives: Não gerar, copiar ou instalar segredos reais; não executar deploy; não rotacionar keyrings existentes; não alterar o contrato criptográfico do backend.
owner: Engenharia, Segurança e DevOps
status: Completed — repository-local
version: 1.12
date: 2026-10-02
last_reviewed: 2026-10-05
keywords: keyring, hmac, outbound, csprng, segredo, provisionamento
related_files: ../../backend/docs/onboarding/conversation-audit-keyring-provisioning.md, docs/delivery/plans/TP-00072-production-keyring-infra-request.txt
code_references: .gitignore, Dockerfile.dev-bot, start-dev-bot.sh, infra/scripts/generate-outbound-attempt-hmac-keyring.sh, infra/scripts/tests/generate-outbound-attempt-hmac-keyring-test.sh, backend/docker/outbound-hmac-keyring-lifecycle.sh
principal_statement: A geração do conversation-outbound-attempt-hmac-keyring.json deve ocorrer somente por um gerador explícito, fail-closed e sem sobrescrita, antes de seu provisionamento pela Infra.
---

# TP-00073 — Gerador do keyring HMAC de tentativas outbound

## Decisão e contrato

O procedimento inline do `start-dev-bot.sh` será extraído para
`infra/scripts/generate-outbound-attempt-hmac-keyring.sh`. O script terá uma única
responsabilidade: criar um keyring novo, com um ID informado, em um caminho
informado. Ele não instala o arquivo no container, não altera ambiente, não faz
deploy e não rotaciona arquivo existente.

O nome canônico é `conversation-outbound-attempt-hmac-keyring.json`, com uma única
extensão `.json`. O formato permanece `{"keys":{"<key-id>":"<base64>"}}`, com
32 bytes gerados por `openssl rand`, arquivo `0600` e diretório `0700`.

## Tarefas atômicas

### TP-00073-T01 — Materializar o procedimento

- **What:** registrar contrato, comandos, riscos e handoff operacional.
- **Where:** este plano, o guia de keyrings e seus índices imediatos.
- **Depends on:** aprovação explícita do usuário em 2026-10-02.
- **Reuses:** contrato validado pelo loader backend e pelo lifecycle existente.
- **Requirements:** documentação deve anteceder qualquer edição executável.
- **Definition of Done:** documentação validada e TP-00073-T02 marcado `READY`.

### TP-00073-T02 — Extrair e integrar o gerador

- **What:** criar o gerador fail-closed, fazer o bootstrap DEV invocá-lo e provar
  seu comportamento com testes herméticos.
- **Where:** `infra/scripts/generate-outbound-attempt-hmac-keyring.sh`,
  `start-dev-bot.sh` e `infra/scripts/tests/generate-outbound-attempt-hmac-keyring-test.sh`.
- **Depends on:** TP-00073-T01 concluída; `bash`, `openssl`, `mktemp`, `realpath`, `stat` e
  filesystem local com escrita no destino.
- **Reuses:** regex de ID `^[A-Za-z0-9._-]{1,64}$`, contrato de 32 bytes e
  validação do `backend/docker/outbound-hmac-keyring-lifecycle.sh`.
- **Requirements:** `--output` e `--active-key-id` obrigatórios; recusar symlink,
  arquivo já existente, ID inválido e destino inseguro; escrita temporária e
  publicação atômica; nunca imprimir material criptográfico.
- **Gate Audit:** PRD não aplicável, pois não há mudança de produto, API ou regra
  de domínio. Fontes e paths foram verificados no repositório. Não há hipótese
  funcional aberta; produção e credenciais permanecem fora do escopo.
- **Acceptance Tests:** gerar JSON válido com chave de 32 bytes; garantir modos
  `0700/0600`; rejeitar overwrite, symlink e ID inválido; confirmar ausência do
  segredo no stdout/stderr; manter o fluxo DEV existente.
- **Prohibited:** ler `.env`; aceitar chave por argumento; sobrescrever keyring;
  versionar o artefato; gerar segredo de PRD nesta execução; fazer deploy.
- **Mandatory:** A1 focal, A2 shell/documentação, A3 Security/Compliance e handoff
  com limitações explícitas.
- **Definition of Done:** script e integração testados sem skips; guia contém o
  comando canônico para HML/PRD; nenhum segredo é criado dentro do repositório.

## Implementation Readiness Gate

**Result: READY** — 2026-10-02, exclusivamente para TP-00073-T02.

As versões, paths, contrato, dependências, critérios de aceite e proibições estão
determinados. O usuário aprovou a extração; não existe decisão humana pendente
para a implementação repository-local. O provisionamento real continua sendo um
handoff separado para Segurança/DevOps.

Reauditoria v1.2 em 2026-10-02: TP-00073-T02 permanece `READY` nos mesmos
paths, fontes e critérios; TP-00073-T03 possui `READY` independente abaixo.

Reauditoria v1.3 em 2026-10-02: usuário decidiu restaurar o wrapper DEV; a
fonte histórica e os critérios do contrato estão identificados em T04. T02 e T03
permanecem `READY` nos respectivos paths e fontes.

Reauditoria v1.4 em 2026-10-02: usuário autorizou reconciliar os validadores
locais com o harness v2. T05 e T06 são unidades independentes; T02–T04 mantêm
as fontes e paths já auditados.

Reauditoria v1.5 em 2026-10-02: T07 trata o teste de regressão impactado e seu
limite de tamanho sem reduzir cobertura. As fontes e o comportamento esperado
estão no teste vigente, no Compose atual e no standard de qualidade v1.3.

Reauditoria v1.6 em 2026-10-02: sem resposta à preferência opcional de
decomposição, segue a solução estrutural exigida pelo standard de qualidade.
T08 conserva a ordem de execução e atualiza somente os consumidores locais que
copiam ou inspecionam o launcher.

Reauditoria v1.7 em 2026-10-02: o usuário escolheu conservar o reset Docker
global atualmente implementado. Essa escolha divergia do ADR-0016 v1.6 e do
REQ-00045 v1.10, que exigem reset limitado ao projeto e continuação pelo start
canônico. A revisão dos testes de reset e bootstrap recebe `BLOCKED` até que
uma decisão sucessora aceita e o requisito aprovado estabeleçam o novo contrato.
Nenhuma limpeza Docker real está autorizada por esta reauditoria.

Reauditoria v1.8 em 2026-10-02: o usuário confirmou expressamente o alcance
global e aprovou a sucessão do contrato. ADR-0056 v1.0 `Accepted` e REQ-00045
v1.11 `Approved` resolvem o conflito para T09. PRD não aplicável, pois esta é
uma operação técnica local sem alteração de produto. A decisão humana, os paths,
as dependências e o aceite abaixo estão fechados; T09 recebe `READY` somente
para edição de repositório e testes herméticos, sem execução do reset real.

### TP-00073-T03 — Impedir staging dos keyrings operacionais

- **What:** ignorar os diretórios locais de segredos referenciados pelo guia.
- **Where:** `.gitignore`.
- **Depends on:** guia de provisionamento v1.1 e restrições de segurança.
- **Gate Audit:** PRD não aplicável; proteção de artefatos locais sem alteração
  funcional. Paths exatos: `/.deploy/secrets/` e `/.deploy/hml/secrets/`.
- **Acceptance Tests:** `git check-ignore` confirma os dois paths.
- **Prohibited:** criar, ler ou versionar qualquer chave real.
- **Mandatory:** validação documental, `git diff --check` e revisão A3.
- **Definition of Done:** ambos os destinos de keyrings são ignorados pelo Git.
- **Result:** `READY` em 2026-10-02 para o path e fontes acima.

### TP-00073-T04 — Restaurar o Dockerfile do wrapper DEV

- **What:** restaurar o contrato do wrapper DEV removido em `f741ca21`.
- **Where:** `Dockerfile.dev-bot`.
- **Depends on:** decisão do usuário de 2026-10-02, conteúdo histórico
  `f741ca21^:Dockerfile.dev-bot`, `REQ-00045` v1.10.
- **Gate Audit:** PRD não aplicável; o wrapper DEV já está definido pelo requisito
  implementado e seus consumidores. Nenhuma hipótese técnica aberta para a
  restauração literal.
- **Acceptance Tests:** `cmp` com o conteúdo histórico, verificações de pacotes
  no teste existente e validação de contrato sem construir imagem.
- **Prohibited:** construir/publicar imagem, acessar Docker ou ambiente real.
- **Mandatory:** A1 contrato, A2 revisão de arquivo e A3 segurança.
- **Definition of Done:** arquivo restaurado literalmente e consumidores locais
  capazes de encontrá-lo; falhas adicionais da suíte são registradas sem waiver.
- **Result:** `READY` em 2026-10-02 para este path e fontes.

### TP-00073-T05 — Reconciliar o validador documental local

- **What:** corrigir as rotas de validadores e coleções migradas no wrapper
  documental, preservando checks de projeto ainda aplicáveis.
- **Where:** `infra/scripts/validate-docs.sh`,
  `infra/scripts/validate-ip-infra-docs.sh`,
  `infra/scripts/tests/validate-ip-infra-docs-test.sh` e rótulos de links em
  `../agents/AgentOrchestrator.md`, `../agents/RequirementAgent.md`,
  `../agents/standards/project-reporting-standard.md`,
  `docs/analysis/ANL-00055-backend-api-contract-coverage-inventory.md`,
  `docs/delivery/plans/README.md`,
  `TP-00045-clear-quality-gate-governance.md`,
  `TP-00052-backend-api-contract-baseline.md`,
  `TP-00053-product-feature-acceptance-coverage.md` e
  `TP-00071-flyway-historical-checksum-recovery.md`.
- **Depends on:** ADR-0000 aceito, harness v2 e estrutura vigente de `docs/`.
- **Gate Audit:** PRD não aplicável. O usuário autorizou a reconciliação;
  os validadores canônicos existem em `harness/tooling/validators/`. Não há
  decisão de produto ou arquitetura aberta.
- **Acceptance Tests:** wrapper executa testes canônicos, checks locais e
  validadores documentais com zero falhas; `harness.mjs check` permanece verde.
- **Prohibited:** eliminar checks aplicáveis somente para obter PASS ou mover
  artefatos project-owned sem plano próprio.
- **Mandatory:** A1 do wrapper, A2 documental e A3 de paths/segredos.
- **Definition of Done:** `./infra/scripts/validate-docs.sh` conclui com sucesso
  sobre a árvore vigente, sem suprimir validações aplicáveis.
- **Result:** `READY` em 2026-10-02 para os paths e fontes acima.

### TP-00073-T06 — Reconciliar gate de PR de Infra

- **What:** alinhar testes do gate às rotas canônicas e configurar a proteção
  de `main` já exigida pela política Git local.
- **Where:** `infra/scripts/validate-quality-gates.sh`,
  `infra/scripts/validate-plan-granularity.mjs`,
  `infra/scripts/tests/validate-quality-gates-test.sh` e
  `infra/quality-gate-policy.json` quando requerido pelo executor.
- **Depends on:** política Git v1.2, software-quality-standard v1.3,
  validador canônico do harness v2 e T05.
- **Gate Audit:** PRD não aplicável. A política local protege `main` e não fixa
  padrão de nomes de branch; o gate deve refletir exatamente essa decisão.
- **Acceptance Tests:** teste de contrato do gate, métricas com policy explícita
  e gate de PR/entrega na branch de trabalho; falhas reais permanecem visíveis.
- **Prohibited:** reduzir limiar de 500 linhas, omitir target alterado ou
  enfraquecer regra de proteção da `main`.
- **Mandatory:** A1, A2, A3 e `--delivery` com branch e paths explícitos.
- **Definition of Done:** gate de PR retorna PASS com todos os targets alterados
  ou registra causa material remanescente sem falso PASS.
- **Result:** `READY` em 2026-10-02 para os paths e fontes acima.

### TP-00073-T07 — Atualizar e decompor a regressão do bootstrap DEV

- **What:** preservar a execução da suíte existente em partes menores que 500
  linhas e alinhar o preflight Keycloak ao provisionamento atual via Admin API.
- **Where:** `infra/scripts/tests/start-dev-bot-outbound-keyring-test.sh` e
  `infra/scripts/tests/start-dev-bot-outbound-keyring/part-*.sh`.
- **Depends on:** T04, `docker-compose.override.yml`, requisito `REQ-00045`
  v1.10 e software-quality-standard v1.3.
- **Gate Audit:** PRD não aplicável. O teste de Compose ainda exigia variável
  enviada ao container Keycloak para import antigo, removido pelo fluxo Admin
  API; o Compose atual expõe o provisionador DEV. Não há hipótese funcional aberta.
- **Acceptance Tests:** todos os cenários originais executam na mesma ordem,
  `bash -n` passa em cada parte, e a asserção Keycloak verifica o provisionador
  atual sem exigir o import removido.
- **Prohibited:** suprimir cenário, diminuir limite de tamanho ou usar skip.
- **Mandatory:** A1 de regressão, A2 métricas e A3 revisão de segredo.
- **Definition of Done:** cada arquivo da suíte tem até 500 linhas, cenários
  permanecem presentes e suíte passa sem skips.
- **Result:** `READY` em 2026-10-02 para estes paths e fontes.

### TP-00073-T08 — Decompor o launcher DEV sob o limite de qualidade

- **What:** mover o corpo do launcher para partes shell de até 500 linhas,
  preservando sua ordem e suas variáveis no mesmo processo Bash.
- **Where:** `start-dev-bot.sh`,
  `infra/scripts/lib/start-dev-bot/part-*.sh`,
  `infra/scripts/tests/start-dev-bot-outbound-keyring/part-*.sh`,
  `infra/scripts/tests/generate-outbound-attempt-hmac-keyring-test.sh`,
  `infra/scripts/tests/reset-dev-bot-test.sh`,
  `infra/scripts/tests/bootstrap-development-host-test.sh` e
  `infra/scripts/tests/bootstrap-development-host/part-*.sh`.
- **Depends on:** T02, T07, teste de regressão verde e standard de qualidade
  v1.3.
- **Gate Audit:** PRD não aplicável; refatoração estrutural sem alteração de
  produto. Fonte exata é o launcher atual; não há hipótese funcional aberta.
- **Acceptance Tests:** comparação byte a byte do corpo concatenado com o
  launcher anterior, `bash -n` de todas as partes, suíte de bootstrap, suíte de
  reset, teste focal do gerador e métricas de todos os scripts alterados.
- **Prohibited:** mudar sequência, suprimir cenário, enfraquecer limite de 500
  linhas ou criar execução em processo Bash diferente.
- **Mandatory:** A1 impactada, A2 métricas/PR e A3 de paths e segredos.
- **Definition of Done:** arquivos shell alterados têm até 500 linhas, testes
  impactados passam sem skips e launcher mantém contrato operacional.
- **Result:** `READY` em 2026-10-02 para estes paths e fontes.

### TP-00073-T09 — Reconciliar o reset global com segurança e testes

- **What:** manter o reset Docker global aprovado, recusando endpoint remoto e
  comprovando o contrato em testes herméticos.
- **Where:** `reset-dev-bot.sh`, `infra/scripts/tests/reset-dev-bot-test.sh`,
  `infra/scripts/tests/reset-dev-bot-global-contract.sh`,
  `infra/scripts/tests/bootstrap-development-host/part-02.sh`, ADR-0056,
  ADR-0016 §7.2, REQ-00045, seus índices e o guia de host DEV.
- **Depends on:** decisão humana de 2026-10-02, ADR-0056 v1.0 `Accepted`,
  REQ-00045 v1.11 `Approved`, preflight Docker compartilhado disponível.
- **Reuses:** `require_direct_development_docker_access` e fixtures Docker falsas.
- **Requirements:** AC-007, AC-012 e AC-014 do REQ-00045 v1.11; somente daemon
  local; confirmação interativa literal; ordem da limpeza global; falha de
  contêiner/prune propagada; nenhum start ou Compose.
- **Gate Audit:** PRD não aplicável pela natureza operacional; decisão material
  resolvida pelo Maintainer Humano, fontes vigentes e paths exatos acima;
  hipótese aberta ausente; Docker real não é dependência dos testes.
- **Acceptance Tests:** rejeitar endpoint remoto antes de mutação; recusar
  confirmação ausente/incorreta; executar a ordem global com Docker falso;
  conferir falhas e ausência de start/Compose; bootstrap hermético mantém
  preflight e proibição de sudo Docker.
- **Prohibited:** executar Docker real, ler segredos, usar confirmação por
  ambiente, iniciar stack, esconder aviso ou reduzir limiar de qualidade.
- **Mandatory:** A1 focal/impactada, A2 shell/documentação/métricas/PR, A3
  segurança e revisão do efeito destrutivo antes de qualquer execução real.
- **Definition of Done:** testes e gates aplicáveis passam sem skips; contrato,
  avisos e limite local concordam; nenhuma limpeza Docker real foi executada.
- **Result:** `READY` em 2026-10-02 para estes paths e fontes.

### TP-00073-T10 — Reconciliar o hook Git local com a política vigente

- **What:** restaurar o entrypoint `commit-msg` ausente e validar somente os
  limites Git definidos pela política local vigente.
- **Where:** `.githooks/commit-msg`, `infra/scripts/validate-commit-message.sh`,
  `infra/scripts/tests/validate-commit-message-test.sh` e documentação de entrega
  diretamente afetada neste plano.
- **Depends on:** política `git-delivery-policy.md` v1.2, ADR-0000 v4.26 e
  autorização do usuário para reconciliar validadores legados nesta entrega.
- **Reuses:** hook histórico de `f741ca21^` e instalador local existente.
- **Requirements:** impedir commit direto na `main` ou detached HEAD e mensagem
  vazia; não impor convenção de branch ou tipo de commit ausente da política.
- **Gate Audit:** PRD não aplicável a enforcement Git; política e paths exatos
  identificados; não há hipótese material aberta; fixture Git isolada em `/tmp`.
- **Acceptance Tests:** teste de contrato do hook aceita branch de trabalho e
  mensagem válida, rejeita `main`, detached HEAD, arquivo ausente ou mensagem
  vazia, e verifica execução real do hook na fixture.
- **Prohibited:** desabilitar hook, alterar configuração Git global, escrever na
  `main` real ou diminuir gates de entrega.
- **Mandatory:** A1 focal, A2 shell/métricas/PR, A3 revisão de branch protegida.
- **Definition of Done:** hook e validador concordam com a política local; teste
  hermético passa; branch real continua separada da `main`.
- **Result:** `READY` em 2026-10-02 para estes paths e fontes.

## Evidência de conclusão — 2026-10-02

- **A1 — PASS:** `generate-outbound-attempt-hmac-keyring-test.sh` comprovou
  geração, contrato JSON, 32 bytes, modo `0600`, integração do bootstrap e
  rejeições de overwrite, symlink, ID e diretório inválidos. O lifecycle existente
  também passou. Nenhum teste foi omitido no gate focal.
- **A2 — PASS:** `bash -n` passou para gerador, bootstrap e testes; o quality gate
  oficial de Infra focal retornou `PASS`; governança documental passou com 869
  Markdown e 860 artefatos indexados; `git diff --check` passou.
- **A3 — PASS:** revisão segundo `security-standard` v1.1 e `security-gate`
  confirmou CSPRNG de 32 bytes, entrada restrita, owner/mode privados, criação
  atômica sem sobrescrita, limpeza do temporário e mensagens de baixa informação.
  Testes usaram apenas material efêmero sintético; nenhum segredo foi versionado,
  lido de ambiente ou impresso. Não houve finding comprovado.
- **Regressão ampla:** `start-dev-bot-outbound-keyring-test.sh` passou após
  restaurar o Dockerfile histórico, atualizar o preflight do provisionamento
  Keycloak via Admin API e simular owner root de forma coerente no teste hermético.
  Os cenários foram preservados em seis partes de até 446 linhas.
- **Auditoria de entrega em 2026-10-02:** `git check-ignore` confirmou os dois
  destinos operacionais de keyrings; `./infra/scripts/validate-docs.sh` passou
  com os validadores canônicos e checks locais; o gate
  `validate-quality-gates.sh --scope infra --level pr --delivery` passou com os
  scripts alterados como targets. O launcher foi decomposto em oito partes de
  até 450 linhas, mantendo a ordem no mesmo processo Bash; o gate de métricas
  do arquivo raiz passou com 20 linhas. A suíte ampla do launcher passou após
  essa mudança. A divergência inicial entre REQ-00045 e o reset foi resolvida
  por ADR-0056 e REQ-00045 v1.11; a evidência final de T09 consta abaixo.
- **A3 adicional:** gerador agora recusa symlink em ancestral do diretório de
  saída; teste negativo focal passou. Nenhum segredo real foi criado ou lido.
- **T09 A1 — PASS:** `reset-dev-bot-test.sh` comprovou com Docker falso a
  confirmação literal em terminal, recusa de endpoint remoto, alcance e ordem da
  limpeza global, propagação de falhas e ausência de Compose/start;
  `bootstrap-development-host-test.sh` comprovou o preflight compartilhado.
  A suíte ampla do launcher passou duas vezes após isolar o log do cenário de
  staging; uma execução anterior teve falha intermitente no cenário de cleanup
  do frontend, preservada como limitação de estabilidade dessa suíte.
- **T09 A2 — PASS:** `bash -n`, métricas do launcher e reset da raiz,
  `validate-quality-gates.sh` para Infra e Docs em nível PR/delivery,
  `validate-docs.sh` e `git diff --check` passaram. O reset tem 60 linhas e o
  teste de contrato global tem 142 linhas.
- **Higiene do staging:** após o primeiro `git diff --cached --check`, foram
  removidos apenas finais de arquivo em branco nas partes novas e espaços após
  a abertura de um filtro jq; sintaxe, reset, bootstrap e suíte ampla do launcher
  passaram novamente. A comparação byte a byte da divisão original foi feita
  antes dessa normalização de whitespace.
- **T09 A3 — PASS repository-local:** revisão do fluxo privilegiado confirmou
  `DOCKER_HOST` e contexto limitados a `unix:///var/run/docker.sock`, preflight
  sem sudo, aviso explícito e confirmação `LIMPAR` em TTY antes dos comandos
  mutantes. O risco residual é intencional e aprovado no ADR-0056: a limpeza
  alcança todos os projetos e volumes não utilizados do daemon local. Nenhum
  Docker real, segredo ou ambiente externo foi acessado.
- **T10 A1/A2/A3 — PASS:** `validate-commit-message-test.sh` passou em nove
  cenários herméticos; `bash -n` e métricas passaram. O hook restaurado delega ao
  validador, que recusa `main`, detached HEAD e mensagem vazia, sem impor a
  convenção de branch que a política Git v1.2 não define. `core.hooksPath` local
  já aponta para `.githooks`; a fixture comprovou a execução real do hook.
- **Fora do escopo:** geração, transporte, instalação e ativação do segredo real
  de HML/PRD continuam sob responsabilidade de Segurança/DevOps.
- **Entrega Git:** commit `34ea14a1417e85b7958c5cd8eba277b2d5d7c0a3`
  publicado em `origin/feat/tp-00073-outbound-keyring-generator` em 2026-10-02.

## Change log

| Versão | Data | Mudança |
| --- | --- | --- |
| 1.12 | 2026-10-05 | Reconcilia o estado repository-local e registra a entrega Git concluída. |
