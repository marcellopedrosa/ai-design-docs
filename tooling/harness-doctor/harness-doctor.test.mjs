import test from 'node:test';
import assert from 'node:assert/strict';
import path from 'node:path';
import fs from 'node:fs';
import os from 'node:os';
import {
  checkRegistry,
  checkContracts,
  checkSkills,
  checkAdapters,
  checkEvals,
  checkFixtureReferences,
  checkDrift,
  parseSimpleYaml,
  splitAllowedTools,
  toolName,
  findRoot,
  checkMarkdownLinks,
  expandBraces,
  checkDistributedTree,
  checkAgentIndex,
  checkVersionParity
} from './index.mjs';

test('checkRegistry passes on repository root', () => {
  const root = path.resolve('.');
  const { errors } = checkRegistry(root);
  assert.equal(errors.length, 0, `Registry errors: ${errors.join(', ')}`);
});

test('checkContracts passes on repository root', () => {
  const root = path.resolve('.');
  const { errors } = checkContracts(root);
  assert.equal(errors.length, 0, `Contract errors: ${errors.join(', ')}`);
});

test('checkSkills passes on repository root', () => {
  const root = path.resolve('.');
  const { errors } = checkSkills(root);
  assert.equal(errors.length, 0, `Skill errors: ${errors.join(', ')}`);
});

test('checkAdapters passes on repository root', () => {
  const root = path.resolve('.');
  const { errors } = checkAdapters(root);
  assert.equal(errors.length, 0, `Adapter errors: ${errors.join(', ')}`);
});

test('checkEvals passes on repository root and validates eval counts', () => {
  const root = path.resolve('.');
  const { errors, count } = checkEvals(root);
  assert.equal(errors.length, 0, `Eval errors: ${errors.join(', ')}`);
  assert.ok(count > 0, `Expected eval count > 0, got ${count}`);
});

test('description of exactly 500 characters is accepted', () => {
  const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'hd-'));
  const skillDir = path.join(tmp, 'skills', 'test-skill');
  fs.mkdirSync(skillDir, { recursive: true });
  fs.mkdirSync(path.join(skillDir, 'evals'), { recursive: true });
  fs.writeFileSync(path.join(skillDir, 'contract.yaml'), 'name: test-skill\n');
  fs.writeFileSync(path.join(skillDir, 'evals', 'evals.json'), '{"evals":[{"id":"t1","category":"c","description":"d","input":"i","expected":"e","assertions":"a"}]}');
  const desc500 = 'A'.repeat(500);
  fs.writeFileSync(path.join(skillDir, 'SKILL.md'), `---\nname: test-skill\ndescription: ${desc500}\n---\n`);
  const { errors } = checkSkills(tmp);
  const descErrors = errors.filter(e => e.includes('description'));
  assert.equal(descErrors.length, 0, `500-char description should be accepted: ${descErrors.join(', ')}`);
  fs.rmSync(tmp, { recursive: true, force: true });
});

test('description of 501 characters is rejected', () => {
  const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'hd-'));
  const skillDir = path.join(tmp, 'skills', 'test-skill');
  fs.mkdirSync(skillDir, { recursive: true });
  fs.mkdirSync(path.join(skillDir, 'evals'), { recursive: true });
  fs.writeFileSync(path.join(skillDir, 'contract.yaml'), 'name: test-skill\n');
  fs.writeFileSync(path.join(skillDir, 'evals', 'evals.json'), '{"evals":[{"id":"t1","category":"c","description":"d","input":"i","expected":"e","assertions":"a"}]}');
  const desc501 = 'A'.repeat(501);
  fs.writeFileSync(path.join(skillDir, 'SKILL.md'), `---\nname: test-skill\ndescription: ${desc501}\n---\n`);
  const { errors } = checkSkills(tmp);
  const descErrors = errors.filter(e => e.includes('description'));
  assert.ok(descErrors.length > 0, '501-char description should be rejected');
  fs.rmSync(tmp, { recursive: true, force: true });
});

test('checkFixtureReferences passes on repository root', () => {
  const root = path.resolve('.');
  const { errors } = checkFixtureReferences(root);
  assert.equal(errors.length, 0, `Fixture reference errors: ${errors.join(', ')}`);
});

test('checkFixtureReferences detects orphan fixture', () => {
  const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'hd-fix-'));
  const fixtureDir = path.join(tmp, 'skills', 'test-skill', 'fixtures', 'orphan-case');
  fs.mkdirSync(fixtureDir, { recursive: true });
  fs.writeFileSync(path.join(fixtureDir, 'test.txt'), 'orphan');
  const evalDir = path.join(tmp, 'skills', 'test-skill', 'evals');
  fs.mkdirSync(evalDir, { recursive: true });
  fs.writeFileSync(path.join(evalDir, 'evals.json'), JSON.stringify({
    evals: [{ id: 't1', category: 'c', description: 'd', input: {}, expected: 'e', assertions: 'a' }]
  }));
  fs.mkdirSync(path.join(tmp, 'evals'), { recursive: true });
  const { errors } = checkFixtureReferences(tmp);
  const orphanErrors = errors.filter(e => e.includes('órfão'));
  assert.ok(orphanErrors.length > 0, 'Should detect orphan fixture');
  fs.rmSync(tmp, { recursive: true, force: true });
});

test('checkFixtureReferences detects missing fixture', () => {
  const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'hd-fix-'));
  const evalDir = path.join(tmp, 'skills', 'test-skill', 'evals');
  fs.mkdirSync(evalDir, { recursive: true });
  fs.writeFileSync(path.join(evalDir, 'evals.json'), JSON.stringify({
    evals: [{ id: 't1', category: 'c', description: 'd', input: { fixture: '../fixtures/nonexistent/file.txt' }, expected: 'e', assertions: 'a' }]
  }));
  fs.mkdirSync(path.join(tmp, 'evals'), { recursive: true });
  const { errors } = checkFixtureReferences(tmp);
  const missingErrors = errors.filter(e => e.includes('inexistente'));
  assert.ok(missingErrors.length > 0, 'Should detect missing fixture');
  fs.rmSync(tmp, { recursive: true, force: true });
});

test('checkDrift rejects substring match for skill names', () => {
  const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'hd-drift-'));
  fs.mkdirSync(path.join(tmp, 'registry'), { recursive: true });
  fs.writeFileSync(path.join(tmp, 'registry', 'skills.yaml'), 'skills:\n  quality-gate:\n    status: active\n');
  fs.mkdirSync(path.join(tmp, 'docs', 'agents', 'skills'), { recursive: true });
  fs.writeFileSync(path.join(tmp, 'docs', 'agents', 'skills', 'README.md'), '| quality-gate-extra | description |\n');
  fs.writeFileSync(path.join(tmp, 'README.md'), 'quality-gate-extra is great\n');
  const { errors } = checkDrift(tmp);
  assert.ok(errors.length > 0, `Should detect that "quality-gate" is not matched by "quality-gate-extra": ${errors.join(', ')}`);
  fs.rmSync(tmp, { recursive: true, force: true });
});

test('parseSimpleYaml fails loud on inline arrays with content', () => {
  assert.throws(
    () => parseSimpleYaml('items: [a, b]', 'test.yaml'),
    /test\.yaml:1: sintaxe YAML não suportada: listas inline/
  );
});

test('parseSimpleYaml fails loud on multiline strings with | or >', () => {
  assert.throws(
    () => parseSimpleYaml('desc: |\n  line1\n  line2', 'test.yaml'),
    /test\.yaml:1: sintaxe YAML não suportada: strings multilinha com '\|' ou '>'/
  );
  assert.throws(
    () => parseSimpleYaml('desc: >\n  line1\n  line2', 'test.yaml'),
    /test\.yaml:1: sintaxe YAML não suportada: strings multilinha com '\|' ou '>'/
  );
});

test('parseSimpleYaml fails loud on anchors and aliases', () => {
  assert.throws(
    () => parseSimpleYaml('val: &anchor 123', 'test.yaml'),
    /test\.yaml:1: sintaxe YAML não suportada: âncoras '&'/
  );
  assert.throws(
    () => parseSimpleYaml('ref: *anchor', 'test.yaml'),
    /test\.yaml:1: sintaxe YAML não suportada: aliases '\*'/
  );
});

test('parseSimpleYaml fails loud on inline objects', () => {
  assert.throws(
    () => parseSimpleYaml('obj: { a: 1 }', 'test.yaml'),
    /test\.yaml:1: sintaxe YAML não suportada: objetos inline/
  );
});

test('parseSimpleYaml parses standard indented YAML correctly and allows quoted special chars', () => {
  const yaml = `
# Comment
title: "Logic & Layout"
count: 42
active: true
disabled: false
tags:
  - first
  - second
nested:
  key: value
`;
  const result = parseSimpleYaml(yaml, 'valid.yaml');
  assert.equal(result.title, 'Logic & Layout');
  assert.equal(result.count, 42);
  assert.equal(result.active, true);
  assert.equal(result.disabled, false);
  assert.deepEqual(result.tags, ['first', 'second']);
  assert.deepEqual(result.nested, { key: 'value' });
});

test('checkSkills rejects skill with filesystem_write: deny when allowed-tools includes Edit or Write', () => {
  const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'hd-skill-perm-'));
  fs.mkdirSync(path.join(tmp, 'registry'), { recursive: true });
  fs.writeFileSync(path.join(tmp, 'registry', 'skills.yaml'), `
skills:
  strict-skill:
    status: active
    permissions:
      filesystem_write: deny
`);
  const skillDir = path.join(tmp, 'skills', 'strict-skill');
  fs.mkdirSync(skillDir, { recursive: true });
  fs.writeFileSync(path.join(skillDir, 'contract.yaml'), 'name: strict-skill\n');
  fs.mkdirSync(path.join(skillDir, 'evals'), { recursive: true });
  fs.writeFileSync(path.join(skillDir, 'evals', 'evals.json'), '{"evals":[{"id":"t1","category":"c","description":"d","input":"i","expected":"e","assertions":"a"}]}');

  // Case 1: allowed-tools missing
  fs.writeFileSync(path.join(skillDir, 'SKILL.md'), '---\nname: strict-skill\ndescription: test\n---\n');
  const res1 = checkSkills(tmp);
  assert.ok(res1.errors.some(e => e.includes('allowed-tools ausente')));

  // Case 2: allowed-tools includes Edit while filesystem_write is deny
  fs.writeFileSync(path.join(skillDir, 'SKILL.md'), '---\nname: strict-skill\ndescription: test\nallowed-tools: Read, Edit\n---\n');
  const res2 = checkSkills(tmp);
  assert.ok(res2.errors.some(e => e.includes('ferramentas de escrita')));

  // Case 3: allowed-tools read-only passes
  fs.writeFileSync(path.join(skillDir, 'SKILL.md'), '---\nname: strict-skill\ndescription: test\nallowed-tools: Read, Grep, Glob\n---\n');
  const res3 = checkSkills(tmp);
  assert.equal(res3.errors.length, 0, `Read-only tools should pass: ${res3.errors.join(', ')}`);

  fs.rmSync(tmp, { recursive: true, force: true });
});

test('checkContracts validates harness.project.yaml and harness.project.example.yaml', () => {
  const root = path.resolve('.');
  const tmp = fs.mkdtempSync(path.join(root, 'scratch-contracts-test-'));

  // Copy contracts and evals/schema into tmp
  fs.cpSync(path.join(root, 'contracts'), path.join(tmp, 'contracts'), { recursive: true });
  fs.mkdirSync(path.join(tmp, 'evals', 'schema'), { recursive: true });
  fs.copyFileSync(
    path.join(root, 'evals', 'schema', 'harness-eval.schema.json'),
    path.join(tmp, 'evals', 'schema', 'harness-eval.schema.json')
  );

  // Missing example manifest should fail
  const res1 = checkContracts(tmp);
  assert.ok(res1.errors.some(e => e.includes('harness.project.example.yaml: manifesto de exemplo ausente')));

  // Valid example manifest should pass
  fs.copyFileSync(path.join(root, 'harness.project.example.yaml'), path.join(tmp, 'harness.project.example.yaml'));
  const res2 = checkContracts(tmp);
  assert.equal(res2.errors.length, 0, `Valid example should pass: ${res2.errors.join(', ')}`);

  // Invalid actual manifest should fail
  fs.writeFileSync(path.join(tmp, 'harness.project.yaml'), 'schema_version: 1\nharness_version: "2.0.0"\nproject:\n  id: "missing-fields"\n');
  const res3 = checkContracts(tmp);
  assert.ok(res3.errors.some(e => e.includes('harness.project.yaml: falha na validação de contrato')));

  // Valid profile under examples/profiles/ passes
  fs.unlinkSync(path.join(tmp, 'harness.project.yaml'));
  const profilesDir = path.join(tmp, 'examples', 'profiles');
  fs.mkdirSync(profilesDir, { recursive: true });
  fs.copyFileSync(path.join(root, 'examples', 'profiles', 'java-spring.yaml'), path.join(profilesDir, 'java-spring.yaml'));
  const res4 = checkContracts(tmp);
  assert.equal(res4.errors.length, 0, `Valid profile should pass: ${res4.errors.join(', ')}`);

  // Invalid profile under examples/profiles/ fails
  fs.writeFileSync(path.join(profilesDir, 'broken.yaml'), 'schema_version: 1\nharness_version: "2.0.0"\nproject:\n  invalid: true\n');
  const res5 = checkContracts(tmp);
  assert.ok(res5.errors.some(e => e.includes('examples/profiles/broken.yaml: falha na validação de contrato')));

  fs.rmSync(tmp, { recursive: true, force: true });
});

test('T-06: splitAllowedTools handles scoped tools and nested commas correctly', () => {
  const tools = splitAllowedTools('Bash(git add:*, git commit:*), Read, Edit(foo:*)');
  assert.deepStrictEqual(tools, [
    'Bash(git add:*, git commit:*)',
    'Read',
    'Edit(foo:*)'
  ]);
  const names = tools.map(toolName);
  assert.deepStrictEqual(names, ['Bash', 'Read', 'Edit']);
});

test('T-06: checkSkills rejects scoped Bash with local_exec: deny and MultiEdit with filesystem_write: deny', () => {
  const root = path.resolve('.');
  const tmp = fs.mkdtempSync(path.join(root, 'scratch-skills-scope-'));
  fs.mkdirSync(path.join(tmp, 'registry'), { recursive: true });
  fs.writeFileSync(path.join(tmp, 'registry', 'skills.yaml'), `
schema_version: 1
skills:
  scope-skill:
    status: active
    permissions:
      filesystem_write: deny
      local_exec: deny
`);
  const skillDir = path.join(tmp, 'skills', 'scope-skill');
  fs.mkdirSync(skillDir, { recursive: true });
  fs.writeFileSync(path.join(skillDir, 'contract.yaml'), 'name: scope-skill\n');
  fs.mkdirSync(path.join(skillDir, 'evals'), { recursive: true });
  fs.writeFileSync(path.join(skillDir, 'evals', 'evals.json'), '{"evals":[{"id":"t1","category":"c","description":"d","input":"i","expected":"e","assertions":"a"}]}');

  // Case 1: scoped Bash(rm:*) triggers local_exec: deny
  fs.writeFileSync(path.join(skillDir, 'SKILL.md'), '---\nname: scope-skill\ndescription: test\nallowed-tools: Bash(rm:*), Read\n---\n');
  const res1 = checkSkills(tmp);
  assert.ok(res1.errors.some(e => e.includes('allowed-tools inclui Bash')));

  // Case 2: MultiEdit triggers filesystem_write: deny
  fs.writeFileSync(path.join(skillDir, 'SKILL.md'), '---\nname: scope-skill\ndescription: test\nallowed-tools: MultiEdit, Read\n---\n');
  const res2 = checkSkills(tmp);
  assert.ok(res2.errors.some(e => e.includes('ferramentas de escrita')));

  fs.rmSync(tmp, { recursive: true, force: true });
});

test('T-11: findRoot locates repository root from nested subdirectory', () => {
  const root = path.resolve('.');
  const sub = path.join(root, 'tooling', 'harness-doctor');
  const found = findRoot(sub);
  assert.equal(found, root);
});

test('T-04: checkMarkdownLinks passes on repository root', () => {
  const root = path.resolve('.');
  const { errors } = checkMarkdownLinks(root);
  assert.equal(errors.length, 0, `Markdown link errors: ${errors.join(', ')}`);
});

test('T-04: checkMarkdownLinks detects broken relative link', () => {
  const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'hd-links-'));
  fs.writeFileSync(path.join(tmp, 'valid.md'), '# Valid\n');
  fs.writeFileSync(
    path.join(tmp, 'test.md'),
    'Link [broken](missing.md) and [ok](valid.md) and [external](https://example.com).'
  );
  const { errors } = checkMarkdownLinks(tmp);
  assert.equal(errors.length, 1);
  assert.ok(errors[0].includes('link relativo quebrado -> missing.md'));
  fs.rmSync(tmp, { recursive: true, force: true });
});

test('T-04: expandBraces expands single and multiple nested braces', () => {
  assert.deepEqual(expandBraces('foo/{a,b}/bar'), ['foo/a/bar', 'foo/b/bar']);
  assert.deepEqual(expandBraces('{x,y}/{1,2}'), ['x/1', 'x/2', 'y/1', 'y/2']);
  assert.deepEqual(expandBraces('simple/path'), ['simple/path']);
});

test('T-04: checkDistributedTree passes on repository root', () => {
  const root = path.resolve('.');
  const { errors } = checkDistributedTree(root);
  assert.equal(errors.length, 0, `Distributed tree errors: ${errors.join(', ')}`);
});

test('T-04: checkDistributedTree detects missing path', () => {
  const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'hd-tree-'));
  fs.writeFileSync(
    path.join(tmp, 'README.md'),
    '# Test\n\n## Árvore distribuída\n\n```text\nmissing-dir/missing-file.md\n```\n'
  );
  const { errors } = checkDistributedTree(tmp);
  assert.ok(errors.length > 0);
  assert.ok(errors.some(e => e.includes("árvore distribuída cita 'missing-dir/missing-file.md' inexistente")));
  fs.rmSync(tmp, { recursive: true, force: true });
});

test('T-04: checkAgentIndex passes on repository root', () => {
  const root = path.resolve('.');
  const { errors } = checkAgentIndex(root);
  assert.equal(errors.length, 0, `Agent index errors: ${errors.join(', ')}`);
});

test('T-04: checkAgentIndex detects unlinked or unlisted agent', () => {
  const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'hd-agent-'));
  const agentsDir = path.join(tmp, 'docs', 'agents');
  fs.mkdirSync(agentsDir, { recursive: true });
  fs.writeFileSync(path.join(agentsDir, 'README.md'), '# Agents\n');
  fs.writeFileSync(path.join(agentsDir, 'OrphanAgent.md'), '# Orphan\n');
  fs.writeFileSync(
    path.join(tmp, 'README.md'),
    '# Root\n\n## Árvore distribuída\n\n```text\ndocs/agents/README.md\n```\n'
  );
  const { errors } = checkAgentIndex(tmp);
  assert.ok(errors.some(e => e.includes("docs/agents/README.md: agente 'OrphanAgent.md' ausente")));
  assert.ok(errors.some(e => e.includes("README.md: agente 'OrphanAgent.md' ausente da árvore distribuída")));
  fs.rmSync(tmp, { recursive: true, force: true });
});

test('T-04: checkVersionParity passes on repository root', () => {
  const root = path.resolve('.');
  const { errors } = checkVersionParity(root);
  assert.equal(errors.length, 0, `Version parity errors: ${errors.join(', ')}`);
});

test('T-04: checkVersionParity detects divergent versions', () => {
  const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'hd-ver-'));
  fs.mkdirSync(path.join(tmp, 'registry'), { recursive: true });
  fs.writeFileSync(path.join(tmp, 'registry', 'harness.yaml'), 'harness_version: "2.0.0"\n');
  fs.writeFileSync(path.join(tmp, 'harness.project.example.yaml'), 'harness_version: "2.1.0"\n');
  fs.writeFileSync(path.join(tmp, 'README.md'), '---\nversion: 2.0.0\n---\n# Root\n');
  const { errors } = checkVersionParity(tmp);
  assert.ok(errors.some(e => e.includes('divergência entre')));
  fs.rmSync(tmp, { recursive: true, force: true });
});

