#!/bin/sh
set -eu
export KEYCLOAK_PROVISION_ENV=production
export KEYCLOAK_FRONTEND_REDIRECTS="${PUBLIC_APP_URL:?PUBLIC_APP_URL is required}/*"
export KEYCLOAK_FRONTEND_ORIGINS="${PUBLIC_APP_URL:?PUBLIC_APP_URL is required}"
export KEYCLOAK_REALM_SMTP_PASSWORD="${TF_VAR_contadorfiscal_smtp_password:?TF_VAR_contadorfiscal_smtp_password is required}"
exec /opt/keycloak/provision/provision-realms.sh "$@"
