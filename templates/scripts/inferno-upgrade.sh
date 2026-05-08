#!/bin/bash
# inferno-upgrade.sh — run every boot to sync user service templates
# Ensures bootc upgrades propagate updated service files to /var/home/core/.config/systemd/user/
# Reads /etc/inferno.conf for substitution values.
set -euo pipefail

TEMPLATE_DIR="${INFERNO_TEMPLATE_DIR:-/etc/inferno/systemd/user}"
CORE_HOME="${INFERNO_CORE_HOME:-/var/home/core}"
SYSTEMD_USER="${INFERNO_SYSTEMD_USER:-${CORE_HOME}/.config/systemd/user}"
INFERNO_CONF="${INFERNO_CONF:-/etc/inferno.conf}"
SYS_CLASS_NET="${INFERNO_SYS_CLASS_NET:-/sys/class/net}"
DEV_ROOT="${INFERNO_DEV_ROOT:-/dev}"
CORE_UID=1000

# Load node config for placeholder substitution
[ -f "${INFERNO_CONF}" ] || { echo "inferno.conf missing — skipping upgrade"; exit 0; }
# shellcheck disable=SC1091
source "${INFERNO_CONF}"

INFERNO_NAME="${INFERNO_NAME:-inferno}"
INFERNO_AUDIO_CARD="${INFERNO_AUDIO_CARD:-hw:0}"
INFERNO_NIC="${INFERNO_NIC:-eth0}"
INFERNO_DEVICE_ID="${INFERNO_DEVICE_ID:-}"
INFERNO_DEVICE_ID_TX="${INFERNO_DEVICE_ID_TX:-}"
INFERNO_DEVICE_ID_RX="${INFERNO_DEVICE_ID_RX:-}"
INFERNO_INTERFACE="${INFERNO_INTERFACE:-}"
INFERNO_BIND="${INFERNO_BIND:-${INFERNO_NIC}}"
if [ "${INFERNO_BIND}" = "0.0.0.0" ]; then
    INFERNO_BIND="${INFERNO_NIC}"
fi
INFERNO_CLOCK_PATH="${INFERNO_CLOCK_PATH:-/tmp/ptp-usrvclock}"
if [ "${INFERNO_HW_PTP:-no}" = "yes" ] && [ "${INFERNO_CLOCK_PATH}" = "/tmp/ptp-usrvclock" ]; then
    PTP_DEV=$(ls "${SYS_CLASS_NET}/${INFERNO_NIC}/device/ptp/" 2>/dev/null | head -1 || true)
    if [ -n "${PTP_DEV:-}" ] && { [ -c "${DEV_ROOT}/${PTP_DEV}" ] || { [ "${INFERNO_ALLOW_NON_CHAR_PTP:-0}" = "1" ] && [ -e "${DEV_ROOT}/${PTP_DEV}" ]; }; }; then
        INFERNO_CLOCK_PATH="/dev/${PTP_DEV}"
    fi
fi
INFERNO_PLUGIN_PATH="${INFERNO_PLUGIN_PATH:-/usr/lib64/alsa-lib/libasound_module_pcm_inferno.so}"

sed_replacement() {
    printf '%s' "$1" | sed 's/[&\\]/\\&/g'
}

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
        -e "s|%%INFERNO_BIND%%|${INFERNO_BIND}|g" \
        -e "s|%%INFERNO_CLOCK_PATH%%|${INFERNO_CLOCK_PATH}|g" \
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

# Repair generated ALSA config from older images. v36 could write BIND_IP 0.0.0.0
# when DHCP was slow, and hardware-PTP nodes need direct /dev/ptpN CLOCK_PATH
# because statime does not emit usable usrvclock updates while acting as PTPv1 master.
ASOUNDRC="${CORE_HOME}/.asoundrc"
if [ -f "${ASOUNDRC}" ]; then
    if grep -q 'BIND_IP 0\.0\.0\.0' "${ASOUNDRC}"; then
        bind_repl=$(sed_replacement "${INFERNO_BIND}")
        sed -i -E "s/BIND_IP 0[.]0[.]0[.]0/BIND_IP ${bind_repl}/g" "${ASOUNDRC}"
        echo "  repaired: .asoundrc BIND_IP 0.0.0.0 -> ${INFERNO_BIND}"
        changed=1
    fi
    if [ "${INFERNO_CLOCK_PATH}" != "/tmp/ptp-usrvclock" ] && grep -q 'CLOCK_PATH /tmp/ptp-usrvclock' "${ASOUNDRC}"; then
        clock_repl=$(sed_replacement "${INFERNO_CLOCK_PATH}")
        sed -i -E "s#CLOCK_PATH /tmp/ptp-usrvclock#CLOCK_PATH ${clock_repl}#g" "${ASOUNDRC}"
        echo "  repaired: .asoundrc CLOCK_PATH -> ${INFERNO_CLOCK_PATH}"
        changed=1
    fi
fi

if [ "${INFERNO_SKIP_OWNERSHIP:-0}" != "1" ]; then
    chown -R core:core "${SYSTEMD_USER}"
    chown core:core "${CORE_HOME}/.asoundrc" 2>/dev/null || true
    restorecon -Rv "${CORE_HOME}/" 2>/dev/null || true
fi

if [ "${changed}" -eq 1 ]; then
    echo "inferno-upgrade: files changed — reloading user daemon"
    # Reload user daemon if lingering session is already active
    if [ "${INFERNO_SKIP_USER_RELOAD:-0}" != "1" ] && [ -d "/run/user/${CORE_UID}/systemd" ]; then
        sudo -u core XDG_RUNTIME_DIR="/run/user/${CORE_UID}" systemctl --user daemon-reload || true
    fi
else
    echo "inferno-upgrade: all service files up to date"
fi
