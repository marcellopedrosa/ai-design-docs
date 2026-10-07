#!/bin/sh

# Toggles only the CONFIGURE_TOTP required-action provider in allowlisted tenant
# realms. The provider and every user-level required action remain present, so
# reenabling the provider restores pending enrollment without recreating state.
set -eu
umask 077

KCADM_BIN="${KCADM_BIN:-/opt/keycloak/bin/kcadm.sh}"
RUNTIME_JSON_VALIDATOR="${RUNTIME_JSON_VALIDATOR:-/opt/keycloak/bootstrap/validate-keycloak-runtime-json.sh}"
RUNTIME_ENVIRONMENT="${KEYCLOAK_RUNTIME_ENVIRONMENT:-production}"
MANAGED_REALMS="${KEYCLOAK_EXISTING_MANAGED_REALMS:-}"
ADMIN_REALM=saas-admin
MAX_MANAGED_REALMS=100

usage() {
    echo "Usage: $0 verify|reconcile KCADM_CONFIG" >&2
    exit 2
}

fail() {
    echo "ERROR: $*" >&2
    exit 1
}

[ "${KEYCLOAK_TENANT_FIRST_LOGIN_MFA_ENABLED+x}" = x ] \
    || fail "KEYCLOAK_TENANT_FIRST_LOGIN_MFA_ENABLED is required."
MFA_ENABLED="$KEYCLOAK_TENANT_FIRST_LOGIN_MFA_ENABLED"

[ "$#" -eq 2 ] || usage
MODE="$1"
KCADM_CONFIG="$2"
case "$MODE" in
    verify|reconcile) ;;
    *) usage ;;
esac
case "$MFA_ENABLED" in
    true|false) ;;
    *) fail "KEYCLOAK_TENANT_FIRST_LOGIN_MFA_ENABLED must be true or false." ;;
esac
case "$RUNTIME_ENVIRONMENT" in
    dev|hml|production) ;;
    *) fail "KEYCLOAK_RUNTIME_ENVIRONMENT must be dev, hml or production." ;;
esac
if ! printf '%s\n' "$MANAGED_REALMS" \
        | grep -Eq '^saas-[a-z0-9][a-z0-9-]*(,saas-[a-z0-9][a-z0-9-]*)*$'; then
    fail "KEYCLOAK_EXISTING_MANAGED_REALMS must be an exact comma-separated SaaS realm allowlist without whitespace."
fi
[ -f "$KCADM_CONFIG" ] && [ -r "$KCADM_CONFIG" ] \
    || fail "The authenticated kcadm session file is unavailable."
[ -x "$KCADM_BIN" ] \
    || fail "The Keycloak administration client is unavailable."
[ -f "$RUNTIME_JSON_VALIDATOR" ] && [ -r "$RUNTIME_JSON_VALIDATOR" ] \
    || fail "The structural Keycloak runtime JSON validator is unavailable."

WORK_DIR="$(mktemp -d /tmp/saas-tenant-first-login-mfa.XXXXXX)"
REALMS_FILE="$WORK_DIR/tenant-realms.list"
INVENTORY_FILE="$WORK_DIR/inventory.list"

cleanup() {
    rm -rf -- "$WORK_DIR"
}
trap cleanup EXIT
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM

kcadm() {
    "$KCADM_BIN" "$@" --config "$KCADM_CONFIG"
}

build_tenant_realm_inventory() {
    : > "$REALMS_FILE"
    remaining_realms="${MANAGED_REALMS},"
    seen_realms=,
    managed_count=0
    tenant_count=0
    while [ -n "$remaining_realms" ]; do
        realm_name="${remaining_realms%%,*}"
        remaining_realms="${remaining_realms#*,}"
        case "$seen_realms" in
            *,"$realm_name",*) fail "KEYCLOAK_EXISTING_MANAGED_REALMS must not contain duplicate realms." ;;
        esac
        managed_count=$((managed_count + 1))
        [ "$managed_count" -le "$MAX_MANAGED_REALMS" ] \
            || fail "KEYCLOAK_EXISTING_MANAGED_REALMS exceeds the bounded realm limit."
        seen_realms="${seen_realms}${realm_name},"
        if [ "$realm_name" != "$ADMIN_REALM" ]; then
            tenant_count=$((tenant_count + 1))
            printf '%s\n' "$realm_name" >> "$REALMS_FILE"
        fi
    done
    if [ "$MFA_ENABLED" = false ] && [ "$tenant_count" -eq 0 ]; then
        fail "Tenant first-login MFA cannot be disabled without an allowlisted tenant realm."
    fi
}

inventory_all_providers() {
    : > "$INVENTORY_FILE"
    realm_index=0
    while IFS= read -r realm_name || [ -n "$realm_name" ]; do
        [ -n "$realm_name" ] || continue
        realm_index=$((realm_index + 1))
        provider_file="$WORK_DIR/provider-$realm_index.json"
        if ! kcadm get "authentication/required-actions/CONFIGURE_TOTP" \
                -r "$realm_name" > "$provider_file"; then
            fail "Could not inspect CONFIGURE_TOTP in an allowlisted tenant realm."
        fi
        if ! provider_result="$(/bin/bash "$RUNTIME_JSON_VALIDATOR" \
                admin-login-required-action "$provider_file")"; then
            fail "Could not classify CONFIGURE_TOTP in an allowlisted tenant realm."
        fi
        case "$provider_result" in
            enabled=true) current_enabled=true ;;
            enabled=false) current_enabled=false ;;
            *) fail "The CONFIGURE_TOTP classifier returned an unexpected result." ;;
        esac
        printf '%s|%s|%s\n' "$realm_name" "$provider_file" "$current_enabled" \
            >> "$INVENTORY_FILE"
    done < "$REALMS_FILE"
}

update_provider() {
    realm_name="$1"
    provider_file="$2"
    payload_file="$3"
    if ! /bin/bash "$RUNTIME_JSON_VALIDATOR" \
            admin-login-required-action "$provider_file" "$MFA_ENABLED" \
            > "$payload_file"; then
        fail "Could not build a preserving CONFIGURE_TOTP update payload."
    fi
    kcadm update "authentication/required-actions/CONFIGURE_TOTP" \
        -r "$realm_name" --no-merge -f "$payload_file" >/dev/null \
        || fail "Could not update CONFIGURE_TOTP in an allowlisted tenant realm."
}

build_tenant_realm_inventory
inventory_all_providers

if [ "$MODE" = verify ]; then
    while IFS='|' read -r realm_name provider_file current_enabled \
            || [ -n "$realm_name$provider_file$current_enabled" ]; do
        [ -n "$realm_name" ] || continue
        [ "$current_enabled" = "$MFA_ENABLED" ] \
            || fail "Tenant first-login MFA state requires controlled reconciliation."
    done < "$INVENTORY_FILE"
    echo "Tenant first-login MFA state is valid."
    exit 0
fi

realm_index=0
while IFS='|' read -r realm_name provider_file current_enabled \
        || [ -n "$realm_name$provider_file$current_enabled" ]; do
    [ -n "$realm_name" ] || continue
    realm_index=$((realm_index + 1))
    if [ "$current_enabled" != "$MFA_ENABLED" ]; then
        update_provider "$realm_name" "$provider_file" "$WORK_DIR/payload-$realm_index.json"
    fi
done < "$INVENTORY_FILE"

inventory_all_providers
while IFS='|' read -r realm_name provider_file current_enabled \
        || [ -n "$realm_name$provider_file$current_enabled" ]; do
    [ -n "$realm_name" ] || continue
    [ "$current_enabled" = "$MFA_ENABLED" ] \
        || fail "Tenant first-login MFA failed post-reconciliation verification."
done < "$INVENTORY_FILE"

echo "Tenant first-login MFA state was reconciled successfully."
