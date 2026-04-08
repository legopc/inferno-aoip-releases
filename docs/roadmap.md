# Inferno AoIP — Improvement Roadmap

Items observed during development/testing that should be improved in a future sprint.
Each item references where the change needs to be made.

---

## Build & Release

### Lower GRUB timeout in installer ISO
**Observed:** During VM install from `inferno-appliance-vN.iso`, the GRUB countdown
is 60 seconds before anaconda auto-starts. On a fast VM this is dead time on every
fresh install.

**Proposed fix:** In `build/build-release.sh` (or the BIB config), patch the GRUB
timeout after the ISO is built:
```bash
# Repack ISO with lower timeout using xorriso
# Or: pass a custom grub.cfg via BIB --config option with set timeout=5
```
Target: `set timeout=5` (5 seconds) — enough to select troubleshooting entries manually
if needed, but not slow for automated installs.

**Files:** `build/build-release.sh`, `build/config.toml` (BIB config)
**Effort:** Small
