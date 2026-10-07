import { fireEvent, render, screen, waitFor } from '@testing-library/react';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { RecaptchaCheckbox } from '../RecaptchaCheckbox';

vi.mock('next/script', () => ({
  default: ({ onReady, onError }: { onReady(): void; onError(): void }) => (
    <>
      <button type="button" onClick={onReady}>
        Carregar script
      </button>
      <button type="button" onClick={onError}>
        Falhar script
      </button>
    </>
  ),
}));

describe('RecaptchaCheckbox', () => {
  const onTokenChange = vi.fn();
  const onUnavailable = vi.fn();
  const reset = vi.fn();
  let callbacks: {
    callback(token: string): void;
    'expired-callback'(): void;
    'error-callback'(): void;
  };

  beforeEach(() => {
    onTokenChange.mockReset();
    onUnavailable.mockReset();
    reset.mockReset();
    vi.stubEnv('NEXT_PUBLIC_RECAPTCHA_SITE_KEY', 'public-test-key');
    window.grecaptcha = {
      ready: (callback) => callback(),
      render: (_container, parameters) => {
        callbacks = parameters;
        return 7;
      },
      reset,
    };
  });

  afterEach(() => {
    delete window.grecaptcha;
    vi.unstubAllEnvs();
  });

  it('publishes, expires, and resets only the ephemeral token', async () => {
    const { rerender } = render(
      <RecaptchaCheckbox
        instruction="Confirme o desafio"
        unavailableMessage="Indisponível"
        onTokenChange={onTokenChange}
        onUnavailable={onUnavailable}
        resetSignal={0}
      />,
    );

    fireEvent.click(screen.getByRole('button', { name: 'Carregar script' }));
    callbacks.callback('ephemeral-token');
    expect(onTokenChange).toHaveBeenLastCalledWith('ephemeral-token');

    callbacks['expired-callback']();
    expect(onTokenChange).toHaveBeenLastCalledWith(null);

    rerender(
      <RecaptchaCheckbox
        instruction="Confirme o desafio"
        unavailableMessage="Indisponível"
        onTokenChange={onTokenChange}
        onUnavailable={onUnavailable}
        resetSignal={1}
      />,
    );
    await waitFor(() => expect(reset).toHaveBeenCalledWith(7));
  });

  it('fails closed when the public site key is absent', async () => {
    vi.stubEnv('NEXT_PUBLIC_RECAPTCHA_SITE_KEY', '');

    render(
      <RecaptchaCheckbox
        instruction="Confirme o desafio"
        unavailableMessage="Indisponível"
        onTokenChange={onTokenChange}
        onUnavailable={onUnavailable}
        resetSignal={0}
      />,
    );

    expect(screen.queryByRole('button', { name: 'Carregar script' })).not.toBeInTheDocument();
    expect(screen.getByText('Indisponível')).toHaveAttribute('aria-live', 'polite');
    await waitFor(() => expect(onUnavailable).toHaveBeenCalledOnce());
  });
});
