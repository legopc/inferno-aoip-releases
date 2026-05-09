#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
tmpdir=$(mktemp -d)
trap 'rm -rf "${tmpdir}"' EXIT

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

assert_contains_literal() {
    local file=$1 pattern=$2 message=$3
    grep -Fq -- "$pattern" "$file" || fail "$message"
}

assert_not_contains_literal() {
    local file=$1 pattern=$2 message=$3
    if grep -Fq -- "$pattern" "$file"; then
        fail "$message"
    fi
}

assert_line_count() {
    local file=$1 pattern=$2 expected=$3 message=$4
    local actual
    actual=$(grep -Ec -- "$pattern" "$file" || true)
    [ "${actual}" -eq "${expected}" ] || fail "${message} (expected ${expected}, got ${actual})"
}

statime_template="${repo_root}/templates/inferno-ptpv1.toml"
configure_script="${repo_root}/build/inferno-configure.sh"
configure_unit="${repo_root}/build/systemd/inferno-configure.service"
containerfile="${repo_root}/Containerfile"
ptp_udev_rule="${repo_root}/templates/udev/90-inferno-ptp.rules"
spotify_asound="${repo_root}/templates/alsa/asoundrc.spotify"
aux_asound="${repo_root}/templates/alsa/asoundrc.aux"
upgrade_script="${repo_root}/templates/scripts/inferno-upgrade.sh"
librespot_unit="${repo_root}/templates/systemd/user/librespot.service"

stub_common_upgrade_commands() {
    local bin_dir=$1
    cat > "${bin_dir}/udevadm" <<'EOF_SH'
#!/bin/sh
printf 'udevadm %s\n' "$*" >> "$SHIM_LOG"
EOF_SH
    cat > "${bin_dir}/chown" <<'EOF_SH'
#!/bin/sh
printf 'chown %s\n' "$*" >> "$SHIM_LOG"
EOF_SH
    cat > "${bin_dir}/restorecon" <<'EOF_SH'
#!/bin/sh
printf 'restorecon %s\n' "$*" >> "$SHIM_LOG"
EOF_SH
    chmod +x "${bin_dir}/udevadm" "${bin_dir}/chown" "${bin_dir}/restorecon"
}

assert_contains \
    "$statime_template" \
    '^[[:space:]]*hardware-clock[[:space:]]*=[[:space:]]*"auto"[[:space:]]*$' \
    'statime template must explicitly use hardware-clock = "auto"'

assert_not_contains \
    "$configure_script" \
    'hardware-clock = \\"/dev/|hardware-clock = "/dev/' \
    'inferno-configure.sh must not write /dev/ptpN as statime hardware-clock'

assert_contains \
    "$configure_script" \
    'INFERNO_BIND="\$\{INFERNO_NIC\}"' \
    'inferno-configure.sh must bind Dante services by NIC name, not DHCP timing'

assert_contains \
    "$configure_script" \
    'INFERNO_CLOCK_PATH="/dev/\$\{PTP_DEV\}"' \
    'hardware PTP nodes must configure Inferno CLOCK_PATH to the detected /dev/ptpN device'

assert_contains \
    "$configure_script" \
    '%%INFERNO_BIND%%' \
    'inferno-configure.sh must substitute the Dante bind identity separately from INFERNO_INTERFACE'

assert_contains \
    "$configure_script" \
    '%%INFERNO_CLOCK_PATH%%' \
    'inferno-configure.sh must substitute Inferno CLOCK_PATH into ALSA templates'

assert_not_contains \
    "$spotify_asound" \
    'BIND_IP[[:space:]]+%%INFERNO_INTERFACE%%' \
    'Spotify ALSA template must not use DHCP IP placeholder as Dante bind identity'

assert_not_contains \
    "$aux_asound" \
    'BIND_IP[[:space:]]+%%INFERNO_INTERFACE%%' \
    'AUX ALSA template must not use DHCP IP placeholder as Dante bind identity'

for asound_template in "$spotify_asound" "$aux_asound"; do
    assert_contains \
        "$asound_template" \
        'BIND_IP[[:space:]]+%%INFERNO_BIND%%' \
        "$(basename "$asound_template") must bind Inferno by explicit INFERNO_BIND placeholder"
    assert_contains \
        "$asound_template" \
        'CLOCK_PATH[[:space:]]+%%INFERNO_CLOCK_PATH%%' \
        "$(basename "$asound_template") must use generated Inferno clock path"
done

assert_contains \
    "$upgrade_script" \
    'BIND_IP 0\.0\.0\.0' \
    'inferno-upgrade.sh must repair v36 asoundrc files that contain BIND_IP 0.0.0.0'

assert_contains \
    "$upgrade_script" \
    'CLOCK_PATH /tmp/ptp-usrvclock' \
    'inferno-upgrade.sh must migrate hardware-PTP nodes away from the unusable statime usrvclock socket'

assert_contains \
    "$containerfile" \
    'm core clock|clock:x:[0-9]+:core|clock.*core' \
    'Containerfile must grant core access to /dev/ptpN through the clock group'

[ -f "$ptp_udev_rule" ] || fail 'PTP udev rule file must exist'
assert_contains_literal \
    "$ptp_udev_rule" \
    'KERNEL=="ptp[0-9]*", GROUP="clock", MODE="0660"' \
    'PTP udev rule must grant /dev/ptpN access through the clock group'
assert_not_contains_literal \
    "$ptp_udev_rule" \
    'uaccess' \
    'PTP udev rule must not use seat-local uaccess permissions'
assert_not_contains_literal \
    "$ptp_udev_rule" \
    'MODE="0666"' \
    'PTP udev rule must not make /dev/ptpN world-writable'
assert_contains \
    "$containerfile" \
    '^[[:space:]]*COPY[[:space:]]+templates/udev/90-inferno-ptp\.rules[[:space:]]+/etc/udev/rules\.d/90-inferno-ptp\.rules[[:space:]]*$' \
    'Containerfile must install the PTP udev rule into /etc/udev/rules.d/90-inferno-ptp.rules'

substitute_asound_template() {
    local src=$1 dst=$2
    sed \
        -e 's|%%INFERNO_NAME%%|Inferno-Test|g' \
        -e 's|%%INFERNO_NIC%%|eno1|g' \
        -e 's|%%INFERNO_INTERFACE%%|0.0.0.0|g' \
        -e 's|%%INFERNO_BIND%%|eno1|g' \
        -e 's|%%INFERNO_CLOCK_PATH%%|/dev/ptp0|g' \
        -e 's|%%INFERNO_DEVICE_ID%%|18602424aaa80000|g' \
        -e 's|%%INFERNO_DEVICE_ID_TX%%|18602424aaa80001|g' \
        -e 's|%%INFERNO_DEVICE_ID_RX%%|18602424aaa80002|g' \
        -e 's|%%INFERNO_PLUGIN_PATH%%|/usr/lib64/alsa-lib/libasound_module_pcm_inferno.so|g' \
        -e 's|%%INFERNO_AUDIO_CARD%%|PCH|g' \
        "$src" > "$dst"
}

substitute_asound_template "$spotify_asound" "${tmpdir}/asoundrc.spotify"
substitute_asound_template "$aux_asound" "${tmpdir}/asoundrc.aux"
cat "${tmpdir}/asoundrc.spotify" "${tmpdir}/asoundrc.aux" > "${tmpdir}/asoundrc.generated"

assert_not_contains \
    "${tmpdir}/asoundrc.generated" \
    '^[[:space:]]+BIND_IP[[:space:]]+0\.0\.0\.0$' \
    'generated Spotify/AUX ALSA config must not emit BIND_IP 0.0.0.0 when DHCP is late'

generated_bind_count=$(grep -Ec '^[[:space:]]+BIND_IP[[:space:]]+eno1$' "${tmpdir}/asoundrc.generated")
[ "${generated_bind_count}" -eq 3 ] || fail "generated Spotify/AUX ALSA config must bind all three Inferno PCMs to eno1"

generated_clock_count=$(grep -Ec '^[[:space:]]+CLOCK_PATH[[:space:]]+/dev/ptp0$' "${tmpdir}/asoundrc.generated")
[ "${generated_clock_count}" -eq 3 ] || fail "generated Spotify/AUX ALSA config must use /dev/ptp0 for all three Inferno PCMs"

run_upgrade_fixture() {
    local fixture=$1
    local allow_non_char_ptp=${2:-1}
    local status=0
    mkdir -p \
        "${fixture}/core/.config/systemd/user" \
        "${fixture}/templates" \
        "${fixture}/dev"
    if [ ! -e "${fixture}/no-default-net" ]; then
        mkdir -p "${fixture}/sys/class/net/eno1/device/ptp"
        : > "${fixture}/sys/class/net/eno1/device/ptp/ptp0"
        : > "${fixture}/dev/ptp0"
    fi

    env \
        INFERNO_CONF="${fixture}/inferno.conf" \
        INFERNO_TEMPLATE_DIR="${fixture}/templates" \
        INFERNO_CORE_HOME="${fixture}/core" \
        INFERNO_SYSTEMD_USER="${fixture}/core/.config/systemd/user" \
        INFERNO_SYS_CLASS_NET="${fixture}/sys/class/net" \
        INFERNO_DEV_ROOT="${fixture}/dev" \
        INFERNO_IP_FIXTURE="${fixture}/ip.fixture" \
        INFERNO_ALLOW_NON_CHAR_PTP="${allow_non_char_ptp}" \
        INFERNO_SKIP_OWNERSHIP=1 \
        INFERNO_SKIP_USER_RELOAD=1 \
        bash "${upgrade_script}" > "${fixture}/upgrade.log" 2>&1 || status=$?
    [ "${status}" -eq 0 ] || return "${status}"
    assert_not_contains_literal \
        "${fixture}/upgrade.log" \
        'sudo: unknown user core' \
        'upgrade fixture must not try to reload the host user daemon'
}

upgrade_fixture="${tmpdir}/upgrade-hw-ptp"
mkdir -p "${upgrade_fixture}/core"
cat > "${upgrade_fixture}/inferno.conf" <<'EOF_CONF'
INFERNO_NIC=eno1
INFERNO_BIND=eno1
INFERNO_HW_PTP=yes
EOF_CONF
cat > "${upgrade_fixture}/core/.asoundrc" <<'EOF_ASOUNDRC'
pcm.inferno_spotify {
    type inferno
    BIND_IP 0.0.0.0
    CLOCK_PATH /tmp/ptp-usrvclock
}
EOF_ASOUNDRC
run_upgrade_fixture "${upgrade_fixture}"
assert_not_contains_literal \
    "${upgrade_fixture}/core/.asoundrc" \
    'BIND_IP 0.0.0.0' \
    'inferno-upgrade.sh must rewrite stale BIND_IP 0.0.0.0 in an existing .asoundrc'
assert_contains_literal \
    "${upgrade_fixture}/core/.asoundrc" \
    'BIND_IP eno1' \
    'inferno-upgrade.sh must repair stale .asoundrc bind identity to INFERNO_BIND'
assert_not_contains_literal \
    "${upgrade_fixture}/core/.asoundrc" \
    'CLOCK_PATH /tmp/ptp-usrvclock' \
    'inferno-upgrade.sh must rewrite stale usrvclock paths on hardware-PTP nodes'
assert_contains_literal \
    "${upgrade_fixture}/core/.asoundrc" \
    'CLOCK_PATH /dev/ptp0' \
    'inferno-upgrade.sh must repair stale .asoundrc clock path to detected /dev/ptpN'

ptp_gate_fixture="${tmpdir}/upgrade-ptp-gate"
mkdir -p "${ptp_gate_fixture}/core"
cat > "${ptp_gate_fixture}/inferno.conf" <<'EOF_CONF'
INFERNO_NIC=eno1
INFERNO_BIND=eno1
INFERNO_HW_PTP=yes
EOF_CONF
cat > "${ptp_gate_fixture}/core/.asoundrc" <<'EOF_ASOUNDRC'
pcm.inferno_spotify {
    type inferno
    BIND_IP 0.0.0.0
    CLOCK_PATH /tmp/ptp-usrvclock
}
EOF_ASOUNDRC
run_upgrade_fixture "${ptp_gate_fixture}" 0
assert_contains_literal \
    "${ptp_gate_fixture}/core/.asoundrc" \
    'CLOCK_PATH /tmp/ptp-usrvclock' \
    'inferno-upgrade.sh must not accept non-character fake PTP devices unless test bypass is enabled'
assert_not_contains_literal \
    "${ptp_gate_fixture}/core/.asoundrc" \
    'CLOCK_PATH /dev/ptp0' \
    'inferno-upgrade.sh production path must require /dev/ptpN to be a character device'

escape_fixture="${tmpdir}/upgrade-sed-escaping"
mkdir -p "${escape_fixture}/core" "${escape_fixture}/sys/class/net/eno&1\lab/device/ptp" "${escape_fixture}/dev"
: > "${escape_fixture}/no-default-net"
: > "${escape_fixture}/sys/class/net/eno&1\lab/device/ptp/ptp&0\lab"
: > "${escape_fixture}/dev/ptp&0\lab"
cat > "${escape_fixture}/inferno.conf" <<'EOF_CONF'
INFERNO_NIC='eno&1\lab'
EOF_CONF
cat > "${escape_fixture}/core/.asoundrc" <<'EOF_ASOUNDRC'
pcm.inferno_spotify {
    type inferno
    BIND_IP 0.0.0.0
    CLOCK_PATH /tmp/ptp-usrvclock
}
EOF_ASOUNDRC
run_upgrade_fixture "${escape_fixture}"
assert_contains_literal \
    "${escape_fixture}/core/.asoundrc" \
    'BIND_IP eno&1\lab' \
    'inferno-upgrade.sh must escape ampersands and backslashes when repairing BIND_IP'
assert_contains_literal \
    "${escape_fixture}/core/.asoundrc" \
    'CLOCK_PATH /dev/ptp&0\lab' \
    'inferno-upgrade.sh must escape ampersands and backslashes when repairing CLOCK_PATH'
assert_contains_literal \
    "${escape_fixture}/inferno.conf" \
    "INFERNO_NIC='eno&1\lab'" \
    'inferno-upgrade.sh must write source-safe quoted canonical NIC values'
bash -c "source \"${escape_fixture}/inferno.conf\"; [ \"\${INFERNO_NIC}\" = 'eno&1\lab' ] && [ \"\${INFERNO_BIND}\" = 'eno&1\lab' ] && [ \"\${INFERNO_CLOCK_PATH}\" = '/dev/ptp&0\lab' ]" || \
    fail 'canonical inferno.conf must remain sourceable and preserve exact metacharacter values'

idempotent_fixture="${tmpdir}/upgrade-asound-idempotent"
mkdir -p "${idempotent_fixture}/core" "${idempotent_fixture}/sys/class/net/enp0s31f6" "${idempotent_fixture}/dev"
: > "${idempotent_fixture}/no-default-net"
cat > "${idempotent_fixture}/ip.fixture" <<'EOF_IP'
enp0s31f6 172.16.10.63 default
EOF_IP
cat > "${idempotent_fixture}/inferno.conf" <<'EOF_CONF'
INFERNO_NIC='enp0s31f6'
INFERNO_INTERFACE='172.16.10.63'
INFERNO_BIND='enp0s31f6'
INFERNO_HW_PTP='no'
INFERNO_CLOCK_PATH='/tmp/ptp-usrvclock'
EOF_CONF
cat > "${idempotent_fixture}/core/.asoundrc" <<'EOF_ASOUNDRC'
pcm.inferno_spotify {
    type inferno
    BIND_IP enp0s31f6
    CLOCK_PATH /tmp/ptp-usrvclock
}
EOF_ASOUNDRC
run_upgrade_fixture "${idempotent_fixture}"
assert_contains_literal "${idempotent_fixture}/upgrade.log" 'inferno-upgrade: all service files up to date' 'upgrade must not mark unchanged .asoundrc as changed'

stale_ip_fixture="${tmpdir}/upgrade-stale-ip-bind"
mkdir -p "${stale_ip_fixture}/core" "${stale_ip_fixture}/sys/class/net/enp0s31f6/device/ptp" "${stale_ip_fixture}/dev"
: > "${stale_ip_fixture}/no-default-net"
: > "${stale_ip_fixture}/sys/class/net/enp0s31f6/device/ptp/ptp0"
: > "${stale_ip_fixture}/dev/ptp0"
# Fixture format: NIC IPv4 DEFAULT, where DEFAULT may be the literal word default.
cat > "${stale_ip_fixture}/ip.fixture" <<'EOF_IP'
enp0s31f6 172.16.10.63 default
EOF_IP
cat > "${stale_ip_fixture}/inferno.conf" <<'EOF_CONF'
INFERNO_NIC=enp0s31f6
INFERNO_INTERFACE=192.168.1.45
INFERNO_HW_PTP=yes
EOF_CONF
cat > "${stale_ip_fixture}/core/.asoundrc" <<'EOF_ASOUNDRC'
pcm.inferno_spotify {
    type inferno
    slave {
        pcm "hw:0"
    }
    BIND_IP 192.168.1.45
    CLOCK_PATH /dev/ptp0
}
pcm.custom_monitor {
    type inferno
    BIND_IP 192.168.1.45
    CLOCK_PATH /tmp/custom-clock
}
EOF_ASOUNDRC
run_upgrade_fixture "${stale_ip_fixture}"
assert_contains_literal "${stale_ip_fixture}/inferno.conf" "INFERNO_BIND='enp0s31f6'" 'upgrade must canonicalize INFERNO_BIND to selected NIC name'
assert_contains_literal "${stale_ip_fixture}/inferno.conf" "INFERNO_INTERFACE='172.16.10.63'" 'upgrade must recompute informational INFERNO_INTERFACE from current IPv4'
assert_contains_literal "${stale_ip_fixture}/inferno.conf" "INFERNO_HW_PTP='yes'" 'upgrade must preserve hardware PTP when selected NIC has a usable /dev/ptpN'
assert_contains_literal "${stale_ip_fixture}/inferno.conf" "INFERNO_CLOCK_PATH='/dev/ptp0'" 'upgrade must store the selected NIC hardware PTP clock path'
assert_contains_literal "${stale_ip_fixture}/core/.asoundrc" 'BIND_IP enp0s31f6' 'upgrade must repair stale nonzero IP BIND_IP to selected NIC name'
assert_contains_literal "${stale_ip_fixture}/core/.asoundrc" 'BIND_IP 192.168.1.45' 'upgrade must not repair unrelated ALSA BIND_IP lines outside Inferno-managed PCM blocks'

canonical_export_fixture="${tmpdir}/upgrade-canonical-export-keys"
mkdir -p "${canonical_export_fixture}/core" "${canonical_export_fixture}/sys/class/net/enp0s31f6/device/ptp" "${canonical_export_fixture}/dev"
: > "${canonical_export_fixture}/no-default-net"
: > "${canonical_export_fixture}/sys/class/net/enp0s31f6/device/ptp/ptp0"
: > "${canonical_export_fixture}/dev/ptp0"
cat > "${canonical_export_fixture}/ip.fixture" <<'EOF_IP'
enp0s31f6 172.16.10.63 default
EOF_IP
cat > "${canonical_export_fixture}/inferno.conf" <<'EOF_CONF'
# preserved managed-key comment
  INFERNO_NIC=old0
export INFERNO_INTERFACE=192.168.1.45
 export INFERNO_BIND=old0
	INFERNO_HW_PTP=no
export INFERNO_CLOCK_PATH=/tmp/ptp-usrvclock
INFERNO_EXTRA=keep-me
EOF_CONF
run_upgrade_fixture "${canonical_export_fixture}"
for managed_key in INFERNO_NIC INFERNO_INTERFACE INFERNO_BIND INFERNO_HW_PTP INFERNO_CLOCK_PATH; do
    managed_count=$(grep -Ec "^[[:space:]]*(export[[:space:]]+)?${managed_key}=" "${canonical_export_fixture}/inferno.conf")
    [ "${managed_count}" -eq 1 ] || fail "upgrade must leave exactly one canonical ${managed_key} entry"
done
assert_contains_literal "${canonical_export_fixture}/inferno.conf" '# preserved managed-key comment' 'upgrade must preserve comments while canonicalizing inferno.conf'
assert_contains_literal "${canonical_export_fixture}/inferno.conf" 'INFERNO_EXTRA=keep-me' 'upgrade must preserve unknown inferno.conf keys while canonicalizing managed keys'
assert_not_contains "${canonical_export_fixture}/inferno.conf" '^[[:space:]]+INFERNO_NIC=|^[[:space:]]*export[[:space:]]+INFERNO_' 'upgrade must strip legacy indented and exported managed keys'

no_hw_ptp_fixture="${tmpdir}/upgrade-no-hw-ptp"
mkdir -p "${no_hw_ptp_fixture}/core" "${no_hw_ptp_fixture}/sys/class/net/enp0s31f6" "${no_hw_ptp_fixture}/dev"
: > "${no_hw_ptp_fixture}/no-default-net"
cat > "${no_hw_ptp_fixture}/ip.fixture" <<'EOF_IP'
enp0s31f6 172.16.10.63 default
EOF_IP
cat > "${no_hw_ptp_fixture}/inferno.conf" <<'EOF_CONF'
INFERNO_NIC=enp0s31f6
INFERNO_BIND=enp0s31f6
INFERNO_HW_PTP=yes
INFERNO_CLOCK_PATH=/dev/ptp0
EOF_CONF
cat > "${no_hw_ptp_fixture}/core/.asoundrc" <<'EOF_ASOUNDRC'
pcm.inferno_spotify {
    type inferno
    BIND_IP enp0s31f6
    CLOCK_PATH /dev/ptp0
}
EOF_ASOUNDRC
run_upgrade_fixture "${no_hw_ptp_fixture}"
assert_contains_literal "${no_hw_ptp_fixture}/inferno.conf" "INFERNO_HW_PTP='no'" 'upgrade must recalculate stale hardware PTP state from the selected NIC'
assert_contains_literal "${no_hw_ptp_fixture}/inferno.conf" "INFERNO_CLOCK_PATH='/tmp/ptp-usrvclock'" 'upgrade must fall back to usrvclock when selected NIC has no usable /dev/ptpN'
assert_contains_literal "${no_hw_ptp_fixture}/core/.asoundrc" 'CLOCK_PATH /tmp/ptp-usrvclock' 'upgrade must repair .asoundrc clock path when hardware PTP disappears'

default_route_fixture="${tmpdir}/upgrade-missing-nic-default-route"
mkdir -p "${default_route_fixture}/core" "${default_route_fixture}/sys/class/net/enp0s31f6" "${default_route_fixture}/dev"
: > "${default_route_fixture}/no-default-net"
cat > "${default_route_fixture}/ip.fixture" <<'EOF_IP'
enp0s31f6 172.16.10.63 default
EOF_IP
cat > "${default_route_fixture}/inferno.conf" <<'EOF_CONF'
INFERNO_NIC=eno1
INFERNO_BIND=eno1
INFERNO_INTERFACE=192.168.1.45
EOF_CONF
cat > "${default_route_fixture}/core/.asoundrc" <<'EOF_ASOUNDRC'
pcm.inferno_spotify {
    type inferno
    BIND_IP eno1
    CLOCK_PATH /tmp/ptp-usrvclock
}
EOF_ASOUNDRC
run_upgrade_fixture "${default_route_fixture}"
assert_contains_literal "${default_route_fixture}/inferno.conf" "INFERNO_NIC='enp0s31f6'" 'upgrade must choose the default-route NIC when the saved NIC is missing'
assert_contains_literal "${default_route_fixture}/inferno.conf" "INFERNO_BIND='enp0s31f6'" 'upgrade bind identity must follow fallback selected NIC'

ambiguous_fixture="${tmpdir}/upgrade-ambiguous-nic"
mkdir -p "${ambiguous_fixture}/core" "${ambiguous_fixture}/sys/class/net/enp0s31f6" "${ambiguous_fixture}/sys/class/net/enp2s0" "${ambiguous_fixture}/dev"
: > "${ambiguous_fixture}/no-default-net"
cat > "${ambiguous_fixture}/ip.fixture" <<'EOF_IP'
enp0s31f6 172.16.10.63
enp2s0 172.16.20.63
EOF_IP
cat > "${ambiguous_fixture}/inferno.conf" <<'EOF_CONF'
INFERNO_NIC=eno1
INFERNO_BIND=eno1
INFERNO_INTERFACE=192.168.1.45
EOF_CONF
before_ambiguous_conf=$(cat "${ambiguous_fixture}/inferno.conf")
if run_upgrade_fixture "${ambiguous_fixture}"; then
    fail 'upgrade must fail loudly when the saved NIC is missing and fallback NIC selection is ambiguous'
fi
after_ambiguous_conf=$(cat "${ambiguous_fixture}/inferno.conf")
[ "${before_ambiguous_conf}" = "${after_ambiguous_conf}" ] || fail 'ambiguous NIC failure must leave inferno.conf untouched'
assert_contains_literal "${ambiguous_fixture}/upgrade.log" 'ambiguous' 'ambiguous NIC failure must log a loud diagnostic'

dhcp_late_fixture="${tmpdir}/upgrade-dhcp-late"
mkdir -p "${dhcp_late_fixture}/core" "${dhcp_late_fixture}/sys/class/net/enp0s31f6" "${dhcp_late_fixture}/dev"
: > "${dhcp_late_fixture}/no-default-net"
cat > "${dhcp_late_fixture}/ip.fixture" <<'EOF_IP'
enp0s31f6 - default
EOF_IP
cat > "${dhcp_late_fixture}/inferno.conf" <<'EOF_CONF'
INFERNO_NIC=enp0s31f6
INFERNO_BIND=enp0s31f6
INFERNO_INTERFACE=192.168.1.45
EOF_CONF
cat > "${dhcp_late_fixture}/core/.asoundrc" <<'EOF_ASOUNDRC'
pcm.inferno_spotify {
    type inferno
    BIND_IP enp0s31f6
    CLOCK_PATH /tmp/ptp-usrvclock
}
EOF_ASOUNDRC
run_upgrade_fixture "${dhcp_late_fixture}"
assert_contains_literal "${dhcp_late_fixture}/inferno.conf" "INFERNO_INTERFACE='192.168.1.45'" 'upgrade must preserve prior non-empty INFERNO_INTERFACE when DHCP has no current IPv4'
assert_not_contains_literal "${dhcp_late_fixture}/inferno.conf" "INFERNO_INTERFACE='0.0.0.0'" 'upgrade must not write 0.0.0.0 when DHCP is not ready'
assert_contains_literal "${dhcp_late_fixture}/upgrade.log" 'WARNING: no current IPv4 for enp0s31f6; preserving INFERNO_INTERFACE=192.168.1.45' 'upgrade must warn when preserving prior INFERNO_INTERFACE because DHCP is not ready'

ownership_fixture="${tmpdir}/upgrade-ptp-ownership"
ownership_bin="${ownership_fixture}/bin"
mkdir -p "${ownership_fixture}/core/.config/systemd/user" "${ownership_fixture}/sys/class/net/enp0s31f6" "${ownership_fixture}/dev" "${ownership_bin}" "${ownership_fixture}/etc"
: > "${ownership_fixture}/no-default-net"
cat > "${ownership_fixture}/etc/group" <<'EOF_GROUP'
root:x:0:
core:x:1000:
audio:x:63:core
EOF_GROUP
cat > "${ownership_fixture}/ip.fixture" <<'EOF_IP'
enp0s31f6 172.16.10.63 default
EOF_IP
cat > "${ownership_fixture}/inferno.conf" <<'EOF_CONF'
INFERNO_NIC='enp0s31f6'
INFERNO_INTERFACE='172.16.10.63'
INFERNO_BIND='enp0s31f6'
INFERNO_HW_PTP='no'
INFERNO_CLOCK_PATH='/tmp/ptp-usrvclock'
EOF_CONF
cat > "${ownership_bin}/getent" <<'EOF_SH'
#!/bin/sh
printf 'getent %s\n' "$*" >> "$SHIM_LOG"
if [ "$1" = "group" ] && [ "$2" = "clock" ] && [ -f "$SHIM_GROUP_STATE" ]; then
    printf 'clock:x:103:\n'
    exit 0
fi
exit 2
EOF_SH
cat > "${ownership_bin}/groupadd" <<'EOF_SH'
#!/bin/sh
printf 'groupadd %s\n' "$*" >> "$SHIM_LOG"
[ "$1" = "-r" ] && [ "$2" = "clock" ] || exit 1
: > "$SHIM_GROUP_STATE"
EOF_SH
cat > "${ownership_bin}/usermod" <<'EOF_SH'
#!/bin/sh
printf 'usermod %s\n' "$*" >> "$SHIM_LOG"
[ "$1" = "-aG" ] && [ "$2" = "clock" ] && [ "$3" = "core" ]
EOF_SH
stub_common_upgrade_commands "${ownership_bin}"
chmod +x "${ownership_bin}/getent" "${ownership_bin}/groupadd" "${ownership_bin}/usermod"
status=0
env \
    PATH="${ownership_bin}:$PATH" \
    SHIM_LOG="${ownership_fixture}/shim.log" \
    SHIM_GROUP_STATE="${ownership_fixture}/clock.group" \
    INFERNO_CONF="${ownership_fixture}/inferno.conf" \
    INFERNO_TEMPLATE_DIR="${ownership_fixture}/templates" \
    INFERNO_CORE_HOME="${ownership_fixture}/core" \
    INFERNO_SYSTEMD_USER="${ownership_fixture}/core/.config/systemd/user" \
    INFERNO_SYS_CLASS_NET="${ownership_fixture}/sys/class/net" \
    INFERNO_DEV_ROOT="${ownership_fixture}/dev" \
    INFERNO_IP_FIXTURE="${ownership_fixture}/ip.fixture" \
    INFERNO_ETC_GROUP="${ownership_fixture}/etc/group" \
    INFERNO_SKIP_USER_RELOAD=1 \
    bash "${upgrade_script}" > "${ownership_fixture}/upgrade.log" 2>&1 || status=$?
[ "${status}" -eq 0 ] || fail 'upgrade must complete when ownership refresh shims succeed'
assert_contains_literal "${ownership_fixture}/shim.log" 'getent group clock' 'upgrade ownership path must verify the clock group exists'
assert_contains_literal "${ownership_fixture}/shim.log" 'groupadd -r clock' 'upgrade ownership path must create the clock group when missing'
assert_contains_literal "${ownership_fixture}/shim.log" 'usermod -aG clock core' 'upgrade ownership path must add core to the clock group'
assert_contains_literal "${ownership_fixture}/shim.log" 'udevadm control --reload' 'upgrade ownership path must reload udev rules after installing PTP permissions'
assert_contains_literal "${ownership_fixture}/shim.log" 'udevadm trigger --subsystem-match=ptp --action=add' 'upgrade ownership path must retrigger PTP udev add events'

ownership_fail_fixture="${tmpdir}/upgrade-ptp-ownership-usermod-fails"
ownership_fail_bin="${ownership_fail_fixture}/bin"
mkdir -p "${ownership_fail_fixture}/core/.config/systemd/user" "${ownership_fail_fixture}/sys/class/net/enp0s31f6" "${ownership_fail_fixture}/dev" "${ownership_fail_bin}" "${ownership_fail_fixture}/etc"
: > "${ownership_fail_fixture}/no-default-net"
: > "${ownership_fail_fixture}/clock.group"
cat > "${ownership_fail_fixture}/etc/group" <<'EOF_GROUP'
root:x:0:
core:x:1000:
audio:x:63:core
EOF_GROUP
cat > "${ownership_fail_fixture}/ip.fixture" <<'EOF_IP'
enp0s31f6 172.16.10.63 default
EOF_IP
cat > "${ownership_fail_fixture}/inferno.conf" <<'EOF_CONF'
INFERNO_NIC='enp0s31f6'
INFERNO_INTERFACE='172.16.10.63'
INFERNO_BIND='enp0s31f6'
INFERNO_HW_PTP='no'
INFERNO_CLOCK_PATH='/tmp/ptp-usrvclock'
EOF_CONF
cat > "${ownership_fail_bin}/getent" <<'EOF_SH'
#!/bin/sh
printf 'getent %s\n' "$*" >> "$SHIM_LOG"
if [ "$1" = "group" ] && [ "$2" = "clock" ] && [ -f "$SHIM_GROUP_STATE" ]; then
    printf 'clock:x:103:\n'
    exit 0
fi
exit 2
EOF_SH
cat > "${ownership_fail_bin}/groupadd" <<'EOF_SH'
#!/bin/sh
printf 'groupadd %s\n' "$*" >> "$SHIM_LOG"
exit 1
EOF_SH
cat > "${ownership_fail_bin}/usermod" <<'EOF_SH'
#!/bin/sh
printf 'usermod %s\n' "$*" >> "$SHIM_LOG"
exit 42
EOF_SH
stub_common_upgrade_commands "${ownership_fail_bin}"
chmod +x "${ownership_fail_bin}/getent" "${ownership_fail_bin}/groupadd" "${ownership_fail_bin}/usermod"
status=0
env \
    PATH="${ownership_fail_bin}:$PATH" \
    SHIM_LOG="${ownership_fail_fixture}/shim.log" \
    SHIM_GROUP_STATE="${ownership_fail_fixture}/clock.group" \
    INFERNO_CONF="${ownership_fail_fixture}/inferno.conf" \
    INFERNO_TEMPLATE_DIR="${ownership_fail_fixture}/templates" \
    INFERNO_CORE_HOME="${ownership_fail_fixture}/core" \
    INFERNO_SYSTEMD_USER="${ownership_fail_fixture}/core/.config/systemd/user" \
    INFERNO_SYS_CLASS_NET="${ownership_fail_fixture}/sys/class/net" \
    INFERNO_DEV_ROOT="${ownership_fail_fixture}/dev" \
    INFERNO_IP_FIXTURE="${ownership_fail_fixture}/ip.fixture" \
    INFERNO_ETC_GROUP="${ownership_fail_fixture}/etc/group" \
    INFERNO_SKIP_USER_RELOAD=1 \
    bash "${upgrade_script}" > "${ownership_fail_fixture}/upgrade.log" 2>&1 || status=$?
[ "${status}" -eq 42 ] || fail "upgrade must exit with usermod failure status 42 when core cannot be added to the clock group (got ${status})"
assert_contains_literal "${ownership_fail_fixture}/shim.log" 'usermod -aG clock core' 'failing ownership fixture must exercise core clock-group membership refresh'
assert_not_contains_literal "${ownership_fail_fixture}/shim.log" 'udevadm control --reload' 'upgrade must not reload udev rules after usermod fails'
assert_not_contains_literal "${ownership_fail_fixture}/shim.log" 'udevadm trigger --subsystem-match=ptp --action=add' 'upgrade must not retrigger PTP udev events after usermod fails'

missing_group_fixture="${tmpdir}/upgrade-ptp-missing-active-group-file"
missing_group_bin="${missing_group_fixture}/bin"
mkdir -p "${missing_group_fixture}/core/.config/systemd/user" "${missing_group_fixture}/sys/class/net/enp0s31f6" "${missing_group_fixture}/dev" "${missing_group_bin}" "${missing_group_fixture}/etc"
: > "${missing_group_fixture}/clock.group"
: > "${missing_group_fixture}/no-default-net"
cat > "${missing_group_fixture}/ip.fixture" <<'EOF_IP'
enp0s31f6 172.16.10.63 default
EOF_IP
cat > "${missing_group_fixture}/inferno.conf" <<'EOF_CONF'
INFERNO_NIC='enp0s31f6'
INFERNO_INTERFACE='172.16.10.63'
INFERNO_BIND='enp0s31f6'
INFERNO_HW_PTP='no'
INFERNO_CLOCK_PATH='/tmp/ptp-usrvclock'
EOF_CONF
cat > "${missing_group_bin}/getent" <<'EOF_SH'
#!/bin/sh
printf 'getent %s\n' "$*" >> "$SHIM_LOG"
if [ "$1" = "group" ] && [ "$2" = "clock" ] && [ -f "$SHIM_GROUP_STATE" ]; then
    printf 'clock:x:103:\n'
    exit 0
fi
exit 2
EOF_SH
cat > "${missing_group_bin}/groupadd" <<'EOF_SH'
#!/bin/sh
printf 'groupadd %s\n' "$*" >> "$SHIM_LOG"
exit 1
EOF_SH
cat > "${missing_group_bin}/usermod" <<'EOF_SH'
#!/bin/sh
printf 'usermod %s\n' "$*" >> "$SHIM_LOG"
[ "$1" = "-aG" ] && [ "$2" = "clock" ] && [ "$3" = "core" ]
EOF_SH
stub_common_upgrade_commands "${missing_group_bin}"
chmod +x "${missing_group_bin}/getent" "${missing_group_bin}/groupadd" "${missing_group_bin}/usermod"
status=0
env \
    PATH="${missing_group_bin}:$PATH" \
    SHIM_LOG="${missing_group_fixture}/shim.log" \
    SHIM_GROUP_STATE="${missing_group_fixture}/clock.group" \
    INFERNO_CONF="${missing_group_fixture}/inferno.conf" \
    INFERNO_TEMPLATE_DIR="${missing_group_fixture}/templates" \
    INFERNO_CORE_HOME="${missing_group_fixture}/core" \
    INFERNO_SYSTEMD_USER="${missing_group_fixture}/core/.config/systemd/user" \
    INFERNO_SYS_CLASS_NET="${missing_group_fixture}/sys/class/net" \
    INFERNO_DEV_ROOT="${missing_group_fixture}/dev" \
    INFERNO_IP_FIXTURE="${missing_group_fixture}/ip.fixture" \
    INFERNO_ETC_GROUP="${missing_group_fixture}/etc/group" \
    INFERNO_SKIP_USER_RELOAD=1 \
    bash "${upgrade_script}" > "${missing_group_fixture}/upgrade.log" 2>&1 || status=$?
[ "${status}" -ne 0 ] || fail 'upgrade must fail rather than synthesize a one-line active /etc/group file'
assert_contains_literal "${missing_group_fixture}/upgrade.log" "active group file '${missing_group_fixture}/etc/group' is missing" 'upgrade must log a clear error when the active group file is missing'
assert_not_contains_literal "${missing_group_fixture}/shim.log" 'udevadm control --reload' 'upgrade must not reload udev rules after active group file repair fails'

split_group_fixture="${tmpdir}/upgrade-ptp-active-group-split"
split_group_bin="${split_group_fixture}/bin"
mkdir -p "${split_group_fixture}/core/.config/systemd/user" "${split_group_fixture}/sys/class/net/enp0s31f6" "${split_group_fixture}/dev" "${split_group_bin}" "${split_group_fixture}/etc"
: > "${split_group_fixture}/clock.group"
: > "${split_group_fixture}/no-default-net"
cat > "${split_group_fixture}/ip.fixture" <<'EOF_IP'
enp0s31f6 172.16.10.63 default
EOF_IP
cat > "${split_group_fixture}/inferno.conf" <<'EOF_CONF'
INFERNO_NIC='enp0s31f6'
INFERNO_INTERFACE='172.16.10.63'
INFERNO_BIND='enp0s31f6'
INFERNO_HW_PTP='no'
INFERNO_CLOCK_PATH='/tmp/ptp-usrvclock'
EOF_CONF
cat > "${split_group_fixture}/etc/group" <<'EOF_GROUP'
root:x:0:
core:x:1000:
audio:x:63:core
EOF_GROUP
cat > "${split_group_bin}/getent" <<'EOF_SH'
#!/bin/sh
printf 'getent %s\n' "$*" >> "$SHIM_LOG"
if [ "$1" = "group" ] && [ "$2" = "clock" ] && [ -f "$SHIM_GROUP_STATE" ]; then
    printf 'clock:x:103:\n'
    exit 0
fi
exit 2
EOF_SH
cat > "${split_group_bin}/groupadd" <<'EOF_SH'
#!/bin/sh
printf 'groupadd %s\n' "$*" >> "$SHIM_LOG"
exit 1
EOF_SH
cat > "${split_group_bin}/usermod" <<'EOF_SH'
#!/bin/sh
printf 'usermod %s\n' "$*" >> "$SHIM_LOG"
[ "$1" = "-aG" ] && [ "$2" = "clock" ] && [ "$3" = "core" ]
EOF_SH
stub_common_upgrade_commands "${split_group_bin}"
chmod +x "${split_group_bin}/getent" "${split_group_bin}/groupadd" "${split_group_bin}/usermod"
status=0
env \
    PATH="${split_group_bin}:$PATH" \
    SHIM_LOG="${split_group_fixture}/shim.log" \
    SHIM_GROUP_STATE="${split_group_fixture}/clock.group" \
    INFERNO_CONF="${split_group_fixture}/inferno.conf" \
    INFERNO_TEMPLATE_DIR="${split_group_fixture}/templates" \
    INFERNO_CORE_HOME="${split_group_fixture}/core" \
    INFERNO_SYSTEMD_USER="${split_group_fixture}/core/.config/systemd/user" \
    INFERNO_SYS_CLASS_NET="${split_group_fixture}/sys/class/net" \
    INFERNO_DEV_ROOT="${split_group_fixture}/dev" \
    INFERNO_IP_FIXTURE="${split_group_fixture}/ip.fixture" \
    INFERNO_ETC_GROUP="${split_group_fixture}/etc/group" \
    INFERNO_SKIP_USER_RELOAD=1 \
    bash "${upgrade_script}" > "${split_group_fixture}/upgrade.log" 2>&1 || status=$?
[ "${status}" -eq 0 ] || fail "upgrade must repair active /etc/group split when usermod succeeds but NSS-backed clock membership is not active (got ${status})"
assert_contains_literal "${split_group_fixture}/etc/group" 'clock:x:103:core' 'upgrade must write the active /etc/group clock entry for bootc upgraded nodes'
assert_contains_literal "${split_group_fixture}/shim.log" 'usermod -aG clock core' 'active group split fixture must still exercise usermod path'

append_group_fixture="${tmpdir}/upgrade-ptp-active-group-append-core"
append_group_bin="${append_group_fixture}/bin"
mkdir -p "${append_group_fixture}/core/.config/systemd/user" "${append_group_fixture}/sys/class/net/enp0s31f6" "${append_group_fixture}/dev" "${append_group_bin}" "${append_group_fixture}/etc"
: > "${append_group_fixture}/clock.group"
: > "${append_group_fixture}/no-default-net"
cat > "${append_group_fixture}/ip.fixture" <<'EOF_IP'
enp0s31f6 172.16.10.63 default
EOF_IP
cat > "${append_group_fixture}/inferno.conf" <<'EOF_CONF'
INFERNO_NIC='enp0s31f6'
INFERNO_INTERFACE='172.16.10.63'
INFERNO_BIND='enp0s31f6'
INFERNO_HW_PTP='no'
INFERNO_CLOCK_PATH='/tmp/ptp-usrvclock'
EOF_CONF
cat > "${append_group_fixture}/etc/group" <<'EOF_GROUP'
root:x:0:
core:x:1000:
clock:x:103:alice,bob
audio:x:63:core
EOF_GROUP
cat > "${append_group_bin}/getent" <<'EOF_SH'
#!/bin/sh
printf 'getent %s\n' "$*" >> "$SHIM_LOG"
if [ "$1" = "group" ] && [ "$2" = "clock" ] && [ -f "$SHIM_GROUP_STATE" ]; then
    printf 'clock:x:103:alice,bob\n'
    exit 0
fi
exit 2
EOF_SH
cat > "${append_group_bin}/groupadd" <<'EOF_SH'
#!/bin/sh
printf 'groupadd %s\n' "$*" >> "$SHIM_LOG"
exit 1
EOF_SH
cat > "${append_group_bin}/usermod" <<'EOF_SH'
#!/bin/sh
printf 'usermod %s\n' "$*" >> "$SHIM_LOG"
[ "$1" = "-aG" ] && [ "$2" = "clock" ] && [ "$3" = "core" ]
EOF_SH
stub_common_upgrade_commands "${append_group_bin}"
chmod +x "${append_group_bin}/getent" "${append_group_bin}/groupadd" "${append_group_bin}/usermod"
status=0
env \
    PATH="${append_group_bin}:$PATH" \
    SHIM_LOG="${append_group_fixture}/shim.log" \
    SHIM_GROUP_STATE="${append_group_fixture}/clock.group" \
    INFERNO_CONF="${append_group_fixture}/inferno.conf" \
    INFERNO_TEMPLATE_DIR="${append_group_fixture}/templates" \
    INFERNO_CORE_HOME="${append_group_fixture}/core" \
    INFERNO_SYSTEMD_USER="${append_group_fixture}/core/.config/systemd/user" \
    INFERNO_SYS_CLASS_NET="${append_group_fixture}/sys/class/net" \
    INFERNO_DEV_ROOT="${append_group_fixture}/dev" \
    INFERNO_IP_FIXTURE="${append_group_fixture}/ip.fixture" \
    INFERNO_ETC_GROUP="${append_group_fixture}/etc/group" \
    INFERNO_SKIP_USER_RELOAD=1 \
    bash "${upgrade_script}" > "${append_group_fixture}/upgrade.log" 2>&1 || status=$?
[ "${status}" -eq 0 ] || fail "upgrade must append core to existing clock members (got ${status})"
assert_line_count "${append_group_fixture}/etc/group" '^clock:x:103:alice,bob,core$' 1 'upgrade must append core exactly once while preserving existing clock members'

preserve_group_fixture="${tmpdir}/upgrade-ptp-active-group-preserve"
preserve_group_bin="${preserve_group_fixture}/bin"
mkdir -p "${preserve_group_fixture}/core/.config/systemd/user" "${preserve_group_fixture}/sys/class/net/enp0s31f6" "${preserve_group_fixture}/dev" "${preserve_group_bin}" "${preserve_group_fixture}/etc"
: > "${preserve_group_fixture}/clock.group"
: > "${preserve_group_fixture}/no-default-net"
cat > "${preserve_group_fixture}/ip.fixture" <<'EOF_IP'
enp0s31f6 172.16.10.63 default
EOF_IP
cat > "${preserve_group_fixture}/inferno.conf" <<'EOF_CONF'
INFERNO_NIC='enp0s31f6'
INFERNO_INTERFACE='172.16.10.63'
INFERNO_BIND='enp0s31f6'
INFERNO_HW_PTP='no'
INFERNO_CLOCK_PATH='/tmp/ptp-usrvclock'
EOF_CONF
cat > "${preserve_group_fixture}/etc/group" <<'EOF_GROUP'
root:x:0:
core:x:1000:
clock:x:103:alice,bob,core
audio:x:63:core
EOF_GROUP
cat > "${preserve_group_bin}/getent" <<'EOF_SH'
#!/bin/sh
printf 'getent %s\n' "$*" >> "$SHIM_LOG"
if [ "$1" = "group" ] && [ "$2" = "clock" ] && [ -f "$SHIM_GROUP_STATE" ]; then
    printf 'clock:x:103:alice,bob,core\n'
    exit 0
fi
exit 2
EOF_SH
cat > "${preserve_group_bin}/groupadd" <<'EOF_SH'
#!/bin/sh
printf 'groupadd %s\n' "$*" >> "$SHIM_LOG"
exit 1
EOF_SH
cat > "${preserve_group_bin}/usermod" <<'EOF_SH'
#!/bin/sh
printf 'usermod %s\n' "$*" >> "$SHIM_LOG"
[ "$1" = "-aG" ] && [ "$2" = "clock" ] && [ "$3" = "core" ]
EOF_SH
stub_common_upgrade_commands "${preserve_group_bin}"
chmod +x "${preserve_group_bin}/getent" "${preserve_group_bin}/groupadd" "${preserve_group_bin}/usermod"
status=0
env \
    PATH="${preserve_group_bin}:$PATH" \
    SHIM_LOG="${preserve_group_fixture}/shim.log" \
    SHIM_GROUP_STATE="${preserve_group_fixture}/clock.group" \
    INFERNO_CONF="${preserve_group_fixture}/inferno.conf" \
    INFERNO_TEMPLATE_DIR="${preserve_group_fixture}/templates" \
    INFERNO_CORE_HOME="${preserve_group_fixture}/core" \
    INFERNO_SYSTEMD_USER="${preserve_group_fixture}/core/.config/systemd/user" \
    INFERNO_SYS_CLASS_NET="${preserve_group_fixture}/sys/class/net" \
    INFERNO_DEV_ROOT="${preserve_group_fixture}/dev" \
    INFERNO_IP_FIXTURE="${preserve_group_fixture}/ip.fixture" \
    INFERNO_ETC_GROUP="${preserve_group_fixture}/etc/group" \
    INFERNO_SKIP_USER_RELOAD=1 \
    bash "${upgrade_script}" > "${preserve_group_fixture}/upgrade.log" 2>&1 || status=$?
[ "${status}" -eq 0 ] || fail "upgrade must preserve existing clock members while ensuring core membership (got ${status})"
assert_line_count "${preserve_group_fixture}/etc/group" '^clock:x:103:alice,bob,core$' 1 'upgrade must preserve existing clock members and avoid duplicate core entries'

REPO_ROOT="$repo_root" node <<'NODE'
const fs = require("fs");

(async () => {
  const repoRoot = process.env.REPO_ROOT;
  const source = fs.readFileSync(`${repoRoot}/src/inferno.js`, "utf8");
  const start = source.indexOf("function deriveDeviceId");
  const endAnchor = "async function saveConfig";
  const end = source.indexOf(endAnchor);
  if (start < 0 || end < 0 || end <= start) {
    throw new Error("could not extract ALSA generation functions from src/inferno.js");
  }

  const files = Object.create(null);
  const ASOUNDRC = "/var/home/core/.asoundrc";
  const cockpit = {
    file(path) {
      return {
        read() { return Promise.resolve(files[path]); },
        replace(value) { files[path] = value; return Promise.resolve(); },
      };
    },
  };
  const USER_HOME = "/var/home/core";
  async function spUser() {}
  let currentConf = {
    INFERNO_NIC: "enp0s31f6",
    INFERNO_INTERFACE: "172.16.10.63",
    INFERNO_BIND: "enp0s31f6",
    INFERNO_CLOCK_PATH: "/dev/ptp0",
    INFERNO_DEVICE_ID: "18602424bbbb0000",
    INFERNO_PLUGIN_PATH: "/opt/inferno/lib/libasound_module_pcm_inferno.so",
  };

  eval(source.slice(start, end));

  files[ASOUNDRC] = `pcm_type.inferno {
    lib "/stale/generated/libasound_module_pcm_inferno.so"
}

pcm.inferno_spotify {
    type inferno
    NAME "Inferno-Test"
    BIND_IP 192.168.1.45
    SAMPLE_RATE 48000
    PROCESS_ID 1
    ALT_PORT 6000
    RX_CHANNELS 0
    TX_CHANNELS 2
    CLOCK_PATH /tmp/ptp-usrvclock
    DEVICE_ID 18602424aaa80000
}
`;

  await ensureIradioSetup("Inferno-Test", 2);
  const generated = files[ASOUNDRC];
  const iradioStart = generated.indexOf("# iradio-bridge Dante TX slot 1");
  if (iradioStart < 0) throw new Error("iradio ALSA blocks were not generated");
  const iradioBlocks = generated.slice(iradioStart);

  if (/BIND_IP\s+192\.168\.1\.45/.test(iradioBlocks)) {
    throw new Error("iradio generation inherited stale BIND_IP 192.168.1.45");
  }
  const bindMatches = iradioBlocks.match(/BIND_IP\s+enp0s31f6/g) || [];
  if (bindMatches.length !== 2) {
    throw new Error(`expected 2 iradio BIND_IP enp0s31f6 lines, got ${bindMatches.length}`);
  }

  if (/CLOCK_PATH\s+\/tmp\/ptp-usrvclock/.test(iradioBlocks)) {
    throw new Error("iradio generation inherited stale CLOCK_PATH /tmp/ptp-usrvclock");
  }
  const clockMatches = iradioBlocks.match(/CLOCK_PATH\s+\/dev\/ptp0/g) || [];
  if (clockMatches.length !== 2) {
    throw new Error(`expected 2 iradio CLOCK_PATH /dev/ptp0 lines, got ${clockMatches.length}`);
  }

  if (/DEVICE_ID\s+18602424aaa8000[ab]/.test(iradioBlocks)) {
    throw new Error("iradio generation inherited stale DEVICE_ID 18602424aaa80000");
  }
  if (!/DEVICE_ID\s+18602424bbbb000a/.test(iradioBlocks) || !/DEVICE_ID\s+18602424bbbb000b/.test(iradioBlocks)) {
    throw new Error("iradio generation did not derive DEVICE_ID values from INFERNO_DEVICE_ID");
  }

  if (/lib\s+"\/stale\/generated\/libasound_module_pcm_inferno\.so"/.test(iradioBlocks)) {
    throw new Error("iradio generation inherited stale pcm_type.inferno plugin path");
  }
  const iradioPluginMatches = iradioBlocks.match(/lib\s+"\/opt\/inferno\/lib\/libasound_module_pcm_inferno\.so"/g) || [];
  if (iradioPluginMatches.length !== 2) {
    throw new Error(`expected 2 iradio canonical plugin paths, got ${iradioPluginMatches.length}`);
  }

  await ensureAuxSetup("PCH", "none", "PCH", "none", 2, 2, "Inferno-Test");
  const withAux = files[ASOUNDRC];
  const auxStart = withAux.indexOf("# AUX TX: analog input");
  if (auxStart < 0) throw new Error("AUX ALSA blocks were not generated");
  const auxBlocks = withAux.slice(auxStart);

  if (/BIND_IP\s+192\.168\.1\.45/.test(auxBlocks)) {
    throw new Error("AUX generation inherited stale BIND_IP 192.168.1.45");
  }
  const auxBindMatches = auxBlocks.match(/BIND_IP\s+enp0s31f6/g) || [];
  if (auxBindMatches.length !== 2) {
    throw new Error(`expected 2 AUX BIND_IP enp0s31f6 lines, got ${auxBindMatches.length}`);
  }

  if (/DEVICE_ID\s+18602424aaa8000[12]/.test(auxBlocks)) {
    throw new Error("AUX generation inherited stale DEVICE_ID 18602424aaa80000");
  }
  if (!/DEVICE_ID\s+18602424bbbb0001/.test(auxBlocks) || !/DEVICE_ID\s+18602424bbbb0002/.test(auxBlocks)) {
    throw new Error("AUX generation did not derive DEVICE_ID values from INFERNO_DEVICE_ID");
  }

  if (!withAux.includes('pcm_type.inferno {\n    lib "/stale/generated/libasound_module_pcm_inferno.so"')) {
    throw new Error("fixture must preserve existing stale generated pcm_type.inferno block before canonicality checks");
  }
  files[ASOUNDRC] = `pcm.inferno_spotify {
    type inferno
    BIND_IP 192.168.1.45
    CLOCK_PATH /tmp/ptp-usrvclock
    DEVICE_ID 18602424aaa80000
}
`;
  await ensureAuxSetup("PCH", "none", "PCH", "none", 2, 2, "Inferno-Test");
  const auxWithoutPcmType = files[ASOUNDRC];
  if (/lib\s+"\/stale\/generated\/libasound_module_pcm_inferno\.so"/.test(auxWithoutPcmType)) {
    throw new Error("AUX generation inherited stale plugin path when creating pcm_type.inferno");
  }
  if (!auxWithoutPcmType.includes('pcm_type.inferno {\n    lib "/opt/inferno/lib/libasound_module_pcm_inferno.so"')) {
    throw new Error("AUX generation did not create pcm_type.inferno with canonical plugin path");
  }

  files[ASOUNDRC] = `pcm.inferno_aux_tx {
    type inferno
    BIND_IP 192.168.1.45
    TX_CHANNELS 2
    CLOCK_PATH /tmp/ptp-usrvclock
    DEVICE_ID 18602424aaa80001
}

pcm.inferno_aux_rx {
    type inferno
    BIND_IP 192.168.1.45
    RX_CHANNELS 2
    CLOCK_PATH /tmp/ptp-usrvclock
    DEVICE_ID 18602424aaa80002
}
`;
  await ensureAuxSetup("PCH", "none", "PCH", "none", 4, 4, "Inferno-Test");
  const updatedAux = files[ASOUNDRC];
  const updatedAuxBlocks = updatedAux.slice(updatedAux.indexOf("pcm.inferno_aux_tx"));
  if (/BIND_IP\s+192\.168\.1\.45/.test(updatedAuxBlocks)) {
    throw new Error("existing AUX update kept stale BIND_IP 192.168.1.45");
  }
  if (/CLOCK_PATH\s+\/tmp\/ptp-usrvclock/.test(updatedAuxBlocks)) {
    throw new Error("existing AUX update kept stale CLOCK_PATH /tmp/ptp-usrvclock");
  }
  const updatedAuxBindMatches = updatedAuxBlocks.match(/BIND_IP\s+enp0s31f6/g) || [];
  if (updatedAuxBindMatches.length !== 2) {
    throw new Error(`expected 2 updated AUX BIND_IP enp0s31f6 lines, got ${updatedAuxBindMatches.length}`);
  }
  const updatedAuxClockMatches = updatedAuxBlocks.match(/CLOCK_PATH\s+\/dev\/ptp0/g) || [];
  if (updatedAuxClockMatches.length !== 2) {
    throw new Error(`expected 2 updated AUX CLOCK_PATH /dev/ptp0 lines, got ${updatedAuxClockMatches.length}`);
  }

  currentConf = {
    INFERNO_NIC: "enp0s31f6",
    INFERNO_INTERFACE: "172.16.10.63",
    INFERNO_BIND: "enp0s31f6",
    INFERNO_CLOCK_PATH: "/dev/ptp0",
  };
  files[ASOUNDRC] = `pcm.inferno_spotify {
    type inferno
    BIND_IP enp0s31f6
    CLOCK_PATH /dev/ptp0
    DEVICE_ID 18602424aaa80000
}
`;
  try {
    await ensureAuxSetup("PCH", "none", "PCH", "none", 2, 2, "Inferno-Test");
    throw new Error("AUX generation accepted missing INFERNO_DEVICE_ID");
  } catch (err) {
    const message = err && err.message ? err.message : String(err);
    if (message !== "INFERNO_DEVICE_ID is required for Dante device identity") {
      throw new Error(`unexpected missing device ID error: ${message}`);
    }
  }

  files[ASOUNDRC] = `pcm.inferno_spotify {
    type inferno
    BIND_IP enp0s31f6
    CLOCK_PATH /dev/ptp0
    DEVICE_ID 18602424aaa80000
}
`;
  try {
    await ensureIradioSetup("Inferno-Test", 2);
    throw new Error("iradio generation accepted missing INFERNO_DEVICE_ID");
  } catch (err) {
    const message = err && err.message ? err.message : String(err);
    if (message !== "INFERNO_DEVICE_ID is required for Dante device identity") {
      throw new Error(`unexpected iradio missing device ID error: ${message}`);
    }
  }

  currentConf = { INFERNO_INTERFACE: "172.16.10.63" };
  try {
    await ensureIradioSetup("Inferno-Test", 2);
    throw new Error("iradio generation accepted missing INFERNO_BIND and INFERNO_NIC");
  } catch (err) {
    const message = err && err.message ? err.message : String(err);
    if (message !== "INFERNO_BIND or INFERNO_NIC is required for Dante binding") {
      throw new Error(`unexpected missing bind/NIC error: ${message}`);
    }
  }
})();
NODE

assert_not_contains \
    "$librespot_unit" \
    '--enable-audio-locking' \
    'librespot 0.8.0 rejects --enable-audio-locking, causing Spotify mode to exit before ALSA starts'

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
