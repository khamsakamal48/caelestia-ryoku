#!/usr/bin/env bash
#
# install.sh -- install the AC-awake ryoku-clamshell wrapper (fixes 2 + 18).
#
# Three places call ryoku-clamshell, and all three must get the wrapper:
#   1. the ryoku-clamshell.service daemon   -> systemd drop-in (ExecStart)
#   2. Hyprland's lid binds and `lid sync`  -> PATH set in ~/.config/hypr/user.lua
#   3. anything else on PATH                -> same PATH entry
# The wrapper lives in ~/.local/lib/ryoku-fixes/bin, NOT ~/.local/bin: `ryoku
# doctor` deletes ~/.local/bin files that shadow packaged commands.
#
# The user.lua block also checks on every Hyprland start/reload that the
# wrapper and drop-in still exist, and raises a critical notification if an
# update removed them.
#
# Usage:
#   ./install.sh              install or update, then restart the daemon
#   ./install.sh --uninstall  remove everything this script installed
#
# Safe to re-run. user.lua is backed up before each change.

set -euo pipefail

HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
BIN_DIR="$HOME/.local/lib/ryoku-fixes/bin"
WRAPPER="$BIN_DIR/ryoku-clamshell"
DROPIN_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user/ryoku-clamshell.service.d"
DROPIN="$DROPIN_DIR/ac-awake.conf"
USER_LUA="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/user.lua"
BEGIN='-- >>> clamshell-ac-awake >>>'
END='-- <<< clamshell-ac-awake <<<'

say() { printf 'clamshell-fix: %s\n' "$*"; }
die() { printf 'clamshell-fix: %s\n' "$*" >&2; exit 1; }

strip_block() {
  awk -v b="$BEGIN" -v e="$END" '
    $0 == b { skip = 1; next }
    $0 == e { skip = 0; next }
    !skip
  ' "$USER_LUA"
}

block() {
  cat <<EOF
$BEGIN
-- AC-awake clamshell (caelestia-ryoku fixes/clamshell, fixes 2 + 18). Put the
-- wrapper ahead of /usr/bin so Hyprland's lid binds and \`lid sync\` use its
-- policy, and warn loudly if a Ryoku update deleted the wrapper or drop-in.
-- Installed by fixes/clamshell/install.sh; --uninstall removes this block.
do
    local home = os.getenv("HOME") or ""
    local dir = home .. "/.local/lib/ryoku-fixes/bin"
    local path = os.getenv("PATH") or "/usr/bin"
    if not (":" .. path .. ":"):find(":" .. dir .. ":", 1, true) then
        hl.env("PATH", dir .. ":" .. path)
    end
    local function missing(p)
        local f = io.open(p, "r")
        if f then f:close(); return false end
        return true
    end
    if missing(dir .. "/ryoku-clamshell")
        or missing(home .. "/.config/systemd/user/ryoku-clamshell.service.d/ac-awake.conf") then
        hl.exec_cmd("notify-send -u critical 'Clamshell fix missing' "
            .. "'A docked, lid-shut laptop may suspend. Re-run caelestia-ryoku/fixes/clamshell/install.sh'")
    end
end
$END
EOF
}

write_user_lua() {  # <with-block: 0|1>
  local tmp
  [[ -d ${USER_LUA%/*} ]] || die "${USER_LUA%/*} not found"
  tmp="$(mktemp "${USER_LUA}.XXXXXX")"
  if [[ -f $USER_LUA ]]; then
    cp -p -- "$USER_LUA" "$USER_LUA.bak-$(date +%Y%m%d-%H%M%S)"
    strip_block >"$tmp"
    chmod --reference="$USER_LUA" "$tmp"
  fi
  if [[ $1 == 1 ]]; then
    { printf '\n'; block; } >>"$tmp"
  fi
  cat -s -- "$tmp" >"$tmp.s" && mv -- "$tmp.s" "$tmp"
  mv -- "$tmp" "$USER_LUA"
}

reload() {
  systemctl --user daemon-reload
  systemctl --user restart ryoku-clamshell.service
  if command -v hyprctl >/dev/null 2>&1 && hyprctl version >/dev/null 2>&1; then
    hyprctl reload >/dev/null
    say "Hyprland reloaded"
  fi
}

case "${1:-}" in
  "")
    grep -qE '^clamshell_wanted\(\)' /usr/bin/ryoku-clamshell \
      && grep -qE '^disable_internal_panels\(\)' /usr/bin/ryoku-clamshell \
      && grep -qF 'if [[ ${BASH_SOURCE[0]} == "$0" ]]; then' /usr/bin/ryoku-clamshell \
      || die "/usr/bin/ryoku-clamshell changed shape; port the wrapper by hand (see README fix 18)"
    install -Dm755 "$HERE/ryoku-clamshell" "$WRAPPER"
    install -Dm644 "$HERE/ac-awake.conf" "$DROPIN"
    # The first install lived in ~/.local/bin; ryoku doctor deletes it there.
    rm -f -- "$HOME/.local/bin/ryoku-clamshell"
    write_user_lua 1
    reload
    say "installed: $WRAPPER, $DROPIN, user.lua block"
    ;;
  --uninstall)
    rm -f -- "$WRAPPER" "$DROPIN"
    rmdir -- "$DROPIN_DIR" "$BIN_DIR" 2>/dev/null || true
    [[ -f $USER_LUA ]] && grep -Fxq -- "$BEGIN" "$USER_LUA" && write_user_lua 0
    reload
    say "removed; stock ryoku-clamshell policy is back"
    ;;
  -h|--help) sed -n '2,21p' "$0" ;;
  *) die "unknown option: $1" ;;
esac
