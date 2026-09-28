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

## Fontes canônicas e referências

Ler sempre:

- `docs/agents/standards/security-standard.md`;
- `docs/agents/standards/software-quality-standard.md`;
- `references/false-positive-controls.md` para heurísticas contra falsos positivos;
- `references/finding-evidence.md` para regras de comprovação de findings;
- `references/threat-review-model.md` para delimitação de trust boundaries.

Selecionar adicionalmente os standards especializados ativados conforme o
manifesto do projeto e `registry/standards.yaml` (ex: `application-security-standard.md`,
`api-security-standard.md`, `spring-security-standard.md`, `iac-supply-chain-standard.md`).
Não duplicar regras desses documentos dentro desta skill.

## Procedimento

1. Confirmar o `READY`, os targets e o nível `focused`, `pr` ou `release` recebido
   do `quality-gate` ou do `AgentOrchestrator`.
2. Identificar no registry e no manifesto os standards aplicáveis e registrar paths e versões.
3. Delimitar trust boundaries, entradas controláveis, identidades, recursos
   protegidos, dados sensíveis, operações privilegiadas, chamadas externas e dependências.
4. Revisar o delta aprovado, inspecionando código e configuração adjacentes para
   provar controles no caminho executado.
5. Para cada candidato a finding, traçar:
   `source controlável -> validação -> controle -> sink/ação -> impacto`.
6. Exigir comprovação quádrupla (Evidência + Reachability + Control Gap + Impacto)
   conforme `references/finding-evidence.md`. Aplicar os controles contra falsos positivos
   de `references/false-positive-controls.md` antes de reportar vulnerabilidades.
7. Executar os testes e validadores de segurança aprovados e registrados no projeto.
8. Classificar cada finding por severidade e confiança sem fabricar identificadores.
9. Aplicar a semântica do subgate A3:
   - violação confirmada sem mitigação: `FAIL`;
   - evidência, validador, autorização ou contexto obrigatório ausente: `BLOCKED`;
   - controles aprovados e sem findings confirmados: `PASS`.
10. Devolver o resultado estruturado ao `quality-gate`.

## Limites

Não alterar limiares, não fabricar evidência ou scanner, não acessar produção,
rede externa, segredos ou dados reais e não autorizar release.

## Limites de segurança

Não acesse produção, dados reais, segredos, credenciais ou rede sem autorização
específica. Não execute exploração destrutiva e use valores sintéticos nos testes.

## Saídas e evidências

A saída é o relatório técnico A3 estruturado conforme `contracts/gate-result.schema.json`,
contendo status (`PASS`, `FAIL`, `BLOCKED`), findings comprovados, comandos executados,
referências a standards ativados e handoff explícito ao `quality-gate`.

## Critério de conclusão

Concluir com a entrega da evidência A3 completa ao `quality-gate`. O `security-gate`
não decide release, não fecha A1 ou A2 e não bypassa ausência de evidência obrigatória.
