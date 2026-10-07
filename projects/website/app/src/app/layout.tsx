import type { Metadata, Viewport } from 'next';
import { getLocale, getMessages, getTranslations } from 'next-intl/server';
import { NextIntlClientProvider } from 'next-intl';
import { getSiteBaseUrl } from '@/lib/urls';
import './globals.css';

const siteUrl = getSiteBaseUrl();

export const metadata: Metadata = {
  metadataBase: new URL(siteUrl),
  title: 'Contador Fiscal | Autoatendimento fiscal pelo WhatsApp',
  description:
    'Automatize consultas de situação fiscal pelo WhatsApp com contatos autorizados, certificados protegidos e uma operação auditável.',
  alternates: { canonical: '/' },
  applicationName: 'Contador Fiscal',
  category: 'business',
  openGraph: {
    type: 'website',
    locale: 'pt_BR',
    url: '/',
    siteName: 'Contador Fiscal',
    title: 'Contador Fiscal | Autoatendimento fiscal pelo WhatsApp',
    description:
      'Automação de consultas fiscais para escritórios contábeis, com segurança e escala.',
  },
  twitter: {
    card: 'summary',
    title: 'Contador Fiscal | Autoatendimento fiscal pelo WhatsApp',
    description:
      'Automação de consultas fiscais para escritórios contábeis, com segurança e escala.',
  },
};

export const viewport: Viewport = {
  width: 'device-width',
  initialScale: 1,
  themeColor: [
    { media: '(prefers-color-scheme: light)', color: '#F8FAFC' },
    { media: '(prefers-color-scheme: dark)', color: '#0F172A' },
  ],
  colorScheme: 'light dark',
};

export default async function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  const [locale, messages, t] = await Promise.all([
    getLocale(),
    getMessages(),
    getTranslations('marketing.a11y'),
  ]);

  return (
    <html lang={locale}>
      <body>
        <a className="skip-link" href="#main-content">
          {t('skipToContent')}
        </a>
        <NextIntlClientProvider locale={locale} messages={messages} timeZone="America/Recife">
          {children}
        </NextIntlClientProvider>
      </body>
    </html>
  );
}
