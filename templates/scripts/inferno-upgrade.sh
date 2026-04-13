#!/bin/bash
# inferno-upgrade.sh — run every boot to sync user service templates
# Ensures bootc upgrades propagate updated service files to /var/home/core/.config/systemd/user/
# Reads /etc/inferno.conf for substitution values.
set -euo pipefail

TEMPLATE_DIR="/etc/inferno/systemd/user"
CORE_HOME="/var/home/core"
SYSTEMD_USER="${CORE_HOME}/.config/systemd/user"
CORE_UID=1000

# Load node config for placeholder substitution
[ -f /etc/inferno.conf ] || { echo "inferno.conf missing — skipping upgrade"; exit 0; }
# shellcheck disable=SC1091
source /etc/inferno.conf

INFERNO_NAME="${INFERNO_NAME:-inferno}"
INFERNO_AUDIO_CARD="${INFERNO_AUDIO_CARD:-hw:0}"
INFERNO_NIC="${INFERNO_NIC:-eth0}"
INFERNO_DEVICE_ID="${INFERNO_DEVICE_ID:-}"
INFERNO_DEVICE_ID_TX="${INFERNO_DEVICE_ID_TX:-}"
INFERNO_DEVICE_ID_RX="${INFERNO_DEVICE_ID_RX:-}"
INFERNO_INTERFACE="${INFERNO_INTERFACE:-}"
INFERNO_PLUGIN_PATH="${INFERNO_PLUGIN_PATH:-/usr/lib64/alsa-lib/libasound_module_pcm_inferno.so}"

mkdir -p "${SYSTEMD_USER}"

changed=0

sub_template() {
    local src="$1" dst="$2"
    local tmp
    tmp=$(mktemp)
    sed \
        -e "s|%%INFERNO_NAME%%|${INFERNO_NAME}|g" \
        -e "s|%%INFERNO_NIC%%|${INFERNO_NIC}|g" \
        -e "s|%%INFERNO_INTERFACE%%|${INFERNO_INTERFACE}|g" \
        -e "s|%%INFERNO_DEVICE_ID%%|${INFERNO_DEVICE_ID}|g" \
        -e "s|%%INFERNO_DEVICE_ID_TX%%|${INFERNO_DEVICE_ID_TX}|g" \
        -e "s|%%INFERNO_DEVICE_ID_RX%%|${INFERNO_DEVICE_ID_RX}|g" \
        -e "s|%%INFERNO_PLUGIN_PATH%%|${INFERNO_PLUGIN_PATH}|g" \
        -e "s|%%INFERNO_AUDIO_CARD%%|${INFERNO_AUDIO_CARD}|g" \
        "${src}" > "${tmp}"

    if ! diff -q "${tmp}" "${dst}" &>/dev/null 2>&1; then
        cp -f "${tmp}" "${dst}"
        echo "  updated: $(basename "${dst}")"
        changed=1
    fi
    rm -f "${tmp}"
}

copy_if_changed() {
    local src="$1" dst="$2"
    if ! diff -q "${src}" "${dst}" &>/dev/null 2>&1; then
        cp -f "${src}" "${dst}"
        echo "  updated: $(basename "${dst}")"
        changed=1
    fi
}

echo "inferno-upgrade: syncing user service templates..."

# Static service files (no placeholders)
for unit in inferno-bridge inferno-keepalive librespot-watchdog inferno-aux-keepalive; do
    src="${TEMPLATE_DIR}/${unit}.service"
    dst="${SYSTEMD_USER}/${unit}.service"
    [ -f "${src}" ] || continue
    copy_if_changed "${src}" "${dst}"
done

# Service files with placeholders
for unit in librespot inferno-aux-tx inferno-aux-rx; do
    src="${TEMPLATE_DIR}/${unit}.service"
    dst="${SYSTEMD_USER}/${unit}.service"
    [ -f "${src}" ] || continue
    sub_template "${src}" "${dst}"
done

chown -R core:core "${SYSTEMD_USER}"
restorecon -Rv /var/home/core/ 2>/dev/null || true

if [ "${changed}" -eq 1 ]; then
    echo "inferno-upgrade: files changed — reloading user daemon"
    # Reload user daemon if lingering session is already active
    if [ -d "/run/user/${CORE_UID}/systemd" ]; then
        sudo -u core XDG_RUNTIME_DIR="/run/user/${CORE_UID}" systemctl --user daemon-reload || true
    fi
else
    echo "inferno-upgrade: all service files up to date"
fi
