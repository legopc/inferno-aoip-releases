# Inferno Appliance — Upgrade Procedure

> Upgrade nodes like network equipment: stage a new image, reboot to apply, roll back if needed.
> No registry required — everything works over the LAN from PRX-01.

---

## How It Works

bootc keeps **two OS deployments** on disk at all times:
- **Current** — what's running now
- **Previous** — the deployment before the last upgrade

Upgrading stages a new deployment without touching the running system.
Reboot applies it. If something is broken, one command rolls back.

```
Build new image on PRX-01
    → Transfer to node over SSH (no registry needed)
    → bootc switch  (stages new deployment)
    → reboot        (applies — node now runs new image)
    → broken?  →  bootc rollback && reboot  (back to previous in 1 min)
```

---

## Step 1 — Build New Image on PRX-01

The build script (`build/build-release.sh`) automatically produces both the installer ISO and the upgrade tarball. Run it via `systemd-run` so it survives SSH disconnects:

```bash
VERSION=v10   # change for each release

ssh -i ~/.ssh/inferno_proxmox root@10.10.1.201 "
  mkdir -p /run/containers/storage
  systemd-run --unit=inferno-build-${VERSION} \
    /mnt/inferno-build/inferno-aoip-releases/build/build-release.sh ${VERSION} \
    > /mnt/inferno-build/build-${VERSION}.log 2>&1
"

# Monitor
ssh -i ~/.ssh/inferno_proxmox root@10.10.1.201 "tail -f /mnt/inferno-build/build-${VERSION}.log"
```

When complete, the upgrade tarball is at `/mnt/inferno-build/inferno-appliance-${VERSION}.tar`.

---

## Step 2 — Apply Upgrade to a Node

```bash
# From the Copilot VM (has SSH access to both PRX-01 and nodes):
NODE=192.168.1.46   # or .47, .46, etc.
VERSION=v8

ssh -i ~/.ssh/inferno_proxmox core@$NODE "
  # Stream image from PRX-01 directly into podman on the node
  ssh -i ~/.ssh/inferno_proxmox -o StrictHostKeyChecking=no root@10.10.1.201 \
    'cat /mnt/inferno-build/inferno-appliance-${VERSION}.tar' \
    | sudo podman load

  # Switch bootc to the new image (stages — does not affect running system)
  sudo bootc switch localhost/inferno-appliance:${VERSION}

  # Reboot to apply
  sudo reboot
"
```

Or in two steps if you prefer to verify before rebooting:

```bash
# Step A: load image on node
ssh -i ~/.ssh/inferno_proxmox -o StrictHostKeyChecking=no root@10.10.1.201 \
  'cat /mnt/inferno-build/inferno-appliance-v8.tar' \
  | ssh -i ~/.ssh/inferno_proxmox core@192.168.1.46 'sudo podman load'

# Step B: stage and reboot when ready
ssh -i ~/.ssh/inferno_proxmox core@192.168.1.46 \
  'sudo bootc switch localhost/inferno-appliance:v8 && sudo reboot'
```

---

## Step 3 — Verify After Reboot

```bash
ssh -i ~/.ssh/inferno_proxmox core@$NODE "
  bootc status                               # shows current deployment
  id                                         # must show 63(audio)
  systemctl --failed --no-pager
  systemctl --user --failed --no-pager
  systemctl --user is-active inferno-bridge librespot
"
```

---

## Rollback

If the new image has a problem:

```bash
ssh -i ~/.ssh/inferno_proxmox core@$NODE "
  sudo bootc rollback   # stage previous deployment
  sudo reboot           # apply rollback
"
```

bootc always keeps the previous deployment. Rollback is instant.

---

## Upgrade All Nodes at Once

```bash
NODES="192.168.1.46 192.168.1.47"
VERSION=v8

for NODE in $NODES; do
  echo "=== Upgrading $NODE ==="
  # Load image
  ssh -i ~/.ssh/inferno_proxmox -o StrictHostKeyChecking=no root@10.10.1.201 \
    "cat /mnt/inferno-build/inferno-appliance-${VERSION}.tar" \
    | ssh -o StrictHostKeyChecking=no -i ~/.ssh/inferno_proxmox core@$NODE \
      'sudo podman load'

  # Stage and reboot
  ssh -o StrictHostKeyChecking=no -i ~/.ssh/inferno_proxmox core@$NODE \
    "sudo bootc switch localhost/inferno-appliance:${VERSION} && sudo reboot"

  echo "=== $NODE rebooting ==="
done
```

---

## Check Current Image Version on a Node

```bash
ssh -i ~/.ssh/inferno_proxmox core@$NODE "bootc status"
```

Output shows:
- `image` — the OCI image reference
- `version` — image build date/tag
- `timestamp` — when this deployment was staged
- Previous deployment (available for rollback)

---

## Live Patching Without Upgrade

For quick fixes that don't need a full image rebuild, edit `/etc/` directly on the node.
Changes in `/etc/` persist across reboots and survive `bootc upgrade` (3-way merge).

| What to change | How |
|----------------|-----|
| PTP domain/priority | `sudo nano /etc/statime-inferno.toml` → `sudo systemctl restart statime-inferno` |
| NIC (if wrong one detected) | `sudo rm /etc/inferno.conf && sudo reboot` (re-runs auto-detect) |
| Hostname | `sudo hostnamectl set-hostname inferno-<name>` |
| User service unit | `nano ~/.config/systemd/user/<unit>.service` → `systemctl --user daemon-reload && systemctl --user restart <unit>` |
| Audio group missing (pre-v8 node) | `echo 'audio:x:63:core' \| sudo tee -a /etc/group && sudo reboot` |

Changes that **require a full image rebuild and upgrade**:
- Updating binaries (statime, librespot, ALSA plugin)
- Adding/removing packages
- Fixing system-level service units
- Changing config templates in `/etc/inferno/`

---

## Version History

| Version | Key changes |
|---------|-------------|
| v10 | Hot-plug USB audio (udev), TX/RX channel selectors, multi-card support, conditional Spotify Connect name field |
| v8 | Audio group fix: direct `/etc/group` write (bypasses NSS/groupadd) |
| v7 | Cockpit full feature set; linger pre-creation; WiFi NIC exclusion |
| v6 | SELinux binary paths; auto-reboot after configure; ordering cycle fix |
| v5 | Initial working bootc appliance |
