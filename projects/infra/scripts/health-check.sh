#!/bin/bash
# =============================================================================
# Health Check Script — Contador Fiscal Inteligente
# =============================================================================
# ADR-0016: Infrastructure Environment Provisioning
# Run from the project root: bash infra/scripts/health-check.sh
# LOCAL/DEVELOPMENT ONLY. Production must use deploy-production.sh status.
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
REPOSITORY_ROOT="$(cd -- "$SCRIPT_DIR/../.." && pwd -P)"
# shellcheck source=infra/scripts/lib/development-docker-access.sh
source "$SCRIPT_DIR/lib/development-docker-access.sh"

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color
BOLD='\033[1m'

PASS=0
FAIL=0
WARN=0

check_pass() {
    echo -e "  ${GREEN}✅ $1${NC}"
    PASS=$((PASS + 1))
}

check_fail() {
    echo -e "  ${RED}❌ $1${NC}"
    FAIL=$((FAIL + 1))
}

check_warn() {
    echo -e "  ${YELLOW}⚠️  $1${NC}"
    WARN=$((WARN + 1))
}

echo ""
echo -e "${BOLD}=== Contador Fiscal Inteligente — Infrastructure Health Check ===${NC}"
echo -e "${YELLOW}LOCAL/DEVELOPMENT ONLY — use deploy-production.sh status in production${NC}"
echo -e "${BOLD}=== ADR-0016 — $(date '+%Y-%m-%d %H:%M:%S') ===${NC}"
echo ""

# ─────────────────────────────────────────────────────────
# 1. Docker Engine
# ─────────────────────────────────────────────────────────
echo -e "${BOLD}[1/8] Docker Engine${NC}"
if ! require_direct_development_docker_access "$REPOSITORY_ROOT"; then
    check_fail "Docker Engine is not directly accessible to the login user"
    echo ""
    echo -e "${RED}Prepare the host before starting the stack. Aborting.${NC}"
    exit 1
fi
check_pass "Docker Engine running ($(docker --version | awk '{print $3}' | tr -d ','))"

# ─────────────────────────────────────────────────────────
# 2. Docker Compose Containers
# ─────────────────────────────────────────────────────────
echo -e "${BOLD}[2/8] Docker Compose Services${NC}"

EXPECTED_CONTAINERS=("saas-postgres-app" "saas-postgres-keycloak" "saas-keycloak" "saas-redis" "saas-prometheus" "saas-alertmanager" "saas-loki" "saas-grafana")

for container in "${EXPECTED_CONTAINERS[@]}"; do
    status=$(docker inspect -f '{{.State.Status}}' "$container" 2>/dev/null || echo "not_found")
    health=$(docker inspect -f '{{if .State.Health}}{{.State.Health.Status}}{{else}}no-healthcheck{{end}}' "$container" 2>/dev/null || echo "unknown")

    if [ "$status" == "running" ]; then
        if [ "$health" == "healthy" ] || [ "$health" == "no-healthcheck" ]; then
            check_pass "$container — running ($health)"
        else
            check_warn "$container — running but $health"
        fi
    elif [ "$status" == "not_found" ]; then
        check_fail "$container — not found (start through ./start-dev-bot.sh after host bootstrap)"
    else
        check_fail "$container — status: $status"
    fi
done

# ─────────────────────────────────────────────────────────
# 3. PostgreSQL App — 5 Databases
# ─────────────────────────────────────────────────────────
echo -e "${BOLD}[3/8] PostgreSQL App Databases${NC}"

EXPECTED_DBS=("saas_tenant" "saas_certificate" "saas_fiscal" "saas_billing" "saas_whatsapp")

if docker exec saas-postgres-app pg_isready -U saas_app > /dev/null 2>&1; then
    for db in "${EXPECTED_DBS[@]}"; do
        if docker exec saas-postgres-app psql -U saas_app -d "$db" -c "SELECT 1" > /dev/null 2>&1; then
            check_pass "Database $db exists and accessible"
        else
            check_fail "Database $db missing or inaccessible"
        fi
    done
else
    check_fail "PostgreSQL App not ready"
fi

# ─────────────────────────────────────────────────────────
# 4. Keycloak
# ─────────────────────────────────────────────────────────
echo -e "${BOLD}[4/8] Keycloak Identity Provider${NC}"

KC_HEALTH=$(curl -sf http://localhost:8180/health/ready 2>/dev/null || echo "unreachable")
if echo "$KC_HEALTH" | grep -q "UP" 2>/dev/null; then
    check_pass "Keycloak health: UP (http://localhost:8180)"
else
    check_fail "Keycloak unreachable at http://localhost:8180/health/ready"
    check_warn "Do not reset production realms; use the versioned Keycloak migration procedure"
fi

# ─────────────────────────────────────────────────────────
# 5. Redis
# ─────────────────────────────────────────────────────────
echo -e "${BOLD}[5/8] Redis Cache${NC}"

REDIS_PONG=$(docker exec saas-redis sh -c 'REDISCLI_AUTH="$REDIS_PASSWORD" redis-cli ping' 2>/dev/null || echo "FAIL")
if [ "$REDIS_PONG" == "PONG" ]; then
    check_pass "Redis responding: PONG"
else
    check_fail "Redis not responding (Backend login will return HTTP 500)"
fi

# ─────────────────────────────────────────────────────────
# 6. Prometheus
# ─────────────────────────────────────────────────────────
echo -e "${BOLD}[6/8] Prometheus Metrics${NC}"

PROM_STATUS=$(curl -sf http://localhost:9090/-/ready 2>/dev/null || echo "unreachable")
if echo "$PROM_STATUS" | grep -qi "ready" 2>/dev/null; then
    check_pass "Prometheus ready (http://localhost:9090)"
else
    check_warn "Prometheus not ready at http://localhost:9090 (non-blocking)"
fi

# ─────────────────────────────────────────────────────────
# 7. Grafana
# ─────────────────────────────────────────────────────────
echo -e "${BOLD}[7/8] Grafana Dashboards${NC}"

GRAFANA_STATUS=$(curl -sf -o /dev/null -w "%{http_code}" http://localhost:3001/api/health 2>/dev/null || echo "000")
if [ "$GRAFANA_STATUS" == "200" ]; then
    check_pass "Grafana healthy (http://localhost:3001)"
else
    check_warn "Grafana not accessible at http://localhost:3001 (non-blocking)"
fi

# ─────────────────────────────────────────────────────────
# 8. Port Availability (Backend & Frontend)
# ─────────────────────────────────────────────────────────
echo -e "${BOLD}[8/8] Port Availability for Backend & Frontend${NC}"

for port_info in "8080:Backend" "3000:Frontend"; do
    port="${port_info%%:*}"
    name="${port_info##*:}"

    pid=$(ss -tlnp | grep ":${port}\b" | head -1 | grep -oP 'pid=\K[0-9]+' || echo "")
    if [ -z "$pid" ]; then
        check_pass "Port $port available for $name"
    else
        proc_name=$(ps -p "$pid" -o comm= 2>/dev/null || echo "unknown")
        check_warn "Port $port in use by $proc_name (PID $pid) — $name may not start"
    fi
done

# ─────────────────────────────────────────────────────────
# Summary
# ─────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}=== Summary ===${NC}"
echo -e "  ${GREEN}Passed: $PASS${NC}"
echo -e "  ${YELLOW}Warnings: $WARN${NC}"
echo -e "  ${RED}Failed: $FAIL${NC}"
echo ""

if [ "$FAIL" -gt 0 ]; then
    echo -e "${RED}${BOLD}⛔ Infrastructure has $FAIL failure(s). See ADR-0016 Section 8 (Troubleshooting).${NC}"
    exit 1
elif [ "$WARN" -gt 0 ]; then
    echo -e "${YELLOW}${BOLD}⚠️  Infrastructure OK with $WARN warning(s).${NC}"
    exit 0
else
    echo -e "${GREEN}${BOLD}🚀 All checks passed! Ready for development.${NC}"
    exit 0
fi
