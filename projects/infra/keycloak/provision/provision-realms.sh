#!/bin/sh

set -eu
umask 077

KCADM_BIN="${KCADM_BIN:-/opt/keycloak/bin/kcadm.sh}"
REALM_SMTP_RECONCILER="${REALM_SMTP_RECONCILER:-/opt/keycloak/bootstrap/reconcile-realm-smtp.sh}"
ADMIN_REALM=saas-admin
TENANT_REALM=saas-bpfarias
TENANT_ID=aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa
SUPER_ADMIN_EMAIL=djmarcellopedrosa@gmail.com
TENANT_ADMIN_EMAIL=contato@matrizcontabil.com.br
ADMIN_ROLES='ROLE_SUPER_ADMIN ROLE_COMMERCIAL BILLING_CATALOG_READ BILLING_CATALOG_DRAFT BILLING_PRICE_SIMULATE BILLING_PRICE_SUBMIT BILLING_PRICE_APPROVE BILLING_PRICE_PUBLISH BILLING_TENANT_IMPERSONATE BILLING_CONTRACT_DRAFT BILLING_CONTRACT_SUBMIT BILLING_CONTRACT_ACCEPT_RECORD BILLING_CONTRACT_ACCEPT_VALIDATE BILLING_INVOICE_PREVIEW BILLING_INVOICE_APPROVE BILLING_INVOICE_FINALIZE BILLING_PROVIDER_READ BILLING_PROVIDER_CONFIGURE BILLING_PROVIDER_SUBMIT BILLING_PROVIDER_APPROVE BILLING_PROVIDER_ACTIVATE BILLING_PROVIDER_INTERACTION_READ ROLE_TENANT_AUDIT ROLE_TENANT_ADMIN ROLE_TENANT_USER ROLE_FISCAL_READER ROLE_FISCAL_ADMIN'
ADMIN_COMPOSITES='BILLING_CATALOG_READ BILLING_CATALOG_DRAFT BILLING_PRICE_SIMULATE BILLING_PRICE_SUBMIT BILLING_PRICE_APPROVE BILLING_PRICE_PUBLISH BILLING_TENANT_IMPERSONATE BILLING_CONTRACT_DRAFT BILLING_CONTRACT_SUBMIT BILLING_CONTRACT_ACCEPT_RECORD BILLING_CONTRACT_ACCEPT_VALIDATE BILLING_INVOICE_PREVIEW BILLING_INVOICE_APPROVE BILLING_INVOICE_FINALIZE'
TENANT_ROLES='ROLE_TENANT_ADMIN BILLING_CONTRACT_DRAFT BILLING_CONTRACT_SUBMIT BILLING_CONTRACT_ACCEPT BILLING_INVOICE_PREVIEW BILLING_PROVIDER_INTERACTION_READ ROLE_TENANT_AUDIT ROLE_TENANT_USER ROLE_FISCAL_READER ROLE_FISCAL_ADMIN'
TENANT_COMPOSITES='BILLING_CONTRACT_DRAFT BILLING_CONTRACT_SUBMIT BILLING_CONTRACT_ACCEPT BILLING_INVOICE_PREVIEW'

fail() { echo "ERROR: $*" >&2; exit 1; }

[ "$#" -eq 1 ] || fail "Usage: $0 KCADM_CONFIG"
KCADM_CONFIG="$1"
[ -r "$KCADM_CONFIG" ] || fail "authenticated kcadm configuration is unavailable"
[ -x "$KCADM_BIN" ] || fail "Keycloak administration client is unavailable"
[ -x "$REALM_SMTP_RECONCILER" ] || fail "Keycloak realm SMTP reconciler is unavailable"
case "${KEYCLOAK_PROVISION_ENV:-}" in dev|hml|production) ;; *) fail "invalid environment" ;; esac
printf '%s\n' "${KEYCLOAK_FRONTEND_REDIRECTS:?}" | grep -Eq '^https?://[A-Za-z0-9.:-]+/\*(,https?://[A-Za-z0-9.:-]+/\*)*$' || fail "invalid redirects"
printf '%s\n' "${KEYCLOAK_FRONTEND_ORIGINS:?}" | grep -Eq '^https?://[A-Za-z0-9.:-]+(,https?://[A-Za-z0-9.:-]+)*$' || fail "invalid origins"

"$REALM_SMTP_RECONCILER" preflight "$KCADM_CONFIG" >/dev/null

kcadm() { "$KCADM_BIN" "$@" --config "$KCADM_CONFIG"; }
csv_json_array() { printf '["%s"]' "$(printf '%s' "$1" | sed 's/,/","/g')"; }
realm_exists() { kcadm get "realms/$1" --fields realm --format csv --noquotes 2>/dev/null | tr -d '\r' | grep -Fxq "$1"; }

verify_single() {
    count="$(kcadm get "$1" -r "$2" -q "$3" -q first=0 -q max=2 --fields id --format csv --noquotes | tr -d '\r' | grep -c . || true)"
    [ "$count" -eq 1 ] || fail "$4 is absent or ambiguous in $2"
}

create_realm() {
    kcadm create realms -s "realm=$1" -s "displayName=$2" -s enabled=true \
        -s loginTheme=saas-theme \
        -s sslRequired=external -s registrationAllowed=false \
        -s loginWithEmailAllowed=true -s duplicateEmailsAllowed=false \
        -s resetPasswordAllowed=true -s editUsernameAllowed=false \
        -s bruteForceProtected=true -s permanentLockout=false \
        -s waitIncrementSeconds=60 -s quickLoginCheckMilliSeconds=1000 \
        -s minimumQuickLoginWaitSeconds=60 -s maxDeltaTimeSeconds=43200 \
        -s failureFactor=5 -s ssoSessionIdleTimeout=1800 \
        -s ssoSessionMaxLifespan=36000 -s accessTokenLifespan=300 >/dev/null
    kcadm update users/profile -r "$1" -s unmanagedAttributePolicy=ADMIN_EDIT >/dev/null
}

ensure_user_profile() {
    kcadm update users/profile -r "$1" -s unmanagedAttributePolicy=ADMIN_EDIT >/dev/null
}

ensure_realm_theme() {
    kcadm update "realms/$1" -s loginTheme=saas-theme >/dev/null
}

create_roles() {
    for role in $2; do
        composite=false
        case "$role" in ROLE_SUPER_ADMIN|ROLE_TENANT_ADMIN) composite=true ;; esac
        kcadm create roles -r "$1" -s "name=$role" -s "composite=$composite" -s clientRole=false >/dev/null
    done
}

add_composites() {
    for child in $3; do
        kcadm add-roles -r "$1" --rname "$2" --rolename "$child" >/dev/null
    done
}

create_client() {
    realm="$1" client_id="$2" client_name="$3" client_kind="$4"
    if [ "$client_kind" = api ]; then
        kcadm create clients -r "$realm" -i -s "clientId=$client_id" -s "name=$client_name" \
            -s enabled=true -s bearerOnly=true -s publicClient=false \
            -s standardFlowEnabled=false -s directAccessGrantsEnabled=false \
            -s serviceAccountsEnabled=false -s fullScopeAllowed=false -s protocol=openid-connect
    else
        redirects="$(csv_json_array "$KEYCLOAK_FRONTEND_REDIRECTS")"
        origins="$(csv_json_array "$KEYCLOAK_FRONTEND_ORIGINS")"
        kcadm create clients -r "$realm" -i -s "clientId=$client_id" -s "name=$client_name" \
            -s enabled=true -s publicClient=true -s bearerOnly=false \
            -s standardFlowEnabled=true -s directAccessGrantsEnabled=true \
            -s serviceAccountsEnabled=false -s fullScopeAllowed=false -s protocol=openid-connect \
            -s "redirectUris=$redirects" -s "webOrigins=$origins" \
            -s 'attributes={"pkce.code.challenge.method":"S256"}'
    fi
}

create_mapper() {
    kcadm create "clients/$2/protocol-mappers/models" -r "$1" \
        -s "name=$3" -s protocol=openid-connect -s "protocolMapper=$4" \
        -s consentRequired=false -s "config=$5" >/dev/null
}

create_mappers() {
    realm="$1" api_uuid="$2" spa_uuid="$3" tenant="$4"
    role_config='{"claim.name":"realm_access.roles","jsonType.label":"String","id.token.claim":"true","access.token.claim":"true","userinfo.token.claim":"true","multivalued":"true"}'
    human_config='{"user.attribute":"human_principal_id","claim.name":"human_principal_id","jsonType.label":"String","id.token.claim":"false","access.token.claim":"true","userinfo.token.claim":"false","multivalued":"false","aggregate.attrs":"false"}'
    audience_config='{"included.client.audience":"saas-service-api","id.token.claim":"false","access.token.claim":"true","introspection.token.claim":"true"}'
    amr_config='{"id.token.claim":"false","access.token.claim":"true"}'
    create_mapper "$realm" "$api_uuid" realm-roles-mapper oidc-usermodel-realm-role-mapper "$role_config"
    create_mapper "$realm" "$spa_uuid" saas-service-api-audience oidc-audience-mapper "$audience_config"
    create_mapper "$realm" "$spa_uuid" human-principal-id oidc-usermodel-attribute-mapper "$human_config"
    create_mapper "$realm" "$spa_uuid" authentication-method-reference oidc-amr-mapper "$amr_config"
    create_mapper "$realm" "$spa_uuid" realm-roles-mapper oidc-usermodel-realm-role-mapper "$role_config"
    if [ "$tenant" = true ]; then
        tenant_user='{"user.attribute":"tenant_id","claim.name":"tenant_id","jsonType.label":"String","id.token.claim":"true","access.token.claim":"true","userinfo.token.claim":"true","multivalued":"false","aggregate.attrs":"false"}'
        tenant_value="{\"claim.name\":\"tenant_id\",\"claim.value\":\"$TENANT_ID\",\"jsonType.label\":\"String\",\"id.token.claim\":\"false\",\"access.token.claim\":\"true\",\"userinfo.token.claim\":\"false\"}"
        create_mapper "$realm" "$api_uuid" tenant_id-mapper oidc-usermodel-attribute-mapper "$tenant_user"
        create_mapper "$realm" "$spa_uuid" tenant_id oidc-hardcoded-claim-mapper "$tenant_value"
    fi
}

ensure_user_no_otp() {
    realm="$1" user_id="$2"
    actions="$(kcadm get "users/$user_id" -r "$realm" --fields requiredActions --format csv --noquotes 2>/dev/null | tr -d '\r' || true)"
    case "$actions" in
        *CONFIGURE_TOTP*)
            case "$actions" in
                *UPDATE_PASSWORD*)
                    kcadm update "users/$user_id" -r "$realm" -s 'requiredActions=["UPDATE_PASSWORD"]' >/dev/null
                    ;;
                *)
                    kcadm update "users/$user_id" -r "$realm" -s 'requiredActions=[]' >/dev/null
                    ;;
            esac
            ;;
    esac
}

ensure_user() {
    realm="$1" email="$2" first_name="$3" last_name="$4" principal="$5" roles="$6"
    ids="$(kcadm get users -r "$realm" -q "username=$email" -q exact=true -q first=0 -q max=2 --fields id --format csv --noquotes | tr -d '\r')"
    count="$(printf '%s\n' "$ids" | grep -c . || true)"
    [ "$count" -le 1 ] || fail "$email is ambiguous in $realm"
    if [ "$count" -eq 0 ]; then
        actual_id="$(kcadm create users -r "$realm" -i -s "username=$email" \
            -s "email=$email" -s "firstName=$first_name" -s "lastName=$last_name" \
            -s enabled=true -s emailVerified=true \
            -s 'requiredActions=["UPDATE_PASSWORD"]' \
            -s "attributes.human_principal_id=[\"$principal\"]")"
    else
        actual_id="$ids"
    fi
    printf '%s\n' "$actual_id" \
        | grep -Eq '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$' \
        || fail "$email returned an invalid IAM ID"
    ensure_user_no_otp "$realm" "$actual_id"
    for role in $roles; do kcadm add-roles -r "$realm" --uid "$actual_id" --rolename "$role" >/dev/null; done
    printf '%s\n' "$actual_id"
}

verify_existing() {
    for role in $2; do
        kcadm get "roles/$role" -r "$1" --fields name --format csv --noquotes \
            | tr -d '\r' | grep -Fxq "$role" || fail "$role is missing from $1"
    done
}

provision_new() {
    create_realm "$1" "$2"
    create_roles "$1" "$3"
    add_composites "$1" "$4" "$5"
    api_uuid="$(create_client "$1" saas-service-api 'SaaS Service API' api)"
    spa_uuid="$(create_client "$1" saas-frontend-spa 'SaaS Frontend SPA' spa)"
    create_mappers "$1" "$api_uuid" "$spa_uuid" "$6"
}

if realm_exists "$ADMIN_REALM"; then
    verify_existing "$ADMIN_REALM" "$ADMIN_ROLES"
    ensure_user_profile "$ADMIN_REALM"
    ensure_realm_theme "$ADMIN_REALM"
else
    provision_new "$ADMIN_REALM" 'Administração do Sistema' "$ADMIN_ROLES" ROLE_SUPER_ADMIN "$ADMIN_COMPOSITES" false
fi
SUPER_ADMIN_IAM_USER_ID="$(ensure_user "$ADMIN_REALM" "$SUPER_ADMIN_EMAIL" Marcello Pedrosa \
    "${KEYCLOAK_PROVISION_ENV}-superadmin-primary" 'ROLE_SUPER_ADMIN ROLE_TENANT_AUDIT')"
printf 'Reconciled Keycloak identity %s with IAM ID %s.\n' \
    "$SUPER_ADMIN_EMAIL" "$SUPER_ADMIN_IAM_USER_ID"

if realm_exists "$TENANT_REALM"; then
    verify_existing "$TENANT_REALM" "$TENANT_ROLES"
    ensure_user_profile "$TENANT_REALM"
    ensure_realm_theme "$TENANT_REALM"
else
    provision_new "$TENANT_REALM" 'BP Farias Contabilidade Estratégica LTDA' "$TENANT_ROLES" ROLE_TENANT_ADMIN "$TENANT_COMPOSITES" true
fi
TENANT_ADMIN_IAM_USER_ID="$(ensure_user "$TENANT_REALM" "$TENANT_ADMIN_EMAIL" Administrador 'BP Farias' \
    "${KEYCLOAK_PROVISION_ENV}-bpfarias-admin" ROLE_TENANT_ADMIN)"
printf 'Reconciled Keycloak identity %s with IAM ID %s.\n' \
    "$TENANT_ADMIN_EMAIL" "$TENANT_ADMIN_IAM_USER_ID"

"$REALM_SMTP_RECONCILER" reconcile "$KCADM_CONFIG" >/dev/null

echo "Static Keycloak realms are provisioned through the Admin REST API."
