deploy_stack() {
  local update_mode="$1"
  local proxy_container

  assert_transition_compose_is_pinned

  if [[ "$update_mode" == true ]]; then
    "${COMPOSE[@]}" up -d --no-build --no-recreate postgres-app postgres-keycloak redis
  else
    "${COMPOSE[@]}" up -d --no-build postgres-app postgres-keycloak redis
  fi
  wait_for_service postgres-app
  wait_for_service postgres-keycloak
  wait_for_service redis

  if [[ "$update_mode" == true ]]; then
    "${COMPOSE[@]}" up -d --no-build --no-deps --no-recreate keycloak
  else
    "${COMPOSE[@]}" up -d --no-build --no-deps keycloak
  fi
  wait_for_service keycloak

  log "Validating/provisioning the permanent Keycloak management identity"
  if [[ "$COMMAND" == init ]]; then
    "${COMPOSE[@]}" run --rm --no-deps \
      --env KEYCLOAK_FORCE_RECONCILE=true keycloak-provisioning-init
  else
    "${COMPOSE[@]}" run --rm --no-deps keycloak-provisioning-init
  fi

  # Crossing this boundary before the initializer prevents a signal/trap from
  # restarting the pre-transition writer after the target volume may change.
  ROLLOUT_STARTED=true
  log "Installing the validated outbound-attempt HMAC keyring into its read-only backend volume"
  "${COMPOSE[@]}" run --rm --no-deps outbound-attempt-keyring-init

  # Forced recreation is required even when image/config did not change because
  # the backend loads the installed keyring generation only during startup.
  "${COMPOSE[@]}" up -d --no-build --no-deps --force-recreate backend
  wait_for_service backend true
  OUTBOUND_KEYRING_ACTIVATED=true
  "${COMPOSE[@]}" up -d --no-build --no-deps frontend
  wait_for_service frontend

  # NGINX resolves Docker upstream names when loading its configuration, and a
  # bind-mounted file keeps the inode that existed when the container started.
  # Recreate this stateless service after rendering/replacing upstreams so both
  # the current config inode and the current Docker IPs are loaded.
  "${COMPOSE[@]}" up -d --no-build --no-deps --force-recreate proxy
  wait_for_service proxy
  proxy_container="$(container_for_service proxy)"
  [[ -n "$proxy_container" ]] || die "Proxy container is absent after rollout"
  docker exec "$proxy_container" nginx -t >/dev/null
  docker kill --signal HUP "$proxy_container" >/dev/null
  wait_for_service proxy

  if [[ "$CFG_WITH_MONITORING" == true ]]; then
    "${COMPOSE[@]}" up -d --no-build prometheus alertmanager loki grafana
    wait_for_service prometheus
    wait_for_service alertmanager
    wait_for_service loki
    wait_for_service grafana
  fi

  WRITERS_STOPPED=false
}

assert_file_subset() {
  local before="$1"
  local after="$2"
  local description="$3"
  local missing="${WORK_DIR}/missing-$RANDOM"
  comm -23 "$before" "$after" >"$missing"
  if [[ -s "$missing" ]]; then
    printf '[deploy] Missing %s after rollout:\n' "$description" >&2
    sed 's/^/  - /' "$missing" >&2
    die "Post-deploy preservation check failed for $description"
  fi
}

validate_preserved_catalog() {
  local backup_path="$1"
  local current_dbs="${WORK_DIR}/current-app-databases"
  local current_tenants="${WORK_DIR}/current-tenants"
  local current_realms="${WORK_DIR}/current-keycloak-realms"

  list_cluster_databases postgres-app "$CFG_DB_USER" | sort -u >"$current_dbs"
  psql_query postgres-app "$CFG_DB_USER" saas_tenant \
    "SELECT id::text || E'\\t' || COALESCE(database_slug, '') FROM tenants ORDER BY id;" \
    | sort -u >"$current_tenants"
  psql_query postgres-keycloak "$CFG_KEYCLOAK_DB_USER" keycloak \
    "SELECT name FROM realm ORDER BY name;" | sort -u >"$current_realms"

  assert_file_subset "${backup_path}/catalog-app-databases.txt" "$current_dbs" "application databases"
  assert_file_subset "${backup_path}/catalog-tenants.txt" "$current_tenants" "tenant catalog rows"
  assert_file_subset "${backup_path}/catalog-keycloak-realms.txt" "$current_realms" "Keycloak realms"
}

validate_keycloak_catalog() {
  local realms_actual="${WORK_DIR}/realms-actual"
  local clients_actual="${WORK_DIR}/clients-actual"
  local grants_actual="${WORK_DIR}/provisioning-grants-actual"
  local realm client expected
  local old_ifs="$IFS"

  psql_query postgres-keycloak "$CFG_KEYCLOAK_DB_USER" keycloak \
    "SELECT name FROM realm ORDER BY name;" | sort -u >"$realms_actual"
  psql_query postgres-keycloak "$CFG_KEYCLOAK_DB_USER" keycloak \
    "SELECT r.name || E'\\t' || c.client_id FROM realm r JOIN client c ON c.realm_id = r.id ORDER BY r.name, c.client_id;" \
    | sort -u >"$clients_actual"
  psql_query postgres-keycloak "$CFG_KEYCLOAK_DB_USER" keycloak \
    "SELECT COALESCE(c.client_id, 'realm') || E'\\t' || kr.name FROM user_entity u JOIN realm r ON r.id = u.realm_id JOIN client technical ON technical.id = u.service_account_client_link JOIN user_role_mapping m ON m.user_id = u.id JOIN keycloak_role kr ON kr.id = m.role_id LEFT JOIN client c ON c.id = kr.client WHERE r.name = 'master' AND technical.client_id = '${CFG_PROVISIONING_CLIENT_ID}' ORDER BY 1;" \
    | sort -u >"$grants_actual"

  IFS=',' read -r -a managed_realms <<<"$CFG_MANAGED_REALMS"
  IFS="$old_ifs"
  for realm in "${managed_realms[@]}"; do
    realm="${realm//[[:space:]]/}"
    [[ "$realm" =~ ^saas-[a-z0-9-]+$ ]] || die "Unsafe managed realm name: $realm"
    grep -Fqx "$realm" "$realms_actual" || die "Required Keycloak realm is absent: $realm"
    for client in saas-service-api saas-frontend-spa; do
      expected="${realm}"$'\t'"${client}"
      grep -Fqx "$expected" "$clients_actual" \
        || die "Required Keycloak client is absent: $realm/$client"
    done
    for client in manage-users query-users view-users view-realm; do
      expected="${realm}-realm"$'\t'"${client}"
      grep -Fqx "$expected" "$grants_actual" \
        || die "Keycloak provisioning identity lacks required grant: $expected"
    done
  done
  grep -Fqx "master"$'\t'"${CFG_PROVISIONING_CLIENT_ID}" "$clients_actual" \
    || die "Permanent Keycloak management client is absent"
  grep -Fqx "realm"$'\t'"create-realm" "$grants_actual" \
    || die "Keycloak provisioning identity lacks the create-realm grant"
}

expected_migration_scripts() {
  local context="$1"
  find "${REPOSITORY_ROOT}/backend/app/src/main/resources/db/migration/${context}" \
    -maxdepth 1 -type f -name '*.sql' -printf '%f\n' | sort -u
}

validate_history_table() {
  local database="$1"
  local context="$2"
  local table="flyway_schema_history_${context}"
  local expected="${WORK_DIR}/expected-${database}-${context}"
  local actual="${WORK_DIR}/actual-${database}-${context}"
  local missing="${WORK_DIR}/pending-${database}-${context}"
  local unexpected="${WORK_DIR}/unexpected-${database}-${context}"
  local failed

  expected_migration_scripts "$context" >"$expected"
  [[ -s "$expected" ]] || die "No migration scripts found for context $context"
  psql_query postgres-app "$CFG_DB_USER" "$database" \
    "SELECT script FROM \"${table}\" WHERE success IS TRUE AND type = 'SQL' ORDER BY script;" \
    | sort -u >"$actual" \
    || die "Flyway history table missing/unreadable: $database/$table"
  failed="$(psql_query postgres-app "$CFG_DB_USER" "$database" \
    "SELECT count(*) FROM \"${table}\" WHERE success IS NOT TRUE;")"
  [[ "$failed" == 0 ]] || die "Flyway reports failed rows in $database/$table"
  comm -23 "$expected" "$actual" >"$missing"
  if [[ -s "$missing" ]]; then
    printf '[deploy] Pending migrations in %s/%s:\n' "$database" "$context" >&2
    sed 's/^/  - /' "$missing" >&2
    die "Not every tenant database was migrated"
  fi
  comm -13 "$expected" "$actual" >"$unexpected"
  if [[ -s "$unexpected" ]]; then
    printf '[deploy] Unexpected/removed migration history in %s/%s:\n' "$database" "$context" >&2
    sed 's/^/  - /' "$unexpected" >&2
    die "Database migration history does not exactly match the verified checkout"
  fi
}

validate_tenant_databases_and_flyway() {
  local databases="${WORK_DIR}/app-databases-for-flyway"
  local tenants_output slug database context
  local -a tenant_contexts=(certificate fiscal billing omnichannel client notification dashboard)

  list_cluster_databases postgres-app "$CFG_DB_USER" | sort -u >"$databases"
  validate_history_table saas_tenant tenant
  tenants_output="$(psql_query postgres-app "$CFG_DB_USER" saas_tenant \
    "SELECT database_slug FROM tenants WHERE database_provisioned IS TRUE ORDER BY database_slug;")"

  while IFS= read -r slug; do
    [[ -n "$slug" ]] || continue
    [[ "$slug" =~ ^[a-z0-9][a-z0-9-]{1,49}$ ]] || die "Unsafe/invalid provisioned tenant slug: $slug"
    database="saas_${slug}"
    grep -Fqx "$database" "$databases" \
      || die "Provisioned tenant database is missing: $database (refusing to recreate it empty)"
    for context in "${tenant_contexts[@]}"; do
      validate_history_table "$database" "$context"
    done
  done <<<"$tenants_output"
}

validate_deploy_logs() {
  local logs registry_status ready total
  logs="$("${COMPOSE[@]}" logs --since "$DEPLOY_STARTED_AT" backend 2>&1 || true)"
  if grep -Eq 'Flyway migrate FAILED|Tenant DataSource is unavailable because migration failed|CRITICAL: TenantDatabaseRegistry failed' <<<"$logs"; then
    grep -E 'Flyway migrate FAILED|Tenant DataSource is unavailable because migration failed|CRITICAL: TenantDatabaseRegistry failed' <<<"$logs" >&2
    die "Backend reported a platform/tenant migration failure"
  fi
  registry_status="$(sed -n 's/.*initialized with \([0-9][0-9]*\)\/\([0-9][0-9]*\) ready dedicated tenant.*/\1 \2/p' <<<"$logs" | tail -n 1)"
  if [[ -n "$registry_status" ]]; then
    read -r ready total <<<"$registry_status"
    [[ "$ready" == "$total" ]] || die "Only $ready/$total provisioned tenant databases became ready"
  fi
}

validate_frontend_build_contract() {
  local container_id labels
  container_id="$(container_for_service frontend)"
  [[ -n "$container_id" ]] || die "Frontend container is absent"
  labels="$(docker inspect "$container_id" \
    | jq -c '.[0].Config.Labels // {}')"
  jq -e \
    --arg api "$CFG_API_URL" \
    --arg auth "$CFG_AUTH_URL" \
    --arg realm "$(env_value NEXT_PUBLIC_KEYCLOAK_REALM)" \
    --arg client "$(env_value NEXT_PUBLIC_KEYCLOAK_CLIENT_ID)" '
      .["io.agentefiscal.frontend.public-api-url"] == $api
      and .["io.agentefiscal.frontend.keycloak-url"] == $auth
      and .["io.agentefiscal.frontend.keycloak-realm"] == $realm
      and .["io.agentefiscal.frontend.keycloak-client-id"] == $client
    ' <<<"$labels" >/dev/null \
    || die "Running frontend bundle was not built for the validated production OAuth/domain contract"
}

http_smoke_test() {
  local health issuer public_health public_issuer
  health="$(curl --fail --silent --show-error --max-time 20 \
    --noproxy '*' \
    --resolve "${CFG_API_HOST}:443:127.0.0.1" \
    "${CFG_API_URL}/actuator/health/readiness")" \
    || die "Public API readiness check failed: ${CFG_API_URL}"
  jq -e '.status == "UP"' <<<"$health" >/dev/null \
    || die "Public API readiness status is not UP"

  issuer="$(curl --fail --silent --show-error --max-time 20 \
    --noproxy '*' \
    --resolve "${CFG_AUTH_HOST}:443:127.0.0.1" \
    "${CFG_AUTH_URL}/realms/saas-admin/.well-known/openid-configuration" \
    | jq -r '.issuer // empty')" \
    || die "Public Keycloak discovery check failed"
  [[ "$issuer" == "${CFG_AUTH_URL}/realms/saas-admin" ]] \
    || die "Unexpected public Keycloak issuer: $issuer"

  curl --fail --silent --show-error --max-time 20 \
    --noproxy '*' \
    --resolve "${CFG_AUTH_HOST}:443:127.0.0.1" \
    --get \
    --data-urlencode 'client_id=saas-frontend-spa' \
    --data-urlencode "redirect_uri=${CFG_APP_URL}/" \
    --data-urlencode 'response_type=code' \
    --data-urlencode 'scope=openid' \
    --data-urlencode 'state=production-deploy-smoke' \
    --data-urlencode 'nonce=production-deploy-smoke' \
    --data-urlencode 'code_challenge=AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA' \
    --data-urlencode 'code_challenge_method=S256' \
    --output /dev/null \
    "${CFG_AUTH_URL}/realms/saas-admin/protocol/openid-connect/auth" \
    || die "Local proxy OAuth client/redirect validation failed"

  curl --fail --silent --show-error --location --max-time 20 \
    --noproxy '*' \
    --resolve "${CFG_APP_HOST}:443:127.0.0.1" \
    --output /dev/null "${CFG_APP_URL}/" \
    || die "Public frontend check failed: ${CFG_APP_URL}"

  # Repeat through normal DNS so status cannot pass while public records are
  # absent or point only to a stale deployment elsewhere.
  public_health="$(curl --fail --silent --show-error --max-time 20 \
    --noproxy '*' "${CFG_API_URL}/actuator/health/readiness")" \
    || die "DNS-routed API readiness check failed: ${CFG_API_URL}"
  jq -e '.status == "UP"' <<<"$public_health" >/dev/null \
    || die "DNS-routed API readiness status is not UP"

  public_issuer="$(curl --fail --silent --show-error --max-time 20 \
    --noproxy '*' "${CFG_AUTH_URL}/realms/saas-admin/.well-known/openid-configuration" \
    | jq -r '.issuer // empty')" \
    || die "DNS-routed Keycloak discovery check failed"
  [[ "$public_issuer" == "${CFG_AUTH_URL}/realms/saas-admin" ]] \
    || die "Unexpected DNS-routed Keycloak issuer: $public_issuer"

  curl --fail --silent --show-error --max-time 20 \
    --noproxy '*' \
    --get \
    --data-urlencode 'client_id=saas-frontend-spa' \
    --data-urlencode "redirect_uri=${CFG_APP_URL}/" \
    --data-urlencode 'response_type=code' \
    --data-urlencode 'scope=openid' \
    --data-urlencode 'state=production-deploy-smoke' \
    --data-urlencode 'nonce=production-deploy-smoke' \
    --data-urlencode 'code_challenge=AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA' \
    --data-urlencode 'code_challenge_method=S256' \
    --output /dev/null \
    "${CFG_AUTH_URL}/realms/saas-admin/protocol/openid-connect/auth" \
    || die "DNS-routed OAuth client/redirect validation failed"

  curl --fail --silent --show-error --location --max-time 20 \
    --noproxy '*' --output /dev/null "${CFG_APP_URL}/" \
    || die "DNS-routed frontend check failed: ${CFG_APP_URL}"
}

validate_live_state() {
  wait_for_service postgres-app
  wait_for_service postgres-keycloak
  wait_for_service redis
  wait_for_service keycloak
  wait_for_service backend
  wait_for_service frontend
  wait_for_service proxy
  validate_keycloak_catalog
  validate_tenant_databases_and_flyway
  validate_deploy_logs
  validate_frontend_build_contract
  validate_telegram_backend_egress
  http_smoke_test
}

print_no_super_admin_warning() {
  local count
  count="$(psql_query postgres-keycloak "$CFG_KEYCLOAK_DB_USER" keycloak \
    "SELECT count(DISTINCT u.id) FROM user_entity u JOIN realm r ON r.id = u.realm_id JOIN user_role_mapping m ON m.user_id = u.id JOIN keycloak_role kr ON kr.id = m.role_id WHERE r.name = 'saas-admin' AND kr.name = 'ROLE_SUPER_ADMIN';")"
  if [[ "$count" == 0 ]]; then
    warn "saas-admin has no human user. Provision the first SUPER_ADMIN through the documented controlled Keycloak procedure."
  fi
}
