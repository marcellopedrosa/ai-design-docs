---
document_id: JAVA-STANDARD
primary_nature: Regra
objective: Definir baseline reutilizável para projetos que adotem Java.
scope: Versão, linguagem, modelagem, erros, concorrência, ferramentas e testes Java.
non_objectives: Não ativar Java, escolher framework, build tool, versão ou convenção de pacote.
owner: Engenharia Java e Arquitetura
status: Active
version: 1.0
date: 2026-09-11
last_reviewed: 2026-09-11
keywords: java, jvm, linguagem, concorrencia, build
related_files: README.md, development-standard.md, backend-testing-standard.md, ddd-clean-architecture-standard.md
code_references: N/A - versão e comandos devem constar no manifesto do projeto.
principal_statement: Quando Java estiver ativo, o projeto fixa uma versão suportada e usa construções explícitas, seguras e verificáveis da linguagem.
---

# Java Standard

## Ativação

Condicional a módulo Java registrado no manifesto.

## Regras

- Fixar e verificar versão de JDK, linguagem, build tool e toolchain em local
  canônico; desenvolvimento e CI usam a mesma linha suportada.
- Preferir imutabilidade, composição, tipos específicos e APIs pequenas. Records,
  sealed types e pattern matching só são usados quando melhoram o modelo e são
  suportados pela versão declarada.
- Definir política de nullability; Optional não substitui validação nem deve ser
  usado indiscriminadamente em campos, parâmetros ou serialização.
- Exceções preservam causa, contexto seguro e semântica. Não capturar Throwable,
  ocultar interrupção ou usar exceção para fluxo esperado.
- Concorrência declara ownership, cancelamento, timeout e propagação de contexto;
  não bloquear recurso ou thread model sem evidência.
- Framework annotations ficam fora do domínio quando a arquitetura ativada exigir
  independência.
- Formatação, warnings, análise estática, testes e build falham de forma
  determinística pelos comandos registrados.

## Evidência

Registrar versão efetiva, comandos, warnings, testes, análise e divergências de
toolchain. Upgrade de versão exige compatibilidade de dependências e ADR quando
material.

## Change log

| Versão | Data | Mudança |
| --- | --- | --- |
| 1.0 | 2026-09-11 | Cria baseline Java condicional e agnóstico de versão. |
