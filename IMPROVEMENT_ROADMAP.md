# Inferno AoIP Appliance — Improvement Roadmap

> **Document type:** Engineering review and improvement backlog  
> **Scope:** Fedora bootc appliance (installer, first-boot, runtime, upgrade, build pipeline, operations)  
> **Total items:** 58 (1 bug fix + 57 improvements) — 13 resolved, 45 open  
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
| 1 | Install | Add Kickstart to BIB `config.toml` | 🟡 Medium | Easy (<2h) | Low | None |
| 8 | Hardware | NIC Carrier Check | 🔴 Critical | Easy (<2h) | Low | None |
| 26 | Security | Default Password Policy | 🔴 Critical | Easy (<2h) | Low | None |
| 31 | Security | SELinux: `restorecon` After Custom File Copies | 🔴 Critical | Easy (<2h) | Low | None |
| 33 | RT/Reliability | Hardware Watchdog | 🔴 Critical | Easy (<2h) | Low | None |
| 45 | Build | Clean Up `output-vN/` Directories After Build | 🔴 Critical | Easy (<2h) | Low | None |
| 2 | Install | Dynamic Disk Selection in Kickstart | ❌ Rejected | Easy (<2h) | Medium | Item 1 |
| 6 | Install | `multi-user.target` as Default | 🟠 High | Easy (<2h) | Low | None |
| 9 | Hardware | Multiple NIC Support / INFERNO_NIC_OVERRIDE | 🟠 High | Easy (<2h) | Low | Item 8 |
| 11 | Hardware | snd-aloop Index: Dynamic at First-Boot | 🟠 High | Easy (<2h) | Medium | None |
| 12 | Hardware | Hardware PTP Auto-Reporting | 🔴 Critical | Easy (<2h) | Low | Item 8 |
| 27 | Security | SSH: Disable Password Authentication | ❌ Rejected | Easy (<2h) | Medium | Item 26 |
| 28 | Security | Firewalld: Configure in the Containerfile | ❌ Rejected | Easy (<2h) | Low | None |
| 34 | RT/Reliability | Service Dependency: `ConditionPathExists=/etc/inferno.conf` | 🟠 High | Easy (<2h) | Low | None |
| 35 | RT/Reliability | journald Log Size Limit | 🟠 High | Easy (<2h) | Low | None |
| 36 | RT/Reliability | `LimitMEMLOCK=infinity` for RT Services | 🟠 High | Easy (<2h) | Low | None |
| 39 | RT/Reliability | Boot: Mask Unnecessary Fedora Services | 🟠 High | Easy (<2h) | Low | None |
| 40 | Build | Pin Base Image Digest | 🟠 High | Easy (<2h) | Low | None |
| 42 | Build | Reorder Containerfile Layers for Cache Efficiency | 🟠 High | Easy (<2h) | Low | None |
| 43 | Build | Pass `--build-arg VERSION=$VERSION` | 🟠 High | Easy (<2h) | Low | None |
| 47 | Operations | Cockpit: Surface Node Identity | ✅ Implemented | Easy (<2h) | Low | None |
| 48 | Operations | Health HTTP Endpoint | ✅ Implemented | Easy (<2h) | Low | None |
| 50 | Operations | Upgrade Audit Log with Rollback Events | ✅ Implemented | Easy (<2h) | Low | Item 17 |
| 51 | Operations | Cockpit: `bootc status` Panel | ✅ Implemented | Easy (<2h) | Low | None |
| 54 | Operations | Cockpit: Dante Device Status | ✅ Implemented | Easy (<2h) | Low | Item 47 |
| 7 | Install | Kickstart `%pre` Disk Detection Script | 🟠 High | Medium (half-day) | Medium | Item 1 |
| 15 | Upgrade | Version Sentinel Comparison in `inferno-configure.sh` | 🟠 High | Medium (half-day) | Medium | BUG-01 |
| 17 | Upgrade | Auto-Rollback on Failed Boot | ✅ Implemented | Medium (half-day) | Medium | BUG-01 |
| 23 | First-boot | `systemd-sysusers` and `tmpfiles.d` for User and Directory Setup | 🟠 High | Medium (half-day) | Medium | None |
| 57 | Security | Cockpit First-Login Password Prompt | 🟠 High | Medium (half-day) | Low | None |
| 38 | RT/Reliability | NIC Link-Down Recovery | 🟡 Medium | Medium (half-day) | Low | Items 8, 9 |
| 3 | Install | Boot Timeout = 3s | 🟡 Medium | Easy (<2h) | Low | Item 1 |
| 13 | Hardware | CPU Frequency Scaling: Performance Governor | 🟡 Medium | Easy (<2h) | Low | None |
| 14 | Hardware | `probe-node.sh` Output to `/var/log/inferno-probe.log` | 🟡 Medium | Easy (<2h) | Low | Items 8, 12 |
| 16 | Upgrade | Pre-Upgrade Version Check in `apply-update.sh` | ✅ Implemented | Easy (<2h) | Low | BUG-01 |
| 22 | First-boot | Butane YAML for Ignition | 🟡 Medium | Easy (<2h) | Low | None |
| 44 | Build | Generate `BUILD_DATE` and `GIT_SHA` Build-Args | 🟡 Medium | Easy (<2h) | Low | Item 43 |
| 46 | Build | Parallel ISO Branding + Tarball Export | 🟡 Medium | Easy (<2h) | Medium | None |
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
| 25 | First-boot | `INFERNO_NIC_OVERRIDE` in Ignition/Kickstart | 🟢 Low | Easy (<2h) | Low | Item 9 |
| 30 | Security | OCI Labels for Version Tracking | 🟢 Low | Easy (<2h) | Low | None |
| 4 | Install | GRUB / Boot Screen Branding via BIB | 🟢 Low | Medium (half-day) | Low | Item 1 |
| 41 | Build | Multi-Stage Containerfile | ❌ Rejected | Medium (half-day) | Low | None |
| 18 | Upgrade | Upload Resume / Chunked Upload | ✅ Implemented | Hard (multi-day) | Medium | BUG-01 |

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

---

---

## Install / One-Shot Provisioning

### Summary Table

| ID | Title | Importance | Difficulty | Risk | Prerequisites |
|---|---|---|---|---|---|
| 1 | Add Kickstart to BIB `config.toml` | 🟡 Medium | Easy | Low | None |
| 2 | Dynamic disk selection in Kickstart | ❌ Rejected | Easy | Medium | 1 |
| 3 | Boot timeout = 3s | 🟡 Medium | Easy | Low | 1 |
| 4 | GRUB / boot screen branding via BIB | 🟢 Low | Medium | Low | 1 |
| 5 | PXE / netboot image | ❌ Rejected | Hard | Medium | 1, 2 |
| 6 | `multi-user.target` as default | 🟠 High | Easy | Low | None |
| 7 | Kickstart `%pre` disk detection script | 🟠 High | Medium | Medium | 1 |

---

#### Item 1 — Add Kickstart to BIB `config.toml`

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

#### Item 2 — Dynamic Disk Selection in Kickstart

> **❌ REJECTED** — Superseded by Item 7 — Item 7 does the same thing properly via `%pre` detection.

**Importance:** ❌ Rejected
**Impact:** Makes the installer hardware-agnostic — works on SATA, NVMe, and virtio disks without modification
**Difficulty:** Easy
**Risk:** Medium
**Prerequisites:** 1

##### What is it?

Using `clearpart --all` and `autopart` without a `--drives=` constraint lets Anaconda select the install target automatically. Works regardless of whether the disk appears as `/dev/sda`, `/dev/nvme0n1`, `/dev/vda`.

##### Why implement?

Hardcoding `/dev/sda` is the #1 cause of kickstart failures when moving between hardware. An Inferno appliance might be deployed on a Proxmox VM (`/dev/vda`), a NUC with NVMe (`/dev/nvme0n1`), or a recycled PC with a SATA SSD (`/dev/sda`). The dynamic approach handles all of these with the same ISO.

##### Why NOT implement (or defer)?

`clearpart --all` is intentionally aggressive — it destroys all existing partitions on all disks. On a machine with multiple disks (e.g. a NAS with data drives), this will destroy everything. Use Item 7's `%pre` detection for multi-disk hardware.

##### Implementation notes

```
clearpart --all --initlabel --disklabel=gpt
autopart --type=plain
```

Do **not** add `--drives=sda`. Anaconda selects the first eligible disk.

---

#### Item 3 — Boot Timeout = 3s

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

#### Item 5 — PXE / Netboot Image

> **❌ REJECTED** — Infrastructure overhead not worth it for this deployment model.

**Importance:** ❌ Rejected
**Impact:** Enables zero-touch network install — no USB stick required; supports multi-node rollout
**Difficulty:** Hard
**Risk:** Medium
**Prerequisites:** 1, 2

##### What is it?

BIB supports `--type netboot` producing a PXE-bootable kernel/initrd/rootfs. Machines PXE boot from the network and install without physical media.

##### Why implement?

For deploying multiple Inferno nodes across a site, USB-stick-per-machine is painful. A PXE server on the LAN lets you provision any machine: power on, walk away, come back to a configured appliance.

##### Why NOT implement (or defer)?

Requires: DHCP server with PXE options configured (may need to touch site router), TFTP/HTTP server, machines with PXE boot enabled. Defer if deploying to a single node or if network infrastructure is not under your control.

##### Implementation notes

```bash
sudo podman run --rm --privileged \
  -v $(pwd)/build:/config -v $(pwd)/output:/output \
  quay.io/centos-bootc/bootc-image-builder:latest \
  --type netboot --config /config/config.toml \
  quay.io/yourorg/inferno-aoip:latest
```

The kickstart from Item 1 applies equally to netboot installs.

---

#### Item 6 — `multi-user.target` as Default

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

#### Item 8 — NIC Carrier Check

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

#### Item 9 — Multiple NIC Support / INFERNO_NIC_OVERRIDE

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

#### Item 10 — Predictable NIC Naming via udev (`inferno0`)

> **❌ REJECTED** — NICs managed by Cockpit; udev rename would interfere with NetworkManager and the Cockpit network UI.

**Importance:** ❌ Rejected  
**Impact:** Gives all scripts a stable, hardware-independent Dante NIC name  
**Difficulty:** Medium  
**Risk:** High  
**Prerequisites:** 8, 9  

##### What is it?

After first-boot NIC detection, a udev rule renames the selected Dante interface to `inferno0`. All subsequent scripts, config files, and systemd units reference `inferno0` rather than a hardware-specific name like `enp1s0` or `ens18`. The rename is persistent (udev rules survive reboots) and survives kernel updates, driver changes, and PCIe slot changes (provided the MAC is used as the match key).

A udev rule matching on MAC address is the most stable approach:

```
SUBSYSTEM=="net", ACTION=="add", ATTR{address}=="9c:8e:99:ee:fa:06", NAME="inferno0"
```

`inferno-configure.sh` would write this rule to `/etc/udev/rules.d/80-inferno-nic.rules` at first boot, then trigger a udev reload before the Dante services start.

##### Why implement?

Image-baked config templates currently embed `%%INFERNO_NIC%%` and substitute it at first boot. If the hardware is ever swapped (motherboard replaced, NIC order changes after a BIOS update), the stored `INFERNO_NIC` value in `/etc/inferno.conf` becomes stale. With `inferno0` as a stable alias, none of the runtime configs need to change — only the udev rule is rewritten at next reconfigure.

##### Why NOT implement (or defer)?

**Defer unless the complexity is justified.** The risks are non-trivial:

1. If the udev rule is written with the wrong MAC (e.g. after a hardware swap where the old MAC is in the rule but the new NIC has a different MAC), the rename silently fails and `inferno0` does not appear. This is harder to diagnose than a wrong `enp1s0` value.
2. On Fedora bootc, `/etc/udev/rules.d/` is mutable overlayfs — correct — but the rename only takes effect after a udev reload or reboot. The rule must be written *before* the network stack initializes, which means it must either be in the base image (impossible, since the MAC is node-specific) or written and then followed by a `udevadm control --reload && udevadm trigger` sequence that races with NetworkManager.
3. If a future version of the appliance supports multiple Dante streams (TX + RX on separate NICs), `inferno0`/`inferno1` naming requires a more complex matching strategy.

**Recommendation:** Implement items 8 and 9 first. Revisit `inferno0` renaming only if operators report friction with hardware-specific NIC names in production support scenarios.

##### Implementation notes

If proceeding, write the udev rule in `inferno-configure.sh` immediately after NIC and MAC detection:

```bash
cat > /etc/udev/rules.d/80-inferno-nic.rules <<EOF
# Written by inferno-configure.sh — do not edit manually.
# Renames the Dante NIC to inferno0 for stable identification.
SUBSYSTEM=="net", ACTION=="add", ATTR{address}=="${MAC}", NAME="inferno0"
EOF
udevadm control --reload-rules
# Note: the rename takes effect on next interface down/up or reboot.
# Reboot is already called at end of configure — no further action needed.
```

Change all `%%INFERNO_NIC%%` substitutions in templates to the literal `inferno0` once this is stable.

---

#### Item 11 — snd-aloop Index: Bump to 10

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

#### Item 12 — Hardware PTP Auto-Reporting

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

#### Item 14 — `probe-node.sh` Output to `/var/log/inferno-probe.log`

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

---

#### Item 22 — Butane YAML for Ignition

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

#### Item 24 — Eliminate the Reboot at End of `inferno-configure.sh`

> **⏸ DEFERRED** — Reboot is a safe catch-all; revisit once other firstboot changes are stable.

**Importance:** ⏸ Deferred  
**Impact:** First deployment completes 1–2 minutes faster; no unnecessary hardware POST cycle  
**Difficulty:** Medium  
**Risk:** Medium  
**Prerequisites:** Item 11  

##### What is it?

`inferno-configure.sh` ends unconditionally with `systemctl reboot` after a 5-second sleep. On a physical appliance (HP EliteDesk), POST + BIOS + bootloader + kernel init adds approximately 60–90 seconds to the first deployment. In a Proxmox VM it is faster but still 30–45 seconds. The reboot exists because:

1. **`snd-aloop` module index:** The loopback audio module is loaded at boot with whatever index the kernel assigned. `inferno-configure.sh` writes the definitive ALSA config (via template substitution) that references a specific card index. For the ALSA config to take effect, the module must be unloaded and reloaded — or the system rebooted.

2. **User service start-up:** Some systemd user services for `core` do not start cleanly when `inferno-configure.sh` enables them mid-session via `sudo -u core systemctl --user enable`. A full reboot ensures the user lingering session starts fresh with the correct environment.

The reboot is a pragmatic workaround, not a fundamental requirement.

##### Why implement?

A reboot-free first-boot configuration means:

- **Faster provisioning:** In automated deployment (Ansible, CI, Proxmox templating), the provisioning pipeline completes in one boot cycle. A 90-second reboot window at the end of `inferno-configure.sh` is dead time where the node is unreachable.
- **Cleaner service model:** Rebooting from within a systemd oneshot service is an antipattern. It makes the service logs discontinuous (pre-reboot logs are in one journal, post-reboot in another), and it means `inferno-configure.service` never reaches `ExecStart=` completion — it is always killed by the reboot. This breaks `systemctl is-active inferno-configure.service` checks in provisioning scripts.
- **Enables true idempotency:** A reboot-free configure script can be re-run safely (e.g., after deleting `/etc/inferno.conf`) without triggering a reboot — useful for re-applying config changes after NIC swaps.

##### Why NOT implement (or defer)?

The `snd-aloop` inline reload is the critical dependency. `rmmod snd_aloop` will fail if any process has the device open (even `aplay -l` holding a handle briefly). In a headless first-boot context this is generally safe — no user processes are running — but it requires `inferno-configure.sh` to run before any ALSA-using service starts. The current service ordering already achieves this, but it must be explicitly enforced with `Before=librespot.service inferno-bridge.service`.

The user service start-up problem is soluble with a polling loop (wait for `/run/user/<UID>/systemd/` to exist, then run `systemctl --user daemon-reload && systemctl --user start`), but this is fragile if the linger session takes more than ~10 seconds to initialize.

**This item is blocked on item 11 (dynamic `snd-aloop` index).** If item 11 is implemented, the module is loaded with the correct index from the start and does not need reloading — which eliminates the primary reason for the reboot. Without item 11, inline module reload is feasible but requires careful testing on hardware where `snd-aloop` may be loaded with index 0 or 1 depending on enumeration order.

**Recommendation: defer until item 11 is complete. Then implement.**

##### Implementation notes

With item 11 in place, the reboot is replaced by:

1. **Inline `snd-aloop` reload** (if item 11 is not yet done — manual approach):
   ```bash
   # Reload snd-aloop with the correct index from the freshly-written modprobe config
   # Safe only if no ALSA clients are running — guaranteed at first-boot configure time
   rmmod snd_aloop 2>/dev/null || true
   modprobe snd_aloop
   echo "snd-aloop reloaded with new index configuration"
   ```

2. **User service start without reboot:**
   ```bash
   CORE_UID=$(id -u core)
   # Wait for the linger session to be available
   for i in $(seq 1 30); do
       [ -S "/run/user/${CORE_UID}/systemd/private/notify" ] && break
       sleep 1
   done

   sudo -u core XDG_RUNTIME_DIR="/run/user/${CORE_UID}" \
       systemctl --user daemon-reload

   for svc in inferno-bridge inferno-keepalive librespot librespot-watchdog; do
       sudo -u core XDG_RUNTIME_DIR="/run/user/${CORE_UID}" \
           systemctl --user start "${svc}.service" \
           && echo "  started: ${svc}" \
           || echo "  WARNING: could not start ${svc}"
   done
   ```

3. **Replace the reboot** at the end of `inferno-configure.sh`:
   ```bash
   # Replace:
   # sleep 5
   # systemctl reboot

   # With:
   echo "=== Inferno AoIP configuration complete — no reboot required ==="
   ```

4. **Update `inferno-configure.service`** to declare ordering before ALSA-using services:
   ```ini
   [Unit]
   Before=librespot.service inferno-bridge.service inferno-keepalive.service
   After=systemd-tmpfiles-setup.service systemd-sysusers.service network-online.target
   ```

5. **Validate** by deploying to a test VM and confirming all four user services reach `active (running)` within 60 seconds of `inferno-configure.service` completing, without a reboot.

---

#### Item 25 — `INFERNO_NIC_OVERRIDE` in Ignition/Kickstart

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

## Security

### Summary Table

| ID | Title | Importance | Difficulty | Risk | Prerequisites |
|----|-------|-----------|------------|------|---------------|
| 26 | Default password policy | 🔴 Critical | Easy | Low | None |
| 27 | SSH: disable password authentication | ❌ Rejected | Easy | Medium | 26 |
| 28 | Firewalld: configure in Containerfile | ❌ Rejected | Easy | Low | None |
| 29 | Image signing with cosign/sigstore | ⏸ Deferred | Hard | Low | None |
| 30 | OCI labels for version tracking | 🟢 Low | Easy | Low | None |
| 31 | SELinux: `restorecon` after custom file copies | 🔴 Critical | Easy | Low | None |
| 32 | Cockpit TLS: custom certificate | ⏸ Deferred | Medium | Low | None |
| 57 | Cockpit: first-login password prompt | 🟠 High | Medium (half-day) | Low | None |

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

#### Item 27 — SSH: Disable Password Authentication

> **❌ REJECTED** — Superseded by Item 57 (Cockpit first-login password prompt), which achieves the same security goal without blocking SSH access for operators who haven't pre-provisioned keys.

**Importance:** ❌ Rejected  
**Impact:** Eliminates brute-force and credential-stuffing risk over SSH  
**Difficulty:** Easy  
**Risk:** Medium  
**Prerequisites:** 26  

##### What is it?

OpenSSH on Fedora ships with `PasswordAuthentication yes` by default. The Containerfile does not override this. Combined with the published `inferno123` password, SSH password auth represents a trivially exploitable entry point.

##### Why implement?

Even after item 26 (expiring the password), an attacker who intercepts the new password (or brute-forces a weak one) can log in. Disabling password auth entirely forces key-based authentication, which is not brute-forceable. This is standard hardening for any SSH-accessible server.

##### Why NOT implement (or defer)?

This is a breaking change for any deployment workflow that does not inject SSH keys before first boot. If a deployer `bootc switch`es to the new image and has not configured key-based auth on their client, they are locked out. This is why item 26 is listed as a prerequisite: key injection must be documented and working before password auth is removed.

Defer if the target deployment environment has no reliable mechanism to inject SSH keys (e.g., fully manual bare-metal installs without Ignition).

##### Implementation notes

1. Add to `Containerfile`:
   ```dockerfile
   RUN mkdir -p /etc/ssh/sshd_config.d && \
       printf 'PasswordAuthentication no\nChallengeResponseAuthentication no\n' \
       > /etc/ssh/sshd_config.d/99-inferno.conf
   ```
2. Verify sshd loads the drop-in: `sshd -T | grep passwordauthentication` should return `no`.
3. Update `DEPLOY.md` with a prerequisite: "You must have SSH key-based access configured before applying an image with this change."
4. Consider shipping a `test-ssh-key-access.sh` helper that verifies key auth works before locking out password auth, to reduce lockout risk during upgrades.

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

#### Item 28 — Firewalld: Configure in the Containerfile

> **❌ REJECTED** — Maintenance burden outweighs benefit; Fedora default zone is sufficient for this deployment model.

**Importance:** ❌ Rejected  
**Impact:** Enforces a minimal-exposure port policy on every deployed node from day one  
**Difficulty:** Easy  
**Risk:** Low  
**Prerequisites:** None  

##### What is it?

The Containerfile installs `firewalld` but never configures it. The post-install state is firewalld's default `public` zone with broad defaults — all ports used by Dante, Inferno, mDNS, Cockpit, and SSH are effectively wide open with no explicit policy. The osbuild blueprint documents the correct ports, but that blueprint is not used in the current container-based build pipeline.

##### Why implement?

Firewall configuration should be part of the image, not a post-install step. An appliance should arrive configured. Any node that is deployed and then not manually hardened (which is most of them) runs with an unconfigured firewall. Baking the policy into the Containerfile guarantees consistent, auditable network exposure across all nodes.

This is especially important because firewalld's default zone allows outbound connections but also accepts inbound connections on several services. Restricting to exactly the ports the appliance needs closes the gap.

##### Why NOT implement (or defer)?

Risk of accidentally blocking a required port during development/testing — if a port is missed in the list, audio or Dante will silently break. Test thoroughly in a VM before deploying to the production node. This is low-risk if the port list is taken directly from the documented Dante/Inferno requirements.

##### Implementation notes

Add to `Containerfile` after the `firewalld` install:

```dockerfile
RUN firewall-offline-cmd --set-default-zone=home \
 && firewall-offline-cmd --add-port=22/tcp \
 && firewall-offline-cmd --add-port=9090/tcp \
 && firewall-offline-cmd --add-port=4455/udp \
 && firewall-offline-cmd --add-port=8700/udp \
 && firewall-offline-cmd --add-port=4400/udp \
 && firewall-offline-cmd --add-port=8800/udp \
 && firewall-offline-cmd --add-port=5353/udp \
 && firewall-offline-cmd --add-port=6000-6011/udp \
 && firewall-offline-cmd --remove-service=dhcpv6-client \
 && firewall-offline-cmd --remove-service=mdns \
 && firewall-offline-cmd --remove-service=samba-client
```

Use `home` zone (vs. `public`) as it is the most appropriate predefined zone for a trusted LAN device — it allows mDNS and disables several services that `public` would allow by default. The explicit `--add-port=5353/udp` replaces the removed `mdns` service entry for clarity.

Verify after build:
```bash
firewall-cmd --list-all --zone=home
```

---

#### Item 29 — Image Signing with cosign/sigstore

> **⏸ DEFERRED** — Closed deployment, low tamper risk; revisit when security posture requires it.

**Importance:** ⏸ Deferred  
**Impact:** Prevents tampered or malicious images from being applied via `bootc switch` or the Cockpit update UI  
**Difficulty:** Hard  
**Risk:** Low  
**Prerequisites:** None  

##### What is it?

The built container image is currently unsigned. Anyone who can push an OCI image to the registry — or upload a `.iotupdate` tar via the Cockpit web UI — can replace the running OS with arbitrary content. `bootc` supports signature verification via `policy.json`, but this is not configured.

##### Why implement?

Supply chain integrity is a real concern even on a private LAN, particularly because the image is built on a separate machine (the build VM) and transferred to nodes via an OCI registry or HTTP endpoint. A compromised build VM, a man-in-the-middle on the LAN, or a malicious `.iotupdate` bundle uploaded through Cockpit by an unauthorized LAN user could silently replace the OS.

Signing the image at build time and enforcing verification at apply time closes this gap with minimal operational overhead once the key management workflow is established.

##### Why NOT implement (or defer)?

This is the most operationally complex item in the security section. It requires:
- `cosign` installed on the build VM
- A signing key generated and stored securely (not in the repo)
- `policy.json` deployed to every node before the first signed image is applied
- Key rotation procedures documented

For a single-node home-lab appliance, this overhead may exceed the threat. Defer unless the deployment involves multiple nodes, a shared registry, or the Cockpit update UI is exposed to more than one administrator. Implement items 26–28 first.

##### Implementation notes

1. Install `cosign` on the build VM:
   ```bash
   curl -Lo cosign https://github.com/sigstore/cosign/releases/latest/download/cosign-linux-amd64
   chmod +x cosign && sudo mv cosign /usr/local/bin/
   ```
2. Generate a key pair (store `cosign.key` out of the repo, commit only `cosign.pub`):
   ```bash
   cosign generate-key-pair
   ```
3. In `build-release.sh`, after `podman build`, add:
   ```bash
   cosign sign --key cosign.key "$IMAGE_REF"
   ```
4. On each node, configure `/etc/containers/policy.json` to require signature verification for the image registry domain. Template:
   ```json
   {
     "default": [{"type": "reject"}],
     "transports": {
       "docker": {
         "192.168.1.x:5000": [{
           "type": "signedBy",
           "keyType": "GPGKeys",
           "keyPath": "/etc/containers/inferno-signing.pub"
         }]
       }
     }
   }
   ```
   (Use cosign's sigstore format if not using GPG — refer to `containers-policy.json(5)` for the `sigstoreSigned` type.)
5. Deploy `cosign.pub` to `/etc/containers/inferno-signing.pub` on nodes via Ignition or the Ansible playbook.

---

#### Item 30 — OCI Labels for Version Tracking

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

#### Item 32 — Cockpit TLS: Custom Certificate

> **⏸ DEFERRED** — Self-signed is fine for now; revisit together with Item 56 (Cockpit certificate management UI).

**Importance:** ⏸ Deferred  
**Impact:** Eliminates the browser security warning on every Cockpit session  
**Difficulty:** Medium  
**Risk:** Low  
**Prerequisites:** None  

##### What is it?

Cockpit uses a self-signed certificate by default, stored in `/etc/cockpit/ws-certs.d/`. Every browser that connects to `https://<node-ip>:9090` receives an untrusted certificate warning and must click through a security exception. On a private LAN this is purely a UX problem, not a meaningful security risk — but it trains users to click through certificate warnings, which is a bad habit.

##### Why implement?

The warning is avoidable with a one-time LAN CA setup and is worth eliminating if this appliance is used regularly. A trusted certificate also makes Cockpit usable from browsers with strict security policies (e.g., corporate Chromium builds that block self-signed certs entirely).

**Recommended approach: LAN CA + pre-shared wildcard cert baked into the image.**

Generate a LAN CA and a wildcard cert for `*.inferno.local` (or whatever the LAN domain is). Bake the signed cert and key into the image at `/etc/cockpit/ws-certs.d/inferno.cert` and `/etc/cockpit/ws-certs.d/inferno.key`. Distribute the LAN CA certificate to browsers as a one-time trust anchor. This requires a new image build on cert expiry (typically 1–2 years), which aligns with the appliance's update cadence.

##### Why NOT implement (or defer)?

Acceptable to defer indefinitely on a single-node home-lab deployment where the administrator is the only Cockpit user and is comfortable clicking through the warning. Do not implement the ACME/DNS-01 approach — it requires LAN DNS infrastructure that the appliance cannot assume exists and adds ongoing operational complexity that outweighs the benefit.

Do not bake a private key into a public GitHub repository. If the cert is baked into the image, the private key must be generated per-deployment (not checked in), or the repo must be private.

##### Implementation notes

**Option A — LAN CA (recommended):**
1. On the admin workstation, generate a LAN CA:
   ```bash
   openssl genrsa -out lan-ca.key 4096
   openssl req -x509 -new -nodes -key lan-ca.key -sha256 -days 3650 \
     -subj "/CN=Inferno LAN CA" -out lan-ca.crt
   ```
2. Generate the node cert (use the node's hostname or a wildcard):
   ```bash
   openssl genrsa -out inferno.key 2048
   openssl req -new -key inferno.key \
     -subj "/CN=inferno.local" -out inferno.csr
   openssl x509 -req -in inferno.csr -CA lan-ca.crt -CAkey lan-ca.key \
     -CAcreateserial -out inferno.crt -days 730 -sha256 \
     -extfile <(printf 'subjectAltName=DNS:inferno.local,IP:192.168.1.25')
   ```
3. Add to `Containerfile` (cert and key injected via build secret or baked from a `secrets/` directory that is `.gitignore`d):
   ```dockerfile
   RUN mkdir -p /etc/cockpit/ws-certs.d
   COPY secrets/inferno.crt /etc/cockpit/ws-certs.d/inferno.cert
   COPY secrets/inferno.key /etc/cockpit/ws-certs.d/inferno.key
   RUN chmod 640 /etc/cockpit/ws-certs.d/inferno.key \
    && chown root:cockpit-ws /etc/cockpit/ws-certs.d/inferno.key
   ```
4. Import `lan-ca.crt` into each browser/OS trust store as a one-time step. On most OSes, double-clicking the `.crt` file and marking it as trusted is sufficient.

**Option B — Pre-baked self-signed with longer validity (minimal improvement):**
If LAN CA setup is too complex, at minimum regenerate the self-signed cert with a 10-year validity and a correct `subjectAltName` matching the node's fixed IP. This eliminates the "invalid host" warning while leaving the "untrusted CA" warning. Not recommended over Option A.

---

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

#### Item 33 — Hardware Watchdog

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

#### Item 34 — Service Dependency: `ConditionPathExists=/etc/inferno.conf`

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

#### Item 36 — `LimitMEMLOCK=infinity` for RT Services

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

#### Item 37 — IRQ Affinity / CPU Isolation

> **⏸ DEFERRED** — Risky without knowing the CPU topology of all target hardware; `isolcpus` assumptions could degrade performance on unknown core counts. Revisit with measured jitter data.

**Importance:** ⏸ Deferred  
**Impact:** PTP timestamp jitter drops from ~200µs to ~50µs; Dante clock stability improves proportionally  
**Difficulty:** Hard (multi-day)  
**Risk:** Medium  
**Prerequisites:** None  

##### What is it?

PTP accuracy depends on how consistently the system can timestamp incoming Ethernet frames. The NIC interrupt handler must run, be serviced, and return a timestamp before any other CPU activity perturbs the timing. On a general-purpose kernel, the CPU running the NIC IRQ is also running the scheduler, handling RCU callbacks, processing timer ticks, and running any workload that happens to be scheduled there. The resulting jitter is 100–300µs for a software PTP implementation like Statime.

CPU isolation removes a CPU core (e.g., CPU 1) from the general scheduler pool. Kernel boot arguments:

```
isolcpus=1 nohz_full=1 rcu_nocbs=1
```

These prevent the scheduler, tick timer, and RCU callbacks from running on CPU 1. The NIC IRQ is then manually pinned to CPU 1 via:

```bash
# Find IRQ number for your NIC:
grep $(basename $(readlink /sys/class/net/enp1s0/device/driver/../)) /proc/interrupts | awk '{print $1}' | tr -d ':'
# Pin it:
echo 2 > /proc/irq/<IRQ>/smp_affinity  # bitmask: CPU 1
```

This can reduce PTP jitter from ~200µs to ~50µs on typical x86 hardware, bringing Dante clock sync within specification for the MXWANI8.

##### Why implement?

If you are experiencing Dante audio sync issues, late-arriving packets, or PTP grandmaster loss events, this is the correct diagnosis path. Sub-100µs PTP jitter is the threshold for stable Dante operation. Statime's software timestamping is already at a disadvantage compared to hardware timestamping NICs (item HW-PTP) — CPU isolation is the software mitigation that partially compensates.

##### Why NOT implement (or defer)?

**Defer until you have a measured jitter problem.** CPU isolation has real costs:

1. **Fixed topology assumption.** The isolated CPU must be specified at image build time. A 2-core node loses 50% of its compute. A 4-core node loses 25%. This is fine for a dedicated appliance, but requires knowing the target hardware's CPU count at image build time. Do not hardcode `isolcpus=1` in a generic image deployed across heterogeneous hardware.
2. **irqbalance conflict.** `irqbalance` will fight with manual IRQ pinning. It must be masked on nodes using this configuration.
3. **Debugging complexity.** A CPU that appears idle but is actually reserved is confusing to operators unfamiliar with isolation.

Implement hardware PTP (item HW-PTP) first if the hardware supports it — it delivers better jitter reduction with no CPU topology dependency.

##### Implementation notes

Add to the bootc kargs TOML file (already used for `preempt=full threadirqs`):

```toml
# /usr/lib/bootc/kargs.d/99-rt.toml
[kargs]
add = ["preempt=full", "threadirqs", "isolcpus=1", "nohz_full=1", "rcu_nocbs=1"]
```

Add a oneshot systemd service to pin IRQs after boot:

```bash
#!/usr/bin/bash
# /usr/local/bin/set-irq-affinity.sh
NIC="${INFERNO_NIC:-enp1s0}"
IRQ=$(grep -l "${NIC}" /proc/irq/*/node 2>/dev/null | head -1 | grep -o '[0-9]*')
if [[ -n "${IRQ}" ]]; then
    echo 2 > /proc/irq/${IRQ}/smp_affinity  # CPU 1 bitmask
    echo "[irq-affinity] Pinned NIC IRQ ${IRQ} to CPU 1"
fi
# Also pin Statime thread if using threaded IRQs:
# tuna --irqs=<IRQ> --cpus=1 --move  (if tuna is installed)
```

Mask `irqbalance.service` in the `Containerfile`:

```dockerfile
RUN systemctl mask irqbalance.service
```

Validate after boot with `cyclictest` (from `rt-tests` package):

```bash
cyclictest --mlockall --smp --priority=80 --interval=200 --distance=0 --duration=60 -q
```

Target: max latency < 200µs. If seeing > 500µs consistently, isolation is not effective and hardware PTP should be prioritised instead.

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

#### Item 39 — Boot: Mask Unnecessary Fedora Services

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

#### Item 41 — Multi-Stage Containerfile

> **❌ REJECTED** — Existing cleanup is sufficient; low gain for bootc images. Maintenance burden of multi-stage builds outweighs benefit.

**Importance:** ❌ Rejected  
**Impact:** Build tools and branding asset generators are excluded from the final runtime image  
**Difficulty:** Medium (half-day)  
**Risk:** Low  
**Prerequisites:** None  

##### What is it?

Docker/Podman multi-stage builds allow a single Containerfile to define multiple `FROM` stages. Artifacts (files, binaries, rendered assets) are `COPY --from=<stage>` into the final image. Build tools that were needed to produce those artifacts never appear in the shipped image.

For the Inferno Containerfile, the primary candidate is branding asset rendering: if the `branding` submodule uses Python/Pillow or similar to render images at build time, those tools (and their transitive dependencies) are currently installed in — and shipped with — the final bootc image.

A two-stage Containerfile would look like:

```dockerfile
# Stage 1: branding asset renderer
FROM registry.fedoraproject.org/fedora:43 AS branding-builder
RUN dnf install -y python3-pillow python3-pip
COPY branding/ /build/branding/
RUN python3 /build/branding/render.py --out /build/assets/

# Stage 2: runtime image
FROM registry.fedoraproject.org/fedora-bootc:43@sha256:<digest>
COPY --from=branding-builder /build/assets/ /usr/share/inferno/branding/
# ... rest of Containerfile
```

##### Why implement?

Smaller images: fewer packages means a smaller attack surface, faster `podman save` export times, and less storage consumed per release in `releases/`. Separation also makes the Containerfile easier to reason about — build concerns are isolated from runtime concerns.

##### Why NOT implement (or defer)?

**Defer unless image size or build-tool presence is a demonstrable problem.** The Inferno image is a bootc image, not a microservice container — it boots a full OS and is expected to be large. The marginal size reduction from excluding Python/Pillow is unlikely to matter in practice.

More importantly, multi-stage builds add Containerfile complexity that can confuse future maintainers. The `COPY --from` syntax, stage naming, and caching behaviour across stages are non-obvious. For a team that currently maintains a linear 35-step Containerfile, introducing stages is a maintenance cost that must be justified by a concrete benefit.

**Recommendation:** Implement only if the branding submodule's build tools are large (>200 MB installed), or if a security audit flags them as unwanted in the runtime image. Otherwise defer indefinitely.

##### Implementation notes

1. Audit what the `branding` submodule installs at build time:
   ```bash
   grep -i "dnf\|pip\|python" Containerfile
   ```
2. If build-only tools exist, extract them into a named `AS branding-builder` stage using `fedora:43` (not `fedora-bootc:43`) as the base — standard Fedora is smaller and sufficient for asset generation.
3. Replace inline branding `RUN` steps with `COPY --from=branding-builder`.
4. Verify final image size with `podman image inspect localhost/inferno-appliance:vN --format '{{.Size}}'` before and after.

---

#### Item 42 — Reorder Containerfile Layers for Cache Efficiency

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

#### Item 43 — Pass `--build-arg VERSION=$VERSION`

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

#### Item 44 — Generate `BUILD_DATE` and `GIT_SHA` Build-Args

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

#### Item 45 — Clean Up `output-vN/` Directories After Build

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

#### Item 46 — Parallel ISO Branding + Tarball Export

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

#### Item 49 — mDNS Alias `inferno.local`

> **❌ REJECTED** — Dante is inherently multi-node; a static `inferno.local` alias would cause mDNS conflicts when multiple Inferno appliances are on the same LAN.

**Importance:** ❌ Rejected  
**Impact:** Provides a stable, bookmark-able hostname — no MAC lookup required  
**Difficulty:** Easy (<2h)  
**Risk:** Medium  
**Prerequisites:** None  

##### What is it?

Avahi currently publishes `inferno-<last6mac>.local` (e.g., `inferno-eefa06.local`). This item conditionally publishes a second alias, `inferno.local`, as an Avahi CNAME record. The alias is only activated when `PUBLISH_STABLE_ALIAS=yes` is set in `/etc/inferno.conf`.

This makes `https://inferno.local:9090` a working browser bookmark and `ssh inferno.local` a working SSH target — without any DNS server configuration.

##### Why implement?

The current MAC-derived hostname requires the operator to look up the MAC from DHCP leases (or the Fortigate dashboard) before they can reach the appliance in a browser. For a single-appliance deployment (the common case), this friction adds nothing. `inferno.local` is the right ergonomic default.

##### Why NOT implement (or defer)?

**The alias conflicts if two Inferno appliances are on the same LAN.** Both will respond to `inferno.local`, causing mDNS split-brain. The `PUBLISH_STABLE_ALIAS` guard mitigates this operationally (require operators to explicitly opt in), but a misconfigured fleet will be confusing to debug.

Defer for multi-appliance LAN environments. For single-appliance studio installs (the primary use case), implement immediately.

##### Implementation notes

1. Read the flag in `inferno-configure.sh` (or a dedicated Avahi config script):
   ```bash
   source /etc/inferno.conf
   if [ "${PUBLISH_STABLE_ALIAS:-no}" = "yes" ]; then
       cat > /etc/avahi/services/inferno-alias.service << EOF
   <?xml version="1.0" standalone='no'?>
   <!DOCTYPE service-group SYSTEM "avahi-service.dtd">
   <service-group>
     <name replace-wildcards="no">inferno</name>
     <service>
       <type>_device-info._tcp</type>
       <port>0</port>
       <txt-record>model=InfernoAoIP</txt-record>
     </service>
   </service-group>
   EOF
   fi
   ```

2. For the CNAME specifically, Avahi does not natively publish DNS CNAME records for `.local`. Instead, use Avahi's host-name aliasing via the `avahi-alias` script, or publish a second `<host-name>` by writing a second Avahi daemon config:
   ```bash
   # /etc/avahi/avahi-daemon.conf (append to [server] section)
   # This makes the host respond to inferno.local in addition to its
   # machine hostname, but requires host-name to be set to "inferno"
   # — which conflicts with the MAC-derived name if both are needed.
   ```
   
   **Recommended approach:** Use `avahi-publish-address` as a oneshot systemd service:
   ```ini
   [Unit]
   Description=Publish inferno.local mDNS alias
   After=avahi-daemon.service
   ConditionPathExists=/etc/inferno.conf

   [Service]
   Type=simple
   EnvironmentFile=/etc/inferno.conf
   ExecStartPre=/bin/sh -c 'test "${PUBLISH_STABLE_ALIAS}" = "yes"'
   ExecStart=/usr/bin/avahi-publish-address -R inferno.local %I
   Restart=on-failure
   ```
   Where `%I` is the node's primary IP (resolved at start time via `ip -4 addr show ${INFERNO_NIC}`).

3. Add `PUBLISH_STABLE_ALIAS=no` to the default `/etc/inferno.conf` template. Document in `DEPLOYMENT.md`: "Set `PUBLISH_STABLE_ALIAS=yes` only if this is the only Inferno appliance on the LAN."

---

#### Item 56 — Cockpit: Certificate Management

> **⏸ DEFERRED** — Deferred together with Item 32 (Cockpit TLS custom certificate). Implement both together when TLS certificate management is prioritised.

**Importance:** ⏸ Deferred  
**Impact:** Eliminates browser TLS warnings without requiring SSH or scp  
**Difficulty:** Medium (half-day)  
**Risk:** Medium  
**Prerequisites:** None  

##### What is it?

A "TLS Certificate" section in the Cockpit Inferno page that allows an operator to upload a custom TLS certificate for Cockpit. Cockpit automatically uses certificates placed in `/etc/cockpit/ws-certs.d/` — a custom cert placed there (full chain + key, or as a combined `.cert` file) replaces the self-signed default.

The workflow:
1. Operator uploads a `.pem` or `.cert` file (full chain + private key) via a file input in Cockpit
2. The Python sidecar validates the certificate (checks expiry, key/cert match) before writing it
3. Sidecar writes the cert to `/etc/cockpit/ws-certs.d/10-inferno.cert`
4. Sidecar restarts `cockpit.socket` to pick up the new cert
5. Cockpit reconnects automatically (Cockpit JS handles the disconnect/reconnect)

##### Why implement?

The self-signed cert generates browser security warnings on every visit. For a studio or broadcast environment where Cockpit is the primary management UI, this is a constant friction point and erodes trust in the interface. Providing a cert upload path in the UI itself gives operators a practical route to fix it — many operators have access to wildcard or local CA certs but not the confidence to `scp` files to a Linux server.

The Cockpit restart (via `systemctl restart cockpit.socket`) is the most disruptive part: the operator's browser session drops and reconnects. Cockpit handles this gracefully with its built-in reconnection logic.

##### Why NOT implement (or defer)?

The risk is that an invalid or mismatched cert (cert/key mismatch, expired cert, wrong format) will break Cockpit access entirely. Recovery requires SSH. The mitigation is pre-write validation in the sidecar:

```python
# Run openssl verify before writing
subprocess.run(["openssl", "verify", "-CAfile", cert_path], check=True)
# Check key matches cert
subprocess.run(["openssl", "x509", "-noout", "-modulus", "-in", cert_path], check=True)
subprocess.run(["openssl", "pkey", "-noout", "-modulus", "-in", key_path], check=True)
```

If validation fails, reject the upload with a clear error message and do not write the file. This makes the worst case "upload failed, cert not changed" rather than "Cockpit is now inaccessible."

Defer if Let's Encrypt / ACME integration (a separate, larger item) is planned — don't build a manual upload UI if automated cert renewal is 6 weeks away.

##### Implementation notes

1. In `sidecar/server.py`:
   ```python
   import ssl, tempfile, os, subprocess, shutil

   COCKPIT_CERT_DIR  = "/etc/cockpit/ws-certs.d"
   COCKPIT_CERT_PATH = os.path.join(COCKPIT_CERT_DIR, "10-inferno.cert")

   @app.route("/certificate", methods=["POST"])
   def upload_certificate():
       if "cert" not in request.files:
           return jsonify({"error": "No cert file provided"}), 400

       cert_file = request.files["cert"]
       cert_data = cert_file.read()

       # Write to a staging path for validation
       staging_path = "/etc/cockpit/ws-certs.d/10-inferno.cert.staging"
       with open(staging_path, "wb") as f:
           f.write(cert_data)

       # Validate: parse the cert
       try:
           result = subprocess.run(
               ["openssl", "x509", "-noout", "-text", "-in", staging_path],
               capture_output=True, text=True, check=True
           )
           # Check it's not expired
           subprocess.run(
               ["openssl", "x509", "-noout", "-checkend", "0", "-in", staging_path],
               check=True
           )
       except subprocess.CalledProcessError as e:
           os.unlink(staging_path)
           return jsonify({"error": f"Certificate validation failed: {e.stderr}"}), 400

       # Commit
       os.replace(staging_path, COCKPIT_CERT_PATH)
       os.chmod(COCKPIT_CERT_PATH, 0o640)

       # Restart cockpit.socket — session will reconnect automatically
       subprocess.Popen(["systemctl", "restart", "cockpit.socket"])
       return jsonify({"status": "ok", "message": "Certificate installed. Reconnecting..."})
   ```

2. The Cockpit JS certificate upload section should:
   - Show the current cert's CN and expiry date (fetched from a `GET /certificate` endpoint)
   - Accept a combined PEM file (cert chain + key concatenated) as the simplest format to support
   - Display a warning: **"Cockpit will restart. Your browser will reconnect automatically in ~10 seconds."**
   - After POST returns, show the reconnect countdown and poll for Cockpit availability

3. For split cert/key upload (separate files), accept two file inputs and concatenate server-side before writing — this matches Cockpit's documented format for `/etc/cockpit/ws-certs.d/*.cert`.

4. Add a `GET /certificate` endpoint that returns the current cert's subject CN and `notAfter` date (parsed via `openssl x509 -noout -subject -enddate`), or `{"installed": false}` if only the default self-signed cert is present.
