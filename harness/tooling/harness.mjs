#!/usr/bin/env node

import { spawnSync } from 'node:child_process';
import path from 'node:path';
import process from 'node:process';
import { fileURLToPath } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
const commands = {
  doctor: ['harness/tooling/harness-doctor/index.mjs'],
  check: ['harness/tooling/validators/validate-documentation-governance.mjs', '--root', root],
  eval: ['harness/tooling/eval-runner/index.mjs', '--level', 'H1', '--root', root],
  sync: ['harness/tooling/adapters/sync-adapters.mjs', '--check', '--root', root],
  scaffold: ['harness/tooling/scaffold/index.mjs'],
  onboard: ['harness/tooling/onboard/index.mjs'],
  bootstrap: ['harness/tooling/bootstrap/index.mjs']
};

export function main(args = process.argv.slice(2), runner = spawnSync) {
  const [command, ...extra] = args;
  if (!Object.hasOwn(commands, command)) {
    process.stderr.write('Usage: node harness/tooling/harness.mjs <doctor|check|eval|sync|onboard|bootstrap|scaffold> [tool options]\n');
    return 2;
  }
  const [entrypoint, ...defaults] = commands[command];
  const result = runner(process.execPath, [path.join(root, entrypoint), ...defaults, ...extra], {
    cwd: root,
    stdio: 'inherit'
  });
  if (result.error) {
    process.stderr.write(`[BLOCKED] ${command}: ${result.error.message}\n`);
    return 2;
  }
  return result.status ?? 2;
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  process.exitCode = main();
}
