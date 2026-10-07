import { ArrowUpRight } from 'lucide-react';
import { useTranslations } from 'next-intl';
import { BrandMark } from './BrandMark';

interface FooterProps {
  plansUrl: string;
}

export function Footer({ plansUrl }: FooterProps) {
  const t = useTranslations('marketing');
  const year = new Date().getFullYear();

  return (
    <footer className="site-footer">
      <div className="container site-footer__grid">
        <div className="site-footer__brand">
          <a href="#top" aria-label={t('nav.home')}>
            <BrandMark inverse />
          </a>
          <p>{t('footer.description')}</p>
        </div>

        <div className="site-footer__column">
          <strong>{t('footer.navigation')}</strong>
          <a href="#quem-somos">{t('nav.who')}</a>
          <a href="#clientes">{t('nav.clients')}</a>
          <a href="#planos">{t('nav.plans')}</a>
          <a href="#contate">{t('nav.contact')}</a>
        </div>

        <div className="site-footer__column">
          <strong>{t('footer.access')}</strong>
          <a href={plansUrl}>
            {t('footer.plans')}
            <ArrowUpRight size={14} aria-hidden="true" />
          </a>
        </div>
      </div>

      <div className="container site-footer__bottom">
        <p>
          © {year} {t('footer.copyright')}
        </p>
        <a href="#top">{t('footer.backToTop')} ↑</a>
      </div>
    </footer>
  );
}
