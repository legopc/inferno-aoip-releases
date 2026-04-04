# Fedora IoT — Complete Inferno AoIP Build Guide

Full rebuild-from-scratch documentation for deploying the Inferno AoIP stack on Fedora IoT 42.
Based on the working VM 110 (10.10.1.79, `core` user) as of 2026-04-02.

> **For physical hardware (EliteDesk 800 G2):** See `ELITEDESK_FEDORA_DEPLOY.md` instead of Phase 1.
> The VM provisioner approach (Phase 1) is Proxmox-specific. Phases 2–14 apply to both VM and physical,
> with the following substitutions:
> - Replace `ens18` with actual NIC name (detect: `ip link show | grep '^[0-9].*: e'`)
> - Replace `DEVICE_ID=bc2411937d0a0000` with: `DEVICE_ID=$(cat /sys/class/net/$NIC/address | tr -d ':')0000`
> - **Gotcha #9 (LUKS keyfile re-embed) does NOT apply on physical hardware** — Anaconda LUKS persists across reboots

---

## Target Specs

| Item | Value |
|------|-------|
| OS | Fedora IoT 42 (rpm-ostree immutable) |
| Kernel | 6.15.7-200.fc42.x86_64 |
| User | `core` (default Fedora IoT user) |
| NIC (VM) | `ens18` |
| DEVICE_ID (VM) | `bc2411937d0a0000` |
| LUKS passphrase | `inferno123` (test only) |
| Binaries location | `/var/lib/inferno/bin/`, `/var/lib/inferno/alsa-plugins/` |
| librespot | `~/.cargo/bin/librespot` (built via cargo install) |

For real hardware: substitute `ens18` with actual NIC name and recompute DEVICE_ID:
```bash
NIC=<your_nic>
DEVICE_ID=$(cat /sys/class/net/$NIC/address | tr -d ':')0000
```

---

## Phase 1 — OS Provisioning (Fedora IoT via Provisioner ISO)

See `PROXMOX_RULES.md` for the full provisioning procedure including:
- Provisioner ISO URL and grub.cfg modification
- Ignition config for `core` user + SSH key
- LUKS setup and keyfile embedding
- BLS entry (`/boot/loader/entries/ostree-1.conf`) modification

**Key facts:**
- Fedora IoT uses OSTree — the root filesystem is immutable. Writable paths: `/var/`, `/etc/`, `/home/` (→ `/var/home/`)
- User home is at `/var/home/core/` (symlinked from `/home/core`)
- `sudo` works for `core` if configured in Ignition

---

## Phase 2 — System Packages (rpm-ostree)

`gcc`, `clang`, and `binutils` **cannot be layered** — they conflict with the locked glibc/libstdc++ in the base image. Only install what's needed for runtime headers and ALSA utilities:

```bash
sudo rpm-ostree install \
  alsa-lib alsa-lib-devel alsa-utils alsa-plugins-speex speexdsp git

# This stages the change — requires reboot to activate
sudo reboot
```

After reboot, the new deployment is active. **The new deployment has a fresh initramfs — the LUKS keyfile cpio must be re-embedded** (see LUKS section below).

---

## Phase 3 — LUKS Keyfile Re-embed

Every new rpm-ostree deployment generates a new initramfs without the keyfile. After each new deployment boots (you may need to enter the passphrase manually via Proxmox serial console):

```bash
# On the running VM:
INITRAMFS=$(ls /boot/ostree/fedora-*/initramfs-*.img | head -1)
mkdir -p /tmp/kf-cpio/etc/luks
echo -n "inferno123" > /tmp/kf-cpio/etc/luks/keyfile
(cd /tmp/kf-cpio && find . | cpio -o -H newc 2>/dev/null) | sudo tee -a "$INITRAMFS" > /dev/null

# Ensure BLS entries have luks.key= in kernel options:
for conf in /boot/loader/entries/*.conf; do
  grep -q "luks.key" "$conf" || sudo sed -i \
    's|^options |options luks.key=/etc/luks/keyfile console=ttyS0,115200n8 |' "$conf"
done
```

If the VM hangs at LUKS prompt (no SSH), send passphrase via Proxmox serial socket from PRX-01:
```bash
ssh -i ~/.ssh/inferno_proxmox root@10.10.1.201 \
  'echo "inferno123" | socat - UNIX-CONNECT:/var/run/qemu-server/110.serial0'
```

---

## Phase 4 — Rust Toolchain

```bash
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
source ~/.cargo/env
rustc --version  # should show 1.94.1+
```

---

## Phase 5 — Build Inferno ALSA Plugin

`gcc` cannot be layered on Fedora IoT 42. Use a Fedora 42 container for all compilation:

```bash
# Build in container, output to home dir (do NOT mount /var/lib/inferno — permission denied)
podman run --rm --security-opt label=disable \
  -v /var/home/core:/var/home/core \
  fedora:42 bash -c '
    dnf install -y gcc openssl-devel alsa-lib-devel
    export HOME=/var/home/core
    export CARGO_HOME=/var/home/core/.cargo
    export RUSTUP_HOME=/var/home/core/.rustup
    source /var/home/core/.cargo/env
    cd /var/home/core/inferno
    cargo build --release -p alsa_pcm_inferno
  '

# Note: cargo workspace puts output at ~/inferno/target/release/ (NOT alsa_pcm_inferno/target/)
sudo mkdir -p /var/lib/inferno/alsa-plugins
sudo install -m 755 ~/inferno/target/release/libasound_module_pcm_inferno.so \
  /var/lib/inferno/alsa-plugins/

# SELinux — make persistent with semanage (not just chcon)
sudo semanage fcontext -a -t lib_t '/var/lib/inferno/alsa-plugins(/.*)?'
sudo restorecon -Rv /var/lib/inferno/alsa-plugins/
```

### Clone the repo first:
```bash
cd ~
git clone https://gitlab.com/lumifaza/inferno --recurse-submodules
```

---

## Phase 6 — Build Statime

```bash
cd ~
git clone https://github.com/teodly/statime --recurse-submodules -b inferno-dev

podman run --rm --security-opt label=disable \
  -v /var/home/core:/var/home/core \
  fedora:42 bash -c '
    dnf install -y gcc
    export HOME=/var/home/core
    export CARGO_HOME=/var/home/core/.cargo
    export RUSTUP_HOME=/var/home/core/.rustup
    source /var/home/core/.cargo/env
    cd /var/home/core/statime
    cargo build --release --bin statime
  '

# Binary name is "statime" NOT "statime-linux" (renamed in inferno-dev branch)
sudo mkdir -p /var/lib/inferno/bin
sudo install -m 755 ~/statime/target/release/statime /var/lib/inferno/bin/statime

# SELinux — persistent
sudo semanage fcontext -a -t bin_t '/var/lib/inferno/bin(/.*)?'
sudo restorecon -Rv /var/lib/inferno/bin/
```

---

## Phase 7 — Build librespot

**Must use `--features=alsa-backend`** — the default build has no ALSA support:

```bash
podman run --rm --security-opt label=disable \
  -v /var/home/core:/var/home/core \
  fedora:42 bash -c '
    dnf install -y gcc openssl-devel alsa-lib-devel
    export HOME=/var/home/core
    export CARGO_HOME=/var/home/core/.cargo
    export RUSTUP_HOME=/var/home/core/.rustup
    source /var/home/core/.cargo/env
    cargo install librespot --features=alsa-backend --locked
  '

~/.cargo/bin/librespot --version
```

---

## Phase 8 — snd-aloop Kernel Module

```bash
echo "snd-aloop" | sudo tee /etc/modules-load.d/snd-aloop.conf
sudo modprobe snd-aloop
aplay -l | grep -i loopback   # should show Loopback card
```

---

## Phase 9 — audio Group Fix

On Fedora IoT, the `audio` group exists only in `/usr/lib/group` (immutable vendor layer).
`usermod -aG audio core` silently does nothing. Fix:

```bash
sudo sh -c 'echo "audio:x:63:core" >> /etc/group'
sudo systemctl restart user@1000.service
# Verify:
aplay -l   # should now show Loopback without "no soundcards found"
```

---

## Phase 10 — ALSA Configuration

### `/etc/alsa/conf.d/99-inferno.conf`
```
pcm_type.inferno {
  lib /var/lib/inferno/alsa-plugins/libasound_module_pcm_inferno.so
}
```

### `~/.asoundrc`
Substitute `ens18` and `bc2411937d0a0000` for your NIC and DEVICE_ID:

```
pcm_type.inferno {
    lib "/var/lib/inferno/alsa-plugins/libasound_module_pcm_inferno.so"
}

# Raw Inferno/Dante transmit device.
# ONLY inferno-bridge.service opens this — keeps DeviceServer permanently alive.
pcm.inferno_spotify {
    type inferno
    NAME "Fedora-IoT"
    BIND_IP ens18
    SAMPLE_RATE 48000
    PROCESS_ID 1
    ALT_PORT 6000
    RX_CHANNELS 0
    TX_CHANNELS 2
    TX_LATENCY_NS 10000000
    RX_LATENCY_NS 10000000
    CLOCK_PATH /tmp/ptp-usrvclock
    DEVICE_ID bc2411937d0a0000
    hint { show off; description "Inferno ALSA virtual device for Spotifyd" }
}

# Shared loopback mixing bus — all audio writers use this.
# dmix allows concurrent writes (silence + audio = audio).
pcm.inferno_mix {
    type dmix
    ipc_key 5000
    slave {
        pcm "hw:Loopback,0,0"
        rate 48000
        format S32_LE
        channels 2
        period_size 256
        periods 4
    }
}

# librespot writes 44.1kHz S32 here; speexrate_best resamples to 48kHz for loopback.
pcm.spotifyd {
    type rate
    converter "speexrate_best"
    slave { pcm "inferno_mix"; rate 48000; format S32_LE }
}
```

---

## Phase 11 — Statime System Service

### `/etc/inferno/inferno-ptpv1.toml`
```toml
loglevel  = "info"
sdo-id    = 0
domain    = 0
priority1 = 251
virtual-system-clock      = true
virtual-system-clock-base = "monotonic_raw"
usrvclock-export          = true

[[port]]
interface        = "ens18"
network-mode     = "ipv4"
hardware-clock   = "auto"
protocol-version = "PTPv1"
```

### `/etc/systemd/system/statime-inferno.service`
```ini
[Unit]
Description=Statime PTPv1 daemon (Inferno fork)
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=root
ExecStart=/var/lib/inferno/bin/statime -c /etc/inferno/inferno-ptpv1.toml
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
```

```bash
sudo systemctl daemon-reload
sudo systemctl mask systemd-timesyncd
sudo systemctl enable --now statime-inferno
```

---

## Phase 12 — User Services

Enable linger so user services survive logout:
```bash
sudo loginctl enable-linger core
```

### `~/.config/systemd/user/inferno-bridge.service`
Starts first. Permanently owns `inferno_spotify`. Must be running before keepalive and librespot.

```ini
[Unit]
Description=Inferno AoIP ALSA Loopback Bridge
After=statime-inferno.service
After=default.target
Before=inferno-keepalive.service
Before=librespot.service

[Service]
ExecStartPre=/bin/sh -c 'while [ ! -S /tmp/ptp-usrvclock ]; do sleep 1; done'
ExecStart=/bin/sh -c 'exec arecord -D hw:Loopback,1,0 -f S32_LE -r 48000 -c 2 --buffer-size=1024 | aplay -D inferno_spotify -f S32_LE -r 48000 -c 2 --buffer-size=1024'
Restart=always
RestartSec=3
TimeoutStopSec=5

[Install]
WantedBy=default.target
```

### `~/.config/systemd/user/inferno-keepalive.service`
Writes silence to the loopback to prevent ALSA underruns on the bridge's capture side.

```ini
[Unit]
Description=Inferno Keepalive (silence to hold Dante TX open)
After=default.target
After=inferno-bridge.service

[Service]
ExecStart=/bin/sh -c 'exec aplay -D inferno_mix -f S32_LE -r 48000 -c 2 /dev/zero'
Restart=always
RestartSec=3
TimeoutStopSec=5

[Install]
WantedBy=default.target
```

### `~/.config/systemd/user/librespot.service`
**Note**: Full path to `~/.cargo/bin/librespot` required on Fedora IoT (not in PATH for user services).

```ini
[Unit]
Description=Librespot Spotify Connect
After=default.target
Wants=default.target

[Service]
ExecStartPre=/bin/sh -c 'while [ ! -S /tmp/ptp-usrvclock ]; do sleep 1; done'
ExecStartPre=/bin/sh -c 'UP=$(cut -d. -f1 /proc/uptime); [ "$UP" -gt 60 ] || sleep 10'
ExecStart=/var/home/core/.cargo/bin/librespot \
    --name "Spotify to Dante (Fedora IoT)" \
    --device-type avr \
    --backend alsa \
    --device spotifyd \
    --format S32 \
    --bitrate 320 \
    --volume-ctrl log \
    --initial-volume 50 \
    --autoplay off \
    --disable-audio-cache \
    --cache /var/home/core/.cache/librespot \
    --system-cache /var/home/core/.cache/librespot \
    --disable-gapless \
    --emit-sink-events \
    --onevent /var/home/core/bin/inferno-sink-event
Restart=always
RestartSec=5

[Install]
WantedBy=default.target
```

### `~/.config/systemd/user/librespot-watchdog.service`
```ini
[Unit]
Description=Librespot Audio Key Error Watchdog

[Service]
ExecStart=%h/bin/librespot-watchdog
Restart=always
RestartSec=5

[Install]
WantedBy=default.target
```

---

## Phase 13 — Scripts

### `~/bin/inferno-sink-event`
```bash
#!/bin/sh
# Loopback-bridge architecture: inferno-bridge permanently owns inferno_spotify.
# This script only manages the /tmp/inferno-sink-active flag for the watchdog.
case "$PLAYER_EVENT" in
    sink_opened)  touch /tmp/inferno-sink-active ;;
    sink_closed)  rm -f /tmp/inferno-sink-active ;;
esac
```

### `~/bin/librespot-watchdog`
See full script in VM at `~/bin/librespot-watchdog` or on Arch VM at same path.
Monitors librespot journal for "Unable to load key" and rapid "unable to load track" cascades.
Restarts librespot with 10s cooldown. Also starts inferno-keepalive after restart.

```bash
mkdir -p ~/bin
chmod +x ~/bin/inferno-sink-event ~/bin/librespot-watchdog
```

---

## Phase 14 — Enable Everything

```bash
systemctl --user daemon-reload
systemctl --user enable --now inferno-bridge inferno-keepalive librespot librespot-watchdog
```

**Startup order** (enforced by `After=`/`Before=` in unit files):
1. `statime-inferno` (system) — PTP socket at `/tmp/ptp-usrvclock`
2. `inferno-bridge` — waits for PTP socket, then opens `inferno_spotify` permanently
3. `inferno-keepalive` — writes silence to `inferno_mix` (loopback)
4. `librespot` — waits for PTP socket + 10s stabilisation on first boot

---

## Verification

```bash
# All services active?
sudo systemctl is-active statime-inferno
systemctl --user is-active librespot inferno-keepalive inferno-bridge librespot-watchdog

# PTP clock running?
sudo journalctl -u statime-inferno -n 5 --no-pager

# ALSA loopback visible?
aplay -l | grep -i loopback

# librespot advertising (look for Zeroconf server line)?
systemctl --user set-environment RUST_LOG=librespot_discovery=debug
systemctl --user restart librespot
journalctl --user -u librespot -n 10 --no-pager | grep -iE "zeroconf|name|device|connect|alsa"
systemctl --user unset-environment RUST_LOG

# Inferno ALSA plugin loads?
aplay -D inferno_spotify --dump-hw-params /dev/null 2>&1 | head -5
# Should show: HW_PERIOD_BYTES, HW_BUFFER_BYTES — plugin initialized OK

# SELinux labels correct?
ls -Z /var/lib/inferno/bin/ /var/lib/inferno/alsa-plugins/
# Should show: bin_t for statime, lib_t for .so
```

### VM-Only Limitation: Dante TX requires Dante L2 network

When running on the management VLAN (10.10.1.0/24) without a Dante grandmaster visible,
statime transitions Listening → Master, the PTPv1 master mode is unimplemented, and the
inferno ALSA plugin times out after ~20 s with:

```
ERROR asound_module_pcm_inferno: no clock available (timeout waiting for overlay update)
```

This causes `inferno-bridge` to crash-restart in a loop. **This is expected and correct
behaviour** — the Inferno plugin requires a locked PTP clock to timestamp Dante audio frames.

**In production** (dante-doos / EliteDesk with MXWANI8 on same L2 segment), statime syncs
to the MXWANI8's PTPv1 grandmaster clock and the clock overlay updates flow continuously.

To fully validate Dante TX from the Fedora IoT VM, the VM would need:
- VLAN tagging to the production Dante network, OR
- A second PTP-capable device on the same 10.10.1.0/24 management VLAN acting as grandmaster

**VM test verdict (2026-04-03):** Full stack deployed and verified on VM 110 (10.10.1.79).
- All 5 services active: `statime-inferno`, `inferno-bridge`, `inferno-keepalive`, `librespot`, `librespot-watchdog`
- ALSA plugin loaded ✅ (libasound_module_pcm_inferno.so, SELinux lib_t)
- librespot advertises on port 39789, `Fedora-IoT` visible via `_spotify-connect._tcp` mDNS ✅
- `avahi-browse` from NixOS VM confirms Fedora-IoT visible alongside NixOS-Test and Arch-Test ✅
- snd-aloop Loopback card visible after audio group fix ✅
- Dante TX "no clock available" — expected on management VLAN without PTP grandmaster (not a bug)

---

## Fedora IoT Specific Gotchas (complete list)

| # | Gotcha | Fix |
|---|--------|-----|
| 1 | `gcc/clang/binutils` can't be layered (glibc conflict) | Build everything in `podman run fedora:42` container |
| 2 | Container can't write to `/var/lib/inferno/` (owned by system root, rootless podman) | Build to `~`, then `sudo install` after |
| 3 | Cargo workspace: plugin .so at `~/inferno/target/release/`, NOT `alsa_pcm_inferno/target/` | Use correct source path |
| 4 | statime binary is `statime` not `statime-linux` (renamed in inferno-dev branch) | `cargo build --bin statime` |
| 5 | librespot default build has no ALSA backend | `cargo install librespot --features=alsa-backend --locked` |
| 6 | SELinux blocks `/var/lib/inferno/bin/` executables (var_lib_t context) | `sudo semanage fcontext -a -t bin_t '/var/lib/inferno/bin(/.*)?'` + restorecon |
| 7 | SELinux blocks `/var/lib/inferno/alsa-plugins/*.so` | `sudo semanage fcontext -a -t lib_t '/var/lib/inferno/alsa-plugins(/.*)?'` + restorecon |
| 8 | `audio` group not in `/etc/group` (vendor-only) | `sudo sh -c 'echo "audio:x:63:core" >> /etc/group'` |
| 9 | rpm-ostree new deployment = new initramfs = LUKS keyfile gone | Re-embed keyfile cpio after every deployment reboot |
| 10 | librespot not in PATH for user services | Use full path: `/var/home/core/.cargo/bin/librespot` |
| 11 | `librespot-watchdog` ExecStart: use `%h/bin/` not `/home/legopc/bin/` | `ExecStart=%h/bin/librespot-watchdog` |
| 12 | `librespot-watchdog` `After=librespot.service` causes ordering cycle at boot | Remove the `After=librespot.service` line |
| 13 | `--ap-port 80` in librespot service breaks Spotify dealer (port 443) | Never set `--ap-port`; let librespot auto-select |
| 14 | avahi not installed in base image — librespot uses own mDNS but avahi needed for DNS-SD browsing | `sudo rpm-ostree install avahi nss-mdns` → reboot → `sudo systemctl enable --now avahi-daemon` |
| 15 | statime becomes PTPv1 Master on networks without a Dante grandmaster; master mode unimplemented → inferno plugin crash-loop | Normal on management VLAN; production requires MXWANI8 or other PTP grandmaster on same L2 |
| 16 | If multiple inferno VMs use `NAME "Spotify"` in asoundrc, mDNS collision occurs (`spotify.local.` conflict) — Dante Controller may show wrong device or miss one | Set unique `NAME` per node in `~/.asoundrc` (e.g. `Fedora-IoT`, `NixOS-Test`, `Arch-Test`) |

---

## Key File Locations on Fedora IoT VM

| File | Purpose |
|------|---------|
| `/var/lib/inferno/bin/statime` | PTP daemon binary (SELinux: bin_t) |
| `/var/lib/inferno/alsa-plugins/libasound_module_pcm_inferno.so` | Inferno ALSA plugin (SELinux: lib_t) |
| `/etc/inferno/inferno-ptpv1.toml` | statime config |
| `/etc/alsa/conf.d/99-inferno.conf` | ALSA plugin type registration |
| `/etc/systemd/system/statime-inferno.service` | System service for PTP |
| `/etc/modules-load.d/snd-aloop.conf` | Loads snd-aloop on boot |
| `/etc/group` | Has `audio:x:63:core` appended |
| `~/.asoundrc` | Inferno/loopback/spotifyd ALSA devices |
| `~/.config/systemd/user/inferno-bridge.service` | Loopback→Dante bridge |
| `~/.config/systemd/user/inferno-keepalive.service` | Silence writer |
| `~/.config/systemd/user/librespot.service` | Spotify Connect |
| `~/.config/systemd/user/librespot-watchdog.service` | Crash watchdog |
| `~/bin/inferno-sink-event` | librespot --onevent handler |
| `~/bin/librespot-watchdog` | Watchdog script |
| `/boot/loader/entries/ostree-*.conf` | BLS boot entries (have luks.key= option) |

---

## Differences vs Arch Linux (dante-doos)

| Aspect | Arch (dante-doos) | Fedora IoT |
|--------|-------------------|------------|
| Package manager | pacman / Ansible | rpm-ostree (immutable) |
| Compiler | system gcc | podman fedora:42 container |
| Plugin install path | `/usr/lib/alsa-lib/` | `/var/lib/inferno/alsa-plugins/` |
| statime binary path | `/usr/local/bin/statime-linux` | `/var/lib/inferno/bin/statime` |
| statime binary name | `statime-linux` (Ansible installs it as this) | `stamate` (built from source) |
| librespot path | `/usr/local/bin/librespot` or `~/.cargo/bin/` | `/var/home/core/.cargo/bin/librespot` |
| librespot ExecStart | `librespot` (in PATH) | Full path required |
| SELinux | not enforced | enforced — semanage fcontext required |
| audio group | standard `/etc/group` | vendor-only — must append to `/etc/group` |
| LUKS | N/A | keyfile cpio append to initramfs |
| Deployment method | Ansible playbook | Manual (no Ansible role yet) |
| `.asoundrc` plugin type lib | `/usr/lib/alsa-lib/libasound_module_pcm_inferno.so` | `/var/lib/inferno/alsa-plugins/libasound_module_pcm_inferno.so` |
