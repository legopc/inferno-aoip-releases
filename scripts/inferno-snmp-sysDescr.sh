#!/bin/bash
# Outputs a one-line sysDescr for SNMP extend.
VERSION=$(cat /var/lib/inferno/version 2>/dev/null || echo "dev")
MODE=$(grep "^INFERNO_MODE=" /etc/inferno.conf 2>/dev/null | cut -d= -f2)
HOSTNAME=$(hostname)
echo "Inferno AoIP Appliance v${VERSION} mode=${MODE:-unknown} host=${HOSTNAME}"
