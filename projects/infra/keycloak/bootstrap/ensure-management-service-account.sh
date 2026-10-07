#!/bin/sh

set -eu
umask 077

KCADM="/opt/keycloak/bin/kcadm.sh"
RUNTIME_JSON_VALIDATOR="/opt/keycloak/bootstrap/validate-keycloak-runtime-json.sh"
BILLING_MFA_AMR_RECONCILER="/opt/keycloak/bootstrap/reconcile-billing-mfa-amr.sh"
ADMIN_LOGIN_MFA_RECONCILER="/opt/keycloak/bootstrap/reconcile-admin-login-mfa.sh"
TENANT_FIRST_LOGIN_MFA_RECONCILER="/opt/keycloak/bootstrap/reconcile-tenant-first-login-mfa.sh"
SUPER_ADMIN_IDENTITY_RECONCILER="/opt/keycloak/bootstrap/reconcile-super-admin-identity.sh"
REALM_SMTP_RECONCILER="/opt/keycloak/bootstrap/reconcile-realm-smtp.sh"
KCADM_CONFIG="/tmp/kcadm.config"
KEYCLOAK_INTERNAL_URL="${KEYCLOAK_INTERNAL_URL:-http://keycloak:8080}"
MANAGED_REALMS="${KEYCLOAK_EXISTING_MANAGED_REALMS:-}"
MANAGED_REALMS_FILE="/tmp/kcadm-managed-realms.list"
ROLE_MAPPINGS_FILE="/tmp/kcadm-role-mappings.csv"
ROLE_NAMES_FILE="/tmp/kcadm-role-names.csv"
ROLE_DELETE_PAYLOAD="/tmp/kcadm-role-delete.json"
CLIENT_PAYLOAD_FILE="/tmp/kcadm-management-client.json"
EXISTING_CLIENT_FILE="/tmp/kcadm-existing-management-client.json"
MASTER_CLIENTS_PAGE_FILE="/tmp/kcadm-master-clients-page.csv"
ALL_MASTER_CLIENTS_FILE="/tmp/kcadm-all-master-clients.csv"
MANAGEMENT_CLIENTS_FILE="/tmp/kcadm-management-clients.csv"
PERMANENT_TOKEN_FILE="/tmp/kcadm-permanent-token.txt"
PERMANENT_TOKEN_PAYLOAD_FILE="/tmp/kcadm-permanent-token-payload.json"
EXPECTED_MANAGEMENT_ROLES="manage-users query-users view-users view-realm"
# Keycloak 26.6.x defines view-users as a composite role whose effective
# expansion also contains query-users and query-groups. Keep the direct grant
# allowlist at the four ADR-0018 roles, while proving the exact inherited set.
EXPECTED_EFFECTIVE_MANAGEMENT_ROLES="manage-users query-groups query-users view-users view-realm"
ADMIN_API_PAGE_SIZE=100
ADMIN_API_MAX_ITEMS=10000
FORCE_RECONCILE="${KEYCLOAK_FORCE_RECONCILE:-false}"

cleanup() {
    rm -f \
        "$KCADM_CONFIG" \
        "$MANAGED_REALMS_FILE" \
        "$ROLE_MAPPINGS_FILE" \
        "$ROLE_NAMES_FILE" \
        "$ROLE_DELETE_PAYLOAD" \
        "$CLIENT_PAYLOAD_FILE" \
        "$EXISTING_CLIENT_FILE" \
        "$MASTER_CLIENTS_PAGE_FILE" \
        "$ALL_MASTER_CLIENTS_FILE" \
        "$MANAGEMENT_CLIENTS_FILE" \
        "$PERMANENT_TOKEN_FILE" \
        "$PERMANENT_TOKEN_PAYLOAD_FILE"
}

validate_managed_realms() {
    if ! printf '%s\n' "$MANAGED_REALMS" \
            | grep -Eq '^saas-[a-z0-9][a-z0-9-]*(,saas-[a-z0-9][a-z0-9-]*)*$'; then
        echo "ERROR: KEYCLOAK_EXISTING_MANAGED_REALMS must be a non-empty, exact comma-separated SaaS realm allowlist without whitespace." >&2
        exit 1
    fi

    : > "$MANAGED_REALMS_FILE"
    remaining_realms="${MANAGED_REALMS},"
    seen_realms=,
    while [ -n "$remaining_realms" ]; do
        realm_name="${remaining_realms%%,*}"
        remaining_realms="${remaining_realms#*,}"
        case "$seen_realms" in
            *,"$realm_name",*)
                echo "ERROR: KEYCLOAK_EXISTING_MANAGED_REALMS must not contain duplicate realms." >&2
                exit 1
                ;;
        esac
        printf '%s\n' "$realm_name" >> "$MANAGED_REALMS_FILE"
        seen_realms="${seen_realms}${realm_name},"
    done
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

require_value() {
    variable_name="$1"
    eval "variable_value=\${$variable_name:-}"
    if [ -z "$variable_value" ]; then
        echo "ERROR: $variable_name is required for Keycloak technical identity bootstrap." >&2
        exit 1
    fi
}

kcadm() {
    "$KCADM" "$@" --config "$KCADM_CONFIG"
}

extract_first_id() {
    sed -n 's/.*"id"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n 1
}

require_value KEYCLOAK_PROVISIONING_CLIENT_ID
require_value KEYCLOAK_PROVISIONING_CLIENT_SECRET
require_value KEYCLOAK_EXISTING_MANAGED_REALMS
[ -f "$RUNTIME_JSON_VALIDATOR" ] && [ -r "$RUNTIME_JSON_VALIDATOR" ] || {
    echo "ERROR: Structural Keycloak runtime JSON validator is unavailable." >&2
    exit 1
}
[ -f "$BILLING_MFA_AMR_RECONCILER" ] && [ -x "$BILLING_MFA_AMR_RECONCILER" ] || {
    echo "ERROR: Billing MFA AMR reconciler is unavailable." >&2
    exit 1
}
[ -f "$ADMIN_LOGIN_MFA_RECONCILER" ] && [ -x "$ADMIN_LOGIN_MFA_RECONCILER" ] || {
    echo "ERROR: Administrative login MFA reconciler is unavailable." >&2
    exit 1
}
[ -f "$TENANT_FIRST_LOGIN_MFA_RECONCILER" ] && [ -x "$TENANT_FIRST_LOGIN_MFA_RECONCILER" ] || {
    echo "ERROR: Tenant first-login MFA reconciler is unavailable." >&2
    exit 1
}
[ -f "$SUPER_ADMIN_IDENTITY_RECONCILER" ] && [ -x "$SUPER_ADMIN_IDENTITY_RECONCILER" ] || {
    echo "ERROR: Super Admin identity reconciler is unavailable." >&2
    exit 1
}
[ -f "$REALM_SMTP_RECONCILER" ] && [ -x "$REALM_SMTP_RECONCILER" ] || {
    echo "ERROR: Keycloak realm SMTP reconciler is unavailable." >&2
    exit 1
}
validate_managed_realms
if ! printf '%s\n' "$KEYCLOAK_PROVISIONING_CLIENT_ID" \
        | LC_ALL=C grep -Eq '^[A-Za-z0-9_.:-]+$'; then
    echo "ERROR: KEYCLOAK_PROVISIONING_CLIENT_ID contains unsafe characters." >&2
    exit 1
fi
case "$KEYCLOAK_PROVISIONING_CLIENT_ID" in
    account|account-console|admin-cli|broker|realm-management|security-admin-console|saas-frontend-spa|saas-service-api|saas-recovery-*|*-realm)
        echo "ERROR: KEYCLOAK_PROVISIONING_CLIENT_ID is reserved and cannot identify the managed technical client." >&2
        exit 1
        ;;
esac
if [ "${#KEYCLOAK_PROVISIONING_CLIENT_SECRET}" -lt 32 ] \
        || [ "${#KEYCLOAK_PROVISIONING_CLIENT_SECRET}" -gt 256 ] \
        || ! printf '%s\n' "$KEYCLOAK_PROVISIONING_CLIENT_SECRET" \
            | LC_ALL=C grep -Eq '^[A-Za-z0-9._~-]+$'; then
    echo "ERROR: KEYCLOAK_PROVISIONING_CLIENT_SECRET must be a 32-256 character URL-safe secret." >&2
    exit 1
fi
case "$FORCE_RECONCILE" in
    true|false)
        ;;
    *)
        echo "ERROR: KEYCLOAK_FORCE_RECONCILE must be true or false." >&2
        exit 1
        ;;
esac

authenticate_client_credentials() (
    credential_client_id="$1"
    credential_client_secret="$2"
    KC_CLI_CLIENT_SECRET="$credential_client_secret"
    export KC_CLI_CLIENT_SECRET
    "$KCADM" config credentials \
        --config "$KCADM_CONFIG" \
        --server "$KEYCLOAK_INTERNAL_URL" \
        --realm master \
        --client "$credential_client_id" \
        </dev/null >/dev/null 2>&1
)

authenticate_user_password() (
    credential_username="$1"
    credential_password="$2"
    KC_CLI_PASSWORD="$credential_password"
    export KC_CLI_PASSWORD
    "$KCADM" config credentials \
        --config "$KCADM_CONFIG" \
        --server "$KEYCLOAK_INTERNAL_URL" \
        --realm master \
        --user "$credential_username" \
        </dev/null >/dev/null 2>&1
)

authenticate_bootstrap_identity() {
    bootstrap_authenticated=false
    if [ -n "${KEYCLOAK_BOOTSTRAP_ADMIN_CLIENT_ID:-}" ] \
            || [ -n "${KEYCLOAK_BOOTSTRAP_ADMIN_CLIENT_SECRET:-}" ]; then
        require_value KEYCLOAK_BOOTSTRAP_ADMIN_CLIENT_ID
        require_value KEYCLOAK_BOOTSTRAP_ADMIN_CLIENT_SECRET
        if authenticate_client_credentials \
                "$KEYCLOAK_BOOTSTRAP_ADMIN_CLIENT_ID" \
                "$KEYCLOAK_BOOTSTRAP_ADMIN_CLIENT_SECRET"; then
            bootstrap_authenticated=true
        fi
        return
    fi

    require_value KEYCLOAK_BOOTSTRAP_ADMIN_USER
    require_value KEYCLOAK_BOOTSTRAP_ADMIN_PASSWORD
    if authenticate_user_password \
            "$KEYCLOAK_BOOTSTRAP_ADMIN_USER" \
            "$KEYCLOAK_BOOTSTRAP_ADMIN_PASSWORD"; then
        bootstrap_authenticated=true
    fi
}

inventory_permanent_management_client() {
    kcadm get clients \
        -r master \
        -q "clientId=$KEYCLOAK_PROVISIONING_CLIENT_ID" \
        -q first=0 \
        -q max=2 \
        --fields id \
        --format csv \
        --noquotes > "$MASTER_CLIENTS_PAGE_FILE"
    client_count=0
    client_uuid=""
    while IFS= read -r candidate_client_uuid || [ -n "$candidate_client_uuid" ]; do
        candidate_client_uuid="$(printf '%s' "$candidate_client_uuid" | tr -d '\r')"
        [ -n "$candidate_client_uuid" ] || continue
        case "$candidate_client_uuid" in
            *[!0-9a-fA-F-]*)
                echo "ERROR: Invalid permanent management client identifier." >&2
                exit 1
                ;;
        esac
        client_count=$((client_count + 1))
        client_uuid="$candidate_client_uuid"
    done < "$MASTER_CLIENTS_PAGE_FILE"
    if [ "$client_count" -gt 1 ]; then
        echo "ERROR: More than one permanent management client matched the configured client ID." >&2
        exit 1
    fi
}

verify_existing_client_ownership() {
    existing_client_uuid="$1"
    kcadm get "clients/$existing_client_uuid" \
        -r master \
        --fields id,clientId,enabled,publicClient,bearerOnly,standardFlowEnabled,implicitFlowEnabled,directAccessGrantsEnabled,serviceAccountsEnabled,clientAuthenticatorType,protocol,attributes \
        > "$EXISTING_CLIENT_FILE"

    if ! client_ownership_state="$(/bin/bash "$RUNTIME_JSON_VALIDATOR" \
            client "$EXISTING_CLIENT_FILE" "$KEYCLOAK_PROVISIONING_CLIENT_ID")"; then
        echo "ERROR: Existing technical client could not be classified structurally; no update was applied." >&2
        exit 1
    fi
    case "$client_ownership_state" in
        managed)
            return
            ;;
        legacy)
            if [ "$KEYCLOAK_PROVISIONING_CLIENT_ID" = saas-realm-provisioner ]; then
                return
            fi
            echo "ERROR: Existing custom technical client has no managed ownership marker; no update was applied." >&2
            exit 1
            ;;
        unowned)
            echo "ERROR: Existing technical client has unsupported ownership or legacy state; no update was applied." >&2
            exit 1
            ;;
        *)
            echo "ERROR: Structural client ownership classifier returned an unexpected result; no update was applied." >&2
            exit 1
            ;;
    esac
}

verify_exact_role_names() {
    role_check_expected_roles="$1"
    role_check_expected_count="$2"
    role_check_context="$3"
    role_check_actual_count=0

    while IFS= read -r role_check_name || [ -n "$role_check_name" ]; do
        role_check_name="$(printf '%s' "$role_check_name" | tr -d '\r')"
        [ -n "$role_check_name" ] || continue
        role_check_actual_count=$((role_check_actual_count + 1))
        case " $role_check_expected_roles " in
            *" $role_check_name "*)
                ;;
            *)
                echo "ERROR: Unexpected effective privilege remains in $role_check_context." >&2
                return 1
                ;;
        esac
    done < "$ROLE_NAMES_FILE"

    if [ "$role_check_actual_count" -ne "$role_check_expected_count" ]; then
        echo "ERROR: $role_check_context does not contain the exact minimum privilege count." >&2
        return 1
    fi
    for role_check_expected_name in $role_check_expected_roles; do
        if ! grep -Fxq "$role_check_expected_name" "$ROLE_NAMES_FILE"; then
            echo "ERROR: Required minimum privilege is absent from $role_check_context." >&2
            return 1
        fi
    done
}

verify_permanent_token_exact_privileges() {
    if ! command -v base64 >/dev/null 2>&1; then
        echo "ERROR: Cannot prove permanent effective privileges because base64 is unavailable." >&2
        return 1
    fi

    sed -n 's/.*"token"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' \
        "$KCADM_CONFIG" > "$PERMANENT_TOKEN_FILE"
    permanent_token_count="$(grep -c '[^[:space:]]' "$PERMANENT_TOKEN_FILE" || true)"
    if [ "$permanent_token_count" -ne 1 ]; then
        echo "ERROR: Client Credentials did not produce exactly one cached access token." >&2
        return 1
    fi
    permanent_token="$(tr -d '\r\n' < "$PERMANENT_TOKEN_FILE")"
    case "$permanent_token" in
        *.*.*)
            permanent_token_after_header="${permanent_token#*.}"
            permanent_token_payload="${permanent_token_after_header%%.*}"
            permanent_token_signature="${permanent_token_after_header#*.}"
            ;;
        *)
            echo "ERROR: Client Credentials returned a malformed access token." >&2
            return 1
            ;;
    esac
    case "$permanent_token_signature" in
        ""|*.*)
            echo "ERROR: Client Credentials returned a malformed access token." >&2
            return 1
            ;;
    esac
    if ! printf '%s\n' "$permanent_token_payload" \
            | LC_ALL=C grep -Eq '^[A-Za-z0-9_-]+$'; then
        echo "ERROR: Client Credentials returned an invalid JWT payload encoding." >&2
        return 1
    fi

    permanent_token_payload_base64="$(printf '%s' "$permanent_token_payload" | tr '_-' '/+')"
    case $((${#permanent_token_payload_base64} % 4)) in
        0)
            ;;
        2)
            permanent_token_payload_base64="${permanent_token_payload_base64}=="
            ;;
        3)
            permanent_token_payload_base64="${permanent_token_payload_base64}="
            ;;
        *)
            echo "ERROR: Client Credentials returned an invalid JWT payload length." >&2
            return 1
            ;;
    esac
    if ! printf '%s' "$permanent_token_payload_base64" \
            | base64 -d > "$PERMANENT_TOKEN_PAYLOAD_FILE" 2>/dev/null; then
        echo "ERROR: Client Credentials JWT payload could not be decoded." >&2
        return 1
    fi
    if ! /bin/bash "$RUNTIME_JSON_VALIDATOR" \
            token \
            "$PERMANENT_TOKEN_PAYLOAD_FILE" \
            "$KEYCLOAK_PROVISIONING_CLIENT_ID" \
            "$MANAGED_REALMS_FILE"; then
        echo "ERROR: Client Credentials token failed the exact structural least-privilege proof." >&2
        return 1
    fi
}

client_count=0
client_uuid=""
client_inventory_complete=false

if [ "$FORCE_RECONCILE" = false ]; then
    rm -f "$KCADM_CONFIG"
    if authenticate_client_credentials \
            "$KEYCLOAK_PROVISIONING_CLIENT_ID" \
            "$KEYCLOAK_PROVISIONING_CLIENT_SECRET"; then
        chmod 600 "$KCADM_CONFIG"
        if ! verify_permanent_token_exact_privileges; then
            echo "ERROR: The permanent Keycloak identity authenticated, but its exact effective least-privilege state could not be proved." >&2
            echo "ERROR: Run the approved reconciler with KEYCLOAK_FORCE_RECONCILE=true." >&2
            exit 1
        fi
        if ! "$SUPER_ADMIN_IDENTITY_RECONCILER" verify "$KCADM_CONFIG"; then
            echo "ERROR: The DEV Super Admin identity is not ready. Run the documented persisted-volume migration." >&2
            exit 1
        fi
        if ! "$REALM_SMTP_RECONCILER" verify "$KCADM_CONFIG"; then
            echo "ERROR: Keycloak realm password-recovery SMTP is not ready. Run the documented persisted-volume migration." >&2
            exit 1
        fi
        if ! "$BILLING_MFA_AMR_RECONCILER" verify "$KCADM_CONFIG"; then
            echo "ERROR: The permanent Keycloak identity is least-privileged, but the Billing MFA AMR contract is not ready." >&2
            echo "ERROR: Run the documented one-time persisted-volume migration; normal startup never elevates privileges to repair it." >&2
            exit 1
        fi
        if ! "$ADMIN_LOGIN_MFA_RECONCILER" verify "$KCADM_CONFIG"; then
            echo "ERROR: The administrative login MFA state is not ready. Run the documented persisted-volume migration." >&2
            exit 1
        fi
        if ! "$TENANT_FIRST_LOGIN_MFA_RECONCILER" verify "$KCADM_CONFIG"; then
            echo "ERROR: Tenant first-login MFA state is not ready. Run the documented persisted-volume migration." >&2
            exit 1
        fi
        echo "Keycloak technical management identity is ready with exact effective privileges."
        exit 0
    fi

    # A new installation cannot authenticate the permanent client before it is
    # created. Bootstrap credentials may classify that exact case, but normal
    # init must never repair an existing inaccessible identity implicitly.
    rm -f "$KCADM_CONFIG"
    authenticate_bootstrap_identity
    if [ "$bootstrap_authenticated" != true ]; then
        echo "ERROR: The permanent Keycloak identity could not authenticate and no bootstrap identity could classify a first installation." >&2
        echo "ERROR: Run the documented one-time persisted-volume migration." >&2
        exit 1
    fi
    chmod 600 "$KCADM_CONFIG"
    inventory_permanent_management_client
    client_inventory_complete=true
    if [ "$client_count" -ne 0 ]; then
        echo "ERROR: The permanent Keycloak identity exists but could not authenticate; normal init will not mutate persisted identity state." >&2
        echo "ERROR: Run the approved reconciler with KEYCLOAK_FORCE_RECONCILE=true." >&2
        exit 1
    fi
fi

# Forced mode always authenticates a reviewed bootstrap/recovery identity.
# Normal mode reaches this mutating path only after proving the permanent client
# is absent, which is the bounded first-install case frozen in the rollout plan.
if [ "$FORCE_RECONCILE" = true ]; then
    rm -f "$KCADM_CONFIG"
    authenticate_bootstrap_identity
fi

if [ "$bootstrap_authenticated" != true ]; then
    echo "ERROR: Forced reconciliation could not authenticate with the configured bootstrap or recovery identity." >&2
    echo "ERROR: Run the documented one-time persisted-volume migration; never replace this with a personal admin password in the backend." >&2
    exit 1
fi
chmod 600 "$KCADM_CONFIG"

printf '{"clientId":"%s","enabled":true,"publicClient":false,"bearerOnly":false,"standardFlowEnabled":false,"implicitFlowEnabled":false,"directAccessGrantsEnabled":false,"serviceAccountsEnabled":true,"fullScopeAllowed":true,"clientAuthenticatorType":"client-secret","protocol":"openid-connect","secret":"%s","attributes":{"saas.provisioning.managed-by":"saas-service","saas.provisioning.contract-version":"1"}}\n' \
    "$KEYCLOAK_PROVISIONING_CLIENT_ID" \
    "$KEYCLOAK_PROVISIONING_CLIENT_SECRET" \
    > "$CLIENT_PAYLOAD_FILE"
chmod 600 "$CLIENT_PAYLOAD_FILE"

if [ "$client_inventory_complete" != true ]; then
    inventory_permanent_management_client
fi

if [ -z "$client_uuid" ]; then
    client_uuid="$(kcadm create clients -r master -i -f "$CLIENT_PAYLOAD_FILE")"
else
    verify_existing_client_ownership "$client_uuid"
    kcadm update "clients/$client_uuid" \
        -r master \
        -f "$CLIENT_PAYLOAD_FILE" >/dev/null
fi
case "$client_uuid" in
    ""|*[!0-9a-fA-F-]*)
        echo "ERROR: Keycloak returned an invalid managed technical-client identifier." >&2
        exit 1
        ;;
esac

service_account_json="$(kcadm get "clients/$client_uuid/service-account-user" -r master --fields id)"
service_account_id="$(printf '%s\n' "$service_account_json" | extract_first_id)"
if [ -z "$service_account_id" ]; then
    echo "ERROR: Keycloak did not expose the service-account user for the technical client." >&2
    exit 1
fi
case "$service_account_id" in
    *[!0-9a-fA-F-]*)
        echo "ERROR: Keycloak returned an invalid service-account user identifier." >&2
        exit 1
        ;;
esac

require_payload_safe_role_name() {
    role_name_to_validate="$1"
    role_validation_context="$2"
    if ! printf '%s\n' "$role_name_to_validate" \
            | LC_ALL=C grep -Eq '^[A-Za-z0-9_.:-]+$'; then
        echo "ERROR: Unsafe or ambiguous role name in $role_validation_context." >&2
        exit 1
    fi
}

reconcile_global_realm_roles() {
    kcadm get "users/$service_account_id/role-mappings/realm" \
        -r master \
        --fields id,name \
        --format csv \
        --noquotes > "$ROLE_MAPPINGS_FILE"

    separator=""
    extra_role_count=0
    printf '[' > "$ROLE_DELETE_PAYLOAD"
    while IFS=, read -r mapped_role_uuid mapped_role_name \
            || [ -n "$mapped_role_uuid$mapped_role_name" ]; do
        mapped_role_uuid="$(printf '%s' "$mapped_role_uuid" | tr -d '\r')"
        mapped_role_name="$(printf '%s' "$mapped_role_name" | tr -d '\r')"
        [ -n "$mapped_role_uuid$mapped_role_name" ] || continue
        case "$mapped_role_uuid" in
            ""|*[!0-9a-fA-F-]*)
                echo "ERROR: Invalid direct realm-role identifier on the technical identity." >&2
                exit 1
                ;;
        esac
        if [ "$mapped_role_name" != create-realm ]; then
            require_payload_safe_role_name \
                "$mapped_role_name" \
                "direct master realm-role mappings"
            printf '%s{"id":"%s","name":"%s"}' \
                "$separator" "$mapped_role_uuid" "$mapped_role_name" \
                >> "$ROLE_DELETE_PAYLOAD"
            separator=,
            extra_role_count=$((extra_role_count + 1))
        fi
    done < "$ROLE_MAPPINGS_FILE"
    printf ']' >> "$ROLE_DELETE_PAYLOAD"
    if [ "$extra_role_count" -gt 0 ]; then
        kcadm delete "users/$service_account_id/role-mappings/realm" \
            -r master \
            -f "$ROLE_DELETE_PAYLOAD" >/dev/null
    fi

    kcadm add-roles -r master \
        --uid "$service_account_id" \
        --rolename create-realm >/dev/null

    kcadm get "users/$service_account_id/role-mappings/realm" \
        -r master \
        --fields name \
        --format csv \
        --noquotes > "$ROLE_NAMES_FILE"
    verify_exact_role_names create-realm 1 "direct master realm-role mappings"

    kcadm get "users/$service_account_id/role-mappings/realm/composite" \
        -r master \
        --fields name \
        --format csv \
        --noquotes > "$ROLE_NAMES_FILE"
    verify_exact_role_names create-realm 1 "effective master realm-role mappings"
}

reconcile_realm_management_roles() {
    management_client_uuid="$1"
    expected_roles="$2"
    expected_role_count="$3"
    expected_effective_roles="$4"
    expected_effective_role_count="$5"
    verification_context="$6"

    kcadm get "users/$service_account_id/role-mappings/clients/$management_client_uuid" \
        -r master \
        --fields id,name \
        --format csv \
        --noquotes > "$ROLE_MAPPINGS_FILE"

    separator=""
    extra_role_count=0
    printf '[' > "$ROLE_DELETE_PAYLOAD"
    while IFS=, read -r mapped_role_uuid mapped_role_name \
            || [ -n "$mapped_role_uuid$mapped_role_name" ]; do
        mapped_role_uuid="$(printf '%s' "$mapped_role_uuid" | tr -d '\r')"
        mapped_role_name="$(printf '%s' "$mapped_role_name" | tr -d '\r')"
        [ -n "$mapped_role_uuid$mapped_role_name" ] || continue
        case "$mapped_role_uuid" in
            ""|*[!0-9a-fA-F-]*)
                echo "ERROR: Invalid realm-management role identifier on the technical identity." >&2
                exit 1
                ;;
        esac
        case " $expected_roles " in
            *" $mapped_role_name "*)
                ;;
            *)
                require_payload_safe_role_name \
                    "$mapped_role_name" \
                    "$verification_context"
                printf '%s{"id":"%s","name":"%s"}' \
                    "$separator" "$mapped_role_uuid" "$mapped_role_name" \
                    >> "$ROLE_DELETE_PAYLOAD"
                separator=,
                extra_role_count=$((extra_role_count + 1))
                ;;
        esac
    done < "$ROLE_MAPPINGS_FILE"
    printf ']' >> "$ROLE_DELETE_PAYLOAD"
    if [ "$extra_role_count" -gt 0 ]; then
        kcadm delete "users/$service_account_id/role-mappings/clients/$management_client_uuid" \
            -r master \
            -f "$ROLE_DELETE_PAYLOAD" >/dev/null
    fi

    if [ "$expected_role_count" -gt 0 ]; then
        kcadm add-roles -r master \
            --uid "$service_account_id" \
            --cid "$management_client_uuid" \
            --rolename manage-users \
            --rolename query-users \
            --rolename view-users \
            --rolename view-realm >/dev/null
    fi

    kcadm get "users/$service_account_id/role-mappings/clients/$management_client_uuid" \
        -r master \
        --fields name \
        --format csv \
        --noquotes > "$ROLE_NAMES_FILE"
    verify_exact_role_names "$expected_roles" "$expected_role_count" "direct $verification_context"

    kcadm get "users/$service_account_id/role-mappings/clients/$management_client_uuid/composite" \
        -r master \
        --fields name \
        --format csv \
        --noquotes > "$ROLE_NAMES_FILE"
    verify_exact_role_names \
        "$expected_effective_roles" \
        "$expected_effective_role_count" \
        "effective $verification_context"
}

enumerate_master_clients() {
    : > "$ALL_MASTER_CLIENTS_FILE"
    : > "$MANAGEMENT_CLIENTS_FILE"
    page_size="$ADMIN_API_PAGE_SIZE"
    max_items="$ADMIN_API_MAX_ITEMS"
    first=0
    total_count=0
    while :; do
        kcadm get clients \
            -r master \
            -q "first=$first" \
            -q "max=$page_size" \
            --fields id,clientId \
            --format csv \
            --noquotes > "$MASTER_CLIENTS_PAGE_FILE"
        page_count=0
        while IFS=, read -r candidate_client_uuid candidate_client_id \
                || [ -n "$candidate_client_uuid$candidate_client_id" ]; do
            candidate_client_uuid="$(printf '%s' "$candidate_client_uuid" | tr -d '\r')"
            candidate_client_id="$(printf '%s' "$candidate_client_id" | tr -d '\r')"
            [ -n "$candidate_client_uuid$candidate_client_id" ] || continue
            page_count=$((page_count + 1))
            if [ "$page_count" -gt "$page_size" ]; then
                echo "ERROR: Keycloak returned more master clients than the requested page size." >&2
                exit 1
            fi
            case "$candidate_client_uuid" in
                ""|*[!0-9a-fA-F-]*)
                    echo "ERROR: Invalid client identifier in master." >&2
                    exit 1
                    ;;
            esac
            if grep -Fq "$candidate_client_uuid," "$ALL_MASTER_CLIENTS_FILE"; then
                echo "ERROR: Duplicate or non-advancing master-client page returned by Keycloak." >&2
                exit 1
            fi
            total_count=$((total_count + 1))
            if [ "$total_count" -gt "$max_items" ]; then
                echo "ERROR: Master-client pagination exceeded the bounded item limit." >&2
                exit 1
            fi
            printf '%s,%s\n' "$candidate_client_uuid" "$candidate_client_id" \
                >> "$ALL_MASTER_CLIENTS_FILE"
            case "$candidate_client_id" in
                realm-management|*-realm)
                    printf '%s,%s\n' "$candidate_client_uuid" "$candidate_client_id" \
                        >> "$MANAGEMENT_CLIENTS_FILE"
                    ;;
            esac
        done < "$MASTER_CLIENTS_PAGE_FILE"
        [ "$page_count" -eq "$page_size" ] || break
        if [ "$total_count" -ge "$max_items" ]; then
            echo "ERROR: Master-client pagination reached its limit on a full page." >&2
            exit 1
        fi
        next_first=$((first + page_count))
        if [ "$next_first" -le "$first" ]; then
            echo "ERROR: Master-client pagination did not advance." >&2
            exit 1
        fi
        first="$next_first"
    done
}

# Reconcile direct and effective privileges to the exact minimum: create-realm
# globally, plus four user-management roles only for allowlisted static realms.
enumerate_master_clients
reconcile_global_realm_roles

while IFS= read -r realm_name || [ -n "$realm_name" ]; do
    [ -n "$realm_name" ] || continue
    realm_management_client="${realm_name}-realm"
    realm_client_count=0
    realm_client_uuid=""
    while IFS=, read -r candidate_client_uuid candidate_client_id \
            || [ -n "$candidate_client_uuid$candidate_client_id" ]; do
        if [ "$candidate_client_id" = "$realm_management_client" ]; then
            realm_client_count=$((realm_client_count + 1))
            realm_client_uuid="$candidate_client_uuid"
        fi
    done < "$MANAGEMENT_CLIENTS_FILE"
    if [ "$realm_client_count" -ne 1 ]; then
        echo "ERROR: Expected exactly one allowlisted realm-management client in master." >&2
        exit 1
    fi
    reconcile_realm_management_roles \
        "$realm_client_uuid" \
        "$EXPECTED_MANAGEMENT_ROLES" \
        4 \
        "$EXPECTED_EFFECTIVE_MANAGEMENT_ROLES" \
        5 \
        "allowlisted realm-management mappings"
done < "$MANAGED_REALMS_FILE"

# Detect and revoke service-account mappings on realm-management clients that
# are outside the allowlist. These calls touch mappings in master only; no
# non-allowlisted realm is queried or mutated.
while IFS=, read -r candidate_client_uuid candidate_client_id \
        || [ -n "$candidate_client_uuid$candidate_client_id" ]; do
    case "$candidate_client_id" in
        realm-management)
            realm_is_allowlisted=false
            ;;
        *-realm)
            candidate_realm="${candidate_client_id%-realm}"
            if grep -Fxq "$candidate_realm" "$MANAGED_REALMS_FILE"; then
                realm_is_allowlisted=true
            else
                realm_is_allowlisted=false
            fi
            ;;
        *)
            continue
            ;;
    esac
    if [ "$realm_is_allowlisted" = false ]; then
        reconcile_realm_management_roles \
            "$candidate_client_uuid" \
            "" \
            0 \
            "" \
            0 \
            "non-allowlisted realm-management mappings"
    fi
done < "$MANAGEMENT_CLIENTS_FILE"

# No role from any other master client belongs to the technical identity
# allowlist. Revoke direct drift and fail closed if inherited/effective drift
# remains, still without querying or mutating any non-allowlisted realm.
while IFS=, read -r candidate_client_uuid candidate_client_id \
        || [ -n "$candidate_client_uuid$candidate_client_id" ]; do
    case "$candidate_client_id" in
        realm-management|*-realm)
            continue
            ;;
    esac
    reconcile_realm_management_roles \
        "$candidate_client_uuid" \
        "" \
        0 \
        "" \
        0 \
        "non-management master-client mappings"
done < "$ALL_MASTER_CLIENTS_FILE"

# First installation and explicit forced recovery run under a reviewed bootstrap
# identity. Reconcile the DEV human identity and the two bounded browser
# authenticator configs before discarding that authority; the permanent
# technical identity only verifies these contracts on subsequent starts.
if ! "$SUPER_ADMIN_IDENTITY_RECONCILER" reconcile "$KCADM_CONFIG"; then
    echo "ERROR: The DEV Super Admin identity could not be reconciled." >&2
    exit 1
fi
if ! "$REALM_SMTP_RECONCILER" reconcile "$KCADM_CONFIG"; then
    echo "ERROR: Keycloak realm password-recovery SMTP could not be reconciled." >&2
    exit 1
fi
if ! "$BILLING_MFA_AMR_RECONCILER" reconcile "$KCADM_CONFIG"; then
    echo "ERROR: Billing MFA AMR execution references could not be reconciled." >&2
    exit 1
fi
if ! "$ADMIN_LOGIN_MFA_RECONCILER" reconcile "$KCADM_CONFIG"; then
    echo "ERROR: Administrative login MFA state could not be reconciled." >&2
    exit 1
fi
if ! "$TENANT_FIRST_LOGIN_MFA_RECONCILER" reconcile "$KCADM_CONFIG"; then
    echo "ERROR: Tenant first-login MFA state could not be reconciled." >&2
    exit 1
fi

rm -f "$KCADM_CONFIG"
if ! authenticate_client_credentials \
        "$KEYCLOAK_PROVISIONING_CLIENT_ID" \
        "$KEYCLOAK_PROVISIONING_CLIENT_SECRET"; then
    echo "ERROR: The Keycloak technical identity was created but client_credentials validation failed." >&2
    exit 1
fi
chmod 600 "$KCADM_CONFIG"
if ! verify_permanent_token_exact_privileges; then
    echo "ERROR: Forced reconciliation completed, but the permanent token does not prove the exact effective privilege set." >&2
    exit 1
fi
if ! "$SUPER_ADMIN_IDENTITY_RECONCILER" verify "$KCADM_CONFIG"; then
    echo "ERROR: The DEV Super Admin identity failed permanent-identity verification." >&2
    exit 1
fi
if ! "$REALM_SMTP_RECONCILER" verify "$KCADM_CONFIG"; then
    echo "ERROR: Keycloak realm password-recovery SMTP failed permanent-identity verification." >&2
    exit 1
fi
if ! "$BILLING_MFA_AMR_RECONCILER" verify "$KCADM_CONFIG"; then
    echo "ERROR: Billing MFA AMR execution references failed permanent-identity verification." >&2
    exit 1
fi
if ! "$ADMIN_LOGIN_MFA_RECONCILER" verify "$KCADM_CONFIG"; then
    echo "ERROR: Administrative login MFA state failed permanent-identity verification." >&2
    exit 1
fi
if ! "$TENANT_FIRST_LOGIN_MFA_RECONCILER" verify "$KCADM_CONFIG"; then
    echo "ERROR: Tenant first-login MFA state failed permanent-identity verification." >&2
    exit 1
fi

echo "Keycloak technical management identity was provisioned successfully."
