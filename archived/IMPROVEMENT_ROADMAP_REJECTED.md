# Inferno AoIP Appliance — Rejected Items Archive

> These improvement items were reviewed during **April 2026 sprint planning** and rejected.
> They are preserved here for reference but will not be implemented.

| # | Title | Reason for Rejection |
|---|-------|----------------------|
| 2 | Dynamic Disk Selection in Kickstart | Superseded by Item 7 (`%pre` disk detection does the same thing properly) |
| 5 | PXE / Netboot Image | Infrastructure overhead not worth it; USB/ISO install is sufficient |
| 10 | Predictable NIC Naming via udev (`inferno0`) | NICs managed by Cockpit; udev rename would interfere with NetworkManager and Cockpit UI |
| 27 | SSH: Disable Password Authentication | Replaced by Item 57 (Cockpit first-login password prompt) |
| 28 | Firewalld: Configure in the Containerfile | Maintenance burden outweighs benefit; Fedora default firewall zone is sufficient |
| 41 | Multi-Stage Containerfile | Existing cleanup sufficient; low gain for bootc images |
| 49 | mDNS Alias `inferno.local` | Dante is inherently multi-node; static `inferno.local` alias causes mDNS conflicts |

---

## Full Detail Blocks (preserved verbatim)

### Item 2

> **Rejection reason:** Superseded by Item 7 (`%pre` disk detection does the same thing properly)

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

---

### Item 5

> **Rejection reason:** Infrastructure overhead not worth it; USB/ISO install is sufficient

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

---

### Item 10

> **Rejection reason:** NICs managed by Cockpit; udev rename would interfere with NetworkManager and Cockpit UI

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

---

### Item 27

> **Rejection reason:** Replaced by Item 57 (Cockpit first-login password prompt)

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

---

### Item 28

> **Rejection reason:** Maintenance burden outweighs benefit; Fedora default firewall zone is sufficient

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

---

### Item 41

> **Rejection reason:** Existing cleanup sufficient; low gain for bootc images

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

---

### Item 49

> **Rejection reason:** Dante is inherently multi-node; static `inferno.local` alias causes mDNS conflicts

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

---



---

## Archived April 2026 -- Sprint Planning Session

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

### New RT / Reliability Improvements (Session 2, April 2026)

---



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



---

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

