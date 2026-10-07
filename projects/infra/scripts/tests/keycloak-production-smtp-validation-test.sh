#!/usr/bin/env bash

set -Eeuo pipefail

REPOSITORY_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
source "$REPOSITORY_ROOT/infra/scripts/deploy-production.sh"
TEST_ROOT="$(mktemp -d)"
SMTP_ENV="$TEST_ROOT/smtp.env"

cleanup() {
    rm -rf -- "$TEST_ROOT"
}
trap cleanup EXIT

fail() {
    echo "FAIL: $*" >&2
    exit 1
}

write_valid_smtp_env() {
    cat > "$SMTP_ENV" <<'EOF'
KEYCLOAK_REALM_SMTP_MODE=prd
KEYCLOAK_REALM_SMTP_HOST=smtp.example.com
KEYCLOAK_REALM_SMTP_PORT=587
KEYCLOAK_REALM_SMTP_FROM=no-reply@agentefiscal.com.br
KEYCLOAK_REALM_SMTP_FROM_DISPLAY_NAME=Contador Fiscal
KEYCLOAK_REALM_SMTP_REPLY_TO=suporte@agentefiscal.com.br
KEYCLOAK_REALM_SMTP_REPLY_TO_DISPLAY_NAME=Contador Fiscal
KEYCLOAK_REALM_SMTP_AUTH=true
KEYCLOAK_REALM_SMTP_STARTTLS=true
KEYCLOAK_REALM_SMTP_SSL=false
KEYCLOAK_REALM_SMTP_USER=smtp-user@example.com
TF_VAR_contadorfiscal_smtp_password=Abcdefghijklmnop1234
EOF
    chmod 600 "$SMTP_ENV"
    ENV_FILE="$SMTP_ENV"
}

expect_rejected() {
    expected_message="$1"
    if (validate_keycloak_realm_smtp_production) \
            > "$TEST_ROOT/rejected.log" 2>&1; then
        fail "invalid production SMTP contract was accepted"
    fi
    grep -Fq "$expected_message" "$TEST_ROOT/rejected.log" \
        || fail "production SMTP rejection did not use the expected diagnostic"
    if grep -Fq 'Abcdefghijklmnop1234' "$TEST_ROOT/rejected.log"; then
        fail "production SMTP password appeared in validation output"
    fi
}

write_valid_smtp_env
validate_keycloak_realm_smtp_production

set_env_value "$SMTP_ENV" KEYCLOAK_REALM_SMTP_HOST mailpit
expect_rejected 'must use an external provider'

write_valid_smtp_env
set_env_value "$SMTP_ENV" KEYCLOAK_REALM_SMTP_AUTH false
expect_rejected 'must enable authentication'

write_valid_smtp_env
set_env_value "$SMTP_ENV" KEYCLOAK_REALM_SMTP_SSL true
expect_rejected 'requires exactly one TLS mode'

write_valid_smtp_env
set_env_value "$SMTP_ENV" TF_VAR_contadorfiscal_smtp_password short
expect_rejected 'must be a 16-256 character transport-safe secret'

echo "PASS: production deploy rejects unsafe Keycloak realm SMTP configurations."
