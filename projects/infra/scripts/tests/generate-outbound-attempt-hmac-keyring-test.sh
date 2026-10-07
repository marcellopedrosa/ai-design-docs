#!/usr/bin/env bash

set -Eeuo pipefail

REPOSITORY_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
GENERATOR="$REPOSITORY_ROOT/infra/scripts/generate-outbound-attempt-hmac-keyring.sh"
BOOTSTRAP_BODY="$(cat "$REPOSITORY_ROOT/infra/scripts/lib/start-dev-bot/"part-*.sh)"
TEST_ROOT="$(mktemp -d)"
OUTPUT_LOG="$TEST_ROOT/output.log"

cleanup() {
    rm -rf -- "$TEST_ROOT"
}
trap cleanup EXIT INT TERM

fail() {
    printf 'generate-outbound-attempt-hmac-keyring-test: FAIL: %s\n' "$*" >&2
    exit 1
}

expect_rejected() {
    if "$GENERATOR" "$@" >"$OUTPUT_LOG" 2>&1; then
        fail 'invalid generation request was accepted'
    fi
    grep -Fqx 'generate-outbound-attempt-hmac-keyring: rejected' "$OUTPUT_LOG" \
        || fail 'rejection did not use the fixed low-information message'
}

for required_command in jq openssl sha256sum stat; do
    command -v "$required_command" >/dev/null 2>&1 \
        || fail "required test command unavailable: $required_command"
done

grep -Fq 'OUTBOUND_ATTEMPT_KEYRING_GENERATOR="$PROJECT_DIR/infra/scripts/generate-outbound-attempt-hmac-keyring.sh"' \
    <<<"$BOOTSTRAP_BODY" || fail 'DEV bootstrap does not bind the canonical generator'
BOOTSTRAP_GENERATION_FUNCTION="$(sed -n \
    '/^ensure_generated_outbound_attempt_keyring() {$/,/^}$/p' <<<"$BOOTSTRAP_BODY")"
grep -Fq '"$OUTBOUND_ATTEMPT_KEYRING_GENERATOR"' <<<"$BOOTSTRAP_GENERATION_FUNCTION" \
    || fail 'DEV bootstrap does not invoke the canonical generator'
if grep -Eq 'openssl rand|printf .*\{.*keys' <<<"$BOOTSTRAP_GENERATION_FUNCTION"; then
    fail 'DEV bootstrap still contains inline outbound keyring generation'
fi

mkdir "$TEST_ROOT/secure"
chmod 700 "$TEST_ROOT/secure"
KEYRING_FILE="$TEST_ROOT/secure/conversation-outbound-attempt-hmac-keyring.json"

"$GENERATOR" \
    --output "$KEYRING_FILE" \
    --active-key-id prd-outbound-v1 >"$OUTPUT_LOG" 2>&1 \
    || fail 'valid keyring generation failed'
grep -Fqx 'generate-outbound-attempt-hmac-keyring: created' "$OUTPUT_LOG" \
    || fail 'success did not use the fixed low-information message'
[ "$(stat -c '%a' "$KEYRING_FILE")" = 600 ] || fail 'keyring mode is not 0600'
jq -e 'keys == ["keys"] and (.keys | keys == ["prd-outbound-v1"])' \
    "$KEYRING_FILE" >/dev/null || fail 'keyring JSON contract is invalid'
KEY_MATERIAL="$(jq -r '.keys["prd-outbound-v1"]' "$KEYRING_FILE")"
[ "$(printf '%s' "$KEY_MATERIAL" | openssl base64 -d -A | wc -c | tr -d '[:space:]')" = 32 ] \
    || fail 'generated material does not decode to exactly 32 bytes'
if grep -Fq "$KEY_MATERIAL" "$OUTPUT_LOG"; then
    fail 'generator output exposed key material'
fi

ORIGINAL_DIGEST="$(sha256sum "$KEYRING_FILE")"
expect_rejected --output "$KEYRING_FILE" --active-key-id prd-outbound-v2
[ "$(sha256sum "$KEYRING_FILE")" = "$ORIGINAL_DIGEST" ] \
    || fail 'existing keyring changed after overwrite attempt'

ln -s "$KEYRING_FILE" "$TEST_ROOT/secure/symlink.json"
expect_rejected --output "$TEST_ROOT/secure/symlink.json" --active-key-id prd-outbound-v1
mkdir -p "$TEST_ROOT/secure-parent/nested"
chmod 700 "$TEST_ROOT/secure-parent" "$TEST_ROOT/secure-parent/nested"
ln -s "$TEST_ROOT/secure-parent" "$TEST_ROOT/symlink-parent"
expect_rejected \
    --output "$TEST_ROOT/symlink-parent/nested/ancestor-symlink.json" \
    --active-key-id prd-outbound-v1
expect_rejected --output "$TEST_ROOT/secure/invalid-id.json" --active-key-id 'invalid id'

mkdir "$TEST_ROOT/insecure"
chmod 755 "$TEST_ROOT/insecure"
expect_rejected \
    --output "$TEST_ROOT/insecure/conversation-outbound-attempt-hmac-keyring.json" \
    --active-key-id prd-outbound-v1
expect_rejected --output "$TEST_ROOT/secure/missing-id.json"

unset KEY_MATERIAL
printf 'generate-outbound-attempt-hmac-keyring-test: PASS\n'
