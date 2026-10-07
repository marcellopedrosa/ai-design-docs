ensure_generated_keyring() {
    local purpose="$1"
    local key_id="$2"
    local source_file="$3"
    local container_file="$4"
    local active_key_variable="$5"
    local keyring_file_variable="$6"
    local env_key_id env_keyring_file key_material decoded_length
    local keyring_content keyring_pattern keyring_temp env_temp

    [ -f "$GENERATED_ENV_FILE" ] || return 0
    command -v openssl >/dev/null 2>&1 || {
        echo "ERROR: openssl is required to provision the local $purpose keyring."
        exit 1
    }

    env_key_id="$(awk -F= -v variable_name="$active_key_variable" '
        $1 == variable_name {
            print substr($0, index($0, "=") + 1)
            exit
        }
    ' "$GENERATED_ENV_FILE")"
    env_keyring_file="$(awk -F= -v variable_name="$keyring_file_variable" '
        $1 == variable_name {
            print substr($0, index($0, "=") + 1)
            exit
        }
    ' "$GENERATED_ENV_FILE")"

    if { [ -n "$env_key_id" ] && [ -z "$env_keyring_file" ]; } \
        || { [ -z "$env_key_id" ] && [ -n "$env_keyring_file" ]; }; then
        echo "ERROR: Generated $purpose configuration is incomplete."
        exit 1
    fi
    if [ -n "$env_key_id" ] \
        && { [ "$env_key_id" != "$key_id" ] || [ "$env_keyring_file" != "$container_file" ]; }; then
        echo "ERROR: Generated $purpose configuration does not match its stable local keyring."
        exit 1
    fi

    umask 077
    mkdir -p "$DEV_SECRETS_DIR"
    chmod 700 "$DEV_SECRETS_DIR"

    if [ -L "$source_file" ]; then
        echo "ERROR: Local $purpose keyring must not be a symbolic link."
        exit 1
    fi

    if [ ! -e "$source_file" ]; then
        if [ -n "$env_key_id" ] || [ -n "$env_keyring_file" ]; then
            echo "ERROR: Configured local $purpose keyring is missing; refusing to rotate it implicitly."
            exit 1
        fi

        keyring_temp="$(mktemp "$DEV_SECRETS_DIR/.conversation-keyring.tmp.XXXXXX")"
        key_material="$(random_keyring_key)"
        printf '{"keys":{"%s":"%s"}}\n' \
            "$key_id" "$key_material" > "$keyring_temp"
        chmod 600 "$keyring_temp"

        if ln "$keyring_temp" "$source_file" 2>/dev/null; then
            rm -f "$keyring_temp"
        else
            rm -f "$keyring_temp"
            [ -f "$source_file" ] || {
                echo "ERROR: Could not create the local $purpose keyring."
                exit 1
            }
        fi
        unset key_material
        echo "Generated a stable local $purpose keyring in .dev-secrets."
    fi

    if [ -L "$source_file" ]; then
        echo "ERROR: Local $purpose keyring must not be a symbolic link."
        exit 1
    fi
    if [ ! -f "$source_file" ]; then
        echo "ERROR: Local $purpose keyring is not a regular file."
        exit 1
    fi
    chmod 600 "$source_file"

    keyring_content="$(tr -d '\r\n' < "$source_file")"
    keyring_pattern="^\\{\\\"keys\\\":\\{\\\"${key_id}\\\":\\\"([A-Za-z0-9+/]+={0,2})\\\"\\}\\}$"
    if [[ ! "$keyring_content" =~ $keyring_pattern ]]; then
        echo "ERROR: Local $purpose keyring has an invalid structure."
        exit 1
    fi
    key_material="${BASH_REMATCH[1]}"
    if ! decoded_length="$(printf '%s' "$key_material" \
        | openssl base64 -d -A 2>/dev/null \
        | wc -c)" \
        || [ "${decoded_length//[[:space:]]/}" != "32" ]; then
        echo "ERROR: Local $purpose key must contain exactly 32 bytes."
        exit 1
    fi
    unset key_material keyring_content

    env_temp="$(mktemp "$GENERATED_ENV_FILE.tmp.XXXXXX")"
    if ! awk \
        -F= \
        -v active_key_variable="$active_key_variable" \
        -v keyring_file_variable="$keyring_file_variable" \
        -v key_id="$key_id" \
        -v keyring_file="$container_file" '
        BEGIN { wrote_id = 0; wrote_file = 0 }
        $1 == active_key_variable {
            if (!wrote_id) {
                print active_key_variable "=" key_id
                wrote_id = 1
            }
            next
        }
        $1 == keyring_file_variable {
            if (!wrote_file) {
                print keyring_file_variable "=" keyring_file
                wrote_file = 1
            }
            next
        }
        { print }
        END {
            if (!wrote_id) {
                print active_key_variable "=" key_id
            }
            if (!wrote_file) {
                print keyring_file_variable "=" keyring_file
            }
        }
    ' "$GENERATED_ENV_FILE" > "$env_temp"; then
        rm -f "$env_temp"
        echo "ERROR: Could not update the generated $purpose configuration."
        exit 1
    fi
    chmod 600 "$env_temp"
    mv "$env_temp" "$GENERATED_ENV_FILE"
}

read_outbound_attempt_env_configuration() {
    local active_count path_count

    active_count="$(grep -c '^CONVERSATION_OUTBOUND_ATTEMPT_HMAC_ACTIVE_KEY_ID=' \
        "$GENERATED_ENV_FILE" || true)"
    path_count="$(grep -c '^CONVERSATION_OUTBOUND_ATTEMPT_HMAC_KEYRING_FILE=' \
        "$GENERATED_ENV_FILE" || true)"
    if [ "$active_count" -gt 1 ] || [ "$path_count" -gt 1 ]; then
        echo "ERROR: Generated outbound attempt HMAC configuration contains duplicate settings."
        exit 1
    fi

    OUTBOUND_ENV_ACTIVE_KEY_ID="$(sed -n \
        's/^CONVERSATION_OUTBOUND_ATTEMPT_HMAC_ACTIVE_KEY_ID=//p' \
        "$GENERATED_ENV_FILE")"
    OUTBOUND_ENV_KEYRING_FILE="$(sed -n \
        's/^CONVERSATION_OUTBOUND_ATTEMPT_HMAC_KEYRING_FILE=//p' \
        "$GENERATED_ENV_FILE")"
    if { [ -n "$OUTBOUND_ENV_ACTIVE_KEY_ID" ] && [ -z "$OUTBOUND_ENV_KEYRING_FILE" ]; } \
        || { [ -z "$OUTBOUND_ENV_ACTIVE_KEY_ID" ] && [ -n "$OUTBOUND_ENV_KEYRING_FILE" ]; }; then
        echo "ERROR: Generated outbound attempt HMAC configuration is incomplete."
        exit 1
    fi
    if [ -n "$OUTBOUND_ENV_KEYRING_FILE" ] \
        && [ "$OUTBOUND_ENV_KEYRING_FILE" != "$OUTBOUND_ATTEMPT_KEYRING_CONTAINER_FILE" ]; then
        echo "ERROR: Generated outbound attempt HMAC configuration has an invalid keyring reference."
        exit 1
    fi
}

validate_outbound_attempt_keyring() {
    local source_file="$1"
    local active_key_id="$2"
    local key_record key_id key_material decoded_length digest
    local -a key_records=()
    local -A seen_digests=()

    command -v jq >/dev/null 2>&1 || {
        echo "ERROR: jq is required to validate the local outbound attempt HMAC keyring."
        exit 1
    }
    [[ "$active_key_id" =~ ^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$ ]] || {
        echo "ERROR: Local outbound attempt HMAC keyring has an invalid active key ID."
        exit 1
    }
    if ! jq -e --arg active_key_id "$active_key_id" '
        type == "object"
        and (keys == ["keys"])
        and (.keys | type == "object")
        and (.keys | length >= 1 and length <= 32)
        and (.keys | has($active_key_id))
        and (.keys | to_entries | all(.value | type == "string"))
    ' "$source_file" >/dev/null 2>&1; then
        echo "ERROR: Local outbound attempt HMAC keyring has an invalid structure."
        exit 1
    fi

    mapfile -t key_records < <(jq -r '.keys | to_entries[] | [.key, .value] | @tsv' \
        "$source_file")
    if [ "${#key_records[@]}" -lt 1 ] || [ "${#key_records[@]}" -gt 32 ]; then
        echo "ERROR: Local outbound attempt HMAC keyring has an invalid key count."
        exit 1
    fi

    OUTBOUND_VALIDATED_KEY_IDS=()
    OUTBOUND_VALIDATED_KEY_DIGESTS=()
    for key_record in "${key_records[@]}"; do
        key_id="${key_record%%$'\t'*}"
        key_material="${key_record#*$'\t'}"
        if [[ ! "$key_id" =~ ^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$ ]] \
            || [[ ! "$key_material" =~ ^([A-Za-z0-9+/]{4})*([A-Za-z0-9+/]{2}==|[A-Za-z0-9+/]{3}=)?$ ]]; then
            echo "ERROR: Local outbound attempt HMAC keyring contains an invalid entry."
            exit 1
        fi
        if ! decoded_length="$(printf '%s' "$key_material" \
            | openssl base64 -d -A 2>/dev/null \
            | wc -c \
            | tr -d '[:space:]')" \
            || [ "$decoded_length" != "32" ]; then
            echo "ERROR: Local outbound attempt HMAC keys must contain exactly 32 bytes."
            exit 1
        fi
        digest="$(printf '%s' "$key_material" \
            | openssl base64 -d -A 2>/dev/null \
            | openssl dgst -sha256 -binary \
            | openssl base64 -A)"
        if [ -n "${seen_digests[$digest]+present}" ]; then
            echo "ERROR: Local outbound attempt HMAC keyring reuses key material."
            exit 1
        fi
        seen_digests["$digest"]=true
        OUTBOUND_VALIDATED_KEY_IDS+=("$key_id")
        OUTBOUND_VALIDATED_KEY_DIGESTS+=("$digest")
    done
    unset key_material digest decoded_length key_record
}

discover_single_outbound_attempt_key_id() {
    local source_file="$1"

    jq -er '
        select(type == "object" and (keys == ["keys"]))
        | .keys
        | select(type == "object" and length == 1)
        | keys[0]
    ' "$source_file" 2>/dev/null
}

write_outbound_attempt_env_configuration() {
    local active_key_id="$1"

    OUTBOUND_STAGE_ENV_TEMP="$(mktemp "$GENERATED_ENV_FILE.tmp.XXXXXX")"
    if ! awk \
        -F= \
        -v active_key_id="$active_key_id" \
        -v keyring_file="$OUTBOUND_ATTEMPT_KEYRING_CONTAINER_FILE" '
        BEGIN { wrote_id = 0; wrote_file = 0 }
        $1 == "CONVERSATION_OUTBOUND_ATTEMPT_HMAC_ACTIVE_KEY_ID" {
            if (!wrote_id) {
                print "CONVERSATION_OUTBOUND_ATTEMPT_HMAC_ACTIVE_KEY_ID=" active_key_id
                wrote_id = 1
            }
            next
        }
        $1 == "CONVERSATION_OUTBOUND_ATTEMPT_HMAC_KEYRING_FILE" {
            if (!wrote_file) {
                print "CONVERSATION_OUTBOUND_ATTEMPT_HMAC_KEYRING_FILE=" keyring_file
                wrote_file = 1
            }
            next
        }
        { print }
        END {
            if (!wrote_id) {
                print "CONVERSATION_OUTBOUND_ATTEMPT_HMAC_ACTIVE_KEY_ID=" active_key_id
            }
            if (!wrote_file) {
                print "CONVERSATION_OUTBOUND_ATTEMPT_HMAC_KEYRING_FILE=" keyring_file
            }
        }
    ' "$GENERATED_ENV_FILE" > "$OUTBOUND_STAGE_ENV_TEMP"; then
        echo "ERROR: Could not update the generated outbound attempt HMAC configuration."
        exit 1
    fi
    chmod 600 "$OUTBOUND_STAGE_ENV_TEMP"
    mv "$OUTBOUND_STAGE_ENV_TEMP" "$GENERATED_ENV_FILE"
    OUTBOUND_STAGE_ENV_TEMP=""
    chmod 600 "$GENERATED_ENV_FILE"
}

ensure_outbound_attempt_commit_receipt_key() {
    local command_name key_owner key_mode key_temp key_value

    for command_name in awk cat jq openssl sha256sum; do
        command -v "$command_name" >/dev/null 2>&1 || {
            echo "ERROR: A required local outbound HMAC receipt command is unavailable."
            exit 1
        }
    done

    if [ -L "$OUTBOUND_ATTEMPT_COMMIT_RECEIPT_KEY_FILE" ]; then
        echo "ERROR: Local outbound HMAC commit-receipt key must not be a symbolic link."
        exit 1
    fi
    if [ ! -e "$OUTBOUND_ATTEMPT_COMMIT_RECEIPT_KEY_FILE" ]; then
        if [ -e "$OUTBOUND_ATTEMPT_COMMIT_RECEIPT_FILE" ] \
            || [ -L "$OUTBOUND_ATTEMPT_COMMIT_RECEIPT_FILE" ]; then
            echo "ERROR: Local outbound HMAC commit receipt exists without its authentication key."
            exit 1
        fi
        umask 077
        key_temp="$(mktemp "$DEV_SECRETS_DIR/.outbound-receipt-key.tmp.XXXXXX")"
        key_value="$(random_secret)"
        printf '%s' "$key_value" > "$key_temp"
        chmod 600 "$key_temp"
        mv "$key_temp" "$OUTBOUND_ATTEMPT_COMMIT_RECEIPT_KEY_FILE"
        unset key_value
    fi
    if [ ! -f "$OUTBOUND_ATTEMPT_COMMIT_RECEIPT_KEY_FILE" ]; then
        echo "ERROR: Local outbound HMAC commit-receipt key is not a regular file."
        exit 1
    fi
    key_owner="$(stat -Lc '%u' "$OUTBOUND_ATTEMPT_COMMIT_RECEIPT_KEY_FILE")"
    key_mode="$(stat -Lc '%a' "$OUTBOUND_ATTEMPT_COMMIT_RECEIPT_KEY_FILE")"
    if [ "$key_owner" != "$(id -u)" ] || [ "$key_mode" != "600" ] \
        || ! grep -Eq '^[0-9a-f]{64}$' "$OUTBOUND_ATTEMPT_COMMIT_RECEIPT_KEY_FILE"; then
        echo "ERROR: Local outbound HMAC commit-receipt key is invalid or not owner-only."
        exit 1
    fi
}

outbound_attempt_keyring_sha256() {
    sha256sum "$OUTBOUND_ATTEMPT_KEYRING_SOURCE_FILE" | awk '{print $1}'
}

outbound_attempt_active_key_id_sha256() {
    local active_key_id="$1"
    printf '%s' "$active_key_id" | sha256sum | awk '{print $1}'
}

outbound_attempt_commit_receipt_signature() {
    local keyring_sha256="$1"
    local active_key_id_sha256="$2"

    {
        printf '%s' 'outbound-hmac-commit-receipt:v1:'
        cat "$OUTBOUND_ATTEMPT_COMMIT_RECEIPT_KEY_FILE"
        printf ':%s:%s:' "$keyring_sha256" "$active_key_id_sha256"
        cat "$OUTBOUND_ATTEMPT_COMMIT_RECEIPT_KEY_FILE"
    } | sha256sum | awk '{print $1}'
}

validate_outbound_attempt_commit_receipt() {
    local receipt_owner receipt_mode receipt_size
    local expected_keyring_sha expected_active_sha expected_signature
    local receipt_keyring_sha receipt_active_sha receipt_signature

    [ -L "$OUTBOUND_ATTEMPT_COMMIT_RECEIPT_FILE" ] && return 1
    [ -f "$OUTBOUND_ATTEMPT_COMMIT_RECEIPT_FILE" ] || return 1
    receipt_owner="$(stat -Lc '%u' "$OUTBOUND_ATTEMPT_COMMIT_RECEIPT_FILE")" || return 1
    receipt_mode="$(stat -Lc '%a' "$OUTBOUND_ATTEMPT_COMMIT_RECEIPT_FILE")" || return 1
    receipt_size="$(stat -Lc '%s' "$OUTBOUND_ATTEMPT_COMMIT_RECEIPT_FILE")" || return 1
    [ "$receipt_owner" = "$(id -u)" ] \
        && [ "$receipt_mode" = "600" ] \
        && [ "$receipt_size" -ge 1 ] \
        && [ "$receipt_size" -le 2048 ] \
        || return 1
    jq -e '
        type == "object"
        and (keys == ["activeKeyIdSha256", "keyringSha256", "signature", "version"])
        and .version == 1
        and (.activeKeyIdSha256 | type == "string" and test("^[0-9a-f]{64}$"))
        and (.keyringSha256 | type == "string" and test("^[0-9a-f]{64}$"))
        and (.signature | type == "string" and test("^[0-9a-f]{64}$"))
    ' "$OUTBOUND_ATTEMPT_COMMIT_RECEIPT_FILE" >/dev/null 2>&1 || return 1

    receipt_keyring_sha="$(jq -er '.keyringSha256' \
        "$OUTBOUND_ATTEMPT_COMMIT_RECEIPT_FILE")" || return 1
    receipt_active_sha="$(jq -er '.activeKeyIdSha256' \
        "$OUTBOUND_ATTEMPT_COMMIT_RECEIPT_FILE")" || return 1
    receipt_signature="$(jq -er '.signature' \
        "$OUTBOUND_ATTEMPT_COMMIT_RECEIPT_FILE")" || return 1
    expected_keyring_sha="$(outbound_attempt_keyring_sha256)" || return 1
    expected_active_sha="$(outbound_attempt_active_key_id_sha256 \
        "$OUTBOUND_ENV_ACTIVE_KEY_ID")" || return 1
    expected_signature="$(outbound_attempt_commit_receipt_signature \
        "$expected_keyring_sha" "$expected_active_sha")" || return 1

    [ "$receipt_keyring_sha" = "$expected_keyring_sha" ] \
        && [ "$receipt_active_sha" = "$expected_active_sha" ] \
        && [ "$receipt_signature" = "$expected_signature" ]
}

write_outbound_attempt_commit_receipt() {
    local keyring_sha active_sha signature receipt_temp

    read_outbound_attempt_env_configuration
    validate_outbound_attempt_keyring \
        "$OUTBOUND_ATTEMPT_KEYRING_SOURCE_FILE" "$OUTBOUND_ENV_ACTIVE_KEY_ID"
    keyring_sha="$(outbound_attempt_keyring_sha256)"
    active_sha="$(outbound_attempt_active_key_id_sha256 \
        "$OUTBOUND_ENV_ACTIVE_KEY_ID")"
    signature="$(outbound_attempt_commit_receipt_signature \
        "$keyring_sha" "$active_sha")"

    umask 077
    receipt_temp="$(mktemp "$DEV_SECRETS_DIR/.outbound-receipt.tmp.XXXXXX")"
    printf '{"activeKeyIdSha256":"%s","keyringSha256":"%s","signature":"%s","version":1}\n' \
        "$active_sha" "$keyring_sha" "$signature" > "$receipt_temp"
    chmod 600 "$receipt_temp"
    mv "$receipt_temp" "$OUTBOUND_ATTEMPT_COMMIT_RECEIPT_FILE"
    unset active_sha keyring_sha signature
}
