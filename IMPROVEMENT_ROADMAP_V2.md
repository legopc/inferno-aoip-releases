# Inferno AoIP Appliance — Improvement Roadmap V2

> **Document type:** Engineering backlog — new items only  
> **Scope:** Virgil appliance (inferno-aoip-releases) + ecosystem touchpoints (inferno-node-agent, inferno-central, dante-patchbox)  
> **Researched:** April 2026 — five parallel deep-dive research agents  
> **Items:** 50 new improvements across 5 categories  
> **Method:** Each item was found by reading actual code/configs. All evidence cites specific files and line numbers.  
> **Companion:** See [IMPROVEMENT_ROADMAP.md](IMPROVEMENT_ROADMAP.md) for the Sprint 1/2 active backlog.

---

## How to Read This Document

| Field | Values |
|---|---|
| **Importance** | Critical / High / Medium / Low |
| **Difficulty** | Easy (<2h) / Medium (half-day) / Hard (multi-day) |
| **Risk** | Low / Medium / High — chance of regressions if implemented |
| **Prerequisites** | Item IDs from this document or the main roadmap |

Items marked **Critical** are confirmed bugs or exploits present in the current codebase with specific code evidence.

---

## Executive Summary

| ID | Category | Title | Importance | Difficulty | Risk |
|---|---|---|---|---|---|
| **V2-SEC-01** | Security | statime NoNewPrivileges=no — Setuid Re-Escalation Path | **Critical** | Easy | Low |
| **V2-OPS-05** | Cockpit/Ops | restartAll() Bug — AUX_SVCS Undefined, Non-Spotify Restart Silently Broken | **Critical** | Easy | Low |
| **V2-AUD-01** | Audio/RT | alsaloop Missing -S SAMPLERATE Clock Drift Compensation | **Critical** | Easy | Low |
| V2-SEC-04 | Security | spSudo() Shell Injection via Device Names | High | Medium | Medium |
| V2-SEC-03 | Security | IoT Updater /session-token Unauthenticated | High | Medium | Medium |
| V2-SEC-02 | Security | SNMP Credentials Plaintext World-Readable | High | Easy | Low |
| V2-SEC-05 | Security | All User Services: Zero Systemd Security Directives | High | Medium | Medium |
| V2-SEC-06 | Security | SSH Daemon No Hardening Drop-In | High | Easy | Low |
| V2-AUD-02 | Audio/RT | ALSA dmix Buffer Too Shallow for alsaloop Window | High | Easy | Low |
| V2-AUD-03 | Audio/RT | librespot.service No CPUSchedulingPolicy=fifo | High | Easy | Low |
| V2-AUD-04 | Audio/RT | iRadio Rubato Resampler sub_chunks=2 (Minimum Quality) | High | Easy | Low |
| V2-AUD-05 | Audio/RT | iRadio ALSA PCM No sw_params (start_threshold/avail_min) | High | Easy | Low |
| V2-BLD-01 | Build/Deploy | No CI/CD Pipeline — Build Is Entirely Manual | High | Hard | Low |
| V2-BLD-03 | Build/Deploy | Containerfile Downloads Binaries from releases/latest | High | Easy | Medium |
| V2-BLD-09 | Build/Deploy | No Post-Build Container Smoke Test | High | Medium | Low |
| V2-BLD-10 | Build/Deploy | podman build Lacks --pull=newer — Base Image Silently Stale | High | Easy | Low |
| V2-ECO-01 | Ecosystem | mDNS TXT Key Mismatch (device vs device_name) | High | Easy | Low |
| V2-ECO-02 | Ecosystem | No Avahi Service File Template — mDNS Bootstrap Paradox | High | Medium | Low |
| V2-ECO-03 | Ecosystem | No /dante Endpoint — Minos Cannot Auto-Discover Sources | High | Easy | Low |
| V2-ECO-04 | Ecosystem | /health Missing dante_connected Flag | High | Easy | Low |
| V2-ECO-05 | Ecosystem | ALSA Xrun Counters Absent from /metrics | High | Easy | Low |
| V2-ECO-07 | Ecosystem | Mode Switch via PUT /config Doesn't Transition Source Services | High | Medium | Medium |
| V2-ECO-08 | Ecosystem | Bootstrap Relies on Hardcoded SSH Password | High | Medium | Low |
| V2-OPS-01 | Cockpit/Ops | Embed iRadio Controls Inline in Cockpit | High | Medium | Low |
| V2-OPS-02 | Cockpit/Ops | Spotify Account Link Status in Cockpit | High | Medium | Low |
| V2-OPS-03 | Cockpit/Ops | PTP Jitter and Variance Metrics in Performance Panel | High | Easy | Low |
| V2-OPS-06 | Cockpit/Ops | Dante Network Pre-flight: Multicast, MTU, Link Speed, ARP | High | Medium | Low |
| V2-OPS-07 | Cockpit/Ops | Mode-Switch Audio Interruption Warning Modal | High | Easy | Low |
| V2-AUD-06 | Audio/RT | iRadio Pre-Roll Buffer 8KB Causes Decoder Starvation | Medium | Easy | Low |
| V2-AUD-07 | Audio/RT | No ALSA Xrun Telemetry in Node-Agent | Medium | Easy | Low |
| V2-AUD-08 | Audio/RT | statime Intervals Not Tuned to Dante AES67 PTP Profile | Medium | Medium | Medium |
| V2-AUD-09 | Audio/RT | iRadio Slot Keeper No Runtime ALSA Re-Open | Medium | Medium | Low |
| V2-AUD-10 | Audio/RT | librespot --normalisation Absent — ±20 LU Track Variation | Medium | Easy | Low |
| V2-BLD-02 | Build/Deploy | BIB Pulled as :latest — Build Tool Unpinned | Medium | Easy | Low |
| V2-BLD-04 | Build/Deploy | Rust Toolchain Pinned to @stable — Not Version-Pinned | Medium | Easy | Medium |
| V2-BLD-05 | Build/Deploy | No SBOM Generation or Vulnerability Scan | Medium | Medium | Low |
| V2-BLD-06 | Build/Deploy | All RPM Packages Unpinned — dnf Is Non-Reproducible | Medium | Hard | Medium |
| V2-BLD-07 | Build/Deploy | No Ignition Placeholder Substitution Script | Medium | Easy | Medium |
| V2-BLD-08 | Build/Deploy | OTA Upload No Chunk-Resume Across Sidecar Restarts | Medium | Medium | Low |
| V2-ECO-06 | Ecosystem | No Prometheus Scrape Endpoint on Node-Agent | Medium | Easy | Low |
| V2-ECO-09 | Ecosystem | No Self-Registration Service — Nodes Invisible in Multi-VLAN | Medium | Medium | Low |
| V2-ECO-10 | Ecosystem | No Push Alerting on Critical Service Failure | Medium | Medium | Low |
| V2-OPS-04 | Cockpit/Ops | iRadio Custom URL Pre-play Validation | Medium | Easy | Low |
| V2-OPS-08 | Cockpit/Ops | Post-Reboot Reconnect Countdown (Actions Panel) | Medium | Easy | Low |
| V2-OPS-09 | Cockpit/Ops | ALSA XRUN Counter on Health Dashboard | Medium | Easy | Low |
| V2-OPS-10 | Cockpit/Ops | Fleet Peer Discovery via Dante mDNS | Medium | Medium | Low |
| V2-SEC-07 | Security | SNMP Listens on All Interfaces Including Dante NIC | Medium | Easy | Low |
| V2-SEC-08 | Security | Avahi No Interface Filtering — Advertises Management on Audio Network | Medium | Easy | Low |
| V2-SEC-09 | Security | inferno-configure.service No Systemd Sandbox Directives | Medium | Easy | Low |
| V2-SEC-10 | Security | librespot Credential Cache World-Readable (No UMask=0077) | Medium | Easy | Low |

---

## Security

### Summary

| ID | Title | Importance | Difficulty | Risk | Prerequisites |
|---|---|---|---|---|---|
| V2-SEC-01 | statime NoNewPrivileges=no — Setuid Re-Escalation | Critical | Easy | Low | Item 106 |
| V2-SEC-02 | SNMP Credentials in Plaintext /etc/inferno.conf | High | Easy | Low | None |
| V2-SEC-03 | IoT Updater /session-token Unauthenticated | High | Medium | Medium | Item 63 |
| V2-SEC-04 | spSudo() Shell Injection via Device Names | High | Medium | Medium | None |
| V2-SEC-05 | All User Services: Zero Hardening Directives | High | Medium | Medium | None |
| V2-SEC-06 | SSH No Hardening Drop-In Config | High | Easy | Low | None |
| V2-SEC-07 | SNMP Listens on All Interfaces | Medium | Easy | Low | None |
| V2-SEC-08 | Avahi No Interface Filtering | Medium | Easy | Low | None |
| V2-SEC-09 | inferno-configure.service No Sandbox Directives | Medium | Easy | Low | None |
| V2-SEC-10 | librespot Credential Cache World-Readable | Medium | Easy | Low | None |

---

#### V2-SEC-01 — statime-inferno.service Has `NoNewPrivileges=no`

**Importance:** Critical
**Difficulty:** Easy (<2h)
**Risk:** Low
**Prerequisites:** Item 106 (pairs well, but independent)

**Impact:** A compromised statime process can execute setuid/setgid binaries to gain root, defeating the capability bounding set entirely.

##### What is it?

`templates/systemd/system/statime-inferno.service` line 17 contains `NoNewPrivileges=no` — an explicit permission to call setuid executables. Even with a `CapabilityBoundingSet=` restricting startup capabilities (Item 106), a compromised statime binary can still gain root via any setuid helper on the system by calling `execve()` on it. This is the only system service with this flag explicitly set to the insecure value.

##### Implementation

Change `NoNewPrivileges=no` to `NoNewPrivileges=yes` in `statime-inferno.service`. statime requires only its declared `AmbientCapabilities` and does not call any setuid binary during normal operation.

##### Evidence

`templates/systemd/system/statime-inferno.service:17` — `NoNewPrivileges=no`

---

#### V2-SEC-02 — SNMP v3 Credentials in Plaintext World-Readable `/etc/inferno.conf`

**Importance:** High
**Difficulty:** Easy (<2h)
**Risk:** Low
**Prerequisites:** None

**Impact:** Any local process (avahi, lldpd, pcp, snmpd, iot-updater) can read SNMPv3 auth/privacy passphrases.

##### What is it?

When an operator configures SNMP via Cockpit, the v3 auth and privacy passphrases are written to `/etc/inferno.conf` via `cockpit.spawn(["sudo","-n","tee",path])`. The `tee` command creates the file with default umask permissions (0644 — world-readable), and no subsequent `chmod` is performed. `INFERNO_SNMP_V3_AUTH_PASS` and `INFERNO_SNMP_V3_PRIV_PASS` are therefore readable by every process on the system.

##### Implementation

1. Add `chmod 0640 /etc/inferno.conf` in `inferno-configure.sh` immediately after the heredoc write (line 271).
2. Replace `sudo -n tee <path>` in `writeFileAsSudo()` with `sudo install -m 0640 -o root -g root /dev/stdin <path>` or add an explicit `chmod` call after `tee`.

##### Evidence

`build/inferno-configure.sh:271` — `cat > /etc/inferno.conf <<EOF` (no chmod follows); `cockpit-inferno/src/inferno.js:83` — `writeFileAsSudo` uses `sudo -n tee <path>` inheriting umask 0644.

---

#### V2-SEC-03 — IoT Updater `/session-token` Endpoint Unauthenticated

**Importance:** High
**Difficulty:** Medium (half-day)
**Risk:** Medium
**Prerequisites:** Item 63 (OTA signing, complementary)

**Impact:** Any unprivileged local process can obtain the sidecar session token and use it to trigger a firmware update or OS rollback, bypassing all operator confirmation.

##### What is it?

The IoT updater sidecar (running as root on 127.0.0.1:8088) exposes `GET /session-token` with no authentication guard — no header check, no credential, no Cockpit bridge verification. Once a process obtains this token, it satisfies `_check_session_token()` on all POST endpoints including `/upload/apply` (deploy firmware) and `/rollback` (revert OS). The CORS origin check only guards browser-based requests, not raw socket clients. A compromised service process (snmpd, avahi, pcp) can achieve root-equivalent OTA control.

##### Implementation

Gate `/session-token` on a Unix-domain socket owned by root with group `cockpit-ws`, or derive the token from a secret injected by systemd (`LoadCredential=`) and never expose it over HTTP.

##### Evidence

`iot-updater/sidecar/server.py:427-428` — `if self.path == '/session-token': self.send_json(200, {'token': SESSION_TOKEN})` with no preceding authentication check.

---

#### V2-SEC-04 — Cockpit `spSudo()` Builds Shell Commands by String Concatenation — Shell Injection via Device Names

**Importance:** High
**Difficulty:** Medium (half-day)
**Risk:** Medium
**Prerequisites:** None

**Impact:** A Spotify/Dante device name containing shell metacharacters executes with NOPASSWD sudo privileges, enabling arbitrary root command execution from the Cockpit UI.

##### What is it?

`spSudo(cmd)` at `inferno.js:78` constructs `cockpit.spawn(["bash", "-c", "sudo -n " + cmd])` — the string `cmd` is concatenated without any escaping. `saveConfig()` embeds operator-supplied "Spotify name" and "Dante name" form fields directly into bash `sed` commands: e.g. a name like `"; sudo reboot #` closes the `sed` string and executes `reboot` as root. Since the Cockpit plugin runs as the authenticated `core` user (NOPASSWD wheel), this is root code execution.

##### Implementation

Replace all `spUser`/`spSudo` `sed`/shell invocations with array-form `cockpit.spawn()` calls or pure-JS file manipulation via `cockpit.file().replace()`. Never pass user-input strings into `bash -c`.

##### Evidence

`cockpit-inferno/src/inferno.js:78` — `cockpit.spawn(['bash', '-c', 'sudo -n ' + cmd])`; `line 851` — `sed` command embedding raw `newSpotifyName` form field; `lines 867-869` — identical pattern with `newDanteName`.

---

#### V2-SEC-05 — All User Systemd Services Have Zero Security Directives

**Importance:** High
**Difficulty:** Medium (half-day)
**Risk:** Medium
**Prerequisites:** None

**Impact:** A compromised librespot (parsing untrusted Spotify/OGG data) has unrestricted access to the home directory, all unit files, and can make arbitrary network connections.

##### What is it?

Every user-space service — `inferno-bridge.service`, `librespot.service`, `inferno-keepalive.service`, `inferno-aux-tx/rx.service` — contains no systemd security hardening directives whatsoever. None have `NoNewPrivileges=yes`, `PrivateTmp=yes`, `ProtectSystem=strict`, `ProtectHome=read-only`, `RestrictAddressFamilies`, `SystemCallFilter`, or `PrivateDevices`. librespot in particular parses untrusted audio metadata from the internet and has write access to all user systemd unit files and the Spotify token cache.

##### Implementation

Baseline fix per service:
- **librespot.service**: `NoNewPrivileges=yes`, `PrivateTmp=yes`, `ProtectSystem=strict`, `ReadWritePaths=~/.cache/librespot`, `UMask=0077`
- **inferno-bridge.service**: `NoNewPrivileges=yes`, `PrivateTmp=yes`, `ProtectSystem=strict`, `ReadWritePaths=/run`
- **keepalive services**: `NoNewPrivileges=yes`, `ProtectSystem=full`

##### Evidence

`grep` across all `templates/systemd/user/*.service` — only `statime-inferno.service` (a system service) has any security directives. All user services confirmed to contain zero security hardening.

---

#### V2-SEC-06 — SSH Daemon Enabled with No Hardening Drop-In Configuration

**Importance:** High
**Difficulty:** Easy (<2h)
**Risk:** Low
**Prerequisites:** None

**Impact:** The SSH daemon is reachable from the network with default Fedora settings: `MaxAuthTries=6`, no idle timeout, X11Forwarding enabled, no AllowUsers restriction.

##### What is it?

`openssh-server` is installed and `sshd` is enabled (Containerfile line 129) but no custom `sshd_config.d` drop-in is written anywhere in the repo. Fedora's defaults allow 6 authentication attempts per connection, keep idle sessions alive indefinitely, and enable X11Forwarding. No existing roadmap item covers these non-breaking hardening directives.

##### Implementation

Add to Containerfile a `RUN` that writes `/etc/ssh/sshd_config.d/99-inferno-hardening.conf`:
```
MaxAuthTries 3
LoginGraceTime 20
ClientAliveInterval 300
ClientAliveCountMax 2
X11Forwarding no
AllowTcpForwarding no
PermitUserEnvironment no
```
All are non-breaking — they do not disable password auth.

##### Evidence

`Containerfile:129` — sshd in enabled services list; zero `sshd_config` references across entire repo.

---

#### V2-SEC-07 — SNMP `agentAddress` Listens on All Interfaces Including Dante Audio NIC

**Importance:** Medium
**Difficulty:** Easy (<2h)
**Risk:** Low
**Prerequisites:** None

**Impact:** When SNMP is enabled, the daemon is reachable from AV equipment (switches, DSPs, amplifiers) on the Dante network that should not have management access.

##### What is it?

`templates/snmpd.conf.template:31` sets `agentAddress udp:161` — binding to all network interfaces. On a typical AoIP deployment the Dante NIC is shared with or adjacent to AV control gear. Exposing SNMP to this segment with a cleartext v2c community string allows any network device to query or fingerprint the appliance.

##### Implementation

Change the template to `agentAddress udp:%%INFERNO_INTERFACE%%:161` and update `inferno-snmp-apply.sh` to substitute the placeholder. Or use `udp:127.0.0.1:161` for management-only access.

##### Evidence

`templates/snmpd.conf.template:31` — `agentAddress udp:161`; `rocommunity` set to `default` (all sources); no `%%INFERNO_INTERFACE%%` substitution in the template.

---

#### V2-SEC-08 — Avahi mDNS No Interface Filtering — Advertises SSH/Cockpit on Audio Network

**Importance:** Medium
**Difficulty:** Easy (<2h)
**Risk:** Low
**Prerequisites:** None

**Impact:** SSH (port 22) and Cockpit (port 9090) are discoverable by any device on the same broadcast domain as the Dante audio NIC.

##### What is it?

`avahi-daemon` is enabled with no custom `avahi-daemon.conf`. Avahi's default behaviour is to respond to mDNS queries on all interfaces and advertise all registered service types, including `_ssh._tcp` and `_cockpit._tcp`. This provides free network reconnaissance to AV equipment that should only interact with Dante audio traffic.

##### Implementation

Create `/etc/avahi/avahi-daemon.conf` in the Containerfile with `allow-interfaces=%%INFERNO_NIC%%` (substituted at first boot by `inferno-configure.sh`), limiting Avahi to only the intended interface.

##### Evidence

`Containerfile:131` — avahi-daemon in enabled services; no `avahi-daemon.conf` in `templates/` or `scripts/`.

---

#### V2-SEC-09 — `inferno-configure.service` Runs as Root with No Systemd Sandbox Directives

**Importance:** Medium
**Difficulty:** Easy (<2h)
**Risk:** Low
**Prerequisites:** None

**Impact:** External binaries invoked during first-boot (ethtool, aplay, hostnamectl) execute with full unrestricted root access and can modify kernel state.

##### What is it?

`inferno-configure.service` is a `Type=oneshot` root service with no systemd security directives at all. The script invokes `ethtool -T` (parses NIC capability output), `aplay -l`, and `hostnamectl` (D-Bus call) all as uid=0. `ProtectKernelTunables=yes`, `ProtectKernelLogs=yes`, `PrivateTmp=yes`, and `LockPersonality=yes` are all safe to add and provide meaningful defence-in-depth.

> Note: `NoNewPrivileges=yes` cannot be added because the script calls `sudo -u core` to enable user services.

##### Implementation

Add to `inferno-configure.service`: `ProtectKernelTunables=yes`, `ProtectKernelLogs=yes`, `PrivateTmp=yes`, `LockPersonality=yes`.

##### Evidence

`build/systemd/inferno-configure.service` — [Service] section contains only `Type=oneshot`, `RemainAfterExit=yes`, `ExecStart`, logging directives; zero security directives.

---

#### V2-SEC-10 — librespot Spotify Credential Cache World-Readable (No `UMask=0077`)

**Importance:** Medium
**Difficulty:** Easy (<2h)
**Risk:** Low
**Prerequisites:** None

**Impact:** Root-running services (iot-updater, snmpd) can read and exfiltrate the Spotify device credential token without user knowledge.

##### What is it?

librespot is launched with `--cache /var/home/core/.cache/librespot`. librespot stores `credentials.json` (a reusable Spotify device auth blob) with default process umask 0022, resulting in a 0644 file readable by any root-running service. `iot-updater.service` runs as root and can trivially read this file.

##### Implementation

1. Add to `inferno-configure.sh`: `mkdir -p /var/home/core/.cache/librespot && chmod 0700 /var/home/core/.cache/librespot`
2. Add `UMask=0077` to `librespot.service`

##### Evidence

`templates/systemd/user/librespot.service:22-23` — `--cache /var/home/core/.cache/librespot`; no `UMask=` in service file; `iot-updater.service:7` — `User=root`.

---

## Audio Pipeline and Real-Time Performance

### Summary

| ID | Title | Importance | Difficulty | Risk | Prerequisites |
|---|---|---|---|---|---|
| V2-AUD-01 | alsaloop Missing -S SAMPLERATE Clock Drift Compensation | Critical | Easy | Low | None |
| V2-AUD-02 | ALSA dmix Buffer Too Shallow for 20ms alsaloop Window | High | Easy | Low | V2-AUD-01 |
| V2-AUD-03 | librespot.service No CPUSchedulingPolicy=fifo | High | Easy | Low | None |
| V2-AUD-04 | iRadio Rubato sub_chunks=2 — Minimum Resampler Quality | High | Easy | Low | None |
| V2-AUD-05 | iRadio ALSA PCM No sw_params (start_threshold/avail_min) | High | Easy | Low | None |
| V2-AUD-06 | iRadio Pre-Roll Buffer 8KB — Decoder Starvation | Medium | Easy | Low | None |
| V2-AUD-07 | No ALSA Xrun Telemetry in Node-Agent | Medium | Easy | Low | None |
| V2-AUD-08 | statime Intervals Not Tuned to Dante AES67 PTP Profile | Medium | Medium | Medium | None |
| V2-AUD-09 | iRadio Slot Keeper No Runtime ALSA Re-Open | Medium | Medium | Low | None |
| V2-AUD-10 | librespot --normalisation Absent — ±20 LU Track Variation | Medium | Easy | Low | None |

---

#### V2-AUD-01 — alsaloop Missing `-S SAMPLERATE` Clock Drift Compensation

**Importance:** Critical
**Difficulty:** Easy (<2h)
**Risk:** Low
**Prerequisites:** None

**Impact:** Without sample-rate drift compensation the two ALSA clock domains diverge over time, producing periodic xruns that interrupt all Dante TX audio.

##### What is it?

`inferno-bridge.service` ExecStart calls alsaloop without the `-S SAMPLERATE` flag. The inline comment directly above the stanza reads: *"alsaloop with -t 20000 (20ms transfer window) and SAMPLERATE sync for clock drift."* The flag was documented as required but is absent. alsaloop's default sync mode is 0 (none), so the local ALSA kernel timer driving `dmix` and the PTP-disciplined clock driving the Inferno ALSA plugin will drift by several ppm, producing a guaranteed xrun once every few minutes on a typical i219 NIC.

##### Implementation

Add `-S 1` (SAMPLERATE sync mode) to the alsaloop ExecStart line in `inferno-bridge.service`.

##### Evidence

`templates/systemd/user/inferno-bridge.service, lines 13–21`: comment says "SAMPLERATE sync for clock drift" but ExecStart has no `-S` flag.

---

#### V2-AUD-02 — ALSA dmix Buffer Too Shallow for 20ms alsaloop Transfer Window

**Importance:** High
**Difficulty:** Easy (<2h)
**Risk:** Low
**Prerequisites:** V2-AUD-01 (fix drift first, then tune headroom)

**Impact:** Eliminates underruns caused by the 1ms margin between the dmix buffer (21ms) and the alsaloop transfer window (20ms), which is far smaller than scheduler jitter.

##### What is it?

`asoundrc.spotify` configures `inferno_mix` dmix with `period_size 256` and `periods 4`, giving 1024 frames ≈ 21.3ms at 48kHz. alsaloop uses `-t 20000` (20ms) — 94% of the available buffer. Linux scheduler jitter on Fedora without CPU isolation is typically 2–8ms P99, which is 2-8× larger than the 1ms headroom.

##### Implementation

Double `periods` from 4 to 8 (buffer = 2048 frames ≈ 42.7ms) in `asoundrc.spotify`. This preserves the 20ms effective latency while tripling the jitter margin.

##### Evidence

`templates/alsa/asoundrc.spotify, lines 32–36`: `period_size 256`, `periods 4`.

---

#### V2-AUD-03 — librespot.service Missing `CPUSchedulingPolicy=fifo`

**Importance:** High
**Difficulty:** Easy (<2h)
**Risk:** Low
**Prerequisites:** None

**Impact:** Prevents SCHED_OTHER preemption of the librespot ALSA writer thread from causing loopback underruns and downstream Dante glitches.

##### What is it?

`librespot.service` sets `LimitMEMLOCK=infinity` (correct) but has no `CPUSchedulingPolicy=`, `CPUSchedulingPriority=`, or `Nice=` directives. Under any CPU spike (Cockpit serving a request, pmcd collecting metrics, iot-updater active), the SCHED_OTHER librespot writer can be delayed long enough to underrun the dmix buffer. The `core` user is already in the `@realtime` PAM group (rtprio 99), so no new capabilities are required.

##### Implementation

Add to `librespot.service`:
```ini
CPUSchedulingPolicy=fifo
CPUSchedulingPriority=70
```
(Below statime at priority 80, per Item 97 convention.)

##### Evidence

`templates/systemd/user/librespot.service`: no `CPUSchedulingPolicy` line. Containerfile lines 116–122: `@realtime` group grants rtprio 99. `statime-inferno.service`: `AmbientCapabilities=CAP_SYS_NICE` confirms the RT priority model already exists.

---

#### V2-AUD-04 — iRadio Rubato `FftFixedIn` `sub_chunks=2` — Minimum Resampler Quality

**Importance:** High
**Difficulty:** Easy (<2h)
**Risk:** Low
**Prerequisites:** None

**Impact:** Eliminates audible aliasing artefacts on 44.1→48kHz resampling from common MP3 internet radio sources.

##### What is it?

`decode.rs` lines 152 and 322 both call `FftFixedIn::<f32>::new(from_rate, to_rate, chunk_size=1024, sub_chunks=2, channels=2)`. Rubato's `sub_chunks` controls sinc filter quality: `sub_chunks=2` yields ~60dB stopband attenuation. Professional broadcast resampling requires ≥96dB (equivalent to `sub_chunks=8`). Even `sub_chunks=4` gives ~84dB with only 4× processing cost, which is inaudible on EliteDesk hardware.

##### Implementation

Change `sub_chunks=2` to `sub_chunks=8` in both call sites in `decode.rs`. Benchmark on EliteDesk to verify CPU headroom remains comfortable.

##### Evidence

`inferno-iradio/crates/iradio-bridge/src/decode.rs, lines 152, 322`: both use `FftFixedIn::new(..., 1024, 2, 2)`.

---

#### V2-AUD-05 — iRadio ALSA PCM Missing `sw_params` (`start_threshold`/`avail_min`)

**Importance:** High
**Difficulty:** Easy (<2h)
**Risk:** Low
**Prerequisites:** None

**Impact:** Eliminates cold-start underruns when the Inferno ALSA plugin begins consuming before the decode pipeline has primed the buffer.

##### What is it?

`alsa.rs` in iradio-bridge configures `hw_params` (channels, rate, format, access, buffer_size) but calls no `sw_params` on the PCM handle. The ALSA default `start_threshold` is 1 period, meaning the Inferno plugin starts consuming audio after a single write. With a 4-period decode channel (`mpsc::channel::<Vec<i32>>(4)`) and the slot keeper potentially mid-write of a silence period, the plugin may underrun before the second period arrives.

##### Implementation

After `hw_params` setup in `alsa.rs`, add:
```rust
let mut sw_params = pcm.sw_params_current()?;
sw_params.set_start_threshold(buffer_frames)?;
sw_params.set_avail_min(buffer_frames / 2)?;
pcm.sw_params(&sw_params)?;
```

##### Evidence

`inferno-iradio/crates/iradio-bridge/src/alsa.rs, lines 17–33`: hw_params configured; no `pcm.sw_params()` call anywhere in file.

---

#### V2-AUD-06 — iRadio Pre-Roll Buffer Threshold 8KB Causes Decoder Starvation

**Importance:** Medium
**Difficulty:** Easy (<2h)
**Risk:** Low
**Prerequisites:** None

**Impact:** Prevents silence gaps at the start of every iRadio session on sub-400kbps streams (virtually all public stations).

##### What is it?

`player.rs` line 110 waits until `buffer.len() >= 8 * 1024` (8KB) before starting the symphonia streaming decoder. At 128kbps, 8KB ≈ 0.5s of compressed audio. However, the decode pipeline's first ALSA period requires 4096 frames × 4 bytes = 16KB of decoded i32 samples sourced from roughly 7-10KB of compressed MP3 — the 8KB pre-roll barely covers one period. The `RING_BUFFER_CAPACITY` is 512KB; raising the threshold to 64KB costs ~4 seconds of extra startup latency while guaranteeing stable initial decode on any public station.

##### Implementation

Change `player.rs` line 110: `if buffer.lock().unwrap().len() >= 64 * 1024`

##### Evidence

`inferno-iradio/crates/iradio-bridge/src/player.rs, line 110`: `if buffer.lock().unwrap().len() >= 8 * 1024`

---

#### V2-AUD-07 — No ALSA Xrun Telemetry in Node-Agent Metrics/Health

**Importance:** Medium
**Difficulty:** Easy (<2h)
**Risk:** Low
**Prerequisites:** None

**Impact:** Makes audio dropout events visible to the monitoring stack for the first time.

##### What is it?

`inferno_node_agent/routes/metrics.py` exposes CPU%, memory, disk, uptime, PTP offset, and net bytes — nothing about audio. ALSA xrun counts (the primary indicator of RT scheduling failures) are available at `/proc/asound/card10/pcm*/sub0/status` (card10 is snd-aloop, pinned by `/etc/modprobe.d/snd-aloop.conf`). Reading these files requires no root privileges.

##### Implementation

Add an `alsa_xruns` field to the `/metrics` response reading `/proc/asound/card10/pcm{0,1}{p,c}/sub0/status` for the `xruns:` field. Expose as `alsa_xruns_total: {playback: N, capture: N}`.

##### Evidence

`inferno_node_agent/routes/metrics.py`: no `/proc/asound` reference. Containerfile line 96: `echo "options snd-aloop index=10"` — card index is stable.

---

#### V2-AUD-08 — statime Sync/Announce Intervals Not Tuned to Dante AES67 PTP Profile

**Importance:** Medium
**Difficulty:** Medium (half-day)
**Risk:** Medium
**Prerequisites:** None

**Impact:** Ensures Dante holdover does not trigger during grandmaster events causing crackling audio.

##### What is it?

`templates/inferno-ptpv1.toml` contains no `log-sync-interval`, `log-announce-interval`, or `announce-receipt-timeout` fields; statime inherits compiled defaults. The Shure MXWANI8 expects `logSyncInterval = -3` (8 msg/s) and `logAnnounceInterval = 0` (1 msg/s) per the AES67 PTP profile. If statime's default sync interval is slower than 8/s, the MXWANI8 takes longer to converge and is more sensitive to network jitter.

##### Implementation

Research statime's TOML keys for sync/announce intervals, then set them explicitly in `inferno-ptpv1.toml` to match the AES67 profile. Document the values and their rationale in a comment block.

##### Evidence

`templates/inferno-ptpv1.toml`: only `loglevel`, `sdo-id`, `domain`, `priority1`, `virtual-system-clock-base`, `usrvclock-export`, `interface`, `network-mode`, `protocol-version` present. No interval fields.

---

#### V2-AUD-09 — iRadio Slot Keeper No Runtime ALSA Re-Open After Plugin Failure

**Importance:** Medium
**Difficulty:** Medium (half-day)
**Risk:** Low
**Prerequisites:** None

**Impact:** Recovers iRadio audio automatically after Inferno ALSA plugin crash without a manual `systemctl restart`.

##### What is it?

`slot_keeper.rs` lines 38–46 contain an ALSA open/retry loop at startup only. Once `InfernoAlsaDevice` is open, write errors in the runtime loop (lines 49–67) are silently discarded (`let _ = alsa.write_frames(&samples)`). When the Inferno plugin's UNIX domain socket disappears (plugin process restart, Dante network interruption), the PCM enters an unrecoverable error state — the slot keeper keeps running but writes silence or nothing.

##### Implementation

Add a runtime re-open path: on any write error that survives `recover()`, drop the `InfernoAlsaDevice`, sleep 3s, and re-open — replicating the startup retry pattern.

##### Evidence

`inferno-iradio/crates/iradio-bridge/src/slot_keeper.rs, lines 38–67`: startup retry loop not replicated at runtime; `line 51`: `let _ = alsa.write_frames(&samples)` — error silently swallowed.

---

#### V2-AUD-10 — librespot `--normalisation` Absent — ±20 LU Track-to-Track Variation into Dante

**Importance:** Medium
**Difficulty:** Easy (<2h)
**Risk:** Low
**Prerequisites:** None

**Impact:** Provides broadcast-consistent output levels, preventing over-level clips on loud tracks and inaudibly quiet passages on low-normalised tracks into the MXWANI8.

##### What is it?

`librespot.service` ExecStart includes `--volume-ctrl log --initial-volume 50` but no `--normalisation` flag. Spotify encodes ReplayGain-compatible gain metadata in its stream. Without `--normalisation auto`, a pop track encoded at -1 dBFS and a classical track encoded at -18 dBFS both reach the Inferno ALSA plugin at their raw encoder levels — a 17 LU swing per track change.

##### Implementation

Add to `librespot.service` ExecStart:
```
--normalisation auto \
--normalisation-method album \
--normalisation-pregain -1.0
```
The -1.0 pregain provides 1dB safety headroom after normalisation.

##### Evidence

`templates/systemd/user/librespot.service, lines 11–27`: `--volume-ctrl log --initial-volume 50` present; no `--normalisation` flag.

---

## Build Pipeline and Deployment

### Summary

| ID | Title | Importance | Difficulty | Risk | Prerequisites |
|---|---|---|---|---|---|
| V2-BLD-01 | No CI/CD Pipeline — Build Is Entirely Manual | High | Hard | Low | None |
| V2-BLD-02 | BIB Pulled as :latest — Build Tool Unpinned | Medium | Easy | Low | None |
| V2-BLD-03 | Containerfile Downloads Binaries from releases/latest | High | Easy | Medium | None |
| V2-BLD-04 | Rust Toolchain Pinned to @stable — Not Version-Pinned | Medium | Easy | Medium | None |
| V2-BLD-05 | No SBOM Generation or Vulnerability Scan | Medium | Medium | Low | None |
| V2-BLD-06 | All RPM Packages Unpinned — dnf Is Non-Reproducible | Medium | Hard | Medium | None |
| V2-BLD-07 | No Ignition Placeholder Substitution Script | Medium | Easy | Medium | None |
| V2-BLD-08 | OTA Upload No Chunk-Resume Across Sidecar Restarts | Medium | Medium | Low | None |
| V2-BLD-09 | No Post-Build Container Smoke Test | High | Medium | Low | None |
| V2-BLD-10 | podman build Lacks --pull=newer — Base Image Silently Stale | High | Easy | Low | None |

---

#### V2-BLD-01 — No CI/CD Pipeline — Container and ISO Build Is Entirely Manual

**Importance:** High
**Difficulty:** Hard (multi-day)
**Risk:** Low
**Prerequisites:** None

**Impact:** Every release requires manual SSH into COPILOT-BUILD-01; broken Containerfiles or bad `config.toml` changes can ship undetected until deployed to hardware.

##### What is it?

The `nightly-build.yml` workflow compiles only Rust binaries. The `podman build`, BIB ISO generation, `.iotupdate` bundle packaging, and Proxmox SCP steps are all manual, run on a dedicated build VM with no CI gate. A self-hosted GitHub Actions runner on COPILOT-BUILD-01 triggered on version tags or `workflow_dispatch` would close this gap with minimal changes to `build-release.sh`.

##### Evidence

`.github/workflows/nightly-build.yml` — zero `podman`/BIB steps; `build/build-release.sh:8` — "Runs on COPILOT-BUILD-01 … Trigger remotely via: inferno-build <version>".

---

#### V2-BLD-02 — bootc-image-builder Pulled as `:latest` — Build Tool Version Unpinned

**Importance:** Medium
**Difficulty:** Easy (<2h)
**Risk:** Low
**Prerequisites:** None

**Impact:** Guarantees identical ISO output regardless of when the build runs.

##### What is it?

`build-release.sh` pulls `ghcr.io/osbuild/bootc-image-builder:latest` on every run. BIB is under active development and has made breaking changes to `config.toml` schema and output directory layout between minor versions. Pin to a specific digest or versioned tag, updated deliberately via a dependency-bump commit.

##### Evidence

`build/build-release.sh:83` — `ghcr.io/osbuild/bootc-image-builder:latest`

---

#### V2-BLD-03 — Containerfile Downloads Binaries from `releases/latest` — Non-Deterministic Builds

**Importance:** High
**Difficulty:** Easy (<2h)
**Risk:** Medium
**Prerequisites:** None

**Impact:** Establishes image provenance — two builds of the same Git commit can currently embed different statime/librespot/iradio-bridge binaries depending on build date.

##### What is it?

The `RELEASES_URL` ARG in the Containerfile defaults to `.../releases/latest/download`, meaning any subsequent image build silently picks up the latest nightly without a version gate. The fix is to require an explicit `--build-arg RELEASES_URL=.../releases/download/<tag>` in `build-release.sh` and fail the build if the ARG is not overridden from its default. The nightly workflow already outputs the tag name in `$GITHUB_OUTPUT`.

##### Evidence

`Containerfile:172` — `ARG RELEASES_URL=https://github.com/legopc/inferno-aoip-releases/releases/latest/download`

---

#### V2-BLD-04 — Rust Toolchain Pinned to `@stable` — Not Version-Pinned

**Importance:** Medium
**Difficulty:** Easy (<2h)
**Risk:** Medium
**Prerequisites:** None

**Impact:** Prevents silent toolchain upgrades from changing binary behaviour or introducing glibc dependency drift.

##### What is it?

`nightly-build.yml` uses `dtolnay/rust-toolchain@stable` with no version override. A new stable Rust release with a changed optimisation default or glibc dependency can silently produce different binaries. Adding a `rust-toolchain.toml` file at the repo root specifying `channel = "1.82.0"` (or current tested minimum) which `dtolnay/rust-toolchain` automatically respects pins this explicitly.

##### Evidence

`.github/workflows/nightly-build.yml:25` — `uses: dtolnay/rust-toolchain@stable` (no `toolchain:` key)

---

#### V2-BLD-05 — No SBOM Generation or Vulnerability Scan in Build Pipeline

**Importance:** Medium
**Difficulty:** Medium (half-day)
**Risk:** Low
**Prerequisites:** None

**Impact:** Provides machine-readable inventory for CVE audits and supply-chain compliance without manual inspection.

##### What is it?

Neither the nightly binary workflow nor `build-release.sh` generates a CycloneDX or SPDX SBOM. For a network-attached appliance with Cockpit (Node/Python), avahi, net-snmp, and multiple Rust binaries, the attack surface is non-trivial. Adding `anchore/syft-action` (SBOM) and `anchore/scan-action` (Grype CVE scan) as post-build steps takes under 20 lines of YAML.

##### Evidence

`nightly-build.yml:207` — `generate_release_notes: false`; no `syft`/`trivy`/`grype` step anywhere.

---

#### V2-BLD-06 — All RPM Packages Unpinned — `dnf install` Is Non-Reproducible

**Importance:** Medium
**Difficulty:** Hard (multi-day)
**Risk:** Medium
**Prerequisites:** None

**Impact:** Prevents silent Fedora package updates from changing image behaviour between builds, enabling bisection of regressions to specific package updates.

##### What is it?

The `dnf install -y` block in the Containerfile lists ~20 packages with no version constraints. Fedora's fast release cadence means these can change weekly. Options: (a) `dnf versionlock add` to capture NVRs into a lockfile, (b) use a Fedora compose snapshot as repo source, or (c) as a lighter first step, run `rpm -qa --qf '%{NAME}-%{VERSION}-%{RELEASE}\n'` at end of build and commit as `build/rpm-manifest.txt`.

##### Evidence

`Containerfile:34-67` — `dnf install -y … cockpit-ws cockpit-system … alsa-lib … net-snmp … bsdiff` — no version specifiers.

---

#### V2-BLD-07 — No Ignition Placeholder Substitution Script — Manual Error-Prone Provisioning

**Importance:** Medium
**Difficulty:** Easy (<2h)
**Risk:** Medium
**Prerequisites:** None

**Impact:** Eliminates risk of deploying nodes with literal placeholder strings as passwords.

##### What is it?

`ignition/inferno-template.bu` documents three string placeholders (`INFERNO_CORE_PASSWORD_HASH`, `INFERNO_SSH_KEY_RSA`, `INFERNO_SSH_KEY_ED25519`) that "must be replaced per-deployment," but there is no companion `prepare-ignition.sh`. A minimal script using `envsubst` + `butane` would eliminate the manual step and allow scripting into the Proxmox VM creation workflow.

##### Evidence

`ignition/inferno-template.bu:12-15` — three substitution placeholders documented; no `prepare-ignition.sh` exists anywhere in the repo.

---

#### V2-BLD-08 — OTA Upload Has No Chunk-Resume Across Sidecar Restarts

**Importance:** Medium
**Difficulty:** Medium (half-day)
**Risk:** Low
**Prerequisites:** None

**Impact:** Avoids restarting 2GB uploads from byte 0 when the sidecar crashes or the network interrupts during a 15-30 minute management-network transfer.

##### What is it?

`server.py` appends each HTTP chunk to `BUNDLE_PATH` correctly, but `_handle_upload_start()` unconditionally calls `BUNDLE_PATH.unlink(missing_ok=True)` to clear any previous upload, and the in-memory state resets to `"idle"` on every server restart. No persisted chunk-index manifest survives a restart. Adding `/var/lib/iot-updater/upload-state.json` recording `{bytes_received, total_chunks, sha256_so_far}` enables standard Range-request resume.

##### Evidence

`server.py:637` — `BUNDLE_PATH.unlink(missing_ok=True)` unconditional; `server.py:665` — chunk appended with `mode="ab"` but no state file written.

---

#### V2-BLD-09 — No Automated Post-Build Container Smoke Test

**Importance:** High
**Difficulty:** Medium (half-day)
**Risk:** Low
**Prerequisites:** None

**Impact:** Catches broken `systemctl enable` layers or missing unit files before an ISO is deployed to hardware.

##### What is it?

`build-release.sh` goes directly from `podman build` to BIB ISO generation with no lint or smoke step. `bootc container lint` (available since bootc ≥ 0.1.14) checks for common errors: content in `/var/` that should be in `/usr/`, wrong SELinux labels, missing `sysusers.d` definitions. A minimal `podman run --rm inferno-appliance:<ver> systemctl list-unit-files --state=enabled` validates that all expected services are enabled without booting a VM.

##### Evidence

`build/build-release.sh:62-66` — `podman build` immediately followed by step 3 (BIB ISO) with no smoke step.

---

#### V2-BLD-10 — `podman build` Lacks `--pull=newer` — Base Image Can Be Silently Stale

**Importance:** High
**Difficulty:** Easy (<2h)
**Risk:** Low
**Prerequisites:** None

**Impact:** Ensures Fedora base image security patches (glibc, openssl, systemd) are included in every build without manual intervention.

##### What is it?

`build-release.sh` invokes `podman build` without `--pull=newer`. Podman's default is `--pull=missing` — it uses the locally cached `fedora-bootc:43` image on COPILOT-BUILD-01 indefinitely. On a long-lived build VM, the base image can be weeks or months out of date. `--pull=newer` costs only one API call to compare digests and pulls only when the upstream image actually changes.

##### Evidence

`build/build-release.sh:61-66` — `${PODMAN} build --network=host -t "inferno-appliance:${VERSION}" … -f Containerfile .` (no `--pull` flag).

---

## Cockpit UI and Operations

### Summary

| ID | Title | Importance | Difficulty | Risk | Prerequisites |
|---|---|---|---|---|---|
| V2-OPS-01 | Embed iRadio Controls Inline in Cockpit | High | Medium | Low | None |
| V2-OPS-02 | Spotify Account Link Status in Cockpit | High | Medium | Low | None |
| V2-OPS-03 | PTP Jitter and Variance Metrics in Performance Panel | High | Easy | Low | None |
| V2-OPS-04 | iRadio Custom URL Pre-play Validation | Medium | Easy | Low | None |
| V2-OPS-05 | restartAll() Bug — AUX_SVCS Undefined (Critical Bug) | Critical | Easy | Low | None |
| V2-OPS-06 | Dante Network Pre-flight: Multicast, MTU, Link Speed, ARP | High | Medium | Low | None |
| V2-OPS-07 | Mode-Switch Audio Interruption Warning Modal | High | Easy | Low | None |
| V2-OPS-08 | Post-Reboot Reconnect Countdown | Medium | Easy | Low | None |
| V2-OPS-09 | ALSA XRUN Counter on Health Dashboard | Medium | Easy | Low | None |
| V2-OPS-10 | Fleet Peer Discovery via Dante mDNS | Medium | Medium | Low | None |

---

#### V2-OPS-05 — `restartAll()` Bug: `AUX_SVCS` Undefined — Non-Spotify Restart Silently Broken

**Importance:** Critical
**Difficulty:** Easy (<2h)
**Risk:** Low
**Prerequisites:** None

**Impact:** Fixes confirmed silent runtime bug where "Restart All" does nothing in aux-in, aux-out, aux-bidir, or iradio modes.

##### What is it?

`restartAll()` at `inferno.js:1102` uses `currentMode === "spotify" ? SPOTIFY_SVCS : AUX_SVCS`, but `AUX_SVCS` is not declared anywhere in the 2661-line file. JavaScript silently resolves it to `undefined`; `spUser("systemctl --user restart undefined")` fails silently. The fix is one line: replace `AUX_SVCS` with `modeToSvcs(currentMode)` — a helper at line 938 that correctly handles all five modes including iRadio.

##### Implementation

In `inferno.js` line 1102, replace:
```js
var userSvcs = currentMode === "spotify" ? SPOTIFY_SVCS : AUX_SVCS;
```
with:
```js
var userSvcs = modeToSvcs(currentMode);
```

##### Evidence

`cockpit-inferno/src/inferno.js:1102` — `AUX_SVCS` referenced; confirmed zero `const`/`let`/`var AUX_SVCS` declarations in entire file.

---

#### V2-OPS-01 — Embed iRadio Playback Controls Inline in Cockpit

**Importance:** High
**Difficulty:** Medium (half-day)
**Risk:** Low
**Prerequisites:** None

**Impact:** Eliminates the UX dead-end where iRadio mode requires leaving Cockpit to manage streams in a separate browser tab.

##### What is it?

When mode is `"iradio"`, the Cockpit Config panel renders only a hyperlink to the standalone iradio-bridge web UI on port 6100. The plugin makes zero API calls to iradio-bridge's REST endpoints (`/api/v1/players`, `/api/v1/health`). The iradio-bridge API is fully RESTful and accessible via `cockpit.spawn()` or a local `fetch()` proxy. A compact embedded player strip with per-slot state badges and stop buttons belongs directly in the Monitoring or Services tab.

##### Evidence

`cockpit-inferno/src/inferno.js:240-244` — only sets `iradio-ui-link.href`; no `fetch()` call to iradio-bridge API anywhere in the file.

---

#### V2-OPS-02 — Spotify Connect Credential and Account Link Status in Cockpit

**Importance:** High
**Difficulty:** Medium (half-day)
**Risk:** Low
**Prerequisites:** None

**Impact:** Gives operators visibility into whether librespot is authenticated to Spotify, preventing silent no-audio failures on premium-only streams.

##### What is it?

The Cockpit Config panel exposes only the Spotify device name. It does not show whether librespot has a cached credential, whether it is in unauthenticated mode, or what Spotify account last connected. The current playback status infers state by brittle journal regex (`"Loading track|Playing|Paused"`). The librespot cache directory contains JSON credential blobs that could be safely surfaced as "linked / not linked" without exposing the raw token.

##### Evidence

`cockpit-inferno/src/inferno.js:1243-1258` — Spotify status uses `lsLog.match(/Loading track|Playing|Paused/)`; `lines 163-170` — bitrate/normalisation fields force-disabled with no explanation.

---

#### V2-OPS-03 — PTP Jitter, Variance, and Mean Offset Metrics in Performance Panel

**Importance:** High
**Difficulty:** Easy (<2h)
**Risk:** Low
**Prerequisites:** None

**Impact:** Provides the quantitative clock-quality numbers that Dante AoIP networks actually require for reliability assessment.

##### What is it?

The PTP Performance card shows instantaneous offset and state — but all 900-point history is already accumulated in `_ptpHistory`. Standard deviation (jitter), peak-to-peak range, and mean offset are not computed from this data. A σ > 5µs sustained for >30s is a practical Dante failure threshold. The grandmaster field renders raw hex bytes with no human-readable device-name resolution.

##### Implementation

Add to `ptpStatUpdate()`:
- `σ (jitter)` = standard deviation of last N samples in `_ptpHistory`
- `mean` = average of last N samples
- `p2p` = max - min over the window

##### Evidence

`cockpit-inferno/src/inferno.js:1498-1505` — `ptpStatUpdate` shows only State/Offset/Grandmaster/Clock; `_ptpHistory[]` at lines 48–50 contains all the data.

---

#### V2-OPS-04 — iRadio Custom Stream URL Pre-play Validation and Reachability Probe

**Importance:** Medium
**Difficulty:** Easy (<2h)
**Risk:** Low
**Prerequisites:** None

**Impact:** Prevents silent "buffering forever" failures when operators enter malformed or unreachable stream URLs.

##### What is it?

The iRadio Quick Play form validates only that the URL field is non-empty. No scheme check, no hostname resolution, no HTTP HEAD probe for `content-type` (audio/mpeg, audio/aac). When an invalid URL is submitted, the player transitions to `state="error"` — a state exposed only in the standalone web UI and not surfaced at all in the Cockpit plugin.

##### Evidence

`inferno-iradio/web-ui/app.js:181` — `if (!url) { toast('error',…); return; }` — the only validation; `state.rs:46-56` — `PlayerState::Error` and `error: Option<String>` exist but Cockpit never reads them.

---

#### V2-OPS-06 — Dante Network Pre-flight Checks: Multicast, MTU, Link Speed, IP Conflict

**Importance:** High
**Difficulty:** Medium (half-day)
**Risk:** Low
**Prerequisites:** None

**Impact:** Catches the four most common field-deployment failures before operators spend hours tracing audio dropouts.

##### What is it?

The Health Check panel (`HC_CHECKS` array, lines 1531-1537) checks snd-aloop loaded, PTP locked, services active, disk < 80%, NIC has IP. It does not check: (1) multicast routing (Dante uses 239.255.x.x/24); (2) MTU for high channel-count Dante; (3) link speed (requires ≥100 Mbps); (4) IP address conflict (duplicate IP causes intermittent subscription failures). All four can be checked with `ip link`, `ethtool`, `ping -I <nic> 239.255.0.1 -c 1`, and `arping`.

##### Evidence

`cockpit-inferno/src/inferno.js:1531-1537` — HC_CHECKS: 7 checks, none cover multicast/MTU/link/ARP.

---

#### V2-OPS-07 — Mode-Switch Audio Interruption Warning Modal

**Importance:** High
**Difficulty:** Easy (<2h)
**Risk:** Low
**Prerequisites:** None

**Impact:** Prevents accidental live-broadcast interruptions when an operator saves a mode change without realising active streams will be hard-stopped.

##### What is it?

`saveConfig()` shows a "Preview Changes" diff modal before applying, but the diff only shows changed key-value pairs — it does not warn that currently-active audio services will be stopped. `saveConfig()` lines 897-900 unconditionally stops all services on mode change. The diff modal needs a prominent banner listing which services are active and will be stopped.

##### Evidence

`cockpit-inferno/src/inferno.js:897-900` — `stopSvcs = SPOTIFY_SVCS.concat(ALL_AUX_SVCS).concat(IRADIO_SVCS)` unconditional; `line 2124` — diff modal shows config diffs only.

---

#### V2-OPS-08 — Post-Reboot Reconnect Countdown for Manual Reboot and Re-deploy Actions

**Importance:** Medium
**Difficulty:** Easy (<2h)
**Risk:** Low
**Prerequisites:** None

**Impact:** Prevents operators from assuming the appliance crashed when it is simply rebooting.

##### What is it?

`triggerReboot()` and `triggerRedeploy()` (lines 1828-1842) use native `window.confirm()` dialogs and show only a brief toast before the session goes dark. No countdown, no polling for reconnect, no automatic page refresh when the node comes back. The same pattern exists in the iot-updater's own Cockpit page (identified as H-6 in its IMPROVEMENTS.md).

##### Implementation

Add a 30-second countdown overlay polling `cockpit.spawn(["hostname"])` every 2s and auto-refreshing on success.

##### Evidence

`cockpit-inferno/src/inferno.js:1828-1842` — `window.confirm()` used; no polling or reconnect logic.

---

#### V2-OPS-09 — ALSA XRUN Counter on Health Dashboard

**Importance:** Medium
**Difficulty:** Easy (<2h)
**Risk:** Low
**Prerequisites:** None

**Impact:** Shows the single most direct indicator of audio glitches directly in the health dashboard without requiring SSH.

##### What is it?

ALSA exposes xrun counts at `/proc/asound/card*/pcm*/sub*/status` (field `xruns:`). The Cockpit health check panel has no visibility into these. `scripts/bench/alsa-health.sh` already reads XRUN counts with this exact approach — the data just needs to be surfaced in `runHealthChecks()`.

##### Evidence

`cockpit-inferno/src/inferno.js` HC_CHECKS — no `/proc/asound` reference; `scripts/bench/alsa-health.sh` — XRUN-reading logic already exists in the repo.

---

#### V2-OPS-10 — Fleet Peer Discovery — Show Other Inferno Nodes via Dante mDNS

**Importance:** Medium
**Difficulty:** Medium (half-day)
**Risk:** Low
**Prerequisites:** None

**Impact:** Enables multi-node navigation directly from a single Cockpit pane without maintaining a separate IP spreadsheet.

##### What is it?

The Dante Discovery panel already scans `avahi-browse -rp _netaudio-arc._udp` and builds a `devices[]` array. Devices whose name starts with `"Inferno-"` (the auto-generated MAC-based naming pattern) are almost certainly other Virgil appliances. The discovery table renders only static text — no "Open Cockpit" link, no peer-type classification. Adding a link button (`https://<ip>:9090`) for Inferno-prefixed peers costs ~5 lines of JS.

##### Evidence

`cockpit-inferno/src/inferno.js:1692-1713` — `devices[]` array built but rendered as static text only; `architecture.md:54` — `INFERNO_DANTE_NAME = "Inferno-" + MAC_SUFFIX` makes peer identification deterministic.

---

## Ecosystem Integration

### Summary

| ID | Title | Importance | Difficulty | Risk | Prerequisites |
|---|---|---|---|---|---|
| V2-ECO-01 | mDNS TXT Key Mismatch (device vs device_name) | High | Easy | Low | None |
| V2-ECO-02 | No Avahi Service File Template — mDNS Bootstrap Paradox | High | Medium | Low | None |
| V2-ECO-03 | No /dante Endpoint on Node-Agent | High | Easy | Low | None |
| V2-ECO-04 | /health Missing dante_connected Flag | High | Easy | Low | None |
| V2-ECO-05 | ALSA Xrun Counters Absent from /metrics | High | Easy | Low | None |
| V2-ECO-06 | No Prometheus Scrape Endpoint on Node-Agent | Medium | Easy | Low | V2-ECO-05 |
| V2-ECO-07 | Mode Switch via PUT /config Doesn't Transition Services | High | Medium | Medium | None |
| V2-ECO-08 | Bootstrap Relies on Hardcoded SSH Password | High | Medium | Low | None |
| V2-ECO-09 | No Self-Registration Service — Nodes Invisible Multi-VLAN | Medium | Medium | Low | None |
| V2-ECO-10 | No Push Alerting on Critical Service Failure | Medium | Medium | Low | V2-ECO-09 |

---

#### V2-ECO-01 — mDNS TXT Key Mismatch: `device=` Published, `device_name=` Read

**Importance:** High
**Difficulty:** Easy (<2h)
**Risk:** Low
**Prerequisites:** None

**Impact:** Fixes device name always being `None` in the inferno-central fleet registry, requiring a secondary HTTP round-trip for every discovered node.

##### What is it?

Virgil's Avahi service file template publishes the TXT record with key `device=` (line 9 of the j2 template). `inferno-central/inferno_central/discovery/mdns.py` line 107 reads `_txt("device_name")` — a different key. The values never match, so `device_name` is always `None` after mDNS discovery.

Additionally, the TXT record is missing: `dante_name`, `agent_port=8089`, and `tx_channels` — all fields that central and Minos need at discovery time without a further HTTP call.

##### Implementation

1. Fix Avahi template: change `device=` to `device_name=`
2. Add `dante_name=%%INFERNO_DANTE_NAME%%`, `agent_port=8089`, `tx_channels=%%INFERNO_TX_CHANNELS%%` to the TXT records
3. Update `inferno-configure.sh` to substitute the new placeholders in the generated Avahi XML

##### Evidence

`inferno-central/avahi/inferno-aoip.service.j2:9` — `<txt-record>device={{ device_name }}</txt-record>`; `inferno-central/inferno_central/discovery/mdns.py:107` — `device_name = _txt("device_name")`.

---

#### V2-ECO-02 — Virgil Has No Avahi Service File Template — mDNS Bootstrap Paradox

**Importance:** High
**Difficulty:** Medium (half-day)
**Risk:** Low
**Prerequisites:** None

**Impact:** Resolves the circular dependency where central needs mDNS to discover nodes but nodes have no Avahi service file until central SSH-bootstraps them.

##### What is it?

`inferno-aoip-releases/templates/` has no Avahi service file template. `inferno-configure.sh` has no mechanism to generate `/etc/avahi/services/inferno-aoip.service` at first boot. `INTEGRATION.md` step 4 requires Avahi to be broadcasting before central's SSH bootstrap runs — but the file that enables the broadcast doesn't exist until central bootstraps. This is a circular dependency that silently fails in fresh deployments.

##### Implementation

Add `templates/avahi/inferno-aoip.service.xml` using the `%%PLACEHOLDER%%` substitution pattern (matching `snmpd.conf.template`) with tokens for `INFERNO_NAME`, `INFERNO_VERSION`, `INFERNO_TX_CHANNELS`, `INFERNO_DANTE_NAME`. Render it in `inferno-configure.sh`.

##### Evidence

`find inferno-aoip-releases/templates/` — no avahi directory; `templates/snmpd.conf.template` — `%%INFERNO_NAME%%` pattern established; `INTEGRATION.md` section 4 — conditional "If inferno-aoip-releases ships its own Avahi file..." (implies it doesn't).

---

#### V2-ECO-03 — No `/dante` Endpoint on Node-Agent — Minos Cannot Auto-Discover Source Metadata

**Importance:** High
**Difficulty:** Easy (<2h)
**Risk:** Low
**Prerequisites:** None

**Impact:** Allows inferno-central and Minos to auto-populate source labels and channel counts without SSH or manual config edits.

##### What is it?

The node-agent exposes `/hardware`, `/config`, `/health`, `/metrics` — but nothing that surfaces the Dante-specific identity: `INFERNO_DANTE_NAME`, `INFERNO_TX_CHANNELS`, `INFERNO_RX_CHANNELS`. Minos's `config.toml` `sources` array must exactly match the Dante TX device name Virgil advertises, and currently requires manual configuration.

##### Implementation

Add `routes/dante.py` with a single `GET /dante` route reading `INFERNO_DANTE_NAME`, `INFERNO_TX_CHANNELS`, `INFERNO_RX_CHANNELS` from `inferno.conf`. Zero risk — pure read endpoint.

##### Evidence

`inferno-node-agent/inferno_node_agent/routes/` — no `dante.py`; `dante-patchbox/config.toml.example` — `sources = ["Main Bar", "DVS PC", "Podium", "Spare"]` manually configured.

---

#### V2-ECO-04 — `/health` Missing `dante_connected` Flag

**Importance:** High
**Difficulty:** Easy (<2h)
**Risk:** Low
**Prerequisites:** None

**Impact:** Distinguishes true Dante readiness from systemd unit active state, preventing silent audio outages invisible to the fleet dashboard.

##### What is it?

`health.py` checks `inferno-bridge.service` via `systemctl is-active` — but this only confirms the unit state, not Dante network registration. The bridge can be "active" while waiting for PTP sync. The real readiness gate is `/tmp/ptp-usrvclock` socket existence (`ExecStartPre` in the bridge service template). Minos already exposes a `dante_connected` field in its health API — Virgil needs parity.

##### Implementation

Add `dante_connected: bool` to the `/health` response: `True` if both `statime-inferno.service` is active AND `/tmp/ptp-usrvclock` socket exists.

##### Evidence

`inferno_node_agent/routes/health.py` — `_get_service_statuses()` has no socket check; `inferno-bridge.service:14` — `ExecStartPre=/bin/sh -c 'while [ ! -S /tmp/ptp-usrvclock ]; do sleep 1; done'`.

---

#### V2-ECO-05 — ALSA Xrun Counters Absent from `/metrics` — Audio Dropout Events Invisible to Central

**Importance:** High
**Difficulty:** Easy (<2h)
**Risk:** Low
**Prerequisites:** None

**Impact:** Gives inferno-central INT-1 a concrete audio quality signal for time-series storage and alerting.

##### What is it?

`metrics.py` returns CPU%, memory, disk, uptime, PTP offset, and net bytes. `inferno-central/ROADMAP.md` INT-1 explicitly plans to "store time-series in SQLite, surface per-metric history... granular PTP offset, CPU, memory, and audio-path metrics" — but the audio-path metric has no data source on the node side. ALSA xrun counts are available at `/proc/asound/card10/pcm*/sub0/status`, no root privileges required.

##### Evidence

`inferno_node_agent/routes/metrics.py:44-87` — no audio metrics; `inferno-central/ROADMAP.md` INT-1 — "audio-path metrics" planned with no corresponding node endpoint.

---

#### V2-ECO-06 — No Prometheus Text-Format Scrape Endpoint on Node-Agent

**Importance:** Medium
**Difficulty:** Easy (<2h)
**Risk:** Low
**Prerequisites:** V2-ECO-05

**Impact:** Enables direct Grafana scraping of each Virgil node and feeds inferno-central MT-1 without a JSON-to-Prometheus conversion layer.

##### What is it?

`metrics.py` returns a JSON dict. `inferno-central/ROADMAP.md` MT-1 plans a Prometheus endpoint, but must currently convert all node metrics from JSON — adding a translation layer. A second handler on `/metrics/prometheus` (or `Accept: text/plain` content negotiation) emitting standard Prometheus exposition format reduces implementation to ~15 lines using `prometheus-client`.

##### Evidence

`metrics.py` — returns `dict[str, Any]` JSON; `inferno-central/ROADMAP.md` MT-1 — "Expose `/metrics` (Prometheus text format)".

---

#### V2-ECO-07 — Mode Switch via `PUT /config` Restarts Only `inferno-bridge` — Source Services Not Transitioned

**Importance:** High
**Difficulty:** Medium (half-day)
**Risk:** Medium
**Prerequisites:** None

**Impact:** Fixes broken mode transitions where librespot keeps running after switching to iradio and vice versa when triggered via inferno-central MT-3 bulk config push.

##### What is it?

`config.py` `_restart_service()` calls `systemctl restart inferno-bridge.service` — nothing else. A mode transition involves multiple user services: `spotify` mode needs librespot + inferno-keepalive; `iradio` mode needs inferno-iradio + inferno-aux-keepalive. There is no `POST /mode/{mode}` endpoint that atomically stops current-mode services, updates `inferno.conf`, and starts new-mode services. Central's MT-3 config push is blocked without this.

##### Implementation

Add `POST /mode/{mode}` route to node-agent that:
1. Validates mode value
2. Stops services for the current mode (`systemctl --user stop ...`)
3. Updates `INFERNO_MODE` in `inferno.conf`
4. Starts services for the new mode (`systemctl --user start ...`)

##### Evidence

`inferno_node_agent/routes/config.py:122-123` — only `systemctl restart inferno-bridge.service`; `services.py` — `USER_SERVICES` includes all mode-specific services but none touched on mode change.

---

#### V2-ECO-08 — Token Bootstrap Relies on Hardcoded SSH Password — Breaks If Default Changed

**Importance:** High
**Difficulty:** Medium (half-day)
**Risk:** Low
**Prerequisites:** None

**Impact:** Allows nodes with non-default SSH passwords (provisioned via Ignition or post-deploy hardening) to be bootstrapped into inferno-central.

##### What is it?

`inferno-central/node_client/bootstrap.py:31` uses `password = ssh_password or "inferno123"`. When bootstrap fails with `PermissionDenied`, it logs a warning and returns `None` — the node stays in the registry without a token and falls back to degraded SSH-only management permanently.

##### Implementation

Add a `POST /bootstrap` endpoint on the node-agent — unauthenticated but rate-limited to one call per boot (sentinel at `/run/inferno-bootstrap-done`), returning a bearer token in exchange for a request signed with the node's `INFERNO_DEVICE_ID`. Removes the SSH password dependency entirely.

##### Evidence

`inferno-central/node_client/bootstrap.py:31` — `password = ssh_password or "inferno123"`; `bootstrap.py:46-48` — `PermissionDenied → log.warning(...)` → returns `None` silently.

---

#### V2-ECO-09 — No Self-Registration Service — Nodes Invisible in Multi-VLAN Deployments

**Importance:** Medium
**Difficulty:** Medium (half-day)
**Risk:** Low
**Prerequisites:** None

**Impact:** Enables fleet enrollment across subnet boundaries where mDNS doesn't traverse VLAN boundaries.

##### What is it?

`inferno-central/ROADMAP.md` MT-2 acknowledges multi-subnet discovery is a gap. The complementary Virgil-side fix is to add `INFERNO_CENTRAL_URL` to `inferno.conf`/`NodeConfig` and ship a `inferno-register.service` systemd oneshot (`Type=oneshot, After=network-online.target`) that POSTs the device's identity to `PUT /nodes/{device_id}` on central when `INFERNO_CENTRAL_URL` is set. Makes the node discoverable from day one without mDNS or SSH.

##### Evidence

`inferno-node-agent/inferno_node_agent/models.py` — no `INFERNO_CENTRAL_URL` field; `templates/systemd/` — no registration unit; `INTEGRATION.md` — relies entirely on central-initiated mDNS discovery.

---

#### V2-ECO-10 — No Push Alerting on Critical Service Failure — All Monitoring Is Pull-Only

**Importance:** Medium
**Difficulty:** Medium (half-day)
**Risk:** Low
**Prerequisites:** V2-ECO-09

**Impact:** Reduces audio outage detection time from up to 60 seconds (poll cycle) to sub-second.

##### What is it?

`inferno-bridge.service` has `Restart=always` but no `OnFailure=` or `ExecStopPost=`. `inferno-central` polls nodes every 60 seconds (`health_poll_interval_seconds = 60`). When a critical service crashes and restarts, the outage is invisible to central for up to 60 seconds.

##### Implementation

If `INFERNO_CENTRAL_URL` is set (V2-ECO-09), add `OnFailure=inferno-notify-central@%n.service` to `inferno-bridge.service` and `statime-inferno.service`. The notification service is a 10-line curl script POSTing `{device_id, service, event: "failed", timestamp}` to a `POST /nodes/{id}/events` endpoint on central.

##### Evidence

`templates/systemd/user/inferno-bridge.service` — `Restart=always`, no `OnFailure=`; `inferno-central/inferno_central/config.py` — `health_poll_interval_seconds: int = 60`; no `/events` endpoint in `inferno-central/inferno_central/api/`.

---

## Quick Wins (Easy + High/Critical Importance)

Items that can be done in under 2 hours with high impact:

| ID | Title | Importance | Time Estimate |
|---|---|---|---|
| V2-OPS-05 | Fix restartAll() AUX_SVCS undefined bug | **Critical** | 5 min |
| V2-SEC-01 | Fix statime NoNewPrivileges=no | **Critical** | 5 min |
| V2-AUD-01 | Add -S SAMPLERATE to alsaloop | **Critical** | 5 min |
| V2-SEC-06 | Add sshd_config.d hardening drop-in | High | 15 min |
| V2-BLD-10 | Add --pull=newer to podman build | High | 5 min |
| V2-BLD-03 | Pin RELEASES_URL in build-release.sh | High | 15 min |
| V2-AUD-10 | Add --normalisation to librespot | Medium | 5 min |
| V2-ECO-01 | Fix mDNS TXT key mismatch | High | 15 min |
| V2-ECO-04 | Add dante_connected to /health | High | 30 min |
| V2-AUD-03 | Add CPUSchedulingPolicy=fifo to librespot | High | 10 min |
| V2-SEC-02 | Fix /etc/inferno.conf permissions (chmod 0640) | High | 10 min |
| V2-AUD-04 | Increase sub_chunks=2 to sub_chunks=8 in iRadio | High | 5 min |
| V2-AUD-06 | Increase iRadio pre-roll threshold 8KB → 64KB | Medium | 5 min |
| V2-OPS-03 | Add σ/mean/p2p to PTP panel (data already in memory) | High | 30 min |

---

*Document generated April 2026 — 50 items across 5 categories. All evidence cites specific file paths and line numbers verified against the codebase at time of research.*
