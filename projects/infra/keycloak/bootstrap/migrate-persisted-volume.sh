#!/usr/bin/env bash

# One-time local recovery for persisted Keycloak contracts: permanent
# client_credentials provisioning, explicit SPA role scopes and the approved
# DEV conversation-audit entitlement. No permanent human credential is passed
# to the application or written to disk.
set -Eeuo pipefail
umask 077

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
cd "$PROJECT_DIR"
# shellcheck source=infra/scripts/lib/development-docker-access.sh
source "$PROJECT_DIR/infra/scripts/lib/development-docker-access.sh"

command -v openssl >/dev/null 2>&1 || {
    echo "ERROR: openssl is required for temporary recovery credentials." >&2
    exit 1
}

ENV_FILES=(--env-file "$PROJECT_DIR/.env.dev.local")
if [ -f "$PROJECT_DIR/.env" ]; then
    ENV_FILES+=(--env-file "$PROJECT_DIR/.env")
fi
COMPOSE_FILES=(-f docker-compose.yml -f docker-compose.override.yml)

resolve_managed_realm_allowlist() {
    local resolved_value=""
    local env_file line_count realm_name
    local admin_realm_seen=false
    local -a realm_names=()
    local -A seen_realms=()

    if [ "${KEYCLOAK_EXISTING_MANAGED_REALMS+x}" = x ]; then
        resolved_value="$KEYCLOAK_EXISTING_MANAGED_REALMS"
    else
        for env_file in "$PROJECT_DIR/.env.dev.local" "$PROJECT_DIR/.env"; do
            [ -f "$env_file" ] || continue
            line_count="$(grep -c '^KEYCLOAK_EXISTING_MANAGED_REALMS=' "$env_file" || true)"
            if [ "$line_count" -gt 1 ]; then
                echo "ERROR: $env_file contains duplicate KEYCLOAK_EXISTING_MANAGED_REALMS entries." >&2
                exit 1
            fi
            if [ "$line_count" -eq 1 ]; then
                resolved_value="$(sed -n 's/^KEYCLOAK_EXISTING_MANAGED_REALMS=//p' "$env_file")"
            fi
        done
    fi

    if [[ ! "$resolved_value" =~ ^saas-[a-z0-9][a-z0-9-]*(,saas-[a-z0-9][a-z0-9-]*)*$ ]]; then
        echo "ERROR: KEYCLOAK_EXISTING_MANAGED_REALMS must be a non-empty, exact comma-separated SaaS realm allowlist without whitespace." >&2
        exit 1
    fi

    IFS=',' read -r -a realm_names <<< "$resolved_value"
    for realm_name in "${realm_names[@]}"; do
        if [ -n "${seen_realms[$realm_name]+x}" ]; then
            echo "ERROR: KEYCLOAK_EXISTING_MANAGED_REALMS must not contain duplicate realms." >&2
            exit 1
        fi
        seen_realms["$realm_name"]=1
        if [ "$realm_name" = saas-admin ]; then
            admin_realm_seen=true
        fi
    done
    if [ "$admin_realm_seen" != true ]; then
        echo "ERROR: the local persisted-volume migration requires saas-admin in KEYCLOAK_EXISTING_MANAGED_REALMS." >&2
        exit 1
    fi

    KEYCLOAK_EXISTING_MANAGED_REALMS="$resolved_value"
    export KEYCLOAK_EXISTING_MANAGED_REALMS
}

require_direct_development_docker_access "$PROJECT_DIR"
resolve_managed_realm_allowlist

COMPOSE=(docker compose)

RECOVERY_ADMIN_USERNAME="saas-recovery-user-$(openssl rand -hex 6)"
RECOVERY_ADMIN_PASSWORD="$(openssl rand -hex 32)"
export RECOVERY_ADMIN_USERNAME RECOVERY_ADMIN_PASSWORD

wait_for_keycloak() {
    echo "Waiting for Keycloak to become healthy..."
    for _ in $(seq 1 60); do
        if "${COMPOSE[@]}" "${ENV_FILES[@]}" "${COMPOSE_FILES[@]}" ps --format json keycloak 2>/dev/null \
                | grep -q '"Health":"healthy"'; then
            return 0
        fi
        sleep 2
    done
    echo "ERROR: Keycloak did not become healthy within 120 seconds." >&2
    return 1
}

wait_for_postgres_keycloak() {
    echo "Waiting for the Keycloak database to become healthy..."
    for _ in $(seq 1 30); do
        if "${COMPOSE[@]}" "${ENV_FILES[@]}" "${COMPOSE_FILES[@]}" ps --format json postgres-keycloak 2>/dev/null \
                | grep -q '"Health":"healthy"'; then
            return 0
        fi
        sleep 2
    done
    echo "ERROR: Keycloak PostgreSQL did not become healthy within 60 seconds." >&2
    return 1
}

remove_recovery_identities() {
    echo "Removing all temporary recovery identities..."
    "${COMPOSE[@]}" "${ENV_FILES[@]}" "${COMPOSE_FILES[@]}" run --rm --no-deps \
        -e RECOVERY_ADMIN_USERNAME \
        -e RECOVERY_ADMIN_PASSWORD \
        --entrypoint /bin/sh keycloak -c '
            set -eu
            umask 077
            config=/tmp/kcadm-recovery.config
            clients_file=/tmp/kcadm-recovery-clients.json
            users_file=/tmp/kcadm-recovery-users.json
            current_user_file=/tmp/kcadm-current-recovery-user.json
            parsed_page_file=/tmp/kcadm-recovery-page.tsv
            records_page_file=/tmp/kcadm-recovery-records.tsv
            item_page_file=/tmp/kcadm-recovery-items.tsv
            candidate_page_file=/tmp/kcadm-recovery-candidates.tsv
            stale_clients_file=/tmp/kcadm-stale-recovery-clients.csv
            stale_users_file=/tmp/kcadm-stale-recovery-users.csv
            seen_client_ids_file=/tmp/kcadm-seen-recovery-client-ids.csv
            seen_user_ids_file=/tmp/kcadm-seen-recovery-user-ids.csv
            runtime_json_validator=/opt/keycloak/bootstrap/validate-keycloak-runtime-json.sh
            trap '\''rm -f "$config" "$clients_file" "$users_file" "$current_user_file" "$parsed_page_file" "$records_page_file" "$item_page_file" "$candidate_page_file" "$stale_clients_file" "$stale_users_file" "$seen_client_ids_file" "$seen_user_ids_file"'\'' EXIT
            [ -f "$runtime_json_validator" ] && [ -r "$runtime_json_validator" ] || {
                echo "ERROR: Structural Keycloak runtime JSON validator is unavailable." >&2
                exit 1
            }
            KC_CLI_PASSWORD="$RECOVERY_ADMIN_PASSWORD" \
            /opt/keycloak/bin/kcadm.sh config credentials \
                --config "$config" \
                --server http://keycloak:8080 \
                --realm master \
                --user "$RECOVERY_ADMIN_USERNAME" \
                </dev/null >/dev/null
            chmod 600 "$config"

            /opt/keycloak/bin/kcadm.sh get users \
                --config "$config" \
                -r master \
                -q "username=$RECOVERY_ADMIN_USERNAME" \
                -q exact=true \
                -q first=0 \
                -q max=2 \
                --fields id,username > "$current_user_file"

            tab_character="$(printf "\t")"

            parse_recovery_page() {
                recovery_page_kind="$1"
                recovery_page_json="$2"
                if ! /bin/bash "$runtime_json_validator" \
                        recovery-page "$recovery_page_json" "$recovery_page_kind" \
                        > "$parsed_page_file"; then
                    echo "ERROR: Could not classify the recovery $recovery_page_kind page structurally." >&2
                    exit 1
                fi
                recovery_page_header="$(sed -n "1p" "$parsed_page_file" | tr -d "\r")"
                case "$recovery_page_header" in
                    count=*)
                        page_count="${recovery_page_header#count=}"
                        ;;
                    *)
                        echo "ERROR: Structural recovery-page classifier returned no valid count." >&2
                        exit 1
                        ;;
                esac
                case "$page_count" in
                    ""|*[!0-9]*)
                        echo "ERROR: Structural recovery-page classifier returned an invalid count." >&2
                        exit 1
                        ;;
                esac
                if [ "$page_count" -gt 100 ] \
                        || [ "$(grep -c "^count=" "$parsed_page_file")" -ne 1 ]; then
                    echo "ERROR: Structural recovery-page classifier returned an ambiguous count." >&2
                    exit 1
                fi
                sed "1d" "$parsed_page_file" > "$records_page_file"
                : > "$item_page_file"
                : > "$candidate_page_file"
                item_record_count=0
                while IFS="$tab_character" read -r recovery_record recovery_field_one recovery_field_two recovery_extra \
                        || [ -n "$recovery_record$recovery_field_one$recovery_field_two$recovery_extra" ]; do
                    [ -n "$recovery_record$recovery_field_one$recovery_field_two$recovery_extra" ] || continue
                    case "$recovery_record" in
                        item)
                            case "$recovery_field_one" in
                                0-[0-9a-f]*|1-[0-9a-f]*) ;;
                                *)
                                    echo "ERROR: Structural recovery-page classifier returned an invalid item token." >&2
                                    exit 1
                                    ;;
                            esac
                            if [ -n "$recovery_field_two$recovery_extra" ] \
                                    || grep -Fxq -- "$recovery_field_one" "$item_page_file"; then
                                echo "ERROR: Structural recovery-page classifier returned a duplicate or ambiguous item token." >&2
                                exit 1
                            fi
                            printf "%s\n" "$recovery_field_one" >> "$item_page_file"
                            item_record_count=$((item_record_count + 1))
                            ;;
                        candidate)
                            if [ -z "$recovery_field_one" ] || [ -z "$recovery_field_two" ] \
                                    || [ -n "$recovery_extra" ]; then
                                echo "ERROR: Structural recovery-page classifier returned an ambiguous candidate." >&2
                                exit 1
                            fi
                            printf "candidate\t%s\t%s\n" \
                                "$recovery_field_one" "$recovery_field_two" >> "$candidate_page_file"
                            ;;
                        *)
                            echo "ERROR: Structural recovery-page classifier returned an unknown record." >&2
                            exit 1
                            ;;
                    esac
                done < "$records_page_file"
                [ "$item_record_count" -eq "$page_count" ] || {
                    echo "ERROR: Structural recovery-page classifier returned an incomplete item inventory." >&2
                    exit 1
                }
            }

            record_recovery_page_items() {
                recovery_item_kind="$1"
                recovery_seen_items_file="$2"
                recovery_item_count=0
                while IFS= read -r recovery_item_token || [ -n "$recovery_item_token" ]; do
                    [ -n "$recovery_item_token" ] || continue
                    recovery_item_count=$((recovery_item_count + 1))
                    if grep -Fxq -- "$recovery_item_token" "$recovery_seen_items_file"; then
                        echo "ERROR: Duplicate or non-advancing recovery $recovery_item_kind page." >&2
                        exit 1
                    fi
                    printf "%s\n" "$recovery_item_token" >> "$recovery_seen_items_file"
                done < "$item_page_file"
                [ "$recovery_item_count" -eq "$page_count" ] || {
                    echo "ERROR: Recovery $recovery_item_kind page item inventory is incomplete." >&2
                    exit 1
                }
            }

            plan_recovery_page_candidates() {
                recovery_candidate_kind="$1"
                recovery_candidate_plan_file="$2"
                recovery_excluded_uuid="${3:-}"
                while IFS="$tab_character" read -r candidate_record candidate_uuid candidate_name candidate_extra \
                        || [ -n "$candidate_record$candidate_uuid$candidate_name$candidate_extra" ]; do
                    [ -n "$candidate_record$candidate_uuid$candidate_name$candidate_extra" ] || continue
                    if [ "$candidate_record" != candidate ] || [ -n "$candidate_extra" ]; then
                        echo "ERROR: Structural recovery-$recovery_candidate_kind candidate row is ambiguous." >&2
                        exit 1
                    fi
                    if [ "$candidate_uuid" = "$recovery_excluded_uuid" ]; then
                        continue
                    fi
                    if grep -Fxq -- "$candidate_uuid" "$recovery_candidate_plan_file"; then
                        echo "ERROR: Duplicate recovery-$recovery_candidate_kind candidate in cleanup plan." >&2
                        exit 1
                    fi
                    printf "%s\n" "$candidate_uuid" >> "$recovery_candidate_plan_file"
                done < "$candidate_page_file"
            }

            delete_recovery_candidates() {
                recovery_resource_kind="$1"
                recovery_delete_plan_file="$2"
                while IFS= read -r recovery_delete_uuid || [ -n "$recovery_delete_uuid" ]; do
                    [ -n "$recovery_delete_uuid" ] || continue
                    /opt/keycloak/bin/kcadm.sh delete "$recovery_resource_kind/$recovery_delete_uuid" \
                        --config "$config" -r master >/dev/null
                done < "$recovery_delete_plan_file"
            }

            parse_recovery_page users "$current_user_file"
            current_user_count="$page_count"
            current_user_uuid=""
            current_user_candidate_count=0
            while IFS="$tab_character" read -r candidate_record candidate_user_uuid candidate_username candidate_extra \
                    || [ -n "$candidate_record$candidate_user_uuid$candidate_username$candidate_extra" ]; do
                [ -n "$candidate_record$candidate_user_uuid$candidate_username$candidate_extra" ] || continue
                if [ "$candidate_record" != candidate ] \
                        || [ "$candidate_username" != "$RECOVERY_ADMIN_USERNAME" ] \
                        || [ -n "$candidate_extra" ]; then
                    echo "ERROR: Exact recovery-user lookup returned an unexpected identity." >&2
                    exit 1
                fi
                current_user_candidate_count=$((current_user_candidate_count + 1))
                current_user_uuid="$candidate_user_uuid"
            done < "$candidate_page_file"
            [ "$current_user_count" -eq 1 ] \
                    && [ "$current_user_candidate_count" -eq 1 ] || {
                echo "ERROR: Expected exactly one temporary recovery administrator; found $current_user_count structural entries and $current_user_candidate_count candidates." >&2
                exit 1
            }

            : > "$stale_clients_file"
            : > "$seen_client_ids_file"
            page_size=100
            max_items=10000
            first=0
            total_count=0
            while :; do
                /opt/keycloak/bin/kcadm.sh get clients \
                    --config "$config" \
                    -r master \
                    -q "first=$first" \
                    -q "max=$page_size" \
                    --fields id,clientId > "$clients_file"
                parse_recovery_page clients "$clients_file"
                record_recovery_page_items client "$seen_client_ids_file"
                plan_recovery_page_candidates client "$stale_clients_file"
                total_count=$((total_count + page_count))
                if [ "$total_count" -gt "$max_items" ]; then
                    echo "ERROR: Recovery client pagination exceeded its bounded item limit." >&2
                    exit 1
                fi
                [ "$page_count" -eq "$page_size" ] || break
                if [ "$total_count" -ge "$max_items" ]; then
                    echo "ERROR: Recovery client pagination reached its limit on a full page." >&2
                    exit 1
                fi
                next_first=$((first + page_count))
                [ "$next_first" -gt "$first" ] || {
                    echo "ERROR: Recovery client pagination did not advance." >&2
                    exit 1
                }
                first="$next_first"
            done

            : > "$stale_users_file"
            : > "$seen_user_ids_file"
            enumerate_recovery_users_for_cleanup() {
                first=0
                total_count=0
                while :; do
                    /opt/keycloak/bin/kcadm.sh get users \
                        --config "$config" \
                        -r master \
                        -q "first=$first" \
                        -q "max=$page_size" \
                        --fields id,username > "$users_file"
                    parse_recovery_page users "$users_file"
                    record_recovery_page_items user "$seen_user_ids_file"
                    plan_recovery_page_candidates user "$stale_users_file" "$current_user_uuid"
                    total_count=$((total_count + page_count))
                    if [ "$total_count" -gt "$max_items" ]; then
                        echo "ERROR: Recovery user pagination exceeded its bounded item limit." >&2
                        exit 1
                    fi
                    [ "$page_count" -eq "$page_size" ] || break
                    if [ "$total_count" -ge "$max_items" ]; then
                        echo "ERROR: Recovery user pagination reached its limit on a full page." >&2
                        exit 1
                    fi
                    next_first=$((first + page_count))
                    [ "$next_first" -gt "$first" ] || {
                        echo "ERROR: Recovery user pagination did not advance." >&2
                        exit 1
                    }
                    first="$next_first"
                done
            }
            enumerate_recovery_users_for_cleanup
            delete_recovery_candidates clients "$stale_clients_file"
            delete_recovery_candidates users "$stale_users_file"

            /opt/keycloak/bin/kcadm.sh delete "users/$current_user_uuid" \
                --config "$config" -r master >/dev/null
        ' || return 1
    RECOVERY_CLEANUP_REQUIRED=false
}

RECOVERY_CLEANUP_REQUIRED=false
cleanup_recovery_on_exit() {
    local exit_status=$?
    local cleanup_status=0
    trap - EXIT INT TERM

    if [ "$RECOVERY_CLEANUP_REQUIRED" = true ]; then
        echo "Attempting emergency cleanup of temporary Keycloak recovery identities..." >&2
        set +e
        "${COMPOSE[@]}" "${ENV_FILES[@]}" "${COMPOSE_FILES[@]}" up -d keycloak >/dev/null 2>&1
        cleanup_status=$?
        if [ "$cleanup_status" -eq 0 ]; then
            wait_for_keycloak
            cleanup_status=$?
        fi
        if [ "$cleanup_status" -eq 0 ]; then
            remove_recovery_identities
            cleanup_status=$?
        fi
        set -e

        if [ "$cleanup_status" -ne 0 ]; then
            echo "CRITICAL: Could not remove recovery administrator $RECOVERY_ADMIN_USERNAME. Resolve Docker/Keycloak and rerun this migration immediately." >&2
            if [ "$exit_status" -eq 0 ]; then
                exit_status=1
            fi
        fi
    fi

    unset RECOVERY_ADMIN_USERNAME RECOVERY_ADMIN_PASSWORD
    exit "$exit_status"
}
trap cleanup_recovery_on_exit EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

run_forced_technical_identity_reconcile() (
    KEYCLOAK_BOOTSTRAP_ADMIN_USER="$RECOVERY_ADMIN_USERNAME"
    KEYCLOAK_BOOTSTRAP_ADMIN_PASSWORD="$RECOVERY_ADMIN_PASSWORD"
    export KEYCLOAK_BOOTSTRAP_ADMIN_USER KEYCLOAK_BOOTSTRAP_ADMIN_PASSWORD

    "${COMPOSE[@]}" "${ENV_FILES[@]}" "${COMPOSE_FILES[@]}" run --rm --no-deps \
        -e KEYCLOAK_BOOTSTRAP_ADMIN_USER \
        -e KEYCLOAK_BOOTSTRAP_ADMIN_PASSWORD \
        -e "KEYCLOAK_EXISTING_MANAGED_REALMS=$KEYCLOAK_EXISTING_MANAGED_REALMS" \
        -e KEYCLOAK_FORCE_RECONCILE=true \
        keycloak-provisioning-init
)

verify_permanent_technical_identity_after_restart() {
    "${COMPOSE[@]}" "${ENV_FILES[@]}" "${COMPOSE_FILES[@]}" run --rm --no-deps \
        -e KEYCLOAK_FORCE_RECONCILE=false \
        -e KEYCLOAK_BOOTSTRAP_ADMIN_USER= \
        -e KEYCLOAK_BOOTSTRAP_ADMIN_PASSWORD= \
        -e KEYCLOAK_BOOTSTRAP_ADMIN_CLIENT_ID= \
        -e KEYCLOAK_BOOTSTRAP_ADMIN_CLIENT_SECRET= \
        keycloak-provisioning-init
}

"${COMPOSE[@]}" "${ENV_FILES[@]}" "${COMPOSE_FILES[@]}" up -d postgres-keycloak
wait_for_postgres_keycloak

echo "Stopping all Keycloak nodes before creating a temporary recovery administrator..."
"${COMPOSE[@]}" "${ENV_FILES[@]}" "${COMPOSE_FILES[@]}" stop keycloak

RECOVERY_CLEANUP_REQUIRED=true
"${COMPOSE[@]}" "${ENV_FILES[@]}" "${COMPOSE_FILES[@]}" run --rm --no-deps \
    -e RECOVERY_ADMIN_USERNAME \
    -e RECOVERY_ADMIN_PASSWORD \
    keycloak bootstrap-admin user \
    --username:env RECOVERY_ADMIN_USERNAME \
    --password:env RECOVERY_ADMIN_PASSWORD \
    --no-prompt

"${COMPOSE[@]}" "${ENV_FILES[@]}" "${COMPOSE_FILES[@]}" up -d keycloak
wait_for_keycloak

run_forced_technical_identity_reconcile

echo "Removing legacy tenant claims from the persisted administrative realm..."
"${COMPOSE[@]}" "${ENV_FILES[@]}" "${COMPOSE_FILES[@]}" run --rm --no-deps \
    -e RECOVERY_ADMIN_USERNAME \
    -e RECOVERY_ADMIN_PASSWORD \
    --entrypoint /bin/sh keycloak -c '
        set -eu
        umask 077
        config=/tmp/kcadm-admin-realm-contract.config
        clients_page_file=/tmp/kcadm-admin-realm-clients-page.csv
        all_clients_file=/tmp/kcadm-admin-realm-all-clients.csv
        managed_clients_file=/tmp/kcadm-admin-realm-managed-clients.csv
        mappers_file=/tmp/kcadm-admin-realm-mappers.csv
        mapper_json=/tmp/kcadm-admin-realm-mapper.json
        scopes_file=/tmp/kcadm-admin-realm-scopes.csv
        scope_edges_file=/tmp/kcadm-admin-realm-scope-edges.psv
        scope_ids_file=/tmp/kcadm-admin-realm-scope-ids.list
        delete_plan_file=/tmp/kcadm-admin-realm-tenant-mapper-delete-plan.psv
        effective_mappers_file=/tmp/kcadm-admin-effective-mappers.csv
        optional_scopes_file=/tmp/kcadm-admin-optional-scopes.csv
        collection_seen_file=/tmp/kcadm-admin-collection-seen.list
        runtime_json_validator=/opt/keycloak/bootstrap/validate-keycloak-runtime-json.sh
        trap '\''rm -f "$config" "$clients_page_file" "$all_clients_file" "$managed_clients_file" "$mappers_file" "$mapper_json" "$scopes_file" "$scope_edges_file" "$scope_ids_file" "$delete_plan_file" "$effective_mappers_file" "$optional_scopes_file" "$collection_seen_file"'\'' EXIT
        [ -f "$runtime_json_validator" ] && [ -r "$runtime_json_validator" ] || {
            echo "ERROR: Structural Keycloak runtime JSON validator is unavailable." >&2
            exit 1
        }
        KC_CLI_PASSWORD="$RECOVERY_ADMIN_PASSWORD" \
        /opt/keycloak/bin/kcadm.sh config credentials \
            --config "$config" \
            --server http://keycloak:8080 \
            --realm master \
            --user "$RECOVERY_ADMIN_USERNAME" \
            </dev/null >/dev/null
        chmod 600 "$config"

        mapper_reconcile_error() {
            echo "ERROR: $*" >&2
            exit 1
        }

        require_uuid() {
            case "$1" in
                ""|*[!0-9a-fA-F-]*)
                    mapper_reconcile_error "$2"
                    ;;
            esac
        }

        is_managed_client_id() {
            case "$1" in
                saas-service-api|saas-frontend-spa)
                    return 0
                    ;;
            esac
            return 1
        }

        append_unique_line() {
            unique_line="$1"
            unique_file="$2"
            duplicate_diagnostic="$3"
            if grep -Fqx "$unique_line" "$unique_file" 2>/dev/null; then
                mapper_reconcile_error "$duplicate_diagnostic"
            fi
            printf "%s\n" "$unique_line" >> "$unique_file"
        }

        fetch_all_admin_clients() {
            : > "$all_clients_file"
            : > "$managed_clients_file"
            : > "$collection_seen_file"
            client_page_size=100
            client_max_items=10000
            client_first=0
            client_total_count=0

            while :; do
                if ! /opt/keycloak/bin/kcadm.sh get clients \
                        --config "$config" \
                        -r saas-admin \
                        -q "first=$client_first" \
                        -q "max=$client_page_size" \
                        --fields id,clientId \
                        --format csv \
                        --noquotes > "$clients_page_file"; then
                    mapper_reconcile_error "Could not enumerate all clients in saas-admin."
                fi

                client_page_count=0
                while IFS=, read -r candidate_client_uuid candidate_client_id extra_client_field \
                        || [ -n "$candidate_client_uuid$candidate_client_id$extra_client_field" ]; do
                    candidate_client_uuid="$(printf "%s" "$candidate_client_uuid" | tr -d "\r")"
                    candidate_client_id="$(printf "%s" "$candidate_client_id" | tr -d "\r")"
                    [ -n "$candidate_client_uuid$candidate_client_id$extra_client_field" ] || continue
                    client_page_count=$((client_page_count + 1))
                    if [ "$client_page_count" -gt "$client_page_size" ] \
                            || [ -n "$extra_client_field" ]; then
                        mapper_reconcile_error "Administrative client pagination returned an oversized or ambiguous page."
                    fi
                    require_uuid "$candidate_client_uuid" \
                        "Invalid administrative client identifier."
                    if ! printf "%s\n" "$candidate_client_id" \
                            | LC_ALL=C grep -Eq "^[A-Za-z0-9_.:-]+$"; then
                        mapper_reconcile_error "Unsafe or ambiguous administrative client identifier."
                    fi
                    append_unique_line \
                        "$candidate_client_uuid" \
                        "$collection_seen_file" \
                        "Duplicate or non-advancing administrative client page."
                    printf "%s,%s\n" \
                        "$candidate_client_uuid" "$candidate_client_id" \
                        >> "$all_clients_file"
                    client_total_count=$((client_total_count + 1))
                    if [ "$client_total_count" -gt "$client_max_items" ]; then
                        mapper_reconcile_error "Administrative client pagination exceeded its bounded item limit."
                    fi
                done < "$clients_page_file"

                [ "$client_page_count" -eq "$client_page_size" ] || break
                if [ "$client_total_count" -ge "$client_max_items" ]; then
                    mapper_reconcile_error "Administrative client pagination reached its limit on a full page."
                fi
                client_next_first=$((client_first + client_page_count))
                if [ "$client_next_first" -le "$client_first" ]; then
                    mapper_reconcile_error "Administrative client pagination did not advance."
                fi
                client_first="$client_next_first"
            done

            for required_client_id in saas-service-api saas-frontend-spa; do
                required_client_count=0
                required_client_uuid=""
                while IFS=, read -r candidate_client_uuid candidate_client_id \
                        || [ -n "$candidate_client_uuid$candidate_client_id" ]; do
                    [ "$candidate_client_id" = "$required_client_id" ] || continue
                    required_client_count=$((required_client_count + 1))
                    required_client_uuid="$candidate_client_uuid"
                done < "$all_clients_file"
                if [ "$required_client_count" -ne 1 ]; then
                    mapper_reconcile_error "Expected exactly one $required_client_id client in saas-admin; found $required_client_count."
                fi
                printf "%s,%s\n" \
                    "$required_client_uuid" "$required_client_id" \
                    >> "$managed_clients_file"
            done
        }

        record_scope_endpoint() {
            scope_resource="$1"
            scope_owner_uuid="$2"
            scope_owner_id="$3"
            scope_assignment_kind="$4"
            : > "$collection_seen_file"
            if ! /opt/keycloak/bin/kcadm.sh get "$scope_resource" \
                    --config "$config" \
                    -r saas-admin \
                    --fields id,name \
                    --format csv \
                    --noquotes > "$scopes_file"; then
                mapper_reconcile_error "Could not enumerate $scope_assignment_kind client scopes in saas-admin."
            fi

            scope_endpoint_count=0
            while IFS=, read -r scope_uuid scope_name extra_scope_field \
                    || [ -n "$scope_uuid$scope_name$extra_scope_field" ]; do
                scope_uuid="$(printf "%s" "$scope_uuid" | tr -d "\r")"
                scope_name="$(printf "%s" "$scope_name" | tr -d "\r")"
                [ -n "$scope_uuid$scope_name$extra_scope_field" ] || continue
                scope_endpoint_count=$((scope_endpoint_count + 1))
                if [ "$scope_endpoint_count" -gt 10000 ] \
                        || [ -n "$extra_scope_field" ]; then
                    mapper_reconcile_error "Client-scope inventory exceeded its bounded limit or was ambiguous."
                fi
                require_uuid "$scope_uuid" "Invalid client-scope identifier in saas-admin."
                if ! printf "%s\n" "$scope_name" \
                        | LC_ALL=C grep -Eq "^[A-Za-z0-9_.:-]+$"; then
                    mapper_reconcile_error "Unsafe or ambiguous client-scope name in saas-admin."
                fi
                append_unique_line \
                    "$scope_uuid" \
                    "$collection_seen_file" \
                    "Duplicate client scope returned by one assignment endpoint."
                append_unique_line \
                    "$scope_uuid|$scope_name|$scope_owner_uuid|$scope_owner_id|$scope_assignment_kind" \
                    "$scope_edges_file" \
                    "Duplicate client-scope ownership edge in saas-admin."
                if ! grep -Fxq "$scope_uuid" "$scope_ids_file" 2>/dev/null; then
                    printf "%s\n" "$scope_uuid" >> "$scope_ids_file"
                fi
            done < "$scopes_file"
        }

        record_all_scope_ownership() {
            : > "$scope_edges_file"
            : > "$scope_ids_file"
            while IFS=, read -r scope_client_uuid scope_client_id \
                    || [ -n "$scope_client_uuid$scope_client_id" ]; do
                [ -n "$scope_client_uuid$scope_client_id" ] || continue
                record_scope_endpoint \
                    "clients/$scope_client_uuid/default-client-scopes" \
                    "$scope_client_uuid" "$scope_client_id" client-default
                record_scope_endpoint \
                    "clients/$scope_client_uuid/optional-client-scopes" \
                    "$scope_client_uuid" "$scope_client_id" client-optional
            done < "$all_clients_file"
            record_scope_endpoint \
                default-default-client-scopes REALM REALM realm-default
            record_scope_endpoint \
                default-optional-client-scopes REALM REALM realm-optional
        }

        get_mapper_json() {
            mapper_resource="$1"
            if ! /opt/keycloak/bin/kcadm.sh get "$mapper_resource" \
                --config "$config" \
                -r saas-admin \
                    > "$mapper_json"; then
                mapper_reconcile_error "Could not inspect protocol mapper $mapper_resource."
            fi
        }

        inspect_mapper_structure() {
            mapper_expected_client_id="$1"
            if ! mapper_structural_result="$(/bin/bash "$runtime_json_validator" \
                    mapper "$mapper_json" "$mapper_expected_client_id")"; then
                mapper_reconcile_error "Could not classify protocol mapper JSON structurally."
            fi
            case "$mapper_structural_result" in
                "emits=true fingerprint=managed")
                    mapper_emits_tenant=true
                    mapper_managed_fingerprint=true
                    ;;
                "emits=true fingerprint=unknown")
                    mapper_emits_tenant=true
                    mapper_managed_fingerprint=false
                    ;;
                "emits=false fingerprint=managed")
                    mapper_emits_tenant=false
                    mapper_managed_fingerprint=true
                    ;;
                "emits=false fingerprint=unknown")
                    mapper_emits_tenant=false
                    mapper_managed_fingerprint=false
                    ;;
                *)
                    mapper_reconcile_error "Structural mapper classifier returned an unexpected result."
                    ;;
            esac
        }

        inspect_direct_mappers() {
            inspection_mode="$1"
            while IFS=, read -r inventory_client_uuid inventory_client_id \
                    || [ -n "$inventory_client_uuid$inventory_client_id" ]; do
                [ -n "$inventory_client_uuid$inventory_client_id" ] || continue
                : > "$collection_seen_file"
                if ! /opt/keycloak/bin/kcadm.sh get \
                        "clients/$inventory_client_uuid/protocol-mappers/models" \
                        --config "$config" \
                        -r saas-admin \
                        --fields id \
                        --format csv \
                        --noquotes > "$mappers_file"; then
                    mapper_reconcile_error "Could not enumerate direct protocol mappers for $inventory_client_id."
                fi
                mapper_count=0
                while IFS= read -r mapper_uuid || [ -n "$mapper_uuid" ]; do
                    mapper_uuid="$(printf "%s" "$mapper_uuid" | tr -d "\r")"
                    [ -n "$mapper_uuid" ] || continue
                    mapper_count=$((mapper_count + 1))
                    if [ "$mapper_count" -gt 10000 ]; then
                        mapper_reconcile_error "Direct protocol-mapper inventory exceeded its bounded limit."
                    fi
                    require_uuid "$mapper_uuid" \
                        "Invalid direct protocol-mapper identifier in saas-admin."
                    append_unique_line \
                        "$mapper_uuid" \
                        "$collection_seen_file" \
                        "Duplicate direct protocol mapper returned for one client."
                    get_mapper_json \
                        "clients/$inventory_client_uuid/protocol-mappers/models/$mapper_uuid"
                    inspect_mapper_structure "$inventory_client_id"
                    if [ "$mapper_emits_tenant" = true ]; then
                        if [ "$inspection_mode" = post ]; then
                            mapper_reconcile_error "A residual direct mapper still emits tenant_id on $inventory_client_id."
                        fi
                        if ! is_managed_client_id "$inventory_client_id"; then
                            mapper_reconcile_error "A tenant_id mapper belongs to unmanaged client $inventory_client_id; no mapper was removed."
                        fi
                        if [ "$mapper_managed_fingerprint" != true ]; then
                            mapper_reconcile_error "A direct tenant_id mapper has an unknown managed-origin fingerprint; no mapper was removed."
                        fi
                        append_unique_line \
                            "client|$inventory_client_uuid|$mapper_uuid" \
                            "$delete_plan_file" \
                            "Duplicate direct mapper in the bounded deletion plan."
                    fi
                done < "$mappers_file"
            done < "$all_clients_file"
        }

        inspect_scope_mappers() {
            inspection_mode="$1"
            while IFS= read -r inventory_scope_uuid || [ -n "$inventory_scope_uuid" ]; do
                [ -n "$inventory_scope_uuid" ] || continue
                scope_consumer_count=0
                scope_consumer_uuid=""
                scope_consumer_id=""
                scope_has_realm_owner=false
                while IFS="|" read -r edge_scope_uuid edge_scope_name \
                        edge_owner_uuid edge_owner_id edge_assignment_kind \
                        || [ -n "$edge_scope_uuid$edge_scope_name$edge_owner_uuid$edge_owner_id$edge_assignment_kind" ]; do
                    [ "$edge_scope_uuid" = "$inventory_scope_uuid" ] || continue
                    scope_consumer_count=$((scope_consumer_count + 1))
                    scope_consumer_uuid="$edge_owner_uuid"
                    scope_consumer_id="$edge_owner_id"
                    case "$edge_assignment_kind" in
                        realm-default|realm-optional)
                            scope_has_realm_owner=true
                            ;;
                    esac
                done < "$scope_edges_file"
                if [ "$scope_consumer_count" -eq 0 ]; then
                    mapper_reconcile_error "A discovered client scope has no attributable owner."
                fi

                : > "$collection_seen_file"
                if ! /opt/keycloak/bin/kcadm.sh get \
                        "client-scopes/$inventory_scope_uuid/protocol-mappers/models" \
                        --config "$config" \
                        -r saas-admin \
                        --fields id \
                        --format csv \
                        --noquotes > "$mappers_file"; then
                    mapper_reconcile_error "Could not enumerate assigned client-scope protocol mappers."
                fi
                mapper_count=0
                while IFS= read -r mapper_uuid || [ -n "$mapper_uuid" ]; do
                    mapper_uuid="$(printf "%s" "$mapper_uuid" | tr -d "\r")"
                    [ -n "$mapper_uuid" ] || continue
                    mapper_count=$((mapper_count + 1))
                    if [ "$mapper_count" -gt 10000 ]; then
                        mapper_reconcile_error "Client-scope mapper inventory exceeded its bounded limit."
                    fi
                    require_uuid "$mapper_uuid" \
                        "Invalid client-scope protocol-mapper identifier in saas-admin."
                    append_unique_line \
                        "$mapper_uuid" \
                        "$collection_seen_file" \
                        "Duplicate protocol mapper returned for one client scope."
                    get_mapper_json \
                        "client-scopes/$inventory_scope_uuid/protocol-mappers/models/$mapper_uuid"
                    inspect_mapper_structure "$scope_consumer_id"
                    if [ "$mapper_emits_tenant" = true ]; then
                        if [ "$inspection_mode" = post ]; then
                            mapper_reconcile_error "A residual assigned client-scope mapper still emits tenant_id."
                        fi
                        if [ "$scope_consumer_count" -ne 1 ] \
                                || [ "$scope_has_realm_owner" = true ]; then
                            mapper_reconcile_error "A tenant_id mapper belongs to a shared or realm-default client scope; no mapper was removed."
                        fi
                        if ! is_managed_client_id "$scope_consumer_id"; then
                            mapper_reconcile_error "A tenant_id client scope belongs to an unmanaged client; no mapper was removed."
                        fi
                        if [ "$mapper_managed_fingerprint" != true ]; then
                            mapper_reconcile_error "A tenant_id client-scope mapper has an unknown managed-origin fingerprint; no mapper was removed."
                        fi
                        append_unique_line \
                            "client-scope|$inventory_scope_uuid|$mapper_uuid" \
                            "$delete_plan_file" \
                            "Duplicate client-scope mapper in the bounded deletion plan."
                    fi
                done < "$mappers_file"
            done < "$scope_ids_file"
        }

        verify_effective_protocol_mappers() {
            verification_mode="$1"
            evaluated_client_uuid="$2"
            evaluated_client_id="$3"
            requested_scope="${4:-}"
            if [ -n "$requested_scope" ]; then
                if ! /opt/keycloak/bin/kcadm.sh get \
                        "clients/$evaluated_client_uuid/evaluate-scopes/protocol-mappers" \
                        --config "$config" \
                        -r saas-admin \
                        -q "scope=$requested_scope" \
                        --fields mapperId,containerId,containerType \
                        --format csv \
                        --noquotes > "$effective_mappers_file"; then
                    mapper_reconcile_error "Could not evaluate optional client scope $requested_scope for $evaluated_client_id."
                fi
            else
                if ! /opt/keycloak/bin/kcadm.sh get \
                        "clients/$evaluated_client_uuid/evaluate-scopes/protocol-mappers" \
                        --config "$config" \
                        -r saas-admin \
                        --fields mapperId,containerId,containerType \
                        --format csv \
                        --noquotes > "$effective_mappers_file"; then
                    mapper_reconcile_error "Could not evaluate default client scopes for $evaluated_client_id."
                fi
            fi

            : > "$collection_seen_file"
            effective_mapper_count=0
            while IFS=, read -r effective_mapper_uuid mapper_container_uuid \
                    mapper_container_type extra_effective_field \
                    || [ -n "$effective_mapper_uuid$mapper_container_uuid$mapper_container_type$extra_effective_field" ]; do
                effective_mapper_uuid="$(printf "%s" "$effective_mapper_uuid" | tr -d "\r")"
                mapper_container_uuid="$(printf "%s" "$mapper_container_uuid" | tr -d "\r")"
                mapper_container_type="$(printf "%s" "$mapper_container_type" | tr -d "\r")"
                [ -n "$effective_mapper_uuid$mapper_container_uuid$mapper_container_type$extra_effective_field" ] || continue
                effective_mapper_count=$((effective_mapper_count + 1))
                if [ "$effective_mapper_count" -gt 10000 ] \
                        || [ -n "$extra_effective_field" ]; then
                    mapper_reconcile_error "Effective mapper inventory exceeded its bounded limit or was ambiguous."
                fi
                require_uuid "$effective_mapper_uuid" \
                    "Invalid effective protocol-mapper identifier in saas-admin."
                require_uuid "$mapper_container_uuid" \
                    "Invalid effective protocol-mapper container in saas-admin."
                append_unique_line \
                    "$effective_mapper_uuid|$mapper_container_uuid|$mapper_container_type" \
                    "$collection_seen_file" \
                    "Duplicate effective protocol mapper returned for one evaluation."

                case "$mapper_container_type" in
                    client)
                        if [ "$mapper_container_uuid" != "$evaluated_client_uuid" ]; then
                            mapper_reconcile_error "An effective direct mapper has an inconsistent client container."
                        fi
                        mapper_resource="clients/$mapper_container_uuid/protocol-mappers/models/$effective_mapper_uuid"
                        mapper_plan_key="client|$mapper_container_uuid|$effective_mapper_uuid"
                        ;;
                    client-scope)
                        if ! grep -Fxq "$mapper_container_uuid" "$scope_ids_file" 2>/dev/null; then
                            mapper_reconcile_error "An effective mapper has an unknown client-scope origin."
                        fi
                        mapper_resource="client-scopes/$mapper_container_uuid/protocol-mappers/models/$effective_mapper_uuid"
                        mapper_plan_key="client-scope|$mapper_container_uuid|$effective_mapper_uuid"
                        ;;
                    *)
                        mapper_reconcile_error "An effective mapper has unknown container type $mapper_container_type."
                        ;;
                esac
                get_mapper_json "$mapper_resource"
                inspect_mapper_structure "$evaluated_client_id"
                if [ "$mapper_emits_tenant" = true ]; then
                    if [ "$verification_mode" = post ]; then
                        mapper_reconcile_error "An effective mapper still emits tenant_id for $evaluated_client_id."
                    fi
                    if ! grep -Fqx "$mapper_plan_key" "$delete_plan_file" 2>/dev/null; then
                        mapper_reconcile_error "An effective tenant_id mapper has no safe bounded deletion plan."
                    fi
                fi
            done < "$effective_mappers_file"
        }

        verify_all_managed_effective_mappers() {
            verification_mode="$1"
            while IFS=, read -r client_uuid client_id \
                    || [ -n "$client_uuid$client_id" ]; do
                [ -n "$client_uuid$client_id" ] || continue
                verify_effective_protocol_mappers \
                    "$verification_mode" "$client_uuid" "$client_id"
                : > "$optional_scopes_file"
                while IFS="|" read -r edge_scope_uuid optional_scope_name \
                        edge_owner_uuid edge_owner_id edge_assignment_kind \
                        || [ -n "$edge_scope_uuid$optional_scope_name$edge_owner_uuid$edge_owner_id$edge_assignment_kind" ]; do
                    if [ "$edge_owner_uuid" != "$client_uuid" ] \
                            || [ "$edge_assignment_kind" != client-optional ]; then
                        continue
                    fi
                    append_unique_line \
                        "$optional_scope_name" \
                        "$optional_scopes_file" \
                        "Duplicate optional client-scope name assigned to $client_id."
                done < "$scope_edges_file"
                while IFS= read -r optional_scope_name || [ -n "$optional_scope_name" ]; do
                    [ -n "$optional_scope_name" ] || continue
                    verify_effective_protocol_mappers \
                        "$verification_mode" \
                        "$client_uuid" "$client_id" "$optional_scope_name"
                done < "$optional_scopes_file"
            done < "$managed_clients_file"
        }

        build_tenant_mapper_plan() {
            inspection_mode="$1"
            : > "$delete_plan_file"
            fetch_all_admin_clients
            record_all_scope_ownership
            inspect_direct_mappers "$inspection_mode"
            inspect_scope_mappers "$inspection_mode"
        }

        build_tenant_mapper_plan preflight
        verify_all_managed_effective_mappers preflight

        while IFS="|" read -r plan_kind plan_container_uuid plan_mapper_uuid \
                || [ -n "$plan_kind$plan_container_uuid$plan_mapper_uuid" ]; do
            [ -n "$plan_kind$plan_container_uuid$plan_mapper_uuid" ] || continue
            require_uuid "$plan_container_uuid" \
                "Invalid mapper container in the bounded deletion plan."
            require_uuid "$plan_mapper_uuid" \
                "Invalid mapper identifier in the bounded deletion plan."
            case "$plan_kind" in
                client)
                    delete_resource="clients/$plan_container_uuid/protocol-mappers/models/$plan_mapper_uuid"
                    ;;
                client-scope)
                    delete_resource="client-scopes/$plan_container_uuid/protocol-mappers/models/$plan_mapper_uuid"
                    ;;
                *)
                    mapper_reconcile_error "Unknown mapper source in the bounded deletion plan."
                    ;;
            esac
            if ! /opt/keycloak/bin/kcadm.sh delete "$delete_resource" \
                --config "$config" \
                -r saas-admin \
                    >/dev/null; then
                mapper_reconcile_error "Could not apply the bounded tenant mapper deletion plan."
            fi
        done < "$delete_plan_file"

        build_tenant_mapper_plan post
        verify_all_managed_effective_mappers post
    '

echo "Reconciling explicit SPA realm-role scopes in all managed SaaS realms..."
"${COMPOSE[@]}" "${ENV_FILES[@]}" "${COMPOSE_FILES[@]}" run --rm --no-deps \
    -e RECOVERY_ADMIN_USERNAME \
    -e RECOVERY_ADMIN_PASSWORD \
    -e "KEYCLOAK_EXISTING_MANAGED_REALMS=$KEYCLOAK_EXISTING_MANAGED_REALMS" \
    --entrypoint /bin/sh keycloak -c '
        set -eu
        umask 077
        config=/tmp/kcadm-role-scopes.config
        payload=/tmp/kcadm-role-scopes.json
        extra_payload=/tmp/kcadm-extra-role-scopes.json
        realms_file=/tmp/kcadm-realms.csv
        result_file=/tmp/kcadm-result.csv
        mapped_roles_file=/tmp/kcadm-mapped-roles.csv
        admin_user_roles_file=/tmp/kcadm-admin-user-roles.csv
        composite_children_file=/tmp/kcadm-composite-children.csv
        composite_children_page_file=/tmp/kcadm-composite-children-page.csv
        composite_payload=/tmp/kcadm-composite-payload.json
        composite_role_json_file=/tmp/kcadm-composite-role.json
        composite_queue_file=/tmp/kcadm-composite-queue.list
        composite_visited_file=/tmp/kcadm-composite-visited.list
        role_inventory_page_file=/tmp/kcadm-role-inventory-page.csv
        client_inventory_page_file=/tmp/kcadm-role-client-inventory-page.csv
        all_role_clients_file=/tmp/kcadm-all-role-clients.list
        all_roles_file=/tmp/kcadm-all-roles.psv
        all_role_ids_file=/tmp/kcadm-all-role-ids.list
        role_edges_file=/tmp/kcadm-role-edges.psv
        inheritance_delete_plan_file=/tmp/kcadm-audit-inheritance-delete-plan.psv
        billing_mapper_ids_file=/tmp/kcadm-billing-mapper-ids.csv
        billing_mapper_json_file=/tmp/kcadm-billing-mapper.json
        billing_mapper_classification_file=/tmp/kcadm-billing-mapper-classification.txt
        human_mapper_payload=/tmp/kcadm-human-principal-mapper.json
        amr_mapper_payload=/tmp/kcadm-amr-mapper.json
        user_profile_result_file=/tmp/kcadm-user-profile-result.csv
        human_identity_result_file=/tmp/kcadm-human-identity-result.csv
        runtime_json_validator=/opt/keycloak/bootstrap/validate-keycloak-runtime-json.sh
        audit_role=ROLE_TENANT_AUDIT
        audit_role_description="Explicit conversation audit entitlement. Requires a valid tenant context and grants no other administrative capability."
        tenant_admin_description="Accounting firm administrator. Manages tenant configuration and users. Does not grant conversation audit access (BR-002)."
        trap '\''rm -f "$config" "$payload" "$extra_payload" "$realms_file" "$result_file" "$mapped_roles_file" "$admin_user_roles_file" "$composite_children_file" "$composite_children_page_file" "$composite_payload" "$composite_role_json_file" "$composite_queue_file" "$composite_visited_file" "$role_inventory_page_file" "$client_inventory_page_file" "$all_role_clients_file" "$all_roles_file" "$all_role_ids_file" "$role_edges_file" "$inheritance_delete_plan_file" "$billing_mapper_ids_file" "$billing_mapper_json_file" "$billing_mapper_classification_file" "$human_mapper_payload" "$amr_mapper_payload" "$user_profile_result_file" "$human_identity_result_file"'\'' EXIT

        [ -f "$runtime_json_validator" ] && [ -r "$runtime_json_validator" ] || {
            echo "ERROR: Structural Keycloak runtime JSON validator is unavailable." >&2
            exit 1
        }

        printf "%s\n" \
            "{\"name\":\"human-principal-id\",\"protocol\":\"openid-connect\",\"protocolMapper\":\"oidc-usermodel-attribute-mapper\",\"consentRequired\":false,\"config\":{\"user.attribute\":\"human_principal_id\",\"claim.name\":\"human_principal_id\",\"jsonType.label\":\"String\",\"id.token.claim\":\"false\",\"access.token.claim\":\"true\",\"userinfo.token.claim\":\"false\",\"multivalued\":\"false\",\"aggregate.attrs\":\"false\"}}" \
            > "$human_mapper_payload"
        printf "%s\n" \
            "{\"name\":\"authentication-method-reference\",\"protocol\":\"openid-connect\",\"protocolMapper\":\"oidc-amr-mapper\",\"consentRequired\":false,\"config\":{\"id.token.claim\":\"false\",\"access.token.claim\":\"true\"}}" \
            > "$amr_mapper_payload"

        managed_realms_value="${KEYCLOAK_EXISTING_MANAGED_REALMS:-}"
        if ! printf "%s\n" "$managed_realms_value" \
                | grep -Eq "^saas-[a-z0-9][a-z0-9-]*(,saas-[a-z0-9][a-z0-9-]*)*$"; then
            echo "ERROR: KEYCLOAK_EXISTING_MANAGED_REALMS must be a non-empty, exact comma-separated SaaS realm allowlist without whitespace." >&2
            exit 1
        fi
        : > "$realms_file"
        remaining_realms="${managed_realms_value},"
        seen_realms=,
        admin_realm_seen=false
        while [ -n "$remaining_realms" ]; do
            realm_name="${remaining_realms%%,*}"
            remaining_realms="${remaining_realms#*,}"
            case "$seen_realms" in
                *,"$realm_name",*)
                    echo "ERROR: KEYCLOAK_EXISTING_MANAGED_REALMS must not contain duplicate realms." >&2
                    exit 1
                    ;;
            esac
            printf "%s\n" "$realm_name" >> "$realms_file"
            seen_realms="${seen_realms}${realm_name},"
            if [ "$realm_name" = saas-admin ]; then
                admin_realm_seen=true
            fi
        done
        if [ "$admin_realm_seen" != true ]; then
            echo "ERROR: the local persisted-volume migration requires saas-admin in KEYCLOAK_EXISTING_MANAGED_REALMS." >&2
            exit 1
        fi

        KC_CLI_PASSWORD="$RECOVERY_ADMIN_PASSWORD" \
        /opt/keycloak/bin/kcadm.sh config credentials \
            --config "$config" \
            --server http://keycloak:8080 \
            --realm master \
            --user "$RECOVERY_ADMIN_USERNAME" \
            </dev/null >/dev/null
        chmod 600 "$config"

        fetch_all_composite_child_ids() {
            composite_realm="$1"
            composite_parent_uuid="$2"
            composite_destination_file="$3"
            composite_page_size=100
            composite_max_items=10000
            composite_first=0
            composite_total_count=0
            : > "$composite_destination_file"

            while :; do
                if ! /opt/keycloak/bin/kcadm.sh get \
                        "roles-by-id/$composite_parent_uuid/composites" \
                        --config "$config" \
                        -r "$composite_realm" \
                        -q "first=$composite_first" \
                        -q "max=$composite_page_size" \
                        --fields id \
                        --format csv \
                        --noquotes > "$composite_children_page_file"; then
                    echo "ERROR: Could not inspect the complete realm-role composite graph in $composite_realm." >&2
                    return 2
                fi

                composite_page_count=0
                while IFS= read -r composite_child_uuid \
                        || [ -n "$composite_child_uuid" ]; do
                    composite_child_uuid="$(printf "%s" "$composite_child_uuid" | tr -d "\r")"
                    [ -n "$composite_child_uuid" ] || continue
                    composite_page_count=$((composite_page_count + 1))
                    if [ "$composite_page_count" -gt "$composite_page_size" ]; then
                        echo "ERROR: Composite pagination returned more items than requested in $composite_realm." >&2
                        return 2
                    fi
                    case "$composite_child_uuid" in
                        *[!0-9a-fA-F-]*)
                            echo "ERROR: Invalid composite role identifier in $composite_realm." >&2
                            return 2
                            ;;
                    esac
                    if grep -Fxq "$composite_child_uuid" "$composite_destination_file"; then
                        echo "ERROR: Duplicate or non-advancing composite page in $composite_realm." >&2
                        return 2
                    fi
                    printf "%s\n" "$composite_child_uuid" >> "$composite_destination_file"
                    composite_total_count=$((composite_total_count + 1))
                    if [ "$composite_total_count" -gt "$composite_max_items" ]; then
                        echo "ERROR: Composite pagination exceeded its bounded item limit in $composite_realm." >&2
                        return 2
                    fi
                done < "$composite_children_page_file"

                [ "$composite_page_count" -eq "$composite_page_size" ] || break
                if [ "$composite_total_count" -ge "$composite_max_items" ]; then
                    echo "ERROR: Composite pagination reached its limit on a full page in $composite_realm." >&2
                    return 2
                fi
                composite_next_first=$((composite_first + composite_page_count))
                if [ "$composite_next_first" -le "$composite_first" ]; then
                    echo "ERROR: Composite pagination did not advance in $composite_realm." >&2
                    return 2
                fi
                composite_first="$composite_next_first"
            done
        }

        role_inherits_audit() {
            composite_graph_realm="$1"
            composite_graph_parent_uuid="$2"
            composite_graph_audit_uuid="$3"
            : > "$composite_queue_file"
            : > "$composite_visited_file"
            printf "%s\n" "$composite_graph_parent_uuid" > "$composite_queue_file"
            composite_queue_index=1
            composite_graph_visit_count=0

            while :; do
                composite_current_uuid="$(sed -n "${composite_queue_index}p" "$composite_queue_file" | tr -d "\r")"
                [ -n "$composite_current_uuid" ] || break
                composite_queue_index=$((composite_queue_index + 1))
                if grep -Fxq "$composite_current_uuid" "$composite_visited_file"; then
                    continue
                fi
                printf "%s\n" "$composite_current_uuid" >> "$composite_visited_file"
                composite_graph_visit_count=$((composite_graph_visit_count + 1))
                if [ "$composite_graph_visit_count" -gt 10000 ]; then
                    echo "ERROR: Composite graph traversal exceeded its bounded role limit in $composite_graph_realm." >&2
                    return 2
                fi

                if fetch_all_composite_child_ids \
                        "$composite_graph_realm" \
                        "$composite_current_uuid" \
                        "$composite_children_file"; then
                    :
                else
                    composite_fetch_status=$?
                    return "$composite_fetch_status"
                fi
                while IFS= read -r composite_child_uuid || [ -n "$composite_child_uuid" ]; do
                    composite_child_uuid="$(printf "%s" "$composite_child_uuid" | tr -d "\r")"
                    [ -n "$composite_child_uuid" ] || continue
                    if [ "$composite_child_uuid" = "$composite_graph_audit_uuid" ]; then
                        return 0
                    fi
                    if ! grep -Fxq "$composite_child_uuid" "$composite_visited_file"; then
                        printf "%s\n" "$composite_child_uuid" >> "$composite_queue_file"
                    fi
                done < "$composite_children_file"
            done
            return 1
        }

        append_role_inventory() {
            inventory_role_uuid="$1"
            inventory_role_kind="$2"
            inventory_role_name="$3"
            case "$inventory_role_uuid" in
                ""|*[!0-9a-fA-F-]*)
                    echo "ERROR: Invalid role identifier in the complete audit-inheritance inventory." >&2
                    exit 1
                    ;;
            esac
            case "$inventory_role_kind" in
                realm|client)
                    ;;
                *)
                    echo "ERROR: Invalid role origin in the complete audit-inheritance inventory." >&2
                    exit 1
                    ;;
            esac
            if ! printf "%s\n" "$inventory_role_name" \
                    | LC_ALL=C grep -Eq "^[A-Za-z0-9_.:-]+$"; then
                echo "ERROR: Unsafe or ambiguous role name in the complete audit-inheritance inventory." >&2
                exit 1
            fi
            if grep -Fxq "$inventory_role_uuid" "$all_role_ids_file" 2>/dev/null; then
                echo "ERROR: Duplicate or non-advancing role inventory page." >&2
                exit 1
            fi
            printf "%s\n" "$inventory_role_uuid" >> "$all_role_ids_file"
            printf "%s|%s|%s\n" \
                "$inventory_role_uuid" "$inventory_role_kind" "$inventory_role_name" \
                >> "$all_roles_file"
            role_inventory_total=$((role_inventory_total + 1))
            if [ "$role_inventory_total" -gt 10000 ]; then
                echo "ERROR: Complete audit-inheritance role inventory exceeded its bounded limit." >&2
                exit 1
            fi
        }

        inventory_all_role_parents() {
            inventory_realm="$1"
            role_page_size=100
            role_first=0
            role_inventory_total=0
            : > "$all_roles_file"
            : > "$all_role_ids_file"
            : > "$all_role_clients_file"

            while :; do
                if ! /opt/keycloak/bin/kcadm.sh get roles \
                        --config "$config" \
                        -r "$inventory_realm" \
                        -q "first=$role_first" \
                        -q "max=$role_page_size" \
                        --fields id,name \
                        --format csv \
                        --noquotes > "$role_inventory_page_file"; then
                    echo "ERROR: Could not enumerate every realm role in $inventory_realm." >&2
                    exit 1
                fi
                role_page_count=0
                while IFS=, read -r inventory_role_uuid inventory_role_name inventory_role_extra \
                        || [ -n "$inventory_role_uuid$inventory_role_name$inventory_role_extra" ]; do
                    inventory_role_uuid="$(printf "%s" "$inventory_role_uuid" | tr -d "\r")"
                    inventory_role_name="$(printf "%s" "$inventory_role_name" | tr -d "\r")"
                    [ -n "$inventory_role_uuid$inventory_role_name$inventory_role_extra" ] || continue
                    if [ -n "$inventory_role_extra" ]; then
                        echo "ERROR: Ambiguous realm-role inventory row in $inventory_realm." >&2
                        exit 1
                    fi
                    role_page_count=$((role_page_count + 1))
                    if [ "$role_page_count" -gt "$role_page_size" ]; then
                        echo "ERROR: Realm-role inventory returned more items than requested." >&2
                        exit 1
                    fi
                    append_role_inventory "$inventory_role_uuid" realm "$inventory_role_name"
                done < "$role_inventory_page_file"
                [ "$role_page_count" -eq "$role_page_size" ] || break
                if [ "$role_inventory_total" -ge 10000 ]; then
                    echo "ERROR: Realm-role inventory reached its bounded limit on a full page." >&2
                    exit 1
                fi
                role_next_first=$((role_first + role_page_count))
                if [ "$role_next_first" -le "$role_first" ]; then
                    echo "ERROR: Realm-role inventory pagination did not advance." >&2
                    exit 1
                fi
                role_first="$role_next_first"
            done

            client_page_size=100
            client_first=0
            client_total=0
            while :; do
                if ! /opt/keycloak/bin/kcadm.sh get clients \
                        --config "$config" \
                        -r "$inventory_realm" \
                        -q "first=$client_first" \
                        -q "max=$client_page_size" \
                        --fields id \
                        --format csv \
                        --noquotes > "$client_inventory_page_file"; then
                    echo "ERROR: Could not enumerate every client role container in $inventory_realm." >&2
                    exit 1
                fi
                client_page_count=0
                while IFS= read -r inventory_client_uuid || [ -n "$inventory_client_uuid" ]; do
                    inventory_client_uuid="$(printf "%s" "$inventory_client_uuid" | tr -d "\r")"
                    [ -n "$inventory_client_uuid" ] || continue
                    case "$inventory_client_uuid" in
                        *[!0-9a-fA-F-]*)
                            echo "ERROR: Invalid client identifier in the complete role inventory." >&2
                            exit 1
                            ;;
                    esac
                    if grep -Fxq "$inventory_client_uuid" "$all_role_clients_file" 2>/dev/null; then
                        echo "ERROR: Duplicate or non-advancing client page in the complete role inventory." >&2
                        exit 1
                    fi
                    printf "%s\n" "$inventory_client_uuid" >> "$all_role_clients_file"
                    client_page_count=$((client_page_count + 1))
                    client_total=$((client_total + 1))
                    if [ "$client_page_count" -gt "$client_page_size" ] \
                            || [ "$client_total" -gt 10000 ]; then
                        echo "ERROR: Client-role container inventory exceeded its bounded limit." >&2
                        exit 1
                    fi
                done < "$client_inventory_page_file"
                [ "$client_page_count" -eq "$client_page_size" ] || break
                if [ "$client_total" -ge 10000 ]; then
                    echo "ERROR: Client-role container inventory reached its limit on a full page." >&2
                    exit 1
                fi
                client_next_first=$((client_first + client_page_count))
                if [ "$client_next_first" -le "$client_first" ]; then
                    echo "ERROR: Client-role container pagination did not advance." >&2
                    exit 1
                fi
                client_first="$client_next_first"
            done

            while IFS= read -r inventory_client_uuid || [ -n "$inventory_client_uuid" ]; do
                [ -n "$inventory_client_uuid" ] || continue
                client_role_first=0
                while :; do
                    if ! /opt/keycloak/bin/kcadm.sh get \
                            "clients/$inventory_client_uuid/roles" \
                            --config "$config" \
                            -r "$inventory_realm" \
                            -q "first=$client_role_first" \
                            -q "max=$role_page_size" \
                            --fields id,name \
                            --format csv \
                            --noquotes > "$role_inventory_page_file"; then
                        echo "ERROR: Could not enumerate every client role in $inventory_realm." >&2
                        exit 1
                    fi
                    client_role_page_count=0
                    while IFS=, read -r inventory_role_uuid inventory_role_name inventory_role_extra \
                            || [ -n "$inventory_role_uuid$inventory_role_name$inventory_role_extra" ]; do
                        inventory_role_uuid="$(printf "%s" "$inventory_role_uuid" | tr -d "\r")"
                        inventory_role_name="$(printf "%s" "$inventory_role_name" | tr -d "\r")"
                        [ -n "$inventory_role_uuid$inventory_role_name$inventory_role_extra" ] || continue
                        if [ -n "$inventory_role_extra" ]; then
                            echo "ERROR: Ambiguous client-role inventory row in $inventory_realm." >&2
                            exit 1
                        fi
                        client_role_page_count=$((client_role_page_count + 1))
                        if [ "$client_role_page_count" -gt "$role_page_size" ]; then
                            echo "ERROR: Client-role inventory returned more items than requested." >&2
                            exit 1
                        fi
                        append_role_inventory "$inventory_role_uuid" client "$inventory_role_name"
                    done < "$role_inventory_page_file"
                    [ "$client_role_page_count" -eq "$role_page_size" ] || break
                    if [ "$role_inventory_total" -ge 10000 ]; then
                        echo "ERROR: Client-role inventory reached its bounded limit on a full page." >&2
                        exit 1
                    fi
                    client_role_next_first=$((client_role_first + client_role_page_count))
                    if [ "$client_role_next_first" -le "$client_role_first" ]; then
                        echo "ERROR: Client-role inventory pagination did not advance." >&2
                        exit 1
                    fi
                    client_role_first="$client_role_next_first"
                done
            done < "$all_role_clients_file"
        }

        build_complete_role_graph() {
            graph_realm="$1"
            : > "$role_edges_file"
            while IFS="|" read -r graph_parent_uuid graph_parent_kind graph_parent_name \
                    || [ -n "$graph_parent_uuid$graph_parent_kind$graph_parent_name" ]; do
                [ -n "$graph_parent_uuid$graph_parent_kind$graph_parent_name" ] || continue
                fetch_all_composite_child_ids \
                    "$graph_realm" "$graph_parent_uuid" "$composite_children_file"
                while IFS= read -r graph_child_uuid || [ -n "$graph_child_uuid" ]; do
                    [ -n "$graph_child_uuid" ] || continue
                    if ! grep -Fxq "$graph_child_uuid" "$all_role_ids_file"; then
                        echo "ERROR: Composite graph references a role outside the complete inventory in $graph_realm." >&2
                        exit 1
                    fi
                    printf "%s|%s\n" "$graph_parent_uuid" "$graph_child_uuid" \
                        >> "$role_edges_file"
                done < "$composite_children_file"
            done < "$all_roles_file"
        }

        inventoried_role_reaches_audit() {
            graph_start_uuid="$1"
            graph_audit_uuid="$2"
            graph_ignored_parent="${3:-}"
            graph_ignored_child="${4:-}"
            : > "$composite_queue_file"
            : > "$composite_visited_file"
            printf "%s\n" "$graph_start_uuid" > "$composite_queue_file"
            graph_queue_index=1
            graph_visit_count=0
            while :; do
                graph_current_uuid="$(sed -n "${graph_queue_index}p" "$composite_queue_file" | tr -d "\r")"
                [ -n "$graph_current_uuid" ] || break
                graph_queue_index=$((graph_queue_index + 1))
                if grep -Fxq "$graph_current_uuid" "$composite_visited_file"; then
                    continue
                fi
                printf "%s\n" "$graph_current_uuid" >> "$composite_visited_file"
                graph_visit_count=$((graph_visit_count + 1))
                if [ "$graph_visit_count" -gt 10000 ]; then
                    echo "ERROR: Inventoried role graph traversal exceeded its bounded limit." >&2
                    return 2
                fi
                while IFS="|" read -r graph_edge_parent graph_edge_child \
                        || [ -n "$graph_edge_parent$graph_edge_child" ]; do
                    [ "$graph_edge_parent" = "$graph_current_uuid" ] || continue
                    if [ "$graph_edge_parent" = "$graph_ignored_parent" ] \
                            && [ "$graph_edge_child" = "$graph_ignored_child" ]; then
                        continue
                    fi
                    if [ "$graph_edge_child" = "$graph_audit_uuid" ]; then
                        return 0
                    fi
                    if ! grep -Fxq "$graph_edge_child" "$composite_visited_file"; then
                        printf "%s\n" "$graph_edge_child" >> "$composite_queue_file"
                    fi
                done < "$role_edges_file"
            done
            return 1
        }

        preflight_complete_audit_inheritance() {
            inheritance_realm="$1"
            inheritance_audit_uuid="$2"
            inventory_all_role_parents "$inheritance_realm"
            if ! grep -Fxq "$inheritance_audit_uuid" "$all_role_ids_file"; then
                echo "ERROR: ROLE_TENANT_AUDIT is absent from the complete role inventory in $inheritance_realm." >&2
                exit 1
            fi
            build_complete_role_graph "$inheritance_realm"
            : > "$inheritance_delete_plan_file"

            while IFS="|" read -r inheritance_parent_uuid inheritance_parent_kind inheritance_parent_name \
                    || [ -n "$inheritance_parent_uuid$inheritance_parent_kind$inheritance_parent_name" ]; do
                [ -n "$inheritance_parent_uuid$inheritance_parent_kind$inheritance_parent_name" ] || continue
                [ "$inheritance_parent_uuid" != "$inheritance_audit_uuid" ] || continue
                if inventoried_role_reaches_audit \
                        "$inheritance_parent_uuid" "$inheritance_audit_uuid"; then
                    case "$inheritance_parent_kind:$inheritance_parent_name" in
                        realm:ROLE_TENANT_ADMIN|realm:ROLE_SUPER_ADMIN)
                            inheritance_direct_count="$(grep -Fxc \
                                "$inheritance_parent_uuid|$inheritance_audit_uuid" \
                                "$role_edges_file" || true)"
                            if [ "$inheritance_direct_count" -ne 1 ]; then
                                echo "ERROR: Managed administrative role reaches ROLE_TENANT_AUDIT through an ambiguous or transitive path in $inheritance_realm." >&2
                                exit 1
                            fi
                            if inventoried_role_reaches_audit \
                                    "$inheritance_parent_uuid" \
                                    "$inheritance_audit_uuid" \
                                    "$inheritance_parent_uuid" \
                                    "$inheritance_audit_uuid"; then
                                echo "ERROR: Managed administrative role has an additional transitive path to ROLE_TENANT_AUDIT in $inheritance_realm." >&2
                                exit 1
                            else
                                inheritance_without_direct_status=$?
                                if [ "$inheritance_without_direct_status" -ne 1 ]; then
                                    exit "$inheritance_without_direct_status"
                                fi
                            fi
                            printf "%s|%s\n" \
                                "$inheritance_parent_uuid" "$inheritance_parent_name" \
                                >> "$inheritance_delete_plan_file"
                            ;;
                        *)
                            echo "ERROR: $inheritance_parent_kind role $inheritance_parent_name inherits ROLE_TENANT_AUDIT outside the bounded managed-drift allowlist in $inheritance_realm." >&2
                            exit 1
                            ;;
                    esac
                else
                    inheritance_graph_status=$?
                    if [ "$inheritance_graph_status" -ne 1 ]; then
                        exit "$inheritance_graph_status"
                    fi
                fi
            done < "$all_roles_file"
        }

        reconcile_complete_audit_inheritance() {
            inheritance_realm="$1"
            inheritance_audit_uuid="$2"
            preflight_complete_audit_inheritance \
                "$inheritance_realm" "$inheritance_audit_uuid"
            while IFS="|" read -r inheritance_parent_uuid inheritance_parent_name \
                    || [ -n "$inheritance_parent_uuid$inheritance_parent_name" ]; do
                [ -n "$inheritance_parent_uuid$inheritance_parent_name" ] || continue
                remove_audit_inheritance \
                    "$inheritance_realm" \
                    "$inheritance_parent_name" \
                    "$inheritance_parent_uuid" \
                    "$inheritance_audit_uuid"
            done < "$inheritance_delete_plan_file"

            preflight_complete_audit_inheritance \
                "$inheritance_realm" "$inheritance_audit_uuid"
            if [ -s "$inheritance_delete_plan_file" ]; then
                echo "ERROR: Managed audit inheritance remains after reconciliation in $inheritance_realm." >&2
                exit 1
            fi
        }

        remove_audit_inheritance() {
            inheritance_realm="$1"
            inheritance_parent_name="$2"
            inheritance_parent_uuid="$3"
            inheritance_audit_uuid="$4"

            fetch_all_composite_child_ids \
                "$inheritance_realm" \
                "$inheritance_parent_uuid" \
                "$composite_children_file"
            inheritance_direct_count=0
            while IFS= read -r inheritance_child_uuid || [ -n "$inheritance_child_uuid" ]; do
                inheritance_child_uuid="$(printf "%s" "$inheritance_child_uuid" | tr -d "\r")"
                [ -n "$inheritance_child_uuid" ] || continue
                case "$inheritance_child_uuid" in
                    *[!0-9a-fA-F-]*)
                        echo "ERROR: Invalid direct composite role identifier in $inheritance_realm." >&2
                        exit 1
                        ;;
                esac
                if [ "$inheritance_child_uuid" = "$inheritance_audit_uuid" ]; then
                    inheritance_direct_count=$((inheritance_direct_count + 1))
                fi
            done < "$composite_children_file"
            if [ "$inheritance_direct_count" -gt 1 ]; then
                echo "ERROR: Duplicate direct audit inheritance detected on $inheritance_parent_name in $inheritance_realm." >&2
                exit 1
            fi
            if [ "$inheritance_direct_count" -eq 1 ]; then
                printf "[{\"id\":\"%s\",\"name\":\"%s\"}]\n" \
                    "$inheritance_audit_uuid" "$audit_role" > "$composite_payload"
                /opt/keycloak/bin/kcadm.sh delete \
                    "roles-by-id/$inheritance_parent_uuid/composites" \
                    --config "$config" \
                    -r "$inheritance_realm" \
                    -f "$composite_payload" >/dev/null
            fi

            fetch_all_composite_child_ids \
                "$inheritance_realm" \
                "$inheritance_parent_uuid" \
                "$composite_children_file"
            if grep -Fxq "$inheritance_audit_uuid" "$composite_children_file"; then
                echo "ERROR: Direct audit inheritance remains on $inheritance_parent_name in $inheritance_realm." >&2
                exit 1
            fi

            if role_inherits_audit \
                    "$inheritance_realm" \
                    "$inheritance_parent_uuid" \
                    "$inheritance_audit_uuid"; then
                echo "ERROR: $inheritance_parent_name still inherits ROLE_TENANT_AUDIT transitively in $inheritance_realm." >&2
                exit 1
            else
                inheritance_graph_status=$?
                if [ "$inheritance_graph_status" -ne 1 ]; then
                    exit "$inheritance_graph_status"
                fi
            fi
        }

        reconcile_audit_role_composites() {
            audit_realm="$1"
            audit_role_uuid_to_reconcile="$2"

            fetch_all_composite_child_ids \
                "$audit_realm" \
                "$audit_role_uuid_to_reconcile" \
                "$composite_children_file"
            while IFS= read -r audit_composite_child_uuid \
                    || [ -n "$audit_composite_child_uuid" ]; do
                [ -n "$audit_composite_child_uuid" ] || continue
                /opt/keycloak/bin/kcadm.sh get \
                    "roles-by-id/$audit_composite_child_uuid" \
                    --config "$config" \
                    -r "$audit_realm" > "$composite_role_json_file"
                printf "[" > "$composite_payload"
                cat "$composite_role_json_file" >> "$composite_payload"
                printf "]" >> "$composite_payload"
                /opt/keycloak/bin/kcadm.sh delete \
                    "roles-by-id/$audit_role_uuid_to_reconcile/composites" \
                    --config "$config" \
                    -r "$audit_realm" \
                    -f "$composite_payload" >/dev/null
            done < "$composite_children_file"

            /opt/keycloak/bin/kcadm.sh update "roles/$audit_role" \
                --config "$config" \
                -r "$audit_realm" \
                -s "description=$audit_role_description" \
                -s composite=false >/dev/null
            fetch_all_composite_child_ids \
                "$audit_realm" \
                "$audit_role_uuid_to_reconcile" \
                "$composite_children_file"
            if grep -Eq "[^[:space:]]" "$composite_children_file"; then
                echo "ERROR: ROLE_TENANT_AUDIT still contains composite roles in $audit_realm." >&2
                exit 1
            fi
            /opt/keycloak/bin/kcadm.sh get "roles/$audit_role" \
                --config "$config" \
                -r "$audit_realm" \
                --fields composite \
                --format csv \
                --noquotes > "$result_file"
            audit_composite_state="$(tr -d "\r\n" < "$result_file")"
            if [ "$audit_composite_state" != false ]; then
                echo "ERROR: ROLE_TENANT_AUDIT is not explicitly non-composite in $audit_realm." >&2
                exit 1
            fi
        }

        inspect_billing_mapper_contract() {
            mapper_realm="$1"
            mapper_client_uuid="$2"
            mapper_kind="$3"
            mapper_phase="$4"
            mapper_exact_count=0
            mapper_inventory_count=0

            /opt/keycloak/bin/kcadm.sh get \
                "clients/$mapper_client_uuid/protocol-mappers/models" \
                --config "$config" \
                -r "$mapper_realm" \
                --fields id \
                --format csv \
                --noquotes > "$billing_mapper_ids_file"

            while IFS= read -r billing_mapper_uuid || [ -n "$billing_mapper_uuid" ]; do
                billing_mapper_uuid="$(printf "%s" "$billing_mapper_uuid" | tr -d "\r")"
                [ -n "$billing_mapper_uuid" ] || continue
                mapper_inventory_count=$((mapper_inventory_count + 1))
                if [ "$mapper_inventory_count" -gt 256 ]; then
                    echo "ERROR: Billing mapper inventory exceeded its bounded limit in $mapper_realm." >&2
                    exit 1
                fi
                case "$billing_mapper_uuid" in
                    *[!0-9a-fA-F-]*|"")
                        echo "ERROR: Invalid Billing mapper identifier in $mapper_realm." >&2
                        exit 1
                        ;;
                esac
                /opt/keycloak/bin/kcadm.sh get \
                    "clients/$mapper_client_uuid/protocol-mappers/models/$billing_mapper_uuid" \
                    --config "$config" \
                    -r "$mapper_realm" > "$billing_mapper_json_file"
                if ! /bin/bash "$runtime_json_validator" \
                        billing-mapper "$billing_mapper_json_file" "$mapper_kind" \
                        > "$billing_mapper_classification_file"; then
                    echo "ERROR: Could not classify $mapper_kind Billing mapper in $mapper_realm." >&2
                    exit 1
                fi
                mapper_classification="$(tr -d "\r\n" < "$billing_mapper_classification_file")"
                case "$mapper_classification" in
                    "kind=$mapper_kind relevant=false exact=false")
                        ;;
                    "kind=$mapper_kind relevant=true exact=true")
                        mapper_exact_count=$((mapper_exact_count + 1))
                        ;;
                    "kind=$mapper_kind relevant=true exact=false")
                        echo "ERROR: Conflicting $mapper_kind Billing mapper exists in $mapper_realm; no mapper was created." >&2
                        exit 1
                        ;;
                    *)
                        echo "ERROR: Structural Billing mapper classifier returned an unexpected result." >&2
                        exit 1
                        ;;
                esac
            done < "$billing_mapper_ids_file"

            if [ "$mapper_exact_count" -gt 1 ]; then
                echo "ERROR: Duplicate exact $mapper_kind Billing mappers exist in $mapper_realm." >&2
                exit 1
            fi
            if [ "$mapper_phase" = post ] && [ "$mapper_exact_count" -ne 1 ]; then
                echo "ERROR: Expected exactly one exact $mapper_kind Billing mapper in $mapper_realm after reconciliation." >&2
                exit 1
            fi
        }

        reconcile_billing_mapper_contract() {
            mapper_realm="$1"
            mapper_client_uuid="$2"
            mapper_kind="$3"
            mapper_payload="$4"

            inspect_billing_mapper_contract \
                "$mapper_realm" "$mapper_client_uuid" "$mapper_kind" preflight
            if [ "$mapper_exact_count" -eq 0 ]; then
                /opt/keycloak/bin/kcadm.sh create \
                    "clients/$mapper_client_uuid/protocol-mappers/models" \
                    --config "$config" \
                    -r "$mapper_realm" \
                    -f "$mapper_payload" >/dev/null
            fi
            inspect_billing_mapper_contract \
                "$mapper_realm" "$mapper_client_uuid" "$mapper_kind" post
        }

        approved_admin_identity=djmarcellopedrosa@gmail.com
        /opt/keycloak/bin/kcadm.sh get users \
            --config "$config" \
            -r saas-admin \
            -q "username=$approved_admin_identity" \
            -q exact=true \
            -q first=0 \
            -q max=2 \
            --fields id \
            --format csv \
            --noquotes > "$result_file"
        admin_user_count=0
        admin_user_uuid=""
        while IFS= read -r candidate_user_uuid || [ -n "$candidate_user_uuid" ]; do
            candidate_user_uuid="$(printf "%s" "$candidate_user_uuid" | tr -d "\r")"
            [ -n "$candidate_user_uuid" ] || continue
            admin_user_count=$((admin_user_count + 1))
            admin_user_uuid="$candidate_user_uuid"
        done < "$result_file"
        [ "$admin_user_count" -eq 1 ] || {
            echo "ERROR: Expected exactly one approved DEV administrative identity; found $admin_user_count." >&2
            exit 1
        }
        case "$admin_user_uuid" in
            ""|*[!0-9a-fA-F-]*)
                echo "ERROR: Invalid approved DEV administrative user identifier." >&2
                exit 1
                ;;
        esac

        /opt/keycloak/bin/kcadm.sh get "users/$admin_user_uuid" \
            --config "$config" \
            -r saas-admin \
            --fields username \
            --format csv \
            --noquotes > "$result_file"
        returned_admin_username="$(tr -d "\r\n" < "$result_file")"
        [ "$returned_admin_username" = "$approved_admin_identity" ] || {
            echo "ERROR: Exact administrative lookup returned a different username." >&2
            exit 1
        }

        /opt/keycloak/bin/kcadm.sh get "users/$admin_user_uuid" \
            --config "$config" \
            -r saas-admin \
            --fields email \
            --format csv \
            --noquotes > "$result_file"
        returned_admin_email="$(tr -d "\r\n" < "$result_file")"
        [ "$returned_admin_email" = "$approved_admin_identity" ] || {
            echo "ERROR: Approved administrative username does not have the exact approved email." >&2
            exit 1
        }

        managed_realm_count=0
        while IFS= read -r realm_name || [ -n "$realm_name" ]; do
                case "$realm_name" in
                    saas-admin)
                        inherited_billing_roles="BILLING_CATALOG_READ BILLING_CATALOG_DRAFT BILLING_PRICE_SIMULATE BILLING_PRICE_SUBMIT BILLING_PRICE_APPROVE BILLING_PRICE_PUBLISH BILLING_TENANT_IMPERSONATE BILLING_CONTRACT_DRAFT BILLING_CONTRACT_SUBMIT BILLING_CONTRACT_ACCEPT_RECORD BILLING_CONTRACT_ACCEPT_VALIDATE BILLING_INVOICE_PREVIEW BILLING_INVOICE_APPROVE BILLING_INVOICE_FINALIZE"
                        standalone_provider_roles="BILLING_PROVIDER_READ BILLING_PROVIDER_CONFIGURE BILLING_PROVIDER_SUBMIT BILLING_PROVIDER_APPROVE BILLING_PROVIDER_ACTIVATE BILLING_PROVIDER_INTERACTION_READ"
                        standalone_platform_roles="ROLE_COMMERCIAL"
                        composite_parent=ROLE_SUPER_ADMIN
                        scoped_roles="ROLE_SUPER_ADMIN ROLE_TENANT_AUDIT $standalone_platform_roles $inherited_billing_roles $standalone_provider_roles"
                        expected_role_count=23
                        ;;
                    *)
                        inherited_billing_roles="BILLING_CONTRACT_DRAFT BILLING_CONTRACT_SUBMIT BILLING_CONTRACT_ACCEPT BILLING_INVOICE_PREVIEW"
                        standalone_provider_roles="BILLING_PROVIDER_INTERACTION_READ"
                        standalone_platform_roles=""
                        composite_parent=ROLE_TENANT_ADMIN
                        scoped_roles="ROLE_FISCAL_ADMIN ROLE_FISCAL_READER ROLE_TENANT_ADMIN ROLE_TENANT_AUDIT ROLE_TENANT_USER $inherited_billing_roles $standalone_provider_roles"
                        expected_role_count=10
                        ;;
                esac
                declared_roles="$standalone_platform_roles $inherited_billing_roles $standalone_provider_roles"
                managed_realm_count=$((managed_realm_count + 1))

                if ! /opt/keycloak/bin/kcadm.sh get "roles/$audit_role" \
                        --config "$config" \
                        -r "$realm_name" >/dev/null 2>&1; then
                    /opt/keycloak/bin/kcadm.sh create roles \
                        --config "$config" \
                        -r "$realm_name" \
                        -s "name=$audit_role" \
                        -s "description=$audit_role_description" \
                        -s composite=false >/dev/null
                fi
                /opt/keycloak/bin/kcadm.sh update "roles/$audit_role" \
                    --config "$config" \
                    -r "$realm_name" \
                    -s "description=$audit_role_description" \
                    -s composite=false >/dev/null

                if /opt/keycloak/bin/kcadm.sh get roles/ROLE_TENANT_ADMIN \
                        --config "$config" \
                        -r "$realm_name" >/dev/null 2>&1; then
                    /opt/keycloak/bin/kcadm.sh update roles/ROLE_TENANT_ADMIN \
                        --config "$config" \
                        -r "$realm_name" \
                        -s "description=$tenant_admin_description" >/dev/null
                fi

                for role_name in $declared_roles; do
                    role_description="Fine-grained Billing authority managed by HD-07."
                    if [ "$role_name" = ROLE_COMMERCIAL ]; then
                        role_description="Global commercial operator with contact-only access."
                    fi
                    if ! /opt/keycloak/bin/kcadm.sh get "roles/$role_name" \
                            --config "$config" \
                            -r "$realm_name" >/dev/null 2>&1; then
                        /opt/keycloak/bin/kcadm.sh create roles \
                            --config "$config" \
                            -r "$realm_name" \
                            -s "name=$role_name" \
                            -s "description=$role_description" \
                            -s composite=false >/dev/null
                    fi
                    if [ "$role_name" = ROLE_COMMERCIAL ]; then
                        /opt/keycloak/bin/kcadm.sh update "roles/$role_name" \
                            --config "$config" \
                            -r "$realm_name" \
                            -s "description=$role_description" \
                            -s composite=false >/dev/null
                    fi
                done

                /opt/keycloak/bin/kcadm.sh get "roles/$composite_parent" \
                    --config "$config" \
                    -r "$realm_name" \
                    --fields id \
                    --format csv \
                    --noquotes > "$result_file"
                composite_parent_uuid="$(tr -d "\r\n" < "$result_file")"
                case "$composite_parent_uuid" in
                    ""|*[!0-9a-fA-F-]*)
                        echo "ERROR: Invalid $composite_parent identifier in $realm_name." >&2
                        exit 1
                        ;;
                esac
                separator=""
                printf "[" > "$payload"
                for role_name in $inherited_billing_roles; do
                    /opt/keycloak/bin/kcadm.sh get "roles/$role_name" \
                        --config "$config" \
                        -r "$realm_name" \
                        --fields id \
                        --format csv \
                        --noquotes > "$result_file"
                    role_uuid="$(tr -d "\r\n" < "$result_file")"
                    case "$role_uuid" in
                        ""|*[!0-9a-fA-F-]*)
                            echo "ERROR: Invalid Billing authority $role_name in $realm_name." >&2
                            exit 1
                            ;;
                    esac
                    printf "%s{\"id\":\"%s\",\"name\":\"%s\"}" \
                        "$separator" "$role_uuid" "$role_name" >> "$payload"
                    separator=,
                done
                printf "]" >> "$payload"
                /opt/keycloak/bin/kcadm.sh create \
                    "roles-by-id/$composite_parent_uuid/composites" \
                    --config "$config" \
                    -r "$realm_name" \
                    -f "$payload" >/dev/null

                /opt/keycloak/bin/kcadm.sh get \
                    "roles-by-id/$composite_parent_uuid/composites" \
                    --config "$config" \
                    -r "$realm_name" \
                    --fields name \
                    --format csv \
                    --noquotes > "$result_file"
                tr -d "\r" < "$result_file" > "$mapped_roles_file"
                for role_name in $inherited_billing_roles; do
                    if ! grep -Fxq "$role_name" "$mapped_roles_file"; then
                        echo "ERROR: $composite_parent does not inherit $role_name in $realm_name." >&2
                        exit 1
                    fi
                done

                /opt/keycloak/bin/kcadm.sh get "roles/$audit_role" \
                    --config "$config" \
                    -r "$realm_name" \
                    --fields id \
                    --format csv \
                    --noquotes > "$result_file"
                audit_role_uuid="$(tr -d "\r\n" < "$result_file")"
                case "$audit_role_uuid" in
                    ""|*[!0-9a-fA-F-]*)
                        echo "ERROR: Invalid ROLE_TENANT_AUDIT identifier in $realm_name." >&2
                        exit 1
                        ;;
                esac

                reconcile_audit_role_composites "$realm_name" "$audit_role_uuid"
                reconcile_complete_audit_inheritance "$realm_name" "$audit_role_uuid"

                /opt/keycloak/bin/kcadm.sh get clients \
                    --config "$config" \
                    -r "$realm_name" \
                    -q "clientId=saas-frontend-spa" \
                    -q first=0 \
                    -q max=2 \
                    --fields id \
                    --format csv \
                    --noquotes > "$result_file"
                client_count=0
                client_uuid=""
                while IFS= read -r candidate_client_uuid || [ -n "$candidate_client_uuid" ]; do
                    candidate_client_uuid="$(printf "%s" "$candidate_client_uuid" | tr -d "\r")"
                    [ -n "$candidate_client_uuid" ] || continue
                    client_count=$((client_count + 1))
                    client_uuid="$candidate_client_uuid"
                done < "$result_file"
                [ "$client_count" -eq 1 ] || {
                    echo "ERROR: Expected exactly one saas-frontend-spa client in $realm_name; found $client_count." >&2
                    exit 1
                }
                case "$client_uuid" in
                    ""|*[!0-9a-fA-F-]*)
                        echo "ERROR: Invalid saas-frontend-spa client identifier in $realm_name." >&2
                        exit 1
                        ;;
                esac

                # Old realm imports are not replayed over a persisted volume. Keep
                # custom attributes writable only from the Admin API so newly
                # provisioned identities can receive the canonical human link.
                /opt/keycloak/bin/kcadm.sh update users/profile \
                    --config "$config" \
                    -r "$realm_name" \
                    -s unmanagedAttributePolicy=ADMIN_EDIT >/dev/null
                /opt/keycloak/bin/kcadm.sh get users/profile \
                    --config "$config" \
                    -r "$realm_name" \
                    --fields unmanagedAttributePolicy \
                    --format csv \
                    --noquotes > "$user_profile_result_file"
                user_profile_policy="$(tr -d "\r\n" < "$user_profile_result_file")"
                if [ "$user_profile_policy" != ADMIN_EDIT ]; then
                    echo "ERROR: Admin-only legacy attribute policy was not reconciled in $realm_name." >&2
                    exit 1
                fi

                reconcile_billing_mapper_contract \
                    "$realm_name" "$client_uuid" human "$human_mapper_payload"
                reconcile_billing_mapper_contract \
                    "$realm_name" "$client_uuid" amr "$amr_mapper_payload"

                separator=""
                printf "[" > "$payload"
                for role_name in $scoped_roles; do
                    /opt/keycloak/bin/kcadm.sh get "roles/$role_name" \
                        --config "$config" \
                        -r "$realm_name" \
                        --fields id \
                        --format csv \
                        --noquotes > "$result_file"
                    role_uuid="$(tr -d "\r\n" < "$result_file")"
                    case "$role_uuid" in
                        ""|*[!0-9a-fA-F-]*)
                            echo "ERROR: Role $role_name was not found in $realm_name." >&2
                            exit 1
                            ;;
                    esac
                    printf "%s{\"id\":\"%s\",\"name\":\"%s\"}" \
                        "$separator" "$role_uuid" "$role_name" >> "$payload"
                    separator=,
                done
                printf "]" >> "$payload"

                /opt/keycloak/bin/kcadm.sh create \
                    "clients/$client_uuid/scope-mappings/realm" \
                    --config "$config" \
                    -r "$realm_name" \
                    -f "$payload" >/dev/null

                /opt/keycloak/bin/kcadm.sh get \
                    "clients/$client_uuid/scope-mappings/realm" \
                    --config "$config" \
                    -r "$realm_name" \
                    --fields id,name \
                    --format csv \
                    --noquotes > "$result_file"
                separator=""
                extra_role_count=0
                printf "[" > "$extra_payload"
                while IFS=, read -r mapped_role_uuid mapped_role || [ -n "$mapped_role_uuid$mapped_role" ]; do
                    mapped_role_uuid="$(printf "%s" "$mapped_role_uuid" | tr -d "\r")"
                    mapped_role="$(printf "%s" "$mapped_role" | tr -d "\r")"
                    [ -n "$mapped_role_uuid$mapped_role" ] || continue
                    case "$mapped_role_uuid" in
                        ""|*[!0-9a-fA-F-]*)
                            echo "ERROR: Invalid role identifier returned for $mapped_role in $realm_name." >&2
                            exit 1
                            ;;
                    esac
                    case " $scoped_roles " in
                        *" $mapped_role "*)
                            ;;
                        *)
                            if ! printf "%s\n" "$mapped_role" \
                                    | LC_ALL=C grep -Eq "^[A-Za-z0-9_.:-]+$"; then
                                echo "ERROR: Unsafe or ambiguous SPA role-scope name in $realm_name." >&2
                                exit 1
                            fi
                            printf "%s{\"id\":\"%s\",\"name\":\"%s\"}" \
                                "$separator" "$mapped_role_uuid" "$mapped_role" \
                                >> "$extra_payload"
                            separator=,
                            extra_role_count=$((extra_role_count + 1))
                            ;;
                    esac
                done < "$result_file"
                printf "]" >> "$extra_payload"
                if [ "$extra_role_count" -gt 0 ]; then
                    /opt/keycloak/bin/kcadm.sh delete \
                        "clients/$client_uuid/scope-mappings/realm" \
                        --config "$config" \
                        -r "$realm_name" \
                        -f "$extra_payload" >/dev/null
                fi

                /opt/keycloak/bin/kcadm.sh update "clients/$client_uuid" \
                    --config "$config" \
                    -r "$realm_name" \
                    -s fullScopeAllowed=false >/dev/null

                /opt/keycloak/bin/kcadm.sh get \
                    "clients/$client_uuid/scope-mappings/realm" \
                    --config "$config" \
                    -r "$realm_name" \
                    --fields name \
                    --format csv \
                    --noquotes > "$result_file"
                tr -d "\r" < "$result_file" > "$mapped_roles_file"
                mapped_role_count=0
                while IFS= read -r mapped_role || [ -n "$mapped_role" ]; do
                    [ -n "$mapped_role" ] || continue
                    mapped_role_count=$((mapped_role_count + 1))
                    case " $scoped_roles " in
                        *" $mapped_role "*)
                            ;;
                        *)
                            echo "ERROR: Unexpected role $mapped_role is scoped to saas-frontend-spa in $realm_name." >&2
                            exit 1
                            ;;
                    esac
                done < "$mapped_roles_file"
                if [ "$mapped_role_count" -ne "$expected_role_count" ]; then
                    echo "ERROR: Expected $expected_role_count explicit SPA role scopes in $realm_name; found $mapped_role_count." >&2
                    exit 1
                fi
                for role_name in $scoped_roles; do
                    if ! grep -Fxq "$role_name" "$mapped_roles_file"; then
                        echo "ERROR: Role $role_name is not scoped to saas-frontend-spa in $realm_name." >&2
                        exit 1
                    fi
                done

                /opt/keycloak/bin/kcadm.sh get "clients/$client_uuid" \
                    --config "$config" \
                    -r "$realm_name" \
                    --fields fullScopeAllowed \
                    --format csv \
                    --noquotes > "$result_file"
                full_scope_allowed="$(tr -d "\r\n" < "$result_file")"
                if [ "$full_scope_allowed" != false ]; then
                    echo "ERROR: Full Scope Allowed remains enabled for saas-frontend-spa in $realm_name." >&2
                    exit 1
                fi
                echo "Explicit SPA role scopes reconciled in $realm_name."
        done < "$realms_file"

        if [ "$managed_realm_count" -eq 0 ]; then
            echo "ERROR: No managed SaaS realm was returned by Keycloak." >&2
            exit 1
        fi

        /opt/keycloak/bin/kcadm.sh update "users/$admin_user_uuid" \
            --config "$config" \
            -r saas-admin \
            -s "attributes.human_principal_id=[\"dev-superadmin-primary\"]" >/dev/null
        /opt/keycloak/bin/kcadm.sh get users \
            --config "$config" \
            -r saas-admin \
            -q "q=human_principal_id:dev-superadmin-primary" \
            -q first=0 \
            -q max=2 \
            --fields id \
            --format csv \
            --noquotes > "$human_identity_result_file"
        human_identity_count=0
        mapped_human_user_uuid=""
        while IFS= read -r candidate_human_user_uuid || [ -n "$candidate_human_user_uuid" ]; do
            candidate_human_user_uuid="$(printf "%s" "$candidate_human_user_uuid" | tr -d "\r")"
            [ -n "$candidate_human_user_uuid" ] || continue
            human_identity_count=$((human_identity_count + 1))
            mapped_human_user_uuid="$candidate_human_user_uuid"
        done < "$human_identity_result_file"
        if [ "$human_identity_count" -ne 1 ] \
                || [ "$mapped_human_user_uuid" != "$admin_user_uuid" ]; then
            echo "ERROR: Canonical DEV human identity was not mapped uniquely to the approved administrator." >&2
            exit 1
        fi

        /opt/keycloak/bin/kcadm.sh get "roles/$audit_role" \
            --config "$config" \
            -r saas-admin \
            --fields id \
            --format csv \
            --noquotes > "$result_file"
        audit_role_uuid="$(tr -d "\r\n" < "$result_file")"
        case "$audit_role_uuid" in
            ""|*[!0-9a-fA-F-]*)
                echo "ERROR: Invalid audit role identifier in saas-admin." >&2
                exit 1
                ;;
        esac
        printf "[{\"id\":\"%s\",\"name\":\"%s\"}]\n" \
            "$audit_role_uuid" "$audit_role" > "$payload"

        /opt/keycloak/bin/kcadm.sh get \
            "users/$admin_user_uuid/role-mappings/realm" \
            --config "$config" \
            -r saas-admin \
            --fields name \
            --format csv \
            --noquotes > "$admin_user_roles_file"
        tr -d "\r" < "$admin_user_roles_file" > "$mapped_roles_file"
        if ! grep -Fxq ROLE_SUPER_ADMIN "$mapped_roles_file"; then
            echo "ERROR: Approved DEV administrative identity is missing ROLE_SUPER_ADMIN." >&2
            exit 1
        fi
        if ! grep -Fxq "$audit_role" "$mapped_roles_file"; then
            /opt/keycloak/bin/kcadm.sh create \
                "users/$admin_user_uuid/role-mappings/realm" \
                --config "$config" \
                -r saas-admin \
                -f "$payload" >/dev/null
        fi

        /opt/keycloak/bin/kcadm.sh get \
            "users/$admin_user_uuid/role-mappings/realm" \
            --config "$config" \
            -r saas-admin \
            --fields name \
            --format csv \
            --noquotes > "$admin_user_roles_file"
        tr -d "\r" < "$admin_user_roles_file" > "$mapped_roles_file"
        grep -Fxq ROLE_SUPER_ADMIN "$mapped_roles_file" || {
            echo "ERROR: ROLE_SUPER_ADMIN was not preserved on the approved DEV identity." >&2
            exit 1
        }
        grep -Fxq "$audit_role" "$mapped_roles_file" || {
            echo "ERROR: ROLE_TENANT_AUDIT was not assigned to the approved DEV identity." >&2
            exit 1
        }

        /opt/keycloak/bin/kcadm.sh create \
            "users/$admin_user_uuid/logout" \
            --config "$config" \
            -r saas-admin >/dev/null
        echo "Approved DEV administrative role mapping verified; existing sessions invalidated."
    '

# Re-run the permanent technical-identity reconciler in forced mode and verify
# its exact effective privilege set before deleting the recovery identity.
run_forced_technical_identity_reconcile

remove_recovery_identities
unset RECOVERY_ADMIN_USERNAME RECOVERY_ADMIN_PASSWORD
trap - EXIT INT TERM
"${COMPOSE[@]}" "${ENV_FILES[@]}" "${COMPOSE_FILES[@]}" restart keycloak
wait_for_keycloak
verify_permanent_technical_identity_after_restart

echo "Persisted Keycloak volume migrated to the permanent technical identity."
echo "The approved DEV administrator sessions were invalidated; a fresh sign-in is required before role verification."
