#!/usr/bin/env node

import fs from 'node:fs';
import path from 'node:path';
import process from 'node:process';
import { fileURLToPath } from 'node:url';

const HTTP_MAPPINGS = new Map([
  ['GetMapping', 'get'],
  ['PostMapping', 'post'],
  ['PutMapping', 'put'],
  ['PatchMapping', 'patch'],
  ['DeleteMapping', 'delete']
]);
const LEGACY_STATUS_FROM_INDEX = new Set([
  'conversation-audit-v1.openapi.yaml',
  'conversation-audit-retention-policy-v1.openapi.yaml'
]);
function listFiles(root, suffix) {
  if (!fs.existsSync(root)) return [];
  const result = [];
  const visit = (directory) => {
    for (const entry of fs.readdirSync(directory, { withFileTypes: true })) {
      const target = path.join(directory, entry.name);
      if (entry.isDirectory()) visit(target);
      else if (entry.isFile() && entry.name.endsWith(suffix)) result.push(target);
    }
  };
  visit(root);
  return result.sort();
}

function maskJavaComments(source) {
  const chars = [...source];
  let state = 'code';
  let quote = '';
  for (let index = 0; index < chars.length; index += 1) {
    const current = chars[index];
    const next = chars[index + 1];
    if (state === 'line') {
      if (current === '\n') state = 'code';
      else chars[index] = ' ';
      continue;
    }
    if (state === 'block') {
      if (current === '*' && next === '/') {
        chars[index] = ' ';
        chars[index + 1] = ' ';
        index += 1;
        state = 'code';
      } else if (current !== '\n') chars[index] = ' ';
      continue;
    }
    if (state === 'string') {
      if (current === '\\') index += 1;
      else if (current === quote) state = 'code';
      continue;
    }
    if (current === '/' && next === '/') {
      chars[index] = ' ';
      chars[index + 1] = ' ';
      index += 1;
      state = 'line';
    } else if (current === '/' && next === '*') {
      chars[index] = ' ';
      chars[index + 1] = ' ';
      index += 1;
      state = 'block';
    } else if (current === '"' || current === "'") {
      state = 'string';
      quote = current;
    }
  }
  return chars.join('');
}

function balancedEnd(text, start, opening, closing) {
  let depth = 0;
  let quote = '';
  let escaped = false;
  for (let index = start; index < text.length; index += 1) {
    const current = text[index];
    if (quote) {
      if (escaped) escaped = false;
      else if (current === '\\') escaped = true;
      else if (current === quote) quote = '';
      continue;
    }
    if (current === '"' || current === "'") quote = current;
    else if (current === opening) depth += 1;
    else if (current === closing) {
      depth -= 1;
      if (depth === 0) return index + 1;
    }
  }
  throw new Error(`unbalanced ${opening} at offset ${start}`);
}

function readAnnotation(text, start) {
  const match = /^@(\w+(?:\.\w+)*)/.exec(text.slice(start));
  if (!match) throw new Error(`annotation expected at offset ${start}`);
  const name = match[1].split('.').at(-1);
  let end = start + match[0].length;
  while (/\s/.test(text[end] ?? '')) end += 1;
  let args = '';
  if (text[end] === '(') {
    const close = balancedEnd(text, end, '(', ')');
    args = text.slice(end + 1, close - 1);
    end = close;
  }
  return { name, args, end };
}

function annotations(text, acceptedNames) {
  const result = [];
  const expression = /@(\w+(?:\.\w+)*)/g;
  let match;
  while ((match = expression.exec(text)) !== null) {
    const name = match[1].split('.').at(-1);
    if (!acceptedNames || acceptedNames.has(name)) {
      try {
        result.push({ start: match.index, ...readAnnotation(text, match.index) });
      } catch {
        // The repository validator reports malformed controller coverage below.
      }
    }
  }
  return result;
}

function mappingPaths(args) {
  if (!args.trim()) return [''];
  let target = '';
  for (const key of ['path', 'value']) {
    const expression = new RegExp(`\\b${key}\\s*=\\s*(\\{[\\s\\S]*?\\}|"(?:\\\\.|[^"\\\\])*")`);
    const match = expression.exec(args);
    if (match) {
      target = match[1];
      break;
    }
  }
  if (!target && /^\s*[{"]/.test(args)) {
    if (args.trimStart().startsWith('{')) {
      const start = args.indexOf('{');
      target = args.slice(start, balancedEnd(args, start, '{', '}'));
    } else {
      target = args.split(',', 1)[0];
    }
  }
  if (!target) return [''];
  const values = [];
  const strings = /"((?:\\.|[^"\\])*)"/g;
  let match;
  while ((match = strings.exec(target)) !== null) {
    values.push(match[1].replaceAll('\\"', '"').replaceAll('\\\\', '\\'));
  }
  return values.length ? values : [''];
}

function joinRoute(base, leaf) {
  const parts = [base, leaf].filter(Boolean).map((part) => part.replace(/^\/+|\/+$/g, ''));
  return `/${parts.join('/')}`.replace(/\/{2,}/g, '/');
}

export function extractControllerOperations(sourceRoot) {
  const files = listFiles(sourceRoot, '.java');
  const operations = [];
  let controllerCount = 0;
  for (const file of files) {
    const original = fs.readFileSync(file, 'utf8');
    const source = maskJavaComments(original);
    if (!/@(?:RestController|Controller)\b/.test(source)) continue;
    if (/@(?:RestControllerAdvice|ControllerAdvice)\b/.test(source)) continue;
    const classMatch = /\bclass\s+(\w+)/.exec(source);
    if (!classMatch) continue;
    controllerCount += 1;
    const classStart = classMatch.index;
    const prefix = source.slice(0, classStart);
    const classMappings = annotations(prefix, new Set(['RequestMapping']));
    const bases = classMappings.length ? mappingPaths(classMappings.at(-1).args) : [''];
    const methodSource = source.slice(classStart + classMatch[0].length);
    for (const annotation of annotations(methodSource, new Set(HTTP_MAPPINGS.keys()))) {
      const line = original.slice(0, classStart + classMatch[0].length + annotation.start).split('\n').length;
      for (const base of bases) {
        for (const leaf of mappingPaths(annotation.args)) {
          operations.push({
            method: HTTP_MAPPINGS.get(annotation.name),
            path: joinRoute(base, leaf),
            controller: classMatch[1],
            file,
            line
          });
        }
      }
    }
  }
  return { controllerCount, operations };
}

function scalar(value) {
  return value.trim().replace(/^['"]|['"]$/g, '');
}

export function parseOpenApiContract(content, filename = '<contract>') {
  const lines = content.split(/\r?\n/);
  const result = {
    filename,
    openapi: '',
    version: '',
    status: '',
    operations: [],
    topLevelOpenQuestions: false
  };
  let inInfo = false;
  let inDocumentMetadata = false;
  let inPaths = false;
  let currentPath = '';
  for (let index = 0; index < lines.length; index += 1) {
    const line = lines[index];
    if (/^openapi:\s*/.test(line)) result.openapi = scalar(line.split(':').slice(1).join(':'));
    if (/^info:\s*$/.test(line)) inInfo = true;
    else if (/^[^\s]/.test(line) && !/^info:\s*$/.test(line)) inInfo = false;
    if (inInfo && /^  version:\s*/.test(line)) result.version = scalar(line.slice(line.indexOf(':') + 1));
    if (/^x-document-metadata:\s*$/.test(line)) inDocumentMetadata = true;
    else if (/^[^\s]/.test(line) && !/^x-document-metadata:\s*$/.test(line)) inDocumentMetadata = false;
    if (inDocumentMetadata && /^  status:\s*/.test(line)) result.status = scalar(line.slice(line.indexOf(':') + 1));
    if (/^x-contract-status:\s*/.test(line)) result.status = scalar(line.slice(line.indexOf(':') + 1));
    if (/^x-open-questions:\s*$/.test(line)) result.topLevelOpenQuestions = true;
    if (/^paths:\s*$/.test(line)) {
      inPaths = true;
      continue;
    }
    if (inPaths && /^components:\s*$/.test(line)) {
      inPaths = false;
      currentPath = '';
      continue;
    }
    if (!inPaths) continue;
    const pathMatch = /^  (\/[^:]*):\s*$/.exec(line);
    if (pathMatch) {
      currentPath = pathMatch[1];
      continue;
    }
    const methodMatch = /^    (get|post|put|patch|delete):\s*$/.exec(line);
    if (!methodMatch || !currentPath) continue;
    const block = [];
    for (let cursor = index + 1; cursor < lines.length; cursor += 1) {
      if (/^  \/[^:]*:\s*$/.test(lines[cursor]) || /^    (?:get|post|put|patch|delete):\s*$/.test(lines[cursor]) || /^components:\s*$/.test(lines[cursor])) break;
      block.push(lines[cursor]);
    }
    const fields = new Map();
    for (const item of block) {
      const field = /^      ([\w-]+):(?:\s*(.*))?$/.exec(item);
      if (field) fields.set(field[1], field[2] ?? '');
    }
    const responseCodes = [];
    let inResponses = false;
    for (const item of block) {
      if (/^      responses:\s*$/.test(item)) {
        inResponses = true;
        continue;
      }
      if (inResponses && /^      [\w-]+:/.test(item)) inResponses = false;
      if (inResponses) {
        const response = /^        ['"]?([1-5]\d\d|default)['"]?:\s*$/.exec(item);
        if (response) responseCodes.push(response[1]);
      }
    }
    result.operations.push({
      method: methodMatch[1],
      path: currentPath,
      operationId: scalar(fields.get('operationId') ?? ''),
      fields,
      responseCodes
    });
  }
  return result;
}

function pairKey(method, route) {
  return `${method.toUpperCase()} ${route}`;
}

function validateDraft(contract) {
  const errors = [];
  if (!/^\d+\.\d+\.\d+(?:[-+][0-9A-Za-z.-]+)?$/.test(contract.version)) {
    errors.push(`${contract.filename}: Draft info.version must be SemVer-compatible`);
  }
  if (!contract.topLevelOpenQuestions) errors.push(`${contract.filename}: Draft must publish top-level x-open-questions`);
  const operationIds = new Set();
  for (const operation of contract.operations) {
    const label = `${contract.filename} ${pairKey(operation.method, operation.path)}`;
    if (!operation.operationId) errors.push(`${label}: missing operationId`);
    else if (operationIds.has(operation.operationId)) errors.push(`${contract.filename}: duplicate operationId ${operation.operationId}`);
    else operationIds.add(operation.operationId);
    for (const field of [
      'security', 'x-required-roles', 'x-required-authorities',
      'x-authorization-source', 'x-authorization-review', 'x-contract-priority',
      'x-source-controller', 'x-source-method', 'x-source-confidence',
      'x-open-questions', 'responses', 'x-error-contract-review', 'x-version-policy'
    ]) {
      if (!operation.fields.has(field)) errors.push(`${label}: missing ${field}`);
    }
    const priority = Number(operation.fields.get('x-contract-priority'));
    if (![1, 2, 3, 4, 5].includes(priority)) errors.push(`${label}: x-contract-priority must be 1..5`);
    if (!operation.responseCodes.some((code) => code.startsWith('2'))) errors.push(`${label}: missing explicit 2xx response`);
    for (const code of ['400', '500']) {
      if (!operation.responseCodes.includes(code)) errors.push(`${label}: missing ${code} error response`);
    }
    const publicOperation = operation.fields.get('security')?.trim() === '[]';
    if (!publicOperation) {
      for (const code of ['401', '403']) {
        if (!operation.responseCodes.includes(code)) errors.push(`${label}: missing ${code} security response`);
      }
    }
  }
  return errors;
}

export function validateApiContractCoverage({ sourceRoot, contractsRoot }) {
  const errors = [];
  const controllerData = extractControllerOperations(sourceRoot);
  const controllerPairs = new Map();
  for (const operation of controllerData.operations) {
    const key = pairKey(operation.method, operation.path);
    if (controllerPairs.has(key)) errors.push(`controller pair declared more than once: ${key}`);
    else controllerPairs.set(key, operation);
  }

  const contractFiles = listFiles(contractsRoot, '.openapi.yaml');
  const contractPairs = new Map();
  let draftOperations = 0;
  for (const file of contractFiles) {
    const relative = path.relative(contractsRoot, file);
    const contract = parseOpenApiContract(fs.readFileSync(file, 'utf8'), relative);
    if (!/^3\.1\.\d+$/.test(contract.openapi)) errors.push(`${relative}: OpenAPI must be 3.1.x`);
    if (!contract.version) errors.push(`${relative}: missing info.version`);
    if (!contract.status && !LEGACY_STATUS_FROM_INDEX.has(relative)) {
      errors.push(`${relative}: missing contract lifecycle status`);
    } else if (contract.status && !['Draft', 'Active', 'Deprecated'].includes(contract.status)) {
      errors.push(`${relative}: invalid contract lifecycle status ${contract.status}`);
    }
    if (!contract.operations.length) errors.push(`${relative}: no HTTP operations`);
    if (contract.status === 'Draft') {
      draftOperations += contract.operations.length;
      errors.push(...validateDraft(contract));
    }
    for (const operation of contract.operations) {
      const key = pairKey(operation.method, operation.path);
      if (contractPairs.has(key)) {
        errors.push(`contract pair declared more than once: ${key} in ${contractPairs.get(key).filename} and ${relative}`);
      } else {
        contractPairs.set(key, { ...operation, filename: relative });
      }
    }
  }

  for (const key of controllerPairs.keys()) {
    if (!contractPairs.has(key)) errors.push(`controller operation has no canonical contract: ${key}`);
  }
  const plannedOperations = [...contractPairs.keys()].filter((key) => !controllerPairs.has(key));
  return {
    errors,
    stats: {
      controllers: controllerData.controllerCount,
      controllerOperations: controllerPairs.size,
      contracts: contractFiles.length,
      contractOperations: contractPairs.size,
      implementedCovered: [...controllerPairs.keys()].filter((key) => contractPairs.has(key)).length,
      plannedOperations: plannedOperations.length,
      draftOperations
    },
    plannedOperations
  };
}

export function validateRepository(root) {
  return validateApiContractCoverage({
    sourceRoot: path.join(root, 'backend', 'src', 'main', 'java'),
    contractsRoot: path.join(root, 'docs', 'contracts')
  });
}

function parseArgs(argv) {
  let root = '';
  for (let index = 0; index < argv.length; index += 1) {
    if (argv[index] === '--root') {
      root = argv[index + 1] ?? '';
      index += 1;
    } else if (argv[index] === '--help' || argv[index] === '-h') {
      return { help: true, root: '' };
    } else {
      throw new Error(`unknown argument: ${argv[index]}`);
    }
  }
  return { help: false, root };
}

function main() {
  let args;
  try {
    args = parseArgs(process.argv.slice(2));
  } catch (error) {
    process.stderr.write(`ERROR: ${error.message}\n`);
    process.exitCode = 2;
    return;
  }
  if (args.help) {
    process.stdout.write('Usage: node docs/scripts/validate-api-contract-coverage.mjs [--root <repository>]\n');
    return;
  }
  const scriptDirectory = path.dirname(fileURLToPath(import.meta.url));
  const root = path.resolve(args.root || path.join(scriptDirectory, '..', '..'));
  const result = validateRepository(root);
  const stats = result.stats;
  process.stdout.write(
    `API_CONTRACT_COVERAGE controllers=${stats.controllers} ` +
    `controllerOperations=${stats.controllerOperations} contracts=${stats.contracts} ` +
    `contractOperations=${stats.contractOperations} implementedCovered=${stats.implementedCovered} ` +
    `planned=${stats.plannedOperations} draftOperations=${stats.draftOperations}\n`
  );
  if (result.errors.length) {
    for (const error of result.errors) process.stderr.write(`ERROR: ${error}\n`);
    process.stderr.write(`API_CONTRACT_COVERAGE_RESULT=FAIL failures=${result.errors.length}\n`);
    process.exitCode = 1;
    return;
  }
  process.stdout.write('API_CONTRACT_COVERAGE_RESULT=PASS failures=0\n');
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) main();
