#!/usr/bin/env bash

set -Eeuo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEV_BOT_COMPOSE_PROJECT_NAME="$(basename "$PROJECT_DIR")"
cd "$PROJECT_DIR"

[[ "$DEV_BOT_COMPOSE_PROJECT_NAME" =~ ^[a-z0-9][a-z0-9_-]*$ ]] || {
    echo "ERROR: Invalid dev-bot Compose project directory name: $DEV_BOT_COMPOSE_PROJECT_NAME"
    exit 1
}
if [[ "$DEV_BOT_COMPOSE_PROJECT_NAME" =~ (^|[-_])(prod|prd|production)([-_]|$) ]]; then
    echo "ERROR: Refusing to stop dev-bot from a production-like project directory: $DEV_BOT_COMPOSE_PROJECT_NAME"
    exit 1
fi

GENERATED_ENV_FILE="$PROJECT_DIR/.env.dev.local"
LOCAL_ENV_FILE="$PROJECT_DIR/.env"
COMPOSE_FILES=(-f docker-compose.yml -f docker-compose.override.yml -f docker-compose.dev-bot.yml)
if [ -n "${DEV_BOT_EXTRA_COMPOSE_FILE:-}" ]; then
    COMPOSE_FILES+=(-f "$DEV_BOT_EXTRA_COMPOSE_FILE")
fi
COMPOSE_ENV_FILES=()

if [ -f "$GENERATED_ENV_FILE" ]; then
    COMPOSE_ENV_FILES+=(--env-file "$GENERATED_ENV_FILE")
fi
if [ -f "$LOCAL_ENV_FILE" ]; then
    COMPOSE_ENV_FILES+=(--env-file "$LOCAL_ENV_FILE")
fi

if [ ${#COMPOSE_ENV_FILES[@]} -eq 0 ]; then
    echo "ERROR: neither .env.dev.local nor .env exists."
    exit 1
fi

REMOVE_VOLUMES=false
case "${1:-}" in
    "")
        ;;
    --volumes)
        REMOVE_VOLUMES=true
        ;;
    *)
        echo "Usage: ./stop-dev-bot.sh [--volumes]"
        exit 1
        ;;
esac

DOWN_ARGS=(down --remove-orphans)
if [ "$REMOVE_VOLUMES" = true ]; then
    if [ "${CONFIRM_DELETE_VOLUMES:-}" != "DELETE" ]; then
        echo "ERROR: --volumes permanently deletes PostgreSQL, Keycloak and application data."
        echo "To confirm, run: CONFIRM_DELETE_VOLUMES=DELETE ./stop-dev-bot.sh --volumes"
        exit 1
    fi
    DOWN_ARGS+=(--volumes)
fi

# shellcheck source=infra/scripts/lib/development-docker-access.sh
source "$PROJECT_DIR/infra/scripts/lib/development-docker-access.sh"
require_direct_development_docker_access "$PROJECT_DIR"
COMPOSE=(docker compose --project-name "$DEV_BOT_COMPOSE_PROJECT_NAME")

"${COMPOSE[@]}" "${COMPOSE_ENV_FILES[@]}" "${COMPOSE_FILES[@]}" "${DOWN_ARGS[@]}"

if [ "$REMOVE_VOLUMES" = true ]; then
    echo "Development bot environment stopped and volumes removed."
else
    echo "Development bot environment stopped; volumes were preserved."
fi
