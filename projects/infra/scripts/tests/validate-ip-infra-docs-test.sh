#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VALIDATOR="${SCRIPT_DIR}/../validate-ip-infra-docs.sh"
TEST_SEED="${BASHPID:-$$}"
VALID_THREE="IP-INFRA-${TEST_SEED}.${TEST_SEED}.${TEST_SEED}-sample-plan.md"
VALID_FOUR="IP-INFRA-${TEST_SEED}.${TEST_SEED}.${TEST_SEED}.${TEST_SEED}-sample-plan.md"
VALID_STEM="${VALID_THREE%.md}"

expect_name_ok() {
  if ! bash "${VALIDATOR}" --check-name "$1"; then
    printf 'Expected valid IP-INFRA name: %s\n' "$1" >&2
    exit 1
  fi
}

expect_name_rejected() {
  if bash "${VALIDATOR}" --check-name "$1"; then
    printf 'Expected rejected IP-INFRA name: %s\n' "$1" >&2
    exit 1
  fi
}

expect_name_ok "${VALID_THREE}"
expect_name_ok "${VALID_FOUR}"
expect_name_rejected "IP-INFRA-${TEST_SEED}.${TEST_SEED}-missing-component.md"
expect_name_rejected "IP-INFRA-${TEST_SEED}.${TEST_SEED}.${TEST_SEED}-Uppercase.md"
expect_name_rejected "IP-INFRA-${TEST_SEED}.${TEST_SEED}.${TEST_SEED}--double-separator.md"
expect_name_rejected "IP-INFRA-${TEST_SEED}.${TEST_SEED}.${TEST_SEED}.md"
expect_name_rejected "TEMPLATE.md"

TEST_REPO_ROOT="$(mktemp -d)"
TEST_COLLECTION="${TEST_REPO_ROOT}/docs/delivery/plans/implementation_plans/infra"
mkdir -p "${TEST_COLLECTION}" "${TEST_REPO_ROOT}/docs/gates"
trap 'rm -rf "${TEST_REPO_ROOT}"' EXIT

run_collection_validator() {
  IP_INFRA_VALIDATOR_TEST_MODE=1 \
    IP_INFRA_TEST_REPO_ROOT="${TEST_REPO_ROOT}" \
    bash "${VALIDATOR}" --collection "${TEST_COLLECTION}"
}

printf '%s\n' \
  '# Test collection' \
  '' \
  '**Implementation Plans específicos:** nenhum.' \
  > "${TEST_COLLECTION}/README.md"
printf '%s\n' \
  '---' \
  'document_id: IMPLEMENTATION-PLAN-INFRA-TEMPLATE' \
  'primary_nature: Template' \
  'status: Active' \
  '---' \
  '# Neutral template' \
  > "${TEST_COLLECTION}/TEMPLATE.md"

if bash "${VALIDATOR}" --collection "${TEST_COLLECTION}"; then
  printf '%s\n' 'Expected collection override without isolated test mode to fail.' >&2
  exit 1
fi

run_collection_validator

rm "${TEST_COLLECTION}/TEMPLATE.md"
run_collection_validator
printf '%s\n' \
  '---' \
  'document_id: IMPLEMENTATION-PLAN-INFRA-TEMPLATE' \
  'primary_nature: Template' \
  'status: Active' \
  '---' \
  '# Neutral template' \
  > "${TEST_COLLECTION}/TEMPLATE.md"

sed -i 's/primary_nature: Template/primary_nature: Plano/' "${TEST_COLLECTION}/TEMPLATE.md"
if run_collection_validator; then
  printf '%s\n' 'Expected an executable-plan nature on TEMPLATE.md to fail.' >&2
  exit 1
fi
sed -i 's/primary_nature: Plano/primary_nature: Template/' "${TEST_COLLECTION}/TEMPLATE.md"
run_collection_validator

INVALID_FILE="${TEST_COLLECTION}/NOT-AN-IP.md"
printf '%s\n' '# Invalid' > "${INVALID_FILE}"
if run_collection_validator; then
  printf '%s\n' 'Expected an unauthorized Markdown filename to fail.' >&2
  exit 1
fi
rm "${INVALID_FILE}"

printf '%s\n' \
  '---' \
  'document_id: TEST-GATE-ALLOCATION' \
  'status: Approved' \
  '---' \
  '' \
  "## allocation — ${VALID_STEM}" \
  "ip_infra_gate: subject=${VALID_STEM}; gate_kind=allocation; decision=Approved; decided_at=2026-08-24; approver=Test Maintainer; anchor=allocation" \
  'Authorizes materialization as Proposed in the isolated fixture.' \
  > "${TEST_REPO_ROOT}/docs/gates/allocation.md"
printf '%s\n' \
  '---' \
  'document_id: TEST-GATE-APPROVAL' \
  'status: Approved' \
  '---' \
  '' \
  "## approval — ${VALID_STEM}" \
  "ip_infra_gate: subject=${VALID_STEM}; gate_kind=approved; decision=Approved; decided_at=2026-08-24; approver=Test Maintainer; anchor=approval" \
  'Authorizes the transition from Proposed to Approved in the isolated fixture.' \
  > "${TEST_REPO_ROOT}/docs/gates/approval.md"

printf '%s\n' \
  '---' \
  "document_id: ${VALID_STEM}" \
  'status: Proposed' \
  'allocation_gate_evidence: docs/gates/allocation.md#allocation' \
  '---' \
  '' \
  "# ${VALID_STEM}" \
  > "${TEST_COLLECTION}/${VALID_THREE}"
printf '%s\n' \
  '# Test collection' \
  '' \
  "- [Generated plan](${VALID_THREE})" \
  > "${TEST_COLLECTION}/README.md"

run_collection_validator
sed -i 's/status: Proposed/status: Draft/' "${TEST_COLLECTION}/${VALID_THREE}"
run_collection_validator
sed -i 's/status: Draft/status: Proposed/' "${TEST_COLLECTION}/${VALID_THREE}"

printf '%s\n' \
  '---' \
  "document_id: ${VALID_STEM}" \
  'status: Approved' \
  'allocation_gate_evidence: docs/gates/allocation.md#allocation' \
  '---' \
  '' \
  "# ${VALID_STEM}" \
  > "${TEST_COLLECTION}/${VALID_THREE}"
if run_collection_validator; then
  printf '%s\n' 'Expected a post-Proposed status without transition evidence to fail.' >&2
  exit 1
fi

printf '%s\n' \
  '---' \
  "document_id: ${VALID_STEM}" \
  'status: Approved' \
  'allocation_gate_evidence: docs/gates/allocation.md#allocation' \
  'approved_gate_evidence: docs/gates/approval.md#approval' \
  '---' \
  '' \
  "# ${VALID_STEM}" \
  > "${TEST_COLLECTION}/${VALID_THREE}"
run_collection_validator

printf '%s\n' 'IP-INFRA validator focused tests passed.'
