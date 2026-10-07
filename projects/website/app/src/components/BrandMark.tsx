import { Landmark } from 'lucide-react';
import { useTranslations } from 'next-intl';

interface BrandMarkProps {
  compact?: boolean;
  inverse?: boolean;
}

export function BrandMark({ compact = false, inverse = false }: BrandMarkProps) {
  const t = useTranslations('marketing.brand');

  return (
    <span className={`brand-mark${inverse ? ' brand-mark--inverse' : ''}`}>
      <span className="brand-mark__symbol" aria-hidden="true">
        <Landmark size={compact ? 18 : 20} strokeWidth={2.1} />
      </span>
      <span className="brand-mark__copy">
        <span className="brand-mark__name">{t('name')}</span>
        {!compact && <span className="brand-mark__tagline">{t('tagline')}</span>}
      </span>
    </span>
  );
}
