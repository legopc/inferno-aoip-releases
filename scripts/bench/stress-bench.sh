#!/bin/bash
# stress-bench.sh — System stress test with PTP jitter correlation
#
# Runs phased system stress (CPU, memory, network) while collecting PTP offset
# samples. Reports how system load degrades PTP stability — useful for comparing
# HW vs SW PTP under load, or validating RT kernel improvements.
#
# Does NOT modify statime/inferno/dante binaries. Uses stress-ng and cyclictest.
#
# Requires on target node:
#   - stress-ng   (dnf install stress-ng)
#   - rt-tests    (dnf install rt-tests  — provides cyclictest)
#   - python3, awk (pre-installed in image)
#
# Usage:
#   stress-bench.sh [user@host] [options]
#
# Options:
#   --phase-duration N  Seconds per stress phase (default: 60)
#   --ptp-samples N     PTP samples per phase (default: 100)
#   --skip-network      Skip iperf3 network stress phase
#   --output FILE       Save JSON report (default: auto-named)
#   --no-save           Skip JSON output
#   --dry-run           Show plan without executing
#   --help
#
# Examples:
#   stress-bench.sh core@192.168.1.43
#   stress-bench.sh core@192.168.1.43 --phase-duration 30 --ptp-samples 50
#   stress-bench.sh core@192.168.1.43 --skip-network --output stress-hw.json

set -euo pipefail

BOLD='\033[1m'; CYAN='\033[0;36m'; GREEN='\033[0;32m'
RED='\033[0;31m'; YELLOW='\033[1;33m'; RESET='\033[0m'; DIM='\033[2m'

TARGET=""; PHASE_DUR=60; PTP_SAMPLES=100; SKIP_NET=false
OUTPUT_FILE=""; NO_SAVE=false; DRY_RUN=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --phase-duration) PHASE_DUR="$2";    shift 2 ;;
        --ptp-samples)    PTP_SAMPLES="$2";  shift 2 ;;
        --skip-network)   SKIP_NET=true;     shift ;;
        --output)         OUTPUT_FILE="$2";  shift 2 ;;
        --no-save)        NO_SAVE=true;      shift ;;
        --dry-run)        DRY_RUN=true;      shift ;;
        --help|-h)        sed -n '2,28p' "$0" | sed 's/^# \?//'; exit 0 ;;
        -*)               echo "Unknown option: $1" >&2; exit 1 ;;
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
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

echo -e "${BOLD}Inferno Stress Benchmark${RESET}  —  ${CYAN}${REMOTE_HOST}${RESET}"
echo -e "${DIM}Phase duration: ${PHASE_DUR}s | PTP samples/phase: ${PTP_SAMPLES}${RESET}"

# ── Dependency check ──────────────────────────────────────────────────────────
echo -e "\n  ${BOLD}Checking dependencies on ${REMOTE_HOST}...${RESET}"
HAS_STRESS=$(run_remote_sh "which stress-ng 2>/dev/null && echo yes || echo no") || HAS_STRESS=no
HAS_CYCLIC=$(run_remote_sh "which cyclictest 2>/dev/null && echo yes || echo no") || HAS_CYCLIC=no
HAS_IPERF=$(run_remote_sh "which iperf3 2>/dev/null && echo yes || echo no") || HAS_IPERF=no
HAS_STRESS=$(echo "$HAS_STRESS" | head -1 | tr -d '[:space:]')
HAS_CYCLIC=$(echo "$HAS_CYCLIC" | head -1 | tr -d '[:space:]')
HAS_IPERF=$(echo "$HAS_IPERF"  | head -1 | tr -d '[:space:]')

printf "  %-16s %b\n" "stress-ng:" "$([[ "$HAS_STRESS" == yes ]] && echo "${GREEN}found${RESET}" || echo "${RED}missing — dnf install stress-ng${RESET}")"
printf "  %-16s %b\n" "cyclictest:" "$([[ "$HAS_CYCLIC" == yes ]] && echo "${GREEN}found${RESET}" || echo "${YELLOW}missing (optional) — dnf install rt-tests${RESET}")"
printf "  %-16s %b\n" "iperf3:" "$([[ "$HAS_IPERF"  == yes ]] && echo "${GREEN}found${RESET}" || echo "${DIM}not found (network phase skipped)${RESET}")"

if [[ "$HAS_STRESS" != "yes" ]] && ! $DRY_RUN; then
    echo -e "\n  ${RED}ERROR: stress-ng is required. Install with: dnf install stress-ng${RESET}"
    echo -e "  ${DIM}stress-ng is not yet in the Inferno image — run from Containerfile or dnf manually${RESET}"
    exit 1
fi

[[ "$HAS_IPERF" != "yes" ]] && SKIP_NET=true

# Phases to run
PHASES=("baseline" "cpu" "memory")
$SKIP_NET || PHASES+=("network")
PHASES+=("recovery")

echo -e "\n  Phases: ${PHASES[*]}"
echo -e "  Total estimated time: $(( ${#PHASES[@]} * PHASE_DUR ))s"

$DRY_RUN && { echo -e "\n  ${DIM}[dry-run] Exiting without executing${RESET}"; exit 0; }

# ── PTP sample collection helper ──────────────────────────────────────────────
collect_ptp_stats() {
    local window_sec=$1
    local raw
    raw=$(run_remote_sh \
        "journalctl -u statime-inferno --since=-${window_sec}s --no-pager 2>/dev/null" \
        | awk '/INFO.*Measurement.*offset: Some\(Duration/ {
            n = split($0, p, "inner:")
            for (i=2;i<=n;i++) {
                v=p[i]; gsub(/^[ ]+/,"",v); gsub(/[ }),].*/,"",v)
                x = v+0; if (x < 1e10 && x > -1e10) print v
            }
        }' | tail -n "$PTP_SAMPLES") || raw=""

    if [[ -z "$raw" ]]; then
        echo '{"error":"no_data","count":0}'
        return
    fi

    echo "$raw" | python3 -c "
import sys, json, math
vals = [float(l.strip()) for l in sys.stdin if l.strip()]
if not vals: print(json.dumps({'error':'no_data','count':0})); exit()
n = len(vals); sv = sorted(vals); av = [abs(v) for v in vals]
mean = sum(vals)/n
sd = math.sqrt(sum((v-mean)**2 for v in vals)/n)
def p(s,q): i=(q/100)*(len(s)-1); lo=int(i); hi=min(lo+1,len(s)-1); return s[lo]+(i-lo)*(s[hi]-s[lo])
print(json.dumps({'count':n,'mean':mean,'stddev':sd,'abs_max':max(av),'p95':p(sv,95),'p99':p(sv,99)}))
"
}

# ── Service health snapshot ────────────────────────────────────────────────────
service_ok() {
    local ok=0
    for svc in inferno-bridge statime-inferno; do
        local cmd
        [[ "$svc" == "statime-inferno" ]] && cmd="systemctl is-active $svc" || cmd="systemctl --user is-active $svc"
        local st; st=$(run_remote_sh "$cmd 2>/dev/null || echo inactive") || st="inactive"
        st=$(echo "$st" | head -1 | tr -d '[:space:]')
        [[ "$st" == "active" ]] && ((ok++)) || true
    done
    echo "$ok"  # 0, 1, or 2
}

# ── Run each phase ─────────────────────────────────────────────────────────────
declare -A PHASE_STATS
declare -A PHASE_SVC

for phase in "${PHASES[@]}"; do
    echo ""
    echo -e "  ${BOLD}Phase: ${CYAN}${phase}${RESET}  ${DIM}(${PHASE_DUR}s)${RESET}"

    # Start stressor (background on remote)
    case "$phase" in
        baseline)
            echo -e "  ${DIM}Running baseline — no stress${RESET}"
            run_remote_sh "sleep $PHASE_DUR &" 2>/dev/null || true
            ;;
        cpu)
            NCPU=$(run_remote_sh "nproc 2>/dev/null || echo 2") || NCPU=2
            NCPU=$(echo "$NCPU" | head -1 | tr -d '[:space:]')
            echo -e "  ${DIM}CPU stress: ${NCPU} workers for ${PHASE_DUR}s${RESET}"
            run_remote_sh "stress-ng --cpu $NCPU --timeout ${PHASE_DUR}s --quiet >/dev/null 2>&1 &" || true
            ;;
        memory)
            echo -e "  ${DIM}Memory stress: 2 workers × 256MB for ${PHASE_DUR}s${RESET}"
            run_remote_sh "stress-ng --vm 2 --vm-bytes 256M --timeout ${PHASE_DUR}s --quiet >/dev/null 2>&1 &" || true
            ;;
        network)
            echo -e "  ${DIM}Network stress: iperf3 client for ${PHASE_DUR}s${RESET}"
            run_remote_sh "iperf3 -c 127.0.0.1 -t $PHASE_DUR -P 4 >/dev/null 2>&1 &" 2>/dev/null || true
            ;;
        recovery)
            echo -e "  ${DIM}Recovery — no stress, waiting ${PHASE_DUR}s${RESET}"
            run_remote_sh "sleep $PHASE_DUR &" 2>/dev/null || true
            ;;
    esac

    # Wait for phase duration + collect PTP in parallel
    sleep "$PHASE_DUR"

    echo -e "  ${DIM}Collecting PTP samples...${RESET}"
    local_stats=$(collect_ptp_stats "$((PHASE_DUR + 10))")
    svc_ok=$(service_ok)

    PHASE_STATS[$phase]="$local_stats"
    PHASE_SVC[$phase]="$svc_ok"

    # Quick summary line
    abs_max=$(echo "$local_stats" | python3 -c "import json,sys; d=json.load(sys.stdin); v=d.get('abs_max',0); print(f'{v/1000:.1f} µs' if abs(v)<1e6 else f'{v/1e6:.2f} ms')" 2>/dev/null || echo "?")
    p99=$(echo "$local_stats" | python3 -c "import json,sys; d=json.load(sys.stdin); v=d.get('p99',0); print(f'{v/1000:.1f} µs' if abs(v)<1e6 else f'{v/1e6:.2f} ms')" 2>/dev/null || echo "?")
    svc_str=$([[ "$svc_ok" == "2" ]] && echo "${GREEN}OK${RESET}" || echo "${YELLOW}${svc_ok}/2 services active${RESET}")
    echo -e "  abs_max=${abs_max}  p99=${p99}  services=${svc_str}"
done

# ── Summary table ─────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}Stress Benchmark Results — ${CYAN}${REMOTE_HOST}${RESET}"
echo "─────────────────────────────────────────────────────────"
printf "  %-12s %10s %10s %10s %8s\n" "Phase" "abs_max" "p95" "p99" "Services"
echo "  ────────── ────────── ────────── ────────── ────────"

fmt_ns() {
    python3 -c "
v = float('${1:-0}')
a = abs(v)
if a < 1e3:  print(f'{v:.0f}ns')
elif a < 1e6: print(f'{v/1e3:.1f}µs')
else:         print(f'{v/1e6:.2f}ms')
" 2>/dev/null || echo "?"
}

declare -A SUMMARY_JSON

for phase in "${PHASES[@]}"; do
    stats="${PHASE_STATS[$phase]:-{}}"
    svc="${PHASE_SVC[$phase]:-?}"

    abs_max=$(echo "$stats" | python3 -c "import json,sys;d=json.load(sys.stdin);print(d.get('abs_max',0))" 2>/dev/null || echo 0)
    p95=$(echo "$stats" | python3 -c "import json,sys;d=json.load(sys.stdin);print(d.get('p95',0))" 2>/dev/null || echo 0)
    p99=$(echo "$stats" | python3 -c "import json,sys;d=json.load(sys.stdin);print(d.get('p99',0))" 2>/dev/null || echo 0)

    svc_col=$([[ "$svc" == "2" ]] && echo "$GREEN" || echo "$YELLOW")
    printf "  ${BOLD}%-12s${RESET} %10s %10s %10s %b%8s%b\n" \
        "$phase" "$(fmt_ns "$abs_max")" "$(fmt_ns "$p95")" "$(fmt_ns "$p99")" \
        "$svc_col" "${svc}/2" "$RESET"

    SUMMARY_JSON[$phase]="{\"abs_max\":$abs_max,\"p95\":$p95,\"p99\":$p99,\"services_ok\":$svc}"
done
echo ""

# Degradation ratio (cpu phase vs baseline)
BASE_MAX=$(echo "${PHASE_STATS[baseline]:-{}}" | python3 -c "import json,sys;d=json.load(sys.stdin);print(d.get('abs_max',1))" 2>/dev/null || echo 1)
CPU_MAX=$(echo "${PHASE_STATS[cpu]:-{}}" | python3 -c "import json,sys;d=json.load(sys.stdin);print(d.get('abs_max',1))" 2>/dev/null || echo 1)
RATIO=$(python3 -c "
b,c = float('$BASE_MAX'), float('$CPU_MAX')
if b > 0: print(f'{c/b:.1f}')
else: print('N/A')
" 2>/dev/null || echo "?")
echo -e "  PTP degradation ratio (CPU vs baseline): ${BOLD}${RATIO}×${RESET}"

# Save JSON report
if ! $NO_SAVE; then
    [[ -z "$OUTPUT_FILE" ]] && OUTPUT_FILE="${REMOTE_HOST}-stress-$(date +%Y%m%d-%H%M%S).json"
    python3 -c "
import json
phases = {}
$(for p in "${PHASES[@]}"; do echo "phases['$p'] = ${SUMMARY_JSON[$p]:-{}}"; done)
result = {
    'label': '$REMOTE_HOST',
    'host': '$REMOTE_HOST',
    'metadata': {
        'timestamp': '$TIMESTAMP',
        'phase_duration_sec': $PHASE_DUR,
        'tool': 'stress-bench.sh'
    },
    'phases': phases,
    'degradation_ratio': '$RATIO'
}
with open('$OUTPUT_FILE', 'w') as f:
    json.dump(result, f, indent=2)
print(f'  Saved → $OUTPUT_FILE')
"
fi
