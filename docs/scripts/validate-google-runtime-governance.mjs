#!/usr/bin/env node

import fs from 'node:fs';
import path from 'node:path';
import process from 'node:process';
import { fileURLToPath } from 'node:url';

const PACKAGES = ['backend', 'frontend', 'website', 'infra'];
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
    '@../../AGENTS.md', 'AGENTS.md', 'mais próximo', 'ADR-0000'
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
    'Always On', '12.000 caracteres', 'Proceed in Sandbox',
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
  requireMarkers(errors, 'ADR-0000', artifacts.adr, [
    'Version: 4.20', 'GOOGLE-AGENTS-001', 'GOOGLE-SKILLS-001',
    'GOOGLE-SECURITY-001', 'GOOGLE-PROJECTS-001', 'GOOGLE-VERIFY-001'
  ]);
  requireMarkers(errors, 'docs/README.md', artifacts.docsMap, [
    'GEMINI.md', '.agents/rules/documentation-governance.md',
    '.gemini/settings.json', 'Not applicable'
  ]);
  requireMarkers(errors, 'docs/ai/README.md', artifacts.aiManual, [
    'GEMINI.md', '.agents/rules/documentation-governance.md',
    'docs/settings/google-gemini.md'
  ]);
  requireMarkers(errors, 'docs/settings/README.md', artifacts.settingsIndex, [
    'google-gemini.md', 'Gemini CLI', 'Antigravity'
  ]);
  requireMarkers(errors, 'docs/settings/settings.md', artifacts.globalSettings, [
    'Gemini CLI', 'Google Antigravity', 'docs/settings/google-gemini.md'
  ]);
  requireMarkers(errors, 'docs/agents/skills/README.md', artifacts.skillsCatalog, [
    '.agents/skills/', 'Gemini CLI', 'Antigravity', ...SKILLS
  ]);
  for (const packageName of PACKAGES) {
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

export function validateRepository(repositoryRoot) {
  const root = path.resolve(repositoryRoot);
  const required = [
    'AGENTS.md', 'GEMINI.md', '.agents/rules/documentation-governance.md',
    'docs/settings/google-gemini.md', 'docs/settings/README.md',
    'docs/settings/settings.md', 'docs/README.md', 'docs/ai/README.md',
    'docs/adrs/ADR-0000-governanca-do-harness-documental.md',
    'docs/agents/skills/README.md', 'docs/architecture/module-registry.md',
    ...PACKAGES.flatMap((packageName) => [
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
    packageAdapters: PACKAGES.map((packageName) => ({
      packageName,
      content: read(`${packageName}/GEMINI.md`)
    })),
    googleSettings: read('docs/settings/google-gemini.md'),
    adr: read('docs/adrs/ADR-0000-governanca-do-harness-documental.md'),
    docsMap: read('docs/README.md'),
    aiManual: read('docs/ai/README.md'),
    settingsIndex: read('docs/settings/README.md'),
    globalSettings: read('docs/settings/settings.md'),
    skillsCatalog: read('docs/agents/skills/README.md'),
    moduleRegistry: read('docs/architecture/module-registry.md'),
    duplicatedGeminiSkills
  });
}

export function main(argv = process.argv.slice(2)) {
  const rootIndex = argv.indexOf('--root');
  const root = rootIndex >= 0 ? argv[rootIndex + 1] : process.cwd();
  if (!root || (argv.length > 0 && rootIndex < 0)) {
    console.error('Usage: validate-google-runtime-governance.mjs [--root <repository>]');
    return 2;
  }
  const errors = validateRepository(root);
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
