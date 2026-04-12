# Network Auto-Discovery — LLDP Device Classification

Virgil nodes run `lldpd` and advertise themselves on the wire via LLDP. Cisco IOS-XE switches
(Catalyst 3650/3850) with device classifier + autoconf enabled automatically place the port on the
Dante VLAN when they see the advertisement — no manual switch port configuration needed per node.

---

## How It Works

1. At first boot, `inferno-configure.sh` writes `/etc/lldpd.conf` with the node's name substituted:
   ```
   configure system description "Virgil-AoIP-Appliance Inferno-AB1234"
   ```
2. `lldpd.service` starts on every subsequent boot and broadcasts LLDP frames on all interfaces.
3. The switch sees the LLDP system description, matches the `"Virgil-AoIP"` prefix against its
   device classifier profile, and applies a service template to that port.
4. The service template assigns the Dante VLAN and enables portfast — no human intervention needed.

The LLDP system name TLV is set automatically to the node hostname (`inferno-<mac-suffix>`),
giving human-readable identity in `show lldp neighbors` output on the switch.

**No VLAN number is baked into the appliance.** The switch decides entirely based on its template.

---

## Appliance Side (automatic — no config required)

| Item | Detail |
|------|--------|
| Package | `lldpd` (Fedora DNF) |
| Service | `lldpd.service` — enabled, starts at boot |
| Config | `/etc/lldpd.conf` — written by `inferno-configure.sh` at first boot |
| Template source | `templates/lldpd.conf` (baked into image at `/etc/inferno/lldpd.conf.template`) |
| Description format | `"Virgil-AoIP-Appliance <INFERNO_NAME>"` |
| Classifier match prefix | `"Virgil-AoIP"` |

---

## Cisco Switch Side (one-time config per switch)

Replace `<dante-vlan-id>` with your actual Dante VLAN number.

```
! 1. Enable LLDP globally (required for device classifier)
lldp run

! 2. Enable autoconf globally
autoconf enable

! 3. Service template — applied automatically when a Virgil node is detected
template service virgil-dante
 switchport mode access
 switchport access vlan <dante-vlan-id>
 spanning-tree portfast

! 4. Device classifier — matches LLDP system description prefix "Virgil-AoIP"
device classifier
 device-type virgil-aoip include lldp system-description "Virgil-AoIP"

! 5. Map classifier to template
autoconf policy
 service-template virgil-dante device-type virgil-aoip

! 6. Enable autoconf on all access ports (adjust range to match your switch)
interface range GigabitEthernet1/0/1-48
 autoconf enable
```

### Supported platforms

| Switch | Support |
|--------|---------|
| Catalyst 3650 / 3850 (IOS-XE) | ✅ Confirmed design — device classifier + autoconf |
| Catalyst 3560X (IOS) | ⚠️ Verify per firmware version before relying on it in production |

---

## Verification

On the switch, after plugging in a Virgil node:

```
! Confirm LLDP advertisement received
show lldp neighbors detail

! Confirm device type was assigned
show device classifier attached

! Confirm template was applied to the port
show run interface GigabitEthernet1/0/X

! Confirm autoconf policy state
show autoconf interface GigabitEthernet1/0/X
```

On the node:

```bash
# Confirm lldpd is running and transmitting
systemctl status lldpd
lldpcli show statistics

# Confirm config is correct
cat /etc/lldpd.conf
```

---

## Patchbox

The `dante-patchbox` node will advertise `"Virgil-AoIP-Patchbox <NodeName>"` using the same
mechanism. The same switch service template applies — plug it in and it lands on the Dante VLAN
automatically.
