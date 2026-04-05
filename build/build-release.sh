#!/bin/bash
# build-release.sh — Full release build for Inferno AoIP
# Produces: container image, installer ISO, raw upgrade tarball, and .iotupdate bundle
#
# Usage: ./build-release.sh <version> [description]
# Example: ./build-release.sh v12 "Fix 4-channel card visibility on page load"
#
# Runs on COPILOT-BUILD-01 (root@<build-vm-ip>) — the dedicated build VM on PRX-02.
# Trigger remotely via: inferno-build <version> [description]  (on jumphost)
#
# Paths are configured via environment variables so the script works on any host:
#   BUILD_DIR      — root of build workspace (default: /opt/inferno-build)
#   PROXMOX_ISO_HOST — SCP target for ISO (default: root@10.10.1.202)
#   PROXMOX_ISO_DIR  — remote path for ISO (default: /var/lib/vz/template/iso)
#   PROXMOX_SSH_KEY  — SSH key for Proxmox SCP (default: /root/.ssh/inferno_proxmox)

set -euo pipefail

VERSION="${1:?Usage: $0 <version> [description] (e.g. v12)}"
DESCRIPTION="${2:-"Inferno AoIP ${VERSION} release"}"

# ── Path configuration (override via environment) ─────────────────────────────
BUILD_DIR="${BUILD_DIR:-/opt/inferno-build}"
PROXMOX_ISO_HOST="${PROXMOX_ISO_HOST:-root@10.10.1.202}"
PROXMOX_ISO_DIR="${PROXMOX_ISO_DIR:-/var/lib/vz/template/iso}"
PROXMOX_SSH_KEY="${PROXMOX_SSH_KEY:-/root/.ssh/inferno_proxmox}"

STORAGE_ROOT="${BUILD_DIR}/storage"
RUNROOT=/run/containers/storage
OUTPUT_DIR="${BUILD_DIR}/output-${VERSION}"
UPGRADE_TAR="${BUILD_DIR}/inferno-appliance-${VERSION}.tar"
IOTUPDATE_BUNDLE="${BUILD_DIR}/inferno-appliance-${VERSION}.iotupdate"
CONFIG_TOML="${BUILD_DIR}/config.toml"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

PODMAN="podman --storage-driver overlay
  --storage-opt overlay.mount_program=/usr/bin/fuse-overlayfs
  --root ${STORAGE_ROOT}
  --runroot ${RUNROOT}"

echo "=== Inferno AoIP release build: ${VERSION} ==="
echo "=== Started at $(date) ==="
echo "=== Build dir: ${BUILD_DIR} ==="

# Ensure runroot dir exists (tmpfs, wiped on reboot)
mkdir -p "${RUNROOT}"

# ── Step 1: Pull latest code ──────────────────────────────────────────────────
echo ""
echo "── [1/5] Pulling latest code ──"
cd "${BUILD_DIR}/inferno-aoip-releases"
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

# SCP ISO to Proxmox ISO storage (build VM is separate from Proxmox host)
ISO_DEST="${PROXMOX_ISO_DIR}/inferno-appliance-${VERSION}.iso"
if [[ -n "${PROXMOX_ISO_HOST}" ]]; then
  echo "Copying ISO to ${PROXMOX_ISO_HOST}:${ISO_DEST} ..."
  scp -i "${PROXMOX_SSH_KEY}" -o StrictHostKeyChecking=no \
    "${ISO_PATH}" "${PROXMOX_ISO_HOST}:${ISO_DEST}"
  echo "ISO available in Proxmox: ${ISO_DEST}"
else
  # Running directly on a Proxmox host — symlink as before
  ln -sf "${ISO_PATH}" "${ISO_DEST}"
  echo "Symlinked: ${ISO_DEST} → ${ISO_PATH}"
fi

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
echo "  ISO:             ${PROXMOX_ISO_HOST}:${PROXMOX_ISO_DIR}/inferno-appliance-${VERSION}.iso"
echo "  Upgrade tar:     ${UPGRADE_TAR}  (raw, for streaming upgrades)"
echo "  IoT bundle:      ${IOTUPDATE_BUNDLE}  (upload via Cockpit IoT Updater UI)"
echo ""
echo "To upgrade a node via tarball streaming:"
echo "  ssh root@<build-vm> 'cat ${UPGRADE_TAR}' \\"
echo "    | ssh -i ~/.ssh/inferno_proxmox core@<NODE-IP> 'sudo podman load'"
echo "  ssh -i ~/.ssh/inferno_proxmox core@<NODE-IP> \\"
echo "    'sudo bootc switch --transport containers-storage localhost/inferno-appliance:${VERSION} && sudo reboot'"
echo ""
echo "To upgrade via Cockpit IoT Updater:"
echo "  1. Open https://<device-ip>:9090 → IoT Updater"
echo "  2. Upload ${IOTUPDATE_BUNDLE}"
echo ""
echo "BUILD_EXIT:0"
