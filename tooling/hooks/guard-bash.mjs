#!/usr/bin/env node

/**
 * PreToolUse Hook: guard-bash
 * Bloqueia comandos de escrita, mutação de arquivos e operações git destrutivas
 * quando executados no contexto de avaliação/auditoria (GateEvaluator).
 * Código de saída 2: bloqueia execução e envia mensagem ao modelo via stderr.
 * Código de saída 0: autoriza execução.
 */

import process from 'node:process';

export function isForbiddenBashCommand(command) {
  if (!command || typeof command !== 'string') return { forbidden: false };
  const cmd = command.trim();

  // Bloqueio de redirecionamentos de saída (> ou >>) ou pipe para tee
  if (/(?:^|\s)(?:>>?|tee)(?:\s|$)/.test(cmd)) {
    return { forbidden: true, reason: 'Redirecionamento de saída ou pipe para tee vedado para o avaliador.' };
  }

  // Bloqueio de comandos de escrita e manipulação de arquivos
  if (/(?:^|[;&|]\s*)(?:rm|mv|cp|sed\s+-i|chmod|chown)(?:\s|$)/.test(cmd)) {
    return { forbidden: true, reason: 'Comandos de escrita, remoção ou modificação de arquivos vedados para o avaliador.' };
  }

  // Bloqueio de comandos Git de escrita ou mutação de branches/tags
  if (/(?:^|[;&|]\s*)git\s+(?:commit|push|add|checkout|reset|merge|rebase|tag|branch\s+-[dD])(?:\s|$)/.test(cmd)) {
    return { forbidden: true, reason: 'Operações Git de escrita ou alteração de estado vedadas para o avaliador.' };
  }

  return { forbidden: false };
}

export function handlePreToolUseBash(inputJson) {
  let data;
  try {
    data = typeof inputJson === 'string' ? JSON.parse(inputJson) : inputJson;
  } catch {
    return { allow: true };
  }

  const tool = data.tool || data.tool_name || '';
  if (tool !== 'Bash') return { allow: true };

  const isEvaluator = data.agent === 'GateEvaluator' ||
                      data.subagent === 'GateEvaluator' ||
                      process.env.HARNESS_SUBAGENT === 'GateEvaluator';

  // Se executado no contexto do GateEvaluator (ou em modo forçado)
  if (isEvaluator) {
    const cmd = data.parameters?.command || data.command || '';
    const check = isForbiddenBashCommand(cmd);
    if (check.forbidden) {
      return {
        allow: false,
        reason: `BLOCKED by guard-bash: ${check.reason} (command: ${cmd})`
      };
    }
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
    const result = handlePreToolUseBash(rawInput);
    if (!result.allow) {
      process.stderr.write(`${result.reason}\n`);
      process.exit(2);
    }
    process.exit(0);
  });
}

if (process.argv[1] && process.argv[1].endsWith('guard-bash.mjs')) {
  main();
}
