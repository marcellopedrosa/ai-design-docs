#!/bin/sh

set -eu
umask 077

KCADM_BIN="${KCADM_BIN:-/opt/keycloak/bin/kcadm.sh}"
KCADM_CONFIG=/tmp/kcadm-static-realms.config
KEYCLOAK_INTERNAL_URL="${KEYCLOAK_INTERNAL_URL:-http://keycloak:8080}"
RUNTIME_ENVIRONMENT="${KEYCLOAK_RUNTIME_ENVIRONMENT:-production}"
BOOTSTRAP_SCRIPT="${KEYCLOAK_BOOTSTRAP_SCRIPT:-/opt/keycloak/bootstrap/ensure-management-service-account.sh}"

cleanup() {
    rm -f "$KCADM_CONFIG"
}
trap cleanup EXIT HUP INT TERM

authenticate_bootstrap_admin() (
    KC_CLI_PASSWORD="${KEYCLOAK_BOOTSTRAP_ADMIN_PASSWORD:?}"
    export KC_CLI_PASSWORD
    "$KCADM_BIN" config credentials --config "$KCADM_CONFIG" \
        --server "$KEYCLOAK_INTERNAL_URL" --realm master \
        --user "${KEYCLOAK_BOOTSTRAP_ADMIN_USER:?}" \
        </dev/null >/dev/null 2>&1
)

authenticate_service_account() (
    KC_CLI_CLIENT_SECRET="${KEYCLOAK_PROVISIONING_CLIENT_SECRET:?}"
    export KC_CLI_CLIENT_SECRET
    "$KCADM_BIN" config credentials --config "$KCADM_CONFIG" \
        --server "$KEYCLOAK_INTERNAL_URL" --realm master \
        --client "${KEYCLOAK_PROVISIONING_CLIENT_ID:-saas-realm-provisioner}" \
        </dev/null >/dev/null 2>&1
)

if ! authenticate_bootstrap_admin; then
    rm -f "$KCADM_CONFIG"
    authenticate_service_account || {
        echo "ERROR: no authorized Keycloak realm provisioning identity is available." >&2
        exit 1
    }
fi
chmod 600 "$KCADM_CONFIG"

case "$RUNTIME_ENVIRONMENT" in
    dev|hml|production) ;;
    *) echo "ERROR: unsupported Keycloak runtime environment." >&2; exit 1 ;;
esac

"/opt/keycloak/provision/$RUNTIME_ENVIRONMENT.sh" "$KCADM_CONFIG"
rm -f "$KCADM_CONFIG"

if [ -f "$BOOTSTRAP_SCRIPT" ] && [ -x "$BOOTSTRAP_SCRIPT" ]; then
    exec "$BOOTSTRAP_SCRIPT"
fi
