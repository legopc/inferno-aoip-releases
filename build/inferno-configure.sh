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
# Item 9: Allow override via INFERNO_NIC_OVERRIDE env var or /etc/inferno/nic-override file.
# Cockpit (or Ignition at provision time) can write /etc/inferno/nic-override to force a
# specific NIC. Lines starting with '#' are treated as comments and ignored.
INFERNO_NIC=""
if [ -n "${INFERNO_NIC_OVERRIDE:-}" ]; then
    INFERNO_NIC="${INFERNO_NIC_OVERRIDE}"
    echo "NIC: ${INFERNO_NIC} (from INFERNO_NIC_OVERRIDE env)"
elif [ -f /etc/inferno/nic-override ]; then
    INFERNO_NIC=$(grep -v '^#' /etc/inferno/nic-override | tr -d '[:space:]' | head -1)
    if [ -n "${INFERNO_NIC}" ]; then
        echo "NIC: ${INFERNO_NIC} (from /etc/inferno/nic-override)"
    else
        echo "NIC override file present but empty — falling through to auto-detect"
    fi
fi

# Auto-detect if not overridden: exclude loopback, Docker/container bridges,
# WiFi (wl*), virtual bridges (virbr). Dante requires wired Ethernet.
if [ -z "${INFERNO_NIC}" ]; then
    INFERNO_NIC=$(ip -o link show | awk '$2 != "lo:" && $2 !~ /^(docker|br-|veth|tun|tap|wl|virbr)/ {print $2; exit}' | tr -d ':')
    if [ -z "${INFERNO_NIC}" ]; then
        echo "ERROR: Could not detect a wired NIC. Available interfaces:"
        ip -o link show | awk '{print "  " $2, $9}' | tr -d ':'
        echo "Falling back to first non-loopback interface..."
        INFERNO_NIC=$(ip -o link show | awk '$2 != "lo:" {print $2; exit}' | tr -d ':')
    fi
    echo "NIC: ${INFERNO_NIC} (auto-detected)"
fi

# Item 8: Wait for NIC carrier (physical link-up) before polling for an IP address.
# A NIC with no cable plugged in will never get an IP — detect early and warn gracefully.
echo "Checking carrier on ${INFERNO_NIC}..."
for i in $(seq 1 15); do
    CARRIER=$(cat "/sys/class/net/${INFERNO_NIC}/carrier" 2>/dev/null || echo "0")
    [ "${CARRIER}" = "1" ] && break
    echo "  waiting for carrier on ${INFERNO_NIC} (${i}/15)..."
    sleep 2
done
CARRIER=$(cat "/sys/class/net/${INFERNO_NIC}/carrier" 2>/dev/null || echo "0")
if [ "${CARRIER}" != "1" ]; then
    echo "WARNING: No carrier on ${INFERNO_NIC} after 30s — cable unplugged? Continuing anyway."
fi

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

# Inferno's ALSA plugin validates BIND_IP as either an assigned IP address or
# an interface name. Bind by NIC name so first-boot DHCP timing cannot leave
# every Dante mode with the invalid fallback BIND_IP 0.0.0.0.
INFERNO_BIND="${INFERNO_NIC}"
echo "Dante bind: ${INFERNO_BIND}"

# Item 12: HW PTP capability check — detect hardware timestamping support on the Dante NIC.
# Hardware PTP yields ~100 ns offset; software-only yields ~500 µs (still fine for Dante).
# Result logged for operator visibility and written to /etc/inferno.conf for Cockpit to read.
INFERNO_HW_PTP="no"
INFERNO_CLOCK_PATH="/tmp/ptp-usrvclock"
PTP_DEV=$(ls "/sys/class/net/${INFERNO_NIC}/device/ptp/" 2>/dev/null | head -1 || true)
if [ -n "${PTP_DEV:-}" ] && [ -c "/dev/${PTP_DEV}" ]; then
    INFERNO_HW_PTP="yes"
    INFERNO_CLOCK_PATH="/dev/${PTP_DEV}"
    echo "HW PTP: hardware clock /dev/${PTP_DEV} on ${INFERNO_NIC} ✓  (~100 ns offset)"
elif command -v ethtool &>/dev/null; then
    HW_TS=$(ethtool -T "${INFERNO_NIC}" 2>/dev/null | grep -c "hardware-transmit" || true)
    if [ "${HW_TS}" -gt 0 ]; then
        INFERNO_HW_PTP="yes"
        echo "HW PTP: ${INFERNO_NIC} supports hardware timestamping (ethtool) ✓  (~100 ns offset)"
        # sysfs path didn't give us the device name; scan /sys/class/ptp/ by device symlink
        NIC_DEV=$(readlink -f "/sys/class/net/${INFERNO_NIC}/device" 2>/dev/null || true)
        if [ -n "$NIC_DEV" ]; then
            for _ptpd in /sys/class/ptp/ptp*/; do
                if [ "$(readlink -f "${_ptpd}device" 2>/dev/null)" = "$NIC_DEV" ]; then
                    PTP_DEV=$(basename "$_ptpd")
                    break
                fi
            done
        fi
        [ -n "$PTP_DEV" ] && echo "HW PTP device: /dev/${PTP_DEV}" || echo "HW PTP: device node not found, will use software clock"
        if [ -n "$PTP_DEV" ] && [ -c "/dev/${PTP_DEV}" ]; then
            INFERNO_CLOCK_PATH="/dev/${PTP_DEV}"
        else
            INFERNO_HW_PTP="no"
        fi
    else
        echo "HW PTP: ${INFERNO_NIC} — software PTP only  (~500 µs offset, Dante works fine)"
    fi
else
    echo "HW PTP: ethtool not available — assuming software PTP"
fi

# ── Derive identifiers from MAC ────────────────────────────────────────────────
MAC=$(cat "/sys/class/net/${INFERNO_NIC}/address")
MAC_CLEAN=$(echo "${MAC}" | tr -d ':')
INFERNO_DEVICE_ID="${MAC_CLEAN}0000"
INFERNO_DEVICE_ID_TX="${MAC_CLEAN}0001"
INFERNO_DEVICE_ID_RX="${MAC_CLEAN}0002"

# ── Detect physical audio card ─────────────────────────────────────────────────
# Pick the first non-Loopback, non-HDMI/DP card from aplay -l.
# Prefer USB cards (bus path contains /usb) over PCI/HDA-Intel cards.
INFERNO_AUDIO_CARD=$(aplay -l 2>/dev/null \
    | awk '/^card / && !/Loopback/ && !/HDMI/ && !/DisplayPort/ { match($0, /^card ([0-9]+)/, a); print a[1]; exit }')

if [[ -z "$INFERNO_AUDIO_CARD" ]]; then
    echo "WARNING: No external audio card found — AUX mode will be unavailable on this node."
    INFERNO_AUDIO_CARD=""
fi
echo "Audio card: ${INFERNO_AUDIO_CARD:-<none>}"

# ── Disable internal speakers and microphones on HDA-Intel cards ───────────────
# HDA-Intel = integrated PCI audio (Intel platforms). These cards have internal
# speakers and internal mics that should not be used by Inferno. Mute them via
# amixer so they don't accidentally receive or emit audio.
# This does NOT prevent the card from being used for HDMI or headphone jacks.
while IFS= read -r _card_idx; do
    [[ -z "$_card_idx" ]] && continue
    echo "Muting internal speaker/mic controls on HDA-Intel card ${_card_idx}..."
    for _ctrl in "Speaker" "Speaker Front" "Speaker Surround" \
                 "Headphone" \
                 "Internal Mic" "Internal Mic Boost" \
                 "Mic" "Mic Boost"; do
        amixer -c "${_card_idx}" sset "${_ctrl}" mute 2>/dev/null && \
            echo "  muted: ${_ctrl}" || true
    done
done < <(awk '/]: HDA-Intel/ { match($0, /^[[:space:]]*([0-9]+)/, a); print a[1] }' /proc/asound/cards)

# Node name from last 3 MAC octets (e.g. BC:24:11:73:CF:6B → Inferno-73CF6B)
MAC_SUFFIX=$(echo "${MAC_CLEAN}" | tail -c 7)  # last 6 hex chars
INFERNO_NAME="Inferno-${MAC_SUFFIX^^}"

PLUGIN_PATH="/usr/lib64/alsa-lib/libasound_module_pcm_inferno.so"

echo "MAC: ${MAC}  DEVICE_ID: ${INFERNO_DEVICE_ID}  NAME: ${INFERNO_NAME}"
echo "Inferno clock path: ${INFERNO_CLOCK_PATH}"

# ── Template substitution helper ───────────────────────────────────────────────
substitute() {
    local src="$1" dst="$2"
    sed \
        -e "s|%%INFERNO_NAME%%|${INFERNO_NAME}|g" \
        -e "s|%%INFERNO_NIC%%|${INFERNO_NIC}|g" \
        -e "s|%%INFERNO_INTERFACE%%|${INFERNO_INTERFACE}|g" \
        -e "s|%%INFERNO_BIND%%|${INFERNO_BIND}|g" \
        -e "s|%%INFERNO_CLOCK_PATH%%|${INFERNO_CLOCK_PATH}|g" \
        -e "s|%%INFERNO_DEVICE_ID%%|${INFERNO_DEVICE_ID}|g" \
        -e "s|%%INFERNO_DEVICE_ID_TX%%|${INFERNO_DEVICE_ID_TX}|g" \
        -e "s|%%INFERNO_DEVICE_ID_RX%%|${INFERNO_DEVICE_ID_RX}|g" \
        -e "s|%%INFERNO_PLUGIN_PATH%%|${PLUGIN_PATH}|g" \
        -e "s|%%INFERNO_AUDIO_CARD%%|${INFERNO_AUDIO_CARD}|g" \
        "${src}" > "${dst}"
}

# ── System config files (from templates) ───────────────────────────────────────
echo "Writing system config files..."
substitute /etc/inferno/statime-inferno.toml.template /etc/statime-inferno.toml
substitute /etc/inferno/99-inferno.conf.template      /etc/alsa/conf.d/99-inferno.conf

# ── Report hardware PTP clock status ────────────────────────────────────────
# The statime template uses hardware-clock = "auto" so statime can select the
# matching /dev/ptp* device at startup. Do not write device paths here; this
# statime build parses hardware-clock as a selector, not a filesystem path.
if [ "$INFERNO_HW_PTP" = "yes" ] && [ -n "${PTP_DEV:-}" ] && [ -c "/dev/${PTP_DEV}" ]; then
    echo "PTP: statime hardware-clock=auto will use detected /dev/${PTP_DEV}"
else
    echo "PTP: statime using software virtual clock"
fi
echo "PTP: Inferno CLOCK_PATH=${INFERNO_CLOCK_PATH}"

# ── Set hostname ───────────────────────────────────────────────────────────────
HOSTNAME="inferno-$(echo "${MAC_SUFFIX}" | tr '[:upper:]' '[:lower:]')"
hostnamectl set-hostname "${HOSTNAME}"
echo "Hostname: ${HOSTNAME}"

# ── Hardware watchdog (auto-detect — enable only if device is present) ────────
if [ -e /dev/watchdog ]; then
    mkdir -p /etc/systemd/system.conf.d
    printf '[Manager]\nRuntimeWatchdogSec=15\nRebootWatchdogSec=10min\n' \
        > /etc/systemd/system.conf.d/inferno-watchdog.conf
    echo "Hardware watchdog: enabled (RuntimeWatchdogSec=15s)"
else
    echo "Hardware watchdog: /dev/watchdog not present — skipping"
fi

# ── core user environment ──────────────────────────────────────────────────────
CORE_HOME=/var/home/core
CORE_UID=$(id -u core)

echo "Setting up core user environment..."

# User ~/bin directory (scripts called by systemd units)
mkdir -p "${CORE_HOME}/bin"
cp /etc/inferno/inferno-sink-event  "${CORE_HOME}/bin/"
cp /etc/inferno/librespot-watchdog  "${CORE_HOME}/bin/"
chmod +x "${CORE_HOME}/bin/inferno-sink-event" "${CORE_HOME}/bin/librespot-watchdog"

# ~/.asoundrc — spotify base + aux extension (both appended)
substitute /etc/inferno/asoundrc.spotify.template "${CORE_HOME}/.asoundrc"
# Append aux PCM definitions (inferno_aux_tx, inferno_aux_rx) — used when mode=aux-*
substitute /etc/inferno/asoundrc.aux.template /tmp/asoundrc.aux
cat /tmp/asoundrc.aux >> "${CORE_HOME}/.asoundrc"

# User systemd units
SYSTEMD_USER="${CORE_HOME}/.config/systemd/user"
mkdir -p "${SYSTEMD_USER}"

# Static units (no placeholders)
for unit in inferno-bridge inferno-keepalive librespot-watchdog; do
    cp "/etc/inferno/systemd/user/${unit}.service" "${SYSTEMD_USER}/"
done

# librespot.service has %%INFERNO_NAME%% placeholder
substitute /etc/inferno/systemd/user/librespot.service "${SYSTEMD_USER}/librespot.service"

# Aux service files have %%INFERNO_AUDIO_CARD%% placeholder (NOT enabled — Cockpit starts them)
substitute /etc/inferno/systemd/user/inferno-aux-tx.service "${SYSTEMD_USER}/inferno-aux-tx.service"
substitute /etc/inferno/systemd/user/inferno-aux-rx.service "${SYSTEMD_USER}/inferno-aux-rx.service"
cp "/etc/inferno/systemd/user/inferno-aux-keepalive.service" "${SYSTEMD_USER}/"

chown -R core:core "${CORE_HOME}"
restorecon -Rv /var/home/core/ 2>/dev/null || true

# ── Enable user services ───────────────────────────────────────────────────────
echo "Enabling user services for core..."
WANTS_DIR="${SYSTEMD_USER}/default.target.wants"
mkdir -p "${WANTS_DIR}"
for svc in inferno-bridge inferno-keepalive librespot librespot-watchdog; do
    if [ -f "${SYSTEMD_USER}/${svc}.service" ]; then
        ln -sfn "../${svc}.service" "${WANTS_DIR}/${svc}.service"
        echo "  enabled: ${svc}"
    else
        echo "  WARNING: ${svc}.service missing — will not start automatically"
    fi
done
chown -R core:core "${SYSTEMD_USER}"
restorecon -Rv /var/home/core/ 2>/dev/null || true

# ── Enable linger for core (user services start at boot, not just at login) ───
# Write the linger sentinel directly instead of calling loginctl from first boot.
# loginctl talks to logind, which can contend with Cockpit's forced password
# change session on fresh installs.
mkdir -p /var/lib/systemd/linger
touch /var/lib/systemd/linger/core
restorecon /var/lib/systemd/linger/core 2>/dev/null || true

# ── Item 14: Run hardware probe → /var/log/inferno-probe.log ──────────────────
# Captures NIC, carrier, HW PTP, audio, storage, CPU for operator diagnostics.
# (All configure output already captured in /var/log/inferno-configure.log above.)
if [ -x /usr/local/sbin/probe-node.sh ]; then
    echo "Running hardware probe → /var/log/inferno-probe.log ..."
    bash /usr/local/sbin/probe-node.sh > /var/log/inferno-probe.log 2>&1 || true
fi

# ── Item 15: Read image version ───────────────────────────────────────────────
INFERNO_VERSION=$(cat /etc/inferno-version 2>/dev/null || echo "unknown")
echo "Version: ${INFERNO_VERSION}"

# ── Write /etc/inferno.conf (sentinel — prevents re-run) ──────────────────────
cat > /etc/inferno.conf <<EOF
# Inferno AoIP node configuration
# Written by inferno-configure.sh on $(date -Iseconds)
# To reconfigure: rm /etc/inferno.conf && reboot

INFERNO_VERSION=${INFERNO_VERSION}
INFERNO_MODE=spotify
INFERNO_NAME=${INFERNO_NAME}
INFERNO_NIC=${INFERNO_NIC}
INFERNO_INTERFACE=${INFERNO_INTERFACE}
INFERNO_BIND=${INFERNO_BIND}
INFERNO_CLOCK_PATH=${INFERNO_CLOCK_PATH}
INFERNO_DEVICE_ID=${INFERNO_DEVICE_ID}
INFERNO_DEVICE_ID_TX=${INFERNO_DEVICE_ID_TX}
INFERNO_DEVICE_ID_RX=${INFERNO_DEVICE_ID_RX}
INFERNO_AUDIO_CARD=${INFERNO_AUDIO_CARD}
INFERNO_HW_PTP=${INFERNO_HW_PTP}
# SNMP agent configuration (configure via Cockpit SNMP tab)
INFERNO_SNMP_ENABLED=no
INFERNO_SNMP_V2_COMMUNITY=
INFERNO_SNMP_V3_USER=
INFERNO_SNMP_V3_AUTH_PASS=
INFERNO_SNMP_V3_PRIV_PASS=
EOF

# ── Item 15: Write /var/lib/inferno/version sentinel ─────────────────────────
mkdir -p /var/lib/inferno
echo "${INFERNO_VERSION}" > /var/lib/inferno/version

echo "=== Inferno AoIP configuration complete ==="
echo "    Name:      ${INFERNO_NAME}"
echo "    NIC:       ${INFERNO_NIC} (${INFERNO_INTERFACE})"
echo "    Bind:      ${INFERNO_BIND}"
echo "    Clock:     ${INFERNO_CLOCK_PATH}"
echo "    DEVICE_ID: ${INFERNO_DEVICE_ID}"
echo "    Rebooting in 5 seconds to start all services..."
sleep 5
systemctl reboot
