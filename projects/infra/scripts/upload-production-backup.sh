#!/usr/bin/env bash
set -Eeuo pipefail

# Encrypt and upload the last completed two-cluster production backup.
# AWS credentials are intentionally not read from this config; use an instance
# role or the standard, protected AWS credential chain of the deployment user.

umask 077

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPOSITORY_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
CONFIG_FILE="${REPOSITORY_ROOT}/.deploy/secrets/offsite-backup.env"
STATE_FILE="${REPOSITORY_ROOT}/.deploy/state/last-backup.env"
TEMPORARY_ARCHIVE=""
TEMPORARY_CHECKSUM=""
TEMPORARY_METADATA=""
TEMPORARY_MARKER=""
ADOPT_LEGACY_MARKERS=false
DEPLOY_LOCK_FD=""
REMOTE_MARKER_ADOPTION_TARGET=false
REMOTE_MARKER_ADOPTED=false
BACKUP_POLICY_ID="conversation-audit-backup-v1"
BACKUP_OBJECT_LOCK_MODE="COMPLIANCE"
BACKUP_OBJECT_LOCK_DAYS=35
BACKUP_RETENTION_TOLERANCE_SECONDS=60
BACKUP_LIFECYCLE_RULE_ID="agentefiscal-production-backup-retention-v1"
BACKUP_EXPIRATION_DAYS=45
BACKUP_NONCURRENT_EXPIRATION_DAYS=1
BACKUP_ABORT_MULTIPART_DAYS=1

usage() {
  cat <<EOF
Usage: upload-production-backup.sh --deploy-lock-fd FD [--config FILE] [--state-file FILE] [--adopt-legacy-markers]

Defaults:
  config:     $CONFIG_FILE
  state file: $STATE_FILE

Options:
  --deploy-lock-fd FD      Required descriptor for the exact protected deploy.lock;
                           the uploader acquires or confirms exclusive ownership.
  --adopt-legacy-markers   Adoption-only scan: no archive creation or S3 upload.
EOF
}

log() {
  printf '[offsite-backup] %s\n' "$*"
}

die() {
  printf '[offsite-backup] ERROR: %s\n' "$*" >&2
  exit 1
}

retention_matches_policy() {
  local last_modified="$1"
  local retain_until="$2"
  local last_modified_epoch retain_until_epoch actual_seconds expected_seconds
  last_modified_epoch="$(date -u -d "$last_modified" +'%s' 2>/dev/null)" \
    || return 1
  retain_until_epoch="$(date -u -d "$retain_until" +'%s' 2>/dev/null)" \
    || return 1
  actual_seconds=$((retain_until_epoch - last_modified_epoch))
  expected_seconds=$((BACKUP_OBJECT_LOCK_DAYS * 86400))
  (( actual_seconds >= expected_seconds - BACKUP_RETENTION_TOLERANCE_SECONDS \
      && actual_seconds <= expected_seconds + BACKUP_RETENTION_TOLERANCE_SECONDS ))
}

normalize_timestamp() {
  date -u -d "$1" +'%Y-%m-%dT%H:%M:%SZ' 2>/dev/null
}

cleanup() {
  local status=$?
  trap - EXIT INT TERM
  if [[ -n "$TEMPORARY_ARCHIVE" && -e "$TEMPORARY_ARCHIVE" ]]; then
    rm -f -- "$TEMPORARY_ARCHIVE"
  fi
  for temporary_file in \
    "$TEMPORARY_CHECKSUM" "$TEMPORARY_METADATA" "$TEMPORARY_MARKER"; do
    [[ -z "$temporary_file" || ! -e "$temporary_file" ]] \
      || rm -f -- "$temporary_file"
  done
  exit "$status"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

while (( $# > 0 )); do
  case "$1" in
    --config)
      [[ $# -ge 2 ]] || die "--config requires a value"
      CONFIG_FILE="$2"
      shift 2
      ;;
    --state-file)
      [[ $# -ge 2 ]] || die "--state-file requires a value"
      STATE_FILE="$2"
      shift 2
      ;;
    --adopt-legacy-markers)
      ADOPT_LEGACY_MARKERS=true
      shift
      ;;
    --deploy-lock-fd)
      [[ $# -ge 2 ]] || die "--deploy-lock-fd requires a value"
      DEPLOY_LOCK_FD="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *) die "Unknown option: $1" ;;
  esac
done

for command_name in age aws tar sha256sum stat awk sed grep sort find realpath jq \
  mktemp install date id chmod mv dirname basename env rmdir rm du df flock; do
  command -v "$command_name" >/dev/null 2>&1 \
    || die "Required command not found: $command_name"
done

validate_protected_file() {
  local file="$1"
  local label="$2"
  local owner mode mode_value
  [[ -f "$file" && ! -L "$file" ]] || die "$label must be a regular, non-symbolic-link file: $file"
  owner="$(stat -c '%u' "$file")"
  [[ "$owner" == "$(id -u)" ]] || die "$label must be owned by the deployment user"
  mode="$(stat -c '%a' "$file")"
  mode_value=$((8#$mode))
  (( (mode_value & 077) == 0 )) || die "$label must not be accessible by group/others (use mode 600)"
}

reject_duplicate_keys() {
  local file="$1"
  local duplicates
  duplicates="$(awk -F= '
    /^[[:space:]]*[A-Za-z_][A-Za-z0-9_]*[[:space:]]*=/ {
      key=$1
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", key)
      count[key]++
    }
    END { for (key in count) if (count[key] > 1) print key }
  ' "$file" | sort)"
  [[ -z "$duplicates" ]] || die "Duplicate keys in $file: $duplicates"
}

file_value() {
  local file="$1"
  local key="$2"
  awk -v wanted="$key" '
    { sub(/\r$/, "") }
    $0 ~ "^[[:space:]]*" wanted "[[:space:]]*=" {
      line=$0
      sub("^[[:space:]]*" wanted "[[:space:]]*=[[:space:]]*", "", line)
      sub(/[[:space:]]+$/, "", line)
      if ((substr(line, 1, 1) == "\"" && substr(line, length(line), 1) == "\"") ||
          (substr(line, 1, 1) == "\047" && substr(line, length(line), 1) == "\047")) {
        line=substr(line, 2, length(line)-2)
      }
      print line
      found++
    }
    END { if (found != 1) exit 1 }
  ' "$file"
}

validate_protected_file "$CONFIG_FILE" "Off-site backup config"
validate_protected_file "$STATE_FILE" "Last-backup state"
[[ "$DEPLOY_LOCK_FD" =~ ^[0-9]+$ ]] \
  && (( 10#$DEPLOY_LOCK_FD >= 3 )) \
  || die "--deploy-lock-fd must identify an inherited descriptor >= 3"
deploy_lock_file="$(dirname "$STATE_FILE")/deploy.lock"
validate_protected_file "$deploy_lock_file" "Production deployment lock"
lock_fd_path="/proc/$$/fd/$DEPLOY_LOCK_FD"
[[ -e "$lock_fd_path" \
    && "$(stat -Lc '%d:%i' "$lock_fd_path")" == "$(stat -c '%d:%i' "$deploy_lock_file")" ]] \
  || die "--deploy-lock-fd does not reference the protected deployment lock"
flock -n "$DEPLOY_LOCK_FD" \
  || die "Cannot acquire or confirm the production deployment/backup lock"
reject_duplicate_keys "$CONFIG_FILE"
reject_duplicate_keys "$STATE_FILE"

age_recipient="$(file_value "$CONFIG_FILE" BACKUP_AGE_RECIPIENT)" \
  || die "BACKUP_AGE_RECIPIENT must occur exactly once"
s3_uri="$(file_value "$CONFIG_FILE" BACKUP_S3_URI)" \
  || die "BACKUP_S3_URI must occur exactly once"
kms_key_id="$(file_value "$CONFIG_FILE" BACKUP_KMS_KEY_ID)" \
  || die "BACKUP_KMS_KEY_ID must occur exactly once"
aws_region="$(file_value "$CONFIG_FILE" AWS_REGION)" \
  || die "AWS_REGION must occur exactly once"
local_keep_count="$(file_value "$CONFIG_FILE" BACKUP_LOCAL_KEEP_COUNT)" \
  || die "BACKUP_LOCAL_KEEP_COUNT must occur exactly once"

[[ "$age_recipient" == age1* && "$age_recipient" != *[[:space:]]* ]] \
  || die "BACKUP_AGE_RECIPIENT must be a valid-looking age recipient"
[[ "$s3_uri" == s3://* && "$s3_uri" != *[[:space:]]* && "$s3_uri" != s3:// ]] \
  || die "BACKUP_S3_URI must be an s3:// bucket or prefix"
[[ -n "$kms_key_id" && "$kms_key_id" != *[[:space:]]* ]] \
  || die "BACKUP_KMS_KEY_ID is invalid"
[[ "$aws_region" == "sa-east-1" ]] \
  || die "AWS_REGION must be exactly sa-east-1 under $BACKUP_POLICY_ID"
[[ "$local_keep_count" =~ ^[0-9]+$ ]] \
  && (( 10#$local_keep_count == 7 )) \
  || die "BACKUP_LOCAL_KEEP_COUNT must be exactly 7 under $BACKUP_POLICY_ID"

backup_path="$(file_value "$STATE_FILE" backup_path)" \
  || die "Last-backup state has no unique backup_path"
state_project="$(file_value "$STATE_FILE" project)" \
  || die "Last-backup state has no unique project"
state_domain="$(file_value "$STATE_FILE" domain)" \
  || die "Last-backup state has no unique domain"
min_free_mb="$(file_value "$STATE_FILE" min_free_mb)" \
  || die "Last-backup state has no unique min_free_mb"
[[ "$min_free_mb" =~ ^[0-9]+$ && 10#$min_free_mb -ge 512 ]] \
  || die "Last-backup state contains an invalid free-space reserve"
[[ "$backup_path" == /* && "$backup_path" != / ]] || die "Recorded backup path is unsafe"
[[ -d "$backup_path" && ! -L "$backup_path" ]] \
  || die "Recorded backup path must be a real directory, not a link"
[[ "$(realpath --canonicalize-existing -- "$backup_path")" == "$backup_path" ]] \
  || die "Recorded backup path must already be canonical and contain no linked component"
backup_path="$(realpath --canonicalize-existing -- "$backup_path")"
[[ -d "$backup_path" && ! -L "$backup_path" ]] || die "Recorded backup directory is unsafe"
backup_root="$(realpath --canonicalize-existing -- "$(dirname "$backup_path")")"
[[ "$backup_path" == "$backup_root/"* ]] || die "Recorded backup escaped its backup root"
backup_root_marker="${backup_root}/.agentefiscal-production-backups"
validate_protected_file "$backup_root_marker" "Production backup-root marker"
reject_duplicate_keys "$backup_root_marker"
marker_project="$(file_value "$backup_root_marker" project)" \
  || die "Backup-root marker has no unique project"
marker_domain="$(file_value "$backup_root_marker" domain)" \
  || die "Backup-root marker has no unique domain"
[[ "$marker_project" == "$state_project" && "$marker_domain" == "$state_domain" ]] \
  || die "Backup root and last-backup state identify different installations"
if [[ "$ADOPT_LEGACY_MARKERS" != true ]]; then
[[ "$(stat -c '%u' "$backup_path")" == "$(id -u)" ]] \
  || die "Backup directory must be owned by the deployment user"
[[ -f "$backup_path/COMPLETED" && ! -e "$backup_path/.INCOMPLETE" ]] \
  || die "Backup is not marked COMPLETED"
[[ -f "$backup_path/SHA256SUMS" && -f "$backup_path/MANIFEST" ]] \
  || die "Backup manifest/checksums are absent"
[[ -z "$(find "$backup_path" -type l -print -quit)" ]] \
  || die "Backup must not contain symbolic links"

manifest_project="$(file_value "$backup_path/MANIFEST" compose_project)" \
  || die "Backup manifest has no unique compose_project"
manifest_domain="$(file_value "$backup_path/MANIFEST" domain)" \
  || die "Backup manifest has no unique domain"
[[ "$manifest_project" == "$state_project" && "$manifest_domain" == "$state_domain" ]] \
  || die "Backup state and manifest identify different installations"
(cd "$backup_path" && sha256sum --check --strict SHA256SUMS >/dev/null) \
  || die "Backup checksum verification failed"

archive_name="$(basename "$backup_path").tar.age"
archive_path="$(dirname "$backup_path")/$archive_name"
archive_checksum_path="${archive_path}.sha256"
archive_metadata_path="${archive_path}.metadata"
for local_artifact in "$archive_path" "$archive_checksum_path" "$archive_metadata_path"; do
  if [[ -e "$local_artifact" || -L "$local_artifact" ]]; then
    [[ -f "$local_artifact" && ! -L "$local_artifact" \
        && "$(stat -c '%u' "$local_artifact")" == "$(id -u)" ]] \
      || die "Existing local backup artifact is unsafe: $local_artifact"
  fi
done
existing_archive_parts=0
for local_artifact in "$archive_path" "$archive_checksum_path" "$archive_metadata_path"; do
  [[ ! -e "$local_artifact" ]] || existing_archive_parts=$((existing_archive_parts + 1))
done

# The archive, checksum and metadata are derived exclusively from the already
# verified dump directory. A power loss between their individual atomic renames
# can leave one or two final files behind. Recover that state deterministically
# instead of blocking every later retry forever.
if (( existing_archive_parts > 0 && existing_archive_parts < 3 )); then
  [[ ! -e "$backup_path/OFFSITE_UPLOAD" ]] \
    || die "Partial encrypted artifacts exist beside a completed off-site marker"
  log "Recovering an interrupted encrypted-archive commit"
  rm -f -- "$archive_path" "$archive_checksum_path" "$archive_metadata_path"
  existing_archive_parts=0
fi

manifest_sha256="$(sha256sum "$backup_path/MANIFEST" | awk '{print $1}')"
backup_sums_sha256="$(sha256sum "$backup_path/SHA256SUMS" | awk '{print $1}')"
if (( existing_archive_parts == 3 )); then
  validate_protected_file "$archive_path" "Pending encrypted archive"
  validate_protected_file "$archive_checksum_path" "Pending archive checksum"
  validate_protected_file "$archive_metadata_path" "Pending archive metadata"
  reject_duplicate_keys "$archive_metadata_path"
  archive_sha256="$(sha256sum "$archive_path" | awk '{print $1}')"
  archive_size="$(stat -c '%s' "$archive_path")"
  checksum_line="$(awk 'NR == 1 { print } NR > 1 { exit 2 }' "$archive_checksum_path")" \
    || die "Pending archive checksum must contain one line"
  [[ "$checksum_line" == "$archive_sha256  $archive_name" \
      && "$(file_value "$archive_metadata_path" archive_sha256)" == "$archive_sha256" \
      && "$(file_value "$archive_metadata_path" archive_size)" == "$archive_size" \
      && "$(file_value "$archive_metadata_path" manifest_sha256)" == "$manifest_sha256" \
      && "$(file_value "$archive_metadata_path" backup_sums_sha256)" == "$backup_sums_sha256" \
      && "$(file_value "$archive_metadata_path" age_recipient)" == "$age_recipient" ]] \
    || die "Pending encrypted archive does not belong to the recorded backup/config"
  log "Reusing the verified encrypted archive from a previous failed upload"
elif (( existing_archive_parts == 0 )); then
  backup_size_kb="$(du -sk -- "$backup_path" | awk '{print $1}')"
  available_kb="$(df -Pk -- "$backup_root" | awk 'END {print $4}')"
  [[ "$backup_size_kb" =~ ^[0-9]+$ && "$available_kb" =~ ^[0-9]+$ ]] \
    || die "Cannot calculate encrypted-archive capacity"
  required_kb=$((backup_size_kb + 10#$min_free_mb * 1024))
  (( available_kb >= required_kb )) \
    || die "Insufficient space for the encrypted archive plus ${min_free_mb} MiB reserve"

  TEMPORARY_ARCHIVE="$(mktemp "${archive_path}.tmp.XXXXXX")"
  log "Encrypting completed backup for off-site storage"
  tar --directory "$(dirname "$backup_path")" --create --file - \
    "$(basename "$backup_path")" \
    | age --recipient "$age_recipient" --output "$TEMPORARY_ARCHIVE"
  [[ -s "$TEMPORARY_ARCHIVE" ]] || die "Encrypted archive is empty"
  mv -f -- "$TEMPORARY_ARCHIVE" "$archive_path"
  TEMPORARY_ARCHIVE=""
  chmod 600 "$archive_path"
  archive_sha256="$(sha256sum "$archive_path" | awk '{print $1}')"
  archive_size="$(stat -c '%s' "$archive_path")"

  TEMPORARY_CHECKSUM="$(mktemp "${archive_checksum_path}.tmp.XXXXXX")"
  printf '%s  %s\n' "$archive_sha256" "$archive_name" >"$TEMPORARY_CHECKSUM"
  chmod 600 "$TEMPORARY_CHECKSUM"
  mv -f -- "$TEMPORARY_CHECKSUM" "$archive_checksum_path"
  TEMPORARY_CHECKSUM=""

  TEMPORARY_METADATA="$(mktemp "${archive_metadata_path}.tmp.XXXXXX")"
  printf 'archive_sha256=%s\narchive_size=%s\nmanifest_sha256=%s\nbackup_sums_sha256=%s\nage_recipient=%s\n' \
    "$archive_sha256" "$archive_size" "$manifest_sha256" \
    "$backup_sums_sha256" "$age_recipient" >"$TEMPORARY_METADATA"
  chmod 600 "$TEMPORARY_METADATA"
  mv -f -- "$TEMPORARY_METADATA" "$archive_metadata_path"
  TEMPORARY_METADATA=""
fi
fi

s3_without_scheme="${s3_uri#s3://}"
s3_bucket="${s3_without_scheme%%/*}"
if [[ "$s3_without_scheme" == */* ]]; then
  s3_prefix="${s3_without_scheme#*/}"
  s3_prefix="${s3_prefix%/}/"
else
  s3_prefix=""
fi
[[ -n "$s3_bucket" && "$s3_bucket" != *[!A-Za-z0-9._-]* ]] || die "Invalid S3 bucket name"
if [[ "$ADOPT_LEGACY_MARKERS" != true ]]; then
  s3_key="${s3_prefix}${archive_name}"
  s3_checksum_key="${s3_key}.sha256"
fi

aws_command=(env "AWS_REGION=$aws_region" "AWS_DEFAULT_REGION=$aws_region" \
  AWS_DEFAULT_OUTPUT=json AWS_PAGER= AWS_CLI_AUTO_PROMPT=off aws)
bucket_versioning="$(
  "${aws_command[@]}" s3api get-bucket-versioning --bucket "$s3_bucket"
)" || die "Cannot verify S3 bucket versioning"
jq -e '.Status == "Enabled"' <<<"$bucket_versioning" >/dev/null \
  || die "S3 bucket versioning must be Enabled"

bucket_location="$(
  "${aws_command[@]}" s3api get-bucket-location --bucket "$s3_bucket"
)" || die "Cannot verify S3 bucket location"
jq -e --arg region "$aws_region" '.LocationConstraint == $region' \
  <<<"$bucket_location" >/dev/null \
  || die "S3 bucket must be located in $aws_region"

public_access_block="$(
  "${aws_command[@]}" s3api get-public-access-block --bucket "$s3_bucket"
)" || die "Cannot verify S3 Block Public Access"
jq -e '
  .PublicAccessBlockConfiguration.BlockPublicAcls == true
  and .PublicAccessBlockConfiguration.IgnorePublicAcls == true
  and .PublicAccessBlockConfiguration.BlockPublicPolicy == true
  and .PublicAccessBlockConfiguration.RestrictPublicBuckets == true
' <<<"$public_access_block" >/dev/null \
  || die "S3 Block Public Access must enable all four controls"

object_lock_configuration="$(
  "${aws_command[@]}" s3api get-object-lock-configuration --bucket "$s3_bucket"
)" || die "Cannot verify S3 Object Lock configuration"
jq -e \
  --arg mode "$BACKUP_OBJECT_LOCK_MODE" \
  --argjson days "$BACKUP_OBJECT_LOCK_DAYS" '
    .ObjectLockConfiguration.ObjectLockEnabled == "Enabled"
    and .ObjectLockConfiguration.Rule.DefaultRetention.Mode == $mode
    and .ObjectLockConfiguration.Rule.DefaultRetention.Days == $days
    and (.ObjectLockConfiguration.Rule.DefaultRetention.Years == null)
  ' <<<"$object_lock_configuration" >/dev/null \
  || die "S3 Object Lock must default to ${BACKUP_OBJECT_LOCK_MODE}/${BACKUP_OBJECT_LOCK_DAYS}d"

lifecycle_configuration="$(
  "${aws_command[@]}" s3api get-bucket-lifecycle-configuration --bucket "$s3_bucket"
)" || die "Cannot verify S3 lifecycle configuration"
jq -e \
  --arg id "$BACKUP_LIFECYCLE_RULE_ID" \
  --arg prefix "$s3_prefix" \
  --argjson expiration "$BACKUP_EXPIRATION_DAYS" \
  --argjson noncurrent "$BACKUP_NONCURRENT_EXPIRATION_DAYS" \
  --argjson multipart "$BACKUP_ABORT_MULTIPART_DAYS" '
    (.Rules | type) == "array"
    and (.Rules | length) == 1
    and .Rules[0].ID == $id
    and .Rules[0].Status == "Enabled"
    and (.Rules[0].Prefix == null)
    and ((.Rules[0].Filter | type) == "object")
    and ((.Rules[0].Filter | keys) == ["Prefix"])
    and .Rules[0].Filter.Prefix == $prefix
    and .Rules[0].Expiration.Days == $expiration
    and .Rules[0].Expiration.Date == null
    and .Rules[0].Expiration.ExpiredObjectDeleteMarker == null
    and .Rules[0].NoncurrentVersionExpiration.NoncurrentDays == $noncurrent
    and .Rules[0].NoncurrentVersionExpiration.NewerNoncurrentVersions == null
    and .Rules[0].AbortIncompleteMultipartUpload.DaysAfterInitiation == $multipart
    and ((.Rules[0].Transitions // []) | length) == 0
    and ((.Rules[0].NoncurrentVersionTransitions // []) | length) == 0
  ' <<<"$lifecycle_configuration" >/dev/null \
  || die "S3 lifecycle rule $BACKUP_LIFECYCLE_RULE_ID does not match the backup policy"

kms_description="$(
  "${aws_command[@]}" kms describe-key --key-id "$kms_key_id"
)" || die "Cannot resolve the configured KMS key"
kms_key_arn="$(jq -er '.KeyMetadata.Arn' <<<"$kms_description")" \
  || die "AWS returned no KMS key ARN"
[[ "$kms_key_arn" == "arn:aws:kms:${aws_region}:"* ]] \
  || die "AWS returned a KMS key outside the configured region"
jq -e '
  .KeyMetadata.KeyManager == "CUSTOMER"
  and .KeyMetadata.Enabled == true
  and .KeyMetadata.KeyState == "Enabled"
  and .KeyMetadata.KeyUsage == "ENCRYPT_DECRYPT"
  and .KeyMetadata.KeySpec == "SYMMETRIC_DEFAULT"
' <<<"$kms_description" >/dev/null \
  || die "KMS key must be an enabled customer-managed symmetric encryption key"
kms_rotation="$(
  "${aws_command[@]}" kms get-key-rotation-status --key-id "$kms_key_arn"
)" || die "Cannot verify KMS automatic rotation"
jq -e '
  .KeyRotationEnabled == true
  and has("RotationPeriodInDays")
  and ((.RotationPeriodInDays | type) == "number")
  and (.RotationPeriodInDays >= 90)
  and (.RotationPeriodInDays <= 365)
' <<<"$kms_rotation" >/dev/null \
  || die "KMS automatic rotation must be enabled with an explicit 90-to-365-day period"

if [[ "$ADOPT_LEGACY_MARKERS" != true ]]; then
log "Uploading encrypted archive and checksum to s3://$s3_bucket/$s3_key"
"${aws_command[@]}" s3 cp "$archive_path" "s3://$s3_bucket/$s3_key" \
  --only-show-errors --checksum-algorithm SHA256 \
  --sse aws:kms --sse-kms-key-id "$kms_key_id"
"${aws_command[@]}" s3 cp "$archive_checksum_path" "s3://$s3_bucket/$s3_checksum_key" \
  --only-show-errors --checksum-algorithm SHA256 \
  --sse aws:kms --sse-kms-key-id "$kms_key_id"

archive_head="$("${aws_command[@]}" s3api head-object \
  --bucket "$s3_bucket" --key "$s3_key" --checksum-mode ENABLED)"
checksum_head="$("${aws_command[@]}" s3api head-object \
  --bucket "$s3_bucket" --key "$s3_checksum_key" --checksum-mode ENABLED)"
local_archive_size="$(stat -c '%s' "$archive_path")"
local_checksum_size="$(stat -c '%s' "$archive_checksum_path")"
[[ "$(jq -er '.ContentLength' <<<"$archive_head")" == "$local_archive_size" ]] \
  || die "Remote encrypted archive size does not match"
[[ "$(jq -er '.ContentLength' <<<"$checksum_head")" == "$local_checksum_size" ]] \
  || die "Remote checksum size does not match"
jq -e '.ServerSideEncryption == "aws:kms"' <<<"$archive_head" >/dev/null \
  || die "Remote archive is not protected with SSE-KMS"
jq -e '.ServerSideEncryption == "aws:kms"' <<<"$checksum_head" >/dev/null \
  || die "Remote checksum is not protected with SSE-KMS"
jq -e --arg key "$kms_key_arn" '.SSEKMSKeyId == $key' <<<"$archive_head" >/dev/null \
  || die "Remote archive uses a different KMS key"
jq -e --arg key "$kms_key_arn" '.SSEKMSKeyId == $key' <<<"$checksum_head" >/dev/null \
  || die "Remote checksum uses a different KMS key"
archive_version_id="$(jq -er '.VersionId | select(. != "null" and length > 0)' <<<"$archive_head")" \
  || die "S3 bucket versioning is required for the encrypted archive"
checksum_version_id="$(jq -er '.VersionId | select(. != "null" and length > 0)' <<<"$checksum_head")" \
  || die "S3 bucket versioning is required for the checksum object"
archive_s3_checksum="$(jq -er '.ChecksumSHA256 | select(length > 0)' <<<"$archive_head")" \
  || die "S3 did not persist the encrypted archive SHA-256 checksum"
checksum_s3_checksum="$(jq -er '.ChecksumSHA256 | select(length > 0)' <<<"$checksum_head")" \
  || die "S3 did not persist the checksum-object SHA-256 checksum"
archive_object_lock_mode="$(jq -er '.ObjectLockMode | select(length > 0)' <<<"$archive_head")" \
  || die "S3 did not apply Object Lock to the encrypted archive"
checksum_object_lock_mode="$(jq -er '.ObjectLockMode | select(length > 0)' <<<"$checksum_head")" \
  || die "S3 did not apply Object Lock to the checksum object"
archive_retain_until="$(jq -er '.ObjectLockRetainUntilDate | select(length > 0)' <<<"$archive_head")" \
  || die "S3 did not persist the encrypted archive retention date"
checksum_retain_until="$(jq -er '.ObjectLockRetainUntilDate | select(length > 0)' <<<"$checksum_head")" \
  || die "S3 did not persist the checksum-object retention date"
archive_last_modified="$(jq -er '.LastModified | select(length > 0)' <<<"$archive_head")" \
  || die "S3 did not return the encrypted archive LastModified timestamp"
checksum_last_modified="$(jq -er '.LastModified | select(length > 0)' <<<"$checksum_head")" \
  || die "S3 did not return the checksum-object LastModified timestamp"
archive_retain_until="$(normalize_timestamp "$archive_retain_until")" \
  || die "S3 returned an invalid archive retention date"
checksum_retain_until="$(normalize_timestamp "$checksum_retain_until")" \
  || die "S3 returned an invalid checksum retention date"
archive_last_modified="$(normalize_timestamp "$archive_last_modified")" \
  || die "S3 returned an invalid archive LastModified timestamp"
checksum_last_modified="$(normalize_timestamp "$checksum_last_modified")" \
  || die "S3 returned an invalid checksum LastModified timestamp"
[[ "$archive_object_lock_mode" == "$BACKUP_OBJECT_LOCK_MODE" \
    && "$checksum_object_lock_mode" == "$BACKUP_OBJECT_LOCK_MODE" ]] \
  || die "Uploaded objects are not protected by $BACKUP_OBJECT_LOCK_MODE Object Lock"
retention_matches_policy "$archive_last_modified" "$archive_retain_until" \
  && retention_matches_policy "$checksum_last_modified" "$checksum_retain_until" \
  || die "Uploaded object retention dates do not match the ${BACKUP_OBJECT_LOCK_DAYS}-day policy"

TEMPORARY_MARKER="$(mktemp "${backup_path}/.offsite-upload.tmp.XXXXXX")"
printf '%s\n' \
  "uploaded_at=$(date -u +'%Y-%m-%dT%H:%M:%SZ')" \
  "s3_uri=s3://$s3_bucket/$s3_key" \
  "archive_sha256=$archive_sha256" \
  "manifest_sha256=$manifest_sha256" \
  "backup_sums_sha256=$backup_sums_sha256" \
  "s3_bucket=$s3_bucket" \
  "archive_key=$s3_key" \
  "archive_version_id=$archive_version_id" \
  "archive_size=$local_archive_size" \
  "archive_s3_checksum=$archive_s3_checksum" \
  "checksum_key=$s3_checksum_key" \
  "checksum_version_id=$checksum_version_id" \
  "checksum_size=$local_checksum_size" \
  "checksum_s3_checksum=$checksum_s3_checksum" \
  "kms_key_arn=$kms_key_arn" \
  "backup_policy_id=$BACKUP_POLICY_ID" \
  "age_recipient=$age_recipient" \
  "object_lock_mode=$BACKUP_OBJECT_LOCK_MODE" \
  "archive_last_modified=$archive_last_modified" \
  "archive_retain_until=$archive_retain_until" \
  "checksum_last_modified=$checksum_last_modified" \
  "checksum_retain_until=$checksum_retain_until" >"$TEMPORARY_MARKER"
chmod 600 "$TEMPORARY_MARKER"
mv -f -- "$TEMPORARY_MARKER" "$backup_path/OFFSITE_UPLOAD"
TEMPORARY_MARKER=""

log "Off-site backup verified: s3://$s3_bucket/$s3_key"
fi

marker_targets_adoption() {
  local marker="$1"
  local policy_id marker_age_recipient marker_lock_mode
  local marker_archive_last_modified marker_archive_retain
  local marker_checksum_last_modified marker_checksum_retain

  [[ "$ADOPT_LEGACY_MARKERS" == true ]] || return 1
  if [[ ! -f "$marker" || -L "$marker" \
      || "$(stat -c '%u' "$marker" 2>/dev/null || true)" != "$(id -u)" ]]; then
    return 0
  fi

  policy_id="$(file_value "$marker" backup_policy_id 2>/dev/null || true)"
  [[ "$policy_id" == "$BACKUP_POLICY_ID" ]] || return 0
  marker_age_recipient="$(file_value "$marker" age_recipient 2>/dev/null || true)"
  marker_lock_mode="$(file_value "$marker" object_lock_mode 2>/dev/null || true)"
  marker_archive_last_modified="$(file_value "$marker" archive_last_modified 2>/dev/null || true)"
  marker_archive_retain="$(file_value "$marker" archive_retain_until 2>/dev/null || true)"
  marker_checksum_last_modified="$(file_value "$marker" checksum_last_modified 2>/dev/null || true)"
  marker_checksum_retain="$(file_value "$marker" checksum_retain_until 2>/dev/null || true)"
  [[ "$marker_age_recipient" == age1* \
      && "$marker_age_recipient" != *[[:space:]]* \
      && "$marker_lock_mode" == "$BACKUP_OBJECT_LOCK_MODE" \
      && -n "$marker_archive_last_modified" \
      && -n "$marker_archive_retain" \
      && -n "$marker_checksum_last_modified" \
      && -n "$marker_checksum_retain" ]] || return 0
  return 1
}

remote_marker_is_verified() {
  local marker="$1"
  local candidate="$2"
  local candidate_name candidate_archive candidate_checksum candidate_metadata
  local expected_archive_key expected_checksum_key local_archive_sha256
  local local_manifest_sha256 local_backup_sums_sha256 metadata_archive_sha256
  local metadata_archive_size metadata_manifest_sha256 metadata_backup_sums_sha256
  local metadata_age_recipient candidate_artifact duplicate_metadata_keys
  local marker_bucket marker_archive_key marker_archive_version marker_archive_size
  local marker_archive_checksum marker_archive_sha256 marker_manifest_sha256
  local marker_backup_sums_sha256 marker_checksum_key marker_checksum_version
  local marker_checksum_size marker_checksum_checksum marker_kms remote_archive remote_checksum
  local marker_uploaded_at marker_s3_uri marker_policy_id marker_lock_mode
  local marker_age_recipient
  local marker_archive_last_modified marker_archive_retain
  local marker_checksum_last_modified marker_checksum_retain
  local remote_archive_last_modified remote_archive_retain remote_checksum_last_modified
  local remote_checksum_retain marker_sha_before marker_contract expected_s3_uri
  local marker_mode marker_mode_value

  REMOTE_MARKER_ADOPTION_TARGET=false
  REMOTE_MARKER_ADOPTED=false
  if marker_targets_adoption "$marker"; then
    REMOTE_MARKER_ADOPTION_TARGET=true
  fi

  [[ -f "$marker" && ! -L "$marker" \
      && "$(stat -c '%u' "$marker")" == "$(id -u)" ]] || return 1
  marker_mode="$(stat -c '%a' "$marker")"
  marker_mode_value=$((8#$marker_mode))
  (( (marker_mode_value & 077) == 0 )) || return 1
  marker_sha_before="$(sha256sum "$marker" | awk '{print $1}')"
  candidate_name="$(basename "$candidate")"
  candidate_archive="${candidate}.tar.age"
  candidate_checksum="${candidate_archive}.sha256"
  candidate_metadata="${candidate_archive}.metadata"
  expected_archive_key="${s3_prefix}${candidate_name}.tar.age"
  expected_checksum_key="${expected_archive_key}.sha256"
  for candidate_artifact in \
    "$candidate/MANIFEST" "$candidate/SHA256SUMS" \
    "$candidate_archive" "$candidate_checksum" "$candidate_metadata"; do
    [[ -f "$candidate_artifact" && ! -L "$candidate_artifact" \
        && "$(stat -c '%u' "$candidate_artifact")" == "$(id -u)" ]] || return 1
  done
  (cd "$candidate" && sha256sum --check --strict SHA256SUMS >/dev/null 2>&1) \
    || return 1
  local_archive_sha256="$(sha256sum "$candidate_archive" | awk '{print $1}')"
  local_manifest_sha256="$(sha256sum "$candidate/MANIFEST" | awk '{print $1}')"
  local_backup_sums_sha256="$(sha256sum "$candidate/SHA256SUMS" | awk '{print $1}')"
  [[ "$(awk 'NR == 1 { print } NR > 1 { exit 2 }' "$candidate_checksum" 2>/dev/null)" \
      == "$local_archive_sha256  ${candidate_name}.tar.age" ]] || return 1
  duplicate_metadata_keys="$(awk -F= '
    /^[[:space:]]*[A-Za-z_][A-Za-z0-9_]*[[:space:]]*=/ {
      key=$1
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", key)
      count[key]++
    }
    END { for (key in count) if (count[key] > 1) print key }
  ' "$candidate_metadata")"
  [[ -z "$duplicate_metadata_keys" ]] || return 1
  metadata_archive_sha256="$(file_value "$candidate_metadata" archive_sha256 2>/dev/null || true)"
  metadata_archive_size="$(file_value "$candidate_metadata" archive_size 2>/dev/null || true)"
  metadata_manifest_sha256="$(file_value "$candidate_metadata" manifest_sha256 2>/dev/null || true)"
  metadata_backup_sums_sha256="$(file_value "$candidate_metadata" backup_sums_sha256 2>/dev/null || true)"
  metadata_age_recipient="$(file_value "$candidate_metadata" age_recipient 2>/dev/null || true)"
  [[ "$metadata_archive_sha256" == "$local_archive_sha256" \
      && "$metadata_archive_size" == "$(stat -c '%s' "$candidate_archive")" \
      && "$metadata_manifest_sha256" == "$local_manifest_sha256" \
      && "$metadata_backup_sums_sha256" == "$local_backup_sums_sha256" \
      && "$metadata_age_recipient" == age1* \
      && "$metadata_age_recipient" != *[[:space:]]* ]] || return 1

  marker_bucket="$(file_value "$marker" s3_bucket 2>/dev/null || true)"
  marker_archive_key="$(file_value "$marker" archive_key 2>/dev/null || true)"
  marker_archive_version="$(file_value "$marker" archive_version_id 2>/dev/null || true)"
  marker_archive_size="$(file_value "$marker" archive_size 2>/dev/null || true)"
  marker_archive_checksum="$(file_value "$marker" archive_s3_checksum 2>/dev/null || true)"
  marker_archive_sha256="$(file_value "$marker" archive_sha256 2>/dev/null || true)"
  marker_manifest_sha256="$(file_value "$marker" manifest_sha256 2>/dev/null || true)"
  marker_backup_sums_sha256="$(file_value "$marker" backup_sums_sha256 2>/dev/null || true)"
  marker_checksum_key="$(file_value "$marker" checksum_key 2>/dev/null || true)"
  marker_checksum_version="$(file_value "$marker" checksum_version_id 2>/dev/null || true)"
  marker_checksum_size="$(file_value "$marker" checksum_size 2>/dev/null || true)"
  marker_checksum_checksum="$(file_value "$marker" checksum_s3_checksum 2>/dev/null || true)"
  marker_kms="$(file_value "$marker" kms_key_arn 2>/dev/null || true)"
  marker_uploaded_at="$(file_value "$marker" uploaded_at 2>/dev/null || true)"
  marker_s3_uri="$(file_value "$marker" s3_uri 2>/dev/null || true)"
  marker_policy_id="$(file_value "$marker" backup_policy_id 2>/dev/null || true)"
  marker_age_recipient="$(file_value "$marker" age_recipient 2>/dev/null || true)"
  marker_lock_mode="$(file_value "$marker" object_lock_mode 2>/dev/null || true)"
  marker_archive_last_modified="$(file_value "$marker" archive_last_modified 2>/dev/null || true)"
  marker_archive_retain="$(file_value "$marker" archive_retain_until 2>/dev/null || true)"
  marker_checksum_last_modified="$(file_value "$marker" checksum_last_modified 2>/dev/null || true)"
  marker_checksum_retain="$(file_value "$marker" checksum_retain_until 2>/dev/null || true)"
  expected_s3_uri="s3://${s3_bucket}/${expected_archive_key}"
  [[ "$marker_bucket" == "$s3_bucket" \
      && "$marker_archive_key" == "$expected_archive_key" \
      && "$marker_checksum_key" == "$expected_checksum_key" \
      && "$marker_s3_uri" == "$expected_s3_uri" \
      && "$marker_archive_sha256" == "$local_archive_sha256" \
      && "$marker_manifest_sha256" == "$local_manifest_sha256" \
      && "$marker_backup_sums_sha256" == "$local_backup_sums_sha256" \
      && "$marker_archive_size" == "$(stat -c '%s' "$candidate_archive")" \
      && "$marker_checksum_size" == "$(stat -c '%s' "$candidate_checksum")" \
      && -n "$marker_archive_version" \
      && -n "$marker_checksum_version" \
      && "$marker_archive_size" =~ ^[0-9]+$ \
      && "$marker_checksum_size" =~ ^[0-9]+$ \
      && -n "$marker_archive_checksum" \
      && -n "$marker_checksum_checksum" \
      && "$marker_kms" == "$kms_key_arn" \
      && -n "$marker_uploaded_at" ]] || return 1
  normalize_timestamp "$marker_uploaded_at" >/dev/null || return 1

  marker_contract="legacy"
  if [[ "$marker_policy_id" == "$BACKUP_POLICY_ID" \
      && "$marker_lock_mode" == "$BACKUP_OBJECT_LOCK_MODE" \
      && "$marker_age_recipient" == "$metadata_age_recipient" \
      && -n "$marker_archive_last_modified" \
      && -n "$marker_archive_retain" \
      && -n "$marker_checksum_last_modified" \
      && -n "$marker_checksum_retain" ]]; then
    marker_contract="current"
  elif [[ -n "$marker_policy_id" \
      && "$marker_policy_id" != "REQ-00043-v1.18" \
      && "$marker_policy_id" != "$BACKUP_POLICY_ID" ]]; then
    log "Keeping local backup because its marker has an unsupported policy ID: $candidate_name"
    return 1
  elif [[ "$ADOPT_LEGACY_MARKERS" != true ]]; then
    log "ACTION REQUIRED: legacy backup marker is preserved; review capacity and use --adopt-legacy-markers after approval: $candidate_name"
    return 1
  fi
  if [[ "$marker_contract" == "legacy" \
      && "$ADOPT_LEGACY_MARKERS" == true ]]; then
    REMOTE_MARKER_ADOPTION_TARGET=true
  fi

  remote_archive="$("${aws_command[@]}" s3api head-object \
    --bucket "$marker_bucket" --key "$marker_archive_key" \
    --version-id "$marker_archive_version" --checksum-mode ENABLED 2>/dev/null)" \
    || return 1
  remote_checksum="$("${aws_command[@]}" s3api head-object \
    --bucket "$marker_bucket" --key "$marker_checksum_key" \
    --version-id "$marker_checksum_version" --checksum-mode ENABLED 2>/dev/null)" \
    || return 1
  jq -e --arg version "$marker_archive_version" \
    --arg size "$marker_archive_size" --arg checksum "$marker_archive_checksum" \
    --arg kms "$marker_kms" --arg lock "$BACKUP_OBJECT_LOCK_MODE" '
      .VersionId == $version
      and (.ContentLength | tostring) == $size
      and .ChecksumSHA256 == $checksum
      and .ServerSideEncryption == "aws:kms"
      and .SSEKMSKeyId == $kms
      and .ObjectLockMode == $lock
      and ((.LastModified | type) == "string")
      and ((.ObjectLockRetainUntilDate | type) == "string")
    ' <<<"$remote_archive" >/dev/null || return 1
  jq -e --arg version "$marker_checksum_version" \
    --arg size "$marker_checksum_size" --arg checksum "$marker_checksum_checksum" \
    --arg kms "$marker_kms" --arg lock "$BACKUP_OBJECT_LOCK_MODE" '
      .VersionId == $version
      and (.ContentLength | tostring) == $size
      and .ChecksumSHA256 == $checksum
      and .ServerSideEncryption == "aws:kms"
      and .SSEKMSKeyId == $kms
      and .ObjectLockMode == $lock
      and ((.LastModified | type) == "string")
      and ((.ObjectLockRetainUntilDate | type) == "string")
    ' <<<"$remote_checksum" >/dev/null || return 1

  remote_archive_last_modified="$(jq -er '.LastModified' <<<"$remote_archive")" \
    || return 1
  remote_archive_retain="$(jq -er '.ObjectLockRetainUntilDate' <<<"$remote_archive")" \
    || return 1
  remote_checksum_last_modified="$(jq -er '.LastModified' <<<"$remote_checksum")" \
    || return 1
  remote_checksum_retain="$(jq -er '.ObjectLockRetainUntilDate' <<<"$remote_checksum")" \
    || return 1
  remote_archive_last_modified="$(normalize_timestamp "$remote_archive_last_modified")" \
    || return 1
  remote_archive_retain="$(normalize_timestamp "$remote_archive_retain")" \
    || return 1
  remote_checksum_last_modified="$(normalize_timestamp "$remote_checksum_last_modified")" \
    || return 1
  remote_checksum_retain="$(normalize_timestamp "$remote_checksum_retain")" \
    || return 1
  retention_matches_policy "$remote_archive_last_modified" "$remote_archive_retain" \
    && retention_matches_policy "$remote_checksum_last_modified" "$remote_checksum_retain" \
    || return 1

  if [[ "$marker_contract" == "current" ]]; then
    marker_archive_last_modified="$(normalize_timestamp "$marker_archive_last_modified")" \
      || return 1
    marker_archive_retain="$(normalize_timestamp "$marker_archive_retain")" \
      || return 1
    marker_checksum_last_modified="$(normalize_timestamp "$marker_checksum_last_modified")" \
      || return 1
    marker_checksum_retain="$(normalize_timestamp "$marker_checksum_retain")" \
      || return 1
    [[ "$marker_archive_last_modified" == "$remote_archive_last_modified" \
        && "$marker_archive_retain" == "$remote_archive_retain" \
        && "$marker_checksum_last_modified" == "$remote_checksum_last_modified" \
        && "$marker_checksum_retain" == "$remote_checksum_retain" ]] || return 1
    return 0
  fi

  [[ -z "$marker_lock_mode" || "$marker_lock_mode" == "$BACKUP_OBJECT_LOCK_MODE" ]] \
    || return 1
  [[ -z "$marker_age_recipient" \
      || "$marker_age_recipient" == "$metadata_age_recipient" ]] || return 1
  if [[ -n "$marker_archive_retain" ]]; then
    marker_archive_retain="$(normalize_timestamp "$marker_archive_retain")" || return 1
    [[ "$marker_archive_retain" == "$remote_archive_retain" ]] || return 1
  fi
  if [[ -n "$marker_checksum_retain" ]]; then
    marker_checksum_retain="$(normalize_timestamp "$marker_checksum_retain")" || return 1
    [[ "$marker_checksum_retain" == "$remote_checksum_retain" ]] || return 1
  fi
  [[ -f "$marker" && ! -L "$marker" \
      && "$(stat -c '%u' "$marker")" == "$(id -u)" \
      && "$(sha256sum "$marker" | awk '{print $1}')" == "$marker_sha_before" ]] \
    || return 1

  TEMPORARY_MARKER="$(mktemp "${candidate}/.offsite-upload-adopt.tmp.XXXXXX")"
  printf '%s\n' \
    "uploaded_at=$marker_uploaded_at" \
    "s3_uri=$marker_s3_uri" \
    "archive_sha256=$marker_archive_sha256" \
    "manifest_sha256=$marker_manifest_sha256" \
    "backup_sums_sha256=$marker_backup_sums_sha256" \
    "s3_bucket=$marker_bucket" \
    "archive_key=$marker_archive_key" \
    "archive_version_id=$marker_archive_version" \
    "archive_size=$marker_archive_size" \
    "archive_s3_checksum=$marker_archive_checksum" \
    "checksum_key=$marker_checksum_key" \
    "checksum_version_id=$marker_checksum_version" \
    "checksum_size=$marker_checksum_size" \
    "checksum_s3_checksum=$marker_checksum_checksum" \
    "kms_key_arn=$marker_kms" \
    "backup_policy_id=$BACKUP_POLICY_ID" \
    "age_recipient=$metadata_age_recipient" \
    "object_lock_mode=$BACKUP_OBJECT_LOCK_MODE" \
    "archive_last_modified=$remote_archive_last_modified" \
    "archive_retain_until=$remote_archive_retain" \
    "checksum_last_modified=$remote_checksum_last_modified" \
    "checksum_retain_until=$remote_checksum_retain" >"$TEMPORARY_MARKER"
  chmod 600 "$TEMPORARY_MARKER"
  if [[ ! -f "$marker" || -L "$marker" \
      || "$(sha256sum "$marker" | awk '{print $1}')" != "$marker_sha_before" ]]; then
    rm -f -- "$TEMPORARY_MARKER"
    TEMPORARY_MARKER=""
    return 1
  fi
  mv -f -- "$TEMPORARY_MARKER" "$marker"
  TEMPORARY_MARKER=""
  REMOTE_MARKER_ADOPTED=true
  log "Adopted legacy backup marker after exact remote revalidation: $candidate_name"
  return 0
}

prune_verified_local_backups() {
  local candidate candidate_canonical candidate_name candidate_archive marker_path
  local manifest_project manifest_domain eligible_count=0
  local adoption_targets=0 adoption_adopted=0 adoption_failed=0
  local candidate_adoption_target structural_failure
  local -a candidate_names=() eligible_candidate_names=()

  mapfile -t candidate_names < <(
    find "$backup_root" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' \
      | awk '/^[0-9]{8}T[0-9]{6}Z-pre-deploy(-[0-9]+)?$/' \
      | sort -r
  )

  for candidate_name in "${candidate_names[@]}"; do
    candidate="${backup_root}/${candidate_name}"
    marker_path="${candidate}/OFFSITE_UPLOAD"
    candidate_adoption_target=false
    if [[ "$ADOPT_LEGACY_MARKERS" == true \
        && ( -e "$marker_path" || -L "$marker_path" ) ]] \
        && marker_targets_adoption "$marker_path"; then
      candidate_adoption_target=true
    fi

    structural_failure=""
    if [[ -L "$candidate" || ! -d "$candidate" \
        || ! -f "$candidate/COMPLETED" \
        || -e "$candidate/.INCOMPLETE" \
        || ! -f "$marker_path" \
        || ! -f "$candidate/MANIFEST" ]]; then
      structural_failure="required local files or directory state are unsafe"
    elif [[ "$(stat -c '%u' "$candidate")" != "$(id -u)" ]]; then
      structural_failure="local directory ownership is unsafe"
    elif [[ -n "$(find "$candidate" -mindepth 1 ! -type f -print -quit)" ]]; then
      structural_failure="local generation contains a non-regular entry"
    else
      candidate_canonical="$(realpath --canonicalize-existing -- "$candidate")"
      if [[ "$candidate_canonical" != "$candidate" \
          || "$candidate_canonical" != "$backup_root/"* ]]; then
        structural_failure="local generation path is not canonical"
      else
        manifest_project="$(file_value "$candidate/MANIFEST" compose_project 2>/dev/null || true)"
        manifest_domain="$(file_value "$candidate/MANIFEST" domain 2>/dev/null || true)"
        if [[ "$manifest_project" != "$state_project" \
            || "$manifest_domain" != "$state_domain" ]]; then
          structural_failure="local manifest identifies another installation"
        fi
      fi
    fi
    if [[ -n "$structural_failure" ]]; then
      if [[ "$candidate_adoption_target" == true ]]; then
        adoption_targets=$((adoption_targets + 1))
        adoption_failed=$((adoption_failed + 1))
        log "Legacy marker adoption failed because $structural_failure; preserving the local generation: $candidate_name"
      else
        log "Keeping local backup because $structural_failure: $candidate_name"
      fi
      continue
    fi
    if remote_marker_is_verified "$candidate/OFFSITE_UPLOAD" "$candidate"; then
      if [[ "$ADOPT_LEGACY_MARKERS" == true \
          && "$REMOTE_MARKER_ADOPTION_TARGET" == true ]]; then
        adoption_targets=$((adoption_targets + 1))
        [[ "$REMOTE_MARKER_ADOPTED" == true ]] \
          || die "An adoption target was verified without an atomic marker upgrade"
        adoption_adopted=$((adoption_adopted + 1))
      fi
      eligible_candidate_names+=("$candidate_name")
      continue
    fi
    if [[ "$ADOPT_LEGACY_MARKERS" == true \
        && "$REMOTE_MARKER_ADOPTION_TARGET" == true ]]; then
      adoption_targets=$((adoption_targets + 1))
      adoption_failed=$((adoption_failed + 1))
      log "Legacy marker adoption failed; preserving the local generation: $candidate_name"
    else
      log "Keeping local backup because its exact remote object versions could not be revalidated: $candidate_name"
    fi
  done

  if [[ "$ADOPT_LEGACY_MARKERS" == true ]]; then
    log "Legacy marker adoption summary: candidates=$adoption_targets adopted=$adoption_adopted failed=$adoption_failed"
    (( adoption_failed == 0 )) \
      || die "Legacy marker adoption is incomplete; no local backup was pruned"
  fi

  for candidate_name in "${eligible_candidate_names[@]}"; do
    eligible_count=$((eligible_count + 1))
    (( eligible_count > 10#$local_keep_count )) || continue
    candidate="${backup_root}/${candidate_name}"
    [[ "$candidate" != "$backup_path" ]] || continue
    if ! remote_marker_is_verified "$candidate/OFFSITE_UPLOAD" "$candidate"; then
      log "Keeping local backup because its exact remote object versions could not be revalidated immediately before pruning: $candidate_name"
      continue
    fi

    candidate_archive="${candidate}.tar.age"
    for local_artifact in \
      "$candidate_archive" "${candidate_archive}.sha256" "${candidate_archive}.metadata"; do
      if [[ -e "$local_artifact" ]]; then
        [[ -f "$local_artifact" && ! -L "$local_artifact" \
            && "$(stat -c '%u' "$local_artifact")" == "$(id -u)" ]] \
          || die "Refusing to prune unsafe local artifact: $local_artifact"
      fi
    done

    find "$candidate" -mindepth 1 -maxdepth 1 -type f -delete
    rmdir -- "$candidate"
    rm -f -- "$candidate_archive" "${candidate_archive}.sha256" "${candidate_archive}.metadata"
    log "Pruned verified local backup after retaining the newest $local_keep_count: $candidate_name"
  done
}

prune_verified_local_backups
if [[ "$ADOPT_LEGACY_MARKERS" == true ]]; then
  log "Legacy marker adoption-only scan completed under the deployment lock; no object was uploaded"
fi
