import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { verifyRecaptcha } from './recaptcha';

describe('verifyRecaptcha', () => {
  beforeEach(() => {
    vi.stubEnv('RECAPTCHA_SECRET_KEY', 'synthetic-secret');
    vi.stubEnv('RECAPTCHA_ALLOWED_HOSTNAMES', 'www.example.com');
    vi.stubEnv('RECAPTCHA_VERIFY_TIMEOUT_MS', '500');
  });

  afterEach(() => {
    vi.useRealTimers();
    vi.unstubAllEnvs();
    vi.unstubAllGlobals();
  });

  it('aborts a provider call at the configured deadline and fails closed', async () => {
    vi.useFakeTimers();
    vi.stubGlobal(
      'fetch',
      vi.fn(
        (_url: string, init?: RequestInit) =>
          new Promise<Response>((_resolve, reject) => {
            init?.signal?.addEventListener('abort', () =>
              reject(new DOMException('Timed out', 'AbortError')),
            );
          }),
      ),
    );

    const result = verifyRecaptcha('ephemeral-token');
    await vi.advanceTimersByTimeAsync(500);

    await expect(result).resolves.toBe('unavailable');
  });

  it('rejects a valid provider response when the challenge timestamp is in the future', async () => {
    vi.stubGlobal(
      'fetch',
      vi.fn().mockResolvedValue(
        new Response(
          JSON.stringify({
            success: true,
            hostname: 'www.example.com',
            challenge_ts: '2026-10-02T12:02:00.000Z',
          }),
          { status: 200 },
        ),
      ),
    );

    await expect(
      verifyRecaptcha('ephemeral-token', Date.parse('2026-10-02T12:00:00.000Z')),
    ).resolves.toBe('invalid');
  });
});
