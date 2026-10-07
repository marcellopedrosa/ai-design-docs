#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$repo_root"

# The harness owns the generic governance contract. Project-specific checks stay
# here, after the canonical validator, so the wrapper remains fail-closed.
node --test \
  harness/tooling/validators/validate-documentation-governance.test.mjs \
  harness/tooling/validators/validate-quality-metrics.test.mjs \
  harness/tooling/validators/validate-plan-granularity.test.mjs \
  harness/tooling/validators/validate-quality-policy.test.mjs
node harness/tooling/validators/validate-documentation-governance.mjs --root .
node harness/tooling/validators/validate-quality-policy.mjs --root .
bash infra/scripts/tests/validate-quality-gates-test.sh
bash infra/scripts/tests/validate-ip-infra-docs-test.sh
bash infra/scripts/validate-ip-infra-docs.sh
perl infra/scripts/validate-doc-link-labels.pl docs
perl infra/scripts/validate-doc-reference-identifiers.pl docs

printf '%s\n' 'Documentation project validation passed.'
