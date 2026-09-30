import test from 'node:test';
import assert from 'node:assert/strict';
import { handlePreToolUse, isForbiddenPath } from './guard-paths.mjs';
import { handleStop } from './require-handoff.mjs';
import { handlePreToolUseBash, isForbiddenBashCommand } from './guard-bash.mjs';

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

test('isForbiddenBashCommand distinguishes test commands from write/git mutations', () => {
  assert.equal(isForbiddenBashCommand('npm test').forbidden, false);
  assert.equal(isForbiddenBashCommand('mvn test').forbidden, false);
  assert.equal(isForbiddenBashCommand('node --test tooling/').forbidden, false);
  assert.equal(isForbiddenBashCommand('git status').forbidden, false);
  assert.equal(isForbiddenBashCommand('git diff').forbidden, false);

  assert.equal(isForbiddenBashCommand('rm -rf src/').forbidden, true);
  assert.equal(isForbiddenBashCommand('echo "x" > out.txt').forbidden, true);
  assert.equal(isForbiddenBashCommand('npm test >> out.log').forbidden, true);
  assert.equal(isForbiddenBashCommand('sed -i "s/a/b/g" file.txt').forbidden, true);
  assert.equal(isForbiddenBashCommand('git commit -m "update"').forbidden, true);
  assert.equal(isForbiddenBashCommand('git push origin main').forbidden, true);
  assert.equal(isForbiddenBashCommand('git add .').forbidden, true);
  assert.equal(isForbiddenBashCommand('git checkout main').forbidden, true);
  assert.equal(isForbiddenBashCommand('git reset --hard HEAD~1').forbidden, true);
});

test('handlePreToolUseBash blocks mutations only for GateEvaluator agent', () => {
  const blockedForEvaluator = handlePreToolUseBash({
    tool: 'Bash',
    agent: 'GateEvaluator',
    parameters: { command: 'rm -f file.txt' }
  });
  assert.equal(blockedForEvaluator.allow, false);
  assert.ok(blockedForEvaluator.reason.includes('BLOCKED by guard-bash'));

  const allowedForEvaluator = handlePreToolUseBash({
    tool: 'Bash',
    agent: 'GateEvaluator',
    parameters: { command: 'npm test' }
  });
  assert.equal(allowedForEvaluator.allow, true);

  const allowedForOrchestrator = handlePreToolUseBash({
    tool: 'Bash',
    agent: 'AgentOrchestrator',
    parameters: { command: 'rm -f file.txt' }
  });
  assert.equal(allowedForOrchestrator.allow, true, 'Non-evaluator agents are not restricted by guard-bash');
});
