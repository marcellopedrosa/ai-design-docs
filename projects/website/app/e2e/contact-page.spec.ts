import AxeBuilder from '@axe-core/playwright';
import { expect, test } from '@playwright/test';

test('offers the existing commercial contact form at the dedicated path', async ({
  page,
  isMobile,
}) => {
  await page.goto('/contate');

  await expect(page).toHaveURL(/\/contate$/u);
  await expect(page).toHaveTitle('Contate o time comercial | Contador Fiscal');
  await expect(page.getByRole('heading', { level: 1 })).toHaveText(
    'Consultas fiscais pelo WhatsApp ou Telegram, com segurança e escala para o seu escritório contábil.',
  );
  await expect(page.getByText('Autoatendimento fiscal para escritórios contábeis')).toBeVisible();
  const heroCopy = page.locator('.contact-page__copy');
  const contactForm = page.locator('.contact-card');
  await expect(heroCopy).toBeVisible();
  await expect(page.getByRole('heading', { name: 'Fale com o time comercial' })).toBeVisible();
  await expect(page.getByLabel('Telefone / WhatsApp *')).toHaveAttribute('required', '');
  await expect(page.getByRole('button', { name: 'Enviar mensagem' })).toBeVisible();
  await expect(page.locator('.hero-section')).toHaveCount(0);
  await expect(page.locator('#planos')).toHaveCount(0);

  const heroBox = await heroCopy.boundingBox();
  const formBox = await contactForm.boundingBox();
  expect(heroBox).not.toBeNull();
  expect(formBox).not.toBeNull();
  if (isMobile) {
    expect(formBox!.y).toBeGreaterThan(heroBox!.y + heroBox!.height);
  } else {
    expect(heroBox!.x + heroBox!.width).toBeLessThan(formBox!.x);
    expect(Math.abs(heroBox!.y - formBox!.y)).toBeLessThanOrEqual(1);
    expect(formBox!.y).toBeLessThanOrEqual(40);
  }

  const messageBox = await page.getByLabel('Mensagem *').boundingBox();
  expect(messageBox).not.toBeNull();
  expect(messageBox!.height).toBeLessThanOrEqual(100);

  const accessibilityScan = await new AxeBuilder({ page }).analyze();
  expect(accessibilityScan.violations).toEqual([]);
});

test('stacks the dedicated contact layout without horizontal overflow on mobile', async ({
  page,
}) => {
  await page.setViewportSize({ width: 390, height: 844 });
  await page.goto('/contate');

  const heroBox = await page.locator('.contact-page__copy').boundingBox();
  const formBox = await page.locator('.contact-card').boundingBox();
  expect(heroBox).not.toBeNull();
  expect(formBox).not.toBeNull();
  expect(formBox!.y).toBeGreaterThan(heroBox!.y + heroBox!.height);
  expect(await page.evaluate(() => document.documentElement.scrollWidth)).toBeLessThanOrEqual(390);
});
