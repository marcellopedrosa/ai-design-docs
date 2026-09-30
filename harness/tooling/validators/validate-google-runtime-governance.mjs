#!/usr/bin/env node

import fs from 'node:fs';
import path from 'node:path';
import process from 'node:process';
import { fileURLToPath } from 'node:url';

const SKILLS = ['governanca-documental', 'implementation-readiness', 'quality-gate'];

function normalize(value) {
  return value.normalize('NFD').replace(/[\u0300-\u036f]/g, '').toLowerCase().replace(/\s+/g, ' ');
}

function requireMarkers(errors, label, content, markers) {
  const normalized = normalize(content);
  for (const marker of markers) {
    if (!normalized.includes(normalize(marker))) {
      errors.push(`${label}: required marker missing: ${marker}`);
    }
  }
}

export function validateGoogleRuntimeGovernance(artifacts) {
  const errors = [];
  requireMarkers(errors, 'GEMINI.md', artifacts.rootGemini, ['@./AGENTS.md']);
  if (artifacts.rootGemini.split(/\r?\n/).length > 20) {
    errors.push('GEMINI.md: root adapter exceeds 20 lines');
  }

  requireMarkers(errors, 'Antigravity workspace rule', artifacts.antigravityRule, [
    '@../../AGENTS.md', 'AGENTS.md', 'mais próximo', 'ADR aceito'
  ]);
  if ([...artifacts.antigravityRule].length > 12000) {
    errors.push('Antigravity workspace rule: exceeds 12,000 characters');
  }

  for (const adapter of artifacts.packageAdapters) {
    requireMarkers(
      errors,
      `${adapter.packageName}/GEMINI.md`,
      adapter.content,
      ['@./AGENTS.md']
    );
    if (adapter.content.split(/\r?\n/).length > 20) {
      errors.push(`${adapter.packageName}/GEMINI.md: adapter exceeds 20 lines`);
    }
  }

  requireMarkers(errors, 'Google runtime settings', artifacts.googleSettings, [
    'Gemini CLI', 'Google Antigravity', 'GEMINI.md',
    '.agents/rules/documentation-governance.md', '.agents/skills/',
    'Always On', 'Proceed in Sandbox',
    'Agent Non-Workspace File Access', 'Deny > Ask > Allow',
    '/memory show', '/skills list', 'runtime não verificado',
    'https://antigravity.google/docs/agent-settings/',
    'https://antigravity.google/docs/rules-workflows',
    'https://antigravity.google/docs/skills/',
    'https://antigravity.google/docs/permissions/',
    'https://antigravity.google/docs/sandbox/',
    'https://antigravity.google/docs/projects/',
    'https://geminicli.com/docs/cli/gemini-md/',
    'https://geminicli.com/docs/cli/skills/'
  ]);
  requireMarkers(errors, 'ADR-0000', artifacts.adr, ['ADR-0000', 'Gemini CLI', 'Antigravity']);
  requireMarkers(errors, 'harness/README.md', artifacts.docsMap, [
    'GEMINI.md', '.agents/rules/documentation-governance.md',
    '.gemini/settings.json', 'Not applicable'
  ]);
  requireMarkers(errors, 'harness/governance/README.md', artifacts.aiManual, [
    'GEMINI.md', '.agents/rules/documentation-governance.md',
    'google-gemini.md'
  ]);
  requireMarkers(errors, 'harness/adapters/README.md', artifacts.settingsIndex, [
    'google-gemini.md', 'Google Gemini', 'Antigravity'
  ]);
  requireMarkers(errors, 'harness/governance/policies/ai-environment-policy.md', artifacts.globalSettings, [
    'Gemini CLI', 'Antigravity', 'google-gemini.md'
  ]);
  requireMarkers(errors, 'harness/skills/README.md', artifacts.skillsCatalog, [
    '.agents/skills/', 'Gemini CLI', 'Antigravity', ...SKILLS
  ]);
  for (const packageName of artifacts.activePackages ?? []) {
    requireMarkers(
      errors,
      'docs/architecture/module-registry.md',
      artifacts.moduleRegistry,
      [`../../${packageName}/GEMINI.md`]
    );
  }
  if (artifacts.duplicatedGeminiSkills.length > 0) {
    errors.push(`.gemini/skills: duplicates shared skills: ${artifacts.duplicatedGeminiSkills.join(', ')}`);
  }
  return [...new Set(errors)].sort();
}

export function validateRepository(repositoryRoot, activePackages = []) {
  const root = path.resolve(repositoryRoot);
  if (activePackages.some(name => !/^[A-Za-z0-9_-]+$/.test(name))) {
    return ['invalid active package name'];
  }
  const required = [
    'AGENTS.md', 'GEMINI.md', '.agents/rules/documentation-governance.md',
    'harness/adapters/google-gemini.md', 'harness/adapters/README.md',
    'harness/governance/policies/ai-environment-policy.md', 'harness/README.md', 'harness/governance/README.md',
    'harness/governance/decisions/ADR-0000-governanca-do-harness-documental.md',
    'harness/skills/README.md', 'docs/architecture/module-registry.md',
    ...activePackages.flatMap((packageName) => [
      `${packageName}/AGENTS.md`, `${packageName}/GEMINI.md`
    ]),
    ...SKILLS.map((skill) => `.agents/skills/${skill}/SKILL.md`)
  ];
  const errors = [];
  for (const relative of required) {
    const absolute = path.join(root, relative);
    if (!fs.statSync(absolute, { throwIfNoEntry: false })?.isFile()) {
      errors.push(`${relative}: required Google governance artifact missing`);
    }
  }
  if (errors.length > 0) return errors.sort();

  const read = (relative) => fs.readFileSync(path.join(root, relative), 'utf8');
  const geminiSkillsRoot = path.join(root, '.gemini/skills');
  const duplicatedGeminiSkills = fs.statSync(geminiSkillsRoot, { throwIfNoEntry: false })?.isDirectory()
    ? SKILLS.filter((skill) => fs.existsSync(path.join(geminiSkillsRoot, skill)))
    : [];
  return validateGoogleRuntimeGovernance({
    rootGemini: read('GEMINI.md'),
    antigravityRule: read('.agents/rules/documentation-governance.md'),
    packageAdapters: activePackages.map((packageName) => ({
      packageName,
      content: read(`${packageName}/GEMINI.md`)
    })),
    activePackages,
    googleSettings: read('harness/adapters/google-gemini.md'),
    adr: read('harness/governance/decisions/ADR-0000-governanca-do-harness-documental.md'),
    docsMap: read('harness/README.md'),
    aiManual: read('harness/governance/README.md'),
    settingsIndex: read('harness/adapters/README.md'),
    globalSettings: read('harness/governance/policies/ai-environment-policy.md'),
    skillsCatalog: read('harness/skills/README.md'),
    moduleRegistry: read('docs/architecture/module-registry.md'),
    duplicatedGeminiSkills
  });
}

export function main(argv = process.argv.slice(2)) {
  let root = process.cwd();
  let profile = '';
  const activePackages = [];
  for (let index = 0; index < argv.length; index += 1) {
    const argument = argv[index];
    if (['--root', '--profile', '--package'].includes(argument) && argv[index + 1]) {
      const value = argv[++index];
      if (argument === '--root') root = value;
      else if (argument === '--profile') profile = value;
      else activePackages.push(value);
    } else {
      console.error(`ERROR: unknown or incomplete argument: ${argument}`);
      return 2;
    }
  }
  if (!profile) {
    console.log('GOOGLE_RUNTIME_GOVERNANCE_RESULT=SKIP reason=profile-not-activated');
    return 0;
  }
  if (profile !== 'google-runtime') {
    console.error(`ERROR: unsupported Google runtime profile: ${profile}`);
    return 2;
  }
  const errors = validateRepository(root, activePackages);
  if (errors.length > 0) {
    for (const error of errors) console.error(`ERROR: ${error}`);
    console.error(`Google runtime governance validation failed with ${errors.length} error(s).`);
    return 1;
  }
  console.log('Google runtime governance validation passed.');
  return 0;
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  process.exitCode = main();
}
