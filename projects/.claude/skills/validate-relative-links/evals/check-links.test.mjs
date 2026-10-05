import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { test } from 'node:test';
import { checkRoot } from '../scripts/check-links.mjs';

const checker = fileURLToPath(new URL('../scripts/check-links.mjs', import.meta.url));

function withFixture(run) {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'links-eval-'));
  try { run(root); } finally { fs.rmSync(root, { recursive: true, force: true }); }
}

function write(root, relative, content) {
  const destination = path.join(root, relative);
  fs.mkdirSync(path.dirname(destination), { recursive: true });
  fs.writeFileSync(destination, content);
}

test('accepts valid relative Markdown and frontmatter references', () => withFixture((root) => {
  write(root, 'docs/target.md', '# Target');
  write(root, 'docs/index.md', [
    '---',
    'related_files: target.md',
    'code_references: N/A - documentação',
    '---',
    '[Target](target.md#heading)',
    '[External](https://example.com/page)',
    '[Anchor](#local)',
    '```markdown',
    '[Example](missing-example.md)',
    '```',
  ].join('\n'));
  assert.deepEqual(checkRoot(root), []);
  const result = spawnSync(process.execPath, [checker, '--root', root], { encoding: 'utf8' });
  assert.equal(result.status, 0);
}));

test('finds missing Markdown links and stale agent-template metadata', () => withFixture((root) => {
  write(root, 'templates/agents/README.md', [
    '---',
    'related_files: ../README.md, agent-template.md',
    '---',
    '[Agent](agent-template.md)',
  ].join('\n'));
  write(root, 'templates/README.md', '# Templates');
  const findings = checkRoot(root);
  assert.equal(findings.length, 2);
  assert.ok(findings.every((finding) => finding.target === 'agent-template.md'));
  const result = spawnSync(process.execPath, [checker, '--root', root], { encoding: 'utf8' });
  assert.equal(result.status, 1);
  assert.match(result.stdout, /agents[\\/]README\.md:2/);
}));

test('rejects absolute local paths and accepts Markdown reference definitions', () => withFixture((root) => {
  write(root, 'README.md', '[Good][item]\n[item]: target.md\n[Bad](/tmp/target.md)\n');
  write(root, 'target.md', '# Target');
  const findings = checkRoot(root);
  assert.equal(findings.length, 1);
  assert.equal(findings[0].reason, 'absolute local path');
}));

test('rejects invalid roots without scanning or writing', () => withFixture((root) => {
  const result = spawnSync(process.execPath, [checker, '--root', path.join(root, 'absent')], { encoding: 'utf8' });
  assert.equal(result.status, 2);
  assert.match(result.stderr, /Not a directory/);
}));
