import { fireEvent, render, screen, waitFor } from '@testing-library/react';
import { NextIntlClientProvider } from 'next-intl';
import { afterEach, describe, expect, it, vi } from 'vitest';
import ptBRMessages from '@/i18n/messages/pt-BR.json';
import { ContactForm } from '../ContactForm';

vi.mock('../RecaptchaCheckbox', () => ({
  RecaptchaCheckbox: ({ onTokenChange }: { onTokenChange(token: string): void }) => (
    <button type="button" onClick={() => onTokenChange('captcha-test-token')}>
      Confirmar que não sou robô
    </button>
  ),
}));

const CREATED_CONTACT = {
  code: 'SUCCESS',
  id: '6d5c1539-8995-4a45-b71c-9c8e994dfca6',
  status: 'NEW',
  createdAt: '2026-09-05T12:30:00Z',
};

function websiteResponse(body: unknown, ok: boolean): Response {
  return {
    ok,
    json: vi.fn().mockResolvedValue(body),
  } as unknown as Response;
}

describe('ContactForm', () => {
  afterEach(() => {
    vi.unstubAllGlobals();
  });

  it('reuses the idempotency key for retries and rotates it after the payload changes', async () => {
    const fetchMock = vi
      .fn()
      .mockResolvedValueOnce(websiteResponse({ code: 'DELIVERY_ERROR' }, false))
      .mockResolvedValueOnce(websiteResponse({ code: 'DELIVERY_ERROR' }, false))
      .mockResolvedValueOnce(websiteResponse(CREATED_CONTACT, true));
    vi.stubGlobal('fetch', fetchMock);

    render(
      <NextIntlClientProvider locale="pt-BR" messages={ptBRMessages}>
        <ContactForm />
      </NextIntlClientProvider>,
    );

    expect(
      screen.getByRole('heading', { level: 3, name: 'Fale com o time comercial' }),
    ).toBeInTheDocument();

    fireEvent.change(screen.getByLabelText('Nome *'), { target: { value: 'Ana Contadora' } });
    fireEvent.change(screen.getByLabelText('E-mail profissional *'), {
      target: { value: 'ana@escritorio.example' },
    });
    fireEvent.change(screen.getByLabelText('Escritório *'), {
      target: { value: 'Escritório Aurora' },
    });
    fireEvent.change(screen.getByLabelText('Telefone / WhatsApp *'), {
      target: { value: '81999999999' },
    });
    fireEvent.change(screen.getByLabelText('Plano de interesse *'), {
      target: { value: 'BUSINESS' },
    });

    const message = screen.getByLabelText('Mensagem *');
    fireEvent.change(message, {
      target: { value: 'Quero automatizar as consultas fiscais do escritório.' },
    });

    const submit = screen.getByRole('button', { name: 'Enviar mensagem' });
    expect(submit).toBeDisabled();
    fireEvent.click(screen.getByRole('button', { name: 'Confirmar que não sou robô' }));
    fireEvent.click(submit);
    await waitFor(() => expect(fetchMock).toHaveBeenCalledTimes(1));
    await screen.findByText(
      'Não foi possível entregar a mensagem agora. Tente novamente em instantes.',
    );

    fireEvent.click(submit);
    fireEvent.click(screen.getByRole('button', { name: 'Confirmar que não sou robô' }));
    fireEvent.click(submit);
    await waitFor(() => expect(fetchMock).toHaveBeenCalledTimes(2));
    await waitFor(() => expect(submit).toBeDisabled());

    const firstHeaders = fetchMock.mock.calls[0][1]?.headers as Record<string, string>;
    const retryHeaders = fetchMock.mock.calls[1][1]?.headers as Record<string, string>;
    expect(firstHeaders['Idempotency-Key']).toMatch(
      /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/,
    );
    expect(retryHeaders['Idempotency-Key']).toBe(firstHeaders['Idempotency-Key']);

    fireEvent.change(message, {
      target: { value: 'Agora preciso automatizar também o atendimento fiscal.' },
    });
    fireEvent.click(screen.getByRole('button', { name: 'Confirmar que não sou robô' }));
    fireEvent.click(submit);

    await screen.findByText(
      'Contato registrado. O time comercial poderá responder pelo e-mail informado.',
    );
    expect(fetchMock).toHaveBeenCalledTimes(3);

    const changedHeaders = fetchMock.mock.calls[2][1]?.headers as Record<string, string>;
    expect(changedHeaders['Idempotency-Key']).not.toBe(firstHeaders['Idempotency-Key']);
    expect(JSON.parse(fetchMock.mock.calls[2][1]?.body as string)).toMatchObject({
      captchaToken: 'captcha-test-token',
    });
    expect(screen.getByLabelText('Nome *')).toHaveValue('');
  });

  it('never confirms registration from a non-success HTTP response', async () => {
    const fetchMock = vi.fn().mockResolvedValueOnce(websiteResponse(CREATED_CONTACT, false));
    vi.stubGlobal('fetch', fetchMock);

    render(
      <NextIntlClientProvider locale="pt-BR" messages={ptBRMessages}>
        <ContactForm />
      </NextIntlClientProvider>,
    );

    fireEvent.change(screen.getByLabelText('Nome *'), { target: { value: 'Ana Contadora' } });
    fireEvent.change(screen.getByLabelText('E-mail profissional *'), {
      target: { value: 'ana@escritorio.example' },
    });
    fireEvent.change(screen.getByLabelText('Escritório *'), {
      target: { value: 'Escritório Aurora' },
    });
    fireEvent.change(screen.getByLabelText('Telefone / WhatsApp *'), {
      target: { value: '81999999999' },
    });
    fireEvent.change(screen.getByLabelText('Mensagem *'), {
      target: { value: 'Quero automatizar as consultas fiscais do escritório.' },
    });

    fireEvent.click(screen.getByRole('button', { name: 'Confirmar que não sou robô' }));
    fireEvent.click(screen.getByRole('button', { name: 'Enviar mensagem' }));

    await screen.findByText('Não foi possível enviar. Verifique sua conexão e tente novamente.');
    expect(screen.queryByText(/Contato registrado/u)).not.toBeInTheDocument();
    expect(screen.getByLabelText('Nome *')).toHaveValue('Ana Contadora');
  });
});
