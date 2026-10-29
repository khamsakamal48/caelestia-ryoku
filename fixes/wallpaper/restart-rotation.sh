#!/usr/bin/env bash
# Restart ryogami's random wallpaper rotation: stop it, then start it again.
#
# Why: rotation can report "active" and still never change the wallpaper
# (seen 2026-10-30: 13+ minutes on the 300 s default, no change, no error in
# the ryogami log). Stopping and starting it fixed it; the first change came
# one interval later. This sends the same two daemon calls the picker's
# auto-rotate button sends, with the same settings it reads.
#
#   fixes/wallpaper/restart-rotation.sh         interval from settings (300 s default)
#   fixes/wallpaper/restart-rotation.sh 60      every 60 s (minimum 10)
#
# The restart lasts until logout or a ryogami restart. To keep rotation on,
# turn on "Rotate automatically" in the picker's settings > Automation.
set -euo pipefail

SOCK=${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/ryogami.sock
SETTINGS=${XDG_CONFIG_HOME:-$HOME/.config}/ryoku/ryogami.json

[[ -S $SOCK ]] || { echo "error: $SOCK missing: is ryogami running? (systemctl --user status ryogami)" >&2; exit 1; }
[[ -z ${1:-} || $1 =~ ^[0-9]+$ ]] || { echo "usage: $0 [interval-seconds]" >&2; exit 2; }

python3 -I - "$SOCK" "$SETTINGS" "${1:-}" <<'EOF'
import json, socket, sys

sock, settings, interval = sys.argv[1:]

# Same keys and defaults as FilterBar.qml's toggleRotation().
try:
    with open(settings) as f:
        general = json.load(f).get("general") or {}
except (OSError, ValueError):
    general = {}

def val(key, default):
    return general.get(key, default)

types = [t for key, t in (("randomIncludeStatic", "static"),
                          ("randomIncludeVideo", "video"),
                          ("randomIncludeWE", "we")) if val(key, True) is True]
if not types:
    sys.exit("error: every random source (images, video, Wallpaper Engine) is off in settings > Automation")

interval = max(10, int(interval or val("randomInterval", 300)))

def call(method, params=None):
    s = socket.socket(socket.AF_UNIX)
    s.settimeout(5)
    s.connect(sock)
    s.sendall((json.dumps({"id": 1, "method": method, "params": params or {}}) + "\n").encode())
    data = b""
    while b"\n" not in data:
        chunk = s.recv(65536)
        if not chunk:
            break
        data += chunk
    s.close()
    reply = json.loads(data)
    if "error" in reply:
        sys.exit(f"error: {method}: {reply['error'].get('message')}")
    return reply.get("result") or {}

call("wall.rotation_stop")
call("wall.random_start", {"interval": interval, "types": types,
                           "favourites_only": val("randomIncludeFavourites", False) is True})
if call("wall.rotation_status").get("active") is not True:
    sys.exit("error: ryogami did not report rotation as active after the restart")
print(f"rotation restarted: every {interval} s from {', '.join(types)}; first change in {interval} s")
EOF
