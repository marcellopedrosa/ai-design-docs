---
document_id: STATE-MANAGEMENT-STANDARD
primary_nature: Regra
objective: Definir ownership, sincronização e ciclo de vida de estado em aplicações cliente.
scope: Estado local, compartilhado, remoto, URL, cache, persistência, mutações e concorrência.
non_objectives: Não escolher biblioteca, framework, storage ou política de cache específica.
owner: Engenharia de Frontend e Arquitetura
status: Active
version: 1.0
date: 2026-09-11
last_reviewed: 2026-09-11
keywords: estado, cache, server-state, client-state, concorrencia
related_files: README.md, frontend-standard.md, api-client-standard.md, security-standard.md
code_references: N/A - stores e ferramentas pertencem ao projeto adotante.
principal_statement: Cada estado possui uma única autoridade, ciclo de vida e política de sincronização explícitos.
---

# State Management Standard

## Regras

- Manter estado no menor escopo que o consome: componente, feature, URL, servidor
  ou store compartilhado.
- Tratar dados remotos como server state com freshness, cache, erro e invalidação;
  não duplicá-los em store global sem necessidade comprovada.
- Tornar URL canônica para estado navegável e compartilhável quando a experiência
  exigir back, refresh ou deep link previsíveis.
- Derivar valores em vez de armazenar cópias sincronizadas manualmente.
- Chaves de cache incluem todo parâmetro que altera o resultado e nenhum dado
  sensível desnecessário.
- Mutações definem concorrência, atualização otimista, rollback, invalidação e
  reconciliação com a resposta canônica.
- Persistência cliente é explícita, versionada, migrável e proibida para segredos;
  logout ou mudança de identidade limpa estado escopado ao usuário.
- Subscriptions e efeitos possuem cleanup e não criam loops ou atualizações após
  descarte.

## Evidência

Registrar owner de cada estado compartilhado e testar refresh, navegação,
invalidação, concorrência, erro, troca de identidade e recuperação de persistência.

## Change log

| Versão | Data | Mudança |
| --- | --- | --- |
| 1.0 | 2026-09-11 | Cria standard portátil de state management. |
