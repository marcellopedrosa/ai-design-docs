#!/usr/bin/env bash

set -Eeuo pipefail
umask 077

PROGRAM_NAME=generate-outbound-attempt-hmac-keyring
OUTPUT_FILE=
ACTIVE_KEY_ID=
TEMP_FILE=

cleanup() {
    if [ -n "$TEMP_FILE" ] && [ -f "$TEMP_FILE" ] && [ ! -L "$TEMP_FILE" ]; then
        rm -f -- "$TEMP_FILE" >/dev/null 2>&1 || true
    fi
}

reject() {
    cleanup
    printf '%s\n' "$PROGRAM_NAME: rejected" >&2
    exit 1
}

trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

while [ "$#" -gt 0 ]; do
    case "$1" in
        --output)
            [ "$#" -ge 2 ] || reject
            OUTPUT_FILE="$2"
            shift 2
            ;;
        --active-key-id)
            [ "$#" -ge 2 ] || reject
            ACTIVE_KEY_ID="$2"
            shift 2
            ;;
        *)
            reject
            ;;
    esac
done

[ -n "$OUTPUT_FILE" ] && [ -n "$ACTIVE_KEY_ID" ] || reject
[[ "$ACTIVE_KEY_ID" =~ ^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$ ]] || reject

for required_command in chmod dirname id ln mktemp openssl realpath rm stat tr wc; do
    command -v "$required_command" >/dev/null 2>&1 || reject
done

OUTPUT_DIRECTORY="$(dirname -- "$OUTPUT_FILE")" || reject
[ -d "$OUTPUT_DIRECTORY" ] && [ ! -L "$OUTPUT_DIRECTORY" ] || reject
[ "$(realpath -e -- "$OUTPUT_DIRECTORY" 2>/dev/null)" = \
  "$(realpath -ms -- "$OUTPUT_DIRECTORY" 2>/dev/null)" ] || reject
[ "$(stat -c '%a' -- "$OUTPUT_DIRECTORY" 2>/dev/null)" = 700 ] || reject
[ "$(stat -c '%u' -- "$OUTPUT_DIRECTORY" 2>/dev/null)" = "$(id -u)" ] || reject
[ ! -e "$OUTPUT_FILE" ] && [ ! -L "$OUTPUT_FILE" ] || reject

TEMP_FILE="$(mktemp "$OUTPUT_DIRECTORY/.outbound-attempt-hmac-keyring.tmp.XXXXXX")" \
    || reject
KEY_MATERIAL="$(openssl rand -base64 32 | tr -d '\r\n')" || reject
DECODED_SIZE="$(printf '%s' "$KEY_MATERIAL" \
    | openssl base64 -d -A 2>/dev/null \
    | wc -c \
    | tr -d '[:space:]')" || reject
[ "$DECODED_SIZE" = 32 ] || reject

printf '{"keys":{"%s":"%s"}}\n' "$ACTIVE_KEY_ID" "$KEY_MATERIAL" >"$TEMP_FILE" \
    || reject
chmod 600 -- "$TEMP_FILE" || reject

if ! ln -- "$TEMP_FILE" "$OUTPUT_FILE" 2>/dev/null; then
    reject
fi
rm -f -- "$TEMP_FILE" || reject
TEMP_FILE=
unset KEY_MATERIAL DECODED_SIZE

printf '%s\n' "$PROGRAM_NAME: created"
