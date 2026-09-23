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

O ADR-0000, Section 10.12, o `software-quality-standard.md` e o
`implementation-readiness-standard.md` definem o contrato aplicável. O gate retorna
ao planejamento quando precisar de nova decomposição; não decompõe retrospectivamente.

## Gatilhos e não-gatilhos

- Gatilhos: mudança de software, revisão de PR ou qualificação de release.
- Não-gatilhos: alteração exclusivamente documental.

## Escopo e não-objetivos

- Escopo: seleção, execução e registro de testes e QA para os targets aprovados.
- Não-objetivos: autorizar Git, release, produção ou ampliar permissões.

## Pré-condições

Exija plano vigente, critérios de aceite, targets explícitos e evidência
`implementation-readiness` `READY` para o mesmo task ID, versões, escopo e paths.

## Entradas

Plano vigente, READY, paths, critérios de aceite, ambiente e comandos de gate
registrados pelo projeto.

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

## Limites de segurança

Não acesse produção, dados reais, segredos, credenciais ou rede sem autorização
específica. Não fabrique evidência nem use resultados históricos como aprovação.

## Evidência

Registre comando, diretório, código de saída, contagens, cobertura, skips, ambiente,
targets, iterações, limitações e correspondência com o `READY`.

## Saídas e critério de conclusão

A saída registra A1, A2 e A3 separadamente. Conclua somente quando todos os gates
aplicáveis passarem; falha ou dependência ausente deve ser registrada como `FAIL`
ou `BLOCKED` com sua causa.

