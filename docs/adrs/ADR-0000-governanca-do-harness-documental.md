---
document_id: ADR-0000
primary_nature: Decisao
objective: Definir a referencia normativa para inicializar e manter o harness documental e as instrucoes de agentes.
scope: Topologia documental, precedencia, bootstrap, agente inicial, biblioteca de standards, lifecycle, readiness, assurance, skills, entrega Git opt-in e adaptadores Codex, Claude Code, Gemini CLI e Antigravity.
non_objectives: Nao definir dominio, stack, comandos, limiares de cobertura, release, segredos ou configuracoes pessoais.
owner: Arquitetura e mantenedores do harness
status: Accepted
version: 1.4
date: 2026-09-10
last_reviewed: 2026-09-13
keywords: governanca, bootstrap, orquestrador, standards, clear, readiness, assurance, entrega-git, portabilidade, gemini, antigravity
related_files: ../README.md, ../ai/README.md, ../settings/settings.md, ../settings/google-gemini.md, ../agents/AgentOrchestrator.md, ../agents/standards/README.md, ../agents/standards/software-engineering-lifecycle.md, ../agents/standards/implementation-readiness-standard.md, ../agents/standards/software-quality-standard.md, ../agents/skills/README.md, ../automation/README.md, ../scripts/README.md
code_references: ../../AGENTS.md, ../../CLAUDE.md, ../../GEMINI.md, ../../.agents/rules/documentation-governance.md, ../../.agents/skills/, ../../.claude/skills/, ../scripts/; hooks e validadores de entrega pertencem ao projeto adotante.
principal_statement: Todo projeto adotante converge de forma nao destrutiva para fontes tipadas, indexadas, rastreaveis e carregadas progressivamente, com readiness antes e assurance depois da implementacao.
---

# ADR-0000 — Governança do harness documental e de agentes

## 1. Contexto

Projetos operados por pessoas e agentes precisam distinguir intenção de produto,
comportamento, decisão, estado arquitetural, plano, execução e evidência. Quando
essas naturezas são misturadas, o agente carrega contexto excessivo, infere decisões
ausentes e produz handoffs não verificáveis.

O harness deve ser independente de domínio, stack e fornecedor de IA. Nomes como
`AGENTS.md`, `CLAUDE.md`, `GEMINI.md`, `.agents/rules/` e `SKILL.md` são adaptadores; os invariantes comuns
continuam sendo precedência, menor privilégio, escopo explícito, fontes canônicas,
readiness, testes e evidência.

Os termos `DEVE`, `NÃO DEVE`, `DEVERIA` e `PODE` têm sentido normativo.

## 2. Decisão

Todo projeto adotante DEVE manter:

- `docs/README.md` como mapa, sem copiar o conteúdo das coleções;
- `docs/ai/README.md` como rota curta de leitura;
- `docs/adrs/README.md` e este ADR como decisão de bootstrap;
- `docs/architecture/module-registry.md` como manifesto da topologia real;
- `docs/settings/` para política agnóstica de ambiente e assistentes;
- `docs/agents/AgentOrchestrator.md` como único agente inicial do bootstrap;
- `docs/agents/standards/` como biblioteca canônica de regras reutilizáveis,
  separando standards transversais de standards condicionais por capacidade,
  risco ou stack;
- `docs/agents/skills/README.md` para catalogar skills operacionais;
- `docs/templates/` para todo tipo recorrente;
- `docs/scripts/` quando o projeto versionar a implementação de validadores do
  harness, sem torná-la uma fonte concorrente do contrato em `docs/automation/`;
- um `README.md` em cada coleção ativa, com inventário completo;
- adaptadores globais enxutos para cada runtime suportado;
- skills de governança, readiness e quality gate em `.agents/skills/` quando
  Codex ou Google forem suportados e variantes equivalentes em `.claude/skills/`
  quando Claude Code também for suportado;
- a skill `git-delivery` nos paths nativos quando o projeto desejar disponibilizar
  uma entrega Git governada opt-in;
- mapeamento de runtime em `docs/settings/` para toda superfície suportada cuja
  descoberta, permissão ou sandbox difira do baseline agnóstico.

Gemini CLI usa `GEMINI.md` hierárquico e pode importar `AGENTS.md`; Antigravity usa
regras de workspace em `.agents/rules/`. Os dois runtimes Google e o Codex podem
reutilizar `.agents/skills/`, portanto uma árvore `.gemini/skills/` duplicada é
proibida enquanto o alias interoperável for suportado.

A convergência é idempotente e não destrutiva: inventaria primeiro, preserva o
desconhecido, cria somente o delta inequívoco e produz zero alteração quando
repetida sobre o mesmo estado conforme.

Os arquivos deste pacote são canônicos dentro do harness. Após a adoção, suas
cópias versionadas no projeto de destino tornam-se as fontes canônicas locais e
NÃO DEVEM depender normativamente de paths ou contexto do projeto de origem.

## 3. Precedência

1. Políticas organizacionais gerenciadas de segurança e compliance.
2. ADRs aceitos.
3. Standards e settings globais versionados.
4. Adaptadores globais de runtime.
5. Instruções e configurações específicas do pacote.
6. Plano e critérios de aceite da tarefa.
7. Preferências locais do usuário.

Camada inferior pode especializar, mas NÃO DEVE enfraquecer fonte superior. Em
conflito não resolvido, prevalece a regra mais restritiva e o owner é acionado.

## 4. Separação das fontes

| Camada | Pergunta | Fonte |
| --- | --- | --- |
| Ambiente e assistente | Sob quais limites o trabalho ocorre? | `docs/settings/` |
| Funcional e técnica | Por que, o que e como o sistema é definido? | Coleções tipadas em `docs/` |
| Operação do runtime | Como instruções e comandos são descobertos? | Adaptadores e configuração nativa |

O manual `docs/ai/README.md` apenas navega entre essas camadas.

### 4.1 Taxonomia documental

| Tipo | Fonte canônica | Conteúdo permitido |
| --- | --- | --- |
| Negócio | `docs/business/` | Motivação, público, glossário e regras de negócio. |
| PRD | `docs/product_requirements/` | Problema, evidência, outcomes, limites, métricas, hipóteses e mapa de requirements. |
| Requirement | `docs/requirements/` | Comportamento, restrições e critérios de aceite. |
| Use case | `docs/use_cases/` | Fluxos principal, alternativos e de exceção. |
| ADR | `docs/adrs/` | Escolha, alternativas, consequências e lifecycle. |
| Arquitetura | `docs/architecture/` | Estado atual, módulos, dependências e interfaces. |
| Contrato | `docs/contracts/` | Interface canônica e versionada entre produtores e consumidores. |
| Plano | `docs/task_plans/` | Escopo, sequência, dependências, gates e handoffs. |
| Agente | `docs/agents/` | Papel, gatilhos, entradas, saídas, limites e handoffs. |
| Standard | `docs/agents/standards/` | Regra técnica reutilizável e verificável. |
| Skill operacional | Diretório nativo do runtime | Procedimento repetível, autocontido e carregado sob demanda. |
| Template | `docs/templates/` | Forma de criação de um tipo documental. |
| Análise | `docs/analysis/` | Diagnóstico que alimenta uma fonte canônica. |
| Histórico | `docs/reports/`, `docs/lessons_learned/`, `docs/pocs/` | Evidência temporal e aprendizado; não define estado vigente. |

User Story não é coleção própria neste baseline. A forma `Como <ator>, quero
<capacidade>, para <valor>` reside no requirement e, quando útil, no use case.

### 4.2 Contrato mínimo

Todo documento declara título/ID, natureza primária, objetivo, escopo,
não-objetivos, owner, status, data, versão, palavras-chave, arquivos relacionados,
referências ao código e afirmação principal. Campo inaplicável usa `N/A` com
justificativa; omissão silenciosa não é válida.

Cada documento tem um objetivo principal. Separe conteúdo quando owner, estado,
audiência, decisão ou ciclo de revisão puder evoluir de forma independente. Índices
resumem e apontam; não incorporam documentos catalogados.

## 5. Matriz de ativação

| Artefato | Regra |
| --- | --- |
| Adaptador global do runtime | Obrigatório para todo runtime suportado. |
| `backend/`, `frontend/`, `website/` e `infra/` com `README.md` | Scaffolds de clonagem; manter, renomear ou remover conforme a topologia real e reconciliar o manifesto. |
| Mapa, manual de IA, ADRs, arquitetura, settings, catálogo de standards e templates | Baseline obrigatório. |
| `docs/agents/AgentOrchestrator.md` | Único agente inicial obrigatório; outros papéis exigem responsabilidade, autoridade e handoff independentes. |
| Lifecycle, readiness, quality, development e security | Standards transversais ativados conforme o tipo de mudança definido no catálogo. |
| Standards de stack, interface, integração e capacidade | Permanecem disponíveis na biblioteca e são ativados somente por ADR, manifesto, contrato, escopo ou risco aplicável. |
| Skills `governanca-documental`, `implementation-readiness`, `quality-gate` | Obrigatórias em cada path nativo necessário; `.agents/skills/` é compartilhado por Codex e Google e `.claude/skills/` atende Claude Code. |
| Skill `git-delivery` | Capacidade disponível; cada projeto define sua política local de branches, integração, gates e proteção da branch principal. |
| `GEMINI.md` e `.agents/rules/documentation-governance.md` | Obrigatórios quando Gemini CLI e Antigravity forem suportados; compõem a política canônica sem copiá-la. |
| Product, requirements, use cases e contracts | Ativar quando o tipo de trabalho existir. |
| Business, analysis, reports, lessons, compliance, onboard e pocs | Ativar somente com necessidade, artefato e owner reais. |
| Adaptador ou skill local de pacote | Criar apenas quando houver especialização local. |
| `docs/scripts/` | Ativar quando o projeto mantiver código de validadores; cada script e teste deve ser adaptado à topologia local e permanecer inativo enquanto a adaptação não estiver validada. |
| Validador executável | Implementar no projeto de destino; ausência deve ser explícita e nunca simulada como `PASS`. |

Diretório vazio não demonstra conformidade. Neste pacote, as coleções opcionais
possuem apenas um contrato baseline para facilitar o clone; o primeiro artefato
real ativa seu inventário.

## 6. Bootstrap não destrutivo

1. Identifique raiz, runtime ativo, adaptadores aplicáveis e o AgentOrchestrator
   como papel inicial.
2. Leia somente os adaptadores, `docs/ai/README.md` e `docs/README.md`.
3. Inventarie diretórios, índices, manifesto e descritores de skills sem abrir toda
   a documentação.
4. Classifique cada item como `Conformant`, `Partial`, `Planned`, `Not applicable`
   ou `Needs review`.
5. Preserve artefato desconhecido até conhecer owner, natureza e destino.
6. Crie ou ajuste somente itens aditivos, reversíveis e inequívocos.
7. Atualize índices e manifesto no mesmo conjunto da mudança correspondente.
8. Selecione no catálogo o baseline e os standards condicionais realmente
   aplicáveis; registre versões, owners, paths, ferramentas e comandos locais.
9. Configure validadores e comandos a partir da stack observada; não invente
   comandos ou limiares.
10. Registre inventário, delta, verificações, pendências e owner.
11. Repita a avaliação; conformidade exige delta vazio na segunda execução.

Migração, remoção, renomeação ou sobrescrita ampla exige plano e autorização
próprios. Um bootstrap diagnóstico termina no inventário e não autoriza escrita.

## 7. Descoberta progressiva

A ordem padrão é adaptador → manual de IA → AgentOrchestrator → PRD → requirement →
índice de ADRs → ADRs selecionados → manifesto → contrato → plano → standards
ativados → artefatos executáveis. Coleções alheias entram somente por link
explícito ou lacuna comprovada.

Skills têm quatro níveis: metadados para descoberta; `SKILL.md` na ativação; fontes
canônicas selecionadas durante o procedimento; e referências/recursos somente na
condição que os exige. Skill NÃO DEVE ordenar varredura integral de `docs/`.

## 8. Lifecycle C.L.E.A.R.

| Estágio | Gate |
| --- | --- |
| Context | PRD aplicável `Validated`; requirement `Approved`; incertezas encerradas. |
| Logic & Layout | ADRs, arquitetura, contrato, use case condicional e plano atômico; IRG `READY`. |
| Execution | Escrita limitada ao task ID, versões, escopo e paths auditados. |
| Assurance | A1 Test, A2 Quality e A3 Security/Compliance independentes. |
| Release | Procedimento e autorização próprios, seguidos de verificação. |

Trabalho puramente técnico pode usar `PRD not applicable` somente com justificativa
específica e auditável. Mudança de produto não pode usar essa exceção.

## 9. Implementation Readiness Gate

Antes de todo handoff executável, a auditoria produz somente `READY` ou `BLOCKED`.
Ela verifica:

- fontes, status, versões, approvals e dependências;
- hypotheses e assumptions `Validated`/`Rejected`;
- Open Questions `Resolved`;
- `What`, `Where`, `Depends on`, `Reuses` e `Requirements`;
- Gate Audit, Acceptance Tests, Prohibited, Mandatory e DoD binária;
- um resultado observável e um handoff por unidade.

PRD aplicável não `Validated`, estado pendente, `TBD`, placeholder, conflito,
dependência ausente, autorização ausente ou DoD subjetiva produz `BLOCKED`. Não
existe `READY WITH ASSUMPTIONS`.

Falta de atomicidade não é blocker final: decomponha por resultados
independentemente aceitáveis, executáveis, reversíveis ou replanejáveis; preserve
aceite, dê IDs e DoDs próprios, atualize pai → filhos, dependências e índices e
reaudite cada unidade. Divisão apenas por arquivo, camada, linhas ou testes é
proibida. Se a decomposição revelar decisão ausente, essa causa real permanece
`BLOCKED`.

## 10. Assurance

- **A1 Test Gate:** o comportamento alterado foi exercitado por teste relevante e
  pela suíte impactada.
- **A2 Quality Gate:** cobertura, arquitetura, análise estática, tipagem, build e
  manutenção atendem aos standards aplicáveis.
- **A3 Security/Compliance Gate:** riscos de segurança, privacidade e compliance
  aplicáveis foram avaliados.

Cada subgate usa `PASS`, `FAIL` ou `BLOCKED`. Teste verde não aprova qualidade ou
segurança. Relatório histórico não é evidência atual. Mudança de software DEVE criar
ou atualizar teste relevante e executá-lo em ambiente seguro.

O Quality Gate exige o `READY` vigente para o mesmo task ID, versões, escopo e
paths. Divergência retorna ao planejamento; Assurance não decompõe retroativamente
uma implementação. `FAIL` pertencente ao escopo é corrigido e reexecutado enquanto
houver progresso. Ferramenta, configuração, autorização ou ambiente ausente é
`BLOCKED`, não aprovação implícita.

## 11. Adaptadores e skills

Adaptador global contém somente rota de leitura, topologia resumida, comandos
essenciais, guardrails e handoff. Regra de stack ou comando de pacote pertence ao
adaptador local mais próximo.

O adapter Gemini CLI importa `AGENTS.md` por `GEMINI.md`. A regra Antigravity
reside em `.agents/rules/`, importa o adapter raiz, fica abaixo de 12.000 caracteres
e deve ter sua ativação `Always On` observada no Project. Settings globais em
`~/.gemini/` não são versionados. A presença dos arquivos não prova Project,
sandbox, permissões ou ativação efetivos; essa fronteira deve constar no handoff.

Skill operacional possui diretório próprio, `SKILL.md`, `name` e `description`,
objetivo, gatilhos, não-gatilhos, procedimento, limites, entradas, saídas, evidência
e conclusão. Nome do diretório, frontmatter e catálogo devem coincidir. Skills
equivalentes em runtimes diferentes preservam o mesmo núcleo sem copiar campos
exclusivos de um runtime.

O AgentOrchestrator é uma especificação documental compartilhada, não um adapter de
runtime nem uma skill. Cada runtime inicia por esse papel e pode executar uma
capacidade especializada diretamente. Criar outro agente exige o template próprio,
entrada individual no índice e handoff que justifique sua existência.

`git-delivery` não impõe uma convenção única ao harness. Cada projeto registra sua
política local de branches, paths, gates e hooks. A política deve permitir integração
de trabalhos independentes e proteger a branch principal contra escrita direta; PR,
merge, rebase, tags, push e alterações de remote seguem os limites locais. Nenhuma
regra do harness pode bloquear novos artefatos ou mudanças válidas apenas por serem
novos. O scaffold distribuído pela skill é uma referência substituível.

## 12. Segurança e autonomia

Leitura local, diagnóstico não destrutivo, edição reversível solicitada e testes
seguros podem ser autônomos no escopo. Rede, instalação, sistema externo, exclusão
ampla e ação irreversível exigem autorização. Produção, dados reais, segredos e
credenciais são negados no baseline.

Este pacote não define uma convenção Git única. A política local do projeto PODE
autorizar branch, commit, push, PR, merge, rebase, tags e alteração de remote,
registrando os limites e gates aplicáveis. A branch principal DEVE ser protegida
contra escrita direta e force-push. Integrações devem preservar o trabalho das
branches envolvidas; conflitos devem ser resolvidos sem descartar mudanças válidas.
Leitura ou exposição de credenciais continua proibida.

## 13. Validação e baseline de conformidade

Conformidade exige:

1. índices completos e links válidos;
2. contrato mínimo e natureza primária em todo documento;
3. manifesto com todos os módulos ativos;
4. AgentOrchestrator como único agente inicial e inventário individual de todo
   papel adicional ativado;
5. catálogo completo de standards, aplicabilidade registrada e nenhuma referência
   normativa ao projeto de origem;
6. equivalência semântica entre adaptadores, imports Google e skills nos paths nativos;
7. nenhuma regra local enfraquecendo fonte superior;
8. `READY` vigente antes de implementação;
9. testes e gates proporcionais depois da implementação;
10. comandos, resultados, skips, falhas e pendências no handoff;
11. nenhuma leitura ou publicação de segredo;
12. automação declarada como configurada ou ausente, sem falso verde;
13. segunda avaliação do bootstrap com delta vazio.
14. quando `git-delivery` estiver ativa, paridade entre a skill, a política local,
    os adaptadores e o enforcement versionado, sem autorização implícita.

Regras deterministas devem migrar de prompt para validador, hook, sandbox ou CI no
projeto de destino. O contrato de automação está em `docs/automation/README.md`; se
o código do validador for versionado, seu inventário e testes ficam em `docs/scripts/`.

## 14. Controle de mudança

Mudança editorial atualiza versão e histórico local. Mudança de obrigação,
precedência, autonomia ou topologia exige revisão arquitetural e nova versão aceita
deste ADR ou ADR sucessor. Remoção ou renomeação atualiza links e índices na mesma
mudança. Reversão da governança exige ADR sucessor e preservação do histórico.

## Change log

| Versão | Data | Mudança |
| --- | --- | --- |
| 1.4 | 2026-09-13 | Mapeia `docs/scripts/` como implementação condicional de validadores, sujeita à adaptação e testes no destino. |
| 1.3 | 2026-09-13 | Disponibiliza entrega Git governada como capacidade opt-in, com enforcement local e sem ampliar o baseline de permissões. |
| 1.2 | 2026-09-11 | Define AgentOrchestrator como único agente inicial e incorpora a biblioteca canônica de standards com ativação condicional. |
| 1.1 | 2026-09-11 | Aceita Gemini CLI e Antigravity como adapters do harness, reutilizando `.agents/skills/` e separando arquivos versionados de settings efetivos do Project. |
