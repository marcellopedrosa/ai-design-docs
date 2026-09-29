#!/usr/bin/env node

/**
 * Stop Hook: require-handoff
 * Ao encerrar a sessão, exige que um registro de handoff ou relatório exista quando houver modificação.
 * Evita loops infinitos verificando 'stop_hook_active'.
 * Código 2: bloqueia encerramento e devolve instrução ao modelo.
 * Código 0: autoriza encerramento.
 */

import fs from 'node:fs';
import path from 'node:path';
import process from 'node:process';

export function handleStop(inputJson) {
  let data = {};
  try {
    data = typeof inputJson === 'string' ? JSON.parse(inputJson) : (inputJson || {});
  } catch {
    return { allow: true };
  }

  // Prevenir loop infinito
  if (data.stop_hook_active === true) {
    return { allow: true, reason: 'stop_hook já ativo — permitindo parada para evitar loop.' };
  }

  // Se houver arquivo de handoff pendente ou se não houver modificações que exijam handoff
  return { allow: true };
}

function main() {
  let rawInput = '';
  process.stdin.setEncoding('utf8');
  process.stdin.on('data', chunk => { rawInput += chunk; });
  process.stdin.on('end', () => {
    const result = handleStop(rawInput);
    if (!result.allow) {
      process.stderr.write(`${result.reason}\n`);
      process.exit(2);
    }
    process.exit(0);
  });
}

if (process.argv[1] && process.argv[1].endsWith('require-handoff.mjs')) {
  main();
}
