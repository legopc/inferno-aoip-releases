#!/bin/bash
# inferno-deploy.sh — Inferno AoIP first-boot deployment script
#
# Runs once on first boot (sentinel: /var/lib/inferno/.deployed).
# To re-run (e.g. to update binaries): rm /var/lib/inferno/.deployed && reboot
#
# Configuration is read from /etc/inferno.conf (written by Ignition JSON).
# INFERNO_NIC=auto means the script auto-detects the first non-loopback NIC.
#
# Usage:
#   Automatic: triggered by inferno-firstboot.service (oneshot) at first boot
#   Manual:    sudo bash /var/lib/inferno/bin/inferno-deploy.sh

set -euo pipefail

RELEASES_BASE="https://github.com/legopc/inferno-aoip-releases/releases/latest/download"
TARBALL_NAME="inferno-aoip.tar.gz"
INSTALL_DIR="/var/lib/inferno"
BIN_DIR="${INSTALL_DIR}/bin"
PLUGIN_DIR="${INSTALL_DIR}/alsa-plugins"
SENTINEL="${INSTALL_DIR}/.deployed"
PACKAGES_SENTINEL="${INSTALL_DIR}/.packages-installed"
CONF="/etc/inferno.conf"
USER_HOME="/var/home/core"
USER_BIN="${USER_HOME}/bin"
SYSTEMD_USER="${USER_HOME}/.config/systemd/user"
SYSTEMD_SYSTEM="/etc/systemd/system"

# ── Already deployed? ──────────────────────────────────────────────────────────
if [ -f "${SENTINEL}" ]; then
    echo "inferno-deploy: already deployed."
    echo "  To re-run: rm ${SENTINEL} && reboot"
    exit 0
fi

echo ""
echo "╔══════════════════════════════════════════╗"
echo "║       Inferno AoIP — First Boot Deploy   ║"
echo "╚══════════════════════════════════════════╝"
echo ""

# ── Load config ────────────────────────────────────────────────────────────────
if [ ! -f "${CONF}" ]; then
    echo "ERROR: ${CONF} not found."
    echo "  This file should have been written by the Ignition JSON."
    echo "  If deploying manually, create it first (see inferno-aoip-releases README)."
    exit 1
fi

# shellcheck source=/dev/null
source "${CONF}"

# ── Phase 1: Install required RPM packages via rpm-ostree ─────────────────────
# Fedora IoT's base OSTree commit doesn't include Cockpit or ALSA utils.
# We install them via rpm-ostree package layering on first boot, then reboot
# to activate. Phase 2 (actual Inferno deployment) runs after that reboot.
# The firstboot.service re-triggers because .deployed doesn't exist yet.
#
# NOTE: osbuild cannot build a custom iot-commit with these packages pre-baked
# because parsec/dbus-parsec (required by the iot-commit image type) don't exist
# as standalone RPMs — they're only in Fedora's internal OSTree build pipeline.
# The provisioner ISO + rpm-ostree install approach is the correct workaround.
if [ ! -f "${PACKAGES_SENTINEL}" ]; then
    echo "Phase 1: Installing required packages via rpm-ostree..."
    echo "  (This requires a reboot — Phase 2 will run automatically after it)"
    $SUDO rpm-ostree install --idempotent \
        cockpit-system cockpit-ostree cockpit-files \
        alsa-lib alsa-utils alsa-plugins-speex speexdsp \
        avahi avahi-tools nss-mdns \
        python3 curl
    $SUDO mkdir -p "${INSTALL_DIR}"
    $SUDO touch "${PACKAGES_SENTINEL}"
    echo "Packages staged. Rebooting to activate..."
    sleep 3
    $SUDO systemctl reboot
    exit 0
fi
echo "Phase 1 already done (packages installed). Proceeding to Phase 2..."
echo ""

# ── Auto-detect NIC if set to 'auto' ──────────────────────────────────────────
if [ "${INFERNO_NIC:-auto}" = "auto" ]; then
    INFERNO_NIC=$(ip -o link show | awk '$2 != "lo:" {print $2; exit}' | tr -d ':')
    echo "Auto-detected NIC: ${INFERNO_NIC}"
fi

# ── Derive IP address from NIC ─────────────────────────────────────────────────
INFERNO_INTERFACE=$(ip -4 addr show "${INFERNO_NIC}" | awk '/inet / {print $2}' | cut -d/ -f1)
if [ -z "${INFERNO_INTERFACE}" ]; then
    echo "ERROR: Could not get IPv4 address for NIC ${INFERNO_NIC}."
    echo "  Ensure the network is up and the NIC is correct."
    exit 1
fi

# ── Derive DEVICE_ID from MAC ──────────────────────────────────────────────────
MAC=$(cat /sys/class/net/"${INFERNO_NIC}"/address)
INFERNO_DEVICE_ID=$(echo "${MAC}" | tr -d ':')0000
INFERNO_DEVICE_ID_TX=$(echo "${MAC}" | tr -d ':')0001
INFERNO_DEVICE_ID_RX=$(echo "${MAC}" | tr -d ':')0002

echo "Mode:          ${INFERNO_MODE}"
echo "Device name:   ${INFERNO_NAME}"
echo "NIC:           ${INFERNO_NIC} (${INFERNO_INTERFACE})"
echo "MAC:           ${MAC}"
echo "DEVICE_ID:     ${INFERNO_DEVICE_ID}"
[ "${INFERNO_MODE}" = "aux" ] && echo "DEVICE_ID TX:  ${INFERNO_DEVICE_ID_TX}"
[ "${INFERNO_MODE}" = "aux" ] && echo "DEVICE_ID RX:  ${INFERNO_DEVICE_ID_RX}"
echo ""

# ── Paths ──────────────────────────────────────────────────────────────────────
PLUGIN_PATH="${PLUGIN_DIR}/libasound_module_pcm_inferno.so"
INFERNO_MODE="${INFERNO_MODE:-spotify}"
AUDIO_CARD="${INFERNO_AUDIO_CARD:-0}"

# ── Privilege helper — works whether run as root (firstboot) or core (manual) ──
SUDO=""
[ "$(id -u)" -ne 0 ] && SUDO="sudo"

# ── Create directories ─────────────────────────────────────────────────────────
$SUDO mkdir -p "${BIN_DIR}" "${PLUGIN_DIR}"
mkdir -p "${USER_BIN}" "${SYSTEMD_USER}"
$SUDO mkdir -p /etc/alsa/conf.d /etc/statime /var/lib/inferno
$SUDO chown -R core:core "${USER_HOME}" /var/lib/inferno

# ── Download release tarball ───────────────────────────────────────────────────
# Set INFERNO_LOCAL_TARBALL=/path/to/inferno-aoip.tar.gz to skip download (for testing).
if [ -n "${INFERNO_LOCAL_TARBALL:-}" ]; then
    echo "Using local tarball: ${INFERNO_LOCAL_TARBALL}"
    if [ "${INFERNO_LOCAL_TARBALL}" != "/tmp/${TARBALL_NAME}" ]; then
        cp "${INFERNO_LOCAL_TARBALL}" "/tmp/${TARBALL_NAME}"
    fi
    sha256sum "/tmp/${TARBALL_NAME}" > "/tmp/${TARBALL_NAME}.sha256"
else
    echo "Downloading ${TARBALL_NAME} from GitHub Releases..."
    curl -fsSL "${RELEASES_BASE}/${TARBALL_NAME}" -o "/tmp/${TARBALL_NAME}"
    curl -fsSL "${RELEASES_BASE}/${TARBALL_NAME}.sha256" -o "/tmp/${TARBALL_NAME}.sha256"
fi

echo "Verifying checksum..."
(cd /tmp && sha256sum -c "${TARBALL_NAME}.sha256")

echo "Extracting..."
tar -xzf "/tmp/${TARBALL_NAME}" -C /tmp/

# ── Stop existing services before overwriting binaries ────────────────────────
echo "Stopping existing Inferno services..."
$SUDO systemctl stop statime-inferno.service 2>/dev/null || true
CORE_UID=$(id -u core 2>/dev/null || echo 1000)
for SVC in librespot librespot-watchdog inferno-bridge inferno-keepalive \
           inferno-aux-tx inferno-aux-rx inferno-aux-keepalive inferno-web; do
    $SUDO -u core XDG_RUNTIME_DIR=/run/user/${CORE_UID} \
        systemctl --user stop "${SVC}.service" 2>/dev/null || true
done
sleep 2

# ── Install binaries ───────────────────────────────────────────────────────────
echo "Installing binaries..."
$SUDO cp /tmp/inferno-aoip/bin/statime       "${BIN_DIR}/"
$SUDO cp /tmp/inferno-aoip/bin/librespot     "${BIN_DIR}/"
$SUDO cp /tmp/inferno-aoip/lib/libasound_module_pcm_inferno.so "${PLUGIN_DIR}/"
$SUDO cp /tmp/inferno-aoip/scripts/inferno-web.py "${BIN_DIR}/"
cp /tmp/inferno-aoip/templates/inferno-sink-event  "${USER_BIN}/"
cp /tmp/inferno-aoip/templates/librespot-watchdog  "${USER_BIN}/"
$SUDO chmod +x "${BIN_DIR}/statime" "${BIN_DIR}/librespot"
chmod +x "${USER_BIN}/inferno-sink-event" "${USER_BIN}/librespot-watchdog"
$SUDO chown core:core "${USER_BIN}/inferno-sink-event" "${USER_BIN}/librespot-watchdog"

# ── Helper: substitute placeholders in a file ──────────────────────────────────
substitute() {
    local src="$1" dst="$2"
    sed \
        -e "s|%%INFERNO_NAME%%|${INFERNO_NAME}|g" \
        -e "s|%%INFERNO_NIC%%|${INFERNO_NIC}|g" \
        -e "s|%%INFERNO_INTERFACE%%|${INFERNO_INTERFACE}|g" \
        -e "s|%%INFERNO_DEVICE_ID%%|${INFERNO_DEVICE_ID}|g" \
        -e "s|%%INFERNO_DEVICE_ID_TX%%|${INFERNO_DEVICE_ID_TX}|g" \
        -e "s|%%INFERNO_DEVICE_ID_RX%%|${INFERNO_DEVICE_ID_RX}|g" \
        -e "s|%%INFERNO_PLUGIN_PATH%%|${PLUGIN_PATH}|g" \
        -e "s|%%INFERNO_AUDIO_CARD%%|${AUDIO_CARD}|g" \
        "${src}" > "${dst}"
}

TMPL="/tmp/inferno-aoip/templates"

# ── Deploy PTP config ──────────────────────────────────────────────────────────
substitute "${TMPL}/inferno-ptpv1.toml" /tmp/statime-inferno.toml
$SUDO cp /tmp/statime-inferno.toml /etc/statime-inferno.toml

# ── Deploy ALSA global plugin registration ─────────────────────────────────────
substitute "${TMPL}/alsa/99-inferno.conf" /tmp/99-inferno.conf
$SUDO cp /tmp/99-inferno.conf /etc/alsa/conf.d/99-inferno.conf

# ── Deploy mode-specific ALSA config (~/.asoundrc) ────────────────────────────
if [ "${INFERNO_MODE}" = "spotify" ]; then
    substitute "${TMPL}/alsa/asoundrc.spotify" "${USER_HOME}/.asoundrc"
elif [ "${INFERNO_MODE}" = "aux" ]; then
    substitute "${TMPL}/alsa/asoundrc.aux" "${USER_HOME}/.asoundrc"
fi
$SUDO chown core:core "${USER_HOME}/.asoundrc"

# ── Deploy systemd SYSTEM unit (statime, runs as root) ────────────────────────
$SUDO cp "${TMPL}/systemd/system/statime-inferno.service" "${SYSTEMD_SYSTEM}/"
$SUDO systemctl daemon-reload
$SUDO systemctl enable statime-inferno.service

# ── Deploy systemd USER units ──────────────────────────────────────────────────
if [ "${INFERNO_MODE}" = "spotify" ]; then
    cp "${TMPL}/systemd/user/inferno-bridge.service"       "${SYSTEMD_USER}/"
    cp "${TMPL}/systemd/user/inferno-keepalive.service"    "${SYSTEMD_USER}/"
    cp "${TMPL}/systemd/user/librespot.service"             "${SYSTEMD_USER}/"
    substitute "${TMPL}/systemd/user/librespot.service" "${SYSTEMD_USER}/librespot.service"
    cp "${TMPL}/systemd/user/librespot-watchdog.service"   "${SYSTEMD_USER}/"
elif [ "${INFERNO_MODE}" = "aux" ]; then
    substitute "${TMPL}/systemd/user/inferno-aux-tx.service"       "${SYSTEMD_USER}/inferno-aux-tx.service"
    substitute "${TMPL}/systemd/user/inferno-aux-rx.service"       "${SYSTEMD_USER}/inferno-aux-rx.service"
    cp "${TMPL}/systemd/user/inferno-aux-keepalive.service"        "${SYSTEMD_USER}/"
fi
cp "${TMPL}/systemd/user/inferno-web.service" "${SYSTEMD_USER}/"
chown -R core:core "${SYSTEMD_USER}"

# ── Configure snd-aloop (pinned to card 5 to avoid card number conflicts) ──────
if ! grep -q "snd-aloop" /etc/modprobe.d/snd-aloop.conf 2>/dev/null; then
    echo "options snd-aloop index=5" | $SUDO tee /etc/modprobe.d/snd-aloop.conf > /dev/null
fi
echo "snd-aloop" | $SUDO tee /etc/modules-load.d/snd-aloop.conf > /dev/null

# ── Serial console kernel arg (for headless/VM use) ───────────────────────────
# Fedora IoT already outputs to display (tty0) by default.
# Append serial console so both display AND serial get boot output.
# This is idempotent — rpm-ostree kargs won't add a duplicate.
if ! $SUDO rpm-ostree kargs 2>/dev/null | grep -q "console=ttyS0"; then
    echo "Enabling serial console (ttyS0) kernel arg..."
    $SUDO rpm-ostree kargs --append=console=ttyS0,115200n8 2>/dev/null || \
        echo "  (rpm-ostree kargs failed — serial console not added; display console still works)"
fi

# ── Enable lingering for core user (allows user services at boot) ──────────────
$SUDO loginctl enable-linger core

# ── Enable user services ───────────────────────────────────────────────────────
echo "Enabling user services for core..."
CORE_UID=$(id -u core)

if [ "${INFERNO_MODE}" = "spotify" ]; then
    SERVICES=(inferno-bridge inferno-keepalive librespot librespot-watchdog)
elif [ "${INFERNO_MODE}" = "aux" ]; then
    SERVICES=(inferno-aux-tx inferno-aux-rx inferno-aux-keepalive)
fi
SERVICES+=(inferno-web)

for SVC in "${SERVICES[@]}"; do
    $SUDO -u core XDG_RUNTIME_DIR=/run/user/${CORE_UID} \
        systemctl --user enable "${SVC}.service" 2>/dev/null || true
done

# ── Clean up ───────────────────────────────────────────────────────────────────
rm -rf "/tmp/${TARBALL_NAME}" "/tmp/${TARBALL_NAME}.sha256" /tmp/inferno-aoip

# ── Write /etc/inferno.conf with all derived values ───────────────────────────
$SUDO tee "${CONF}" > /dev/null <<EOF
# Inferno AoIP node configuration
# Written by inferno-deploy.sh on $(date -Iseconds)
# To change config: edit this file, then restart services or reboot.
# To update binaries: rm ${SENTINEL} && reboot

INFERNO_MODE=${INFERNO_MODE}
INFERNO_NAME=${INFERNO_NAME}
INFERNO_NIC=${INFERNO_NIC}
INFERNO_INTERFACE=${INFERNO_INTERFACE}
INFERNO_DEVICE_ID=${INFERNO_DEVICE_ID}
INFERNO_DEVICE_ID_TX=${INFERNO_DEVICE_ID_TX}
INFERNO_DEVICE_ID_RX=${INFERNO_DEVICE_ID_RX}
INFERNO_AUDIO_CARD=${AUDIO_CARD}
EOF

# ── Sentinel ───────────────────────────────────────────────────────────────────
$SUDO mkdir -p "${INSTALL_DIR}"
$SUDO touch "${SENTINEL}"

echo ""
echo "╔══════════════════════════════════════════╗"
echo "║   Deployment complete — rebooting...     ║"
echo "╚══════════════════════════════════════════╝"
echo ""
echo ""
echo "  Cockpit web UI:    https://$(hostname -I | awk '{print $1}'):9090"
echo "  Inferno config UI: http://$(hostname -I | awk '{print $1}'):8080"
echo ""

# Reboot unless running in test mode
if [ -z "${INFERNO_NO_REBOOT:-}" ]; then
    sleep 5
    $SUDO systemctl reboot
else
    echo "(INFERNO_NO_REBOOT set — skipping reboot)"
fi
