# Ansible Playbook Validation Results

## Target

VM: `INFERNO-ARCH-TEST-01` (Proxmox VMID 105, PRX-02)  
Hardware equivalent: HP EliteDesk 800 G2 Mini (Intel I219-LM → emulated via virtio)  
Date: 2026-04-02  
Ansible version: 2.18.x (ansible-core from pip)  
Arch Linux kernel: 6.19.10-arch1-1

---

## Pre-flight: DNS fix required (fresh Arch install)

Fresh Arch installs with `systemd-networkd` + `systemd-resolved` have an **empty** `/etc/resolv.conf`.  
Without this fix, `yay` (Go binary) and all internet access will fail DNS.

```bash
sudo ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf
```

**This is now handled automatically by the Ansible playbook** (first task in `base` role).

---

## Full Provision Result (fresh VM — first ever run)

```
PLAY RECAP **************************************************************
inferno-node : ok=60  changed=21  unreachable=0  failed=0  skipped=5  rescued=0  ignored=0
```

Failed tasks: **none**  
Warnings: **none**

Notable changes on first run:
- Installed 14 system packages (yay, alsa-utils, pipewire, avahi, etc.)
- Built `yay` from AUR source
- Built `statime-linux` from source (inferno-dev branch)
- Built `libasound_module_pcm_inferno.so` from source
- Installed `librespot` via `yay` (AUR, builds from Rust source)
- Deployed `.asoundrc`, ALSA plugin config, PTP config
- Deployed 4 user systemd services + system statime service
- Enabled linger, enabled and started all services

---

## Service Verification (post-Ansible, manually enabled librespot + bridge)

| Service | Status | Notes |
|---------|--------|-------|
| `statime-inferno` (system) | ✅ active | PTPv1 master mode (no external grandmaster in VM) |
| `librespot` (user) | ✅ active | Spotify Connect visible on network |
| `inferno-keepalive` (user) | ✅ active | Writes to `inferno_mix` (loopback) continuously |
| `inferno-bridge` (user) | ✅ active | Loops `hw:Loopback,1,0` → `inferno_spotify`; fails/restarts without PTP clock (expected in VM) |
| `librespot-watchdog` (user) | ✅ active | Monitors librespot journal, restarts on audio key errors |
| Avahi / Spotify Connect visible | ✅ yes | `avahi-daemon` active; device appears in Spotify app |
| `systemd-timesyncd` masked | ✅ yes | Masked to prevent conflict with statime PTP |
| `~/bin/inferno-sink-event` | ✅ executable | |
| `~/bin/librespot-watchdog` | ✅ executable | |

> **VM Note**: `inferno-bridge` will restart every ~5s in a VM because `statime` becomes PTPv1
> master (no Dante grandmaster on network) but "PTPv1 master not implemented" in the inferno fork.
> The ALSA plugin times out waiting for the clock overlay and exits. This is **expected behavior** —
> on real hardware with a Dante device providing the PTP grandmaster, the bridge works correctly.
> All other services (4/5) work normally in VMs.

---

## Fix Applied: librespot and inferno-bridge not enabled by playbook

After the initial run, `librespot` and `inferno-bridge` were deployed but not enabled/started.
Fix: added enable tasks for both to `system-state` role.

```yaml
# Added to roles/system-state/tasks/main.yml
- name: Enable and start librespot user service
- name: Enable and start inferno-bridge user service
```

---

## Verdict

- [x] **Ready for HP EliteDesk 800 G2 production deployment**

Notes:
- Interface name on real I219-LM hardware will likely be `enp0s25` or `enp1s0` — update `group_vars/all.yml`
- First run takes ~30–60min (compiling Rust binaries from source)
- Second run (idempotency): all Rust build tasks skip via stamp files → expected 0 changed on builds
- DNS fix is now automatic (first task in base role)

---

## Fedora IoT Ansible Playbook — `site-fedora.yml` (2026-04-03)

**Target**: VM 110, `core@10.10.1.79`, Fedora IoT 42

**Result**: ✅ **59 ok, 0 failed** on first clean run after one required reboot

### New files created
- `site-fedora.yml` — Fedora-specific playbook (6 roles)
- `inventory-fedora.yml` — VM 110 target (10.10.1.79)
- `roles/fedora-base/` — rpm-ostree packages, snd-aloop, audio group fix
- `roles/fedora-rust/` — rustup via `{{ inferno_home }}` (handles `/var/home/core/` path)
- `roles/fedora-build/` — podman container builds for inferno, statime, librespot
- `roles/fedora-alsa/` — ALSA + SELinux contexts
- `roles/fedora-services/` — user systemd units + scripts
- `roles/fedora-system-state/` — linger, timesyncd mask, enable all services
- `templates-fedora/` — 10 Fedora-specific templates

### Fixes found during test run
1. `rpm-ostree install --idempotent` errors if package is in base image (e.g. podman). Fix: add `--allow-inactive`
2. After `rpm-ostree install` stages a new deployment, playbook correctly halts with "Reboot required" message. LUKS keyfile was already embedded → VM auto-unlocked

### Verified on VM 110 post-run
- `statime-inferno`, `avahi-daemon`: active
- `inferno-bridge`, `inferno-keepalive`, `librespot`, `librespot-watchdog`: all active
- SELinux: `lib_t` on `.so`, `bin_t` on `statime` binary
- librespot advertising `Fedora-IoT` via mDNS (no `--ap-port`)

---

## Bug Fix: librespot-watchdog ordering cycle (2026-04-03)

**Problem**: `librespot-watchdog.service` had `After=librespot.service`. Combined with
`inferno-bridge.service` having `Before=librespot.service`, systemd detected a cycle through
`default.target` and dropped the watchdog start job entirely.

**Effect**: Watchdog was **silently inactive** on dante-doos — 14 unhandled "Unable to load key"
events over 48h went undetected.

**Fix**: Removed `After=librespot.service` from `templates/librespot-watchdog.service.j2`.
Watchdog has no ordering requirement against librespot — it only reads the journal.
Applied fix to dante-doos manually; Fedora template uses correct version from the start.

---

## Change: alsaloop replaces arecord|aplay in all bridge services (2026-04-03)

**Problem**: The `arecord | aplay` pipe in `inferno-bridge.service` uses ALSA's default buffer
sizes (~500 ms+). This is fine for the TX bridge (nobody notices 500 ms of extra Spotify latency),
but the same pattern in the dante-doos RX→analog path (`inferno-aux-rx.service`) caused 500 ms–1 s
of audible delay between the Dante network and the 3.5mm analog output.

**Root cause**: Without explicit `--buffer-size` and `--period-size` flags, `arecord` buffers
hundreds of milliseconds of audio before writing to the pipe. `aplay` then buffers again before
sending to hardware.

**Fix**: Replace `arecord | aplay` with `alsaloop` in all bridge services:

| Service | Role | `-t` value | Reason |
|---------|------|------------|--------|
| `inferno-bridge.service` | TX: loopback → Dante | 20 ms | Latency non-critical; 20 ms gives more headroom |
| `inferno-rx.service` | RX: Dante → analog out | 10 ms | Match Dante receive latency setting |
| `inferno-aux-rx.service` | RX: Dante → analog out | 10 ms | Same as above |
| `inferno-aux-tx.service` | TX: analog in → Dante | 10 ms | Low ALC221 capture latency achievable |

`alsaloop` benefits:
- Single process (no shell pipe, no two-process overhead)
- Explicit transfer latency via `-t <usec>`
- SAMPLERATE sync (compensates for clock drift between capture and playback clocks)
- Cleaner xrun handling (no broken-pipe cascade)

**Applied to**: `templates/inferno-bridge.service.j2`, `templates-fedora/inferno-bridge.service.j2`,
`Inferno_OS_Hardening/nix/home/inferno-aoip.nix`, `Inferno_AoIP_AUX/config/systemd-user/`.
Live nodes: dante-doos (`inferno-rx`) and EliteDesk-01 (`inferno-bridge`) updated in place.
