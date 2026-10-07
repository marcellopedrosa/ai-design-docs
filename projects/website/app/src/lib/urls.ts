export const PLAN_TYPES = ['START', 'BUSINESS', 'PREMIUM'] as const;

export type PlanType = (typeof PLAN_TYPES)[number];

const LOCAL_APP_URL = 'http://localhost:3000';
const LOCAL_SITE_URL = 'http://localhost:3002';

function normalizeHttpUrl(value: string | undefined, fallback: string): string {
  if (!value) return fallback;

  try {
    const url = new URL(value);
    if (url.protocol !== 'http:' && url.protocol !== 'https:') return fallback;
    return url.origin;
  } catch {
    return fallback;
  }
}

export function getAppBaseUrl(): string {
  return normalizeHttpUrl(process.env.NEXT_PUBLIC_APP_URL, LOCAL_APP_URL);
}

export function getSiteBaseUrl(): string {
  return normalizeHttpUrl(process.env.NEXT_PUBLIC_SITE_URL, LOCAL_SITE_URL);
}

export function isPlanType(value: unknown): value is PlanType {
  return typeof value === 'string' && PLAN_TYPES.includes(value as PlanType);
}

export function buildLoginUrl(plan?: PlanType): string {
  const url = new URL('/login', getAppBaseUrl());

  if (plan) {
    url.searchParams.set('plan', plan);
    url.searchParams.set('returnTo', `/billing/plans?plan=${plan}`);
  }

  return url.toString();
}

export function buildDashboardUrl(): string {
  return new URL('/dashboard', getAppBaseUrl()).toString();
}

export function buildPlansUrl(plan?: PlanType): string {
  const url = new URL('/billing/plans', getAppBaseUrl());
  if (plan) url.searchParams.set('plan', plan);
  return url.toString();
}
