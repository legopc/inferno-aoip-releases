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


---

## Newly Archived (April 2026 — Sprint 5 cleanup)

#### BUG-08 — `apply-update.sh` Uses `eval` with Python Heredoc for JSON Parsing

> ✅ **Implemented** — Sprint 4, commit `5d360c2` (`inferno-aoip-releases`) Replace eval heredoc with individual python3 -c calls

**Importance:** 🟠 High  
**Impact:** Eliminates potential code injection vector in the OTA update path  
**Difficulty:** Medium (half-day)  
**Risk:** Medium  
**Prerequisites:** None  

##### What is it?

`iot-updater/scripts/apply-update.sh` uses `eval "$(python3 - <<'PYEOF' ... PYEOF)"` at multiple points (lines ~46, ~69, ~125, ~157, ~193) to extract values from `version.json`. While the heredoc quoting prevents most injection, using `eval` on Python subprocess output is an unnecessary risk surface in the security-critical update path.

##### Why implement?

If `version.json` is tampered with (compromised OTA bundle, MITM on an unsigned bundle), the eval construct could execute arbitrary shell commands. The current SHA256 verification mitigates this, but defence-in-depth requires eliminating the eval pattern entirely. Replacing with `jq` or direct `python3 -c` with explicit field extraction removes the attack vector.

##### Why NOT implement (or defer)?

Currently mitigated by bundle SHA256 verification — risk requires both bundle signature bypass AND a malicious `version.json`. Medium risk, not immediate danger. However, the eval pattern should not remain in security-sensitive scripts long-term.

##### Implementation notes

Add `jq` to Containerfile packages. Replace each `eval "$(python3 - <<'PYEOF'...)"` block with:

```bash
# Before (unsafe pattern):
eval "$(python3 - <<'PYEOF'
import json, sys
d = json.load(open('version.json'))
print(f"VERSION={d['version']}")
PYEOF
)"

# After (safe pattern):
VERSION=$(jq -r '.version' version.json)
# or without jq:
VERSION=$(python3 -c "import json; print(json.load(open('version.json'))['version'])")
```

Affects `apply-update.sh` lines ~46, ~69, ~125, ~157, ~193. Each block extracts a different field — convert each to a targeted `jq -r` call.

---


---

---

#### Item 1 — Add Kickstart to BIB `config.toml`

> ✅ **Implemented** — Sprint 6, commit pending (`inferno-aoip-releases`)

**Importance:** 🟡 Medium
**Impact:** Eliminates all interactive Anaconda prompts; enables fully unattended install from a single ISO boot
**Difficulty:** Easy
**Risk:** Low
**Prerequisites:** None

> **Implementation note:** Priority demoted from Critical to Medium — already fully unattended via BIB. Risk of Fedora wiping wrong disk on multi-disk hardware. Implement Item 7 (`%pre` disk detection script) before this. No manual install interaction is currently required.

##### What is it?

BIB supports embedding a kickstart file directly into the installer ISO via the `[[customizations.installer.kickstart]]` stanza in `build/config.toml`. Without this, Anaconda pauses at disk selection, timezone, and root password prompts. Adding a kickstart bakes complete answers into the ISO so the install proceeds without any operator interaction.

##### Why implement?

This is the foundational item for the entire one-shot provisioning story. Every other item in this section either depends on it or is made significantly easier by it. Without a kickstart, the Inferno ISO cannot be considered an appliance installer — it's just a Fedora installer that happens to include the Inferno image. A single `config.toml` addition turns it into a true walk-away installer.

##### Why NOT implement (or defer)?

There is no good reason to defer this. The only scenario where interactive install is preferable is during initial development on a new hardware platform where you're not yet sure about disk layout — but even then, a minimal kickstart with disk detection (Items 2 and 7) is better than no kickstart.

##### Implementation notes

Edit `build/config.toml`:

```toml
[customizations]

[[customizations.installer.kickstart]]
contents = """
lang en_US.UTF-8
keyboard us
timezone UTC --utc
rootpw --lock
user --name=core --groups=wheel --password=inferno123 --plaintext
clearpart --all --initlabel --disklabel=gpt
autopart --type=plain
bootloader --timeout=1
services --enabled=inferno-configure
reboot --eject

%packages
@^minimal-environment
%end
"""
```

Key decisions: `rootpw --lock` disables root login; `reboot --eject` prevents re-install loop; `autopart --type=plain` avoids unnecessary LVM; `timezone UTC` is correct for appliances.

---

---

#### Item 3 — Boot Timeout = 3s

> ✅ **Implemented** — Sprint 1, commit `3aa6e1a` (`inferno-aoip-releases`)

**Importance:** �� Medium
**Impact:** Reduces install time by 2 seconds; eliminates the GRUB pause on headless hardware
**Difficulty:** Easy
**Risk:** Low
**Prerequisites:** 1

> **Implementation note:** Timeout = **3s** (not 1s as previously written). This preserves a usable rescue window while still being fast for headless appliances.

##### What is it?

Fedora's default GRUB timeout is 5 seconds. For a headless appliance install where no one is watching the screen, this is dead time.

##### Why implement?

On a machine with no monitor, the 5-second pause is invisible but still burns time. Setting to 3s (not 0 — that removes all ability to interrupt for rescue mode, and not 1s which is too short for reliable rescue) is the correct appliance default.

##### Why NOT implement (or defer)?

No meaningful reason to defer. One-line addition to the kickstart.

##### Implementation notes

Add to kickstart in `build/config.toml`: `bootloader --timeout=3 --location=mbr`

---

---

#### Item 6 — `multi-user.target` as Default

> ✅ **Implemented** — Sprint 1, commit `3aa6e1a` (`inferno-aoip-releases`)

**Importance:** 🟠 High
**Impact:** Eliminates display manager and X11/Wayland init on a headless appliance; reduces boot time and attack surface
**Difficulty:** Easy
**Risk:** Low
**Prerequisites:** None

##### What is it?

Fedora defaults to `graphical.target` which starts GDM even when no display is present. One Containerfile line fixes this permanently.

##### Why implement?

GDM on a headless machine consumes 30–60 MB RAM, adds 2–5 seconds to boot, and may spawn PipeWire/PulseAudio session daemons that grab the ALSA device before `inferno-bridge.service` starts — causing a non-obvious audio device conflict. This is independent of the kickstart work and can be done right now.

##### Why NOT implement (or defer)?

Do not defer. `systemctl isolate graphical.target` still works at runtime if a display is ever needed for debugging. The default does not prevent using a display.

##### Implementation notes

In `Containerfile`:

```dockerfile
RUN dnf remove -y gdm && systemctl set-default multi-user.target
```

Verify: `podman run --rm <image> systemctl get-default` → should output `multi-user.target`.

---

---

#### Item 7 — Kickstart `%pre` Disk Detection Script

> ✅ **Implemented** — Sprint 6, commit pending (`inferno-aoip-releases`)

**Importance:** 🟠 High
**Impact:** Makes disk targeting fully automatic and safe on multi-disk hardware without destroying non-target disks
**Difficulty:** Medium
**Risk:** Medium
**Prerequisites:** 1

##### What is it?

A `%pre` kickstart script runs before partitioning. It enumerates block devices in `/sys/class/block/`, selects the largest one, and writes the target to a `%include` file that `clearpart --drives=` picks up. Only the identified disk is wiped.

##### Why implement?

Item 2's `clearpart --all` destroys everything on a multi-disk machine. `%pre` detection is the professional-grade solution — it's targeted and auditable.

##### Why NOT implement (or defer)?

Implement this instead of Item 2 if any of your target hardware has multiple disks. If hardware is 100% known single-disk, Item 2 is simpler. `%pre` scripting has its own pitfalls (minimal busybox environment, cryptic Anaconda failures on error). Test in a VM first.

##### Implementation notes

```
%include /tmp/disksel.ks

%pre --interpreter=/bin/bash --log=/tmp/ks-pre.log
#!/bin/bash
BEST_DISK=""; BEST_SIZE=0
for dev in /sys/class/block/*/; do
    name=$(basename "$dev")
    [[ "$name" =~ [0-9]$ ]] && continue
    [[ "$name" =~ ^(loop|sr) ]] && continue
    [[ -f "$dev/size" ]] || continue
    size=$(cat "$dev/size")
    if [[ "$size" -gt "$BEST_SIZE" ]]; then BEST_SIZE="$size"; BEST_DISK="$name"; fi
done
cat > /tmp/disksel.ks <<EOF
clearpart --drives=${BEST_DISK} --all --initlabel --disklabel=gpt
autopart --type=plain --nohome
EOF
%end
```

The `%include` line must appear **before** the `%pre` block in the kickstart — Anaconda processes includes after `%pre` completes.

---

---

#### Item 8 — NIC Carrier Check ✅ Sprint 4 (`b07a8db`)

**Importance:** 🔴 Critical  
**Impact:** Prevents silent misconfiguration when a machine has a disconnected NIC selected as the Dante interface  
**Difficulty:** Easy  
**Risk:** Low  
**Prerequisites:** None  

> **Implementation note:** Must handle carrier gracefully — wait and retry if no carrier is detected; do not crash or silently pick a dead NIC. Log a clear warning if the selected NIC has no carrier at configure time.

##### What is it?

`inferno-configure.sh` currently selects the Dante NIC by picking the first interface that is not a loopback, virtual bridge, or wireless device — in alphabetical order by interface name. It does not verify that the selected NIC has physical link. On a machine with two wired NICs (e.g. `enp1s0` and `enp2s0`) where `enp1s0` is not plugged in, the appliance configures Dante on a dead interface and transmits nothing. The failure is silent: the script succeeds, the sentinel `/etc/inferno.conf` is written, and the node never reconfigures.

The kernel exposes link state via two sysfs files: `/sys/class/net/$NIC/carrier` (value `1` = link up, `0` = no link; absent before driver bind) and `/sys/class/net/$NIC/operstate` (value `up`, `down`, `unknown`). Both should be checked.

##### Why implement?

This is the single most likely silent-failure mode for a multi-NIC deployment. The HP EliteDesk Mini sometimes ships with a rear Ethernet port and a front USB-C dock that exposes a virtual Ethernet — but some variants have two physical NICs. A `powersave` machine sitting in a rack with the wrong port cabled does nothing and gives no indication why. The fix is four lines of shell.

##### Why NOT implement (or defer)?

There is one edge case: some NIC drivers report `operstate=unknown` even when the link is physically up (common with older `tg3` and some USB Ethernet adapters). Checking `carrier=1` alone is sufficient and more reliable than `operstate`. Reading `carrier` on an interface with no driver bound will return an error — the script must handle this gracefully with `2>/dev/null` and a default of `0`.

Do not defer. This is a correctness bug, not a feature request.

##### Implementation notes

Replace the NIC detection block in `inferno-configure.sh`:

```bash
# Prefer the first wired NIC that has physical carrier (link up).
# Falls back to first wired NIC if none has carrier (e.g. no cable yet).
pick_nic() {
    local first_wired="" best=""
    while IFS= read -r line; do
        local iface
        iface=$(echo "$line" | awk '{print $2}' | tr -d ':')
        [[ "$iface" == "lo" ]] && continue
        [[ "$iface" =~ ^(docker|br-|veth|tun|tap|wl|virbr) ]] && continue
        [ -z "$first_wired" ] && first_wired="$iface"
        local carrier
        carrier=$(cat "/sys/class/net/$iface/carrier" 2>/dev/null || echo "0")
        if [ "$carrier" = "1" ] && [ -z "$best" ]; then
            best="$iface"
        fi
    done < <(ip -o link show)
    echo "${best:-$first_wired}"
}
INFERNO_NIC=$(pick_nic)
```

Log a warning if the chosen NIC has no carrier — the node may be uncabled and every downstream service will fail.

---

---

#### Item 9 — Multiple NIC Support / INFERNO_NIC_OVERRIDE ✅ Sprint 4 (`b07a8db`)

**Importance:** 🟠 High  
**Impact:** Allows operators to select the correct Dante NIC on multi-NIC hardware without reinstalling  
**Difficulty:** Easy  
**Risk:** Low  
**Prerequisites:** 8  

> **Implementation note:** Must account for NIC configuration in both `cockpit-inferno` UI and `cockpit-networkmanager`. `INFERNO_NIC_OVERRIDE` is a provisioning-time mechanism only (set via Ignition before first boot); Cockpit is the post-boot mechanism for changing NIC selection. Keep these two paths separate and clearly documented.

##### What is it?

Even after implementing the carrier check (item 8), a machine with two active wired NICs will always pick the one that sorts first alphabetically. There is currently no mechanism to override this choice without deleting `/etc/inferno.conf` and relying on luck that the other NIC comes first — which it won't, because the order is deterministic.

Proposed: honour an `INFERNO_NIC_OVERRIDE` variable in `/etc/inferno.conf` (or a drop-in at `/etc/inferno.conf.d/override.conf`). If set, `inferno-configure.sh` skips auto-detection and uses the specified interface directly. Re-running configure (via `rm /etc/inferno.conf && reboot`) then picks up the override.

##### Why implement?

The target deployment scenario is "drop a machine on a network, boot, it works." When it doesn't work because the wrong NIC was chosen, the only recovery path today is SSH (which requires knowing the IP — which requires knowing the MAC of the correct NIC, which the operator may not have). An override file is a minimal escape hatch that an operator can provision into the image before flashing, or push via Cockpit/SSH after first boot, without reinstalling.

##### Why NOT implement (or defer)?

This adds a second place where NIC configuration lives, which could confuse operators who expect auto-detection to always be authoritative. Document clearly: if `INFERNO_NIC_OVERRIDE` is set, auto-detection is completely bypassed — the override NIC is used even if it has no carrier. This is intentional (the operator knows what they're doing) but should produce a loud warning in the log if carrier is absent at configure time.

##### Implementation notes

At the top of the NIC detection block in `inferno-configure.sh`, add:

```bash
# Allow operators to force a specific NIC. Set in /etc/inferno.conf before
# first boot (pre-provisioning) or in /etc/inferno-override.conf post-install.
if [ -f /etc/inferno-override.conf ]; then
    # shellcheck source=/dev/null
    source /etc/inferno-override.conf
fi

if [ -n "${INFERNO_NIC_OVERRIDE:-}" ]; then
    echo "NIC OVERRIDE: using ${INFERNO_NIC_OVERRIDE} (auto-detection skipped)"
    INFERNO_NIC="${INFERNO_NIC_OVERRIDE}"
    carrier=$(cat "/sys/class/net/${INFERNO_NIC}/carrier" 2>/dev/null || echo "0")
    [ "$carrier" != "1" ] && echo "WARNING: ${INFERNO_NIC} has no carrier — check cable"
else
    INFERNO_NIC=$(pick_nic)
fi
```

Using a separate `/etc/inferno-override.conf` (rather than a pre-populated `/etc/inferno.conf`) avoids the sentinel race: an operator can provision the override file into the image and first-boot still runs normally.

Write `INFERNO_NIC_OVERRIDE=` (empty) into the generated `/etc/inferno.conf` as a commented-out hint so operators know the knob exists.

---

---

#### Item 11 — snd-aloop Index: Bump to 10

> ✅ **Implemented** — Sprint 1, commit `3aa6e1a` (`inferno-aoip-releases`)

**Importance:** 🟠 High  
**Impact:** Eliminates ALSA card index conflict on machines with ≥5 physical sound cards  
**Difficulty:** Easy  
**Risk:** Medium  
**Prerequisites:** None  

> **Implementation note:** NOT dynamic detection. Simply bump the hardcoded index from `5` to `10` in `/etc/modprobe.d/snd-aloop.conf` in the image. This is a static change in the Containerfile — no first-boot detection logic required.

##### What is it?

The kernel module `snd-aloop` is loaded with `index=5` hardcoded in `/etc/modprobe.d/snd-aloop.conf` (baked into the bootc image). ALSA assigns card indices sequentially; if a machine already has physical cards at indices 0–5, `snd-aloop` fails to load. The Inferno ALSA plugin then has no loopback device to open, and audio stops working silently.

The fix: bump the hardcoded index from `5` to `10` in `/etc/modprobe.d/snd-aloop.conf`. Index 10 is safely above the typical maximum on any x86 hardware. Since `/etc/` is the mutable overlay on Fedora bootc, this change in the image will propagate on upgrade.

##### Why implement?

The HP EliteDesk Mini typically has one or two sound devices (HD Audio controller + HDMI audio). Index 5 is safe for this hardware. However, the stated goal is that the image works on *any* x86_64 hardware. A workstation-class machine or a server with an audio expansion card could easily have 6+ ALSA cards. The detection logic is trivial and the fix is written to `/etc/` which is already mutable — there is no downside.

##### Why NOT implement (or defer)?

The medium risk rating comes from one scenario: the user runs `aplay -l` at first-boot time, but `snd-aloop` itself is already loaded (e.g. from initramfs or a prior boot), which means index 5 appears in the card list. The `max+1` calculation then computes 6 instead of the correct value. The fix: exclude `Loopback` from the card count, or unload `snd-aloop` before querying.

Also note: if the OS image is updated via `bootc upgrade`, the base `/etc/modprobe.d/snd-aloop.conf` in the image is **not** overwritten if the file exists in the mutable overlay — Fedora bootc's three-way merge preserves local `/etc/` changes. Confirm this behaviour holds for your bootc version before relying on it.

##### Implementation notes

Add to `inferno-configure.sh`, before the `snd-aloop` module is first loaded:

```bash
# Detect the highest occupied ALSA card index, excluding Loopback.
# /proc/asound/cards format: " 0 [PCH            ]: HDA-Intel - ..."
MAX_CARD=$(awk '/^\s*[0-9]/ && !/Loopback/ {print $1+0}' /proc/asound/cards 2>/dev/null \
    | sort -n | tail -1)
MAX_CARD="${MAX_CARD:-4}"   # default: assume index 4 is highest → use 5
ALOOP_INDEX=$(( MAX_CARD + 1 ))

echo "snd-aloop index: ${ALOOP_INDEX} (max existing card: ${MAX_CARD})"
cat > /etc/modprobe.d/snd-aloop.conf <<EOF
# Written by inferno-configure.sh — do not edit manually.
options snd-aloop index=${ALOOP_INDEX} enable=1
EOF

modprobe snd-aloop
```

Propagate `ALOOP_INDEX` into `/etc/inferno.conf` and the `asoundrc` template substitution so that `plughw:${ALOOP_INDEX},0` is used in `.asoundrc` instead of a hardcoded card number.

---

---

#### Item 12 — Hardware PTP Auto-Reporting ✅ Sprint 4 (`b07a8db`)

**Importance:** 🔴 Critical  
**Impact:** Operators know at first boot whether they have ~100ns hardware PTP or ~500µs software PTP jitter  
**Difficulty:** Easy  
**Risk:** Low  
**Prerequisites:** 8  

> **Implementation note:** Priority elevated to Critical. Auto-detect HW PTP capability on NIC at firstboot; report result to logs and surface in Cockpit. This information is essential for diagnosing audio sync issues in the field.

##### What is it?

Statime is configured with `hardware-clock=auto` — it will use a hardware PTP clock if one is available for the selected NIC. However, there is currently no first-boot record of *which mode was actually activated*. An operator deploying to mixed hardware (some nodes with Intel I219-LM NICs that support hardware timestamping, some without) has no per-node audit trail.

The detection logic already exists in `probe-node.sh`:

1. Check `/sys/class/net/$NIC/device/ptp/` — if a `ptp0` (or similar) character device is present, hardware PTP is available.
2. Cross-check with `ethtool -T $NIC` — look for `hardware-transmit` in the capabilities output.

The proposal is to run this detection in `inferno-configure.sh` and write `HW_PTP_AVAILABLE=yes|no` into `/etc/inferno.conf`.

##### Why implement?

PTP quality directly affects Dante AES67 packet timing. A node running software PTP on a Shure MXWANI8 network may exhibit audio glitches under load that hardware PTP would eliminate. Without per-node detection, operators have no way to audit their fleet. The detection is read-only, requires no changes to Statime, and takes under 100ms.

This also feeds item 14 (probe log) and any future Cockpit status page.

##### Why NOT implement (or defer)?

No meaningful trade-offs. The only caveat: `ethtool` must be available in the bootc image at configure time. Verify it is included in the base image or add it to the `Containerfile`. On Fedora, `ethtool` is in the `ethtool` package — a 200 KB addition.

##### Implementation notes

Add to `inferno-configure.sh` after NIC detection:

```bash
# Detect hardware PTP capability for the selected NIC.
HW_PTP_AVAILABLE=no
PTP_DEV=$(ls "/sys/class/net/${INFERNO_NIC}/device/ptp/" 2>/dev/null | head -1)
if [ -n "$PTP_DEV" ] && [ -c "/dev/${PTP_DEV}" ]; then
    HW_PTP_AVAILABLE=yes
    echo "Hardware PTP: /dev/${PTP_DEV} detected (${INFERNO_NIC})"
elif command -v ethtool &>/dev/null; then
    HW_COUNT=$(ethtool -T "${INFERNO_NIC}" 2>/dev/null \
        | grep -c "hardware-transmit" || true)
    [ "${HW_COUNT:-0}" -gt 0 ] && HW_PTP_AVAILABLE=yes
fi
echo "HW_PTP_AVAILABLE=${HW_PTP_AVAILABLE}"
```

Append `HW_PTP_AVAILABLE=${HW_PTP_AVAILABLE}` to the `/etc/inferno.conf` sentinel block.

Log prominently at the end of configure:

```
=== PTP MODE: SOFTWARE (expect ~500µs jitter) ===
```

or:

```
=== PTP MODE: HARDWARE /dev/ptp0 (expect ~100ns jitter) ===
```

---

---

#### Item 13 — CPU Frequency Scaling: Performance Governor

> ✅ **Implemented** — Sprint 1, commit `3aa6e1a` (`inferno-aoip-releases`)

**Importance:** 🟡 Medium  
**Impact:** Reduces PTP timestamp jitter and audio buffer underruns caused by dynamic CPU clock scaling  
**Difficulty:** Easy  
**Risk:** Low  
**Prerequisites:** None  

##### What is it?

The default Linux CPU frequency governor on Fedora is `powersave`, which dynamically scales clock speed based on load. For a headless, always-on appliance with real-time audio and PTP clock synchronisation requirements, this introduces variable latency in interrupt handling and timer resolution. The `performance` governor locks the CPU at maximum frequency, eliminating this source of jitter.

Two implementation paths:

- **(a) Systemd unit** — set governor via sysfs at boot. Simple, fully reversible, no kernel parameter changes.
- **(b) Kernel cmdline** — `processor.max_cstate=1 intel_idle.max_cstate=0` in `GRUB_CMDLINE_LINUX`. Reduces CPU C-state depth (prevents deep sleep states). More aggressive; complements rather than replaces the governor change.

**Recommendation: implement (a) unconditionally; add (b) as an optional annotation in documentation for latency-sensitive deployments.**

##### Why implement?

PTP synchronisation accuracy is bounded by the stability of the kernel's clock interrupt handling. On a machine with `powersave` governor, a burst of Dante control traffic can cause a CPU frequency ramp-up event that temporarily inflates PTP offset measurements. On an appliance with no interactive users, there is no benefit to `powersave` — the machine is always doing real work (PTP, Dante, librespot).

Power consumption increases marginally (~3–5W on a Mini PC), which is acceptable for an always-on device.

##### Why NOT implement (or defer)?

On ARM or heterogeneous CPU architectures (big.LITTLE), forcing `performance` across all cores via the sysfs glob `cpu*/cpufreq/scaling_governor` may not be supported. Write the unit defensively — ignore errors on individual cores. On machines without `cpufreq` support (some embedded x86 with fixed frequency), the write silently fails; this is harmless.

Do not use `cpupower` as the only mechanism — it may not be installed. The sysfs write is dependency-free.

##### Implementation notes

Add a systemd unit to the bootc image at `/etc/systemd/system/inferno-governor.service`:

```ini
[Unit]
Description=Inferno AoIP — set CPU performance governor
DefaultDependencies=no
After=sysinit.target
Before=statime-inferno.service

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/bin/bash -c \
  'for f in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do \
     [ -w "$f" ] && echo performance > "$f"; done; \
   echo "CPU governor: $(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null || echo n/a)"'

[Install]
WantedBy=multi-user.target
```

Enable it in the `Containerfile`:

```dockerfile
RUN systemctl enable inferno-governor.service
```

This runs before `statime-inferno.service`, ensuring the PTP daemon starts on a stable-frequency CPU.

---

---

#### Item 14 — `probe-node.sh` Output to `/var/log/inferno-probe.log` ✅ Sprint 4 (`b07a8db`)

**Importance:** 🟡 Medium  
**Impact:** Provides a persistent, single-file hardware snapshot for remote support and debugging  
**Difficulty:** Easy  
**Risk:** Low  
**Prerequisites:** 8, 12  

##### What is it?

`scripts/probe-node.sh` is currently a pre-install tool — run by an operator before flashing to check hardware compatibility. It collects NIC model, MAC, HW PTP status, ALSA cards, CPU, RAM, and boot drive. This information is valuable post-install too, but it is never captured on the running node.

The proposal: at the end of `inferno-configure.sh`, execute `probe-node.sh` (or an equivalent inline probe function) and write the output to `/var/log/inferno-probe.log`. `/var/log/` is persistent across reboots on Fedora bootc (it lives in the stateful volume, not the overlay).

##### Why implement?

When supporting a remote node, the first question is always "what hardware is this?" Currently that requires the operator to remember what they installed on, or cross-reference a spreadsheet. With this log, the answer is `ssh core@inferno-abc123 'cat /var/log/inferno-probe.log'` — a 30-second operation versus a multi-step investigation. Items 8 (correct NIC) and 12 (HW PTP) feed directly into the probe output; implementing those first makes the log meaningful.

The log is also useful for detecting hardware drift: if a node is swapped onto different hardware but `/etc/inferno.conf` is copied over, the probe log will show a discrepancy between the stored NIC/MAC and the actual hardware.

##### Why NOT implement (or defer)?

`probe-node.sh` currently uses ANSI colour codes (`\033[0;32m` etc.) which clutter a log file viewed without a terminal. Strip colours before writing, or add a `--no-color` flag to `probe-node.sh`. The script also uses `set -euo pipefail` and calls several commands that may not be available in the target image at configure time (`aplay`, `lsblk`). Run with `set +e` for the probe section, or guard each command with `command -v ... && ...`.

The log is written once at first boot. It does not auto-update if hardware changes post-install. Document this limitation clearly in the log header.

##### Implementation notes

In `inferno-configure.sh`, near the end (after NIC and PTP detection, before the reboot):

```bash
# Write hardware probe log for remote diagnostics.
PROBE_LOG=/var/log/inferno-probe.log
{
    echo "=== Inferno AoIP Hardware Probe Log ==="
    echo "Generated: $(date -Iseconds)"
    echo "Node: $(hostname)"
    echo ""
    echo "--- NIC ---"
    echo "  Interface:        ${INFERNO_NIC}"
    echo "  MAC:              ${MAC}"
    echo "  IP (at configure):${INFERNO_INTERFACE}"
    echo "  HW PTP:           ${HW_PTP_AVAILABLE}"
    ip -o link show "${INFERNO_NIC}" 2>/dev/null | awk '{print "  ip link: " $0}'
    ethtool "${INFERNO_NIC}" 2>/dev/null | grep -E "Speed|Duplex|Link" | sed 's/^/  /' || true
    echo ""
    echo "--- ALSA cards ---"
    cat /proc/asound/cards 2>/dev/null | sed 's/^/  /' || echo "  (none)"
    echo ""
    echo "--- CPU ---"
    grep "model name" /proc/cpuinfo 2>/dev/null | head -1 | cut -d: -f2 | xargs | sed 's/^/  /'
    echo ""
    echo "--- Memory ---"
    free -h 2>/dev/null | awk '/^Mem:/ {print "  Total: " $2 "  Available: " $7}' || true
    echo ""
    echo "--- Storage ---"
    lsblk -d -o NAME,SIZE,ROTA,MODEL 2>/dev/null | grep -v zram | sed 's/^/  /' || true
    echo ""
    echo "--- DEVICE_ID ---"
    echo "  ${INFERNO_DEVICE_ID}"
} > "${PROBE_LOG}" 2>&1

echo "Hardware probe written to ${PROBE_LOG}"
```

Ensure `/var/log/` exists and is writable at configure time (it always is on Fedora bootc — `systemd-tmpfiles` creates it from the base image).
---

---

---

#### Item 22 — Butane YAML for Ignition

> ✅ **Implemented** — Sprint 6, commit pending (`inferno-aoip-releases`)
> `ignition/inferno-template.bu` — Butane YAML source; compile with `butane --pretty --strict inferno-template.bu > inferno-template.ign`

**Importance:** 🟡 Medium  
**Impact:** Ignition config becomes readable, diffable, and compile-time validated  
**Difficulty:** Easy  
**Risk:** Low  
**Prerequisites:** None  

> **Implementation note:** Staged approach — (1) write `config.bu` equivalent to current `config.ign`, (2) verify compiled output matches existing JSON byte-for-byte, (3) switch build to use compiled output, (4) remove raw JSON only after VM-verified. Do not switch to Butane in a single step.

##### What is it?

`ignition/inferno-template.ign` is hand-authored Ignition v3.4.0 JSON — currently 95 lines of raw JSON with URL-encoded `data:` URIs for all embedded file content. Reading or editing it requires decoding those URIs mentally or with a tool. A typo in a percent-encoded character produces a silently corrupt file that fails at boot, not at authoring time.

[Butane](https://coreos.github.io/butane/) is the upstream-recommended YAML authoring format for Ignition configs. It compiles to Ignition JSON via `butane --pretty --strict`. Butane YAML allows inline file content (no URL encoding), type-checked fields, and catches schema errors at compile time. The compiled `.ign` file is committed to the repo or generated at image build time.

##### Why implement?

The current JSON is already painful at 95 lines. As the Ignition config grows — additional SSH keys, new override files, per-environment variants — maintaining raw JSON becomes progressively more error-prone. Butane YAML offers:

- **Inline file content:** Write file payloads directly in YAML without percent-encoding. Butane handles the `data:` URI encoding in the compiled output.
- **Compile-time validation:** `butane --strict` rejects unknown fields and type mismatches before the file is ever booted. The current JSON fails silently at boot or not at all (Ignition ignores unknown fields by default).
- **Readable diffs:** Git diffs on Butane YAML are human-readable. Git diffs on URL-encoded JSON are not.
- **Include/merge:** Butane supports `include` directives for splitting large configs across files (useful when item 25 adds per-hardware variants).

The migration is a one-time translation of the existing JSON to YAML — a well-understood mechanical process. The compiled `.ign` output is byte-for-byte equivalent to what the node receives today, so there is no runtime behaviour change.

##### Why NOT implement (or defer)?

The only trade-off is adding `butane` as a build dependency. `butane` is a single static Go binary available in Fedora repos (`dnf install butane`) and as a GitHub release binary — it is not a heavyweight dependency. If the Ignition config is rarely changed, the friction of authoring JSON directly may not be worth the migration effort. However, given that SSH key rotation and per-deployment overrides (item 25) are planned, this will pay off quickly.

**Recommendation: implement.** The migration cost is one afternoon; the ongoing benefit is permanent.

##### Implementation notes

1. Install `butane` on the authoring workstation:
   ```bash
   # Fedora/RHEL
   sudo dnf install butane
   # Or download the static binary from GitHub releases
   curl -fsSL https://github.com/coreos/butane/releases/latest/download/butane-x86_64-unknown-linux-gnu -o ~/bin/butane && chmod +x ~/bin/butane
   ```

2. Create `ignition/inferno-template.bu` as the Butane YAML source. Example structure:
   ```yaml
   variant: fcos
   version: 1.5.0
   passwd:
     users:
       - name: core
         password_hash: "INFERNO_CORE_PASSWORD_HASH"
         groups: [wheel]
         home_dir: /var/home/core
         shell: /bin/bash
         ssh_authorized_keys:
           - "ssh-ed25519 AAAA... legopc@jumphost"
   storage:
     files:
       - path: /etc/hostname
         mode: 0644
         overwrite: true
         contents:
           inline: InfernoNode
       - path: /etc/sudoers.d/core-nopasswd
         mode: 0440
         overwrite: true
         contents:
           inline: "core ALL=(ALL) NOPASSWD:ALL\n"
       - path: /etc/inferno.conf
         mode: 0644
         overwrite: true
         contents:
           inline: |
             # Inferno AoIP node configuration — seed file written by Ignition
             INFERNO_MODE=spotify
             INFERNO_NAME=InfernoNode
             INFERNO_NIC=auto
             INFERNO_AUDIO_CARD=0
   systemd:
     units:
       - name: inferno-firstboot.service
         enabled: true
         contents: |
           [Unit]
           Description=Inferno AoIP first-boot deployment
           ...
   ```

3. Compile to JSON and commit both files:
   ```bash
   butane --pretty --strict ignition/inferno-template.bu > ignition/inferno-template.ign
   git add ignition/inferno-template.bu ignition/inferno-template.ign
   ```

4. Add a `Makefile` target (or CI step) to enforce that `.ign` is always regenerated from `.bu` and committed:
   ```makefile
   ignition/inferno-template.ign: ignition/inferno-template.bu
       butane --pretty --strict $< > $@
   ```

5. Add `.bu` authoring to `CONTRIBUTING.md` or build docs: "Edit `inferno-template.bu`, run `make ignition`, commit both files."

---

---

#### Item 25 — `INFERNO_NIC_OVERRIDE` in Ignition/Kickstart ✅ Sprint 4 (`b07a8db`)

**Importance:** 🟢 Low  
**Impact:** Eliminates NIC auto-detection uncertainty on known-hardware deployments  
**Difficulty:** Easy  
**Risk:** Low  
**Prerequisites:** Item 9  

##### What is it?

`inferno-configure.sh` auto-detects the NIC by filtering `ip link show` output — excluding loopback, virtual bridges, Docker interfaces, and WiFi. On a single-NIC appliance (HP EliteDesk with only `enp1s0`) this works reliably. On hardware with multiple NICs or unusual naming, detection can be ambiguous.

This item adds a static override mechanism: Ignition writes `/etc/inferno-override.conf` containing `INFERNO_NIC_OVERRIDE=ens18`. `inferno-configure.sh` sources this file at startup and skips auto-detection if the variable is set.

This is particularly useful for:
- Fleet deployments where the target hardware is known and the NIC name is predictable.
- Environments where auto-detection would pick the wrong interface (e.g., a management NIC instead of the Dante-facing NIC).
- Testing: force a specific NIC in a Proxmox VM without relying on detection heuristics.

##### Why implement?

Auto-detection is a best-effort heuristic. The current filter (`!~ /^(docker|br-|veth|tun|tap|wl|virbr)/`) covers common cases but cannot anticipate every naming convention (e.g., `bond0`, `team0`, OEM-specific names). An explicit override costs 10 lines of shell and one Ignition file entry, and eliminates an entire class of deployment failures on non-standard hardware.

This pairs naturally with item 9 (multi-NIC support), which will make NIC selection a first-class concept rather than an auto-detected side effect. Until item 9 is complete, this item provides a lightweight escape hatch for the single-NIC case.

##### Why NOT implement (or defer)?

On standard single-NIC hardware (the primary target), this adds no value — auto-detection works. The risk of the override is that if an operator sets `INFERNO_NIC_OVERRIDE=ens18` and the hardware is later redeployed on a machine where the interface is `enp1s0`, the override silently causes configuration to target a non-existent interface. The sentinel at `/etc/inferno.conf` would need to capture the override state so operators know it is active.

**Recommendation: implement as a low-effort quality-of-life improvement. Gate it behind item 9 only if the multi-NIC implementation changes the NIC selection architecture significantly.**

##### Implementation notes

1. Add to `inferno-configure.sh` at the top of the NIC detection block:
   ```bash
   # Allow Ignition/kickstart to inject a NIC override
   INFERNO_NIC_OVERRIDE=""
   [ -f /etc/inferno-override.conf ] && source /etc/inferno-override.conf

   if [ -n "${INFERNO_NIC_OVERRIDE:-}" ]; then
       INFERNO_NIC="${INFERNO_NIC_OVERRIDE}"
       echo "NIC: ${INFERNO_NIC} (from INFERNO_NIC_OVERRIDE)"
   else
       # existing auto-detection logic
       INFERNO_NIC=$(ip -o link show | awk '$2 != "lo:" && $2 !~ /^(docker|br-|veth|tun|tap|wl|virbr)/ {print $2; exit}' | tr -d ':')
       ...
   fi
   ```

2. Record the override in the sentinel `/etc/inferno.conf`:
   ```bash
   # In the sentinel-writing block, add:
   INFERNO_NIC_SOURCE=${INFERNO_NIC_OVERRIDE:+override}/auto
   ```

3. To deploy with an override, add this file entry to the Butane source (item 22):
   ```yaml
   storage:
     files:
       - path: /etc/inferno-override.conf
         mode: 0644
         overwrite: true
         contents:
           inline: |
             INFERNO_NIC_OVERRIDE=ens18
   ```

4. For a fleet with multiple hardware variants, maintain one `.bu` file per hardware type and compile each to its own `.ign`. The shared configuration lives in a base Butane file; hardware-specific overrides are merged at compile time using Butane's `include` support (added in Butane 0.17).

5. Document in `DEPLOYMENT.md`: "If the appliance has multiple NICs or auto-detection selects the wrong interface, set `INFERNO_NIC_OVERRIDE` in the Ignition config before deployment."

---

---

---

#### Item 30 —

> ✅ **Implemented** — Sprint 2, commit `01da8f3` (`inferno-aoip-releases`) OCI Labels for Version Tracking

**Importance:** 🟢 Low  
**Impact:** Makes `bootc status` and `podman inspect` show meaningful version, build date, and git SHA  
**Difficulty:** Easy  
**Risk:** Low  
**Prerequisites:** None  

##### What is it?

The Containerfile contains no `LABEL` instructions. Running `bootc status` on a deployed node shows the image reference but no semantic version, build timestamp, or git SHA. This makes it impossible to quickly verify which exact build is running or correlate a running image to a specific commit or release tag.

##### Why implement?

Operational hygiene. When debugging a production issue, knowing the exact build (version + git SHA + build date) without SSH access to the node significantly reduces mean time to diagnosis. Labels are free metadata — zero runtime cost, zero security risk, and they surface in `bootc status`, `podman inspect`, and any OCI-compatible registry UI.

##### Why NOT implement (or defer)?

No meaningful reason to defer. This is the lowest-risk, lowest-effort item in the entire roadmap. The only caveat is that labels are static per build — a node that has been running for six months will show the build date of the image it's running, not the current date (which is correct behaviour, not a bug).

##### Implementation notes

1. Add to the end of `Containerfile` (before any `CMD`/`ENTRYPOINT`, if present):
   ```dockerfile
   ARG VERSION=dev
   ARG BUILD_DATE=unknown
   ARG GIT_SHA=unknown
   LABEL org.opencontainers.image.version="${VERSION}"
   LABEL org.opencontainers.image.created="${BUILD_DATE}"
   LABEL org.opencontainers.image.revision="${GIT_SHA}"
   LABEL org.opencontainers.image.title="Inferno AoIP Appliance"
   LABEL org.opencontainers.image.source="https://github.com/YOUR_ORG/inferno-aoip-releases"
   ```
2. In `build-release.sh`, pass the values at build time:
   ```bash
   GIT_SHA=$(git rev-parse --short HEAD)
   BUILD_DATE=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
   podman build \
     --build-arg VERSION="${RELEASE_VERSION}" \
     --build-arg BUILD_DATE="${BUILD_DATE}" \
     --build-arg GIT_SHA="${GIT_SHA}" \
     -t "${IMAGE_REF}" .
   ```
3. Verify after build:
   ```bash
   podman inspect "${IMAGE_REF}" | jq '.[0].Labels'
   ```

---

---

#### Item 31 — SELinux: `restorecon` After Custom File Copies

> ✅ **Implemented** — Sprint 1, commit `3aa6e1a` (`inferno-aoip-releases`)

**Importance:** 🔴 Critical  
**Impact:** Prevents silent permission denials for custom binaries and systemd units under SELinux enforcing mode  
**Difficulty:** Easy  
**Risk:** Low  
**Prerequisites:** None  

##### What is it?

The Containerfile copies several files into SELinux-labelled paths: `inferno-configure.sh` into `/usr/local/bin/`, the ALSA plugin `.so` into `/usr/lib64/alsa-lib/`, and custom systemd units into `/etc/systemd/system/` and `/etc/systemd/user/`. Files copied via `COPY` or `RUN cp` in a container build inherit the SELinux label of the build process context, not the label appropriate for their destination path. Without `restorecon`, these files may carry incorrect types (e.g., `container_file_t` instead of `bin_t` or `lib_t`).

In SELinux enforcing mode, a systemd service that tries to execute a binary labelled `container_file_t` may be denied by the `domain_transition` policy. The service appears to start but the binary fails silently — AVC denials go to the audit log, but the error is not surfaced in `journalctl -u` in an obvious way. This is likely the root cause of any "service starts but does nothing" issues observed during testing.

##### Why implement?

This is a correctness fix disguised as a security item. Fedora IoT runs SELinux in enforcing mode by default — this is not optional and should not be disabled. The only correct fix is to ensure files have the right labels. `restorecon -Rv` does exactly this in a single command and is the standard Fedora/RHEL practice after copying files into system paths.

This item has the highest likelihood of having already caused real, hard-to-diagnose bugs. It should be fixed immediately.

##### Why NOT implement (or defer)?

No reason to defer. The command is one line, zero risk, and idempotent. The only scenario where this is unnecessary is if all copied files already happen to land with correct labels — which cannot be relied on across build environments.

##### Implementation notes

Add to `Containerfile` after all `COPY` instructions for custom binaries and configs:

```dockerfile
RUN restorecon -Rv \
      /usr/local/bin/ \
      /usr/lib64/alsa-lib/ \
      /etc/systemd/system/ \
      /etc/systemd/user/ \
      /etc/alsa/conf.d/
```

To verify labels are correct after build, run on the deployed node:

```bash
ls -Z /usr/local/bin/inferno-configure.sh
# Expected: system_u:object_r:bin_t:s0
ls -Z /usr/lib64/alsa-lib/libasound_module_pcm_inferno.so
# Expected: system_u:object_r:lib_t:s0
```

If AVC denials have already been observed, check:
```bash
ausearch -m avc -ts recent | grep inferno
```

---

> Detail block moved to Deferred section below.

---

---

---

#### Item 33 —

> ✅ **Implemented** — Sprint 3, commit `f1a02bf` (`inferno-aoip-releases`) Hardware Watchdog

**Importance:** 🔴 Critical  
**Impact:** A kernel freeze or deadlock reboots the appliance automatically instead of leaving it silently dead  
**Difficulty:** Easy (<2h)  
**Risk:** Low  
**Prerequisites:** None  

> **Implementation note:** Auto-detect `/dev/watchdog` presence at firstboot; enable `RuntimeWatchdogSec` only if a hardware watchdog is present, skip gracefully if not. Do not hard-fail on hardware that lacks a watchdog device.

##### What is it?

A hardware watchdog is a timer, maintained by a dedicated hardware circuit or firmware peripheral, that resets the machine if software stops petting it within a defined interval. Linux exposes this via `/dev/watchdog`. systemd's PID 1 pets the watchdog automatically via `RuntimeWatchdogSec=` in `/etc/systemd/system.conf` — no custom watchdog daemon is required.

On most x86 hardware, the watchdog is available via `iTCO_wdt` (Intel Platform Controller Hub) or `sp5100_tco` (AMD FCH). Both are in-kernel modules and load automatically. Verify with:

```bash
ls /dev/watchdog* && cat /sys/class/watchdog/watchdog0/identity
```

Adding `RuntimeWatchdogSec=30` causes systemd to kick the watchdog every 15 seconds (half the timeout). If PID 1 ever stops running — kernel panic, deadlock, OOM kill of systemd — the hardware timer fires after 30 seconds and the machine resets.

For individual critical services, `WatchdogSec=` in the unit file causes systemd to kill and restart the service if it fails to send `sd_notify(WATCHDOG=1)` within the interval. This requires the service to be watchdog-aware (`Type=notify` with watchdog support), which Statime and librespot currently are not — so focus on the system-level `RuntimeWatchdogSec` first.

##### Why implement?

This is a venue appliance. When it fails at 2 AM before a morning event, there is no operator present to power-cycle it. A 30-second automatic recovery from a kernel freeze is the difference between "self-healing appliance" and "requires physical intervention". The implementation cost is a single line in one config file. There is no reason every production Inferno node does not already have this.

##### Why NOT implement (or defer)?

The only credible objection is hardware without a watchdog (uncommon on x86, impossible on embedded). Check `dmesg | grep -i watchdog` after boot — if no watchdog device is found, systemd ignores the setting gracefully. There is no downside to enabling it unconditionally.

##### Implementation notes

In `Containerfile`, add or create `/etc/systemd/system.conf.d/watchdog.conf`:

```dockerfile
RUN mkdir -p /etc/systemd/system.conf.d && \
    printf '[Manager]\nRuntimeWatchdogSec=30\nRebootWatchdogSec=10min\n' \
    > /etc/systemd/system.conf.d/watchdog.conf
```

`RebootWatchdogSec=10min` protects the reboot/shutdown path: if a reboot hangs for more than 10 minutes (e.g., a service refuses to stop), the watchdog forces a hard reset.

Verify on the node after boot:

```bash
systemctl show -p RuntimeWatchdogUSec,RebootWatchdogUSec
# Should show RuntimeWatchdogUSec=30s
```

If `/dev/watchdog0` exists but the module is not auto-loaded, add `iTCO_wdt` or `sp5100_tco` to `/etc/modules-load.d/watchdog.conf` in the image.

---

---

#### Item 34 —

> ✅ **Implemented** — Sprint 3, commit `f1a02bf` (`inferno-aoip-releases`) Service Dependency: `ConditionPathExists=/etc/inferno.conf`

**Importance:** 🟠 High  
**Impact:** Services no longer start with unsubstituted `%%PLACEHOLDER%%` values if first-boot configuration has not yet completed  
**Difficulty:** Easy (<2h)  
**Risk:** Low  
**Prerequisites:** None  

##### What is it?

`/etc/inferno.conf` is written by `inferno-configure.sh` on first boot. It is the sentinel indicating that all service template files have had their `%%PLACEHOLDER%%` variables resolved (NIC name, DEVICE_ID, Spotify credentials, etc.). If a service such as `statime-inferno.service` starts before `inferno-configure.sh` has finished — or if configure has never run — the service attempts to start with literal `%%NIC%%` and `%%DEVICE_ID%%` strings in its `ExecStart`, which fails immediately and noisily.

The fix is to add `ConditionPathExists=/etc/inferno.conf` to the `[Unit]` section of every service that depends on configured values. A failing `Condition*` causes systemd to skip the unit silently (exit code 0, condition not met), rather than entering a failed state and triggering restart loops.

For tighter coupling — where a service must not just skip but actively wait — use `After=inferno-configure.service` and `Requires=inferno-configure.service`. This is correct if `inferno-configure.service` is a oneshot unit that runs at boot and only marks itself complete when `inferno.conf` is written.

##### Why implement?

Without this guard, a factory-fresh node that boots before `inferno-configure.sh` has been invoked (or a node where configure failed mid-run) will enter a restart storm: `statime-inferno` fails, restarts with `Restart=always`, fails again, floods the journal, and never recovers until configure is re-run manually. The fix is two lines per service unit. The absence of it is a genuine first-boot reliability defect.

##### Why NOT implement (or defer)?

There is no reason to defer. The only subtlety: `inferno-configure.sh` must be idempotent and must write `/etc/inferno.conf` atomically (write to `.tmp`, then `mv`) so that no service sees a partially written sentinel. If configure writes the file before completing all substitutions, the condition check becomes unreliable. Audit `inferno-configure.sh` for this before deploying.

##### Implementation notes

Add to `statime-inferno.service`, `cockpit.socket`, and any other unit that reads configured values:

```ini
[Unit]
ConditionPathExists=/etc/inferno.conf
```

For the stronger ordering guarantee, add a dedicated oneshot service:

```ini
# /usr/lib/systemd/system/inferno-configure.service
[Unit]
Description=Inferno first-boot configuration
Before=statime-inferno.service cockpit.socket
ConditionPathExists=!/etc/inferno.conf

[Service]
Type=oneshot
ExecStart=/usr/local/bin/inferno-configure.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
```

Then in `statime-inferno.service`:

```ini
[Unit]
After=inferno-configure.service
Requires=inferno-configure.service
```

Bake both unit files into the `Containerfile` and `systemctl enable inferno-configure.service` in the image.

---

---

#### Item 35 — journald Log Size Limit

> ✅ **Implemented** — Sprint 1, commit `3aa6e1a` (`inferno-aoip-releases`)

**Importance:** 🟠 High  
**Impact:** The appliance does not silently fill its disk with journal logs over months of operation  
**Difficulty:** Easy (<2h)  
**Risk:** Low  
**Prerequisites:** None  

> **Implementation note:** Set `SystemMaxUse=512M` (not 200M as previously written). Confirmed: `SystemMaxUse` is not set in the current image or in the `fedora-bootc:43` base — this will be a net new setting.

##### What is it?

systemd-journald's default behaviour on a system with persistent storage (`/var/log/journal/` exists) is to use up to 10% of the filesystem or 4 GB, whichever is smaller. On a Fedora bootc node with a 32 GB disk and persistent `/var/`, this permits up to 3.2 GB of journal accumulation. A headless appliance that runs continuously for months — and has verbose services like librespot and Inferno logging at debug level — will fill this quota and start discarding old logs silently. Worse, if the quota is not set and the journal grows into filesystem space needed for OTA bundles, upgrades fail.

##### Why implement?

A 512 MB journal cap is generous for diagnostic purposes while protecting the ~3 GB of headroom needed for OTA bundle staging. `MaxRetentionSec=30day` ensures old logs are purged regardless of size. For an appliance that is not monitored in real time, 30 days of history is more than enough for post-incident debugging. This is a one-time, zero-maintenance fix.

##### Why NOT implement (or defer)?

There is no valid reason to defer. The only consideration: if you are actively debugging a production issue and want long journal history, you may want to temporarily increase `MaxRetentionSec` on that specific node. That is an operator concern, not a reason to leave the default uncapped in the image.

##### Implementation notes

In `Containerfile`:

```dockerfile
RUN mkdir -p /etc/systemd/journald.conf.d && \
    printf '[Journal]\nSystemMaxUse=512M\nSystemKeepFree=100M\nMaxRetentionSec=30day\n' \
    > /etc/systemd/journald.conf.d/inferno.conf
```

Verify on a running node:

```bash
journalctl --disk-usage
# Force immediate vacuum to test:
journalctl --vacuum-size=512M --vacuum-time=30d
```

`SystemKeepFree=100M` is a hard floor — journald will delete old entries to keep at least 100 MB free regardless of `SystemMaxUse`. This is the safety net for a nearly-full disk.

---

---

#### Item 36 —

> ✅ **Implemented** — Sprint 3, commit `f1a02bf` (`inferno-aoip-releases`) `LimitMEMLOCK=infinity` for RT Services

**Importance:** 🟠 High  
**Impact:** Inferno and Statime can lock their memory pages, preventing page faults that cause audio glitches under load  
**Difficulty:** Easy (<2h)  
**Risk:** Low  
**Prerequisites:** None  

##### What is it?

Real-time audio processes must lock their memory pages (`mlock`/`mlockall`) to prevent the kernel from swapping them out. A page fault in the middle of an audio buffer fill or PTP timestamp calculation introduces a multi-millisecond latency spike — exactly the kind of jitter that causes Dante network audio clicks and dropouts.

The `@audio` PAM group limit (`/etc/security/limits.conf`: `@audio - memlock unlimited`) applies to interactive login sessions. systemd services run in their own cgroup, subject to the `LimitMEMLOCK=` setting in the unit file, which defaults to the system limit (typically 64 KB — far too small for a locked audio process). Without an explicit override, `mlockall()` in `inferno-bridge.service` and `statime-inferno.service` silently fails or is clamped, leaving the processes unlocked.

##### Why implement?

The symptom of missing `LimitMEMLOCK` is subtle: the process starts fine, audio plays, but under memory pressure (OTA bundle download, journal flush, large log burst) the kernel pages out audio buffers mid-stream, producing infrequent but reproducible clicks. This is the kind of bug that appears only in production, intermittently, and is extremely hard to trace. Setting `LimitMEMLOCK=infinity` costs nothing and eliminates the failure mode entirely.

##### Why NOT implement (or defer)?

`LimitMEMLOCK=infinity` combined with an unbounded process is a potential DoS vector: a runaway process could lock all RAM, forcing the OOM killer. Mitigate by ensuring the services in question have reasonable `MemoryMax=` limits set (e.g., `MemoryMax=256M` for Inferno, `MemoryMax=64M` for Statime). Do not set `LimitMEMLOCK=infinity` globally in `system.conf` — apply it only to the specific RT service units.

##### Implementation notes

Add to `inferno-bridge.service` (and `inferno-keepalive.service` if it holds the ALSA device open):

```ini
[Service]
LimitMEMLOCK=infinity
```

Add to `statime-inferno.service`:

```ini
[Service]
LimitMEMLOCK=infinity
```

Verify the limit is applied to the running process:

```bash
# Get PID of the service
PID=$(systemctl show -p MainPID --value inferno-bridge.service)
grep -i memlock /proc/${PID}/limits
# Expect: Max locked memory  unlimited  unlimited  bytes
```

While editing the unit files, also add `LimitRTPRIO=95` and `LimitNICE=-20` if not already present — these are the other two limits required for RT scheduling and are equally ignored by PAM limits in the systemd context.

---

> Detail block moved to Deferred section below.

---

---

#### Item 39 —

> ✅ **Implemented** — Sprint 3, commit `f1a02bf` (`inferno-aoip-releases`) Boot: Mask Unnecessary Fedora Services

**Importance:** 🟠 High  
**Impact:** Boot time drops by 15–45 seconds; resource contention during audio startup is eliminated  
**Difficulty:** Easy (<2h)  
**Risk:** Low  
**Prerequisites:** None  

> **Implementation note:** Carefully curated list only. **DO NOT mask `NetworkManager-wait-online`** — `statime`/PTP depends on network being available. Safe to mask: `plymouth`, `sssd`, `ModemManager`, `bluetooth`, `cups`, `dnf-makecache.timer`. Ensure `statime-inferno.service` has `After=network-online.target`.

##### What is it?

Fedora's default image enables a set of services that are designed for general-purpose workstations and enterprise systems. On a headless, standalone audio appliance, these services waste boot time, consume memory, generate spurious journal noise, and — in the case of `NetworkManager-wait-online.service` — can add 30+ seconds to boot when NetworkManager takes time to establish a DHCP lease.

Services to mask in the `Containerfile`:

| Service | Reason |
|---|---|
| `kdump.service` | Kernel crash dump collection — useful during development, unnecessary in production; consumes ~128 MB reserved RAM |
| `sssd.service` | SSSD identity/authentication service — not needed on a standalone, non-domain appliance |
| `plymouth.service` | Graphical boot splash — meaningless on a headless device; adds ~200ms to boot |
| `NetworkManager-wait-online.service` | Blocks `network-online.target` until NM considers all connections fully up — can stall 30+ seconds; replace with the `ExecStartPre` carrier check in item 38 |
| `rhsmcertd.service` | Red Hat Subscription Manager certificate daemon — irrelevant on Fedora; attempts to contact Red Hat servers and times out noisily |

##### Why implement?

`NetworkManager-wait-online.service` alone justifies this item. On a node where NM is waiting for DHCP from a slow switch or a switch that hasn't finished its own boot sequence, this service holds `network-online.target` for up to 90 seconds before timing out. Since `statime-inferno.service` has `After=network-online.target` (item 38), this directly delays the PTP clock stabilisation and the subsequent 10-second audio service sleep. Total boot-to-audio delay without this fix: potentially 2+ minutes. With it: under 30 seconds.

The other services are lower-stakes but eliminate unnecessary resource consumption and log noise on a device that will run unattended for months.

##### Why NOT implement (or defer)?

`kdump.service` is worth keeping enabled during active development — crash dumps are invaluable for diagnosing kernel panics. Mask it only in production image builds. Consider a build arg (`ARG PRODUCTION_BUILD=false`) that conditionally masks kdump, allowing development images to retain it.

`plymouth.service` masking has no downside in production but makes debugging boot issues harder if you are watching a physical console. Again, a development vs. production build distinction handles this cleanly.

##### Implementation notes

In `Containerfile`, add before the final `ENTRYPOINT`/`CMD` or alongside other `systemctl mask` calls:

```dockerfile
RUN systemctl mask \
    kdump.service \
    sssd.service \
    plymouth.service \
    NetworkManager-wait-online.service \
    rhsmcertd.service
```

For `NetworkManager-wait-online.service` specifically, masking alone is sufficient — do not replace it with a custom `network-online.target` implementation. Instead, rely on the `ExecStartPre` carrier check in `statime-inferno.service` (item 38) to gate on actual link state, which is more accurate than NM's notion of "online" for a single-NIC, static-topology appliance.

Verify the masks survive the bootc image build:

```bash
podman run --rm <image> systemctl is-enabled NetworkManager-wait-online.service
# Expected: masked
```

After deployment, confirm boot time improvement with:

```bash
systemd-analyze blame | head -20
```

`NetworkManager-wait-online.service` should no longer appear in the blame output.

---

---

#### Item 40 — Pin Base Image Digest

> ✅ **Implemented** — Sprint 1, commit `3aa6e1a` (`inferno-aoip-releases`)

**Importance:** 🟠 High  
**Impact:** Builds become reproducible; silent base image drift between runs is eliminated  
**Difficulty:** Easy (<2h)  
**Risk:** Low  
**Prerequisites:** None  

##### What is it?

`FROM registry.fedoraproject.org/fedora-bootc:43` is a floating tag. Any time Fedora pushes an update to that tag — new package versions, kernel bumps, security patches — the next `podman build` silently picks up a different base. Two builds of `v12` made a week apart can produce different images.

Pinning to a digest makes the base image immutable until you deliberately update the pin:

```dockerfile
FROM registry.fedoraproject.org/fedora-bootc:43@sha256:<digest>
```

##### Why implement?

**Reproducibility is foundational.** If a `v12` build on the build VM produces a different image than a `v12` build on a test machine, debugging becomes unreliable. Base image drift is also a subtle source of regressions: a DNF dependency version change in the base can break a layer that has been stable for months. Pinning means you can bisect regressions to a specific base image update, and you can reproduce any historical build exactly.

This is standard practice in every production container build system. The floating-tag pattern is acceptable for development but not for release artifacts destined for physical appliances.

##### Why NOT implement (or defer)?

The only trade-off is that you must manually rotate the digest when you want to pick up base image security patches. This is a feature, not a bug — it forces a conscious decision — but it adds a maintenance step. If the team is unwilling to periodically run `skopeo inspect` and commit the updated digest, the base image will stagnate and accumulate unpatched CVEs. A periodic digest-rotation reminder (e.g., a cron job or calendar entry, monthly) mitigates this entirely.

Do not defer unless the build cadence is so frequent and irregular that digest rotation would become a full-time job — which is not the case here.

##### Implementation notes

1. Fetch the current digest:
   ```bash
   skopeo inspect --format '{{.Digest}}' \
     docker://registry.fedoraproject.org/fedora-bootc:43
   ```
   Example output: `sha256:a1b2c3d4...`

2. Update the first line of the Containerfile:
   ```dockerfile
   # Updated: 2025-07-15 — Fedora bootc 43 (20250715 compose)
   FROM registry.fedoraproject.org/fedora-bootc:43@sha256:a1b2c3d4...
   ```
   Keep the floating tag alongside the digest for human readability; podman uses the digest.

3. Commit the Containerfile change. The digest is part of the source-of-truth for every build.

4. Establish a rotation cadence. Monthly is appropriate for a stable appliance. Add a build-script check that warns (does not fail) if the digest is older than 60 days:
   ```bash
   DIGEST_DATE=$(git log -1 --format="%ci" -- Containerfile | cut -d' ' -f1)
   AGE_DAYS=$(( ( $(date +%s) - $(date -d "$DIGEST_DATE" +%s) ) / 86400 ))
   [[ $AGE_DAYS -gt 60 ]] && echo "WARNING: base image digest is ${AGE_DAYS} days old — consider rotating"
   ```

---

---

#### Item 42 —

> ✅ **Implemented** — Sprint 2, commit `034c76c` (`inferno-aoip-releases`) Reorder Containerfile Layers for Cache Efficiency

**Importance:** 🟠 High  
**Impact:** Stable DNF, config, and service-unit layers are cached on every rebuild; only the binary download layer is invalidated when nightly binaries change  
**Difficulty:** Easy (<2h)  
**Risk:** Low  
**Prerequisites:** None  

> **Implementation note:** Must be tested after reorder — verify that the DNF layer cache is actually preserved after script/template changes. Do a before/after rebuild-time comparison to confirm the speedup is real.

##### What is it?

Podman (and Docker) layer caching works top-to-bottom: the first instruction that changes invalidates the cache for all instructions below it. The current Containerfile places the binary download step early:

```dockerfile
# CURRENT — near the top, invalidated on every nightly binary change:
RUN curl -fsSL https://github.com/legopc/inferno-aoip-releases/releases/latest/download/... \
    -o /usr/lib/alsa-lib/libasound_module_pcm_inferno.so
```

Because the nightly build changes frequently, this layer is almost never a cache hit. Every layer below it — DNF installs, config file copies, systemd unit installation, user setup — is also re-executed on every build, even though none of those things changed.

Moving the binary download to just before the final metadata/label instructions means all stable layers above it are always cache hits. A rebuild after a nightly binary change costs only the binary download layer and any subsequent layers, not the entire image.

##### Why implement?

On a 25–35 minute build, the podman layer rebuild time is the dominant cost. If DNF installs, service unit setup, and config copies represent 15–20 minutes of that time and they're cache hits, rebuilds of the same version drop to minutes. This directly reduces the feedback loop for any build that doesn't change the base OS setup.

This is one of the highest-ROI changes in this section: it requires moving a single `RUN curl` block, has zero runtime effect, and has no prerequisites.

##### Why NOT implement (or defer)?

There is no meaningful reason to defer. The only edge case is if you deliberately want every build to do a full rebuild for verification purposes — in that case, pass `--no-cache` explicitly rather than structuring the Containerfile to force it.

##### Implementation notes

Identify the current position of all binary download `RUN` steps in the Containerfile:

```bash
grep -n "curl\|wget\|download" Containerfile
```

Restructure the Containerfile into these logical groups, in order:

```
1. FROM (base image, pinned — see Item 40)
2. ARG declarations (VERSION, BUILD_DATE, GIT_SHA — see Items 43/44)
3. DNF installs (stable, large, high cache value)
4. Static config files (COPY /etc/..., /usr/lib/...) — stable
5. systemd unit files (COPY + RUN systemctl enable) — stable
6. User creation, permissions — stable
7. ── cache boundary: everything above is almost never invalidated ──
8. Binary downloads (curl for nightly inferno + statime binaries)
9. LABEL instructions (VERSION, BUILD_DATE, GIT_SHA)
```

The key rule: **any instruction whose inputs change between builds must come after all instructions whose inputs are stable.**

Verify that build times drop after reordering by comparing rebuild time (without `--no-cache`) before and after making a trivial binary-only change.

---

---

#### Item 43 —

> ✅ **Implemented** — Sprint 2, commit `01da8f3` (`inferno-aoip-releases`) Pass `--build-arg VERSION=$VERSION`

**Importance:** 🟠 High  
**Impact:** The image version is baked into every layer, enabling version-aware first-boot scripts, `bootc status` metadata, and accurate log output  
**Difficulty:** Easy (<2h)  
**Risk:** Low  
**Prerequisites:** None  

##### What is it?

Currently `VERSION` is used only as a podman image tag (`-t inferno-appliance:v12`). The tag exists only in podman's local storage and is lost after export. Nothing inside the image knows what version it is.

Passing `VERSION` as a build-arg makes it available inside the Containerfile:

```bash
# build-release.sh
podman build \
  --build-arg VERSION="${VERSION}" \
  -t "localhost/inferno-appliance:${VERSION}" \
  .
```

```dockerfile
# Containerfile
ARG VERSION=dev
LABEL org.opencontainers.image.version="${VERSION}"
RUN echo "${VERSION}" > /etc/inferno-version
```

##### Why implement?

Without this, `/etc/inferno-version` (needed by Item 15's version sentinel comparison), first-boot log lines, and `bootc status` all show either nothing or a hardcoded placeholder. When a deployed node reports its version via Cockpit or syslog, it must be able to read the baked-in version — not infer it from a tag that may not exist on the target node.

This also unblocks Items 15 and 16 (version comparison in the upgrade path), which depend on a reliable on-disk version string.

##### Why NOT implement (or defer)?

No meaningful reason to defer. The change is two lines in `build-release.sh` and three lines in the Containerfile. The only risk is forgetting to add `ARG VERSION=dev` to the Containerfile before passing `--build-arg` — podman will silently ignore unknown build-args unless `--build-arg-check` is set. Add `--build-arg-check` to the podman invocation to surface this class of mistake:

```bash
podman build --build-arg-check ...
```

##### Implementation notes

1. **`build-release.sh`** — add to the `podman build` invocation:
   ```bash
   podman build \
     --build-arg-check \
     --build-arg VERSION="${VERSION}" \
     --build-arg BUILD_DATE="${BUILD_DATE}" \
     --build-arg GIT_SHA="${GIT_SHA}" \
     -t "localhost/inferno-appliance:${VERSION}" \
     .
   ```

2. **Containerfile** — add near the top (after `FROM`):
   ```dockerfile
   ARG VERSION=dev
   ARG BUILD_DATE=unknown
   ARG GIT_SHA=unknown
   ```

3. **Containerfile** — add labels (after the binary download layer, so they don't invalidate stable cache layers above):
   ```dockerfile
   LABEL org.opencontainers.image.version="${VERSION}" \
         org.opencontainers.image.created="${BUILD_DATE}" \
         org.opencontainers.image.revision="${GIT_SHA}" \
         com.legopc.inferno.version="${VERSION}"
   ```

4. **Containerfile** — write version to disk for runtime use:
   ```dockerfile
   RUN echo "${VERSION}" > /etc/inferno-version && chmod 444 /etc/inferno-version
   ```

5. Verify after build:
   ```bash
   podman inspect localhost/inferno-appliance:v12 \
     --format '{{json .Config.Labels}}' | jq .
   ```

---

---

#### Item 44 —

> ✅ **Implemented** — Sprint 2, commit `01da8f3` (`inferno-aoip-releases`) Generate `BUILD_DATE` and `GIT_SHA` Build-Args

**Importance:** 🟡 Medium  
**Impact:** `bootc status` and `podman inspect` show meaningful provenance metadata; debugging "which exact commit built this image" becomes trivial  
**Difficulty:** Easy (<2h)  
**Risk:** Low  
**Prerequisites:** 43  

##### What is it?

Two additional build-time values that cost nothing to capture but provide significant diagnostic value when embedded in image labels:

- **`BUILD_DATE`** — ISO 8601 UTC timestamp of the build invocation
- **`GIT_SHA`** — short SHA of the `inferno-aoip-releases` repo at build time

These are captured in `build-release.sh` before calling `podman build`, then passed as `--build-arg` and baked into `LABEL` instructions (see Item 43 for the Containerfile side).

##### Why implement?

When a deployed node reports an issue, the first diagnostic question is: "What exact image is running?" With these labels, `bootc status` (or `podman inspect` on the build machine) answers this completely:

```
org.opencontainers.image.version: v12
org.opencontainers.image.created: 2025-07-15T03:14:00Z
org.opencontainers.image.revision: a1b2c3d
```

Without them, you know only the version tag. With them, you can `git show a1b2c3d` to see exactly what changed, and `BUILD_DATE` lets you correlate the image with build logs at `/opt/inferno-build/build-v12.log`.

##### Why NOT implement (or defer)?

`BUILD_DATE` invalidates the label layer on every build, even if nothing else changed. This is unavoidable and acceptable — the label layer is trivially small and should be last in the Containerfile (after the binary download layer), so it only invalidates itself.

`GIT_SHA` reflects the `inferno-aoip-releases` repo, not the Containerfile submodules. If `cockpit-inferno` or `iot-updater` submodule content changes without a parent repo commit, the SHA won't reflect that change. Mitigate by including submodule SHAs in the label set if full provenance is required.

##### Implementation notes

1. **`build-release.sh`** — capture values before the `podman build` call:
   ```bash
   BUILD_DATE=$(date -u +%Y-%m-%dT%H:%M:%SZ)
   GIT_SHA=$(git -C /opt/inferno-build/inferno-aoip-releases rev-parse --short HEAD)
   ```

2. Pass to `podman build` (combined with Item 43 args — see that item's implementation notes for the full invocation).

3. The Containerfile `ARG` and `LABEL` declarations are covered in Item 43. No additional Containerfile changes are needed beyond what Item 43 specifies.

4. Optionally, write `BUILD_DATE` and `GIT_SHA` to `/etc/inferno-build-info` for use by first-boot scripts or Cockpit status pages:
   ```dockerfile
   RUN printf "VERSION=%s\nBUILD_DATE=%s\nGIT_SHA=%s\n" \
       "${VERSION}" "${BUILD_DATE}" "${GIT_SHA}" \
       > /etc/inferno-build-info && chmod 444 /etc/inferno-build-info
   ```

5. Verify the full label set after a build:
   ```bash
   podman inspect localhost/inferno-appliance:v12 \
     --format '{{range $k,$v := .Config.Labels}}{{$k}}={{$v}}{{"\n"}}{{end}}'
   ```

---

---

#### Item 45 —

> ✅ **Implemented** — Sprint 2, commit `01da8f3` (`inferno-aoip-releases`) Clean Up `output-vN/` Directories After Build

**Importance:** 🔴 Critical  
**Impact:** Build VM disk does not fill up; the 150 GB ceiling is not reached after ~75 builds  
**Difficulty:** Easy (<2h)  
**Risk:** Low  
**Prerequisites:** None  

##### What is it?

Bootable Image Builder (BIB) writes its working output to `/opt/inferno-build/output-vN/` — squashfs trees, bootiso working files, and the raw ISO. This directory is approximately 2 GB per build. After the ISO is copied to `releases/` and SCP'd to PRX-02, the `output-vN/` directory is entirely redundant, but it is never deleted.

At the current build cadence, the build VM's 150 GB disk will be exhausted after approximately 75 builds. At that point, `podman build` and BIB will fail mid-run with no disk space, potentially corrupting in-progress artifacts. There is no alerting for this condition.

##### Why implement?

This is an operational time bomb with a deterministic failure mode. The fix is a single `rm -rf` line. The permanent artifact store (`releases/`) is unaffected — it holds only the final ISO, tar, and `.iotupdate` bundle, not the BIB working directory. Implementing this now costs 30 minutes; recovering from a full disk during a live build costs far more.

##### Why NOT implement (or defer)?

The only reason to keep `output-vN/` after SCP succeeds would be to re-run `inject-iso-branding.sh` without triggering a full BIB run. This is a niche debugging use case. If re-branding a specific version's ISO is needed, regenerate it from the tar artifact in `releases/` instead.

Do not defer. A build that fails at step 3 of 8 due to a full disk, with no log-space to write the error, is a bad failure mode.

##### Implementation notes

Add the cleanup step at the **end** of `build-release.sh`, gated on successful SCP:

```bash
# After SCP to PRX-02 succeeds:
echo "[build] SCP complete. Cleaning up BIB working directory..."
rm -rf "${BUILD_DIR}/output-v${VERSION}"
echo "[build] Cleaned up output-v${VERSION}/ (saved ~2 GB)"
```

Where `BUILD_DIR=/opt/inferno-build` and `VERSION` is the current build version string.

**Gate the cleanup on SCP success.** Do not delete the output directory if SCP fails — the local output is the last copy of the ISO until SCP is retried:

```bash
scp "${RELEASES_DIR}/inferno-v${VERSION}.iso" "user@prx-02:/path/to/releases/" \
  && rm -rf "${BUILD_DIR}/output-v${VERSION}" \
  || echo "[build] WARNING: SCP failed — output-v${VERSION}/ retained for recovery"
```

Optionally, add a pre-build disk space check to fail fast if the build VM is already low:

```bash
AVAIL_GB=$(df -BG /opt/inferno-build | awk 'NR==2 {gsub("G","",$4); print $4}')
[[ $AVAIL_GB -lt 15 ]] && { echo "ERROR: Less than 15 GB free — aborting build"; exit 1; }
```

---

---

#### Item 46 —

> ✅ **Implemented** — Sprint 2, commit `01da8f3` (`inferno-aoip-releases`) Parallel ISO Branding + Tarball Export

**Importance:** 🟡 Medium  
**Impact:** Total build time reduced by 5–10 minutes by running two independent post-build steps concurrently  
**Difficulty:** Easy (<2h)  
**Risk:** Medium  
**Prerequisites:** None  

##### What is it?

The current build pipeline runs steps 3 and 4 sequentially:

- **Step 3:** `inject-iso-branding.sh` — reads the raw BIB ISO, writes a branded ISO (~3–5 min, I/O bound)
- **Step 4:** `podman save` — reads podman storage, writes a `.tar` (~3–5 min, I/O bound)

These operations are completely independent: branding reads the ISO file; `podman save` reads podman's overlay storage. They share no inputs or outputs. Running them in parallel shaves 3–5 minutes off every build.

##### Why implement?

5–10 minutes off a 45–65 minute pipeline is a meaningful improvement for a release cadence where builds are manually triggered and the operator is waiting. The implementation is simple bash job control — two background processes and a `wait` with exit code checking. No new tools, no new dependencies.

##### Why NOT implement (or defer)?

**Risk is medium because both operations are I/O intensive.** The build VM has a single disk (`/opt/inferno-build`), and both operations read/write large files concurrently. On a VM with slow storage (e.g., Proxmox thin-provisioned LVM over spinning disk), contention may make each operation take longer in parallel than sequentially, eliminating the benefit.

**Measure before committing.** Run a build with `time` around each step individually, then run them in parallel and compare wall-clock time. If the build VM's storage is NVMe-backed or the VM has sufficient I/O bandwidth, parallelisation will help. If it's slow spinning disk, the gain may be near zero.

Also: error handling in parallel bash is more complex than sequential. If branding fails but `podman save` succeeds, the build must not silently continue to step 5 with a missing branded ISO. The implementation must capture and check both exit codes.

##### Implementation notes

Replace the sequential steps 3–4 block in `build-release.sh` with:

```bash
echo "[build] Starting ISO branding and tarball export in parallel..."

# Launch both in background
bash "${SCRIPT_DIR}/inject-iso-branding.sh" \
  "${BIB_ISO}" "${BRANDED_ISO}" &
BRAND_PID=$!

podman save "localhost/inferno-appliance:${VERSION}" \
  --format oci-archive \
  -o "${RELEASES_DIR}/inferno-appliance-${VERSION}.tar" &
TAR_PID=$!

# Wait for both and check exit codes independently
BRAND_EXIT=0
TAR_EXIT=0

wait $BRAND_PID || BRAND_EXIT=$?
wait $TAR_PID   || TAR_EXIT=$?

if [[ $BRAND_EXIT -ne 0 ]]; then
  echo "ERROR: inject-iso-branding.sh failed (exit ${BRAND_EXIT})" >&2
  exit 1
fi

if [[ $TAR_EXIT -ne 0 ]]; then
  echo "ERROR: podman save failed (exit ${TAR_EXIT})" >&2
  exit 1
fi

echo "[build] ISO branding and tarball export complete."
```

Key points:
- Capture PIDs immediately after `&` — do not use `wait` without a PID, as it returns 0 even if a background job failed in some shells.
- Check exit codes with `wait $PID || EXIT=$?`, not `wait $PID && ...` inline, to ensure both jobs are always waited on regardless of which fails first.
- Do not run step 5 (`make-oci-bundle.sh`) until both `BRAND_EXIT` and `TAR_EXIT` are confirmed zero, since step 5 likely depends on the `.tar` output.
- Log wall-clock time for both parallel jobs on the first few runs to confirm the speedup is real on this VM's storage.

---

---

#### Item 84 — SNMP v2c Read-Only Agent ✅ DONE

**Status:** ✅ Implemented — `legopc/cockpit-inferno` + `inferno-aoip-releases` (2026). Supports both SNMPv2c (community string) and SNMPv3 (SHA-256/AES-128). Cockpit SNMP tab for config; inferno-snmp-apply.sh renders snmpd.conf from template; OIDs exposed under NET-SNMP-EXTEND-MIB; disabled by default.

**Importance:** 🟢 Low  
**Impact:** Integration with AV system management platforms (QSC, Crestron, Extron) that use SNMP for device monitoring  
**Difficulty:** Hard (multi-day)  
**Risk:** Low  
**Prerequisites:** None  

##### What is it?

Professional AV environments frequently use AMX, Crestron, or QSC control systems that poll devices via SNMP for status monitoring. A read-only SNMPv2c agent exposing: system uptime, service status OIDs, PTP offset, and audio device status would enable integration with these management platforms without custom API development.

##### Why implement?

High value for professional installs. Many AV operators and integrators evaluate solutions based on SNMP support — it's a standard requirement in tender documents for installed AV systems. Even a basic MIB with system uptime and service status would satisfy most requirements.

##### Why NOT implement (or defer)?

`net-snmp` adds ~20MB to the image. SNMP configuration (community strings, MIB definitions, trap destinations) is complex and varies per installation. SNMPv2c uses plaintext community strings — a security concern. Consider deferring until SNMPv3 (auth + encryption) can be implemented.

##### Implementation notes

Add `net-snmp` as an optional commented-out package in Containerfile. Add MIB template for inferno-specific OIDs under a private enterprise number. Provide example `snmpd.conf` with read-only community string configurable via `/etc/inferno.conf`. Document with example `snmpwalk -v2c -c inferno <node-ip> .1.3.6.1.4.1.XXXXX` commands.

---

---

#### Item 97 — Disable RT Throttling (`sched_rt_runtime_us=-1`)

> ✅ **Implemented** — Sprint 4, commit `fb0e4dd` (`inferno-aoip-releases`) Add /etc/sysctl.d/99-rt-audio.conf

**Importance:** 🟠 High  
**Impact:** Prevents kernel from preempting SCHED_FIFO statime — eliminates 50ms/s forced pauses that cause PTP jitter spikes  
**Difficulty:** Easy  
**Risk:** Low  
**Prerequisites:** None

##### What is it?
Linux's default `sched_rt_runtime_us=950000` throttles SCHED_FIFO processes to 95% of CPU to prevent starvation. statime runs at FIFO priority 80; under default settings it can be involuntarily preempted for 50ms every second — catastrophic for IEEE 1588 PTP synchronisation. Setting this to `-1` disables throttling entirely for RT processes.

##### Why implement?
PTP synchronisation requires sub-millisecond timing consistency. The 50ms preemption window under default throttling is 50× larger than acceptable PTP jitter. Combined with PREEMPT_DYNAMIC/full, disabling RT throttling is the single highest-leverage software tuning available without a PREEMPT_RT kernel.

##### Why NOT implement (or defer)?
A runaway SCHED_FIFO process with `sched_rt_runtime_us=-1` can starve all non-RT workloads completely. Only safe because inferno services are well-understood and not susceptible to infinite loops.

##### Implementation notes
Add to `Containerfile`:
```dockerfile
RUN echo 'kernel.sched_rt_runtime_us = -1' > /etc/sysctl.d/99-rt-audio.conf && \
    echo 'kernel.sched_rt_period_us = 1000000' >> /etc/sysctl.d/99-rt-audio.conf && \
    echo 'net.core.rmem_max = 16777216' >> /etc/sysctl.d/99-rt-audio.conf && \
    echo 'net.core.wmem_max = 16777216' >> /etc/sysctl.d/99-rt-audio.conf && \
    echo 'net.core.netdev_max_backlog = 300000' >> /etc/sysctl.d/99-rt-audio.conf
```
The `rmem_max`/`wmem_max` additions prevent UDP audio receive buffer drops at the NIC ring. Already partially addressed by existing Item 36 (`LimitMEMLOCK`) but this is the kernel-level complement.

---

---

#### Item 104 — bootc Switch Rollback via `FailureAction=`

> ✅ **Implemented** — Sprint 4, commits `003e95c`+`5d8b4ca` (`inferno-aoip-releases`) OnFailure rollback service + boot-loop circuit breaker

**Importance:** 🟠 High  
**Impact:** Automatic rollback to previous image if updated image hard-locks before reaching multi-user.target  
**Difficulty:** Easy  
**Risk:** Low  
**Prerequisites:** None

##### What is it?
`inferno-health-check.service` correctly calls `bootc rollback` after 120s, but this only works if the system reaches `multi-user.target`. If a bad kernel argument or early-boot systemd unit causes a hard lock, the health check never runs. A `FailureAction=` on the health check unit combined with a watchdog service covers the gap.

##### Why implement?
Applied OTA updates are the highest-risk operation on a production appliance. The existing 120s health check is good but incomplete — it doesn't cover boot-time panics or hard locks from bad kernel args.

##### Why NOT implement (or defer)?
Adds complexity to the boot sequence. `FailureAction=` only fires if the health check service itself fails, not if the system hangs. Full coverage requires a bootloader-level boot counter (systemd-boot `BootCount`).

##### Implementation notes
Add to `inferno-health-check.service`:
```ini
[Unit]
OnFailure=inferno-rollback-reboot.service
```
Create `inferno-rollback-reboot.service`:
```ini
[Unit]
Description=Inferno Emergency Rollback
[Service]
Type=oneshot
ExecStart=/usr/bin/bootc rollback
ExecStartPost=/usr/bin/systemctl reboot
```
Longer term: use `bootc switch --apply` in `apply-update.sh` to enable systemd-boot `BootCount` tracking.

---

---

#### Item 105 — Cockpit CSP Hardening (Remove `unsafe-inline`)

> ✅ **Implemented** — Sprint 4, commit `c805d23` (`iot-updater`) Remove unsafe-inline; migrate 47 inline styles to CSS classes

**Importance:** 🟠 High  
**Impact:** Eliminates CSS/script injection vector in IoT Updater and Cockpit Inferno plugins  
**Difficulty:** Easy  
**Risk:** Low  
**Prerequisites:** None

##### What is it?
`cockpit-iot-updater/manifest.json` Content-Security-Policy includes `style-src 'self' 'unsafe-inline'`. This allows any injected CSS to execute, which is a meaningful XSS vector given the plugin's `connect-src http://127.0.0.1:8088` grants access to the update sidecar. The `cockpit-inferno` manifest should also be audited for similar issues.

##### Why implement?
Cockpit plugins run in a privileged browser context with access to systemd, journal, and SSH. An XSS in either plugin could silently trigger OTA updates, execute arbitrary systemctl commands, or exfiltrate SSH keys.

##### Why NOT implement (or defer)?
Removing `unsafe-inline` requires auditing all inline `<style>` blocks and moving them to linked CSS. The iot-updater UI uses some dynamic inline styles for progress bars — these must be refactored.

##### Implementation notes
```json
// cockpit-iot-updater/manifest.json
"content-security-policy": "default-src 'self'; connect-src 'self' http://127.0.0.1:8088; img-src 'self' data:; style-src 'self'; script-src 'self'"
```
Audit `index.html` and `updater.js` for inline `style=` attributes and `<style>` blocks. Move to `updater.css`. For `cockpit-inferno`, audit `src/index.html` for inline scripts and styles.

---

---

#### Item 106 — `statime-inferno.service` Capability Sandboxing

> ✅ **Implemented** — Sprint 4, commits `d6532b8`+`004f2e4` (`inferno-aoip-releases`) CapabilityBoundingSet with CAP_SYS_NICE; PrivateTmp removed (breaks ptp-usrvclock)

**Importance:** 🟠 High  
**Impact:** Limits blast radius if statime process is exploited — strips 35+ unnecessary Linux capabilities  
**Difficulty:** Easy  
**Risk:** Medium  
**Prerequisites:** None

##### What is it?
`statime-inferno.service` runs as root with no `CapabilityBoundingSet` — effectively full root. statime only needs three capabilities: `CAP_SYS_TIME` (adjust hardware clock), `CAP_NET_RAW` (raw PTP sockets), `CAP_NET_BIND_SERVICE` (bind to port 319/320). All others can be stripped.

##### Why implement?
PTP daemon is network-facing (binds to ports 319/320, receives arbitrary UDP packets). A memory corruption bug in statime with full root capabilities is a complete system compromise. With capability bounding, the same bug is contained.

##### Why NOT implement (or defer)?
Risk: `ProtectSystem=` and `PrivateTmp=` can break statime's access to `/etc/statime-inferno.toml` or the PHC device if paths aren't whitelisted. Requires testing each restriction carefully.

##### Implementation notes
```ini
# templates/systemd/system/statime-inferno.service — [Service] section additions
CapabilityBoundingSet=CAP_SYS_TIME CAP_NET_RAW CAP_NET_BIND_SERVICE
AmbientCapabilities=CAP_SYS_TIME CAP_NET_RAW CAP_NET_BIND_SERVICE
NoNewPrivileges=no
ProtectHome=true
PrivateTmp=yes
# Do NOT add ProtectSystem=strict — statime reads /etc/statime-inferno.toml
# Do NOT add PrivateDevices=yes — statime needs /dev/ptp0
```
Test with `systemd-analyze security statime-inferno` before and after.

---

---

#### Item 107 — `WatchdogSec=` for Critical Audio Services

> ✅ **Implemented** — Sprint 4, commits `4477f3b`+`f69dec1` (`inferno-aoip-releases`) Wrapper scripts for alsaloop and librespot; WatchdogSec=30/60

**Importance:** 🟠 High  
**Impact:** Detects hung (non-exiting) service states and forces restart — catches zombie alsaloop processes  
**Difficulty:** Medium  
**Risk:** Low  
**Prerequisites:** None

##### What is it?
`inferno-bridge.service`, `inferno-keepalive.service`, and `librespot.service` use `Restart=always` but have no watchdog. If `alsaloop` enters a hung state without exiting (e.g. waiting indefinitely for an ALSA buffer), systemd never detects the failure and never restarts the service. Audio stops silently.

##### Why implement?
`Restart=always` only handles clean exits and crashes. A hung process looks "running" to systemd. The watchdog (`WatchdogSec=`) forces a restart if the service doesn't periodically `sd_notify(WATCHDOG=1)`. Catches an entire class of silent audio failures.

##### Why NOT implement (or defer)?
Requires a wrapper script around `alsaloop` to send watchdog pings — the `alsaloop` binary itself doesn't support `sd_notify`. Adds a thin shell script wrapper layer.

##### Implementation notes
```bash
#!/bin/bash
# /usr/local/sbin/inferno-bridge-watchdog.sh
systemd-notify --ready
(while true; do systemd-notify WATCHDOG=1; sleep 10; done) &
exec /usr/bin/alsaloop "$@"
```
```ini
# inferno-bridge.service additions
ExecStart=/usr/local/sbin/inferno-bridge-watchdog.sh [original args]
WatchdogSec=30
NotifyAccess=all
Type=notify
```
For `librespot`, pass `--enable-audio-locking` flag and add `WatchdogSec=60` directly (librespot supports sd_notify).

---

---

#### BUG-04 — Dante Network Discovery: Longer Scan + Better Results

**Problem:** The Dante scan uses `avahi-browse -t` (one-shot/terminate immediately after initial results — typically 2–3 s). Slow devices may not respond in time and results are shown in a minimal text list.

**Solution:**
- Remove `-t` flag; use `timeout 8 avahi-browse -rp _netaudio-arc._tcp` so the scan runs for 8 seconds and captures late responders
- Present results as a clean table with columns: **Device Name**, **IP Address**, **Hostname**
- Show a count of devices found after scan completes

**File:** `cockpit-inferno/src/inferno.js` — `scanDanteDevices()` function

---

---

---

#### BUG-05 — SELinux `unlabeled_t` on `/var/home/core/.ssh` → SSH key auth fails

**Importance:** 🔴 Critical  
**Impact:** All deployed nodes have broken SSH key auth; silently falls back to password auth  
**Difficulty:** Easy (<2h)  
**Risk:** Low  
**Prerequisites:** None  

##### What is it?

Ignition creates `/var/home/core/.ssh/authorized_keys` during first boot, but SELinux labels it `unlabeled_t` instead of the required `ssh_home_t`. The SSH daemon (selinux-aware) denies key-based authentication and silently falls back to password auth. This is confirmed on v23: `ls -Z /var/home/core/.ssh/` shows `unlabeled_t`. The fix is a single `restorecon -Rv /var/home/core/` call in `inferno-configure.sh` after user home setup.

##### Why implement?

If password authentication is ever disabled (Items 26/27), nodes become completely unreachable. This is a latent critical vulnerability — it works now only because password auth is still enabled. The fix is a one-liner, completely safe, and idempotent.

##### Why NOT implement (or defer)?

SSH currently works via password auth so the issue is not immediately visible. However, as Item 26 (password policy) and Item 27 (disable password auth) are progressively implemented, this silently blocks the security hardening path.

##### Implementation notes

In `build/inferno-configure.sh`, after the `chown -R core:core "${CORE_HOME}"` line (~line 215), add:

```bash
restorecon -Rv /var/home/core/ 2>/dev/null || true
```

To verify the fix: after first boot, run `ls -Z /var/home/core/.ssh/authorized_keys` — expected label is `system_u:object_r:ssh_home_t:s0`.

---

---

#### Item 23 — `systemd-sysusers` and `tmpfiles.d` for User and Directory Setup

**Importance:** 🟠 High  
**Impact:** User creation becomes declarative and bootc-idiomatic, eliminating fragile shell hacks in the Containerfile  
**Difficulty:** Medium  
**Risk:** Medium  
**Prerequisites:** None  

> **Implementation note:** Staged approach — (1) add `sysusers`/`tmpfiles` declarations alongside existing `RUN` commands, (2) verify parity on test VM (correct groups, linger, home dirs), (3) remove old `RUN` commands only after verified. Must not break core user audio group membership or linger setup.

##### What is it?

The `core` user is currently created in the Containerfile by running `useradd`, `chpasswd`, and directly writing `/etc/group` with `sed`. This works, but it is fragile:

- `useradd` and `chpasswd` are imperative shell commands — they leave traces in image layers and interact poorly with bootc's 3-way merge on upgrade.
- Adding `core` to the `audio` group requires bypassing `groupadd` entirely (which refuses because `audio` already exists in `/usr/lib/group`) and writing directly to `/etc/group`. This is documented in the Containerfile comment as a known hack.
- Pre-creating `/var/lib/systemd/linger/core` in the image (to work around linger timing) is another hack that survives only because `/var/` is persistent — but it means the linger file lives in the image layer, not in the runtime state where systemd expects to manage it.

The bootc/systemd-idiomatic approach:

- **`/usr/lib/sysusers.d/inferno.conf`** — declares the `core` user declaratively. `systemd-sysusers` creates or reconciles it on every boot. It handles `audio` group membership correctly because it reads both `/usr/lib/group` and `/etc/group` and merges them.
- **`/usr/lib/tmpfiles.d/inferno.conf`** — declares directories under `/var/` that should be created on first boot with correct ownership and permissions. Replaces `mkdir -p` calls scattered across the Containerfile and `inferno-configure.sh`.

##### Why implement?

1. **Correctness on upgrade:** When a new bootc image is applied, `systemd-sysusers` re-runs and reconciles user state against the current declaration. The shell-script approach does not re-run — if group membership needs to change in a future release, it silently fails on already-deployed nodes.

2. **Eliminates the `audio` group hack:** `systemd-sysusers` understands group merging across `/usr/lib/group` and `/etc/group`. The current `sed -i '/^audio:/d' /etc/group && echo 'audio:x:63:core' >> /etc/group` line in the Containerfile is fragile and documents its own fragility in a comment. Replacing it with a sysusers declaration removes both the hack and the comment.

3. **Eliminates the linger pre-creation hack:** `tmpfiles.d` can create `/var/lib/systemd/linger/core` on first boot via a `f` or `F` type rule, with correct ownership, without baking it into the image layer. Or better: `inferno-configure.sh` can call `loginctl enable-linger core` which already works — the pre-creation hack exists to compensate for timing, which sysusers would fix by ensuring group membership is correct before any user session starts.

4. **Declarative `/var/` structure:** `tmpfiles.d` creates persistent directories (`/var/lib/inferno/`, `/var/home/core/.config/`, `/var/home/core/bin/`) idempotently on every boot, with correct ownership. Currently `mkdir -p` calls are scattered across `inferno-configure.sh` with no ownership guarantees.

##### Why NOT implement (or defer)?

The risk is the transition. The current `core` user was created by `useradd` and lives in `/etc/passwd`. If the Containerfile switches to sysusers and the existing node already has a `core` user from the old method, `systemd-sysusers` will attempt to reconcile — usually harmlessly, but UID conflicts or `/etc/shadow` format mismatches could lock the user out. This needs careful testing on an upgrade path (not just a fresh install).

Additionally, the password hash for `core` must be set somewhere. `sysusers.d` does not support password hashes — it creates system users without passwords. The password must be set via Ignition (which already sets `passwordHash`) or via a first-boot script. This is not a blocker but requires ensuring the Ignition password hash takes precedence.

**Recommendation: implement, but test the upgrade path from an existing deployed node before shipping.**

##### Implementation notes

1. Create `/usr/lib/sysusers.d/inferno.conf` in the Containerfile (place before the `useradd` block, then remove `useradd`/`chpasswd`/`sed`):
   ```
   # /usr/lib/sysusers.d/inferno.conf
   u core - "Inferno AoIP user" /var/home/core /bin/bash
   m core audio
   m core wheel
   m core render
   ```
   The `u` directive creates the user if absent, reconciles if present. The `m` directives add group membership idempotently.

2. Create `/usr/lib/tmpfiles.d/inferno.conf`:
   ```
   # /usr/lib/tmpfiles.d/inferno.conf
   d /var/home/core                    0700 core core -
   d /var/home/core/.config            0700 core core -
   d /var/home/core/.config/systemd    0700 core core -
   d /var/home/core/.config/systemd/user 0700 core core -
   d /var/home/core/bin                0755 core core -
   d /var/home/core/.cache             0700 core core -
   d /var/home/core/.local             0700 core core -
   d /var/home/core/.local/state       0700 core core -
   d /var/lib/inferno                  0755 root root -
   d /var/lib/inferno/bin              0755 root root -
   f /var/lib/systemd/linger/core      0644 root root -
   ```
   The `f` line for the linger file replaces the `touch /var/lib/systemd/linger/core` Containerfile hack.

3. Remove from the Containerfile:
   ```dockerfile
   # Remove these lines:
   RUN useradd -m -d /var/home/core -G wheel -s /bin/bash core && \
       echo "core:inferno123" | chpasswd && \
       sed -i '/^audio:/d' /etc/group && echo 'audio:x:63:core' >> /etc/group && \
       mkdir -p /var/lib/systemd/linger && touch /var/lib/systemd/linger/core
   ```

4. The password `inferno123` is set via Ignition's `passwordHash` field — this already works. Verify the hash format is compatible with the bootc image's PAM stack (`yescrypt` on Fedora 41+).

5. Keep the `realtime-setup.conf` sysusers entry that already exists in the Containerfile for the `@realtime` group — it confirms the sysusers mechanism already works in this image, reducing integration risk.

6. Test the upgrade path: deploy a node with the old Containerfile, apply a new image using the sysusers approach, reboot, verify `id core` shows correct groups and login works.

---

> Detail block moved to Deferred section below.

---

---

#### Item 15 — Version Sentinel Comparison in `inferno-configure.sh`

**Importance:** 🟠 High  
**Impact:** Config changes baked into new image versions actually reach deployed nodes instead of being silently ignored  
**Difficulty:** Medium (half-day)  
**Risk:** Medium  
**Prerequisites:** BUG-01  

> **Implementation note:** Must be scaffolded in stages — (1) detect firstboot vs upgrade cleanly, (2) write sentinel on firstboot completion, (3) build migration hook system before any migration logic, (4) test each stage independently. No monolithic rewrite.

##### What is it?

`/etc/inferno.conf` is the sentinel that gates `inferno-configure.sh`. If the file exists, the script exits immediately — meaning any config template changes (new systemd units, updated `snd-aloop` parameters, revised ALSA conf) delivered in a new image version are never applied to nodes that have already completed first boot.

Proposed fix: bake `IMAGE_VERSION=vN` into the image (e.g. via a label or a file at `/usr/lib/inferno/image-version`). At boot, `inferno-configure.sh` reads the sentinel's recorded version and compares it to the image version. If they differ, it re-runs configure — preserving user-provided values (`INFERNO_NAME`, `INFERNO_NIC`) from the old sentinel while regenerating everything else from the new templates.

##### Why implement?

Without this, upgrading the image is cosmetically correct (the OS is updated) but operationally incomplete. Any service unit changes, new ALSA plugin parameters, or revised systemd `ExecStart` lines in the new image are dead on arrival. As the project matures and configuration grows more complex, silent skips will cause hard-to-diagnose divergence between the image spec and actual running config.

##### Why NOT implement (or defer)?

The medium risk rating is real. If `inferno-configure.sh` re-runs and contains a bug, it could overwrite a working config on a live node. Mitigation: the script must read and re-inject user values before writing anything. Test thoroughly on a VM before shipping. Defer only if the project's config templates are genuinely stable and no image version has changed them — unlikely past v1.

##### Implementation notes

1. In `Containerfile`, add a build arg and write the version to a read-only path:
   ```dockerfile
   ARG IMAGE_VERSION=dev
   RUN echo "${IMAGE_VERSION}" > /usr/lib/inferno/image-version
   ```
2. In `build/build-release.sh`, pass `--build-arg IMAGE_VERSION=${TAG}` to `podman build`.
3. In `inferno-configure.sh`, at the top of the sentinel check:
   ```bash
   IMAGE_VER=$(cat /usr/lib/inferno/image-version 2>/dev/null || echo "unknown")
   SENTINEL_VER=$(grep ^IMAGE_VERSION= /etc/inferno.conf 2>/dev/null | cut -d= -f2 || echo "none")

   if [[ "${SENTINEL_VER}" == "${IMAGE_VER}" ]]; then
       exit 0  # already configured for this version
   fi

   # Re-run: preserve user values
   INFERNO_NAME=$(grep ^INFERNO_NAME= /etc/inferno.conf | cut -d= -f2)
   INFERNO_NIC=$(grep ^INFERNO_NIC= /etc/inferno.conf | cut -d= -f2)
   ```
4. After configure completes, write `IMAGE_VERSION=${IMAGE_VER}` into `/etc/inferno.conf`.
5. The sentinel now serves dual purpose: "configured" flag + version record. Old nodes without `IMAGE_VERSION=` in their sentinel get treated as `none` and re-run on first upgrade — acceptable, expected behaviour.

---

---

#### Item 19 — Delta / Layer-Based Upgrades via Local OCI Registry

> **✅ IMPLEMENTED** — Already implemented in `cockpit-iot-updater` `apply-update.sh` — `bundle_type=delta` path using bsdiff/bspatch. Discovered resolved April 2026. Full detail archived in [archived/IMPROVEMENT_ROADMAP_DONE.md](archived/IMPROVEMENT_ROADMAP_DONE.md).
---

---

---

#### Item 26 — Default Password Policy

**Importance:** 🔴 Critical  
**Impact:** Eliminates a hardcoded, publicly-known credential from all deployed nodes  
**Difficulty:** Easy  
**Risk:** Low  
**Prerequisites:** None  

##### What is it?

The default `core` user is given the password `inferno123` in the Containerfile. This password is committed to a public GitHub repository, meaning it is effectively public knowledge. Every deployed node ships with the same credential unless manually changed post-install.

##### Why implement?

A hardcoded password in a public repo is not a "weak default" — it is a published credential. Any device reachable on the LAN (or reachable via VPN, jump host, or misrouted traffic) can be logged into by anyone who has read the repo. This is a real threat even on a private LAN: guests, contractors, or compromised devices can pivot laterally. The password is also likely to survive image upgrades if users don't know to change it.

**Recommended approach: Lock the password and require SSH key injection via Ignition.**

Add to Containerfile:

```dockerfile
RUN passwd --lock core
```

Document in `DEPLOY.md` that deployers must supply an SSH public key via an Ignition config or kickstart `%post` before first boot. This is consistent with how production bootc/Fedora IoT deployments are expected to work.

If SSH key injection is too operationally complex for the target audience, use the **expire** approach as a fallback:

```dockerfile
RUN chage -d 0 core
```

This forces a password change on first SSH login. The initial password is still `inferno123`, but it cannot be reused after first login.

Do **not** leave `inferno123` as a standing default.

##### Why NOT implement (or defer)?

Locking the password entirely (`passwd --lock`) breaks console recovery on a headless node if SSH keys are lost. In a home-lab scenario with physical access and no Ignition tooling, this creates a recovery dead end. In that case, prefer `chage -d 0` (expire on first use) over locking.

##### Implementation notes

1. In `Containerfile`, replace the current `passwd` invocation with:
   ```dockerfile
   RUN passwd --lock core
   # OR, if physical console recovery must remain possible:
   RUN chage -d 0 core
   ```
2. Add an `ignition/example.ign` to the repo with a skeleton Ignition config showing how to inject an `authorized_keys` entry for `core`.
3. Update `DEPLOY.md` with a prerequisite section: "Before first boot, you must inject your SSH public key."
4. Remove any documentation that treats `inferno123` as the expected login password.

---

---

#### Item 57 — Cockpit First-Login Password Prompt

| Field | Value |
|---|---|
| **Category** | Security |
| **Importance** | 🟠 High |
| **Difficulty** | Medium (half-day) |
| **Risk** | Low |
| **Prerequisites** | None |

**Problem:** The appliance ships with a known default credential (`core / inferno123`). Without enforcement, operators may leave this unchanged, exposing the appliance to unauthorized access.

**Solution:** On first login to the Cockpit web UI, detect that the default credential is still in use and show a prominent prompt to change the password. Implemented in `cockpit-inferno` UI.

**Why now:** Replaces the rejected Item 27 approach (disabling SSH password auth). A first-login prompt ensures operators change the default credential without blocking SSH access for those who haven't pre-provisioned keys.

**Why not:** Requires coordination between cockpit-inferno and the appliance image. If Cockpit is bypassed, password is never prompted.

---

> Detail block moved to Deferred section below.

---

---

#### Item 59 — `restorecon` for User Home Dir in `inferno-configure.sh`

**Importance:** 🔴 Critical  
**Impact:** Fixes broken SSH key authentication on all deployed nodes caused by wrong SELinux labels  
**Difficulty:** Easy (<2h)  
**Risk:** Low  
**Prerequisites:** None  

##### What is it?

This is the configure-script fix for BUG-05. Ignition creates `/var/home/core/.ssh/authorized_keys` but the resulting SELinux label is `unlabeled_t` instead of `ssh_home_t`. Adding `restorecon -Rv /var/home/core/` to `inferno-configure.sh` after the `chown -R core:core` call (~line 215) fixes the labels on first boot and on every upgrade re-run.

##### Why implement?

Without correct SELinux labels, SSH key auth is silently denied on all deployed nodes. This is a single line fix that prevents a potentially node-bricking scenario once password auth is disabled.

##### Why NOT implement (or defer)?

No reason to defer. One line, zero risk, idempotent.

##### Implementation notes

```bash
# In inferno-configure.sh, after: chown -R core:core "${CORE_HOME}"
restorecon -Rv /var/home/core/ 2>/dev/null || true
```

See BUG-05 for full context and verification steps.

---

---

#### Item 48 — Health HTTP Endpoint

**Status:** ✅ Implemented — `legopc/cockpit-inferno` (2026-04-07). Monitoring tab → Health Check panel runs on demand; checks: snd-aloop loaded, PTP locked, inferno-bridge active, librespot active, statime-inferno active, disk < 80%, NIC has IP.

**Importance:** 🟠 High  
**Impact:** Enables external monitoring (Prometheus, Proxmox checks, LAN cron) without SSH  
**Difficulty:** Easy (<2h)  
**Risk:** Low  
**Prerequisites:** None  

##### What is it?

A lightweight JSON endpoint at `http://node:8080/health` served by the existing Python sidecar. The response reports the systemd active state of the four critical services:

```json
{
  "status": "ok",
  "services": {
    "statime-inferno": "active",
    "librespot": "active",
    "inferno-bridge": "active",
    "inferno-keepalive": "active"
  },
  "dante_device_open": true,
  "timestamp": "2025-07-03T14:22:01Z"
}
```

`status` is `"ok"` only when all required services are `active`. Otherwise it is `"degraded"`, and the HTTP response code is 503. This allows monitoring tools to use the status code without parsing JSON.

##### Why implement?

The appliance is headless. The only way to currently detect a crashed `librespot` or a dead `inferno-bridge` is SSH or Cockpit. Neither is scriptable for automated monitoring without extra tooling. An HTTP endpoint at port 8080 requires:

- One Prometheus scrape rule, or
- One `curl` in a Proxmox health check script, or
- One LAN cron job that pages on 503

This is the lowest-effort monitoring integration possible, and it pays dividends across every environment the appliance is deployed in.

##### Why NOT implement (or defer)?

Port 8080 needs to be open in `firewalld`. If the firewall zone policy is strict, adding a port has a review cost. The sidecar is currently bound to `localhost` for Cockpit's reverse proxy — binding it to `0.0.0.0:8080` exposes it to the LAN. This is acceptable for an AV appliance on a trusted LAN, but should be documented.

If the environment requires HTTPS-only monitoring, this endpoint would need TLS termination (nginx or the sidecar itself). Defer the HTTPS requirement — the monitoring target is a LAN-only appliance, not an internet-facing service.

##### Implementation notes

1. Extend `sidecar/server.py`:

   ```python
   import subprocess, datetime, json

   def get_service_state(service, user=False):
       cmd = ["systemctl"]
       if user:
           cmd += ["--user"]
       cmd += ["is-active", "--quiet", service]
       result = subprocess.run(cmd, capture_output=True)
       return "active" if result.returncode == 0 else "inactive"

   @app.route("/health")
   def health():
       services = {
           "statime-inferno": get_service_state("statime-inferno"),
           "librespot": get_service_state("librespot", user=True),
           "inferno-bridge": get_service_state("inferno-bridge", user=True),
           "inferno-keepalive": get_service_state("inferno-keepalive", user=True),
       }
       all_ok = all(v == "active" for v in services.values())
       payload = {
           "status": "ok" if all_ok else "degraded",
           "services": services,
           "timestamp": datetime.datetime.utcnow().isoformat() + "Z",
       }
       return app.response_class(
           response=json.dumps(payload),
           status=200 if all_ok else 503,
           mimetype="application/json"
       )
   ```

2. Bind the sidecar to `0.0.0.0:8080` (or make the bind address configurable via `/etc/inferno.conf`):
   ```bash
   # In sidecar systemd unit ExecStart:
   ExecStart=/usr/bin/python3 /usr/lib/iot-updater/sidecar/server.py --host 0.0.0.0 --port 8080
   ```

3. Open the port in the Containerfile:
   ```bash
   RUN firewall-offline-cmd --add-port=8080/tcp
   ```

4. For Prometheus, add a scrape config:
   ```yaml
   - job_name: 'inferno'
     metrics_path: '/health'
     static_configs:
       - targets: ['inferno-abc123.local:8080']
   ```
   Note: `/health` returns JSON, not Prometheus text format. Use `json_exporter` as a proxy, or add a `/metrics` endpoint (separate item) once the health endpoint is stable.

---

> Detail block moved to Deferred section below.

---

---

