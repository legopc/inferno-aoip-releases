# Bluetooth → Dante Bridge (T470s)

This document covers the Bluetooth A2DP → Dante/AES67 bridge running on the
ThinkPad T470s (Arch Linux). This is a standalone bridge node — not a full
Inferno appliance — that receives audio from a paired phone and transmits it
as Dante audio.

---

## Architecture

```
Phone (A2DP/AAC)
    │
    ▼ Bluetooth (bluealsa)
bluealsa-aplay --volume=none -D bt_loopback
    │
    ▼ ALSA plug plugin (44100 Hz S16_LE → 48000 Hz S32_LE resampling)
hw:Loopback,0,2  (snd-aloop playback side, substream 2)
    │
    ▼ kernel snd-aloop loopback
hw:Loopback,1,2  (snd-aloop capture side, substream 2)
    │
    ▼ alsaloop (clock domain bridge)
inferno_bluetooth  (Dante TX, NAME="T470s-Bluetooth", port 6004)
    │
    ▼ Dante / AES67 (network)
dante-doos-RX  (inferno_aux_rx, port 6008)
    │
    ▼ alsaloop
plughw:2,0  (HD-Audio Generic, built-in audio output)
```

**Why the loopback?** Bluetooth uses the phone's audio clock (44100 Hz), while Dante
TX uses a PTP-synchronized clock (48000 Hz). The snd-aloop acts as an asynchronous
buffer between the two clock domains. Without it, `bluealsa-aplay` drops frames
("Dropping PCM frames") because the Dante TX PCM can't consume at the BT rate.

---

## Prerequisites

```bash
# Arch Linux packages
sudo pacman -S bluez bluez-utils bluez-tools alsa-utils
yay -S bluealsa-git  # or bluealsa from AUR

# Required kernel module
sudo modprobe snd-aloop pcm_substreams=4
# Make persistent:
echo "snd-aloop pcm_substreams=4" | sudo tee /etc/modules-load.d/snd-aloop.conf
echo "options snd-aloop pcm_substreams=4" | sudo tee /etc/modprobe.d/snd-aloop.conf

# CRITICAL: Disable PipeWire — it intercepts A2DP before bluealsa can see it
systemctl --user mask pipewire pipewire-pulse wireplumber
systemctl --user stop pipewire pipewire-pulse wireplumber
```

---

## bluealsa Setup

```bash
# Enable and configure bluealsa
sudo systemctl enable --now bluetooth.service

# Create bluealsa config (or ensure defaults are acceptable)
# bluealsa serves as the bridge between BlueZ and ALSA

# Configure bluealsa systemd service to enable A2DP sink
sudo mkdir -p /etc/systemd/system/bluealsa.service.d
sudo tee /etc/systemd/system/bluealsa.service.d/override.conf << 'EOF'
[Service]
ExecStart=
ExecStart=/usr/bin/bluealsa -p a2dp-sink
EOF
sudo systemctl daemon-reload
sudo systemctl restart bluealsa
```

## Bluetooth Pairing

```bash
# Start bluetooth agent (handles pairing PIN automatically)
# This should run as a user service or in background
bt-agent -c NoInputNoOutput &

# Make device discoverable
bluetoothctl power on
bluetoothctl discoverable on
bluetoothctl pairable on

# Device will show as "T470s" in phone's Bluetooth settings
# Pair from the phone — bt-agent accepts automatically
```

To verify a connected A2DP device:
```bash
bluetoothctl info PHONE_MAC | grep -E "Connected|UUID|Codec"
# Should show: A2DP profile UUID
```

---

## ALSA Configuration (`~/.asoundrc`)

```
# Dante TX — advertises as "T470s-Bluetooth" on Dante network
pcm.inferno_bluetooth {
    type inferno
    DEVICE_ID "54e1ad6a8b330001"   # derived from NIC MAC: 54:e1:ad:6a:8b:33 → ...0001
    ALT_PORT 6004
    TX_CHANNELS 2
    NAME "T470s-Bluetooth"
    SAMPLE_RATE 48000
}

# Loopback bridge — plug handles rate/format conversion
# BT delivers S16_LE @ 44100 Hz; loopback target is S32_LE @ 48000 Hz
pcm.bt_loopback {
    type plug
    slave {
        pcm "hw:Loopback,0,2"    # snd-aloop substream 2, playback side
        format S32_LE
        rate 48000
        channels 2
    }
}
```

**Why substream 2?** Substreams 0 and 1 may be in use by other ALSA applications.
Substream 2 (with `pcm_substreams≥4`) gives a clean dedicated channel.

**DEVICE_ID derivation:**
- NIC MAC: `54:e1:ad:6a:8b:33`
- Remove colons, lowercase: `54e1ad6a8b33`
- Append `0001`: `54e1ad6a8b330001`

---

## Systemd User Services

### inferno-bt-bridge.service
Waits for an active A2DP connection, then pipes audio to the loopback.

```ini
[Unit]
Description=Bluetooth A2DP to Dante bridge
After=sound.target bluealsa.service
Requires=inferno-bt-loop.service

[Service]
Type=simple
Restart=always
RestartSec=3
ExecStart=/bin/bash -c '\
  while ! bluealsa-aplay --list-pcms 2>/dev/null | grep -q A2DP-sink; do \
    sleep 2; \
  done; \
  exec bluealsa-aplay --volume=none -D bt_loopback'

[Install]
WantedBy=default.target
```

### inferno-bt-loop.service
Forwards audio from the loopback capture side to the Dante TX plugin.

```ini
[Unit]
Description=Loopback to Dante TX (alsaloop)
After=sound.target

[Service]
Type=simple
Restart=always
RestartSec=3
ExecStart=/usr/bin/alsaloop \
    -C hw:Loopback,1,2 \
    -P inferno_bluetooth \
    -r 48000 \
    -f S32_LE \
    -c 2 \
    -t 20000

[Install]
WantedBy=default.target
```

### Enable services

```bash
systemctl --user enable --now inferno-bt-bridge inferno-bt-loop
```

---

## Dante Routing

On the Dante Controller side:
1. The T470s advertises **T470s-Bluetooth** (2-channel TX)
2. Route it to the receiver node (e.g., `dante-doos-RX`)
3. On dante-doos: `alsaloop -C inferno_aux_rx -P plughw:2,0` plays received audio

---

## Verifying the Chain

### Step 1 — Check bluealsa sees the A2DP device
```bash
bluealsa-aplay --list-pcms
# Should show: bluealsa:DEV=C0:D5:E2:23:B9:C6,PROFILE=a2dp (or similar)
```

### Step 2 — Check loopback is receiving data
```bash
# Watch playback side
watch -n1 'cat /proc/asound/card5/pcm2p/sub0/status'
# hw_ptr should advance; appl_ptr should advance
```

### Step 3 — Check alsaloop is forwarding
```bash
# Capture side of loopback
cat /proc/asound/card5/pcm2c/sub2/status
# state should be RUNNING
```

### Step 4 — Check Dante flow
```bash
journalctl --user -u inferno-bt-loop -f
# Look for: "send returned error" (recovers automatically within ~6s)
# Absence of errors = flow is good
```

### Step 5 — Check dante-doos is playing
On dante-doos:
```bash
cat /proc/asound/card2/pcm0p/sub0/status
# hw_ptr should advance while audio flows
```

---

## Lessons Learned

### dmix causes appl_ptr=0 (silent audio)
Using dmix as an intermediate device for the loopback caused `appl_ptr` to stay
at 0 despite `hw_ptr` advancing. This means dmix was writing silence. Root cause:
MMAP timing mismatch between dmix's period size and the loopback slave.

**Fix:** Eliminate dmix entirely. Use `plug` directly on `hw:Loopback`.

### PipeWire intercepts A2DP
PipeWire grabs the A2DP profile before bluealsa sees it. Result: `bluealsa-aplay`
finds no devices.

**Fix:** `systemctl --user mask pipewire pipewire-pulse wireplumber`

### BT clock vs PTP clock — frame drops
Without the loopback buffer, `bluealsa-aplay` directly to the Dante TX plugin
causes "Dropping PCM frames" errors. The BT source runs at 44100 Hz on the
phone's clock; Dante TX is locked to PTP at 48000 Hz. They can't be directly
connected.

**Fix:** Use snd-aloop as an async buffer. The `plug` plugin handles resampling.

### Two writers cannot share an inferno PCM
Attempting to open the same inferno PCM device from two processes fails.

**Fix:** Only one process per inferno PCM instance. Use loopback + alsaloop to
serialize access.

### dmix IPC persists after service stop
Changing `period_size` in a dmix config while old IPC segments exist causes
conflicts.

**Fix:** `ipcrm -a` (remove all IPC segments) before restarting after dmix config changes.

---

## Key Values (T470s lab node)

| Parameter | Value |
|-----------|-------|
| NIC | `enp0s31f6` |
| NIC MAC | `54:e1:ad:6a:8b:33` |
| BT MAC | `94:B8:6D:B3:FF:96` |
| DEVICE_ID | `54e1ad6a8b330001` |
| ALT_PORT | `6004` |
| Dante TX name | `T470s-Bluetooth` |
| snd-aloop card | card 5 |
| Loopback substream | 2 |
| bluealsa A2DP codec | AAC (phone-dependent) |
