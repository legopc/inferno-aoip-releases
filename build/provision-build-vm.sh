#!/bin/bash
# provision-build-vm.sh — One-shot setup script for COPILOT-BUILD-01
#
# Run this ONCE on a fresh Ubuntu 24.04 server VM after SSH is available.
# Call from jumphost:
#   ssh root@<build-vm-ip> 'bash -s' < build/provision-build-vm.sh
#
# What this does:
#   1. Installs podman, fuse-overlayfs, git, curl, python3
#   2. Creates /opt/inferno-build directory structure
#   3. Clones the inferno-aoip-releases repo
#   4. Places config.toml (copied from PRX-01)
#   5. Installs the build watcher systemd timer
#   6. Installs the inferno_proxmox SSH key for SCP to Proxmox
#   7. Initialises podman storage

set -euo pipefail

BUILD_DIR=/opt/inferno-build
REPO_URL=https://github.com/legopc/inferno-aoip-releases.git
PROXMOX_ISO_HOST=root@10.10.1.202
PROXMOX_SSH_KEY=/root/.ssh/inferno_proxmox

echo "=== Inferno Build VM Provisioning ==="
echo "=== $(date) ==="

# ── Step 1: System packages ───────────────────────────────────────────────────
echo ""
echo "── [1/7] Installing packages ──"
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y --no-install-recommends \
    podman \
    fuse-overlayfs \
    uidmap \
    git \
    curl \
    python3 \
    openssh-client

# ── Step 2: Directory layout ─────────────────────────────────────────────────
echo ""
echo "── [2/7] Creating build directory layout ──"
mkdir -p \
    "${BUILD_DIR}/storage" \
    "${BUILD_DIR}/watcher-state"

# ── Step 3: Clone repo ───────────────────────────────────────────────────────
echo ""
echo "── [3/7] Cloning inferno-aoip-releases ──"
if [[ -d "${BUILD_DIR}/inferno-aoip-releases/.git" ]]; then
    echo "Repo already exists — pulling."
    git -C "${BUILD_DIR}/inferno-aoip-releases" pull
else
    git clone "${REPO_URL}" "${BUILD_DIR}/inferno-aoip-releases"
fi

# ── Step 4: config.toml ──────────────────────────────────────────────────────
echo ""
echo "── [4/7] Fetching config.toml from PRX-01 ──"
if [[ ! -f "${BUILD_DIR}/config.toml" ]]; then
    # config.toml lives on PRX-01 at /mnt/inferno-build/config.toml
    # Requires the inferno_proxmox SSH key to be in place (step 6) — bootstrap problem.
    # Copy it here manually if SSH key isn't installed yet:
    #   scp root@10.10.1.201:/mnt/inferno-build/config.toml /opt/inferno-build/config.toml
    echo "WARNING: config.toml not found at ${BUILD_DIR}/config.toml"
    echo "  Copy it manually: scp root@10.10.1.201:/mnt/inferno-build/config.toml ${BUILD_DIR}/config.toml"
    echo "  (Requires inferno_proxmox SSH key — run step 6 first, then re-run.)"
else
    echo "config.toml already present."
fi

# ── Step 5: Environment config for build scripts ──────────────────────────────
echo ""
echo "── [5/7] Writing build environment config ──"
cat > /etc/inferno-build.env <<EOF
BUILD_DIR=${BUILD_DIR}
PROXMOX_ISO_HOST=${PROXMOX_ISO_HOST}
PROXMOX_ISO_DIR=/var/lib/vz/template/iso
PROXMOX_SSH_KEY=${PROXMOX_SSH_KEY}
EOF
echo "Written: /etc/inferno-build.env"

# ── Step 6: SSH key for Proxmox SCP ──────────────────────────────────────────
echo ""
echo "── [6/7] SSH key for Proxmox SCP ──"
mkdir -p /root/.ssh && chmod 700 /root/.ssh
if [[ ! -f "${PROXMOX_SSH_KEY}" ]]; then
    echo "  inferno_proxmox key not found."
    echo "  Copy it from jumphost: scp legopc@jumphost01:~/.ssh/inferno_proxmox ${PROXMOX_SSH_KEY}"
    echo "  Then run: chmod 600 ${PROXMOX_SSH_KEY}"
    echo "  Then add PRX-02 to known_hosts: ssh-keyscan -H 10.10.1.202 >> /root/.ssh/known_hosts"
else
    echo "  inferno_proxmox key already present."
fi

# ── Step 7: Install watcher systemd units ────────────────────────────────────
echo ""
echo "── [7/7] Installing build watcher systemd timer ──"

# Copy scripts from the cloned repo
cp "${BUILD_DIR}/inferno-aoip-releases/build/inferno-build-watcher.sh" \
   "${BUILD_DIR}/inferno-build-watcher.sh"
chmod +x "${BUILD_DIR}/inferno-build-watcher.sh"

cp "${BUILD_DIR}/inferno-aoip-releases/build/systemd/inferno-build-watcher.service" \
   /etc/systemd/system/inferno-build-watcher.service

cp "${BUILD_DIR}/inferno-aoip-releases/build/systemd/inferno-build-watcher.timer" \
   /etc/systemd/system/inferno-build-watcher.timer

systemctl daemon-reload
systemctl enable --now inferno-build-watcher.timer
systemctl list-timers inferno-build-watcher.timer --no-pager

# ── Validate podman works ─────────────────────────────────────────────────────
echo ""
echo "── Validating podman with custom storage ──"
mkdir -p /run/containers/storage
podman \
    --storage-driver overlay \
    --storage-opt overlay.mount_program=/usr/bin/fuse-overlayfs \
    --root "${BUILD_DIR}/storage" \
    --runroot /run/containers/storage \
    info --format "GraphDriver: {{.Store.GraphDriverName}}" 2>&1 | head -5

echo ""
echo "=== Provisioning complete at $(date) ==="
echo ""
echo "NEXT STEPS:"
if [[ ! -f "${BUILD_DIR}/config.toml" ]]; then
  echo "  1. Copy config.toml from PRX-01:"
  echo "       scp -i ${PROXMOX_SSH_KEY} root@10.10.1.201:/mnt/inferno-build/config.toml ${BUILD_DIR}/config.toml"
fi
if [[ ! -f "${PROXMOX_SSH_KEY}" ]]; then
  echo "  2. Install inferno_proxmox SSH key:"
  echo "       (copy key content to ${PROXMOX_SSH_KEY} and chmod 600)"
  echo "       ssh-keyscan -H 10.10.1.202 >> /root/.ssh/known_hosts"
fi
echo ""
echo "  Then trigger a test build from the jumphost:"
echo "    inferno-build v12 'First build on COPILOT-BUILD-01'"
echo ""
echo "  Monitor: inferno-build-status v12"
