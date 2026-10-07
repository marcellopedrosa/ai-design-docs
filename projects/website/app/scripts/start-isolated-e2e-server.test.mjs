import assert from 'node:assert/strict';
import {
  existsSync,
  mkdirSync,
  mkdtempSync,
  readFileSync,
  readlinkSync,
  rmSync,
  writeFileSync,
} from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { afterEach, test } from 'node:test';
import { createIsolatedWebsite, createNextE2eInvocation } from './start-isolated-e2e-server.mjs';

const temporaryDirectories = [];

afterEach(() => {
  while (temporaryDirectories.length > 0) {
    rmSync(temporaryDirectories.pop(), { recursive: true, force: true });
  }
});

test('creates an isolated Next project without copying local environment files', () => {
  const sourceDirectory = mkdtempSync(join(tmpdir(), 'website-e2e-source-'));
  const temporaryRoot = mkdtempSync(join(tmpdir(), 'website-e2e-runtime-root-'));
  temporaryDirectories.push(sourceDirectory, temporaryRoot);

  mkdirSync(join(sourceDirectory, 'src'));
  mkdirSync(join(sourceDirectory, 'node_modules'));
  writeFileSync(join(sourceDirectory, 'src', 'page.tsx'), 'export default function Page() {}');
  writeFileSync(join(sourceDirectory, 'next.config.ts'), 'export default {};');
  writeFileSync(join(sourceDirectory, 'package.json'), '{}');
  writeFileSync(join(sourceDirectory, 'postcss.config.mjs'), 'export default {};');
  writeFileSync(join(sourceDirectory, 'tsconfig.json'), '{}');
  writeFileSync(join(sourceDirectory, '.env.local'), 'CONTACT_WEBHOOK_TOKEN=must-not-be-copied');

  const runtimeDirectory = createIsolatedWebsite(sourceDirectory, temporaryRoot);

  assert.equal(readFileSync(join(runtimeDirectory, 'src', 'page.tsx'), 'utf8').length > 0, true);
  assert.equal(existsSync(join(runtimeDirectory, '.env.local')), false);
  assert.equal(existsSync(join(runtimeDirectory, 'next-env.d.ts')), false);
  assert.equal(
    readlinkSync(join(runtimeDirectory, 'node_modules')),
    join(sourceDirectory, 'node_modules'),
  );
});

test('starts Next without a shell and forces the contact fixture to stay unconfigured', () => {
  const invocation = createNextE2eInvocation('/tmp/isolated-website', {
    CONTACT_WEBHOOK_URL: 'https://must-not-be-used.example/api/v1/public/commercial/contacts',
    CONTACT_WEBHOOK_TOKEN: 'must-not-be-used',
    NEXT_PUBLIC_RECAPTCHA_SITE_KEY: 'must-not-be-used',
    RECAPTCHA_SECRET_KEY: 'must-not-be-used',
    RECAPTCHA_ALLOWED_HOSTNAMES: 'must-not-be-used.example',
    RECAPTCHA_VERIFY_TIMEOUT_MS: '5000',
    NEXT_STATIC_HTML_EXPORT: '1',
    __NEXT_PROCESSED_ENV: 'true',
    SAFE_SETTING: 'preserved',
  });

  assert.equal(invocation.command, process.execPath);
  assert.deepEqual(invocation.args.slice(-4), ['dev', '--webpack', '--port', '3102']);
  assert.equal(invocation.options.cwd, '/tmp/isolated-website');
  assert.equal(invocation.options.env.CONTACT_WEBHOOK_URL, '');
  assert.equal(invocation.options.env.CONTACT_WEBHOOK_TOKEN, '');
  assert.equal(invocation.options.env.NEXT_PUBLIC_RECAPTCHA_SITE_KEY, '');
  assert.equal(invocation.options.env.RECAPTCHA_SECRET_KEY, '');
  assert.equal(invocation.options.env.RECAPTCHA_ALLOWED_HOSTNAMES, '');
  assert.equal(invocation.options.env.RECAPTCHA_VERIFY_TIMEOUT_MS, '');
  assert.equal(invocation.options.env.NEXT_STATIC_HTML_EXPORT, '');
  assert.equal(invocation.options.env.__NEXT_PROCESSED_ENV, undefined);
  assert.equal(invocation.options.env.SAFE_SETTING, 'preserved');
  assert.equal(invocation.options.env.NODE_ENV, 'development');
  assert.equal(invocation.options.stdio, 'inherit');
});
