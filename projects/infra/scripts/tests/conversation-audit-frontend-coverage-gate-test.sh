#!/usr/bin/env bash

set -Eeuo pipefail

REPOSITORY_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
GATE="$REPOSITORY_ROOT/frontend/app/scripts/check-changed-lines-coverage.mjs"
TEST_ROOT="$(mktemp -d)"
trap 'rm -rf -- "$TEST_ROOT"' EXIT

fail() {
    echo "FAIL: $*" >&2
    exit 1
}

for command_name in find git node grep; do
    command -v "$command_name" >/dev/null 2>&1 \
        || fail "required command is unavailable: $command_name"
done
[ -f "$GATE" ] || fail "changed-lines coverage gate is missing"

mkdir -p "$TEST_ROOT/frontend/app/src/lib" "$TEST_ROOT/frontend/app/coverage"
mkdir -p "$TEST_ROOT/gate-tmp"
git -C "$TEST_ROOT" init -q
git -C "$TEST_ROOT" config user.name "Coverage Gate Test"
git -C "$TEST_ROOT" config user.email "coverage-gate@example.invalid"

cat > "$TEST_ROOT/frontend/app/src/lib/example.ts" <<'EOF'
export function value() {
  return 1;
}
EOF
git -C "$TEST_ROOT" add frontend/app/src/lib/example.ts
git -C "$TEST_ROOT" commit -qm "base"
BASE_SHA="$(git -C "$TEST_ROOT" rev-parse HEAD)"

cat > "$TEST_ROOT/frontend/app/src/lib/example.ts" <<'EOF'
export function value(flag: boolean) {
  if (flag) {
    return 2;
  }
  return 1;
}
EOF
git -C "$TEST_ROOT" add frontend/app/src/lib/example.ts
git -C "$TEST_ROOT" commit -qm "covered change"
HEAD_SHA="$(git -C "$TEST_ROOT" rev-parse HEAD)"
git -C "$TEST_ROOT" diff --unified=0 "$BASE_SHA" "$HEAD_SHA" > "$TEST_ROOT/change.diff"

cat > "$TEST_ROOT/frontend/app/coverage/lcov.info" <<'EOF'
TN:
SF:src/lib/example.ts
DA:1,1
DA:2,1
DA:3,1
DA:5,1
LF:4
LH:4
end_of_record
EOF

run_success() {
    local expected="$1"
    shift
    local output
    output="$(cd "$TEST_ROOT/frontend" && TMPDIR="$TEST_ROOT/gate-tmp" node "$GATE" "$@" 2>&1)" \
        || fail "expected success containing '$expected', got: $output"
    grep -Fq "$expected" <<< "$output" \
        || fail "success output did not contain '$expected': $output"
    [ -z "$(find "$TEST_ROOT/gate-tmp" -mindepth 1 -print -quit)" ] \
        || fail "changed-lines gate leaked a temporary file after success"
}

run_failure() {
    local expected="$1"
    shift
    local output
    if output="$(cd "$TEST_ROOT/frontend" && TMPDIR="$TEST_ROOT/gate-tmp" node "$GATE" "$@" 2>&1)"; then
        fail "expected failure containing '$expected', got success: $output"
    fi
    grep -Fq "$expected" <<< "$output" \
        || fail "failure output did not contain '$expected': $output"
    [ -z "$(find "$TEST_ROOT/gate-tmp" -mindepth 1 -print -quit)" ] \
        || fail "changed-lines gate leaked a temporary file after failure"
}

run_success "100.00%" \
    --lcov coverage/lcov.info --base "$BASE_SHA" --head "$HEAD_SHA"
run_success "100.00%" \
    --lcov coverage/lcov.info --diff-file "$TEST_ROOT/change.diff"

cat > "$TEST_ROOT/.gitattributes" <<'EOF'
frontend/app/src/**/*.ts -diff
EOF
cat > "$TEST_ROOT/frontend/app/src/lib/example.ts" <<'EOF'
export function value(flag: boolean) {
  if (flag) {
    return 3;
  }
  return 1;
}
EOF
git -C "$TEST_ROOT" add .gitattributes frontend/app/src/lib/example.ts
git -C "$TEST_ROOT" commit -qm "source classified as binary by attribute"
ATTR_HEAD_SHA="$(git -C "$TEST_ROOT" rev-parse HEAD)"
git -C "$TEST_ROOT" diff --unified=0 "$HEAD_SHA" "$ATTR_HEAD_SHA" > "$TEST_ROOT/binary.diff"
grep -Fq 'Binary files ' "$TEST_ROOT/binary.diff" \
    || fail "adversarial fixture did not produce a binary diff marker"
run_failure "binary or non-textual file change" \
    --lcov coverage/lcov.info --diff-file "$TEST_ROOT/binary.diff"
run_success "100.00%" \
    --lcov coverage/lcov.info --base "$HEAD_SHA" --head "$ATTR_HEAD_SHA"
git -C "$TEST_ROOT" checkout -q "$HEAD_SHA"

cat > "$TEST_ROOT/frontend/app/coverage/partial.info" <<'EOF'
TN:
SF:src/lib/example.ts
DA:1,1
DA:2,1
DA:3,0
DA:5,1
LF:4
LH:3
end_of_record
EOF
run_failure "66.67%" \
    --lcov coverage/partial.info --base "$BASE_SHA" --head "$HEAD_SHA"
run_success "66.67%" \
    --lcov coverage/partial.info --base "$BASE_SHA" --head "$HEAD_SHA" --threshold 60

cat > "$TEST_ROOT/README.md" <<'EOF'
Documentation-only change.
EOF
git -C "$TEST_ROOT" add README.md
git -C "$TEST_ROOT" commit -qm "documentation only"
DOC_SHA="$(git -C "$TEST_ROOT" rev-parse HEAD)"
run_success "Changed-lines coverage: N/A" \
    --lcov coverage/lcov.info --base "$HEAD_SHA" --head "$DOC_SHA"
: > "$TEST_ROOT/empty.diff"
run_success "Changed-lines coverage: N/A" \
    --lcov coverage/lcov.info --diff-file "$TEST_ROOT/empty.diff"

cat > "$TEST_ROOT/frontend/app/coverage/malformed.info" <<'EOF'
TN:
SF:src/lib/example.ts
DA:not-a-line
end_of_record
EOF
run_failure "malformed DA" \
    --lcov coverage/malformed.info --diff-file "$TEST_ROOT/change.diff"
run_failure "LCOV file is missing" \
    --lcov coverage/absent.info --diff-file "$TEST_ROOT/change.diff"
run_failure "base ref does not resolve" \
    --lcov coverage/lcov.info --base not-a-ref --head "$HEAD_SHA"

cat > "$TEST_ROOT/frontend/app/src/lib/other.ts" <<'EOF'
export const other = true;
EOF
cat > "$TEST_ROOT/frontend/app/coverage/missing-source-record.info" <<'EOF'
TN:
SF:src/lib/other.ts
DA:1,1
LF:1
LH:1
end_of_record
EOF
run_failure "no record for changed covered source" \
    --lcov coverage/missing-source-record.info --diff-file "$TEST_ROOT/change.diff"

printf '%s\n' 'this is not a unified diff' > "$TEST_ROOT/malformed.diff"
run_failure "diff input is malformed" \
    --lcov coverage/lcov.info --diff-file "$TEST_ROOT/malformed.diff"
run_failure "choose exactly one diff source" \
    --lcov coverage/lcov.info --diff-file "$TEST_ROOT/change.diff" \
    --base "$BASE_SHA" --head "$HEAD_SHA"
run_failure "between 0 and 100" \
    --lcov coverage/lcov.info --diff-file "$TEST_ROOT/change.diff" --threshold 101
run_failure "between 0 and 100" \
    --lcov coverage/lcov.info --diff-file "$TEST_ROOT/change.diff" --threshold ''

cat > "$TEST_ROOT/frontend/app/coverage/unknown-directive.info" <<'EOF'
TN:
SF:src/lib/example.ts
DA:1,1
BOGUS:value
LF:1
LH:1
end_of_record
EOF
run_failure "unsupported directive" \
    --lcov coverage/unknown-directive.info --diff-file "$TEST_ROOT/change.diff"

cat > "$TEST_ROOT/frontend/app/coverage/misplaced-directive.info" <<'EOF'
FNF:1
TN:
SF:src/lib/example.ts
DA:1,1
LF:1
LH:1
end_of_record
EOF
run_failure "outside an SF record" \
    --lcov coverage/misplaced-directive.info --diff-file "$TEST_ROOT/change.diff"

cat > "$TEST_ROOT/frontend/app/coverage/inconsistent-summary.info" <<'EOF'
TN:
SF:src/lib/example.ts
FN:1,value
FNF:2
FNH:1
FNDA:1,value
DA:1,1
LF:1
LH:1
end_of_record
EOF
run_failure "FNF does not match" \
    --lcov coverage/inconsistent-summary.info --diff-file "$TEST_ROOT/change.diff"

for workflow in \
    "$REPOSITORY_ROOT/" \
    "$REPOSITORY_ROOT/"; do
    grep -Fq 'ref: ${{ github.event.pull_request.head.sha || github.sha }}' "$workflow" \
        || fail "frontend checkout does not use the explicit pull-request head SHA: $workflow"
    grep -Fq 'COVERAGE_HEAD_SHA: ${{ github.event.pull_request.head.sha || github.sha }}' "$workflow" \
        || fail "coverage gate does not use the explicit pull-request head SHA: $workflow"
done

echo "Conversation Audit frontend changed-lines coverage gate validation passed."
