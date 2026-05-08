# Inferno Bind Reconciliation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make Inferno appliances canonicalize Dante bind identity to NIC names and self-repair bind, clock, and PTP access after upgrade, reboot, and subnet changes.

**Architecture:** `/etc/inferno.conf` is the source of truth. `inferno-upgrade.sh` reconciles live NIC/IP/PTP state at boot and regenerates managed ALSA sections with `BIND_IP=${INFERNO_NIC}`. Cockpit generation stops reading stale `BIND_IP` from `.asoundrc`.

**Tech Stack:** Bash, systemd, udev, ALSA config templates, Cockpit JavaScript, shell regression tests.

---

### Task 1: Upgrade Reconciler Behavior Tests

**Files:**
- Modify: `tests/regression.sh`

- [ ] **Step 1: Add fixture helpers for fake NIC/IP state**

Extend the existing `run_upgrade_fixture()` area with helper files under `$tmpdir`:

```bash
# Fixtures should be able to supply:
# - INFERNO_CONF pointing at fake inferno.conf
# - INFERNO_CORE_HOME pointing at fake core home
# - INFERNO_SYS_CLASS_NET pointing at fake sysfs net root
# - INFERNO_DEV_ROOT pointing at fake dev root
# - INFERNO_IP_FIXTURE pointing at a text file mapping NIC names to IPv4/default-route state
```

- [ ] **Step 2: Add stale IP regression**

Add a fixture equivalent to `172.16.10.63`:

```bash
INFERNO_NIC=enp0s31f6
INFERNO_INTERFACE=192.168.1.45
INFERNO_HW_PTP=yes
```

Fake current state has `enp0s31f6 172.16.10.63 default`, fake PTP has `ptp0`, and `.asoundrc` contains `BIND_IP 192.168.1.45`. Expected after upgrade:

```text
INFERNO_BIND=enp0s31f6
INFERNO_INTERFACE=172.16.10.63
INFERNO_HW_PTP=yes
INFERNO_CLOCK_PATH=/dev/ptp0
BIND_IP enp0s31f6
```

- [ ] **Step 3: Add no-HW-PTP regression**

Add a fixture equivalent to `172.16.10.64`: saved `INFERNO_HW_PTP=yes`, no fake PTP device, `.asoundrc` contains `CLOCK_PATH /dev/ptp0` or stale hardware clock. Expected:

```text
INFERNO_HW_PTP=no
INFERNO_CLOCK_PATH=/tmp/ptp-usrvclock
CLOCK_PATH /tmp/ptp-usrvclock
```

- [ ] **Step 4: Add missing NIC/default-route fallback regression**

Saved `INFERNO_NIC=eno1` does not exist. Fake route marks `enp0s31f6` as default. Expected `INFERNO_NIC=enp0s31f6` and `INFERNO_BIND=enp0s31f6`.

- [ ] **Step 5: Add ambiguous NIC regression**

Saved NIC missing and two viable fake NICs exist with no default-route marker. Expected script exits nonzero or logs a loud failure and leaves conf unchanged.

- [ ] **Step 6: Add boot-before-DHCP regression**

Selected NIC exists but fake current IPv4 is empty. Expected prior `INFERNO_INTERFACE` is preserved and not rewritten to empty or `0.0.0.0`.

- [ ] **Step 7: Run tests and capture RED**

Run:

```bash
bash tests/regression.sh
```

Expected: fails on the first newly-added stale IP canonicalization assertion.

### Task 2: Implement Upgrade Reconciler

**Files:**
- Modify: `templates/scripts/inferno-upgrade.sh`
- Modify: `templates/systemd/system/inferno-upgrade.service`

- [ ] **Step 1: Add NIC/IP helper functions**

Implement helpers inside `inferno-upgrade.sh`:

```bash
nic_exists() { [ -d "${SYS_CLASS_NET}/$1" ]; }
is_excluded_nic() { case "$1" in lo|docker*|br-*|veth*|virbr*|tap*|tun*) return 0;; esac; [ -d "${SYS_CLASS_NET}/$1/wireless" ]; }
current_ipv4_for_nic() { ... }
default_route_nic() { ... }
detect_fallback_nic() { ... }
detect_ptp_clock_path() { ... }
```

Use `INFERNO_IP_FIXTURE` in tests before shelling out to `ip`.

- [ ] **Step 2: Canonicalize config values**

After sourcing conf, set:

```bash
INFERNO_NIC=<validated or detected NIC>
INFERNO_BIND="${INFERNO_NIC}"
INFERNO_INTERFACE=<current IPv4, preserving previous non-empty value if DHCP not ready>
INFERNO_HW_PTP=yes/no
INFERNO_CLOCK_PATH=/dev/ptpN or /tmp/ptp-usrvclock
```

- [ ] **Step 3: Preserve unknown conf keys**

Write an update helper that replaces or appends only known Inferno keys and keeps unrelated lines. Known keys for this task:

```text
INFERNO_NIC
INFERNO_INTERFACE
INFERNO_BIND
INFERNO_HW_PTP
INFERNO_CLOCK_PATH
```

- [ ] **Step 4: Regenerate managed ALSA bind/clock values**

For this release, minimally rewrite every non-comment managed Inferno `BIND_IP` and `CLOCK_PATH` line inside `.asoundrc` to canonical values. Avoid changing commented lines. Keep existing device IDs and non-Inferno PCMs intact.

- [ ] **Step 5: Make service ordering explicit**

Update `templates/systemd/system/inferno-upgrade.service` to run after network is online:

```ini
Wants=network-online.target
After=network-online.target inferno-configure.service
```

Keep `Before=user@1000.service`.

- [ ] **Step 6: Run tests and capture GREEN**

Run:

```bash
bash -n templates/scripts/inferno-upgrade.sh tests/regression.sh
bash tests/regression.sh
```

Expected: syntax passes and regression prints `All regression checks passed.`

### Task 3: Cockpit Bind Generation

**Files:**
- Modify: `src/inferno.js`
- Modify: `tests/regression.sh`

- [ ] **Step 1: Add JS stale bind RED test**

Extend the existing Node harness so seeded `.asoundrc` contains `BIND_IP 192.168.1.45` while `currentConf.INFERNO_NIC` and `INFERNO_BIND` are `enp0s31f6`. Assert generated iradio blocks and AUX blocks use `BIND_IP enp0s31f6` and do not contain `192.168.1.45`.

- [ ] **Step 2: Run RED**

Run:

```bash
bash tests/regression.sh
```

Expected: fails because current JS preserves stale nonzero `BIND_IP`.

- [ ] **Step 3: Change `infernoBindValue()`**

Update `src/inferno.js` so `infernoBindValue()` returns only `currentConf.INFERNO_BIND || currentConf.INFERNO_NIC` and throws or returns an explicit invalid marker if both are absent. Do not use `INFERNO_INTERFACE`.

- [ ] **Step 4: Stop reading stale BIND_IP in generators**

Update `ensureIradioSetup()` and `ensureAuxSetup()` to use `infernoBindValue()` directly instead of preserving `bindIpMatch` from `.asoundrc`.

- [ ] **Step 5: Run GREEN**

Run:

```bash
bash tests/regression.sh
```

Expected: regression prints `All regression checks passed.`

### Task 4: PTP Access Image and Upgrade Support

**Files:**
- Create: `templates/udev/90-inferno-ptp.rules`
- Modify: `Containerfile`
- Modify: `templates/scripts/inferno-upgrade.sh`
- Modify: `tests/regression.sh`

- [ ] **Step 1: Add udev rule test**

Add regression assertions that `templates/udev/90-inferno-ptp.rules` exists and contains:

```text
KERNEL=="ptp[0-9]*", GROUP="clock", MODE="0660"
```

Assert it does not contain `uaccess` or `MODE="0666"`.

- [ ] **Step 2: Run RED**

Run:

```bash
bash tests/regression.sh
```

Expected: fails because the udev rule file does not exist.

- [ ] **Step 3: Add udev rule and image install**

Create `templates/udev/90-inferno-ptp.rules` with the rule from Step 1. Update `Containerfile` to copy it into `/etc/udev/rules.d/90-inferno-ptp.rules`.

- [ ] **Step 4: Add upgrade-time group and udev refresh**

In `inferno-upgrade.sh`, idempotently run:

```bash
usermod -aG clock core || true
udevadm control --reload || true
udevadm trigger --subsystem-match=ptp || true
```

Skip these commands when `INFERNO_SKIP_OWNERSHIP=1` in tests.

- [ ] **Step 5: Run GREEN**

Run:

```bash
bash tests/regression.sh
```

Expected: regression prints `All regression checks passed.`

### Task 5: Integrated Verification and Review

**Files:**
- Review all changed files.

- [ ] **Step 1: Run full local verification**

Run:

```bash
bash -n build/inferno-configure.sh templates/scripts/inferno-upgrade.sh tests/regression.sh
bash tests/regression.sh
git diff --check
```

Expected: syntax/diff checks produce no output and regression prints `All regression checks passed.`

- [ ] **Step 2: Inspect final diff**

Run:

```bash
git diff --stat
git diff -- Containerfile templates/scripts/inferno-upgrade.sh templates/systemd/system/inferno-upgrade.service src/inferno.js tests/regression.sh templates/udev/90-inferno-ptp.rules
```

Expected: changes match this plan; no unrelated files except the approved spec/plan docs.

- [ ] **Step 3: Request code review**

Dispatch `code-reviewer` with the full diff and live-node evidence. Blocking review findings must be fixed before commit.

- [ ] **Step 4: Commit after approval**

Run:

```bash
git add docs/superpowers/specs/2026-05-08-inferno-bind-reconciliation-design.md docs/superpowers/plans/2026-05-08-inferno-bind-reconciliation.md Containerfile templates/scripts/inferno-upgrade.sh templates/systemd/system/inferno-upgrade.service src/inferno.js tests/regression.sh templates/udev/90-inferno-ptp.rules
git commit -m "fix Inferno bind reconciliation"
```
