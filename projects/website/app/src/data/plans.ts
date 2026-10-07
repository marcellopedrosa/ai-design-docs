import type { PlanType } from '@/lib/urls';

export interface MarketingPlan {
  id: PlanType;
  key: 'start' | 'business' | 'premium';
  featureCount: number;
}

export const MARKETING_PLANS: MarketingPlan[] = [
  { id: 'START', key: 'start', featureCount: 4 },
  { id: 'BUSINESS', key: 'business', featureCount: 4 },
  { id: 'PREMIUM', key: 'premium', featureCount: 6 },
];
