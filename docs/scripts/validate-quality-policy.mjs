#!/usr/bin/env node

import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const FILES = {
  adr: 'docs/adrs/ADR-0000-governanca-do-harness-documental.md',
  quality: 'docs/agents/standards/software-quality-standard.md',
  settings: 'docs/settings/settings.md',
  gitDelivery: 'docs/settings/git-delivery.md',
  agents: 'AGENTS.md',
  claude: 'CLAUDE.md',
  codexSkill: '.agents/skills/quality-gate/SKILL.md',
  claudeSkill: '.claude/skills/quality-gate/SKILL.md',
  codexGovernance: '.agents/skills/governanca-documental/SKILL.md',
  claudeGovernance: '.claude/skills/governanca-documental/SKILL.md',
  scriptsReadme: 'docs/scripts/README.md',
  metrics: 'docs/scripts/validate-quality-metrics.mjs',
  metricsTest: 'docs/scripts/validate-quality-metrics.test.mjs',
  planGranularity: 'docs/scripts/validate-plan-granularity.mjs',
  planGranularityTest: 'docs/scripts/validate-plan-granularity.test.mjs',
};

export function validateQualityPolicy(artifacts) {
  const errors = [];
  const has = (source, expression) => expression.test(source ?? '');
  if (!has(artifacts.adr, /ADR-0000/) || !has(artifacts.adr, /software-quality-standard\.md/)) {
    errors.push('ADR-0000: quality policy must identify its decision and governing standard');
  }
  for (const [label, content] of [
    ['settings', artifacts.settings], ['AGENTS.md', artifacts.agents], ['CLAUDE.md', artifacts.claude]
  ]) {
    if (!has(content, /git-delivery\.md/) || !has(content, /main/i)) {
      errors.push(`${label}: must point to local Git delivery policy and main-branch protection`);
    }
  }
  if (!has(artifacts.gitDelivery, /main/i) || !has(artifacts.gitDelivery, /force-push/i)) {
    errors.push('git-delivery policy: main-branch protection is not explicit');
  }
  if (!has(artifacts.quality, /A1[\s—-]*Test/) || !has(artifacts.quality, /A2[\s—-]*Quality/) ||
      !has(artifacts.quality, /A3[\s—-]*Security/i) || !has(artifacts.quality, /READY/)) {
    errors.push('Software Quality Standard: independent assurance gates or READY precondition are missing');
  }
  if (artifacts.codexSkill !== artifacts.claudeSkill) {
    errors.push('quality-gate skills: Codex and Claude variants differ');
  }
  if (artifacts.codexGovernance !== artifacts.claudeGovernance) {
    errors.push('governanca-documental skills: Codex and Claude variants differ');
  }
  if (!has(artifacts.codexSkill, /software-quality-standard\.md/) ||
      !has(artifacts.codexGovernance, /validate-documentation-governance\.mjs/)) {
    errors.push('skills: quality and documentation procedures must link to available standards and validator');
  }
  if (/(?:^|[;&|()]|\s)git\s+(?:diff|status|show|log|ls-files)\b/m.test(artifacts.metrics) ||
      /(?:^|[;&|()]|\s)git\s+(?:diff|status|show|log|ls-files)\b/m.test(artifacts.planGranularity)) {
    errors.push('quality scripts: Git discovery is forbidden');
  }
  if (!has(artifacts.scriptsReadme, /node --test/) || !has(artifacts.scriptsReadme, /Automação não configurada/)) {
    errors.push('docs/scripts/README.md: available test command and unconfigured automation state must be explicit');
  }
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
