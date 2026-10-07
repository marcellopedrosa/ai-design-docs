#!/bin/bash

set -euo pipefail

PROJECT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")/../../.." && pwd)"
VALIDATOR="$PROJECT_DIR/infra/keycloak/bootstrap/validate-keycloak-runtime-json.sh"
TEST_DIRECTORY="$(mktemp -d)"
OUTPUT_FILE="$TEST_DIRECTORY/output"
ERROR_FILE="$TEST_DIRECTORY/error"
JSON_FILE="$TEST_DIRECTORY/input.json"
REALMS_FILE="$TEST_DIRECTORY/managed-realms.list"
PASS_COUNT=0

cleanup() {
    rm -rf "$TEST_DIRECTORY"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

fail() {
    echo "FAIL: $*" >&2
    exit 1
}

write_json() {
    printf '%s\n' "$1" > "$JSON_FILE"
}

structural_item_token() {
    local item_value="$1"
    local item_escaped="${2:-0}"
    local item_index item_character item_code item_hex encoded_item=""
    for ((item_index = 0; item_index < ${#item_value}; item_index++)); do
        item_character=${item_value:item_index:1}
        printf -v item_code '%d' "'$item_character"
        printf -v item_hex '%02x' "$item_code"
        encoded_item+=$item_hex
    done
    printf '%s-%s' "$item_escaped" "$encoded_item"
}

expect_output() {
    test_name="$1"
    expected_output="$2"
    shift 2
    if ! "$@" > "$OUTPUT_FILE" 2> "$ERROR_FILE"; then
        echo "Validator stderr for $test_name:" >&2
        sed -n '1,8p' "$ERROR_FILE" >&2
        fail "$test_name unexpectedly failed"
    fi
    actual_output="$(tr -d '\r' < "$OUTPUT_FILE")"
    [ "$actual_output" = "$expected_output" ] \
        || fail "$test_name returned '$actual_output' instead of '$expected_output'"
    PASS_COUNT=$((PASS_COUNT + 1))
}

expect_failure() {
    test_name="$1"
    shift
    if "$@" > "$OUTPUT_FILE" 2> "$ERROR_FILE"; then
        fail "$test_name unexpectedly succeeded"
    fi
    grep -Eq '^(ERROR:|Usage:)' "$ERROR_FILE" \
        || fail "$test_name did not return a bounded diagnostic"
    PASS_COUNT=$((PASS_COUNT + 1))
}

[ -f "$VALIDATOR" ] || fail "runtime JSON validator is missing"
bash -n "$VALIDATOR" || fail "runtime JSON validator is not valid Bash syntax"
IFS= read -r validator_shebang < "$VALIDATOR"
[ "$validator_shebang" = '#!/bin/bash' ] \
    || fail "runtime JSON validator must declare the guaranteed Bash runtime"
if grep -Eq '(^|[[:space:];|&])(awk|jq|python3?|perl|node)([[:space:];|&]|$)' "$VALIDATOR"; then
    fail "runtime JSON validator depends on a prohibited JSON runtime"
fi

printf '%s\n' saas-admin saas-example > "$REALMS_FILE"

write_json '{"iss":"http://keycloak/realms/master","azp":"saas-realm-provisioner","iat":1.25e+3,"aud":["master-realm"],"active":true,"nullable":null,"realm_access":{"roles":["create-realm"]},"resource_access":{"saas-example-realm":{"roles":["view-users","manage-users","query-groups","view-realm","query-users"]},"saas-admin-realm":{"roles":["manage-users","query-groups","query-users","view-users","view-realm"]}}}'
expect_output "exact token" "" \
    bash "$VALIDATOR" token "$JSON_FILE" saas-realm-provisioner "$REALMS_FILE"

write_json '{"azp":"saas-realm-provisioner","realm_access":{"roles":["create-realm"]},"resource_access":{"saas-admin-realm":{"roles":["manage-users","query-users","view-users","view-realm"]},"saas-example-realm":{"roles":["manage-users","query-groups","query-users","view-users","view-realm"]}}}'
expect_failure "missing inherited query-groups" \
    bash "$VALIDATOR" token "$JSON_FILE" saas-realm-provisioner "$REALMS_FILE"

write_json '{"azp":"saas-realm-provisioner","decoy":{"realm_access":{"roles":["create-realm"]},"resource_access":{"saas-admin-realm":{"roles":["manage-users","query-groups","query-users","view-users","view-realm"]},"saas-example-realm":{"roles":["manage-users","query-groups","query-users","view-users","view-realm"]}}}}'
expect_failure "nested token containers" \
    bash "$VALIDATOR" token "$JSON_FILE" saas-realm-provisioner "$REALMS_FILE"

write_json '{"azp":"saas-realm-provisioner","note":"realm_access and resource_access decoys with roles","realm_access":{"roles":["create-realm"]}}'
expect_failure "string token decoy" \
    bash "$VALIDATOR" token "$JSON_FILE" saas-realm-provisioner "$REALMS_FILE"

write_json '{"azp":"saas-realm-provisioner","realm_\u0061ccess":{"roles":["create-realm"]},"resource_access":{}}'
expect_failure "escaped relevant token key" \
    bash "$VALIDATOR" token "$JSON_FILE" saas-realm-provisioner "$REALMS_FILE"

write_json '{"azp":"saas-realm-provisioner","realm_access":{"roles":["create-realm"]},"realm_access":{"roles":["create-realm"]},"resource_access":{}}'
expect_failure "duplicate relevant token key" \
    bash "$VALIDATOR" token "$JSON_FILE" saas-realm-provisioner "$REALMS_FILE"

write_json '{"azp":"saas-realm-provisioner","realm_access":{"roles":["create-realm"]},"resource_access":{"saas-admin-realm":{"roles":["manage-users","query-groups","query-users","view-users","view-realm"]},"saas-example-realm":{"roles":["manage-users","query-groups","query-users","view-users","view-realm"]},"account":{"roles":["view-profile"]}}}'
expect_failure "extra token resource client" \
    bash "$VALIDATOR" token "$JSON_FILE" saas-realm-provisioner "$REALMS_FILE"

write_json '{"azp":"saas-realm-provisioner","realm_access":{"roles":["create-realm"]},"resource_access":{"saas-admin-realm":{"roles":["manage-users","query-groups","query-users","view-users","view-users","view-realm"]},"saas-example-realm":{"roles":["manage-users","query-groups","query-users","view-users","view-realm"]}}}'
expect_failure "duplicate token role" \
    bash "$VALIDATOR" token "$JSON_FILE" saas-realm-provisioner "$REALMS_FILE"

write_json '{"azp":"saas-realm-provisioner","realm_access":{"roles":["create-realm"]},"resource_access":{"saas-admin-realm":{"roles":["manage-users","query-groups","query-users","view-users","view-realm"]},"saas-example-realm":{"roles":["manage-users","query-groups","query-users","view-users","view-realm"]}}} trailing'
expect_failure "trailing token data" \
    bash "$VALIDATOR" token "$JSON_FILE" saas-realm-provisioner "$REALMS_FILE"

write_json '{"clientId":"saas-realm-provisioner","attributes":{"saas.provisioning.managed-by":"saas-service","saas.provisioning.contract-version":"1"},"note":"nested and string decoys cannot alter ownership"}'
expect_output "managed client" "managed" \
    bash "$VALIDATOR" client "$JSON_FILE" saas-realm-provisioner

write_json '{"clientId":"saas-realm-provisioner","enabled":true,"publicClient":false,"bearerOnly":false,"standardFlowEnabled":false,"implicitFlowEnabled":false,"directAccessGrantsEnabled":false,"serviceAccountsEnabled":true,"clientAuthenticatorType":"client-secret","protocol":"openid-connect"}'
expect_output "strict legacy client" "legacy" \
    bash "$VALIDATOR" client "$JSON_FILE" saas-realm-provisioner

write_json '{"clientId":"saas-realm-provisioner","decoy":{"attributes":{"saas.provisioning.managed-by":"saas-service","saas.provisioning.contract-version":"1"}},"note":"\"saas.provisioning.managed-by\":\"saas-service\""}'
expect_output "nested client marker decoy" "unowned" \
    bash "$VALIDATOR" client "$JSON_FILE" saas-realm-provisioner

write_json '{"clientId":"saas-realm-provisioner","enabled":true,"publicClient":false,"bearerOnly":false,"standardFlowEnabled":false,"implicitFlowEnabled":false,"directAccessGrantsEnabled":false,"serviceAccountsEnabled":true,"clientAuthenticatorType":"client-secret","protocol":"openid-connect","attributes":{"saas.provisioning.managed-by":"saas-service"}}'
expect_output "partial marker blocks legacy adoption" "unowned" \
    bash "$VALIDATOR" client "$JSON_FILE" saas-realm-provisioner

write_json '{"clientId":"saas-realm-provisioner","enabled":true,"publicClient":false,"bearerOnly":false,"standardFlowEnabled":false,"implicitFlowEnabled":false,"directAccessGrantsEnabled":false,"serviceAccountsEnabled":true,"clientAuthenticatorType":"client-secret","protocol":"openid-connect","attributes":{"saas.provisioning.managed-by":"saas-service","saas.provisioning.contract-version":"2"}}'
expect_output "unsupported marker version blocks legacy adoption" "unowned" \
    bash "$VALIDATOR" client "$JSON_FILE" saas-realm-provisioner

write_json '{"clientId":"saas-realm-provisioner","enabled":true,"publicClient":false,"bearerOnly":false,"standardFlowEnabled":false,"implicitFlowEnabled":false,"directAccessGrantsEnabled":false,"serviceAccountsEnabled":true,"clientAuthenticatorType":"client-secret","protocol":"openid-connect","attributes":"not-an-object"}'
expect_output "non-object attributes block legacy adoption" "unowned" \
    bash "$VALIDATOR" client "$JSON_FILE" saas-realm-provisioner

write_json '{"clientId":"saas-realm-provisioner","enabled":true,"publicClient":false,"bearerOnly":false,"standardFlowEnabled":false,"implicitFlowEnabled":true,"directAccessGrantsEnabled":false,"serviceAccountsEnabled":true,"clientAuthenticatorType":"client-secret","protocol":"openid-connect"}'
expect_output "implicit legacy flow is not adoptable" "unowned" \
    bash "$VALIDATOR" client "$JSON_FILE" saas-realm-provisioner

write_json '{"clientId":"saas-realm-provisioner","attributes":{"saas.provisioning.managed-\u0062y":"saas-service","saas.provisioning.contract-version":"1"}}'
expect_failure "escaped client marker key" \
    bash "$VALIDATOR" client "$JSON_FILE" saas-realm-provisioner

write_json '{"clientId":"saas-realm-provisioner","clientId":"another-client"}'
expect_failure "duplicate client ID" \
    bash "$VALIDATOR" client "$JSON_FILE" saas-realm-provisioner

write_json '{"clientId":"another-client"}'
expect_failure "mismatched client ID" \
    bash "$VALIDATOR" client "$JSON_FILE" saas-realm-provisioner

write_json '{"name":"tenant_id-mapper","protocol":"openid-connect","protocolMapper":"oidc-usermodel-attribute-mapper","config":{"user.attribute":"tenant_id","claim.name":"tenant_id"}}'
expect_output "managed API mapper" "emits=true fingerprint=managed" \
    bash "$VALIDATOR" mapper "$JSON_FILE" saas-service-api

write_json '{"name":"tenant_id","protocol":"openid-connect","protocolMapper":"oidc-hardcoded-claim-mapper","config":{"claim.name":"tenant_id","claim.value":"11111111-1111-1111-1111-111111111111"}}'
expect_output "managed SPA mapper" "emits=true fingerprint=managed" \
    bash "$VALIDATOR" mapper "$JSON_FILE" saas-frontend-spa

write_json '{"name":"ordinary-mapper","protocol":"openid-connect","protocolMapper":"oidc-hardcoded-claim-mapper","config":{"claim.name":"ordinary_claim"},"decoy":{"name":"tenant_id","config":{"claim.name":"tenant_id"}},"note":"\"user.attribute\":\"tenant_id\""}'
expect_output "nested mapper decoys" "emits=false fingerprint=unknown" \
    bash "$VALIDATOR" mapper "$JSON_FILE" saas-service-api

write_json '{"name":"tenant_id-mapper","protocol":"openid-connect","protocolMapper":"different-mapper","config":{"claim.name":"ordinary_claim"}}'
expect_output "emitting mapper with unknown fingerprint" "emits=true fingerprint=unknown" \
    bash "$VALIDATOR" mapper "$JSON_FILE" saas-service-api

write_json '{"name":"ordinary-mapper","protocol":"openid-connect","protocolMapper":"oidc-usermodel-attribute-mapper","config":{"claim.name":"tenant\u005fid","user.attribute":"ordinary"}}'
expect_failure "escaped mapper value is rejected" \
    bash "$VALIDATOR" mapper "$JSON_FILE" saas-service-api

write_json '{"name":"ordinary-mapper","config":{"cl\u0061im.name":"tenant_id"}}'
expect_failure "escaped mapper key" \
    bash "$VALIDATOR" mapper "$JSON_FILE" saas-service-api

write_json '{"name":"ordinary-mapper","config":{"claim.name":"tenant_id","claim.name":"ordinary_claim"}}'
expect_failure "duplicate mapper config key" \
    bash "$VALIDATOR" mapper "$JSON_FILE" saas-service-api

write_json '{"name":"ordinary-mapper","protocol":"openid-connect","config":{}}'
expect_failure "mapper missing canonical top-level field" \
    bash "$VALIDATOR" mapper "$JSON_FILE" saas-service-api

required_action_enabled='{"alias":"CONFIGURE_TOTP","name":"Configure OTP / DEV","providerId":"CONFIGURE_TOTP","enabled":true,"defaultAction":false,"priority":20,"config":{"sentinel":"preserve-me","nested":"{\"enabled\":true}"}}'
required_action_disabled='{"alias":"CONFIGURE_TOTP","name":"Configure OTP / DEV","providerId":"CONFIGURE_TOTP","enabled":false,"defaultAction":false,"priority":20,"config":{"sentinel":"preserve-me","nested":"{\"enabled\":true}"}}'
write_json "$required_action_enabled"
expect_output "required action current state" "enabled=true" \
    bash "$VALIDATOR" admin-login-required-action "$JSON_FILE"
expect_output "required action preserving disable payload" "$required_action_disabled" \
    bash "$VALIDATOR" admin-login-required-action "$JSON_FILE" false

write_json "$required_action_disabled"
expect_output "required action preserving rollback payload" "$required_action_enabled" \
    bash "$VALIDATOR" admin-login-required-action "$JSON_FILE" true

write_json '{"alias":"CONFIGURE_TOTP","name":"Configure OTP","providerId":"CONFIGURE_TOTP","enabled":true,"defaultAction":true,"priority":20,"config":{}}'
expect_failure "required action cannot become a default action" \
    bash "$VALIDATOR" admin-login-required-action "$JSON_FILE" false

write_json '{"alias":"CONFIGURE_TOTP","name":"Configure OTP","providerId":"CONFIGURE_TOTP","enabled":true,"defaultAction":false,"priority":20,"config":{},"unexpected":true}'
expect_failure "required action exact field set" \
    bash "$VALIDATOR" admin-login-required-action "$JSON_FILE" false

write_json '{"alias":"CONFIGURE_TOTP","name":"Configure OTP","providerId":"CONFIGURE_TOTP","enabled":true,"defaultAction":false,"priority":20.5,"config":{}}'
expect_failure "required action integer priority" \
    bash "$VALIDATOR" admin-login-required-action "$JSON_FILE" false

write_json '{"alias":"CONFIGURE_TOTP","name":"Configure OTP","providerId":"CONFIGURE_TOTP","enabled":true,"defaultAction":false,"priority":20,"config":{"invalid":{"nested":true}}}'
expect_failure "required action config values must remain strings" \
    bash "$VALIDATOR" admin-login-required-action "$JSON_FILE" false

write_json '[{"id":"external,id","clientId":"external,client"},{"id":"aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee","clientId":"saas-recovery-deadbeef"}]'
recovery_clients_expected="$(printf 'count=2\nitem\t%s\nitem\t%s\ncandidate\taaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee\tsaas-recovery-deadbeef' \
    "$(structural_item_token 'external,id')" \
    "$(structural_item_token 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee')")"
expect_output "client recovery page tolerates external commas" \
    "$recovery_clients_expected" \
    bash "$VALIDATOR" recovery-page "$JSON_FILE" clients

write_json '[{"id":"federated,opaque,id","username":"external,user"},{"id":"11111111-2222-3333-4444-555555555555","username":"saas-recovery-user-deadbeef"}]'
recovery_users_expected="$(printf 'count=2\nitem\t%s\nitem\t%s\ncandidate\t11111111-2222-3333-4444-555555555555\tsaas-recovery-user-deadbeef' \
    "$(structural_item_token 'federated,opaque,id')" \
    "$(structural_item_token '11111111-2222-3333-4444-555555555555')")"
expect_output "user recovery page tolerates external commas" \
    "$recovery_users_expected" \
    bash "$VALIDATOR" recovery-page "$JSON_FILE" users

write_json '[{"id":"external-id","username":"external\u002cuser"}]'
escaped_external_expected="$(printf 'count=1\nitem\t%s' \
    "$(structural_item_token 'external-id')")"
expect_output "escaped external recovery name is ignored" "$escaped_external_expected" \
    bash "$VALIDATOR" recovery-page "$JSON_FILE" users

write_json '[{"id":"external-id"}]'
expect_failure "recovery entry missing top-level name" \
    bash "$VALIDATOR" recovery-page "$JSON_FILE" clients

write_json '[{"id":"external-id","clientId":"external","clientId":"saas-recovery-deadbeef"}]'
expect_failure "duplicate recovery page field" \
    bash "$VALIDATOR" recovery-page "$JSON_FILE" clients

write_json '[{"id":"not,a,uuid","username":"saas-recovery-user-deadbeef"}]'
expect_failure "reserved recovery candidate invalid UUID" \
    bash "$VALIDATOR" recovery-page "$JSON_FILE" users

write_json '[{"id":"aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeee","username":"saas-recovery-user-deadbeef"}]'
expect_failure "reserved recovery candidate non-canonical UUID" \
    bash "$VALIDATOR" recovery-page "$JSON_FILE" users

write_json '[{"id":"aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee","clientId":"saas-recovery-,unsafe"}]'
expect_failure "reserved recovery candidate unsafe name" \
    bash "$VALIDATOR" recovery-page "$JSON_FILE" clients

oversized_page='['
oversized_index=0
oversized_separator=''
while [ "$oversized_index" -lt 101 ]; do
    oversized_page="${oversized_page}${oversized_separator}{\"id\":\"external-$oversized_index\",\"clientId\":\"external-$oversized_index\"}"
    oversized_separator=','
    oversized_index=$((oversized_index + 1))
done
oversized_page="${oversized_page}]"
write_json "$oversized_page"
expect_failure "recovery page item limit" \
    bash "$VALIDATOR" recovery-page "$JSON_FILE" clients

nested_json='{}'
nested_depth=0
while [ "$nested_depth" -lt 32 ]; do
    nested_json="{\"nested\":$nested_json}"
    nested_depth=$((nested_depth + 1))
done
write_json "$nested_json"
expect_failure "JSON nesting depth limit" \
    bash "$VALIDATOR" mapper "$JSON_FILE" saas-service-api

printf -v oversized_padding '%*s' 65536 ''
oversized_padding=${oversized_padding// /x}
printf '{"padding":"%s"}' "$oversized_padding" > "$JSON_FILE"
expect_failure "JSON byte limit" \
    bash "$VALIDATOR" mapper "$JSON_FILE" saas-service-api

printf 'saas-admin\nsaas-admin\n' > "$REALMS_FILE"
write_json '{"azp":"saas-realm-provisioner","realm_access":{"roles":["create-realm"]},"resource_access":{}}'
expect_failure "duplicate managed realm" \
    bash "$VALIDATOR" token "$JSON_FILE" saas-realm-provisioner "$REALMS_FILE"

echo "PASS: $PASS_COUNT structural Keycloak runtime JSON validator scenarios"
