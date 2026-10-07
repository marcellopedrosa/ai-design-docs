import { afterEach, describe, expect, it } from 'vitest';
import { buildLoginUrl, buildPlansUrl, isPlanType } from './urls';

const originalAppUrl = process.env.NEXT_PUBLIC_APP_URL;

afterEach(() => {
  process.env.NEXT_PUBLIC_APP_URL = originalAppUrl;
});

describe('plan URL handoff', () => {
  it('accepts only the documented plan identifiers', () => {
    expect(isPlanType('START')).toBe(true);
    expect(isPlanType('BUSINESS')).toBe(true);
    expect(isPlanType('PREMIUM')).toBe(true);
    expect(isPlanType('enterprise')).toBe(false);
    expect(isPlanType('/dashboard')).toBe(false);
  });

  it('builds a fixed login return path without accepting an arbitrary redirect', () => {
    process.env.NEXT_PUBLIC_APP_URL = 'https://app.hub.example';
    const url = new URL(buildLoginUrl('BUSINESS'));

    expect(url.origin).toBe('https://app.hub.example');
    expect(url.pathname).toBe('/login');
    expect(url.searchParams.get('plan')).toBe('BUSINESS');
    expect(url.searchParams.get('returnTo')).toBe('/billing/plans?plan=BUSINESS');
  });

  it('falls back to a safe local origin when the configured URL is invalid', () => {
    process.env.NEXT_PUBLIC_APP_URL = 'javascript:alert(1)';
    expect(buildPlansUrl('START')).toBe('http://localhost:3000/billing/plans?plan=START');
  });
});
