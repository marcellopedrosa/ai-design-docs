import fs from 'node:fs';
import path from 'node:path';
import { pathToFileURL } from 'node:url';

const ignoredDirectories = new Set(['.git', '.agents', '.claude', '.codex', 'node_modules', 'spec-kit']);
const pathExtensions = /\.(?:md|mdx|json|ya?ml|mjs|cjs|js|ts|tsx|py|sh|ps1|toml|xml|proto|template)$/i;

function markdownFiles(root) {
  const files = [];
  function walk(directory) {
    for (const entry of fs.readdirSync(directory, { withFileTypes: true })) {
      if (entry.isSymbolicLink()) continue;
      const absolute = path.join(directory, entry.name);
      if (entry.isDirectory() && !ignoredDirectories.has(entry.name)) walk(absolute);
      else if (entry.isFile() && /\.mdx?$/i.test(entry.name)) files.push(absolute);
    }
  }
  walk(root);
  return files.sort();
}

function localTarget(raw, fromMetadata = false) {
  let value = raw.trim().replace(/^<|>$/g, '').replace(/^['"]|['"]$/g, '');
  if (!value || value.startsWith('#') || /^https?:\/\//i.test(value) || /^mailto:/i.test(value)) return null;
  if (/^N\/A\b/i.test(value) || value.includes('{{') || value.includes('}}')) return null;
  if (/^file:\/\//i.test(value)) return value;
  if (/^[a-z][a-z\d+.-]*:/i.test(value)) return null;
  if (fromMetadata) {
    value = value.split(/\s+-\s+|;\s+/)[0].trim();
    if (!value.includes('/') && !pathExtensions.test(value)) return null;
  } else {
    value = value.split(/\s+['"]/)[0].trim();
  }
  value = value.split(/[?#]/)[0];
  if (!value || value.includes('*')) return null;
  try { return decodeURIComponent(value); } catch { return value; }
}

export function checkFile(file) {
  const findings = [];
  const lines = fs.readFileSync(file, 'utf8').split(/\r?\n/);
  const frontmatter = lines[0] === '---';
  let inFrontmatter = frontmatter;
  let inFence = false;
  const inspect = (target, line) => {
    if (path.isAbsolute(target) || /^[a-z]:[\\/]/i.test(target) || /^file:\/\//i.test(target)) {
      findings.push({ file, line, target, reason: 'absolute local path' });
      return;
    }
    const resolved = path.resolve(path.dirname(file), target);
    if (!fs.existsSync(resolved)) findings.push({ file, line, target, reason: 'missing target' });
  };

  for (let index = 0; index < lines.length; index += 1) {
    const line = lines[index];
    if (index === 0 && frontmatter) continue;
    if (inFrontmatter) {
      if (line === '---') { inFrontmatter = false; continue; }
      const metadata = line.match(/^(related_files|code_references):\s*(.*)$/);
      if (metadata) {
        for (const token of metadata[2].split(',')) {
          const target = localTarget(token, true);
          if (target) inspect(target, index + 1);
        }
      }
      continue;
    }
    if (/^\s*(```|~~~)/.test(line)) { inFence = !inFence; continue; }
    if (inFence) continue;

    const inline = /!?\[[^\]]+\]\((<[^>]+>|[^)]+)\)/g;
    for (const match of line.matchAll(inline)) {
      const target = localTarget(match[1]);
      if (target) inspect(target, index + 1);
    }
    const reference = line.match(/^\s*\[[^\]]+\]:\s*(<[^>]+>|\S+)/);
    if (reference) {
      const target = localTarget(reference[1]);
      if (target) inspect(target, index + 1);
    }
  }
  return findings;
}

export function checkRoot(root) {
  return markdownFiles(root).flatMap(checkFile);
}

function main() {
  const args = process.argv.slice(2);
  if (args.length !== 2 || args[0] !== '--root') {
    process.stderr.write('Usage: node scripts/check-links.mjs --root <directory>\n');
    process.exitCode = 2;
    return;
  }
  const root = path.resolve(args[1]);
  if (!fs.existsSync(root) || !fs.statSync(root).isDirectory()) {
    process.stderr.write(`Not a directory: ${root}\n`);
    process.exitCode = 2;
    return;
  }
  const findings = checkRoot(root);
  for (const finding of findings) {
    process.stdout.write(`${path.relative(root, finding.file)}:${finding.line}: ${finding.reason}: ${finding.target}\n`);
  }
  process.stdout.write(`Checked ${markdownFiles(root).length} Markdown files; ${findings.length} broken references.\n`);
  if (findings.length) process.exitCode = 1;
}

if (process.argv[1] && import.meta.url === pathToFileURL(path.resolve(process.argv[1])).href) main();
