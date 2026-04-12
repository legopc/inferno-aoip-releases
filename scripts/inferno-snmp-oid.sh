#!/bin/bash
# inferno-snmp-oid.sh — SNMP OID data provider for Inferno AoIP
# Called by snmpd via 'extend' directives.  Prints a single line to stdout.
# Usage: inferno-snmp-oid.sh <key>

set -euo pipefail

KEY="${1:-}"

# Source inferno config (KEY=VALUE format)
if [ -f /etc/inferno.conf ]; then
    # shellcheck disable=SC1091
    . /etc/inferno.conf
fi

case "$KEY" in
    version)
        echo "${INFERNO_VERSION:-unknown}"
        ;;
    mode)
        echo "${INFERNO_MODE:-unknown}"
        ;;
    name)
        echo "${INFERNO_NAME:-unknown}"
        ;;
    ptp_offset)
        # Read latest PTP offset from statime-inferno journal (nanoseconds)
        # Output format: "offset=<ns>" or "unavailable" if no data
        OFFSET=$(journalctl -u statime-inferno --no-pager -n 50 --output=cat 2>/dev/null \
            | grep -oP 'offset=\K[-0-9]+' | tail -1 || true)
        if [ -n "${OFFSET}" ]; then
            echo "offset=${OFFSET}ns"
        else
            echo "unavailable"
        fi
        ;;
    service_bridge)
        STATUS=$(systemctl is-active inferno-bridge.service 2>/dev/null \
            || systemctl --user -M core@ is-active inferno-bridge.service 2>/dev/null \
            || echo "unknown")
        echo "${STATUS}"
        ;;
    service_librespot)
        STATUS=$(systemctl --user -M core@ is-active librespot.service 2>/dev/null \
            || echo "unknown")
        echo "${STATUS}"
        ;;
    service_statime)
        STATUS=$(systemctl is-active statime-inferno.service 2>/dev/null || echo "unknown")
        echo "${STATUS}"
        ;;
    *)
        echo "unknown-key:${KEY}"
        exit 1
        ;;
esac
