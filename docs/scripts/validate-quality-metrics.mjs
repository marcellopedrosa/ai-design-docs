#!/usr/bin/env node

import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const SOURCE_EXTENSIONS = new Set(['.java', '.js', '.jsx', '.ts', '.tsx', '.mjs', '.cjs', '.sh', '.py']);
const HASH_COMMENT_EXTENSIONS = new Set(['.sh', '.py']);
const BRANCH_PATTERN = /^[0-9]+\.[0-9]+\.[0-9]+-(docs|feat|fix)-[a-z0-9]+(?:-[a-z0-9]+)*$/;
const PROTECTED_BRANCHES = /^(main|master|develop|release(?:\/|$))/;
const TRACEABLE_COMMENT = /(?:[A-Z][A-Z0-9]+-\d+|#\d+|https?:\/\/\S+)/;

const PROFILES = {
  backend: {
    format: 'jacoco',
    reports: ['backend/target/site/jacoco/jacoco.xml', 'backend/target/jacoco.xml'],
    thresholds: { instructions: 80, branches: 70 },
  },
  frontend: {
    format: 'lcov',
    reports: ['frontend/coverage/lcov.info'],
    thresholds: { lines: 70, branches: 70, functions: 70 },
  },
  website: {
    format: 'lcov',
    reports: ['website/coverage/lcov.info'],
    thresholds: { lines: 70, branches: 70, functions: 70 },
  },
  docs: { format: null, reports: [], thresholds: {} },
  infra: { format: null, reports: [], thresholds: {} },
};

function percentage(covered, total) {
  return total === 0 ? 100 : Number(((covered / total) * 100).toFixed(2));
}

export function parseJacoco(xml) {
  const counters = {};
  const pattern = /<counter\s+type="([A-Z]+)"\s+missed="(\d+)"\s+covered="(\d+)"\s*\/>/g;
  for (const match of xml.matchAll(pattern)) {
    counters[match[1]] = { missed: Number(match[2]), covered: Number(match[3]) };
  }
  if (!counters.INSTRUCTION || !counters.BRANCH) {
    throw new Error('JaCoCo report omits INSTRUCTION or BRANCH counters');
  }
  const result = {};
  const names = { INSTRUCTION: 'instructions', BRANCH: 'branches' };
  for (const [name, counter] of Object.entries(counters)) {
    result[names[name] ?? name.toLowerCase()] = percentage(counter.covered, counter.covered + counter.missed);
  }
  return result;
}

export function parseLcov(lcov) {
  const totals = { LF: 0, LH: 0, BRF: 0, BRH: 0, FNF: 0, FNH: 0 };
  let records = 0;
  for (const line of lcov.split(/\r?\n/)) {
    if (line === 'end_of_record') records += 1;
    const match = /^(LF|LH|BRF|BRH|FNF|FNH):(\d+)$/.exec(line);
    if (match) totals[match[1]] += Number(match[2]);
  }
  if (records === 0 || totals.LF === 0) throw new Error('LCOV report has no executable line record');
  return {
    lines: percentage(totals.LH, totals.LF),
    branches: percentage(totals.BRH, totals.BRF),
    functions: percentage(totals.FNH, totals.FNF),
  };
}

function markerOutsideQuotes(line, marker, requireBoundary = false) {
  let quote = null;
  let escaped = false;
  for (let index = 0; index <= line.length - marker.length; index += 1) {
    const character = line[index];
    if (escaped) {
      escaped = false;
      continue;
    }
    if (character === '\\') {
      escaped = true;
      continue;
    }
    if (quote) {
      if (character === quote) quote = null;
      continue;
    }
    if (character === '"' || character === "'" || character === '`') {
      quote = character;
      continue;
    }
    if (line.startsWith(marker, index) && (!requireBoundary || index === 0 || /\s/.test(line[index - 1]))) return index;
  }
  return -1;
}

function commentFragment(line, state, extension) {
  if (HASH_COMMENT_EXTENSIONS.has(extension)) {
    const index = markerOutsideQuotes(line, '#', true);
    if (index >= 0 && !line.startsWith('#!')) return { text: line.slice(index + 1), state };
    return { text: null, state };
  }
  if (state.block) {
    const end = line.indexOf('*/');
    return {
      text: end >= 0 ? line.slice(0, end).replace(/^\s*\*?\s?/, '') : line.replace(/^\s*\*?\s?/, ''),
      state: { block: end < 0 },
    };
  }
  const lineIndex = markerOutsideQuotes(line, '//');
  const blockIndex = markerOutsideQuotes(line, '/*');
  if (lineIndex < 0 && blockIndex < 0) return { text: null, state };
  if (lineIndex >= 0 && (blockIndex < 0 || lineIndex < blockIndex)) {
    return { text: line.slice(lineIndex + 2), state };
  }
  const rest = line.slice(blockIndex + 2);
  const end = rest.indexOf('*/');
  return { text: end >= 0 ? rest.slice(0, end) : rest, state: { block: end < 0 } };
}

function resemblesCode(text) {
  const value = text.trim();
  return /(?:;|\{|\})\s*$/.test(value)
    || /(?:=>|===|!==|\bnew\s+[A-Z]\w*\s*\()/.test(value)
    || /^(?:import|export)\s+.+\s+from\s+['"]/.test(value)
    || /^(?:public|private|protected)\s+(?:class|interface|record|enum)\b/.test(value)
    || /^(?:if|for|while|def|class)\b.*:\s*$/.test(value)
    || /^(?:from\s+\S+\s+import|import\s+\S+)/.test(value)
    || /^[A-Za-z_]\w*\s*=\s*[^=]/.test(value);
}

export function analyzeSource(relativePath, content, limits = {}) {
  const maxLines = limits.maxLines ?? 500;
  const maxCommentLength = limits.maxCommentLength ?? 100;
  const maxCommentBlock = limits.maxCommentBlock ?? 12;
  const lines = content.split(/\r?\n/);
  if (lines.at(-1) === '') lines.pop();
  const violations = [];
  if (lines.length > maxLines) {
    violations.push({ rule: 'file-lines', line: null, actual: lines.length, limit: maxLines });
  }
  const extension = path.extname(relativePath);
  let state = { block: false };
  let blockLength = 0;
  let commentLines = 0;
  for (const [index, line] of lines.entries()) {
    const fragment = commentFragment(line, state, extension);
    state = fragment.state;
    if (fragment.text === null) {
      blockLength = 0;
      continue;
    }
    commentLines += 1;
    blockLength += 1;
    const text = fragment.text.trim();
    if (text.length > maxCommentLength) {
      violations.push({ rule: 'comment-length', line: index + 1, actual: text.length, limit: maxCommentLength });
    }
    if (blockLength === maxCommentBlock + 1) {
      violations.push({ rule: 'comment-block', line: index + 1, actual: blockLength, limit: maxCommentBlock });
    }
    if (/\b(?:TODO|FIXME)\b/i.test(text) && !TRACEABLE_COMMENT.test(text)) {
      violations.push({ rule: 'untracked-comment', line: index + 1, actual: text, limit: 'traceable-id' });
    }
    if (resemblesCode(text)) {
      violations.push({ rule: 'commented-code', line: index + 1, actual: text, limit: 0 });
    }
  }
  return {
    path: relativePath,
    lines: lines.length,
    commentLines,
    commentDensity: lines.length === 0 ? 0 : percentage(commentLines, lines.length),
    violations,
  };
}

function parseArguments(argv) {
  const options = { targets: [], root: process.cwd(), coverage: null, branchName: null, delivery: false, json: false };
  for (let index = 0; index < argv.length; index += 1) {
    const argument = argv[index];
    if (argument === '--delivery') options.delivery = true;
    else if (argument === '--json') options.json = true;
    else if (['--scope', '--target', '--root', '--coverage', '--branch-name'].includes(argument)) {
      const value = argv[index + 1];
      if (!value) throw new Error(`${argument} requires a value`);
      index += 1;
      if (argument === '--target') options.targets.push(value);
      else options[{ '--scope': 'scope', '--root': 'root', '--coverage': 'coverage', '--branch-name': 'branchName' }[argument]] = value;
    } else if (argument === '--help' || argument === '-h') options.help = true;
    else throw new Error(`unknown argument: ${argument}`);
  }
  return options;
}

function usage() {
  return `Usage: validate-quality-metrics.mjs --scope <docs|backend|frontend|website|infra> --target <path> [--target <path> ...] [--coverage <path>] [--delivery --branch-name <name>] [--json]`;
}

function insideRoot(root, candidate) {
  const relative = path.relative(root, candidate);
  return relative !== '..' && !relative.startsWith(`..${path.sep}`) && !path.isAbsolute(relative);
}

function evaluateCoverage(root, profile, override, blocked, violations) {
  if (!profile.format) return null;
  const candidates = override ? [override] : profile.reports;
  const selected = candidates.map((item) => path.resolve(root, item)).find((item) => fs.existsSync(item));
  if (!selected || !insideRoot(root, selected)) {
    blocked.push(`coverage report missing inside repository: ${candidates.join(', ')}`);
    return null;
  }
  try {
    const content = fs.readFileSync(selected, 'utf8');
    const metrics = profile.format === 'jacoco' ? parseJacoco(content) : parseLcov(content);
    for (const [metric, limit] of Object.entries(profile.thresholds)) {
      if (!(metric in metrics)) blocked.push(`coverage metric missing: ${metric}`);
      else if (metrics[metric] < limit) violations.push({ rule: `coverage-${metric}`, actual: metrics[metric], limit });
    }
    return { report: path.relative(root, selected), metrics, thresholds: profile.thresholds };
  } catch (error) {
    blocked.push(`invalid coverage report: ${error.message}`);
    return null;
  }
}

export function evaluate(options) {
  const root = path.resolve(options.root);
  const profile = PROFILES[options.scope];
  if (!profile) throw new Error(`invalid or missing --scope: ${options.scope ?? ''}`);
  if (!fs.statSync(root, { throwIfNoEntry: false })?.isDirectory()) throw new Error(`--root is not a directory: ${root}`);
  if (options.targets.length === 0) throw new Error('at least one --target is required');
  const blocked = [];
  const violations = [];
  const files = [];
  if (options.delivery) {
    if (!options.branchName) blocked.push('--branch-name is required with --delivery');
    else if (!BRANCH_PATTERN.test(options.branchName) || PROTECTED_BRANCHES.test(options.branchName)) {
      violations.push({ rule: 'branch-name', actual: options.branchName, limit: 'X.Y.Z-{docs,feat,fix}-short-description' });
    }
  } else if (options.branchName) throw new Error('--branch-name requires --delivery');
  for (const target of options.targets) {
    const absolute = path.resolve(root, target);
    const relative = path.relative(root, absolute).split(path.sep).join('/');
    if (!insideRoot(root, absolute) || !(relative === options.scope || relative.startsWith(`${options.scope}/`))) {
      blocked.push(`target outside selected scope: ${target}`);
      continue;
    }
    const stats = fs.statSync(absolute, { throwIfNoEntry: false });
    if (!stats?.isFile()) {
      blocked.push(`target missing or not a file: ${target}`);
      continue;
    }
    if (!SOURCE_EXTENSIONS.has(path.extname(relative))) continue;
    const analysis = analyzeSource(relative, fs.readFileSync(absolute, 'utf8'));
    files.push(analysis);
    violations.push(...analysis.violations.map((item) => ({ ...item, path: relative })));
  }
  const coverage = evaluateCoverage(root, profile, options.coverage, blocked, violations);
  const status = blocked.length > 0 ? 'BLOCKED' : violations.length > 0 ? 'FAIL' : 'PASS';
  return { status, scope: options.scope, coverage, files, violations, blocked };
}

function printHuman(result) {
  console.log(`QUALITY_METRICS_START scope=${result.scope}`);
  if (result.coverage) {
    for (const [name, value] of Object.entries(result.coverage.metrics)) {
      const threshold = result.coverage.thresholds[name];
      if (threshold !== undefined) console.log(`QUALITY_METRIC coverage.${name}=${value} threshold=${threshold}`);
    }
  }
  for (const file of result.files) {
    console.log(`QUALITY_METRIC file=${file.path} lines=${file.lines} comment_lines=${file.commentLines} comment_density=${file.commentDensity}`);
  }
  for (const violation of result.violations) console.error(`QUALITY_METRICS_VIOLATION ${JSON.stringify(violation)}`);
  for (const reason of result.blocked) console.error(`QUALITY_METRICS_BLOCKED ${reason}`);
  console.log(`QUALITY_METRICS_RESULT=${result.status} violations=${result.violations.length} blocked=${result.blocked.length}`);
  console.log(`QUALITY_METRICS_JSON=${JSON.stringify(result)}`);
}

export function main(argv = process.argv.slice(2)) {
  let options;
  try {
    options = parseArguments(argv);
    if (options.help) {
      console.log(usage());
      return 0;
    }
    const result = evaluate(options);
    if (options.json) console.log(JSON.stringify(result, null, 2));
    else printHuman(result);
    return result.status === 'PASS' ? 0 : 1;
  } catch (error) {
    console.error(`ERROR: ${error.message}`);
    console.error(usage());
    return 2;
  }
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  process.exitCode = main();
}
