#!/usr/bin/env bash
set -euo pipefail

usage() {
  printf 'Usage: bash scripts/install-corporate-skills.sh --project-root PATH [--agent codex|claude|both] [--force]\n' >&2
  exit 2
}

project_root=''
agent='both'
force=false
while (($#)); do
  case "$1" in
    --project-root)
      (($# >= 2)) || usage
      project_root=$2
      shift 2
      ;;
    --agent)
      (($# >= 2)) || usage
      agent=$2
      shift 2
      ;;
    --force)
      force=true
      shift
      ;;
    *) usage ;;
  esac
done

[[ -n $project_root && -d $project_root ]] || usage
case "$agent" in codex|claude|both) ;; *) usage ;; esac

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
project=$(cd -- "$project_root" && pwd -P)
core=$(cd -- "$script_dir/../spec-kit" && pwd -P)
source_dir=$(cd -- "$script_dir/../corporate-presets/skills" && pwd -P)
case "$project/" in
  "$core/"|"$core/"*) printf 'ProjectRoot cannot be inside the protected spec-kit core.\n' >&2; exit 1 ;;
esac

skills=()
for skill_dir in "$source_dir"/*/; do
  [[ -d $skill_dir ]] || continue
  name=${skill_dir%/}
  name=${name##*/}
  if [[ ! $name =~ ^[a-z0-9]+(-[a-z0-9]+)*$ || $name == speckit-* ]]; then
    printf 'Invalid or reserved skill name: %s\n' "$name" >&2
    exit 1
  fi
  [[ -f "$skill_dir/SKILL.md" ]] || { printf 'Missing SKILL.md: %s\n' "$skill_dir" >&2; exit 1; }
  skills+=("$name")
done

runtimes=()
case "$agent" in
  both) runtimes=(codex claude) ;;
  *) runtimes=("$agent") ;;
esac

# Check every destination before copying any skill.
for runtime in "${runtimes[@]}"; do
  if [[ $runtime == codex ]]; then parent="$project/.agents/skills"; else parent="$project/.claude/skills"; fi
  for name in "${skills[@]}"; do
    destination="$parent/$name"
    if [[ -L $destination || ( -e $destination && ! -d $destination ) ]]; then
      printf 'Destination is not a regular directory: %s\n' "$destination" >&2
      exit 1
    fi
    if [[ -e $destination && $force == false ]]; then
      printf 'Skill already installed; use --force to update: %s\n' "$destination" >&2
      exit 1
    fi
  done
done

for runtime in "${runtimes[@]}"; do
  if [[ $runtime == codex ]]; then parent="$project/.agents/skills"; else parent="$project/.claude/skills"; fi
  mkdir -p -- "$parent"
  for name in "${skills[@]}"; do
    destination="$parent/$name"
    if [[ -d $destination ]]; then
      cp -R -- "$source_dir/$name/." "$destination/"
    else
      cp -R -- "$source_dir/$name" "$destination"
    fi
    printf '%s: %s\n' "$runtime" "$destination"
  done
done
