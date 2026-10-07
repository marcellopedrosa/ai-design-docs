#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
DEFAULT_COLLECTION="${REPO_ROOT}/docs/delivery/plans/implementation_plans/infra"
COLLECTION="${DEFAULT_COLLECTION}"
NAME_PATTERN='^IP-INFRA-[0-9]+\.[0-9]+\.[0-9]+(\.[0-9]+)?-[a-z0-9]+(-[a-z0-9]+)*\.md$'

usage() {
  printf '%s\n' \
    'Usage:' \
    '  validate-ip-infra-docs.sh' \
    '  IP_INFRA_VALIDATOR_TEST_MODE=1 IP_INFRA_TEST_REPO_ROOT=<root> validate-ip-infra-docs.sh --collection <canonical-test-directory>' \
    '  validate-ip-infra-docs.sh --check-name <filename>'
}

is_plan_name() {
  [[ "$1" =~ ${NAME_PATTERN} ]]
}

frontmatter_value() {
  local file="$1"
  local key="$2"

  awk -v wanted="${key}" '
    NR == 1 && $0 == "---" { in_frontmatter = 1; next }
    in_frontmatter && $0 == "---" { exit }
    in_frontmatter && index($0, wanted ":") == 1 {
      value = substr($0, length(wanted) + 2)
      sub(/^[[:space:]]*/, "", value)
      gsub(/^"|"$/, "", value)
      print value
      exit
    }
  ' "${file}"
}

if [[ "${1:-}" == '--check-name' ]]; then
  [[ $# -eq 2 ]] || {
    usage >&2
    exit 2
  }
  is_plan_name "$2"
  exit
fi

if [[ "${1:-}" == '--collection' ]]; then
  [[ $# -eq 2 ]] || {
    usage >&2
    exit 2
  }
  [[ "${IP_INFRA_VALIDATOR_TEST_MODE:-}" == '1' && -n "${IP_INFRA_TEST_REPO_ROOT:-}" ]] || {
    printf '%s\n' '--collection is reserved for the focused test harness.' >&2
    exit 2
  }
  REPO_ROOT="${IP_INFRA_TEST_REPO_ROOT}"
  COLLECTION="$2"
  [[ "${COLLECTION}" == "${REPO_ROOT}/docs/delivery/plans/implementation_plans/infra" ]] || {
    printf '%s\n' '--collection must be the canonical IP-INFRA path under the isolated test root.' >&2
    exit 2
  }
elif [[ $# -ne 0 ]]; then
  usage >&2
  exit 2
fi

failures=0

report_failure() {
  printf 'IP-INFRA governance error: %s\n' "$1" >&2
  failures=$((failures + 1))
}

validate_gate_evidence() {
  local evidence="$1"
  local label="$2"
  local plan_file="$3"
  local plan_stem="$4"
  local expected_gate_kind="$5"
  local gate_path
  local gate_fragment
  local gate_file
  local gate_status

  if [[ -z "${evidence}" || "${evidence}" == *'<'* || "${evidence}" == *'>'* || "${evidence}" =~ ^(TODO|TBD|N/A)$ ]]; then
    report_failure "${label} must be resolved and non-placeholder in $(basename "${plan_file}")"
    return
  fi

  if [[ "${evidence}" != *'#'* ]]; then
    report_failure "${label} must identify a decision fragment in $(basename "${plan_file}"): ${evidence}"
    return
  fi

  gate_path="${evidence%%#*}"
  gate_fragment="${evidence#*#}"

  if [[ -z "${gate_fragment}" || "${gate_path}" != docs/* || "${gate_path}" == /* || "${gate_path}" == *://* || "/${gate_path}/" == *'/../'* ]]; then
    report_failure "${label} must be a non-escaping repository-doc reference in $(basename "${plan_file}"): ${evidence}"
    return
  fi

  if [[ ! "${gate_fragment}" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]]; then
    report_failure "${label} has an invalid decision fragment in $(basename "${plan_file}"): ${evidence}"
    return
  fi

  gate_file="${REPO_ROOT}/${gate_path}"
  if [[ ! -f "${gate_file}" || -L "${gate_file}" || "${gate_file}" == "${plan_file}" ]]; then
    report_failure "${label} must resolve to a separate governed document in $(basename "${plan_file}"): ${evidence}"
    return
  fi

  case "$(basename "${gate_file}")" in
    README.md|TEMPLATE.md)
      report_failure "${label} cannot point to an index or template in $(basename "${plan_file}"): ${evidence}"
      return
      ;;
  esac

  gate_status="$(frontmatter_value "${gate_file}" status)"
  case "${gate_status}" in
    Approved|Completed) ;;
    *)
      report_failure "${label} must point to an Approved or Completed decision in $(basename "${plan_file}"): ${evidence}"
      return
      ;;
  esac

  if ! awk -v fragment="${gate_fragment}" -v stem="${plan_stem}" -v gate_kind="${expected_gate_kind}" '
    BEGIN { FS = ";[[:space:]]*" }
    index($0, "ip_infra_gate:") == 1 {
      subject = ""
      kind = ""
      decision = ""
      decided_at = ""
      approver = ""
      anchor = ""

      for (i = 1; i <= NF; i++) {
        part = $i
        sub(/^ip_infra_gate:[[:space:]]*/, "", part)
        separator = index(part, "=")
        if (separator == 0) {
          continue
        }
        key = substr(part, 1, separator - 1)
        value = substr(part, separator + 1)
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", key)
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", value)

        if (key == "subject") subject = value
        else if (key == "gate_kind") kind = value
        else if (key == "decision") decision = value
        else if (key == "decided_at") decided_at = value
        else if (key == "approver") approver = value
        else if (key == "anchor") anchor = value
      }

      if (anchor == fragment) {
        anchor_count++
      }

      if (subject == stem && kind == gate_kind && decision == "Approved" &&
          decided_at ~ /^[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]$/ &&
          approver != "" && approver != "TODO" && approver != "TBD" &&
          index(approver, "<") == 0 && anchor == fragment) {
        match_count++
      }
    }
    END { exit(match_count == 1 && anchor_count == 1 ? 0 : 1) }
  ' "${gate_file}"; then
    report_failure "${label} must resolve to one unique Approved ip_infra_gate record for ${plan_stem}/${expected_gate_kind}: ${evidence}"
  fi
}

if [[ ! -d "${COLLECTION}" ]]; then
  report_failure "missing canonical collection: ${COLLECTION}"
  exit 1
fi

INDEX_FILE="${COLLECTION}/README.md"
TEMPLATE_FILE="${COLLECTION}/TEMPLATE.md"

[[ -f "${INDEX_FILE}" && ! -L "${INDEX_FILE}" ]] || report_failure 'README.md must be a regular, non-symlink file'
if [[ -f "${TEMPLATE_FILE}" ]]; then
  [[ ! -L "${TEMPLATE_FILE}" ]] || report_failure 'TEMPLATE.md must be a regular, non-symlink file'
  [[ "$(frontmatter_value "${TEMPLATE_FILE}" primary_nature)" == 'Template' ]] || report_failure 'TEMPLATE.md primary_nature must be Template'
  [[ "$(frontmatter_value "${TEMPLATE_FILE}" status)" == 'Active' ]] || report_failure 'TEMPLATE.md status must be Active'
fi

while IFS= read -r nested_directory; do
  report_failure "subdirectories are not allowed: ${nested_directory#"${COLLECTION}/"}"
done < <(find "${COLLECTION}" -mindepth 1 -type d -print)

while IFS= read -r unexpected_file; do
  report_failure "only governed Markdown files are allowed: ${unexpected_file#"${COLLECTION}/"}"
done < <(find "${COLLECTION}" -mindepth 1 -maxdepth 1 -type f ! -name '*.md' -print)

while IFS= read -r symlink_entry; do
  report_failure "symlinks are not allowed: ${symlink_entry#"${COLLECTION}/"}"
done < <(find "${COLLECTION}" -mindepth 1 -maxdepth 1 -type l -print)

shopt -s nullglob
markdown_files=("${COLLECTION}"/*.md)
plan_count=0

for file in "${markdown_files[@]}"; do
  base="$(basename "${file}")"

  if [[ -L "${file}" || ! -f "${file}" ]]; then
    report_failure "Markdown entries must be regular, non-symlink files: ${base}"
    continue
  fi

  case "${base}" in
    README.md|TEMPLATE.md)
      continue
      ;;
  esac

  if ! is_plan_name "${base}"; then
    report_failure "invalid or unauthorized Markdown filename: ${base}"
    continue
  fi

  plan_count=$((plan_count + 1))
  stem="${base%.md}"
  document_id="$(frontmatter_value "${file}" document_id)"
  status="$(frontmatter_value "${file}" status)"
  allocation_gate="$(frontmatter_value "${file}" allocation_gate_evidence)"
  approved_gate="$(frontmatter_value "${file}" approved_gate_evidence)"
  in_progress_gate="$(frontmatter_value "${file}" in_progress_gate_evidence)"
  completed_gate="$(frontmatter_value "${file}" completed_gate_evidence)"
  cancelled_gate="$(frontmatter_value "${file}" cancelled_gate_evidence)"

  [[ "${document_id}" == "${stem}" ]] || report_failure "document_id must equal filename stem: ${base}"

  case "${status}" in
    Draft|Proposed|Approved|'In Progress'|Completed|Cancelled) ;;
    *) report_failure "invalid lifecycle status in ${base}: ${status:-<missing>}" ;;
  esac

  validate_gate_evidence "${allocation_gate}" allocation_gate_evidence "${file}" "${stem}" allocation

  case "${status}" in
    Draft|Proposed)
      [[ -z "${approved_gate}${in_progress_gate}${completed_gate}${cancelled_gate}" ]] || report_failure "Draft/Proposed cannot predeclare future transition evidence in ${base}"
      ;;
    Approved)
      validate_gate_evidence "${approved_gate}" approved_gate_evidence "${file}" "${stem}" approved
      [[ "${approved_gate}" != "${allocation_gate}" ]] || report_failure "Approved must use a gate distinct from allocation in ${base}"
      [[ -z "${in_progress_gate}${completed_gate}${cancelled_gate}" ]] || report_failure "Approved cannot predeclare later transition evidence in ${base}"
      ;;
    'In Progress')
      validate_gate_evidence "${approved_gate}" approved_gate_evidence "${file}" "${stem}" approved
      validate_gate_evidence "${in_progress_gate}" in_progress_gate_evidence "${file}" "${stem}" in_progress
      [[ "${approved_gate}" != "${allocation_gate}" && "${in_progress_gate}" != "${approved_gate}" && "${in_progress_gate}" != "${allocation_gate}" ]] || report_failure "In Progress requires distinct evidence for every transition in ${base}"
      [[ -z "${completed_gate}${cancelled_gate}" ]] || report_failure "In Progress cannot predeclare a terminal transition in ${base}"
      ;;
    Completed)
      validate_gate_evidence "${approved_gate}" approved_gate_evidence "${file}" "${stem}" approved
      validate_gate_evidence "${in_progress_gate}" in_progress_gate_evidence "${file}" "${stem}" in_progress
      validate_gate_evidence "${completed_gate}" completed_gate_evidence "${file}" "${stem}" completed
      [[ "${allocation_gate}" != "${approved_gate}" && "${allocation_gate}" != "${in_progress_gate}" && "${allocation_gate}" != "${completed_gate}" && "${approved_gate}" != "${in_progress_gate}" && "${approved_gate}" != "${completed_gate}" && "${in_progress_gate}" != "${completed_gate}" ]] || report_failure "Completed requires distinct evidence for every transition in ${base}"
      [[ -z "${cancelled_gate}" ]] || report_failure "Completed cannot also declare cancellation evidence in ${base}"
      ;;
    Cancelled)
      validate_gate_evidence "${approved_gate}" approved_gate_evidence "${file}" "${stem}" approved
      validate_gate_evidence "${in_progress_gate}" in_progress_gate_evidence "${file}" "${stem}" in_progress
      validate_gate_evidence "${cancelled_gate}" cancelled_gate_evidence "${file}" "${stem}" cancelled
      [[ "${allocation_gate}" != "${approved_gate}" && "${allocation_gate}" != "${in_progress_gate}" && "${allocation_gate}" != "${cancelled_gate}" && "${approved_gate}" != "${in_progress_gate}" && "${approved_gate}" != "${cancelled_gate}" && "${in_progress_gate}" != "${cancelled_gate}" ]] || report_failure "Cancelled requires distinct evidence for every transition in ${base}"
      [[ -z "${completed_gate}" ]] || report_failure "Cancelled cannot also declare completion evidence in ${base}"
      ;;
  esac

  if [[ -f "${INDEX_FILE}" ]] && ! grep -Fq "](${base})" "${INDEX_FILE}"; then
    report_failure "missing individual README.md inventory link for ${base}"
  fi
done

if [[ -f "${TEMPLATE_FILE}" ]] && grep -Eq 'IP-INFRA-[0-9]+\.[0-9]+\.[0-9]+(\.[0-9]+)?-[a-z0-9]+(-[a-z0-9]+)*\.md' "${TEMPLATE_FILE}"; then
  report_failure 'TEMPLATE.md contains a concrete-looking IP-INFRA filename'
fi

if [[ -f "${INDEX_FILE}" ]]; then
  empty_marker='**Implementation Plans específicos:** nenhum.'
  if [[ ${plan_count} -eq 0 ]] && ! grep -Fq "${empty_marker}" "${INDEX_FILE}"; then
    report_failure 'empty collection must declare that no specific IP-INFRA exists'
  elif [[ ${plan_count} -gt 0 ]] && grep -Fq "${empty_marker}" "${INDEX_FILE}"; then
    report_failure 'README.md still declares an empty collection while specific plans exist'
  fi

  if [[ ${plan_count} -eq 0 ]] && grep -Eq 'IP-INFRA-[0-9]+\.[0-9]+\.[0-9]+(\.[0-9]+)?-[a-z0-9]+(-[a-z0-9]+)*\.md' "${INDEX_FILE}"; then
    report_failure 'empty README.md contains a concrete-looking IP-INFRA filename'
  fi

  while IFS= read -r linked_token; do
    linked_file="${linked_token#](}"
    linked_file="${linked_file%)}"
    if ! is_plan_name "${linked_file}"; then
      report_failure "README.md contains an invalid IP-INFRA inventory link: ${linked_file}"
    elif [[ ! -f "${COLLECTION}/${linked_file}" || -L "${COLLECTION}/${linked_file}" ]]; then
      report_failure "README.md contains a stale IP-INFRA inventory link: ${linked_file}"
    fi
  done < <(grep -Eo '\]\(IP-INFRA-[^)]*\.md\)' "${INDEX_FILE}" || true)
fi

if [[ ${failures} -ne 0 ]]; then
  exit 1
fi

printf 'IP-INFRA documentation governance passed (%d specific plan(s)).\n' "${plan_count}"
