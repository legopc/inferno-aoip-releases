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
const AUX_SVCS     = ["inferno-aux-tx", "inferno-aux-rx", "inferno-aux-keepalive"];

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
    var liveName = "";
    try {
        var svcText = await cockpit.file(LIBRESPOT_SVC).read();
        var m = (svcText || "").match(/--name\s+"([^"]+)"/);
        if (m) liveName = m[1];
    } catch (_) {}

    var confText = "";
    try { confText = await cockpit.file(CONF).read() || ""; } catch (_) {}

    currentConf = parseConf(confText);
    if (liveName) currentConf.INFERNO_NAME = liveName;

    $("cfg-name").value = currentConf.INFERNO_NAME || "";
    currentMode = currentConf.INFERNO_MODE || "spotify";
    $("cfg-mode").value = currentMode;
    onModeChange();

    await populateNics(currentConf.INFERNO_NIC || "auto");
    await populateAudio(currentConf.INFERNO_AUDIO_CARD || "0");

    isDirty = false;
    $("cfg-dirty-badge").classList.add("hidden");
}

function markDirty() {
    isDirty = true;
    $("cfg-dirty-badge").classList.remove("hidden");
}

function onModeChange() {
    currentMode = $("cfg-mode").value;
    if (currentMode === "aux") {
        $("field-audio").classList.remove("hidden");
    } else {
        $("field-audio").classList.add("hidden");
    }
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
async function populateAudio(current) {
    var sel = $("cfg-audio");
    sel.innerHTML = "";
    try {
        var out = await sp(["cat", "/proc/asound/cards"]);
        var seen = {};
        out.split("\n").forEach(function(line) {
            var m = line.match(/^\s*(\d+)\s+\[([^\]]+)\]/);
            if (!m || seen[m[1]]) return;
            seen[m[1]] = true;
            sel.add(new Option("Card " + m[1] + " \u2014 " + m[2].trim(), m[1], false, m[1] === current));
        });
    } catch (_) {}
    if (!sel.options.length) sel.add(new Option("Card 0 (default)", "0"));
    sel.value = current || "0";
}

// ── Save config ────────────────────────────────────────────────────────────────
async function saveConfig() {
    var btn   = $("btn-save");
    var label = $("save-label");
    btn.disabled = true;
    label.innerHTML = '<span class="spinner"></span> Applying\u2026';

    var newName     = $("cfg-name").value.trim();
    var oldName     = currentConf.INFERNO_NAME || "";
    var nameChanged = newName && newName !== oldName;

    try {
        // Write /etc/inferno.conf via sudo tee
        var newConf = Object.assign({}, currentConf, {
            INFERNO_MODE:       $("cfg-mode").value,
            INFERNO_NAME:       newName,
            INFERNO_NIC:        $("cfg-nic").value,
            INFERNO_AUDIO_CARD: $("cfg-audio").value,
        });
        await writeFileAsSudo(CONF, buildConfText(newConf));
        currentConf = newConf;
        currentMode = newConf.INFERNO_MODE;

        if (nameChanged) {
            // Patch librespot.service --name and .asoundrc NAME
            await spUser("sed -i 's/--name \"[^\"]*\"/--name \"" + newName + "\"/' " + LIBRESPOT_SVC);
            await spUser("sed -i 's/NAME \"[^\"]*\"/NAME \"" + newName + "\"/' " + ASOUNDRC);
            await spUser("systemctl --user daemon-reload");
            await spUser("systemctl --user restart librespot inferno-bridge inferno-keepalive");
            toast("Device name updated to <b>" + newName + "</b>. Restarting services\u2026", "success", 8000);
        } else {
            toast("Configuration saved.", "success");
        }

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
function activeSvcs() {
    return SYSTEM_SVCS.concat(currentMode === "spotify" ? SPOTIFY_SVCS : AUX_SVCS);
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
    $("cfg-audio").addEventListener("change", markDirty);
    $("cfg-nic").addEventListener("change", markDirty);

    await loadConfig();
    refreshHeader();
    await refreshAll();
    await loadLog();
}

init().catch(function(e) { toast("Init error: " + String(e), "error", 0); });
setInterval(refreshServices, 20000);
