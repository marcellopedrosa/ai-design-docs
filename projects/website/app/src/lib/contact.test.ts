import { describe, expect, it } from 'vitest';
import {
  commercialContactCreatedSchema,
  commercialContactRequestSchema,
  contactPayloadSchema,
  contactResponseSchema,
  formatContactPhone,
} from './contact';

describe('contactPayloadSchema', () => {
  const validPayload = {
    name: 'Ana Contadora',
    email: 'ana@escritorio.example',
    company: 'Escritório Aurora',
    phone: '(81) 99999.9999',
    plan: 'BUSINESS',
    message: 'Quero entender como automatizar as consultas fiscais.',
    website: '',
  };

  it('accepts a complete business lead', () => {
    expect(contactPayloadSchema.safeParse(validPayload).success).toBe(true);
  });

  it('derives the backend request without the honeypot', () => {
    const parsed = contactPayloadSchema.parse(validPayload);
    const request = commercialContactRequestSchema.parse(parsed);

    expect(request).toEqual({
      name: validPayload.name,
      email: validPayload.email,
      company: validPayload.company,
      phone: validPayload.phone,
      plan: validPayload.plan,
      message: validPayload.message,
    });
    expect(request).not.toHaveProperty('website');
  });

  it('rejects honeypot content and unknown plans', () => {
    expect(
      contactPayloadSchema.safeParse({ ...validPayload, website: 'spam.example' }).success,
    ).toBe(false);
    expect(contactPayloadSchema.safeParse({ ...validPayload, plan: 'ENTERPRISE' }).success).toBe(
      false,
    );
  });

  it('rejects invalid contact data', () => {
    expect(contactPayloadSchema.safeParse({ ...validPayload, email: 'invalid' }).success).toBe(
      false,
    );
    expect(contactPayloadSchema.safeParse({ ...validPayload, message: 'curta' }).success).toBe(
      false,
    );
    expect(contactPayloadSchema.safeParse({ ...validPayload, phone: '' }).success).toBe(false);
    expect(contactPayloadSchema.safeParse({ ...validPayload, phone: '81999999999' }).success).toBe(
      false,
    );
  });

  it('formats phone input with the required mask and limits it to eleven digits', () => {
    expect(formatContactPhone('8')).toBe('(8');
    expect(formatContactPhone('81')).toBe('(81) ');
    expect(formatContactPhone('8199999')).toBe('(81) 99999');
    expect(formatContactPhone('81999999999')).toBe('(81) 99999.9999');
    expect(formatContactPhone('(81) 99999.9999 extra 123')).toBe('(81) 99999.9999');
  });

  it('accepts and formats a ten-digit landline', () => {
    const phone = formatContactPhone('8133334444');

    expect(phone).toBe('(81) 3333.4444');
    expect(contactPayloadSchema.safeParse({ ...validPayload, phone }).success).toBe(true);
  });
});

describe('commercial contact response contract', () => {
  const created = {
    id: '6d5c1539-8995-4a45-b71c-9c8e994dfca6',
    status: 'NEW' as const,
    createdAt: '2026-09-05T12:30:00Z',
  };

  it('accepts the minimal backend creation response', () => {
    expect(commercialContactCreatedSchema.parse(created)).toEqual(created);
    expect(contactResponseSchema.safeParse({ code: 'SUCCESS', ...created }).success).toBe(true);
  });

  it('rejects a success response that does not confirm a NEW contact', () => {
    expect(
      contactResponseSchema.safeParse({ code: 'SUCCESS', ...created, status: 'PENDING' }).success,
    ).toBe(false);
  });
});
