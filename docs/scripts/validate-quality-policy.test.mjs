import assert from 'node:assert/strict';
import test from 'node:test';

import { validateQualityPolicy } from './validate-quality-policy.mjs';

function validArtifacts() {
  const delivery = 'git-delivery.md\nmain';
  return {
    adr: `ADR-0000\nsoftware-quality-standard.md\n${delivery}`,
    quality: 'A1 — Test\nA2 — Quality\nA3 — Security\nREADY',
    gitDelivery: 'Protect main from direct writes and force-push',
    settings: delivery,
    agents: delivery,
    claude: delivery,
    codexSkill: 'software-quality-standard.md',
    claudeSkill: 'software-quality-standard.md',
    codexGovernance: 'node docs/scripts/validate-documentation-governance.mjs',
    claudeGovernance: 'node docs/scripts/validate-documentation-governance.mjs',
    metrics: 'export function analyzeSource',
    metricsTest: 'test coverage',
    planGranularity: 'export function analyzePlan',
    planGranularityTest: 'test coverage',
    scriptsReadme: 'node --test "docs/scripts/*.test.mjs"\nAutomação não configurada',
  };
}

test('accepts the complete governed quality policy', () => {
  assert.deepEqual(validateQualityPolicy(validArtifacts()), []);
});

test('rejects missing local Git policy reference and diverging skills', () => {
  const artifacts = validArtifacts();
  artifacts.settings = artifacts.settings.replace('git-delivery.md', '');
  artifacts.claudeSkill += '\ndivergent';
  const errors = validateQualityPolicy(artifacts).join('\n');
  assert.match(errors, /settings: must point to local Git delivery policy/);
  assert.match(errors, /variants differ/);
});

test('rejects Git discovery in quality scripts', () => {
  const artifacts = validArtifacts();
  artifacts.metrics += '\ngit diff';
  assert.match(validateQualityPolicy(artifacts).join('\n'), /Git discovery is forbidden/);
});

test('rejects an undocumented test entrypoint', () => {
  const artifacts = validArtifacts();
  artifacts.scriptsReadme = artifacts.scriptsReadme.replace('node --test', '');
  assert.match(
    validateQualityPolicy(artifacts).join('\n'),
    /available test command and unconfigured automation state/
  );
});
