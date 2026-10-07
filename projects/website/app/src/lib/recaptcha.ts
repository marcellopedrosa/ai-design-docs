import { z } from 'zod';

const VERIFY_URL = 'https://www.google.com/recaptcha/api/siteverify';
const MAX_CHALLENGE_AGE_MS = 120_000;
const MAX_FUTURE_CLOCK_SKEW_MS = 30_000;
const DEFAULT_TIMEOUT_MS = 3_000;

const providerResponseSchema = z
  .object({
    success: z.boolean(),
    challenge_ts: z.string().datetime({ offset: true }).optional(),
    hostname: z.string().trim().min(1).optional(),
    'error-codes': z.array(z.string()).optional(),
  })
  .passthrough();

export type RecaptchaVerificationResult = 'valid' | 'invalid' | 'unavailable';

interface RecaptchaConfig {
  allowedHostnames: Set<string>;
  secret: string;
  timeoutMs: number;
}

function readConfig(): RecaptchaConfig | null {
  const secret = process.env.RECAPTCHA_SECRET_KEY?.trim();
  const allowedHostnames = (process.env.RECAPTCHA_ALLOWED_HOSTNAMES ?? '')
    .split(',')
    .map((hostname) => hostname.trim().toLowerCase())
    .filter(Boolean);
  const configuredTimeout = Number(process.env.RECAPTCHA_VERIFY_TIMEOUT_MS ?? DEFAULT_TIMEOUT_MS);

  if (
    !secret ||
    secret.length > 1_024 ||
    /[\u0000-\u001f\u007f]/.test(secret) ||
    allowedHostnames.length === 0 ||
    allowedHostnames.some((hostname) => hostname === '*' || hostname.includes('/')) ||
    !Number.isInteger(configuredTimeout) ||
    configuredTimeout < 500 ||
    configuredTimeout > 5_000
  ) {
    return null;
  }

  return { secret, allowedHostnames: new Set(allowedHostnames), timeoutMs: configuredTimeout };
}

export async function verifyRecaptcha(
  token: string,
  now = Date.now(),
): Promise<RecaptchaVerificationResult> {
  const config = readConfig();
  if (!config) return 'unavailable';

  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), config.timeoutMs);

  try {
    const body = new URLSearchParams({ secret: config.secret, response: token });
    const response = await fetch(VERIFY_URL, {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body,
      signal: controller.signal,
      cache: 'no-store',
      redirect: 'error',
    });
    if (!response.ok) return 'unavailable';

    const parsed = providerResponseSchema.safeParse(await response.json());
    if (!parsed.success) return 'unavailable';
    if (!parsed.data.success || !parsed.data.challenge_ts || !parsed.data.hostname)
      return 'invalid';

    const hostname = parsed.data.hostname.toLowerCase();
    const challengeTime = Date.parse(parsed.data.challenge_ts);
    if (!config.allowedHostnames.has(hostname) || !Number.isFinite(challengeTime)) return 'invalid';

    const age = now - challengeTime;
    return age >= -MAX_FUTURE_CLOCK_SKEW_MS && age <= MAX_CHALLENGE_AGE_MS ? 'valid' : 'invalid';
  } catch {
    return 'unavailable';
  } finally {
    clearTimeout(timeout);
  }
}
