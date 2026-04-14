# Inferno AoIP Appliance -- Improvement Roadmap V2

> **Document type:** Engineering backlog -- second research wave  
> **Scope:** Fedora bootc appliance (Virgil) + ecosystem integration (Minos/inferno-central/node-agent)  
> **Research method:** Static analysis of all source files across inferno-aoip-releases, cockpit-inferno, inferno-iradio, inferno-node-agent, inferno-central, and dante-patchbox  
> **Total items:** 50 (3 Critical, 25 High, 22 Medium)  
> **Difficulty split:** 31 Easy / 17 Medium / 2 Hard  
> **Prior roadmap:** [IMPROVEMENT_ROADMAP.md](IMPROVEMENT_ROADMAP.md) covers Sprint 2 (16 items), Later (18 items), On Hold (9 items)  

All items in this document are NEW -- none duplicate items already in IMPROVEMENT_ROADMAP.md.  
Two items are **Critical** confirmed bugs: V2-OPS-05 (silent JS runtime bug) and V2-AUD-01 (confirmed missing flag documented in own code comment). V2-SEC-01 is a Critical security misconfiguration.

---

## How to Read This Document

| Field | Values |
|---|---|
| **Importance** | Critical / High / Medium / Low |
| **Difficulty** | Easy (<2h) / Medium (half-day) / Hard (multi-day) |
| **Risk** | Low / Medium / High -- regression risk from implementing |
| **Prerequisites** | Items from this document (V2-xxx) or prior roadmap (item numbers) that should land first |

---

## Executive Summary -- All 50 Items

| ID | Category | Title | Importance | Difficulty | Risk | Prerequisites |
|---|---|---|---|---|---|---|
| V2-SEC-01 | SEC | statime `NoNewPrivileges=no` -- Setuid Re-escalation Path | Critical | Easy | Low | Item 106 (complementary, independent) |
| V2-SEC-02 | SEC | SNMP Credentials in Plaintext World-Readable `/etc/inferno.conf` | High | Easy | Low | None |
| V2-SEC-03 | SEC | IoT Updater `/session-token` Unauthenticated -- Any Local Process Can Trigger OTA | High | Medium | Medium | Item 63 (OTA signing, complementary) |
| V2-SEC-04 | SEC | Cockpit `spSudo()` Shell Injection via Device Names | High | Medium | Medium | None |
| V2-SEC-05 | SEC | All User Systemd Services Have Zero Security Directives | High | Medium | Medium | None |
| V2-SEC-06 | SEC | SSH Daemon Enabled With No Hardening Drop-In Configuration | High | Easy | Low | None |
| V2-SEC-07 | SEC | SNMP `agentAddress` Listens on All Interfaces Including Dante Audio NIC | Medium | Easy | Low | None |
| V2-SEC-08 | SEC | Avahi mDNS No Interface Filtering -- Advertises SSH/Cockpit on Audio Network | Medium | Easy | Low | None |
| V2-SEC-09 | SEC | `inferno-configure.service` Runs as Root With No Systemd Sandbox Directives | Medium | Easy | Low | None |
| V2-SEC-10 | SEC | librespot Spotify Credential Cache World-Readable (Missing `UMask=0077`) | Medium | Easy | Low | None |
| V2-AUD-01 | AUD | alsaloop Missing `-S SAMPLERATE` Clock Drift Compensation | Critical | Easy | Low | None |
| V2-AUD-02 | AUD | ALSA dmix Buffer Too Shallow for 20ms alsaloop Transfer Window | High | Easy | Low | V2-AUD-01 |
| V2-AUD-03 | AUD | librespot.service Missing `CPUSchedulingPolicy=fifo` | High | Easy | Low | None |
| V2-AUD-04 | AUD | iRadio Rubato Resampler `sub_chunks=2` -- Minimum Quality, Audible Aliasing | High | Easy | Low | None |
| V2-AUD-05 | AUD | iRadio ALSA PCM Missing `sw_params` (`start_threshold`/`avail_min` Unset) | High | Easy | Low | None |
| V2-AUD-06 | AUD | iRadio Pre-Roll Buffer Threshold 8KB Causes Decoder Starvation | Medium | Easy | Low | None |
| V2-AUD-07 | AUD | No ALSA Xrun Telemetry in Node-Agent Metrics/Health | Medium | Easy | Low | None |
| V2-AUD-08 | AUD | statime PTP Intervals Not Tuned to Dante/AES67 Profile | Medium | Medium | Medium | None |
| V2-AUD-09 | AUD | iRadio Slot Keeper No Runtime ALSA Re-Open After Plugin Failure | Medium | Medium | Low | None |
| V2-AUD-10 | AUD | librespot `--normalisation` Absent -- +/-20 LU Track Level Variation into Dante | Medium | Easy | Low | None |
| V2-OPS-01 | OPS | Embed iRadio Playback Controls Inline in Cockpit | High | Medium | Low | None |
| V2-OPS-02 | OPS | Spotify Connect Account Link Status in Cockpit | High | Medium | Low | None |
| V2-OPS-03 | OPS | PTP Jitter, Variance, and Mean Offset Metrics in Performance Panel | High | Easy | Low | None |
| V2-OPS-04 | OPS | iRadio Custom Stream URL Pre-play Validation and Reachability Probe | Medium | Easy | Low | None |
| V2-OPS-05 | OPS | `restartAll()` Bug -- `AUX_SVCS` Undefined, Non-Spotify Modes Silently Skip Restart | Critical | Easy | Low | None |
| V2-OPS-06 | OPS | Dante Network Pre-flight Checks: Multicast, MTU, Link Speed, IP Conflict | High | Medium | Low | None |
| V2-OPS-07 | OPS | Mode-Switch Audio Interruption Warning with Active Service Inventory | High | Easy | Low | None |
| V2-OPS-08 | OPS | Post-Reboot Reconnect Countdown for Reboot and Re-deploy Actions | Medium | Easy | Low | None |
| V2-OPS-09 | OPS | ALSA XRUN Counter on Health Dashboard | Medium | Easy | Low | None |
| V2-OPS-10 | OPS | Fleet Peer Discovery -- Show Other Inferno Nodes via Dante mDNS | Medium | Medium | Low | None |
| V2-BLD-01 | BLD | No CI/CD Pipeline -- Container and ISO Build Is Entirely Manual | High | Hard | Low | None |
| V2-BLD-02 | BLD | bootc-image-builder Pulled as `:latest` -- Build Tool Version Unpinned | Medium | Easy | Low | None |
| V2-BLD-03 | BLD | Containerfile Downloads Binaries from `releases/latest` -- Non-Deterministic Builds | High | Easy | Medium | None |
| V2-BLD-04 | BLD | Rust Toolchain Pinned to `@stable` -- Silent Toolchain Upgrades | Medium | Easy | Medium | None |
| V2-BLD-05 | BLD | No SBOM Generation or Vulnerability Scan in Build Pipeline | Medium | Medium | Low | None |
| V2-BLD-06 | BLD | All RPM Packages Unpinned in Containerfile -- Non-Reproducible dnf Installs | Medium | Hard | Medium | None |
| V2-BLD-07 | BLD | No Ignition Placeholder Substitution Script -- Manual Error-Prone Provisioning | Medium | Easy | Medium | None |
| V2-BLD-08 | BLD | OTA Upload No Chunk-Resume Across Sidecar Restarts | Medium | Medium | Low | None |
| V2-BLD-09 | BLD | No Automated Post-Build Container Smoke Test | High | Medium | Low | None |
| V2-BLD-10 | BLD | `podman build` Lacks `--pull=newer` -- Base Image Can Be Silently Stale | High | Easy | Low | None |
| V2-ECO-01 | ECO | mDNS TXT Key Mismatch -- `device=` Published, `device_name=` Read | High | Easy | Low | None |
| V2-ECO-02 | ECO | Virgil Has No Avahi Service File Template -- mDNS Bootstrap Paradox | High | Medium | Low | None |
| V2-ECO-03 | ECO | No `/dante` Endpoint on Node-Agent -- Minos Cannot Auto-Discover Source Metadata | High | Easy | Low | None |
| V2-ECO-04 | ECO | `/health` Missing `dante_connected` Flag -- Service Active != Dante on Network | High | Easy | Low | None |
| V2-ECO-05 | ECO | ALSA Xrun Counters Absent from `/metrics` -- Audio Dropout Events Invisible to Central | High | Easy | Low | None |
| V2-ECO-06 | ECO | No Prometheus Text-Format Scrape Endpoint on Node-Agent | Medium | Easy | Low | V2-ECO-05 |
| V2-ECO-07 | ECO | Mode Switch via `PUT /config` Restarts Only `inferno-bridge` -- Source Services Not Transitioned | High | Medium | Medium | None |
| V2-ECO-08 | ECO | Token Bootstrap Relies on Hardcoded SSH Password -- Breaks If Default Changed | High | Medium | Low | None |
| V2-ECO-09 | ECO | No Self-Registration Service -- Nodes Cannot Push Identity to inferno-central | Medium | Medium | Low | None |
| V2-ECO-10 | ECO | No Push Alerting on Critical Service Failure -- All Monitoring Is Pull-Only | Medium | Medium | Low | V2-ECO-09 |

---

## Quick Wins (Easy + High or Critical Importance)

Items that are easy to implement but have outsized impact:

| ID | Title | Importance | Why Do It First |
|---|---|---|---|
| V2-OPS-05 | restartAll() AUX_SVCS undefined | Critical | One-line fix, confirmed silent bug in production |
| V2-AUD-01 | alsaloop missing -S SAMPLERATE | Critical | Flag literally documented in own code comment, absent from ExecStart |
| V2-SEC-01 | statime NoNewPrivileges=no | Critical | Single character change, eliminates setuid re-escalation |
| V2-AUD-03 | librespot missing CPUSchedulingPolicy=fifo | High | Two-line service change, eliminates ALSA preemption underruns |
| V2-AUD-10 | librespot --normalisation absent | High | One-flag addition, broadcast-consistent audio levels |
| V2-SEC-06 | SSH no hardening config | High | One Containerfile RUN block, 8 non-breaking directives |
| V2-SEC-02 | SNMP credentials world-readable | High | chmod + install-m fix in two files |
| V2-OPS-03 | PTP jitter/variance metrics | High | Pure computation on existing in-memory data, no new I/O |
| V2-ECO-01 | mDNS TXT key mismatch | High | One-line fix in j2 template, unblocks central device naming |
| V2-ECO-04 | /health missing dante_connected | High | Simple socket-existence check, fixes fleet health accuracy |
| V2-BLD-10 | podman build lacks --pull=newer | High | One flag addition, prevents stale base image CVEs |

---

## Security

Issues found by auditing systemd unit files, Cockpit plugin source, IoT updater server code, and network-facing daemon configurations. Several are confirmed vulnerabilities with direct exploit paths.

### Summary

| ID | Title | Importance | Difficulty | Risk | Prerequisites |
|---|---|---|---|---|---|
| V2-SEC-01 | statime `NoNewPrivileges=no` -- Setuid Re-escalation Path | Critical | Easy | Low | Item 106 (complementary, independent) |
| V2-SEC-02 | SNMP Credentials in Plaintext World-Readable `/etc/inferno.conf` | High | Easy | Low | None |
| V2-SEC-03 | IoT Updater `/session-token` Unauthenticated -- Any Local Process Can Trigger OTA | High | Medium | Medium | Item 63 (OTA signing, complementary) |
| V2-SEC-04 | Cockpit `spSudo()` Shell Injection via Device Names | High | Medium | Medium | None |
| V2-SEC-05 | All User Systemd Services Have Zero Security Directives | High | Medium | Medium | None |
| V2-SEC-06 | SSH Daemon Enabled With No Hardening Drop-In Configuration | High | Easy | Low | None |
| V2-SEC-07 | SNMP `agentAddress` Listens on All Interfaces Including Dante Audio NIC | Medium | Easy | Low | None |
| V2-SEC-08 | Avahi mDNS No Interface Filtering -- Advertises SSH/Cockpit on Audio Network | Medium | Easy | Low | None |
| V2-SEC-09 | `inferno-configure.service` Runs as Root With No Systemd Sandbox Directives | Medium | Easy | Low | None |
| V2-SEC-10 | librespot Spotify Credential Cache World-Readable (Missing `UMask=0077`) | Medium | Easy | Low | None |

---

#### V2-SEC-01 -- statime `NoNewPrivileges=no` -- Setuid Re-escalation Path

**Importance:** Critical  
**Difficulty:** Easy  
**Risk:** Low  
**Prerequisites:** Item 106 (complementary, independent)  

##### Impact

Prevents a compromised statime process from gaining additional privileges via setuid binaries, defeating the CapabilityBoundingSet entirely.

##### Description

`statime-inferno.service` line 17 has `NoNewPrivileges=no` -- the only system service in the entire repo with this flag explicitly set to the insecure value. Even when a `CapabilityBoundingSet=` is applied (Item 106), `NoNewPrivileges=no` means a compromised statime binary can still call `execve()` on any setuid binary on the system (e.g. `/usr/bin/sudo`, `pkexec`) which bypasses the bounding set on exec. Fix is a single-character change: `NoNewPrivileges=no` -> `NoNewPrivileges=yes`. statime only needs its two ambient capabilities (`CAP_NET_ADMIN`, `CAP_SYS_TIME`) and never calls any setuid helper.

##### Evidence

``templates/systemd/system/statime-inferno.service:17` -- `NoNewPrivileges=no``

---

#### V2-SEC-02 -- SNMP Credentials in Plaintext World-Readable `/etc/inferno.conf`

**Importance:** High  
**Difficulty:** Easy  
**Risk:** Low  
**Prerequisites:** None  

##### Impact

Prevents any local process running as any UID from reading SNMPv3 auth/privacy passphrases and v2c community strings.

##### Description

When an operator configures SNMP via the Cockpit SNMP tab, the v3 auth passphrase and privacy passphrase are written to `/etc/inferno.conf` via `cockpit.spawn(["sudo","-n","tee",path])`. The `tee` command creates the file with default umask `0644` (world-readable) and no subsequent `chmod` is performed. `INFERNO_SNMP_V3_AUTH_PASS` and `INFERNO_SNMP_V3_PRIV_PASS` (used for SHA-256/AES-128 auth) are therefore readable by any process on the system. The same issue exists for the v2c community string. Fix: add `chmod 0640 /etc/inferno.conf && chown root:core /etc/inferno.conf` to `inferno-configure.sh` immediately after the heredoc write, and replace `sudo -n tee <path>` in `writeFileAsSudo()` with `sudo install -m 0640 -o root -g core /dev/stdin <path>`.

##### Evidence

``build/inferno-configure.sh:271` -- `cat > /etc/inferno.conf <<EOF` with no chmod; `cockpit-inferno/src/inferno.js:83` -- `writeFileAsSudo` uses bare `sudo -n tee`; `inferno-configure.sh:289-292` -- `INFERNO_SNMP_V3_AUTH_PASS=` written to that 0644 file`

---

#### V2-SEC-03 -- IoT Updater `/session-token` Unauthenticated -- Any Local Process Can Trigger OTA

**Importance:** High  
**Difficulty:** Medium  
**Risk:** Medium  
**Prerequisites:** Item 63 (OTA signing, complementary)  

##### Impact

Prevents unprivileged local processes from obtaining the OTA session token and triggering firmware deploy or OS rollback without operator confirmation.

##### Description

The IoT updater sidecar (running as root on `127.0.0.1:8088`) generates a random session token at startup. The endpoint `GET /session-token` returns this token to any TCP client with no authentication guard -- no credential check, no Cockpit bridge verification. Once obtained, the token satisfies `_check_session_token()` on all POST endpoints including `/upload/apply` (deploy firmware) and `/rollback` (revert OS). A compromised service process running as any UID (snmpd, avahi, pcp) can obtain root-equivalent OTA control. The CORS origin check only guards browser requests, not raw socket clients. Fix: gate `/session-token` on a Unix-domain socket owned root:cockpit-ws (mode 0660), or derive the token from a systemd `LoadCredential=` secret and never expose it over TCP.

##### Evidence

``iot-updater/sidecar/server.py:427-428` -- `GET /session-token` returns token with no auth guard; `server.py:571-574` -- all POST mutations check session token only`

---

#### V2-SEC-04 -- Cockpit `spSudo()` Shell Injection via Device Names

**Importance:** High  
**Difficulty:** Medium  
**Risk:** Medium  
**Prerequisites:** None  

##### Impact

Prevents arbitrary root command execution via shell-metacharacter-containing Spotify/Dante device names in the Cockpit UI.

##### Description

`spSudo(cmd)` at `inferno.js:77-79` constructs its command as `cockpit.spawn(["bash", "-c", "sudo -n " + cmd])` -- string concatenation with no escaping. `saveConfig()` embeds the operator-supplied Spotify name and Dante name form fields directly into bash `sed` commands: e.g., `spUser("sed -i 's/--name \"[^\"]*\"/--name \"" + newSpotifyName + "\"/' " + LIBRESPOT_SVC)`. A device name of `"; sudo reboot #` closes the sed argument and executes reboot as root. Fix: replace all `spUser`/`spSudo` sed/shell invocations with `cockpit.file().replace()` using JS regex substitution, or use array-form `cockpit.spawn()` -- never pass user-input strings into `bash -c`.

##### Evidence

``cockpit-inferno/src/inferno.js:78` -- `cockpit.spawn(["bash","-c","sudo -n " + cmd])`; line 851 -- raw form input `newSpotifyName` concatenated into sed shell string; lines 867-869 -- same for `newDanteName``

---

#### V2-SEC-05 -- All User Systemd Services Have Zero Security Directives

**Importance:** High  
**Difficulty:** Medium  
**Risk:** Medium  
**Prerequisites:** None  

##### Impact

Limits blast radius of a compromised librespot (processes untrusted Spotify/OGG data from the internet) or inferno-bridge process.

##### Description

Every user-space service -- `inferno-bridge.service`, `librespot.service`, `inferno-keepalive.service`, `inferno-aux-tx/rx.service` -- contains no systemd security hardening directives whatsoever. None have `NoNewPrivileges=yes`, `PrivateTmp=yes`, `ProtectSystem=strict`, `ProtectHome=read-only`, `RestrictAddressFamilies`, `SystemCallFilter`, or `PrivateDevices`. librespot parses untrusted audio metadata from the internet (OGG Vorbis, Spotify CDN data) and currently has write access to `~/.asoundrc`, all user systemd unit files, and the Spotify token cache. Baseline fix: add `NoNewPrivileges=yes`, `PrivateTmp=yes`, `ProtectSystem=strict`, `ReadWritePaths=~/.cache/librespot` to `librespot.service`; similar minimal set to `inferno-bridge` and keepalive services. Note: `ProtectSystem=strict` requires `ReadWritePaths=` for any directories the service writes to.

##### Evidence

``grep` across all `templates/systemd/user/*.service` -- zero security directives in any user service file; only `statime-inferno.service` (a system service) has any hardening`

---

#### V2-SEC-06 -- SSH Daemon Enabled With No Hardening Drop-In Configuration

**Importance:** High  
**Difficulty:** Easy  
**Risk:** Low  
**Prerequisites:** None  

##### Impact

Closes SSH default-config attack surface: MaxAuthTries 6, no idle timeout, X11Forwarding on.

##### Description

`openssh-server` is installed and `sshd` is enabled (Containerfile line 129) but no custom `sshd_config.d` drop-in is written anywhere in the Containerfile or scripts. Fedora default allows 6 authentication attempts per connection, keeps idle sessions alive indefinitely, and enables X11Forwarding. None of these are covered by any existing roadmap item (Item 27 which disabled password auth entirely was rejected). Non-breaking hardening directives that are completely absent: `MaxAuthTries 3`, `LoginGraceTime 20`, `ClientAliveInterval 300`, `ClientAliveCountMax 2`, `X11Forwarding no`, `AllowTcpForwarding no`, `PermitUserEnvironment no`. Fix: add a `RUN` in the Containerfile that writes `/etc/ssh/sshd_config.d/99-inferno-hardening.conf` with these directives.

##### Evidence

``Containerfile:129` -- sshd in `systemctl enable` list; `grep -r "sshd_config|MaxAuthTries|ClientAlive|X11Forward"` returns zero results across entire repo`

---

#### V2-SEC-07 -- SNMP `agentAddress` Listens on All Interfaces Including Dante Audio NIC

**Importance:** Medium  
**Difficulty:** Easy  
**Risk:** Low  
**Prerequisites:** None  

##### Impact

Prevents AV equipment on the Dante network from querying or fingerprinting the appliance via SNMP.

##### Description

The snmpd configuration template sets `agentAddress udp:161` -- binding to all network interfaces. The Dante network is typically shared with AV control gear (Cisco switches, QSC, Crestron) that communicates on UDP 161. Exposing SNMP (with a cleartext v2c community string) to this segment allows any network device to enumerate the appliance. Fix: change the template to `agentAddress udp:%%INFERNO_INTERFACE%%:161` and update `inferno-snmp-apply.sh` to substitute that placeholder. For management-only access, `udp:127.0.0.1:161` with a Cockpit proxy is the cleanest solution.

##### Evidence

``templates/snmpd.conf.template:31` -- `agentAddress udp:161` with no interface binding; line 7 -- `rocommunity` set to `default` (all sources, all interfaces)`

---

#### V2-SEC-08 -- Avahi mDNS No Interface Filtering -- Advertises SSH/Cockpit on Audio Network

**Importance:** Medium  
**Difficulty:** Easy  
**Risk:** Low  
**Prerequisites:** None  

##### Impact

Stops SSH and Cockpit management ports from being discoverable by AV equipment on the Dante broadcast domain.

##### Description

`avahi-daemon` is enabled (Containerfile line 131) with no custom `avahi-daemon.conf`. Avahi's default responds to mDNS queries on all interfaces and advertises all registered service types. On a typical AoIP deployment the Dante NIC is on the same physical segment as management. Avahi will respond to `_ssh._tcp` and `_cockpit._tcp` queries from switches, amplifiers, or other Dante nodes, exposing the management attack surface. Fix: create `/etc/avahi/avahi-daemon.conf` in the Containerfile with `allow-interfaces=` set to the Dante NIC (substituted at first-boot by `inferno-configure.sh`), and restrict published service types to Dante-related records only (`_netaudio._udp`, `_inferno-aoip._tcp`).

##### Evidence

``Containerfile:131` -- `avahi-daemon` enabled; no `avahi-daemon.conf` in `templates/` or `scripts/`; no `deny-interfaces`, `allow-interfaces` reference anywhere in repo`

---

#### V2-SEC-09 -- `inferno-configure.service` Runs as Root With No Systemd Sandbox Directives

**Importance:** Medium  
**Difficulty:** Easy  
**Risk:** Low  
**Prerequisites:** None  

##### Impact

Limits kernel attack surface from first-boot script invoking `ethtool`, `aplay`, `modprobe` as uid=0.

##### Description

`inferno-configure.service` is a `Type=oneshot` root service with no systemd security directives at all -- no `ProtectKernelTunables`, `ProtectKernelLogs`, `PrivateTmp`, or `LockPersonality`. The script invokes `ethtool -T` (parses NIC capability output), `aplay -l` (parses kernel ALSA state), and `hostnamectl` (D-Bus call) all as uid=0. Note: `NoNewPrivileges=yes` cannot be added because the script calls `sudo -u core` to enable user services, but `ProtectKernelTunables=yes`, `ProtectKernelLogs=yes`, `PrivateTmp=yes`, and `LockPersonality=yes` are all safe to add and provide meaningful defence-in-depth without breaking functionality.

##### Evidence

``build/systemd/inferno-configure.service` -- `[Service]` contains only Type/ExecStart/Timeout/StandardOutput; zero security directives; `build/inferno-configure.sh:88-110` -- invokes `ethtool -T` with NIC name from `/etc/inferno/nic-override``

---

#### V2-SEC-10 -- librespot Spotify Credential Cache World-Readable (Missing `UMask=0077`)

**Importance:** Medium  
**Difficulty:** Easy  
**Risk:** Low  
**Prerequisites:** None  

##### Impact

Prevents root-running services (iot-updater) from exfiltrating the Spotify device OAuth credential blob.

##### Description

`librespot.service` launches librespot with `--cache /var/home/core/.cache/librespot`. librespot stores `credentials.json` in this directory containing a Spotify-issued `auth_data` blob (a reusable device credential, not a raw password, but redeemable for a Spotify access token). The cache directory and files are created by librespot with default process umask `0022`, resulting in `0755` directory and `0644` files -- readable by root processes. `iot-updater.service` explicitly runs as `User=root` and can trivially read `/var/home/core/.cache/librespot/credentials.json`. Fix: add `mkdir -p /var/home/core/.cache/librespot && chmod 0700 /var/home/core/.cache/librespot` to `inferno-configure.sh`, and add `UMask=0077` to `librespot.service`.

##### Evidence

``templates/systemd/user/librespot.service:22-23` -- `--cache /var/home/core/.cache/librespot`; no `UMask=` in service; no `chmod` for `.cache/librespot` in `inferno-configure.sh`; `iot-updater/systemd/iot-updater.service:7` -- `User=root``

---



## Audio & Real-Time Performance

Issues found by auditing ALSA configs, systemd service units, and iRadio bridge Rust source. Several are confirmed bugs with direct audio quality impact on every active deployment.

### Summary

| ID | Title | Importance | Difficulty | Risk | Prerequisites |
|---|---|---|---|---|---|
| V2-AUD-01 | alsaloop Missing `-S SAMPLERATE` Clock Drift Compensation | Critical | Easy | Low | None |
| V2-AUD-02 | ALSA dmix Buffer Too Shallow for 20ms alsaloop Transfer Window | High | Easy | Low | V2-AUD-01 |
| V2-AUD-03 | librespot.service Missing `CPUSchedulingPolicy=fifo` | High | Easy | Low | None |
| V2-AUD-04 | iRadio Rubato Resampler `sub_chunks=2` -- Minimum Quality, Audible Aliasing | High | Easy | Low | None |
| V2-AUD-05 | iRadio ALSA PCM Missing `sw_params` (`start_threshold`/`avail_min` Unset) | High | Easy | Low | None |
| V2-AUD-06 | iRadio Pre-Roll Buffer Threshold 8KB Causes Decoder Starvation | Medium | Easy | Low | None |
| V2-AUD-07 | No ALSA Xrun Telemetry in Node-Agent Metrics/Health | Medium | Easy | Low | None |
| V2-AUD-08 | statime PTP Intervals Not Tuned to Dante/AES67 Profile | Medium | Medium | Medium | None |
| V2-AUD-09 | iRadio Slot Keeper No Runtime ALSA Re-Open After Plugin Failure | Medium | Medium | Low | None |
| V2-AUD-10 | librespot `--normalisation` Absent -- +/-20 LU Track Level Variation into Dante | Medium | Easy | Low | None |

---

#### V2-AUD-01 -- alsaloop Missing `-S SAMPLERATE` Clock Drift Compensation

**Importance:** Critical  
**Difficulty:** Easy  
**Risk:** Low  
**Prerequisites:** None  

##### Impact

Prevents periodic xruns that interrupt Dante TX audio flows due to uncompensated clock domain divergence between ALSA and PTP.

##### Description

`inferno-bridge.service`'s `ExecStart` calls `alsaloop` with `-C hw:Loopback,1,0 -P inferno_spotify -r 48000 -f S32_LE -c 2 -t 20000`, but the inline comment directly above reads: "alsaloop with -t 20000 (20ms transfer window) and SAMPLERATE sync for clock drift." The `-S SAMPLERATE` flag (alsaloop sync mode 1 -- adjust playback sample-rate to track capture) was documented as required but is absent from the actual command line. alsaloop's default sync mode is 0 (none), so clock drift between the local ALSA kernel timer driving dmix and the PTP-disciplined clock driving the Inferno ALSA plugin is entirely uncompensated. These two clock domains will diverge by several ppm, producing a guaranteed xrun approximately every few minutes.

##### Evidence

``templates/systemd/user/inferno-bridge.service:13-21` -- comment says "SAMPLERATE sync for clock drift" but `ExecStart` has no `-S` flag`

---

#### V2-AUD-02 -- ALSA dmix Buffer Too Shallow for 20ms alsaloop Transfer Window

**Importance:** High  
**Difficulty:** Easy  
**Risk:** Low  
**Prerequisites:** V2-AUD-01  

##### Impact

Eliminates underruns caused by scheduler jitter consuming the 1ms headroom between the dmix buffer (21ms) and alsaloop window (20ms).

##### Description

`asoundrc.spotify` configures the `inferno_mix` dmix slave with `period_size=256` and `periods=4`, giving a total buffer of 1024 frames = 21.3ms at 48kHz. `inferno-bridge.service` passes `-t 20000` (20ms) to alsaloop -- 94% of the available buffer. Linux scheduler tick jitter on Fedora with `HZ=250` (no `isolcpus`) is nominally 2-8ms P99, which is 2-8x larger than the 1ms headroom. Buffer underruns under any non-trivial system load are near-certain. Doubling `periods` from 4 to 8 (buffer = 2048 frames = 42.7ms) preserves the 20ms effective latency while tripling the jitter margin.

##### Evidence

``templates/alsa/asoundrc.spotify:32-36` -- `period_size 256`, `periods 4`; `inferno-bridge.service:21` -- `-t 20000``

---

#### V2-AUD-03 -- librespot.service Missing `CPUSchedulingPolicy=fifo`

**Importance:** High  
**Difficulty:** Easy  
**Risk:** Low  
**Prerequisites:** None  

##### Impact

Prevents librespot ALSA writer thread preemption from causing loopback underruns and downstream Dante audio glitches.

##### Description

`librespot.service` sets `LimitMEMLOCK=infinity` (correct, enables `mlockall`) but has no `CPUSchedulingPolicy=`, `CPUSchedulingPriority=`, `Nice=`, or `IOSchedulingClass=` directives. librespot's audio output thread calls into ALSA's `snd-aloop` module which has a fixed-size ring buffer. Under any momentary CPU spike (cockpit-ws serving a request, pmcd collecting metrics, iot-updater active), the `SCHED_OTHER` librespot writer can be delayed long enough to underrun the dmix buffer. Setting `CPUSchedulingPolicy=fifo` and `CPUSchedulingPriority=70` (below statime at 80, above normal) ensures librespot is only preempted by the PTP daemon. The `core` user is already in the `@realtime` PAM group (`rtprio 99`, `memlock unlimited` per Containerfile line 121) so no new capabilities are required.

##### Evidence

``templates/systemd/user/librespot.service` -- no `CPUSchedulingPolicy` line; `Containerfile:116-122` -- `@realtime` group grants rtprio 99; `statime-inferno.service` -- `AmbientCapabilities=CAP_SYS_NICE` confirms RT priority model in use`

---

#### V2-AUD-04 -- iRadio Rubato Resampler `sub_chunks=2` -- Minimum Quality, Audible Aliasing

**Importance:** High  
**Difficulty:** Easy  
**Risk:** Low  
**Prerequisites:** None  

##### Impact

Eliminates audible aliasing artefacts on 44.1->48kHz resampling from common MP3 internet radio sources.

##### Description

`decode.rs` lines 152 and 322 both call `FftFixedIn::<f32>::new(from_rate, to_rate, chunk_size=1024, sub_chunks=2, channels=2)`. Rubato's `sub_chunks` parameter controls the sinc filter quality: `sub_chunks=2` yields ~60 dB stopband attenuation -- broadcast resampling requires >=96 dB (`sub_chunks=8`). At `sub_chunks=4` the improvement is already perceptible (84 dB) with only 4x processing cost. The `chunk_size=1024` is also mismatched: at the 44100/48000 ratio this produces an output chunk of 1088 frames, misaligned with the 4096-frame ALSA period, adding latency jitter from extra accumulation.

##### Evidence

``inferno-iradio/crates/iradio-bridge/src/decode.rs:152` and `:322` -- `FftFixedIn::new(..., 1024, 2, 2)`; rubato crate docs: sub_chunks controls "quality of the filter"`

---

#### V2-AUD-05 -- iRadio ALSA PCM Missing `sw_params` (`start_threshold`/`avail_min` Unset)

**Importance:** High  
**Difficulty:** Easy  
**Risk:** Low  
**Prerequisites:** None  

##### Impact

Eliminates cold-start underruns when the Inferno ALSA plugin begins consuming before the decode pipeline is primed.

##### Description

`InfernoAlsaDevice::open()` in `alsa.rs` configures `hw_params` (channels, rate, format, access, buffer_size) but calls no `sw_params` on the PCM handle. The ALSA default `start_threshold` is 1 period, meaning the Inferno plugin starts consuming audio after a single write. With the decode channel capped at 4 periods (mpsc::channel capacity 4) and the slot keeper potentially mid-write of a silence period, the plugin may see an immediate underrun before the decode pipeline has produced its second period. Setting `start_threshold = buffer_frames` and `avail_min = period_size` ensures the buffer is at least half-full before playback begins.

##### Evidence

``inferno-iradio/crates/iradio-bridge/src/alsa.rs:17-33` -- hw_params configured, no `pcm.sw_params()` call; `decode.rs:259` -- `mpsc::channel::<Vec<i32>>(4)``

---

#### V2-AUD-06 -- iRadio Pre-Roll Buffer Threshold 8KB Causes Decoder Starvation

**Importance:** Medium  
**Difficulty:** Easy  
**Risk:** Low  
**Prerequisites:** None  

##### Impact

Prevents silence gaps at the start of every iRadio session on streams slower than 400kbps.

##### Description

`player.rs:110` waits until `buffer.len() >= 8 * 1024` (8KB) before starting the symphonia streaming decoder. At 128 kbps, 8KB = ~0.5s of compressed audio -- barely enough to decode one ALSA period (16KB of decoded i32 samples). On 64 kbps stations (common DAB simulcasts) this is even more marginal. The decode pipeline starves within milliseconds of starting, injecting silence gaps at the beginning of every iRadio session. The `RING_BUFFER_CAPACITY` is 512KB and the 5-second startup deadline is generous; the threshold should be at least 64KB (~4s at 128 kbps).

##### Evidence

``inferno-iradio/crates/iradio-bridge/src/player.rs:110` -- `if buffer.lock().unwrap().len() >= 8 * 1024`; `stream.rs:8` -- `RING_BUFFER_CAPACITY: usize = 512 * 1024``

---

#### V2-AUD-07 -- No ALSA Xrun Telemetry in Node-Agent Metrics/Health

**Importance:** Medium  
**Difficulty:** Easy  
**Risk:** Low  
**Prerequisites:** None  

##### Impact

Makes audio dropout events visible to the monitoring stack rather than invisible while CPU/PTP dashboards show flat lines.

##### Description

`metrics.py` exposes CPU%, memory, disk, uptime, PTP offset, and net bytes -- nothing about the audio pipeline. ALSA xrun (underrun + overrun) counts are available per-substream at `/proc/asound/card10/pcm{0,1}{p,c}/sub0/status` (field `xruns`). Card 10 is `snd-aloop` at `index=10`, pinned in `/etc/modprobe.d/snd-aloop.conf`, so the path is stable. Reading these files requires no root privileges. Exposing `alsa_xruns_total` in `/metrics` gives `inferno-central` INT-1 a concrete audio quality signal for trending and alerting.

##### Evidence

``inferno_node_agent/routes/metrics.py` -- no `/proc/asound` reference; `Containerfile:96` -- `echo "options snd-aloop index=10"` makes card number stable`

---

#### V2-AUD-08 -- statime PTP Intervals Not Tuned to Dante/AES67 Profile

**Importance:** Medium  
**Difficulty:** Medium  
**Risk:** Medium  
**Prerequisites:** None  

##### Impact

Ensures Dante holdover does not trigger during grandmaster events, preventing crackling audio before re-sync.

##### Description

`inferno-ptpv1.toml` contains no `log-sync-interval`, `log-announce-interval`, `log-min-delay-req-interval`, or `announce-receipt-timeout` fields -- statime inherits compiled defaults. Dante's AES67 implementation (confirmed in Shure MXWANI8 documentation) expects: sync messages at 8/s (`logSyncInterval = -3`), announce messages at 1/s (`logAnnounceInterval = 0`), holdover timeout of 3 announce periods = 3s. If statime's compiled default sync interval is the IEEE 1588 default (1/s, `logSyncInterval=0`), the MXWANI8 will tolerate it but takes longer to converge and is more sensitive to network jitter. Both intervals should be explicitly set in the TOML template rather than relying on library defaults.

##### Evidence

``templates/inferno-ptpv1.toml` -- only loglevel, sdo-id, domain, priority1, virtual-system-clock, usrvclock-export, interface, network-mode, protocol-version; no interval fields present`

---

#### V2-AUD-09 -- iRadio Slot Keeper No Runtime ALSA Re-Open After Plugin Failure

**Importance:** Medium  
**Difficulty:** Medium  
**Risk:** Low  
**Prerequisites:** None  

##### Impact

Recovers iRadio audio automatically after Inferno ALSA plugin crash without requiring manual service restart.

##### Description

`slot_keeper.rs:38-46` contains a startup retry loop for ALSA open. Once `InfernoAlsaDevice` is opened, the running loop at lines 49-67 calls `write_frames()` or `write_silence()`, but on failure the error is silently discarded (`let _ = alsa.write_frames(&samples)`). In `alsa.rs`, `write_frames()` calls `pcm.recover()` for EPIPE (underrun) but not for `ENODEV`/`EIO` (plugin socket closed, Dante gone). When the Inferno plugin's UNIX domain socket disappears (e.g. plugin process restart), the PCM enters an unrecoverable error state and the slot keeper silently writes nothing. Fix: on any write error that survives `recover()`, drop the `InfernoAlsaDevice`, sleep 3s, and re-open -- the same retry pattern already used at startup.

##### Evidence

``inferno-iradio/crates/iradio-bridge/src/slot_keeper.rs:38-46` -- startup retry; lines 49-67 -- runtime loop with silently discarded errors; `alsa.rs:43-58` -- `recover()` only handles EPIPE`

---

#### V2-AUD-10 -- librespot `--normalisation` Absent -- +/-20 LU Track Level Variation into Dante

**Importance:** Medium  
**Difficulty:** Easy  
**Risk:** Low  
**Prerequisites:** None  

##### Impact

Provides broadcast-consistent output levels into the Inferno plugin, preventing clipping on loud tracks and inaudible quiet on low-normalised tracks.

##### Description

`librespot.service` has `--volume-ctrl log --initial-volume 50` but no `--normalisation` flag. Spotify encodes ReplayGain-compatible normalisation metadata in its stream; librespot can apply this at decode time via `--normalisation auto`. Without it, raw encoder output levels reach the Inferno ALSA plugin: a pop/EDM track encoded at -1 dBFS and a classical track encoded at -18 dBFS both pass through at their original levels, producing 17 dB level difference at the MXWANI8 input. Adding `--normalisation auto --normalisation-method album --normalisation-pregain -1.0` (1 dB safety headroom) provides broadcast-consistent output levels with no latency penalty.

##### Evidence

``templates/systemd/user/librespot.service:11-27` -- `--volume-ctrl log --initial-volume 50` present; no `--normalisation` flag anywhere; `asoundrc.spotify:42-49` -- no gain stage between librespot and Dante TX`

---



## Cockpit UI & Operations

Issues found by auditing the cockpit-inferno JS source and iRadio web UI. V2-OPS-05 is a confirmed silent runtime bug affecting all non-Spotify deployments.

### Summary

| ID | Title | Importance | Difficulty | Risk | Prerequisites |
|---|---|---|---|---|---|
| V2-OPS-01 | Embed iRadio Playback Controls Inline in Cockpit | High | Medium | Low | None |
| V2-OPS-02 | Spotify Connect Account Link Status in Cockpit | High | Medium | Low | None |
| V2-OPS-03 | PTP Jitter, Variance, and Mean Offset Metrics in Performance Panel | High | Easy | Low | None |
| V2-OPS-04 | iRadio Custom Stream URL Pre-play Validation and Reachability Probe | Medium | Easy | Low | None |
| V2-OPS-05 | `restartAll()` Bug -- `AUX_SVCS` Undefined, Non-Spotify Modes Silently Skip Restart | Critical | Easy | Low | None |
| V2-OPS-06 | Dante Network Pre-flight Checks: Multicast, MTU, Link Speed, IP Conflict | High | Medium | Low | None |
| V2-OPS-07 | Mode-Switch Audio Interruption Warning with Active Service Inventory | High | Easy | Low | None |
| V2-OPS-08 | Post-Reboot Reconnect Countdown for Reboot and Re-deploy Actions | Medium | Easy | Low | None |
| V2-OPS-09 | ALSA XRUN Counter on Health Dashboard | Medium | Easy | Low | None |
| V2-OPS-10 | Fleet Peer Discovery -- Show Other Inferno Nodes via Dante mDNS | Medium | Medium | Low | None |

---

#### V2-OPS-01 -- Embed iRadio Playback Controls Inline in Cockpit

**Importance:** High  
**Difficulty:** Medium  
**Risk:** Low  
**Prerequisites:** None  

##### Impact

Eliminates the UX dead-end where iRadio mode users must leave Cockpit to manage streams via a separate browser tab.

##### Description

When mode is "iradio", the Cockpit Config panel renders only an `<a href="http://<node-ip>:6100">` hyperlink pointing to the standalone iradio-bridge web UI. The `cockpit-inferno` plugin makes zero API calls to the iradio-bridge REST endpoints (`/api/v1/players`, `/api/v1/health`) -- there is no embedded player status, no start/stop controls, and no "now playing" indicator within Cockpit. The iradio-bridge API is fully RESTful and same-origin-accessible via `cockpit.spawn()` or local `fetch()`. A compact player strip mirroring what `iradio-bridge`'s own `web-ui/app.js` renders should be embedded directly on the Monitoring or Services tab when iradio-bridge is active, with per-slot stop buttons and state badges -- no page-leave required.

##### Evidence

``cockpit-inferno/src/inferno.js:240-244` -- the only iRadio UI interaction is setting `iradio-ui-link.href`; no `fetch()` call to iradio-bridge API anywhere in the 2661-line file`

---

#### V2-OPS-02 -- Spotify Connect Account Link Status in Cockpit

**Importance:** High  
**Difficulty:** Medium  
**Risk:** Low  
**Prerequisites:** None  

##### Impact

Gives operators visibility into whether librespot is authenticated to Spotify, preventing silent no-audio failures.

##### Description

The Cockpit Config panel exposes only the Spotify device name; it does not surface whether librespot has a cached Zeroconf token or is in unauthenticated mode. The System Info table infers playback state by brittle journal regex (`/Loading track|Playing|Paused/`) rather than querying a structured source. The bitrate and normalisation fields are permanently disabled in the UI (`inferno.js:167-170`) with no explanation on the form. The librespot cache directory contains a `credentials.json` whose existence indicates a linked account -- safely surfaceable as "linked / not linked" without exposing credentials. Structured playback state is available via librespot's `--onevent` hook or by parsing `~/.cache/librespot/audio_quality.json`.

##### Evidence

``cockpit-inferno/src/inferno.js:1243-1258` -- Spotify status uses `lsLog.match(/Loading track|Playing|Paused/)` on raw journal text; lines 163-170 -- bitrate/normalisation fields force-disabled`

---

#### V2-OPS-03 -- PTP Jitter, Variance, and Mean Offset Metrics in Performance Panel

**Importance:** High  
**Difficulty:** Easy  
**Risk:** Low  
**Prerequisites:** None  

##### Impact

Provides quantitative clock quality numbers (jitter sigma, peak-to-peak) needed for Dante AoIP reliability assessment.

##### Description

The PTP Performance card displays instantaneous offset and state only. It does not calculate standard deviation (jitter), peak-to-peak range, or mean offset -- even though all historical samples are already accumulated in the `_ptpHistory` array (up to 900 points = ~15 minutes). Dante AoIP tolerates short offset spikes but fails on sustained high jitter; a sigma > 5 µs sustained for >30s is a practical failure threshold the current sparkline cannot convey. The grandmaster field renders raw bytes with no human-readable resolution. All required data is in-memory; this is a pure computation + display addition requiring no new data sources.

##### Evidence

``cockpit-inferno/src/inferno.js:48-50` -- `_ptpHistory` and `_ptpTimes` arrays maintained; lines 1498-1505 -- `ptpStatUpdate` shows only State/Offset/Grandmaster/Clock; `renderPtpLiveSVG()` uses array for drawing but computes no statistics`

---

#### V2-OPS-04 -- iRadio Custom Stream URL Pre-play Validation and Reachability Probe

**Importance:** Medium  
**Difficulty:** Easy  
**Risk:** Low  
**Prerequisites:** None  

##### Impact

Prevents silent buffering-forever failures when operators enter malformed or unreachable stream URLs.

##### Description

The iRadio Quick Play form validates only that the URL field is non-empty before calling `startStation()`. No scheme check, no hostname resolution, no HTTP HEAD probe for content-type (`audio/mpeg`, `audio/aac`, `application/ogg`). When an invalid URL is submitted, the player transitions to `state="error"` with an error string exposed only inside the standalone web UI -- not surfaced at all in the Cockpit plugin. The iradio-bridge `PlayerInfo` struct already carries an `error: Option<String>` field; the Cockpit embedded player strip (V2-OPS-01) would naturally surface it if it polled the API.

##### Evidence

``inferno-iradio/web-ui/app.js:181` -- only validation is empty-string check; `state.rs:46-56` -- `PlayerState::Error` and `error: Option<String>` exist but Cockpit never reads them`

---

#### V2-OPS-05 -- `restartAll()` Bug -- `AUX_SVCS` Undefined, Non-Spotify Modes Silently Skip Restart

**Importance:** Critical  
**Difficulty:** Easy  
**Risk:** Low  
**Prerequisites:** None  

##### Impact

Fixes confirmed silent runtime bug where "Restart All" on the Services tab does nothing useful for aux-in, aux-out, aux-bidir, or iradio modes.

##### Description

`restartAll()` at `inferno.js:1102` uses `currentMode === "spotify" ? SPOTIFY_SVCS : AUX_SVCS`, but `AUX_SVCS` is not declared anywhere in the file. The defined constants are `AUX_IN_SVCS`, `AUX_OUT_SVCS`, `AUX_BIDIR_SVCS`, `ALL_AUX_SVCS`, and `IRADIO_SVCS`. JavaScript resolves the undeclared variable to `undefined`; `spUser("systemctl --user restart undefined")` produces an error caught and discarded silently. The fix is a one-liner: replace `AUX_SVCS` with `modeToSvcs(currentMode)`, the correctly-implemented helper at line 933-943 that already handles all five modes.

##### Evidence

``cockpit-inferno/src/inferno.js:1102` -- `AUX_SVCS` referenced but has zero `const`/`let`/`var` declarations in 2661-line file (confirmed by full-file grep); `modeToSvcs()` at line 933 is correctly implemented and already used by `activeSvcs()``

---

#### V2-OPS-06 -- Dante Network Pre-flight Checks: Multicast, MTU, Link Speed, IP Conflict

**Importance:** High  
**Difficulty:** Medium  
**Risk:** Low  
**Prerequisites:** None  

##### Impact

Catches the four most common field-deployment network failures before operators spend hours tracing audio dropouts.

##### Description

The Health Check panel (`HC_CHECKS` array, lines 1531-1537) checks only: snd-aloop loaded, PTP locked, services active, disk < 80%, NIC has IP. It does not check: (1) multicast routing -- Dante uses `239.255.x.x/24`; IGMP snooping misconfiguration silently drops all audio; (2) MTU -- high channel-count Dante (>8ch) requires jumbo frames (>=4096 bytes); (3) link speed -- Dante requires >=100 Mbps; a 10 Mbps negotiation causes packet loss; (4) IP address conflict -- duplicate IP causes intermittent subscription failures. All four checks can be implemented with `ip link`, `ethtool`, `ping -I <nic> 239.255.0.1 -c 1`, and `arping`. `scripts/probe-node.sh` already implements hardware-timestamping and link-state checks at install time.

##### Evidence

``cockpit-inferno/src/inferno.js:1531-1537` -- 7 HC_CHECKS, none cover multicast, MTU, link speed, or ARP conflict; `scripts/probe-node.sh:79-100` -- link-state check already implemented at install time`

---

#### V2-OPS-07 -- Mode-Switch Audio Interruption Warning with Active Service Inventory

**Importance:** High  
**Difficulty:** Easy  
**Risk:** Low  
**Prerequisites:** None  

##### Impact

Prevents accidental live-broadcast interruptions when an operator saves a mode change without realising active streams will be hard-stopped.

##### Description

`saveConfig()` shows a "Preview Changes" diff modal before applying, but the diff only shows changed config key-value pairs -- it does not warn that currently-active audio services will be stopped. Lines 897-900 stop all services unconditionally on mode change. In iRadio mode, stopping `iradio-bridge` terminates all active Dante TX flows without notice to downstream receivers. The diff modal needs a prominent banner when `INFERNO_MODE` changes and services are running: e.g. "Mode change will stop: librespot, inferno-bridge (currently active)" -- checking current service states before showing the modal.

##### Evidence

``cockpit-inferno/src/inferno.js:897-900` -- `stopSvcs = SPOTIFY_SVCS.concat(ALL_AUX_SVCS).concat(IRADIO_SVCS)` unconditional; line 2124 -- diff modal shows only config diffs, no service-impact warning`

---

#### V2-OPS-08 -- Post-Reboot Reconnect Countdown for Reboot and Re-deploy Actions

**Importance:** Medium  
**Difficulty:** Easy  
**Risk:** Low  
**Prerequisites:** None  

##### Impact

Prevents operators from assuming the appliance crashed when it is simply rebooting after a manually triggered action.

##### Description

`triggerReboot()` and `triggerRedeploy()` (inferno.js lines 1828-1842) use native `window.confirm()` dialogs (browser-styled, inconsistent with Cockpit design) and then emit a short toast before the session goes dark. There is no post-reboot countdown, no polling for reconnect, and no automatic page refresh when the node comes back. The iot-updater `IMPROVEMENTS.md` item H-6 identifies the same gap for OTA reboots. A 30-second countdown overlay polling `cockpit.spawn(["hostname"])` every 2s and auto-refreshing on success is the standard fix.

##### Evidence

``cockpit-inferno/src/inferno.js:1828` -- native browser `confirm()` used; line 1837 -- same for reboot; lines 1839-1842 -- only toast shown, no reconnect polling`

---

#### V2-OPS-09 -- ALSA XRUN Counter on Health Dashboard

**Importance:** Medium  
**Difficulty:** Easy  
**Risk:** Low  
**Prerequisites:** None  

##### Impact

Shows the single most direct indicator of audio glitches in the health dashboard without requiring SSH access to /proc.

##### Description

ALSA exposes per-device underrun/overrun counts at `/proc/asound/card*/pcm*/sub*/status` (field `xruns:`). Every underrun on the loopback device (snd-aloop) results in a silence gap or click in the transmitted Dante audio. The Cockpit health check currently has no visibility into XRUN counts. Reading `/proc/asound/*/pcm*/sub*/status` via `cockpit.file()` is non-privileged and cheap. A health check row "ALSA XRUNs: 0 (pass)" vs "ALSA XRUNs: 47 on snd-aloop (warn)" would be high diagnostic value. Notably, `scripts/bench/alsa-health.sh` already reads XRUN counts -- the logic just needs to be called from `runHealthChecks()`.

##### Evidence

``cockpit-inferno/src/inferno.js` HC_CHECKS (lines 1531-1537) -- no `/proc/asound` reference beyond snd-aloop presence check; `scripts/bench/alsa-health.sh` -- already reads XRUN counts, not surfaced in UI`

---

#### V2-OPS-10 -- Fleet Peer Discovery -- Show Other Inferno Nodes via Dante mDNS

**Importance:** Medium  
**Difficulty:** Medium  
**Risk:** Low  
**Prerequisites:** None  

##### Impact

Enables multi-node navigation directly from a single Cockpit pane without maintaining a separate node IP spreadsheet.

##### Description

The Dante Discovery panel already scans `avahi-browse -rp _netaudio-arc._udp` and builds a table of all Dante devices (name, IP, hostname). Devices whose name starts with `Inferno-` (matching the `INFERNO_DANTE_NAME` pattern auto-generated from MAC) are other Virgil appliances running `cockpit-inferno` on port 9090. The discovery table currently shows only static text with no action buttons. Adding an "Open Cockpit" link for Inferno-prefixed peers and a "Probe" button that reads the peer's image version gives multi-node operational awareness at near-zero backend cost.

##### Evidence

``cockpit-inferno/src/inferno.js:1692-1713` -- Dante scan builds `devices[]` array but renders only static text spans; `architecture.md:54` -- Inferno device name pattern is `"Inferno-" + MAC_SUFFIX``

---



## Build Pipeline & Deployment

Issues found by auditing the build scripts, Containerfile, GitHub Actions workflows, and OTA updater. Focus on reproducibility, supply chain, and reliability.

### Summary

| ID | Title | Importance | Difficulty | Risk | Prerequisites |
|---|---|---|---|---|---|
| V2-BLD-01 | No CI/CD Pipeline -- Container and ISO Build Is Entirely Manual | High | Hard | Low | None |
| V2-BLD-02 | bootc-image-builder Pulled as `:latest` -- Build Tool Version Unpinned | Medium | Easy | Low | None |
| V2-BLD-03 | Containerfile Downloads Binaries from `releases/latest` -- Non-Deterministic Builds | High | Easy | Medium | None |
| V2-BLD-04 | Rust Toolchain Pinned to `@stable` -- Silent Toolchain Upgrades | Medium | Easy | Medium | None |
| V2-BLD-05 | No SBOM Generation or Vulnerability Scan in Build Pipeline | Medium | Medium | Low | None |
| V2-BLD-06 | All RPM Packages Unpinned in Containerfile -- Non-Reproducible dnf Installs | Medium | Hard | Medium | None |
| V2-BLD-07 | No Ignition Placeholder Substitution Script -- Manual Error-Prone Provisioning | Medium | Easy | Medium | None |
| V2-BLD-08 | OTA Upload No Chunk-Resume Across Sidecar Restarts | Medium | Medium | Low | None |
| V2-BLD-09 | No Automated Post-Build Container Smoke Test | High | Medium | Low | None |
| V2-BLD-10 | `podman build` Lacks `--pull=newer` -- Base Image Can Be Silently Stale | High | Easy | Low | None |

---

#### V2-BLD-01 -- No CI/CD Pipeline -- Container and ISO Build Is Entirely Manual

**Importance:** High  
**Difficulty:** Hard  
**Risk:** Low  
**Prerequisites:** None  

##### Impact

Prevents broken Containerfiles or config.toml changes from shipping undetected without any automated gate.

##### Description

The `nightly-build.yml` workflow only compiles Rust binaries and uploads them as a GitHub Release asset. `podman build`, BIB ISO generation, `.iotupdate` bundle packaging, and Proxmox SCP are all manual steps run on COPILOT-BUILD-01 via `build-release.sh`. A broken Containerfile can ship undetected until a human fires the script. Adding a GitHub Actions workflow triggered on version tags or `workflow_dispatch` to execute `build-release.sh` on a self-hosted runner on COPILOT-BUILD-01 would close this gap and provide a complete audit trail for every release.

##### Evidence

``.github/workflows/nightly-build.yml` -- zero podman/BIB steps; `build/build-release.sh:8` -- "Runs on COPILOT-BUILD-01 ... Trigger remotely via: inferno-build <version>"`

---

#### V2-BLD-02 -- bootc-image-builder Pulled as `:latest` -- Build Tool Version Unpinned

**Importance:** Medium  
**Difficulty:** Easy  
**Risk:** Low  
**Prerequisites:** None  

##### Impact

Guarantees identical ISO output regardless of when the build runs by pinning the BIB version.

##### Description

`build-release.sh` pulls `ghcr.io/osbuild/bootc-image-builder:latest` on every run. BIB is under active development and has made breaking changes to `config.toml` schema and output directory layout between minor versions. Pinning to a specific digest (e.g. `ghcr.io/osbuild/bootc-image-builder@sha256:<digest>`) or a versioned tag guarantees identical ISO output. The digest should be updated intentionally via a scheduled dependency-bump commit, not silently on every build.

##### Evidence

``build/build-release.sh:83` -- `ghcr.io/osbuild/bootc-image-builder:latest``

---

#### V2-BLD-03 -- Containerfile Downloads Binaries from `releases/latest` -- Non-Deterministic Builds

**Importance:** High  
**Difficulty:** Easy  
**Risk:** Medium  
**Prerequisites:** None  

##### Impact

Establishes image provenance -- two builds of the same Git commit on different days can silently embed different binaries.

##### Description

The `RELEASES_URL` ARG in the Containerfile defaults to `.../releases/latest/download`, meaning the nightly workflow publishes a new binary tarball every morning and any subsequent image build silently picks it up without a version gate. Fix: require an explicit `--build-arg RELEASES_URL=.../releases/download/<tag>` in `build-release.sh`, and fail the build if the ARG is at its default value. The nightly workflow already outputs the tag name in `$GITHUB_OUTPUT`; `build-release.sh` just needs to consume it.

##### Evidence

``Containerfile:172` -- `ARG RELEASES_URL=https://github.com/legopc/inferno-aoip-releases/releases/latest/download``

---

#### V2-BLD-04 -- Rust Toolchain Pinned to `@stable` -- Silent Toolchain Upgrades

**Importance:** Medium  
**Difficulty:** Easy  
**Risk:** Medium  
**Prerequisites:** None  

##### Impact

Prevents silent Rust version changes from changing binary behaviour or introducing new glibc dependencies.

##### Description

`nightly-build.yml` uses `dtolnay/rust-toolchain@stable` with no version override. A new Rust stable release with changed optimisation defaults or a breaking `feature` flag can silently change binaries. Adding a `rust-toolchain.toml` file at the repo root specifying `channel = "1.82.0"` (or current tested version) which `dtolnay/rust-toolchain` automatically respects pins the toolchain explicitly. This should be bumped deliberately via a dependency-update PR.

##### Evidence

``nightly-build.yml:25` -- `uses: dtolnay/rust-toolchain@stable` with no `toolchain:` version key`

---

#### V2-BLD-05 -- No SBOM Generation or Vulnerability Scan in Build Pipeline

**Importance:** Medium  
**Difficulty:** Medium  
**Risk:** Low  
**Prerequisites:** None  

##### Impact

Provides machine-readable inventory of packages, Rust crates, and RPMs for CVE audits and supply-chain compliance.

##### Description

Neither the nightly binary workflow nor `build-release.sh` generates a CycloneDX or SPDX SBOM. No Grype/Trivy/Syft step exists anywhere in the pipeline. For a network-attached appliance with Cockpit (Node/Python), avahi, net-snmp, and multiple Rust binaries, the attack surface is non-trivial. Adding `anchore/syft-action` (SBOM) and `anchore/scan-action` (Grype CVE scan) as post-build steps takes under 20 lines of YAML and provides immediate auditability. The OCI image SBOM should also be attached as an OCI annotation via `cosign attach sbom`.

##### Evidence

``nightly-build.yml:207` -- `generate_release_notes: false`; no syft/trivy/grype step anywhere in pipeline or Containerfile`

---

#### V2-BLD-06 -- All RPM Packages Unpinned in Containerfile -- Non-Reproducible dnf Installs

**Importance:** Medium  
**Difficulty:** Hard  
**Risk:** Medium  
**Prerequisites:** None  

##### Impact

Prevents silent Fedora package updates from changing appliance behaviour between builds and enables regression bisection.

##### Description

The `dnf install -y` block lists ~20 packages with no version constraints (`cockpit-ws`, `alsa-lib`, `net-snmp`, `bsdiff`). Fedora's fast release cadence means these change weekly. The preferred mitigation for bootc images is (a) `dnf4 versionlock add` to capture current NVRs into a committed lockfile, or (b) use a Fedora compose snapshot as the repo source. A lighter-weight first step: run `rpm -qa --qf "%{NAME}-%{VERSION}-%{RELEASE}"` at build end and commit the output as `build/rpm-manifest.txt`, providing a post-hoc audit trail.

##### Evidence

``Containerfile:34-67` -- `dnf install -y cockpit-ws cockpit-system alsa-lib net-snmp bsdiff ...` -- no version specifiers on any package`

---

#### V2-BLD-07 -- No Ignition Placeholder Substitution Script -- Manual Error-Prone Provisioning

**Importance:** Medium  
**Difficulty:** Easy  
**Risk:** Medium  
**Prerequisites:** None  

##### Impact

Eliminates risk of deploying nodes with literal placeholder strings (`INFERNO_CORE_PASSWORD_HASH`) as passwords.

##### Description

`ignition/inferno-template.bu` documents three string placeholders (`INFERNO_CORE_PASSWORD_HASH`, `INFERNO_SSH_KEY_RSA`, `INFERNO_SSH_KEY_ED25519`) that "must be replaced per-deployment," but there is no companion `prepare-ignition.sh` that takes these as arguments and produces a ready-to-serve `inferno-node.ign`. A minimal script using `envsubst` + `butane` would eliminate the manual step, allow scripting into the Proxmox VM creation hook, and make SSH key rotation trivial across all future nodes.

##### Evidence

``ignition/inferno-template.bu:12-15` -- "Placeholders that must be replaced per-deployment... INFERNO_CORE_PASSWORD_HASH... INFERNO_SSH_KEY_RSA..."; no `prepare-ignition.sh` anywhere in repo`

---

#### V2-BLD-08 -- OTA Upload No Chunk-Resume Across Sidecar Restarts

**Importance:** Medium  
**Difficulty:** Medium  
**Risk:** Low  
**Prerequisites:** None  

##### Impact

Avoids restarting a 2GB upload from byte 0 on sidecar crash or slow management network disconnection.

##### Description

`server.py:637` unconditionally calls `BUNDLE_PATH.unlink(missing_ok=True)` in `_handle_upload_start()`, clearing any partial upload. The in-memory `_state["stage"]` is reset to `"idle"` on every server restart. There is no persisted chunk-index manifest. Adding a `upload-state.json` recording `{bytes_received, total_chunks, sha256_so_far}` would allow a reconnecting client to query `/upload/resume-info` and re-send only the missing tail -- a standard Range-request pattern supported by Cockpit's XHR stack.

##### Evidence

``iot-updater/sidecar/server.py:637` -- `BUNDLE_PATH.unlink(missing_ok=True)` in `_handle_upload_start`; line 665 -- chunk appended with mode `"ab"` but no state file written to disk`

---

#### V2-BLD-09 -- No Automated Post-Build Container Smoke Test

**Importance:** High  
**Difficulty:** Medium  
**Risk:** Low  
**Prerequisites:** None  

##### Impact

Catches broken `systemctl enable` layers or missing unit files before the ISO is deployed to hardware.

##### Description

`build-release.sh` goes straight from `podman build` to BIB ISO generation with no lint or smoke step. A minimal smoke test using `podman run --rm inferno-appliance:<version> systemctl list-unit-files --state=enabled` can verify expected services are enabled. `bootc container lint` (shipped with bootc >= 0.1.14) checks for bootc-specific errors such as content in `/var/` that should be in `/usr/`, files with wrong SELinux labels, and missing `sysusers.d` definitions -- all without booting a VM.

##### Evidence

``build/build-release.sh:62-66` -- `podman build` immediately followed by BIB ISO step with no intermediate lint/smoke; `nightly-build.yml` has no `podman run` step`

---

#### V2-BLD-10 -- `podman build` Lacks `--pull=newer` -- Base Image Can Be Silently Stale

**Importance:** High  
**Difficulty:** Easy  
**Risk:** Low  
**Prerequisites:** None  

##### Impact

Ensures `fedora-bootc:43` security patches are included in every build without manual pull intervention.

##### Description

`build-release.sh` invokes `podman build` without `--pull=newer` (or `--pull=always`). Podman's default is `--pull=missing` -- it uses a locally cached base image if present. On a long-lived build VM, `fedora-bootc:43` can be months out of date while the build reports success. For an appliance deployed on broadcast networks with a default password, running stale base images with known CVEs is a meaningful supply-chain risk. Adding `--pull=newer` costs only the time to compare the remote digest against the local one and pulls updated layers only when the upstream image actually changes.

##### Evidence

``build/build-release.sh:61-66` -- `podman build --network=host -t "inferno-appliance:..."` with no `--pull` flag`

---



## Ecosystem Integration

Issues found by auditing inferno-node-agent, inferno-central, and dante-patchbox integration points. Focus on closing integration gaps that block inferno-central INT-1 through INT-4.

### Summary

| ID | Title | Importance | Difficulty | Risk | Prerequisites |
|---|---|---|---|---|---|
| V2-ECO-01 | mDNS TXT Key Mismatch -- `device=` Published, `device_name=` Read | High | Easy | Low | None |
| V2-ECO-02 | Virgil Has No Avahi Service File Template -- mDNS Bootstrap Paradox | High | Medium | Low | None |
| V2-ECO-03 | No `/dante` Endpoint on Node-Agent -- Minos Cannot Auto-Discover Source Metadata | High | Easy | Low | None |
| V2-ECO-04 | `/health` Missing `dante_connected` Flag -- Service Active != Dante on Network | High | Easy | Low | None |
| V2-ECO-05 | ALSA Xrun Counters Absent from `/metrics` -- Audio Dropout Events Invisible to Central | High | Easy | Low | None |
| V2-ECO-06 | No Prometheus Text-Format Scrape Endpoint on Node-Agent | Medium | Easy | Low | V2-ECO-05 |
| V2-ECO-07 | Mode Switch via `PUT /config` Restarts Only `inferno-bridge` -- Source Services Not Transitioned | High | Medium | Medium | None |
| V2-ECO-08 | Token Bootstrap Relies on Hardcoded SSH Password -- Breaks If Default Changed | High | Medium | Low | None |
| V2-ECO-09 | No Self-Registration Service -- Nodes Cannot Push Identity to inferno-central | Medium | Medium | Low | None |
| V2-ECO-10 | No Push Alerting on Critical Service Failure -- All Monitoring Is Pull-Only | Medium | Medium | Low | V2-ECO-09 |

---

#### V2-ECO-01 -- mDNS TXT Key Mismatch -- `device=` Published, `device_name=` Read

**Importance:** High  
**Difficulty:** Easy  
**Risk:** Low  
**Prerequisites:** None  

##### Impact

Fixes device name always being `None` in the fleet registry, requiring a secondary HTTP round-trip for every node.

##### Description

Virgil's Avahi service file template publishes the TXT record with key `device=` (line 9 of the j2 template). `inferno-central`'s mDNS parser reads `_txt("device_name")` -- a different key. The values never match so `device_name` is always `None` at discovery time. Additionally, the TXT record is missing `dante_name`, `agent_port=8089`, and `tx_channels`, all of which central and Minos need at discovery time without a further HTTP call. Fixing the key to `device_name=` and adding the missing fields is a one-line change in the template.

##### Evidence

``inferno-central/avahi/inferno-aoip.service.j2:9` -- `<txt-record>device={{ device_name }}</txt-record>` (key = `device`); `inferno-central/inferno_central/discovery/mdns.py:107` -- reads key `device_name` -- never matches`

---

#### V2-ECO-02 -- Virgil Has No Avahi Service File Template -- mDNS Bootstrap Paradox

**Importance:** High  
**Difficulty:** Medium  
**Risk:** Low  
**Prerequisites:** None  

##### Impact

Resolves the circular dependency where central needs mDNS to discover nodes but nodes have no Avahi file until central SSH-bootstraps them.

##### Description

`inferno-aoip-releases/templates/` has no avahi directory or `.service` XML file. There is no mechanism for `inferno-configure.sh` to generate `/etc/avahi/services/inferno-aoip.service` with runtime values. `INTEGRATION.md` step 4 requires avahi-daemon to broadcast `_inferno-aoip._udp` before central's SSH bootstrap runs, yet inferno-configure.sh has no Avahi file generation. Add `templates/avahi/inferno-aoip.service.xml` using the `%%INFERNO_NAME%%` substitution pattern already established in `templates/snmpd.conf.template`, and render it from `inferno-configure.sh`.

##### Evidence

``find inferno-aoip-releases/templates/` -- no avahi directory; `INTEGRATION.md:4` -- "If inferno-aoip-releases ships its own Avahi service file..." (conditional implies it doesn't)`

---

#### V2-ECO-03 -- No `/dante` Endpoint on Node-Agent -- Minos Cannot Auto-Discover Source Metadata

**Importance:** High  
**Difficulty:** Easy  
**Risk:** Low  
**Prerequisites:** None  

##### Impact

Allows inferno-central and Minos to auto-populate source labels and channel counts without SSH or manual config edits.

##### Description

The node-agent exposes `/hardware`, `/config`, `/health`, and `/metrics` but nothing that surfaces the Dante-specific identity: `INFERNO_DANTE_NAME`, `INFERNO_TX_CHANNELS`, `INFERNO_RX_CHANNELS`, and per-channel labels. Minos's `config.toml` `sources` array must exactly match the Dante TX device name Virgil advertises on the network. A lightweight `GET /dante` route reading these four fields from `inferno.conf` provides a stable machine-readable contract for Minos and central. This is a pure read endpoint with zero risk.

##### Evidence

``inferno-node-agent/inferno_node_agent/routes/` -- no `dante.py`; `dante-patchbox/config.toml.example` -- `sources = ["Main Bar", "DVS PC", "Podium", "Spare"]` manually configured strings`

---

#### V2-ECO-04 -- `/health` Missing `dante_connected` Flag -- Service Active != Dante on Network

**Importance:** High  
**Difficulty:** Easy  
**Risk:** Low  
**Prerequisites:** None  

##### Impact

Distinguishes true Dante readiness from systemd unit active state, exposing silent audio outages invisible to the fleet dashboard.

##### Description

`health.py` checks `inferno-bridge.service` via `systemctl is-active`, but this confirms only the systemd unit state, not Dante network registration. `inferno-bridge` waits for `/tmp/ptp-usrvclock` to exist before starting the audio path (`ExecStartPre=/bin/sh -c 'while [ ! -S /tmp/ptp-usrvclock ]; do sleep 1; done'`). A `dante_connected: bool` field in `/health` should check: (1) `/tmp/ptp-usrvclock` socket exists, (2) `statime-inferno.service` is active. Minos already exposes an equivalent field (`dante_connected` in `api.rs:148`) -- Virgil needs parity.

##### Evidence

``inferno_node_agent/routes/health.py` -- `_get_service_statuses()` checks `inferno-bridge.service` only; `inferno-bridge.service` ExecStartPre checks for `/tmp/ptp-usrvclock` socket; `dante-patchbox/crates/patchbox/src/api.rs:148` -- `HealthDante.connected` field`

---

#### V2-ECO-05 -- ALSA Xrun Counters Absent from `/metrics` -- Audio Dropout Events Invisible to Central

**Importance:** High  
**Difficulty:** Easy  
**Risk:** Low  
**Prerequisites:** None  

##### Impact

Gives inferno-central INT-1 a concrete audio quality signal for trending and alerting instead of binary up/down state.

##### Description

`metrics.py` returns CPU%, memory, disk, uptime, PTP offset, and net bytes. Audio health is entirely absent. ALSA xrun counts are available per-substream at `/proc/asound/card10/pcm{0,1}{p,c}/sub0/status` (field `xruns`). Exposing these as `alsa_xruns: {card_index: 10, playback_xruns: N, capture_xruns: N}` in `/metrics` gives inferno-central INT-1 a concrete audio quality signal. `inferno-central/ROADMAP.md` INT-1 explicitly plans to "surface per-metric history... CPU, memory, and audio-path metrics" -- but the audio-path metric has no data source on the node side.

##### Evidence

``inferno_node_agent/routes/metrics.py` -- audio metrics absent; `inferno-central/ROADMAP.md` INT-1 -- "granular... audio-path metrics" planned but no node source exists`

---

#### V2-ECO-06 -- No Prometheus Text-Format Scrape Endpoint on Node-Agent

**Importance:** Medium  
**Difficulty:** Easy  
**Risk:** Low  
**Prerequisites:** V2-ECO-05  

##### Impact

Enables direct Grafana scraping of each node and feeds inferno-central MT-1 without a JSON-to-Prometheus conversion layer.

##### Description

`metrics.py` returns a JSON dict, not Prometheus exposition format. `inferno-central` MT-1 plans to expose `/metrics` in Prometheus format but must convert all node metrics from JSON, adding a translation layer with potential field mapping bugs. A `GET /metrics/prometheus` handler emitting standard `# HELP / # TYPE / metric_name{label=...} N` lines for CPU, memory, disk, PTP offset, xruns, and net counters allows direct Grafana scraping and eliminates the conversion layer. The Python `prometheus-client` package reduces implementation to ~15 lines.

##### Evidence

``inferno_node_agent/routes/metrics.py` -- returns `dict[str, Any]` JSON; `inferno-central/ROADMAP.md` MT-1 -- Prometheus endpoint planned, currently requires JSON-to-Prometheus conversion`

---

#### V2-ECO-07 -- Mode Switch via `PUT /config` Restarts Only `inferno-bridge` -- Source Services Not Transitioned

**Importance:** High  
**Difficulty:** Medium  
**Risk:** Medium  
**Prerequisites:** None  

##### Impact

Fixes broken mode transitions where librespot stays running after switch to iradio mode and vice versa.

##### Description

`config.py` `_restart_service()` calls only `systemctl restart inferno-bridge.service` after a config PUT. A mode transition involves multiple user services: `spotify` mode needs `librespot` + `inferno-keepalive`; `iradio` mode needs `inferno-iradio` + `inferno-aux-keepalive`. None of these are started or stopped by the current restart logic. `services.py` defines all mode services in `USER_SERVICES` but there is no `POST /mode/{mode}` endpoint that atomically stops current-mode services, updates `inferno.conf`, and starts new-mode services. `inferno-central` MT-3 bulk config push is blocked without this.

##### Evidence

``inferno_node_agent/routes/config.py:122-123` -- only `systemctl restart inferno-bridge.service`; `services.py` USER_SERVICES includes all mode services but none touched on config change; no `/mode` route in any routes file`

---

#### V2-ECO-08 -- Token Bootstrap Relies on Hardcoded SSH Password -- Breaks If Default Changed

**Importance:** High  
**Difficulty:** Medium  
**Risk:** Low  
**Prerequisites:** None  

##### Impact

Allows nodes with non-default SSH passwords to be bootstrapped into inferno-central without silent failure.

##### Description

`bootstrap.py:31` uses `password = ssh_password or "inferno123"`. When bootstrap fails with `PermissionDenied`, it logs a warning and returns `None` -- the node stays in the registry without a token and falls back to degraded SSH-only management permanently. Fix: expose a `POST /bootstrap` endpoint on the node-agent, unauthenticated but rate-limited to one call per boot (sentinel file `/run/inferno-bootstrap-done`), returning the bearer token in exchange for a request signed with the node's `INFERNO_DEVICE_ID`. This removes the SSH password dependency entirely.

##### Evidence

``inferno-central/node_client/bootstrap.py:31` -- `password = ssh_password or "inferno123"`; lines 46-48 -- `PermissionDenied` -> `log.warning()` -> returns `None` silently; `INTEGRATION.md` step 5 -- entire bootstrap gated on factory default SSH password`

---

#### V2-ECO-09 -- No Self-Registration Service -- Nodes Cannot Push Identity to inferno-central

**Importance:** Medium  
**Difficulty:** Medium  
**Risk:** Low  
**Prerequisites:** None  

##### Impact

Enables fleet enrollment in multi-VLAN deployments where mDNS does not cross network boundaries.

##### Description

`models.py` has no `INFERNO_CENTRAL_URL` field. No registration systemd unit exists. `INTEGRATION.md` relies entirely on central-initiated mDNS discovery + SSH bootstrap. In multi-VLAN installations, Virgil nodes on a separate subnet are invisible to inferno-central. Fix: add `INFERNO_CENTRAL_URL` as an optional key to `inferno.conf`/`NodeConfig`, and ship a `inferno-register.service` systemd oneshot (`After=network-online.target inferno-node-agent.service`) that, if the URL is set, POSTs the device identity and agent token to `PUT /nodes/{device_id}` on central. `NodeConfig` already has `INFERNO_DEVICE_ID` and all required fields.

##### Evidence

``inferno-node-agent/inferno_node_agent/models.py` -- no `INFERNO_CENTRAL_URL` field; `templates/systemd/` -- no registration unit; `inferno-central/ROADMAP.md` MT-2 -- "Currently limited to VLAN 10"`

---

#### V2-ECO-10 -- No Push Alerting on Critical Service Failure -- All Monitoring Is Pull-Only

**Importance:** Medium  
**Difficulty:** Medium  
**Risk:** Low  
**Prerequisites:** V2-ECO-09  

##### Impact

Reduces audio outage detection time from up to 60 seconds (poll cycle) to sub-second.

##### Description

`inferno-bridge.service` has `Restart=always` but no `OnFailure=` or `ExecStopPost=`. `statime-inferno.service` has `Restart=on-failure` with no failure notification path. `inferno-central` health poll interval is 60 seconds -- meaning a venue can experience a full minute of silent Dante outputs before the fleet dashboard registers a problem. If `INFERNO_CENTRAL_URL` is set (V2-ECO-09), adding `OnFailure=inferno-notify-central@%n.service` to both service templates would POST a lightweight JSON event to central immediately on failure. The script is 10 lines of curl; only two lines per service template need changing.

##### Evidence

``templates/systemd/user/inferno-bridge.service` -- `Restart=always`, no `OnFailure=`; `templates/systemd/system/statime-inferno.service` -- `Restart=on-failure`, no `OnFailure=`; `inferno-central/inferno_central/config.py:36` -- `health_poll_interval_seconds: int = 60``

---

