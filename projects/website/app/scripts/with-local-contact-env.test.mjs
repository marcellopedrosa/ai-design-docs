import assert from 'node:assert/strict';
import { chmodSync, mkdtempSync, rmSync, symlinkSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { afterEach, describe, test } from 'node:test';
import {
  LocalContactEnvironmentError,
  assertDevelopmentEnvironment,
  createNextDevInvocation,
  parseGeneratedContactToken,
  readGeneratedContactToken,
  resolveLocalContactEnvironment,
} from './with-local-contact-env.mjs';

const TOKEN = 'a'.repeat(64);
const CUSTOM_TOKEN = 'b'.repeat(64);
const LOCAL_CONTACT_URL = 'http://localhost:8080/api/v1/public/commercial/contacts';
const temporaryDirectories = [];

function createSecureGeneratedEnv(
  contents = `DB_PASSWORD=not-imported\nCONTACT_WEBHOOK_TOKEN=${TOKEN}\n`,
) {
  const directory = mkdtempSync(join(tmpdir(), 'website-contact-env-'));
  const file = join(directory, '.env.dev.local');
  temporaryDirectories.push(directory);
  writeFileSync(file, contents, { encoding: 'utf8', mode: 0o600 });
  chmodSync(file, 0o600);
  return file;
}

afterEach(() => {
  while (temporaryDirectories.length > 0) {
    rmSync(temporaryDirectories.pop(), { recursive: true, force: true });
  }
});

describe('local commercial-contact environment', () => {
  test('preserves explicit website configuration without opening the generated backend env', () => {
    const environment = resolveLocalContactEnvironment(
      {
        CONTACT_WEBHOOK_URL: 'https://api.example.test/api/v1/public/commercial/contacts',
        CONTACT_WEBHOOK_TOKEN: CUSTOM_TOKEN,
      },
      '/path/that/must/not/be-opened',
    );

    assert.equal(
      environment.CONTACT_WEBHOOK_URL,
      'https://api.example.test/api/v1/public/commercial/contacts',
    );
    assert.equal(environment.CONTACT_WEBHOOK_TOKEN, CUSTOM_TOKEN);
    assert.equal(environment.NODE_ENV, 'development');
  });

  test('fills only blank contact settings from the owner-only generated DEV env', () => {
    const generatedEnv = createSecureGeneratedEnv();
    const environment = resolveLocalContactEnvironment(
      {
        CONTACT_WEBHOOK_URL: '',
        CONTACT_WEBHOOK_TOKEN: '',
        NEXT_PUBLIC_SITE_URL: 'http://localhost:3002',
      },
      generatedEnv,
    );

    assert.equal(environment.CONTACT_WEBHOOK_URL, LOCAL_CONTACT_URL);
    assert.equal(environment.CONTACT_WEBHOOK_TOKEN, TOKEN);
    assert.equal(environment.NEXT_PUBLIC_SITE_URL, 'http://localhost:3002');
    assert.equal(environment.DB_PASSWORD, undefined);
  });

  test('rejects partial configuration instead of pairing a local token with another URL', () => {
    const generatedEnv = createSecureGeneratedEnv();

    assert.throws(
      () =>
        resolveLocalContactEnvironment(
          {
            CONTACT_WEBHOOK_URL: 'https://remote.example.test/api/v1/public/commercial/contacts',
            CONTACT_WEBHOOK_TOKEN: '',
          },
          generatedEnv,
        ),
      LocalContactEnvironmentError,
    );
    assert.throws(
      () =>
        resolveLocalContactEnvironment(
          { CONTACT_WEBHOOK_URL: '', CONTACT_WEBHOOK_TOKEN: CUSTOM_TOKEN },
          generatedEnv,
        ),
      LocalContactEnvironmentError,
    );
  });

  test('validates explicit URL and token with the BFF security contract', () => {
    for (const environment of [
      {
        CONTACT_WEBHOOK_URL: 'http://remote.example.test/api/v1/public/commercial/contacts',
        CONTACT_WEBHOOK_TOKEN: CUSTOM_TOKEN,
      },
      {
        CONTACT_WEBHOOK_URL: 'https://api.example.test/wrong-path',
        CONTACT_WEBHOOK_TOKEN: CUSTOM_TOKEN,
      },
      {
        CONTACT_WEBHOOK_URL:
          'https://user:password@api.example.test/api/v1/public/commercial/contacts',
        CONTACT_WEBHOOK_TOKEN: CUSTOM_TOKEN,
      },
      {
        CONTACT_WEBHOOK_URL:
          'https://api.example.test/api/v1/public/commercial/contacts?debug=true',
        CONTACT_WEBHOOK_TOKEN: CUSTOM_TOKEN,
      },
      {
        CONTACT_WEBHOOK_URL: 'https://api.example.test/api/v1/public/commercial/contacts',
        CONTACT_WEBHOOK_TOKEN: 'invalid\nvalue',
      },
    ]) {
      assert.throws(
        () => resolveLocalContactEnvironment(environment, '/path/that/must/not/be-opened'),
        LocalContactEnvironmentError,
      );
    }
  });

  test('extracts only one strict lowercase 32-byte hexadecimal token', () => {
    assert.equal(
      parseGeneratedContactToken(`IGNORED=value\nCONTACT_WEBHOOK_TOKEN=${TOKEN}\n`),
      TOKEN,
    );

    for (const contents of [
      '',
      `CONTACT_WEBHOOK_TOKEN=${TOKEN}\nCONTACT_WEBHOOK_TOKEN=${CUSTOM_TOKEN}\n`,
      `CONTACT_WEBHOOK_TOKEN=${'A'.repeat(64)}\n`,
      'CONTACT_WEBHOOK_TOKEN=short\n',
      `CONTACT_WEBHOOK_TOKEN="${TOKEN}"\n`,
      `CONTACT_WEBHOOK_TOKEN=${TOKEN}\rTRAILING_GARBAGE\n`,
    ]) {
      assert.throws(() => parseGeneratedContactToken(contents), LocalContactEnvironmentError);
    }
  });

  test('rejects permissive, foreign-owner and symbolic-link sources without exposing values', () => {
    const permissive = createSecureGeneratedEnv();
    chmodSync(permissive, 0o644);
    assert.throws(
      () => readGeneratedContactToken(permissive),
      (error) =>
        error instanceof LocalContactEnvironmentError &&
        error.message.includes('0600') &&
        !error.message.includes(TOKEN),
    );

    const foreignOwner = createSecureGeneratedEnv();
    assert.throws(
      () => readGeneratedContactToken(foreignOwner, (process.getuid?.() ?? 0) + 1),
      LocalContactEnvironmentError,
    );

    const source = createSecureGeneratedEnv();
    const link = `${source}.link`;
    symlinkSync(source, link);
    assert.throws(() => readGeneratedContactToken(link), LocalContactEnvironmentError);

    const directory = mkdtempSync(join(tmpdir(), 'website-contact-directory-'));
    temporaryDirectories.push(directory);
    assert.throws(() => readGeneratedContactToken(directory), LocalContactEnvironmentError);

    const malformedLine = createSecureGeneratedEnv(
      `CONTACT_WEBHOOK_TOKEN=${TOKEN}\rTRAILING_GARBAGE\n`,
    );
    assert.throws(() => readGeneratedContactToken(malformedLine), LocalContactEnvironmentError);
  });

  test('allows only an unset or development NODE_ENV', () => {
    assert.doesNotThrow(() => assertDevelopmentEnvironment(undefined));
    assert.doesNotThrow(() => assertDevelopmentEnvironment('development'));
    assert.throws(() => assertDevelopmentEnvironment('production'), LocalContactEnvironmentError);
    assert.throws(() => assertDevelopmentEnvironment('test'), LocalContactEnvironmentError);
  });

  test('builds a shell-free Next DEV invocation and removes the env-loader marker', () => {
    const generatedEnv = createSecureGeneratedEnv();
    const environment = resolveLocalContactEnvironment(
      { __NEXT_PROCESSED_ENV: 'true' },
      generatedEnv,
    );
    const invocation = createNextDevInvocation(environment, ['--hostname', '127.0.0.1']);

    assert.equal(invocation.command, process.execPath);
    assert.deepEqual(invocation.args.slice(-5), [
      'dev',
      '--port',
      '3002',
      '--hostname',
      '127.0.0.1',
    ]);
    assert.equal(invocation.options.cwd.endsWith('/website'), true);
    assert.equal(invocation.options.env.__NEXT_PROCESSED_ENV, undefined);
    assert.equal(invocation.options.stdio, 'inherit');
  });
});
