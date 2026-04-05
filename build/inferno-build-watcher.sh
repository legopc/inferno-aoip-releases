#!/bin/bash
# inferno-build-watcher.sh — Polls GitHub for new versions and auto-triggers builds
#
# Run via systemd timer (every 30 minutes) on COPILOT-BUILD-01.
# Checks two triggers:
#   1. New v* tag in legopc/inferno-aoip-releases repo  → named release build
#   2. New nightly-YYYY-MM-DD binary release from CI     → nightly appliance build
#
# New release workflow:
#   Push a git tag to trigger an auto-build:
#     git tag v12 && git push origin v12
#   Build VM detects the tag within 30 minutes and starts the build automatically.
#
# State files (in BUILD_DIR):
#   last-built-tag     → last vN tag that was built
#   last-built-nightly → last nightly-YYYY-MM-DD that was built

set -euo pipefail

# Source build environment config
[[ -f /etc/inferno-build.env ]] && source /etc/inferno-build.env

BUILD_DIR="${BUILD_DIR:-/opt/inferno-build}"
REPO="legopc/inferno-aoip-releases"
LOG="${BUILD_DIR}/watcher.log"

log() { echo "[$(date -u '+%Y-%m-%dT%H:%M:%SZ')] $*" | tee -a "$LOG"; }

log "=== inferno-build-watcher starting ==="

# ── Helper: get latest v* git tag from repo ───────────────────────────────────
get_latest_vtag() {
    curl -fsSL \
        -H "Accept: application/vnd.github+json" \
        "https://api.github.com/repos/${REPO}/tags" 2>/dev/null \
    | python3 -c "
import json, sys, re
tags = json.load(sys.stdin)
vtags = [t['name'] for t in tags if re.match(r'^v\d+$', t['name'])]
vtags.sort(key=lambda x: int(x[1:]))
print(vtags[-1] if vtags else '')
"
}

# ── Helper: get latest GitHub release tag ────────────────────────────────────
get_latest_release_tag() {
    curl -fsSL \
        -H "Accept: application/vnd.github+json" \
        "https://api.github.com/repos/${REPO}/releases/latest" 2>/dev/null \
    | python3 -c "import json,sys; print(json.load(sys.stdin).get('tag_name',''))"
}

# ── Helper: launch a build via systemd-run ────────────────────────────────────
launch_build() {
    local version="$1"
    local description="$2"
    local unit="inferno-build-${version}"
    local build_log="${BUILD_DIR}/build-${version}.log"

    if systemctl is-active --quiet "$unit" 2>/dev/null; then
        log "Build ${version} already running — skipping."
        return 0
    fi
    if [[ -f "${build_log}" ]] && grep -q "BUILD_EXIT:0" "${build_log}" 2>/dev/null; then
        log "Build ${version} already succeeded — skipping."
        return 0
    fi

    log "Launching build: ${version} — ${description}"
    systemctl reset-failed "$unit" 2>/dev/null || true
    mkdir -p /run/containers/storage

    cd "${BUILD_DIR}/inferno-aoip-releases"
    git pull --quiet

    systemd-run \
        --unit="$unit" \
        --description="Inferno AoIP auto-build ${version}" \
        --property="StandardOutput=append:${build_log}" \
        --property="StandardError=append:${build_log}" \
        --setenv="BUILD_DIR=${BUILD_DIR}" \
        --setenv="PROXMOX_ISO_HOST=${PROXMOX_ISO_HOST:-root@10.10.1.202}" \
        --setenv="PROXMOX_ISO_DIR=${PROXMOX_ISO_DIR:-/var/lib/vz/template/iso}" \
        --setenv="PROXMOX_SSH_KEY=${PROXMOX_SSH_KEY:-/root/.ssh/inferno_proxmox}" \
        "${BUILD_DIR}/inferno-aoip-releases/build/build-release.sh" \
        "$version" "$description"

    log "Build unit '${unit}' started. Log: ${build_log}"
}

# ── Trigger 1: New v* tag in repo ────────────────────────────────────────────
LAST_TAG_FILE="${BUILD_DIR}/last-built-tag"
LAST_TAG=$(cat "$LAST_TAG_FILE" 2>/dev/null || echo "")
LATEST_TAG=$(get_latest_vtag)

log "Latest v-tag in repo: '${LATEST_TAG}' | Last built: '${LAST_TAG}'"

if [[ -n "$LATEST_TAG" && "$LATEST_TAG" != "$LAST_TAG" ]]; then
    log "New release tag detected: ${LATEST_TAG}"
    launch_build "$LATEST_TAG" "Auto-build: new release tag ${LATEST_TAG}"
    echo "$LATEST_TAG" > "$LAST_TAG_FILE"
fi

# ── Trigger 2: New nightly binary release ────────────────────────────────────
LAST_NIGHTLY_FILE="${BUILD_DIR}/last-built-nightly"
LAST_NIGHTLY=$(cat "$LAST_NIGHTLY_FILE" 2>/dev/null || echo "")
LATEST_RELEASE=$(get_latest_release_tag)

log "Latest GitHub release: '${LATEST_RELEASE}' | Last built nightly: '${LAST_NIGHTLY}'"

if [[ "$LATEST_RELEASE" == nightly-* && "$LATEST_RELEASE" != "$LAST_NIGHTLY" ]]; then
    log "New nightly binary detected: ${LATEST_RELEASE}"
    launch_build "$LATEST_RELEASE" "Auto-build: new nightly binaries ${LATEST_RELEASE}"
    echo "$LATEST_RELEASE" > "$LAST_NIGHTLY_FILE"
fi

log "=== inferno-build-watcher done ==="
