import assert from 'node:assert/strict';
import test from 'node:test';
import { main } from './harness.mjs';

for (const command of ['doctor', 'check', 'eval', 'sync']) {
  test(`${command} delegates and preserves exit code`, () => {
    let call;
    const runner = (binary, args, options) => {
      call = { binary, args, options };
      return { status: 7 };
    };
    assert.equal(main([command, '--test-option'], runner), 7);
    assert.equal(call.binary, process.execPath);
    assert.equal(call.options.stdio, 'inherit');
    assert.equal(call.args.at(-1), '--test-option');
    if (command === 'sync') assert.ok(call.args.includes('--check'));
    if (command === 'eval') assert.deepEqual(call.args.slice(1, 3), ['--level', 'H1']);
  });
}

test('unknown command fails without delegating', () => {
  assert.equal(main(['unknown'], () => { throw Error('unexpected'); }), 2);
});

test('spawn failure is BLOCKED, never PASS', () => {
  assert.equal(main(['doctor'], () => ({ error: new Error('denied') })), 2);
});
