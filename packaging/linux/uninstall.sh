#!/bin/bash
# Removes acme-manager. Keeps /var/lib/acme-manager (your accounts, db, keys) unless
# you pass --purge.  Run as root:  sudo ./uninstall.sh [--purge]
set -euo pipefail

INSTALL_DIR="/opt/acme-manager"
DATA_DIR="/var/lib/acme-manager"
UNIT="/etc/systemd/system/acme-manager.service"

if [[ $EUID -ne 0 ]]; then
    echo "Run as root (sudo ./uninstall.sh)." >&2
    exit 1
fi

if systemctl list-unit-files acme-manager.service &>/dev/null; then
    systemctl disable --now acme-manager 2>/dev/null || true
fi
rm -f "${UNIT}"
systemctl daemon-reload
rm -rf "${INSTALL_DIR}"

if [[ "${1:-}" == "--purge" ]]; then
    echo "purging data directory ${DATA_DIR}"
    rm -rf "${DATA_DIR}"
else
    echo "kept data directory ${DATA_DIR} (use --purge to remove accounts/db/keys)"
fi

echo "acme-manager removed."
