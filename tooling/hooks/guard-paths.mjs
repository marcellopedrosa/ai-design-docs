#!/usr/bin/env node

/**
 * PreToolUse Hook: guard-paths
 * Bloqueia operações de escrita/edição em arquivos de segredos, credenciais e variáveis de ambiente (.env*).
 * Código de saída 2: bloqueia execução e envia mensagem ao modelo via stderr.
 * Código de saída 0: autoriza execução.
 */

import fs from 'node:fs';
import path from 'node:path';
import process from 'node:process';

export function isForbiddenPath(filePath) {
  if (!filePath || typeof filePath !== 'string') return false;
  const normalized = filePath.replace(/\\/g, '/').toLowerCase();
  const basename = path.basename(normalized);

  // Bloqueio de arquivos .env e suas variantes
  if (basename === '.env' || basename.startsWith('.env.')) {
    return { forbidden: true, reason: 'Arquivo de ambiente (.env*) protegido contra modificação.' };
  }

  // Bloqueio de caminhos em diretórios de segredos
  if (/(?:^|\/)(?:\.?)secrets\//i.test(normalized) || /(?:^|\/)credentials(?:\/|\.|$)/i.test(normalized)) {
    return { forbidden: true, reason: 'Diretório ou arquivo de credenciais/segredos protegido.' };
  }

  return { forbidden: false };
}

export function handlePreToolUse(inputJson) {
  let data;
  try {
    data = typeof inputJson === 'string' ? JSON.parse(inputJson) : inputJson;
  } catch {
    // Se JSON não for parseável, permite para não quebrar runtime não-JSON
    return { allow: true };
  }

  const tool = data.tool || data.tool_name || '';
  const isEditTool = ['Edit', 'Write', 'MultiEdit'].includes(tool);
  if (!isEditTool) return { allow: true };

  const targetPath = data.parameters?.file_path || data.parameters?.path || data.file_path || '';
  const check = isForbiddenPath(targetPath);
  if (check.forbidden) {
    return {
      allow: false,
      reason: `BLOCKED by guard-paths: ${check.reason} (path: ${targetPath})`
    };
  }

  return { allow: true };
}

function main() {
  let rawInput = '';
  process.stdin.setEncoding('utf8');
  process.stdin.on('data', chunk => { rawInput += chunk; });
  process.stdin.on('end', () => {
    if (!rawInput.trim()) {
      process.exit(0);
    }
    const result = handlePreToolUse(rawInput);
    if (!result.allow) {
      process.stderr.write(`${result.reason}\n`);
      process.exit(2);
    }
    process.exit(0);
  });
}

if (process.argv[1] && process.argv[1].endsWith('guard-paths.mjs')) {
  main();
}
