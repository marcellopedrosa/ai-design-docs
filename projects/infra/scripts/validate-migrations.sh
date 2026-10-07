#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
backend_dir="${repo_root}/backend"
report="${backend_dir}/target/surefire-reports/TEST-br.com.duoset.saas_service.config.persistence.AllFlywayMigrationsPostgresTest.xml"

if [[ "${1:-}" != "" && "${1:-}" != "--offline" ]] || [[ $# -gt 1 ]]; then
  echo "Usage: $0 [--offline]" >&2
  exit 2
fi

if ! docker info --format '{{.ServerVersion}}' >/dev/null 2>&1; then
  echo "Migration validation requires a working local Docker daemon." >&2
  exit 1
fi

if ! command -v python3 >/dev/null 2>&1; then
  echo "Migration validation requires python3 to inspect the Surefire report." >&2
  exit 1
fi

marker="$(mktemp)"
trap 'rm -f "$marker"' EXIT

maven_args=(-B)
if [[ "${1:-}" == "--offline" ]]; then
  maven_args+=(-o)
fi

(
  cd "$backend_dir"
  ./mvnw "${maven_args[@]}" -Dtest=AllFlywayMigrationsPostgresTest test
)

if [[ ! -f "$report" || ! "$report" -nt "$marker" ]]; then
  echo "Current Surefire migration report is missing: $report" >&2
  exit 1
fi

python3 - "$report" <<'PY'
import sys
import xml.etree.ElementTree as ET

report = ET.parse(sys.argv[1]).getroot()
counts = {name: int(report.attrib.get(name, "0")) for name in ("tests", "errors", "failures", "skipped")}
print("Migration tests:", counts)
if counts["tests"] < 3 or any(counts[name] for name in ("errors", "failures", "skipped")):
    raise SystemExit("Migration validation failed: expected all three PostgreSQL cases with zero errors, failures and skips")
PY
