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

STORAGE_ROOT="/var/lib/containers/storage"
OUTPUT_DIR="${BUILD_DIR}/output-${VERSION}"
RELEASES_DIR="${BUILD_DIR}/releases"
UPGRADE_TAR="${RELEASES_DIR}/inferno-appliance-${VERSION}.tar"
IOTUPDATE_BUNDLE="${RELEASES_DIR}/inferno-appliance-${VERSION}.iotupdate"
CONFIG_TOML="${BUILD_DIR}/config.toml"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

mkdir -p "${RELEASES_DIR}"

# Use default podman storage — native overlayfs works for root on Ubuntu 24.04.
# /var/lib/containers/storage is the default; BIB mounts the same path so its
# internal podman finds the image without a database path mismatch.
PODMAN="podman"

echo "=== Inferno AoIP release build: ${VERSION} ==="
echo "=== Started at $(date) ==="
echo "=== Build dir: ${BUILD_DIR} ==="

# ── Step 1: Pull latest code ──────────────────────────────────────────────────
echo ""
echo "── [1/5] Pulling latest code ──"
cd "${BUILD_DIR}/inferno-aoip-releases"
git pull
git submodule update --init --recursive

BRANDING_DIR="${BUILD_DIR}/inferno-aoip-releases/branding"

# ── Step 2: Build container image ────────────────────────────────────────────
echo ""
echo "── [2/5] Building container image localhost/inferno-appliance:${VERSION} ──"
${PODMAN} build --network=host -t "inferno-appliance:${VERSION}" -f Containerfile .

# ── Step 3: Build installer ISO ───────────────────────────────────────────────
echo ""
echo "── [3/5] Building installer ISO → ${OUTPUT_DIR} ──"
mkdir -p "${OUTPUT_DIR}"
${PODMAN} run --rm --privileged --network=host \
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

# ── Step 3b: Inject installer branding ───────────────────────────────────────
echo ""
if [[ -d "${BRANDING_DIR}/installer/pixmaps" ]]; then
  echo "── [3b] Injecting installer branding ──"
  cd "${BRANDING_DIR}"
  bash scripts/build-product-img.sh
  BRANDED_ISO="${OUTPUT_DIR}/bootiso/inferno-appliance-${VERSION}-branded.iso"
  bash scripts/inject-iso-branding.sh "${ISO_PATH}" "${BRANDED_ISO}"
  ISO_PATH="${BRANDED_ISO}"
  echo "Branded ISO: $(ls -lh ${ISO_PATH})"
  cd "${BUILD_DIR}/inferno-aoip-releases"
else
  echo "── [3b] No branding pixmaps found — skipping ISO branding ──"
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
  --image-name "localhost/inferno-appliance:${VERSION}" \
  --version "${VERSION}" \
  --description "${DESCRIPTION}" \
  --out "${IOTUPDATE_BUNDLE}"

# ── All local artifacts ready ─────────────────────────────────────────────────
echo ""
echo "=== Local artifacts ready on build VM ==="
echo "  ISO:        $(ls -lh ${ISO_PATH})"
echo "  Tar:        $(ls -lh ${UPGRADE_TAR})"
echo "  IoT bundle: $(ls -lh ${IOTUPDATE_BUNDLE})"

# ── Copy ISO to Proxmox ISO storage ──────────────────────────────────────────
LOCAL_ISO_COPY="${RELEASES_DIR}/inferno-appliance-${VERSION}.iso"
cp "${ISO_PATH}" "${LOCAL_ISO_COPY}"
echo ""
echo "ISO kept locally: ${LOCAL_ISO_COPY}"

ISO_DEST="${PROXMOX_ISO_DIR}/inferno-appliance-${VERSION}.iso"
if [[ -n "${PROXMOX_ISO_HOST}" ]]; then
  echo "Copying ISO to ${PROXMOX_ISO_HOST}:${ISO_DEST} ..."
  scp -i "${PROXMOX_SSH_KEY}" -o StrictHostKeyChecking=no \
    "${LOCAL_ISO_COPY}" "${PROXMOX_ISO_HOST}:${ISO_DEST}"
  echo "ISO available in Proxmox: ${ISO_DEST}"
else
  # Running directly on a Proxmox host — symlink as before
  ln -sf "${ISO_PATH}" "${ISO_DEST}"
  echo "Symlinked: ${ISO_DEST} → ${ISO_PATH}"
fi

echo ""
echo "=== Build complete at $(date) ==="
echo "  ISO (build VM): ${LOCAL_ISO_COPY}"
echo "  ISO (Proxmox):  ${PROXMOX_ISO_HOST}:${PROXMOX_ISO_DIR}/inferno-appliance-${VERSION}.iso"
echo "  Upgrade tar:    ${UPGRADE_TAR}  (raw, for streaming upgrades)"
echo "  IoT bundle:     ${IOTUPDATE_BUNDLE}  (upload via Cockpit IoT Updater UI)"
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
