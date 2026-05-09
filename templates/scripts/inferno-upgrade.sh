#!/bin/bash
# inferno-upgrade.sh — run every boot to sync user service templates
# Ensures bootc upgrades propagate updated service files to /var/home/core/.config/systemd/user/
# Reads /etc/inferno.conf for substitution values.
set -euo pipefail

TEMPLATE_DIR="${INFERNO_TEMPLATE_DIR:-/etc/inferno/systemd/user}"
CORE_HOME="${INFERNO_CORE_HOME:-/var/home/core}"
SYSTEMD_USER="${INFERNO_SYSTEMD_USER:-${CORE_HOME}/.config/systemd/user}"
INFERNO_CONF="${INFERNO_CONF:-/etc/inferno.conf}"
SYS_CLASS_NET="${INFERNO_SYS_CLASS_NET:-/sys/class/net}"
DEV_ROOT="${INFERNO_DEV_ROOT:-/dev}"
IP_FIXTURE="${INFERNO_IP_FIXTURE:-}"
ETC_GROUP="${INFERNO_ETC_GROUP:-/etc/group}"
CORE_UID=1000

# Load node config for placeholder substitution
[ -f "${INFERNO_CONF}" ] || { echo "inferno.conf missing — skipping upgrade"; exit 0; }
# shellcheck disable=SC1091
source "${INFERNO_CONF}"

INFERNO_NAME="${INFERNO_NAME:-inferno}"
INFERNO_AUDIO_CARD="${INFERNO_AUDIO_CARD:-hw:0}"
INFERNO_NIC="${INFERNO_NIC:-eth0}"
INFERNO_DEVICE_ID="${INFERNO_DEVICE_ID:-}"
INFERNO_DEVICE_ID_TX="${INFERNO_DEVICE_ID_TX:-}"
INFERNO_DEVICE_ID_RX="${INFERNO_DEVICE_ID_RX:-}"
INFERNO_INTERFACE="${INFERNO_INTERFACE:-}"
INFERNO_CLOCK_PATH="${INFERNO_CLOCK_PATH:-/tmp/ptp-usrvclock}"
INFERNO_PLUGIN_PATH="${INFERNO_PLUGIN_PATH:-/usr/lib64/alsa-lib/libasound_module_pcm_inferno.so}"

changed=0

is_excluded_nic() {
    local nic="$1"
    case "${nic}" in
        lo|docker*|br-*|veth*|virbr*|tap*|tun*) return 0 ;;
    esac
    [ -d "${SYS_CLASS_NET}/${nic}/wireless" ] && return 0
    [ -d "${SYS_CLASS_NET}/${nic}/phy80211" ] && return 0
    return 1
}

nic_exists() {
    [ -n "${1:-}" ] && [ -d "${SYS_CLASS_NET}/$1" ]
}

viable_nic() {
    nic_exists "$1" && ! is_excluded_nic "$1"
}

fixture_field() {
    local want_nic="$1" want_field="$2" nic ip default_flag
    [ -n "${IP_FIXTURE}" ] && [ -f "${IP_FIXTURE}" ] || return 1
    while read -r nic ip default_flag _; do
        [ -n "${nic:-}" ] || continue
        [ "${nic#\#}" = "${nic}" ] || continue
        [ "${nic}" = "${want_nic}" ] || continue
        case "${want_field}" in
            ip)
                [ "${ip:-}" = "-" ] && return 0
                printf '%s\n' "${ip:-}"
                return 0
                ;;
            default)
                [ "${default_flag:-}" = "default" ] || return 1
                printf '%s\n' "${nic}"
                return 0
                ;;
        esac
    done < "${IP_FIXTURE}"
    return 1
}

current_ipv4() {
    local nic="$1" line addr
    if [ -n "${IP_FIXTURE}" ] && [ -f "${IP_FIXTURE}" ]; then
        fixture_field "${nic}" ip || true
        return 0
    fi
    line=$(ip -o -4 addr show dev "${nic}" scope global 2>/dev/null | while read -r found; do printf '%s\n' "${found}"; break; done || true)
    [ -n "${line}" ] || return 0
    set -- ${line}
    addr="${4:-}"
    printf '%s\n' "${addr%%/*}"
}

default_route_nic() {
    local nic ip default_flag line dev next
    if [ -n "${IP_FIXTURE}" ] && [ -f "${IP_FIXTURE}" ]; then
        while read -r nic ip default_flag _; do
            [ -n "${nic:-}" ] || continue
            [ "${nic#\#}" = "${nic}" ] || continue
            if [ "${default_flag:-}" = "default" ] && viable_nic "${nic}"; then
                printf '%s\n' "${nic}"
                return 0
            fi
        done < "${IP_FIXTURE}"
        return 1
    fi
    line=$(ip -o route show default 2>/dev/null | while read -r found; do printf '%s\n' "${found}"; break; done || true)
    set -- ${line}
    while [ "$#" -gt 0 ]; do
        next="$1"
        shift
        if [ "${next}" = "dev" ] && [ "$#" -gt 0 ]; then
            dev="$1"
            if viable_nic "${dev}"; then
                printf '%s\n' "${dev}"
                return 0
            fi
            return 1
        fi
    done
    return 1
}

fallback_nic() {
    local default_nic count=0 selected='' path nic
    default_nic=$(default_route_nic || true)
    if [ -n "${default_nic}" ]; then
        printf '%s\n' "${default_nic}"
        return 0
    fi
    for path in "${SYS_CLASS_NET}"/*; do
        [ -d "${path}" ] || continue
        nic="${path##*/}"
        viable_nic "${nic}" || continue
        selected="${nic}"
        count=$((count + 1))
    done
    case "${count}" in
        1) printf '%s\n' "${selected}" ;;
        0) echo "inferno-upgrade: ERROR: saved NIC '${INFERNO_NIC}' is missing and no viable fallback NIC was found" >&2; return 1 ;;
        *) echo "inferno-upgrade: ERROR: saved NIC '${INFERNO_NIC}' is missing and fallback NIC selection is ambiguous" >&2; return 1 ;;
    esac
}

ptp_clock_path() {
    local nic="$1" ptp_path ptp_dev
    for ptp_path in "${SYS_CLASS_NET}/${nic}/device/ptp/"*; do
        [ -e "${ptp_path}" ] || continue
        ptp_dev="${ptp_path##*/}"
        if [ -c "${DEV_ROOT}/${ptp_dev}" ] || { [ "${INFERNO_ALLOW_NON_CHAR_PTP:-0}" = "1" ] && [ -e "${DEV_ROOT}/${ptp_dev}" ]; }; then
            printf '/dev/%s\n' "${ptp_dev}"
            return 0
        fi
    done
    printf '/tmp/ptp-usrvclock\n'
}

shell_quote() {
    printf "'%s'" "${1//\'/\'\\\'\'}"
}

write_conf_value() {
    local key="$1" value="$2"
    printf '%s=' "${key}"
    shell_quote "${value}"
    printf '\n'
}

write_canonical_conf() {
    local tmp conf_dir stripped
    conf_dir=$(dirname "${INFERNO_CONF}")
    tmp=$(mktemp "${conf_dir}/.inferno.conf.XXXXXX")
    while IFS= read -r line || [ -n "${line:-}" ]; do
        stripped="${line#"${line%%[![:space:]]*}"}"
        if [[ "${stripped}" == export[[:space:]]* ]]; then
            stripped="${stripped#export}"
            stripped="${stripped#"${stripped%%[![:space:]]*}"}"
        fi
        case "${stripped}" in
            INFERNO_NIC=*|INFERNO_INTERFACE=*|INFERNO_BIND=*|INFERNO_HW_PTP=*|INFERNO_CLOCK_PATH=*) continue ;;
        esac
        printf '%s\n' "${line}" >> "${tmp}"
    done < "${INFERNO_CONF}"
    write_conf_value INFERNO_NIC "${INFERNO_NIC}" >> "${tmp}"
    if [ -n "${INFERNO_INTERFACE}" ]; then
        write_conf_value INFERNO_INTERFACE "${INFERNO_INTERFACE}" >> "${tmp}"
    fi
    write_conf_value INFERNO_BIND "${INFERNO_BIND}" >> "${tmp}"
    write_conf_value INFERNO_HW_PTP "${INFERNO_HW_PTP}" >> "${tmp}"
    write_conf_value INFERNO_CLOCK_PATH "${INFERNO_CLOCK_PATH}" >> "${tmp}"
    if ! diff -q "${tmp}" "${INFERNO_CONF}" &>/dev/null 2>&1; then
        chmod 0644 "${tmp}"
        chown root:root "${tmp}" 2>/dev/null || true
        mv -f "${tmp}" "${INFERNO_CONF}"
        echo "  updated: inferno.conf bind identity"
        changed=1
        return 0
    fi
    rm -f "${tmp}"
}

if ! nic_exists "${INFERNO_NIC}"; then
    INFERNO_NIC=$(fallback_nic)
fi
INFERNO_BIND="${INFERNO_NIC}"
CURRENT_IPV4=$(current_ipv4 "${INFERNO_NIC}")
if [ -n "${CURRENT_IPV4}" ] && [ "${CURRENT_IPV4}" != "0.0.0.0" ]; then
    INFERNO_INTERFACE="${CURRENT_IPV4}"
elif [ -n "${INFERNO_INTERFACE}" ] && [ "${INFERNO_INTERFACE}" != "0.0.0.0" ]; then
    echo "inferno-upgrade: WARNING: no current IPv4 for ${INFERNO_NIC}; preserving INFERNO_INTERFACE=${INFERNO_INTERFACE}" >&2
fi
INFERNO_CLOCK_PATH=$(ptp_clock_path "${INFERNO_NIC}")
if [ "${INFERNO_CLOCK_PATH}" = "/tmp/ptp-usrvclock" ]; then
    INFERNO_HW_PTP=no
else
    INFERNO_HW_PTP=yes
fi

write_canonical_conf

sed_replacement() {
    printf '%s' "$1" | sed 's/[&\\]/\\&/g'
}

repair_asoundrc() {
    local tmp asound_dir
    asound_dir=$(dirname "${ASOUNDRC}")
    tmp=$(mktemp "${asound_dir}/.asoundrc.XXXXXX")
    REPAIR_BIND="${INFERNO_BIND}" REPAIR_CLOCK="${INFERNO_CLOCK_PATH}" awk '
        function brace_delta(line, i, ch, delta) {
            delta = 0
            for (i = 1; i <= length(line); i++) {
                ch = substr(line, i, 1)
                if (ch == "{") delta++
                if (ch == "}") delta--
            }
            return delta
        }
        function update_stanza_state(line) {
            if (in_inferno_pcm) {
                brace_depth += brace_delta(line)
                if (brace_depth <= 0) in_inferno_pcm = 0
            }
        }
        BEGIN {
            bind = ENVIRON["REPAIR_BIND"]
            clock_path = ENVIRON["REPAIR_CLOCK"]
            in_inferno_pcm = 0
            brace_depth = 0
        }
        !in_inferno_pcm && /^[[:space:]]*pcm\.inferno_[^[:space:]]*[[:space:]]*\{/ {
            in_inferno_pcm = 1
            brace_depth = 0
        }
        in_inferno_pcm && /^[[:space:]]*BIND_IP[[:space:]]+/ {
            match($0, /^[[:space:]]*BIND_IP[[:space:]]+/)
            print substr($0, 1, RLENGTH) bind
            update_stanza_state($0)
            next
        }
        in_inferno_pcm && /^[[:space:]]*CLOCK_PATH[[:space:]]+/ {
            match($0, /^[[:space:]]*CLOCK_PATH[[:space:]]+/)
            print substr($0, 1, RLENGTH) clock_path
            update_stanza_state($0)
            next
        }
        {
            print
            update_stanza_state($0)
        }
    ' "${ASOUNDRC}" > "${tmp}" || { rm -f "${tmp}"; return 1; }
    if ! diff -q "${tmp}" "${ASOUNDRC}" &>/dev/null 2>&1; then
        chmod --reference="${ASOUNDRC}" "${tmp}" 2>/dev/null || true
        chown --reference="${ASOUNDRC}" "${tmp}" 2>/dev/null || true
        mv -f "${tmp}" "${ASOUNDRC}"
        echo "  repaired: .asoundrc BIND_IP -> ${INFERNO_BIND}"
        echo "  repaired: .asoundrc CLOCK_PATH -> ${INFERNO_CLOCK_PATH}"
        changed=1
        return 0
    fi
    rm -f "${tmp}"
}

refresh_ptp_access() {
    local clock_gid group_dir tmp
    if ! getent group clock >/dev/null; then
        groupadd -r clock || true
    fi
    getent group clock >/dev/null || { echo "inferno-upgrade: ERROR: clock group is unavailable" >&2; return 1; }
    usermod -aG clock core
    clock_gid=$(getent group clock | awk -F: '{print $3; exit}')
    [[ "${clock_gid}" =~ ^[0-9]+$ ]] || { echo "inferno-upgrade: ERROR: invalid clock group GID '${clock_gid}'" >&2; return 1; }
    [ -f "${ETC_GROUP}" ] || { echo "inferno-upgrade: ERROR: active group file '${ETC_GROUP}' is missing" >&2; return 1; }
    group_dir=$(dirname "${ETC_GROUP}")
    tmp=$(mktemp "${group_dir}/.group.XXXXXX")
    awk -F: -v gid="${clock_gid}" '
        BEGIN { OFS = FS }
        $1 == "clock" {
            saw_clock = 1
            split($4, members, ",")
            for (i in members) {
                if (members[i] != "") seen[members[i]] = 1
            }
            seen["core"] = 1
            list = ""
            for (i = 1; i <= length($4); i++) {
                member = ""
                while (i <= length($4) && substr($4, i, 1) != ",") {
                    member = member substr($4, i, 1)
                    i++
                }
                if (member != "" && seen[member]) {
                    list = list (list == "" ? "" : ",") member
                    seen[member] = 0
                }
            }
            if (seen["core"]) list = list (list == "" ? "" : ",") "core"
            print "clock", $2, gid, list
            next
        }
        { print }
        END {
            if (!saw_clock) print "clock", "x", gid, "core"
        }
    ' "${ETC_GROUP}" > "${tmp}"
    chmod 0644 "${tmp}"
    chown root:root "${tmp}" 2>/dev/null || true
    if ! [ -f "${ETC_GROUP}" ] || ! diff -q "${tmp}" "${ETC_GROUP}" &>/dev/null 2>&1; then
        mv -f "${tmp}" "${ETC_GROUP}"
    else
        rm -f "${tmp}"
    fi
    udevadm control --reload || true
    udevadm trigger --subsystem-match=ptp --action=add || true
}

mkdir -p "${SYSTEMD_USER}"

sub_template() {
    local src="$1" dst="$2"
    local tmp
    tmp=$(mktemp)
    sed \
        -e "s|%%INFERNO_NAME%%|${INFERNO_NAME}|g" \
        -e "s|%%INFERNO_NIC%%|${INFERNO_NIC}|g" \
        -e "s|%%INFERNO_INTERFACE%%|${INFERNO_INTERFACE}|g" \
        -e "s|%%INFERNO_BIND%%|${INFERNO_BIND}|g" \
        -e "s|%%INFERNO_CLOCK_PATH%%|${INFERNO_CLOCK_PATH}|g" \
        -e "s|%%INFERNO_DEVICE_ID%%|${INFERNO_DEVICE_ID}|g" \
        -e "s|%%INFERNO_DEVICE_ID_TX%%|${INFERNO_DEVICE_ID_TX}|g" \
        -e "s|%%INFERNO_DEVICE_ID_RX%%|${INFERNO_DEVICE_ID_RX}|g" \
        -e "s|%%INFERNO_PLUGIN_PATH%%|${INFERNO_PLUGIN_PATH}|g" \
        -e "s|%%INFERNO_AUDIO_CARD%%|${INFERNO_AUDIO_CARD}|g" \
        "${src}" > "${tmp}"

    if ! diff -q "${tmp}" "${dst}" &>/dev/null 2>&1; then
        cp -f "${tmp}" "${dst}"
        echo "  updated: $(basename "${dst}")"
        changed=1
    fi
    rm -f "${tmp}"
}

copy_if_changed() {
    local src="$1" dst="$2"
    if ! diff -q "${src}" "${dst}" &>/dev/null 2>&1; then
        cp -f "${src}" "${dst}"
        echo "  updated: $(basename "${dst}")"
        changed=1
    fi
}

echo "inferno-upgrade: syncing user service templates..."

# Static service files (no placeholders)
for unit in inferno-bridge inferno-keepalive librespot-watchdog inferno-aux-keepalive; do
    src="${TEMPLATE_DIR}/${unit}.service"
    dst="${SYSTEMD_USER}/${unit}.service"
    [ -f "${src}" ] || continue
    copy_if_changed "${src}" "${dst}"
done

# Service files with placeholders
for unit in librespot inferno-aux-tx inferno-aux-rx; do
    src="${TEMPLATE_DIR}/${unit}.service"
    dst="${SYSTEMD_USER}/${unit}.service"
    [ -f "${src}" ] || continue
    sub_template "${src}" "${dst}"
done

# Repair generated ALSA config from older images. v36 could write BIND_IP 0.0.0.0
# or stale nonzero IP binds when DHCP/networking changed. Hardware-PTP nodes need direct /dev/ptpN CLOCK_PATH
# instead of stale CLOCK_PATH /tmp/ptp-usrvclock output when a usable PTP device exists.
# because statime does not emit usable usrvclock updates while acting as PTPv1 master.
ASOUNDRC="${CORE_HOME}/.asoundrc"
if [ -f "${ASOUNDRC}" ]; then
    repair_asoundrc
fi

if [ "${INFERNO_SKIP_OWNERSHIP:-0}" != "1" ]; then
    refresh_ptp_access
    chown -R core:core "${SYSTEMD_USER}"
    chown core:core "${CORE_HOME}/.asoundrc" 2>/dev/null || true
    restorecon -Rv "${CORE_HOME}/" 2>/dev/null || true
fi

if [ "${changed}" -eq 1 ]; then
    echo "inferno-upgrade: files changed — reloading user daemon"
    # Reload user daemon if lingering session is already active
    if [ "${INFERNO_SKIP_USER_RELOAD:-0}" != "1" ] && [ -d "/run/user/${CORE_UID}/systemd" ]; then
        sudo -u core XDG_RUNTIME_DIR="/run/user/${CORE_UID}" systemctl --user daemon-reload || true
    fi
else
    echo "inferno-upgrade: all service files up to date"
fi
