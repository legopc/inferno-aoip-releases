# Inferno AoIP Appliance — Containerfile
#
# Produces a fully self-contained Inferno appliance image.
# Build → convert to installer ISO with bootc-image-builder.
#
# Quick build:
#   podman build -t inferno-appliance:v1 .
#
# Convert to installer ISO (one-shot, no HTTP server needed):
#   see build/README.md
#
# Base image notes:
#   fedora-bootc:43 = standard Fedora 43 with bootc support (atomic updates)
#   Uses dnf for packages (no rpm-ostree parsec/dbus-parsec dependency)
#   Result is a bootc-managed system — atomic updates via 'bootc upgrade'

FROM registry.fedoraproject.org/fedora-bootc:43

# ── Packages ──────────────────────────────────────────────────────────────────
RUN dnf install -y --setopt=install_weak_deps=False \
    # Cockpit web UI (management interface — https://node:9090)
    # cockpit-ws provides cockpit.socket; cockpit-system provides the System page
    cockpit-ws cockpit-system \
    # ALSA audio stack
    alsa-lib alsa-utils alsa-plugins-speex speexdsp \
    # Avahi / mDNS (Dante discovery)
    avahi avahi-tools nss-mdns \
    # Web UI backend
    python3 \
    # Required for inferno-configure.sh
    curl \
    # SSH server
    openssh-server \
    && dnf clean all

# ── Directory structure ────────────────────────────────────────────────────────
# NOTE: binaries go in /usr/local/bin/ and /usr/lib64/alsa-lib/ (immutable ostree layer, correct
# SELinux contexts: bin_t and lib_t). Do NOT place executables in /var/lib/ — that path gets
# var_lib_t context which systemd cannot exec (status=203/EXEC Permission denied).
RUN mkdir -p \
    /var/lib/inferno \
    /usr/local/lib/inferno \
    /etc/inferno/systemd/user \
    /etc/alsa/conf.d

# ── Download release binaries (built nightly by CI) ───────────────────────────
# Tarball contains: bin/statime, bin/librespot, lib/libasound_module_pcm_inferno.so
ARG RELEASES_URL=https://github.com/legopc/inferno-aoip-releases/releases/latest/download
RUN TARBALL=inferno-aoip.tar.gz && \
    curl -fsSL "${RELEASES_URL}/${TARBALL}" -o "/tmp/${TARBALL}" && \
    curl -fsSL "${RELEASES_URL}/${TARBALL}.sha256" -o "/tmp/${TARBALL}.sha256" && \
    (cd /tmp && sha256sum -c "${TARBALL}.sha256") && \
    tar -xzf "/tmp/${TARBALL}" -C /tmp/ && \
    cp /tmp/inferno-aoip/bin/statime              /usr/local/bin/ && \
    cp /tmp/inferno-aoip/bin/librespot            /usr/local/bin/ && \
    cp /tmp/inferno-aoip/lib/libasound_module_pcm_inferno.so /usr/lib64/alsa-lib/ && \
    chmod +x /usr/local/bin/statime /usr/local/bin/librespot && \
    rm -rf /tmp/inferno-aoip /tmp/${TARBALL} /tmp/${TARBALL}.sha256

# ── Templates (stored with %%PLACEHOLDER%% values, substituted at first boot) ─
# System config templates
COPY templates/inferno-ptpv1.toml         /etc/inferno/statime-inferno.toml.template
COPY templates/alsa/99-inferno.conf       /etc/inferno/99-inferno.conf.template
COPY templates/alsa/asoundrc.spotify      /etc/inferno/asoundrc.spotify.template
# Per-user scripts (installed to ~/bin at first boot)
COPY templates/inferno-sink-event         /etc/inferno/inferno-sink-event
COPY templates/librespot-watchdog         /etc/inferno/librespot-watchdog
# Web management UI
COPY scripts/inferno-web.py               /usr/local/lib/inferno/inferno-web.py

# ── Systemd SYSTEM units ───────────────────────────────────────────────────────
COPY templates/systemd/system/statime-inferno.service /etc/systemd/system/

# ── Systemd USER units (templates — copied to user dir at first boot) ─────────
# inferno-bridge, inferno-keepalive are static (no placeholders)
# librespot.service has %%INFERNO_NAME%% — substituted by inferno-configure.sh
COPY templates/systemd/user/inferno-bridge.service      /etc/inferno/systemd/user/
COPY templates/systemd/user/inferno-keepalive.service   /etc/inferno/systemd/user/
COPY templates/systemd/user/librespot.service           /etc/inferno/systemd/user/
COPY templates/systemd/user/librespot-watchdog.service  /etc/inferno/systemd/user/
COPY templates/systemd/user/inferno-web.service         /etc/inferno/systemd/user/

# ── snd-aloop kernel module (pinned to card 5 — avoids card number conflicts) ─
RUN echo "options snd-aloop index=5" > /etc/modprobe.d/snd-aloop.conf && \
    echo "snd-aloop" > /etc/modules-load.d/snd-aloop.conf

# ── First-boot configuration service ──────────────────────────────────────────
# Detects NIC/MAC, derives DEVICE_ID, substitutes placeholders,
# sets up core user environment. Runs once (gated on /etc/inferno.conf absent).
COPY build/inferno-configure.sh /usr/local/sbin/inferno-configure.sh
COPY build/systemd/inferno-configure.service /etc/systemd/system/inferno-configure.service
RUN chmod +x /usr/local/sbin/inferno-configure.sh

# ── Enable system services ─────────────────────────────────────────────────────
RUN systemctl enable \
    sshd \
    cockpit.socket \
    avahi-daemon \
    statime-inferno \
    inferno-configure

# ── Mask conflicting time sync services (PTP manages the clock) ───────────────
RUN systemctl mask systemd-timesyncd chronyd ntpd

# ── core user ─────────────────────────────────────────────────────────────────
# Login: core / inferno123  (console, SSH, Cockpit web UI at https://node:9090)
RUN mkdir -p /var/home && \
    useradd -m -d /var/home/core -G wheel -s /bin/bash core && \
    echo "core:inferno123" | chpasswd && \
    echo "%wheel ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/wheel-nopasswd && \
    # Add core to audio group so user services can open /dev/snd/* (crw-rw---- root:audio).
    # On Fedora bootc, the audio group (GID 63) is defined in /usr/lib/group (system-provided,
    # read-only). usermod -aG requires the group to exist in /etc/group (the writable file) to
    # write membership there. groupadd --system ensures the entry exists in /etc/group first,
    # then usermod adds core. Without this, membership is silently lost after reboot.
    groupadd --system -g 63 audio 2>/dev/null || true && \
    usermod -aG audio core
