#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
PROVISIONER="$ROOT/infra/keycloak/provision/provision-realms.sh"
fail() { echo "ERROR: $*" >&2; exit 1; }
[[ -x "$PROVISIONER" ]] || fail "Admin API provisioner is unavailable"
for path in infra/keycloak/dev/saas-admin-realm.json infra/keycloak/dev/saas-bpfarias-realm.json infra/keycloak/hml/saas-admin-realm.json infra/keycloak/hml/saas-bpfarias-realm.json infra/keycloak/prd/saas-admin-realm.json infra/keycloak/prd/saas-bpfarias-realm.json; do [[ ! -e "$ROOT/$path" ]] || fail "legacy realm export remains: $path"; done
for required in "ADMIN_REALM=saas-admin" "TENANT_REALM=saas-bpfarias" "ROLE_SUPER_ADMIN" "ROLE_TENANT_ADMIN" "ROLE_TENANT_AUDIT" "BILLING_PROVIDER_INTERACTION_READ" "BILLING_PROVIDER_ACTIVATE" "human-principal-id" "authentication-method-reference" "oidc-hardcoded-claim-mapper" "tenant_id" "fullScopeAllowed=false" "loginTheme=saas-theme" "requiredActions=[\"UPDATE_PASSWORD\"]"; do grep -Fq "$required" "$PROVISIONER" || fail "provisioner lacks contract: $required"; done
grep -Fq 'ensure_realm_theme' "$PROVISIONER" || fail "provisioner must reconcile login theme on existing realms"
! grep -Eq 'create users.*CONFIGURE_TOTP' "$PROVISIONER" || fail "provisioner must not configure CONFIGURE_TOTP on user creation"
grep -Fq 'if [ "$tenant" = true ]; then' "$PROVISIONER" || fail "tenant_id mapper must be limited to tenant realm"
grep -Fq 'provision_new "$ADMIN_REALM"' "$PROVISIONER" || fail "admin realm must be provisioned by Admin API"
grep -Fq 'provision_new "$TENANT_REALM"' "$PROVISIONER" || fail "tenant realm must be provisioned by Admin API"
echo "Keycloak Admin API provisioning contracts are valid."
