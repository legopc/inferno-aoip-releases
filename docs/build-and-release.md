# Inferno AoIP — Build and Release Process

> Full step-by-step guide for building a new Inferno AoIP release on PRX-01.
> Covers: container image → installer ISO → upgrade tarball → .iotupdate bundle → node deployment.

---

## Overview

A release consists of four artifacts, all produced by one script:

| Artifact | Purpose |
|----------|---------|
| **Container image** | The bootable OS image (`localhost/inferno-appliance:vN`) |
| **Installer ISO** | Bootable USB/CD for fresh installs (via Anaconda) |
| **Upgrade tarball** | Raw `podman save` export — used for streaming upgrades (node-to-node via SSH pipe) |
| **`.iotupdate` bundle** | Packaged upgrade for the Cockpit IoT Updater UI (includes `version.json` + SHA-256 integrity) |

The build runs on **PRX-01** (`root@10.10.1.201`) using a dedicated 25GB LV at `/mnt/inferno-build`.

---

## Build Infrastructure

### PRX-01 Build Environment

| Path | Purpose |
|------|---------|
| `/mnt/inferno-build/inferno-aoip-releases` | Git repo clone |
| `/mnt/inferno-build/storage` | Podman graphRoot (fuse-overlayfs, off root FS) |
| `/run/containers/storage` | Podman runRoot (tmpfs — recreate after reboot: `mkdir -p /run/containers/storage`) |
| `/mnt/inferno-build/config.toml` | bootc-image-builder config (no user customizations needed) |
| `/mnt/inferno-build/output-vN/` | ISO build output directory |
| `/mnt/inferno-build/inferno-appliance-vN.tar` | Upgrade tarball output |
| `/var/lib/vz/template/iso/` | Proxmox ISO storage (symlinks point into `/mnt/inferno-build/`) |

### Critical: Podman storage flags

Always use both flags together. The storage DB was initialized with `runroot=/run/containers/storage`:

```bash
podman --storage-driver overlay \
  --storage-opt overlay.mount_program=/usr/bin/fuse-overlayfs \
  --root /mnt/inferno-build/storage \
  --runroot /run/containers/storage
```

After a PRX-01 reboot, `/run/containers/storage` is wiped (tmpfs). Recreate it:
```bash
mkdir -p /run/containers/storage
```

### Critical: Use systemd-run for long builds

`nohup ... &` and `setsid ... &` both die when the SSH session closes on PRX-01.  
Always use `systemd-run` to create a proper transient service that survives disconnects:

```bash
systemd-run --unit=inferno-build-vN /path/to/script.sh
systemctl is-active inferno-build-vN    # check status
journalctl -u inferno-build-vN -f       # or tail the log file
```

### Disk space

PRX-01's root FS (`/`) fills up quickly. **All build work must stay on `/mnt/inferno-build`.**

If root fills up, builds are killed silently (no OOM in dmesg — process just disappears).

Common space consumers to clean:
```bash
# Old ISO build artifacts in /tmp
rm -rf /tmp/iso-repack* /tmp/iso-work /tmp/mod-check /tmp/initrd-*

# Old Proxmox ISOs (Fedora IoT, etc.)
ls -lh /var/lib/vz/template/iso/

# Apt cache and journals
apt-get clean
journalctl --vacuum-time=7d

# Dangling podman images (from failed builds)
podman --storage-driver overlay \
  --storage-opt overlay.mount_program=/usr/bin/fuse-overlayfs \
  --root /mnt/inferno-build/storage \
  --runroot /run/containers/storage \
  image prune
```

---

## Standard Build (Recommended)

### Step 1 — Pull latest code

```bash
ssh -i ~/.ssh/inferno_proxmox root@10.10.1.201
cd /mnt/inferno-build/inferno-aoip-releases && git pull
```

### Step 2 — Run the build script

```bash
VERSION=v11   # bump for each release
DESCRIPTION="Brief description of changes in this release"

mkdir -p /run/containers/storage

systemd-run --unit=inferno-build-${VERSION} \
  /mnt/inferno-build/inferno-aoip-releases/build/build-release.sh ${VERSION} "${DESCRIPTION}" \
  > /mnt/inferno-build/build-${VERSION}.log 2>&1
```

### Step 3 — Monitor progress

```bash
# Status
systemctl is-active inferno-build-${VERSION}

# Live log
tail -f /mnt/inferno-build/build-${VERSION}.log
```

The script logs `── [N/5] ...` section headers and appends `BUILD_EXIT:0` on success.  
If the build is killed, there will be no `BUILD_EXIT` line in the log.

### Step 4 — Verify outputs

```bash
# Container image
podman --storage-driver overlay \
  --storage-opt overlay.mount_program=/usr/bin/fuse-overlayfs \
  --root /mnt/inferno-build/storage \
  --runroot /run/containers/storage \
  images | grep inferno-appliance

# ISO (Proxmox symlink)
ls -lh /var/lib/vz/template/iso/inferno-appliance-${VERSION}.iso

# Upgrade tarball
ls -lh /mnt/inferno-build/inferno-appliance-${VERSION}.tar

# IoT Updater bundle
ls -lh /mnt/inferno-build/inferno-appliance-${VERSION}.iotupdate
```

---

## What `build-release.sh` Does

The script at `build/build-release.sh` runs five steps in sequence:

### [1/5] Git pull

Ensures the repo on PRX-01 is current before building.

### [2/5] Container image build

```bash
podman ... build -t inferno-appliance:vN -f Containerfile .
```

**Containerfile overview (33 steps):**

| Steps | Action |
|-------|--------|
| 1 | `FROM registry.fedoraproject.org/fedora-bootc:43` |
| 2 | `dnf install` cockpit, alsa-lib/utils, avahi, openssh, skopeo, curl |
| 3–4 | `mkdir` layout, download `inferno-aoip.tar.gz` from GitHub Releases (SHA256 verified) |
| 5–6 | Install `statime`, `librespot` → `/usr/local/bin/`, ALSA plugin → `/usr/lib64/alsa-lib/` |
| 7–13 | `COPY templates/` — ALSA, PTP, systemd templates (with `%%PLACEHOLDER%%` markers) |
| 14 | `COPY cockpit/` → `/usr/share/cockpit/inferno/` |
| 15–16 | `COPY` system service units |
| 17–23 | `COPY` user service unit templates |
| 24 | Pin `snd-aloop` to card index 5 (modprobe config) |
| 25–26 | `COPY` first-boot configure script + service unit |
| 27 | `systemctl enable` sshd, cockpit.socket, avahi-daemon, statime-inferno, inferno-configure |
| 28 | `systemctl mask` systemd-timesyncd, chronyd, ntpd |
| 29 | `useradd core` + audio group fix + sudoers + linger pre-create |
| 30–33 | `COPY` iot-updater cockpit page, server, apply script, service units; `systemctl enable` iot-updater |

**Expected time:** ~10 minutes (mostly network: base image pull + binary tarball download).

### [3/5] Installer ISO

Uses `ghcr.io/osbuild/bootc-image-builder` (BIB) to convert the container image into an Anaconda installer ISO:

```bash
podman ... run --rm --privileged \
  -v /mnt/inferno-build/storage:/var/lib/containers/storage \
  -v /mnt/inferno-build/output-vN:/output \
  -v /mnt/inferno-build/config.toml:/config.toml:ro \
  ghcr.io/osbuild/bootc-image-builder:latest \
  --type anaconda-iso \
  --rootfs xfs \
  --config /config.toml \
  --local localhost/inferno-appliance:vN
```

The `-v .../storage:/var/lib/containers/storage` bind-mount is critical: BIB runs in a container and must find `localhost/inferno-appliance:vN` at that path.  
`--rootfs xfs` is required — Fedora bootc does not declare a default root filesystem type.

Output: `/mnt/inferno-build/output-vN/bootiso/install.iso` (~2 GB)  
**Expected time:** ~15–20 minutes.

The script then symlinks the ISO into Proxmox ISO storage:
```bash
ln -sf /mnt/inferno-build/output-vN/bootiso/install.iso \
  /var/lib/vz/template/iso/inferno-appliance-vN.iso
```

### [4/5] Upgrade tarball

```bash
podman ... save localhost/inferno-appliance:vN \
  -o /mnt/inferno-build/inferno-appliance-vN.tar
```

Exports all image layers as a portable tar. Used for streaming upgrades over SSH.  
**Expected time:** ~3–5 minutes. Output: ~1.9 GB.

### [5/5] .iotupdate bundle

```bash
build/make-oci-bundle.sh \
  --archive /mnt/inferno-build/inferno-appliance-vN.tar \
  --version vN \
  --description "Change description" \
  --out /mnt/inferno-build/inferno-appliance-vN.iotupdate
```

Packages the raw tar with a `version.json` manifest and SHA-256 hash into a single `.iotupdate` bundle.  
This is the file you upload via the **Cockpit IoT Updater** UI to upgrade a node over the network.  
**Expected time:** ~1–2 minutes (just SHA-256 + tar wrap). Output: same size as upgrade tar.

---

## Manual Steps (if `build-release.sh` cannot be used)

### Build container image only

```bash
cd /mnt/inferno-build/inferno-aoip-releases
mkdir -p /run/containers/storage

podman --storage-driver overlay \
  --storage-opt overlay.mount_program=/usr/bin/fuse-overlayfs \
  --root /mnt/inferno-build/storage \
  --runroot /run/containers/storage \
  build -t inferno-appliance:vN -f Containerfile .
```

### Build ISO only (container image already exists)

```bash
mkdir -p /mnt/inferno-build/output-vN /run/containers/storage

podman --storage-driver overlay \
  --storage-opt overlay.mount_program=/usr/bin/fuse-overlayfs \
  --root /mnt/inferno-build/storage \
  --runroot /run/containers/storage \
  run --rm --privileged \
  -v /mnt/inferno-build/storage:/var/lib/containers/storage \
  -v /mnt/inferno-build/output-vN:/output \
  -v /mnt/inferno-build/config.toml:/config.toml:ro \
  ghcr.io/osbuild/bootc-image-builder:latest \
  --type anaconda-iso \
  --rootfs xfs \
  --config /config.toml \
  --local localhost/inferno-appliance:vN
```

### Export upgrade tarball only (container image already exists)

```bash
podman --storage-driver overlay \
  --storage-opt overlay.mount_program=/usr/bin/fuse-overlayfs \
  --root /mnt/inferno-build/storage \
  --runroot /run/containers/storage \
  save localhost/inferno-appliance:vN \
  -o /mnt/inferno-build/inferno-appliance-vN.tar
```

### Package .iotupdate bundle only (upgrade tarball already exists)

```bash
/mnt/inferno-build/inferno-aoip-releases/build/make-oci-bundle.sh \
  --archive /mnt/inferno-build/inferno-appliance-vN.tar \
  --version vN \
  --description "Change description here" \
  --out /mnt/inferno-build/inferno-appliance-vN.iotupdate
```

---

## After the Build — Checklist

- [ ] `grep "BUILD_EXIT:0" /mnt/inferno-build/build-vN.log` — confirm success
- [ ] ISO symlink present: `ls -lh /var/lib/vz/template/iso/inferno-appliance-vN.iso`
- [ ] Upgrade tar present: `ls -lh /mnt/inferno-build/inferno-appliance-vN.tar`
- [ ] IoT bundle present: `ls -lh /mnt/inferno-build/inferno-appliance-vN.iotupdate`
- [ ] Update `README.md` version table (set new version to ✅ Production, old to Superseded)
- [ ] Update `docs/upgrade.md` version table
- [ ] `git commit && git push`
- [ ] `git pull` on PRX-01 to sync

---

## Deploying to Nodes

### Fresh install from ISO

1. Flash ISO to USB:  
   ```bash
   dd if=install.iso of=/dev/sdX bs=4M status=progress conv=fsync
   ```
2. Boot target from USB. Anaconda installs automatically (no interaction needed).
3. Node reboots → first-boot `inferno-configure.service` runs → reboots again.
4. Node is operational. Access Cockpit at `https://node-ip:9090`.

### Online upgrade via Cockpit IoT Updater (recommended)

1. Copy the `.iotupdate` bundle to a machine that can reach the node's Cockpit UI.
2. Open `https://<node-ip>:9090` → **IoT Updater**.
3. Drag-and-drop (or select) the `.iotupdate` file.
4. The UI shows version info and SHA-256 preview — click **Apply**.
5. The sidecar streams the bundle, calls `bootc switch`, and reboots the node automatically.

### Online upgrade via tarball streaming (fallback — no browser needed)

```bash
VERSION=v11
NODE=192.168.1.46   # or .47 for second node

# Stream tar from PRX-01 directly into node's podman
ssh -i ~/.ssh/inferno_proxmox root@10.10.1.201 \
  "cat /mnt/inferno-build/inferno-appliance-${VERSION}.tar" \
  | ssh -i ~/.ssh/id_ed25519 core@${NODE} 'sudo podman load'

# Stage new image and reboot to apply
# --transport containers-storage is required when image was loaded via podman load
# (without it, bootc tries to pull from a registry and fails with "connection refused")
ssh -i ~/.ssh/id_ed25519 core@${NODE} \
  "sudo bootc switch --transport containers-storage localhost/inferno-appliance:${VERSION} && sudo reboot"
```

### Rollback (if new image has issues)

```bash
ssh -i ~/.ssh/id_ed25519 core@${NODE} "sudo bootc rollback && sudo reboot"
```

bootc always keeps the previous deployment on disk — rollback is instant.

### Upgrade all nodes at once

```bash
VERSION=v11
NODES="192.168.1.46 192.168.1.47"

for NODE in $NODES; do
  echo "=== Upgrading $NODE ==="
  ssh -i ~/.ssh/inferno_proxmox -o StrictHostKeyChecking=no root@10.10.1.201 \
    "cat /mnt/inferno-build/inferno-appliance-${VERSION}.tar" \
    | ssh -o StrictHostKeyChecking=no -i ~/.ssh/id_ed25519 core@${NODE} \
      'sudo podman load'

  ssh -o StrictHostKeyChecking=no -i ~/.ssh/id_ed25519 core@${NODE} \
    "sudo bootc switch --transport containers-storage localhost/inferno-appliance:${VERSION} && sudo reboot"

  echo "=== $NODE rebooting ==="
done
```

---

## Troubleshooting

### Build killed silently (no BUILD_EXIT in log)

Root filesystem is full. Check: `df -h /`  
Clean: delete `/tmp/iso-*` artifacts, old Proxmox ISOs, apt cache, vacuum journals.

### `error: runroot mismatch` from podman

The runroot tmpfs was wiped (server rebooted). Fix:
```bash
mkdir -p /run/containers/storage
```

### `cannot build manifest: no default root filesystem type`

Missing `--rootfs xfs` in the BIB command. Always required for Fedora bootc images.

### `image not found` in BIB

Missing `-v /mnt/inferno-build/storage:/var/lib/containers/storage`.  
BIB runs inside a container — it cannot see `localhost/` images without this bind-mount.

### Build killed at step N

Check `df -h /` and `df -h /mnt/inferno-build`. Also check `/tmp` for leftover iso-work directories.

### `systemd-run: Unit already loaded`

Previous run's transient unit is still registered. Reset it:
```bash
systemctl reset-failed inferno-build-vN
systemd-run --unit=inferno-build-vN ...
```

---

## Binary CI Pipeline (GitHub Actions)

A nightly workflow (`.github/workflows/`) builds Inferno binaries from source on Ubuntu 24.04:

1. Clone [inferno](https://gitlab.com/lumifaza/inferno), [statime](https://github.com/teodly/statime) (inferno-dev branch), [librespot](https://github.com/librespot-org/librespot)
2. Build as release binaries (`cargo build --release`)
3. Bundle into `inferno-aoip.tar.gz` with SHA256 checksum
4. Publish as GitHub Release with stable `latest` URL

The `Containerfile` downloads this tarball at build time. The SHA256 is verified before install.

Stable download URL (always points to most recent build):
```
https://github.com/legopc/inferno-aoip-releases/releases/latest/download/inferno-aoip.tar.gz
```
