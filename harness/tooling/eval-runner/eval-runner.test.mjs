import test from 'node:test';
import assert from 'node:assert/strict';
import path from 'node:path';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { runEvalsH1, evaluateCaseH1 } from './index.mjs';

function runCli(level) {
  return spawnSync(process.execPath, [fileURLToPath(new URL('./index.mjs', import.meta.url)), '--level', level], {
    cwd: path.resolve('.'),
    encoding: 'utf8'
  });
}

test('CLI H1 executes deterministic evals', () => {
  const result = runCli('H1');
  assert.equal(result.status, 0, result.stderr);
  assert.match(result.stdout, /H1 executados: 24/);
});

test('CLI H2 fails explicitly instead of passing H1', () => {
  const result = runCli('H2');
  assert.equal(result.status, 2);
  assert.match(result.stderr, /H2 not implemented/);
  assert.doesNotMatch(result.stdout, /PASS|H1 executados/);
});

test('CLI rejects unknown levels before running H1', () => {
  const result = runCli('H9');
  assert.equal(result.status, 2);
  assert.match(result.stderr, /NOT_IMPLEMENTED/);
  assert.doesNotMatch(result.stdout, /PASS|H1 executados/);
});

test('runEvalsH1 passes on repository root with zero failures', () => {
  const root = path.resolve('.');
  const results = runEvalsH1(root);
  assert.equal(results.h1Failed, 0, `Expected 0 H1 failures, got: ${JSON.stringify(results.failures)}`);
  assert.ok(results.h1Executed >= 20, `Expected at least 20 H1 cases executed, got ${results.h1Executed}`);
  assert.ok(results.h1Passed === results.h1Executed, 'All executed H1 cases must pass');
});

test('key fixtures from WP-03 pass deterministically in H1', () => {
  const root = path.resolve('.');

  // 1. SQL Injection confirmada
  const sqlInjection = runEvalsH1(root, { case: 'security.detection.sql-injection-confirmed' });
  assert.equal(sqlInjection.h1Executed, 1);
  assert.equal(sqlInjection.h1Passed, 1);

  // 2. JPA Safe Query falso positivo
  const jpaSafe = runEvalsH1(root, { case: 'security.false-positive.jpa-safe-query' });
  assert.equal(jpaSafe.h1Executed, 1);
  assert.equal(jpaSafe.h1Passed, 1);

  // 3. Open Question bloqueante
  const openQ = runEvalsH1(root, { case: 'readiness.blocking.open-question-unresolved' });
  assert.equal(openQ.h1Executed, 1);
  assert.equal(openQ.h1Passed, 1);
});

test('eval runner fails when expected outcome is violated (mutation test)', () => {
  const root = path.resolve('.');
  // Mock case with wrong expected outcome
  const mutatedCase = {
    id: 'test.mutated.sql-injection',
    suite: 'security-gate',
    category: 'behavior',
    input: {
      fixture: 'harness/skills/security-gate/fixtures/sql-injection-confirmed/UserRepository.java'
    },
    expected: {
      status: 'PASS' // Mutated: fixture actually has SQL injection and returns FAIL
    }
  };

  const res = evaluateCaseH1(mutatedCase, 'mock.json', root);
  assert.ok(res.eligible, 'Should be H1 eligible');
  assert.equal(res.pass, false, 'Mutated expectation must FAIL');
  assert.equal(res.actual.status, 'FAIL');
});
