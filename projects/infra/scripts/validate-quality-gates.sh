#!/usr/bin/env bash

set -uo pipefail

usage() {
  cat <<'USAGE'
Usage:
  ./infra/scripts/validate-quality-gates.sh --scope <docs|backend|frontend|website|infra|all> --level <focused|pr|release> [options]

Options:
  --focus <selector>  Test selector or repository-relative shell path; required for focused software gates.
  --target <path>     Changed path for metrics and TP/IP granularity; repeat for every changed file.
  --delivery          Certify the gate for an autonomous governed push.
  --branch-name <id>  Exact delivery branch; required with --delivery.
  --dry-run           Validate configuration and print commands without executing them.
  --root <directory>  Repository root override used by hermetic contract tests.
  --help              Show this help.

Results:
  QUALITY_GATE_RESULT=PASS     every applicable command passed
  QUALITY_GATE_RESULT=FAIL     an executed command failed
  QUALITY_GATE_RESULT=BLOCKED  required configuration, tool or input is absent
USAGE
}

scope=''
level=''
focus=''
dry_run=0
root_override=''
targets=()
delivery=0
branch_name=''

while (($# > 0)); do
  case "$1" in
    --scope)
      [[ $# -ge 2 ]] || { printf 'ERROR: --scope requires a value\n' >&2; usage >&2; exit 2; }
      scope="$2"
      shift 2
      ;;
    --level)
      [[ $# -ge 2 ]] || { printf 'ERROR: --level requires a value\n' >&2; usage >&2; exit 2; }
      level="$2"
      shift 2
      ;;
    --focus)
      [[ $# -ge 2 ]] || { printf 'ERROR: --focus requires a value\n' >&2; usage >&2; exit 2; }
      focus="$2"
      shift 2
      ;;
    --root)
      [[ $# -ge 2 ]] || { printf 'ERROR: --root requires a value\n' >&2; usage >&2; exit 2; }
      root_override="$2"
      shift 2
      ;;
    --target)
      [[ $# -ge 2 ]] || { printf 'ERROR: --target requires a value\n' >&2; usage >&2; exit 2; }
      targets+=("$2")
      shift 2
      ;;
    --branch-name)
      [[ $# -ge 2 ]] || { printf 'ERROR: --branch-name requires a value\n' >&2; usage >&2; exit 2; }
      branch_name="$2"
      shift 2
      ;;
    --delivery)
      delivery=1
      shift
      ;;
    --dry-run)
      dry_run=1
      shift
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      printf 'ERROR: unknown argument: %s\n' "$1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

case "$scope" in docs|backend|frontend|website|infra|all) ;; *) printf 'ERROR: invalid or missing --scope: %s\n' "$scope" >&2; usage >&2; exit 2 ;; esac
case "$level" in focused|pr|release) ;; *) printf 'ERROR: invalid or missing --level: %s\n' "$level" >&2; usage >&2; exit 2 ;; esac
if [[ "$level" == focused && "$scope" != docs && -z "$focus" ]]; then
  printf 'ERROR: --focus is required for focused %s gates\n' "$scope" >&2
  exit 2
fi
if [[ "$level" == focused && "$scope" == all ]]; then
  printf 'ERROR: focused gates require one explicit scope, not all\n' >&2
  exit 2
fi
if [[ "$level" != focused && ${#targets[@]} -eq 0 ]]; then
  printf 'ERROR: at least one --target is required for %s/%s metrics\n' "$scope" "$level" >&2
  exit 2
fi
if ((delivery)) && [[ "$level" == focused || -z "$branch_name" ]]; then
  printf 'ERROR: --delivery requires pr/release and --branch-name\n' >&2
  exit 2
fi
if ((!delivery)) && [[ -n "$branch_name" ]]; then
  printf 'ERROR: --branch-name requires --delivery\n' >&2
  exit 2
fi

if [[ -n "$root_override" ]]; then
  if [[ ! -d "$root_override" ]]; then
    printf 'ERROR: --root is not a directory: %s\n' "$root_override" >&2
    exit 2
  fi
  repo_root="$(cd "$root_override" && pwd)"
else
  repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
fi

failures=0
blocked=0

block() {
  printf 'QUALITY_GATE_BLOCKED: %s\n' "$1" >&2
  blocked=$((blocked + 1))
}

print_command() {
  local workdir="$1"
  shift
  printf 'QUALITY_GATE_COMMAND cwd=%q command=' "${workdir#"$repo_root"/}"
  printf '%q ' "$@"
  printf '\n'
}

run_in() {
  local workdir="$1"
  shift
  print_command "$workdir" "$@"
  if ((dry_run)); then
    return 0
  fi
  if ! (cd "$workdir" && "$@"); then
    failures=$((failures + 1))
    printf 'QUALITY_GATE_FAILED: command exited non-zero in %s\n' "${workdir#"$repo_root"/}" >&2
    return 1
  fi
}

require_file() {
  local file="$1"
  local label="$2"
  if [[ ! -s "$file" ]]; then
    block "$label missing or empty: ${file#"$repo_root"/}"
    return 1
  fi
}

require_executable() {
  local file="$1"
  local label="$2"
  require_file "$file" "$label" || return 1
  if [[ ! -x "$file" ]]; then
    block "$label is not executable: ${file#"$repo_root"/}"
    return 1
  fi
}

require_marker() {
  local file="$1"
  local marker="$2"
  local label="$3"
  require_file "$file" "$label" || return 1
  if ! grep -Fq "$marker" "$file"; then
    block "$label omits required marker '$marker': ${file#"$repo_root"/}"
    return 1
  fi
}

require_npm_script() {
  local package_dir="$1"
  local script_name="$2"
  local manifest="$package_dir/package.json"
  require_file "$manifest" 'npm manifest' || return 1
  if ! node -e 'const p=require(process.argv[1]); process.exit(p.scripts?.[process.argv[2]] ? 0 : 1)' "$manifest" "$script_name"; then
    block "npm script '$script_name' is not configured in ${manifest#"$repo_root"/}"
    return 1
  fi
}

run_npm() {
  local package_dir="$1"
  local script_name="$2"
  shift 2
  require_npm_script "$package_dir" "$script_name" || return 1
  run_in "$package_dir" npm run "$script_name" -- "$@"
}

run_docs_gate() {
  local validator="$repo_root/infra/scripts/validate-docs.sh"
  require_executable "$validator" 'documentation gate' || return
  run_in "$repo_root" ./infra/scripts/validate-docs.sh
}

run_backend_focused() {
  local package_dir="$repo_root/backend"
  require_executable "$package_dir/mvnw" 'backend Maven wrapper' || return
  run_in "$package_dir" ./mvnw -B "-Dtest=$focus" test
}

run_backend_pr() {
  local package_dir="$repo_root/backend"
  local pom="$package_dir/pom.xml"
  local blocked_before="$blocked"
  require_executable "$package_dir/mvnw" 'backend Maven wrapper' || true
  require_marker "$pom" '<artifactId>jacoco-maven-plugin</artifactId>' 'backend coverage enforcement' || true
  require_marker "$pom" '<goal>check</goal>' 'backend coverage check' || true
  if [[ "$blocked" -eq "$blocked_before" ]]; then
    run_in "$package_dir" ./mvnw -B clean verify
  fi
}

run_node_focused() {
  local package_dir="$1"
  run_npm "$package_dir" test "$focus"
}

run_node_pr() {
  local package_dir="$1"
  local config="$package_dir/vitest.config.ts"
  local blocked_before="$blocked"
  local build_env_blocked=0
  local env_candidate
  require_marker "$config" 'coverage:' 'Vitest coverage configuration' || true
  require_marker "$config" 'thresholds:' 'Vitest coverage thresholds' || true
  for script_name in test:coverage lint typecheck format:check build; do
    require_npm_script "$package_dir" "$script_name" || true
  done
  if [[ "$blocked" -eq "$blocked_before" ]]; then
    run_npm "$package_dir" test:coverage
    run_npm "$package_dir" lint
    run_npm "$package_dir" typecheck
    run_npm "$package_dir" format:check
    for env_candidate in .env .env.local .env.development.local .env.production.local .env.test.local; do
      if [[ -e "$package_dir/$env_candidate" ]]; then
        block "build refused because the framework may read local environment file: ${package_dir#"$repo_root"/}/$env_candidate"
        build_env_blocked=1
      fi
    done
    if ((build_env_blocked == 0)); then
      run_npm "$package_dir" build
    fi
  fi
}

run_infra_focused() {
  case "$focus" in
    infra/*.sh|infra/*/*.sh|infra/*/*/*.sh) ;;
    *) block "infra --focus must be a repository-relative .sh path below infra/: $focus"; return ;;
  esac
  if [[ "$focus" == *'..'* ]]; then
    block "infra --focus must not contain '..': $focus"
    return
  fi
  local target="$repo_root/$focus"
  require_file "$target" 'focused shell target' || return
  run_in "$repo_root" bash -n "$focus"
  if [[ "$focus" == infra/scripts/tests/*-test.sh ]]; then
    run_in "$repo_root" bash "$focus"
  fi
}

run_infra_pr() {
  local script
  while IFS= read -r script; do
    run_in "$repo_root" bash -n "${script#"$repo_root"/}"
  done < <(find "$repo_root/infra/scripts" -type f -name '*.sh' -print | sort)
  local contract_test="$repo_root/infra/scripts/tests/validate-quality-gates-test.sh"
  require_file "$contract_test" 'quality gate contract test' || return
  run_in "$repo_root" bash infra/scripts/tests/validate-quality-gates-test.sh
  require_file "$repo_root/harness/tooling/validators/validate-quality-metrics.test.mjs" 'quality metrics test' || return
  run_in "$repo_root" node --test harness/tooling/validators/validate-quality-metrics.test.mjs
  require_file "$repo_root/harness/tooling/validators/validate-plan-granularity.test.mjs" 'plan granularity test' || return
  run_in "$repo_root" node --test harness/tooling/validators/validate-plan-granularity.test.mjs
  require_file "$repo_root/harness/tooling/validators/validate-quality-policy.test.mjs" 'quality policy test' || return
  run_in "$repo_root" node --test harness/tooling/validators/validate-quality-policy.test.mjs
}

run_plan_granularity() {
  local tool="$repo_root/infra/scripts/validate-plan-granularity.mjs"
  local docs_targets=()
  local target
  for target in "${targets[@]}"; do
    if [[ "$target" == docs/* ]]; then
      docs_targets+=("$target")
    fi
  done
  if ((${#docs_targets[@]} == 0)); then
    return
  fi
  require_file "$tool" 'plan granularity tool' || return
  local command=(node "$tool" --root "$repo_root")
  for target in "${docs_targets[@]}"; do
    command+=(--target "$target")
  done
  print_command "$repo_root" "${command[@]}"
  if ((dry_run)); then
    return
  fi
  local output
  output="$("${command[@]}" 2>&1)"
  local status=$?
  printf '%s\n' "$output"
  if ((status != 0)); then
    if grep -Fq 'PLAN_GRANULARITY_RESULT=BLOCKED' <<<"$output"; then
      blocked=$((blocked + 1))
    else
      failures=$((failures + 1))
    fi
  fi
}

run_metrics() {
  local selected="$1"
  local tool="$repo_root/infra/scripts/validate-quality-metrics.mjs"
  local scoped_targets=()
  local target
  for target in "${targets[@]}"; do
    if [[ "$target" == "$selected/"* ]]; then
      scoped_targets+=("$target")
    fi
  done
  if ((${#scoped_targets[@]} == 0)); then
    return
  fi
  require_file "$tool" 'quality metrics tool' || return
  local command=(node "$tool" --root "$repo_root" --scope "$selected")
  for target in "${scoped_targets[@]}"; do
    command+=(--target "$target")
  done
  if ((delivery)); then
    command+=(--delivery --branch-name "$branch_name" --policy infra/quality-gate-policy.json)
  fi
  print_command "$repo_root" "${command[@]}"
  if ((dry_run)); then
    return
  fi
  local output
  output="$("${command[@]}" 2>&1)"
  local status=$?
  printf '%s\n' "$output"
  if ((status != 0)); then
    if grep -Fq 'QUALITY_METRICS_RESULT=BLOCKED' <<<"$output"; then
      blocked=$((blocked + 1))
    else
      failures=$((failures + 1))
    fi
  fi
}

run_scope() {
  local selected="$1"
  case "$selected:$level" in
    docs:*) run_docs_gate ;;
    backend:focused) run_backend_focused ;;
    backend:pr|backend:release) run_backend_pr ;;
    frontend:focused) run_node_focused "$repo_root/frontend" ;;
    frontend:pr|frontend:release) run_node_pr "$repo_root/frontend" ;;
    website:focused) run_node_focused "$repo_root/website" ;;
    website:pr|website:release) run_node_pr "$repo_root/website" ;;
    infra:focused) run_infra_focused ;;
    infra:pr|infra:release) run_infra_pr ;;
  esac

  if [[ "$level" == release ]]; then
    case "$selected" in
      frontend|website)
        if ((blocked == 0 && failures == 0)); then
          run_npm "$repo_root/$selected" test:e2e
        fi
        ;;
    esac
  fi
  if [[ "$level" != focused ]]; then
    run_metrics "$selected"
    if [[ "$selected" == docs ]]; then
      run_plan_granularity
    fi
  fi
}

printf 'QUALITY_GATE_START scope=%s level=%s dry_run=%s\n' "$scope" "$level" "$dry_run"
if [[ "$scope" == all ]]; then
  for selected_scope in docs backend frontend website infra; do
    run_scope "$selected_scope"
  done
else
  run_scope "$scope"
fi

if ((failures > 0)); then
  printf 'QUALITY_GATE_RESULT=FAIL failures=%d blocked=%d\n' "$failures" "$blocked" >&2
  exit 1
fi
if ((blocked > 0)); then
  printf 'QUALITY_GATE_RESULT=BLOCKED failures=0 blocked=%d\n' "$blocked" >&2
  exit 1
fi
printf 'QUALITY_GATE_RESULT=PASS failures=0 blocked=0\n'
