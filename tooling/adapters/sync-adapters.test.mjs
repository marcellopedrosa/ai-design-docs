import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { syncAdapters } from './sync-adapters.mjs';

test('syncAdapters check detects parity with canonical skills', () => {
  const root = path.resolve('.');
  const { errors } = syncAdapters(root, true);
  assert.equal(errors.length, 0, `Expected 0 parity errors, got: ${errors.join(', ')}`);
});

test('syncAdapters copies recursive subfolders and scripts with execution bit', () => {
  const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'sync-test-'));
  const canonicalSkill = path.join(tmp, 'skills', 'custom-skill');
  fs.mkdirSync(path.join(canonicalSkill, 'references', 'subfolder'), { recursive: true });
  fs.mkdirSync(path.join(canonicalSkill, 'scripts', 'nested'), { recursive: true });

  fs.writeFileSync(path.join(canonicalSkill, 'SKILL.md'), '---\nname: custom-skill\n---\n# Skill');
  fs.writeFileSync(path.join(canonicalSkill, 'references', 'subfolder', 'guide.md'), '# Guide');
  const scriptPath = path.join(canonicalSkill, 'scripts', 'nested', 'run.sh');
  fs.writeFileSync(scriptPath, '#!/bin/sh\necho "hello"');
  fs.chmodSync(scriptPath, 0o755);

  // Sync to targets
  const { errors, synced } = syncAdapters(tmp, { checkOnly: false });
  assert.equal(errors.length, 0, `Sync should have no errors: ${errors.join(', ')}`);
  assert.ok(synced.length >= 6, `Expected at least 6 files synced (3 files * 2 targets), got ${synced.length}`);

  // Verify files exist in both targets (.agents and .claude)
  for (const target of ['.agents', '.claude']) {
    const destSkill = path.join(tmp, target, 'skills', 'custom-skill');
    assert.ok(fs.existsSync(path.join(destSkill, 'SKILL.md')), `SKILL.md missing in ${target}`);
    assert.ok(fs.existsSync(path.join(destSkill, 'references', 'subfolder', 'guide.md')), `subfolder guide missing in ${target}`);
    const destScript = path.join(destSkill, 'scripts', 'nested', 'run.sh');
    assert.ok(fs.existsSync(destScript), `nested run.sh missing in ${target}`);
    const destStat = fs.statSync(destScript);
    assert.ok((destStat.mode & 0o111) !== 0, `Executable bit was not preserved in ${target}`);
  }

  // Parity check passes
  const checkResult = syncAdapters(tmp, { checkOnly: true });
  assert.equal(checkResult.errors.length, 0, `Parity check should pass: ${checkResult.errors.join(', ')}`);

  fs.rmSync(tmp, { recursive: true, force: true });
});

test('syncAdapters --check detects orphan skills and files', () => {
  const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'sync-test-'));
  const canonicalSkill = path.join(tmp, 'skills', 'canonical-skill');
  fs.mkdirSync(canonicalSkill, { recursive: true });
  fs.writeFileSync(path.join(canonicalSkill, 'SKILL.md'), '---\nname: canonical-skill\n---\n');

  // Initial sync
  syncAdapters(tmp, { checkOnly: false });

  // Add orphan skill in .agents/skills
  const orphanSkillDir = path.join(tmp, '.agents', 'skills', 'orphan-skill');
  fs.mkdirSync(orphanSkillDir, { recursive: true });
  fs.writeFileSync(path.join(orphanSkillDir, 'SKILL.md'), 'orphan');

  // Add orphan file inside valid skill in .claude/skills
  const orphanFilePath = path.join(tmp, '.claude', 'skills', 'canonical-skill', 'orphan.txt');
  fs.writeFileSync(orphanFilePath, 'orphan file');

  const { errors, orphans } = syncAdapters(tmp, { checkOnly: true });
  assert.ok(orphans.some(o => o.includes('orphan-skill')), 'Should report orphan skill');
  assert.ok(orphans.some(o => o.includes('orphan.txt')), 'Should report orphan file');
  assert.ok(errors.length >= 2, 'Errors should include all orphans');

  fs.rmSync(tmp, { recursive: true, force: true });
});

test('syncAdapters --prune removes orphans in managed targets and preserves unmanaged directories', () => {
  const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'sync-test-'));
  const canonicalSkill = path.join(tmp, 'skills', 'canonical-skill');
  fs.mkdirSync(canonicalSkill, { recursive: true });
  fs.writeFileSync(path.join(canonicalSkill, 'SKILL.md'), '---\nname: canonical-skill\n---\n');

  // Unmanaged directory outside of .agents/skills and .claude/skills
  const unmanagedDir = path.join(tmp, 'other-dir', 'precious');
  fs.mkdirSync(unmanagedDir, { recursive: true });
  fs.writeFileSync(path.join(unmanagedDir, 'keep.txt'), 'do not touch');

  // Sync initially
  syncAdapters(tmp, { checkOnly: false });

  // Add orphan skill and orphan file in managed targets
  const orphanSkillDir = path.join(tmp, '.agents', 'skills', 'orphan-skill');
  fs.mkdirSync(orphanSkillDir, { recursive: true });
  fs.writeFileSync(path.join(orphanSkillDir, 'SKILL.md'), 'orphan');
  const orphanFile = path.join(tmp, '.claude', 'skills', 'canonical-skill', 'extra.txt');
  fs.writeFileSync(orphanFile, 'extra');

  // Run with prune
  const pruneResult = syncAdapters(tmp, { checkOnly: false, prune: true });
  assert.ok(pruneResult.orphans.length >= 2, 'Should report pruned orphans');
  assert.ok(!fs.existsSync(orphanSkillDir), 'Orphan skill directory should be removed');
  assert.ok(!fs.existsSync(orphanFile), 'Orphan file should be removed');

  // Ensure unmanaged directory is untouched
  assert.ok(fs.existsSync(path.join(unmanagedDir, 'keep.txt')), 'Unmanaged file must never be touched');

  // Check passes after prune
  const checkAfterPrune = syncAdapters(tmp, { checkOnly: true });
  assert.equal(checkAfterPrune.errors.length, 0, `No errors after prune: ${checkAfterPrune.errors.join(', ')}`);

  fs.rmSync(tmp, { recursive: true, force: true });
});
