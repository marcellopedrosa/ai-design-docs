import assert from 'node:assert/strict';
import { mkdtemp, mkdir, writeFile } from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import test from 'node:test';

import { analyzeSource, evaluate, main, parseJacoco, parseLcov } from './validate-quality-metrics.mjs';

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
    delivery: false,
    branchName: null,
  });
  assert.equal(result.status, 'BLOCKED');
  assert.equal(result.blocked.length, 2);
});

test('main returns PASS and rejects missing targets', async () => {
  const root = await fixture();
  assert.equal(main(['--root', root, '--scope', 'infra', '--target', 'infra/scripts/example.sh']), 0);
  assert.equal(main(['--root', root, '--scope', 'infra']), 2);
});
