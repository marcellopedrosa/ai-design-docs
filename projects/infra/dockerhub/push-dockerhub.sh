#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$PROJECT_DIR"

if [[ "$#" -gt 1 ]]; then
  echo "Uso: $0 [TAG]" >&2
  echo "Exemplo: $0 1.0.0" >&2
  exit 2
fi

DOCKERHUB_NAMESPACE="${DOCKERHUB_NAMESPACE:-djmarcellopedrosa}"
DOCKERHUB_LOGIN="${DOCKERHUB_LOGIN:-${DOCKERHUB_NAMESPACE}}"
DOCKERHUB_LOGIN_BEFORE_PUSH="${DOCKERHUB_LOGIN_BEFORE_PUSH:-false}"
IMAGE_REPOSITORY="${IMAGE_REPOSITORY:-saas-service}"
IMAGE_VERSION="${1:-${IMAGE_VERSION:-latest}}"
BUILD_CONTEXT="${BUILD_CONTEXT:-.}"
DOCKERFILE="${DOCKERFILE:-Dockerfile.dev-bot}"
TARGET_PLATFORM="${TARGET_PLATFORM:-linux/amd64}"
BUNDLE_DIR="${BUNDLE_DIR:-.docker-bundle}"
BUNDLE_FILE="$BUNDLE_DIR/saas-images.tar"
BACKEND_BUNDLE_IMAGE="saas-backend:bundled"
FRONTEND_BUNDLE_IMAGE="saas-frontend:bundled"
NEXT_PUBLIC_API_BASE_URL="${NEXT_PUBLIC_API_BASE_URL:-http://localhost:8080}"
NEXT_PUBLIC_KEYCLOAK_URL="${NEXT_PUBLIC_KEYCLOAK_URL:-http://localhost:8180}"
NEXT_PUBLIC_KEYCLOAK_REALM="${NEXT_PUBLIC_KEYCLOAK_REALM:-saas-bpfarias}"
NEXT_PUBLIC_KEYCLOAK_CLIENT_ID="${NEXT_PUBLIC_KEYCLOAK_CLIENT_ID:-saas-frontend-spa}"

cleanup() {
  rm -f "$BUNDLE_FILE"
  rmdir "$BUNDLE_DIR" 2>/dev/null || true
}
trap cleanup EXIT

IMAGE="${DOCKERHUB_NAMESPACE}/${IMAGE_REPOSITORY}"

if [[ ! "${DOCKERHUB_NAMESPACE}" =~ ^[a-z0-9]+([._-][a-z0-9]+)*$ ]]; then
  echo "Erro: namespace inválido para o Docker Hub: ${DOCKERHUB_NAMESPACE}" >&2
  exit 1
fi

if [[ ! "${IMAGE_VERSION}" =~ ^[A-Za-z0-9_][A-Za-z0-9_.-]{0,127}$ ]]; then
  echo "Erro: tag Docker inválida: ${IMAGE_VERSION}" >&2
  echo "Use, por exemplo: 1.0.0, 1.0.0-rc.1 ou latest." >&2
  exit 1
fi

if [[ ! -f "${DOCKERFILE}" ]]; then
  echo "Erro: Dockerfile não encontrado: ${DOCKERFILE}" >&2
  exit 1
fi

command -v docker >/dev/null 2>&1 || {
  echo "Erro: o comando docker não está instalado." >&2
  exit 1
}

DOCKER=(docker)
if ! docker info >/dev/null 2>&1; then
  if [[ "${EUID}" -ne 0 ]] && command -v sudo >/dev/null 2>&1; then
    echo "Docker sem acesso à API como usuário atual; usando sudo."
    DOCKER=(sudo docker)
  else
    echo "Erro: não foi possível acessar a API do Docker em /var/run/docker.sock." >&2
    exit 1
  fi
fi

if [[ "${DOCKERHUB_LOGIN_BEFORE_PUSH}" == "true" ]]; then
  echo "Autenticando no Docker Hub como ${DOCKERHUB_LOGIN}..."
  "${DOCKER[@]}" login --username "${DOCKERHUB_LOGIN}"
else
  echo "Usando as credenciais do Docker Hub já armazenadas pelo Docker."
fi

echo "Compilando a imagem do backend..."
"${DOCKER[@]}" buildx build \
  --platform "${TARGET_PLATFORM}" \
  --file backend/app/Dockerfile \
  --tag "${BACKEND_BUNDLE_IMAGE}" \
  --load \
  backend

echo "Compilando a imagem do frontend para localhost..."
"${DOCKER[@]}" buildx build \
  --platform "${TARGET_PLATFORM}" \
  --file frontend/app/Dockerfile \
  --build-arg "NEXT_PUBLIC_API_BASE_URL=${NEXT_PUBLIC_API_BASE_URL}" \
  --build-arg "NEXT_PUBLIC_KEYCLOAK_URL=${NEXT_PUBLIC_KEYCLOAK_URL}" \
  --build-arg "NEXT_PUBLIC_KEYCLOAK_REALM=${NEXT_PUBLIC_KEYCLOAK_REALM}" \
  --build-arg "NEXT_PUBLIC_KEYCLOAK_CLIENT_ID=${NEXT_PUBLIC_KEYCLOAK_CLIENT_ID}" \
  --build-arg "NEXT_PUBLIC_APP_NAME=Contador Fiscal" \
  --tag "${FRONTEND_BUNDLE_IMAGE}" \
  --load \
  frontend

echo "Empacotando as imagens pré-compiladas..."
mkdir -p "$BUNDLE_DIR"
"${DOCKER[@]}" image save \
  --output "$BUNDLE_FILE" \
  "$BACKEND_BUNDLE_IMAGE" \
  "$FRONTEND_BUNDLE_IMAGE"

echo "Construindo e publicando ${IMAGE}:${IMAGE_VERSION} para ${TARGET_PLATFORM}..."
PUBLISH_TAGS=(--tag "${IMAGE}:${IMAGE_VERSION}")
if [[ "${IMAGE_VERSION}" != "latest" ]]; then
  PUBLISH_TAGS+=(--tag "${IMAGE}:latest")
  echo "A mesma imagem também será publicada como ${IMAGE}:latest."
fi

"${DOCKER[@]}" buildx build \
  --platform "${TARGET_PLATFORM}" \
  --file "${DOCKERFILE}" \
  --build-context "bundled-images=${BUNDLE_DIR}" \
  "${PUBLISH_TAGS[@]}" \
  --push \
  "${BUILD_CONTEXT}"

echo "Imagem publicada: ${IMAGE}:${IMAGE_VERSION}"
if [[ "${IMAGE_VERSION}" != "latest" ]]; then
  echo "Imagem publicada: ${IMAGE}:latest"
fi
echo "Docker Hub: https://hub.docker.com/r/${IMAGE}"
