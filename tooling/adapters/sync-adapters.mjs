#!/usr/bin/env node

import fs from 'node:fs';
import path from 'node:path';
import process from 'node:process';
import crypto from 'node:crypto';
import { fileURLToPath } from 'node:url';

const IGNORED_TOP_LEVEL = new Set(['contract.yaml', 'evals', 'fixtures', '.DS_Store']);

function normalizeText(content) {
  return content.replace(/\r\n/g, '\n').trim();
}

function getFileHash(filePath) {
  const content = fs.readFileSync(filePath);
  return crypto.createHash('sha256').update(content).digest('hex');
}

function isContentEqual(srcPath, destPath) {
  try {
    const srcBuf = fs.readFileSync(srcPath);
    const destBuf = fs.readFileSync(destPath);
    if (srcBuf.equals(destBuf)) return true;
    // For text files, fallback to normalized comparison
    const srcText = srcBuf.toString('utf8');
    const destText = destBuf.toString('utf8');
    return normalizeText(srcText) === normalizeText(destText);
  } catch {
    return false;
  }
}

function getCanonicalSkillFiles(skillPath) {
  const files = new Map();
  function walk(currentDir, relPrefix) {
    if (!fs.existsSync(currentDir)) return;
    for (const entry of fs.readdirSync(currentDir, { withFileTypes: true })) {
      if (entry.name === '.DS_Store') continue;
      if (relPrefix === '' && IGNORED_TOP_LEVEL.has(entry.name)) continue;
      const relPath = relPrefix ? path.join(relPrefix, entry.name) : entry.name;
      const fullPath = path.join(currentDir, entry.name);
      if (entry.isDirectory()) {
        walk(fullPath, relPath);
      } else if (entry.isFile()) {
        files.set(relPath, fullPath);
      }
    }
  }
  walk(skillPath, '');
  return files;
}

function getTargetSkillFiles(targetSkillPath) {
  const files = new Map();
  function walk(currentDir, relPrefix) {
    if (!fs.existsSync(currentDir)) return;
    for (const entry of fs.readdirSync(currentDir, { withFileTypes: true })) {
      if (entry.name === '.DS_Store') continue;
      const relPath = relPrefix ? path.join(relPrefix, entry.name) : entry.name;
      const fullPath = path.join(currentDir, entry.name);
      if (entry.isDirectory()) {
        walk(fullPath, relPath);
      } else if (entry.isFile()) {
        files.set(relPath, fullPath);
      }
    }
  }
  walk(targetSkillPath, '');
  return files;
}

function removeEmptyDirs(dir) {
  if (!fs.existsSync(dir)) return;
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    if (entry.isDirectory()) {
      const sub = path.join(dir, entry.name);
      removeEmptyDirs(sub);
      try {
        if (fs.readdirSync(sub).length === 0) {
          fs.rmdirSync(sub);
        }
      } catch {
        // ignore
      }
    }
  }
}

export function syncAdapters(repositoryRoot, options = false) {
  const checkOnly = typeof options === 'boolean' ? options : !!options?.checkOnly;
  const prune = typeof options === 'object' && options !== null ? !!options.prune : false;

  const root = path.resolve(repositoryRoot);
  const skillsSource = path.join(root, 'skills');
  const agentsTarget = path.join(root, '.agents', 'skills');
  const claudeTarget = path.join(root, '.claude', 'skills');

  const targets = [
    { name: '.agents/skills', root: agentsTarget },
    { name: '.claude/skills', root: claudeTarget }
  ];

  const missing = [];
  const divergent = [];
  const orphans = [];
  const synced = [];

  if (!fs.existsSync(skillsSource)) {
    return {
      errors: ['Diretório canônico skills/ não encontrado.'],
      missing: [],
      divergent: [],
      orphans: [],
      synced: []
    };
  }

  // Coletar skills canônicas
  const canonicalSkills = new Map();
  const skillDirs = fs.readdirSync(skillsSource, { withFileTypes: true })
    .filter((entry) => entry.isDirectory())
    .map((entry) => entry.name)
    .sort();

  for (const skill of skillDirs) {
    const skillPath = path.join(skillsSource, skill);
    const files = getCanonicalSkillFiles(skillPath);
    if (files.has('SKILL.md')) {
      canonicalSkills.set(skill, files);
    }
  }

  for (const target of targets) {
    // 1. Detectar skills e arquivos órfãos nos targets gerenciados
    if (fs.existsSync(target.root)) {
      const targetSkillDirs = fs.readdirSync(target.root, { withFileTypes: true })
        .filter((entry) => entry.isDirectory())
        .map((entry) => entry.name);

      for (const tSkill of targetSkillDirs) {
        const targetSkillPath = path.join(target.root, tSkill);

        if (!canonicalSkills.has(tSkill)) {
          // Skill órfã
          orphans.push(`${target.name}/${tSkill}: skill órfã (não existe na fonte canônica).`);
          if (prune) {
            fs.rmSync(targetSkillPath, { recursive: true, force: true });
          }
        } else {
          // Arquivos órfãos dentro de skill existente
          const canonicalFiles = canonicalSkills.get(tSkill);
          const targetFiles = getTargetSkillFiles(targetSkillPath);

          for (const [relFile, targetFilePath] of targetFiles.entries()) {
            if (!canonicalFiles.has(relFile)) {
              orphans.push(`${target.name}/${tSkill}/${relFile}: arquivo órfão.`);
              if (prune) {
                fs.unlinkSync(targetFilePath);
              }
            }
          }

          if (prune) {
            removeEmptyDirs(targetSkillPath);
          }
        }
      }
    }

    // 2. Verificar arquivos ausentes, divergentes e sincronizar
    for (const [skill, canonicalFiles] of canonicalSkills.entries()) {
      for (const [relPath, srcPath] of canonicalFiles.entries()) {
        const destPath = path.join(target.root, skill, relPath);
        const destDir = path.dirname(destPath);

        if (!fs.existsSync(destPath)) {
          if (checkOnly) {
            missing.push(`${target.name}/${skill}/${relPath}: arquivo ausente.`);
          } else {
            fs.mkdirSync(destDir, { recursive: true });
            const content = fs.readFileSync(srcPath);
            fs.writeFileSync(destPath, content);
            const stat = fs.statSync(srcPath);
            if ((stat.mode & 0o111) !== 0) {
              fs.chmodSync(destPath, stat.mode);
            }
            synced.push(`${target.name}/${skill}/${relPath}`);
          }
        } else if (!isContentEqual(srcPath, destPath)) {
          if (checkOnly) {
            divergent.push(`${target.name}/${skill}/${relPath}: diverge da fonte canônica.`);
          } else {
            const content = fs.readFileSync(srcPath);
            fs.writeFileSync(destPath, content);
            const stat = fs.statSync(srcPath);
            if ((stat.mode & 0o111) !== 0) {
              fs.chmodSync(destPath, stat.mode);
            }
            synced.push(`${target.name}/${skill}/${relPath}`);
          }
        }
      }
    }
  }

  const errors = [...missing, ...divergent, ...orphans];
  return { errors, missing, divergent, orphans, synced };
}

function parseArgs(args) {
  const checkOnly = args.includes('--check');
  const prune = args.includes('--prune');
  const rootIndex = args.indexOf('--root');
  const root = rootIndex >= 0 && args[rootIndex + 1]
    ? path.resolve(args[rootIndex + 1])
    : path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
  return { root, checkOnly, prune };
}

function main() {
  const { root, checkOnly, prune } = parseArgs(process.argv.slice(2));
  const { errors, missing, divergent, orphans, synced } = syncAdapters(root, { checkOnly, prune });

  if (checkOnly) {
    if (errors.length > 0) {
      if (missing.length > 0) {
        process.stderr.write(`Arquivos ausentes (${missing.length}):\n`);
        for (const m of missing) process.stderr.write(`  - ${m}\n`);
      }
      if (divergent.length > 0) {
        process.stderr.write(`Arquivos divergentes (${divergent.length}):\n`);
        for (const d of divergent) process.stderr.write(`  - ${d}\n`);
      }
      if (orphans.length > 0) {
        process.stderr.write(`Itens órfãos (${orphans.length}):\n`);
        for (const o of orphans) process.stderr.write(`  - ${o}\n`);
      }
      process.stderr.write(`Sync adapters check failed with ${errors.length} error(s).\n`);
      process.exitCode = 1;
      return;
    }
    process.stdout.write('Sync adapters check passed: all runtime skills are in parity with canonical skills/.\n');
    return;
  }

  if (orphans.length > 0 && !prune) {
    process.stdout.write(`Aviso: ${orphans.length} item(ns) órfão(s) detectado(s). Use --prune para remover.\n`);
  }

  process.stdout.write(`Sync adapters completed: ${synced.length} files synchronized.\n`);
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  main();
}
