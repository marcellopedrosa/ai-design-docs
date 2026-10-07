'use client';

import { useCallback, useEffect, useRef, useState } from 'react';
import { ArrowUpRight, Menu, X } from 'lucide-react';
import { useTranslations } from 'next-intl';
import { BrandMark } from './BrandMark';

interface HeaderProps {
  loginUrl: string;
}

const NAV_ITEMS = [
  { key: 'who', href: '#quem-somos' },
  { key: 'clients', href: '#clientes' },
  { key: 'plans', href: '#planos' },
  { key: 'contact', href: '#contate' },
] as const;

export function Header({ loginUrl }: HeaderProps) {
  const t = useTranslations('marketing.nav');
  const [isOpen, setIsOpen] = useState(false);
  const toggleRef = useRef<HTMLButtonElement>(null);
  const panelRef = useRef<HTMLDivElement>(null);

  const closeMenu = useCallback((restoreFocus = false) => {
    setIsOpen(false);
    if (restoreFocus) requestAnimationFrame(() => toggleRef.current?.focus());
  }, []);

  const focusDestination = (href: string) => {
    closeMenu();
    requestAnimationFrame(() => document.querySelector<HTMLElement>(href)?.focus());
  };

  useEffect(() => {
    if (!isOpen) return;

    const panel = panelRef.current;
    const focusable = panel?.querySelectorAll<HTMLElement>('a, button:not([disabled])') ?? [];
    focusable[0]?.focus();

    const handleKeyDown = (event: KeyboardEvent) => {
      if (event.key === 'Escape') {
        event.preventDefault();
        closeMenu(true);
        return;
      }

      if (event.key !== 'Tab' || focusable.length === 0) return;
      const first = focusable[0];
      const last = focusable[focusable.length - 1];

      if (event.shiftKey && document.activeElement === first) {
        event.preventDefault();
        last.focus();
      } else if (!event.shiftKey && document.activeElement === last) {
        event.preventDefault();
        first.focus();
      }
    };

    const desktopViewport = window.matchMedia('(min-width: 1025px)');
    const handleViewportChange = (event: MediaQueryListEvent) => {
      if (event.matches) closeMenu();
    };

    document.addEventListener('keydown', handleKeyDown);
    desktopViewport.addEventListener('change', handleViewportChange);
    document.body.classList.add('menu-open');

    return () => {
      document.removeEventListener('keydown', handleKeyDown);
      desktopViewport.removeEventListener('change', handleViewportChange);
      document.body.classList.remove('menu-open');
    };
  }, [closeMenu, isOpen]);

  return (
    <header className="site-header">
      <div className="container site-header__inner">
        <a className="site-header__brand" href="#top" aria-label={t('home')}>
          <BrandMark />
        </a>

        <nav className="site-header__nav" aria-label={t('ariaLabel')}>
          {NAV_ITEMS.map((item) => (
            <a key={item.key} href={item.href}>
              {t(item.key)}
            </a>
          ))}
        </nav>

        <div className="site-header__actions">
          <a className="button button--primary button--compact" href="#planos">
            {t('cta')}
            <ArrowUpRight size={17} aria-hidden="true" />
          </a>
        </div>

        <button
          ref={toggleRef}
          className="site-header__menu-button"
          type="button"
          aria-expanded={isOpen}
          aria-controls="mobile-menu"
          aria-label={isOpen ? t('close') : t('open')}
          onClick={() => setIsOpen((current) => !current)}
        >
          {isOpen ? <X aria-hidden="true" /> : <Menu aria-hidden="true" />}
        </button>
      </div>

      {isOpen && (
        <>
          <button
            className="mobile-menu__backdrop"
            type="button"
            tabIndex={-1}
            aria-label={t('close')}
            onClick={() => closeMenu(true)}
          />
          <div
            ref={panelRef}
            id="mobile-menu"
            className="mobile-menu"
            role="dialog"
            aria-modal="true"
            aria-label={t('mobileLabel')}
          >
            <nav aria-label={t('ariaLabel')}>
              {NAV_ITEMS.map((item) => (
                <a key={item.key} href={item.href} onClick={() => focusDestination(item.href)}>
                  {t(item.key)}
                </a>
              ))}
            </nav>
            <div className="mobile-menu__actions">
              <a className="button button--secondary" href={loginUrl}>
                {t('login')}
              </a>
              <a
                className="button button--primary"
                href="#planos"
                onClick={() => focusDestination('#planos')}
              >
                {t('cta')}
                <ArrowUpRight size={18} aria-hidden="true" />
              </a>
            </div>
          </div>
        </>
      )}
    </header>
  );
}
