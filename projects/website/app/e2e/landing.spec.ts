import AxeBuilder from '@axe-core/playwright';
import { expect, test } from '@playwright/test';

const REQUIRED_NAVIGATION = [
  { label: 'Quem somos', hash: '#quem-somos' },
  { label: 'Clientes', hash: '#clientes' },
  { label: 'Planos', hash: '#planos' },
  { label: 'Contate', hash: '#contate' },
] as const;

const PLAN_TYPES = ['START', 'BUSINESS', 'PREMIUM'] as const;
const PLATFORM_TABS = [
  'Painel',
  'Clientes',
  'Fiscal',
  'Certificados',
  'Atendimento',
  'Assinatura',
  'Administração',
] as const;
const FISCAL_TABS = [
  'Situação Fiscal',
  'DAS Cobrança',
  'Emissão de DARF',
  'Processamento',
  'Documentos',
] as const;
const RESPONSIVE_VIEWPORTS = [360, 390, 768, 1024, 1440] as const;

test.beforeEach(async ({ page }) => {
  await page.goto('/');
});

test('renders the required menu and sections in order and navigates by anchors', async ({
  page,
}) => {
  await page.setViewportSize({ width: 1280, height: 900 });
  await page.reload();

  await expect(page).toHaveTitle(/Contador Fiscal/);
  await expect(page.locator('body')).not.toContainText(['Hub', 'Contábil'].join(' '));
  await expect(page.getByRole('heading', { level: 1 })).toContainText(
    'Consultas fiscais pelo WhatsApp ou Telegram, com segurança e escala para o seu escritório contábil.',
  );

  const headerBox = await page.locator('.site-header').boundingBox();
  const heroEyebrowBox = await page.locator('.hero-copy .eyebrow').boundingBox();
  expect(headerBox).not.toBeNull();
  expect(heroEyebrowBox).not.toBeNull();
  expect(heroEyebrowBox!.y - (headerBox!.y + headerBox!.height)).toBeLessThanOrEqual(80);

  const navigation = page.locator('.site-header__nav');
  const links = navigation.locator('a');

  await expect(page.getByRole('link', { name: 'Acessar o sistema', exact: true })).toHaveCount(0);
  await expect(
    page.locator('.site-footer').getByRole('link', { name: 'Entrar no sistema', exact: true }),
  ).toHaveCount(0);

  const footerDescription = page
    .locator('.site-footer__brand')
    .getByText('Autoatendimento fiscal pelo Telegram ou WhatsApp para escritórios contábeis.');
  await expect(footerDescription).toBeVisible();
  expect(
    await footerDescription.evaluate((element) => {
      const range = document.createRange();
      range.selectNodeContents(element);
      return range.getClientRects().length;
    }),
  ).toBe(1);

  await expect(navigation).toBeVisible();
  await expect(links).toHaveCount(REQUIRED_NAVIGATION.length);
  await expect(links).toHaveText(REQUIRED_NAVIGATION.map(({ label }) => label));

  for (const [index, item] of REQUIRED_NAVIGATION.entries()) {
    await expect(links.nth(index)).toHaveAttribute('href', item.hash);
  }

  const renderedSectionOrder = await page.locator('main section[id]').evaluateAll(
    (sections, requiredIds) =>
      sections.map((section) => section.id).filter((id) => (requiredIds as string[]).includes(id)),
    REQUIRED_NAVIGATION.map(({ hash }) => hash.slice(1)),
  );

  expect(renderedSectionOrder).toEqual(REQUIRED_NAVIGATION.map(({ hash }) => hash.slice(1)));

  const sectionPaddings = await page.locator('main > .section').evaluateAll((sections) =>
    sections.map((section) => {
      const styles = window.getComputedStyle(section);
      return {
        top: Number.parseFloat(styles.paddingTop),
        bottom: Number.parseFloat(styles.paddingBottom),
      };
    }),
  );
  expect(sectionPaddings.length).toBeGreaterThan(0);
  for (const padding of sectionPaddings) {
    expect(padding.top).toBeLessThanOrEqual(88);
    expect(padding.bottom).toBeLessThanOrEqual(88);
  }

  for (const [index, item] of REQUIRED_NAVIGATION.entries()) {
    await links.nth(index).click();
    await expect.poll(() => page.evaluate(() => window.location.hash)).toBe(item.hash);
    await expect(page.locator(item.hash)).toBeInViewport();
  }
});

test('shows the three documented plans without mock prices or individual CTAs', async ({
  page,
}) => {
  const plansSection = page.locator('#planos');
  const cards = plansSection.locator('.plan-card');

  await expect(cards).toHaveCount(PLAN_TYPES.length);
  await expect(cards.locator('h3')).toHaveText(['Start', 'Business', 'Premium']);
  await expect(cards.locator('.plan-card__value > strong')).toHaveText([
    'Consulte valores e condições',
    'Consulte valores e condições',
    'Consulte valores e condições',
  ]);

  await expect(cards.nth(0)).toContainText('Até 2 empresas');
  await expect(cards.nth(0)).toContainText('Integração Telegram');
  await expect(cards.nth(1)).toContainText('Até 20 empresas');
  await expect(cards.nth(1)).toContainText('Integração Telegram ou Whatsapp');
  await expect(cards.nth(2)).toContainText('Atenda Pelos Canais Telegram ou Whatsapp');
  await expect(cards.nth(2)).toContainText('Analisar por consultoria');

  const comparison = plansSection.locator('.comparison-table');
  await expect(comparison.getByRole('row', { name: /^Empresas / }).locator('td')).toHaveText([
    'Até 2',
    'Até 20',
    'Analisar por consultoria',
  ]);
  await expect(
    comparison.getByRole('row', { name: /Atendimento Whatsapp/ }).locator('td'),
  ).toHaveText(['Não especificado', 'Incluído', 'Incluído']);
  await expect(
    comparison.getByRole('row', { name: /Atendimento Telegram/ }).locator('td'),
  ).toHaveText(['Incluído', 'Incluído', 'Incluído']);
  await expect(
    comparison.getByRole('row', { name: /Gestão de Certificado/ }).locator('td'),
  ).toHaveText(['Incluído', 'Incluído', 'Incluído']);
  await expect(comparison.getByRole('row', { name: /^Dashboard / }).locator('td')).toHaveText([
    'Incluído',
    'Incluído',
    'Incluído',
  ]);
  await expect(
    comparison.getByRole('row', { name: /Suporte prioritário/ }).locator('td'),
  ).toHaveText(['Não especificado', 'Não especificado', 'Incluído']);
  await expect(comparison).not.toContainText('Relatório de horas economizadas');

  const plansCopy = await plansSection.innerText();
  expect(plansCopy).not.toMatch(/R\$\s*\d/i);
  expect(plansCopy).not.toMatch(/\b(?:99|299|899)(?:[,.]00)?\b/);

  await expect(cards.getByRole('link')).toHaveCount(0);
  expect((await cards.allTextContents()).join(' ')).not.toMatch(
    /Escolher (Start|Business|Premium)/,
  );
});

test('supports the mobile menu at 360px, including Escape and anchor selection', async ({
  page,
}) => {
  await page.setViewportSize({ width: 360, height: 800 });
  await page.reload();
  await page.waitForLoadState('networkidle');

  const toggle = page.locator('.site-header__menu-button');
  await expect(toggle).toBeVisible();
  await expect(toggle).toHaveAccessibleName('Abrir menu');
  await expect(toggle).toHaveAttribute('aria-expanded', 'false');

  await toggle.click();
  await expect(toggle).toHaveAccessibleName('Fechar menu');
  await expect(toggle).toHaveAttribute('aria-expanded', 'true');

  const mobileMenu = page.locator('#mobile-menu');
  const mobileLinks = mobileMenu.locator('nav a');
  await expect(mobileMenu).toBeVisible();
  await expect(mobileLinks).toHaveText(REQUIRED_NAVIGATION.map(({ label }) => label));

  await page.keyboard.press('Escape');
  await expect(mobileMenu).toHaveCount(0);
  await expect(toggle).toBeFocused();

  await toggle.click();
  await page.locator('#mobile-menu nav a[href="#planos"]').click();
  await expect.poll(() => page.evaluate(() => window.location.hash)).toBe('#planos');
  await expect(page.locator('#mobile-menu')).toHaveCount(0);
  await expect(page.locator('#planos')).toBeInViewport();
});

test('supports keyboard navigation across the platform tabs', async ({ page }) => {
  const tablist = page.locator('.platform-tabs');
  const tabs = tablist.getByRole('tab');
  const panel = page.getByRole('tabpanel');

  await expect(tabs).toHaveCount(PLATFORM_TABS.length);
  await expect(tabs).toHaveText([...PLATFORM_TABS]);
  await expect(tabs.nth(0)).toHaveAttribute('aria-selected', 'true');
  await expect(tabs.nth(0)).toHaveAttribute('tabindex', '0');
  await expect(panel).toHaveAttribute('aria-labelledby', 'tab-dashboard');

  await tabs.nth(0).focus();
  await page.keyboard.press('ArrowRight');
  await expect(tabs.nth(1)).toBeFocused();
  await expect(tabs.nth(1)).toHaveAttribute('aria-selected', 'true');
  await expect(tabs.nth(0)).toHaveAttribute('tabindex', '-1');
  await expect(panel).toHaveAttribute('aria-labelledby', 'tab-clients');

  await page.keyboard.press('End');
  await expect(tabs.nth(PLATFORM_TABS.length - 1)).toBeFocused();
  await expect(tabs.nth(PLATFORM_TABS.length - 1)).toHaveAttribute('aria-selected', 'true');
  await expect(panel).toHaveAttribute('aria-labelledby', 'tab-admin');

  await page.keyboard.press('Home');
  await expect(tabs.nth(0)).toBeFocused();
  await expect(tabs.nth(0)).toHaveAttribute('aria-selected', 'true');

  await page.keyboard.press('ArrowLeft');
  await expect(tabs.nth(PLATFORM_TABS.length - 1)).toBeFocused();
  await expect(tabs.nth(PLATFORM_TABS.length - 1)).toHaveAttribute('aria-selected', 'true');
});

test('shows the six dashboard KPIs and the operational widgets from the application', async ({
  page,
}) => {
  const panel = page.locator('#platform-panel');
  const cards = panel.locator('.preview-kpi-card');

  await expect(cards).toHaveCount(6);
  await expect(cards.locator('.preview-kpi-card__copy > small')).toHaveText([
    'Clientes Ativos',
    'Certificado',
    'Cons. Fiscais',
    'WhatsApp',
    'Telegram',
    'Total Mensagens',
  ]);
  await expect(cards.locator('.preview-kpi-card__value > strong')).toHaveText([
    '42',
    '15',
    '1.250',
    '1.450',
    '3.450',
    '4.900',
  ]);

  await expect(panel.getByText('Atividade Recente', { exact: true })).toBeVisible();
  await expect(panel.getByText('DAS gerada', { exact: true })).toBeVisible();
  await expect(
    panel.getByText('Empresa Semente — documento disponível', { exact: true }),
  ).toBeVisible();
  await expect(panel.getByText('Evolução Fiscal', { exact: true })).toBeVisible();
  await expect(panel.getByText('Consultas', { exact: true })).toBeVisible();
  await expect(panel.getByText('DAS', { exact: true })).toBeVisible();
  await expect(panel.getByText('Últimas Movimentações', { exact: true })).toBeVisible();
  await expect(panel.getByText('Emissão de DAS', { exact: true })).toBeVisible();
  await expect(panel.getByText('SUCESSO', { exact: true })).toHaveCount(2);
  await expect(panel.getByText('ERRO', { exact: true })).toBeVisible();
  await expect(panel.getByText('PENDENTE', { exact: true })).toBeVisible();
});

test('exposes each implemented fiscal screen and supports keyboard navigation', async ({
  page,
}) => {
  await page.locator('.platform-tabs').getByRole('tab', { name: 'Fiscal', exact: true }).click();

  const fiscalTabs = page.getByRole('tablist', { name: 'Telas fiscais demonstrativas' });
  const tabs = fiscalTabs.getByRole('tab');
  const panel = page.locator('#fiscal-function-panel');

  await expect(tabs).toHaveCount(FISCAL_TABS.length);
  await expect(tabs).toHaveText([...FISCAL_TABS]);
  await expect(panel).toContainText('Histórico de Consultas');
  await expect(panel).toContainText('ID de Correlação');
  await expect(panel).toContainText('Débitos Identificados');
  await expect(panel).toContainText('Gerar DARF');
  await expect(panel).toContainText('ABERTO');
  await expect(panel).toContainText('PARCELADO');

  const expectedContent: Array<[string, string[]]> = [
    ['DAS Cobrança', ['Período de Apuração', 'Data de Consolidação', 'EMITIDO', 'PDF']],
    ['Emissão de DARF', ['Código Receita', 'Linha Digitável', 'DARFs Emitidos', 'PDF']],
    [
      'Processamento',
      ['Monitor de Processamento', 'CONSULTA CNPJs', 'GERAÇÃO DARF', 'DOWNLOAD NFe', 'Progresso'],
    ],
    [
      'Documentos',
      [
        'Repositório de Documentos',
        'Todos os tipos',
        'RELATÓRIO',
        'NFe XML',
        'DARF PDF',
        'CND PDF',
      ],
    ],
  ];

  for (const [tabName, content] of expectedContent) {
    await fiscalTabs.getByRole('tab', { name: tabName, exact: true }).click();
    for (const text of content) await expect(panel).toContainText(text);
  }

  await tabs.nth(0).focus();
  await page.keyboard.press('ArrowRight');
  await expect(tabs.nth(1)).toBeFocused();
  await expect(tabs.nth(1)).toHaveAttribute('aria-selected', 'true');
  await expect(panel).toHaveAttribute('aria-labelledby', 'fiscal-function-tab-das');

  await page.keyboard.press('End');
  await expect(tabs.nth(FISCAL_TABS.length - 1)).toBeFocused();
  await expect(panel).toHaveAttribute('aria-labelledby', 'fiscal-function-tab-documents');

  await page.keyboard.press('Home');
  await expect(tabs.nth(0)).toBeFocused();
  await expect(panel).toHaveAttribute('aria-labelledby', 'fiscal-function-tab-query');
});

test('returns the basic security headers on the landing response', async ({ page }) => {
  const response = await page.goto('/');
  expect(response).not.toBeNull();

  const headers = response!.headers();
  expect(headers['content-security-policy']).toContain("default-src 'self'");
  expect(headers['content-security-policy']).toContain("object-src 'none'");
  expect(headers['content-security-policy']).toContain("frame-ancestors 'none'");
  expect(headers['referrer-policy']).toBe('strict-origin-when-cross-origin');
  expect(headers['x-content-type-options']).toBe('nosniff');
  expect(headers['x-frame-options']).toBe('DENY');
  expect(headers['permissions-policy']).toContain('camera=()');
  expect(headers['cross-origin-opener-policy']).toBe('same-origin');
  expect(headers['x-powered-by']).toBeUndefined();
});

test('requires and masks the commercial contact phone', async ({ page }) => {
  const phone = page.getByLabel('Telefone / WhatsApp *', { exact: true });

  await expect(phone).toHaveAttribute('required', '');
  await expect(phone).toHaveAttribute('inputmode', 'numeric');
  await expect(phone).toHaveAttribute('placeholder', '(99) 99999.9999');
  await expect(phone).toHaveAttribute('pattern', '\\(\\d{2}\\) \\d{4,5}\\.\\d{4}');
  await phone.fill('8133334444');
  await expect(phone).toHaveValue('(81) 3333.4444');
  await phone.fill('81999999999');
  await expect(phone).toHaveValue('(81) 99999.9999');
});

test('rejects invalid contact data and reports an unconfigured webhook', async ({
  request,
}, testInfo) => {
  const requestKey = `${testInfo.project.name}-${process.pid}`;
  const invalidResponse = await request.post('/api/contact', {
    headers: {
      'Idempotency-Key': `${requestKey}-invalid-contact`,
      'x-forwarded-for': `${requestKey}-invalid`,
    },
    data: { name: 'A' },
  });

  expect(invalidResponse.status()).toBe(400);
  await expect(invalidResponse.json()).resolves.toEqual({ code: 'VALIDATION_ERROR' });

  const noWebhookResponse = await request.post('/api/contact', {
    headers: {
      'Idempotency-Key': `${requestKey}-unconfigured-contact`,
      'x-forwarded-for': `${requestKey}-no-webhook`,
    },
    data: {
      name: 'Maria Contadora',
      email: 'maria@example.com',
      company: 'Escritório Exemplo',
      phone: '(81) 99999.9999',
      plan: 'BUSINESS',
      message: 'Gostaria de conhecer melhor o Contador Fiscal.',
      website: '',
      captchaToken: 'synthetic-e2e-token',
    },
  });

  expect(noWebhookResponse.status()).toBe(503);
  await expect(noWebhookResponse.json()).resolves.toEqual({ code: 'NOT_CONFIGURED' });
});

test('does not introduce horizontal overflow at the supported viewports', async ({ page }) => {
  test.setTimeout(120_000);

  for (const width of RESPONSIVE_VIEWPORTS) {
    await page.setViewportSize({ width, height: 900 });
    await page.reload();

    const assertNoOverflow = async (screen: string) => {
      const dimensions = await page.evaluate(() => ({
        clientWidth: document.documentElement.clientWidth,
        scrollWidth: document.documentElement.scrollWidth,
      }));

      expect(
        dimensions.scrollWidth,
        `Expected no horizontal overflow at ${width}px on ${screen}: scrollWidth=${dimensions.scrollWidth}, clientWidth=${dimensions.clientWidth}`,
      ).toBeLessThanOrEqual(dimensions.clientWidth);
    };

    await assertNoOverflow('Painel');

    const platformTabs = page.locator('.platform-tabs');
    for (const tabName of PLATFORM_TABS.slice(1)) {
      await platformTabs.getByRole('tab', { name: tabName, exact: true }).click();
      await assertNoOverflow(tabName);

      if (tabName === 'Fiscal') {
        const fiscalTabs = page.getByRole('tablist', {
          name: 'Telas fiscais demonstrativas',
        });
        for (const fiscalTab of FISCAL_TABS) {
          await fiscalTabs.getByRole('tab', { name: fiscalTab, exact: true }).click();
          await assertNoOverflow(`Fiscal / ${fiscalTab}`);
        }
      }
    }
  }
});

test('has no serious or critical axe violations', async ({ page }) => {
  test.setTimeout(120_000);

  const assertNoBlockingViolations = async (screen: string) => {
    const results = await new AxeBuilder({ page }).analyze();
    const blockingViolations = results.violations.filter(
      ({ impact }) => impact === 'serious' || impact === 'critical',
    );

    expect(
      blockingViolations,
      `${screen}\n${blockingViolations
        .map(
          ({ id, impact, help, nodes }) =>
            `[${impact}] ${id}: ${help}\n${nodes.map(({ target }) => `  - ${target.join(' ')}`).join('\n')}`,
        )
        .join('\n\n')}`,
    ).toEqual([]);
  };

  await assertNoBlockingViolations('Painel');
  await page.locator('.platform-tabs').getByRole('tab', { name: 'Fiscal', exact: true }).click();

  const fiscalTabs = page.getByRole('tablist', { name: 'Telas fiscais demonstrativas' });
  for (const tabName of FISCAL_TABS) {
    await fiscalTabs.getByRole('tab', { name: tabName, exact: true }).click();
    await assertNoBlockingViolations(`Fiscal / ${tabName}`);
  }
});
