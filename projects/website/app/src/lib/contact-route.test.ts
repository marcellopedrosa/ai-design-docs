import { NextRequest } from 'next/server';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { POST } from '@/app/api/contact/route';

const BACKEND_URL = 'https://api.example.com/api/v1/public/commercial/contacts';
const CREATED_CONTACT = {
  id: '6d5c1539-8995-4a45-b71c-9c8e994dfca6',
  status: 'NEW',
  createdAt: '2026-09-05T12:30:00Z',
};
const VALID_PAYLOAD = {
  name: 'Ana Contadora',
  email: 'ana@escritorio.example',
  company: 'Escritório Aurora',
  phone: '(81) 99999.9999',
  plan: 'BUSINESS',
  message: 'Quero entender como automatizar as consultas fiscais.',
  website: '',
  captchaToken: 'valid-captcha-token',
};

function captchaResponse(
  body: unknown = {
    success: true,
    challenge_ts: new Date().toISOString(),
    hostname: 'www.example.com',
  },
  status = 200,
): Response {
  return backendResponse(body, status);
}

function contactRequest(options: { idempotencyKey?: string; payload?: unknown } = {}) {
  return new NextRequest('http://localhost:3002/api/contact', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Idempotency-Key': options.idempotencyKey ?? '6d5c1539-8995-4a45-b71c-9c8e994dfca6',
    },
    body: JSON.stringify(options.payload ?? VALID_PAYLOAD),
  });
}

function backendResponse(
  body: unknown,
  status = 201,
  headers: Record<string, string> = {},
): Response {
  return {
    ok: status >= 200 && status < 300,
    status,
    headers: new Headers(headers),
    json: vi.fn().mockResolvedValue(body),
  } as unknown as Response;
}

describe('POST /api/contact', () => {
  const fetchMock = vi.fn();
  let telemetry: ReturnType<typeof vi.spyOn>;

  beforeEach(() => {
    fetchMock.mockReset();
    vi.stubGlobal('fetch', fetchMock);
    telemetry = vi.spyOn(console, 'info').mockImplementation(() => undefined);
    vi.stubEnv('CONTACT_WEBHOOK_URL', BACKEND_URL);
    vi.stubEnv('CONTACT_WEBHOOK_TOKEN', 'website-technical-token');
    vi.stubEnv('RECAPTCHA_SECRET_KEY', 'recaptcha-secret');
    vi.stubEnv('RECAPTCHA_ALLOWED_HOSTNAMES', 'www.example.com');
    vi.stubEnv('RECAPTCHA_VERIFY_TIMEOUT_MS', '3000');
  });

  afterEach(() => {
    vi.unstubAllEnvs();
    vi.unstubAllGlobals();
  });

  it('forwards only the backend contract with technical authentication and idempotency', async () => {
    fetchMock
      .mockResolvedValueOnce(captchaResponse())
      .mockResolvedValueOnce(backendResponse(CREATED_CONTACT));

    const response = await POST(contactRequest());

    expect(response.status).toBe(201);
    await expect(response.json()).resolves.toEqual({ code: 'SUCCESS', ...CREATED_CONTACT });
    expect(fetchMock).toHaveBeenCalledTimes(2);

    const [captchaTarget, captchaInit] = fetchMock.mock.calls[0] as [string, RequestInit];
    expect(captchaTarget).toBe('https://www.google.com/recaptcha/api/siteverify');
    expect(captchaInit.body?.toString()).toContain('response=valid-captcha-token');
    expect(captchaInit.body?.toString()).toContain('secret=recaptcha-secret');

    const [target, init] = fetchMock.mock.calls[1] as [URL, RequestInit];
    expect(target.toString()).toBe(BACKEND_URL);
    expect(init).toMatchObject({
      method: 'POST',
      cache: 'no-store',
      headers: {
        'Content-Type': 'application/json',
        'Idempotency-Key': '6d5c1539-8995-4a45-b71c-9c8e994dfca6',
        'X-Website-Contact-Token': 'website-technical-token',
      },
    });
    expect(JSON.parse(init.body as string)).toEqual({
      name: VALID_PAYLOAD.name,
      email: VALID_PAYLOAD.email,
      company: VALID_PAYLOAD.company,
      phone: VALID_PAYLOAD.phone,
      plan: VALID_PAYLOAD.plan,
      message: VALID_PAYLOAD.message,
    });
    expect(init.body).not.toContain('captchaToken');
    expect(telemetry).toHaveBeenCalledWith(
      'commercial_contact_captcha',
      expect.objectContaining({
        environment: 'test',
        latencyMs: expect.any(Number),
        outcome: 'valid',
      }),
    );
    expect(JSON.stringify(telemetry.mock.calls)).not.toContain(VALID_PAYLOAD.captchaToken);
    expect(JSON.stringify(telemetry.mock.calls)).not.toContain('recaptcha-secret');
  });

  it('fails closed when the technical token is not configured', async () => {
    vi.stubEnv('CONTACT_WEBHOOK_TOKEN', '');

    const response = await POST(contactRequest());

    expect(response.status).toBe(503);
    await expect(response.json()).resolves.toEqual({ code: 'NOT_CONFIGURED' });
    expect(fetchMock).not.toHaveBeenCalled();
  });

  it('rejects a missing or malformed idempotency key before calling the backend', async () => {
    const response = await POST(contactRequest({ idempotencyKey: 'short' }));

    expect(response.status).toBe(400);
    await expect(response.json()).resolves.toEqual({ code: 'VALIDATION_ERROR' });
    expect(fetchMock).not.toHaveBeenCalled();
  });

  it('preserves backend throttling without exposing its response body', async () => {
    fetchMock
      .mockResolvedValueOnce(captchaResponse())
      .mockResolvedValueOnce(backendResponse({ detail: 'internal' }, 429, { 'Retry-After': '60' }));

    const response = await POST(contactRequest());

    expect(response.status).toBe(429);
    expect(response.headers.get('retry-after')).toBe('60');
    await expect(response.json()).resolves.toEqual({ code: 'RATE_LIMITED' });
  });

  it('does not confirm registration when the backend success body violates the contract', async () => {
    fetchMock
      .mockResolvedValueOnce(captchaResponse())
      .mockResolvedValueOnce(backendResponse({ ...CREATED_CONTACT, status: 'PENDING' }));

    const response = await POST(contactRequest());

    expect(response.status).toBe(502);
    await expect(response.json()).resolves.toEqual({ code: 'DELIVERY_ERROR' });
  });

  it('requires a captcha token before any external call', async () => {
    const payload = { ...VALID_PAYLOAD } as Partial<typeof VALID_PAYLOAD>;
    delete payload.captchaToken;
    const response = await POST(contactRequest({ payload }));

    expect(response.status).toBe(400);
    await expect(response.json()).resolves.toEqual({ code: 'CAPTCHA_REQUIRED' });
    expect(fetchMock).not.toHaveBeenCalled();
  });

  it('rejects invalid, expired, or wrong-hostname proofs without calling the backend', async () => {
    fetchMock.mockResolvedValueOnce(
      captchaResponse({
        success: true,
        challenge_ts: new Date(Date.now() - 121_000).toISOString(),
        hostname: 'attacker.example',
      }),
    );

    const response = await POST(contactRequest());

    expect(response.status).toBe(422);
    await expect(response.json()).resolves.toEqual({ code: 'CAPTCHA_INVALID' });
    expect(fetchMock).toHaveBeenCalledOnce();
  });

  it('rejects a replay reported by the provider without calling the backend', async () => {
    fetchMock.mockResolvedValueOnce(
      captchaResponse({ success: false, 'error-codes': ['timeout-or-duplicate'] }),
    );

    const response = await POST(contactRequest());

    expect(response.status).toBe(422);
    await expect(response.json()).resolves.toEqual({ code: 'CAPTCHA_INVALID' });
    expect(fetchMock).toHaveBeenCalledOnce();
  });

  it('fails closed when the provider response violates its schema', async () => {
    fetchMock.mockResolvedValueOnce(captchaResponse({ unexpected: true }));

    const response = await POST(contactRequest());

    expect(response.status).toBe(503);
    await expect(response.json()).resolves.toEqual({ code: 'CAPTCHA_UNAVAILABLE' });
    expect(fetchMock).toHaveBeenCalledOnce();
  });

  it('fails closed when captcha configuration is absent', async () => {
    vi.stubEnv('RECAPTCHA_SECRET_KEY', '');

    const response = await POST(contactRequest());

    expect(response.status).toBe(503);
    await expect(response.json()).resolves.toEqual({ code: 'CAPTCHA_UNAVAILABLE' });
    expect(fetchMock).not.toHaveBeenCalled();
  });

  it('maps provider failures to a recoverable unavailable response', async () => {
    fetchMock.mockRejectedValueOnce(new Error('provider unavailable'));

    const response = await POST(contactRequest());

    expect(response.status).toBe(503);
    await expect(response.json()).resolves.toEqual({ code: 'CAPTCHA_UNAVAILABLE' });
    expect(fetchMock).toHaveBeenCalledOnce();
  });
});
