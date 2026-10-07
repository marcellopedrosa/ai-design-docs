#!/usr/bin/env bash
set -Eeuo pipefail

TEST_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${TEST_SCRIPT_DIR}/../deploy-production.sh"
PRODUCTION_TEMPLATE="${TEST_SCRIPT_DIR}/../../deploy/production.env.example"
PRODUCTION_COMPOSE="${TEST_SCRIPT_DIR}/../../../docker-compose.prd.yml"
BASE_ENV_TEMPLATE="${TEST_SCRIPT_DIR}/../../../.env.example"
HML_COMPOSE="${TEST_SCRIPT_DIR}/../../../docker-compose.hml.yml"
BACKEND_DOCKERFILE="${TEST_SCRIPT_DIR}/../../../backend/app/Dockerfile"
LIFECYCLE_SCRIPT="${TEST_SCRIPT_DIR}/../../../backend/app/docker/outbound-hmac-keyring-lifecycle.sh"
TEST_ROOT="$(mktemp -d)"
TEST_KEYRING="${TEST_ROOT}/conversation-outbound-attempt-hmac-keyring.json"
trap 'rm -rf -- "$TEST_ROOT"' EXIT INT TERM

fail() {
  printf 'deploy-production-v40-config-test: FAIL: %s\n' "$*" >&2
  exit 1
}

validate_billing_mfa_production true true
while read -r global_mfa legacy_contract_mfa; do
  if (validate_billing_mfa_production "$global_mfa" "$legacy_contract_mfa") \
    >/dev/null 2>&1; then
    fail "production Billing MFA validator accepted $global_mfa/$legacy_contract_mfa"
  fi
done <<'EOF'
false true
true false
false false
invalid true
true invalid
EOF

write_valid_keyring() {
  local key_material
  key_material="$(printf '0123456789abcdef0123456789abcdef' | base64 | tr -d '\n')"
  printf '{"keys":{"prd-outbound-v1":"%s"}}\n' "$key_material" >"$TEST_KEYRING"
  chmod 600 "$TEST_KEYRING"
}

expect_keyring_rejected() {
  if validate_outbound_attempt_hmac_keyring_file "$1" prd-outbound-v1; then
    fail "$2"
  fi
}

validate_outbound_dispatch_bound 5m 30s 5s 10s 5s 10s
validate_outbound_reconciliation_flags false false
validate_outbound_reconciliation_flags true true
validate_outbound_attempt_hmac_references \
  prd-outbound-v1 \
  /run/saas-secrets/conversation-outbound-attempt-hmac-keyring.json
write_valid_keyring
validate_outbound_attempt_hmac_keyring_file "$TEST_KEYRING" prd-outbound-v1
chmod 400 "$TEST_KEYRING"
validate_outbound_attempt_hmac_keyring_file "$TEST_KEYRING" prd-outbound-v1
chmod 700 "$TEST_KEYRING"
expect_keyring_rejected "$TEST_KEYRING" 'owner-executable outbound HMAC keyring was accepted'
write_valid_keyring

chmod 755 "$TEST_ROOT"
expect_keyring_rejected "$TEST_KEYRING" 'non-owner-only outbound HMAC keyring directory was accepted'
chmod 700 "$TEST_ROOT"

chmod 644 "$TEST_KEYRING"
expect_keyring_rejected "$TEST_KEYRING" 'group/other-readable outbound HMAC keyring was accepted'
write_valid_keyring

printf '{"keys":{"old":"c2hvcnQ="}}\n' >"$TEST_KEYRING"
chmod 600 "$TEST_KEYRING"
expect_keyring_rejected "$TEST_KEYRING" 'missing active ID and short key material were accepted'

printf '{"keys":{"prd-outbound-v1":"c2hvcnQ="}}\n' >"$TEST_KEYRING"
chmod 600 "$TEST_KEYRING"
expect_keyring_rejected "$TEST_KEYRING" 'non-32-byte outbound HMAC material was accepted'

write_valid_keyring
valid_key_material="$(jq -er '.keys["prd-outbound-v1"]' "$TEST_KEYRING")"
duplicate_encoding="${valid_key_material%??}Z="
[[ "$duplicate_encoding" != "$valid_key_material" ]] \
  || fail 'duplicate-material regression fixture must use distinct Base64 text'
cmp -s \
  <(printf '%s' "$valid_key_material" | base64 --decode) \
  <(printf '%s' "$duplicate_encoding" | base64 --decode) \
  || fail 'duplicate-material regression fixture must decode to identical bytes'
printf '{"keys":{"prd-outbound-v1":"%s","read-old":"%s"}}\n' \
  "$valid_key_material" "$duplicate_encoding" >"$TEST_KEYRING"
chmod 600 "$TEST_KEYRING"
expect_keyring_rejected "$TEST_KEYRING" 'duplicate decoded outbound HMAC key material was accepted'

printf '{not-json}\n' >"$TEST_KEYRING"
chmod 600 "$TEST_KEYRING"
expect_keyring_rejected "$TEST_KEYRING" 'malformed outbound HMAC keyring JSON was accepted'

printf '{"keys":{"prd-outbound-v1":"%s","bad/id":"%s"}}\n' \
  "$valid_key_material" "$valid_key_material" >"$TEST_KEYRING"
chmod 600 "$TEST_KEYRING"
expect_keyring_rejected "$TEST_KEYRING" 'invalid outbound HMAC key ID was accepted'

printf '{"keys":{"prd-outbound-v1":"%s"},"extra":true}\n' "$valid_key_material" >"$TEST_KEYRING"
chmod 600 "$TEST_KEYRING"
expect_keyring_rejected "$TEST_KEYRING" 'outbound HMAC keyring with an extra root field was accepted'

printf '{"keys":{' >"$TEST_KEYRING"
for index in {1..33}; do
  (( index == 1 )) || printf ',' >>"$TEST_KEYRING"
  printf '"key-%s":"%s"' "$index" "$valid_key_material" >>"$TEST_KEYRING"
done
printf '}}\n' >>"$TEST_KEYRING"
chmod 600 "$TEST_KEYRING"
expect_keyring_rejected "$TEST_KEYRING" 'outbound HMAC keyring with more than 32 keys was accepted'

write_valid_keyring
cp "$TEST_KEYRING" "${TEST_ROOT}/regular-copy.json"
ln -s "${TEST_ROOT}/regular-copy.json" "${TEST_ROOT}/symlink-keyring.json"
expect_keyring_rejected "${TEST_ROOT}/symlink-keyring.json" 'symlink outbound HMAC keyring was accepted'

write_valid_keyring
head -c 17000 /dev/zero | tr '\0' ' ' >>"$TEST_KEYRING"
expect_keyring_rejected "$TEST_KEYRING" 'outbound HMAC keyring larger than 16 KiB was accepted'
write_valid_keyring

grep -Fqx \
  'CONVERSATION_OUTBOUND_ATTEMPT_HMAC_ACTIVE_KEY_ID=prd-outbound-v1' \
  "$PRODUCTION_TEMPLATE" \
  || fail 'production template must contain only the opaque outbound HMAC active key ID'
grep -Fqx \
  'CONVERSATION_OUTBOUND_ATTEMPT_HMAC_KEYRING_FILE=/run/saas-secrets/conversation-outbound-attempt-hmac-keyring.json' \
  "$PRODUCTION_TEMPLATE" \
  || fail 'production template must contain the canonical outbound HMAC keyring reference'
grep -Fqx \
  'CONVERSATION_OUTBOUND_ATTEMPT_HMAC_ACTIVE_KEY_ID=example-outbound-v1' \
  "$BASE_ENV_TEMPLATE" \
  || fail 'base example must contain only a non-secret outbound HMAC key ID reference'
grep -Fqx \
  'CONVERSATION_OUTBOUND_ATTEMPT_HMAC_KEYRING_FILE=/run/saas-secrets/conversation-outbound-attempt-hmac-keyring.json' \
  "$BASE_ENV_TEMPLATE" \
  || fail 'base example must contain the canonical outbound HMAC container reference'
grep -Fqx \
  'CONTACT_WEBHOOK_TOKEN=__GENERATE__' \
  "$PRODUCTION_TEMPLATE" \
  || fail 'production template must require a generated website contact token'
grep -Fqx \
  'CONTACT_WEBHOOK_TOKEN=' \
  "$BASE_ENV_TEMPLATE" \
  || fail 'base example must declare the server-only website contact token without a value'
grep -Fqx \
  'APP_SECURITY_RATE_LIMIT_TRUSTED_PROXY_CIDRS=CHANGE_ME' \
  "$PRODUCTION_TEMPLATE" \
  || fail 'production template must require the exact trusted reverse-proxy CIDR'
grep -Fqx \
  'APP_SECURITY_RATE_LIMIT_TRUSTED_PROXY_CIDRS=' \
  "$BASE_ENV_TEMPLATE" \
  || fail 'base example must fail closed until a trusted reverse-proxy CIDR is provisioned'
grep -Fq \
  'WEBSITE_CONTACT_TOKEN: ${CONTACT_WEBHOOK_TOKEN:?CONTACT_WEBHOOK_TOKEN is required}' \
  "${REPOSITORY_ROOT}/docker-compose.yml" \
  || fail 'base Compose must pass the required website contact token only to the backend'
grep -Fqx 'BILLING_SECURITY_SUPER_ADMIN_MFA_ENABLED=true' "$PRODUCTION_TEMPLATE" \
  || fail 'production template must keep global Super Admin Billing MFA enabled'
grep -Fqx 'BILLING_SECURITY_ADMIN_CONTRACT_CONTEXT_MFA_ENABLED=true' "$PRODUCTION_TEMPLATE" \
  || fail 'production template must keep legacy contract Billing MFA enabled'
grep -Fqx 'BILLING_SECURITY_SUPER_ADMIN_MFA_ENABLED=false' "$BASE_ENV_TEMPLATE" \
  || fail 'DEV example must expose the temporary global Super Admin Billing MFA waiver'
grep -Fqx 'BILLING_SECURITY_ADMIN_CONTRACT_CONTEXT_MFA_ENABLED=false' "$BASE_ENV_TEMPLATE" \
  || fail 'DEV example must retain the temporary legacy contract MFA waiver'

grep -Fq \
  'source: ./.deploy/secrets/conversation-outbound-attempt-hmac-keyring.json' \
  "$PRODUCTION_COMPOSE" \
  || fail 'production Compose must bind the fixed ignored host keyring source'
grep -Fq \
  'outbound-attempt-keyring-init:' \
  "$PRODUCTION_COMPOSE" \
  || fail 'production Compose must define the isolated outbound HMAC keyring initializer'

rendered_config="$(
  env -i PATH="$PATH" docker compose \
    --project-name agentefiscal-prd \
    --env-file "$PRODUCTION_TEMPLATE" \
    --file "${REPOSITORY_ROOT}/docker-compose.yml" \
    --file "$PRODUCTION_COMPOSE" \
    config --format json
)" || fail 'production Compose could not be rendered from the explicit example environment'
jq -e '
  .services.backend.environment.BILLING_SECURITY_SUPER_ADMIN_MFA_ENABLED == "true"
  and .services.backend.environment.BILLING_SECURITY_ADMIN_CONTRACT_CONTEXT_MFA_ENABLED == "true"
' <<<"$rendered_config" >/dev/null \
  || fail 'effective production Compose must keep both Billing MFA toggles enabled'
validate_outbound_attempt_hmac_effective_compose \
  "$rendered_config" \
  "$(resolve_repository_path "$OUTBOUND_ATTEMPT_HMAC_KEYRING_SOURCE_RELATIVE")" \
  "$OUTBOUND_ATTEMPT_HMAC_KEYRING_TARGET" \
  "prd-outbound-attempt-keyring" \
  "$(resolve_repository_path "$OUTBOUND_ATTEMPT_HMAC_APPROVAL_SOURCE_RELATIVE")" \
  "/source/conversation-outbound-attempt-hmac-keyring.json" \
  "" \
  || fail 'effective production Compose does not preserve the outbound HMAC keyring boundary'

hml_rendered_config="$(
  env -i \
    PATH="$PATH" \
    CONVERSATION_OUTBOUND_ATTEMPT_HMAC_ACTIVE_KEY_ID=hml-outbound-v1 \
    docker compose \
      --project-name agentefiscal-hml \
      --env-file "$PRODUCTION_TEMPLATE" \
      --file "${REPOSITORY_ROOT}/docker-compose.yml" \
      --file "$HML_COMPOSE" \
      config --format json
)" || fail 'HML Compose could not be rendered with explicit non-secret references'
validate_outbound_attempt_hmac_effective_compose \
  "$hml_rendered_config" \
  "$(resolve_repository_path './.deploy/hml/secrets/outbound-hmac')" \
  "$OUTBOUND_ATTEMPT_HMAC_KEYRING_TARGET" \
  "hml-outbound-attempt-keyring" \
  "$(resolve_repository_path './.deploy/hml/approvals/outbound-hmac')" \
  "/source" \
  "/source" \
  || fail 'effective HML Compose does not preserve the outbound HMAC keyring boundary'
jq -e '
  .services.backend.environment.WEBSITE_CONTACT_TOKEN == "__GENERATE__"
  and .services.backend.environment.APP_SECURITY_RATE_LIMIT_TRUSTED_PROXY_CIDRS == "CHANGE_ME"
  and .services.backend.environment.CONVERSATION_OUTBOUND_ATTEMPT_HMAC_ACTIVE_KEY_ID == "hml-outbound-v1"
  and .services.backend.environment.APP_CONVERSATION_AUDIT_ENABLED == "false"
  and .services.backend.environment.APP_CONVERSATION_AUDIT_API_ENABLED == "false"
  and .services.backend.environment.APP_CONVERSATION_AUDIT_OUTBOUND_RECONCILIATION_ENABLED == "false"
  and .services.backend.environment.APP_CONVERSATION_AUDIT_OUTBOUND_RECONCILIATION_TERMINAL_GAP_DETECTION_ENABLED == "false"
  and .services.backend.environment.BILLING_SECURITY_SUPER_ADMIN_MFA_ENABLED == "true"
  and .services.backend.environment.BILLING_SECURITY_ADMIN_CONTRACT_CONTEXT_MFA_ENABLED == "true"
' <<<"$hml_rendered_config" >/dev/null \
  || fail 'HML must keep audit/provider workers default-off while provisioning the HMAC component'

declare -a broken_compose_filters=(
  '.services.backend.volumes[0].read_only = false'
  '.services.backend.depends_on["outbound-attempt-keyring-init"].condition = "service_started"'
  '.services["outbound-attempt-keyring-init"].network_mode = "bridge"'
  '.services["outbound-attempt-keyring-init"].volumes[0].bind.create_host_path = true'
  '.services["outbound-attempt-keyring-init"].volumes[1].read_only = false'
  '.services["outbound-attempt-keyring-init"].entrypoint = ["/bin/true"]'
  '.services["outbound-attempt-keyring-init"].environment.OUTBOUND_HMAC_ACTIVE_KEY_ID = "drifted-key"'
  '.services["outbound-attempt-keyring-init"].tmpfs = []'
)
for broken_compose_filter in "${broken_compose_filters[@]}"; do
  broken_config="$(jq "$broken_compose_filter" <<<"$rendered_config")"
  if validate_outbound_attempt_hmac_effective_compose \
    "$broken_config" \
    "$(resolve_repository_path "$OUTBOUND_ATTEMPT_HMAC_KEYRING_SOURCE_RELATIVE")" \
    "$OUTBOUND_ATTEMPT_HMAC_KEYRING_TARGET" \
    "prd-outbound-attempt-keyring" \
    "$(resolve_repository_path "$OUTBOUND_ATTEMPT_HMAC_APPROVAL_SOURCE_RELATIVE")" \
    "/source/conversation-outbound-attempt-hmac-keyring.json" \
    ""; then
    fail 'a broken outbound HMAC effective Compose boundary was accepted'
  fi
done

for protected_mapping in \
  'backend|CONVERSATION_OUTBOUND_ATTEMPT_HMAC_ACTIVE_KEY_ID|CONVERSATION_OUTBOUND_ATTEMPT_HMAC_ACTIVE_KEY_ID' \
  'backend|CONVERSATION_OUTBOUND_ATTEMPT_HMAC_KEYRING_FILE|CONVERSATION_OUTBOUND_ATTEMPT_HMAC_KEYRING_FILE' \
  'outbound-attempt-keyring-init|OUTBOUND_HMAC_ACTIVE_KEY_ID|CONVERSATION_OUTBOUND_ATTEMPT_HMAC_ACTIVE_KEY_ID' \
  'backend|WEBSITE_CONTACT_TOKEN|CONTACT_WEBHOOK_TOKEN' \
  'backend|BILLING_SECURITY_SUPER_ADMIN_MFA_ENABLED|BILLING_SECURITY_SUPER_ADMIN_MFA_ENABLED' \
  'backend|BILLING_SECURITY_ADMIN_CONTRACT_CONTEXT_MFA_ENABLED|BILLING_SECURITY_ADMIN_CONTRACT_CONTEXT_MFA_ENABLED'; do
  grep -Fq "\"${protected_mapping}\"" "${TEST_SCRIPT_DIR}/../deploy-production.sh" \
    || fail 'deploy must protect the outbound HMAC ID and file reference from Compose interpolation drift'
done

grep -Fq 'apk add --no-cache libcap jq' "$BACKEND_DOCKERFILE" \
  || fail 'backend runtime image must provide the lifecycle JSON parser'
grep -Fq \
  'docker/outbound-hmac-keyring-lifecycle.sh' \
  "$BACKEND_DOCKERFILE" \
  || fail 'backend runtime image must install the outbound HMAC lifecycle gate'
[ -x "$LIFECYCLE_SCRIPT" ] \
  || fail 'outbound HMAC lifecycle gate must be executable'

deploy_stack_source="$(sed -n '/^deploy_stack() {$/,/^}$/p' \
  "${TEST_SCRIPT_DIR}/../lib/deploy-production/deployment.sh")"
initializer_line="$(grep -nF \
  '"${COMPOSE[@]}" run --rm --no-deps outbound-attempt-keyring-init' \
  <<<"$deploy_stack_source" | cut -d: -f1)"
rollout_line="$(grep -n '^  ROLLOUT_STARTED=true$' \
  <<<"$deploy_stack_source" | cut -d: -f1)"
backend_line="$(grep -nF \
  '"${COMPOSE[@]}" up -d --no-build --no-deps --force-recreate backend' \
  <<<"$deploy_stack_source" | cut -d: -f1)"
backend_health_line="$(grep -n '^  wait_for_service backend true$' \
  <<<"$deploy_stack_source" | cut -d: -f1)"
activated_line="$(grep -n '^  OUTBOUND_KEYRING_ACTIVATED=true$' \
  <<<"$deploy_stack_source" | cut -d: -f1)"
frontend_line="$(grep -nF \
  '"${COMPOSE[@]}" up -d --no-build --no-deps frontend' \
  <<<"$deploy_stack_source" | cut -d: -f1)"
[[ -n "$initializer_line" && -n "$rollout_line" \
    && -n "$backend_line" && -n "$backend_health_line" \
    && -n "$activated_line" && -n "$frontend_line" \
    && 10#$rollout_line -lt 10#$initializer_line \
    && 10#$initializer_line -lt 10#$backend_line \
    && 10#$backend_line -lt 10#$backend_health_line \
    && 10#$backend_health_line -lt 10#$activated_line \
    && 10#$activated_line -lt 10#$frontend_line ]] \
  || fail 'deploy must cross the fail-closed boundary before installing the keyring, then force-recreate a healthy backend before frontend'

cleanup_source="$(sed -n '/^cleanup_on_exit() {$/,/^}$/p' \
  "${TEST_SCRIPT_DIR}/../lib/deploy-production/commands.sh")"
grep -Fq '[[ "$ROLLOUT_STARTED" == true' <<<"$cleanup_source" \
  && grep -Fq '&& "$OUTBOUND_KEYRING_ACTIVATED" == false ]]' <<<"$cleanup_source" \
  && grep -Fq '"${COMPOSE[@]}" stop --timeout 60 proxy' <<<"$cleanup_source" \
  && grep -Fq '"${COMPOSE[@]}" stop --timeout 60 backend' <<<"$cleanup_source" \
  || fail 'deploy must stop stale backend/app/proxy traffic when keyring activation fails before health'

MISSING_HEALTH_LOG="${TEST_ROOT}/missing-health-production.log"
if (
  fake_compose_missing_health() {
    printf '%s\n' "$*" >>"$MISSING_HEALTH_LOG"
    if [[ "$*" == ps\ --all\ --quiet\ * ]]; then
      printf 'fake-%s\n' "${!#}"
    fi
    return 0
  }
  docker() {
    if [[ "${1:-}" == ps ]]; then
      printf '%s\n' fake-service-container
    elif [[ "${1:-}" == inspect && "$*" == *'.State.Status'* ]]; then
      printf '%s\n' running
    elif [[ "${1:-}" == inspect && "$*" == *'.State.Health'* ]]; then
      printf '%s\n' none
    fi
    return 0
  }
  sleep() {
    command sleep 1
  }
  assert_transition_compose_is_pinned() {
    :
  }

  COMPOSE=(fake_compose_missing_health)
  CFG_WAIT_TIMEOUT=1
  COMMAND=update
  ROLLOUT_STARTED=false
  OUTBOUND_KEYRING_ACTIVATED=false
  WRITERS_STOPPED=false
  trap cleanup_on_exit EXIT
  deploy_stack false
); then
  fail 'production deploy accepted a recreated backend without a HEALTHCHECK'
fi
grep -Fq 'stop --timeout 60 proxy' "$MISSING_HEALTH_LOG" \
  && grep -Fq 'stop --timeout 60 backend' "$MISSING_HEALTH_LOG" \
  || fail 'missing backend health did not stop stale production proxy/backend traffic'
if grep -Fq 'up -d --no-build --no-deps frontend' "$MISSING_HEALTH_LOG"; then
  fail 'production deploy started frontend without strict backend health'
fi

if grep -Eq \
  '^CONVERSATION_OUTBOUND_ATTEMPT_HMAC_(ACTIVE_KEY_ID|KEYRING_FILE)=.*(CHANGE_ME|__GENERATE__|base64:)' \
  "$PRODUCTION_TEMPLATE"; then
  fail 'production template must not contain a secret or placeholder outbound HMAC value'
fi
if grep -Eq \
  '^CONVERSATION_OUTBOUND_ATTEMPT_HMAC_(ACTIVE_KEY_ID|KEYRING_FILE)=.*(CHANGE_ME|__GENERATE__|base64:)' \
  "$BASE_ENV_TEMPLATE"; then
  fail 'base example must not contain a secret or placeholder outbound HMAC value'
fi

for invalid_key_id in \
  '' \
  'CHANGE_ME' \
  'contains/slash' \
  'contains whitespace' \
  "$(printf 'a%.0s' {1..65})"; do
  if validate_outbound_attempt_hmac_references \
    "$invalid_key_id" \
    /run/saas-secrets/conversation-outbound-attempt-hmac-keyring.json; then
    fail 'invalid outbound HMAC active key ID was accepted'
  fi
done

for invalid_keyring_reference in \
  'conversation-outbound-attempt-hmac-keyring.json' \
  '/tmp/conversation-outbound-attempt-hmac-keyring.json' \
  '/run/saas-secrets/another-keyring.json' \
  '/run/saas-secrets/../conversation-outbound-attempt-hmac-keyring.json' \
  '/run/saas-secrets/conversation-outbound-attempt-hmac-keyring.txt' \
  '/run/saas-secrets/keyring with whitespace.json'; do
  if validate_outbound_attempt_hmac_references \
    prd-outbound-v1 \
    "$invalid_keyring_reference"; then
    fail 'invalid outbound HMAC keyring reference was accepted'
  fi
done

if validate_outbound_reconciliation_flags false true; then
  printf 'expected terminal gap detection without its parent worker to fail\n' >&2
  exit 1
fi

if validate_outbound_dispatch_bound 60s 30s 5s 10s 5s 10s; then
  printf 'expected an equal fence/provider+margin bound to fail\n' >&2
  exit 1
fi

if validate_outbound_dispatch_bound 70s 30s 20s 20s 5s 10s 5s; then
  printf 'expected the Telegram-dominant insufficient fence to fail\n' >&2
  exit 1
fi

if validate_outbound_dispatch_bound 31m 30s 5s 10s 5s 10s; then
  printf 'expected an out-of-range dispatch fence to fail\n' >&2
  exit 1
fi

SNAPSHOT_CASE_ROOT="${TEST_ROOT}/immutable-inputs"
mkdir -p -- "${SNAPSHOT_CASE_ROOT}/work"
chmod 700 "${SNAPSHOT_CASE_ROOT}" "${SNAPSHOT_CASE_ROOT}/work"
LIVE_ENV_FILE="${SNAPSHOT_CASE_ROOT}/production.env"
LIVE_BASE_COMPOSE="${SNAPSHOT_CASE_ROOT}/compose.base.yaml"
LIVE_PRODUCTION_COMPOSE="${SNAPSHOT_CASE_ROOT}/compose.prd.yaml"
printf 'GENERATION=env-a\n' >"$LIVE_ENV_FILE"
printf 'IMAGE=registry.invalid/backend:a\n' >"$LIVE_BASE_COMPOSE"
printf 'GENERATION=yaml-a\n' >"$LIVE_PRODUCTION_COMPOSE"
chmod 600 "$LIVE_ENV_FILE"
chmod 644 "$LIVE_BASE_COMPOSE" "$LIVE_PRODUCTION_COMPOSE"

(
  WORK_DIR="${SNAPSHOT_CASE_ROOT}/work"
  ENV_FILE="$LIVE_ENV_FILE"
  BASE_COMPOSE_FILE="$LIVE_BASE_COMPOSE"
  PRODUCTION_COMPOSE_FILE="$LIVE_PRODUCTION_COMPOSE"
  capture_deployment_inputs

  for captured_input in \
    "$ENV_SNAPSHOT_FILE" \
    "$BASE_COMPOSE_SNAPSHOT_FILE" \
    "$PRODUCTION_COMPOSE_SNAPSHOT_FILE"; do
    [[ "$(stat -c '%a' -- "$captured_input")" == 400 ]] \
      || fail 'captured env/YAML input must be owner-read-only (0400)'
  done
  [[ "$ENV_FILE" == "$ENV_SNAPSHOT_FILE" \
      && "$BASE_COMPOSE_FILE" == "$BASE_COMPOSE_SNAPSHOT_FILE" \
      && "$PRODUCTION_COMPOSE_FILE" == "$PRODUCTION_COMPOSE_SNAPSHOT_FILE" ]] \
    || fail 'deployment did not switch every parser input to its private snapshot'

  # Adversarial A -> B replacement after capture must not affect rendering.
  printf 'GENERATION=env-b\n' >"$LIVE_ENV_FILE"
  printf 'IMAGE=registry.invalid/backend:b\n' >"$LIVE_BASE_COMPOSE"
  printf 'GENERATION=yaml-b\n' >"$LIVE_PRODUCTION_COMPOSE"
  CFG_PROJECT_NAME=snapshot-regression
  CFG_WITH_MONITORING=false
  configure_compose_command
  compose_source_command=" ${COMPOSE[*]} "
  [[ "$compose_source_command" == *" --env-file $ENV_SNAPSHOT_FILE "* \
      && "$compose_source_command" == *" --file $BASE_COMPOSE_SNAPSHOT_FILE "* \
      && "$compose_source_command" == *" --file $PRODUCTION_COMPOSE_SNAPSHOT_FILE "* \
      && "$compose_source_command" != *" --env-file $LIVE_ENV_FILE "* \
      && "$compose_source_command" != *" --file $LIVE_BASE_COMPOSE "* \
      && "$compose_source_command" != *" --file $LIVE_PRODUCTION_COMPOSE "* ]] \
    || fail 'source Compose command retained a mutable env/YAML path'

  fake_snapshot_compose() {
    local env_path="" base_path="" production_path="" previous=""
    local env_generation base_image yaml_generation
    for argument in "$@"; do
      if [[ "$previous" == --env-file ]]; then
        env_path="$argument"
      elif [[ "$previous" == --file && -z "$base_path" ]]; then
        base_path="$argument"
      elif [[ "$previous" == --file ]]; then
        production_path="$argument"
      fi
      previous="$argument"
    done
    [[ "$*" == *'config --format json'* \
        && -n "$env_path" && -n "$base_path" && -n "$production_path" ]] \
      || return 1
    env_generation="$(sed -n 's/^GENERATION=//p' "$env_path")"
    base_image="$(sed -n 's/^IMAGE=//p' "$base_path")"
    yaml_generation="$(sed -n 's/^GENERATION=//p' "$production_path")"
    jq -n \
      --arg env_generation "$env_generation" \
      --arg image "$base_image" \
      --arg yaml_generation "$yaml_generation" '{
        name: "snapshot-regression",
        services: {
          backend: {
            image: $image,
            environment: {GENERATION: $env_generation}
          },
          "outbound-attempt-keyring-init": {image: $image},
          fixture: {environment: {GENERATION: $yaml_generation}}
        }
      }'
  }
  validate_effective_compose_config() {
    :
  }
  COMPOSE=(
    fake_snapshot_compose
    --env-file "$ENV_FILE"
    --file "$BASE_COMPOSE_FILE"
    --file "$PRODUCTION_COMPOSE_FILE"
  )
  render_effective_compose_snapshot
  jq -e '
    .services.backend.image == "registry.invalid/backend:a"
    and .services.backend.environment.GENERATION == "env-a"
    and .services.fixture.environment.GENERATION == "yaml-a"
  ' "$EFFECTIVE_COMPOSE_FILE" >/dev/null \
    || fail 'effective Compose model changed after live env/YAML A -> B replacement'
  [[ "$(stat -c '%a' -- "$EFFECTIVE_COMPOSE_FILE")" == 400 ]] \
    || fail 'effective Compose model must be owner-read-only (0400)'
  frozen_compose_command=" ${COMPOSE[*]} "
  [[ "$frozen_compose_command" == *" --file $EFFECTIVE_COMPOSE_FILE "* \
      && "$frozen_compose_command" != *' --env-file '* \
      && "$frozen_compose_command" != *"$ENV_SNAPSHOT_FILE"* \
      && "$frozen_compose_command" != *"$BASE_COMPOSE_SNAPSHOT_FILE"* \
      && "$frozen_compose_command" != *"$PRODUCTION_COMPOSE_SNAPSHOT_FILE"* ]] \
    || fail 'post-render Compose commands do not use only the effective model'
)

MUTATION_CASE_ROOT="${TEST_ROOT}/snapshot-mid-acquisition"
mkdir -p -- "$MUTATION_CASE_ROOT"
chmod 700 "$MUTATION_CASE_ROOT"
MUTATING_SOURCE="${MUTATION_CASE_ROOT}/source.env"
MUTATION_LOG="${MUTATION_CASE_ROOT}/capture.log"
printf 'GENERATION=private-generation-a\n' >"$MUTATING_SOURCE"
chmod 600 "$MUTATING_SOURCE"
if (
  snapshot_acquisition_test_hook() {
    printf 'GENERATION=private-generation-b\n' >"$2"
    chmod 600 "$2"
  }
  capture_stable_file_snapshot \
    "$MUTATING_SOURCE" "${MUTATION_CASE_ROOT}/snapshot.env" true "test environment"
) >"$MUTATION_LOG" 2>&1; then
  fail 'input mutation during descriptor-backed acquisition was accepted'
fi
grep -Fq 'source changed while its snapshot was being acquired' "$MUTATION_LOG" \
  || fail 'mid-acquisition mutation did not fail with the fixed safe diagnostic'
if grep -Fq 'private-generation-' "$MUTATION_LOG"; then
  fail 'snapshot acquisition diagnostic leaked protected input content'
fi
[[ ! -e "${MUTATION_CASE_ROOT}/snapshot.env" ]] \
  || fail 'failed snapshot acquisition published a destination file'

PIN_CASE_ROOT="${TEST_ROOT}/image-pin"
PIN_WORK_DIR="${PIN_CASE_ROOT}/work"
PIN_INSPECT_COUNT="${PIN_CASE_ROOT}/inspect.count"
PIN_LOG="${PIN_CASE_ROOT}/pin.log"
mkdir -p -- "$PIN_WORK_DIR"
chmod 700 "$PIN_CASE_ROOT" "$PIN_WORK_DIR"
printf '0\n' >"$PIN_INSPECT_COUNT"
PINNED_IMAGE_A="sha256:$(printf 'a%.0s' {1..64})"
PINNED_IMAGE_B="sha256:$(printf 'b%.0s' {1..64})"
cat >"${PIN_WORK_DIR}/compose.effective.json" <<'EOF'
{
  "name": "image-pin-regression",
  "services": {
    "backend": {"image": "registry.invalid/backend:mutable", "environment": {"SAFE": "value"}},
    "outbound-attempt-keyring-init": {"image": "registry.invalid/backend:mutable"},
    "frontend": {"image": "registry.invalid/frontend:fixed"}
  }
}
EOF
chmod 400 "${PIN_WORK_DIR}/compose.effective.json"
(
  WORK_DIR="$PIN_WORK_DIR"
  EFFECTIVE_COMPOSE_FILE="${PIN_WORK_DIR}/compose.effective.json"
  CFG_PROJECT_NAME=image-pin-regression
  CFG_WITH_MONITORING=false
  docker() {
    local count
    [[ "${1:-}" == image && "${2:-}" == inspect && "${3:-}" == --format ]] \
      || return 1
    count="$(<"$PIN_INSPECT_COUNT")"
    count=$((count + 1))
    printf '%s\n' "$count" >"$PIN_INSPECT_COUNT"
    if (( count == 1 )); then
      printf '%s\n' "$PINNED_IMAGE_A"
    else
      # A mutable tag would resolve to B on a second lookup. The transition
      # must never perform that lookup.
      printf '%s\n' "$PINNED_IMAGE_B"
    fi
  }
  pin_backend_image_for_transition >"$PIN_LOG" 2>&1
  assert_transition_compose_is_pinned
  [[ "$(<"$PIN_INSPECT_COUNT")" == 1 ]] \
    || fail 'mutable backend image reference was resolved more than once'
  jq -e --arg image "$PINNED_IMAGE_A" '
    .services.backend.image == $image
    and .services["outbound-attempt-keyring-init"].image == $image
    and .services.frontend.image == "registry.invalid/frontend:fixed"
    and .services.backend.environment.SAFE == "value"
  ' "$PINNED_COMPOSE_FILE" >/dev/null \
    || fail 'initializer/backend were not bound to the same once-resolved image ID'
  [[ "$(stat -c '%a' -- "$PINNED_COMPOSE_FILE")" == 400 ]] \
    || fail 'image-pinned Compose model must be owner-read-only (0400)'
  pinned_compose_command=" ${COMPOSE[*]} "
  [[ "$pinned_compose_command" == *" --file $PINNED_COMPOSE_FILE "* \
      && "$pinned_compose_command" != *" --file $EFFECTIVE_COMPOSE_FILE "* ]] \
    || fail 'transition commands did not switch exclusively to the pinned model'
)
[[ ! -s "$PIN_LOG" ]] \
  || fail 'successful image pinning emitted a protected reference or identity'

CLEANUP_WORK_DIR="${TEST_ROOT}/cleanup-private-work"
mkdir -p -- "$CLEANUP_WORK_DIR"
chmod 700 "$CLEANUP_WORK_DIR"
printf 'private-snapshot\n' >"${CLEANUP_WORK_DIR}/production.env.snapshot"
chmod 400 "${CLEANUP_WORK_DIR}/production.env.snapshot"
(
  WORK_DIR="$CLEANUP_WORK_DIR"
  COMPOSE=()
  ROLLOUT_STARTED=false
  OUTBOUND_KEYRING_ACTIVATED=false
  WRITERS_STOPPED=false
  cleanup_on_exit
)
[[ ! -e "$CLEANUP_WORK_DIR" ]] \
  || fail 'private deployment snapshots survived invocation cleanup'

main_source="$(sed -n '/^main() {$/,/^}$/p' "${TEST_SCRIPT_DIR}/../deploy-production.sh")"
workspace_line="$(grep -n '^  initialize_invocation_workspace$' <<<"$main_source" | cut -d: -f1)"
capture_line="$(grep -n '^  capture_deployment_inputs$' <<<"$main_source" | cut -d: -f1)"
render_line="$(grep -n '^  render_effective_compose_snapshot$' <<<"$main_source" | cut -d: -f1)"
runtime_line="$(grep -n '^  initialize_runtime$' <<<"$main_source" | cut -d: -f1)"
[[ -n "$workspace_line" && -n "$capture_line" && -n "$render_line" && -n "$runtime_line" \
    && 10#$workspace_line -lt 10#$capture_line \
    && 10#$capture_line -lt 10#$render_line \
    && 10#$render_line -lt 10#$runtime_line ]] \
  || fail 'PRD host lock/workspace must precede immutable input capture and effective rendering'

printf 'deploy-production-v40-config-test: PASS\n'
