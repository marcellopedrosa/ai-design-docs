#!/usr/bin/env bash

set -Eeuo pipefail

REPOSITORY_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
source "$REPOSITORY_ROOT/infra/scripts/tests/start-dev-bot-outbound-keyring/part-01.sh"
source "$REPOSITORY_ROOT/infra/scripts/tests/start-dev-bot-outbound-keyring/part-02.sh"
source "$REPOSITORY_ROOT/infra/scripts/tests/start-dev-bot-outbound-keyring/part-03.sh"
source "$REPOSITORY_ROOT/infra/scripts/tests/start-dev-bot-outbound-keyring/part-04.sh"
source "$REPOSITORY_ROOT/infra/scripts/tests/start-dev-bot-outbound-keyring/part-05.sh"
source "$REPOSITORY_ROOT/infra/scripts/tests/start-dev-bot-outbound-keyring/part-06.sh"
