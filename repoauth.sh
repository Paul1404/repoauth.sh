#!/bin/bash
# -----------------------------------------------------------------------------
# repoauth.sh — Securely configure SSH key auth for Git repositories
# -----------------------------------------------------------------------------
# Author: Paul Dresch
# Version: 2.0
# Date: 2025-10-07
# -----------------------------------------------------------------------------
# Purpose:
#   - Works on any Linux distro with Bash + OpenSSH stack
#   - Safely installs a user-provided SSH private key for Git repos
#   - Updates ~/.ssh/config with proper permissions, idempotently
#   - Logs operations through systemd-journald and stderr
# -----------------------------------------------------------------------------
# Security/UX:
#   - No exposed key material in process table or stdout
#   - Strict bash error handling and quoting
#   - ShellCheck-compliant (no SC2001, SC2086, SC2046 violations)
#   - Interactive with fail-safe defaults, minimal external deps
# -----------------------------------------------------------------------------

set -euo pipefail
IFS=$'\n\t'

# ==== Constants ===============================================================
PROG="repoauth"
VERSION="2.0"
SSH_DIR="${HOME}/.ssh"
CONFIG_FILE="${SSH_DIR}/config"
LOGGER_BIN=$(command -v logger || true)

# ==== Logging =================================================================
log() {
    local level="$1"
    shift || true
    local msg="$*"
    local timestamp
    timestamp="$(date +"%Y-%m-%d %H:%M:%S")"
    printf '[%s] [%s] %s\n' "$timestamp" "$level" "$msg" >&2
    if [[ -n "$LOGGER_BIN" ]]; then
        "$LOGGER_BIN" -t "$PROG" "[$level] $msg"
    fi
}

info()    { log "INFO" "$*"; }
warn()    { log "WARN" "$*"; }
error()   { log "ERROR" "$*"; }
fatal()   { log "FATAL" "$*"; exit 1; }

# ==== Sanity Checks ===========================================================
check_prereqs() {
    local reqs=("ssh" "sed" "chmod" "mkdir")
    for bin in "${reqs[@]}"; do
        command -v "$bin" >/dev/null 2>&1 || fatal "Required command not found: $bin"
    done
}

ensure_sshdir() {
    mkdir -p "$SSH_DIR"
    chmod 700 "$SSH_DIR"
    [[ -d "$SSH_DIR" ]] || fatal "Failed to create $SSH_DIR"
}

# ==== Input Helpers ===========================================================
prompt_repo_url() {
    local repo_url
    read -r -p "Enter Git SSH repo URL (e.g. git@github.com:user/repo.git): " repo_url
    [[ $repo_url =~ ^git@[^:]+:.+\.git$ ]] || fatal "Invalid repo SSH URL format."
    printf '%s\n' "$repo_url"
}

extract_host() {
    local repo_url="$1"
    local host
    host=$(printf '%s\n' "$repo_url" | sed -E 's#^[^@]+@([^:/]+).*#\1#')
    [[ -n "$host" ]] || fatal "Unable to extract host from $repo_url"
    printf '%s\n' "$host"
}

read_key_stdin() {
    info "Paste the private key for this repository. Press Ctrl+D when done."
    info "⚠️ The key will be saved with strict 600 permissions."
    echo "----------------------------------------------------------------"
    local key
    key=$(cat)
    [[ -n "$key" ]] || fatal "No key content received."
    printf '%s\n' "$key"
}

# ==== File & Config Handling ==================================================
write_key_file() {
    local host="$1" key_content="$2"
    local keyfile="$SSH_DIR/repoauth-${host}.key"

    # Refuse to overwrite unless confirmed
    if [[ -f "$keyfile" ]]; then
        read -r -p "Key for $host already exists. Overwrite? [y/N]: " yn
        [[ "$yn" =~ ^[Yy]$ ]] || fatal "Aborted by user."
    fi

    umask 077
    printf '%s\n' "$key_content" >"$keyfile"
    chmod 600 "$keyfile" || fatal "Failed to set permissions on $keyfile"
    info "Private key written to $keyfile"
    unset key_content
}

update_ssh_config() {
    local host="$1" keyfile="$2"
    touch "$CONFIG_FILE"
    chmod 600 "$CONFIG_FILE"

    # Remove any existing entry
    if grep -qE "^Host ${host}-repoauth$" "$CONFIG_FILE"; then
        sed -i "/^Host ${host}-repoauth/,/^$/d" "$CONFIG_FILE"
        info "Removed old block for ${host}-repoauth"
    fi

    cat >>"$CONFIG_FILE" <<EOF

Host ${host}-repoauth
    HostName ${host}
    User git
    IdentityFile ${keyfile}
    IdentitiesOnly yes

EOF
    info "Updated SSH config: ${host}-repoauth → ${keyfile}"
}

# ==== Validation ==============================================================
validate_permissions() {
    [[ $(stat -c '%a' "$SSH_DIR") == "700" ]] || warn "~/.ssh permissions not 700"
    [[ $(stat -c '%a' "$CONFIG_FILE") == "600" ]] || warn "SSH config permissions not 600"
}

# ==== Usage Tips ==============================================================
usage_tips() {
    local host="$1"
    cat <<EOF

✔ SSH key configuration complete for host: ${host}

You can now use the configured alias:
  git clone ${host}-repoauth:user/repo.git

📘 Useful commands:
  ssh -T ${host}-repoauth   # Verify connection
  cat ~/.ssh/config         # Review configuration
  rm -f ~/.ssh/repoauth-${host}.key   # Remove key (if needed)
  sed -i '/Host ${host}-repoauth/,/^$/d' ~/.ssh/config  # Remove config entry

EOF
}

# ==== Main ====================================================================
main() {
    info "Starting $PROG v$VERSION"
    check_prereqs
    ensure_sshdir

    local repo_url host key_data keyfile
    repo_url=$(prompt_repo_url)
    host=$(extract_host "$repo_url")
    key_data=$(read_key_stdin)
    keyfile="${SSH_DIR}/repoauth-${host}.key"

    write_key_file "$host" "$key_data"
    update_ssh_config "$host" "$keyfile"
    validate_permissions

    if command -v ssh >/dev/null 2>&1; then
        read -r -p "Test SSH connection to ${host}-repoauth now? [y/N]: " yn
        if [[ "$yn" =~ ^[Yy]$ ]]; then
            ssh -T "${host}-repoauth" || warn "Non-zero exit from ssh (may be normal)"
        fi
    fi

    usage_tips "$host"
    info "$PROG completed successfully."
}

main "$@"
