#!/usr/bin/env bash

set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
PROVISIONER="$ROOT/infra/keycloak/provision/provision-realms.sh"
MIGRATION="$ROOT/backend/app/src/main/resources/db/migration/tenant/V93__seed_canonical_admin_identities.sql"
TMP_ROOT="$(mktemp -d)"
FAKE_KCADM="$TMP_ROOT/kcadm.sh"
FAKE_SMTP_RECONCILER="$TMP_ROOT/reconcile-realm-smtp.sh"
SESSION="$TMP_ROOT/session"
LOG="$TMP_ROOT/calls.log"
trap 'rm -rf -- "$TMP_ROOT"' EXIT

fail() { echo "FAIL: $*" >&2; exit 1; }

for environment in dev hml production; do
    test -x "$ROOT/infra/keycloak/provision/$environment.sh" \
        || fail "$environment wrapper is absent"
done
for environment in hml production; do
    grep -Fq 'TF_VAR_contadorfiscal_smtp_password' "$ROOT/infra/keycloak/provision/$environment.sh" \
        || fail "$environment wrapper does not map the protected SMTP variable"
done

for compose in docker-compose.yml docker-compose.override.yml docker-compose.hml.yml docker-compose.prd.yml; do
    grep -q -- '--import-realm' "$ROOT/$compose" && fail "$compose still imports realms"
done
grep -Fq '/opt/keycloak/bootstrap/provision-and-bootstrap.sh' "$ROOT/docker-compose.yml" \
    || fail "Compose does not run the API provisioner"

for identity in djmarcellopedrosa@gmail.com contato@matrizcontabil.com.br; do
    grep -Fq "$identity" "$PROVISIONER" || fail "$identity is absent from IAM provisioning"
    grep -Fq "$identity" "$MIGRATION" || fail "$identity is absent from application provisioning"
done
grep -Eq 'password|credentials' "$PROVISIONER" \
    && fail "static realm provisioner must not carry human credentials"

printf '%s\n' session > "$SESSION"
chmod 600 "$SESSION"
cat > "$FAKE_KCADM" <<'FAKE'
#!/bin/sh
set -eu
printf '%s\n' "$*" >> "${FAKE_KCADM_LOG:?}"
command_name="${1:-}"
resource="${2:-}"
if [ "$command_name" = get ] && [ "${resource#realms/}" != "$resource" ]; then
    [ "${FAKE_REALMS_EXIST:-false}" = true ] || exit 1
    echo "${resource#realms/}"
    exit 0
fi
if [ "$command_name" = get ] && [ "${resource#roles/}" != "$resource" ]; then
    echo "${resource#roles/}"
    exit 0
fi
if [ "$command_name" = get ] && [ "$resource" = users ]; then
    [ "${FAKE_REALMS_EXIST:-false}" = true ] || exit 0
    case "$*" in *djmarcellopedrosa*) echo 11111111-1111-4111-8111-111111111111 ;; *) echo 22222222-2222-4222-8222-222222222222 ;; esac
    exit 0
fi
if [ "$command_name" = get ] && [ "${resource#users/}" != "$resource" ]; then
    case "$*" in *requiredActions*)
        if [ "${FAKE_USER_HAS_OTP:-false}" = true ]; then
            echo "UPDATE_PASSWORD,CONFIGURE_TOTP"
        else
            echo "UPDATE_PASSWORD"
        fi
        exit 0
        ;;
    esac
fi
if [ "$command_name" = create ] && [ "$resource" = clients ]; then
    case "$*" in *saas-service-api*) echo 10000000-0000-4000-8000-000000000001 ;; *) echo 20000000-0000-4000-8000-000000000002 ;; esac
    exit 0
fi
if [ "$command_name" = create ] && [ "$resource" = users ]; then
    case "$*" in *djmarcellopedrosa*) echo 11111111-1111-4111-8111-111111111111 ;; *) echo 22222222-2222-4222-8222-222222222222 ;; esac
    exit 0
fi
exit 0
FAKE
chmod 700 "$FAKE_KCADM"
cat > "$FAKE_SMTP_RECONCILER" <<'FAKE'
#!/bin/sh
set -eu
[ "$#" -eq 2 ] || exit 90
case "$1" in preflight|reconcile) ;; *) exit 91 ;; esac
printf 'smtp-%s\n' "$1" >> "${FAKE_KCADM_LOG:?}"
FAKE
chmod 700 "$FAKE_SMTP_RECONCILER"

FAKE_KCADM_LOG="$LOG" KCADM_BIN="$FAKE_KCADM" REALM_SMTP_RECONCILER="$FAKE_SMTP_RECONCILER" KEYCLOAK_PROVISION_ENV=dev \
KEYCLOAK_FRONTEND_REDIRECTS='http://localhost:3000/*' \
KEYCLOAK_FRONTEND_ORIGINS='http://localhost:3000' \
KEYCLOAK_REALM_SMTP_MODE=dev KEYCLOAK_REALM_SMTP_HOST=mailpit KEYCLOAK_REALM_SMTP_PORT=1025 \
KEYCLOAK_REALM_SMTP_FROM=no-reply@agentefiscal.local KEYCLOAK_REALM_SMTP_FROM_DISPLAY_NAME='Contador Fiscal' \
KEYCLOAK_REALM_SMTP_REPLY_TO=suporte@agentefiscal.local KEYCLOAK_REALM_SMTP_REPLY_TO_DISPLAY_NAME='Contador Fiscal' \
KEYCLOAK_REALM_SMTP_AUTH=false KEYCLOAK_REALM_SMTP_STARTTLS=false KEYCLOAK_REALM_SMTP_SSL=false \
KEYCLOAK_REALM_SMTP_USER= KEYCLOAK_REALM_SMTP_PASSWORD= "$PROVISIONER" "$SESSION" >/dev/null

[ "$(grep -c '^create realms ' "$LOG")" -eq 2 ] || fail "expected exactly two realm creations"
[ "$(grep -c '^create clients ' "$LOG")" -eq 4 ] || fail "expected exactly four client creations"
[ "$(grep -c '^create users ' "$LOG")" -eq 2 ] || fail "expected exactly two user creations"
grep -q 'create realms.*loginTheme=saas-theme' "$LOG" || fail "realm creation did not configure saas-theme"
grep -q 'create users.*requiredActions=\["UPDATE_PASSWORD"\]' "$LOG" || fail "user creation did not set requiredActions=[UPDATE_PASSWORD]"
grep -Fq 'CONFIGURE_TOTP' "$LOG" && fail "user creation unexpectedly requested CONFIGURE_TOTP"

FAKE_REALMS_EXIST=true FAKE_USER_HAS_OTP=true FAKE_KCADM_LOG="$LOG" KCADM_BIN="$FAKE_KCADM" REALM_SMTP_RECONCILER="$FAKE_SMTP_RECONCILER" KEYCLOAK_PROVISION_ENV=dev \
KEYCLOAK_FRONTEND_REDIRECTS='http://localhost:3000/*' \
KEYCLOAK_FRONTEND_ORIGINS='http://localhost:3000' \
KEYCLOAK_REALM_SMTP_MODE=dev KEYCLOAK_REALM_SMTP_HOST=mailpit KEYCLOAK_REALM_SMTP_PORT=1025 \
KEYCLOAK_REALM_SMTP_FROM=no-reply@agentefiscal.local KEYCLOAK_REALM_SMTP_FROM_DISPLAY_NAME='Contador Fiscal' \
KEYCLOAK_REALM_SMTP_REPLY_TO=suporte@agentefiscal.local KEYCLOAK_REALM_SMTP_REPLY_TO_DISPLAY_NAME='Contador Fiscal' \
KEYCLOAK_REALM_SMTP_AUTH=false KEYCLOAK_REALM_SMTP_STARTTLS=false KEYCLOAK_REALM_SMTP_SSL=false \
KEYCLOAK_REALM_SMTP_USER= KEYCLOAK_REALM_SMTP_PASSWORD= "$PROVISIONER" "$SESSION" >/dev/null
[ "$(grep -c '^create realms ' "$LOG")" -eq 2 ] || fail "second run recreated realms"
[ "$(grep -c '^create clients ' "$LOG")" -eq 4 ] || fail "second run recreated clients"
[ "$(grep -c '^create users ' "$LOG")" -eq 2 ] || fail "second run recreated users"
grep -Fq 'ROLE_SUPER_ADMIN' "$LOG" || fail "Super Admin role was not provisioned"
grep -Fq 'ROLE_TENANT_ADMIN' "$LOG" || fail "Tenant Admin role was not provisioned"
grep -Fq -- '--uid 11111111-1111-4111-8111-111111111111' "$LOG" \
    || fail "Keycloak-generated Super Admin ID was not used for role assignment"
grep -Fq -- '--uid 22222222-2222-4222-8222-222222222222' "$LOG" \
    || fail "Keycloak-generated Tenant Admin ID was not used for role assignment"
grep -q 'update realms/saas-admin.*loginTheme=saas-theme' "$LOG" || fail "admin realm theme was not reconciled"
grep -q 'update realms/saas-bpfarias.*loginTheme=saas-theme' "$LOG" || fail "tenant realm theme was not reconciled"
grep -q 'update users/11111111-1111-4111-8111-111111111111.*requiredActions=\["UPDATE_PASSWORD"\]' "$LOG" || fail "admin user OTP was not stripped"
grep -q 'update users/22222222-2222-4222-8222-222222222222.*requiredActions=\["UPDATE_PASSWORD"\]' "$LOG" || fail "tenant user OTP was not stripped"
[ "$(grep -c '^smtp-preflight$' "$LOG")" -eq 2 ] || fail "SMTP preflight did not run before each provisioning"
[ "$(grep -c '^smtp-reconcile$' "$LOG")" -eq 2 ] || fail "SMTP reconciliation did not run after each provisioning"

echo "Keycloak static realm provisioning tests passed."
