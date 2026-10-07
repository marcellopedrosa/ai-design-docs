'use client';

import { FormEvent, useCallback, useRef, useState } from 'react';
import { ArrowRight, LoaderCircle, Mail } from 'lucide-react';
import { useTranslations } from 'next-intl';
import {
  contactPayloadSchema,
  contactResponseSchema,
  formatContactPhone,
  type ContactPayload,
  type ContactResponseCode,
} from '@/lib/contact';
import { RecaptchaCheckbox } from './RecaptchaCheckbox';

interface ContactFormProps {
  contactEmail?: string;
  headingLevel?: 2 | 3;
}

type FieldName = keyof ContactPayload;

const INITIAL_FORM: ContactPayload = {
  name: '',
  email: '',
  company: '',
  phone: '',
  plan: 'NOT_SURE',
  message: '',
  website: '',
};

interface SubmissionAttempt {
  idempotencyKey: string;
  serializedPayload: string;
}

function createIdempotencyKey(): string {
  const cryptoApi = globalThis.crypto;
  if (typeof cryptoApi?.randomUUID === 'function') return cryptoApi.randomUUID();

  const bytes = new Uint8Array(16);
  cryptoApi.getRandomValues(bytes);
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  const hex = Array.from(bytes, (byte) => byte.toString(16).padStart(2, '0')).join('');
  return `${hex.slice(0, 8)}-${hex.slice(8, 12)}-${hex.slice(12, 16)}-${hex.slice(16, 20)}-${hex.slice(20)}`;
}

export function ContactForm({ contactEmail, headingLevel = 3 }: ContactFormProps) {
  const t = useTranslations('marketing.contact');
  const FormHeading = `h${headingLevel}` as const;
  const [form, setForm] = useState<ContactPayload>(INITIAL_FORM);
  const [fieldErrors, setFieldErrors] = useState<Partial<Record<FieldName, boolean>>>({});
  const [status, setStatus] = useState<ContactResponseCode | 'UNKNOWN_ERROR' | null>(null);
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [captchaToken, setCaptchaToken] = useState<string | null>(null);
  const [captchaResetSignal, setCaptchaResetSignal] = useState(0);
  const submissionAttempt = useRef<SubmissionAttempt | null>(null);
  const handleCaptchaUnavailable = useCallback(() => setStatus('CAPTCHA_UNAVAILABLE'), []);

  const updateField = (field: FieldName, value: string) => {
    setForm((current) => ({ ...current, [field]: value }));
    setFieldErrors((current) => ({ ...current, [field]: false }));
    setStatus(null);
  };

  const handleSubmit = async (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    setStatus(null);

    const parsed = contactPayloadSchema.safeParse(form);
    if (!parsed.success) {
      const errors: Partial<Record<FieldName, boolean>> = {};
      parsed.error.issues.forEach((issue) => {
        const field = issue.path[0];
        if (typeof field === 'string') errors[field as FieldName] = true;
      });
      setFieldErrors(errors);
      setStatus('VALIDATION_ERROR');
      return;
    }
    if (!captchaToken) {
      setStatus('CAPTCHA_REQUIRED');
      return;
    }

    setIsSubmitting(true);
    try {
      const serializedPayload = JSON.stringify(parsed.data);
      if (submissionAttempt.current?.serializedPayload !== serializedPayload) {
        submissionAttempt.current = {
          idempotencyKey: createIdempotencyKey(),
          serializedPayload,
        };
      }

      const response = await fetch('/api/contact', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Idempotency-Key': submissionAttempt.current.idempotencyKey,
        },
        body: JSON.stringify({ ...parsed.data, captchaToken }),
      });
      const result = contactResponseSchema.safeParse(await response.json());
      if (!result.success) {
        setStatus('UNKNOWN_ERROR');
        return;
      }

      if (!response.ok && result.data.code === 'SUCCESS') {
        setStatus('UNKNOWN_ERROR');
        return;
      }

      setStatus(result.data.code);
      if (result.data.code === 'SUCCESS') {
        setForm(INITIAL_FORM);
        setFieldErrors({});
        submissionAttempt.current = null;
      }
    } catch {
      setStatus('UNKNOWN_ERROR');
    } finally {
      setIsSubmitting(false);
      setCaptchaToken(null);
      setCaptchaResetSignal((current) => current + 1);
    }
  };

  const errorFor = (field: FieldName) => (fieldErrors[field] ? t('fieldError') : undefined);

  return (
    <div className="contact-card">
      <div className="contact-card__header">
        <div>
          <FormHeading>{t('formTitle')}</FormHeading>
          <p>{t('formDescription')}</p>
        </div>
        <span aria-hidden="true">
          <Mail size={21} />
        </span>
      </div>

      <form onSubmit={handleSubmit} noValidate>
        <div className="form-grid">
          <div className="form-field">
            <label htmlFor="contact-name">{t('name')}</label>
            <input
              id="contact-name"
              name="name"
              autoComplete="name"
              value={form.name}
              onChange={(event) => updateField('name', event.target.value)}
              placeholder={t('namePlaceholder')}
              aria-invalid={Boolean(fieldErrors.name)}
              aria-describedby={fieldErrors.name ? 'contact-name-error' : undefined}
              required
            />
            {fieldErrors.name && <small id="contact-name-error">{errorFor('name')}</small>}
          </div>

          <div className="form-field">
            <label htmlFor="contact-email">{t('email')}</label>
            <input
              id="contact-email"
              name="email"
              type="email"
              autoComplete="email"
              value={form.email}
              onChange={(event) => updateField('email', event.target.value)}
              placeholder={t('emailPlaceholder')}
              aria-invalid={Boolean(fieldErrors.email)}
              aria-describedby={fieldErrors.email ? 'contact-email-error' : undefined}
              required
            />
            {fieldErrors.email && <small id="contact-email-error">{errorFor('email')}</small>}
          </div>

          <div className="form-field">
            <label htmlFor="contact-company">{t('company')}</label>
            <input
              id="contact-company"
              name="company"
              autoComplete="organization"
              value={form.company}
              onChange={(event) => updateField('company', event.target.value)}
              placeholder={t('companyPlaceholder')}
              aria-invalid={Boolean(fieldErrors.company)}
              aria-describedby={fieldErrors.company ? 'contact-company-error' : undefined}
              required
            />
            {fieldErrors.company && <small id="contact-company-error">{errorFor('company')}</small>}
          </div>

          <div className="form-field">
            <label htmlFor="contact-phone">{t('phone')}</label>
            <input
              id="contact-phone"
              name="phone"
              type="tel"
              autoComplete="tel"
              inputMode="numeric"
              value={form.phone}
              onChange={(event) => updateField('phone', formatContactPhone(event.target.value))}
              placeholder={t('phonePlaceholder')}
              maxLength={15}
              pattern="\(\d{2}\) \d{4,5}\.\d{4}"
              aria-invalid={Boolean(fieldErrors.phone)}
              aria-describedby={fieldErrors.phone ? 'contact-phone-error' : undefined}
              required
            />
            {fieldErrors.phone && <small id="contact-phone-error">{errorFor('phone')}</small>}
          </div>

          <div className="form-field form-field--full">
            <label htmlFor="contact-plan">{t('plan')}</label>
            <select
              id="contact-plan"
              name="plan"
              value={form.plan}
              onChange={(event) => updateField('plan', event.target.value)}
              aria-invalid={Boolean(fieldErrors.plan)}
              required
            >
              <option value="NOT_SURE">{t('planUnsure')}</option>
              <option value="START">{t('planStart')}</option>
              <option value="BUSINESS">{t('planBusiness')}</option>
              <option value="PREMIUM">{t('planPremium')}</option>
            </select>
          </div>

          <div className="form-field form-field--full">
            <label htmlFor="contact-message">{t('message')}</label>
            <textarea
              id="contact-message"
              name="message"
              rows={5}
              value={form.message}
              onChange={(event) => updateField('message', event.target.value)}
              placeholder={t('messagePlaceholder')}
              aria-invalid={Boolean(fieldErrors.message)}
              aria-describedby={fieldErrors.message ? 'contact-message-error' : undefined}
              required
            />
            {fieldErrors.message && <small id="contact-message-error">{errorFor('message')}</small>}
          </div>

          <div className="honeypot" aria-hidden="true">
            <label htmlFor="contact-website">Website</label>
            <input
              id="contact-website"
              name="website"
              tabIndex={-1}
              autoComplete="off"
              value={form.website}
              onChange={(event) => updateField('website', event.target.value)}
            />
          </div>

          <RecaptchaCheckbox
            instruction={t('captcha.instruction')}
            unavailableMessage={t('captcha.unavailable')}
            onTokenChange={setCaptchaToken}
            onUnavailable={handleCaptchaUnavailable}
            resetSignal={captchaResetSignal}
          />
        </div>

        <div className="contact-card__footer">
          <p>{t('privacy')}</p>
          <button
            className="button button--primary"
            type="submit"
            disabled={isSubmitting || !captchaToken}
            aria-describedby={!captchaToken ? 'contact-captcha-instruction' : undefined}
          >
            {isSubmitting ? (
              <>
                <LoaderCircle className="spin" size={18} aria-hidden="true" />
                {t('sending')}
              </>
            ) : (
              <>
                {t('submit')}
                <ArrowRight size={18} aria-hidden="true" />
              </>
            )}
          </button>
        </div>

        <div className="form-status" aria-live="polite" aria-atomic="true">
          {status && (
            <p className={`form-status--${status === 'SUCCESS' ? 'success' : 'error'}`}>
              {status === 'NOT_CONFIGURED' && contactEmail
                ? t('status.NOT_CONFIGURED_WITH_EMAIL')
                : t(`status.${status}`)}
            </p>
          )}
        </div>
      </form>

      {contactEmail && (
        <p className="contact-card__alternative">
          {t('alternative')} <a href={`mailto:${contactEmail}`}>{contactEmail}</a>
        </p>
      )}
    </div>
  );
}
