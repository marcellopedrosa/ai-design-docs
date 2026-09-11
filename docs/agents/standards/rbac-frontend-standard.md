---
document_id: RBAC-FRONTEND-STANDARD
primary_nature: Regra
objective: Definir consumo seguro e coerente de autorização baseada em roles ou capacidades no frontend.
scope: Sessão, capabilities, rotas, componentes, estados 401/403, cache, impersonação e testes.
non_objectives: Não tornar o frontend autoridade de acesso, definir roles do domínio ou escolher provedor de identidade.
owner: Segurança, Produto e Engenharia de Frontend
status: Active
version: 1.0
date: 2026-09-11
last_reviewed: 2026-09-11
keywords: rbac, frontend, autorizacao, roles, capabilities, deny-by-default
related_files: README.md, frontend-standard.md, security-standard.md, keycloak-frontend-standard.md, frontend-testing-standard.md
code_references: N/A - modelo de autorização pertence ao contrato do projeto adotante.
principal_statement: O backend é a autoridade de autorização; o frontend representa capabilities canônicas como defesa em profundidade e nega por padrão.
---

# RBAC Frontend Standard

## Ativação

Condicional a UI com acesso diferenciado por identidade, role, escopo ou atributo.

## Regras

- Consumir roles, permissions ou capabilities de fonte autenticada e documentada;
  não inferir autorização por nome, rota, conteúdo do cliente ou condição visual.
- Preferir capabilities orientadas a ação quando o modelo de produto exceder roles
  simples. Mapeamentos ficam centralizados e testáveis.
- Ocultar ou desabilitar controle melhora experiência, mas toda operação continua
  protegida no servidor.
- Aplicar deny-by-default durante loading, sessão inválida, claims desconhecidas ou
  falha na obtenção de permissões.
- Diferenciar não autenticado, não autorizado e recurso inexistente conforme o
  contrato, sem revelar existência sensível.
- Mudança de sessão, tenant, escopo ou impersonação invalida caches e estado
  derivados; o contexto ativo permanece visível e auditável.
- Não persistir token ou claim sensível sem decisão de segurança explícita.

## Evidência

Manter matriz capability → superfície → operação e testar permitido, negado,
sessão expirada, claim ausente, troca de escopo e resposta 401/403. Teste de UI não
substitui teste server-side.

## Change log

| Versão | Data | Mudança |
| --- | --- | --- |
| 1.0 | 2026-09-11 | Extrai regras RBAC sem roles ou domínio específicos. |
