import type { Metadata } from 'next';
import { useTranslations } from 'next-intl';
import { ContactForm } from '@/components/ContactForm';

export const metadata: Metadata = {
  title: 'Contate o time comercial | Contador Fiscal',
  description:
    'Fale com o time comercial do Contador Fiscal e encontre a estrutura adequada para o seu escritório contábil.',
  alternates: { canonical: '/contate' },
  openGraph: {
    type: 'website',
    locale: 'pt_BR',
    url: '/contate',
    title: 'Contate o time comercial | Contador Fiscal',
    description:
      'Converse com o time comercial do Contador Fiscal sobre a rotina do seu escritório.',
  },
};

function getContactEmail(): string | undefined {
  const value = process.env.NEXT_PUBLIC_CONTACT_EMAIL?.trim();
  return value && /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(value) ? value : undefined;
}

export default function ContactPage() {
  const t = useTranslations('marketing');
  const contactEmail = getContactEmail();

  return (
    <main id="main-content" className="contact-page" tabIndex={-1}>
      <section
        id="contate"
        className="section contact-section contact-page__section"
        aria-labelledby="contact-title"
      >
        <div className="container contact-grid">
          <div className="hero-copy contact-page__copy">
            <p className="eyebrow">
              <span aria-hidden="true" />
              {t('hero.eyebrow')}
            </p>
            <h1 id="contact-title">
              {t('hero.titleStart')} <em>{t('hero.titleHighlight')}</em> {t('hero.titleEnd')}
            </h1>
            <p className="hero-copy__description">{t('hero.description')}</p>
          </div>
          <ContactForm contactEmail={contactEmail} headingLevel={2} />
        </div>
      </section>
    </main>
  );
}
