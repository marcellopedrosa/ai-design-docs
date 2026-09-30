#!/usr/bin/env node
import fs from 'node:fs';
import path from 'node:path';
import process from 'node:process';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { parseYamlSubset } from '../scaffold/yaml.mjs';
import { loadModel, auditScaffold } from '../scaffold/engine.mjs';

const TYPES = new Set(['application', 'service', 'library', 'infrastructure', 'mobile', 'other']);
const PROJECT_ROOTS = ['docs/agents', 'docs/architecture', 'docs/product', 'docs/requirements', 'docs/decisions'];
const LEGACY = new Set(['registry', 'tooling', 'contracts', 'evals', 'skills', '.agents', '.claude']);

function safeRoot(root, candidate, label) {
  const full = path.resolve(candidate);
  if (!path.isAbsolute(full) || full === path.resolve(root)) throw new Error(`${label}: path must be an existing directory different from target`);
  return full;
}
function argsOf(args) {
  const out = {}; for (let i = 0; i < args.length; i++) { const a = args[i]; if (a.startsWith('--')) out[a.slice(2)] = args[i + 1]?.startsWith('--') ? true : (args[i + 1] ?? true); } return out;
}
function listFiles(root) {
  const files = [];
  const walk = (dir) => { for (const e of fs.readdirSync(dir, { withFileTypes: true }).sort((a,b)=>a.name.localeCompare(b.name))) { if (e.isSymbolicLink()) continue; const f=path.join(dir,e.name); if(e.isDirectory()) walk(f); else if(e.isFile()) files.push(f); } };
  walk(root); return files;
}
function yamlManifest(name, type, profiles, agents) { return `version: 1\nproject:\n  name: ${name}\n  type: ${type}\nprofiles:\n${profiles.map(p=>`  - ${p}`).join('\n')}\nagents:\n${agents.map(a=>`  - ${a}`).join('\n')}\n`; }
function run(root, entry, extra=[]) { return spawnSync(process.execPath, [path.join(root, entry), ...extra], { cwd: root, stdio: 'inherit' }); }
function requireConfirm(opts) { return opts.yes === true || opts.yes === 'true'; }

export function classifySource(source, target) {
  const result = [];
  for (const full of listFiles(source)) {
    const rel = path.relative(source, full).replaceAll('\\', '/');
    const top = rel.split('/')[0];
    let classification = 'PROJECT_OTHER_DOC', action = 'REPORT', reason = 'unknown root artifact';
    if (rel === '.git' || rel.startsWith('.git/')) { classification='IGNORED'; action='SKIP'; reason='neverCopy policy'; }
    else if (LEGACY.has(top) || top === 'harness') { classification='LEGACY_HARNESS'; action='SKIP'; reason='current harness is authoritative'; }
    else if (['node_modules','target','build','dist','coverage','.idea','.vscode'].includes(top) || rel.endsWith('.log')) { classification='BUILD_ARTIFACT'; action='SKIP'; reason='neverCopy policy'; }
    else if (PROJECT_ROOTS.some(p=>rel === p || rel.startsWith(`${p}/`))) { classification = rel.startsWith('docs/agents/standards/') ? 'PROJECT_STANDARD' : rel.startsWith('docs/agents/') ? 'PROJECT_AGENT' : rel.startsWith('docs/architecture/') ? 'PROJECT_ARCHITECTURE' : rel.startsWith('docs/product/') ? 'PROJECT_PRODUCT' : rel.startsWith('docs/requirements/') ? 'PROJECT_REQUIREMENT' : rel.startsWith('docs/decisions/') ? 'PROJECT_DECISION' : 'PROJECT_OTHER_DOC'; action='COPY'; reason='project-owned artifact preserved by migration policy'; }
    result.push({ source: rel, classification, action, target: action === 'COPY' ? rel : 'none', reason });
  }
  return result;
}
function importLegacy(root, source, opts) {
  const sourceRoot = safeRoot(root, source, 'source');
  if (!fs.existsSync(sourceRoot) || !fs.statSync(sourceRoot).isDirectory()) throw new Error('source: directory not found');
  if (sourceRoot === path.resolve(root)) throw new Error('source must differ from target');
  const status = spawnSync('git', ['status', '--porcelain'], { cwd: root, encoding: 'utf8' });
  if (status.status !== 0 || status.stdout.trim()) throw new Error('Target working tree is not clean. Commit or stash changes before onboarding a legacy project.');
  const decisions = classifySource(sourceRoot, root);
  const conflicts = decisions.filter(d=>d.action==='COPY' && fs.existsSync(path.join(root,d.target)));
  if (conflicts.length) { for (const d of conflicts) console.log(`CONFLICT ${d.target}`); throw new Error('target conflict; overwrite is forbidden'); }
  for (const d of decisions) console.log(`SOURCE: ${d.source}\nCLASSIFICATION: ${d.classification}\nACTION: ${d.action}\nTARGET: ${d.target}\nREASON: ${d.reason}\n`);
  const copies = decisions.filter(d=>d.action==='COPY');
  if (!requireConfirm(opts)) return 2;
  for (const d of copies) { const from=path.join(sourceRoot,d.source), to=path.join(root,d.target); fs.mkdirSync(path.dirname(to), {recursive:true}); fs.copyFileSync(from,to,fs.constants.COPYFILE_EXCL); }
  return 0;
}
export function main(args=process.argv.slice(2), root=path.resolve('.')) {
  const opts=argsOf(args);
  if (opts.source) return importLegacy(root, opts.source, opts);
  const manifest=path.join(root,'docs','project-manifest.yaml');
  if (fs.existsSync(manifest)) { console.error('Manifest already exists; use bootstrap.'); return 2; }
  const name=String(opts.name||'').trim(), type=String(opts.type||'application');
  if (!name || !TYPES.has(type)) { console.error('Questions required: --name and valid --type. Profiles/agents come from Registry.'); return 2; }
  let model; try { model=loadModel(root); } catch(e) { console.error(`BLOCKED ${e.message}`); return 2; }
  const profiles=String(opts.profiles||'base').split(',').map(x=>x.trim()).filter(Boolean);
  const agents=String(opts.agents||'').split(',').map(x=>x.trim()).filter(Boolean);
  if (profiles.some(p=>!Object.hasOwn(model.profiles,p))) { console.error('Unknown profile. Use harness/registry/profiles.yaml.'); return 2; }
  const content=yamlManifest(name,type,profiles,agents); console.log(content);
  if (!requireConfirm(opts)) { console.error('Confirmation required: rerun with --yes after reviewing the manifest.'); return 2; }
  fs.mkdirSync(path.dirname(manifest),{recursive:true}); fs.writeFileSync(manifest,content,{flag:'wx'});
  const scaffold=run(root,'harness/tooling/scaffold/index.mjs',['--create']); if(scaffold.status!==0)return scaffold.status??1;
  return run(root,'harness/tooling/harness-doctor/index.mjs').status??1;
}
if (process.argv[1] && path.resolve(process.argv[1])===fileURLToPath(import.meta.url)) process.exitCode=main();
