#!/bin/sh

# Reconciles the Authenticator Method Reference attached to the two browser
# authenticators used by administrative Billing. It receives an already
# authenticated kcadm session file; this script never handles a password, token
# or OTP directly.
set -eu
umask 077

KCADM_BIN="${KCADM_BIN:-/opt/keycloak/bin/kcadm.sh}"
RUNTIME_JSON_VALIDATOR="${RUNTIME_JSON_VALIDATOR:-/opt/keycloak/bootstrap/validate-keycloak-runtime-json.sh}"
ADMIN_REALM=saas-admin
EXPECTED_MAX_AGE=900
MAX_FLOW_EXECUTIONS=100

usage() {
    echo "Usage: $0 verify|reconcile KCADM_CONFIG" >&2
    exit 2
}

fail() {
    echo "ERROR: $*" >&2
    exit 1
}

[ "$#" -eq 2 ] || usage
MODE="$1"
KCADM_CONFIG="$2"
case "$MODE" in
    verify|reconcile) ;;
    *) usage ;;
esac

[ -f "$KCADM_CONFIG" ] && [ -r "$KCADM_CONFIG" ] \
    || fail "The authenticated kcadm session file is unavailable."
[ -x "$KCADM_BIN" ] \
    || fail "The Keycloak administration client is unavailable."
[ -f "$RUNTIME_JSON_VALIDATOR" ] && [ -r "$RUNTIME_JSON_VALIDATOR" ] \
    || fail "The structural Keycloak runtime JSON validator is unavailable."

WORK_DIR="$(mktemp -d /tmp/saas-billing-mfa-amr.XXXXXX)"
REALM_FILE="$WORK_DIR/realm.json"
EXECUTIONS_FILE="$WORK_DIR/executions.csv"
CONFIG_FILE="$WORK_DIR/config.json"
PAYLOAD_FILE="$WORK_DIR/payload.json"

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

require_uuid() {
    case "$1" in
        ????????-????-????-????-????????????) ;;
        *) fail "$2" ;;
    esac
    if ! printf '%s\n' "$1" | LC_ALL=C grep -Eq '^[0-9A-Fa-f-]+$'; then
        fail "$2"
    fi
}

read_browser_flow() {
    if ! kcadm get "realms/$ADMIN_REALM" \
            --fields browserFlow > "$REALM_FILE"; then
        fail "Could not inspect the administrative realm browser flow."
    fi
    if ! BROWSER_FLOW_RESULT="$(/bin/bash "$RUNTIME_JSON_VALIDATOR" \
            billing-browser-flow "$REALM_FILE")"; then
        fail "Could not classify the administrative realm browser flow."
    fi
    case "$BROWSER_FLOW_RESULT" in
        flow=*) BROWSER_FLOW=${BROWSER_FLOW_RESULT#flow=} ;;
        *) fail "The browser-flow classifier returned an unexpected result." ;;
    esac
    [ -n "$BROWSER_FLOW" ] \
        || fail "The administrative realm browser flow is empty."
}

inventory_target_executions() {
    if ! kcadm get "authentication/flows/$BROWSER_FLOW/executions" \
            -r "$ADMIN_REALM" \
            --fields id,providerId,authenticationConfig \
            --format csv \
            --noquotes > "$EXECUTIONS_FILE"; then
        fail "Could not inspect the administrative browser-flow executions."
    fi

    PWD_COUNT=0
    PWD_EXECUTION_ID=""
    PWD_CONFIG_ID=""
    OTP_COUNT=0
    OTP_EXECUTION_ID=""
    OTP_CONFIG_ID=""
    EXECUTION_COUNT=0

    while IFS=, read -r execution_id provider_id authentication_config extra_field \
            || [ -n "$execution_id$provider_id$authentication_config$extra_field" ]; do
        execution_id="$(printf '%s' "$execution_id" | tr -d '\r')"
        provider_id="$(printf '%s' "$provider_id" | tr -d '\r')"
        authentication_config="$(printf '%s' "$authentication_config" | tr -d '\r')"
        [ -n "$execution_id$provider_id$authentication_config$extra_field" ] || continue
        EXECUTION_COUNT=$((EXECUTION_COUNT + 1))
        [ "$EXECUTION_COUNT" -le "$MAX_FLOW_EXECUTIONS" ] \
            && [ -z "$extra_field" ] \
            || fail "The administrative browser-flow inventory is oversized or ambiguous."
        require_uuid "$execution_id" \
            "The administrative browser flow returned an invalid execution identifier."
        if [ -n "$authentication_config" ]; then
            require_uuid "$authentication_config" \
                "The administrative browser flow returned an invalid authenticator-config identifier."
        fi
        case "$provider_id" in
            auth-username-password-form)
                PWD_COUNT=$((PWD_COUNT + 1))
                PWD_EXECUTION_ID="$execution_id"
                PWD_CONFIG_ID="$authentication_config"
                ;;
            auth-otp-form)
                OTP_COUNT=$((OTP_COUNT + 1))
                OTP_EXECUTION_ID="$execution_id"
                OTP_CONFIG_ID="$authentication_config"
                ;;
        esac
    done < "$EXECUTIONS_FILE"

    [ "$PWD_COUNT" -eq 1 ] \
        || fail "Expected exactly one username/password execution in the active administrative browser flow."
    [ "$OTP_COUNT" -eq 1 ] \
        || fail "Expected exactly one OTP execution in the active administrative browser flow."
}

classify_target() {
    TARGET_CONFIG_ID="$1"
    TARGET_REFERENCE="$2"
    TARGET_MANAGED_ALIAS="$3"
    TARGET_ACTION=none

    if [ -z "$TARGET_CONFIG_ID" ]; then
        TARGET_ACTION=create
        return
    fi

    if ! kcadm get "authentication/config/$TARGET_CONFIG_ID" \
            -r "$ADMIN_REALM" > "$CONFIG_FILE"; then
        fail "Could not inspect an administrative authenticator configuration."
    fi
    if ! TARGET_CLASSIFICATION="$(/bin/bash "$RUNTIME_JSON_VALIDATOR" \
            billing-amr-config "$CONFIG_FILE" \
            "$TARGET_REFERENCE" "$TARGET_MANAGED_ALIAS")"; then
        fail "Could not classify an administrative AMR authenticator configuration."
    fi
    case "$TARGET_CLASSIFICATION" in
        "reference=$TARGET_REFERENCE exact=true ownership=managed"|\
        "reference=$TARGET_REFERENCE exact=true ownership=external")
            TARGET_ACTION=none
            ;;
        "reference=$TARGET_REFERENCE exact=false ownership=managed")
            TARGET_ACTION=update
            ;;
        "reference=$TARGET_REFERENCE exact=false ownership=external")
            fail "A divergent external authenticator config is attached to a Billing MFA execution; no config was changed."
            ;;
        *)
            fail "The AMR authenticator classifier returned an unexpected result."
            ;;
    esac
}

write_payload() {
    payload_alias="$1"
    payload_reference="$2"
    printf '%s\n' \
        "{\"alias\":\"$payload_alias\",\"config\":{\"default.reference.value\":\"$payload_reference\",\"default.reference.maxAge\":\"$EXPECTED_MAX_AGE\"}}" \
        > "$PAYLOAD_FILE"
    chmod 600 "$PAYLOAD_FILE"
}

apply_target_action() {
    target_action="$1"
    target_execution_id="$2"
    target_config_id="$3"
    target_alias="$4"
    target_reference="$5"

    case "$target_action" in
        none)
            return
            ;;
        create)
            write_payload "$target_alias" "$target_reference"
            if ! kcadm create "authentication/executions/$target_execution_id/config" \
                    -r "$ADMIN_REALM" -f "$PAYLOAD_FILE" >/dev/null; then
                fail "Could not create a managed Billing AMR authenticator config."
            fi
            ;;
        update)
            write_payload "$target_alias" "$target_reference"
            if ! kcadm update "authentication/config/$target_config_id" \
                    -r "$ADMIN_REALM" -f "$PAYLOAD_FILE" >/dev/null; then
                fail "Could not update a managed Billing AMR authenticator config."
            fi
            ;;
        *)
            fail "Unknown Billing AMR reconciliation action."
            ;;
    esac
}

read_browser_flow
inventory_target_executions

# Preflight both targets before the first mutation. A foreign divergent config
# therefore cannot leave the contract half-reconciled.
classify_target "$PWD_CONFIG_ID" pwd saas-billing-amr-pwd-v1
PWD_ACTION="$TARGET_ACTION"
classify_target "$OTP_CONFIG_ID" otp saas-billing-amr-otp-v1
OTP_ACTION="$TARGET_ACTION"

if [ "$MODE" = verify ]; then
    [ "$PWD_ACTION" = none ] && [ "$OTP_ACTION" = none ] \
        || fail "Billing MFA AMR execution references require controlled reconciliation."
    echo "Billing MFA AMR execution references are valid."
    exit 0
fi

apply_target_action "$PWD_ACTION" "$PWD_EXECUTION_ID" "$PWD_CONFIG_ID" \
    saas-billing-amr-pwd-v1 pwd
apply_target_action "$OTP_ACTION" "$OTP_EXECUTION_ID" "$OTP_CONFIG_ID" \
    saas-billing-amr-otp-v1 otp

# Re-read server state and demand an exact postcondition. No local action plan is
# accepted as proof of a successful Keycloak mutation.
inventory_target_executions
classify_target "$PWD_CONFIG_ID" pwd saas-billing-amr-pwd-v1
[ "$TARGET_ACTION" = none ] \
    || fail "Username/password AMR config failed post-reconciliation verification."
classify_target "$OTP_CONFIG_ID" otp saas-billing-amr-otp-v1
[ "$TARGET_ACTION" = none ] \
    || fail "OTP AMR config failed post-reconciliation verification."

echo "Billing MFA AMR execution references were reconciled successfully."
