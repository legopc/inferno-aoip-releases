# EliteDesk 800 G2 — Fedora IoT Physical Deploy Guide

Complete step-by-step guide for deploying the Inferno AoIP stack on a physical
HP EliteDesk 800 G2 running Fedora IoT 42.

---

## Target Specs

| Item | Value |
|------|-------|
| Machine | HP EliteDesk 800 G2 |
| OS | Fedora IoT 42 x86_64 |
| NIC | Intel I219-LM (name detected on first boot — likely `eno1` or `enp0s31f6`) |
| User | `core` |
| Password | `inferno123` |
| LUKS passphrase | `inferno123` |
| SSH key | `~/.ssh/inferno_proxmox` (private) / `ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILI+T7Koyd+yPIskHka+byxPdg/oQ4Zr7LEoWKI8G/6d copilot-inferno` (public) |
| Network | 192.168.1.x (DHCP) |
| Device name | `EliteDesk-Fedora` (Spotify Connect + Dante Controller) |

> **Difference from VM approach:** LUKS is set up during Anaconda install — no post-install
> keyfile cpio tricks (gotcha #9 from VM guide does NOT apply here).

---

## Phase 1 — Media Preparation (do this on a Windows/Linux workstation)

### 1.1 Download Fedora IoT ISO

```
https://dl.fedoraproject.org/pub/alt/iot/42/x86_64/iso/Fedora-IoT-42-x86_64-dvd.iso
```

Or check for latest at: https://fedoraproject.org/iot/download/

### 1.2 Flash to USB (pick one)

**Linux:**
```bash
sudo dd if=Fedora-IoT-42-x86_64-dvd.iso of=/dev/sdX bs=4M status=progress oflag=sync
# Replace /dev/sdX with your USB drive (check with lsblk)
```

**Windows (Balena Etcher):**
- Download from https://etcher.balena.io
- Select ISO → Select USB → Flash

---

## Phase 2 — Installation (keyboard + monitor on EliteDesk)

### 2.1 Boot from USB
1. Insert USB into EliteDesk
2. Power on, press **F9** (HP boot menu) or **F10** (BIOS setup → boot order)
3. Select the USB drive
4. At Fedora IoT boot menu: select **"Install Fedora IoT 42"**

### 2.2 Anaconda Installer

Work through the installation summary screen:

**Network & Hostname:**
- Connect Ethernet cable to LAN (192.168.1.x)
- Enable the NIC (toggle it on)
- Set hostname: `inferno-fiot-elitedesk`
- Note the IP address shown — you'll need it for SSH

**Storage:**
- Select the internal SSD/HDD
- Choose **"Custom"** partitioning
- Create layout:
  - `/boot/efi` — 512 MB, EFI System Partition (vfat)
  - `/boot` — 1 GB, ext4
  - `/` — rest of disk, **enable encryption** (LUKS), passphrase: `inferno123`
- Click **Done**, accept summary

> Note: Anaconda handles LUKS cleanly — the bootloader can prompt for passphrase on boot.
> No post-install keyfile embedding needed (unlike the Proxmox VM approach).

**Root account:** Leave disabled (use `core` via Ignition).

**User creation:** Leave empty (Ignition handles `core` user).

Click **Begin Installation**.

### 2.3 Place Ignition Config (CRITICAL — before first boot)

When installation completes, **do NOT reboot yet**.

Open a terminal (Ctrl+Alt+F2 or use the "Shell" option if available):

```bash
# Find the EFI/boot partition (should be /dev/sda1 or similar)
lsblk

# Mount the boot partition
mount /dev/sda2 /mnt   # adjust sda2 to your /boot partition

# Create ignition directory and copy config
mkdir -p /mnt/ignition
# Transfer the ignition config (copy elitedesk2-ignition.json here)
# Option A: USB with the file
cp /run/media/*/elitedesk2-ignition.json /mnt/ignition/config.ign
# Option B: Download with curl (if network works in installer)
curl -o /mnt/ignition/config.ign http://10.10.1.201:8080/elitedesk2-ignition.json

umount /mnt
```

> **Ignition config is at:** `copilot_projects/elitedesk2-ignition.json`
> Copy it to USB before starting, or serve it over HTTP.

Click **Reboot**.

---

## Phase 3 — First Boot

1. EliteDesk reboots, GRUB loads
2. **LUKS prompt** appears: type `inferno123`, press Enter
3. Fedora IoT boots, Ignition runs (applies `core` user, SSH key, NOPASSWD sudo, disables firewalld)
4. System gets IP via DHCP on 192.168.1.x

### Find the IP address
- Check your router's DHCP table for `inferno-fiot-elitedesk`
- Or: read from the console login screen (shows IP after login)
- Or: `arp -a | grep inferno` from another machine on 192.168.1.x

---

## Phase 4 — SSH Access (Copilot takes over from here)

Once you have the IP, tell Copilot:

```bash
ssh -i ~/.ssh/inferno_proxmox core@192.168.1.XXX
```

Expected: login as `core`, `sudo whoami` returns `root` with no password prompt.

From this point Copilot runs Phases 2–14 of `FEDORA_IOT_BUILD.md` remotely.

---

## Phase 5 — Inferno Stack Deployment (remote)

Copilot will:

1. **Detect NIC name** and compute `DEVICE_ID`:
   ```bash
   ip link show | grep -E '^[0-9]+: e'
   NIC=eno1  # or enp0s31f6 — whatever shows up
   DEVICE_ID=$(cat /sys/class/net/$NIC/address | tr -d ':')0000
   ```

2. **Install packages** (FEDORA_IOT_BUILD.md Phase 2):
   ```bash
   sudo rpm-ostree install \
     alsa-lib alsa-lib-devel alsa-utils alsa-plugins-speex speexdsp git avahi nss-mdns
   sudo reboot
   ```
   > After reboot: type LUKS passphrase `inferno123` at prompt again.
   > Unlike the VM guide, **no keyfile re-embed is needed** — Anaconda's LUKS setup persists.

3. **Phases 3–14** (build Rust toolchain, inferno ALSA plugin, statime, librespot, configure ALSA, services)
   - Refer to `FEDORA_IOT_BUILD.md` for full commands
   - Substitute `ens18` with actual NIC name throughout
   - Use computed `DEVICE_ID` in statime config and asoundrc

4. **Configure device name** — set `NAME "EliteDesk-Fedora"` in `~/.asoundrc` and librespot `--name`

---

## Phase 6 — Validate

```bash
# Services running?
systemctl --user status librespot inferno-bridge statime

# Check Spotify Connect
# Open Spotify on phone/PC → Devices → should see "EliteDesk-Fedora"

# Check Dante Controller
# Open Dante Controller on Windows → should see "EliteDesk-Fedora" as a transmitter
```

---

## Key Differences from VM (FEDORA_IOT_BUILD.md)

| Topic | VM Guide | Physical EliteDesk |
|-------|----------|--------------------|
| Phase 1 | Proxmox provisioner + offline LUKS | Anaconda installer with LUKS |
| Ignition | Placed on boot partition via loop device offline | Placed from installer shell before reboot |
| LUKS keyfile | Must embed in initramfs after each rpm-ostree (gotcha #9) | **Not needed** — Anaconda LUKS persists |
| Serial console | `socat` via Proxmox for LUKS passphrase | Type on physical keyboard |
| NIC name | `ens18` | Detect with `ip link show` (likely `eno1`) |
| DEVICE_ID | `bc2411937d0a0000` | Recalculate from actual MAC |
| LUKS passphrase entry | Via serial socket from PRX-01 | Physical keyboard each cold boot |

---

## Credentials

| Item | Value |
|------|-------|
| SSH user | `core` |
| SSH password | `inferno123` |
| SSH key | `~/.ssh/inferno_proxmox` |
| LUKS passphrase | `inferno123` |
| Ignition password hash | `$6$CY8v2Jdtar6PicRu$QU0bM1...` (see `elitedesk2-ignition.json`) |

---

## Gotchas (Physical Hardware Specific)

| # | Issue | Fix |
|---|-------|-----|
| 1 | EliteDesk BIOS may have Secure Boot enabled | Disable Secure Boot in BIOS (F10 → Security → Secure Boot) before booting USB |
| 2 | NIC name differs from VM (`ens18`) | Always use `ip link show` to detect; set NIC variable before any copy-paste from VM guide |
| 3 | LUKS prompt on every cold boot | Must be at keyboard; type `inferno123`. For automation: configure TPM2 auto-unlock with `systemd-cryptenroll` |
| 4 | Ignition only runs once | If you miss placing config.ign, must reinstall or manually recreate user/sudoers |
| 5 | Anaconda LUKS = cleaner than VM | No keyfile cpio embedding, no gotcha #9, no `socat` needed |
