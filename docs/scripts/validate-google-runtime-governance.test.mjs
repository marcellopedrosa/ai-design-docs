import assert from 'node:assert/strict';
import test from 'node:test';

import { validateGoogleRuntimeGovernance } from './validate-google-runtime-governance.mjs';

const packages = ['backend', 'frontend', 'website', 'infra'];
const skills = ['governanca-documental', 'implementation-readiness', 'quality-gate'];

function validArtifacts() {
  const googleSettings = [
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
  ].join('\n');
  return {
    rootGemini: '# Gemini\n\n@./AGENTS.md\n',
    antigravityRule: '# Regra\n\n@../../AGENTS.md\n\nUse o AGENTS.md mais próximo e preserve ADR-0000.\n',
    packageAdapters: packages.map((packageName) => ({
      packageName,
      content: '@./AGENTS.md\n'
    })),
    googleSettings,
    adr: 'Version: 4.20\nGOOGLE-AGENTS-001\nGOOGLE-SKILLS-001\nGOOGLE-SECURITY-001\nGOOGLE-PROJECTS-001\nGOOGLE-VERIFY-001',
    docsMap: 'GEMINI.md\n.agents/rules/documentation-governance.md\n.gemini/settings.json\nNot applicable',
    aiManual: 'GEMINI.md\n.agents/rules/documentation-governance.md\ndocs/settings/google-gemini.md',
    settingsIndex: 'google-gemini.md\nGemini CLI\nAntigravity',
    globalSettings: 'Gemini CLI\nGoogle Antigravity\ndocs/settings/google-gemini.md',
    skillsCatalog: ['.agents/skills/', 'Gemini CLI', 'Antigravity', ...skills].join('\n'),
    moduleRegistry: packages.map((packageName) => `../../${packageName}/GEMINI.md`).join('\n'),
    duplicatedGeminiSkills: []
  };
}

test('accepts the complete Google runtime governance contract', () => {
  assert.deepEqual(validateGoogleRuntimeGovernance(validArtifacts()), []);
});

test('rejects divergent adapters, unsafe mapping and duplicated skills', () => {
  const artifacts = validArtifacts();
  artifacts.rootGemini = '# missing import\n';
  artifacts.antigravityRule = 'x'.repeat(12001);
  artifacts.packageAdapters[0].content = '# missing import\n';
  artifacts.googleSettings = artifacts.googleSettings.replace('Proceed in Sandbox', 'Always Proceed');
  artifacts.duplicatedGeminiSkills = ['quality-gate'];
  const errors = validateGoogleRuntimeGovernance(artifacts).join('\n');
  assert.match(errors, /GEMINI\.md: required marker missing/);
  assert.match(errors, /Antigravity workspace rule: exceeds 12,000 characters/);
  assert.match(errors, /backend\/GEMINI\.md/);
  assert.match(errors, /Proceed in Sandbox/);
  assert.match(errors, /duplicates shared skills: quality-gate/);
});
