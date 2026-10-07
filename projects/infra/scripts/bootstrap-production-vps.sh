#!/usr/bin/env bash
set -Eeuo pipefail

# One-time, idempotent preparation of an Ubuntu production host.
# This script intentionally does not create .env.production, issue TLS
# certificates, alter the firewall, or start the application stack.

umask 077

DEPLOY_USER="saas-deploy"
REPOSITORY_DIR="/opt/saas-service"
REPOSITORY_URL="git@github.com:duoset/saas-service.git"
CI_PUBLIC_KEY_FILE=""
CLONE_REPOSITORY=false
INSTALL_PACKAGES=true
INSTALL_DOCKER=true
TEMPORARY_FILES=()

usage() {
  cat <<'USAGE'
Usage:
  sudo ./infra/scripts/bootstrap-production-vps.sh [options]

Options:
  --deploy-user USER          Dedicated SSH/Docker user (default: saas-deploy).
  --repository-dir PATH       Checkout path (default: /opt/saas-service).
  --repository-url URL        Read-only Git URL.
  --ci-public-key-file PATH   Public key whose private half is VPS_SSH_KEY.
  --clone                     Clone/verify the repository after its deploy key
                              has been registered read-only on GitHub.
  --skip-package-install      Only validate already installed host tools.
  --skip-docker-install       Do not install Docker if it is absent.
  -h, --help                  Show this help.

Run once without --clone, register the printed repository key in GitHub as a
read-only Deploy key, then rerun with --clone. The CI public key is restricted
from forwarding and PTY allocation, but its user can control Docker; protect
the corresponding private key as a production credential.
USAGE
}

log() {
  printf '[vps-bootstrap] %s\n' "$*"
}

die() {
  printf '[vps-bootstrap] ERROR: %s\n' "$*" >&2
  exit 1
}

cleanup() {
  local temporary
  for temporary in "${TEMPORARY_FILES[@]}"; do
    [[ -z "$temporary" || ! -e "$temporary" ]] || rm -f -- "$temporary"
  done
}
trap cleanup EXIT INT TERM

while (( $# > 0 )); do
  case "$1" in
    --deploy-user)
      [[ $# -ge 2 ]] || die "--deploy-user requires a value"
      DEPLOY_USER="$2"
      shift 2
      ;;
    --repository-dir)
      [[ $# -ge 2 ]] || die "--repository-dir requires a value"
      REPOSITORY_DIR="$2"
      shift 2
      ;;
    --repository-url)
      [[ $# -ge 2 ]] || die "--repository-url requires a value"
      REPOSITORY_URL="$2"
      shift 2
      ;;
    --ci-public-key-file)
      [[ $# -ge 2 ]] || die "--ci-public-key-file requires a value"
      CI_PUBLIC_KEY_FILE="$2"
      shift 2
      ;;
    --clone)
      CLONE_REPOSITORY=true
      shift
      ;;
    --skip-package-install)
      INSTALL_PACKAGES=false
      shift
      ;;
    --skip-docker-install)
      INSTALL_DOCKER=false
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *) die "Unknown option: $1" ;;
  esac
done

(( EUID == 0 )) || die "Run this script as root (sudo)"
[[ "$DEPLOY_USER" =~ ^[a-z_][a-z0-9_-]{0,31}$ ]] \
  || die "Invalid deploy user: $DEPLOY_USER"
[[ "$DEPLOY_USER" != root ]] || die "The deployment user must never be root"
[[ "$REPOSITORY_DIR" =~ ^/opt/[A-Za-z0-9._/-]+$ \
    && "$REPOSITORY_DIR" != *'/../'* \
    && "$REPOSITORY_DIR" != */.. \
    && "$REPOSITORY_DIR" != *'/./'* \
    && "$REPOSITORY_DIR" != */. \
    && "$REPOSITORY_DIR" != *'//'* ]] \
  || die "Repository directory must be a dedicated path below /opt"
[[ -n "$REPOSITORY_URL" && "$REPOSITORY_URL" != *[[:space:]]* ]] \
  || die "Invalid repository URL"

[[ -r /etc/os-release ]] || die "/etc/os-release is unavailable"
# shellcheck disable=SC1091
source /etc/os-release
[[ "${ID:-}" == ubuntu ]] \
  || die "This bootstrap supports Ubuntu only; use the production runbook on other Linux distributions"
case "${VERSION_ID:-}" in
  22.04|24.04|26.04) ;;
  *) die "Unsupported Ubuntu release: ${VERSION_ID:-unknown} (use an LTS release supported by Docker)" ;;
esac

base_packages=(
  age bash ca-certificates curl git jq openssl dnsutils gzip tar snapd
  util-linux coreutils diffutils findutils gawk sed grep iproute2
  openssh-client openssh-server
)

if [[ "$INSTALL_PACKAGES" == true ]]; then
  log "Installing host prerequisites from Ubuntu repositories"
  export DEBIAN_FRONTEND=noninteractive
  apt-get update
  apt-get install -y --no-install-recommends "${base_packages[@]}"
else
  for command_name in bash curl git jq openssl sha256sum base64 awk sed grep \
    sort comm cmp gzip tar flock dig getent stat find cut wc tr install realpath \
    df id mktemp ssh ssh-keygen sshd age aws; do
    command -v "$command_name" >/dev/null 2>&1 \
      || die "Required command is absent: $command_name"
  done
fi

install_aws_cli_from_official_snap() {
  if command -v aws >/dev/null 2>&1 \
    && aws --version 2>&1 | grep -Eq '^aws-cli/2\.'; then
    return
  fi

  command -v snap >/dev/null 2>&1 \
    || die "AWS CLI v2 is absent and snap is unavailable"
  systemctl enable --now snapd.socket
  snap wait system seed.loaded
  if ! snap list aws-cli >/dev/null 2>&1; then
    log "Installing the officially supported AWS CLI v2 snap"
    snap install aws-cli --classic
  fi
  [[ -x /snap/bin/aws ]] || die "The official aws-cli snap did not expose /snap/bin/aws"
  if [[ ! -e /usr/local/bin/aws ]]; then
    ln -s /snap/bin/aws /usr/local/bin/aws
  fi
  command -v aws >/dev/null 2>&1 \
    && aws --version 2>&1 | grep -Eq '^aws-cli/2\.' \
    || die "AWS CLI v2 installation failed"
}

install_aws_cli_from_official_snap
REPOSITORY_DIR="$(realpath --canonicalize-missing -- "$REPOSITORY_DIR")"
[[ "$REPOSITORY_DIR" == /opt/* && "$REPOSITORY_DIR" != /opt/ ]] \
  || die "Canonical repository directory escaped /opt"

install_docker_from_official_repository() {
  local conflict docker_key_temporary docker_sources_temporary architecture codename
  local conflicts=()

  for conflict in docker.io docker-compose docker-compose-v2 docker-doc docker-buildx \
    podman-docker containerd runc; do
    if dpkg-query -W -f='${db:Status-Abbrev}' "$conflict" 2>/dev/null | grep -q '^ii '; then
      conflicts+=("$conflict")
    fi
  done
  if (( ${#conflicts[@]} > 0 )); then
    die "Conflicting Docker packages are installed (${conflicts[*]}). Review and remove them manually before installing Docker CE."
  fi

  install -d -m 0755 /etc/apt/keyrings
  docker_key_temporary="$(mktemp)"
  docker_sources_temporary="$(mktemp)"
  TEMPORARY_FILES+=("$docker_key_temporary" "$docker_sources_temporary")
  curl --fail --silent --show-error --location \
    https://download.docker.com/linux/ubuntu/gpg \
    --output "$docker_key_temporary"
  install -m 0644 "$docker_key_temporary" /etc/apt/keyrings/docker.asc

  architecture="$(dpkg --print-architecture)"
  codename="${UBUNTU_CODENAME:-${VERSION_CODENAME:-}}"
  [[ -n "$codename" ]] || die "Cannot determine the Ubuntu codename"
  printf '%s\n' \
    'Types: deb' \
    'URIs: https://download.docker.com/linux/ubuntu' \
    "Suites: $codename" \
    'Components: stable' \
    "Architectures: $architecture" \
    'Signed-By: /etc/apt/keyrings/docker.asc' \
    >"$docker_sources_temporary"
  install -m 0644 "$docker_sources_temporary" /etc/apt/sources.list.d/docker.sources

  apt-get update
  apt-get install -y --no-install-recommends \
    docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
}

if ! command -v docker >/dev/null 2>&1 || ! docker compose version >/dev/null 2>&1; then
  [[ "$INSTALL_DOCKER" == true ]] \
    || die "Docker Engine and Docker Compose v2 are required"
  log "Installing Docker Engine, Buildx and Compose from Docker's official apt repository"
  install_docker_from_official_repository
fi
systemctl enable --now docker
systemctl enable --now ssh
docker info >/dev/null 2>&1 || die "Docker daemon is unavailable"
docker compose version >/dev/null 2>&1 || die "Docker Compose v2 is unavailable"
docker buildx version >/dev/null 2>&1 || die "Docker Buildx is unavailable"

compose_probe="$(mktemp)"
TEMPORARY_FILES+=("$compose_probe")
printf '%s\n' \
  'services:' \
  '  probe:' \
  '    image: scratch' \
  >"$compose_probe"
docker compose --file "$compose_probe" config --format json \
  | jq -e '.services.probe.image == "scratch"' >/dev/null \
  || die "Docker Compose does not support the required JSON config output"
docker compose --file "$compose_probe" config --environment >/dev/null \
  || die "Docker Compose does not support config --environment"

if id "$DEPLOY_USER" >/dev/null 2>&1; then
  deploy_home="$(getent passwd "$DEPLOY_USER" | cut -d: -f6)"
else
  log "Creating dedicated deployment user: $DEPLOY_USER"
  useradd --create-home --user-group --shell /bin/bash "$DEPLOY_USER"
  deploy_home="$(getent passwd "$DEPLOY_USER" | cut -d: -f6)"
fi
[[ "$deploy_home" == /* && "$deploy_home" != / ]] \
  || die "Invalid home directory for $DEPLOY_USER"
deploy_uid="$(id -u "$DEPLOY_USER")"
(( deploy_uid >= 1000 && deploy_uid < 65534 )) \
  || die "$DEPLOY_USER must be a dedicated, non-system account"
deploy_shell="$(getent passwd "$DEPLOY_USER" | cut -d: -f7)"
[[ "$deploy_home" == "/home/$DEPLOY_USER" && "$deploy_shell" == /bin/bash ]] \
  || die "$DEPLOY_USER must use /home/$DEPLOY_USER and /bin/bash"
[[ "$(id -gn "$DEPLOY_USER")" == "$DEPLOY_USER" ]] \
  || die "$DEPLOY_USER must use an exclusive same-name primary group"
deploy_gid="$(id -g "$DEPLOY_USER")"
other_primary_users="$(getent passwd | awk -F: -v gid="$deploy_gid" -v user="$DEPLOY_USER" \
  '$4 == gid && $1 != user { print $1 }')"
[[ -z "$other_primary_users" ]] \
  || die "The deployment primary group is shared by other accounts: $other_primary_users"
supplementary_members="$(getent group "$DEPLOY_USER" | cut -d: -f4 | tr ',' '\n' \
  | sed '/^$/d' | grep -Fvx "$DEPLOY_USER" || true)"
[[ -z "$supplementary_members" ]] \
  || die "The deployment primary group has extra members: $supplementary_members"
if id -nG "$DEPLOY_USER" | tr ' ' '\n' | grep -Eq '^(sudo|admin|wheel)$'; then
  die "$DEPLOY_USER must not belong to an administrative group"
fi

# OpenSSH/PAM may reject public-key authentication for a locked account. Give
# the account an unknown random password, then disable every password-based SSH
# method for this user below. The generated value is never printed or stored.
account_status="$(passwd -S "$DEPLOY_USER" | awk '{print $2}')"
if [[ "$account_status" == L ]]; then
  random_unusable_password="$(openssl rand -base64 48)"
  printf '%s:%s\n' "$DEPLOY_USER" "$random_unusable_password" | chpasswd
  unset random_unusable_password
fi
chage -M -1 -E -1 "$DEPLOY_USER"

sshd_match_file="/etc/ssh/sshd_config.d/60-agentefiscal-deploy.conf"
managed_authorized_keys_dir="/etc/ssh/authorized_keys"
managed_authorized_keys_file="${managed_authorized_keys_dir}/${DEPLOY_USER}"
install -d -m 0755 -o root -g root "$managed_authorized_keys_dir"
[[ ! -L "$managed_authorized_keys_file" ]] \
  || die "$managed_authorized_keys_file must not be a symbolic link"
if [[ ! -e "$managed_authorized_keys_file" ]]; then
  install -m 0644 -o root -g root /dev/null "$managed_authorized_keys_file"
fi
[[ -f "$managed_authorized_keys_file" ]] \
  || die "$managed_authorized_keys_file is not a regular file"
chown root:root "$managed_authorized_keys_file"
chmod 0644 "$managed_authorized_keys_file"
sshd_candidate="$(mktemp)"
TEMPORARY_FILES+=("$sshd_candidate")
sshd_previous=""
[[ ! -L "$sshd_match_file" ]] || die "$sshd_match_file must not be a symbolic link"
if [[ -e "$sshd_match_file" ]]; then
  [[ -f "$sshd_match_file" ]] || die "$sshd_match_file is not a regular file"
  sshd_previous="$(mktemp)"
  TEMPORARY_FILES+=("$sshd_previous")
  install -m 0600 "$sshd_match_file" "$sshd_previous"
fi
restore_sshd_policy() {
  if [[ -n "$sshd_previous" ]]; then
    install -m 0644 "$sshd_previous" "$sshd_match_file"
  else
    rm -f -- "$sshd_match_file"
  fi
}
printf '%s\n' \
  "Match User $DEPLOY_USER" \
  '    AuthenticationMethods publickey' \
  '    PubkeyAuthentication yes' \
  "    AuthorizedKeysFile $managed_authorized_keys_file" \
  '    PasswordAuthentication no' \
  '    KbdInteractiveAuthentication no' \
  '    PermitEmptyPasswords no' \
  '    DisableForwarding yes' \
  '    PermitTTY no' \
  '    X11Forwarding no' \
  >"$sshd_candidate"
install -m 0644 "$sshd_candidate" "$sshd_match_file"
if ! sshd -t; then
  restore_sshd_policy
  die "Generated OpenSSH deployment-user policy is invalid; the previous daemon configuration remains loaded"
fi
if ! sshd_effective="$(sshd -T -C "user=$DEPLOY_USER,host=agentefiscal-vps,addr=127.0.0.1")"; then
  restore_sshd_policy
  die "Cannot evaluate the effective OpenSSH deployment-user policy"
fi
for expected_setting in \
  'authenticationmethods publickey' \
  'pubkeyauthentication yes' \
  "authorizedkeysfile $managed_authorized_keys_file" \
  'passwordauthentication no' \
  'kbdinteractiveauthentication no' \
  'disableforwarding yes' \
  'permittty no' \
  'x11forwarding no'; do
  if ! grep -Fqx -- "$expected_setting" <<<"$sshd_effective"; then
    restore_sshd_policy
    die "OpenSSH did not apply required setting: $expected_setting"
  fi
done
systemctl reload ssh

getent group docker >/dev/null || die "Docker group was not created"
usermod -aG docker "$DEPLOY_USER"

[[ ! -L "$REPOSITORY_DIR" ]] || die "Repository directory must not be a symbolic link"
if [[ ! -e "$REPOSITORY_DIR" ]]; then
  install -d -m 0750 -o "$DEPLOY_USER" -g "$DEPLOY_USER" "$REPOSITORY_DIR"
fi
[[ -d "$REPOSITORY_DIR" ]] || die "Repository path is not a directory"
repository_owner="$(stat -c '%U' "$REPOSITORY_DIR")"
repository_group="$(stat -c '%G' "$REPOSITORY_DIR")"
[[ "$repository_owner" == "$DEPLOY_USER" ]] \
  || die "$REPOSITORY_DIR must be owned by $DEPLOY_USER (current owner: $repository_owner)"
[[ "$repository_group" == "$DEPLOY_USER" ]] \
  || die "$REPOSITORY_DIR must use group $DEPLOY_USER (current group: $repository_group)"
chmod 0750 "$REPOSITORY_DIR"

ssh_directory="${deploy_home}/.ssh"
known_hosts_file="${ssh_directory}/known_hosts"
repository_key="${ssh_directory}/saas-service-github-readonly"
install -d -m 0700 -o "$DEPLOY_USER" -g "$DEPLOY_USER" "$ssh_directory"

# Published at https://docs.github.com/authentication/keeping-your-account-and-data-secure/githubs-ssh-key-fingerprints
github_ed25519_host_key='github.com ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl'
[[ ! -L "$known_hosts_file" ]] || die "$known_hosts_file must not be a symbolic link"
known_hosts_temporary="$(mktemp)"
TEMPORARY_FILES+=("$known_hosts_temporary")
printf '%s\n' "$github_ed25519_host_key" >"$known_hosts_temporary"
install -m 0600 -o "$DEPLOY_USER" -g "$DEPLOY_USER" \
  "$known_hosts_temporary" "$known_hosts_file"

if [[ ! -e "$repository_key" ]]; then
  log "Generating the VPS read-only repository deploy key"
  runuser -u "$DEPLOY_USER" -- ssh-keygen -q -t ed25519 -N '' \
    -C "${DEPLOY_USER}@agentefiscal-production-readonly" -f "$repository_key"
fi
[[ -f "$repository_key" && ! -L "$repository_key" && -f "${repository_key}.pub" ]] \
  || die "Repository deploy key is incomplete or unsafe"
chown "$DEPLOY_USER:$DEPLOY_USER" "$repository_key" "${repository_key}.pub"
chmod 0600 "$repository_key"
chmod 0644 "${repository_key}.pub"

if [[ -n "$CI_PUBLIC_KEY_FILE" ]]; then
  [[ -f "$CI_PUBLIC_KEY_FILE" && ! -L "$CI_PUBLIC_KEY_FILE" ]] \
    || die "CI public key must be a regular, non-symbolic-link file"
  mapfile -t ci_key_lines < <(sed '/^[[:space:]]*$/d; s/\r$//' "$CI_PUBLIC_KEY_FILE")
  (( ${#ci_key_lines[@]} == 1 )) || die "CI public key file must contain exactly one key"
  ci_public_key="${ci_key_lines[0]}"
  [[ "$ci_public_key" == ssh-ed25519\ * || "$ci_public_key" == sk-ssh-ed25519@openssh.com\ * ]] \
    || die "Use a dedicated Ed25519 CI key"
  ssh-keygen -lf "$CI_PUBLIC_KEY_FILE" -E sha256 >/dev/null \
    || die "CI public key is invalid"
  restricted_ci_key="restrict $ci_public_key"
  authorized_keys_temporary="$(mktemp)"
  TEMPORARY_FILES+=("$authorized_keys_temporary")
  printf '%s\n' "$restricted_ci_key" >"$authorized_keys_temporary"
  install -m 0644 -o root -g root "$authorized_keys_temporary" \
    "$managed_authorized_keys_file"
  log "Installed the restricted GitHub Actions SSH public key"
fi

repository_ssh_command="ssh -i $repository_key -o IdentitiesOnly=yes -o BatchMode=yes -o PasswordAuthentication=no -o StrictHostKeyChecking=yes -o UserKnownHostsFile=$known_hosts_file -o GlobalKnownHostsFile=/dev/null"
if [[ "$CLONE_REPOSITORY" == true ]]; then
  log "Verifying read-only repository access"
  runuser -u "$DEPLOY_USER" -- env "GIT_SSH_COMMAND=$repository_ssh_command" \
    git ls-remote "$REPOSITORY_URL" HEAD >/dev/null \
    || die "GitHub denied the repository key; register the printed public key as read-only first"

  if [[ -d "${REPOSITORY_DIR}/.git" ]]; then
    existing_origin="$(runuser -u "$DEPLOY_USER" -- git -C "$REPOSITORY_DIR" remote get-url origin)"
    [[ "$existing_origin" == "$REPOSITORY_URL" ]] \
      || die "Existing origin does not match $REPOSITORY_URL"
  else
    [[ -z "$(find "$REPOSITORY_DIR" -mindepth 1 -maxdepth 1 -print -quit)" ]] \
      || die "$REPOSITORY_DIR is not empty and is not a Git checkout"
    runuser -u "$DEPLOY_USER" -- env "GIT_SSH_COMMAND=$repository_ssh_command" \
      git clone --origin origin --branch main --single-branch \
      "$REPOSITORY_URL" "$REPOSITORY_DIR"
  fi
  runuser -u "$DEPLOY_USER" -- git -C "$REPOSITORY_DIR" \
    config core.sshCommand "$repository_ssh_command"
  runuser -u "$DEPLOY_USER" -- git -C "$REPOSITORY_DIR" fetch --no-tags origin main
  [[ -f "${REPOSITORY_DIR}/.git/HEAD" && ! -L "${REPOSITORY_DIR}/.git" ]] \
    || die "Git metadata is absent or unsafe"
  unsafe_git_entry="$(find "${REPOSITORY_DIR}/.git" -xdev \
    \( ! -user "$DEPLOY_USER" -o -perm /0022 \) -print -quit)"
  [[ -z "$unsafe_git_entry" ]] \
    || die "Git metadata is not exclusively controlled by $DEPLOY_USER: $unsafe_git_entry"
  unsafe_tracked_entry=""
  while IFS= read -r -d '' tracked_path; do
    absolute_tracked_path="${REPOSITORY_DIR}/${tracked_path}"
    if [[ ! -f "$absolute_tracked_path" || -L "$absolute_tracked_path" \
        || "$(stat -c '%U' "$absolute_tracked_path")" != "$DEPLOY_USER" \
        || $((8#$(stat -c '%a' "$absolute_tracked_path") & 0022)) -ne 0 ]]; then
      unsafe_tracked_entry="$tracked_path"
      break
    fi
  done < <(runuser -u "$DEPLOY_USER" -- git -C "$REPOSITORY_DIR" ls-files -z)
  [[ -z "$unsafe_tracked_entry" ]] \
    || die "Tracked checkout entry is unsafe: $unsafe_tracked_entry"
  [[ -f "${REPOSITORY_DIR}/infra/scripts/deploy-production.sh" \
      && ! -L "${REPOSITORY_DIR}/infra/scripts/deploy-production.sh" \
      && -x "${REPOSITORY_DIR}/infra/scripts/deploy-production.sh" ]] \
    || die "Production deploy script is absent or not executable"
  [[ -f "${REPOSITORY_DIR}/infra/scripts/upload-production-backup.sh" \
      && ! -L "${REPOSITORY_DIR}/infra/scripts/upload-production-backup.sh" \
      && -x "${REPOSITORY_DIR}/infra/scripts/upload-production-backup.sh" ]] \
    || die "Off-site backup uploader is absent or not executable"

  backup_service_template="${REPOSITORY_DIR}/infra/systemd/agentefiscal-production-backup.service.in"
  backup_timer_template="${REPOSITORY_DIR}/infra/systemd/agentefiscal-production-backup.timer"
  [[ -f "$backup_service_template" && -f "$backup_timer_template" ]] \
    || die "Production backup systemd templates are absent"
  backup_service_rendered="$(mktemp)"
  TEMPORARY_FILES+=("$backup_service_rendered")
  sed \
    -e "s|__DEPLOY_USER__|$DEPLOY_USER|g" \
    -e "s|__REPOSITORY_DIR__|$REPOSITORY_DIR|g" \
    "$backup_service_template" >"$backup_service_rendered"
  install -m 0644 "$backup_service_rendered" \
    /etc/systemd/system/agentefiscal-production-backup.service
  install -m 0644 "$backup_timer_template" \
    /etc/systemd/system/agentefiscal-production-backup.timer
  systemd-analyze verify \
    /etc/systemd/system/agentefiscal-production-backup.service \
    /etc/systemd/system/agentefiscal-production-backup.timer
  systemctl daemon-reload
  log "Installed the backup timer; enable it only after the first verified off-site backup"
fi

runuser -u "$DEPLOY_USER" -- docker info >/dev/null 2>&1 \
  || die "$DEPLOY_USER cannot access Docker; log out/in and rerun after group membership refresh"

if ss -H -ltn | awk '$4 ~ /:80$/ || $4 ~ /:443$/ {found=1} END {exit !found}'; then
  log "WARNING: TCP/80 or TCP/443 is already occupied; confirm that only the intended production proxy owns it"
fi
if command -v timedatectl >/dev/null 2>&1 \
  && [[ "$(timedatectl show --property=NTPSynchronized --value 2>/dev/null || true)" != yes ]]; then
  log "WARNING: NTP is not synchronized yet; fix clock synchronization before TLS/init"
fi
log "Disk availability: $(df -h --output=avail,target "$REPOSITORY_DIR" /var/lib/docker 2>/dev/null | tail -n +2 | tr '\n' '; ')"

printf '\nRepository deploy key (register in GitHub with read-only access):\n'
sed -n '1p' "${repository_key}.pub"
printf '\nVPS SSH host fingerprint (store as VPS_HOST_FINGERPRINT):\n'
if [[ -f /etc/ssh/ssh_host_ed25519_key.pub ]]; then
  ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key.pub -E sha256 | awk '{print $2}'
else
  printf 'No Ed25519 SSH host key found; review the OpenSSH server configuration.\n'
fi

printf '\nHost preparation complete.\n'
if [[ "$CLONE_REPOSITORY" != true ]]; then
  printf '1. Add the repository key above at Settings > Deploy keys, without write access.\n'
  printf '2. Rerun this script with --clone.\n'
else
  printf 'Repository ready at %s. Perform the first production init manually as %s.\n' \
    "$REPOSITORY_DIR" "$DEPLOY_USER"
  printf 'After the first verified off-site backup, enable agentefiscal-production-backup.timer.\n'
fi
printf 'Firewall/DNS/TLS and off-site backup remain explicit runbook steps.\n'
