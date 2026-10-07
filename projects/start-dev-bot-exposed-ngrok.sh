#!/usr/bin/env bash
# =============================================================================
# Contador Fiscal Inteligente - Docker Compose Expose Initialization Script
# =============================================================================
# This script initializes the SaaS environment and dynamically fetches the 
# public Ngrok URL so it can be injected into Keycloak, Backend, and Frontend.

set -Eeuo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$PROJECT_DIR"

load_dotenv_if_unset() {
    local file="$1"
    local line key value

    [ -f "$file" ] || return 0
    while IFS= read -r line || [ -n "$line" ]; do
        line="${line%$'\r'}"
        [[ "$line" =~ ^[[:space:]]*$ ]] && continue
        [[ "$line" =~ ^[[:space:]]*# ]] && continue
        [[ "$line" =~ ^[A-Za-z_][A-Za-z0-9_]*= ]] || continue

        key="${line%%=*}"
        value="${line#*=}"
        if [[ "$value" == \"*\" && "$value" == *\" ]]; then
            value="${value:1:${#value}-2}"
        elif [[ "$value" == \'*\' && "$value" == *\' ]]; then
            value="${value:1:${#value}-2}"
        fi
        if [ -z "${!key-}" ] && [ -n "$value" ]; then
            export "$key=$value"
        fi
    done < "$file"
}

echo "Starting initialization script for expose environment..."

"$PROJECT_DIR/start-dev-bot.sh" --prepare-env-only
COMPOSE_ENV_FILES=(--env-file "$PROJECT_DIR/.env.dev.local")
if [ -f "$PROJECT_DIR/.env" ]; then
    COMPOSE_ENV_FILES+=(--env-file "$PROJECT_DIR/.env")
fi

# shellcheck source=infra/scripts/lib/development-docker-access.sh
source "$PROJECT_DIR/infra/scripts/lib/development-docker-access.sh"
require_direct_development_docker_access "$PROJECT_DIR" start-dev-bot-exposed-ngrok
COMPOSE=(docker compose)

# Explicit environment wins, then real local configuration, then generated
# development defaults. Values are never evaluated as shell code.
load_dotenv_if_unset "$PROJECT_DIR/.env"
load_dotenv_if_unset "$PROJECT_DIR/.env.dev.local"

if [ -z "${NGROK_AUTHTOKEN:-}" ]; then
    echo "ERROR: NGROK_AUTHTOKEN is not set in .env"
    exit 1
fi

if [[ ! "${APP_BASE_URL:-}" =~ ^https://[A-Za-z0-9.-]+(:[0-9]+)?/?$ ]]; then
    echo "ERROR: APP_BASE_URL must be a complete public HTTPS origin."
    exit 1
fi
APP_BASE_URL="${APP_BASE_URL%/}"
export APP_BASE_URL

echo "Starting NGINX Proxy and Ngrok..."
# We run ngrok and proxy first
"${COMPOSE[@]}" "${COMPOSE_ENV_FILES[@]}" -f docker-compose.yml -f docker-compose.override.yml -f docker-compose.dev-expose.yml up -d proxy ngrok

echo "Waiting for Ngrok to initialize (up to 20 seconds)..."

# Fetch the public URL from ngrok API (exposed on port 4040 by the container).
NGROK_URL=""
for _ in $(seq 1 20); do
    NGROK_URL=$(curl --fail --silent --show-error http://localhost:4040/api/tunnels 2>/dev/null \
        | grep -o '"public_url":"https://[^"]*"' \
        | head -n 1 \
        | cut -d'"' -f4 || true)
    [ -n "$NGROK_URL" ] && break
    sleep 1
done

if [ -z "$NGROK_URL" ]; then
    echo "ERROR: Could not get public URL from Ngrok. Make sure the ngrok container started successfully."
    exit 1
fi
NGROK_URL="${NGROK_URL%/}"
if [ "$NGROK_URL" != "$APP_BASE_URL" ]; then
    echo "ERROR: Ngrok inspector returned a public origin different from APP_BASE_URL."
    exit 1
fi

echo "Ngrok public origin matches APP_BASE_URL."

# Export it so docker compose can use it for the rest of the services
export PUBLIC_URL="$NGROK_URL"

# Start the rest of the services with the PUBLIC_URL
echo "Starting Backend, Frontend, Keycloak, Databases, etc..."
PUBLIC_URL="$PUBLIC_URL" "${COMPOSE[@]}" "${COMPOSE_ENV_FILES[@]}" -f docker-compose.yml -f docker-compose.override.yml -f docker-compose.dev-expose.yml up -d --build backend frontend keycloak keycloak-provisioning-init postgres-app postgres-keycloak redis

echo "=========================================================="
echo "SaaS is successfully exposed!"
echo "Frontend: $PUBLIC_URL/"
echo "Backend:  $PUBLIC_URL/api/"
echo "Keycloak: $PUBLIC_URL/auth/"
echo "=========================================================="
