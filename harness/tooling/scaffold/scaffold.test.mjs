import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import test from 'node:test';
import { fileURLToPath } from 'node:url';
import { auditScaffold, loadModel, resolveArtifacts, resolveProfiles, routeArtifact } from './engine.mjs';
import { main as scaffoldMain } from './index.mjs';
import { parseYamlSubset } from './yaml.mjs';

const sourceRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../../..');

function withProject(callback, manifest = 'frontend-project.yaml') {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'scaffold-v6-'));
  try {
    for (const rel of [
      'harness/contracts/project-manifest.schema.json',
      'harness/contracts/profile-registry.schema.json',
      'harness/contracts/artifact-routes.schema.json',
      'harness/registry/profiles.yaml',
      'harness/registry/standards.yaml',
      'harness/registry/artifact-routes.yaml'
    ]) {
      const target = path.join(root, rel);
      fs.mkdirSync(path.dirname(target), { recursive: true });
      fs.copyFileSync(path.join(sourceRoot, rel), target);
    }
    for (const type of ['agents', 'standards', 'architecture', 'requirements']) {
      fs.cpSync(path.join(sourceRoot, 'harness', 'templates', type), path.join(root, 'harness', 'templates', type), { recursive: true });
    }
    fs.mkdirSync(path.join(root, 'docs'), { recursive: true });
    if (manifest) fs.copyFileSync(path.join(sourceRoot, 'harness', 'examples', 'project-manifests', manifest), path.join(root, 'docs', 'project-manifest.yaml'));
    callback(root);
  } finally {
    fs.rmSync(root, { recursive: true, force: true });
  }
}

test('YAML subset parses nested artifact mappings and rejects ambiguous syntax', () => {
  const parsed = parseYamlSubset('profiles:\n  frontend:\n    artifacts:\n      - type: standard\n        scope: frontend\n        name: frontend-standard\n');
  assert.deepEqual(parsed.profiles.frontend.artifacts, [{ type: 'standard', scope: 'frontend', name: 'frontend-standard' }]);
  assert.throws(() => parseYamlSubset('version: 1\nversion: 2\n'), /duplicate key/);
  assert.throws(() => parseYamlSubset('value: &anchor\n'), /unsupported/);
  assert.throws(() => parseYamlSubset('bad:\n   value: 1\n'), /indentation/);
});

test('profile inheritance is deterministic, deduplicated and cycle-safe', () => {
  const data = parseYamlSubset(fs.readFileSync(path.join(sourceRoot, 'harness/registry/profiles.yaml'), 'utf8'));
  assert.deepEqual(resolveProfiles(data.profiles, ['frontend', 'security']), ['base', 'frontend', 'security']);
  assert.deepEqual(resolveProfiles(data.profiles, ['backend']), ['base', 'backend']);
  assert.throws(() => resolveProfiles({ a: { extends: ['b'] }, b: { extends: ['a'] } }, ['a']), /cycle/);
  assert.throws(() => resolveProfiles(data.profiles, ['mobile']), /unknown profile/);
  assert.throws(() => resolveProfiles(data.profiles, ['toString']), /unsafe identifier|unknown profile/);
});

test('frontend requires frontend artifacts; backend does not create frontend artifacts', () => {
  withProject((root) => {
    const model = loadModel(root);
    const resolved = resolveArtifacts(model);
    assert.ok(resolved.artifacts.some((item) => item.type === 'standard' && item.name === 'frontend-typography-standard'));
    assert.ok(resolved.artifacts.some((item) => item.type === 'standard' && item.name === 'application-security-standard'));
    assert.ok(resolved.artifacts.some((item) => item.type === 'agent' && item.name === 'frontend'));
  });
  withProject((root) => {
    const resolved = resolveArtifacts(loadModel(root));
    assert.ok(resolved.artifacts.some((item) => item.name === 'backend-standard'));
    assert.ok(!resolved.artifacts.some((item) => item.name.startsWith('frontend')));
  }, 'backend-project.yaml');
});

test('check is read-only; create is exclusive, idempotent and never overwrites local content', () => {
  withProject((root) => {
    const existing = path.join(root, 'docs/agents/frontend-agent.md');
    fs.mkdirSync(path.dirname(existing), { recursive: true });
    fs.writeFileSync(existing, '# Squad-owned frontend agent\n');
    const before = fs.readFileSync(existing, 'utf8');
    const check = auditScaffold(root);
    assert.ok(check.artifacts.some((item) => item.status === 'CREATE'));
    assert.equal(fs.existsSync(path.join(root, 'docs/agents/standards/frontend/frontend-standard.md')), false);
    const first = auditScaffold(root, { mode: 'create' });
    assert.ok(first.artifacts.some((item) => item.status === 'CREATED'));
    assert.equal(fs.readFileSync(existing, 'utf8'), before);
    assert.ok(auditScaffold(root).artifacts.every((item) => item.status === 'KEEP'));
    assert.ok(auditScaffold(root, { mode: 'create' }).artifacts.every((item) => item.status === 'KEEP'));
    assert.equal(fs.readFileSync(existing, 'utf8'), before);
  });
});

test('legacy location is reported and never migrated or duplicated by create', () => {
  withProject((root) => {
    const legacy = path.join(root, 'docs/frontend/frontend-standard.md');
    fs.mkdirSync(path.dirname(legacy), { recursive: true });
    fs.writeFileSync(legacy, '# Existing standard\n');
    const report = auditScaffold(root, { mode: 'create' });
    const item = report.artifacts.find((artifact) => artifact.name === 'frontend-standard');
    assert.equal(item.status, 'LEGACY_LOCATION');
    assert.deepEqual(item.legacy, ['docs/frontend/frontend-standard.md']);
    assert.equal(fs.existsSync(path.join(root, item.expected)), false);
    assert.equal(fs.readFileSync(legacy, 'utf8'), '# Existing standard\n');
  });
});

test('missing manifest is a warning and inspect stays read-only', () => {
  withProject((root) => {
    const existing = path.join(root, 'docs/agents/frontend-agent.md');
    fs.mkdirSync(path.dirname(existing), { recursive: true });
    fs.writeFileSync(existing, '# Existing agent\n');
    const report = auditScaffold(root, { mode: 'inspect' });
    assert.equal(report.manifest, 'MISSING');
    assert.ok(report.warnings.some((warning) => warning.includes('missing')));
    assert.ok(report.inspection.some((item) => item.current === 'docs/agents/frontend-agent.md'));
    assert.deepEqual(report.suggestions.profiles, ['frontend']);
    assert.equal(report.suggestions.reviewRequired, true);
    assert.equal(fs.readFileSync(existing, 'utf8'), '# Existing agent\n');
    assert.equal(scaffoldMain(['--inspect', '--json'], root), 0);
    assert.equal(scaffoldMain(['--check', '--json'], root), 2);
  }, null);
});

test('malicious profile, manifest and route paths fail before creation', () => {
  withProject((root) => {
    const model = loadModel(root);
    assert.throws(() => routeArtifact(root, model.routes.standard, { type: 'standard', scope: '../../../../outside', name: 'evil' }), /unsafe identifier/);
    const manifest = path.join(root, 'docs/project-manifest.yaml');
    fs.writeFileSync(manifest, fs.readFileSync(manifest, 'utf8').replace('  - frontend', '  - ../outside'));
    assert.throws(() => auditScaffold(root, { mode: 'create' }), /pattern|unsafe|unknown/);
    assert.equal(fs.existsSync(path.join(root, 'outside')), false);
  });
  withProject((root) => {
    const route = path.join(root, 'harness/registry/artifact-routes.yaml');
    fs.writeFileSync(route, fs.readFileSync(route, 'utf8').replace('root: docs/agents', 'root: ../outside'));
    assert.throws(() => auditScaffold(root, { mode: 'create' }), /unsafe path|outside/);
  });
});

test('the example fullstack manifest validates and resolves both application sides', () => {
  withProject((root) => {
    const result = resolveArtifacts(loadModel(root));
    assert.ok(result.artifacts.some((item) => item.name === 'frontend-standard'));
    assert.ok(result.artifacts.some((item) => item.name === 'backend-standard'));
    assert.equal(result.artifacts.filter((item) => item.name === 'security-standard').length, 1);
  }, 'fullstack-project.yaml');
});

test('requirement route preserves the existing REQ naming convention', () => {
  withProject((root) => {
    const routes = loadModel(root).routes;
    const artifact = { type: 'requirement', name: 'REQ-00008-example' };
    assert.equal(routeArtifact(root, routes.requirement, artifact).relative, 'docs/product/requirements/REQ-00008-example.md');
    assert.throws(() => routeArtifact(root, routes.requirement, { type: 'requirement', name: 'example' }), /REQ-NNNNN/);
  });
});

test('all four artifact routes create only missing template drafts', () => {
  withProject((root) => {
    const registry = path.join(root, 'harness/registry/profiles.yaml');
    const source = fs.readFileSync(registry, 'utf8');
    fs.writeFileSync(registry, source.replace(
      'name: application-security-standard',
      'name: application-security-standard\n      - type: architecture\n        name: service-map\n      - type: requirement\n        name: REQ-00008-example'
    ));
    const report = auditScaffold(root, { mode: 'create' });
    assert.ok(report.artifacts.some((item) => item.type === 'agent' && item.status === 'CREATED'));
    assert.ok(report.artifacts.some((item) => item.type === 'standard' && item.status === 'CREATED'));
    assert.ok(report.artifacts.some((item) => item.type === 'architecture' && item.status === 'CREATED'));
    assert.ok(report.artifacts.some((item) => item.type === 'requirement' && item.status === 'CREATED'));
    assert.match(fs.readFileSync(path.join(root, 'docs/product/requirements/REQ-00008-example.md'), 'utf8'), /## Acceptance Criteria/);
  });
});

test('missing parent, inheritance cycle, missing route and missing template fail closed', () => {
  withProject((root) => {
    const registry = path.join(root, 'harness/registry/profiles.yaml');
    const original = fs.readFileSync(registry, 'utf8');
    fs.writeFileSync(registry, original.replace('      - base', '      - mobile'));
    assert.throws(() => loadModel(root), /unknown parent profile/);
    fs.writeFileSync(registry, original.replace('  base:\n    artifacts:', '  base:\n    extends:\n      - frontend\n    artifacts:'));
    assert.throws(() => loadModel(root), /cycle/);
    fs.writeFileSync(registry, original);
    fs.writeFileSync(registry, original.replace('name: frontend-standard', 'name: unknown-standard'));
    assert.throws(() => loadModel(root), /standard not cataloged/);
    fs.writeFileSync(registry, original);
    const routes = path.join(root, 'harness/registry/artifact-routes.yaml');
    const routeSource = fs.readFileSync(routes, 'utf8');
    fs.writeFileSync(routes, routeSource.replace('  agent:\n', '  missing-agent:\n'));
    assert.throws(() => loadModel(root), /route missing: agent/);
    fs.writeFileSync(routes, routeSource.replace('harness/templates/agents/agent-template.md', 'harness/templates/agents/missing.md'));
    assert.throws(() => loadModel(root), /template missing/);
  });
});

test('template data is copied literally, never executed', () => {
  withProject((root) => {
    const template = path.join(root, 'harness/templates/agents/agent-template.md');
    fs.writeFileSync(template, '# {{title}}\n$(echo should-not-run)\n');
    auditScaffold(root, { mode: 'create' });
    const created = fs.readFileSync(path.join(root, 'docs/agents/frontend-agent.md'), 'utf8');
    assert.match(created, /\$\(echo should-not-run\)/);
  });
});

test('symlinked artifact directories cannot escape the project root', () => {
  withProject((root) => {
    const outside = fs.mkdtempSync(path.join(os.tmpdir(), 'scaffold-outside-'));
    try {
      const parent = path.join(root, 'docs/agents/standards');
      fs.mkdirSync(parent, { recursive: true });
      try {
        fs.symlinkSync(outside, path.join(parent, 'frontend'), process.platform === 'win32' ? 'junction' : 'dir');
      } catch (error) {
        if (error.code === 'EPERM' || error.code === 'EACCES') return;
        throw error;
      }
      assert.throws(() => auditScaffold(root, { mode: 'create' }), /symlink/);
      assert.equal(fs.readdirSync(outside).length, 0);
    } finally {
      fs.rmSync(outside, { recursive: true, force: true });
    }
  });
});
