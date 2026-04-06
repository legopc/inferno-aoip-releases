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
    # cockpit-ws + cockpit-system = base; remaining modules add full feature set:
    #   networkmanager = NIC/IP config, storaged = disk/partition management,
    #   selinux = SELinux policy browser, ostree = bootc image upgrades via UI,
    #   kdump = kernel crash config, sosreport = support data collection
    #   pcp = performance metrics graphs, files = web-based file browser
    cockpit-ws cockpit-system \
    cockpit-networkmanager cockpit-storaged cockpit-selinux \
    cockpit-ostree cockpit-kdump cockpit-sosreport \
    cockpit-files \
    # ALSA audio stack
    alsa-lib alsa-utils alsa-plugins-speex speexdsp \
    # Avahi / mDNS (Dante discovery)
    avahi avahi-tools nss-mdns \
    # Required for inferno-configure.sh
    curl \
    # SSH server
    openssh-server \
    # Required by IoT Updater apply-update.sh (OCI image import)
    skopeo \
    && dnf clean all

# ── Directory structure ────────────────────────────────────────────────────────
# NOTE: binaries go in /usr/local/bin/ and /usr/lib64/alsa-lib/ (immutable ostree layer, correct
# SELinux contexts: bin_t and lib_t). Do NOT place executables in /var/lib/ — that path gets
# var_lib_t context which systemd cannot exec (status=203/EXEC Permission denied).
RUN mkdir -p \
    /var/lib/inferno \
    /var/lib/iot-updater \
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
    rm -rf /tmp/inferno-aoip /tmp/${TARBALL} /tmp/${TARBALL}.sha256 && \
    ln -s /usr/bin/alsaloop /usr/local/bin/Virgil-Appliance

# ── Templates (stored with %%PLACEHOLDER%% values, substituted at first boot) ─
# System config templates
COPY templates/inferno-ptpv1.toml         /etc/inferno/statime-inferno.toml.template
COPY templates/alsa/99-inferno.conf       /etc/inferno/99-inferno.conf.template
COPY templates/alsa/asoundrc.spotify      /etc/inferno/asoundrc.spotify.template
COPY templates/alsa/asoundrc.aux          /etc/inferno/asoundrc.aux.template
# Per-user scripts (installed to ~/bin at first boot)
COPY templates/inferno-sink-event         /etc/inferno/inferno-sink-event
COPY templates/librespot-watchdog         /etc/inferno/librespot-watchdog

# ── Inferno branding (Cockpit login screen + nav) ────────────────────────────
# Clone legopc/inferno-branding into branding/ before building
# (handled by build-release.sh and prepare-build.sh automatically)
COPY branding/cockpit/ /usr/share/cockpit/branding/fedora/

# ── Cockpit Inferno page ───────────────────────────────────────────────────────
# Baked into the image at the system-wide Cockpit package path.
# cockpit-ws auto-discovers packages in /usr/share/cockpit/.
COPY cockpit-inferno/src/ /usr/share/cockpit/inferno/

# ── Systemd SYSTEM units ───────────────────────────────────────────────────────
COPY templates/systemd/system/statime-inferno.service /etc/systemd/system/

# ── Systemd USER units (templates — copied to user dir at first boot) ─────────
# inferno-bridge, inferno-keepalive are static (no placeholders)
# librespot.service has %%INFERNO_NAME%% — substituted by inferno-configure.sh
COPY templates/systemd/user/inferno-bridge.service      /etc/inferno/systemd/user/
COPY templates/systemd/user/inferno-keepalive.service   /etc/inferno/systemd/user/
COPY templates/systemd/user/librespot.service           /etc/inferno/systemd/user/
COPY templates/systemd/user/librespot-watchdog.service  /etc/inferno/systemd/user/
# Aux service files — substituted at first boot; NOT enabled (Cockpit starts them on mode switch)
COPY templates/systemd/user/inferno-aux-tx.service      /etc/inferno/systemd/user/
COPY templates/systemd/user/inferno-aux-rx.service      /etc/inferno/systemd/user/
COPY templates/systemd/user/inferno-aux-keepalive.service /etc/inferno/systemd/user/

# ── snd-aloop kernel module (pinned to card 5 — avoids card number conflicts) ─
RUN echo "options snd-aloop index=5" > /etc/modprobe.d/snd-aloop.conf && \
    echo "snd-aloop" > /etc/modules-load.d/snd-aloop.conf

# ── RT scheduling tuning ──────────────────────────────────────────────────────
# The Fedora 43 kernel uses CONFIG_PREEMPT_DYNAMIC. Its default runtime mode is
# 'lazy'; preempt=full switches to full kernel preemption (all code paths
# preemptible, equivalent to compiling with CONFIG_PREEMPT=y). threadirqs moves
# threaded IRQ handlers out of hard-IRQ context. Both reduce worst-case
# scheduling jitter — directly improving PTP clock stability in statime.
# No packages added; no COPR; reversed trivially by bootc rollback.
# The @realtime group limits (rtprio 99, memlock unlimited) raise the ceiling
# for processes that explicitly request RT scheduling. Written manually rather
# than via the realtime-setup rpm to avoid a systemd-sysusers conflict caused
# by that rpm's %post writing /etc/gshadow without a matching /etc/group entry.
RUN mkdir -p /usr/lib/bootc/kargs.d /usr/lib/sysusers.d /etc/security/limits.d && \
    echo 'kargs = ["preempt=full", "threadirqs"]' \
      > /usr/lib/bootc/kargs.d/99-rt.toml && \
    echo 'g realtime 71' \
      > /usr/lib/sysusers.d/realtime-setup.conf && \
    printf '@realtime - rtprio 99\n@realtime - memlock unlimited\n' \
      > /etc/security/limits.d/realtime.conf

# ── First-boot configuration service ──────────────────────────────────────────
# Detects NIC/MAC, derives DEVICE_ID, substitutes placeholders,
# sets up core user environment. Runs once (gated on /etc/inferno.conf absent).
COPY build/inferno-configure.sh /usr/local/sbin/inferno-configure.sh
COPY build/systemd/inferno-configure.service /etc/systemd/system/inferno-configure.service
RUN chmod +x /usr/local/sbin/inferno-configure.sh

# ── Post-boot health check — auto-rollback on bad upgrade (Item 17) ───────────
# Runs 120 s after multi-user.target; calls 'bootc rollback + reboot' if all
# critical services (statime-inferno, cockpit.socket) are down simultaneously.
# Protects headless nodes from being permanently bricked by a bad OTA update.
COPY scripts/inferno-health-check.sh /usr/local/sbin/inferno-health-check.sh
COPY templates/systemd/system/inferno-health-check.service /etc/systemd/system/inferno-health-check.service
RUN chmod +x /usr/local/sbin/inferno-health-check.sh

# ── Enable system services ─────────────────────────────────────────────────────
RUN systemctl enable \
    sshd \
    cockpit.socket \
    avahi-daemon \
    statime-inferno \
    inferno-configure \
    inferno-health-check

# ── Mask conflicting time sync services (PTP manages the clock) ───────────────
RUN systemctl mask systemd-timesyncd chronyd ntpd

# ── core user ─────────────────────────────────────────────────────────────────
# Login: core / inferno123  (console, SSH, Cockpit web UI at https://node:9090)
RUN mkdir -p /var/home && \
    useradd -m -d /var/home/core -G wheel -s /bin/bash core && \
    echo "core:inferno123" | chpasswd && \
    echo "%wheel ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/wheel-nopasswd && \
    # Add core to audio group so user services can open /dev/snd/* (crw-rw---- root:audio).
    # On Fedora bootc, the audio group (GID 63) lives in /usr/lib/group (immutable system layer).
    # groupadd sees it via NSS and refuses with "already exists", so usermod never writes
    # membership to /etc/group. The deployed node then has no audio entry in /etc/group,
    # causing inferno-bridge and librespot to fail with "No such device" on /dev/snd/*.
    # Fix: write directly to /etc/group, bypassing groupadd entirely.
    sed -i '/^audio:/d' /etc/group && echo 'audio:x:63:core' >> /etc/group && \
    # Pre-enable lingering so systemd starts the core user session from the very first boot.
    # Without this, loginctl enable-linger (called in inferno-configure.sh) creates the
    # lingering session for the first time on boot 2 — at that point the audio group is not
    # yet effective in the new session, causing inferno-bridge to fail (ALSA permission denied).
    # Pre-creating the linger file means the session already exists by the time configure runs,
    # so boot 3 (the first normal boot) starts the session with correct group membership.
    mkdir -p /var/lib/systemd/linger && touch /var/lib/systemd/linger/core

# ── Cockpit IoT Updater — baked in (v9+) ──────────────────────────────────────
# Provides the web UI for delivering OCI update bundles (~2 GB) via Cockpit.
# Sidecar (iot-updater.service) runs persistently on 127.0.0.1:8088.
# Apply service (iot-update.service) is started on-demand by the sidecar — NOT enabled at boot.
COPY iot-updater/cockpit-page/  /usr/share/cockpit/iot-updater/
COPY iot-updater/sidecar/server.py     /var/lib/iot-updater/server.py
COPY iot-updater/scripts/apply-update.sh /var/lib/iot-updater/apply-update.sh
COPY iot-updater/systemd/iot-updater.service /etc/systemd/system/iot-updater.service
COPY iot-updater/systemd/iot-update.service  /etc/systemd/system/iot-update.service
RUN chmod +x /var/lib/iot-updater/apply-update.sh && \
    systemctl enable iot-updater
