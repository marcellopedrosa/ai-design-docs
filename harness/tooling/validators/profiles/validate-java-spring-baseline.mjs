#!/usr/bin/env node

/**
 * Profile validator entry point. Java/Spring checks are opt-in and isolated
 * from the harness-wide validators.
 */
import { validateRepository } from '../validate-api-contract-coverage.mjs';

export { validateRepository };

if (import.meta.url === `file://${process.argv[1].replaceAll('\\', '/')}`) {
  const rootIndex = process.argv.indexOf('--root');
  const root = rootIndex >= 0 ? process.argv[rootIndex + 1] : process.cwd();
  const result = validateRepository(root);
  process.stdout.write(`JAVA_SPRING_PROFILE controllers=${result.stats.controllers} contracts=${result.stats.contracts}\n`);
  if (result.errors.length) {
    process.stderr.write(`${result.errors.join('\n')}\n`);
    process.exitCode = 1;
  }
}
