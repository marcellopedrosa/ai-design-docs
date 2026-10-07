import { NextRequest, NextResponse } from 'next/server';
import {
  commercialContactCreatedSchema,
  contactPayloadSchema,
  type CommercialContactRequest,
  type ContactPayload,
  type ContactResponse,
  type ContactResponseCode,
} from '@/lib/contact';
import { verifyRecaptcha } from '@/lib/recaptcha';

const MAX_BODY_BYTES = 16_384;
const COMMERCIAL_CONTACT_PATH = '/api/v1/public/commercial/contacts';
const IDEMPOTENCY_HEADER = 'Idempotency-Key';
const TECHNICAL_TOKEN_HEADER = 'X-Website-Contact-Token';
const IDEMPOTENCY_KEY_PATTERN = /^[A-Za-z0-9._:-]{16,128}$/;
const CORRELATION_ID_PATTERN = /^[A-Za-z0-9._:-]{8,128}$/;
class PayloadTooLargeError extends Error {}

type CaptchaOutcome = 'required' | 'invalid' | 'unavailable' | 'valid';

function recordCaptchaOutcome(
  request: NextRequest,
  outcome: CaptchaOutcome,
  startedAt: number,
): void {
  const suppliedCorrelationId = request.headers.get('x-correlation-id')?.trim();
  const correlationId =
    suppliedCorrelationId && CORRELATION_ID_PATTERN.test(suppliedCorrelationId)
      ? suppliedCorrelationId
      : crypto.randomUUID();

  console.info('commercial_contact_captcha', {
    correlationId,
    environment: process.env.NODE_ENV ?? 'unknown',
    latencyMs: Math.max(0, Date.now() - startedAt),
    outcome,
  });
}

function response(
  code: Exclude<ContactResponseCode, 'SUCCESS'>,
  status: number,
  headers?: HeadersInit,
) {
  return NextResponse.json<ContactResponse>(
    { code },
    {
      status,
      headers: { 'Cache-Control': 'no-store', ...Object.fromEntries(new Headers(headers)) },
    },
  );
}

async function readLimitedJson(request: NextRequest): Promise<unknown> {
  const declaredLength = Number(request.headers.get('content-length'));
  if (Number.isFinite(declaredLength) && declaredLength > MAX_BODY_BYTES) {
    throw new PayloadTooLargeError();
  }

  if (!request.body) return null;

  const reader = request.body.getReader();
  const decoder = new TextDecoder();
  let received = 0;
  let body = '';

  while (true) {
    const { done, value } = await reader.read();
    if (done) break;

    received += value.byteLength;
    if (received > MAX_BODY_BYTES) {
      await reader.cancel();
      throw new PayloadTooLargeError();
    }

    body += decoder.decode(value, { stream: true });
  }

  body += decoder.decode();
  return JSON.parse(body);
}

interface BackendConfig {
  token: string;
  url: URL;
}

function validatedBackendConfig(): BackendConfig | null {
  const raw = process.env.CONTACT_WEBHOOK_URL;
  const token = process.env.CONTACT_WEBHOOK_TOKEN?.trim();
  if (!raw || !token || token.length > 1_024 || /[\u0000-\u001f\u007f]/.test(token)) return null;

  try {
    const url = new URL(raw);
    const localDevelopment = process.env.NODE_ENV !== 'production' && url.hostname === 'localhost';
    if (url.protocol !== 'https:' && !(localDevelopment && url.protocol === 'http:')) return null;
    if (url.username || url.password || url.search || url.hash) return null;

    const normalizedPath = url.pathname.replace(/\/+$/, '');
    if (normalizedPath !== COMMERCIAL_CONTACT_PATH) return null;
    url.pathname = COMMERCIAL_CONTACT_PATH;
    return { token, url };
  } catch {
    return null;
  }
}

function readIdempotencyKey(request: NextRequest): string | null {
  const value = request.headers.get(IDEMPOTENCY_HEADER)?.trim();
  return value && IDEMPOTENCY_KEY_PATTERN.test(value) ? value : null;
}

function toCommercialContactRequest(payload: ContactPayload): CommercialContactRequest {
  return {
    name: payload.name,
    email: payload.email,
    company: payload.company,
    phone: payload.phone,
    plan: payload.plan,
    message: payload.message,
  };
}

function upstreamRetryAfter(response: Response): string {
  const retryAfter = response.headers.get('retry-after')?.trim();
  return retryAfter && /^\d{1,5}$/.test(retryAfter) ? retryAfter : '60';
}

export async function POST(request: NextRequest) {
  const startedAt = Date.now();
  let payload: unknown;
  try {
    payload = await readLimitedJson(request);
  } catch (error) {
    if (error instanceof PayloadTooLargeError) return response('PAYLOAD_TOO_LARGE', 413);
    return response('VALIDATION_ERROR', 400);
  }

  const parsed = contactPayloadSchema.safeParse(payload);
  if (!parsed.success) return response('VALIDATION_ERROR', 400);
  const captchaToken =
    typeof payload === 'object' && payload !== null && 'captchaToken' in payload
      ? Reflect.get(payload, 'captchaToken')
      : undefined;
  if (typeof captchaToken !== 'string' || captchaToken.trim().length === 0) {
    recordCaptchaOutcome(request, 'required', startedAt);
    return response('CAPTCHA_REQUIRED', 400);
  }
  if (captchaToken.length > 4_096) {
    recordCaptchaOutcome(request, 'invalid', startedAt);
    return response('CAPTCHA_INVALID', 422);
  }

  const idempotencyKey = readIdempotencyKey(request);
  if (!idempotencyKey) return response('VALIDATION_ERROR', 400);

  const backend = validatedBackendConfig();
  if (!backend) return response('NOT_CONFIGURED', 503);

  const captchaResult = await verifyRecaptcha(captchaToken);
  if (captchaResult === 'invalid') {
    recordCaptchaOutcome(request, 'invalid', startedAt);
    return response('CAPTCHA_INVALID', 422);
  }
  if (captchaResult === 'unavailable') {
    recordCaptchaOutcome(request, 'unavailable', startedAt);
    return response('CAPTCHA_UNAVAILABLE', 503);
  }
  recordCaptchaOutcome(request, 'valid', startedAt);

  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 6_000);

  try {
    const delivery = await fetch(backend.url, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        [IDEMPOTENCY_HEADER]: idempotencyKey,
        [TECHNICAL_TOKEN_HEADER]: backend.token,
      },
      signal: controller.signal,
      body: JSON.stringify(toCommercialContactRequest(parsed.data)),
      cache: 'no-store',
    });

    if (delivery.status === 400) return response('VALIDATION_ERROR', 400);
    if (delivery.status === 413) return response('PAYLOAD_TOO_LARGE', 413);
    if (delivery.status === 429) {
      return response('RATE_LIMITED', 429, { 'Retry-After': upstreamRetryAfter(delivery) });
    }
    if (delivery.status === 401 || delivery.status === 403) {
      return response('NOT_CONFIGURED', 503);
    }
    if (!delivery.ok) return response('DELIVERY_ERROR', 502);

    const created = commercialContactCreatedSchema.safeParse(await delivery.json());
    if (!created.success) return response('DELIVERY_ERROR', 502);

    return NextResponse.json<ContactResponse>(
      { code: 'SUCCESS', ...created.data },
      { status: 201, headers: { 'Cache-Control': 'no-store' } },
    );
  } catch {
    return response('DELIVERY_ERROR', 502);
  } finally {
    clearTimeout(timeout);
  }
}
