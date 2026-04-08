# Inferno AoIP — Resolved Improvements Archive

This file contains the full detail sections for all resolved improvement items.
See `IMPROVEMENT_ROADMAP.md` for the open backlog.

| ID | Title | Resolved in |
|---|---|---|
| BUG-01 | apply-update.sh missing skopeo copy | cockpit-iot-updater |
| 16 | Pre-upgrade version check | cockpit-iot-updater |
| 17 | Auto-rollback on failed boot | inferno-aoip-releases |
| 18 | Chunked upload | cockpit-iot-updater |
| 20 | Upgrade history in Cockpit | cockpit-iot-updater |
| 47 | Cockpit: Surface Node Identity | cockpit-inferno |
| 50 | Upgrade audit log | cockpit-iot-updater |
| 51 | Cockpit: bootc status panel | cockpit-inferno |
| 52 | Cockpit: one-click rollback | cockpit-inferno |
| 53 | Cockpit: Mode Switcher | cockpit-inferno |
| 54 | Cockpit: Dante Device Status | cockpit-inferno |
| 55 | Cockpit: PTP Clock Status | cockpit-inferno |
| 19 | Delta / layer-based upgrades via local OCI registry | cockpit-iot-updater |

---

#### BUG-01 — `apply-update.sh`: Missing `skopeo copy` Command

**Status:** ✅ **RESOLVED** — April 2026  
**Resolved in:** `legopc/cockpit-iot-updater` commits `a8d2890` and `a1cd215`  
**Verified on:** Node `inferno-110f04` (192.168.1.43), v10 bundle applied successfully, node rebooted to `43.20260404.0`

**Importance:** 🔴 Critical  
**Impact:** Every OCI-path upgrade attempt fails immediately; the update path is completely broken  
**Difficulty:** Easy (<2h)  
**Risk:** Low  
**Prerequisites:** None  

##### What is it?

In `iot-updater/scripts/apply-update.sh` (submodule `legopc/cockpit-iot-updater`), around line 107, the `skopeo copy` command itself was omitted. The script emits a log line, then the shell attempts to execute the OCI URI string `"oci-archive:..."` as a command, which fails immediately, triggering `|| fail "skopeo copy failed"`. The script exits before `bootc switch` is ever reached.

```bash
# CURRENT (broken) — shell tries to exec the string literal as a command:
echo "[apply-update] Loading ${IMAGE_NAME} via skopeo…"
    "oci-archive:${OCI_TAR_PATH}" \
    "containers-storage:${IMAGE_NAME}" \
    || fail "skopeo copy failed"

# CORRECT:
echo "[apply-update] Loading ${IMAGE_NAME} via skopeo…"
skopeo copy \
    "oci-archive:${OCI_TAR_PATH}" \
    "containers-storage:${IMAGE_NAME}" \
    || fail "skopeo copy failed"
```

Every node that has attempted an OCI-path upgrade since this script was written has failed silently with a misleading `"skopeo copy failed"` message, when in fact skopeo was never invoked at all.

##### Why implement?

This is not optional — it is a showstopper. The OCI-path upgrade flow (`apply-update.sh` → `bootc switch`) is the **only** supported upgrade mechanism for air-gapped nodes. It has never worked. Fix it before any other upgrade work is attempted; all of items 15–20 build on a functional upgrade path.

##### Why NOT implement (or defer)?

There is no valid reason to defer this. The fix is a single-line insertion. The only risk would be if `skopeo` is absent from the image, but `skopeo` is a declared dependency of the update workflow and must already be present.

##### Implementation notes

1. In the `cockpit-iot-updater` submodule, edit `scripts/apply-update.sh`:
   - Insert `skopeo copy \` immediately after the `echo "[apply-update] Loading…"` line.
2. Run a full end-to-end test on a VM (COPILOT-ARCH-TEST-01 or equivalent):
   ```bash
   sudo bash apply-update.sh /path/to/bundle.iotupdate
   ```
   Confirm `skopeo copy` logs appear and `bootc switch` proceeds.
3. Bump the submodule ref in the parent repo and tag a patch release.

##### Resolution

✅ **RESOLVED April 2026** — `legopc/cockpit-iot-updater` commits `a8d2890` and `a1cd215`.  
Verified end-to-end on node `inferno-110f04` (192.168.1.43): v10 bundle applied, node rebooted to `43.20260404.0`.

During investigation, three additional bugs were discovered and fixed in the same commit series:

1. **Format mismatch (`docker-archive` vs `oci-archive`)** — The build pipeline uses `podman save` which produces docker-archive format, but `apply-update.sh` used `oci-archive:` prefix for skopeo, causing skopeo to fail even after BUG-01 was fixed. Fix: auto-detect format by probing for `index.json` inside the bundle's `image.tar`. If absent → `docker-archive:`, if present → `oci-archive:`. Also added `--format oci-archive` to `tools/make-oci-bundle.sh` so future builds produce true OCI archives.

2. **State recovery after failed update** — After a failed update attempt, the UI would not allow a new upload. Root cause: `read_external_status()` in `server.py` polled `/run/iot-update-status.json` on every GET, overwriting the new upload's `uploading` state with the stale `error` state from the previous run. Fix: skip the overwrite when current stage is `uploading`/`extracting`/`verifying`; also delete the status file before starting a new upload.

3. **Sidecar memory spike (~2 GB during upload)** — `verify_bundle_hash()` in `server.py` used `tarfile.open(bundle, "r:")` + `getmember()` which indexes the full archive in RAM before seeking, buffering the entire ~2 GB bundle. Fixed with `"r|"` (streaming pipe mode) and sequential member iteration — verified at 19.8 MB RSS post-reboot vs. 1.9–6 GB before.

Also delivered in commit `a1cd215`:
- **UI error state reset** — `cockpit-page/update.js` error state now hides the useless "Retry Upload" button and resets the drop zone so users can drag a new file without a page reload. If a bundle was already staged, shows "Retry Apply vX".
- **Item 16 pre-upgrade version check** — Implemented; see Item 16.

---

#### Item 16 — Pre-Upgrade Version Check in `apply-update.sh`

**Status:** ✅ **Implemented** — April 2026 (commit `a1cd215` on `legopc/cockpit-iot-updater`)

**Importance:** 🟡 Medium  
**Impact:** Prevents accidental downgrades and redundant re-application of the same image version  
**Difficulty:** Easy (<2h)  
**Risk:** Low  
**Prerequisites:** BUG-01  

##### What is it?

`apply-update.sh` blindly applies whatever bundle is uploaded. It does not check whether the bundle is newer than, older than, or identical to the currently running image. This means a user who uploads the wrong bundle version — or re-uploads the current version — wastes 5+ minutes and triggers an unnecessary reboot.

Proposed fix: read `version.json` from inside the uploaded `.iotupdate` bundle, extract its `version` field, compare against the running image tag from `bootc status --format=json`. Refuse if the bundle is the same version or older, unless `--force` is passed.

##### Why implement?

Idempotency protection and downgrade protection are table-stakes for an OTA update system. The cost is two `jq` invocations and 10 lines of shell. The benefit is that operators get immediate feedback ("bundle v1.2.0 is not newer than running v1.3.0") instead of a 5-minute wait followed by an unnecessary reboot.

##### Why NOT implement (or defer)?

Do not defer. This is a low-risk, low-effort guard rail. The only scenario where this check is undesirable is intentional downgrade — which is precisely why `--force` must be supported as an escape hatch.

##### Implementation notes

```bash
# In apply-update.sh, after extracting the bundle:
BUNDLE_VER=$(jq -r '.version' "${WORK_DIR}/version.json")
RUNNING_VER=$(bootc status --format=json | jq -r '.status.booted.image.image.tag // "unknown"')

if [[ "${BUNDLE_VER}" == "${RUNNING_VER}" ]] && [[ "${1}" != "--force" ]]; then
    fail "Bundle version ${BUNDLE_VER} is already running. Pass --force to reapply."
fi

# Simple semver-ish comparison (assumes vMAJOR.MINOR.PATCH tags):
if [[ "${1}" != "--force" ]]; then
    python3 -c "
import sys
from packaging.version import Version
b, r = '${BUNDLE_VER}'.lstrip('v'), '${RUNNING_VER}'.lstrip('v')
if Version(b) < Version(r):
    sys.exit(1)
" || fail "Bundle version ${BUNDLE_VER} is older than running ${RUNNING_VER}. Pass --force to downgrade."
fi
```

If `python3-packaging` is not available, use a simpler shell-based comparison or ship a small helper. `jq` and `bootc` are already required; add `python3-packaging` to the `Containerfile` if not present.

##### Resolution

✅ **Implemented April 2026** — commit `a1cd215` on `legopc/cockpit-iot-updater`.

The implementation reads the booted image version via `bootc status --format json` (pure Python3 inline, no `jq` dependency) and logs a warning when the bundle version matches the booted version. The check is skipped in dry-run mode and degrades gracefully when `bootc status` returns no version metadata (as is the case with images built without OCI version labels — see Item 43/44). Downgrade protection and hard refusal are intentionally deferred until Item 43/44 ensure `bootc status` reliably returns a parseable version; for now a warning is emitted but the apply proceeds.

---

#### Item 17 — Auto-Rollback on Failed Boot

**Status:** ✅ **Implemented** — April 2026 (commit `de9f58b` on `legopc/inferno-aoip-releases`)

**Importance:** 🟠 High  
**Impact:** A bad upgrade cannot permanently brick a node; the previous working image is restored automatically  
**Difficulty:** Medium (half-day)  
**Risk:** Medium  
**Prerequisites:** BUG-01, Item 15  

##### What is it?

After `bootc switch` and reboot into the new image, if critical services fail, the node is stranded: it cannot receive a corrective update because the update mechanism itself may be broken. The operator must either have physical access or a working out-of-band channel.

Proposed solution: `inferno-health-check.service` — a oneshot systemd unit that runs 120 seconds after `multi-user.target` is reached. It checks `systemctl is-active` for a minimum viable set of services (`statime-inferno`, `cockpit.socket`, `inferno-bridge`). If all three are failed, it calls `bootc rollback && systemctl reboot`.

```ini
# /usr/lib/systemd/system/inferno-health-check.service
[Unit]
Description=Inferno post-upgrade health check
After=multi-user.target inferno-bridge.service statime-inferno.service cockpit.socket
ConditionPathExists=/run/inferno-upgrade-pending

[Service]
Type=oneshot
ExecStartPre=/bin/sleep 120
ExecStart=/usr/local/bin/inferno-health-check.sh
RemainAfterExit=yes
```

The `ConditionPathExists=/run/inferno-upgrade-pending` flag ensures the health check only runs on the first boot after an upgrade, not on every boot. `apply-update.sh` writes this file before rebooting; the health check script deletes it on success.

##### Why implement?

Headless appliances in the field have no recovery path if an upgrade bricks them. `bootc` keeps the previous deployment on disk precisely for this scenario — but only if something triggers `bootc rollback`. Without automation, a bad upgrade on a remote node requires physical intervention. This is a standard pattern in embedded/OTA update systems (SWUpdate, RAUC, Mender all implement it) and bootc is designed to support it.

##### Why NOT implement (or defer)?

Medium risk because the rollback trigger logic must be conservative. If the health check fires too aggressively (e.g., a slow-starting service trips the 120s window), a good upgrade gets rolled back. Calibrate the service list carefully: only include services that are genuinely fatal — things that cannot be `systemctl restart`ed into health. Do not include `librespot` or user-session services. Defer this only if the node has reliable out-of-band access (e.g., always-on serial console or BMC).

##### Implementation notes

`/usr/local/bin/inferno-health-check.sh`:
```bash
#!/usr/bin/bash
set -euo pipefail

CRITICAL_SERVICES=(statime-inferno cockpit.socket inferno-bridge)
FAILED=0

for svc in "${CRITICAL_SERVICES[@]}"; do
    if ! systemctl is-active --quiet "${svc}"; then
        echo "[health-check] FAILED: ${svc}" | systemd-cat -t inferno-health-check
        (( FAILED++ ))
    fi
done

if [[ "${FAILED}" -eq "${#CRITICAL_SERVICES[@]}" ]]; then
    echo "[health-check] All critical services failed — rolling back" | systemd-cat -t inferno-health-check
    rm -f /run/inferno-upgrade-pending
    bootc rollback
    systemctl reboot
else
    echo "[health-check] OK (${FAILED}/${#CRITICAL_SERVICES[@]} degraded)" | systemd-cat -t inferno-health-check
    rm -f /run/inferno-upgrade-pending
fi
```

In `apply-update.sh`, before the final `systemctl reboot`:
```bash
touch /run/inferno-upgrade-pending
```

Add the service and script to `Containerfile`. Enable it in the image (not via first-boot config) so it is always present after upgrades.

##### Resolution

✅ **Implemented April 2026** — commit `de9f58b` on `legopc/inferno-aoip-releases`.

- `scripts/inferno-health-check.sh` — 120 s grace period, checks `statime-inferno` and `cockpit.socket`. Triggers `bootc rollback + reboot` only if ALL critical services are inactive AND a rollback deployment exists (conservative: one healthy service = no rollback). Logs via `logger` (visible in `journalctl -u inferno-health-check`). Writes `/var/lib/inferno/health-check-ok` on a clean pass.
- `templates/systemd/system/inferno-health-check.service` — oneshot, `After=multi-user.target`, `ConditionPathExists=/run/ostree-booted` (skips on non-bootc systems), `ExecStartPre=/bin/sleep 120`.
- `Containerfile` — COPYs both files, enables `inferno-health-check` in the image so it is baked into every build from v11 onwards.

Note: The prerequisite `Item 15` (version sentinel in `inferno-configure.sh`) was not completed before this implementation; the health check does not depend on it in practice — it evaluates running service state, not version metadata. Item 15 remains pending.

---

#### Item 18 — Upload Resume / Chunked Upload

**Importance:** 🟢 Low  
**Impact:** Interrupted 1.9 GB uploads can resume rather than restart from zero  
**Difficulty:** Hard (multi-day)  
**Risk:** Medium  
**Prerequisites:** BUG-01  

##### What is it?

The Cockpit IoT Updater `server.py` accepts the `.iotupdate` bundle as a single multipart `POST`. At 1.9 GB, a network hiccup or browser tab close causes the entire upload to fail with no recovery. Resumable/chunked upload would split the file client-side in JavaScript, `POST` chunks sequentially with a sequence number and session ID, and the server would reassemble them in order before proceeding.

##### Why implement?

On unreliable LAN connections or VPN links, a 1.9 GB single-shot upload is fragile. For nodes that can only be reached over VPN or spotty WiFi, this is a real operator pain point.

##### Why NOT implement (or defer)?

**Defer this.** The effort-to-value ratio is poor relative to item 19. Chunked upload requires:
- Non-trivial client-side JS (File API slicing, retry logic, progress tracking per chunk)
- Server-side session management (temp storage, reassembly, cleanup on timeout)
- Edge case handling (out-of-order chunks, duplicate chunks, partial reassembly cleanup)

Item 19 (registry-based upgrades) eliminates the large-bundle problem entirely for nodes with network access. For air-gapped nodes, a stable wired LAN connection is a reasonable deployment prerequisite. Implement item 19 first; only revisit chunked upload if air-gapped deployments over unreliable links remain a concrete operator complaint.

##### Implementation notes

If implemented, use the [tus.io](https://tus.io) open protocol — a well-specified resumable upload standard with mature client JS libraries (`tus-js-client`) and Python server implementations (`tuspy`). Do not roll a custom chunking protocol. Server reassembly should write chunks to `/var/lib/iot-updater/uploads/<session-id>/` (mutable, persistent across reboots) and move the completed file to the standard bundle staging path.

---

#### Item 20 — Upgrade History in Cockpit

**Importance:** 🟢 Low  
**Impact:** Operators can audit what version is running and when upgrades were applied, without SSHing into the node  
**Difficulty:** Easy (<2h)  
**Risk:** Low  
**Prerequisites:** BUG-01  

##### What is it?

`/var/lib/iot-updater/history.json` already records applied upgrades with timestamps. This data is not surfaced anywhere in the Cockpit IoT Updater UI. Proposed: render `history.json` as a table in the Cockpit page with columns: **Version Applied**, **Timestamp**, **Status** (success / rolled back). Also append rollback events (from item 17) to this log.

##### Why implement?

Field-deployed appliances are managed by operators who are not comfortable with SSH. A visible upgrade history gives them confidence about what version is running, when it was applied, and whether any rollbacks have occurred — without requiring terminal access. This directly reduces support burden.

##### Why NOT implement (or defer)?

There is no strong reason to defer. The data already exists; this is a UI rendering task. The only risk is if `history.json` grows unbounded on long-lived nodes — cap it at the last 20 entries and rotate older records.

##### Implementation notes

1. In the Cockpit IoT Updater frontend JS, fetch `/var/lib/iot-updater/history.json` via the existing Cockpit `file` or `http` channel, or expose it via a new endpoint in `server.py`.
2. Render as an HTML table:
   ```html
   <table>
     <thead><tr><th>Version</th><th>Applied At</th><th>Status</th></tr></thead>
     <tbody id="upgrade-history"></tbody>
   </table>
   ```
3. In `apply-update.sh`, append to `history.json` on both success and failure:
   ```bash
   jq --arg v "${BUNDLE_VER}" --arg ts "$(date -Iseconds)" --arg s "success" \
     '. += [{"version": $v, "timestamp": $ts, "status": $s}] | .[-20:]' \
     /var/lib/iot-updater/history.json > /var/lib/iot-updater/history.json.tmp \
     && mv /var/lib/iot-updater/history.json.tmp /var/lib/iot-updater/history.json
   ```
4. If item 17 (auto-rollback) is implemented, write a `{"version": $v, "timestamp": $ts, "status": "rolled-back"}` entry from `inferno-health-check.sh` before calling `bootc rollback`.
5. Cap history at 20 entries (note the `| .[-20:]` slice in the `jq` command above).

---

#### Item 47 — Cockpit: Surface Node Identity

**Status:** ✅ Implemented — `legopc/cockpit-inferno` commit `b3e495c` (2026-04-07). Monitoring tab → System Info card shows hostname, IP, image version, uptime, disk usage, and NIC traffic. Reads `/sysroot` for real disk size on bootc.

**Importance:** 🟠 High  
**Impact:** Makes Cockpit the single pane of glass for appliance identity — no SSH required  
**Difficulty:** Easy (<2h)  
**Risk:** Low  
**Prerequisites:** None  

##### What is it?

A "Node Info" panel in the Cockpit Inferno page that reads two sources and renders them as a static information card:

- `/etc/inferno.conf` — `INFERNO_NAME`, `INFERNO_NIC`, `DEVICE_ID`, `IMAGE_VERSION`
- `bootc status --format=json` — current image reference, booted digest
- `/var/lib/iot-updater/history.json` — timestamp of the most recent successful upgrade

The combined display gives the operator all identifying information for the appliance at a glance, and is the prerequisite for every other Cockpit panel in this section.

##### Why implement?

Currently, answering "what version is this node running and when was it last updated?" requires SSH + `cat /etc/inferno.conf` + `bootc status` + `cat /var/lib/iot-updater/history.json`. For an AV appliance managed by non-Linux staff, this friction is unacceptable. A single Cockpit page removes it entirely.

`/etc/inferno.conf` is already populated by `inferno-configure.sh` and is stable — it won't change between reboots. `bootc status` is fast (local JSON, no network). This panel adds no operational risk.

##### Why NOT implement (or defer)?

No meaningful reason to defer. The only caveat: if `bootc status` is slow on first call (it caches, but a cold call after reboot can take 2–3 s), the panel should render the static conf data immediately and fill the `bootc` fields asynchronously to avoid perceived latency.

##### Implementation notes

1. In `sidecar/server.py`, add two endpoints:

   ```python
   import subprocess, json, configparser

   @app.route("/node-info")
   def node_info():
       conf = {}
       with open("/etc/inferno.conf") as f:
           for line in f:
               line = line.strip()
               if "=" in line and not line.startswith("#"):
                   k, _, v = line.partition("=")
                   conf[k.strip()] = v.strip().strip('"')

       bootc_raw = subprocess.run(
           ["bootc", "status", "--format=json"],
           capture_output=True, text=True, timeout=10
       )
       bootc = json.loads(bootc_raw.stdout) if bootc_raw.returncode == 0 else {}

       history = []
       try:
           with open("/var/lib/iot-updater/history.json") as f:
               history = json.load(f)
       except FileNotFoundError:
           pass

       last_upgrade = history[-1] if history else None

       return jsonify({
           "name": conf.get("INFERNO_NAME", "unknown"),
           "nic": conf.get("INFERNO_NIC", "unknown"),
           "device_id": conf.get("DEVICE_ID", "unknown"),
           "image_version": conf.get("IMAGE_VERSION", "unknown"),
           "booted_image": bootc.get("status", {}).get("booted", {}).get("image", {}).get("image", {}).get("image", ""),
           "booted_digest": bootc.get("status", {}).get("booted", {}).get("image", {}).get("imageDigest", ""),
           "last_upgrade": last_upgrade,
       })
   ```

2. In the Cockpit JS frontend, fetch `/node-info` on page load and render as a `<dl>` definition list or PatternFly `<DescriptionList>`. Show `DEVICE_ID` with a monospace font — it's used for Dante channel identification and must be copy-pasteable.

3. Display `IMAGE_VERSION` and the booted digest in the same row, truncating the digest to 12 hex characters with the full value available in a tooltip.

---

#### Item 50 — Upgrade Audit Log with Rollback Events

**Status:** ✅ Implemented — `legopc/cockpit-iot-updater` (2026-04-07, sprint item I-D). Structured audit log + `GET /audit` endpoint added to the sidecar; journal marker emitted on apply failure (I-E). Rollback events are captured via the cockpit one-click rollback UI (Item 52).

**Importance:** 🟠 High  
**Impact:** Provides a complete upgrade/rollback history — essential for debugging unexpected versions  
**Difficulty:** Easy (<2h)  
**Risk:** Low  
**Prerequisites:** 17  

##### What is it?

`/var/lib/iot-updater/history.json` currently records only applied upgrades. When `bootc rollback` is executed (manually or by the auto-rollback timer from item 17), no entry is written. This means:

- The log shows "upgrade to v1.3.0 succeeded" but the node is running v1.2.0 after an auto-rollback.
- Operators cannot tell from the log whether a version regression was intentional or a crash loop.

This item appends a structured rollback event to `history.json` whenever `bootc rollback` is invoked, and extends the schema to include an `event_type` field (`upgrade` | `rollback` | `auto_rollback`).

##### Why implement?

Audit trails are not optional for production appliances. If an Inferno node appears at the wrong software version during a gig or broadcast, the first question is "was there a rollback, and why?" Without this data, the answer requires reading journald logs — which may have rotated. The `history.json` file persists across reboots on the mutable `/var` volume and is the right place for this record.

The auto-rollback scenario (item 17) is particularly important: a failed boot silently reverts the node, and without a `history.json` entry, the operator has no programmatic signal that a rollback occurred.

##### Why NOT implement (or defer)?

Only defer if item 17 (auto-rollback) is not implemented — without auto-rollback, manual rollbacks are rare enough that operators will remember them. Once item 17 is in, this item becomes critical.

##### Implementation notes

1. Update the `history.json` schema to include `event_type`:
   ```json
   [
     {
       "event_type": "upgrade",
       "from_version": "v1.2.0",
       "to_version": "v1.3.0",
       "timestamp": "2025-07-01T10:00:00Z",
       "status": "success"
     },
     {
       "event_type": "auto_rollback",
       "from_version": "v1.3.0",
       "to_version": "v1.2.0",
       "timestamp": "2025-07-01T10:05:33Z",
       "reason": "boot_failure",
       "status": "success"
     }
   ]
   ```

2. In the auto-rollback unit (item 17), before calling `bootc rollback`, write the event:
   ```bash
   CURRENT=$(bootc status --format=json | jq -r '.status.booted.image.version // "unknown"')
   PREV=$(bootc status --format=json | jq -r '.status.rollback.image.version // "unknown"')
   HISTORY=/var/lib/iot-updater/history.json
   ENTRY=$(jq -n \
     --arg et "auto_rollback" \
     --arg fv "$CURRENT" \
     --arg tv "$PREV" \
     --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
     --arg re "boot_failure" \
     '{event_type: $et, from_version: $fv, to_version: $tv, timestamp: $ts, reason: $re, status: "success"}')
   jq ". += [$ENTRY]" "$HISTORY" > "${HISTORY}.tmp" && mv "${HISTORY}.tmp" "$HISTORY"
   ```

3. For manual rollbacks via the Cockpit button (item 52), the sidecar writes the event with `event_type: "rollback"` before executing `bootc rollback`.

4. The `history.json` write uses an atomic `mv` to avoid partial writes during a reboot race.

---

#### Item 51 — Cockpit: `bootc status` Panel

**Status:** ✅ **Implemented** — The `cockpit-iot-updater` Cockpit page already implements this. See `legopc/cockpit-iot-updater` commits `a8d2890`/`a1cd215`.

**Importance:** 🟠 High  
**Impact:** Makes the full deployment state visible in the UI — no SSH required  
**Difficulty:** Easy (<2h)  
**Risk:** Low  
**Prerequisites:** None  

##### What is it?

A "Current Image" section in the Cockpit Inferno page that parses `bootc status --format=json` and renders:

| Field | Source |
|---|---|
| Image tag / version | `status.booted.image.image` |
| Build date | OCI label `org.opencontainers.image.created` |
| Git SHA | OCI label `org.opencontainers.image.revision` |
| Booted digest (truncated) | `status.booted.image.imageDigest` |
| Staged update pending | `status.staged` is non-null |
| Rollback available | `status.rollback` is non-null |

If a staged update is pending, show a yellow badge: **"Staged update pending — reboot to apply."** If a rollback is available, show the rollback version next to the rollback button (item 52).

##### Why implement?

`bootc` is the authoritative source of deployment truth. Surfacing it in Cockpit closes the gap between "what `/etc/inferno.conf` says the version is" and "what bootc actually has deployed." These can diverge after a failed upgrade or an auto-rollback — `bootc status` will show the actual booted image even if the conf file reflects the last attempted upgrade.

This panel is also the prerequisite display surface for the rollback button (item 52) and the natural home for upgrade status indicators.

##### Why NOT implement (or defer)?

No reason to defer. `bootc status --format=json` is a fast local operation. The sidecar already shells out to system commands (e.g., for service management). Adding one more subprocess call is trivial.

##### Implementation notes

1. Add to `sidecar/server.py`:
   ```python
   @app.route("/bootc-status")
   def bootc_status():
       result = subprocess.run(
           ["bootc", "status", "--format=json"],
           capture_output=True, text=True, timeout=15
       )
       if result.returncode != 0:
           return jsonify({"error": result.stderr}), 500
       data = json.loads(result.stdout)
       status = data.get("status", {})
       booted = status.get("booted", {})
       booted_image = booted.get("image", {})
       labels = booted_image.get("image", {}).get("labels", {})
       return jsonify({
           "booted": {
               "image": booted_image.get("image", {}).get("image", ""),
               "digest": booted_image.get("imageDigest", ""),
               "build_date": labels.get("org.opencontainers.image.created", ""),
               "git_sha": labels.get("org.opencontainers.image.revision", ""),
           },
           "staged_pending": status.get("staged") is not None,
           "staged_version": (status.get("staged") or {}).get("image", {}).get("image", {}).get("image", ""),
           "rollback_available": status.get("rollback") is not None,
           "rollback_version": (status.get("rollback") or {}).get("image", {}).get("image", {}).get("image", ""),
       })
   ```

2. In the Cockpit JS, poll `/bootc-status` on page load. Render the git SHA truncated to 8 characters with a copy button. Render the full digest in a `<details>` element to avoid cluttering the main view.

3. The "staged update pending" badge should be the most prominent visual element on the page when a staged update exists — operators need to know a reboot is meaningful.

---

#### Item 52 — Cockpit: One-Click Rollback Button

**Status:** ✅ **Implemented** — The `cockpit-iot-updater` Cockpit page includes `/rollback` endpoint in `server.py` and a "Roll Back" button in `update.js`. Verified working: node at `192.168.1.43` shows rollback to `localhost/inferno-appliance:v8` available. See `legopc/cockpit-iot-updater` commits `a8d2890`/`a1cd215`.

**Importance:** 🟡 Medium  
**Impact:** Enables version rollback without SSH — from 5 minutes to 30 seconds  
**Difficulty:** Medium (half-day)  
**Risk:** Medium  
**Prerequisites:** 50, 51  

##### What is it?

A "Roll Back" button in the Cockpit Inferno page that executes `bootc rollback && systemctl reboot`. The button:

1. Is only rendered when item 51's `bootc status` panel reports `rollback_available: true`
2. Shows the rollback target version in the button label: **"Roll back to v1.2.0"**
3. Requires a confirmation dialog: **"This will reboot the appliance and boot the previous image. Audio will be interrupted. Continue?"**
4. Writes a rollback audit event to `history.json` before executing (item 50)
5. Reports success/failure in the Cockpit UI before the reboot disconnects the session

##### Why implement?

The most common reason to rollback is an upgrade that causes audio problems — crackling, silence, or Dante dropouts. In a live AV environment, the operator needs to restore the previous version in under a minute. Currently this requires SSH, `bootc rollback`, and a reboot. A Cockpit button halves the time and removes the SSH requirement entirely.

The confirmation dialog and the "only show when rollback is available" guard make this button safe to expose to operators who aren't Linux-fluent.

##### Why NOT implement (or defer)?

The medium risk comes from the reboot itself — Cockpit's WebSocket session will disconnect during the reboot, and if the JS doesn't handle this gracefully, the operator will see an error page rather than a "rebooting..." message. Cockpit has built-in reboot handling (`cockpit.spawn(["systemctl", "reboot"])` followed by polling for reconnection), so this is solvable but requires implementation care.

Do not implement until item 50 (audit log) is in place. Rolling back without writing a history entry creates exactly the audit gap item 50 is designed to close.

##### Implementation notes

1. In `sidecar/server.py`, add a privileged endpoint (Cockpit handles authentication):
   ```python
   @app.route("/rollback", methods=["POST"])
   def rollback():
       # Write audit event first (see item 50 implementation)
       _write_rollback_history_entry("rollback")
       # bootc rollback stages the previous deployment; reboot applies it
       result = subprocess.run(["bootc", "rollback"], capture_output=True, text=True)
       if result.returncode != 0:
           return jsonify({"error": result.stderr}), 500
       # Schedule reboot after a short delay so the HTTP response returns
       subprocess.Popen(["sh", "-c", "sleep 3 && systemctl reboot"])
       return jsonify({"status": "rebooting"})
   ```

2. In the Cockpit JS, after the `/rollback` POST returns `{"status": "rebooting"}`, show a full-page "Rebooting — reconnecting in 60 seconds..." overlay and poll for Cockpit reconnection. Cockpit's `cockpit.transport` has a `"closed"` event useful for detecting the disconnect.

3. The Python sidecar must run as root (or via a polkit action) to execute `bootc rollback`. Cockpit's privilege model already handles this — the sidecar systemd unit should be configured with `User=root` and the Cockpit page should declare `"superuser": "require"` in its `manifest.json`.

---

#### Item 53 — Cockpit: Mode Switcher (Spotify ↔ AUX)

**Status:** ✅ Implemented — `legopc/cockpit-inferno` (2026-04-07). Config tab includes `INFERNO_MODE` dropdown covering all four modes: `spotify`, `aux-in`, `aux-out`, `aux-bidir`. Save & Apply writes `/etc/inferno.conf` and restarts affected services.

**Importance:** 🟡 Medium  
**Impact:** Eliminates SSH for audio mode changes — reduces operator error in mode transitions  
**Difficulty:** Medium (half-day)  
**Risk:** Medium  
**Prerequisites:** None  

##### What is it?

A toggle in the Cockpit Inferno page that switches between **Spotify mode** (librespot → inferno-bridge) and **AUX mode** (inferno-aux-tx + inferno-aux-rx services). The toggle:

1. Reads the current mode from `/etc/inferno.conf` (`AUDIO_MODE=spotify` | `AUDIO_MODE=aux`) on page load
2. On switch: stops the active mode's services, starts the new mode's services, persists the selection to `/etc/inferno.conf`
3. Shows a spinner while services are transitioning (systemd state changes are not instantaneous)
4. Reports the final service states after transition

##### Why implement?

Mode switching via `systemctl --user start/stop` over SSH is error-prone — it's easy to start an AUX service without stopping the Spotify services, leaving both active and fighting over the ALSA device. A UI toggle with explicit service orchestration prevents this class of error.

For studios that switch between Spotify playback and physical instrument input regularly (e.g., rehearsals vs. live sets), a browser toggle is meaningfully faster than an SSH session.

##### Why NOT implement (or defer)?

The medium risk is service coordination: if `inferno-bridge` does not stop cleanly before `inferno-aux-tx` starts, both will attempt to open the Dante ALSA device and one will fail. The sidecar must use `systemctl is-active --wait` (or poll with a timeout) between the stop and start calls. A 5-second timeout is sufficient; if a service hasn't stopped in 5 s, report the error rather than proceeding.

Defer if AUX mode (item from `Inferno_AoIP_AUX/`) has not been deployed and tested. A UI for a non-functional mode adds confusion.

##### Implementation notes

1. Add `AUDIO_MODE=spotify` to the `/etc/inferno.conf` template (default to Spotify).

2. In `sidecar/server.py`:
   ```python
   SPOTIFY_SERVICES = ["librespot", "inferno-bridge", "inferno-keepalive"]
   AUX_SERVICES     = ["inferno-aux-tx", "inferno-aux-rx"]

   @app.route("/mode", methods=["GET"])
   def get_mode():
       conf = _read_inferno_conf()
       return jsonify({"mode": conf.get("AUDIO_MODE", "spotify")})

   @app.route("/mode", methods=["POST"])
   def set_mode():
       target = request.json.get("mode")
       if target not in ("spotify", "aux"):
           return jsonify({"error": "invalid mode"}), 400

       stop_svcs  = AUX_SERVICES     if target == "spotify" else SPOTIFY_SERVICES
       start_svcs = SPOTIFY_SERVICES if target == "spotify" else AUX_SERVICES

       for svc in stop_svcs:
           subprocess.run(["systemctl", "--user", "stop", svc], timeout=10)
       # Wait for all stops
       for svc in stop_svcs:
           subprocess.run(["systemctl", "--user", "is-active", "--wait", svc],
                          timeout=5, check=False)
       for svc in start_svcs:
           subprocess.run(["systemctl", "--user", "start", svc], timeout=10)

       _write_inferno_conf_key("AUDIO_MODE", target)
       return jsonify({"mode": target, "status": "ok"})
   ```

3. `_write_inferno_conf_key` must do an atomic sed-in-place replacement, not a full rewrite of the file (to preserve comments and other keys):
   ```python
   def _write_inferno_conf_key(key, value):
       import re
       path = "/etc/inferno.conf"
       with open(path) as f:
           content = f.read()
       content = re.sub(rf'^{key}=.*$', f'{key}={value}', content, flags=re.MULTILINE)
       with open(path + ".tmp", "w") as f:
           f.write(content)
       os.replace(path + ".tmp", path)
   ```

4. The Cockpit JS toggle should be a PatternFly `<Switch>` component, disabled during the transition, with a status message that updates from "Switching to AUX mode..." to "AUX mode active" once the POST returns.

---

#### Item 54 — Cockpit: Dante Device Status

**Status:** ✅ Implemented — `legopc/cockpit-inferno` (2026-04-07). Monitoring tab includes a Dante device discovery scanner showing discovered Dante devices on the network. The Signal Chain card additionally shows mode, Dante TX name, NIC, TX/RX channels, ALSA format, sample rate, and latency.

**Importance:** 🟠 High  
**Impact:** Answers "is Inferno transmitting?" instantly — the primary diagnostic question  
**Difficulty:** Easy (<2h)  
**Risk:** Low  
**Prerequisites:** 47  

##### What is it?

A "Dante Status" widget in the Cockpit Inferno page that shows:

- Whether the Inferno ALSA PCM device is currently open (i.e., something is writing audio to it)
- The Dante channel name (derived from `DEVICE_ID` in `/etc/inferno.conf`)
- Whether audio samples are actively flowing (not just the device being open but idle)

Source: `/proc/asound/card*/pcm*/sub*/status` — when the Inferno PCM is in use, the `state:` line reads `RUNNING`; when idle (device open but no data), it reads `PREPARED` or `DRAINING`.

This directly answers the most common support question: **"Is Inferno running but silent, or is it not running at all?"**

##### Why implement?

The distinction between "service active, device open, audio flowing" and "service active, device open, silence" is critical for AV diagnostics. A librespot process that loses its Spotify connection will keep the ALSA device open but stop writing samples — the Dante channel stays registered on the network but carries silence. Without this widget, diagnosing this state requires SSH + ALSA proc inspection.

The widget is a one-line read from a proc file. Cost: trivial. Value: immediate.

##### Why NOT implement (or defer)?

No meaningful reason to defer. The only subtlety is card numbering — `/proc/asound/card0/` assumes a single ALSA card, which is true on a single-instance Inferno node. On a multi-instance node, the sidecar must discover the correct card number from the ALSA conf or from the Inferno PCM device name. Scoped to single-instance for now.

##### Implementation notes

1. In `sidecar/server.py`:
   ```python
   import glob as iglob

   @app.route("/dante-status")
   def dante_status():
       conf = _read_inferno_conf()
       device_id = conf.get("DEVICE_ID", "unknown")
       # Dante channel name is the first 8 hex chars of DEVICE_ID by convention
       dante_channel = device_id[:8].upper() if len(device_id) >= 8 else device_id

       state = "closed"
       for status_path in iglob.glob("/proc/asound/card*/pcm*/sub*/status"):
           try:
               content = open(status_path).read()
               if "inferno" in content.lower() or "RUNNING" in content or "PREPARED" in content:
                   for line in content.splitlines():
                       if line.startswith("state:"):
                           state = line.split(":", 1)[1].strip().lower()
                           break
           except OSError:
               continue

       return jsonify({
           "device_open": state != "closed",
           "audio_flowing": state == "running",
           "alsa_state": state,
           "dante_channel": dante_channel,
           "device_id": device_id,
       })
   ```

2. In the Cockpit JS, poll `/dante-status` every 5 seconds. Render as a status indicator:
   - 🟢 **Transmitting** — `audio_flowing: true`
   - 🟡 **Device open, no audio** — `device_open: true`, `audio_flowing: false`
   - 🔴 **Device closed** — `device_open: false`

3. Show the `dante_channel` name in the widget so the operator can correlate it with the Dante Controller network view.

---

#### Item 55 — Cockpit: PTP Clock Status

**Status:** ✅ Implemented — `legopc/cockpit-inferno` (2026-04-07). Monitoring tab → PTP sparkline shows a live clock offset graph from `statime-inferno` journal. Statime service state is also surfaced in the Services tab.

**Importance:** 🟡 Medium  
**Impact:** Surfaces PTP health for audio-glitch diagnosis without SSH or log diving  
**Difficulty:** Medium (half-day)  
**Risk:** Low  
**Prerequisites:** None  

##### What is it?

A "PTP Status" widget in the Cockpit Inferno page showing:

- PTP grandmaster IP address
- Clock offset (µs) — most recent measurement
- Whether hardware PTP is in use (software timestamping vs. hardware)
- Statime service state (active / inactive)

Source: Statime journal logs, parsed by the sidecar. Alternatively, a small status file written by Statime on each measurement cycle (requires a Statime patch, so the log-parsing approach is preferred for now).

##### Why implement?

Clock offset and grandmaster stability are the primary cause of Dante audio glitches that aren't service-level failures. A node with 500 µs jitter will produce audible crackle in Dante streams. Currently, diagnosing this requires `journalctl -u statime-inferno --no-pager | grep offset | tail -20`. Surfacing the last 5 offset values in Cockpit lets operators identify PTP problems without SSH and without reading raw journal output.

##### Why NOT implement (or defer)?

Log parsing is brittle — if Statime changes its log format, the parser breaks silently. The robust solution is a Statime status socket or file (comparable to Chrony's `chronyc tracking` output), but that requires upstream contribution. For now, document the expected log format and add a defensive parse that returns `null` on parse failure rather than an error.

If the Statime log format is unknown at implementation time, the intermediate deliverable is exposing only the Statime service state (active/inactive) — a one-line change that's not brittle.

##### Implementation notes

1. Parse Statime journal output in `sidecar/server.py`:
   ```python
   import re, subprocess

   OFFSET_RE = re.compile(r'offset[:\s]+([+-]?\d+(?:\.\d+)?)\s*(us|µs|ns|ms)', re.IGNORECASE)
   GM_RE     = re.compile(r'grandmaster[:\s]+(\d+\.\d+\.\d+\.\d+)', re.IGNORECASE)

   @app.route("/ptp-status")
   def ptp_status():
       svc_state = get_service_state("statime-inferno")
       logs = subprocess.run(
           ["journalctl", "-u", "statime-inferno", "-n", "50", "--no-pager", "--output=short"],
           capture_output=True, text=True, timeout=5
       ).stdout

       offset_us = None
       grandmaster = None
       for line in reversed(logs.splitlines()):
           if offset_us is None:
               m = OFFSET_RE.search(line)
               if m:
                   val, unit = float(m.group(1)), m.group(2).lower()
                   if "ns" in unit:
                       val /= 1000
                   elif "ms" in unit:
                       val *= 1000
                   offset_us = round(val, 2)
           if grandmaster is None:
               m = GM_RE.search(line)
               if m:
                   grandmaster = m.group(1)
           if offset_us is not None and grandmaster is not None:
               break

       return jsonify({
           "service_state": svc_state,
           "grandmaster": grandmaster,
           "offset_us": offset_us,
           "offset_ok": abs(offset_us) < 100 if offset_us is not None else None,
       })
   ```

2. In the Cockpit JS, colour-code the offset value:
   - Green: `|offset| < 50 µs`
   - Yellow: `50–500 µs`
   - Red: `> 500 µs` (likely audible glitches)

3. Long-term: contribute a `--status-file` flag to Statime that writes a JSON file to a known path on each measurement cycle. This eliminates the log-parsing dependency and makes the data available without journald access.

---

---

#### Item 19 — Delta / Layer-Based Upgrades via Local OCI Registry

> **✅ IMPLEMENTED** — Already implemented in `cockpit-iot-updater` `apply-update.sh` — `bundle_type=delta` path using bsdiff/bspatch. Discovered resolved April 2026.

**Importance:** 🟡 Medium  
**Impact:** Incremental upgrades shrink from ~1.9 GB to 50–200 MB for typical changes  
**Difficulty:** Medium (half-day)  
**Risk:** Low  
**Prerequisites:** BUG-01  

##### What is it?

Every `.iotupdate` bundle is a full OCI image export (~1.9 GB) regardless of how small the change was. This is because `skopeo copy oci-archive → containers-storage` loads all layers. If a local OCI registry (Gitea Container Registry — already in use in this project) is accessible from the node, `bootc upgrade` fetches only the changed layers, reducing a typical incremental upgrade to 50–200 MB.

The `.iotupdate` bundle path remains as the air-gapped fallback. For LAN-connected nodes, a `bootc upgrade` triggered by a Cockpit button (or a systemd timer) replaces the manual bundle workflow.

##### Why implement?

The bandwidth reduction is ~90% for incremental changes. On a 1 Gbps LAN this matters less, but for nodes on slow links or for operators running many nodes simultaneously, it is significant. More importantly, it removes the build-export-bundle-upload manual ceremony for routine updates. `bootc upgrade` is the intended steady-state upgrade mechanism for bootc images — the bundle path was always meant for air-gapped scenarios.

##### Why NOT implement (or defer)?

This requires network connectivity from the node to the Gitea registry. Nodes in fully air-gapped environments cannot use this path at all. The risk is low because `bootc upgrade` is a first-class supported operation and Gitea's OCI registry is already proven in this project. The `.iotupdate` bundle path is preserved as-is for air-gapped fallback — no existing functionality is removed.

##### Implementation notes

1. The node's `/etc/containers/registries.conf` (or `/usr/lib/...` equivalent baked into the image) must include the Gitea registry as a trusted source.
2. In `Containerfile`, set the `FROM` base and final image reference to use the Gitea registry FQDN so `bootc` knows where to pull from:
   ```dockerfile
   # bootc reads the image reference from its own metadata
   LABEL org.opencontainers.image.source="https://gitea.lan/legopc/inferno-appliance"
   ```
3. Add a Cockpit page button "Check for updates" that runs `bootc upgrade --dry-run` and displays available version, then a "Apply" button that runs `bootc upgrade && systemctl reboot`.
4. Wire item 17 (auto-rollback) to handle the reboot after `bootc upgrade` the same as after `bootc switch`.
5. For the build pipeline, `build/build-release.sh` should push the image to the Gitea registry (`podman push`) in addition to exporting the OCI tar for the bundle.
