#!/bin/bash
# alsa-health.sh — ALSA pipeline health monitor for Inferno AoIP
#
# Reads /proc/asound for xrun counts and buffer state, checks snd-aloop,
# and tails the inferno-bridge journal for ALSA errors.
# Completely read-only — does not modify any ALSA state.
#
# Usage:
#   alsa-health.sh [user@host] [options]
#
# Options:
#   --watch          Continuous monitoring (refresh every 5s)
#   --interval N     Refresh interval in seconds (default: 5, requires --watch)
#   --help
#
# Examples:
#   alsa-health.sh core@192.168.1.43
#   alsa-health.sh core@192.168.1.43 --watch
#   alsa-health.sh                    # run locally

set -euo pipefail

BOLD='\033[1m'; CYAN='\033[0;36m'; GREEN='\033[0;32m'
RED='\033[0;31m'; YELLOW='\033[1;33m'; RESET='\033[0m'; DIM='\033[2m'

TARGET=""; WATCH=false; INTERVAL=5

while [[ $# -gt 0 ]]; do
    case "$1" in
        --watch)    WATCH=true;        shift ;;
        --interval) INTERVAL="$2";     shift 2 ;;
        --help|-h)  sed -n '2,18p' "$0" | sed 's/^# \?//'; exit 0 ;;
        -*)         echo "Unknown option: $1" >&2; exit 1 ;;
        *)  [[ -z "$TARGET" ]] && { TARGET="$1"; shift; } || { echo "Unexpected: $1" >&2; exit 1; } ;;
    esac
done

SSH_OPT=(-o StrictHostKeyChecking=no -o ConnectTimeout=10)
run_remote() {
    if [[ -n "$TARGET" ]]; then
        ssh "${SSH_OPT[@]}" "$TARGET" "$@"
    else
        "$@"
    fi
}

run_remote_sh() {
    if [[ -n "$TARGET" ]]; then
        ssh "${SSH_OPT[@]}" "$TARGET" "$1"
    else
        bash -c "$1"
    fi
}

collect_and_print() {
    local host
    host=$(run_remote hostname 2>/dev/null || echo "localhost")
    local ts; ts=$(date -u +"%H:%M:%S UTC")

    echo -e "${BOLD}ALSA Pipeline Health${RESET}  —  ${CYAN}${host}${RESET}  ${DIM}${ts}${RESET}"
    echo "────────────────────────────────────────────"

    # ── snd-aloop module ──────────────────────────────────────────────────────
    local aloop_loaded
    aloop_loaded=$(run_remote_sh "lsmod 2>/dev/null | grep -c snd_aloop || echo 0")
    if [[ "${aloop_loaded:-0}" -ge 1 ]]; then
        local users
        users=$(run_remote_sh "lsmod 2>/dev/null | awk '/^snd_aloop/{print \$3}'" )
        echo -e "  snd-aloop:      ${GREEN}loaded${RESET}  (${users:-?} users)"
    else
        echo -e "  snd-aloop:      ${RED}NOT LOADED${RESET}"
    fi

    # ── ALSA card listing ──────────────────────────────────────────────────────
    echo -e "\n  ${BOLD}ALSA Cards${RESET}"
    run_remote_sh "cat /proc/asound/cards 2>/dev/null || echo '  (unavailable)'" | \
        sed 's/^/    /'

    # ── Card 5 (snd-aloop) PCM status ────────────────────────────────────────
    echo -e "\n  ${BOLD}Loopback (card 5) PCM Status${RESET}"
    local found_any=false
    for sub in 0 1; do
        for stream in p c; do
            local path="/proc/asound/card5/pcm0${stream}/sub${sub}/status"
            local status
            status=$(run_remote_sh "cat '$path' 2>/dev/null" || true)
            if [[ -n "$status" ]]; then
                found_any=true
                local dir; [[ "$stream" == "p" ]] && dir="playback" || dir="capture"
                local state; state=$(echo "$status" | awk '/^state:/{print $2}')
                local color; [[ "$state" == "RUNNING" ]] && color="$GREEN" || color="$YELLOW"
                echo -e "    pcm0${stream}/sub${sub} (${dir}): ${color}${state}${RESET}"
            fi
        done
    done
    $found_any || echo -e "    ${YELLOW}No card5 PCM devices found${RESET}"

    # ── XRun check via journal ────────────────────────────────────────────────
    echo -e "\n  ${BOLD}XRun Events (last 5 min)${RESET}"
    local xrun_count
    xrun_count=$(run_remote_sh \
        "journalctl --user -u inferno-bridge --since=-5min --no-pager 2>/dev/null | grep -ic 'xrun\|underrun\|overrun' || echo 0" \
    ) || xrun_count=0
    xrun_count=$(echo "$xrun_count" | head -1 | tr -d '[:space:]')
    xrun_count="${xrun_count:-0}"
    if [[ "$xrun_count" -eq 0 ]]; then
        echo -e "    ${GREEN}None detected${RESET}  (inferno-bridge journal)"
    else
        echo -e "    ${RED}${xrun_count} events${RESET}"
        run_remote_sh \
            "journalctl --user -u inferno-bridge --since=-5min --no-pager 2>/dev/null | grep -i 'xrun\|underrun\|overrun' | tail -5" | \
            sed 's/^/      /'
    fi

    # ── inferno-bridge service status ────────────────────────────────────────
    echo -e "\n  ${BOLD}Core Services${RESET}"
    for svc in inferno-bridge statime-inferno librespot; do
        local st
        case "$svc" in
            statime-inferno)
                st=$(run_remote_sh "systemctl is-active $svc 2>/dev/null || echo inactive") ;;
            *)
                st=$(run_remote_sh "systemctl --user is-active $svc 2>/dev/null || echo inactive") ;;
        esac
        st=$(echo "$st" | head -1 | tr -d '[:space:]')
        local col; [[ "$st" == "active" ]] && col="$GREEN" || col="$RED"
        printf "    %-26s %b%s%b\n" "$svc:" "$col" "$st" "$RESET"
    done

    # ── Last ALSA error ──────────────────────────────────────────────────────
    echo -e "\n  ${BOLD}Recent ALSA Errors (last 15 min)${RESET}"
    local alsa_errs
    alsa_errs=$(run_remote_sh \
        "journalctl --user --since=-15min --no-pager 2>/dev/null | grep -i 'ALSA\|alsa\|pcm\|snd' | grep -i 'error\|fail\|unable\|cannot\|Permission\|denied' | tail -5" \
    ) || true
    if [[ -z "$alsa_errs" ]]; then
        echo -e "    ${GREEN}None found${RESET}"
    else
        echo "$alsa_errs" | sed 's/^/    /'
    fi

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
