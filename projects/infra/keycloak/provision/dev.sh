#!/bin/sh
set -eu
export KEYCLOAK_PROVISION_ENV=dev
export KEYCLOAK_FRONTEND_REDIRECTS='http://localhost:3000/*,http://app.agentefiscal.local/*'
export KEYCLOAK_FRONTEND_ORIGINS='http://localhost:3000,http://app.agentefiscal.local'
exec /opt/keycloak/provision/provision-realms.sh "$@"
