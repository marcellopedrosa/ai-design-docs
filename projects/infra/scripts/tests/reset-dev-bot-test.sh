#!/usr/bin/env bash

set -Eeuo pipefail

REPOSITORY_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
source "$REPOSITORY_ROOT/infra/scripts/tests/reset-dev-bot-global-contract.sh"
