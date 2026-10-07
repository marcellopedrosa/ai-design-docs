'use client';

import Script from 'next/script';
import { useCallback, useEffect, useRef, useState } from 'react';

interface RecaptchaApi {
  ready(callback: () => void): void;
  render(
    container: HTMLElement,
    parameters: {
      sitekey: string;
      theme: 'light';
      size: 'normal';
      callback(token: string): void;
      'expired-callback'(): void;
      'error-callback'(): void;
    },
  ): number;
  reset(widgetId?: number): void;
}

declare global {
  interface Window {
    grecaptcha?: RecaptchaApi;
  }
}

interface RecaptchaCheckboxProps {
  instruction: string;
  unavailableMessage: string;
  onTokenChange(token: string | null): void;
  onUnavailable(): void;
  resetSignal: number;
}

export function RecaptchaCheckbox({
  instruction,
  unavailableMessage,
  onTokenChange,
  onUnavailable,
  resetSignal,
}: RecaptchaCheckboxProps) {
  const siteKey = process.env.NEXT_PUBLIC_RECAPTCHA_SITE_KEY?.trim() ?? '';
  const containerRef = useRef<HTMLDivElement>(null);
  const widgetId = useRef<number | null>(null);
  const [loadFailed, setLoadFailed] = useState(!siteKey);

  const renderWidget = useCallback(() => {
    if (!siteKey || !containerRef.current || widgetId.current !== null) return;

    window.grecaptcha?.ready(() => {
      if (!containerRef.current || !window.grecaptcha || widgetId.current !== null) return;
      widgetId.current = window.grecaptcha.render(containerRef.current, {
        sitekey: siteKey,
        theme: 'light',
        size: 'normal',
        callback: (token) => {
          setLoadFailed(false);
          onTokenChange(token);
        },
        'expired-callback': () => onTokenChange(null),
        'error-callback': () => {
          onTokenChange(null);
          setLoadFailed(true);
          onUnavailable();
        },
      });
    });
  }, [onTokenChange, onUnavailable, siteKey]);

  useEffect(() => {
    if (!siteKey) onUnavailable();
  }, [onUnavailable, siteKey]);

  useEffect(() => {
    if (widgetId.current !== null) window.grecaptcha?.reset(widgetId.current);
  }, [resetSignal]);

  return (
    <div className="recaptcha-field">
      {siteKey && (
        <Script
          id="google-recaptcha-v2"
          src="https://www.google.com/recaptcha/api.js?render=explicit&hl=pt-BR"
          strategy="afterInteractive"
          onReady={renderWidget}
          onError={() => {
            setLoadFailed(true);
            onUnavailable();
          }}
        />
      )}
      <div className="recaptcha-field__widget" ref={containerRef} />
      <p
        id="contact-captcha-instruction"
        className={loadFailed ? 'recaptcha-field__error' : undefined}
        aria-live="polite"
      >
        {loadFailed ? unavailableMessage : instruction}
      </p>
      <p className="recaptcha-field__legal">
        Este site é protegido pelo reCAPTCHA. Aplicam-se a{' '}
        <a href="https://policies.google.com/privacy" target="_blank" rel="noreferrer">
          Política de Privacidade
        </a>{' '}
        e os{' '}
        <a href="https://policies.google.com/terms" target="_blank" rel="noreferrer">
          Termos de Serviço
        </a>{' '}
        do Google.
      </p>
    </div>
  );
}
