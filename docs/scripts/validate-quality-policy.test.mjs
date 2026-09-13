import assert from 'node:assert/strict';
import test from 'node:test';

import { validateQualityPolicy } from './validate-quality-policy.mjs';

const branch = 'X.Y.Z-{docs,feat,fix}-short-description';

function validArtifacts() {
  const delivery = `${branch}\n--delivery\nforce-push\ngit add\ngit commit\ngit push --set-upstream origin <branch-exata>`;
  return {
    adr: `Version: 4.20\ndocs/scripts/validate-quality-metrics.mjs\ndocs/scripts/validate-plan-granularity.mjs\n${delivery}\ngit add -- <paths-autorizados>\ngit commit -m <mensagem-convencional>\ngh pr create\nForce-push\n500 linhas\n64 KiB\ncomentários`,
    quality: 'version: 1.3\n80% de instruções\n70% de branches\n70% de lines\n500 linhas\n64 KiB\nGranularity / Decomposition Review\n100 caracteres\n12 linhas\ntrês iterações\nQUALITY_METRICS_JSON\nPLAN_GRANULARITY_JSON\n--delivery\n`git add`\n`git commit`',
    development: `version: "1.11"\n${branch}\nConventional Commits 1.0.0\n<coordenada-da-branch>\ngit branch --show-current\n^[0-9]+\\.[0-9]+\\.[0-9]+$\ngit push --set-upstream origin <branch-exata>\n500 linhas físicas`,
    lifecycle: 'version: "1.11"\n--target <path>\n--delivery --branch-name\ntrês iterações',
    settings: delivery,
    agents: delivery,
    claude: delivery,
    gemini: '@./AGENTS.md',
    antigravityRule: '@../../AGENTS.md\nAGENTS.md mais próximo\nADR-0000',
    googleSettings: 'GEMINI.md\n.agents/rules/documentation-governance.md\n.agents/skills/\nAlways On\nProceed in Sandbox\nDeny > Ask > Allow\nruntime não verificado',
    googleValidator: 'export function validateGoogleRuntimeGovernance\nexport function validateRepository\n12000\n.gemini/skills\nGoogle runtime governance validation passed.',
    googleValidatorTest: 'accepts the complete Google runtime governance contract\nrejects divergent adapters, unsafe mapping and duplicated skills',
    taskTemplate: `--target\nQuality Correction Loop and Delivery\nGranularity / Decomposition Review\n64 KiB\n${branch}\n--delivery`,
    planTemplate: `--target\nQuality Correction Loop and Delivery\nGranularity / Decomposition Review\n64 KiB\n${branch}\n--delivery`,
    rawPlan: `--target\nQuality Correction Loop and Delivery\nGranularity / Decomposition Review\n64 KiB\n${branch}\n--delivery`,
    codexSkill: '--target <path>\n--delivery --branch-name\nTP/IP\nIRG\ntrês\ngit add\ngit commit\ngit push\nforce-push',
    claudeSkill: '--target <path>\n--delivery --branch-name\nTP/IP\nIRG\ntrês\ngit add\ngit commit\ngit push\nforce-push',
    codexGovernance: 'validate-docs.sh\ngates\nPASS\nbranch documental governada\nforce-push',
    claudeGovernance: 'validate-docs.sh\ngates\nPASS\nbranch documental governada\nforce-push',
    metrics: 'instructions: 80\nbranches: 70\nlines: 70\nmaxLines ?? 500\nmaxCommentLength ?? 100\nmaxCommentBlock ?? 12\nQUALITY_METRICS_JSON=\nexport function parseJacoco\nexport function parseLcov\nexport function analyzeSource',
    metricsTest: 'parses JaCoCo\naggregates LCOV\nfile size and comment hygiene\ngoverned delivery branch\ncoverage evidence or target is absent',
    metricsWrapper: "import { main } from '../../docs/scripts/validate-quality-metrics.mjs'\nprocess.exitCode = main()",
    planGranularity: 'MAX_LINES = 500\nMAX_BYTES = 64 * 1024\nGranularity / Decomposition Review\nSemantically indivisible\nPLAN_GRANULARITY_JSON=\nexport function analyzePlan',
    planGranularityTest: 'below both review thresholds\nwithout a structured review\nsemantically indivisible\nat least two child IDs\nUTF-8 bytes',
    planGranularityWrapper: "import { main } from '../../docs/scripts/validate-plan-granularity.mjs'\nprocess.exitCode = main()",
    gate: '--target\n--delivery\n--branch-name\nrun_metrics\nrun_plan_granularity\nvalidate-quality-metrics.mjs\nvalidate-plan-granularity.mjs\nat least one --target is required',
    gateTest: 'PR metrics require targets\ninvalid delivery branch fails\nvalid docs delivery passes\ndocs PR omitted plan granularity command\n10 scenarios',
    docsGate: 'validate-quality-metrics.test.mjs\nvalidate-plan-granularity.test.mjs\nvalidate-quality-policy.test.mjs\nvalidate-quality-policy.mjs\nvalidate-google-runtime-governance.test.mjs\nvalidate-google-runtime-governance.mjs',
  };
}

test('accepts the complete governed quality policy', () => {
  assert.deepEqual(validateQualityPolicy(validArtifacts()), []);
});

test('rejects missing delivery certification and diverging skills', () => {
  const artifacts = validArtifacts();
  artifacts.settings = artifacts.settings.replace('--delivery', '');
  artifacts.claudeSkill += '\ndivergent';
  const errors = validateQualityPolicy(artifacts).join('\n');
  assert.match(errors, /settings: required marker missing: --delivery/);
  assert.match(errors, /variants differ/);
});

test('rejects Git discovery in the quality gate', () => {
  const artifacts = validArtifacts();
  artifacts.gate += '\ngit diff';
  assert.match(validateQualityPolicy(artifacts).join('\n'), /Git discovery is forbidden/);
});

test('rejects an incomplete Google runtime policy', () => {
  const artifacts = validArtifacts();
  artifacts.googleSettings = artifacts.googleSettings.replace('Proceed in Sandbox', 'Always Proceed');
  assert.match(
    validateQualityPolicy(artifacts).join('\n'),
    /Google runtime settings: required marker missing: Proceed in Sandbox/
  );
});
