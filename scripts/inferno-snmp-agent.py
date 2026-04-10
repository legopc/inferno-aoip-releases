#!/usr/bin/env python3
"""
inferno-snmp-agent.py — AgentX subagent for Inferno AoIP appliance

Exposes appliance health and Dante/audio state via SNMPv2c.
Connects to net-snmp's snmpd via AgentX protocol (RFC 2741).

OID tree:
  Standard MIBs (handled by snmpd directly):
    - sysDescr, sysUpTime, ifTable, hrSystem* (HOST-RESOURCES-MIB)
  Custom Inferno OIDs under IANA private enterprise arc:
    enterprises.99999.1  (inferno-aoip)
      .1.0  infernoMode         (string)  — current appliance mode (spotify/aux-tx/aux-rx/etc)
      .2.0  infernoVersion      (string)  — inferno binary version
      .3.0  infernoConfigured   (integer) — 1=configured, 0=unconfigured (sentinel present)
      .4.0  infernoServiceCount (integer) — number of running inferno user services
      .5.0  infernoDanteRunning (integer) — 1=dante process detected, 0=not running
      .6.0  infernoPTPState     (string)  — PTP sync state from last health check
      .7.0  infernoAudioLoopback (integer) — 1=snd-aloop module loaded, 0=not loaded
      .8.0  infernoLastHealthCheck (string) — ISO timestamp of last health check run

NOTE: enterprises.99999 is a placeholder. Jelle needs to either:
  a) Register a real PEN at https://www.iana.org/assignments/enterprise-numbers/
  b) Use an internal/private arc and document it
  Current placeholder: .1.3.6.1.4.1.99999.1

Dependencies (must be in container image):
  pip3 install pyagentx3
  dnf install net-snmp net-snmp-utils
"""

import os
import sys
import time
import json
import logging
import subprocess
import threading
import pyagentx

# ── Config ────────────────────────────────────────────────────────────────────

# OID base: enterprises.99999.1 (inferno-aoip subtree)
# TODO: replace 99999 with real PEN once registered
INFERNO_OID_BASE = "1.3.6.1.4.1.99999.1"

INFERNO_CONF_PATH   = "/etc/inferno/inferno.conf"
SENTINEL_PATH       = "/etc/inferno/.deployed"
HEALTH_STATE_PATH   = "/var/lib/inferno/health-state.json"
AGENTX_SOCKET       = "/var/agentx/master"

LOG_LEVEL = logging.INFO

# ── Logging ──────────────────────────────────────────────────────────────────

logging.basicConfig(
    level=LOG_LEVEL,
    format="%(asctime)s inferno-snmp-agent %(levelname)s %(message)s",
    handlers=[logging.StreamHandler(sys.stdout)]
)
log = logging.getLogger("inferno-snmp")


# ── Data collection helpers ───────────────────────────────────────────────────

def read_conf_value(key: str, default: str = "") -> str:
    """Read a single key=value from /etc/inferno/inferno.conf."""
    try:
        with open(INFERNO_CONF_PATH) as f:
            for line in f:
                line = line.strip()
                if line.startswith(key + "="):
                    return line.split("=", 1)[1].strip().strip('"')
    except OSError:
        pass
    return default


def get_mode() -> str:
    return read_conf_value("MODE", "unknown")


def get_version() -> str:
    """Try to get the inferno binary version."""
    try:
        out = subprocess.check_output(
            ["inferno", "--version"],
            stderr=subprocess.STDOUT,
            timeout=3
        ).decode().strip()
        return out[:64]  # truncate for safety
    except Exception:
        pass
    # Fallback: read from OCI label file if present
    try:
        with open("/etc/inferno/version") as f:
            return f.read().strip()[:64]
    except OSError:
        return "unknown"


def get_configured() -> int:
    """Return 1 if deploy sentinel exists (binaries deployed), 0 otherwise."""
    return 1 if os.path.exists(SENTINEL_PATH) else 0


def get_service_count() -> int:
    """Count running inferno user services via systemctl."""
    try:
        out = subprocess.check_output(
            ["systemctl", "--user", "-M", "inferno@",
             "list-units", "--state=running", "--no-legend",
             "inferno-*.service", "librespot*.service"],
            stderr=subprocess.DEVNULL,
            timeout=5
        ).decode()
        return len([l for l in out.strip().splitlines() if l.strip()])
    except Exception:
        return -1


def get_dante_running() -> int:
    """Return 1 if any dante/conman process is running."""
    try:
        out = subprocess.check_output(
            ["pgrep", "-x", "conman"],
            stderr=subprocess.DEVNULL,
            timeout=3
        )
        return 1 if out.strip() else 0
    except subprocess.CalledProcessError:
        return 0
    except Exception:
        return 0


def get_ptp_state() -> str:
    """Read PTP state from health-state.json if available."""
    try:
        with open(HEALTH_STATE_PATH) as f:
            data = json.load(f)
            return str(data.get("ptp_state", "unknown"))[:64]
    except OSError:
        pass
    # Fallback: quick statime status check
    try:
        out = subprocess.check_output(
            ["systemctl", "is-active", "statime-inferno"],
            stderr=subprocess.DEVNULL,
            timeout=3
        ).decode().strip()
        return out
    except Exception:
        return "unknown"


def get_audio_loopback() -> int:
    """Return 1 if snd-aloop kernel module is loaded."""
    try:
        with open("/proc/modules") as f:
            for line in f:
                if line.startswith("snd_aloop"):
                    return 1
        return 0
    except OSError:
        return 0


def get_last_health_check() -> str:
    """Return ISO timestamp of last health check run."""
    try:
        with open(HEALTH_STATE_PATH) as f:
            data = json.load(f)
            return str(data.get("last_check", "never"))[:32]
    except OSError:
        return "never"


# ── AgentX Updater ────────────────────────────────────────────────────────────

class InfernoUpdater(pyagentx.Updater):
    """
    Periodic data updater. Called by pyagentx every update_frequency seconds.
    Populates the OID subtree with fresh values from the appliance.
    """

    def update(self):
        base = INFERNO_OID_BASE
        try:
            # .1.0 — mode (OctetString)
            self.set_OCTETSTRING(base + ".1.0", get_mode())
            # .2.0 — version (OctetString)
            self.set_OCTETSTRING(base + ".2.0", get_version())
            # .3.0 — configured (Integer)
            self.set_INTEGER(base + ".3.0", get_configured())
            # .4.0 — running service count (Integer)
            self.set_INTEGER(base + ".4.0", get_service_count())
            # .5.0 — dante running (Integer, boolean)
            self.set_INTEGER(base + ".5.0", get_dante_running())
            # .6.0 — PTP state (OctetString)
            self.set_OCTETSTRING(base + ".6.0", get_ptp_state())
            # .7.0 — audio loopback (Integer, boolean)
            self.set_INTEGER(base + ".7.0", get_audio_loopback())
            # .8.0 — last health check timestamp (OctetString)
            self.set_OCTETSTRING(base + ".8.0", get_last_health_check())
        except Exception as e:
            log.error("Updater error: %s", e)


# ── Main ──────────────────────────────────────────────────────────────────────

class InfernoAgent(pyagentx.Agent):
    def setup(self):
        # Register the inferno subtree
        # update_frequency: how often InfernoUpdater.update() is called (seconds)
        self.register(INFERNO_OID_BASE, InfernoUpdater, update_frequency=30)


def main():
    log.info("Inferno SNMP AgentX subagent starting (OID base: %s)", INFERNO_OID_BASE)

    # Wait for snmpd agentx socket to appear (it may not be up yet at boot)
    deadline = time.time() + 60
    while not os.path.exists(AGENTX_SOCKET):
        if time.time() > deadline:
            log.error("AgentX socket %s not available after 60s — snmpd running?", AGENTX_SOCKET)
            sys.exit(1)
        log.info("Waiting for AgentX socket %s ...", AGENTX_SOCKET)
        time.sleep(5)

    pyagentx.setup_logging()
    agent = InfernoAgent()
    try:
        agent.start()
    except KeyboardInterrupt:
        log.info("Interrupted — shutting down")
        agent.stop()
    except Exception as e:
        log.error("Agent fatal error: %s", e)
        sys.exit(1)


if __name__ == "__main__":
    main()
