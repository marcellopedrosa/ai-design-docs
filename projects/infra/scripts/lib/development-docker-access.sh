#!/usr/bin/env bash

# Shared fail-closed preflight for local development entrypoints. This helper
# must be sourced; it never changes groups, invokes sudo, or starts Compose.
require_direct_development_docker_access() {
    local repository_root="${1:-}"
    local continuation_mode="${2:-}"
    local developer_user docker_endpoint failure_reason=""

    if [ -z "$repository_root" ] || [ ! -d "$repository_root" ]; then
        echo "ERROR: a valid repository root is required for the Docker access preflight." >&2
        return 1
    fi

    case "${DOCKER_HOST:-}" in
        ""|unix://*)
            ;;
        *)
            failure_reason="DOCKER_HOST selects a non-local Docker endpoint"
            ;;
    esac
    if [ -z "$failure_reason" ] \
        && ! command -v docker >/dev/null 2>&1; then
        failure_reason="the Docker CLI is unavailable"
    fi
    if [ -z "$failure_reason" ]; then
        if ! docker_endpoint="$(docker context inspect --format '{{.Endpoints.docker.Host}}' 2>/dev/null)"; then
            failure_reason="the active Docker context is not inspectable"
        elif [[ "$docker_endpoint" != unix://* ]]; then
            failure_reason="the active Docker context is not local"
        elif ! docker info >/dev/null 2>&1; then
            failure_reason="Docker is not directly accessible to the login user"
        elif ! docker compose version >/dev/null 2>&1; then
            failure_reason="Docker Compose is not directly available to the login user"
        fi
    fi
    [ -z "$failure_reason" ] && return 0

    developer_user="$(id -un 2>/dev/null || printf '%s' '<login-user>')"
    echo "ERROR: $failure_reason. Docker is never elevated by this entrypoint." >&2
    printf 'Prepare the host from the repository root (%q) with the canonical bootstrap:\n' \
        "$repository_root" >&2
    printf '  sudo ./infra/scripts/bootstrap-development-host.sh --developer-user %q --docker-access rootful-group' \
        "$developer_user" >&2
    if [ -n "$continuation_mode" ]; then
        printf ' --continue %q' "$continuation_mode" >&2
    fi
    printf '\n' >&2
    if [ -z "$continuation_mode" ]; then
        echo "Open a fresh login session, then retry the entrypoint." >&2
    fi
    echo "See docs/onboarding/local-development-host-bootstrap.md." >&2
    return 1
}
