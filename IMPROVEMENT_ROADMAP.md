# Inferno AoIP Appliance — Improvement Roadmap

> **Document type:** Engineering review and improvement backlog  
> **Scope:** Fedora bootc appliance (installer, first-boot, runtime, upgrade, build pipeline, operations)  
> **Total items:** 114 (7 bug fixes + 107 improvements) — 51 resolved, 7 rejected, 6 deferred, 50 active  
> **Generated:** April 2026  

> Resolved items archived in [archived/IMPROVEMENT_ROADMAP_DONE.md](archived/IMPROVEMENT_ROADMAP_DONE.md)

## How to Read This Document

Each improvement item is scored on four axes:

| Field | Meaning |
|---|---|
| **Importance** | 🔴 Critical (blocking/broken) · 🟠 High (significant pain) · 🟡 Medium (meaningful improvement) · 🟢 Low (nice-to-have) |
| **Difficulty** | Easy (<2h) · Medium (half-day) · Hard (multi-day) |
| **Risk** | Low · Medium · High — chance of regressions |
| **Prerequisites** | Other item numbers that must be completed first |

Items marked 🔴 Critical should be addressed before any Medium or Low items regardless of category.

## Executive Summary

All 58 items sorted by importance (Critical → High → Medium → Low), then by difficulty (Easy → Medium → Hard) within each level.

| ID | Category | Title | Importance | Difficulty | Risk | Prerequisites |
|---|---|---|---|---|---|---|
| BUG-01 | Bug | `apply-update.sh`: Missing `skopeo copy` Command | ✅ Resolved | Easy (<2h) | Low | None |
| 1 | Install | Add Kickstart to BIB `config.toml` | ✅ Implemented | Easy (<2h) | Low | None |
| 8 | Hardware | NIC Carrier Check | ✅ Implemented | Easy (<2h) | Low | None |
| 26 | Security | Default Password Policy | ✅ Implemented | Easy (<2h) | Low | None |
| 31 | Security | SELinux: `restorecon` After Custom File Copies | ✅ Implemented | Easy (<2h) | Low | None |
| 33 | RT/Reliability | Hardware Watchdog | ✅ Implemented| Easy (<2h) | Low | None |
| 45 | Build | Clean Up `output-vN/` Directories After Build | ✅ Implemented| Easy (<2h) | Low | None |
| 2 | Install | Dynamic Disk Selection in Kickstart | ❌ Rejected | Easy (<2h) | Medium | Item 1 |
| 6 | Install | `multi-user.target` as Default | ✅ Implemented | Easy (<2h) | Low | None |
| 9 | Hardware | Multiple NIC Support / INFERNO_NIC_OVERRIDE | ✅ Implemented | Easy (<2h) | Low | Item 8 |
| 11 | Hardware | snd-aloop Index: Bump to 10 | ✅ Implemented | Easy (<2h) | Medium | None |
| 12 | Hardware | Hardware PTP Auto-Reporting | ✅ Implemented | Easy (<2h) | Low | Item 8 |
| 27 | Security | SSH: Disable Password Authentication | ❌ Rejected | Easy (<2h) | Medium | Item 26 |
| 28 | Security | Firewalld: Configure in the Containerfile | ❌ Rejected | Easy (<2h) | Low | None |
| 34 | RT/Reliability | Service Dependency: `ConditionPathExists=/etc/inferno.conf` | ✅ Implemented| Easy (<2h) | Low | None |
| 35 | RT/Reliability | journald Log Size Limit | ✅ Implemented | Easy (<2h) | Low | None |
| 36 | RT/Reliability | `LimitMEMLOCK=infinity` for RT Services | ✅ Implemented| Easy (<2h) | Low | None |
| 39 | RT/Reliability | Boot: Mask Unnecessary Fedora Services | ✅ Implemented| Easy (<2h) | Low | None |
| 40 | Build | Pin Base Image Digest | ✅ Implemented | Easy (<2h) | Low | None |
| 42 | Build | Reorder Containerfile Layers for Cache Efficiency | ✅ Implemented| Easy (<2h) | Low | None |
| 43 | Build | Pass `--build-arg VERSION=$VERSION` | ✅ Implemented| Easy (<2h) | Low | None |
| 47 | Operations | Cockpit: Surface Node Identity | ✅ Implemented | Easy (<2h) | Low | None |
| 48 | Operations | Health HTTP Endpoint | ✅ Implemented | Easy (<2h) | Low | None |
| 50 | Operations | Upgrade Audit Log with Rollback Events | ✅ Implemented | Easy (<2h) | Low | Item 17 |
| 51 | Operations | Cockpit: `bootc status` Panel | ✅ Implemented | Easy (<2h) | Low | None |
| 54 | Operations | Cockpit: Dante Device Status | ✅ Implemented | Easy (<2h) | Low | Item 47 |
| 7 | Install | Kickstart `%pre` Disk Detection Script | ✅ Implemented | Medium (half-day) | Medium | Item 1 |
| 15 | Upgrade | Version Sentinel Comparison in `inferno-configure.sh` | ✅ Implemented | Medium (half-day) | Medium | BUG-01 |
| 17 | Upgrade | Auto-Rollback on Failed Boot | ✅ Implemented | Medium (half-day) | Medium | BUG-01 |
| 23 | First-boot | `systemd-sysusers` and `tmpfiles.d` for User and Directory Setup | ✅ Implemented (Stage 1) | Medium (half-day) | Medium | None |
| 57 | Security | Cockpit First-Login Password Prompt | ✅ Implemented | Medium (half-day) | Low | None |
| 38 | RT/Reliability | NIC Link-Down Recovery | 🟡 Medium | Medium (half-day) | Low | Items 8, 9 |
| 3 | Install | Boot Timeout = 3s | ✅ Implemented | Easy (<2h) | Low | Item 1 |
| 13 | Hardware | CPU Frequency Scaling: Performance Governor | ✅ Implemented | Easy (<2h) | Low | None |
| 14 | Hardware | `probe-node.sh` Output to `/var/log/inferno-probe.log` | ✅ Implemented | Easy (<2h) | Low | Items 8, 12 |
| 16 | Upgrade | Pre-Upgrade Version Check in `apply-update.sh` | ✅ Implemented | Easy (<2h) | Low | BUG-01 |
| 22 | First-boot | Butane YAML for Ignition | ✅ Implemented | Easy (<2h) | Low | None |
| 44 | Build | Generate `BUILD_DATE` and `GIT_SHA` Build-Args | ✅ Implemented| Easy (<2h) | Low | Item 43 |
| 46 | Build | Parallel ISO Branding + Tarball Export | ✅ Implemented| Easy (<2h) | Medium | None |
| 49 | Operations | mDNS Alias `inferno.local` | ❌ Rejected | Easy (<2h) | Medium | None |
| 10 | Hardware | Predictable NIC Naming via udev (`inferno0`) | ❌ Rejected | Medium (half-day) | High | Items 8, 9 |
| 19 | Upgrade | Delta / Layer-Based Upgrades via Local OCI Registry | ✅ Implemented | Medium (half-day) | Low | BUG-01 |
| 24 | First-boot | Eliminate the Reboot at End of `inferno-configure.sh` | ⏸ Deferred | Medium (half-day) | Medium | Item 11 |
| 32 | Security | Cockpit TLS: Custom Certificate | ⏸ Deferred | Medium (half-day) | Low | None |
| 52 | Operations | Cockpit: One-Click Rollback Button | ✅ Implemented | Medium (half-day) | Medium | Items 50, 51 |
| 53 | Operations | Cockpit: Mode Switcher (Spotify ↔ AUX) | ✅ Implemented | Medium (half-day) | Medium | None |
| 55 | Operations | Cockpit: PTP Clock Status | ✅ Implemented | Medium (half-day) | Low | None |
| 56 | Operations | Cockpit: Certificate Management | ⏸ Deferred | Medium (half-day) | Medium | None |
| 5 | Install | PXE / Netboot Image | ❌ Rejected | Hard (multi-day) | Medium | Items 1, 2 |
| 29 | Security | Image Signing with cosign/sigstore | ⏸ Deferred | Hard (multi-day) | Low | None |
| 37 | RT/Reliability | IRQ Affinity / CPU Isolation | ⏸ Deferred | Hard (multi-day) | Medium | None |
| 20 | Upgrade | Upgrade History in Cockpit | ✅ Implemented | Easy (<2h) | Low | BUG-01 |
| 25 | First-boot | `INFERNO_NIC_OVERRIDE` in Ignition/Kickstart | ✅ Implemented | Easy (<2h) | Low | Item 9 |
| 30 | Security | OCI Labels for Version Tracking | ✅ Implemented| Easy (<2h) | Low | None |
| 4 | Install | GRUB / Boot Screen Branding via BIB | ⏸ Deferred — BIB has no native GRUB branding API | Medium (half-day) | Low | Item 1 |
| 41 | Build | Multi-Stage Containerfile | ❌ Rejected | Medium (half-day) | Low | None |
| 18 | Upgrade | Upload Resume / Chunked Upload | ✅ Implemented | Hard (multi-day) | Medium | BUG-01 |
| BUG-05 | Security | SELinux `unlabeled_t` on `/var/home/core/.ssh` | ✅ Resolved | Easy (<2h) | Low | None |
| BUG-07 | Security | Credentials Committed to Documentation Files | 🔴 Critical | Easy (<2h) | Low | None |
| BUG-08 | Security | `apply-update.sh` Uses `eval` with Python Heredoc for JSON Parsing | 🟠 High | Medium (half-day) | Medium | None |
| 58 | RT/Reliability | PREEMPT_RT Kernel Option | 🟡 Medium | Hard (multi-day) | High | None |
| 59 | Security | `restorecon` for User Home Dir in `inferno-configure.sh` | ✅ Implemented | Easy (<2h) | Low | None |
| 60 | Operations | `dante-network-bench.sh` Default Timeout 3s → 8s | 🟢 Low | Easy (<2h) | Low | None |
| 61 | Build | Cockpit Plugin Update Without Full Image Rebuild | 🟡 Medium | Medium (half-day) | Low | None |
| 62 | Security | Restrict `sudo` to Specific Inferno Commands | 🟠 High | Easy (<2h) | Low | None |
| 63 | Security | Enable OTA Bundle Signature Enforcement by Default | 🟠 High | Easy (<2h) | Low | None |
| 64 | Security | URL Allowlist for IoT Updater `POST /fetch-url` | 🟡 Medium | Easy (<2h) | Low | None |
| 65 | Security | Firewall Configuration (nftables) for Inferno Appliance | 🟠 High | Medium (half-day) | Medium | None |
| 66 | Security | TLS Certificate Validation for Bundle URL Fetches | 🟡 Medium | Easy (<2h) | Low | None |
| 67 | Build | Remove/Redact Hardcoded IPs from Bench Scripts | 🟢 Low | Easy (<2h) | Low | None |
| 68 | Build | Add `.containerignore` to Reduce Build Context Size | 🟡 Medium | Easy (<2h) | Low | None |
| 69 | Build | Pin `bootc-image-builder` Image Version in Build Script | 🟡 Medium | Easy (<2h) | Low | None |
| 70 | Build | Add `--setopt=tsflags=nodocs` to DNF Install | 🟢 Low | Easy (<2h) | Low | None |
| 71 | Build | Tag Releases on Submodule Repositories | 🟢 Low | Easy (<2h) | Low | None |
| 72 | Build | Consolidate Containerfile RUN Layers | 🟢 Low | Medium (half-day) | Low | None |
| 73 | Build | BATS Test Suite for Shell Scripts | 🟡 Medium | Hard (multi-day) | Low | None |
| 74 | Operations | Continuous Health Monitoring Daemon | 🟡 Medium | Medium (half-day) | Low | None |
| 75 | RT/Reliability | Resource Limits in Service Units (MemoryMax, TasksMax, CPUQuota) | 🟡 Medium | Easy (<2h) | Low | None |
| 76 | RT/Reliability | Explicit Systemd Service Dependencies Between User Services | 🟡 Medium | Easy (<2h) | Low | None |
| 77 | RT/Reliability | Restart Backoff Strategy for Flapping Services | 🟢 Low | Easy (<2h) | Low | None |
| 78 | Operations | Log Rotation for Custom Script Logs | 🟡 Medium | Easy (<2h) | Low | None |
| 79 | Upgrades | Config Backup Before OTA Update | 🟡 Medium | Easy (<2h) | Low | None |
| 80 | First-boot | Boot-Time Disk Space and RAM Check | 🟡 Medium | Easy (<2h) | Low | None |
| 81 | Operations | User Action Audit Trail in Cockpit UI | 🟡 Medium | Medium (half-day) | Low | None |
| 82 | Operations | Prometheus Metrics Endpoint via PCP | 🟡 Medium | Medium (half-day) | Low | None |
| 83 | Operations | Central Logging via `systemd-journal-remote` | 🟡 Medium | Medium (half-day) | Low | None |
| 84 | Operations | SNMP v2c Read-Only Agent | 🟢 Low | Hard (multi-day) | Low | None |
| 85 | Network/Dante | DSCP/QoS Marking for Dante Audio Traffic | 🟡 Medium | Medium (half-day) | Medium | 65 |
| 86 | Network/Dante | VLAN Interface Support for Dante AoIP Network | 🟡 Medium | Hard (multi-day) | Medium | None |
| 87 | Network/Dante | Dante Device Name Conflict Detection | 🟡 Medium | Easy (<2h) | Low | None |
| 88 | Network/Dante | Configurable PTP Domain Number | 🟡 Medium | Easy (<2h) | Low | None |
| 89 | Network/Dante | PTP Offset Alerting Threshold | 🟡 Medium | Medium (half-day) | Low | 74 |
| 90 | Operations | Internet Radio (iradio) Channel/Station Management in Cockpit | 🟢 Low | Medium (half-day) | Low | None |
| 91 | RT/Reliability | `statime` Log Level: Reduce from `trace` to `info` in Production | 🟢 Low | Easy (<2h) | Low | None |
| 92 | First-boot | `inferno-configure.sh` Idempotent Re-Run Mode | 🟡 Medium | Medium (half-day) | Medium | None |
| 93 | First-boot | Auto-Hostname Conflict Detection | 🟡 Medium | Easy (<2h) | Low | None |
| 94 | First-boot | librespot Cache Size Limit | 🟢 Low | Easy (<2h) | Low | None |
| 95 | Operations | Cockpit Configuration Export/Import | 🟡 Medium | Medium (half-day) | Low | None |
| 96 | Operations | Cockpit In-App Help / Troubleshooting Runbook | 🟡 Medium | Medium (half-day) | Low | None |
| 97 | RT / Reliability | Disable RT Throttling (`sched_rt_runtime_us=-1`) | 🟠 High | Easy | Low | None |
| 98 | RT / Reliability | RT CPU Isolation (`isolcpus` + `nohz_full` + `rcu_nocbs`) | 🟠 High | Medium | Medium | 97, 108 |
| 99 | RT / Reliability | NIC Interrupt Pinning Away from RT CPUs | 🟡 Medium | Medium | Medium | 98 |
| 100 | Hardware Detection | Hardware PTP Timestamping Enforcement | 🔴 Critical | Easy | Low | None |
| 101 | Network / Dante | PTP `priority1 = 255` Slave-Only Enforcement | 🟡 Medium | Easy | Low | None |
| 102 | Network / Dante | IGMP Multicast Group Membership for Dante | 🟡 Medium | Easy | Low | None |
| 103 | RT / Reliability | NIC TX Queue and Ring Buffer Tuning | 🟡 Medium | Easy | Low | None |
| 104 | Upgrades | bootc Switch Rollback via `FailureAction=` | 🟠 High | Easy | Low | None |
| 105 | Security | Cockpit CSP Hardening (Remove `unsafe-inline`) | 🟠 High | Easy | Low | None |
| 106 | Security | `statime-inferno.service` Capability Sandboxing | 🟠 High | Easy | Medium | None |
| 107 | RT / Reliability | `WatchdogSec=` for Critical Audio Services | 🟠 High | Medium | Low | None |
| 108 | Build Pipeline | `/usr/lib/bootc/kargs.d/` for Declarative Kernel Args | 🟡 Medium | Easy | Low | None |
| 109 | Security | Bundle Manifest `valid_from` Anti-Replay | 🟡 Medium | Medium | Low | 63 |
| 110 | Security | SELinux Policy Module for `inferno_aoip` | 🟡 Medium | Hard | Medium | BUG-05, 59, 106 |
| 111 | Developer Experience | `cockpit.transport.wait()` for Plugin Init | 🟡 Medium | Easy | Low | None |

## Where to Start

### Top 5 Quick Wins (Easy difficulty, High or Critical importance)

1. **BUG-01 — `apply-update.sh`: Missing `skopeo copy`** — ✅ **RESOLVED** (April 2026, commits `a8d2890` / `a1cd215` on `legopc/cockpit-iot-updater`). See BUG-01 section for full resolution notes including additional bugs fixed during investigation.
2. **Item 33 — Hardware Watchdog** — A Critical+Easy item that gives the appliance automatic crash/hang recovery. Without it, a wedged librespot or a kernel panic requires physical intervention at the customer site.
3. **Item 26 — Default Password Policy** — The appliance ships with a default credential; this must be enforced before any unit leaves the build pipeline. One-liner in `inferno-configure.sh` or the Containerfile.
4. **Item 31 — SELinux: `restorecon` After Custom File Copies** — Critical and trivially easy; without it, files copied into the image via `COPY` in the Containerfile may carry wrong SELinux labels, causing silent service failures after first boot.
5. **Item 45 — Clean Up `output-vN/` Directories After Build** — Critical disk hygiene: each build accumulates multi-GB artifact directories; without cleanup the build host will eventually run out of space and fail silently mid-build.

### Top 5 High-Impact Items (regardless of difficulty)

1. **Item 17 — Auto-Rollback on Failed Boot** — Without this, a bad image update permanently bricks the appliance (requires physical access to recover). This is the single highest safety item in the entire roadmap; once BUG-01 is fixed this should be next.
2. **BUG-01 — `apply-update.sh`: Missing `skopeo copy`** — ✅ **RESOLVED** (April 2026). Unlocks the entire upgrade subsystem. Every upgrade-related item (15, 16, 17, 18, 19, 20, 50) is blocked until this is resolved.
3. **Item 33 — Hardware Watchdog** — Auto-recovery from crashes and hangs without human intervention; critical for a headless appliance deployed in AV racks.
4. **Item 26 — Default Password Policy** — A shipped appliance with a known default credential is a security incident waiting to happen; eliminates that risk entirely.
5. **Item 1 — Add Kickstart to BIB `config.toml`** — Enables fully unattended zero-touch provisioning; without it every new node requires manual install interaction. It is also the prerequisite foundation for Items 2, 3, 4, 5, 7.


### New Quick Wins Added (Session 2, April 2026)

6. **BUG-05 — SELinux `unlabeled_t` on `/var/home/core/.ssh`** — Critical+Easy: add one `restorecon` call in `inferno-configure.sh` to fix silent SSH key auth failures on all deployed nodes.
7. **BUG-07 — Credentials in Documentation Files** — Critical+Easy: scrub `(redacted)` from docs and add a pre-commit hook to prevent future credential commits.
8. **Item 59 — `restorecon` for User Home Dir** — same fix as BUG-05, confirmed path in `inferno-configure.sh`; one-liner after `chown -R core:core`.
9. **Item 62 — Restrict `sudo` to Specific Commands** — High+Easy: scope NOPASSWD sudo grant from `ALL` to a specific whitelist; eliminates the broadest attack vector if Cockpit is compromised.
10. **Item 63 — Enable OTA Bundle Signature Enforcement by Default** — High+Easy: flip one env var default from `0` to `1`; signature infrastructure already exists.
11. **Item 97 — Disable RT Throttling (`sched_rt_runtime_us=-1`)** — High+Easy: one sysctl file prevents kernel from preempting statime for 50ms/s; single highest-leverage RT tuning available.
12. **Item 100 — Hardware PTP Timestamping Enforcement** — Critical+Easy: verify HW timestamps are active at configure time; silent SW fallback is the leading cause of poor PTP accuracy.
13. **Item 101 — PTP `priority1 = 255`** — Medium+Easy: one-line change prevents Inferno from accidentally becoming PTP grandmaster on a quiet network.
14. **Item 104 — bootc Rollback via `FailureAction=`** — High+Easy: closes the gap where hard-lock before multi-user.target leaves no rollback path.
15. **Item 105 — Cockpit CSP `unsafe-inline` removal** — High+Easy: eliminates CSS injection XSS vector in Cockpit plugins.
16. **Item 106 — statime Capability Sandboxing** — High+Easy: strip 35+ unnecessary Linux capabilities from PTP daemon.

### Recommended Sequencing

Natural "stacks" that should be done together as sprint-sized units:

- **Upgrade safety stack (BUG-01 → 15 → 16 → 17 → 50):** Fix the broken command first, add the version sentinel, add the pre-upgrade check, implement auto-rollback, then surface the audit log in Cockpit. These form a complete safe-upgrade story.
- **Install/kickstart stack (1 → 2 → 7):** Kickstart entry in config.toml, then dynamic disk selection, then the `%pre` detection script. Items 3 and 6 can be bundled into the same PR cheaply.
- **NIC/hardware stack (8 → 9 → 12 → 10 → 14):** Carrier check first, then multi-NIC override support, then PTP auto-reporting, then (carefully) predictable naming via udev (High risk), then probe log.
- **Security baseline stack (26 → 27 → 28 → 31):** Password policy, SSH hardening, firewalld rules, and SELinux restorecon — all Easy, all Critical or High, do them in one pass.
- **Build hygiene stack (43 → 44 → 40 → 42 → 45):** Pass VERSION build-arg, add BUILD_DATE/GIT_SHA, pin base image digest, reorder layers for cache, then add output-dir cleanup. All Easy, all High or Critical.
- **Cockpit operations stack (47 → 54 → 51 → 48):** Node identity panel, Dante status, bootc status, health endpoint — all Easy+High and buildable incrementally.

## Dependency Map

Items with no prerequisites are safe to start immediately. Items with prerequisites should wait until those are marked done.

```
BUG-01  → (none)
Item 1  → (none)
Item 2  → Item 1
Item 7  → Item 1
Item 8  → (none)
Item 9  → Item 8
Item 10 → Items 8, 9
Item 11 → (none)
Item 12 → Item 8
Item 14 → Items 8, 12
Item 15 → BUG-01
Item 16 → BUG-01
Item 17 → BUG-01
Item 18 → BUG-01
Item 19 → (none — infrastructure decision)
Item 22 → (none)
Item 23 → (none)
Item 24 → Item 11
Item 25 → Item 9
Item 26 → (none)
Item 27 → Item 26
Item 28 → (none)
Item 29 → Items 26, 30
Item 30 → Items 43, 44
Item 31 → (none)
Item 32 → (none)
Items 33–39 → (none, each independent)
Items 40–46 → (none, each independent)
Items 47–56 → (none, each independent; some enhanced by Items 12, 30)
```

**Foundation items** (no dependencies, unlock others): BUG-01, Item 1, Item 6, Item 8, Item 11, Item 26, Item 28, Item 31, Item 33, Item 35, Item 39, Item 42, Item 43, Item 45.

> **Note on prerequisites vs. the detail sections:** Items 29 and 30 list "None" as prerequisites in their individual detail entries, but the dependency map above reflects the recommended implementation order: Item 30 (OCI Labels) builds on the `VERSION` and `BUILD_DATE` build-args introduced by Items 43 and 44; Item 29 (cosign signing) is most useful once labels are in place (Item 30) and a password policy is enforced (Item 26). The detail section text is preserved verbatim; the dependency map is the authoritative sequencing guide.

---

## Bug Fixes

### Summary Table

| ID | Title | Importance | Difficulty | Risk | Prerequisites |
|---|---|---|---|---|---|
| BUG-01 | `apply-update.sh`: missing `skopeo copy` command | ✅ Implemented | Easy (<2h) | Low | None |
| BUG-02 | Wizard overlay blocks own dialog (z-index conflict) | ✅ Implemented | Easy (<2h) | Low | None |
| BUG-03 | Add `cockpit-pcp` for Cockpit Metrics & History | ✅ Implemented | Easy (<1h) | Low | None |
| BUG-04 | Dante discovery: longer scan + better results table | 🟡 Medium | Easy (<2h) | Low | None |
| BUG-05 | SELinux `unlabeled_t` on `/var/home/core/.ssh` → SSH key auth fails | ✅ Resolved | Easy (<2h) | Low | None |
| BUG-07 | Credentials Committed to Documentation Files | 🔴 Critical | Easy (<2h) | Low | None |
| BUG-08 | `apply-update.sh` Uses `eval` with Python Heredoc for JSON Parsing | 🟠 High | Medium (half-day) | Medium | None |

#### BUG-04 — Dante Network Discovery: Longer Scan + Better Results

**Problem:** The Dante scan uses `avahi-browse -t` (one-shot/terminate immediately after initial results — typically 2–3 s). Slow devices may not respond in time and results are shown in a minimal text list.

**Solution:**
- Remove `-t` flag; use `timeout 8 avahi-browse -rp _netaudio-arc._tcp` so the scan runs for 8 seconds and captures late responders
- Present results as a clean table with columns: **Device Name**, **IP Address**, **Hostname**
- Show a count of devices found after scan completes

**File:** `cockpit-inferno/src/inferno.js` — `scanDanteDevices()` function

---

---

### New Bug Fixes (Session 2, April 2026)

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

#### BUG-07 — Credentials Committed to Documentation Files

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

## Install / One-Shot Provisioning

### Summary Table

| ID | Title | Importance | Difficulty | Risk | Prerequisites |
|---|---|---|---|---|---|
| 1 | Add Kickstart to BIB `config.toml` | ✅ Implemented | Easy | Low | None |
| 2 | Dynamic disk selection in Kickstart | ❌ Rejected | Easy | Medium | 1 |
| 3 | Boot timeout = 3s | 🟡 Medium | Easy | Low | 1 |
| 4 | GRUB / boot screen branding via BIB | ⏸ Deferred — BIB has no native GRUB branding API | Medium | Low | 1 |
| 5 | PXE / netboot image | ❌ Rejected | Hard | Medium | 1, 2 |
| 6 | `multi-user.target` as default | ✅ Implemented | Easy | Low | None |
| 7 | Kickstart `%pre` disk detection script | ✅ Implemented | Medium | Medium | 1 |

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

#### Item 4 — GRUB / Boot Screen Branding via BIB

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

## HARDWARE DETECTION & ADAPTABILITY

### Summary Table

| ID | Title | Importance | Difficulty | Risk | Prerequisites |
|----|-------|-----------|-----------|------|---------------|
| 8 | NIC carrier check | 🔴 Critical | Easy | Low | None |
| 9 | Multiple NIC support / INFERNO_NIC_OVERRIDE | 🟠 High | Easy | Low | 8 |
| 10 | Predictable NIC naming via udev (`inferno0`) | ❌ Rejected | Medium | High | 8, 9 |
| 11 | snd-aloop index: bump to 10 in modprobe.d | 🟠 High | Easy | Medium | None |
| 12 | Hardware PTP auto-reporting | 🔴 Critical | Easy | Low | 8 |
| 13 | CPU frequency scaling: performance governor | 🟡 Medium | Easy | Low | None |
| 14 | `probe-node.sh` output to `/var/log/inferno-probe.log` | 🟡 Medium | Easy | Low | 8, 12 |

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

## First-Boot Configuration

### Summary Table

| ID | Title | Importance | Difficulty | Risk | Prerequisites |
|---|---|---|---|---|---|
| 22 | Butane YAML for Ignition | 🟡 Medium | Easy | Low | None |
| 23 | `systemd-sysusers` and `tmpfiles.d` for user/directory setup | 🟠 High | Medium | Medium | None |
| 24 | Eliminate reboot at end of `inferno-configure.sh` | ⏸ Deferred | Medium | Medium | Item 11 |
| 25 | `INFERNO_NIC_OVERRIDE` in Ignition/kickstart | 🟢 Low | Easy | Low | Item 9 |
| 80 | Boot-Time Disk Space and RAM Check | 🟡 Medium | Easy (<2h) | Low | None |
| 92 | `inferno-configure.sh` Idempotent Re-Run Mode | 🟡 Medium | Medium (half-day) | Medium | None |
| 93 | Auto-Hostname Conflict Detection | 🟡 Medium | Easy (<2h) | Low | None |
| 94 | librespot Cache Size Limit | 🟢 Low | Easy (<2h) | Low | None |
| 95 | Cockpit Configuration Export/Import | 🟡 Medium | Medium (half-day) | Low | None |
| 96 | Cockpit In-App Help / Troubleshooting Runbook | 🟡 Medium | Medium (half-day) | Low | None |

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

### New First-Boot / Provisioning Improvements (Session 2, April 2026)

---

#### Item 80 — Boot-Time Disk Space and RAM Check

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

#### Item 92 — `inferno-configure.sh` Idempotent Re-Run Mode

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

#### Item 93 — Auto-Hostname Conflict Detection

**Importance:** 🟡 Medium  
**Impact:** Prevents duplicate mDNS hostnames causing routing confusion on the AV network  
**Difficulty:** Easy (<2h)  
**Risk:** Low  
**Prerequisites:** None  

##### What is it?

`inferno-configure.sh` sets the hostname to `inferno-<mac_suffix>` and Avahi advertises it as `inferno-<mac_suffix>.local`. If two nodes somehow get the same MAC suffix (theoretically impossible but seen with batch-ordered NICs using sequential MACs), or if nodes are cloned from the same VM snapshot, mDNS hostname conflicts occur. Avahi silently renames to `inferno-73cf6b-2.local`, confusing operators.

##### Why implement?

mDNS hostname conflicts cause confusing duplicate entries in Dante Controller and make remote access unreliable (both nodes respond to the same `.local` name). Early detection with a warning in the configure log saves significant debugging time.

##### Why NOT implement (or defer)?

The `avahi-browse` check adds ~3 seconds to first-boot configure time. On a network with many nodes, the broadcast scan may miss late responders. This is a best-effort check, not a guarantee — document as such.

##### Implementation notes

After setting hostname in `inferno-configure.sh`, add:

```bash
HOSTNAME_CONFLICT=$(avahi-browse -t -p --resolve _workstation._tcp 2>/dev/null     | grep "^=" | awk -F';' '{print $4}' | grep -c "^${HOSTNAME}$" || true)
if [ "${HOSTNAME_CONFLICT:-0}" -gt 0 ]; then
    echo "WARNING: Hostname ${HOSTNAME} is already visible on the network — possible conflict"
    echo "WARNING: Consider setting INFERNO_NAME in ignition config to a unique value"
fi
```

---

#### Item 94 — librespot Cache Size Limit

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

#### Item 95 — Cockpit Configuration Export/Import

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

#### Item 96 — Cockpit In-App Help / Troubleshooting Runbook

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

## Upgrades

### Summary Table

| ID | Title | Importance | Difficulty | Risk | Prerequisites |
|---|---|---|---|---|---|
| 15 | Version sentinel comparison in `inferno-configure.sh` | 🟠 High | Medium (half-day) | Medium | BUG-01 |
| 16 | Pre-upgrade version check in `apply-update.sh` | ✅ Implemented | Easy (<2h) | Low | BUG-01 |
| 17 | Auto-rollback on failed boot | ✅ Implemented | Medium (half-day) | Medium | BUG-01, 15 |
| 18 | Upload resume / chunked upload | ✅ Implemented | Hard (multi-day) | Medium | BUG-01 |
| 19 | Delta / layer-based upgrades via local OCI registry | ✅ Implemented | Medium (half-day) | Low | BUG-01 |
| 20 | Upgrade history in Cockpit | ✅ Implemented | Easy (<2h) | Low | BUG-01 |
| 79 | Config Backup Before OTA Update | 🟡 Medium | Easy (<2h) | Low | None |

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

#### Item 19 — Delta / Layer-Based Upgrades via Local OCI Registry

> **✅ IMPLEMENTED** — Already implemented in `cockpit-iot-updater` `apply-update.sh` — `bundle_type=delta` path using bsdiff/bspatch. Discovered resolved April 2026. Full detail archived in [archived/IMPROVEMENT_ROADMAP_DONE.md](archived/IMPROVEMENT_ROADMAP_DONE.md).
---

---

### New Upgrade Improvements (Session 2, April 2026)

---

#### Item 79 — Config Backup Before OTA Update

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

## Security

### Summary Table

| ID | Title | Importance | Difficulty | Risk | Prerequisites |
|----|-------|-----------|------------|------|---------------|
| 26 | Default password policy | ✅ Implemented | Easy | Low | None |
| 27 | SSH: disable password authentication | ❌ Rejected | Easy | Medium | 26 |
| 28 | Firewalld: configure in Containerfile | ❌ Rejected | Easy | Low | None |
| 29 | Image signing with cosign/sigstore | ⏸ Deferred | Hard | Low | None |
| 30 | OCI labels for version tracking | 🟢 Low | Easy | Low | None |
| 31 | SELinux: `restorecon` after custom file copies | 🔴 Critical | Easy | Low | None |
| 32 | Cockpit TLS: custom certificate | ⏸ Deferred | Medium | Low | None |
| 57 | Cockpit: first-login password prompt | 🟠 High | Medium (half-day) | Low | None |
| 59 | `restorecon` for User Home Dir in `inferno-configure.sh` | ✅ Implemented | Easy (<2h) | Low | None |
| 62 | Restrict `sudo` to Specific Inferno Commands | 🟠 High | Easy (<2h) | Low | None |
| 63 | Enable OTA Bundle Signature Enforcement by Default | 🟠 High | Easy (<2h) | Low | None |
| 64 | URL Allowlist for IoT Updater `POST /fetch-url` | 🟡 Medium | Easy (<2h) | Low | None |
| 65 | Firewall Configuration (nftables) for Inferno Appliance | 🟠 High | Medium (half-day) | Medium | None |
| 66 | TLS Certificate Validation for Bundle URL Fetches | 🟡 Medium | Easy (<2h) | Low | None |
| 67 | Remove/Redact Hardcoded IPs from Bench Scripts | 🟢 Low | Easy (<2h) | Low | None |

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

### New Security Improvements (Session 2, April 2026)

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

#### Item 62 — Restrict `sudo` to Specific Inferno Commands

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

#### Item 63 — Enable OTA Bundle Signature Enforcement by Default

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

#### Item 64 — URL Allowlist for IoT Updater `POST /fetch-url`

**Importance:** 🟡 Medium  
**Impact:** Prevents SSRF attacks via the bundle fetch endpoint  
**Difficulty:** Easy (<2h)  
**Risk:** Low  
**Prerequisites:** None  

##### What is it?

`sidecar/server.py`'s `/fetch-url` endpoint accepts any `https://` URL as a bundle source. An attacker with Cockpit access (or a compromised Cockpit session) could use this to probe internal network services via SSRF — including cloud metadata endpoints (`169.254.169.254`), internal APIs, or other hosts on the AV LAN.

##### Why implement?

SSRF via bundle fetch is a realistic attack vector on a multi-tenant AV installation where Cockpit may be accessible to multiple operators. An allowlist restricts fetches to known safe hosts with minimal operator impact.

##### Why NOT implement (or defer)?

Operators self-hosting an update server on a custom domain would need to configure the allowlist. Default should be permissive enough for the common case (GitHub releases) while blocking obvious SSRF targets.

##### Implementation notes

Add `ALLOWED_FETCH_HOSTS` environment variable (default: `["github.com", "raw.githubusercontent.com", "releases.github.com"]`). In the `/fetch-url` handler in `server.py`:

```python
from urllib.parse import urlparse
ALLOWED_HOSTS = os.environ.get("ALLOWED_FETCH_HOSTS", "github.com,raw.githubusercontent.com").split(",")

@app.route("/fetch-url", methods=["POST"])
def fetch_url():
    url = request.json.get("url", "")
    host = urlparse(url).hostname
    if host not in ALLOWED_HOSTS:
        return jsonify({"error": f"Host {host} not in allowlist"}), 403
    # ... existing fetch logic
```

Operators with private update servers set `ALLOWED_FETCH_HOSTS=my-update-server.internal` in `/etc/inferno.conf` and the sidecar unit's `EnvironmentFile=`.

---

#### Item 65 — Firewall Configuration (nftables) for Inferno Appliance

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

#### Item 66 — TLS Certificate Validation for Bundle URL Fetches

**Importance:** 🟡 Medium  
**Impact:** Prevents MITM attacks on OTA bundle downloads from custom URL sources  
**Difficulty:** Easy (<2h)  
**Risk:** Low  
**Prerequisites:** None  

##### What is it?

`sidecar/server.py` uses `urllib.request.urlopen(req, timeout=300)` for bundle fetch and manifest downloads with default SSL validation. No explicit `ssl.create_default_context()` is created, meaning the system CA bundle's currency is assumed. Should explicitly create an SSL context and optionally support a custom CA certificate for self-hosted update servers.

##### Why implement?

Explicit SSL context creation is a security best practice — it ensures the system CA bundle is loaded correctly and allows operators with private CA certificates to pin their own CA for custom update servers. The change is three lines.

##### Why NOT implement (or defer)?

Default SSL validation already works correctly in most deployments. This is a defence-in-depth improvement, not a fix for a known vulnerability.

##### Implementation notes

In `server.py`, add to fetch functions:

```python
import ssl
ctx = ssl.create_default_context()
# Optionally add custom CA:
custom_ca = "/etc/iot-updater/ca.crt"
if os.path.exists(custom_ca):
    ctx.load_verify_locations(custom_ca)
response = urllib.request.urlopen(req, context=ctx, timeout=300)
```

Document the `/etc/iot-updater/ca.crt` path for operators with private update servers.

---

#### Item 67 — Remove/Redact Hardcoded IPs from Bench Scripts

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

## Real-Time Audio & Reliability

### Summary Table

| ID | Title | Importance | Difficulty | Risk | Prerequisites |
|---|---|---|---|---|---|
| 33 | Hardware watchdog | 🔴 Critical | Easy (<2h) | Low | None |
| 34 | Service dependency: `ConditionPathExists=/etc/inferno.conf` | 🟠 High | Easy (<2h) | Low | None |
| 35 | journald log size limit | 🟠 High | Easy (<2h) | Low | None |
| 36 | `LimitMEMLOCK=infinity` for RT services | 🟠 High | Easy (<2h) | Low | None |
| 37 | IRQ affinity / CPU isolation | ⏸ Deferred | Hard (multi-day) | Medium | None |
| 38 | NIC link-down recovery | 🟡 Medium | Medium (half-day) | Low | Items 8, 9 |
| 39 | Boot: mask unnecessary Fedora services | 🟠 High | Easy (<2h) | Low | None |

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

#### Item 38 — NIC Link-Down Recovery

**Importance:** 🟡 Medium  
**Impact:** Audio resumes within seconds of cable re-plug instead of requiring 30–60 seconds of failed restarts  
**Difficulty:** Medium (half-day)  
**Risk:** Low  
**Prerequisites:** Items 8, 9  

> **Implementation note:** Priority demoted to Medium. Depends on Items 8 (NIC carrier check) and 9 (multi-NIC support) — implement those first. The `BindsTo=` device unit approach requires stable NIC naming, but Items 8/9 are sufficient prerequisites (Item 10 udev rename is rejected).

##### What is it?

When the Ethernet cable is unplugged, `statime-inferno.service` loses its PTP grandmaster and immediately fails. With `Restart=always`, it restarts — but the NIC has no carrier, so the next start attempt fails instantly too. This cycle repeats at the `RestartSec=` interval (default 100ms), flooding the journal and burning CPU. When the cable is re-plugged, the NIC must re-negotiate link (~2s), DHCP must renew (~5s), and ARP must resolve before Statime can reach the PTP grandmaster. The `Restart=always` loop may restart Statime before the network is ready, causing 3–5 more failures before it finally succeeds. Total recovery: 30–60 seconds of chaos.

Three targeted improvements collapse this to under 10 seconds:

1. **`After=network-online.target`** in `statime-inferno.service` — ensures the service only starts when NetworkManager reports the link is up and routable. Does not help with mid-run link loss, but prevents the initial start storm on boot with a slow NIC.

2. **`ExecStartPre` carrier check** — wait for the NIC carrier before attempting to start:
   ```bash
   ExecStartPre=/bin/bash -c 'until [ "$(cat /sys/class/net/${NIC}/carrier 2>/dev/null)" = "1" ]; do sleep 1; done'
   ```
   This makes the service block at `ExecStartPre` (no failure) until the link is physically up, then proceed to start normally. Combined with `Restart=always`, link-down recovery becomes: cable re-plugged → carrier detected → `ExecStartPre` exits → Statime starts successfully. One restart, clean.

3. **`BindsTo=sys-subsystem-net-devices-<NIC>.device`** — binds the service lifecycle to the kernel device object for the NIC. When the NIC is unplugged (device disappears), systemd stops the service cleanly. When the NIC reappears (cable re-plug or driver reload), systemd restarts it. This requires predictable NIC naming (item 10) because the device unit name is derived from the interface name.

##### Why implement?

Network interruptions in a venue are common — someone trips over a cable, a switch is rebooted, a patch panel connection is jostled. The current behaviour (30–60s of restart storm) is operator-visible: audio cuts out, Cockpit shows service failures, the journal fills with errors. The improvements make the failure mode silent and self-healing in < 10 seconds, which matches what operators expect from a professional audio appliance.

##### Why NOT implement (or defer)?

Defer `BindsTo=sys-subsystem-net-devices-<NIC>.device` until Items 8 and 9 are complete and the NIC name is reliably known at boot time. The `After=network-online.target` and `ExecStartPre` carrier check have no dependencies and should be implemented immediately.

##### Implementation notes

In `statime-inferno.service`:

```ini
[Unit]
After=network-online.target sys-subsystem-net-devices-enp1s0.device
Wants=network-online.target
BindsTo=sys-subsystem-net-devices-enp1s0.device

[Service]
# NIC name must be resolved at runtime from /etc/inferno.conf or environment:
EnvironmentFile=/etc/inferno.conf
ExecStartPre=/bin/bash -c 'until [ "$(cat /sys/class/net/${INFERNO_NIC}/carrier 2>/dev/null)" = "1" ]; do sleep 1; done'
Restart=always
RestartSec=5s
```

Use `RestartSec=5s` rather than the default to avoid hammering the network stack during transient failures. Five seconds is fast enough for practical recovery and slow enough to avoid log floods.

The `BindsTo=` device unit name follows the pattern `sys-subsystem-net-devices-<iface>.device` with hyphens replacing any non-alphanumeric characters in the interface name. For `enp1s0`: `sys-subsystem-net-devices-enp1s0.device`. Verify the unit exists:

```bash
systemctl status sys-subsystem-net-devices-enp1s0.device
```

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

### New RT / Reliability Improvements (Session 2, April 2026)

---

#### Item 58 — PREEMPT_RT Kernel Option

**Importance:** 🟡 Medium  
**Impact:** Sub-100µs scheduling latency for statime/inferno-bridge vs. current ~500µs with PREEMPT_DYNAMIC  
**Difficulty:** Hard (multi-day)  
**Risk:** High  
**Prerequisites:** None  

##### What is it?

The current Fedora IoT 43 kernel uses `PREEMPT_DYNAMIC` with `preempt=full` (full preemption, soft-RT). True `PREEMPT_RT` requires the Linus RT patchset and shows as `PREEMPT_RT` in `uname -a`. Fedora ships `kernel-rt` in its repos since F38, making it installable via dnf. PREEMPT_RT reduces worst-case scheduler latency from ~500µs to ~50µs — a measurable improvement in PTP jitter under CPU load.

##### Why implement?

`cyclictest` P99 latency with PREEMPT_RT is typically 50µs vs. 500µs with PREEMPT_DYNAMIC. For Dante AES67 with tight PTP requirements, reducing worst-case jitter by 10x directly improves audio quality under load. The improvement is most visible on nodes running multiple concurrent workloads (librespot + iradio + cockpit updates).

##### Why NOT implement (or defer)?

`kernel-rt` is a separate package not in `fedora-bootc:43` by default. Replacing the kernel adds ~200MB to the image and requires extensive hardware compatibility testing. bootc may have constraints on non-standard kernels. Dante audio works acceptably with PREEMPT_DYNAMIC for most deployments — this is a marginal improvement for demanding installs, not a fix for a broken feature. Estimate: 3–5 days including testing across all target hardware.

##### Implementation notes

In Containerfile:

```dockerfile
RUN dnf install -y kernel-rt kernel-rt-modules-extra &&     dnf remove -y kernel kernel-core kernel-modules &&     dnf clean all
```

Requires careful testing — verify `uname -r` shows `-rt` suffix, run `cyclictest -l100000 -m -n -a -t -p99 -i200 -h400` to confirm latency improvement, test full Dante audio stack for regressions. See `docs/rt-scheduling.md` for reference benchmarks.

---

#### Item 75 — Resource Limits in Service Units (MemoryMax, TasksMax, CPUQuota)

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

#### Item 76 — Explicit Systemd Service Dependencies Between User Services

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

#### Item 77 — Restart Backoff Strategy for Flapping Services

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

#### Item 91 — `statime` Log Level: Reduce from `trace` to `info` in Production

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

## Build Pipeline & Image Quality

### Summary Table

| ID | Title | Importance | Difficulty | Risk | Prerequisites |
|---|---|---|---|---|---|
| 40 | Pin base image digest | 🟠 High | Easy (<2h) | Low | None |
| 41 | Multi-stage Containerfile | ❌ Rejected | Medium (half-day) | Low | None |
| 42 | Reorder Containerfile layers for cache efficiency | 🟠 High | Easy (<2h) | Low | None |
| 43 | Pass `--build-arg VERSION=$VERSION` | 🟠 High | Easy (<2h) | Low | None |
| 44 | Generate `BUILD_DATE` and `GIT_SHA` build-args | 🟡 Medium | Easy (<2h) | Low | 43 |
| 45 | Clean up `output-vN/` dirs after build | 🔴 Critical | Easy (<2h) | Low | None |
| 46 | Parallel ISO branding + tarball export | 🟡 Medium | Easy (<2h) | Medium | None |

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

### New Build Pipeline / Developer Experience Improvements (Session 2, April 2026)

---

#### Item 61 — Cockpit Plugin Update Without Full Image Rebuild

**Importance:** 🟡 Medium  
**Impact:** Cockpit UI fixes deployable in minutes instead of requiring a 45–60 minute full image rebuild  
**Difficulty:** Medium (half-day)  
**Risk:** Low  
**Prerequisites:** None  

##### What is it?

`/usr/share/cockpit/inferno/` is read-only in the bootc image. Every UI-only fix (layout, labels, a missing status indicator) requires a full image build cycle. The `~/.local/share/cockpit/inferno/` path is writable and Cockpit checks it first, but it requires manual SSH deployment of plugin files.

##### Why implement?

A 45–60 minute build cycle for a one-line UI fix is impractical during active customer deployments. A signed update script that replaces only the Cockpit plugin files enables hotfixes within minutes. This also reduces the pressure to batch unrelated changes into releases, improving overall code quality.

##### Why NOT implement (or defer)?

Out-of-band UI updates bypass the normal image build/test/sign pipeline. Plugin updates must be separately versioned and verified to avoid divergence between the appliance image version and the UI version. Adds complexity to version tracking.

##### Implementation notes

**Option A (recommended):** Mount cockpit plugin from `/var/lib/inferno/cockpit-override/` if present, so OTA updates only need to write to `/var`:

```bash
# In Containerfile:
RUN ln -sf /var/lib/inferno/cockpit-override /root/.local/share/cockpit/inferno-override 2>/dev/null || true
```

**Option B:** `update-cockpit-plugin.sh` script that:

1. Fetches latest `cockpit-inferno` tarball from GitHub releases
2. Verifies SHA256 against a published checksum
3. Extracts to `~/.local/share/cockpit/inferno/`
4. Restarts `cockpit.service`

Add "Check for UI Update" button to Cockpit Config tab. Show current plugin version and available version.

---

#### Item 68 — Add `.containerignore` to Reduce Build Context Size

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

#### Item 69 — Pin `bootc-image-builder` Image Version in Build Script

**Importance:** 🟡 Medium  
**Impact:** Reproducible ISO builds — same BIB version used every time; prevents silent ISO layout changes  
**Difficulty:** Easy (<2h)  
**Risk:** Low  
**Prerequisites:** None  

##### What is it?

`build/build-release.sh` uses `ghcr.io/osbuild/bootc-image-builder:latest` — a floating tag. BIB updates can change ISO layout, Kickstart handling, partition schemes, or introduce breaking changes without notice. A BIB update between v23 and v24 builds could produce different installer behaviour silently.

##### Why implement?

ISO build reproducibility requires a pinned toolchain. If a node in the field reports an installer problem that isn't reproducible, the first question is "what BIB version was used?" — which is currently unanswerable. Pinning to a specific digest answers that question definitively.

##### Why NOT implement (or defer)?

Pinning requires intentional version bumps, which means staying on an older BIB version longer than necessary. BIB is actively developed and may have bug fixes or security patches. Set a reminder to review the pin quarterly.

##### Implementation notes

```bash
# In build-release.sh, replace:
BIB_IMAGE="ghcr.io/osbuild/bootc-image-builder:latest"
# With:
BIB_IMAGE="ghcr.io/osbuild/bootc-image-builder:1.0.0@sha256:<digest>"
```

Get current digest: `podman pull ghcr.io/osbuild/bootc-image-builder:latest && podman inspect ghcr.io/osbuild/bootc-image-builder:latest --format '{{.Digest}}'`. Document the BIB version and upgrade procedure in `docs/build-process.md`.

---

#### Item 70 — Add `--setopt=tsflags=nodocs` to DNF Install

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

#### Item 71 — Tag Releases on Submodule Repositories

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

#### Item 72 — Consolidate Containerfile RUN Layers

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

#### Item 73 — BATS Test Suite for Shell Scripts

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

## Operations & Cockpit UI

### Summary Table

| ID | Title | Importance | Difficulty | Risk | Prerequisites |
|---|---|---|---|---|---|
| 47 | Cockpit: surface node identity | ✅ Implemented | Easy (<2h) | Low | None |
| 48 | Health HTTP endpoint | 🟠 High | Easy (<2h) | Low | None |
| 49 | mDNS alias `inferno.local` | ❌ Rejected | Easy (<2h) | Medium | None |
| 50 | Upgrade audit log with rollback events | ✅ Implemented | Easy (<2h) | Low | 17 |
| 51 | Cockpit: `bootc status` panel | ✅ Implemented | Easy (<2h) | Low | None |
| 52 | Cockpit: one-click rollback button | ✅ Implemented | Medium (half-day) | Medium | 50, 51 |
| 53 | Cockpit: mode switcher (Spotify ↔ AUX) | ✅ Implemented | Medium (half-day) | Medium | None |
| 54 | Cockpit: Dante device status | ✅ Implemented | Easy (<2h) | Low | 47 |
| 55 | Cockpit: PTP clock status | ✅ Implemented | Medium (half-day) | Low | None |
| 56 | Cockpit: certificate management | ⏸ Deferred | Medium (half-day) | Medium | None |
| 60 | `dante-network-bench.sh` Default Timeout 3s → 8s | 🟢 Low | Easy (<2h) | Low | None |
| 74 | Continuous Health Monitoring Daemon | 🟡 Medium | Medium (half-day) | Low | None |
| 78 | Log Rotation for Custom Script Logs | 🟡 Medium | Easy (<2h) | Low | None |
| 81 | User Action Audit Trail in Cockpit UI | 🟡 Medium | Medium (half-day) | Low | None |
| 82 | Prometheus Metrics Endpoint via PCP | 🟡 Medium | Medium (half-day) | Low | None |
| 83 | Central Logging via `systemd-journal-remote` | 🟡 Medium | Medium (half-day) | Low | None |
| 84 | SNMP v2c Read-Only Agent | 🟢 Low | Hard (multi-day) | Low | None |
| 90 | Internet Radio (iradio) Channel/Station Management in Cockpit | 🟢 Low | Medium (half-day) | Low | None |

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

### New Operations / Observability Improvements (Session 2, April 2026)

---

#### Item 60 — `dante-network-bench.sh` Default Timeout 3s → 8s

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

#### Item 74 — Continuous Health Monitoring Daemon

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

#### Item 78 — Log Rotation for Custom Script Logs

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

#### Item 81 — User Action Audit Trail in Cockpit UI

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

#### Item 82 — Prometheus Metrics Endpoint via PCP

**Importance:** 🟡 Medium  
**Impact:** Enables integration with Grafana/Prometheus monitoring stacks for AV system visibility  
**Difficulty:** Medium (half-day)  
**Risk:** Low  
**Prerequisites:** None  

##### What is it?

`pcp` (Performance Co-Pilot) is already installed for Cockpit metrics. PCP ships `pmproxy` which can expose PCP metrics as a Prometheus-compatible endpoint on port 44322 when run with `--timeseries`. This is not configured. PTP offset, audio xrun count, service uptime, CPU governor frequency, and disk utilisation are all available as PCP metrics.

##### Why implement?

AV integrators with Grafana/Prometheus monitoring stacks want to pull metrics from all devices without SSH. PTP offset trends over time are particularly valuable — they reveal systematic clock drift patterns not visible in instantaneous Cockpit displays.

##### Why NOT implement (or defer)?

`pmproxy` adds a listening service on port 44322. This port must be added to the firewall config (Item 65). PCP's Prometheus format may not include all desired metrics out-of-the-box — custom PCP metrics for inferno-specific data (PTP offset, Dante status) would require additional development.

##### Implementation notes

Add `pcp-export-pcp2prometheus` to Containerfile package list. Enable `pmproxy` with `--timeseries` flag:

```bash
systemctl enable pmproxy.service
```

Set `PMPROXY_OPTIONS=--timeseries` in `/etc/sysconfig/pmproxy`. Add firewall rule for port 44322 (optional, operator-controlled via `INFERNO_PROMETHEUS_ENABLED=yes` in `/etc/inferno.conf`).

---

#### Item 83 — Central Logging via `systemd-journal-remote`

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

#### Item 84 — SNMP v2c Read-Only Agent

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

#### Item 90 — Internet Radio (iradio) Channel/Station Management in Cockpit

**Importance:** 🟢 Low  
**Impact:** Operators can manage iRadio stations from Cockpit without SSH  
**Difficulty:** Medium (half-day)  
**Risk:** Low  
**Prerequisites:** None  

##### What is it?

iRadio mode is supported via the `iradio-bridge` submodule and the Cockpit mode switcher. However, station management — adding, removing, and reordering internet radio station URLs — requires SSH and direct editing of the iradio config file. The Cockpit Config tab shows an iradio mode option but no inline station editor.

##### Why implement?

iRadio mode is a value-add feature that differentiates inferno from a basic Dante device. Operators using iRadio mode should be able to manage their station list from the same Cockpit interface they use for everything else. Requiring SSH for station management undermines the "no SSH needed" operator story.

##### Why NOT implement (or defer)?

iRadio is a secondary feature; implement after the core audio features are stable. Station management requires reading/writing a TOML config file via Cockpit — use `cockpit.file()` API for this.

##### Implementation notes

Add station editor card to Cockpit Config tab (only visible when mode = iradio):

```javascript
// Only show when in iradio mode
if (mode === "iradio") {
    renderIradioStations(config.iradio_stations);
}
```

Read/write iradio config TOML via `cockpit.file("/etc/iradio.toml")`. Show station list as editable rows: name, URL, enabled toggle. On save, call `spSudo("systemctl --user restart iradio-bridge")`.

---


---

## Network / Dante Audio

> New section added Session 2, April 2026. Items 85–89 covering Dante-specific network configuration and audio quality improvements.

### Summary Table

| ID | Title | Importance | Difficulty | Risk | Prerequisites |
|---|---|---|---|---|---|
| 85 | DSCP/QoS Marking for Dante Audio Traffic | 🟡 Medium | Medium (half-day) | Medium | 65 |
| 86 | VLAN Interface Support for Dante AoIP Network | 🟡 Medium | Hard (multi-day) | Medium | None |
| 87 | Dante Device Name Conflict Detection | 🟡 Medium | Easy (<2h) | Low | None |
| 88 | Configurable PTP Domain Number | 🟡 Medium | Easy (<2h) | Low | None |
| 89 | PTP Offset Alerting Threshold | 🟡 Medium | Medium (half-day) | Low | 74 |

---

### New Network / Dante Audio Improvements (Session 2, April 2026)

---

#### Item 85 — DSCP/QoS Marking for Dante Audio Traffic

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

#### Item 86 — VLAN Interface Support for Dante AoIP Network

**Importance:** 🟡 Medium  
**Impact:** Supports dedicated AoIP VLANs — standard practice in professional AV installations  
**Difficulty:** Hard (multi-day)  
**Risk:** Medium  
**Prerequisites:** None  

##### What is it?

Professional AV installations typically use a dedicated VLAN for Dante traffic (e.g., VLAN 10 for AoIP, VLAN 1 for management). Currently, inferno uses the same NIC and VLAN for both management (Cockpit, SSH) and Dante audio. Supporting `INFERNO_DANTE_VLAN=10` in the config would allow creating a VLAN sub-interface for Dante traffic while management stays on the native interface.

##### Why implement?

Dedicated Dante VLANs: (1) isolate audio multicast from management traffic, (2) enable per-VLAN QoS policies on managed switches, (3) match the Audinate recommended deployment architecture for large installs. Many enterprise AV integrators require this for compliance with their network segmentation policies.

##### Why NOT implement (or defer)?

Hard difficulty and medium risk reflect the complexity of creating VLAN interfaces via NetworkManager, ensuring Dante binds to the VLAN interface instead of the native NIC, handling the PTP vs. management interface split, and testing across different switch configurations. Defer until the simpler items (DSCP, domain config) are in place.

##### Implementation notes

Add to `inferno-configure.sh`: if `INFERNO_DANTE_VLAN` is set and non-empty, create VLAN interface:

```bash
if [ -n "${INFERNO_DANTE_VLAN:-}" ]; then
    DANTE_IFACE="${INFERNO_NIC}.${INFERNO_DANTE_VLAN}"
    nmcli connection add type vlan ifname "${DANTE_IFACE}"         dev "${INFERNO_NIC}" id "${INFERNO_DANTE_VLAN}"
fi
```

Update statime and inferno-bridge configurations to use `${DANTE_IFACE}` instead of `${INFERNO_NIC}` when `INFERNO_DANTE_VLAN` is set.

---

#### Item 87 — Dante Device Name Conflict Detection

**Importance:** 🟡 Medium  
**Impact:** Prevents audio routing failures caused by duplicate device names in Dante Controller  
**Difficulty:** Easy (<2h)  
**Risk:** Low  
**Prerequisites:** None  

##### What is it?

Inferno's Dante device name is derived from the MAC address suffix (e.g., `Inferno-73CF6B`). If two nodes produce the same name — due to sequential MAC assignment in batch NIC orders, VM cloning, or MAC spoofing — Dante Controller displays both with the same name, creating routing confusion. No detection or warning currently exists.

##### Why implement?

Dante name conflicts cause routing failures that are extremely difficult to diagnose without physical access. Operators see "two devices with the same name" in Dante Controller and cannot determine which is which. Early detection during first-boot or via Cockpit monitoring allows the operator to set a unique name via `INFERNO_NAME` in the config.

##### Why NOT implement (or defer)?

`avahi-browse` conflict detection adds ~8s to first-boot. On a large network, the scan may not capture all devices before timing out. This is best-effort detection, not a guarantee.

##### Implementation notes

In `inferno-configure.sh`, after device name is set:

```bash
CONFLICT=$(avahi-browse -t -p --resolve _netaudio-arc._udp 2>/dev/null     | awk -F';' '{print $4}' | grep -c "^${INFERNO_NAME}$" || true)
if [ "${CONFLICT:-0}" -gt 0 ]; then
    echo "WARNING: Dante device name '${INFERNO_NAME}' already visible on network — possible conflict"
    echo "WARNING: Set INFERNO_NAME in /etc/inferno.conf to a unique value"
fi
```

Also add to Cockpit Monitoring tab `scanDanteDevices()`: if any discovered device name matches local `INFERNO_NAME` on a different IP, show a warning badge.

---

#### Item 88 — Configurable PTP Domain Number

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

#### Item 89 — PTP Offset Alerting Threshold

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

## RT / Reliability — Web Research Additions (Session 2)

### Summary Table

| # | Title | Importance | Difficulty | Risk | Prerequisites |
|---|-------|------------|------------|------|---------------|
| 97 | Disable RT Throttling (`sched_rt_runtime_us=-1`) | 🟠 High | Easy | Low | None |
| 98 | RT CPU Isolation (`isolcpus` + `nohz_full` + `rcu_nocbs`) | 🟠 High | Medium | Medium | 97 |
| 99 | NIC Interrupt Pinning Away from RT CPUs | 🟡 Medium | Medium | Medium | 98 |
| 100 | Hardware PTP Timestamping Enforcement | 🔴 Critical | Easy | Low | None |
| 101 | PTP `priority1 = 255` Slave-Only Enforcement | 🟡 Medium | Easy | Low | None |
| 102 | IGMP Multicast Group Membership for Dante | 🟡 Medium | Easy | Low | None |
| 103 | NIC TX Queue and Ring Buffer Tuning | 🟡 Medium | Easy | Low | None |
| 104 | bootc Switch Rollback via `FailureAction=` | 🟠 High | Easy | Low | None |
| 105 | Cockpit CSP Hardening (Remove `unsafe-inline`) | 🟠 High | Easy | Low | None |
| 106 | `statime-inferno.service` Capability Sandboxing | 🟠 High | Easy | Medium | None |
| 107 | `WatchdogSec=` for Critical Audio Services | 🟠 High | Medium | Low | None |
| 108 | `/usr/lib/bootc/kargs.d/` for All Kernel Args | 🟡 Medium | Easy | Low | None |
| 109 | Bundle Manifest `valid_from` Anti-Replay | 🟡 Medium | Medium | Low | 63 |
| 110 | SELinux Policy Module for `inferno_aoip` | 🟡 Medium | Hard | Medium | BUG-05, 59 |
| 111 | `cockpit.transport.wait()` for Plugin Init | 🟡 Medium | Easy | Low | None |

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

#### Item 98 — RT CPU Isolation (`isolcpus` + `nohz_full` + `rcu_nocbs`)

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

#### Item 99 — NIC Interrupt Pinning Away from RT CPUs

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

#### Item 100 — Hardware PTP Timestamping Enforcement

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

#### Item 101 — PTP `priority1 = 255` Slave-Only Enforcement

**Importance:** 🟡 Medium  
**Impact:** Prevents Inferno from accidentally winning PTP grandmaster election on a network with no other Dante master  
**Difficulty:** Easy  
**Risk:** Low  
**Prerequisites:** None

##### What is it?
`templates/inferno-ptpv1.toml` uses `priority1 = 251`. IEEE 1588 BMCA: `priority1 = 255` means "never become master" — the device explicitly refuses grandmaster election. At 251, if no other Dante device is visible, Inferno could win the BMCA election and become grandmaster with its unsynchronised free-running clock, causing every other Dante device to slew to an incorrect time reference.

##### Why implement?
Inferno is a Dante endpoint/bridge, not a grandmaster clock. It should never be selected as PTP master. A professional install that loses its Dante grandmaster clock should not silently fall back to Inferno's local clock — it should log a fault.

##### Why NOT implement (or defer)?
In a standalone single-node test setup, `priority1=255` means the node never has a master. statime should handle this gracefully (not crash), but behaviour should be verified.

##### Implementation notes
One-line change in `templates/inferno-ptpv1.toml`:
```toml
priority1 = 255   # slave-only: never win BMCA grandmaster election
priority2 = 255   # belt-and-suspenders
```
Verify statime handles no-master condition gracefully before deploying.

---

#### Item 102 — IGMP Multicast Group Membership for Dante

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

#### Item 103 — NIC TX Queue and Ring Buffer Tuning

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

#### Item 108 — `/usr/lib/bootc/kargs.d/` for Declarative Kernel Args

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

#### Item 109 — Bundle Manifest `valid_from` Anti-Replay Timestamp

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

#### Item 110 — SELinux Policy Module for `inferno_aoip`

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

#### Item 111 — `cockpit.transport.wait()` for Plugin Initialisation

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

## Deferred — Not Now

> These items were reviewed during April 2026 sprint planning and deferred. They remain candidates for future sprints but are out of scope for current work.

| # | Title | Original Priority | Reason for Deferral |
|---|-------|-------------------|---------------------|
| 24 | Eliminate the Reboot at End of inferno-configure.sh | 🟡 Medium | Reboot is a safe catch-all; revisit once other firstboot changes are stable |
| 29 | Image Signing with cosign/sigstore | 🟡 Medium | Closed deployment, low tamper risk; revisit when security posture requires it |
| 32 | Cockpit TLS: Custom Certificate | 🟡 Medium | Self-signed fine for now; defer with Item 56 |
| 37 | IRQ Affinity / CPU Isolation | 🟡 Medium | Risky without knowing CPU topology of all target hardware |
| 56 | Cockpit: Certificate Management | 🟡 Medium | Defer with Item 32 |

### Factory Reset / Provisioning Mode

**Not yet tracked as roadmap items. Adding now.**

#### FR-01 — Factory Reset Button in Cockpit
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

#### FR-02 — Provisioning Mode mDNS Advertisement  
**Importance:** 🟠 High  
**Difficulty:** Medium  
**Risk:** Low  
**Prerequisite:** FR-01  

In unconfigured state (no ), the node advertises:
-  (new service type, signals "ready to configure")
- Payload: MAC address, hardware type, current firmware version

inferno-central discovers this service type and lists the node as "awaiting provisioning". Operator can push a config remotely, node transitions to operational state and switches advertisement to .

This is the zero-touch deployment model for fleet management.

