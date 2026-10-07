wait_for_service() {
  local service="$1"
  local require_health="${2:-false}"
  local deadline=$((SECONDS + CFG_WAIT_TIMEOUT))
  local container_id status health

  [[ "$require_health" == true || "$require_health" == false ]] \
    || die "Invalid internal health requirement for $service"
  log "Waiting for $service..."
  while (( SECONDS < deadline )); do
    container_id="$(container_for_service "$service")"
    if [[ -n "$container_id" ]]; then
      status="$(docker inspect --format '{{.State.Status}}' "$container_id" 2>/dev/null || true)"
      health="$(docker inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' "$container_id" 2>/dev/null || true)"
      if [[ "$status" == running && "$health" == healthy ]]; then
        return 0
      fi
      if [[ "$status" == running && "$health" == none && "$require_health" == false ]]; then
        return 0
      fi
      if [[ "$status" == exited || "$health" == unhealthy ]]; then
        "${COMPOSE[@]}" logs --tail 120 "$service" >&2 || true
        die "$service failed (status=$status, health=$health)"
      fi
    fi
    sleep 3
  done
  "${COMPOSE[@]}" logs --tail 120 "$service" >&2 || true
  die "Timed out waiting for $service"
}

psql_query() {
  local service="$1"
  local user="$2"
  local database="$3"
  local sql="$4"
  "${COMPOSE[@]}" exec -T "$service" psql \
    --username "$user" --dbname "$database" \
    --no-align --tuples-only --set=ON_ERROR_STOP=1 --command "$sql"
}

list_cluster_databases() {
  local service="$1"
  local user="$2"
  psql_query "$service" "$user" postgres \
    "SELECT datname FROM pg_database WHERE datallowconn AND NOT datistemplate ORDER BY datname;"
}

cluster_size_bytes() {
  local service="$1"
  local user="$2"
  psql_query "$service" "$user" postgres \
    "SELECT COALESCE(sum(pg_database_size(datname)), 0)::bigint FROM pg_database WHERE datallowconn AND NOT datistemplate;"
}

preflight_backup_capacity() {
  local app_bytes keycloak_bytes total_bytes available_kb required_kb
  app_bytes="$(cluster_size_bytes postgres-app "$CFG_DB_USER")"
  keycloak_bytes="$(cluster_size_bytes postgres-keycloak "$CFG_KEYCLOAK_DB_USER")"
  [[ "$app_bytes" =~ ^[0-9]+$ && "$keycloak_bytes" =~ ^[0-9]+$ ]] \
    || die "Unable to estimate PostgreSQL backup size"
  total_bytes=$((app_bytes + keycloak_bytes))
  available_kb="$(df -Pk -- "$CFG_BACKUP_DIR" | awk 'END {print $4}')"
  [[ "$available_kb" =~ ^[0-9]+$ ]] || die "Unable to determine free backup space"
  # Capacity includes the dump directory and encrypted stream until remote verification.
  required_kb=$((2 * ((total_bytes + 1023) / 1024) + CFG_BACKUP_MIN_FREE_MB * 1024))
  (( available_kb >= required_kb )) \
    || die "Insufficient backup space: require twice the database size plus ${CFG_BACKUP_MIN_FREE_MB} MiB free reserve"
}

dump_cluster() {
  local service="$1"
  local user="$2"
  local prefix="$3"
  local backup_path="$4"
  local database_output database dump_file

  database_output="$(list_cluster_databases "$service" "$user")" \
    || die "Unable to enumerate databases in $service"
  [[ -n "$database_output" ]] || die "No databases found in $service"
  printf '%s\n' "$database_output" >"${backup_path}/${prefix}-databases.txt"

  "${COMPOSE[@]}" exec -T "$service" pg_dumpall \
    --username "$user" --globals-only --no-role-passwords \
    | gzip -9 >"${backup_path}/${prefix}-globals.sql.gz"
  gzip --test "${backup_path}/${prefix}-globals.sql.gz"

  while IFS= read -r database; do
    [[ -n "$database" ]] || continue
    [[ "$database" =~ ^[A-Za-z0-9_-]+$ ]] || die "Unsafe database name returned by PostgreSQL: $database"
    dump_file="${backup_path}/${prefix}-${database}.dump"
    log "Backing up $service/$database"
    "${COMPOSE[@]}" exec -T "$service" pg_dump \
      --username "$user" --dbname "$database" \
      --format=custom --compress=9 --no-owner --no-acl >"$dump_file"
    [[ -s "$dump_file" ]] || die "Empty backup generated for $service/$database"
    "${COMPOSE[@]}" exec -T "$service" pg_restore --list <"$dump_file" >/dev/null
  done <<<"$database_output"
}

snapshot_catalog_into_backup() {
  local backup_path="$1"
  local allow_partial="$2"
  local tenants_table realms_table
  BACKUP_CATALOG_COMPLETE=true
  list_cluster_databases postgres-app "$CFG_DB_USER" \
    | sort -u >"${backup_path}/catalog-app-databases.txt"
  tenants_table="$(psql_query postgres-app "$CFG_DB_USER" saas_tenant \
    "SELECT to_regclass('public.tenants') IS NOT NULL;")"
  realms_table="$(psql_query postgres-keycloak "$CFG_KEYCLOAK_DB_USER" keycloak \
    "SELECT to_regclass('public.realm') IS NOT NULL;")"

  if [[ "$tenants_table" == t ]]; then
    psql_query postgres-app "$CFG_DB_USER" saas_tenant \
      "SELECT id::text || E'\\t' || COALESCE(database_slug, '') FROM tenants ORDER BY id;" \
      | sort -u >"${backup_path}/catalog-tenants.txt"
  elif [[ "$allow_partial" == true ]]; then
    : >"${backup_path}/catalog-tenants.txt"
    BACKUP_CATALOG_COMPLETE=false
  else
    die "The tenant catalog table is absent; refusing a production update backup"
  fi

  if [[ "$realms_table" == t ]]; then
    psql_query postgres-keycloak "$CFG_KEYCLOAK_DB_USER" keycloak \
      "SELECT name FROM realm ORDER BY name;" \
      | sort -u >"${backup_path}/catalog-keycloak-realms.txt"
  elif [[ "$allow_partial" == true ]]; then
    : >"${backup_path}/catalog-keycloak-realms.txt"
    BACKUP_CATALOG_COMPLETE=false
  else
    die "The Keycloak realm table is absent; refusing a production update backup"
  fi
}

create_backup() {
  local allow_partial_catalog="${1:-false}"
  local timestamp backup_path manifest file state_temporary
  preflight_backup_capacity
  timestamp="$(date -u +'%Y%m%dT%H%M%SZ')"
  backup_path="${CFG_BACKUP_DIR}/${timestamp}-pre-deploy"
  [[ ! -e "$backup_path" ]] || backup_path="${backup_path}-$$"
  mkdir -p -- "$backup_path"
  chmod 700 "$backup_path"
  LAST_BACKUP_DIR="$backup_path"
  : >"${backup_path}/.INCOMPLETE"

  dump_cluster postgres-app "$CFG_DB_USER" app "$backup_path"
  dump_cluster postgres-keycloak "$CFG_KEYCLOAK_DB_USER" keycloak "$backup_path"
  snapshot_catalog_into_backup "$backup_path" "$allow_partial_catalog"

  manifest="${backup_path}/MANIFEST"
  {
    printf 'created_at=%s\n' "$(date -u +'%Y-%m-%dT%H:%M:%SZ')"
    printf 'compose_project=%s\n' "$CFG_PROJECT_NAME"
    printf 'domain=%s\n' "$CFG_DOMAIN"
    printf 'catalog_snapshot=%s\n' "$([[ "$BACKUP_CATALOG_COMPLETE" == true ]] && printf complete || printf partial)"
    if command -v git >/dev/null 2>&1; then
      printf 'git_revision=%s\n' "$(git -C "$REPOSITORY_ROOT" rev-parse HEAD 2>/dev/null || printf unknown)"
    fi
  } >"$manifest"

  : >"${backup_path}/SHA256SUMS"
  while IFS= read -r file; do
    (cd "$backup_path" && sha256sum "$(basename "$file")") >>"${backup_path}/SHA256SUMS"
  done < <(find "$backup_path" -maxdepth 1 -type f \
    ! -name SHA256SUMS ! -name .INCOMPLETE -print | sort)
  (cd "$backup_path" && sha256sum --check SHA256SUMS >/dev/null)
  mv -f -- "${backup_path}/.INCOMPLETE" "${backup_path}/COMPLETED"

  state_temporary="$(mktemp "${LAST_BACKUP_STATE_FILE}.tmp.XXXXXX")"
  printf 'backup_path=%s\ncompleted_at=%s\nproject=%s\ndomain=%s\nmin_free_mb=%s\n' \
    "$backup_path" "$(date -u +'%Y-%m-%dT%H:%M:%SZ')" \
    "$CFG_PROJECT_NAME" "$CFG_DOMAIN" "$CFG_BACKUP_MIN_FREE_MB" >"$state_temporary"
  chmod 600 "$state_temporary"
  mv -f -- "$state_temporary" "$LAST_BACKUP_STATE_FILE"

  log "Backup completed and checksummed: $backup_path"
  warn "This snapshot is local until OFFSITE_UPLOAD succeeds; use backup --upload-offsite or the documented timer."
}

validate_offsite_backup_prerequisites() {
  local command_name
  [[ -x "$OFFSITE_BACKUP_SCRIPT" ]] \
    || die "Off-site backup uploader is absent or not executable: $OFFSITE_BACKUP_SCRIPT"
  [[ -f "$OFFSITE_BACKUP_CONFIG" && ! -L "$OFFSITE_BACKUP_CONFIG" ]] \
    || die "Protected off-site backup config is absent: $OFFSITE_BACKUP_CONFIG"
  for command_name in age aws tar jq; do
    require_command "$command_name"
  done
}

upload_last_backup_offsite() {
  local -a uploader_arguments=(
    --config "$OFFSITE_BACKUP_CONFIG"
    --state-file "$LAST_BACKUP_STATE_FILE"
    --deploy-lock-fd 9
  )
  if [[ "$ADOPT_LEGACY_BACKUP_MARKERS" == true ]]; then
    uploader_arguments+=(--adopt-legacy-markers)
  fi
  "$OFFSITE_BACKUP_SCRIPT" "${uploader_arguments[@]}"
}

pending_offsite_backup_path() {
  local pending_path
  [[ -e "$LAST_BACKUP_STATE_FILE" ]] || return 0
  [[ -f "$LAST_BACKUP_STATE_FILE" && ! -L "$LAST_BACKUP_STATE_FILE" ]] \
    || die "Last-backup state is unsafe: $LAST_BACKUP_STATE_FILE"
  pending_path="$(state_value "$LAST_BACKUP_STATE_FILE" backup_path)"
  [[ -n "$pending_path" ]] || die "Last-backup state has no backup_path"
  if [[ -e "$pending_path/.INCOMPLETE" ]]; then
    die "The last backup is incomplete and requires operator inspection: $pending_path"
  fi
  if [[ -f "$pending_path/COMPLETED" && ! -f "$pending_path/OFFSITE_UPLOAD" ]]; then
    printf '%s' "$pending_path"
  fi
}

retry_pending_offsite_backup() {
  local pending_path
  pending_path="$(pending_offsite_backup_path)"
  [[ -n "$pending_path" ]] || return 0
  log "Retrying the pending off-site upload before creating another snapshot: $pending_path"
  upload_last_backup_offsite
}

stop_writers() {
  ORIGINAL_BACKEND_CONTAINER="$(container_for_service backend)"
  ORIGINAL_KEYCLOAK_CONTAINER="$(container_for_service keycloak)"
  WRITERS_STOPPED=true

  if container_is_running "$ORIGINAL_BACKEND_CONTAINER"; then
    "${COMPOSE[@]}" stop --timeout 60 backend
  else
    ORIGINAL_BACKEND_CONTAINER=""
  fi
  if container_is_running "$ORIGINAL_KEYCLOAK_CONTAINER"; then
    "${COMPOSE[@]}" stop --timeout 60 keycloak
  else
    ORIGINAL_KEYCLOAK_CONTAINER=""
  fi
}

restart_original_writers() {
  local failed=false
  [[ "$WRITERS_STOPPED" == true ]] || return 0
  log "Restarting the original writer containers after the consistent snapshot"
  if [[ -n "$ORIGINAL_KEYCLOAK_CONTAINER" ]]; then
    if ! docker start "$ORIGINAL_KEYCLOAK_CONTAINER" >/dev/null; then
      warn "Failed to restart the original Keycloak container"
      failed=true
    elif ! wait_for_existing_container "$ORIGINAL_KEYCLOAK_CONTAINER" keycloak; then
      failed=true
    fi
  fi
  if [[ -n "$ORIGINAL_BACKEND_CONTAINER" ]]; then
    if ! docker start "$ORIGINAL_BACKEND_CONTAINER" >/dev/null; then
      warn "Failed to restart the original backend container"
      failed=true
    elif ! wait_for_existing_container "$ORIGINAL_BACKEND_CONTAINER" backend; then
      failed=true
    fi
  fi
  if [[ "$failed" == false ]]; then
    WRITERS_STOPPED=false
    return 0
  fi
  warn "One or more original writer containers did not recover; immediate operator intervention is required"
  return 1
}

wait_for_existing_container() {
  local container_id="$1"
  local label="$2"
  local deadline=$((SECONDS + CFG_WAIT_TIMEOUT))
  local status health
  while (( SECONDS < deadline )); do
    status="$(docker inspect --format '{{.State.Status}}' "$container_id" 2>/dev/null || true)"
    health="$(docker inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' "$container_id" 2>/dev/null || true)"
    if [[ "$status" == running && ( "$health" == healthy || "$health" == none ) ]]; then
      return 0
    fi
    if [[ "$status" == exited || "$health" == unhealthy ]]; then
      break
    fi
    sleep 3
  done
  docker logs --tail 120 "$container_id" >&2 || true
  warn "$label did not recover (status=${status:-unknown}, health=${health:-unknown})"
  return 1
}

record_release_state() {
  local phase="$1"
  local timestamp="$2"
  local destination="${STATE_DIR}/releases/${timestamp}.${phase}"
  local service container_id
  mkdir -p -- "${STATE_DIR}/releases"
  chmod 700 "${STATE_DIR}/releases"
  {
    printf 'recorded_at=%s\n' "$(date -u +'%Y-%m-%dT%H:%M:%SZ')"
    printf 'git_revision=%s\n' "$(git -C "$REPOSITORY_ROOT" rev-parse HEAD 2>/dev/null || printf unknown)"
    for service in backend frontend keycloak proxy; do
      container_id="$(container_for_service "$service")"
      if [[ -n "$container_id" ]]; then
        printf '%s_container=%s\n' "$service" "$container_id"
        printf '%s_image=%s\n' "$service" \
          "$(docker inspect --format '{{.Image}}' "$container_id" 2>/dev/null || true)"
      fi
    done
  } >"$destination"
  chmod 600 "$destination"
}

pin_backend_image_for_transition() {
  local backend_image_ref initializer_image_ref resolved_image_id temporary

  [[ -n "$EFFECTIVE_COMPOSE_FILE" && -f "$EFFECTIVE_COMPOSE_FILE" ]] \
    || die "Effective Compose model is unavailable for image pinning"
  backend_image_ref="$(jq -er '.services.backend.image' "$EFFECTIVE_COMPOSE_FILE")" \
    || die "Effective Compose model has no backend image reference"
  initializer_image_ref="$(jq -er '.services["outbound-attempt-keyring-init"].image' \
    "$EFFECTIVE_COMPOSE_FILE")" \
    || die "Effective Compose model has no outbound HMAC initializer image reference"
  [[ -n "$backend_image_ref" && "$backend_image_ref" == "$initializer_image_ref" ]] \
    || die "Backend and outbound HMAC initializer must resolve from one image reference"

  # Resolve the mutable reference exactly once after the build. Every later
  # transition command consumes the resulting content-addressed image ID.
  resolved_image_id="$(docker image inspect --format '{{.Id}}' "$backend_image_ref")" \
    || die "Cannot resolve the built backend image identity"
  [[ "$resolved_image_id" =~ ^sha256:[a-f0-9]{64}$ ]] \
    || die "Docker returned an invalid backend image identity"

  PINNED_COMPOSE_FILE="${WORK_DIR}/compose.pinned.json"
  temporary="$(mktemp "${PINNED_COMPOSE_FILE}.tmp.XXXXXX")"
  if ! jq --arg image_id "$resolved_image_id" '
      .services.backend.image = $image_id
      | .services["outbound-attempt-keyring-init"].image = $image_id
    ' "$EFFECTIVE_COMPOSE_FILE" >"$temporary"; then
    rm -f -- "$temporary"
    die "Cannot create the image-pinned Compose model"
  fi
  jq -e --arg image_id "$resolved_image_id" '
      .services.backend.image == $image_id
      and .services["outbound-attempt-keyring-init"].image == $image_id
    ' "$temporary" >/dev/null \
    || die "Image-pinned Compose model does not bind both transition services"
  chmod 400 -- "$temporary"
  mv -f -- "$temporary" "$PINNED_COMPOSE_FILE"
  PINNED_BACKEND_IMAGE_ID="$resolved_image_id"
  use_frozen_compose_model "$PINNED_COMPOSE_FILE"
}

assert_transition_compose_is_pinned() {
  local compose_command=" ${COMPOSE[*]} "

  [[ -n "$PINNED_COMPOSE_FILE" \
      && ! -L "$PINNED_COMPOSE_FILE" \
      && -f "$PINNED_COMPOSE_FILE" \
      && "$(stat -c '%a' -- "$PINNED_COMPOSE_FILE")" == 400 \
      && "$PINNED_BACKEND_IMAGE_ID" =~ ^sha256:[a-f0-9]{64}$ \
      && "$compose_command" == *" --file $PINNED_COMPOSE_FILE "* ]] \
    || die "Release transition requires the immutable image-pinned Compose model"
  jq -e --arg image_id "$PINNED_BACKEND_IMAGE_ID" '
      .services.backend.image == $image_id
      and .services["outbound-attempt-keyring-init"].image == $image_id
    ' "$PINNED_COMPOSE_FILE" >/dev/null \
    || die "Release transition services do not share the pinned image identity"
}

prepare_release_images() {
  local backend_context="${WORK_DIR}/build-context/backend"
  local frontend_context="${WORK_DIR}/build-context/frontend"
  install -d -m 700 "$backend_context" "$frontend_context"

  # Build from Git object contents, never from ignored/untracked VPS files.
  git -C "$REPOSITORY_ROOT" archive --format=tar HEAD:backend \
    | tar --extract --directory "$backend_context"
  git -C "$REPOSITORY_ROOT" archive --format=tar HEAD:frontend \
    | tar --extract --directory "$frontend_context"
  [[ -f "$backend_context/Dockerfile" && -f "$frontend_context/Dockerfile" ]] \
    || die "Cannot materialize production build contexts from the verified Git revision"

  log "Building backend and frontend images from immutable Git contexts before touching running containers"
  "${COMPOSE[@]}" build --pull backend frontend
  pin_backend_image_for_transition
}
