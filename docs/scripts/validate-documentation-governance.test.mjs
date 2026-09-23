import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import test from 'node:test';

import {
  validateAdrCatalogEntry,
  validateCollectionSemantics,
  validateCodeReferences,
  validateDocumentContract,
  validateGeneratedArtifactPath,
  validateGovernanceEntrypoint,
  validateGovernanceSkill,
  validateLegacyPromptBridge,
  validateImplementationReadinessGovernance,
  validateImplementationReadinessSkill,
  validateModuleRegistryStructure,
  validateOpenApiTemplate,
  validateProductRequirementsGovernance,
  validateRawTemplate,
  validateRepository,
  validateRelativeLinks,
  validateQualityGateScaffold,
  validateQualityGateSkill,
  validateSkillFile,
  validateStandardConsumerParity
} from './validate-documentation-governance.mjs';

const validDocument = `---
document_id: TEST-0001
primary_nature: Contexto
objective: Demonstrar o contrato.
scope: Fixture hermética.
non_objectives: N/A - fixture sem domínio.
owner: Qualidade
status: Active
date: 2026-08-26
version: 1.0
keywords: teste, fixture
related_files: N/A - fixture autocontida.
code_references: N/A - sem código de produção.
principal_statement: O contrato completo deve passar.
---

# TEST-0001 — Fixture
`;

test('aceita documento com contrato completo', () => {
  assert.deepEqual(validateDocumentContract(validDocument, 'fixture.md'), []);
});

test('aceita valores YAML entre aspas', () => {
  const quoted = validDocument.replace('document_id: TEST-0001', 'document_id: "TEST-0001"');
  assert.deepEqual(validateDocumentContract(quoted, 'fixture.md'), []);
});

test('rejeita campo obrigatório ausente', () => {
  const invalid = validDocument.replace('primary_nature: Contexto\n', '');
  assert.match(validateDocumentContract(invalid, 'fixture.md').join('\n'), /primary_nature/);
});

test('last_reviewed não substitui o campo Date', () => {
  const invalid = validDocument.replace('date: 2026-08-26', 'last_reviewed: 2026-08-26');
  assert.match(validateDocumentContract(invalid, 'fixture.md').join('\n'), /date/);
});

test('exemplo no corpo não substitui campo ausente no frontmatter', () => {
  const invalid = validDocument.replace('date: 2026-08-26\n', '') + '\n```yaml\ndate: 2026-08-26\n```\n';
  assert.match(validateDocumentContract(invalid, 'fixture.md').join('\n'), /date/);
});

test('rejeita lifecycle e N/A sem justificativa', () => {
  const invalid = validDocument
    .replace('status: Active', 'status: BANANA')
    .replace('version: 1.0', 'version: TBD')
    .replace('non_objectives: N/A - fixture sem domínio.', 'non_objectives: N/A');
  const errors = validateDocumentContract(invalid, 'fixture.md').join('\n');
  assert.match(errors, /status/);
  assert.match(errors, /version/);
  assert.match(errors, /sem justificativa/);
});

test('rejeita natureza fora da taxonomia', () => {
  const invalid = validDocument.replace('primary_nature: Contexto', 'primary_nature: Agente');
  assert.match(validateDocumentContract(invalid, 'fixture.md').join('\n'), /fora da taxonomia/);
});

test('valida links locais e rejeita alvo ausente', () => {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'docs-governance-'));
  const docs = path.join(root, 'docs');
  fs.mkdirSync(docs);
  const source = path.join(docs, 'source.md');
  fs.writeFileSync(source, '# Source\n');
  fs.writeFileSync(path.join(docs, 'target.md'), '# Target\n');
  assert.deepEqual(validateRelativeLinks('[ok](target.md)', source, root), []);
  assert.match(validateRelativeLinks('[bad](missing.md)', source, root).join('\n'), /quebrado/);
  fs.rmSync(root, { recursive: true, force: true });
});

test('resolve referencias de codigo por raiz, sufixo e basename', () => {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'code-references-'));
  const source = path.join(root, 'docs', 'source.md');
  const target = path.join(root, 'backend', 'src', 'main', 'java', 'example', 'Current.java');
  fs.mkdirSync(path.dirname(source), { recursive: true });
  fs.mkdirSync(path.dirname(target), { recursive: true });
  fs.writeFileSync(source, '# Source\n');
  fs.writeFileSync(target, 'class Current {}\n');
  assert.deepEqual(validateCodeReferences(
    'backend/src/main/java/example/Current.java, src/main/java/example/Current.java, Current.java',
    source,
    root
  ), []);
  assert.match(validateCodeReferences('Missing.java', source, root).join('\n'), /basename ausente/);
  assert.match(validateCodeReferences('src/main/java/.../Current.java', source, root).join('\n'), /reticencias ambiguas/);
  assert.deepEqual(validateCodeReferences('Missing.java - destino planejado', source, root), []);
  fs.rmSync(root, { recursive: true, force: true });
});

test('rejeita identidade divergente de skill', () => {
  const skill = `---\nname: actual-name\ndescription: Use quando a fixture for validada; não use fora do teste.\n---\n# Skill\n`;
  assert.match(validateSkillFile(skill, 'directory-name', 'SKILL.md').join('\n'), /difere do diretorio/);
});

test('rejeita skill sem contrato operacional', () => {
  const skill = `---\nname: demo\ndescription: Use para demonstrar a validação.\n---\n# Demo\n`;
  assert.match(validateSkillFile(skill, 'demo', 'SKILL.md').join('\n'), /contrato operacional/);
});

test('exige ADR-0000 e wrapper agregado na skill de governança', () => {
  const valid = '# Governança\nADR-0000\nSection 10.11.1\n`./infra/scripts/validate-docs.sh`\n';
  assert.deepEqual(validateGovernanceSkill(valid, 'SKILL.md'), []);
  assert.match(
    validateGovernanceSkill(valid.replace('./infra/scripts/validate-docs.sh', 'node docs/scripts/validate-documentation-governance.mjs'), 'SKILL.md').join('\n'),
    /validate-docs\.sh/
  );
});

test('exige o wrapper como entrypoint agregado do ADR-0000', () => {
  const adr = [
    '`infra/scripts/validate-docs.sh`',
    '`./infra/scripts/validate-docs.sh`',
    '### 10.11.1 Bootstrap tecnico portatil do wrapper',
    'criar `infra/scripts/`',
    'chmod +x infra/scripts/validate-docs.sh',
    '#!/usr/bin/env bash',
    'set -uo pipefail',
    'governance_validator="$repo_root/docs/scripts/validate-documentation-governance.mjs"',
    'node "$governance_validator" --root "$repo_root" || exit 1'
  ].join('\n');
  const wrapper = [
    '#!/usr/bin/env bash',
    'set -uo pipefail',
    'governance_validator="$repo_root/docs/scripts/validate-documentation-governance.mjs"',
    'node --test "$governance_validator_test"',
    'node "$governance_validator" --root "$repo_root"',
    'validate-documentation-governance.test.mjs',
    'validate-documentation-governance.mjs'
  ].join('\n');
  assert.deepEqual(validateGovernanceEntrypoint(adr, wrapper), []);
  assert.match(validateGovernanceEntrypoint(adr, wrapper.replace('validate-documentation-governance.test.mjs', '')).join('\n'), /test\.mjs/);
  assert.match(validateGovernanceEntrypoint(adr.replace('#!/usr/bin/env bash', ''), wrapper).join('\n'), /bootstrap portatil/);
});

test('exige fontes e executor sem duplicar limiares na skill de Quality Gate', () => {
  const valid = [
    'ADR-0000', 'Section 10.12', 'software-quality-standard.md',
    'implementation-readiness-standard.md',
    './infra/scripts/validate-quality-gates.sh', 'focused', 'pr', 'release',
    'PASS', 'FAIL', 'BLOCKED', 'implementation-readiness', 'READY',
    'task ID', 'Phase 7', 'não decomponha retrospectivamente'
  ].join('\n');
  assert.deepEqual(validateQualityGateSkill(valid, 'SKILL.md'), []);
  assert.match(
    validateQualityGateSkill(valid.replace('software-quality-standard.md', ''), 'SKILL.md').join('\n'),
    /software-quality-standard\.md/
  );
  assert.match(validateQualityGateSkill(`${valid}\n80%`, 'SKILL.md').join('\n'), /limiar numerico/);
});

test('protege o scaffold portatil do Quality Gate no ADR e no wrapper', () => {
  const contractTest = [
    '#!/usr/bin/env bash', 'set -uo pipefail', '--scope', '--level', '--dry-run',
    '--root', 'QUALITY_GATE_RESULT=BLOCKED',
    'fixture_root="$(mktemp -d /tmp/quality-gate-test.XXXXXX)"',
    'trap cleanup EXIT', "assert_exit 0 'all PR dry-run'",
    "assert_exit 1 'missing backend coverage blocks'",
    'local env blocks build', '7 scenarios'
  ].join('\n');
  const adr = [
    '## 10.12 Gate executavel Teste x QA do C.L.E.A.R.',
    '### 10.12.1 Ordem obrigatoria do scaffold',
    '### 10.12.2 Interface e modo de uso',
    '### 10.12.3 Bootstrap tecnico portatil do Quality Gate',
    'docs/agents/standards/software-quality-standard.md',
    '.agents/skills/quality-gate/SKILL.md',
    '.claude/skills/quality-gate/SKILL.md',
    'infra/scripts/validate-quality-gates.sh',
    'infra/scripts/tests/validate-quality-gates-test.sh',
    'implementation-readiness', 'Phase 7',
    '#### 10.12.3.1 Teste de contrato portatil integral',
    '```bash', contractTest, '```'
  ].join('\n');
  const executor = [
    '#!/usr/bin/env bash', 'set -uo pipefail', '--scope', '--level', '--focus',
    '--dry-run', '--root', 'focused', 'pr', 'release', 'QUALITY_GATE_RESULT=PASS',
    'QUALITY_GATE_RESULT=FAIL', 'QUALITY_GATE_RESULT=BLOCKED', '.env.local'
  ].join('\n');
  const wrapper = 'validate-quality-gates-test.sh';
  const standard = 'A1 — Test Gate\nA2 — Quality Gate\nA3 — Security & Compliance Gate\nPASS\nFAIL\nBLOCKED\nimplementation-readiness\nREADY\nescopo atômico\nPhase 7\nnão decompõe retrospectivamente';
  assert.deepEqual(validateQualityGateScaffold(adr, executor, contractTest, wrapper, standard), []);
  assert.match(
    validateQualityGateScaffold(adr.replace('### 10.12.3 Bootstrap tecnico portatil do Quality Gate', ''), executor, contractTest, wrapper, standard).join('\n'),
    /Bootstrap tecnico portatil/
  );
  assert.match(
    validateQualityGateScaffold(adr.replace('#### 10.12.3.1 Teste de contrato portatil integral', ''), executor, contractTest, wrapper, standard).join('\n'),
    /Teste de contrato portatil integral/
  );
  assert.match(
    validateQualityGateScaffold(adr, `${executor}\ngit diff`, contractTest, wrapper, standard).join('\n'),
    /Git e proibida/
  );
  assert.match(
    validateQualityGateScaffold(adr, executor, `${contractTest}\nextra`, wrapper, standard).join('\n'),
    /corpo integral do teste portatil diverge/
  );
});

test('exige hard gate e ordem operacional na skill de implementation readiness', () => {
  const valid = [
    'ADR-0000 Section 10.13 implementation-readiness-standard.md',
    'READY BLOCKED Assumption Open Question perguntar ao humano não existe waiver AC aplicável teste/evidência',
    'PRD aplicável PRD not applicable Product Hypothesis',
    'Granularidade / Decomposição decomponha semanticamente pai → filhos reexecute o gate para cada unidade',
    'Gate Audit', 'Acceptance Tests', 'Prohibited', 'Mandatory', 'Definition of Done'
  ].join('\n');
  assert.deepEqual(validateImplementationReadinessSkill(valid, 'SKILL.md'), []);
  assert.match(
    validateImplementationReadinessSkill(valid.replace('perguntar ao humano', ''), 'SKILL.md').join('\n'),
    /perguntar ao humano/
  );
  const wrongOrder = valid.replace('Gate Audit', 'TEMP').replace('Mandatory', 'Gate Audit').replace('TEMP', 'Mandatory');
  assert.match(validateImplementationReadinessSkill(wrongOrder, 'SKILL.md').join('\n'), /ordem da auditoria/);
});

test('protege a governanca portatil do implementation readiness', () => {
  const fields = 'What Where Depends on Reuses Requirements Gate Audit Acceptance Tests Prohibited Mandatory Definition of Done READY BLOCKED';
  const artifacts = {
    adr: [
      '## 10.13 Implementation Readiness Gate do C.L.E.A.R.',
      '### 10.13.1 Invariante dura e estados',
      '### 10.13.5 Scaffold portatil da skill',
      'docs/agents/standards/implementation-readiness-standard.md',
      '.agents/skills/implementation-readiness/SKILL.md',
      '.claude/skills/implementation-readiness/SKILL.md',
      'Nao existe waiver User Story View US-NNN matriz AC Product Definition Gate TPL-00012',
      '#### 10.13.1.1 Decomposicao semantica automatica',
      'Granularity / Decomposition pai → filhos',
      'Falha de granularidade NAO e um motivo final de `BLOCKED`'
    ].join('\n'),
    standard: `READY BLOCKED Assumption Open Question User Story View AC → fluxo → teste/evidência ${fields} não despachar implementação Product Definition PRD Validated Product Hypothesis Granularidade / Decomposição Decomposição semântica automática pai → filhos reexecutar o IRG separadamente para cada unidade`,
    requirementTemplate: 'User Story View Assumptions and Open Questions Readiness Declaration perguntar ao humano',
    useCaseTemplate: 'User Story View Assumptions Open Questions Implementation Readiness Assumption não é precondition Acceptance Criteria Coverage Planned Test or Evidence',
    prdTemplate: 'Product Definition Gate Product hypotheses Success metrics Requirement map Approval and readiness O agente não promove',
    taskPlanTemplate: `Implementation Readiness Gate ${fields} Granularity / Decomposition parent → child`,
    implementationPlanTemplate: `Implementation Readiness Gate ${fields} Granularity / Decomposition parent → child`,
    rawImplementationPlanTemplate: `Implementation Readiness Gate ${fields} Granularity / Decomposition parent → child`,
    lifecycle: 'implementation-readiness READY Uncertainty Hard Gate Finite Task Rule Product Definition Gate PRD-NNNNN Validated Automatic Semantic Decomposition Rule parent → child return the work to Phase 7',
    orchestrator: 'Always audit implementation readiness ask the human/owner implementation-readiness Enforce Product Definition PRD not applicable Automatically correct granularity parent → child re-audits every child',
    requirementAgent: 'Classify and close uncertainty Proposed Open Question eligibility `No` TPL-00012 never validate the PRD',
    codeGuardian: 'READINESS EVIDENCE blocking process AgentOrchestrator Divergent Atomic Scope return to Phase 7 Do not',
    agentsAdapter: 'implementation-readiness READY Open Question humano/owner PRD not applicable Validated Falha de granularidade pai → filhos Quality Gate',
    claudeAdapter: 'implementation-readiness READY Open Question humano/owner PRD not applicable Validated Falha de granularidade pai → filhos Quality Gate'
  };
  assert.deepEqual(validateImplementationReadinessGovernance(artifacts), []);
  assert.match(
    validateImplementationReadinessGovernance({
      ...artifacts,
      requirementTemplate: `${artifacts.requirementTemplate} US-NNN`
    }).join('\n'),
    /User Story autonomo/
  );
  assert.match(
    validateImplementationReadinessGovernance({
      ...artifacts,
      adr: artifacts.adr.replace('#### 10.13.1.1 Decomposicao semantica automatica', '')
    }).join('\n'),
    /Decomposicao semantica automatica/
  );
  assert.match(
    validateImplementationReadinessGovernance({
      ...artifacts,
      lifecycle: artifacts.lifecycle.replace('return the work to Phase 7', '')
    }).join('\n'),
    /return the work to Phase 7/
  );
});

test('valida o contrato exigido por uma variante raw', () => {
  const validRaw = `Deve criar H1 com Document ID, Primary Nature, Objective, Scope,
Non-objectives, Owner, Status, Date, Version, Keywords, Related
Files,
Code References e Principal Statement. Na mesma alteração, atualize o README.md.`;
  assert.deepEqual(validateRawTemplate(validRaw, 'template.raw'), []);
  assert.match(validateRawTemplate(validRaw.replace('Date, ', ''), 'template.raw').join('\n'), /date/);
});

test('exige path canônico nas variantes de agente', () => {
  const raw = `Deve criar H1 com Document ID, Primary Nature, Objective, Scope,
Non-objectives, Owner, Status, Date, Version, Keywords, Related Files,
Code References e Principal Statement em docs/agents/<NomeDoAgente>.md.
Na mesma alteração, atualize o README.md.`;
  assert.deepEqual(validateRawTemplate(raw, 'TPL-00001-Agent.raw'), []);
  assert.match(
    validateRawTemplate(raw.replace('docs/agents/<NomeDoAgente>.md', 'docs/agents/'), 'TPL-00001-Agent.raw').join('\n'),
    /caminho canônico/
  );
  assert.deepEqual(validateGeneratedArtifactPath(
    'Create docs/agents/<AGENT_FILE_STEM>.md.',
    'TPL-00001',
    'TPL-00001.md'
  ), []);
  assert.match(validateGeneratedArtifactPath('Create in docs/agents/.', 'TPL-00001', 'TPL-00001.md').join('\n'), /omite caminho/);
});

test('protege nome, natureza e lifecycle da coleção de PRDs', () => {
  const root = path.join(os.tmpdir(), 'prd-collection');
  const file = path.join(root, 'docs/product_requirements/PRD-00001-demo.md');
  const validPrd = validDocument
    .replace('document_id: TEST-0001', 'document_id: PRD-00001')
    .replace('primary_nature: Contexto', 'primary_nature: Requisito')
    .replace('status: Active', 'status: In Review');
  assert.deepEqual(validateCollectionSemantics(validPrd, file, root), []);
  assert.match(
    validateCollectionSemantics(validPrd, path.join(path.dirname(file), 'demo.md'), root).join('\n'),
    /nome fora da convencao/
  );
  assert.match(
    validateCollectionSemantics(validPrd.replace('primary_nature: Requisito', 'primary_nature: Contexto'), file, root).join('\n'),
    /natureza Requisito/
  );
  assert.match(
    validateCollectionSemantics(validPrd.replace('status: In Review', 'status: Approved'), file, root).join('\n'),
    /status Approved nao e permitido/
  );
});

test('protege o esqueleto e o fechamento do Product Definition Gate', () => {
  const index = `PRD-NNNNN-short-title.md Draft In Review Validated Deprecated
Product Definition Gate TPL-00001-prd.md
não copia seus acceptance criteria; referencia casos de uso sem recontar fluxos;
referencia ADRs sem decidir arquitetura; F-<CONTEXTO>-NNN;
referência a IDs/seção de aceite`;
  const sections = `## 2. Problem and evidence
## 3. Audience and value
## 4. Objectives and outcomes
## 5. Product scope and limits
## 6. Product validation criteria
## 7. Success metrics
## 8. Product hypotheses
## 9. Requirement map
### 9.1 Feature inventory and acceptance coverage
## 10. Use cases and decisions by reference
## 11. Current phase assessment
## 13. Open questions and decisions
## 14. Approval and readiness
**Product Definition Gate:** \`BLOCKED\``;
  const template = `docs/product_requirements/PRD-NNNNN-<short-title>.md
${sections}
vários \`REQ-NNNNN\`; não copie acceptance criteria; não redefine decisões arquiteturais;
O agente não promove seu próprio documento a \`Validated\`;
F-<CONTEXTO>-NNN; IDs ausentes — lacuna documental`;
  const featureRow = '| `F-DEMO-001` | Resultado para o público. | [REQ-00001](../requirements/REQ-00001-demo.md) | [AC-001](../requirements/REQ-00001-demo.md#7-acceptance-criteria) | Approved. |';
  const prd = `---
document_id: PRD-00001
primary_nature: Requisito
status: In Review
---
${sections}
${featureRow}
REQ-00001 REQ-00002`;
  const artifacts = { index, template, prds: [{ path: 'docs/product_requirements/PRD-00001-demo.md', content: prd }] };
  assert.deepEqual(validateProductRequirementsGovernance(artifacts), []);
  assert.match(
    validateProductRequirementsGovernance({
      ...artifacts,
      prds: [{ ...artifacts.prds[0], content: prd.replaceAll('REQ-00002', 'REQ-00001') }]
    }).join('\n'),
    /agrupar e apontar para varios/
  );
  assert.match(
    validateProductRequirementsGovernance({
      ...artifacts,
      prds: [{ ...artifacts.prds[0], content: prd.replace('status: In Review', 'status: Validated') }]
    }).join('\n'),
    /Gate PASS/
  );
  assert.match(
    validateProductRequirementsGovernance({
      ...artifacts,
      prds: [{ ...artifacts.prds[0], content: prd.replace('F-DEMO-001', 'feature-without-id') }]
    }).join('\n'),
    /nao possui feature ID/
  );
  assert.match(
    validateProductRequirementsGovernance({
      ...artifacts,
      prds: [{ ...artifacts.prds[0], content: prd.replace(featureRow, featureRow.replaceAll('REQ-00001', 'requirement-pending')) }]
    }).join('\n'),
    /nao referencia REQ-NNNNN/
  );
  assert.match(
    validateProductRequirementsGovernance({
      ...artifacts,
      prds: [{ ...artifacts.prds[0], content: prd.replace('[AC-001](../requirements/REQ-00001-demo.md#7-acceptance-criteria)', 'aceite pendente') }]
    }).join('\n'),
    /nao referencia IDs ou secao canonica de aceite/
  );
  assert.match(
    validateProductRequirementsGovernance({
      ...artifacts,
      prds: [{ ...artifacts.prds[0], content: prd.replace('[AC-001](../requirements/REQ-00001-demo.md#7-acceptance-criteria)', '[AC-001](../requirements/REQ-00001-demo.md#7-acceptance-criteria) Given X When Y Then Z') }]
    }).join('\n'),
    /duplica texto de acceptance criteria/
  );
  assert.deepEqual(validateGeneratedArtifactPath(
    'Create docs/product_requirements/PRD-NNNNN-<short-title>.md.',
    'TPL-00012',
    'TPL-00012.md'
  ), []);
});

test('valida template OpenAPI por seu contrato YAML, não pelo contrato Markdown', () => {
  const template = `Antes de criar, consulte docs/contracts/README.md e, na mesma mudança, atualize o índice.
openapi: 3.1.0
x-document-metadata:
  documentId: DEMO-V1
  primaryNature: Contrato
  owner: Arquitetura
  status: Draft
  date: YYYY-MM-DD
  lastReviewed: YYYY-MM-DD
  normativeBaseline: REQ-00001
  relatedFiles: []
x-change-log: []
operationId: demo
security: []
x-required-roles: []
x-required-authorities: []
content: application/problem+json`;
  assert.deepEqual(validateOpenApiTemplate(template, 'TPL-00011.md'), []);
  assert.match(
    validateOpenApiTemplate(template.replace('operationId:', 'operation:'), 'TPL-00011.md').join('\n'),
    /operationId/
  );
});

test('rejeita status ou data original divergente no catálogo de ADRs', () => {
  const adr = 'Status: Accepted\n- Data original: 2026-07-24\n';
  const validRow = '| [ADR-0018](ADR-0018-demo.md) | Demo | Accepted | 2026-07-24 | Segurança |';
  assert.deepEqual(validateAdrCatalogEntry(adr, 'ADR-0018-demo.md', validRow), []);
  const errors = validateAdrCatalogEntry(
    adr,
    'ADR-0018-demo.md',
    '| [ADR-0018](ADR-0018-demo.md) | Demo | Proposed | 2026-07-23 | Segurança |'
  ).join('\n');
  assert.match(errors, /status/);
  assert.match(errors, /data original/);
});

test('rejeita a reintrodução de prompt concorrente no website', () => {
  const plan = '../../docs/task_plans/TP-00021-hub-contabil-landing-page-implementation-brief.md';
  const website = '[ponteiro](prompt/README.md) [plano](../docs/task_plans/TP-00021-hub-contabil-landing-page-implementation-brief.md)';
  assert.deepEqual(validateLegacyPromptBridge(
    `Este diretório não mantém prompt operacional ativo. [TP-00021](${plan}).`,
    website
  ), []);
  assert.match(validateLegacyPromptBridge(`Você é uma equipe. [TP-00021](${plan}).`, website).join('\n'), /fonte concorrente/);
});

test('exige relação reversa para cada consumidor de standard', () => {
  const standardCatalog = '| [Demo](demo-standard.md) | Demo | Qualidade | Active | demo | DemoAgent | N/A |';
  const validAgentCatalog = '| [DemoAgent](DemoAgent.md) | Demo | Qualidade | Active | [demo](standards/demo-standard.md) |';
  const validDocuments = new Map([['DemoAgent.md', 'related_files: docs/agents/standards/demo-standard.md']]);
  assert.deepEqual(validateStandardConsumerParity(validAgentCatalog, standardCatalog, validDocuments), []);
  const errors = validateStandardConsumerParity(
    '| [DemoAgent](DemoAgent.md) | Demo | Qualidade | Active | N/A |',
    standardCatalog,
    new Map([['DemoAgent.md', 'related_files: N/A - sem standard.']])
  ).join('\n');
  assert.match(errors, /DemoAgent\.md: omite standard consumidor/);
  assert.match(errors, /README\.md: DemoAgent omite relacionamento reverso/);
});

test('rejeita rota incompleta, excesso e recapitulação no manifesto de módulos', () => {
  const header = '| Domínio | Pacote físico | Owner | Entry points | Dependências | Documentação |';
  const modulePath = 'backend/src/main/java/br/com/duoset/saas_service/contexts/demo/';
  const registry = `---
code_references: "backend/, frontend/, website/, infra/, docs/"
---
${header}
| --- | --- | --- | --- | --- | --- |
| Backend | \`backend/\` | Owner | Entry | Deps | Docs |
| Frontend | \`frontend/\` | Owner | Entry | Deps | Docs |
| Website | \`website/\` | Owner | Entry | Deps | Docs |
| Infra | \`infra/\` | Owner | Entry | Deps | Docs |
| Docs | \`docs/\` | Owner | Entry | Deps | Docs |
${header}
| --- | --- | --- | --- | --- | --- |
| Demo | \`${modulePath}\` | Owner | Entry | Deps | Docs |
`;
  assert.deepEqual(validateModuleRegistryStructure(registry, [modulePath]), []);
  const incomplete = registry.replace('| Demo |', '| |');
  assert.match(validateModuleRegistryStructure(incomplete, [modulePath]).join('\n'), /rota incompleta/);
  const oversized = `${registry}${'\n'.repeat(221)}`;
  assert.match(validateModuleRegistryStructure(oversized, [modulePath]).join('\n'), /orçamento seletivo/);
  assert.match(validateModuleRegistryStructure(`${registry}\n### Target aceito`, [modulePath]).join('\n'), /duplicar lifecycle/);
});

test('repositório satisfaz o contrato integrado', () => {
  const repositoryRoot = path.resolve(path.dirname(new URL(import.meta.url).pathname), '../..');
  assert.deepEqual(validateRepository(repositoryRoot).errors, []);
});
