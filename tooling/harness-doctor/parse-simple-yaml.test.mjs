import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { parseSimpleYaml, stripInlineComment } from './index.mjs';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const root = path.resolve(__dirname, '../..');

test('T-09: stripInlineComment preserves content inside quotes and cuts in unquoted #', () => {
  assert.equal(stripInlineComment('foo: bar # comment'), 'foo: bar');
  assert.equal(stripInlineComment('url: "https://example.com#anchor" # comment'), 'url: "https://example.com#anchor"');
  assert.equal(stripInlineComment("single: 'val # not comment' # real comment"), "single: 'val # not comment'");
  assert.equal(stripInlineComment('no_comment: value'), 'no_comment: value');
});

test('T-09: throws when list item contains unquoted object syntax (- key: value)', () => {
  const yaml = `
items:
  - name: test
`;
  assert.throws(
    () => parseSimpleYaml(yaml, 'test.yaml'),
    /listas de objetos não suportadas; use chaves aninhadas/
  );
});

test('T-09: allows list item with colon inside quotes', () => {
  const yaml = `
items:
  - "item: with colon"
`;
  const parsed = parseSimpleYaml(yaml, 'test.yaml');
  assert.deepStrictEqual(parsed, { items: ['item: with colon'] });
});

test('T-09: throws when list item appears outside a list parent', () => {
  const yaml = `
- orphan_item
`;
  assert.throws(
    () => parseSimpleYaml(yaml, 'test.yaml'),
    /item de lista fora de lista/
  );
});

test('T-09: throws on unbalanced double or single quotes', () => {
  assert.throws(
    () => parseSimpleYaml('key: "unclosed', 'test.yaml'),
    /aspas desbalanceadas/
  );
  assert.throws(
    () => parseSimpleYaml("key: 'unclosed", 'test.yaml'),
    /aspas desbalanceadas/
  );
  assert.throws(
    () => parseSimpleYaml('key: unclosed"', 'test.yaml'),
    /aspas desbalanceadas/
  );
  assert.throws(
    () => parseSimpleYaml("key: unclosed'", 'test.yaml'),
    /aspas desbalanceadas/
  );
});

test('T-09: parses scalar types correctly (null, ~, numbers, booleans, quoted strings)', () => {
  const yaml = `
null_val: null
tilde_val: ~
int_val: 42
neg_int: -17
float_val: 3.14
quoted_num: "42"
quoted_ver: "2.0.0"
bool_true: true
bool_false: false
str_val: hello world # inline
`;
  const parsed = parseSimpleYaml(yaml, 'types.yaml');
  assert.strictEqual(parsed.null_val, null);
  assert.strictEqual(parsed.tilde_val, null);
  assert.strictEqual(parsed.int_val, 42);
  assert.strictEqual(parsed.neg_int, -17);
  assert.strictEqual(parsed.float_val, 3.14);
  assert.strictEqual(parsed.quoted_num, '42');
  assert.strictEqual(parsed.quoted_ver, '2.0.0');
  assert.strictEqual(parsed.bool_true, true);
  assert.strictEqual(parsed.bool_false, false);
  assert.strictEqual(parsed.str_val, 'hello world');
});

test('T-09: regression - parses harness.project.example.yaml correctly', () => {
  const examplePath = path.join(root, 'harness.project.example.yaml');
  const content = fs.readFileSync(examplePath, 'utf8');
  const parsed = parseSimpleYaml(content, 'harness.project.example.yaml');

  const expected = {
    schema_version: 1,
    harness_version: '2.0.0',
    project: {
      id: 'example-service',
      name: 'Exemplo de Serviço Adotante',
      description: 'Exemplo de manifesto de projeto adotante do AI Engineering Harness'
    },
    runtimes: [
      'codex',
      'claude-code',
      'gemini-cli',
      'antigravity'
    ],
    capabilities: {
      git_delivery: false
    },
    standards: {
      baseline: [
        'software-engineering-lifecycle',
        'implementation-readiness-standard',
        'software-quality-standard',
        'development-standard',
        'security-standard'
      ],
      activated: [
        'java-standard',
        'spring-security-standard',
        'api-security-standard'
      ]
    },
    quality: {
      commands: {
        backend_test: 'mvn test',
        backend_build: 'mvn verify',
        frontend_test: 'npm test'
      }
    },
    security: {
      validators: [
        'mvn org.owasp:dependency-check-maven:check'
      ]
    },
    paths: {
      backend: [
        'backend/'
      ],
      frontend: [
        'frontend/'
      ],
      docs: [
        'docs/'
      ]
    }
  };

  assert.deepStrictEqual(parsed, expected);
});
