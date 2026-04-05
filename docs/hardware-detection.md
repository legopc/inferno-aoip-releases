# Inferno Appliance — Hardware Detection Architecture

> How the bootc appliance discovers and adapts to physical hardware at first boot.
> Read this before installing on new hardware or debugging unexpected behaviour.

---

## Overview

The Inferno Appliance image is **hardware-agnostic**. A single ISO installs identically on any x86_64 UEFI machine. All hardware-specific configuration is resolved at **first boot** by `inferno-configure.sh`, which writes `/etc/inferno.conf` as a sentinel (preventing re-run).

To force reconfiguration (e.g. after a NIC change): `rm /etc/inferno.conf && reboot`

---

## Detection Flow

```
First boot
    └── inferno-configure.sh runs (as root, via inferno-configure.service)
            │
            ├─ 1. Detect wired NIC  →  INFERNO_NIC
            ├─ 2. Wait for DHCP IP  →  INFERNO_INTERFACE
            ├─ 3. Read MAC address  →  MAC
            ├─ 4. Derive identifiers from MAC:
            │       INFERNO_DEVICE_ID   = MAC + "0000"
            │       INFERNO_DEVICE_ID_TX = MAC + "0001"
            │       INFERNO_DEVICE_ID_RX = MAC + "0002"
            │       INFERNO_NAME        = "Inferno-" + last 3 MAC octets (uppercase)
            ├─ 5. Substitute %%PLACEHOLDER%% in all config templates
            ├─ 6. Set hostname  →  "inferno-<mac-suffix-lowercase>"
            ├─ 7. Write /etc/inferno.conf  (sentinel)
            └─ 8. Reboot
```

On subsequent boots, `inferno-configure.service` exits immediately (sentinel present). All services read their config from the already-substituted files.

---

## Variable Reference

| Variable | Derived from | Example | Used in |
|----------|-------------|---------|---------|
| `INFERNO_NIC` | First wired non-virtual NIC | `eno1` | statime-inferno.toml, ALSA conf |
| `INFERNO_INTERFACE` | DHCP IPv4 on `$INFERNO_NIC` | `192.168.1.43` | statime-inferno.toml |
| `MAC` | `/sys/class/net/$NIC/address` | `18:60:24:24:aa:a8` | Base for all IDs |
| `INFERNO_NAME` | Last 3 MAC octets, uppercase | `Inferno-24AAA8` | Dante TX name, Spotify Connect name |
| `INFERNO_DEVICE_ID` | MAC + `0000` | `18602424aaa80000` | ALSA Dante plugin identity |
| `INFERNO_DEVICE_ID_TX` | MAC + `0001` | `18602424aaa80001` | ALSA Dante TX stream |
| `INFERNO_DEVICE_ID_RX` | MAC + `0002` | `18602424aaa80002` | ALSA Dante RX stream |
| `hostname` | MAC suffix, lowercase | `inferno-24aaa8` | System hostname, mDNS `.local` name |

---

## NIC Selection Logic

**Script:** `build/inferno-configure.sh` (lines 22–31)

```bash
INFERNO_NIC=$(ip -o link show | awk \
  '$2 != "lo:" && $2 !~ /^(docker|br-|veth|tun|tap|wl|virbr)/ \
  {print $2; exit}' | tr -d ':')
```

**Exclusions:**
| Pattern | Reason |
|---------|--------|
| `lo` | Loopback — not a real NIC |
| `docker`, `br-`, `veth` | Container bridge interfaces |
| `tun`, `tap` | VPN tunnels |
| `wl*` | WiFi — Dante requires wired Ethernet (jitter + multicast reliability) |
| `virbr*` | libvirt virtual bridges (appear on hypervisor-installed nodes) |

**Selection:** First interface from `ip -o link show` output order (kernel enumeration order) that passes all exclusions. On a typical EliteDesk with a single wired NIC, this is `eno1`.

**Fallback:** If no interface passes exclusions, logs all available interfaces and falls back to the first non-loopback interface. Node will require manual fix if this occurs.

**What can go wrong:**
- New NIC added post-install → different NIC selected. Fix: `rm /etc/inferno.conf && reboot`
- NIC renamed by udev rules → may not be detected. Check `/etc/udev/rules.d/`
- Dual-NIC machine → whichever NIC is enumerated first by the kernel wins. Verify with `ip link` before install.

---

## PTP Clock Detection (Hardware vs Software Timestamping)

**Config template:** `templates/inferno-ptpv1.toml`

```toml
[[port]]
interface = "%%INFERNO_NIC%%"
hardware-clock = "auto"
```

`hardware-clock = "auto"` instructs statime to probe for a PTP hardware clock device (`/dev/ptp*`) associated with the selected NIC. This happens at statime startup, not at first boot.

**Behaviour:**

| Condition | Outcome | PTP accuracy |
|-----------|---------|-------------|
| NIC has `/dev/ptp*` and supports hardware timestamping (`ethtool -T` shows `hardware-transmit`, `hardware-receive`) | Hardware PTP mode | ~100 ns offset from grandmaster |
| NIC has no hardware timestamping support | Software PTP mode | ~500 µs offset from grandmaster |

**Which NICs support hardware PTP in this lab:**

| NIC | Driver | HW PTP | Notes |
|-----|--------|--------|-------|
| Intel I219-LM | `e1000e` | ✅ Yes | EliteDesk-01 (800G2-1), 800G3-1 — ~100ns offset |
| Intel e1000e (EliteDesk 800 G2) | `e1000e` | ✅ Yes | Same driver family |
| Realtek RTL8111 | `r8169` | ❌ No | dante-doos — software timestamping only (~500µs) |
| VirtIO (QEMU VM) | `virtio_net` | ❌ No | All Proxmox VMs — software only |
| Intel WiFi | `iwlwifi` | ❌ No | Excluded from Dante NIC selection anyway |

**Impact of software PTP:**
Dante audio is robust to ~500µs PTP offset. Both hardware and software timestamping produce working Dante streams. Hardware timestamping is preferred for lower latency settings, but is not required for normal operation.

**To check hardware PTP capability before install (run on target machine):**
```bash
ethtool -T eno1   # or whichever NIC will be INFERNO_NIC
# Look for "hardware-transmit" and "hardware-receive" in the output
# Or check: ls /sys/class/net/eno1/device/ptp*/
```

The `probe-node.sh` script checks and reports this automatically.

---

## Audio Subsystem — What Is and Isn't Detected

**Not auto-detected:**
- Physical sound cards — the appliance ignores them entirely
- USB audio devices — not used

**Fixed at image build time:**
- `snd-aloop` (software loopback) is loaded by `modprobe.d` at index **5** (`/etc/modprobe.d/snd-aloop.conf`)
- Index 5 is hardcoded to avoid conflicts with physical cards (which typically occupy 0–4)
- ALSA config (`99-inferno.conf`, `.asoundrc`) references `hw:Loopback` by card index 5

**Impact of physical cards:**
If the machine has more than 4 physical sound cards enumerated before `snd-aloop` loads, there could be an index conflict. In practice this never happens on EliteDesk hardware. If it does, adjust `/etc/modprobe.d/snd-aloop.conf` and reboot.

---

## Configuration Files Written at First Boot

| File | Template | Content |
|------|----------|---------|
| `/etc/inferno.conf` | (generated) | Sentinel + all resolved variables |
| `/etc/statime-inferno.toml` | `templates/inferno-ptpv1.toml` | PTP config with NIC + IP substituted |
| `/etc/alsa/conf.d/99-inferno.conf` | `templates/alsa/99-inferno.conf` | ALSA Dante plugin with DEVICE_ID substituted |
| `/var/home/core/.asoundrc` | `templates/alsa/asoundrc.spotify` | User ALSA config for Spotify→Dante routing |
| `/var/home/core/.config/systemd/user/librespot.service` | `templates/systemd/user/librespot.service` | Spotify Connect with INFERNO_NAME substituted |

All other user systemd units are static (no placeholders) and are copied as-is.

---

## What Requires a Re-run of inferno-configure.sh

Delete `/etc/inferno.conf` and reboot to re-run configuration:

```bash
sudo rm /etc/inferno.conf && sudo reboot
```

**Triggers:**
- NIC changed or renamed
- MAC address changed (e.g. different NIC)
- IP changed from DHCP to static (edit the template instead — see below)
- Node needs a different INFERNO_NAME

**Note:** Re-running configuration regenerates all files from templates. Any manual edits to `/etc/statime-inferno.toml`, `.asoundrc`, etc. will be overwritten.

---

## Static IP (Override DHCP)

If DHCP is unavailable or a static IP is required:

1. Set static IP via NetworkManager before configuration runs:
   ```bash
   nmcli con mod "Wired connection 1" ipv4.addresses 192.168.1.50/24 \
     ipv4.gateway 192.168.1.1 ipv4.dns 192.168.1.1 ipv4.method manual
   ```
2. Then run first-boot configuration: `rm /etc/inferno.conf && reboot`

The script waits up to 60 seconds for an IPv4 address. If no IP is available at all, it writes `0.0.0.0` into `/etc/inferno.conf` and statime will fail to bind. Fix by editing `/etc/statime-inferno.toml` manually.

---

## Predicting Node Identity Before Install

Given a MAC address from `probe-node.sh` or DHCP lease records, you can calculate all node identities in advance:

```bash
MAC="18:60:24:24:aa:a8"
MAC_CLEAN=$(echo "$MAC" | tr -d ':')
MAC_SUFFIX=$(echo "$MAC_CLEAN" | tail -c 7 | tr '[:lower:]' '[:upper:]')

echo "Dante TX name:   Inferno-${MAC_SUFFIX}"
echo "Hostname:        inferno-$(echo ${MAC_SUFFIX} | tr '[:upper:]' '[:lower:]')"
echo "DEVICE_ID:       ${MAC_CLEAN}0000"
echo "mDNS:            inferno-$(echo ${MAC_SUFFIX} | tr '[:upper:]' '[:lower:]').local"
```
