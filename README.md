# Inferno AoIP Appliance — *Virgil*

A headless Linux appliance that bridges Spotify Connect and analog audio into a Dante Audio-over-IP network. Runs as an immutable [bootc](https://containers.github.io/bootc/) image — the entire OS is a container image that boots directly. No package manager, no config drift.

This appliance is named **Virgil** after the Roman poet who guides Dante through the Inferno in Dante Alighieri's *Divine Comedy* — just as this OS image guides and carries the [Inferno AoIP project](https://gitlab.com/lumifaza/inferno) onto real hardware. All credit for the Inferno protocol implementation goes to its original creators and contributors at [gitlab.com/lumifaza/inferno](https://gitlab.com/lumifaza/inferno) — this appliance simply packages their work.

> **⚠️ AI-GENERATED CODE — READ BEFORE RUNNING**
>
> This repository is substantially AI-assisted ("AI slop"). The Containerfile, scripts, systemd units, and configuration files were written with the help of an AI coding assistant. **Do not blindly run code on your machine without understanding what it does.** Review the `Containerfile`, `build-release.sh`, and any scripts before building or installing.
>
> That said: this is **verified working on real hardware** across multiple HP EliteDesk nodes and test VMs. The Dante networking, PTP sync, Spotify Connect, and aux audio paths have all been exercised on physical systems. "AI slop" doesn't mean untested — it means you should still read what you're running.

---

## Operating Modes

| Mode | Audio path | Dante devices created |
|------|-----------|----------------------|
| **Spotify** | Spotify Connect → Dante TX | 1 TX device (`Name`) |
| **Aux In** | Analog capture → Dante TX | 1 TX device (`Name-TX`) |
| **Aux Out** | Dante RX → Analog playback | 1 RX device (`Name-RX`) |
| **Aux Bidir** | Analog in → Dante TX **and** Dante RX → Analog out | 1 TX + 1 RX (`Name-TX`, `Name-RX`) |

Aux modes support 2–8 channels and optionally combine two physical soundcards (e.g. two 2-channel USB cards as a single 4-channel Dante device).

---

## Quick Start — Install on a Node

1. Download the latest installer ISO from PRX-01:  
   `/var/lib/vz/template/iso/inferno-appliance-v10.iso`  
   or flash it to USB: `dd if=install.iso of=/dev/sdX bs=4M status=progress conv=fsync`

2. Boot the target machine from the ISO. Anaconda installs automatically.

3. After install the node reboots. On first boot, `inferno-configure.service` runs:
   - Auto-detects NIC, derives Dante DEVICE_ID from MAC address
   - Auto-detects physical audio card
   - Writes `/etc/inferno.conf` and `~/.asoundrc`
   - Reboots again (boot 2 = first normal operation)

4. Open Cockpit at `https://node-ip:9090` → **Inferno** (sidebar) to configure mode, device name, audio cards and channel counts.

---

## Management

| Interface | URL | Purpose |
|-----------|-----|---------|
| Cockpit | `https://node-ip:9090` | Configure mode, audio cards, channel counts, device names. Service status and restart. Journal viewer. |

### Configuration file (`/etc/inferno.conf`)

| Key | Values | Notes |
|-----|--------|-------|
| `INFERNO_MODE` | `spotify` / `aux-in` / `aux-out` / `aux-bidir` | Active operating mode |
| `INFERNO_SPOTIFY_NAME` | string | Name shown in Spotify app (Spotify mode only) |
| `INFERNO_DANTE_NAME` | string | Base name for Dante devices (`-TX`/`-RX` appended in aux modes) |
| `INFERNO_NIC` | NIC name or `auto` | Dante network interface |
| `INFERNO_AUDIO_CARD_IN` | ALSA short ID e.g. `PCH` | Capture card (aux modes) |
| `INFERNO_AUDIO_CARD_OUT` | ALSA short ID e.g. `PCH` | Playback card (aux modes) |
| `INFERNO_AUDIO_CARD_IN2` | ALSA short ID or `none` | Optional second capture card (multi-card TX) |
| `INFERNO_AUDIO_CARD_OUT2` | ALSA short ID or `none` | Optional second playback card (multi-card RX) |
| `INFERNO_TX_CHANNELS` | `2` / `4` / `6` / `8` | Dante TX channel count |
| `INFERNO_RX_CHANNELS` | `2` / `4` / `6` / `8` | Dante RX channel count |

### Credentials (lab use only)

| Item | Value |
|------|-------|
| OS user | `core` |
| Password | `inferno123` |
| sudo | passwordless (wheel NOPASSWD) |
| SSH | password auth enabled |

---

## Upgrading a Node

**From ISO** — full re-install (use for major version jumps):  
Flash new ISO to USB, boot target, re-install.

**From upgrade tarball** — online upgrade without USB (preferred for minor updates):

```bash
VERSION=v10
NODE=192.168.1.46

# Stream upgrade tar from PRX-01 directly into node
ssh -i ~/.ssh/inferno_proxmox -o StrictHostKeyChecking=no root@10.10.1.201 \
  "cat /mnt/inferno-build/inferno-appliance-${VERSION}.tar" \
  | ssh -i ~/.ssh/inferno_proxmox core@${NODE} 'sudo podman load'

# Stage new image and reboot
ssh -i ~/.ssh/inferno_proxmox core@${NODE} \
  "sudo bootc switch localhost/inferno-appliance:${VERSION} && sudo reboot"
```

If something is wrong after reboot:
```bash
ssh -i ~/.ssh/inferno_proxmox core@${NODE} "sudo bootc rollback && sudo reboot"
```

See [`docs/upgrade.md`](docs/upgrade.md) for full procedure including multi-node upgrades.

---

## Building a New Release

Use the build script — it produces all three release artifacts automatically:

```bash
VERSION=v11   # bump for each release

ssh -i ~/.ssh/inferno_proxmox root@10.10.1.201 "
  mkdir -p /run/containers/storage
  systemd-run --unit=inferno-build-${VERSION} \
    /mnt/inferno-build/inferno-aoip-releases/build/build-release.sh ${VERSION} \
    > /mnt/inferno-build/build-${VERSION}.log 2>&1
"

# Monitor
ssh -i ~/.ssh/inferno_proxmox root@10.10.1.201 "tail -f /mnt/inferno-build/build-${VERSION}.log"
```

The script runs as a systemd transient service (survives SSH disconnects). It produces:

| Artifact | Location on PRX-01 |
|----------|--------------------|
| Container image | `localhost/inferno-appliance:vN` (custom storage) |
| Installer ISO | `/mnt/inferno-build/output-vN/bootiso/install.iso` |
| Proxmox ISO symlink | `/var/lib/vz/template/iso/inferno-appliance-vN.iso` |
| Upgrade tarball | `/mnt/inferno-build/inferno-appliance-vN.tar` |

Expected time: ~10 min container build + ~15 min ISO + ~3 min upgrade tar = ~30 min total.

See [`build/README.md`](build/README.md) for full build environment details and troubleshooting.

---

## Repository Structure

```
inferno-aoip-releases/
├── Containerfile               OS image definition (33 build steps)
├── build/
│   ├── build-release.sh        Full release build script (container → ISO → upgrade tar)
│   ├── inferno-configure.sh    First-boot configuration script (baked into image)
│   ├── config.toml             bootc-image-builder config (no secrets — baked into image)
│   └── README.md               Build environment and PRX-01 setup guide
├── cockpit/
│   ├── index.html              Cockpit UI shell
│   ├── inferno.js              UI logic: mode switching, audio provisioning, ALSA config
│   └── manifest.json           Cockpit package descriptor
├── templates/
│   ├── alsa/                   ALSA config templates (%%PLACEHOLDER%% substituted at first boot)
│   ├── systemd/system/         System service units (statime-inferno, inferno-configure)
│   └── systemd/user/           User service templates (inferno-bridge, librespot, aux-tx, aux-rx…)
├── iot-updater/                Cockpit OCI update delivery UI (web + server + apply script)
├── docs/
│   ├── architecture.md         Full system architecture, ALSA device hierarchy, PTP, service map
│   ├── build-and-release.md    Step-by-step build and release process
│   ├── cockpit-ui.md           Cockpit UI internals and ALSA/systemd provisioning logic
│   ├── upgrade.md              Node upgrade procedure (tar-based, no registry required)
│   ├── install-guide.md        Physical/VM installation guide
│   ├── operations.md           Lab hosts, IPs, credentials, operational runbook
│   └── troubleshooting.md      Common failures and fixes
└── scripts/
    └── probe-node.sh           Diagnose a running node
```

---

## How It Works

### Binary pipeline

A GitHub Actions CI pipeline builds Inferno binaries nightly from source:
1. Clones [inferno](https://gitlab.com/lumifaza/inferno), [statime](https://github.com/teodly/statime), [librespot](https://github.com/librespot-org/librespot)
2. Builds on Ubuntu 24.04 (glibc 2.39 — compatible with Fedora 43)
3. Bundles into `inferno-aoip.tar.gz` and publishes as a GitHub Release

The `Containerfile` downloads this tarball at image build time:
```
https://github.com/legopc/inferno-aoip-releases/releases/latest/download/inferno-aoip.tar.gz
```

### Image layers (Containerfile — 33 steps)

```
FROM fedora-bootc:43
  └─ dnf install: cockpit, alsa-utils, avahi, openssh, skopeo, curl
  └─ Download inferno-aoip.tar.gz → install statime, librespot, ALSA plugin
  └─ COPY templates/ → /etc/inferno/  (config templates with %%PLACEHOLDERs%%)
  └─ COPY cockpit/   → /usr/share/cockpit/inferno/  (management UI)
  └─ COPY systemd units → /etc/systemd/system/ + /etc/inferno/systemd/user/
  └─ snd-aloop pinned to card index 5 (avoids conflicts with physical cards)
  └─ systemctl enable: sshd, cockpit.socket, avahi-daemon, statime-inferno, inferno-configure, iot-updater
  └─ systemctl mask: systemd-timesyncd, chronyd, ntpd  (PTP manages the clock)
  └─ useradd core:inferno123 + audio group + wheel NOPASSWD + linger pre-created
  └─ COPY iot-updater/ → cockpit page + server + apply script
```

### First boot

`inferno-configure.service` runs once (gated by absence of `/etc/inferno.conf`):
1. Detect wired NIC, get IP and MAC
2. Derive `DEVICE_ID` from MAC (e.g. `MAC 18:60:24:24:aa:a8` → `186024244aa80000`)
3. Auto-detect physical audio card (first non-Loopback non-HDMI from `aplay -l`)
4. Substitute `%%PLACEHOLDER%%` values in all templates
5. Write `~/.asoundrc` with Spotify and aux ALSA PCM blocks
6. Write user service files to `~/.config/systemd/user/`
7. Enable linger + activate user services
8. Write `/etc/inferno.conf` (sentinel — prevents re-run on next boot)
9. Reboot

### USB hot-plug (udev)

A udev rule detects USB audio card add/remove events and triggers an ALSA rescan. The Cockpit UI's **Audio Devices** panel shows a live list of cards with capture/playback capability, with a manual **Refresh** button alongside.

---

## Version History

| Version | Status | Notes |
|---------|--------|-------|
| v10 | ✅ Production | USB hot-plug audio (udev), TX/RX channel selectors, conditional Spotify Connect name field, multi-card ALSA type multi, dynamic audio device panel |
| v9 | Superseded | Cockpit UI with full aux mode: split card selectors, channel counts, multi-card support, stable ALSA card IDs, audio devices panel, auto-refresh |
| v8 | Superseded | First physical install on HP EliteDesk 800G3. Spotify Connect + Dante TX functional. Cockpit UI replaces Python webserver. |
| v7 | Superseded | Added Cockpit modules, linger fix, WiFi NIC exclusion |
| v6 | Superseded | SELinux binary path fix, auto-reboot after configure, ordering cycle fix |
