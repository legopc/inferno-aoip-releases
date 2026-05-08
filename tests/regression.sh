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

statime_template="${repo_root}/templates/inferno-ptpv1.toml"
configure_script="${repo_root}/build/inferno-configure.sh"
configure_unit="${repo_root}/build/systemd/inferno-configure.service"
containerfile="${repo_root}/Containerfile"
spotify_asound="${repo_root}/templates/alsa/asoundrc.spotify"
aux_asound="${repo_root}/templates/alsa/asoundrc.aux"
upgrade_script="${repo_root}/templates/scripts/inferno-upgrade.sh"
librespot_unit="${repo_root}/templates/systemd/user/librespot.service"

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
    mkdir -p \
        "${fixture}/core/.config/systemd/user" \
        "${fixture}/templates" \
        "${fixture}/sys/class/net/eno1/device/ptp" \
        "${fixture}/dev"
    : > "${fixture}/sys/class/net/eno1/device/ptp/ptp0"
    : > "${fixture}/dev/ptp0"

    env \
        INFERNO_CONF="${fixture}/inferno.conf" \
        INFERNO_TEMPLATE_DIR="${fixture}/templates" \
        INFERNO_CORE_HOME="${fixture}/core" \
        INFERNO_SYSTEMD_USER="${fixture}/core/.config/systemd/user" \
        INFERNO_SYS_CLASS_NET="${fixture}/sys/class/net" \
        INFERNO_DEV_ROOT="${fixture}/dev" \
        INFERNO_ALLOW_NON_CHAR_PTP="${allow_non_char_ptp}" \
        INFERNO_SKIP_OWNERSHIP=1 \
        INFERNO_SKIP_USER_RELOAD=1 \
        bash "${upgrade_script}" > "${fixture}/upgrade.log" 2>&1
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
mkdir -p "${escape_fixture}/core"
cat > "${escape_fixture}/inferno.conf" <<'EOF_CONF'
INFERNO_NIC=eno1
INFERNO_BIND='eno&1\lab'
INFERNO_CLOCK_PATH='/dev/ptp&0\lab'
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

REPO_ROOT="$repo_root" node <<'NODE'
const fs = require("fs");

(async () => {
  const repoRoot = process.env.REPO_ROOT;
  const source = fs.readFileSync(`${repoRoot}/src/inferno.js`, "utf8");
  const start = source.indexOf("function deriveDeviceId");
  const end = source.indexOf("async function ensureAuxSetup");
  if (start < 0 || end < 0 || end <= start) {
    throw new Error("could not extract iradio generation functions from src/inferno.js");
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
  async function spUser() {}
  let currentConf = {
    INFERNO_NIC: "eno1",
    INFERNO_INTERFACE: "0.0.0.0",
    INFERNO_BIND: "eno1",
    INFERNO_CLOCK_PATH: "/dev/ptp0",
  };

  eval(source.slice(start, end));

  files[ASOUNDRC] = `pcm_type.inferno {
    lib "/usr/lib64/alsa-lib/libasound_module_pcm_inferno.so"
}

pcm.inferno_spotify {
    type inferno
    NAME "Inferno-Test"
    BIND_IP 0.0.0.0
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

  if (/BIND_IP\s+0\.0\.0\.0/.test(iradioBlocks)) {
    throw new Error("iradio generation inherited stale BIND_IP 0.0.0.0");
  }
  const bindMatches = iradioBlocks.match(/BIND_IP\s+eno1/g) || [];
  if (bindMatches.length !== 2) {
    throw new Error(`expected 2 iradio BIND_IP eno1 lines, got ${bindMatches.length}`);
  }

  if (/CLOCK_PATH\s+\/tmp\/ptp-usrvclock/.test(iradioBlocks)) {
    throw new Error("iradio generation inherited stale CLOCK_PATH /tmp/ptp-usrvclock");
  }
  const clockMatches = iradioBlocks.match(/CLOCK_PATH\s+\/dev\/ptp0/g) || [];
  if (clockMatches.length !== 2) {
    throw new Error(`expected 2 iradio CLOCK_PATH /dev/ptp0 lines, got ${clockMatches.length}`);
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
