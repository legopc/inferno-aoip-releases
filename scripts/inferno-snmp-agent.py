#!/usr/bin/env python3
"""
inferno-snmp-agent.py — AgentX subagent for Inferno AoIP appliance

Exposes appliance health and Dante/audio state via SNMPv2c.
Connects to net-snmp's snmpd via AgentX protocol (RFC 2741).

OID tree (base: .1.3.6.1.4.1.65535.1  — IANA private-use arc, internal deployment only):

  node(1)
    .1.0  nodeHostname        STRING   — system hostname
    .2.0  nodeRole            INTEGER  — virgil(1), patchbox(2), central(3)
    .3.0  nodeVersion         STRING   — bootc image tag / inferno binary version
    .4.0  nodeMode            INTEGER  — spotify(1), auxIn(2), auxOut(3), auxBidir(4), iradio(5), bluetooth(6)
    .5.0  nodeConfigured      INTEGER  — 1=configured, 0=unconfigured

  services(2)
    .1.0  svcInfernoAoip      INTEGER  — up(1), down(2), degraded(3)
    .2.0  svcStatime          INTEGER  — up(1), down(2), degraded(3)
    .3.0  svcCockpit          INTEGER  — up(1), down(2), degraded(3)
    .4.0  svcLibrespot        INTEGER  — up(1), down(2), degraded(3), notApplicable(4)
    .5.0  svcIradio           INTEGER  — up(1), down(2), degraded(3), notApplicable(4)
    .6.0  svcBluetooth        INTEGER  — up(1), down(2), degraded(3), notApplicable(4)
    .7.0  svcAuxIn            INTEGER  — up(1), down(2), degraded(3), notApplicable(4)
    .8.0  svcAuxOut           INTEGER  — up(1), down(2), degraded(3), notApplicable(4)
    .9.0  svcCockpitUpdater   INTEGER  — up(1), down(2), degraded(3), notApplicable(4)

  dante(3)
    .1.0  danteDeviceState    INTEGER  — online(1), offline(2), fault(3)
    .2.0  danteRxStreams       Gauge32  — active receive flows
    .3.0  danteTxStreams       Gauge32  — active transmit flows
    .4.0  danteSubscribed     INTEGER  — allSubscribed(1), partial(2), none(3)
    .5.0  danteLatencyUs      Gauge32  — configured latency in microseconds

  ptp(4)
    .1.0  ptpSyncStatus       INTEGER  — locked(1), acquiring(2), unlocked(3), fault(4)
    .2.0  ptpOffsetNs         Integer32 — offset from master in nanoseconds
    .3.0  ptpClockRole        INTEGER  — master(1), slave(2), passive(3)
    .4.0  ptpGmIdentity       STRING   — grandmaster clock ID (EUI-64 hex)

  audio(5)
    .1.0  audioInputLevel     Gauge32  — peak input dBFS * -100 (e.g. -18dBFS = 1800)
    .2.0  audioOutputLevel    Gauge32  — peak output dBFS * -100
    .3.0  audioClipping       Counter32 — clip events since last reset
    .4.0  audioSampleRate     Gauge32  — Hz (44100, 48000, etc.)
    .5.0  audioLoopbackLoaded INTEGER  — 1=snd-aloop loaded, 0=not loaded

  spotify(6)  [only meaningful when nodeMode=spotify]
    .1.0  spotifyState        INTEGER  — playing(1), paused(2), idle(3), disconnected(4)
    .2.0  spotifyTrack        STRING   — "Artist - Title" (truncated 64 chars)
    .3.0  spotifyVolume       Gauge32  — 0-100

  iradio(7)  [only meaningful when nodeMode=iradio]
    .1.0  iradioState         INTEGER  — playing(1), paused(2), idle(3), disconnected(4)
    .2.0  iradioStation       STRING   — current station name (truncated 64 chars)
    .3.0  iradioUrl           STRING   — current stream URL (truncated 128 chars)

  system(8)
    .1.0  sysLastHealthCheck  STRING   — ISO timestamp of last health check
    .2.0  sysUptime           Gauge32  — appliance uptime in seconds
    .3.0  sysServiceCount     INTEGER  — number of running inferno services

Dependencies:
  pip3 install pyagentx3
  dnf install net-snmp net-snmp-utils
"""

import os
import sys
import time
import json
import socket
import logging
import subprocess
import pyagentx

# ── Config ────────────────────────────────────────────────────────────────────

# IANA private-use arc (.1.3.6.1.4.1.65535) — reserved for internal/testing use,
# will not conflict with any registered enterprise. Internal deployment only.
OID_BASE         = "1.3.6.1.4.1.65535.1"
OID_NODE         = OID_BASE + ".1"
OID_SERVICES     = OID_BASE + ".2"
OID_DANTE        = OID_BASE + ".3"
OID_PTP          = OID_BASE + ".4"
OID_AUDIO        = OID_BASE + ".5"
OID_SPOTIFY      = OID_BASE + ".6"
OID_IRADIO       = OID_BASE + ".7"
OID_SYSTEM       = OID_BASE + ".8"

INFERNO_CONF     = "/etc/inferno/inferno.conf"
SENTINEL_PATH    = "/etc/inferno/.deployed"
HEALTH_STATE     = "/var/lib/inferno/health-state.json"
AGENTX_SOCKET    = "/var/agentx/master"
UPDATE_INTERVAL  = 30  # seconds

# Service state constants
SVC_UP           = 1
SVC_DOWN         = 2
SVC_DEGRADED     = 3
SVC_NA           = 4

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s inferno-snmp %(levelname)s %(message)s",
    handlers=[logging.StreamHandler(sys.stdout)]
)
log = logging.getLogger("inferno-snmp")


# ── Helpers ───────────────────────────────────────────────────────────────────

def read_conf(key: str, default: str = "") -> str:
    try:
        with open(INFERNO_CONF) as f:
            for line in f:
                line = line.strip()
                if line.startswith(key + "="):
                    return line.split("=", 1)[1].strip().strip('"')
    except OSError:
        pass
    return default


def health_state() -> dict:
    try:
        with open(HEALTH_STATE) as f:
            return json.load(f)
    except (OSError, json.JSONDecodeError):
        return {}


def systemd_active(unit: str) -> bool:
    try:
        r = subprocess.run(
            ["systemctl", "is-active", unit],
            capture_output=True, text=True, timeout=3
        )
        return r.stdout.strip() == "active"
    except Exception:
        return False


def systemd_exists(unit: str) -> bool:
    try:
        r = subprocess.run(
            ["systemctl", "list-unit-files", unit],
            capture_output=True, text=True, timeout=3
        )
        return unit in r.stdout
    except Exception:
        return False


def svc_state(unit: str, applicable: bool = True) -> int:
    if not applicable:
        return SVC_NA
    if not systemd_exists(unit):
        return SVC_NA
    return SVC_UP if systemd_active(unit) else SVC_DOWN


def mode_to_int(mode: str) -> int:
    return {
        "spotify": 1, "aux-in": 2, "aux-out": 3,
        "aux-bidir": 4, "iradio": 5, "bluetooth": 6
    }.get(mode.lower(), 0)


def uptime_seconds() -> int:
    try:
        with open("/proc/uptime") as f:
            return int(float(f.read().split()[0]))
    except Exception:
        return 0


def running_inferno_services() -> int:
    try:
        out = subprocess.check_output(
            ["systemctl", "--state=running", "--no-legend", "--plain",
             "--type=service"],
            stderr=subprocess.DEVNULL, timeout=5
        ).decode()
        return sum(1 for l in out.splitlines() if "inferno" in l or "librespot" in l or "statime" in l)
    except Exception:
        return -1


# ── Spotify helpers ───────────────────────────────────────────────────────────

def spotify_state_int() -> int:
    # Try reading from health state or librespot status file
    hs = health_state()
    state = hs.get("spotify_state", "")
    return {"playing": 1, "paused": 2, "idle": 3}.get(state, 4)


def spotify_track() -> str:
    hs = health_state()
    return str(hs.get("spotify_track", ""))[:64]


def spotify_volume() -> int:
    hs = health_state()
    return int(hs.get("spotify_volume", 0))


# ── Iradio helpers ────────────────────────────────────────────────────────────

def iradio_state_int() -> int:
    hs = health_state()
    state = hs.get("iradio_state", "")
    return {"playing": 1, "paused": 2, "idle": 3}.get(state, 4)


def iradio_station() -> str:
    hs = health_state()
    return str(hs.get("iradio_station", ""))[:64]


def iradio_url() -> str:
    hs = health_state()
    return str(hs.get("iradio_url", ""))[:128]


# ── Dante helpers ─────────────────────────────────────────────────────────────

def dante_state_int() -> int:
    hs = health_state()
    state = hs.get("dante_state", "")
    return {"online": 1, "offline": 2, "fault": 3}.get(state, 2)


def dante_rx_streams() -> int:
    hs = health_state()
    return int(hs.get("dante_rx_streams", 0))


def dante_tx_streams() -> int:
    hs = health_state()
    return int(hs.get("dante_tx_streams", 0))


def dante_subscribed_int() -> int:
    hs = health_state()
    state = hs.get("dante_subscribed", "")
    return {"all": 1, "partial": 2, "none": 3}.get(state, 3)


def dante_latency_us() -> int:
    hs = health_state()
    return int(hs.get("dante_latency_us", 0))


# ── PTP helpers ───────────────────────────────────────────────────────────────

def ptp_sync_int() -> int:
    hs = health_state()
    state = hs.get("ptp_state", "")
    return {"locked": 1, "acquiring": 2, "unlocked": 3, "fault": 4}.get(state, 3)


def ptp_offset_ns() -> int:
    hs = health_state()
    return int(hs.get("ptp_offset_ns", 0))


def ptp_role_int() -> int:
    hs = health_state()
    role = hs.get("ptp_role", "")
    return {"master": 1, "slave": 2, "passive": 3}.get(role, 2)


def ptp_gm_identity() -> str:
    hs = health_state()
    return str(hs.get("ptp_gm_identity", "unknown"))[:32]


# ── Audio helpers ─────────────────────────────────────────────────────────────

def audio_input_level() -> int:
    hs = health_state()
    # dBFS stored as float e.g. -18.5, encode as abs*100 = 1850
    return int(abs(float(hs.get("audio_input_dbfs", -60))) * 100)


def audio_output_level() -> int:
    hs = health_state()
    return int(abs(float(hs.get("audio_output_dbfs", -60))) * 100)


def audio_clip_count() -> int:
    hs = health_state()
    return int(hs.get("audio_clip_count", 0))


def audio_sample_rate() -> int:
    hs = health_state()
    return int(hs.get("audio_sample_rate", 48000))


def audio_loopback_loaded() -> int:
    try:
        with open("/proc/modules") as f:
            for line in f:
                if line.startswith("snd_aloop"):
                    return 1
        return 0
    except OSError:
        return 0


# ── AgentX Updater ────────────────────────────────────────────────────────────

class InfernoUpdater(pyagentx.Updater):

    def update(self):
        try:
            mode_str = read_conf("MODE", "unknown")
            mode_int = mode_to_int(mode_str)
            is_spotify   = mode_int == 1
            is_iradio    = mode_int == 5
            is_bluetooth = mode_int == 6
            is_aux       = mode_int in (2, 3, 4)

            # node(1)
            self.set_OCTETSTRING(OID_NODE + ".1.0", socket.gethostname()[:64])
            self.set_INTEGER    (OID_NODE + ".2.0", 1)  # virgil role
            self.set_OCTETSTRING(OID_NODE + ".3.0", read_conf("VERSION", "unknown")[:64])
            self.set_INTEGER    (OID_NODE + ".4.0", mode_int)
            self.set_INTEGER    (OID_NODE + ".5.0", 1 if os.path.exists(SENTINEL_PATH) else 0)

            # services(2)
            self.set_INTEGER(OID_SERVICES + ".1.0", svc_state("inferno-aoip.service"))
            self.set_INTEGER(OID_SERVICES + ".2.0", svc_state("statime-inferno.service"))
            self.set_INTEGER(OID_SERVICES + ".3.0", svc_state("cockpit.socket"))
            self.set_INTEGER(OID_SERVICES + ".4.0", svc_state("librespot.service",        is_spotify))
            self.set_INTEGER(OID_SERVICES + ".5.0", svc_state("inferno-iradio.service",   is_iradio))
            self.set_INTEGER(OID_SERVICES + ".6.0", svc_state("bluetooth.service",        is_bluetooth))
            self.set_INTEGER(OID_SERVICES + ".7.0", svc_state("inferno-aux-in.service",   is_aux))
            self.set_INTEGER(OID_SERVICES + ".8.0", svc_state("inferno-aux-out.service",  is_aux))
            self.set_INTEGER(OID_SERVICES + ".9.0", svc_state("cockpit-iot-updater.service"))

            # dante(3)
            self.set_INTEGER(OID_DANTE + ".1.0", dante_state_int())
            self.set_GAUGE32 (OID_DANTE + ".2.0", dante_rx_streams())
            self.set_GAUGE32 (OID_DANTE + ".3.0", dante_tx_streams())
            self.set_INTEGER(OID_DANTE + ".4.0", dante_subscribed_int())
            self.set_GAUGE32 (OID_DANTE + ".5.0", dante_latency_us())

            # ptp(4)
            self.set_INTEGER (OID_PTP + ".1.0", ptp_sync_int())
            self.set_INTEGER (OID_PTP + ".2.0", ptp_offset_ns())
            self.set_INTEGER (OID_PTP + ".3.0", ptp_role_int())
            self.set_OCTETSTRING(OID_PTP + ".4.0", ptp_gm_identity())

            # audio(5)
            self.set_GAUGE32 (OID_AUDIO + ".1.0", audio_input_level())
            self.set_GAUGE32 (OID_AUDIO + ".2.0", audio_output_level())
            self.set_COUNTER32(OID_AUDIO + ".3.0", audio_clip_count())
            self.set_GAUGE32 (OID_AUDIO + ".4.0", audio_sample_rate())
            self.set_INTEGER (OID_AUDIO + ".5.0", audio_loopback_loaded())

            # spotify(6)
            self.set_INTEGER    (OID_SPOTIFY + ".1.0", spotify_state_int() if is_spotify else SVC_NA)
            self.set_OCTETSTRING(OID_SPOTIFY + ".2.0", spotify_track() if is_spotify else "")
            self.set_GAUGE32    (OID_SPOTIFY + ".3.0", spotify_volume() if is_spotify else 0)

            # iradio(7)
            self.set_INTEGER    (OID_IRADIO + ".1.0", iradio_state_int() if is_iradio else SVC_NA)
            self.set_OCTETSTRING(OID_IRADIO + ".2.0", iradio_station() if is_iradio else "")
            self.set_OCTETSTRING(OID_IRADIO + ".3.0", iradio_url() if is_iradio else "")

            # system(8)
            hs = health_state()
            self.set_OCTETSTRING(OID_SYSTEM + ".1.0", str(hs.get("last_check", "never"))[:32])
            self.set_GAUGE32    (OID_SYSTEM + ".2.0", uptime_seconds())
            self.set_INTEGER    (OID_SYSTEM + ".3.0", running_inferno_services())

        except Exception as e:
            log.error("Updater error: %s", e)


# ── Main ──────────────────────────────────────────────────────────────────────

class InfernoAgent(pyagentx.Agent):
    def setup(self):
        self.register(OID_BASE, InfernoUpdater, update_frequency=UPDATE_INTERVAL)


def main():
    log.info("Inferno SNMP AgentX subagent starting (OID base: %s)", OID_BASE)
    deadline = time.time() + 60
    while not os.path.exists(AGENTX_SOCKET):
        if time.time() > deadline:
            log.error("AgentX socket %s not available after 60s", AGENTX_SOCKET)
            sys.exit(1)
        log.info("Waiting for AgentX socket %s ...", AGENTX_SOCKET)
        time.sleep(5)

    pyagentx.setup_logging()
    agent = InfernoAgent()
    try:
        agent.start()
    except KeyboardInterrupt:
        log.info("Shutting down")
        agent.stop()
    except Exception as e:
        log.error("Fatal: %s", e)
        sys.exit(1)


if __name__ == "__main__":
    main()
