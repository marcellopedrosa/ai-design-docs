import assert from 'node:assert/strict';
import test from 'node:test';
import { validateTrace } from './trace.mjs';

const valid = () => ({
  evidence: [{ evidence_id: 'EV-1', exit_code: 0, freshness: { task_id: 'T-1', scope_fingerprint: 'abc' } }],
  gate: { status: 'PASS', task_id: 'T-1', scope_fingerprint: 'abc', evidence: ['EV-1'] },
  handoff: { status: 'PASS', task_id: 'T-1', evidence_refs: ['EV-1'], commands_executed: [], pending_items: [], limitations: [] }
});

test('linked PASS is accepted', () => assert.deepEqual(validateTrace(valid()), []));
test('PASS without evidence is blocked', () => {
  const value = valid(); value.gate.evidence = [];
  assert.match(validateTrace(value).join(' '), /no evidence/);
});
test('missing and stale evidence are blocked', () => {
  const value = valid(); value.gate.evidence.push('EV-2');
  assert.match(validateTrace(value).join(' '), /missing evidence/);
  value.gate.evidence.pop(); value.evidence[0].freshness.scope_fingerprint = 'old';
  assert.match(validateTrace(value).join(' '), /stale evidence/);
});
test('failed command and omitted handoff evidence are blocked', () => {
  const value = valid(); value.evidence[0].exit_code = 1; value.handoff.evidence_refs = [];
  assert.match(validateTrace(value).join(' '), /failed evidence/);
  assert.match(validateTrace(value).join(' '), /handoff omits/);
});
test('subgate PASS needs evidence and handoff reports omissions', () => {
  const value = valid(); value.gate.subgates = { A1: { status: 'PASS', evidence: [] } };
  delete value.handoff.commands_executed;
  assert.match(validateTrace(value).join(' '), /PASS subgate/);
  assert.match(validateTrace(value).join(' '), /commands_executed/);
});
test('PASS gate cannot hide failed subgate or blocked handoff', () => {
  const value = valid(); value.gate.subgates = { A3: { status: 'FAIL', evidence: ['EV-1'] } };
  value.handoff.status = 'BLOCKED';
  assert.match(validateTrace(value).join(' '), /non-passing subgate/);
  assert.match(validateTrace(value).join(' '), /non-passing handoff/);
});
