#!/usr/bin/env bash
# inferno-health-check.sh — post-boot health check for auto-rollback (Item 17)
#
# Runs 120 seconds after multi-user.target via inferno-health-check.service.
# If ALL critical services are inactive after the grace period, calls
# 'bootc rollback' and reboots — recovering from a bad OTA update automatically.
#
# Critical services checked:
#   statime-inferno  — PTP clock sync daemon (core audio timing)
#   cockpit.socket   — Cockpit web UI (management + remote recovery)
#
# A rollback is triggered only when BOTH services are failed AND a rollback
# deployment is available in bootc. One healthy service = no rollback.
#
# The /var/lib/inferno/health-check-ok flag is written on a clean pass so
# the result is visible in 'journalctl -u inferno-health-check'.

set -uo pipefail

LOG_TAG="inferno-health-check"
OK_FLAG="/var/lib/inferno/health-check-ok"

log() { logger -t "$LOG_TAG" "$*"; echo "[${LOG_TAG}] $*"; }

CRITICAL_SERVICES=(statime-inferno cockpit.socket)
FAILED=0

for svc in "${CRITICAL_SERVICES[@]}"; do
    if systemctl is-active --quiet "$svc"; then
        log "OK: ${svc} is active"
    else
        log "FAIL: ${svc} is not active ($(systemctl is-active "$svc" 2>/dev/null || echo unknown))"
        FAILED=$((FAILED + 1))
    fi
done

TOTAL=${#CRITICAL_SERVICES[@]}

if [[ $FAILED -lt $TOTAL ]]; then
    log "Health check passed ($((TOTAL - FAILED))/${TOTAL} critical services healthy)"
    touch "$OK_FLAG"
    exit 0
fi

# All critical services failed — check if a rollback deployment is available
log "All ${TOTAL}/${TOTAL} critical services failed — checking for rollback deployment"

HAS_ROLLBACK=$(bootc status --format json 2>/dev/null | python3 -c "
import json, sys
try:
    d = json.load(sys.stdin)
    rb = (d.get('status') or {}).get('rollback') or d.get('rollback')
    print('yes' if rb else 'no')
except Exception as e:
    print('no')
    sys.stderr.write(str(e) + '\n')
" 2>/dev/null || echo "no")

if [[ "$HAS_ROLLBACK" != "yes" ]]; then
    log "No rollback deployment available — cannot auto-recover (physical intervention required)"
    exit 1
fi

log "CRITICAL: Triggering bootc rollback — this boot is unhealthy"
bootc rollback || { log "bootc rollback failed — cannot auto-recover"; exit 1; }

log "Rollback staged — rebooting in 5 seconds"
sleep 5
systemctl reboot
