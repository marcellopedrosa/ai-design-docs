import assert from 'node:assert/strict';
import { mkdtemp, mkdir, writeFile } from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import test from 'node:test';

import { analyzeSource, evaluate, main, parseJacoco, parseLcov } from './validate-quality-metrics.mjs';

const frontendPolicy = {
  coverage: { format: 'lcov', reports: ['frontend/coverage/lcov.info'], thresholds: { lines: 70, branches: 70, functions: 70 } },
  delivery: { protectedBranches: ['main'], branchPattern: '^[0-9]+\\.[0-9]+\\.[0-9]+-(docs|feat|fix)-[a-z0-9-]+$' },
};
const backendPolicy = {
  coverage: { format: 'jacoco', reports: ['backend/target/site/jacoco/jacoco.xml'], thresholds: { instructions: 80, branches: 70 } },
};

async function fixture() {
  const root = await mkdtemp(path.join(os.tmpdir(), 'quality-metrics-test-'));
  await mkdir(path.join(root, 'backend/target/site/jacoco'), { recursive: true });
  await mkdir(path.join(root, 'backend/src/main/java'), { recursive: true });
  await mkdir(path.join(root, 'frontend/coverage'), { recursive: true });
  await mkdir(path.join(root, 'frontend/src'), { recursive: true });
  await mkdir(path.join(root, 'infra/scripts'), { recursive: true });
  await writeFile(path.join(root, 'frontend/src/example.ts'), 'export const answer = 42;\n// INT-123 explains the boundary.\n');
  await writeFile(path.join(root, 'backend/src/main/java/Example.java'), 'final class Example {}\n');
  await writeFile(path.join(root, 'infra/scripts/example.sh'), '#!/usr/bin/env bash\nprintf "ok\\n"\n');
  return root;
}

test('parses JaCoCo report-level counters', () => {
  const metrics = parseJacoco(`
    <report>
      <package><counter type="INSTRUCTION" missed="99" covered="1"/></package>
      <counter type="INSTRUCTION" missed="20" covered="80"/>
      <counter type="BRANCH" missed="3" covered="7"/>
    </report>`);
  assert.equal(metrics.instructions, 80);
  assert.equal(metrics.branches, 70);
});

test('parses and aggregates LCOV records', () => {
  const metrics = parseLcov('LF:10\nLH:8\nBRF:4\nBRH:3\nFNF:2\nFNH:2\nend_of_record\n');
  assert.deepEqual(metrics, { lines: 80, branches: 75, functions: 100 });
});

test('reports file size and comment hygiene violations without requiring density', () => {
  const source = `${'const value = 1;\n'.repeat(501)}// TODO improve\n// const disabled = true;\n`;
  const result = analyzeSource('frontend/src/large.ts', source);
  assert.ok(result.violations.some(({ rule }) => rule === 'file-lines'));
  assert.ok(result.violations.some(({ rule }) => rule === 'untracked-comment'));
  assert.ok(result.violations.some(({ rule }) => rule === 'commented-code'));
});

test('recognizes Python comments without treating strings as comments', () => {
  const source = 'endpoint = "https://example.invalid"\n# TODO add retry\n';
  const result = analyzeSource('infra/scripts/example.py', source);
  assert.equal(result.commentLines, 1);
  assert.ok(result.violations.some(({ rule }) => rule === 'untracked-comment'));
});

test('passes a valid frontend profile and governed delivery branch', async () => {
  const root = await fixture();
  await writeFile(path.join(root, 'frontend/coverage/lcov.info'), 'LF:10\nLH:8\nBRF:10\nBRH:8\nFNF:10\nFNH:8\nend_of_record\n');
  const result = evaluate({
    root,
    scope: 'frontend',
    targets: ['frontend/src/example.ts'],
    coverage: null,
    policy: frontendPolicy,
    delivery: true,
    branchName: '45.1.2-feat-quality-metrics',
  });
  assert.equal(result.status, 'PASS');
});

test('evaluates backend thresholds from JaCoCo XML', async () => {
  const root = await fixture();
  await writeFile(path.join(root, 'backend/target/site/jacoco/jacoco.xml'), '<report><counter type="INSTRUCTION" missed="20" covered="80"/><counter type="BRANCH" missed="3" covered="7"/></report>');
  const result = evaluate({
    root,
    scope: 'backend',
    targets: ['backend/src/main/java/Example.java'],
    coverage: null,
    policy: backendPolicy,
    delivery: false,
    branchName: null,
  });
  assert.equal(result.status, 'PASS');
});

test('fails low coverage and an invalid branch', async () => {
  const root = await fixture();
  await writeFile(path.join(root, 'frontend/coverage/lcov.info'), 'LF:10\nLH:6\nBRF:10\nBRH:6\nFNF:10\nFNH:6\nend_of_record\n');
  const result = evaluate({
    root,
    scope: 'frontend',
    targets: ['frontend/src/example.ts'],
    coverage: null,
    policy: frontendPolicy,
    delivery: true,
    branchName: 'feature/quality',
  });
  assert.equal(result.status, 'FAIL');
  assert.ok(result.violations.some(({ rule }) => rule === 'coverage-lines'));
  assert.ok(result.violations.some(({ rule }) => rule === 'branch-name'));
});

test('blocks when coverage evidence or target is absent', async () => {
  const root = await fixture();
  const result = evaluate({
    root,
    scope: 'frontend',
    targets: ['frontend/src/missing.ts'],
    coverage: null,
    policy: frontendPolicy,
    delivery: false,
    branchName: null,
  });
  assert.equal(result.status, 'BLOCKED');
  assert.equal(result.blocked.length, 2);
});

test('does not require coverage when no policy is activated', async () => {
  const root = await fixture();
  const result = evaluate({ root, scope: 'backend', targets: ['backend/src/main/java/Example.java'], delivery: false });
  assert.equal(result.status, 'PASS');
  assert.equal(result.coverage, null);
});

test('changing configured thresholds changes result without code changes', async () => {
  const root = await fixture();
  await writeFile(path.join(root, 'frontend/coverage/lcov.info'), 'LF:10\nLH:8\nBRF:10\nBRH:8\nFNF:10\nFNH:8\nend_of_record\n');
  const options = { root, scope: 'frontend', targets: ['frontend/src/example.ts'], policy: frontendPolicy, delivery: false };
  assert.equal(evaluate(options).status, 'PASS');
  const strict = { ...frontendPolicy, coverage: { ...frontendPolicy.coverage, thresholds: { ...frontendPolicy.coverage.thresholds, lines: 90 } } };
  assert.equal(evaluate({ ...options, policy: strict }).status, 'FAIL');
});

test('reads coverage thresholds from a policy file inside the project', async () => {
  const root = await fixture();
  await writeFile(path.join(root, 'frontend/coverage/lcov.info'), 'LF:10\nLH:8\nBRF:10\nBRH:8\nFNF:10\nFNH:8\nend_of_record\n');
  const policyPath = path.join(root, 'quality.json');
  const options = { root, scope: 'frontend', targets: ['frontend/src/example.ts'], policy: 'quality.json', delivery: false };
  await writeFile(policyPath, JSON.stringify(frontendPolicy));
  assert.equal(evaluate(options).status, 'PASS');
  await writeFile(policyPath, JSON.stringify({ ...frontendPolicy, coverage: { ...frontendPolicy.coverage, thresholds: { lines: 90 } } }));
  assert.equal(evaluate(options).status, 'FAIL');
});

test('delivery branch pattern is optional but protected branch is always rejected', async () => {
  const root = await fixture();
  const options = { root, scope: 'infra', targets: ['infra/scripts/example.sh'], delivery: true };
  assert.equal(evaluate({ ...options, branchName: 'feature/quality' }).status, 'BLOCKED');
  const deliveryPolicy = { delivery: { protectedBranches: ['main'] } };
  assert.equal(evaluate({ ...options, branchName: 'feature/quality', policy: deliveryPolicy }).status, 'PASS');
  assert.equal(evaluate({ ...options, branchName: 'main', policy: deliveryPolicy }).status, 'FAIL');
  assert.equal(evaluate({ ...options, branchName: 'feature/quality', policy: { delivery: frontendPolicy.delivery } }).status, 'FAIL');
});

test('main returns PASS and rejects missing targets', async () => {
  const root = await fixture();
  assert.equal(main(['--root', root, '--scope', 'infra', '--target', 'infra/scripts/example.sh']), 0);
  assert.equal(main(['--root', root, '--scope', 'infra']), 2);
});
