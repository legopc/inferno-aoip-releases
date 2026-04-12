#!/bin/bash
# inferno-snmp-apply.sh — Apply SNMP configuration from /etc/inferno.conf
#
# Called by Cockpit SNMP tab (via sudo) after the user saves SNMP settings.
# Also called by inferno-configure.sh if SNMP was previously enabled and
# the node is being reconfigured.
#
# What this does:
#   1. Source /etc/inferno.conf to get INFERNO_SNMP_* values
#   2. If INFERNO_SNMP_ENABLED=no  → stop + disable snmpd, exit 0
#   3. Substitute template → /etc/snmp/snmpd.conf
#   4. If V3_USER set → recreate SNMPv3 user (stop daemon, write createUser, start)
#   5. If V3_USER empty → remove any existing rouser directive
#   6. Enable + (re)start snmpd

set -euo pipefail
exec >> /var/log/inferno-snmp-apply.log 2>&1
echo "=== inferno-snmp-apply: $(date -Iseconds) ==="

TEMPLATE=/etc/inferno/snmpd.conf.template
CONF=/etc/snmp/snmpd.conf
NET_SNMP_PERSIST=/var/lib/net-snmp/snmpd.conf

# Source inferno config
if [ ! -f /etc/inferno.conf ]; then
    echo "ERROR: /etc/inferno.conf not found" >&2
    exit 1
fi
# shellcheck disable=SC1091
. /etc/inferno.conf

INFERNO_SNMP_ENABLED="${INFERNO_SNMP_ENABLED:-no}"
INFERNO_SNMP_V2_COMMUNITY="${INFERNO_SNMP_V2_COMMUNITY:-}"
INFERNO_SNMP_V3_USER="${INFERNO_SNMP_V3_USER:-}"
INFERNO_SNMP_V3_AUTH_PASS="${INFERNO_SNMP_V3_AUTH_PASS:-}"
INFERNO_SNMP_V3_PRIV_PASS="${INFERNO_SNMP_V3_PRIV_PASS:-}"
INFERNO_NAME="${INFERNO_NAME:-Inferno-Node}"

# ── Disable path ───────────────────────────────────────────────────────────────
if [ "${INFERNO_SNMP_ENABLED}" != "yes" ]; then
    echo "SNMP disabled — stopping snmpd"
    systemctl stop snmpd.service 2>/dev/null || true
    systemctl disable snmpd.service 2>/dev/null || true
    exit 0
fi

# ── Validate ───────────────────────────────────────────────────────────────────
if [ -z "${INFERNO_SNMP_V2_COMMUNITY}" ] && [ -z "${INFERNO_SNMP_V3_USER}" ]; then
    echo "ERROR: SNMP enabled but no v2c community or v3 user configured" >&2
    exit 1
fi

# ── Render snmpd.conf from template ───────────────────────────────────────────
if [ ! -f "${TEMPLATE}" ]; then
    echo "ERROR: template not found: ${TEMPLATE}" >&2
    exit 1
fi

mkdir -p /etc/snmp
sed \
    -e "s|%%INFERNO_SNMP_V2_COMMUNITY%%|${INFERNO_SNMP_V2_COMMUNITY}|g" \
    -e "s|%%INFERNO_SNMP_V3_USER%%|${INFERNO_SNMP_V3_USER}|g" \
    -e "s|%%INFERNO_NAME%%|${INFERNO_NAME}|g" \
    "${TEMPLATE}" > "${CONF}"

# If v2c community is empty, remove the rocommunity line
if [ -z "${INFERNO_SNMP_V2_COMMUNITY}" ]; then
    sed -i '/^rocommunity/d' "${CONF}"
fi

# ── SNMPv3 user management ─────────────────────────────────────────────────────
if [ -n "${INFERNO_SNMP_V3_USER}" ]; then
    # Validate passphrase lengths (net-snmp minimum: 8 chars)
    if [ "${#INFERNO_SNMP_V3_AUTH_PASS}" -lt 8 ] || [ "${#INFERNO_SNMP_V3_PRIV_PASS}" -lt 8 ]; then
        echo "ERROR: SNMPv3 passphrases must be at least 8 characters" >&2
        exit 1
    fi

    echo "Configuring SNMPv3 user: ${INFERNO_SNMP_V3_USER}"

    # Stop daemon so it processes createUser on next start
    systemctl stop snmpd.service 2>/dev/null || true

    # Remove any existing createUser and usmUser lines for this user from persist file
    mkdir -p /var/lib/net-snmp
    touch "${NET_SNMP_PERSIST}"
    sed -i "/createUser ${INFERNO_SNMP_V3_USER} /d" "${NET_SNMP_PERSIST}"
    sed -i "/usmUser.*\"${INFERNO_SNMP_V3_USER}\"/d" "${NET_SNMP_PERSIST}"

    # Write new createUser directive (net-snmp replaces this with hashed form on start)
    echo "createUser ${INFERNO_SNMP_V3_USER} SHA-256 ${INFERNO_SNMP_V3_AUTH_PASS} AES ${INFERNO_SNMP_V3_PRIV_PASS}" \
        >> "${NET_SNMP_PERSIST}"

    # Uncomment rouser line in snmpd.conf
    sed -i "s|^# rouser %%INFERNO_SNMP_V3_USER%% authPriv|rouser ${INFERNO_SNMP_V3_USER} authPriv|" "${CONF}"
    # In case placeholder was already substituted above, ensure rouser line is present
    if ! grep -q "^rouser ${INFERNO_SNMP_V3_USER}" "${CONF}"; then
        echo "rouser ${INFERNO_SNMP_V3_USER} authPriv" >> "${CONF}"
    fi
else
    # No v3 user — remove rouser line
    sed -i '/^# rouser/d' "${CONF}"
    sed -i '/^rouser/d' "${CONF}"
fi

# ── Enable and start snmpd ─────────────────────────────────────────────────────
echo "Starting snmpd"
systemctl enable snmpd.service
systemctl start snmpd.service

echo "SNMP apply complete"
