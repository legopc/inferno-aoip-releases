# Inferno AoIP Appliance — *Virgil*

A headless Linux appliance that bridges Spotify Connect and analog audio into a Dante Audio-over-IP network. Runs as an immutable [bootc](https://containers.github.io/bootc/) image — the entire OS is a container image that boots directly. No package manager, no config drift.

This appliance is named **Virgil** after the Roman poet who guides Dante through the Inferno in Dante Alighieri's *Divine Comedy* — just as this OS image guides and carries the [Inferno AoIP project](https://gitlab.com/lumifaza/inferno) onto real hardware. All credit for the Inferno protocol implementation goes to its original creators and contributors at [gitlab.com/lumifaza/inferno](https://gitlab.com/lumifaza/inferno) — this appliance simply packages their work.

> **⚠️ AI-GENERATED CODE — READ BEFORE RUNNING**
>
> This repository is substantially AI-assisted ("AI slop"). The Containerfile, scripts, systemd units, and configuration files were written with the help of an AI coding assistant. **Do not blindly run code on your machine without understanding what it does.** Review the `Containerfile`, `build-release.sh`, and any scripts before building or installing.
>
> That said: this is **verified working on real hardware** across multiple HP EliteDesk nodes and test VMs. The Dante networking, PTP sync, Spotify Connect, and aux audio paths have all been exercised on physical systems. "AI slop" doesn't mean untested — it means you should still read what you're running.

---

## ⚠️ Known Issues

> **Why this section exists:** AI assistants document features convincingly even when the underlying code is broken. The items below are confirmed defects — do not rely on them working until they are marked fixed.

### ~~🔴 OTA upgrade via Cockpit IoT Updater is broken~~

**Status:** ✅ **RESOLVED** — April 2026 (`legopc/cockpit-iot-updater` commits `a8d2890` / `a1cd215`). The missing `skopeo copy` command (BUG-01) is fixed, along with a docker-archive vs. oci-archive format mismatch and a 2 GB sidecar memory spike. OTA upgrades via the Cockpit IoT Updater UI work correctly as of v14+. See [`IMPROVEMENT_ROADMAP.md`](IMPROVEMENT_ROADMAP.md) BUG-01 section for full resolution notes.

---

### 🔴 `bootc-fetch-apply-updates.service` fails to start

**Status:** Fails on boot. Not yet fixed.

The `bootc-fetch-apply-updates` systemd service (part of the upstream bootc package) fails to start on this appliance. This service is responsible for automatic background OTA updates from a container registry. It is not used by the Inferno upgrade workflow (which uses the Cockpit IoT Updater instead), but the failure generates journal errors that can be confusing.

**Symptom:** `systemctl status bootc-fetch-apply-updates.service` shows a failed state. Journal shows errors related to missing registry credentials or unresolvable image reference.

**Why it fails:** The appliance image is built locally (not pushed to a public registry). `bootc` cannot find the image reference at any known registry URL. The service has no meaningful target to fetch from.

**Workaround:** Mask the service to suppress the errors — it is not needed:
```bash
sudo systemctl mask bootc-fetch-apply-updates.service bootc-fetch-apply-updates.timer
```

**Note:** This does **not** affect upgrades. Use the Cockpit IoT Updater (BUG-01 is resolved — works as of v14+) or the SSH tar pipe method above.

---

### 🟠 Install ISO requires manual disk/user confirmation (not fully unattended)

**Status:** Active. No kickstart is embedded in the ISO.

The installer ISO is built without a kickstart file. Anaconda may pause for disk selection, timezone, or root password prompts depending on the target hardware. The install is **not** fully unattended on first use.

**Workaround:** Watch the install and respond to any Anaconda prompts. The install will proceed to completion once the prompts are answered.

**Fix:** Add `[[customizations.installer.kickstart]]` to `build/config.toml`. Tracked as **Item 1** in [`IMPROVEMENT_ROADMAP.md`](IMPROVEMENT_ROADMAP.md).

---

### 🟠 NIC selection does not verify link state

**Status:** Active. No fix yet.

`inferno-configure.sh` selects the Dante NIC by picking the first non-virtual, non-wireless interface alphabetically. It does **not** check whether that interface has physical link (cable connected). On a machine with two wired NICs where the wrong one is cabled, the appliance silently configures Dante on a dead interface.

**Symptom:** Node appears to configure successfully (reboots cleanly, `/etc/inferno.conf` is written) but no Dante device appears on the network.

**Workaround:** SSH in and check `ip link show` — if the configured NIC shows `NO-CARRIER`, the wrong NIC was selected. Delete `/etc/inferno.conf` and reboot to retrigger configure, after ensuring only the correct NIC has a cable connected.

**Fix:** Add carrier check to NIC detection. Tracked as **Item 8** in [`IMPROVEMENT_ROADMAP.md`](IMPROVEMENT_ROADMAP.md).

---

## What Does It Do?

Virgil is a headless Fedora-based audio appliance distributed as a [bootc](https://containers.github.io/bootc/) container image — the entire OS is a single OCI image that boots directly, with no package manager and no config drift.

Once installed on a node:
- **Spotify Connect** is advertised on the local network. Any Spotify client can stream to it.
- Audio is received by [librespot](https://github.com/librespot-org/librespot) and piped through an ALSA loopback device into the [Inferno](https://gitlab.com/lumifaza/inferno) ALSA plugin.
- Inferno transmits the audio over **Dante AoIP** (UDP) to Dante-capable hardware — in production, a Shure MXWANI8 8-channel networked audio input.
- [Statime](https://github.com/teodly/statime) runs as a software PTP grandmaster/slave to synchronise the node's clock with the Dante network's PTP domain.
- The node is managed entirely via the **Cockpit web UI** — no desktop, no SSH required for day-to-day operation.

```
[Spotify App]  →  librespot  →  ALSA loopback  →  Inferno ALSA plugin  →  Dante (UDP)  →  [MXWANI8]
                                                        ↑
                                               Statime PTP clock sync
```

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

## Quick Start — Install

1. Get the latest installer ISO from PRX-02 (`10.10.1.202`) at:  
   `/var/lib/vz/template/iso/` — or download directly from the [releases page](../../releases).  
   Flash to USB: `dd if=inferno-appliance-vN.iso of=/dev/sdX bs=4M status=progress conv=fsync`

2. Boot the target machine from the USB. Anaconda will install the OS. (See [Known Issues](#️-known-issues) — the install is not fully unattended; watch for prompts.)

3. After install the node reboots. First-boot configuration runs automatically (~2 minutes):
   - Auto-detects NIC, derives Dante DEVICE_ID from MAC address
   - Auto-detects physical audio card
   - Writes `/etc/inferno.conf` and `~/.asoundrc`
   - Reboots again (second boot = first normal operation)

4. Open Cockpit at `https://<node-ip>:9090` → **Inferno** (sidebar) to configure mode, device name, audio cards, and channel counts.

---

## Management

| Interface | How to reach | Purpose |
|-----------|-------------|---------|
| **Cockpit** | `https://<node-ip>:9090` | Configure mode, audio cards, channel counts, device names. Service status, restart, journal viewer. |
| **SSH** | `ssh core@<node-ip>` | Advanced operations, log inspection, manual config edits. |

The `inferno-build` Copilot skill handles build triggering and status monitoring remotely.

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
VERSION=v11
NODE=192.168.1.46

# Stream upgrade tar from COPILOT-BUILD-01 directly into node
ssh root@10.10.1.98 \
  "cat /opt/inferno-build/inferno-appliance-${VERSION}.tar" \
  | ssh core@${NODE} 'sudo podman load'

# Stage new image and reboot
ssh core@${NODE} \
  "sudo bootc switch localhost/inferno-appliance:${VERSION} && sudo reboot"
```

If something is wrong after reboot:
```bash
ssh core@${NODE} "sudo bootc rollback && sudo reboot"
```

See [`docs/upgrade.md`](docs/upgrade.md) for the full procedure including multi-node upgrades.

---

## Building a Release

Use the **`inferno-build` Copilot skill** to trigger and monitor a build, or from the jumphost:

```bash
~/bin/inferno-build v12 "Your release notes here"
```

See [`docs/build-and-release.md`](docs/build-and-release.md) for the complete build and release process, artifact locations, and troubleshooting.

---

## Repository Structure

```
inferno-aoip-releases/
├── Containerfile               OS image definition (35 build steps)
├── config.toml                 bootc-image-builder config (no secrets)
├── build/
│   ├── build-release.sh        Full release build script (container → ISO → upgrade tar)
│   ├── inferno-configure.sh    First-boot configuration script (baked into image)
│   └── README.md               Build environment setup guide
├── cockpit-inferno/            Cockpit management UI — git submodule (github.com/legopc/cockpit-inferno)
├── branding/                   Cockpit branding assets — git submodule (github.com/legopc/inferno-branding)
├── iot-updater/                Cockpit OCI update delivery UI — git submodule (github.com/legopc/cockpit-iot-updater)
├── templates/
│   ├── alsa/                   ALSA config templates (%%PLACEHOLDER%% substituted at first boot)
│   ├── systemd/system/         System service units (statime-inferno, inferno-configure)
│   └── systemd/user/           User service templates (inferno-bridge, librespot, aux-tx, aux-rx…)
├── docs/
│   ├── architecture.md         Full system architecture, ALSA device hierarchy, PTP, service map
│   ├── build-and-release.md    Step-by-step build and release process
│   ├── cockpit-ui.md           Cockpit UI internals and ALSA/systemd provisioning logic
│   ├── upgrade.md              Node upgrade procedure (tar-based, no registry required)
│   ├── install-guide.md        Physical/VM installation guide
│   ├── operations.md           Lab hosts, IPs, credentials, operational runbook
│   └── troubleshooting.md      Common failures and fixes
├── scripts/
│   ├── probe-node.sh           Diagnose a running node
│   └── inferno-deploy.sh       Deploy/upgrade helper script
├── IMPROVEMENT_ROADMAP.md      Tracked defects and planned improvements
└── archived/                   Pre-bootc content (osbuild, ignition, ansible) — preserved for reference
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

### Image layers (Containerfile — 35 steps)

```
FROM fedora-bootc:43
  └─ dnf install: cockpit, alsa-utils, avahi, openssh, skopeo, curl
  └─ Download inferno-aoip.tar.gz → install statime, librespot, ALSA plugin
  └─ COPY templates/ → /etc/inferno/  (config templates with %%PLACEHOLDERs%%)
  └─ COPY cockpit-inferno/src/ → /usr/share/cockpit/inferno/  (management UI — git submodule)
  └─ COPY systemd units → /etc/systemd/system/ + /etc/inferno/systemd/user/
  └─ snd-aloop pinned to card index 5 (avoids conflicts with physical cards)
  └─ systemctl enable: sshd, cockpit.socket, avahi-daemon, statime-inferno, inferno-configure, iot-updater
  └─ systemctl mask: systemd-timesyncd, chronyd, ntpd  (PTP manages the clock)
  └─ useradd core:inferno123 + audio group + wheel NOPASSWD + linger pre-created
  └─ COPY iot-updater/ → cockpit page + server + apply script  (git submodule)
```

Images are built on **COPILOT-BUILD-01** (`10.10.1.98`) at `/opt/inferno-build/`.

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
| v11 | Built | Cockpit IoT Updater bundle support, iot-updater submodule, branding submodule |
| v10 | ✅ Production | USB hot-plug audio (udev), TX/RX channel selectors, conditional Spotify Connect name field, multi-card ALSA type multi, dynamic audio device panel |
| v9 | Superseded | Cockpit UI with full aux mode: split card selectors, channel counts, multi-card support, stable ALSA card IDs, audio devices panel, auto-refresh |
| v8 | Superseded | First physical install on HP EliteDesk 800G3. Spotify Connect + Dante TX functional. Cockpit UI replaces Python webserver. |
| v7 | Superseded | Added Cockpit modules, linger fix, WiFi NIC exclusion |
| v6 | Superseded | SELinux binary path fix, auto-reboot after configure, ordering cycle fix |
