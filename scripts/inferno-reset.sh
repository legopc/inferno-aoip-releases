#!/bin/bash
# inferno-reset.sh — Factory reset script for Inferno AoIP appliance
#
# Triggered by inferno-factory-reset.service on boot when marker file exists.
# Wipes all configuration and returns the appliance to first-boot defaults.
# The OS image (bootc layer) is NEVER touched.
#
# Do NOT call this script directly. It is invoked by the systemd unit only.

set -euo pipefail

MARKER="/var/lib/inferno/.factory-reset-pending"
LOG_TAG="inferno-factory-reset"

log() {
    echo "$1"
    systemd-cat -t "$LOG_TAG" -p info echo "$1" 2>/dev/null || true
}

log_err() {
    echo "ERROR: $1" >&2
    systemd-cat -t "$LOG_TAG" -p err echo "ERROR: $1" 2>/dev/null || true
}

# Safety: must be run as root
if [ "$(id -u)" -ne 0 ]; then
    log_err "Must run as root"
    exit 1
fi

# Safety: marker must exist (should always be true when called from systemd unit,
# but guard against accidental direct invocation)
if [ ! -f "$MARKER" ]; then
    log_err "Marker file not found — refusing to run without explicit reset request"
    exit 1
fi

log "=== Inferno factory reset starting ==="

# Read marker metadata for audit log
REQUESTED_AT=$(python3 -c "import json,sys; d=json.load(open('$MARKER')); print(d.get('requested_at','unknown'))" 2>/dev/null || echo "unknown")
REQUESTED_BY=$(python3 -c "import json,sys; d=json.load(open('$MARKER')); print(d.get('requested_by','unknown'))" 2>/dev/null || echo "unknown")
log "Reset requested at: $REQUESTED_AT by: $REQUESTED_BY"

# ── Step 1: Stop all inferno user services ────────────────────────────────────
log "Stopping inferno services..."
# Stop system-level inferno services
for svc in inferno-health-check statime-inferno; do
    systemctl stop "$svc" 2>/dev/null && log "  stopped $svc" || log "  $svc not running (ok)"
done
# Stop user services for the inferno user
if id inferno &>/dev/null; then
    INFERNO_UID=$(id -u inferno)
    for svc in librespot librespot-watchdog inferno-bridge inferno-aux-tx inferno-aux-rx \
               inferno-aux-keepalive inferno-keepalive; do
        systemctl --user -M "inferno@" stop "$svc" 2>/dev/null \
            && log "  stopped user/$svc" || log "  user/$svc not running (ok)"
    done
fi

# ── Step 2: Wipe Inferno configuration ───────────────────────────────────────
log "Wiping /etc/inferno/..."
if [ -d /etc/inferno ]; then
    rm -rf /etc/inferno
fi
mkdir -p /etc/inferno
chmod 755 /etc/inferno
log "  /etc/inferno wiped and recreated"

# ── Step 3: Reset hostname ────────────────────────────────────────────────────
log "Resetting hostname to inferno-appliance..."
hostnamectl set-hostname "inferno-appliance" 2>/dev/null || \
    echo "inferno-appliance" > /etc/hostname
log "  hostname set to inferno-appliance"

# ── Step 4: Wipe NetworkManager overrides ────────────────────────────────────
# IMPORTANT: Only remove manually-created override connections, NOT the default
# DHCP/autoconnect profile. The device must remain reachable after reset.
# We remove any connection files that were NOT part of the base OS image.
# Base image creates no NM connections; anything in system-connections was added post-install.
log "Wiping NetworkManager override connections..."
NM_CONN_DIR="/etc/NetworkManager/system-connections"
if [ -d "$NM_CONN_DIR" ]; then
    CONNECTION_COUNT=$(find "$NM_CONN_DIR" -name "*.nmconnection" -o -name "*.conf" | wc -l)
    if [ "$CONNECTION_COUNT" -gt 0 ]; then
        find "$NM_CONN_DIR" -type f \( -name "*.nmconnection" -o -name "*.conf" \) -delete
        log "  removed $CONNECTION_COUNT NetworkManager connection files"
        # Reload NM so it falls back to DHCP autodiscovery
        nmcli connection reload 2>/dev/null || true
    else
        log "  no override connections found (ok)"
    fi
fi

# ── Step 5: Reset local user passwords ───────────────────────────────────────
# Remove passwords from local accounts — first-boot setup must set new ones.
# The bootc image ships a locked root by default; we restore that state.
log "Resetting local user passwords..."
for user in root inferno admin; do
    if id "$user" &>/dev/null; then
        # Lock password (disables password login, SSH keys still work)
        passwd -l "$user" 2>/dev/null && log "  locked password for $user" || true
        # Expire: force password change on next login
        chage -d 0 "$user" 2>/dev/null || true
    fi
done

# ── Step 6: Regenerate SSH host keys ─────────────────────────────────────────
log "Removing SSH host keys (will regenerate on next boot)..."
rm -f /etc/ssh/ssh_host_*
log "  SSH host keys removed — sshd will regenerate on next boot"

# ── Step 7: Wipe inferno state and cache ─────────────────────────────────────
log "Wiping /var/lib/inferno state..."
# Remove everything EXCEPT the marker file itself (we remove it last)
find /var/lib/inferno -mindepth 1 ! -name ".factory-reset-pending" -delete 2>/dev/null || true
log "  /var/lib/inferno state wiped"

# ── Step 8: Remove marker file (point of no return) ──────────────────────────
log "Removing factory reset marker..."
rm -f "$MARKER"
log "  marker removed"

log "=== Factory reset complete — rebooting to clean first-boot state ==="
systemd-cat -t "$LOG_TAG" -p info echo "FACTORY_RESET_COMPLETE requested_by=$REQUESTED_BY" 2>/dev/null || true

sync
sleep 1
systemctl reboot
