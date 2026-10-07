#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
bash "$ROOT/infra/keycloak/bootstrap/validate-realm-token-contracts.sh"
grep -Fq "BILLING_PROVIDER_ACTIVATE" "$ROOT/infra/keycloak/provision/provision-realms.sh"
grep -Fq "BILLING_PROVIDER_INTERACTION_READ" "$ROOT/infra/keycloak/provision/provision-realms.sh"
echo "PASS: provider authorities are governed by the Admin API provisioner."
