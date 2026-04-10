# Factory Reset — Inferno AoIP Appliance

Factory reset wipes all mutable configuration and returns the appliance to its
first-boot defaults. The OS image (bootc layer) is **never modified** — only
state stored in `/etc/inferno/` and `/var/lib/inferno/` is erased.

---

## How it works

The factory reset is **marker-triggered**: when a reset is requested, a JSON
marker file is written to `/var/lib/inferno/.factory-reset-pending`. On the
next boot, `inferno-factory-reset.service` runs early (before all Inferno
services), detects the marker, executes `/usr/local/sbin/inferno-reset.sh`,
and reboots into a clean first-boot state.

```
Cockpit UI → double-confirm → write marker → reboot
                                                  ↓
                                         Early boot (before network)
                                                  ↓
                         inferno-factory-reset.service (ConditionPathExists)
                                                  ↓
                                    inferno-reset.sh (runs as root)
                                                  ↓
                                     Wipe → Remove marker → Reboot
```

If the reset script fails partway through, the marker file remains and the
reset is **retried on the next boot**. An admin can SSH in to investigate
before allowing another boot.

---

## How to trigger

### Via Cockpit (recommended)

1. Open `https://<node-ip>:9090` and navigate to **Inferno → Actions**
2. Click **Factory Reset** — a double-confirmation dialog appears
3. Confirm twice; the UI writes the marker and issues a reboot
4. The node reboots, performs the wipe, then reboots again into first-boot state

### Via CLI (emergency / scripted)

```bash
sudo mkdir -p /var/lib/inferno
sudo python3 -c "
import json, datetime
marker = {
    'requested_at': datetime.datetime.utcnow().isoformat() + 'Z',
    'requested_by': 'cli-manual'
}
with open('/var/lib/inferno/.factory-reset-pending', 'w') as f:
    json.dump(marker, f)
"
sudo systemctl reboot
```

---

## What gets wiped

| Item | Action |
|------|--------|
| `/etc/inferno/` | Deleted and recreated empty |
| `/var/lib/inferno/` state & cache | Deleted (marker removed last) |
| Hostname | Reset to `inferno-appliance` |
| NetworkManager override connections | All `.nmconnection` / `.conf` files removed; falls back to DHCP |
| Local user passwords | Locked (`passwd -l`); forced expiry on next login |
| SSH host keys | Removed; regenerated on next boot |
| Inferno system services | Stopped before wipe (`statime-inferno`, `inferno-health-check`) |
| Inferno user services | Stopped (`librespot`, `inferno-bridge`, `inferno-aux-*`) |

## What is NOT wiped

| Item | Reason |
|------|--------|
| OS / bootc image | Immutable — factory reset only touches mutable state |
| `/home/` (if any) | Not part of appliance state; not touched |
| UEFI / BIOS settings | Hardware-level, not touched |
| Dante hardware config | External hardware (Dante AVIO/switch), not managed by Inferno |

---

## Recovery notes

After reset the appliance boots into first-boot state:

1. **Network**: DHCP is active; check your DHCP server for the new IP
   (hostname will be `inferno-appliance` until reconfigured)
2. **SSH**: Host keys are regenerated — clear the old entry from
   `~/.ssh/known_hosts`: `ssh-keygen -R <node-ip>`
3. **Cockpit login**: Default credentials apply; passwords must be set on first login
4. **Configuration**: Use Cockpit **Config** tab to re-enter mode, Dante TX
   name, audio cards, and network interface; click **Save & Apply**

If the node fails to boot after reset, connect a monitor/serial console.
The `inferno-factory-reset.service` journal output is visible in the boot log.

---

## Security considerations

- Factory reset is available to **any authenticated Cockpit user with admin
  privileges**. Restrict Cockpit access to trusted management networks.
- The marker file contains a timestamp and requester identity for audit
  purposes; this is logged to journald with tag `inferno-factory-reset`.
- After reset, SSH host keys are replaced — verify fingerprints out-of-band
  if the management network is untrusted.
- The reset does **not** wipe the bootc image. A compromised OS layer
  survives a factory reset; use `bootc switch` / re-image for full remediation.
- Treat `/var/lib/inferno/.factory-reset-pending` as security-sensitive —
  anyone who can write this file and trigger a reboot can wipe the appliance.
