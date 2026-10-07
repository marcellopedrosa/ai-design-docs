#!/usr/bin/env bash

set -Eeuo pipefail

REPOSITORY_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
FIXTURE_ROOT="$(mktemp -d)"
SERVICE_SCRIPT="$FIXTURE_ROOT/ensure-management-service-account.sh"
FAKE_KCADM="$FIXTURE_ROOT/kcadm.sh"
FAKE_BILLING_MFA_RECONCILER="$FIXTURE_ROOT/reconcile-billing-mfa-amr.sh"
FAKE_ADMIN_LOGIN_MFA_RECONCILER="$FIXTURE_ROOT/reconcile-admin-login-mfa.sh"
FAKE_TENANT_FIRST_LOGIN_MFA_RECONCILER="$FIXTURE_ROOT/reconcile-tenant-first-login-mfa.sh"
FAKE_SUPER_ADMIN_IDENTITY_RECONCILER="$FIXTURE_ROOT/reconcile-super-admin-identity.sh"
FAKE_REALM_SMTP_RECONCILER="$FIXTURE_ROOT/reconcile-realm-smtp.sh"
RUNTIME_JSON_VALIDATOR="$REPOSITORY_ROOT/infra/keycloak/bootstrap/validate-keycloak-runtime-json.sh"

cleanup() {
    rm -rf -- "$FIXTURE_ROOT"
}
trap cleanup EXIT

fail() {
    echo "FAIL: $*" >&2
    exit 1
}

for command_name in awk base64 bash cat chmod cp dirname find grep jq mkdir mktemp mv sed stat tr wc; do
    command -v "$command_name" >/dev/null 2>&1 \
        || fail "required command is unavailable: $command_name"
done

EXACT_TOKEN_PAYLOAD='{"azp":"synthetic-provisioner","realm_access":{"roles":["create-realm"]},"resource_access":{"saas-admin-realm":{"roles":["manage-users","query-groups","query-users","view-users","view-realm"]},"saas-bpfarias-realm":{"roles":["manage-users","query-groups","query-users","view-users","view-realm"]}}}'
EXACT_TOKEN_PAYLOAD_B64="$(printf '%s' "$EXACT_TOKEN_PAYLOAD" \
    | base64 | tr -d '\n=' | tr '+/' '-_')"
EXACT_TOKEN="e30.$EXACT_TOKEN_PAYLOAD_B64.signature"
DRIFT_TOKEN_PAYLOAD='{"azp":"synthetic-provisioner","realm_access":{"roles":["create-realm","view-realm"]},"resource_access":{"saas-admin-realm":{"roles":["manage-users","query-groups","query-users","view-users","view-realm"]},"saas-bpfarias-realm":{"roles":["manage-users","query-groups","query-users","view-users","view-realm"]}}}'
DRIFT_TOKEN_PAYLOAD_B64="$(printf '%s' "$DRIFT_TOKEN_PAYLOAD" \
    | base64 | tr -d '\n=' | tr '+/' '-_')"
DRIFT_TOKEN="e30.$DRIFT_TOKEN_PAYLOAD_B64.signature"
CANONICAL_TOKEN_PAYLOAD='{"azp":"saas-realm-provisioner","realm_access":{"roles":["create-realm"]},"resource_access":{"saas-admin-realm":{"roles":["manage-users","query-groups","query-users","view-users","view-realm"]},"saas-bpfarias-realm":{"roles":["manage-users","query-groups","query-users","view-users","view-realm"]}}}'
CANONICAL_TOKEN_PAYLOAD_B64="$(printf '%s' "$CANONICAL_TOKEN_PAYLOAD" \
    | base64 | tr -d '\n=' | tr '+/' '-_')"
CANONICAL_TOKEN="e30.$CANONICAL_TOKEN_PAYLOAD_B64.signature"
DECOY_TOKEN_PAYLOAD='{"azp":"synthetic-provisioner","decoy":{"realm_access":{"roles":["create-realm"]},"resource_access":{"saas-admin-realm":{"roles":["manage-users","query-groups","query-users","view-users","view-realm"]},"saas-bpfarias-realm":{"roles":["manage-users","query-groups","query-users","view-users","view-realm"]}}}}'
DECOY_TOKEN_PAYLOAD_B64="$(printf '%s' "$DECOY_TOKEN_PAYLOAD" \
    | base64 | tr -d '\n=' | tr '+/' '-_')"
DECOY_TOKEN="e30.$DECOY_TOKEN_PAYLOAD_B64.signature"

cp "$REPOSITORY_ROOT/infra/keycloak/bootstrap/ensure-management-service-account.sh" "$SERVICE_SCRIPT"
sed -i \
    -e "s|^KCADM=.*|KCADM=\"$FAKE_KCADM\"|" \
    -e "s|^RUNTIME_JSON_VALIDATOR=.*|RUNTIME_JSON_VALIDATOR=\"$RUNTIME_JSON_VALIDATOR\"|" \
    -e "s|^BILLING_MFA_AMR_RECONCILER=.*|BILLING_MFA_AMR_RECONCILER=\"$FAKE_BILLING_MFA_RECONCILER\"|" \
    -e "s|^ADMIN_LOGIN_MFA_RECONCILER=.*|ADMIN_LOGIN_MFA_RECONCILER=\"$FAKE_ADMIN_LOGIN_MFA_RECONCILER\"|" \
    -e "s|^TENANT_FIRST_LOGIN_MFA_RECONCILER=.*|TENANT_FIRST_LOGIN_MFA_RECONCILER=\"$FAKE_TENANT_FIRST_LOGIN_MFA_RECONCILER\"|" \
    -e "s|^SUPER_ADMIN_IDENTITY_RECONCILER=.*|SUPER_ADMIN_IDENTITY_RECONCILER=\"$FAKE_SUPER_ADMIN_IDENTITY_RECONCILER\"|" \
    -e "s|^REALM_SMTP_RECONCILER=.*|REALM_SMTP_RECONCILER=\"$FAKE_REALM_SMTP_RECONCILER\"|" \
    -e "s|/tmp/kcadm|$FIXTURE_ROOT/kcadm|g" \
    "$SERVICE_SCRIPT"
chmod 700 "$SERVICE_SCRIPT"

cat > "$FAKE_KCADM" <<'EOF'
#!/bin/sh
set -eu

printf "%s\n" "$*" >> "${FAKE_KCADM_LOG:?}"
case " $* " in
    *" --password "*|*" --secret "*) exit 91 ;;
esac
if [ "${1:-}" = config ] && [ "${2:-}" = credentials ]; then
    config_file=""
    previous_argument=""
    for argument in "$@"; do
        if [ "$previous_argument" = --config ]; then
            config_file="$argument"
        fi
        previous_argument="$argument"
    done
    case " $* " in
        *" --client "*) [ "${KC_CLI_CLIENT_SECRET:-}" = "${FAKE_EXPECTED_CLIENT_SECRET:?}" ] || exit 92 ;;
        *" --user "*) [ "${KC_CLI_PASSWORD:-}" = "${FAKE_EXPECTED_USER_PASSWORD:?}" ] || exit 93 ;;
        *) exit 94 ;;
    esac
    [ -n "$config_file" ] || exit 95
    printf '{"token":"%s"}\n' "${FAKE_KCADM_TOKEN:?}" > "$config_file"
    exit 0
fi
if [ "${1:-}" = get ] && [ "${2:-}" = clients ] \
        && [ -f "${FAKE_MANAGED_REALMS_FILE:?}" ]; then
    printf "%s\n" managed-realms-preserved >> "${FAKE_KCADM_LOG:?}"
fi
exit 1
EOF
chmod 700 "$FAKE_KCADM"

cat > "$FAKE_BILLING_MFA_RECONCILER" <<'EOF'
#!/bin/sh
set -eu
case "${1:-}" in
    verify|reconcile) ;;
    *) exit 91 ;;
esac
[ -f "${2:-}" ] || exit 92
exit 0
EOF
chmod 700 "$FAKE_BILLING_MFA_RECONCILER"

cp "$FAKE_BILLING_MFA_RECONCILER" "$FAKE_ADMIN_LOGIN_MFA_RECONCILER"
chmod 700 "$FAKE_ADMIN_LOGIN_MFA_RECONCILER"
cp "$FAKE_BILLING_MFA_RECONCILER" "$FAKE_TENANT_FIRST_LOGIN_MFA_RECONCILER"
chmod 700 "$FAKE_TENANT_FIRST_LOGIN_MFA_RECONCILER"
cp "$FAKE_BILLING_MFA_RECONCILER" "$FAKE_SUPER_ADMIN_IDENTITY_RECONCILER"
chmod 700 "$FAKE_SUPER_ADMIN_IDENTITY_RECONCILER"
cp "$FAKE_BILLING_MFA_RECONCILER" "$FAKE_REALM_SMTP_RECONCILER"
chmod 700 "$FAKE_REALM_SMTP_RECONCILER"

run_service_bootstrap() {
    FAKE_KCADM_LOG="$FIXTURE_ROOT/kcadm.log" \
    FAKE_MANAGED_REALMS_FILE="$FIXTURE_ROOT/kcadm-managed-realms.list" \
    FAKE_KCADM_TOKEN="${3:-$EXACT_TOKEN}" \
    FAKE_EXPECTED_CLIENT_SECRET=synthetic-secret-0123456789abcdef \
    FAKE_EXPECTED_USER_PASSWORD=synthetic-password \
    KEYCLOAK_PROVISIONING_CLIENT_ID=synthetic-provisioner \
    KEYCLOAK_PROVISIONING_CLIENT_SECRET=synthetic-secret-0123456789abcdef \
    KEYCLOAK_EXISTING_MANAGED_REALMS="$1" \
    KEYCLOAK_FORCE_RECONCILE="${2:-false}" \
    KEYCLOAK_BOOTSTRAP_ADMIN_USER=synthetic-bootstrap \
    KEYCLOAK_BOOTSTRAP_ADMIN_PASSWORD=synthetic-password \
        "$SERVICE_SCRIPT"
}

: > "$FIXTURE_ROOT/kcadm.log"
if ! run_service_bootstrap 'saas-admin,saas-bpfarias' > "$FIXTURE_ROOT/valid.log" 2>&1; then
    fail "an exact managed-realm allowlist was rejected"
fi
grep -Fq 'Keycloak technical management identity is ready with exact effective privileges.' "$FIXTURE_ROOT/valid.log" \
    || fail "valid allowlist did not reach technical-identity verification"

invalid_allowlists=(
    ''
    'saas-admin,saas-admin'
    'saas-admin, saas-bpfarias'
    'saas-admin,'
    'saas-*'
    'master'
)
for invalid_allowlist in "${invalid_allowlists[@]}"; do
    if run_service_bootstrap "$invalid_allowlist" > "$FIXTURE_ROOT/invalid.log" 2>&1; then
        fail "an invalid or duplicate managed-realm allowlist was accepted"
    fi
done

: > "$FIXTURE_ROOT/kcadm.log"
if run_service_bootstrap 'saas-admin,saas-bpfarias' true \
        > "$FIXTURE_ROOT/forced.log" 2>&1; then
    fail "forced reconciliation returned early after client_credentials authentication"
fi
if grep -Fq 'Keycloak technical management identity is ready.' "$FIXTURE_ROOT/forced.log"; then
    fail "forced reconciliation emitted the early-success readiness message"
fi
grep -Fq 'get clients -r master -q clientId=synthetic-provisioner' \
    "$FIXTURE_ROOT/kcadm.log" \
    || fail "forced reconciliation did not continue into provisioning inspection"
grep -Fxq managed-realms-preserved "$FIXTURE_ROOT/kcadm.log" \
    || fail "bootstrap-authentication fallback discarded the validated managed-realm allowlist"

: > "$FIXTURE_ROOT/kcadm.log"
if run_service_bootstrap 'saas-admin,saas-bpfarias' false "$DRIFT_TOKEN" \
        > "$FIXTURE_ROOT/normal-drift.log" 2>&1; then
    fail "normal init accepted an overprivileged permanent token"
fi
grep -Fq 'KEYCLOAK_FORCE_RECONCILE=true' "$FIXTURE_ROOT/normal-drift.log" \
    || fail "normal init drift did not direct the operator to forced reconciliation"
if grep -Eq '^(create|update|delete|add-roles) ' "$FIXTURE_ROOT/kcadm.log"; then
    fail "normal init mutated Keycloak while proving permanent privileges"
fi
if grep -Fq 'synthetic-secret-0123456789abcdef' "$FIXTURE_ROOT/kcadm.log"; then
    fail "client secret appeared in kcadm argv"
fi

: > "$FIXTURE_ROOT/kcadm.log"
if run_service_bootstrap 'saas-admin,saas-bpfarias' false "$DECOY_TOKEN" \
        > "$FIXTURE_ROOT/normal-decoy.log" 2>&1; then
    fail "normal init accepted nested structural token decoys"
fi
if grep -Eq '^(create|update|delete|add-roles) ' "$FIXTURE_ROOT/kcadm.log"; then
    fail "normal init mutated Keycloak after a structural token decoy"
fi

SIGNAL_ROOT="$FIXTURE_ROOT/signal-termination"
SIGNAL_SERVICE_SCRIPT="$SIGNAL_ROOT/ensure-management-service-account.sh"
SIGNAL_FAKE_KCADM="$SIGNAL_ROOT/kcadm.sh"
mkdir -p "$SIGNAL_ROOT"
cp "$REPOSITORY_ROOT/infra/keycloak/bootstrap/ensure-management-service-account.sh" \
    "$SIGNAL_SERVICE_SCRIPT"
sed -i \
    -e "s|^KCADM=.*|KCADM=\"$SIGNAL_FAKE_KCADM\"|" \
    -e "s|^RUNTIME_JSON_VALIDATOR=.*|RUNTIME_JSON_VALIDATOR=\"$RUNTIME_JSON_VALIDATOR\"|" \
    -e "s|^BILLING_MFA_AMR_RECONCILER=.*|BILLING_MFA_AMR_RECONCILER=\"$FAKE_BILLING_MFA_RECONCILER\"|" \
    -e "s|^ADMIN_LOGIN_MFA_RECONCILER=.*|ADMIN_LOGIN_MFA_RECONCILER=\"$FAKE_ADMIN_LOGIN_MFA_RECONCILER\"|" \
    -e "s|^TENANT_FIRST_LOGIN_MFA_RECONCILER=.*|TENANT_FIRST_LOGIN_MFA_RECONCILER=\"$FAKE_TENANT_FIRST_LOGIN_MFA_RECONCILER\"|" \
    -e "s|^SUPER_ADMIN_IDENTITY_RECONCILER=.*|SUPER_ADMIN_IDENTITY_RECONCILER=\"$FAKE_SUPER_ADMIN_IDENTITY_RECONCILER\"|" \
    -e "s|^REALM_SMTP_RECONCILER=.*|REALM_SMTP_RECONCILER=\"$FAKE_REALM_SMTP_RECONCILER\"|" \
    -e "s|/tmp/kcadm|$SIGNAL_ROOT/kcadm|g" \
    "$SIGNAL_SERVICE_SCRIPT"
chmod 700 "$SIGNAL_SERVICE_SCRIPT"
cat > "$SIGNAL_FAKE_KCADM" <<'EOF'
#!/bin/sh
set -eu
printf '%s\n' "$*" >> "${SIGNAL_KCADM_LOG:?}"
config_file=""
previous_argument=""
for argument in "$@"; do
    if [ "$previous_argument" = --config ]; then
        config_file="$argument"
    fi
    previous_argument="$argument"
done
[ -n "$config_file" ] && printf '%s\n' temporary-session > "$config_file"
kill -s "${SIGNAL_KIND:?}" "$PPID"
exit 0
EOF
chmod 700 "$SIGNAL_FAKE_KCADM"

for signal_contract in INT:130 TERM:143; do
    signal_kind="${signal_contract%%:*}"
    expected_signal_status="${signal_contract#*:}"
    signal_log="$SIGNAL_ROOT/$signal_kind.log"
    : > "$signal_log"
    set +e
    SIGNAL_KIND="$signal_kind" \
    SIGNAL_KCADM_LOG="$signal_log" \
    KEYCLOAK_PROVISIONING_CLIENT_ID=synthetic-provisioner \
    KEYCLOAK_PROVISIONING_CLIENT_SECRET=synthetic-secret-0123456789abcdef \
    KEYCLOAK_EXISTING_MANAGED_REALMS=saas-admin \
    KEYCLOAK_BOOTSTRAP_ADMIN_USER=synthetic-bootstrap \
    KEYCLOAK_BOOTSTRAP_ADMIN_PASSWORD=synthetic-password \
        "$SIGNAL_SERVICE_SCRIPT" > "$SIGNAL_ROOT/$signal_kind.out" 2>&1
    actual_signal_status=$?
    set -e
    [ "$actual_signal_status" -eq "$expected_signal_status" ] \
        || fail "$signal_kind exited $actual_signal_status instead of $expected_signal_status"
    [ "$(wc -l < "$signal_log" | tr -d '[:space:]')" -eq 1 ] \
        || fail "$signal_kind allowed a Keycloak operation after termination"
    if find "$SIGNAL_ROOT" -maxdepth 1 -name 'kcadm.*' ! -name kcadm.sh -type f | grep -q .; then
        fail "$signal_kind did not clean temporary kcadm files on exit"
    fi
done

SEMANTIC_ROOT="$FIXTURE_ROOT/semantic-reconcile"
SEMANTIC_SERVICE_SCRIPT="$SEMANTIC_ROOT/ensure-management-service-account.sh"
SEMANTIC_FAKE_KCADM="$SEMANTIC_ROOT/kcadm.sh"
SEMANTIC_LOG="$SEMANTIC_ROOT/kcadm.log"
SEMANTIC_GLOBAL_DRIFT_STATE="$SEMANTIC_ROOT/global-drift-removed"
SEMANTIC_CLIENT_DRIFT_STATE="$SEMANTIC_ROOT/client-drift-removed"
SEMANTIC_TECHNICAL_CLIENT_STATE="$SEMANTIC_ROOT/technical-client-created"
mkdir -p "$SEMANTIC_ROOT"
cp "$REPOSITORY_ROOT/infra/keycloak/bootstrap/ensure-management-service-account.sh" \
    "$SEMANTIC_SERVICE_SCRIPT"
sed -i \
    -e "s|^KCADM=.*|KCADM=\"$SEMANTIC_FAKE_KCADM\"|" \
    -e "s|^RUNTIME_JSON_VALIDATOR=.*|RUNTIME_JSON_VALIDATOR=\"$RUNTIME_JSON_VALIDATOR\"|" \
    -e "s|^BILLING_MFA_AMR_RECONCILER=.*|BILLING_MFA_AMR_RECONCILER=\"$FAKE_BILLING_MFA_RECONCILER\"|" \
    -e "s|^ADMIN_LOGIN_MFA_RECONCILER=.*|ADMIN_LOGIN_MFA_RECONCILER=\"$FAKE_ADMIN_LOGIN_MFA_RECONCILER\"|" \
    -e "s|^TENANT_FIRST_LOGIN_MFA_RECONCILER=.*|TENANT_FIRST_LOGIN_MFA_RECONCILER=\"$FAKE_TENANT_FIRST_LOGIN_MFA_RECONCILER\"|" \
    -e "s|^SUPER_ADMIN_IDENTITY_RECONCILER=.*|SUPER_ADMIN_IDENTITY_RECONCILER=\"$FAKE_SUPER_ADMIN_IDENTITY_RECONCILER\"|" \
    -e "s|^REALM_SMTP_RECONCILER=.*|REALM_SMTP_RECONCILER=\"$FAKE_REALM_SMTP_RECONCILER\"|" \
    -e "s|/tmp/kcadm|$SEMANTIC_ROOT/kcadm|g" \
    "$SEMANTIC_SERVICE_SCRIPT"
chmod 700 "$SEMANTIC_SERVICE_SCRIPT"

cat > "$SEMANTIC_FAKE_KCADM" <<'EOF'
#!/bin/sh
set -eu

printf '%s\n' "$*" >> "${SEMANTIC_KCADM_LOG:?}"
command_name="${1:-}"
resource="${2:-}"
arguments=" $* "
service_account_id=22222222-2222-2222-2222-222222222222
technical_client_uuid=11111111-1111-1111-1111-111111111111
admin_management_uuid=33333333-3333-3333-3333-333333333333
tenant_management_uuid=44444444-4444-4444-4444-444444444444
master_management_uuid=55555555-5555-5555-5555-555555555555
configured_client_id="${SEMANTIC_PROVISIONING_CLIENT_ID:-synthetic-provisioner}"

if [ "$command_name" = config ] && [ "$resource" = credentials ]; then
    case " $arguments" in
        *" --password "*|*" --secret "*) exit 91 ;;
    esac
    config_file=""
    previous_argument=""
    for argument in "$@"; do
        if [ "$previous_argument" = --config ]; then
            config_file="$argument"
        fi
        previous_argument="$argument"
    done
    case "$arguments" in
        *" --client "*)
            [ "${KC_CLI_CLIENT_SECRET:-}" = "${SEMANTIC_EXPECTED_CLIENT_SECRET:?}" ] || exit 92
            [ "${SEMANTIC_FORCE_PERMANENT_AUTH_FAILURE:-false}" != true ] || exit 96
            [ -f "${SEMANTIC_TECHNICAL_CLIENT_STATE:?}" ] || exit 97
            ;;
        *" --user "*) [ "${KC_CLI_PASSWORD:-}" = "${SEMANTIC_EXPECTED_USER_PASSWORD:?}" ] || exit 93 ;;
        *) exit 94 ;;
    esac
    [ -n "$config_file" ] || exit 95
    printf '{"token":"%s"}\n' "${SEMANTIC_KCADM_TOKEN:?}" > "$config_file"
    exit 0
fi

if [ "$command_name" = get ] && [ "$resource" = clients ]; then
    case "$arguments" in
        *" clientId=$configured_client_id "*)
            if [ -f "${SEMANTIC_TECHNICAL_CLIENT_STATE:?}" ]; then
                printf '%s\n' "$technical_client_uuid"
            fi
            exit 0
            ;;
        *" first=0 "*" max=100 "*)
            if [ -f "${SEMANTIC_TECHNICAL_CLIENT_STATE:?}" ]; then
                printf '%s,%s\n' "$technical_client_uuid" "$configured_client_id"
            fi
            printf '%s,%s\n' \
                "$admin_management_uuid" saas-admin-realm \
                "$tenant_management_uuid" saas-bpfarias-realm \
                "$master_management_uuid" realm-management
            exit 0
            ;;
    esac
fi

if [ "$command_name" = get ] \
        && [ "$resource" = "clients/$technical_client_uuid" ]; then
    case "${SEMANTIC_EXISTING_CLIENT_OWNERSHIP:-managed}" in
        managed)
            printf '{"id":"%s","clientId":"%s","enabled":true,"publicClient":false,"bearerOnly":false,"standardFlowEnabled":false,"implicitFlowEnabled":false,"directAccessGrantsEnabled":false,"serviceAccountsEnabled":true,"clientAuthenticatorType":"client-secret","protocol":"openid-connect","attributes":{"saas.provisioning.managed-by":"saas-service","saas.provisioning.contract-version":"1"}}\n' \
                "$technical_client_uuid" "$configured_client_id"
            ;;
        unmanaged|legacy-valid)
            printf '{"id":"%s","clientId":"%s","enabled":true,"publicClient":false,"bearerOnly":false,"standardFlowEnabled":false,"implicitFlowEnabled":false,"directAccessGrantsEnabled":false,"serviceAccountsEnabled":true,"clientAuthenticatorType":"client-secret","protocol":"openid-connect","attributes":{}}\n' \
                "$technical_client_uuid" "$configured_client_id"
            ;;
        partial)
            printf '{"id":"%s","clientId":"%s","enabled":true,"publicClient":false,"bearerOnly":false,"standardFlowEnabled":false,"implicitFlowEnabled":false,"directAccessGrantsEnabled":false,"serviceAccountsEnabled":true,"clientAuthenticatorType":"client-secret","protocol":"openid-connect","attributes":{"saas.provisioning.managed-by":"saas-service"}}\n' \
                "$technical_client_uuid" "$configured_client_id"
            ;;
        wrong-marker)
            printf '{"id":"%s","clientId":"%s","enabled":true,"publicClient":false,"bearerOnly":false,"standardFlowEnabled":false,"implicitFlowEnabled":false,"directAccessGrantsEnabled":false,"serviceAccountsEnabled":true,"clientAuthenticatorType":"client-secret","protocol":"openid-connect","attributes":{"saas.provisioning.managed-by":"other","saas.provisioning.contract-version":"2"}}\n' \
                "$technical_client_uuid" "$configured_client_id"
            ;;
        legacy-invalid)
            printf '{"id":"%s","clientId":"%s","enabled":true,"publicClient":false,"bearerOnly":false,"standardFlowEnabled":false,"implicitFlowEnabled":true,"directAccessGrantsEnabled":false,"serviceAccountsEnabled":true,"clientAuthenticatorType":"client-secret","protocol":"openid-connect","attributes":{}}\n' \
                "$technical_client_uuid" "$configured_client_id"
            ;;
        *)
            exit 98
            ;;
    esac
    exit 0
fi

if [ "$command_name" = create ] && [ "$resource" = clients ]; then
    [ ! -f "${SEMANTIC_TECHNICAL_CLIENT_STATE:?}" ] || exit 1
    : > "$SEMANTIC_TECHNICAL_CLIENT_STATE"
    printf '%s\n' "$technical_client_uuid"
    exit 0
fi

if [ "$command_name" = get ] \
        && [ "$resource" = "clients/$technical_client_uuid/service-account-user" ]; then
    printf '{"id":"%s"}\n' "$service_account_id"
    exit 0
fi

if [ "$command_name" = get ] \
        && [ "$resource" = "users/$service_account_id/role-mappings/realm" ]; then
    case "$arguments" in
        *" --fields id,name "*)
            printf '%s,%s\n' \
                aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa create-realm
            if [ ! -f "${SEMANTIC_GLOBAL_DRIFT_STATE:?}" ]; then
                printf '%s,%s\n' \
                    bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb view-all
            fi
            ;;
        *)
            printf '%s\n' create-realm
            ;;
    esac
    exit 0
fi

if [ "$command_name" = get ] \
        && [ "$resource" = "users/$service_account_id/role-mappings/realm/composite" ]; then
    printf '%s\n' create-realm
    exit 0
fi

emit_management_roles() {
    management_uuid="$1"
    include_ids="$2"
    include_effective_inheritance="$3"
    case "$management_uuid" in
        "$admin_management_uuid")
            role_prefix=c
            include_drift=true
            [ -f "${SEMANTIC_CLIENT_DRIFT_STATE:?}" ] && include_drift=false
            ;;
        "$tenant_management_uuid")
            role_prefix=e
            include_drift=false
            ;;
        *)
            return 0
            ;;
    esac

    if [ "$include_ids" = true ]; then
        printf '%s,%s\n' \
            "${role_prefix}0000000-0000-0000-0000-000000000001" manage-users \
            "${role_prefix}0000000-0000-0000-0000-000000000002" query-users \
            "${role_prefix}0000000-0000-0000-0000-000000000003" view-users \
            "${role_prefix}0000000-0000-0000-0000-000000000004" view-realm
        if [ "$include_drift" = true ]; then
            printf '%s,%s\n' \
                dddddddd-dddd-dddd-dddd-dddddddddddd manage-realm \
                ffffffff-ffff-ffff-ffff-ffffffffffff query-groups
        fi
    else
        printf '%s\n' manage-users query-users view-users view-realm
        if [ "$include_effective_inheritance" = true ]; then
            printf '%s\n' query-groups
            if [ "${SEMANTIC_EFFECTIVE_CLIENT_DRIFT:-false}" = true ]; then
                printf '%s\n' manage-realm
            fi
        fi
        if [ "$include_drift" = true ]; then
            printf '%s\n' manage-realm query-groups
        fi
    fi
}

case "$resource" in
    "users/$service_account_id/role-mappings/clients/"*)
        if [ "$command_name" = get ]; then
            management_uuid="${resource#users/$service_account_id/role-mappings/clients/}"
            include_effective_inheritance=false
            case "$management_uuid" in
                */composite)
                    management_uuid="${management_uuid%/composite}"
                    include_effective_inheritance=true
                    ;;
            esac
            case "$arguments" in
                *" --fields id,name "*)
                    emit_management_roles "$management_uuid" true false
                    ;;
                *)
                    emit_management_roles \
                        "$management_uuid" \
                        false \
                        "$include_effective_inheritance"
                    ;;
            esac
            exit 0
        fi
        ;;
esac

if [ "$command_name" = delete ]; then
    payload_file=""
    previous_argument=""
    for argument in "$@"; do
        if [ "$previous_argument" = -f ]; then
            payload_file="$argument"
            break
        fi
        previous_argument="$argument"
    done
    [ -n "$payload_file" ] && [ -f "$payload_file" ] || exit 1
    payload="$(tr -d '\r\n' < "$payload_file")"
    printf 'PAYLOAD %s\n' "$payload" >> "${SEMANTIC_KCADM_LOG:?}"
    case "$resource" in
        "users/$service_account_id/role-mappings/realm")
            printf '%s\n' "$payload" \
                | grep -Fq '"id":"bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb","name":"view-all"' \
                || exit 1
            : > "${SEMANTIC_GLOBAL_DRIFT_STATE:?}"
            exit 0
            ;;
        "users/$service_account_id/role-mappings/clients/$admin_management_uuid")
            printf '%s\n' "$payload" \
                | grep -Fq '"id":"dddddddd-dddd-dddd-dddd-dddddddddddd","name":"manage-realm"' \
                || exit 1
            printf '%s\n' "$payload" \
                | grep -Fq '"id":"ffffffff-ffff-ffff-ffff-ffffffffffff","name":"query-groups"' \
                || exit 1
            : > "${SEMANTIC_CLIENT_DRIFT_STATE:?}"
            exit 0
            ;;
    esac
fi

case "$command_name" in
    update|add-roles)
        exit 0
        ;;
esac

exit 1
EOF
chmod 700 "$SEMANTIC_FAKE_KCADM"

run_semantic_reconcile() {
    SEMANTIC_KCADM_LOG="$SEMANTIC_LOG" \
    SEMANTIC_GLOBAL_DRIFT_STATE="$SEMANTIC_GLOBAL_DRIFT_STATE" \
    SEMANTIC_CLIENT_DRIFT_STATE="$SEMANTIC_CLIENT_DRIFT_STATE" \
    SEMANTIC_TECHNICAL_CLIENT_STATE="$SEMANTIC_TECHNICAL_CLIENT_STATE" \
    SEMANTIC_FORCE_PERMANENT_AUTH_FAILURE="${2:-false}" \
    SEMANTIC_EXISTING_CLIENT_OWNERSHIP="${3:-managed}" \
    SEMANTIC_PROVISIONING_CLIENT_ID="${4:-synthetic-provisioner}" \
    SEMANTIC_KCADM_TOKEN="${5:-$EXACT_TOKEN}" \
    SEMANTIC_EFFECTIVE_CLIENT_DRIFT="${6:-false}" \
    SEMANTIC_EXPECTED_CLIENT_SECRET=synthetic-secret-0123456789abcdef \
    SEMANTIC_EXPECTED_USER_PASSWORD=synthetic-password \
    KEYCLOAK_PROVISIONING_CLIENT_ID="${4:-synthetic-provisioner}" \
    KEYCLOAK_PROVISIONING_CLIENT_SECRET=synthetic-secret-0123456789abcdef \
    KEYCLOAK_EXISTING_MANAGED_REALMS=saas-admin,saas-bpfarias \
    KEYCLOAK_FORCE_RECONCILE="${1:-true}" \
    KEYCLOAK_BOOTSTRAP_ADMIN_USER=synthetic-bootstrap \
    KEYCLOAK_BOOTSTRAP_ADMIN_PASSWORD=synthetic-password \
        "$SEMANTIC_SERVICE_SCRIPT"
}

: > "$SEMANTIC_LOG"
run_semantic_reconcile false > "$SEMANTIC_ROOT/first-run.log"
grep -Fq 'provisioned successfully' "$SEMANTIC_ROOT/first-run.log" \
    || fail "normal first bootstrap did not provision the technical identity"
[ -f "$SEMANTIC_TECHNICAL_CLIENT_STATE" ] \
    || fail "normal first bootstrap did not create the absent technical client"
first_create_count="$(grep -c '^create clients ' "$SEMANTIC_LOG")"
[ "$first_create_count" -eq 1 ] \
    || fail "normal first bootstrap did not issue exactly one bounded client creation"
[ -f "$SEMANTIC_GLOBAL_DRIFT_STATE" ] \
    || fail "excess global realm role was not revoked"
[ -f "$SEMANTIC_CLIENT_DRIFT_STATE" ] \
    || fail "excess realm-management role was not revoked"
first_delete_count="$(grep -c '^delete users/' "$SEMANTIC_LOG")"
[ "$first_delete_count" -eq 2 ] \
    || fail "semantic reconciliation did not issue exactly two bounded drift revocations"

mutation_count_before_failure="$(grep -Ec '^(create|update|delete|add-roles) ' "$SEMANTIC_LOG")"
if run_semantic_reconcile false true > "$SEMANTIC_ROOT/existing-inaccessible.log" 2>&1; then
    fail "normal init mutated or accepted an existing inaccessible technical identity"
fi
grep -Fq 'exists but could not authenticate' "$SEMANTIC_ROOT/existing-inaccessible.log" \
    || fail "existing inaccessible identity did not produce the fail-closed diagnostic"
mutation_count_after_failure="$(grep -Ec '^(create|update|delete|add-roles) ' "$SEMANTIC_LOG")"
[ "$mutation_count_after_failure" -eq "$mutation_count_before_failure" ] \
    || fail "normal init mutated an existing inaccessible technical identity"

mutation_count_before_read_only="$(grep -Ec '^(create|update|delete|add-roles) ' "$SEMANTIC_LOG")"
run_semantic_reconcile false > "$SEMANTIC_ROOT/read-only-run.log"
grep -Fq 'ready with exact effective privileges' "$SEMANTIC_ROOT/read-only-run.log" \
    || fail "normal init did not verify an accessible exact technical identity"
mutation_count_after_read_only="$(grep -Ec '^(create|update|delete|add-roles) ' "$SEMANTIC_LOG")"
[ "$mutation_count_after_read_only" -eq "$mutation_count_before_read_only" ] \
    || fail "normal exact init mutated Keycloak"

if run_semantic_reconcile \
        true \
        false \
        managed \
        synthetic-provisioner \
        "$EXACT_TOKEN" \
        true \
        > "$SEMANTIC_ROOT/effective-only-drift.log" 2>&1; then
    fail "forced reconcile accepted a privilege present only in the effective role expansion"
fi
grep -Fq 'Unexpected effective privilege remains in effective allowlisted realm-management mappings.' \
    "$SEMANTIC_ROOT/effective-only-drift.log" \
    || fail "effective-only realm-management drift did not fail with the bounded diagnostic"

for reserved_client_id in \
        account \
        admin-cli \
        realm-management \
        saas-admin-realm \
        saas-frontend-spa \
        saas-service-api \
        saas-recovery-temporary; do
    reserved_log_count_before="$(wc -l < "$SEMANTIC_LOG" | tr -d '[:space:]')"
    if SEMANTIC_KCADM_LOG="$SEMANTIC_LOG" \
            KEYCLOAK_PROVISIONING_CLIENT_ID="$reserved_client_id" \
            KEYCLOAK_PROVISIONING_CLIENT_SECRET=synthetic-secret-0123456789abcdef \
            KEYCLOAK_EXISTING_MANAGED_REALMS=saas-admin,saas-bpfarias \
            KEYCLOAK_BOOTSTRAP_ADMIN_USER=synthetic-bootstrap \
            KEYCLOAK_BOOTSTRAP_ADMIN_PASSWORD=synthetic-password \
            "$SEMANTIC_SERVICE_SCRIPT" \
            > "$SEMANTIC_ROOT/reserved-client.log" 2>&1; then
        fail "reserved technical client ID was accepted: $reserved_client_id"
    fi
    grep -Fq 'is reserved' "$SEMANTIC_ROOT/reserved-client.log" \
        || fail "reserved technical client ID did not produce the bounded diagnostic"
    reserved_log_count_after="$(wc -l < "$SEMANTIC_LOG" | tr -d '[:space:]')"
    [ "$reserved_log_count_after" -eq "$reserved_log_count_before" ] \
        || fail "reserved technical client ID reached the Keycloak Admin API"
done

for ownership_failure_mode in unmanaged partial wrong-marker; do
    mutation_count_before_ownership_failure="$(grep -Ec '^(create|update|delete|add-roles) ' "$SEMANTIC_LOG")"
    if run_semantic_reconcile true false "$ownership_failure_mode" \
            > "$SEMANTIC_ROOT/ownership-$ownership_failure_mode.log" 2>&1; then
        fail "forced reconciliation accepted a $ownership_failure_mode custom-client ownership state"
    fi
    mutation_count_after_ownership_failure="$(grep -Ec '^(create|update|delete|add-roles) ' "$SEMANTIC_LOG")"
    [ "$mutation_count_after_ownership_failure" -eq "$mutation_count_before_ownership_failure" ] \
        || fail "forced reconciliation updated a $ownership_failure_mode custom client"
done

mutation_count_before_legacy_failure="$(grep -Ec '^(create|update|delete|add-roles) ' "$SEMANTIC_LOG")"
if run_semantic_reconcile true false legacy-invalid saas-realm-provisioner "$CANONICAL_TOKEN" \
        > "$SEMANTIC_ROOT/legacy-invalid.log" 2>&1; then
    fail "forced reconciliation adopted a divergent legacy canonical client"
fi
mutation_count_after_legacy_failure="$(grep -Ec '^(create|update|delete|add-roles) ' "$SEMANTIC_LOG")"
[ "$mutation_count_after_legacy_failure" -eq "$mutation_count_before_legacy_failure" ] \
    || fail "forced reconciliation updated a divergent legacy canonical client"

canonical_update_count_before="$(grep -c '^update clients/' "$SEMANTIC_LOG" || true)"
run_semantic_reconcile true false legacy-valid saas-realm-provisioner "$CANONICAL_TOKEN" \
    > "$SEMANTIC_ROOT/legacy-valid.log"
canonical_update_count_after="$(grep -c '^update clients/' "$SEMANTIC_LOG" || true)"
[ "$canonical_update_count_after" -eq $((canonical_update_count_before + 1)) ] \
    || fail "strict canonical legacy client adoption did not issue exactly one managed update"

run_semantic_reconcile true > "$SEMANTIC_ROOT/second-run.log"
grep -Fq 'provisioned successfully' "$SEMANTIC_ROOT/second-run.log" \
    || fail "repeated least-privilege reconciliation did not complete"
second_delete_count="$(grep -c '^delete users/' "$SEMANTIC_LOG")"
[ "$second_delete_count" -eq "$first_delete_count" ] \
    || fail "repeated least-privilege reconciliation was not idempotent"
second_create_count="$(grep -c '^create clients ' "$SEMANTIC_LOG")"
[ "$second_create_count" -eq "$first_create_count" ] \
    || fail "repeated reconciliation recreated the technical client"

MIGRATION_SCRIPT="$REPOSITORY_ROOT/infra/keycloak/bootstrap/migrate-persisted-volume.sh"
SERVICE_ACCOUNT_SCRIPT="$REPOSITORY_ROOT/infra/keycloak/bootstrap/ensure-management-service-account.sh"
VALIDATOR_SCRIPT="$REPOSITORY_ROOT/infra/keycloak/bootstrap/validate-realm-token-contracts.sh"
COMPOSE_FILE="$REPOSITORY_ROOT/docker-compose.yml"
COMPOSE_OVERRIDE_FILE="$REPOSITORY_ROOT/docker-compose.override.yml"
DEV_ENV_EXAMPLE="$REPOSITORY_ROOT/.env.example"
PRODUCTION_ENV_EXAMPLE="$REPOSITORY_ROOT/infra/deploy/production.env.example"
PRODUCTION_DEPLOY_SCRIPT="$REPOSITORY_ROOT/infra/scripts/deploy-production.sh"
PRODUCTION_ENVIRONMENT_SCRIPT="$REPOSITORY_ROOT/infra/scripts/lib/deploy-production/environment.sh"
PRODUCTION_ENV_VALIDATION_SCRIPT="$REPOSITORY_ROOT/infra/scripts/lib/deploy-production/environment-validation.sh"
APPLICATION_CONFIG="$REPOSITORY_ROOT/backend/app/src/main/resources/application.yml"
APPLICATION_DEV_CONFIG="$REPOSITORY_ROOT/backend/app/src/main/resources/application-dev.yml"
[ "$(grep -Fc './infra/keycloak/bootstrap/validate-keycloak-runtime-json.sh:/opt/keycloak/bootstrap/validate-keycloak-runtime-json.sh:ro' "$COMPOSE_FILE")" -eq 2 ] \
    || fail "both Keycloak runtime services must mount the structural validator read-only"
[ "$(grep -Fc './infra/keycloak/bootstrap/reconcile-billing-mfa-amr.sh:/opt/keycloak/bootstrap/reconcile-billing-mfa-amr.sh:ro' "$COMPOSE_FILE")" -eq 2 ] \
    || fail "both Keycloak runtime services must mount the Billing MFA AMR reconciler read-only"
[ "$(grep -Fc './infra/keycloak/bootstrap/reconcile-admin-login-mfa.sh:/opt/keycloak/bootstrap/reconcile-admin-login-mfa.sh:ro' "$COMPOSE_FILE")" -eq 2 ] \
    || fail "both Keycloak runtime services must mount the administrative login MFA reconciler read-only"
[ "$(grep -Fc './infra/keycloak/bootstrap/reconcile-tenant-first-login-mfa.sh:/opt/keycloak/bootstrap/reconcile-tenant-first-login-mfa.sh:ro' "$COMPOSE_FILE")" -eq 2 ] \
    || fail "both Keycloak runtime services must mount the tenant first-login MFA reconciler read-only"
[ "$(grep -Fc './infra/keycloak/bootstrap/reconcile-super-admin-identity.sh:/opt/keycloak/bootstrap/reconcile-super-admin-identity.sh:ro' "$COMPOSE_FILE")" -eq 2 ] \
    || fail "both Keycloak runtime services must mount the Super Admin identity reconciler read-only"
[ "$(grep -Fc './infra/keycloak/bootstrap/reconcile-realm-smtp.sh:/opt/keycloak/bootstrap/reconcile-realm-smtp.sh:ro' "$COMPOSE_FILE")" -eq 2 ] \
    || fail "both Keycloak runtime services must mount the realm SMTP reconciler read-only"
grep -Fq 'KEYCLOAK_ADMIN_LOGIN_MFA_ENABLED: ${KEYCLOAK_ADMIN_LOGIN_MFA_ENABLED:-true}' "$COMPOSE_FILE" \
    || fail "secure base Compose must keep administrative login MFA enabled by default"
grep -Fq 'KEYCLOAK_TENANT_FIRST_LOGIN_MFA_ENABLED: ${KEYCLOAK_TENANT_FIRST_LOGIN_MFA_ENABLED:-true}' "$COMPOSE_FILE" \
    || fail "secure base Compose must keep tenant first-login MFA enabled by default"
grep -Fq 'KEYCLOAK_RUNTIME_ENVIRONMENT: production' "$COMPOSE_FILE" \
    || fail "secure base Compose must bind the Keycloak policy scope to production"
grep -Fq 'KEYCLOAK_ADMIN_LOGIN_MFA_ENABLED: ${KEYCLOAK_ADMIN_LOGIN_MFA_ENABLED:-false}' "$COMPOSE_OVERRIDE_FILE" \
    || fail "DEV override must expose the temporary administrative login MFA toggle"
grep -Fq 'KEYCLOAK_TENANT_FIRST_LOGIN_MFA_ENABLED: ${KEYCLOAK_TENANT_FIRST_LOGIN_MFA_ENABLED:-false}' "$COMPOSE_OVERRIDE_FILE" \
    || fail "DEV override must expose the temporary tenant first-login MFA toggle"
grep -Fq 'KEYCLOAK_RUNTIME_ENVIRONMENT: dev' "$COMPOSE_OVERRIDE_FILE" \
    || fail "DEV override must bind the administrative login MFA toggle to DEV"
grep -Fqx 'KEYCLOAK_ADMIN_LOGIN_MFA_ENABLED=false' "$DEV_ENV_EXAMPLE" \
    || fail "DEV environment example must declare the temporary login MFA state"
grep -Fqx 'KEYCLOAK_TENANT_FIRST_LOGIN_MFA_ENABLED=false' "$DEV_ENV_EXAMPLE" \
    || fail "DEV environment example must declare the temporary tenant first-login MFA state"
grep -Fqx 'KEYCLOAK_ADMIN_LOGIN_MFA_ENABLED=true' "$PRODUCTION_ENV_EXAMPLE" \
    || fail "production environment example must keep administrative login MFA enabled"
grep -Fqx 'KEYCLOAK_TENANT_FIRST_LOGIN_MFA_ENABLED=true' "$PRODUCTION_ENV_EXAMPLE" \
    || fail "production environment example must keep tenant first-login MFA enabled"
grep -Fq 'KEYCLOAK_EXISTING_MANAGED_REALMS KEYCLOAK_ADMIN_LOGIN_MFA_ENABLED' "$PRODUCTION_ENV_VALIDATION_SCRIPT" \
    || fail "production deploy must require an explicit administrative login MFA value"
grep -Fq 'KEYCLOAK_ADMIN_LOGIN_MFA_ENABLED must remain true in production' "$PRODUCTION_ENV_VALIDATION_SCRIPT" \
    || fail "production deploy must reject administrative login MFA disablement"
grep -Fq 'KEYCLOAK_TENANT_FIRST_LOGIN_MFA_ENABLED must remain true in production' "$PRODUCTION_ENV_VALIDATION_SCRIPT" \
    || fail "production deploy must reject tenant first-login MFA disablement"
grep -Fq '"keycloak-provisioning-init|KEYCLOAK_ADMIN_LOGIN_MFA_ENABLED|KEYCLOAK_ADMIN_LOGIN_MFA_ENABLED"' "$PRODUCTION_DEPLOY_SCRIPT" \
    || fail "production deploy must verify the effective provisioning-init MFA value"
grep -Fq '"keycloak-provisioning-init|KEYCLOAK_TENANT_FIRST_LOGIN_MFA_ENABLED|KEYCLOAK_TENANT_FIRST_LOGIN_MFA_ENABLED"' "$PRODUCTION_DEPLOY_SCRIPT" \
    || fail "production deploy must verify the effective tenant first-login MFA value"
grep -Fq 'super-admin-mfa-enabled: ${BILLING_SECURITY_SUPER_ADMIN_MFA_ENABLED:true}' "$APPLICATION_CONFIG" \
    || fail "base Spring configuration must keep Super Admin Billing MFA enabled by default"
grep -Fq 'admin-contract-context-mfa-enabled: ${BILLING_SECURITY_ADMIN_CONTRACT_CONTEXT_MFA_ENABLED:true}' "$APPLICATION_CONFIG" \
    || fail "base Spring configuration must keep the legacy contract MFA toggle enabled by default"
grep -Fq 'super-admin-mfa-enabled: ${BILLING_SECURITY_SUPER_ADMIN_MFA_ENABLED:false}' "$APPLICATION_DEV_CONFIG" \
    || fail "DEV Spring configuration must expose the temporary global Super Admin Billing MFA waiver"
grep -Fq 'BILLING_SECURITY_SUPER_ADMIN_MFA_ENABLED: ${BILLING_SECURITY_SUPER_ADMIN_MFA_ENABLED:-true}' "$COMPOSE_FILE" \
    || fail "base Compose must keep Super Admin Billing MFA enabled by default"
grep -Fq 'BILLING_SECURITY_ADMIN_CONTRACT_CONTEXT_MFA_ENABLED: ${BILLING_SECURITY_ADMIN_CONTRACT_CONTEXT_MFA_ENABLED:-true}' "$COMPOSE_FILE" \
    || fail "base Compose must keep the legacy contract MFA toggle enabled by default"
grep -Fq 'BILLING_SECURITY_SUPER_ADMIN_MFA_ENABLED: ${BILLING_SECURITY_SUPER_ADMIN_MFA_ENABLED:-false}' "$COMPOSE_OVERRIDE_FILE" \
    || fail "DEV Compose override must expose the temporary global Super Admin Billing MFA waiver"
grep -Fqx 'BILLING_SECURITY_SUPER_ADMIN_MFA_ENABLED=false' "$DEV_ENV_EXAMPLE" \
    || fail "DEV environment example must declare the temporary global Billing MFA waiver"
grep -Fqx 'BILLING_SECURITY_ADMIN_CONTRACT_CONTEXT_MFA_ENABLED=false' "$DEV_ENV_EXAMPLE" \
    || fail "DEV environment example must retain the temporary legacy contract MFA waiver"
grep -Fqx 'BILLING_SECURITY_SUPER_ADMIN_MFA_ENABLED=true' "$PRODUCTION_ENV_EXAMPLE" \
    || fail "production environment example must keep global Super Admin Billing MFA enabled"
grep -Fqx 'BILLING_SECURITY_ADMIN_CONTRACT_CONTEXT_MFA_ENABLED=true' "$PRODUCTION_ENV_EXAMPLE" \
    || fail "production environment example must keep legacy contract MFA enabled"
grep -Fq 'BILLING_SECURITY_SUPER_ADMIN_MFA_ENABLED BILLING_SECURITY_ADMIN_CONTRACT_CONTEXT_MFA_ENABLED' "$PRODUCTION_ENV_VALIDATION_SCRIPT" \
    || fail "production deploy must require explicit values for both Billing MFA toggles"
grep -Fq 'BILLING_SECURITY_SUPER_ADMIN_MFA_ENABLED must remain true in production' "$PRODUCTION_ENVIRONMENT_SCRIPT" \
    || fail "production deploy must reject the global Super Admin Billing MFA waiver"
grep -Fq 'BILLING_SECURITY_ADMIN_CONTRACT_CONTEXT_MFA_ENABLED must remain true in production' "$PRODUCTION_ENVIRONMENT_SCRIPT" \
    || fail "production deploy must reject the legacy contract Billing MFA waiver"
grep -Fqx '  validate_billing_mfa_production \' "$PRODUCTION_ENV_VALIDATION_SCRIPT" \
    || fail "production environment validation must invoke the Billing MFA fail-closed check"
grep -Fq '"backend|BILLING_SECURITY_SUPER_ADMIN_MFA_ENABLED|BILLING_SECURITY_SUPER_ADMIN_MFA_ENABLED"' "$PRODUCTION_DEPLOY_SCRIPT" \
    || fail "production deploy must verify the effective global Billing MFA toggle"
grep -Fq '"backend|BILLING_SECURITY_ADMIN_CONTRACT_CONTEXT_MFA_ENABLED|BILLING_SECURITY_ADMIN_CONTRACT_CONTEXT_MFA_ENABLED"' "$PRODUCTION_DEPLOY_SCRIPT" \
    || fail "production deploy must verify the effective legacy contract MFA toggle"
grep -Fq '/bin/bash "$RUNTIME_JSON_VALIDATOR"' "$SERVICE_ACCOUNT_SCRIPT" \
    || fail "technical identity init must invoke the mounted Bash structural validator"
grep -Fq '"$BILLING_MFA_AMR_RECONCILER" verify "$KCADM_CONFIG"' "$SERVICE_ACCOUNT_SCRIPT" \
    || fail "normal technical-identity init must verify the Billing MFA AMR contract"
grep -Fq '"$BILLING_MFA_AMR_RECONCILER" reconcile "$KCADM_CONFIG"' "$SERVICE_ACCOUNT_SCRIPT" \
    || fail "first-install and forced init must reconcile the Billing MFA AMR contract"
grep -Fq '"$ADMIN_LOGIN_MFA_RECONCILER" verify "$KCADM_CONFIG"' "$SERVICE_ACCOUNT_SCRIPT" \
    || fail "normal technical-identity init must verify the administrative login MFA state"
grep -Fq '"$ADMIN_LOGIN_MFA_RECONCILER" reconcile "$KCADM_CONFIG"' "$SERVICE_ACCOUNT_SCRIPT" \
    || fail "first-install and forced init must reconcile the administrative login MFA state"
grep -Fq '"$TENANT_FIRST_LOGIN_MFA_RECONCILER" verify "$KCADM_CONFIG"' "$SERVICE_ACCOUNT_SCRIPT" \
    || fail "normal technical-identity init must verify the tenant first-login MFA state"
grep -Fq '"$TENANT_FIRST_LOGIN_MFA_RECONCILER" reconcile "$KCADM_CONFIG"' "$SERVICE_ACCOUNT_SCRIPT" \
    || fail "first-install and forced init must reconcile the tenant first-login MFA state"
grep -Fq '"$SUPER_ADMIN_IDENTITY_RECONCILER" verify "$KCADM_CONFIG"' "$SERVICE_ACCOUNT_SCRIPT" \
    || fail "normal technical-identity init must verify the DEV Super Admin identity"
grep -Fq '"$SUPER_ADMIN_IDENTITY_RECONCILER" reconcile "$KCADM_CONFIG"' "$SERVICE_ACCOUNT_SCRIPT" \
    || fail "first-install and forced init must reconcile the DEV Super Admin identity"
grep -Fq '"$REALM_SMTP_RECONCILER" verify "$KCADM_CONFIG"' "$SERVICE_ACCOUNT_SCRIPT" \
    || fail "normal technical-identity init must verify realm SMTP"
grep -Fq '"$REALM_SMTP_RECONCILER" reconcile "$KCADM_CONFIG"' "$SERVICE_ACCOUNT_SCRIPT" \
    || fail "first-install and forced init must reconcile realm SMTP"
grep -Fq '"implicitFlowEnabled":false' "$SERVICE_ACCOUNT_SCRIPT" \
    || fail "technical client payload must explicitly disable implicit flow"
grep -Fq '"clientAuthenticatorType":"client-secret"' "$SERVICE_ACCOUNT_SCRIPT" \
    || fail "technical client payload must explicitly set the client-secret authenticator"
[ "$(grep -c '^[[:space:]]*umask 077$' "$MIGRATION_SCRIPT")" -eq 4 ] \
    || fail "migration host and all three inner shells must enforce umask 077"
[ "$(grep -c '^[[:space:]]*chmod 600 \"\$config\"$' "$MIGRATION_SCRIPT")" -eq 3 ] \
    || fail "all three inner kcadm session files must be forced to mode 0600"
if grep -Fq '/opt/keycloak/bin/kcadm.sh get realms' "$MIGRATION_SCRIPT"; then
    fail "persisted-volume migration must not discover every Keycloak realm"
fi
grep -Fq 'inspect_mapper_structure()' "$MIGRATION_SCRIPT" \
    || fail "persisted-volume migration must classify mapper JSON structurally"
grep -Fq '/bin/bash "$runtime_json_validator"' "$MIGRATION_SCRIPT" \
    || fail "persisted-volume migration must invoke the mounted Bash structural validator"
grep -Fq 'protocol-mappers/models/$mapper_uuid' "$MIGRATION_SCRIPT" \
    || fail "persisted-volume migration must inspect each administrative mapper JSON"
grep -Fq 'done < "$realms_file"' "$MIGRATION_SCRIPT" \
    || fail "persisted-volume migration must iterate its validated allowlist file"
grep -Fq 'clients/$evaluated_client_uuid/evaluate-scopes/protocol-mappers' "$MIGRATION_SCRIPT" \
    || fail "persisted-volume migration must inspect effective default and optional protocol mappers"
grep -Fq 'clients/$scope_client_uuid/optional-client-scopes' "$MIGRATION_SCRIPT" \
    || fail "persisted-volume migration must enumerate optional client scopes"
grep -Fq 'fetch_all_composite_child_ids()' "$MIGRATION_SCRIPT" \
    || fail "persisted-volume migration must centralize complete composite pagination"
grep -Fq -- '-q "first=$composite_first"' "$MIGRATION_SCRIPT" \
    || fail "composite traversal must paginate from an explicit offset"
grep -Fq -- '-q "max=$composite_page_size"' "$MIGRATION_SCRIPT" \
    || fail "composite traversal must request an explicit bounded page"
grep -Fq 'Duplicate or non-advancing composite page' "$MIGRATION_SCRIPT" \
    || fail "composite pagination must fail closed when a page does not advance"
grep -Fq 'role_inherits_audit' "$MIGRATION_SCRIPT" \
    || fail "persisted-volume migration must reject transitive administrative inheritance of audit"
grep -Fq 'build_tenant_mapper_plan preflight' "$MIGRATION_SCRIPT" \
    || fail "tenant mapper reconciliation must build a complete preflight plan"
grep -Fq 'verify_all_managed_effective_mappers preflight' "$MIGRATION_SCRIPT" \
    || fail "tenant mapper reconciliation must verify effective origins before deletion"
grep -Fq 'mapper_managed_fingerprint' "$MIGRATION_SCRIPT" \
    || fail "direct and client-scope mapper deletion must require a managed-origin fingerprint"
grep -Fq 'shared or realm-default client scope; no mapper was removed' "$MIGRATION_SCRIPT" \
    || fail "shared client-scope tenant mappers must fail closed before deletion"
grep -Fq 'build_tenant_mapper_plan post' "$MIGRATION_SCRIPT" \
    || fail "tenant mapper reconciliation must perform a complete post-mutation inventory"
grep -Fq 'billing-mapper "$billing_mapper_json_file" "$mapper_kind"' "$MIGRATION_SCRIPT" \
    || fail "persisted-volume migration must classify Billing identity mappers structurally"
grep -Fq 'reconcile_billing_mapper_contract' "$MIGRATION_SCRIPT" \
    || fail "persisted-volume migration must reconcile Billing identity mappers"
grep -Fq 'Duplicate exact $mapper_kind Billing mappers' "$MIGRATION_SCRIPT" \
    || fail "Billing identity mapper reconciliation must reject duplicates"
grep -Fq 'unmanagedAttributePolicy=ADMIN_EDIT' "$MIGRATION_SCRIPT" \
    || fail "legacy realms must keep unmanaged identity attributes admin-only"
grep -Fq 'q=human_principal_id:dev-superadmin-primary' "$MIGRATION_SCRIPT" \
    || fail "persisted DEV identity mapping must be verified by its canonical value"
grep -Fq 'recovery-page "$recovery_page_json" "$recovery_page_kind"' "$MIGRATION_SCRIPT" \
    || fail "recovery cleanup must classify user/client pages structurally"
if grep -Eq -- '--fields id,(username|clientId)[[:space:]]+--format csv' "$MIGRATION_SCRIPT"; then
    fail "recovery cleanup must not parse arbitrary external identifiers as unquoted CSV"
fi

BILLING_MAPPER_TEST_ROOT="$FIXTURE_ROOT/billing-identity-mappers"
mkdir -p "$BILLING_MAPPER_TEST_ROOT"
printf '%s\n' '{"id":"11111111-1111-1111-1111-111111111111","name":"human-principal-id","protocol":"openid-connect","protocolMapper":"oidc-usermodel-attribute-mapper","consentRequired":false,"config":{"user.attribute":"human_principal_id","claim.name":"human_principal_id","jsonType.label":"String","id.token.claim":"false","access.token.claim":"true","userinfo.token.claim":"false","multivalued":"false","aggregate.attrs":"false"}}' \
    > "$BILLING_MAPPER_TEST_ROOT/human.json"
printf '%s\n' '{"id":"22222222-2222-2222-2222-222222222222","name":"authentication-method-reference","protocol":"openid-connect","protocolMapper":"oidc-amr-mapper","consentRequired":false,"config":{"id.token.claim":"false","access.token.claim":"true"}}' \
    > "$BILLING_MAPPER_TEST_ROOT/amr.json"
printf '%s\n' '{"id":"33333333-3333-3333-3333-333333333333","name":"human-principal-id","protocol":"openid-connect","protocolMapper":"oidc-usermodel-attribute-mapper","consentRequired":false,"config":{"user.attribute":"human_principal_id","claim.name":"human_principal_id","jsonType.label":"String","id.token.claim":"true","access.token.claim":"true","userinfo.token.claim":"false","multivalued":"false","aggregate.attrs":"false"}}' \
    > "$BILLING_MAPPER_TEST_ROOT/conflicting-human.json"
printf '%s\n' '{"id":"44444444-4444-4444-4444-444444444444","name":"email","protocol":"openid-connect","protocolMapper":"oidc-usermodel-property-mapper","consentRequired":false,"config":{"user.attribute":"email","claim.name":"email","id.token.claim":"true","access.token.claim":"true"}}' \
    > "$BILLING_MAPPER_TEST_ROOT/unrelated.json"

[ "$(bash "$RUNTIME_JSON_VALIDATOR" billing-mapper "$BILLING_MAPPER_TEST_ROOT/human.json" human)" \
    = 'kind=human relevant=true exact=true' ] \
    || fail "canonical human-principal mapper was not classified as exact"
[ "$(bash "$RUNTIME_JSON_VALIDATOR" billing-mapper "$BILLING_MAPPER_TEST_ROOT/amr.json" amr)" \
    = 'kind=amr relevant=true exact=true' ] \
    || fail "canonical AMR mapper was not classified as exact"
[ "$(bash "$RUNTIME_JSON_VALIDATOR" billing-mapper "$BILLING_MAPPER_TEST_ROOT/conflicting-human.json" human)" \
    = 'kind=human relevant=true exact=false' ] \
    || fail "conflicting human-principal mapper was not classified fail-closed"
[ "$(bash "$RUNTIME_JSON_VALIDATOR" billing-mapper "$BILLING_MAPPER_TEST_ROOT/unrelated.json" human)" \
    = 'kind=human relevant=false exact=false' ] \
    || fail "unrelated mapper was treated as a human identity mapper"
[ "$(bash "$RUNTIME_JSON_VALIDATOR" billing-mapper "$BILLING_MAPPER_TEST_ROOT/unrelated.json" amr)" \
    = 'kind=amr relevant=false exact=false' ] \
    || fail "unrelated mapper was treated as an AMR mapper"

RECOVERY_TEST_ROOT="$FIXTURE_ROOT/recovery-structural-pagination"
RECOVERY_HELPERS="$RECOVERY_TEST_ROOT/recovery-helpers.sh"
RECOVERY_FAKE_KCADM="$RECOVERY_TEST_ROOT/kcadm.sh"
mkdir -p "$RECOVERY_TEST_ROOT"
awk '
  /^            parse_recovery_page\(\) \{/ { capture = 1 }
  capture && /^            parse_recovery_page users / { exit }
  capture {
    line = $0
    sub(/^            /, "", line)
    print line
  }
' "$MIGRATION_SCRIPT" > "$RECOVERY_HELPERS"
grep -Fq 'record_recovery_page_items()' "$RECOVERY_HELPERS" \
    || fail "could not isolate structural recovery-page progress tracking"
grep -Fq 'plan_recovery_page_candidates()' "$RECOVERY_HELPERS" \
    || fail "could not isolate structural recovery candidate planning"
grep -Fq 'delete_recovery_candidates()' "$RECOVERY_HELPERS" \
    || fail "could not isolate bounded recovery candidate deletion"
sed -i "s|/opt/keycloak/bin/kcadm.sh|$RECOVERY_FAKE_KCADM|g" "$RECOVERY_HELPERS"

cat > "$RECOVERY_FAKE_KCADM" <<'EOF'
#!/bin/sh
set -eu
[ "${1:-}" = delete ] || exit 91
printf '%s\n' "${2:-}" >> "${RECOVERY_MUTATION_LOG:?}"
EOF
chmod 700 "$RECOVERY_FAKE_KCADM"

REPEATED_EXTERNAL_PAGE="$RECOVERY_TEST_ROOT/repeated-external-page.json"
repeated_external_json='['
repeated_external_separator=''
repeated_external_index=0
while [ "$repeated_external_index" -lt 100 ]; do
    repeated_external_json="${repeated_external_json}${repeated_external_separator}{\"id\":\"external-id-$repeated_external_index\",\"clientId\":\"external,client,$repeated_external_index\"}"
    repeated_external_separator=','
    repeated_external_index=$((repeated_external_index + 1))
done
printf '%s]\n' "$repeated_external_json" > "$REPEATED_EXTERNAL_PAGE"

REPEATED_ROOT="$RECOVERY_TEST_ROOT/repeated"
mkdir -p "$REPEATED_ROOT"
: > "$REPEATED_ROOT/mutations.log"
if (
    set -eu
    runtime_json_validator="$RUNTIME_JSON_VALIDATOR"
    parsed_page_file="$REPEATED_ROOT/parsed.tsv"
    records_page_file="$REPEATED_ROOT/records.tsv"
    item_page_file="$REPEATED_ROOT/items.tsv"
    candidate_page_file="$REPEATED_ROOT/candidates.tsv"
    seen_items_file="$REPEATED_ROOT/seen-items.list"
    config="$REPEATED_ROOT/kcadm.config"
    tab_character="$(printf '\t')"
    : > "$seen_items_file"
    RECOVERY_MUTATION_LOG="$REPEATED_ROOT/mutations.log"
    export RECOVERY_MUTATION_LOG
    # shellcheck source=/dev/null
    . "$RECOVERY_HELPERS"
    parse_recovery_page clients "$REPEATED_EXTERNAL_PAGE"
    record_recovery_page_items client "$seen_items_file"
    parse_recovery_page clients "$REPEATED_EXTERNAL_PAGE"
    record_recovery_page_items client "$seen_items_file"
) > "$REPEATED_ROOT/output.log" 2>&1; then
    fail "a repeated full page containing only external recovery identities was accepted"
fi
grep -Fq 'Duplicate or non-advancing recovery client page.' "$REPEATED_ROOT/output.log" \
    || fail "repeated external recovery page did not preserve the fail-closed diagnostic"
[ ! -s "$REPEATED_ROOT/mutations.log" ] \
    || fail "repeated external recovery page caused a delete"

COMMA_ROOT="$RECOVERY_TEST_ROOT/comma-and-stale"
mkdir -p "$COMMA_ROOT"
COMMA_CLIENT_PAGE="$COMMA_ROOT/clients.json"
COMMA_USER_PAGE="$COMMA_ROOT/users.json"
printf '%s\n' '[{"id":"external,id","clientId":"external,client"},{"id":"aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee","clientId":"saas-recovery-deadbeef"}]' \
    > "$COMMA_CLIENT_PAGE"
printf '%s\n' '[{"id":"federated,opaque,id","username":"external,user"},{"id":"11111111-2222-3333-4444-555555555555","username":"saas-recovery-user-stale"},{"id":"66666666-7777-8888-9999-aaaaaaaaaaaa","username":"saas-recovery-user-current"}]' \
    > "$COMMA_USER_PAGE"
: > "$COMMA_ROOT/mutations.log"
(
    set -eu
    runtime_json_validator="$RUNTIME_JSON_VALIDATOR"
    parsed_page_file="$COMMA_ROOT/parsed.tsv"
    records_page_file="$COMMA_ROOT/records.tsv"
    item_page_file="$COMMA_ROOT/items.tsv"
    candidate_page_file="$COMMA_ROOT/candidates.tsv"
    seen_client_items_file="$COMMA_ROOT/seen-client-items.list"
    seen_user_items_file="$COMMA_ROOT/seen-user-items.list"
    stale_clients_file="$COMMA_ROOT/stale-clients.list"
    stale_users_file="$COMMA_ROOT/stale-users.list"
    config="$COMMA_ROOT/kcadm.config"
    tab_character="$(printf '\t')"
    : > "$seen_client_items_file"
    : > "$seen_user_items_file"
    : > "$stale_clients_file"
    : > "$stale_users_file"
    RECOVERY_MUTATION_LOG="$COMMA_ROOT/mutations.log"
    export RECOVERY_MUTATION_LOG
    # shellcheck source=/dev/null
    . "$RECOVERY_HELPERS"
    parse_recovery_page clients "$COMMA_CLIENT_PAGE"
    record_recovery_page_items client "$seen_client_items_file"
    plan_recovery_page_candidates client "$stale_clients_file"
    parse_recovery_page users "$COMMA_USER_PAGE"
    record_recovery_page_items user "$seen_user_items_file"
    plan_recovery_page_candidates user "$stale_users_file" \
        66666666-7777-8888-9999-aaaaaaaaaaaa
    delete_recovery_candidates clients "$stale_clients_file"
    delete_recovery_candidates users "$stale_users_file"
)
[ "$(wc -l < "$COMMA_ROOT/mutations.log" | tr -d '[:space:]')" -eq 2 ] \
    || fail "structural recovery cleanup did not delete exactly the two stale reserved candidates"
grep -Fxq 'clients/aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee' "$COMMA_ROOT/mutations.log" \
    || fail "stale recovery client was not deleted"
grep -Fxq 'users/11111111-2222-3333-4444-555555555555' "$COMMA_ROOT/mutations.log" \
    || fail "stale recovery user was not deleted"
if grep -Eq 'external|66666666-7777-8888-9999-aaaaaaaaaaaa' "$COMMA_ROOT/mutations.log"; then
    fail "external or current recovery identity entered the deletion plan"
fi

MAPPER_TEST_ROOT="$FIXTURE_ROOT/mapper-reconciliation"
MAPPER_BODY="$MAPPER_TEST_ROOT/mapper-reconciliation-body.sh"
MAPPER_FAKE_KCADM="$MAPPER_TEST_ROOT/kcadm.sh"
mkdir -p "$MAPPER_TEST_ROOT"
awk '
  /^        mapper_reconcile_error\(\) \{/ { capture = 1 }
  capture {
    line = $0
    sub(/^        /, "", line)
    print line
  }
  capture && /^        verify_all_managed_effective_mappers post$/ { exit }
' "$MIGRATION_SCRIPT" > "$MAPPER_BODY"
grep -Fq 'mapper_reconcile_error()' "$MAPPER_BODY" \
    || fail "could not isolate the real tenant-mapper reconciliation body"
grep -Fq 'verify_all_managed_effective_mappers post' "$MAPPER_BODY" \
    || fail "tenant-mapper semantic body omitted post-mutation verification"
sed -i "s|/opt/keycloak/bin/kcadm.sh|$MAPPER_FAKE_KCADM|g" "$MAPPER_BODY"

cat > "$MAPPER_FAKE_KCADM" <<'EOF'
#!/bin/sh
set -eu

command_name="${1:-}"
resource="${2:-}"
scope_query=""
first_query=""
for argument in "$@"; do
    case "$argument" in
        scope=*) scope_query="${argument#scope=}" ;;
        first=*) first_query="${argument#first=}" ;;
    esac
done
printf '%s|%s|%s|%s\n' "$command_name" "$resource" "$scope_query" "$first_query" \
    >> "${MAPPER_REQUEST_LOG:?}"

api_client=aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa
spa_client=bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb
other_client=cccccccc-cccc-cccc-cccc-cccccccccccc
default_scope=dddddddd-dddd-dddd-dddd-dddddddddddd
optional_scope=eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee
unknown_scope=99999999-9999-9999-9999-999999999999
direct_mapper=11111111-1111-1111-1111-111111111111
default_mapper=22222222-2222-2222-2222-222222222222
optional_mapper=33333333-3333-3333-3333-333333333333
unmanaged_mapper=44444444-4444-4444-4444-444444444444
scenario="${MAPPER_SCENARIO:?}"

is_deleted() {
    [ -f "${MAPPER_STATE_DIR:?}/deleted-$1" ]
}

if [ "$command_name" = get ] && [ "$resource" = clients ]; then
    case "$scenario" in
        client-pagination-advancing|client-pagination-nonadvancing)
            if [ -z "$first_query" ] || [ "$first_query" = 0 ] \
                    || [ "$scenario" = client-pagination-nonadvancing ]; then
                printf '%s,%s\n' \
                    "$api_client" saas-service-api \
                    "$spa_client" saas-frontend-spa \
                    "$other_client" third-party-client
            elif [ "$first_query" = 3 ]; then
                printf '%032x,%s\n' 4 client-004
            fi
            ;;
        *)
            printf '%s,%s\n' \
                "$api_client" saas-service-api \
                "$spa_client" saas-frontend-spa \
                "$other_client" third-party-client
            ;;
    esac
    exit 0
fi

case "$resource" in
    "clients/$api_client/default-client-scopes")
        case "$scenario" in
            managed|shared|unknown-fingerprint) printf '%s,%s\n' "$default_scope" api-tenant-scope ;;
        esac
        exit 0
        ;;
    "clients/$spa_client/default-client-scopes"|"clients/$api_client/optional-client-scopes"|"clients/$other_client/default-client-scopes"|"clients/$other_client/optional-client-scopes")
        exit 0
        ;;
    "clients/$spa_client/optional-client-scopes")
        [ "$scenario" = managed ] \
            && printf '%s,%s\n' "$optional_scope" spa-tenant-scope
        exit 0
        ;;
    default-default-client-scopes)
        [ "$scenario" = shared ] \
            && printf '%s,%s\n' "$default_scope" api-tenant-scope
        exit 0
        ;;
    default-optional-client-scopes)
        exit 0
        ;;
    clients/*/default-client-scopes|clients/*/optional-client-scopes)
        exit 0
        ;;
esac

if [ "$command_name" = get ]; then
    case "$resource" in
        "clients/$api_client/protocol-mappers/models")
            case "$scenario" in
                managed|decoy|direct-unknown-fingerprint)
                    is_deleted "$direct_mapper" || printf '%s\n' "$direct_mapper"
                    ;;
                residual)
                    printf '%s\n' "$direct_mapper"
                    ;;
            esac
            exit 0
            ;;
        "clients/$spa_client/protocol-mappers/models")
            exit 0
            ;;
        "clients/$other_client/protocol-mappers/models")
            [ "$scenario" = unmanaged ] && printf '%s\n' "$unmanaged_mapper"
            exit 0
            ;;
        clients/*/protocol-mappers/models)
            exit 0
            ;;
        "client-scopes/$default_scope/protocol-mappers/models")
            case "$scenario" in
                managed|shared|unknown-fingerprint)
                    is_deleted "$default_mapper" || printf '%s\n' "$default_mapper"
                    ;;
            esac
            exit 0
            ;;
        "client-scopes/$optional_scope/protocol-mappers/models")
            if [ "$scenario" = managed ]; then
                is_deleted "$optional_mapper" || printf '%s\n' "$optional_mapper"
            fi
            exit 0
            ;;
        "clients/$api_client/protocol-mappers/models/$direct_mapper")
            if [ "$scenario" = decoy ]; then
                printf '{"id":"%s","name":"ordinary","protocol":"openid-connect","protocolMapper":"oidc-hardcoded-claim-mapper","config":{"claim.name":"ordinary"},"decoy":{"name":"tenant_id","config":{"claim.name":"tenant_id"}},"note":"tenant_id-mapper"}\n' "$direct_mapper"
            elif [ "$scenario" = direct-unknown-fingerprint ]; then
                printf '{"id":"%s","name":"ordinary-mapper","protocol":"openid-connect","protocolMapper":"foreign-mapper","config":{"claim.name":"tenant_id"},"note":"{\\"name\\":\\"tenant_id-mapper\\",\\"protocolMapper\\":\\"oidc-usermodel-attribute-mapper\\",\\"user.attribute\\":\\"tenant_id\\",\\"claim.name\\":\\"tenant_id\\"}"}\n' "$direct_mapper"
            else
                printf '{"id":"%s","name":"tenant_id-mapper","protocol":"openid-connect","protocolMapper":"oidc-usermodel-attribute-mapper","config":{"user.attribute":"tenant_id","claim.name":"tenant_id"}}\n' "$direct_mapper"
            fi
            exit 0
            ;;
        "clients/$other_client/protocol-mappers/models/$unmanaged_mapper")
            printf '{"id":"%s","name":"tenant_id","protocol":"openid-connect","protocolMapper":"oidc-hardcoded-claim-mapper","config":{"claim.name":"tenant_id","claim.value":"foreign"}}\n' "$unmanaged_mapper"
            exit 0
            ;;
        "client-scopes/$default_scope/protocol-mappers/models/$default_mapper")
            if [ "$scenario" = unknown-fingerprint ]; then
                printf '{"id":"%s","name":"ordinary-mapper","protocol":"openid-connect","protocolMapper":"foreign-mapper","config":{"claim.name":"tenant_id"},"note":"{\\"name\\":\\"tenant_id-mapper\\",\\"protocolMapper\\":\\"oidc-usermodel-attribute-mapper\\",\\"user.attribute\\":\\"tenant_id\\",\\"claim.name\\":\\"tenant_id\\"}"}\n' "$default_mapper"
            else
                printf '{"id":"%s","name":"tenant_id-mapper","protocol":"openid-connect","protocolMapper":"oidc-usermodel-attribute-mapper","config":{"user.attribute":"tenant_id","claim.name":"tenant_id"}}\n' "$default_mapper"
            fi
            exit 0
            ;;
        "client-scopes/$optional_scope/protocol-mappers/models/$optional_mapper")
            printf '{"id":"%s","name":"tenant_id","protocol":"openid-connect","protocolMapper":"oidc-hardcoded-claim-mapper","config":{"claim.name":"tenant_id","claim.value":"legacy"}}\n' "$optional_mapper"
            exit 0
            ;;
        "clients/$api_client/evaluate-scopes/protocol-mappers")
            if [ -z "$scope_query" ]; then
                case "$scenario" in
                    managed)
                        is_deleted "$direct_mapper" \
                            || printf '%s,%s,%s\n' "$direct_mapper" "$api_client" client
                        is_deleted "$default_mapper" \
                            || printf '%s,%s,%s\n' "$default_mapper" "$default_scope" client-scope
                        ;;
                    unknown-origin)
                        printf '%s,%s,%s\n' "$default_mapper" "$unknown_scope" client-scope
                        ;;
                    residual)
                        printf '%s,%s,%s\n' "$direct_mapper" "$api_client" client
                        ;;
                esac
            fi
            exit 0
            ;;
        "clients/$spa_client/evaluate-scopes/protocol-mappers")
            if [ "$scenario" = managed ] && [ "$scope_query" = spa-tenant-scope ]; then
                is_deleted "$optional_mapper" \
                    || printf '%s,%s,%s\n' "$optional_mapper" "$optional_scope" client-scope
            fi
            exit 0
            ;;
    esac
fi

if [ "$command_name" = delete ]; then
    expected_mapper=""
    case "$resource" in
        "clients/$api_client/protocol-mappers/models/$direct_mapper") expected_mapper="$direct_mapper" ;;
        "client-scopes/$default_scope/protocol-mappers/models/$default_mapper") expected_mapper="$default_mapper" ;;
        "client-scopes/$optional_scope/protocol-mappers/models/$optional_mapper") expected_mapper="$optional_mapper" ;;
        *) exit 98 ;;
    esac
    printf 'delete|%s\n' "$resource" >> "${MAPPER_MUTATION_LOG:?}"
    if [ "$scenario" != residual ]; then
        : > "$MAPPER_STATE_DIR/deleted-$expected_mapper"
    fi
    exit 0
fi

echo "unexpected fake kcadm call: $*" >&2
exit 99
EOF
chmod 700 "$MAPPER_FAKE_KCADM"

run_mapper_scenario() {
    mapper_scenario="$1"
    mapper_scenario_root="$2"
    mkdir -p "$mapper_scenario_root/state"
    : > "$mapper_scenario_root/requests.log"
    [ -f "$mapper_scenario_root/mutations.log" ] || : > "$mapper_scenario_root/mutations.log"
    (
        set -eu
        config="$mapper_scenario_root/kcadm.config"
        clients_page_file="$mapper_scenario_root/clients-page.csv"
        all_clients_file="$mapper_scenario_root/all-clients.csv"
        managed_clients_file="$mapper_scenario_root/managed-clients.csv"
        mappers_file="$mapper_scenario_root/mappers.csv"
        mapper_json="$mapper_scenario_root/mapper.json"
        scopes_file="$mapper_scenario_root/scopes.csv"
        scope_edges_file="$mapper_scenario_root/scope-edges.psv"
        scope_ids_file="$mapper_scenario_root/scope-ids.list"
        delete_plan_file="$mapper_scenario_root/delete-plan.psv"
        effective_mappers_file="$mapper_scenario_root/effective.csv"
        optional_scopes_file="$mapper_scenario_root/optional-scopes.csv"
        collection_seen_file="$mapper_scenario_root/collection-seen.list"
        runtime_json_validator="$RUNTIME_JSON_VALIDATOR"
        MAPPER_SCENARIO="$mapper_scenario"
        MAPPER_STATE_DIR="$mapper_scenario_root/state"
        MAPPER_REQUEST_LOG="$mapper_scenario_root/requests.log"
        MAPPER_MUTATION_LOG="$mapper_scenario_root/mutations.log"
        export MAPPER_SCENARIO MAPPER_STATE_DIR MAPPER_REQUEST_LOG MAPPER_MUTATION_LOG
        # shellcheck source=/dev/null
        . "$MAPPER_BODY"
    )
}

MANAGED_MAPPER_ROOT="$MAPPER_TEST_ROOT/managed"
run_mapper_scenario managed "$MANAGED_MAPPER_ROOT"
[ "$(grep -c '^delete|' "$MANAGED_MAPPER_ROOT/mutations.log")" -eq 3 ] \
    || fail "managed direct/default/optional reconciliation did not issue exactly three deletes"
grep -Fxq 'delete|clients/aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa/protocol-mappers/models/11111111-1111-1111-1111-111111111111' \
    "$MANAGED_MAPPER_ROOT/mutations.log" \
    || fail "managed direct mapper was not deleted through its exact resource"
grep -Fxq 'delete|client-scopes/dddddddd-dddd-dddd-dddd-dddddddddddd/protocol-mappers/models/22222222-2222-2222-2222-222222222222' \
    "$MANAGED_MAPPER_ROOT/mutations.log" \
    || fail "managed dedicated default-scope mapper was not deleted exactly"
grep -Fxq 'delete|client-scopes/eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee/protocol-mappers/models/33333333-3333-3333-3333-333333333333' \
    "$MANAGED_MAPPER_ROOT/mutations.log" \
    || fail "managed dedicated optional-scope mapper was not deleted exactly"
run_mapper_scenario managed "$MANAGED_MAPPER_ROOT"
[ "$(grep -c '^delete|' "$MANAGED_MAPPER_ROOT/mutations.log")" -eq 3 ] \
    || fail "tenant-mapper reconciliation was not idempotent after the clean post-state"

DECOY_MAPPER_ROOT="$MAPPER_TEST_ROOT/decoy"
run_mapper_scenario decoy "$DECOY_MAPPER_ROOT"
[ ! -s "$DECOY_MAPPER_ROOT/mutations.log" ] \
    || fail "nested/string mapper decoys produced a deletion"

for closed_mapper_scenario in shared unmanaged unknown-origin unknown-fingerprint direct-unknown-fingerprint; do
    closed_mapper_root="$MAPPER_TEST_ROOT/$closed_mapper_scenario"
    if run_mapper_scenario "$closed_mapper_scenario" "$closed_mapper_root" \
            > "$closed_mapper_root.log" 2>&1; then
        fail "$closed_mapper_scenario mapper scenario did not fail closed"
    fi
    [ ! -s "$closed_mapper_root/mutations.log" ] \
        || fail "$closed_mapper_scenario mapper scenario mutated before full preflight"
done
grep -Fq 'shared or realm-default client scope' "$MAPPER_TEST_ROOT/shared.log" \
    || fail "shared/realm-default scope did not preserve the closed-state diagnostic"
grep -Fq 'belongs to unmanaged client' "$MAPPER_TEST_ROOT/unmanaged.log" \
    || fail "unmanaged direct mapper did not preserve the closed-state diagnostic"
grep -Fq 'unknown client-scope origin' "$MAPPER_TEST_ROOT/unknown-origin.log" \
    || fail "unknown effective scope origin did not preserve the closed-state diagnostic"
grep -Fq 'unknown managed-origin fingerprint' "$MAPPER_TEST_ROOT/unknown-fingerprint.log" \
    || fail "structurally unknown mapper fingerprint did not fail closed"
grep -Fq 'unknown managed-origin fingerprint' "$MAPPER_TEST_ROOT/direct-unknown-fingerprint.log" \
    || fail "structurally unknown direct mapper fingerprint did not fail closed"

RESIDUAL_MAPPER_ROOT="$MAPPER_TEST_ROOT/residual"
if run_mapper_scenario residual "$RESIDUAL_MAPPER_ROOT" \
        > "$RESIDUAL_MAPPER_ROOT.log" 2>&1; then
    fail "residual mapper scenario passed without a clean post-mutation inventory"
fi
[ "$(grep -c '^delete|' "$RESIDUAL_MAPPER_ROOT/mutations.log")" -eq 1 ] \
    || fail "residual scenario did not isolate the single accepted delete"
grep -Fq 'residual direct mapper still emits tenant_id' "$RESIDUAL_MAPPER_ROOT.log" \
    || fail "residual mapper did not fail during post-mutation inventory"

CLIENT_PAGINATION_HELPER="$MAPPER_TEST_ROOT/fetch-all-admin-clients.sh"
awk '
  /^        mapper_reconcile_error\(\) \{/ { capture = 1 }
  capture && /^        record_scope_endpoint\(\) \{/ { exit }
  capture {
    line = $0
    sub(/^        /, "", line)
    print line
  }
' "$MIGRATION_SCRIPT" > "$CLIENT_PAGINATION_HELPER"
grep -Fq 'fetch_all_admin_clients()' "$CLIENT_PAGINATION_HELPER" \
    || fail "could not isolate administrative client pagination for semantic testing"
sed -i "s|/opt/keycloak/bin/kcadm.sh|$MAPPER_FAKE_KCADM|g" \
    "$CLIENT_PAGINATION_HELPER"
sed -i 's/client_page_size=100/client_page_size=3/' "$CLIENT_PAGINATION_HELPER"

run_client_pagination_scenario() {
    client_pagination_scenario="$1"
    client_pagination_root="$2"
    mkdir -p "$client_pagination_root/state"
    : > "$client_pagination_root/requests.log"
    : > "$client_pagination_root/mutations.log"
    (
        set -eu
        config=synthetic-config
        clients_page_file="$client_pagination_root/clients-page.csv"
        all_clients_file="$client_pagination_root/all-clients.csv"
        managed_clients_file="$client_pagination_root/managed-clients.csv"
        collection_seen_file="$client_pagination_root/seen.list"
        MAPPER_SCENARIO="$client_pagination_scenario"
        MAPPER_STATE_DIR="$client_pagination_root/state"
        MAPPER_REQUEST_LOG="$client_pagination_root/requests.log"
        MAPPER_MUTATION_LOG="$client_pagination_root/mutations.log"
        export MAPPER_SCENARIO MAPPER_STATE_DIR MAPPER_REQUEST_LOG MAPPER_MUTATION_LOG
        # shellcheck source=/dev/null
        . "$CLIENT_PAGINATION_HELPER"
        fetch_all_admin_clients
    )
}

ADVANCING_CLIENT_ROOT="$MAPPER_TEST_ROOT/client-pagination-advancing"
run_client_pagination_scenario client-pagination-advancing "$ADVANCING_CLIENT_ROOT"
[ "$(wc -l < "$ADVANCING_CLIENT_ROOT/all-clients.csv" | tr -d '[:space:]')" -eq 4 ] \
    || fail "advancing administrative client pagination did not accumulate every page"
[ ! -s "$ADVANCING_CLIENT_ROOT/mutations.log" ] \
    || fail "advancing administrative client pagination produced a mutation"
grep -Fq 'get|clients||3' "$ADVANCING_CLIENT_ROOT/requests.log" \
    || fail "administrative client inventory did not request its second page"

NONADVANCING_CLIENT_ROOT="$MAPPER_TEST_ROOT/client-pagination-nonadvancing"
if run_client_pagination_scenario client-pagination-nonadvancing "$NONADVANCING_CLIENT_ROOT" \
        > "$NONADVANCING_CLIENT_ROOT.log" 2>&1; then
    fail "administrative client pagination accepted a repeated full page"
fi
[ ! -s "$NONADVANCING_CLIENT_ROOT/mutations.log" ] \
    || fail "non-advancing administrative client pagination mutated mapper state"
grep -Fq 'Duplicate or non-advancing administrative client page' \
    "$NONADVANCING_CLIENT_ROOT.log" \
    || fail "non-advancing administrative client page did not fail closed"

PAGINATION_ROOT="$FIXTURE_ROOT/composite-pagination"
PAGINATION_HELPER="$PAGINATION_ROOT/fetch-all-composite-child-ids.sh"
PAGINATION_FAKE_KCADM="$PAGINATION_ROOT/kcadm.sh"
PAGINATION_PAGE_FILE="$PAGINATION_ROOT/page.csv"
PAGINATION_RESULT_FILE="$PAGINATION_ROOT/result.csv"
PAGINATION_LOG="$PAGINATION_ROOT/requests.log"
mkdir -p "$PAGINATION_ROOT"
awk '
  /^        fetch_all_composite_child_ids\(\) \{/ { capture = 1 }
  capture {
    line = $0
    sub(/^        /, "", line)
    print line
  }
  capture && /^        }$/ { exit }
' "$MIGRATION_SCRIPT" > "$PAGINATION_HELPER"
grep -Fq 'fetch_all_composite_child_ids()' "$PAGINATION_HELPER" \
    || fail "could not isolate the composite pagination helper for semantic testing"
sed -i "s|/opt/keycloak/bin/kcadm.sh|$PAGINATION_FAKE_KCADM|g" \
    "$PAGINATION_HELPER"

cat > "$PAGINATION_FAKE_KCADM" <<'EOF'
#!/bin/sh
set -eu

first=""
max=""
for argument in "$@"; do
    case "$argument" in
        first=*) first="${argument#first=}" ;;
        max=*) max="${argument#max=}" ;;
    esac
done
[ "$max" = 100 ] || exit 97
printf '%s:%s\n' "$first" "$max" >> "${PAGINATION_REQUEST_LOG:?}"

emit_identifiers() {
    awk -v first_identifier="$1" -v last_identifier="$2" '
      BEGIN {
        for (identifier = first_identifier; identifier <= last_identifier; identifier++) {
          printf "%032x\n", identifier
        }
      }
    '
}

case "${PAGINATION_SCENARIO:?}" in
    advancing)
        case "$first" in
            0) emit_identifiers 1 100 ;;
            100) emit_identifiers 101 102 ;;
        esac
        ;;
    nonadvancing)
        emit_identifiers 1 100
        ;;
    failure)
        exit 17
        ;;
    *)
        exit 98
        ;;
esac
EOF
chmod 700 "$PAGINATION_FAKE_KCADM"

: > "$PAGINATION_LOG"
(
    set -eu
    config=synthetic-config
    composite_children_page_file="$PAGINATION_PAGE_FILE"
    PAGINATION_SCENARIO=advancing
    PAGINATION_REQUEST_LOG="$PAGINATION_LOG"
    export PAGINATION_SCENARIO PAGINATION_REQUEST_LOG
    # shellcheck source=/dev/null
    . "$PAGINATION_HELPER"
    fetch_all_composite_child_ids \
        saas-admin \
        aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa \
        "$PAGINATION_RESULT_FILE"
)
pagination_result_count="$(wc -l < "$PAGINATION_RESULT_FILE" | tr -d '[:space:]')"
[ "$pagination_result_count" -eq 102 ] \
    || fail "composite pagination did not accumulate every identifier across pages"
grep -Fxq '0:100' "$PAGINATION_LOG" \
    || fail "composite pagination did not request the first bounded page"
grep -Fxq '100:100' "$PAGINATION_LOG" \
    || fail "composite pagination did not request the next bounded page"

if (
    set -eu
    config=synthetic-config
    composite_children_page_file="$PAGINATION_PAGE_FILE"
    PAGINATION_SCENARIO=nonadvancing
    PAGINATION_REQUEST_LOG="$PAGINATION_LOG"
    export PAGINATION_SCENARIO PAGINATION_REQUEST_LOG
    # shellcheck source=/dev/null
    . "$PAGINATION_HELPER"
    fetch_all_composite_child_ids \
        saas-admin \
        bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb \
        "$PAGINATION_RESULT_FILE"
) > "$PAGINATION_ROOT/nonadvancing.log" 2>&1; then
    fail "composite pagination accepted a repeated non-advancing page"
fi
grep -Fq 'Duplicate or non-advancing composite page' \
    "$PAGINATION_ROOT/nonadvancing.log" \
    || fail "non-advancing composite pagination did not fail with the closed-state diagnostic"

if (
    set -eu
    config=synthetic-config
    composite_children_page_file="$PAGINATION_PAGE_FILE"
    PAGINATION_SCENARIO=failure
    PAGINATION_REQUEST_LOG="$PAGINATION_LOG"
    export PAGINATION_SCENARIO PAGINATION_REQUEST_LOG
    # shellcheck source=/dev/null
    . "$PAGINATION_HELPER"
    fetch_all_composite_child_ids \
        saas-admin \
        cccccccc-cccc-cccc-cccc-cccccccccccc \
        "$PAGINATION_RESULT_FILE"
) > "$PAGINATION_ROOT/failure.log" 2>&1; then
    fail "composite pagination ignored an administrative API failure"
fi
grep -Fq 'Could not inspect the complete realm-role composite graph' \
    "$PAGINATION_ROOT/failure.log" \
    || fail "composite API failure did not preserve the fail-closed diagnostic"

AUDIT_INHERITANCE_ROOT="$FIXTURE_ROOT/audit-inheritance"
AUDIT_INHERITANCE_BODY="$AUDIT_INHERITANCE_ROOT/reconcile-audit-inheritance.sh"
AUDIT_INHERITANCE_FAKE_KCADM="$AUDIT_INHERITANCE_ROOT/kcadm.sh"
mkdir -p "$AUDIT_INHERITANCE_ROOT"
awk '
  /^        fetch_all_composite_child_ids\(\) \{/ { capture = 1 }
  capture && /^        reconcile_audit_role_composites\(\) \{/ { exit }
  capture {
    line = $0
    sub(/^        /, "", line)
    print line
  }
' "$MIGRATION_SCRIPT" > "$AUDIT_INHERITANCE_BODY"
grep -Fq 'inventory_all_role_parents()' "$AUDIT_INHERITANCE_BODY" \
    || fail "could not isolate complete realm/client-role inventory"
grep -Fq 'preflight_complete_audit_inheritance()' "$AUDIT_INHERITANCE_BODY" \
    || fail "could not isolate complete audit-inheritance preflight"
sed -i "s|/opt/keycloak/bin/kcadm.sh|$AUDIT_INHERITANCE_FAKE_KCADM|g" \
    "$AUDIT_INHERITANCE_BODY"

cat > "$AUDIT_INHERITANCE_FAKE_KCADM" <<'EOF'
#!/bin/sh
set -eu

command_name="${1:-}"
resource="${2:-}"
scenario="${AUDIT_INHERITANCE_SCENARIO:?}"
audit_uuid=aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa
super_uuid=bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb
fiscal_uuid=cccccccc-cccc-cccc-cccc-cccccccccccc
custom_uuid=dddddddd-dddd-dddd-dddd-dddddddddddd
client_uuid=eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee
client_role_uuid=ffffffff-ffff-ffff-ffff-ffffffffffff

if [ "$command_name" = get ] && [ "$resource" = roles ]; then
    printf '%s,%s\n' "$audit_uuid" ROLE_TENANT_AUDIT
    case "$scenario" in
        clean|managed-direct) printf '%s,%s\n' "$super_uuid" ROLE_SUPER_ADMIN ;;
        fiscal) printf '%s,%s\n' "$fiscal_uuid" ROLE_FISCAL_ADMIN ;;
        custom) printf '%s,%s\n' "$custom_uuid" ROLE_CUSTOM_AUDIT_PARENT ;;
        client) ;;
        *) exit 98 ;;
    esac
    exit 0
fi
if [ "$command_name" = get ] && [ "$resource" = clients ]; then
    printf '%s\n' "$client_uuid"
    exit 0
fi
if [ "$command_name" = get ] && [ "$resource" = "clients/$client_uuid/roles" ]; then
    printf '%s,%s\n' "$client_role_uuid" client-audit-parent
    exit 0
fi
case "$resource" in
    roles-by-id/*/composites)
        parent_uuid="${resource#roles-by-id/}"
        parent_uuid="${parent_uuid%/composites}"
        if [ "$command_name" = get ]; then
            case "$scenario:$parent_uuid" in
                managed-direct:$super_uuid)
                    [ -f "${AUDIT_INHERITANCE_STATE_DIR:?}/managed-edge-deleted" ] \
                        || printf '%s\n' "$audit_uuid"
                    ;;
                fiscal:$fiscal_uuid|custom:$custom_uuid|client:$client_role_uuid)
                    printf '%s\n' "$audit_uuid"
                    ;;
            esac
            exit 0
        fi
        if [ "$command_name" = delete ] \
                && [ "$scenario" = managed-direct ] \
                && [ "$parent_uuid" = "$super_uuid" ]; then
            printf 'delete|%s\n' "$resource" >> "${AUDIT_INHERITANCE_MUTATION_LOG:?}"
            : > "${AUDIT_INHERITANCE_STATE_DIR:?}/managed-edge-deleted"
            exit 0
        fi
        ;;
esac

echo "unexpected audit-inheritance fake call: $*" >&2
exit 99
EOF
chmod 700 "$AUDIT_INHERITANCE_FAKE_KCADM"

run_audit_inheritance_scenario() {
    inheritance_scenario="$1"
    inheritance_scenario_root="$2"
    mkdir -p "$inheritance_scenario_root/state"
    : > "$inheritance_scenario_root/mutations.log"
    (
        set -eu
        config=synthetic-config
        composite_children_file="$inheritance_scenario_root/composite-children.list"
        composite_children_page_file="$inheritance_scenario_root/composite-page.list"
        composite_payload="$inheritance_scenario_root/composite-payload.json"
        composite_queue_file="$inheritance_scenario_root/composite-queue.list"
        composite_visited_file="$inheritance_scenario_root/composite-visited.list"
        role_inventory_page_file="$inheritance_scenario_root/role-page.csv"
        client_inventory_page_file="$inheritance_scenario_root/client-page.csv"
        all_role_clients_file="$inheritance_scenario_root/all-clients.list"
        all_roles_file="$inheritance_scenario_root/all-roles.psv"
        all_role_ids_file="$inheritance_scenario_root/all-role-ids.list"
        role_edges_file="$inheritance_scenario_root/role-edges.psv"
        inheritance_delete_plan_file="$inheritance_scenario_root/delete-plan.psv"
        audit_role=ROLE_TENANT_AUDIT
        AUDIT_INHERITANCE_SCENARIO="$inheritance_scenario"
        AUDIT_INHERITANCE_STATE_DIR="$inheritance_scenario_root/state"
        AUDIT_INHERITANCE_MUTATION_LOG="$inheritance_scenario_root/mutations.log"
        export AUDIT_INHERITANCE_SCENARIO AUDIT_INHERITANCE_STATE_DIR \
            AUDIT_INHERITANCE_MUTATION_LOG
        # shellcheck source=/dev/null
        . "$AUDIT_INHERITANCE_BODY"
        reconcile_complete_audit_inheritance \
            saas-admin aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa
    )
}

CLEAN_INHERITANCE_ROOT="$AUDIT_INHERITANCE_ROOT/clean"
run_audit_inheritance_scenario clean "$CLEAN_INHERITANCE_ROOT"
[ ! -s "$CLEAN_INHERITANCE_ROOT/mutations.log" ] \
    || fail "clean complete role graph produced an audit-inheritance mutation"

MANAGED_INHERITANCE_ROOT="$AUDIT_INHERITANCE_ROOT/managed-direct"
run_audit_inheritance_scenario managed-direct "$MANAGED_INHERITANCE_ROOT"
[ "$(grep -c '^delete|' "$MANAGED_INHERITANCE_ROOT/mutations.log")" -eq 1 ] \
    || fail "bounded managed direct audit inheritance was not removed exactly once"

for forbidden_inheritance_scenario in fiscal custom client; do
    forbidden_inheritance_root="$AUDIT_INHERITANCE_ROOT/$forbidden_inheritance_scenario"
    if run_audit_inheritance_scenario \
            "$forbidden_inheritance_scenario" "$forbidden_inheritance_root" \
            > "$forbidden_inheritance_root.log" 2>&1; then
        fail "$forbidden_inheritance_scenario role inherited Audit without failing closed"
    fi
    [ ! -s "$forbidden_inheritance_root/mutations.log" ] \
        || fail "$forbidden_inheritance_scenario inheritance mutated before complete preflight"
    grep -Fq 'outside the bounded managed-drift allowlist' \
        "$forbidden_inheritance_root.log" \
        || fail "$forbidden_inheritance_scenario inheritance lacked the closed-state diagnostic"
done

if [ "$(grep -c '^run_forced_technical_identity_reconcile$' "$MIGRATION_SCRIPT")" -ne 2 ]; then
    fail "both persisted-volume provisioning calls must force exact reconciliation"
fi
grep -Fq -- '-e KEYCLOAK_BOOTSTRAP_ADMIN_PASSWORD \' "$MIGRATION_SCRIPT" \
    || fail "recovery password must be inherited by environment-variable name"
grep -Fq 'export KEYCLOAK_BOOTSTRAP_ADMIN_USER KEYCLOAK_BOOTSTRAP_ADMIN_PASSWORD' \
    "$MIGRATION_SCRIPT" \
    || fail "recovery credentials must be exported only inside the bounded reconciliation subshell"
if grep -Eq -- '-e[[:space:]]+"?KEYCLOAK_BOOTSTRAP_ADMIN_PASSWORD=.*RECOVERY_ADMIN_PASSWORD' \
        "$MIGRATION_SCRIPT"; then
    fail "recovery password must never be expanded into the host Compose argv"
fi
if grep -En -- '(^|[[:space:]])--(password|secret)(=|[[:space:]]|$)' \
        "$MIGRATION_SCRIPT" "$SERVICE_ACCOUNT_SCRIPT"; then
    fail "kcadm must never receive a raw password or client secret in argv"
fi
grep -Fq 'KC_CLI_PASSWORD="$RECOVERY_ADMIN_PASSWORD"' "$MIGRATION_SCRIPT" \
    || fail "recovery kcadm authentication must use the supported KC_CLI_PASSWORD channel"
grep -Fq 'KC_CLI_CLIENT_SECRET="$credential_client_secret"' "$SERVICE_ACCOUNT_SCRIPT" \
    || fail "permanent kcadm authentication must use the supported KC_CLI_CLIENT_SECRET channel"
if grep -Fq 'synthetic-secret-0123456789abcdef' "$SEMANTIC_LOG"; then
    fail "service-account secret appeared in forced-reconcile kcadm argv"
fi

POST_RESTART_SECTION="$FIXTURE_ROOT/post-restart-migration-section.sh"
awk '/restart keycloak/ { capture = 1 } capture { print }' \
    "$MIGRATION_SCRIPT" > "$POST_RESTART_SECTION"
grep -Fq 'verify_permanent_technical_identity_after_restart' "$POST_RESTART_SECTION" \
    || fail "migration must verify the permanent technical identity after restart"
for bootstrap_fallback_variable in \
        KEYCLOAK_BOOTSTRAP_ADMIN_USER \
        KEYCLOAK_BOOTSTRAP_ADMIN_PASSWORD \
        KEYCLOAK_BOOTSTRAP_ADMIN_CLIENT_ID \
        KEYCLOAK_BOOTSTRAP_ADMIN_CLIENT_SECRET; do
    grep -Fq -- "-e $bootstrap_fallback_variable=" "$MIGRATION_SCRIPT" \
        || fail "post-restart verification must suppress $bootstrap_fallback_variable fallback"
done

if grep -Eq '(^|[[:space:]])(kcadm|"\$KCADM") get realms([[:space:]]|$)' \
        "$SERVICE_ACCOUNT_SCRIPT"; then
    fail "service-account reconciliation must not enumerate Keycloak realms"
fi
grep -Fq 'EXPECTED_MANAGEMENT_ROLES="manage-users query-users view-users view-realm"' \
    "$SERVICE_ACCOUNT_SCRIPT" \
    || fail "technical service account must use the documented exact management-role allowlist"
grep -Fq 'EXPECTED_EFFECTIVE_MANAGEMENT_ROLES="manage-users query-groups query-users view-users view-realm"' \
    "$SERVICE_ACCOUNT_SCRIPT" \
    || fail "technical service account must model Keycloak native view-users inheritance exactly"
grep -Fq 'users/$service_account_id/role-mappings/realm/composite' \
    "$SERVICE_ACCOUNT_SCRIPT" \
    || fail "technical service account must verify effective global roles"
grep -Fq 'users/$service_account_id/role-mappings/clients/$management_client_uuid/composite' \
    "$SERVICE_ACCOUNT_SCRIPT" \
    || fail "technical service account must verify effective realm-management roles"
grep -Fq 'reconcile_realm_management_roles \' "$SERVICE_ACCOUNT_SCRIPT" \
    || fail "technical service account must reconcile allowlisted and non-allowlisted management mappings"
grep -Fq 'done < "$ALL_MASTER_CLIENTS_FILE"' "$SERVICE_ACCOUNT_SCRIPT" \
    || fail "technical service account must reject roles from every non-management master client"
grep -Fq '{"id":"%s","name":"%s"}' "$SERVICE_ACCOUNT_SCRIPT" \
    || fail "role-mapping revocations must send complete id-and-name representations"

if [ -e "$REPOSITORY_ROOT/backend/app/src/main/resources/keycloak/realm-template.json" ]; then
    fail "backend tenant realm provisioning must not depend on a realm JSON template"
fi
grep -Fq 'new RealmRepresentation()' \
    "$REPOSITORY_ROOT/backend/app/src/main/java/br/com/duoset/saas_service/contexts/tenant/internal/infrastructure/iam/KeycloakTenantRealmRepresentationFactory.java" \
    || fail "backend tenant realm provisioning must construct RealmRepresentation programmatically"
if ! bash "$VALIDATOR_SCRIPT" > "$FIXTURE_ROOT/validator-baseline.log" 2>&1; then
    fail "Admin API realm contracts did not pass the static validator"
fi

bash "$REPOSITORY_ROOT/infra/scripts/tests/keycloak-billing-mfa-amr-test.sh"
bash "$REPOSITORY_ROOT/infra/scripts/tests/keycloak-admin-login-mfa-toggle-test.sh"
bash "$REPOSITORY_ROOT/infra/scripts/tests/keycloak-tenant-first-login-mfa-toggle-test.sh"
bash "$REPOSITORY_ROOT/infra/scripts/tests/keycloak-realm-smtp-test.sh"
bash "$REPOSITORY_ROOT/infra/scripts/tests/keycloak-mailpit-compose-contract-test.sh"
bash "$REPOSITORY_ROOT/infra/scripts/tests/keycloak-production-smtp-validation-test.sh"

echo "PASS: Keycloak bootstrap enforces forced reconcile, realm SMTP, composite isolation, effective mapper checks, and least privilege"
