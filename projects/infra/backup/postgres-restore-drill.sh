#!/usr/bin/env bash
set -Eeuo pipefail

umask 077

require_command() {
  command -v "$1" >/dev/null 2>&1 || {
    printf 'Required command not found: %s\n' "$1" >&2
    exit 1
  }
}

require_env() {
  if [[ -z "${!1:-}" ]]; then
    printf 'Required environment variable is empty: %s\n' "$1" >&2
    exit 1
  fi
}

for command_name in age createdb dropdb pg_restore psql sha256sum tar; do
  require_command "$command_name"
done

for variable_name in DB_HOST DB_USER PGPASSWORD BACKUP_AGE_IDENTITY RESTORE_ARCHIVE RESTORE_DATABASE; do
  require_env "$variable_name"
done

if [[ ! "$RESTORE_DATABASE" =~ ^[A-Za-z0-9_-]+$ ]]; then
  printf 'RESTORE_DATABASE contains unsupported characters\n' >&2
  exit 1
fi

export PGHOST="$DB_HOST"
export PGPORT="${DB_PORT:-5432}"
export PGUSER="$DB_USER"
export PGCONNECT_TIMEOUT="${PGCONNECT_TIMEOUT:-10}"

work_dir="$(mktemp -d "${TMPDIR:-/tmp}/saas-restore.XXXXXXXX")"
archive="${work_dir}/backup.tar.age"
restore_db="${RESTORE_DATABASE}_restore_$(date -u +'%Y%m%d%H%M%S')"
created_restore_db=false

cleanup() {
  if [[ "$created_restore_db" == true && "$restore_db" == "${RESTORE_DATABASE}_restore_"* ]]; then
    dropdb --if-exists "$restore_db" >/dev/null 2>&1 || true
  fi
  rm -rf -- "$work_dir"
}
trap cleanup EXIT INT TERM

if [[ "$RESTORE_ARCHIVE" == s3://* ]]; then
  require_command aws
  aws s3 cp "$RESTORE_ARCHIVE" "$archive" --only-show-errors
else
  cp -- "$RESTORE_ARCHIVE" "$archive"
fi

age --decrypt --identity "$BACKUP_AGE_IDENTITY" "$archive" \
  | tar --extract --directory="$work_dir" --file=-

(
  cd "$work_dir"
  sha256sum --check SHA256SUMS
)

dump_file="${work_dir}/${RESTORE_DATABASE}.dump"
if [[ ! -f "$dump_file" ]]; then
  printf 'Database dump not present in archive: %s\n' "$RESTORE_DATABASE" >&2
  exit 1
fi

createdb "$restore_db"
created_restore_db=true
pg_restore --dbname="$restore_db" --exit-on-error --no-owner --no-acl "$dump_file"

table_count="$(psql --dbname="$restore_db" --no-align --tuples-only --set=ON_ERROR_STOP=1 \
  --command="SELECT count(*) FROM pg_catalog.pg_tables WHERE schemaname NOT IN ('pg_catalog', 'information_schema')")"
if [[ ! "$table_count" =~ ^[0-9]+$ ]] || (( table_count == 0 )); then
  printf 'Restore validation failed: no application tables found\n' >&2
  exit 1
fi

printf 'Restore drill succeeded for %s with %s application tables\n' "$RESTORE_DATABASE" "$table_count"
