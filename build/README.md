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
  --local \
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

# In Proxmox web UI:
#   Create new VM → attach ISO → boot → installer runs automatically
#   After install completes, detach ISO → boot → first-boot config runs
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
