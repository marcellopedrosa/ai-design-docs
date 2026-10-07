import { z } from 'zod';

export const CONTACT_PLAN_TYPES = ['START', 'BUSINESS', 'PREMIUM', 'NOT_SURE'] as const;
const CONTACT_PHONE_PATTERN = /^\(\d{2}\) (?:\d{4}|\d{5})\.\d{4}$/;

export function formatContactPhone(value: string): string {
  const digits = value.replace(/\D/g, '').slice(0, 11);
  if (!digits) return '';

  const areaCode = digits.slice(0, 2);
  const firstPartLength = digits.length === 10 ? 4 : 5;
  const firstPart = digits.slice(2, 2 + firstPartLength);
  const secondPart = digits.slice(2 + firstPartLength);

  if (digits.length < 2) return `(${areaCode}`;
  if (!firstPart) return `(${areaCode}) `;
  if (!secondPart) return `(${areaCode}) ${firstPart}`;
  return `(${areaCode}) ${firstPart}.${secondPart}`;
}

export const contactPayloadSchema = z.object({
  name: z.string().trim().min(2).max(100),
  email: z.string().trim().email().max(160),
  company: z.string().trim().min(2).max(140),
  phone: z.string().trim().regex(CONTACT_PHONE_PATTERN),
  plan: z.enum(CONTACT_PLAN_TYPES),
  message: z.string().trim().min(10).max(1500),
  website: z.string().max(0).optional().default(''),
});

export type ContactPayload = z.infer<typeof contactPayloadSchema>;

export const contactSubmissionSchema = contactPayloadSchema.extend({
  captchaToken: z.string().trim().min(1).max(4096),
});

export type ContactSubmission = z.infer<typeof contactSubmissionSchema>;

export const commercialContactRequestSchema = contactPayloadSchema.omit({ website: true });

export type CommercialContactRequest = z.infer<typeof commercialContactRequestSchema>;

export const commercialContactCreatedSchema = z
  .object({
    id: z.string().trim().uuid(),
    status: z.literal('NEW'),
    createdAt: z.string().datetime({ offset: true }),
  })
  .strict();

export type CommercialContactCreated = z.infer<typeof commercialContactCreatedSchema>;

export type ContactResponseCode =
  | 'SUCCESS'
  | 'VALIDATION_ERROR'
  | 'NOT_CONFIGURED'
  | 'RATE_LIMITED'
  | 'DELIVERY_ERROR'
  | 'PAYLOAD_TOO_LARGE'
  | 'CAPTCHA_REQUIRED'
  | 'CAPTCHA_INVALID'
  | 'CAPTCHA_UNAVAILABLE';

export const contactResponseSchema = z.discriminatedUnion('code', [
  commercialContactCreatedSchema.extend({ code: z.literal('SUCCESS') }),
  z.object({
    code: z.enum([
      'VALIDATION_ERROR',
      'NOT_CONFIGURED',
      'RATE_LIMITED',
      'DELIVERY_ERROR',
      'PAYLOAD_TOO_LARGE',
      'CAPTCHA_REQUIRED',
      'CAPTCHA_INVALID',
      'CAPTCHA_UNAVAILABLE',
    ]),
  }),
]);

export type ContactResponse = z.infer<typeof contactResponseSchema>;
