# Real-Time Scheduling Tuning

## Overview

The Inferno appliance image includes three low-risk, kernel-agnostic RT scheduling
improvements that apply to the standard Fedora 43 kernel — no COPR, no kernel
replacement, no package additions.

---

## What is applied

### 1. `preempt=full` kernel argument

The Fedora 43 kernel is compiled with `CONFIG_PREEMPT_DYNAMIC`, which allows the
preemption mode to be selected at boot via a kernel argument. The default runtime
mode is `lazy`.

Setting `preempt=full` switches to **full kernel preemption**: all kernel code paths
become preemptible. This is equivalent to compiling the kernel with `CONFIG_PREEMPT=y`.

| Mode | Behaviour |
|------|-----------|
| `preempt=none` | No forced preemption — server-class latency |
| `preempt=voluntary` | Voluntary yield points only |
| `preempt=lazy` | **Fedora 43 default** — threads get full preemption, regular tasks voluntary |
| `preempt=full` | **Applied here** — all kernel code paths preemptible |

**Applied via:** `/usr/lib/bootc/kargs.d/99-rt.toml`

### 2. `threadirqs` kernel argument

Forces IRQ handlers that support threading to run as kernel threads rather than in
hard-IRQ context. This reduces worst-case IRQ latency and is safe on all hardware.

**Applied via:** `/usr/lib/bootc/kargs.d/99-rt.toml` (same file as above)

### 3. `@realtime` group RT scheduling limits

Installs two files that raise the scheduling ceiling for processes that explicitly
request real-time priority:

- `/usr/lib/sysusers.d/realtime-setup.conf` — creates `realtime` group (GID 71) at
  first boot via `systemd-sysusers`
- `/etc/security/limits.d/realtime.conf` — grants group members:
  - `rtprio 99` (maximum real-time scheduling priority)
  - `memlock unlimited` (memory locking — prevents paging of RT-critical buffers)

These limits are **inactive for all processes that do not call `sched_setscheduler()`
or `mlockall()` explicitly**. Statime and Inferno may use them; everything else is
completely unaffected.

> **Note:** These files are written manually in a `RUN` step rather than via the
> `realtime-setup` rpm. The rpm's `%post` scriptlet writes the `realtime` group to
> `/etc/gshadow` without a corresponding `/etc/group` entry. This causes
> `systemd-sysusers.service` to fail at every boot with "Group realtime already
> exists in gshadow". Writing the files directly avoids this.

---

## Impact assessment

### Packages
None added. No COPR. Image size unchanged.

### Build time
Negligible — three `echo`/`printf` commands in one `RUN` step.

### CPU overhead
`preempt=full` adds a small amount of context-switch overhead (~0–2%) on CPU-bound
workloads. The Inferno appliance is not CPU-bound, so this is immeasurable in
practice.

### Rollback
Standard `bootc rollback` atomically reverts the kernel arguments along with
everything else. No special recovery procedure needed.

### Expected latency improvement (physical node)

| Configuration | Worst-case sched jitter | statime PTP offset |
|---|---|---|
| Fedora 43 default (lazy, untuned) | ~5–20 ms | ±1–5 ms |
| preempt=full + threadirqs (this image) | ~500 µs–1 ms | ±200–500 µs |
| kernel-rt PREEMPT_RT (future, see below) | ~50–200 µs | ±50–200 µs |

> ⚠️ VM testing will not show these numbers — hypervisor scheduling adds its own
> jitter floor. Measure on a physical EliteDesk with a PTP master on the LAN.

---

## Future: full PREEMPT_RT kernel

A separate experiment repo tracks the path to a full `kernel-rt` (PREEMPT_RT) swap:

**[legopc/inferno-fedora-iot-rt](https://github.com/legopc/inferno-fedora-iot-rt)**

As of 2026-04-05 no COPR provides `kernel-rt` for Fedora 43 x86_64. When
`pbrobinson/kernel-rt` produces working F43 packages, the upgrade is three
Containerfile lines (see experiment repo `RESEARCH.md §4` for the exact change).
The upgrade and rollback infrastructure (`bootc switch`, IoT Updater, `bootc
rollback`) requires no changes.
