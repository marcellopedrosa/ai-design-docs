#!/usr/bin/env node

import fs from 'node:fs';
import path from 'node:path';
import process from 'node:process';
import { fileURLToPath } from 'node:url';

function normalizeText(content) {
  return content.replace(/\r\n/g, '\n').trim();
}

export function syncAdapters(repositoryRoot, checkOnly = false) {
  const root = path.resolve(repositoryRoot);
  const skillsSource = path.join(root, 'skills');
  const agentsTarget = path.join(root, '.agents', 'skills');
  const claudeTarget = path.join(root, '.claude', 'skills');

  const targets = [
    { name: '.agents/skills', root: agentsTarget },
    { name: '.claude/skills', root: claudeTarget }
  ];

  const errors = [];
  const synced = [];

  if (!fs.existsSync(skillsSource)) {
    return { errors: ['Diretório canônico skills/ não encontrado.'], synced: [] };
  }

  const skillDirs = fs.readdirSync(skillsSource, { withFileTypes: true })
    .filter((entry) => entry.isDirectory())
    .map((entry) => entry.name)
    .sort();

  for (const skill of skillDirs) {
    const canonicalSkillPath = path.join(skillsSource, skill, 'SKILL.md');
    if (!fs.existsSync(canonicalSkillPath)) continue;

    const canonicalContent = fs.readFileSync(canonicalSkillPath, 'utf8');

    for (const target of targets) {
      const destDir = path.join(target.root, skill);
      const destSkillPath = path.join(destDir, 'SKILL.md');

      if (checkOnly) {
        if (!fs.existsSync(destSkillPath)) {
          errors.push(`${target.name}/${skill}/SKILL.md: arquivo ausente.`);
        } else {
          const currentContent = fs.readFileSync(destSkillPath, 'utf8');
          if (normalizeText(canonicalContent) !== normalizeText(currentContent)) {
            errors.push(`${target.name}/${skill}/SKILL.md: diverge da fonte canônica skills/${skill}/SKILL.md.`);
          }
        }
      } else {
        if (!fs.existsSync(destDir)) {
          fs.mkdirSync(destDir, { recursive: true });
        }
        fs.writeFileSync(destSkillPath, canonicalContent, 'utf8');
        synced.push(`${target.name}/${skill}/SKILL.md`);
      }
    }

    // Copiar diretório references se existir
    const canonicalRefsDir = path.join(skillsSource, skill, 'references');
    if (fs.existsSync(canonicalRefsDir)) {
      const refFiles = fs.readdirSync(canonicalRefsDir, { withFileTypes: true })
        .filter((entry) => entry.isFile())
        .map((entry) => entry.name);

      for (const refFile of refFiles) {
        const canonicalRefPath = path.join(canonicalRefsDir, refFile);
        const refContent = fs.readFileSync(canonicalRefPath, 'utf8');

        for (const target of targets) {
          const destRefDir = path.join(target.root, skill, 'references');
          const destRefPath = path.join(destRefDir, refFile);

          if (checkOnly) {
            if (!fs.existsSync(destRefPath)) {
              errors.push(`${target.name}/${skill}/references/${refFile}: arquivo ausente.`);
            } else {
              const currentRefContent = fs.readFileSync(destRefPath, 'utf8');
              if (normalizeText(refContent) !== normalizeText(currentRefContent)) {
                errors.push(`${target.name}/${skill}/references/${refFile}: diverge da fonte canônica.`);
              }
            }
          } else {
            if (!fs.existsSync(destRefDir)) {
              fs.mkdirSync(destRefDir, { recursive: true });
            }
            fs.writeFileSync(destRefPath, refContent, 'utf8');
            synced.push(`${target.name}/${skill}/references/${refFile}`);
          }
        }
      }
    }
  }

  return { errors, synced };
}

function parseArgs(args) {
  const checkOnly = args.includes('--check');
  const rootIndex = args.indexOf('--root');
  const root = rootIndex >= 0 && args[rootIndex + 1]
    ? path.resolve(args[rootIndex + 1])
    : path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
  return { root, checkOnly };
}

function main() {
  const { root, checkOnly } = parseArgs(process.argv.slice(2));
  const { errors, synced } = syncAdapters(root, checkOnly);

  if (errors.length > 0) {
    for (const error of errors) process.stderr.write(`ERROR: ${error}\n`);
    process.stderr.write(`Sync adapters check failed with ${errors.length} error(s).\n`);
    process.exitCode = 1;
    return;
  }

  if (checkOnly) {
    process.stdout.write('Sync adapters check passed: all runtime skills are in parity with canonical skills/.\n');
  } else {
    process.stdout.write(`Sync adapters completed: ${synced.length} files synchronized.\n`);
  }
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  main();
}
