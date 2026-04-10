#!/usr/bin/env python3
"""
inferno-snmp-subagent — AgentX subagent for the Inferno AoIP appliance.

Exposes appliance health to SNMP (SNMPv2c) via net-snmp AgentX.

Custom OIDs under .1.3.6.1.4.1.99999.1 (Inferno private enterprise arc):
  .1  infernoMode        — INFERNO_MODE from /etc/inferno.conf
  .2  infernoVersion     — version from /var/lib/inferno/version
  .3  infernoPtpState    — PTP lock state from statime journal
  .4  infernoDanteState  — inferno-bridge service state
  .5  infernoLibreState  — librespot service state
  .6  infernoUptime      — uptime in seconds
  .7  infernoHostname    — system hostname
  .8  infernoPtpOffset   — PTP offset_from_master (ns, integer)
  .9  infernoSoundcard   — ALSA soundcard name from /proc/asound/cards
"""

import sys
import os
import re
import time
import subprocess
import socket

try:
    import agentx
except ImportError:
    # Try netsnmpagent as fallback
    try:
        import netsnmpagent
    except ImportError:
        sys.stderr.write("ERROR: Neither agentx nor netsnmpagent Python module found.\n")
        sys.stderr.write("Install: pip3 install agentx  or  pip3 install netsnmp-agent-python\n")
        sys.exit(1)

# ── Constants ─────────────────────────────────────────────────────────────────
CONF_FILE    = "/etc/inferno.conf"
VERSION_FILE = "/var/lib/inferno/version"
ENTERPRISE   = ".1.3.6.1.4.1.99999.1"   # Inferno private enterprise arc
AGENTX_SOCKET = "/var/agentx/master"

POLL_INTERVAL = 30  # seconds between data refresh


# ── Helpers ───────────────────────────────────────────────────────────────────

def read_file(path, default=""):
    try:
        with open(path) as f:
            return f.read().strip()
    except Exception:
        return default


def parse_conf(text):
    conf = {}
    for line in text.splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        if "=" in line:
            k, _, v = line.partition("=")
            conf[k.strip()] = v.strip()
    return conf


def get_systemd_state(unit):
    """Return systemd ActiveState for a unit (root + user fallback)."""
    # Try system unit first
    for scope in [["systemctl", "is-active", unit],
                  ["systemctl", "--user", "-M", "core@", "is-active", unit]]:
        try:
            r = subprocess.run(scope, capture_output=True, text=True, timeout=5)
            state = r.stdout.strip()
            if state:
                return state
        except Exception:
            pass
    return "unknown"


def get_ptp_offset():
    """Extract most recent offset_from_master from statime journal."""
    try:
        r = subprocess.run(
            ["journalctl", "-u", "statime-inferno", "-n", "50",
             "--no-pager", "--output=cat"],
            capture_output=True, text=True, timeout=10
        )
        # Look for offset_from_master: Ns or offset: Nns
        for m in re.finditer(r'offset[_\s](?:from_master[:\s]+)?(-?\d+)\s*n?s', r.stdout, re.I):
            val = m.group(1)
        # return last match
        matches = re.findall(r'offset[_\s](?:from_master[:\s]+)?(-?\d+)\s*n?s', r.stdout, re.I)
        if matches:
            return int(matches[-1])
    except Exception:
        pass
    return 0


def get_ptp_state():
    """Return PTP state string: locked / acquiring / unknown."""
    try:
        r = subprocess.run(
            ["journalctl", "-u", "statime-inferno", "-n", "30",
             "--no-pager", "--output=cat"],
            capture_output=True, text=True, timeout=10
        )
        text = r.stdout.lower()
        if "synchronized" in text or "locked" in text or "slave" in text:
            return "locked"
        if "offset" in text:
            return "acquiring"
    except Exception:
        pass
    svc = get_systemd_state("statime-inferno")
    if svc == "active":
        return "acquiring"
    return "unknown"


def get_soundcard():
    try:
        with open("/proc/asound/cards") as f:
            first = f.readline().strip()
            # e.g.  " 0 [HDMI           ]: HDA-Intel - HDA Intel HDMI"
            m = re.search(r'\[(\S+)\s*\]', first)
            if m:
                return m.group(1)
            return first[:64]
    except Exception:
        return "unknown"


def collect_data():
    conf = parse_conf(read_file(CONF_FILE))
    return {
        "mode":       conf.get("INFERNO_MODE", "unknown"),
        "version":    read_file(VERSION_FILE, "unknown"),
        "ptp_state":  get_ptp_state(),
        "ptp_offset": get_ptp_offset(),
        "dante_state": get_systemd_state("inferno-bridge"),
        "libre_state": get_systemd_state("librespot"),
        "uptime":     int(time.time() - _boot_time),
        "hostname":   socket.gethostname(),
        "soundcard":  get_soundcard(),
    }


# ── Boot time ─────────────────────────────────────────────────────────────────
def _get_boot_time():
    try:
        with open("/proc/uptime") as f:
            up = float(f.read().split()[0])
        return time.time() - up
    except Exception:
        return time.time()

_boot_time = _get_boot_time()


# ── AgentX implementation (netsnmpagent) ──────────────────────────────────────

def run_netsnmpagent():
    import netsnmpagent

    agent = netsnmpagent.netsnmpAgent(
        AgentName   = "InfernoSnmpAgent",
        MasterSocket= AGENTX_SOCKET,
        MIBFiles    = [],
    )

    # Register OIDs
    oids = {
        "mode":        agent.OctetString( oidstr=ENTERPRISE+".1.0" ),
        "version":     agent.OctetString( oidstr=ENTERPRISE+".2.0" ),
        "ptp_state":   agent.OctetString( oidstr=ENTERPRISE+".3.0" ),
        "dante_state": agent.OctetString( oidstr=ENTERPRISE+".4.0" ),
        "libre_state": agent.OctetString( oidstr=ENTERPRISE+".5.0" ),
        "uptime":      agent.Unsigned32(  oidstr=ENTERPRISE+".6.0" ),
        "hostname":    agent.OctetString( oidstr=ENTERPRISE+".7.0" ),
        "ptp_offset":  agent.Integer32(   oidstr=ENTERPRISE+".8.0" ),
        "soundcard":   agent.OctetString( oidstr=ENTERPRISE+".9.0" ),
    }

    agent.start()

    last_refresh = 0
    data = {}

    while True:
        now = time.time()
        if now - last_refresh >= POLL_INTERVAL:
            data = collect_data()
            last_refresh = now

            oids["mode"].update(data["mode"])
            oids["version"].update(data["version"])
            oids["ptp_state"].update(data["ptp_state"])
            oids["dante_state"].update(data["dante_state"])
            oids["libre_state"].update(data["libre_state"])
            oids["uptime"].update(data["uptime"])
            oids["hostname"].update(data["hostname"])
            oids["ptp_offset"].update(data["ptp_offset"])
            oids["soundcard"].update(data["soundcard"])

        agent.check_and_process(block=False)
        time.sleep(1)


def run_agentx():
    """Fallback: use the 'agentx' module."""
    import agentx as ax

    data = collect_data()
    last_refresh = [time.time()]

    def refresh():
        nonlocal data
        if time.time() - last_refresh[0] >= POLL_INTERVAL:
            data = collect_data()
            last_refresh[0] = time.time()

    # Build a simple scalar OID map
    def oid(suffix):
        return ENTERPRISE.lstrip(".") + "." + str(suffix) + ".0"

    class InfernoAgent(ax.Agent):
        def get(self, reqid, oid_list):
            refresh()
            results = []
            for o in oid_list:
                o_str = str(o)
                if o_str.endswith(ENTERPRISE.lstrip(".")+".1.0"):
                    results.append((o, ax.OctetString(data["mode"])))
                elif o_str.endswith(ENTERPRISE.lstrip(".")+".2.0"):
                    results.append((o, ax.OctetString(data["version"])))
                elif o_str.endswith(ENTERPRISE.lstrip(".")+".3.0"):
                    results.append((o, ax.OctetString(data["ptp_state"])))
                elif o_str.endswith(ENTERPRISE.lstrip(".")+".4.0"):
                    results.append((o, ax.OctetString(data["dante_state"])))
                elif o_str.endswith(ENTERPRISE.lstrip(".")+".5.0"):
                    results.append((o, ax.OctetString(data["libre_state"])))
                elif o_str.endswith(ENTERPRISE.lstrip(".")+".6.0"):
                    results.append((o, ax.Unsigned32(data["uptime"])))
                elif o_str.endswith(ENTERPRISE.lstrip(".")+".7.0"):
                    results.append((o, ax.OctetString(data["hostname"])))
                elif o_str.endswith(ENTERPRISE.lstrip(".")+".8.0"):
                    results.append((o, ax.Integer(data["ptp_offset"])))
                elif o_str.endswith(ENTERPRISE.lstrip(".")+".9.0"):
                    results.append((o, ax.OctetString(data["soundcard"])))
                else:
                    results.append((o, ax.NoSuchObject()))
            return results

    a = InfernoAgent(master=AGENTX_SOCKET)
    a.register(ENTERPRISE)
    a.run()


# ── Main ──────────────────────────────────────────────────────────────────────
if __name__ == "__main__":
    try:
        import netsnmpagent
        run_netsnmpagent()
    except ImportError:
        run_agentx()
