# Inferno Bind Reconciliation Design

## Goal

Inferno appliances must keep working after DHCP delays, subnet moves, reboots,
bootc upgrades, and NIC/IP changes. The Dante/Inferno bind identity is always
the selected NIC name, never a persisted IP address.

## Evidence

- `172.16.10.59` worked with `BIND_IP eno1`; its failure was `/dev/ptp0`
  access (`EACCES`) because `core` could not open `root:clock 0660`.
- `172.16.10.63` failed because `.asoundrc` preserved stale
  `BIND_IP 192.168.1.45` after the node moved to `172.16.10.63`; replacing it
  with `BIND_IP enp0s31f6` fixed the bridge.
- `172.16.10.64` had stale `INFERNO_HW_PTP=yes` on virtio with no `/dev/ptp*`;
  the node needed software clock path handling and statime readiness.

## Canonical State

`/etc/inferno.conf` is the source of truth. `.asoundrc` is generated output and
must not be used as an input for bind selection.

Canonical keys:

- `INFERNO_NIC`: selected Dante NIC.
- `INFERNO_INTERFACE`: current IPv4 on `INFERNO_NIC`, informational only.
- `INFERNO_BIND`: always equal to `INFERNO_NIC`.
- `INFERNO_HW_PTP`: recomputed at boot/upgrade from the selected NIC.
- `INFERNO_CLOCK_PATH`: `/dev/ptpN` when hardware PTP is available, otherwise
  `/tmp/ptp-usrvclock`.

`INFERNO_INTERFACE` is never used for ALSA `BIND_IP`.

## Upgrade Reconciler

`templates/scripts/inferno-upgrade.sh` becomes the idempotent boot/upgrade
reconciler. On every boot it must:

1. Source `/etc/inferno.conf`.
2. Keep saved `INFERNO_NIC` if it exists under `/sys/class/net`.
3. If saved NIC is missing, select the NIC holding the default IPv4 route.
4. Exclude non-appliance interfaces from fallback detection: `lo`, `docker*`,
   `br-*`, `veth*`, `virbr*`, `tap*`, `tun*`, and wireless interfaces.
5. If NIC selection remains ambiguous, fail loudly and leave config untouched.
6. Recompute `INFERNO_INTERFACE` from current IPv4 on the selected NIC.
7. Force `INFERNO_BIND=${INFERNO_NIC}`.
8. Recompute hardware PTP from the selected NIC and matching `/dev/ptpN`.
9. Atomically rewrite `/etc/inferno.conf` only when canonical values changed,
   preserving unknown keys and setting `0644 root:root`.
10. Regenerate managed Inferno ALSA blocks from templates with canonical bind and
    clock values.
11. Reload/restart only affected services when generated files changed.

The reconciler must not rewrite `INFERNO_INTERFACE` to an empty value if DHCP is
not ready. If the selected NIC lacks IPv4, keep the previous value and log a
warning.

## ALSA Generation

The managed Inferno ALSA sections are generated from existing templates:

- `templates/alsa/asoundrc.spotify`
- `templates/alsa/asoundrc.aux`

Generated PCMs always use:

```text
BIND_IP %%INFERNO_BIND%%
CLOCK_PATH %%INFERNO_CLOCK_PATH%%
```

Line-repair of arbitrary `.asoundrc` is not sufficient for stale IPs and stale
clock paths. The release should replace managed Inferno sections while avoiding
global substitutions that could corrupt unrelated ALSA config.

## Cockpit Generation

`src/inferno.js` must stop copying the first `BIND_IP` from existing
`.asoundrc`. `ensureIradioSetup()` and `ensureAuxSetup()` use
`infernoBindValue()` directly.

`infernoBindValue()` returns `currentConf.INFERNO_BIND || currentConf.INFERNO_NIC`.
If neither exists, the UI should fail visibly instead of silently using
`127.0.0.1`.

## PTP Device Access

The image ships a persistent udev rule:

```text
KERNEL=="ptp[0-9]*", GROUP="clock", MODE="0660"
```

The `core` user is a member of `clock` in new images. On upgrade,
`inferno-upgrade.sh` should run `usermod -aG clock core`, reload udev, and
trigger PTP devices. Existing running user managers may need a reboot or user
manager restart before supplementary group membership is visible; the upgrade
script must log this clearly.

`TAG+="uaccess"` and world-writable PTP devices are intentionally rejected for
headless appliance services.

## Service Ordering

`inferno-upgrade.service` runs before `user@1000.service`. If clock state
changes, system `statime-inferno.service` must be restarted or try-restarted
before user bridge services start. User service reloads must target the `core`
manager with `XDG_RUNTIME_DIR=/run/user/1000`.

For runtime network changes, the next reboot or explicit `inferno-upgrade.service`
restart must converge config. Mid-stream automatic restarts on arbitrary DHCP
renewal are out of scope for this release.

## Tests

Regression coverage must include:

- Stale IP bind from `172.16.10.63`: `BIND_IP 192.168.1.45` becomes
  `BIND_IP enp0s31f6`; conf gets `INFERNO_INTERFACE=172.16.10.63` and
  `INFERNO_BIND=enp0s31f6`.
- Subnet move: current IPv4 changes while bind remains NIC name.
- No hardware PTP from `172.16.10.64`: stale `INFERNO_HW_PTP=yes` becomes `no`
  and `INFERNO_CLOCK_PATH=/tmp/ptp-usrvclock`.
- Canonical hardware PTP from `172.16.10.59`: `BIND_IP eno1` and
  `CLOCK_PATH /dev/ptp0` remain canonical.
- Missing saved NIC falls back to default-route NIC.
- Ambiguous NIC detection fails loudly and leaves config untouched.
- Boot-before-DHCP keeps prior `INFERNO_INTERFACE` instead of writing empty or
  `0.0.0.0`.
- Cockpit iradio/AUX generation ignores stale `.asoundrc BIND_IP` and emits the
  canonical NIC name.
- PTP udev rule exists and is group-based, not world-writable.

Verification commands:

```bash
bash -n build/inferno-configure.sh templates/scripts/inferno-upgrade.sh tests/regression.sh
bash tests/regression.sh
git diff --check
```

## Rollout

This changes IP-bound legacy nodes to NIC-name binding on first boot after
upgrade. That is intentional and required by policy. The script logs every
canonicalization so operators can see why services were restarted.
