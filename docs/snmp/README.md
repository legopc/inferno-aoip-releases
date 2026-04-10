# SNMP Agent (Item 84)

Inferno exposes appliance health via SNMPv2c read-only on UDP 161.

## Architecture

```
Cisco NMS  ──(udp/161)──►  snmpd (net-snmp)
                                │
                         AgentX socket
                                │
                    inferno-snmp-subagent.py
                      (Python, reads state from
                       /etc/inferno.conf, systemd,
                       journald, /proc)
```

## Standard MIBs provided by net-snmp

- **sysDescr / system group** (SNMPv2-MIB): hostname, version via extend
- **ifTable** (IF-MIB): network interfaces
- **HOST-RESOURCES-MIB**: CPU, memory, storage, running processes

## Custom OIDs (.1.3.6.1.4.1.99999.1.x)

| OID | Name | Description |
|-----|------|-------------|
| .1  | infernoMode | Operating mode (spotify/aux-in/…) |
| .2  | infernoVersion | Image version string |
| .3  | infernoPtpState | PTP lock state (locked/acquiring/unknown) |
| .4  | infernoDanteState | inferno-bridge service state |
| .5  | infernoLibreState | librespot service state |
| .6  | infernoUptime | System uptime (seconds) |
| .7  | infernoHostname | Hostname |
| .8  | infernoPtpOffset | PTP offset from master (nanoseconds) |
| .9  | infernoSoundcard | Primary ALSA soundcard name |

MIB file: `INFERNO-MIB.txt` — import into your NMS/Cisco Prime/LibreNMS.

## Enable / Disable

Via **Cockpit → Inferno → Config tab → SNMP card**:
- Toggle switch enables/disables the agent
- Community string field (default: `public`)
- Changes take effect immediately (no reboot)

State is persisted via `/etc/inferno/.snmp-enabled` marker file.
The community string is stored in `/etc/inferno/.snmp-community`.

## Manual operation

```bash
# Enable
sudo touch /etc/inferno/.snmp-enabled
sudo systemctl start inferno-snmpd inferno-snmp-subagent

# Test (from NMS or another host)
snmpwalk -v2c -c public <node-ip> .1.3.6.1.4.1.99999.1
snmpwalk -v2c -c public <node-ip> system
snmpwalk -v2c -c public <node-ip> interfaces

# Disable
sudo systemctl stop inferno-snmp-subagent inferno-snmpd
sudo rm /etc/inferno/.snmp-enabled
```

## Systemd units

| Unit | Role |
|------|------|
| `inferno-snmpd.service` | net-snmp daemon, reads /etc/snmp/snmpd.conf |
| `inferno-snmp-subagent.service` | Python AgentX subagent, custom Inferno OIDs |

Neither unit is enabled by default. The marker file controls startup.
