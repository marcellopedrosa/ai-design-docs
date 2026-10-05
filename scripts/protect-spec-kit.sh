#!/usr/bin/env bash
set -euo pipefail

usage() {
  printf 'Usage: bash scripts/protect-spec-kit.sh lock|unlock|status [TARGET] [STATE_FILE]\n' >&2
  exit 2
}

action=${1:-status}
case "$action" in lock|unlock|status) ;; *) usage ;; esac
if (($# > 3)); then usage; fi

case "$(uname -s)" in
  Linux|Darwin) ;;
  *) printf 'Use protect-spec-kit.ps1 with Windows ACLs on this system.\n' >&2; exit 1 ;;
esac

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
target_arg=${2:-"$script_dir/../spec-kit"}
[[ -d $target_arg ]] || { printf 'Target must be an existing directory.\n' >&2; exit 1; }
target=$(cd -- "$target_arg" && pwd -P)
state=${3:-"$script_dir/../.guard/spec-kit-modes.bin"}
state_parent=$(dirname -- "$state")
mkdir -p -- "$state_parent"
state_parent=$(cd -- "$state_parent" && pwd -P)
state="$state_parent/$(basename -- "$state")"
case "$state" in
  "$target"|"$target/"*) printf 'State file must be outside the protected directory.\n' >&2; exit 1 ;;
esac

mode_of() {
  if [[ $(uname -s) == Darwin ]]; then stat -f %Lp "$1"; else stat -c %a -- "$1"; fi
}

case "$action" in
  status)
    if [[ -f $state ]]; then printf 'Locked: %s\n' "$target"; else printf 'Unlocked: %s\n' "$target"; fi
    ;;
  lock)
    [[ ! -e $state ]] || { printf 'Already locked: %s\n' "$target" >&2; exit 1; }
    tmp=$(mktemp "$state.XXXXXX")
    trap 'rm -f -- "$tmp"' EXIT
    while IFS= read -r -d '' item; do
      printf '%s\0%s\0' "$(mode_of "$item")" "$item" >> "$tmp"
    done < <(find "$target" \( -type f -o -type d \) -print0)
    mv -- "$tmp" "$state"
    trap - EXIT
    while IFS= read -r -d '' mode && IFS= read -r -d '' item; do
      chmod a-w -- "$item"
    done < "$state"
    printf 'Locked: %s\n' "$target"
    ;;
  unlock)
    [[ -f $state ]] || { printf 'No permission snapshot: %s\n' "$state" >&2; exit 1; }
    while IFS= read -r -d '' mode && IFS= read -r -d '' item; do
      [[ -e $item ]] || { printf 'Snapshot target missing: %s\n' "$item" >&2; exit 1; }
      chmod "$mode" -- "$item"
    done < "$state"
    rm -f -- "$state"
    printf 'Unlocked: %s\n' "$target"
    ;;
esac
