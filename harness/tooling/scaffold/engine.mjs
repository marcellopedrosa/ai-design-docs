import fs from 'node:fs';
import path from 'node:path';
import { compileSchema } from '../contracts/validator.mjs';
import { parseYamlSubset } from './yaml.mjs';

const SEGMENT = /^[a-z][a-z0-9]*(?:-[a-z0-9]+)*$/;
const REQUIREMENT_NAME = /^REQ-[0-9]{5}-[a-z0-9]+(?:-[a-z0-9]+)*$/;
const RESERVED = /^(?:con|prn|aux|nul|com[1-9]|lpt[1-9])$/i;
const TYPES = ['agent', 'standard', 'architecture', 'requirement'];

function segment(value, label) {
  if (typeof value !== 'string' || !SEGMENT.test(value) || RESERVED.test(value)) {
    throw new Error(`${label}: unsafe identifier ${JSON.stringify(value)}`);
  }
  return value;
}

function artifactName(value, type) {
  if (type === 'requirement' && REQUIREMENT_NAME.test(value)) return value;
  if (type === 'requirement') throw new Error(`requirement.name: expected REQ-NNNNN-short-title, got ${JSON.stringify(value)}`);
  return segment(value, 'artifact.name');
}

function safePath(root, relative, boundary) {
  if (typeof relative !== 'string' || !relative || relative.includes('\\') ||
      relative.includes(':') || path.posix.isAbsolute(relative) ||
      relative.split('/').some((part) => part === '..' || part === '.' || part === '')) {
    throw new Error(`unsafe path: ${relative}`);
  }
  if (!relative.startsWith(`${boundary}/`)) throw new Error(`path outside ${boundary}/: ${relative}`);
  const base = path.resolve(root);
  const full = path.resolve(base, ...relative.split('/'));
  const rel = path.relative(base, full);
  if (rel.startsWith('..') || path.isAbsolute(rel)) throw new Error(`path outside project root: ${relative}`);
  let current = base;
  for (const part of relative.split('/')) {
    current = path.join(current, part);
    try {
      if (fs.lstatSync(current).isSymbolicLink()) throw new Error(`symlink in artifact path: ${relative}`);
    } catch (error) {
      if (error.code !== 'ENOENT') throw error;
    }
  }
  return full;
}

function readYaml(root, relative, schemaName) {
  const file = safePath(root, relative, relative.split('/')[0]);
  const schemaFile = safePath(root, `harness/contracts/${schemaName}.schema.json`, 'harness');
  const schema = JSON.parse(fs.readFileSync(schemaFile, 'utf8'));
  const value = parseYamlSubset(fs.readFileSync(file, 'utf8'), relative);
  const validation = compileSchema(schema, schemaName)(value);
  if (!validation.valid) throw new Error(`${relative}: ${validation.errors.join('; ')}`);
  return value;
}

function validRoute(root, type, route) {
  const substitutes = { scope: 'global', name: type === 'requirement' ? 'REQ-00001-example' : 'example' };
  const expand = (value) => {
    const result = value.replace(/\{([^}]+)\}/g, (all, key) => {
      if (!Object.hasOwn(substitutes, key)) throw new Error(`route ${type}: unknown placeholder ${key}`);
      return substitutes[key];
    });
    if (/[{}]/.test(result)) throw new Error(`route ${type}: malformed placeholder`);
    return result;
  };
  const rootPath = expand(route.root);
  const name = expand(route.naming);
  if (!name.endsWith('.md') || name.includes('/')) throw new Error(`route ${type}: invalid naming`);
  safePath(root, `${rootPath}/${name}`, 'docs');
  const template = safePath(root, route.template, 'harness');
  if (!route.template.startsWith('harness/templates/') || !route.template.endsWith('.md') ||
      !fs.existsSync(template) || !fs.statSync(template).isFile()) {
    throw new Error(`route ${type}: template missing or outside harness/templates/: ${route.template}`);
  }
  if (type === 'standard' && !route.root.includes('{scope}')) throw new Error('standard route must include {scope}');
  if (!route.naming.includes('{name}')) throw new Error(`route ${type}: naming must include {name}`);
}

export function loadModel(root, manifestPath = 'docs/project-manifest.yaml') {
  const profiles = readYaml(root, 'harness/registry/profiles.yaml', 'profile-registry');
  const routes = readYaml(root, 'harness/registry/artifact-routes.yaml', 'artifact-routes');
  const standardsPath = safePath(root, 'harness/registry/standards.yaml', 'harness');
  const standards = parseYamlSubset(fs.readFileSync(standardsPath, 'utf8'), 'harness/registry/standards.yaml').standards;
  if (!standards || typeof standards !== 'object') throw new Error('standards registry missing catalog');
  for (const [name, profile] of Object.entries(profiles.profiles)) {
    segment(name, 'profile');
    for (const parent of profile.extends ?? []) segment(parent, 'extends');
    for (const artifact of profile.artifacts) {
      artifactName(artifact.name, artifact.type);
      if (artifact.type === 'standard' && !Object.hasOwn(standards, artifact.name)) {
        throw new Error(`${name}: standard not cataloged in standards.yaml: ${artifact.name}`);
      }
      if (artifact.type === 'standard') segment(artifact.scope, 'artifact.scope');
      else if (artifact.scope !== undefined) throw new Error(`${name}: only standard accepts scope`);
    }
  }
  for (const type of TYPES) {
    if (!routes.routes[type]) throw new Error(`route missing: ${type}`);
  }
  for (const [type, route] of Object.entries(routes.routes)) {
    if (!TYPES.includes(type)) throw new Error(`unsupported artifact type: ${type}`);
    validRoute(root, type, route);
  }
  for (const [name, profile] of Object.entries(profiles.profiles)) {
    for (const parent of profile.extends ?? []) {
      if (!Object.hasOwn(profiles.profiles, parent)) throw new Error(`${name}: unknown parent profile ${parent}`);
    }
  }
  for (const name of Object.keys(profiles.profiles)) resolveProfiles(profiles.profiles, [name]);
  const manifestFile = safePath(root, manifestPath, 'docs');
  const manifest = fs.existsSync(manifestFile) ? readYaml(root, manifestPath, 'project-manifest') : null;
  return { profiles: profiles.profiles, routes: routes.routes, manifest };
}

export function resolveProfiles(profiles, selected) {
  const order = [];
  const visited = new Set();
  const visiting = new Set();
  const visit = (name) => {
    segment(name, 'profile');
    if (!Object.hasOwn(profiles, name)) throw new Error(`unknown profile: ${name}`);
    if (visiting.has(name)) throw new Error(`profile inheritance cycle: ${name}`);
    if (visited.has(name)) return;
    visiting.add(name);
    for (const parent of profiles[name].extends ?? []) visit(parent);
    visiting.delete(name);
    visited.add(name);
    order.push(name);
  };
  for (const name of selected) visit(name);
  return order;
}

export function resolveArtifacts(model) {
  if (!model.manifest) return { profiles: [], artifacts: [] };
  const order = resolveProfiles(model.profiles, model.manifest.profiles);
  const found = new Map();
  for (const profile of order) {
    for (const artifact of model.profiles[profile].artifacts) {
      const key = `${artifact.type}/${artifact.scope ?? ''}/${artifact.name}`;
      if (!found.has(key)) found.set(key, artifact);
    }
  }
  const expectedAgents = new Set([...found.values()].filter((item) => item.type === 'agent').map((item) => item.name));
  const listedAgents = new Set(model.manifest.agents);
  for (const name of expectedAgents) if (!listedAgents.has(name)) throw new Error(`required agent not declared in manifest: ${name}`);
  for (const name of listedAgents) if (!expectedAgents.has(name)) throw new Error(`manifest agent not required by profiles: ${name}`);
  return { profiles: order, artifacts: [...found.values()] };
}

export function routeArtifact(root, route, artifact) {
  artifactName(artifact.name, artifact.type);
  const scope = artifact.type === 'standard' ? segment(artifact.scope, 'artifact.scope') : null;
  const replace = (value) => value.replaceAll('{name}', artifact.name).replaceAll('{scope}', scope ?? '');
  const relative = `${replace(route.root)}/${replace(route.naming)}`;
  const full = safePath(root, relative, 'docs');
  return { relative, full };
}

function markdownFiles(root) {
  const docs = path.join(root, 'docs');
  if (!fs.existsSync(docs)) return [];
  const result = [];
  const visit = (dir) => {
    for (const entry of fs.readdirSync(dir, { withFileTypes: true }).sort((a, b) => a.name.localeCompare(b.name))) {
      const full = path.join(dir, entry.name);
      if (entry.isSymbolicLink()) continue;
      if (entry.isDirectory()) visit(full);
      else if (entry.isFile() && entry.name.endsWith('.md')) result.push(full);
    }
  };
  visit(docs);
  return result;
}

export function inspectProject(root, model = null) {
  const routes = model?.routes ?? loadModel(root).routes;
  const result = [];
  for (const full of markdownFiles(root)) {
    const relative = path.relative(root, full).replaceAll('\\', '/');
    if (path.basename(full) === 'README.md') continue;
    let artifact;
    const standard = relative.match(/^docs\/agents\/standards\/([a-z][a-z0-9-]*)\/([a-z][a-z0-9-]*)\.md$/);
    const agent = relative.match(/^docs\/agents\/([a-z][a-z0-9-]*)-agent\.md$/);
    if (standard) artifact = { type: 'standard', scope: standard[1], name: standard[2] };
    else if (agent) artifact = { type: 'agent', name: agent[1] };
    else if (/-standard\.md$/.test(relative)) {
      const name = path.basename(full, '.md');
      const scope = path.basename(path.dirname(full));
      if (SEGMENT.test(scope)) artifact = { type: 'standard', scope, name };
    }
    if (!artifact) continue;
    const expected = routeArtifact(root, routes[artifact.type], artifact).relative;
    result.push({
      artifact,
      current: relative,
      targetRoute: `${routes[artifact.type].root}/${routes[artifact.type].naming}`,
      expected,
      action: relative === expected ? 'CONFORMANT' : 'MIGRATION_REQUIRED',
      reason: relative === expected ? 'canonical_location' : 'legacy_location'
    });
  }
  return result;
}

export function auditScaffold(root, { mode = 'check', manifestPath = 'docs/project-manifest.yaml' } = {}) {
  const model = loadModel(root, manifestPath);
  const report = { mode, manifest: model.manifest ? 'PRESENT' : 'MISSING', profiles: [], artifacts: [], inspection: [], suggestions: null, warnings: [] };
  if (mode === 'inspect') {
    report.inspection = inspectProject(root, model);
    if (!model.manifest) {
      const inferred = report.inspection.flatMap((item) => [item.artifact.scope, item.artifact.type === 'agent' ? item.artifact.name : null]);
      report.suggestions = {
        profiles: [...new Set(inferred.filter((name) => name && Object.hasOwn(model.profiles, name)))],
        agents: [...new Set(report.inspection.filter((item) => item.artifact.type === 'agent').map((item) => item.artifact.name))],
        reviewRequired: true
      };
    }
  }
  if (!model.manifest) {
    report.warnings.push('docs/project-manifest.yaml missing; adoption remains opt-in');
    return report;
  }
  const resolved = resolveArtifacts(model);
  report.profiles = resolved.profiles;
  const candidates = markdownFiles(root);
  for (const artifact of resolved.artifacts) {
    const route = model.routes[artifact.type];
    const { relative, full } = routeArtifact(root, route, artifact);
    const legacy = candidates.filter((candidate) => candidate !== full && path.basename(candidate) === path.basename(full))
      .map((candidate) => path.relative(root, candidate).replaceAll('\\', '/'));
    const exists = fs.existsSync(full);
    const status = exists ? 'KEEP' : legacy.length ? 'LEGACY_LOCATION' : 'CREATE';
    const item = { ...artifact, expected: relative, status, legacy };
    if (exists && /\{\{|Definir owner\./.test(fs.readFileSync(full, 'utf8'))) {
      item.incomplete = true;
      report.warnings.push(`${relative}: template content requires squad completion`);
    }
    report.artifacts.push(item);
    if (mode !== 'create' || status !== 'CREATE') continue;
    const template = safePath(root, route.template, 'harness');
    const content = fs.readFileSync(template, 'utf8')
      .replaceAll('{{name}}', artifact.name)
      .replaceAll('{{title}}', artifact.name.replaceAll('-', ' '));
    if (content.includes('{{')) throw new Error(`template has unsupported placeholder: ${route.template}`);
    safePath(root, relative, 'docs');
    fs.mkdirSync(path.dirname(full), { recursive: true });
    safePath(root, relative, 'docs');
    fs.writeFileSync(full, content, { flag: 'wx' });
    item.status = 'CREATED';
    report.warnings.push(`${relative}: update collection README and complete owner/content before approval`);
  }
  return report;
}
