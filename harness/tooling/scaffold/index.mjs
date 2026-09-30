#!/usr/bin/env node
import path from 'node:path';
import process from 'node:process';
import { fileURLToPath } from 'node:url';
import { auditScaffold } from './engine.mjs';

export function main(args = process.argv.slice(2), root = path.resolve('.')) {
  const flags = new Set(args);
  const modes = ['--check', '--create', '--inspect'].filter((flag) => flags.has(flag));
  if (modes.length !== 1 || args.some((arg) => !['--check', '--create', '--inspect', '--json'].includes(arg))) {
    process.stderr.write('Usage: scaffold <--check|--create|--inspect> [--json]\n');
    return 2;
  }
  try {
    const mode = modes[0].slice(2);
    const report = auditScaffold(root, { mode });
    if (flags.has('--json')) process.stdout.write(`${JSON.stringify(report, null, 2)}\n`);
    else {
      process.stdout.write(`Manifest: ${report.manifest}\nProfiles: ${report.profiles.join(', ') || '(none)'}\n`);
      for (const item of report.artifacts) process.stdout.write(`${item.status} ${item.expected}${item.legacy.length ? ` <- ${item.legacy.join(', ')}` : ''}\n`);
      for (const item of report.inspection) process.stdout.write(`${item.action} ${item.current} -> ${item.expected}\n`);
      if (report.suggestions) process.stdout.write(`CANDIDATE_PROFILES ${report.suggestions.profiles.join(', ') || '(none)'} (review required)\n`);
      for (const warning of report.warnings) process.stdout.write(`WARN ${warning}\n`);
    }
    if (mode !== 'inspect' && !report.manifest.startsWith('PRESENT')) return 2;
    if (report.artifacts.some((item) => item.status === 'LEGACY_LOCATION')) return 1;
    if (mode === 'check' && report.artifacts.some((item) => item.status === 'CREATE')) return 1;
    return 0;
  } catch (error) {
    process.stderr.write(`FAIL ${error.message}\n`);
    return 1;
  }
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  process.exitCode = main();
}
