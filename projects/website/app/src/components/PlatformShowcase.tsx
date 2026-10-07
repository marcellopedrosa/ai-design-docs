'use client';

import { useRef, useState } from 'react';
import {
  Activity,
  BarChart3,
  BellRing,
  Building2,
  Check,
  CircleCheck,
  CircleAlert,
  Clock3,
  CreditCard,
  FileArchive,
  FileJson,
  FileSearch,
  FileText,
  FolderArchive,
  LayoutDashboard,
  MessageCircle,
  MessagesSquare,
  ReceiptText,
  Search,
  ShieldCheck,
  Smartphone,
  Users,
} from 'lucide-react';
import { useTranslations } from 'next-intl';

const TABS = [
  { id: 'dashboard', icon: LayoutDashboard },
  { id: 'clients', icon: Users },
  { id: 'fiscal', icon: FileSearch },
  { id: 'certificates', icon: ShieldCheck },
  { id: 'service', icon: MessageCircle },
  { id: 'billing', icon: CreditCard },
  { id: 'admin', icon: Building2 },
] as const;

type TabId = (typeof TABS)[number]['id'];

function PreviewHeader({ title, description }: { title: string; description: string }) {
  const t = useTranslations('marketing.platform');

  return (
    <div className="product-screen__heading">
      <div>
        <h3>{title}</h3>
        <p>{description}</p>
      </div>
      <div className="product-screen__heading-actions" aria-hidden="true">
        <span>
          <Search size={15} />
        </span>
        <span>
          <BellRing size={15} />
        </span>
        <span>{t('avatar')}</span>
      </div>
    </div>
  );
}

function StatusBadge({ children, tone = 'success' }: { children: React.ReactNode; tone?: string }) {
  return <span className={`status-badge status-badge--${tone}`}>{children}</span>;
}

function PreviewModuleLinks({ items }: { items: string[] }) {
  return (
    <div className="preview-module-links">
      {items.map((item) => (
        <span key={item}>{item}</span>
      ))}
    </div>
  );
}

function DashboardPreview() {
  const t = useTranslations('marketing.platform.dashboard');
  const metrics = [
    {
      id: 'clients',
      icon: Users,
      value: t('metrics.clients.value'),
      label: t('metrics.clients.label'),
      subtitle: t('metrics.clients.subtitle'),
      trend: t('metrics.clients.trend'),
    },
    {
      id: 'certificate',
      icon: ShieldCheck,
      value: t('metrics.certificate.value'),
      label: t('metrics.certificate.label'),
      subtitle: t('metrics.certificate.subtitle'),
      tone: 'warning',
    },
    {
      id: 'queries',
      icon: FileSearch,
      value: t('metrics.queries.value'),
      label: t('metrics.queries.label'),
      subtitle: t('metrics.queries.subtitle'),
      trend: t('metrics.queries.trend'),
    },
    {
      id: 'whatsapp',
      icon: Smartphone,
      value: t('metrics.whatsapp.value'),
      label: t('metrics.whatsapp.label'),
      subtitle: t('metrics.whatsapp.subtitle'),
    },
    {
      id: 'chatbot',
      icon: MessageCircle,
      value: t('metrics.chatbot.value'),
      label: t('metrics.chatbot.label'),
      subtitle: t('metrics.chatbot.subtitle'),
    },
    {
      id: 'messages',
      icon: MessagesSquare,
      value: t('metrics.messages.value'),
      label: t('metrics.messages.label'),
      subtitle: t('metrics.messages.subtitle'),
    },
  ];

  const recentQueries = [
    { key: 'queryOne', tone: 'success' },
    { key: 'queryTwo', tone: 'success' },
    { key: 'queryThree', tone: 'danger' },
    { key: 'queryFour', tone: 'warning' },
  ] as const;

  return (
    <>
      <PreviewHeader title={t('title')} description={t('description')} />
      <div className="preview-kpi-grid">
        {metrics.map((metric) => {
          const Icon = metric.icon;
          return (
            <article
              className={`preview-kpi-card${metric.tone ? ` preview-kpi-card--${metric.tone}` : ''}`}
              key={metric.id}
            >
              <div className="preview-kpi-card__copy">
                <small>{metric.label}</small>
                <div className="preview-kpi-card__value">
                  <strong>{metric.value}</strong>
                  {metric.trend ? <span>{metric.trend}</span> : null}
                </div>
                <p>{metric.subtitle}</p>
              </div>
              <span className="preview-kpi-card__icon" aria-hidden="true">
                <Icon size={18} />
              </span>
            </article>
          );
        })}
      </div>

      <div className="preview-activity-card">
        <div className="preview-card-title">
          <span>{t('activity.title')}</span>
          <small>{t('activity.viewAll')}</small>
        </div>
        <div className="preview-activity-card__items">
          <div>
            <span className="preview-activity-card__icon">
              <FileSearch size={14} />
            </span>
            <p>
              <strong>{t('activity.queryTitle')}</strong>
              <small>{t('activity.queryDescription')}</small>
            </p>
            <time>{t('activity.queryTime')}</time>
          </div>
          <div>
            <span className="preview-activity-card__icon preview-activity-card__icon--warning">
              <Clock3 size={14} />
            </span>
            <p>
              <strong>{t('activity.certificateTitle')}</strong>
              <small>{t('activity.certificateDescription')}</small>
            </p>
            <time>{t('activity.certificateTime')}</time>
          </div>
          <div>
            <span className="preview-activity-card__icon preview-activity-card__icon--success">
              <ReceiptText size={14} />
            </span>
            <p>
              <strong>{t('activity.darfTitle')}</strong>
              <small>{t('activity.darfDescription')}</small>
            </p>
            <time>{t('activity.darfTime')}</time>
          </div>
        </div>
      </div>

      <div className="preview-dashboard-grid">
        <div className="preview-chart">
          <div className="preview-card-title">
            <div>
              <span>{t('chartTitle')}</span>
              <small>{t('chartDescription')}</small>
            </div>
            <BarChart3 size={17} />
          </div>
          <svg viewBox="0 0 560 190" role="img" aria-label={t('chartAriaLabel')}>
            <defs>
              <linearGradient id="platformChartFill" x1="0" x2="0" y1="0" y2="1">
                <stop offset="0%" stopColor="#3B82F6" stopOpacity="0.32" />
                <stop offset="100%" stopColor="#3B82F6" stopOpacity="0" />
              </linearGradient>
            </defs>
            <g className="preview-chart__grid">
              <line x1="0" y1="30" x2="560" y2="30" />
              <line x1="0" y1="90" x2="560" y2="90" />
              <line x1="0" y1="150" x2="560" y2="150" />
            </g>
            <path
              d="M0 151 C45 143 55 108 100 116 C145 124 158 76 210 90 C256 103 273 51 325 68 C370 82 391 31 440 48 C486 62 511 24 560 30 L560 190 L0 190 Z"
              fill="url(#platformChartFill)"
            />
            <path
              d="M0 151 C45 143 55 108 100 116 C145 124 158 76 210 90 C256 103 273 51 325 68 C370 82 391 31 440 48 C486 62 511 24 560 30"
              fill="none"
              stroke="#2563EB"
              strokeLinecap="round"
              strokeWidth="3"
            />
            <path
              d="M0 172 C52 168 77 151 125 158 C177 165 203 134 252 145 C310 157 329 118 378 132 C424 145 472 108 560 119"
              fill="none"
              stroke="#F59E0B"
              strokeLinecap="round"
              strokeWidth="2"
            />
          </svg>
          <div className="preview-chart__legend" aria-hidden="true">
            <span>{t('chartQueries')}</span>
            <span>{t('chartDarfs')}</span>
          </div>
        </div>
        <div className="preview-list-card">
          <div className="preview-card-title">{t('listTitle')}</div>
          {recentQueries.map(({ key, tone }) => (
            <div className="preview-list-row" key={key}>
              <span className={`preview-list-dot preview-list-dot--${tone}`} />
              <span>
                <strong>{t(`${key}.title`)}</strong>
                <small>{t(`${key}.company`)}</small>
              </span>
              <StatusBadge tone={tone}>{t(`${key}.status`)}</StatusBadge>
            </div>
          ))}
        </div>
      </div>
    </>
  );
}

function ClientsPreview() {
  const t = useTranslations('marketing.platform.clients');
  return (
    <>
      <PreviewHeader title={t('title')} description={t('description')} />
      <div className="usage-banner">
        <span>
          <Users size={18} />
        </span>
        <div>
          <strong>{t('usage')}</strong>
          <div className="progress-track">
            <i style={{ width: '84%' }} />
          </div>
        </div>
        <b>84%</b>
      </div>
      <div className="preview-table" role="table" aria-label={t('title')}>
        <div className="preview-table__row preview-table__row--header" role="row">
          <span role="columnheader">{t('name')}</span>
          <span role="columnheader">{t('document')}</span>
          <span role="columnheader">{t('contact')}</span>
          <span role="columnheader">{t('status')}</span>
        </div>
        {[t('rowOne'), t('rowTwo')].map((name) => (
          <div className="preview-table__row" role="row" key={name}>
            <span role="cell">
              <i className="company-avatar">{name.slice(0, 2)}</i>
              {name}
            </span>
            <span role="cell">{t('maskedDocument')}</span>
            <span role="cell">
              <StatusBadge>{t('authorized')}</StatusBadge>
            </span>
            <span role="cell">
              <StatusBadge tone="info">{t('active')}</StatusBadge>
            </span>
          </div>
        ))}
      </div>
    </>
  );
}

const FISCAL_FUNCTIONS = [
  { id: 'query', icon: FileSearch },
  { id: 'das', icon: ReceiptText },
  { id: 'darf', icon: FileText },
  { id: 'batch', icon: Activity },
  { id: 'documents', icon: FolderArchive },
] as const;

type FiscalFunctionId = (typeof FISCAL_FUNCTIONS)[number]['id'];

function DemoField({ label, value }: { label: string; value: string }) {
  return (
    <div className="fiscal-demo-field">
      <small>{label}</small>
      <span>{value}</span>
    </div>
  );
}

function FiscalQueryScreen() {
  const t = useTranslations('marketing.platform.fiscal.queryScreen');

  return (
    <div className="fiscal-page-view">
      <div className="fiscal-page-tabs" aria-hidden="true">
        <span className="is-active">
          <Search size={13} />
          {t('newTab')}
        </span>
        <span>
          <Clock3 size={13} />
          {t('historyTab')}
        </span>
      </div>
      <div className="fiscal-screen-grid fiscal-screen-grid--query">
        <section className="fiscal-form-card">
          <div className="preview-card-title">{t('formTitle')}</div>
          <DemoField label={t('companyLabel')} value={t('companyValue')} />
          <span className="preview-static-action">
            <Search size={14} />
            {t('action')}
          </span>
          <div className="fiscal-history-note">
            <Clock3 size={14} />
            <span>
              <strong>{t('history')}</strong>
              <small>{t('historyDescription')}</small>
            </span>
          </div>
        </section>

        <section className="fiscal-query-result">
          <div className="fiscal-result__status">
            <span>
              <CircleAlert size={21} />
            </span>
            <div>
              <small>{t('resultLabel')}</small>
              <strong>{t('status')}</strong>
            </div>
            <StatusBadge tone="warning">{t('statusBadge')}</StatusBadge>
          </div>
          <dl className="fiscal-result__summary">
            <div>
              <dt>{t('document')}</dt>
              <dd>{t('maskedDocument')}</dd>
            </div>
            <div>
              <dt>{t('date')}</dt>
              <dd>{t('dateValue')}</dd>
            </div>
            <div>
              <dt>{t('totalDebts')}</dt>
              <dd>{t('totalDebtsValue')}</dd>
            </div>
            <div>
              <dt>{t('correlationId')}</dt>
              <dd>{t('correlationValue')}</dd>
            </div>
          </dl>
          <div className="fiscal-debts">
            <div className="preview-card-title">{t('debtsTitle')}</div>
            {[t('debtOne'), t('debtTwo')].map((debt, index) => (
              <div className="fiscal-debt-row" key={debt}>
                <span>
                  <strong>{debt}</strong>
                  <small>{index === 0 ? t('debtOneMeta') : t('debtTwoMeta')}</small>
                </span>
                <b>{index === 0 ? t('debtOneValue') : t('debtTwoValue')}</b>
                <StatusBadge tone={index === 0 ? 'danger' : 'warning'}>
                  {index === 0 ? t('open') : t('installment')}
                </StatusBadge>
                <span className="fiscal-debt-row__action">{t('generateDarf')}</span>
              </div>
            ))}
          </div>
        </section>
      </div>
    </div>
  );
}

function DasScreen() {
  const t = useTranslations('marketing.platform.fiscal.dasScreen');

  return (
    <div className="fiscal-page-view">
      <div className="fiscal-page-tabs" aria-hidden="true">
        <span className="is-active">
          <ReceiptText size={13} />
          {t('newTab')}
        </span>
        <span>
          <Clock3 size={13} />
          {t('historyTab')}
        </span>
      </div>
      <div className="fiscal-screen-grid">
        <section className="fiscal-form-card">
          <div className="preview-card-title">{t('title')}</div>
          <DemoField label={t('companyLabel')} value={t('companyValue')} />
          <div className="fiscal-form-card__fields">
            <DemoField label={t('periodLabel')} value={t('periodValue')} />
            <DemoField label={t('dateLabel')} value={t('dateValue')} />
          </div>
          <span className="preview-static-action">
            <Search size={14} />
            {t('action')}
          </span>
        </section>
        <section className="fiscal-success-card">
          <div>
            <span className="fiscal-success-card__icon">
              <CircleCheck size={20} />
            </span>
            <div>
              <small>{t('resultLabel')}</small>
              <strong>{t('success')}</strong>
            </div>
            <StatusBadge>{t('status')}</StatusBadge>
          </div>
          <dl>
            <div>
              <dt>{t('periodLabel')}</dt>
              <dd>{t('periodValue')}</dd>
            </div>
            <div>
              <dt>{t('dueDate')}</dt>
              <dd>{t('dueDateValue')}</dd>
            </div>
            <div>
              <dt>{t('total')}</dt>
              <dd>{t('totalValue')}</dd>
            </div>
          </dl>
          <span className="fiscal-file-ready">
            <FileText size={15} />
            {t('pdf')}
          </span>
        </section>
      </div>
    </div>
  );
}

function DarfScreen() {
  const t = useTranslations('marketing.platform.fiscal.darfScreen');

  return (
    <div className="darf-preview">
      <section className="darf-document-card">
        <div className="darf-document-card__header">
          <span>
            <ReceiptText size={20} />
          </span>
          <div>
            <small>{t('resultLabel')}</small>
            <strong>{t('title')}</strong>
          </div>
          <StatusBadge tone="info">{t('status')}</StatusBadge>
        </div>
        <dl>
          <div>
            <dt>{t('revenueCode')}</dt>
            <dd>{t('revenueValue')}</dd>
          </div>
          <div>
            <dt>{t('dueDate')}</dt>
            <dd>{t('dueDateValue')}</dd>
          </div>
          <div>
            <dt>{t('total')}</dt>
            <dd>{t('totalValue')}</dd>
          </div>
        </dl>
        <div className="darf-document-card__line">
          <small>{t('digitLine')}</small>
          <code>{t('digitLineValue')}</code>
        </div>
        <span className="fiscal-file-ready">
          <FileText size={15} />
          {t('pdf')}
        </span>
      </section>
      <section className="darf-history-card">
        <div className="preview-card-title">{t('history')}</div>
        {[t('historyOne'), t('historyTwo')].map((item, index) => (
          <div key={item}>
            <span>
              <strong>{item}</strong>
              <small>{index === 0 ? t('historyOneMeta') : t('historyTwoMeta')}</small>
            </span>
            <StatusBadge tone={index === 0 ? 'info' : 'success'}>
              {index === 0 ? t('generated') : t('paid')}
            </StatusBadge>
          </div>
        ))}
      </section>
    </div>
  );
}

function BatchScreen() {
  const t = useTranslations('marketing.platform.fiscal.batchScreen');
  const jobs = [
    { key: 'jobOne', width: '72%', tone: 'info' },
    { key: 'jobTwo', width: '100%', tone: 'success' },
    { key: 'jobThree', width: '38%', tone: 'warning' },
  ] as const;

  return (
    <section className="batch-preview">
      <div className="batch-preview__heading">
        <span>
          <Activity size={20} />
        </span>
        <div>
          <strong>{t('title')}</strong>
          <small>{t('description')}</small>
        </div>
      </div>
      <div className="batch-preview__jobs">
        {jobs.map(({ key, width, tone }) => (
          <article key={key}>
            <div>
              <span className="batch-preview__id">{t(`${key}.id`)}</span>
              <StatusBadge tone={tone}>{t(`${key}.status`)}</StatusBadge>
              <small>{t(`${key}.type`)}</small>
            </div>
            <strong>{t(`${key}.description`)}</strong>
            <div className="batch-preview__progress-copy">
              <span>{t('progress')}</span>
              <b>{t(`${key}.progress`)}</b>
            </div>
            <div className="progress-track">
              <i style={{ width }} />
            </div>
          </article>
        ))}
      </div>
    </section>
  );
}

function DocumentsScreen() {
  const t = useTranslations('marketing.platform.fiscal.documentsScreen');
  const documents = [
    { key: 'documentOne', icon: FileText, tone: 'blue' },
    { key: 'documentTwo', icon: FileJson, tone: 'orange' },
    { key: 'documentThree', icon: ReceiptText, tone: 'green' },
    { key: 'documentFour', icon: FileArchive, tone: 'purple' },
  ] as const;

  return (
    <section className="documents-preview">
      <div className="documents-preview__heading">
        <span>
          <FolderArchive size={20} />
        </span>
        <div>
          <strong>{t('title')}</strong>
          <small>{t('description')}</small>
        </div>
      </div>
      <div className="documents-preview__filters">
        <span>
          <Search size={14} />
          {t('search')}
        </span>
        <span>{t('filter')}</span>
      </div>
      <div className="documents-preview__grid">
        {documents.map(({ key, icon: Icon, tone }) => (
          <article key={key}>
            <div>
              <span className={`documents-preview__icon documents-preview__icon--${tone}`}>
                <Icon size={17} />
              </span>
              <small>{t(`${key}.period`)}</small>
            </div>
            <strong>{t(`${key}.name`)}</strong>
            <span>{t(`${key}.company`)}</span>
            <footer>
              <small>{t(`${key}.size`)}</small>
              <StatusBadge tone="info">{t(`${key}.type`)}</StatusBadge>
            </footer>
          </article>
        ))}
      </div>
    </section>
  );
}

function FiscalFunctionScreen({ active }: { active: FiscalFunctionId }) {
  const screens: Record<FiscalFunctionId, React.ReactNode> = {
    query: <FiscalQueryScreen />,
    das: <DasScreen />,
    darf: <DarfScreen />,
    batch: <BatchScreen />,
    documents: <DocumentsScreen />,
  };

  return screens[active];
}

function FiscalPreview() {
  const t = useTranslations('marketing.platform.fiscal');
  const [activeFunction, setActiveFunction] = useState<FiscalFunctionId>('query');
  const tabRefs = useRef<Array<HTMLButtonElement | null>>([]);

  const handleKeyDown = (event: React.KeyboardEvent<HTMLButtonElement>, index: number) => {
    let nextIndex = index;
    if (event.key === 'ArrowRight' || event.key === 'ArrowDown')
      nextIndex = (index + 1) % FISCAL_FUNCTIONS.length;
    else if (event.key === 'ArrowLeft' || event.key === 'ArrowUp')
      nextIndex = (index - 1 + FISCAL_FUNCTIONS.length) % FISCAL_FUNCTIONS.length;
    else if (event.key === 'Home') nextIndex = 0;
    else if (event.key === 'End') nextIndex = FISCAL_FUNCTIONS.length - 1;
    else return;

    event.preventDefault();
    const nextTab = FISCAL_FUNCTIONS[nextIndex];
    setActiveFunction(nextTab.id);
    tabRefs.current[nextIndex]?.focus();
  };

  return (
    <>
      <PreviewHeader
        title={t(`screenHeadings.${activeFunction}.title`)}
        description={t(`screenHeadings.${activeFunction}.description`)}
      />
      <div className="fiscal-function-tabs" role="tablist" aria-label={t('functionsLabel')}>
        {FISCAL_FUNCTIONS.map((item, index) => {
          const Icon = item.icon;
          const selected = activeFunction === item.id;
          return (
            <button
              key={item.id}
              ref={(node) => {
                tabRefs.current[index] = node;
              }}
              id={`fiscal-function-tab-${item.id}`}
              type="button"
              role="tab"
              aria-selected={selected}
              aria-controls="fiscal-function-panel"
              tabIndex={selected ? 0 : -1}
              onClick={() => setActiveFunction(item.id)}
              onKeyDown={(event) => handleKeyDown(event, index)}
            >
              <Icon size={15} />
              {t(`functions.${item.id}`)}
            </button>
          );
        })}
      </div>
      <div
        id="fiscal-function-panel"
        role="tabpanel"
        aria-labelledby={`fiscal-function-tab-${activeFunction}`}
        tabIndex={0}
        className="fiscal-function-panel"
      >
        <FiscalFunctionScreen active={activeFunction} />
      </div>
      <p className="fiscal-preview-disclaimer">
        <CircleAlert size={13} />
        {t('availabilityNote')}
      </p>
    </>
  );
}

function CertificatesPreview() {
  const t = useTranslations('marketing.platform.certificates');
  const rows = [
    { name: t('rowOne'), days: t('days'), status: t('attention'), tone: 'warning' },
    { name: t('rowTwo'), days: t('secondDays'), status: t('valid'), tone: 'success' },
  ];
  return (
    <>
      <PreviewHeader title={t('title')} description={t('description')} />
      <div className="attention-banner">
        <CircleAlert size={18} />
        <span>{t('alert')}</span>
      </div>
      <div className="preview-table preview-table--three" role="table" aria-label={t('title')}>
        <div className="preview-table__row preview-table__row--header" role="row">
          <span role="columnheader">{t('name')}</span>
          <span role="columnheader">{t('validity')}</span>
          <span role="columnheader">{t('status')}</span>
        </div>
        {rows.map((row) => (
          <div className="preview-table__row" role="row" key={row.name}>
            <span role="cell">
              <i className="certificate-icon">
                <ShieldCheck size={15} />
              </i>
              {row.name}
            </span>
            <span role="cell">{row.days}</span>
            <span role="cell">
              <StatusBadge tone={row.tone}>{row.status}</StatusBadge>
            </span>
          </div>
        ))}
      </div>
      <PreviewModuleLinks items={[t('uploadAction')]} />
    </>
  );
}

function ServicePreview() {
  const t = useTranslations('marketing.platform.service');
  return (
    <>
      <PreviewHeader title={t('title')} description={t('description')} />
      <div className="inbox-preview">
        <div className="conversation-list">
          {[t('conversationOne'), t('conversationTwo')].map((name, index) => (
            <div
              className={`conversation-item${index === 0 ? ' conversation-item--active' : ''}`}
              key={name}
            >
              <span>{name.slice(0, 2)}</span>
              <div>
                <strong>{name}</strong>
                <small>{t('preview')}</small>
              </div>
              <time>{index === 0 ? t('firstTime') : t('secondTime')}</time>
            </div>
          ))}
        </div>
        <div className="conversation-thread">
          <div className="conversation-thread__header">
            <div>
              <strong>{t('conversationOne')}</strong>
              <span>{t('channel')}</span>
            </div>
            <StatusBadge>{t('channel')}</StatusBadge>
          </div>
          <div className="conversation-thread__messages">
            <div className="thread-message thread-message--incoming">
              {t('preview')}
              <small>{t('messageTime')}</small>
            </div>
            <div className="thread-message thread-message--outgoing">
              {t('reply')}
              <small>{t('replyTime')}</small>
            </div>
            <span className="audit-event">
              <Check size={12} />
              {t('audit')}
            </span>
          </div>
        </div>
      </div>
      <PreviewModuleLinks items={[t('whatsappSettings'), t('chatbotSettings')]} />
    </>
  );
}

function BillingPreview() {
  const t = useTranslations('marketing.platform.billing');
  const metrics = [
    { label: t('companies'), value: t('usageOne'), width: '84%' },
    { label: t('queries'), value: t('usageTwo'), width: '68%' },
    { label: t('messages'), value: t('usageThree'), width: '51%' },
  ];
  return (
    <>
      <PreviewHeader title={t('title')} description={t('description')} />
      <div className="billing-preview">
        <div className="subscription-card">
          <span className="subscription-card__icon">
            <CreditCard size={22} />
          </span>
          <small>{t('plan')}</small>
          <strong>{t('status')}</strong>
          <StatusBadge>{t('status')}</StatusBadge>
        </div>
        <div className="usage-card">
          {metrics.map((metric) => (
            <div className="usage-metric" key={metric.label}>
              <div>
                <span>{metric.label}</span>
                <strong>{metric.value}</strong>
              </div>
              <div className="progress-track">
                <i style={{ width: metric.width }} />
              </div>
            </div>
          ))}
        </div>
      </div>
      <PreviewModuleLinks items={[t('overages'), t('invoices')]} />
    </>
  );
}

function AdminPreview() {
  const t = useTranslations('marketing.platform.admin');
  const rows = [
    { office: t('rowOne'), plan: t('business'), users: '8' },
    { office: t('rowTwo'), plan: t('start'), users: '3' },
  ];
  return (
    <>
      <PreviewHeader title={t('title')} description={t('description')} />
      <div className="exclusive-banner">
        <ShieldCheck size={17} />
        {t('exclusive')}
      </div>
      <div className="preview-table" role="table" aria-label={t('title')}>
        <div className="preview-table__row preview-table__row--header" role="row">
          <span role="columnheader">{t('office')}</span>
          <span role="columnheader">{t('plan')}</span>
          <span role="columnheader">{t('users')}</span>
          <span role="columnheader">{t('status')}</span>
        </div>
        {rows.map((row) => (
          <div className="preview-table__row" role="row" key={row.office}>
            <span role="cell">
              <i className="company-avatar">{row.office.slice(0, 2)}</i>
              {row.office}
            </span>
            <span role="cell">{row.plan}</span>
            <span role="cell">{row.users}</span>
            <span role="cell">
              <StatusBadge>{t('active')}</StatusBadge>
            </span>
          </div>
        ))}
      </div>
      <PreviewModuleLinks items={[t('logs'), t('notifications')]} />
    </>
  );
}

function ProductSidebar({ active }: { active: TabId }) {
  const t = useTranslations('marketing.platform.sidebar');
  const mainItems = [
    { id: 'dashboard', icon: LayoutDashboard },
    { id: 'clients', icon: Users },
  ] as const;
  const operationItems = [
    { id: 'fiscal', icon: FileSearch },
    { id: 'certificates', icon: ShieldCheck },
  ] as const;
  const billingItems = [{ id: 'billing', icon: CreditCard }] as const;

  const renderItems = (items: ReadonlyArray<{ id: TabId; icon: typeof LayoutDashboard }>) =>
    items.map((item) => {
      const Icon = item.icon;
      return (
        <div
          className={`product-sidebar__item${active === item.id ? ' is-active' : ''}`}
          key={item.id}
        >
          <Icon size={16} />
          <span>{t(item.id)}</span>
        </div>
      );
    });

  return (
    <aside className="product-sidebar" aria-hidden="true">
      <div className="product-sidebar__brand">
        <b>HC</b>
        <span>
          <strong>Contador Fiscal</strong>
          <small>{t('office')}</small>
        </span>
      </div>
      <small className="product-sidebar__group">{t('mainGroup')}</small>
      <div className="product-sidebar__nav">{renderItems(mainItems)}</div>
      <small className="product-sidebar__group">{t('operationsGroup')}</small>
      <div className="product-sidebar__nav">
        {renderItems(operationItems)}
        {active === 'fiscal' ? (
          <div className="product-sidebar__subnav">
            <span>{t('fiscalQuery')}</span>
            <span>{t('fiscalDas')}</span>
          </div>
        ) : null}
      </div>
      <small className="product-sidebar__group">{t('billingGroup')}</small>
      <div className="product-sidebar__nav">{renderItems(billingItems)}</div>
    </aside>
  );
}

function ProductPreview({ active }: { active: TabId }) {
  const screens: Record<TabId, React.ReactNode> = {
    dashboard: <DashboardPreview />,
    clients: <ClientsPreview />,
    fiscal: <FiscalPreview />,
    certificates: <CertificatesPreview />,
    service: <ServicePreview />,
    billing: <BillingPreview />,
    admin: <AdminPreview />,
  };

  return screens[active];
}

export function PlatformShowcase() {
  const t = useTranslations('marketing.platform');
  const [active, setActive] = useState<TabId>('dashboard');
  const tabRefs = useRef<Array<HTMLButtonElement | null>>([]);

  const handleKeyDown = (event: React.KeyboardEvent<HTMLButtonElement>, index: number) => {
    let nextIndex = index;
    if (event.key === 'ArrowRight' || event.key === 'ArrowDown')
      nextIndex = (index + 1) % TABS.length;
    else if (event.key === 'ArrowLeft' || event.key === 'ArrowUp')
      nextIndex = (index - 1 + TABS.length) % TABS.length;
    else if (event.key === 'Home') nextIndex = 0;
    else if (event.key === 'End') nextIndex = TABS.length - 1;
    else return;

    event.preventDefault();
    const nextTab = TABS[nextIndex];
    setActive(nextTab.id);
    tabRefs.current[nextIndex]?.focus();
  };

  return (
    <div className="platform-showcase">
      <div className="platform-tabs" role="tablist" aria-label={t('title')}>
        {TABS.map((tab, index) => {
          const Icon = tab.icon;
          const selected = active === tab.id;
          return (
            <button
              key={tab.id}
              ref={(node) => {
                tabRefs.current[index] = node;
              }}
              id={`tab-${tab.id}`}
              type="button"
              role="tab"
              aria-selected={selected}
              aria-controls="platform-panel"
              tabIndex={selected ? 0 : -1}
              onClick={() => setActive(tab.id)}
              onKeyDown={(event) => handleKeyDown(event, index)}
            >
              <Icon size={17} aria-hidden="true" />
              {t(`tabs.${tab.id}`)}
            </button>
          );
        })}
      </div>

      <div className="product-frame">
        <div className="product-frame__chrome" aria-hidden="true">
          <span />
          <span />
          <span />
          <div>{t('appAddress')}</div>
          <i>
            <ShieldCheck size={12} />
          </i>
        </div>
        <div className="product-frame__body">
          <ProductSidebar active={active} />
          <div
            id="platform-panel"
            role="tabpanel"
            aria-labelledby={`tab-${active}`}
            tabIndex={0}
            className="product-screen"
          >
            <div className="demo-notice">
              <span />
              {t('demoNotice')}
            </div>
            <ProductPreview active={active} />
          </div>
        </div>
      </div>
    </div>
  );
}
