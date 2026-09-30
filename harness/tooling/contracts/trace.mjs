#!/usr/bin/env node

import fs from 'node:fs';
import path from 'node:path';
import process from 'node:process';
import { fileURLToPath } from 'node:url';

// A stateless consistency check over existing Evidence, GateResult and Handoff contracts.
export function validateTrace({ evidence, gate, handoff }) {
  const errors = [];
  if (!Array.isArray(evidence) || !gate || !handoff) return ['evidence, gate and handoff are required'];
  const byId = new Map(evidence.map(item => [item.evidence_id, item]));
  const requiredIds = new Set(gate.evidence ?? []);
  for (const subgate of Object.values(gate.subgates ?? {})) {
    if (gate.status === 'PASS' && !['PASS', 'SKIPPED'].includes(subgate.status))
      errors.push('PASS gate contains non-passing subgate');
    if (subgate.status === 'PASS' && !subgate.evidence?.length) errors.push('PASS subgate has no evidence');
    for (const id of subgate.evidence ?? []) requiredIds.add(id);
  }
  if (gate.status === 'PASS' && requiredIds.size === 0) errors.push('PASS gate has no evidence');
  for (const id of requiredIds) {
    const item = byId.get(id);
    if (!item) errors.push(`missing evidence: ${id}`);
    else {
      if (item.freshness?.task_id !== gate.task_id || item.freshness?.scope_fingerprint !== gate.scope_fingerprint)
        errors.push(`stale evidence: ${id}`);
      if (gate.status === 'PASS' && item.exit_code !== undefined && item.exit_code !== 0)
        errors.push(`failed evidence cannot support PASS: ${id}`);
    }
  }
  if (handoff.task_id !== gate.task_id) errors.push('handoff task differs from gate task');
  if (gate.status === 'PASS') {
    if (!['PASS', 'COMPLETED'].includes(handoff.status)) errors.push('PASS gate has non-passing handoff');
    for (const id of requiredIds) if (!handoff.evidence_refs?.includes(id)) errors.push(`handoff omits evidence: ${id}`);
  }
  if (!Array.isArray(handoff.commands_executed)) errors.push('handoff must report commands_executed (possibly empty)');
  if (!Array.isArray(handoff.pending_items)) errors.push('handoff must report pending_items (possibly empty)');
  if (!Array.isArray(handoff.limitations)) errors.push('handoff must report limitations (possibly empty)');
  return errors;
}

export function main(args = process.argv.slice(2)) {
  if (args.length !== 2 || args[0] !== '--input') {
    process.stderr.write('Usage: node harness/tooling/contracts/trace.mjs --input <trace.json>\n');
    return 2;
  }
  try {
    const bundle = JSON.parse(fs.readFileSync(path.resolve(args[1]), 'utf8'));
    const errors = validateTrace(bundle);
    for (const error of errors) process.stderr.write(`[BLOCKED] ${error}\n`);
    if (errors.length) return 1;
    process.stdout.write('[PASS] Evidence, gate and handoff are linked.\n');
    return 0;
  } catch (error) {
    process.stderr.write(`[BLOCKED] Cannot read trace: ${error.message}\n`);
    return 2;
  }
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) process.exitCode = main();
