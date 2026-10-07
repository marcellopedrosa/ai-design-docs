#!/usr/bin/env bash
# Contador Fiscal Inteligente - Start Script for Bot Webhooks (Hybrid Local Mode)
# This script starts the SaaS environment locally on localhost, but spins up
# an Ngrok tunnel EXCLUSIVELY for the Backend to receive external webhooks
# (like Telegram or WhatsApp bots).

set -Eeuo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEV_BOT_COMPOSE_PROJECT_NAME="$(basename "$PROJECT_DIR")"
GENERATED_ENV_FILE="$PROJECT_DIR/.env.dev.local"
DEV_SECRETS_DIR="$PROJECT_DIR/.dev-secrets"
source "$PROJECT_DIR/infra/scripts/lib/start-dev-bot/part-01.sh"
source "$PROJECT_DIR/infra/scripts/lib/start-dev-bot/part-02.sh"
source "$PROJECT_DIR/infra/scripts/lib/start-dev-bot/part-03.sh"
source "$PROJECT_DIR/infra/scripts/lib/start-dev-bot/part-04.sh"
source "$PROJECT_DIR/infra/scripts/lib/start-dev-bot/part-05.sh"
source "$PROJECT_DIR/infra/scripts/lib/start-dev-bot/part-06.sh"
source "$PROJECT_DIR/infra/scripts/lib/start-dev-bot/part-07.sh"
source "$PROJECT_DIR/infra/scripts/lib/start-dev-bot/part-08.sh"
