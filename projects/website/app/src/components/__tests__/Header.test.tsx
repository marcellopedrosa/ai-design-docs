import { render, within } from '@testing-library/react';
import { NextIntlClientProvider } from 'next-intl';
import { describe, expect, it } from 'vitest';
import ptBRMessages from '@/i18n/messages/pt-BR.json';
import { Header } from '../Header';

describe('Header', () => {
  it('não exibe a ação Entrar no topbar', () => {
    const { container } = render(
      <NextIntlClientProvider locale="pt-BR" messages={ptBRMessages}>
        <Header loginUrl="https://app.example.com/login" />
      </NextIntlClientProvider>,
    );

    const actions = container.querySelector<HTMLElement>('.site-header__actions');

    expect(actions).not.toBeNull();
    expect(within(actions!).queryByRole('link', { name: 'Entrar' })).not.toBeInTheDocument();
    expect(within(actions!).getByRole('link', { name: 'Conhecer os planos' })).toHaveAttribute(
      'href',
      '#planos',
    );
  });
});
