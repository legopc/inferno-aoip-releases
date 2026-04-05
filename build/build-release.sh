#!/bin/bash
# build-release.sh — Full release build for Inferno AoIP on PRX-01
# Produces: container image, installer ISO, raw upgrade tarball, and .iotupdate bundle
#
# Usage: ./build-release.sh <version> [description]
# Example: ./build-release.sh v11 "Fix 4-channel card visibility on page load"
#
# Must be run on PRX-01 (root@10.10.1.201) from /mnt/inferno-build/inferno-aoip-releases
# or called remotely via SSH.

set -euo pipefail

VERSION="${1:?Usage: $0 <version> [description] (e.g. v11)}"
DESCRIPTION="${2:-"Inferno AoIP ${VERSION} release"}"

STORAGE_ROOT=/mnt/inferno-build/storage
RUNROOT=/run/containers/storage
OUTPUT_DIR=/mnt/inferno-build/output-${VERSION}
UPGRADE_TAR=/mnt/inferno-build/inferno-appliance-${VERSION}.tar
IOTUPDATE_BUNDLE=/mnt/inferno-build/inferno-appliance-${VERSION}.iotupdate
CONFIG_TOML=/mnt/inferno-build/config.toml
PROXMOX_ISO_DIR=/var/lib/vz/template/iso
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

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
echo "── [1/5] Pulling latest code ──"
cd /mnt/inferno-build/inferno-aoip-releases
git pull

# ── Step 2: Build container image ────────────────────────────────────────────
echo ""
echo "── [2/5] Building container image localhost/inferno-appliance:${VERSION} ──"
${PODMAN} build -t "inferno-appliance:${VERSION}" -f Containerfile .

# ── Step 3: Build installer ISO ───────────────────────────────────────────────
echo ""
echo "── [3/5] Building installer ISO → ${OUTPUT_DIR} ──"
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

# ── Step 4: Export raw upgrade tarball ───────────────────────────────────────
echo ""
echo "── [4/5] Exporting raw upgrade tarball → ${UPGRADE_TAR} ──"
${PODMAN} save "localhost/inferno-appliance:${VERSION}" -o "${UPGRADE_TAR}"
echo "Upgrade tar: $(ls -lh ${UPGRADE_TAR})"

# ── Step 5: Package .iotupdate bundle ────────────────────────────────────────
echo ""
echo "── [5/5] Packaging .iotupdate bundle for Cockpit IoT Updater → ${IOTUPDATE_BUNDLE} ──"
"${SCRIPT_DIR}/make-oci-bundle.sh" \
  --archive "${UPGRADE_TAR}" \
  --version "${VERSION}" \
  --description "${DESCRIPTION}" \
  --out "${IOTUPDATE_BUNDLE}"

echo ""
echo "=== Build complete at $(date) ==="
echo "  ISO:             ${PROXMOX_ISO_DIR}/inferno-appliance-${VERSION}.iso"
echo "  Upgrade tar:     ${UPGRADE_TAR}  (raw, for streaming upgrades)"
echo "  IoT bundle:      ${IOTUPDATE_BUNDLE}  (upload via Cockpit IoT Updater UI)"
echo ""
echo "To upgrade a node via tarball streaming:"
echo "  ssh root@10.10.1.201 'cat ${UPGRADE_TAR}' \\"
echo "    | ssh -i ~/.ssh/id_ed25519 core@<NODE-IP> 'sudo podman load'"
echo "  ssh -i ~/.ssh/id_ed25519 core@<NODE-IP> \\"
echo "    'sudo bootc switch --transport containers-storage localhost/inferno-appliance:${VERSION} && sudo reboot'"
echo ""
echo "To upgrade via Cockpit IoT Updater:"
echo "  1. Open https://<device-ip>:9090 → IoT Updater"
echo "  2. Upload ${IOTUPDATE_BUNDLE}"
