import type { NextConfig } from 'next';
import createNextIntlPlugin from 'next-intl/plugin';

const withNextIntl = createNextIntlPlugin('./src/i18n/request.ts');

const isDevelopment = process.env.NODE_ENV === 'development';
const isStaticHtmlExport = process.env.NEXT_STATIC_HTML_EXPORT === '1';

const contentSecurityPolicy = [
  "default-src 'self'",
  `script-src 'self' 'unsafe-inline' https://www.google.com/recaptcha/ https://www.gstatic.com/recaptcha/${isDevelopment ? " 'unsafe-eval'" : ''}`,
  "style-src 'self' 'unsafe-inline'",
  "img-src 'self' data: blob:",
  "font-src 'self' data:",
  `connect-src 'self' https://www.google.com/recaptcha/${isDevelopment ? ' ws: http:' : ''}`,
  "object-src 'none'",
  "base-uri 'self'",
  "form-action 'self'",
  "frame-ancestors 'none'",
  'frame-src https://www.google.com/recaptcha/ https://recaptcha.google.com/recaptcha/',
  "worker-src 'self' blob:",
].join('; ');

const securityHeaders = [
  { key: 'Content-Security-Policy', value: contentSecurityPolicy },
  { key: 'Referrer-Policy', value: 'strict-origin-when-cross-origin' },
  { key: 'X-Content-Type-Options', value: 'nosniff' },
  { key: 'X-Frame-Options', value: 'DENY' },
  {
    key: 'Permissions-Policy',
    value: 'camera=(), microphone=(), geolocation=(), payment=(), browsing-topics=()',
  },
  { key: 'Cross-Origin-Opener-Policy', value: 'same-origin' },
  ...(isDevelopment
    ? []
    : [{ key: 'Strict-Transport-Security', value: 'max-age=31536000; includeSubDomains' }]),
];

const nextConfig: NextConfig = {
  output: isStaticHtmlExport ? 'export' : 'standalone',
  distDir: isStaticHtmlExport ? 'site-html' : '.next',
  assetPrefix: isStaticHtmlExport ? '.' : undefined,
  poweredByHeader: false,
  reactStrictMode: true,
  experimental: {
    useTypeScriptCli: false,
  },
  turbopack: {
    root: process.cwd(),
  },
  ...(isStaticHtmlExport
    ? {}
    : {
        async headers() {
          return [{ source: '/:path*', headers: securityHeaders }];
        },
      }),
};

export default withNextIntl(nextConfig);
