#!/usr/bin/env bash
# =============================================================================
# Contador Fiscal Inteligente - Start Script for DNS Local Mode + Bot Webhooks
# =============================================================================
# This script starts the SaaS environment locally using your custom domains
# (.local), but spins up an Ngrok tunnel EXCLUSIVELY for the Backend to 
# receive external webhooks (like Telegram or WhatsApp bots).
# =============================================================================

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

echo "Starting Hybrid DNS Mode (Nginx Proxy + Backend Ngrok)..."

"$PROJECT_DIR/start-dev-bot.sh" --prepare-env-only
COMPOSE_ENV_FILES=(--env-file "$PROJECT_DIR/.env.dev.local")
if [ -f "$PROJECT_DIR/.env" ]; then
    COMPOSE_ENV_FILES+=(--env-file "$PROJECT_DIR/.env")
fi

# shellcheck source=infra/scripts/lib/development-docker-access.sh
source "$PROJECT_DIR/infra/scripts/lib/development-docker-access.sh"
require_direct_development_docker_access "$PROJECT_DIR" start-dev-dns-bot
COMPOSE=(docker compose)

# Explicit environment wins, then real local configuration, then generated
# development defaults. Values are never evaluated as shell code.
load_dotenv_if_unset "$PROJECT_DIR/.env"
load_dotenv_if_unset "$PROJECT_DIR/.env.dev.local"

if [ -z "${NGROK_AUTHTOKEN:-}" ]; then
    echo "ERROR: NGROK_AUTHTOKEN is not set in .env"
    exit 1
fi

if [[ ! "${APP_BASE_URL:-}" =~ ^https://[A-Za-z0-9.-]+\.ngrok-free\.dev/?$ ]]; then
    echo "ERROR: APP_BASE_URL is not a complete HTTPS ngrok origin in .env"
    echo "Please set APP_BASE_URL=https://<your-domain>.ngrok-free.dev in your .env file."
    exit 1
fi
APP_BASE_URL="${APP_BASE_URL%/}"
export APP_BASE_URL

# Start the services (Base + Override + DNS Proxy + DNS Bot Override)
"${COMPOSE[@]}" "${COMPOSE_ENV_FILES[@]}" -f docker-compose.yml -f docker-compose.override.yml -f docker-compose.local-dns.yml -f docker-compose.dns-bot.yml up -d --build --force-recreate

echo "Waiting for Ngrok to initialize (up to 20 seconds)..."

# Fetch the public URL from ngrok API (exposed on port 4041 by the bot container).
NGROK_URL=""
for _ in $(seq 1 20); do
    NGROK_URL=$(curl --fail --silent --show-error http://localhost:4041/api/tunnels 2>/dev/null \
        | grep -o '"public_url":"https://[^"]*"' \
        | head -n 1 \
        | cut -d'"' -f4 || true)
    [ -n "$NGROK_URL" ] && break
    sleep 1
done

if [ -z "$NGROK_URL" ]; then
    echo "ERROR: Could not get public URL from Ngrok. Make sure the saas-ngrok-bot container started successfully."
    exit 1
fi
NGROK_URL="${NGROK_URL%/}"
if [ "$NGROK_URL" != "$APP_BASE_URL" ]; then
    echo "ERROR: Ngrok inspector returned a public origin different from APP_BASE_URL."
    exit 1
fi

echo "=========================================================="
echo "✅ Hybrid DNS Mode is Running!"
echo ""
echo "💻 UI / Frontend:   http://app.agentefiscal.local"
echo "🔑 Keycloak Admin:  http://auth.agentefiscal.local"
echo "🔌 Backend API:     http://api.agentefiscal.local"
echo ""
echo "🤖 WEBHOOK URL FOR BOTS (Telegram/WhatsApp):"
echo "   -> $NGROK_URL/api/..."
echo "=========================================================="
