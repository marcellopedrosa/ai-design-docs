#!/usr/bin/env node

import fs from 'node:fs';
import path from 'node:path';
import process from 'node:process';
import { fileURLToPath } from 'node:url';
import { syncAdapters } from '../adapters/sync-adapters.mjs';
import { compileSchema, validateSchemaSyntax, validateInstance } from '../contracts/validator.mjs';
import { runEvalsH1 } from '../eval-runner/index.mjs';

function checkForUnsupportedYaml(rawLine, lineNumber, filename) {
  const trimmed = rawLine.trim();
  if (!trimmed || trimmed.startsWith('#')) return;

  if (/:\s*[|>][+-]?\s*(?:#.*)?$/.test(trimmed)) {
    throw new Error(`${filename}:${lineNumber}: sintaxe YAML não suportada: strings multilinha com '|' ou '>' não são permitidas.`);
  }

  if (/:\s*\[[^\]]+\]\s*(?:#.*)?$/.test(trimmed)) {
    throw new Error(`${filename}:${lineNumber}: sintaxe YAML não suportada: listas inline '[...]' não são permitidas.`);
  }

  if (/:\s*\{[^}]*\}\s*(?:#.*)?$/.test(trimmed)) {
    throw new Error(`${filename}:${lineNumber}: sintaxe YAML não suportada: objetos inline '{...}' não são permitidas.`);
  }

  const unquoted = trimmed.replace(/"[^"]*"|'[^']*'/g, '');
  if (/(?:^|\s)&[A-Za-z0-9_-]+/.test(unquoted)) {
    throw new Error(`${filename}:${lineNumber}: sintaxe YAML não suportada: âncoras '&' não são permitidas.`);
  }

  if (/(?:^|\s)\*[A-Za-z0-9_-]+/.test(unquoted)) {
    throw new Error(`${filename}:${lineNumber}: sintaxe YAML não suportada: aliases '*' não são permitidos.`);
  }
}

export function parseSimpleYaml(content, filename = 'yaml') {
  // Parser leve e determinístico com fail-loud para subconjunto de YAML usado no registry
  const lines = content.split(/\r?\n/);
  const result = {};
  const stack = [{ indent: -1, obj: result }];

  for (let i = 0; i < lines.length; i++) {
    const rawLine = lines[i];
    if (!rawLine.trim() || rawLine.trim().startsWith('#')) continue;

    checkForUnsupportedYaml(rawLine, i + 1, filename);

    const indent = rawLine.search(/\S/);
    const line = rawLine.trim();

    while (stack.length > 1 && indent <= stack[stack.length - 1].indent) {
      stack.pop();
    }

    const currentParent = stack[stack.length - 1].obj;

    if (line.startsWith('- ')) {
      // Item de lista
      const value = line.slice(2).trim().replace(/^["']|["']$/g, '');
      if (Array.isArray(currentParent)) {
        currentParent.push(value);
      }
      continue;
    }

    const colonIndex = line.indexOf(':');
    if (colonIndex > 0) {
      const key = line.slice(0, colonIndex).trim().replace(/^["']|["']$/g, '');
      const rawValue = line.slice(colonIndex + 1).trim();

      if (!rawValue) {
        // Objeto ou lista aninhada
        let isList = false;
        for (let j = i + 1; j < lines.length; j++) {
          const nextTrimmed = lines[j].trim();
          if (nextTrimmed && !nextTrimmed.startsWith('#')) {
            isList = nextTrimmed.startsWith('- ');
            break;
          }
        }

        const newObj = isList ? [] : {};
        if (Array.isArray(currentParent)) {
          currentParent.push({ [key]: newObj });
        } else {
          currentParent[key] = newObj;
        }
        stack.push({ indent, obj: newObj });
      } else {
        const cleanValue = rawValue.replace(/^["']|["']$/g, '');
        let parsedValue = cleanValue;
        if (cleanValue === 'true') parsedValue = true;
        else if (cleanValue === 'false') parsedValue = false;
        else if (/^\d+$/.test(cleanValue)) parsedValue = parseInt(cleanValue, 10);

        if (Array.isArray(currentParent)) {
          currentParent.push({ [key]: parsedValue });
        } else {
          currentParent[key] = parsedValue;
        }
      }
    }
  }

  return result;
}

export function checkRegistry(root) {
  const errors = [];
  const registryDir = path.join(root, 'registry');
  const requiredFiles = ['harness.yaml', 'skills.yaml', 'standards.yaml', 'runtimes.yaml', 'tooling.yaml'];

  if (!fs.existsSync(registryDir)) {
    return { errors: ['Diretório registry/ não encontrado.'] };
  }

  for (const file of requiredFiles) {
    const filePath = path.join(registryDir, file);
    if (!fs.existsSync(filePath)) {
      errors.push(`registry/${file}: arquivo ausente.`);
      continue;
    }

    try {
      const content = fs.readFileSync(filePath, 'utf8');
      const parsed = parseSimpleYaml(content, file);
      if (!parsed || typeof parsed !== 'object') {
        errors.push(`registry/${file}: estrutura inválida.`);
      }

      if (file === 'skills.yaml' && parsed.skills) {
        for (const skillName of Object.keys(parsed.skills)) {
          const canonicalSkill = path.join(root, 'skills', skillName, 'SKILL.md');
          if (!fs.existsSync(canonicalSkill)) {
            errors.push(`registry/skills.yaml: skill '${skillName}' declarada mas skills/${skillName}/SKILL.md não existe.`);
          }
        }
      }

      if (file === 'standards.yaml' && parsed.standards) {
        for (const [name, std] of Object.entries(parsed.standards)) {
          if (std.class === 'baseline' && std.path) {
            const stdPath = path.join(root, std.path);
            if (!fs.existsSync(stdPath)) {
              errors.push(`registry/standards.yaml: standard baseline '${name}' aponta para path inexistente: ${std.path}`);
            }
          }
        }
      }

      if (file === 'runtimes.yaml' && parsed.runtimes) {
        for (const [runtimeName, rcfg] of Object.entries(parsed.runtimes)) {
          if (rcfg.global_adapter) {
            const adapterPath = path.join(root, rcfg.global_adapter);
            if (!fs.existsSync(adapterPath)) {
              errors.push(`registry/runtimes.yaml: runtime '${runtimeName}' aponta para adapter ausente: ${rcfg.global_adapter}`);
            }
          }
        }
      }
    } catch (err) {
      errors.push(`registry/${file}: erro ao ler/analisar: ${err.message}`);
    }
  }

  return { errors };
}

export function checkContracts(root) {
  const errors = [];
  const contractsDir = path.join(root, 'contracts');
  const requiredSchemas = [
    'capability-request.schema.json',
    'readiness-result.schema.json',
    'gate-result.schema.json',
    'evidence.schema.json',
    'security-finding.schema.json',
    'handoff.schema.json'
  ];

  if (!fs.existsSync(contractsDir)) {
    return { errors: ['Diretório contracts/ não encontrado.'] };
  }

  const compiledSchemas = new Map();

  for (const schemaFile of requiredSchemas) {
    const schemaPath = path.join(contractsDir, schemaFile);
    if (!fs.existsSync(schemaPath)) {
      errors.push(`contracts/${schemaFile}: schema ausente.`);
      continue;
    }

    try {
      const content = fs.readFileSync(schemaPath, 'utf8');
      const parsed = JSON.parse(content);
      const syntax = validateSchemaSyntax(parsed, `contracts/${schemaFile}`);
      if (!syntax.valid) {
        errors.push(...syntax.errors);
      } else {
        const validator = compileSchema(parsed, `contracts/${schemaFile}`);
        compiledSchemas.set(schemaFile, { schema: parsed, validator });
      }
    } catch (err) {
      errors.push(`contracts/${schemaFile}: erro ao compilar schema: ${err.message}`);
    }
  }

  const examplesDir = path.join(contractsDir, 'examples');
  if (fs.existsSync(examplesDir)) {
    for (const entry of fs.readdirSync(examplesDir, { withFileTypes: true })) {
      if (entry.isFile() && entry.name.endsWith('.json')) {
        const examplePath = path.join(examplesDir, entry.name);
        const match = entry.name.match(/^(.+?)\.(valid|invalid)\.json$/);
        if (match) {
          const [, schemaBase, kind] = match;
          const targetSchemaFile = `${schemaBase}.schema.json`;
          const compiled = compiledSchemas.get(targetSchemaFile);
          if (!compiled) {
            errors.push(`contracts/examples/${entry.name}: schema correspondente '${targetSchemaFile}' não encontrado.`);
            continue;
          }
          try {
            const data = JSON.parse(fs.readFileSync(examplePath, 'utf8'));
            const res = compiled.validator(data);
            if (kind === 'valid' && !res.valid) {
              errors.push(`contracts/examples/${entry.name}: exemplo válido falhou na validação: ${res.errors.join(', ')}`);
            } else if (kind === 'invalid' && res.valid) {
              errors.push(`contracts/examples/${entry.name}: exemplo inválido passou na validação indevidamente.`);
            }
          } catch (err) {
            errors.push(`contracts/examples/${entry.name}: JSON inválido: ${err.message}`);
          }
        }
      }
    }
  }

  const harnessEvalSchema = path.join(root, 'evals', 'schema', 'harness-eval.schema.json');
  if (fs.existsSync(harnessEvalSchema)) {
    try {
      const content = fs.readFileSync(harnessEvalSchema, 'utf8');
      const parsed = JSON.parse(content);
      if (!parsed.$schema || !parsed.title) {
        errors.push('evals/schema/harness-eval.schema.json: formato JSON Schema inválido.');
      }
    } catch (err) {
      errors.push(`evals/schema/harness-eval.schema.json: JSON inválido: ${err.message}`);
    }
  } else {
    errors.push('evals/schema/harness-eval.schema.json: schema ausente.');
  }

  return { errors };
}

export function checkSkills(root) {
  const errors = [];
  const skillsDir = path.join(root, 'skills');
  const skillsYamlPath = path.join(root, 'registry', 'skills.yaml');

  let registrySkills = {};
  if (fs.existsSync(skillsYamlPath)) {
    try {
      const parsed = parseSimpleYaml(fs.readFileSync(skillsYamlPath, 'utf8'), 'registry/skills.yaml');
      registrySkills = parsed.skills || {};
    } catch { /* handled in checkRegistry */ }
  }

  if (!fs.existsSync(skillsDir)) {
    return { errors: ['Diretório skills/ não encontrado.'] };
  }

  const skillDirs = fs.readdirSync(skillsDir, { withFileTypes: true })
    .filter((entry) => entry.isDirectory())
    .map((entry) => entry.name);

  for (const skill of skillDirs) {
    const skillPath = path.join(skillsDir, skill, 'SKILL.md');
    const contractPath = path.join(skillsDir, skill, 'contract.yaml');
    const evalsPath = path.join(skillsDir, skill, 'evals', 'evals.json');

    if (!fs.existsSync(skillPath)) {
      errors.push(`skills/${skill}: SKILL.md ausente.`);
      continue;
    }

    const content = fs.readFileSync(skillPath, 'utf8');
    const frontmatter = content.match(/^---\r?\n([\s\S]*?)\r?\n---/);
    if (!frontmatter) {
      errors.push(`skills/${skill}/SKILL.md: frontmatter YAML ausente.`);
    } else {
      const nameMatch = frontmatter[1].match(/^name:\s*(.+)$/m);
      const descMatch = frontmatter[1].match(/^description:\s*(.+)$/m);
      const allowedToolsMatch = frontmatter[1].match(/^allowed-tools:\s*(.+)$/m);
      const disableModelMatch = frontmatter[1].match(/^disable-model-invocation:\s*(.+)$/m);

      if (!nameMatch) errors.push(`skills/${skill}/SKILL.md: campo name ausente.`);
      else if (nameMatch[1].trim() !== skill) errors.push(`skills/${skill}/SKILL.md: name '${nameMatch[1].trim()}' difere do diretório '${skill}'.`);

      if (!descMatch) errors.push(`skills/${skill}/SKILL.md: campo description ausente.`);
      else if (descMatch[1].trim().length > 500) errors.push(`skills/${skill}/SKILL.md: description excede 500 caracteres.`);

      if (!allowedToolsMatch) {
        errors.push(`skills/${skill}/SKILL.md: campo allowed-tools ausente no frontmatter.`);
      } else {
        const allowedTools = allowedToolsMatch[1].split(',').map(t => t.trim());
        const regConfig = registrySkills[skill];
        if (regConfig?.permissions) {
          if (regConfig.permissions.filesystem_write === 'deny') {
            if (allowedTools.includes('Edit') || allowedTools.includes('Write')) {
              errors.push(`skills/${skill}/SKILL.md: allowed-tools inclui ferramentas de escrita, mas registry define filesystem_write: deny.`);
            }
          }
          if (regConfig.permissions.local_exec === 'deny') {
            if (allowedTools.includes('Bash')) {
              errors.push(`skills/${skill}/SKILL.md: allowed-tools inclui Bash, mas registry define local_exec: deny.`);
            }
          }
        }
        if (regConfig?.activation?.mode === 'explicit-opt-in' || regConfig?.risk_class === 'R3') {
          if (!disableModelMatch || disableModelMatch[1].trim() !== 'true') {
            errors.push(`skills/${skill}/SKILL.md: skill de risco R3 / explicit-opt-in deve definir disable-model-invocation: true.`);
          }
        }
      }
    }

    if (!fs.existsSync(contractPath)) {
      errors.push(`skills/${skill}/contract.yaml: arquivo ausente.`);
    }

    if (!fs.existsSync(evalsPath)) {
      errors.push(`skills/${skill}/evals/evals.json: arquivo ausente.`);
    } else {
      try {
        const evalsContent = fs.readFileSync(evalsPath, 'utf8');
        const parsed = JSON.parse(evalsContent);
        if (!Array.isArray(parsed.evals) || parsed.evals.length === 0) {
          errors.push(`skills/${skill}/evals/evals.json: lista de evals vazia ou inválida.`);
        }
      } catch (err) {
        errors.push(`skills/${skill}/evals/evals.json: JSON inválido: ${err.message}`);
      }
    }
  }

  return { errors };
}

export function checkAdapters(root) {
  const { errors } = syncAdapters(root, true);
  const geminiPath = path.join(root, 'GEMINI.md');
  if (fs.existsSync(geminiPath)) {
    const geminiContent = fs.readFileSync(geminiPath, 'utf8');
    if (!geminiContent.includes('@./AGENTS.md')) {
      errors.push('GEMINI.md: import do AGENTS.md ausente.');
    }
  }
  const claudePath = path.join(root, 'CLAUDE.md');
  if (fs.existsSync(claudePath)) {
    const claudeContent = fs.readFileSync(claudePath, 'utf8');
    if (!claudeContent.includes('@AGENTS.md') && !claudeContent.includes('@./AGENTS.md')) {
      errors.push('CLAUDE.md: import do AGENTS.md ausente.');
    }
  }
  return { errors };
}

export function checkEvals(root) {
  const errors = [];
  const evalIds = new Set();
  const searchDirs = [
    path.join(root, 'evals'),
    path.join(root, 'skills')
  ];

  function walk(dir) {
    if (!fs.existsSync(dir)) return;
    for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
      const fullPath = path.join(dir, entry.name);
      if (entry.isDirectory()) {
        walk(fullPath);
      } else if (entry.isFile() && entry.name.endsWith('.json') && !entry.name.endsWith('.schema.json')) {
        try {
          const content = fs.readFileSync(fullPath, 'utf8');
          const data = JSON.parse(content);
          if (Array.isArray(data.evals)) {
            for (const item of data.evals) {
              if (!item.id || !item.category || !item.description || !item.input || !item.expected || !item.assertions) {
                errors.push(`${path.relative(root, fullPath)}: caso de eval '${item.id || 'sem id'}' omite campos obrigatórios.`);
              }
              if (item.id) {
                if (evalIds.has(item.id)) {
                  errors.push(`Evals: ID duplicado detectado: '${item.id}'.`);
                }
                evalIds.add(item.id);
              }
            }
          }
        } catch (err) {
          errors.push(`${path.relative(root, fullPath)}: JSON inválido: ${err.message}`);
        }
      }
    }
  }

  for (const d of searchDirs) walk(d);
  return { errors, count: evalIds.size };
}

export function checkFixtureReferences(root) {
  const errors = [];
  const referencedFixtures = new Set();
  const searchDirs = [path.join(root, "evals"), path.join(root, "skills")];

  function walkEvals(dir) {
    if (!fs.existsSync(dir)) return;
    for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
      const fullPath = path.join(dir, entry.name);
      if (entry.isDirectory()) { walkEvals(fullPath); }
      else if (entry.isFile() && entry.name.endsWith(".json") && !entry.name.endsWith(".schema.json")) {
        try {
          const data = JSON.parse(fs.readFileSync(fullPath, "utf8"));
          if (Array.isArray(data.evals)) {
            for (const item of data.evals) {
              if (item.input && item.input.fixture) {
                // Try relative to eval file first, then relative to root
                const relToFile = path.resolve(path.dirname(fullPath), item.input.fixture);
                const relToRoot = path.resolve(root, item.input.fixture);
                const fixturePath = fs.existsSync(relToFile) ? relToFile : (fs.existsSync(relToRoot) ? relToRoot : relToFile);
                // Track both possible resolutions for orphan detection
                referencedFixtures.add(relToFile);
                referencedFixtures.add(relToRoot);
                if (!fs.existsSync(fixturePath)) {
                  errors.push(`${path.relative(root, fullPath)}: fixture inexistente: ${item.input.fixture}`);
                }
              }
            }
          }
        } catch { /* JSON parse errors are caught by checkEvals */ }
      }
    }
  }

  for (const d of searchDirs) walkEvals(d);

  function walkFixtures(dir) {
    if (!fs.existsSync(dir)) return;
    for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
      const fullPath = path.join(dir, entry.name);
      if (entry.isDirectory()) {
        if (entry.name === "fixtures") { scanFixtureDir(fullPath); }
        else { walkFixtures(fullPath); }
      }
    }
  }

  function scanFixtureDir(fixturesDir) {
    for (const entry of fs.readdirSync(fixturesDir, { withFileTypes: true })) {
      const fullPath = path.join(fixturesDir, entry.name);
      if (entry.isDirectory()) {
        for (const fEntry of fs.readdirSync(fullPath, { withFileTypes: true })) {
          if (fEntry.isFile()) {
            const filePath = path.join(fullPath, fEntry.name);
            if (!referencedFixtures.has(filePath)) {
              errors.push(`${path.relative(root, filePath)}: fixture órfão (nenhum eval o referencia).`);
            }
          }
        }
      } else if (entry.isFile() && !referencedFixtures.has(fullPath)) {
        errors.push(`${path.relative(root, fullPath)}: fixture órfão (nenhum eval o referencia).`);
      }
    }
  }

  for (const d of [path.join(root, "skills"), path.join(root, "evals")]) walkFixtures(d);
  return { errors };
}

export function checkDrift(root) {
  const errors = [];
  const skillsYamlPath = path.join(root, 'registry', 'skills.yaml');
  if (!fs.existsSync(skillsYamlPath)) return { errors: [] };

  const skillsYaml = parseSimpleYaml(fs.readFileSync(skillsYamlPath, 'utf8'), 'registry/skills.yaml');
  const registeredSkills = Object.keys(skillsYaml.skills || {});

  // Verificar docs/agents/skills/README.md
  const skillsCatalogPath = path.join(root, 'docs', 'agents', 'skills', 'README.md');
  if (fs.existsSync(skillsCatalogPath)) {
    const catalog = fs.readFileSync(skillsCatalogPath, 'utf8');
    for (const skill of registeredSkills) {
      if (!new RegExp(`(?<![\\w-])${skill}(?![\\w-])`).test(catalog)) {
        errors.push(`docs/agents/skills/README.md: skill '${skill}' do registry não está catalogada.`);
      }
    }
  }

  // Verificar README.md raiz
  const rootReadmePath = path.join(root, 'README.md');
  if (fs.existsSync(rootReadmePath)) {
    const readme = fs.readFileSync(rootReadmePath, 'utf8');
    for (const skill of registeredSkills) {
      if (!new RegExp(`(?<![\\w-])${skill}(?![\\w-])`).test(readme)) {
        errors.push(`README.md: skill '${skill}' do registry ausente da árvore distribuída.`);
      }
    }
  }

  return { errors };
}

export function runDoctor(repositoryRoot) {
  const root = path.resolve(repositoryRoot);
  const results = {
    registry: checkRegistry(root),
    contracts: checkContracts(root),
    skills: checkSkills(root),
    adapters: checkAdapters(root),
    evals: checkEvals(root),
    evalsH1: runEvalsH1(root),
    fixtureRefs: checkFixtureReferences(root),
    drift: checkDrift(root)
  };

  const allErrors = [
    ...results.registry.errors,
    ...results.contracts.errors,
    ...results.skills.errors,
    ...results.adapters.errors,
    ...results.evals.errors,
    ...results.evalsH1.failures.map(f => `eval ${f.id} falhou no nível H1`),
    ...results.fixtureRefs.errors,
    ...results.drift.errors
  ];

  return { results, errors: allErrors };
}

function main() {
  const root = path.resolve('.');
  process.stdout.write('==> Executando Harness Doctor (Diagnóstico Estrutural v2)...\n\n');

  const { results, errors } = runDoctor(root);

  function printCheck(name, errs, detail = '') {
    if (errs.length === 0) {
      process.stdout.write(`[PASS] ${name}${detail ? ` (${detail})` : ''}\n`);
    } else {
      process.stdout.write(`[FAIL] ${name} - ${errs.length} erro(s):\n`);
      for (const e of errs) {
        process.stdout.write(`       - ${e}\n`);
      }
    }
  }

  printCheck('Registry', results.registry.errors, 'harness, skills, standards, runtimes, tooling');
  printCheck('Contracts', results.contracts.errors, 'schemas formais em contracts/');
  printCheck('Skills', results.skills.errors, 'capability packages em skills/');
  printCheck('Adapters', results.adapters.errors, 'paridade entre skills/, .agents/ e .claude/');
  const evalH1Errors = results.evalsH1.failures.map(f => `${f.id}: falhou em H1`);
  printCheck('Evals', [...results.evals.errors, ...evalH1Errors], `H0 ${results.evals.count}/${results.evals.count} PASS, H1 ${results.evalsH1.h1Passed}/${results.evalsH1.h1Executed} PASS`);
  printCheck('Fixtures', results.fixtureRefs.errors, 'integridade referencial de fixtures');
  printCheck('Drift', results.drift.errors, 'paridade entre registry e documentação');

  process.stdout.write('\n');
  if (errors.length > 0) {
    process.stderr.write(`Diagnóstico concluído com ${errors.length} erro(s).\n`);
    process.exitCode = 1;
  } else {
    process.stdout.write('Diagnóstico concluído com sucesso: todos os componentes v2 conformes!\n');
    process.exitCode = 0;
  }
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  main();
}
