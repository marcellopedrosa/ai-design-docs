run_init() {
  local existing_app_volume release_id
  validate_worktree
  validate_dns
  validate_tls
  validate_alert_webhook
  docker_preflight
  validate_telegram_egress_preflight
  assert_fresh_or_resumable_init
  if [[ -f "$FINGERPRINT_FILE" ]]; then
    verify_immutable_fingerprints
  else
    write_immutable_fingerprints
  fi
  if [[ -f "$MIGRATION_MANIFEST_FILE" ]]; then
    validate_migration_immutability
  else
    save_migration_manifest
  fi
  if [[ -f "$KEYCLOAK_BOOTSTRAP_MANIFEST_FILE" ]]; then
    verify_keycloak_bootstrap_manifest
  else
    save_keycloak_bootstrap_manifest
  fi
  DEPLOY_STARTED_AT="$(date -u +'%Y-%m-%dT%H:%M:%SZ')"
  release_id="$(date -u +'%Y%m%dT%H%M%SZ')"

  existing_app_volume="$(labeled_volume postgres-app-data)"
  if [[ -n "$existing_app_volume" ]]; then
    validate_offsite_backup_prerequisites
    retry_pending_offsite_backup
  fi
  prepare_release_images
  if [[ -n "$existing_app_volume" ]]; then
    "${COMPOSE[@]}" up -d --no-build --no-recreate postgres-app postgres-keycloak
    wait_for_service postgres-app
    wait_for_service postgres-keycloak
    stop_writers
    create_backup true
    upload_last_backup_offsite
  fi

  if [[ -n "$existing_app_volume" ]]; then
    deploy_stack true
  else
    deploy_stack false
  fi
  validate_live_state
  if [[ -n "$existing_app_volume" ]]; then
    validate_preserved_catalog "$LAST_BACKUP_DIR"
  fi
  write_installation_state
  record_release_state after "$release_id"
  print_no_super_admin_warning
  log "Initial production deployment completed successfully."
}

run_update() {
  local release_id
  verify_immutable_fingerprints
  validate_migration_immutability
  verify_keycloak_bootstrap_manifest
  validate_worktree
  validate_dns
  validate_tls
  validate_alert_webhook
  docker_preflight
  validate_telegram_egress_preflight
  verify_installation_state
  validate_offsite_backup_prerequisites
  retry_pending_offsite_backup
  wait_for_service postgres-keycloak
  wait_for_service keycloak
  validate_keycloak_catalog
  DEPLOY_STARTED_AT="$(date -u +'%Y-%m-%dT%H:%M:%SZ')"
  release_id="$(date -u +'%Y%m%dT%H%M%SZ')"
  record_release_state before "$release_id"

  prepare_release_images
  stop_writers
  create_backup false
  upload_last_backup_offsite
  deploy_stack true
  validate_live_state
  validate_preserved_catalog "$LAST_BACKUP_DIR"
  save_migration_manifest
  record_release_state after "$release_id"
  log "Incremental production update completed; databases, tenant rows and realms were preserved."
  log "Pre-update backup: $LAST_BACKUP_DIR"
}

run_backup() {
  local pending_path
  verify_immutable_fingerprints
  validate_alert_webhook
  if [[ "$ADOPT_LEGACY_BACKUP_MARKERS" == true ]]; then
    validate_offsite_backup_prerequisites
    upload_last_backup_offsite
    log "Legacy off-site markers were scanned under the deployment lock; no backup or upload was created"
    return 0
  fi
  docker_preflight
  verify_installation_state
  wait_for_service postgres-app
  wait_for_service postgres-keycloak
  if [[ "$UPLOAD_OFFSITE" == true ]]; then
    validate_offsite_backup_prerequisites
    pending_path="$(pending_offsite_backup_path)"
    if [[ -n "$pending_path" ]]; then
      log "Retrying the pending off-site upload instead of consuming space for another snapshot: $pending_path"
      upload_last_backup_offsite
      log "Pending backup is now protected off-site: $pending_path"
      return 0
    fi
  fi
  stop_writers
  create_backup false
  restart_original_writers
  if [[ "$UPLOAD_OFFSITE" == true ]]; then
    upload_last_backup_offsite
  fi
  log "Consistent backup completed: $LAST_BACKUP_DIR"
}

run_status() {
  verify_immutable_fingerprints
  validate_migration_immutability
  verify_keycloak_bootstrap_manifest
  validate_dns
  validate_tls
  validate_alert_webhook
  docker_preflight
  validate_telegram_egress_preflight
  verify_installation_state
  DEPLOY_STARTED_AT="1h"
  "${COMPOSE[@]}" ps
  validate_live_state
  log "Production status is healthy; volumes, realms and Flyway histories match the deployment contract."
}

cleanup_on_exit() {
  local status=$?
  trap - EXIT INT TERM
  if (( status != 0 )) \
      && [[ "$ROLLOUT_STARTED" == true \
          && "$OUTBOUND_KEYRING_ACTIVATED" == false ]]; then
    warn "Outbound HMAC keyring was installed but not activated by a healthy backend; stopping stale application traffic."
    "${COMPOSE[@]}" stop --timeout 60 proxy >/dev/null 2>&1 \
      || warn "Failed to stop the production proxy after outbound HMAC activation failure"
    "${COMPOSE[@]}" stop --timeout 60 backend >/dev/null 2>&1 \
      || warn "Failed to stop the stale backend after outbound HMAC activation failure"
  fi
  if (( status != 0 )) && [[ "$WRITERS_STOPPED" == true && "$ROLLOUT_STARTED" == false ]]; then
    restart_original_writers || true
  fi
  if (( status != 0 )) && [[ "$ROLLOUT_STARTED" == true ]]; then
    if [[ "$COMMAND" == init && ! -f "$MARKER_FILE" ]]; then
      warn "Initial deployment was not committed; stopping public/application services until init --resume succeeds."
      "${COMPOSE[@]}" stop --timeout 60 proxy >/dev/null 2>&1 \
        || warn "Failed to stop the uncommitted production proxy"
      "${COMPOSE[@]}" stop --timeout 60 backend frontend >/dev/null 2>&1 \
        || warn "Failed to stop one or more uncommitted application containers"
    fi
    warn "Rollout had already started; no blind image/database rollback was attempted."
    [[ -z "$LAST_BACKUP_DIR" ]] || warn "Preserved backup: $LAST_BACKUP_DIR"
    warn "Inspect: ${COMPOSE[*]} ps && ${COMPOSE[*]} logs --tail 200"
  fi
  if [[ -n "$WORK_DIR" && -d "$WORK_DIR" ]]; then
    rm -rf -- "$WORK_DIR"
  fi
  exit "$status"
}
