# Inferno Appliance — Troubleshooting Playbook

> Diagnostic steps for physical hardware installs and running nodes.
> Work top-to-bottom — each section assumes the previous checks passed.

---

## Quick Reference

```bash
# SSH into node (pw: inferno123)
ssh core@<node-ip>

# Check all failed units
systemctl --failed                        # system services
systemctl --user --failed                 # user services (run as core)

# First-boot log (most useful for install failures)
sudo journalctl -u inferno-configure --no-pager

# Live service status
systemctl is-active statime-inferno
systemctl --user is-active inferno-bridge librespot

# Full inferno-configure log
sudo cat /var/log/inferno-configure.log

# What the node knows about itself
cat /etc/inferno.conf                     # empty/missing = first boot hasn't run yet

# bootc image state
bootc status
```

> **For deeper diagnostics, performance measurement, and before/after comparisons,
> use the bench suite — see [`docs/benchmarking.md`](benchmarking.md).**
>
> ```bash
> # Quick health snapshot from dev machine (PTP + ALSA + Dante, ~2 min)
> bash scripts/bench/inferno-bench.sh core@<node-ip> --mode quick
>
> # Or from the node itself (image must be v16+ / post-cde60cb)
> inferno-bench --mode quick
> ```

---

## Finding the Node IP After Install

The node sets its hostname to `inferno-<mac-suffix>` and gets a DHCP lease.

```bash
# FortiGate DHCP lease search
curl -sk -H "Authorization: Bearer mH1x975mHzfQwHQznf5qnf1gys5dGp" \
  "https://10.10.1.1/api/v2/monitor/system/dhcp?vdom=root" \
  | python3 -m json.tool | grep -B2 -A4 inferno

# If you know the MAC (from probe-node.sh output), search by last 3 octets
# e.g. MAC 18:60:24:24:aa:a8 → search for "24:aa:a8"
```

---

## Stage 1 — Node Doesn't Appear at All

**Symptom:** Nothing shows in Dante Controller or Spotify Connect. No DHCP lease.

Check in order:

1. **Is the node booting from the installed OS or USB?**
   - Remove USB after install. If USB is still plugged in, anaconda re-runs.

2. **Did the install complete?**
   - Anaconda install takes ~3–5 minutes. If you rebooted early, reinstall.
   - The node reboots **twice** after install before services are ready.

3. **Is the network cable plugged in?**
   - The NIC must have link before `inferno-configure.sh` starts or it will timeout waiting for IP.
   - If it waited out and wrote `0.0.0.0`, delete `/etc/inferno.conf` and reboot.

4. **Is the NIC detected correctly?**
   - Access physical console (monitor + keyboard, or see [Physical Console](#physical-console) below)
   - Log in as `core` / `inferno123`
   - `sudo journalctl -u inferno-configure --no-pager | grep NIC`
   - Expected: `NIC: eno1` (or similar wired NIC name)
   - If it shows a WiFi interface (`wlp*`), the v7 WiFi exclusion fix may not be in the image

5. **Did inferno-configure.sh run at all?**
   - `cat /etc/inferno.conf` — if missing, configure hasn't run or failed
   - `sudo journalctl -u inferno-configure --no-pager` — look for errors
   - `sudo cat /var/log/inferno-configure.log` — full script output

---

## Stage 2 — Node Has IP but Services Not Working

**Symptom:** Node appears on network (DHCP lease exists), but nothing in Dante Controller or Spotify.

```bash
# SSH in
ssh core@<node-ip>

# Check first-boot completed and sentinel is written
cat /etc/inferno.conf     # should show INFERNO_NAME, INFERNO_NIC, etc.

# Check system service (PTP — must be active first)
systemctl is-active statime-inferno
sudo journalctl -u statime-inferno --no-pager -n 30

# Check user services (Dante TX + Spotify)
systemctl --user is-active inferno-bridge librespot
systemctl --user --failed
journalctl --user -u inferno-bridge --no-pager -n 40
journalctl --user -u librespot --no-pager -n 20

# Check audio group (critical — must show 63(audio))
id
```

### Common Causes

| Symptom | Likely cause | Fix |
|---------|-------------|-----|
| `id` doesn't show `63(audio)` | Audio group not added (image bug) | Image rebuild needed |
| `inferno-bridge` fails `Cannot get card index for Loopback` | Audio group not effective in linger session | Delete `/etc/inferno.conf`, reboot (or `bootc rollback`) |
| `statime-inferno` failed | No network / bad NIC config | Check `INFERNO_NIC` in `/etc/inferno.conf` |
| `librespot` failed `ExecStart` | Wrong binary path (old image) | `bootc upgrade && reboot` |
| `systemctl --user` shows `no session` | Linger not set up | `sudo loginctl enable-linger core && sudo reboot` |
| `/etc/inferno.conf` has `INFERNO_INTERFACE=0.0.0.0` | No DHCP at configure time | Fix network, `sudo rm /etc/inferno.conf && sudo reboot` |

---

## Stage 3 — Services Running but No Dante TX / Spotify

**Symptom:** `inferno-bridge` and `librespot` are active, but nothing visible in Dante Controller or Spotify Connect.

```bash
# Confirm ALSA loopback is loaded
aplay -l | grep Loopback    # should show "card 5: Loopback"
cat /proc/asound/cards       # snd-aloop should be at index 5

# Confirm inferno-bridge is actually transmitting
journalctl --user -u inferno-bridge --no-pager | grep -i "transmit\|tx\|dante\|error"

# Confirm Avahi mDNS is working (Dante discovery uses mDNS)
sudo systemctl is-active avahi-daemon
avahi-browse -t _netaudio._udp    # should show the local TX

# Check statime is synced (Dante needs PTP)
sudo journalctl -u statime-inferno --no-pager | tail -20
# "no clock available" is normal in VM or without a PTP grandmaster — won't stop Dante

# Check INFERNO_NAME matches what you expect
grep INFERNO_NAME /etc/inferno.conf   # e.g. INFERNO_NAME=Inferno-24AAA8
```

---

## Live Patching — Fix Without Rebuilding

For changes in `/etc/` (mutable overlay) you don't need to rebuild the image.

### Change PTP config (domain, priority, etc.)
```bash
sudo nano /etc/statime-inferno.toml
sudo systemctl restart statime-inferno
```

### Fix NIC if wrong one was detected
```bash
sudo nano /etc/inferno.conf         # change INFERNO_NIC=eno1
sudo nano /etc/statime-inferno.toml # change interface = "eno1"
sudo nano /etc/alsa/conf.d/99-inferno.conf  # change bind_nic if present
sudo systemctl restart statime-inferno
systemctl --user restart inferno-bridge
```

Or cleanest: `sudo rm /etc/inferno.conf && sudo reboot` — re-runs full auto-detection.

### Fix a user service unit
```bash
nano ~/.config/systemd/user/inferno-bridge.service
systemctl --user daemon-reload
systemctl --user restart inferno-bridge
```

### Reload ALSA config
```bash
# ALSA doesn't hot-reload — restart the services that use it
systemctl --user restart inferno-bridge librespot
```

### Changes that require image rebuild
- Updating binaries (`statime`, `librespot`, ALSA plugin)
- Fixing the audio group or linger setup
- Changing config templates in `/etc/inferno/`
- Adding/removing packages
- Changing system-level service units

After rebuild: `sudo bootc upgrade && sudo reboot` (see [upgrade.md](upgrade.md)).

---

## Physical Console Access

For HP EliteDesk 800 machines with no remote management:

1. Attach monitor + USB keyboard to the machine
2. Power on — press **F10** to enter BIOS (also use to set UEFI mode if needed)
3. To reach the OS console: let it boot, GRUB appears briefly, then Fedora boots to TTY
4. Log in: **core** / **inferno123**
5. Run diagnostic commands above

**Enabling serial console (optional, for headless debugging):**
```bash
# On the node (once accessible):
sudo grubby --update-kernel=ALL --args="console=ttyS0,115200n8 console=tty0"
sudo reboot
# Then connect via USB-serial adapter at 115200 baud
```

---

## Rollback to Previous Image

If an upgrade broke the node and it's accessible:

```bash
ssh core@<node-ip>
bootc status            # shows current + staged + previous deployments
sudo bootc rollback     # stages the previous deployment
sudo reboot             # applies rollback — node boots previous image
```

If the node is not accessible after a bad upgrade (can't SSH), use physical console to run the same commands.

OSTree keeps the previous deployment on disk. Rollback is always available unless you've done two upgrades since the last known-good state.

---

## Full Reinstall (Last Resort)

Only needed if:
- The disk is corrupted
- UEFI boot order is wrong and node won't boot
- You want to start completely fresh

```bash
# 1. SCP latest ISO to your laptop
scp -i ~/.ssh/inferno_proxmox \
  root@10.10.1.201:/mnt/inferno-build/output/bootiso/install.iso \
  ~/inferno-appliance-latest.iso

# 2. Flash to USB
sudo dd if=~/inferno-appliance-latest.iso of=/dev/sdX bs=4M status=progress conv=fsync

# 3. Boot node from USB (F9 for HP boot menu at POST)
# 4. Anaconda installs automatically — no interaction needed
# 5. Node reboots twice, then appears in Dante Controller + Spotify
```

---

## Known Issues by Image Version

### Pre-v8: Audio group not in `/etc/group` → `No such device` on all ALSA

**Symptom:** `inferno-bridge` and `librespot` crash immediately with:
```
ALSA lib confmisc.c: Cannot get card index for Loopback
capture hw:Loopback,1,0 open error: No such device
```
`id` shows no `audio`: `groups=1000(core),10(wheel)` — missing `63(audio)`.

**Root cause:** All `/dev/snd/*` are `crw-rw---- root audio`. Without audio group
membership the user session cannot open any ALSA device. The `groupadd + usermod`
approach in pre-v8 images silently failed — `groupadd` refuses to write to `/etc/group`
when the group already exists in `/usr/lib/group` via NSS. Fixed in v8 with direct
`sed` write to `/etc/group`.

**Live fix (any pre-v8 node, one-time, survives upgrades):**
```bash
echo 'audio:x:63:core' | sudo tee -a /etc/group
sudo reboot
```

**Verify after reboot:**
```bash
id                                          # must show 63(audio)
systemctl --user is-active inferno-bridge   # must be active
```

