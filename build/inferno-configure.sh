#!/bin/bash
# inferno-configure.sh — Inferno AoIP first-boot node configuration
#
# Runs once at first boot via inferno-configure.service.
# Gated by absence of /etc/inferno.conf — idempotent (safe to re-run after deleting that file).
#
# What this does:
#   1. Detect NIC, IP, MAC
#   2. Derive DEVICE_ID and INFERNO_NAME from MAC
#   3. Substitute %%PLACEHOLDER%% values in config templates
#   4. Set up core user environment (~/bin, ~/.asoundrc, user systemd units)
#   5. Enable linger + user services for core
#   6. Write /etc/inferno.conf (the sentinel — prevents re-run)
#
# To force reconfigure (e.g. after NIC change): rm /etc/inferno.conf && reboot

set -euo pipefail
exec > >(tee -a /var/log/inferno-configure.log) 2>&1

echo "=== Inferno AoIP first-boot configuration: $(date -Iseconds) ==="

# ── Detect NIC ─────────────────────────────────────────────────────────────────
INFERNO_NIC=$(ip -o link show | awk '$2 != "lo:" && $2 !~ /^(docker|br-|veth|tun|tap)/ {print $2; exit}' | tr -d ':')
if [ -z "${INFERNO_NIC}" ]; then
    echo "ERROR: Could not detect a non-loopback NIC. Waiting for network..."
    sleep 10
    INFERNO_NIC=$(ip -o link show | awk '$2 != "lo:" {print $2; exit}' | tr -d ':')
fi
echo "NIC: ${INFERNO_NIC}"

# Wait for IPv4 address (may take a moment after link-up)
for i in $(seq 1 30); do
    INFERNO_INTERFACE=$(ip -4 addr show "${INFERNO_NIC}" | awk '/inet / {print $2}' | cut -d/ -f1)
    [ -n "${INFERNO_INTERFACE}" ] && break
    echo "  waiting for IP on ${INFERNO_NIC} (${i}/30)..."
    sleep 2
done

if [ -z "${INFERNO_INTERFACE}" ]; then
    echo "WARNING: No IPv4 on ${INFERNO_NIC} — using 0.0.0.0 (will need manual fix)"
    INFERNO_INTERFACE="0.0.0.0"
fi
echo "IP: ${INFERNO_INTERFACE}"

# ── Derive identifiers from MAC ────────────────────────────────────────────────
MAC=$(cat "/sys/class/net/${INFERNO_NIC}/address")
MAC_CLEAN=$(echo "${MAC}" | tr -d ':')
INFERNO_DEVICE_ID="${MAC_CLEAN}0000"
INFERNO_DEVICE_ID_TX="${MAC_CLEAN}0001"
INFERNO_DEVICE_ID_RX="${MAC_CLEAN}0002"

# Node name from last 3 MAC octets (e.g. BC:24:11:73:CF:6B → Inferno-73CF6B)
MAC_SUFFIX=$(echo "${MAC_CLEAN}" | tail -c 7)  # last 6 hex chars
INFERNO_NAME="Inferno-${MAC_SUFFIX^^}"

PLUGIN_PATH="/var/lib/inferno/lib/libasound_module_pcm_inferno.so"

echo "MAC: ${MAC}  DEVICE_ID: ${INFERNO_DEVICE_ID}  NAME: ${INFERNO_NAME}"

# ── Template substitution helper ───────────────────────────────────────────────
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
        "${src}" > "${dst}"
}

# ── System config files (from templates) ───────────────────────────────────────
echo "Writing system config files..."
substitute /etc/inferno/statime-inferno.toml.template /etc/statime-inferno.toml
substitute /etc/inferno/99-inferno.conf.template      /etc/alsa/conf.d/99-inferno.conf

# ── Set hostname ───────────────────────────────────────────────────────────────
HOSTNAME="inferno-$(echo "${MAC_SUFFIX}" | tr '[:upper:]' '[:lower:]')"
hostnamectl set-hostname "${HOSTNAME}"
echo "Hostname: ${HOSTNAME}"

# ── core user environment ──────────────────────────────────────────────────────
CORE_HOME=/var/home/core
CORE_UID=$(id -u core)

echo "Setting up core user environment..."

# User ~/bin directory (scripts called by systemd units)
mkdir -p "${CORE_HOME}/bin"
cp /etc/inferno/inferno-sink-event  "${CORE_HOME}/bin/"
cp /etc/inferno/librespot-watchdog  "${CORE_HOME}/bin/"
chmod +x "${CORE_HOME}/bin/inferno-sink-event" "${CORE_HOME}/bin/librespot-watchdog"

# ~/.asoundrc (with substituted ALSA device names)
substitute /etc/inferno/asoundrc.spotify.template "${CORE_HOME}/.asoundrc"

# User systemd units
SYSTEMD_USER="${CORE_HOME}/.config/systemd/user"
mkdir -p "${SYSTEMD_USER}"

# Static units (no placeholders)
for unit in inferno-bridge inferno-keepalive inferno-web librespot-watchdog; do
    cp "/etc/inferno/systemd/user/${unit}.service" "${SYSTEMD_USER}/"
done

# librespot.service has %%INFERNO_NAME%% placeholder
substitute /etc/inferno/systemd/user/librespot.service "${SYSTEMD_USER}/librespot.service"

chown -R core:core "${CORE_HOME}"

# ── Enable linger for core (user services start at boot, not just at login) ───
loginctl enable-linger core

# Wait for the core user's systemd instance to start (up to 30s)
echo "Waiting for core user systemd instance..."
for i in $(seq 1 30); do
    [ -d "/run/user/${CORE_UID}/systemd" ] && break
    sleep 1
done

# ── Enable user services ───────────────────────────────────────────────────────
echo "Enabling user services for core..."
for svc in inferno-bridge inferno-keepalive librespot librespot-watchdog inferno-web; do
    sudo -u core XDG_RUNTIME_DIR="/run/user/${CORE_UID}" \
        systemctl --user enable "${svc}.service" 2>/dev/null \
        && echo "  enabled: ${svc}" \
        || echo "  WARNING: could not enable ${svc} — will try on next reboot"
done

# ── Write /etc/inferno.conf (sentinel — prevents re-run) ──────────────────────
cat > /etc/inferno.conf <<EOF
# Inferno AoIP node configuration
# Written by inferno-configure.sh on $(date -Iseconds)
# To reconfigure: rm /etc/inferno.conf && reboot

INFERNO_MODE=spotify
INFERNO_NAME=${INFERNO_NAME}
INFERNO_NIC=${INFERNO_NIC}
INFERNO_INTERFACE=${INFERNO_INTERFACE}
INFERNO_DEVICE_ID=${INFERNO_DEVICE_ID}
INFERNO_DEVICE_ID_TX=${INFERNO_DEVICE_ID_TX}
INFERNO_DEVICE_ID_RX=${INFERNO_DEVICE_ID_RX}
EOF

echo "=== Inferno AoIP configuration complete ==="
echo "    Name:      ${INFERNO_NAME}"
echo "    NIC:       ${INFERNO_NIC} (${INFERNO_INTERFACE})"
echo "    DEVICE_ID: ${INFERNO_DEVICE_ID}"
echo "    Reboot to start all services."
