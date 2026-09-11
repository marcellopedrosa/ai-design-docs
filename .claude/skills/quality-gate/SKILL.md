---
name: quality-gate
description: Seleciona, executa e registra os gates de Teste e QA do ciclo C.L.E.A.R. Use em mudancas de software, revisao de PR ou qualificacao de release; nao use para alteracao exclusivamente documental.
---

# Quality Gate C.L.E.A.R.

- Owner: Arquitetura e Qualidade
- Status: Active

## Objetivo

Aplicar Assurance proporcional ao risco e produzir evidência reproduzível sem
inventar aprovação.

## Pré-condições

Exija plano vigente, critérios de aceite, targets explícitos e evidência
`implementation-readiness` `READY` para o mesmo task ID, versões, escopo e paths.

## Procedimento

1. Leia o lifecycle, o Software Quality Standard e os standards ativados pelo
   pacote ou risco.
2. Classifique a execução como `focused`, `pr` ou `release`.
3. Crie ou atualize testes relevantes; execute o teste focalizado e depois a suíte
   impactada.
4. Execute os comandos e validadores registrados pelo projeto para cada target.
5. Registre A1 Test, A2 Quality e A3 Security/Compliance separadamente como
   `PASS`, `FAIL` ou `BLOCKED`.
6. Em `FAIL`, corrija o escopo e reexecute enquanto houver progresso. Dependência,
   autorização, ferramenta ou ambiente ausente resulta em `BLOCKED`.
7. Só conclua quando todos os gates aplicáveis estiverem em `PASS`.

## Limites

Não reduzir limiar, suprimir teste, usar relatório histórico, ler arquivo de
segredo, acessar produção ou ampliar autoridade. Release e Git obedecem políticas
próprias do projeto de destino.

## Evidência

Registre comando, diretório, código de saída, contagens, cobertura, skips, ambiente,
targets, iterações, limitações e correspondência com o `READY`.

