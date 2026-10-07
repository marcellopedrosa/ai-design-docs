#!/usr/bin/env bash

set -uo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
validator="$repo_root/infra/scripts/validate-quality-gates.sh"
fixture_root="$(mktemp -d /tmp/quality-gate-test.XXXXXX)"
failures=0

cleanup() {
  if [[ -n "${fixture_root:-}" && "$fixture_root" == /tmp/quality-gate-test.* ]]; then
    rm -rf -- "$fixture_root"
  fi
}
trap cleanup EXIT

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  failures=$((failures + 1))
}

assert_exit() {
  local expected="$1"
  local label="$2"
  shift 2
  local output_file="$fixture_root/output.txt"
  "$@" >"$output_file" 2>&1
  local actual=$?
  if [[ "$actual" -ne "$expected" ]]; then
    printf 'FAIL: %s expected exit %s, got %s\n' "$label" "$expected" "$actual" >&2
    sed -n '1,120p' "$output_file" >&2
    failures=$((failures + 1))
  fi
}

mkdir -p "$fixture_root/infra/scripts/tests" "$fixture_root/backend" \
  "$fixture_root/frontend/app/src" "$fixture_root/website" "$fixture_root/docs" \
  "$fixture_root/harness/tooling/validators/project"

printf '#!/usr/bin/env bash\nexit 0\n' > "$fixture_root/infra/scripts/validate-docs.sh"
printf '#!/usr/bin/env bash\nexit 0\n' > "$fixture_root/backend/app/mvnw"
printf '#!/usr/bin/env bash\nexit 0\n' > "$fixture_root/infra/scripts/tests/validate-quality-gates-test.sh"
cat > "$fixture_root/infra/scripts/validate-quality-metrics.mjs" <<'NODE'
const args = process.argv.slice(2);
const branchIndex = args.indexOf('--branch-name');
const branch = branchIndex >= 0 ? args[branchIndex + 1] : '';
const valid = branch !== '' && branch !== 'main';
if (args.includes('--delivery') && !valid) {
  console.log('QUALITY_METRICS_RESULT=FAIL violations=1 blocked=0');
  process.exitCode = 1;
} else {
  console.log('QUALITY_METRICS_RESULT=PASS violations=0 blocked=0');
}
NODE
cat > "$fixture_root/infra/scripts/validate-plan-granularity.mjs" <<'NODE'
console.log('PLAN_GRANULARITY_RESULT=PASS violations=0 blocked=0');
NODE
for test_name in validate-quality-metrics validate-plan-granularity validate-quality-policy; do
  printf "import test from 'node:test';\ntest('fixture', () => {});\n" \
    > "$fixture_root/harness/tooling/validators/${test_name}.test.mjs"
done
printf '# Fixture docs\n' > "$fixture_root/docs/README.md"
printf 'export const value = 1;\n' > "$fixture_root/frontend/app/src/example.ts"
printf '#!/usr/bin/env bash\nexit 0\n' > "$fixture_root/infra/scripts/example.sh"
chmod +x "$fixture_root/infra/scripts/validate-docs.sh" "$fixture_root/backend/app/mvnw"

printf '%s\n' \
  '<project>' \
  '<artifactId>jacoco-maven-plugin</artifactId>' \
  '<goal>check</goal>' \
  '</project>' > "$fixture_root/backend/app/pom.xml"

for package_name in frontend website; do
  printf '%s\n' \
    '{"scripts":{"test":"vitest run","test:coverage":"vitest run --coverage","lint":"eslint .","typecheck":"tsc --noEmit","format:check":"prettier --check .","build":"next build","test:e2e":"playwright test"}}' \
    > "$fixture_root/$package_name/package.json"
  printf 'export default { test: { coverage: { thresholds: {} } } };\n' \
    > "$fixture_root/$package_name/vitest.config.ts"
done

assert_exit 0 'help' "$validator" --help
assert_exit 0 'docs PR dry-run' "$validator" --root "$fixture_root" --scope docs --level pr --target docs/README.md --dry-run
grep -Fq 'QUALITY_GATE_RESULT=PASS' "$fixture_root/output.txt" || fail 'docs PR did not emit PASS'
grep -Fq 'validate-plan-granularity.mjs' "$fixture_root/output.txt" || fail 'docs PR omitted plan granularity command'

assert_exit 0 'all PR dry-run' "$validator" --root "$fixture_root" --scope all --level pr --target frontend/app/src/example.ts --dry-run
grep -Fq 'npm run test:coverage' "$fixture_root/output.txt" || fail 'all PR omitted node coverage command'
grep -Fq './mvnw -B clean verify' "$fixture_root/output.txt" || fail 'all PR omitted clean backend verify command'
grep -Fq 'validate-quality-metrics.mjs' "$fixture_root/output.txt" || fail 'all PR omitted quality metrics command'

printf 'synthetic=true\n' > "$fixture_root/frontend/app/.env.local"
assert_exit 1 'local env blocks build' "$validator" --root "$fixture_root" --scope frontend --level pr --target frontend/app/src/example.ts --dry-run
grep -Fq 'QUALITY_GATE_RESULT=BLOCKED' "$fixture_root/output.txt" || fail 'local environment file did not block build'
rm -f -- "$fixture_root/frontend/app/.env.local"

assert_exit 2 'focused selector is mandatory' "$validator" --root "$fixture_root" --scope backend --level focused --dry-run
assert_exit 2 'unknown scope is rejected' "$validator" --root "$fixture_root" --scope unknown --level pr --dry-run

printf '<project/>\n' > "$fixture_root/backend/app/pom.xml"
assert_exit 1 'missing backend coverage blocks' "$validator" --root "$fixture_root" --scope backend --level pr --target backend/app/example.java --dry-run
grep -Fq 'QUALITY_GATE_RESULT=BLOCKED' "$fixture_root/output.txt" || fail 'missing backend coverage did not emit BLOCKED'

assert_exit 2 'PR metrics require targets' "$validator" --root "$fixture_root" --scope infra --level pr --dry-run
assert_exit 1 'protected delivery branch fails' "$validator" --root "$fixture_root" --scope infra --level pr --target infra/scripts/example.sh --delivery --branch-name main
grep -Fq 'QUALITY_GATE_RESULT=FAIL' "$fixture_root/output.txt" || fail 'invalid delivery branch did not fail'
assert_exit 0 'valid docs delivery passes' "$validator" --root "$fixture_root" --scope docs --level pr --target docs/README.md --delivery --branch-name feat/tp-00073-outbound-keyring-generator
grep -Fq 'QUALITY_GATE_RESULT=PASS' "$fixture_root/output.txt" || fail 'valid docs delivery did not pass'

if grep -Eq '(^|[[:space:]])git[[:space:]]+(diff|status|show|log|ls-files)' "$validator"; then
  fail 'validator contains a Git discovery command'
fi

if ((failures > 0)); then
  printf 'validate-quality-gates contract tests failed: %d\n' "$failures" >&2
  exit 1
fi
# Preserves the original 7 scenarios and adds metric, granularity and delivery cases.
printf 'validate-quality-gates contract tests passed: 10 scenarios.\n'
