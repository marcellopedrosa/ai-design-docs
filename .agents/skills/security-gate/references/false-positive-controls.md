# Controles contra Falso Positivo em Verificação de Segurança (A3)

Este documento reúne heurísticas e invariantes para prevenir que agentes reportem vulnerabilidades sem evidência de explorabilidade real ou sem compreender controles embutidos na stack.

## 1. Interpolação Textual em Frontend (XSS)

- **Heurística**: Frameworks modernos (React, Vue, Angular) aplicam escaping automático em interpolações textuais de tags JSX/templates (ex: `{userName}`).
- **Regra**: Nunca confirme XSS refletido ou armazenado em JSX/template sem demonstrar uso deliberado de sink inseguro (como `dangerouslySetInnerHTML`, `v-html`, manipulação direta de `innerHTML`, `document.write` ou URLs controladas pelo usuário em `href="javascript:..."`).

## 2. CORS vs Autorização

- **Heurística**: CORS (Cross-Origin Resource Sharing) é uma política do navegador para restringir requisições cross-origin com credenciais de sessão do usuário. Não é um mecanismo de autenticação ou autorização no servidor.
- **Regra**: Um cabeçalho CORS permissivo (`*`) em endpoints de leitura pública não constitui vulnerabilidade de bypass de autorização. Não confunda ausência de CORS com proteção de backend.

## 3. UI Guards e Ocultação de Botões

- **Heurística**: Condições de renderização de interface (ex: `if (user.isAdmin) { showButton(); }`) são puramente para experiência do usuário.
- **Regra**: A presença de um guard na interface não valida a segurança se o endpoint backend não validar a autorização por papel ou permissão no recebimento do payload.

## 4. ORMs e Frameworks de Persistência (SQL Injection)

- **Heurística**: O uso de JPA, Spring Data, Hibernate, Prisma ou queries parametrizadas (`PreparedStatement`) protege nativamente contra SQL Injection.
- **Regra**: A presença de uma chamada de repositório (ex: `findByEmail(email)`) não é vulnerabilidade de SQLi. Para confirmar SQLi, é obrigatório demonstrar concatenação dinâmica insegura de strings diretamente em SQL/JPQL/HQL sem parametrização.

## 5. CSRF em APIs Stateless

- **Heurística**: CSRF depende do envio automático de credenciais de ambiente pelo navegador (como cookies de sessão `Cookie: JSESSIONID`).
- **Regra**: APIs puramente stateless que utilizam autenticação baseada em token Bearer (`Authorization: Bearer <JWT>`) armazenado na memória da aplicação e que não utilizam cookies de sessão para autenticação de estado não são vulneráveis a CSRF tradicional. Não confirme vulnerabilidade CSRF isolada nesse cenário.

## 6. Dependências Antigas vs Vulnerabilidades Confirmadas

- **Heurística**: Versão desatualizada de dependência é um indicador de higiene de supply chain, mas nem toda CVE é explorável no contexto do projeto.
- **Regra**: Antes de confirmar severidade CRITICAL/HIGH para CVE de dependência, demonstre reachability: o código do projeto realmente invoca a classe/método vulnerável? Se não invocar, registre como observação de manutenção/risco residual, não como vulnerabilidade de execução imediata.

## 7. Autenticação vs Autorização (BOLA / IDOR)

- **Heurística**: O fato de um endpoint exigir token JWT válido comprova quem o usuário é (autenticação), mas não se ele tem direito de acessar o recurso específico (autorização de objeto / IDOR / BOLA).
- **Regra**: Verifique se o backend valida que o ID do recurso solicitado pertence ao tenant/usuário do token antes de retornar dados ou persistir modificações.
