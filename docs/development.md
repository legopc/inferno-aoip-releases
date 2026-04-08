# Development Guide

## Prerequisites

- An Inferno AoIP node running v10 or later (physical or VM)
- SSH key access: `ssh -i ~/.ssh/your_key core@<node-ip>`
- Node has `/var/home/core/.local/share/cockpit/inferno/` (created automatically on first Cockpit login)

---

## Fast iteration workflow

Cockpit serves the plugin from the user override path at runtime — no service restart or container rebuild needed.

```bash
# One-liner: push all three files after any change
scp -i ~/.ssh/your_key \
  src/{index.html,inferno.js,inferno.css} \
  core@<node-ip>:/var/home/core/.local/share/cockpit/inferno/
```

Then **hard-refresh** the browser (`Ctrl+Shift+R`) — changes are live immediately.

> The node override path takes priority over the baked-in image path. Your changes persist until the next bootc upgrade, which will overwrite them with the image version.

---

## CSP rules — always follow these

Cockpit enforces a strict Content Security Policy. Violating these causes silent failures:

| Rule | Reason |
|------|--------|
| ❌ No `<style>` tags | CSP blocks inline stylesheets |
| ❌ No `style="..."` attributes | CSP blocks inline styles |
| ❌ No `onclick=`/`onchange=`/`oninput=` in HTML | CSP blocks inline event handlers |
| ✅ All CSS in `inferno.css` | Loaded as an external stylesheet |
| ✅ All JS in `inferno.js` | Loaded as an external script |
| ✅ Wire events in `init()` via `addEventListener` | Keeps HTML clean and CSP-safe |

---

## Writing commands

Three spawn helpers are available:

```js
// Run a command as the session user (non-privileged)
sp(["amixer", "-c", "0", "sget", "Master"])

// Run a shell command in the user environment (for systemctl --user, sed, journalctl --user, etc.)
spUser("systemctl --user restart inferno-bridge")
spUser("sed -i 's/foo/bar/' /var/home/core/.asoundrc")

// Run a shell command with sudo -n (NOPASSWD — for writing root files, alsactl store, etc.)
spSudo("alsactl store")
spSudo("tee /etc/inferno.conf")   // or use writeFileAsSudo(path, content)
```

All return Promises. Use `await` or `.then()`.

---

## Writing files

```js
// User-owned file (e.g. .asoundrc)
await cockpit.file("/var/home/core/.asoundrc").replace(content);

// Root-owned file (e.g. /etc/inferno.conf)
await writeFileAsSudo("/etc/inferno.conf", content);
// writeFileAsSudo uses: cockpit.spawn(["sudo", "-n", "tee", path]).input(content)
// Do NOT pass content as a second arg to spawn — it doesn't work that way in Cockpit.
```

---

## ALSA debugging

```bash
# List all cards
aplay -l
arecord -l

# Check mixer controls for a card
amixer -c 0 scontents    # all controls with current values
amixer -c 0 sget Master  # specific control

# Check what's in .asoundrc
cat /var/home/core/.asoundrc

# Verify ALSA state persistence
systemctl --user status alsa-state   # should be active (running)
sudo cat /var/lib/alsa/asound.state | grep -A3 "card 0"
```

Common volume issue: on Intel HDA (PCH) cards, `Headphone` and `Speaker` are already at 100% but `Master` is attenuated — always check `Master` first.

---

## Adding a new panel

1. Add the HTML card to `src/index.html` following the existing pattern:
   ```html
   <div class="card">
     <div class="card-header">
       <span class="card-title">My Panel</span>
       <button class="btn btn-secondary btn-sm" id="btn-my-action">Do thing</button>
     </div>
     <div class="card-body">
       <div id="my-content"><span class="loading-text">…</span></div>
     </div>
   </div>
   ```

2. Wire the event listener in `init()` in `inferno.js`:
   ```js
   $("btn-my-action").addEventListener("click", myFunction);
   ```

3. Add any styles to `inferno.css` — use classes, never inline styles.

4. Call your init/load function at the end of `init()`.

---

## Baking into the image

When ready to ship, update the source files and trigger a full Inferno release build via `inferno-aoip-releases`:

```bash
# From the build machine
build/build-release.sh vN "Description of changes"
```

The Containerfile copies the cockpit files directly from the `cockpit/` directory (which mirrors this repo's `src/`) into the image at `/usr/share/cockpit/inferno/`.
