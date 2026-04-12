#!/bin/bash
# ptp-bench.sh — Collect PTP jitter statistics from statime-inferno
#
# Parses TRACE-level "Estimated offset" lines from the statime-inferno journal.
# Values are in nanoseconds.
#
# Usage:
#   ptp-bench.sh [user@host] [options]
#
# Options:
#   --samples N      Measurements to collect (default: 300, ~60 sec at 5/s)
#   --minutes M      Collect journal window of M minutes instead
#   --output FILE    Save results to JSON (default: auto-named)
#   --no-save        Skip JSON output
#   --compare A B    Compare two JSON result files side-by-side
#   --label NAME     Label for this run (default: hostname)
#   --help
#
# Examples:
#   ptp-bench.sh core@192.168.1.43                         # HW PTP node
#   ptp-bench.sh core@192.168.1.25                         # SW PTP node
#   ptp-bench.sh core@192.168.1.43 --minutes 5 --output hw.json
#   ptp-bench.sh --compare hw.json sw.json
#   ptp-bench.sh                                           # run locally

set -euo pipefail

BOLD='\033[1m'; CYAN='\033[0;36m'; GREEN='\033[0;32m'
YELLOW='\033[1;33m'; RESET='\033[0m'; DIM='\033[2m'

# ── Python stats script (written to temp file) ─────────────────────────────────
STATS_PY=$(mktemp /tmp/ptp-bench-stats-XXXXXX.py)
trap 'rm -f "$STATS_PY"' EXIT

cat > "$STATS_PY" <<'STATS_SCRIPT'
import sys, json, math

values = [float(l.strip()) for l in sys.stdin if l.strip()]
if not values:
    print(json.dumps({"error": "no values"})); sys.exit(1)

n = len(values)
sv = sorted(values)
av = [abs(v) for v in values]
mean = sum(values) / n
stddev = math.sqrt(sum((v - mean)**2 for v in values) / n)

def pct(s, p):
    i = (p / 100.0) * (len(s) - 1)
    lo = int(i); hi = min(lo + 1, len(s) - 1)
    return s[lo] + (i - lo) * (s[hi] - s[lo])

print(json.dumps({
    "count": n,
    "mean": mean, "stddev": stddev,
    "min": sv[0], "max": sv[-1],
    "abs_max": max(av),
    "p50": pct(sv, 50), "p95": pct(sv, 95), "p99": pct(sv, 99),
    "out_1us_pct":   100.0 * sum(1 for v in av if v > 1e3)   / n,
    "out_10us_pct":  100.0 * sum(1 for v in av if v > 1e4)   / n,
    "out_100us_pct": 100.0 * sum(1 for v in av if v > 1e5)   / n,
}))
STATS_SCRIPT

# ── Python compare script ──────────────────────────────────────────────────────
COMPARE_PY=$(mktemp /tmp/ptp-bench-cmp-XXXXXX.py)
trap 'rm -f "$STATS_PY" "$COMPARE_PY"' EXIT

cat > "$COMPARE_PY" <<'CMP_SCRIPT'
import json, sys

BOLD='\033[1m'; GREEN='\033[0;32m'; RED='\033[0;31m'; RESET='\033[0m'

def load(f):
    with open(f) as fh: return json.load(fh)

def fmt(v):
    if v is None: return "N/A"
    av = abs(v)
    if av < 1e3:  return f"{v:.1f} ns"
    elif av < 1e6: return f"{v/1e3:.2f} µs"
    else:          return f"{v/1e6:.3f} ms"

a, b = load(sys.argv[1]), load(sys.argv[2])
sa, sb = a["stats"], b["stats"]
la = a.get("label", a.get("host", "A"))
lb = b.get("label", b.get("host", "B"))

print(f"\n{BOLD}PTP Jitter Comparison{RESET}")
print(f"{'Metric':<22} {la:>20} {lb:>20}  {'Better':>6}")
print("─" * 74)

def row(name, key, pct=False):
    va, vb = sa.get(key), sb.get(key)
    if va is None or vb is None:
        print(f"  {name:<20} {'N/A':>20} {'N/A':>20}")
        return
    fa, fb = fmt(va) if not pct else f"{va:.1f}%", fmt(vb) if not pct else f"{vb:.1f}%"
    win = f"{GREEN}A{RESET}" if abs(va) < abs(vb) else (f"{RED}B{RESET}" if abs(vb) < abs(va) else "=")
    print(f"  {name:<20} {fa:>20} {fb:>20}  {win:>6}")

row("Samples",    "count")
row("Mean offset","mean")
row("Std dev",    "stddev")
row("Abs max",    "abs_max")
row("p50",        "p50")
row("p95",        "p95")
row("p99",        "p99")
row(">1µs  %",   "out_1us_pct",  pct=True)
row(">10µs %",   "out_10us_pct", pct=True)
row(">100µs%",   "out_100us_pct",pct=True)

print()
print(f"  A = {la}  ({a['metadata'].get('timestamp','?')})")
print(f"  B = {lb}  ({b['metadata'].get('timestamp','?')})")
print()
CMP_SCRIPT

# ── Argument parsing ───────────────────────────────────────────────────────────
TARGET=""; SAMPLES=300; MINUTES=""; OUTPUT_FILE=""; NO_SAVE=false
COMPARE_A=""; COMPARE_B=""; LABEL=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --samples)  SAMPLES="$2";     shift 2 ;;
        --minutes)  MINUTES="$2";     shift 2 ;;
        --output)   OUTPUT_FILE="$2"; shift 2 ;;
        --no-save)  NO_SAVE=true;     shift ;;
        --compare)  COMPARE_A="$2"; COMPARE_B="$3"; shift 3 ;;
        --label)    LABEL="$2";       shift 2 ;;
        --help|-h)  sed -n '2,22p' "$0" | sed 's/^# \?//'; exit 0 ;;
        -*)         echo "Unknown option: $1" >&2; exit 1 ;;
        *)  [[ -z "$TARGET" ]] && { TARGET="$1"; shift; } || { echo "Unexpected: $1" >&2; exit 1; } ;;
    esac
done

# ── Compare mode ───────────────────────────────────────────────────────────────
if [[ -n "$COMPARE_A" ]]; then
    [[ -f "$COMPARE_A" ]] || { echo "File not found: $COMPARE_A" >&2; exit 1; }
    [[ -f "$COMPARE_B" ]] || { echo "File not found: $COMPARE_B" >&2; exit 1; }
    python3 "$COMPARE_PY" "$COMPARE_A" "$COMPARE_B"
    exit 0
fi

# ── Collect mode ───────────────────────────────────────────────────────────────
# Build SSH prefix
SSH_PREFIX=()
[[ -n "$TARGET" ]] && SSH_PREFIX=(ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 "$TARGET" --)

run_remote() { "${SSH_PREFIX[@]}" "$@"; }

REMOTE_HOST=$(run_remote hostname 2>/dev/null || echo "localhost")
[[ -z "$LABEL" ]] && LABEL="$REMOTE_HOST"

echo -e "${BOLD}PTP Jitter Benchmark${RESET}  —  ${CYAN}${LABEL}${RESET}"

# Build journalctl time window
# statime emits ~40 TRACE offset measurements/sec at loglevel=trace
# For --samples N: fetch SAMPLES/40 seconds + 30s buffer; for --minutes M: use --since
if [[ -n "$MINUTES" ]]; then
    JCTL_SINCE="--since=-${MINUTES}min"
    echo -e "${DIM}  collecting last ${MINUTES} minutes of journal...${RESET}"
else
    WINDOW_SEC=$(( (SAMPLES / 40) + 30 ))
    JCTL_SINCE="--since=-${WINDOW_SEC}s"
    echo -e "${DIM}  collecting ~${SAMPLES} samples (~${WINDOW_SEC}s window)...${RESET}"
fi

# Remote awk command: extract offset values from TRACE "Estimated offset" lines
# Pattern: "Estimated offset" + capture value in ns
AWK_PROG='
/Estimated offset/ {
    if (match($0, /Estimated offset ([+-]?[0-9.]+)ns/, a)) {
        v = a[1] + 0
        if (v < 1e10 && v > -1e10) print a[1]
    }
}
'

# Build the remote command as a single string (SSH passes it to remote shell)
JCTL_CMD="journalctl -u statime-inferno $JCTL_SINCE --no-pager 2>/dev/null"

RAW_OFFSETS=""
if [[ ${#SSH_PREFIX[@]} -gt 0 ]]; then
    # Pass as a single quoted arg; use printf to safely escape the awk program
    RAW_OFFSETS=$(ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 "$TARGET" \
        "journalctl -u statime-inferno $JCTL_SINCE --no-pager 2>/dev/null" \
        | awk "$AWK_PROG") || true
else
    RAW_OFFSETS=$(eval "$JCTL_CMD" | awk "$AWK_PROG") || true
fi

if [[ -z "$RAW_OFFSETS" ]]; then
    echo -e "${YELLOW}ERROR: No PTP measurements found.${RESET}" >&2
    echo "  Is statime-inferno active?  Try: systemctl is-active statime-inferno" >&2
    exit 1
fi

TOTAL_COUNT=$(echo "$RAW_OFFSETS" | wc -l)

# Trim to requested sample count if using sample-based window
if [[ -z "$MINUTES" && "$TOTAL_COUNT" -gt "$SAMPLES" ]]; then
    RAW_OFFSETS=$(echo "$RAW_OFFSETS" | tail -n "$SAMPLES")
fi

SAMPLE_COUNT=$(echo "$RAW_OFFSETS" | wc -l)
echo -e "${DIM}  found ${TOTAL_COUNT} measurements, using ${SAMPLE_COUNT}${RESET}"
[[ "$SAMPLE_COUNT" -lt 10 ]] && echo -e "${YELLOW}  WARNING: very few samples — results may not be representative${RESET}" >&2

# Compute statistics
STATS_JSON=$(echo "$RAW_OFFSETS" | python3 "$STATS_PY")

if echo "$STATS_JSON" | python3 -c "import json,sys; d=json.load(sys.stdin); sys.exit(0 if 'error' not in d else 1)" 2>/dev/null; then
    : # ok
else
    echo "ERROR: Statistics computation failed" >&2; exit 1
fi

# Helper: extract a stat field
stat() {
    echo "$STATS_JSON" | python3 -c "
import json,sys
d = json.load(sys.stdin)
v = d.get('$1')
if v is None: print('N/A')
elif isinstance(v, int): print(v)
else: print(f'{v:.6f}')
"
}

# Helper: format nanoseconds
ns() {
    local v="$1"
    python3 -c "
v = float('$v')
a = abs(v)
if a < 1e3:  print(f'{v:.1f} ns')
elif a < 1e6: print(f'{v/1e3:.2f} µs')
else:         print(f'{v/1e6:.3f} ms')
" 2>/dev/null || echo "$v ns"
}

TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
COUNT=$(stat count)
MEAN=$(stat mean); STDDEV=$(stat stddev)
VMIN=$(stat min);  VMAX=$(stat max); ABS_MAX=$(stat abs_max)
P50=$(stat p50); P95=$(stat p95); P99=$(stat p99)
OUT1=$(stat out_1us_pct); OUT10=$(stat out_10us_pct); OUT100=$(stat out_100us_pct)

# Quality classification
GRADE=$(python3 -c "
am = float('$ABS_MAX')
if am < 50e3:   print('HW_PTP')   # < 50µs abs max
elif am < 1e6:  print('RT_SW')    # < 1ms
else:           print('STD_SW')   # >= 1ms
")

# Print results
echo ""
echo -e "${BOLD}Results: ${CYAN}${LABEL}${RESET}  ${DIM}${TIMESTAMP}${RESET}"
echo    "─────────────────────────────────────────"
printf "  %-20s %s\n"  "Samples:"         "$COUNT"
printf "  %-20s %s\n"  "Mean offset:"     "$(ns "$MEAN")"
printf "  %-20s %s\n"  "Std deviation:"   "$(ns "$STDDEV")"
printf "  %-20s %s\n"  "Min:"             "$(ns "$VMIN")"
printf "  %-20s %s\n"  "Max:"             "$(ns "$VMAX")"
printf "  %-20s %s\n"  "Abs max:"         "$(ns "$ABS_MAX")"
printf "  %-20s %s\n"  "p50 (median):"    "$(ns "$P50")"
printf "  %-20s %s\n"  "p95:"             "$(ns "$P95")"
printf "  %-20s %s\n"  "p99:"             "$(ns "$P99")"
echo    "─────────────────────────────────────────"
printf "  %-20s %.1f%%\n" "Outliers >1µs:"   "$OUT1"
printf "  %-20s %.1f%%\n" "Outliers >10µs:"  "$OUT10"
printf "  %-20s %.1f%%\n" "Outliers >100µs:" "$OUT100"
echo ""
case "$GRADE" in
    HW_PTP) echo -e "  ${GREEN}★ Excellent — HW PTP class (abs max < 50µs)${RESET}" ;;
    RT_SW)  echo -e "  ${YELLOW}◆ Good — RT-tuned SW PTP (abs max < 1ms)${RESET}" ;;
    STD_SW) echo -e "  ${YELLOW}◇ Typical — Standard SW PTP (abs max ≥ 1ms)${RESET}" ;;
esac
echo ""

# Save JSON
if ! $NO_SAVE; then
    [[ -z "$OUTPUT_FILE" ]] && OUTPUT_FILE="${LABEL//@/_}-ptp-$(date +%Y%m%d-%H%M%S).json"
    # Write raw offsets to temp file for JSON embedding
    RAW_OFFSETS_TMP=".ptp-bench-offsets-$$"
    echo "$RAW_OFFSETS" > "$RAW_OFFSETS_TMP"
    trap "rm -f '$RAW_OFFSETS_TMP'" RETURN
    python3 - <<PYEOF
import json
stats_raw = json.loads("""$STATS_JSON""")
with open("$RAW_OFFSETS_TMP") as _f:
    samples = [float(l) for l in _f if l.strip()]
result = {
    "label": "$LABEL",
    "host":  "$REMOTE_HOST",
    "metadata": {
        "timestamp": "$TIMESTAMP",
        "sample_count": $COUNT,
        "grade": "$GRADE",
        "tool": "ptp-bench.sh"
    },
    "stats": {
        "mean":           stats_raw["mean"],
        "stddev":         stats_raw["stddev"],
        "min":            stats_raw["min"],
        "max":            stats_raw["max"],
        "abs_max":        stats_raw["abs_max"],
        "p50":            stats_raw["p50"],
        "p95":            stats_raw["p95"],
        "p99":            stats_raw["p99"],
        "out_1us_pct":    stats_raw["out_1us_pct"],
        "out_10us_pct":   stats_raw["out_10us_pct"],
        "out_100us_pct":  stats_raw["out_100us_pct"],
    },
    "samples": samples
}
with open("$OUTPUT_FILE", "w") as f:
    json.dump(result, f, indent=2)
print(f"  Saved → $OUTPUT_FILE")
PYEOF
fi
