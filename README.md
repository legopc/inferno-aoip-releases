# inferno-aoip-releases

Pre-built binaries and deployment tooling for the [Inferno AoIP](https://gitlab.com/lumifaza/inferno) project — a headless appliance that bridges Spotify Connect and analog audio into a Dante AoIP network.

## What Is Inferno AoIP?

Inferno AoIP is an immutable Linux appliance that bridges audio into a Dante Audio-over-IP network. It runs as a [bootc](https://containers.github.io/bootc/) image — the entire OS is a container image that boots directly (no package manager, no drift).

### Operating modes

| Mode | Audio path | Dante devices created |
|------|-----------|----------------------|
| **Spotify** | Spotify Connect → Dante TX | 1 TX device (`Name`) |
| **Aux In** | Analog capture → Dante TX | 1 TX device (`Name-TX`) |
| **Aux Out** | Dante RX → Analog playback | 1 RX device (`Name-RX`) |
| **Aux Bidir** | Analog in → Dante TX **and** Dante RX → Analog out | 1 TX + 1 RX (`Name-TX`, `Name-RX`) |

Aux modes support up to 8 channels and optionally combine two physical soundcards (e.g. two 2-channel USB cards into a single 4-channel Dante device).

---

## What This Repo Contains

This repo holds:
- **`Containerfile`** — the bootc image definition
- **`build/`** — `inferno-configure.sh` (first-boot configuration script)
- **`cockpit/`** — Cockpit management UI (native Cockpit page, no separate web server)
- **`templates/`** — ALSA, systemd, and PTP config templates baked into the image
- **`docs/`** — System architecture and UI documentation

A nightly GitHub Actions CI pipeline also builds Inferno binaries from source and publishes them as a release tarball:

```
https://github.com/legopc/inferno-aoip-releases/releases/latest/download/inferno-aoip.tar.gz
```

The tarball contains:
```
inferno-aoip/
├── bin/
│   ├── statime             PTP daemon (Inferno fork)
│   └── librespot           Spotify Connect receiver
├── lib/
│   └── libasound_module_pcm_inferno.so   ALSA Dante plugin
├── templates/
│   ├── systemd/system/statime-inferno.service
│   ├── systemd/user/inferno-bridge.service
│   ├── systemd/user/inferno-keepalive.service
│   ├── systemd/user/librespot.service
│   ├── systemd/user/librespot-watchdog.service
│   ├── systemd/user/inferno-aux-tx.service
│   ├── systemd/user/inferno-aux-rx.service
│   ├── systemd/user/inferno-aux-keepalive.service
│   ├── alsa/asoundrc.spotify
│   ├── alsa/asoundrc.aux
│   ├── alsa/99-inferno.conf
│   ├── inferno-ptpv1.toml
│   ├── inferno-sink-event
│   └── librespot-watchdog
├── scripts/
│   └── inferno-deploy.sh
└── VERSION
```

---

## First-Boot Deployment (bootc image)

The bootc image is installed via an ISO built with `osbuild`. After installation:

1. The node boots into the immutable Fedora image
2. `inferno-configure.service` fires on first boot (gated by absence of `/etc/inferno.conf`):
   - Auto-detects wired NIC and IP
   - Derives Dante DEVICE_ID from MAC address
   - Auto-detects physical audio card (first non-Loopback non-HDMI card)
   - Derives default device name from MAC: `Inferno-24AAA8`
   - Downloads the latest binary tarball from this repo
   - Writes `~/.asoundrc`, user service files, PTP config
   - Writes `/etc/inferno.conf` (prevents re-run)
   - Reboots
3. After the second reboot the node is fully running

---

## Cockpit Management UI

Access at `https://node-ip:9090` → Inferno (sidebar).

The Inferno Cockpit page provides:
- **Live service status** — per-service start/stop/restart for statime, librespot, inferno-bridge, inferno-aux-tx, inferno-aux-rx
- **Configuration** — mode, device names, NIC, audio cards, channel counts — applied immediately without reboot
- **Audio devices panel** — shows all detected soundcards with capture/playback capabilities; auto-refreshes on load
- **Journal viewer** — per-service log output
- **Actions** — restart all, trigger binary re-deploy, reboot

### Configuration keys (`/etc/inferno.conf`)

| Key | Values | Notes |
|-----|--------|-------|
| `INFERNO_MODE` | `spotify` / `aux-in` / `aux-out` / `aux-bidir` | Active operating mode |
| `INFERNO_SPOTIFY_NAME` | string | Name shown in Spotify app |
| `INFERNO_DANTE_NAME` | string | Base name for Dante devices (`-TX`/`-RX` appended for aux) |
| `INFERNO_NIC` | NIC name or `auto` | Dante network interface |
| `INFERNO_AUDIO_CARD_IN` | ALSA short ID e.g. `PCH` | Capture card (stable across reboots) |
| `INFERNO_AUDIO_CARD_OUT` | ALSA short ID e.g. `PCH` | Playback card |
| `INFERNO_AUDIO_CARD_IN2` | ALSA short ID or `none` | Optional second capture card for multi-card TX |
| `INFERNO_AUDIO_CARD_OUT2` | ALSA short ID or `none` | Optional second playback card for multi-card RX |
| `INFERNO_TX_CHANNELS` | `2` / `4` / `6` / `8` | Dante TX channel count |
| `INFERNO_RX_CHANNELS` | `2` / `4` / `6` / `8` | Dante RX channel count |

See [`docs/cockpit-ui.md`](docs/cockpit-ui.md) for full UI internals and [`docs/architecture.md`](docs/architecture.md) for the system architecture.

---

## Upgrading

**Inferno binary update:**
```bash
# Via Cockpit: Inferno page → Actions → "Trigger re-deploy + reboot"
# Via SSH:
sudo rm /var/lib/inferno/.deployed && sudo systemctl reboot
```

**Config change:**
```bash
# Via Cockpit (recommended): https://node-ip:9090 → Inferno page
# Via SSH (manual):
sudo nano /etc/inferno.conf
systemctl --user restart inferno-aux-tx   # example for aux-in mode
```

---

## Credentials (lab use only)

| Item | Value |
|------|-------|
| OS user | `core` |
| Password | see internal documentation |
| sudo | passwordless (wheel NOPASSWD in sudoers) |
| SSH | password auth enabled; public key auth also works |

---

## Version History

| Version | Status | Notes |
|---------|--------|-------|
| v10 | ✅ Production | Hot-plug USB audio support (udev rules), dynamic ALSA device detection on add/remove, Spotify Connect name field conditional display, TX/RX channel selectors, multi-card support |
| v9 | Superseded | Cockpit UI with full aux mode: split card selectors, channel counts, multi-card support (ALSA type multi), stable ALSA card IDs, audio devices panel, auto-refresh |
| v8 | Superseded | First physical install on HP EliteDesk 800G3. Spotify Connect + Dante TX functional. Cockpit UI replaces Python webserver. |
| v7 | Superseded | Added Cockpit modules, linger fix, WiFi NIC exclusion |
| v6 | Superseded | — |

---

## Build (PRX-01)

```bash
ssh root@10.10.1.201
cd /mnt/inferno-build/inferno-aoip-releases && git pull
podman --storage-driver overlay \
  --storage-opt overlay.mount_program=/usr/bin/fuse-overlayfs \
  --root /mnt/inferno-build/storage \
  build -t inferno-aoip:v10 -f Containerfile .
```


## What This Repo Does

A nightly GitHub Actions CI pipeline:
1. Clones [inferno](https://gitlab.com/lumifaza/inferno), [statime](https://github.com/teodly/statime) (inferno-dev branch), and [librespot](https://github.com/librespot-org/librespot) from source
2. Builds all three as release binaries on Ubuntu 24.04 (glibc 2.39 — compatible with Fedora IoT 43)
3. Bundles binaries + deployment templates/scripts into `inferno-aoip.tar.gz`
4. Publishes as a GitHub Release with a **stable `latest` URL**

## Stable Download URL

```
https://github.com/legopc/inferno-aoip-releases/releases/latest/download/inferno-aoip.tar.gz
```

This URL always points to the most recent successful build.

## Tarball Contents

```
inferno-aoip/
├── bin/
│   ├── statime             PTP daemon (Inferno fork)
│   ├── librespot           Spotify Connect receiver
│   └── inferno-web.py      Web config UI (Python 3, stdlib only)
├── lib/
│   └── libasound_module_pcm_inferno.so   ALSA plugin
├── templates/
│   ├── systemd/system/statime-inferno.service
│   ├── systemd/user/inferno-bridge.service
│   ├── systemd/user/inferno-keepalive.service
│   ├── systemd/user/librespot.service
│   ├── systemd/user/librespot-watchdog.service
│   ├── systemd/user/inferno-aux-tx.service
│   ├── systemd/user/inferno-aux-rx.service
│   ├── systemd/user/inferno-aux-keepalive.service
│   ├── systemd/user/inferno-web.service
│   ├── alsa/asoundrc.spotify
│   ├── alsa/asoundrc.aux
│   ├── alsa/99-inferno.conf
│   ├── inferno-ptpv1.toml
│   ├── inferno-sink-event
│   └── librespot-watchdog
├── scripts/
│   └── inferno-deploy.sh
└── VERSION
```

## First-Boot Deployment (Fedora IoT)

### Step 1 — Prepare Ignition JSON

Copy `ignition/inferno-template.ign` and customise:
1. Generate password hash: `openssl passwd -6 YOUR_PASSWORD`
2. Set `INFERNO_CORE_PASSWORD_HASH` in the JSON
3. Edit the `/etc/inferno.conf` seed inside the JSON:
   - `INFERNO_MODE` — `spotify` or `aux`
   - `INFERNO_NAME` — device name shown in Dante Controller / Spotify
   - `INFERNO_NIC` — NIC name (or `auto` to auto-detect)
   - `INFERNO_AUDIO_CARD` — ALSA card number for aux mode

### Step 2 — Install Fedora IoT

Install from the Fedora IoT 43 installer ISO. After Anaconda finishes (before first reboot):
1. Mount the EFI/boot partition (p2)
2. Place Ignition config: `cp inferno.ign /mnt/p2/ignition/config.ign`
3. Unmount and reboot

### Step 3 — First boot

Ignition runs, then `inferno-firstboot.service` fires and:
1. Downloads `inferno-aoip.tar.gz` from this repo's latest release
2. Runs `inferno-deploy.sh` which:
   - Auto-detects NIC, derives DEVICE_ID from MAC
   - Installs binaries to `/var/lib/inferno/`
   - Deploys mode-specific ALSA config, systemd units, PTP config
   - Enables all services
   - Reboots

After the second reboot the node is fully running.

## Web Management

| Interface | URL | Purpose |
|-----------|-----|---------|
| Cockpit | `https://node-ip:9090` | Full management: Inferno config, service status/restart, hostname, NIC, audio card, OS upgrades, terminal |

The **Inferno** page appears in the Cockpit sidebar and provides:
- Live service status with per-service restart/start/stop
- Config editor (mode, device name, NIC, audio card) — applied without reboot
- Hostname change
- Journal viewer per service
- Quick actions: restart all, trigger re-deploy, reboot

## Upgrading

**OS upgrade (Fedora IoT 43 → 44):**
```bash
rpm-ostree upgrade && systemctl reboot
# Or: use the "OS updates" page in Cockpit
```

**Inferno binary update:**
```bash
# Via Cockpit: Inferno page → Actions → "Trigger re-deploy + reboot"
# Via SSH/Cockpit terminal:
sudo rm /var/lib/inferno/.deployed && sudo systemctl reboot
# On next boot, deploy.sh re-runs and downloads the latest tarball
```

**Inferno config change:**
```bash
# Via Cockpit: https://node-ip:9090 → Inferno page → Config section
# Via SSH:
sudo nano /etc/inferno.conf
systemctl --user restart librespot.service   # (spotify mode example)
```

## Credentials (lab use only)

| Item | Value |
|------|-------|
| OS user | `core` |
| Password | see internal documentation |
| sudo | passwordless (configured by Ignition) |
| SSH | password auth enabled; public key auth also works |

## Version History

| Version | Status | Notes |
|---------|--------|-------|
| v8 | ✅ Production — validated | First physical install on HP EliteDesk 800G3 confirmed working. Audio group bug fixed (`/etc/group` direct write bypassing NSS). Spotify Connect + Dante TX functional. Cockpit UI replaces port-8080 Python webserver. |
| v7 | Superseded | Added Cockpit modules, linger fix, WiFi NIC exclusion |
| v6 | Superseded | — |

## osbuild Blueprint

`osbuild/inferno-aoip.toml` is the blueprint for building a custom Fedora IoT 43 installer ISO.

**Before building:**
1. Replace `INFERNO_CORE_PASSWORD_HASH` with a real hash: `openssl passwd -6 YOUR_PASSWORD`
2. Install osbuild on a Fedora machine: `sudo dnf install osbuild-composer composer-cli`
3. Push blueprint and build:
   ```bash
   sudo composer-cli blueprints push osbuild/inferno-aoip.toml
   sudo composer-cli compose start inferno-aoip iot-installer
   sudo composer-cli compose results <UUID>   # download ISO when done
   ```
