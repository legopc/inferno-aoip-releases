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

