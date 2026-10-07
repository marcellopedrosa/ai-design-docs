#!/usr/bin/env node

import { spawn } from 'node:child_process';
import { cpSync, mkdtempSync, rmSync, symlinkSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join, resolve } from 'node:path';
import process from 'node:process';
import { fileURLToPath } from 'node:url';

const SCRIPT_PATH = fileURLToPath(import.meta.url);
const WEBSITE_DIRECTORY = resolve(dirname(SCRIPT_PATH), '..');
const NEXT_CLI_PATH = resolve(WEBSITE_DIRECTORY, 'node_modules', 'next', 'dist', 'bin', 'next');
const PROJECT_ENTRIES = [
  'next.config.ts',
  'package.json',
  'postcss.config.mjs',
  'src',
  'tsconfig.json',
];

export function createIsolatedWebsite(
  sourceDirectory = WEBSITE_DIRECTORY,
  temporaryDirectory = tmpdir(),
) {
  const runtimeDirectory = mkdtempSync(join(temporaryDirectory, 'agente-fiscal-website-e2e-'));

  try {
    for (const entry of PROJECT_ENTRIES) {
      cpSync(resolve(sourceDirectory, entry), resolve(runtimeDirectory, entry), {
        recursive: true,
        errorOnExist: true,
        force: false,
      });
    }

    symlinkSync(
      resolve(sourceDirectory, 'node_modules'),
      resolve(runtimeDirectory, 'node_modules'),
      'dir',
    );
    return runtimeDirectory;
  } catch (error) {
    rmSync(runtimeDirectory, { recursive: true, force: true });
    throw error;
  }
}

export function createNextE2eInvocation(runtimeDirectory, environment = process.env) {
  const isolatedEnvironment = {
    ...environment,
    NODE_ENV: 'development',
    NEXT_STATIC_HTML_EXPORT: '',
    CONTACT_WEBHOOK_URL: '',
    CONTACT_WEBHOOK_TOKEN: '',
    NEXT_PUBLIC_RECAPTCHA_SITE_KEY: '',
    RECAPTCHA_SECRET_KEY: '',
    RECAPTCHA_ALLOWED_HOSTNAMES: '',
    RECAPTCHA_VERIFY_TIMEOUT_MS: '',
  };
  delete isolatedEnvironment.__NEXT_PROCESSED_ENV;

  return {
    command: process.execPath,
    args: [NEXT_CLI_PATH, 'dev', '--webpack', '--port', '3102'],
    options: {
      cwd: runtimeDirectory,
      env: isolatedEnvironment,
      stdio: 'inherit',
    },
  };
}

function runNextE2e(runtimeDirectory) {
  const invocation = createNextE2eInvocation(runtimeDirectory);
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
  const runtimeDirectory = createIsolatedWebsite();

  try {
    return await runNextE2e(runtimeDirectory);
  } finally {
    rmSync(runtimeDirectory, { recursive: true, force: true });
  }
}

if (process.argv[1] && resolve(process.argv[1]) === SCRIPT_PATH) {
  main()
    .then((exitCode) => {
      process.exitCode = exitCode;
    })
    .catch(() => {
      console.error('ERROR: Nao foi possivel iniciar o website E2E isolado.');
      process.exitCode = 1;
    });
}
