#!/usr/bin/env bash
#
# fix-clamshell.sh -- turn the laptop panel off while the lid is shut and an
# external display is connected (Ryoku + Hyprland 0.56 Lua config).
#
# Why: ryoku-clamshell disables the panel with
#   hyprctl eval 'hl.monitor({ output = "eDP-1", disabled = true })'
# which Hyprland 0.56 acknowledges with "ok" but never applies. The panel stays
# live behind the closed lid and the external display lags and flickers black
# every few seconds. A rule evaluated at config load does apply, so this script
# installs a marked block in ~/.config/hypr/user.lua that decides from the
# hardware state at load time, plus lid binds that reload the config on every
# lid edge. Ryoku's own lid binds keep running (suspend policy unchanged).
#
# Usage:
#   ./fix-clamshell.sh              install or update the block, then reload
#   ./fix-clamshell.sh --uninstall  remove the block, then reload
#
# Safe to run repeatedly: an existing block is replaced, never duplicated, and
# user.lua is backed up first (user.lua.bak-<timestamp>).

set -euo pipefail

USER_LUA="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/user.lua"
BEGIN='-- >>> clamshell-panel-off >>>'
END='-- <<< clamshell-panel-off <<<'

die() { printf 'fix-clamshell: %s\n' "$*" >&2; exit 1; }
say() { printf 'fix-clamshell: %s\n' "$*"; }

# The internal panel's connector name (eDP-1 on most laptops).
detect_panel() {
  local c n
  for c in /sys/class/drm/card*-eDP-* /sys/class/drm/card*-LVDS-* /sys/class/drm/card*-DSI-*; do
    [[ -e $c ]] || continue
    n=${c##*/}; printf '%s\n' "${n#card*-}"; return 0
  done
  return 1
}

# Print user.lua without the marked block (if any).
strip_block() {
  awk -v b="$BEGIN" -v e="$END" '
    $0 == b { skip = 1; next }
    $0 == e { skip = 0; next }
    !skip
  ' "$USER_LUA"
}

reload_hyprland() {
  if command -v hyprctl >/dev/null 2>&1 && hyprctl version >/dev/null 2>&1; then
    hyprctl reload >/dev/null
    local errs
    errs="$(hyprctl configerrors 2>/dev/null | tr -d '[:space:]')"
    [[ -z $errs ]] || say "warning: Hyprland reports config errors; run: hyprctl configerrors"
    say "Hyprland reloaded"
  else
    say "Hyprland is not running here; the fix applies at next login"
  fi
}

block() {
  local panel=$1
  cat <<EOF
$BEGIN
-- Turn the laptop panel off while the lid is shut and an external display is
-- connected. ryoku-clamshell tries this through a runtime \`hyprctl eval
-- hl.monitor({ disabled = true })\`, which Hyprland 0.56 acks without applying,
-- so the panel stayed live behind the closed lid and the external display lagged
-- and flickered. A rule evaluated during config load does apply, so decide here
-- from the hardware state and reload on every lid edge. ryoku-monitor's hotplug
-- reloads re-run this too. Installed by fix-clamshell.sh; run it with
-- --uninstall (or delete this block) to undo.
local function clamshell_read(cmd)
    local p = io.popen(cmd)
    if not p then return "" end
    local out = p:read("*a") or ""
    p:close()
    return out
end

local function clamshell_lid_closed()
    return clamshell_read("cat /proc/acpi/button/lid/*/state 2>/dev/null"):find("closed") ~= nil
end

local function clamshell_external_connected()
    local out = clamshell_read("cat /sys/class/drm/card*-DP-*/status /sys/class/drm/card*-HDMI-A-*/status 2>/dev/null")
    return out:find("^connected") ~= nil or out:find("\nconnected") ~= nil
end

if clamshell_lid_closed() and clamshell_external_connected() then
    hl.monitor({ output = "$panel", disabled = true })
end

hl.bind("switch:on:Lid Switch",  hl.dsp.exec_cmd("hyprctl reload"), { locked = true })
hl.bind("switch:off:Lid Switch", hl.dsp.exec_cmd("hyprctl reload"), { locked = true })
$END
EOF
}

main() {
  local mode=install tmp panel
  case "${1:-}" in
    "") ;;
    --uninstall) mode=uninstall ;;
    -h|--help) sed -n '2,23p' "$0"; exit 0 ;;
    *) die "unknown option: $1 (use --uninstall or --help)" ;;
  esac

  [[ -d ${USER_LUA%/*} ]] || die "${USER_LUA%/*} not found; is Ryoku/Hyprland installed for this user?"

  if [[ $mode == uninstall ]]; then
    [[ -f $USER_LUA ]] && grep -Fxq -- "$BEGIN" "$USER_LUA" || { say "nothing to remove"; exit 0; }
    cp -p -- "$USER_LUA" "$USER_LUA.bak-$(date +%Y%m%d-%H%M%S)"
    tmp="$(mktemp "${USER_LUA}.XXXXXX")"
    # Drop the blank line the install added before the block.
    strip_block | sed -e :a -e '/^\n*$/{$d;N;ba' -e '}' >"$tmp"
    mv -- "$tmp" "$USER_LUA"
    say "removed the clamshell block from $USER_LUA"
    reload_hyprland
    exit 0
  fi

  [[ -d /proc/acpi/button/lid ]] || die "no ACPI lid found; this fix is for laptops"
  panel="$(detect_panel)" || die "no internal panel (eDP/LVDS/DSI) connector found"

  tmp="$(mktemp "${USER_LUA}.XXXXXX")"
  trap 'rm -f -- "$tmp"' EXIT
  if [[ -f $USER_LUA ]]; then
    cp -p -- "$USER_LUA" "$USER_LUA.bak-$(date +%Y%m%d-%H%M%S)"
    strip_block >"$tmp"
  fi
  { printf '\n'; block "$panel"; } >>"$tmp"
  # Collapse runs of blank lines left behind by replacing an older block.
  cat -s -- "$tmp" >"$tmp.s" && mv -- "$tmp.s" "$tmp"
  mv -- "$tmp" "$USER_LUA"
  trap - EXIT
  say "installed the clamshell block for panel $panel in $USER_LUA"
  reload_hyprland
}

main "$@"
