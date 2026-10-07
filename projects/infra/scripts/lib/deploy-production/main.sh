main() {
  local command_name
  parse_arguments "$@"

  if [[ ! -f "$ENV_FILE" ]]; then
    [[ "$COMMAND" == init ]] || die "Environment file not found: $ENV_FILE (run init first)"
    create_environment_file
    exit 2
  fi

  for command_name in awk stat base64 openssl jq sed sha256sum realpath install flock find id cmp sort uniq head tr dig getent mktemp chmod mv; do
    require_command "$command_name"
  done
  initialize_invocation_workspace
  trap cleanup_on_exit EXIT
  trap 'exit 130' INT
  trap 'exit 143' TERM
  capture_deployment_inputs
  prepare_outbound_attempt_hmac_approval_directory
  validate_environment_file
  sanitize_compose_environment
  configure_compose_command
  render_effective_compose_snapshot
  initialize_runtime
  render_production_assets

  case "$COMMAND" in
    init) run_init ;;
    update) run_update ;;
    backup) run_backup ;;
    status) run_status ;;
  esac
}
