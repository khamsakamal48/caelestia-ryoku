#!/usr/bin/env bash
# Restart the Quickshell lock client when it has lost its lock surfaces.
#
# If every output disappears while the session is locked (lid shut, HDMI the
# only display, and the monitor switches input or sleeps), the lock client
# logs "There are no outputs - creating placeholder screen" and never creates
# a lock surface for the output when it returns. Hyprland keeps the session
# locked with nothing drawn: a black screen that ignores input, locally and
# over VNC. Killing the client is safe: lock.sh relaunches it, and with
# misc:allow_session_lock_restore the new client takes over the same lock.
#
# Triggered by Hyprland monitoradded events, with a 60s periodic fallback.
set -u
rt=${XDG_RUNTIME_DIR:-/run/user/$(id -u)}
sock=$(ls -t "$rt"/hypr/*/.socket2.sock 2>/dev/null | head -1)
[ -n "$sock" ] || { echo "no Hyprland socket"; exit 1; }
export HYPRLAND_INSTANCE_SIGNATURE=$(basename "$(dirname "$sock")")

pattern='quickshell -p .*/lock_shell.qml'

check() {
  local pid
  pid=$(pgrep -o -f "$pattern") || return 0              # not locked
  # Only act once a real output is back; with none, a new client is no better.
  # (Hyprland's own FALLBACK output does not count.)
  hyprctl monitors -j 2>/dev/null | grep '"name":' | grep -qv FALLBACK || return 0
  timeout 5 quickshell log --pid "$pid" 2>/dev/null \
    | grep -q 'There are no outputs - creating placeholder screen' || return 0
  echo "lock client $pid lost its outputs; restarting it"
  kill "$pid"
}

check
socat -U - "UNIX-CONNECT:$sock" | while :; do
  if read -r -t 60 line; then
    case $line in monitoradded*) sleep 3; check ;; esac
  else
    [ $? -gt 128 ] || exit 0   # EOF: Hyprland gone, let systemd restart us
    check
  fi
done
