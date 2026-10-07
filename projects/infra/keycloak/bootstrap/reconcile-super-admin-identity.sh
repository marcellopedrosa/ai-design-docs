#!/bin/sh

# Reconciles the mutable username/email of the canonical human Super Admin in
# local DEV. The stable human_principal_id and ROLE_SUPER_ADMIN mapping anchor
# the identity. An exact duplicate of the retired DEV identity is removed only
# after the canonical account and its global role have been verified.
set -eu
umask 077

KCADM_BIN="${KCADM_BIN:-/opt/keycloak/bin/kcadm.sh}"
ADMIN_REALM=saas-admin
CANONICAL_IDENTITY=djmarcellopedrosa@gmail.com
CANONICAL_HUMAN_ID=dev-superadmin-primary
LEGACY_IDENTITY=superadmin@duoset.com.br
RUNTIME_ENVIRONMENT="${KEYCLOAK_RUNTIME_ENVIRONMENT:-production}"

usage() {
    echo "Usage: $0 verify|reconcile KCADM_CONFIG" >&2
    exit 2
}

fail() {
    echo "ERROR: $*" >&2
    exit 1
}

[ "$#" -eq 2 ] || usage
MODE="$1"
KCADM_CONFIG="$2"
case "$MODE" in
    verify|reconcile) ;;
    *) usage ;;
esac
case "$RUNTIME_ENVIRONMENT" in
    dev) ;;
    hml|production)
        echo "Super Admin human identity is not repository-provisioned outside DEV."
        exit 0
        ;;
    *) fail "KEYCLOAK_RUNTIME_ENVIRONMENT must be dev, hml or production." ;;
esac

[ -f "$KCADM_CONFIG" ] && [ -r "$KCADM_CONFIG" ] \
    || fail "The authenticated kcadm session file is unavailable."
[ -x "$KCADM_BIN" ] \
    || fail "The Keycloak administration client is unavailable."

WORK_DIR="$(mktemp -d /tmp/saas-super-admin-identity.XXXXXX)"
USERNAME_IDS_FILE="$WORK_DIR/username-ids.csv"
EMAIL_IDS_FILE="$WORK_DIR/email-ids.csv"
HUMAN_IDS_FILE="$WORK_DIR/human-ids.csv"
LEGACY_USERNAME_IDS_FILE="$WORK_DIR/legacy-username-ids.csv"
LEGACY_EMAIL_IDS_FILE="$WORK_DIR/legacy-email-ids.csv"
ROLE_IDS_FILE="$WORK_DIR/role-ids.csv"
ROLE_NAMES_FILE="$WORK_DIR/role-names.csv"
VALUE_FILE="$WORK_DIR/value.csv"

cleanup() {
    rm -rf -- "$WORK_DIR"
}
trap cleanup EXIT
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM

kcadm() {
    "$KCADM_BIN" "$@" --config "$KCADM_CONFIG"
}

inventory_ids() {
    inventory_file="$1"
    inventory_label="$2"
    INVENTORY_COUNT=0
    INVENTORY_ID=""
    while IFS= read -r inventory_candidate || [ -n "$inventory_candidate" ]; do
        inventory_candidate="$(printf '%s' "$inventory_candidate" | tr -d '\r')"
        [ -n "$inventory_candidate" ] || continue
        case "$inventory_candidate" in
            ????????-????-????-????-????????????) ;;
            *) fail "$inventory_label returned an invalid user identifier." ;;
        esac
        printf '%s\n' "$inventory_candidate" | LC_ALL=C grep -Eq '^[0-9A-Fa-f-]+$' \
            || fail "$inventory_label returned an unsafe user identifier."
        INVENTORY_COUNT=$((INVENTORY_COUNT + 1))
        [ "$INVENTORY_COUNT" -le 1 ] \
            || fail "$inventory_label is duplicated or ambiguous."
        INVENTORY_ID="$inventory_candidate"
    done < "$inventory_file"
}

merge_candidate() {
    candidate_source="$1"
    candidate_id="$2"
    [ -n "$candidate_id" ] || return 0
    if [ -n "$ADMIN_USER_ID" ] && [ "$ADMIN_USER_ID" != "$candidate_id" ]; then
        fail "$candidate_source belongs to a different user."
    fi
    ADMIN_USER_ID="$candidate_id"
}

query_identity_anchors() {
    kcadm get users -r "$ADMIN_REALM" \
        -q "username=$CANONICAL_IDENTITY" -q exact=true -q first=0 -q max=2 \
        --fields id --format csv --noquotes > "$USERNAME_IDS_FILE" \
        || fail "Could not inspect the canonical Super Admin username."
    inventory_ids "$USERNAME_IDS_FILE" "The canonical Super Admin username"
    USERNAME_COUNT="$INVENTORY_COUNT"
    USERNAME_USER_ID="$INVENTORY_ID"

    kcadm get users -r "$ADMIN_REALM" \
        -q "email=$CANONICAL_IDENTITY" -q exact=true -q first=0 -q max=2 \
        --fields id --format csv --noquotes > "$EMAIL_IDS_FILE" \
        || fail "Could not inspect the canonical Super Admin email."
    inventory_ids "$EMAIL_IDS_FILE" "The canonical Super Admin email"
    EMAIL_COUNT="$INVENTORY_COUNT"
    EMAIL_USER_ID="$INVENTORY_ID"

    kcadm get users -r "$ADMIN_REALM" \
        -q "q=human_principal_id:$CANONICAL_HUMAN_ID" \
        -q first=0 -q max=2 --fields id --format csv --noquotes \
        > "$HUMAN_IDS_FILE" \
        || fail "Could not inspect the canonical human principal identifier."
    inventory_ids "$HUMAN_IDS_FILE" "The canonical human principal identifier"
    HUMAN_ID_COUNT="$INVENTORY_COUNT"
    HUMAN_ID_USER_ID="$INVENTORY_ID"

    kcadm get users -r "$ADMIN_REALM" \
        -q "username=$LEGACY_IDENTITY" -q exact=true -q first=0 -q max=2 \
        --fields id --format csv --noquotes > "$LEGACY_USERNAME_IDS_FILE" \
        || fail "Could not inspect the retired Super Admin username."
    inventory_ids "$LEGACY_USERNAME_IDS_FILE" "The retired Super Admin username"
    LEGACY_USERNAME_COUNT="$INVENTORY_COUNT"
    LEGACY_USERNAME_USER_ID="$INVENTORY_ID"

    kcadm get users -r "$ADMIN_REALM" \
        -q "email=$LEGACY_IDENTITY" -q exact=true -q first=0 -q max=2 \
        --fields id --format csv --noquotes > "$LEGACY_EMAIL_IDS_FILE" \
        || fail "Could not inspect the retired Super Admin email."
    inventory_ids "$LEGACY_EMAIL_IDS_FILE" "The retired Super Admin email"
    LEGACY_EMAIL_COUNT="$INVENTORY_COUNT"
    LEGACY_EMAIL_USER_ID="$INVENTORY_ID"

    LEGACY_USER_ID=""
    if [ "$LEGACY_USERNAME_COUNT" -eq 0 ] && [ "$LEGACY_EMAIL_COUNT" -eq 0 ]; then
        return 0
    fi
    [ "$LEGACY_USERNAME_COUNT" -eq 1 ] \
        && [ "$LEGACY_EMAIL_COUNT" -eq 1 ] \
        && [ "$LEGACY_USERNAME_USER_ID" = "$LEGACY_EMAIL_USER_ID" ] \
        || fail "The retired Super Admin identity is partial, duplicated or ambiguous."
    LEGACY_USER_ID="$LEGACY_USERNAME_USER_ID"
}

select_admin_user() {
    ADMIN_USER_ID=""
    merge_candidate "The canonical Super Admin username" "$USERNAME_USER_ID"
    merge_candidate "The canonical Super Admin email" "$EMAIL_USER_ID"
    merge_candidate "The canonical human principal identifier" "$HUMAN_ID_USER_ID"

    if [ -z "$ADMIN_USER_ID" ] && [ -n "$LEGACY_USER_ID" ]; then
        ADMIN_USER_ID="$LEGACY_USER_ID"
    fi

    if [ -z "$ADMIN_USER_ID" ]; then
        kcadm get "roles/ROLE_SUPER_ADMIN/users" -r "$ADMIN_REALM" \
            -q first=0 -q max=2 --fields id --format csv --noquotes \
            > "$ROLE_IDS_FILE" \
            || fail "Could not inspect DEV Super Admin role members."
        inventory_ids "$ROLE_IDS_FILE" "The DEV Super Admin role membership"
        [ "$INVENTORY_COUNT" -eq 1 ] \
            || fail "No canonical anchor exists and the DEV Super Admin role is not unique."
        ADMIN_USER_ID="$INVENTORY_ID"
    fi
}

verify_admin_role() {
    kcadm get "users/$ADMIN_USER_ID/role-mappings/realm" -r "$ADMIN_REALM" \
        --fields name --format csv --noquotes > "$ROLE_NAMES_FILE" \
        || fail "Could not inspect the canonical Super Admin role mappings."
    tr -d '\r' < "$ROLE_NAMES_FILE" | grep -Fxq ROLE_SUPER_ADMIN \
        || fail "The canonical human identity is missing ROLE_SUPER_ADMIN."
}

read_user_field() {
    user_field="$1"
    kcadm get "users/$ADMIN_USER_ID" -r "$ADMIN_REALM" \
        --fields "$user_field" --format csv --noquotes > "$VALUE_FILE" \
        || fail "Could not inspect the canonical Super Admin $user_field."
    USER_FIELD_VALUE="$(tr -d '\r\n' < "$VALUE_FILE")"
}

query_identity_anchors
select_admin_user
verify_admin_role
read_user_field username
CURRENT_USERNAME="$USER_FIELD_VALUE"
read_user_field email
CURRENT_EMAIL="$USER_FIELD_VALUE"

if [ "$MODE" = verify ]; then
    [ "$CURRENT_USERNAME" = "$CANONICAL_IDENTITY" ] \
        && [ "$CURRENT_EMAIL" = "$CANONICAL_IDENTITY" ] \
        && [ "$USERNAME_COUNT" -eq 1 ] \
        && [ "$EMAIL_COUNT" -eq 1 ] \
        && [ "$HUMAN_ID_COUNT" -eq 1 ] \
        && [ -z "$LEGACY_USER_ID" ] \
        || fail "The DEV Super Admin identity requires controlled reconciliation."
    echo "DEV Super Admin identity is valid."
    exit 0
fi

if [ "$CURRENT_USERNAME" != "$CANONICAL_IDENTITY" ] \
        || [ "$CURRENT_EMAIL" != "$CANONICAL_IDENTITY" ] \
        || [ "$HUMAN_ID_COUNT" -ne 1 ]; then
    kcadm update "users/$ADMIN_USER_ID" -r "$ADMIN_REALM" \
        -s "username=$CANONICAL_IDENTITY" \
        -s "email=$CANONICAL_IDENTITY" \
        -s "attributes.human_principal_id=[\"$CANONICAL_HUMAN_ID\"]" \
        >/dev/null \
        || fail "Could not reconcile the DEV Super Admin identity."
fi

query_identity_anchors
[ "$USERNAME_COUNT" -eq 1 ] && [ "$USERNAME_USER_ID" = "$ADMIN_USER_ID" ] \
    && [ "$EMAIL_COUNT" -eq 1 ] && [ "$EMAIL_USER_ID" = "$ADMIN_USER_ID" ] \
    && [ "$HUMAN_ID_COUNT" -eq 1 ] && [ "$HUMAN_ID_USER_ID" = "$ADMIN_USER_ID" ] \
    || fail "The canonical DEV Super Admin identity failed reconciliation verification."
verify_admin_role

if [ -n "$LEGACY_USER_ID" ] && [ "$LEGACY_USER_ID" != "$ADMIN_USER_ID" ]; then
    kcadm delete "users/$LEGACY_USER_ID" -r "$ADMIN_REALM" >/dev/null \
        || fail "Could not remove the retired DEV Super Admin identity."
fi

query_identity_anchors
[ "$USERNAME_COUNT" -eq 1 ] && [ "$USERNAME_USER_ID" = "$ADMIN_USER_ID" ] \
    && [ "$EMAIL_COUNT" -eq 1 ] && [ "$EMAIL_USER_ID" = "$ADMIN_USER_ID" ] \
    && [ "$HUMAN_ID_COUNT" -eq 1 ] && [ "$HUMAN_ID_USER_ID" = "$ADMIN_USER_ID" ] \
    && [ -z "$LEGACY_USER_ID" ] \
    || fail "The DEV Super Admin identity failed post-reconciliation verification."
verify_admin_role

echo "DEV Super Admin identity was reconciled successfully."
