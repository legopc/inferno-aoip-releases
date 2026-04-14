# Inferno AoIP Appliance — Improvement Roadmap Version Two, Narrated

This document covers fifty new improvements found through a detailed audit of the Inferno AoIP appliance, known as Virgil, and the surrounding ecosystem including Minos, inferno-central, and the node agent. None of these items duplicate anything in the original roadmap. They were found by reading the actual source code across six repositories. Three items are critical confirmed bugs that exist right now in production.

---

## Overview

The fifty items are grouped into five areas: security, audio and real-time performance, the Cockpit user interface and operations, the build pipeline and deployment, and ecosystem integration. Of the fifty items, three are rated critical, twenty-five are high importance, and twenty-two are medium. Thirty-one of them are easy fixes taking under two hours each. Seventeen are medium effort taking about half a day. Only two require multi-day work.

There are eleven items that stand out as quick wins — they are high or critical importance and each takes under two hours to fix. Those are called out individually later in this document.

---

## Section One: Security

This section covers ten security issues found by reading the systemd unit files, the Cockpit plugin source code, the IoT updater server, and the network-facing daemon configurations. Several of these are confirmed vulnerabilities with direct exploit paths.

### Issue One: The statime service explicitly allows privilege escalation

This is rated critical. The Precision Time Protocol daemon called statime has a configuration file that explicitly sets a flag called NoNewPrivileges to the value no. This is the only service in the entire codebase with this flag set to that insecure value. What this means in practice is that if the statime process were ever compromised, it could call any program on the system that has elevated permissions baked in — sometimes called setuid binaries — and use those to gain full root access. Even if you separately restrict which kernel capabilities statime is allowed to use, this flag bypasses those restrictions at the moment a new program is launched. The fix is literally a single character change in one configuration file. Statime only needs two capabilities to do its job and never needs to call any elevated helper program.

### Issue Two: SNMP credentials stored in a world-readable file

This is rated high importance. When an operator configures the SNMP network monitoring feature through the Cockpit web interface, the authentication passwords — including version three auth and privacy passphrases — get written to the main configuration file at slash-etc-slash-inferno.conf. The problem is that this file is created with default permissions that allow any process on the system to read it. No permission tightening happens after the file is written. This means any running service — the SNMP daemon itself, the IoT updater, the metrics collector — can read those passwords directly from disk. The fix involves changing how the file is written so it is only readable by root and the core user group.

### Issue Three: The firmware update endpoint has no authentication

This is rated high importance. The IoT updater sidecar runs as root and listens on a local network port. It generates a random session token when it starts up, and there is an endpoint that returns this token to anyone who asks — with no authentication check at all. Once a process has this token, it can use it to deploy new firmware or roll back the operating system. Any service running on the device, even an unprivileged one like the Avahi discovery daemon or the SNMP daemon, could obtain this token and trigger a firmware change without any operator involvement. The browser-based security check only protects against web browser requests, not direct socket connections. The fix is to stop exposing this token over a plain network socket and instead use a protected channel that only trusted processes can access.

### Issue Four: Cockpit command execution is vulnerable to injection via device names

This is rated high importance. The Cockpit plugin has a function that runs system commands by building a command string through text concatenation. When an operator types a Spotify device name or a Dante device name into the configuration form, that text is embedded directly into a shell command without any sanitisation or escaping. If someone enters a device name containing shell control characters — for example a semicolon followed by another command — that second command executes as root. The fix is to stop building shell commands from user input entirely, and instead use the structured file editing tools that Cockpit already provides.

### Issue Five: All user-space services have zero security restrictions

This is rated high importance. Every background service that runs as the core user — including the Spotify bridge, the audio loopback service, the keepalive service, and the auxiliary audio services — has no security directives in its configuration at all. None of them restrict which directories they can write to, which system calls they can make, or whether they can spawn new privileged processes. The Spotify service in particular processes untrusted audio data from the internet, including audio files and metadata from Spotify's content delivery network. A vulnerability in that service would give an attacker unrestricted access to the entire home directory, all service configuration files, and the authentication token cache. Adding a small set of standard hardening directives to each service would significantly reduce the blast radius of any future vulnerability.

### Issue Six: The SSH daemon has no hardening configuration

This is rated high importance. The SSH server is installed and enabled but there is no custom configuration file for it anywhere in the codebase. Fedora's default SSH settings allow six password attempts per connection, keep idle sessions alive indefinitely, and enable X forwarding for graphical applications — none of which are needed on this appliance. None of these gaps are covered by any existing roadmap item. Adding a single configuration drop-in file with a small set of standard directives — reducing max auth attempts, setting an idle timeout, and disabling unused features — would close these gaps without affecting normal SSH access. This is one Containerfile addition.

### Issue Seven: The SNMP daemon listens on all network interfaces

This is rated medium importance. The SNMP configuration binds to all network interfaces, meaning it is reachable from both the management network and the Dante audio network. In a typical audio-over-IP installation, the Dante network segment also carries AV control equipment from manufacturers like Cisco, QSC, and Crestron. Exposing SNMP, including the version two community string which is sent in plain text, to that segment allows any device on the network to query or fingerprint the appliance. The fix is to bind SNMP to only the management interface.

### Issue Eight: The Avahi discovery daemon advertises management services on the audio network

This is rated medium importance. The Avahi multicast DNS daemon is enabled with no interface filtering configuration. By default it responds to discovery queries on all network interfaces and advertises all registered services. This means SSH on port twenty-two and Cockpit on port nine-thousand-and-ninety are discoverable by audio equipment on the Dante broadcast domain — switches, amplifiers, DSPs, and other Dante nodes. The fix is to add a configuration file that restricts which interfaces Avahi responds on.

### Issue Nine: The first-boot configuration service has no sandboxing

This is rated medium importance. The service that runs on first boot to configure the appliance runs as root with no kernel protection directives. It calls several external programs — tools to probe network card capabilities, list audio hardware, and set the hostname — all as the root user with unrestricted access to kernel state. Adding protective directives that prevent the service from modifying kernel tuning parameters or kernel logs would provide meaningful defence in depth without affecting how the service functions, since it does not actually need those capabilities.

### Issue Ten: The Spotify credential cache is readable by other services

This is rated medium importance. Librespot, the open-source Spotify client, stores its authentication credentials in a cache directory. The directory and files are created with default permissions that allow root processes to read them. The IoT updater service explicitly runs as root, so it can read the Spotify credential file at any time. While this is not a raw password, it is a reusable device authentication token that could be replayed to access the Spotify account. The fix is two lines: create the cache directory with restricted permissions during first-boot configuration, and add a file permission mask directive to the librespot service unit.

---

## Section Two: Audio and Real-Time Performance

This section covers ten issues found by reading the ALSA audio configuration files, the systemd service units for audio components, and the Rust source code of the internet radio bridge. Several of these are confirmed bugs with direct audio quality impact on every active deployment.

### Issue One: The audio loopback is missing its clock drift compensation flag

This is rated critical. The service that bridges Spotify audio into the Dante network uses a tool called alsaloop to transfer audio between two different clock domains — the Linux kernel timer and the Precision Time Protocol clock used by Dante. The service configuration file contains a comment that explicitly says the clock drift synchronisation flag should be enabled. However, the actual command line in the same file does not include that flag. Without it, the two clock domains drift apart by several parts per million, which guarantees an audio interruption roughly every few minutes as the gap becomes too large to bridge. The comment documenting the intended fix is literally sitting next to the broken command line. This is a single flag addition.

### Issue Two: The audio mixing buffer is too small for its transfer window

This is rated high importance and depends on the previous fix. The ALSA digital audio mixing configuration creates a buffer of about twenty-one milliseconds, while the audio loopback tool is configured to transfer audio in twenty-millisecond chunks. That leaves only one millisecond of headroom between when audio is needed and when it must be ready. Linux scheduler timing on this configuration typically varies by two to eight milliseconds under normal load, which is two to eight times larger than the available headroom. Buffer underruns are near-certain under any meaningful system activity. Doubling the buffer to about forty-two milliseconds preserves the effective latency while making the system far more resilient to normal scheduling variation.

### Issue Three: The Spotify service has no real-time scheduling priority

This is rated high importance. The librespot service correctly locks its memory to prevent it from being swapped out, which is good. But it has no CPU scheduling directives, meaning it runs at normal priority alongside everything else on the system. When Cockpit processes a web request, or the metrics collector runs, or the IoT updater is active, the Spotify audio writing thread can be delayed long enough to cause an underrun in the audio buffer. Setting the service to run at a real-time scheduling priority just below the PTP clock daemon would ensure it only gets preempted by the most time-critical tasks. The core user already has the necessary permissions to do this — no new capabilities are required.

### Issue Four: The internet radio resampler uses minimum quality settings

This is rated high importance. When the internet radio bridge receives audio at forty-four-point-one kilohertz — which is common for MP3 streams — it must resample it to forty-eight kilohertz for Dante. The resampler library being used has a quality parameter that controls how well it suppresses frequencies that should not be present in the output. The current setting provides about sixty decibels of suppression, which is below the threshold for broadcast quality audio. Broadcast standard requires at least ninety-six decibels. Increasing this parameter to eight, up from the current value of two, would bring it to broadcast standard with only a modest increase in processing load.

### Issue Five: The internet radio ALSA output starts too early

This is rated high importance. When the internet radio bridge opens its audio output device, it does not configure the software parameters that control when the device starts consuming audio. The default behaviour is to start as soon as a single audio period has been written. But the decode pipeline may not yet have produced enough audio to keep up continuously, so the output can underrun immediately on startup before the decode chain has had time to fill its buffer. Setting the start threshold to require a fuller buffer before consumption begins would eliminate these cold-start dropouts.

### Issue Six: The internet radio pre-roll buffer is too small

This is rated medium importance. When starting an internet radio stream, the player waits until it has accumulated eight kilobytes of compressed audio data before it begins decoding. At a typical bitrate of one hundred and twenty-eight kilobits per second, eight kilobytes is only about half a second of compressed audio — barely enough to decode a single audio period. On lower bitrate stations, which are common for digital audio broadcast simulcasts, this margin is even tighter. The decode pipeline runs out of data almost immediately, producing a silence gap at the beginning of every internet radio session. Increasing the pre-roll threshold to sixty-four kilobytes would provide four seconds of buffer at typical bitrates, eliminating startup dropouts.

### Issue Seven: Audio dropout events are invisible to the monitoring system

This is rated medium importance. The node agent exposes CPU usage, memory, disk space, uptime, PTP clock offset, and network traffic statistics. It reports nothing about the audio pipeline. The Linux kernel tracks how many times the audio hardware has experienced an underrun or overrun, and this information is available through the proc filesystem in a stable location. Exposing these counts through the metrics endpoint would give inferno-central a concrete audio quality signal for trending and alerting, rather than relying on a binary up-or-down status.

### Issue Eight: The PTP clock intervals are not configured for Dante compatibility

This is rated medium importance. The statime PTP configuration file does not specify sync message intervals, announce intervals, or holdover timeout values. The daemon inherits whatever was compiled in as defaults. Dante devices, including the Shure hardware confirmed in official documentation, expect specific timing intervals for clock synchronisation. If the statime compiled defaults differ from what Dante expects, synchronisation takes longer to converge and is more sensitive to network timing variation. Both intervals should be explicitly set in the configuration file rather than relying on unspecified library defaults.

### Issue Nine: The internet radio slot keeper silently stops on plugin failure

This is rated medium importance. The slot keeper component that holds the Dante audio slot continuously writes either audio or silence to the output device. If the write operation fails because the underlying ALSA plugin has crashed or become unavailable — for example because the plugin process was restarted — the error is silently discarded and the slot keeper continues its loop writing nothing. The startup code already has a retry mechanism for initially opening the device. That same pattern should be applied at runtime: if a write fails and cannot be recovered, the device should be closed, a short pause taken, and then re-opened — recovering audio automatically without requiring a manual service restart.

### Issue Ten: The Spotify output has no loudness normalisation

This is rated medium importance. The librespot service has a volume control mode configured, but the loudness normalisation flag is absent. Spotify encodes normalisation metadata in its audio stream that librespot can use to adjust playback level at decode time. Without it, a loud pop track encoded near full volume and a quiet classical track encoded much lower both pass through at their original levels, producing differences of up to seventeen decibels at the Dante input. In a broadcast context this is unacceptable. Adding the normalisation flag with a small safety headroom would provide consistent output levels with no latency penalty.

---

## Section Three: Cockpit User Interface and Operations

This section covers ten issues found by reading the cockpit-inferno JavaScript source and the internet radio web interface. One of these — issue five — is a confirmed silent runtime bug affecting all non-Spotify deployments right now.

### Issue One: Internet radio controls are not embedded in Cockpit

This is rated high importance. When the appliance is in internet radio mode, the Cockpit interface shows only a link that takes the operator to a separate browser tab running the standalone internet radio interface. The Cockpit plugin makes no calls to the internet radio API at all. There is no playback status, no now-playing information, and no stop controls within Cockpit itself. The internet radio bridge has a fully documented REST API. A compact player panel embedded directly in Cockpit would let operators manage internet radio streams without leaving the management interface.

### Issue Two: Spotify account connection status is not shown in Cockpit

This is rated high importance. The Cockpit configuration panel shows only the Spotify device name. It does not indicate whether librespot has successfully authenticated to Spotify or is running in an unauthenticated state where audio will not play. The current method for detecting playback state involves searching the system log for specific text strings, which is fragile and can miss state transitions. The authentication state can be determined safely by checking whether the credentials cache file exists, without exposing the credentials themselves. Several configuration fields in the Cockpit interface are permanently disabled with no explanation shown to the operator.

### Issue Three: The PTP performance panel is missing statistical metrics

This is rated high importance. The Precision Time Protocol performance panel shows only the current instantaneous clock offset and synchronisation state. It does not calculate standard deviation, peak-to-peak variation, or mean offset — even though all the historical data needed to calculate these is already stored in memory, covering up to fifteen minutes of samples. Dante audio-over-IP can tolerate brief clock spikes but fails on sustained high jitter. A jitter figure gives operators a meaningful quality metric that the current graph cannot convey. No new data sources are needed — this is purely a calculation and display addition.

### Issue Four: Internet radio stream URLs are not validated before use

This is rated medium importance. The internet radio quick-play form checks only that the URL field is not empty before attempting to start a stream. There is no check that the URL is correctly formatted, that the hostname resolves, or that the stream is actually serving audio. When an invalid URL is submitted, the player enters an error state but this error is only visible inside the standalone internet radio interface, not in Cockpit. The error information already exists in the player state — it just is not being surfaced in the right place.

### Issue Five: The Restart All button is completely broken in non-Spotify modes

This is rated critical. In the Services tab, there is a button to restart all active services. The code that implements this checks the current mode and, for Spotify mode, restarts the correct set of services. For any other mode — including aux input, aux output, aux bidirectional, and internet radio — it tries to restart a variable called AUX_SVCS. This variable is not declared anywhere in the two-thousand-six-hundred-and-sixty-one line file. JavaScript resolves an undeclared variable to undefined, so the restart command attempts to restart a service named literally "undefined", which fails silently. The correct helper function to get the right service list for the current mode already exists in the same file and is already used by other parts of the code. The fix is replacing one identifier with a call to that existing function.

### Issue Six: The health check panel is missing critical network pre-flight tests

This is rated high importance. The current health check panel verifies seven things: that the audio loopback module is loaded, that PTP is synchronised, that services are active, that disk usage is below eighty percent, and that the network interface has an IP address. It does not check four of the most common causes of Dante audio failures in the field: whether multicast traffic is reaching the network, which is required for all Dante audio flows; whether the network interface is configured for jumbo frames, which is required for higher channel counts; whether the link speed is at least one hundred megabits, since ten megabit connections cause packet loss; and whether there is an IP address conflict on the network, which causes intermittent subscription failures. All four checks can be implemented with standard command-line tools. The node installation script already implements a similar link-state check that could be reused.

### Issue Seven: Mode switching does not warn about active audio streams

This is rated high importance. When an operator changes the appliance mode — for example from Spotify to internet radio — a preview dialogue shows the configuration changes that will be applied. However, this preview does not mention that currently active audio services will be stopped. The mode switch unconditionally stops all services. If internet radio streams are active, the Dante audio outputs go silent immediately and without warning to any downstream receivers. The preview dialogue should include a prominent warning when a mode change is about to interrupt active audio, listing the services that will be stopped.

### Issue Eight: The reboot action has no reconnect feedback

This is rated medium importance. When an operator triggers a reboot or redeploy action from the Cockpit interface, a simple browser confirmation dialogue appears, followed by a brief notification, and then the Cockpit session goes dark. There is no countdown timer, no indication that the appliance is rebooting normally, and no automatic page refresh when it comes back online. Operators who are not familiar with the expected reboot time may assume something has gone wrong. A thirty-second countdown overlay that polls the appliance every few seconds and automatically refreshes the page on reconnect would give operators clear feedback throughout the reboot process.

### Issue Nine: Audio underrun counts are not on the health dashboard

This is rated medium importance. The Linux kernel tracks every time the audio subsystem experiences an underrun or overrun — these events correspond directly to silence gaps or clicks in the transmitted Dante audio. This information is available from the kernel's proc filesystem without any special privileges. Adding a health check row that shows the audio underrun count would give operators the single most direct indicator of audio quality problems without requiring SSH access or any special tools. Notably, the repository already contains a benchmark script that reads these counts — the logic just needs to be called from the health check system.

### Issue Ten: The Dante discovery panel does not link to peer Inferno nodes

This is rated medium importance. The Dante device discovery panel already scans the network and builds a table of all Dante-capable devices, including their names, IP addresses, and hostnames. Other Virgil appliances on the same network follow a predictable naming pattern based on their MAC address. The discovery table currently shows only static text with no actions. Adding an open-in-Cockpit link for devices that match the Inferno naming pattern would let operators navigate between multiple appliances from a single pane, without maintaining a separate list of IP addresses.

---

## Section Four: Build Pipeline and Deployment

This section covers ten issues found by reading the build scripts, the container build file, the GitHub Actions workflow, and the OTA updater. The focus is on reproducibility, supply chain integrity, and build reliability.

### Issue One: The container and ISO build is entirely manual

This is rated high importance. The automated GitHub workflow only compiles the Rust binary components and uploads them as release assets. Building the container image, generating the installer ISO, packaging the update bundle, and copying it to the build server are all manual steps that require a human to run a script on a specific machine. A broken container build file or configuration change can be shipped without detection until that human triggers the script. Connecting the build script to a GitHub Actions workflow triggered on release tags would provide automated gating and a complete audit trail for every release.

### Issue Two: The build tool version is not pinned

This is rated medium importance. The build script pulls the bootc image builder tool using the latest tag every time it runs. This tool is under active development and has previously made breaking changes to its configuration format and output structure between versions. Pinning the tool to a specific version or checksum digest guarantees that the same source code produces the same ISO output regardless of when the build runs.

### Issue Three: The binary download in the container build is not version-pinned

This is rated high importance. The container build file is configured to download the latest released binaries by default. This means two builds of the exact same container build file on different days can silently embed different binaries, depending on what was released in between. The build script should require an explicit version to be specified and should fail if no version is provided. The nightly binary workflow already outputs its release tag — the build script just needs to use it.

### Issue Four: The Rust toolchain version is not pinned

This is rated medium importance. The nightly build workflow installs whatever the current stable Rust release is at the time of the build. A new Rust release with different optimisation defaults or changed standard library behaviour can silently change how the compiled binaries behave. Adding a toolchain version file to the repository would pin Rust to a known-good version and make any toolchain upgrade a deliberate, reviewable change.

### Issue Five: There is no software bill of materials or vulnerability scan

This is rated medium importance. Neither the nightly build nor the release build process generates a software bill of materials listing which packages, Rust libraries, and system components are included in the appliance image. There is no automated vulnerability scanning step. For a network-attached appliance running multiple services — including a web interface, SNMP, SSH, and audio processing — having an automated inventory and CVE scan would provide immediate supply-chain visibility. The tools to do this exist as standard GitHub Actions steps and take under twenty lines of workflow configuration to add.

### Issue Six: All system packages in the container build are version-unpinned

This is rated medium importance. The container build file installs roughly twenty system packages without specifying versions for any of them. Fedora releases updated packages frequently. Two builds of the same container build file a week apart can produce images with different software versions, making it impossible to bisect regressions or guarantee consistent behaviour. Capturing the installed package versions into a committed manifest file would at minimum provide a post-build audit trail.

### Issue Seven: There is no script to prepare the node provisioning file

This is rated medium importance. The node provisioning template contains three placeholders that must be manually replaced before deploying a new node: the password hash, and two SSH public keys. There is no companion script that takes these values as inputs and produces a ready-to-use provisioning file. A minimal script using standard substitution tools would eliminate the manual step, allow the process to be automated as part of a VM creation workflow, and make SSH key rotation straightforward across all nodes.

### Issue Eight: Interrupted OTA uploads cannot be resumed

This is rated medium importance. If the OTA update sidecar crashes or the management network connection drops during a firmware upload, the partial upload is deleted and the client must restart the transfer from the beginning. For a two-gigabyte firmware bundle over a slow management link, this is a significant inconvenience. Saving the upload progress to a state file on disk would allow a reconnecting client to query how much data was received and re-send only the remaining portion.

### Issue Nine: There is no automated post-build smoke test

This is rated high importance. After building the container image, the build script proceeds directly to ISO generation without running any verification. A basic smoke test using the container runtime could verify that all expected services are enabled and that there are no structural errors in the bootable image — all without needing to boot a virtual machine. The bootc tool ships with a built-in container lint command that checks for common mistakes specific to bootable container images.

### Issue Ten: The container base image is not refreshed during builds

This is rated high importance. The container build command does not include a flag to check for a newer version of the base image. The default behaviour uses whatever is already cached on the build machine. On a long-running build server, the base operating system image can become months out of date while every build reports success. For an appliance that is deployed on broadcast networks, running a stale base image with known security vulnerabilities is a real risk. Adding a single flag to the build command costs only the time to check the remote image digest and downloads updated layers only when they have actually changed.

---

## Section Five: Ecosystem Integration

This section covers ten issues found by reading the node agent, inferno-central, and dante-patchbox integration points. The focus is on closing gaps that block the planned inferno-central integration features.

### Issue One: The device discovery name key is mismatched between Virgil and inferno-central

This is rated high importance. When a Virgil node announces itself on the network using multicast DNS, it publishes its device name under a key spelled one way. When inferno-central reads that announcement, it looks for the device name under a key spelled slightly differently. Because the keys never match, the device name in the fleet registry is always empty, and inferno-central has to make an additional network request to every node just to find out its name. Fixing the key name in the announcement template is a one-line change.

### Issue Two: Virgil nodes have no network discovery announcement template

This is rated high importance. The central management system discovers nodes by listening for multicast DNS announcements. However, the Virgil appliance does not ship with a template for generating its own discovery announcement file. The integration documentation acknowledges this by describing the announcement as conditional on whether Virgil ships its own file — implying it does not. This creates a circular dependency: central needs to discover the node via multicast DNS to run the bootstrap process, but the node has no announcement file until after bootstrap. Adding a discovery announcement template to the appliance and generating it during first-boot configuration would break this circle.

### Issue Three: The node agent has no Dante identity endpoint

This is rated high importance. The node agent exposes endpoints for hardware information, configuration, health status, and metrics. None of these expose the Dante-specific identity: the Dante device name, the number of transmit and receive channels, or the channel labels. Minos requires the Dante device name to match exactly what the appliance advertises on the network. Currently this must be manually configured. A simple read-only endpoint that returns the Dante identity from the configuration file would give both inferno-central and Minos a stable, machine-readable contract and eliminate the manual configuration step.

### Issue Four: The health endpoint does not distinguish Dante readiness from service running

This is rated high importance. The health endpoint checks whether the audio bridge service is active according to systemd. However, the audio bridge service has a startup dependency — it waits for the PTP clock service to become ready before it can actually begin sending audio. A service that is running but blocked waiting for the clock is reported as healthy when it is not yet producing audio. Adding a specific Dante connectivity flag to the health response — checking whether the clock socket is available — would expose this state accurately. Minos already provides this level of detail in its own health responses.

### Issue Five: Audio dropout counts are not included in the metrics endpoint

This is rated high importance. The metrics endpoint returns CPU usage, memory, disk, uptime, PTP offset, and network traffic. Audio health data is entirely absent. Inferno-central's planned monitoring integration explicitly requires audio path metrics from each node. The kernel makes audio underrun and overrun counts available through the proc filesystem at a stable path, and reading them requires no special privileges. Adding these counts to the metrics response would give the central management system its first concrete audio quality signal per node.

### Issue Six: There is no Prometheus-format metrics endpoint

This is rated medium importance and depends on adding audio metrics first. The metrics endpoint returns data in JSON format. Inferno-central's planned monitoring integration requires Prometheus-formatted metrics, which means it must convert every metric from JSON, introducing a translation layer with potential for mapping errors. A Prometheus-format endpoint on the node agent would allow direct integration with Grafana dashboards and eliminate the conversion layer entirely. The Python library for generating Prometheus metrics is mature and reduces the implementation to about fifteen lines.

### Issue Seven: Mode switches via the API only restart the audio bridge

This is rated high importance. When the mode is changed through the node agent configuration API, the service restart logic only restarts the audio bridge service. But a mode change involves multiple services: Spotify mode needs the librespot and keepalive services; internet radio mode needs the iradio and audio keepalive services. None of these are started or stopped when a mode change is applied via the API. This means inferno-central's planned bulk configuration push cannot correctly change node modes remotely, as the wrong services remain running.

### Issue Eight: Fleet bootstrap relies on a hardcoded default password

This is rated high importance. The bootstrap process that registers a node with inferno-central uses SSH to connect. If no password is provided, it falls back to a hardcoded default password baked into the central management code. If bootstrap fails because the password has been changed, it logs a warning and returns without enrolling the node — which then remains in a degraded management state indefinitely with no further retry. Replacing the SSH password dependency with a dedicated bootstrap endpoint on the node agent, secured by the device's unique identifier rather than a password, would allow any node to be enrolled regardless of its SSH password configuration.

### Issue Nine: Nodes cannot register themselves with inferno-central

This is rated medium importance. The current discovery model requires inferno-central to find each node via multicast DNS and initiate the bootstrap process. In installations where nodes are on a different network segment from the management server, multicast DNS does not cross the segment boundary and those nodes are invisible to central. Adding support for a central server URL in the node configuration, along with a one-time registration service that runs at startup, would allow nodes to push their identity to central when the URL is configured. All the required identity fields already exist in the node configuration model.

### Issue Ten: Critical service failures are not reported immediately

This is rated medium importance and depends on the self-registration feature. Both the audio bridge service and the PTP clock service are configured to restart automatically on failure. However, neither service is configured to notify anyone when it fails. The central management system polls nodes for health status on a sixty-second cycle. This means a venue can experience a full minute of silence on its Dante audio outputs before the fleet dashboard registers the problem. If self-registration is in place, adding a failure notification hook to both service configurations would allow a lightweight alert to be sent to central immediately when either service crashes, reducing detection time from sixty seconds to near-instant.

---

## Summary of Quick Wins

To close, here are the eleven items that offer the highest value for the lowest effort — each is under two hours of work.

The critical Restart All button bug requires a single line change to fix a confirmed silent failure in all non-Spotify modes. The missing alsaloop clock drift flag is documented in the code's own comment right next to the command that should include it. The statime privilege escalation is one character in one configuration file. The librespot real-time scheduling omission is two lines in one service file. The Spotify normalisation flag is one addition to the librespot startup command. The SSH hardening gap is one block added to the container build file. The SNMP credentials exposure is a file permission fix in two places. The PTP jitter statistics are already available in memory and require only calculation and display code. The multicast DNS key mismatch in inferno-central is one character in one template line. The Dante connectivity health flag is a simple socket existence check. And the stale base image risk is one flag added to the container build command.

These eleven items collectively address three confirmed bugs, one critical security misconfiguration, two audio quality gaps, one fleet monitoring accuracy issue, one management network exposure, one supply chain risk, and one silent build reliability gap.
