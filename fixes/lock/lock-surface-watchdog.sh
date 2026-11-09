#!/usr/bin/env bash
# Restart the Quickshell lock client when an output is left without a lock
# surface.
#
# Two ways this happens while the session is locked:
#  1. Every output disappears (lid shut, HDMI the only display, and the monitor
#     switches input or sleeps). The client logs "There are no outputs -
#     creating placeholder screen" and never creates a surface for the output
#     when it returns (fix 17).
#  2. An output is added while locked (Hyprland re-enabling eDP-1 when HDMI
#     drops, or the lid opening after a suspend) and the client simply never
#     puts a surface on it, logging nothing. Hyprland draws pure black there,
#     with only the cursor on top (fix 18, 2026-11-09).
# Either way the session stays locked with nothing to type into. Killing the
# client is safe: lock.sh relaunches it, and with misc:allow_session_lock_restore
# the new client takes over the same lock, so the session never unlocks.
#
# Case 2 is detected by capturing each live output (grim, which sees what
# Hyprland composites, cursor excluded): a lock theme always draws text, so a
# frame that is exactly black on two captures 5 s apart has no lock surface.
#
# Triggered by Hyprland monitoradded events, with a 60 s periodic fallback.
# Restarts are rate-limited so a theme that really is black cannot loop.
set -u
rt=${XDG_RUNTIME_DIR:-/run/user/$(id -u)}
sock=$(ls -t "$rt"/hypr/*/.socket2.sock 2>/dev/null | head -1)
[ -n "$sock" ] || { echo "no Hyprland socket"; exit 1; }
export HYPRLAND_INSTANCE_SIGNATURE=$(basename "$(dirname "$sock")")
if [ -z "${WAYLAND_DISPLAY:-}" ]; then
  WAYLAND_DISPLAY=$(ls "$rt" | grep -m1 -E '^wayland-[0-9]+$') && export WAYLAND_DISPLAY
fi

pattern='quickshell -p .*/lock_shell.qml'
cooldown=120        # seconds between restarts
max_strikes=3       # consecutive restarts that did not help, then wait for a new monitor event
last_restart=0
strikes=0

# Live outputs: enabled, powered (DPMS on), and not Hyprland's FALLBACK.
live_outputs() {
  hyprctl monitors -j 2>/dev/null \
    | jq -r '.[] | select(.disabled | not) | select(.dpmsStatus) | select(.name != "FALLBACK") | .name'
}

# Print the live outputs whose composited frame is exactly black.
black_outputs() {
  local o
  for o in $(live_outputs); do
    grim -t ppm -s 0.125 -o "$o" - 2>/dev/null | python3 -I -c '
import sys
d = sys.stdin.buffer.read()
# Binary PPM: "P6" w h maxval, each separated by whitespace, then 1 byte.
i, fields = 0, []
while len(fields) < 4 and i < len(d):
    while i < len(d) and d[i:i+1].isspace(): i += 1
    j = i
    while j < len(d) and not d[j:j+1].isspace(): j += 1
    fields.append(d[i:j]); i = j
px = d[i+1:]
sys.exit(0 if fields[:1] == [b"P6"] and px and not px.strip(b"\0") else 1)
' && printf '%s\n' "$o"
  done
}

check() {
  local pid reason="" blank1 blank2 now age
  pid=$(pgrep -o -f "$pattern") || { strikes=0; return 0; }   # not locked
  # Only act once a real output is back; with none, a new client is no better.
  [ -n "$(live_outputs)" ] || return 0
  # Give a freshly started client time to draw its first frame.
  age=$(ps -o etimes= -p "$pid" 2>/dev/null | tr -d ' ')
  [ "${age:-0}" -ge 15 ] || return 0

  if timeout 5 quickshell log --pid "$pid" 2>/dev/null \
       | grep -q 'There are no outputs - creating placeholder screen'; then
    reason="it lost every output"
  else
    blank1=$(black_outputs)
    if [ -n "$blank1" ]; then
      sleep 5
      [ "$(pgrep -o -f "$pattern")" = "$pid" ] || return 0      # unlocked or replaced
      blank2=$(black_outputs)
      blank2=$(comm -12 <(sort <<<"$blank1") <(sort <<<"$blank2") | paste -sd' ')
      [ -n "$blank2" ] && reason="no lock surface on $blank2"
    fi
  fi
  if [ -z "$reason" ]; then strikes=0; return 0; fi

  now=$(date +%s)
  if [ $((now - last_restart)) -lt "$cooldown" ]; then return 0; fi
  if [ "$strikes" -ge "$max_strikes" ]; then return 0; fi
  echo "lock client $pid: $reason; restarting it"
  last_restart=$now
  strikes=$((strikes + 1))
  kill "$pid"
}

check
socat -U - "UNIX-CONNECT:$sock" | while :; do
  if read -r -t 60 line; then
    case $line in monitoradded*) strikes=0; sleep 3; check ;; esac
  else
    [ $? -gt 128 ] || exit 0   # EOF: Hyprland gone, let systemd restart us
    check
  fi
done
