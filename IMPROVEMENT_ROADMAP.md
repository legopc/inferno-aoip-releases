# Inferno AoIP Appliance -- Improvement Roadmap

> **Document type:** Engineering backlog  
> **Scope:** Fedora bootc appliance (installer, first-boot, runtime, upgrade, build pipeline, operations)  
> **Last triaged:** April 2026 -- Sprint planning session  
> **Active:** 42 items (15 Sprint 2 / 18 later / 9 on hold)  
> **Deferred:** 6  
> **Archived:** resolved -> [IMPROVEMENT_ROADMAP_DONE.md](archived/IMPROVEMENT_ROADMAP_DONE.md) | rejected -> [IMPROVEMENT_ROADMAP_REJECTED.md](archived/IMPROVEMENT_ROADMAP_REJECTED.md)

## How to Read This Document

| Field | Values |
|---|---|
| **Importance** | Critical / High / Medium / Low |
| **Difficulty** | Easy (<2h) / Medium (half-day) / Hard (multi-day) |
| **Risk** | Low / Medium / High -- chance of regressions |
| **Sprint** | Sprint 2 (next) / Later / On Hold / Deferred |

---

## Sprint Plan

### Sprint 2 -- Next Up (15 items)

| ID | Category | Title | Importance | Difficulty |
|---|---|---|---|---|
| BUG-08 | Bug | apply-update.sh Uses eval with Python Heredoc | High | Medium |
| 97 | RT/Reliability | Disable RT Throttling (sched_rt_runtime_us=-1) | High | Easy |
| 104 | Upgrades | bootc Switch Rollback via FailureAction= | High | Easy |
| 105 | Security | Cockpit CSP Hardening (Remove unsafe-inline) | High | Easy |
| 73 | Build | BATS Test Suite for Shell Scripts | Medium | Hard |
| 76 | RT/Reliability | Explicit Systemd Service Dependencies Between User Services | Medium | Easy |
| 78 | Operations | Log Rotation for Custom Script Logs | Medium | Easy |
| 79 | Upgrades | Config Backup Before OTA Update | Medium | Easy |
| 80 | First-boot | Boot-Time Disk Space and RAM Check | Medium | Easy |
| 89 | Network/Dante | PTP Offset Alerting Threshold | Medium | Medium |
| 92 | First-boot | inferno-configure.sh Idempotent Re-Run Mode | Medium | Medium |
| 103 | RT/Reliability | NIC TX Queue and Ring Buffer Tuning | Medium | Easy |
| FR-01 | Operations | Factory Reset: Full Wipe and Re-Configure | Medium | Medium |
| 67 | Build | Remove/Redact Hardcoded IPs from Bench Scripts | Low | Easy |
| 70 | Build | Add --setopt=tsflags=nodocs to DNF Install | Low | Easy |

### Later Sprints (18 items)

| ID | Category | Title | Importance | Difficulty |
|---|---|---|---|---|
| 62 | Security | Restrict sudo to Specific Inferno Commands | High | Easy |
| 65 | Security | Firewall Configuration (nftables) | High | Medium |
| 106 | Security | statime-inferno.service Capability Sandboxing | High | Easy |
| 68 | Build | Add .containerignore to Reduce Build Context Size | Medium | Easy |
| 74 | Operations | Continuous Health Monitoring Daemon | Medium | Medium |
| 75 | RT/Reliability | Resource Limits in Service Units (MemoryMax, TasksMax, CPUQuota) | Medium | Easy |
| 85 | Network/Dante | DSCP/QoS Marking for Dante Audio Traffic | Medium | Medium |
| 88 | Network/Dante | Configurable PTP Domain Number | Medium | Easy |
| 95 | Operations | Cockpit Configuration Export/Import | Medium | Medium |
| 96 | Operations | Cockpit In-App Help / Troubleshooting Runbook | Medium | Medium |
| 108 | Build | kargs.d/ for Declarative Kernel Args | Medium | Easy |
| 111 | Build | cockpit.transport.wait() for Plugin Init | Medium | Easy |
| 60 | Operations | dante-network-bench.sh Default Timeout 3s to 8s | Low | Easy |
| 71 | Build | Tag Releases on Submodule Repositories | Low | Easy |
| 72 | Build | Consolidate Containerfile RUN Layers | Low | Medium |
| 77 | RT/Reliability | Restart Backoff Strategy for Flapping Services | Low | Easy |
| 91 | RT/Reliability | statime Log Level: trace to info in Production | Low | Easy |
| 94 | First-boot | librespot Cache Size Limit | Low | Easy |

### On Hold -- Pending Decision (9 items)

| ID | Category | Title | Notes |
|---|---|---|---|
| 63 | Security | Enable OTA Bundle Signature Enforcement by Default |  |
| 98 | RT/Reliability | RT CPU Isolation (isolcpus + nohz_full + rcu_nocbs) | Must be dynamic: only apply CPU isolation on 4-core+ systems. Configurable via configure script, not baked into image. |
| 107 | RT/Reliability | WatchdogSec= for Critical Audio Services |  |
| 81 | Operations | User Action Audit Trail in Cockpit UI |  |
| 83 | Operations | Central Logging via systemd-journal-remote | Only implement if the remote syslog server URL can be configured from within the Cockpit UI. |
| 99 | RT/Reliability | NIC Interrupt Pinning Away from RT CPUs |  |
| 102 | Network/Dante | IGMP Multicast Group Membership for Dante |  |
| 109 | Security | Bundle Manifest valid_from Anti-Replay |  |
| 110 | Security | SELinux Policy Module for inferno_aoip |  |

---

## Active Items -- Executive Summary

| ID | Category | Title | Importance | Difficulty | Risk | Prerequisites | Sprint |
|---|---|---|---|---|---|---|---|
| BUG-07 | Bug | Credentials Committed to Documentation Files | Critical | Easy | Low | None | (tracked separately) |
| 100 | Hardware | Hardware PTP Timestamping Enforcement | Critical | Easy | Low | None | (tracked separately) |
| BUG-08 | Bug | apply-update.sh Uses eval with Python Heredoc | High | Medium | Medium | None | Sprint 2 |
| 97 | RT/Reliability | Disable RT Throttling (sched_rt_runtime_us=-1) | High | Easy | Low | None | Sprint 2 |
| 104 | Upgrades | bootc Switch Rollback via FailureAction= | High | Easy | Low | None | Sprint 2 |
| 105 | Security | Cockpit CSP Hardening (Remove unsafe-inline) | High | Easy | Low | None | Sprint 2 |
| 73 | Build | BATS Test Suite for Shell Scripts | Medium | Hard | Low | None | Sprint 2 |
| 76 | RT/Reliability | Explicit Systemd Service Dependencies Between User Services | Medium | Easy | Low | None | Sprint 2 |
| 78 | Operations | Log Rotation for Custom Script Logs | Medium | Easy | Low | None | Sprint 2 |
| 79 | Upgrades | Config Backup Before OTA Update | Medium | Easy | Low | None | Sprint 2 |
| 80 | First-boot | Boot-Time Disk Space and RAM Check | Medium | Easy | Low | None | Sprint 2 |
| 89 | Network/Dante | PTP Offset Alerting Threshold | Medium | Medium | Low | 74 | Sprint 2 |
| 92 | First-boot | inferno-configure.sh Idempotent Re-Run Mode | Medium | Medium | Medium | None | Sprint 2 |
| 103 | RT/Reliability | NIC TX Queue and Ring Buffer Tuning | Medium | Easy | Low | None | Sprint 2 |
| FR-01 | Operations | Factory Reset: Full Wipe and Re-Configure | Medium | Medium | Low | None | Sprint 2 |
| 67 | Build | Remove/Redact Hardcoded IPs from Bench Scripts | Low | Easy | Low | None | Sprint 2 |
| 70 | Build | Add --setopt=tsflags=nodocs to DNF Install | Low | Easy | Low | None | Sprint 2 |
| 62 | Security | Restrict sudo to Specific Inferno Commands | High | Easy | Low | None | Later |
| 65 | Security | Firewall Configuration (nftables) | High | Medium | Medium | None | Later |
| 106 | Security | statime-inferno.service Capability Sandboxing | High | Easy | Medium | None | Later |
| 68 | Build | Add .containerignore to Reduce Build Context Size | Medium | Easy | Low | None | Later |
| 74 | Operations | Continuous Health Monitoring Daemon | Medium | Medium | Low | None | Later |
| 75 | RT/Reliability | Resource Limits in Service Units (MemoryMax, TasksMax, CPUQuota) | Medium | Easy | Low | None | Later |
| 85 | Network/Dante | DSCP/QoS Marking for Dante Audio Traffic | Medium | Medium | Medium | 65 | Later |
| 88 | Network/Dante | Configurable PTP Domain Number | Medium | Easy | Low | None | Later |
| 95 | Operations | Cockpit Configuration Export/Import | Medium | Medium | Low | None | Later |
| 96 | Operations | Cockpit In-App Help / Troubleshooting Runbook | Medium | Medium | Low | None | Later |
| 108 | Build | kargs.d/ for Declarative Kernel Args | Medium | Easy | Low | None | Later |
| 111 | Build | cockpit.transport.wait() for Plugin Init | Medium | Easy | Low | None | Later |
| 60 | Operations | dante-network-bench.sh Default Timeout 3s to 8s | Low | Easy | Low | None | Later |
| 71 | Build | Tag Releases on Submodule Repositories | Low | Easy | Low | None | Later |
| 72 | Build | Consolidate Containerfile RUN Layers | Low | Medium | Low | None | Later |
| 77 | RT/Reliability | Restart Backoff Strategy for Flapping Services | Low | Easy | Low | None | Later |
| 91 | RT/Reliability | statime Log Level: trace to info in Production | Low | Easy | Low | None | Later |
| 94 | First-boot | librespot Cache Size Limit | Low | Easy | Low | None | Later |
| 63 | Security | Enable OTA Bundle Signature Enforcement by Default | High | Easy | Low | None | On Hold |
| 98 | RT/Reliability | RT CPU Isolation (isolcpus + nohz_full + rcu_nocbs) | High | Medium | Medium | 97, 108 | On Hold |
| 107 | RT/Reliability | WatchdogSec= for Critical Audio Services | High | Medium | Low | None | On Hold |
| 81 | Operations | User Action Audit Trail in Cockpit UI | Medium | Medium | Low | None | On Hold |
| 83 | Operations | Central Logging via systemd-journal-remote | Medium | Medium | Low | None | On Hold |
| 99 | RT/Reliability | NIC Interrupt Pinning Away from RT CPUs | Medium | Medium | Medium | 98 | On Hold |
| 102 | Network/Dante | IGMP Multicast Group Membership for Dante | Medium | Easy | Low | None | On Hold |
| 109 | Security | Bundle Manifest valid_from Anti-Replay | Medium | Medium | Low | 63 | On Hold |
| 110 | Security | SELinux Policy Module for inferno_aoip | Medium | Hard | Medium | 63, 106 | On Hold |
| 4 | Install | GRUB / Boot Screen Branding via BIB | Medium | Medium | Low | None | Deferred |
| 24 | First-boot | Eliminate Reboot at End of inferno-configure.sh | Deferred | Medium | Medium | 11 | Deferred |
| 29 | Security | Image Signing with cosign/sigstore | Deferred | Hard | Low | None | Deferred |
| 32 | Security | Cockpit TLS: Custom Certificate | Deferred | Medium | Low | None | Deferred |
| 37 | RT/Reliability | IRQ Affinity / CPU Isolation | Deferred | Hard | Medium | None | Deferred |
| 56 | Operations | Cockpit: Certificate Management | Deferred | Medium | Medium | None | Deferred |

---


## Bug Fixes

| ID | Title | Importance | Difficulty | Risk | Prerequisites | Sprint |
|---|---|---|---|---|---|---|
| BUG-07 | Credentials Committed to Documentation Files | Critical | Easy | Low | None | (tracked separately) |
| BUG-08 | apply-update.sh Uses eval with Python Heredoc | High | Medium | Medium | None | Sprint 2 |

---

#### BUG-07 — Credentials Committed to Documentation Files
> Tracked separately -- excluded from sprint planning

**Importance:** 🔴 Critical  
**Impact:** Reduces risk of credential exposure from documentation files in the repository  
**Difficulty:** Easy (<2h)  
**Risk:** Low  
**Prerequisites:** None  

##### What is it?

`cockpit-iot-updater/docs/DEPLOYMENT-V9.md` and `BUILDING-UPDATES.md` contain the plaintext password `(redacted)` for `root@10.10.1.201`. Even in a private or local repository, committing credentials is bad practice. If the repo is ever made public, cloned to a less-secure machine, or pushed to a CI system, the credential leaks.

##### Why implement?

Even if the password has been rotated, the pattern of committing credentials is the issue. Scrubbing and adding tooling (`.git-secrets` or a `pre-commit` hook) prevents recurrence.

##### Why NOT implement (or defer)?

Scrubbing git history (via `git filter-branch` or `git filter-repo`) is operationally complex and rewrites commits. For a private/local repo, scrubbing the current working tree and rotating the credential is sufficient. Full history rewrite is optional.

##### Implementation notes

1. Replace literal passwords in docs with `<REDACTED>` placeholders.
2. Rotate the password on `10.10.1.201`.
3. Add `.gitleaks.toml` or `.git-secrets` config to detect credential patterns:
   ```toml
   # .gitleaks.toml
   [[rules]]
   description = "Password in plain text"
   regex = '''password\s*=\s*['"][^'"]{8,}['"]'''
   ```
4. Add a pre-commit hook: `git secrets --install && git secrets --register-aws`.

---

#### BUG-08 -- apply-update.sh Uses eval with Python Heredoc
> Sprint 2 -- scheduled for next sprint

**Importance:** High
**Impact:** Eliminates remote code execution risk in the OTA update path
**Difficulty:** Medium
**Risk:** Medium
**Prerequisites:** None

##### What is it?
`apply-update.sh` uses `eval` to execute a Python heredoc passed from the OTA payload. If the payload is tampered with or if a path injection is possible, `eval` allows arbitrary code execution on the appliance with the privileges of the update service.

##### Why implement?
The update path is a privileged, trusted code channel. Using `eval` on externally-sourced content is one of the highest-risk patterns in shell scripting. Replace with explicit argument passing or a signed script approach.

##### Implementation notes
1. Identify all `eval` calls in `apply-update.sh` and trace their input sources.
2. Replace heredoc+eval pattern with explicit function calls or a Python script called with arguments.
3. Validate that the update path cannot be influenced by payload content beyond the intended update action.

---

---


## Hardware Detection

| ID | Title | Importance | Difficulty | Risk | Prerequisites | Sprint |
|---|---|---|---|---|---|---|
| 100 | Hardware PTP Timestamping Enforcement | Critical | Easy | Low | None | (tracked separately) |

---

#### Item 100 — Hardware PTP Timestamping Enforcement
> Tracked separately -- excluded from sprint planning

**Importance:** 🔴 Critical  
**Impact:** Guarantees sub-microsecond PTP precision on supporting NICs; provides clear diagnostic when hardware timestamping is unavailable  
**Difficulty:** Easy  
**Risk:** Low  
**Prerequisites:** None

##### What is it?
`inferno-configure.sh` detects hardware PTP capability (Item 12) but `inferno-ptpv1.toml` uses `hardware-clock = "auto"` — silently falling back to software timestamps if hardware timestamps fail. Software PTP timestamps have 10-100× worse accuracy. There's no log entry or health status to indicate which mode is active.

##### Why implement?
On NICs that support hardware timestamping (Intel i210, i219, I225 — all common in EliteDesk hardware), software fallback represents a massive quality regression with zero operator visibility. Inferno nodes that silently fall back to SW timestamps will have noticeably worse Dante audio quality but no obvious cause.

##### Why NOT implement (or defer)?
Some deployment NICs genuinely don't support hardware timestamping. Hard-failing would block deployment on those nodes. Must warn clearly but not block.

##### Implementation notes
```bash
# inferno-configure.sh — extend existing HW_PTP detection block
if [ "${HW_PTP_AVAILABLE:-no}" = "yes" ]; then
    PTP_DEV=$(ls /sys/class/net/"$INFERNO_NIC"/device/ptp/ 2>/dev/null | head -1)
    if test -c "/dev/${PTP_DEV:-ptpX}"; then
        echo "HW_PTP_DEVICE=/dev/$PTP_DEV" >> /etc/inferno.conf
        ethtool -T "$INFERNO_NIC" 2>/dev/null | grep -q "hardware-transmit" && \
            echo "✓ Hardware PTP timestamps confirmed on $INFERNO_NIC" || \
            echo "WARNING: NIC reports PTP support but hardware-transmit not listed"
    else
        echo "WARNING: HW PTP claimed but /dev/$PTP_DEV not accessible — using SW timestamps"
    fi
fi
```
Surface `HW_PTP_DEVICE` value in Cockpit Services tab PTP card.

---

---


## First-Boot and Provisioning

| ID | Title | Importance | Difficulty | Risk | Prerequisites | Sprint |
|---|---|---|---|---|---|---|
| 80 | Boot-Time Disk Space and RAM Check | Medium | Easy | Low | None | Sprint 2 |
| 92 | inferno-configure.sh Idempotent Re-Run Mode | Medium | Medium | Medium | None | Sprint 2 |
| 94 | librespot Cache Size Limit | Low | Easy | Low | None | Later |

---

#### Item 80 — Boot-Time Disk Space and RAM Check
> Sprint 2 -- scheduled for next sprint

**Importance:** 🟡 Medium  
**Impact:** Provides a clear error message instead of mysterious failures when hardware is undersized  
**Difficulty:** Easy (<2h)  
**Risk:** Low  
**Prerequisites:** None  

##### What is it?

`inferno-configure.sh` does not check available disk space or RAM before proceeding. On a node with a full `/var` partition or less than 2GB RAM, configure will fail in unpredictable ways mid-execution. An upfront check with a human-readable warning message is far better UX.

##### Why implement?

Operators deploying to unknown or salvaged hardware get cryptic failures that are difficult to diagnose remotely. A `WARNING: Only 512MB RAM detected, minimum 2GB required` message at the top of the configure log immediately narrows the problem space.

##### Why NOT implement (or defer)?

Checks are non-fatal warnings, not blocking errors — the script continues regardless. This ensures unusual hardware that might work despite the warnings isn't accidentally blocked. Adjust thresholds if minimum hardware specs change.

##### Implementation notes

Add at the start of `inferno-configure.sh` (before the sentinel check):

```bash
# Hardware sanity checks (warnings only — do not block execution)
FREE_MB=$(df /var --output=avail -m 2>/dev/null | tail -1 | tr -d ' ')
if [ -n "$FREE_MB" ] && [ "$FREE_MB" -lt 2048 ]; then
    echo "WARNING: Only ${FREE_MB}MB free on /var — recommend 2GB+ for OTA updates and logs"
fi

RAM_MB=$(awk '/MemTotal/ {print int($2/1024)}' /proc/meminfo 2>/dev/null)
if [ -n "$RAM_MB" ] && [ "$RAM_MB" -lt 1900 ]; then
    echo "WARNING: Only ${RAM_MB}MB RAM — Dante may be unstable under heavy load (recommend 4GB)"
fi
```

---

---

#### Item 92 — `inferno-configure.sh` Idempotent Re-Run Mode
> Sprint 2 -- scheduled for next sprint

**Importance:** 🟡 Medium  
**Impact:** Allows reconfiguring NIC/name/mode without requiring a full reboot and sentinel deletion  
**Difficulty:** Medium (half-day)  
**Risk:** Medium  
**Prerequisites:** None  

##### What is it?

To reconfigure a deployed node today, an operator must `rm /etc/inferno.conf && reboot` — a blunt instrument that re-runs the full first-boot sequence. A targeted re-run mode (`inferno-configure.sh --reconfigure --nic enp3s0`) would re-detect hardware and rewrite configs without requiring a full reboot cycle. This is especially valuable during on-site troubleshooting.

##### Why implement?

NIC changes, hostname corrections, mode switches (Spotify ↔ AUX), and audio card changes currently require full first-boot cycle including reboot. A `--reconfigure` flag that re-runs specific sections would cut on-site troubleshooting time from 5 minutes to under 30 seconds.

##### Why NOT implement (or defer)?

Medium risk: if `--reconfigure` partially succeeds (e.g., rewrites templates but fails before restarting services), the system can be left in an inconsistent state. Implement with careful error handling and rollback of template files if any step fails. Test on VMs before shipping.

##### Implementation notes

Add argument parsing to `inferno-configure.sh`:

```bash
RECONFIGURE=0
NIC_OVERRIDE=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --reconfigure) RECONFIGURE=1 ;;
        --nic) NIC_OVERRIDE="$2"; shift ;;
    esac; shift
done

# Skip sentinel check if --reconfigure
if [[ $RECONFIGURE -eq 0 ]] && [[ -f /etc/inferno.conf ]]; then
    exit 0
fi
```

Skip `loginctl enable-linger core` and user service enablement steps if already configured (check `loginctl show-user core | grep -q Linger=yes`). Preserve existing `INFERNO_NAME` and other user values from current `/etc/inferno.conf` when re-running. Write updated sentinel at end.

---

---

#### Item 94 — librespot Cache Size Limit
> Later -- scheduled for a future sprint

**Importance:** 🟢 Low  
**Impact:** Prevents Spotify audio cache from filling `/var` on long-running nodes  
**Difficulty:** Easy (<2h)  
**Risk:** Low  
**Prerequisites:** None  

##### What is it?

`librespot.service` uses `--cache /var/home/core/.cache/librespot` with no size limit. librespot caches decoded audio to reduce buffering on repeat tracks. On a node used heavily for Spotify, this cache can grow to several GB over months, potentially filling `/var` and preventing journal writes, OTA bundle staging, and other critical operations.

##### Why implement?

`/var` is the writable partition in bootc. Cache growth is silent and unbounded. A simple `--cache-size-limit 512` flag in the librespot ExecStart caps the cache at 512MB — more than sufficient for smooth playback while protecting system stability.

##### Why NOT implement (or defer)?

No reason to defer. One flag addition to the service unit, zero risk.

##### Implementation notes

In `librespot.service` ExecStart, add `--cache-size-limit 512` (in megabytes). Also consider adding a cleanup trigger in `inferno-monitor.sh` (Item 74): if cache directory exceeds 400MB, trim the oldest cached files.

---

---


## Upgrades

| ID | Title | Importance | Difficulty | Risk | Prerequisites | Sprint |
|---|---|---|---|---|---|---|
| 79 | Config Backup Before OTA Update | Medium | Easy | Low | None | Sprint 2 |
| 104 | bootc Switch Rollback via FailureAction= | High | Easy | Low | None | Sprint 2 |

---

#### Item 79 — Config Backup Before OTA Update
> Sprint 2 -- scheduled for next sprint

**Importance:** 🟡 Medium  
**Impact:** Allows config recovery if an OTA update resets or overwrites customised node settings  
**Difficulty:** Easy (<2h)  
**Risk:** Low  
**Prerequisites:** None  

##### What is it?

No backup is taken before applying an OTA update. If `apply-update.sh` or the new image's `inferno-configure.sh` overwrites `/etc/inferno.conf`, the ALSA config, or the statime TOML, operator-applied customisations are silently lost. A pre-update config backup provides a recovery point.

##### Why implement?

`/etc` is a mutable overlay in bootc — values do persist across updates in theory. But a misconfigured new image that resets conf templates would destroy customisation without warning. A 3-file tarball archived before every update costs almost nothing and saves significant recovery time in the field.

##### Why NOT implement (or defer)?

For fully automated rollback (Item 17), a config backup is redundant if the previous boot is still accessible. However, config backup protects against cases where the image upgrade succeeds but the new image's config template is incompatible — a scenario rollback doesn't protect against.

##### Implementation notes

Add to `apply-update.sh` pre-apply step:

```bash
BACKUP_DIR="/var/lib/inferno/backups"
mkdir -p "${BACKUP_DIR}"
BACKUP_FILE="${BACKUP_DIR}/config-pre-$(date +%Y%m%d%H%M%S).tar.gz"
tar -czf "${BACKUP_FILE}"     /etc/inferno.conf     /etc/alsa/conf.d/99-inferno.conf     /etc/statime-inferno.toml     2>/dev/null || true
echo "[backup] Config archived to ${BACKUP_FILE}"

# Keep only 3 most recent backups:
ls -t "${BACKUP_DIR}"/config-pre-*.tar.gz | tail -n +4 | xargs rm -f 2>/dev/null || true
```

Surface backup list and restore action in Cockpit Diagnostics tab (links to Item 81 audit trail).


---

---

#### Item 104 -- bootc Switch Rollback via FailureAction=
> Sprint 2 -- scheduled for next sprint

**Importance:** High  
**Impact:** Automatic rollback to previous image if new image fails to reach multi-user.target  
**Difficulty:** Easy  
**Risk:** Low  
**Prerequisites:** None

##### What is it?
After `bootc switch`, if the node hard-locks before reaching `multi-user.target`, there is no automatic recovery. Configuring a `FailureAction=` on the post-upgrade unit triggers rollback automatically.

##### Implementation
Configure bootc for automatic rollback on repeated boot failure via bootloader policy. Set `FailureAction=` on the post-upgrade unit to reboot into the previous deployment.

---


## Security

| ID | Title | Importance | Difficulty | Risk | Prerequisites | Sprint |
|---|---|---|---|---|---|---|
| 62 | Restrict sudo to Specific Inferno Commands | High | Easy | Low | None | Later |
| 63 | Enable OTA Bundle Signature Enforcement by Default | High | Easy | Low | None | On Hold |
| 65 | Firewall Configuration (nftables) | High | Medium | Medium | None | Later |
| 105 | Cockpit CSP Hardening (Remove unsafe-inline) | High | Easy | Low | None | Sprint 2 |
| 106 | statime-inferno.service Capability Sandboxing | High | Easy | Medium | None | Later |
| 109 | Bundle Manifest valid_from Anti-Replay | Medium | Medium | Low | 63 | On Hold |
| 110 | SELinux Policy Module for inferno_aoip | Medium | Hard | Medium | 63, 106 | On Hold |

---

#### Item 62 — Restrict `sudo` to Specific Inferno Commands
> Later -- scheduled for a future sprint
> Planning note: Preferred approach: add a separate end-user account and restrict sudo to that account only; keep `core` (manufacturer) unrestricted.

**Importance:** 🟠 High  
**Impact:** Reduces blast radius if the `core` user session is compromised via Cockpit or librespot  
**Difficulty:** Easy (<2h)  
**Risk:** Low  
**Prerequisites:** None  

##### What is it?

The current `Containerfile` contains: `echo "%wheel ALL=(ALL) NOPASSWD: ALL"` — granting passwordless root for any command to any wheel user. This should be scoped to the specific commands Cockpit and inferno scripts actually need: `systemctl`, `journalctl`, `cockpit`, `inferno-configure.sh`, `restorecon`, `hostnamectl`, `loginctl`.

##### Why implement?

`NOPASSWD: ALL` is the broadest possible sudo grant. An attacker with RCE in Cockpit, librespot, or any other user-level service gets full root without any additional barrier. A targeted sudoers file limits the damage to exactly the intended set of operations.

##### Why NOT implement (or defer)?

The risk is over-restriction: if Cockpit calls `sudo` for a command not in the whitelist, the operation silently fails. Requires careful auditing of all `spSudo()` calls in `inferno.js` before deploying. Start permissively and tighten over time.

##### Implementation notes

Replace `/etc/sudoers.d/wheel-nopasswd` in the Containerfile with a targeted file:

```bash
RUN cat > /etc/sudoers.d/inferno-core <<'EOF'
core ALL=(ALL) NOPASSWD:     /usr/bin/systemctl,     /usr/bin/journalctl,     /usr/sbin/restorecon,     /usr/bin/hostnamectl,     /usr/bin/loginctl,     /usr/bin/bootctl,     /usr/local/sbin/inferno-configure.sh
EOF
chmod 440 /etc/sudoers.d/inferno-core
```

Audit `cockpit-inferno/src/inferno.js` for all `spSudo()` and `cockpit.spawn(["sudo", ...])` calls to build the complete required list before shipping.

---

---

#### Item 63 — Enable OTA Bundle Signature Enforcement by Default
> On Hold -- pending decision

**Importance:** 🟠 High  
**Impact:** Prevents installation of unsigned or tampered OTA bundles on production nodes  
**Difficulty:** Easy (<2h)  
**Risk:** Low  
**Prerequisites:** None  

##### What is it?

`iot-updater/scripts/apply-update.sh` sets `ENFORCE_SIGNING="${IOT_UPDATER_ENFORCE_SIGNING:-0}"` — signature verification exists but defaults to disabled. The signing infrastructure (`tools/gen-signing-key.sh`, Ed25519 signing in `make-oci-bundle.sh`) is already built. Defaulting to enabled means production nodes reject unsigned bundles.

##### Why implement?

Signature verification infrastructure exists and works. Defaulting to disabled means the security feature is invisible in production. A single env var default change enables it fleet-wide. Dev workflow can override with `IOT_UPDATER_ENFORCE_SIGNING=0`.

##### Why NOT implement (or defer)?

All bundles must be signed before changing the default. If any existing bundles lack signatures, they become uninstallable. Coordinate with build pipeline (Item 69 BIB pinning) to ensure all released bundles are signed.

##### Implementation notes

1. In `apply-update.sh`, change: `ENFORCE_SIGNING="${IOT_UPDATER_ENFORCE_SIGNING:-0}"` → `ENFORCE_SIGNING="${IOT_UPDATER_ENFORCE_SIGNING:-1}"`
2. Add `IOT_UPDATER_ENFORCE_SIGNING=0` as a note in dev build documentation.
3. Optionally read from `/etc/inferno.conf`: `INFERNO_SIGNING_REQUIRED=yes` as an operator-visible knob.

---

---

#### Item 65 — Firewall Configuration (nftables) for Inferno Appliance
> Later -- scheduled for a future sprint

**Importance:** 🟠 High  
**Impact:** Limits attack surface to only the ports required for Dante/PTP/Cockpit; all others closed by default  
**Difficulty:** Medium (half-day)  
**Risk:** Medium  
**Prerequisites:** None  

##### What is it?

No firewall configuration exists in the current image. All ports are exposed on all interfaces by default. A professional AV appliance deployed on a shared network should expose only the ports required for its function: SSH (22), Cockpit (9090), Dante discovery (mDNS 5353/udp), Dante audio (6000–6999/udp), and PTP (319–320/udp).

##### Why implement?

Headless appliances on professional AV networks are frequently co-located with untrusted devices (guest networks, shared switches, conference room AV). A minimal firewall reduces exposure to port scans, stray connections, and potential interference with RT scheduling from unexpected inbound traffic.

##### Why NOT implement (or defer)?

Risk is medium because overly restrictive rules can break Dante discovery (mDNS multicast requires careful handling), PTP (multicast), and any future monitoring ports. Test thoroughly on a real Dante network before shipping. Note: Item 28 (firewalld) was rejected — this item uses nftables directly, which is cleaner for a bootc appliance without a full firewalld stack.

##### Implementation notes

Add to Containerfile:

```dockerfile
RUN dnf install -y nftables && systemctl enable nftables.service
COPY build/nftables.conf /etc/nftables.conf
```

`build/nftables.conf`:
```nft
table inet filter {
    chain input {
        type filter hook input priority 0; policy drop;
        ct state established,related accept
        iif lo accept
        ip protocol icmp accept
        tcp dport { 22, 9090, 8080 } accept
        udp dport { 5353, 319, 320 } accept
        udp dport 6000-6999 accept
    }
    chain forward { type filter hook forward priority 0; policy drop; }
    chain output { type filter hook output priority 0; policy accept; }
}
```

DSCP marking for Dante traffic can be added to this ruleset (see Item 85).

---

---

#### Item 105 -- Cockpit CSP Hardening (Remove unsafe-inline)
> Sprint 2 -- scheduled for next sprint

**Importance:** High  
**Impact:** Eliminates CSS/JS injection vector in Cockpit plugin  
**Difficulty:** Easy  
**Risk:** Low  
**Prerequisites:** None

##### What is it?
Current Cockpit plugin headers include `Content-Security-Policy: script-src 'unsafe-inline'`. Removing it closes the primary XSS attack vector.

##### Implementation
1. Move all inline `<script>` and `<style>` blocks to external files.
2. Update the CSP header in the plugin manifest to remove `unsafe-inline`.

---

#### Item 106 -- statime-inferno.service Capability Sandboxing
> Later -- scheduled for a future sprint
> Planning note: Requires thorough testing before committing. Verify statime operates correctly under the restricted capability set.

**Importance:** High  
**Impact:** Limits blast radius to only the two capabilities statime actually needs  
**Difficulty:** Easy  
**Risk:** Medium  
**Prerequisites:** None

##### What is it?
`statime` only needs `CAP_NET_ADMIN` and `CAP_SYS_TIME`. Currently it inherits ~35 capabilities. Adding `CapabilityBoundingSet=` restricts it to only those two.


##### Implementation
Add to `statime-inferno.service`:
```ini
[Service]
CapabilityBoundingSet=CAP_NET_ADMIN CAP_SYS_TIME
AmbientCapabilities=CAP_NET_ADMIN CAP_SYS_TIME
NoNewPrivileges=true
```

---

#### Item 109 — Bundle Manifest `valid_from` Anti-Replay Timestamp
> On Hold -- pending decision

**Importance:** 🟡 Medium  
**Impact:** Prevents replay attacks that roll back nodes to known-vulnerable firmware versions  
**Difficulty:** Medium  
**Risk:** Low  
**Prerequisites:** Item 63 (signing enforcement)

##### What is it?
IoT Updater bundle `version.json` manifest contains `version`, `sha256`, and signature — but no time-bounded validity window. An attacker who captures a valid signed bundle can re-serve it indefinitely to downgrade a node to a vulnerable version. A `valid_from` / `valid_until` field in the manifest, checked in `apply-update.sh`, closes this window.

##### Why implement?
Downgrade attacks are a real threat model for appliances with known CVEs in older firmware. Bundle signing (Item 63) prevents unsigned bundles, but doesn't prevent replay of legitimately-signed old bundles.

##### Why NOT implement (or defer)?
Requires all existing bundles to be re-signed with timestamps. Nodes with incorrect system time would reject valid bundles. Must handle clock skew gracefully.

##### Implementation notes
Add to `version.json` schema:
```json
{
  "version": "24",
  "valid_from": "2026-04-01T00:00:00Z",
  "valid_until": "2027-04-01T00:00:00Z",
  "sha256": "...",
  "signature": "..."
}
```
In `apply-update.sh`, after signature verify: parse `valid_from`/`valid_until`, compare to `$(date -u +%s)`. Reject with clear error if outside window. Adjust `make-oci-bundle.sh` to auto-populate fields.

---

---

#### Item 110 — SELinux Policy Module for `inferno_aoip`
> On Hold -- pending decision

**Importance:** 🟡 Medium  
**Impact:** Proper MAC confinement for all inferno processes — moves beyond relying on inherited unconfined contexts  
**Difficulty:** Hard  
**Risk:** Medium  
**Prerequisites:** BUG-05, Item 59, Item 106

##### What is it?
All inferno user services currently inherit generic SELinux contexts (`unconfined_t` or `init_t` depending on how they're launched). A custom `inferno_aoip` policy module would confine them to only the files, capabilities, and network operations they actually need — providing defence-in-depth beyond capability sandboxing.

##### Why implement?
Fedora 43 ships with SELinux enforcing by default. Custom policy closes the gap between "running in enforcing mode" and "actually confined" — the current state has SELinux enforcing but inferno processes running as unconfined, giving a false sense of security.

##### Why NOT implement (or defer)?
Writing a correct SELinux policy is complex and time-consuming. Overly tight policy will break statime (raw sockets), ALSA (device access), or inferno-bridge. Requires a dedicated testing cycle. Defer until after RT stabilisation items (97-99) are stable.

##### Implementation notes
Collect AVC denials from a running node: `ausearch -m avc -ts recent | audit2allow -M inferno_aoip`. Build as permissive module first. Test with `semodule -i inferno_aoip.pp`. Promote to enforcing after validation sprint. Add `checkmodule` / `semodule_package` tooling to build pipeline.

---

---


## RT Reliability

| ID | Title | Importance | Difficulty | Risk | Prerequisites | Sprint |
|---|---|---|---|---|---|---|
| 75 | Resource Limits in Service Units (MemoryMax, TasksMax, CPUQuota) | Medium | Easy | Low | None | Later |
| 76 | Explicit Systemd Service Dependencies Between User Services | Medium | Easy | Low | None | Sprint 2 |
| 77 | Restart Backoff Strategy for Flapping Services | Low | Easy | Low | None | Later |
| 91 | statime Log Level: trace to info in Production | Low | Easy | Low | None | Later |
| 97 | Disable RT Throttling (sched_rt_runtime_us=-1) | High | Easy | Low | None | Sprint 2 |
| 98 | RT CPU Isolation (isolcpus + nohz_full + rcu_nocbs) | High | Medium | Medium | 97, 108 | On Hold |
| 99 | NIC Interrupt Pinning Away from RT CPUs | Medium | Medium | Medium | 98 | On Hold |
| 103 | NIC TX Queue and Ring Buffer Tuning | Medium | Easy | Low | None | Sprint 2 |
| 107 | WatchdogSec= for Critical Audio Services | High | Medium | Low | None | On Hold |

---

#### Item 75 — Resource Limits in Service Units (MemoryMax, TasksMax, CPUQuota)
> Later -- scheduled for a future sprint

**Importance:** 🟡 Medium  
**Impact:** Prevents runaway services from starving statime or causing OOM crashes on long-running nodes  
**Difficulty:** Easy (<2h)  
**Risk:** Low  
**Prerequisites:** None  

##### What is it?

No service unit currently specifies `MemoryMax`, `CPUQuota`, or `TasksMax`. A memory leak in librespot, iradio-bridge, or the IoT updater sidecar could OOM the system and kill statime, losing PTP synchronisation. On a headless appliance running for months, this is a realistic failure mode.

##### Why implement?

Resource limits act as a safety net for the RT audio stack. Bounding non-RT services ensures statime and inferno-bridge always have memory and CPU available regardless of what librespot or the updater are doing.

##### Why NOT implement (or defer)?

Setting limits too low risks killing services under legitimate load (e.g., IoT updater during bundle extraction needs significant RAM). Start with generous limits and tighten after profiling actual usage.

##### Implementation notes

Add to user service unit files:

- `librespot.service`: `MemoryMax=256M`, `TasksMax=32`
- `iradio-bridge.service`: `MemoryMax=128M`, `TasksMax=16`
- `iot-updater.service` (system): `MemoryMax=512M` (bundle extraction headroom), `CPUQuota=50%`

Leave `statime-inferno.service` and `inferno-bridge.service` without limits — RT services must never be artificially constrained.

---

---

#### Item 76 — Explicit Systemd Service Dependencies Between User Services
> Sprint 2 -- scheduled for next sprint

**Importance:** 🟡 Medium  
**Impact:** Prevents race conditions; services start in correct order even after manual restarts  
**Difficulty:** Easy (<2h)  
**Risk:** Low  
**Prerequisites:** None  

##### What is it?

User service units use `After=` for ordering but not `Requires=` or `BindsTo=` for lifecycle coupling. `inferno-keepalive.service` depends on `inferno-bridge.service` via `After=` but does not declare `Requires=`. If `inferno-bridge` is manually stopped, `inferno-keepalive` continues trying to write to a non-existent ALSA device, flooding the journal with errors.

##### Why implement?

`After=` only controls start ordering at initial activation. `BindsTo=` stops the dependent service when its dependency stops — which is the correct behaviour for a keepalive process that feeds audio to a bridge that no longer exists.

##### Why NOT implement (or defer)?

`BindsTo=` is more aggressive than `Requires=` — if the bound service is stopped for maintenance, the dependent service also stops. Ensure that `inferno-bridge` stopping for a legitimate reason (config reload, upgrade) doesn't cascade to services that should survive the restart.

##### Implementation notes

```ini
# inferno-keepalive.service
[Unit]
BindsTo=inferno-bridge.service
After=inferno-bridge.service

# inferno-bridge.service
[Unit]
Requires=statime-inferno.service
After=statime-inferno.service network-online.target
Wants=network-online.target
```

Test the dependency chain: `systemctl --user stop inferno-bridge` should automatically stop `inferno-keepalive`, and `systemctl --user start inferno-bridge` should restart it (via `Restart=always`).

---

---

#### Item 77 — Restart Backoff Strategy for Flapping Services
> Later -- scheduled for a future sprint

**Importance:** 🟢 Low  
**Impact:** Prevents rapid restart loops from consuming CPU and filling the journal when services crash on startup  
**Difficulty:** Easy (<2h)  
**Risk:** Low  
**Prerequisites:** None  

##### What is it?

All services use fixed `RestartSec=3` or `RestartSec=5`. If a service crashes immediately on start (e.g., missing config, bad audio device), it restarts every 3s indefinitely, flooding the journal and wasting CPU. systemd v254+ supports `RestartSteps` and `RestartMaxDelaySec` for exponential backoff. Fedora 43 ships systemd v255+.

##### Why implement?

Exponential backoff converts a tight restart loop (3s, 3s, 3s...) into a progressively slower series (3s, 6s, 12s..., up to 120s). This reduces journal noise by ~95% for a broken service and allows operators to notice the problem without being overwhelmed by log volume.

##### Why NOT implement (or defer)?

No meaningful reason to defer. Purely additive change, no behaviour change for services that start cleanly.

##### Implementation notes

Add to service units that have `Restart=always`:

```ini
[Service]
RestartSteps=5
RestartMaxDelaySec=120
StartLimitIntervalSec=600
StartLimitBurst=5
```

This creates backoff: 3s → ~14s → ~28s → ~58s → 120s (5 steps, capped at 120s). After 5 failures in 10 minutes (`StartLimitIntervalSec=600`, `StartLimitBurst=5`), systemd stops restarting and marks the service as failed — enabling monitoring to detect the persistent failure.

---

---

#### Item 91 — `statime` Log Level: Reduce from `trace` to `info` in Production
> Later -- scheduled for a future sprint

**Importance:** 🟢 Low  
**Impact:** Reduces journal noise by ~95% from statime; reduces disk I/O on RT workloads  
**Difficulty:** Easy (<2h)  
**Risk:** Low  
**Prerequisites:** None  

##### What is it?

`templates/inferno-ptpv1.toml` sets `loglevel = "trace"`. Trace logging outputs every PTP packet, clock adjustment, and internal state change — extremely verbose. On a busy PTP network this generates thousands of lines per minute, causing measurable disk I/O that can introduce scheduling jitter on RT workloads.

##### Why implement?

Trace logging was appropriate during development and debugging but should not be the production default. The disk I/O from continuous trace logging is a real (if small) source of scheduling interference. `info` level logs PTP convergence events and errors — sufficient for production monitoring.

##### Why NOT implement (or defer)?

Trace logging is invaluable for diagnosing PTP convergence issues in the field. Consider making the log level configurable via `/etc/inferno.conf` rather than hardcoding `info` — operators can re-enable `trace` when debugging without rebuilding the image.

##### Implementation notes

1. Change `templates/inferno-ptpv1.toml`: `loglevel = "trace"` → `loglevel = "info"`
2. Add `INFERNO_PTP_LOGLEVEL=info` to `/etc/inferno.conf` template.
3. Add `%%INFERNO_PTP_LOGLEVEL%%` placeholder to `inferno-ptpv1.toml.template`.
4. Add substitution in `inferno-configure.sh`'s `substitute()` call for this new placeholder.


---

---

#### Item 97 -- Disable RT Throttling (sched_rt_runtime_us=-1)
> Sprint 2 -- scheduled for next sprint

**Importance:** High  
**Impact:** Prevents kernel from throttling the statime RT thread for up to 50ms/s  
**Difficulty:** Easy  
**Risk:** Low  
**Prerequisites:** None

##### What is it?
Linux limits RT tasks to 95% CPU time by default. Setting `sched_rt_runtime_us=-1` removes this cap, eliminating periodic PTP jitter spikes caused by the throttle window.

##### Implementation
Add `/etc/sysctl.d/99-inferno-rt.conf`:
```
kernel.sched_rt_runtime_us = -1
```

---

#### Item 98 — RT CPU Isolation (`isolcpus` + `nohz_full` + `rcu_nocbs`)
> On Hold -- pending decision
> Planning note: Must be dynamic: only apply CPU isolation on 4-core+ systems. Configurable via configure script, not baked into image.

**Importance:** 🟠 High  
**Impact:** Reduces PTP jitter by an order of magnitude by dedicating 1-2 cores exclusively to RT workloads  
**Difficulty:** Medium  
**Risk:** Medium  
**Prerequisites:** Item 97, Item 108

##### What is it?
Even with `preempt=full` and `threadirqs`, kernel ticks (`HZ=250`) and RCU callbacks still interrupt all CPUs including ones running RT tasks. `isolcpus` removes specified CPUs from the scheduler's general pool; `nohz_full` makes those CPUs tickless; `rcu_nocbs` offloads RCU callbacks. The HP EliteDesk Mini has 4–8 cores — dedicating cores 2-3 to RT tasks is practical.

##### Why implement?
With CPU isolation, cyclictest P99 latency on Fedora drops from ~200µs to ~20µs. For PTP, this means consistently sub-100µs offset rather than occasional 500µs spikes under load.

##### Why NOT implement (or defer)?
Requires knowing the CPU topology of all target hardware. A 2-core system would leave 0 cores for non-RT work. Needs dynamic detection of core count in `inferno-configure.sh`. Previously deferred as Item 37 for this reason — now that EliteDesk is established target hardware, risk is lower.

##### Implementation notes
```toml
# /usr/lib/bootc/kargs.d/99-rt-isolation.toml (Item 108 prerequisite)
kargs = [
  "isolcpus=nohz,domain,managed_irq:2-3",
  "nohz_full=2-3",
  "rcu_nocbs=2-3",
  "rcu_nocb_poll"
]
```
Add CPU count check to `inferno-configure.sh`: only write this kargs file if `nproc >= 4`. Pin statime to isolated CPUs via `ExecStart=/usr/bin/taskset -c 2-3 /usr/bin/statime ...` in unit file.

---

---

#### Item 99 — NIC Interrupt Pinning Away from RT CPUs
> On Hold -- pending decision

**Importance:** 🟡 Medium  
**Impact:** Prevents NIC IRQ handler from running on RT-isolated CPUs during PTP timestamp exchanges  
**Difficulty:** Medium  
**Risk:** Medium  
**Prerequisites:** Item 98

##### What is it?
`threadirqs` makes IRQs run as kernel threads (good), but `irqbalance` migrates them freely — including onto RT-isolated CPUs. A NIC interrupt landing on CPU 2 during a PTP hardware timestamp exchange introduces unbounded jitter. The fix is to mask `irqbalance` and manually pin NIC IRQs to non-isolated CPUs.

##### Why implement?
Even with `isolcpus`, unmanaged IRQ migration can breach isolation boundaries. IRQ pinning is the standard complement to CPU isolation in RT audio workloads.

##### Why NOT implement (or defer)?
Manual IRQ pinning via `/proc/irq/*/smp_affinity` is fragile across driver updates and reboots. NetworkManager restarting the interface can reset IRQ assignments. Requires careful implementation.

##### Implementation notes
```bash
# inferno-configure.sh — after NIC detection, if CPU isolation is active
if [ "$(nproc)" -ge 4 ]; then
  systemctl mask irqbalance 2>/dev/null || true
  for irq in $(ls /sys/class/net/"$INFERNO_NIC"/device/msi_irqs/ 2>/dev/null); do
    echo "3" > /proc/irq/$irq/smp_affinity  # CPUs 0-1 only (bitmask 0x3)
  done
fi
```
Add a `NetworkManager` dispatcher script to re-apply on interface up events.

---

---

#### Item 103 — NIC TX Queue and Ring Buffer Tuning
> Sprint 2 -- scheduled for next sprint

**Importance:** 🟡 Medium  
**Impact:** Prevents audio UDP packet drops during multichannel Dante streaming bursts  
**Difficulty:** Easy  
**Risk:** Low  
**Prerequisites:** None

##### What is it?
Default Linux NIC transmit queue length is 1000 packets. Multi-channel Dante sends many simultaneous UDP audio frames per millisecond; a burst from the ALSA plugin can overflow the queue and silently drop packets. Ring buffer defaults (typically 256 descriptors RX/TX) are also undersized for Dante traffic patterns. Ethtool coalescing defaults optimise for throughput, not latency.

##### Why implement?
Simple ethtool/ip tuning with no kernel changes. Directly addresses the root cause of intermittent audio glitches under load that aren't explained by PTP jitter.

##### Why NOT implement (or defer)?
`ethtool` is not currently in the Containerfile dependencies — needs to be added. Coalescing changes (`rx-usecs 50`) reduce throughput-optimised coalescing and slightly increase CPU IRQ rate.

##### Implementation notes
```bash
# inferno-configure.sh — after NIC detection
ip link set dev "$INFERNO_NIC" txqueuelen 10000
ethtool -G "$INFERNO_NIC" rx 4096 tx 4096 2>/dev/null || true
ethtool -C "$INFERNO_NIC" rx-usecs 50 tx-usecs 50 2>/dev/null || true
```
Add `ethtool` to `Containerfile` dnf install line. Add `|| true` to all ethtool calls — some NICs don't support all parameters.

---

---

#### Item 107 -- WatchdogSec= for Critical Audio Services
> On Hold -- pending decision

**Importance:** High  
**Impact:** Detects and recovers from silent service hangs without human intervention  
**Difficulty:** Medium  
**Risk:** Low  
**Prerequisites:** None

##### What is it?
A service can be 'running' but completely hung -- not processing audio. systemd `WatchdogSec=` restarts it if it fails to call `sd_notify(WATCHDOG=1)` within the timeout window. Services without native sd_notify support need a wrapper health check script.

##### On Hold
Deferred until Item 74 (health monitoring daemon) establishes a health check pattern. A watchdog without a meaningful check is just a restart timer.

---


## Build Pipeline

| ID | Title | Importance | Difficulty | Risk | Prerequisites | Sprint |
|---|---|---|---|---|---|---|
| 67 | Remove/Redact Hardcoded IPs from Bench Scripts | Low | Easy | Low | None | Sprint 2 |
| 68 | Add .containerignore to Reduce Build Context Size | Medium | Easy | Low | None | Later |
| 70 | Add --setopt=tsflags=nodocs to DNF Install | Low | Easy | Low | None | Sprint 2 |
| 71 | Tag Releases on Submodule Repositories | Low | Easy | Low | None | Later |
| 72 | Consolidate Containerfile RUN Layers | Low | Medium | Low | None | Later |
| 73 | BATS Test Suite for Shell Scripts | Medium | Hard | Low | None | Sprint 2 |
| 108 | kargs.d/ for Declarative Kernel Args | Medium | Easy | Low | None | Later |
| 111 | cockpit.transport.wait() for Plugin Init | Medium | Easy | Low | None | Later |

---

#### Item 67 — Remove/Redact Hardcoded IPs from Bench Scripts
> Sprint 2 -- scheduled for next sprint

**Importance:** 🟢 Low  
**Impact:** Removes confusion for external operators copying bench commands from examples  
**Difficulty:** Easy (<2h)  
**Risk:** Low  
**Prerequisites:** None  

##### What is it?

`scripts/bench/ptp-bench.sh`, `audio-loopback-test.sh`, and `stress-bench.sh` have hardcoded example IPs (`192.168.1.43`, `192.168.1.25`) in comments and default variable values. Operators copy-pasting these commands may accidentally target wrong nodes or be confused by errors from the placeholder IPs.

##### Why implement?

Documentation quality and operator safety. Hardcoded IPs in bench scripts look like they should work and cause confusing errors when they don't. Placeholder-style documentation (`<node-ip>`) is unambiguous.

##### Why NOT implement (or defer)?

No reason to defer. Purely documentation cleanup, zero risk.

##### Implementation notes

Replace hardcoded IPs in comments with `<node-ip>` or `TARGET_NODE_IP`. Change any default `TARGET=192.168.1.43` to `TARGET=""` with:

```bash
[ -z "$TARGET" ] && { echo "ERROR: set TARGET=<node-ip> before running"; exit 1; }
```


---

---

#### Item 68 — Add `.containerignore` to Reduce Build Context Size
> Later -- scheduled for a future sprint

**Importance:** 🟡 Medium  
**Impact:** Prevents multi-GB build context transfer on every build; faster build start on COPILOT-BUILD-01  
**Difficulty:** Easy (<2h)  
**Risk:** Low  
**Prerequisites:** None  

##### What is it?

No `.containerignore` file exists in the repository. `podman build` transfers the entire repo directory as build context, including `output-vN/` directories (2–4GB per release build), `archived/`, `docs/`, `.git/`, and artifact files. On COPILOT-BUILD-01 where multiple `output-vN/` dirs accumulate, the build context can exceed 10GB before the actual build even starts.

##### Why implement?

Large build context wastes I/O bandwidth and slows the `COPY` layer scanning step. Context transfer time is dead time that cannot be parallelised with the actual build steps. A `.containerignore` file is a one-time addition that pays off on every subsequent build.

##### Why NOT implement (or defer)?

No reason to defer. Zero risk — `.containerignore` only excludes files from the build context; it doesn't affect files already in the image or the build process itself.

##### Implementation notes

Create `inferno-aoip-releases/.containerignore`:

```
.git
.gitignore
.gitmodules
output*/
releases/
archived/
docs/
*.tar
*.iso
*.iotupdate
*.log
build/*.json
build/*.env
IMPROVEMENT_ROADMAP.md
```

Verify with: `podman build --dry-run .` and inspect the context size reported. Confirm the `build/` directory scripts and templates are still included (they should be — only specific patterns are excluded).

---

---

#### Item 70 — Add `--setopt=tsflags=nodocs` to DNF Install
> Sprint 2 -- scheduled for next sprint

**Importance:** 🟢 Low  
**Impact:** ~50–100MB image size reduction; no documentation needed on a headless appliance  
**Difficulty:** Easy (<2h)  
**Risk:** Low  
**Prerequisites:** None  

##### What is it?

`Containerfile` dnf install commands do not include `--setopt=tsflags=nodocs`. Man pages, info pages, locale files, and documentation installed with each package are unnecessary on a headless audio appliance that has no document viewer.

##### Why implement?

50–100MB of image savings across all packages is meaningful for OTA updates — it reduces download time, extraction time, and bootc overlay storage usage. This is especially significant on nodes with slow storage.

##### Why NOT implement (or defer)?

Removing docs makes `man` and `info` commands non-functional on the node. If operators SSH in to debug and expect man pages, they will find them missing. Document this clearly. No meaningful reason to defer otherwise.

##### Implementation notes

Add `--setopt=tsflags=nodocs` to all `dnf install` lines in the `Containerfile`. Also add explicit cleanup:

```dockerfile
RUN dnf install -y --setopt=tsflags=nodocs <packages> &&     dnf clean all &&     rm -rf /usr/share/man/* /usr/share/info/* /usr/share/locale/*
```

Note: `rm -rf /usr/share/locale/*` removes all locale files — keep `en_US.UTF-8` if the appliance needs locale-aware tools.

---

---

#### Item 71 — Tag Releases on Submodule Repositories
> Later -- scheduled for a future sprint

**Importance:** 🟢 Low  
**Impact:** Enables version traceability; allows pinning submodule versions to specific appliance releases  
**Difficulty:** Easy (<2h)  
**Risk:** Low  
**Prerequisites:** None  

##### What is it?

`cockpit-inferno`, `cockpit-iot-updater`, and `inferno-branding` submodules have no version tags. The build uses `--remote` to pull the latest commit from each submodule — meaning a breaking change in `cockpit-inferno` between build triggers silently enters the next appliance release.

##### Why implement?

Version tags on submodules enable: (1) traceability — know exactly which `cockpit-inferno` commit is in v23, (2) reproducible builds — pin `--remote` fetch to a tag instead of HEAD, (3) staged rollout — test a new UI version before including it in an appliance release.

##### Why NOT implement (or defer)?

Adds a small overhead to the release process: tag each submodule repo before triggering the appliance build. Can be scripted as part of `build-release.sh` to remove friction.

##### Implementation notes

After each appliance release, tag submodule repos:

```bash
cd submodules/cockpit-inferno && git tag "v${VERSION}-appliance" && git push origin "v${VERSION}-appliance"
cd submodules/cockpit-iot-updater && git tag "v${VERSION}-appliance" && git push origin "v${VERSION}-appliance"
```

Consider removing `--remote` from `git submodule update` in `build-release.sh` and pinning submodule refs to the tagged commits in `.gitmodules` instead. This gives full build reproducibility.

---

---

#### Item 72 — Consolidate Containerfile RUN Layers
> Later -- scheduled for a future sprint

**Importance:** 🟢 Low  
**Impact:** Fewer intermediate image layers; slightly faster build and reduced storage overhead  
**Difficulty:** Medium (half-day)  
**Risk:** Low  
**Prerequisites:** None  

##### What is it?

`Containerfile` currently has ~13 separate `RUN` commands for configuration and setup (lines 68–245). Many of these could be consolidated into 2–3 grouped blocks without sacrificing cache efficiency, since they all sit in the stable-config zone below the main cache boundary (package install layer).

##### Why implement?

Each `RUN` creates an intermediate image layer in podman/OCI storage. Fewer layers means less storage overhead on the build host and slightly faster image inspection via `podman history`. A cleaner Containerfile is also easier to review and maintain.

##### Why NOT implement (or defer)?

Overly aggressive consolidation can break the cache optimisation strategy: the layer boundary between "slow/expensive" package install and "fast/cheap" config should be preserved. Avoid consolidating across the cache boundary. Test build times with and without the change to confirm benefit.

##### Implementation notes

Keep the following as separate layers (cache boundaries):
1. `FROM` + base image setup
2. `RUN dnf install ...` (cache-heavy, slow)
3. `RUN` for file copies and symlinks
4. `RUN` for systemd unit configuration
5. `COPY` + restorecon for binaries

Consolidate all the small `RUN echo > /etc/...` one-liners into grouped blocks within each layer.

---

---

#### Item 73 — BATS Test Suite for Shell Scripts
> Sprint 2 -- scheduled for next sprint

**Importance:** 🟡 Medium  
**Impact:** Catches regressions in `inferno-configure.sh`, `apply-update.sh`, and health checks before they reach production  
**Difficulty:** Hard (multi-day)  
**Risk:** Low  
**Prerequisites:** None  

##### What is it?

No automated tests exist for any shell script in the project. `inferno-configure.sh` (254 lines), `apply-update.sh`, `inferno-health-check.sh`, and `build-release.sh` contain complex conditional logic (NIC detection, PTP capability, version comparison, bundle hash verification) that is currently tested only by manual VM testing.

##### Why implement?

Shell scripts have subtle edge cases — empty `$NIC`, no carrier, wrong version format, missing config file — that manual testing rarely exercises. BATS (Bash Automated Testing System) allows unit-testing shell functions in isolation with mock `ip`, `ethtool`, and `systemctl` stubs. A test suite that runs in CI would catch regressions before they reach production builds.

##### Why NOT implement (or defer)?

Writing BATS tests for existing scripts requires understanding every code path — this is inherently time-consuming for complex scripts. The investment pays off over time but requires initial commitment. A phased approach: start with the highest-value tests (NIC detection, version comparison) and expand incrementally.

##### Implementation notes

1. Add `tests/` directory to repo.
2. Install BATS via GitHub Actions: `sudo apt-get install bats` or `npm install -g bats`.
3. Write initial test cases:
   - NIC detection with carrier: mock `/sys/class/net/<iface>/carrier` files
   - Version sentinel comparison: test `IMAGE_VER > SENTINEL_VER` logic
   - Bundle hash verification: test SHA256 mismatch detection
   - Health check: mock `systemctl is-active` return codes
4. Add CI job: `.github/workflows/test-scripts.yml` that runs `bats tests/`.


---

---

#### Item 108 — `/usr/lib/bootc/kargs.d/` for Declarative Kernel Args
> Later -- scheduled for a future sprint

**Importance:** 🟡 Medium  
**Impact:** Kernel args version-controlled in the image, portable across build tools, no BIB config dependency  
**Difficulty:** Easy  
**Risk:** Low  
**Prerequisites:** None

##### What is it?
Kernel arguments currently live in BIB's `config.toml` (`kargs` array). bootc natively supports `/usr/lib/bootc/kargs.d/*.toml` files baked into the image, which are applied at install time by the bootloader. This makes kernel args part of the container image (version-controlled, auditable) rather than a build-tool concern.

##### Why implement?
BIB config.toml is external to the container image — it must be kept in sync with the Containerfile. Moving kargs into the image means the exact kernel arguments used are visible by inspecting the container, and they're applied consistently regardless of which build tool is used.

##### Why NOT implement (or defer)?
Requires bootc ≥ 0.1.13 (available on Fedora 43). Some kargs (e.g. installer-specific args) may still need to live in BIB config.

##### Implementation notes
```toml
# Bake into Containerfile via COPY or RUN:
# /usr/lib/bootc/kargs.d/01-inferno-rt.toml
kargs = [
  "preempt=full",
  "threadirqs",
  "intel_pstate=disable",
  "pcie_aspm=off",
  "mitigations=off"
]
```
Remove equivalent entries from `build/bib-config.toml`. Leaves BIB config.toml for installer-only args.

---

---

#### Item 111 — `cockpit.transport.wait()` for Plugin Initialisation
> Later -- scheduled for a future sprint

**Importance:** 🟡 Medium  
**Impact:** Prevents intermittent "transport not ready" errors when Cockpit loads the inferno plugin  
**Difficulty:** Easy  
**Risk:** Low  
**Prerequisites:** None

##### What is it?
`cockpit-inferno` `init()` runs immediately on `DOMContentLoaded`. Cockpit's official best practices recommend wrapping all init code in `cockpit.transport.wait()` to ensure the Cockpit transport channel is established before making `cockpit.spawn()` or `cockpit.file()` calls. Without this, slow Cockpit connections can result in silent init failures where the plugin loads but shows stale/empty data.

##### Why implement?
Intermittent "plugin shows nothing on first load, refresh fixes it" reports are almost always caused by this race condition. One-line fix with no downside.

##### Why NOT implement (or defer)?
No reason to defer. Low-risk, high-confidence improvement.

##### Implementation notes
```javascript
// cockpit-inferno/src/inferno.js — wrap top-level init call
document.addEventListener('DOMContentLoaded', function() {
  cockpit.transport.wait(function() {
    init();
  });
});
```
Apply same pattern to `cockpit-iot-updater/src/index.js` if it has the same pattern.

---

---


## Operations and Cockpit

| ID | Title | Importance | Difficulty | Risk | Prerequisites | Sprint |
|---|---|---|---|---|---|---|
| 60 | dante-network-bench.sh Default Timeout 3s to 8s | Low | Easy | Low | None | Later |
| 74 | Continuous Health Monitoring Daemon | Medium | Medium | Low | None | Later |
| 78 | Log Rotation for Custom Script Logs | Medium | Easy | Low | None | Sprint 2 |
| 81 | User Action Audit Trail in Cockpit UI | Medium | Medium | Low | None | On Hold |
| 83 | Central Logging via systemd-journal-remote | Medium | Medium | Low | None | On Hold |
| 89 | PTP Offset Alerting Threshold | Medium | Medium | Low | 74 | Sprint 2 |
| 95 | Cockpit Configuration Export/Import | Medium | Medium | Low | None | Later |
| 96 | Cockpit In-App Help / Troubleshooting Runbook | Medium | Medium | Low | None | Later |
| FR-01 | Factory Reset: Full Wipe and Re-Configure | Medium | Medium | Low | None | Sprint 2 |

---

#### Item 60 — `dante-network-bench.sh` Default Timeout 3s → 8s
> Later -- scheduled for a future sprint

**Importance:** 🟢 Low  
**Impact:** Consistent device discovery between bench script and Cockpit monitoring; no missed devices on slower networks  
**Difficulty:** Easy (<2h)  
**Risk:** Low  
**Prerequisites:** None  

##### What is it?

`scripts/bench/dante-network-bench.sh` defaults to `MDNS_TIMEOUT=3`. The Cockpit `scanDanteDevices()` function uses 8 seconds. On networks where Dante devices are slow to respond (VLAN boundaries, upstream routers, heavily loaded switches), the 3-second scan misses devices that the 8-second Cockpit scan catches. This causes confusing discrepancies between bench results and Cockpit results.

##### Why implement?

Consistency between tooling. If Cockpit finds 8 devices and the bench script finds 6, operators assume the bench script is broken — or worse, that Cockpit is showing stale data. Aligning the timeouts removes that confusion.

##### Why NOT implement (or defer)?

No reason to defer. One-line change, zero risk.

##### Implementation notes

In `scripts/bench/dante-network-bench.sh`, change: `MDNS_TIMEOUT=3` → `MDNS_TIMEOUT=8`. Also align the `avahi-browse` flags to match what Cockpit uses: `timeout ${MDNS_TIMEOUT} avahi-browse -rp _netaudio-arc._tcp`.

---

---

#### Item 74 — Continuous Health Monitoring Daemon
> Later -- scheduled for a future sprint

**Importance:** 🟡 Medium  
**Impact:** Detects service failures within minutes instead of waiting for operator to open Cockpit  
**Difficulty:** Medium (half-day)  
**Risk:** Low  
**Prerequisites:** None  

##### What is it?

`inferno-health-check.service` runs ONCE at 120 seconds after boot. After that, no continuous monitoring occurs. If `statime-inferno` dies at hour 6, nobody knows until someone opens Cockpit. Production appliances need self-monitoring that runs continuously and exposes status to both Cockpit and external tools.

##### Why implement?

Silent degraded state — PTP running but not converged, audio playing but with xruns, librespot active but not streaming — is undetectable without continuous monitoring. A simple periodic script writing to a status JSON file that Cockpit can read provides the monitoring foundation for Items 81, 82, 83, and 89.

##### Why NOT implement (or defer)?

A monitoring daemon that itself crashes would leave the system unmonitored without indication. Use a `systemd.timer` rather than a long-running daemon — timer failures are visible in `systemctl` status and the timer automatically retries.

##### Implementation notes

Add `inferno-monitor.timer`:

```ini
[Unit]
Description=Inferno Health Monitor

[Timer]
OnCalendar=*:0/5
Persistent=true

[Install]
WantedBy=timers.target
```

`inferno-monitor.sh` checks:
1. All critical services active (`systemctl is-active`)
2. PTP converged (offset < threshold from statime log)
3. ALSA loopback device present (`aplay -l | grep -q Loopback`)
4. Disk > 10% free on `/var`
5. Network carrier on `$INFERNO_NIC`

Writes to `/var/lib/inferno/monitor-status.json` — readable by Cockpit without sudo.

---

---

#### Item 78 — Log Rotation for Custom Script Logs
> Sprint 2 -- scheduled for next sprint

**Importance:** 🟡 Medium  
**Impact:** Prevents unbounded log growth on long-running nodes  
**Difficulty:** Easy (<2h)  
**Risk:** Low  
**Prerequisites:** None  

##### What is it?

`/var/lib/iot-updater/update.log` and `/var/lib/iot-updater/audit.log` have no rotation configured. The audit log grows with every upload attempt — on a node receiving weekly OTA updates over years, this file can grow significantly. No `logrotate.d` configuration exists for any inferno-specific log path.

##### Why implement?

Long-running headless appliances accumulate logs indefinitely. On a node deployed at a venue for 3+ years, unbounded audit logs become a meaningful disk space consumer. Log rotation is a standard operational hygiene item.

##### Why NOT implement (or defer)?

No reason to defer. A `logrotate.d` configuration is a static file addition to the Containerfile — zero runtime risk.

##### Implementation notes

Add to Containerfile:

```dockerfile
COPY build/logrotate-inferno /etc/logrotate.d/inferno
```

`build/logrotate-inferno`:

```
/var/lib/iot-updater/audit.log {
    weekly
    rotate 4
    compress
    missingok
    notifempty
    create 0644 root root
}

/var/lib/iot-updater/update.log {
    weekly
    rotate 2
    compress
    missingok
    notifempty
}

/var/lib/inferno/monitor-status.json {
    daily
    rotate 7
    compress
    missingok
    notifempty
}
```

---

---

#### Item 81 — User Action Audit Trail in Cockpit UI
> On Hold -- pending decision

**Importance:** 🟡 Medium  
**Impact:** Operational visibility — know who changed what and when on each node  
**Difficulty:** Medium (half-day)  
**Risk:** Low  
**Prerequisites:** None  

##### What is it?

The IoT Updater sidecar has `/var/lib/iot-updater/audit.log` for update actions, but the main Cockpit plugin (`inferno.js`) has no audit trail. Mode changes, config saves, service restarts, and rollback actions performed via Cockpit are not logged anywhere operator-accessible. Cockpit does log to the journal, but Cockpit user actions (as distinct from system events) are not easily queryable.

##### Why implement?

In a shared AV environment, knowing "who changed Dante device name at 14:32 on Tuesday" is critical for post-incident analysis. An audit trail in a human-readable structured log reduces mean time to diagnosis significantly.

##### Why NOT implement (or defer)?

Writing to a log file from Cockpit JavaScript requires a `sudo tee -a` call (see Item 62 — `tee` must be in the sudoers allowlist). This is an acceptable pattern but requires Item 62 to be implemented first for clean security scoping.

##### Implementation notes

Add `infernoAudit(action, before, after)` helper in `inferno.js`:

```javascript
function infernoAudit(action, before, after) {
    const ts = new Date().toISOString();
    const user = cockpit.user.name || "unknown";
    const line = `${ts} [${user}] ${action}: ${JSON.stringify({before, after})}
`;
    cockpit.spawn(["sudo", "tee", "-a", "/var/lib/inferno/cockpit-audit.log"],
                  {superuser: "require"}).input(line);
}
```

Call from: mode change, config save, service restart, rollback, NIC change. Expose last 50 entries in Diagnostics tab as a scrollable log view.

---

---

#### Item 83 — Central Logging via `systemd-journal-remote`
> On Hold -- pending decision
> Planning note: Only implement if the remote syslog server URL can be configured from within the Cockpit UI.

**Importance:** 🟡 Medium  
**Impact:** All inferno nodes ship logs to a central location for fleet-wide aggregation and alerting  
**Difficulty:** Medium (half-day)  
**Risk:** Low  
**Prerequisites:** None  

##### What is it?

Each node logs only to its local journal. There is no mechanism to collect logs from multiple inferno nodes centrally. `systemd-journal-remote` (push mode via `systemd-journal-upload`) can forward journal entries to a central `systemd-journal-gatewayd` or Loki/Graylog endpoint, enabling fleet-wide log search.

##### Why implement?

A fleet of inferno nodes at a production venue requires a single place to search logs — "did any node lose PTP sync in the last hour?" currently requires SSH-ing to each node individually. Central logging enables alerting on PTP loss, service failures, and OTA update outcomes across the entire fleet.

##### Why NOT implement (or defer)?

Central logging requires a receiving server — this is operator infrastructure that inferno cannot provide. The implementation on the inferno side is minimal (configure `journal-upload` with a URL), but the feature is only valuable when the operator has a central log server.

##### Implementation notes

Add `systemd-journal-remote` to Containerfile packages. Add configuration:

```ini
# /etc/systemd/journal-remote.conf.d/inferno.conf
[Remote]
URL=${INFERNO_LOG_REMOTE_URL}
```

Enable `systemd-journal-upload.service` only if `INFERNO_LOG_REMOTE_URL` is set in `/etc/inferno.conf`:

```bash
# In inferno-configure.sh:
if [ -n "${INFERNO_LOG_REMOTE_URL:-}" ]; then
    systemctl enable --now systemd-journal-upload.service
fi
```

---

---

#### Item 89 — PTP Offset Alerting Threshold
> Sprint 2 -- scheduled for next sprint

**Importance:** 🟡 Medium  
**Impact:** Proactive notification when PTP drift exceeds safe range for Dante audio quality  
**Difficulty:** Medium (half-day)  
**Risk:** Low  
**Prerequisites:** 74  

##### What is it?

PTP offset is displayed in the Cockpit Services tab but no alerting occurs when offset exceeds a threshold. If PTP drifts beyond 1ms (the danger zone for Dante), the operator only knows if actively watching the Cockpit UI. Dante can tolerate ~1ms PTP offset but audio quality degrades and device connections may drop above this.

##### Why implement?

PTP offset exceeding threshold is one of the most common causes of intermittent audio glitches in Dante installations. Automated alerting via the Cockpit UI (orange/red indicator change) enables operators to catch and diagnose the problem before it causes audible artefacts. The continuous monitor (Item 74) provides the infrastructure for this check.

##### Why NOT implement (or defer)?

Requires Item 74 (continuous monitoring daemon) to provide the periodic PTP offset reading. Implement Item 74 first, then add the alerting threshold check as an additional step in `inferno-monitor.sh`.

##### Implementation notes

In `inferno-monitor.sh` (Item 74), add PTP offset check:

```bash
PTP_OFFSET_US=$(journalctl -u statime-inferno -n 50 --no-pager 2>/dev/null     | grep "offset:" | tail -1 | grep -oP '[+-]?[0-9]+(?=.{0,5}us)' || echo "0")
THRESHOLD="${INFERNO_PTP_ALERT_THRESHOLD_US:-500}"
ABS_OFFSET="${PTP_OFFSET_US#-}"

PTP_STATUS="ok"
[ "${ABS_OFFSET}" -gt "${THRESHOLD}" ] 2>/dev/null && PTP_STATUS="warning"

jq -n     --arg offset "$PTP_OFFSET_US"     --arg threshold "$THRESHOLD"     --arg status "$PTP_STATUS"     '{ptp_offset_us: $offset, ptp_threshold_us: $threshold, ptp_status: $status}'     >> /var/lib/inferno/monitor-status.json
```

Cockpit reads `/var/lib/inferno/monitor-status.json` and renders the PTP card with orange background when `ptp_status = "warning"`. Add `INFERNO_PTP_ALERT_THRESHOLD_US=500` to `/etc/inferno.conf` template.

---

---

#### Item 95 — Cockpit Configuration Export/Import
> Later -- scheduled for a future sprint

**Importance:** 🟡 Medium  
**Impact:** Enables mass provisioning of multiple nodes with identical config; backup/restore of node settings  
**Difficulty:** Medium (half-day)  
**Risk:** Low  
**Prerequisites:** None  

##### What is it?

There is currently no way to export a node's configuration (`INFERNO_NAME`, `INFERNO_NIC`, `INFERNO_MODE`, etc.) from Cockpit or restore it. Operators with 10 identical nodes must configure each manually. A "Export Config" button and "Import Config" upload in the Cockpit Config tab would significantly speed up fleet provisioning.

##### Why implement?

AV installs frequently have multiple identical nodes — backup receivers, multiple venues, staging/production pairs. Config export/import accelerates deployment from hours to minutes for large fleets. Config export also serves as an implicit backup mechanism.

##### Why NOT implement (or defer)?

Imported configs must be validated before applying — importing a config intended for different hardware (different NIC name) could break network connectivity. Add validation: check that `INFERNO_NIC` value exists as a network interface on the target node.

##### Implementation notes

Add to Cockpit Config tab in `inferno.js`:

- **Export**: `cockpit.file("/etc/inferno.conf").read()` → `Blob` download as `inferno-config-HOSTNAME.conf`
- **Import**: file upload → validate NIC exists → `cockpit.file("/etc/inferno.conf").replace(content)` → `spSudo("systemctl restart inferno-configure")`

JSON format with schema validation is preferred over raw shell env format for import — convert `/etc/inferno.conf` to JSON for the export format while keeping the file itself as shell env syntax.

---

---

#### Item 96 — Cockpit In-App Help / Troubleshooting Runbook
> Later -- scheduled for a future sprint

**Importance:** 🟡 Medium  
**Impact:** Reduces support requests; operators can self-diagnose the top 5 failure modes without SSH  
**Difficulty:** Medium (half-day)  
**Risk:** Low  
**Prerequisites:** None  

##### What is it?

No in-app help or troubleshooting guidance exists in the Cockpit UI. Common issues — no Dante devices discovered, PTP not converged, audio not playing, OTA update fails — each have multiple root causes that require knowledge of the system architecture to diagnose. A "Help" tab or collapsible guidance panels would guide operators through the decision tree.

##### Why implement?

AV operators are typically not Linux experts. "Dante shows no devices in Cockpit" has five possible causes (no cable, wrong NIC, mDNS filtered by switch, Dante device not powered, avahi-daemon not running). A guided decision tree in the UI narrows this to the actual cause in 30 seconds instead of 20 minutes of SSH debugging.

##### Why NOT implement (or defer)?

Help content requires maintenance — it must be updated when the system changes. Start with the 5 most common failure modes and expand as support patterns emerge from real deployments.

##### Implementation notes

Add "Help" tab to Cockpit plugin or collapsible `?` icon on each card:

1. **No Dante devices**: cable → NIC selection → avahi-daemon running → try manual `avahi-browse -rt _netaudio-arc._tcp`
2. **PTP not converged**: grandmaster available → statime running → check `journalctl -u statime-inferno` → check domain number (Item 88)
3. **Audio not playing**: mode correct → librespot active → ALSA device exists → check `aplay -l` for loopback card
4. **OTA update fails**: network connectivity → sidecar running → disk space → check `/var/lib/iot-updater/update.log`
5. **Cockpit shows errors**: service unit logs → `journalctl --user -u inferno-bridge` → restart services


---

---

#### FR-01 — Factory Reset Button in Cockpit
> Sprint 2 -- scheduled for next sprint
**Importance:** 🟠 High  
**Difficulty:** Medium  
**Risk:** Low  

A Cockpit action that resets the node to unconfigured state:
- Clears  (removes sentinel, triggers reconfigure on next boot)
- Wipes Inferno state: 
- Resets hostname to  format
- Clears Dante TX name from state
- Reboots into unconfigured state — Cockpit first-login wizard fires again

After reset the node should advertise  via mDNS instead of  so inferno-central can discover it as "awaiting provisioning".

---


## Network and Dante

| ID | Title | Importance | Difficulty | Risk | Prerequisites | Sprint |
|---|---|---|---|---|---|---|
| 85 | DSCP/QoS Marking for Dante Audio Traffic | Medium | Medium | Medium | 65 | Later |
| 88 | Configurable PTP Domain Number | Medium | Easy | Low | None | Later |
| 102 | IGMP Multicast Group Membership for Dante | Medium | Easy | Low | None | On Hold |

---

#### Item 85 — DSCP/QoS Marking for Dante Audio Traffic
> Later -- scheduled for a future sprint

**Importance:** 🟡 Medium  
**Impact:** Audio traffic prioritised over background traffic on shared networks; reduces latency jitter  
**Difficulty:** Medium (half-day)  
**Risk:** Medium  
**Prerequisites:** 65  

##### What is it?

Dante uses DSCP EF (Expedited Forwarding, DSCP 46 / `0x2E`) for audio RTP streams and CS7 for control. No DSCP marking is configured on the inferno appliance. On congested networks where audio packets compete with background traffic, unmarked packets may be deprioritised by QoS-aware switches, introducing latency jitter.

##### Why implement?

The Dante specification recommends DSCP marking. Switches with QoS configured will prioritise EF-marked packets, providing up to 10x latency improvement under load. Critical for large Dante installations with 100+ audio channels where network contention is realistic.

##### Why NOT implement (or defer)?

DSCP marking is only effective if the network switches support and are configured for QoS. In small installations with unmanaged switches, DSCP marking has no effect. Risk: incorrectly marking non-audio traffic as EF could interfere with other QoS policies on the network.

##### Implementation notes

Add to nftables configuration (Item 65):

```nft
table inet mangle {
    chain output {
        type route hook output priority mangle; policy accept;
        # Dante audio RTP — DSCP EF
        meta l4proto udp udp dport 6000-6999 ip dscp set ef
        # PTP — DSCP CS7
        meta l4proto udp udp dport { 319, 320 } ip dscp set cs7
    }
}
```

Make configurable: add `INFERNO_DSCP_MARKING=yes` to `/etc/inferno.conf`. In `inferno-configure.sh`, conditionally include the mangle table in `nftables.conf` if the option is set.

---

---

#### Item 88 — Configurable PTP Domain Number
> Later -- scheduled for a future sprint

**Importance:** 🟡 Medium  
**Impact:** Supports mixed PTP environments where Dante uses a non-default PTP domain  
**Difficulty:** Easy (<2h)  
**Risk:** Low  
**Prerequisites:** None  

##### What is it?

`templates/inferno-ptpv1.toml` hardcodes `domain = 0`. Dante uses PTP domain 0 by default, but some installations use domain 1 (e.g., certain Shure configurations) or domain 127. Operators with existing PTP infrastructure on non-default domains cannot use the default inferno configuration without manually editing template files after each image update.

##### Why implement?

PTP domain mismatch is a common cause of "PTP not converging" support issues. Making the domain number configurable via `/etc/inferno.conf` allows operators to match their existing PTP infrastructure without modifying image files — following the same pattern already used for NIC name and device name substitution.

##### Why NOT implement (or defer)?

No reason to defer. Straightforward template variable substitution — the same mechanism already used for other template values.

##### Implementation notes

1. Add `INFERNO_PTP_DOMAIN=0` to `/etc/inferno.conf` template.
2. Add `%%INFERNO_PTP_DOMAIN%%` placeholder to `templates/inferno-ptpv1.toml.template`.
3. Add substitution in `inferno-configure.sh` `substitute()` call.
4. Add "PTP Domain" field to Cockpit Config tab PTP section.
5. Validate that domain is 0–127 (PTP specification limit).

---

---

#### Item 102 — IGMP Multicast Group Membership for Dante
> On Hold -- pending decision

**Importance:** 🟡 Medium  
**Impact:** Prevents Dante control traffic drops on managed switches with IGMP snooping enabled  
**Difficulty:** Easy  
**Risk:** Low  
**Prerequisites:** None

##### What is it?
Dante control uses multicast groups `224.0.0.107` and `224.0.1.129`. On managed switches with IGMP snooping, the switch only forwards multicast frames to ports that have explicitly joined the group. NetworkManager reconfiguring the interface (e.g. DHCP renewal) can silently drop multicast group memberships, causing Dante discovery to stop working until the next restart.

##### Why implement?
Dante "no devices" issues on managed-switch environments are often caused by dropped IGMP memberships. This is a low-effort fix that prevents an entire class of discovery failures in professional AV installs.

##### Why NOT implement (or defer)?
On unmanaged switches (the majority of home/small installs), IGMP snooping is not active and this change has no effect. Low risk.

##### Implementation notes
```bash
# inferno-configure.sh — after NIC detection
ip addr add 224.0.0.107 dev "$INFERNO_NIC" autojoin 2>/dev/null || true
ip addr add 224.0.1.129 dev "$INFERNO_NIC" autojoin 2>/dev/null || true
```
Add NetworkManager dispatcher to re-join on interface-up events:
```bash
# /etc/NetworkManager/dispatcher.d/50-inferno-multicast
#!/bin/bash
[ "$1" = "$(cat /etc/inferno.conf | grep INFERNO_NIC | cut -d= -f2)" ] || exit 0
[ "$2" = "up" ] || exit 0
ip addr add 224.0.0.107 dev "$1" autojoin 2>/dev/null || true
ip addr add 224.0.1.129 dev "$1" autojoin 2>/dev/null || true
```

---

---


## Deferred

| ID | Title | Importance | Difficulty | Risk | Prerequisites | Sprint |
|---|---|---|---|---|---|---|
| 4 | GRUB / Boot Screen Branding via BIB | Medium | Medium | Low | None | Deferred |
| 24 | Eliminate Reboot at End of inferno-configure.sh | Deferred | Medium | Medium | 11 | Deferred |
| 29 | Image Signing with cosign/sigstore | Deferred | Hard | Low | None | Deferred |
| 32 | Cockpit TLS: Custom Certificate | Deferred | Medium | Low | None | Deferred |
| 37 | IRQ Affinity / CPU Isolation | Deferred | Hard | Medium | None | Deferred |
| 56 | Cockpit: Certificate Management | Deferred | Medium | Medium | None | Deferred |

---

#### Item 4 — GRUB / Boot Screen Branding via BIB
> Deferred -- not currently scheduled

**Importance:** 🟢 Low
**Impact:** Eliminates the post-build `inject-iso-branding.sh` step; branding baked into ISO automatically
**Difficulty:** Medium
**Risk:** Low
**Prerequisites:** 1

> **Implementation note:** Conditional — only implement if BIB supports the required branding elements natively. No workarounds or hybrid approaches; if BIB cannot do it cleanly, leave the post-build `inject-iso-branding.sh` script as-is.

##### What is it?

Currently branding is applied via a post-build script (`inject-iso-branding.sh`) that modifies the ISO after BIB produces it. BIB's `[customizations.installer]` in `config.toml` could handle this natively.

##### Why implement?

Every ISO rebuild requires remembering to run `inject-iso-branding.sh` or shipping an unbranded ISO. Moving branding into `config.toml` makes the build self-contained.

##### Why NOT implement (or defer)?

Defer if BIB's installer customisation API doesn't support all the branding elements currently in the post-build script. The `[customizations.installer]` surface area changes frequently between BIB versions. A hybrid approach (BIB handles what it can, reduced post-build script for the rest) is acceptable.

##### Implementation notes

Track [BIB release notes](https://github.com/osbuild/bootc-image-builder) for native GRUB theme support. For now, the kickstart `bootloader --timeout=3` (Item 3) covers the most important functional aspect of "appliance boot behaviour."

---

#### Item 24 -- Eliminate Reboot at End of inferno-configure.sh
> Deferred -- not currently scheduled

**Importance:** Deferred
**Difficulty:** Medium
**Risk:** Medium
**Prerequisites:** 11 (systemd target restructure)

##### What is it?
`inferno-configure.sh` currently reboots at the end to ensure all services are running in their final state. Eliminating this reboot requires careful systemd target ordering so that services can be activated in-place without a restart.

Deferred until the systemd target restructure (Item 11) is complete — that work is a prerequisite for safely removing the reboot.

---

#### Item 29 -- Image Signing with cosign/sigstore
> Deferred -- not currently scheduled

**Importance:** Deferred
**Difficulty:** Hard
**Risk:** Low
**Prerequisites:** None

##### What is it?
Sign OTA images and bootc container images with `cosign` (sigstore). Verify signatures at update time before applying. This closes the supply-chain attack surface on the update path.

Deferred pending a decision on the key management approach (hardware key vs. CI secret). The signing infrastructure needs to be established before implementation is useful.

---

#### Item 32 -- Cockpit TLS: Custom Certificate
> Deferred -- not currently scheduled

**Importance:** Deferred
**Difficulty:** Medium
**Risk:** Low
**Prerequisites:** None

##### What is it?
Allow operators to provide a custom TLS certificate for the Cockpit web interface instead of using the auto-generated self-signed cert. This eliminates browser security warnings in enterprise deployments.

Deferred until there is a clear deployment model for certificate distribution (ACME, manual, or org CA).

---

#### Item 37 -- IRQ Affinity / CPU Isolation
> Deferred -- not currently scheduled

**Importance:** Deferred
**Difficulty:** Hard
**Risk:** Medium
**Prerequisites:** None

##### What is it?
Pin hardware IRQs away from the CPUs running RT audio workloads. Requires identifying all IRQ sources, setting `smp_affinity` for each, and ensuring new IRQs don't land on isolated CPUs.

Deferred because it requires knowing the IRQ topology of all target hardware (EliteDesks vary by generation). Superseded in priority by Item 98 (RT CPU isolation via `isolcpus`) and Item 99 (NIC interrupt pinning), which are more targeted.

---

#### Item 56 -- Cockpit: Certificate Management
> Deferred -- not currently scheduled

**Importance:** Deferred
**Difficulty:** Medium
**Risk:** Medium
**Prerequisites:** None

##### What is it?
Cockpit UI panel for managing TLS certificates: view current cert, upload a custom cert, trigger ACME renewal. Depends on Item 32 (custom certificate) being implemented first.

---
