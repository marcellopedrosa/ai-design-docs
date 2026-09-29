import test from 'node:test';
import assert from 'node:assert/strict';
import path from 'node:path';
import fs from 'node:fs';
import os from 'node:os';
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

test('description of exactly 500 characters is accepted', () => {
  const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'hd-'));
  const skillDir = path.join(tmp, 'skills', 'test-skill');
  fs.mkdirSync(skillDir, { recursive: true });
  fs.mkdirSync(path.join(skillDir, 'evals'), { recursive: true });
  fs.writeFileSync(path.join(skillDir, 'contract.yaml'), 'name: test-skill\n');
  fs.writeFileSync(path.join(skillDir, 'evals', 'evals.json'), '{"evals":[{"id":"t1","category":"c","description":"d","input":"i","expected":"e","assertions":"a"}]}');
  const desc500 = 'A'.repeat(500);
  fs.writeFileSync(path.join(skillDir, 'SKILL.md'), `---\nname: test-skill\ndescription: ${desc500}\n---\n`);
  const { errors } = checkSkills(tmp);
  const descErrors = errors.filter(e => e.includes('description'));
  assert.equal(descErrors.length, 0, `500-char description should be accepted: ${descErrors.join(', ')}`);
  fs.rmSync(tmp, { recursive: true, force: true });
});

test('description of 501 characters is rejected', () => {
  const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'hd-'));
  const skillDir = path.join(tmp, 'skills', 'test-skill');
  fs.mkdirSync(skillDir, { recursive: true });
  fs.mkdirSync(path.join(skillDir, 'evals'), { recursive: true });
  fs.writeFileSync(path.join(skillDir, 'contract.yaml'), 'name: test-skill\n');
  fs.writeFileSync(path.join(skillDir, 'evals', 'evals.json'), '{"evals":[{"id":"t1","category":"c","description":"d","input":"i","expected":"e","assertions":"a"}]}');
  const desc501 = 'A'.repeat(501);
  fs.writeFileSync(path.join(skillDir, 'SKILL.md'), `---\nname: test-skill\ndescription: ${desc501}\n---\n`);
  const { errors } = checkSkills(tmp);
  const descErrors = errors.filter(e => e.includes('description'));
  assert.ok(descErrors.length > 0, '501-char description should be rejected');
  fs.rmSync(tmp, { recursive: true, force: true });
});
