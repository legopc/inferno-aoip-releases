# Inferno AoIP Ecosystem — Architecture & Open Questions

*Written as flowing prose for audio playback. Optimized for listening, not scanning.*

---

## Where We Are Right Now

The Inferno ecosystem is a collection of open-source components designed to replace proprietary audio-over-IP infrastructure in live venues — starting with Het Vliegende Paard, a large student pub in Zwolle. The goal has always been to build something that works alongside existing Dante hardware, not against it. The pub already has Dante devices: AVIO adapters, a Shure MXWANI8 eight-channel networked audio input. Inferno slots into that network as a first-class Dante participant, not a workaround.

The physical foundation is a collection of HP EliteDesk thin clients — small, fanless-ish boxes that cost around eighty euros each on the secondhand market. Each one runs an immutable operating system image called Virgil, which is built on Fedora IoT using bootc, the bootable container toolchain. Immutable here means the root filesystem is read-only at runtime. You don't install packages on a running Virgil node. You build a new image, deploy it, and the node reboots into the new version. This is the same philosophy that powers container infrastructure, applied to a bare-metal appliance. The upside is consistency and auditability. The downside is that anything you want on the node has to be baked into the image at build time.

Each Virgil node has exactly one job. One node might run Spotify Connect, advertising itself on the network and accepting streams from the Spotify app. Another might handle internet radio, pulling a stream from the internet and injecting it into Dante. A third might manage AUX input — taking a physical audio signal from a jack on the back of the machine and putting it onto the network. A fourth might handle AUX output, the reverse direction. There's also a Bluetooth mode in development. In every case, the node's output — or input — is a Dante audio stream. The node is a bridge between the outside world and the Dante network.

The Cockpit plugin, called cockpit-inferno, runs on each node and provides a browser-based management interface. Cockpit is a Linux administration tool that Red Hat ships as part of Fedora and RHEL. It's already present on Fedora IoT nodes, so the plugin slots in without adding a separate web server. The plugin has four tabs: configuration, services, audio routing, and monitoring. From any browser on the local network, a technician can check what a node is doing, restart services, change settings, and watch audio meters in real time.

Sitting above the nodes is dante-patchbox, a Rust binary that acts as the routing and mixing brain of the whole system. It discovers Dante devices on the network, receives audio streams, runs them through a configurable NxM DSP matrix, and transmits the processed results back onto the network for amplifiers and other devices to pick up. Each bar in the pub gets a zone-scoped view through a web interface — a touchpanel running in a browser that shows only the sources and destinations relevant to that area. The patchbox handles authentication via PAM and JWT, scene save and restore, WebSocket-based metering, and mDNS advertisement so clients can find it without configuration.

Finally, inferno-central is planned as a fleet management layer — a server that knows about every Virgil node on the network, tracks their health, pushes configuration changes, and provides a unified view of the whole installation. It exists today only as an early FastAPI scaffold. The architecture hasn't been fully designed yet, and that's deliberate. Building inferno-central before the appliance layer is stable would mean building on sand.

---

## Why Distributed Won

The alternative to this architecture is a central appliance — one powerful box running everything. One machine handling Spotify, internet radio, AUX, Bluetooth, mixing, routing, all of it. That approach has obvious appeal: one box to manage, one config to understand, one place to look when something goes wrong.

The problem is that in a live venue, that one box is also one point of failure. If it crashes during a Friday night event, the whole pub goes silent. There's no graceful degradation. There's no "at least the main bar still has music." There's nothing.

With distributed nodes, failure is contained. If the Spotify node in the back room dies, the back room loses Spotify. The main bar is still playing. The stage monitors are still working. The internet radio node is still streaming. Each node failing independently means each node can be replaced independently too — you pull the dead box, plug in a fresh one, boot it from the same image, and you're back in minutes. No reconfiguration required beyond the basic network setup, because the image itself carries the configuration.

The cost argument is also compelling. A single AVIO adapter from Audinate's ecosystem costs more than an entire HP EliteDesk node. Adding a new zone to the Dante network with an AVIO means paying that premium every time. Adding a new zone with a Virgil node means buying an eighty-euro thin client and booting the standard image. The economics scale well. And because the nodes run commodity x86 hardware, there's no supply chain dependency on any specific manufacturer.

The operational simplicity argument matters too. Each node has one job, which means each node has one config file, one set of services to understand, one failure mode to diagnose. When something sounds wrong in a specific area, you know which node to look at. The complexity hasn't disappeared — it's been moved to the management layer. But management complexity is a solved problem in a way that hardware complexity is not. Software can be updated. Firmware on proprietary boxes often cannot.

The honest counterargument is that distributed systems are harder to manage at scale. Thirty nodes is more complexity than one box, if you're SSHing into each one individually. That's exactly what inferno-central is supposed to address. The distributed architecture is only a good idea if the management layer exists to tame it.

---

## The Patchbox — Open Questions

The dante-patchbox proof of concept works. There's a running instance on the jumphost, reachable on port 9191, built from thirty autonomous development sprints. The architecture is sound: Rust for performance and memory safety, axum for the HTTP and WebSocket server, rust-embed to bundle the frontend into the binary, PAM for authentication, mDNS for discovery. The DSP matrix is an NxM design, meaning any input can be routed to any output, with per-channel gain and processing.

But the proof of concept was built without close human oversight, and that shows. It has never been properly tested against real Dante hardware in a live configuration. The frontend was generated quickly and hasn't been reviewed for usability. The data model for scenes — the saved routing configurations — hasn't been stress-tested with real operator workflows. The Dante protocol integration is based on reverse-engineered documentation from the Inferno_Dante_Tools repository, which means there are likely edge cases and protocol subtleties that haven't surfaced yet.

The decision that needs to be made before writing a production version is this: what exactly is the patchbox responsible for, and where does its responsibility end? Right now it tries to be both a Dante router and a DSP matrix. Those are two distinct functions. A Dante router decides which audio streams go where — it's essentially a network-level patch bay. A DSP matrix processes audio — gain, EQ, compression, perhaps delay. Combining them in one binary is convenient, but it creates coupling that may cause problems later. If the DSP processing needs to change, you risk destabilizing the routing. If the routing logic needs updating for a new Dante protocol version, you're editing code that's entangled with audio processing.

The question of whether dante-patchbox should run on its own dedicated node or on an existing Virgil appliance node is also open. Running it on a dedicated box makes the architecture cleaner — the routing brain is a distinct piece of infrastructure with its own failure domain. Running it on an existing node saves hardware. Given that nodes are eighty euros each, saving hardware is not a strong argument here. A dedicated routing node seems right, especially if the patchbox is handling audio for the entire pub.

Another open question is how zone scoping works in practice. The current design gives each bar touchpanel a zone-scoped view, meaning staff at the main bar only see main bar sources and destinations. But who defines the zones? How are they configured? What happens when the venue layout changes, or when a temporary zone is needed for an event? The current patchbox has no mechanism for zone management beyond what was scaffolded in the proof of concept. This is a design gap that needs to be filled before any production deployment.

The DSP capabilities of the patchbox also raise a question about where Dante Controller — Audinate's own configuration tool — fits in. Dante Controller handles the low-level routing of Dante channels. The patchbox is supposed to sit above that, as an application-layer mixer. But there's overlap. A technician setting up the system needs to understand which layer they're operating at, and the two tools need to be used in a coordinated way. Getting this wrong in a live venue means audio goes to the wrong place. The documentation and operator training story here is not yet written.

---

## Virgil and the Immutable Image — Open Questions

The immutable image approach is correct. It's the right call for appliances that need to be reproducible and reliable. But it introduces some friction that hasn't been fully resolved.

The most significant open question is SELinux. Fedora IoT ships with SELinux in enforcing mode, which is correct from a security standpoint. But several known bugs in the current Virgil image relate to SELinux denials — particularly around SSH and the way services interact with the filesystem. The workaround has been to note the bugs and move on, but a production appliance should not be shipping with known SELinux issues. Each denial represents a security boundary that has been broken in an unexpected way. Before production deployment, every SELinux denial in the current image needs to be traced to its source and fixed properly — either by writing the correct policy or by restructuring the service to behave within expected boundaries.

The default password situation is another critical open item. A production appliance that ships with a known default password is a security liability. In a pub environment with open WiFi or semi-trusted network access, this is not a theoretical risk. Any node with a known default credential is a potential entry point. Fixing this requires a first-boot provisioning flow: the node boots, detects that no admin password has been set, and forces the operator through a setup wizard before it becomes functional. That flow doesn't exist yet in any meaningful form.

The OTA update story is reasonably solid. Cockpit has the inferno OTA updater plugin, which handles delivering new image bundles to nodes. The mechanism works. The question that hasn't been answered is the rollback story. If a new image breaks something on a specific hardware configuration, can you roll back? Fedora IoT's bootc tooling supports keeping the previous deployment, so a rollback is theoretically possible. But the operator-facing workflow for triggering a rollback through Cockpit isn't built. A technician standing in front of a broken node at eleven PM on a Saturday night needs a clear, obvious way to roll back. That path needs to be documented and tested before production.

Multi-soundcard support is another open area. The current Virgil image supports up to eight channels and can work with multiple soundcard configurations. But the behavior when cards are added or removed at runtime — or when a card fails — hasn't been tested thoroughly. Audio interfaces can and do fail in live environments. What happens to the Dante stream when the physical audio device disappears? Does the software crash? Does it emit silence? Does it emit noise? Each of those outcomes has very different consequences in a live venue. The failure behavior needs to be explicitly defined and tested.

---

## Cockpit Plugin — What's Done, What's Not

The cockpit-inferno plugin is feature-complete for the current set of appliance modes. The four tabs — config, services, audio, and monitoring — cover the operational needs of a Spotify or AUX node. The code is plain HTML, JavaScript, and CSS with no build step, which is the right call for a Cockpit plugin. It keeps the toolchain simple and the plugin easy to audit.

What's missing is Bluetooth pairing UI. The Bluetooth mode is in development, and when it lands in the appliance image, the Cockpit plugin needs a way to pair devices. Bluetooth pairing is inherently interactive — it often requires confirmation on both devices, and it can fail in confusing ways. Building a good pairing UI in Cockpit means handling the asynchronous pairing state machine clearly, surfacing errors in plain language, and dealing with the reality that the person using it may not be technically sophisticated. This is not a hard engineering problem, but it requires careful UX thinking.

The Patchbox panel integration for Cockpit is marked as uncertain in the project notes. The idea was that each node's Cockpit interface might include a panel connected to the patchbox, giving operators a unified view without switching tools. Whether this is actually useful depends on how the touchpanel interface for the patchbox evolves. If the patchbox has a good standalone web interface that operators prefer, duplicating it inside Cockpit adds maintenance overhead for little gain. This is a decision that should be deferred until the patchbox v2 design is further along.

---

## inferno-central — The Layer That Doesn't Exist Yet

inferno-central is the planned fleet management server. It's supposed to know about every Virgil node, track health and status, push configuration updates, handle identity and authentication across the fleet, and provide a unified operator dashboard. Today it's a FastAPI scaffold with no meaningful implementation.

The reason it hasn't been built is correct: building fleet management before the appliance is stable is backwards. You end up managing a moving target, and every change to the appliance's configuration model breaks the management layer. The right sequence is to stabilize the appliance, define a clear configuration schema, and then build inferno-central against that stable interface.

But there are architectural questions that need answers before implementation begins, and some of them affect the appliance design too. The first is the communication model. Should inferno-central push configuration to nodes, or should nodes pull from inferno-central? Push is simpler to reason about but requires nodes to have open inbound connections, which is a security consideration. Pull is more resilient to network partitions — nodes continue running their last known config if the central server is unreachable — but requires nodes to poll, which adds latency to configuration changes.

The second question is identity. How does inferno-central know it's talking to a legitimate Virgil node, and not something else on the network claiming to be one? The appliance needs some form of per-node identity — probably a certificate or key generated at provisioning time — that inferno-central can verify. This ties back to the first-boot provisioning flow mentioned in the Virgil section. Provisioning and identity are the same problem.

The third question is scope. inferno-central could be minimal — just health monitoring and configuration push — or it could be comprehensive, including update orchestration, backup management, and event logging. The minimal version is faster to build and less likely to become a maintenance burden. The comprehensive version is more useful but risks becoming an infrastructure project in its own right. Given that Het Vliegende Paard is the primary deployment target and it's one venue, not a chain of fifty, the minimal version is probably right.

---

## The Windows DVS Replacement

inferno-windows is the least mature component in the ecosystem. The goal is to replace Audinate's Windows DVS — the software that turns a Windows PC into a Dante network device — with an open-source implementation. The scaffold is in place and the code compiles. It does not yet function as a working Dante device.

The fundamental blocker is PTP — Precision Time Protocol. Dante relies on PTP for sample-accurate synchronization across all devices on the network. Getting PTP right on Windows is not trivial. The Shure MXWANI8 at Jelle's home acts as the PTP grandmaster for the home network, which means there's hardware available for testing. But the test environment hasn't been set up yet, and until it is, there's no way to verify that the Windows implementation is actually synchronized to the network clock.

This is worth flagging as an architectural consideration for the broader ecosystem too. PTP is the invisible foundation that everything else depends on. All the Dante devices on the network — the AVIO adapters, the Shure hardware, the Virgil nodes, potentially inferno-windows — need to agree on the time. If a node's PTP implementation is slightly wrong, audio from that node will drift and eventually glitch. Debugging PTP issues in a live venue is genuinely difficult because the symptoms — occasional clicks, pops, dropouts — look like a dozen other problems. The ecosystem needs tooling to make PTP health visible. The Inferno_Dante_Tools repository has some of this, but it's not integrated into the standard operator workflow.

---

## The Dante Protocol Itself — A Known Risk

Everything in this ecosystem depends on reverse-engineered knowledge of the Dante protocol. Audinate has not published a public specification. The Inferno_Dante_Tools repository contains the best available documentation, built by observing real Dante traffic and cross-referencing with community knowledge.

This is a known risk, and it needs to be named clearly. Audinate has the right to change their protocol in firmware updates, and they have done so before. A Dante firmware update that changes a message format or adds a new required handshake could break Inferno components without warning. There is no licensing relationship with Audinate, no access to private documentation, and no formal interoperability testing. The ecosystem works because the protocol is largely stable and the reverse engineering has been careful. But it's not guaranteed to keep working.

The practical mitigation is to design components that fail gracefully. If the patchbox loses its Dante connection because of a protocol mismatch, it should degrade to silence rather than to noise or a crash. If a Virgil node can't register on the Dante network, it should report a clear error through Cockpit rather than silently failing. The ecosystem can't prevent protocol incompatibilities, but it can make them visible and recoverable.

---

## Security Posture Across the Ecosystem

Security has been on the radar from the start, but there are gaps. The committed documentation scrub happened — plaintext passwords were removed from published repositories. The Fortigate API token remains in FORTIGATE_RULES.md intentionally, as it's read-only. But there are still open items.

The BUG-07 issue — credentials committed to a published GitHub repository — needs a full history scrub on inferno-aoip-releases. Not just removing the file. The commit history needs to be rewritten to expunge the credentials entirely. Anyone who cloned the repo before the fix potentially has the old credentials. Whether those credentials are still valid or meaningful in the current setup is a separate question, but the history should be clean regardless.

The network model for the appliances is VLAN 10, with DHCP. The appliances don't have static IPs, which means inferno-central needs a service discovery mechanism rather than a hardcoded address list. mDNS is the natural fit here, and the patchbox already uses it. Extending that pattern to the appliance nodes is straightforward. But mDNS has limitations — it doesn't cross subnet boundaries, and it can be noisy on larger networks. For a single-venue deployment, it's fine. For a hypothetical multi-venue future, it needs rethinking.

Authentication on the individual Cockpit interfaces is handled by PAM — Linux's standard pluggable authentication modules. That's correct and appropriate. Authentication on the patchbox is PAM plus JWT. The question that hasn't been fully answered is what the trust boundary is between the patchbox and the appliance nodes. Can the patchbox instruct a node to do something? Should it be able to? If so, that channel needs to be authenticated. If not, the communication is one-way — nodes advertise streams, patchbox subscribes to them — and the question is simpler.

---

## What Needs to Happen Next

The honest answer to "what's next" is that the ecosystem is at a transition point. The proof of concept phase is over. The individual components have been built and partially tested. The question now is which components get hardened for production and in what order.

Virgil is the most production-ready component. The SELinux bugs and the default password issue are the critical blockers. Once those are fixed, and once the OTA rollback story is documented and tested, Virgil nodes can be deployed to the pub with reasonable confidence.

The cockpit-inferno plugin follows Virgil's readiness. It needs the Bluetooth pairing UI when that mode is ready, but the existing tabs are functional.

dante-patchbox v2 is the most important design conversation to have before writing more code. The proof of concept demonstrated that the architecture is viable. The v2 design needs to answer the zone scoping question, the DSP versus routing split, the dedicated-node question, and the operator workflow. This is a design and discussion exercise, not a coding exercise — and it should happen before a single line of v2 code is written.

inferno-central should wait until Virgil is stable and the patchbox v2 design is settled, because both of those inform what inferno-central needs to manage. Building it now means building it twice.

inferno-windows is a parallel track that doesn't block anything else. It can proceed when the PTP test environment is ready, independently of everything above.

The Dante TUI — the Rust command-line and terminal interface for Dante routing — is live-tested against real hardware and works. It's a useful operator tool regardless of how the rest of the ecosystem evolves.

---

## The Larger Picture

This ecosystem is being built in public, on GitHub, with the explicit goal of being generally useful — not just for Het Vliegende Paard, but for any venue that wants to build a Dante-compatible audio infrastructure without paying enterprise prices. The design decisions have been made with that in mind: generic over site-specific, no magic assumptions baked into the code, complexity earns its place by delivering real value.

The bet is that there are other venues, other technicians, other builders who want what this is becoming. A sub-hundred-euro appliance that speaks Dante, managed from a browser, updated over the air, with an open routing and mixing layer. Nothing in that description requires proprietary hardware or proprietary software. The technology exists. The challenge is assembling it into something that works reliably enough to trust in a live environment where failure has an immediate, audible cost.

That's the bar. Not "works in a demo." Works on a busy Friday night when the venue is full and nobody has time to SSH into a box.

Everything in the architecture serves that goal. The immutable image ensures nodes don't drift. The distributed design ensures failures stay local. The Cockpit plugin ensures any technically-capable person can manage a node from a browser. The patchbox ensures routing can be changed at the application level without touching Dante Controller. And inferno-central — when it exists — ensures the whole fleet can be managed as a coherent system rather than a collection of individual boxes.

The open questions catalogued here aren't failures. They're the honest map of what's left to do. Knowing what you don't know is most of the job.

---

*Document generated 2026-04-09. Intended for audio playback — read by a TTS system or a human out loud.*
