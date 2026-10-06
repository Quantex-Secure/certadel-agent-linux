#!/bin/bash
# acme-manager installer for Linux (Ubuntu, RHEL/Rocky/Alma, any systemd distro).
# Run as root from the extracted package directory:  sudo ./install.sh
set -euo pipefail

INSTALL_DIR="/opt/acme-manager"
DATA_DIR="/var/lib/acme-manager"
UNIT="/etc/systemd/system/acme-manager.service"
PORT="9443"

if [[ $EUID -ne 0 ]]; then
    echo "This installer must run as root (try: sudo ./install.sh)." >&2
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Check existence, not the executable bit: a tarball built on Windows can't carry
# +x, so the binary arrives non-executable. We chmod it after copying below.
if [[ ! -f "${SCRIPT_DIR}/app/AcmeManager.Service" ]]; then
    echo "Could not find app/AcmeManager.Service next to this script. Extract the full package first." >&2
    exit 1
fi

echo "==> Installing acme-manager"

# Stop the service if this is an upgrade, so files aren't in use.
if systemctl list-unit-files acme-manager.service &>/dev/null \
   && systemctl is-active --quiet acme-manager 2>/dev/null; then
    echo "    stopping running service for upgrade"
    systemctl stop acme-manager
fi

echo "    copying binaries to ${INSTALL_DIR}"
mkdir -p "${INSTALL_DIR}"
cp -a "${SCRIPT_DIR}/app/." "${INSTALL_DIR}/"
chmod 0755 "${INSTALL_DIR}/AcmeManager.Service"

echo "    creating data directory ${DATA_DIR}"
mkdir -p "${DATA_DIR}"
chmod 0700 "${DATA_DIR}"

echo "    installing systemd unit"
cp "${SCRIPT_DIR}/acme-manager.service" "${UNIT}"
systemctl daemon-reload

# Best-effort firewall opening — don't fail the install if neither tool is present.
if command -v ufw &>/dev/null && ufw status 2>/dev/null | grep -q "Status: active"; then
    echo "    opening ${PORT}/tcp (ufw)"
    ufw allow "${PORT}/tcp" >/dev/null || true
elif command -v firewall-cmd &>/dev/null && firewall-cmd --state &>/dev/null; then
    echo "    opening ${PORT}/tcp (firewalld)"
    firewall-cmd --permanent --add-port="${PORT}/tcp" >/dev/null || true
    firewall-cmd --reload >/dev/null || true
else
    echo "    note: no active ufw/firewalld detected - open ${PORT}/tcp manually if a firewall is in use"
fi

echo "    enabling and starting service"
systemctl enable acme-manager >/dev/null
systemctl restart acme-manager

sleep 2
if systemctl is-active --quiet acme-manager; then
    HOST="$(hostname -f 2>/dev/null || hostname)"
    echo ""
    echo "==> acme-manager is running."
    echo "    Web console:  https://${HOST}:${PORT}/   (self-signed until you issue a cert for this host)"
    echo "    Log in with a local Linux account (PAM). Logs: journalctl -u acme-manager -f"
else
    echo "" >&2
    echo "==> Service failed to start. Check: journalctl -u acme-manager -n 50 --no-pager" >&2
    exit 1
fi
