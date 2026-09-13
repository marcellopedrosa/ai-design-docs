import assert from 'node:assert/strict';
import { mkdtemp, mkdir, writeFile } from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import test from 'node:test';

import { analyzePlan, evaluate, main } from './validate-plan-granularity.mjs';

async function fixture() {
  const root = await mkdtemp(path.join(os.tmpdir(), 'plan-granularity-test-'));
  await mkdir(path.join(root, 'docs/task_plans/implementation_plans/backend'), { recursive: true });
  await writeFile(path.join(root, 'docs/task_plans/TP-00001-small.md'), '# Small\n');
  await writeFile(path.join(root, 'docs/README.md'), '# Docs\n');
  return root;
}

function oversized(review = '') {
  return `${'# Plan\n'.repeat(501)}${review}`;
}

test('passes a plan below both review thresholds', () => {
  const result = analyzePlan('docs/task_plans/TP-00001-small.md', '# Small\n');
  assert.equal(result.reviewRequired, false);
  assert.deepEqual(result.violations, []);
});

test('fails an oversized plan without a structured review', () => {
  const result = analyzePlan('docs/task_plans/TP-00002-large.md', oversized());
  assert.equal(result.reviewRequired, true);
  assert.ok(result.violations.some(({ rule }) => rule === 'plan-granularity-review'));
});

test('accepts a semantically indivisible oversized plan with evidence', () => {
  const review = `\n## Granularity / Decomposition Review
- **Outcome:** Semantically indivisible
- **Rationale:** One coordinated normative decision must be transported and reviewed as a unit.
- **Children:** N/A — splitting would duplicate the same normative authority.
- **Reviewed on:** 2026-09-10
`;
  const result = analyzePlan('docs/task_plans/TP-00003-indivisible.md', oversized(review));
  assert.deepEqual(result.violations, []);
  assert.equal(result.review.outcome, 'Semantically indivisible');
});

test('requires at least two child IDs for a decomposed oversized plan', () => {
  const review = `\n## Granularity / Decomposition Review
- **Outcome:** Decomposed
- **Rationale:** Independent delivery outcomes have distinct acceptance and handoff cycles.
- **Children:** TP-00004-A
- **Reviewed on:** 2026-09-10
`;
  const result = analyzePlan('docs/task_plans/TP-00004-parent.md', oversized(review));
  assert.ok(result.violations.some(({ rule }) => rule === 'plan-granularity-children'));
});

test('passes decomposition evidence with two child IDs', () => {
  const review = `\n## Granularity / Decomposition Review
- **Outcome:** Decomposed
- **Rationale:** Independent delivery outcomes have distinct acceptance and handoff cycles.
- **Children:** IP-BE-4.1.1-one, IP-BE-4.1.2-two
- **Reviewed on:** 2026-09-10
`;
  const result = analyzePlan('docs/task_plans/implementation_plans/backend/IP-BE-4.1.0-parent.md', oversized(review));
  assert.deepEqual(result.violations, []);
});

test('measures UTF-8 bytes independently of line count', () => {
  const review = `\n## Granularity / Decomposition Review
- **Outcome:** Semantically indivisible
- **Rationale:** The single generated compatibility matrix has one acceptance decision.
- **Children:** N/A — one indivisible compatibility matrix.
- **Reviewed on:** 2026-09-10
`;
  const result = analyzePlan('docs/task_plans/TP-00005-bytes.md', `${'á'.repeat(33_000)}${review}`);
  assert.equal(result.reviewRequired, true);
  assert.deepEqual(result.violations, []);
});

test('evaluates plan targets, skips other docs and blocks missing files', async () => {
  const root = await fixture();
  const pass = evaluate({ root, targets: ['docs/task_plans/TP-00001-small.md', 'docs/README.md'] });
  assert.equal(pass.status, 'PASS');
  assert.deepEqual(pass.skipped, ['docs/README.md']);
  const blocked = evaluate({ root, targets: ['docs/task_plans/TP-99999-missing.md'] });
  assert.equal(blocked.status, 'BLOCKED');
});

test('main rejects execution without explicit targets', async () => {
  const root = await fixture();
  assert.equal(main(['--root', root]), 2);
});
