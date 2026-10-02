#!/usr/bin/env node
import fs from 'node:fs';
import path from 'node:path';
import process from 'node:process';
import { spawnSync } from 'node:child_process';
import { createInterface } from 'node:readline/promises';
import { fileURLToPath } from 'node:url';
import { validateInstance } from '../contracts/validator.mjs';
import { loadModel, resolveProfiles } from '../scaffold/engine.mjs';
import { parseYamlSubset } from '../scaffold/yaml.mjs';

const PROJECT_ROOTS = ['docs/agents', 'docs/architecture', 'docs/product', 'docs/requirements', 'docs/decisions'];
const LEGACY = new Set(['registry', 'tooling', 'contracts', 'evals', 'skills', '.agents', '.claude']);

function safeRoot(root, candidate, label) {
  const full = path.resolve(candidate);
  if (!path.isAbsolute(full) || full === path.resolve(root)) throw new Error(`${label}: path must be an existing directory different from target`);
  return full;
}

function argsOf(args) {
  const out = {};
  for (let i = 0; i < args.length; i++) {
    const arg = args[i];
    if (arg.startsWith('--')) out[arg.slice(2)] = args[i + 1]?.startsWith('--') ? true : (args[i + 1] ?? true);
  }
  return out;
}

function listFiles(root) {
  const files = [];
  const walk = (dir) => {
    for (const entry of fs.readdirSync(dir, { withFileTypes: true }).sort((a, b) => a.name.localeCompare(b.name))) {
      if (entry.isSymbolicLink()) continue;
      const full = path.join(dir, entry.name);
      if (entry.isDirectory()) walk(full);
      else if (entry.isFile()) files.push(full);
    }
  };
  walk(root);
  return files;
}

function slug(value) {
  return value.normalize('NFD').replace(/[\u0300-\u036f]/g, '').toLowerCase()
    .replace(/[^a-z0-9]+/g, '-').replace(/^-+|-+$/g, '');
}

function quote(value) {
  return JSON.stringify(String(value));
}

export function yamlManifest({ name, type, profiles, agents, owner, questionnaireVersion, completedOn }) {
  const list = (key, items) => items.length ? `${key}:\n${items.map((item) => `  - ${item}`).join('\n')}` : `${key}: []`;
  return `version: 1
project:
  name: ${name}
  type: ${type}
${list('profiles', profiles)}
${list('agents', agents)}
metadata:
  owner: ${quote(owner)}
onboarding:
  status: completed
  questionnaire_version: ${questionnaireVersion}
  completed_on: ${completedOn}
`;
}

function agentsForProfiles(model, selected) {
  const agents = new Set();
  for (const profile of resolveProfiles(model.profiles, selected)) {
    for (const artifact of model.profiles[profile].artifacts ?? []) {
      if (artifact.type === 'agent') agents.add(artifact.name);
    }
  }
  return [...agents];
}

function loadQuestions(root) {
  const file = path.join(root, 'harness', 'onboarding', 'questions.yaml');
  return parseYamlSubset(fs.readFileSync(file, 'utf8'), 'questions.yaml');
}

function loadManifest(root) {
  const file = path.join(root, 'docs', 'project-manifest.yaml');
  if (!fs.existsSync(file)) return null;
  return parseYamlSubset(fs.readFileSync(file, 'utf8'), 'project-manifest.yaml');
}

async function requiredAnswer(ask, definition) {
  while (true) {
    const answer = String(await ask(`${definition.description}\n${definition.label}: `)).trim();
    if (answer) return answer;
    process.stderr.write(`${definition.label} é obrigatório.\n`);
  }
}

async function choiceAnswer(ask, definition) {
  const options = definition.options;
  while (true) {
    const rendered = options.map((item, index) => `${index + 1}) ${item}`).join('  ');
    const answer = String(await ask(`${definition.description}\n${definition.label}\n${rendered}\nEscolha: `)).trim();
    const index = Number(answer) - 1;
    if (Number.isInteger(index) && options[index]) return options[index];
    if (options.includes(answer)) return answer;
    process.stderr.write('Selecione uma das opções listadas.\n');
  }
}

async function multiChoiceAnswer(ask, definition) {
  const options = definition.options;
  while (true) {
    const rendered = options.map((item, index) => {
      const description = definition.option_descriptions?.[item];
      return `${index + 1}) ${item}${description ? ` — ${description}` : ''}`;
    }).join('\n');
    const answer = String(await ask(`${definition.description}\n${definition.label}\n${rendered}\nEscolhas (separadas por vírgula): `)).trim();
    const selected = answer.split(',').map((item) => item.trim()).filter(Boolean).map((item) => {
      const index = Number(item) - 1;
      return Number.isInteger(index) && options[index] ? options[index] : item;
    });
    if (selected.length && selected.every((item) => options.includes(item))) return [...new Set(selected)];
    process.stderr.write('Selecione uma ou mais opções listadas.\n');
  }
}

async function confirmAnswer(ask, definition) {
  while (true) {
    const answer = String(await ask(`${definition.description}\n${definition.label} [s/N]: `)).trim().toLowerCase();
    if (['y', 'yes', 's', 'sim'].includes(answer)) return true;
    if (['', 'n', 'no', 'nao', 'não'].includes(answer)) return false;
    process.stderr.write('Responda sim ou não.\n');
  }
}

export async function runQuiz(root, model, { ask, write, completedOn }) {
  const questionnaire = loadQuestions(root);
  const questions = questionnaire.questions;
  const readableName = await requiredAnswer(ask, questions['project-name']);
  const name = slug(readableName);
  if (!name) throw new Error('O nome do projeto deve conter letras ou números.');
  const type = await choiceAnswer(ask, questions['project-type']);
  const owner = await requiredAnswer(ask, questions['project-owner']);
  const profiles = await multiChoiceAnswer(ask, questions['project-profiles']);
  if (profiles.some((profile) => !Object.hasOwn(model.profiles, profile))) throw new Error('O quiz referencia um profile desconhecido no Registry.');
  const agents = agentsForProfiles(model, profiles);
  const content = yamlManifest({ name, type, profiles, agents, owner, questionnaireVersion: questionnaire.version, completedOn });
  write(`\nPrévia do manifesto:\n\n${content}\n`);
  const confirmed = await confirmAnswer(ask, questions['confirm-manifest']);
  return confirmed ? content : null;
}

export function classifySource(source, target) {
  const result = [];
  for (const full of listFiles(source)) {
    const rel = path.relative(source, full).replaceAll('\\', '/');
    const top = rel.split('/')[0];
    let classification = 'PROJECT_OTHER_DOC', action = 'REPORT', reason = 'unknown root artifact';
    if (rel === '.git' || rel.startsWith('.git/')) { classification = 'IGNORED'; action = 'SKIP'; reason = 'neverCopy policy'; }
    else if (LEGACY.has(top) || top === 'harness') { classification = 'LEGACY_HARNESS'; action = 'SKIP'; reason = 'current harness is authoritative'; }
    else if (['node_modules', 'target', 'build', 'dist', 'coverage', '.idea', '.vscode'].includes(top) || rel.endsWith('.log')) { classification = 'BUILD_ARTIFACT'; action = 'SKIP'; reason = 'neverCopy policy'; }
    else if (PROJECT_ROOTS.some((projectRoot) => rel === projectRoot || rel.startsWith(`${projectRoot}/`))) {
      classification = rel.startsWith('docs/agents/standards/') ? 'PROJECT_STANDARD' : rel.startsWith('docs/agents/') ? 'PROJECT_AGENT' : rel.startsWith('docs/architecture/') ? 'PROJECT_ARCHITECTURE' : rel.startsWith('docs/product/') ? 'PROJECT_PRODUCT' : rel.startsWith('docs/requirements/') ? 'PROJECT_REQUIREMENT' : rel.startsWith('docs/decisions/') ? 'PROJECT_DECISION' : 'PROJECT_OTHER_DOC';
      action = 'COPY';
      reason = 'project-owned artifact preserved by migration policy';
    }
    result.push({ source: rel, classification, action, target: action === 'COPY' ? rel : 'none', reason });
  }
  return result;
}

function requireConfirm(opts) {
  return opts.yes === true || opts.yes === 'true';
}

function importLegacy(root, source, opts) {
  const sourceRoot = safeRoot(root, source, 'source');
  if (!fs.existsSync(sourceRoot) || !fs.statSync(sourceRoot).isDirectory()) throw new Error('source: directory not found');
  if (sourceRoot === path.resolve(root)) throw new Error('source must differ from target');
  const status = spawnSync('git', ['status', '--porcelain'], { cwd: root, encoding: 'utf8' });
  if (status.status !== 0 || status.stdout.trim()) throw new Error('Target working tree is not clean. Commit or stash changes before onboarding a legacy project.');
  const decisions = classifySource(sourceRoot, root);
  const conflicts = decisions.filter((decision) => decision.action === 'COPY' && fs.existsSync(path.join(root, decision.target)));
  if (conflicts.length) {
    for (const decision of conflicts) console.log(`CONFLICT ${decision.target}`);
    throw new Error('target conflict; overwrite is forbidden');
  }
  for (const decision of decisions) console.log(`SOURCE: ${decision.source}\nCLASSIFICATION: ${decision.classification}\nACTION: ${decision.action}\nTARGET: ${decision.target}\nREASON: ${decision.reason}\n`);
  const copies = decisions.filter((decision) => decision.action === 'COPY');
  if (!requireConfirm(opts)) return 2;
  for (const decision of copies) {
    const from = path.join(sourceRoot, decision.source), to = path.join(root, decision.target);
    fs.mkdirSync(path.dirname(to), { recursive: true });
    fs.copyFileSync(from, to, fs.constants.COPYFILE_EXCL);
  }
  return 0;
}

export async function main(args = process.argv.slice(2), root = path.resolve('.'), dependencies = {}) {
  const opts = argsOf(args);
  if (opts.source) return importLegacy(root, opts.source, opts);

  const schema = JSON.parse(fs.readFileSync(path.join(root, 'harness', 'contracts', 'project-manifest.schema.json'), 'utf8'));
  const existing = loadManifest(root);
  if (existing) {
    const validation = validateInstance(schema, existing);
    if (!validation.valid) {
      console.error(`BLOCKED manifesto existente inválido: ${validation.errors.join('; ')}`);
      return 2;
    }
    const state = existing.onboarding?.status === 'completed' ? 'completed' : 'legacy-manifest';
    (dependencies.write ?? console.log)(`Onboarding já concluído (${state}); quiz não repetido.`);
    return 0;
  }

  let model;
  try {
    model = loadModel(root);
  } catch (error) {
    console.error(`BLOCKED ${error.message}`);
    return 2;
  }

  const ownInterface = dependencies.ask ? null : createInterface({ input: process.stdin, output: process.stdout });
  const ask = dependencies.ask ?? ((prompt) => ownInterface.question(prompt));
  const write = dependencies.write ?? console.log;
  const completedOn = dependencies.completedOn ?? new Date().toISOString().slice(0, 10);

  try {
    const content = await runQuiz(root, model, { ask, write, completedOn });
    if (!content) {
      write('Onboarding cancelado; nenhum arquivo foi alterado.');
      return 2;
    }
    const parsed = parseYamlSubset(content, 'generated project manifest');
    const validation = validateInstance(schema, parsed);
    if (!validation.valid) {
      console.error(`BLOCKED manifesto inválido: ${validation.errors.join('; ')}`);
      return 2;
    }
    const manifest = path.join(root, 'docs', 'project-manifest.yaml');
    fs.mkdirSync(path.dirname(manifest), { recursive: true });
    fs.writeFileSync(manifest, content, { flag: 'wx' });
    write('Onboarding concluído. Manifesto criado em docs/project-manifest.yaml.');
    write('Próximo passo: revise com scaffold --check e crie os documentos ausentes com scaffold --create.');
    return 0;
  } catch (error) {
    console.error(`BLOCKED ${error.message}`);
    return 2;
  } finally {
    ownInterface?.close();
  }
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  process.exitCode = await main();
}
