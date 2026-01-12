#!/usr/bin/env bash
set -euo pipefail

: "${HOME:=/root}"

SSH_DIR="${HOME}/.ssh"
KEY_FILE="${SSH_DIR}/id_ed25519"
KNOWN_HOSTS="${SSH_DIR}/known_hosts"
CONFIG_FILE="${SSH_DIR}/config"

mkdir -p "${SSH_DIR}"
chmod 700 "${SSH_DIR}"

# --- Write private key (only if missing) ---
if [[ ! -f "${KEY_FILE}" ]]; then
  if [[ -z "${SECRET_SSH_PRIVATE_KEY_B64:-}" ]]; then
    echo "ERROR: SECRET_SSH_PRIVATE_KEY_B64 is not set and ${KEY_FILE} does not exist." >&2
    exit 1
  fi

  # Decode base64 -> key file
  echo "${SECRET_SSH_PRIVATE_KEY_B64}" | base64 -d > "${KEY_FILE}"

  # Strip CR if any (harmless if none)
  tr -d '\r' < "${KEY_FILE}" > "${KEY_FILE}.tmp" && mv "${KEY_FILE}.tmp" "${KEY_FILE}"

  chmod 600 "${KEY_FILE}"
fi

# --- Pin GitHub host key to avoid interactive prompt ---
if [[ ! -f "${KNOWN_HOSTS}" ]] || ! ssh-keygen -F github.com -f "${KNOWN_HOSTS}" >/dev/null 2>&1; then
  ssh-keyscan -t ed25519 github.com 2>/dev/null >> "${KNOWN_HOSTS}"
  chmod 644 "${KNOWN_HOSTS}"
fi

# --- Minimal SSH config for GitHub (optional but helpful) ---
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

# --- Optional: prefer SSH when someone uses https GitHub remotes ---
git config --global url."git@github.com:".insteadOf "https://github.com/" >/dev/null 2>&1 || true

# --- Validate key parses (won’t print it) ---
ssh-keygen -l -f "${KEY_FILE}" >/dev/null

echo "GitHub SSH setup complete."
