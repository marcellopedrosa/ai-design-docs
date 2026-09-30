import test from 'node:test';
import assert from 'node:assert/strict';
import { handlePreToolUse, isForbiddenPath } from './guard-paths.mjs';
import { handleStop } from './require-handoff.mjs';

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
    parameters: { file_path: 'docs/settings/settings.md' }
  });
  assert.equal(allowedDoc.allow, true);

  const allowedRead = handlePreToolUse({
    tool: 'Read',
    parameters: { file_path: '.env' }
  });
  assert.equal(allowedRead.allow, true, 'Non-edit tools should not be blocked by pre-edit hook');
});

test('handleStop respects stop_hook_active to prevent loops', () => {
  const result = handleStop({ stop_hook_active: true });
  assert.equal(result.allow, true);
  assert.ok(result.reason.includes('loop'));
});
