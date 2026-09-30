import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import test from 'node:test';
import { fileURLToPath } from 'node:url';
import { checkRegistry, runDoctor } from './harness-doctor/index.mjs';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
const run = (script, args = []) => spawnSync(process.execPath, [path.join(root, script), ...args], { cwd: root, encoding: 'utf8' });

function fixture(source, status, assertErrors) {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'harness-integrity-'));
  try {
    const registry = path.join(dir, 'harness', 'registry');
    fs.mkdirSync(registry, { recursive: true });
    for (const name of ['harness', 'skills', 'standards', 'runtimes']) fs.writeFileSync(path.join(registry, `${name}.yaml`), 'schema_version: 1\n');
    fs.writeFileSync(path.join(registry, 'tooling.yaml'), `tools:\n  sample:\n    status: ${status}\n    implementation: harness/tooling/sample.mjs\n`);
    if (source !== null) {
      fs.mkdirSync(path.join(dir, 'harness', 'tooling'));
      fs.writeFileSync(path.join(dir, 'harness', 'tooling', 'sample.mjs'), source);
    }
    assertErrors(checkRegistry(dir).errors);
  } finally {
    fs.rmSync(dir, { recursive: true, force: true });
  }
}

test('A: intact baseline passes Doctor', () => assert.deepEqual(runDoctor(root).errors, []));
test('B: missing registered entrypoint fails', () => fixture(null, 'active', errors => assert.ok(errors.some(e => e.includes('sample')))));
test('C: inactive profiles explicitly skip', () => {
  for (const script of ['harness/tooling/validators/validate-api-contract-coverage.mjs', 'harness/tooling/validators/validate-google-runtime-governance.mjs']) {
    const result = run(script);
    assert.equal(result.status, 0);
    assert.match(result.stdout, /SKIP/);
  }
});
test('D: H2 cannot fall through to H1', () => {
  const result = run('harness/tooling/eval-runner/index.mjs', ['--level', 'H2']);
  assert.equal(result.status, 2);
  assert.match(result.stderr, /NOT_IMPLEMENTED/);
  assert.doesNotMatch(result.stdout, /H1 executados/);
});
test('E: broken active tool fails Doctor registry check', () => fixture('export const x = ;\n', 'active', errors => assert.ok(errors.some(e => e.includes('sintaxe')))));
test('F: broken experimental tool is not presented as active', () => fixture(null, 'experimental', errors => assert.deepEqual(errors, [])));
