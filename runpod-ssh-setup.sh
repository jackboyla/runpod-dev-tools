#!/usr/bin/env bash
set -euo pipefail

: "${HOME:=/root}"

SSH_DIR="${HOME}/.ssh"
KEY_FILE="${SSH_DIR}/id_ed25519"
KNOWN_HOSTS="${SSH_DIR}/known_hosts"
CONFIG_FILE="${SSH_DIR}/config"

need_cmd() {
  command -v "$1" >/dev/null 2>&1
}

install_if_missing_debian() {
  # best-effort installer for common missing tools
  local pkgs=()
  for c in "$@"; do
    if ! need_cmd "$c"; then
      pkgs+=("$c")
    fi
  done
  if (( ${#pkgs[@]} > 0 )); then
    if need_cmd apt-get; then
      apt-get update -y >/dev/null
      # Map commands to packages (rough but works on most Debian/Ubuntu images)
      local packages=()
      for c in "${pkgs[@]}"; do
        case "$c" in
          ssh|ssh-add|ssh-keyscan) packages+=("openssh-client") ;;
          base64) packages+=("coreutils") ;;
          *) : ;;
        esac
      done
      if (( ${#packages[@]} > 0 )); then
        apt-get install -y --no-install-recommends "${packages[@]}" >/dev/null
      fi
    fi
  fi
}

# Ensure required commands exist
install_if_missing_debian ssh ssh-keyscan ssh-add base64 || true

mkdir -p "${SSH_DIR}"
chmod 700 "${SSH_DIR}"

# Write private key if not already present
if [[ ! -f "${KEY_FILE}" ]]; then
  if [[ -z "${SSH_PRIVATE_KEY_B64:-}" ]]; then
    echo "ERROR: SSH_PRIVATE_KEY_B64 is not set and ${KEY_FILE} does not exist." >&2
    exit 1
  fi

  # Decode base64 -> key file
  echo "${SSH_PRIVATE_KEY_B64}" | base64 -d > "${KEY_FILE}"
  chmod 600 "${KEY_FILE}"
fi

# Add GitHub host key to known_hosts (avoid interactive prompt)
if [[ ! -f "${KNOWN_HOSTS}" ]] || ! ssh-keygen -F github.com -f "${KNOWN_HOSTS}" >/dev/null 2>&1; then
  ssh-keyscan -t ed25519 github.com 2>/dev/null >> "${KNOWN_HOSTS}"
  chmod 644 "${KNOWN_HOSTS}"
fi

# Minimal SSH config for GitHub
if [[ ! -f "${CONFIG_FILE}" ]] || ! grep -qE '^\s*Host\s+github\.com\s*$' "${CONFIG_FILE}"; then
  cat >> "${CONFIG_FILE}" <<'EOF'

Host github.com
  HostName github.com
  User git
  IdentityFile ~/.ssh/id_ed25519
  IdentitiesOnly yes
  StrictHostKeyChecking yes
  UserKnownHostsFile ~/.ssh/known_hosts
EOF
  chmod 600 "${CONFIG_FILE}"
fi

# Optional: start ssh-agent + add key (non-fatal if it fails in this environment)
if [[ -z "${SSH_AUTH_SOCK:-}" ]]; then
  eval "$(ssh-agent -s)" >/dev/null 2>&1 || true
fi
ssh-add "${KEY_FILE}" >/dev/null 2>&1 || true

# Optional: rewrite https GitHub remotes to SSH
git config --global url."git@github.com:".insteadOf "https://github.com/" >/dev/null 2>&1 || true

echo "GitHub SSH setup complete."
