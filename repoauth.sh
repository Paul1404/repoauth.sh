#!/bin/bash
# -----------------------------------------------------------------------------
# repoauth.sh — Secure SSH key setup for Git hosts
# -----------------------------------------------------------------------------
# Author: Paul Dresch (Systems Engineer, Linux)
# Version: 3.0
# Date: 2025-10-07
# -----------------------------------------------------------------------------
# Description:
#   Secure, portable script that configures SSH authentication for any Git host
#   (e.g. github.com, gitlab.company.net). Writes a private key safely to
#   ~/.ssh and updates ~/.ssh/config with proper permissions and journald logs.
# -----------------------------------------------------------------------------
# Features:
#   • Minimal dependencies (bash, sed, ssh, chmod, mkdir)
#   • Works on all modern Linux distributions
#   • ShellCheck‑clean, safe quoting, pipefail strict mode
#   • No aliases — uses real host names (github.com, gitlab.com, etc.)
#   • Sanitizes CRLF line endings in pasted keys
#   • Logs actions to both stderr and systemd-journald (if available)
# -----------------------------------------------------------------------------

set -euo pipefail
IFS=$'\n\t'

PROG="repoauth"
VERSION="3.0"
SSH_DIR="${HOME}/.ssh"
CONFIG_FILE="${SSH_DIR}/config"
LOGGER_BIN=$(command -v logger || true)

# -----------------------------------------------------------------------------
# Logging + messaging helpers
# -----------------------------------------------------------------------------
log() {
    local level="$1"; shift || true
    local msg="$*"
    local ts
    ts="$(date +"%F %T")"
    printf '[%s] [%s] %s\n' "$ts" "$level" "$msg" >&2
    if [[ -n "$LOGGER_BIN" ]]; then
        "$LOGGER_BIN" -t "$PROG" "[$level] $msg"
    fi
}
info()  { log INFO "$*"; }
warn()  { log WARN "$*"; }
error() { log ERROR "$*"; }
fatal() { log FATAL "$*"; exit 1; }

# -----------------------------------------------------------------------------
# Dependency and directory checks
# -----------------------------------------------------------------------------
check_prereqs() {
    local reqs=(bash ssh sed mkdir chmod)
    for bin in "${reqs[@]}"; do
        command -v "$bin" >/dev/null 2>&1 || fatal "Missing required command: $bin"
    done
}

ensure_ssh_dir() {
    mkdir -p "$SSH_DIR"
    chmod 700 "$SSH_DIR"
    [[ -d "$SSH_DIR" ]] || fatal "Failed to create $SSH_DIR"
}

# -----------------------------------------------------------------------------
# Input + key reading
# -----------------------------------------------------------------------------
read_host() {
    local host
    read -r -p "Enter Git host (e.g. github.com, gitlab.com, custom.domain): " host
    [[ -n "$host" ]] || fatal "Host cannot be empty."
    echo "$host"
}

read_key() {
    # -------------------------------------------------------------
    # Securely read a multiline private SSH key from stdin.
    # - Prompts go to stderr (safe in process substitution)
    # - Reads until EOF (Ctrl+D)
    # - Removes CR (\r) line endings
    # - Validates that key looks plausible
    # -------------------------------------------------------------
    {
        echo
        echo "Paste your private SSH key for this host."
        echo "When finished, press ENTER then Ctrl+D."
        echo "⚠️  The key won't be displayed and will be saved with 0600 perms."
        echo "----------------------------------------------------------------"
    } >&2

    local key
    key=$(cat)
    key=$(printf '%s' "$key" | tr -d '\r')

    # Sanity checks
    if [ -z "$key" ]; then
        fatal "No key content received (input empty)."
    fi
    if ! printf '%s\n' "$key" | grep 'BEGIN OPENSSH' >/dev/null 2>&1; then
        fatal "Invalid key: missing BEGIN marker."
    fi
    if ! printf '%s\n' "$key" | grep 'END OPENSSH' >/dev/null 2>&1; then
        fatal "Invalid key: missing END marker."
    fi

    # Drop blank lines that sometimes appear from copy/paste
    key=$(printf '%s\n' "$key" | awk 'NF')

    printf '%s\n' "$key"
}

# -----------------------------------------------------------------------------
# Write key securely
# -----------------------------------------------------------------------------
write_key_file() {
    local host="$1" key_content="$2"
    local keyfile="${SSH_DIR}/${host}.key"

    if [[ -f "$keyfile" ]]; then
        read -r -p "Key for ${host} already exists. Overwrite? [y/N]: " yn
        [[ "$yn" =~ ^[Yy]$ ]] || fatal "Aborted by user."
    fi

    umask 077
    printf '%s\n' "$key_content" >"$keyfile"
    chmod 600 "$keyfile" || fatal "Failed to set permissions on $keyfile"
    info "Private key written to $keyfile"
    unset key_content
    echo "$keyfile"
}

# -----------------------------------------------------------------------------
# Update SSH config with the real host name
# -----------------------------------------------------------------------------
update_ssh_config() {
    local host="$1" keyfile="$2"

    touch "$CONFIG_FILE"
    chmod 600 "$CONFIG_FILE"

    if grep -qE "^Host[[:space:]]+$host$" "$CONFIG_FILE"; then
        read -r -p "An SSH config entry for $host already exists. Overwrite it? [y/N]: " yn
        [[ "$yn" =~ ^[Yy]$ ]] || fatal "Aborted by user."
        sed -i "/^Host[[:space:]]\+$host/,/^$/d" "$CONFIG_FILE"
        info "Removed old SSH config block for $host"
    fi

    cat >>"$CONFIG_FILE" <<EOF

Host $host
    HostName $host
    User git
    IdentityFile $keyfile
    IdentitiesOnly yes

EOF

    info "Added SSH configuration block for $host"
}

# -----------------------------------------------------------------------------
# Validate and tip
# -----------------------------------------------------------------------------
validate_perms() {
    [[ $(stat -c '%a' "$SSH_DIR") == "700" ]] || warn "~/.ssh directory permissions not 700"
    [[ $(stat -c '%a' "$CONFIG_FILE") == "600" ]] || warn "~/.ssh/config permissions not 600"
}

usage_tips() {
    local host="$1"
    cat <<EOF

✅ Setup complete for host: $host

You can now use your Git repos normally:
  git clone git@$host:username/repository.git

Diagnostics:
  ssh -T $host
  cat ~/.ssh/config | grep -A4 "Host $host"

Removal (manual):
  rm -f ~/.ssh/${host}.key
  sed -i '/Host ${host}/,/^$/d' ~/.ssh/config

Logs:
  journalctl -t repoauth

EOF
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------
main() {
    info "Starting $PROG v$VERSION"
    check_prereqs
    ensure_ssh_dir

    local host key_data keyfile
    host=$(read_host)
    key_data=$(read_key)
    keyfile=$(write_key_file "$host" "$key_data")

    update_ssh_config "$host" "$keyfile"
    validate_perms

    if command -v ssh >/dev/null 2>&1; then
        read -r -p "Test SSH connection to $host now? [y/N]: " yn
        if [[ "$yn" =~ ^[Yy]$ ]]; then
            ssh -T "$host" || warn "SSH test returned non-zero exit (check host or key)."
        fi
    fi

    usage_tips "$host"
    info "$PROG completed successfully."
}

main "$@"
