grep -Fq 'build backend' "$FIXTURE_ROOT/launcher-body.sh" \
    || fail "host startup must build the backend before cutover"
grep -Fq 'up -d --no-build --no-recreate --wait --wait-timeout 300' \
    "$FIXTURE_ROOT/launcher-body.sh" \
    || fail "startup must prepare stateful dependencies without recreating them"
grep -Fq 'up -d --no-build --no-recreate --wait --wait-timeout 300 keycloak' \
    "$FIXTURE_ROOT/launcher-body.sh" \
    || fail "startup must start or verify Keycloak after database credential preparation"
grep -Fq 'verify-postgres-role-password' "$FIXTURE_ROOT/launcher-body.sh" \
    || fail "startup must verify effective PostgreSQL credentials before cutover"
grep -Fq 'verify-redis-password' "$FIXTURE_ROOT/launcher-body.sh" \
    || fail "startup must verify the effective Redis credential before cutover"
grep -Fq 'CONVERSATION_AUDIT_EXPOSURE_MAY_BE_OPEN=true' \
    "$FIXTURE_ROOT/launcher-body.sh" \
    || fail "startup must treat prior audit exposure as open from the commit gate"
grep -Fq 'run --rm --no-deps keycloak-provisioning-init' \
    "$FIXTURE_ROOT/launcher-body.sh" \
    || fail "startup must verify the Keycloak identity before cutover"
grep -Fq 'run --rm --no-deps outbound-attempt-keyring-init' \
    "$FIXTURE_ROOT/launcher-body.sh" \
    || fail "startup must install the outbound keyring at the cutover boundary"
grep -Fq 'up -d --no-build --no-deps --force-recreate backend' \
    "$FIXTURE_ROOT/launcher-body.sh" \
    || fail "startup must recreate only the backend after preflight"
grep -Fq 'up -d --no-build --no-deps --force-recreate ngrok-bot' \
    "$FIXTURE_ROOT/launcher-body.sh" \
    || fail "startup must recreate ngrok only after backend readiness"
if grep -Eq 'force-recreate.*(redis|postgres-app|postgres-keycloak|keycloak)' \
    "$FIXTURE_ROOT/launcher-body.sh"; then
    fail "incremental startup must never force-recreate a stateful dependency"
fi
grep -Fq 'up -d --build --force-recreate frontend' \
    "$FIXTURE_ROOT/launcher-body.sh" \
    || fail "startup must expose the frontend through a separate post-activation step"
grep -Fq 'validate_promoted_conversation_audit_backend' \
    "$FIXTURE_ROOT/launcher-body.sh" \
    || fail "startup must verify the effective backend audit environment"
initializer_service_block="$(sed -n \
    '/^  outbound-attempt-keyring-init:$/,/^  frontend:$/p' \
    "$REPOSITORY_ROOT/docker-compose.override.yml")"
printf '%s\n' "$initializer_service_block" | grep -Fq 'healthcheck:' \
    || fail "development keyring initializer must override the backend image healthcheck"
printf '%s\n' "$initializer_service_block" | grep -Fq 'disable: true' \
    || fail "development keyring initializer must disable the inherited HTTP healthcheck"
keycloak_service_block="$(sed -n \
    '/^  keycloak:$/,/^  keycloak-provisioning-init:$/p' \
    "$REPOSITORY_ROOT/docker-compose.yml")"
printf '%s\n' "$keycloak_service_block" | grep -Fq 'start_period: 180s' \
    || fail "Keycloak must tolerate cold augmentation and realm import"
printf '%s\n' "$keycloak_service_block" | grep -Fq 'KC_SERVER_ASYNC_BOOTSTRAP: "false"' \
    || fail "Keycloak readiness must wait for synchronous server bootstrap"
printf '%s\n' "$keycloak_service_block" | grep -Fq 'read -r http_version http_status http_rest' \
    || fail "Keycloak healthcheck must parse the HTTP readiness status line"
grep -Fq 'read -r http_version http_status http_rest' \
    "$REPOSITORY_ROOT/docker-compose.dev-expose.yml" \
    || fail "exposed DEV mode must not restore the unsafe Keycloak JSON healthcheck"
keycloak_readiness_status_is_up() {
    local http_version http_status http_rest
    IFS=' ' read -r http_version http_status http_rest
    [ "$http_version" = 'HTTP/1.1' ] && [ "$http_status" = 200 ]
}
if printf '%s\r\n%s\r\n' \
    'HTTP/1.1 503 Service Unavailable' \
    '{"status":"DOWN","checks":[{"name":"database","status":"UP"}]}' \
    | keycloak_readiness_status_is_up; then
    fail "nested Keycloak component UP masked readiness HTTP 503"
fi
printf '%s\r\n' 'HTTP/1.1 200 OK' \
    | keycloak_readiness_status_is_up \
    || fail "Keycloak readiness HTTP 200 was rejected"
grep -Fq 'Docker Compose did not complete the DEV backend cutover.' \
    "$FIXTURE_ROOT/launcher-body.sh" \
    || fail "start-dev-bot must explain an incomplete backend cutover"
grep -Fq 'http://127.0.0.1:8080/actuator/health/readiness' \
    "$FIXTURE_ROOT/launcher-body.sh" \
    || fail "start-dev-bot must gate success on backend readiness"
grep -Fq 'Backend did not become ready within 300 seconds.' \
    "$FIXTURE_ROOT/launcher-body.sh" \
    || fail "start-dev-bot backend readiness wait must be bounded"
grep -Fq 'ps -a outbound-attempt-keyring-init keycloak keycloak-provisioning-init backend ngrok-bot' \
    "$FIXTURE_ROOT/launcher-body.sh" \
    || fail "start-dev-bot must print critical service states after Compose failure"
grep -Fq 'source "$PROJECT_DIR/infra/scripts/lib/development-docker-access.sh"' \
    "$FIXTURE_ROOT/launcher-body.sh" \
    || fail "start-dev-bot must use the canonical direct-Docker preflight"
grep -Fqx 'export DEV_BOT_DIND_WRAPPER=1' \
    "$REPOSITORY_ROOT/infra/docker/dev-bot-entrypoint.sh" \
    || fail "the trusted Docker-in-Docker entrypoint must declare its root execution context"
if grep -Eq 'sudo[[:space:]]+(-E[[:space:]]+)?docker|--preserve-env=.*docker' \
    "$FIXTURE_ROOT/launcher-body.sh" \
    "$FIXTURE_DIR/infra/scripts/lib/development-docker-access.sh"; then
    fail "development entrypoints must never elevate Docker"
fi

(
    cd "$FIXTURE_DIR"
    ./start-dev-bot.sh --prepare-env-only
) > "$OUTPUT_FILE"

[ "$(stat -c '%a' "$FIXTURE_DIR/.dev-secrets")" = "700" ] \
    || fail "development secret directory must use mode 0700"
[ -d "$OUTBOUND_KEYRING_DIR" ] && [ ! -L "$OUTBOUND_KEYRING_DIR" ] \
    && [ "$(stat -c '%a' "$OUTBOUND_KEYRING_DIR")" = "700" ] \
    || fail "outbound HMAC source directory must be regular and owner-only"
[ -d "$OUTBOUND_APPROVAL_DIR" ] && [ ! -L "$OUTBOUND_APPROVAL_DIR" ] \
    || fail "outbound HMAC lifecycle approval directory was not created safely"
[ "$(stat -c '%a' "$FIXTURE_DIR/.dev-secrets/approvals")" = "700" ] \
    && [ "$(stat -c '%a' "$OUTBOUND_APPROVAL_DIR")" = "700" ] \
    || fail "outbound HMAC lifecycle approval directories must use mode 0700"
[ "$(stat -c '%a' "$GENERATED_ENV_FILE")" = "600" ] \
    || fail "generated environment file must use mode 0600"
[ "$(grep -c '^CONTACT_WEBHOOK_TOKEN=' "$GENERATED_ENV_FILE")" = "1" ] \
    || fail "generated environment must contain exactly one website contact token"
contact_webhook_token="$(sed -n 's/^CONTACT_WEBHOOK_TOKEN=//p' "$GENERATED_ENV_FILE")"
[[ "$contact_webhook_token" =~ ^[0-9a-f]{64}$ ]] \
    || fail "website contact token must contain exactly 32 random bytes in hex"
if grep -Fq "$contact_webhook_token" "$OUTPUT_FILE"; then
    fail "website contact token appeared in bootstrap output"
fi
[ -f "$OUTBOUND_COMMIT_RECEIPT_KEY_FILE" ] \
    && [ ! -L "$OUTBOUND_COMMIT_RECEIPT_KEY_FILE" ] \
    && [ "$(stat -c '%a' "$OUTBOUND_COMMIT_RECEIPT_KEY_FILE")" = "600" ] \
    || fail "outbound commit-receipt authentication key must be owner-only"
[ -f "$OUTBOUND_STAGE_LOCK_FILE" ] \
    && [ ! -L "$OUTBOUND_STAGE_LOCK_FILE" ] \
    && [ "$(stat -c '%a' "$OUTBOUND_STAGE_LOCK_FILE")" = "600" ] \
    || fail "outbound staging/start lock must be owner-only"
[ ! -e "$OUTBOUND_COMMIT_RECEIPT_FILE" ] \
    || fail "prepare-only must not emit an initializer commit receipt"

for executor_index in "${!EXECUTOR_VARIABLES[@]}"; do
    executor_variable="${EXECUTOR_VARIABLES[$executor_index]}"
    executor_default="${EXECUTOR_DEFAULTS[$executor_index]}"
    [ "$(grep -c "^${executor_variable}=" "$GENERATED_ENV_FILE")" = "1" ] \
        || fail "fresh environment must contain exactly one $executor_variable setting"
    grep -Fqx "${executor_variable}=${executor_default}" "$GENERATED_ENV_FILE" \
        || fail "fresh environment has the wrong bounded default for $executor_variable"
done

whatsapp_operator_value=271828
telegram_operator_value=314159
sed -i \
    -e "s/^APP_CONVERSATION_AUDIT_WEBHOOK_EXECUTOR_WHATSAPP_CORE_POOL_SIZE=.*/APP_CONVERSATION_AUDIT_WEBHOOK_EXECUTOR_WHATSAPP_CORE_POOL_SIZE=${whatsapp_operator_value}/" \
    -e 's/^APP_CONVERSATION_AUDIT_WEBHOOK_EXECUTOR_WHATSAPP_MAX_POOL_SIZE=.*/APP_CONVERSATION_AUDIT_WEBHOOK_EXECUTOR_WHATSAPP_MAX_POOL_SIZE=/' \
    -e '/^APP_CONVERSATION_AUDIT_WEBHOOK_EXECUTOR_WHATSAPP_QUEUE_CAPACITY=/d' \
    -e '/^APP_CONVERSATION_AUDIT_WEBHOOK_EXECUTOR_TELEGRAM_CORE_POOL_SIZE=/d' \
    -e "s/^APP_CONVERSATION_AUDIT_WEBHOOK_EXECUTOR_TELEGRAM_MAX_POOL_SIZE=.*/APP_CONVERSATION_AUDIT_WEBHOOK_EXECUTOR_TELEGRAM_MAX_POOL_SIZE=${telegram_operator_value}/" \
    -e 's/^APP_CONVERSATION_AUDIT_WEBHOOK_EXECUTOR_TELEGRAM_QUEUE_CAPACITY=.*/APP_CONVERSATION_AUDIT_WEBHOOK_EXECUTOR_TELEGRAM_QUEUE_CAPACITY=""/' \
    "$GENERATED_ENV_FILE"
chmod 640 "$GENERATED_ENV_FILE"
(
    cd "$FIXTURE_DIR"
    ./start-dev-bot.sh --prepare-env-only
) >> "$OUTPUT_FILE"
[ "$(stat -c '%a' "$GENERATED_ENV_FILE")" = "600" ] \
    || fail "repairing an existing environment must restore mode 0600"
expected_existing_executor_values=(
    "$whatsapp_operator_value"
    4
    100
    2
    "$telegram_operator_value"
    100
)
for executor_index in "${!EXECUTOR_VARIABLES[@]}"; do
    executor_variable="${EXECUTOR_VARIABLES[$executor_index]}"
    expected_executor_value="${expected_existing_executor_values[$executor_index]}"
    [ "$(grep -c "^${executor_variable}=" "$GENERATED_ENV_FILE")" = "1" ] \
        || fail "repaired environment must contain exactly one $executor_variable setting"
    grep -Fqx "${executor_variable}=${expected_executor_value}" "$GENERATED_ENV_FILE" \
        || fail "existing environment did not preserve or repair $executor_variable correctly"
done
if grep -Fq "$whatsapp_operator_value" "$OUTPUT_FILE" \
    || grep -Fq "$telegram_operator_value" "$OUTPUT_FILE"; then
    fail "operator-provided inbound executor values appeared in bootstrap output"
fi

cp "$GENERATED_ENV_FILE" "$FIXTURE_DIR/env.before-duplicate-executor"
duplicate_executor_value=duplicate-executor-value-must-not-leak
printf 'APP_CONVERSATION_AUDIT_WEBHOOK_EXECUTOR_WHATSAPP_CORE_POOL_SIZE=%s\n' \
    "$duplicate_executor_value" >> "$GENERATED_ENV_FILE"
cp "$GENERATED_ENV_FILE" "$FIXTURE_DIR/env.duplicate-executor-input"
if (
    cd "$FIXTURE_DIR"
    ./start-dev-bot.sh --prepare-env-only
) >> "$OUTPUT_FILE" 2>&1; then
    fail "bootstrap accepted a duplicate inbound webhook executor setting"
fi
cmp -s "$FIXTURE_DIR/env.duplicate-executor-input" "$GENERATED_ENV_FILE" \
    || fail "duplicate rejection changed the existing environment content"
if grep -Fq "$duplicate_executor_value" "$OUTPUT_FILE"; then
    fail "duplicate inbound executor value appeared in bootstrap output"
fi
mv "$FIXTURE_DIR/env.before-duplicate-executor" "$GENERATED_ENV_FILE"
chmod 600 "$GENERATED_ENV_FILE"

[ "$(grep -c '^KEYCLOAK_DEV_SUPERADMIN_INITIAL_PASSWORD=' "$GENERATED_ENV_FILE")" = "1" ] \
    || fail "generated environment must contain exactly one DEV Super Admin initial password"
dev_superadmin_initial_password="$(sed -n 's/^KEYCLOAK_DEV_SUPERADMIN_INITIAL_PASSWORD=//p' "$GENERATED_ENV_FILE")"
[[ "$dev_superadmin_initial_password" =~ ^[0-9a-f]{64}$ ]] \
    || fail "DEV Super Admin initial password must contain exactly 32 random bytes in hex"
for independent_variable in \
    DB_PASSWORD \
    KEYCLOAK_DB_PASSWORD \
    KEYCLOAK_ADMIN_PASSWORD \
    KEYCLOAK_PROVISIONING_CLIENT_SECRET \
    GRAFANA_ADMIN_PASSWORD \
    AUTH_SESSION_SECRET \
    CONTACT_WEBHOOK_TOKEN; do
    independent_value="$(sed -n "s/^${independent_variable}=//p" "$GENERATED_ENV_FILE")"
    [ -n "$independent_value" ] \
        || fail "generated environment is missing $independent_variable"
    [ "$dev_superadmin_initial_password" != "$independent_value" ] \
        || fail "DEV Super Admin initial password reused $independent_variable"
done
if grep -Fq "$dev_superadmin_initial_password" "$OUTPUT_FILE"; then
    fail "DEV Super Admin initial password appeared in bootstrap output"
fi

validate_keyring "$AES_KEYRING_FILE" "$AES_KEY_ID"
aes_key_material="$VALIDATED_KEY_MATERIAL"
validate_keyring "$AUDIT_HMAC_KEYRING_FILE" "$AUDIT_HMAC_KEY_ID"
audit_hmac_key_material="$VALIDATED_KEY_MATERIAL"
validate_keyring "$OUTBOUND_KEYRING_FILE" "$OUTBOUND_KEY_ID"
outbound_key_material="$VALIDATED_KEY_MATERIAL"

[ "$aes_key_material" != "$audit_hmac_key_material" ] \
    || fail "AES and audit HMAC material must differ"
[ "$aes_key_material" != "$outbound_key_material" ] \
    || fail "AES and outbound HMAC material must differ"
[ "$audit_hmac_key_material" != "$outbound_key_material" ] \
    || fail "audit and outbound HMAC material must differ"

[ "$(grep -c '^CONVERSATION_AUDIT_AES_ACTIVE_KEY_ID=' "$GENERATED_ENV_FILE")" = "1" ] \
    || fail "generated environment must contain one audit AES active key ID"
[ "$(grep -c '^CONVERSATION_AUDIT_AES_KEYRING_FILE=' "$GENERATED_ENV_FILE")" = "1" ] \
    || fail "generated environment must contain one audit AES keyring path"
[ "$(grep -c '^CONVERSATION_AUDIT_HMAC_ACTIVE_KEY_ID=' "$GENERATED_ENV_FILE")" = "1" ] \
    || fail "generated environment must contain one audit HMAC active key ID"
[ "$(grep -c '^CONVERSATION_AUDIT_HMAC_KEYRING_FILE=' "$GENERATED_ENV_FILE")" = "1" ] \
    || fail "generated environment must contain one audit HMAC keyring path"
[ "$(grep -c '^CONVERSATION_OUTBOUND_ATTEMPT_HMAC_ACTIVE_KEY_ID=' "$GENERATED_ENV_FILE")" = "1" ] \
    || fail "generated environment must contain one outbound active key ID"
[ "$(grep -c '^CONVERSATION_OUTBOUND_ATTEMPT_HMAC_KEYRING_FILE=' "$GENERATED_ENV_FILE")" = "1" ] \
    || fail "generated environment must contain one outbound keyring path"

grep -qx 'CONVERSATION_AUDIT_AES_ACTIVE_KEY_ID=dev-conversation-audit-aes-v1' "$GENERATED_ENV_FILE" \
    || fail "generated environment has the wrong audit AES active key ID"
grep -qx 'CONVERSATION_AUDIT_AES_KEYRING_FILE=/run/saas-secrets/conversation-audit-aes-keyring.json' \
    "$GENERATED_ENV_FILE" \
    || fail "generated environment has the wrong audit AES keyring path"
grep -qx 'CONVERSATION_AUDIT_HMAC_ACTIVE_KEY_ID=dev-conversation-audit-hmac-v1' "$GENERATED_ENV_FILE" \
    || fail "generated environment has the wrong audit HMAC active key ID"
grep -qx 'CONVERSATION_AUDIT_HMAC_KEYRING_FILE=/run/saas-secrets/conversation-audit-hmac-keyring.json' \
    "$GENERATED_ENV_FILE" \
    || fail "generated environment has the wrong audit HMAC keyring path"
grep -qx 'CONVERSATION_OUTBOUND_ATTEMPT_HMAC_ACTIVE_KEY_ID=dev-outbound-v1' "$GENERATED_ENV_FILE" \
    || fail "generated environment has the wrong outbound active key ID"
grep -qx 'CONVERSATION_OUTBOUND_ATTEMPT_HMAC_KEYRING_FILE=/run/saas-secrets/conversation-outbound-attempt-hmac-keyring.json' \
    "$GENERATED_ENV_FILE" \
    || fail "generated environment has the wrong outbound keyring path"

for key_material in "$aes_key_material" "$audit_hmac_key_material" "$outbound_key_material"; do
    if grep -Fq "$key_material" "$GENERATED_ENV_FILE"; then
        fail "key material must not be stored in the environment file"
    fi
    if grep -Fq "$key_material" "$OUTPUT_FILE"; then
        fail "key material must not be written to bootstrap output"
    fi
done

cp "$AES_KEYRING_FILE" "$FIXTURE_DIR/aes-keyring.before"
cp "$AUDIT_HMAC_KEYRING_FILE" "$FIXTURE_DIR/audit-hmac-keyring.before"
cp "$OUTBOUND_KEYRING_FILE" "$FIXTURE_DIR/outbound-keyring.before"
cp "$GENERATED_ENV_FILE" "$FIXTURE_DIR/env.before"
mv "$OUTBOUND_KEYRING_FILE" "$OUTBOUND_LEGACY_KEYRING_FILE"
rmdir "$OUTBOUND_KEYRING_DIR"
(
    cd "$FIXTURE_DIR"
    ./start-dev-bot.sh --prepare-env-only
) >> "$OUTPUT_FILE"
[ ! -e "$OUTBOUND_LEGACY_KEYRING_FILE" ] \
    || fail "legacy outbound keyring path remained after the owner-only migration"
[ -d "$OUTBOUND_KEYRING_DIR" ] && [ "$(stat -c '%a' "$OUTBOUND_KEYRING_DIR")" = "700" ] \
    || fail "legacy outbound keyring migration did not restore the owner-only source directory"
cmp -s "$FIXTURE_DIR/aes-keyring.before" "$AES_KEYRING_FILE" \
    || fail "a repeated bootstrap rotated the audit AES keyring"
cmp -s "$FIXTURE_DIR/audit-hmac-keyring.before" "$AUDIT_HMAC_KEYRING_FILE" \
    || fail "a repeated bootstrap rotated the audit HMAC keyring"
cmp -s "$FIXTURE_DIR/outbound-keyring.before" "$OUTBOUND_KEYRING_FILE" \
    || fail "a repeated bootstrap rotated the outbound keyring"
cmp -s "$FIXTURE_DIR/env.before" "$GENERATED_ENV_FILE" \
    || fail "a repeated bootstrap changed the generated environment"

sed -i '/^CONTACT_WEBHOOK_TOKEN=/d' "$GENERATED_ENV_FILE"
(
    cd "$FIXTURE_DIR"
    ./start-dev-bot.sh --prepare-env-only
) >> "$OUTPUT_FILE"
[ "$(grep -c '^CONTACT_WEBHOOK_TOKEN=' "$GENERATED_ENV_FILE")" = "1" ] \
    || fail "legacy environment migration did not restore one website contact token"
repaired_contact_webhook_token="$(sed -n 's/^CONTACT_WEBHOOK_TOKEN=//p' "$GENERATED_ENV_FILE")"
[[ "$repaired_contact_webhook_token" =~ ^[0-9a-f]{64}$ ]] \
    || fail "restored website contact token must contain exactly 32 random bytes in hex"
[ "$repaired_contact_webhook_token" != "$contact_webhook_token" ] \
    || fail "restoring the missing website contact token reused its retired value"
[ "$(stat -c '%a' "$GENERATED_ENV_FILE")" = "600" ] \
    || fail "restoring the website contact token must preserve mode 0600"
if grep -Fq "$repaired_contact_webhook_token" "$OUTPUT_FILE"; then
    fail "restored website contact token appeared in bootstrap output"
fi

sed -i '/^KEYCLOAK_DEV_SUPERADMIN_INITIAL_PASSWORD=/d' "$GENERATED_ENV_FILE"
(
    cd "$FIXTURE_DIR"
    ./start-dev-bot.sh --prepare-env-only
) >> "$OUTPUT_FILE"
[ "$(grep -c '^KEYCLOAK_DEV_SUPERADMIN_INITIAL_PASSWORD=' "$GENERATED_ENV_FILE")" = "1" ] \
    || fail "legacy environment migration did not restore one DEV Super Admin initial password"
repaired_dev_superadmin_initial_password="$(sed -n 's/^KEYCLOAK_DEV_SUPERADMIN_INITIAL_PASSWORD=//p' "$GENERATED_ENV_FILE")"
[[ "$repaired_dev_superadmin_initial_password" =~ ^[0-9a-f]{64}$ ]] \
    || fail "restored DEV Super Admin initial password must contain exactly 32 random bytes in hex"
[ "$repaired_dev_superadmin_initial_password" != "$dev_superadmin_initial_password" ] \
    || fail "restoring the missing DEV Super Admin initial password reused its retired value"
[ "$(stat -c '%a' "$GENERATED_ENV_FILE")" = "600" ] \
    || fail "restoring the DEV Super Admin initial password must preserve mode 0600"
for independent_variable in \
    DB_PASSWORD \
    KEYCLOAK_DB_PASSWORD \
    KEYCLOAK_ADMIN_PASSWORD \
    KEYCLOAK_PROVISIONING_CLIENT_SECRET \
    GRAFANA_ADMIN_PASSWORD \
    AUTH_SESSION_SECRET; do
    independent_value="$(sed -n "s/^${independent_variable}=//p" "$GENERATED_ENV_FILE")"
    [ "$repaired_dev_superadmin_initial_password" != "$independent_value" ] \
        || fail "restored DEV Super Admin initial password reused $independent_variable"
done

sed -i \
    -e '/^CONVERSATION_AUDIT_AES_ACTIVE_KEY_ID=/d' \
    -e '/^CONVERSATION_AUDIT_AES_KEYRING_FILE=/d' \
    -e '/^CONVERSATION_AUDIT_HMAC_ACTIVE_KEY_ID=/d' \
    -e '/^CONVERSATION_AUDIT_HMAC_KEYRING_FILE=/d' \
    -e '/^CONVERSATION_OUTBOUND_ATTEMPT_HMAC_ACTIVE_KEY_ID=/d' \
    -e '/^CONVERSATION_OUTBOUND_ATTEMPT_HMAC_KEYRING_FILE=/d' \
    "$GENERATED_ENV_FILE"
(
    cd "$FIXTURE_DIR"
    ./start-dev-bot.sh --prepare-env-only
) >> "$OUTPUT_FILE"
cmp -s "$FIXTURE_DIR/aes-keyring.before" "$AES_KEYRING_FILE" \
    || fail "legacy environment migration rotated the audit AES keyring"
cmp -s "$FIXTURE_DIR/audit-hmac-keyring.before" "$AUDIT_HMAC_KEYRING_FILE" \
    || fail "legacy environment migration rotated the audit HMAC keyring"
cmp -s "$FIXTURE_DIR/outbound-keyring.before" "$OUTBOUND_KEYRING_FILE" \
    || fail "legacy environment migration rotated the outbound keyring"
grep -qx 'CONVERSATION_AUDIT_AES_ACTIVE_KEY_ID=dev-conversation-audit-aes-v1' "$GENERATED_ENV_FILE" \
    || fail "legacy environment migration did not restore the audit AES active key ID"
grep -qx 'CONVERSATION_AUDIT_AES_KEYRING_FILE=/run/saas-secrets/conversation-audit-aes-keyring.json' \
    "$GENERATED_ENV_FILE" \
    || fail "legacy environment migration did not restore the audit AES keyring path"
grep -qx 'CONVERSATION_AUDIT_HMAC_ACTIVE_KEY_ID=dev-conversation-audit-hmac-v1' "$GENERATED_ENV_FILE" \
    || fail "legacy environment migration did not restore the audit HMAC active key ID"
grep -qx 'CONVERSATION_AUDIT_HMAC_KEYRING_FILE=/run/saas-secrets/conversation-audit-hmac-keyring.json' \
    "$GENERATED_ENV_FILE" \
    || fail "legacy environment migration did not restore the audit HMAC keyring path"
grep -qx 'CONVERSATION_OUTBOUND_ATTEMPT_HMAC_ACTIVE_KEY_ID=dev-outbound-v1' "$GENERATED_ENV_FILE" \
    || fail "legacy environment migration did not restore the outbound active key ID"
grep -qx 'CONVERSATION_OUTBOUND_ATTEMPT_HMAC_KEYRING_FILE=/run/saas-secrets/conversation-outbound-attempt-hmac-keyring.json' \
    "$GENERATED_ENV_FILE" \
    || fail "legacy environment migration did not restore the outbound keyring path"

for keyring_file in "$AES_KEYRING_FILE" "$AUDIT_HMAC_KEYRING_FILE" "$OUTBOUND_KEYRING_FILE"; do
    mv "$keyring_file" "$FIXTURE_DIR/keyring.saved"
    if (
        cd "$FIXTURE_DIR"
        ./start-dev-bot.sh --prepare-env-only
    ) >> "$OUTPUT_FILE" 2>&1; then
        fail "bootstrap regenerated a referenced missing keyring"
    fi
    mv "$FIXTURE_DIR/keyring.saved" "$keyring_file"
done

printf '{"keys":{"%s":"%s"}}\n' \
    "$AUDIT_HMAC_KEY_ID" "$aes_key_material" > "$AUDIT_HMAC_KEYRING_FILE"
chmod 600 "$AUDIT_HMAC_KEYRING_FILE"
if (
    cd "$FIXTURE_DIR"
    ./start-dev-bot.sh --prepare-env-only
) >> "$OUTPUT_FILE" 2>&1; then
    fail "bootstrap accepted duplicate material across purpose-specific keyrings"
fi
cp "$FIXTURE_DIR/audit-hmac-keyring.before" "$AUDIT_HMAC_KEYRING_FILE"
chmod 600 "$AUDIT_HMAC_KEYRING_FILE"
