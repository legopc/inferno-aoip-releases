#!/bin/bash
# Watchdog wrapper for librespot.
# Sends WATCHDOG=1 pings to systemd — librespot does not send them natively.
systemd-notify --ready
(while true; do
    systemd-notify WATCHDOG=1
    sleep 20
done) &
exec /usr/local/bin/librespot "$@"
