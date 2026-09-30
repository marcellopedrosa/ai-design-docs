import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import { handlePreToolUse, isForbiddenPath } from './guard-paths.mjs';

test('isForbiddenPath identifies sensitive files and paths', () => {
  assert.ok(isForbiddenPath('.env').forbidden);
  assert.ok(isForbiddenPath('.env.production').forbidden);
  assert.ok(isForbiddenPath('.env.local').forbidden);
  assert.ok(isForbiddenPath('secrets/api-keys.json').forbidden);
  assert.ok(isForbiddenPath('.secrets/prod.pem').forbidden);
  assert.ok(isForbiddenPath('config/credentials.json').forbidden);

  assert.ok(!isForbiddenPath('docs/README.md').forbidden);
  assert.ok(!isForbiddenPath('src/main/java/App.java').forbidden);
  assert.ok(!isForbiddenPath('package.json').forbidden);
});

test('handlePreToolUse blocks Edit/Write tools targeting forbidden files', () => {
  const blockedEnv = handlePreToolUse({
    tool: 'Edit',
    parameters: { file_path: '.env' }
  });
  assert.equal(blockedEnv.allow, false);
  assert.ok(blockedEnv.reason.includes('BLOCKED'));

  const blockedSecret = handlePreToolUse({
    tool: 'Write',
    parameters: { file_path: 'backend/secrets/key.txt' }
  });
  assert.equal(blockedSecret.allow, false);

  const allowedDoc = handlePreToolUse({
    tool: 'Edit',
    parameters: { file_path: 'harness/governance/policies/ai-environment-policy.md' }
  });
  assert.equal(allowedDoc.allow, true);

  const allowedRead = handlePreToolUse({
    tool: 'Read',
    parameters: { file_path: '.env' }
  });
  assert.equal(allowedRead.allow, true, 'Non-edit tools should not be blocked by pre-edit hook');
});

test('Claude settings do not activate a Stop hook without deterministic handoff evidence', () => {
  const settings = JSON.parse(fs.readFileSync(new URL('../../../.claude/settings.json', import.meta.url), 'utf8'));
  assert.ok(!Object.hasOwn(settings.hooks, 'Stop'));
  assert.deepEqual(settings.hooks.PreToolUse.map(hook => hook.command), ['node harness/tooling/hooks/guard-paths.mjs']);
});
