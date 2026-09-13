#!/usr/bin/env node

import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const MAX_LINES = 500;
const MAX_BYTES = 64 * 1024;
const REVIEW_TITLE = 'Granularity / Decomposition Review';
const REVIEW_HEADING = new RegExp(`^##\\s+${REVIEW_TITLE.replace('/', '\\/')}\\s*$`, 'im');
const OUTCOMES = new Set(['Decomposed', 'Semantically indivisible']);
const CHILD_ID = /\b(?:TP-\d{5}(?:-[A-Z0-9]+)?|IP-[A-Z]+-\d+(?:\.\d+){2,3}(?:-[a-z0-9]+(?:-[a-z0-9]+)*)?)\b/g;

function normalize(value) {
  return value.split(path.sep).join('/');
}

function insideRoot(root, candidate) {
  const relative = path.relative(root, candidate);
  return relative !== '..' && !relative.startsWith(`..${path.sep}`) && !path.isAbsolute(relative);
}

function planKind(relativePath) {
  if (/^docs\/task_plans\/TP-\d{5}-.+\.md$/.test(relativePath)) return 'TP';
  if (/^docs\/task_plans\/implementation_plans\/(?:[^/]+\/)?IP-[A-Z]+-.+\.md$/.test(relativePath)) return 'IP';
  return null;
}

function field(section, name) {
  const match = new RegExp(`^\\s*-?\\s*\\*\\*${name}:\\*\\*\\s*(.+?)\\s*$`, 'im').exec(section);
  return match?.[1]?.replace(/^`|`$/g, '').trim() ?? null;
}

function reviewSection(content) {
  const heading = REVIEW_HEADING.exec(content);
  if (!heading) return null;
  const start = heading.index + heading[0].length;
  const remainder = content.slice(start);
  const nextHeading = /^##\s+/m.exec(remainder);
  return nextHeading ? remainder.slice(0, nextHeading.index) : remainder;
}

function meaningfulRationale(value) {
  if (!value || value.length < 20) return false;
  return !/(?:\bTBD\b|\bTODO\b|placeholder|<[^>]+>)/i.test(value);
}

export function analyzePlan(relativePath, content, limits = {}) {
  const maxLines = limits.maxLines ?? MAX_LINES;
  const maxBytes = limits.maxBytes ?? MAX_BYTES;
  const rawLines = content.split(/\r?\n/);
  if (rawLines.at(-1) === '') rawLines.pop();
  const lines = rawLines.length;
  const bytes = Buffer.byteLength(content, 'utf8');
  const reviewRequired = lines > maxLines || bytes > maxBytes;
  const violations = [];
  let review = null;

  if (reviewRequired) {
    const section = reviewSection(content);
    if (!section) {
      violations.push({ rule: 'plan-granularity-review', actual: 'missing', limit: 'structured review required' });
    } else {
      const outcome = field(section, 'Outcome');
      const rationale = field(section, 'Rationale');
      const reviewedOn = field(section, 'Reviewed on');
      const childrenValue = field(section, 'Children');
      const children = [...new Set(section.match(CHILD_ID) ?? [])];
      review = { outcome, rationale, reviewedOn, children };

      if (!OUTCOMES.has(outcome)) {
        violations.push({ rule: 'plan-granularity-outcome', actual: outcome, limit: [...OUTCOMES] });
      }
      if (!meaningfulRationale(rationale)) {
        violations.push({ rule: 'plan-granularity-rationale', actual: rationale, limit: 'at least 20 non-placeholder characters' });
      }
      if (!/^\d{4}-\d{2}-\d{2}$/.test(reviewedOn ?? '')) {
        violations.push({ rule: 'plan-granularity-date', actual: reviewedOn, limit: 'YYYY-MM-DD' });
      }
      if (outcome === 'Decomposed' && children.length < 2) {
        violations.push({ rule: 'plan-granularity-children', actual: children, limit: 'at least two child TP/IP IDs' });
      }
      if (outcome === 'Semantically indivisible' && (!childrenValue || !/^N\/A\b/i.test(childrenValue))) {
        violations.push({ rule: 'plan-granularity-children', actual: childrenValue, limit: 'N/A for a semantically indivisible plan' });
      }
    }
  }

  return { path: relativePath, kind: planKind(relativePath), lines, bytes, maxLines, maxBytes, reviewRequired, review, violations };
}

function parseArguments(argv) {
  const options = { root: process.cwd(), targets: [], json: false };
  for (let index = 0; index < argv.length; index += 1) {
    const argument = argv[index];
    if (argument === '--json') options.json = true;
    else if (argument === '--root' || argument === '--target') {
      const value = argv[index + 1];
      if (!value) throw new Error(`${argument} requires a value`);
      index += 1;
      if (argument === '--target') options.targets.push(value);
      else options.root = value;
    } else if (argument === '--help' || argument === '-h') options.help = true;
    else throw new Error(`unknown argument: ${argument}`);
  }
  return options;
}

function usage() {
  return 'Usage: validate-plan-granularity.mjs --target <TP-or-IP-path> [--target <path> ...] [--json]';
}

export function evaluate(options) {
  const root = path.resolve(options.root);
  if (!fs.statSync(root, { throwIfNoEntry: false })?.isDirectory()) throw new Error(`--root is not a directory: ${root}`);
  if (options.targets.length === 0) throw new Error('at least one --target is required');
  const blocked = [];
  const violations = [];
  const plans = [];
  const skipped = [];

  for (const target of options.targets) {
    const absolute = path.resolve(root, target);
    const relative = normalize(path.relative(root, absolute));
    if (!insideRoot(root, absolute)) {
      blocked.push(`target outside repository: ${target}`);
      continue;
    }
    const stats = fs.statSync(absolute, { throwIfNoEntry: false });
    if (!stats?.isFile()) {
      blocked.push(`target missing or not a file: ${target}`);
      continue;
    }
    const kind = planKind(relative);
    if (!kind) {
      skipped.push(relative);
      continue;
    }
    const analysis = analyzePlan(relative, fs.readFileSync(absolute, 'utf8'));
    plans.push(analysis);
    violations.push(...analysis.violations.map((item) => ({ ...item, path: relative })));
  }

  const status = blocked.length > 0 ? 'BLOCKED' : violations.length > 0 ? 'FAIL' : 'PASS';
  return { status, plans, skipped, violations, blocked };
}

function printHuman(result) {
  console.log('PLAN_GRANULARITY_START');
  for (const plan of result.plans) {
    console.log(`PLAN_GRANULARITY_METRIC file=${plan.path} kind=${plan.kind} lines=${plan.lines} bytes=${plan.bytes} review_required=${plan.reviewRequired}`);
  }
  for (const violation of result.violations) console.error(`PLAN_GRANULARITY_VIOLATION ${JSON.stringify(violation)}`);
  for (const reason of result.blocked) console.error(`PLAN_GRANULARITY_BLOCKED ${reason}`);
  console.log(`PLAN_GRANULARITY_RESULT=${result.status} violations=${result.violations.length} blocked=${result.blocked.length}`);
  console.log(`PLAN_GRANULARITY_JSON=${JSON.stringify(result)}`);
}

export function main(argv = process.argv.slice(2)) {
  try {
    const options = parseArguments(argv);
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
