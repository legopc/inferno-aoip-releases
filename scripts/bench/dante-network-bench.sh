#!/bin/bash
# dante-network-bench.sh — Dante network health snapshot for Inferno
#
# Checks Dante device presence (via mDNS/avahi), netaudio device status,
# and subscription stability. Uses only read-only network queries.
#
# Requires: avahi-browse (in image), netaudio (if available)
#
# Usage:
#   dante-network-bench.sh [user@host] [options]
#
# Options:
#   --watch          Refresh every 10s until Ctrl+C
#   --interval N     Watch refresh interval (default: 10)
#   --timeout N      mDNS discovery timeout seconds (default: 3)
#   --help
#
# Examples:
#   dante-network-bench.sh core@192.168.1.43
#   dante-network-bench.sh                    # run locally

set -euo pipefail

BOLD='\033[1m'; CYAN='\033[0;36m'; GREEN='\033[0;32m'
RED='\033[0;31m'; YELLOW='\033[1;33m'; RESET='\033[0m'; DIM='\033[2m'

TARGET=""; WATCH=false; INTERVAL=10; MDNS_TIMEOUT=3

while [[ $# -gt 0 ]]; do
    case "$1" in
        --watch)    WATCH=true;            shift ;;
        --interval) INTERVAL="$2";         shift 2 ;;
        --timeout)  MDNS_TIMEOUT="$2";     shift 2 ;;
        --help|-h)  sed -n '2,20p' "$0" | sed 's/^# \?//'; exit 0 ;;
        -*)         echo "Unknown option: $1" >&2; exit 1 ;;
        *)  [[ -z "$TARGET" ]] && { TARGET="$1"; shift; } || { echo "Unexpected: $1" >&2; exit 1; } ;;
    esac
done

SSH_OPT=(-o StrictHostKeyChecking=no -o ConnectTimeout=10)

run_remote_sh() {
    if [[ -n "$TARGET" ]]; then
        ssh "${SSH_OPT[@]}" "$TARGET" "$1"
    else
        bash -c "$1"
    fi
}

collect_and_print() {
    local host ts
    host=$(run_remote_sh "hostname" 2>/dev/null || echo "localhost")
    ts=$(date -u +"%H:%M:%S UTC")

    echo -e "${BOLD}Dante Network Health${RESET}  —  ${CYAN}${host}${RESET}  ${DIM}${ts}${RESET}"
    echo "────────────────────────────────────────────"

    # ── Avahi / mDNS Dante discovery ─────────────────────────────────────────
    echo -e "  ${BOLD}Dante Device Discovery (mDNS, ${MDNS_TIMEOUT}s timeout)${RESET}"
    local mdns_out
    mdns_out=$(run_remote_sh \
        "avahi-browse -t -p --resolve _netaudio-arc._udp 2>/dev/null | grep '^=' || true" \
    ) || true

    if [[ -z "$mdns_out" ]]; then
        # Fallback: plain avahi-browse without resolve (faster)
        mdns_out=$(run_remote_sh \
            "timeout ${MDNS_TIMEOUT} avahi-browse -a -t -p 2>/dev/null | grep -i 'netaudio\|dante\|audinate' || true" \
        ) || true
    fi

    if [[ -z "$mdns_out" ]]; then
        echo -e "    ${YELLOW}No Dante devices found via mDNS${RESET}"
        echo -e "    ${DIM}(avahi-daemon may need a moment to discover — try --timeout 8)${RESET}"
    else
        local count; count=$(echo "$mdns_out" | wc -l)
        echo -e "    ${GREEN}${count} device(s) found${RESET}"
        echo "$mdns_out" | while IFS=';' read -ra fields; do
            # avahi-browse -p fields: event;ifindex;proto;name;type;domain[;host;addr;port;txt]
            local name="${fields[3]:-?}" addr="${fields[7]:-?}" port="${fields[8]:-?}"
            printf "    %-32s  %s:%s\n" "$name" "$addr" "$port"
        done
    fi

    # ── netaudio CLI (if available) ───────────────────────────────────────────
    echo -e "\n  ${BOLD}netaudio Status${RESET}"
    local has_netaudio
    has_netaudio=$(run_remote_sh "which netaudio 2>/dev/null && echo yes || echo no")
    if [[ "$has_netaudio" == "yes" ]]; then
        echo -e "    ${DIM}netaudio available — querying devices...${RESET}"
        local na_out
        na_out=$(run_remote_sh "timeout 10 netaudio device list 2>/dev/null || true") || true
        if [[ -n "$na_out" ]]; then
            echo "$na_out" | sed 's/^/    /'
        else
            echo -e "    ${YELLOW}netaudio returned no output${RESET}"
        fi

        echo -e "\n    ${DIM}subscriptions:${RESET}"
        local sub_out
        sub_out=$(run_remote_sh "timeout 10 netaudio subscription list 2>/dev/null || true") || true
        if [[ -n "$sub_out" ]]; then
            echo "$sub_out" | sed 's/^/    /'
        else
            echo -e "    ${YELLOW}No subscriptions or netaudio query failed${RESET}"
        fi
    else
        echo -e "    ${DIM}netaudio not installed — skipping device config queries${RESET}"
        echo -e "    ${DIM}(install via: see Inferno_Dante_Tools/scripts/dante-install-netaudio.sh)${RESET}"
    fi

    # ── Dante multicast ports (quick port check) ──────────────────────────────
    echo -e "\n  ${BOLD}Dante UDP Ports${RESET}"
    local port_out
    port_out=$(run_remote_sh \
        "ss -ulnp 2>/dev/null | grep -E ':(6004|6005|6006|6007|6008|6009|6010|6011|319|320)\b' || true" \
    ) || true
    if [[ -n "$port_out" ]]; then
        local pcount; pcount=$(echo "$port_out" | wc -l)
        echo -e "    ${GREEN}${pcount} Dante/PTP port(s) bound${RESET}"
        echo "$port_out" | awk '{for(i=1;i<=NF;i++) if($i~/:[0-9]+$/) printf "    %-8s %s\n",$1,$i}' | head -12
    else
        echo -e "    ${YELLOW}No Dante ports detected (Dante TX may not be running)${RESET}"
    fi

    # ── inferno TX service status ─────────────────────────────────────────────
    echo -e "\n  ${BOLD}Inferno TX/RX Services${RESET}"
    for svc in inferno-bridge inferno-keepalive inferno-aux-tx inferno-aux-rx; do
        local st
        st=$(run_remote_sh "systemctl --user is-active $svc 2>/dev/null || echo inactive") || st="inactive"
        st=$(echo "$st" | head -1 | tr -d '[:space:]')
        local col; [[ "$st" == "active" ]] && col="$GREEN" || col="$DIM"
        printf "    %-30s %b%s%b\n" "$svc:" "$col" "$st" "$RESET"
    done

    echo ""
}

if $WATCH; then
    while true; do
        clear 2>/dev/null || printf '\033[2J\033[H'
        collect_and_print
        echo -e "${DIM}Refreshing every ${INTERVAL}s — Ctrl+C to stop${RESET}"
        sleep "$INTERVAL"
    done
else
    collect_and_print
fi
