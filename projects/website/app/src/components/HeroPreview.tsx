import {
  BarChart3,
  Check,
  FileSearch,
  LayoutDashboard,
  MessageCircle,
  ShieldCheck,
  Users,
} from 'lucide-react';
import { useTranslations } from 'next-intl';

export function HeroPreview() {
  const t = useTranslations('marketing.hero');

  return (
    <figure className="hero-preview">
      <div className="hero-preview__glow" aria-hidden="true" />
      <div className="hero-preview__notice" aria-hidden="true">
        <span aria-hidden="true" />
        {t('dashboard.demoNotice')}
      </div>
      <div className="app-window" aria-hidden="true">
        <div className="app-window__chrome" aria-hidden="true">
          <span />
          <span />
          <span />
          <div className="app-window__address">{t('dashboard.appAddress')}</div>
        </div>

        <div className="app-window__body">
          <aside className="demo-sidebar" aria-label={t('dashboard.navigationLabel')}>
            <div className="demo-sidebar__brand">HC</div>
            <div className="demo-sidebar__item demo-sidebar__item--active">
              <LayoutDashboard size={15} aria-hidden="true" />
              <span>{t('dashboard.navigation.panel')}</span>
            </div>
            <div className="demo-sidebar__item">
              <Users size={15} aria-hidden="true" />
              <span>{t('dashboard.navigation.clients')}</span>
            </div>
            <div className="demo-sidebar__item">
              <FileSearch size={15} aria-hidden="true" />
              <span>{t('dashboard.navigation.fiscal')}</span>
            </div>
            <div className="demo-sidebar__item">
              <ShieldCheck size={15} aria-hidden="true" />
              <span>{t('dashboard.navigation.certificates')}</span>
            </div>
          </aside>

          <div className="demo-dashboard">
            <div className="demo-dashboard__topbar">
              <div>
                <strong>{t('dashboard.office')}</strong>
                <span>{t('dashboard.period')}</span>
              </div>
              <div className="demo-avatar">{t('dashboard.avatar')}</div>
            </div>

            <div className="demo-kpis">
              <div className="demo-kpi">
                <span className="demo-kpi__icon demo-kpi__icon--blue">
                  <Users size={14} />
                </span>
                <span>{t('dashboard.clients')}</span>
                <strong>{t('dashboard.clientsValue')}</strong>
              </div>
              <div className="demo-kpi">
                <span className="demo-kpi__icon demo-kpi__icon--amber">
                  <ShieldCheck size={14} />
                </span>
                <span>{t('dashboard.certificate')}</span>
                <strong>{t('dashboard.certificateValue')}</strong>
              </div>
              <div className="demo-kpi">
                <span className="demo-kpi__icon demo-kpi__icon--green">
                  <FileSearch size={14} />
                </span>
                <span>{t('dashboard.queries')}</span>
                <strong>{t('dashboard.queriesValue')}</strong>
              </div>
            </div>

            <div className="demo-dashboard__grid">
              <div className="demo-chart-card">
                <div className="demo-chart-card__header">
                  <div>
                    <strong>{t('dashboard.chartTitle')}</strong>
                    <span>{t('dashboard.chartLegend')}</span>
                  </div>
                  <BarChart3 size={18} aria-hidden="true" />
                </div>
                <svg
                  className="demo-chart"
                  viewBox="0 0 390 130"
                  role="img"
                  aria-label={t('dashboard.chartAriaLabel')}
                >
                  <defs>
                    <linearGradient id="heroChartFill" x1="0" x2="0" y1="0" y2="1">
                      <stop offset="0%" stopColor="#3B82F6" stopOpacity="0.3" />
                      <stop offset="100%" stopColor="#3B82F6" stopOpacity="0" />
                    </linearGradient>
                  </defs>
                  <g className="demo-chart__grid">
                    <line x1="0" y1="25" x2="390" y2="25" />
                    <line x1="0" y1="65" x2="390" y2="65" />
                    <line x1="0" y1="105" x2="390" y2="105" />
                  </g>
                  <path
                    d="M0 106 C38 98 52 79 85 86 C121 94 140 49 175 64 C211 79 225 38 260 46 C295 55 310 22 345 31 C365 36 377 24 390 18 L390 130 L0 130 Z"
                    fill="url(#heroChartFill)"
                  />
                  <path
                    d="M0 106 C38 98 52 79 85 86 C121 94 140 49 175 64 C211 79 225 38 260 46 C295 55 310 22 345 31 C365 36 377 24 390 18"
                    fill="none"
                    stroke="#2563EB"
                    strokeLinecap="round"
                    strokeWidth="3"
                  />
                </svg>
              </div>

              <div className="demo-activity">
                <strong>{t('dashboard.recent')}</strong>
                <div className="demo-activity__item">
                  <span>
                    <Check size={12} />
                  </span>
                  <div>
                    <b>{t('dashboard.recentItem')}</b>
                    <small>{t('dashboard.recentTime')}</small>
                  </div>
                </div>
                <div className="demo-activity__skeleton" />
                <div className="demo-activity__skeleton demo-activity__skeleton--short" />
              </div>
            </div>
          </div>
        </div>
      </div>

      <div className="phone-frame" aria-hidden="true">
        <div className="phone-frame__notch" aria-hidden="true" />
        <div className="phone-frame__header">
          <span className="phone-frame__avatar">
            <MessageCircle size={15} />
          </span>
          <div>
            <strong>{t('phone.name')}</strong>
            <span>{t('phone.status')}</span>
          </div>
        </div>
        <div className="phone-frame__chat">
          <div className="chat-bubble chat-bubble--outgoing">{t('phone.clientMessage')}</div>
          <div className="chat-bubble chat-bubble--incoming">
            <small>{t('phone.auth')}</small>
            <strong>{t('phone.result')}</strong>
            <span>{t('phone.detail')}</span>
          </div>
        </div>
        <div className="phone-frame__composer">
          <span>{t('phone.placeholder')}</span>
          <i aria-hidden="true">➤</i>
        </div>
      </div>

      <figcaption className="sr-only">{t('visualLabel')}</figcaption>
    </figure>
  );
}
