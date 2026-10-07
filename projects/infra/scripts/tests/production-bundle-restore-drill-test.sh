#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPOSITORY_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"
DRILL="${REPOSITORY_ROOT}/infra/backup/production-bundle-restore-drill.sh"
TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/agentefiscal-restore-test.XXXXXXXX")"

cleanup() {
  rm -rf -- "$TEST_ROOT"
}
trap cleanup EXIT INT TERM

mock_bin="${TEST_ROOT}/bin"
fixture_parent="${TEST_ROOT}/fixture"
fixture_name="20260816T120000Z-pre-deploy"
fixture="${fixture_parent}/${fixture_name}"
identity="${TEST_ROOT}/restore.agekey"
command_log="${TEST_ROOT}/postgres-commands.log"
mkdir -p "$mock_bin" "$fixture"
: >"$identity"
: >"$command_log"
chmod 600 "$identity"

cat >"${mock_bin}/age" <<'MOCK_AGE'
#!/usr/bin/env bash
set -Eeuo pipefail
output=""
input=""
while (( $# > 0 )); do
  case "$1" in
    --decrypt) shift ;;
    --identity) shift 2 ;;
    --output) output="$2"; shift 2 ;;
    *) input="$1"; shift ;;
  esac
done
[[ -n "$output" && -f "$input" ]]
cp -- "$input" "$output"
MOCK_AGE

cat >"${mock_bin}/pg_restore" <<'MOCK_PG_RESTORE'
#!/usr/bin/env bash
set -Eeuo pipefail
: "${FAKE_PG_LOG:?}"
database=""
dump=""
list_only=false
for argument in "$@"; do
  case "$argument" in
    --list) list_only=true ;;
    --dbname=*) database="${argument#*=}" ;;
    *.dump) dump="$argument" ;;
  esac
done
[[ -n "$dump" && -s "$dump" ]]
if [[ "$list_only" == false ]]; then
  [[ -n "$database" ]]
  printf 'restore\t%s\t%s\n' "$(basename "$dump")" "$database" >>"$FAKE_PG_LOG"
  if [[ "${FAKE_PG_FAIL_DUMP:-}" == "$(basename "$dump")" ]]; then
    exit 75
  fi
fi
MOCK_PG_RESTORE

cat >"${mock_bin}/createdb" <<'MOCK_CREATEDB'
#!/usr/bin/env bash
set -Eeuo pipefail
: "${FAKE_PG_LOG:?}"
printf 'create\t%s\t%s\t%s\n' "${PGHOST:?}" "${PGPORT:?}" "${!#}" >>"$FAKE_PG_LOG"
MOCK_CREATEDB

cat >"${mock_bin}/dropdb" <<'MOCK_DROPDB'
#!/usr/bin/env bash
set -Eeuo pipefail
: "${FAKE_PG_LOG:?}"
printf 'drop\t%s\t%s\t%s\n' "${PGHOST:?}" "${PGPORT:?}" "${!#}" >>"$FAKE_PG_LOG"
MOCK_DROPDB

cat >"${mock_bin}/psql" <<'MOCK_PSQL'
#!/usr/bin/env bash
set -Eeuo pipefail
command_text=""
for argument in "$@"; do
  case "$argument" in
    --command=*) command_text="${argument#*=}" ;;
  esac
done
case "$command_text" in
  *"to_regclass('public.realm')"*) printf 't\n' ;;
  *"id::text"*"FROM tenants"*) printf '00000000-0000-0000-0000-000000000001\tacme\n' ;;
  *"SELECT name FROM public.realm"*) printf 'master\nsaas-acme\nsaas-admin\n' ;;
  *"SELECT count(*) FROM public.realm"*) printf '3\n' ;;
  *"FROM pg_catalog.pg_tables"*) printf '7\n' ;;
  *) exit 64 ;;
esac
MOCK_PSQL
chmod 755 "${mock_bin}/age" "${mock_bin}/pg_restore" \
  "${mock_bin}/createdb" "${mock_bin}/dropdb" "${mock_bin}/psql"

printf '%s\n' postgres saas_tenant tenant_acme >"${fixture}/app-databases.txt"
printf '%s\n' postgres keycloak >"${fixture}/keycloak-databases.txt"
printf '%s\n' \
  'created_at=2026-08-16T12:00:00Z' \
  'compose_project=agentefiscal-prd' \
  'domain=agentefiscal.com.br' \
  'catalog_snapshot=complete' \
  'git_revision=0123456789abcdef' >"${fixture}/MANIFEST"
printf '00000000-0000-0000-0000-000000000001\tacme\n' \
  >"${fixture}/catalog-tenants.txt"
printf '%s\n' master saas-acme saas-admin >"${fixture}/catalog-keycloak-realms.txt"
printf '%s\n' postgres saas_tenant tenant_acme >"${fixture}/catalog-app-databases.txt"
for dump in \
  app-postgres.dump app-saas_tenant.dump app-tenant_acme.dump \
  keycloak-postgres.dump keycloak-keycloak.dump; do
  printf 'custom dump payload: %s\n' "$dump" >"${fixture}/${dump}"
done
printf 'app globals\n' | gzip -9 >"${fixture}/app-globals.sql.gz"
printf 'keycloak globals\n' | gzip -9 >"${fixture}/keycloak-globals.sql.gz"
(
  cd "$fixture"
  find . -mindepth 1 -maxdepth 1 -type f ! -name SHA256SUMS -printf '%f\n' \
    | sort \
    | while IFS= read -r file; do sha256sum "$file"; done >SHA256SUMS
)
: >"${fixture}/COMPLETED"

valid_archive="${TEST_ROOT}/${fixture_name}.tar.age"
tar --directory "$fixture_parent" --create --file "$valid_archive" "$fixture_name"

insecure_identity="${TEST_ROOT}/insecure-restore.agekey"
cp -- "$identity" "$insecure_identity"
chmod 644 "$insecure_identity"
if PATH="${mock_bin}:$PATH" FAKE_PG_LOG="$command_log" \
    RESTORE_ARCHIVE="$valid_archive" BACKUP_AGE_IDENTITY="$insecure_identity" \
    "$DRILL" --verify-only >/dev/null 2>&1; then
  printf 'expected an insecure age identity mode to fail\n' >&2
  exit 1
fi

verify_output="$(PATH="${mock_bin}:$PATH" FAKE_PG_LOG="$command_log" \
  RESTORE_ARCHIVE="$valid_archive" BACKUP_AGE_IDENTITY="$identity" \
  "$DRILL" --verify-only)"
[[ "$verify_output" == *"app_databases=3, keycloak_databases=2"* ]]
[[ "$verify_output" == *"no PostgreSQL connection was made"* ]]
[[ ! -s "$command_log" ]]

PATH="${mock_bin}:$PATH" FAKE_PG_LOG="$command_log" \
  RESTORE_ARCHIVE="$valid_archive" BACKUP_AGE_IDENTITY="$identity" \
  RESTORE_DRILL_CONFIRM_ISOLATED=YES-I-CONFIRM-NON-PRODUCTION \
  APP_RESTORE_HOST=app-drill.internal APP_RESTORE_PORT=55432 \
  APP_RESTORE_USER=restore_admin APP_RESTORE_PASSWORD='app test password' \
  KEYCLOAK_RESTORE_HOST=keycloak-drill.internal KEYCLOAK_RESTORE_PORT=55433 \
  KEYCLOAK_RESTORE_USER=restore_admin KEYCLOAK_RESTORE_PASSWORD='keycloak test password' \
  "$DRILL"

[[ "$(awk -F '\t' '$1 == "create" { count++ } END { print count + 0 }' "$command_log")" == 5 ]]
[[ "$(awk -F '\t' '$1 == "restore" { count++ } END { print count + 0 }' "$command_log")" == 5 ]]
[[ "$(awk -F '\t' '$1 == "drop" { count++ } END { print count + 0 }' "$command_log")" == 5 ]]
for dump in \
  app-postgres.dump app-saas_tenant.dump app-tenant_acme.dump \
  keycloak-postgres.dump keycloak-keycloak.dump; do
  [[ "$(awk -F '\t' -v wanted="$dump" '$1 == "restore" && $2 == wanted { count++ } END { print count + 0 }' "$command_log")" == 1 ]]
done

: >"$command_log"
if PATH="${mock_bin}:$PATH" FAKE_PG_LOG="$command_log" \
    FAKE_PG_FAIL_DUMP=keycloak-keycloak.dump \
    RESTORE_ARCHIVE="$valid_archive" BACKUP_AGE_IDENTITY="$identity" \
    RESTORE_DRILL_CONFIRM_ISOLATED=YES-I-CONFIRM-NON-PRODUCTION \
    APP_RESTORE_HOST=app-drill.internal APP_RESTORE_PORT=55432 \
    APP_RESTORE_USER=restore_admin APP_RESTORE_PASSWORD='app test password' \
    KEYCLOAK_RESTORE_HOST=keycloak-drill.internal KEYCLOAK_RESTORE_PORT=55433 \
    KEYCLOAK_RESTORE_USER=restore_admin KEYCLOAK_RESTORE_PASSWORD='keycloak test password' \
    "$DRILL" >/dev/null 2>&1; then
  printf 'expected simulated pg_restore failure\n' >&2
  exit 1
fi
[[ "$(awk -F '\t' '$1 == "create" { count++ } END { print count + 0 }' "$command_log")" == 5 ]]
[[ "$(awk -F '\t' '$1 == "drop" { count++ } END { print count + 0 }' "$command_log")" == 5 ]]

mismatch_parent="${TEST_ROOT}/mismatch"
mismatch_fixture="${mismatch_parent}/${fixture_name}"
mkdir -p "$mismatch_parent"
cp -a -- "$fixture" "$mismatch_fixture"
printf 'undeclared dump\n' >"${mismatch_fixture}/app-undeclared.dump"
(
  cd "$mismatch_fixture"
  find . -mindepth 1 -maxdepth 1 -type f \
    ! -name SHA256SUMS ! -name COMPLETED -printf '%f\n' \
    | sort \
    | while IFS= read -r file; do sha256sum "$file"; done >SHA256SUMS
)
mismatch_archive="${TEST_ROOT}/mismatch.tar.age"
tar --directory "$mismatch_parent" --create --file "$mismatch_archive" "$fixture_name"
if PATH="${mock_bin}:$PATH" FAKE_PG_LOG="$command_log" \
    RESTORE_ARCHIVE="$mismatch_archive" BACKUP_AGE_IDENTITY="$identity" \
    "$DRILL" --verify-only >/dev/null 2>&1; then
  printf 'expected undeclared dump validation to fail\n' >&2
  exit 1
fi

tampered_parent="${TEST_ROOT}/tampered"
tampered_fixture="${tampered_parent}/${fixture_name}"
mkdir -p "$tampered_parent"
cp -a -- "$fixture" "$tampered_fixture"
printf 'tampered payload\n' >>"${tampered_fixture}/app-saas_tenant.dump"
tampered_archive="${TEST_ROOT}/tampered.tar.age"
tar --directory "$tampered_parent" --create --file "$tampered_archive" "$fixture_name"
if PATH="${mock_bin}:$PATH" FAKE_PG_LOG="$command_log" \
    RESTORE_ARCHIVE="$tampered_archive" BACKUP_AGE_IDENTITY="$identity" \
    "$DRILL" --verify-only >/dev/null 2>&1; then
  printf 'expected checksum validation to fail\n' >&2
  exit 1
fi

partial_parent="${TEST_ROOT}/partial"
partial_fixture="${partial_parent}/${fixture_name}"
mkdir -p "$partial_parent"
cp -a -- "$fixture" "$partial_fixture"
sed -i 's/catalog_snapshot=complete/catalog_snapshot=partial/' \
  "${partial_fixture}/MANIFEST"
(
  cd "$partial_fixture"
  find . -mindepth 1 -maxdepth 1 -type f \
    ! -name SHA256SUMS ! -name COMPLETED -printf '%f\n' \
    | sort \
    | while IFS= read -r file; do sha256sum "$file"; done >SHA256SUMS
)
partial_archive="${TEST_ROOT}/partial.tar.age"
tar --directory "$partial_parent" --create --file "$partial_archive" "$fixture_name"
if PATH="${mock_bin}:$PATH" FAKE_PG_LOG="$command_log" \
    RESTORE_ARCHIVE="$partial_archive" BACKUP_AGE_IDENTITY="$identity" \
    "$DRILL" --verify-only >/dev/null 2>&1; then
  printf 'expected a partial catalog snapshot to fail\n' >&2
  exit 1
fi

catalog_mismatch_parent="${TEST_ROOT}/catalog-mismatch"
catalog_mismatch_fixture="${catalog_mismatch_parent}/${fixture_name}"
mkdir -p "$catalog_mismatch_parent"
cp -a -- "$fixture" "$catalog_mismatch_fixture"
printf '%s\n' master saas-admin saas-missing \
  >"${catalog_mismatch_fixture}/catalog-keycloak-realms.txt"
(
  cd "$catalog_mismatch_fixture"
  find . -mindepth 1 -maxdepth 1 -type f \
    ! -name SHA256SUMS ! -name COMPLETED -printf '%f\n' \
    | sort \
    | while IFS= read -r file; do sha256sum "$file"; done >SHA256SUMS
)
catalog_mismatch_archive="${TEST_ROOT}/catalog-mismatch.tar.age"
tar --directory "$catalog_mismatch_parent" --create \
  --file "$catalog_mismatch_archive" "$fixture_name"
if PATH="${mock_bin}:$PATH" FAKE_PG_LOG="$command_log" \
    RESTORE_ARCHIVE="$catalog_mismatch_archive" BACKUP_AGE_IDENTITY="$identity" \
    RESTORE_DRILL_CONFIRM_ISOLATED=YES-I-CONFIRM-NON-PRODUCTION \
    APP_RESTORE_HOST=app-drill.internal APP_RESTORE_PORT=55432 \
    APP_RESTORE_USER=restore_admin APP_RESTORE_PASSWORD='app test password' \
    KEYCLOAK_RESTORE_HOST=keycloak-drill.internal KEYCLOAK_RESTORE_PORT=55433 \
    KEYCLOAK_RESTORE_USER=restore_admin KEYCLOAK_RESTORE_PASSWORD='keycloak test password' \
    "$DRILL" >/dev/null 2>&1; then
  printf 'expected a restored realm catalog mismatch to fail\n' >&2
  exit 1
fi

printf 'production-bundle-restore-drill-test: PASS\n'
