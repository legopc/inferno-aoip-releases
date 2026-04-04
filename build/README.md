# Build & Deploy — Inferno AoIP Appliance

This document covers building the self-contained installer ISO and deploying it
to VMs or physical hardware. No HTTP server is needed during install.

---

## Requirements

- A Linux host with **podman** installed (Fedora IoT VM, or any Linux with `sudo apt install podman`)
- **~20 GB free disk space** for the build (image + ISO output)
- Internet access (to pull base image and download inferno release binaries)

### Build host options (in preference order)

| Host | Notes |
|------|-------|
| VM 111 (Fedora IoT 43) | Has podman natively. Best option. |
| PRX-01 (Proxmox/Debian) | `apt install podman`. Create a 20GB LV for output (root FS is tight). |
| legopc (Ubuntu 24.04) | Needs `sudo apt install podman`. |

---

## Step 1 — Prepare config.toml

Edit `build/config.toml`:

```bash
cd inferno-aoip-releases/build
# Set your SSH public key
sed -i 's|REPLACE_WITH_SSH_PUBLIC_KEY|ssh-ed25519 AAAA...|' config.toml
# Set a password hash for emergency console access
HASH=$(openssl passwd -6 YourPassword)
sed -i "s|REPLACE_WITH_OPENSSL_PASSWD_HASH|${HASH}|" config.toml
```

> **Security note**: `config.toml` contains credentials — do NOT commit it to git.
> It is listed in `.gitignore`. Back it up separately.

---

## Step 2 — Build the container image

From the repo root:

```bash
# Build the Inferno appliance container
# This downloads the Fedora bootc base + installs packages + downloads inferno binaries
podman build \
  --build-arg SSH_AUTHORIZED_KEY="$(cat ~/.ssh/id_ed25519.pub)" \
  -t inferno-appliance:v1 \
  .
```

Expected build time: 5-15 minutes (mostly package download + binary download).

> **Alternative**: Omit `--build-arg SSH_AUTHORIZED_KEY` and rely entirely on `config.toml`
> for key injection (cleaner, key not in image layers).

---

## Step 3 — Convert to installer ISO

```bash
mkdir -p output

podman run --rm --privileged \
  -v ./output:/output \
  -v /var/lib/containers/storage:/var/lib/containers/storage \
  ghcr.io/osbuild/bootc-image-builder:latest \
  --type anaconda-iso \
  --config /output/../build/config.toml \
  --rootfs xfs \
  inferno-appliance:v1
```

Output: `output/bootiso/install.iso` (~2-4 GB)

> **On PRX-01** (tight root FS): create a temp LV first:
> ```bash
> lvcreate -L 25G -n inferno-build HVP-PRX-01-VMDISK01
> mkfs.ext4 /dev/HVP-PRX-01-VMDISK01/inferno-build
> mount /dev/HVP-PRX-01-VMDISK01/inferno-build /mnt/inferno-build
> cd /mnt/inferno-build
> # Run podman build and bootc-image-builder here
> # When done: cd / && umount /mnt/inferno-build && lvremove /dev/HVP-PRX-01-VMDISK01/inferno-build
> ```

---

## Step 4 — Deploy

### Proxmox VM

```bash
# Upload ISO to Proxmox
scp -i ~/.ssh/inferno_proxmox output/bootiso/install.iso \
    root@10.10.1.201:/var/lib/vz/template/iso/inferno-appliance-v1.iso

# Create VM — IMPORTANT: use --vga std (NOT --vga serial0)
# Anaconda requires a VGA device to render its TUI. With serial0-only VGA,
# Anaconda produces no output and appears stuck (near-zero disk write activity).
qm create 111 \
  --name inferno-appliance-test \
  --memory 4096 --cores 4 \
  --bios ovmf --machine q35 \
  --efidisk0 HVP-PRX-01-VMDISK01:1,efitype=4m,pre-enrolled-keys=0 \
  --scsi0 HVP-PRX-01-VMDISK01:20,format=raw \
  --ide2 local:iso/inferno-appliance-v1.iso,media=cdrom \
  --net0 virtio,bridge=vmbr0,tag=10 \
  --boot order=ide2 \
  --serial0 socket --vga std
qm start 111

# After install completes (VM stops), switch to disk boot:
qm set 111 --boot order=scsi0 --ide2 none,media=cdrom
qm start 111
```

### Physical hardware (EliteDesk 800G2)

```bash
# Write to USB stick (replace /dev/sdX with your USB device!)
sudo dd if=output/bootiso/install.iso of=/dev/sdX bs=4M status=progress conv=fsync
# Boot target from USB → installer runs → reboot → done
```

---

## How it works (first boot)

1. Anaconda installer from ISO deploys the full Inferno appliance image to disk
2. On first boot, `inferno-configure.service` runs (one-shot, gated on `/etc/inferno.conf` absent):
   - Detects NIC and MAC address
   - Derives `DEVICE_ID` = `MAC0000` (e.g. `BC2411_73CF6B_0000`)
   - Sets hostname to `inferno-<mac-suffix>` (e.g. `inferno-73cf6b`)
   - Substitutes `%%PLACEHOLDER%%` values in config templates
   - Writes `/etc/statime-inferno.toml`, `/etc/alsa/conf.d/99-inferno.conf`
   - Sets up core user `~/bin`, `~/.asoundrc`, user systemd units
   - Enables linger + activates user services
   - Writes `/etc/inferno.conf` (sentinel — configure won't run again)
3. All Inferno services start automatically on next reboot (or immediately after first-boot config)

To **reconfigure** (e.g. after NIC change):
```bash
sudo rm /etc/inferno.conf && sudo reboot
```

---

## Updating the appliance

With bootc, updates work like container image updates:

```bash
# On the node:
sudo bootc switch ghcr.io/legopc/inferno-appliance:latest
sudo reboot
```

Or rebuild the container, push to a registry, and pull on nodes.

---

## What changed from the old approach

| Old (ignition + deploy.sh) | New (bootc Containerfile) |
|----------------------------|---------------------------|
| Provisioner ISO → coreos-installer → ignition on p2 | Anaconda ISO → direct image install |
| rpm-ostree installs packages on first boot (reboot needed) | Packages pre-installed in image |
| Binary download at first boot | Binaries pre-installed in image |
| Emergency mode from coreos-installer issues | No coreos-installer — not applicable |
| `inferno-deploy.sh` ~290 lines | `inferno-configure.sh` ~100 lines (config only) |

---

## Troubleshooting

### SELinux: statime/librespot fail with `Permission denied` (status=203/EXEC)

**Symptom**: `statime-inferno.service` loops with `Failed at step EXEC spawning ...: Permission denied`
and `status=203/EXEC` in `systemctl status`.

**Cause**: Binaries placed in `/var/lib/` get SELinux context `var_lib_t`. Systemd cannot exec files
with this context — it needs `bin_t`. Files in `/var/lib` are NOT in the immutable ostree layer and
get labeled by the default file context policy at runtime.

**Fix (already applied in v4+)**: Binaries are now installed to `/usr/local/bin/` (part of the
immutable ostree layer, `bin_t` context). ALSA plugin goes to `/usr/lib64/alsa-lib/` (`lib_t`).

**Lesson**: Never place executables in `/var/lib/`, `/var/home/`, or other runtime-writable paths
in a bootc image. Use `/usr/local/bin/` for executables, `/usr/local/lib/` for data files.

### User services dead after first boot (port 8080 not responding, inferno-bridge/librespot inactive)

**Symptom**: After first boot, user services (`inferno-web`, `inferno-bridge`, `librespot`) are
enabled but `inactive (dead)`. Port 8080 returns connection refused.

**Cause**: `inferno-configure.sh` enables user services during the first boot, but systemd user
lingering takes effect on the *next* boot. The services are enabled but never started on the same
boot they were registered.

**Fix (already applied in v4+)**: `inferno-configure.sh` now calls `systemctl reboot` at the end.
The appliance auto-reboots after first-boot configuration — no manual intervention needed. On the
second boot, all user services start automatically via lingering.

**Lesson**: When enabling systemd user services from a root script, always trigger a reboot after
`loginctl enable-linger` — user services will not start until the next boot.

### Verifying install is progressing (don't just poll status)

When waiting for Anaconda to finish, confirm it is actually writing to disk — don't rely solely
on `qm status`. A VM can appear "running" while stuck at a boot prompt or display issue.

```bash
# Watch disk write activity on the target LV — should show active I/O during install
ssh -i ~/.ssh/inferno_proxmox root@10.10.1.201 \
  "iostat -dx /dev/HVP-PRX-01-VMDISK01/vm-111-disk-1 5 3"

# Or watch the block device stats directly
ssh -i ~/.ssh/inferno_proxmox root@10.10.1.201 \
  "watch -n5 'cat /sys/block/dm-*/stat' 2>/dev/null | head -5"
```

If disk writes are zero for several minutes, the VM is stuck (display issue, boot failure, etc.).
Recreate with `--vga std` if Anaconda shows no serial output — Anaconda needs a VGA device.

### Configure service failed
```bash
journalctl -u inferno-configure
```

### Reconfigure node
```bash
sudo rm /etc/inferno.conf && sudo reboot
```

### Check Inferno services
```bash
# System services
systemctl status statime-inferno cockpit.socket avahi-daemon sshd

# User services (run as core user)
sudo -u core XDG_RUNTIME_DIR=/run/user/$(id -u core) systemctl --user status \
  inferno-bridge librespot librespot-watchdog inferno-keepalive inferno-web
```

### Cockpit web UI
Open `https://NODE-IP:9090` in a browser (accept the self-signed cert).
Manage services, view logs, edit `/etc/inferno.conf` from the Files tab.
