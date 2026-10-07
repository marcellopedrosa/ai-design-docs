---
document_id: ADR-0054
primary_nature: Decisao
objective: Decidir onde e como manter a custódia durável dos eventos conversacionais antes do ACK em uma arquitetura database-per-tenant.
scope: Telegram e WhatsApp inbound, ownership da inbox, roteamento, deduplicação, FIFO, claim, lease, fencing, retry seguro, worker e observabilidade.
non_objectives: Escolher broker externo; persistir payload bruto ou segredos; repetir mutações fiscais incertas; definir sizing produtivo; governar receipts WhatsApp neste primeiro slice.
owner: Arquitetura e Backend Omnichannel
status: Accepted
version: 1.5
date: 2026-08-29
last_reviewed: 2026-09-03
keywords: adr, omnichannel, inbox, database-per-tenant, ack, fifo, lease, fencing, retry
related_files: "README.md"
code_references: app/src/main/java/br/com/duoset/saas_service/contexts/omnichannel/, app/src/main/resources/db/migration/omnichannel/V45__create_inbound_event_inbox.sql
principal_statement: O envelope inbound normalizado será commitado na inbox do banco dedicado do tenant antes do ACK; o control plane manterá apenas a rota WhatsApp, e workers usarão FIFO por conversa, claim não bloqueante, lease/fencing e retry somente antes de efeito potencialmente incerto.
---

# ADR-0054 - Inbox durável omnichannel no banco do tenant

- Document ID: `ADR-0054`
- Primary Nature: `Decisao`
- Objective: eliminar perda pós-ACK sem romper isolamento database-per-tenant.
- Scope: custódia, roteamento, concorrência, recuperação e telemetria inbound.
- Non-objectives: broker externo, payload bruto, replay fiscal incerto, sizing de produção e receipts WhatsApp.
- Keywords: omnichannel, inbox, tenant, ACK, claim, lease, fencing, FIFO.
- Related Files: [REQ-00050](../product/requirements/REQ-00050-omnichannel-durable-inbound-processing.md), [ADR-0011](ADR-0011-resilience-retry-circuit-breaker.md), [ADR-0015](ADR-0015-telegram-integration.md), [ADR-0019](ADR-0019-database-per-tenant.md), [IP-BE-3.2.12-omnichannel-durable-inbound-processing](../specs/IP-BE-3.2.12-omnichannel-durable-inbound-processing.md) e [LL-BE-00093](../lessons-learned/LL-BE-00093-webhook-ack-is-not-worker-completion.md).
- Code References: módulo Omnichannel e migration tenant `V45`.
- Principal Decision: conteúdo inbound pertence ao banco dedicado do tenant e deve estar commitado antes do ACK.
- Date: 2026-08-29
- Status: Accepted sob solicitação humana explícita para implementação local
- Version: 1.5
- Owner: Arquitetura e Backend Omnichannel
- Authors / Owners: Codex, sob solicitação humana explícita
- Reviewers: Arquitetura, Backend, Segurança, QA e SRE
- Stakeholders: clientes dos canais, escritórios, suporte e operação
- Supersedes: N/A
- Superseded by: N/A

# 1. Context

Os webhooks submetiam o processamento a executores in-memory e retornavam sucesso
quando a task era aceita. Se o processo reiniciasse, a fila rejeitasse trabalho ou
uma exceção acontecesse depois do ACK, o provider não possuía motivo para repetir e
o sistema não possuía inbox para recuperar a mensagem.

Serializar a mesma conversa dentro de uma thread também não resolve o problema:
waiters consomem executor/pool, a fila não sobrevive a restart e uma chamada longa
ao provider pode multiplicar o congestionamento. O ADR-0019 exige que conteúdo e
identidades conversacionais permaneçam isolados por tenant. Antes do `TenantContext`,
porém, o WhatsApp só fornece a identidade WABA/phone usada para localizar esse tenant.

O desenho precisa simultaneamente preservar custódia antes do ACK, ordem por
conversa, paralelismo entre conversas, deduplicação entre réplicas e segurança
contra repetir efeitos externos cujo resultado seja desconhecido.

# 2. Decision Statement

Adotar uma inbox relacional no banco dedicado de cada tenant. O endpoint executa
autenticação, resolução de rota e uma transação curta de aceite; somente commit ou
duplicata já durável permitem ACK. Um dispatcher best-effort reduz latência, e um
scheduler tenant-scoped recupera o backlog como fonte autoritativa.

O control plane guarda exclusivamente a rota ativa `(wabaId, phoneNumberId) ->
tenantId`. Não recebe conteúdo, remote ID, callback ou payload bruto. Telegram usa
o tenant autenticado pelo endpoint. Depois da resolução, toda leitura/escrita da
inbox ocorre sob o `TenantContext` correto.

Cada conversa possui ordem persistida. Claims selecionam somente a cabeça elegível,
usam `FOR UPDATE SKIP LOCKED`, owner, lease e fencing token. Completion e qualquer
mudança de estado fazem compare-and-set. Um checkpoint separa trabalho ainda não
iniciado, que pode ser reprocessado, de resultado potencialmente incerto, que vai
para revisão sem replay automático.

Durante trabalho ativo, o worker renova o lease com o mesmo owner e fence. Revisão
manual é terminal para a ordenação: preserva o evento incerto e impede seu replay,
mas libera a sucessora para que uma poison message não paralise a conversa inteira.

O ledger outbound usa transações curtas `REQUIRES_NEW`, mas essa independência não
autoriza inversão pai/filho. A transação conversacional externa não pode atualizar
e fazer flush da linha `conversations` antes de a transação interna inserir uma
tentativa outbound que a referencia por foreign key. Em um turno com múltiplas
saídas, os claims acontecem antes de um único flush final do aggregate, ou uma
fronteira explícita de commit deve separar as unidades de trabalho.

Heartbeat de lease comprova somente ownership. Duração de estágio e espera de banco
continuam necessárias para distinguir trabalho com progresso de execução viva,
porém bloqueada; lease renovado isoladamente não constitui sinal de saúde.

Saída operacional `PROGRESS` que não influencia estado nem contexto futuro usa a
mesma deduplicação/evidência do ledger outbound, porém não é anexada a
`Conversation.messages` e não causa save do aggregate em listener assíncrono. Se
uma notificação passar a ter valor semântico, ela deve voltar ao escritor serial da
conversa ou a uma estrutura append-only com ordem de lock explícita; writers
concorrentes do aggregate não são permitidos.

# 3. Decision Drivers

- compromisso de ACK verificável e recuperável;
- isolamento de conteúdo e LGPD por tenant;
- ordem por conversa sem serializar todo o tenant;
- nenhum waiter bloqueante no executor;
- idempotência entre réplicas e replays do provider;
- prevenção de emissão fiscal duplicada;
- operação possível com PostgreSQL já adotado, sem nova infraestrutura obrigatória;
- métricas de conclusão e backlog com cardinalidade finita.

# 4. Considered Options

## 4.1 Executor em memória com keyed lock

**Pros:** alteração pequena e baixa latência.  
**Cons:** ACK continua sem custódia, restart perde fila e waiters ocupam threads.

## 4.2 Inbox central no banco da plataforma

**Pros:** polling global simples e tenant conhecido em uma tabela.  
**Cons:** concentra conteúdo/PII de todos os escritórios, amplia blast radius e
contraria o ownership database-per-tenant.

## 4.3 Broker externo com consumer groups

**Pros:** mecanismos maduros de fila e escala horizontal.  
**Cons:** nova dependência operacional e ainda exige outbox/inbox para atomicidade,
dedupe e efeito incerto. Pode ser evolução futura, não pré-requisito.

## 4.4 Inbox no banco dedicado do tenant — escolhida

**Pros:** ACK-after-commit, isolamento, transações locais e reutilização do padrão
PostgreSQL de claim/lease já conhecido.  
**Cons:** scheduler precisa descobrir tenants, instalar contexto e aplicar fairness;
WhatsApp exige uma resolução curta no control plane antes do insert.

# 5. Decision Outcome

A opção tenant-local atende simultaneamente custódia e isolamento com a menor nova
superfície operacional. O custo aceito é um dispatcher consciente de tenant e uma
rota prévia do WhatsApp. O ACK não depende do dispatcher: sinal perdido ou executor
cheio apenas aumenta a latência até o próximo polling.

A identidade idempotente será representada por token HMAC com separação de domínio.
Payload normalizado sensível será cifrado com proteção autenticada e keyring vigente.
Bot token, webhook secret e corpo HTTP original nunca entram na tabela.

# 6. Consequences

**Positive Consequences:** mensagens aceitas sobrevivem a restart; contenção volta
ao backlog sem bloquear threads; canais compartilham a mesma semântica; métricas
distinguem custódia de conclusão.

**Negative Consequences:** existe estado operacional adicional, migration por
tenant, necessidade de lease/fencing e fila manual para outcomes incertos.

**Neutral Consequences:** receipts WhatsApp permanecem explicitamente com a
semântica anterior até requisito próprio; isso não deve ser confundido com paridade
durável de mensagens conversacionais.

# 7. Impact

- **Architecture:** controllers deixam de chamar o fluxo conversacional diretamente.
- **Data:** nova tabela tenant-local, aditiva e forward-only.
- **Security:** conteúdo cifrado, índices HMAC e roteamento fail-closed.
- **Runtime:** worker bounded, scheduler round-robin e coordenação fail-fast tipada.
- **Observability:** counters/timers do worker e backlog, sem IDs como tags.
- **Integrations:** SERPRO auth ganha read timeout; a cascata LLM recebe budget
  agregado para limitar retenção de worker.

# 8. AI Agent Considerations

Agentes podem implementar e validar somente em ambiente local sintético. Não podem
reenviar manualmente uma linha em revisão, inferir que timeout fiscal não produziu
efeito, acessar segredo, alterar registro de webhook real ou executar deploy. Uma
decisão de replay de outcome incerto exige reconciliação e autoridade humana.

# 9. Implementation Plan

1. firmar REQ-00050 e migration aditiva;
2. implementar ports/adapters tenant-local e testes PostgreSQL;
3. integrar aceite síncrono e resolução WhatsApp;
4. criar worker, dispatcher, scheduler, lease/fencing e métricas;
5. tornar coordenação fail-fast tipada e fechar limites SERPRO/LLM;
6. executar testes focalizados, impactados, arquitetura e docs;
7. calibrar e autorizar rollout em trabalho posterior.

Rollback de código não remove a tabela nem seus eventos. Se houver backlog, uma
versão anterior não deve ser promovida sem plano explícito de drain/preservação.

# 10. Validation

Sucesso exige provas concorrentes em PostgreSQL real: dedupe, FIFO, paralelismo
entre conversas, `SKIP LOCKED`, lease/checkpoint, fence obsoleto e isolamento. Os
controller tests comprovam que o ACK ocorre depois do commit e que falha de wake-up
não perde a linha. Worker tests comprovam conclusão, backoff e revisão segura.

# 11. Risks and Mitigations

| Risk | Mitigation |
| --- | --- |
| Worker executa efeito e cai antes de completar | Checkpoint, fence e revisão; nunca replay cego. |
| Lease expira em chamada longa | Limites externos bounded e heartbeat fenced mantêm trabalho ativo; `WORKING` realmente expirado vai para revisão, sem replay cego. |
| Worker renova lease sem avançar | Proibir flush do pai antes do claim filho `REQUIRES_NEW` e observar duração/wait do estágio; heartbeat isolado não comprova progresso. |
| Listener de progresso disputa o aggregate | Registrar tentativa/aceitação no ledger sem adicionar mensagem nem salvar a conversa; saída semântica permanece no escritor serial. |
| Revisão vira poison head-of-line | `MANUAL_REVIEW` é terminal para o FIFO, permanece preservado e nunca é reclamado automaticamente. |
| Uma conversa bloqueia todas | FIFO é somente por conversa; fairness por tenant. |
| Plataforma centraliza PII | Control plane guarda apenas rota; conteúdo é tenant-local. |
| Scheduler causa scan sem limite | Paginação/fatias bounded e concorrência configurável. |

# 12. Related ADRs

- ADR-0011 — retry e resultado desconhecido;
- ADR-0012 — taxonomia e observabilidade;
- ADR-0015 — integração Telegram;
- ADR-0019 — database-per-tenant;
- ADR-0021 — fallback LLM;
- ADR-0052 — capacidade e admission control tenant.

# 13. References

- [REQ-00050](../product/requirements/REQ-00050-omnichannel-durable-inbound-processing.md)
- [IP-BE-3.2.12-omnichannel-durable-inbound-processing](../specs/IP-BE-3.2.12-omnichannel-durable-inbound-processing.md)
- [LL-BE-00093](../lessons-learned/LL-BE-00093-webhook-ack-is-not-worker-completion.md)
- [LL-BE-00091](../lessons-learned/LL-BE-00091-long-lived-chatbot-transaction-exhausts-tenant-pool.md)
- [IP-BE-3.2.15-omnichannel-outbound-parent-lock-inversion](../specs/IP-BE-3.2.15-omnichannel-outbound-parent-lock-inversion.md)

# 14. Decision Lifecycle

`Accepted` em 2026-08-29 por solicitação humana explícita para implementação local.
Não representa aprovação de rollout, produção, sizing, acesso a provider ou replay
de dados existentes.

# 15. Change Log

| Version | Date | Author | Changes |
| --- | --- | --- | --- |
| 1.5 | 2026-09-03 | Codex | Separa progresso transitório do histórico semântico e proíbe writers assíncronos concorrentes do aggregate. |
| 1.4 | 2026-09-03 | Codex | Proíbe inversão de lock entre conversa pai e tentativa outbound filha e explicita que heartbeat não mede progresso. |
| 1.3 | 2026-09-02 | Codex | Registra comprovação local do heartbeat e da quarentena terminal em testes PostgreSQL para ambos os canais. |
| 1.2 | 2026-09-02 | Codex | Torna explícitos heartbeat fenced e quarentena terminal para FIFO após incidente omnichannel de `LEASE_EXPIRED`. |
| 1.1 | 2026-08-29 | Codex | Alinha a mitigação de lease ao comportamento implementado: expiração pós-checkpoint é revisão conservadora; heartbeat não é declarado como ativo. |
| 1.0 | 2026-08-29 | Codex / solicitação humana explícita | Decide inbox tenant-local, ACK-after-commit e retry por checkpoint. |

# 16. Repository Structure

O ADR permanece em `docs/adrs/`; requisito, plano e lição vivem nas coleções
governadas correspondentes.

# 17. Review Process

Mudanças futuras em ownership, semântica de replay ou fonte de verdade exigem ADR
sucessor. Calibração numérica pode evoluir sob requisito/plano sem alterar esta
decisão, desde que preserve limites finitos e invariantes.

# 18. Notes

Durabilidade não equivale a entrega exatamente uma vez. O sistema implementa
custódia, deduplicação e efeitos fenced; integrações sem idempotency key continuam
exigindo tratamento conservador do resultado desconhecido.
