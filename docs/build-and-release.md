# Inferno AoIP — Build and Release Process

> Full guide for building a new Inferno AoIP release.
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

The build runs on **COPILOT-BUILD-01** (`root@<build-vm-ip>`) — a dedicated VM on PRX-02 (VMID 112).  
The jumphost (`jumphost01`) is used to trigger and monitor builds remotely.

---

## Releasing a New Version

### Option A — Automatic (recommended)

Push a git tag. The build VM detects it within 30 minutes and builds automatically:

```bash
git tag v12
git push origin v12
```

Monitor from the jumphost:
```bash
inferno-build-status v12   # check progress
inferno-build-log v12      # stream live log
```

### Option B — Manual trigger from jumphost

```bash
inferno-build v12 "Fix 4-channel card visibility on page load"
```

This SSHes to the build VM and launches the build in the background via `systemd-run`.  
The script returns immediately — the build continues even after you close the terminal.

---

## Build Infrastructure

### COPILOT-BUILD-01 (Proxmox VM 112, PRX-02)

| Item | Value |
|------|-------|
| VMID | 112 |
| Node | PRX-02 (`10.10.1.202`) |
| IP | DHCP on VLAN 10 — see `~/.inferno-build.conf` on jumphost |
| Spec | 10 vCPU, 24 GB RAM, 150 GB disk |
| OS | Ubuntu 24.04 LTS |
| SSH | `root@<ip>` with `~/.ssh/inferno_proxmox` |

| Path | Purpose |
|------|---------|
| `/opt/inferno-build/inferno-aoip-releases` | Git repo clone |
| `/opt/inferno-build/storage` | Podman graphRoot (fuse-overlayfs) |
| `/run/containers/storage` | Podman runRoot (tmpfs — auto-recreated by build scripts) |
| `/opt/inferno-build/config.toml` | bootc-image-builder config |
| `/opt/inferno-build/output-vN/` | ISO build output |
| `/opt/inferno-build/inferno-appliance-vN.tar` | Upgrade tarball output |
| `/opt/inferno-build/inferno-appliance-vN.iotupdate` | IoT Updater bundle output |
| `/opt/inferno-build/build-vN.log` | Build log |
| `/opt/inferno-build/watcher.log` | Auto-build watcher log |
| `/etc/inferno-build.env` | Build environment variables (paths, Proxmox host) |

### Jumphost automation scripts (`~/bin/`)

| Script | Purpose |
|--------|---------|
| `inferno-build <version> [desc]` | Trigger a background build on COPILOT-BUILD-01 |
| `inferno-build-status [version]` | Check build progress and last 20 log lines |
| `inferno-build-log <version>` | Stream live build log (Ctrl+C to stop; build keeps running) |
| `inferno-deploy <version> [nodes]` | Stream upgrade tarball to production nodes and reboot them |

Configuration in `~/.inferno-build.conf` — update `BUILD_VM` after the build VM boots.

### Auto-build watcher (on COPILOT-BUILD-01)

A `systemd.timer` (`inferno-build-watcher.timer`) runs every 30 minutes and checks:
1. **New `v*` git tag** pushed to `legopc/inferno-aoip-releases` → auto-builds that version
2. **New nightly binary** published by GitHub Actions CI → auto-builds `nightly-YYYY-MM-DD`

Check watcher status:
```bash
ssh root@<build-vm> "systemctl list-timers inferno-build-watcher.timer"
ssh root@<build-vm> "tail -30 /opt/inferno-build/watcher.log"
```

### Critical: Podman storage flags

Always use these flags together:

```bash
podman --storage-driver overlay \
  --storage-opt overlay.mount_program=/usr/bin/fuse-overlayfs \
  --root /opt/inferno-build/storage \
  --runroot /run/containers/storage
```

After a VM reboot, `/run/containers/storage` is wiped (tmpfs). The build scripts recreate it automatically.

### Critical: Use systemd-run for long builds

`nohup ... &` and `setsid ... &` die when the SSH session closes.  
All builds use `systemd-run` — they survive disconnects:

```bash
systemd-run --unit=inferno-build-vN /path/to/script.sh
systemctl is-active inferno-build-vN    # check status
```

### Disk space (COPILOT-BUILD-01)

The build VM has 150 GB dedicated to `/opt/inferno-build`. Clean up old builds periodically:

```bash
# Old ISO output directories
rm -rf /opt/inferno-build/output-v9 /opt/inferno-build/output-v10

# Old upgrade tarballs (keep latest 2 versions)
ls -lth /opt/inferno-build/inferno-appliance-*.tar

# Dangling podman images
podman --storage-driver overlay \
  --storage-opt overlay.mount_program=/usr/bin/fuse-overlayfs \
  --root /opt/inferno-build/storage \
  --runroot /run/containers/storage \
  image prune
```

---

## Standard Build (Recommended)

### From the jumphost — automatic (push a tag)

```bash
# In your local repo checkout:
git tag v12
git push origin v12
# Build VM detects tag within 30 min and builds automatically.
```

Monitor from jumphost:
```bash
inferno-build-status v12
inferno-build-log v12
```

### From the jumphost — manual trigger

```bash
inferno-build v12 "Brief description of changes"
# Returns immediately; build runs in background on COPILOT-BUILD-01
inferno-build-status v12
```

### Directly on COPILOT-BUILD-01 (fallback)

```bash
ssh -i ~/.ssh/inferno_proxmox root@<build-vm-ip>

VERSION=v12
DESCRIPTION="Brief description"

mkdir -p /run/containers/storage

systemd-run \
  --unit=inferno-build-${VERSION} \
  --property="StandardOutput=append:/opt/inferno-build/build-${VERSION}.log" \
  --property="StandardError=append:/opt/inferno-build/build-${VERSION}.log" \
  --setenv="BUILD_DIR=/opt/inferno-build" \
  --setenv="PROXMOX_ISO_HOST=root@10.10.1.202" \
  --setenv="PROXMOX_ISO_DIR=/var/lib/vz/template/iso" \
  --setenv="PROXMOX_SSH_KEY=/root/.ssh/inferno_proxmox" \
  /opt/inferno-build/inferno-aoip-releases/build/build-release.sh "${VERSION}" "${DESCRIPTION}"

# Monitor
systemctl is-active inferno-build-${VERSION}
tail -f /opt/inferno-build/build-${VERSION}.log
```

### Verify outputs

```bash
# From jumphost:
inferno-build-status v12

# On build VM:
podman --storage-driver overlay \
  --storage-opt overlay.mount_program=/usr/bin/fuse-overlayfs \
  --root /opt/inferno-build/storage \
  --runroot /run/containers/storage \
  images | grep inferno-appliance

ls -lh /opt/inferno-build/inferno-appliance-${VERSION}.tar
ls -lh /opt/inferno-build/inferno-appliance-${VERSION}.iotupdate

# ISO on PRX-02 (SCPed there automatically by build script):
ssh root@10.10.1.202 "ls -lh /var/lib/vz/template/iso/inferno-appliance-${VERSION}.iso"
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
  --archive /opt/inferno-build/inferno-appliance-vN.tar \
  --version vN \
  --description "Change description" \
  --out /opt/inferno-build/inferno-appliance-vN.iotupdate
```

Packages the raw tar with a `version.json` manifest and SHA-256 hash into a single `.iotupdate` bundle.  
This is the file you upload via the **Cockpit IoT Updater** UI to upgrade a node over the network.  
**Expected time:** ~1–2 minutes (just SHA-256 + tar wrap). Output: same size as upgrade tar.

---

## Manual Steps (if `build-release.sh` cannot be used)

All commands run on COPILOT-BUILD-01 (`ssh -i ~/.ssh/inferno_proxmox root@<build-vm-ip>`).

### Build container image only

```bash
cd /opt/inferno-build/inferno-aoip-releases
mkdir -p /run/containers/storage

podman --storage-driver overlay \
  --storage-opt overlay.mount_program=/usr/bin/fuse-overlayfs \
  --root /opt/inferno-build/storage \
  --runroot /run/containers/storage \
  build -t inferno-appliance:vN -f Containerfile .
```

### Build ISO only (container image already exists)

```bash
mkdir -p /opt/inferno-build/output-vN /run/containers/storage

podman --storage-driver overlay \
  --storage-opt overlay.mount_program=/usr/bin/fuse-overlayfs \
  --root /opt/inferno-build/storage \
  --runroot /run/containers/storage \
  run --rm --privileged \
  -v /opt/inferno-build/storage:/var/lib/containers/storage \
  -v /opt/inferno-build/output-vN:/output \
  -v /opt/inferno-build/config.toml:/config.toml:ro \
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
  --root /opt/inferno-build/storage \
  --runroot /run/containers/storage \
  save localhost/inferno-appliance:vN \
  -o /opt/inferno-build/inferno-appliance-vN.tar
```

### Package .iotupdate bundle only (upgrade tarball already exists)

```bash
/opt/inferno-build/inferno-aoip-releases/build/make-oci-bundle.sh \
  --archive /opt/inferno-build/inferno-appliance-vN.tar \
  --version vN \
  --description "Change description here" \
  --out /opt/inferno-build/inferno-appliance-vN.iotupdate
```

---

## After the Build — Checklist

- [ ] `inferno-build-status vN` — confirm `BUILD_EXIT:0` (from jumphost)
- [ ] ISO present on PRX-02: `ssh root@10.10.1.202 "ls -lh /var/lib/vz/template/iso/inferno-appliance-vN.iso"`
- [ ] Upgrade tar present: `ls -lh /opt/inferno-build/inferno-appliance-vN.tar` (on build VM)
- [ ] IoT bundle present: `ls -lh /opt/inferno-build/inferno-appliance-vN.iotupdate` (on build VM)
- [ ] Update `README.md` version table (set new version to ✅ Production, old to Superseded)
- [ ] Update `docs/upgrade.md` version table
- [ ] `git commit && git push`

---

## Deploying to Nodes

### Fresh install from ISO

1. Download ISO from PRX-02: `/var/lib/vz/template/iso/inferno-appliance-vN.iso`
2. Flash to USB: `dd if=install.iso of=/dev/sdX bs=4M status=progress conv=fsync`
3. Boot target from USB. Anaconda installs automatically (no interaction needed).
4. Node reboots → first-boot `inferno-configure.service` runs → reboots again.
5. Node is operational. Access Cockpit at `https://node-ip:9090`.

### Online upgrade from jumphost (recommended)

```bash
inferno-deploy v12 192.168.1.46
# or multiple nodes:
inferno-deploy v12 192.168.1.46 192.168.1.47
```

This streams the upgrade tarball from COPILOT-BUILD-01 directly into the node's podman, then reboots.

### Online upgrade via Cockpit IoT Updater

1. Copy the `.iotupdate` bundle from COPILOT-BUILD-01 to a machine that can reach the node's Cockpit UI.
2. Open `https://<node-ip>:9090` → **IoT Updater**.
3. Drag-and-drop (or select) the `.iotupdate` file.
4. The UI shows version info and SHA-256 preview — click **Apply**.
5. The sidecar streams the bundle, calls `bootc switch`, and reboots the node automatically.

### Online upgrade via tarball streaming (manual fallback)

```bash
VERSION=v12
NODE=192.168.1.46
BUILD_VM=<build-vm-ip>

# Stream tar from build VM into node's podman
ssh -i ~/.ssh/inferno_proxmox root@${BUILD_VM} \
  "cat /opt/inferno-build/inferno-appliance-${VERSION}.tar" \
  | ssh -i ~/.ssh/inferno_proxmox core@${NODE} 'sudo podman load'

# Stage new image and reboot to apply
ssh -i ~/.ssh/inferno_proxmox core@${NODE} \
  "sudo bootc switch --transport containers-storage localhost/inferno-appliance:${VERSION} && sudo reboot"
```

### Rollback (if new image has issues)

```bash
ssh -i ~/.ssh/inferno_proxmox core@${NODE} "sudo bootc rollback && sudo reboot"
```

bootc always keeps the previous deployment on disk — rollback is instant.

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

Missing `-v /opt/inferno-build/storage:/var/lib/containers/storage`.  
BIB runs inside a container — it cannot see `localhost/` images without this bind-mount.

### Build killed at step N

Check `df -h /` and `df -h /opt/inferno-build`. Also check `/tmp` for leftover iso-work directories.

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
