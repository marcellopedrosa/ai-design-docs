# Scaffold portátil — enforcement de Conventional Commit por worktree

Este é um exemplo de enforcement, não uma regra do harness. Antes de copiá-lo, o
projeto adotante deve aceitar e registrar a convenção abaixo — ou substituí-la por
outra equivalente — no ADR-0000, nos adaptadores e na automação local.

O exemplo usa a branch `X.Y.Z-{docs,feat,fix}-short-description` e a mensagem
`<type>(X.Y.Z): <description>`.

## `.githooks/commit-msg`

```bash
#!/usr/bin/env bash
set -euo pipefail
message_file="${1:?commit-msg requires the path to the commit message}"
repository_root="$(git rev-parse --show-toplevel)"
exec "$repository_root/infra/scripts/validate-commit-message.sh" "$message_file"
```

## `infra/scripts/install-git-hooks.sh`

```bash
#!/usr/bin/env bash
set -euo pipefail
repository_root="$(git rev-parse --show-toplevel)"
git -C "$repository_root" config --local core.hooksPath .githooks
```

## `infra/scripts/validate-commit-message.sh`

```bash
#!/usr/bin/env bash
set -euo pipefail
message_file="${1:-}"
[[ -n "$message_file" && -f "$message_file" ]] || exit 2
branch="$(git branch --show-current)"
branch_pattern='^([0-9]+\.[0-9]+\.[0-9]+)-(docs|feat|fix)-[a-z0-9]+(-[a-z0-9]+)*$'
[[ "$branch" =~ $branch_pattern ]] || exit 1
coordinate="${BASH_REMATCH[1]}"
branch_type="${BASH_REMATCH[2]}"
subject="$(head -n 1 "$message_file")"
message_pattern='^(feat|fix|docs|test|refactor|build|chore)\(([0-9]+\.[0-9]+\.[0-9]+)\): .+$'
[[ "$subject" =~ $message_pattern ]] || exit 1
commit_type="${BASH_REMATCH[1]}"
commit_coordinate="${BASH_REMATCH[2]}"
[[ "$commit_coordinate" == "$coordinate" ]] || exit 1
[[ ! "$commit_type" =~ ^(docs|feat|fix)$ || "$commit_type" == "$branch_type" ]] || exit 1
```

Versione também testes herméticos para branch válida, escopo/tipo divergentes e
detached HEAD. `--no-verify` é tecnicamente possível; a política local deve tratá-lo
como proibido e usar CI ou proteção de servidor se precisar bloquear clientes
adversariais.
