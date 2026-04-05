# Archived Content

This directory preserves configuration and scripts from earlier development approaches
that predate the current bootc appliance architecture. Files are kept for historical
reference and are **not** part of the current build or deployment workflow.

---

## `ansible/`

**Original purpose:** Automated configuration of hand-built Arch Linux and Fedora IoT nodes
via Ansible playbooks (roles: base, audio, librespot, statime, inferno).

**Why archived:** The project moved to a bootc image-based approach where all system
configuration is baked into a container image at build time. Ansible is no longer invoked
during deployment. Replaced by `build/inferno-configure.sh` (first-boot systemd service).

---

## `osbuild/`

**Original purpose:** An osbuild Blueprint (`inferno-aoip.toml`) for building a Fedora IoT
commit image via `osbuild iot-commit`.

**Why archived:** osbuild IoT commit building was found infeasible for this project
(noted in the file itself). Replaced by `bootc-image-builder` (BIB), which builds a full
Anaconda installer ISO from the container image.

---

## `config/bluetooth/`

**Original purpose:** Configuration for a standalone Bluetooth audio bridge on a ThinkPad T470s,
routing Bluetooth audio into an ALSA loopback device.

**Why archived:** This was a separate experiment and was never part of the main appliance
build. The bootc appliance uses Spotify Connect (librespot), not Bluetooth input.

---

## `scripts/inferno-deploy.sh`

**Original purpose:** First-boot deployment script for the pre-bootc Fedora IoT approach.
Installed binaries into `/var/lib/inferno/`, configured systemd user services, set up
the ALSA loopback device, and started `inferno-web.py` (a status web server).

**Why archived:** Entirely replaced by `build/inferno-configure.sh`, which runs as a
systemd oneshot service on first boot of the bootc appliance. The `inferno-web.py`
interface no longer exists — Cockpit handles all management.

---

## `ignition/`

**Original purpose:** An Ignition JSON config (`inferno-template.ign`) for provisioning
a Fedora IoT node via `coreos-installer`, setting up the `core` user, SSH keys, and
copying first-boot configuration files.

**Why archived:** The project moved from Fedora IoT + coreos-installer to a full
Anaconda installer ISO (built by BIB). Anaconda handles initial provisioning; Ignition
is no longer used.

---

## `docs/archive/install-guide-fedora-iot.md`

**Original purpose:** End-user install guide for the pre-bootc Fedora IoT approach:
`coreos-installer`, Ignition injection, `inferno-deploy.sh`, etc.

**Why archived:** Fully superseded by the Quick Start section in the main README and
`docs/build-and-release.md`. The current appliance uses an Anaconda ISO — completely
different install flow.
