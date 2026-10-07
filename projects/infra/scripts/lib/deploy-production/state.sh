container_for_service() {
  local service="$1"
  local result count
  result="$(docker ps --all --quiet \
    --filter "label=com.docker.compose.project=${CFG_PROJECT_NAME}" \
    --filter "label=com.docker.compose.service=${service}")"
  count="$(printf '%s\n' "$result" | sed '/^$/d' | wc -l | tr -d ' ')"
  (( count <= 1 )) || die "More than one container found for service $service"
  printf '%s' "$result"
}

container_is_running() {
  local container_id="$1"
  [[ -n "$container_id" ]] || return 1
  [[ "$(docker inspect --format '{{.State.Running}}' "$container_id" 2>/dev/null)" == true ]]
}

volume_for_service() {
  local service="$1"
  local container_id mount
  container_id="$(container_for_service "$service")"
  [[ -n "$container_id" ]] || return 1
  mount="$(docker inspect --format '{{range .Mounts}}{{if eq .Destination "/var/lib/postgresql/data"}}{{.Type}} {{.Name}}{{end}}{{end}}' "$container_id")"
  [[ "$mount" == volume\ * ]] || die "$service is not using a named PostgreSQL data volume"
  printf '%s' "${mount#volume }"
}

labeled_volume() {
  local logical_name="$1"
  docker volume ls --quiet \
    --filter "label=com.docker.compose.project=${CFG_PROJECT_NAME}" \
    --filter "label=com.docker.compose.volume=${logical_name}" | head -n 1
}

state_value() {
  local file="$1"
  local key="$2"
  awk -F= -v wanted="$key" '$1 == wanted {sub("^[^=]*=", ""); print; exit}' "$file"
}

write_installation_state() {
  local temporary app_volume keycloak_volume
  app_volume="$(volume_for_service postgres-app)" \
    || die "Unable to resolve the application PostgreSQL volume"
  keycloak_volume="$(volume_for_service postgres-keycloak)" \
    || die "Unable to resolve the Keycloak PostgreSQL volume"
  [[ "$app_volume" != "$keycloak_volume" ]] || die "Application and Keycloak must use different volumes"

  temporary="$(mktemp "${VOLUME_STATE_FILE}.tmp.XXXXXX")"
  printf 'postgres_app=%s\npostgres_keycloak=%s\n' "$app_volume" "$keycloak_volume" >"$temporary"
  chmod 600 "$temporary"
  mv -f -- "$temporary" "$VOLUME_STATE_FILE"
  write_stateful_services_state

  # The installation marker is the commit point and is therefore written last.
  temporary="$(mktemp "${MARKER_FILE}.tmp.XXXXXX")"
  printf 'project=%s\ndomain=%s\npublic_ipv4=%s\npublic_ipv6=%s\ngit_revision=%s\ninstalled_at=%s\n' \
    "$CFG_PROJECT_NAME" "$CFG_DOMAIN" "$CFG_VPS_PUBLIC_IPV4" "$CFG_VPS_PUBLIC_IPV6" \
    "$(git -C "$REPOSITORY_ROOT" rev-parse HEAD)" \
    "$(date -u +'%Y-%m-%dT%H:%M:%SZ')" >"$temporary"
  chmod 600 "$temporary"
  mv -f -- "$temporary" "$MARKER_FILE"
}

verify_installation_state() {
  local expected actual
  [[ -f "$MARKER_FILE" ]] || die "Installation marker is absent; use init for the first deployment"
  [[ -f "$VOLUME_STATE_FILE" ]] || die "Persistent-volume identity file is absent; refusing an unsafe update"
  [[ "$(state_value "$MARKER_FILE" project)" == "$CFG_PROJECT_NAME" ]] \
    || die "Compose project name changed since installation"
  [[ "$(state_value "$MARKER_FILE" domain)" == "$CFG_DOMAIN" ]] \
    || die "Public domain changed; realm/domain migration must be performed explicitly"
  [[ "$(state_value "$MARKER_FILE" public_ipv4)" == "$CFG_VPS_PUBLIC_IPV4" \
      && "$(state_value "$MARKER_FILE" public_ipv6)" == "$CFG_VPS_PUBLIC_IPV6" ]] \
    || die "VPS public address changed; perform an explicit host/DNS migration instead of update"

  expected="$(state_value "$VOLUME_STATE_FILE" postgres_app)"
  actual="$(volume_for_service postgres-app)" || die "Application PostgreSQL container is absent"
  [[ "$actual" == "$expected" ]] || die "Application PostgreSQL volume changed ($expected -> $actual)"
  docker volume inspect "$actual" >/dev/null || die "Application PostgreSQL volume no longer exists"

  expected="$(state_value "$VOLUME_STATE_FILE" postgres_keycloak)"
  actual="$(volume_for_service postgres-keycloak)" || die "Keycloak PostgreSQL container is absent"
  [[ "$actual" == "$expected" ]] || die "Keycloak PostgreSQL volume changed ($expected -> $actual)"
  docker volume inspect "$actual" >/dev/null || die "Keycloak PostgreSQL volume no longer exists"
  verify_stateful_services_state
}

assert_fresh_or_resumable_init() {
  local app_volume keycloak_volume
  [[ ! -f "$MARKER_FILE" ]] || die "Production is already initialized; use update"
  app_volume="$(labeled_volume postgres-app-data)"
  keycloak_volume="$(labeled_volume postgres-kc-data)"
  if [[ -n "$app_volume" || -n "$keycloak_volume" ]]; then
    [[ "$RESUME_INITIALIZATION" == true ]] \
      || die "Persistent volumes already exist without an install marker. Inspect them, then rerun init --resume; they will never be deleted."
    [[ -f "$FINGERPRINT_FILE" && -f "$MIGRATION_MANIFEST_FILE" \
        && -f "$MIGRATION_MANIFEST_DIGEST_FILE" && -f "$KEYCLOAK_BOOTSTRAP_MANIFEST_FILE" ]] \
      || die "These volumes were not created by a recorded init attempt; refusing to adopt or bless unknown production data"
    [[ -n "$(container_for_service postgres-app)" && -n "$(container_for_service postgres-keycloak)" ]] \
      || die "--resume requires both existing PostgreSQL containers; perform a recovery instead of attaching unknown volumes"
    warn "Resuming initialization with existing volumes; an emergency backup will be created before rollout"
  fi
}

fingerprint_value() {
  local key="$1"
  local value="$2"
  printf '%s\0%s' "$key" "$value" | sha256sum | awk '{print $1}'
}

write_immutable_fingerprints() {
  local temporary key
  temporary="$(mktemp "${FINGERPRINT_FILE}.tmp.XXXXXX")"
  for key in "${IMMUTABLE_KEYS[@]}"; do
    printf '%s\t%s\n' "$key" "$(fingerprint_value "$key" "$(env_value "$key")")" >>"$temporary"
  done
  chmod 600 "$temporary"
  mv -f -- "$temporary" "$FINGERPRINT_FILE"
}

verify_immutable_fingerprints() {
  local key expected actual changed=false duplicate
  local expected_keys="${WORK_DIR}/immutable-expected-keys"
  local actual_keys="${WORK_DIR}/immutable-actual-keys"
  [[ -f "$FINGERPRINT_FILE" ]] || die "Immutable-secret fingerprint file is absent; refusing update"
  [[ -s "$FINGERPRINT_FILE" ]] || die "Immutable-secret fingerprint file is empty"
  printf '%s\n' "${IMMUTABLE_KEYS[@]}" | sort >"$expected_keys"
  if ! awk -F '\t' '
      NF != 2 || $1 !~ /^[A-Z][A-Z0-9_]*$/ || length($2) != 64 || $2 ~ /[^0-9a-f]/ { exit 1 }
      { print $1 }
    ' "$FINGERPRINT_FILE" >"$actual_keys"; then
    die "Immutable-secret fingerprint file is malformed"
  fi
  duplicate="$(sort "$actual_keys" | uniq -d | head -n 1)"
  [[ -z "$duplicate" ]] || die "Duplicate immutable fingerprint key: $duplicate"
  sort -o "$actual_keys" "$actual_keys"
  cmp -s "$expected_keys" "$actual_keys" \
    || die "Immutable-secret fingerprint file is incomplete or contains unknown keys"
  while IFS=$'\t' read -r key expected; do
    [[ -n "$key" && -n "$expected" ]] || continue
    actual="$(fingerprint_value "$key" "$(env_value "$key")")"
    if [[ "$actual" != "$expected" ]]; then
      printf '[deploy] immutable value changed: %s\n' "$key" >&2
      changed=true
    fi
  done <"$FINGERPRINT_FILE"
  [[ "$changed" == false ]] \
    || die "Database/encryption identity changed. Use a coordinated credential/key rotation procedure, not update."
}

validate_saved_migration_manifest() {
  local recorded_digest actual_digest duplicate
  local paths="${WORK_DIR}/saved-migration-paths"
  [[ -s "$MIGRATION_MANIFEST_FILE" ]] || die "Migration manifest is absent or empty; refusing update"
  [[ -s "$MIGRATION_MANIFEST_DIGEST_FILE" ]] \
    || die "Migration manifest integrity digest is absent or empty"
  recorded_digest="$(tr -d '[:space:]' <"$MIGRATION_MANIFEST_DIGEST_FILE")"
  [[ ${#recorded_digest} -eq 64 && "$recorded_digest" != *[^0-9a-f]* ]] \
    || die "Migration manifest integrity digest is malformed"
  actual_digest="$(sha256sum "$MIGRATION_MANIFEST_FILE" | awk '{print $1}')"
  [[ "$actual_digest" == "$recorded_digest" ]] \
    || die "Migration manifest integrity check failed; restore the production state backup"
  if ! awk -F '\t' '
      NF != 2 || length($1) != 64 || $1 ~ /[^0-9a-f]/ { exit 1 }
      $2 !~ /^backend\/src\/main\/resources\/db\/migration\/[A-Za-z0-9_-]+\/[A-Za-z0-9_.-]+\.sql$/ { exit 1 }
      { print $2 }
    ' "$MIGRATION_MANIFEST_FILE" >"$paths"; then
    die "Migration manifest contains a malformed hash or unsafe path"
  fi
  duplicate="$(sort "$paths" | uniq -d | head -n 1)"
  [[ -z "$duplicate" ]] || die "Duplicate path in migration manifest: $duplicate"
}

build_migration_manifest() {
  local destination="$1"
  local file relative digest
  : >"$destination"
  while IFS= read -r file; do
    relative="${file#${REPOSITORY_ROOT}/}"
    digest="$(sha256sum "$file" | awk '{print $1}')"
    printf '%s\t%s\n' "$digest" "$relative" >>"$destination"
  done < <(find "${REPOSITORY_ROOT}/backend/app/src/main/resources/db/migration" \
    -type f -name '*.sql' -print | sort)
  [[ -s "$destination" ]] || die "No Flyway migrations found"
}

validate_migration_immutability() {
  local current old_hash path current_hash changed=false
  local old_paths new_paths new_file destructive=false
  validate_saved_migration_manifest
  current="${WORK_DIR}/migrations-current.sha256"
  build_migration_manifest "$current"

  while IFS=$'\t' read -r old_hash path; do
    [[ -n "$path" ]] || continue
    if [[ ! -f "${REPOSITORY_ROOT}/${path}" ]]; then
      printf '[deploy] migration removed: %s\n' "$path" >&2
      changed=true
      continue
    fi
    current_hash="$(sha256sum "${REPOSITORY_ROOT}/${path}" | awk '{print $1}')"
    if [[ "$current_hash" != "$old_hash" ]]; then
      printf '[deploy] migration edited: %s\n' "$path" >&2
      changed=true
    fi
  done <"$MIGRATION_MANIFEST_FILE"
  [[ "$changed" == false ]] || die "Applied migration history is immutable; add a new versioned migration instead"

  old_paths="${WORK_DIR}/migration-old-paths"
  new_paths="${WORK_DIR}/migration-new-paths"
  cut -f2 "$MIGRATION_MANIFEST_FILE" | sort >"$old_paths"
  cut -f2 "$current" | sort >"${new_paths}.all"
  comm -13 "$old_paths" "${new_paths}.all" >"$new_paths"

  while IFS= read -r new_file; do
    [[ -n "$new_file" ]] || continue
    if grep -Eiq '\b(DROP[[:space:]]+(TABLE|COLUMN|DATABASE|SCHEMA|INDEX|CONSTRAINT)|TRUNCATE([[:space:]]+TABLE)?|DELETE[[:space:]]+FROM)\b' \
        "${REPOSITORY_ROOT}/${new_file}"; then
      printf '[deploy] destructive SQL requires approval: %s\n' "$new_file" >&2
      destructive=true
    fi
  done <"$new_paths"
  if [[ "$destructive" == true && "$ALLOW_DESTRUCTIVE_MIGRATIONS" != true ]]; then
    die "Review the backup/retention impact, then rerun with --allow-destructive-migrations"
  fi
}

save_migration_manifest() {
  local temporary digest_temporary
  temporary="$(mktemp "${MIGRATION_MANIFEST_FILE}.tmp.XXXXXX")"
  build_migration_manifest "$temporary"
  chmod 600 "$temporary"
  mv -f -- "$temporary" "$MIGRATION_MANIFEST_FILE"
  digest_temporary="$(mktemp "${MIGRATION_MANIFEST_DIGEST_FILE}.tmp.XXXXXX")"
  sha256sum "$MIGRATION_MANIFEST_FILE" | awk '{print $1}' >"$digest_temporary"
  chmod 600 "$digest_temporary"
  mv -f -- "$digest_temporary" "$MIGRATION_MANIFEST_DIGEST_FILE"
}

build_keycloak_bootstrap_manifest() {
  local destination="$1"
  local file relative
  : >"$destination"
  for file in \
    "${REPOSITORY_ROOT}/infra/keycloak/provision/provision-realms.sh" \
    "${REPOSITORY_ROOT}/infra/keycloak/provision/production.sh"; do
    [[ -f "$file" ]] || die "Keycloak bootstrap file is absent: $file"
    relative="${file#${REPOSITORY_ROOT}/}"
    printf '%s\t%s\n' "$(sha256sum "$file" | awk '{print $1}')" "$relative" >>"$destination"
  done
}

save_keycloak_bootstrap_manifest() {
  local temporary
  temporary="$(mktemp "${KEYCLOAK_BOOTSTRAP_MANIFEST_FILE}.tmp.XXXXXX")"
  build_keycloak_bootstrap_manifest "$temporary"
  chmod 600 "$temporary"
  mv -f -- "$temporary" "$KEYCLOAK_BOOTSTRAP_MANIFEST_FILE"
}

verify_keycloak_bootstrap_manifest() {
  local current
  [[ -f "$KEYCLOAK_BOOTSTRAP_MANIFEST_FILE" ]] \
    || die "Keycloak bootstrap manifest is absent; refusing update"
  current="${WORK_DIR}/keycloak-bootstrap-current.sha256"
  build_keycloak_bootstrap_manifest "$current"
  if ! cmp -s "$KEYCLOAK_BOOTSTRAP_MANIFEST_FILE" "$current"; then
    warn "Persisted realms are reconciled by the reviewed Admin API provisioner."
    die "Keycloak Admin API provisioner changed. Review and apply its idempotent migration before deploying it."
  fi
}

stateful_services_json() {
  "${COMPOSE[@]}" config --format json \
    | jq -cS '{services: (.services | with_entries(select(
        .key == "postgres-app"
        or .key == "postgres-keycloak"
        or .key == "keycloak"
        or .key == "redis"
      )))}'
}

write_stateful_services_state() {
  local temporary service key image config_digest container_id image_id
  temporary="$(mktemp "${STATEFUL_SERVICES_FILE}.tmp.XXXXXX")"
  config_digest="$(stateful_services_json | sha256sum | awk '{print $1}')"
  printf 'config_sha256=%s\n' "$config_digest" >"$temporary"
  for service in postgres-app postgres-keycloak keycloak redis; do
    key="${service//-/_}_image"
    image="$("${COMPOSE[@]}" config --format json \
      | jq -er --arg service "$service" '.services[$service].image')"
    printf '%s=%s\n' "$key" "$image" >>"$temporary"
    container_id="$(container_for_service "$service")"
    [[ -n "$container_id" ]] || die "Stateful service container is absent: $service"
    image_id="$(docker inspect --format '{{.Image}}' "$container_id")"
    [[ "$image_id" =~ ^sha256:[0-9a-f]{64}$ ]] \
      || die "Unable to record immutable image ID for $service"
    printf '%s_image_id=%s\n' "${service//-/_}" "$image_id" >>"$temporary"
  done
  chmod 600 "$temporary"
  mv -f -- "$temporary" "$STATEFUL_SERVICES_FILE"
}

verify_stateful_services_state() {
  local expected actual service key container_id
  [[ -f "$STATEFUL_SERVICES_FILE" ]] \
    || die "Stateful-service baseline is absent; refusing an implicit database/Keycloak upgrade"
  expected="$(state_value "$STATEFUL_SERVICES_FILE" config_sha256)"
  actual="$(stateful_services_json | sha256sum | awk '{print $1}')"
  [[ -n "$expected" && "$actual" == "$expected" ]] \
    || die "PostgreSQL, Keycloak or Redis configuration changed; use a reviewed stateful-upgrade procedure"

  for service in postgres-app postgres-keycloak keycloak redis; do
    key="${service//-/_}_image"
    expected="$(state_value "$STATEFUL_SERVICES_FILE" "$key")"
    container_id="$(container_for_service "$service")"
    [[ -n "$container_id" ]] || die "Stateful service container is absent: $service"
    actual="$(docker inspect --format '{{.Config.Image}}' "$container_id")"
    [[ -n "$expected" && "$actual" == "$expected" ]] \
      || die "$service image changed outside the controlled stateful-upgrade procedure ($expected -> $actual)"
    expected="$(state_value "$STATEFUL_SERVICES_FILE" "${service//-/_}_image_id")"
    actual="$(docker inspect --format '{{.Image}}' "$container_id")"
    [[ "$expected" =~ ^sha256:[0-9a-f]{64}$ && "$actual" == "$expected" ]] \
      || die "$service image bytes changed outside the controlled stateful-upgrade procedure"
  done
}
