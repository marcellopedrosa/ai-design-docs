import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import test from 'node:test';
import { fileURLToPath } from 'node:url';
import { main } from './index.mjs';
import { parseYamlSubset } from '../scaffold/yaml.mjs';

const sourceRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../../..');

function fixture() {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'harness-onboard-'));
  for (const relative of [
    'harness/onboarding/questions.yaml',
    'harness/registry/profiles.yaml',
    'harness/registry/artifact-routes.yaml',
    'harness/registry/standards.yaml',
    'harness/contracts/project-manifest.schema.json',
    'harness/contracts/profile-registry.schema.json',
    'harness/contracts/artifact-routes.schema.json',
    'harness/templates/agents/agent-template.md',
    'harness/templates/standards/standard-template.md',
    'harness/templates/architecture/architecture-template.md',
    'harness/templates/requirements/requirement-template.md'
  ]) {
    const target = path.join(root, relative);
    fs.mkdirSync(path.dirname(target), { recursive: true });
    fs.copyFileSync(path.join(sourceRoot, relative), target);
  }
  return root;
}

function answers(values) {
  let index = 0;
  return async () => values[index++];
}

test('quiz creates a manifest, derives agents and records completed state', async (t) => {
  const root = fixture();
  t.after(() => fs.rmSync(root, { recursive: true, force: true }));
  const output = [];

  const status = await main([], root, {
    ask: answers(['Meu Projeto', '1', 'Equipe Produto', '2,5', 'sim']),
    write: (message) => output.push(message),
    completedOn: '2026-10-01'
  });

  assert.equal(status, 0);
  const manifest = parseYamlSubset(fs.readFileSync(path.join(root, 'docs/project-manifest.yaml'), 'utf8'));
  assert.equal(manifest.project.name, 'meu-projeto');
  assert.equal(manifest.project.type, 'application');
  assert.deepEqual(manifest.profiles, ['frontend', 'security']);
  assert.deepEqual(manifest.agents, ['frontend']);
  assert.equal(manifest.metadata.owner, 'Equipe Produto');
  assert.deepEqual(manifest.onboarding, {
    status: 'completed',
    questionnaire_version: 2,
    completed_on: '2026-10-01'
  });
  assert.match(output.at(-1), /scaffold --check/);
});

test('completed onboarding skips the quiz on later executions', async (t) => {
  const root = fixture();
  t.after(() => fs.rmSync(root, { recursive: true, force: true }));
  const first = await main([], root, {
    ask: answers(['Projeto Repeticao', '2', 'Equipe Plataforma', '1', 'sim']),
    write: () => {},
    completedOn: '2026-10-01'
  });
  assert.equal(first, 0);

  let asked = false;
  const output = [];
  const second = await main([], root, {
    ask: async () => { asked = true; throw new Error('quiz must not run'); },
    write: (message) => output.push(message)
  });

  assert.equal(second, 0);
  assert.equal(asked, false);
  assert.match(output[0], /quiz não repetido/);
});

test('cancelled quiz does not create a manifest', async (t) => {
  const root = fixture();
  t.after(() => fs.rmSync(root, { recursive: true, force: true }));

  const status = await main([], root, {
    ask: answers(['Projeto Cancelado', '1', 'Equipe Produto', '1', 'nao']),
    write: () => {},
    completedOn: '2026-10-01'
  });

  assert.equal(status, 2);
  assert.equal(fs.existsSync(path.join(root, 'docs/project-manifest.yaml')), false);
});

test('invalid existing manifest blocks instead of suppressing the quiz', async (t) => {
  const root = fixture();
  t.after(() => fs.rmSync(root, { recursive: true, force: true }));
  const manifest = path.join(root, 'docs/project-manifest.yaml');
  fs.mkdirSync(path.dirname(manifest), { recursive: true });
  fs.writeFileSync(manifest, 'version: 1\nproject:\n  name: INVALID NAME\n  type: application\nprofiles:\n  - base\nagents: []\n');
  let asked = false;

  const status = await main([], root, {
    ask: async () => { asked = true; return ''; },
    write: () => {}
  });

  assert.equal(status, 2);
  assert.equal(asked, false);
});
