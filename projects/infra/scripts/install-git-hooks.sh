#!/usr/bin/env bash
set -euo pipefail

repository_root="$(git rev-parse --show-toplevel)"
git -C "$repository_root" config --local core.hooksPath .githooks
echo "Git hooks configurados em .githooks para este clone."
