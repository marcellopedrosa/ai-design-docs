#!/usr/bin/env node

import { spawn } from 'node:child_process';
import { closeSync, constants, fstatSync, openSync, readSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import process from 'node:process';
import { fileURLToPath } from 'node:url';
import nextEnvironment from '@next/env';

const { loadEnvConfig } = nextEnvironment;

const SCRIPT_PATH = fileURLToPath(import.meta.url);
const WEBSITE_DIRECTORY = resolve(dirname(SCRIPT_PATH), '..');
const GENERATED_ENV_PATH = resolve(WEBSITE_DIRECTORY, '..', '.env.dev.local');
const NEXT_CLI_PATH = resolve(WEBSITE_DIRECTORY, 'node_modules', 'next', 'dist', 'bin', 'next');
const LOCAL_CONTACT_URL = 'http://localhost:8080/api/v1/public/commercial/contacts';
const MAX_GENERATED_ENV_BYTES = 128 * 1024;
const CONTACT_TOKEN_PATTERN = /^[0-9a-f]{64}$/;
const CONTROL_CHARACTER_PATTERN = /[\u0000-\u001f\u007f]/u;
const CONTACT_TOKEN_PREFIX = Buffer.from('CONTACT_WEBHOOK_TOKEN=', 'ascii');

export class LocalContactEnvironmentError extends Error {
  constructor(message) {
    super(message);
    this.name = 'LocalContactEnvironmentError';
  }
}

function isConfigured(value) {
  return typeof value === 'string' && value.trim().length > 0;
}

export function assertDevelopmentEnvironment(nodeEnvironment) {
  if (
    nodeEnvironment !== undefined &&
    nodeEnvironment !== '' &&
    nodeEnvironment !== 'development'
  ) {
    throw new LocalContactEnvironmentError(
      'O bootstrap automático do formulário comercial é exclusivo do ambiente de desenvolvimento.',
    );
  }
}

export function parseGeneratedContactToken(contents) {
  const entries = contents
    .split(/\r?\n/u)
    .filter((line) => line.startsWith('CONTACT_WEBHOOK_TOKEN='));

  if (entries.length !== 1) {
    throw new LocalContactEnvironmentError(
      'A configuração DEV deve possuir exatamente um token técnico do formulário comercial.',
    );
  }

  const token = entries[0].slice('CONTACT_WEBHOOK_TOKEN='.length);
  if (!CONTACT_TOKEN_PATTERN.test(token)) {
    throw new LocalContactEnvironmentError(
      'O token técnico DEV do formulário comercial possui formato inválido.',
    );
  }

  return token;
}

function readContactTokenEntry(descriptor, size) {
  const buffer = Buffer.alloc(4096);
  const entries = [];
  let remaining = size;
  let position = 0;
  let prefixIndex = 0;
  let candidate = true;
  let collectingToken = false;
  let collectedToken = '';
  let tokenOverflow = false;

  const finishLine = () => {
    if (collectingToken) {
      entries.push(
        tokenOverflow
          ? 'invalid'
          : collectedToken.endsWith('\r')
            ? collectedToken.slice(0, -1)
            : collectedToken,
      );
    }
    prefixIndex = 0;
    candidate = true;
    collectingToken = false;
    collectedToken = '';
    tokenOverflow = false;
  };

  while (remaining > 0) {
    const requestedBytes = Math.min(buffer.length, remaining);
    const bytesRead = readSync(descriptor, buffer, 0, requestedBytes, position);
    if (bytesRead === 0) break;

    for (let index = 0; index < bytesRead; index += 1) {
      const byte = buffer[index];
      if (byte === 0x0a) {
        finishLine();
      } else if (collectingToken) {
        if (collectedToken.length < 66) collectedToken += String.fromCharCode(byte);
        else tokenOverflow = true;
      } else if (candidate && byte === CONTACT_TOKEN_PREFIX[prefixIndex]) {
        prefixIndex += 1;
        collectingToken = prefixIndex === CONTACT_TOKEN_PREFIX.length;
      } else {
        candidate = false;
      }
    }

    buffer.fill(0, 0, bytesRead);
    position += bytesRead;
    remaining -= bytesRead;
  }

  buffer.fill(0);
  if (remaining !== 0) {
    throw new LocalContactEnvironmentError(
      'A configuração DEV do backend mudou durante a leitura segura.',
    );
  }
  if (prefixIndex > 0 || collectingToken || collectedToken.length > 0) finishLine();

  return parseGeneratedContactToken(
    entries.map((entry) => `CONTACT_WEBHOOK_TOKEN=${entry}`).join('\n'),
  );
}

export function readGeneratedContactToken(
  generatedEnvPath,
  expectedUid = typeof process.getuid === 'function' ? process.getuid() : undefined,
) {
  let descriptor;

  if (typeof constants.O_NOFOLLOW !== 'number') {
    throw new LocalContactEnvironmentError(
      'A plataforma atual não oferece a proteção necessária para ler a configuração DEV.',
    );
  }

  try {
    descriptor = openSync(
      generatedEnvPath,
      constants.O_RDONLY | constants.O_NOFOLLOW | constants.O_NONBLOCK,
    );
  } catch {
    throw new LocalContactEnvironmentError(
      'A configuração DEV do backend não está disponível. Execute ./start-dev-bot.sh --prepare-env-only na raiz do repositório.',
    );
  }

  try {
    const metadata = fstatSync(descriptor);
    if (!metadata.isFile()) {
      throw new LocalContactEnvironmentError(
        'A configuração DEV do backend deve ser um arquivo regular.',
      );
    }
    if (expectedUid !== undefined && metadata.uid !== expectedUid) {
      throw new LocalContactEnvironmentError(
        'A configuração DEV do backend deve pertencer ao usuário atual.',
      );
    }
    if ((metadata.mode & 0o777) !== 0o600) {
      throw new LocalContactEnvironmentError(
        'A configuração DEV do backend deve usar permissão 0600.',
      );
    }
    if (metadata.size <= 0 || metadata.size > MAX_GENERATED_ENV_BYTES) {
      throw new LocalContactEnvironmentError(
        'A configuração DEV do backend possui tamanho inválido.',
      );
    }

    const token = readContactTokenEntry(descriptor, metadata.size);
    if (fstatSync(descriptor).size !== metadata.size) {
      throw new LocalContactEnvironmentError(
        'A configuração DEV do backend mudou durante a leitura segura.',
      );
    }
    return token;
  } finally {
    closeSync(descriptor);
  }
}

export function resolveLocalContactEnvironment(environment, generatedEnvPath = GENERATED_ENV_PATH) {
  assertDevelopmentEnvironment(environment.NODE_ENV);

  const resolvedEnvironment = { ...environment, NODE_ENV: 'development' };
  const hasExplicitUrl = isConfigured(resolvedEnvironment.CONTACT_WEBHOOK_URL);
  const hasExplicitToken = isConfigured(resolvedEnvironment.CONTACT_WEBHOOK_TOKEN);
  if (hasExplicitUrl !== hasExplicitToken) {
    throw new LocalContactEnvironmentError(
      'URL e token do formulário comercial devem ser configurados juntos ou permanecer ambos vazios no DEV.',
    );
  }

  if (!hasExplicitUrl) {
    resolvedEnvironment.CONTACT_WEBHOOK_URL = LOCAL_CONTACT_URL;
    resolvedEnvironment.CONTACT_WEBHOOK_TOKEN = readGeneratedContactToken(generatedEnvPath);
  }

  validateResolvedContactEnvironment(resolvedEnvironment);
  delete resolvedEnvironment.__NEXT_PROCESSED_ENV;
  return resolvedEnvironment;
}

function validateResolvedContactEnvironment(environment) {
  const token = environment.CONTACT_WEBHOOK_TOKEN?.trim() ?? '';
  if (!token || token.length > 1_024 || CONTROL_CHARACTER_PATTERN.test(token)) {
    throw new LocalContactEnvironmentError(
      'O token técnico configurado para o formulário comercial é inválido.',
    );
  }

  try {
    const url = new URL(environment.CONTACT_WEBHOOK_URL ?? '');
    const validProtocol =
      url.protocol === 'https:' || (url.protocol === 'http:' && url.hostname === 'localhost');
    const normalizedPath = url.pathname.replace(/\/+$/u, '');
    if (
      !validProtocol ||
      url.username ||
      url.password ||
      url.search ||
      url.hash ||
      normalizedPath !== '/api/v1/public/commercial/contacts'
    ) {
      throw new Error('invalid');
    }
  } catch {
    throw new LocalContactEnvironmentError(
      'A URL configurada para o formulário comercial é inválida.',
    );
  }
}

export function createNextDevInvocation(environment, extraArguments = []) {
  return {
    command: process.execPath,
    args: [NEXT_CLI_PATH, 'dev', '--port', '3002', ...extraArguments],
    options: {
      cwd: WEBSITE_DIRECTORY,
      env: environment,
      stdio: 'inherit',
    },
  };
}

function loadWebsiteDevelopmentEnvironment() {
  assertDevelopmentEnvironment(process.env.NODE_ENV);
  process.env.NODE_ENV = 'development';

  const { combinedEnv } = loadEnvConfig(WEBSITE_DIRECTORY, true, console, true);
  return resolveLocalContactEnvironment(combinedEnv);
}

function runNextDev(environment, extraArguments) {
  const invocation = createNextDevInvocation(environment, extraArguments);
  const child = spawn(invocation.command, invocation.args, invocation.options);

  return new Promise((resolveExitCode, reject) => {
    const signalHandlers = new Map();
    const cleanup = () => {
      for (const [signal, handler] of signalHandlers) process.removeListener(signal, handler);
    };

    for (const signal of ['SIGINT', 'SIGTERM']) {
      const handler = () => child.kill(signal);
      signalHandlers.set(signal, handler);
      process.once(signal, handler);
    }

    child.once('error', (error) => {
      cleanup();
      reject(error);
    });
    child.once('exit', (code, signal) => {
      cleanup();
      resolveExitCode(signal ? 1 : (code ?? 1));
    });
  });
}

async function main() {
  const argumentsToForward = process.argv.slice(2);
  const checkOnly = argumentsToForward.length === 1 && argumentsToForward[0] === '--check';
  const environment = loadWebsiteDevelopmentEnvironment();

  if (checkOnly) {
    console.log(
      'Configuração DEV do formulário comercial resolvida e validada; conectividade não testada e segredo não exibido.',
    );
    return 0;
  }

  return runNextDev(environment, argumentsToForward);
}

if (process.argv[1] && resolve(process.argv[1]) === SCRIPT_PATH) {
  main()
    .then((exitCode) => {
      process.exitCode = exitCode;
    })
    .catch((error) => {
      const message =
        error instanceof LocalContactEnvironmentError
          ? error.message
          : 'Não foi possível iniciar o website em modo de desenvolvimento.';
      console.error(`ERROR: ${message}`);
      process.exitCode = 1;
    });
}
