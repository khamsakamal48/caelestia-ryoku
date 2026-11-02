#!/usr/bin/env bash
# Watchdog for ryogami's random wallpaper rotation. Run every minute by
# rotation-watchdog.timer.
#
# Why: rotation can report "active" and still never change the wallpaper.
# Seen 2026-10-30 (13+ minutes on 300 s) and 2026-10-31 to 11-02 (36 h awake
# in clamshell on 3590 s, same wallpaper throughout). ryogami's timer also
# pauses during suspend and starts over on every daemon restart, so a long
# interval on a laptop that sleeps or logs in often may never be reached.
#
# What it does: while "Rotate automatically" is on and ryogami reports
# rotation active, it remembers when the wallpaper last changed (from
# ~/.cache/ryogami/outputs.json). Once it has not changed for the interval
# plus 60 s of wall-clock time, it makes ryogami swap now (rotation restarted
# on a 10 s interval until the wallpaper changes), then restarts rotation on
# the interval from settings. Sources, favourites and weather matching stay
# ryogami's own. A wallpaper picked by hand resets the countdown. If rotation
# was stopped with the picker button, it does nothing.
set -euo pipefail

SOCK=${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/ryogami.sock
SETTINGS=${XDG_CONFIG_HOME:-$HOME/.config}/ryoku/ryogami.json
OUTPUTS=${XDG_CACHE_HOME:-$HOME/.cache}/ryogami/outputs.json
STATE=${XDG_STATE_HOME:-$HOME/.local/state}/ryoku/rotation-watchdog.json

[[ -S $SOCK ]] || exit 0   # ryogami not running: nothing to watch

python3 -I - "$SOCK" "$SETTINGS" "$OUTPUTS" "$STATE" <<'EOF'
import hashlib, json, os, socket, sys, time

sock, settings, outputs, state_path = sys.argv[1:]
GRACE = 60      # past the interval before stepping in
KICK_WAIT = 45  # seconds to wait for the forced swap

try:
    with open(settings) as f:
        general = json.load(f).get("general") or {}
except (OSError, ValueError):
    general = {}

def val(key, default):
    return general.get(key, default)

def call(method, params=None):
    s = socket.socket(socket.AF_UNIX)
    s.settimeout(10)
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

def signature():
    try:
        with open(outputs, "rb") as f:
            return hashlib.sha256(f.read()).hexdigest()
    except OSError:
        return None

def save(sig, since):
    os.makedirs(os.path.dirname(state_path), exist_ok=True)
    with open(state_path, "w") as f:
        json.dump({"sig": sig, "since": since}, f)

if val("randomRotate", False) is not True:
    sys.exit(0)
if call("wall.rotation_status").get("active") is not True:
    sys.exit(0)

# Same keys and defaults as FilterBar.qml's toggleRotation().
types = [t for key, t in (("randomIncludeStatic", "static"),
                          ("randomIncludeVideo", "video"),
                          ("randomIncludeWE", "we")) if val(key, True) is True]
if not types:
    sys.exit(0)
interval = max(10, int(val("randomInterval", 300)))
favourites = val("randomIncludeFavourites", False) is True

now = time.time()
sig = signature()
try:
    with open(state_path) as f:
        state = json.load(f)
except (OSError, ValueError):
    state = {}

if sig != state.get("sig"):
    save(sig, now)
    sys.exit(0)

stale = now - state.get("since", now)
if stale < interval + GRACE:
    sys.exit(0)

print(f"no wallpaper change for {int(stale)} s (interval {interval} s): forcing a swap")
call("wall.rotation_stop")
call("wall.random_start", {"interval": 10, "types": types, "favourites_only": favourites})
deadline = time.time() + KICK_WAIT
while time.time() < deadline and signature() == sig:
    time.sleep(2)
changed = signature() != sig
call("wall.rotation_stop")
call("wall.random_start", {"interval": interval, "types": types, "favourites_only": favourites})
save(signature(), time.time())
if not changed:
    sys.exit(f"error: no wallpaper change within {KICK_WAIT} s of the forced swap")
print(f"wallpaper swapped; rotation restarted every {interval} s")
EOF
