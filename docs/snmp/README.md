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

The subagent (`inferno-snmp-subagent.py`) registers custom OIDs under the
private enterprise arc `.1.3.6.1.4.1.99999.1` via the net-snmp AgentX
protocol. Net-snmp handles all SNMPv2c framing; the subagent only manages
the Inferno-specific OIDs.

## Standard MIBs provided by net-snmp

- **sysDescr / system group** (SNMPv2-MIB): hostname, version via extend
- **ifTable** (IF-MIB): network interfaces
- **HOST-RESOURCES-MIB**: CPU, memory, storage, running processes

## Custom OIDs (.1.3.6.1.4.1.99999.1.x)

| OID suffix | Full OID | Name | Type | Description |
|------------|----------|------|------|-------------|
| .1 | .1.3.6.1.4.1.99999.1.1 | infernoMode | STRING | Operating mode (spotify/aux-in/aux-out/aux-bidir/iradio) |
| .2 | .1.3.6.1.4.1.99999.1.2 | infernoVersion | STRING | Image version string |
| .3 | .1.3.6.1.4.1.99999.1.3 | infernoPtpState | STRING | PTP lock state (locked/acquiring/unknown) |
| .4 | .1.3.6.1.4.1.99999.1.4 | infernoDanteState | STRING | inferno-bridge service state |
| .5 | .1.3.6.1.4.1.99999.1.5 | infernoLibreState | STRING | librespot service state |
| .6 | .1.3.6.1.4.1.99999.1.6 | infernoUptime | INTEGER | System uptime (seconds) |
| .7 | .1.3.6.1.4.1.99999.1.7 | infernoHostname | STRING | Hostname |
| .8 | .1.3.6.1.4.1.99999.1.8 | infernoPtpOffset | INTEGER | PTP offset from master (nanoseconds) |
| .9 | .1.3.6.1.4.1.99999.1.9 | infernoSoundcard | STRING | Primary ALSA soundcard name |

MIB file: [`INFERNO-MIB.txt`](INFERNO-MIB.txt) — import into your NMS.

---

## Enable / Disable

### Via Cockpit (recommended)

1. Open `https://<node-ip>:9090` → **Inferno → Config tab → SNMP card**
2. Toggle the **Enable SNMP** switch
3. Optionally change the **Community String** (default: `public`)
4. Changes take effect immediately — no reboot required

State is persisted:
- Enabled marker: `/etc/inferno/.snmp-enabled`
- Community string: `/etc/inferno/.snmp-community`

### Via CLI

```bash
# Enable
sudo touch /etc/inferno/.snmp-enabled
sudo systemctl start inferno-snmpd inferno-snmp-subagent

# Change community string
echo -n "mycommunity" | sudo tee /etc/inferno/.snmp-community
sudo systemctl restart inferno-snmpd

# Disable
sudo systemctl stop inferno-snmp-subagent inferno-snmpd
sudo rm /etc/inferno/.snmp-enabled
```

---

## Systemd units

| Unit | Role |
|------|------|
| `inferno-snmpd.service` | net-snmp daemon, reads `/etc/snmp/snmpd.conf` |
| `inferno-snmp-subagent.service` | Python AgentX subagent, custom Inferno OIDs |

Neither unit is enabled by default. The marker file controls startup.

---

## Testing

```bash
# Walk all Inferno custom OIDs
snmpwalk -v2c -c public <node-ip> .1.3.6.1.4.1.99999.1

# Walk standard system group
snmpwalk -v2c -c public <node-ip> system

# Walk interfaces
snmpwalk -v2c -c public <node-ip> interfaces

# Get a single OID (e.g. infernoMode)
snmpget -v2c -c public <node-ip> .1.3.6.1.4.1.99999.1.1
```

---

## Importing INFERNO-MIB into your NMS

### LibreNMS

1. Copy `INFERNO-MIB.txt` to `/opt/librenms/mibs/` on the LibreNMS host
2. Run `php /opt/librenms/artisan snmp:mibs` to rebuild the MIB cache
3. In the LibreNMS web UI, add the Inferno node as a device (SNMP v2c,
   community string matching `/etc/inferno/.snmp-community`)
4. LibreNMS will auto-discover the standard MIBs (system, ifTable,
   HOST-RESOURCES-MIB)
5. For custom Inferno OIDs, create a **Custom OID** or use **Oxidized** +
   device-type template — LibreNMS doesn't graph arbitrary private-enterprise
   OIDs automatically without a device definition

### Cisco Prime Infrastructure / Cisco DNA Center

1. Go to **Administration → System Settings → MIBs** (Prime) or use the
   MIB browser in your Cisco NMS
2. Upload `INFERNO-MIB.txt` via the MIB upload dialog
3. Add the Inferno device with SNMP v2c credentials
4. Use the **MIB Browser** to walk `.1.3.6.1.4.1.99999.1` and verify OID
   resolution against the imported MIB

### Generic NMS / Cacti / Zabbix

- Place `INFERNO-MIB.txt` in the system MIB directory (typically
  `/usr/share/snmp/mibs/` on Linux)
- Run `snmptranslate -m +INFERNO-MIB .1.3.6.1.4.1.99999.1.1` to verify
  the MIB loads correctly
- For Zabbix: create a **SNMP template** using the OIDs in the table above,
  or import a pre-built template if available in `templates/zabbix/`
