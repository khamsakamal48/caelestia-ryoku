-- >>> wispr-flow >>>
-- Wispr Flow: stop the compositor from decorating the Flow Bar overlay.
-- Managed by wispr.sh (OneDrive/Arch Linux/wispr-flow): `bash wispr.sh restore`
-- replaces this whole marked block in ~/.config/hypr/user.lua. Delete it to undo.
--
-- The "Status" window is Wispr Flow's Flow Bar: a fully transparent, always
-- mapped 512x586 surface that should show nothing but the small recording pill
-- drawn inside it. The desktop's window decoration (Ryoku: blur, rounding,
-- shadow and inactive_opacity 0.94 in hypr/modules/decoration.lua; caelestia
-- dots did the same in hyprland/rules.lua) applies to the surface's empty
-- alpha, painting the invisible overlay as a frosted, rounded, bordered panel
-- that sits on screen permanently.
--
-- Undoing exactly those effects for this one surface makes it invisible again
-- without touching the Hub window ("Wispr Flow"), which still gets normal
-- decoration. If another Wispr overlay ever shows up as a ghost panel, add its
-- title to the alternation below (`hyprctl clients` prints titles).
hl.window_rule({
    name        = "wispr-flow-bar-undecorated",
    match       = { class = "^(wispr-flow)$", title = "^(Status)$" },
    no_blur     = true,
    no_shadow   = true,
    no_dim      = true,
    no_anim     = true,
    border_size = 0,
    rounding    = 0,
    opacity     = "1.0 override", -- cancel the global (inactive_)opacity
    -- The surface is also 512x586 of invisible INPUT, not just invisible pixels.
    -- Wispr makes it click-through with Electron's setIgnoreMouseEvents(), which
    -- is a no-op under native Wayland (the window reports xwayland: false), so
    -- the empty overlay swallowed every click in its rect on whatever workspace
    -- it sat on. `nofocus` drops it out of Hyprland's pointer hit-test, which is
    -- the same end state the app is asking for.
    -- Cost: the recording pill inside is no longer clickable either (Wispr
    -- briefly flips setIgnoreMouseEvents off for it -- also a Wayland no-op).
    -- If the pill ever needs clicks, launch the AppImage with
    -- --ozone-platform=x11 instead and drop this line: on XWayland Electron's
    -- own toggling works and the compositor need not intervene.
    no_focus    = true,
})

-- Open at login. Hyprland has no XDG autostart manager (Ryoku's own
-- modules/autostart.lua says as much), so ~/.config/autostart/wispr-flow.desktop
-- is written but never run. Run it here instead. The in-app "Open at login"
-- toggle still decides: the app's autostart shim deletes that entry when the
-- toggle is off, and the Exec line follows the AppImage if it moves.
-- Wait (up to 30s) for the tray watcher that `ryoku-shell daemon` owns: Electron
-- checks for org.kde.StatusNotifierWatcher once at startup, and if it is not
-- there yet the app runs with no tray icon for the rest of the session.
hl.on("hyprland.start", function()
    hl.exec_cmd([[for i in $(seq 30); do busctl --user status org.kde.StatusNotifierWatcher >/dev/null 2>&1 && break; sleep 1; done; f="$HOME/.config/autostart/wispr-flow.desktop"; [ -f "$f" ] && eval "$(sed -n 's/^Exec=//p' "$f" | head -n1)"]])
end)
-- <<< wispr-flow <<<

-- >>> clamshell-panel-off >>>
-- Turn the laptop panel off while the lid is shut and an external display is
-- connected. ryoku-clamshell tries this through a runtime `hyprctl eval
-- hl.monitor({ disabled = true })`, which Hyprland 0.56 acks without applying,
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
    hl.monitor({ output = "eDP-1", disabled = true })
end

hl.bind("switch:on:Lid Switch",  hl.dsp.exec_cmd("hyprctl reload"), { locked = true })
hl.bind("switch:off:Lid Switch", hl.dsp.exec_cmd("hyprctl reload"), { locked = true })
-- <<< clamshell-panel-off <<<

-- >>> wayvnc >>>
-- Start the VNC server (config: ~/.config/wayvnc/config, PAM auth). Hyprland's
-- Lua config never reads hyprland.conf, so its `exec-once = wayvnc` never ran.
-- Delete this block to undo.
-- Respawn loop: wayvnc exits when its output goes away (e.g. a display
-- handoff), and nothing would restart it. Output goes to the journal
-- (`journalctl --user -t wayvnc`).
-- XKB_DEFAULT_RULES=macvnc (~/.config/xkb/rules/macvnc) makes the Mac's
-- Command key, which Screen Sharing sends as Alt_L, act as Super.
hl.on("hyprland.start", function()
    hl.exec_cmd("while :; do XKB_DEFAULT_RULES=macvnc systemd-cat -t wayvnc wayvnc; sleep 2; done")
end)
-- <<< wayvnc <<<


-- >>> ryo-apps-tile >>>
-- Fit Ryoku's own app windows to the Caelestia frame, so they sit inside
-- the Caelestia bar and border and get the normal gaps like every other
-- window. Ryoku's shipped modules/window_rules.lua floats them at fixed sizes
-- (Ryoku Settings at 99% x 96% of the monitor, Ryoport's SSH terminal at
-- 900x560), and floating windows skip the layout, its gaps and the bar's
-- reserved space. user.lua loads last, so these rules win; Ryoku updates
-- never touch this file. If a Ryo app floats again after an update, Ryoku
-- renamed its class or title: check `hyprctl clients` and update the match.
-- Delete this block to undo.
hl.window_rule({
    name  = "ryo-apps-tile",
    match = { class = "^(dev\\.ryoku\\.ryoport_ssh|ryostore|ryoku-rashin-setup)$" },
    float = false,
})
-- Ryoku's Quickshell apps cannot tile: each sets a minimumSize of 980-1180px,
-- wider than a tile, and Hyprland keeps them floating even when asked to tile.
-- Float them sized to the area a tiled window gets instead: the monitor minus
-- Caelestia's reserved edges (60 left, 10 top/right/bottom) and 18px gaps
-- plus 2px border on each side; `center` centres inside the reserved area.
-- shortcut: the 110/60 margins are hard-coded for Caelestia's bar and gaps 18;
-- recompute them if the bar width, gaps_out or border_size changes.
hl.window_rule({
    name   = "ryo-pages-fit",
    match  = { title = "^(Ryoku Settings|Ryostore|ryovm|Welcome to Ryoku)$" },
    float  = true,
    size   = { "monitor_w - 110", "monitor_h - 60" },
    center = true,
})
-- <<< ryo-apps-tile <<<

-- >>> tile-gnome-apps >>>
-- Tile GNOME-style apps instead of floating them. Ryoku's shipped
-- window_rules.lua floats Nautilus at a fixed size and a few other apps;
-- user.lua loads last, so these win. Dialogs and file pickers stay floating
-- on purpose (a tiled transient dialog is unusable). Delete this block to undo.
hl.window_rule({
    name  = "tile-gnome-apps",
    match = { class = "^(org\\.gnome\\.Nautilus|[Ss]potify|Ghosttype-app|pavucontrol|nm-connection-editor|blueman-manager)$" },
    float = false,
})
-- <<< tile-gnome-apps <<<
