# inferno-aoip-releases

Pre-built binaries and deployment tooling for the [Inferno AoIP](https://gitlab.com/lumifaza/inferno) project — a headless Spotify Connect receiver / AUX bridge that transmits audio over Dante.

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
