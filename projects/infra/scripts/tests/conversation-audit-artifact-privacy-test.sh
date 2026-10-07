#!/usr/bin/env bash

set -Eeuo pipefail

REPOSITORY_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
SCANNER="$REPOSITORY_ROOT/frontend/app/scripts/scan-playwright-artifacts.mjs"
FIXTURE_ROOT="$(mktemp -d)"

cleanup() {
    rm -rf -- "$FIXTURE_ROOT"
}
trap cleanup EXIT

fail() {
    echo "FAIL: $*" >&2
    exit 1
}

command -v node >/dev/null 2>&1 || fail "node is required"
[ -f "$SCANNER" ] || fail "artifact privacy scanner is missing"

run_scanner() {
    node "$SCANNER" "$@" > "$FIXTURE_ROOT/scanner.stdout" 2> "$FIXTURE_ROOT/scanner.stderr"
}

expect_pass() {
    if ! run_scanner "$@"; then
        fail "scanner rejected a safe artifact fixture"
    fi
    grep -Fq 'Playwright artifact privacy scan passed' "$FIXTURE_ROOT/scanner.stdout" \
        || fail "scanner did not emit its bounded success message"
}

expect_deny() {
    local expected_class="$1"
    shift
    if run_scanner "$@"; then
        fail "scanner accepted a forbidden artifact fixture: $expected_class"
    fi
    grep -Fq "DENY [$expected_class]" "$FIXTURE_ROOT/scanner.stderr" \
        || fail "scanner did not report the expected finding class: $expected_class"
}

SAFE_REPORT="$FIXTURE_ROOT/safe-report"
mkdir -p "$SAFE_REPORT/nested"
printf '%s\n' '<html><body>Audit report: no attachments recorded.</body></html>' \
    > "$SAFE_REPORT/index.html"
printf '%s\n' '{"status":"passed","tests":3}' > "$SAFE_REPORT/nested/report.json"
expect_pass "$SAFE_REPORT"

expect_deny missing-directory "$FIXTURE_ROOT/missing-report"
mkdir "$FIXTURE_ROOT/empty-report"
expect_deny empty-directory "$FIXTURE_ROOT/empty-report"

mkdir "$FIXTURE_ROOT/symlink-report"
printf '%s\n' safe > "$FIXTURE_ROOT/symlink-target.txt"
ln -s "$FIXTURE_ROOT/symlink-target.txt" "$FIXTURE_ROOT/symlink-report/result.txt"
expect_deny symlink "$FIXTURE_ROOT/symlink-report"

for forbidden_contract in \
    'media:screenshot.png' \
    'trace:trace.log' \
    'archive:results.zip' \
    'storage-state:storage-state.json'; do
    finding_class="${forbidden_contract%%:*}"
    artifact_name="${forbidden_contract#*:}"
    fixture="$FIXTURE_ROOT/$finding_class-report"
    mkdir "$fixture"
    printf '%s\n' forbidden > "$fixture/$artifact_name"
    expect_deny "$finding_class" "$fixture"
done

mkdir "$FIXTURE_ROOT/storage-content-report"
printf '%s\n' '{"cookies":[],"origins":[]}' \
    > "$FIXTURE_ROOT/storage-content-report/result.json"
expect_deny storage-state "$FIXTURE_ROOT/storage-content-report"

mkdir "$FIXTURE_ROOT/partial-storage-content-report"
printf '%s\n' '{"cookies":[{"name":"session","value":"redacted"}]}' \
    > "$FIXTURE_ROOT/partial-storage-content-report/result.json"
expect_deny storage-state "$FIXTURE_ROOT/partial-storage-content-report"

mkdir "$FIXTURE_ROOT/inline-media-report"
printf '%s\n' '<img src="data:image/png;base64,c3ludGhldGlj">' \
    > "$FIXTURE_ROOT/inline-media-report/result.html"
expect_deny media "$FIXTURE_ROOT/inline-media-report"

mkdir "$FIXTURE_ROOT/binary-report"
printf '\000\001\002' > "$FIXTURE_ROOT/binary-report/result.dat"
expect_deny binary "$FIXTURE_ROOT/binary-report"

mkdir "$FIXTURE_ROOT/credential-report"
printf '%s\n' 'authorization: Bearer eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiJhdWRpdCJ9.c2lnbmF0dXJlMTIzNDU2' \
    > "$FIXTURE_ROOT/credential-report/result.txt"
expect_deny credential "$FIXTURE_ROOT/credential-report"

declare -a pii_contracts=(
    'pii-email:auditor@example.org'
    'pii-cpf:529.982.247-25'
    'pii-cnpj:57.092.807/0001-19'
    'pii-phone:+55 (11) 98765-4321'
    'pii-payment-card:4111 1111 1111 1111'
    'pii-uuid:123e4567-e89b-12d3-a456-426614174000'
)
for pii_contract in "${pii_contracts[@]}"; do
    finding_class="${pii_contract%%:*}"
    pii_value="${pii_contract#*:}"
    fixture="$FIXTURE_ROOT/$finding_class-report"
    mkdir "$fixture"
    printf '%s\n' "$pii_value" > "$fixture/result.txt"
    expect_deny "$finding_class" "$fixture"
done

mkdir "$FIXTURE_ROOT/pii-phone-e164-without-plus-report"
printf '%s\n' '5511987654321' \
    > "$FIXTURE_ROOT/pii-phone-e164-without-plus-report/result.txt"
expect_deny pii-phone "$FIXTURE_ROOT/pii-phone-e164-without-plus-report"

mkdir "$FIXTURE_ROOT/pii-payment-card-assignment-report"
printf '%s\n' 'cardNumber=4111111111111111' \
    > "$FIXTURE_ROOT/pii-payment-card-assignment-report/result.txt"
expect_deny pii-payment-card "$FIXTURE_ROOT/pii-payment-card-assignment-report"

mkdir "$FIXTURE_ROOT/technical-number-report"
printf '%s\n' '{"durationNanoseconds":1099511627776,"sequence":8820915}' \
    > "$FIXTURE_ROOT/technical-number-report/result.json"
expect_pass "$FIXTURE_ROOT/technical-number-report"

EXACT_VALUE='owner-only-exact-value-7f36d14b'
EXACT_VALUES_FILE="$FIXTURE_ROOT/exact-values.txt"
umask 077
printf '%s\n' "$EXACT_VALUE" > "$EXACT_VALUES_FILE"
mkdir "$FIXTURE_ROOT/exact-value-report"
printf '%s\n' "result=$EXACT_VALUE" > "$FIXTURE_ROOT/exact-value-report/result.txt"
expect_deny exact-value "$FIXTURE_ROOT/exact-value-report" "$EXACT_VALUES_FILE"
if grep -Fq "$EXACT_VALUE" "$FIXTURE_ROOT/scanner.stdout" "$FIXTURE_ROOT/scanner.stderr"; then
    fail "scanner disclosed an exact denylisted value"
fi

if PLAYWRIGHT_ARTIFACT_EXACT_VALUES_FILE="$EXACT_VALUES_FILE" \
    run_scanner "$FIXTURE_ROOT/exact-value-report"; then
    fail "environment-provided exact denylist was ignored"
fi
grep -Fq 'DENY [exact-value]' "$FIXTURE_ROOT/scanner.stderr" \
    || fail "environment-provided exact denylist did not classify the match"
if grep -Fq "$EXACT_VALUE" "$FIXTURE_ROOT/scanner.stdout" "$FIXTURE_ROOT/scanner.stderr"; then
    fail "environment-provided exact denylist value appeared in diagnostics"
fi

chmod 0644 "$EXACT_VALUES_FILE"
expect_deny exact-values-permissions "$SAFE_REPORT" "$EXACT_VALUES_FILE"

extract_workflow_step() {
    local workflow="$1"
    local step_name="$2"
    awk -v heading="      - name: $step_name" '
        $0 == heading { capture = 1; print; next }
        capture && /^      - name: / { exit }
        capture { print }
    ' "$workflow"
}

for workflow in \
    "$REPOSITORY_ROOT/" \
    "$REPOSITORY_ROOT/"; do
    grep -Fq 'id: frontend-install' "$workflow" \
        || fail "frontend dependency step is not addressable in workflow: $workflow"
    grep -Fq 'npx playwright install --with-deps chromium' "$workflow" \
        || fail "hermetic Chromium installation is not selected in workflow: $workflow"
    browser_step="$(extract_workflow_step "$workflow" 'Run canonical Audit browser gate without backend-real fallback')"
    scanner_step="$(extract_workflow_step "$workflow" 'Scan hermetic Audit browser report for secrets and PII')"
    upload_step="$(extract_workflow_step "$workflow" 'Upload hermetic Audit browser report')"
    grep -Fq 'id: audit-browser' <<<"$browser_step" \
        || fail "Audit browser step is not addressable in workflow: $workflow"
    grep -Fq 'if: ${{ always() && steps.frontend-install.outcome == '\''success'\'' }}' \
        <<<"$browser_step" \
        || fail "Audit browser is not selected after earlier independent gate failures: $workflow"
    grep -Fq 'npm run test:e2e -- e2e/chatbot/inbox.spec.ts' <<<"$browser_step" \
        || fail "canonical Audit browser spec is not selected in workflow: $workflow"
    grep -Fq 'PLAYWRIGHT_BROWSER_CHANNEL: ""' <<<"$browser_step" \
        || fail "Audit browser workflow may fall back to a host browser: $workflow"
    grep -Fq 'id: audit-artifact-privacy' <<<"$scanner_step" \
        || fail "Audit report scanner is not addressable in workflow: $workflow"
    grep -Fq 'if: ${{ always() && steps.frontend-install.outcome == '\''success'\'' }}' \
        <<<"$scanner_step" \
        || fail "Audit report scanner may be skipped after a RED browser gate: $workflow"
    grep -Fq 'npm run test:artifacts:pii -- playwright-report' <<<"$scanner_step" \
        || fail "Audit report privacy scanner is not selected in workflow: $workflow"
    grep -Fq 'if: ${{ always() && steps.audit-artifact-privacy.outcome == '\''success'\'' }}' \
        <<<"$upload_step" \
        || fail "Audit report upload is not conditioned on the privacy scanner: $workflow"
done

echo "Conversation Audit Playwright artifact privacy contract validation passed."
