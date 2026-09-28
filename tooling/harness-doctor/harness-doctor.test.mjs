import test from 'node:test';
import assert from 'node:assert/strict';
import path from 'node:path';
import { checkRegistry, checkContracts, checkSkills, checkAdapters, checkEvals } from './index.mjs';

test('checkRegistry passes on repository root', () => {
  const root = path.resolve('.');
  const { errors } = checkRegistry(root);
  assert.equal(errors.length, 0, `Registry errors: ${errors.join(', ')}`);
});

test('checkContracts passes on repository root', () => {
  const root = path.resolve('.');
  const { errors } = checkContracts(root);
  assert.equal(errors.length, 0, `Contract errors: ${errors.join(', ')}`);
});

test('checkSkills passes on repository root', () => {
  const root = path.resolve('.');
  const { errors } = checkSkills(root);
  assert.equal(errors.length, 0, `Skill errors: ${errors.join(', ')}`);
});

test('checkAdapters passes on repository root', () => {
  const root = path.resolve('.');
  const { errors } = checkAdapters(root);
  assert.equal(errors.length, 0, `Adapter errors: ${errors.join(', ')}`);
});

test('checkEvals passes on repository root and validates eval counts', () => {
  const root = path.resolve('.');
  const { errors, count } = checkEvals(root);
  assert.equal(errors.length, 0, `Eval errors: ${errors.join(', ')}`);
  assert.ok(count > 0, `Expected eval count > 0, got ${count}`);
});
