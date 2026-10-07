#!/usr/bin/env bash
set -euo pipefail

repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
validator="$repository_root/infra/scripts/validate-commit-message.sh"
fixture_root="$(mktemp -d /tmp/commit-message-hook-test.XXXXXX)"
trap 'rm -rf "$fixture_root"' EXIT

git -C "$fixture_root" init --quiet
git -C "$fixture_root" config user.name fixture
git -C "$fixture_root" config user.email fixture@example.invalid
git -C "$fixture_root" checkout --quiet -b feat/tp-00073-outbound-keyring-generator

assert_exit() {
  local expected="$1"
  shift
  set +e
  "$@" >/dev/null 2>&1
  local actual=$?
  set -e
  [[ "$actual" == "$expected" ]] || {
    echo "expected exit $expected, got $actual: $*" >&2
    exit 1
  }
}

printf 'feat(tp-00073): valida mensagem\n' > "$fixture_root/valid"
printf 'Mensagem livre de manutenção\n' > "$fixture_root/free-form"
printf '   \n' > "$fixture_root/blank"

(
  cd "$fixture_root"
  assert_exit 0 "$validator" valid
  assert_exit 0 "$validator" free-form
  assert_exit 1 "$validator" blank
  assert_exit 2 "$validator" missing
  mkdir -p .githooks infra/scripts
  cp "$repository_root/.githooks/commit-msg" .githooks/commit-msg
  cp "$validator" infra/scripts/validate-commit-message.sh
  chmod +x .githooks/commit-msg infra/scripts/validate-commit-message.sh
  git config core.hooksPath .githooks
  touch committed
  git add committed
  assert_exit 1 git commit -m '   '
  assert_exit 0 git commit -m 'feat(tp-00073): hook permite branch de trabalho'
  git checkout --quiet -b main
  assert_exit 1 "$validator" valid
  git checkout --quiet feat/tp-00073-outbound-keyring-generator
  git checkout --quiet --detach
  assert_exit 1 "$validator" valid
)

echo "validate-commit-message tests passed: 9 scenarios."
