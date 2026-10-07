#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$PROJECT_DIR/infra/scripts/lib/development-docker-access.sh"

if [[ -n "${DOCKER_HOST:-}" && "${DOCKER_HOST}" != "unix:///var/run/docker.sock" ]]; then
    echo "Erro: reset global permite somente o socket Docker local /var/run/docker.sock." >&2
    exit 1
fi

if ! require_direct_development_docker_access "$PROJECT_DIR"; then
    exit 1
fi

docker_endpoint="$(docker context inspect --format '{{.Endpoints.docker.Host}}')"
if [[ "$docker_endpoint" != "unix:///var/run/docker.sock" ]]; then
    echo "Erro: reset global permite somente o contexto Docker local /var/run/docker.sock." >&2
    exit 1
fi

cat <<'AVISO'
ATENÇÃO: esta limpeza afeta todo o Docker acessado por este terminal,
não apenas o projeto ou diretório atual.

Remove todos os contêineres, inclusive os que estão em execução,
e limpa imagens, redes e cache não utilizados.
Também exclui volumes não utilizados, inclusive os nomeados,
apagando os dados armazenados neles. Faça backup antes de continuar.
AVISO

if [[ ! -t 0 ]] || ! read -r -p "Digite LIMPAR para continuar: " confirmacao || [[ "$confirmacao" != "LIMPAR" ]]; then
    echo "Operação cancelada."
    exit 1
fi

echo "[1/4] Removendo contêineres..."
containers="$(docker ps -aq)"
if [[ -n "$containers" ]]; then
    # A separação dos IDs em argumentos é intencional.
    # shellcheck disable=SC2086
    docker rm -f $containers
fi

echo "[2/4] Removendo imagens..."
imagens="$(docker image ls -q | sort -u)"
if [[ -n "$imagens" ]]; then
    # shellcheck disable=SC2086
    if ! docker rmi $imagens; then
        echo "Aviso: algumas imagens não foram removidas; continuando com o prune." >&2
    fi
fi

echo "[3/4] Limpando recursos não utilizados..."
docker system prune -a -f

echo "[4/4] Removendo volumes não utilizados..."
docker volume prune -a -f

echo "Comandos de limpeza finalizados. Verifique eventuais avisos acima."
