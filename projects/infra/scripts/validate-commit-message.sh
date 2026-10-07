#!/usr/bin/env bash
set -euo pipefail

message_file="${1:-}"
if [[ -z "$message_file" || ! -f "$message_file" ]]; then
  echo "ERROR: informe o arquivo de mensagem do commit." >&2
  exit 2
fi

branch="$(git branch --show-current)"
if [[ -z "$branch" || "$branch" == main ]]; then
  echo "ERROR: commit exige branch de trabalho separada da main." >&2
  exit 1
fi

subject="$(head -n 1 "$message_file")"
if [[ ! "$subject" =~ [^[:space:]] ]]; then
  echo "ERROR: mensagem de commit vazia." >&2
  exit 1
fi
