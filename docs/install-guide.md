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
# Create VM (recommended settings — use exact command, not the short form above)
qm create 111 --name inferno-node-01 --machine q35 --bios ovmf \
  --cpu host --cores 2 --sockets 1 --memory 8192 \
  --net0 virtio,bridge=vmbr0,tag=10 \
  --scsihw virtio-scsi-pci --serial0 socket --vga serial0 --tablet 0 --ostype l26
qm set 111 --efidisk0 YOUR_STORAGE:4,efitype=4m,pre-enrolled-keys=0
qm set 111 --scsi0 YOUR_STORAGE:32,cache=none
qm set 111 --ide2 local:iso/Fedora-IoT-provisioner-43-inferno.iso,media=cdrom
qm set 111 --boot order="scsi0;ide2"

# ⚠ ALWAYS read the MAC back immediately — it is auto-assigned and changes on every
# destroy/create. You need it to find the node's DHCP IP after boot.
qm config 111 | grep net0
# Record the MAC shown (e.g. BC:24:11:D1:3D:57) for later ARP lookup:
#   ip neigh | grep -i "d1:3d:57"

# Start VM
qm start 111
```

The boot order `scsi0;ide2` works because:
- UEFI tries `scsi0` first → fresh disk, no EFI bootloader → falls through
- UEFI boots from `ide2` (CDROM/ISO) automatically
- After install, disk has EFI bootloader → subsequent boots use `scsi0`, ignoring CDROM

The installer will automatically:
1. Run coreos-installer (writes image to disk, embeds ignition from ISO)
2. Reboot from disk — **no skip_reboot, no manual intervention needed**
3. Ignition configures system (users, SSH, masked services, firstboot unit)
4. inferno-firstboot.service deploys Inferno via rpm-ostree → auto-reboot
5. inferno-postdeploy.service fixes SELinux + enables statime
6. Node is operational (~25 min total)


### Method B: Physical Hardware

**Required tools:**
- USB stick (≥ 2 GB) burned with the Fedora IoT provisioner ISO
- A monitor and keyboard connected to the target machine (no serial console assumed)
- A second machine on the same network to serve the ignition config over HTTP

#### Step 1 — Burn the provisioner ISO to USB

On legopc (or any Linux machine):
```bash
# Find your USB device (check dmesg or lsblk after inserting)
lsblk
# Then burn (replace /dev/sdX with your USB device):
sudo dd if=Fedora-IoT-provisioner-43-inferno.iso of=/dev/sdX bs=4M status=progress oflag=sync
```

#### Step 2 — Prepare the ignition config

On legopc:
```bash
cd ~/copilot_projects/Inferno_Appliance/inferno-aoip-releases
cp ignition/inferno-template.ign /tmp/NODE_NAME.ign

# Fill in the password hash (replace INFERNO_CORE_PASSWORD_HASH placeholder)
HASH=$(openssl passwd -6 inferno123)
sed -i "s|INFERNO_CORE_PASSWORD_HASH|${HASH}|" /tmp/NODE_NAME.ign

# Validate
python3 -m json.tool /tmp/NODE_NAME.ign > /dev/null && echo "JSON OK"
```

Edit `/tmp/NODE_NAME.ign` to set `INFERNO_MODE`, `INFERNO_NAME`, and `INFERNO_NIC`
in the `/etc/inferno.conf` file section. For a new node, leave `INFERNO_NIC=auto`
unless you know the NIC name.

Also add your SSH public key to `sshAuthorizedKeys` if not already in the template.

#### Step 3 — Serve the ignition config over HTTP

On legopc (or any machine reachable from the target):
```bash
cd /tmp
python3 -m http.server 8080 &
# Note your IP on the same network as the target:
ip addr show   # find 10.10.1.x or similar
```

Keep this running throughout the install.

#### Step 4 — Boot from USB and edit GRUB

1. Plug in USB, power on target machine, boot from USB (F12/DEL/F2 for boot menu)
2. At the GRUB menu, **press `e`** to edit the boot entry
3. Find the line starting with `linux /images/pxeboot/vmlinuz ...`
4. At the **end of that line**, add:
   ```
   coreos.inst.ignition_url=http://LEGOPC_IP:8080/NODE_NAME.ign coreos.inst.skip_reboot console=tty0
   ```
5. Also verify or change `coreos.inst.install_dev=`:
   - For NVMe: `/dev/nvme0n1`
   - For SATA/SAS: `/dev/sda`
   - **Check which disk to install to** — the provisioner ISO may default to `/dev/vda` (for KVM)
     which will fail on physical hardware. Change it to the correct device.
6. Press **Ctrl+X** or **F10** to boot with the edited parameters

#### Step 5 — Wait for install to complete

The installer will:
1. Write Fedora IoT image to the target disk (~5-15 min depending on disk speed)
2. Download and embed your ignition config
3. **Power off** (due to `coreos.inst.skip_reboot`)

Watch the screen for progress. If you see `Install complete` and the machine powers off, proceed.

If the machine reboots instead of powering off (skip_reboot may not work on all hardware),
immediately remove the USB stick so it boots from the internal disk.

#### Step 6 — First boot

Remove the USB stick and power the machine on. The machine will:
1. Apply Ignition (~30s) — creates `core` user, writes `/etc/inferno.conf`, installs firstboot service
2. Run `inferno-firstboot.service` — downloads tarball, Phase 1 (package install), reboots
3. Phase 2 — deploys Inferno binaries, starts all services, reboots
4. Machine is operational after the second reboot

**Total time: ~20-45 minutes** depending on internet speed and disk speed.

#### Step 7 — Find the IP and connect

After the machine boots, find its DHCP address:
```bash
# From any machine on the same network — scan for the new node
# If you know the MAC address (from the machine's label or BIOS), check your router/DHCP server
# Or run a quick ARP scan:
for i in $(seq 1 254); do ping -c1 -W1 10.10.1.$i &>/dev/null; done
ip neigh | grep REACHABLE | sort
```

Then SSH:
```bash
ssh core@NODE_IP   # uses ~/.ssh/id_ed25519 automatically
```

#### Physical hardware notes

**NIC name:** The NIC name on physical hardware may differ from the VM (`ens18`). Common names:
- `enp1s0`, `enp2s0` — PCI Express NICs (most common on EliteDesk, T470S)
- `eno1` — onboard (embedded) NICs on servers
- `eth0` — older naming convention

If you set `INFERNO_NIC=auto` in `inferno.conf`, the deploy script will detect the first
active NIC automatically.

**Disk device names on physical hardware:**
- EliteDesk 800G2: likely `/dev/sda` (SATA SSD) or `/dev/nvme0n1` (NVMe)
- T470S: likely `/dev/nvme0n1` (NVMe SSD)

Check with `lsblk` from a live environment if unsure.

**No monitor after install:** Once the node is deployed and you know the IP, you no longer
need a monitor. All management is via SSH or Cockpit (`https://NODE_IP:9090`).

**UEFI vs BIOS:** The provisioner ISO requires UEFI boot. Ensure Secure Boot is disabled
in the BIOS (Fedora IoT does not support Secure Boot out of the box). UEFI mode is required
— CSM/Legacy mode will not work.

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

### ENOSPC during coreos-installer (Proxmox VMs)

**Symptom:** Install fails with `error decoding and writing image: No space left on device (os error 28)`.

**Cause:** The VM disk LV symlink in `/dev/VGname/` was missing or replaced by a rogue regular
file (this can happen after failed wipefs operations or if the LV was recreated without udev
re-running). When this happens, QEMU writes the VM disk to a tmpfs file rather than the LV,
and the tmpfs runs out of space.

**Fix — always destroy and recreate cleanly:**
```bash
# On Proxmox host:
qm stop 111 --skiplock
qm destroy 111 --destroy-unreferenced-disks 1 --purge 1

# Recreate fresh
qm create 111 --name inferno-node-01 --machine q35 --bios ovmf \
  --cpu host --cores 2 --sockets 1 --memory 4096 \
  --net0 virtio,bridge=vmbr0,tag=10 \
  --scsihw virtio-scsi-pci --serial0 socket --vga serial0 --tablet 0 --ostype l26
qm set 111 --efidisk0 YOUR_STORAGE:4,efitype=4m,pre-enrolled-keys=0
qm set 111 --scsi0 YOUR_STORAGE:32,cache=none
qm set 111 --ide2 local:iso/Fedora-IoT-provisioner-43-inferno.iso,media=cdrom
qm set 111 --boot order="scsi0;ide2"
qm start 111

# Always capture the MAC immediately — it changes on every destroy/create:
qm config 111 | grep net0
# Record the MAC for ARP lookups: ip neigh | grep -i "XX:XX:XX"
```

**⚠ Never attempt to reuse or manually wipe a VM disk that has failed an install.**
Always `qm destroy` and recreate. The `qm create` process properly initialises the LV
and udev symlinks.

**⚠ Always read back the MAC after `qm create`** — Proxmox auto-assigns a random MAC
every time. You need it to find the node's IP after boot via `ip neigh | grep -i MAC`.
If you skip this step you'll waste time scanning the subnet later.

---

### Ignition "running for the second time" warning

**Cause:** The provisioner ISO embeds an ignition config that runs during `coreos-installer`.
When you also place a config on p2 (the boot partition), ignition runs again on first boot.

**This warning is harmless.** The second run applies your updated config (with correct SSH keys,
etc.) on top of the first. Files with `overwrite: true` are updated; the `core` user's
`sshAuthorizedKeys` are merged.

To avoid the double-run in future, embed your final ignition config into the provisioner ISO
before install (see Method A above).

---

### Known issue: coreos-installer does NOT embed ignition when using `file://` URL

**Symptom:** After install completes, p2 (the /boot partition) has no `/ignition/` directory.
On first boot, ignition runs with no config → no SSH keys, no user password, no firstboot service.

**Cause:** When `coreos.inst.ignition_url=file:///run/media/iso/ignition/config.ign` is used
in the Fedora IoT 43 provisioner, coreos-installer uses the config internally during install
but does **not** write it to `p2/ignition/config.ign` on the installed disk. This appears to
be a Fedora IoT 43 provisioner quirk (possibly a bug).

**Workaround (Proxmox VMs):** After install completes and VM is in emergency mode or has
rebooted, stop the VM and manually place ignition on p2:

```bash
# On PRX-01, with VM stopped:
qm stop 111
lvchange -ay HVP-PRX-01-VMDISK01/vm-111-disk-1
udevadm settle

DEV="/dev/mapper/HVP--PRX--01--VMDISK01-vm--111--disk--1"
LOOP=$(losetup -f --show -o $((1028096 * 512)) $DEV)
mkdir -p /mnt/p2 && mount $LOOP /mnt/p2
mkdir -p /mnt/p2/ignition
cp /tmp/vm111.ign /mnt/p2/ignition/config.ign
umount /mnt/p2 && losetup -d $LOOP

qm set 111 --boot order="scsi0"
qm start 111
```

**For physical hardware:** Serve the ignition config over HTTP from a machine on the same
network, and change the grub.cfg entry to use `coreos.inst.ignition_url=http://HOST/node.ign`
instead of `file://`. This way coreos-installer fetches over the network and does write it
to the installed disk correctly.

---

### Mounting p2 (boot partition) on Proxmox LVM storage

If you need to place/update the ignition config on p2 after install but before first boot:

```bash
# On PRX-01, with VM stopped:
# 1. Activate the LV (it goes inactive when VM stops)
lvchange -ay YOUR_VG/vm-111-disk-1
udevadm settle

# 2. Mount p2 via losetup offset (sector 1028096 × 512 = 526385152 bytes)
LOOP=$(losetup -f --show -o 526385152 /dev/mapper/YOUR--VG-vm--111--disk--1)
mkdir -p /mnt/p2 && mount $LOOP /mnt/p2

# 3. Place ignition
mkdir -p /mnt/p2/ignition
cp your-node.ign /mnt/p2/ignition/config.ign

# 4. Unmount
umount /mnt/p2 && losetup -d $LOOP
```

**Note:** Use `losetup -f --show -o OFFSET` (not `mount -o offset=` directly). Direct offset
mount of XFS/ext4 on a block device may fail; losetup works reliably. `kpartx` is not
installed on Proxmox by default.

---

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
