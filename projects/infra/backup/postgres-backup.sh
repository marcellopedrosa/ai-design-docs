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

for command_name in age aws pg_dump pg_dumpall psql sha256sum tar; do
  require_command "$command_name"
done

for variable_name in \
  DB_HOST DB_USER PGPASSWORD BACKUP_AGE_RECIPIENT BACKUP_KMS_KEY_ID BACKUP_S3_URI; do
  require_env "$variable_name"
done

if [[ "$BACKUP_S3_URI" != s3://* ]]; then
  printf 'BACKUP_S3_URI must start with s3://\n' >&2
  exit 1
fi

export PGHOST="$DB_HOST"
export PGPORT="${DB_PORT:-5432}"
export PGUSER="$DB_USER"
export PGCONNECT_TIMEOUT="${PGCONNECT_TIMEOUT:-10}"

timestamp="$(date -u +'%Y%m%dT%H%M%SZ')"
work_dir="$(mktemp -d "${TMPDIR:-/tmp}/saas-backup.XXXXXXXX")"
archive="${work_dir}/saas-postgres-${timestamp}.tar.age"

cleanup() {
  rm -rf -- "$work_dir"
}
trap cleanup EXIT INT TERM

printf 'Creating encrypted PostgreSQL backup at %s\n' "$timestamp"
pg_dumpall --globals-only --no-role-passwords >"${work_dir}/globals.sql"

mapfile -t databases < <(
  psql --dbname=postgres --no-align --tuples-only --set=ON_ERROR_STOP=1 \
    --command="SELECT datname FROM pg_database WHERE datallowconn AND NOT datistemplate ORDER BY datname"
)

if (( ${#databases[@]} == 0 )); then
  printf 'No PostgreSQL databases were found\n' >&2
  exit 1
fi

for database in "${databases[@]}"; do
  if [[ ! "$database" =~ ^[A-Za-z0-9_-]+$ ]]; then
    printf 'Refusing unsafe database name: %s\n' "$database" >&2
    exit 1
  fi
  printf 'Dumping database %s\n' "$database"
  pg_dump --dbname="$database" --format=custom --compress=9 --no-owner --no-acl \
    --file="${work_dir}/${database}.dump"
done

(
  cd "$work_dir"
  sha256sum globals.sql ./*.dump >SHA256SUMS
  printf 'created_at=%s\npostgres_server=%s:%s\ndatabases=%s\n' \
    "$timestamp" "$PGHOST" "$PGPORT" "${databases[*]}" >MANIFEST
  tar --create --file=- MANIFEST SHA256SUMS globals.sql ./*.dump \
    | age --recipient "$BACKUP_AGE_RECIPIENT" --output "$archive"
)

destination="${BACKUP_S3_URI%/}/$(basename "$archive")"
aws s3 cp "$archive" "$destination" \
  --only-show-errors \
  --sse aws:kms \
  --sse-kms-key-id "$BACKUP_KMS_KEY_ID"

printf 'Backup uploaded successfully: %s\n' "$destination"
