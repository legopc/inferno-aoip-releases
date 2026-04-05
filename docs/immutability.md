# Inferno Appliance — Fedora bootc Immutability Model

> What is read-only, what is writable, what survives upgrades, and why certain
> design decisions were made. Read this when debugging unexpected behaviour after
> runtime edits or image upgrades.

---

## The OSTree Filesystem Model

Fedora bootc uses **OSTree** as its deployment engine. The filesystem is divided
into three distinct zones with different mutability rules:

```
/
├── usr/          ← IMMUTABLE  — read-only bind-mount from OSTree commit
├── etc/          ← MUTABLE OVERLAY — writable, 3-way merged on upgrade
├── var/          ← MUTABLE STORE — fully writable, never touched by upgrades
├── home/         → symlink to /var/home  (mutable)
├── tmp/          → tmpfs  (ephemeral, gone on reboot)
└── run/          → tmpfs  (ephemeral, gone on reboot)
```

The **OSTree commit** is the container image. Everything baked into the image
lands in `/usr/`. Everything that varies at runtime goes into `/etc/` or `/var/`.

---

## Zone Reference

### `/usr/` — Immutable

Read-only at runtime. Cannot be modified by any running process, including root.
All OS binaries, system libraries, and package-installed files live here.

**In the Inferno appliance:**

| Path | Content | Why here |
|------|---------|----------|
| `/usr/local/bin/statime` | PTP daemon binary | Immutable — version controlled in image |
| `/usr/local/bin/librespot` | Spotify Connect binary | Immutable — version controlled in image |
| `/usr/lib64/alsa-lib/libasound_module_pcm_inferno.so` | Dante ALSA plugin | Must be in `/usr/lib64/alsa-lib/` for correct SELinux context |
| `/usr/local/lib/inferno/inferno-web.py` | Web UI script | Immutable — shipped with image |
| `/usr/local/sbin/inferno-configure.sh` | First-boot config script | Immutable — runs once, cannot be patched at runtime |
| `/usr/lib/systemd/system/statime-inferno.service` | PTP system unit | Immutable |
| `/usr/lib/systemd/system/inferno-configure.service` | First-boot service | Immutable |
| `/usr/lib/group` | System group definitions | Immutable — **read-only shadow of group database** |
| `/usr/lib/passwd` | System user definitions | Immutable — **read-only shadow of passwd** |

**To change anything here: rebuild the image and redeploy.**

### `/etc/` — Mutable Overlay

Writable at runtime. Starts from the image's `/etc/` content but changes made
at runtime persist across reboots. On image upgrade, OSTree performs a **3-way
merge**: `(image-base-etc) + (your-runtime-changes)` — similar to git merge.

This is where `inferno-configure.sh` writes all its output on first boot.

**In the Inferno appliance:**

| Path | Written by | Content |
|------|-----------|---------|
| `/etc/inferno.conf` | `inferno-configure.sh` (first boot) | Sentinel + all resolved variables |
| `/etc/statime-inferno.toml` | `inferno-configure.sh` (from template) | PTP config with NIC + IP substituted |
| `/etc/alsa/conf.d/99-inferno.conf` | `inferno-configure.sh` (from template) | ALSA Dante plugin config |
| `/etc/inferno/` | Image (Containerfile) | Templates with `%%PLACEHOLDER%%` values |
| `/etc/modprobe.d/snd-aloop.conf` | Image (Containerfile) | Forces snd-aloop to card index 5 |
| `/etc/modules-load.d/snd-aloop.conf` | Image (Containerfile) | Auto-loads snd-aloop at boot |
| `/etc/group` | Image + `groupadd` at build time | Writable group membership file |
| `/etc/hostname` | `hostnamectl` (first boot) | `inferno-<mac-suffix>` |
| `/etc/systemd/system/` | Image (symlinks via `systemctl enable`) | Enabled unit symlinks |

**Upgrade behaviour:** `/etc/statime-inferno.toml`, `/etc/inferno.conf`, etc.
are preserved through upgrades (your runtime values survive). If the image
changes the *template* in `/etc/inferno/`, you won't see the change until you
delete `/etc/inferno.conf` and reboot to re-run configuration.

### `/var/` — Mutable Store

Fully writable, never modified by OSTree during upgrades. This is permanent
runtime state. On upgrade, `/var/` is left completely untouched.

**In the Inferno appliance:**

| Path | Content |
|------|---------|
| `/var/home/core/` | User home — `.asoundrc`, `~/bin/`, systemd user units |
| `/var/home/core/.config/systemd/user/` | User systemd services (written at first boot) |
| `/var/log/inferno-configure.log` | First-boot configuration log |
| `/var/lib/systemd/linger/core` | Linger flag — pre-created in image (see below) |

---

## The Two Group Files — A Critical Distinction

This caused the **"3 reboots needed" bug** in v5/v6 and is the most important
immutability gotcha in this project.

Fedora bootc maintains **two group databases**:

| File | Zone | Writable | Purpose |
|------|------|----------|---------|
| `/usr/lib/group` | `/usr/` | ❌ No | System-provided groups from packages |
| `/etc/group` | `/etc/` | ✅ Yes | Runtime group membership, overrides `/usr/lib/group` |

The `audio` group (GID 63) is defined in `/usr/lib/group` (immutable). When
`usermod -aG audio core` runs during image build, it tries to write to `/etc/group`.
Because `/etc/group` had no `audio` entry, the membership was silently dropped.

**Fix (v8+):** Write directly to `/etc/group`, bypassing groupadd entirely.

`groupadd` uses NSS to check for existing groups — it finds `audio` in
`/usr/lib/group` and refuses with "already exists", without writing anything to
`/etc/group`. This means `usermod -aG audio core` that follows also silently
fails to persist (no entry in `/etc/group` to append to). The net result is the
same as not running either command.

The `groupadd --system -g 63 audio 2>/dev/null || true && usermod -aG audio
core` approach used in v6/v7 was therefore **also broken** — confirmed by
physical hardware deployment on 2026-04-05 where the node had no audio group in
`/etc/group` after install.

```dockerfile
# WRONG — groupadd sees /usr/lib/group via NSS and refuses; usermod never writes:
RUN groupadd --system -g 63 audio 2>/dev/null || true && \
    usermod -aG audio core

# CORRECT — write directly to /etc/group, bypassing NSS/groupadd entirely:
RUN sed -i '/^audio:/d' /etc/group && echo 'audio:x:63:core' >> /etc/group
```

**Live fix on a deployed node (if installed from a pre-v8 ISO):**
```bash
echo 'audio:x:63:core' | sudo tee -a /etc/group
sudo reboot   # lingering session must restart to pick up the new group
```
This write to `/etc/group` persists across reboots and `bootc upgrade` (3-way
merge preserves it). No reinstall needed.

The same split applies to `/usr/lib/passwd` vs `/etc/passwd` and
`/usr/lib/shadow` vs `/etc/shadow`.

---

## The Linger Pre-Creation Fix

**Problem (v5/v6):** `loginctl enable-linger core` was called in
`inferno-configure.sh` (first boot). This created the lingering session **for
the first time** at that moment — without the `audio` group being in scope for
the new session process. Result: `inferno-bridge` crashed opening
`/dev/snd/pcmC5D1c`, requiring a third reboot to get a fresh session.

**Root cause:** When linger is first enabled, systemd spawns a new `user@.service`
instance. That instance inherits its supplementary groups from the PAM session
context at creation time — not from `/etc/group` directly. The new session didn't
have `audio` in its effective groups even though `/etc/group` was correct.

**Fix (v7+):** Pre-create the linger flag in the Containerfile:

```dockerfile
RUN mkdir -p /var/lib/systemd/linger && touch /var/lib/systemd/linger/core
```

Since `/var/lib/systemd/linger/core` exists from the very first boot, systemd
never "creates" the session fresh — it's always re-used. By the time any
services start, the session has already been initialized with correct groups.

**Why writing to `/var/` in a Containerfile works:** bootc-image-builder
extracts the container image's `/var/` content and uses it to seed the
initial `/var/` on first deployment. Subsequent upgrades leave `/var/` alone.

---

## What Requires an Image Rebuild vs Runtime Edit

### Requires image rebuild (change in Containerfile)
- Install or remove a package
- Change a binary (`statime`, `librespot`, ALSA plugin)
- Change a systemd system unit file (statime-inferno.service, inferno-configure.service)
- Change `inferno-configure.sh` itself
- Change a config template in `/etc/inferno/` (templates are baked in)
- Change `snd-aloop` card index (in `/etc/modprobe.d/`)
- Add or remove services from `systemctl enable` in Containerfile
- Fix user/group setup (e.g. the audio group fix)

### Can be changed at runtime (persists across reboots, survives upgrades)
- `/etc/statime-inferno.toml` — edit directly (e.g. change PTP domain)
- `/etc/inferno.conf` — delete to force reconfiguration
- `/etc/alsa/conf.d/99-inferno.conf` — ALSA plugin config
- `/etc/hostname` — `hostnamectl set-hostname <name>`
- `/var/home/core/.config/systemd/user/` — add/modify user services
- Network config via `nmcli` (written to `/etc/NetworkManager/`)
- SSH keys in `/var/home/core/.ssh/`

### Lost on reboot (do not rely on)
- Anything in `/tmp/` or `/run/`
- In-memory `ip` / `ip route` changes not backed by NetworkManager
- `sysctl` changes not in `/etc/sysctl.d/`

---

## Upgrade Path

```bash
# Check available updates
sudo bootc status

# Upgrade to latest image
sudo bootc upgrade

# Reboot to apply (staged — current boot untouched until reboot)
sudo reboot
```

On upgrade:
- `/usr/` is atomically replaced with the new OSTree commit
- `/etc/` is 3-way merged — your runtime edits are preserved where possible
- `/var/` is untouched — all runtime state, home dirs, logs survive
- `/etc/inferno.conf` survives — `inferno-configure.sh` will NOT re-run

If a new image version changes a config template and you need the new defaults,
delete `/etc/inferno.conf` after upgrading and reboot.

---

## Cockpit Web UI — bootc Upgrades

With `cockpit-ostree` installed (v7+), upgrades can be triggered from the
Cockpit web UI at `https://<node-ip>:9090` → **Software Updates**.
This is equivalent to `bootc upgrade && reboot` but with a GUI and rollback option.
