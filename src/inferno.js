/* inferno.js — Cockpit Inferno AoIP page
 * Vanilla JS, cockpit.spawn() / cockpit.file() — no build step.
 * Privileged ops use "sudo -n" (wheel NOPASSWD) to avoid pkexec/polkit.
 */

// ── Constants ──────────────────────────────────────────────────────────────────
const CONF          = "/etc/inferno.conf";
const SENTINEL      = "/var/lib/inferno/.deployed";
const ASOUNDRC      = "/var/home/core/.asoundrc";
const LIBRESPOT_SVC = "/var/home/core/.config/systemd/user/librespot.service";

const SYSTEM_SVCS  = ["statime-inferno"];
const SPOTIFY_SVCS = ["librespot", "librespot-watchdog", "inferno-bridge", "inferno-keepalive"];
// aux-keepalive must NOT run alongside aux-rx (competing Dante subscription owners break streaming).
const AUX_IN_SVCS    = ["inferno-aux-tx"];
const AUX_OUT_SVCS   = ["inferno-aux-rx"];
const AUX_BIDIR_SVCS = ["inferno-aux-tx", "inferno-aux-rx"];
// All aux services — used for stop-before-switch
const ALL_AUX_SVCS   = ["inferno-aux-tx", "inferno-aux-rx", "inferno-aux-keepalive"];

const IRADIO_SVCS  = ["iradio-bridge"];

const SVC_LABELS = {
    "librespot":             { label: "librespot",           desc: "Spotify Connect receiver" },
    "librespot-watchdog":    { label: "librespot-watchdog",  desc: "Watchdog & auto-restart" },
    "inferno-bridge":        { label: "inferno-bridge",      desc: "ALSA loopback to Dante TX" },
    "inferno-keepalive":     { label: "inferno-keepalive",   desc: "Dante TX keepalive writer" },
    "inferno-aux-tx":        { label: "inferno-aux-tx",      desc: "AUX to Dante TX bridge" },
    "inferno-aux-rx":        { label: "inferno-aux-rx",      desc: "Dante RX to AUX output" },
    "inferno-aux-keepalive": { label: "inferno-aux-keepalive", desc: "AUX Dante keepalive" },
    "statime-inferno":       { label: "statime",             desc: "PTP hardware clock sync" },
    "iradio-bridge":         { label: "iradio-bridge",       desc: "Internet Radio → Dante TX" },
};

let currentConf = {};
let currentMode = "spotify";
let isDirty     = false;
let USER_UID    = 1000;
let USER_HOME   = "/var/home/core";

let _refreshTimer  = null;   // auto-refresh interval handle
let _followTimer   = null;   // journal follow interval handle
let _ptpHistory    = [];     // rolling offset history for sparkline (max 30 pts)

// ── Helpers ────────────────────────────────────────────────────────────────────
const $ = id => document.getElementById(id);

// Environment for user-session commands: replaces process env in cockpit.spawn
function userEnv() {
    return [
        "HOME=" + USER_HOME,
        "USER=core",
        "PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin",
        "XDG_RUNTIME_DIR=/run/user/" + USER_UID,
        "DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/" + USER_UID + "/bus",
    ];
}

// Plain non-privileged spawn (inherits cockpit-bridge env)
function sp(args) {
    return cockpit.spawn(args, { err: "message" });
}

// Shell command in user session environment (for systemctl --user, journalctl --user, sed, etc.)
function spUser(cmd) {
    return cockpit.spawn(["bash", "-c", cmd], { err: "message", environ: userEnv() });
}

// Privileged shell command via sudo -n (NOPASSWD wheel) — avoids pkexec/polkit/TTY issues
function spSudo(cmd) {
    return cockpit.spawn(["bash", "-c", "sudo -n " + cmd], { err: "message", environ: userEnv() });
}

// Write a file as root using sudo tee (stdin pipe)
function writeFileAsSudo(path, content) {
    const proc = cockpit.spawn(["sudo", "-n", "tee", path],
        { err: "message", environ: userEnv() });
    proc.input(content);   // no second arg = stream:false = close stdin after this chunk
    return proc;
}

// ── Toast notifications ────────────────────────────────────────────────────────
function toast(msg, type, duration) {
    type = type || "info";
    if (duration === undefined) duration = 5000;
    const icons = { success: "\u2705", error: "\u274c", info: "\u2139\ufe0f" };
    const div = document.createElement("div");
    div.className = "toast toast-" + type;
    const iconEl = document.createElement("span");
    iconEl.className = "toast-icon";
    iconEl.textContent = icons[type] || "";
    const msgEl = document.createElement("span");
    msgEl.innerHTML = msg;
    const closeEl = document.createElement("span");
    closeEl.className = "toast-close";
    closeEl.textContent = "\u2715";
    closeEl.onclick = function() { div.remove(); };
    div.appendChild(iconEl);
    div.appendChild(msgEl);
    div.appendChild(closeEl);
    $("toast-area").appendChild(div);
    if (duration > 0) setTimeout(function() { if (div.parentNode) div.remove(); }, duration);
    return div;
}

// ── Config ─────────────────────────────────────────────────────────────────────
function parseConf(text) {
    var c = {};
    (text || "").split("\n").forEach(function(line) {
        var t = line.trim();
        if (!t || t[0] === "#" || t.indexOf("=") === -1) return;
        var i = t.indexOf("=");
        c[t.slice(0, i).trim()] = t.slice(i + 1).trim();
    });
    return c;
}

function buildConfText(conf) {
    var lines = ["# Inferno AoIP node configuration\n# Managed via Cockpit\n"];
    Object.keys(conf).forEach(function(k) { lines.push(k + "=" + conf[k] + "\n"); });
    return lines.join("");
}

async function loadConfig() {
    var spotifyName = "";
    var danteName   = "";
    var lsBitrate   = "320";
    var lsNorm      = "";
    try {
        var svcText = await cockpit.file(LIBRESPOT_SVC).read();
        var m = (svcText || "").match(/--name\s+"([^"]+)"/);
        if (m) spotifyName = m[1];
        var mb = (svcText || "").match(/--bitrate\s+(\d+)/);
        if (mb) lsBitrate = mb[1];
        var mn = (svcText || "").match(/--normalisation-method\s+(\S+)/);
        if (mn) lsNorm = mn[1];
    } catch (_) {}
    try {
        var asoundText = await cockpit.file(ASOUNDRC).read();
        var m2 = (asoundText || "").match(/NAME\s+"([^"]+)"/);
        if (m2) danteName = m2[1];
    } catch (_) {}

    var confText = "";
    try { confText = await cockpit.file(CONF).read() || ""; } catch (_) {}

    currentConf = parseConf(confText);

    $("cfg-spotify-name").value = spotifyName || currentConf.INFERNO_NAME || "";
    $("cfg-dante-name").value   = danteName   || currentConf.INFERNO_NAME || "";
    currentMode = currentConf.INFERNO_MODE || "spotify";
    $("cfg-mode").value = currentMode;

    // Librespot quality settings — both grayed out: Inferno does not support
    // runtime bitrate changes (ALSA impact) and normalisation is not in this build.
    var bitrateEl   = $("cfg-librespot-bitrate");
    var normaliseEl = $("cfg-librespot-normalize");
    bitrateEl.value    = lsBitrate;
    normaliseEl.value  = lsNorm;
    bitrateEl.disabled   = true;
    normaliseEl.disabled = true;
    bitrateEl.title   = "Bitrate changes are not supported at runtime — would require ALSA reconfiguration";
    normaliseEl.title = "Normalisation is not supported by this librespot build";

    // Loop latency
    var latency = parseInt(currentConf.INFERNO_LOOP_LATENCY) || 10000;
    $("cfg-loop-latency").value = latency;
    $("cfg-loop-latency-val").textContent = Math.round(latency/1000) + " ms";

    onModeChange();

    await populateNics(currentConf.INFERNO_NIC || "auto");
    var cardIn   = currentConf.INFERNO_AUDIO_CARD_IN   || currentConf.INFERNO_AUDIO_CARD || "0";
    var cardOut  = currentConf.INFERNO_AUDIO_CARD_OUT  || currentConf.INFERNO_AUDIO_CARD || "0";
    var cardIn2  = currentConf.INFERNO_AUDIO_CARD_IN2  || "none";
    var cardOut2 = currentConf.INFERNO_AUDIO_CARD_OUT2 || "none";
    await populateAudio(cardIn, cardOut, cardIn2, cardOut2);

    $("cfg-tx-channels").value = currentConf.INFERNO_TX_CHANNELS || "2";
    $("cfg-rx-channels").value = currentConf.INFERNO_RX_CHANNELS || "2";
    onChannelChange();

    isDirty = false;
    $("cfg-dirty-badge").classList.add("hidden");
    updateModeFlow();
    // F-2: snapshot form values so diff modal knows what changed
    _savedConfSnapshot = buildFormSnapshot();

    // Populate iradio channel count from saved config.toml if present
    if ($("cfg-iradio-channels")) {
        cockpit.file(IRADIO_CONFIG_PATH).read().then(function(toml) {
            if (!toml) return;
            var m = toml.match(/max_players\s*=\s*(\d+)/);
            if (m) {
                var n = m[1];
                var sel = $("cfg-iradio-channels");
                for (var i = 0; i < sel.options.length; i++) {
                    if (sel.options[i].value === n) { sel.selectedIndex = i; break; }
                }
            }
        }).catch(function() {});
    }

    // Ensure iradio-bridge is stopped if we're not in iradio mode
    if (currentMode !== "iradio") {
        spUser("systemctl --user stop iradio-bridge 2>/dev/null; true").catch(function() {});
    }
}

function markDirty() {
    isDirty = true;
    $("cfg-dirty-badge").classList.remove("hidden");
}

function onModeChange() {
    currentMode = $("cfg-mode").value;
    var isSpotify  = currentMode === "spotify";
    var isAuxIn    = currentMode === "aux-in"    || currentMode === "aux-bidir";
    var isAuxOut   = currentMode === "aux-out"   || currentMode === "aux-bidir";
    var isIradio   = currentMode === "iradio";
    $("field-spotify-name").classList.toggle("hidden", !isSpotify);
    $("field-librespot-bitrate").classList.toggle("hidden", !isSpotify);
    $("field-librespot-bitrate-hint").classList.toggle("hidden", !isSpotify);
    $("field-librespot-normalize").classList.toggle("hidden", !isSpotify);
    $("field-librespot-normalize-hint").classList.toggle("hidden", !isSpotify);
    $("field-audio-in").classList.toggle("hidden", !isAuxIn);
    $("field-tx-channels").classList.toggle("hidden", !isAuxIn);
    $("field-audio-out").classList.toggle("hidden", !isAuxOut);
    $("field-rx-channels").classList.toggle("hidden", !isAuxOut);
    $("field-loop-latency").classList.toggle("hidden", !isAuxIn && !isAuxOut);
    if ($("field-iradio")) {
        $("field-iradio").classList.toggle("hidden", !isIradio);
        if (isIradio && $("iradio-ui-link")) {
            var host = window.location.hostname || "localhost";
            var url  = "http://" + host + ":8765";
            $("iradio-ui-link").href = url;
            $("iradio-ui-link").textContent = url;
        }
    }
    onChannelChange();
    updateModeFlow();
}

function onChannelChange() {
    var txCh = parseInt($("cfg-tx-channels").value) || 2;
    var rxCh = parseInt($("cfg-rx-channels").value) || 2;
    var isAuxIn  = currentMode === "aux-in"  || currentMode === "aux-bidir";
    var isAuxOut = currentMode === "aux-out" || currentMode === "aux-bidir";
    $("field-audio-in2").classList.toggle("hidden",  !(isAuxIn  && txCh >= 4));
    $("field-audio-out2").classList.toggle("hidden", !(isAuxOut && rxCh >= 4));
}

// ── NIC discovery ──────────────────────────────────────────────────────────────
async function populateNics(current) {
    var sel = $("cfg-nic");
    sel.innerHTML = "";
    function add(v, label) { sel.add(new Option(label, v, false, v === current)); }
    try {
        var out = await sp(["ip", "-o", "link", "show"]);
        out.split("\n").forEach(function(line) {
            var m = line.match(/^\d+:\s+(\S+):/);
            if (!m) return;
            var nic = m[1];
            if (nic === "lo" || /^(docker|br-|veth|tun|tap|wl|virbr)/.test(nic)) return;
            add(nic, nic);
        });
    } catch (_) {}
    if (current && current !== "auto" && ![].some.call(sel.options, function(o) { return o.value === current; }))
        add(current, current + " (from config)");
    sel.value = current || "auto";
}

// ── Audio card discovery ───────────────────────────────────────────────────────
function parseCards(output, filterFn) {
    var seen = {};
    var cards = [];
    (output || "").split("\n").forEach(function(line) {
        // Groups: 1=num, 2=alsaId (short stable ID), 3=longName, 4=devNum, 5=devName
        var m = line.match(/^card\s+(\d+):\s+(\S+)\s+\[([^\]]+)\],\s+device\s+(\d+):\s+([^\[]+)/i);
        if (!m) return;
        var num = m[1], alsaId = m[2], cardName = m[3].trim(), devName = m[5].trim();
        if (seen[num]) return;
        if (/Loopback/i.test(cardName)) return;
        if (filterFn && filterFn(cardName, devName)) return;
        seen[num] = true;
        // Use stable ALSA card ID as value; label shows number + device name for clarity
        cards.push({ num: num, alsaId: alsaId, label: num + " \u2014 " + devName + " [" + alsaId + "]" });
    });
    return cards;
}

async function populateAudio(currentIn, currentOut, currentIn2, currentOut2) {
    var selIn   = $("cfg-audio-in");
    var selOut  = $("cfg-audio-out");
    var selIn2  = $("cfg-audio-in2");
    var selOut2 = $("cfg-audio-out2");
    selIn.innerHTML  = "";
    selOut.innerHTML = "";
    selIn2.innerHTML  = '<option value="none">None — not used</option>';
    selOut2.innerHTML = '<option value="none">None — not used</option>';
    var playOut = "";
    var recOut  = "";
    try {
        playOut = await sp(["aplay",   "-l"]);
    } catch (_) {}
    try {
        recOut  = await sp(["arecord", "-l"]);
    } catch (_) {}

    var hdmiFilter = function(cardName, devName) {
        return /HDMI|DisplayPort/i.test(devName) && !/Analog/i.test(devName);
    };
    var captureCards  = parseCards(recOut,  hdmiFilter);
    var playbackCards = parseCards(playOut, hdmiFilter);

    captureCards.forEach(function(c) {
        selIn.add(new Option(c.label, c.alsaId, false, c.alsaId === currentIn || c.num === currentIn));
        selIn2.add(new Option(c.label, c.alsaId, false, c.alsaId === currentIn2 || c.num === currentIn2));
    });
    playbackCards.forEach(function(c) {
        selOut.add(new Option(c.label, c.alsaId, false, c.alsaId === currentOut || c.num === currentOut));
        selOut2.add(new Option(c.label, c.alsaId, false, c.alsaId === currentOut2 || c.num === currentOut2));
    });

    if (!selIn.options.length)  selIn.add(new Option("0 (default)", "0"));
    if (!selOut.options.length) selOut.add(new Option("0 (default)", "0"));

    if (currentIn  && ![].some.call(selIn.options,  function(o) { return o.value === currentIn;  }))
        selIn.add(new Option(currentIn  + " (from config)", currentIn));
    if (currentOut && ![].some.call(selOut.options, function(o) { return o.value === currentOut; }))
        selOut.add(new Option(currentOut + " (from config)", currentOut));
    if (currentIn2 && currentIn2 !== "none" && ![].some.call(selIn2.options, function(o) { return o.value === currentIn2; }))
        selIn2.add(new Option(currentIn2 + " (from config)", currentIn2));
    if (currentOut2 && currentOut2 !== "none" && ![].some.call(selOut2.options, function(o) { return o.value === currentOut2; }))
        selOut2.add(new Option(currentOut2 + " (from config)", currentOut2));

    selIn.value   = currentIn   || (selIn.options[0]   && selIn.options[0].value)   || "0";
    selOut.value  = currentOut  || (selOut.options[0]  && selOut.options[0].value)  || "0";
    selIn2.value  = currentIn2  || "none";
    selOut2.value = currentOut2 || "none";
}

// ── Audio device info panel ────────────────────────────────────────────────────
async function refreshAudioDevices() {
    var el = $("audio-devices-content");
    el.innerHTML = "<span class='loading-text'>Scanning audio hardware…</span>";
    try {
        var play = await sp(["aplay",   "-l"]).catch(function() { return ""; });
        var rec  = await sp(["arecord", "-l"]).catch(function() { return ""; });

        var cardMap = {};
        function parseLine(line, type) {
            var m = line.match(/^card\s+(\d+):\s+\S+\s+\[([^\]]+)\],\s+device\s+(\d+):\s+([^\[]+)/i);
            if (!m) return;
            var num = m[1], codecName = m[2].trim(), devName = m[4].trim();
            if (!cardMap[num]) cardMap[num] = { num: num, codecName: codecName, playbackDevices: [], captureDevices: [] };
            if (type === "playback") cardMap[num].playbackDevices.push(devName);
            else                     cardMap[num].captureDevices.push(devName);
        }
        play.split("\n").forEach(function(l) { parseLine(l, "playback"); });
        rec.split("\n").forEach(function(l)  { parseLine(l, "capture");  });

        var keys = Object.keys(cardMap);
        if (!keys.length) {
            el.innerHTML = "<em>No audio devices found.</em>";
            return;
        }
        var html = "";
        keys.sort().forEach(function(num) {
            var c = cardMap[num];
            var isLoopback = /Loopback/i.test(c.codecName);
            var dimClass   = isLoopback ? " audio-card-dimmed" : "";
            html += '<div class="audio-card-entry' + dimClass + '">';
            html += '<div class="audio-card-header">';
            html += '<span class="audio-card-num">Card ' + num + '</span>';
            html += '<span class="audio-card-codec">' + c.codecName + '</span>';
            html += '</div>';
            if (isLoopback) {
                html += '<div class="audio-card-devices">(software loopback \u2014 not selectable)</div>';
            } else {
                html += '<div class="audio-card-devices">';
                c.captureDevices.forEach(function(d) {
                    var hdmi = /HDMI|DisplayPort/i.test(d) && !/Analog/i.test(d);
                    html += '<span class="audio-cap-badge">\uD83C\uDF99\uFE0F Capture</span> ' + d;
                    if (hdmi) html += ' <em>(HDMI \u2014 not selectable)</em>';
                    html += ' &nbsp;';
                });
                c.playbackDevices.forEach(function(d) {
                    var hdmi = /HDMI|DisplayPort/i.test(d) && !/Analog/i.test(d);
                    html += '<span class="audio-play-badge">\uD83D\uDD0A Playback</span> ' + d;
                    if (hdmi) html += ' <em>(HDMI \u2014 not selectable)</em>';
                    html += ' &nbsp;';
                });
                html += '</div>';
            }
            html += '</div>';
        });
        el.innerHTML = html;
    } catch (e) {
        el.innerHTML = "<em class='err'>Error: " + String(e) + "</em>";
    }
}

// ── Volume Control ─────────────────────────────────────────────────────────────

// Per-card volume state: { cardNum: { control, pct, db } }
var volumeState = {};

// Detect the primary playback volume control for a card.
// Returns { control, pct, db } or null.
async function detectCardVolume(cardNum) {
    var controls = ["Master", "Headphone", "PCM"];
    for (var i = 0; i < controls.length; i++) {
        var ctrl = controls[i];
        try {
            var out = await sp(["amixer", "-c", String(cardNum), "sget", ctrl]);
            // Must have playback volume and a percentage
            var m = out.match(/Playback\s+\d+\s+\[(\d+)%\]\s+\[([^\]]+dB)\]/);
            if (!m) continue;
            return { control: ctrl, pct: parseInt(m[1]), db: m[2] };
        } catch (_) {}
    }
    return null;
}

// Get card numbers currently in use by the audio selectors (deduped).
// NOTE: matching is done inside loadVolumes; this stub kept for reference.

async function loadVolumes() {
    var el = $("volume-sliders");
    el.innerHTML = "<span class='loading-text'>Reading mixer levels…</span>";

    // Build card num → { alsaId, codec } from aplay -l
    var cardMap = {};
    try {
        var aplayOut = await sp(["aplay", "-l"]);
        var seen = {};
        aplayOut.split("\n").forEach(function(line) {
            var m = line.match(/^card\s+(\d+):\s+(\S+)\s+\[([^\]]+)\]/i);
            if (!m || seen[m[1]]) return;
            seen[m[1]] = true;
            if (/Loopback/i.test(m[3])) return;
            cardMap[m[1]] = { alsaId: m[2], codec: m[3].trim() };
        });
    } catch (_) {}

    // Selector values are alsaId strings (e.g. "PCH", "G430") or card numbers
    var selValues = [
        $("cfg-audio-in").value,
        $("cfg-audio-out").value,
        $("cfg-audio-in2") ? $("cfg-audio-in2").value : "none",
        $("cfg-audio-out2") ? $("cfg-audio-out2").value : "none"
    ].filter(function(v) { return v && v !== "none"; });

    // Match by alsaId or numeric card number
    var usedNums = {};
    Object.keys(cardMap).forEach(function(num) {
        var info = cardMap[num];
        selValues.forEach(function(v) {
            if (v === info.alsaId || v === num) usedNums[num] = info.codec;
        });
    });

    // Fall back: show all non-loopback cards
    if (!Object.keys(usedNums).length) {
        Object.keys(cardMap).forEach(function(num) {
            usedNums[num] = cardMap[num].codec;
        });
    }

    // Probe each card for its primary volume control
    volumeState = {};
    var probes = Object.keys(usedNums).sort().map(function(num) {
        return detectCardVolume(num).then(function(info) {
            if (info) volumeState[num] = Object.assign({ codec: usedNums[num] }, info);
        });
    });
    await Promise.all(probes);

    renderVolumeSliders();
}

function renderVolumeSliders() {
    var el = $("volume-sliders");
    var keys = Object.keys(volumeState).sort();
    if (!keys.length) {
        el.innerHTML = "<span class='loading-text'>No controllable audio cards found.</span>";
        return;
    }
    var html = "";
    keys.forEach(function(num) {
        var s = volumeState[num];
        html += '<div class="vol-row">';
        html += '<span class="vol-label" title="Card ' + num + ': ' + s.codec + ' (' + s.control + ')">'
              + s.codec + '</span>';
        html += '<input class="vol-slider" type="range" min="0" max="100" value="' + s.pct + '" '
              + 'data-card="' + num + '" data-control="' + s.control + '">';
        html += '<span class="vol-pct" id="vol-pct-' + num + '">' + s.pct + '%</span>';
        html += '<span class="vol-db"  id="vol-db-'  + num + '">' + s.db  + '</span>';
        html += '</div>';
    });
    el.innerHTML = html;

    // Wire up sliders
    el.querySelectorAll(".vol-slider").forEach(function(slider) {
        slider.addEventListener("input", function() {
            var num = this.dataset.card;
            var pct = this.value;
            $("vol-pct-" + num).textContent = pct + "%";
        });
        slider.addEventListener("change", function() {
            var num = this.dataset.card;
            var ctrl = this.dataset.control;
            var pct = this.value;
            setCardVolume(num, ctrl, pct);
        });
    });
}

async function setCardVolume(cardNum, control, pct) {
    try {
        var out = await sp(["amixer", "-c", String(cardNum), "sset", control, pct + "%"]);
        // Parse new dB from output
        var m = out.match(/\[(\d+)%\]\s+\[([^\]]+dB)\]/);
        if (m) {
            var dbEl = $("vol-db-" + cardNum);
            var pctEl = $("vol-pct-" + cardNum);
            if (dbEl) dbEl.textContent = m[2];
            if (pctEl) pctEl.textContent = m[1] + "%";
            if (volumeState[cardNum]) {
                volumeState[cardNum].pct = parseInt(m[1]);
                volumeState[cardNum].db  = m[2];
            }
        }
        await spUser("sudo alsactl store");
    } catch (e) {
        toast("Volume error: " + String(e), "error");
    }
}

async function normalizeAllVolumes() {
    var keys = Object.keys(volumeState).sort();
    for (var i = 0; i < keys.length; i++) {
        var num = keys[i];
        var ctrl = volumeState[num].control;
        var slider = document.querySelector('.vol-slider[data-card="' + num + '"]');
        if (slider) slider.value = "100";
        if ($("vol-pct-" + num)) $("vol-pct-" + num).textContent = "100%";
        await setCardVolume(num, ctrl, "100");
    }
    toast("All volumes set to 100%", "success");
}


function deriveDeviceId(baseId, offset) {
    // Increment the last 4 hex chars of a 16-char DEVICE_ID hex string
    var suffix = parseInt((baseId || "0").slice(-4), 16) + offset;
    return (baseId || "000000000000").slice(0, -4) + suffix.toString(16).padStart(4, "0");
}

// ── Internet Radio (iradio-bridge) ALSA setup ──────────────────────────────────
// Mirrors ensureAuxSetup but writes pcm.inferno_iradio_N blocks (slots 1–4)
// and a systemd user service unit for iradio-bridge.
const IRADIO_BRIDGE_BIN   = "/var/home/core/bin/iradio-bridge";
const IRADIO_CONFIG_DIR   = "/var/home/core/.config/iradio";
const IRADIO_CONFIG_PATH  = "/var/home/core/.config/iradio/config.toml";
const IRADIO_SVC_PATH     = "/var/home/core/.config/systemd/user/iradio-bridge.service";
const IRADIO_ALT_PORT_BASE= 6100;
const IRADIO_PID_BASE     = 10; // slots 1..4 → PIDs 10..13

async function ensureIradioSetup(danteName, numChannels) {
    numChannels = numChannels || 2; // default 2 stereo pairs
    var asoundText = await cockpit.file(ASOUNDRC).read() || "";

    var bindIpMatch   = asoundText.match(/BIND_IP\s+(\S+)/);
    var deviceIdMatch = asoundText.match(/DEVICE_ID\s+([0-9a-f]+)/i);
    var clockMatch    = asoundText.match(/CLOCK_PATH\s+(\S+)/);
    var pluginMatch   = asoundText.match(/lib\s+"([^"]+)"/);

    var bindIp     = bindIpMatch   ? bindIpMatch[1]   : "127.0.0.1";
    var baseId     = deviceIdMatch ? deviceIdMatch[1]  : "000000000000000";
    var clockPath  = clockMatch    ? clockMatch[1]     : "/tmp/ptp-usrvclock";
    var pluginPath = pluginMatch   ? pluginMatch[1]    : "/usr/lib64/alsa-lib/libasound_module_pcm_inferno.so";

    // Always regenerate iradio ALSA blocks so channel count changes take effect.
    // Strip old iradio blocks then append fresh ones.
    var stripped = asoundText.replace(/\n?# iradio-bridge Dante TX slot \d+[\s\S]*?^\}\n?/gm, "").trimEnd();
    var blocks = "\n";
    for (var slot = 1; slot <= numChannels; slot++) {
        var pid     = IRADIO_PID_BASE + (slot - 1);
        var altPort = IRADIO_ALT_PORT_BASE + (slot - 1) * 20;
        var devId   = deriveDeviceId(baseId, IRADIO_PID_BASE + (slot - 1));
        var name    = (danteName || "Inferno") + "-ir" + slot;
        blocks +=
            "# iradio-bridge Dante TX slot " + slot + "\n" +
            "pcm.inferno_iradio_" + slot + " {\n" +
            "    type inferno\n" +
            "    lib \"" + pluginPath + "\"\n" +
            "    NAME \"" + name + "\"\n" +
            "    BIND_IP " + bindIp + "\n" +
            "    SAMPLE_RATE 48000\n" +
            "    PROCESS_ID " + pid + "\n" +
            "    ALT_PORT " + altPort + "\n" +
            "    RX_CHANNELS 0\n" +
            "    TX_CHANNELS 2\n" +
            "    TX_LATENCY_NS 10000000\n" +
            "    RX_LATENCY_NS 10000000\n" +
            "    CLOCK_PATH " + clockPath + "\n" +
            "    DEVICE_ID " + devId + "\n" +
            "    hint { show off description \"Inferno iradio slot " + slot + " TX\" }\n" +
            "}\n\n";
    }
    await cockpit.file(ASOUNDRC).replace(stripped + "\n" + blocks);

    // Always write config directory + config.toml (update max_players each time)
    await spUser("mkdir -p " + IRADIO_CONFIG_DIR);
    var toml =
        "# iradio-bridge configuration — auto-generated by cockpit-inferno\n" +
        "port = 8765\n" +
        "max_players = " + numChannels + "\n" +
        "favourites_path = \"/var/home/core/.local/share/iradio/favourites.json\"\n\n" +
        "[auth]\nenabled = false\nusername = \"\"\npassword = \"\"\n\n" +
        "[alsa]\nsetup_alsa = false\n" +
        "asoundrc_path = \"/var/home/core/.asoundrc\"\n" +
        "sample_rate = 48000\nbuffer_frames = 4096\n\n" +
        "[radiobrowser]\napi_url = \"\"\nrequest_timeout_secs = 10\n";
    await cockpit.file(IRADIO_CONFIG_PATH).replace(toml);

    // Write systemd user service unit (only once — it doesn't change)
    var unitExists = await cockpit.file(IRADIO_SVC_PATH).read().catch(function() { return null; });
    if (!unitExists) {
        var unit =
            "[Unit]\n" +
            "Description=Inferno Internet Radio Bridge\n" +
            "After=network-online.target\n" +
            "Wants=network-online.target\n\n" +
            "[Service]\n" +
            "Type=simple\n" +
            "ExecStart=" + IRADIO_BRIDGE_BIN + " --config " + IRADIO_CONFIG_PATH + "\n" +
            "Restart=on-failure\nRestartSec=5\n" +
            "Environment=RUST_LOG=info\n";
        // No [Install]/WantedBy — cockpit-inferno manages start/stop explicitly
        await cockpit.file(IRADIO_SVC_PATH).replace(unit);
    }
}

async function ensureAuxSetup(cardIn, cardIn2, cardOut, cardOut2, txCh, rxCh, danteName) {
    var asoundText = await cockpit.file(ASOUNDRC).read() || "";
    var needsAlsa  = !asoundText.includes("pcm.inferno_aux_tx");

    var bindIpMatch    = asoundText.match(/BIND_IP\s+(\S+)/);
    var deviceIdMatch  = asoundText.match(/DEVICE_ID\s+([0-9a-f]+)/i);
    var pluginMatch    = asoundText.match(/lib\s+"([^"]+)"/);

    var bindIp     = bindIpMatch   ? bindIpMatch[1]   : "127.0.0.1";
    var baseId     = deviceIdMatch ? deviceIdMatch[1]  : "000000000000000";
    var pluginPath = pluginMatch   ? pluginMatch[1]    : "/usr/lib64/alsa-lib/libasound_module_pcm_inferno.so";
    var txId       = deriveDeviceId(baseId, 1);
    var rxId       = deriveDeviceId(baseId, 2);
    var txName     = (danteName || "Inferno") + "-TX";
    var rxName     = (danteName || "Inferno") + "-RX";

    var useMultiIn  = cardIn2  && cardIn2  !== "none" && txCh >= 4;
    var useMultiOut = cardOut2 && cardOut2 !== "none" && rxCh >= 4;

    // Helper to build ALSA stable hw string
    function hwStr(c) { return /^\d+$/.test(c) ? c + ",0" : "CARD=" + c + ",DEV=0"; }

    function multiBlock(name, card1, card2, ch1, ch2) {
        var lines = [
            "pcm." + name + " {",
            "    type multi",
            "    slaves {",
            "        a { pcm \"plughw:" + hwStr(card1) + "\" channels " + ch1 + " }",
            "        b { pcm \"plughw:" + hwStr(card2) + "\" channels " + ch2 + " }",
            "    }",
            "    bindings {",
        ];
        for (var i = 0; i < ch1; i++) lines.push("        " + i + " { slave a channel " + i + " }");
        for (var j = 0; j < ch2; j++) lines.push("        " + (ch1 + j) + " { slave b channel " + j + " }");
        lines.push("    }");
        lines.push("}");
        return lines.join("\n");
    }

    if (needsAlsa) {
        var auxBlock = [
            "",
            "# AUX TX: analog input \u2192 Dante transmitter",
            "pcm.inferno_aux_tx {",
            "    type inferno",
            '    NAME "' + txName + '"',
            "    BIND_IP " + bindIp,
            "    SAMPLE_RATE 48000",
            "    PROCESS_ID 2",
            "    ALT_PORT 6004",
            "    RX_CHANNELS 0",
            "    TX_CHANNELS " + txCh,
            "    TX_LATENCY_NS 10000000",
            "    RX_LATENCY_NS 10000000",
            "    CLOCK_PATH /tmp/ptp-usrvclock",
            "    DEVICE_ID " + txId,
            "    hint { show off description \"Inferno AUX TX: analog in to Dante\" }",
            "}",
            "",
            "# Format bridge: S32_LE wrapper for aux TX input",
            "pcm.aux_tx_in {",
            "    type plug",
            "    slave { pcm \"inferno_aux_tx\" format S32_LE rate 48000 }",
            "}",
            "",
            "# AUX RX: Dante receiver \u2192 analog output",
            "pcm.inferno_aux_rx {",
            "    type inferno",
            '    NAME "' + rxName + '"',
            "    BIND_IP " + bindIp,
            "    SAMPLE_RATE 48000",
            "    PROCESS_ID 3",
            "    ALT_PORT 6008",
            "    RX_CHANNELS " + rxCh,
            "    TX_CHANNELS 0",
            "    TX_LATENCY_NS 10000000",
            "    RX_LATENCY_NS 10000000",
            "    CLOCK_PATH /tmp/ptp-usrvclock",
            "    DEVICE_ID " + rxId,
            "    hint { show off description \"Inferno AUX RX: Dante to analog out\" }",
            "}",
            "",
            "# Format bridge: S32_LE wrapper for aux RX output",
            "pcm.aux_rx_out {",
            "    type plug",
            "    slave { pcm \"inferno_aux_rx\" format S32_LE rate 48000 }",
            "}",
        ].join("\n");
        if (useMultiIn)  auxBlock += "\n\n# Multi-card capture for TX\n" + multiBlock("inferno_aux_multi_in",  cardIn,  cardIn2,  2, 2);
        if (useMultiOut) auxBlock += "\n\n# Multi-card playback for RX\n" + multiBlock("inferno_aux_multi_out", cardOut, cardOut2, 2, 2);
        // pcm_type.inferno lib must be at top — only add if missing
        var prefix = asoundText.includes("pcm_type.inferno") ? "" :
            "pcm_type.inferno {\n    lib \"" + pluginPath + "\"\n}\n";
        await cockpit.file(ASOUNDRC).replace(prefix + asoundText + auxBlock + "\n");
    } else {
        // Aux blocks already exist — update TX/RX channel counts in place with scoped sed
        await spUser("sed -i '/pcm\\.inferno_aux_tx/,/^}/s/TX_CHANNELS.*/TX_CHANNELS " + txCh + "/' " + ASOUNDRC);
        await spUser("sed -i '/pcm\\.inferno_aux_rx/,/^}/s/RX_CHANNELS.*/RX_CHANNELS " + rxCh + "/' " + ASOUNDRC);

        // Multi blocks: remove stale ones, rewrite if needed
        await spUser("sed -i '/^# Multi-card/,/^}/d' " + ASOUNDRC);
        if (useMultiIn || useMultiOut) {
            var multiAppend = "";
            if (useMultiIn)  multiAppend += "\n\n# Multi-card capture for TX\n" + multiBlock("inferno_aux_multi_in",  cardIn,  cardIn2,  2, 2);
            if (useMultiOut) multiAppend += "\n\n# Multi-card playback for RX\n" + multiBlock("inferno_aux_multi_out", cardOut, cardOut2, 2, 2);
            var current = await cockpit.file(ASOUNDRC).read() || "";
            await cockpit.file(ASOUNDRC).replace(current.trimEnd() + multiAppend + "\n");
        }
    }

    // Always write/update service files — ensures card change in UI always takes effect.
    // Uses stable ALSA card ID (plughw:CARD=PCH,DEV=0) so card number shifts on reboot
    // (e.g. when adding a USB soundcard) don't break the service.
    var svcDir  = USER_HOME + "/.config/systemd/user";
    var txSvc   = svcDir + "/inferno-aux-tx.service";
    var rxSvc   = svcDir + "/inferno-aux-rx.service";
    var cardInArg   = /^\d+$/.test(cardIn)   ? cardIn   : "CARD=" + cardIn;
    var cardOutArg  = /^\d+$/.test(cardOut)  ? cardOut  : "CARD=" + cardOut;
    // TX: use multi_in PCM when two input cards, else direct plughw
    var txCapture = useMultiIn ? "inferno_aux_multi_in" : ("plughw:" + cardInArg + ",0");
    // RX: use multi_out PCM when two output cards, else direct plughw
    var rxPlayback = useMultiOut ? "inferno_aux_multi_out" : ("plughw:" + cardOutArg + ",0");

    await cockpit.file(txSvc).replace([
        "[Unit]",
        "Description=Inferno AUX TX Bridge \u2014 analog in to Dante",
        "After=statime-inferno.service default.target",
        "",
        "[Service]",
        "ExecStart=/usr/bin/alsaloop -C " + txCapture + " -P inferno_aux_tx -r 48000 -f S32_LE -c " + txCh + " -t 10000",
        "Restart=on-failure",
        "RestartSec=3",
        "",
        "[Install]",
        "WantedBy=default.target",
    ].join("\n") + "\n");

    await cockpit.file(rxSvc).replace([
        "[Unit]",
        "Description=Inferno AUX RX Bridge \u2014 Dante to analog out",
        "After=statime-inferno.service default.target",
        "",
        "[Service]",
        "ExecStart=/usr/bin/alsaloop -C inferno_aux_rx -P " + rxPlayback + " -r 48000 -f S32_LE -c " + rxCh + " -t 10000",
        "Restart=on-failure",
        "RestartSec=3",
        "",
        "[Install]",
        "WantedBy=default.target",
    ].join("\n") + "\n");

    return true; // always trigger daemon-reload so updated service files take effect
}

// ── Save config ────────────────────────────────────────────────────────────────
async function saveConfig() {
    // F-2: Show diff modal before applying
    var confirmed = await showConfigDiff();
    if (!confirmed) return;

    var btn   = $("btn-save");
    var label = $("save-label");
    btn.disabled = true;
    label.innerHTML = '<span class="spinner"></span> Applying\u2026';

    var newSpotifyName = $("cfg-spotify-name").value.trim();
    var newDanteName   = $("cfg-dante-name").value.trim();
    var oldMode        = currentMode;
    var newMode        = $("cfg-mode").value;
    var modeChanged    = newMode !== oldMode;

    try {
        // Write /etc/inferno.conf via sudo tee
        var newConf = Object.assign({}, currentConf, {
            INFERNO_MODE:           newMode,
            INFERNO_SPOTIFY_NAME:   newSpotifyName,
            INFERNO_DANTE_NAME:     newDanteName,
            INFERNO_NIC:            $("cfg-nic").value,
            INFERNO_AUDIO_CARD_IN:  $("cfg-audio-in").value,
            INFERNO_AUDIO_CARD_IN2: $("cfg-audio-in2").value  || "none",
            INFERNO_AUDIO_CARD_OUT: $("cfg-audio-out").value,
            INFERNO_AUDIO_CARD_OUT2:$("cfg-audio-out2").value || "none",
            INFERNO_TX_CHANNELS:    $("cfg-tx-channels").value,
            INFERNO_RX_CHANNELS:    $("cfg-rx-channels").value,
            INFERNO_LOOP_LATENCY:   $("cfg-loop-latency").value,
        });
        await writeFileAsSudo(CONF, buildConfText(newConf));
        currentConf = newConf;
        currentMode = newMode;

        var msgs = [];

        // Patch name files if changed
        if (newSpotifyName) {
            await spUser("sed -i 's/--name \"[^\"]*\"/--name \"" + newSpotifyName + "\"/' " + LIBRESPOT_SVC);
            msgs.push("Spotify → <b>" + newSpotifyName + "</b>");
        }
        // Patch librespot bitrate + normalisation
        var newBitrate = $("cfg-librespot-bitrate").value;
        var newNorm    = $("cfg-librespot-normalize").value;
        if (newBitrate) {
            // Replace existing --bitrate flag, or append to ExecStart if absent
            await spUser(
                "grep -q -- '--bitrate' " + LIBRESPOT_SVC + " 2>/dev/null" +
                " && sed -i 's/--bitrate [0-9]*/--bitrate " + newBitrate + "/' " + LIBRESPOT_SVC +
                " || sed -i '/^ExecStart/s/$/ --bitrate " + newBitrate + "/' " + LIBRESPOT_SVC
            );
        }
        if (newDanteName) {
            // Patch NAME only inside each named block to avoid clobbering aux -TX/-RX suffixes
            await spUser("sed -i '/pcm\\.inferno_spotify/,/^}/s/NAME \"[^\"]*\"/NAME \"" + newDanteName + "\"/' " + ASOUNDRC);
            await spUser("sed -i '/pcm\\.inferno_aux_tx/,/^}/s/NAME \"[^\"]*\"/NAME \"" + newDanteName + "-TX\"/' " + ASOUNDRC);
            await spUser("sed -i '/pcm\\.inferno_aux_rx/,/^}/s/NAME \"[^\"]*\"/NAME \"" + newDanteName + "-RX\"/' " + ASOUNDRC);
            msgs.push("Dante TX → <b>" + newDanteName + "</b>");
        }

        await spUser("systemctl --user daemon-reload");

        // For aux modes: ensure ALSA PCM defs + always rewrite service files with current card/channels
        if (newMode === "aux-in" || newMode === "aux-out" || newMode === "aux-bidir") {
            var cardIn    = $("cfg-audio-in").value   || "0";
            var cardIn2   = $("cfg-audio-in2").value  || "none";
            var cardOut   = $("cfg-audio-out").value  || "0";
            var cardOut2  = $("cfg-audio-out2").value || "none";
            var txCh      = parseInt($("cfg-tx-channels").value) || 2;
            var rxCh      = parseInt($("cfg-rx-channels").value) || 2;
            var freshAlsa = await ensureAuxSetup(cardIn, cardIn2, cardOut, cardOut2, txCh, rxCh, newDanteName);
            if (freshAlsa) {
                await spUser("systemctl --user daemon-reload");
            }
        }

        // For iradio mode: ensure iradio-bridge is installed and configured
        if (newMode === "iradio") {
            var numCh = parseInt($("cfg-iradio-channels") ? $("cfg-iradio-channels").value : "2", 10) || 2;
            await ensureIradioSetup(newDanteName, numCh);
            await spUser("systemctl --user daemon-reload");
        }

        var targetSvcs = modeToSvcs(newMode);
        var stopSvcs   = SPOTIFY_SVCS.concat(ALL_AUX_SVCS).concat(IRADIO_SVCS)
                           .filter(function(s) { return !targetSvcs.includes(s); })
                           .join(" ");
        var startSvcs  = targetSvcs.join(" ");

        if (stopSvcs)  await spUser("systemctl --user stop "    + stopSvcs  + " 2>/dev/null; true");
        if (startSvcs) await spUser("systemctl --user restart " + startSvcs + " 2>/dev/null; true");

        var modeLabels = {
            "spotify":   "Spotify Connect → Dante TX",
            "aux-in":    "Analog In → Dante TX",
            "aux-out":   "Dante RX → Analog Out",
            "aux-bidir": "Analog In + Out",
            "iradio":    "Internet Radio → Dante TX",
        };
        if (modeChanged) msgs.push("Mode → <b>" + (modeLabels[newMode] || newMode) + "</b>");

        toast((msgs.length ? msgs.join(", ") + ". " : "Configuration saved. ") + "Services updated.", "success", 8000);

        isDirty = false;
        $("cfg-dirty-badge").classList.add("hidden");
        _savedConfSnapshot = buildFormSnapshot();
        setTimeout(refreshAll, 1500);

    } catch (e) {
        toast("Save failed: " + ((e && e.message) || String(e)), "error", 0);
    } finally {
        btn.disabled = false;
        label.textContent = "\ud83d\udcbe  Save & Apply";
    }
}

// ── Service status ─────────────────────────────────────────────────────────────
function modeToSvcs(mode) {
    if (mode === "aux-in")    return AUX_IN_SVCS;
    if (mode === "aux-out")   return AUX_OUT_SVCS;
    if (mode === "aux-bidir") return AUX_BIDIR_SVCS;
    if (mode === "aux")       return AUX_BIDIR_SVCS; // legacy value
    if (mode === "iradio")    return IRADIO_SVCS;
    return SPOTIFY_SVCS;
}

function activeSvcs() {
    return SYSTEM_SVCS.concat(modeToSvcs(currentMode));
}

async function getSvcStatus(svc) {
    var isSystem = SYSTEM_SVCS.includes(svc);
    try {
        var r = isSystem
            ? await sp(["systemctl", "is-active", svc])
            : await spUser("systemctl --user is-active " + svc);
        return r.trim();
    } catch (e) {
        var msg = ((e && e.message) || "").trim().split("\n")[0];
        return msg || "unknown";
    }
}

async function getSvcMeta(svc) {
    // Returns { uptime, restarts, lastError } — best-effort, empty strings on failure
    var isSystem = SYSTEM_SVCS.includes(svc);
    var props = "ActiveEnterTimestamp,NRestarts,Result";
    try {
        var out = isSystem
            ? await sp(["systemctl", "show", svc, "--property=" + props, "--no-pager"])
            : await spUser("systemctl --user show " + svc + " --property=" + props + " --no-pager");
        var p = {};
        (out || "").split("\n").forEach(function(l) {
            var i = l.indexOf("=");
            if (i > 0) p[l.slice(0,i)] = l.slice(i+1).trim();
        });
        var uptime = "";
        if (p.ActiveEnterTimestamp && p.ActiveEnterTimestamp !== "n/a") {
            var ts = new Date(p.ActiveEnterTimestamp);
            if (!isNaN(ts)) {
                var sec = Math.floor((Date.now() - ts) / 1000);
                if (sec < 60)   uptime = sec + "s";
                else if (sec < 3600) uptime = Math.floor(sec/60) + "m";
                else uptime = Math.floor(sec/3600) + "h " + Math.floor((sec%3600)/60) + "m";
            }
        }
        var restarts   = parseInt(p.NRestarts) || 0;
        var lastError  = (p.Result && p.Result !== "success") ? p.Result : "";
        return { uptime: uptime, restarts: restarts, lastError: lastError };
    } catch (_) {
        return { uptime: "", restarts: 0, lastError: "" };
    }
}

async function refreshServices() {
    var svcs     = activeSvcs();
    var statuses = await Promise.all(svcs.map(getSvcStatus));
    var metas    = await Promise.all(svcs.map(getSvcMeta));
    var grid     = $("svc-grid");
    grid.innerHTML = "";

    svcs.forEach(function(svc, i) {
        var state    = statuses[i] || "unknown";
        var meta     = metas[i]    || {};
        var cls      = ["active","inactive","failed"].includes(state) ? state : "unknown";
        var info     = SVC_LABELS[svc] || { label: svc, desc: "" };
        var isSystem = SYSTEM_SVCS.includes(svc);

        var card = document.createElement("div");
        card.className = "svc-card " + cls;

        var top = document.createElement("div");
        var nameEl = document.createElement("div");
        nameEl.className = "svc-name";
        nameEl.textContent = info.label;
        if (isSystem) {
            var tag = document.createElement("span");
            tag.className = "svc-system-tag";
            tag.textContent = " (system)";
            nameEl.appendChild(tag);
        }
        var descEl = document.createElement("div");
        descEl.className = "svc-type";
        descEl.textContent = info.desc;
        top.appendChild(nameEl);
        top.appendChild(descEl);
        card.appendChild(top);

        var statusEl = document.createElement("div");
        statusEl.className = "svc-status";
        var dot = document.createElement("span");
        dot.className = "status-dot " + cls;
        var stateEl = document.createElement("span");
        stateEl.textContent = state;
        statusEl.appendChild(dot);
        statusEl.appendChild(stateEl);
        card.appendChild(statusEl);

        // Uptime + restart count meta row
        var metaParts = [];
        if (meta.uptime && state === "active") metaParts.push("up " + meta.uptime);
        if (meta.restarts > 0) metaParts.push(meta.restarts + " restart" + (meta.restarts > 1 ? "s" : ""));
        if (metaParts.length) {
            var metaEl = document.createElement("div");
            metaEl.className = "svc-meta";
            if (meta.restarts >= 3) {
                metaEl.innerHTML = metaParts.map(function(p, idx) {
                    return idx === 1 ? '<span class="svc-restart-warn">' + p + '</span>' : p;
                }).join(" · ");
            } else {
                metaEl.textContent = metaParts.join(" · ");
            }
            card.appendChild(metaEl);
        }

        // Last error
        if (meta.lastError) {
            var errEl = document.createElement("div");
            errEl.className = "svc-last-error";
            errEl.textContent = "\u26A0 " + meta.lastError;
            errEl.title = meta.lastError;
            card.appendChild(errEl);
        }

        var actEl = document.createElement("div");
        actEl.className = "svc-actions";
        ["restart","start","stop"].forEach(function(cmd) {
            var b = document.createElement("button");
            b.className = "btn btn-secondary btn-sm";
            b.textContent = cmd.charAt(0).toUpperCase() + cmd.slice(1);
            b.onclick = function() { svcAction(svc, cmd, isSystem); };
            actEl.appendChild(b);
        });
        card.appendChild(actEl);

        grid.appendChild(card);
    });
}

async function svcAction(svc, cmd, isSystem) {
    var t = toast(cmd + " " + svc + "\u2026", "info", 0);
    try {
        if (isSystem) {
            await spSudo("systemctl " + cmd + " " + svc);
        } else {
            await spUser("systemctl --user " + cmd + " " + svc);
        }
        t.remove();
        toast(svc + ": " + cmd + " OK", "success");
        await refreshServices();
    } catch (e) {
        t.remove();
        toast(cmd + " " + svc + " failed: " + ((e && e.message) || String(e)), "error", 0);
    }
}

async function restartAll() {
    var t = toast("Restarting all Inferno services\u2026", "info", 0);
    try {
        for (var i = 0; i < SYSTEM_SVCS.length; i++) {
            await spSudo("systemctl restart " + SYSTEM_SVCS[i]).catch(function() {});
        }
        var userSvcs = currentMode === "spotify" ? SPOTIFY_SVCS : AUX_SVCS;
        await spUser("systemctl --user restart " + userSvcs.join(" "));
        t.remove();
        toast("All services restarted.", "success");
        await refreshServices();
    } catch (e) {
        t.remove();
        toast("Restart all failed: " + ((e && e.message) || String(e)), "error", 0);
    }
}

// ── System info ────────────────────────────────────────────────────────────────
function addRow(table, key, html, cls) {
    var tr = document.createElement("tr");
    var k  = document.createElement("td"); k.className = "info-key"; k.textContent = key;
    var v  = document.createElement("td"); if (cls) v.className = cls; v.innerHTML = html;
    tr.appendChild(k); tr.appendChild(v);
    table.appendChild(tr);
}
function code(t) { return "<code>" + t + "</code>"; }

async function refreshSystemInfo() {
    var table = $("info-table");
    table.innerHTML = "";

    try {
        var hn = (await sp(["hostname"])).trim();
        addRow(table, "Hostname", code(hn));
        $("hdr-hostname").textContent = hn;
    } catch (_) {}

    // Image version from /etc/os-release
    try {
        var osrel = await cockpit.file("/etc/os-release").read();
        var verMatch = (osrel || "").match(/^OSTREE_VERSION=(.+)$/m) ||
                       (osrel || "").match(/^IMAGE_VERSION=(.+)$/m) ||
                       (osrel || "").match(/^BUILD_ID=(.+)$/m);
        if (verMatch) {
            addRow(table, "Image version", code(verMatch[1].replace(/['"]/g, "")));
        } else {
            // fallback: bootc status (slower)
            try {
                var bs = await spSudo("bootc status --format json 2>/dev/null | python3 -c \"import sys,json; d=json.load(sys.stdin); print(d['status']['booted']['image']['image']['image'])\" 2>/dev/null");
                if (bs.trim()) addRow(table, "Image", code(bs.trim()));
            } catch (_) {}
        }
    } catch (_) {}

    var nic = currentConf.INFERNO_NIC || "eno1";
    try {
        var ip = (await sp(["bash", "-c", "ip -4 addr show " + nic + " 2>/dev/null | awk '/inet /{print $2}'"])).trim();
        addRow(table, "IP Address", code(ip));
        $("hdr-ip").textContent = ip;
    } catch (_) {}

    try {
        var mac = (await sp(["cat", "/sys/class/net/" + nic + "/address"])).trim();
        addRow(table, "MAC / NIC", code(mac) + " on " + code(nic));
    } catch (_) {}

    // Network RX/TX rate — sample twice 1 second apart
    try {
        function readNicStat(f) { return sp(["cat", "/sys/class/net/" + nic + "/statistics/" + f]).then(function(v){ return parseInt(v.trim()) || 0; }); }
        var rx0 = await readNicStat("rx_bytes");
        var tx0 = await readNicStat("tx_bytes");
        await new Promise(function(r){ setTimeout(r, 1000); });
        var rx1 = await readNicStat("rx_bytes");
        var tx1 = await readNicStat("tx_bytes");
        function fmtRate(bps) {
            if (bps > 1048576) return (bps/1048576).toFixed(1) + " MB/s";
            if (bps > 1024)    return (bps/1024).toFixed(0)    + " KB/s";
            return bps + " B/s";
        }
        addRow(table, "Net traffic", "↓ " + code(fmtRate(rx1 - rx0)) + " · ↑ " + code(fmtRate(tx1 - tx0)));
    } catch (_) {}

    // Memory
    try {
        var meminfo = await cockpit.file("/proc/meminfo").read();
        var mTotal = parseInt((meminfo.match(/MemTotal:\s+(\d+)/) || [])[1]) || 0;
        var mAvail = parseInt((meminfo.match(/MemAvailable:\s+(\d+)/) || [])[1]) || 0;
        var mUsed  = mTotal - mAvail;
        var mPct   = mTotal ? Math.round(mUsed / mTotal * 100) : 0;
        addRow(table, "Memory", code(Math.round(mUsed/1024) + " / " + Math.round(mTotal/1024) + " MB") + " (" + mPct + "% used)");
    } catch (_) {}

    // Disk — on bootc/OSTree /sysroot is the real disk; / is a composefs overlay
    try {
        var dfTargets = ["/sysroot", "/var", "/"];
        var dfShown   = false;
        for (var di = 0; di < dfTargets.length && !dfShown; di++) {
            try {
                var dfOut  = (await sp(["df", "-h", dfTargets[di]])).trim().split("\n");
                var dfLine = (dfOut[1] || "").split(/\s+/);
                if (dfLine.length >= 5 && dfLine[1] !== "8.3M" && dfLine[1] !== "0") {
                    addRow(table, "Disk (" + dfTargets[di] + ")", code(dfLine[2] + " used of " + dfLine[1]) + " (" + dfLine[4] + ")");
                    dfShown = true;
                }
            } catch (_) {}
        }
    } catch (_) {}

    // PTP offset (header pill only — full card handled by refreshPTP)
    try {
        var ptpLine = (await spSudo(
            "journalctl -u statime-inferno -n 30 --no-pager -o cat | grep -oE 'Estimated offset [0-9.+-]+ns' | tail -1"
        )).trim();
        if (ptpLine) {
            addRow(table, "PTP Offset", code(ptpLine), "text-success");
            $("hdr-ptp").textContent = "PTP " + ptpLine;
        } else {
            addRow(table, "PTP Offset", "no recent data", "text-muted");
            $("hdr-ptp").textContent = "PTP syncing\u2026";
        }
    } catch (_) {
        addRow(table, "PTP Offset", "no recent data", "text-muted");
        $("hdr-ptp").textContent = "PTP syncing\u2026";
    }

    // snd-aloop check with load button
    try {
        var loop = (await sp(["bash", "-c", "cat /proc/asound/cards | grep -i loopback | head -1"])).trim();
        if (loop) {
            addRow(table, "snd-aloop", code(loop));
        } else {
            var tr  = document.createElement("tr");
            var k   = document.createElement("td"); k.className = "info-key"; k.textContent = "snd-aloop";
            var v   = document.createElement("td"); v.className = "text-danger";
            var txt = document.createElement("span"); txt.textContent = "not loaded \u26a0 ";
            var btn = document.createElement("button");
            btn.className = "btn btn-secondary btn-sm"; btn.id = "btn-load-aloop";
            btn.textContent = "Load now";
            btn.addEventListener("click", loadAloop);
            v.appendChild(txt); v.appendChild(btn);
            tr.appendChild(k); tr.appendChild(v);
            table.appendChild(tr);
        }
    } catch (_) {}

    // Librespot active session indicator
    try {
        var lsState = await spUser("systemctl --user is-active librespot");
        if (lsState.trim() === "active") {
            try {
                var lsLog = await sp(["journalctl", "_SYSTEMD_USER_UNIT=librespot.service",
                    "-n", "20", "--no-pager", "--output=cat"]);
                var sessionMatch = lsLog.match(/Loading track|Playing|Paused/);
                var trackMatch   = lsLog.match(/Loading track "([^"]+)"/);
                if (trackMatch) {
                    addRow(table, "Spotify", "\uD83C\uDFB5 " + trackMatch[1], "text-success");
                } else if (sessionMatch) {
                    addRow(table, "Spotify", "\uD83D\uDD0A active session", "text-success");
                } else {
                    addRow(table, "Spotify", "ready, no active stream", "text-muted");
                }
            } catch (_) {}
        }
    } catch (_) {}

    try {
        var sentinel = await spSudo("test -f " + SENTINEL + " && echo present || echo absent");
        if ((sentinel || "").trim() === "present") {
            addRow(table, "Deploy sentinel", "\u2705 present");
        } else {
            addRow(table, "Deploy sentinel", "missing \u2014 binaries will refresh on next reboot (harmless)");
        }
    } catch (_) {
        addRow(table, "Deploy sentinel", "unknown");
    }
}

// ── Header mode badge ──────────────────────────────────────────────────────
function refreshHeader() {
    var badge = $("hdr-mode-badge");
    var mode  = currentMode || "spotify";
    badge.innerHTML = "";
    var span = document.createElement("span");
    span.className = "mode-badge " + mode;
    span.textContent = mode;
    badge.appendChild(span);
}

// ── snd-aloop one-click load ───────────────────────────────────────────────
async function loadAloop() {
    var t = toast("Loading snd-aloop\u2026", "info", 0);
    try {
        await spSudo("modprobe snd-aloop");
        t.remove();
        toast("snd-aloop loaded.", "success");
        await refreshSystemInfo();
    } catch (e) {
        t.remove();
        toast("modprobe failed: " + ((e && e.message) || String(e)), "error", 0);
    }
}

// ── PTP status card ────────────────────────────────────────────────────────
async function refreshPTP() {
    var badge   = $("ptp-state-badge");
    var content = $("ptp-content");
    content.innerHTML = "";

    try {
        var raw = await spSudo(
            "journalctl -u statime-inferno -n 80 --no-pager -o cat"
        );
        var lines = (raw || "").split("\n").filter(Boolean).reverse();

        // Determine lock state
        var state = "unknown";
        var grandmaster = "";
        var offsetNs = null;
        var offsetStr = "";

        for (var i = 0; i < lines.length; i++) {
            var l = lines[i];
            if (/locked/i.test(l) && state === "unknown")       state = "locked";
            else if (/synchroniz/i.test(l) && state === "unknown") state = "syncing";
            else if (/acquir/i.test(l) && state === "unknown")  state = "acquiring";
            var gm = l.match(/grandmaster[:\s]+([0-9a-fA-F:.-]+)/i);
            if (gm && !grandmaster) grandmaster = gm[1];
            var off = l.match(/Estimated offset ([0-9.+-]+)ns/);
            if (off && offsetNs === null) {
                offsetNs = parseFloat(off[1]);
                offsetStr = off[1] + " ns";
            }
            if (state !== "unknown" && grandmaster && offsetNs !== null) break;
        }
        if (state === "unknown") state = "acquiring";

        // Collect all recent offsets for sparkline
        var allOffsets = [];
        lines.forEach(function(l) {
            var m = l.match(/Estimated offset ([0-9.+-]+)ns/);
            if (m) allOffsets.push(parseFloat(m[1]));
        });
        allOffsets.reverse();
        if (allOffsets.length) {
            _ptpHistory = _ptpHistory.concat(allOffsets).slice(-30);
        }

        // Update badge
        badge.className = "ptp-state-badge ptp-" + (state === "locked" ? "locked" : state === "syncing" ? "syncing" : state === "acquiring" ? "syncing" : "lost");
        badge.textContent = state === "locked" ? "\uD83D\uDD12 Locked" : state === "syncing" ? "\u231B Syncing\u2026" : "\u26A0 Acquiring\u2026";

        // Offset quality
        var offsetClass = "good";
        if (offsetNs !== null) {
            var absOff = Math.abs(offsetNs);
            offsetClass = absOff < 1000 ? "good" : absOff < 50000 ? "warn" : "bad";
        }

        function ptpStat(label, value, cls) {
            var d = document.createElement("div"); d.className = "ptp-stat";
            var l = document.createElement("div"); l.className = "ptp-stat-label"; l.textContent = label;
            var v = document.createElement("div"); v.className = "ptp-stat-value" + (cls ? " " + cls : ""); v.textContent = value;
            d.appendChild(l); d.appendChild(v); content.appendChild(d);
        }

        ptpStat("State",       state.charAt(0).toUpperCase() + state.slice(1), state === "locked" ? "good" : "warn");
        ptpStat("Offset",      offsetStr || "—", offsetClass);
        ptpStat("Grandmaster", grandmaster || "discovering\u2026", "");

        // Update header pill
        if (offsetStr) $("hdr-ptp").textContent = "PTP " + offsetStr;

        // Draw sparkline
        drawSparkline(_ptpHistory);

    } catch (e) {
        badge.className = "ptp-state-badge ptp-lost";
        badge.textContent = "\u274C Error";
        content.innerHTML = '<span class="text-danger">' + ((e && e.message) || String(e)) + '</span>';
    }
}

function drawSparkline(pts) {
    var svg = $("ptp-sparkline");
    if (!svg || pts.length < 2) return;
    svg.innerHTML = "";
    var W = 300, H = 40, pad = 4;
    var absMax = Math.max.apply(null, pts.map(Math.abs));
    if (absMax === 0) absMax = 1;
    function x(i) { return pad + (i / (pts.length - 1)) * (W - 2*pad); }
    function y(v) { return pad + (1 - (v + absMax) / (2 * absMax)) * (H - 2*pad); }
    var zero = y(0);

    // Zero line
    var zl = document.createElementNS("http://www.w3.org/2000/svg", "line");
    zl.setAttribute("x1", pad); zl.setAttribute("x2", W - pad);
    zl.setAttribute("y1", zero); zl.setAttribute("y2", zero);
    zl.setAttribute("class", "sparkline-zero"); svg.appendChild(zl);

    // Area
    var apts = pts.map(function(v,i){ return x(i) + "," + y(v); });
    var area = [x(0) + "," + zero].concat(apts).concat([x(pts.length-1) + "," + zero]).join(" ");
    var polygon = document.createElementNS("http://www.w3.org/2000/svg", "polygon");
    polygon.setAttribute("points", area); polygon.setAttribute("class", "sparkline-area"); svg.appendChild(polygon);

    // Line
    var polyline = document.createElementNS("http://www.w3.org/2000/svg", "polyline");
    polyline.setAttribute("points", apts.join(" ")); polyline.setAttribute("class", "sparkline-line"); svg.appendChild(polyline);
}

// ── Health check panel ─────────────────────────────────────────────────────
var HC_CHECKS = [
    { id: "hc-snd-aloop",  name: "snd-aloop loaded",       fix: "loadAloop()" },
    { id: "hc-ptp",        name: "PTP clock locked",        fix: null },
    { id: "hc-bridge",     name: "inferno-bridge active",   fix: "svcAction('inferno-bridge','restart',false)" },
    { id: "hc-librespot",  name: "librespot active",        fix: "svcAction('librespot','restart',false)" },
    { id: "hc-statime",    name: "statime-inferno active",  fix: "svcAction('statime-inferno','restart',true)" },
    { id: "hc-disk",       name: "Disk < 80% used",         fix: null },
    { id: "hc-ip",         name: "NIC has IP address",      fix: null },
];

function hcRow(id, name, status, detail, fixFn) {
    var row = document.createElement("div");
    row.className = "hc-row " + status; row.id = id;
    var icon = document.createElement("span"); icon.className = "hc-icon";
    icon.textContent = status === "pass" ? "\u2705" : status === "fail" ? "\u274C" : status === "warn" ? "\u26A0\uFE0F" : "\u23F3";
    var nameEl = document.createElement("span"); nameEl.className = "hc-name"; nameEl.textContent = name;
    var detEl  = document.createElement("span"); detEl.className = "hc-detail"; detEl.textContent = detail;
    row.appendChild(icon); row.appendChild(nameEl); row.appendChild(detEl);
    if (fixFn && status === "fail") {
        var fix = document.createElement("span"); fix.className = "hc-fix"; fix.textContent = "Fix";
        fix.addEventListener("click", function() { eval(fixFn); }); // jshint ignore:line
        row.appendChild(fix);
    }
    return row;
}

async function runHealthCheck() {
    var btn = $("btn-health-check");
    btn.disabled = true; btn.textContent = "\u23F3 Checking\u2026";
    var results = $("hc-results");
    results.innerHTML = "";

    var pass = 0, fail = 0, warn = 0;

    async function check(name, fn, fixFn) {
        var placeholder = hcRow("", name, "running", "checking\u2026", null);
        results.appendChild(placeholder);
        var r;
        try { r = await fn(); } catch (e) { r = { status: "fail", detail: String(e) }; }
        placeholder.className = "hc-row " + r.status;
        placeholder.querySelector(".hc-icon").textContent = r.status === "pass" ? "\u2705" : r.status === "fail" ? "\u274C" : r.status === "warn" ? "\u26A0\uFE0F" : "\u23F3";
        placeholder.querySelector(".hc-detail").textContent = r.detail;
        if (r.status === "fail" && fixFn) {
            var fix = document.createElement("span"); fix.className = "hc-fix"; fix.textContent = "Fix";
            fix.addEventListener("click", function() { eval(fixFn); }); // jshint ignore:line
            placeholder.appendChild(fix);
        }
        if (r.status === "pass") pass++;
        else if (r.status === "fail") fail++;
        else if (r.status === "warn") warn++;
    }

    await check("snd-aloop loaded", async function() {
        var o = await sp(["bash", "-c", "cat /proc/asound/cards | grep -i loopback | head -1"]);
        return o.trim() ? { status: "pass", detail: o.trim() } : { status: "fail", detail: "not in /proc/asound/cards" };
    }, "loadAloop()");

    await check("PTP clock locked", async function() {
        var o = await spSudo("journalctl -u statime-inferno -n 40 --no-pager -o cat | grep -i locked | tail -1");
        return o.trim() ? { status: "pass", detail: "locked" } : { status: "warn", detail: "not yet locked (may be syncing)" };
    }, null);

    await check("inferno-bridge active", async function() {
        var o = await spUser("systemctl --user is-active inferno-bridge");
        var s = o.trim();
        return s === "active" ? { status: "pass", detail: "active" } : { status: "fail", detail: s };
    }, "svcAction('inferno-bridge','restart',false)");

    await check("librespot active", async function() {
        var o = await spUser("systemctl --user is-active librespot");
        var s = o.trim();
        return s === "active" ? { status: "pass", detail: "active" } : { status: "warn", detail: s + " (only needed in spotify mode)" };
    }, "svcAction('librespot','restart',false)");

    await check("statime-inferno active", async function() {
        var o = (await sp(["systemctl", "is-active", "statime-inferno"])).trim();
        return o === "active" ? { status: "pass", detail: "active" } : { status: "fail", detail: o };
    }, "svcAction('statime-inferno','restart',true)");

    await check("Disk < 80% used", async function() {
        var targets = ["/sysroot", "/var", "/"];
        for (var i = 0; i < targets.length; i++) {
            try {
                var df  = (await sp(["df", targets[i]])).trim().split("\n")[1].split(/\s+/);
                var pct = parseInt(df[4]) || 0;
                if (df[1] === "8368128" || df[1] === "0") continue; // skip composefs sentinel size
                return pct < 80
                    ? { status: "pass", detail: df[4] + " used on " + targets[i] }
                    : { status: (pct < 95 ? "warn" : "fail"), detail: df[4] + " used on " + targets[i] + " — low space" };
            } catch (_) {}
        }
        return { status: "warn", detail: "could not determine disk usage" };
    }, null);

    await check("NIC has IP address", async function() {
        var nic = currentConf.INFERNO_NIC || "eno1";
        var ip = (await sp(["bash", "-c", "ip -4 addr show " + nic + " 2>/dev/null | awk '/inet /{print $2}'"])).trim();
        return ip ? { status: "pass", detail: ip + " on " + nic } : { status: "fail", detail: "no IPv4 on " + nic };
    }, null);

    // Summary badge
    var summary = $("hc-summary");
    if (fail > 0) { summary.textContent = fail + " failing"; summary.className = "hc-summary has-fail"; }
    else if (warn > 0) { summary.textContent = warn + " warnings"; summary.className = "hc-summary has-warn"; }
    else { summary.textContent = "\u2705 All good"; summary.className = "hc-summary all-pass"; }

    btn.disabled = false; btn.textContent = "\u25B6 Run Checks";
}

// ── Dante device discovery ─────────────────────────────────────────────────
async function scanDanteDevices() {
    var btn     = $("btn-dante-scan");
    var content = $("dante-devices-content");
    btn.disabled = true; btn.textContent = "\u23F3 Scanning\u2026";
    content.innerHTML = '<span class="loading-text">Scanning for Dante devices via mDNS\u2026</span>';
    try {
        // avahi-browse for _netaudio-arc._tcp (Dante ARC/device-info)
        var raw = await sp(["avahi-browse", "-t", "-r", "-p", "_netaudio-arc._tcp"]);
        var lines = (raw || "").split("\n").filter(function(l){ return l.startsWith("="); });
        if (!lines.length) {
            content.innerHTML = '<span class="loading-text">No Dante devices found on network.</span>';
        } else {
            content.innerHTML = "";
            var seen = {};
            lines.forEach(function(line) {
                var parts = line.split(";");
                // = ; iface ; proto ; name ; type ; domain ; host ; proto ; ip ; port ; txt
                if (parts.length < 9) return;
                var name = parts[3] || "?";
                var ip   = parts[7] || "";
                var host = parts[6] || "";
                if (seen[name]) return;
                seen[name] = true;
                var row = document.createElement("div"); row.className = "dante-dev-row";
                var nameEl = document.createElement("span"); nameEl.className = "dante-dev-name"; nameEl.textContent = name;
                var ipEl   = document.createElement("span"); ipEl.className = "dante-dev-ip";   ipEl.textContent = ip;
                var hostEl = document.createElement("span"); hostEl.className = "dante-dev-type"; hostEl.textContent = host;
                row.appendChild(nameEl); row.appendChild(ipEl); row.appendChild(hostEl);
                content.appendChild(row);
            });
        }
    } catch (e) {
        content.innerHTML = '<span class="text-muted">avahi-browse not available or no devices found.</span>';
    }
    btn.disabled = false; btn.textContent = "\u21BB Scan";
}

// ── Mode signal-flow diagram ───────────────────────────────────────────────
function updateModeFlow() {
    var div  = $("mode-flow-diagram");
    var mode = $("cfg-mode").value;
    div.innerHTML = "";
    var flows = {
        "spotify":   [["Spotify", "source"], ["snd-aloop", "middle"], ["inferno-bridge", "middle"], ["Dante TX", "dest"]],
        "aux-in":    [["Analog In", "source"], ["snd-aloop", "middle"], ["inferno-aux-tx", "middle"], ["Dante TX", "dest"]],
        "aux-out":   [["Dante RX", "source"], ["inferno-aux-rx", "middle"], ["Analog Out", "dest"]],
        "aux-bidir": [["Analog In", "source"], ["Dante TX", "dest"], ["\u2194", "middle"], ["Dante RX", "source"], ["Analog Out", "dest"]],
        "iradio":    [["Internet Radio", "source"], ["iradio-bridge", "middle"], ["Dante TX", "dest"]],
    };
    var nodes = flows[mode] || [];
    nodes.forEach(function(n, i) {
        if (i > 0) {
            var arr = document.createElement("span");
            arr.className = "flow-arrow"; arr.textContent = " \u2192 ";
            div.appendChild(arr);
        }
        var nd = document.createElement("span"); nd.className = "flow-node " + n[1]; nd.textContent = n[0];
        div.appendChild(nd);
    });
}

// ── Journal ────────────────────────────────────────────────────────────────────
function colorizeLog(text, levelFilter) {
    return text.split("\n").map(function(line) {
        var esc = line.replace(/&/g,"&amp;").replace(/</g,"&lt;").replace(/>/g,"&gt;");
        var lo  = esc.toLowerCase();
        var isErr  = /\berr(or)?\b|failed|fatal/.test(lo);
        var isWarn = /\bwarn/.test(lo);
        var isOk   = /\bok\b|success|ready|running|active|started/.test(lo);
        if (levelFilter === "error" && !isErr)        return null;
        if (levelFilter === "warn"  && !isErr && !isWarn) return null;
        if (isErr)  return '<span class="log-err">'  + esc + "</span>";
        if (isWarn) return '<span class="log-warn">' + esc + "</span>";
        if (isOk)   return '<span class="log-ok">'   + esc + "</span>";
        return esc;
    }).filter(function(l){ return l !== null; }).join("\n");
}

async function loadLog() {
    var svc   = $("log-svc-select").value;
    var lines = ($("log-lines-select") && $("log-lines-select").value) || "100";
    var box   = $("log-box");
    var levelFilter = ($("log-level-select") && $("log-level-select").value) || "all";
    box.textContent = "Loading\u2026";

    // E-4: multi-service interleaved log
    if (svc === "__all__") {
        box.innerHTML = await loadAllServicesLog(lines, levelFilter);
        box.scrollTop = box.scrollHeight;
        return;
    }

    var isSystem = SYSTEM_SVCS.includes(svc);
    try {
        var out;
        if (isSystem) {
            out = await spSudo("journalctl -u " + svc + " -n " + lines + " --no-pager --output=short");
        } else {
            out = await sp(["journalctl",
                "_SYSTEMD_USER_UNIT=" + svc + ".service",
                "-n", lines, "--no-pager", "--output=short"]);
        }
        box.innerHTML = colorizeLog(out || "(no output)", levelFilter);
        box.scrollTop = box.scrollHeight;
    } catch (e) {
        box.textContent = "Error: " + ((e && e.message) || String(e));
    }
}

function exportLog() {
    var box  = $("log-box");
    var text = box.innerText || box.textContent;
    var svc  = $("log-svc-select").value;
    var blob = new Blob([text], { type: "text/plain" });
    var a    = document.createElement("a");
    a.href   = URL.createObjectURL(blob);
    a.download = "inferno-" + svc + "-" + new Date().toISOString().slice(0,19).replace(/[T:]/g,"-") + ".log";
    document.body.appendChild(a); a.click(); document.body.removeChild(a);
    URL.revokeObjectURL(a.href);
}

function toggleFollow() {
    var btn = $("btn-log-follow");
    if (_followTimer) {
        clearInterval(_followTimer);
        _followTimer = null;
        btn.classList.remove("btn-follow-active");
        btn.textContent = "\u25B6 Follow";
    } else {
        _followTimer = setInterval(function() {
            loadLog().then(function() {
                var box = $("log-box"); box.scrollTop = box.scrollHeight;
            });
        }, 2500);
        btn.classList.add("btn-follow-active");
        btn.textContent = "\u25A0 Stop";
        toast("Live follow active (2.5 s poll)", "info", 3000);
    }
}

// ── Actions ────────────────────────────────────────────────────────────────────
async function triggerRedeploy() {
    if (!confirm("Remove deploy sentinel and reboot?\n\nThe node will re-download Inferno binaries from GitHub on next boot.")) return;
    try {
        await spSudo("rm -f " + SENTINEL);
        toast("Sentinel removed. Rebooting\u2026", "info", 0);
        await spSudo("systemctl reboot");
    } catch (e) { toast("Error: " + ((e && e.message) || String(e)), "error", 0); }
}

async function triggerReboot() {
    if (!confirm("Reboot the node?")) return;
    try {
        toast("Rebooting\u2026", "info", 0);
        await spSudo("systemctl reboot");
    } catch (e) { toast("Reboot error: " + ((e && e.message) || String(e)), "error", 0); }
}

// ── Config export / import ─────────────────────────────────────────────────────
function exportConfig() {
    var text = buildConfText(currentConf);
    var blob = new Blob([text], { type: "text/plain" });
    var a    = document.createElement("a");
    a.href   = URL.createObjectURL(blob);
    a.download = "inferno.conf";
    document.body.appendChild(a); a.click(); document.body.removeChild(a);
    URL.revokeObjectURL(a.href);
    toast("Config exported.", "success", 3000);
}

function importConfig(file) {
    if (!file) return;
    var reader = new FileReader();
    reader.onload = function(e) {
        var parsed = parseConf(e.target.result);
        if (!parsed.INFERNO_MODE) {
            toast("Invalid config file — INFERNO_MODE missing.", "error", 0);
            return;
        }
        currentConf = parsed;
        currentMode = parsed.INFERNO_MODE || "spotify";
        $("cfg-mode").value = currentMode;
        if (parsed.INFERNO_SPOTIFY_NAME) $("cfg-spotify-name").value = parsed.INFERNO_SPOTIFY_NAME;
        if (parsed.INFERNO_DANTE_NAME)   $("cfg-dante-name").value   = parsed.INFERNO_DANTE_NAME;
        if (parsed.INFERNO_NIC) populateNics(parsed.INFERNO_NIC);
        if (parsed.INFERNO_TX_CHANNELS)  $("cfg-tx-channels").value  = parsed.INFERNO_TX_CHANNELS;
        if (parsed.INFERNO_RX_CHANNELS)  $("cfg-rx-channels").value  = parsed.INFERNO_RX_CHANNELS;
        if (parsed.INFERNO_LOOP_LATENCY) {
            $("cfg-loop-latency").value = parsed.INFERNO_LOOP_LATENCY;
            $("cfg-loop-latency-val").textContent = Math.round(parseInt(parsed.INFERNO_LOOP_LATENCY)/1000) + " ms";
        }
        onModeChange();
        markDirty();
        toast("Config imported — review and click Save & Apply.", "info", 6000);
    };
    reader.readAsText(file);
}

// ── Auto-refresh interval control ─────────────────────────────────────────────
function setRefreshInterval(ms) {
    if (_refreshTimer) { clearInterval(_refreshTimer); _refreshTimer = null; }
    if (ms > 0) _refreshTimer = setInterval(refreshServices, ms);
}

// ── Collapsible card toggle ────────────────────────────────────────────────────
function toggleCard(cardId) {
    var card = $(cardId);
    if (!card) return;
    card.classList.toggle("collapsed");
    var collapsed = card.classList.contains("collapsed");
    try { localStorage.setItem("inferno-collapsed-" + cardId, collapsed ? "1" : "0"); } catch (_) {}
}

function restoreCollapsed() {
    ["card-audio-devices","card-volume","card-dante","card-journal"].forEach(function(id) {
        try {
            if (localStorage.getItem("inferno-collapsed-" + id) === "1") {
                var card = $(id);
                if (card) card.classList.add("collapsed");
            }
        } catch (_) {}
    });
}

// ── Keyboard shortcuts ─────────────────────────────────────────────────────────
function initKeyboardShortcuts() {
    document.addEventListener("keydown", function(e) {
        var tag = (e.target.tagName || "").toUpperCase();
        if (tag === "INPUT" || tag === "SELECT" || tag === "TEXTAREA") return;
        if (e.ctrlKey || e.metaKey || e.altKey) return;
        switch (e.key) {
            case "r": case "R": e.preventDefault(); refreshAll(); break;
            case "s": case "S": if (isDirty) { e.preventDefault(); saveConfig(); } break;
            case "j": case "J": e.preventDefault(); loadLog(); break;
            case "Escape":
                document.querySelectorAll(".toast").forEach(function(t){ t.remove(); });
                if (_followTimer) toggleFollow();
                break;
        }
    });
}

// ── Dante / Inferno Signal Chain info card ────────────────────────────────────
async function refreshSignalChain() {
    var container = $("signal-chain-content");
    if (!container) return;
    container.innerHTML = '<span class="loading-text">Reading signal chain…</span>';

    var rows = [];
    function scRow(label, val, hint) {
        rows.push({ label: label, val: val, hint: hint || "" });
    }

    // From inferno.conf
    scRow("Mode",          currentConf.INFERNO_MODE || "—");
    scRow("Dante TX Name", currentConf.INFERNO_DANTE_NAME || currentConf.INFERNO_NAME || "—");
    scRow("NIC",           currentConf.INFERNO_NIC  || "—");
    scRow("TX Channels",   currentConf.INFERNO_TX_CHANNELS || "—");
    scRow("RX Channels",   currentConf.INFERNO_RX_CHANNELS || "—");

    // From .asoundrc — parse TX_LATENCY_NS, RX_LATENCY_NS, format, rate
    try {
        var asound = await cockpit.file(ASOUNDRC).read() || "";
        var txLat  = (asound.match(/TX_LATENCY_NS\s+(\d+)/) || [])[1];
        var rxLat  = (asound.match(/RX_LATENCY_NS\s+(\d+)/) || [])[1];
        var fmt    = (asound.match(/format\s+(S\w+)/)        || [])[1];
        var rate   = (asound.match(/rate\s+(\d+)/)           || [])[1];
        var chans  = (asound.match(/channels\s+(\d+)/)       || [])[1];
        if (txLat) scRow("TX Latency", (parseInt(txLat)/1e6).toFixed(1) + " ms", "TX_LATENCY_NS=" + txLat);
        if (rxLat) scRow("RX Latency", (parseInt(rxLat)/1e6).toFixed(1) + " ms", "RX_LATENCY_NS=" + rxLat);
        if (fmt)   scRow("ALSA Format",  fmt,  "PCM sample format in .asoundrc");
        if (rate)  scRow("Sample Rate",  rate + " Hz");
        if (chans) scRow("ALSA Channels", chans + " ch");
    } catch (_) {}

    // Dante device name from .asoundrc NAME field
    try {
        var asound2  = asound || await cockpit.file(ASOUNDRC).read() || "";
        var danteName = (asound2.match(/NAME\s+"([^"]+)"/) || [])[1];
        if (danteName) scRow("Dante PCM Name", danteName, "NAME in inferno_spotify block");
    } catch (_) {}

    container.innerHTML = "";
    if (rows.length === 0) {
        container.innerHTML = '<span class="loading-text">No signal chain data found.</span>';
        return;
    }
    var table = document.createElement("table");
    table.className = "info-table sc-table";
    rows.forEach(function(r) {
        var tr = document.createElement("tr");
        var k  = document.createElement("td"); k.className = "info-key sc-key"; k.textContent = r.label;
        var v  = document.createElement("td");
        var c  = document.createElement("code"); c.textContent = r.val;
        v.appendChild(c);
        if (r.hint) {
            var h = document.createElement("span"); h.className = "sc-hint"; h.textContent = " — " + r.hint;
            v.appendChild(h);
        }
        tr.appendChild(k); tr.appendChild(v);
        table.appendChild(tr);
    });
    container.appendChild(table);
}

// ── Tab navigation (I-3) ──────────────────────────────────────────────────────
var _activeTab = "tab-config";

function switchTab(tabId) {
    document.querySelectorAll(".tab-panel").forEach(function(p) {
        p.classList.add("tab-panel-hidden");
    });
    document.querySelectorAll(".tab-btn").forEach(function(b) {
        b.classList.remove("tab-btn-active");
    });
    var panel = $(tabId);
    if (panel) panel.classList.remove("tab-panel-hidden");
    var btn = document.querySelector('[data-tab="' + tabId + '"]');
    if (btn) btn.classList.add("tab-btn-active");
    _activeTab = tabId;
    try { localStorage.setItem("inferno-active-tab", tabId); } catch (_) {}
}

function initTabs() {
    document.querySelectorAll(".tab-btn").forEach(function(btn) {
        btn.addEventListener("click", function() { switchTab(this.dataset.tab); });
    });
    try {
        var saved = localStorage.getItem("inferno-active-tab");
        if (saved && $(saved)) switchTab(saved);
    } catch (_) {}
}

// ── Restart All with per-service progress (B-4) ───────────────────────────────
async function restartAll() {
    var svcs     = activeSvcs();
    var progress = $("restart-progress");
    progress.innerHTML = "";
    progress.classList.remove("hidden");

    var items = {};
    svcs.forEach(function(svc) {
        var row   = document.createElement("div"); row.className = "restart-progress-item";
        var icon  = document.createElement("span"); icon.className  = "restart-progress-icon";  icon.textContent  = "⏳";
        var name  = document.createElement("span"); name.className  = "restart-progress-name";  name.textContent  = SVC_LABELS[svc] ? SVC_LABELS[svc].label : svc;
        var state = document.createElement("span"); state.className = "restart-progress-state"; state.textContent = "waiting…";
        row.appendChild(icon); row.appendChild(name); row.appendChild(state);
        progress.appendChild(row);
        items[svc] = { icon: icon, state: state };
    });

    var anyFail = false;
    for (var i = 0; i < svcs.length; i++) {
        var svc = svcs[i];
        items[svc].icon.textContent  = "⟳";
        items[svc].state.textContent = "restarting…";
        try {
            if (SYSTEM_SVCS.includes(svc)) {
                await spSudo("systemctl restart " + svc);
            } else {
                await spUser("systemctl --user restart " + svc);
            }
            items[svc].icon.textContent  = "✅";
            items[svc].state.textContent = "restarted";
        } catch (e) {
            items[svc].icon.textContent  = "❌";
            items[svc].state.textContent = "failed: " + ((e && e.message) || String(e));
            anyFail = true;
        }
    }

    toast(anyFail ? "Restart complete with errors." : "All services restarted.", anyFail ? "error" : "success", 5000);
    await refreshServices();
    setTimeout(function() { progress.classList.add("hidden"); progress.innerHTML = ""; }, 8000);
}

// ── Config change diff modal (F-2) ────────────────────────────────────────────
var _savedConfSnapshot = {};

function buildFormSnapshot() {
    return {
        INFERNO_MODE:         $("cfg-mode").value,
        INFERNO_SPOTIFY_NAME: $("cfg-spotify-name").value,
        INFERNO_DANTE_NAME:   $("cfg-dante-name").value,
        INFERNO_NIC:          $("cfg-nic").value,
        INFERNO_TX_CHANNELS:  $("cfg-tx-channels").value,
        INFERNO_RX_CHANNELS:  $("cfg-rx-channels").value,
        INFERNO_LOOP_LATENCY: $("cfg-loop-latency").value,
        LIBRESPOT_BITRATE:    $("cfg-librespot-bitrate").value,
        LIBRESPOT_NORMALIZE:  $("cfg-librespot-normalize").value,
    };
}

var _pendingSaveResolve = null;

function showConfigDiff() {
    return new Promise(function(resolve) {
        var current = buildFormSnapshot();
        var labels  = {
            INFERNO_MODE:         "Mode",
            INFERNO_SPOTIFY_NAME: "Spotify Name",
            INFERNO_DANTE_NAME:   "Dante TX Name",
            INFERNO_NIC:          "Interface",
            INFERNO_TX_CHANNELS:  "TX Channels",
            INFERNO_RX_CHANNELS:  "RX Channels",
            INFERNO_LOOP_LATENCY: "Loop Latency (µs)",
            LIBRESPOT_BITRATE:    "Bitrate",
            LIBRESPOT_NORMALIZE:  "Normalise",
        };
        var diffRows = [];
        Object.keys(labels).forEach(function(k) {
            var oldVal = ((_savedConfSnapshot[k] !== undefined ? _savedConfSnapshot[k] : "") + "");
            var newVal = ((current[k]            !== undefined ? current[k]            : "") + "");
            if (oldVal !== newVal) diffRows.push({ label: labels[k], oldVal: oldVal || "(none)", newVal: newVal || "(none)" });
        });

        if (diffRows.length === 0) { resolve(true); return; }

        var table = $("cfg-diff-table");
        table.innerHTML = "<thead><tr><th>Setting</th><th>Current</th><th>New value</th></tr></thead>";
        var tbody = document.createElement("tbody");
        diffRows.forEach(function(r) {
            var tr  = document.createElement("tr");
            var td1 = document.createElement("td"); td1.textContent = r.label;
            var td2 = document.createElement("td"); td2.className = "diff-old"; td2.textContent = r.oldVal;
            var td3 = document.createElement("td"); td3.className = "diff-new"; td3.textContent = r.newVal;
            tr.appendChild(td1); tr.appendChild(td2); tr.appendChild(td3);
            tbody.appendChild(tr);
        });
        table.appendChild(tbody);

        _pendingSaveResolve = resolve;
        $("cfg-diff-modal").showModal();
    });
}

// ── Multi-service interleaved journal (E-4) ───────────────────────────────────
async function loadAllServicesLog(lines, levelFilter) {
    var svcs = activeSvcs();
    var results = await Promise.all(svcs.map(async function(svc) {
        try {
            var out;
            if (SYSTEM_SVCS.includes(svc)) {
                out = await spSudo("journalctl -u " + svc + " -n " + lines + " --no-pager --output=short");
            } else {
                out = await sp(["journalctl", "_SYSTEMD_USER_UNIT=" + svc + ".service",
                    "-n", lines, "--no-pager", "--output=short"]);
            }
            return { svc: svc, text: out || "" };
        } catch (_) { return { svc: svc, text: "" }; }
    }));

    var shortLabels = {
        "librespot":             "librespot", "librespot-watchdog": "watchdog",
        "inferno-bridge":        "bridge",    "inferno-keepalive":  "keepalive",
        "inferno-aux-tx":        "aux-tx",    "inferno-aux-rx":     "aux-rx",
        "inferno-aux-keepalive": "aux-ka",    "statime-inferno":    "statime",
    };

    var allLines = [];
    results.forEach(function(r) {
        r.text.split("\n").forEach(function(line) {
            if (!line.trim()) return;
            var ts = line.length >= 15 ? line.substring(0, 15) : line;
            allLines.push({ ts: ts, svc: r.svc, line: line });
        });
    });
    allLines.sort(function(a, b) { return a.ts < b.ts ? -1 : a.ts > b.ts ? 1 : 0; });

    return allLines.map(function(entry) {
        var tag = shortLabels[entry.svc] || entry.svc;
        var esc = entry.line.replace(/&/g,"&amp;").replace(/</g,"&lt;").replace(/>/g,"&gt;");
        var lo  = esc.toLowerCase();
        var isErr  = /\berr(or)?\b|failed|fatal/.test(lo);
        var isWarn = /\bwarn/.test(lo);
        var isOk   = /\bok\b|success|ready|running|active|started/.test(lo);
        if (levelFilter === "error" && !isErr)            return null;
        if (levelFilter === "warn"  && !isErr && !isWarn) return null;
        var prefix = '<span class="log-svc-tag">[' + tag + ']</span> ';
        var body   = isErr  ? '<span class="log-err">'  + esc + "</span>" :
                     isWarn ? '<span class="log-warn">' + esc + "</span>" :
                     isOk   ? '<span class="log-ok">'   + esc + "</span>" : esc;
        return prefix + body;
    }).filter(function(l) { return l !== null; }).join("\n");
}

// ── Audio Level Monitor (G-1) — polls ALSA mixer controls ────────────────────
var _peakTimer = null;

async function refreshPeakMeters() {
    var container = $("peak-meters-content");
    try {
        var out = await sp(["bash", "-c", "amixer -D default scontents 2>/dev/null || amixer scontents 2>/dev/null"]);
        if (!out || !out.trim()) {
            container.innerHTML = '<span class="loading-text">No ALSA mixer controls found.</span>';
            return;
        }
        var controls = [];
        out.split(/^Simple mixer control /m).filter(Boolean).forEach(function(block) {
            var nameMatch = block.match(/^'([^']+)'/);
            if (!nameMatch) return;
            var vols = [];
            var re = /(\d+)%/g;
            var m;
            while ((m = re.exec(block)) !== null) vols.push(parseInt(m[1]));
            if (vols.length === 0) return;
            var avg = Math.round(vols.reduce(function(a,b){return a+b;},0) / vols.length);
            controls.push({ name: nameMatch[1], pct: avg });
        });
        if (controls.length === 0) {
            container.innerHTML = '<span class="loading-text">No volume data available.</span>';
            return;
        }
        container.innerHTML = "";
        controls.forEach(function(c) {
            var row  = document.createElement("div"); row.className = "peak-row";
            var lbl  = document.createElement("span"); lbl.className = "peak-label"; lbl.textContent = c.name; lbl.title = c.name;
            var wrap = document.createElement("div"); wrap.className = "peak-bar-wrap";
            var bar  = document.createElement("div"); bar.className = "peak-bar"; bar.style.width = c.pct + "%";
            wrap.appendChild(bar);
            var pct  = document.createElement("span"); pct.className = "peak-pct"; pct.textContent = c.pct + "%";
            row.appendChild(lbl); row.appendChild(wrap); row.appendChild(pct);
            container.appendChild(row);
        });
    } catch (e) {
        container.innerHTML = '<span class="loading-text">amixer unavailable: ' + ((e && e.message) || String(e)) + '</span>';
    }
}

function togglePeakMonitor() {
    var btn = $("btn-peak-toggle");
    if (_peakTimer) {
        clearInterval(_peakTimer);
        _peakTimer = null;
        btn.textContent = "\u25B6 Start Monitor";
        toast("Level monitor stopped.", "info", 2000);
    } else {
        refreshPeakMeters();
        _peakTimer = setInterval(refreshPeakMeters, 2000);
        btn.textContent = "\u25A0 Stop Monitor";
        toast("Level monitor active (2 s poll).", "info", 2000);
    }
}

// ── Init ───────────────────────────────────────────────────────────────────────
async function refreshAll() {
    await Promise.all([refreshServices(), refreshSystemInfo(), refreshPTP()]);
    refreshHeader();
    refreshSignalChain().catch(function(){});
}

async function init() {
    try {
        var u = await cockpit.user();
        USER_UID  = u.id;
        USER_HOME = u.home || "/var/home/core";
    } catch (_) {}

    // A-1: Unsaved-changes guard
    window.addEventListener("beforeunload", function(e) {
        if (isDirty) { e.preventDefault(); e.returnValue = ""; }
    });

    // Wire all event listeners (CSP blocks inline onclick/onchange in HTML)
    $("btn-refresh").addEventListener("click", refreshAll);
    $("btn-restart-all").addEventListener("click", restartAll);
    $("btn-save").addEventListener("click", saveConfig);
    $("btn-log-refresh").addEventListener("click", loadLog);
    $("btn-redeploy").addEventListener("click", triggerRedeploy);
    $("btn-reboot").addEventListener("click", triggerReboot);
    $("log-svc-select").addEventListener("change", loadLog);
    $("log-level-select").addEventListener("change", loadLog);
    $("log-lines-select").addEventListener("change", loadLog);
    $("btn-log-follow").addEventListener("click", toggleFollow);
    $("btn-log-export").addEventListener("click", exportLog);

    $("cfg-mode").addEventListener("change", function() { onModeChange(); markDirty(); });
    $("cfg-audio-in").addEventListener("change", markDirty);
    $("cfg-audio-in2").addEventListener("change", markDirty);
    $("cfg-audio-out").addEventListener("change", markDirty);
    $("cfg-audio-out2").addEventListener("change", markDirty);
    $("cfg-nic").addEventListener("change", markDirty);
    $("cfg-tx-channels").addEventListener("change", function() { onChannelChange(); markDirty(); });
    $("cfg-rx-channels").addEventListener("change", function() { onChannelChange(); markDirty(); });
    $("cfg-spotify-name").addEventListener("input", markDirty);
    $("cfg-dante-name").addEventListener("input", markDirty);
    $("cfg-librespot-bitrate").addEventListener("change", markDirty);
    $("cfg-librespot-normalize").addEventListener("change", markDirty);
    $("cfg-loop-latency").addEventListener("input", function() {
        $("cfg-loop-latency-val").textContent = Math.round(parseInt(this.value)/1000) + " ms";
        markDirty();
    });

    $("btn-audio-devices").addEventListener("click", refreshAudioDevices);
    $("btn-vol-normalize").addEventListener("click", normalizeAllVolumes);

    // Config export/import
    $("btn-cfg-export").addEventListener("click", exportConfig);
    $("btn-cfg-import").addEventListener("click", function() { $("cfg-import-file").click(); });
    $("cfg-import-file").addEventListener("change", function() { importConfig(this.files[0]); this.value = ""; });

    // PTP refresh
    $("btn-ptp-refresh").addEventListener("click", refreshPTP);

    // Health check
    $("btn-health-check").addEventListener("click", runHealthCheck);

    // Dante discovery
    $("btn-dante-scan").addEventListener("click", scanDanteDevices);

    // Auto-refresh interval
    $("svc-refresh-select").addEventListener("change", function() {
        setRefreshInterval(parseInt(this.value));
    });

    // Collapsible cards
    $("btn-collapse-audio").addEventListener("click",   function() { toggleCard("card-audio-devices"); });
    $("btn-collapse-volume").addEventListener("click",  function() { toggleCard("card-volume"); });
    $("btn-collapse-dante").addEventListener("click",   function() { toggleCard("card-dante"); });
    $("btn-collapse-journal").addEventListener("click", function() { toggleCard("card-journal"); });
    $("btn-collapse-peak").addEventListener("click",    function() { toggleCard("card-peak-meters"); });
    restoreCollapsed();

    // Tab navigation (I-3)
    initTabs();

    // Audio level monitor (G-1)
    $("btn-peak-toggle").addEventListener("click", togglePeakMonitor);

    // Config diff modal confirm/cancel (F-2)
    $("btn-diff-confirm").addEventListener("click", function() {
        $("cfg-diff-modal").close();
        if (_pendingSaveResolve) { _pendingSaveResolve(true); _pendingSaveResolve = null; }
    });
    $("btn-diff-cancel").addEventListener("click", function() {
        $("cfg-diff-modal").close();
        if (_pendingSaveResolve) { _pendingSaveResolve(false); _pendingSaveResolve = null; }
        toast("Save cancelled.", "info", 2000);
    });

    // Keyboard shortcuts
    initKeyboardShortcuts();

    await loadConfig();
    refreshHeader();
    await refreshAll();
    await loadLog();
    refreshAudioDevices();
    loadVolumes();

    // Start auto-refresh (default 20s)
    setRefreshInterval(20000);
    // Initial PTP poll
    refreshPTP().catch(function(){});
}

init().catch(function(e) { toast("Init error: " + String(e), "error", 0); });
