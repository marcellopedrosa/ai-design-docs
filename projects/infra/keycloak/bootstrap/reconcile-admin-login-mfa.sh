#!/bin/sh

# Keeps administrative login MFA present while toggling its execution state.
# OFF is accepted in each governed environment only through an explicit flag.
# The script receives an authenticated kcadm session and never handles credentials.
set -eu
umask 077

KCADM_BIN="${KCADM_BIN:-/opt/keycloak/bin/kcadm.sh}"
RUNTIME_JSON_VALIDATOR="${RUNTIME_JSON_VALIDATOR:-/opt/keycloak/bootstrap/validate-keycloak-runtime-json.sh}"
ADMIN_REALM=saas-admin
MAX_FLOW_EXECUTIONS=100
MAX_FLOW_DEPTH=32
RUNTIME_ENVIRONMENT="${KEYCLOAK_RUNTIME_ENVIRONMENT:-production}"

usage() {
    echo "Usage: $0 verify|reconcile KCADM_CONFIG" >&2
    exit 2
}

fail() {
    echo "ERROR: $*" >&2
    exit 1
}

[ "${KEYCLOAK_ADMIN_LOGIN_MFA_ENABLED+x}" = x ] \
    || fail "KEYCLOAK_ADMIN_LOGIN_MFA_ENABLED is required."
MFA_ENABLED="$KEYCLOAK_ADMIN_LOGIN_MFA_ENABLED"

[ "$#" -eq 2 ] || usage
MODE="$1"
KCADM_CONFIG="$2"
case "$MODE" in
    verify|reconcile) ;;
    *) usage ;;
esac
case "$MFA_ENABLED" in
    true|false) ;;
    *) fail "KEYCLOAK_ADMIN_LOGIN_MFA_ENABLED must be true or false." ;;
esac
case "$RUNTIME_ENVIRONMENT" in
    dev|hml|production) ;;
    *) fail "KEYCLOAK_RUNTIME_ENVIRONMENT must be dev, hml or production." ;;
esac

[ -f "$KCADM_CONFIG" ] && [ -r "$KCADM_CONFIG" ] \
    || fail "The authenticated kcadm session file is unavailable."
[ -x "$KCADM_BIN" ] \
    || fail "The Keycloak administration client is unavailable."
[ -f "$RUNTIME_JSON_VALIDATOR" ] && [ -r "$RUNTIME_JSON_VALIDATOR" ] \
    || fail "The structural Keycloak runtime JSON validator is unavailable."

WORK_DIR="$(mktemp -d /tmp/saas-admin-login-mfa.XXXXXX)"
REALM_FILE="$WORK_DIR/realm.json"
EXECUTIONS_FILE="$WORK_DIR/executions.csv"
SEEN_EXECUTION_IDS_FILE="$WORK_DIR/execution-ids.txt"
REQUIRED_ACTION_FILE="$WORK_DIR/required-action.json"
REQUIRED_ACTION_PAYLOAD_FILE="$WORK_DIR/required-action-payload.json"

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
    printf '%s\n' "$1" | LC_ALL=C grep -Eq '^[0-9A-Fa-f-]+$' \
        || fail "$2"
}

read_browser_flow() {
    if ! kcadm get "realms/$ADMIN_REALM" \
            --fields browserFlow > "$REALM_FILE"; then
        fail "Could not inspect the administrative realm browser flow."
    fi
    if ! browser_flow_result="$(/bin/bash "$RUNTIME_JSON_VALIDATOR" \
            billing-browser-flow "$REALM_FILE")"; then
        fail "Could not classify the administrative realm browser flow."
    fi
    case "$browser_flow_result" in
        flow=*) BROWSER_FLOW=${browser_flow_result#flow=} ;;
        *) fail "The browser-flow classifier returned an unexpected result." ;;
    esac
    [ -n "$BROWSER_FLOW" ] \
        || fail "The administrative realm browser flow is empty."
}

inventory_managed_2fa_topology() {
    if ! kcadm get "authentication/flows/$BROWSER_FLOW/executions" \
            -r "$ADMIN_REALM" \
            --fields id,providerId,requirement,priority,authenticationConfig,authenticationFlow,flowId,level,index \
            --format csv \
            --noquotes > "$EXECUTIONS_FILE"; then
        fail "Could not inspect the administrative browser-flow executions."
    fi

    : > "$SEEN_EXECUTION_IDS_FILE"
    OTP_COUNT=0
    OTP_EXECUTION_ID=""
    OTP_REQUIREMENT=""
    OTP_PRIORITY=""
    OTP_LEVEL=""
    EXECUTION_COUNT=0
    while IFS=, read -r execution_id provider_id requirement priority \
            authentication_config authentication_flow flow_id level index extra_field \
            || [ -n "$execution_id$provider_id$requirement$priority$authentication_config$authentication_flow$flow_id$level$index$extra_field" ]; do
        execution_id="$(printf '%s' "$execution_id" | tr -d '\r')"
        provider_id="$(printf '%s' "$provider_id" | tr -d '\r')"
        requirement="$(printf '%s' "$requirement" | tr -d '\r')"
        priority="$(printf '%s' "$priority" | tr -d '\r')"
        authentication_config="$(printf '%s' "$authentication_config" | tr -d '\r')"
        authentication_flow="$(printf '%s' "$authentication_flow" | tr -d '\r')"
        flow_id="$(printf '%s' "$flow_id" | tr -d '\r')"
        level="$(printf '%s' "$level" | tr -d '\r')"
        index="$(printf '%s' "$index" | tr -d '\r')"
        extra_field="$(printf '%s' "$extra_field" | tr -d '\r')"
        [ -n "$execution_id$provider_id$requirement$priority$authentication_config$authentication_flow$flow_id$level$index$extra_field" ] \
            || continue
        EXECUTION_COUNT=$((EXECUTION_COUNT + 1))
        [ "$EXECUTION_COUNT" -le "$MAX_FLOW_EXECUTIONS" ] && [ -z "$extra_field" ] \
            || fail "The administrative browser-flow inventory is oversized or ambiguous."
        require_uuid "$execution_id" \
            "The administrative browser flow returned an invalid execution identifier."
        if grep -Fqx -- "$execution_id" "$SEEN_EXECUTION_IDS_FILE"; then
            fail "The administrative browser flow returned a duplicate execution identifier."
        fi
        printf '%s\n' "$execution_id" >> "$SEEN_EXECUTION_IDS_FILE"
        case "$requirement" in
            ALTERNATIVE|CONDITIONAL|DISABLED|REQUIRED) ;;
            *) fail "The administrative browser flow returned an invalid execution requirement." ;;
        esac
        case "$priority" in
            ""|*[!0-9]*) fail "The administrative browser flow returned an invalid execution priority." ;;
        esac
        [ "$priority" -le 100000 ] \
            || fail "The administrative browser flow returned an oversized execution priority."
        case "$level" in
            ""|*[!0-9]*) fail "The administrative browser flow returned an invalid execution level." ;;
        esac
        [ "$level" -le "$MAX_FLOW_DEPTH" ] \
            || fail "The administrative browser flow returned an oversized execution level."
        case "$index" in
            ""|*[!0-9]*) fail "The administrative browser flow returned an invalid execution index." ;;
        esac
        [ "$index" -le "$MAX_FLOW_EXECUTIONS" ] \
            || fail "The administrative browser flow returned an oversized execution index."
        if [ -n "$authentication_config" ]; then
            require_uuid "$authentication_config" \
                "The administrative browser flow returned an invalid authenticator-config identifier."
        fi
        if [ -n "$provider_id" ]; then
            printf '%s\n' "$provider_id" | LC_ALL=C grep -Eq '^[A-Za-z0-9_.:-]+$' \
                || fail "The administrative browser flow returned an unsafe provider identifier."
        fi
        case "$authentication_flow" in
            true)
                require_uuid "$flow_id" \
                    "The administrative browser flow returned an invalid child-flow identifier."
                ;;
            ""|false)
                [ -z "$flow_id" ] \
                    || fail "A non-flow authentication execution returned a child-flow identifier."
                ;;
            *)
                fail "The administrative browser flow returned an invalid authentication-flow marker."
                ;;
        esac
        if [ "$provider_id" = auth-otp-form ]; then
            [ "$authentication_flow" != true ] \
                || fail "The administrative OTP execution cannot also be a child flow."
            case "$requirement" in
                ALTERNATIVE|DISABLED) ;;
                *) fail "The administrative OTP execution requirement is outside the managed toggle states." ;;
            esac
            OTP_COUNT=$((OTP_COUNT + 1))
            OTP_EXECUTION_ID="$execution_id"
            OTP_REQUIREMENT="$requirement"
            OTP_PRIORITY="$priority"
            OTP_LEVEL="$level"
        fi
    done < "$EXECUTIONS_FILE"

    [ "$OTP_COUNT" -eq 1 ] \
        || fail "Expected exactly one OTP execution in the active administrative browser flow."
    [ "$OTP_LEVEL" -gt 0 ] \
        || fail "The administrative OTP execution has no direct parent flow."

    OTP_PARENT_LEVEL=$((OTP_LEVEL - 1))
    OTP_PARENT_EXECUTION_ID=""
    OTP_PARENT_FLOW_ID=""
    OTP_PARENT_REQUIREMENT=""
    OTP_PARENT_PRIORITY=""
    while IFS=, read -r execution_id provider_id requirement priority \
            authentication_config authentication_flow flow_id level index extra_field \
            || [ -n "$execution_id$provider_id$requirement$priority$authentication_config$authentication_flow$flow_id$level$index$extra_field" ]; do
        execution_id="$(printf '%s' "$execution_id" | tr -d '\r')"
        requirement="$(printf '%s' "$requirement" | tr -d '\r')"
        priority="$(printf '%s' "$priority" | tr -d '\r')"
        authentication_flow="$(printf '%s' "$authentication_flow" | tr -d '\r')"
        flow_id="$(printf '%s' "$flow_id" | tr -d '\r')"
        level="$(printf '%s' "$level" | tr -d '\r')"

        if [ "$execution_id" = "$OTP_EXECUTION_ID" ]; then
            break
        fi
        if [ "$level" -le "$OTP_PARENT_LEVEL" ]; then
            OTP_PARENT_EXECUTION_ID=""
            OTP_PARENT_FLOW_ID=""
            OTP_PARENT_REQUIREMENT=""
            OTP_PARENT_PRIORITY=""
            if [ "$authentication_flow" = true ] \
                    && [ "$level" -eq "$OTP_PARENT_LEVEL" ]; then
                OTP_PARENT_EXECUTION_ID="$execution_id"
                OTP_PARENT_FLOW_ID="$flow_id"
                OTP_PARENT_REQUIREMENT="$requirement"
                OTP_PARENT_PRIORITY="$priority"
            fi
        fi
    done < "$EXECUTIONS_FILE"

    [ -n "$OTP_PARENT_EXECUTION_ID" ] \
        || fail "Could not identify the direct parent flow of the administrative OTP execution."
    case "$OTP_PARENT_REQUIREMENT" in
        CONDITIONAL|DISABLED) ;;
        *) fail "The direct OTP parent requirement is outside the managed toggle states." ;;
    esac

    CONDITION_COUNT=0
    INSIDE_OTP_PARENT=false
    while IFS=, read -r execution_id provider_id requirement priority \
            authentication_config authentication_flow flow_id level index extra_field \
            || [ -n "$execution_id$provider_id$requirement$priority$authentication_config$authentication_flow$flow_id$level$index$extra_field" ]; do
        execution_id="$(printf '%s' "$execution_id" | tr -d '\r')"
        provider_id="$(printf '%s' "$provider_id" | tr -d '\r')"
        requirement="$(printf '%s' "$requirement" | tr -d '\r')"
        authentication_flow="$(printf '%s' "$authentication_flow" | tr -d '\r')"
        level="$(printf '%s' "$level" | tr -d '\r')"

        if [ "$execution_id" = "$OTP_PARENT_EXECUTION_ID" ]; then
            INSIDE_OTP_PARENT=true
            continue
        fi
        [ "$INSIDE_OTP_PARENT" = true ] || continue
        if [ "$level" -le "$OTP_PARENT_LEVEL" ]; then
            break
        fi
        if [ "$level" -eq "$OTP_LEVEL" ] \
                && [ "$provider_id" = conditional-user-configured ]; then
            [ "$authentication_flow" != true ] && [ "$requirement" = REQUIRED ] \
                || fail "The managed user-configured condition has an invalid execution state."
            CONDITION_COUNT=$((CONDITION_COUNT + 1))
        fi
    done < "$EXECUTIONS_FILE"

    [ "$CONDITION_COUNT" -eq 1 ] \
        || fail "Expected exactly one direct user-configured condition in the administrative OTP parent flow."
}

inventory_configure_totp_action() {
    if ! kcadm get "authentication/required-actions/CONFIGURE_TOTP" \
            -r "$ADMIN_REALM" \
            > "$REQUIRED_ACTION_FILE"; then
        fail "Could not inspect the CONFIGURE_TOTP required-action provider."
    fi
    if ! action_result="$(/bin/bash "$RUNTIME_JSON_VALIDATOR" \
            admin-login-required-action "$REQUIRED_ACTION_FILE")"; then
        fail "Could not classify the CONFIGURE_TOTP required-action provider."
    fi
    case "$action_result" in
        enabled=true) CONFIGURE_TOTP_ENABLED=true ;;
        enabled=false) CONFIGURE_TOTP_ENABLED=false ;;
        *) fail "The CONFIGURE_TOTP classifier returned an unexpected result." ;;
    esac
}

update_configure_totp_action() {
    target_enabled="$1"
    if ! /bin/bash "$RUNTIME_JSON_VALIDATOR" \
            admin-login-required-action \
            "$REQUIRED_ACTION_FILE" \
            "$target_enabled" > "$REQUIRED_ACTION_PAYLOAD_FILE"; then
        fail "Could not build a preserving CONFIGURE_TOTP update payload."
    fi
    kcadm update "authentication/required-actions/CONFIGURE_TOTP" \
        -r "$ADMIN_REALM" --no-merge \
        -f "$REQUIRED_ACTION_PAYLOAD_FILE" >/dev/null \
        || fail "Could not update the CONFIGURE_TOTP required-action provider."
}

if [ "$MFA_ENABLED" = true ]; then
    EXPECTED_PARENT_REQUIREMENT=CONDITIONAL
    EXPECTED_OTP_REQUIREMENT=ALTERNATIVE
    EXPECTED_ACTION_ENABLED=true
else
    EXPECTED_PARENT_REQUIREMENT=DISABLED
    EXPECTED_OTP_REQUIREMENT=ALTERNATIVE
    EXPECTED_ACTION_ENABLED=false
fi

read_browser_flow
inventory_managed_2fa_topology
inventory_configure_totp_action

if [ "$MODE" = verify ]; then
    [ "$OTP_PARENT_REQUIREMENT" = "$EXPECTED_PARENT_REQUIREMENT" ] \
        && [ "$OTP_REQUIREMENT" = "$EXPECTED_OTP_REQUIREMENT" ] \
        && [ "$CONFIGURE_TOTP_ENABLED" = "$EXPECTED_ACTION_ENABLED" ] \
        || fail "Administrative login MFA state requires controlled reconciliation."
    echo "Administrative login MFA state is valid."
    exit 0
fi

# OFF disables the whole conditional branch first, then repairs the legacy leaf
# and enrollment state. ON also quiesces an already active parent before repairing
# either child state, then enables enrollment/leaf and activates the parent last.
# A partial failure can therefore never leave an active empty branch.
DISABLE_PARENT_BEFORE_REPAIR=false
if [ "$OTP_PARENT_REQUIREMENT" = CONDITIONAL ]; then
    if [ "$MFA_ENABLED" = false ] \
            || [ "$OTP_REQUIREMENT" != "$EXPECTED_OTP_REQUIREMENT" ] \
            || [ "$CONFIGURE_TOTP_ENABLED" != "$EXPECTED_ACTION_ENABLED" ]; then
        DISABLE_PARENT_BEFORE_REPAIR=true
    fi
fi

if [ "$DISABLE_PARENT_BEFORE_REPAIR" = true ]; then
    kcadm update "authentication/flows/$BROWSER_FLOW/executions" \
        -r "$ADMIN_REALM" --no-merge \
        -s "id=$OTP_PARENT_EXECUTION_ID" \
        -s "requirement=DISABLED" \
        -s "priority=$OTP_PARENT_PRIORITY" >/dev/null \
        || fail "Could not quiesce the administrative 2FA parent flow before repair."
    OTP_PARENT_REQUIREMENT=DISABLED
fi

if [ "$MFA_ENABLED" = true ] \
        && [ "$CONFIGURE_TOTP_ENABLED" != "$EXPECTED_ACTION_ENABLED" ]; then
    update_configure_totp_action true
fi

if [ "$OTP_REQUIREMENT" != "$EXPECTED_OTP_REQUIREMENT" ]; then
    kcadm update "authentication/flows/$BROWSER_FLOW/executions" \
        -r "$ADMIN_REALM" --no-merge \
        -s "id=$OTP_EXECUTION_ID" \
        -s "requirement=$EXPECTED_OTP_REQUIREMENT" \
        -s "priority=$OTP_PRIORITY" >/dev/null \
        || fail "Could not restore the canonical administrative OTP execution state."
fi

if [ "$MFA_ENABLED" = false ] \
        && [ "$CONFIGURE_TOTP_ENABLED" != "$EXPECTED_ACTION_ENABLED" ]; then
    update_configure_totp_action false
fi

if [ "$MFA_ENABLED" = true ] \
        && [ "$OTP_PARENT_REQUIREMENT" != "$EXPECTED_PARENT_REQUIREMENT" ]; then
    kcadm update "authentication/flows/$BROWSER_FLOW/executions" \
        -r "$ADMIN_REALM" --no-merge \
        -s "id=$OTP_PARENT_EXECUTION_ID" \
        -s "requirement=$EXPECTED_PARENT_REQUIREMENT" \
        -s "priority=$OTP_PARENT_PRIORITY" >/dev/null \
        || fail "Could not reactivate the administrative 2FA parent flow."
fi

inventory_managed_2fa_topology
inventory_configure_totp_action
[ "$OTP_PARENT_REQUIREMENT" = "$EXPECTED_PARENT_REQUIREMENT" ] \
    && [ "$OTP_REQUIREMENT" = "$EXPECTED_OTP_REQUIREMENT" ] \
    && [ "$CONFIGURE_TOTP_ENABLED" = "$EXPECTED_ACTION_ENABLED" ] \
    || fail "Administrative login MFA failed post-reconciliation verification."

echo "Administrative login MFA state was reconciled successfully."
