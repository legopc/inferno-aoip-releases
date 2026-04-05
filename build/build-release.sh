#!/bin/bash
# build-release.sh — Full release build for Inferno AoIP on PRX-01
# Produces: container image, installer ISO, and upgrade tarball
#
# Usage: ./build-release.sh <version>
# Example: ./build-release.sh v10
#
# Must be run on PRX-01 (root@10.10.1.201) from /mnt/inferno-build/inferno-aoip-releases
# or called remotely via SSH.

set -euo pipefail

VERSION="${1:?Usage: $0 <version> (e.g. v10)}"

STORAGE_ROOT=/mnt/inferno-build/storage
RUNROOT=/run/containers/storage
OUTPUT_DIR=/mnt/inferno-build/output-${VERSION}
UPGRADE_TAR=/mnt/inferno-build/inferno-appliance-${VERSION}.tar
CONFIG_TOML=/mnt/inferno-build/config.toml
PROXMOX_ISO_DIR=/var/lib/vz/template/iso

PODMAN="podman --storage-driver overlay
  --storage-opt overlay.mount_program=/usr/bin/fuse-overlayfs
  --root ${STORAGE_ROOT}
  --runroot ${RUNROOT}"

echo "=== Inferno AoIP release build: ${VERSION} ==="
echo "=== Started at $(date) ==="

# Ensure runroot dir exists (tmpfs, wiped on reboot)
mkdir -p "${RUNROOT}"

# ── Step 1: Pull latest code ──────────────────────────────────────────────────
echo ""
echo "── [1/4] Pulling latest code ──"
cd /mnt/inferno-build/inferno-aoip-releases
git pull

# ── Step 2: Build container image ────────────────────────────────────────────
echo ""
echo "── [2/4] Building container image localhost/inferno-appliance:${VERSION} ──"
${PODMAN} build -t "inferno-appliance:${VERSION}" -f Containerfile .

# ── Step 3: Build installer ISO ───────────────────────────────────────────────
echo ""
echo "── [3/4] Building installer ISO → ${OUTPUT_DIR} ──"
mkdir -p "${OUTPUT_DIR}"
${PODMAN} run --rm --privileged \
  -v "${STORAGE_ROOT}:/var/lib/containers/storage" \
  -v "${OUTPUT_DIR}:/output" \
  -v "${CONFIG_TOML}:/config.toml:ro" \
  ghcr.io/osbuild/bootc-image-builder:latest \
  --type anaconda-iso \
  --rootfs xfs \
  --config /config.toml \
  --local "localhost/inferno-appliance:${VERSION}"

ISO_PATH="${OUTPUT_DIR}/bootiso/install.iso"
echo "ISO built: $(ls -lh ${ISO_PATH})"

# Symlink into Proxmox ISO storage
ln -sf "${ISO_PATH}" "${PROXMOX_ISO_DIR}/inferno-appliance-${VERSION}.iso"
echo "Symlinked: ${PROXMOX_ISO_DIR}/inferno-appliance-${VERSION}.iso → ${ISO_PATH}"

# ── Step 4: Export upgrade tarball ───────────────────────────────────────────
echo ""
echo "── [4/4] Exporting upgrade tarball → ${UPGRADE_TAR} ──"
${PODMAN} save "localhost/inferno-appliance:${VERSION}" -o "${UPGRADE_TAR}"
echo "Upgrade tar: $(ls -lh ${UPGRADE_TAR})"

echo ""
echo "=== Build complete at $(date) ==="
echo "  ISO:         ${PROXMOX_ISO_DIR}/inferno-appliance-${VERSION}.iso"
echo "  Upgrade tar: ${UPGRADE_TAR}"
echo ""
echo "To upgrade a node:"
echo "  ssh -i ~/.ssh/inferno_proxmox -o StrictHostKeyChecking=no root@10.10.1.201 \\"
echo "    'cat ${UPGRADE_TAR}' \\"
echo "    | ssh -i ~/.ssh/inferno_proxmox core@<NODE-IP> 'sudo podman load'"
echo "  ssh -i ~/.ssh/inferno_proxmox core@<NODE-IP> \\"
echo "    'sudo bootc switch localhost/inferno-appliance:${VERSION} && sudo reboot'"
