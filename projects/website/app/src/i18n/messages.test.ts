import { describe, expect, it } from 'vitest';
import { MARKETING_PLANS } from '@/data/plans';
import ptBRMessages from './messages/pt-BR.json';

const requiredDashboardMetrics = {
  clients: ['label', 'value', 'subtitle', 'trend'],
  certificate: ['label', 'value', 'subtitle'],
  queries: ['label', 'value', 'subtitle', 'trend'],
  whatsapp: ['label', 'value', 'subtitle'],
  chatbot: ['label', 'value', 'subtitle'],
  messages: ['label', 'value', 'subtitle'],
} as const;

describe('catálogo pt-BR da plataforma', () => {
  it('mantém a comunicação comercial solicitada na landing page', () => {
    const marketing = ptBRMessages.marketing;

    expect(marketing.brand.name).toBe('Contador Fiscal');
    expect(marketing.meta.title).toContain('Contador Fiscal');
    expect(marketing.hero.titleStart).toBe('Consultas fiscais pelo WhatsApp ou Telegram,');
    expect(marketing.hero.titleEnd).toBe('para o seu escritório contábil.');
    expect(marketing.trust.serpro).toEqual({
      title: 'Integração Receita Federal',
      description: 'Consultas seguras com certificado digital do seu escritório',
    });
    expect(marketing.about.description).toContain(
      'O cliente recebe uma resposta clara pelo Telegram ou WhatsApp',
    );
    expect(marketing.workflow.steps.whatsapp.title).toBe(
      'Atenda Pelos Canais Telegram ou Whatsapp',
    );
    expect(marketing.workflow.states.pending).toBe('Pendente / DAS');
    expect(marketing.platform.dashboard.metrics.chatbot.label).toBe('Telegram');
    expect(marketing.platform.dashboard.activity.darfTitle).toBe('DAS gerada');
    expect(marketing.platform.dashboard.queryTwo.title).toBe('Emissão de DAS');
    expect(marketing.platform.dashboard.chartDarfs).toBe('DAS');
    expect(marketing.clients.profiles.scale.title).toBe(
      'Volume, performance e certificados monitorados',
    );
    expect(marketing.plans.start.features).toContain('Até 2 empresas');
    expect(marketing.plans.start.features).toContain('Integração Telegram');
    expect(marketing.plans.business.features).toContain('Até 20 empresas');
    expect(marketing.plans.business.features).toContain('Integração Telegram ou Whatsapp');
    expect(MARKETING_PLANS.find(({ id }) => id === 'BUSINESS')?.featureCount).toBe(4);
    expect(MARKETING_PLANS.find(({ id }) => id === 'PREMIUM')?.featureCount).toBe(6);
    expect(marketing.plans.premium.features).toContain('Atenda Pelos Canais Telegram ou Whatsapp');
    expect(marketing.plans.rows).not.toHaveProperty('reports');
    expect(marketing.plans.rows.whatsapp).toBe('Atendimento Whatsapp');
    expect(marketing.plans.rows.telegram).toBe('Atendimento Telegram');
    expect(marketing.plans.rows.certificates).toBe('Gestão de Certificado');
    expect(marketing.plans.rows.dashboard).toBe('Dashboard');
    expect(marketing.plans.start).not.toHaveProperty('whatsapp');
    expect(marketing.plans.start.telegram).toBe('Incluído');

    for (const plan of [marketing.plans.start, marketing.plans.business, marketing.plans.premium]) {
      expect(plan.certificates).toBe('Incluído');
      expect(plan.dashboard).toBe('Incluído');
    }

    expect(marketing.plans.business.whatsapp).toBe('Incluído');
    expect(marketing.plans.business.telegram).toBe('Incluído');
    expect(marketing.plans.business).not.toHaveProperty('support');
    expect(marketing.plans.premium.whatsapp).toBe('Incluído');
    expect(marketing.plans.premium.telegram).toBe('Incluído');
    expect(marketing.plans.premium.support).toBe('Incluído');
    expect(marketing.plans.business.features).not.toContain('Suporte prioritário');
    expect(marketing.plans.premium.features).toContain('Suporte prioritário');
    expect(marketing.plans.premium.features).toContain('Analisar por consultoria');
    expect(marketing.plans.premium.companies).toBe('Analisar por consultoria');
    expect(marketing.faq.items.product.answer).toBe(
      'É uma plataforma para multi escritórios contábeis que oferecere consultas fiscais pelo Telegram ou WhatsApp, com certificados digitais, integração com a Receita Federal e acompanhamento em painel',
    );
    expect(marketing.faq.items.authorization.question).toBe(
      'Qualquer número pode consultar pelo Telegram ou WhatsApp?',
    );
    expect(marketing.faq.items.isolation.answer).toBe(
      'A arquitetura multi escritório mantém a carteira de cada escritório isolada. O contador visualiza apenas os clientes associados ao seu ambiente, além de uma única conta de e-mail poder acessar múltiplos escritórios',
    );
    expect(marketing.faq.items.plans.answer).toBe(
      'O Start valida o fluxo com até 2 empresas; o Business atende escritórios pequenos e médios com até 20 empresas e suporte prioritário; o Premium atende grandes operações com empresas com limite configurável, visão avançada e gestão de certificados.',
    );
    expect(marketing.faq.items.subscription.answer).toBe(
      'No topo da página selecione [Conhecer os planos] e entre em contato conosco. Valores, condições disponíveis e a assinatura são tratados com um de nossos consultores e eles entrarão em contato com você.',
    );
    expect(marketing.footer.description).toBe(
      'Autoatendimento fiscal pelo Telegram ou WhatsApp para escritórios contábeis.',
    );
    expect(marketing.contact.phone).toBe('Telefone / WhatsApp *');
    expect(marketing.contact.phonePlaceholder).toBe('(99) 99999.9999');
    expect(marketing.contact.status.NOT_CONFIGURED).toBe(
      'O formulário está temporariamente indisponível. Tente novamente mais tarde.',
    );
    expect(marketing.contact.status.NOT_CONFIGURED_WITH_EMAIL).toBe(
      'O formulário está temporariamente indisponível. Use o e-mail disponível nesta seção.',
    );
  });

  it('contém todas as mensagens usadas pelos KPIs do dashboard', () => {
    const metrics = ptBRMessages.marketing.platform.dashboard.metrics as Record<
      string,
      Record<string, string>
    >;

    for (const [metric, fields] of Object.entries(requiredDashboardMetrics)) {
      for (const field of fields) {
        expect(
          metrics[metric]?.[field],
          `marketing.platform.dashboard.metrics.${metric}.${field}`,
        ).toBeTruthy();
      }
    }
  });

  it('contém as mensagens das cinco telas fiscais demonstrativas', () => {
    const fiscal = ptBRMessages.marketing.platform.fiscal;

    expect(Object.keys(fiscal.functions)).toEqual(['query', 'das', 'darf', 'batch', 'documents']);
    expect(Object.keys(fiscal.screenHeadings)).toEqual([
      'query',
      'das',
      'darf',
      'batch',
      'documents',
    ]);
    expect(fiscal.queryScreen.correlationId).toBeTruthy();
    expect(fiscal.dasScreen.status).toBeTruthy();
    expect(fiscal.darfScreen.digitLine).toBeTruthy();
    expect(fiscal.batchScreen.progress).toBeTruthy();
    expect(fiscal.documentsScreen.title).toBeTruthy();
  });
});
