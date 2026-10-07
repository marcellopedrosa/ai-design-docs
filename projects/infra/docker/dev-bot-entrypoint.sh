#!/usr/bin/env bash

set -Eeuo pipefail

PROJECT_DIR=/workspace
STATE_DIR=/state
DOCKER_LOG=/tmp/dockerd.log
DOCKER_PID=""
BUNDLED_IMAGES=/opt/saas/saas-images.tar
BUNDLED_IMAGES_CHECKSUM="$STATE_DIR/saas-images.sha256"
export DEV_BOT_EXTRA_COMPOSE_FILE=docker-compose.dev-bot-image.yml
export DEV_BOT_DIND_WRAPPER=1
export DEV_BOT_DIND_STATE_DIR="$STATE_DIR"

usage() {
    echo "Uso: dev-bot start | stop | status | logs"
}

prepare_state() {
    mkdir -p "$STATE_DIR/dev-secrets"
    rm -rf "$PROJECT_DIR/.dev-secrets"
    ln -s "$STATE_DIR/dev-secrets" "$PROJECT_DIR/.dev-secrets"

    rm -f "$PROJECT_DIR/.env.dev.local"
    ln -s "$STATE_DIR/.env.dev.local" "$PROJECT_DIR/.env.dev.local"
}

start_docker() {
    if docker info >/dev/null 2>&1; then
        return 0
    fi

    dockerd-entrypoint.sh >"$DOCKER_LOG" 2>&1 &
    DOCKER_PID=$!

    echo "Inicializando o Docker interno..."
    for _ in $(seq 1 60); do
        if docker info >/dev/null 2>&1; then
            return 0
        fi
        if ! kill -0 "$DOCKER_PID" 2>/dev/null; then
            echo "Erro: Docker interno encerrou durante a inicialização." >&2
            tail -n 100 "$DOCKER_LOG" >&2 || true
            exit 1
        fi
        sleep 1
    done

    echo "Erro: Docker interno não ficou disponível em 60 segundos." >&2
    tail -n 100 "$DOCKER_LOG" >&2 || true
    exit 1
}

load_bundled_images() {
    local current_checksum saved_checksum=""

    if [[ ! -f "$BUNDLED_IMAGES" ]]; then
        echo "Erro: pacote de imagens não encontrado: $BUNDLED_IMAGES" >&2
        exit 1
    fi

    current_checksum="$(sha256sum "$BUNDLED_IMAGES" | cut -d' ' -f1)"
    if [[ -f "$BUNDLED_IMAGES_CHECKSUM" ]]; then
        saved_checksum="$(cat "$BUNDLED_IMAGES_CHECKSUM")"
    fi

    if [[ "$current_checksum" != "$saved_checksum" ]] \
        || ! docker image inspect saas-backend:bundled >/dev/null 2>&1 \
        || ! docker image inspect saas-frontend:bundled >/dev/null 2>&1; then
        echo "Importando imagens pré-compiladas do backend e frontend..."
        docker load --input "$BUNDLED_IMAGES"
        printf '%s\n' "$current_checksum" > "$BUNDLED_IMAGES_CHECKSUM"
    else
        echo "Imagens pré-compiladas já estão carregadas."
    fi
}

shutdown() {
    if [[ -n "$DOCKER_PID" ]] && kill -0 "$DOCKER_PID" 2>/dev/null; then
        cd "$PROJECT_DIR"
        ./stop-dev-bot.sh || true
        kill -TERM "$DOCKER_PID" 2>/dev/null || true
        wait "$DOCKER_PID" 2>/dev/null || true
    fi
}

command_name="${1:-start}"
prepare_state
start_docker
load_bundled_images
cd "$PROJECT_DIR"

case "$command_name" in
    start)
        trap shutdown TERM INT
        if ! ./start-dev-bot.sh; then
            echo "A inicialização falhou. O Docker interno permanecerá ativo para diagnóstico." >&2
            echo "Consulte: docker exec <container> docker logs saas-ngrok-bot --tail 100" >&2
            echo "Depois de corrigir o .env, recrie o contêiner para aplicar as variáveis." >&2
            wait "$DOCKER_PID"
            exit 1
        fi
        echo "Ambiente ativo. Mantenha este contêiner em execução."
        wait "$DOCKER_PID"
        ;;
    stop)
        ./stop-dev-bot.sh "${@:2}"
        ;;
    status)
        docker compose \
            --env-file .env.dev.local \
            -f docker-compose.yml \
            -f docker-compose.override.yml \
            -f docker-compose.dev-bot.yml \
            -f docker-compose.dev-bot-image.yml ps
        ;;
    logs)
        docker compose \
            --env-file .env.dev.local \
            -f docker-compose.yml \
            -f docker-compose.override.yml \
            -f docker-compose.dev-bot.yml \
            -f docker-compose.dev-bot-image.yml logs -f "${@:2}"
        ;;
    *)
        usage >&2
        exit 2
        ;;
esac
