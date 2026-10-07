interface SectionHeadingProps {
  id?: string;
  eyebrow: string;
  title: string;
  description?: string;
  align?: 'left' | 'center';
  inverse?: boolean;
}

export function SectionHeading({
  id,
  eyebrow,
  title,
  description,
  align = 'left',
  inverse = false,
}: SectionHeadingProps) {
  return (
    <div
      className={`section-heading section-heading--${align}${inverse ? ' section-heading--inverse' : ''}`}
    >
      <p className="eyebrow">{eyebrow}</p>
      <h2 id={id}>{title}</h2>
      {description && <p className="section-heading__description">{description}</p>}
    </div>
  );
}
