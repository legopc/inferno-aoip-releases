# Inferno AoIP Ecosystem — Architecture and Open Questions

*A technical discussion document, written for listening. Approx. 25 minutes at normal reading pace.*

---

## Where We Are Right Now

Let's start by describing the full picture of what's been built, because it's easy to lose track of the scope when you're deep in individual components.

The core of the ecosystem is a set of small, headless Linux appliances running on HP EliteDesk thin clients — machines that cost around eighty euros each. Each appliance runs an immutable Fedora IoT operating system image called Virgil. Immutable means the root filesystem is read-only at runtime; the OS is a container image that boots directly, with no package manager and no configuration drift. When you update a node, you load a new image and reboot. If it fails, the previous image is still on disk and the node rolls back automatically. This design choice was made early and it's one of the best decisions in the project.

Each appliance node has exactly one job. A node at a podium runs in AUX-in mode, capturing analog audio from a microphone or instrument and transmitting it as a Dante audio-over-IP stream. A node at a bar runs Spotify Connect mode, receiving music from Spotify and transmitting it as a Dante stream. Some nodes run internet radio mode, pulling from any internet radio stream and broadcasting it on the Dante network. Eventually, nodes will run Bluetooth mode, acting as an A2DP sink for mobile devices. The key design principle is one node, one job, one failure mode. These nodes are audio format converters — they take audio from whatever source is relevant for their location, and they put it onto the Dante network as a Dante TX device.

On the output side, amplifiers around the venue each have an Audinate AVIO adapter connected to them. These adapters are Dante RX devices — they receive audio from the Dante network and convert it back to analog for the amplifiers. Two Shure MXWANI8 units will eventually consolidate these outputs — each has eight analog output channels, so two units cover all fourteen stereo zone outputs the pub needs, with two channels to spare.

In the middle sits the dante-patchbox. This is a Rust binary that runs on a Linux machine, creates a virtual Dante device with configurable input and output channel counts, and provides a browser-based web interface for routing and mixing. Sources arrive from the Dante network as RX channels, pass through a configurable routing matrix with per-input and per-output gain control, and the results are transmitted back onto the Dante network as TX channels for the amplifier adapters to pick up. As of now, the patchbox has a working Phase Zero proof-of-concept: routing matrix, gain controls, scene presets, PAM authentication with JWT tokens, WebSocket live metering, zone-scoped views for bar staff, and a panic mute button. The real Inferno audio integration is compiled and working in tests, though full hardware validation against the Shure is still in progress.

Cockpit-inferno is the management UI baked into each appliance node. It's a plugin for Cockpit, the open-source server management framework that runs in the browser. It gives you four tabs: configuration for audio mode and routing parameters, service control with log viewing, audio volume control, and monitoring with PTP clock status and health checks. No separate management application is needed — you open a browser, navigate to port 9090 on any node, and you're managing it.

Inferno-central is the planned fleet management layer. The scaffold exists — a FastAPI Python server with Docker Compose — but the architecture needs to be locked before code gets written. Its job is to aggregate all the nodes: discover them via mDNS, monitor their health, push OTA updates. It sits above all the other components as a single pane of glass.

---

## Why Distributed Won

The most important architectural decision in this project was the choice between a distributed model — one appliance per area — and a centralized model where one or a few machines handle everything.

The centralized model has real appeal. Fewer machines to manage, lower total hardware cost, simpler network topology. But in a live venue, centralized means a single point of failure. If that one box dies at ten PM on a Thursday, the whole pub goes silent. That's not a hypothetical — hardware fails, software crashes, power blinks. And the more functionality you pack into one machine, the more ways it can fail.

With the distributed model, one node dying takes out one area. The main bar keeps playing. The stage keeps running. Bar staff can keep serving. You've degraded gracefully instead of completely. This is the same logic that makes microservices appealing in software architecture, applied to physical hardware.

The cost argument is also compelling. Each node costs around eighty euros in thin client hardware. That's cheaper than a single Audinate AVIO adapter, which runs two to four hundred euros. Adding a new zone to the distributed system means buying a thin client. The Inferno software costs nothing — it's open source. So the per-area cost of the new system is a fraction of what the commercial equivalent would be.

The counterargument is management complexity. More nodes means more things to update, more things to monitor, more potential configuration drift. That's exactly why inferno-central is part of the design. The distributed model only works at scale if you have a management layer on top of it. Without that, you'd be manually SSH-ing into seven or ten or fifteen nodes every time you need to push an update. With inferno-central and OTA updates via Cockpit, you push to all nodes from one interface.

There's also a performance isolation argument. Each node runs its own Inferno instance, its own statime PTP daemon, its own service stack. They don't share resources. One node being under CPU load doesn't affect the audio quality on another node. With a centralized DSP processor handling all zones, a software bug or resource spike affects everything simultaneously.

---

## The Patchbox — Open Questions

The patchbox proof-of-concept is done and working. The production version has several unresolved architecture questions that need answers before it goes into the pub.

The first is real-time safety in the audio path. The Inferno audio callback fires at the hardware sample rate — forty-eight thousand times per second, typically in blocks of sixty-four or one hundred twenty-eight samples. Inside that callback, every microsecond counts. The current implementation uses a Rust RwLock in parts of the hot path for reading the routing configuration. Under normal conditions this is fine, but RwLock can theoretically block if a writer is holding the lock. In a real-time audio context, blocking is catastrophic — even a microsecond of unexpected delay shows up as a click or dropout.

The solution is a triple buffer. The idea is simple: you have three copies of the configuration. The web API writes to the "input" copy. A background task running every ten milliseconds promotes the input to the "pending" slot and then atomically swaps the pending and "output" copies. The audio callback reads exclusively from the output copy, which is never written while the callback might be reading it. The swap operation is lock-free and takes nanoseconds. The callback never blocks, never waits, never touches a mutex. This is already partially in place — the triple_buffer crate is in the dependency tree — but the wiring needs to be completed before production.

The second question is hardware target. The patchbox needs specific capabilities: CAP_NET_RAW for Inferno's raw Dante socket implementation, SCHED_FIFO real-time thread scheduling for the audio callback, and a NIC on the Dante VLAN. The obvious choice is the same HP EliteDesk thin clients used for the appliances, for operational consistency. It means one hardware platform for the whole system, one set of spares. The patchbox also needs a proper systemd service unit that grants the binary the necessary capabilities — not running it as root, which is what the current test setup does. Getting PAM authentication working without root is a platform-specific problem that needs to be solved for Fedora IoT, where the shadow group may not work the same way as Ubuntu.

The third question is channel count scaling. The current test config uses two RX inputs and two TX outputs. The pub deployment needs roughly fourteen TX outputs for seven stereo zones, and potentially twenty or more RX inputs when you account for all the area sources. The DSP matrix computation is order N times M multiplications per sample — twenty inputs by fourteen outputs is two hundred eighty multiplications, which is nothing. Even on a slow embedded processor, that's trivial. The real constraints are Inferno's internal buffer management and network bandwidth, but Dante at forty-eight kilohertz with twenty-four bit depth across thirty-plus channels is under five megabits per second — well within what a gigabit network handles with no effort.

The fourth question is zone ownership. This one is conceptually important. The patchbox manages the DSP routing — which sources feed which outputs, at what gain levels. But Dante subscriptions — which Dante device subscribes to which other Dante device — happen at the protocol level in Dante Controller or in a tool like the Inferno Dante App CLI. These are separate concerns. The patchbox doesn't directly control Dante subscriptions yet. In the future, it should — the patchbox web UI should be able to tell the Inferno instance to subscribe to specific TX channels from the Shure or other devices. That integration work is Phase Two.

---

## Inferno-Central — Design Before Code

The scaffold for inferno-central is a FastAPI Python server with Docker Compose. One commit. The architecture needs to be fully designed before any significant code gets written, because getting this wrong means rework.

The minimal viable version covers eighty percent of the value: mDNS discovery of all nodes on the network, health status polling with a simple dashboard showing which nodes are up and which are down, and OTA update triggering — push a new image version to all nodes from one interface. Everything beyond that is nice-to-have.

The database question is actually simple once you think about it correctly. Inferno-central should not be the source of truth for audio configuration. Each node holds its own configuration in its local inferno.conf file. Inferno-central holds operational data: health history, update audit log, alert rules. SQLite is the right choice — lightweight, zero administration, works fine for the traffic volume involved. The schema is probably three tables: nodes, health_events, and ota_jobs.

Authentication should use the same PAM and JWT pattern as the patchbox. One authentication system across the ecosystem means bar staff login to the patchbox with the same credentials they'd use for inferno-central. Centralized user management via Linux group membership — patchbox-admin, patchbox-operator, patchbox-bar-N — applies to both systems.

The patchbox should register with inferno-central via mDNS when it starts, just like appliance nodes do. Inferno-central can then poll the patchbox health endpoint alongside node health endpoints, and display the patchbox in the fleet dashboard. From inferno-central's perspective, the patchbox is just a special type of node with different health metrics — audio callback timing, routing state, PTP sync status — rather than Spotify connect status or AUX mode.

---

## LLDP and Automatic VLAN Assignment

This is a feature that will matter significantly in production deployment. The Cisco network at the pub uses IOS and IOS-XE throughout — Catalyst 3650 on the core migrating to 3850, and 3560X on access. Dante audio traffic runs on a dedicated VLAN, isolated from the general network. Right now, when you plug in a new appliance node, someone has to manually configure the switch port to put it on the Dante VLAN. That's fine for a handful of nodes but it doesn't scale well and it's error-prone.

The solution is LLDP-based device classification. The appliance node runs lldpd and advertises itself with a custom system description string — something like "Inferno-AoIP-Appliance". On IOS-XE 3650 and 3850, you can configure a device classifier profile that matches on LLDP system description and applies a service template to the port. The service template assigns the port to the Dante VLAN, applies QoS markings for DSCP EF to prioritize audio traffic, and optionally disables CDP to prevent confusion.

The configuration looks roughly like this: you define an autoconf template that sets the access VLAN to whatever number the Dante VLAN is, then you create a device classifier condition that matches on the LLDP system description containing "Inferno-AoIP", and you attach that to the template. When the switch sees the LLDP advertisement from a new node, it automatically applies the template to that port.

The 3560X access switches also support LLDP, but device classifier behavior varies by firmware version. This needs testing before you rely on it in production. The safe approach is to validate it on the 3560X in a lab environment first, before deploying to the pub.

The risk is worth addressing directly: what happens if LLDP misfires and a wrong device gets assigned to the Dante VLAN? The answer is: not much. An unauthorized device on the Dante VLAN won't find anything useful — Dante uses proprietary multicast addressing and authentication that general network devices don't know how to use. The Dante network won't be disrupted by an unexpected device appearing on it. The device just won't be able to participate in Dante routing. This is a much lower risk than the equivalent mistake on a management VLAN.

The patchbox node gets the same treatment. It advertises "Inferno-AoIP-Patchbox" and the same service template applies. Plug it into any switch port, and it lands on the Dante VLAN automatically.

---

## PTP — Why It's Non-Negotiable

Precision Time Protocol is the foundation that Dante audio networking is built on, and if you don't understand it, you'll make bad decisions when things go wrong.

Dante is a synchronous protocol. Every device on the Dante network has to agree on what time it is, to within a few hundred nanoseconds. The reason is simple: audio samples are time-stamped. A transmitter sends sample five million at a specific clock tick. A receiver needs to play sample five million at exactly the same tick in its own clock. If the clocks disagree, samples arrive late or early. Late means buffer underrun — silence or a click. Early means buffer overflow — samples dropped. Even microsecond-level disagreement causes audible glitches.

PTP synchronizes all the clocks on the network to a single grandmaster. IEEE 1588 PTP runs a best master clock election algorithm — devices advertise their clock quality and the network elects the best one as the grandmaster. Everyone else slews their local clock to match.

The pub had a problem in the past: the PTP grandmaster was connected to a circuit that powered off regularly, probably as part of end-of-evening procedures. When the grandmaster disappeared, the network ran a new election. When it came back, it ran another election. If the circuit was flapping — going on and off repeatedly — the network never stabilized. Every election attempt caused a brief period of desynchronization, which is exactly when you get clicks, dropouts, and audio routing failures.

The fix is a hardware grandmaster on a dedicated circuit that never powers off. The Shure MXWANI8 is an excellent candidate — it has hardware PTP support with dedicated clock hardware rather than software implementation, which means lower jitter and higher stability. Put it on a UPS. Set it as the Dante clock master explicitly in Dante Controller rather than relying on the automatic election. Never change this. Mark that circuit clearly so no one accidentally turns it off.

The patchbox needs to sync to this PTP master too. It runs the Teodly Statime daemon, which is an open-source IEEE 1588 PTP implementation. Statime creates a Unix socket that the Inferno audio library connects to for clock information. The Inferno DeviceServer, when configured with the clock path pointing to that socket, uses the Statime clock for all its timing. Getting this wiring right — statime running, socket created, Inferno connecting to it, PTP synced to the Shure master — is one of the critical checkboxes before the patchbox goes into production.

When PTP fails, the right response is graceful degradation to silence. Not noise, not clipping, not random garbage — clean silence. The patchbox should watch the statime log output for PTP loss events, apply a fast logarithmic fade over a few hundred milliseconds, and hold at silence until PTP recovers. When the clock stabilizes again, it should fade back in and restore the previous routing state. This is what "graceful degradation" means for a venue audio system. Silence is annoying. Noise through the speakers is embarrassing and potentially damaging to equipment.

Should appliance nodes be capable of acting as backup PTP masters? The short answer is no. The PTP election algorithm is designed to handle master failure, but the transition period while a new master is elected is a problem for real-time audio. You want one stable master and no elections. Adding more potential masters increases the chance of election conflicts and instability. Keep it simple: one hardware grandmaster, on a UPS, never touched.

---

## The Bluetooth Mode Problem

Bluetooth is working as a proof of concept on Arch Linux, specifically on a ThinkPad T470s with an Intel 8265 chipset. The audio path is A2DP sink via bluez-alsa, through an ALSA loopback device, into the Inferno ALSA plugin, out as a Dante TX. It works. The question is how to bring this to Fedora IoT.

The main challenge is bluez-alsa versus PipeWire Bluetooth. Bluez-alsa is the simpler integration — it creates virtual ALSA devices for Bluetooth audio, which is exactly what the current Arch implementation uses. But Fedora has been moving toward PipeWire as the primary audio subsystem, and PipeWire has its own Bluetooth integration that handles A2DP differently. For the immutable Fedora IoT appliance, getting the right packages into the container image and configuring the audio path correctly is more complex than on Arch where you install packages individually.

Chipset compatibility is an open question. The Intel 8265 works. Other chipsets — Broadcom, Realtek, other Intel variants — may need different firmware or have different behavior with bluez. Testing on HP EliteDesk hardware is necessary before claiming support.

The pairing UI problem is the most interesting design challenge. Bluetooth pairing is interactive — a device initiates a connection, the host has to accept it, possibly with a PIN. A headless appliance with no display can't do this. The current Arch implementation has workarounds but they're not production quality. The right solution for the appliance is a Cockpit pairing panel — a UI in the Cockpit plugin that shows discoverable Bluetooth devices, allows initiating pairing, and manages the paired device list. This is a non-trivial piece of UI and backend work.

The per-area endpoint requirement is a physical constraint that can't be engineered around. Bluetooth range in a busy venue with bodies, furniture, and competing radio signals is typically ten to fifteen meters in practice. A student pub with multiple rooms and metal surfaces might be less. One Bluetooth endpoint can't realistically serve a whole venue. Each area that wants Bluetooth needs its own node.

---

## Inferno-Windows — Unblocking It

The Windows Dante Virtual Soundcard replacement is a Rust project that uses WASAPI to receive audio from the Dante network and play it through Windows audio output. The scaffold is there. Some compile errors have been fixed. It's not functional yet.

The blockers are: a PTP master on the same network as the Windows machine, and getting the WASAPI audio path actually working end-to-end with real samples.

The Shure MXWANI8 at home on the 192.168.1.0/24 network is the PTP master needed for testing. The Windows test machine needs to be on that same network, with statime for Windows running or an alternative PTP implementation. Getting a Windows PTP client working is itself a project — Windows has basic PTP support in newer versions, but the integration with Inferno's clock socket model needs to be validated.

This matters for the pub specifically because there's a DVS PC — a Windows machine running Dante Virtual Soundcard — already in the audio infrastructure. Replacing DVS with the open-source Inferno implementation would remove one more dependency on Audinate's commercial software.

---

## Production Deployment Checklist

Before the patchbox goes into the pub for real, several things need to be true. The hardware test against the Shure MXWANI8 is in progress — the patchbox binary runs on dante-doos, which is on the same network as the Shure, and we're working through the PTP clock path wiring to get the Inferno DeviceServer synced and the device visible in Dante Controller.

PTP stability needs to be validated over a meaningful period — several hours minimum, ideally across a full evening simulation. Dante networks can be stable for the first hour and then show problems when traffic patterns change.

PAM authentication without running as root is a blocker. The current test setup on dante-doos runs the patchbox binary with sudo. That's not acceptable for production. The solution is either a setuid wrapper binary that drops privileges after acquiring the raw socket capability, or using Linux capabilities more precisely — specifically setting CAP_NET_RAW on the binary with setcap, and getting PAM authentication working via a different mechanism that doesn't require root shadow file access.

The systemd service unit needs to be written properly. It should specify the runtime user, AmbientCapabilities for CAP_NET_RAW, CPUSchedulingPolicy for SCHED_FIFO, RestartPolicy for automatic restart on failure, and the correct working directory and config file path.

The rollback plan is straightforward: Dante Controller gives direct access to all Dante subscriptions. If the patchbox fails mid-event, someone with Dante Controller on a laptop can re-route audio directly from sources to amp AVIO adapters within minutes, bypassing the patchbox entirely. This fallback exists because the AVIO adapters at the pub are already there and always available. The patchbox is in the signal path by choice, not necessity.

---

## The Open Source Story

There is nothing else in open source that does what the dante-patchbox does. There are tools for managing Dante routing from the command line. There are AES67 implementations. There are commercial DSP processors. But an open-source NxM routing matrix with DSP that runs on commodity hardware, speaks native Dante, and has a browser-based zone control interface — that doesn't exist anywhere else.

The foundation is the Inferno AoIP project, maintained by lumifaza on GitLab. Inferno is an unofficial implementation of the Dante protocol, written in Rust, that allows Linux machines to appear as Dante devices on the network. Without Inferno, none of this ecosystem exists. All credit for the protocol implementation goes there.

The legopc/inferno fork adds patches developed during this project — Dante Controller integration improvements, latency reporting, board info flags, and the Clear Config handler. These patches should eventually go upstream to the main Inferno project. The fork exists because of the pace of development needed here, not because of any desire to maintain a permanent divergence.

The license is AGPLv3. This is the right choice for this kind of project. AGPLv3 requires that if you distribute a modified version or run it as a network service, you share the source code of your modifications. For a venue using the software internally without distributing it, AGPLv3 imposes no obligations on the venue itself. You can run it commercially. You just can't take the code, modify it, and sell it as a proprietary product without sharing your changes.

For community adoption, the biggest gap is documentation. The hardware requirements are specific enough that someone coming to this project without context would struggle. You need to know about CAP_NET_RAW and what it's for. You need to understand PTP and why you need a hardware grandmaster. You need to know which Fedora IoT packages to include in the container image for ALSA to work correctly. A getting-started guide with a specific, validated hardware list — "buy this thin client, follow these steps, it works" — would lower the barrier significantly and allow other venues to deploy the ecosystem with confidence.

The ecosystem is genuinely novel, built to solve a real problem in a real venue by someone who is both the system designer and the primary user. That context matters. The design decisions are grounded in operational reality, not theoretical architecture. That's a good foundation to build from.

---

*This document was written as a living discussion record. Update it as decisions get made and questions get answered.*
