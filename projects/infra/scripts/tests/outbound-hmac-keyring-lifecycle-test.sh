#!/usr/bin/env bash

set -Eeuo pipefail

REPOSITORY_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
LIFECYCLE_SCRIPT="$REPOSITORY_ROOT/backend/app/docker/outbound-hmac-keyring-lifecycle.sh"
TEST_ROOT="$(mktemp -d)"
TARGET_OWNER="$(id -u):$(id -g)"
MATERIAL_V1="$(printf '11111111111111111111111111111111' | base64 | tr -d '\n')"
MATERIAL_V2="$(printf '22222222222222222222222222222222' | base64 | tr -d '\n')"
MATERIAL_V3="$(printf '33333333333333333333333333333333' | base64 | tr -d '\n')"
MATERIAL_V4="$(printf '44444444444444444444444444444444' | base64 | tr -d '\n')"

cleanup() {
  rm -rf -- "$TEST_ROOT"
}
trap cleanup EXIT INT TERM

fail() {
  printf 'outbound-hmac-keyring-lifecycle-test: FAIL: %s\n' "$*" >&2
  exit 1
}

new_fixture() {
  FIXTURE="$TEST_ROOT/$1"
  SOURCE_FILE="$FIXTURE/source.json"
  TARGET_FILE="$FIXTURE/volume/conversation-outbound-attempt-hmac-keyring.json"
  STATE_FILE="$FIXTURE/volume/.outbound-hmac-lifecycle-state.json"
  PENDING_FILE="$FIXTURE/volume/.outbound-hmac-lifecycle-pending.json"
  APPROVAL_FILE="$FIXTURE/approval/outbound-hmac-key-removal.json"
  OUTPUT_FILE="$FIXTURE/output.log"
  SOURCE_PARENT_OVERRIDE=
  mkdir -p "$FIXTURE/volume" "$FIXTURE/approval" "$FIXTURE/tmp"
  chmod 700 "$FIXTURE" "$FIXTURE/volume" "$FIXTURE/approval" "$FIXTURE/tmp"
}

write_keyring() {
  local active_file="$1"
  shift
  local key_id key_material separator=

  rm -f -- "$active_file"
  printf '{"keys":{' >"$active_file"
  while [ "$#" -gt 0 ]; do
    key_id="$1"
    key_material="$2"
    shift 2
    printf '%s"%s":"%s"' "$separator" "$key_id" "$key_material" >>"$active_file"
    separator=,
  done
  printf '}}\n' >>"$active_file"
  chmod 600 "$active_file"
}

write_approval() {
  local approval_id="$1"
  shift
  write_approval_file "$APPROVAL_FILE" "$approval_id" "$@"
}

write_approval_file() {
  local approval_output_file="$1"
  local approval_id="$2"
  shift 2
  jq -n \
    --arg approval_id "$approval_id" \
    --argjson removed_ids "$(printf '%s\n' "$@" | jq -Rsc 'split("\n")[:-1] | sort')" '
      {
        version: 1,
        approvalId: $approval_id,
        approvedAt: "2026-08-23T12:00:00Z",
        removedKeyIds: $removed_ids,
        ledgerRetentionEvidenceId: "ledger-evidence-1",
        backupRetentionEvidenceId: "backup-evidence-1",
        recoveryDrillEvidenceId: "recovery-evidence-1",
        securityApproved: true,
        sreApproved: true
      }
    ' >"$approval_output_file"
  chmod 600 "$approval_output_file"
}

invoke_lifecycle() {
  local active_key_id="$1"
  local failpoint="${2:-}"
  local source_replacement="${3:-}"
  local approval_replacement="${4:-}"
  local -a extra_environment=()

  if [ -n "$failpoint" ] || [ -n "$source_replacement" ] || [ -n "$approval_replacement" ]; then
    extra_environment+=(
      OUTBOUND_HMAC_LIFECYCLE_TESTING=true
    )
  fi
  if [ -n "$failpoint" ]; then
    extra_environment+=("OUTBOUND_HMAC_LIFECYCLE_TEST_FAILPOINT=$failpoint")
  fi
  if [ -n "$source_replacement" ]; then
    extra_environment+=("OUTBOUND_HMAC_LIFECYCLE_TEST_REPLACE_SOURCE_WITH=$source_replacement")
  fi
  if [ -n "$approval_replacement" ]; then
    extra_environment+=("OUTBOUND_HMAC_LIFECYCLE_TEST_REPLACE_APPROVAL_WITH=$approval_replacement")
  fi
  set +e
  env \
    "OUTBOUND_HMAC_SOURCE_FILE=$SOURCE_FILE" \
    "OUTBOUND_HMAC_TARGET_FILE=$TARGET_FILE" \
    "OUTBOUND_HMAC_STATE_FILE=$STATE_FILE" \
    "OUTBOUND_HMAC_PENDING_FILE=$PENDING_FILE" \
    "OUTBOUND_HMAC_APPROVAL_FILE=$APPROVAL_FILE" \
    "OUTBOUND_HMAC_APPROVAL_DIRECTORY=$FIXTURE/approval" \
    "OUTBOUND_HMAC_SOURCE_PARENT=$SOURCE_PARENT_OVERRIDE" \
    "OUTBOUND_HMAC_ACTIVE_KEY_ID=$active_key_id" \
    "OUTBOUND_HMAC_TARGET_OWNER=$TARGET_OWNER" \
    "TMPDIR=$FIXTURE/tmp" \
    "${extra_environment[@]}" \
    "$LIFECYCLE_SCRIPT" >"$OUTPUT_FILE" 2>&1
  LIFECYCLE_STATUS=$?
  set -e
}

assert_private_output() {
  local forbidden
  for forbidden in \
    key-v1 key-v2 key-v3 key-v4 \
    "$MATERIAL_V1" "$MATERIAL_V2" "$MATERIAL_V3" "$MATERIAL_V4" \
    ledger-evidence-1 backup-evidence-1 recovery-evidence-1 \
    approval-1 approval-2 approval-a approval-b approval-mixed; do
    if grep -Fq "$forbidden" "$OUTPUT_FILE"; then
      fail 'lifecycle output exposed protected rotation data'
    fi
  done
}

expect_applied() {
  local active_key_id="$1"
  invoke_lifecycle "$active_key_id"
  [ "$LIFECYCLE_STATUS" -eq 0 ] || fail 'expected lifecycle transition to be applied'
  grep -Fqx 'outbound-hmac-keyring-lifecycle: applied' "$OUTPUT_FILE" \
    || fail 'successful lifecycle output is not the fixed low-information message'
  assert_private_output
}

expect_rejected() {
  local active_key_id="$1"
  invoke_lifecycle "$active_key_id"
  [ "$LIFECYCLE_STATUS" -eq 1 ] || fail 'expected lifecycle transition to be rejected'
  grep -Fqx 'outbound-hmac-keyring-lifecycle: rejected' "$OUTPUT_FILE" \
    || fail 'rejected lifecycle output is not the fixed low-information message'
  assert_private_output
}

expect_interrupted() {
  local active_key_id="$1"
  local failpoint="$2"
  invoke_lifecycle "$active_key_id" "$failpoint"
  [ "$LIFECYCLE_STATUS" -eq 75 ] || fail 'expected the lifecycle test failpoint to interrupt'
  grep -Fqx 'outbound-hmac-keyring-lifecycle: simulated interruption' "$OUTPUT_FILE" \
    || fail 'simulated interruption output is not the fixed test message'
  assert_private_output
}

assert_state() {
  local jq_filter="$1"
  jq -e "$jq_filter" "$STATE_FILE" >/dev/null \
    || fail 'committed lifecycle state does not satisfy the expected transition'
  [ "$(stat -c '%a' "$STATE_FILE")" = 400 ] \
    || fail 'committed lifecycle state must remain owner-only'
  [ "$(stat -c '%a' "$TARGET_FILE")" = 400 ] \
    || fail 'installed keyring must remain read-only'
}

for required_command in base64 cmp env flock grep jq mkfifo mktemp seq sha256sum sleep stat; do
  command -v "$required_command" >/dev/null 2>&1 \
    || fail "required test command is unavailable: $required_command"
done
[ -x "$LIFECYCLE_SCRIPT" ] || fail 'lifecycle script must be executable'
sh -n "$LIFECYCLE_SCRIPT" || fail 'lifecycle script has invalid shell syntax'

# Fresh install and an unchanged reboot establish an idempotent committed state.
new_fixture staged-rotation
write_keyring "$SOURCE_FILE" key-v1 "$MATERIAL_V1"
expect_applied key-v1
assert_state '
  .activeKeyId == "key-v1"
  and (.readKeys | keys) == ["key-v1"]
  and .retiredKeys == {}
  and .usedApprovalIds == []
'
cp "$STATE_FILE" "$FIXTURE/state.before-reboot"
cp "$TARGET_FILE" "$FIXTURE/target.before-reboot"
expect_applied key-v1
cmp -s "$STATE_FILE" "$FIXTURE/state.before-reboot" \
  || fail 'an unchanged reboot modified committed lifecycle state'
cmp -s "$TARGET_FILE" "$FIXTURE/target.before-reboot" \
  || fail 'an unchanged reboot rewrote the installed keyring'

# Add/read-old must be committed before a later active-key switch.
write_keyring "$SOURCE_FILE" key-v1 "$MATERIAL_V1" key-v2 "$MATERIAL_V2"
expect_applied key-v1
assert_state '
  .activeKeyId == "key-v1"
  and (.readKeys | keys) == ["key-v1", "key-v2"]
'
cp "$STATE_FILE" "$FIXTURE/state.before-invalid-switch"
cp "$TARGET_FILE" "$FIXTURE/target.before-invalid-switch"
write_keyring "$SOURCE_FILE" \
  key-v1 "$MATERIAL_V1" key-v2 "$MATERIAL_V2" key-v3 "$MATERIAL_V3"
expect_rejected key-v3
cmp -s "$STATE_FILE" "$FIXTURE/state.before-invalid-switch" \
  || fail 'add-and-switch rejection mutated lifecycle state'
cmp -s "$TARGET_FILE" "$FIXTURE/target.before-invalid-switch" \
  || fail 'add-and-switch rejection mutated the installed keyring'

write_keyring "$SOURCE_FILE" key-v1 "$MATERIAL_V1" key-v2 "$MATERIAL_V2"
expect_applied key-v2
assert_state '
  .activeKeyId == "key-v2"
  and (.readKeys | keys) == ["key-v1", "key-v2"]
'

# Addition and retirement are separate approved updates. A candidate cannot
# smuggle a new read key into the same transition that consumes a removal
# approval, even while the active key remains unchanged.
cp "$STATE_FILE" "$FIXTURE/state.before-add-and-retire"
cp "$TARGET_FILE" "$FIXTURE/target.before-add-and-retire"
write_keyring "$SOURCE_FILE" key-v2 "$MATERIAL_V2" key-v3 "$MATERIAL_V3"
write_approval approval-mixed key-v1
expect_rejected key-v2
cmp -s "$STATE_FILE" "$FIXTURE/state.before-add-and-retire" \
  || fail 'add-and-retire rejection mutated lifecycle state'
cmp -s "$TARGET_FILE" "$FIXTURE/target.before-add-and-retire" \
  || fail 'add-and-retire rejection mutated the installed keyring'
rm -f -- "$APPROVAL_FILE"

# Replacing bytes under an existing ID is rejected without any side effect.
cp "$STATE_FILE" "$FIXTURE/state.before-replacement"
cp "$TARGET_FILE" "$FIXTURE/target.before-replacement"
write_keyring "$SOURCE_FILE" key-v1 "$MATERIAL_V1" key-v2 "$MATERIAL_V3"
expect_rejected key-v2
cmp -s "$STATE_FILE" "$FIXTURE/state.before-replacement" \
  || fail 'same-ID material replacement mutated lifecycle state'
cmp -s "$TARGET_FILE" "$FIXTURE/target.before-replacement" \
  || fail 'same-ID material replacement mutated the installed keyring'

# Removal fails closed without exact evidence and succeeds with one exact,
# owner-only approval whose ID is committed atomically with the tombstone.
write_keyring "$SOURCE_FILE" key-v2 "$MATERIAL_V2"
expect_rejected key-v2
write_approval approval-1 key-v3
expect_rejected key-v2
write_approval approval-1 key-v1
chmod 644 "$APPROVAL_FILE"
expect_rejected key-v2
chmod 600 "$APPROVAL_FILE"
mv "$APPROVAL_FILE" "$FIXTURE/approval.saved"
ln -s "$FIXTURE/approval.saved" "$APPROVAL_FILE"
expect_rejected key-v2
rm "$APPROVAL_FILE"
mv "$FIXTURE/approval.saved" "$APPROVAL_FILE"
expect_applied key-v2
assert_state '
  .activeKeyId == "key-v2"
  and (.readKeys | keys) == ["key-v2"]
  and (.retiredKeys | keys) == ["key-v1"]
  and .usedApprovalIds == ["approval-1"]
'
cp "$STATE_FILE" "$FIXTURE/state.after-removal"
expect_applied key-v2
cmp -s "$STATE_FILE" "$FIXTURE/state.after-removal" \
  || fail 'reboot with a stale approval changed committed state'

write_keyring "$SOURCE_FILE" key-v1 "$MATERIAL_V1" key-v2 "$MATERIAL_V2"
expect_rejected key-v2
write_keyring "$SOURCE_FILE" key-v2 "$MATERIAL_V2" key-v3 "$MATERIAL_V1"
expect_rejected key-v2

# Approval IDs are one-shot even when a later manifest has a new exact removal
# set. A new ID is required after add/read-old and switch complete.
write_keyring "$SOURCE_FILE" key-v2 "$MATERIAL_V2" key-v3 "$MATERIAL_V3"
expect_applied key-v2
expect_applied key-v3
write_keyring "$SOURCE_FILE" key-v3 "$MATERIAL_V3"
write_approval approval-1 key-v2
expect_rejected key-v3
write_approval approval-2 key-v2
expect_applied key-v3
assert_state '
  (.retiredKeys | keys) == ["key-v1", "key-v2"]
  and .usedApprovalIds == ["approval-1", "approval-2"]
'

# A pending journal makes both interruption windows recoverable. The approval
# remains reusable only until the corresponding removal is committed.
new_fixture interrupted-removal
write_keyring "$SOURCE_FILE" key-v1 "$MATERIAL_V1"
expect_applied key-v1
write_keyring "$SOURCE_FILE" key-v1 "$MATERIAL_V1" key-v2 "$MATERIAL_V2"
expect_interrupted key-v1 after-pending
[ -f "$PENDING_FILE" ] || fail 'pending journal was not persisted before copy'
jq -e '(.readKeys | keys) == ["key-v1"]' "$STATE_FILE" >/dev/null \
  || fail 'after-pending interruption changed committed state'
expect_applied key-v1
[ ! -e "$PENDING_FILE" ] || fail 'retry did not clear the pending journal'

expect_applied key-v2
write_keyring "$SOURCE_FILE" key-v2 "$MATERIAL_V2"
write_approval approval-2 key-v1
expect_interrupted key-v2 after-copy
jq -e '
  (.readKeys | keys) == ["key-v1", "key-v2"]
  and .usedApprovalIds == []
' "$STATE_FILE" >/dev/null \
  || fail 'after-copy interruption consumed approval before commit'
jq -e '(.keys | keys) == ["key-v2"]' "$TARGET_FILE" >/dev/null \
  || fail 'after-copy fixture did not reach the recoverable overwrite window'
expect_applied key-v2
assert_state '
  (.readKeys | keys) == ["key-v2"]
  and (.retiredKeys | keys) == ["key-v1"]
  and .usedApprovalIds == ["approval-2"]
'
[ ! -e "$PENDING_FILE" ] || fail 'removal retry did not clear the pending journal'

# A crash after the state commit but before journal cleanup is also idempotent.
write_keyring "$SOURCE_FILE" key-v2 "$MATERIAL_V2" key-v3 "$MATERIAL_V3"
expect_interrupted key-v2 after-state
jq -e '(.readKeys | keys) == ["key-v2", "key-v3"]' "$STATE_FILE" >/dev/null \
  || fail 'after-state fixture did not commit the next state'
[ -f "$PENDING_FILE" ] || fail 'after-state fixture must retain the pending journal'
expect_applied key-v2
[ ! -e "$PENDING_FILE" ] || fail 'reboot did not clean an already committed journal'

# A target that is neither the committed nor pending key set cannot be adopted.
new_fixture unknown-recovery-state
write_keyring "$SOURCE_FILE" key-v1 "$MATERIAL_V1"
expect_applied key-v1
write_keyring "$SOURCE_FILE" key-v1 "$MATERIAL_V1" key-v2 "$MATERIAL_V2"
expect_interrupted key-v1 after-pending
write_keyring "$TARGET_FILE" key-v4 "$MATERIAL_V4"
chmod 400 "$TARGET_FILE"
expect_rejected key-v1

# Existing volumes from before the lifecycle gate are adopted only when the
# candidate and mounted material are identical (the init --resume path).
new_fixture legacy-adoption
write_keyring "$SOURCE_FILE" key-v1 "$MATERIAL_V1"
write_keyring "$TARGET_FILE" key-v1 "$MATERIAL_V1"
chmod 400 "$TARGET_FILE"
expect_applied key-v1
assert_state '(.readKeys | keys) == ["key-v1"] and .activeKeyId == "key-v1"'

new_fixture legacy-mismatch
write_keyring "$SOURCE_FILE" key-v1 "$MATERIAL_V2"
write_keyring "$TARGET_FILE" key-v1 "$MATERIAL_V1"
chmod 400 "$TARGET_FILE"
expect_rejected key-v1
[ ! -e "$STATE_FILE" ] || fail 'legacy mismatch created lifecycle state'

# The host owner may replace a read-only bind source after validation. The
# lifecycle must install the exact private snapshot from which next-state was
# derived, never re-read the live source path during the transition.
new_fixture source-snapshot-toctou
write_keyring "$SOURCE_FILE" key-v1 "$MATERIAL_V1"
cp "$SOURCE_FILE" "$FIXTURE/expected-source-snapshot.json"
chmod 600 "$FIXTURE/expected-source-snapshot.json"
write_keyring "$FIXTURE/replacement-source.json" key-v4 "$MATERIAL_V4"
invoke_lifecycle key-v1 '' "$FIXTURE/replacement-source.json"
[ "$LIFECYCLE_STATUS" -eq 0 ] || fail 'source replacement after snapshot rejected a valid snapshot'
grep -Fqx 'outbound-hmac-keyring-lifecycle: applied' "$OUTPUT_FILE" \
  || fail 'snapshot transition output is not the fixed low-information message'
assert_private_output
cmp -s "$TARGET_FILE" "$FIXTURE/expected-source-snapshot.json" \
  || fail 'installed keyring diverged from the validated private source snapshot'
jq -e '(.keys | keys) == ["key-v4"]' "$SOURCE_FILE" >/dev/null \
  || fail 'TOCTOU fixture did not replace the live source after snapshot'
assert_state '
  .activeKeyId == "key-v1"
  and (.readKeys | keys) == ["key-v1"]
'

# A live approval bind may also be replaced after it has been snapshotted. All
# validation and state derivation must consume approval A from the private
# snapshot; the later, mismatched approval B must never influence the in-flight
# retirement.
new_fixture approval-snapshot-toctou
write_keyring "$SOURCE_FILE" key-v1 "$MATERIAL_V1"
expect_applied key-v1
write_keyring "$SOURCE_FILE" key-v1 "$MATERIAL_V1" key-v2 "$MATERIAL_V2"
expect_applied key-v1
expect_applied key-v2
write_keyring "$SOURCE_FILE" key-v2 "$MATERIAL_V2"
write_approval approval-a key-v1
write_approval_file "$FIXTURE/replacement-approval.json" approval-b key-v4
invoke_lifecycle key-v2 '' '' "$FIXTURE/replacement-approval.json"
[ "$LIFECYCLE_STATUS" -eq 0 ] \
  || fail 'approval replacement after snapshot rejected coherent approval A'
grep -Fqx 'outbound-hmac-keyring-lifecycle: applied' "$OUTPUT_FILE" \
  || fail 'approval snapshot transition output is not the fixed low-information message'
assert_private_output
jq -e '
  .approvalId == "approval-b"
  and .removedKeyIds == ["key-v4"]
' "$APPROVAL_FILE" >/dev/null \
  || fail 'TOCTOU fixture did not replace the live approval after snapshot'
jq -e '(.keys | keys) == ["key-v2"]' "$TARGET_FILE" >/dev/null \
  || fail 'approval snapshot retirement installed an incoherent keyring'
assert_state '
  .activeKeyId == "key-v2"
  and (.readKeys | keys) == ["key-v2"]
  and (.retiredKeys | keys) == ["key-v1"]
  and .usedApprovalIds == ["approval-a"]
'
[ ! -e "$PENDING_FILE" ] \
  || fail 'approval snapshot retirement left an uncommitted pending journal'

# The embedded HML trust boundary checks the directory bind itself. PRD has the
# same file/owner checks plus its host preflight; DEV creates the owner-only
# directories before rendering Compose.
new_fixture trust-boundary
SOURCE_PARENT_OVERRIDE="$FIXTURE/source-parent"
mkdir "$SOURCE_PARENT_OVERRIDE"
chmod 700 "$SOURCE_PARENT_OVERRIDE"
SOURCE_FILE="$SOURCE_PARENT_OVERRIDE/conversation-outbound-attempt-hmac-keyring.json"
write_keyring "$SOURCE_FILE" key-v1 "$MATERIAL_V1"
chmod 755 "$SOURCE_PARENT_OVERRIDE"
expect_rejected key-v1
chmod 700 "$SOURCE_PARENT_OVERRIDE"
chmod 644 "$SOURCE_FILE"
expect_rejected key-v1
chmod 600 "$SOURCE_FILE"
mv "$SOURCE_FILE" "$FIXTURE/source.saved"
ln -s "$FIXTURE/source.saved" "$SOURCE_FILE"
expect_rejected key-v1
rm "$SOURCE_FILE"
mv "$FIXTURE/source.saved" "$SOURCE_FILE"
mv "$FIXTURE/approval" "$FIXTURE/approval.real"
ln -s "$FIXTURE/approval.real" "$FIXTURE/approval"
expect_rejected key-v1
rm "$FIXTURE/approval"
mv "$FIXTURE/approval.real" "$FIXTURE/approval"
expect_applied key-v1

new_fixture identifier-boundary
write_keyring "$SOURCE_FILE" key-v1 "$MATERIAL_V1"
expect_rejected 'key:v1'
write_keyring "$SOURCE_FILE" 'key:v1' "$MATERIAL_V1"
expect_rejected key-v1

# The named-volume advisory lock serializes every initializer from snapshot to
# cleanup. A contender fails without mutation, and a killed holder releases the
# kernel lock even though the owner-only lock file remains on disk.
start_lock_holder() {
  local ready_file="$FIXTURE/lock-ready"
  local release_file="$FIXTURE/lock-release"
  local attempt

  rm -f -- "$ready_file" "$release_file"
  mkfifo -m 600 "$release_file"
  env \
    "OUTBOUND_HMAC_SOURCE_FILE=$SOURCE_FILE" \
    "OUTBOUND_HMAC_TARGET_FILE=$TARGET_FILE" \
    "OUTBOUND_HMAC_STATE_FILE=$STATE_FILE" \
    "OUTBOUND_HMAC_PENDING_FILE=$PENDING_FILE" \
    "OUTBOUND_HMAC_APPROVAL_FILE=$APPROVAL_FILE" \
    "OUTBOUND_HMAC_APPROVAL_DIRECTORY=$FIXTURE/approval" \
    "OUTBOUND_HMAC_SOURCE_PARENT=$SOURCE_PARENT_OVERRIDE" \
    "OUTBOUND_HMAC_ACTIVE_KEY_ID=key-v1" \
    "OUTBOUND_HMAC_TARGET_OWNER=$TARGET_OWNER" \
    "OUTBOUND_HMAC_LIFECYCLE_TESTING=true" \
    "OUTBOUND_HMAC_LIFECYCLE_TEST_LOCK_READY_FILE=$ready_file" \
    "OUTBOUND_HMAC_LIFECYCLE_TEST_LOCK_RELEASE_FILE=$release_file" \
    "TMPDIR=$FIXTURE/tmp" \
    "$LIFECYCLE_SCRIPT" >"$FIXTURE/lock-holder.log" 2>&1 &
  LOCK_HOLDER_PID=$!
  LOCK_RELEASE_FILE="$release_file"

  for attempt in $(seq 1 100); do
    [ -e "$ready_file" ] && return 0
    kill -0 "$LOCK_HOLDER_PID" 2>/dev/null \
      || fail 'lock holder exited before acquiring the advisory lock'
    sleep 0.05
  done
  fail 'lock holder did not report acquisition'
}

new_fixture concurrent-initializers
write_keyring "$SOURCE_FILE" key-v1 "$MATERIAL_V1"
start_lock_holder
invoke_lifecycle key-v1
[ "$LIFECYCLE_STATUS" -eq 1 ] || fail 'concurrent initializer acquired an already-held lock'
[ ! -e "$STATE_FILE" ] && [ ! -e "$TARGET_FILE" ] && [ ! -e "$PENDING_FILE" ] \
  || fail 'rejected concurrent initializer mutated lifecycle artifacts'
printf 'release\n' >"$LOCK_RELEASE_FILE"
wait "$LOCK_HOLDER_PID" || fail 'serialized lock holder did not complete successfully'
grep -Fqx 'outbound-hmac-keyring-lifecycle: applied' "$FIXTURE/lock-holder.log" \
  || fail 'serialized lock holder did not emit the fixed success result'
[ "$(stat -c '%a' "$FIXTURE/volume/.outbound-hmac-lifecycle.lock")" = 600 ] \
  || fail 'persistent lifecycle lock file must remain owner-only'

new_fixture crash-releases-lock
write_keyring "$SOURCE_FILE" key-v1 "$MATERIAL_V1"
start_lock_holder
kill -KILL "$LOCK_HOLDER_PID"
set +e
wait "$LOCK_HOLDER_PID" 2>/dev/null
set -e
expect_applied key-v1
assert_state '.activeKeyId == "key-v1" and (.readKeys | keys) == ["key-v1"]'

printf 'outbound-hmac-keyring-lifecycle-test: PASS\n'
