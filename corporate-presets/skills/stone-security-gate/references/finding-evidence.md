# Modelo de Evidência de Findings de Segurança (A3)

Este documento define os critérios de comprovação para que um finding de segurança seja registrado e classificado de forma reproduzível.

## 1. Princípio da Comprovação Quádrupla

Um finding somente é considerado **CONFIRMED** quando apresentar evidência simultânea dos quatro elementos:

```text
Evidence (presença de código/configuração)
  AND
Reachability (origem controlável atinge o sink)
  AND
Control Gap (falha ou ausência do controle de mitigação)
  AND
Plausible Impact (consequência mensurável no sistema/negócio)
```

Se qualquer um desses elementos não puder ser comprovado:
- Não confirme como vulnerabilidade explorável;
- Registre como pendência de investigação ou observação informativa se os fatos forem verídicos, ou descarte como falso positivo se houver controle compensatório comprovado.

## 2. Severidade e Confiança

- **Severidade**:
  - `CRITICAL`: Execução remota de código sem autenticação, bypass completo de autenticação, vazamento irrestrito de banco de dados.
  - `HIGH`: BOLA/IDOR com acesso a dados de outros tenants, SQL injection autenticado, escalação de privilégio horizontal/vertical.
  - `MEDIUM`: XSS armazenado com impacto em usuário autenticado, CSRF com impacto em transação financeira, cabeçalhos de segurança ausentes com risco de clickjacking.
  - `LOW`: Divulgação de informações técnicas (stack trace), banners de versão expostos.
  - `INFO`: Sugestão de endurecimento (hardening) preventivo.

- **Confiança**:
  - `CONFIRMED`: Evidência reproduzida por teste unitário/integrado ou análise de fluxo estático inequívoca.
  - `HIGH`: Padrão vulnerável evidente no código e ausência explícita de controles.
  - `MEDIUM`: Controle ausente na camada revisada, mas possível mitigação em gateway/proxy ou camada externa.
  - `LOW`: Indício estatístico sem análise contextual de reachability.
  - `TENTATIVE`: Hipótese pendente de validação dinâmica ou teste.

## 3. Identificadores Canônicos

- Não fabrique números de CVE ou CWE.
- Utilize classificações formais reconhecidas (ex: `CWE-89: SQL Injection`, `CWE-79: Cross-Site Scripting`, `CWE-639: Authorization Bypass Through User-Controlled Key`).
- Quando não for possível determinar com exatidão o CWE específico, registre `"não verificado"` ou a categoria genérica OWASP Top 10 com justificativa.
