// XSS confirmado via dangerouslySetInnerHTML sem sanitização
export function UnsafeProfile({ rawContent }: { rawContent: string }) {
  return (
    <div dangerouslySetInnerHTML={{ __html: rawContent }} />
  );
}
