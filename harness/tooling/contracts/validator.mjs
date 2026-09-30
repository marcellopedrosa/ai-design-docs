#!/usr/bin/env node

/**
 * Validador determinístico leve de JSON Schema para os contratos do harness.
 * Implementa validação estrutural pura em Node.js (Draft-07 / 2020-12 subset):
 * - type (object, array, string, number, integer, boolean)
 * - required
 * - properties & nested properties
 * - additionalProperties (boolean)
 * - enum
 * - items (array element schema)
 * - minItems
 */

const VALID_TYPES = new Set(['object', 'array', 'string', 'number', 'integer', 'boolean', 'null']);

export function validateSchemaSyntax(schema, schemaName = 'schema') {
  const errors = [];
  if (!schema || typeof schema !== 'object' || Array.isArray(schema)) {
    return { valid: false, errors: [`${schemaName}: schema deve ser um objeto JSON.`] };
  }

  if (!schema.$schema || typeof schema.$schema !== 'string') {
    errors.push(`${schemaName}: campo '$schema' obrigatório ausente ou inválido.`);
  }

  if (!schema.title || typeof schema.title !== 'string') {
    errors.push(`${schemaName}: campo 'title' obrigatório ausente ou inválido.`);
  }

  if (!schema.type || !VALID_TYPES.has(schema.type)) {
    errors.push(`${schemaName}: campo 'type' ausente ou inválido: '${schema.type}'.`);
  }

  if (schema.required !== undefined) {
    if (!Array.isArray(schema.required)) {
      errors.push(`${schemaName}: campo 'required' deve ser um array.`);
    } else {
      for (const reqField of schema.required) {
        if (typeof reqField !== 'string') {
          errors.push(`${schemaName}: item em 'required' deve ser string.`);
        } else if (schema.properties && !(reqField in schema.properties)) {
          errors.push(`${schemaName}: campo obrigatório '${reqField}' não está definido em 'properties'.`);
        }
      }
    }
  }

  if (schema.properties !== undefined) {
    if (typeof schema.properties !== 'object' || Array.isArray(schema.properties)) {
      errors.push(`${schemaName}: campo 'properties' deve ser um objeto.`);
    }
  }

  return { valid: errors.length === 0, errors };
}

export function validateInstance(schema, instance, instancePath = '$') {
  const errors = [];

  if (schema === undefined || schema === null) {
    return { valid: true, errors: [] };
  }

  // Type check
  if (schema.type) {
    const actualType = getActualType(instance);
    if (!isTypeMatch(schema.type, actualType)) {
      errors.push(`${instancePath}: tipo esperado '${schema.type}', obtido '${actualType}'.`);
      return { valid: false, errors };
    }
  }

  // Enum check
  if (schema.enum && Array.isArray(schema.enum)) {
    if (!schema.enum.includes(instance)) {
      errors.push(`${instancePath}: valor '${instance}' não pertence ao enum [${schema.enum.map(e => JSON.stringify(e)).join(', ')}].`);
    }
  }

  // Object checks
  if (schema.type === 'object' && instance && typeof instance === 'object' && !Array.isArray(instance)) {
    // Required fields
    if (Array.isArray(schema.required)) {
      for (const field of schema.required) {
        if (!(field in instance) || instance[field] === undefined) {
          errors.push(`${instancePath}: campo obrigatório '${field}' ausente.`);
        }
      }
    }

    // additionalProperties: false ou schema
    if (schema.additionalProperties === false && schema.properties) {
      const allowedProps = new Set(Object.keys(schema.properties));
      for (const key of Object.keys(instance)) {
        if (!allowedProps.has(key)) {
          errors.push(`${instancePath}: propriedade não permitida '${key}' (additionalProperties: false).`);
        }
      }
    } else if (typeof schema.additionalProperties === 'object' && schema.additionalProperties !== null) {
      const declaredProps = new Set(Object.keys(schema.properties || {}));
      for (const [key, val] of Object.entries(instance)) {
        if (!declaredProps.has(key)) {
          const subResult = validateInstance(schema.additionalProperties, val, `${instancePath}.${key}`);
          if (!subResult.valid) {
            errors.push(...subResult.errors);
          }
        }
      }
    }

    // Properties validation
    if (schema.properties) {
      for (const [propName, propSchema] of Object.entries(schema.properties)) {
        if (propName in instance && instance[propName] !== undefined) {
          const subResult = validateInstance(propSchema, instance[propName], `${instancePath}.${propName}`);
          if (!subResult.valid) {
            errors.push(...subResult.errors);
          }
        }
      }
    }
  }

  // Array checks
  if (schema.type === 'array' && Array.isArray(instance)) {
    if (typeof schema.minItems === 'number' && instance.length < schema.minItems) {
      errors.push(`${instancePath}: array com ${instance.length} itens; mínimo exigido é ${schema.minItems}.`);
    }

    if (schema.items) {
      for (let i = 0; i < instance.length; i++) {
        const itemResult = validateInstance(schema.items, instance[i], `${instancePath}[${i}]`);
        if (!itemResult.valid) {
          errors.push(...itemResult.errors);
        }
      }
    }
  }

  return { valid: errors.length === 0, errors };
}

function getActualType(val) {
  if (val === null) return 'null';
  if (Array.isArray(val)) return 'array';
  if (typeof val === 'number') {
    return Number.isInteger(val) ? 'integer' : 'number';
  }
  return typeof val;
}

function isTypeMatch(expected, actual) {
  if (expected === actual) return true;
  if (expected === 'number' && actual === 'integer') return true;
  return false;
}

export function compileSchema(schema, schemaName = 'schema') {
  const syntaxCheck = validateSchemaSyntax(schema, schemaName);
  if (!syntaxCheck.valid) {
    const err = new Error(`Schema inválido (${schemaName}): ${syntaxCheck.errors.join('; ')}`);
    err.errors = syntaxCheck.errors;
    throw err;
  }

  return function validator(instance) {
    return validateInstance(schema, instance);
  };
}
