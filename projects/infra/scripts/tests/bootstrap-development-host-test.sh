#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
REPOSITORY_ROOT="$(cd -- "$SCRIPT_DIR/../../.." && pwd -P)"
source "$REPOSITORY_ROOT/infra/scripts/tests/bootstrap-development-host/part-01.sh"
source "$REPOSITORY_ROOT/infra/scripts/tests/bootstrap-development-host/part-02.sh"
