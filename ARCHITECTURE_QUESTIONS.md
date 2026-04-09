# Inferno AoIP Ecosystem — Architecture & Open Questions

*A thoughtful engineering discussion document. Written to be read aloud — prose over bullets, depth over brevity.*

---

## 1. The Ecosystem Architecture — Where We Are

Let's start by painting the full picture, because the individual components only make sense when you understand how they fit together.

The Inferno ecosystem is built around a single, well-understood problem: a venue like Het Vliegende Paard has audio sources in multiple physical locations — a bar area, a stage, a lounge, a terrace — and it needs those sources routed, mixed, and delivered to amplifiers and speakers in each zone. The professional solution has always been Dante: Audinate's Audio-over-IP protocol that turns your ethernet network into a high-quality, low-latency audio fabric. The problem is that Dante hardware is expensive, proprietary, and locked to a Windows-centric management tool called Dante Controller. Inferno is the open-source answer to that.

The ecosystem currently has four distinct components, each with a clearly bounded responsibility.

The first is the appliance layer, codenamed Virgil, living in the inferno-aoip-releases repository. Each appliance is a small, cheap thin client — an HP EliteDesk in our case, costing around eighty euros — running a custom Fedora IoT bootc image. This image is immutable: the operating system is baked at build time, delivered as a container image, and the device boots into it read-only. The appliance's job is source management and format conversion. It takes audio from the physical world — a Spotify stream, an analog AUX input, an internet radio station, eventually a Bluetooth source — and puts it onto the Dante network as a set of named channels. That's it. The appliance doesn't know about zones, it doesn't know about routing, it doesn't manage other devices. It owns its sources and exposes them to the network.

The second component is cockpit-inferno, the per-node management interface. Red Hat's Cockpit is a web-based server management tool that runs locally on each appliance and is accessible over HTTPS. The cockpit-inferno plugin adds four tabs: configuration, services, audio, and monitoring. From here a technician can configure which modes are active on this node, restart services, check levels, and look at system health. The key design decision was that cockpit-inferno is exclusively a local tool. It manages one node. It has no awareness of the rest of the ecosystem. This keeps it simple, keeps the security surface small, and means it works even when the rest of the network is broken.

The third component is dante-patchbox, the routing brain. Where the appliances are pure I/O nodes, the patchbox is where routing decisions live. It presents a configurable N-by-M matrix of Dante channels — any input can be routed to any output — along with per-input gain control, per-output volume, and eventually DSP. It also provides the user-facing zone interface: a simple web page for bar staff showing just the sources relevant to their area and a volume fader. The patchbox is not embedded in any appliance. It runs as a standalone service on its own machine, and it communicates with the Dante network using the same protocol that all other Dante devices use. The first version was a thirty-sprint autonomous prototype that never got properly tested. The design is sound, but it needs to be rebuilt with intention.

The fourth component is inferno-central, still in early scaffold, which will eventually be the fleet management layer. Think of it as the view from above: which appliances are online, what versions they're running, whether any have drifted from their expected configuration, OTA update orchestration, and aggregate monitoring. This is the layer that matters when you have the system deployed and need to manage it without SSHing into seven separate nodes. It's a FastAPI service, Python, and it's deliberately the last thing to build — because you need the appliance and patchbox to be stable before you build a management plane on top of them.

The responsibility boundaries were drawn this way for a reason. The appliance layer and the patchbox are deliberately kept separate because they have different failure modes, different hardware requirements, and different operational lifetimes. An appliance can be rebooted or replaced without affecting routing. The patchbox can be reconfigured without touching any appliance. Cockpit stays local because local management should never depend on network services being up. And inferno-central is deferred because premature generalization is how you end up with a complicated system that doesn't actually work.

---

## 2. The Distributed vs Centralized Question

This is the most fundamental architecture decision in the whole system, and it's worth spending some time on.

The alternative to the current design would be a single powerful machine running all the audio services — one box taking in all the audio sources, doing all the format conversion, all the routing, all the DSP, and sending Dante streams out to the amplifiers. That's how a lot of professional AV systems are actually built. There are mixing desks that do exactly this: one rack unit, one IP address, one management interface, total control. So why didn't we go that route?

The first reason is cost. A single powerful appliance capable of running eight or ten simultaneous audio streams with format conversion, DSP, and routing would cost significantly more than a string of cheap thin clients. But more importantly, it would cost more to expand. When you want to add a new zone, you're potentially limited by the capacity of the central box. With the distributed model, adding a zone means buying an eighty-euro thin client and plugging it in. The marginal cost stays flat.

The second reason is failure isolation. In a distributed system, a single appliance crashing affects one zone. The bar area loses its Spotify stream, but the stage still works, the lounge still works, the DJ booth still works. In a centralized system, one fault takes everything down. For a venue that runs events and live music, "everything is silent" is genuinely catastrophic. Failure isolation is not just a theoretical benefit — it's the difference between a manageable problem and a ruined event.

The third reason is a physical one, and it's more interesting than it might seem at first. Bluetooth has a range of roughly ten meters. If you want a Bluetooth source in a venue — a musician connecting their phone to the system without cables — you need a Bluetooth receiver physically close to that person. You cannot centralize Bluetooth. Once you accept that some sources must be local, you're already in a distributed model. The question becomes whether you want a consistent architecture everywhere or a hybrid where some areas have local nodes and others don't. A consistent architecture is simpler to reason about, simpler to deploy, and simpler to troubleshoot.

The fourth reason is operational clarity. When something is wrong in a distributed system, the scope of the problem is usually obvious. "The kitchen has no audio" points you at the kitchen node. In a centralized system, problems are more likely to be systemic and harder to diagnose. You're also touching a shared system when you make any change, which raises the stakes of every intervention.

That said, the counterarguments are real and worth acknowledging. A centralized system is much simpler to synchronize. If you want sources to play in perfect sync across all zones — the same track at exactly the same moment in the bar and on the terrace — centralized DSP and routing is the natural way to do that. With distributed nodes feeding into Dante, you can still achieve synchronization because Dante is inherently sample-accurate across the network, but you need to be deliberate about it. The patchbox handles this at the routing layer, but it requires that all your source streams are actually in sync at the network level, which is a solvable problem but not a free one.

A centralized model is also easier to patch and update. You have one system to maintain. With seven appliances, you have seven systems to update, seven places where something could go wrong during an OS rollover. This is precisely why we chose a bootc immutable image model — OTA updates are atomic, rollback is built in, and the update mechanism is the same whether you have one node or twenty. But it does add complexity to the build pipeline that a centralized system wouldn't need.

The honest conclusion is that distributed wins for this deployment because of the Bluetooth constraint, the cost model, and the failure isolation requirements. Centralized would make sense for a smaller installation — a recording studio with one room, or a small bar with a single zone — where complexity reduction outweighs the benefits of isolation. At venue scale, distributed is the right call.

---

## 3. dante-patchbox v2 — Open Architecture Questions

The patchbox is where the interesting engineering questions live. The first version was built as a proof of concept — thirty autonomous development sprints, minimal human oversight, and it was never properly tested against real Dante hardware. The architecture is sound, but there are several design questions that need answers before we write version two.

**The audio path and real-time safety.** The most critical question is what the patchbox's audio path actually is. In Dante, the routing decisions live in hardware — the Dante network interfaces on the actual devices maintain their own routing tables, and the patchbox talks to them using Dante's control API to say "route input channel X to output channel Y." This means the patchbox is not actually in the audio hot path at all. It's a control plane, not a data plane. The audio flows directly between Dante devices at the network level. This is a crucial distinction because it means the real-time safety concerns you'd have in a traditional DSP system — avoiding locks in the audio callback, avoiding memory allocation, keeping latency deterministic — are mostly not applicable to the patchbox itself.

However, if we add DSP — per-output EQ, per-input compression, that sort of thing — we have two choices. We can leave the DSP running on the Dante devices themselves (if they support it, and many do), or we can insert a software DSP node into the signal path. A software DSP node would be a separate process that presents itself to the Dante network as both a receiver and a sender, receives audio, processes it, and re-sends it. That process needs real-time guarantees. It should run with a real-time scheduler priority, it should not allocate memory in its processing loop, and any data structures shared between the control thread and the audio thread need to be lock-free. The right pattern in Rust for this is a ring buffer with atomic indices and a separate control channel — something like the `rtrb` crate, which is specifically designed for single-producer single-consumer real-time audio scenarios. If we go down the software DSP path, that architecture decision needs to be locked in before we write the DSP layer, because retrofitting lock-free data structures into an existing codebase is painful.

For version two's initial scope — routing and volume only — the patchbox remains a control plane and the real-time question is deferred. But we should design the interfaces now with the assumption that DSP will eventually exist, so we don't paint ourselves into a corner.

**State persistence and scene management.** The patchbox needs to survive a restart without forgetting its configuration. This seems obvious, but there are subtleties. The routing state — which inputs are connected to which outputs — is authoritative in the Dante network, not in the patchbox's database. When the patchbox restarts, it needs to either query the network to discover current routing state or it needs to reapply its own stored configuration. These two approaches have different failure semantics. If the patchbox reapplies its stored config on every restart, it's always in a known state but it may override manual changes made using other tools like Dante Controller. If it queries the network and accepts what it finds, manual changes are preserved but the patchbox's state might diverge from what it expects.

For a venue deployment, the reapply-on-restart approach is almost certainly correct. You want the system to converge to its intended configuration reliably. The right model is probably: store scenes as declarative configurations, apply the active scene on startup, and treat external changes made via other tools as unsupported overrides. This also makes backup and restore trivial — a scene is just a JSON file.

**Authentication and the zone UI problem.** The patchbox has three classes of user. There's the system administrator — one person, probably with a laptop — who needs full access to everything: routing matrix, gain staging, DSP, scene management, user administration. There's the venue manager, who needs to be able to recall scenes, adjust master volumes, and see system status. And there's the bar staff, who need to be able to select a source for their zone and adjust the volume. That's it. They should not be able to accidentally reroute the entire venue or mute the stage.

The current design uses PAM plus JWT for authentication, with role-based access. PAM is an interesting choice because it means user accounts are actual system accounts, managed the same way as SSH access. This has advantages for an embedded system — you don't need a separate user database — but it also means that adding a new bar staff member requires touching the system configuration on the patchbox host, which may be more friction than we want. An alternative would be a lightweight application-level user database, stored in SQLite, managed through the admin interface. This is more self-contained and doesn't require system-level access to manage users. For a small venue deployment with a handful of staff, either approach works, but the SQLite approach is friendlier for whoever ends up maintaining this system day-to-day.

The zone interface for bar staff is a solved UI problem: source selector, volume fader, maybe a mute button. The hard part is the scope enforcement. A staff member at the main bar should only see the main bar zone. They should not be able to see or interact with other zones. This needs to be enforced at the API level, not just the UI level — because anyone with a phone can open a browser and poke at an API directly. Each user account needs to be scoped to one or more zones, and the API needs to check that scope on every request.

**Hardware platform for the patchbox.** The appliances are HP EliteDesk thin clients — that decision is made. What runs the patchbox? It needs to be an always-on machine, ideally with a local display or a connected touchscreen for use as a wall panel. The patchbox service itself is a single Rust binary with embedded static assets, so the hardware requirements are minimal. A Raspberry Pi 5 would be more than sufficient. A second HP EliteDesk running the patchbox software rather than an appliance image would also work and would give you consistency in your hardware fleet.

The more interesting question is whether the patchbox should eventually be embedded in the bootc image itself — so that a single node can run as both an appliance and a patchbox — or whether it should remain a separate machine. There's an argument for separation: the patchbox is a single point of failure for routing, so you want it on its own hardware that you can update and restart independently of any audio source node. Mixing them creates the kind of coupling we specifically designed against.

**The WebSocket metering question.** The patchbox currently streams audio meters over WebSocket — level information for each channel, updated multiple times per second. This is good for a visual interface: VU meters showing input and output levels in real time. But it raises a question about load. If you have fourteen output channels and eight input channels, that's twenty-two meter streams, each updating at maybe ten hertz. That's not a heavy load for a local network, but you need to be careful about how many simultaneous clients you support and what happens to the server when a client disconnects badly. The WebSocket connection management needs to handle dropped clients gracefully without leaking resources. Rust's async model makes this manageable, but it needs to be designed explicitly — not assumed.

---

## 4. The Network Layer — LLDP, VLANs, and Auto-Provisioning

One of the more elegant ideas in the current roadmap is using LLDP to make the network self-configuring. The context is this: the pub's network is all Cisco IOS-XE — 3650 and 3850 switches. Cisco IOS-XE supports a feature called device classifier, which inspects LLDP announcements from connected devices, matches them against known device types by system description, and automatically applies service templates. A service template can configure the port: assign a VLAN, apply QoS markings, enable spanning-tree portfast. The idea is that when you plug an Inferno appliance into the network, it announces itself via LLDP with a specific system description string, the switch recognizes it as an "Inferno AoIP node," and automatically assigns the port to the Dante VLAN and applies the appropriate QoS policy.

This is not just convenient — it's a meaningful security boundary. Without this, any device plugged into a spare switch port could potentially join the Dante network. With device classifier, only devices that announce the right LLDP identity get placed in the Dante VLAN. Ordinary devices land on the default VLAN. It's not a strong security boundary — someone who knows the expected LLDP string could spoof it — but it prevents accidental contamination, which is the more likely problem.

The implementation is straightforward: lldpd baked into the bootc image with a custom configuration that sets the system description to something like "Inferno AoIP Node v2" and includes the hardware model and firmware version in the LLDP chassis information. The patchbox would announce a slightly different system description to get a slightly different service template — maybe with a different priority queue configuration, since the patchbox's control traffic has different QoS requirements than the audio streams.

The open question here is about the service template content. Dante has specific QoS recommendations: audio traffic should be in a high-priority queue, but the exact DSCP marking depends on your switch configuration. Getting this right requires knowing the switch's QoS policy in detail, and the pub's switches are managed by someone who may not want arbitrary LLDP templates modifying port configurations automatically. The right approach is to prototype this in a lab environment — the Shure MXWANI8 at home plus a test switch — before deploying it to the production network.

---

## 5. The Virgil Appliance — What's Stable and What Isn't

The appliance image is the most mature component in the ecosystem. Version twenty-four shipped with several meaningful fixes: the first-login password change flow now works correctly through Cockpit's wizard, the SELinux labels on the SSH home directory are set correctly by the configuration script, and the immutable image boot model is solid. It's been tested on real hardware.

There are two open items worth noting. The first is BUG-07: early development commits included plaintext credentials in the documentation. Those credentials have been scrubbed from the current codebase, but the git history on the public GitHub repository still contains them. The repository needs a history rewrite — specifically a git filter-repo pass to remove those commits — followed by a force push and a note to anyone who has cloned the repository. This is a known issue and a real one, even if the credentials themselves have likely been rotated.

The second is the Bluetooth mode. The architecture for Bluetooth on the appliance was prototyped on an Arch Linux T470s with an Intel 8265 chipset. It works there. It has not been ported to Fedora IoT, and there are questions about chipset compatibility on the HP EliteDesk hardware. The EliteDesk thin clients may need USB Bluetooth adapters, which adds cost and mechanical complexity. Bluetooth is also the most complex source mode operationally — pairing, re-pairing, device priority when multiple phones try to connect — and it's the one most likely to generate support calls. It's probably right that Bluetooth is the last mode to be fully implemented and that the Cockpit pairing UI gets proper design attention.

---

## 6. inferno-central — The Architecture Question Before the Code

inferno-central is deliberately parked at scaffold stage, and that's the right call. Building a fleet management layer before the things it manages are stable is how you end up maintaining two moving targets at once. But it's worth thinking about what the architecture will need to look like when we do get there.

The core function of inferno-central is inventory and health. It needs to know which nodes exist, what they're running, and whether they're healthy. The natural way to implement this is a heartbeat model: each appliance periodically sends a status report to the central server, and the server marks nodes as offline if they stop reporting. The status report should include the current image version, active modes, service states, and basic system health metrics — disk usage, CPU temperature, uptime.

The more interesting question is whether inferno-central should be a push or pull model. Push — where nodes send data to the server — is simpler to implement and works behind NAT. Pull — where the server queries each node — gives the server more control but requires the server to have network access to every node, which may not be true if nodes are on a segmented Dante VLAN. A hybrid makes sense: nodes push their heartbeats, but the server can initiate connections for on-demand queries and OTA orchestration.

The OTA piece is particularly interesting because the appliance already has OTA update capability through cockpit-iot-updater. The question is whether inferno-central drives updates centrally — "update all nodes to version twenty-five" — or whether it just monitors and the updates are still triggered locally. Centrally orchestrated updates are more powerful but require a robust rollback story: if you push a bad update to seven nodes simultaneously and they all fail to boot, you have a serious problem. The bootc rollback capability handles the per-node recovery, but someone still needs to detect the failure and roll back. Orchestrated updates should probably be staged — update one node, verify it, then proceed — with automatic rollback if a node doesn't come back healthy within a defined window.

---

## 7. The Rust/Axum Pattern — Consistency as a Strategic Choice

All of the backend services in this ecosystem use the same technology stack: Rust, axum for the HTTP layer, rust-embed for static asset bundling, tokio as the async runtime. This is a deliberate strategic choice worth examining.

The primary benefit is that a single developer can work across the whole system without context switching between languages and frameworks. The patterns for error handling, configuration loading, health endpoints, and WebSocket management are the same in the patchbox as they are in inferno-central as they are in the appliance services. Code can be shared through common crate dependencies. Skills transfer directly.

The secondary benefit is deployment simplicity. Each service is a single statically linked binary with no runtime dependencies. Embedding it in a bootc image is trivial: copy the binary, write a systemd unit file. There's no Python virtualenv to manage, no Node.js version matrix, no shared library version conflicts. This matters a lot for an immutable OS deployment where you can't just install a missing dependency at runtime.

The tradeoff is compile time. Rust's compile times are slow, especially for incremental changes to a large dependency tree. The build VM exists partly to address this — you don't want to be waiting eight minutes for a build on a developer laptop — but it's still slower than equivalent Python or Go development cycles. For a solo developer or small team, this is a real cost. The answer is good tooling: cargo's incremental compilation, sccache for shared build caches, and disciplined dependency management to avoid pulling in large crates unnecessarily.

---

## 8. Where To Go Next — The Honest Roadmap

If you were to order the remaining work by what unblocks what else, it looks roughly like this.

The highest priority right now is BUG-07 — scrubbing the credential history from the public repository. This is a risk that exists every day the repository is public with that history. It's uncomfortable to do because it rewrites public history and disrupts anyone who has cloned the repo, but it's necessary.

After that, the next meaningful milestone is a working dante-patchbox v2 tested against real Dante hardware. The Shure MXWANI8 at home is the right test environment for this. Phase zero is routing only: no DSP, no metering, just the ability to route inputs to outputs and persist that configuration across restarts. That alone would replace the current manual Dante Controller workflow for the pub. Everything else — volume control, scene presets, the zone UI — layers on top of a working routing foundation.

The patchbox hardware decision should be made in parallel with the software work, because it affects what you're developing against. A Raspberry Pi 5 is probably the right call for a first deployment — cheap, fanless, reliable, well-supported by Fedora — but an HP EliteDesk running the patchbox software is also appealing for fleet consistency. This needs a concrete decision, not continued ambiguity.

Once the patchbox is working and deployed to the pub, inferno-central becomes the next sensible project. By that point, you'll have real operational experience with the appliance fleet, which will inform what the management layer actually needs to do — as opposed to what you imagine it needs to do now.

The Bluetooth mode, inferno-windows, and the LLDP auto-provisioning work are all valuable but none of them are blocking anything critical. They can proceed in whatever order makes sense given available time and interest.

---

## Closing Thoughts

What's been built here is genuinely interesting engineering. The choice to use an immutable bootc image for the appliance layer is ahead of most production AV deployments. The Rust-based service architecture is clean and consistent. The decision to use real Dante protocol — to be a real Dante participant in the network rather than a bridge or adapter — means this system works alongside existing Dante hardware without any special configuration.

The remaining work is less about inventing new things and more about filling in the gaps carefully. The patchbox v2 needs to be built with the rigor that the v1 prototype didn't get. inferno-central needs to be designed, not just scaffolded. The Bluetooth work needs hardware validation before it goes into a production image.

The biggest risk to the project is scope creep — trying to build everything at once and ending up with nothing working well. The current phased approach is correct: get the appliance stable, get the patchbox working against real hardware, then build upward. Each layer should be deployable and useful on its own before the next layer is added. That's the discipline that turns a collection of interesting prototypes into a system you'd actually trust to run a venue's audio on a busy Friday night.

---

*Generated: 2026-04-09 | Inferno AoIP Ecosystem | Version 1.0*
