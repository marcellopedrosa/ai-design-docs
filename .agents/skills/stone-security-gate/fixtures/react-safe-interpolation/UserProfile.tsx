// Interpolação JSX segura padrão do React com escaping automático - NÃO é XSS
export function UserProfile({ user }: { user: { name: string; bio: string } }) {
  return (
    <div className="profile">
      <h1>{user.name}</h1>
      <p>{user.bio}</p>
    </div>
  );
}
