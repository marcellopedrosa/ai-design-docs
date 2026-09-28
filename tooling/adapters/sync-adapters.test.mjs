import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { syncAdapters } from './sync-adapters.mjs';

test('syncAdapters check detects parity with canonical skills', () => {
  const root = path.resolve('.');
  const { errors } = syncAdapters(root, true);
  assert.equal(errors.length, 0, `Expected 0 parity errors, got: ${errors.join(', ')}`);
});
