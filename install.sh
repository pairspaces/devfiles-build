#!/bin/sh
set -e

# --------------------------
# Configuration
# --------------------------
PAIR_ENV="build"
PAIR_VERSION="2.5.1-build"
PORT="${VAR_PORT:-2222}"
PAIR_CLI_URL="https://s3.amazonaws.com/downloads.pairspaces.com/cli/$PAIR_ENV/linux/amd64/pair_${PAIR_VERSION}"
PAIR_CLI_PATH="/opt/pair/pair"
SSHD_CONFIG_TARGET="/etc/ssh/ps_sshd_config"
SUPERVISOR_CONF_DIR="/etc/supervisor/conf.d"
SUPERVISORD_MAIN_CONF="/etc/supervisor/supervisord.conf"
TOKEN="${TOKEN:-CHANGE_ME}"

PKG_INSTALL=""
PKG_UPDATE=""

# --------------------------
# Detect package manager
# --------------------------
detect_package_manager() {
  if command -v apt-get >/dev/null 2>&1; then
    PKG_INSTALL="apt-get install -y --no-install-recommends"
    PKG_UPDATE="apt-get update"
  elif command -v apk >/dev/null 2>&1; then
    PKG_INSTALL="apk add --no-cache"
    PKG_UPDATE=":"
  elif command -v dnf >/dev/null 2>&1; then
    PKG_INSTALL="dnf install -y"
    PKG_UPDATE="dnf makecache"
  elif command -v yum >/dev/null 2>&1; then
    PKG_INSTALL="yum install -y"
    PKG_UPDATE="yum makecache"
  elif command -v pacman >/dev/null 2>&1; then
    PKG_INSTALL="pacman -Sy --noconfirm"
    PKG_UPDATE="pacman -Sy"
  else
    echo "Unsupported OS. Could not detect package manager."
    exit 1
  fi
}

# --------------------------
# Install system packages
# --------------------------
install_packages() {
  eval "$PKG_UPDATE"
  eval "$PKG_INSTALL curl bash openssh-server sudo ca-certificates iproute2 kmod supervisor"
}

# --------------------------
# Install Pair CLI
# --------------------------
install_pair_cli() {
  mkdir -p "$(dirname "$PAIR_CLI_PATH")"
  curl -fsSL "$PAIR_CLI_URL" -o "$PAIR_CLI_PATH"
  chmod +x "$PAIR_CLI_PATH"
}

# --------------------------
# Configure SSHD
# --------------------------
configure_sshd() {
  mkdir -p /var/run/sshd /etc/ssh

  cat <<EOF > "$SSHD_CONFIG_TARGET"
AuthorizedKeysCommand /opt/pair/pair verify %u %k %t
AuthorizedKeysCommandUser root

Port ${PORT}

PasswordAuthentication no
PermitEmptyPasswords no

Subsystem sftp /usr/libexec/openssh/sftp-server
EOF

  ssh-keygen -A || true
}

# --------------------------
# Configure supervisord
# --------------------------
configure_supervisord() {
  mkdir -p "$SUPERVISOR_CONF_DIR"

  cat <<EOF > "${SUPERVISOR_CONF_DIR}/sshd.conf"
[program:sshd]
command=/usr/sbin/sshd -D -e -f $SSHD_CONFIG_TARGET
autostart=true
autorestart=true
stderr_logfile=/var/log/sshd.err.log
stdout_logfile=/var/log/sshd.out.log
EOF

  cat <<EOF > "$SUPERVISORD_MAIN_CONF"
[supervisord]
nodaemon=false
user=root
logfile=/var/log/supervisord.log
pidfile=/var/run/supervisord.pid

[include]
files = $SUPERVISOR_CONF_DIR/*.conf
EOF
}

main() {
  detect_package_manager
  install_packages
  install_pair_cli
  configure_sshd
  configure_supervisord
}

main "$@"