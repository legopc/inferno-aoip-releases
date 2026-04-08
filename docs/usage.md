# Usage Guide

## First Login

After a fresh install the `core` user password is set to `inferno123` but is **expired**. You must change it before you can access the node.

### Via SSH (console or terminal)

```bash
ssh core@<node-ip>
# You will immediately be prompted:
# WARNING: Your password has expired.
# New password:
# Retype new password:
```

Enter `inferno123` as the current password when asked, then set a new one. SSH login completes after the password is changed.

### Via Cockpit

Browse to `https://<node-ip>:9090` and log in with `core` / `inferno123`. Cockpit will present a password change prompt before proceeding to the dashboard.

### Via physical console

Same as SSH — you will be prompted to change the password immediately on first login.

> **Note:** Until the password is changed, no login method will work. This is intentional — it prevents nodes from being permanently accessible with a publicly known credential.

---


Access the Inferno panel via Cockpit at `https://<node-ip>:9090` → **Inferno AoIP** in the left sidebar.

The UI is organised into four tabs. **Config** is the default.

---

## 🔧 Config

### Device identity

| Field | What it sets |
|-------|-------------|
| **Spotify Name** | The name shown in Spotify apps as the playback target. Only visible in Spotify mode. Changing it restarts `librespot`. |
| **Dante TX Name** | The name shown in Dante Controller for the transmitter. Changing it restarts `inferno-bridge`. |

### Audio routing

| Field | Description |
|-------|-------------|
| **Mode** | The audio routing mode (see below) |
| **TX Channels** | Number of channels sent to Dante TX (2/4/6/8) |
| **Input Card** | ALSA soundcard used for capture (to Dante TX) |
| **Input Card 2** | Second capture card for channels 3-4 (only shown when TX Channels >= 4) |
| **RX Channels** | Number of channels received from Dante RX (2/4/6/8) |
| **Output Card** | ALSA soundcard used for playback (from Dante RX) |
| **Output Card 2** | Second playback card for channels 3-4 (only shown when RX Channels >= 4) |
| **Bitrate** | (read-only) Not supported at runtime -- requires ALSA reconfiguration |
| **Normalise** | (read-only) Not supported by this librespot build |

#### Modes

| Mode | Description |
|------|-------------|
| Spotify to Dante TX | Spotify Connect receiver. Audio: Spotify app -> librespot -> ALSA -> inferno-bridge -> Dante TX |
| Analog In to Dante TX | Capture from physical soundcard(s) and transmit over Dante |
| Dante RX to Analog Out | Receive from Dante and play to physical soundcard(s) |
| In + Out (bidirectional) | Both capture and playback simultaneously, with independent channel counts |

### Network

**Interface** -- the wired Ethernet interface used for Dante audio and PTP sync. Usually `eno1` or similar.

### Saving

Click **Save & Apply** to write the configuration and restart affected services. No reboot needed.

Click **Preview Changes** first to see a diff of what will change -- a modal shows old vs new values for every field that differs.

The unsaved badge in the header appears when there are pending changes.

---

## Services

Shows all Inferno systemd services with their current state (active/inactive/failed).

Each card has **Start**, **Stop**, and **Restart** buttons. The coloured left border indicates status:
- Green -- active and running
- Red -- failed
- Grey -- inactive (stopped)

**Restart All** at the top restarts every service in sequence with a live progress indicator.

### Journal

Select a service from the dropdown (or **All**) and click Refresh to load recent log entries. Log lines are colour-coded:
- Green -- success/OK messages
- Red -- errors
- Orange -- warnings
- Grey -- timestamps

Services refresh automatically every 20 seconds.

---

## Audio

### Volume Control

Shows a slider per active soundcard (cards currently selected in the Config panel).

- Slider range: 0-100%
- The dB value shown is the actual hardware level reported by ALSA
- Moving the slider updates the hardware immediately and persists the change via `alsactl store`
- **Set All to 100%** normalises all cards to 0 dB simultaneously

Which control is used: per card the plugin tries Master, then Headphone, then PCM.

### Audio Devices

Enumerates all ALSA cards and their devices via `aplay -l` and `arecord -l`.

- Capture devices are shown with a mic badge
- Playback devices with a speaker badge
- HDMI/DisplayPort outputs are excluded (not usable for Dante)
- Software loopback cards are shown dimmed

Click **Refresh** to re-scan (useful after plugging in a USB audio device).

---

## Monitoring

### Signal Chain

Reads live from `/etc/inferno.conf` and `/var/home/core/.asoundrc`. Shows:

| Row | Source |
|-----|--------|
| Mode | INFERNO_MODE in inferno.conf |
| Dante TX Name | INFERNO_DANTE_NAME or INFERNO_NAME |
| NIC | INFERNO_NIC |
| TX / RX Channels | INFERNO_TX_CHANNELS / INFERNO_RX_CHANNELS |
| TX / RX Latency | TX_LATENCY_NS / RX_LATENCY_NS from .asoundrc (converted to ms) |
| ALSA Format | format field in .asoundrc |
| Sample Rate | rate field in .asoundrc |

### System Info

| Row | Source |
|-----|--------|
| Hostname | /proc/sys/kernel/hostname |
| IP address | ip -4 addr show (nic) |
| Image version | bootc status |
| PTP status | journalctl -u statime-inferno (last sync line) |
| Uptime | uptime -p |
| Disk | df /sysroot (real disk on bootc -- avoids composefs overlay) |
| NIC traffic | 1-second delta of /sys/class/net/(nic)/statistics/ in KB/s or MB/s |
| Deploy sentinel | Presence of /var/lib/inferno/.deployed (informational) |

### PTP Sparkline

Live chart of `statime-inferno` clock offset samples from the systemd journal.

### Health Check

Click **Run Checks** to run all checks on demand:

| Check | Pass condition |
|-------|---------------|
| snd-aloop loaded | Present in /proc/asound/cards |
| PTP clock locked | "locked" found in recent statime-inferno journal |
| inferno-bridge active | systemctl --user is-active inferno-bridge = active |
| librespot active | systemctl --user is-active librespot = active (warn only -- needed in Spotify mode) |
| statime-inferno active | systemctl is-active statime-inferno = active |
| Disk < 80% used | Checks /sysroot (or /var as fallback) |
| NIC has IP address | ip -4 addr show (nic) returns an address |

### Dante Discovery

Scans the local network for Dante devices.

---

## Actions

| Button | Effect |
|--------|--------|
| **Re-deploy binaries** | Removes the deploy sentinel and reboots. On next boot inferno-deploy.sh re-downloads the latest Inferno binaries from GitHub. |
| **Reboot** | Reboots the node immediately. |

Both actions show a confirmation dialog before proceeding.

---

## Keyboard shortcuts

| Key | Action |
|-----|--------|
| Ctrl+S | Save & Apply config |
| Ctrl+R | Refresh all panels |
| 1 | Switch to Config tab |
| 2 | Switch to Services tab |
| 3 | Switch to Audio tab |
| 4 | Switch to Monitoring tab |
