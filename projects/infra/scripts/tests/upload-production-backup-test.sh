#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPOSITORY_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"
UPLOADER="${REPOSITORY_ROOT}/infra/scripts/upload-production-backup.sh"
TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/agentefiscal-backup-test.XXXXXXXX")"

cleanup() {
  rm -rf -- "$TEST_ROOT"
}
trap cleanup EXIT INT TERM

mock_bin="${TEST_ROOT}/bin"
backup_root="${TEST_ROOT}/backups"
fake_s3_root="${TEST_ROOT}/fake-s3"
config_file="${TEST_ROOT}/offsite.env"
state_file="${TEST_ROOT}/last-backup.env"
test_age_recipient='age1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq'
test_old_age_recipient='age1llllllllllllllllllllllllllllllllllllllllllllllllllllllllllllll'
FAKE_OBJECT_LAST_MODIFIED='2026-08-15T00:00:00Z'
FAKE_OBJECT_RETAIN_UNTIL="$(date -u -d "$FAKE_OBJECT_LAST_MODIFIED +35 days" +'%Y-%m-%dT%H:%M:%SZ')"
export FAKE_OBJECT_LAST_MODIFIED FAKE_OBJECT_RETAIN_UNTIL
mkdir -p "$mock_bin" "$backup_root" "$fake_s3_root"
chmod 700 "$backup_root"

cat >"${mock_bin}/age" <<'MOCK_AGE'
#!/usr/bin/env bash
set -Eeuo pipefail
output=""
while (( $# > 0 )); do
  case "$1" in
    --recipient) shift 2 ;;
    --output) output="$2"; shift 2 ;;
    *) exit 64 ;;
  esac
done
[[ -n "$output" ]]
if [[ -n "${FAKE_AGE_COUNTER:-}" ]]; then
  count=0
  [[ ! -f "$FAKE_AGE_COUNTER" ]] || count="$(<"$FAKE_AGE_COUNTER")"
  printf '%s\n' "$((count + 1))" >"$FAKE_AGE_COUNTER"
fi
cat >"$output"
MOCK_AGE

cat >"${mock_bin}/aws" <<'MOCK_AWS'
#!/usr/bin/env bash
set -Eeuo pipefail
: "${FAKE_S3_ROOT:?}"
[[ "${AWS_DEFAULT_OUTPUT:-}" == json ]]
[[ "${AWS_CLI_AUTO_PROMPT:-}" == off ]]
if [[ "$1" == s3 && "$2" == cp ]]; then
  if [[ -n "${FAKE_AWS_UPLOAD_COUNTER:-}" ]]; then
    count=0
    [[ ! -f "$FAKE_AWS_UPLOAD_COUNTER" ]] || count="$(<"$FAKE_AWS_UPLOAD_COUNTER")"
    printf '%s\n' "$((count + 1))" >"$FAKE_AWS_UPLOAD_COUNTER"
  fi
  [[ "${FAKE_AWS_FAIL_UPLOAD:-false}" != true ]] || exit 75
  source_file="$3"
  destination="$4"
  relative="${destination#s3://}"
  [[ "$relative" != "$destination" ]]
  install -d "${FAKE_S3_ROOT}/$(dirname "$relative")"
  install -m 600 "$source_file" "${FAKE_S3_ROOT}/${relative}"
  exit 0
fi
if [[ "$1" == s3api && "$2" == get-bucket-versioning ]]; then
  printf '{"Status":"%s"}\n' "${FAKE_VERSIONING_STATUS-Enabled}"
  exit 0
fi
if [[ "$1" == s3api && "$2" == get-bucket-location ]]; then
  printf '{"LocationConstraint":"%s"}\n' "${FAKE_BUCKET_REGION:-sa-east-1}"
  exit 0
fi
if [[ "$1" == s3api && "$2" == get-public-access-block ]]; then
  printf '{"PublicAccessBlockConfiguration":{"BlockPublicAcls":%s,"IgnorePublicAcls":%s,"BlockPublicPolicy":%s,"RestrictPublicBuckets":%s}}\n' \
    "${FAKE_BLOCK_PUBLIC_ACLS:-true}" "${FAKE_IGNORE_PUBLIC_ACLS:-true}" \
    "${FAKE_BLOCK_PUBLIC_POLICY:-true}" "${FAKE_RESTRICT_PUBLIC_BUCKETS:-true}"
  exit 0
fi
if [[ "$1" == s3api && "$2" == get-object-lock-configuration ]]; then
  if [[ "${FAKE_OBJECT_LOCK_USE_YEARS:-false}" == true ]]; then
    printf '{"ObjectLockConfiguration":{"ObjectLockEnabled":"%s","Rule":{"DefaultRetention":{"Mode":"%s","Years":1}}}}\n' \
      "${FAKE_OBJECT_LOCK_ENABLED:-Enabled}" "${FAKE_OBJECT_LOCK_MODE:-COMPLIANCE}"
  else
    printf '{"ObjectLockConfiguration":{"ObjectLockEnabled":"%s","Rule":{"DefaultRetention":{"Mode":"%s","Days":%s}}}}\n' \
      "${FAKE_OBJECT_LOCK_ENABLED:-Enabled}" \
      "${FAKE_OBJECT_LOCK_MODE:-COMPLIANCE}" \
      "${FAKE_OBJECT_LOCK_DAYS:-35}"
  fi
  exit 0
fi
if [[ "$1" == s3api && "$2" == get-bucket-lifecycle-configuration ]]; then
  transition_json=''
  noncurrent_limit_json=''
  extra_rule_json=''
  expiration_date_json=''
  delete_marker_json=''
  [[ "${FAKE_LIFECYCLE_TRANSITION:-false}" != true ]] \
    || transition_json=',"Transitions":[{"Days":1,"StorageClass":"GLACIER"}]'
  [[ "${FAKE_LIFECYCLE_NEWER_NONCURRENT:-false}" != true ]] \
    || noncurrent_limit_json=',"NewerNoncurrentVersions":1'
  [[ "${FAKE_LIFECYCLE_EXTRA_RULE:-false}" != true ]] \
    || extra_rule_json=',{"ID":"dangerous-extra","Filter":{"Prefix":"production/"},"Status":"Enabled","Expiration":{"Days":1}}'
  [[ "${FAKE_LIFECYCLE_ABSOLUTE_DATE:-false}" != true ]] \
    || expiration_date_json=',"Date":"2026-08-25T00:00:00Z"'
  [[ "${FAKE_LIFECYCLE_DELETE_MARKER:-false}" != true ]] \
    || delete_marker_json=',"ExpiredObjectDeleteMarker":true'
  printf '{"Rules":[{"ID":"%s","Filter":{"Prefix":"%s"},"Status":"%s","Expiration":{"Days":%s%s%s},"NoncurrentVersionExpiration":{"NoncurrentDays":%s%s},"AbortIncompleteMultipartUpload":{"DaysAfterInitiation":%s}%s}%s]}\n' \
    "${FAKE_LIFECYCLE_RULE_ID:-agentefiscal-production-backup-retention-v1}" \
    "${FAKE_LIFECYCLE_PREFIX:-production/}" \
    "${FAKE_LIFECYCLE_STATUS:-Enabled}" \
    "${FAKE_LIFECYCLE_EXPIRATION_DAYS:-45}" \
    "$expiration_date_json" "$delete_marker_json" \
    "${FAKE_LIFECYCLE_NONCURRENT_DAYS:-1}" \
    "$noncurrent_limit_json" \
    "${FAKE_LIFECYCLE_MULTIPART_DAYS:-1}" \
    "$transition_json" "$extra_rule_json"
  exit 0
fi
if [[ "$1" == s3api && "$2" == head-object ]]; then
  shift 2
  bucket=""
  key=""
  requested_version=""
  while (( $# > 0 )); do
    case "$1" in
      --bucket) bucket="$2"; shift 2 ;;
      --key) key="$2"; shift 2 ;;
      --version-id) requested_version="$2"; shift 2 ;;
      *) shift ;;
    esac
  done
  object="${FAKE_S3_ROOT}/${bucket}/${key}"
  [[ -f "$object" ]]
  token="$(printf '%s' "$key" | sha256sum | cut -c1-16)"
  version_id="v-${token}"
  checksum="checksum-${token}"
  [[ -z "$requested_version" || "$requested_version" == "$version_id" ]]
  if [[ "${FAKE_HEAD_INCLUDE_RETENTION:-true}" == true ]]; then
    if [[ "${FAKE_HEAD_INCLUDE_LAST_MODIFIED:-true}" == true ]]; then
      printf '{"ContentLength":%s,"ServerSideEncryption":"aws:kms","SSEKMSKeyId":"arn:aws:kms:sa-east-1:111122223333:key/test","VersionId":"%s","ChecksumSHA256":"%s","ObjectLockMode":"%s","LastModified":"%s","ObjectLockRetainUntilDate":"%s"}\n' \
        "$(stat -c '%s' "$object")" "$version_id" "$checksum" \
        "${FAKE_HEAD_OBJECT_LOCK_MODE:-COMPLIANCE}" \
        "$FAKE_OBJECT_LAST_MODIFIED" "$FAKE_OBJECT_RETAIN_UNTIL"
    else
      printf '{"ContentLength":%s,"ServerSideEncryption":"aws:kms","SSEKMSKeyId":"arn:aws:kms:sa-east-1:111122223333:key/test","VersionId":"%s","ChecksumSHA256":"%s","ObjectLockMode":"%s","ObjectLockRetainUntilDate":"%s"}\n' \
        "$(stat -c '%s' "$object")" "$version_id" "$checksum" \
        "${FAKE_HEAD_OBJECT_LOCK_MODE:-COMPLIANCE}" "$FAKE_OBJECT_RETAIN_UNTIL"
    fi
  else
    printf '{"ContentLength":%s,"ServerSideEncryption":"aws:kms","SSEKMSKeyId":"arn:aws:kms:sa-east-1:111122223333:key/test","VersionId":"%s","ChecksumSHA256":"%s"}\n' \
      "$(stat -c '%s' "$object")" "$version_id" "$checksum"
  fi
  exit 0
fi
if [[ "$1" == kms && "$2" == describe-key ]]; then
  printf '{"KeyMetadata":{"Arn":"arn:aws:kms:sa-east-1:111122223333:key/test","KeyManager":"%s","Enabled":%s,"KeyState":"%s","KeyUsage":"%s","KeySpec":"%s"}}\n' \
    "${FAKE_KMS_KEY_MANAGER:-CUSTOMER}" "${FAKE_KMS_ENABLED:-true}" \
    "${FAKE_KMS_KEY_STATE:-Enabled}" "${FAKE_KMS_KEY_USAGE:-ENCRYPT_DECRYPT}" \
    "${FAKE_KMS_KEY_SPEC:-SYMMETRIC_DEFAULT}"
  exit 0
fi
if [[ "$1" == kms && "$2" == get-key-rotation-status ]]; then
  if [[ "${FAKE_KMS_ROTATION_INCLUDE_PERIOD:-true}" == true ]]; then
    printf '{"KeyRotationEnabled":%s,"RotationPeriodInDays":%s}\n' \
      "${FAKE_KMS_ROTATION_ENABLED:-true}" "${FAKE_KMS_ROTATION_DAYS:-365}"
  else
    printf '{"KeyRotationEnabled":%s}\n' "${FAKE_KMS_ROTATION_ENABLED:-true}"
  fi
  exit 0
fi
exit 64
MOCK_AWS
chmod 755 "${mock_bin}/age" "${mock_bin}/aws"

printf 'project=agentefiscal-prd\ndomain=agentefiscal.com.br\n' \
  >"${backup_root}/.agentefiscal-production-backups"
chmod 600 "${backup_root}/.agentefiscal-production-backups"

object_token() {
  printf '%s' "$1" | sha256sum | cut -c1-16
}

make_backup() {
  local name="$1"
  local uploaded="$2"
  local remote_present="${3:-false}"
  local marker_contract="${4:-current}"
  local generation_age_recipient="${5:-$test_age_recipient}"
  local directory="${backup_root}/${name}"
  local archive="${backup_root}/${name}.tar.age"
  local checksum="${archive}.sha256"
  local metadata="${archive}.metadata"
  local archive_key="production/${name}.tar.age"
  local checksum_key="${archive_key}.sha256"
  local archive_token checksum_token archive_hash manifest_hash sums_hash
  mkdir -m 700 "$directory"
  printf 'compose_project=agentefiscal-prd\ndomain=agentefiscal.com.br\n' \
    >"${directory}/MANIFEST"
  printf 'database payload for %s\n' "$name" >"${directory}/app.dump"
  (
    cd "$directory"
    sha256sum MANIFEST app.dump >SHA256SUMS
  )
  : >"${directory}/COMPLETED"
  if [[ "$uploaded" == true ]]; then
    printf 'encrypted %s\n' "$name" >"$archive"
    archive_hash="$(sha256sum "$archive" | awk '{print $1}')"
    printf '%s  %s\n' "$archive_hash" "${name}.tar.age" >"$checksum"
    manifest_hash="$(sha256sum "${directory}/MANIFEST" | awk '{print $1}')"
    sums_hash="$(sha256sum "${directory}/SHA256SUMS" | awk '{print $1}')"
    printf 'archive_sha256=%s\narchive_size=%s\nmanifest_sha256=%s\nbackup_sums_sha256=%s\nage_recipient=%s\n' \
      "$archive_hash" "$(stat -c '%s' "$archive")" "$manifest_hash" \
      "$sums_hash" "$generation_age_recipient" >"$metadata"
    chmod 600 "$archive" "$checksum" "$metadata"
    archive_token="$(object_token "$archive_key")"
    checksum_token="$(object_token "$checksum_key")"
    printf '%s\n' \
      'uploaded_at=2026-08-15T00:00:00Z' \
      "s3_uri=s3://test-bucket/${archive_key}" \
      "archive_sha256=$archive_hash" \
      "manifest_sha256=$manifest_hash" \
      "backup_sums_sha256=$sums_hash" \
      's3_bucket=test-bucket' \
      "archive_key=$archive_key" \
      "archive_version_id=v-${archive_token}" \
      "archive_size=$(stat -c '%s' "$archive")" \
      "archive_s3_checksum=checksum-${archive_token}" \
      "checksum_key=$checksum_key" \
      "checksum_version_id=v-${checksum_token}" \
      "checksum_size=$(stat -c '%s' "$checksum")" \
      "checksum_s3_checksum=checksum-${checksum_token}" \
      'kms_key_arn=arn:aws:kms:sa-east-1:111122223333:key/test' \
      >"${directory}/OFFSITE_UPLOAD"
    if [[ "$marker_contract" == current ]]; then
      printf '%s\n' \
        'backup_policy_id=conversation-audit-backup-v1' \
        "age_recipient=$generation_age_recipient" \
        'object_lock_mode=COMPLIANCE' \
        "archive_last_modified=$FAKE_OBJECT_LAST_MODIFIED" \
        "archive_retain_until=$FAKE_OBJECT_RETAIN_UNTIL" \
        "checksum_last_modified=$FAKE_OBJECT_LAST_MODIFIED" \
        "checksum_retain_until=$FAKE_OBJECT_RETAIN_UNTIL" \
        >>"${directory}/OFFSITE_UPLOAD"
    elif [[ "$marker_contract" == prerelease ]]; then
      printf '%s\n' \
        'backup_policy_id=REQ-00043-v1.18' \
        'object_lock_mode=COMPLIANCE' \
        "archive_retain_until=$FAKE_OBJECT_RETAIN_UNTIL" \
        "checksum_retain_until=$FAKE_OBJECT_RETAIN_UNTIL" \
        >>"${directory}/OFFSITE_UPLOAD"
    elif [[ "$marker_contract" != legacy ]]; then
      printf 'unknown marker contract: %s\n' "$marker_contract" >&2
      exit 64
    fi
    chmod 600 "${directory}/OFFSITE_UPLOAD"
    if [[ "$remote_present" == true ]]; then
      install -d "${fake_s3_root}/test-bucket/production"
      install -m 600 "$archive" "${fake_s3_root}/test-bucket/${archive_key}"
      install -m 600 "$checksum" "${fake_s3_root}/test-bucket/${checksum_key}"
    fi
  fi
}

extra_oldest='20260806T030000Z-pre-deploy'
extra_two='20260807T030000Z-pre-deploy'
extra_three='20260808T030000Z-pre-deploy'
extra_four='20260809T030000Z-pre-deploy'
extra_five='20260810T030000Z-pre-deploy'
swapped='20260811T030000Z-pre-deploy'
orphan='20260812T030000Z-pre-deploy'
oldest='20260813T030000Z-pre-deploy'
previous='20260814T030000Z-pre-deploy'
legacy_failure='20260814T020000Z-pre-deploy'
legacy_local_failure='20260814T015000Z-pre-deploy'
legacy='20260814T010000Z-pre-deploy'
current='20260815T030000Z-pre-deploy'
make_backup "$extra_oldest" true true current "$test_old_age_recipient"
make_backup "$extra_two" true true
make_backup "$extra_three" true true
make_backup "$extra_four" true true
make_backup "$extra_five" true true
make_backup "$swapped" true true
make_backup "$orphan" true false
make_backup "$oldest" true true
make_backup "$previous" true true
make_backup "$legacy_failure" true false legacy
make_backup "$legacy_local_failure" true true legacy
mkdir -m 700 "${backup_root}/${legacy_local_failure}/unexpected-subdirectory"
make_backup "$legacy" true true legacy
make_backup "$current" false
# A valid marker copied from a different backup must never authorize pruning.
cp "${backup_root}/${previous}/OFFSITE_UPLOAD" \
  "${backup_root}/${swapped}/OFFSITE_UPLOAD"
chmod 600 "${backup_root}/${swapped}/OFFSITE_UPLOAD"

cat >"$config_file" <<'CONFIG'
BACKUP_AGE_RECIPIENT=age1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq
BACKUP_S3_URI=s3://test-bucket/production
BACKUP_KMS_KEY_ID=arn:aws:kms:sa-east-1:111122223333:key/test
AWS_REGION=sa-east-1
BACKUP_LOCAL_KEEP_COUNT=7
CONFIG
printf 'backup_path=%s\ncompleted_at=2026-08-15T03:00:00Z\nproject=agentefiscal-prd\ndomain=agentefiscal.com.br\nmin_free_mb=512\n' \
  "${backup_root}/${current}" >"$state_file"
chmod 600 "$config_file" "$state_file"

deploy_lock_file="${TEST_ROOT}/deploy.lock"
: >"$deploy_lock_file"
chmod 600 "$deploy_lock_file"
exec 9>"$deploy_lock_file"
flock -n 9

age_counter="${TEST_ROOT}/age-counter"
upload_counter="${TEST_ROOT}/upload-counter"
failure_output="${TEST_ROOT}/expected-failure.log"

expect_policy_failure() {
  local expected="$1"
  shift
  if env "PATH=${mock_bin}:$PATH" "FAKE_S3_ROOT=$fake_s3_root" \
      "FAKE_AGE_COUNTER=$age_counter" "FAKE_AWS_UPLOAD_COUNTER=$upload_counter" "$@" \
      "$UPLOADER" --config "$config_file" --state-file "$state_file" \
      --deploy-lock-fd 9 \
      >"$failure_output" 2>&1; then
    printf 'expected backup policy validation to fail: %s\n' "$expected" >&2
    exit 1
  fi
  grep -F "$expected" "$failure_output" >/dev/null
}

if env "PATH=${mock_bin}:$PATH" "FAKE_S3_ROOT=$fake_s3_root" \
    "$UPLOADER" --config "$config_file" --state-file "$state_file" \
    >"$failure_output" 2>&1; then
  printf 'expected missing deployment-lock descriptor to fail\n' >&2
  exit 1
fi
grep -F -- '--deploy-lock-fd must identify an inherited descriptor' \
  "$failure_output" >/dev/null

exec 8>>"$deploy_lock_file"
if env "PATH=${mock_bin}:$PATH" "FAKE_S3_ROOT=$fake_s3_root" \
    "$UPLOADER" --config "$config_file" --state-file "$state_file" \
    --deploy-lock-fd 8 >"$failure_output" 2>&1; then
  printf 'expected contended deployment-lock descriptor to fail\n' >&2
  exit 1
fi
grep -F 'Cannot acquire or confirm the production deployment/backup lock' \
  "$failure_output" >/dev/null
test ! -e "$upload_counter"
grep -Fx "age_recipient=$test_old_age_recipient" \
  "${backup_root}/${extra_oldest}/OFFSITE_UPLOAD" >/dev/null

bad_region_config="${TEST_ROOT}/offsite-wrong-region.env"
cp "$config_file" "$bad_region_config"
sed -i 's/AWS_REGION=sa-east-1/AWS_REGION=us-east-1/' "$bad_region_config"
chmod 600 "$bad_region_config"
if env "PATH=${mock_bin}:$PATH" "FAKE_S3_ROOT=$fake_s3_root" \
    "FAKE_AGE_COUNTER=$age_counter" "FAKE_AWS_UPLOAD_COUNTER=$upload_counter" \
    "$UPLOADER" --config "$bad_region_config" --state-file "$state_file" \
    --deploy-lock-fd 9 \
    >"$failure_output" 2>&1; then
  printf 'expected configured AWS region validation to fail\n' >&2
  exit 1
fi
grep -F 'AWS_REGION must be exactly sa-east-1' "$failure_output" >/dev/null

expect_policy_failure 'S3 bucket versioning must be Enabled' \
  FAKE_VERSIONING_STATUS=Suspended
expect_policy_failure 'S3 bucket versioning must be Enabled' \
  FAKE_VERSIONING_STATUS=
expect_policy_failure 'S3 bucket must be located in sa-east-1' \
  FAKE_BUCKET_REGION=us-east-1
expect_policy_failure 'S3 Block Public Access must enable all four controls' \
  FAKE_BLOCK_PUBLIC_ACLS=false
expect_policy_failure 'S3 Block Public Access must enable all four controls' \
  FAKE_IGNORE_PUBLIC_ACLS=false
expect_policy_failure 'S3 Block Public Access must enable all four controls' \
  FAKE_BLOCK_PUBLIC_POLICY=false
expect_policy_failure 'S3 Block Public Access must enable all four controls' \
  FAKE_RESTRICT_PUBLIC_BUCKETS=false
expect_policy_failure 'S3 Object Lock must default to COMPLIANCE/35d' \
  FAKE_OBJECT_LOCK_ENABLED=Disabled
expect_policy_failure 'S3 Object Lock must default to COMPLIANCE/35d' \
  FAKE_OBJECT_LOCK_MODE=GOVERNANCE
expect_policy_failure 'S3 Object Lock must default to COMPLIANCE/35d' \
  FAKE_OBJECT_LOCK_DAYS=34
expect_policy_failure 'S3 Object Lock must default to COMPLIANCE/35d' \
  FAKE_OBJECT_LOCK_DAYS=36
expect_policy_failure 'S3 Object Lock must default to COMPLIANCE/35d' \
  FAKE_OBJECT_LOCK_USE_YEARS=true
expect_policy_failure 'does not match the backup policy' \
  FAKE_LIFECYCLE_RULE_ID=unexpected-rule
expect_policy_failure 'does not match the backup policy' \
  FAKE_LIFECYCLE_STATUS=Disabled
expect_policy_failure 'does not match the backup policy' \
  FAKE_LIFECYCLE_PREFIX=production-too-broad/
expect_policy_failure 'does not match the backup policy' \
  FAKE_LIFECYCLE_EXPIRATION_DAYS=44
expect_policy_failure 'does not match the backup policy' \
  FAKE_LIFECYCLE_NONCURRENT_DAYS=2
expect_policy_failure 'does not match the backup policy' \
  FAKE_LIFECYCLE_MULTIPART_DAYS=2
expect_policy_failure 'does not match the backup policy' \
  FAKE_LIFECYCLE_EXTRA_RULE=true
expect_policy_failure 'does not match the backup policy' \
  FAKE_LIFECYCLE_TRANSITION=true
expect_policy_failure 'does not match the backup policy' \
  FAKE_LIFECYCLE_NEWER_NONCURRENT=true
expect_policy_failure 'does not match the backup policy' \
  FAKE_LIFECYCLE_ABSOLUTE_DATE=true
expect_policy_failure 'does not match the backup policy' \
  FAKE_LIFECYCLE_DELETE_MARKER=true
expect_policy_failure 'KMS key must be an enabled customer-managed symmetric encryption key' \
  FAKE_KMS_KEY_MANAGER=AWS
expect_policy_failure 'KMS key must be an enabled customer-managed symmetric encryption key' \
  FAKE_KMS_ENABLED=false
expect_policy_failure 'KMS key must be an enabled customer-managed symmetric encryption key' \
  FAKE_KMS_KEY_STATE=Disabled
expect_policy_failure 'KMS key must be an enabled customer-managed symmetric encryption key' \
  FAKE_KMS_KEY_USAGE=SIGN_VERIFY
expect_policy_failure 'KMS key must be an enabled customer-managed symmetric encryption key' \
  FAKE_KMS_KEY_SPEC=RSA_2048
expect_policy_failure 'KMS automatic rotation must be enabled' \
  FAKE_KMS_ROTATION_ENABLED=false
expect_policy_failure 'KMS automatic rotation must be enabled' \
  FAKE_KMS_ROTATION_INCLUDE_PERIOD=false
expect_policy_failure 'KMS automatic rotation must be enabled' \
  FAKE_KMS_ROTATION_DAYS=89
expect_policy_failure 'KMS automatic rotation must be enabled' \
  FAKE_KMS_ROTATION_DAYS=366
test ! -e "$upload_counter"

expect_policy_failure 'S3 did not apply Object Lock to the encrypted archive' \
  FAKE_HEAD_INCLUDE_RETENTION=false
expect_policy_failure 'Uploaded objects are not protected by COMPLIANCE Object Lock' \
  FAKE_HEAD_OBJECT_LOCK_MODE=GOVERNANCE
expect_policy_failure 'S3 did not return the encrypted archive LastModified timestamp' \
  FAKE_HEAD_INCLUDE_LAST_MODIFIED=false
expect_policy_failure 'Uploaded object retention dates do not match the 35-day policy' \
  FAKE_OBJECT_RETAIN_UNTIL=2026-08-24T00:00:00Z
expect_policy_failure 'Uploaded object retention dates do not match the 35-day policy' \
  FAKE_OBJECT_RETAIN_UNTIL=2026-09-20T00:00:00Z
test ! -e "${backup_root}/${current}/OFFSITE_UPLOAD"
test -s "$upload_counter"
test -d "${backup_root}/${extra_oldest}"

happy_output="${TEST_ROOT}/happy-path.log"
PATH="${mock_bin}:$PATH" FAKE_S3_ROOT="$fake_s3_root" FAKE_AGE_COUNTER="$age_counter" \
  FAKE_AWS_UPLOAD_COUNTER="$upload_counter" \
  FAKE_OBJECT_LAST_MODIFIED=2026-08-15T00:00:00+00:00 \
  FAKE_OBJECT_RETAIN_UNTIL=2026-09-19T00:00:00+00:00 \
  "$UPLOADER" --config "$config_file" --state-file "$state_file" \
  --deploy-lock-fd 9 \
  >"$happy_output"

test -f "${backup_root}/${current}/OFFSITE_UPLOAD"
grep -Fx 'backup_policy_id=conversation-audit-backup-v1' \
  "${backup_root}/${current}/OFFSITE_UPLOAD" >/dev/null
grep -Fx 'object_lock_mode=COMPLIANCE' \
  "${backup_root}/${current}/OFFSITE_UPLOAD" >/dev/null
grep -Fx "age_recipient=$test_age_recipient" \
  "${backup_root}/${current}/OFFSITE_UPLOAD" >/dev/null
grep -Fx 'archive_last_modified=2026-08-15T00:00:00Z' \
  "${backup_root}/${current}/OFFSITE_UPLOAD" >/dev/null
grep -F 'ACTION REQUIRED: legacy backup marker is preserved' "$happy_output" >/dev/null
! grep -F 'backup_policy_id=' "${backup_root}/${legacy}/OFFSITE_UPLOAD" >/dev/null
test -f "${fake_s3_root}/test-bucket/production/${current}.tar.age"
test -f "${fake_s3_root}/test-bucket/production/${current}.tar.age.sha256"
test -d "${backup_root}/${previous}"
test -d "${backup_root}/${oldest}"
test ! -e "${backup_root}/${extra_oldest}"
test ! -e "${backup_root}/${extra_oldest}.tar.age"
test ! -e "${backup_root}/${extra_oldest}.tar.age.sha256"
test ! -e "${backup_root}/${extra_oldest}.tar.age.metadata"
test -d "${backup_root}/${orphan}"
test -d "${backup_root}/${swapped}"

adoption_output="${TEST_ROOT}/legacy-adoption.log"
uploads_before_adoption="$(<"$upload_counter")"
age_before_adoption="$(<"$age_counter")"
current_marker_before_adoption="$(sha256sum "${backup_root}/${current}/OFFSITE_UPLOAD" | awk '{print $1}')"
failed_legacy_marker_before="$(sha256sum "${backup_root}/${legacy_failure}/OFFSITE_UPLOAD" | awk '{print $1}')"
local_failed_legacy_marker_before="$(sha256sum "${backup_root}/${legacy_local_failure}/OFFSITE_UPLOAD" | awk '{print $1}')"
if PATH="${mock_bin}:$PATH" FAKE_S3_ROOT="$fake_s3_root" \
    FAKE_AGE_COUNTER="$age_counter" FAKE_AWS_UPLOAD_COUNTER="$upload_counter" \
    "$UPLOADER" --config "$config_file" --state-file "$state_file" \
    --deploy-lock-fd 9 --adopt-legacy-markers >"$adoption_output" 2>&1; then
  printf 'expected mixed legacy-marker adoption to fail closed\n' >&2
  exit 1
fi
grep -F 'Adopted legacy backup marker after exact remote revalidation' \
  "$adoption_output" >/dev/null
grep -F 'Legacy marker adoption summary: candidates=3 adopted=1 failed=2' \
  "$adoption_output" >/dev/null
grep -F 'Legacy marker adoption failed because local generation contains a non-regular entry' \
  "$adoption_output" >/dev/null
grep -F 'Legacy marker adoption is incomplete; no local backup was pruned' \
  "$adoption_output" >/dev/null
grep -Fx 'backup_policy_id=conversation-audit-backup-v1' \
  "${backup_root}/${legacy}/OFFSITE_UPLOAD" >/dev/null
grep -Fx "age_recipient=$test_age_recipient" \
  "${backup_root}/${legacy}/OFFSITE_UPLOAD" >/dev/null
grep -Fx "archive_last_modified=$FAKE_OBJECT_LAST_MODIFIED" \
  "${backup_root}/${legacy}/OFFSITE_UPLOAD" >/dev/null
test "$(<"$upload_counter")" == "$uploads_before_adoption"
test "$(<"$age_counter")" == "$age_before_adoption"
test "$(sha256sum "${backup_root}/${current}/OFFSITE_UPLOAD" | awk '{print $1}')" \
  == "$current_marker_before_adoption"
test "$(sha256sum "${backup_root}/${legacy_failure}/OFFSITE_UPLOAD" | awk '{print $1}')" \
  == "$failed_legacy_marker_before"
test "$(sha256sum "${backup_root}/${legacy_local_failure}/OFFSITE_UPLOAD" | awk '{print $1}')" \
  == "$local_failed_legacy_marker_before"
test -d "${backup_root}/${extra_two}"

rmdir "${backup_root}/${legacy_local_failure}/unexpected-subdirectory"
install -m 600 "${backup_root}/${legacy_failure}.tar.age" \
  "${fake_s3_root}/test-bucket/production/${legacy_failure}.tar.age"
install -m 600 "${backup_root}/${legacy_failure}.tar.age.sha256" \
  "${fake_s3_root}/test-bucket/production/${legacy_failure}.tar.age.sha256"
adoption_retry_output="${TEST_ROOT}/legacy-adoption-retry.log"
PATH="${mock_bin}:$PATH" FAKE_S3_ROOT="$fake_s3_root" FAKE_AGE_COUNTER="$age_counter" \
  FAKE_AWS_UPLOAD_COUNTER="$upload_counter" \
  "$UPLOADER" --config "$config_file" --state-file "$state_file" \
  --deploy-lock-fd 9 --adopt-legacy-markers >"$adoption_retry_output"
grep -F 'Legacy marker adoption summary: candidates=2 adopted=2 failed=0' \
  "$adoption_retry_output" >/dev/null
grep -F 'no object was uploaded' "$adoption_retry_output" >/dev/null
grep -Fx 'backup_policy_id=conversation-audit-backup-v1' \
  "${backup_root}/${legacy_failure}/OFFSITE_UPLOAD" >/dev/null
grep -Fx 'backup_policy_id=conversation-audit-backup-v1' \
  "${backup_root}/${legacy_local_failure}/OFFSITE_UPLOAD" >/dev/null
test "$(<"$upload_counter")" == "$uploads_before_adoption"
test "$(<"$age_counter")" == "$age_before_adoption"

retry='20260816T030000Z-pre-deploy'
make_backup "$retry" false
printf 'backup_path=%s\ncompleted_at=2026-08-16T03:00:00Z\nproject=agentefiscal-prd\ndomain=agentefiscal.com.br\nmin_free_mb=512\n' \
  "${backup_root}/${retry}" >"$state_file"
chmod 600 "$state_file"
if PATH="${mock_bin}:$PATH" FAKE_S3_ROOT="$fake_s3_root" \
    FAKE_AGE_COUNTER="$age_counter" FAKE_AWS_FAIL_UPLOAD=true \
    "$UPLOADER" --config "$config_file" --state-file "$state_file" \
    --deploy-lock-fd 9; then
  printf 'expected the simulated S3 outage to fail\n' >&2
  exit 1
fi
test -f "${backup_root}/${retry}.tar.age"
test -f "${backup_root}/${retry}.tar.age.sha256"
test -f "${backup_root}/${retry}.tar.age.metadata"
test ! -e "${backup_root}/${retry}/OFFSITE_UPLOAD"
test "$(<"$age_counter")" == 2

PATH="${mock_bin}:$PATH" FAKE_S3_ROOT="$fake_s3_root" FAKE_AGE_COUNTER="$age_counter" \
  "$UPLOADER" --config "$config_file" --state-file "$state_file" \
  --deploy-lock-fd 9
test -f "${backup_root}/${retry}/OFFSITE_UPLOAD"
test "$(<"$age_counter")" == 2

# SIGKILL/power loss between the three final renames must self-heal instead of
# blocking all future off-site retries.
partial_one='20260817T030000Z-pre-deploy'
make_backup "$partial_one" false
printf 'interrupted archive\n' >"${backup_root}/${partial_one}.tar.age"
chmod 600 "${backup_root}/${partial_one}.tar.age"
printf 'backup_path=%s\ncompleted_at=2026-08-17T03:00:00Z\nproject=agentefiscal-prd\ndomain=agentefiscal.com.br\nmin_free_mb=512\n' \
  "${backup_root}/${partial_one}" >"$state_file"
chmod 600 "$state_file"
PATH="${mock_bin}:$PATH" FAKE_S3_ROOT="$fake_s3_root" FAKE_AGE_COUNTER="$age_counter" \
  "$UPLOADER" --config "$config_file" --state-file "$state_file" \
  --deploy-lock-fd 9
test -f "${backup_root}/${partial_one}/OFFSITE_UPLOAD"
test "$(<"$age_counter")" == 3

partial_two='20260818T030000Z-pre-deploy'
make_backup "$partial_two" false
printf 'interrupted archive\n' >"${backup_root}/${partial_two}.tar.age"
printf 'invalid interrupted checksum\n' >"${backup_root}/${partial_two}.tar.age.sha256"
chmod 600 "${backup_root}/${partial_two}.tar.age" \
  "${backup_root}/${partial_two}.tar.age.sha256"
printf 'backup_path=%s\ncompleted_at=2026-08-18T03:00:00Z\nproject=agentefiscal-prd\ndomain=agentefiscal.com.br\nmin_free_mb=512\n' \
  "${backup_root}/${partial_two}" >"$state_file"
chmod 600 "$state_file"
PATH="${mock_bin}:$PATH" FAKE_S3_ROOT="$fake_s3_root" FAKE_AGE_COUNTER="$age_counter" \
  "$UPLOADER" --config "$config_file" --state-file "$state_file" \
  --deploy-lock-fd 9
test -f "${backup_root}/${partial_two}/OFFSITE_UPLOAD"
test "$(<"$age_counter")" == 4

deploy_script="${REPOSITORY_ROOT}/infra/scripts/deploy-production.sh"
wrapper_capture="${TEST_ROOT}/wrapper-uploader"
wrapper_arguments="${TEST_ROOT}/wrapper-arguments"
cat >"$wrapper_capture" <<'WRAPPER_CAPTURE'
#!/usr/bin/env bash
set -Eeuo pipefail
: "${WRAPPER_ARGUMENTS_FILE:?}"
printf '%s\n' "$@" >"$WRAPPER_ARGUMENTS_FILE"
exit "${WRAPPER_EXIT_CODE:-0}"
WRAPPER_CAPTURE
chmod 755 "$wrapper_capture"
(
  source "$deploy_script"
  parse_arguments backup --upload-offsite --adopt-legacy-markers
  [[ "$UPLOAD_OFFSITE" == true && "$ADOPT_LEGACY_BACKUP_MARKERS" == true ]]
  OFFSITE_BACKUP_SCRIPT="$wrapper_capture"
  OFFSITE_BACKUP_CONFIG="$config_file"
  LAST_BACKUP_STATE_FILE="$state_file"
  export WRAPPER_ARGUMENTS_FILE="$wrapper_arguments"
  upload_last_backup_offsite
)
grep -Fx -- '--deploy-lock-fd' "$wrapper_arguments" >/dev/null
grep -Fx '9' "$wrapper_arguments" >/dev/null
grep -Fx -- '--adopt-legacy-markers' "$wrapper_arguments" >/dev/null
if (
  source "$deploy_script"
  parse_arguments backup --upload-offsite --adopt-legacy-markers
  OFFSITE_BACKUP_SCRIPT="$wrapper_capture"
  OFFSITE_BACKUP_CONFIG="$config_file"
  LAST_BACKUP_STATE_FILE="$state_file"
  export WRAPPER_ARGUMENTS_FILE="$wrapper_arguments" WRAPPER_EXIT_CODE=23
  upload_last_backup_offsite
) >"$failure_output" 2>&1; then
  printf 'expected the deploy wrapper to propagate uploader failure\n' >&2
  exit 1
fi
if (
  source "$deploy_script"
  parse_arguments backup --adopt-legacy-markers
) >"$failure_output" 2>&1; then
  printf 'expected wrapper adoption without --upload-offsite to fail\n' >&2
  exit 1
fi
grep -F -- '--adopt-legacy-markers requires backup --upload-offsite' \
  "$failure_output" >/dev/null

timer_file="${REPOSITORY_ROOT}/infra/systemd/agentefiscal-production-backup.timer"
example_config="${REPOSITORY_ROOT}/infra/deploy/offsite-backup.env.example"
grep -Fx 'OnCalendar=*-*-* 03,15:15:00 UTC' "$timer_file" >/dev/null
grep -Fx 'RandomizedDelaySec=15m' "$timer_file" >/dev/null
grep -Fx 'Persistent=true' "$timer_file" >/dev/null
grep -Fx 'BACKUP_LOCAL_KEEP_COUNT=7' "$example_config" >/dev/null

printf 'upload-production-backup-test: PASS\n'
