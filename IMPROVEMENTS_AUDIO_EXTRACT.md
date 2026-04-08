INFERNO AOIP APPLIANCE — OPEN IMPROVEMENTS
Audio Over IP Appliance Development Backlog — Text to Speech Version
Generated: April 2026
Total open improvements: 59

This document lists all open improvements to the Inferno AoIP appliance.
Each improvement includes its priority, difficulty, what it does, why it matters,
and any reasons to delay or skip it.

Priority levels: Critical means blocking or a security risk. High means significant
operational pain or safety risk. Medium means meaningful improvement. Low means
nice-to-have or minor polish.

Difficulty: Easy means under two hours. Medium means about half a day. Hard means
multiple days of work.

============================================================


============================================================
CRITICAL PRIORITY IMPROVEMENTS
============================================================

Item 59  —  restorecon for User Home Dir in inferno-configure.sh
Priority: Critical   Difficulty: Easy   Risk: Low
Benefit: Fixes broken SSH key authentication on all deployed nodes caused by wrong SELinux labels

What is it?
This is the configure-script fix for BUG-05. Ignition creates /var/home/core/.ssh/authorized_keys but the resulting SELinux label is unlabeled_t instead of ssh_home_t. Adding restorecon -Rv /var/home/core/ to inferno-configure.sh after the chown -R core:core call (~line 215) fixes the labels on first boot and on every upgrade re-run.

Why implement it?
Without correct SELinux labels, SSH key auth is silently denied on all deployed nodes. This is a single line fix that prevents a potentially node-bricking scenario once password auth is disabled.

Reasons to delay or skip?
No reason to defer. One line, zero risk, idempotent.

----------------------------------------

Item 100  —  Hardware PTP Timestamping Enforcement
Priority: Critical   Difficulty: Easy   Risk: Low
Benefit: Guarantees sub-microsecond PTP precision on supporting NICs; provides clear diagnostic when hardware timestamping is unavailable

What is it?
inferno-configure.sh detects hardware PTP capability (Item 12) but inferno-ptpv1.toml uses hardware-clock = "auto" — silently falling back to software timestamps if hardware timestamps fail. Software PTP timestamps have 10-100× worse accuracy. There's no log entry or health status to indicate which mode is active.

Why implement it?
On NICs that support hardware timestamping (Intel i210, i219, I225 — all common in EliteDesk hardware), software fallback represents a massive quality regression with zero operator visibility. Inferno nodes that silently fall back to SW timestamps will have noticeably worse Dante audio quality but no obvious cause.

Reasons to delay or skip?
Some deployment NICs genuinely don't support hardware timestamping. Hard-failing would block deployment on those nodes. Must warn clearly but not block.

----------------------------------------

Bug Fix BUG-07  —  Credentials Committed to Documentation Files
Priority: Critical   Difficulty: Easy   Risk: Low
Benefit: Reduces risk of credential exposure from documentation files in the repository

What is it?
cockpit-iot-updater/docs/DEPLOYMENT-V9.md and BUILDING-UPDATES.md contain the plaintext password Schnitzel-king1 for root@10.10.1.201. Even in a private or local repository, committing credentials is bad practice. If the repo is ever made public, cloned to a less-secure machine, or pushed to a CI system, the credential leaks.

Why implement it?
Even if the password has been rotated, the pattern of committing credentials is the issue. Scrubbing and adding tooling (.git-secrets or a pre-commit hook) prevents recurrence.

Reasons to delay or skip?
Scrubbing git history (via git filter-branch or git filter-repo) is operationally complex and rewrites commits. For a private/local repo, scrubbing the current working tree and rotating the credential is sufficient. Full history rewrite is optional.

----------------------------------------

Bug Fix BUG-05  —  SELinux unlabeled_t on /var/home/core/.ssh → SSH key auth fails
Priority: Critical   Difficulty: Easy   Risk: Low
Benefit: All deployed nodes have broken SSH key auth; silently falls back to password auth

What is it?
Ignition creates /var/home/core/.ssh/authorized_keys during first boot, but SELinux labels it unlabeled_t instead of the required ssh_home_t. The SSH daemon (selinux-aware) denies key-based authentication and silently falls back to password auth. This is confirmed on v23: ls -Z /var/home/core/.ssh/ shows unlabeled_t. The fix is a single restorecon -Rv /var/home/core/ call in inferno-configure.sh after user home setup.

Why implement it?
If password authentication is ever disabled (Items 26/27), nodes become completely unreachable. This is a latent critical vulnerability — it works now only because password auth is still enabled. The fix is a one-liner, completely safe, and idempotent.

Reasons to delay or skip?
SSH currently works via password auth so the issue is not immediately visible. However, as Item 26 (password policy) and Item 27 (disable password auth) are progressively implemented, this silently blocks the security hardening path.

----------------------------------------

Item 26  —  Default Password Policy
Priority: Critical   Difficulty: Easy   Risk: Low
Benefit: Eliminates a hardcoded, publicly-known credential from all deployed nodes

What is it?
The default core user is given the password inferno123 in the Containerfile. This password is committed to a public GitHub repository, meaning it is effectively public knowledge. Every deployed node ships with the same credential unless manually changed post-install.

Why implement it?
A hardcoded password in a public repo is not a "weak default" — it is a published credential. Any device reachable on the LAN (or reachable via VPN, jump host, or misrouted traffic) can be logged into by anyone who has read the repo. This is a real threat even on a private LAN: guests, contractors, or compromised devices can pivot laterally. The password is also likely to survive image upgrades if users don't know to change it.

Recommended approach: Lock the password and require SSH key injection via Ignition.

Add to Containerfile:

Document in DEPLOY.md that deployers must supply an SSH public key via an Ignition config or kickstart %post before first boot. This is consistent with how production bootc/Fedora IoT deployments are expected to work.

If SSH key injection is too operationally complex for the target audience, use the expire approach as a fallback:

This forces a password change on first SSH login. The initial password is still inferno123, but it cannot be reused after first login.

Do not leave inferno123 as a standing default.

Reasons to delay or skip?
Locking the password entirely (passwd --lock) breaks console recovery on a headless node if SSH keys are lost. In a home-lab scenario with physical access and no Ignition tooling, this creates a recovery dead end. In that case, prefer chage -d 0 (expire on first use) over locking.

----------------------------------------


============================================================
HIGH PRIORITY IMPROVEMENTS
============================================================

Item 106  —  statime-inferno.service Capability Sandboxing
Priority: High   Difficulty: Easy   Risk: Medium
Benefit: Limits blast radius if statime process is exploited — strips 35+ unnecessary Linux capabilities

What is it?
statime-inferno.service runs as root with no CapabilityBoundingSet — effectively full root. statime only needs three capabilities: CAP_SYS_TIME (adjust hardware clock), CAP_NET_RAW (raw PTP sockets), CAP_NET_BIND_SERVICE (bind to port 319/320). All others can be stripped.

Why implement it?
PTP daemon is network-facing (binds to ports 319/320, receives arbitrary UDP packets). A memory corruption bug in statime with full root capabilities is a complete system compromise. With capability bounding, the same bug is contained.

Reasons to delay or skip?
Risk: ProtectSystem= and PrivateTmp= can break statime's access to /etc/statime-inferno.toml or the PHC device if paths aren't whitelisted. Requires testing each restriction carefully.

----------------------------------------

Item 104  —  bootc Switch Rollback via FailureAction=
Priority: High   Difficulty: Easy   Risk: Low
Benefit: Automatic rollback to previous image if updated image hard-locks before reaching multi-user.target

What is it?
inferno-health-check.service correctly calls bootc rollback after 120s, but this only works if the system reaches multi-user.target. If a bad kernel argument or early-boot systemd unit causes a hard lock, the health check never runs. A FailureAction= on the health check unit combined with a watchdog service covers the gap.

Why implement it?
Applied OTA updates are the highest-risk operation on a production appliance. The existing 120s health check is good but incomplete — it doesn't cover boot-time panics or hard locks from bad kernel args.

Reasons to delay or skip?
Adds complexity to the boot sequence. FailureAction= only fires if the health check service itself fails, not if the system hangs. Full coverage requires a bootloader-level boot counter (systemd-boot BootCount).

----------------------------------------

Item 63  —  Enable OTA Bundle Signature Enforcement by Default
Priority: High   Difficulty: Easy   Risk: Low
Benefit: Prevents installation of unsigned or tampered OTA bundles on production nodes

What is it?
iot-updater/scripts/apply-update.sh sets ENFORCE_SIGNING="${IOT_UPDATER_ENFORCE_SIGNING:-0}" — signature verification exists but defaults to disabled. The signing infrastructure (tools/gen-signing-key.sh, Ed25519 signing in make-oci-bundle.sh) is already built. Defaulting to enabled means production nodes reject unsigned bundles.

Why implement it?
Signature verification infrastructure exists and works. Defaulting to disabled means the security feature is invisible in production. A single env var default change enables it fleet-wide. Dev workflow can override with IOT_UPDATER_ENFORCE_SIGNING=0.

Reasons to delay or skip?
All bundles must be signed before changing the default. If any existing bundles lack signatures, they become uninstallable. Coordinate with build pipeline (Item 69 BIB pinning) to ensure all released bundles are signed.

----------------------------------------

Item 105  —  Cockpit CSP Hardening (Remove unsafe-inline)
Priority: High   Difficulty: Easy   Risk: Low
Benefit: Eliminates CSS/script injection vector in IoT Updater and Cockpit Inferno plugins

What is it?
cockpit-iot-updater/manifest.json Content-Security-Policy includes style-src 'self' 'unsafe-inline'. This allows any injected CSS to execute, which is a meaningful XSS vector given the plugin's connect-src http://127.0.0.1:8088 grants access to the update sidecar. The cockpit-inferno manifest should also be audited for similar issues.

Why implement it?
Cockpit plugins run in a privileged browser context with access to systemd, journal, and SSH. An XSS in either plugin could silently trigger OTA updates, execute arbitrary systemctl commands, or exfiltrate SSH keys.

Reasons to delay or skip?
Removing unsafe-inline requires auditing all inline  blocks and moving them to linked CSS. The iot-updater UI uses some dynamic inline styles for progress bars — these must be refactored.

----------------------------------------

Item 62  —  Restrict sudo to Specific Inferno Commands
Priority: High   Difficulty: Easy   Risk: Low
Benefit: Reduces blast radius if the core user session is compromised via Cockpit or librespot

What is it?
The current Containerfile contains: echo "%wheel ALL=(ALL) NOPASSWD: ALL" — granting passwordless root for any command to any wheel user. This should be scoped to the specific commands Cockpit and inferno scripts actually need: systemctl, journalctl, cockpit, inferno-configure.sh, restorecon, hostnamectl, loginctl.

Why implement it?
NOPASSWD: ALL is the broadest possible sudo grant. An attacker with RCE in Cockpit, librespot, or any other user-level service gets full root without any additional barrier. A targeted sudoers file limits the damage to exactly the intended set of operations.

Reasons to delay or skip?
The risk is over-restriction: if Cockpit calls sudo for a command not in the whitelist, the operation silently fails. Requires careful auditing of all spSudo() calls in inferno.js before deploying. Start permissively and tighten over time.

----------------------------------------

Item 97  —  Disable RT Throttling (sched_rt_runtime_us=-1)
Priority: High   Difficulty: Easy   Risk: Low
Benefit: Prevents kernel from preempting SCHED_FIFO statime — eliminates 50ms/s forced pauses that cause PTP jitter spikes

What is it?
Linux's default sched_rt_runtime_us=950000 throttles SCHED_FIFO processes to 95% of CPU to prevent starvation. statime runs at FIFO priority 80; under default settings it can be involuntarily preempted for 50ms every second — catastrophic for IEEE 1588 PTP synchronisation. Setting this to -1 disables throttling entirely for RT processes.

Why implement it?
PTP synchronisation requires sub-millisecond timing consistency. The 50ms preemption window under default throttling is 50× larger than acceptable PTP jitter. Combined with PREEMPT_DYNAMIC/full, disabling RT throttling is the single highest-leverage software tuning available without a PREEMPT_RT kernel.

Reasons to delay or skip?
A runaway SCHED_FIFO process with sched_rt_runtime_us=-1 can starve all non-RT workloads completely. Only safe because inferno services are well-understood and not susceptible to infinite loops.

----------------------------------------

Item 107  —  WatchdogSec= for Critical Audio Services
Priority: High   Difficulty: Medium   Risk: Low
Benefit: Detects hung (non-exiting) service states and forces restart — catches zombie alsaloop processes

What is it?
inferno-bridge.service, inferno-keepalive.service, and librespot.service use Restart=always but have no watchdog. If alsaloop enters a hung state without exiting (e.g. waiting indefinitely for an ALSA buffer), systemd never detects the failure and never restarts the service. Audio stops silently.

Why implement it?
Restart=always only handles clean exits and crashes. A hung process looks "running" to systemd. The watchdog (WatchdogSec=) forces a restart if the service doesn't periodically sd_notify(WATCHDOG=1). Catches an entire class of silent audio failures.

Reasons to delay or skip?
Requires a wrapper script around alsaloop to send watchdog pings — the alsaloop binary itself doesn't support sd_notify. Adds a thin shell script wrapper layer.

----------------------------------------

Item 98  —  RT CPU Isolation (isolcpus + nohz_full + rcu_nocbs)
Priority: High   Difficulty: Medium   Risk: Medium
Requires first: Item 97, Item 108
Benefit: Reduces PTP jitter by an order of magnitude by dedicating 1-2 cores exclusively to RT workloads

What is it?
Even with preempt=full and threadirqs, kernel ticks (HZ=250) and RCU callbacks still interrupt all CPUs including ones running RT tasks. isolcpus removes specified CPUs from the scheduler's general pool; nohz_full makes those CPUs tickless; rcu_nocbs offloads RCU callbacks. The HP EliteDesk Mini has 4–8 cores — dedicating cores 2-3 to RT tasks is practical.

Why implement it?
With CPU isolation, cyclictest P99 latency on Fedora drops from ~200µs to ~20µs. For PTP, this means consistently sub-100µs offset rather than occasional 500µs spikes under load.

Reasons to delay or skip?
Requires knowing the CPU topology of all target hardware. A 2-core system would leave 0 cores for non-RT work. Needs dynamic detection of core count in inferno-configure.sh. Previously deferred as Item 37 for this reason — now that EliteDesk is established target hardware, risk is lower.

----------------------------------------

Item 65  —  Firewall Configuration (nftables) for Inferno Appliance
Priority: High   Difficulty: Medium   Risk: Medium
Benefit: Limits attack surface to only the ports required for Dante/PTP/Cockpit; all others closed by default

What is it?
No firewall configuration exists in the current image. All ports are exposed on all interfaces by default. A professional AV appliance deployed on a shared network should expose only the ports required for its function: SSH (22), Cockpit (9090), Dante discovery (mDNS 5353/udp), Dante audio (6000–6999/udp), and PTP (319–320/udp).

Why implement it?
Headless appliances on professional AV networks are frequently co-located with untrusted devices (guest networks, shared switches, conference room AV). A minimal firewall reduces exposure to port scans, stray connections, and potential interference with RT scheduling from unexpected inbound traffic.

Reasons to delay or skip?
Risk is medium because overly restrictive rules can break Dante discovery (mDNS multicast requires careful handling), PTP (multicast), and any future monitoring ports. Test thoroughly on a real Dante network before shipping. Note: Item 28 (firewalld) was rejected — this item uses nftables directly, which is cleaner for a bootc appliance without a full firewalld stack.

----------------------------------------

Bug Fix BUG-08  —  apply-update.sh Uses eval with Python Heredoc for JSON Parsing
Priority: High   Difficulty: Medium   Risk: Medium
Benefit: Eliminates potential code injection vector in the OTA update path

What is it?
iot-updater/scripts/apply-update.sh uses eval "$(python3 - <<'PYEOF' ... PYEOF)" at multiple points (lines ~46, ~69, ~125, ~157, ~193) to extract values from version.json. While the heredoc quoting prevents most injection, using eval on Python subprocess output is an unnecessary risk surface in the security-critical update path.

Why implement it?
If version.json is tampered with (compromised OTA bundle, MITM on an unsigned bundle), the eval construct could execute arbitrary shell commands. The current SHA256 verification mitigates this, but defence-in-depth requires eliminating the eval pattern entirely. Replacing with jq or direct python3 -c with explicit field extraction removes the attack vector.

Reasons to delay or skip?
Currently mitigated by bundle SHA256 verification — risk requires both bundle signature bypass AND a malicious version.json. Medium risk, not immediate danger. However, the eval pattern should not remain in security-sensitive scripts long-term.

----------------------------------------


============================================================
MEDIUM PRIORITY IMPROVEMENTS
============================================================

Item 64  —  URL Allowlist for IoT Updater POST /fetch-url
Priority: Medium   Difficulty: Easy   Risk: Low
Benefit: Prevents SSRF attacks via the bundle fetch endpoint

What is it?
sidecar/server.py's /fetch-url endpoint accepts any https:// URL as a bundle source. An attacker with Cockpit access (or a compromised Cockpit session) could use this to probe internal network services via SSRF — including cloud metadata endpoints (169.254.169.254), internal APIs, or other hosts on the AV LAN.

Why implement it?
SSRF via bundle fetch is a realistic attack vector on a multi-tenant AV installation where Cockpit may be accessible to multiple operators. An allowlist restricts fetches to known safe hosts with minimal operator impact.

Reasons to delay or skip?
Operators self-hosting an update server on a custom domain would need to configure the allowlist. Default should be permissive enough for the common case (GitHub releases) while blocking obvious SSRF targets.

----------------------------------------

Item 87  —  Dante Device Name Conflict Detection
Priority: Medium   Difficulty: Easy   Risk: Low
Benefit: Prevents audio routing failures caused by duplicate device names in Dante Controller

What is it?
Inferno's Dante device name is derived from the MAC address suffix (e.g., Inferno-73CF6B). If two nodes produce the same name — due to sequential MAC assignment in batch NIC orders, VM cloning, or MAC spoofing — Dante Controller displays both with the same name, creating routing confusion. No detection or warning currently exists.

Why implement it?
Dante name conflicts cause routing failures that are extremely difficult to diagnose without physical access. Operators see "two devices with the same name" in Dante Controller and cannot determine which is which. Early detection during first-boot or via Cockpit monitoring allows the operator to set a unique name via INFERNO_NAME in the config.

Reasons to delay or skip?
avahi-browse conflict detection adds ~8s to first-boot. On a large network, the scan may not capture all devices before timing out. This is best-effort detection, not a guarantee.

----------------------------------------

Item 75  —  Resource Limits in Service Units (MemoryMax, TasksMax, CPUQuota)
Priority: Medium   Difficulty: Easy   Risk: Low
Benefit: Prevents runaway services from starving statime or causing OOM crashes on long-running nodes

What is it?
No service unit currently specifies MemoryMax, CPUQuota, or TasksMax. A memory leak in librespot, iradio-bridge, or the IoT updater sidecar could OOM the system and kill statime, losing PTP synchronisation. On a headless appliance running for months, this is a realistic failure mode.

Why implement it?
Resource limits act as a safety net for the RT audio stack. Bounding non-RT services ensures statime and inferno-bridge always have memory and CPU available regardless of what librespot or the updater are doing.

Reasons to delay or skip?
Setting limits too low risks killing services under legitimate load (e.g., IoT updater during bundle extraction needs significant RAM). Start with generous limits and tighten after profiling actual usage.

----------------------------------------

Item 66  —  TLS Certificate Validation for Bundle URL Fetches
Priority: Medium   Difficulty: Easy   Risk: Low
Benefit: Prevents MITM attacks on OTA bundle downloads from custom URL sources

What is it?
sidecar/server.py uses urllib.request.urlopen(req, timeout=300) for bundle fetch and manifest downloads with default SSL validation. No explicit ssl.create_default_context() is created, meaning the system CA bundle's currency is assumed. Should explicitly create an SSL context and optionally support a custom CA certificate for self-hosted update servers.

Why implement it?
Explicit SSL context creation is a security best practice — it ensures the system CA bundle is loaded correctly and allows operators with private CA certificates to pin their own CA for custom update servers. The change is three lines.

Reasons to delay or skip?
Default SSL validation already works correctly in most deployments. This is a defence-in-depth improvement, not a fix for a known vulnerability.

----------------------------------------

Item 78  —  Log Rotation for Custom Script Logs
Priority: Medium   Difficulty: Easy   Risk: Low
Benefit: Prevents unbounded log growth on long-running nodes

What is it?
/var/lib/iot-updater/update.log and /var/lib/iot-updater/audit.log have no rotation configured. The audit log grows with every upload attempt — on a node receiving weekly OTA updates over years, this file can grow significantly. No logrotate.d configuration exists for any inferno-specific log path.

Why implement it?
Long-running headless appliances accumulate logs indefinitely. On a node deployed at a venue for 3+ years, unbounded audit logs become a meaningful disk space consumer. Log rotation is a standard operational hygiene item.

Reasons to delay or skip?
No reason to defer. A logrotate.d configuration is a static file addition to the Containerfile — zero runtime risk.

----------------------------------------

Item 103  —  NIC TX Queue and Ring Buffer Tuning
Priority: Medium   Difficulty: Easy   Risk: Low
Benefit: Prevents audio UDP packet drops during multichannel Dante streaming bursts

What is it?
Default Linux NIC transmit queue length is 1000 packets. Multi-channel Dante sends many simultaneous UDP audio frames per millisecond; a burst from the ALSA plugin can overflow the queue and silently drop packets. Ring buffer defaults (typically 256 descriptors RX/TX) are also undersized for Dante traffic patterns. Ethtool coalescing defaults optimise for throughput, not latency.

Why implement it?
Simple ethtool/ip tuning with no kernel changes. Directly addresses the root cause of intermittent audio glitches under load that aren't explained by PTP jitter.

Reasons to delay or skip?
ethtool is not currently in the Containerfile dependencies — needs to be added. Coalescing changes (rx-usecs 50) reduce throughput-optimised coalescing and slightly increase CPU IRQ rate.

----------------------------------------

Item 79  —  Config Backup Before OTA Update
Priority: Medium   Difficulty: Easy   Risk: Low
Benefit: Allows config recovery if an OTA update resets or overwrites customised node settings

What is it?
No backup is taken before applying an OTA update. If apply-update.sh or the new image's inferno-configure.sh overwrites /etc/inferno.conf, the ALSA config, or the statime TOML, operator-applied customisations are silently lost. A pre-update config backup provides a recovery point.

Why implement it?
/etc is a mutable overlay in bootc — values do persist across updates in theory. But a misconfigured new image that resets conf templates would destroy customisation without warning. A 3-file tarball archived before every update costs almost nothing and saves significant recovery time in the field.

Reasons to delay or skip?
For fully automated rollback (Item 17), a config backup is redundant if the previous boot is still accessible. However, config backup protects against cases where the image upgrade succeeds but the new image's config template is incompatible — a scenario rollback doesn't protect against.

----------------------------------------

Item 68  —  Add .containerignore to Reduce Build Context Size
Priority: Medium   Difficulty: Easy   Risk: Low
Benefit: Prevents multi-GB build context transfer on every build; faster build start on COPILOT-BUILD-01

What is it?
No .containerignore file exists in the repository. podman build transfers the entire repo directory as build context, including output-vN/ directories (2–4GB per release build), archived/, docs/, .git/, and artifact files. On COPILOT-BUILD-01 where multiple output-vN/ dirs accumulate, the build context can exceed 10GB before the actual build even starts.

Why implement it?
Large build context wastes I/O bandwidth and slows the COPY layer scanning step. Context transfer time is dead time that cannot be parallelised with the actual build steps. A .containerignore file is a one-time addition that pays off on every subsequent build.

Reasons to delay or skip?
No reason to defer. Zero risk — .containerignore only excludes files from the build context; it doesn't affect files already in the image or the build process itself.

----------------------------------------

Item 80  —  Boot-Time Disk Space and RAM Check
Priority: Medium   Difficulty: Easy   Risk: Low
Benefit: Provides a clear error message instead of mysterious failures when hardware is undersized

What is it?
inferno-configure.sh does not check available disk space or RAM before proceeding. On a node with a full /var partition or less than 2GB RAM, configure will fail in unpredictable ways mid-execution. An upfront check with a human-readable warning message is far better UX.

Why implement it?
Operators deploying to unknown or salvaged hardware get cryptic failures that are difficult to diagnose remotely. A WARNING: Only 512MB RAM detected, minimum 2GB required message at the top of the configure log immediately narrows the problem space.

Reasons to delay or skip?
Checks are non-fatal warnings, not blocking errors — the script continues regardless. This ensures unusual hardware that might work despite the warnings isn't accidentally blocked. Adjust thresholds if minimum hardware specs change.

----------------------------------------

Item 108  —  /usr/lib/bootc/kargs.d/ for Declarative Kernel Args
Priority: Medium   Difficulty: Easy   Risk: Low
Benefit: Kernel args version-controlled in the image, portable across build tools, no BIB config dependency

What is it?
Kernel arguments currently live in BIB's config.toml (kargs array). bootc natively supports /usr/lib/bootc/kargs.d/*.toml files baked into the image, which are applied at install time by the bootloader. This makes kernel args part of the container image (version-controlled, auditable) rather than a build-tool concern.

Why implement it?
BIB config.toml is external to the container image — it must be kept in sync with the Containerfile. Moving kargs into the image means the exact kernel arguments used are visible by inspecting the container, and they're applied consistently regardless of which build tool is used.

Reasons to delay or skip?
Requires bootc ≥ 0.1.13 (available on Fedora 43). Some kargs (e.g. installer-specific args) may still need to live in BIB config.

----------------------------------------

Item 101  —  PTP priority1 = 255 Slave-Only Enforcement
Priority: Medium   Difficulty: Easy   Risk: Low
Benefit: Prevents Inferno from accidentally winning PTP grandmaster election on a network with no other Dante master

What is it?
templates/inferno-ptpv1.toml uses priority1 = 251. IEEE 1588 BMCA: priority1 = 255 means "never become master" — the device explicitly refuses grandmaster election. At 251, if no other Dante device is visible, Inferno could win the BMCA election and become grandmaster with its unsynchronised free-running clock, causing every other Dante device to slew to an incorrect time reference.

Why implement it?
Inferno is a Dante endpoint/bridge, not a grandmaster clock. It should never be selected as PTP master. A professional install that loses its Dante grandmaster clock should not silently fall back to Inferno's local clock — it should log a fault.

Reasons to delay or skip?
In a standalone single-node test setup, priority1=255 means the node never has a master. statime should handle this gracefully (not crash), but behaviour should be verified.

----------------------------------------

Item 93  —  Auto-Hostname Conflict Detection
Priority: Medium   Difficulty: Easy   Risk: Low
Benefit: Prevents duplicate mDNS hostnames causing routing confusion on the AV network

What is it?
inferno-configure.sh sets the hostname to inferno- and Avahi advertises it as inferno-.local. If two nodes somehow get the same MAC suffix (theoretically impossible but seen with batch-ordered NICs using sequential MACs), or if nodes are cloned from the same VM snapshot, mDNS hostname conflicts occur. Avahi silently renames to inferno-73cf6b-2.local, confusing operators.

Why implement it?
mDNS hostname conflicts cause confusing duplicate entries in Dante Controller and make remote access unreliable (both nodes respond to the same .local name). Early detection with a warning in the configure log saves significant debugging time.

Reasons to delay or skip?
The avahi-browse check adds ~3 seconds to first-boot configure time. On a network with many nodes, the broadcast scan may miss late responders. This is a best-effort check, not a guarantee — document as such.

----------------------------------------

Item 69  —  Pin bootc-image-builder Image Version in Build Script
Priority: Medium   Difficulty: Easy   Risk: Low
Benefit: Reproducible ISO builds — same BIB version used every time; prevents silent ISO layout changes

What is it?
build/build-release.sh uses ghcr.io/osbuild/bootc-image-builder:latest — a floating tag. BIB updates can change ISO layout, Kickstart handling, partition schemes, or introduce breaking changes without notice. A BIB update between v23 and v24 builds could produce different installer behaviour silently.

Why implement it?
ISO build reproducibility requires a pinned toolchain. If a node in the field reports an installer problem that isn't reproducible, the first question is "what BIB version was used?" — which is currently unanswerable. Pinning to a specific digest answers that question definitively.

Reasons to delay or skip?
Pinning requires intentional version bumps, which means staying on an older BIB version longer than necessary. BIB is actively developed and may have bug fixes or security patches. Set a reminder to review the pin quarterly.

----------------------------------------

Item 111  —  cockpit.transport.wait() for Plugin Initialisation
Priority: Medium   Difficulty: Easy   Risk: Low
Benefit: Prevents intermittent "transport not ready" errors when Cockpit loads the inferno plugin

What is it?
cockpit-inferno init() runs immediately on DOMContentLoaded. Cockpit's official best practices recommend wrapping all init code in cockpit.transport.wait() to ensure the Cockpit transport channel is established before making cockpit.spawn() or cockpit.file() calls. Without this, slow Cockpit connections can result in silent init failures where the plugin loads but shows stale/empty data.

Why implement it?
Intermittent "plugin shows nothing on first load, refresh fixes it" reports are almost always caused by this race condition. One-line fix with no downside.

Reasons to delay or skip?
No reason to defer. Low-risk, high-confidence improvement.

----------------------------------------

Item 102  —  IGMP Multicast Group Membership for Dante
Priority: Medium   Difficulty: Easy   Risk: Low
Benefit: Prevents Dante control traffic drops on managed switches with IGMP snooping enabled

What is it?
Dante control uses multicast groups 224.0.0.107 and 224.0.1.129. On managed switches with IGMP snooping, the switch only forwards multicast frames to ports that have explicitly joined the group. NetworkManager reconfiguring the interface (e.g. DHCP renewal) can silently drop multicast group memberships, causing Dante discovery to stop working until the next restart.

Why implement it?
Dante "no devices" issues on managed-switch environments are often caused by dropped IGMP memberships. This is a low-effort fix that prevents an entire class of discovery failures in professional AV installs.

Reasons to delay or skip?
On unmanaged switches (the majority of home/small installs), IGMP snooping is not active and this change has no effect. Low risk.

----------------------------------------

Item 76  —  Explicit Systemd Service Dependencies Between User Services
Priority: Medium   Difficulty: Easy   Risk: Low
Benefit: Prevents race conditions; services start in correct order even after manual restarts

What is it?
User service units use After= for ordering but not Requires= or BindsTo= for lifecycle coupling. inferno-keepalive.service depends on inferno-bridge.service via After= but does not declare Requires=. If inferno-bridge is manually stopped, inferno-keepalive continues trying to write to a non-existent ALSA device, flooding the journal with errors.

Why implement it?
After= only controls start ordering at initial activation. BindsTo= stops the dependent service when its dependency stops — which is the correct behaviour for a keepalive process that feeds audio to a bridge that no longer exists.

Reasons to delay or skip?
BindsTo= is more aggressive than Requires= — if the bound service is stopped for maintenance, the dependent service also stops. Ensure that inferno-bridge stopping for a legitimate reason (config reload, upgrade) doesn't cascade to services that should survive the restart.

----------------------------------------

Item 88  —  Configurable PTP Domain Number
Priority: Medium   Difficulty: Easy   Risk: Low
Benefit: Supports mixed PTP environments where Dante uses a non-default PTP domain

What is it?
templates/inferno-ptpv1.toml hardcodes domain = 0. Dante uses PTP domain 0 by default, but some installations use domain 1 (e.g., certain Shure configurations) or domain 127. Operators with existing PTP infrastructure on non-default domains cannot use the default inferno configuration without manually editing template files after each image update.

Why implement it?
PTP domain mismatch is a common cause of "PTP not converging" support issues. Making the domain number configurable via /etc/inferno.conf allows operators to match their existing PTP infrastructure without modifying image files — following the same pattern already used for NIC name and device name substitution.

Reasons to delay or skip?
No reason to defer. Straightforward template variable substitution — the same mechanism already used for other template values.

----------------------------------------

Item 109  —  Bundle Manifest valid_from Anti-Replay Timestamp
Priority: Medium   Difficulty: Medium   Risk: Low
Requires first: Item 63 (signing enforcement)
Benefit: Prevents replay attacks that roll back nodes to known-vulnerable firmware versions

What is it?
IoT Updater bundle version.json manifest contains version, sha256, and signature — but no time-bounded validity window. An attacker who captures a valid signed bundle can re-serve it indefinitely to downgrade a node to a vulnerable version. A valid_from / valid_until field in the manifest, checked in apply-update.sh, closes this window.

Why implement it?
Downgrade attacks are a real threat model for appliances with known CVEs in older firmware. Bundle signing (Item 63) prevents unsigned bundles, but doesn't prevent replay of legitimately-signed old bundles.

Reasons to delay or skip?
Requires all existing bundles to be re-signed with timestamps. Nodes with incorrect system time would reject valid bundles. Must handle clock skew gracefully.

----------------------------------------

Item 82  —  Prometheus Metrics Endpoint via PCP
Priority: Medium   Difficulty: Medium   Risk: Low
Benefit: Enables integration with Grafana/Prometheus monitoring stacks for AV system visibility

What is it?
pcp (Performance Co-Pilot) is already installed for Cockpit metrics. PCP ships pmproxy which can expose PCP metrics as a Prometheus-compatible endpoint on port 44322 when run with --timeseries. This is not configured. PTP offset, audio xrun count, service uptime, CPU governor frequency, and disk utilisation are all available as PCP metrics.

Why implement it?
AV integrators with Grafana/Prometheus monitoring stacks want to pull metrics from all devices without SSH. PTP offset trends over time are particularly valuable — they reveal systematic clock drift patterns not visible in instantaneous Cockpit displays.

Reasons to delay or skip?
pmproxy adds a listening service on port 44322. This port must be added to the firewall config (Item 65). PCP's Prometheus format may not include all desired metrics out-of-the-box — custom PCP metrics for inferno-specific data (PTP offset, Dante status) would require additional development.

----------------------------------------

Item 96  —  Cockpit In-App Help / Troubleshooting Runbook
Priority: Medium   Difficulty: Medium   Risk: Low
Benefit: Reduces support requests; operators can self-diagnose the top 5 failure modes without SSH

What is it?
No in-app help or troubleshooting guidance exists in the Cockpit UI. Common issues — no Dante devices discovered, PTP not converged, audio not playing, OTA update fails — each have multiple root causes that require knowledge of the system architecture to diagnose. A "Help" tab or collapsible guidance panels would guide operators through the decision tree.

Why implement it?
AV operators are typically not Linux experts. "Dante shows no devices in Cockpit" has five possible causes (no cable, wrong NIC, mDNS filtered by switch, Dante device not powered, avahi-daemon not running). A guided decision tree in the UI narrows this to the actual cause in 30 seconds instead of 20 minutes of SSH debugging.

Reasons to delay or skip?
Help content requires maintenance — it must be updated when the system changes. Start with the 5 most common failure modes and expand as support patterns emerge from real deployments.

----------------------------------------

Item 81  —  User Action Audit Trail in Cockpit UI
Priority: Medium   Difficulty: Medium   Risk: Low
Benefit: Operational visibility — know who changed what and when on each node

What is it?
The IoT Updater sidecar has /var/lib/iot-updater/audit.log for update actions, but the main Cockpit plugin (inferno.js) has no audit trail. Mode changes, config saves, service restarts, and rollback actions performed via Cockpit are not logged anywhere operator-accessible. Cockpit does log to the journal, but Cockpit user actions (as distinct from system events) are not easily queryable.

Why implement it?
In a shared AV environment, knowing "who changed Dante device name at 14:32 on Tuesday" is critical for post-incident analysis. An audit trail in a human-readable structured log reduces mean time to diagnosis significantly.

Reasons to delay or skip?
Writing to a log file from Cockpit JavaScript requires a sudo tee -a call (see Item 62 — tee must be in the sudoers allowlist). This is an acceptable pattern but requires Item 62 to be implemented first for clean security scoping.

----------------------------------------

Item 85  —  DSCP/QoS Marking for Dante Audio Traffic
Priority: Medium   Difficulty: Medium   Risk: Medium
Requires first: 65
Benefit: Audio traffic prioritised over background traffic on shared networks; reduces latency jitter

What is it?
Dante uses DSCP EF (Expedited Forwarding, DSCP 46 / 0x2E) for audio RTP streams and CS7 for control. No DSCP marking is configured on the inferno appliance. On congested networks where audio packets compete with background traffic, unmarked packets may be deprioritised by QoS-aware switches, introducing latency jitter.

Why implement it?
The Dante specification recommends DSCP marking. Switches with QoS configured will prioritise EF-marked packets, providing up to 10x latency improvement under load. Critical for large Dante installations with 100+ audio channels where network contention is realistic.

Reasons to delay or skip?
DSCP marking is only effective if the network switches support and are configured for QoS. In small installations with unmanaged switches, DSCP marking has no effect. Risk: incorrectly marking non-audio traffic as EF could interfere with other QoS policies on the network.

----------------------------------------

Item 92  —  inferno-configure.sh Idempotent Re-Run Mode
Priority: Medium   Difficulty: Medium   Risk: Medium
Benefit: Allows reconfiguring NIC/name/mode without requiring a full reboot and sentinel deletion

What is it?
To reconfigure a deployed node today, an operator must rm /etc/inferno.conf && reboot — a blunt instrument that re-runs the full first-boot sequence. A targeted re-run mode (inferno-configure.sh --reconfigure --nic enp3s0) would re-detect hardware and rewrite configs without requiring a full reboot cycle. This is especially valuable during on-site troubleshooting.

Why implement it?
NIC changes, hostname corrections, mode switches (Spotify ↔ AUX), and audio card changes currently require full first-boot cycle including reboot. A --reconfigure flag that re-runs specific sections would cut on-site troubleshooting time from 5 minutes to under 30 seconds.

Reasons to delay or skip?
Medium risk: if --reconfigure partially succeeds (e.g., rewrites templates but fails before restarting services), the system can be left in an inconsistent state. Implement with careful error handling and rollback of template files if any step fails. Test on VMs before shipping.

----------------------------------------

Item 38  —  NIC Link-Down Recovery
Priority: Medium   Difficulty: Medium   Risk: Low
Requires first: Items 8, 9
Benefit: Audio resumes within seconds of cable re-plug instead of requiring 30–60 seconds of failed restarts

What is it?
When the Ethernet cable is unplugged, statime-inferno.service loses its PTP grandmaster and immediately fails. With Restart=always, it restarts — but the NIC has no carrier, so the next start attempt fails instantly too. This cycle repeats at the RestartSec= interval (default 100ms), flooding the journal and burning CPU. When the cable is re-plugged, the NIC must re-negotiate link (~2s), DHCP must renew (~5s), and ARP must resolve before Statime can reach the PTP grandmaster. The Restart=always loop may restart Statime before the network is ready, causing 3–5 more failures before it finally succeeds. Total recovery: 30–60 seconds of chaos.

Three targeted improvements collapse this to under 10 seconds:
After=network-online.target in statime-inferno.service — ensures the service only starts when NetworkManager reports the link is up and routable. Does not help with mid-run link loss, but prevents the initial start storm on boot with a slow NIC.
ExecStartPre carrier check — wait for the NIC carrier before attempting to start:
   
   This makes the service block at ExecStartPre (no failure) until the link is physically up, then proceed to start normally. Combined with Restart=always, link-down recovery becomes: cable re-plugged → carrier detected → ExecStartPre exits → Statime starts successfully. One restart, clean.
BindsTo=sys-subsystem-net-devices-.device — binds the service lifecycle to the kernel device object for the NIC. When the NIC is unplugged (device disappears), systemd stops the service cleanly. When the NIC reappears (cable re-plug or driver reload), systemd restarts it. This requires predictable NIC naming (item 10) because the device unit name is derived from the interface name.

Why implement it?
Network interruptions in a venue are common — someone trips over a cable, a switch is rebooted, a patch panel connection is jostled. The current behaviour (30–60s of restart storm) is operator-visible: audio cuts out, Cockpit shows service failures, the journal fills with errors. The improvements make the failure mode silent and self-healing in < 10 seconds, which matches what operators expect from a professional audio appliance.

Reasons to delay or skip?
Defer BindsTo=sys-subsystem-net-devices-.device until Items 8 and 9 are complete and the NIC name is reliably known at boot time. The After=network-online.target and ExecStartPre carrier check have no dependencies and should be implemented immediately.

----------------------------------------

Item 61  —  Cockpit Plugin Update Without Full Image Rebuild
Priority: Medium   Difficulty: Medium   Risk: Low
Benefit: Cockpit UI fixes deployable in minutes instead of requiring a 45–60 minute full image rebuild

What is it?
/usr/share/cockpit/inferno/ is read-only in the bootc image. Every UI-only fix (layout, labels, a missing status indicator) requires a full image build cycle. The ~/.local/share/cockpit/inferno/ path is writable and Cockpit checks it first, but it requires manual SSH deployment of plugin files.

Why implement it?
A 45–60 minute build cycle for a one-line UI fix is impractical during active customer deployments. A signed update script that replaces only the Cockpit plugin files enables hotfixes within minutes. This also reduces the pressure to batch unrelated changes into releases, improving overall code quality.

Reasons to delay or skip?
Out-of-band UI updates bypass the normal image build/test/sign pipeline. Plugin updates must be separately versioned and verified to avoid divergence between the appliance image version and the UI version. Adds complexity to version tracking.

----------------------------------------

Item 99  —  NIC Interrupt Pinning Away from RT CPUs
Priority: Medium   Difficulty: Medium   Risk: Medium
Requires first: Item 98
Benefit: Prevents NIC IRQ handler from running on RT-isolated CPUs during PTP timestamp exchanges

What is it?
threadirqs makes IRQs run as kernel threads (good), but irqbalance migrates them freely — including onto RT-isolated CPUs. A NIC interrupt landing on CPU 2 during a PTP hardware timestamp exchange introduces unbounded jitter. The fix is to mask irqbalance and manually pin NIC IRQs to non-isolated CPUs.

Why implement it?
Even with isolcpus, unmanaged IRQ migration can breach isolation boundaries. IRQ pinning is the standard complement to CPU isolation in RT audio workloads.

Reasons to delay or skip?
Manual IRQ pinning via /proc/irq/*/smp_affinity is fragile across driver updates and reboots. NetworkManager restarting the interface can reset IRQ assignments. Requires careful implementation.

----------------------------------------

Item 95  —  Cockpit Configuration Export/Import
Priority: Medium   Difficulty: Medium   Risk: Low
Benefit: Enables mass provisioning of multiple nodes with identical config; backup/restore of node settings

What is it?
There is currently no way to export a node's configuration (INFERNO_NAME, INFERNO_NIC, INFERNO_MODE, etc.) from Cockpit or restore it. Operators with 10 identical nodes must configure each manually. A "Export Config" button and "Import Config" upload in the Cockpit Config tab would significantly speed up fleet provisioning.

Why implement it?
AV installs frequently have multiple identical nodes — backup receivers, multiple venues, staging/production pairs. Config export/import accelerates deployment from hours to minutes for large fleets. Config export also serves as an implicit backup mechanism.

Reasons to delay or skip?
Imported configs must be validated before applying — importing a config intended for different hardware (different NIC name) could break network connectivity. Add validation: check that INFERNO_NIC value exists as a network interface on the target node.

----------------------------------------

Item 89  —  PTP Offset Alerting Threshold
Priority: Medium   Difficulty: Medium   Risk: Low
Requires first: 74
Benefit: Proactive notification when PTP drift exceeds safe range for Dante audio quality

What is it?
PTP offset is displayed in the Cockpit Services tab but no alerting occurs when offset exceeds a threshold. If PTP drifts beyond 1ms (the danger zone for Dante), the operator only knows if actively watching the Cockpit UI. Dante can tolerate ~1ms PTP offset but audio quality degrades and device connections may drop above this.

Why implement it?
PTP offset exceeding threshold is one of the most common causes of intermittent audio glitches in Dante installations. Automated alerting via the Cockpit UI (orange/red indicator change) enables operators to catch and diagnose the problem before it causes audible artefacts. The continuous monitor (Item 74) provides the infrastructure for this check.

Reasons to delay or skip?
Requires Item 74 (continuous monitoring daemon) to provide the periodic PTP offset reading. Implement Item 74 first, then add the alerting threshold check as an additional step in inferno-monitor.sh.

----------------------------------------

Item 74  —  Continuous Health Monitoring Daemon
Priority: Medium   Difficulty: Medium   Risk: Low
Benefit: Detects service failures within minutes instead of waiting for operator to open Cockpit

What is it?
inferno-health-check.service runs ONCE at 120 seconds after boot. After that, no continuous monitoring occurs. If statime-inferno dies at hour 6, nobody knows until someone opens Cockpit. Production appliances need self-monitoring that runs continuously and exposes status to both Cockpit and external tools.

Why implement it?
Silent degraded state — PTP running but not converged, audio playing but with xruns, librespot active but not streaming — is undetectable without continuous monitoring. A simple periodic script writing to a status JSON file that Cockpit can read provides the monitoring foundation for Items 81, 82, 83, and 89.

Reasons to delay or skip?
A monitoring daemon that itself crashes would leave the system unmonitored without indication. Use a systemd.timer rather than a long-running daemon — timer failures are visible in systemctl status and the timer automatically retries.

----------------------------------------

Item 83  —  Central Logging via systemd-journal-remote
Priority: Medium   Difficulty: Medium   Risk: Low
Benefit: All inferno nodes ship logs to a central location for fleet-wide aggregation and alerting

What is it?
Each node logs only to its local journal. There is no mechanism to collect logs from multiple inferno nodes centrally. systemd-journal-remote (push mode via systemd-journal-upload) can forward journal entries to a central systemd-journal-gatewayd or Loki/Graylog endpoint, enabling fleet-wide log search.

Why implement it?
A fleet of inferno nodes at a production venue requires a single place to search logs — "did any node lose PTP sync in the last hour?" currently requires SSH-ing to each node individually. Central logging enables alerting on PTP loss, service failures, and OTA update outcomes across the entire fleet.

Reasons to delay or skip?
Central logging requires a receiving server — this is operator infrastructure that inferno cannot provide. The implementation on the inferno side is minimal (configure journal-upload with a URL), but the feature is only valuable when the operator has a central log server.

----------------------------------------

Item 58  —  PREEMPT_RT Kernel Option
Priority: Medium   Difficulty: Hard   Risk: High
Benefit: Sub-100µs scheduling latency for statime/inferno-bridge vs. current ~500µs with PREEMPT_DYNAMIC

What is it?
The current Fedora IoT 43 kernel uses PREEMPT_DYNAMIC with preempt=full (full preemption, soft-RT). True PREEMPT_RT requires the Linus RT patchset and shows as PREEMPT_RT in uname -a. Fedora ships kernel-rt in its repos since F38, making it installable via dnf. PREEMPT_RT reduces worst-case scheduler latency from ~500µs to ~50µs — a measurable improvement in PTP jitter under CPU load.

Why implement it?
cyclictest P99 latency with PREEMPT_RT is typically 50µs vs. 500µs with PREEMPT_DYNAMIC. For Dante AES67 with tight PTP requirements, reducing worst-case jitter by 10x directly improves audio quality under load. The improvement is most visible on nodes running multiple concurrent workloads (librespot + iradio + cockpit updates).

Reasons to delay or skip?
kernel-rt is a separate package not in fedora-bootc:43 by default. Replacing the kernel adds ~200MB to the image and requires extensive hardware compatibility testing. bootc may have constraints on non-standard kernels. Dante audio works acceptably with PREEMPT_DYNAMIC for most deployments — this is a marginal improvement for demanding installs, not a fix for a broken feature. Estimate: 3–5 days including testing across all target hardware.

----------------------------------------

Item 86  —  VLAN Interface Support for Dante AoIP Network
Priority: Medium   Difficulty: Hard   Risk: Medium
Benefit: Supports dedicated AoIP VLANs — standard practice in professional AV installations

What is it?
Professional AV installations typically use a dedicated VLAN for Dante traffic (e.g., VLAN 10 for AoIP, VLAN 1 for management). Currently, inferno uses the same NIC and VLAN for both management (Cockpit, SSH) and Dante audio. Supporting INFERNO_DANTE_VLAN=10 in the config would allow creating a VLAN sub-interface for Dante traffic while management stays on the native interface.

Why implement it?
Dedicated Dante VLANs: (1) isolate audio multicast from management traffic, (2) enable per-VLAN QoS policies on managed switches, (3) match the Audinate recommended deployment architecture for large installs. Many enterprise AV integrators require this for compliance with their network segmentation policies.

Reasons to delay or skip?
Hard difficulty and medium risk reflect the complexity of creating VLAN interfaces via NetworkManager, ensuring Dante binds to the VLAN interface instead of the native NIC, handling the PTP vs. management interface split, and testing across different switch configurations. Defer until the simpler items (DSCP, domain config) are in place.

----------------------------------------

Item 73  —  BATS Test Suite for Shell Scripts
Priority: Medium   Difficulty: Hard   Risk: Low
Benefit: Catches regressions in inferno-configure.sh, apply-update.sh, and health checks before they reach production

What is it?
No automated tests exist for any shell script in the project. inferno-configure.sh (254 lines), apply-update.sh, inferno-health-check.sh, and build-release.sh contain complex conditional logic (NIC detection, PTP capability, version comparison, bundle hash verification) that is currently tested only by manual VM testing.

Why implement it?
Shell scripts have subtle edge cases — empty $NIC, no carrier, wrong version format, missing config file — that manual testing rarely exercises. BATS (Bash Automated Testing System) allows unit-testing shell functions in isolation with mock ip, ethtool, and systemctl stubs. A test suite that runs in CI would catch regressions before they reach production builds.

Reasons to delay or skip?
Writing BATS tests for existing scripts requires understanding every code path — this is inherently time-consuming for complex scripts. The investment pays off over time but requires initial commitment. A phased approach: start with the highest-value tests (NIC detection, version comparison) and expand incrementally.

----------------------------------------

Item 110  —  SELinux Policy Module for inferno_aoip
Priority: Medium   Difficulty: Hard   Risk: Medium
Requires first: BUG-05, Item 59, Item 106
Benefit: Proper MAC confinement for all inferno processes — moves beyond relying on inherited unconfined contexts

What is it?
All inferno user services currently inherit generic SELinux contexts (unconfined_t or init_t depending on how they're launched). A custom inferno_aoip policy module would confine them to only the files, capabilities, and network operations they actually need — providing defence-in-depth beyond capability sandboxing.

Why implement it?
Fedora 43 ships with SELinux enforcing by default. Custom policy closes the gap between "running in enforcing mode" and "actually confined" — the current state has SELinux enforcing but inferno processes running as unconfined, giving a false sense of security.

Reasons to delay or skip?
Writing a correct SELinux policy is complex and time-consuming. Overly tight policy will break statime (raw sockets), ALSA (device access), or inferno-bridge. Requires a dedicated testing cycle. Defer until after RT stabilisation items (97-99) are stable.

----------------------------------------


============================================================
LOW PRIORITY IMPROVEMENTS
============================================================

Item 60  —  dante-network-bench.sh Default Timeout 3s → 8s
Priority: Low   Difficulty: Easy   Risk: Low
Benefit: Consistent device discovery between bench script and Cockpit monitoring; no missed devices on slower networks

What is it?
scripts/bench/dante-network-bench.sh defaults to MDNS_TIMEOUT=3. The Cockpit scanDanteDevices() function uses 8 seconds. On networks where Dante devices are slow to respond (VLAN boundaries, upstream routers, heavily loaded switches), the 3-second scan misses devices that the 8-second Cockpit scan catches. This causes confusing discrepancies between bench results and Cockpit results.

Why implement it?
Consistency between tooling. If Cockpit finds 8 devices and the bench script finds 6, operators assume the bench script is broken — or worse, that Cockpit is showing stale data. Aligning the timeouts removes that confusion.

Reasons to delay or skip?
No reason to defer. One-line change, zero risk.

----------------------------------------

Item 67  —  Remove/Redact Hardcoded IPs from Bench Scripts
Priority: Low   Difficulty: Easy   Risk: Low
Benefit: Removes confusion for external operators copying bench commands from examples

What is it?
scripts/bench/ptp-bench.sh, audio-loopback-test.sh, and stress-bench.sh have hardcoded example IPs (192.168.1.43, 192.168.1.25) in comments and default variable values. Operators copy-pasting these commands may accidentally target wrong nodes or be confused by errors from the placeholder IPs.

Why implement it?
Documentation quality and operator safety. Hardcoded IPs in bench scripts look like they should work and cause confusing errors when they don't. Placeholder-style documentation () is unambiguous.

Reasons to delay or skip?
No reason to defer. Purely documentation cleanup, zero risk.

----------------------------------------

Item 94  —  librespot Cache Size Limit
Priority: Low   Difficulty: Easy   Risk: Low
Benefit: Prevents Spotify audio cache from filling /var on long-running nodes

What is it?
librespot.service uses --cache /var/home/core/.cache/librespot with no size limit. librespot caches decoded audio to reduce buffering on repeat tracks. On a node used heavily for Spotify, this cache can grow to several GB over months, potentially filling /var and preventing journal writes, OTA bundle staging, and other critical operations.

Why implement it?
/var is the writable partition in bootc. Cache growth is silent and unbounded. A simple --cache-size-limit 512 flag in the librespot ExecStart caps the cache at 512MB — more than sufficient for smooth playback while protecting system stability.

Reasons to delay or skip?
No reason to defer. One flag addition to the service unit, zero risk.

----------------------------------------

Item 70  —  Add --setopt=tsflags=nodocs to DNF Install
Priority: Low   Difficulty: Easy   Risk: Low
Benefit: ~50–100MB image size reduction; no documentation needed on a headless appliance

What is it?
Containerfile dnf install commands do not include --setopt=tsflags=nodocs. Man pages, info pages, locale files, and documentation installed with each package are unnecessary on a headless audio appliance that has no document viewer.

Why implement it?
50–100MB of image savings across all packages is meaningful for OTA updates — it reduces download time, extraction time, and bootc overlay storage usage. This is especially significant on nodes with slow storage.

Reasons to delay or skip?
Removing docs makes man and info commands non-functional on the node. If operators SSH in to debug and expect man pages, they will find them missing. Document this clearly. No meaningful reason to defer otherwise.

----------------------------------------

Item 71  —  Tag Releases on Submodule Repositories
Priority: Low   Difficulty: Easy   Risk: Low
Benefit: Enables version traceability; allows pinning submodule versions to specific appliance releases

What is it?
cockpit-inferno, cockpit-iot-updater, and inferno-branding submodules have no version tags. The build uses --remote to pull the latest commit from each submodule — meaning a breaking change in cockpit-inferno between build triggers silently enters the next appliance release.

Why implement it?
Version tags on submodules enable: (1) traceability — know exactly which cockpit-inferno commit is in v23, (2) reproducible builds — pin --remote fetch to a tag instead of HEAD, (3) staged rollout — test a new UI version before including it in an appliance release.

Reasons to delay or skip?
Adds a small overhead to the release process: tag each submodule repo before triggering the appliance build. Can be scripted as part of build-release.sh to remove friction.

----------------------------------------

Item 91  —  statime Log Level: Reduce from trace to info in Production
Priority: Low   Difficulty: Easy   Risk: Low
Benefit: Reduces journal noise by ~95% from statime; reduces disk I/O on RT workloads

What is it?
templates/inferno-ptpv1.toml sets loglevel = "trace". Trace logging outputs every PTP packet, clock adjustment, and internal state change — extremely verbose. On a busy PTP network this generates thousands of lines per minute, causing measurable disk I/O that can introduce scheduling jitter on RT workloads.

Why implement it?
Trace logging was appropriate during development and debugging but should not be the production default. The disk I/O from continuous trace logging is a real (if small) source of scheduling interference. info level logs PTP convergence events and errors — sufficient for production monitoring.

Reasons to delay or skip?
Trace logging is invaluable for diagnosing PTP convergence issues in the field. Consider making the log level configurable via /etc/inferno.conf rather than hardcoding info — operators can re-enable trace when debugging without rebuilding the image.

----------------------------------------

Item 77  —  Restart Backoff Strategy for Flapping Services
Priority: Low   Difficulty: Easy   Risk: Low
Benefit: Prevents rapid restart loops from consuming CPU and filling the journal when services crash on startup

What is it?
All services use fixed RestartSec=3 or RestartSec=5. If a service crashes immediately on start (e.g., missing config, bad audio device), it restarts every 3s indefinitely, flooding the journal and wasting CPU. systemd v254+ supports RestartSteps and RestartMaxDelaySec for exponential backoff. Fedora 43 ships systemd v255+.

Why implement it?
Exponential backoff converts a tight restart loop (3s, 3s, 3s...) into a progressively slower series (3s, 6s, 12s..., up to 120s). This reduces journal noise by ~95% for a broken service and allows operators to notice the problem without being overwhelmed by log volume.

Reasons to delay or skip?
No meaningful reason to defer. Purely additive change, no behaviour change for services that start cleanly.

----------------------------------------

Item 72  —  Consolidate Containerfile RUN Layers
Priority: Low   Difficulty: Medium   Risk: Low
Benefit: Fewer intermediate image layers; slightly faster build and reduced storage overhead

What is it?
Containerfile currently has ~13 separate RUN commands for configuration and setup (lines 68–245). Many of these could be consolidated into 2–3 grouped blocks without sacrificing cache efficiency, since they all sit in the stable-config zone below the main cache boundary (package install layer).

Why implement it?
Each RUN creates an intermediate image layer in podman/OCI storage. Fewer layers means less storage overhead on the build host and slightly faster image inspection via podman history. A cleaner Containerfile is also easier to review and maintain.

Reasons to delay or skip?
Overly aggressive consolidation can break the cache optimisation strategy: the layer boundary between "slow/expensive" package install and "fast/cheap" config should be preserved. Avoid consolidating across the cache boundary. Test build times with and without the change to confirm benefit.

----------------------------------------

Item 90  —  Internet Radio (iradio) Channel/Station Management in Cockpit
Priority: Low   Difficulty: Medium   Risk: Low
Benefit: Operators can manage iRadio stations from Cockpit without SSH

What is it?
iRadio mode is supported via the iradio-bridge submodule and the Cockpit mode switcher. However, station management — adding, removing, and reordering internet radio station URLs — requires SSH and direct editing of the iradio config file. The Cockpit Config tab shows an iradio mode option but no inline station editor.

Why implement it?
iRadio mode is a value-add feature that differentiates inferno from a basic Dante device. Operators using iRadio mode should be able to manage their station list from the same Cockpit interface they use for everything else. Requiring SSH for station management undermines the "no SSH needed" operator story.

Reasons to delay or skip?
iRadio is a secondary feature; implement after the core audio features are stable. Station management requires reading/writing a TOML config file via Cockpit — use cockpit.file() API for this.

----------------------------------------

Item 84  —  SNMP v2c Read-Only Agent
Priority: Low   Difficulty: Hard   Risk: Low
Benefit: Integration with AV system management platforms (QSC, Crestron, Extron) that use SNMP for device monitoring

What is it?
Professional AV environments frequently use AMX, Crestron, or QSC control systems that poll devices via SNMP for status monitoring. A read-only SNMPv2c agent exposing: system uptime, service status OIDs, PTP offset, and audio device status would enable integration with these management platforms without custom API development.

Why implement it?
High value for professional installs. Many AV operators and integrators evaluate solutions based on SNMP support — it's a standard requirement in tender documents for installed AV systems. Even a basic MIB with system uptime and service status would satisfy most requirements.

Reasons to delay or skip?
net-snmp adds ~20MB to the image. SNMP configuration (community strings, MIB definitions, trap destinations) is complex and varies per installation. SNMPv2c uses plaintext community strings — a security concern. Consider deferring until SNMPv3 (auth + encryption) can be implemented.

----------------------------------------


============================================================
End of open improvements. Total: 59 items.
============================================================