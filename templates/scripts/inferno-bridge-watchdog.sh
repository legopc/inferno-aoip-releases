#!/bin/bash
# Watchdog wrapper for inferno-bridge (alsaloop).
# Sends WATCHDOG=1 pings to systemd while alsaloop runs.
# alsaloop does not support sd_notify natively.
systemd-notify --ready
(while true; do
    systemd-notify WATCHDOG=1
    sleep 10
done) &
WATCHDOG_PID=$!
exec /usr/local/bin/Virgil-Appliance "$@"
