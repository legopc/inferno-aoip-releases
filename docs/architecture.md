# Inferno AoIP — System Architecture

> How the whole stack fits together: from Spotify Connect and analog audio to Dante AoIP on the network.

---

## Overview

Inferno AoIP is a headless Linux appliance that bridges audio sources into a Dante Audio-over-IP network. It runs as a [bootc](https://containers.github.io/bootc/) immutable Fedora image — the OS is a container image that boots directly.

Three operating modes are supported:

| Mode | Audio path | Dante devices created |
|------|-----------|----------------------|
| **Spotify** | Spotify Connect → Dante TX | 1 TX device (`Name`) |
| **Aux In** | Analog capture → Dante TX | 1 TX device (`Name-TX`) |
| **Aux Out** | Dante RX → Analog playback | 1 RX device (`Name-RX`) |
| **Aux Bidir** | Analog capture → Dante TX **and** Dante RX → Analog playback | 1 TX + 1 RX device (`Name-TX`, `Name-RX`) |

---

## Component Stack

```
┌─────────────────────────────────────────────────────────────┐
│                  SPOTIFY MODE                               │
│                                                             │
│  Spotify App  ──(Spotify Connect)──▶  librespot             │
│                                           │                 │
│                                    writes PCM to            │
│                                    pcm.spotifyd             │
│                                    (44.1kHz SRC)            │
│                                           │                 │
│                                    pcm.inferno_mix          │
│                                    (dmix, loopback)         │
│                                           │                 │
│                              inferno-bridge reads           │
│                              hw:Loopback → inferno_spotify  │
│                                           │                 │
│                              ALSA plugin (inferno.so)       │
│                              ────────────────────           │
│                              statime PTP clock sync         │
│                                           │                 │
│                              ──── Dante network ────        │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│                  AUX IN MODE                                │
│                                                             │
│  Analog input (plughw:N,0)                                  │
│       │                                                     │
│  alsaloop (inferno-aux-tx.service)                          │
│       │  reads from hardware mic/line in                    │
│       │  writes to inferno_aux_tx                           │
│       │                                                     │
│  ALSA plugin (inferno.so)  PROCESS_ID 2  ALT_PORT 6004      │
│  ────────────────────────────────────────────────           │
│  statime PTP clock sync                                     │
│       │                                                     │
│  ──── Dante network ────                                    │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│                  AUX OUT MODE                               │
│                                                             │
│  ──── Dante network ────                                    │
│       │                                                     │
│  ALSA plugin (inferno.so)  PROCESS_ID 3  ALT_PORT 6008      │
│  inferno_aux_rx                                             │
│       │                                                     │
│  alsaloop (inferno-aux-rx.service)                          │
│       │  reads from inferno_aux_rx (Dante RX)               │
│       │  writes to hardware speaker/line out (plughw:N,0)   │
└─────────────────────────────────────────────────────────────┘
```

---

## ALSA Device Hierarchy

The Inferno ALSA plugin (`libasound_module_pcm_inferno.so`) is a custom PCM type that speaks the Dante AoIP protocol internally. It presents as a standard ALSA PCM device to the rest of the system.

```
~/.asoundrc defines:

pcm_type.inferno    ← registers the plugin shared library

pcm.inferno_spotify ← Dante TX device (Spotify mode)
    type inferno
    PROCESS_ID 1  ALT_PORT 6000  TX_CHANNELS 2  RX_CHANNELS 0
    DEVICE_ID <mac>0000

pcm.inferno_mix     ← dmix loopback mixing bus (Spotify only)
    type dmix  → hw:Loopback,0,0 (card 5, pinned via modprobe)

pcm.spotifyd        ← SRC bridge: 44.1kHz → 48kHz into inferno_mix
    type rate  → inferno_mix

pcm.inferno_aux_tx  ← Dante TX device (Aux In / Bidir)
    type inferno
    PROCESS_ID 2  ALT_PORT 6004  TX_CHANNELS 2  RX_CHANNELS 0
    DEVICE_ID <mac>0001
    NAME "<name>-TX"

pcm.inferno_aux_rx  ← Dante RX device (Aux Out / Bidir)
    type inferno
    PROCESS_ID 3  ALT_PORT 6008  TX_CHANNELS 0  RX_CHANNELS 2
    DEVICE_ID <mac>0002
    NAME "<name>-RX"

pcm.aux_tx_in       ← S32_LE format bridge (plug wrapper for inferno_aux_tx)
pcm.aux_rx_out      ← S32_LE format bridge (plug wrapper for inferno_aux_rx)
```

**DEVICE_ID derivation from MAC:**
```
MAC 18:60:24:24:aa:a8  →  MAC_CLEAN = 186024244aa8
  Spotify TX:  186024244aa80000   (PROCESS_ID 1)
  Aux TX:      186024244aa80001   (PROCESS_ID 2, last 4 hex + 1)
  Aux RX:      186024244aa80002   (PROCESS_ID 3, last 4 hex + 2)
```

Three distinct DEVICE_IDs are required so Dante Controller identifies them as three separate devices. The `ALT_PORT` values (6000, 6004, 6008) must also be distinct — each Inferno plugin instance binds 4 consecutive UDP ports (e.g. 6004–6007).

---

## Systemd Services

### System services (run as root)

| Unit | Purpose |
|------|---------|
| `statime-inferno.service` | PTP v1 clock daemon — locks to Dante master clock. Required by all Inferno plugin instances. Clock path: `/tmp/ptp-usrvclock` |
| `inferno-configure.service` | First-boot setup — runs once, gated by absence of `/etc/inferno.conf` |

### User services (run as `core`)

| Unit | Mode | Purpose |
|------|------|---------|
| `inferno-bridge.service` | Spotify | Reads `hw:Loopback,1,0` → writes to `pcm.inferno_spotify`. Keeps the Dante TX stream open continuously. |
| `inferno-keepalive.service` | Spotify | Opens `inferno_spotify` with silence when nothing is playing — keeps the Dante subscription alive so DC always shows the device |
| `librespot.service` | Spotify | Spotify Connect receiver — writes decoded audio to `pcm.spotifyd` |
| `librespot-watchdog.service` | Spotify | Restarts librespot if it stops writing audio |
| `inferno-aux-tx.service` | Aux In / Bidir | `alsaloop`: reads `plughw:<card_in>,0` → writes `inferno_aux_tx`. Bridges physical analog in to Dante TX. |
| `inferno-aux-rx.service` | Aux Out / Bidir | `alsaloop`: reads `inferno_aux_rx` → writes `plughw:<card_out>,0`. Bridges Dante RX to physical analog out. |
| `inferno-aux-keepalive.service` | (unused with rx) | Opens `inferno_aux_rx` with silence — **must NOT run alongside `inferno-aux-rx.service`** (competing Dante subscription owners cause streams to stop) |

### Service set per mode

```
Mode         Active user services
────────────────────────────────────────────────────────────
spotify      inferno-bridge  inferno-keepalive  librespot  librespot-watchdog
aux-in       inferno-aux-tx
aux-out      inferno-aux-rx
aux-bidir    inferno-aux-tx  inferno-aux-rx
```

---

## PTP Clock Synchronisation

`statime-inferno` implements PTP v1 (IEEE 1588) as a slave-only clock. It synchronises to the Dante master clock on the network (any Dante-enabled device can be master).

The plugin communicates with the clock daemon via a Unix socket at `/tmp/ptp-usrvclock`. Each Inferno plugin instance subscribes to this socket on startup and waits until the clock is valid before transmitting/receiving audio.

Log output on successful sync:
```
INFO  device_server: waiting for clock
INFO  device_server: clock ready
```

---

## Configuration Files

### `/etc/inferno.conf` (system-wide, managed by Cockpit)

```ini
INFERNO_MODE=spotify           # spotify | aux-in | aux-out | aux-bidir
INFERNO_NAME=Inferno-24AAA8    # legacy field (replaced by separate names below)
INFERNO_SPOTIFY_NAME=Inferno-24AAA8   # shown in Spotify app
INFERNO_DANTE_NAME=Inferno-24AAA8     # base name for Dante devices (see -TX/-RX below)
INFERNO_NIC=eno1               # Dante network interface
INFERNO_INTERFACE=192.168.1.46 # IP of NIC above (BIND_IP in ALSA config)
INFERNO_DEVICE_ID=186024244aa80000   # base Dante DEVICE_ID
INFERNO_DEVICE_ID_TX=186024244aa80001
INFERNO_DEVICE_ID_RX=186024244aa80002
INFERNO_AUDIO_CARD_IN=0        # ALSA card number for capture (aux modes)
INFERNO_AUDIO_CARD_OUT=0       # ALSA card number for playback (aux modes)
INFERNO_AUDIO_CARD=0           # legacy single-card field (kept for compatibility)
```

Written at first boot by `inferno-configure.sh`. Cockpit reads and updates this file (via `sudo -n tee`) when configuration is saved.

### `~/.asoundrc` (user, managed by Cockpit and configure script)

Defines all Inferno ALSA PCM devices. Written at first boot from templates. The Cockpit UI appends aux blocks (`inferno_aux_tx`, `inferno_aux_rx`) the first time an aux mode is saved.

**Critical**: When patching the `NAME` field (e.g. on device rename), sed must be scoped to each block individually to preserve `-TX`/`-RX` suffixes:
```bash
sed -i '/pcm\.inferno_spotify/,/^}/s/NAME "[^"]*"/NAME "NewName"/' ~/.asoundrc
sed -i '/pcm\.inferno_aux_tx/,/^}/s/NAME "[^"]*"/NAME "NewName-TX"/' ~/.asoundrc
sed -i '/pcm\.inferno_aux_rx/,/^}/s/NAME "[^"]*"/NAME "NewName-RX"/' ~/.asoundrc
```

### `~/.config/systemd/user/*.service`

User service units. Static units are copied from `/etc/inferno/systemd/user/` at first boot. Aux service files (`inferno-aux-tx.service`, `inferno-aux-rx.service`) are written with the card number substituted (`plughw:N,0`).

---

## First-Boot Configuration (`inferno-configure.sh`)

Runs once via `inferno-configure.service`, gated by absence of `/etc/inferno.conf`.

Steps:
1. Detect wired NIC (excludes lo, docker, WiFi, virbr)
2. Get IP and MAC from NIC
3. Derive `DEVICE_ID` (MAC + `0000`), TX/RX variants
4. Auto-detect physical audio card (first non-Loopback non-HDMI from `aplay -l`)
5. Derive device name from last 3 MAC octets: `Inferno-24AAA8`
6. Substitute `%%PLACEHOLDER%%` values in all templates
7. Write `~/.asoundrc` (spotify base + aux PCM blocks appended)
8. Write user service files (aux services with card number substituted)
9. Copy scripts to `~/bin/`
10. Enable linger + user services for `core`
11. Write `/etc/inferno.conf` (sentinel — prevents re-run)
12. Reboot

To force reconfiguration: `sudo rm /etc/inferno.conf && sudo reboot`

---

## Bootc Image Build

The image is defined in `Containerfile`. It is a standard OCI container image that boots directly via [bootc](https://containers.github.io/bootc/).

Key layers:
1. `FROM quay.io/fedora/fedora-bootc:41` — immutable Fedora base
2. `dnf install` — Cockpit, statime, alsaloop, alsa-utils, etc.
3. `COPY templates/` → `/etc/inferno/` — config templates baked in
4. `COPY cockpit/` → `/usr/share/cockpit/inferno/` — Cockpit UI baked in
5. `COPY build/inferno-configure.sh` → installed as `inferno-configure.service`
6. `snd-aloop` pinned to card index 5 via modprobe options (avoids conflicts with physical cards)

Built on PRX-01:
```bash
podman --storage-driver overlay \
  --storage-opt overlay.mount_program=/usr/bin/fuse-overlayfs \
  --root /mnt/inferno-build/storage \
  build -t inferno-aoip:v9 -f Containerfile .
```

---

## Network Ports

| Port(s) | Protocol | Service | Notes |
|---------|----------|---------|-------|
| 319, 320 | UDP | PTP (statime) | IEEE 1588 event + general |
| 6000–6003 | UDP | Inferno ALSA plugin (Spotify TX) | PROCESS_ID 1 |
| 6004–6007 | UDP | Inferno ALSA plugin (Aux TX) | PROCESS_ID 2 |
| 6008–6011 | UDP | Inferno ALSA plugin (Aux RX) | PROCESS_ID 3 |
| 9090 | TCP | Cockpit HTTPS | Management UI |
| 5353 | UDP | mDNS | Dante device discovery |
| 224.0.0.107 | UDP multicast | Dante control | Device announcement |
| 224.0.1.129 | UDP multicast | Dante audio | AoIP stream data |
