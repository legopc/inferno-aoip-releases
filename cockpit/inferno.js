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

const SVC_LABELS = {
    "librespot":             { label: "librespot",           desc: "Spotify Connect receiver" },
    "librespot-watchdog":    { label: "librespot-watchdog",  desc: "Watchdog & auto-restart" },
    "inferno-bridge":        { label: "inferno-bridge",      desc: "ALSA loopback to Dante TX" },
    "inferno-keepalive":     { label: "inferno-keepalive",   desc: "Dante TX keepalive writer" },
    "inferno-aux-tx":        { label: "inferno-aux-tx",      desc: "AUX to Dante TX bridge" },
    "inferno-aux-rx":        { label: "inferno-aux-rx",      desc: "Dante RX to AUX output" },
    "inferno-aux-keepalive": { label: "inferno-aux-keepalive", desc: "AUX Dante keepalive" },
    "statime-inferno":       { label: "statime",             desc: "PTP hardware clock sync" },
};

let currentConf = {};
let currentMode = "spotify";
let isDirty     = false;
let USER_UID    = 1000;
let USER_HOME   = "/var/home/core";

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
    try {
        var svcText = await cockpit.file(LIBRESPOT_SVC).read();
        var m = (svcText || "").match(/--name\s+"([^"]+)"/);
        if (m) spotifyName = m[1];
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
    onModeChange();

    await populateNics(currentConf.INFERNO_NIC || "auto");
    var cardIn  = currentConf.INFERNO_AUDIO_CARD_IN  || currentConf.INFERNO_AUDIO_CARD || "0";
    var cardOut = currentConf.INFERNO_AUDIO_CARD_OUT || currentConf.INFERNO_AUDIO_CARD || "0";
    await populateAudio(cardIn, cardOut);

    isDirty = false;
    $("cfg-dirty-badge").classList.add("hidden");
}

function markDirty() {
    isDirty = true;
    $("cfg-dirty-badge").classList.remove("hidden");
}

function onModeChange() {
    currentMode = $("cfg-mode").value;
    var isAuxIn    = currentMode === "aux-in"    || currentMode === "aux-bidir";
    var isAuxOut   = currentMode === "aux-out"   || currentMode === "aux-bidir";
    var needsPanel = currentMode !== "spotify";
    $("field-audio-in").classList.toggle("hidden", !isAuxIn);
    $("field-audio-out").classList.toggle("hidden", !isAuxOut);
    $("field-audio-panel").classList.toggle("hidden", !needsPanel);
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
        var m = line.match(/^card\s+(\d+):\s+\S+\s+\[([^\]]+)\],\s+device\s+(\d+):\s+([^\[]+)/i);
        if (!m) return;
        var num = m[1], cardName = m[2].trim(), devName = m[4].trim();
        if (seen[num]) return;
        if (/Loopback/i.test(cardName)) return;
        if (filterFn && filterFn(cardName, devName)) return;
        seen[num] = true;
        cards.push({ num: num, label: num + " \u2014 " + devName });
    });
    return cards;
}

async function populateAudio(currentIn, currentOut) {
    var selIn  = $("cfg-audio-in");
    var selOut = $("cfg-audio-out");
    selIn.innerHTML  = "";
    selOut.innerHTML = "";
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
        selIn.add(new Option(c.label, c.num, false, c.num === currentIn));
    });
    playbackCards.forEach(function(c) {
        selOut.add(new Option(c.label, c.num, false, c.num === currentOut));
    });

    if (!selIn.options.length)  selIn.add(new Option("0 (default)", "0"));
    if (!selOut.options.length) selOut.add(new Option("0 (default)", "0"));

    if (currentIn  && ![].some.call(selIn.options,  function(o) { return o.value === currentIn;  }))
        selIn.add(new Option(currentIn  + " (from config)", currentIn));
    if (currentOut && ![].some.call(selOut.options, function(o) { return o.value === currentOut; }))
        selOut.add(new Option(currentOut + " (from config)", currentOut));

    selIn.value  = currentIn  || (selIn.options[0]  && selIn.options[0].value)  || "0";
    selOut.value = currentOut || (selOut.options[0] && selOut.options[0].value) || "0";
}

// ── Audio device info panel ────────────────────────────────────────────────────
async function showAudioDevices() {
    var box  = $("audio-devices-box");
    var btn  = $("btn-audio-devices");
    if (!box.classList.contains("hidden")) {
        box.classList.add("hidden");
        btn.textContent = "\u25b6 Show audio devices";
        return;
    }
    btn.textContent = "Loading\u2026";
    try {
        var play = await sp(["aplay",   "-l"]).catch(function() { return ""; });
        var rec  = await sp(["arecord", "-l"]).catch(function() { return ""; });

        // Build card map from both outputs
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
            $("audio-devices-content").innerHTML = "<em>No audio devices found.</em>";
        } else {
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
            $("audio-devices-content").innerHTML = html;
        }
    } catch (e) {
        $("audio-devices-content").textContent = "Error: " + e;
    }
    box.classList.remove("hidden");
    btn.textContent = "\u25bc Hide audio devices";
}

// ── Aux ALSA + service auto-provisioning ──────────────────────────────────────
function deriveDeviceId(baseId, offset) {
    // Increment the last 4 hex chars of a 16-char DEVICE_ID hex string
    var suffix = parseInt((baseId || "0").slice(-4), 16) + offset;
    return (baseId || "000000000000").slice(0, -4) + suffix.toString(16).padStart(4, "0");
}

async function ensureAuxSetup(cardIn, cardOut, danteName) {
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
            "    TX_CHANNELS 2",
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
            "    RX_CHANNELS 2",
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
        // pcm_type.inferno lib must be at top — only add if missing
        var prefix = asoundText.includes("pcm_type.inferno") ? "" :
            "pcm_type.inferno {\n    lib \"" + pluginPath + "\"\n}\n";
        await cockpit.file(ASOUNDRC).replace(prefix + asoundText + auxBlock + "\n");
    }

    // Write service files if missing
    var svcDir  = USER_HOME + "/.config/systemd/user";
    var txSvc   = svcDir + "/inferno-aux-tx.service";
    var rxSvc   = svcDir + "/inferno-aux-rx.service";

    var txContent = await cockpit.file(txSvc).read().catch(function() { return null; });
    if (!txContent) {
        await cockpit.file(txSvc).replace([
            "[Unit]",
            "Description=Inferno AUX TX Bridge \u2014 analog in to Dante",
            "After=statime-inferno.service default.target",
            "",
            "[Service]",
            "ExecStart=/usr/bin/alsaloop -C plughw:" + cardIn + ",0 -P inferno_aux_tx -r 48000 -f S32_LE -c 2 -t 10000",
            "Restart=on-failure",
            "RestartSec=3",
            "",
            "[Install]",
            "WantedBy=default.target",
        ].join("\n") + "\n");
    }

    var rxContent = await cockpit.file(rxSvc).read().catch(function() { return null; });
    if (!rxContent) {
        await cockpit.file(rxSvc).replace([
            "[Unit]",
            "Description=Inferno AUX RX Bridge \u2014 Dante to analog out",
            "After=statime-inferno.service default.target",
            "",
            "[Service]",
            "ExecStart=/usr/bin/alsaloop -C inferno_aux_rx -P plughw:" + cardOut + ",0 -r 48000 -f S32_LE -c 2 -t 10000",
            "Restart=on-failure",
            "RestartSec=3",
            "",
            "[Install]",
            "WantedBy=default.target",
        ].join("\n") + "\n");
    }

    return needsAlsa; // true if ALSA blocks were freshly written
}

// ── Save config ────────────────────────────────────────────────────────────────
async function saveConfig() {
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
            INFERNO_MODE:         newMode,
            INFERNO_SPOTIFY_NAME: newSpotifyName,
            INFERNO_DANTE_NAME:   newDanteName,
            INFERNO_NIC:           $("cfg-nic").value,
            INFERNO_AUDIO_CARD_IN:  $("cfg-audio-in").value,
            INFERNO_AUDIO_CARD_OUT: $("cfg-audio-out").value,
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
        if (newDanteName) {
            // Patch NAME only inside each named block to avoid clobbering aux -TX/-RX suffixes
            await spUser("sed -i '/pcm\\.inferno_spotify/,/^}/s/NAME \"[^\"]*\"/NAME \"" + newDanteName + "\"/' " + ASOUNDRC);
            await spUser("sed -i '/pcm\\.inferno_aux_tx/,/^}/s/NAME \"[^\"]*\"/NAME \"" + newDanteName + "-TX\"/' " + ASOUNDRC);
            await spUser("sed -i '/pcm\\.inferno_aux_rx/,/^}/s/NAME \"[^\"]*\"/NAME \"" + newDanteName + "-RX\"/' " + ASOUNDRC);
            msgs.push("Dante TX → <b>" + newDanteName + "</b>");
        }

        await spUser("systemctl --user daemon-reload");

        // For aux modes: ensure ALSA PCM defs and service files exist before starting
        if (newMode !== "spotify") {
            var cardIn    = $("cfg-audio-in").value  || "0";
            var cardOut   = $("cfg-audio-out").value || "0";
            var freshAlsa = await ensureAuxSetup(cardIn, cardOut, newDanteName);
            if (freshAlsa) {
                // New ALSA definitions written — must reload daemon again
                await spUser("systemctl --user daemon-reload");
                msgs.push("AUX ALSA devices configured");
            }
        }

        var targetSvcs = modeToSvcs(newMode);
        var stopSvcs   = SPOTIFY_SVCS.concat(ALL_AUX_SVCS)
                           .filter(function(s) { return !targetSvcs.includes(s); })
                           .join(" ");
        var startSvcs  = targetSvcs.join(" ");

        if (stopSvcs)  await spUser("systemctl --user stop "  + stopSvcs  + " 2>/dev/null; true");
        if (startSvcs) await spUser("systemctl --user start " + startSvcs + " 2>/dev/null; true");

        var modeLabels = {
            "spotify":   "Spotify Connect → Dante TX",
            "aux-in":    "Analog In → Dante TX",
            "aux-out":   "Dante RX → Analog Out",
            "aux-bidir": "Analog In + Out",
        };
        if (modeChanged) msgs.push("Mode → <b>" + (modeLabels[newMode] || newMode) + "</b>");

        toast((msgs.length ? msgs.join(", ") + ". " : "Configuration saved. ") + "Services updated.", "success", 8000);

        isDirty = false;
        $("cfg-dirty-badge").classList.add("hidden");
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

async function refreshServices() {
    var svcs     = activeSvcs();
    var statuses = await Promise.all(svcs.map(getSvcStatus));
    var grid     = $("svc-grid");
    grid.innerHTML = "";

    svcs.forEach(function(svc, i) {
        var state    = statuses[i] || "unknown";
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

    try {
        var loop = (await sp(["bash", "-c", "cat /proc/asound/cards | grep -i loopback | head -1"])).trim();
        addRow(table, "snd-aloop", loop ? code(loop) : "not loaded \u26a0", loop ? "" : "text-danger");
    } catch (_) {}

    try {
        // Try reading sentinel — may require sudo on bootc systems
        var sentinel = await spSudo("test -f " + SENTINEL + " && echo present || echo absent");
        if ((sentinel || "").trim() === "present") {
            addRow(table, "Deploy sentinel", "\u2705 present", "text-success");
        } else {
            addRow(table, "Deploy sentinel", "\u26a0 missing \u2014 re-deploys on next reboot", "text-warning");
        }
    } catch (_) {
        addRow(table, "Deploy sentinel", "unknown", "text-muted");
    }
}

// ── Header mode badge ──────────────────────────────────────────────────────────
function refreshHeader() {
    var badge = $("hdr-mode-badge");
    var mode  = currentMode || "spotify";
    badge.innerHTML = "";
    var span = document.createElement("span");
    span.className = "mode-badge " + mode;
    span.textContent = mode;
    badge.appendChild(span);
}

// ── Journal ────────────────────────────────────────────────────────────────────
function colorizeLog(text) {
    return text.split("\n").map(function(line) {
        var esc = line.replace(/&/g,"&amp;").replace(/</g,"&lt;").replace(/>/g,"&gt;");
        var lo  = esc.toLowerCase();
        if (/\berr(or)?\b|failed|fatal/.test(lo)) return '<span class="log-err">' + esc + "</span>";
        if (/\bwarn/.test(lo))                    return '<span class="log-warn">' + esc + "</span>";
        if (/\bok\b|success|ready|running|active|started/.test(lo)) return '<span class="log-ok">' + esc + "</span>";
        return esc;
    }).join("\n");
}

async function loadLog() {
    var svc = $("log-svc-select").value;
    var box = $("log-box");
    box.textContent = "Loading\u2026";
    var isSystem = SYSTEM_SVCS.includes(svc);
    try {
        var out;
        if (isSystem) {
            // System service: use sudo -n journalctl
            out = await spSudo("journalctl -u " + svc + " -n 100 --no-pager --output=short");
        } else {
            // User service: query via _SYSTEMD_USER_UNIT in system journal (no --user needed)
            out = await sp(["journalctl",
                "_SYSTEMD_USER_UNIT=" + svc + ".service",
                "-n", "100", "--no-pager", "--output=short"]);
        }
        box.innerHTML = colorizeLog(out || "(no output)");
        box.scrollTop = box.scrollHeight;
    } catch (e) {
        box.textContent = "Error: " + ((e && e.message) || String(e));
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

// ── Init ───────────────────────────────────────────────────────────────────────
async function refreshAll() {
    await Promise.all([refreshServices(), refreshSystemInfo()]);
    refreshHeader();
}

async function init() {
    try {
        var u = await cockpit.user();
        USER_UID  = u.id;
        USER_HOME = u.home || "/var/home/core";
    } catch (_) {}

    // Wire all event listeners here (CSP blocks inline onclick/onchange in HTML)
    $("btn-refresh").addEventListener("click", refreshAll);
    $("btn-restart-all").addEventListener("click", restartAll);
    $("btn-save").addEventListener("click", saveConfig);
    $("btn-log-refresh").addEventListener("click", loadLog);
    $("btn-redeploy").addEventListener("click", triggerRedeploy);
    $("btn-reboot").addEventListener("click", triggerReboot);
    $("log-svc-select").addEventListener("change", loadLog);
    $("cfg-mode").addEventListener("change", function() { onModeChange(); markDirty(); });
    $("cfg-audio-in").addEventListener("change", markDirty);
    $("cfg-audio-out").addEventListener("change", markDirty);
    $("cfg-nic").addEventListener("change", markDirty);
    $("btn-audio-devices").addEventListener("click", showAudioDevices);
    $("cfg-spotify-name").addEventListener("input", markDirty);
    $("cfg-dante-name").addEventListener("input", markDirty);

    await loadConfig();
    refreshHeader();
    await refreshAll();
    await loadLog();
}

init().catch(function(e) { toast("Init error: " + String(e), "error", 0); });
setInterval(refreshServices, 20000);
