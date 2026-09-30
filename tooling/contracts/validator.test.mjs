import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { compileSchema, validateSchemaSyntax, validateInstance } from './validator.mjs';

test('compileSchema compiles all repository contracts successfully', () => {
  const root = path.resolve('.');
  const contractsDir = path.join(root, 'contracts');
  const requiredSchemas = [
    'capability-request.schema.json',
    'readiness-result.schema.json',
    'gate-result.schema.json',
    'evidence.schema.json',
    'security-finding.schema.json',
    'handoff.schema.json',
    'harness-project.schema.json',
    'doctor-result.schema.json'
  ];

  for (const file of requiredSchemas) {
    const raw = fs.readFileSync(path.join(contractsDir, file), 'utf8');
    const parsed = JSON.parse(raw);
    const syntax = validateSchemaSyntax(parsed, file);
    assert.ok(syntax.valid, `Schema syntax error in ${file}: ${syntax.errors.join(', ')}`);
    const validator = compileSchema(parsed, file);
    assert.equal(typeof validator, 'function', `Compiler should return validator function for ${file}`);
  }
});

test('validateSchemaSyntax rejects broken schema with missing title or invalid type', () => {
  const broken1 = { $schema: 'http://json-schema.org/draft-07/schema#', type: 'invalid-type' };
  const res1 = validateSchemaSyntax(broken1, 'broken1');
  assert.ok(!res1.valid, 'Should reject missing title and invalid type');

  const broken2 = {
    $schema: 'http://json-schema.org/draft-07/schema#',
    title: 'Broken',
    type: 'object',
    required: ['non_existent'],
    properties: { existent: { type: 'string' } }
  };
  const res2 = validateSchemaSyntax(broken2, 'broken2');
  assert.ok(!res2.valid, 'Should reject required field not declared in properties');
  assert.ok(res2.errors.some(e => e.includes('non_existent')));
});

test('contracts/examples valid examples pass and invalid examples fail', () => {
  const root = path.resolve('.');
  const contractsDir = path.join(root, 'contracts');
  const examplesDir = path.join(contractsDir, 'examples');

  for (const entry of fs.readdirSync(examplesDir, { withFileTypes: true })) {
    if (entry.isFile() && entry.name.endsWith('.json')) {
      const match = entry.name.match(/^(.+?)\.(valid|invalid)\.json$/);
      if (match) {
        const [, schemaBase, kind] = match;
        const schemaPath = path.join(contractsDir, `${schemaBase}.schema.json`);
        const schema = JSON.parse(fs.readFileSync(schemaPath, 'utf8'));
        const instance = JSON.parse(fs.readFileSync(path.join(examplesDir, entry.name), 'utf8'));
        const validator = compileSchema(schema, schemaBase);
        const result = validator(instance);

        if (kind === 'valid') {
          assert.ok(result.valid, `Valid example ${entry.name} should pass: ${result.errors.join(', ')}`);
        } else {
          assert.ok(!result.valid, `Invalid example ${entry.name} should fail validation`);
        }
      }
    }
  }
});

test('validateInstance enforces additionalProperties: false and enum restrictions', () => {
  const schema = {
    $schema: 'http://json-schema.org/draft-07/schema#',
    title: 'Test',
    type: 'object',
    required: ['status'],
    properties: {
      status: { type: 'string', enum: ['READY', 'BLOCKED'] }
    },
    additionalProperties: false
  };

  const valid = { status: 'READY' };
  assert.ok(validateInstance(schema, valid).valid);

  const invalidEnum = { status: 'PENDING' };
  const resEnum = validateInstance(schema, invalidEnum);
  assert.ok(!resEnum.valid, 'Should reject value not in enum');

  const extraField = { status: 'READY', unexpected: 123 };
  const resExtra = validateInstance(schema, extraField);
  assert.ok(!resExtra.valid, 'Should reject extra field when additionalProperties is false');
});

test('T-10: validateSchemaSyntax rejects unsupported validation keywords like oneOf or if', () => {
  const schemaWithOneOf = {
    $schema: 'http://json-schema.org/draft-07/schema#',
    title: 'OneOfTest',
    type: 'object',
    oneOf: [{ type: 'object' }]
  };
  const resOneOf = validateSchemaSyntax(schemaWithOneOf, 'schemaWithOneOf');
  assert.ok(!resOneOf.valid);
  assert.ok(resOneOf.errors.some(e => e.includes("palavra-chave 'oneOf' não suportada")));

  const schemaWithIf = {
    $schema: 'http://json-schema.org/draft-07/schema#',
    title: 'IfTest',
    type: 'object',
    if: { properties: { foo: { type: 'string' } } }
  };
  const resIf = validateSchemaSyntax(schemaWithIf, 'schemaWithIf');
  assert.ok(!resIf.valid);
  assert.ok(resIf.errors.some(e => e.includes("palavra-chave 'if' não suportada")));

  const schemaWithNestedUnsupported = {
    $schema: 'http://json-schema.org/draft-07/schema#',
    title: 'NestedTest',
    type: 'object',
    properties: {
      field: {
        type: 'string',
        pattern: '^[a-z]+$'
      }
    }
  };
  const resNested = validateSchemaSyntax(schemaWithNestedUnsupported, 'schemaWithNested');
  assert.ok(!resNested.valid);
  assert.ok(resNested.errors.some(e => e.includes("palavra-chave 'pattern' não suportada")));
});

