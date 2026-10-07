import { existsSync, readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { describe, expect, it } from 'vitest';

const exportDirectory = resolve(process.cwd(), 'site-html');
const indexPath = resolve(exportDirectory, 'index.html');
const contactPath = resolve(exportDirectory, 'contate.html');

describe('exportação HTML estática', () => {
  it('contém a landing page e todos os assets locais referenciados', () => {
    expect(existsSync(indexPath)).toBe(true);

    const html = readFileSync(indexPath, 'utf8');

    expect(html).toMatch(/^<!DOCTYPE html>/i);
    expect(html).toContain('<title>Contador Fiscal');
    expect(html).toContain('id="quem-somos"');
    expect(html).toContain('id="clientes"');
    expect(html).toContain('id="planos"');
    expect(html).toContain('id="contate"');
    expect(html).not.toContain(['Hub', 'Contábil'].join(' '));

    const assetReferences = [...html.matchAll(/(?:href|src)="\.\/(\_next\/static\/[^"?#]+)/g)].map(
      ([, assetPath]) => decodeURIComponent(assetPath),
    );

    expect(assetReferences.length).toBeGreaterThan(0);
    for (const assetPath of new Set(assetReferences)) {
      expect(existsSync(resolve(exportDirectory, assetPath)), assetPath).toBe(true);
    }
  });

  it('inclui a página dedicada de contato sem remover a seção da landing page', () => {
    expect(existsSync(indexPath)).toBe(true);
    expect(existsSync(contactPath)).toBe(true);

    const landingHtml = readFileSync(indexPath, 'utf8');
    const contactHtml = readFileSync(contactPath, 'utf8');

    expect(landingHtml).toContain('id="contate"');
    expect(contactHtml).toContain('id="contate"');
    expect(contactHtml).toContain('Consultas fiscais pelo WhatsApp ou Telegram,');
    expect(contactHtml).toContain('Fale com o time comercial');
    expect(contactHtml).not.toContain('class="hero-section"');
  });
});
