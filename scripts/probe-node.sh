#!/usr/bin/env bash
# probe-node.sh — Inferno AoIP Hardware Probe
# Run this on any Linux system (live ISO, existing OS, SSH) before installing
# the Inferno Appliance to verify hardware compatibility and collect variables.
#
# Usage:
#   bash probe-node.sh
#   curl -s https://raw.githubusercontent.com/legopc/inferno-aoip-releases/main/scripts/probe-node.sh | bash

set -euo pipefail

BOLD='\033[1m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo ""
echo -e "${BOLD}=== Inferno AoIP Node Probe ===${NC}"
echo ""

# ── UEFI ──────────────────────────────────────────────────────────────────────
echo -e "${BOLD}--- Boot mode ---${NC}"
if [ -d /sys/firmware/efi ]; then
    echo -e "  ${GREEN}UEFI${NC} ✓  (required for bootc appliance)"
else
    echo -e "  ${RED}Legacy BIOS${NC}  ✗  (bootc appliance requires UEFI)"
fi

# ── Network interfaces ─────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}--- Network interfaces ---${NC}"
DANTE_NIC=""
while IFS= read -r line; do
    IDX=$(echo "$line" | awk '{print $1}' | tr -d ':')
    IFACE=$(echo "$line" | awk '{print $2}' | tr -d ':')
    STATE=$(echo "$line" | grep -oP '(?<=state )\w+' || echo "UNKNOWN")
    MAC=$(cat "/sys/class/net/${IFACE}/address" 2>/dev/null || echo "??:??:??:??:??:??")
    DRIVER=$(readlink "/sys/class/net/${IFACE}/device/driver" 2>/dev/null | xargs basename 2>/dev/null || echo "n/a")
    SPEED=$(cat "/sys/class/net/${IFACE}/speed" 2>/dev/null || echo "?")

    # Classify
    if [[ "$IFACE" == "lo" ]]; then continue; fi
    if [[ "$IFACE" =~ ^(docker|br-|veth|tun|tap|virbr) ]]; then
        echo "  ${IFACE}  [virtual/container — skipped]"
        continue
    fi
    if [[ "$IFACE" =~ ^wl ]]; then
        echo "  ${IFACE}  MAC=${MAC}  driver=${DRIVER}  [WiFi — excluded from Dante]"
        continue
    fi

    # Wired candidate
    LABEL=""
    if [ "$STATE" = "UP" ] && [ -z "$DANTE_NIC" ]; then
        DANTE_NIC="$IFACE"
        DANTE_MAC="$MAC"
        LABEL="${GREEN}[RECOMMENDED DANTE NIC]${NC}"
    elif [ "$STATE" = "UP" ]; then
        LABEL="${YELLOW}[wired, link up — secondary]${NC}"
    else
        LABEL="[wired, no link]"
    fi
    echo -e "  ${IFACE}  MAC=${MAC}  driver=${DRIVER}  speed=${SPEED}Mb/s  state=${STATE}  ${LABEL}"
done < <(ip -o link show)

if [ -z "$DANTE_NIC" ]; then
    echo -e "  ${RED}No wired NIC with link found!${NC} Check cable before installing."
    DANTE_NIC="(none detected)"
    DANTE_MAC="??"
fi

# ── Audio ──────────────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}--- Audio ---${NC}"
if modinfo snd-aloop &>/dev/null; then
    echo -e "  snd-aloop: ${GREEN}available${NC} ✓  (will be loaded by appliance at card index 5)"
else
    echo -e "  snd-aloop: ${RED}not found${NC}  (check kernel modules)"
fi
if aplay -l &>/dev/null 2>&1; then
    CARDS=$(aplay -l 2>/dev/null | grep "^card" | sed 's/^/    /')
    if [ -n "$CARDS" ]; then
        echo "  Physical sound cards detected:"
        echo "$CARDS"
        echo "  (ok — appliance uses snd-aloop for Dante, ignores physical cards)"
    else
        echo "  No physical sound cards  (ok for spotify mode)"
    fi
else
    echo "  aplay not available  (ok — will be installed by appliance)"
fi

# ── Storage ───────────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}--- Storage ---${NC}"
lsblk -d -o NAME,SIZE,ROTA,TYPE 2>/dev/null | grep disk | grep -v zram | while read -r line; do
    NAME=$(echo "$line" | awk '{print $1}')
    SIZE=$(echo "$line" | awk '{print $2}')
    ROTA=$(echo "$line" | awk '{print $3}')
    TYPE=$([ "$ROTA" = "0" ] && echo "SSD/NVMe" || echo "HDD")
    echo "  /dev/${NAME}  ${SIZE}  ${TYPE}  [install target]"
done
echo "  NOTE: anaconda will wipe the first disk — back up any data first!"

# ── CPU / RAM ─────────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}--- Hardware ---${NC}"
CPU=$(grep "model name" /proc/cpuinfo 2>/dev/null | head -1 | cut -d: -f2 | xargs)
RAM=$(free -h 2>/dev/null | awk '/^Mem:/ {print $2}')
echo "  CPU: ${CPU:-unknown}"
echo "  RAM: ${RAM:-unknown}  (minimum 2GB required)"

# ── Suggested config ──────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}--- Suggested inferno.conf (auto-detected) ---${NC}"
if [ -n "$DANTE_NIC" ] && [ "$DANTE_NIC" != "(none detected)" ]; then
    MAC_CLEAN=$(echo "$DANTE_MAC" | tr -d ':')
    MAC_SUFFIX=$(echo "$MAC_CLEAN" | tail -c 7)
    NAME="Inferno-${MAC_SUFFIX^^}"
    echo "  INFERNO_MODE=spotify        # hardcoded in appliance"
    echo "  INFERNO_NIC=auto            # auto-detection will pick ${DANTE_NIC}"
    echo "  INFERNO_NAME=${NAME}  # derived from MAC — will be the Dante TX name"
    echo "  (all other values derived automatically from MAC at first boot)"
else
    echo "  ${RED}Cannot suggest config — no wired NIC detected${NC}"
fi

echo ""
echo -e "${BOLD}--- Summary ---${NC}"
[ -d /sys/firmware/efi ] && echo -e "  UEFI: ${GREEN}YES${NC}" || echo -e "  UEFI: ${RED}NO${NC}"
echo -e "  Dante NIC: ${GREEN}${DANTE_NIC}${NC}"
if modinfo snd-aloop &>/dev/null; then
    echo -e "  snd-aloop: ${GREEN}available${NC}"
else
    echo -e "  snd-aloop: ${YELLOW}check kernel${NC}"
fi
echo ""
