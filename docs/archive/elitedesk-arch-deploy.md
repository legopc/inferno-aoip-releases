# Inferno AoIP — Complete Deployment Guide
## HP EliteDesk 800 G2 + Arch Linux + Hardware PTP

**Last verified**: 2026-04-03  
**Node deployed**: `800G2-1` (192.168.1.43) — all services running, MXWANI8 subscribed  
**Result**: Spotify Connect → Dante TX, PTP offset ~100–300 ns (hardware-assisted)

---

## What This Does

This guide deploys a **headless Spotify Connect receiver** that transmits audio over **Dante Audio
over IP** to a hardware Dante device (e.g. Shure MXWANI8). The entire stack runs on a cheap
second-hand mini PC (~€60) using only open-source software.

```
Your phone / Spotify desktop app
        │
        │ Spotify Connect (mDNS/zeroconf over LAN)
        ▼
┌─────────────────────────────────┐
│  HP EliteDesk 800 G2            │
│                                 │
│  librespot  ──► ALSA loopback   │
│  (Spotify)      (software mix)  │
│       │                         │
│  inferno-bridge                 │
│  (loopback → Dante)             │
│       │                         │
│  alsa_pcm_inferno               │
│  (ALSA plugin, Dante protocol)  │
│       │                         │
│  statime (PTP daemon)           │
│  (clock sync ← MXWANI8)        │
└──────────────┬──────────────────┘
               │ Dante / AES67 (UDP/IP)
               ▼
        Shure MXWANI8
        (or other Dante receiver)
```

**Open source projects used:**

| Software | Role | Source |
|---|---|---|
| [librespot](https://github.com/librespot-org/librespot) | Spotify Connect daemon (plays audio from Spotify) | AUR: `librespot` |
| [Inferno](https://gitlab.com/lumifaza/inferno) | ALSA PCM plugin that speaks Dante protocol | Build from source |
| [Statime (inferno-dev fork)](https://github.com/teodly/statime) | PTP clock daemon (Dante uses PTPv1) | Build from source |

---

## Why Hardware PTP Matters

Dante audio networking synchronises all devices to a shared master clock using PTP (Precision Time
Protocol). The accuracy of this synchronisation determines the **minimum Dante receive latency** you
can configure before audio dropouts occur.

| NIC type | PTP offset | Minimum Dante latency |
|---|---|---|
| Realtek RTL8111 (common, cheap) | 200 µs – 2 ms | ~2.5–5 ms |
| **Intel I219-LM (this guide)** | **~100–300 ns** | **~0.25–1 ms** |

The Intel I219-LM timestamps PTP packets at the **MAC layer** (inside the NIC hardware), eliminating
kernel scheduler jitter from the clock measurement path. The HP EliteDesk 800 G2 has this NIC built
in. With `hardware-clock = "auto"` in the statime config, the software automatically detects and
uses `/dev/ptp0` — no extra configuration needed.

**Measured on 800G2-1 slaving to a Shure MXWANI8 grandmaster (2026-04-03):**
```
Estimated offset -9.4 ns ± 69.8 ns   (first measurement, ~30s after start)
Estimated offset 162.8 ns ± 305.9 ns (converging, ~7 min after start)
```

---

## Hardware Requirements

### Minimum (this guide)
- **HP EliteDesk 800 G2** (Mini, SFF, or TWR — all have I219-LM)
  - CPU: Intel Core i5-6500T (or any 6th-gen Core)
  - RAM: 8 GB DDR4 (4 GB works but leaves little headroom)
  - Storage: Any SSD or HDD (even 16 GB is plenty)
  - NIC: **Intel I219-LM** (built-in, this is the key component)
  - Where to buy: eBay, Marktplaats — ~€50–80
- **Network switch** with Dante support (standard managed switch is fine;
  unmanaged also works as long as it's low-latency — avoid Wi-Fi bridges)
- **Dante receiver** (this guide assumes Shure MXWANI8; any Dante device works)

### Alternative compatible hardware (same Intel NIC family)
- HP EliteDesk 800 G3 Mini — identical, slightly faster CPU
- Dell OptiPlex 7040 Micro — I219-LM, works identically
- Lenovo ThinkCentre M900 Tiny — I219-LM, works identically

### How to verify NIC model before buying
```bash
# Run on the candidate machine (any Linux live USB works):
lspci | grep -i ethernet
# Should show: "Ethernet Connection (5) I219-LM" or similar I219 variant
```

---

## Software Architecture (How It All Fits Together)

Understanding this helps with troubleshooting. There are **five systemd services** that must run
in the correct order:

### 1. `statime-inferno.service` (system service, runs as root)

Statime is a PTP daemon. It listens on the network for PTP multicast packets from the Dante
grandmaster (the MXWANI8 acts as grandmaster by default). Once it locks onto the master clock,
it steers the Linux system clock and exposes a Unix socket at `/tmp/ptp-usrvclock` that the
Inferno plugin uses to timestamp audio packets correctly.

**Key config**: `~/statime/inferno-ptpv1.toml`
- `interface = "eno1"` — must match your NIC name
- `hardware-clock = "auto"` — statime auto-detects `/dev/ptp0` for hardware timestamping
- `protocol-version = "PTPv1"` — Dante uses PTPv1 (standard Dante, not AES67)
- `virtual-system-clock = true` — Inferno requires this mode

### 2. `inferno-keepalive.service` (user service)

The Inferno ALSA plugin only advertises a Dante transmitter while something has the ALSA device
open. If librespot is idle and closes the device, the Dante subscription on the receiver drops.

To prevent this, `inferno-keepalive` writes a continuous stream of **silence** to the loopback
(not directly to the Dante device) so the bridge stays open. This also "warms up" the Dante
subscription so there is no re-establishment delay when a song starts.

### 3. `inferno-bridge.service` (user service)

This is the permanent audio bridge. It reads from the ALSA loopback capture side and writes to
the `inferno_spotify` ALSA device (which is the Inferno/Dante plugin). This keeps the Dante
device **permanently open** — the key insight that eliminates re-subscription delays.

```
arecord hw:Loopback,1,0  ──►  aplay inferno_spotify
     (loopback capture)           (Dante transmitter)
```

Both librespot and inferno-keepalive write to the **loopback playback side** (`inferno_mix`
dmix device). dmix allows multiple writers simultaneously, so silence from keepalive and audio
from librespot simply mix together.

### 4. `librespot.service` (user service)

Librespot is the Spotify Connect daemon. It receives audio from Spotify and writes it to the
`spotifyd` ALSA device, which applies 44.1 kHz → 48 kHz sample rate conversion and feeds into
the loopback mix bus.

Key flags:
- `--device spotifyd` — writes to the rate-converting ALSA virtual device
- `--format S32` — 32-bit samples (required by Inferno)
- `--disable-gapless` — prevents prefetch races after Spotify AP reconnects
- `--ap-port 443` — forces Spotify connection on port 443 (more stable than 4070)
- `--emit-sink-events` — fires events when playback starts/stops (used by keepalive coordination)

### 5. `librespot-watchdog.service` (user service)

Spotify's servers occasionally send a TCP RST on the AP connection (observed from Google Cloud
IPs at 34.158.x.x). When this happens, librespot reconnects in ~3–4 seconds but may fail to
obtain the audio decryption key for the current track (20–90 second silent period).

The watchdog monitors librespot's journal for `"Unable to load key"` errors and restarts it
immediately (with a 10-second cooldown to prevent restart storms).

### ALSA Device Chain (full picture)

```
librespot                    inferno-keepalive
    │ (S32 @ 44.1kHz)             │ (S32 @ 48kHz, silence)
    ▼                             ▼
pcm.spotifyd              pcm.inferno_mix (dmix)
(speexrate_best               │
 44.1→48kHz)                  │
    │ (S32 @ 48kHz)            │
    └──────────────────────────┘
                │
                ▼
         hw:Loopback,0,0          ← loopback playback
         hw:Loopback,1,0          ← loopback capture
                │
                ▼
         inferno-bridge
         (arecord | aplay)
                │
                ▼
         pcm.inferno_spotify      ← Inferno ALSA plugin
         (alsa_pcm_inferno.so)
                │ Dante/UDP packets
                ▼
         Shure MXWANI8
```

---

## Prerequisites

On the deployment machine (your workstation — not the EliteDesk):

- **Ansible** installed (`pip install ansible`, or distro package)
  - Plus: `ansible-galaxy collection install community.general`
- **SSH key** at `~/.ssh/inferno_proxmox` (ed25519, for passwordless access to target)
- **Network access** to the EliteDesk (same LAN segment as Dante devices)

On the EliteDesk target:

- **Arch Linux** installed with:
  - User `legopc` (or your username) in `wheel` group
  - `sshd` running
  - `systemd-networkd` + `systemd-resolved` for networking
  - Internet access (for pacman/AUR/rustup/cargo)
- **Python 3** installed (`sudo pacman -S python`)
  — **Note**: Python is NOT included in the Arch `base` package group. It must be installed
  manually before Ansible can run, because Ansible uses Python on the target to execute modules.

> **Tip**: If you installed Arch using the standard install guide, run `sudo pacman -S python`
> on the EliteDesk before proceeding to the Ansible step.

---

## Step-by-Step Deployment

### Step 1 — Set up SSH access

On the EliteDesk, as `legopc`:
```bash
mkdir -p ~/.ssh
echo "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILI+T7Koyd+yPIskHka+byxPdg/oQ4Zr7LEoWKI8G/6d copilot-inferno" \
  >> ~/.ssh/authorized_keys
chmod 700 ~/.ssh && chmod 600 ~/.ssh/authorized_keys
```

Verify from your workstation:
```bash
ssh -i ~/.ssh/inferno_proxmox legopc@<elitedesk-ip> 'echo OK'
```

### Step 2 — Install Python (required for Ansible)

On the EliteDesk:
```bash
sudo pacman -S python
```

### Step 3 — Enable passwordless sudo (required for Ansible become)

On the EliteDesk:
```bash
echo "%wheel ALL=(ALL:ALL) NOPASSWD: ALL" | sudo tee /etc/sudoers.d/wheel-nopasswd
sudo chmod 440 /etc/sudoers.d/wheel-nopasswd
```

Verify:
```bash
sudo whoami   # should print: root
```

### Step 4 — Configure the Ansible inventory

In the repository, edit `Inferno_OS_Hardening/ansible/inventory-elitedesk.yml`:

```yaml
---
all:
  hosts:
    inferno-node:
      ansible_host: 192.168.1.43          # ← set to your EliteDesk's IP
      ansible_user: legopc                # ← your username
      ansible_ssh_private_key_file: "~/.ssh/inferno_proxmox"
      ansible_become_password: "yourpassword"  # ← sudo password

  vars:
    inferno_user: legopc
    inferno_interface: eno1               # ← verify with: ip link show
    inferno_hostname: dante-elitedesk
    inferno_name: "EliteDesk-HW-PTP"     # ← Spotify Connect device name
    dante_device_ip: 192.168.1.34        # ← IP of your Dante device (MXWANI8 etc.)
```

**Finding the NIC name**: run `ip link show` on the EliteDesk. On the 800 G2 you will see `eno1`
(onboard naming). On some units it may be `enp2s0` (PCIe naming) — use whatever `ip link` shows.

**Finding the DEVICE_ID** (for reference — Ansible computes this automatically):
```bash
# Run on the EliteDesk:
NIC=eno1
cat /sys/class/net/$NIC/address | tr -d ':' && echo "0000"
# Example: 10e7c6110f04  +  0000  =  10e7c6110f040000
```

### Step 5 — Install Ansible dependencies

On your workstation:
```bash
cd Inferno_OS_Hardening/ansible
ansible-galaxy collection install community.general
```

### Step 6 — Run the Ansible playbook

```bash
cd Inferno_OS_Hardening/ansible
ansible-playbook -i inventory-elitedesk.yml site.yml
```

**Expected output** (first run — all from scratch):
```
PLAY RECAP
inferno-node : ok=61  changed=21  unreachable=0  failed=0  skipped=9
```

This takes **5–15 minutes** on the first run because it compiles:
- `statime` (Rust, the PTP daemon fork) — ~1–2 minutes
- `alsa_pcm_inferno` (Rust, the Dante ALSA plugin) — ~2–5 minutes
- `librespot` (via yay/AUR, also builds from Rust source) — ~2–5 minutes

On subsequent runs (idempotent — safe to re-run):
```
PLAY RECAP
inferno-node : ok=47  changed=0  unreachable=0  failed=0  skipped=14
```

### Step 7 — Verify everything is running

SSH to the EliteDesk and run:

```bash
# System services (runs as root):
sudo systemctl status statime-inferno

# User services (runs as legopc):
systemctl --user status librespot inferno-bridge inferno-keepalive librespot-watchdog
```

All five should show `active (running)`.

### Step 8 — Verify hardware PTP

```bash
# Check NIC hardware PTP capability:
ethtool -T eno1

# Key lines to look for:
#   hardware-transmit
#   hardware-receive
#   Hardware timestamp provider qualifier: Precise (IEEE 1588 quality)
#   Hardware timestamp source: MAC

# Confirm /dev/ptp0 exists:
ls -la /dev/ptp0

# Monitor live PTP offset (once statime is slaving to your Dante grandmaster):
sudo journalctl -u statime-inferno -f | grep "Estimated offset"
# You should see offsets in the range of tens to hundreds of nanoseconds.
# If you see offsets in milliseconds, hardware PTP is not active.
```

### Step 9 — Connect Spotify

On your phone or Spotify desktop:
1. Open Spotify
2. Tap the device icon (bottom of player)
3. Look for **"EliteDesk-HW-PTP"** (or whatever `inferno_name` you set)
4. Select it — audio should start flowing to your Dante receiver

---

## Configuration Reference

### ALSA config (`~/.asoundrc`)

Deployed automatically by Ansible. This is what it looks like on 800G2-1:

```
pcm_type.inferno {
    lib "/usr/lib/alsa-lib/libasound_module_pcm_inferno.so"
}

# Raw Dante device (only inferno-bridge.service opens this)
pcm.inferno_spotify {
    type inferno
    NAME "EliteDesk-HW-PTP"
    BIND_IP eno1
    SAMPLE_RATE 48000
    PROCESS_ID 1
    ALT_PORT 6000
    RX_CHANNELS 0
    TX_CHANNELS 2
    TX_LATENCY_NS 10000000
    RX_LATENCY_NS 10000000
    CLOCK_PATH /tmp/ptp-usrvclock
    DEVICE_ID 10e7c6110f040000
}

# Loopback mixing bus (multiple writers via dmix)
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

# librespot output: 44.1kHz → 48kHz rate conversion → loopback
pcm.spotifyd {
    type rate
    converter "speexrate_best"
    slave {
        pcm "inferno_mix"
        rate 48000
        format S32_LE
    }
}
```

**Key values to adapt for a new node:**
| Value | How to find it |
|---|---|
| `NAME` | Your chosen Spotify Connect device name |
| `BIND_IP` | Output of `ip link show` — NIC name (e.g. `eno1`, `enp2s0`) |
| `DEVICE_ID` | MAC without colons + `0000` suffix (see Step 4 above) |

### PTP config (`~/statime/inferno-ptpv1.toml`)

```toml
loglevel = "trace"
sdo-id = 0
domain = 0
priority1 = 251
virtual-system-clock = true
virtual-system-clock-base = "monotonic_raw"
usrvclock-export = true

[[port]]
interface = "eno1"          # ← your NIC name
network-mode = "ipv4"
hardware-clock = "auto"     # auto-detects /dev/ptp0
protocol-version = "PTPv1"  # Dante uses PTPv1
```

**Why `protocol-version = "PTPv1"`?** Standard Dante (as used by the Shure MXWANI8) runs
PTPv1 (IEEE 1588-2002). Upstream statime only supports PTPv2. The inferno-dev fork adds
PTPv1 support specifically for Dante compatibility.

### Port/firewall requirements

Open these UDP ports inbound on the EliteDesk (or ensure your switch doesn't block them):

| Port(s) | Protocol | Purpose |
|---|---|---|
| 319, 320 | UDP multicast | PTP (statime) |
| 4455 | UDP | Dante device discovery |
| 8700 | UDP | Dante audio flows |
| 4400, 8800 | UDP | Dante control |
| 5353 | UDP multicast | mDNS (Spotify Connect via avahi) |
| 6000–6003 | UDP | Inferno ALT_PORT range (Spotify instance) |

---

## Troubleshooting

### statime shows "master operation not implemented yet for PTPv1"

```
WARN log: got DelayReq, master operation not implemented yet for PTPv1
```

This is **not an error**. It means a device on the network tried to use this node as a PTP
master (sent it a DelayReq). Statime correctly ignores it. The node is in **Slave** mode,
following the MXWANI8's clock. This message appears periodically and can be ignored.

### inferno-bridge shows "overrun!!!" at startup

```
overrun!!! (at least 53.875 ms long)
```

This is a **startup transient**, not a problem. When inferno-bridge first opens the Inferno
ALSA device, the clock sync and buffer alignment take a moment. After the initial negotiation
the overrun stops. If you see continuous overruns after 30+ seconds of operation, something
is wrong (check statime is running and PTP socket exists).

### inferno-bridge shows "received unknown opcode1 0x2204"

```
ERROR inferno_aoip::device_server::arc_server] received unknown opcode1 0x2204
```

This is **benign**. Dante devices send various control messages for device management (routing
configuration, remote control). Opcode 0x2204 is a Dante-proprietary control message that
the open-source Inferno implementation does not recognise. Audio is unaffected.

### No /tmp/ptp-usrvclock socket

If `ls /tmp/ptp-usrvclock` fails, statime is not running or failed to start:

```bash
sudo systemctl status statime-inferno
sudo journalctl -u statime-inferno -n 50
```

Common causes:
- Wrong `interface` name in `inferno-ptpv1.toml` (run `ip link show` to verify)
- Binary path wrong in service file — the binary is at `~/statime/target/debug/statime`
  (note: the playbook builds debug mode, not release, for faster builds)

### inferno-bridge keeps restarting

If inferno-bridge restarts every few seconds, it is likely waiting for the PTP clock to become
valid. Check:
```bash
ls /tmp/ptp-usrvclock              # must exist
sudo systemctl is-active statime-inferno  # must be "active"
sudo journalctl -u statime-inferno -n 20 | grep "Estimated offset"
# Must show small offsets (ns range) — if no output, statime hasn't synced yet
```

In a VM without a Dante grandmaster on the network, statime will enter Master mode (which
is unimplemented in PTPv1). In this case inferno-bridge will restart continuously — this is
**expected in a VM**, not a bug.

### Spotify device not visible in app

```bash
systemctl is-active avahi-daemon   # must be "active"
# If not: sudo systemctl start avahi-daemon && sudo systemctl enable avahi-daemon

systemctl --user is-active librespot  # must be "active"
journalctl --user -u librespot -n 20  # look for "Authenticated as ..." line
```

librespot needs at least one Spotify login to work. On first run, you can either:
- Use `--username`/`--password` flags in the service file (edit the service template)
- Or connect via the Spotify app — it will authenticate automatically on first selection

### Audio is silent / no Dante flow reaching MXWANI8

Check the bridge is connecting:
```bash
journalctl --user -u inferno-bridge -n 30 | grep -E "MXWANI8|requesting flow|clock ready"
```

You should see lines like:
```
MXWANI8-fb6d82 requesting flow 1 of channel indices [Some(0), Some(1)] at 48000Hz 24bit 32 fpp
```

If you don't see this within 30 seconds of inferno-bridge starting, the MXWANI8 is not
subscribing. Check:
- The MXWANI8 is on the same L2 network segment (same VLAN, no router between them)
- Dante Controller on a Windows/Mac machine shows the Inferno transmitter as available
- The `BIND_IP` in `.asoundrc` matches the NIC that reaches the MXWANI8

---

## What Each File Does (Repository Map)

```
Inferno_OS_Hardening/ansible/
├── site.yml                    # Main playbook — runs all roles in order
├── inventory-elitedesk.yml     # ← Edit this for your EliteDesk
├── inventory-test-vm.yml       # For Proxmox test VM (VM 105)
├── roles/
│   ├── base/                   # pacman packages, snd-aloop module, yay AUR helper
│   ├── rust/                   # rustup install + stable toolchain
│   ├── statime/                # Clone + build statime, deploy service + PTP config
│   ├── inferno/                # Clone + build alsa_pcm_inferno.so, deploy ALSA plugin
│   ├── alsa/                   # Deploy ~/.asoundrc and /etc/alsa/conf.d/99-inferno.conf
│   ├── librespot/              # yay install librespot, deploy all user services + scripts
│   └── system-state/           # Mask timesyncd, enable linger, enable/start all services
└── templates/
    ├── asoundrc.j2             # ~/.asoundrc template (uses inferno_interface, DEVICE_ID)
    ├── 99-inferno.conf.j2      # ALSA plugin type registration
    ├── inferno-ptpv1.toml.j2  # PTP daemon config
    ├── statime-inferno.service.j2
    ├── librespot.service.j2
    ├── inferno-bridge.service.j2
    ├── inferno-keepalive.service.j2
    └── librespot-watchdog.service.j2

Inferno_AoIP/
├── INSTALL.md                  # Manual (non-Ansible) installation guide
├── CONTEXT.md                  # Full technical context for troubleshooting
└── config/                     # Raw config files (before templating)

Inferno_AoIP_HW_PTP/
├── hardware-assessment.md      # NIC research, I219-LM deep dive, buying guide
└── vm-setup-log.md             # Verification log (VM test + physical 800G2-1 results)
```

---

## Service Dependency and Startup Order

```
boot
 │
 ├─► network-online.target
 │       │
 │       └─► statime-inferno.service (system, root)
 │               Creates /tmp/ptp-usrvclock
 │               │
 │               └─► [user services start via linger after network is up]
 │
 ├─► inferno-keepalive.service (user)
 │       Writes silence → inferno_mix → loopback
 │
 ├─► inferno-bridge.service (user)
 │       Polls for /tmp/ptp-usrvclock (ExecStartPre loop)
 │       Then: arecord loopback → aplay inferno_spotify (Dante TX)
 │
 ├─► librespot.service (user)
 │       Polls for /tmp/ptp-usrvclock
 │       Spotify Connect → spotifyd ALSA → inferno_mix → loopback
 │
 └─► librespot-watchdog.service (user)
         Monitors librespot journal
         Restarts librespot on "Unable to load key" errors
```

**Critical constraint**: `systemd-timesyncd` must remain **masked** permanently.
Both statime and timesyncd try to discipline the Linux system clock (`adjtimex`).
If timesyncd runs, it fights statime and PTP sync degrades or breaks.

```bash
# Verify it's masked (returns "masked"):
systemctl is-enabled systemd-timesyncd
```

---

## Performance Results (800G2-1, 2026-04-03)

After 7 minutes of operation, slaving to Shure MXWANI8 as PTP grandmaster:

```
Estimated offset -277 ns ± 131 ns
Estimated offset  163 ns ± 306 ns
Estimated offset   98 ns ± 185 ns
```

Compare to production node `dante-doos` (RTL8111, software timestamping):
```
Typical offset: 200 µs – 2 ms
```

**This is a ~2000× improvement in clock accuracy.** In practice this means:
- Dante receive latency can be set to **0.25–1 ms** (vs 2.5–5 ms with RTL8111)
- Better resistance to clock drift under CPU load (hardware timestamps bypass the kernel)
- More stable Dante subscription (fewer re-subscriptions during heavy network traffic)

---

## Re-deploying / Updating

The Ansible playbook is **idempotent** — safe to run multiple times. On subsequent runs:
- Packages already installed are skipped
- Rust builds are skipped if the git commit hasn't changed (stamp-file check)
- Config files are re-deployed only if contents have changed
- Services are restarted only if their unit file changed

```bash
# Re-run everything (safe):
ansible-playbook -i inventory-elitedesk.yml site.yml

# Re-run only specific roles (faster):
ansible-playbook -i inventory-elitedesk.yml site.yml --tags alsa
```

---

## Known Gotchas

| Gotcha | Impact | Fix |
|---|---|---|
| Python3 not in Arch `base` | Ansible fails at "Gathering Facts" with "No python interpreters found" | `sudo pacman -S python` before first Ansible run |
| `inferno_name` missing from inventory | Ansible fails at alsa role: `'inferno_name' is undefined` | Add `inferno_name: "YourName"` to inventory vars |
| `systemd-timesyncd` not masked | PTP sync degrades; `adjtimex` fights | `sudo systemctl mask systemd-timesyncd` |
| `ethtool` not in base Arch | Can't verify hardware PTP | `sudo pacman -S ethtool` |
| Startup `overrun!!!` in inferno-bridge | Normal — buffer alignment at start | Ignore if gone within 30s |
| `unknown opcode1 0x2204` in bridge log | Dante control message, audio unaffected | Ignore — benign |
| statime in VM with no grandmaster | inferno-bridge restarts every ~5s | Expected in VM; works on real hardware with MXWANI8 |
| Wrong NIC name in config | statime and ALSA can't find the interface | Run `ip link show`, update `inferno_interface` in inventory |

---

## Quick Reference Commands

```bash
# Check all service status at once:
sudo systemctl status statime-inferno && \
  systemctl --user status librespot inferno-bridge inferno-keepalive librespot-watchdog

# Live PTP offset (tells you clock sync quality):
sudo journalctl -u statime-inferno -f | grep "Estimated offset"

# Live librespot log (Spotify Connect activity):
journalctl --user -u librespot -f

# Live inferno-bridge log (Dante subscription activity):
journalctl --user -u inferno-bridge -f

# Verify hardware PTP:
ethtool -T eno1 | grep -E "hardware-|Hardware"
ls -la /dev/ptp0

# Check TX timestamp health (should stay near 0):
ethtool -S eno1 | grep hwtstamp

# Restart everything (if needed):
sudo systemctl restart statime-inferno
sleep 5
systemctl --user restart inferno-keepalive inferno-bridge librespot librespot-watchdog

# View ALSA devices (should show Loopback at card 5):
aplay -l

# Check Spotify Connect advertisement:
avahi-browse -t _spotify-connect._tcp
```
