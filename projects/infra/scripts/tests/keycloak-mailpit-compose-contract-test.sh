#!/usr/bin/env bash

set -Eeuo pipefail

REPOSITORY_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
DEV_COMPOSE="$REPOSITORY_ROOT/docker-compose.override.yml"
HML_COMPOSE="$REPOSITORY_ROOT/docker-compose.hml.yml"
PRD_COMPOSE="$REPOSITORY_ROOT/docker-compose.prd.yml"
BASE_COMPOSE="$REPOSITORY_ROOT/docker-compose.yml"
PRODUCTION_ENV="$REPOSITORY_ROOT/infra/deploy/production.env.example"
PRODUCTION_DEPLOY="$REPOSITORY_ROOT/infra/scripts/deploy-production.sh"
PRODUCTION_ENV_VALIDATION="$REPOSITORY_ROOT/infra/scripts/lib/deploy-production/environment.sh"
MAILPIT_IMAGE='axllent/mailpit:v1.27.4@sha256:df6c2541907e1be6fac21f509927cf6ed771617a1f4b361ef66d97bd05593d2d'

fail() {
    echo "FAIL: $*" >&2
    exit 1
}

for compose_file in "$DEV_COMPOSE"; do
    grep -Fq '  mailpit:' "$compose_file" \
        || fail "DEV Compose must define Mailpit"
    grep -Fq "image: $MAILPIT_IMAGE" "$compose_file" \
        || fail "Mailpit image must use the reviewed version and OCI digest"
    grep -Fq '"127.0.0.1:8025:8025"' "$compose_file" \
        || fail "Mailpit UI must be published only on host loopback"
    grep -Fq 'MP_DATABASE: /tmp/mailpit.db' "$compose_file" \
        || fail "Mailpit messages must use ephemeral storage"
    grep -Fq 'MP_MAX_MESSAGES: 500' "$compose_file" \
        || fail "Mailpit message count must be bounded"
    if grep -Eq '(^|[^0-9])1025:1025([^0-9]|$)' "$compose_file"; then
        fail "Mailpit SMTP port must not be published on the host"
    fi
done

DEV_MAILPIT_BLOCK="$(sed -n '/^  mailpit:$/,/^  redis:$/p' "$DEV_COMPOSE")"
printf '%s\n' "$DEV_MAILPIT_BLOCK" | grep -Fq 'cap_drop: !reset []' \
    || fail "DEV Mailpit must reset dropped capabilities for Docker Desktop/Snap compatibility"
printf '%s\n' "$DEV_MAILPIT_BLOCK" | grep -Fq 'security_opt: !reset []' \
    || fail "DEV Mailpit must reset no-new-privileges for Docker Desktop/Snap compatibility"

for compose_file in "$HML_COMPOSE" "$PRD_COMPOSE"; do
    grep -Fqi mailpit "$compose_file" && fail "HML/production Compose must not contain Mailpit"
    grep -Fq 'TF_VAR_contadorfiscal_smtp_password:?TF_VAR_contadorfiscal_smtp_password is required' "$compose_file" \
        || fail "HML/production Compose must require the protected SMTP variable"
done
grep -Fq 'KEYCLOAK_REALM_SMTP_HOST: smtp.hostinger.com' "$HML_COMPOSE" \
    || fail "HML must use the external SMTP provider"
grep -Fq 'KEYCLOAK_REALM_SMTP_PORT: 465' "$HML_COMPOSE" \
    || fail "HML must use SMTP SSL port 465"
grep -Fq 'KEYCLOAK_REALM_SMTP_MODE: prd' "$PRD_COMPOSE" \
    || fail "production services must bind the SMTP policy to PRD"
grep -Fq 'KEYCLOAK_REALM_SMTP_PASSWORD: ${TF_VAR_contadorfiscal_smtp_password:?TF_VAR_contadorfiscal_smtp_password is required}' "$PRD_COMPOSE" \
    || fail "production Compose must require the external SMTP credential"
[ "$(grep -Fc './infra/keycloak/bootstrap/reconcile-realm-smtp.sh:/opt/keycloak/bootstrap/reconcile-realm-smtp.sh:ro' "$BASE_COMPOSE")" -eq 2 ] \
    || fail "both Keycloak runtime services must mount the SMTP reconciler read-only"
grep -Fqx 'KEYCLOAK_REALM_SMTP_MODE=prd' "$PRODUCTION_ENV" \
    || fail "production environment contract must select PRD SMTP mode"
grep -Fqx 'KEYCLOAK_REALM_SMTP_HOST=CHANGE_ME' "$PRODUCTION_ENV" \
    || fail "production environment must require an external SMTP host"
grep -Fq 'Production Keycloak realm SMTP must use an external provider' "$PRODUCTION_ENV_VALIDATION" \
    || fail "production deploy must reject local/Mailpit SMTP"
grep -Fq 'Production Keycloak realm SMTP requires exactly one TLS mode' "$PRODUCTION_ENV_VALIDATION" \
    || fail "production deploy must require exactly one SMTP TLS mode"

echo "PASS: Mailpit is bounded to DEV and HML/production require external SMTP."
