# Inferno AoIP — Complete Installation Guide

This document covers the end-to-end installation of an Inferno AoIP node on Fedora IoT 43,
from bare hardware (or VM) to a fully operational Dante / AES67 streaming node.

---

## Overview

The install consists of three phases:

```
Phase 0: Prepare ignition config (once per node type)
Phase 1: Fedora IoT OS install (coreos-installer via provisioner ISO)
Phase 2: Ignition + inferno-firstboot (automated on first boot)
Phase 3: Inferno deploy.sh (automated on second boot, or triggered manually)
```

Total time from boot to operational: ~25 min on decent hardware, ~45 min on slower VMs.

---

## Prerequisites

### Hardware requirements
- x86_64 machine with UEFI firmware
- ≥ 16 GB disk (32 GB recommended)
- ≥ 2 GB RAM (4 GB recommended)
- Network connection (DHCP + internet access for GitHub releases download)
- USB port or virtual CD-ROM for installer ISO

### Tools needed (on your workstation)
- SSH access to target host (or serial console / KVM)
- For VMs: Proxmox or similar hypervisor with serial console support

---

## Phase 0 — Prepare Ignition Config

Ignition configures the OS on first boot: user accounts, SSH, sudo, seed config,
and the firstboot service that kicks off the Inferno install.

### 0.1 Generate a password hash

```bash
openssl passwd -6 YOUR_PASSWORD
```

### 0.2 Customise the template

Copy `ignition/inferno-template.ign` and fill in:

| Field | Location in JSON | Example |
|-------|-----------------|---------|
| Password hash | `passwd.users[0].passwordHash` | output of `openssl passwd -6` |
| SSH public key | `passwd.users[0].sshAuthorizedKeys` | your `~/.ssh/id_rsa.pub` or `id_ed25519.pub` |
| `INFERNO_MODE` | `/etc/inferno.conf` inline content | `spotify`, `aux`, or `bluetooth` |
| `INFERNO_NAME` | `/etc/inferno.conf` inline content | `Dante-Node-01` |
| `INFERNO_NIC` | `/etc/inferno.conf` inline content | `enp1s0` or `auto` |
| `INFERNO_AUDIO_CARD` | `/etc/inferno.conf` inline content | `0` (first sound card) |

**⚠ Ignition version:** Use `3.4.0` (the template ships with this). Version 3.3.0 does
not support `data:` URI sources or `overwrite: true`, which are required for reliable
file placement.

**⚠ Groups:** Do NOT add `audio` to the groups list in the ignition config.
The `audio` group does not exist in the initramfs environment where Ignition runs on
Fedora IoT 43. Only `wheel` is safe. The deploy script adds the user to `audio`
as part of Phase 2.

Example `/etc/inferno.conf` section in the ignition JSON:
```json
{
  "path": "/etc/inferno.conf",
  "contents": {
    "inline": "# Inferno AoIP node configuration\nINFERNO_MODE=spotify\nINFERNO_NAME=MyNode-01\nINFERNO_NIC=auto\nINFERNO_AUDIO_CARD=0\n"
  },
  "mode": 420
}
```

### 0.3 Validate the ignition file

```bash
# Validate JSON structure
python3 -m json.tool your-node.ign > /dev/null && echo "JSON OK"
```

---

## Phase 1 — Install Fedora IoT

### Method A: Custom ISO (Recommended for VMs/Proxmox)

A custom ISO with the ignition URL baked into the GRUB config automates everything.
The installer downloads your ignition config and embeds it into the installed image
before the first reboot.

#### Build the custom ISO

On the machine hosting the ISO files:

```bash
# 1. Set variables
STOCK_ISO=/var/lib/vz/template/iso/Fedora-IoT-provisioner-43.iso
CUSTOM_ISO=/var/lib/vz/template/iso/Fedora-IoT-provisioner-43-ignition.iso
IGN_URL="http://YOUR_SERVER_IP:8080/config.ign"

# 2. Serve the ignition file
cp your-node.ign /tmp/config.ign
cd /tmp && python3 -m http.server 8080 &

# 3. Extract stock ISO
mkdir -p /tmp/iso-repack/iso
mount -o loop,ro "$STOCK_ISO" /mnt
cp -a /mnt/. /tmp/iso-repack/iso/
umount /mnt
chmod -R u+w /tmp/iso-repack/iso

# 4. Check if ISO targets /dev/vda (KVM virtio) or /dev/sda (virtio-scsi)
#    For Proxmox with virtio-scsi-pci controller: use /dev/sda
#    For Proxmox with virtio controller: use /dev/vda
grep "coreos.inst.install_dev" /tmp/iso-repack/iso/EFI/BOOT/grub.cfg | head -3
```

The stock Fedora 43 IoT ISO contains two sets of entries in grub.cfg:
- Default entries: target `/dev/vda1` (no ignition URL, no skip_reboot)
- Custom/hardware entries (if you add them): target `/dev/sda` with ignition URL

```bash
# 5. Add ignition URL to the correct target entries
#    IMPORTANT: The entry must use the correct install_dev for your hardware
#    For Proxmox virtio-scsi: /dev/sda
#    For Proxmox virtio block: /dev/vda

# Add new entry to grub.cfg (before the closing brace of the first menuentry)
cat >> /tmp/iso-repack/iso/EFI/BOOT/grub.cfg << GRUBEOF

menuentry 'Install Fedora IoT 43 with Ignition' --class fedora {
  linux /images/pxeboot/vmlinuz rd.neednet=1 \\
    coreos.inst.crypt_root=1 \\
    coreos.inst.isoroot=Fedora-43-IoT-x86_64 \\
    coreos.inst.install_dev=/dev/sda \\
    coreos.inst.image_file=/run/media/iso/image.raw.xz \\
    coreos.inst.insecure \\
    coreos.inst.skip_reboot \\
    coreos.inst.ignition_url=${IGN_URL} \\
    console=ttyS0,115200n8
  initrd /images/pxeboot/initrd.img
}
GRUBEOF

# OR: patch existing entries (if stock ISO already has sda entries)
sed -i "s|coreos.inst.skip_reboot|coreos.inst.skip_reboot coreos.inst.ignition_url=${IGN_URL}|g" \
    /tmp/iso-repack/iso/EFI/BOOT/grub.cfg

# 6. Repack ISO (requires xorriso)
xorriso -as mkisofs \
  -o "$CUSTOM_ISO" \
  -V "Fedora-43-IoT-x86_64" \
  --mbr-force-bootable -partition_offset 0 -iso_mbr_part_type 0x00 \
  --boot-catalog-hide \
  -eltorito-alt-boot -e images/efiboot.img -no-emul-boot \
  -isohybrid-gpt-basdat \
  /tmp/iso-repack/iso
```

#### Deploy in Proxmox

```bash
# Create VM
qm create 111 --name inferno-node-01 \
  --cores 2 --memory 4096 \
  --net0 virtio,bridge=vmbr0,tag=10 \
  --scsihw virtio-scsi-pci \
  --scsi0 YOUR_STORAGE:vm-111-disk-1,cache=writeback,size=32G \
  --ide2 local:iso/Fedora-IoT-provisioner-43-ignition.iso,media=cdrom \
  --boot order="ide2;scsi0" \
  --bios ovmf \
  --efidisk0 YOUR_STORAGE:vm-111-efi,size=4M \
  --serial0 socket \
  --vga serial0

# Start and monitor via serial
qm start 111
socat - UNIX-CONNECT:/var/run/qemu-server/111.serial0
```

The installer will:
1. Boot from ISO
2. Download ignition config from URL
3. Extract and write Fedora IoT image to `/dev/sda`
4. Embed ignition config into the EFI boot partition
5. Power off (due to `coreos.inst.skip_reboot`)

**After poweroff: remove ISO from boot order and start VM:**
```bash
qm set 111 --boot order="scsi0"
qm start 111
```

### Method B: Physical Hardware

**Required tools:** USB stick with Fedora IoT provisioner ISO burned to it.

```bash
# Burn ISO to USB
sudo dd if=Fedora-IoT-provisioner-43.iso of=/dev/sdX bs=4M status=progress
```

Boot from USB. The Fedora IoT provisioner ISO runs `coreos-installer` automatically.
It installs to the first non-USB disk it finds.

**Embedding ignition config on physical hardware:**

Option 1 — Network ignition (requires DHCP + reachable HTTP server during install):
- Boot with `coreos.inst.ignition_url=http://YOUR_IP:8080/config.ign` added to kernel args
- Press `e` at the GRUB menu to edit the boot entry and append this parameter

Option 2 — Manual placement (after install, before first reboot):
```bash
# After coreos-installer finishes (but before first boot):
# The installed disk's EFI partition (p2) is mounted at /mnt/boot during install
# OR mount it manually:
mount /dev/sda2 /mnt
mkdir -p /mnt/ignition
cp your-node.ign /mnt/ignition/config.ign
umount /mnt
```

**⚠ CRITICAL:** Ignition only runs once on first boot. If it runs with no config,
it marks itself complete and will NOT run again. The node will have locked accounts
(no login possible). You must either reflash or provide the ignition config before
the first boot.

---

## Phase 2 — First Boot (Ignition + firstboot)

After the OS installs and the VM/machine boots from disk for the first time:

1. **Ignition runs** (~30s): Creates `core` user, sets password, enables sudo, writes
   `/etc/inferno.conf`, installs `inferno-firstboot.service`

2. **inferno-firstboot.service runs** (~2-5 min):
   - Downloads `inferno-aoip.tar.gz` from GitHub Releases (requires internet)
   - Verifies SHA256 checksum
   - Runs `inferno-deploy.sh`

3. **inferno-deploy.sh Phase 1** (~5 min):
   - Installs RPM packages via `rpm-ostree`: `cockpit`, `alsa-utils`, `avahi-tools`
   - Writes sentinel `/var/lib/inferno/.packages-installed`
   - Reboots (triggers Phase 2)

### Monitoring first boot (serial console)

```bash
# On Proxmox host:
socat - UNIX-CONNECT:/var/run/qemu-server/111.serial0

# Look for these key events:
# "Starting Inferno First Boot..." — firstboot service running
# "Downloading inferno-aoip.tar.gz" — tarball fetch
# "Phase 1: Installing packages" — rpm-ostree install
# System reboots automatically
```

### Monitoring via SSH

The node gets a DHCP address. **Important: The IP may change between reboots** (e.g. after
the Phase 1 rpm-ostree reboot). Always discover the IP fresh after each reboot.

```bash
# On Proxmox host — check which IP the VM got (replace MAC with your VM's MAC):
grep -i "BC:24:11" /var/lib/misc/dnsmasq.leases 2>/dev/null
# Or via ARP:
arp -n | grep -i "BC:24:11"
# Or check serial console after boot — look for "Started Network Manager" then:
#   ip addr show   (via socat session)
```

Once you have the IP, SSH with the credentials from your ignition config:
```bash
ssh core@NODE_IP
# Password: whatever you set in the ignition config (default: inferno123)
# SSH public key auth works if sshAuthorizedKeys are set in the ignition template
```

**⚠ If SSH publickey auth fails silently:** Verify you are connecting to the correct IP.
The most common cause is connecting to a stale/old IP that belongs to a different device.

---

## Phase 3 — Second Boot (inferno-deploy.sh Phase 2)

After the Phase 1 reboot:

1. **inferno-deploy.sh Phase 2 runs** (~3 min):
   - Detects NIC, derives Dante DEVICE_ID from MAC address
   - Extracts and installs Inferno binaries to `/var/lib/inferno/bin/`
   - Installs ALSA plugin to `/usr/lib64/alsa-lib/`
   - Deploys ALSA config (`/etc/alsa/conf.d/99-inferno.conf`)
   - Deploys systemd units for mode-specific services (spotify/aux)
   - Generates PTP config (`/var/lib/inferno/inferno-ptpv1.toml`)
   - Enables and starts all services
   - Reboots

2. **After reboot:** Node is fully operational
   - Dante Controller sees the new device
   - Spotify: device appears in Spotify Connect
   - AUX: `alsaloop` is forwarding audio from AUX in

### Verify operation

```bash
ssh core@NODE_IP

# Check all services running
systemctl --user status librespot inferno-bridge inferno-keepalive
systemctl status statime-inferno

# Check ALSA devices
aplay -l

# Check network / Dante
avahi-browse -a | grep inferno

# Cockpit web UI
# https://NODE_IP:9090
```

---

## Troubleshooting

### Node has locked accounts (can't log in after first boot)

**Cause:** Ignition ran with no config — either the ignition URL was unreachable during install,
or the config was not placed before the first boot.

**Fix for VMs:** Wipe the disk and reinstall. Ensure the HTTP server serving the ignition
config is reachable from the installer environment.

**Fix for physical hardware:** Reinstall from USB, this time with the ignition config
correctly embedded. Alternatively, use a rescue environment to mount the disk and
reset the root password.

### inferno-firstboot.service fails — can't download tarball

**Cause:** No internet access from the node, or GitHub is unreachable.

**Check:**
```bash
journalctl -u inferno-firstboot -f
curl -v https://github.com/legopc/inferno-aoip-releases/releases/latest/download/inferno-aoip.tar.gz
```

**Fix:** Ensure the node can reach the internet. If the network requires a proxy,
set `https_proxy` in `/etc/inferno.conf` and restart the service.

For air-gapped environments, use `INFERNO_LOCAL_TARBALL=/path/to/inferno-aoip.tar.gz`
and manually trigger: `sudo bash /var/lib/inferno/bin/inferno-deploy.sh`

### VM LUKS passphrase prompt at boot

**Cause:** Fedora IoT uses LUKS disk encryption by default (`coreos.inst.crypt_root=1`).
After an `rpm-ostree` reboot, the initramfs is regenerated and may not have the keyfile.

**Workaround for VMs** (inject passphrase via serial):
```bash
# On Proxmox host — send passphrase to serial console:
echo "YOUR_PASSPHRASE" | socat - UNIX-CONNECT:/var/run/qemu-server/111.serial0
```

**Permanent fix** (append keyfile to initramfs — run inside VM):
```bash
INITRAMFS=$(ls /boot/ostree/fedora-*/initramfs-*.img | head -1)
mkdir -p /tmp/kf-cpio/etc/luks
echo -n "inferno123" > /tmp/kf-cpio/etc/luks/keyfile
(cd /tmp/kf-cpio && find . | cpio -o -H newc 2>/dev/null) | sudo tee -a "$INITRAMFS" > /dev/null
for conf in /boot/loader/entries/*.conf; do
  grep -q "luks.key" "$conf" || sudo sed -i 's|^options |options luks.key=/etc/luks/keyfile |' "$conf"
done
sudo systemctl reboot
```

Note: Physical hardware typically does not have this issue since the keyfile is
embedded during the initial install.

### Services not starting (wrong mode/name)

Edit `/etc/inferno.conf` and trigger redeploy:
```bash
sudo nano /etc/inferno.conf
sudo rm /var/lib/inferno/.deployed
sudo systemctl reboot
```

### SELinux denying inferno binary execution

**Symptom:** `statime-inferno.service` fails with SELinux AVC denial for `execute` on
files in `/var/lib/inferno/bin/`.

**Cause:** SELinux `var_lib_t` context does not allow execute.

**Fix:**
```bash
sudo chcon -t bin_t /var/lib/inferno/bin/*
sudo systemctl restart statime-inferno
```

This is applied automatically by `inferno-deploy.sh` since the VM 111 session.
If you are on an older tarball, apply manually.

### SSH public key auth failing after deploy script runs

**Symptom:** SSH connects but rejects the key without logging anything to journal.

**Cause 1:** Wrong IP — the DHCP lease changed between reboots (especially after
Phase 1 rpm-ostree reboot). Check the actual IP via DHCP/ARP/serial console.

**Cause 2:** `AuthorizedKeysCommand /usr/libexec/ssh-key-dir` in the Red Hat drop-in
config (`/etc/ssh/sshd_config.d/40-ssh-key-dir.conf`) returning an error. If the
authorized_keys.d directory referenced by ssh-key-dir doesn't exist, it may cause
auth to fail silently.

**Fix:**
```bash
# Verify the actual VM IP first:
ip addr show   # run from serial console if SSH is broken

# If IP is correct and key auth still fails, check and disable AuthorizedKeysCommand:
sudo bash -c "echo 'AuthorizedKeysCommand none' > /etc/ssh/sshd_config.d/40-ssh-key-dir.conf"
sudo bash -c "echo 'AuthorizedKeysCommandUser nobody' >> /etc/ssh/sshd_config.d/40-ssh-key-dir.conf"
sudo systemctl restart sshd
```

**Note:** Including SSH public keys directly in the ignition config (via `sshAuthorizedKeys`
in the `passwd.users` section) is the most reliable approach and avoids this issue entirely.

---

## Node Default Credentials

| Item | Value |
|------|-------|
| OS user | `core` |
| Default password | `inferno123` (set in ignition) |
| sudo | passwordless |
| Cockpit | `https://NODE_IP:9090` |
| Inferno Web UI | `http://NODE_IP:8080` |
| SSH | Password + public key both supported |

---

## Ignition Config Quick Reference

The ignition config that ships with this repo (`ignition/inferno-template.ign`) sets up:

| What | How |
|------|-----|
| `core` user with password + sudo | `passwd.users` section |
| `/etc/sudoers.d/core-nopasswd` | `storage.files` |
| `/etc/inferno.conf` seed | `storage.files` |
| `/usr/local/bin/inferno-firstboot.sh` | `storage.files` (bootstrap script) |
| `inferno-firstboot.service` | `systemd.units` (runs firstboot script) |
| `getty@tty1.service` enabled | `systemd.units` (keyboard/display login) |

The firstboot script downloads the tarball from GitHub and runs `inferno-deploy.sh`.
No binaries are embedded in the ignition config itself — it stays small and version-agnostic.

---

## Fedora IoT 43 ISO Download

```
https://dl.fedoraproject.org/pub/alt/iot/43/IoT/x86_64/iso/
```

Download the `Fedora-IoT-provisioner-43-*.x86_64.iso` (the "provisioner" variant that
uses `coreos-installer` — not the live desktop ISO).

---

## Architecture Reference

```
┌─────────────────────────────────────────────────────┐
│                  Fedora IoT 43 Node                  │
│                                                      │
│  ALSA stack (inferno ALSA plugin)                    │
│  ┌──────────┐    ┌────────────────┐                  │
│  │librespot │───▶│inferno_spotify │──┐               │
│  └──────────┘    └────────────────┘  │               │
│                                      ▼               │
│  ┌──────────┐    ┌────────────────┐ Dante TX ──────▶ │ Network (AES67/Dante)
│  │alsaloop  │───▶│inferno_aux_tx  │──┘               │
│  └──────────┘    └────────────────┘                  │
│       ▲                                              │
│  ┌──────────┐    ┌────────────────┐                  │
│  │alsaloop  │◀───│inferno_aux_rx  │◀── Dante RX      │
│  └──────────┘    └────────────────┘                  │
│       │                                              │
│  ┌──────────┐                                        │
│  │ALSA hw:0 │ (physical audio card)                  │
│  └──────────┘                                        │
│                                                      │
│  PTP (statime) ──────────────────────────────────▶  │ Network (PTP/IEEE1588)
└─────────────────────────────────────────────────────┘
```
