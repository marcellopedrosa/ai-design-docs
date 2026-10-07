#!/bin/bash

# Structural validator for the bounded Keycloak JSON documents consumed by the
# bootstrap and persisted-volume reconciliation scripts. Parsing and semantic
# checks use Bash built-ins only, so no optional JSON runtime is required.

set -euo pipefail

LC_ALL=C
export LC_ALL

readonly MAX_JSON_BYTES=65536
readonly MAX_JSON_DEPTH=32
readonly MAX_RECOVERY_PAGE_ITEMS=100
readonly KEY_SEPARATOR=$'\x1f'

usage() {
    printf 'Usage: %s token FILE EXPECTED_CLIENT_ID MANAGED_REALMS_FILE\n' "$0" >&2
    printf '       %s client FILE EXPECTED_CLIENT_ID\n' "$0" >&2
    printf '       %s mapper FILE EXPECTED_CLIENT_ID\n' "$0" >&2
    printf '       %s billing-mapper FILE human|amr\n' "$0" >&2
    printf '       %s billing-browser-flow FILE\n' "$0" >&2
    printf '       %s admin-login-required-action FILE [true|false]\n' "$0" >&2
    printf '       %s realm-smtp FILE\n' "$0" >&2
    printf '       %s billing-amr-config FILE pwd|otp EXPECTED_MANAGED_ALIAS\n' "$0" >&2
    printf '       %s recovery-page FILE users|clients\n' "$0" >&2
    exit 2
}

fail() {
    printf 'ERROR: %s\n' "$*" >&2
    exit 1
}

fatal_json() {
    printf 'ERROR: %s\n' "$*" >&2
    exit 2
}

[[ $# -ge 1 ]] || usage
validation_mode=$1
shift

recovery_page_type=
billing_mapper_kind=
billing_amr_reference=
billing_amr_managed_alias=
admin_login_mfa_target_enabled=
case "$validation_mode" in
    token)
        [[ $# -eq 3 ]] || usage
        json_file=$1
        expected_client_id=$2
        managed_realms_file=$3
        ;;
    client|mapper)
        [[ $# -eq 2 ]] || usage
        json_file=$1
        expected_client_id=$2
        managed_realms_file=
        ;;
    billing-mapper)
        [[ $# -eq 2 ]] || usage
        json_file=$1
        billing_mapper_kind=$2
        case "$billing_mapper_kind" in
            human|amr)
                ;;
            *)
                usage
                ;;
        esac
        expected_client_id=
        managed_realms_file=
        ;;
    billing-amr-config)
        [[ $# -eq 3 ]] || usage
        json_file=$1
        billing_amr_reference=$2
        billing_amr_managed_alias=$3
        case "$billing_amr_reference" in
            pwd|otp)
                ;;
            *)
                usage
                ;;
        esac
        [[ $billing_amr_managed_alias =~ ^saas-billing-amr-(pwd|otp)-v[1-9][0-9]*$ ]] \
            || usage
        expected_client_id=
        managed_realms_file=
        ;;
    billing-browser-flow)
        [[ $# -eq 1 ]] || usage
        json_file=$1
        expected_client_id=
        managed_realms_file=
        ;;
    admin-login-required-action)
        [[ $# -eq 1 || $# -eq 2 ]] || usage
        json_file=$1
        admin_login_mfa_target_enabled=${2:-}
        case "$admin_login_mfa_target_enabled" in
            ''|true|false)
                ;;
            *)
                usage
                ;;
        esac
        expected_client_id=
        managed_realms_file=
        ;;
    realm-smtp)
        [[ $# -eq 1 ]] || usage
        json_file=$1
        expected_client_id=
        managed_realms_file=
        ;;
    recovery-page)
        [[ $# -eq 2 ]] || usage
        json_file=$1
        recovery_page_type=$2
        case "$recovery_page_type" in
            users|clients)
                ;;
            *)
                usage
                ;;
        esac
        expected_client_id=
        managed_realms_file=
        ;;
    *)
        usage
        ;;
esac

[[ -f $json_file && -r $json_file ]] \
    || fail 'Keycloak JSON input must be a readable regular file.'
if [[ $validation_mode == client || $validation_mode == mapper ]]; then
    [[ $expected_client_id =~ ^[A-Za-z0-9_.:-]+$ ]] \
        || fail 'Expected client ID contains unsafe characters.'
fi

# `read -d ""` stops on a raw NUL while `-n` caps memory before parsing. A
# successful short read therefore means a forbidden NUL; a 65537-byte value is
# rejected before it can enter the parser.
BOUNDED_FILE_TEXT=
read_bounded_file() {
    local input_file=$1
    local input_description=$2
    local read_status=0

    BOUNDED_FILE_TEXT=
    if IFS= read -r -d '' -n "$((MAX_JSON_BYTES + 1))" \
            BOUNDED_FILE_TEXT < "$input_file"; then
        read_status=0
    else
        read_status=$?
    fi
    if (( read_status == 0 && ${#BOUNDED_FILE_TEXT} <= MAX_JSON_BYTES )); then
        fail "$input_description contains a raw NUL byte."
    fi
    (( ${#BOUNDED_FILE_TEXT} <= MAX_JSON_BYTES )) \
        || fail "$input_description exceeds the 65536-byte limit."
}

read_bounded_file "$json_file" 'Keycloak JSON input'
JSON_TEXT=$BOUNDED_FILE_TEXT
readonly JSON_TEXT
readonly JSON_LENGTH=${#JSON_TEXT}

declare -A MANAGED_REALMS=()
declare -A EXPECTED_RESOURCE_KEYS=()
MANAGED_REALM_COUNT=0

add_managed_realm() {
    local realm_name=$1
    [[ $realm_name =~ ^saas-[a-z0-9][a-z0-9-]*$ ]] \
        || fail 'Managed-realm allowlist contains an invalid entry.'
    [[ ! -v 'MANAGED_REALMS[$realm_name]' ]] \
        || fail 'Managed-realm allowlist contains a duplicate entry.'
    MANAGED_REALMS["$realm_name"]=1
    EXPECTED_RESOURCE_KEYS["${realm_name}-realm"]=1
    ((MANAGED_REALM_COUNT += 1))
}

if [[ $validation_mode == token ]]; then
    [[ -f $managed_realms_file && -r $managed_realms_file ]] \
        || fail 'Managed-realm allowlist must be a readable regular file.'
    read_bounded_file "$managed_realms_file" 'Managed-realm allowlist'
    managed_realms_text=$BOUNDED_FILE_TEXT
    while [[ $managed_realms_text == *$'\n'* ]]; do
        managed_realm_line=${managed_realms_text%%$'\n'*}
        managed_realms_text=${managed_realms_text#*$'\n'}
        add_managed_realm "$managed_realm_line"
    done
    if [[ -n $managed_realms_text ]]; then
        add_managed_realm "$managed_realms_text"
    fi
    (( MANAGED_REALM_COUNT > 0 )) \
        || fail 'Managed-realm allowlist must not be empty.'
fi

declare -a NODE_TYPE=()
declare -a NODE_STRING=()
declare -a NODE_STRING_ESCAPED=()
declare -a NODE_BOOLEAN=()
declare -a NODE_START=()
declare -a NODE_END=()
declare -a OBJECT_CHILD_COUNT=()
declare -a ARRAY_CHILD_COUNT=()
declare -A OBJECT_CHILD=()
declare -A OBJECT_CHILD_KEY=()
declare -A ARRAY_CHILD=()

NODE_COUNT=0
JSON_POSITION=0
NEW_NODE_ID=0
PARSED_NODE_ID=0
PARSED_STRING=
PARSED_STRING_ESCAPED=0
CHILD_NODE_ID=0
ENCODED_OBJECT_KEY=

skip_whitespace() {
    local character
    while (( JSON_POSITION < JSON_LENGTH )); do
        character=${JSON_TEXT:JSON_POSITION:1}
        case "$character" in
            ' '|$'\t'|$'\r'|$'\n')
                ((JSON_POSITION += 1))
                ;;
            *)
                return
                ;;
        esac
    done
}

next_node() {
    local node_kind=$1
    ((NODE_COUNT += 1))
    NEW_NODE_ID=$NODE_COUNT
    NODE_TYPE[NEW_NODE_ID]=$node_kind
}

# Associative-array subscripts never receive raw JSON. Encoding every object
# key as hexadecimal prevents shell metacharacters in an otherwise valid JSON
# key from acquiring any secondary meaning during lookup.
encode_object_key() {
    local object_key=$1
    local key_index key_character key_code key_hex
    ENCODED_OBJECT_KEY=
    for ((key_index = 0; key_index < ${#object_key}; key_index++)); do
        key_character=${object_key:key_index:1}
        printf -v key_code '%d' "'$key_character"
        printf -v key_hex '%02x' "$key_code"
        ENCODED_OBJECT_KEY+=$key_hex
    done
}

parse_string() {
    local character escape_character unicode_digits
    [[ ${JSON_TEXT:JSON_POSITION:1} == '"' ]] \
        || fatal_json 'Malformed JSON string.'
    ((JSON_POSITION += 1))
    PARSED_STRING=
    PARSED_STRING_ESCAPED=0

    while (( JSON_POSITION < JSON_LENGTH )); do
        character=${JSON_TEXT:JSON_POSITION:1}
        if [[ $character == '"' ]]; then
            ((JSON_POSITION += 1))
            return
        fi
        if [[ $character == '\' ]]; then
            PARSED_STRING_ESCAPED=1
            ((JSON_POSITION += 1))
            (( JSON_POSITION < JSON_LENGTH )) \
                || fatal_json 'Truncated JSON escape sequence.'
            escape_character=${JSON_TEXT:JSON_POSITION:1}
            case "$escape_character" in
                '"'|'\'|'/'|b|f|n|r|t)
                    ((JSON_POSITION += 1))
                    continue
                    ;;
                u)
                    unicode_digits=${JSON_TEXT:JSON_POSITION+1:4}
                    [[ ${#unicode_digits} -eq 4 \
                        && $unicode_digits =~ ^[0-9A-Fa-f]{4}$ ]] \
                        || fatal_json 'Invalid JSON Unicode escape sequence.'
                    ((JSON_POSITION += 5))
                    continue
                    ;;
                *)
                    fatal_json 'Invalid JSON escape sequence.'
                    ;;
            esac
        fi
        [[ ! $character =~ [[:cntrl:]] ]] \
            || fatal_json 'Unescaped control character in JSON string.'
        PARSED_STRING+=$character
        ((JSON_POSITION += 1))
    done
    fatal_json 'Unterminated JSON string.'
}

add_object_child() {
    local object_id=$1
    local object_key=$2
    local child_id=$3
    local lookup_key
    local child_count

    encode_object_key "$object_key"
    lookup_key="${object_id}${KEY_SEPARATOR}${ENCODED_OBJECT_KEY}"
    [[ ! -v 'OBJECT_CHILD[$lookup_key]' ]] \
        || fatal_json 'Duplicate JSON object key is not allowed.'
    OBJECT_CHILD["$lookup_key"]=$child_id
    child_count=$((${OBJECT_CHILD_COUNT[object_id]:-0} + 1))
    OBJECT_CHILD_COUNT[object_id]=$child_count
    OBJECT_CHILD_KEY["${object_id}${KEY_SEPARATOR}${child_count}"]=$object_key
}

parse_object() {
    local depth=$1
    local object_id object_key child_id character

    next_node object
    object_id=$NEW_NODE_ID
    ((JSON_POSITION += 1))
    skip_whitespace
    if [[ ${JSON_TEXT:JSON_POSITION:1} == '}' ]]; then
        ((JSON_POSITION += 1))
        PARSED_NODE_ID=$object_id
        return
    fi

    while true; do
        [[ ${JSON_TEXT:JSON_POSITION:1} == '"' ]] \
            || fatal_json 'JSON object key must be a string.'
        parse_string
        (( PARSED_STRING_ESCAPED == 0 )) \
            || fatal_json 'Escaped JSON object keys are not accepted by the structural contract.'
        object_key=$PARSED_STRING
        skip_whitespace
        [[ ${JSON_TEXT:JSON_POSITION:1} == ':' ]] \
            || fatal_json 'JSON object key is missing its value separator.'
        ((JSON_POSITION += 1))
        parse_value "$((depth + 1))"
        child_id=$PARSED_NODE_ID
        add_object_child "$object_id" "$object_key" "$child_id"
        skip_whitespace
        character=${JSON_TEXT:JSON_POSITION:1}
        if [[ $character == '}' ]]; then
            ((JSON_POSITION += 1))
            PARSED_NODE_ID=$object_id
            return
        fi
        [[ $character == ',' ]] \
            || fatal_json 'JSON object contains an invalid member separator.'
        ((JSON_POSITION += 1))
        skip_whitespace
    done
}

parse_array() {
    local depth=$1
    local array_id child_id character child_count

    next_node array
    array_id=$NEW_NODE_ID
    ((JSON_POSITION += 1))
    skip_whitespace
    if [[ ${JSON_TEXT:JSON_POSITION:1} == ']' ]]; then
        ((JSON_POSITION += 1))
        PARSED_NODE_ID=$array_id
        return
    fi

    while true; do
        parse_value "$((depth + 1))"
        child_id=$PARSED_NODE_ID
        child_count=$((${ARRAY_CHILD_COUNT[array_id]:-0} + 1))
        ARRAY_CHILD_COUNT[array_id]=$child_count
        ARRAY_CHILD["${array_id}${KEY_SEPARATOR}${child_count}"]=$child_id
        skip_whitespace
        character=${JSON_TEXT:JSON_POSITION:1}
        if [[ $character == ']' ]]; then
            ((JSON_POSITION += 1))
            PARSED_NODE_ID=$array_id
            return
        fi
        [[ $character == ',' ]] \
            || fatal_json 'JSON array contains an invalid element separator.'
        ((JSON_POSITION += 1))
        skip_whitespace
    done
}

parse_number() {
    local character

    next_node number
    PARSED_NODE_ID=$NEW_NODE_ID
    character=${JSON_TEXT:JSON_POSITION:1}
    if [[ $character == '-' ]]; then
        ((JSON_POSITION += 1))
        character=${JSON_TEXT:JSON_POSITION:1}
    fi
    if [[ $character == '0' ]]; then
        ((JSON_POSITION += 1))
        [[ ! ${JSON_TEXT:JSON_POSITION:1} =~ [0-9] ]] \
            || fatal_json 'JSON number contains a leading zero.'
    elif [[ $character =~ [1-9] ]]; then
        while [[ ${JSON_TEXT:JSON_POSITION:1} =~ [0-9] ]]; do
            ((JSON_POSITION += 1))
        done
    else
        fatal_json 'Malformed JSON number.'
    fi

    if [[ ${JSON_TEXT:JSON_POSITION:1} == '.' ]]; then
        ((JSON_POSITION += 1))
        [[ ${JSON_TEXT:JSON_POSITION:1} =~ [0-9] ]] \
            || fatal_json 'Malformed JSON fractional number.'
        while [[ ${JSON_TEXT:JSON_POSITION:1} =~ [0-9] ]]; do
            ((JSON_POSITION += 1))
        done
    fi
    character=${JSON_TEXT:JSON_POSITION:1}
    if [[ $character == e || $character == E ]]; then
        ((JSON_POSITION += 1))
        character=${JSON_TEXT:JSON_POSITION:1}
        if [[ $character == '+' || $character == '-' ]]; then
            ((JSON_POSITION += 1))
        fi
        [[ ${JSON_TEXT:JSON_POSITION:1} =~ [0-9] ]] \
            || fatal_json 'Malformed JSON exponent.'
        while [[ ${JSON_TEXT:JSON_POSITION:1} =~ [0-9] ]]; do
            ((JSON_POSITION += 1))
        done
    fi
}

parse_value() {
    local depth=$1
    local character value_start

    (( depth <= MAX_JSON_DEPTH )) \
        || fatal_json 'Keycloak JSON input exceeds the maximum nesting depth of 32.'
    skip_whitespace
    (( JSON_POSITION < JSON_LENGTH )) \
        || fatal_json 'Malformed or truncated JSON value.'
    value_start=$JSON_POSITION
    character=${JSON_TEXT:JSON_POSITION:1}
    case "$character" in
        '{')
            parse_object "$depth"
            ;;
        '[')
            parse_array "$depth"
            ;;
        '"')
            parse_string
            next_node string
            NODE_STRING[NEW_NODE_ID]=$PARSED_STRING
            NODE_STRING_ESCAPED[NEW_NODE_ID]=$PARSED_STRING_ESCAPED
            PARSED_NODE_ID=$NEW_NODE_ID
            ;;
        t)
            [[ ${JSON_TEXT:JSON_POSITION:4} == true ]] \
                || fatal_json 'Malformed or truncated JSON value.'
            ((JSON_POSITION += 4))
            next_node boolean
            NODE_BOOLEAN[NEW_NODE_ID]=true
            PARSED_NODE_ID=$NEW_NODE_ID
            ;;
        f)
            [[ ${JSON_TEXT:JSON_POSITION:5} == false ]] \
                || fatal_json 'Malformed or truncated JSON value.'
            ((JSON_POSITION += 5))
            next_node boolean
            NODE_BOOLEAN[NEW_NODE_ID]=false
            PARSED_NODE_ID=$NEW_NODE_ID
            ;;
        n)
            [[ ${JSON_TEXT:JSON_POSITION:4} == null ]] \
                || fatal_json 'Malformed or truncated JSON value.'
            ((JSON_POSITION += 4))
            next_node null
            PARSED_NODE_ID=$NEW_NODE_ID
            ;;
        '-'|[0-9])
            parse_number
            ;;
        *)
            fatal_json 'Malformed or truncated JSON value.'
            ;;
    esac
    NODE_START[PARSED_NODE_ID]=$value_start
    NODE_END[PARSED_NODE_ID]=$JSON_POSITION
}

child_of() {
    local object_id=$1
    local child_name=$2
    local lookup_key
    encode_object_key "$child_name"
    lookup_key="${object_id}${KEY_SEPARATOR}${ENCODED_OBJECT_KEY}"
    CHILD_NODE_ID=0
    if [[ -v 'OBJECT_CHILD[$lookup_key]' ]]; then
        CHILD_NODE_ID=${OBJECT_CHILD[$lookup_key]}
    fi
}

has_child() {
    local object_id=$1
    local child_name=$2
    local lookup_key
    encode_object_key "$child_name"
    lookup_key="${object_id}${KEY_SEPARATOR}${ENCODED_OBJECT_KEY}"
    [[ -v 'OBJECT_CHILD[$lookup_key]' ]]
}

is_canonical_string() {
    local node_id=$1
    [[ ${NODE_TYPE[node_id]-} == string \
        && ${NODE_STRING_ESCAPED[node_id]:-0} -eq 0 ]]
}

is_exact_string() {
    local node_id=$1
    local expected_value=$2
    [[ ${NODE_TYPE[node_id]-} == string \
        && ${NODE_STRING_ESCAPED[node_id]:-0} -eq 0 \
        && ${NODE_STRING[node_id]-} == "$expected_value" ]]
}

is_nonempty_plain_string() {
    local node_id=$1
    [[ ${NODE_TYPE[node_id]-} == string \
        && ${NODE_STRING_ESCAPED[node_id]:-0} -eq 0 \
        && -n ${NODE_STRING[node_id]-} ]]
}

is_exact_boolean() {
    local node_id=$1
    local expected_value=$2
    [[ ${NODE_TYPE[node_id]-} == boolean \
        && ${NODE_BOOLEAN[node_id]-} == "$expected_value" ]]
}

validate_role_array() {
    local array_id=$1
    local expected_roles_text=$2
    local expected_count=$3
    local context=$4
    local expected_role actual_index actual_node actual_role
    local actual_count=${ARRAY_CHILD_COUNT[array_id]:-0}
    local -A expected_set=()
    local -A actual_set=()

    [[ ${NODE_TYPE[array_id]-} == array ]] \
        || fatal_json "$context must be a JSON array."
    for expected_role in $expected_roles_text; do
        expected_set["$expected_role"]=1
    done
    (( actual_count == expected_count )) \
        || fatal_json "$context does not contain the exact minimum role count."
    for ((actual_index = 1; actual_index <= actual_count; actual_index++)); do
        actual_node=${ARRAY_CHILD["${array_id}${KEY_SEPARATOR}${actual_index}"]}
        is_canonical_string "$actual_node" \
            || fatal_json "$context contains a non-canonical role value."
        actual_role=${NODE_STRING[actual_node]}
        [[ $actual_role =~ ^[A-Za-z0-9_.:-]+$ ]] \
            || fatal_json "$context contains an unsafe role value."
        [[ -v 'expected_set[$actual_role]' ]] \
            || fatal_json "$context contains an unexpected role."
        [[ ! -v 'actual_set[$actual_role]' ]] \
            || fatal_json "$context contains a duplicate role."
        actual_set["$actual_role"]=1
    done
    for expected_role in "${!expected_set[@]}"; do
        [[ -v 'actual_set[$expected_role]' ]] \
            || fatal_json "$context is missing a required role."
    done
}

validate_token() {
    local root_id=$1
    local azp_id realm_access_id realm_roles_id resource_access_id
    local resource_index resource_key resource_container_id resource_roles_id
    local expected_key resource_count

    child_of "$root_id" azp
    azp_id=$CHILD_NODE_ID
    is_exact_string "$azp_id" "$expected_client_id" \
        || fatal_json 'Token azp does not exactly identify the expected technical client.'

    child_of "$root_id" realm_access
    realm_access_id=$CHILD_NODE_ID
    [[ ${NODE_TYPE[realm_access_id]-} == object ]] \
        || fatal_json 'Token is missing a top-level realm_access object.'
    child_of "$realm_access_id" roles
    realm_roles_id=$CHILD_NODE_ID
    validate_role_array "$realm_roles_id" create-realm 1 'Token master realm roles'

    child_of "$root_id" resource_access
    resource_access_id=$CHILD_NODE_ID
    [[ ${NODE_TYPE[resource_access_id]-} == object ]] \
        || fatal_json 'Token is missing a top-level resource_access object.'
    resource_count=${OBJECT_CHILD_COUNT[resource_access_id]:-0}
    (( resource_count == MANAGED_REALM_COUNT )) \
        || fatal_json 'Token resource_access does not contain the exact managed-realm client set.'
    for ((resource_index = 1; resource_index <= resource_count; resource_index++)); do
        resource_key=${OBJECT_CHILD_KEY["${resource_access_id}${KEY_SEPARATOR}${resource_index}"]}
        [[ $resource_key =~ ^saas-[a-z0-9][a-z0-9-]*-realm$ ]] \
            || fatal_json 'Token resource_access contains an unsafe client key.'
        [[ -v 'EXPECTED_RESOURCE_KEYS[$resource_key]' ]] \
            || fatal_json 'Token resource_access contains a client outside the managed-realm allowlist.'
        child_of "$resource_access_id" "$resource_key"
        resource_container_id=$CHILD_NODE_ID
        [[ ${NODE_TYPE[resource_container_id]-} == object ]] \
            || fatal_json 'Token resource role container must be a JSON object.'
        child_of "$resource_container_id" roles
        resource_roles_id=$CHILD_NODE_ID
        validate_role_array \
            "$resource_roles_id" \
            'manage-users query-groups query-users view-users view-realm' \
            5 \
            'Token managed-realm client roles'
    done
    for expected_key in "${!EXPECTED_RESOURCE_KEYS[@]}"; do
        has_child "$resource_access_id" "$expected_key" \
            || fatal_json 'Token resource_access is missing a managed-realm client.'
    done
}

validate_client() {
    local root_id=$1
    local client_id_node attributes_id marker_node
    local managed_by_present=false
    local contract_version_present=false
    local managed_by_exact=false
    local contract_version_exact=false

    child_of "$root_id" clientId
    client_id_node=$CHILD_NODE_ID
    is_exact_string "$client_id_node" "$expected_client_id" \
        || fatal_json 'Client representation does not exactly match the expected client ID.'

    if has_child "$root_id" attributes; then
        child_of "$root_id" attributes
        attributes_id=$CHILD_NODE_ID
        if [[ ${NODE_TYPE[attributes_id]-} != object ]]; then
            printf 'unowned\n'
            return
        fi
        if has_child "$attributes_id" saas.provisioning.managed-by; then
            managed_by_present=true
            child_of "$attributes_id" saas.provisioning.managed-by
            marker_node=$CHILD_NODE_ID
            if is_exact_string "$marker_node" saas-service; then
                managed_by_exact=true
            fi
        fi
        if has_child "$attributes_id" saas.provisioning.contract-version; then
            contract_version_present=true
            child_of "$attributes_id" saas.provisioning.contract-version
            marker_node=$CHILD_NODE_ID
            if is_exact_string "$marker_node" 1; then
                contract_version_exact=true
            fi
        fi
    fi

    if [[ $managed_by_exact == true && $contract_version_exact == true ]]; then
        printf 'managed\n'
        return
    fi
    if [[ $managed_by_present == true || $contract_version_present == true ]]; then
        printf 'unowned\n'
        return
    fi

    child_of "$root_id" enabled
    local enabled_id=$CHILD_NODE_ID
    child_of "$root_id" publicClient
    local public_client_id=$CHILD_NODE_ID
    child_of "$root_id" bearerOnly
    local bearer_only_id=$CHILD_NODE_ID
    child_of "$root_id" standardFlowEnabled
    local standard_flow_id=$CHILD_NODE_ID
    child_of "$root_id" implicitFlowEnabled
    local implicit_flow_id=$CHILD_NODE_ID
    child_of "$root_id" directAccessGrantsEnabled
    local direct_grants_id=$CHILD_NODE_ID
    child_of "$root_id" serviceAccountsEnabled
    local service_accounts_id=$CHILD_NODE_ID
    child_of "$root_id" clientAuthenticatorType
    local authenticator_id=$CHILD_NODE_ID
    child_of "$root_id" protocol
    local protocol_id=$CHILD_NODE_ID

    if is_exact_boolean "$enabled_id" true \
            && is_exact_boolean "$public_client_id" false \
            && is_exact_boolean "$bearer_only_id" false \
            && is_exact_boolean "$standard_flow_id" false \
            && is_exact_boolean "$implicit_flow_id" false \
            && is_exact_boolean "$direct_grants_id" false \
            && is_exact_boolean "$service_accounts_id" true \
            && is_exact_string "$authenticator_id" client-secret \
            && is_exact_string "$protocol_id" openid-connect; then
        printf 'legacy\n'
    else
        printf 'unowned\n'
    fi
}

validate_mapper() {
    local root_id=$1
    local name_id protocol_id protocol_mapper_id config_id
    local claim_name_id=0 user_attribute_id=0 claim_value_id=0
    local emits=false managed_fingerprint=false fingerprint_output

    child_of "$root_id" name
    name_id=$CHILD_NODE_ID
    child_of "$root_id" protocol
    protocol_id=$CHILD_NODE_ID
    child_of "$root_id" protocolMapper
    protocol_mapper_id=$CHILD_NODE_ID
    child_of "$root_id" config
    config_id=$CHILD_NODE_ID
    is_canonical_string "$name_id" \
        && is_canonical_string "$protocol_id" \
        && is_canonical_string "$protocol_mapper_id" \
        && [[ ${NODE_TYPE[config_id]-} == object ]] \
        || fatal_json 'Protocol mapper representation has invalid canonical top-level fields.'

    if has_child "$config_id" claim.name; then
        child_of "$config_id" claim.name
        claim_name_id=$CHILD_NODE_ID
        is_canonical_string "$claim_name_id" \
            || fatal_json 'Protocol mapper representation has a non-canonical relevant config value.'
    fi
    if has_child "$config_id" user.attribute; then
        child_of "$config_id" user.attribute
        user_attribute_id=$CHILD_NODE_ID
        is_canonical_string "$user_attribute_id" \
            || fatal_json 'Protocol mapper representation has a non-canonical relevant config value.'
    fi
    if has_child "$config_id" claim.value; then
        child_of "$config_id" claim.value
        claim_value_id=$CHILD_NODE_ID
        is_canonical_string "$claim_value_id" \
            || fatal_json 'Protocol mapper representation has a non-canonical relevant config value.'
    fi

    if is_exact_string "$name_id" tenant_id \
            || is_exact_string "$name_id" tenant_id-mapper \
            || is_exact_string "$claim_name_id" tenant_id \
            || is_exact_string "$user_attribute_id" tenant_id; then
        emits=true
    fi

    if is_exact_string "$protocol_id" openid-connect; then
        case "$expected_client_id" in
            saas-service-api)
                if is_exact_string "$name_id" tenant_id-mapper \
                        && is_exact_string "$protocol_mapper_id" oidc-usermodel-attribute-mapper \
                        && is_exact_string "$user_attribute_id" tenant_id \
                        && is_exact_string "$claim_name_id" tenant_id; then
                    managed_fingerprint=true
                fi
                ;;
            saas-frontend-spa)
                if is_exact_string "$name_id" tenant_id \
                        && is_exact_string "$protocol_mapper_id" oidc-hardcoded-claim-mapper \
                        && is_exact_string "$claim_name_id" tenant_id \
                        && is_nonempty_plain_string "$claim_value_id"; then
                    managed_fingerprint=true
                fi
                ;;
        esac
    fi

    fingerprint_output=unknown
    if [[ $managed_fingerprint == true ]]; then
        fingerprint_output=managed
    fi
    printf 'emits=%s fingerprint=%s\n' "$emits" "$fingerprint_output"
}

validate_billing_mapper() {
    local root_id=$1
    local name_id protocol_id protocol_mapper_id consent_required_id config_id
    local config_key
    local claim_name_id=0 user_attribute_id=0 json_type_id=0
    local id_token_id=0 access_token_id=0 userinfo_token_id=0
    local multivalued_id=0 aggregate_attrs_id=0
    local relevant=false exact=false

    child_of "$root_id" name
    name_id=$CHILD_NODE_ID
    child_of "$root_id" protocol
    protocol_id=$CHILD_NODE_ID
    child_of "$root_id" protocolMapper
    protocol_mapper_id=$CHILD_NODE_ID
    child_of "$root_id" consentRequired
    consent_required_id=$CHILD_NODE_ID
    child_of "$root_id" config
    config_id=$CHILD_NODE_ID

    is_canonical_string "$name_id" \
        && is_canonical_string "$protocol_id" \
        && is_canonical_string "$protocol_mapper_id" \
        && [[ ${NODE_TYPE[config_id]-} == object ]] \
        || fatal_json 'Billing protocol mapper has invalid canonical top-level fields.'

    for config_key in claim.name user.attribute jsonType.label id.token.claim \
            access.token.claim userinfo.token.claim multivalued aggregate.attrs; do
        if has_child "$config_id" "$config_key"; then
            child_of "$config_id" "$config_key"
            is_canonical_string "$CHILD_NODE_ID" \
                || fatal_json 'Billing protocol mapper has a non-canonical relevant config value.'
            case "$config_key" in
                claim.name) claim_name_id=$CHILD_NODE_ID ;;
                user.attribute) user_attribute_id=$CHILD_NODE_ID ;;
                jsonType.label) json_type_id=$CHILD_NODE_ID ;;
                id.token.claim) id_token_id=$CHILD_NODE_ID ;;
                access.token.claim) access_token_id=$CHILD_NODE_ID ;;
                userinfo.token.claim) userinfo_token_id=$CHILD_NODE_ID ;;
                multivalued) multivalued_id=$CHILD_NODE_ID ;;
                aggregate.attrs) aggregate_attrs_id=$CHILD_NODE_ID ;;
            esac
        fi
    done

    case "$billing_mapper_kind" in
        human)
            if is_exact_string "$name_id" human-principal-id \
                    || is_exact_string "$claim_name_id" human_principal_id \
                    || is_exact_string "$user_attribute_id" human_principal_id; then
                relevant=true
            fi
            if is_exact_string "$name_id" human-principal-id \
                    && is_exact_string "$protocol_id" openid-connect \
                    && is_exact_string "$protocol_mapper_id" oidc-usermodel-attribute-mapper \
                    && is_exact_boolean "$consent_required_id" false \
                    && is_exact_string "$user_attribute_id" human_principal_id \
                    && is_exact_string "$claim_name_id" human_principal_id \
                    && is_exact_string "$json_type_id" String \
                    && is_exact_string "$id_token_id" false \
                    && is_exact_string "$access_token_id" true \
                    && is_exact_string "$userinfo_token_id" false \
                    && is_exact_string "$multivalued_id" false \
                    && is_exact_string "$aggregate_attrs_id" false; then
                exact=true
            fi
            ;;
        amr)
            if is_exact_string "$name_id" authentication-method-reference \
                    || is_exact_string "$protocol_mapper_id" oidc-amr-mapper \
                    || is_exact_string "$claim_name_id" amr; then
                relevant=true
            fi
            if is_exact_string "$name_id" authentication-method-reference \
                    && is_exact_string "$protocol_id" openid-connect \
                    && is_exact_string "$protocol_mapper_id" oidc-amr-mapper \
                    && is_exact_boolean "$consent_required_id" false \
                    && is_exact_string "$id_token_id" false \
                    && is_exact_string "$access_token_id" true; then
                exact=true
            fi
            ;;
    esac

    printf 'kind=%s relevant=%s exact=%s\n' "$billing_mapper_kind" "$relevant" "$exact"
}

validate_billing_amr_config() {
    local root_id=$1
    local alias_id config_id reference_id max_age_id
    local exact=false ownership=external

    child_of "$root_id" alias
    alias_id=$CHILD_NODE_ID
    child_of "$root_id" config
    config_id=$CHILD_NODE_ID
    is_canonical_string "$alias_id" \
        && [[ ${NODE_TYPE[config_id]-} == object ]] \
        || fatal_json 'Billing AMR authenticator config has invalid canonical top-level fields.'

    if is_exact_string "$alias_id" "$billing_amr_managed_alias"; then
        ownership=managed
    fi

    child_of "$config_id" default.reference.value
    reference_id=$CHILD_NODE_ID
    child_of "$config_id" default.reference.maxAge
    max_age_id=$CHILD_NODE_ID
    is_canonical_string "$reference_id" \
        && is_canonical_string "$max_age_id" \
        || fatal_json 'Billing AMR authenticator config has non-canonical values.'

    if (( ${OBJECT_CHILD_COUNT[config_id]:-0} == 2 )) \
            && is_exact_string "$reference_id" "$billing_amr_reference" \
            && is_exact_string "$max_age_id" 900; then
        exact=true
    fi

    printf 'reference=%s exact=%s ownership=%s\n' \
        "$billing_amr_reference" "$exact" "$ownership"
}

validate_billing_browser_flow() {
    local root_id=$1
    local browser_flow_id browser_flow

    child_of "$root_id" browserFlow
    browser_flow_id=$CHILD_NODE_ID
    is_canonical_string "$browser_flow_id" \
        || fatal_json 'Administrative realm browser flow must be a canonical string.'
    browser_flow=${NODE_STRING[browser_flow_id]}
    [[ ${#browser_flow} -le 160 && $browser_flow =~ ^[A-Za-z0-9._\ -]+$ ]] \
        || fatal_json 'Administrative realm browser flow alias is unsafe.'
    printf 'flow=%s\n' "$browser_flow"
}

validate_admin_login_required_action() {
    local root_id=$1
    local alias_id name_id provider_id enabled_id default_action_id priority_id config_id
    local priority_text enabled_start enabled_end config_index config_value_id

    (( ${OBJECT_CHILD_COUNT[root_id]:-0} == 7 )) \
        || fatal_json 'CONFIGURE_TOTP representation must contain its exact seven fields.'
    child_of "$root_id" alias
    alias_id=$CHILD_NODE_ID
    child_of "$root_id" name
    name_id=$CHILD_NODE_ID
    child_of "$root_id" providerId
    provider_id=$CHILD_NODE_ID
    child_of "$root_id" enabled
    enabled_id=$CHILD_NODE_ID
    child_of "$root_id" defaultAction
    default_action_id=$CHILD_NODE_ID
    child_of "$root_id" priority
    priority_id=$CHILD_NODE_ID
    child_of "$root_id" config
    config_id=$CHILD_NODE_ID

    is_exact_string "$alias_id" CONFIGURE_TOTP \
        && is_nonempty_plain_string "$name_id" \
        && is_exact_string "$provider_id" CONFIGURE_TOTP \
        && [[ ${NODE_TYPE[enabled_id]-} == boolean ]] \
        && is_exact_boolean "$default_action_id" false \
        && [[ ${NODE_TYPE[priority_id]-} == number ]] \
        && [[ ${NODE_TYPE[config_id]-} == object ]] \
        || fatal_json 'CONFIGURE_TOTP representation has invalid identity or state fields.'
    [[ ${#NODE_STRING[name_id]} -le 160 \
        && ${NODE_STRING[name_id]} =~ ^[A-Za-z0-9._\ /():+-]+$ ]] \
        || fatal_json 'CONFIGURE_TOTP display name is unsafe.'
    for ((config_index = 1; config_index <= ${OBJECT_CHILD_COUNT[config_id]:-0}; config_index++)); do
        # Resolve through child_of so raw config keys never become associative
        # array expressions. RequiredActionProviderRepresentation config is a
        # Map<String,String>; preserve escaped string values byte-for-byte.
        child_of "$config_id" "${OBJECT_CHILD_KEY["${config_id}${KEY_SEPARATOR}${config_index}"]}"
        config_value_id=$CHILD_NODE_ID
        [[ ${NODE_TYPE[config_value_id]-} == string ]] \
            || fatal_json 'CONFIGURE_TOTP config values must be strings.'
    done

    priority_text=${JSON_TEXT:${NODE_START[priority_id]}:$((NODE_END[priority_id] - NODE_START[priority_id]))}
    [[ $priority_text =~ ^(0|[1-9][0-9]{0,5})$ ]] \
        && (( priority_text <= 100000 )) \
        || fatal_json 'CONFIGURE_TOTP priority is invalid or oversized.'

    if [[ -z $admin_login_mfa_target_enabled ]]; then
        printf 'enabled=%s\n' "${NODE_BOOLEAN[enabled_id]}"
        return
    fi

    enabled_start=${NODE_START[enabled_id]}
    enabled_end=${NODE_END[enabled_id]}
    printf '%s%s%s' \
        "${JSON_TEXT:0:enabled_start}" \
        "$admin_login_mfa_target_enabled" \
        "${JSON_TEXT:enabled_end}"
}

validate_realm_smtp() {
    local root_id=$1
    local reset_id smtp_id auth_id user_id password_id
    local smtp_child_count

    child_of "$root_id" resetPasswordAllowed
    reset_id=$CHILD_NODE_ID
    is_exact_boolean "$reset_id" true \
        || fatal_json 'Realm password recovery must be enabled.'

    child_of "$root_id" smtpServer
    smtp_id=$CHILD_NODE_ID
    [[ ${NODE_TYPE[smtp_id]-} == object ]] \
        || fatal_json 'Realm SMTP configuration must be a top-level object.'

    assert_smtp_string "$smtp_id" host "${KEYCLOAK_REALM_SMTP_HOST:?}"
    assert_smtp_string "$smtp_id" port "${KEYCLOAK_REALM_SMTP_PORT:?}"
    assert_smtp_string "$smtp_id" from "${KEYCLOAK_REALM_SMTP_FROM:?}"
    assert_smtp_string "$smtp_id" fromDisplayName "${KEYCLOAK_REALM_SMTP_FROM_DISPLAY_NAME:?}"
    assert_smtp_string "$smtp_id" replyTo "${KEYCLOAK_REALM_SMTP_REPLY_TO:?}"
    assert_smtp_string "$smtp_id" replyToDisplayName "${KEYCLOAK_REALM_SMTP_REPLY_TO_DISPLAY_NAME:?}"
    assert_smtp_string "$smtp_id" auth "${KEYCLOAK_REALM_SMTP_AUTH:?}"
    assert_smtp_string "$smtp_id" starttls "${KEYCLOAK_REALM_SMTP_STARTTLS:?}"
    assert_smtp_string "$smtp_id" ssl "${KEYCLOAK_REALM_SMTP_SSL:?}"

    smtp_child_count=${OBJECT_CHILD_COUNT[smtp_id]:-0}
    if [[ ${KEYCLOAK_REALM_SMTP_AUTH:?} == true ]]; then
        assert_smtp_string "$smtp_id" user "${KEYCLOAK_REALM_SMTP_USER:?}"
        child_of "$smtp_id" password
        password_id=$CHILD_NODE_ID
        [[ ${NODE_TYPE[password_id]-} == string \
            && ${NODE_STRING_ESCAPED[password_id]:-0} -eq 0 \
            && ( ${NODE_STRING[password_id]-} == "${KEYCLOAK_REALM_SMTP_PASSWORD:?}" \
                || ${NODE_STRING[password_id]-} == '**********' ) ]] \
            || fatal_json 'Realm SMTP password is absent or has an unexpected opaque representation.'
        (( smtp_child_count == 11 )) \
            || fatal_json 'Authenticated realm SMTP contains unexpected or missing fields.'
    else
        if has_child "$smtp_id" user || has_child "$smtp_id" password; then
            child_of "$smtp_id" user
            user_id=$CHILD_NODE_ID
            child_of "$smtp_id" password
            password_id=$CHILD_NODE_ID
            is_exact_string "$user_id" '' && is_exact_string "$password_id" '' \
                || fatal_json 'Unauthenticated realm SMTP must not retain credentials.'
            (( smtp_child_count == 11 )) \
                || fatal_json 'Unauthenticated realm SMTP contains a partial credential state.'
        else
            (( smtp_child_count == 9 )) \
                || fatal_json 'Unauthenticated realm SMTP contains unexpected fields.'
        fi
    fi
}

assert_smtp_string() {
    local smtp_id=$1
    local field_name=$2
    local expected_value=$3
    local field_id

    child_of "$smtp_id" "$field_name"
    field_id=$CHILD_NODE_ID
    is_exact_string "$field_id" "$expected_value" \
        || fatal_json "Realm SMTP field $field_name does not match the environmental contract."
}

is_canonical_uuid() {
    local identifier_value=$1
    [[ $identifier_value =~ ^[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}$ ]]
}

validate_recovery_page() {
    local root_id=$1
    local page_count=${ARRAY_CHILD_COUNT[root_id]:-0}
    local item_index item_id identifier_node name_node
    local identifier_value name_value reserved_candidate
    local candidate_count=0 candidate_index
    local -a recovery_item_token=()
    local -a recovery_candidate_id=()
    local -a recovery_candidate_name=()

    [[ ${NODE_TYPE[root_id]-} == array ]] \
        || fatal_json 'Recovery inventory page must be a top-level JSON array.'
    (( page_count <= MAX_RECOVERY_PAGE_ITEMS )) \
        || fatal_json 'Recovery inventory page exceeds the bounded 100-item page size.'

    for ((item_index = 1; item_index <= page_count; item_index++)); do
        item_id=${ARRAY_CHILD["${root_id}${KEY_SEPARATOR}${item_index}"]}
        [[ ${NODE_TYPE[item_id]-} == object ]] \
            || fatal_json 'Recovery inventory entry must be a JSON object.'
        child_of "$item_id" id
        identifier_node=$CHILD_NODE_ID
        if [[ $recovery_page_type == users ]]; then
            child_of "$item_id" username
        else
            child_of "$item_id" clientId
        fi
        name_node=$CHILD_NODE_ID
        [[ ${NODE_TYPE[identifier_node]-} == string \
            && ${NODE_TYPE[name_node]-} == string ]] \
            || fatal_json 'Recovery inventory entry is missing top-level string identity fields.'
        identifier_value=${NODE_STRING[identifier_node]-}
        name_value=${NODE_STRING[name_node]-}
        encode_object_key "$identifier_value"
        recovery_item_token[item_index]="${NODE_STRING_ESCAPED[identifier_node]:-0}-${ENCODED_OBJECT_KEY}"
        reserved_candidate=false
        if (( ${NODE_STRING_ESCAPED[name_node]:-0} == 0 )); then
            if [[ $recovery_page_type == users \
                    && $name_value =~ ^saas-recovery-user- ]]; then
                reserved_candidate=true
                [[ $name_value =~ ^saas-recovery-user-[A-Za-z0-9_.:-]+$ ]] \
                    || fatal_json 'Reserved recovery username contains unsafe characters.'
            elif [[ $recovery_page_type == clients \
                    && $name_value =~ ^saas-recovery- ]]; then
                reserved_candidate=true
                [[ $name_value =~ ^saas-recovery-[A-Za-z0-9_.:-]+$ ]] \
                    || fatal_json 'Reserved recovery client ID contains unsafe characters.'
            fi
        fi
        if [[ $reserved_candidate == true ]]; then
            (( ${NODE_STRING_ESCAPED[identifier_node]:-0} == 0 )) \
                && is_canonical_uuid "$identifier_value" \
                || fatal_json 'Reserved recovery candidate has an invalid UUID identifier.'
            ((candidate_count += 1))
            recovery_candidate_id[candidate_count]=$identifier_value
            recovery_candidate_name[candidate_count]=$name_value
        fi
    done

    printf 'count=%d\n' "$page_count"
    for ((item_index = 1; item_index <= page_count; item_index++)); do
        printf 'item\t%s\n' "${recovery_item_token[item_index]}"
    done
    for ((candidate_index = 1; candidate_index <= candidate_count; candidate_index++)); do
        printf 'candidate\t%s\t%s\n' \
            "${recovery_candidate_id[candidate_index]}" \
            "${recovery_candidate_name[candidate_index]}"
    done
}

JSON_POSITION=0
parse_value 1
ROOT_NODE=$PARSED_NODE_ID
skip_whitespace
(( JSON_POSITION == JSON_LENGTH )) \
    || fatal_json 'Trailing data after complete JSON document is not allowed.'

if [[ $validation_mode == recovery-page ]]; then
    validate_recovery_page "$ROOT_NODE"
elif [[ ${NODE_TYPE[ROOT_NODE]-} != object ]]; then
    fatal_json 'Keycloak JSON input must be a top-level object.'
else
    case "$validation_mode" in
        token)
            validate_token "$ROOT_NODE"
            ;;
        client)
            validate_client "$ROOT_NODE"
            ;;
        mapper)
            validate_mapper "$ROOT_NODE"
            ;;
        billing-mapper)
            validate_billing_mapper "$ROOT_NODE"
            ;;
        billing-amr-config)
            validate_billing_amr_config "$ROOT_NODE"
            ;;
        billing-browser-flow)
            validate_billing_browser_flow "$ROOT_NODE"
            ;;
        admin-login-required-action)
            validate_admin_login_required_action "$ROOT_NODE"
            ;;
        realm-smtp)
            validate_realm_smtp "$ROOT_NODE"
            ;;
        *)
            fatal_json 'Unsupported structural validation mode.'
            ;;
    esac
fi
