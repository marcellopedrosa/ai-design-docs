#!/usr/bin/env bash
set -Eeuo pipefail

umask 077

VERIFY_ONLY=false
WORK_DIR=""
BUNDLE_ROOT=""
declare -a APP_DATABASES=()
declare -a KEYCLOAK_DATABASES=()
declare -a CREATED_CLUSTERS=()
declare -a CREATED_DATABASES=()

usage() {
  cat <<'USAGE'
Usage:
  production-bundle-restore-drill.sh --verify-only
  production-bundle-restore-drill.sh

Common required environment:
  RESTORE_ARCHIVE             Local .tar.age path or s3:// URI
  BACKUP_AGE_IDENTITY         Path to the private age identity

Full restore additionally requires:
  RESTORE_DRILL_CONFIRM_ISOLATED=YES-I-CONFIRM-NON-PRODUCTION
  APP_RESTORE_HOST, APP_RESTORE_USER, APP_RESTORE_PASSWORD
  KEYCLOAK_RESTORE_HOST, KEYCLOAK_RESTORE_USER,
  KEYCLOAK_RESTORE_PASSWORD

The full drill creates temporary databases in two isolated PostgreSQL targets,
restores every dump, validates the restored data, and drops every temporary
database before exiting. It never restores cluster globals.
USAGE
}

die() {
  printf '[restore-drill] ERROR: %s\n' "$*" >&2
  exit 1
}

log() {
  printf '[restore-drill] %s\n' "$*"
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || die "Required command not found: $1"
}

require_env() {
  [[ -n "${!1:-}" ]] || die "Required environment variable is empty: $1"
}

unique_file_value() {
  local file="$1"
  local key="$2"
  awk -F= -v wanted="$key" '
    $1 == wanted {
      found++
      value = substr($0, index($0, "=") + 1)
    }
    END {
      if (found != 1 || value == "") exit 1
      print value
    }
  ' "$file"
}

run_cluster() {
  local cluster="$1"
  shift
  case "$cluster" in
    app)
      env \
        "PGHOST=$APP_RESTORE_HOST" \
        "PGPORT=$APP_RESTORE_PORT" \
        "PGUSER=$APP_RESTORE_USER" \
        "PGPASSWORD=$APP_RESTORE_PASSWORD" \
        "PGCONNECT_TIMEOUT=$PGCONNECT_TIMEOUT" \
        "PGSSLMODE=$APP_RESTORE_SSLMODE" \
        "$@"
      ;;
    keycloak)
      env \
        "PGHOST=$KEYCLOAK_RESTORE_HOST" \
        "PGPORT=$KEYCLOAK_RESTORE_PORT" \
        "PGUSER=$KEYCLOAK_RESTORE_USER" \
        "PGPASSWORD=$KEYCLOAK_RESTORE_PASSWORD" \
        "PGCONNECT_TIMEOUT=$PGCONNECT_TIMEOUT" \
        "PGSSLMODE=$KEYCLOAK_RESTORE_SSLMODE" \
        "$@"
      ;;
    *)
      die "Internal error: unknown restore cluster $cluster"
      ;;
  esac
}

cleanup() {
  local exit_status=$?
  local cleanup_failed=false
  local index cluster database maintenance_database
  trap - EXIT
  set +e

  for ((index=${#CREATED_DATABASES[@]} - 1; index >= 0; index--)); do
    cluster="${CREATED_CLUSTERS[$index]}"
    database="${CREATED_DATABASES[$index]}"
    case "$cluster" in
      app) maintenance_database="$APP_RESTORE_MAINTENANCE_DB" ;;
      keycloak) maintenance_database="$KEYCLOAK_RESTORE_MAINTENANCE_DB" ;;
      *)
        printf '[restore-drill] WARNING: refusing to clean an unknown cluster\n' >&2
        cleanup_failed=true
        continue
        ;;
    esac
    if [[ "$database" != agentefiscal_drill_* ]]; then
      printf '[restore-drill] WARNING: refusing to drop an unexpected database: %s\n' \
        "$database" >&2
      cleanup_failed=true
      continue
    fi
    if ! run_cluster "$cluster" dropdb --if-exists --force \
        --maintenance-db="$maintenance_database" "$database" >/dev/null 2>&1; then
      printf '[restore-drill] WARNING: could not drop temporary database %s/%s\n' \
        "$cluster" "$database" >&2
      cleanup_failed=true
    fi
  done

  if [[ -n "$WORK_DIR" && -d "$WORK_DIR" ]]; then
    rm -rf -- "$WORK_DIR"
  fi
  if [[ "$cleanup_failed" == true && "$exit_status" -eq 0 ]]; then
    exit_status=1
  fi
  exit "$exit_status"
}

trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

case "${1:-}" in
  --verify-only)
    VERIFY_ONLY=true
    shift
    ;;
  --help|-h)
    usage
    exit 0
    ;;
  "") ;;
  *)
    usage >&2
    die "Unsupported argument: $1"
    ;;
esac
(( $# == 0 )) || die "Unexpected positional arguments"

for command_name in age awk cmp comm cp date find gzip id mktemp pg_restore rm sha256sum sort stat tar uniq wc; do
  require_command "$command_name"
done
require_env RESTORE_ARCHIVE
require_env BACKUP_AGE_IDENTITY

[[ -f "$BACKUP_AGE_IDENTITY" && ! -L "$BACKUP_AGE_IDENTITY" ]] \
  || die "BACKUP_AGE_IDENTITY must be a regular file, not a symbolic link"
identity_mode="$(stat -c '%a' "$BACKUP_AGE_IDENTITY")"
identity_mode_value=$((8#$identity_mode))
[[ "$(stat -c '%u' "$BACKUP_AGE_IDENTITY")" == "$(id -u)" \
    && $((identity_mode_value & 077)) -eq 0 ]] \
  || die "BACKUP_AGE_IDENTITY must be owned by the current user and inaccessible to group/others (mode 600)"

WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/agentefiscal-restore.XXXXXXXX")"
encrypted_archive="${WORK_DIR}/production-backup.tar.age"
plain_archive="${WORK_DIR}/production-backup.tar"
extraction_dir="${WORK_DIR}/extracted"
members_file="${WORK_DIR}/archive-members"
verbose_members_file="${WORK_DIR}/archive-members-verbose"
mkdir -m 700 "$extraction_dir"

if [[ "$RESTORE_ARCHIVE" == s3://* ]]; then
  require_command aws
  s3_path="${RESTORE_ARCHIVE#s3://}"
  s3_bucket="${s3_path%%/*}"
  s3_key="${s3_path#*/}"
  [[ -n "$s3_bucket" && -n "$s3_key" && "$s3_key" != "$s3_path" ]] \
    || die "RESTORE_ARCHIVE is not a valid S3 object URI"
  if [[ -n "${RESTORE_ARCHIVE_VERSION_ID:-}" ]]; then
    aws s3api get-object \
      --bucket "$s3_bucket" \
      --key "$s3_key" \
      --version-id "$RESTORE_ARCHIVE_VERSION_ID" \
      "$encrypted_archive" >/dev/null
  else
    aws s3 cp "$RESTORE_ARCHIVE" "$encrypted_archive" --only-show-errors
  fi
else
  [[ -f "$RESTORE_ARCHIVE" && ! -L "$RESTORE_ARCHIVE" ]] \
    || die "RESTORE_ARCHIVE must be a regular file, not a symbolic link"
  cp -- "$RESTORE_ARCHIVE" "$encrypted_archive"
fi
[[ -s "$encrypted_archive" ]] || die "Encrypted backup archive is empty"

log "Decrypting the production backup bundle"
age --decrypt --identity "$BACKUP_AGE_IDENTITY" \
  --output "$plain_archive" "$encrypted_archive"
[[ -s "$plain_archive" ]] || die "Decrypted tar archive is empty"

tar --list --file="$plain_archive" >"$members_file" \
  || die "Decrypted payload is not a readable tar archive"
tar --list --verbose --file="$plain_archive" >"$verbose_members_file" \
  || die "Cannot inspect tar member types"
[[ -s "$members_file" ]] || die "Backup tar archive has no members"

while IFS= read -r verbose_member; do
  case "${verbose_member:0:1}" in
    -|d) ;;
    *) die "Backup tar contains a link or unsupported member type" ;;
  esac
done <"$verbose_members_file"

top_level=""
: >"${WORK_DIR}/normalized-members"
while IFS= read -r member || [[ -n "$member" ]]; do
  [[ -n "$member" && "$member" =~ ^[A-Za-z0-9._/-]+$ ]] \
    || die "Backup tar contains an unsafe member name"
  [[ "$member" != /* && "$member" != *"/../"* \
      && "$member" != ../* && "$member" != */.. && "$member" != ".." ]] \
    || die "Backup tar contains path traversal"
  normalized="${member%/}"
  [[ -n "$normalized" ]] || die "Backup tar contains an empty member name"
  candidate_top="${normalized%%/*}"
  if [[ -z "$top_level" ]]; then
    top_level="$candidate_top"
  fi
  [[ "$candidate_top" == "$top_level" ]] \
    || die "Backup tar must contain exactly one top-level directory"
  if [[ "$normalized" == */* ]]; then
    leaf="${normalized#*/}"
    [[ -n "$leaf" && "$leaf" != */* && "$leaf" =~ ^[A-Za-z0-9._-]+$ ]] \
      || die "Backup tar may contain only flat files below its top-level directory"
  fi
  printf '%s\n' "$normalized" >>"${WORK_DIR}/normalized-members"
done <"$members_file"

[[ "$top_level" =~ ^[0-9]{8}T[0-9]{6}Z-pre-deploy(-[0-9]+)?$ ]] \
  || die "Backup top-level directory does not match the production bundle format"
[[ -z "$(sort "${WORK_DIR}/normalized-members" | uniq -d)" ]] \
  || die "Backup tar contains duplicate member names"

tar --extract --file="$plain_archive" --directory="$extraction_dir" \
  --no-same-owner --no-same-permissions --no-overwrite-dir
BUNDLE_ROOT="${extraction_dir}/${top_level}"
[[ -d "$BUNDLE_ROOT" && ! -L "$BUNDLE_ROOT" ]] \
  || die "Extracted production backup root is unsafe"
[[ -z "$(find "$BUNDLE_ROOT" -mindepth 1 ! -type f -print -quit)" ]] \
  || die "Extracted production backup must contain regular files only"
[[ -f "$BUNDLE_ROOT/COMPLETED" && ! -s "$BUNDLE_ROOT/COMPLETED" ]] \
  || die "Backup is not marked COMPLETED"
[[ ! -e "$BUNDLE_ROOT/.INCOMPLETE" ]] \
  || die "Backup still contains the .INCOMPLETE marker"
for required_file in \
  MANIFEST SHA256SUMS app-databases.txt keycloak-databases.txt \
  app-globals.sql.gz keycloak-globals.sql.gz catalog-app-databases.txt \
  catalog-tenants.txt catalog-keycloak-realms.txt; do
  [[ -f "$BUNDLE_ROOT/$required_file" ]] \
    || die "Required production backup file is absent: $required_file"
done

checksum_line_pattern='^[0-9a-f]{64}  [A-Za-z0-9._-]+$'
: >"${WORK_DIR}/checksummed-files"
while IFS= read -r checksum_line || [[ -n "$checksum_line" ]]; do
  [[ "$checksum_line" =~ $checksum_line_pattern ]] \
    || die "SHA256SUMS contains an unsafe or malformed entry"
  checksummed_file="${checksum_line:66}"
  [[ "$checksummed_file" != SHA256SUMS && "$checksummed_file" != COMPLETED ]] \
    || die "SHA256SUMS contains a forbidden self/marker entry"
  printf '%s\n' "$checksummed_file" >>"${WORK_DIR}/checksummed-files"
done <"$BUNDLE_ROOT/SHA256SUMS"
[[ -s "${WORK_DIR}/checksummed-files" ]] || die "SHA256SUMS has no entries"
[[ -z "$(sort "${WORK_DIR}/checksummed-files" | uniq -d)" ]] \
  || die "SHA256SUMS contains duplicate file entries"

find "$BUNDLE_ROOT" -mindepth 1 -maxdepth 1 -type f \
  ! -name SHA256SUMS ! -name COMPLETED -printf '%f\n' \
  | sort >"${WORK_DIR}/actual-payload-files"
sort "${WORK_DIR}/checksummed-files" >"${WORK_DIR}/expected-payload-files"
[[ -z "$(comm -3 "${WORK_DIR}/expected-payload-files" \
  "${WORK_DIR}/actual-payload-files")" ]] \
  || die "SHA256SUMS does not cover exactly every backup payload file"
(cd "$BUNDLE_ROOT" && sha256sum --check --strict SHA256SUMS >/dev/null) \
  || die "Backup payload checksum validation failed"
gzip --test "$BUNDLE_ROOT/app-globals.sql.gz" \
  || die "Application globals archive is corrupt"
gzip --test "$BUNDLE_ROOT/keycloak-globals.sql.gz" \
  || die "Keycloak globals archive is corrupt"

manifest_project="$(unique_file_value "$BUNDLE_ROOT/MANIFEST" compose_project)" \
  || die "MANIFEST has no unique compose_project"
manifest_domain="$(unique_file_value "$BUNDLE_ROOT/MANIFEST" domain)" \
  || die "MANIFEST has no unique domain"
manifest_created_at="$(unique_file_value "$BUNDLE_ROOT/MANIFEST" created_at)" \
  || die "MANIFEST has no unique created_at"
manifest_catalog_snapshot="$(unique_file_value "$BUNDLE_ROOT/MANIFEST" catalog_snapshot)" \
  || die "MANIFEST has no unique catalog_snapshot"
expected_project="${RESTORE_EXPECTED_PROJECT:-agentefiscal-prd}"
expected_domain="${RESTORE_EXPECTED_DOMAIN:-agentefiscal.com.br}"
[[ "$manifest_project" == "$expected_project" ]] \
  || die "Backup project differs from RESTORE_EXPECTED_PROJECT"
[[ "$manifest_domain" == "$expected_domain" ]] \
  || die "Backup domain differs from RESTORE_EXPECTED_DOMAIN"
[[ "$manifest_created_at" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$ ]] \
  || die "MANIFEST contains an invalid UTC creation time"
[[ "$manifest_catalog_snapshot" == complete ]] \
  || die "A production restore drill requires catalog_snapshot=complete"

load_inventory() {
  local prefix="$1"
  local inventory_file="$2"
  local output_array_name="$3"
  local database dump_file
  local -A seen=()
  local -n output_array="$output_array_name"
  local -a actual_dumps=()
  local actual_dump

  output_array=()
  while IFS= read -r database || [[ -n "$database" ]]; do
    [[ "$database" =~ ^[A-Za-z0-9_][A-Za-z0-9_-]{0,62}$ ]] \
      || die "$inventory_file contains an unsafe or empty database name"
    [[ -z "${seen[$database]+present}" ]] \
      || die "$inventory_file contains a duplicate database: $database"
    seen[$database]=1
    dump_file="$BUNDLE_ROOT/${prefix}-${database}.dump"
    [[ -s "$dump_file" ]] \
      || die "Inventory dump is absent or empty: ${prefix}-${database}.dump"
    pg_restore --list "$dump_file" >/dev/null \
      || die "PostgreSQL custom dump is unreadable: ${prefix}-${database}.dump"
    output_array+=("$database")
  done <"$BUNDLE_ROOT/$inventory_file"
  (( ${#output_array[@]} > 0 )) || die "$inventory_file is empty"

  mapfile -t actual_dumps < <(
    find "$BUNDLE_ROOT" -mindepth 1 -maxdepth 1 -type f \
      -name "${prefix}-*.dump" -printf '%f\n' | sort
  )
  (( ${#actual_dumps[@]} == ${#output_array[@]} )) \
    || die "Dump files do not correspond exactly to $inventory_file"
  for actual_dump in "${actual_dumps[@]}"; do
    database="${actual_dump#${prefix}-}"
    database="${database%.dump}"
    [[ -n "${seen[$database]+present}" ]] \
      || die "Dump file is not declared in $inventory_file: $actual_dump"
  done
}

load_inventory app app-databases.txt APP_DATABASES
load_inventory keycloak keycloak-databases.txt KEYCLOAK_DATABASES
[[ " ${APP_DATABASES[*]} " == *" saas_tenant "* ]] \
  || die "Application inventory does not contain saas_tenant"
[[ " ${KEYCLOAK_DATABASES[*]} " == *" keycloak "* ]] \
  || die "Keycloak inventory does not contain keycloak"

printf '%s\n' "${APP_DATABASES[@]}" | sort -u >"${WORK_DIR}/app-inventory-sorted"
sort -u "$BUNDLE_ROOT/catalog-app-databases.txt" >"${WORK_DIR}/app-catalog-sorted"
[[ "$(wc -l <"${WORK_DIR}/app-inventory-sorted")" \
    == "$(wc -l <"${WORK_DIR}/app-catalog-sorted")" \
    && -z "$(comm -3 "${WORK_DIR}/app-inventory-sorted" "${WORK_DIR}/app-catalog-sorted")" ]] \
  || die "Application database inventory differs from catalog-app-databases.txt"
[[ "$(wc -l <"$BUNDLE_ROOT/catalog-app-databases.txt")" \
    == "$(wc -l <"${WORK_DIR}/app-catalog-sorted")" ]] \
  || die "catalog-app-databases.txt contains duplicates"

while IFS= read -r tenant_catalog_line || [[ -n "$tenant_catalog_line" ]]; do
  [[ "$tenant_catalog_line" =~ ^[A-Za-z0-9-]+$'\t'[A-Za-z0-9_-]*$ ]] \
    || die "catalog-tenants.txt contains an unsafe or malformed row"
done <"$BUNDLE_ROOT/catalog-tenants.txt"
[[ "$(sort "$BUNDLE_ROOT/catalog-tenants.txt" | uniq -d | wc -l)" == 0 ]] \
  || die "catalog-tenants.txt contains duplicates"

while IFS= read -r realm_catalog_line || [[ -n "$realm_catalog_line" ]]; do
  [[ "$realm_catalog_line" =~ ^[A-Za-z0-9._-]+$ ]] \
    || die "catalog-keycloak-realms.txt contains an unsafe or empty realm"
done <"$BUNDLE_ROOT/catalog-keycloak-realms.txt"
[[ -s "$BUNDLE_ROOT/catalog-keycloak-realms.txt" \
    && "$(sort "$BUNDLE_ROOT/catalog-keycloak-realms.txt" | uniq -d | wc -l)" == 0 ]] \
  || die "catalog-keycloak-realms.txt is empty or contains duplicates"

log "Bundle verified: project=${manifest_project}, domain=${manifest_domain}, app_databases=${#APP_DATABASES[@]}, keycloak_databases=${#KEYCLOAK_DATABASES[@]}"
if [[ "$VERIFY_ONLY" == true ]]; then
  log "Verification-only drill completed; no PostgreSQL connection was made"
  exit 0
fi

for command_name in createdb dropdb psql; do
  require_command "$command_name"
done
[[ "${RESTORE_DRILL_CONFIRM_ISOLATED:-}" == YES-I-CONFIRM-NON-PRODUCTION ]] \
  || die "Set RESTORE_DRILL_CONFIRM_ISOLATED=YES-I-CONFIRM-NON-PRODUCTION only for isolated targets"
for variable_name in \
  APP_RESTORE_HOST APP_RESTORE_USER APP_RESTORE_PASSWORD \
  KEYCLOAK_RESTORE_HOST KEYCLOAK_RESTORE_USER KEYCLOAK_RESTORE_PASSWORD; do
  require_env "$variable_name"
done

APP_RESTORE_PORT="${APP_RESTORE_PORT:-5432}"
KEYCLOAK_RESTORE_PORT="${KEYCLOAK_RESTORE_PORT:-5432}"
APP_RESTORE_MAINTENANCE_DB="${APP_RESTORE_MAINTENANCE_DB:-postgres}"
KEYCLOAK_RESTORE_MAINTENANCE_DB="${KEYCLOAK_RESTORE_MAINTENANCE_DB:-postgres}"
APP_RESTORE_SSLMODE="${APP_RESTORE_SSLMODE:-prefer}"
KEYCLOAK_RESTORE_SSLMODE="${KEYCLOAK_RESTORE_SSLMODE:-prefer}"
PGCONNECT_TIMEOUT="${PGCONNECT_TIMEOUT:-10}"

for port in "$APP_RESTORE_PORT" "$KEYCLOAK_RESTORE_PORT"; do
  [[ "$port" =~ ^[0-9]+$ ]] && (( 10#$port >= 1 && 10#$port <= 65535 )) \
    || die "Restore PostgreSQL port is invalid: $port"
done
for identifier in \
  "$APP_RESTORE_USER" "$KEYCLOAK_RESTORE_USER" \
  "$APP_RESTORE_MAINTENANCE_DB" "$KEYCLOAK_RESTORE_MAINTENANCE_DB"; do
  [[ "$identifier" =~ ^[A-Za-z0-9_.-]+$ ]] \
    || die "Restore role/maintenance database contains unsupported characters"
done
for sslmode in "$APP_RESTORE_SSLMODE" "$KEYCLOAK_RESTORE_SSLMODE"; do
  [[ "$sslmode" =~ ^(disable|allow|prefer|require|verify-ca|verify-full)$ ]] \
    || die "Invalid PostgreSQL SSL mode: $sslmode"
done
for host in "$APP_RESTORE_HOST" "$KEYCLOAK_RESTORE_HOST"; do
  [[ "$host" != -* && "$host" != *[[:space:]]* ]] \
    || die "Restore host contains unsupported characters"
  case "${host,,}" in
    agentefiscal.com.br|*.agentefiscal.com.br|postgres-app|postgres-keycloak)
      die "Refusing a host that identifies the production application topology: $host"
      ;;
  esac
done
[[ "$APP_RESTORE_HOST:$APP_RESTORE_PORT" != \
    "$KEYCLOAK_RESTORE_HOST:$KEYCLOAK_RESTORE_PORT" ]] \
  || die "Application and Keycloak drills require separate isolated cluster endpoints"
[[ "$PGCONNECT_TIMEOUT" =~ ^[0-9]+$ ]] && (( 10#$PGCONNECT_TIMEOUT >= 1 )) \
  || die "PGCONNECT_TIMEOUT must be a positive integer"

restore_database() {
  local cluster="$1"
  local prefix="$2"
  local source_database="$3"
  local sequence="$4"
  local maintenance_database temporary_database dump_file table_count realm_table realm_count
  local restored_catalog actual_catalog_file expected_catalog_file

  case "$cluster" in
    app) maintenance_database="$APP_RESTORE_MAINTENANCE_DB" ;;
    keycloak) maintenance_database="$KEYCLOAK_RESTORE_MAINTENANCE_DB" ;;
    *) die "Internal error: invalid cluster in restore_database" ;;
  esac
  printf -v temporary_database 'agentefiscal_drill_%s_%s_%04d_%05d' \
    "$cluster" "$(date -u +'%Y%m%d%H%M%S')" "$sequence" "$$"
  dump_file="$BUNDLE_ROOT/${prefix}-${source_database}.dump"

  log "Restoring ${cluster}/${source_database} into temporary database ${temporary_database}"
  run_cluster "$cluster" createdb \
    --maintenance-db="$maintenance_database" "$temporary_database"
  CREATED_CLUSTERS+=("$cluster")
  CREATED_DATABASES+=("$temporary_database")
  run_cluster "$cluster" pg_restore \
    --dbname="$temporary_database" --exit-on-error --single-transaction \
    --no-owner --no-acl "$dump_file"

  if [[ "$cluster" == app && "$source_database" != postgres ]]; then
    table_count="$(run_cluster app psql --dbname="$temporary_database" \
      --no-align --tuples-only --set=ON_ERROR_STOP=1 \
      --command="SELECT count(*) FROM pg_catalog.pg_tables WHERE schemaname NOT IN ('pg_catalog', 'information_schema');")"
    table_count="${table_count//[[:space:]]/}"
    [[ "$table_count" =~ ^[0-9]+$ ]] && (( table_count > 0 )) \
      || die "Restored application database has no application tables: $source_database"
  fi

  if [[ "$cluster" == app && "$source_database" == saas_tenant ]]; then
    restored_catalog="$(run_cluster app psql --dbname="$temporary_database" \
      --no-align --tuples-only --set=ON_ERROR_STOP=1 \
      --command="SELECT id::text || E'\\t' || COALESCE(database_slug, '') FROM tenants ORDER BY id;")"
    actual_catalog_file="${WORK_DIR}/restored-tenants"
    expected_catalog_file="${WORK_DIR}/expected-tenants"
    : >"$actual_catalog_file"
    [[ -z "$restored_catalog" ]] \
      || printf '%s\n' "$restored_catalog" | sort -u >"$actual_catalog_file"
    sort -u "$BUNDLE_ROOT/catalog-tenants.txt" >"$expected_catalog_file"
    cmp --silent "$expected_catalog_file" "$actual_catalog_file" \
      || die "Restored tenant rows differ from catalog-tenants.txt"
  fi

  if [[ "$cluster" == keycloak && "$source_database" == keycloak ]]; then
    realm_table="$(run_cluster keycloak psql --dbname="$temporary_database" \
      --no-align --tuples-only --set=ON_ERROR_STOP=1 \
      --command="SELECT to_regclass('public.realm') IS NOT NULL;")"
    realm_table="${realm_table//[[:space:]]/}"
    [[ "$realm_table" == t ]] || die "Restored Keycloak database has no public.realm table"
    realm_count="$(run_cluster keycloak psql --dbname="$temporary_database" \
      --no-align --tuples-only --set=ON_ERROR_STOP=1 \
      --command="SELECT count(*) FROM public.realm;")"
    realm_count="${realm_count//[[:space:]]/}"
    [[ "$realm_count" =~ ^[0-9]+$ ]] && (( realm_count > 0 )) \
      || die "Restored Keycloak database contains no realms"
    restored_catalog="$(run_cluster keycloak psql --dbname="$temporary_database" \
      --no-align --tuples-only --set=ON_ERROR_STOP=1 \
      --command="SELECT name FROM public.realm ORDER BY name;")"
    actual_catalog_file="${WORK_DIR}/restored-realms"
    expected_catalog_file="${WORK_DIR}/expected-realms"
    printf '%s\n' "$restored_catalog" | sort -u >"$actual_catalog_file"
    sort -u "$BUNDLE_ROOT/catalog-keycloak-realms.txt" >"$expected_catalog_file"
    cmp --silent "$expected_catalog_file" "$actual_catalog_file" \
      || die "Restored Keycloak realms differ from catalog-keycloak-realms.txt"
  fi
}

sequence=0
for database in "${APP_DATABASES[@]}"; do
  sequence=$((sequence + 1))
  restore_database app app "$database" "$sequence"
done
for database in "${KEYCLOAK_DATABASES[@]}"; do
  sequence=$((sequence + 1))
  restore_database keycloak keycloak "$database" "$sequence"
done

log "Full restore drill succeeded for ${#APP_DATABASES[@]} application databases and ${#KEYCLOAK_DATABASES[@]} Keycloak databases; temporary databases will now be removed"
