# Inferno AoIP — Benchmarking & Diagnostics

The `scripts/bench/` directory contains a non-intrusive suite for measuring PTP
jitter, ALSA pipeline health, Dante network health, audio quality, and system
stress response. None of these scripts modify statime, inferno, or Dante packages
— they read from the kernel, journald, and mDNS only.

The same tools are surfaced in the **🩺 Diagnostics** tab in the Cockpit web UI
(`https://<node-ip>:9090` → Inferno → Diagnostics).

---

## Scripts

| Script | Purpose | Tested |
|--------|---------|--------|
| `ptp-bench.sh` | PTP jitter stats (min/max/mean/p95/p99/stddev) + compare two runs | ✅ EliteDesk-01 |
| `alsa-health.sh` | snd-aloop state, PCM status, xrun events, service health | ✅ EliteDesk-01 |
| `dante-network-bench.sh` | mDNS device discovery, PTP port check, service status | ✅ EliteDesk-01 |
| `audio-loopback-test.sh` | Audio pipeline health (ALSA fallback, or full signal analysis with inferno2pipe+ffmpeg) | ✅ EliteDesk-01 |
| `stress-bench.sh` | Phased CPU/memory/network stress with PTP correlation per phase | Needs stress-ng in image |
| `inferno-bench.sh` | Master orchestrator — runs all components, saves timestamped report | ✅ EliteDesk-01 |

All scripts take an optional `user@host` as the first argument for remote execution.
Without it they run locally (e.g. from within a node).

---

## Quick Start

```bash
# Clone the repo
git clone https://github.com/legopc/inferno-aoip-releases
cd inferno-aoip-releases

# Quick health snapshot (~2 min: PTP + ALSA + Dante)
bash scripts/bench/inferno-bench.sh core@192.168.1.43 --mode quick

# Full benchmark including stress (~15 min)
bash scripts/bench/inferno-bench.sh core@192.168.1.43 --mode full --label hw-ptp

# PTP only (300 samples)
bash scripts/bench/inferno-bench.sh core@192.168.1.43 --mode ptp-only --label before-change
```

Reports are saved to `~/.inferno-bench/<label>-<timestamp>/`.

---

## Before/After Comparison

The suite is designed for before-and-after workflows — capture a baseline,
make a change (config, image, hardware), capture again, then compare:

```bash
# 1. Capture baseline
bash scripts/bench/inferno-bench.sh core@192.168.1.43 \
    --mode ptp-only --label baseline

# 2. Make the change (e.g. switch PTP config, rebuild image, replace NIC)

# 3. Capture after
bash scripts/bench/inferno-bench.sh core@192.168.1.43 \
    --mode ptp-only --label after-change

# 4. Compare (paths auto-expand with glob)
bash scripts/bench/inferno-bench.sh \
    --compare ~/.inferno-bench/baseline-*/ \
              ~/.inferno-bench/after-change-*/
```

---

## HW PTP vs SW PTP Comparison

The key comparison in the Inferno context is hardware-assisted PTP (Intel I219-LM,
Intel X550) vs software-only PTP (Realtek RTL8111, generic NICs).

```bash
# Collect from HW PTP node
bash scripts/bench/ptp-bench.sh core@192.168.1.43 \
    --samples 300 --label hw-ptp --output /tmp/hw-ptp.json

# Collect from SW PTP node (needs SSH key: ssh-copy-id core@192.168.1.25)
bash scripts/bench/ptp-bench.sh core@192.168.1.25 \
    --samples 300 --label sw-ptp --output /tmp/sw-ptp.json

# Side-by-side comparison
bash scripts/bench/ptp-bench.sh --compare /tmp/hw-ptp.json /tmp/sw-ptp.json
```

### Measured baselines (lab hardware, April 2026)

| Node | NIC | PTP Type | Abs max | p99 | Mean |
|------|-----|----------|---------|-----|------|
| EliteDesk-01 (`192.168.1.43`) | Intel I219-LM | HW timestamps | ~22 µs | ~22 µs | ~8 µs |
| dante-doos (`192.168.1.25`) | Realtek RTL8111 | SW only | TBD | TBD | TBD |

> **Note:** The Intel I219-LM values (~22 µs) are higher than theoretical hardware PTP
> (<1 µs typical). This reflects that statime is not yet fully utilising hardware
> timestamping — tracked as an improvement item in `IMPROVEMENT_ROADMAP.md`.

---

## PTP Grade Reference

| Grade | Abs max | Meaning |
|-------|---------|---------|
| ★ Excellent — HW PTP class | < 50 µs | NIC hardware timestamps active |
| ✓ Good — RT SW PTP | < 1 ms | RT kernel, adequate for Dante |
| ⚠ Marginal | < 5 ms | Standard kernel SW PTP — may cause glitches |
| ✗ Poor | ≥ 5 ms | Investigate kernel, network, or statime config |

---

## Audio Quality Test

The audio test has two modes depending on what is installed in the image:

**ALSA fallback (always available):**
Monitors `inferno-bridge` journal for xrun/underrun/overrun events during the window.
```bash
bash scripts/bench/audio-loopback-test.sh core@192.168.1.43 --duration 30
```

**Full signal analysis (requires `inferno2pipe` + `ffmpeg` in image):**
Captures Dante RX audio through `inferno2pipe` and analyses with ffmpeg:
- Silence detection (dropouts)
- Integrated loudness (LUFS)
- True peak (dBTP)
- Dropout rate %

To enable: build the image with `inferno2pipe` binary copied in and `ffmpeg-free` from
RPM Fusion added to the Containerfile.

---

## Stress Benchmark

Tests PTP stability under CPU, memory, and network load. Use to verify that the
RT scheduling configuration prevents Dante/PTP from being impacted by other workloads.

```bash
# Requires stress-ng in image (added to Containerfile as of this suite)
bash scripts/bench/stress-bench.sh core@192.168.1.43 \
    --phase-duration 60 \
    --output /tmp/stress-result.json

# Preview what would run without executing stress
bash scripts/bench/stress-bench.sh core@192.168.1.43 --dry-run
```

Output: per-phase PTP stats (baseline / CPU / memory / network / recovery) +
service stability matrix. A healthy node should show <100 µs PTP offset even
under CPU and memory stress, with services remaining active throughout.

---

## Image-Installed Tools

When running from an Inferno node directly (not via SSH from dev machine), the
bench scripts are pre-installed at `/usr/local/sbin/inferno-bench/`:

```bash
# From the node itself
inferno-bench --mode quick        # via symlink at /usr/local/sbin/inferno-bench
inferno-bench --mode ptp-only
inferno-bench --mode health-only
```

Tools included in the image via Containerfile (`stress-ng`, `rt-tests`):
- `stress-ng` — system stress generator
- `cyclictest` (from `rt-tests`) — scheduler latency measurement
- `ss`, `avahi-browse`, `journalctl`, `python3`, `awk` — used internally by scripts

---

## Cockpit Diagnostics Tab

All bench scripts are accessible from the Cockpit web UI without SSH:

1. Open `https://<node-ip>:9090` and log in (`core` / `inferno123`)
2. Navigate to **Inferno** → **🩺 Diagnostics**
3. Cards:
   - **PTP Performance** — collect 5 min of samples, view sparkline + stats, export CSV
   - **ALSA Pipeline** — one-click ALSA health check
   - **Dante Network** — live device discovery (mDNS)
   - **Benchmark Runner** — run quick/full/ptp-only/health-only with live log output

---

## Adding to a New Node

If the node was built from an image that includes the bench suite (post-`cde60cb`
in this repo), the scripts are already at `/usr/local/sbin/inferno-bench/`.

For older images, deploy manually:
```bash
# Copy all bench scripts to node
rsync -avz scripts/bench/ core@192.168.1.43:/tmp/inferno-bench/

# Run from /tmp (or move to ~/bin/)
ssh core@192.168.1.43 "bash /tmp/inferno-bench/inferno-bench.sh --mode quick"
```

---

## Troubleshooting the Bench Scripts

**`ptp-bench.sh` shows 0 samples:**
```bash
ssh core@NODE "journalctl --user -u statime-inferno -n 5 --no-pager"
```
Check that statime-inferno is running and producing `offset: Some(Duration { inner:` lines.

**`dante-network-bench.sh` finds 0 devices:**
```bash
ssh core@NODE "systemctl is-active avahi-daemon"
ssh core@NODE "avahi-browse -t -p --resolve _netaudio-arc._udp"
```
avahi-daemon must be active and devices must have been powered on recently.

**`stress-bench.sh`: stress-ng not found:**
```bash
# Install on current image (rpm-ostree, not persistent across reboots)
ssh core@NODE "sudo rpm-ostree install stress-ng && sudo systemctl reboot"
# OR rebuild image (stress-ng already added to Containerfile)
```

**SSH from dev machine requires password:**
```bash
ssh-copy-id -i ~/.ssh/id_ed25519 core@192.168.1.25   # dante-doos
```
