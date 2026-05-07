#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)

fail() {
    printf 'FAIL: %s\n' "$1" >&2
    exit 1
}

assert_contains() {
    local file=$1 pattern=$2 message=$3
    grep -Eq -- "$pattern" "$file" || fail "$message"
}

assert_not_contains() {
    local file=$1 pattern=$2 message=$3
    if grep -Eq -- "$pattern" "$file"; then
        fail "$message"
    fi
}

statime_template="${repo_root}/templates/inferno-ptpv1.toml"
configure_script="${repo_root}/build/inferno-configure.sh"
configure_unit="${repo_root}/build/systemd/inferno-configure.service"
containerfile="${repo_root}/Containerfile"

assert_contains \
    "$statime_template" \
    '^[[:space:]]*hardware-clock[[:space:]]*=[[:space:]]*"auto"[[:space:]]*$' \
    'statime template must explicitly use hardware-clock = "auto"'

assert_not_contains \
    "$configure_script" \
    'hardware-clock = \\"/dev/|hardware-clock = "/dev/' \
    'inferno-configure.sh must not write /dev/ptpN as statime hardware-clock'

assert_not_contains \
    <(grep -Ev '^[[:space:]]*#' "$configure_script") \
    'sudo -u core.*systemctl --user enable|systemctl --user enable' \
    'first boot must not enable user services through PAM-backed systemctl --user'

assert_contains \
    "$configure_script" \
    'default\.target\.wants' \
    'first boot should enable core user services by creating default.target.wants symlinks'

assert_not_contains \
    "$configure_script" \
    '/run/user/\$\{CORE_UID\}/systemd|/run/user/1000/systemd' \
    'first boot must not wait on the core user manager before enabling services'

assert_not_contains \
    "$configure_script" \
    'loginctl enable-linger' \
    'first boot must not call logind to enable linger while Cockpit may be handling first login'

assert_contains \
    "$configure_script" \
    '/var/lib/systemd/linger/core' \
    'first boot should enable lingering by writing the linger sentinel directly'

assert_not_contains \
    "$configure_unit" \
    'network-online\.target|Wants=network-online\.target' \
    'inferno-configure.service must not depend on NetworkManager-wait-online'

assert_contains \
    "$containerfile" \
    'bootc-fetch-apply-updates\.service' \
    'Containerfile must mask bootc-fetch-apply-updates.service'

assert_contains \
    "$containerfile" \
    'bootc-fetch-apply-updates\.timer' \
    'Containerfile must mask bootc-fetch-apply-updates.timer'

printf 'All regression checks passed.\n'
