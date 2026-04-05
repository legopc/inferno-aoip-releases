/* inferno.js — Cockpit Inferno AoIP page
 * Vanilla JS using cockpit.spawn() / cockpit.file() — no build step needed.
 */

// ── Constants ──────────────────────────────────────────────────────────────────
const CONF         = "/etc/inferno.conf";
const SENTINEL     = "/var/lib/inferno/.deployed";
const ASOUNDRC     = "/var/home/core/.asoundrc";
const LIBRESPOT_SVC= "/var/home/core/.config/systemd/user/librespot.service";

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
let USER_UID    = 1000;  // updated from cockpit.user() on init

// ── Helpers ────────────────────────────────────────────────────────────────────
const $ = id => document.getElementById(id);

function userEnv() {
    return [
        "XDG_RUNTIME_DIR=/run/user/" + USER_UID,
        "DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/" + USER_UID + "/bus",
    ];
}

function sp(args, opts) {
    return cockpit.spawn(args, Object.assign({ err: "message" }, opts || {}));
}

function spUser(cmd) {
    return cockpit.spawn(["bash", "-c", cmd], { err: "message", environ: userEnv() });
}

function spRoot(args) {
    return cockpit.spawn(args, { err: "message", superuser: "require" });
}

// ── Toast notifications ────────────────────────────────────────────────────────
function toast(msg, type, duration) {
    type = type || "info";
    if (duration === undefined) duration = 5000;
    const icons = { success: "\u2705", error: "\u274c", info: "\u2139\ufe0f" };
    const div = document.createElement("div");
    div.className = "toast toast-" + type;
    const iconSpan = document.createElement("span");
    iconSpan.className = "toast-icon";
    iconSpan.textContent = icons[type] || "";
    const msgSpan = document.createElement("span");
    msgSpan.innerHTML = msg;
    const closeSpan = document.createElement("span");
    closeSpan.className = "toast-close";
    closeSpan.textContent = "\u2715";
    closeSpan.onclick = function() { div.remove(); };
    div.appendChild(iconSpan);
    div.appendChild(msgSpan);
    div.appendChild(closeSpan);
    $("toast-area").appendChild(div);
    if (duration > 0) setTimeout(function() { if (div.parentNode) div.remove(); }, duration);
    return div;
}

// ── Config ─────────────────────────────────────────────────────────────────────
function parseConf(text) {
    const c = {};
    for (const line of (text || "").split("\n")) {
        const t = line.trim();
        if (!t || t.startsWith("#") || !t.includes("=")) continue;
        const i = t.indexOf("=");
        c[t.slice(0, i).trim()] = t.slice(i + 1).trim();
    }
    return c;
}

function buildConfText(conf) {
    const lines = ["# Inferno AoIP node configuration\n# Managed via Cockpit\n"];
    for (const [k, v] of Object.entries(conf)) lines.push(k + "=" + v + "\n");
    return lines.join("");
}

async function loadConfig() {
    let liveName = "";
    try {
        const svcText = await cockpit.file(LIBRESPOT_SVC).read();
        const m = (svcText || "").match(/--name\s+"([^"]+)"/);
        if (m) liveName = m[1];
    } catch (_) {}

    const confText = await cockpit.file(CONF, { superuser: "try" }).read().catch(function() { return ""; });
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
    const sel = $("cfg-nic");
    sel.innerHTML = "";
    function add(v, label) { sel.add(new Option(label, v, false, v === current)); }
    try {
        const out = await sp(["ip", "-o", "link", "show"]);
        for (const line of out.split("\n")) {
            const m = line.match(/^\d+:\s+(\S+):/);
            if (!m) continue;
            const nic = m[1];
            if (nic === "lo" || /^(docker|br-|veth|tun|tap|wl|virbr)/.test(nic)) continue;
            add(nic, nic);
        }
    } catch (_) {}
    if (current && current !== "auto" && ![...sel.options].some(function(o) { return o.value === current; }))
        add(current, current + " (from config)");
    sel.value = current || "auto";
}

// ── Audio card discovery ───────────────────────────────────────────────────────
async function populateAudio(current) {
    const sel = $("cfg-audio");
    sel.innerHTML = "";
    try {
        const out = await sp(["cat", "/proc/asound/cards"]);
        const seen = new Set();
        for (const line of out.split("\n")) {
            const m = line.match(/^\s*(\d+)\s+\[([^\]]+)\]/);
            if (!m || seen.has(m[1])) continue;
            seen.add(m[1]);
            sel.add(new Option("Card " + m[1] + " -- " + m[2].trim(), m[1], false, m[1] === current));
        }
    } catch (_) {}
    if (!sel.options.length) sel.add(new Option("Card 0 (default)", "0"));
    sel.value = current || "0";
}

// ── Save config ────────────────────────────────────────────────────────────────
async function saveConfig() {
    const btn   = $("btn-save");
    const label = $("save-label");
    btn.disabled = true;
    label.innerHTML = '<span class="spinner"></span> Applying\u2026';

    const newName     = $("cfg-name").value.trim();
    const oldName     = currentConf.INFERNO_NAME || "";
    const nameChanged = newName && newName !== oldName;

    try {
        const newConf = Object.assign({}, currentConf, {
            INFERNO_MODE:       $("cfg-mode").value,
            INFERNO_NAME:       newName,
            INFERNO_NIC:        $("cfg-nic").value,
            INFERNO_AUDIO_CARD: $("cfg-audio").value,
        });
        await cockpit.file(CONF, { superuser: "require" }).replace(buildConfText(newConf));
        currentConf = newConf;
        currentMode = newConf.INFERNO_MODE;

        if (nameChanged) {
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
        toast("Save failed: " + (e.message || String(e)), "error", 0);
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
    const isSystem = SYSTEM_SVCS.includes(svc);
    try {
        const r = isSystem
            ? await sp(["systemctl", "is-active", svc])
            : await spUser("systemctl --user is-active " + svc);
        return r.trim();
    } catch (e) {
        const msg = ((e && e.message) || "").trim().split("\n")[0];
        return msg || "unknown";
    }
}

async function refreshServices() {
    const svcs     = activeSvcs();
    const statuses = await Promise.all(svcs.map(getSvcStatus));
    const grid     = $("svc-grid");
    grid.innerHTML = "";

    svcs.forEach(function(svc, i) {
        const state    = statuses[i] || "unknown";
        const cls      = ["active","inactive","failed"].includes(state) ? state : "unknown";
        const info     = SVC_LABELS[svc] || { label: svc, desc: "" };
        const isSystem = SYSTEM_SVCS.includes(svc);

        const card = document.createElement("div");
        card.className = "svc-card " + cls;

        const top = document.createElement("div");

        const nameEl = document.createElement("div");
        nameEl.className = "svc-name";
        nameEl.textContent = info.label;
        if (isSystem) {
            const tag = document.createElement("span");
            tag.className = "svc-system-tag";
            tag.textContent = " (system)";
            nameEl.appendChild(tag);
        }
        top.appendChild(nameEl);

        const descEl = document.createElement("div");
        descEl.className = "svc-type";
        descEl.textContent = info.desc;
        top.appendChild(descEl);
        card.appendChild(top);

        const statusEl = document.createElement("div");
        statusEl.className = "svc-status";
        const dot = document.createElement("span");
        dot.className = "status-dot " + cls;
        const stateText = document.createElement("span");
        stateText.textContent = state;
        statusEl.appendChild(dot);
        statusEl.appendChild(stateText);
        card.appendChild(statusEl);

        const actEl = document.createElement("div");
        actEl.className = "svc-actions";
        ["restart","start","stop"].forEach(function(cmd) {
            const b = document.createElement("button");
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
    const t = toast(cmd + " " + svc + "\u2026", "info", 0);
    try {
        if (isSystem) {
            await spRoot(["systemctl", cmd, svc]);
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
    const t = toast("Restarting all Inferno services\u2026", "info", 0);
    try {
        for (const svc of SYSTEM_SVCS)
            await spRoot(["systemctl", "restart", svc]).catch(function() {});
        const userSvcs = currentMode === "spotify" ? SPOTIFY_SVCS : AUX_SVCS;
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
function addInfoRow(table, key, valueHtml, cls) {
    const tr  = document.createElement("tr");
    const td1 = document.createElement("td");
    td1.className = "info-key";
    td1.textContent = key;
    const td2 = document.createElement("td");
    if (cls) td2.className = cls;
    td2.innerHTML = valueHtml;
    tr.appendChild(td1);
    tr.appendChild(td2);
    table.appendChild(tr);
}

function codeVal(v) { return "<code>" + v + "</code>"; }

async function refreshSystemInfo() {
    const table = $("info-table");
    table.innerHTML = "";

    try {
        const hn = (await sp(["hostname"])).trim();
        addInfoRow(table, "Hostname", codeVal(hn));
        $("hdr-hostname").textContent = hn;
    } catch (_) {}

    const nic = currentConf.INFERNO_NIC || "eno1";
    try {
        const ip = (await sp(["bash", "-c", "ip -4 addr show " + nic + " 2>/dev/null | awk '/inet /{print $2}'"])).trim();
        addInfoRow(table, "IP Address", codeVal(ip));
        $("hdr-ip").textContent = ip;
    } catch (_) {}

    try {
        const mac = (await sp(["cat", "/sys/class/net/" + nic + "/address"])).trim();
        addInfoRow(table, "MAC / NIC", codeVal(mac) + " on " + codeVal(nic));
    } catch (_) {}

    try {
        const ptpLine = (await spRoot(["bash", "-c",
            "journalctl -u statime-inferno -n 30 --no-pager -o cat | grep -oE 'Estimated offset [0-9.+-]+ns' | tail -1"
        ])).trim();
        if (ptpLine) {
            addInfoRow(table, "PTP Offset", codeVal(ptpLine), "text-success");
            $("hdr-ptp").textContent = "PTP " + ptpLine;
        } else {
            addInfoRow(table, "PTP Offset", "no recent data", "text-muted");
            $("hdr-ptp").textContent = "PTP syncing\u2026";
        }
    } catch (_) {
        addInfoRow(table, "PTP Offset", "no recent data", "text-muted");
    }

    try {
        const loop = (await sp(["bash", "-c", "cat /proc/asound/cards | grep -i loopback | head -1"])).trim();
        if (loop) {
            addInfoRow(table, "snd-aloop", codeVal(loop));
        } else {
            addInfoRow(table, "snd-aloop", "not loaded \u26a0", "text-danger");
        }
    } catch (_) {}

    const sentinel = await cockpit.file(SENTINEL).read().catch(function() { return null; });
    if (sentinel !== null) {
        addInfoRow(table, "Deploy sentinel", "\u2705 present", "text-success");
    } else {
        addInfoRow(table, "Deploy sentinel", "\u26a0 missing \u2014 will re-deploy on next reboot", "text-warning");
    }
}

// ── Header mode badge ──────────────────────────────────────────────────────────
function refreshHeader() {
    const badge = $("hdr-mode-badge");
    const mode  = currentMode || "spotify";
    badge.innerHTML = "";
    const span = document.createElement("span");
    span.className = "mode-badge " + mode;
    span.textContent = mode;
    badge.appendChild(span);
}

// ── Journal ────────────────────────────────────────────────────────────────────
function colorizeLog(text) {
    return text.split("\n").map(function(line) {
        const ts   = line.match(/^(\S+T\S+)\s+(.*)/);
        const raw  = ts ? ts[2] : line;
        const date = ts ? '<span class="log-ts">' + ts[1] + " </span>" : "";
        const lo   = raw.toLowerCase();
        if (/\berr(or)?\b|failed|fatal/.test(lo)) return date + '<span class="log-err">' + raw + "</span>";
        if (/\bwarn/.test(lo))                    return date + '<span class="log-warn">' + raw + "</span>";
        if (/\bok\b|success|ready|running|active|started/.test(lo)) return date + '<span class="log-ok">' + raw + "</span>";
        return date + raw;
    }).join("\n");
}

async function loadLog() {
    const svc = $("log-svc-select").value;
    const box = $("log-box");
    box.textContent = "Loading\u2026";
    const isSystem = SYSTEM_SVCS.includes(svc);
    try {
        const out = isSystem
            ? await spRoot(["journalctl", "-u", svc, "-n", "100", "--no-pager", "--output=short"])
            : await spUser("journalctl --user -u " + svc + " -n 100 --no-pager --output=short");
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
        await spRoot(["rm", "-f", SENTINEL]);
        toast("Sentinel removed. Rebooting\u2026", "info", 0);
        await spRoot(["systemctl", "reboot"]);
    } catch (e) { toast("Error: " + ((e && e.message) || String(e)), "error", 0); }
}

async function triggerReboot() {
    if (!confirm("Reboot the node?")) return;
    try {
        toast("Rebooting\u2026", "info", 0);
        await spRoot(["systemctl", "reboot"]);
    } catch (e) { toast("Reboot error: " + ((e && e.message) || String(e)), "error", 0); }
}

// ── Init ───────────────────────────────────────────────────────────────────────
async function refreshAll() {
    await Promise.all([refreshServices(), refreshSystemInfo()]);
    refreshHeader();
}

async function init() {
    try {
        const u = await cockpit.user();
        USER_UID = u.id;
    } catch (_) {}

    await loadConfig();
    refreshHeader();
    await refreshAll();
    await loadLog();
}

init().catch(function(e) { toast("Init error: " + String(e), "error", 0); });
setInterval(refreshServices, 20000);
