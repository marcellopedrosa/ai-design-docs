#!/usr/bin/env bash

set -Eeuo pipefail

REPOSITORY_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
TEMPLATE_FILE="$REPOSITORY_ROOT/infra/keycloak/themes/saas-theme/login/template.ftl"
LOGIN_TEMPLATE_FILE="$REPOSITORY_ROOT/infra/keycloak/themes/saas-theme/login/login.ftl"
RESET_TEMPLATE_FILE="$REPOSITORY_ROOT/infra/keycloak/themes/saas-theme/login/login-reset-password.ftl"
STYLES_FILE="$REPOSITORY_ROOT/infra/keycloak/themes/saas-theme/login/resources/css/styles.css"
EXPECTED_RIGHT_TEMPLATE_HASH="a859c3df66a4e1497365684b1edb9a0c3b27b50f270079af75435ac5aa685859"
EXPECTED_RIGHT_STYLES_HASH="a1eb2308cc1b538a10ef03181cd985972d6af7b8d87d7d8f51741ea3c6da1e3c"

fail() {
    echo "FAIL: $*" >&2
    exit 1
}

for command_name in awk grep sha256sum; do
    command -v "$command_name" >/dev/null 2>&1 \
        || fail "required command is unavailable: $command_name"
done

grep -Fq 'class="split-left" aria-label="Apresentação do Contador Fiscal"' "$TEMPLATE_FILE" \
    || fail "Keycloak theme is missing the accessible product panel"
grep -Fq 'class="login-chart"' "$TEMPLATE_FILE" \
    || fail "Keycloak theme is missing the illustrative fiscal chart"
grep -Fq 'role="img" aria-label="Gráfico demonstrativo de Consultas, DAS e Situação Fiscal nos últimos 30 dias"' "$TEMPLATE_FILE" \
    || fail "Keycloak chart is missing its accessible description"
grep -Fq 'Dados ilustrativos' "$TEMPLATE_FILE" \
    || fail "Keycloak chart must identify its data as illustrative"
grep -Fq 'class="chart-line chart-line-fiscal-status"' "$TEMPLATE_FILE" \
    || fail "Keycloak chart is missing the Situação Fiscal series"

for chart_item in 'Consultas' 'DAS' 'Situação Fiscal'; do
    grep -Fq ">$chart_item<" "$TEMPLATE_FILE" \
        || fail "Keycloak chart is missing legend item: $chart_item"
done

if grep -Fq 'DARFs' "$TEMPLATE_FILE"; then
    fail "Keycloak chart must use DAS instead of DARFs"
fi

for benefit in \
    'Consultas seguras com certificados' \
    'Escalando atendimento para escritórios' \
    'Visão única de operação'; do
    grep -Fq "$benefit" "$TEMPLATE_FILE" \
        || fail "Keycloak product panel is missing benefit: $benefit"
done

if grep -Fq 'bg-business.png' "$TEMPLATE_FILE"; then
    fail "legacy raster hero must not be rendered by the Keycloak theme"
fi
if grep -Fq 'font-serif' "$TEMPLATE_FILE" "$STYLES_FILE"; then
    fail "Keycloak product panel must not use serif typography"
fi

grep -Fq 'displayInfo=realm.password && (realm.resetPasswordAllowed || (realm.registrationAllowed && !registrationDisabled??))' "$LOGIN_TEMPLATE_FILE" \
    || fail "Keycloak password recovery visibility must not depend on public registration"
grep -Fq 'href="${url.loginResetCredentialsUrl}">Esqueceu sua senha?</a>' "$LOGIN_TEMPLATE_FILE" \
    || fail "Keycloak login is missing the native password recovery link"

[ -f "$RESET_TEMPLATE_FILE" ] \
    || fail "Keycloak theme is missing its password recovery form template"

grep -Fq '<#import "template.ftl" as layout>' "$RESET_TEMPLATE_FILE" \
    || fail "Keycloak password recovery form must reuse the shared layout"
grep -Fq 'id="kc-reset-password-form" class="login-form" action="${url.loginAction}" method="post"' "$RESET_TEMPLATE_FILE" \
    || fail "Keycloak password recovery form must preserve the native POST contract"
grep -Fq 'id="username" class="form-input" name="username"' "$RESET_TEMPLATE_FILE" \
    || fail "Keycloak password recovery form must preserve the native username field"
grep -Fq "value=\"\${(auth.attemptedUsername!'')}\"" "$RESET_TEMPLATE_FILE" \
    || fail "Keycloak password recovery form must preserve the attempted username"
grep -Fq "aria-invalid=\"<#if messagesPerField.existsError('username')>true</#if>\"" "$RESET_TEMPLATE_FILE" \
    || fail "Keycloak password recovery field must expose its invalid state"
grep -Fq 'id="input-error-username" class="input-error" aria-live="polite"' "$RESET_TEMPLATE_FILE" \
    || fail "Keycloak password recovery error must be announced accessibly"
grep -Fq "\${kcSanitize(messagesPerField.get('username'))?no_esc}" "$RESET_TEMPLATE_FILE" \
    || fail "Keycloak password recovery error must remain sanitized"
grep -Fq 'href="${url.loginUrl}"' "$RESET_TEMPLATE_FILE" \
    || fail "Keycloak password recovery form must return through the native login URL"

for reset_class in \
    'login-form' \
    'form-group' \
    'input-label' \
    'input-wrapper' \
    'form-input' \
    'btn-primary' \
    'auth-links'; do
    grep -Fq "class=\"$reset_class\"" "$RESET_TEMPLATE_FILE" \
        || fail "Keycloak password recovery form is missing visual class: $reset_class"
done

for reset_message in \
    'msg("emailForgotTitle")' \
    'msg("usernameOrEmail")' \
    'msg("emailInstructionUsername")' \
    'msg("emailInstruction")' \
    'msg("doSubmit")' \
    'msg("backToLogin")'; do
    grep -Fq "$reset_message" "$RESET_TEMPLATE_FILE" \
        || fail "Keycloak password recovery form is missing native message: $reset_message"
done

if grep -Eq '/login-actions/|<script' "$RESET_TEMPLATE_FILE"; then
    fail "Keycloak password recovery form must not replace the native flow"
fi

awk '
    index($0, "<#if realm.registrationAllowed && !registrationDisabled??>") {
        inside_registration_guard = 1
        admin_card_found = 0
        next
    }
    inside_registration_guard && index($0, "class=\"admin-card\"") {
        admin_card_found = 1
    }
    inside_registration_guard && index($0, "</#if>") {
        if (admin_card_found) {
            guarded_admin_card = 1
        }
        inside_registration_guard = 0
    }
    END { exit guarded_admin_card ? 0 : 1 }
' "$LOGIN_TEMPLATE_FILE" \
    || fail "Keycloak administrative card must preserve its registration visibility guard"

left_styles="$(awk '/\/\* Left Side \*\//,/\/\* Right Side \*\//' "$STYLES_FILE")"
grep -Fq 'font-family: var(--font-family);' <<< "$left_styles" \
    || fail "Keycloak product panel does not use the system font family"
grep -Fq '.login-chart {' <<< "$left_styles" \
    || fail "Keycloak chart styles are missing"

right_template_hash="$(awk '/<!-- Lado Direito: Formulário -->/,0' "$TEMPLATE_FILE" \
    | sha256sum \
    | awk '{print $1}')"
[ "$right_template_hash" = "$EXPECTED_RIGHT_TEMPLATE_HASH" ] \
    || fail "Keycloak right-side template changed"

right_styles_hash="$(awk '/\/\* Right Side \*\//,0' "$STYLES_FILE" \
    | sha256sum \
    | awk '{print $1}')"
[ "$right_styles_hash" = "$EXPECTED_RIGHT_STYLES_HASH" ] \
    || fail "Keycloak right-side styles changed"

echo "PASS: Keycloak login product panel matches the visual contract and preserves the form"
