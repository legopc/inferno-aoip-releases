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

---

### Auto-bump submodule pointers on upstream release
**Observed:** `iot-updater` (and `cockpit-inferno`) are git submodules in this repo.
When commits land in `legopc/cockpit-iot-updater` or `legopc/cockpit-inferno`, the
pointer in `inferno-aoip-releases` is NOT updated automatically. v17 shipped with an
iot-updater that was 5 commits behind because the bump wasn't done before the build.

**Proposed fix:** Add a GitHub Actions workflow to each dependent repo
(`cockpit-iot-updater`, `cockpit-inferno`) that, on push to `main`, opens a PR or
pushes a commit to `inferno-aoip-releases` bumping the submodule pointer:
```yaml
# .github/workflows/bump-parent.yml (in cockpit-iot-updater / cockpit-inferno)
on:
  push:
    branches: [main]
jobs:
  bump:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          repository: legopc/inferno-aoip-releases
          token: ${{ secrets.RELEASES_PAT }}
      - run: |
          git submodule update --remote iot-updater  # or cockpit-inferno
          git commit -am "chore: auto-bump iot-updater submodule" && git push || true
```

**Files:** `legopc/cockpit-iot-updater/.github/workflows/`, `legopc/cockpit-inferno/.github/workflows/`
**Effort:** Small
