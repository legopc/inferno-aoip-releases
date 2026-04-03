#!/usr/bin/env python3
"""
inferno-web.py — Inferno AoIP minimal web config UI
Runs on port 8080 as the 'core' user.
Deployed to: /var/lib/inferno/bin/inferno-web.py

Endpoints:
  GET  /          — Config form (read/write /etc/inferno.conf)
  POST /save      — Save config and optionally restart services
  GET  /status    — JSON service status
  POST /update    — Remove sentinel + reboot to re-run deploy script
"""

import http.server
import json
import os
import subprocess
import urllib.parse

CONF = "/etc/inferno.conf"
SENTINEL = "/var/lib/inferno/.deployed"
PORT = 8080

STYLE = """
<style>
  body { font-family: sans-serif; max-width: 640px; margin: 40px auto; padding: 0 16px; }
  h1 { color: #1a1a2e; }
  label { display: block; margin-top: 12px; font-weight: bold; }
  input, select { width: 100%; padding: 8px; margin-top: 4px; box-sizing: border-box; }
  .btn { padding: 10px 20px; margin: 8px 4px 0 0; cursor: pointer; border: none; border-radius: 4px; }
  .btn-primary { background: #16213e; color: white; }
  .btn-danger  { background: #c0392b; color: white; }
  .status { font-family: monospace; font-size: 12px; }
  .ok  { color: green; } .fail { color: red; } .inactive { color: grey; }
  .note { background: #fff3cd; padding: 8px; border-radius: 4px; margin-top: 16px; font-size: 13px; }
</style>
"""

def read_conf():
    conf = {}
    if os.path.exists(CONF):
        with open(CONF) as f:
            for line in f:
                line = line.strip()
                if line and not line.startswith('#') and '=' in line:
                    k, _, v = line.partition('=')
                    conf[k.strip()] = v.strip()
    return conf

def service_status(name, user=False):
    try:
        flag = ['--user'] if user else []
        r = subprocess.run(
            ['systemctl'] + flag + ['is-active', name],
            capture_output=True, text=True, timeout=3
        )
        return r.stdout.strip()
    except Exception:
        return 'unknown'

def all_status():
    mode = read_conf().get('INFERNO_MODE', 'spotify')
    services = [('statime-inferno', False)]
    if mode == 'spotify':
        services += [
            ('inferno-bridge', True),
            ('inferno-keepalive', True),
            ('librespot', True),
            ('librespot-watchdog', True),
        ]
    elif mode == 'aux':
        services += [
            ('inferno-aux-tx', True),
            ('inferno-aux-rx', True),
            ('inferno-aux-keepalive', True),
        ]
    services.append(('inferno-web', True))
    return {name: service_status(name, user) for name, user in services}

class Handler(http.server.BaseHTTPRequestHandler):

    def log_message(self, fmt, *args):
        pass  # suppress per-request logging

    def send_html(self, body, code=200):
        content = body.encode()
        self.send_response(code)
        self.send_header('Content-Type', 'text/html; charset=utf-8')
        self.send_header('Content-Length', len(content))
        self.end_headers()
        self.wfile.write(content)

    def send_json(self, data, code=200):
        content = json.dumps(data, indent=2).encode()
        self.send_response(code)
        self.send_header('Content-Type', 'application/json')
        self.send_header('Content-Length', len(content))
        self.end_headers()
        self.wfile.write(content)

    def do_GET(self):
        if self.path == '/status':
            self.send_json({'services': all_status(), 'sentinel': os.path.exists(SENTINEL)})
        elif self.path == '/':
            self.serve_form()
        else:
            self.send_response(404); self.end_headers()

    def do_POST(self):
        length = int(self.headers.get('Content-Length', 0))
        body = urllib.parse.parse_qs(self.rfile.read(length).decode())
        if self.path == '/save':
            self.handle_save(body)
        elif self.path == '/update':
            self.handle_update()
        else:
            self.send_response(404); self.end_headers()

    def serve_form(self):
        conf = read_conf()
        status = all_status()
        rows = ''.join(
            f'<tr><td>{n}</td>'
            f'<td class="status {s if s in ("active","inactive") else "fail"}">{s}</td></tr>'
            for n, s in status.items()
        )
        deployed = os.path.exists(SENTINEL)
        mode = conf.get('INFERNO_MODE', 'spotify')

        html = f"""<!DOCTYPE html><html><head><title>Inferno Config</title>{STYLE}</head><body>
<h1>🔥 Inferno AoIP</h1>
<table border=1 cellpadding=6 style="border-collapse:collapse;width:100%">
  <tr><th>Service</th><th>Status</th></tr>{rows}
</table>

<form method="POST" action="/save">
  <label>Mode
    <select name="INFERNO_MODE">
      <option value="spotify" {"selected" if mode=="spotify" else ""}>spotify</option>
      <option value="aux" {"selected" if mode=="aux" else ""}>aux</option>
    </select>
  </label>
  <label>Device name (shown in Dante Controller / Spotify)
    <input name="INFERNO_NAME" value="{conf.get('INFERNO_NAME','')}">
  </label>
  <label>NIC (or 'auto')
    <input name="INFERNO_NIC" value="{conf.get('INFERNO_NIC','auto')}">
  </label>
  <label>Audio card number (aux mode only)
    <input name="INFERNO_AUDIO_CARD" value="{conf.get('INFERNO_AUDIO_CARD','0')}">
  </label>
  <button class="btn btn-primary" type="submit">Save config</button>
</form>

<form method="POST" action="/update" onsubmit="return confirm('This will remove the deploy sentinel and reboot. The node will re-download binaries on next boot. Continue?')">
  <button class="btn btn-danger" type="submit">🔄 Update Inferno binaries</button>
</form>

<div class="note">
  <b>Tip:</b> After saving config, restart the relevant services via
  <a href="https://{'localhost'}:9090">Cockpit</a> (port 9090) or SSH.<br>
  Deployed: {"✅ yes" if deployed else "⚠️ not yet"} &nbsp;|&nbsp;
  Config: <code>{CONF}</code>
</div>
</body></html>"""
        self.send_html(html)

    def handle_save(self, body):
        conf = read_conf()
        for key in ('INFERNO_MODE', 'INFERNO_NAME', 'INFERNO_NIC', 'INFERNO_AUDIO_CARD'):
            if key in body:
                conf[key] = body[key][0]
        lines = [f"# Inferno AoIP node configuration\n"]
        for k, v in conf.items():
            lines.append(f"{k}={v}\n")
        try:
            subprocess.run(['sudo', 'tee', CONF], input=''.join(lines).encode(),
                           capture_output=True, check=True)
            self.send_response(303)
            self.send_header('Location', '/?saved=1')
            self.end_headers()
        except Exception as e:
            self.send_html(f"<p>Error saving: {e}</p>", 500)

    def handle_update(self):
        try:
            subprocess.run(['sudo', 'rm', '-f', SENTINEL], check=True)
            self.send_html("<p>Sentinel removed. Rebooting in 3s...</p>")
            subprocess.Popen(['sudo', 'systemctl', 'reboot'])
        except Exception as e:
            self.send_html(f"<p>Error: {e}</p>", 500)


if __name__ == '__main__':
    print(f"Inferno web UI running on port {PORT}")
    httpd = http.server.HTTPServer(('', PORT), Handler)
    httpd.serve_forever()
