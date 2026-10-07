#!/bin/sh
set -eu
export KEYCLOAK_PROVISION_ENV=hml
export KEYCLOAK_FRONTEND_REDIRECTS='https://app-hml.contadorfiscal.com.br/*'
export KEYCLOAK_FRONTEND_ORIGINS='https://app-hml.contadorfiscal.com.br'
export KEYCLOAK_REALM_SMTP_PASSWORD="${TF_VAR_contadorfiscal_smtp_password:?TF_VAR_contadorfiscal_smtp_password is required}"
exec /opt/keycloak/provision/provision-realms.sh "$@"
