#!/usr/bin/env node

import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const FILES = {
  adr: 'docs/adrs/ADR-0000-governanca-do-harness-documental.md',
  quality: 'docs/agents/standards/software-quality-standard.md',
  development: 'docs/agents/standards/development-standard.md',
  lifecycle: 'docs/agents/standards/software-engineering-lifecycle.md',
  settings: 'docs/settings/settings.md',
  agents: 'AGENTS.md',
  claude: 'CLAUDE.md',
  gemini: 'GEMINI.md',
  antigravityRule: '.agents/rules/documentation-governance.md',
  googleSettings: 'docs/settings/google-gemini.md',
  googleValidator: 'docs/scripts/validate-google-runtime-governance.mjs',
  googleValidatorTest: 'docs/scripts/validate-google-runtime-governance.test.mjs',
  taskTemplate: 'docs/templates/TPL-00005-task-plan.md',
  planTemplate: 'docs/templates/TPL-00006-implementation-plan.md',
  codexSkill: '.agents/skills/quality-gate/SKILL.md',
  claudeSkill: '.claude/skills/quality-gate/SKILL.md',
  codexGovernance: '.agents/skills/governanca-documental/SKILL.md',
  claudeGovernance: '.claude/skills/governanca-documental/SKILL.md',
  metrics: 'docs/scripts/validate-quality-metrics.mjs',
  metricsTest: 'docs/scripts/validate-quality-metrics.test.mjs',
  metricsWrapper: 'infra/scripts/validate-quality-metrics.mjs',
  planGranularity: 'docs/scripts/validate-plan-granularity.mjs',
  planGranularityTest: 'docs/scripts/validate-plan-granularity.test.mjs',
  planGranularityWrapper: 'infra/scripts/validate-plan-granularity.mjs',
  gate: 'infra/scripts/validate-quality-gates.sh',
  gateTest: 'infra/scripts/tests/validate-quality-gates-test.sh',
  docsGate: 'infra/scripts/validate-docs.sh',
};

const BRANCH_CONTRACT = 'X.Y.Z-{docs,feat,fix}-short-description';

function requireMarkers(errors, label, content, markers) {
  for (const marker of markers) {
    if (!content.includes(marker)) errors.push(`${label}: required marker missing: ${marker}`);
  }
}

export function validateQualityPolicy(artifacts) {
  const errors = [];
  requireMarkers(errors, 'ADR-0000', artifacts.adr, [
    'Version: 4.20', 'docs/scripts/validate-quality-metrics.mjs',
    'docs/scripts/validate-plan-granularity.mjs',
    BRANCH_CONTRACT, '--delivery', 'git push --set-upstream origin <branch-exata>',
    'git add -- <paths-autorizados>', 'git commit -m <mensagem-convencional>',
    'gh pr create', 'Force-push', '500 linhas', '64 KiB', 'comentários',
  ]);
  requireMarkers(errors, 'Software Quality Standard', artifacts.quality, [
    'version: 1.3', '80% de instruções', '70% de branches', '70% de lines',
    '500 linhas', '100 caracteres', '12 linhas', 'três iterações',
    '64 KiB', 'Granularity / Decomposition Review', 'PLAN_GRANULARITY_JSON',
    'QUALITY_METRICS_JSON', '--delivery', '`git add`', '`git commit`',
  ]);
  requireMarkers(errors, 'Development Standard', artifacts.development, [
    'version: "1.11"', BRANCH_CONTRACT, 'Conventional Commits 1.0.0',
    '<coordenada-da-branch>', 'git branch --show-current', '^[0-9]+\\.[0-9]+\\.[0-9]+$',
    'git push --set-upstream origin <branch-exata>', '500 linhas físicas',
  ]);
  requireMarkers(errors, 'Lifecycle', artifacts.lifecycle, [
    'version: "1.11"', '--target <path>', '--delivery --branch-name',
    'três iterações',
  ]);
  for (const [label, content] of [
    ['settings', artifacts.settings], ['AGENTS.md', artifacts.agents],
    ['CLAUDE.md', artifacts.claude],
  ]) {
    requireMarkers(errors, label, content, [
      BRANCH_CONTRACT, '--delivery', 'force-push', 'git add', 'git commit',
      'git push --set-upstream origin <branch-exata>',
    ]);
  }
  requireMarkers(errors, 'GEMINI.md', artifacts.gemini, ['@./AGENTS.md']);
  requireMarkers(errors, 'Antigravity workspace rule', artifacts.antigravityRule, [
    '@../../AGENTS.md', 'AGENTS.md', 'ADR-0000',
  ]);
  requireMarkers(errors, 'Google runtime settings', artifacts.googleSettings, [
    'GEMINI.md', '.agents/rules/documentation-governance.md', '.agents/skills/',
    'Always On', 'Proceed in Sandbox', 'Deny > Ask > Allow',
    'runtime não verificado',
  ]);
  requireMarkers(errors, 'Google runtime validator', artifacts.googleValidator, [
    'export function validateGoogleRuntimeGovernance',
    'export function validateRepository', '12000', '.gemini/skills',
    'Google runtime governance validation passed.'
  ]);
  requireMarkers(errors, 'Google runtime validator test', artifacts.googleValidatorTest, [
    'accepts the complete Google runtime governance contract',
    'rejects divergent adapters, unsafe mapping and duplicated skills'
  ]);
  for (const [label, content] of [
    ['TPL-00005', artifacts.taskTemplate], ['TPL-00006', artifacts.planTemplate],
  ]) {
    requireMarkers(errors, label, content, [
      '--target', 'Quality Correction Loop and Delivery', BRANCH_CONTRACT,
      '--delivery', 'Granularity / Decomposition Review', '64 KiB',
    ]);
  }
  if (artifacts.codexSkill !== artifacts.claudeSkill) {
    errors.push('quality-gate skills: Codex and Claude variants differ');
  }
  requireMarkers(errors, 'quality-gate skill', artifacts.codexSkill, [
    '--target <path>', '--delivery --branch-name', 'TP/IP', 'IRG', 'três',
    'git add', 'git commit', 'git push', 'force-push',
  ]);
  if (artifacts.codexGovernance !== artifacts.claudeGovernance) {
    errors.push('governanca-documental skills: Codex and Claude variants differ');
  }
  requireMarkers(errors, 'governanca-documental skill', artifacts.codexGovernance, [
    'validate-docs.sh', 'gates', 'PASS', 'branch documental governada',
    'force-push',
  ]);
  requireMarkers(errors, 'quality metrics', artifacts.metrics, [
    'instructions: 80', 'branches: 70', 'lines: 70', 'maxLines ?? 500',
    'maxCommentLength ?? 100', 'maxCommentBlock ?? 12',
    'QUALITY_METRICS_JSON=', 'export function parseJacoco',
    'export function parseLcov', 'export function analyzeSource',
  ]);
  requireMarkers(errors, 'quality metrics test', artifacts.metricsTest, [
    'parses JaCoCo', 'aggregates LCOV', 'file size and comment hygiene',
    'governed delivery branch', 'coverage evidence or target is absent',
  ]);
  requireMarkers(errors, 'quality metrics wrapper', artifacts.metricsWrapper, [
    "import { main } from '../../docs/scripts/validate-quality-metrics.mjs'",
    'process.exitCode = main()',
  ]);
  requireMarkers(errors, 'plan granularity', artifacts.planGranularity, [
    'MAX_LINES = 500', 'MAX_BYTES = 64 * 1024',
    'Granularity / Decomposition Review', 'Semantically indivisible',
    'PLAN_GRANULARITY_JSON=', 'export function analyzePlan',
  ]);
  requireMarkers(errors, 'plan granularity test', artifacts.planGranularityTest, [
    'below both review thresholds', 'without a structured review',
    'semantically indivisible', 'at least two child IDs', 'UTF-8 bytes',
  ]);
  requireMarkers(errors, 'plan granularity wrapper', artifacts.planGranularityWrapper, [
    "import { main } from '../../docs/scripts/validate-plan-granularity.mjs'",
    'process.exitCode = main()',
  ]);
  requireMarkers(errors, 'quality gate', artifacts.gate, [
    '--target', '--delivery', '--branch-name', 'run_metrics',
    'run_plan_granularity', 'validate-quality-metrics.mjs',
    'validate-plan-granularity.mjs', 'at least one --target is required',
  ]);
  if (/(?:^|[;&|()]|\s)git\s+(?:diff|status|show|log|ls-files)\b/m.test(artifacts.gate)) {
    errors.push('quality gate: Git discovery is forbidden');
  }
  requireMarkers(errors, 'quality gate test', artifacts.gateTest, [
    'PR metrics require targets', 'invalid delivery branch fails',
    'valid docs delivery passes', 'docs PR omitted plan granularity command',
    '10 scenarios',
  ]);
  requireMarkers(errors, 'documentation gate', artifacts.docsGate, [
    'validate-quality-metrics.test.mjs', 'validate-plan-granularity.test.mjs',
    'validate-quality-policy.test.mjs', 'validate-quality-policy.mjs',
    'validate-google-runtime-governance.test.mjs',
    'validate-google-runtime-governance.mjs',
  ]);
  return errors;
}

export function validateRepository(root) {
  const artifacts = {};
  const errors = [];
  for (const [name, relative] of Object.entries(FILES)) {
    const absolute = path.join(root, relative);
    if (!fs.statSync(absolute, { throwIfNoEntry: false })?.isFile()) {
      errors.push(`${relative}: required quality artifact missing`);
    } else {
      artifacts[name] = fs.readFileSync(absolute, 'utf8');
    }
  }
  if (errors.length === 0) errors.push(...validateQualityPolicy(artifacts));
  return errors;
}

export function main(argv = process.argv.slice(2)) {
  const rootIndex = argv.indexOf('--root');
  const root = rootIndex >= 0 ? argv[rootIndex + 1] : process.cwd();
  if (!root || (argv.length > 0 && rootIndex < 0)) {
    console.error('Usage: validate-quality-policy.mjs [--root <repository>]');
    return 2;
  }
  const errors = validateRepository(path.resolve(root));
  if (errors.length > 0) {
    for (const error of errors) console.error(`ERROR: ${error}`);
    console.error(`Quality policy validation failed with ${errors.length} error(s).`);
    return 1;
  }
  console.log('Quality policy validation passed.');
  return 0;
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  process.exitCode = main();
}
