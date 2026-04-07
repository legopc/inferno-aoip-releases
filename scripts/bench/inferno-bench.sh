#!/bin/bash
# inferno-bench.sh — Master benchmark orchestrator for Inferno AoIP
#
# Runs all (or selected) benchmark components and collects results into a
# timestamped report directory. Designed for before/after comparisons:
# run once before a change, again after, then compare.
#
# Usage:
#   inferno-bench.sh [user@host] [options]
#
# Options:
#   --mode quick|full|ptp-only|audio-only|health-only
#                    Preset run mode (default: quick)
#   --output-dir D   Report directory (default: ~/.inferno-bench/TIMESTAMP/)
#   --label NAME     Label for this run (default: hostname)
#   --compare DIR_A DIR_B  Compare two report directories
#   --help
#
# Modes:
#   quick       PTP bench (100 samples) + ALSA health + Dante health  (~2 min)
#   full        All components including stress bench                  (~15 min)
#   ptp-only    PTP benchmark only
#   audio-only  Audio loopback test only
#   health-only ALSA health + Dante health (no benchmarking)
#
# Examples:
#   inferno-bench.sh core@192.168.1.43
#   inferno-bench.sh core@192.168.1.43 --mode full --label hw-ptp-before
#   inferno-bench.sh core@192.168.1.43 --mode ptp-only --label sw-ptp
#   inferno-bench.sh --compare ~/.inferno-bench/hw-run/ ~/.inferno-bench/sw-run/

set -euo pipefail

BOLD='\033[1m'; CYAN='\033[0;36m'; GREEN='\033[0;32m'
YELLOW='\033[1;33m'; RESET='\033[0m'; DIM='\033[2m'; RED='\033[0;31m'

TARGET=""; MODE="quick"; OUTPUT_DIR=""; LABEL=""
COMPARE_A=""; COMPARE_B=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --mode)       MODE="$2";       shift 2 ;;
        --output-dir) OUTPUT_DIR="$2"; shift 2 ;;
        --label)      LABEL="$2";      shift 2 ;;
        --compare)    COMPARE_A="$2"; COMPARE_B="$3"; shift 3 ;;
        --help|-h)    sed -n '2,30p' "$0" | sed 's/^# \?//'; exit 0 ;;
        -*)           echo "Unknown option: $1" >&2; exit 1 ;;
        *)  [[ -z "$TARGET" ]] && { TARGET="$1"; shift; } || { echo "Unexpected: $1" >&2; exit 1; } ;;
    esac
done

# Script directory (to find sibling scripts)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

ptp_bench()    { bash "$SCRIPT_DIR/ptp-bench.sh"          ${TARGET:+"$TARGET"} "$@"; }
alsa_health()  { bash "$SCRIPT_DIR/alsa-health.sh"         ${TARGET:+"$TARGET"} "$@"; }
dante_bench()  { bash "$SCRIPT_DIR/dante-network-bench.sh" ${TARGET:+"$TARGET"} "$@"; }
audio_test()   { bash "$SCRIPT_DIR/audio-loopback-test.sh" ${TARGET:+"$TARGET"} "$@"; }
stress_bench() { bash "$SCRIPT_DIR/stress-bench.sh"        ${TARGET:+"$TARGET"} "$@"; }

# ── Compare mode ───────────────────────────────────────────────────────────────
if [[ -n "$COMPARE_A" ]]; then
    [[ -d "$COMPARE_A" ]] || { echo "Directory not found: $COMPARE_A" >&2; exit 1; }
    [[ -d "$COMPARE_B" ]] || { echo "Directory not found: $COMPARE_B" >&2; exit 1; }

    echo -e "${BOLD}Benchmark Comparison${RESET}"
    echo -e "  A: ${CYAN}$COMPARE_A${RESET}"
    echo -e "  B: ${CYAN}$COMPARE_B${RESET}"
    echo ""

    # PTP comparison
    PTP_A=$(ls "$COMPARE_A"/*-ptp-*.json 2>/dev/null | head -1 || true)
    PTP_B=$(ls "$COMPARE_B"/*-ptp-*.json 2>/dev/null | head -1 || true)
    if [[ -n "$PTP_A" && -n "$PTP_B" ]]; then
        echo -e "${BOLD}── PTP Jitter ──${RESET}"
        ptp_bench --compare "$PTP_A" "$PTP_B"
    else
        echo -e "${DIM}  No PTP result files found in one or both directories${RESET}"
    fi

    # Stress comparison
    STRESS_A=$(ls "$COMPARE_A"/*-stress-*.json 2>/dev/null | head -1 || true)
    STRESS_B=$(ls "$COMPARE_B"/*-stress-*.json 2>/dev/null | head -1 || true)
    if [[ -n "$STRESS_A" && -n "$STRESS_B" ]]; then
        echo -e "\n${BOLD}── Stress Benchmark ──${RESET}"
        python3 - "$STRESS_A" "$STRESS_B" <<'PYEOF'
import json, sys

BOLD='\033[1m'; GREEN='\033[0;32m'; RED='\033[0;31m'; RESET='\033[0m'

def load(f):
    with open(f) as fh: return json.load(fh)

def fmt(v):
    v = float(v); a = abs(v)
    if a < 1e3:  return f"{v:.0f}ns"
    elif a < 1e6: return f"{v/1e3:.1f}µs"
    else:         return f"{v/1e6:.2f}ms"

a, b = load(sys.argv[1]), load(sys.argv[2])
la = a.get("label", "A"); lb = b.get("label", "B")

print(f"\n  {'Phase':<12} {la:>16} {lb:>16}  {'Better':>8}")
print("  " + "─" * 54)
for phase in ["baseline","cpu","memory","network","recovery"]:
    pa = a["phases"].get(phase, {}); pb = b["phases"].get(phase, {})
    if not pa and not pb: continue
    va = pa.get("abs_max", 0); vb = pb.get("abs_max", 0)
    win = f"{GREEN}A{RESET}" if va < vb else (f"{RED}B{RESET}" if vb < va else "=")
    print(f"  {phase:<12} {fmt(va):>16} {fmt(vb):>16}  {win:>8}")
print()
PYEOF
    fi

    exit 0
fi

# ── Collect mode ───────────────────────────────────────────────────────────────
SSH_OPT=(-o StrictHostKeyChecking=no -o ConnectTimeout=10)
run_remote_sh() {
    if [[ -n "$TARGET" ]]; then
        ssh "${SSH_OPT[@]}" "$TARGET" "$1"
    else
        bash -c "$1"
    fi
}

REMOTE_HOST=$(run_remote_sh "hostname" 2>/dev/null || echo "localhost")
[[ -z "$LABEL" ]] && LABEL="$REMOTE_HOST"

TS=$(date +%Y%m%d-%H%M%S)
[[ -z "$OUTPUT_DIR" ]] && OUTPUT_DIR="$HOME/.inferno-bench/${LABEL}-${TS}"
mkdir -p "$OUTPUT_DIR"

echo -e "${BOLD}Inferno Benchmark Suite${RESET}  —  ${CYAN}${LABEL}${RESET}"
echo -e "${DIM}Mode: ${MODE} | Output: ${OUTPUT_DIR}${RESET}"

START_SEC=$SECONDS

run_component() {
    local name="$1"; shift
    echo -e "\n${BOLD}── ${name} ──${RESET}"
    if "$@"; then
        echo -e "  ${GREEN}✓ ${name} complete${RESET}"
    else
        echo -e "  ${YELLOW}⚠ ${name} failed or skipped${RESET}"
    fi
}

case "$MODE" in
    quick)
        run_component "PTP Benchmark"   ptp_bench    --samples 100 --output "$OUTPUT_DIR/${LABEL}-ptp-${TS}.json"
        run_component "ALSA Health"     alsa_health  > "$OUTPUT_DIR/alsa-health-${TS}.txt" 2>&1; cat "$OUTPUT_DIR/alsa-health-${TS}.txt"
        run_component "Dante Network"   dante_bench  > "$OUTPUT_DIR/dante-network-${TS}.txt" 2>&1; cat "$OUTPUT_DIR/dante-network-${TS}.txt"
        ;;
    full)
        run_component "PTP Benchmark"   ptp_bench    --samples 300 --output "$OUTPUT_DIR/${LABEL}-ptp-${TS}.json"
        run_component "ALSA Health"     alsa_health  > "$OUTPUT_DIR/alsa-health-${TS}.txt" 2>&1; cat "$OUTPUT_DIR/alsa-health-${TS}.txt"
        run_component "Dante Network"   dante_bench  > "$OUTPUT_DIR/dante-network-${TS}.txt" 2>&1; cat "$OUTPUT_DIR/dante-network-${TS}.txt"
        run_component "Audio Test"      audio_test   --duration 30 > "$OUTPUT_DIR/audio-test-${TS}.txt" 2>&1; cat "$OUTPUT_DIR/audio-test-${TS}.txt"
        run_component "Stress Bench"    stress_bench --phase-duration 60 --output "$OUTPUT_DIR/${LABEL}-stress-${TS}.json"
        ;;
    ptp-only)
        run_component "PTP Benchmark"   ptp_bench    --samples 300 --output "$OUTPUT_DIR/${LABEL}-ptp-${TS}.json"
        ;;
    audio-only)
        run_component "Audio Test"      audio_test   --duration 30 > "$OUTPUT_DIR/audio-test-${TS}.txt" 2>&1; cat "$OUTPUT_DIR/audio-test-${TS}.txt"
        ;;
    health-only)
        run_component "ALSA Health"     alsa_health  > "$OUTPUT_DIR/alsa-health-${TS}.txt" 2>&1; cat "$OUTPUT_DIR/alsa-health-${TS}.txt"
        run_component "Dante Network"   dante_bench  > "$OUTPUT_DIR/dante-network-${TS}.txt" 2>&1; cat "$OUTPUT_DIR/dante-network-${TS}.txt"
        ;;
    *)
        echo "Unknown mode: $MODE (use: quick, full, ptp-only, audio-only, health-only)" >&2; exit 1 ;;
esac

ELAPSED=$(( SECONDS - START_SEC ))

# Write report index
cat > "$OUTPUT_DIR/README.md" <<MDEOF
# Inferno Benchmark Report

- **Label**: $LABEL
- **Host**: $REMOTE_HOST
- **Mode**: $MODE
- **Timestamp**: $(date -u)
- **Duration**: ${ELAPSED}s

## Files

$(ls "$OUTPUT_DIR" | grep -v README.md | sed 's/^/- /')

## Compare

To compare this run with another:
\`\`\`
inferno-bench.sh --compare $OUTPUT_DIR /path/to/other-run/
\`\`\`
MDEOF

echo ""
echo -e "${BOLD}Benchmark complete${RESET}  (${ELAPSED}s)"
echo -e "${GREEN}  Report saved → ${OUTPUT_DIR}${RESET}"
echo -e "${DIM}  Run again with a different config, then:${RESET}"
echo -e "${DIM}  inferno-bench.sh --compare ${OUTPUT_DIR} /path/to/other/run${RESET}"
