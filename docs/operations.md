# Inferno AoIP — Operations Reference

> Internal lab documentation. Credentials are lab-use only — security is not a concern.
> **GitHub PAT**: stored in `~/copilot_projects/key` — never commit to repo.

---

## Hosts

### Proxmox Cluster

| Node | IP | Hostname |
|------|-----|----------|
| PRX-01 | 10.10.1.201 | HVP-PRX-01-MGMT |
| PRX-02 | 10.10.1.202 | HVP-PRX-02-MGMT |

**SSH:**
```bash
ssh -i ~/.ssh/inferno_proxmox root@10.10.1.201   # PRX-01
ssh -i ~/.ssh/inferno_proxmox root@10.10.1.202   # PRX-02
```

**API:**
- Endpoint: `https://10.10.1.201:8006/api2/json`
- Token ID: `root@pam!api_user`
- Token secret: `c8e5c26d-da78-4e38-aa9e-c7a08b363e14`
- Header: `PVEAPIToken=root@pam!api_user=c8e5c26d-da78-4e38-aa9e-c7a08b363e14`

**Storage (PRX-01):**
- `HVP-PRX-01-VMDISK01` — VM disks (preferred)
- `/mnt/inferno-build` — 25GB LV for ISO builds (also bind-mounted as `/var/lib/containers/storage`)
- **Root FS is 99% full — never write large files to /**

### Physical Inferno Nodes

| Host | IP | User | Notes |
|------|----|------|-------|
| dante-doos | 192.168.1.25 | legopc | **Production** — Dante RX → Analog Out, Arch Linux, RTL8111 |
| 800G2-1 (EliteDesk-01) | 192.168.1.43 | legopc | **Production TX** — Arch Linux, Intel I219-LM, HW PTP ~100ns |
| 800G3-1 | 192.168.1.46 | legopc | Arch Linux, Intel I219-LM, `/dev/ptp0` ✅, NIC `eno1` — not yet configured |
| EliteDesk-02 | 192.168.1.47 | legopc | Arch Linux (pre-install), MAC `18:60:24:24:aa:a8`, NIC `eno1` e1000e, 224GB SSD, i5-6500T — **BIOS must be set to UEFI before ISO install** |
| T470s | 192.168.1.45 | legopc | Bluetooth bridge node, pw: `312858` |

**SSH (all physical nodes):**
```bash
ssh -i ~/.ssh/inferno_proxmox legopc@192.168.1.25   # dante-doos
ssh -i ~/.ssh/inferno_proxmox legopc@192.168.1.43   # EliteDesk-01 (800G2-1)
ssh -i ~/.ssh/inferno_proxmox legopc@192.168.1.46   # 800G3-1
ssh -i ~/.ssh/inferno_proxmox legopc@192.168.1.47   # EliteDesk-02 (pre-install)
ssh -o StrictHostKeyChecking=no legopc@192.168.1.45  # T470s (pw: 312858)
```

### Proxmox VMs — Inferno Test

| VMID | Name | Node | IP | Notes |
|------|------|------|----|-------|
| 105 | COPILOT-ARCH-TEST-01 | PRX-02 | 10.10.1.75 | Arch Linux — Ansible e2e test complete |
| 106 | COPILOT-NIXOS-TEST-01 | PRX-02 | 10.10.1.74 | NixOS 24.11 live ISO |
| 109 | COPILOT-FEDORA-IOT-TEST-02 | PRX-01 | 10.10.1.78 | Fedora IoT 42 — OS only |
| 110 | COPILOT-FEDORA-IOT-TEST-03 | PRX-01 | 10.10.1.79 | Fedora IoT 42 — Inferno stack |
| 111 | inferno-eea64f | PRX-01 | 10.10.1.97 (MAC: BC:24:11:EE:A6:4F) | Inferno Appliance bootc image v5 — verified working. Dante TX: `Inferno-EEA64F`. SSH: `core@10.10.1.97` via PRX-01 jump (pw: inferno123) |

### Proxmox VMs — Production (do not touch)

| VMID | Name | Node |
|------|------|------|
| 100 | HVP-VM-01-MGMT01 | PRX-01 |
| 103 | HVP-VM-04-JUMPHOST01 | PRX-01 |
| 104 | HVP-VM-05-OXIDIZED01 | PRX-01 |
| 201 | HVP-VM-13-WLC01-OLD | PRX-01 |
| 107 | HVP-VM-06-LIBRENMS01 | PRX-02 |
| 202 | HVP-VM-14-WLC02-OLD | PRX-02 |

---

## Credentials

| Resource | Username | Password / Key |
|----------|----------|----------------|
| Proxmox root SSH | `root` | key: `~/.ssh/inferno_proxmox` / pw: `Schnitzel-king1` |
| Inferno `core` user (VMs/physical) | `core` | `inferno123` |
| LUKS (Fedora IoT VMs) | — | `inferno123` |
| EliteDesk-01 / T470s | `legopc` | `312858` |
| All other nodes | `legopc` | `inferno123` |
| Proxmox API token | `root@pam!api_user` | `c8e5c26d-da78-4e38-aa9e-c7a08b363e14` |
| GitHub account | `legopc` | PAT in `~/copilot_projects/key` (scopes: repo, workflow) |

SSH key for all nodes: `~/.ssh/inferno_proxmox` (ed25519)
```
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILI+T7Koyd+yPIskHka+byxPdg/oQ4Zr7LEoWKI8G/6d copilot-inferno
```

---

## Web Interfaces

| Interface | URL | Credentials |
|-----------|-----|-------------|
| Proxmox Cockpit (PRX-01) | `https://10.10.1.201:9090` | `core` / `inferno123` |
| Proxmox Cockpit (PRX-02) | `https://10.10.1.202:9090` | `core` / `inferno123` |
| Inferno Web UI | `http://<node-ip>:8080` | — |
| Proxmox UI | `https://10.10.1.201:8006` | API token or root |
| FortiGate | `https://10.10.1.1` | — |

---

## GitHub / CI

| Resource | Value |
|----------|-------|
| Account | `legopc` |
| CI repo | `legopc/inferno-aoip-releases` (public) |
| Workflow | `.github/workflows/nightly-build.yml` |
| Stable tarball | `https://github.com/legopc/inferno-aoip-releases/releases/latest/download/inferno-aoip.tar.gz` |

**Trigger CI run:**
```bash
TOKEN=$(cat ~/copilot_projects/key | tr -d '[:space:]')
curl -s -o /dev/null -w "%{http_code}" -X POST \
  -H "Accept: application/vnd.github+json" \
  -H "Authorization: Bearer $TOKEN" \
  "https://api.github.com/repos/legopc/inferno-aoip-releases/actions/workflows/nightly-build.yml/dispatches" \
  -d '{"ref":"main"}'
# 204 = success
```

---

## DHCP / IP Lookup

FortiGate DHCP leases API (read-only token):
```bash
curl -sk -H "Authorization: Bearer mH1x975mHzfQwHQznf5qnf1gys5dGp" \
  "https://10.10.1.1/api/v2/monitor/system/dhcp?vdom=root"
```

Find VM by MAC on PRX-01:
```bash
ip neigh | grep -i "XX:XX:XX"   # use last 3 octets of MAC
```

---

## Production Architecture

```
EliteDesk-01 (192.168.1.43)              dante-doos (192.168.1.25)
  Spotify Connect (librespot)              inferno_rx (Dante RX)
      ↓ speexrate_best                          ↓ arecord S32_LE
  inferno_spotify (TX, Dante)              ALC221 DAC → 3.5mm analog out
      ↓↓↓↓↓ Dante network ↓↓↓↓↓↓↓↓↓↓↓↓↓↑↑↑
  Dante Controller: subscribe dante-doos RX ← EliteDesk-01 TX
```

PTP: Both nodes slave to MXWANI8 grandmaster. EliteDesk-01 has hardware timestamping (~100ns offset). dante-doos has software PTP (~500µs offset — adequate for Dante).

---

## Troubleshooting

### dante-doos: Inferno stream changes fail / `inferno-aux-rx` won't open

**Symptom:** Changing the Dante Controller subscription on dante-doos fails or `inferno-aux-rx` errors on restart.

**Cause:** `inferno-aux-keepalive.service` was dual-opening `inferno_aux_rx`, holding the device and blocking stream changes.

**Fix:** `inferno-aux-keepalive` was stopped and **disabled permanently**. Do not re-enable it.

---

### dante-doos: "flow creation in progress" → "unresolved" loop when subscribing to T470s-Bluetooth

**Symptom:** dante-doos (`inferno-aux-rx`) subscribes to `TX 1@T470s-Bluetooth` and `TX 2@T470s-Bluetooth`. Subscription handshake succeeds (mDNS resolves, control messages exchange), but dante-doos logs:
```
WARN  channels_subscriber] flow index=0 timeout (not receiving media packets)
WARN  channels_subscriber] channel subscribed to TX 1@T470s-Bluetooth is orphaned now
```
This repeats in a 10-second retry loop.

**Root cause (confirmed 2026-04-04):** The T470s `inferno-bt-loop.service` (alsaloop Loopback→Dante TX) develops a **TX ring buffer lag** after extended uptime (~14+ hours). When a new Dante subscriber connects and the TX plugin tries to create a new multicast flow, it detects a massive lag (~115702 samples = 2.4 seconds at 48kHz) and **destroys the flow** before transmitting any RTP:
```
ERROR flows_tx] tx lag of 115702 samples detected, or media clock jumped, dropout occurs!
WARN  tx_multicasts] flows_tx will be destroyed soon, not activating transmitter
```
The control-plane subscription succeeds but no audio RTP packets are ever sent, causing the 8-second media timeout on dante-doos.

**This is NOT a network/WiFi issue.** Both dante-doos and T470s are on wired ethernet, same L2 segment, multicast group join is confirmed on both sides.

**This is NOT a PTP clock mismatch.** Both run `statime` with `protocol-version = "PTPv1"`, `domain = 0` — both synced to same grandmaster with <5µs offset.

**Immediate fix:**
```bash
# SSH to T470s and restart the Dante TX service
ssh -o StrictHostKeyChecking=no legopc@192.168.1.45  # pw: 312858
systemctl --user restart inferno-bt-loop
```
Then re-attempt the subscription in Dante Controller. The service reinitializes cleanly with a fresh ring buffer.

**Long-term fix (deployed):** Added `RuntimeMaxSec=6h` to `inferno-bt-loop.service` on T470s. Systemd restarts every 6 hours automatically, preventing long-uptime lag accumulation. A brief 2-second audio gap occurs at restart — acceptable for Bluetooth bridge use case.

**Service file location on T470s:** `~/.config/systemd/user/inferno-bt-loop.service`

---

### T470s: Phone pause causes new inferno subscribers to fail ("flow creation in progress" → "unresolved")

**Symptom:** After the phone pauses A2DP playback, new inferno Dante subscribers (e.g. dante-doos `inferno-aux-rx`) cannot establish a flow. Existing hardware Dante connections (e.g. Shure) may persist, but new inferno flows fail with the same TX lag error:
```
ERROR flows_tx] tx lag of 115702 samples detected, or media clock jumped, dropout occurs!
```

**Root cause:** When the phone pauses, `bluealsa-aplay` stops writing to `hw:Loopback,0,2`. The snd-aloop loopback goes idle, but `inferno-bt-loop` (alsaloop reading `hw:Loopback,1,2`) keeps running. With no writer on the playback side, the loopback is starved and the TX ring buffer accumulates massive lag. When a new subscriber connects, the lag is detected and the flow is destroyed before any RTP is sent.

**Immediate fix:** Restart bt-loop manually:
```bash
ssh -o StrictHostKeyChecking=no legopc@192.168.1.45  # pw: 312858
systemctl --user restart inferno-bt-loop
```

**Long-term fix (deployed):** Added `PartOf=inferno-bt-bridge.service` to `inferno-bt-loop.service`. When `inferno-bt-bridge` stops (phone pauses → bluealsa-aplay exits), systemd stops `inferno-bt-loop` too. When `inferno-bt-bridge` restarts (phone resumes + A2DP reconnects), `inferno-bt-loop` restarts fresh with a clean ring buffer. `RestartSec` also reduced to 2s for faster recovery.

---

### T470s: `inferno-bt-keepalive` and `inferno-keepalive` are in failed state

**Expected.** Both services were intentionally stopped and disabled (similar to `inferno-aux-keepalive` on dante-doos). Keepalive services that write silence (`aplay /dev/zero`) to ALSA devices were causing interference with the main audio services. They are **disabled** and will not restart on reboot. Ignore the `failed` status.

---

## Key File Locations

| File | Purpose |
|------|---------|
| `build/config.toml` | bootc-image-builder ISO config |
| `build/inferno-configure.sh` | First-boot config script |
| `Containerfile` | Appliance container image definition |
| `docs/install-guide.md` | Authoritative install guide |
| `docs/bluetooth-bridge.md` | Bluetooth bridge docs |
| `config/bluetooth/inferno-bt-bridge.service` | BT bridge — requires `--volume=software` |
| `ignition/inferno-template.ign` | Ignition template for appliance VMs |
| `ansible/` | Ansible roles and playbooks |
| `~/copilot_projects/key` | GitHub PAT — never commit |
| PRX-01: `/mnt/inferno-build/` | ISO build workspace (25GB LV) |
