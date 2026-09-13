import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import test from 'node:test';

import {
  extractControllerOperations,
  parseOpenApiContract,
  validateRepository
} from './validate-api-contract-coverage.mjs';

const controller = `
package example;
import org.springframework.web.bind.annotation.*;
@RestController
@RequestMapping("/api/v1/widgets")
class WidgetController {
  @GetMapping("/{id}")
  public Object getWidget(@PathVariable String id) { return null; }
}
`;

const validContract = `
openapi: 3.1.0
info:
  title: Widget baseline
  version: 0.1.0
x-contract-status: Draft
x-open-questions:
  - id: WIDGET-001
paths:
  /api/v1/widgets/{id}:
    get:
      operationId: getWidget
      security:
        - bearerAuth: []
      x-required-roles:
        []
      x-required-authorities:
        []
      x-authorization-source: SecurityConfig authenticated fallback
      x-authorization-review: required
      x-contract-priority: 5
      x-source-controller: WidgetController.java:7
      x-source-method: WidgetController.getWidget
      x-source-confidence: extracted-not-approved
      x-open-questions:
        - id: WIDGET-GET-001
      responses:
        '200':
          description: Observed success.
        '400':
          description: Observed shared error.
        '401':
          description: Authentication required.
        '403':
          description: Authorization denied.
        '500':
          description: Sanitized failure.
      x-error-contract-review: required
      x-version-policy:
        publicMajor: v1
`;

function fixture() {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'api-contract-coverage-'));
  const java = path.join(root, 'backend', 'src', 'main', 'java', 'example', 'WidgetController.java');
  const contracts = path.join(root, 'docs', 'contracts');
  fs.mkdirSync(path.dirname(java), { recursive: true });
  fs.mkdirSync(contracts, { recursive: true });
  fs.writeFileSync(java, controller);
  fs.writeFileSync(path.join(contracts, 'widget-v1.openapi.yaml'), validContract);
  return root;
}

test('extracts class and method mappings while ignoring comments', () => {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'api-controller-parser-'));
  const file = path.join(root, 'WidgetController.java');
  fs.writeFileSync(file, `${controller}\n// @PostMapping("/ignored")\n`);
  const result = extractControllerOperations(root);
  assert.equal(result.controllerCount, 1);
  assert.deepEqual(
    result.operations.map(({ method, path: route }) => [method, route]),
    [['get', '/api/v1/widgets/{id}']]
  );
  fs.rmSync(root, { recursive: true, force: true });
});

test('parses operation identity, status and responses from the OpenAPI subset', () => {
  const parsed = parseOpenApiContract(validContract, 'widget-v1.openapi.yaml');
  assert.equal(parsed.openapi, '3.1.0');
  assert.equal(parsed.version, '0.1.0');
  assert.equal(parsed.status, 'Draft');
  assert.equal(parsed.operations[0].operationId, 'getWidget');
  assert.deepEqual(parsed.operations[0].responseCodes, ['200', '400', '401', '403', '500']);
});

test('accepts complete one-to-one controller and Draft coverage', () => {
  const root = fixture();
  const result = validateRepository(root);
  assert.deepEqual(result.errors, []);
  assert.deepEqual(result.stats, {
    controllers: 1,
    controllerOperations: 1,
    contracts: 1,
    contractOperations: 1,
    implementedCovered: 1,
    plannedOperations: 0,
    draftOperations: 1
  });
  fs.rmSync(root, { recursive: true, force: true });
});

test('rejects a controller operation without canonical contract coverage', () => {
  const root = fixture();
  const java = path.join(root, 'backend', 'src', 'main', 'java', 'example', 'WidgetController.java');
  fs.writeFileSync(java, controller.replace('\n}', '\n  @PostMapping\n  public Object createWidget() { return null; }\n}\n'));
  const errors = validateRepository(root).errors.join('\n');
  assert.match(errors, /controller operation has no canonical contract: POST \/api\/v1\/widgets/);
  fs.rmSync(root, { recursive: true, force: true });
});

test('rejects a method and path pair declared by two contracts', () => {
  const root = fixture();
  fs.writeFileSync(path.join(root, 'docs', 'contracts', 'duplicate-v1.openapi.yaml'), validContract);
  const errors = validateRepository(root).errors.join('\n');
  assert.match(errors, /contract pair declared more than once/);
  fs.rmSync(root, { recursive: true, force: true });
});

test('rejects a Draft operation without mandatory role declaration', () => {
  const root = fixture();
  const contract = path.join(root, 'docs', 'contracts', 'widget-v1.openapi.yaml');
  fs.writeFileSync(contract, validContract.replace('      x-required-roles:\n        []\n', ''));
  const errors = validateRepository(root).errors.join('\n');
  assert.match(errors, /missing x-required-roles/);
  fs.rmSync(root, { recursive: true, force: true });
});

test('rejects a new contract without an explicit lifecycle status', () => {
  const root = fixture();
  const contract = path.join(root, 'docs', 'contracts', 'widget-v1.openapi.yaml');
  fs.writeFileSync(contract, validContract.replace('x-contract-status: Draft\n', ''));
  const errors = validateRepository(root).errors.join('\n');
  assert.match(errors, /missing contract lifecycle status/);
  fs.rmSync(root, { recursive: true, force: true });
});

test('allows a contracted operation that is explicitly ahead of the controller', () => {
  const root = fixture();
  const contract = path.join(root, 'docs', 'contracts', 'widget-v1.openapi.yaml');
  const planned = validContract.replace(
    'components-not-present:',
    ''
  ) + `
  /api/v1/widgets:
    post:
      operationId: createWidget
      security: []
      x-required-roles: []
      x-required-authorities: []
      x-authorization-source: public decision
      x-authorization-review: required
      x-contract-priority: 2
      x-source-controller: planned
      x-source-method: planned
      x-source-confidence: planned
      x-open-questions:
        - id: WIDGET-CREATE-001
      responses:
        '201':
          description: Planned success.
        '400':
          description: Invalid request.
        '500':
          description: Sanitized failure.
      x-error-contract-review: required
      x-version-policy:
        publicMajor: v1
`;
  fs.writeFileSync(contract, planned);
  const result = validateRepository(root);
  assert.deepEqual(result.errors, []);
  assert.equal(result.stats.plannedOperations, 1);
  fs.rmSync(root, { recursive: true, force: true });
});
