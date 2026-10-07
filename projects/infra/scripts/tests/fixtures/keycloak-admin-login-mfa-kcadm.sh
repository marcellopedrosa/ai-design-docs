#!/bin/sh
set -eu

command_name="${1:-}"
resource="${2:-}"
otp_execution=22222222-2222-2222-2222-222222222222
duplicate_otp_execution=33333333-3333-3333-3333-333333333333
pwd_execution=11111111-1111-1111-1111-111111111111
otp_config=44444444-4444-4444-4444-444444444444
pwd_config=55555555-5555-5555-5555-555555555555
forms_execution=66666666-6666-6666-6666-666666666666
forms_flow=77777777-7777-7777-7777-777777777777
parent_execution=88888888-8888-8888-8888-888888888888
parent_flow=99999999-9999-9999-9999-999999999999
condition_execution=aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa
duplicate_condition_execution=bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb

printf '%s\n' "$*" >> "${FAKE_KCADM_LOG:?}"

case " $* " in
    *" --password "*|*" --secret "*|*" users/"*"/credentials "*|*" disable-credential-types "*)
        exit 91
        ;;
esac
[ "$command_name" != delete ] || exit 92

option_value() {
    option_name="$1"
    shift
    previous_argument=""
    for argument in "$@"; do
        if [ "$previous_argument" = "$option_name" ]; then
            printf '%s\n' "$argument"
            return
        fi
        previous_argument="$argument"
    done
    printf '\n'
}

setting_value() {
    setting_name="$1"
    shift
    for argument in "$@"; do
        case "$argument" in
            "$setting_name"=*)
                printf '%s\n' "${argument#*=}"
                return
                ;;
        esac
    done
    printf '\n'
}

emit_execution_csv() {
    execution_id="$1"
    provider_id="$2"
    requirement="$3"
    priority="$4"
    authentication_config="$5"
    authentication_flow="$6"
    flow_id="$7"
    level="$8"
    index="$9"
    fields="${10}"
    row=""
    remaining_fields="$fields,"
    while [ -n "$remaining_fields" ]; do
        field_name="${remaining_fields%%,*}"
        remaining_fields="${remaining_fields#*,}"
        case "$field_name" in
            id) field_value="$execution_id" ;;
            providerId) field_value="$provider_id" ;;
            requirement) field_value="$requirement" ;;
            priority) field_value="$priority" ;;
            authenticationConfig) field_value="$authentication_config" ;;
            authenticationFlow) field_value="$authentication_flow" ;;
            flowId) field_value="$flow_id" ;;
            level) field_value="$level" ;;
            index) field_value="$index" ;;
            *) exit 93 ;;
        esac
        if [ -z "$row" ]; then
            row="$field_value"
        else
            row="$row,$field_value"
        fi
    done
    printf '%s\n' "$row"
}

emit_forms_flow() {
    emit_execution_csv \
        "$forms_execution" '' ALTERNATIVE 10 '' true "$forms_flow" 0 0 "$1"
}

emit_password() {
    emit_execution_csv \
        "$pwd_execution" auth-username-password-form REQUIRED 10 \
        "$pwd_config" '' '' 1 0 "$1"
}

emit_parent_flow() {
    parent_requirement="${2:-$(cat "${FAKE_STATE_DIR:?}/parent-requirement")}"
    parent_index="${3:-1}"
    emit_execution_csv \
        "$parent_execution" '' "$parent_requirement" \
        "$(cat "$FAKE_STATE_DIR/parent-priority")" '' true "$parent_flow" \
        1 "$parent_index" "$1"
}

emit_condition() {
    condition_requirement="${2:-REQUIRED}"
    condition_id="${3:-$condition_execution}"
    condition_index="${4:-0}"
    emit_execution_csv \
        "$condition_id" conditional-user-configured "$condition_requirement" \
        10 '' '' '' 2 "$condition_index" "$1"
}

emit_otp() {
    otp_id="${2:-$otp_execution}"
    otp_requirement="${3:-$(cat "${FAKE_STATE_DIR:?}/otp-requirement")}"
    otp_level="${4:-2}"
    otp_index="${5:-1}"
    emit_execution_csv \
        "$otp_id" auth-otp-form "$otp_requirement" \
        "$(cat "$FAKE_STATE_DIR/otp-priority")" "$otp_config" '' '' \
        "$otp_level" "$otp_index" "$1"
}

if [ "$command_name" = get ] && [ "$resource" = realms/saas-admin ]; then
    printf '%s\n' '{"browserFlow":"browser"}'
    exit 0
fi

if [ "$command_name" = get ] \
        && [ "$resource" = authentication/flows/browser/executions ]; then
    fields="$(option_value --fields "$@")"
    [ -n "$fields" ] || exit 94
    scenario="${FAKE_SCENARIO:-normal}"
    case "$scenario" in
        missing-otp)
            emit_forms_flow "$fields"
            emit_password "$fields"
            emit_parent_flow "$fields"
            emit_condition "$fields"
            ;;
        duplicate-otp)
            emit_forms_flow "$fields"
            emit_password "$fields"
            emit_parent_flow "$fields"
            emit_condition "$fields"
            emit_otp "$fields"
            emit_otp "$fields" "$duplicate_otp_execution" ALTERNATIVE 2 2
            ;;
        malformed-priority)
            emit_execution_csv \
                "$forms_execution" '' ALTERNATIVE not-a-priority '' true \
                "$forms_flow" 0 0 "$fields"
            ;;
        malformed-level)
            emit_forms_flow "$fields"
            emit_password "$fields"
            emit_parent_flow "$fields"
            emit_condition "$fields"
            emit_otp "$fields" "$otp_execution" ALTERNATIVE not-a-level 1
            ;;
        malformed-index)
            emit_execution_csv \
                "$forms_execution" '' ALTERNATIVE 10 '' true "$forms_flow" \
                0 not-an-index "$fields"
            ;;
        missing-parent)
            emit_execution_csv \
                "$pwd_execution" auth-username-password-form REQUIRED 10 \
                "$pwd_config" '' '' 0 0 "$fields"
            emit_execution_csv \
                "$condition_execution" conditional-user-configured REQUIRED 20 \
                '' '' '' 0 1 "$fields"
            emit_otp "$fields" "$otp_execution" ALTERNATIVE 0 2
            ;;
        duplicate-parent)
            emit_forms_flow "$fields"
            emit_password "$fields"
            emit_parent_flow "$fields"
            emit_parent_flow "$fields"
            emit_condition "$fields"
            emit_otp "$fields"
            ;;
        missing-condition)
            emit_forms_flow "$fields"
            emit_password "$fields"
            emit_parent_flow "$fields"
            emit_otp "$fields"
            ;;
        duplicate-condition)
            emit_forms_flow "$fields"
            emit_password "$fields"
            emit_parent_flow "$fields"
            emit_condition "$fields"
            emit_condition "$fields" REQUIRED "$duplicate_condition_execution" 1
            emit_otp "$fields" "$otp_execution" ALTERNATIVE 2 2
            ;;
        disabled-condition)
            emit_forms_flow "$fields"
            emit_password "$fields"
            emit_parent_flow "$fields"
            emit_condition "$fields" DISABLED
            emit_otp "$fields"
            ;;
        unmanaged-parent-requirement)
            emit_forms_flow "$fields"
            emit_password "$fields"
            emit_parent_flow "$fields" REQUIRED
            emit_condition "$fields"
            emit_otp "$fields"
            ;;
        unmanaged-otp-requirement)
            emit_forms_flow "$fields"
            emit_password "$fields"
            emit_parent_flow "$fields"
            emit_condition "$fields"
            emit_otp "$fields" "$otp_execution" REQUIRED
            ;;
        unmanaged-conditional)
            emit_forms_flow "$fields"
            emit_password "$fields"
            emit_parent_flow "$fields"
            emit_condition "$fields" CONDITIONAL
            emit_otp "$fields"
            ;;
        normal)
            emit_forms_flow "$fields"
            emit_password "$fields"
            emit_parent_flow "$fields"
            emit_condition "$fields"
            emit_otp "$fields"
            ;;
        *) exit 95 ;;
    esac
    exit 0
fi

if [ "$command_name" = get ] \
        && [ "$resource" = authentication/required-actions/CONFIGURE_TOTP ]; then
    enabled="$(cat "${FAKE_STATE_DIR:?}/configure-totp-enabled")"
    fields="$(option_value --fields "$@")"
    [ -z "$fields" ] || exit 94
    case "${FAKE_SCENARIO:-normal}" in
        wrong-required-action)
            printf '%s\n' \
                '{"alias":"UPDATE_PASSWORD","name":"Configure OTP / DEV","providerId":"UPDATE_PASSWORD","enabled":true,"defaultAction":false,"priority":20,"config":{"sentinel":"preserve-me","nested":"{\"enabled\":true}"}}'
            ;;
        default-action-enabled)
            printf '%s%s%s\n' \
                '{"alias":"CONFIGURE_TOTP","name":"Configure OTP / DEV","providerId":"CONFIGURE_TOTP","enabled":' \
                "$enabled" \
                ',"defaultAction":true,"priority":20,"config":{"sentinel":"preserve-me","nested":"{\"enabled\":true}"}}'
            ;;
        *)
            printf '%s%s%s\n' \
                '{"alias":"CONFIGURE_TOTP","name":"Configure OTP / DEV","providerId":"CONFIGURE_TOTP","enabled":' \
                "$enabled" \
                ',"defaultAction":false,"priority":20,"config":{"sentinel":"preserve-me","nested":"{\"enabled\":true}"}}'
            ;;
    esac
    exit 0
fi

if [ "$command_name" = update ] \
        && [ "$resource" = authentication/flows/browser/executions ]; then
    case " $* " in
        *' --no-merge '*) ;;
        *) exit 96 ;;
    esac
    execution_id="$(setting_value id "$@")"
    requirement="$(setting_value requirement "$@")"
    priority="$(setting_value priority "$@")"
    if [ "$execution_id" = "$otp_execution" ] \
            && [ "${FAKE_FAILURE_POINT:-}" = otp-update ]; then
        exit 102
    fi
    case "$execution_id" in
        "$parent_execution")
            [ "$priority" = "$(cat "${FAKE_STATE_DIR:?}/parent-priority")" ] \
                || exit 97
            case "$requirement" in
                CONDITIONAL|DISABLED) ;;
                *) exit 98 ;;
            esac
            old_requirement="$(cat "$FAKE_STATE_DIR/parent-requirement")"
            printf 'flow-parent:%s:%s>%s\n' \
                "$execution_id" "$old_requirement" "$requirement" \
                >> "${FAKE_MUTATION_LOG:?}"
            printf '%s\n' "$requirement" > "$FAKE_STATE_DIR/parent-requirement"
            ;;
        "$otp_execution")
            [ "$priority" = "$(cat "${FAKE_STATE_DIR:?}/otp-priority")" ] \
                || exit 97
            case "$requirement" in
                ALTERNATIVE|DISABLED) ;;
                *) exit 98 ;;
            esac
            old_requirement="$(cat "$FAKE_STATE_DIR/otp-requirement")"
            printf 'flow-otp:%s:%s>%s\n' \
                "$execution_id" "$old_requirement" "$requirement" \
                >> "${FAKE_MUTATION_LOG:?}"
            printf '%s\n' "$requirement" > "$FAKE_STATE_DIR/otp-requirement"
            ;;
        *)
            exit 96
            ;;
    esac
    exit 0
fi

if [ "$command_name" = update ] \
        && [ "$resource" = authentication/required-actions/CONFIGURE_TOTP ]; then
    payload_file="$(option_value -f "$@")"
    [ -n "$payload_file" ] && [ -f "$payload_file" ] || exit 99
    case " $* " in
        *' --no-merge '*) ;;
        *) exit 99 ;;
    esac
    [ -z "$(setting_value enabled "$@")" ] || exit 99
    enabled_result="$(/bin/bash "${FAKE_RUNTIME_JSON_VALIDATOR:?}" \
        admin-login-required-action "$payload_file")" || exit 99
    enabled="${enabled_result#enabled=}"
    alias="$(setting_value alias "$@")"
    provider_id="$(setting_value providerId "$@")"
    default_action="$(setting_value defaultAction "$@")"
    priority="$(setting_value priority "$@")"
    [ -z "$alias$provider_id$default_action$priority" ] || exit 99
    case "$enabled" in
        true|false) ;;
        *) exit 100 ;;
    esac
    expected_payload_prefix='{"alias":"CONFIGURE_TOTP","name":"Configure OTP / DEV","providerId":"CONFIGURE_TOTP","enabled":'
    expected_payload_suffix=',"defaultAction":false,"priority":20,"config":{"sentinel":"preserve-me","nested":"{\"enabled\":true}"}}'
    expected_payload="${expected_payload_prefix}${enabled}${expected_payload_suffix}"
    actual_payload="$(tr -d '\r\n' < "$payload_file")"
    [ "$actual_payload" = "$expected_payload" ] || exit 99
    old_enabled="$(cat "${FAKE_STATE_DIR:?}/configure-totp-enabled")"
    printf 'required-action:%s>%s\n' "$old_enabled" "$enabled" \
        >> "${FAKE_MUTATION_LOG:?}"
    printf '%s\n' "$enabled" > "$FAKE_STATE_DIR/configure-totp-enabled"
    exit 0
fi

exit 101
