---
document_id: ADR-0000
primary_nature: Decisao
objective: Definir a referencia normativa para inicializar e manter o harness documental e as instrucoes de agentes.
scope: Topologia documental, precedencia, bootstrap, descoberta progressiva, lifecycle, readiness, assurance, skills e adaptadores.
non_objectives: Nao definir dominio, stack, comandos, limiares de cobertura, release, segredos ou configuracoes pessoais.
owner: Arquitetura e mantenedores do harness
status: Accepted
version: 1.0
date: 2026-09-10
last_reviewed: 2026-09-10
keywords: governanca, bootstrap, agentes, clear, readiness, assurance, portabilidade
related_files: ../README.md, ../ai/README.md, ../agents/standards/software-engineering-lifecycle.md, ../agents/standards/implementation-readiness-standard.md, ../agents/standards/software-quality-standard.md
code_references: ../../AGENTS.md, ../../CLAUDE.md, ../../.agents/skills/, ../../.claude/skills/
principal_statement: Todo projeto adotante converge de forma nao destrutiva para fontes tipadas, indexadas, rastreaveis e carregadas progressivamente, com readiness antes e assurance depois da implementacao.
---

# ADR-0000 — Governança do harness documental e de agentes

## 1. Contexto

Projetos operados por pessoas e agentes precisam distinguir intenção de produto,
comportamento, decisão, estado arquitetural, plano, execução e evidência. Quando
essas naturezas são misturadas, o agente carrega contexto excessivo, infere decisões
ausentes e produz handoffs não verificáveis.

O harness deve ser independente de domínio, stack e fornecedor de IA. Nomes como
`AGENTS.md`, `CLAUDE.md` e `SKILL.md` são adaptadores; os invariantes comuns
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
- `docs/agents/standards/` para regras reutilizáveis;
- `docs/agents/skills/README.md` para catalogar skills operacionais;
- `docs/templates/` para todo tipo recorrente;
- um `README.md` em cada coleção ativa, com inventário completo;
- adaptadores globais enxutos para cada runtime suportado;
- skills pareadas de governança, readiness e quality gate quando Codex e Claude
  Code forem ambos suportados.

A convergência é idempotente e não destrutiva: inventaria primeiro, preserva o
desconhecido, cria somente o delta inequívoco e produz zero alteração quando
repetida sobre o mesmo estado conforme.

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
| Mapa, manual de IA, ADRs, arquitetura, settings, standards e templates | Baseline obrigatório. |
| Skills `governanca-documental`, `implementation-readiness`, `quality-gate` | Obrigatórias em cada runtime com suporte a skills. |
| Product, requirements, use cases e contracts | Ativar quando o tipo de trabalho existir. |
| Business, analysis, reports, lessons, compliance, onboard e pocs | Ativar somente com necessidade, artefato e owner reais. |
| Adaptador ou skill local de pacote | Criar apenas quando houver especialização local. |
| Validador executável | Implementar no projeto de destino; ausência deve ser explícita e nunca simulada como `PASS`. |

Diretório vazio não demonstra conformidade. Neste pacote, as coleções opcionais
possuem apenas um contrato baseline para facilitar o clone; o primeiro artefato
real ativa seu inventário.

## 6. Bootstrap não destrutivo

1. Identifique raiz, runtime ativo e adaptadores aplicáveis.
2. Leia somente os adaptadores, `docs/ai/README.md` e `docs/README.md`.
3. Inventarie diretórios, índices, manifesto e descritores de skills sem abrir toda
   a documentação.
4. Classifique cada item como `Conformant`, `Partial`, `Planned`, `Not applicable`
   ou `Needs review`.
5. Preserve artefato desconhecido até conhecer owner, natureza e destino.
6. Crie ou ajuste somente itens aditivos, reversíveis e inequívocos.
7. Atualize índices e manifesto no mesmo conjunto da mudança correspondente.
8. Configure validadores e comandos a partir da stack observada; não invente
   comandos ou limiares.
9. Registre inventário, delta, verificações, pendências e owner.
10. Repita a avaliação; conformidade exige delta vazio na segunda execução.

Migração, remoção, renomeação ou sobrescrita ampla exige plano e autorização
próprios. Um bootstrap diagnóstico termina no inventário e não autoriza escrita.

## 7. Descoberta progressiva

A ordem padrão é adaptador → manual de IA → PRD → requirement → índice de ADRs →
ADRs selecionados → manifesto → contrato → plano → standards referenciados →
artefatos executáveis. Coleções alheias entram somente por link explícito ou lacuna
comprovada.

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

Skill operacional possui diretório próprio, `SKILL.md`, `name` e `description`,
objetivo, gatilhos, não-gatilhos, procedimento, limites, entradas, saídas, evidência
e conclusão. Nome do diretório, frontmatter e catálogo devem coincidir. Skills
equivalentes em runtimes diferentes preservam o mesmo núcleo sem copiar campos
exclusivos de um runtime.

## 12. Segurança e autonomia

Leitura local, diagnóstico não destrutivo, edição reversível solicitada e testes
seguros podem ser autônomos no escopo. Rede, instalação, sistema externo, exclusão
ampla e ação irreversível exigem autorização. Produção, dados reais, segredos e
credenciais são negados no baseline.

Este pacote não autoriza Git de escrita ou entrega. O projeto de destino pode adotar
política mais permissiva somente por decisão explícita que defina branch, paths,
gates, comandos permitidos e operações proibidas.

## 13. Validação e baseline de conformidade

Conformidade exige:

1. índices completos e links válidos;
2. contrato mínimo e natureza primária em todo documento;
3. manifesto com todos os módulos ativos;
4. equivalência semântica entre adaptadores e skills pareadas;
5. nenhuma regra local enfraquecendo fonte superior;
6. `READY` vigente antes de implementação;
7. testes e gates proporcionais depois da implementação;
8. comandos, resultados, skips, falhas e pendências no handoff;
9. nenhuma leitura ou publicação de segredo;
10. automação declarada como configurada ou ausente, sem falso verde;
11. segunda avaliação do bootstrap com delta vazio.

Regras deterministas devem migrar de prompt para validador, hook, sandbox ou CI no
projeto de destino. O contrato de automação está em `docs/automation/README.md`.

## 14. Controle de mudança

Mudança editorial atualiza versão e histórico local. Mudança de obrigação,
precedência, autonomia ou topologia exige revisão arquitetural e nova versão aceita
deste ADR ou ADR sucessor. Remoção ou renomeação atualiza links e índices na mesma
mudança. Reversão da governança exige ADR sucessor e preservação do histórico.
