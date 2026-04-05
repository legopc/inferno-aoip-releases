# Inferno AoIP — Cockpit UI

The Inferno page in Cockpit (`https://node-ip:9090`) is the primary management interface for a running node. It is a native Cockpit page (not an iframe or separate web server) baked into the bootc image at `/usr/share/cockpit/inferno/`.

---

## Layout

The page is a single-column layout with four cards:

```
┌──────────────────────────────────────────────────────────────┐
│  SERVICES                                                    │
│  ┌────────────┐ ┌───────────────┐ ┌────────────────────┐   │
│  │ statime    │ │ inferno-bridge│ │ librespot          │   │
│  │ ● active   │ │ ● active      │ │ ● active           │   │
│  │ [▶][■][↺] │ │ [▶][■][↺]    │ │ [▶][■][↺]         │   │
│  └────────────┘ └───────────────┘ └────────────────────┘   │
│  ┌────────────────────┐ ┌──────────────────────────────┐    │
│  │ inferno-aux-tx     │ │ inferno-aux-rx               │    │
│  │ ○ inactive         │ │ ○ inactive                   │    │
│  └────────────────────┘ └──────────────────────────────┘    │
├──────────────────────────────────────────────────────────────┤
│  CONFIGURATION                              [Unsaved changes]│
│  Mode:           [Spotify Connect → Dante TX         ▼]     │
│  Spotify name:   [Inferno-24AAA8                    ]       │
│  Dante TX name:  [Inferno-24AAA8                    ]       │
│  Input Card:     (hidden unless aux-in or aux-bidir)        │
│  Output Card:    (hidden unless aux-out or aux-bidir)       │
│  ▶ Show audio devices   (expandable device list)            │
│  Network Interface: [eno1                            ▼]     │
│  Hostname:       [inferno-24aaa8                    ]       │
│                                   [Save & Apply]            │
├──────────────────────────────────────────────────────────────┤
│  SYSTEM INFO          │  ACTIONS                            │
│  Hostname: ...        │  [Restart all]                      │
│  IP: ...              │  [Trigger re-deploy + reboot]       │
│  Mode: ...            │  [Reboot node]                      │
│  Dante TX: ...        │                                     │
├──────────────────────────────────────────────────────────────┤
│  JOURNAL                                                     │
│  [statime▼] [inferno-bridge▼] [librespot▼] [aux-tx▼] ...   │
│  ┌────────────────────────────────────────────────────────┐ │
│  │ live journal output                                    │ │
│  └────────────────────────────────────────────────────────┘ │
└──────────────────────────────────────────────────────────────┘
```

---

## Files

```
cockpit/
├── manifest.json   — Cockpit package registration
├── index.html      — Page shell (no inline styles or event handlers)
├── inferno.css     — All styles (external — required by Cockpit CSP)
└── inferno.js      — All logic (~750 lines)
```

---

## How It Works

### Cockpit CSP Constraints

Cockpit v359+ enforces a strict Content Security Policy:
- **No `<style>` blocks** — all CSS must be in an external `.css` file loaded via `<link rel="stylesheet">`
- **No `style="..."` attributes** — use CSS classes
- **No `onclick=`/`onchange=`/`oninput=` in HTML** — silently blocked; wires nothing
- **All event handlers** must use `addEventListener()` in JS, or DOM property assignment (`el.onclick = fn`)
- **No `eval` or inline scripts**

All event handler wiring happens in `init()`, called on `DOMContentLoaded`.

### Privileged Operations

Cockpit runs as the `core` user (not root). Privileged operations use two patterns:

**Writing system files** (`/etc/inferno.conf`, `/etc/hostname`):
```js
cockpit.spawn(["sudo", "-n", "tee", "/etc/inferno.conf"])
    .input(content)   // closes stdin after write — MUST NOT pass stream:true
```

**Running system commands**:
```js
cockpit.spawn(["bash", "-c", "sudo -n systemctl restart statime-inferno"])
```

**Writing user files** (`.asoundrc`, `~/.config/systemd/user/*.service`):
```js
cockpit.file(path).replace(content)   // no sudo needed — core owns these
```

The `core` user has passwordless sudo for specific commands (configured in the image via `/etc/sudoers.d/inferno`).

### Service Control

Service buttons call `cockpit.spawn` with the appropriate `systemctl` command. System services use `sudo -n systemctl`; user services use `systemctl --user` in the user's environment:

```js
function spUser(cmd) {
    return cockpit.spawn(["bash", "-c", cmd], { environ: userEnv() });
}
// userEnv() provides: HOME, USER, PATH, XDG_RUNTIME_DIR, DBUS_SESSION_BUS_ADDRESS
```

Status polling runs every 5 seconds. Each service card shows active/inactive/failed with colour coding.

### Configuration Save Flow

`saveConfig()` performs these steps in order:

1. **Write `/etc/inferno.conf`** — via `sudo -n tee` with full updated conf content
2. **Patch Spotify name** in `librespot.service` via scoped `sed`
3. **Patch Dante names** in `.asoundrc` — **block-scoped sed** (critical):
   ```bash
   sed -i '/pcm.inferno_spotify/,/^}/s/NAME "..."/NAME "NewName"/'    ~/.asoundrc
   sed -i '/pcm.inferno_aux_tx/,/^}/s/NAME "..."/NAME "NewName-TX"/'  ~/.asoundrc
   sed -i '/pcm.inferno_aux_rx/,/^}/s/NAME "..."/NAME "NewName-RX"/'  ~/.asoundrc
   ```
4. **`systemctl --user daemon-reload`**
5. **Aux provisioning** (if mode is not spotify) — calls `ensureAuxSetup()`
6. **Stop old services** — anything not in the target set for the new mode
7. **Start new services** — target set for the new mode
8. Toast notification with summary

### Aux Mode Auto-Provisioning (`ensureAuxSetup`)

Called on first save in any aux mode. Checks if `pcm.inferno_aux_tx` already exists in `.asoundrc`:

**If missing** — derives values from the existing `inferno_spotify` block:
- `BIND_IP` — copied from spotify block
- `DEVICE_ID_TX` — base ID with last 4 hex chars incremented by 1
- `DEVICE_ID_RX` — base ID with last 4 hex chars incremented by 2
- Names — `DanteName-TX` and `DanteName-RX`

Then appends the aux PCM block definitions to `.asoundrc` using `cockpit.file().replace()`.

**Service files** — writes `inferno-aux-tx.service` and `inferno-aux-rx.service` to `~/.config/systemd/user/` with the selected input/output card numbers substituted.

Returns `true` if ALSA blocks were freshly written (triggers an extra `daemon-reload`).

### Mode → Service Mapping

```js
const SPOTIFY_SVCS   = ["librespot","inferno-bridge","inferno-keepalive","librespot-watchdog"];
const AUX_IN_SVCS    = ["inferno-aux-tx"];
const AUX_OUT_SVCS   = ["inferno-aux-rx"];
const AUX_BIDIR_SVCS = ["inferno-aux-tx","inferno-aux-rx"];
const ALL_AUX_SVCS   = ["inferno-aux-tx","inferno-aux-rx","inferno-aux-keepalive"];
```

On mode change: stop everything not in the target set, start everything in the target set.

### Audio Card Discovery

`populateAudio()` runs `aplay -l` and `arecord -l` separately and parses output into labelled `<select>` options:
- Excludes Loopback cards (software — not a physical device)
- Excludes HDMI-only devices (no line-level audio)
- Labels: `"0 — CX20632 Analog"` (card number + device name from aplay)

For bidir mode, two independent selectors are shown:
- **Input Card (Capture)** — populated from `arecord -l` — used for `alsaloop` capture (`-C plughw:N,0`)
- **Output Card (Playback)** — populated from `aplay -l` — used for `alsaloop` playback (`-P plughw:N,0`)

### Audio Device Info Panel

The "▶ Show audio devices" button expands a panel showing all audio hardware. It:
1. Runs `aplay -l` and `arecord -l` in parallel
2. Parses both into a card map keyed by card number
3. Renders each card as a styled HTML block showing:
   - Card number + codec name
   - 🎤 capture capability (from arecord) and/or 🔊 playback capability (from aplay)
   - Loopback cards shown dimmed with a "(software loopback — not selectable)" note

### Journal Viewer

The journal section shows live logs for a selected service. Selector options map to:

| Label | journalctl query |
|-------|-----------------|
| statime | `sudo -n journalctl -u statime-inferno -n 100 --no-pager` |
| inferno-bridge | `journalctl _SYSTEMD_USER_UNIT=inferno-bridge.service -n 100` |
| librespot | `journalctl _SYSTEMD_USER_UNIT=librespot.service -n 100` |
| inferno-aux-tx | `journalctl _SYSTEMD_USER_UNIT=inferno-aux-tx.service -n 100` |
| inferno-aux-rx | `journalctl _SYSTEMD_USER_UNIT=inferno-aux-rx.service -n 100` |

User service logs use `_SYSTEMD_USER_UNIT=` (system journal filter) rather than `journalctl --user` which is unreliable in the Cockpit bridge context (no full login session).

---

## Known Gotchas

| Gotcha | Detail |
|--------|--------|
| `proc.input(content, true)` hangs forever | The second arg `stream:true` keeps stdin open — tee never exits. Always use `.input(content)` with no second arg. |
| Global `sed` on `.asoundrc` wipes `-TX`/`-RX` | Always scope sed to the specific PCM block (see save flow above). |
| `inferno-aux-keepalive` + `inferno-aux-rx` conflict | Both try to own the Dante RX subscription — streams stop. Keepalive must never run alongside aux-rx. |
| Cockpit inline handlers silent fail | `onclick="fn()"` in HTML does nothing — Cockpit CSP blocks it. Must use `addEventListener` in JS. |
| `environ: [...]` replaces, not merges | `cockpit.spawn(..., { environ: [...] })` replaces the entire env. Must explicitly include HOME, USER, PATH, XDG_RUNTIME_DIR, DBUS_SESSION_BUS_ADDRESS. |
| Same Dante NAME = invisible in DC | All three Inferno instances must have unique names. Aux devices must append `-TX`/`-RX`. |
