#!/usr/bin/env node

import fs from 'node:fs';
import path from 'node:path';
import process from 'node:process';
import { fileURLToPath } from 'node:url';

const FIELD_ALIASES = {
  document_id: ['document_id', 'Document ID', 'Requirement ID', 'Use Case ID'],
  primary_nature: ['primary_nature', 'Primary Nature', 'Natureza primaria', 'Natureza primária'],
  objective: ['objective', 'Objective', 'Objetivo'],
  scope: ['scope', 'Scope', 'Escopo'],
  non_objectives: ['non_objectives', 'Non-objectives', 'Non-Objectives', 'Nao-objetivos', 'Não-objetivos'],
  owner: ['owner', 'Owner', 'Authors / Owners', 'Author / Owner', 'Agent / Owner'],
  status: ['status', 'Status'],
  date: ['date', 'Date', 'Data'],
  version: ['version', 'Version', 'Versão'],
  keywords: ['keywords', 'Keywords', 'Palavras-chave'],
  related_files: ['related_files', 'Related Files', 'Arquivos relacionados'],
  code_references: ['code_references', 'Code References', 'Referências ao código', 'Referencias ao codigo'],
  principal_statement: [
    'principal_statement', 'Principal Statement', 'Principal Decision',
    'Principal Requirement', 'Principal Rule', 'Principal Flow'
  ]
};

const REQUIRED_PATHS = [
  'AGENTS.md',
  'CLAUDE.md',
  'docs/README.md',
  'docs/ai/README.md',
  'docs/adrs/README.md',
  'docs/adrs/ADR-0000-governanca-documentacao-agentes-ia.md',
  'docs/architecture/README.md',
  'docs/architecture/module-registry.md',
  'docs/agents/README.md',
  'docs/agents/standards/README.md',
  'docs/agents/standards/software-engineering-lifecycle.md',
  'docs/agents/standards/implementation-readiness-standard.md',
  'docs/agents/standards/software-quality-standard.md',
  'docs/agents/skills/README.md',
  'docs/business/skills/README.md',
  'docs/product_requirements/README.md',
  'docs/product_requirements/PRD-00001-billing-enterprise.md',
  'docs/product_requirements/PRD-00002-omnichannel-experience.md',
  'docs/product_requirements/PRD-00003-tenant-platform-lifecycle.md',
  'docs/product_requirements/PRD-00004-fiscal-operations.md',
  'docs/product_requirements/PRD-00005-identity-access-governance.md',
  'docs/templates/README.md',
  'docs/settings/README.md',
  'docs/settings/codex.md',
  'docs/settings/claude-code.md',
  'docs/scripts/README.md',
  'docs/scripts/validate-documentation-governance.mjs',
  'docs/scripts/validate-documentation-governance.test.mjs',
  'infra/scripts/validate-docs.sh',
  'infra/scripts/validate-quality-gates.sh',
  'infra/scripts/tests/validate-quality-gates-test.sh',
  '.agents/skills/governanca-documental/SKILL.md',
  '.claude/skills/governanca-documental/SKILL.md',
  '.agents/skills/implementation-readiness/SKILL.md',
  '.claude/skills/implementation-readiness/SKILL.md',
  '.agents/skills/quality-gate/SKILL.md',
  '.claude/skills/quality-gate/SKILL.md',
  'infra/README.md',
  'infra/AGENTS.md',
  'infra/CLAUDE.md',
  'docs/task_plans/implementation_plans/infra/README.md',
  'docs/task_plans/implementation_plans/infra/TEMPLATE.md'
];

const REQUIRED_TEMPLATES = [
  'docs/templates/TPL-00001-PromptTemplateCriarAgente.md',
  'docs/templates/TPL-00002-PromptTemplateCriarADR.md',
  'docs/templates/TPL-00003-PromptTemplateCriarRequisito.md',
  'docs/templates/TPL-00004-PromptTemplateCriarCasoDeUso.md',
  'docs/templates/TPL-00005-PromptTemplateCriarTaskPlan.md',
  'docs/templates/TPL-00006-PromptTemplateCriarImplementationPlan.md',
  'docs/templates/TPL-00007-PromptTemplateCriarProgressReport.md',
  'docs/templates/TPL-00008-PromptTemplateWireframeStitchMapping.md',
  'docs/templates/TPL-00009-PromptTemplateLessonsLearned.md',
  'docs/templates/TPL-00010-PromptTemplateCriarSkill.md',
  'docs/templates/TPL-00012-PromptTemplateCriarPRD.md'
];

function normalize(value) {
  return value.normalize('NFD').replace(/[\u0300-\u036f]/g, '').toLowerCase();
}

function escapeRegex(value) {
  return value.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

function linesWithin(content, limit = 80) {
  const clean = content.replace(/^\uFEFF/, '');
  const frontmatter = clean.match(/^---\r?\n([\s\S]*?)\r?\n---(?:\r?\n|$)/);
  const metadata = frontmatter ? frontmatter[1] : clean;
  return metadata.split(/\r?\n/).slice(0, limit);
}

function fieldPattern(alias) {
  const escaped = escapeRegex(alias).replace(/\\ /g, '\\s+');
  return new RegExp(
    `^\\s*(?:-\\s*)?(?:\\*\\*)?${escaped}(?:\\*\\*)?\\s*(?::|\\|)\\s*(?:\\*\\*)?(.+?)\\s*(?:\\|)?$`,
    'i'
  );
}

export function extractField(content, aliases, limit = 80) {
  const clean = (value) => {
    const trimmed = value.trim().replace(/\s*\|\s*$/, '').replace(/^`|`$/g, '');
    const quoted = trimmed.match(/^(["'])([\s\S]*)\1$/);
    return quoted ? quoted[2] : trimmed;
  };
  for (const line of linesWithin(content, limit)) {
    for (const alias of aliases) {
      const match = line.match(fieldPattern(alias));
      if (match && match[1]?.trim()) {
        return clean(match[1]);
      }

      const table = line.match(/^\s*\|\s*(?:\*\*)?([^|*]+?)(?:\*\*)?\s*\|\s*(.+?)\s*\|\s*$/);
      if (table && normalize(table[1].trim()) === normalize(alias) && table[2].trim()) {
        return clean(table[2]);
      }
    }
  }
  return null;
}

export function validateDocumentContract(content, relativePath = '<memory>') {
  const errors = [];
  if (!/^(?:\uFEFF)?#\s+\S/m.test(content)) {
    errors.push(`${relativePath}: titulo H1 ausente`);
  }

  const values = {};
  for (const [field, aliases] of Object.entries(FIELD_ALIASES)) {
    values[field] = extractField(content, aliases);
    if (!values[field]) {
      errors.push(`${relativePath}: campo ausente ou vazio: ${field}`);
    } else if (/^N\/?A$/i.test(values[field])) {
      errors.push(`${relativePath}: ${field} usa N/A sem justificativa`);
    }
  }
  const nature = values.primary_nature;
  const allowedNatures = new Set(['regra', 'requisito', 'contexto', 'decisao', 'plano', 'historico', 'template']);
  if (nature && !allowedNatures.has(normalize(nature))) {
    errors.push(`${relativePath}: primary_nature fora da taxonomia: ${nature}`);
  }
  if (values.date && !/^\d{4}-\d{2}-\d{2}$/.test(values.date)) {
    errors.push(`${relativePath}: date deve usar YYYY-MM-DD: ${values.date}`);
  }
  if (values.version && !/^v?\d+\.\d+(?:\.\d+)?$/i.test(values.version)) {
    errors.push(`${relativePath}: version deve ser numerica e versionada: ${values.version}`);
  }
  const validStatusBases = [
    'Accepted', 'Active', 'Approved', 'Cancelled', 'Completed', 'Current',
    'Deprecated', 'Disabled', 'Done', 'Draft', 'Final', 'Historical',
    'Implemented', 'In Progress', 'In Review', 'Needs Review',
    'Partially Superseded', 'Pending', 'Proposed', 'Rejected', 'Superseded',
    'Validated'
  ];
  if (values.status && !validStatusBases.some((status) => {
    const actual = normalize(values.status);
    const base = normalize(status);
    return actual === base || actual.startsWith(`${base} `);
  })) {
    errors.push(`${relativePath}: status fora dos ciclos de vida documentais: ${values.status}`);
  }
  return errors;
}

const SKIPPED_TREE_NAMES = new Set([
  '.git', 'node_modules', 'target', '.next', 'dist', 'build', 'out', 'coverage'
]);

function shouldSkipTreeEntry(entry) {
  return entry.name.startsWith('.env') || SKIPPED_TREE_NAMES.has(entry.name);
}

function walkFiles(root) {
  const files = [];
  for (const entry of fs.readdirSync(root, { withFileTypes: true })) {
    if (shouldSkipTreeEntry(entry)) continue;
    const target = path.join(root, entry.name);
    if (entry.isSymbolicLink()) continue;
    if (entry.isDirectory()) files.push(...walkFiles(target));
    if (entry.isFile()) files.push(target);
  }
  return files;
}

function walkDirectories(root) {
  const directories = [root];
  for (const entry of fs.readdirSync(root, { withFileTypes: true })) {
    if (shouldSkipTreeEntry(entry)) continue;
    if (!entry.isDirectory() || entry.isSymbolicLink()) continue;
    directories.push(...walkDirectories(path.join(root, entry.name)));
  }
  return directories;
}

function relative(root, target) {
  return path.relative(root, target).split(path.sep).join('/');
}

function isMarkdownLinkTo(content, filename) {
  const escaped = escapeRegex(filename);
  return new RegExp(`\\[[^\\]]*\\]\\((?:<)?[^)<>]*${escaped}(?:>)?\\)`).test(content);
}

export function validateRelativeLinks(content, filePath, repositoryRoot) {
  const errors = [];
  const rel = relative(repositoryRoot, filePath);
  if (/^docs\/templates\/TPL-[^/]+\.md$/.test(rel)) return errors;
  const linkPattern = /\]\((<[^>]+>|[^)]+)\)/g;
  let match;
  while ((match = linkPattern.exec(content)) !== null) {
    let target = match[1].trim();
    if (target.startsWith('<') && target.endsWith('>')) target = target.slice(1, -1);
    target = target.replace(/\s+"[^"]*"$/, '');
    const withoutFragment = target.split('#')[0].split('?')[0];
    if (!withoutFragment || /^(?:https?:|mailto:|#|\/)/.test(target)) continue;
    if (target.startsWith('(') || /[{}<>\[]/.test(withoutFragment) || withoutFragment.includes('*')) continue;
    if (withoutFragment.startsWith('file:')) {
      errors.push(`${relative(repositoryRoot, filePath)}: URI file: proibida: ${target}`);
      continue;
    }
    let decoded = withoutFragment;
    try { decoded = decodeURIComponent(withoutFragment); } catch { /* keep literal */ }
    const resolved = path.resolve(path.dirname(filePath), decoded);
    if (!resolved.startsWith(`${repositoryRoot}${path.sep}`) && resolved !== repositoryRoot) continue;
    if (!fs.existsSync(resolved)) {
      errors.push(`${relative(repositoryRoot, filePath)}: link relativo quebrado: ${target}`);
    }
  }
  return errors;
}

function metadataPathReferences(content, field) {
  const value = extractField(content, FIELD_ALIASES[field]);
  if (!value || /\bN\/?A\b/i.test(value)) return [];
  const matches = value.match(/docs\/[A-Za-z0-9._/-]+\.(?:md|mjs|json|ya?ml|sh)|(?:AGENTS|CLAUDE)\.md/g);
  return matches ?? [];
}

function buildRepositoryPathIndex(repositoryRoot) {
  const absolutePaths = [
    ...walkDirectories(repositoryRoot),
    ...walkFiles(repositoryRoot)
  ];
  const relativePaths = absolutePaths.map((target) => relative(repositoryRoot, target));
  const pathSet = new Set(relativePaths);
  const basenames = new Map();
  for (const target of relativePaths) {
    const basename = path.posix.basename(target);
    if (!basenames.has(basename)) basenames.set(basename, []);
    basenames.get(basename).push(target);
  }
  return { relativePaths, pathSet, basenames };
}

function hasSuffix(index, candidate) {
  const normalized = candidate.replace(/^\.\//, '').replace(/\/$/, '');
  return index.relativePaths.some((target) =>
    target === normalized || target.endsWith(`/${normalized}`)
  );
}

function codeReferenceTokens(segment) {
  const tokens = [];
  const occupied = [];
  const collect = (expression, kind) => {
    for (const match of segment.matchAll(expression)) {
      const value = match[1].replace(/[.,:;]+$/, '');
      const start = (match.index ?? 0) + match[0].indexOf(match[1]);
      const end = start + match[1].length;
      tokens.push({ kind, value });
      occupied.push([start, end]);
    }
  };
  const pathCharacters = '[A-Za-z0-9_@%+.,/(){}\\[\\]*\\-]+';
  collect(new RegExp(`(?:^|[\\s"'\`(])((?:\\.github|github|backend|frontend|website|infra|docs|\\.agents|\\.claude)/${pathCharacters})`, 'g'), 'root');
  collect(new RegExp(`(?:^|[\\s"'\`(])((?:src|app|components|services|hooks|schemas|types|mocks|e2e|db/migration|public|settings|domain|contexts|tests?|config)/${pathCharacters})`, 'g'), 'relative');
  const basenamePattern = /(?:^|[\s"'`(])((?:[A-Za-z0-9_@+.-]+\.(?:java|kt|kts|xml|properties|ya?ml|json|sql|sh|ts|tsx|js|jsx|mjs|cjs|css|scss|html|md)|Makefile|Dockerfile(?:[A-Za-z0-9_.-]*)))(?=$|[\s"'`,);])/g;
  for (const match of segment.matchAll(basenamePattern)) {
    const start = (match.index ?? 0) + match[0].indexOf(match[1]);
    const end = start + match[1].length;
    if (!occupied.some(([from, to]) => start >= from && end <= to)) {
      tokens.push({ kind: 'basename', value: match[1] });
    }
  }
  return tokens;
}

export function validateCodeReferences(value, filePath, repositoryRoot, repositoryIndex) {
  const errors = [];
  const index = repositoryIndex ?? buildRepositoryPathIndex(repositoryRoot);
  for (const segment of value.split(',')) {
    const semantic = normalize(segment);
    if (/(?:^|\b)(?:n\/?a|not applicable|nao aplicavel|planned|planejad\w*|futur\w*|histor\w*|supersed\w*|substitu\w*|generated|gerad\w*|conditional|condicional|removed|removid\w*|to-be)(?:\b|$)/.test(semantic)) {
      continue;
    }
    for (const token of codeReferenceTokens(segment)) {
      const referenced = token.value;
      if (referenced.includes('...')) {
        errors.push(`${relative(repositoryRoot, filePath)}: code_references usa reticencias ambiguas: ${referenced}`);
        continue;
      }
      if (/[{}<>\[\]*]/.test(referenced)) continue;
      if (/(?:^|\/)(?:target|\.next|dist|build|out|coverage)(?:\/|$)/.test(referenced)) continue;
      const exists = token.kind === 'root'
        ? index.pathSet.has(referenced.replace(/\/$/, ''))
        : token.kind === 'relative'
          ? hasSuffix(index, referenced)
          : index.basenames.has(referenced);
      if (!exists) {
        const resolution = token.kind === 'root' ? 'caminho' : token.kind === 'relative' ? 'sufixo' : 'basename';
        errors.push(`${relative(repositoryRoot, filePath)}: code_references aponta para ${resolution} ausente sem qualificacao: ${referenced}`);
      }
    }
  }
  return errors;
}

function validateMetadataReferences(content, filePath, repositoryRoot, repositoryIndex) {
  const errors = [];
  for (const field of ['related_files']) {
    for (const referenced of metadataPathReferences(content, field)) {
      if (!fs.existsSync(path.join(repositoryRoot, referenced))) {
        errors.push(`${relative(repositoryRoot, filePath)}: ${field} aponta para caminho ausente: ${referenced}`);
      }
    }
  }
  const codeReferences = extractField(content, FIELD_ALIASES.code_references);
  if (codeReferences) {
    errors.push(...validateCodeReferences(codeReferences, filePath, repositoryRoot, repositoryIndex));
  }
  return errors;
}

function expectedIdForFile(filename) {
  const patterns = [
    /^(ADR-\d{4})-/, /^(PRD-\d{5})-/, /^(REQ-\d{5})-/, /^(UC-\d{5})-/,
    /^(TP-\d{5})-/, /^(LL-(?:BE|FE)-\d{5})-/,
    /^(RPT-\d{4})-/, /^(TPL-\d{5})-/, /^(ANL-\d{5})-/
  ];
  for (const pattern of patterns) {
    const match = filename.match(pattern);
    if (match) return match[1];
  }
  if (/^IP-(?:BE|FE)-/.test(filename)) return filename.replace(/\.md$/, '');
  return null;
}

const COLLECTION_RULES = [
  { directory: 'docs/adrs', filename: /^ADR-\d{4}-.+\.md$/, nature: 'Decisao', statuses: ['Proposed', 'Accepted', 'Rejected', 'Superseded', 'Partially Superseded', 'Deprecated'] },
  { directory: 'docs/product_requirements', filename: /^PRD-\d{5}-.+\.md$/, nature: 'Requisito', statuses: ['Draft', 'In Review', 'Validated', 'Deprecated'] },
  { directory: 'docs/requirements', filename: /^REQ-\d{5}-.+\.md$/, nature: 'Requisito', statuses: ['Draft', 'Accepted', 'Approved', 'Implemented', 'Deprecated'] },
  { directory: 'docs/use_cases', filename: /^UC-\d{5}-.+\.md$/, nature: 'Requisito', statuses: ['Draft', 'In Review', 'Accepted', 'Approved', 'Implemented', 'Deprecated'] },
  { directory: 'docs/analysis', filename: /^(?:ANL-\d{5}-.+|analysis-.+|e2e-.+-analysis)\.md$/, nature: 'Contexto', statuses: ['Draft', 'Current', 'Historical'] },
  { directory: 'docs/task_plans', filename: /^(?:TP-\d{5}-.+|phase-[a-z0-9-]+-specification-index)\.md$/, nature: 'Plano', statuses: ['Proposed', 'Approved', 'In Progress', 'Completed', 'Cancelled'] },
  { directory: 'docs/task_plans/implementation_plans/backend', filename: /^IP-BE-\d+(?:\.\d+){2,3}-.+\.md$/, nature: 'Plano', statuses: ['Pending', 'In Progress', 'Done', 'Superseded'] },
  { directory: 'docs/task_plans/implementation_plans/frontend', filename: /^IP-FE-\d+(?:\.\d+){2,3}-.+\.md$/, nature: 'Plano', statuses: ['Pending', 'In Progress', 'Done', 'Superseded'] },
  { directory: 'docs/task_plans/implementation_plans/infra', filename: /^TEMPLATE\.md$/, nature: 'Template', statuses: ['Active'] },
  { directory: 'docs/task_plans/implementation_plans/infra', filename: /^IP-INFRA-\d+(?:\.\d+){2,3}-.+\.md$/, nature: 'Plano', statuses: ['Proposed', 'Approved', 'In Progress', 'Completed', 'Cancelled'] },
  { directory: 'docs/lessons_learned/backend', filename: /^LL-BE-\d{5}-.+\.md$/, nature: 'Historico', statuses: ['Draft', 'Validated', 'Deprecated'] },
  { directory: 'docs/lessons_learned/frontend', filename: /^LL-FE-\d{5}-.+\.md$/, nature: 'Historico', statuses: ['Draft', 'Validated', 'Deprecated'] },
  { directory: 'docs/reports', filename: /^RPT-\d{4}-.+\.md$/, nature: 'Historico', statuses: ['Draft', 'Final', 'Superseded'] },
  { directory: 'docs/templates', filename: /^TPL-\d{5}-.+\.md$/, nature: 'Template', statuses: ['Draft', 'Active', 'Deprecated'] },
  { directory: 'docs/agents/standards', filename: /^(?:[a-z0-9]+(?:-[a-z0-9]+)*-standard|software-engineering-lifecycle)\.md$/, nature: 'Regra', statuses: ['Draft', 'Active', 'Deprecated'] }
];

const NATURE_RULES = [
  { pattern: /^docs\/agents\/[^/]+\.md$/, nature: 'Regra', statuses: ['Active', 'Deprecated', 'Disabled'] },
  { pattern: /^docs\/onboard\/[^/]+\.md$/, nature: 'Regra', statuses: ['Draft', 'Active', 'Historical', 'Deprecated'] },
  { pattern: /^docs\/compliance\/waba-number-integration-guide\.md$/, nature: 'Regra', statuses: ['Draft', 'Active', 'Historical'] },
  { pattern: /^docs\/(?:analysis|architecture|business|compliance)\//, nature: 'Contexto' },
  { pattern: /^docs\/settings\/[^/]+\.md$/, nature: 'Regra', statuses: ['Draft', 'Active', 'Deprecated'] }
];

function statusMatches(value, allowed) {
  const actual = normalize(value);
  return allowed.some((candidate) => {
    const base = normalize(candidate);
    return actual === base || actual.startsWith(`${base} `);
  });
}

export function validateCollectionSemantics(content, filePath, repositoryRoot) {
  const errors = [];
  const rel = relative(repositoryRoot, filePath);
  if (path.basename(filePath) === 'README.md') return errors;
  const directory = path.posix.dirname(rel);
  const collectionRules = COLLECTION_RULES.filter((rule) => rule.directory === directory);
  const collection = collectionRules.find((rule) => rule.filename.test(path.basename(filePath)));
  const fallback = NATURE_RULES.find((rule) => rule.pattern.test(rel));
  const rule = collection ?? fallback;
  if (collectionRules.length > 0 && !collection) {
    errors.push(`${rel}: nome fora da convencao da colecao`);
  }
  if (!rule) return errors;

  const nature = extractField(content, FIELD_ALIASES.primary_nature);
  if (nature && normalize(nature) !== normalize(rule.nature)) {
    errors.push(`${rel}: primary_nature ${nature} difere da natureza ${rule.nature} da colecao`);
  }
  const status = extractField(content, FIELD_ALIASES.status);
  if (status && rule.statuses && !statusMatches(status, rule.statuses)) {
    errors.push(`${rel}: status ${status} nao e permitido pela colecao`);
  }
  return errors;
}

export function validateProductRequirementsGovernance(artifacts) {
  const errors = [];
  const requireMarkers = (content, relativePath, markers) => {
    const normalizedContent = normalize(content).replace(/\s+/g, ' ');
    for (const marker of markers) {
      if (!normalizedContent.includes(normalize(marker).replace(/\s+/g, ' '))) {
        errors.push(`${relativePath}: contrato de PRD omite ${marker}`);
      }
    }
  };

  requireMarkers(artifacts.index ?? '', 'docs/product_requirements/README.md', [
    'PRD-NNNNN-short-title.md', 'Draft', 'In Review', 'Validated', 'Deprecated',
    'Product Definition Gate', 'TPL-00012-PromptTemplateCriarPRD.md',
    'não copia seus acceptance criteria', 'referencia casos de uso sem recontar fluxos',
    'referencia ADRs sem decidir arquitetura', 'F-<CONTEXTO>-NNN',
    'referência a IDs/seção de aceite'
  ]);
  requireMarkers(artifacts.template ?? '', 'docs/templates/TPL-00012-PromptTemplateCriarPRD.md', [
    'docs/product_requirements/PRD-NNNNN-<short-title>.md',
    '## 2. Problem and evidence', '## 3. Audience and value',
    '## 4. Objectives and outcomes', '## 5. Product scope and limits',
    '## 6. Product validation criteria', '## 7. Success metrics',
    '## 8. Product hypotheses', '## 9. Requirement map',
    '### 9.1 Feature inventory and acceptance coverage',
    '## 13. Open questions and decisions', '## 14. Approval and readiness',
    'Product Definition Gate', 'vários `REQ-NNNNN`',
    'não copie acceptance criteria', 'não redefine decisões arquiteturais',
    'O agente não promove seu próprio documento a `Validated`',
    'F-<CONTEXTO>-NNN', 'IDs ausentes — lacuna documental'
  ]);

  for (const prd of artifacts.prds ?? []) {
    const relativePath = prd.path ?? '<prd>';
    const content = prd.content ?? '';
    requireMarkers(content, relativePath, [
      '## 2. Problem and evidence', '## 3. Audience and value',
      '## 4. Objectives and outcomes', '## 5. Product scope and limits',
      '## 6. Product validation criteria', '## 7. Success metrics',
      '## 8. Product hypotheses', '## 9. Requirement map',
      '### 9.1 Feature inventory and acceptance coverage',
      '## 10. Use cases and decisions by reference',
      '## 11. Current phase assessment', '## 13. Open questions and decisions',
      '## 14. Approval and readiness', 'Product Definition Gate'
    ]);
    const requirements = new Set(content.match(/\bREQ-\d{5}\b/g) ?? []);
    if (requirements.size < 2) {
      errors.push(`${relativePath}: PRD deve agrupar e apontar para varios REQ-NNNNN`);
    }
    const featureRows = content.split(/\r?\n/).filter((line) =>
      /^\|\s*`?F-[A-Z0-9]+-\d{3}`?\s*\|/.test(line)
    );
    if (featureRows.length === 0) {
      errors.push(`${relativePath}: PRD nao possui feature ID no formato F-<CONTEXTO>-NNN`);
    }
    const featureIds = new Set();
    for (const row of featureRows) {
      const cells = row.split('|').slice(1, -1).map((cell) => cell.trim());
      const featureId = cells[0]?.replaceAll('`', '') ?? '';
      if (featureIds.has(featureId)) {
        errors.push(`${relativePath}: feature ID duplicado: ${featureId}`);
      }
      featureIds.add(featureId);
      if (!cells[1]) {
        errors.push(`${relativePath}: ${featureId} nao declara resultado de produto`);
      }
      if (!/\bREQ-\d{5}\b/.test(cells[2] ?? '')) {
        errors.push(`${relativePath}: ${featureId} nao referencia REQ-NNNNN`);
      }
      const acceptance = cells[3] ?? '';
      const normalizedAcceptance = normalize(acceptance);
      const hasAcceptanceLink = /\]\(\.\.\/requirements\/req-\d{5}-[^)#]+\.md#[^)]*(?:acceptance-criteria|criterios-de-aceite)\)/.test(normalizedAcceptance);
      const hasAcceptanceIds = /\bAC-[A-Z0-9]+(?:-[A-Z0-9]+)*\b/.test(acceptance);
      const recordsMissingIds = normalizedAcceptance.includes('ids ausentes') &&
        normalizedAcceptance.includes('lacuna documental');
      if (!hasAcceptanceLink || (!hasAcceptanceIds && !recordsMissingIds)) {
        errors.push(`${relativePath}: ${featureId} nao referencia IDs ou secao canonica de aceite`);
      }
      if (/\b(?:given|when|then|dado|quando|entao)\b/.test(normalizedAcceptance)) {
        errors.push(`${relativePath}: ${featureId} duplica texto de acceptance criteria`);
      }
      if (!cells[4]) {
        errors.push(`${relativePath}: ${featureId} nao declara estado documental`);
      }
    }
    if (/^#{2,6}\s+(?:Acceptance Criteria|Main Flow|Alternative Flows?|Architecture)\b/im.test(content)) {
      errors.push(`${relativePath}: PRD duplica criterio, fluxo ou decisao de fonte especializada`);
    }
    const status = extractField(content, FIELD_ALIASES.status);
    if (statusMatches(status ?? '', ['Validated'])) {
      if (!/\*\*Product Definition Gate:\*\*\s*`PASS`/i.test(content)) {
        errors.push(`${relativePath}: PRD Validated nao publica Product Definition Gate PASS`);
      }
      if (/\|\s*(?:Proposed|Open)\s*\|/i.test(content) || /Pending review/i.test(content)) {
        errors.push(`${relativePath}: PRD Validated ainda possui hipotese, pergunta ou aprovacao pendente`);
      }
    } else if (statusMatches(status ?? '', ['Draft', 'In Review']) &&
               !/\*\*Product Definition Gate:\*\*\s*`BLOCKED`/i.test(content)) {
      errors.push(`${relativePath}: PRD nao validado deve publicar Product Definition Gate BLOCKED`);
    }
  }
  if ((artifacts.prds ?? []).length === 0) {
    errors.push('docs/product_requirements/: colecao ativa sem PRD');
  }
  return errors;
}

function validateKnownIdentity(content, filePath, repositoryRoot) {
  const errors = [];
  const filename = path.basename(filePath);
  const expected = expectedIdForFile(filename);
  if (!expected) return errors;
  const actual = extractField(content, FIELD_ALIASES.document_id);
  if (actual !== expected) {
    errors.push(`${relative(repositoryRoot, filePath)}: document_id ${JSON.stringify(actual)} nao corresponde a ${expected}`);
  }
  const firstHeading = content.match(/^(?:\uFEFF)?#\s+(.+)$/m)?.[1] ?? '';
  const headingExpected = /^IP-(?:BE|FE)-/.test(expected)
    ? expected.match(/^(IP-(?:BE|FE)-\d+(?:\.\d+){2,3})/)?.[1] ?? expected
    : expected;
  if (!new RegExp(`^${escapeRegex(headingExpected)}(?:$|\\s|[—–:-])`).test(firstHeading)) {
    errors.push(`${relative(repositoryRoot, filePath)}: primeiro H1 nao publica ${headingExpected}`);
  }
  return errors;
}

export function validateSkillFile(content, directoryName, relativePath = '<skill>') {
  const errors = [];
  const frontmatter = content.match(/^---\r?\n([\s\S]*?)\r?\n---/);
  if (!frontmatter) return [`${relativePath}: frontmatter YAML ausente`];
  const scalar = (key) => {
    const value = frontmatter[1].match(new RegExp(`^${key}:\\s*(.+)\\s*$`, 'm'))?.[1]?.trim();
    if (!value) return null;
    const quoted = value.match(/^(["'])([\s\S]*)\1$/);
    return quoted ? quoted[2] : value;
  };
  const name = scalar('name');
  const description = scalar('description');
  if (!name) errors.push(`${relativePath}: frontmatter name ausente`);
  if (!description) errors.push(`${relativePath}: frontmatter description ausente`);
  if (name && name !== directoryName) errors.push(`${relativePath}: name ${name} difere do diretorio ${directoryName}`);
  if (name && !/^[a-z0-9]+(?:-[a-z0-9]+)*$/.test(name)) errors.push(`${relativePath}: name nao usa minusculas e hifens`);
  if (description && description.length >= 500) errors.push(`${relativePath}: description excede 500 caracteres`);
  if (!/^#\s+\S/m.test(content.replace(/^---\r?\n[\s\S]*?\r?\n---\r?\n/, ''))) {
    errors.push(`${relativePath}: titulo H1 ausente`);
  }
  const normalized = normalize(content);
  const requiredConcepts = [
    ['objetivo', /\b(?:objetivo|objective)\b/],
    ['gatilhos', /\b(?:gatilho|gatilhos|trigger|triggers)\b/],
    ['escopo', /\b(?:escopo|scope)\b/],
    ['nao-objetivos', /\b(?:nao-objetiv\w*|non-objectiv\w*)\b/],
    ['pre-condicoes', /\b(?:pre-condic\w*|precondition\w*)\b/],
    ['procedimento', /\b(?:procedimento|procedure)\b/],
    ['limites de seguranca', /(?:limites? de seguranca|safety limits?)/],
    ['entradas', /\b(?:entradas|inputs?)\b/],
    ['saidas', /\b(?:saidas|outputs?)\b/],
    ['evidencias', /\b(?:evidencias|evidence)\b/],
    ['criterio de conclusao', /(?:criterio de conclusao|completion criteri\w*)/],
    ['owner', /(?:^|\n)\s*(?:-\s*)?owner\s*:/m],
    ['status', /(?:^|\n)\s*(?:-\s*)?status\s*:/m]
  ];
  for (const [concept, expression] of requiredConcepts) {
    if (!expression.test(normalized)) errors.push(`${relativePath}: contrato operacional omite ${concept}`);
  }
  if (content.split(/\r?\n/).length > 200 || Buffer.byteLength(content) > 16 * 1024) {
    if (!/justificativa|granularidade/i.test(content)) errors.push(`${relativePath}: SKILL.md excede limite sem justificativa`);
  }
  return errors;
}

export function validateGovernanceSkill(content, relativePath = '<governance-skill>') {
  const errors = [];
  if (!normalize(content).includes('adr-0000')) {
    errors.push(`${relativePath}: skill de governanca nao referencia ADR-0000`);
  }
  if (!content.includes('./infra/scripts/validate-docs.sh')) {
    errors.push(`${relativePath}: skill de governanca nao usa ./infra/scripts/validate-docs.sh`);
  }
  if (!content.includes('Section 10.11.1')) {
    errors.push(`${relativePath}: skill de governanca nao orienta o bootstrap do wrapper ausente`);
  }
  return errors;
}

export function validateQualityGateSkill(content, relativePath = '<quality-gate-skill>') {
  const errors = [];
  const markers = [
    'ADR-0000', 'Section 10.12', 'software-quality-standard.md',
    'implementation-readiness-standard.md',
    './infra/scripts/validate-quality-gates.sh', 'focused', 'pr', 'release',
    'PASS', 'FAIL', 'BLOCKED', 'implementation-readiness', 'READY',
    'task ID', 'Phase 7', 'não decomponha retrospectivamente'
  ];
  for (const marker of markers) {
    if (!content.includes(marker)) {
      errors.push(`${relativePath}: skill quality-gate omite ${marker}`);
    }
  }
  if (/\b\d+(?:[.,]\d+)?\s*%|[≥>]\s*\d+/u.test(content)) {
    errors.push(`${relativePath}: skill quality-gate duplica limiar numerico dos standards`);
  }
  return errors;
}

export function validateImplementationReadinessSkill(
  content,
  relativePath = '<implementation-readiness-skill>'
) {
  const errors = [];
  const markers = [
    'ADR-0000', 'Section 10.13', 'implementation-readiness-standard.md',
    'READY', 'BLOCKED', 'Assumption', 'Open Question', 'Gate Audit',
    'Acceptance Tests', 'Prohibited', 'Mandatory', 'Definition of Done',
    'perguntar ao humano', 'não existe waiver', 'AC aplicável', 'teste/evidência',
    'PRD aplicável', 'PRD not applicable', 'Product Hypothesis',
    'Granularidade / Decomposição', 'decomponha semanticamente', 'pai → filhos',
    'reexecute o gate para cada unidade'
  ];
  for (const marker of markers) {
    if (!content.toLocaleLowerCase('pt-BR').includes(marker.toLocaleLowerCase('pt-BR'))) {
      errors.push(`${relativePath}: skill implementation-readiness omite ${marker}`);
    }
  }
  const ordered = ['Gate Audit', 'Acceptance Tests', 'Prohibited', 'Mandatory', 'Definition of Done'];
  let previous = -1;
  for (const marker of ordered) {
    const current = content.indexOf(marker, previous + 1);
    if (current === -1) {
      errors.push(`${relativePath}: ordem da auditoria deve ser ${ordered.join(' -> ')}`);
      break;
    }
    previous = current;
  }
  return errors;
}

export function validateImplementationReadinessGovernance(artifacts) {
  const errors = [];
  const required = (content, relativePath, markers) => {
    const normalizedContent = normalize(content).replace(/\s+/g, ' ');
    for (const marker of markers) {
      const normalizedMarker = normalize(marker).replace(/\s+/g, ' ');
      if (!normalizedContent.includes(normalizedMarker)) {
        errors.push(`${relativePath}: governanca de readiness omite ${marker}`);
      }
    }
  };

  required(artifacts.adr, 'ADR-0000', [
    '## 10.13 Implementation Readiness Gate do C.L.E.A.R.',
    '### 10.13.1 Invariante dura e estados',
    '### 10.13.5 Scaffold portatil da skill',
    'docs/agents/standards/implementation-readiness-standard.md',
    '.agents/skills/implementation-readiness/SKILL.md',
    '.claude/skills/implementation-readiness/SKILL.md',
    'Nao existe waiver', 'User Story View', 'US-NNN', 'matriz AC',
    'Product Definition Gate', 'TPL-00012',
    '#### 10.13.1.1 Decomposicao semantica automatica',
    'Granularity / Decomposition', 'pai → filhos',
    'Falha de granularidade NAO e um motivo final de `BLOCKED`'
  ]);
  required(artifacts.standard, 'implementation-readiness-standard.md', [
    'READY', 'BLOCKED', 'Assumption', 'Open Question', 'User Story View',
    'Product Definition', 'PRD', 'Validated', 'Product Hypothesis',
    'AC → fluxo → teste/evidência',
    'What', 'Where', 'Depends on', 'Reuses', 'Requirements', 'Gate Audit',
    'Acceptance Tests', 'Prohibited', 'Mandatory', 'Definition of Done',
    'não despachar implementação', 'Granularidade / Decomposição',
    'Decomposição semântica automática', 'pai → filhos',
    'reexecutar o IRG separadamente para cada unidade'
  ]);
  required(artifacts.requirementTemplate, 'TPL-00003', [
    'User Story View', 'Assumptions and Open Questions', 'Readiness Declaration',
    'perguntar ao humano'
  ]);
  required(artifacts.useCaseTemplate, 'TPL-00004', [
    'User Story View', 'Assumptions', 'Open Questions', 'Implementation Readiness',
    'Assumption não é precondition', 'Acceptance Criteria Coverage',
    'Planned Test or Evidence'
  ]);
  required(artifacts.prdTemplate, 'TPL-00012', [
    'Product Definition Gate', 'Product hypotheses', 'Success metrics',
    'Requirement map', 'Approval and readiness', 'O agente não promove'
  ]);

  for (const [relativePath, content] of [
    ['TPL-00005', artifacts.taskPlanTemplate],
    ['TPL-00006', artifacts.implementationPlanTemplate],
    ['TPL-00006.raw', artifacts.rawImplementationPlanTemplate]
  ]) {
    required(content, relativePath, [
      'Implementation Readiness Gate', 'What', 'Where', 'Depends on', 'Reuses',
      'Requirements', 'Gate Audit', 'Acceptance Tests', 'Prohibited', 'Mandatory',
      'Definition of Done', 'READY', 'BLOCKED', 'Granularity / Decomposition',
      'parent → child'
    ]);
    const ordered = ['Gate Audit', 'Acceptance Tests', 'Prohibited', 'Mandatory', 'Definition of Done'];
    let previous = -1;
    for (const marker of ordered) {
      const current = content.indexOf(marker, previous + 1);
      if (current === -1) {
        errors.push(`${relativePath}: ordem deve ser ${ordered.join(' -> ')}`);
        break;
      }
      previous = current;
    }
  }

  if (/\bUS-NNN\b/.test(artifacts.requirementTemplate) || /\bUS-NNN\b/.test(artifacts.useCaseTemplate)) {
    errors.push('TPL-00003/TPL-00004: referencia a artefato User Story autonomo e proibida');
  }

  required(artifacts.lifecycle, 'software-engineering-lifecycle.md', [
    'implementation-readiness', 'READY', 'Uncertainty Hard Gate', 'Finite Task Rule',
    'Product Definition Gate', 'PRD-NNNNN', 'Validated',
    'Automatic Semantic Decomposition Rule', 'parent → child',
    'return the work to Phase 7'
  ]);
  required(artifacts.orchestrator, 'AgentOrchestrator.md', [
    'Always audit implementation readiness', 'ask the human/owner', 'implementation-readiness',
    'Enforce Product Definition', 'PRD not applicable',
    'Automatically correct granularity', 'parent → child', 're-audits every child'
  ]);
  required(artifacts.requirementAgent, 'RequirementAgent.md', [
    'Classify and close uncertainty', 'Proposed', 'Open Question', 'eligibility `No`',
    'TPL-00012', 'never validate the PRD'
  ]);
  required(artifacts.codeGuardian, 'CodeGuardian.md', [
    'READINESS EVIDENCE', 'blocking process', 'AgentOrchestrator',
    'Divergent Atomic Scope', 'return to Phase 7', 'Do not'
  ]);
  for (const [relativePath, content] of [
    ['AGENTS.md', artifacts.agentsAdapter],
    ['CLAUDE.md', artifacts.claudeAdapter]
  ]) {
    required(content, relativePath, [
      'implementation-readiness', 'READY', 'Open Question', 'humano/owner',
      'PRD not applicable', 'Validated', 'Falha de granularidade',
      'pai → filhos', 'Quality Gate'
    ]);
  }
  return errors;
}

export function validateGovernanceEntrypoint(adrContent, wrapperContent) {
  const errors = [];
  if (!adrContent.includes('`infra/scripts/validate-docs.sh`') ||
      !adrContent.includes('./infra/scripts/validate-docs.sh')) {
    errors.push('ADR-0000: entrypoint canonico agregado nao e infra/scripts/validate-docs.sh');
  }
  const portableAdrMarkers = [
    '### 10.11.1 Bootstrap tecnico portatil do wrapper',
    'criar `infra/scripts/`',
    'chmod +x infra/scripts/validate-docs.sh',
    '#!/usr/bin/env bash',
    'set -uo pipefail',
    'governance_validator="$repo_root/docs/scripts/validate-documentation-governance.mjs"',
    'node "$governance_validator" --root "$repo_root" || exit 1'
  ];
  for (const marker of portableAdrMarkers) {
    if (!adrContent.includes(marker)) {
      errors.push(`ADR-0000: bootstrap portatil do wrapper omite ${marker}`);
    }
  }
  const portableWrapperMarkers = [
    '#!/usr/bin/env bash',
    'set -uo pipefail',
    'governance_validator="$repo_root/docs/scripts/validate-documentation-governance.mjs"',
    'node --test "$governance_validator_test"',
    'node "$governance_validator" --root "$repo_root"'
  ];
  for (const marker of portableWrapperMarkers) {
    if (!wrapperContent.includes(marker)) {
      errors.push(`infra/scripts/validate-docs.sh: nucleo portatil omite ${marker}`);
    }
  }
  for (const internalArtifact of [
    'validate-documentation-governance.test.mjs',
    'validate-documentation-governance.mjs'
  ]) {
    if (!wrapperContent.includes(internalArtifact)) {
      errors.push(`infra/scripts/validate-docs.sh: nao executa ${internalArtifact}`);
    }
  }
  return errors;
}

export function validateQualityGateScaffold(
  adrContent,
  executorContent,
  contractTestContent,
  wrapperContent,
  standardContent
) {
  const errors = [];
  const adrMarkers = [
    '## 10.12 Gate executavel Teste x QA do C.L.E.A.R.',
    '### 10.12.1 Ordem obrigatoria do scaffold',
    '### 10.12.2 Interface e modo de uso',
    '### 10.12.3 Bootstrap tecnico portatil do Quality Gate',
    '#### 10.12.3.1 Teste de contrato portatil integral',
    'docs/agents/standards/software-quality-standard.md',
    '.agents/skills/quality-gate/SKILL.md',
    '.claude/skills/quality-gate/SKILL.md',
    'infra/scripts/validate-quality-gates.sh',
    'infra/scripts/tests/validate-quality-gates-test.sh',
    'QUALITY_GATE_RESULT=BLOCKED', '--root',
    'fixture_root="$(mktemp -d /tmp/quality-gate-test.XXXXXX)"',
    'trap cleanup EXIT', "assert_exit 0 'all PR dry-run'",
    "assert_exit 1 'missing backend coverage blocks'", '7 scenarios',
    'implementation-readiness', 'Phase 7',
    '#!/usr/bin/env bash',
    'set -uo pipefail'
  ];
  for (const marker of adrMarkers) {
    if (!adrContent.includes(marker)) errors.push(`ADR-0000: scaffold do Quality Gate omite ${marker}`);
  }

  const portableTestHeading = '#### 10.12.3.1 Teste de contrato portatil integral';
  const headingIndex = adrContent.indexOf(portableTestHeading);
  if (headingIndex >= 0) {
    const fenceStart = adrContent.indexOf('```bash\n', headingIndex);
    const codeStart = fenceStart >= 0 ? fenceStart + '```bash\n'.length : -1;
    const fenceEnd = codeStart >= 0 ? adrContent.indexOf('\n```', codeStart) : -1;
    if (fenceStart < 0 || fenceEnd < 0) {
      errors.push('ADR-0000: teste portatil integral do Quality Gate nao possui bloco bash completo');
    } else {
      const portableBody = adrContent.slice(codeStart, fenceEnd).replace(/\r\n/g, '\n').trimEnd();
      const versionedBody = contractTestContent.replace(/\r\n/g, '\n').trimEnd();
      if (portableBody !== versionedBody) {
        errors.push('ADR-0000: corpo integral do teste portatil diverge de infra/scripts/tests/validate-quality-gates-test.sh');
      }
    }
  }

  const executorMarkers = [
    '#!/usr/bin/env bash', 'set -uo pipefail', '--scope', '--level', '--focus',
    '--dry-run', '--root', 'focused', 'pr', 'release', 'QUALITY_GATE_RESULT=PASS',
    'QUALITY_GATE_RESULT=FAIL', 'QUALITY_GATE_RESULT=BLOCKED', '.env.local'
  ];
  for (const marker of executorMarkers) {
    if (!executorContent.includes(marker)) {
      errors.push(`infra/scripts/validate-quality-gates.sh: contrato omite ${marker}`);
    }
  }
  if (/(?:^|[;&|()]|\s)git\s+(?:diff|status|show|log|ls-files)\b/m.test(executorContent)) {
    errors.push('infra/scripts/validate-quality-gates.sh: descoberta por Git e proibida');
  }

  for (const marker of [
    '--scope', '--level', '--dry-run', '--root', 'QUALITY_GATE_RESULT=BLOCKED',
    'missing backend coverage blocks', 'local env blocks build', '7 scenarios'
  ]) {
    if (!contractTestContent.includes(marker)) {
      errors.push(`infra/scripts/tests/validate-quality-gates-test.sh: contrato omite ${marker}`);
    }
  }
  if (!wrapperContent.includes('validate-quality-gates-test.sh')) {
    errors.push('infra/scripts/validate-docs.sh: nao executa validate-quality-gates-test.sh');
  }
  for (const marker of [
    'A1 — Test Gate', 'A2 — Quality Gate', 'A3 — Security & Compliance Gate',
    'PASS', 'FAIL', 'BLOCKED', 'implementation-readiness', 'READY',
    'escopo atômico', 'Phase 7', 'não decompõe retrospectivamente'
  ]) {
    if (!standardContent.includes(marker)) {
      errors.push(`docs/agents/standards/software-quality-standard.md: omite ${marker}`);
    }
  }
  return errors;
}

function validateReadmeContract(content, filePath, repositoryRoot) {
  const errors = [];
  const rel = relative(repositoryRoot, filePath);
  if (!/(Conven[cç][aã]o|Nomes\s*:)/i.test(content)) errors.push(`${rel}: README nao declara convencao de nomes`);
  if (!/(Estados(?: permitidos)?\s*:|States\s*:|Estado dos arquivos\s*:)/i.test(content)) errors.push(`${rel}: README nao declara estados permitidos`);
  if (!/granular/i.test(content)) errors.push(`${rel}: README nao declara criterio de granularidade`);
  return errors;
}

const GENERATED_ARTIFACT_PATHS = {
  'TPL-00001': 'docs/agents/<AGENT_FILE_STEM>.md',
  'TPL-00003': 'docs/requirements/REQ-NNNNN-<short-title>.md',
  'TPL-00004': 'docs/use_cases/UC-NNNNN-<short-title>.md',
  'TPL-00008': 'docs/task_plans/implementation_plans/frontend/IP-FE-X.Y.Z.N-<short-title>.md',
  'TPL-00012': 'docs/product_requirements/PRD-NNNNN-<short-title>.md'
};

export function validateGeneratedArtifactPath(content, templateId, relativePath = '<template>') {
  const generatedPath = GENERATED_ARTIFACT_PATHS[templateId];
  if (generatedPath && !content.includes(generatedPath)) {
    return [`${relativePath}: convencao gerada omite caminho ${generatedPath}`];
  }
  return [];
}

export function validateOpenApiTemplate(content, relativePath = '<openapi-template>') {
  const errors = [];
  for (const marker of [
    'openapi: 3.1.0', 'x-document-metadata:', 'documentId:',
    'primaryNature: Contrato', 'owner:', 'status: Draft', 'date:',
    'lastReviewed:', 'normativeBaseline:', 'relatedFiles:', 'x-change-log:',
    'operationId:', 'security:', 'x-required-roles:', 'x-required-authorities:',
    'application/problem+json'
  ]) {
    if (!content.includes(marker)) {
      errors.push(`${relativePath}: esqueleto OpenAPI omite ${marker}`);
    }
  }
  if (!/README\.md/i.test(content) || !/na mesma (?:altera[cç][aã]o|mudan[cç]a)/i.test(content)) {
    errors.push(`${relativePath}: template OpenAPI nao exige indexacao imediata`);
  }
  return errors;
}

function validateTemplates(repositoryRoot) {
  const errors = [];
  const templateRoot = path.join(repositoryRoot, 'docs/templates');
  const templates = fs.readdirSync(templateRoot, { withFileTypes: true })
    .filter((entry) => entry.isFile() && /^TPL-\d{5}-.+\.md$/.test(entry.name))
    .map((entry) => `docs/templates/${entry.name}`)
    .sort();
  const generatedContracts = {
    'TPL-00001': { nature: 'Regra', documentId: '<AGENT_FILE_STEM>', heading: /^#\s+<AGENT_FILE_STEM>(?:\s|—)/m },
    'TPL-00002': { nature: 'Decisao', documentId: 'ADR-NNNN', heading: /^#\s+ADR-NNNN\b/m },
    'TPL-00003': { nature: 'Requisito', documentId: 'REQ-NNNNN', heading: /^#\s+REQ-NNNNN\b/m },
    'TPL-00004': { nature: 'Requisito', documentId: 'UC-NNNNN', heading: /^#\s+UC-NNNNN\b/m },
    'TPL-00005': { nature: 'Plano', documentId: 'TP-NNNNN', heading: /^#\s+TP-NNNNN\b/m },
    'TPL-00006': { nature: 'Plano', documentId: 'IP-AREA-X.Y.Z[.N]-<short-description>', heading: /^#\s+IP-AREA-X\.Y\.Z/m },
    'TPL-00007': { nature: 'Historico', documentId: 'RPT-NNNN', heading: /^#\s+RPT-NNNN\b/m },
    'TPL-00008': { nature: 'Plano', documentId: 'IP-FE-X.Y.Z.N-short-title', heading: /^#\s+IP-FE-X\.Y\.Z/m },
    'TPL-00009': { nature: 'Historico', documentId: 'LL-AREA-NNNNN', heading: /^#\s+LL-AREA-NNNNN\b/m },
    'TPL-00010': { nature: 'Contexto', documentId: 'BUSINESS-SKILL-<ID>', heading: /^#\s+Skill de neg[oó]cio\b/m },
    'TPL-00012': { nature: 'Requisito', documentId: 'PRD-NNNNN', heading: /^#\s+PRD-NNNNN\b/m }
  };
  const generatedLifecycles = {
    'TPL-00002': ['Proposed', 'Accepted', 'Rejected', 'Superseded', 'Partially Superseded', 'Deprecated'],
    'TPL-00003': ['Draft', 'Accepted', 'Approved', 'Implemented', 'Deprecated'],
    'TPL-00004': ['Draft', 'In Review', 'Accepted', 'Approved', 'Implemented', 'Deprecated'],
    'TPL-00005': ['Proposed', 'Approved', 'In Progress', 'Completed', 'Cancelled'],
    'TPL-00006': ['Pending', 'In Progress', 'Done', 'Superseded'],
    'TPL-00007': ['Draft', 'Final', 'Superseded'],
    'TPL-00009': ['Draft', 'Validated', 'Deprecated']
  };
  for (const template of templates) {
    const absolute = path.join(repositoryRoot, template);
    if (!fs.existsSync(absolute)) continue;
    const content = fs.readFileSync(absolute, 'utf8');
    const body = content.replace(/^---\r?\n[\s\S]*?\r?\n---\r?\n/, '');
    const id = path.basename(template).match(/^(TPL-\d{5})-/)?.[1];
    if (id === 'TPL-00011') {
      errors.push(...validateOpenApiTemplate(body, template));
    } else {
      for (const [field, aliases] of Object.entries(FIELD_ALIASES)) {
        if (!extractField(body, aliases, Number.POSITIVE_INFINITY)) {
          errors.push(`${template}: template gerado nao publica ${field}`);
        }
      }
    }
    const generated = generatedContracts[id];
    if (generated) {
      const nature = extractField(body, FIELD_ALIASES.primary_nature, Number.POSITIVE_INFINITY);
      if (normalize(nature ?? '') !== normalize(generated.nature)) {
        errors.push(`${template}: artefato gerado usa natureza ${JSON.stringify(nature)} em vez de ${generated.nature}`);
      }
      const documentId = extractField(body, FIELD_ALIASES.document_id, Number.POSITIVE_INFINITY);
      if (documentId !== generated.documentId) {
        errors.push(`${template}: artefato gerado usa document_id ${JSON.stringify(documentId)} em vez de ${generated.documentId}`);
      }
      if (!generated.heading.test(body)) errors.push(`${template}: artefato gerado nao publica H1 canonico`);
    }
    const generatedStatus = extractField(body, FIELD_ALIASES.status, Number.POSITIVE_INFINITY);
    if (generatedStatus && /[✅🔄❌⬜]/u.test(generatedStatus)) {
      errors.push(`${template}: status gerado usa emoji em vez do estado canonico`);
    }
    if (id === 'TPL-00001' && /\b(?:Draft|Approved|Superseded)\b/.test(generatedStatus ?? '')) {
      errors.push(`${template}: lifecycle do agente diverge do catalogo`);
    }
    if (id === 'TPL-00009' && /norma reutiliz[aá]vel/i.test(body)) {
      errors.push(`${template}: licao gerada tenta introduzir regra normativa`);
    }
    for (const lifecycle of generatedLifecycles[id] ?? []) {
      if (!normalize(generatedStatus ?? '').includes(normalize(lifecycle))) {
        errors.push(`${template}: lifecycle gerado omite ${lifecycle}`);
      }
    }
    errors.push(...validateGeneratedArtifactPath(body, id, template));
    if (/(?:^|[\s`"'(])\/docs\//m.test(body)) {
      errors.push(`${template}: caminho documental usa /docs como raiz absoluta`);
    }
    if (!/README\.md/i.test(body) || !/na mesma (?:altera[cç][aã]o|mudan[cç]a)/i.test(body)) {
      errors.push(`${template}: template nao exige indexacao imediata na mesma alteracao`);
    }
  }

  const rawRoot = path.join(repositoryRoot, 'docs/templates/chat');
  for (const entry of fs.readdirSync(rawRoot, { withFileTypes: true })) {
    if (!entry.isFile() || !/^TPL-\d{5}-.+\.raw$/.test(entry.name)) continue;
    const rawPath = path.join(rawRoot, entry.name);
    const markdownName = entry.name.replace(/\.raw$/, '.md');
    if (!fs.existsSync(path.join(repositoryRoot, 'docs/templates', markdownName))) {
      errors.push(`docs/templates/chat/${entry.name}: variante sem template Markdown correspondente`);
    }
    errors.push(...validateRawTemplate(
      fs.readFileSync(rawPath, 'utf8'),
      `docs/templates/chat/${entry.name}`
    ));
    if (entry.name.startsWith('TPL-00006-')) {
      const raw = fs.readFileSync(rawPath, 'utf8');
      for (const lifecycle of generatedLifecycles['TPL-00006']) {
        if (!normalize(raw).includes(normalize(lifecycle))) {
          errors.push(`docs/templates/chat/${entry.name}: lifecycle gerado omite ${lifecycle}`);
        }
      }
    }
  }

  const skillTemplatePath = path.join(repositoryRoot, 'docs/templates/TPL-00010-PromptTemplateCriarSkill.md');
  if (fs.existsSync(skillTemplatePath)) {
    const operational = fs.readFileSync(skillTemplatePath, 'utf8').split('## Template B')[1] ?? '';
    const requiredMarkers = [
      '## Objetivo', '## Gatilhos e não-gatilhos', '## Escopo e pré-condições',
      '## Procedimento', '## Limites de segurança', '## Entradas, saídas e evidências',
      '## Governança operacional', '## Descoberta progressiva', '## Critério de conclusão',
      '- Non-objectives:', '- Owner:', '- Status:'
    ];
    for (const marker of requiredMarkers) {
      if (!operational.includes(marker)) {
        errors.push(`docs/templates/TPL-00010-PromptTemplateCriarSkill.md: skill operacional gerada nao publica ${marker}`);
      }
    }
  }

  const infraTemplate = 'docs/task_plans/implementation_plans/infra/TEMPLATE.md';
  const infraTemplatePath = path.join(repositoryRoot, infraTemplate);
  if (fs.existsSync(infraTemplatePath)) {
    const body = fs.readFileSync(infraTemplatePath, 'utf8').replace(/^---\r?\n[\s\S]*?\r?\n---\r?\n/, '');
    for (const [field, aliases] of Object.entries(FIELD_ALIASES)) {
      if (!extractField(body, aliases, Number.POSITIVE_INFINITY)) {
        errors.push(`${infraTemplate}: plano gerado nao publica ${field}`);
      }
    }
    if (!body.includes('status: Proposed')) errors.push(`${infraTemplate}: plano gerado nao nasce Proposed`);
    if (!/README\.md/i.test(body) || !/na mesma altera[cç][aã]o/i.test(body)) {
      errors.push(`${infraTemplate}: plano gerado nao exige indexacao imediata`);
    }
  }
  return errors;
}

export function validateRawTemplate(content, relativePath = '<raw-template>') {
  const errors = [];
  const normalized = normalize(content).replace(/\s+/g, ' ');
  for (const [field, aliases] of Object.entries(FIELD_ALIASES)) {
    if (!aliases.some((alias) => normalized.includes(normalize(alias)))) {
      errors.push(`${relativePath}: prompt raw nao exige ${field}`);
    }
  }
  if (!/(?:\bH1\b|^#\s+\S)/mi.test(content)) {
    errors.push(`${relativePath}: prompt raw nao exige titulo H1`);
  }
  if (!/\b(?:deve|must|required|obrig\w*)\b/i.test(normalized)) {
    errors.push(`${relativePath}: prompt raw nao formula o contrato como obrigacao`);
  }
  if (!/README\.md/i.test(content) || !/na mesma altera[cç][aã]o/i.test(content)) {
    errors.push(`${relativePath}: prompt raw nao exige indexacao imediata na mesma alteracao`);
  }
  if (/TPL-00001-.+\.raw$/.test(relativePath) &&
      !content.includes('docs/agents/<NomeDoAgente>.md')) {
    errors.push(`${relativePath}: variante nao publica o caminho canônico do agente`);
  }
  return errors;
}

function validateRuntimeAdapters(repositoryRoot) {
  const errors = [];
  const packages = ['backend', 'frontend', 'website', 'infra'];
  for (const packageName of packages) {
    const agents = path.join(repositoryRoot, packageName, 'AGENTS.md');
    const claude = path.join(repositoryRoot, packageName, 'CLAUDE.md');
    if (fs.existsSync(agents) && !fs.existsSync(claude)) {
      errors.push(`${packageName}/CLAUDE.md: adaptador local ausente para especializacao existente`);
    } else if (fs.existsSync(agents) && !fs.readFileSync(claude, 'utf8').includes('AGENTS.md')) {
      errors.push(`${packageName}/CLAUDE.md: adaptador local nao compoe AGENTS.md`);
    }
    if (fs.existsSync(agents) && fs.readFileSync(agents, 'utf8').split(/\r?\n/).length > 200) {
      errors.push(`${packageName}/AGENTS.md: adaptador local excede 200 linhas e deve conter somente especializacoes`);
    }
  }

  const invariants = [
    'docs/ai/README.md', 'docs/README.md', 'docs/adrs/README.md',
    'docs/architecture/module-registry.md', 'validate-docs.sh'
  ];
  for (const adapter of ['AGENTS.md', 'CLAUDE.md']) {
    const content = fs.readFileSync(path.join(repositoryRoot, adapter), 'utf8');
    const normalizedContent = normalize(content).replace(/\s+/g, ' ');
    for (const invariant of invariants) {
      if (!content.includes(invariant)) errors.push(`${adapter}: invariante global ausente: ${invariant}`);
    }
    for (const concept of [
      'teste', 'produção', 'plano persistido', 'evidência',
      'Qualquer comando Git', 'execução pertence ao humano',
      'Instalação, download, rede ou sistema externo', 'segredos e credenciais',
      'Exclusão, sobrescrita ampla ou ação irreversível', 'Bypass de permissão'
    ]) {
      if (!normalizedContent.includes(normalize(concept))) errors.push(`${adapter}: conceito global ausente: ${concept}`);
    }
  }
  return errors;
}

export function validateAdrCatalogEntry(content, filename, row) {
  const errors = [];
  const catalogStatus = (row.split('|')[3] ?? '').trim();
  const declaredStatus = extractField(content, FIELD_ALIASES.status);
  if (declaredStatus && (!catalogStatus || !statusMatches(catalogStatus, [declaredStatus]))) {
    errors.push(`docs/adrs/README.md: ${filename} cataloga status ${JSON.stringify(catalogStatus)} em vez de ${declaredStatus}`);
  }
  const originalDate = content.match(/Data original:\s*(\d{4}-\d{2}-\d{2})/i)?.[1];
  if (originalDate && !(row.split('|')[4] ?? '').includes(originalDate)) {
    errors.push(`docs/adrs/README.md: ${filename} omite a data original ${originalDate}`);
  }
  return errors;
}

export function validateLegacyPromptBridge(legacyPrompt, websiteReadme) {
  const errors = [];
  const planLink = '../../docs/task_plans/TP-00021-hub-contabil-landing-page-implementation-brief.md';
  if (!legacyPrompt.includes(planLink) || !/não mantém prompt operacional ativo/i.test(legacyPrompt)) {
    errors.push('website/prompt/README.md: ponteiro nao declara o TP-00021 como fonte canônica exclusiva');
  }
  if (/Você é uma equipe|##\s+\d+\.|leia integralmente/i.test(legacyPrompt) || legacyPrompt.split(/\r?\n/).length > 20) {
    errors.push('website/prompt/README.md: fonte concorrente ou instrução extensa voltou ao ponteiro legado');
  }
  if (!websiteReadme.includes('(prompt/README.md)') ||
      !websiteReadme.includes('(../docs/task_plans/TP-00021-hub-contabil-landing-page-implementation-brief.md)')) {
    errors.push('website/README.md: pacote nao indexa o ponteiro legado e o TP-00021 canônico');
  }
  return errors;
}

function validateEntryPointConciseness(repositoryRoot) {
  const errors = [];
  const adrIndexPath = path.join(repositoryRoot, 'docs/adrs/README.md');
  const adrIndex = fs.readFileSync(adrIndexPath, 'utf8');
  if (!adrIndex.includes('## Rotas temáticas')) {
    errors.push('docs/adrs/README.md: indice nao publica rotas tematicas curtas');
  }
  if (/^###\s+ADR-\d+/m.test(adrIndex) || /\bgraph\s+TD\b/.test(adrIndex)) {
    errors.push('docs/adrs/README.md: indice volta a duplicar resumos ou grafo detalhado por ADR');
  }
  if (adrIndex.split(/\r?\n/).length > 200) {
    errors.push('docs/adrs/README.md: ponto de entrada excede o limite local de 200 linhas');
  }
  const adrRows = adrIndex.split(/\r?\n/).filter((line) => line.startsWith('|'));
  const adrRoot = path.join(repositoryRoot, 'docs/adrs');
  for (const entry of fs.readdirSync(adrRoot, { withFileTypes: true })) {
    if (!entry.isFile() || !/^ADR-\d{4}-.+\.md$/.test(entry.name)) continue;
    const adr = fs.readFileSync(path.join(adrRoot, entry.name), 'utf8');
    const row = adrRows.find(
      (line) => (line.split('|')[1] ?? '').includes(`](${entry.name})`)
    ) ?? '';
    errors.push(...validateAdrCatalogEntry(adr, entry.name, row));
  }

  const infraReadmePath = path.join(repositoryRoot, 'infra/README.md');
  const infraReadme = fs.readFileSync(infraReadmePath, 'utf8');
  errors.push(...validateDocumentContract(infraReadme, 'infra/README.md'));
  errors.push(...validateRelativeLinks(infraReadme, infraReadmePath, repositoryRoot));
  for (const marker of ['## Catálogo da subárvore', '## Fontes canônicas por assunto', '## Owners e revisões', '## Guardrails', '## Validação segura']) {
    if (!infraReadme.includes(marker)) errors.push(`infra/README.md: ponto de entrada omite ${marker}`);
  }
  if (/^##\s+(?:Etapa|Arquitetura-alvo aceita)/m.test(infraReadme)) {
    errors.push('infra/README.md: catalogo volta a duplicar lifecycle ou decisao de IaC');
  }
  if (infraReadme.split(/\r?\n/).length > 150) {
    errors.push('infra/README.md: ponto de entrada excede o limite local de 150 linhas');
  }

  const infraAgents = fs.readFileSync(path.join(repositoryRoot, 'infra/AGENTS.md'), 'utf8');
  for (const marker of ['Testes e', 'validadores locais seguros', 'autônomos e obrigatórios']) {
    if (!infraAgents.includes(marker)) errors.push(`infra/AGENTS.md: especializacao omite ${marker}`);
  }
  if (infraAgents.split(/\r?\n/).length > 80) {
    errors.push('infra/AGENTS.md: especializacao excede o limite local de 80 linhas');
  }

  const legacyPromptPath = path.join(repositoryRoot, 'website/prompt/README.md');
  const websiteReadme = fs.readFileSync(path.join(repositoryRoot, 'website/README.md'), 'utf8');
  if (!fs.existsSync(legacyPromptPath)) {
    errors.push('website/prompt/README.md: ponteiro legado ausente');
  } else {
    const legacyPrompt = fs.readFileSync(legacyPromptPath, 'utf8');
    errors.push(...validateLegacyPromptBridge(legacyPrompt, websiteReadme));
  }
  return errors;
}

function validateRuntimeSettings(repositoryRoot) {
  const errors = [];
  const globalPath = path.join(repositoryRoot, 'docs/settings/settings.md');
  const global = fs.readFileSync(globalPath, 'utf8');
  const normalizedGlobal = normalize(global).replace(/\s+/g, ' ');
  for (const concept of [
    'Políticas organizacionais gerenciadas de segurança e compliance',
    'ADRs aceitos, incluindo o ADR-0000',
    'Standards e configurações globais versionadas do repositório',
    'Adaptadores globais de runtime',
    'Instruções e configurações específicas do pacote',
    'Plano e critérios de aceite da tarefa',
    'Preferências locais do usuário',
    'Qualquer comando Git', '`deny`', 'execução pertence ao humano',
    'Instalação, download, rede ou sistema externo',
    'Segredos e credenciais', 'não ler, registrar, transmitir ou versionar',
    'Exclusão, sobrescrita ampla ou ação irreversível',
    'Bypass de permissão', 'ambiente isolado e autorização específica'
  ]) {
    if (!normalizedGlobal.includes(normalize(concept))) {
      errors.push(`docs/settings/settings.md: matriz nao publica ${concept}`);
    }
  }
  if (/opera[cç][oõ]es Git que escrevem/i.test(global)) {
    errors.push('docs/settings/settings.md: matriz ainda permite subconjunto de comandos Git');
  }

  const manual = fs.readFileSync(path.join(repositoryRoot, 'docs/ai/README.md'), 'utf8');
  for (const marker of [
    '## Mapa das três camadas', 'Regras de ambiente e do assistente',
    'Documentação funcional e técnica', 'Configuração operacional do runtime',
    '## Ordem de autoridade',
    'Políticas organizacionais gerenciadas de segurança e compliance',
    'ADRs aceitos, incluindo o ADR-0000',
    'Standards e configurações globais versionadas do repositório',
    'Adaptadores globais de runtime', 'Instruções e configurações específicas do pacote',
    'Plano e critérios de aceite da tarefa', 'Preferências locais do usuário'
  ]) {
    if (!normalize(manual).includes(normalize(marker))) {
      errors.push(`docs/ai/README.md: mapa de camadas ou precedencia omite ${marker}`);
    }
  }

  const codexPath = path.join(repositoryRoot, 'docs/settings/codex.md');
  const codex = fs.readFileSync(codexPath, 'utf8');
  for (const marker of [
    'project_doc_max_bytes', 'project_doc_fallback_filenames', 'AGENTS.override.md',
    'CODEX_HOME', '32768', 'Configuração pessoal', 'Orçamento agregado observado'
  ]) {
    if (!normalize(codex).includes(normalize(marker))) {
      errors.push(`docs/settings/codex.md: configuracao efetiva omite ${marker}`);
    }
  }

  const rootBytes = Buffer.byteLength(fs.readFileSync(path.join(repositoryRoot, 'AGENTS.md')));
  const scopes = [
    { label: 'raiz', file: null },
    ...['backend', 'frontend', 'website', 'infra'].map((scope) => ({ label: scope, file: `${scope}/AGENTS.md` }))
  ];
  for (const scope of scopes) {
    const localBytes = scope.file
      ? Buffer.byteLength(fs.readFileSync(path.join(repositoryRoot, scope.file)))
      : rootBytes;
    const aggregate = scope.file ? rootBytes + localBytes : rootBytes;
    const label = scope.label === 'raiz' ? 'raiz' : escapeRegex(`\`${scope.label}/\``);
    const row = new RegExp(`^\\|\\s*${label}\\s*\\|[^\\n]*\\|\\s*\\x60?${localBytes}\\x60?\\s*\\|\\s*\\x60?${aggregate}\\x60?\\s*\\|$`, 'm');
    if (!row.test(codex)) {
      errors.push(`docs/settings/codex.md: orcamento de ${scope.label} diverge dos bytes ${localBytes}/${aggregate}`);
    }
    if (aggregate >= 32768) {
      errors.push(`${scope.file ?? 'AGENTS.md'}: cadeia ${aggregate} alcanca ou excede o teto governado de 32768 bytes`);
    }
  }

  for (const absent of ['.codex/config.toml', 'AGENTS.override.md']) {
    if (fs.existsSync(path.join(repositoryRoot, absent)) && codex.includes(`não contém \`${absent}\``)) {
      errors.push(`docs/settings/codex.md: declara ausente configuracao que existe: ${absent}`);
    }
  }
  return errors;
}

function validateNativeSkills(repositoryRoot) {
  const errors = [];
  const catalogPath = path.join(repositoryRoot, 'docs/agents/skills/README.md');
  const catalog = fs.readFileSync(catalogPath, 'utf8');
  const roots = ['', 'backend', 'frontend', 'website', 'infra'].flatMap((scope) =>
    ['.agents/skills', '.claude/skills'].map((runtimeRoot) =>
      scope ? `${scope}/${runtimeRoot}` : runtimeRoot
    )
  );
  for (const root of roots) {
    const absoluteRoot = path.join(repositoryRoot, root);
    if (!fs.existsSync(absoluteRoot)) continue;
    for (const entry of fs.readdirSync(absoluteRoot, { withFileTypes: true })) {
      if (!entry.isDirectory()) continue;
      const skillPath = path.join(absoluteRoot, entry.name, 'SKILL.md');
      if (!fs.existsSync(skillPath)) {
        errors.push(`${relative(repositoryRoot, path.dirname(skillPath))}: diretorio de skill sem SKILL.md`);
        continue;
      }
      const content = fs.readFileSync(skillPath, 'utf8');
      errors.push(...validateSkillFile(content, entry.name, relative(repositoryRoot, skillPath)));
      if (entry.name === 'governanca-documental') {
        errors.push(...validateGovernanceSkill(content, relative(repositoryRoot, skillPath)));
      }
      if (entry.name === 'implementation-readiness') {
        errors.push(...validateImplementationReadinessSkill(content, relative(repositoryRoot, skillPath)));
      }
      if (entry.name === 'quality-gate') {
        errors.push(...validateQualityGateSkill(content, relative(repositoryRoot, skillPath)));
      }
      if (!catalog.includes(entry.name) || !catalog.includes(`${root}/${entry.name}/SKILL.md`)) {
        errors.push(`${relative(repositoryRoot, skillPath)}: skill ausente do catalogo operacional`);
      }
    }
  }
  for (const skillName of ['governanca-documental', 'implementation-readiness', 'quality-gate']) {
    const variants = [
      `.agents/skills/${skillName}/SKILL.md`,
      `.claude/skills/${skillName}/SKILL.md`
    ].map((relativePath) => ({
      relativePath,
      absolutePath: path.join(repositoryRoot, relativePath)
    }));
    if (variants.every(({ absolutePath }) => fs.existsSync(absolutePath))) {
      const [codex, claude] = variants.map(({ absolutePath }) =>
        fs.readFileSync(absolutePath, 'utf8').replace(/\r\n/g, '\n').trim()
      );
      if (codex !== claude) {
        errors.push(`${skillName}: nucleo Codex/Claude diverge sem justificativa catalogada`);
      }
    }
  }
  return errors;
}

export function validateStandardConsumerParity(agentCatalog, standardCatalog, agentDocuments) {
  const errors = [];
  const agentRows = agentCatalog.split(/\r?\n/).filter((line) => line.startsWith('|'));
  const standardRows = standardCatalog.split(/\r?\n/).filter((line) => line.startsWith('|'));
  for (const standardRow of standardRows) {
    const standardName = (standardRow.split('|')[1] ?? '').match(/\]\(([^/)]+\.md)\)/)?.[1];
    if (!standardName) continue;
    const consumers = (standardRow.split('|')[6] ?? '').split(',')
      .map((value) => value.trim())
      .filter((value) => value && !/^todos os agentes executores$/i.test(value));
    for (const consumer of consumers) {
      const agent = agentDocuments.get(`${consumer}.md`);
      if (agent === undefined) {
        errors.push(`docs/agents/standards/README.md: ${standardName} declara consumidor inexistente ${consumer}`);
        continue;
      }
      if (!agent.includes(`standards/${standardName}`)) {
        errors.push(`docs/agents/${consumer}.md: omite standard consumidor ${standardName}`);
      }
      const agentRow = agentRows.find(
        (line) => (line.split('|')[1] ?? '').includes(`](${consumer}.md)`)
      ) ?? '';
      if (!agentRow.includes(`(standards/${standardName})`)) {
        errors.push(`docs/agents/README.md: ${consumer} omite relacionamento reverso com ${standardName}`);
      }
    }
  }
  return errors;
}

function validateSemanticCatalogs(repositoryRoot) {
  const errors = [];
  const agents = fs.readFileSync(path.join(repositoryRoot, 'docs/agents/README.md'), 'utf8');
  if (!/\|[^\n]*Relacionamentos[^\n]*\|/i.test(agents)) errors.push('docs/agents/README.md: catalogo nao publica relacionamentos por agente');
  const standards = fs.readFileSync(path.join(repositoryRoot, 'docs/agents/standards/README.md'), 'utf8');
  if (!/\|[^\n]*Palavras-chave[^\n]*\|/i.test(standards)) errors.push('docs/agents/standards/README.md: catalogo nao publica palavras-chave por standard');
  if (!/\|[^\n]*Relacionamentos[^\n]*\|/i.test(standards)) errors.push('docs/agents/standards/README.md: catalogo nao publica relacionamentos por standard');

  const agentRows = agents.split(/\r?\n/).filter((line) => line.startsWith('|'));
  const standardRows = standards.split(/\r?\n/).filter((line) => line.startsWith('|'));
  const agentRoot = path.join(repositoryRoot, 'docs/agents');
  const agentDocuments = new Map();
  for (const entry of fs.readdirSync(agentRoot, { withFileTypes: true })) {
    if (!entry.isFile() || entry.name === 'README.md' || !entry.name.endsWith('.md')) continue;
    const agentName = entry.name.replace(/\.md$/, '');
    const content = fs.readFileSync(path.join(agentRoot, entry.name), 'utf8');
    agentDocuments.set(entry.name, content);
    const agentRow = agentRows.find((line) => (line.split('|')[1] ?? '').includes(`](${entry.name})`)) ?? '';
    const referencedStandards = [...new Set(
      [...content.matchAll(/(?:\.\/)?standards\/([A-Za-z0-9._-]+\.md)/g)].map((match) => match[1])
    )];
    for (const standardName of referencedStandards) {
      if (!agentRow.includes(`(standards/${standardName})`)) {
        errors.push(`docs/agents/README.md: ${agentName} omite relacionamento com ${standardName}`);
      }
      const standardRow = standardRows.find(
        (line) => (line.split('|')[1] ?? '').includes(`](${standardName})`)
      ) ?? '';
      const consumers = (standardRow.split('|')[6] ?? '').split(',').map((value) => value.trim());
      if (!consumers.includes(agentName)) {
        errors.push(`docs/agents/standards/README.md: ${standardName} omite consumidor ${agentName}`);
      }
    }
  }
  errors.push(...validateStandardConsumerParity(agents, standards, agentDocuments));
  return errors;
}

function validateIgnoreRules(repositoryRoot) {
  const content = fs.readFileSync(path.join(repositoryRoot, '.gitignore'), 'utf8');
  const activeRules = new Set(content.split(/\r?\n/)
    .map((line) => line.trim())
    .filter((line) => line && !line.startsWith('#') && !line.startsWith('!')));
  const required = ['.env*', 'node_modules/', 'target/', '.next/', 'CLAUDE.local.md', '.claude/settings.local.json'];
  return required.filter((rule) => !activeRules.has(rule)).map((rule) => `.gitignore: regra obrigatoria ausente: ${rule}`);
}

export function validateModuleRegistryStructure(
  content,
  moduleDirectories = [],
  packageNames = ['backend/', 'frontend/', 'website/', 'infra/', 'docs/']
) {
  const errors = [];
  const routeHeader = '| Domínio | Pacote físico | Owner | Entry points | Dependências | Documentação |';
  if (content.split(routeHeader).length - 1 < 2) {
    errors.push('docs/architecture/module-registry.md: manifesto nao publica rotas completas por pacote e modulo');
  }
  const codeReferences = extractField(content, FIELD_ALIASES.code_references) ?? '';
  for (const packageName of packageNames) {
    if (!content.includes(`\`${packageName}\``)) errors.push(`docs/architecture/module-registry.md: pacote ausente: ${packageName}`);
    if (!codeReferences.includes(packageName)) errors.push(`docs/architecture/module-registry.md: code_references omite ${packageName}`);
    const row = content.split(/\r?\n/).find((line) => line.includes(`| \`${packageName}\` |`)) ?? '';
    const cells = row.split('|').slice(1, 7).map((cell) => cell.trim());
    if (cells.length < 6 || cells.some((cell) => !cell)) {
      errors.push(`docs/architecture/module-registry.md: rota incompleta para pacote ${packageName}`);
    }
  }
  if (content.split(/\r?\n/).length > 220 || Buffer.byteLength(content) > 20 * 1024) {
    errors.push('docs/architecture/module-registry.md: manifesto excede o orçamento seletivo de 220 linhas/20 KiB');
  }
  if (/^###\s+(?:Fronteira operacional|Target aceito)|^####\s+Proveniência e readiness|zero mudança em módulo/im.test(content)) {
    errors.push('docs/architecture/module-registry.md: manifesto volta a duplicar lifecycle de Infra ou target de Billing');
  }
  for (const moduleDirectory of moduleDirectories) {
    const row = content.split(/\r?\n/).find((line) => line.includes(`\`${moduleDirectory}\``)) ?? '';
    const cells = row.split('|').slice(1, 7).map((cell) => cell.trim());
    if (cells.length < 6 || cells.some((cell) => !cell)) {
      errors.push(`docs/architecture/module-registry.md: rota incompleta para ${moduleDirectory}`);
    }
  }
  return errors;
}

function validateModuleRegistry(repositoryRoot) {
  const content = fs.readFileSync(path.join(repositoryRoot, 'docs/architecture/module-registry.md'), 'utf8');
  const errors = [];
  const pom = fs.readFileSync(path.join(repositoryRoot, 'backend/pom.xml'), 'utf8');
  const java = pom.match(/<java\.version>([^<]+)<\/java\.version>/)?.[1];
  const springBoot = pom.match(/<artifactId>spring-boot-starter-parent<\/artifactId>\s*<version>([^<]+)<\/version>/)?.[1];
  const modulith = pom.match(/<spring-modulith\.version>([^<]+)<\/spring-modulith\.version>/)?.[1];
  for (const [name, value] of [['Java', java], ['Spring Boot', springBoot], ['Spring Modulith', modulith]]) {
    if (!value) errors.push(`backend/pom.xml: versao de ${name} nao resolvida`);
    else if (!content.includes(`${name} ${value}`)) errors.push(`docs/architecture/module-registry.md: baseline diverge de ${name} ${value}`);
  }
  const namespace = 'backend/src/main/java/br/com/duoset/saas_service/';
  const namespaceRoot = path.join(repositoryRoot, namespace);
  if (!fs.existsSync(namespaceRoot)) errors.push(`${namespace}: namespace backend obrigatorio ausente`);
  if (!content.includes(namespace)) errors.push(`docs/architecture/module-registry.md: namespace backend ausente: ${namespace}`);
  let moduleDirectories = [];
  if (fs.existsSync(namespaceRoot)) {
    moduleDirectories = walkFiles(namespaceRoot)
      .filter((file) => path.basename(file) === 'package-info.java')
      .filter((file) => /@org\.springframework\.modulith\.ApplicationModule\b/.test(fs.readFileSync(file, 'utf8')))
      .map((file) => `${relative(repositoryRoot, path.dirname(file))}/`)
      .sort();
  }
  errors.push(...validateModuleRegistryStructure(content, moduleDirectories));

  for (const packageName of ['frontend', 'website']) {
    const manifest = JSON.parse(fs.readFileSync(path.join(repositoryRoot, packageName, 'package.json'), 'utf8'));
    const nextMajor = String(manifest.dependencies?.next ?? '').match(/\d+/)?.[0];
    const reactMajor = String(manifest.dependencies?.react ?? '').match(/\d+/)?.[0];
    if (!nextMajor || !content.includes(`Next.js ${nextMajor}`)) {
      errors.push(`docs/architecture/module-registry.md: baseline Next.js diverge de ${packageName}/package.json`);
    }
    if (!reactMajor || !content.includes(`React ${reactMajor}`)) {
      errors.push(`docs/architecture/module-registry.md: baseline React diverge de ${packageName}/package.json`);
    }
  }
  return errors;
}

export function validateRepository(repositoryRoot) {
  const root = path.resolve(repositoryRoot);
  const docsRoot = path.join(root, 'docs');
  const errors = [];
  const metrics = { markdown: 0, directories: 0, indexedArtifacts: 0, skills: 0 };

  for (const required of REQUIRED_PATHS) {
    const absolute = path.join(root, required);
    if (!fs.existsSync(absolute) || fs.statSync(absolute).size === 0) errors.push(`${required}: artefato obrigatorio ausente ou vazio`);
  }
  for (const template of REQUIRED_TEMPLATES) {
    if (!fs.existsSync(path.join(root, template))) errors.push(`${template}: template obrigatorio ausente`);
  }
  if (!fs.existsSync(docsRoot)) return { errors, metrics };

  const repositoryPathIndex = buildRepositoryPathIndex(root);
  const markdownFiles = walkFiles(docsRoot).filter((file) => file.endsWith('.md')).sort();
  metrics.markdown = markdownFiles.length;
  const ids = new Map();
  for (const file of markdownFiles) {
    const content = fs.readFileSync(file, 'utf8');
    const rel = relative(root, file);
    errors.push(...validateDocumentContract(content, rel));
    errors.push(...validateRelativeLinks(content, file, root));
    errors.push(...validateMetadataReferences(content, file, root, repositoryPathIndex));
    errors.push(...validateCollectionSemantics(content, file, root));
    errors.push(...validateKnownIdentity(content, file, root));
    if (path.basename(file) === 'README.md') errors.push(...validateReadmeContract(content, file, root));
    const id = extractField(content, FIELD_ALIASES.document_id);
    if (id) {
      if (ids.has(id)) errors.push(`${rel}: document_id duplicado ${id}; primeiro em ${ids.get(id)}`);
      else ids.set(id, rel);
    }
  }

  const directories = walkDirectories(docsRoot).sort();
  metrics.directories = directories.length;
  for (const directory of directories) {
    const readmePath = path.join(directory, 'README.md');
    if (!fs.existsSync(readmePath)) {
      errors.push(`${relative(root, directory)}: diretorio documental ativo sem README.md`);
      continue;
    }
    const readme = fs.readFileSync(readmePath, 'utf8');
    for (const entry of fs.readdirSync(directory, { withFileTypes: true })) {
      if (entry.isFile() && entry.name !== 'README.md') {
        if (!isMarkdownLinkTo(readme, entry.name)) errors.push(`${relative(root, path.join(directory, entry.name))}: artefato sem link individual no indice imediato`);
        else metrics.indexedArtifacts += 1;
      }
      if (entry.isDirectory() && !isMarkdownLinkTo(readme, `${entry.name}/README.md`)) {
        errors.push(`${relative(root, path.join(directory, entry.name))}: subcolecao sem link individual no indice pai`);
      }
    }
  }

  for (const forbidden of walkFiles(docsRoot).filter((file) => path.basename(file) === 'SKILL.md')) {
    errors.push(`${relative(root, forbidden)}: SKILL.md e proibido dentro de docs/`);
  }

  const allText = markdownFiles.map((file) => fs.readFileSync(file, 'utf8')).join('\n');
  if (/\b(?:\d{5}-REQ-|NNNNN-REQ|TP-00TP|RPT-RPT|LL-\d{5}|\d{3}\.PromptTemplate)/.test(allText)) {
    errors.push('docs/: identificador documental legado permanece');
  }

  errors.push(...validateTemplates(root));

  const productRequirementsRoot = path.join(root, 'docs/product_requirements');
  const productRequirementsIndex = path.join(productRequirementsRoot, 'README.md');
  const productRequirementsTemplate = path.join(root, 'docs/templates/TPL-00012-PromptTemplateCriarPRD.md');
  if (fs.existsSync(productRequirementsRoot) &&
      fs.existsSync(productRequirementsIndex) &&
      fs.existsSync(productRequirementsTemplate)) {
    const prds = fs.readdirSync(productRequirementsRoot, { withFileTypes: true })
      .filter((entry) => entry.isFile() && /^PRD-\d{5}-.+\.md$/.test(entry.name))
      .map((entry) => ({
        path: `docs/product_requirements/${entry.name}`,
        content: fs.readFileSync(path.join(productRequirementsRoot, entry.name), 'utf8')
      }));
    errors.push(...validateProductRequirementsGovernance({
      index: fs.readFileSync(productRequirementsIndex, 'utf8'),
      template: fs.readFileSync(productRequirementsTemplate, 'utf8'),
      prds
    }));
  }
  errors.push(...validateRuntimeAdapters(root));
  errors.push(...validateRuntimeSettings(root));
  errors.push(...validateEntryPointConciseness(root));
  errors.push(...validateNativeSkills(root));
  errors.push(...validateSemanticCatalogs(root));
  errors.push(...validateIgnoreRules(root));
  errors.push(...validateModuleRegistry(root));

  errors.push(...validateGovernanceEntrypoint(
    fs.readFileSync(path.join(root, 'docs/adrs/ADR-0000-governanca-documentacao-agentes-ia.md'), 'utf8'),
    fs.readFileSync(path.join(root, 'infra/scripts/validate-docs.sh'), 'utf8')
  ));

  errors.push(...validateQualityGateScaffold(
    fs.readFileSync(path.join(root, 'docs/adrs/ADR-0000-governanca-documentacao-agentes-ia.md'), 'utf8'),
    fs.readFileSync(path.join(root, 'infra/scripts/validate-quality-gates.sh'), 'utf8'),
    fs.readFileSync(path.join(root, 'infra/scripts/tests/validate-quality-gates-test.sh'), 'utf8'),
    fs.readFileSync(path.join(root, 'infra/scripts/validate-docs.sh'), 'utf8'),
    fs.readFileSync(path.join(root, 'docs/agents/standards/software-quality-standard.md'), 'utf8')
  ));

  errors.push(...validateImplementationReadinessGovernance({
    adr: fs.readFileSync(path.join(root, 'docs/adrs/ADR-0000-governanca-documentacao-agentes-ia.md'), 'utf8'),
    standard: fs.readFileSync(path.join(root, 'docs/agents/standards/implementation-readiness-standard.md'), 'utf8'),
    requirementTemplate: fs.readFileSync(path.join(root, 'docs/templates/TPL-00003-PromptTemplateCriarRequisito.md'), 'utf8'),
    useCaseTemplate: fs.readFileSync(path.join(root, 'docs/templates/TPL-00004-PromptTemplateCriarCasoDeUso.md'), 'utf8'),
    prdTemplate: fs.readFileSync(path.join(root, 'docs/templates/TPL-00012-PromptTemplateCriarPRD.md'), 'utf8'),
    taskPlanTemplate: fs.readFileSync(path.join(root, 'docs/templates/TPL-00005-PromptTemplateCriarTaskPlan.md'), 'utf8'),
    implementationPlanTemplate: fs.readFileSync(path.join(root, 'docs/templates/TPL-00006-PromptTemplateCriarImplementationPlan.md'), 'utf8'),
    rawImplementationPlanTemplate: fs.readFileSync(path.join(root, 'docs/templates/chat/TPL-00006-PromptTemplateCriarImplementationPlan.raw'), 'utf8'),
    lifecycle: fs.readFileSync(path.join(root, 'docs/agents/standards/software-engineering-lifecycle.md'), 'utf8'),
    orchestrator: fs.readFileSync(path.join(root, 'docs/agents/AgentOrchestrator.md'), 'utf8'),
    requirementAgent: fs.readFileSync(path.join(root, 'docs/agents/RequirementAgent.md'), 'utf8'),
    codeGuardian: fs.readFileSync(path.join(root, 'docs/agents/CodeGuardian.md'), 'utf8'),
    agentsAdapter: fs.readFileSync(path.join(root, 'AGENTS.md'), 'utf8'),
    claudeAdapter: fs.readFileSync(path.join(root, 'CLAUDE.md'), 'utf8')
  }));

  const map = fs.readFileSync(path.join(root, 'docs/README.md'), 'utf8');
  for (const requiredState of ['.agents/skills/', '.claude/skills/', 'governanca-documental', 'implementation-readiness', 'quality-gate', 'Conformant', '.claude/settings.json', 'Not applicable']) {
    if (!map.includes(requiredState)) errors.push(`docs/README.md: matriz de ativacao nao publica ${requiredState}`);
  }

  return { errors: [...new Set(errors)].sort(), metrics };
}

function parseRoot(args) {
  const rootIndex = args.indexOf('--root');
  if (rootIndex >= 0) {
    if (!args[rootIndex + 1]) throw new Error('--root exige um caminho');
    return path.resolve(args[rootIndex + 1]);
  }
  return path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
}

function main() {
  const root = parseRoot(process.argv.slice(2));
  const { errors, metrics } = validateRepository(root);
  if (errors.length > 0) {
    for (const error of errors) process.stderr.write(`ERROR: ${error}\n`);
    process.stderr.write(`Documentation governance validation failed with ${errors.length} error(s).\n`);
    process.exitCode = 1;
    return;
  }
  process.stdout.write(
    `Documentation governance validation passed: ${metrics.markdown} Markdown, ` +
    `${metrics.directories} directories, ${metrics.indexedArtifacts} indexed artifacts.\n`
  );
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) main();
