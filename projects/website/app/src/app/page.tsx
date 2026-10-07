import {
  ArrowRight,
  ArrowUpRight,
  Bot,
  Building2,
  Check,
  CircleAlert,
  FileCheck2,
  FileKey2,
  FileSearch,
  KeyRound,
  Landmark,
  LockKeyhole,
  MessageCircle,
  ScrollText,
  Sparkles,
  UserRoundCheck,
  Users,
} from 'lucide-react';
import { useTranslations } from 'next-intl';
import { BrandMark } from '@/components/BrandMark';
import { ContactForm } from '@/components/ContactForm';
import { Footer } from '@/components/Footer';
import { Header } from '@/components/Header';
import { HeroPreview } from '@/components/HeroPreview';
import { PlatformShowcase } from '@/components/PlatformShowcase';
import { SectionHeading } from '@/components/SectionHeading';
import { MARKETING_PLANS } from '@/data/plans';
import { buildLoginUrl, buildPlansUrl, getSiteBaseUrl } from '@/lib/urls';

const TRUST_ITEMS = [
  { key: 'serpro', icon: Landmark },
  { key: 'tenant', icon: Building2 },
  { key: 'certificate', icon: FileKey2 },
  { key: 'audit', icon: ScrollText },
] as const;

const ROLES = [
  { key: 'saas', icon: Sparkles },
  { key: 'office', icon: Building2 },
  { key: 'accountant', icon: UserRoundCheck },
  { key: 'client', icon: MessageCircle },
] as const;

const WORKFLOW_STEPS = [
  { key: 'register', icon: Users },
  { key: 'certificate', icon: KeyRound },
  { key: 'whatsapp', icon: MessageCircle },
  { key: 'audit', icon: FileCheck2 },
] as const;

const FLOW_STATES = [
  { key: 'regular', tone: 'success' },
  { key: 'pending', tone: 'warning' },
  { key: 'unavailable', tone: 'neutral' },
  { key: 'unauthorized', tone: 'danger' },
  { key: 'invalid', tone: 'neutral' },
] as const;

const CLIENT_PROFILES = [
  { key: 'validation', number: '01', icon: Bot },
  { key: 'productivity', number: '02', icon: FileSearch },
  { key: 'scale', number: '03', icon: Building2 },
] as const;

const SECURITY_ITEMS = [
  { key: 'tenant', icon: Building2 },
  { key: 'link', icon: UserRoundCheck },
  { key: 'certificate', icon: LockKeyhole },
  { key: 'audit', icon: ScrollText },
  { key: 'failure', icon: CircleAlert },
] as const;

const FAQ_ITEMS = [
  'product',
  'authorization',
  'isolation',
  'certificate',
  'serpro',
  'plans',
  'subscription',
] as const;

function getContactEmail(): string | undefined {
  const value = process.env.NEXT_PUBLIC_CONTACT_EMAIL?.trim();
  return value && /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(value) ? value : undefined;
}

export default function HomePage() {
  const t = useTranslations('marketing');
  const loginUrl = buildLoginUrl();
  const plansUrl = buildPlansUrl();
  const contactEmail = getContactEmail();
  const siteUrl = getSiteBaseUrl();

  const structuredData = {
    '@context': 'https://schema.org',
    '@graph': [
      {
        '@type': 'Organization',
        '@id': `${siteUrl}/#organization`,
        name: 'Contador Fiscal',
        url: siteUrl,
      },
      {
        '@type': 'SoftwareApplication',
        '@id': `${siteUrl}/#software`,
        name: 'Contador Fiscal',
        applicationCategory: 'BusinessApplication',
        operatingSystem: 'Web',
        description: t('meta.description'),
        url: siteUrl,
        provider: { '@id': `${siteUrl}/#organization` },
        audience: {
          '@type': 'BusinessAudience',
          audienceType: t('meta.audience'),
        },
      },
    ],
  };

  return (
    <>
      <script type="application/ld+json">
        {JSON.stringify(structuredData).replace(/</g, '\\u003c')}
      </script>
      <Header loginUrl={loginUrl} />

      <main id="main-content" tabIndex={-1}>
        <section id="top" className="hero-section" aria-labelledby="hero-title" tabIndex={-1}>
          <div className="hero-section__orb hero-section__orb--one" aria-hidden="true" />
          <div className="hero-section__orb hero-section__orb--two" aria-hidden="true" />
          <div className="container hero-grid">
            <div className="hero-copy">
              <p className="eyebrow">
                <span aria-hidden="true" />
                {t('hero.eyebrow')}
              </p>
              <h1 id="hero-title">
                {t('hero.titleStart')} <em>{t('hero.titleHighlight')}</em> {t('hero.titleEnd')}
              </h1>
              <p className="hero-copy__description">{t('hero.description')}</p>
              <div className="hero-copy__actions">
                <a className="button button--primary button--large" href="#planos">
                  {t('hero.primaryCta')}
                  <ArrowRight size={19} aria-hidden="true" />
                </a>
                <a className="button button--secondary button--large" href="#plataforma">
                  {t('hero.secondaryCta')}
                  <ArrowUpRight size={18} aria-hidden="true" />
                </a>
              </div>
              <p className="hero-copy__microcopy">
                <Check size={16} aria-hidden="true" />
                {t('hero.microcopy')}
              </p>
            </div>
            <HeroPreview />
          </div>
        </section>

        <section className="trust-strip" aria-label={t('trust.label')}>
          <div className="container trust-strip__grid">
            {TRUST_ITEMS.map((item) => {
              const Icon = item.icon;
              return (
                <div className="trust-item" key={item.key}>
                  <span>
                    <Icon size={20} aria-hidden="true" />
                  </span>
                  <div>
                    <strong>{t(`trust.${item.key}.title`)}</strong>
                    <small>{t(`trust.${item.key}.description`)}</small>
                  </div>
                </div>
              );
            })}
          </div>
        </section>

        <section
          id="quem-somos"
          className="section section--about"
          aria-labelledby="about-title"
          tabIndex={-1}
        >
          <div className="container about-grid">
            <div>
              <p className="eyebrow">{t('about.eyebrow')}</p>
              <h2 id="about-title">{t('about.title')}</h2>
              <p className="about-grid__description">{t('about.description')}</p>
              <div className="about-callout">
                <Sparkles size={20} aria-hidden="true" />
                <p>{t('about.callout')}</p>
              </div>
            </div>
            <div className="role-panel">
              <p className="role-panel__label">{t('about.rolesLabel')}</p>
              <div className="role-panel__grid">
                {ROLES.map((role) => {
                  const Icon = role.icon;
                  return (
                    <article className="role-card" key={role.key}>
                      <span>
                        <Icon size={19} aria-hidden="true" />
                      </span>
                      <h3>{t(`about.roles.${role.key}.title`)}</h3>
                      <p>{t(`about.roles.${role.key}.description`)}</p>
                    </article>
                  );
                })}
              </div>
            </div>
          </div>
        </section>

        <section className="section workflow-section" aria-labelledby="workflow-title">
          <div className="container">
            <SectionHeading
              eyebrow={t('workflow.eyebrow')}
              title={t('workflow.title')}
              description={t('workflow.description')}
              align="center"
            />
            <ol className="workflow-list">
              {WORKFLOW_STEPS.map((step, index) => {
                const Icon = step.icon;
                return (
                  <li key={step.key}>
                    <span className="workflow-list__number">0{index + 1}</span>
                    <span className="workflow-list__icon">
                      <Icon size={22} aria-hidden="true" />
                    </span>
                    <h3>{t(`workflow.steps.${step.key}.title`)}</h3>
                    <p>{t(`workflow.steps.${step.key}.description`)}</p>
                  </li>
                );
              })}
            </ol>

            <div className="flow-states">
              <div>
                <h3>{t('workflow.statesTitle')}</h3>
                <p>{t('workflow.statesDescription')}</p>
              </div>
              <div className="flow-states__badges">
                {FLOW_STATES.map((state) => (
                  <span className={`flow-badge flow-badge--${state.tone}`} key={state.key}>
                    {t(`workflow.states.${state.key}`)}
                  </span>
                ))}
              </div>
            </div>
          </div>
        </section>

        <section
          id="plataforma"
          className="section section--platform"
          aria-labelledby="platform-title"
          tabIndex={-1}
        >
          <div className="container">
            <SectionHeading
              id="platform-title"
              eyebrow={t('platform.eyebrow')}
              title={t('platform.title')}
              description={t('platform.description')}
              align="center"
            />
            <PlatformShowcase />
          </div>
        </section>

        <section
          id="clientes"
          className="section section--clients"
          aria-labelledby="clients-title"
          tabIndex={-1}
        >
          <div className="container">
            <SectionHeading
              id="clients-title"
              eyebrow={t('clients.eyebrow')}
              title={t('clients.title')}
              description={t('clients.description')}
            />
            <div className="client-profiles">
              {CLIENT_PROFILES.map((profile) => {
                const Icon = profile.icon;
                return (
                  <article className="client-profile" key={profile.key}>
                    <div className="client-profile__top">
                      <span>{profile.number}</span>
                      <Icon size={22} aria-hidden="true" />
                    </div>
                    <p className="client-profile__label">
                      {t(`clients.profiles.${profile.key}.label`)}
                    </p>
                    <h3>{t(`clients.profiles.${profile.key}.title`)}</h3>
                    <p>{t(`clients.profiles.${profile.key}.description`)}</p>
                  </article>
                );
              })}
            </div>
          </div>
        </section>

        <section
          id="planos"
          className="section section--plans"
          aria-labelledby="plans-title"
          tabIndex={-1}
        >
          <div className="container">
            <SectionHeading
              id="plans-title"
              eyebrow={t('plans.eyebrow')}
              title={t('plans.title')}
              description={t('plans.description')}
              align="center"
            />
            <div className="plan-grid">
              {MARKETING_PLANS.map((plan) => {
                const features = t.raw(`plans.${plan.key}.features`) as string[];
                return (
                  <article className={`plan-card plan-card--${plan.key}`} key={plan.id}>
                    <div className="plan-card__header">
                      <span>{t(`plans.${plan.key}.tag`)}</span>
                      <h3>{t(`plans.${plan.key}.name`)}</h3>
                      <p>{t(`plans.${plan.key}.audience`)}</p>
                    </div>
                    <div className="plan-card__value">
                      <strong>{t('plans.noPrice')}</strong>
                      <small>{t('plans.details')}</small>
                    </div>
                    <ul>
                      {features.map((feature) => (
                        <li key={feature}>
                          <span>
                            <Check size={14} aria-hidden="true" />
                          </span>
                          {feature}
                        </li>
                      ))}
                    </ul>
                  </article>
                );
              })}
            </div>

            <div className="comparison-table-wrap">
              <h3>{t('plans.comparisonTitle')}</h3>
              <p className="comparison-table-hint">{t('plans.scrollHint')}</p>
              <div
                className="comparison-table-scroll"
                role="region"
                aria-label={t('plans.comparisonCaption')}
                tabIndex={0}
              >
                <table className="comparison-table">
                  <caption>{t('plans.comparisonCaption')}</caption>
                  <thead>
                    <tr>
                      <th scope="col">{t('plans.rows.feature')}</th>
                      {MARKETING_PLANS.map((plan) => (
                        <th scope="col" key={plan.id}>
                          {t(`plans.${plan.key}.name`)}
                        </th>
                      ))}
                    </tr>
                  </thead>
                  <tbody>
                    {[
                      ['profile', 'profile'],
                      ['companies', 'companies'],
                      ['whatsapp', 'whatsapp'],
                      ['telegram', 'telegram'],
                      ['support', 'support'],
                      ['overage', 'overage'],
                      ['dashboard', 'dashboard'],
                      ['certificates', 'certificates'],
                    ].map(([rowKey, valueKey]) => (
                      <tr key={rowKey}>
                        <th scope="row">{t(`plans.rows.${rowKey}`)}</th>
                        {MARKETING_PLANS.map((plan) => {
                          const key = `plans.${plan.key}.${valueKey}`;
                          return (
                            <td key={plan.id}>
                              {t.has(key) ? (
                                t(key)
                              ) : (
                                <span className="not-specified">
                                  {t('plans.rows.notSpecified')}
                                </span>
                              )}
                            </td>
                          );
                        })}
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            </div>
          </div>
        </section>

        <section className="security-section" aria-labelledby="security-title">
          <div className="container security-grid">
            <div>
              <p className="eyebrow eyebrow--inverse">{t('security.eyebrow')}</p>
              <h2 id="security-title">{t('security.title')}</h2>
              <p>{t('security.description')}</p>
            </div>
            <ul>
              {SECURITY_ITEMS.map((item) => {
                const Icon = item.icon;
                return (
                  <li key={item.key}>
                    <span>
                      <Icon size={18} aria-hidden="true" />
                    </span>
                    {t(`security.items.${item.key}`)}
                  </li>
                );
              })}
            </ul>
          </div>
        </section>

        <section className="section faq-section" aria-labelledby="faq-title">
          <div className="container faq-grid">
            <SectionHeading id="faq-title" eyebrow={t('faq.eyebrow')} title={t('faq.title')} />
            <div className="faq-list">
              {FAQ_ITEMS.map((item, index) => (
                <details key={item} open={index === 0}>
                  <summary>
                    <span>{t(`faq.items.${item}.question`)}</span>
                    <i aria-hidden="true">+</i>
                  </summary>
                  <p>{t(`faq.items.${item}.answer`)}</p>
                </details>
              ))}
            </div>
          </div>
        </section>

        <section
          id="contate"
          className="section contact-section"
          aria-labelledby="contact-title"
          tabIndex={-1}
        >
          <div className="container contact-grid">
            <div className="contact-copy">
              <p className="eyebrow">{t('contact.eyebrow')}</p>
              <h2 id="contact-title">{t('contact.title')}</h2>
              <p>{t('contact.description')}</p>
              <div className="contact-copy__mark">
                <BrandMark compact />
              </div>
            </div>
            <ContactForm contactEmail={contactEmail} />
          </div>
        </section>

        <section className="final-cta" aria-labelledby="final-cta-title">
          <div className="container final-cta__inner">
            <div>
              <p className="eyebrow eyebrow--inverse">{t('finalCta.eyebrow')}</p>
              <h2 id="final-cta-title">{t('finalCta.title')}</h2>
              <p>{t('finalCta.description')}</p>
            </div>
            <div className="final-cta__actions">
              <a className="button button--light button--large" href="#planos">
                {t('finalCta.primary')}
                <ArrowRight size={18} aria-hidden="true" />
              </a>
            </div>
          </div>
        </section>
      </main>

      <Footer plansUrl={plansUrl} />
    </>
  );
}
