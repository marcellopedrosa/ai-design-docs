---
name: security-gate
description: Executar a verificação especializada do A3 Security/Compliance em aplicações web, APIs, autenticação, autorização, dados, Spring Security, frontend, dependências ou superfícies expostas. Retornar evidência e PASS, FAIL ou BLOCKED ao quality-gate; não agregar A1/A2 nem autorizar release.
---

# Security Gate

- Owner: Segurança e Engenharia
- Status: Active

## Objetivo

Executar a verificação técnica especializada do subgate `A3 — Security/Compliance`
e devolver seu resultado ao `quality-gate`. Apesar do nome `security-gate`, esta
skill não agrega A1/A2/A3, não constitui um Assurance Gate paralelo e não decide
release, merge ou deploy.

## Gatilhos e não-gatilhos

- Gatilhos: mudança de aplicação web, API, autenticação, autorização, dado sensível,
  Spring Security, frontend, dependência ou superfície exposta.
- Não-gatilhos: alteração exclusivamente documental sem impacto em segurança.

## Escopo e não-objetivos

- Escopo: execução especializada do A3 Security/Compliance e devolução de evidência
  ao `quality-gate`.
- Não-objetivos: agregar A1/A2, autorizar merge, release, deploy ou produção, ou
  substituir decisão de risco do owner.

## Pré-condições

Exigir plano vigente, escopo e paths explícitos e evidência `implementation-readiness`
`READY` para a mesma unidade executável. Divergência de task ID, versão, escopo ou
paths é `BLOCKED` processual.

## Entradas

Plano vigente, resultado `READY`, task ID, nível de execução, paths, critérios de
aceite, ambiente e comandos de validação registrados pelo projeto.

## Fontes canônicas

Ler sempre:

- `docs/agents/standards/security-standard.md`;
- `docs/agents/standards/software-quality-standard.md`;
- `docs/agents/standards/application-security-standard.md` quando houver aplicação
  web, backend web ou superfície exposta a entrada não confiável.

Selecionar adicionalmente apenas quando ativados pelo manifesto, ADR, contrato,
escopo ou risco:

- `docs/agents/standards/api-security-standard.md` para APIs;
- `docs/agents/standards/spring-security-standard.md` para Spring Boot/Spring Security;
- `docs/agents/standards/java-standard.md` para Java;
- `docs/agents/standards/frontend-standard.md` para frontend;
- `docs/agents/standards/nextjs-standard.md` para Next.js/React correspondente;
- `docs/agents/standards/keycloak-frontend-standard.md` para Keycloak no frontend;
- `docs/agents/standards/rbac-frontend-standard.md` para UI com acesso diferenciado;
- `docs/agents/standards/iac-supply-chain-standard.md` para dependências, containers,
  IaC ou supply chain;
- demais standards catalogados que o escopo realmente ativar.

Não duplicar regras desses documentos dentro desta skill. Se um standard requerido
não existir ou estiver materialmente inconsistente, retornar `BLOCKED` e apontar o
path ausente ou conflitante.

## Procedimento

1. Confirmar o `READY`, os targets e o nível `focused`, `pr` ou `release` recebido
   do `quality-gate` ou do `AgentOrchestrator`.
2. Selecionar somente os standards aplicáveis e registrar seus paths e versões.
3. Delimitar trust boundaries, entradas controláveis, identidades, recursos
   protegidos, dados sensíveis, operações privilegiadas, chamadas externas,
   uploads, persistência e dependências afetadas.
4. Revisar primeiro o delta aprovado. Seguir código ou configuração adjacente apenas
   quando necessário para provar autenticação, autorização, validação ou outro
   controle no caminho executado.
5. Para cada candidato a finding, traçar:
   `source controlável -> transformação/validação -> controle -> sink/ação -> impacto`.
6. Antes de confirmar um finding, demonstrar evidência, reachability, ausência ou
   falha do controle e impacto plausível. Padrão suspeito sem prova suficiente deve
   virar pendência de validação, nunca vulnerabilidade inventada.
7. Executar ou solicitar os testes e validadores já registrados pelo projeto.
   Não inventar scanner, comando, credencial, endpoint, ambiente ou acesso de rede.
8. Classificar cada finding por severidade e confiança sem derivar severidade apenas
   da categoria OWASP. Usar CWE/ASVS somente quando o identificador estiver
   verificado; não fabricar IDs.
9. Aplicar o contrato do A3:
   - violação confirmada de requisito aplicável: `FAIL`;
   - evidência, ferramenta, ambiente, autorização ou contexto obrigatório ausente:
     `BLOCKED`;
   - nenhum finding confirmado e toda evidência obrigatória disponível: `PASS`.
10. Devolver o resultado ao `quality-gate`. Não agregar A1/A2, não transformar
    waiver em `PASS` e não autorizar release.

## Controles contra falso positivo

- React escapa interpolação textual por padrão; não reportar XSS sem bypass ou sink
  inseguro demonstrado.
- CORS é política de compartilhamento do browser, não autorização.
- UI, route guard, botão oculto e claim decodificada não substituem autorização no
  backend.
- Uso de JPA/Spring Data não prova SQL injection; demonstrar construção dinâmica
  insegura e influência da entrada.
- CSRF desabilitado não é finding isolado em API comprovadamente stateless com
  bearer token e sem credencial ambiente do browser.
- Dependência antiga não é vulnerabilidade confirmada sem política violada ou
  vulnerabilidade aplicável verificada.
- Endpoint autenticado pode continuar vulnerável a autorização; verificar recurso,
  função, tenant e propriedade separadamente.

## Evidência mínima do A3

Registrar:

- task ID, nível, paths e referência ao `READY`;
- standards ativados com path e versão;
- superfícies e trust boundaries revisadas;
- comandos/validadores executados, diretório, exit code e limitações;
- findings confirmados com evidência mínima necessária;
- testes positivos e negativos relevantes;
- skips, N/A, waivers e risco residual;
- status final `PASS`, `FAIL` ou `BLOCKED` e sua causa.

## Formato de saída

Usar esta estrutura:

```text
A3 — Security/Compliance
Executor: security-gate
Status: PASS | FAIL | BLOCKED
Task: <id>
Level: focused | pr | release
Scope: <paths/targets>

Standards aplicados:
- <path> @ <version>

Findings:
- <id> | <severity> | <confidence> | <title>
  Evidence: <arquivo/linha/configuração>
  Control gap: <controle ausente ou falho>
  Impact: <impacto plausível>
  Reference: <CWE/ASVS/OWASP verificado ou "não verificado">
  Remediation: <correção da causa raiz>
  Validation: <teste que demonstra fechamento>

Evidence:
- <comando/resultado/artefato>

Residual risk / waivers:
- <item ou none>

Handoff:
- quality-gate
```

Quando `BLOCKED`, incluir owner da pendência e condição objetiva de retomada.

## Saídas e critério de conclusão

A saída é o relatório A3 no formato acima, com status `PASS`, `FAIL` ou `BLOCKED`,
findings, evidências e handoff ao `quality-gate`. Concluir somente quando todos os
controles A3 aplicáveis tiverem evidência atual; ausência de evidência obrigatória
permanece `BLOCKED`.

## Limites de segurança

Não acessar produção, dados reais, segredos, credenciais ou rede sem autorização
específica. Não ampliar o escopo, desabilitar controle, reduzir limiar, fabricar
evidência, executar exploração destrutiva ou manter dado sensível no relatório.
Usar valores sintéticos nos testes sempre que possível.
