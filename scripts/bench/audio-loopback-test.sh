#!/bin/bash
# audio-loopback-test.sh — Audio pipeline quality test for Inferno AoIP
#
# Passive mode (default): reads from the Dante RX ALSA device via inferno2pipe,
# pipes through ffmpeg silence/level detection, and reports dropout rate and
# level stability over a configurable window.
#
# Active mode (--active): starts sinegen.sh on a TX node first, then measures
# the received signal. Use only on development nodes.
#
# Requires:
#   - inferno2pipe binary in PATH or ~/bin/ (reads Dante RX as raw PCM)
#   - ffmpeg (for signal analysis)
#   - sinegen.sh in PATH or ~/bin/ (active mode only)
#
# Usage:
#   audio-loopback-test.sh [user@host] [options]
#
# Options:
#   --duration N     Test duration in seconds (default: 20)
#   --device NAME    ALSA device for inferno2pipe (default: auto-detect)
#   --active         Active mode: inject 1kHz sine first (dev nodes only)
#   --tx-node U@H    TX node for active mode (where to run sinegen)
#   --help
#
# Examples:
#   audio-loopback-test.sh core@192.168.1.43              # passive, 20s
#   audio-loopback-test.sh core@192.168.1.43 --duration 60
#   audio-loopback-test.sh core@192.168.1.43 --active --tx-node core@192.168.1.43

set -euo pipefail

BOLD='\033[1m'; CYAN='\033[0;36m'; GREEN='\033[0;32m'
RED='\033[0;31m'; YELLOW='\033[1;33m'; RESET='\033[0m'; DIM='\033[2m'

TARGET=""; DURATION=20; DEVICE=""; ACTIVE=false; TX_NODE=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --duration) DURATION="$2"; shift 2 ;;
        --device)   DEVICE="$2";   shift 2 ;;
        --active)   ACTIVE=true;   shift ;;
        --tx-node)  TX_NODE="$2";  shift 2 ;;
        --help|-h)  sed -n '2,24p' "$0" | sed 's/^# \?//'; exit 0 ;;
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

REMOTE_HOST=$(run_remote_sh "hostname" 2>/dev/null || echo "localhost")

echo -e "${BOLD}Audio Pipeline Test${RESET}  —  ${CYAN}${REMOTE_HOST}${RESET}"

# ── Dependency check ───────────────────────────────────────────────────────────
echo -e "\n  ${BOLD}Checking dependencies...${RESET}"

HAS_I2PIPE=$(run_remote_sh "which inferno2pipe 2>/dev/null || ls ~/bin/inferno2pipe 2>/dev/null && echo yes || echo no") || HAS_I2PIPE=no
HAS_FFMPEG=$(run_remote_sh "which ffmpeg 2>/dev/null && echo yes || echo no") || HAS_FFMPEG=no

if [[ "$HAS_I2PIPE" != "yes" ]]; then
    echo -e "  ${YELLOW}inferno2pipe not found${RESET}"
    echo -e "  ${DIM}Falling back to ALSA-level health check only${RESET}"
    FALLBACK=true
else
    echo -e "  inferno2pipe: ${GREEN}found${RESET}"
    FALLBACK=false
fi

if [[ "$HAS_FFMPEG" != "yes" ]]; then
    echo -e "  ffmpeg: ${YELLOW}not found${RESET}"
    [[ "$FALLBACK" == "false" ]] && echo -e "  ${YELLOW}Cannot do signal analysis without ffmpeg — falling back to ALSA check${RESET}"
    FALLBACK=true
else
    echo -e "  ffmpeg:       ${GREEN}found${RESET}"
fi

# ── Fallback: ALSA-level check (no inferno2pipe/ffmpeg) ──────────────────────
if [[ "$FALLBACK" == "true" ]]; then
    echo -e "\n  ${BOLD}ALSA Fallback: Monitoring inferno-bridge for ${DURATION}s${RESET}"
    echo -e "  ${DIM}(install inferno2pipe + ffmpeg for full audio quality metrics)${RESET}\n"

    # Capture baseline xrun count
    START_XRUNS=$(run_remote_sh \
        "journalctl --user -u inferno-bridge --since=-1min --no-pager 2>/dev/null | grep -ic 'xrun\|underrun\|overrun' || echo 0") || START_XRUNS=0
    START_XRUNS=$(echo "$START_XRUNS" | head -1 | tr -d '[:space:]')

    # Check bridge is running
    BRIDGE_ST=$(run_remote_sh "systemctl --user is-active inferno-bridge 2>/dev/null || echo inactive")
    if [[ "$BRIDGE_ST" != "active" ]]; then
        echo -e "  ${RED}inferno-bridge is not active — audio pipeline not running${RESET}"
        exit 1
    fi

    echo -e "  Monitoring ${DURATION}s..."
    sleep "$DURATION"

    END_XRUNS=$(run_remote_sh \
        "journalctl --user -u inferno-bridge --since=-$((DURATION + 5))s --no-pager 2>/dev/null | grep -ic 'xrun\|underrun\|overrun' || echo 0") || END_XRUNS=0
    END_XRUNS=$(echo "$END_XRUNS" | head -1 | tr -d '[:space:]')

    NEW_XRUNS=$(( END_XRUNS - START_XRUNS ))
    [[ "$NEW_XRUNS" -lt 0 ]] && NEW_XRUNS=0

    echo ""
    printf "  %-24s %s\n" "Duration:"           "${DURATION}s"
    printf "  %-24s %s\n" "inferno-bridge:"      "$BRIDGE_ST"
    printf "  %-24s %s\n" "New XRuns detected:"  "$NEW_XRUNS"

    if [[ "$NEW_XRUNS" -eq 0 ]]; then
        echo -e "\n  ${GREEN}★ PASS — No audio pipeline errors detected${RESET}"
    else
        echo -e "\n  ${RED}✗ FAIL — ${NEW_XRUNS} XRun(s) during test window${RESET}"
    fi
    exit 0
fi

# ── Active mode: start sine generator on TX node ──────────────────────────────
SINE_PID=""
if $ACTIVE; then
    if [[ -z "$TX_NODE" ]]; then
        echo -e "${YELLOW}--active requires --tx-node user@host${RESET}" >&2; exit 1
    fi
    echo -e "\n  ${BOLD}Active mode: starting 1kHz sine on ${TX_NODE}${RESET}"
    SINE_CMD="sinegen.sh 2>/dev/null &"
    ssh "${SSH_OPT[@]}" "$TX_NODE" "$SINE_CMD" &
    SINE_PID=$!
    sleep 2  # Allow sine to stabilise
    echo -e "  ${DIM}Sine generator started (PID ${SINE_PID})${RESET}"
fi

# ── Determine Dante RX ALSA device ────────────────────────────────────────────
if [[ -z "$DEVICE" ]]; then
    # inferno2pipe default device: plughw:5,0 or similar
    DEVICE=$(run_remote_sh \
        "arecord -l 2>/dev/null | awk '/Loopback.*subdevice/{sub(/.*card /,\"hw:\"); sub(/,.*subdevice /,\",\"); sub(/:.*/,\"\"); print; exit}'" \
    ) || DEVICE="hw:5,0"
    echo -e "\n  ${DIM}Using ALSA device: $DEVICE${RESET}"
fi

# ── Run inferno2pipe → ffmpeg pipeline ────────────────────────────────────────
echo -e "\n  ${BOLD}Capturing ${DURATION}s of audio from Dante RX...${RESET}"
echo -e "  ${DIM}Device: ${DEVICE} | Duration: ${DURATION}s${RESET}\n"

TMPDIR_RUN=$(run_remote_sh "mktemp -d /tmp/audio-bench-XXXXXX") || TMPDIR_RUN="/tmp/audio-bench-$$"

# Run the full pipeline remotely: inferno2pipe | ffmpeg silence+ebur128 detection
RESULT=$(run_remote_sh "
set -e
inferno2pipe --device '$DEVICE' --duration $DURATION 2>/dev/null | \
ffmpeg -f s32le -ar 48000 -ac 2 -i pipe:0 \
  -af 'silencedetect=noise=-50dB:d=0.1,ebur128=peak=true' \
  -f null - 2>&1 || true
" 2>/dev/null) || RESULT=""

# Stop sine generator if active
if [[ -n "$SINE_PID" ]]; then
    kill "$SINE_PID" 2>/dev/null || true
    $ACTIVE && ssh "${SSH_OPT[@]}" "$TX_NODE" "pkill -f sinegen 2>/dev/null || true"
fi

if [[ -z "$RESULT" ]]; then
    echo -e "  ${RED}No output from audio pipeline. Is inferno2pipe receiving audio?${RESET}"
    exit 1
fi

# Parse silence events
SILENCE_STARTS=$(echo "$RESULT" | grep -c "silence_start" || echo 0)
SILENCE_STARTS=$(echo "$SILENCE_STARTS" | head -1 | tr -d '[:space:]')
SILENCE_ENDS=$(echo "$RESULT" | grep -c "silence_end" || echo 0)
SILENCE_ENDS=$(echo "$SILENCE_ENDS" | head -1 | tr -d '[:space:]')
SILENCE_TOTAL=$(echo "$RESULT" | grep -oP 'silence_duration: \K[\d.]+' | \
    python3 -c "import sys; print(f'{sum(float(l) for l in sys.stdin):.2f}')" || echo "0.00")

# Parse integrated loudness from ebur128
LOUDNESS=$(echo "$RESULT" | grep -oP 'I:\s+\K[-\d.]+' | tail -1 || echo "N/A")
PEAK=$(echo "$RESULT" | grep -oP 'Peak:\s+\K[-\d.]+' | tail -1 || echo "N/A")

echo -e "  ${BOLD}Results${RESET}"
echo    "  ─────────────────────────────────────────"
printf  "  %-28s %s\n"  "Duration:"             "${DURATION}s"
printf  "  %-28s %s\n"  "Silence events:"       "${SILENCE_STARTS}"
printf  "  %-28s %s\n"  "Total silence:"        "${SILENCE_TOTAL}s"
printf  "  %-28s %s\n"  "Integrated loudness:"  "${LOUDNESS} LUFS"
printf  "  %-28s %s\n"  "True peak:"            "${PEAK} dBTP"

DROPOUT_RATE=$(python3 -c "print(f'{float(\"$SILENCE_TOTAL\") / $DURATION * 100:.1f}')" 2>/dev/null || echo "?")
printf  "  %-28s %s\n"  "Dropout rate:"         "${DROPOUT_RATE}%"

echo ""
if [[ "$SILENCE_STARTS" -eq 0 ]]; then
    echo -e "  ${GREEN}★ PASS — No audio dropouts in ${DURATION}s window${RESET}"
else
    echo -e "  ${RED}✗ FAIL — ${SILENCE_STARTS} dropout event(s), ${SILENCE_TOTAL}s total silence${RESET}"
fi
echo ""
