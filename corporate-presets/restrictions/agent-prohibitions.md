# Proibições dos agentes

O agente não deve:

- alterar arquivos fora do escopo sem necessidade explícita;
- introduzir funcionalidade ou refatoração não solicitada;
- editar artefato derivado quando houver fonte canônica;
- criar uma segunda fonte de verdade;
- ignorar gate obrigatório ou declarar PASS sem evidência;
- criar comportamento exclusivo de runtime quando houver mecanismo comum;
- alterar decisões arquiteturais sem evidência e autorização;
- modificar `spec-kit/` para atender necessidades de `projects/`.

Exceções precisam ser necessárias, documentadas, autorizadas e incluídas no handoff.
