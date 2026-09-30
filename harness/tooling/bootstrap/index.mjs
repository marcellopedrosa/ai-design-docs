#!/usr/bin/env node
import path from 'node:path';
import process from 'node:process';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { auditScaffold } from '../scaffold/engine.mjs';

export function main(root=path.resolve('.')) {
  try {
    const report = auditScaffold(root, { mode: 'check' });
    if (!report.manifest.startsWith('PRESENT') || report.artifacts.some(x => ['CREATE','LEGACY_LOCATION','CONFLICT'].includes(x.status))) {
      console.error('BLOCKED bootstrap: manifest or required artifacts are not ready'); return 2;
    }
    const doctor = spawnSync(process.execPath, [path.join(root,'harness/tooling/harness-doctor/index.mjs')], {cwd:root, stdio:'inherit'});
    if (doctor.status !== 0) return doctor.status ?? 1;
    console.log('READY'); return 0;
  } catch (error) { console.error(`BLOCKED bootstrap: ${error.message}`); return 2; }
}
if (process.argv[1] && path.resolve(process.argv[1])===fileURLToPath(import.meta.url)) process.exitCode=main();
