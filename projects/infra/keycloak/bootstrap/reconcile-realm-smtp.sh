#!/bin/sh

# Verifies the per-realm password-recovery transport on normal startup and
# reconciles it only while the reviewed bootstrap/recovery identity is active.
set -eu
umask 077

KCADM_BIN="${KCADM_BIN:-/opt/keycloak/bin/kcadm.sh}"
RUNTIME_JSON_VALIDATOR="${RUNTIME_JSON_VALIDATOR:-/opt/keycloak/bootstrap/validate-keycloak-runtime-json.sh}"
RUNTIME_ENVIRONMENT="${KEYCLOAK_RUNTIME_ENVIRONMENT:-production}"
MANAGED_REALMS="${KEYCLOAK_EXISTING_MANAGED_REALMS:-}"

usage() {
    echo "Usage: $0 preflight|verify|reconcile KCADM_CONFIG" >&2
    exit 2
}

fail() {
    echo "ERROR: $*" >&2
    exit 1
}

require_value() {
    variable_name="$1"
    eval "variable_value=\${$variable_name:-}"
    [ -n "$variable_value" ] || fail "$variable_name is required for Keycloak realm SMTP."
}

safe_value() {
    value="$1"
    expression="$2"
    label="$3"
    printf '%s\n' "$value" | LC_ALL=C grep -Eq "$expression" \
        || fail "$label contains unsupported characters."
}

[ "$#" -eq 2 ] || usage
MODE="$1"
KCADM_CONFIG="$2"
case "$MODE" in
    preflight|verify|reconcile) ;;
    *) usage ;;
esac

for variable_name in \
        KEYCLOAK_REALM_SMTP_MODE \
        KEYCLOAK_REALM_SMTP_HOST \
        KEYCLOAK_REALM_SMTP_PORT \
        KEYCLOAK_REALM_SMTP_FROM \
        KEYCLOAK_REALM_SMTP_FROM_DISPLAY_NAME \
        KEYCLOAK_REALM_SMTP_REPLY_TO \
        KEYCLOAK_REALM_SMTP_REPLY_TO_DISPLAY_NAME \
        KEYCLOAK_REALM_SMTP_AUTH \
        KEYCLOAK_REALM_SMTP_STARTTLS \
        KEYCLOAK_REALM_SMTP_SSL; do
    require_value "$variable_name"
done

SMTP_MODE="$KEYCLOAK_REALM_SMTP_MODE"
SMTP_HOST="$KEYCLOAK_REALM_SMTP_HOST"
SMTP_PORT="$KEYCLOAK_REALM_SMTP_PORT"
SMTP_FROM="$KEYCLOAK_REALM_SMTP_FROM"
SMTP_FROM_DISPLAY_NAME="$KEYCLOAK_REALM_SMTP_FROM_DISPLAY_NAME"
SMTP_REPLY_TO="$KEYCLOAK_REALM_SMTP_REPLY_TO"
SMTP_REPLY_TO_DISPLAY_NAME="$KEYCLOAK_REALM_SMTP_REPLY_TO_DISPLAY_NAME"
SMTP_AUTH="$KEYCLOAK_REALM_SMTP_AUTH"
SMTP_STARTTLS="$KEYCLOAK_REALM_SMTP_STARTTLS"
SMTP_SSL="$KEYCLOAK_REALM_SMTP_SSL"
SMTP_USER="${KEYCLOAK_REALM_SMTP_USER:-}"
SMTP_PASSWORD="${KEYCLOAK_REALM_SMTP_PASSWORD:-}"

case "$RUNTIME_ENVIRONMENT:$SMTP_MODE" in
    dev:dev|hml:hml|production:prd) ;;
    *) fail "Keycloak runtime environment and realm SMTP mode do not match." ;;
esac
case "$SMTP_AUTH:$SMTP_STARTTLS:$SMTP_SSL" in
    false:false:false|true:true:false|true:false:true) ;;
    *) fail "Keycloak realm SMTP authentication/TLS flags are inconsistent." ;;
esac
safe_value "$SMTP_HOST" '^[A-Za-z0-9][A-Za-z0-9.-]{0,252}[A-Za-z0-9]$' \
    "Keycloak realm SMTP host"
safe_value "$SMTP_PORT" '^[1-9][0-9]{0,4}$' "Keycloak realm SMTP port"
[ "$SMTP_PORT" -ge 1 ] && [ "$SMTP_PORT" -le 65535 ] \
    || fail "Keycloak realm SMTP port is outside the supported range."
safe_value "$SMTP_FROM" '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,63}$' \
    "Keycloak realm SMTP from address"
safe_value "$SMTP_REPLY_TO" '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,63}$' \
    "Keycloak realm SMTP reply-to address"
safe_value "$SMTP_FROM_DISPLAY_NAME" '^[A-Za-z0-9 ._()@+-]{1,160}$' \
    "Keycloak realm SMTP from display name"
safe_value "$SMTP_REPLY_TO_DISPLAY_NAME" '^[A-Za-z0-9 ._()@+-]{1,160}$' \
    "Keycloak realm SMTP reply-to display name"

case "$SMTP_MODE" in
    dev)
        [ "$SMTP_HOST" = mailpit ] && [ "$SMTP_PORT" = 1025 ] \
            && [ "$SMTP_AUTH:$SMTP_STARTTLS:$SMTP_SSL" = false:false:false ] \
            && [ -z "$SMTP_USER$SMTP_PASSWORD" ] \
            || fail "DEV realm SMTP must use internal Mailpit without credentials or TLS."
        ;;
    hml|prd)
        case "$(printf '%s' "$SMTP_HOST" | tr '[:upper:]' '[:lower:]')" in
            mailpit|localhost|127.0.0.1|*.local)
                fail "HML/production realm SMTP must use an external provider."
                ;;
        esac
        [ "$SMTP_AUTH" = true ] && [ "$SMTP_STARTTLS" != "$SMTP_SSL" ] \
            || fail "HML/production realm SMTP requires authentication and exactly one TLS mode."
        safe_value "$SMTP_USER" '^[A-Za-z0-9._@+:/=-]{1,256}$' \
            "Keycloak realm SMTP user"
        [ "${#SMTP_PASSWORD}" -ge 16 ] && [ "${#SMTP_PASSWORD}" -le 256 ] \
            || fail "Keycloak realm SMTP password must contain 16-256 characters."
        safe_value "$SMTP_PASSWORD" '^[A-Za-z0-9._~:/+=-]+$' \
            "Keycloak realm SMTP password"
        ;;
    *) fail "KEYCLOAK_REALM_SMTP_MODE must be dev, hml or prd." ;;
esac

if [ "$MODE" = preflight ]; then
    echo "Keycloak realm SMTP preflight passed."
    exit 0
fi

printf '%s\n' "$MANAGED_REALMS" \
    | grep -Eq '^saas-[a-z0-9][a-z0-9-]*(,saas-[a-z0-9][a-z0-9-]*)*$' \
    || fail "KEYCLOAK_EXISTING_MANAGED_REALMS is invalid."
[ -f "$KCADM_CONFIG" ] && [ -r "$KCADM_CONFIG" ] \
    || fail "The authenticated kcadm session file is unavailable."
[ -x "$KCADM_BIN" ] || fail "The Keycloak administration client is unavailable."
[ -f "$RUNTIME_JSON_VALIDATOR" ] && [ -r "$RUNTIME_JSON_VALIDATOR" ] \
    || fail "The structural Keycloak runtime JSON validator is unavailable."

WORK_DIR="$(mktemp -d /tmp/saas-realm-smtp.XXXXXX)"
REALM_FILE="$WORK_DIR/realm.json"
PAYLOAD_FILE="$WORK_DIR/payload.json"
REALMS_FILE="$WORK_DIR/realms.list"

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

printf '%s\n' "$MANAGED_REALMS" | tr ',' '\n' > "$REALMS_FILE"
[ "$(sort -u "$REALMS_FILE" | wc -l | tr -d ' ')" \
    -eq "$(wc -l < "$REALMS_FILE" | tr -d ' ')" ] \
    || fail "KEYCLOAK_EXISTING_MANAGED_REALMS contains duplicates."

write_payload() {
    printf '{"resetPasswordAllowed":true,"smtpServer":{"host":"%s","port":"%s","from":"%s","fromDisplayName":"%s","replyTo":"%s","replyToDisplayName":"%s","auth":"%s","starttls":"%s","ssl":"%s","user":"%s","password":"%s"}}\n' \
        "$SMTP_HOST" \
        "$SMTP_PORT" \
        "$SMTP_FROM" \
        "$SMTP_FROM_DISPLAY_NAME" \
        "$SMTP_REPLY_TO" \
        "$SMTP_REPLY_TO_DISPLAY_NAME" \
        "$SMTP_AUTH" \
        "$SMTP_STARTTLS" \
        "$SMTP_SSL" \
        "$SMTP_USER" \
        "$SMTP_PASSWORD" \
        > "$PAYLOAD_FILE"
    chmod 600 "$PAYLOAD_FILE"
}

verify_realm() {
    realm_name="$1"
    if ! kcadm get "realms/$realm_name" \
            --fields 'resetPasswordAllowed,smtpServer(*)' > "$REALM_FILE"; then
        fail "Could not inspect password recovery for an allowlisted realm."
    fi
    /bin/bash "$RUNTIME_JSON_VALIDATOR" realm-smtp "$REALM_FILE" \
        || fail "An allowlisted realm does not match the password-recovery SMTP contract."
}

if [ "$MODE" = reconcile ]; then
    write_payload
fi

while IFS= read -r realm_name || [ -n "$realm_name" ]; do
    [ -n "$realm_name" ] || continue
    if [ "$MODE" = reconcile ]; then
        kcadm update "realms/$realm_name" -f "$PAYLOAD_FILE" >/dev/null \
            || fail "Could not reconcile password recovery for an allowlisted realm."
    fi
    verify_realm "$realm_name"
done < "$REALMS_FILE"

if [ "$MODE" = verify ]; then
    echo "Keycloak realm password-recovery SMTP is valid."
else
    echo "Keycloak realm password-recovery SMTP was reconciled successfully."
fi
