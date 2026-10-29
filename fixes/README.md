# Machine fixes

Fixes for problems hit on this laptop under Ryoku (Arch, Hyprland 0.56,
October 2026). They are **not** installed by `install.sh`: after a fresh
Ryoku install, check each symptom first and apply only the fixes that are
still needed. A new Ryoku release (or the Fedora edition) may have fixed the
problem, or changed the files a fix hooks into.

| Fix | Symptom | Files |
|-----|---------|-------|
| [Conda guard](#1-conda-guard) | Clamshell daemon dead, lock screen loops, D-Bus tools fail in the session | `fish/conda-interactive-guard.fish` |
| [AC-awake clamshell](#2-ac-awake-clamshell) | Lid shut on AC with no monitor: laptop locks/suspends, VNC re-locks every ~2s | `clamshell/ryoku-clamshell`, `clamshell/ac-awake.conf` |
| [Panel off in clamshell](#3-panel-off-in-clamshell) | Lid shut with external monitor: panel stays on, external display lags/flickers | `clamshell/fix-clamshell.sh` |
| [wayvnc autostart](#4-wayvnc-autostart) | No VNC server after login | `hypr/user-blocks.lua` (wayvnc) |
| [Wispr Flow](#5-wispr-flow) | No tray icon; ghost frosted panel that eats clicks | `hypr/user-blocks.lua` (wispr-flow) |
| [Mac Command as Super over VNC](#6-mac-command-as-super-over-vnc) | From macOS Screen Sharing, ⌘ does nothing as Super | `xkb/rules/macvnc`, `xkb/symbols/macvnc_pc`, `hypr/user-blocks.lua` (wayvnc) |
| [Wallpaper socket crash](#7-wallpaper-socket-crash) | "Quickshell has crashed" dialog at login or after `ryoku update` | `quickshell/wallpaper-socket-crash.patch` |
| [Tray icons](#8-tray-icons) | Blurry full-colour app icons (Slack) in the bar tray | `tray-icons/apply.sh`, `tray-icons/icons/` |
| [rclone sleep](#9-rclone-sleep) | Lid shut, then on open: black screen with only a cursor, or a frozen lock screen | `sleep/rclone-sleep@.service` |
| [Ryo app windows](#10-ryo-app-windows) | Ryoku Settings opens over the bar; Ryoport's SSH terminal and other Ryo apps open as small floating windows outside the gaps | `hypr/user-blocks.lua` (ryo-apps-tile) |
| [Clipboard in RDP/VM](#11-clipboard-in-rdpvm) | Ctrl+C in a Windows RDP/VM window needs 2-3 tries; Ctrl+X loses the text | `clipboard/wl-clip-persist` |
| [Wallpaper auto-rotate](#12-wallpaper-auto-rotate) | Auto-rotate in the wallpaper picker is clicked, but the wallpaper never changes | `wallpaper/restart-rotation.sh` |

Apply them in this order: fix 1 was the root cause behind most of the rest.

## 1. Conda guard

**Root cause.** SDDM starts the desktop through `fish -l`. `conda init` adds
an unguarded hook to `~/.config/fish/config.fish`, so conda's `bin/` landed
ahead of `/usr/bin` for Hyprland and every session service. Conda ships its
own `dbus-monitor`, which cannot find the system bus, so `ryoku-clamshell`
timed out waiting for login1 and never started.

**Check.** Only needed if conda (miniconda/anaconda) is installed. From a
terminal inside the session:

```sh
systemctl --user show-environment | grep -i conda   # any output = affected
systemctl --user status ryoku-clamshell             # failed = affected
```

**Apply.** Wrap the `# >>> conda initialize >>>` block in
`~/.config/fish/config.fish` in `if status is-interactive` ... `end`, as in
`fish/conda-interactive-guard.fish`. Re-running `conda init` rewrites the
inner block but keeps the guard. Log out and back in.

## 2. AC-awake clamshell

**Problem.** Stock `ryoku-clamshell` keeps the laptop awake with the lid shut
only on AC **and** with an external display. Otherwise every close path (the
lid bind, `lid sync` on each config reload, the daemon) runs lock-and-suspend,
so headless use over VNC re-locked every ~2s after unlocking. The wrapper
changes the policy to "on AC" alone, and only turns off the laptop panel when
an external display exists to take over. With no output left, wayvnc exits and
reopening the lid brings the panel back at the wrong scale. On battery it still
locks and suspends.

**Check.** The wrapper sources `/usr/bin/ryoku-clamshell` and overrides
`clamshell_wanted` and `disable_internal_panels`, and repeats its command
dispatch. Before applying on a new release, confirm those still exist:

```sh
grep -nE '^(clamshell_wanted|disable_internal_panels|on_ac|external_connected|run_daemon|cmd_lid)\(\)' /usr/bin/ryoku-clamshell
sed -n '/^cmd=/,/^esac/p' /usr/bin/ryoku-clamshell   # compare with the wrapper's case block
```

If they are renamed or the dispatch differs, port the two overrides by hand.

**Apply.**

```sh
install -Dm755 fixes/clamshell/ryoku-clamshell ~/.local/bin/ryoku-clamshell
install -Dm644 fixes/clamshell/ac-awake.conf ~/.config/systemd/user/ryoku-clamshell.service.d/ac-awake.conf
systemctl --user daemon-reload && systemctl --user restart ryoku-clamshell
```

**Undo.** Delete both files, `daemon-reload`, restart the service.

## 3. Panel off in clamshell

**Problem.** `ryoku-clamshell` disables the panel with a runtime
`hyprctl eval hl.monitor({ disabled = true })`. Hyprland 0.56 acknowledges it
without applying it, so the panel stayed live behind the shut lid. A monitor
rule evaluated at config load does apply, so the block checks the lid and
display state at load time and reloads the config on every lid edge.

**Check.** Close the lid with an external monitor connected, then run
`hyprctl monitors`. If `eDP-1` is still listed, the bug is still there.

**Apply.** `bash fixes/clamshell/fix-clamshell.sh` writes the
`clamshell-panel-off` block into `~/.config/hypr/user.lua`, using the panel's
detected connector name, and reloads Hyprland. It backs up `user.lua` first
and is safe to re-run. Undo with `--uninstall`.

## 4. wayvnc autostart

**Problem.** Ryoku's Hyprland uses a Lua config and never reads
`hyprland.conf`, so `exec-once = wayvnc` never ran. wayvnc also exits when its
output goes away and nothing restarted it.

**Check.** `pgrep -a wayvnc` after login.

**Apply.** Paste the `wayvnc` block into `~/.config/hypr/user.lua`. It needs
`wayvnc` installed and `~/.config/wayvnc/config`. That file is not in this
repo because it holds the password. This machine used `address=0.0.0.0`,
`port=5901`, `enable_auth=true` with `username=` and `password=`, and
`rsa_private_key_file=~/.config/wayvnc/rsa_key.pem`. Generate a fresh key
with `ssh-keygen -m pem -f ~/.config/wayvnc/rsa_key.pem -t rsa -N ""`.
Logs: `journalctl --user -t wayvnc`.

## 5. Wispr Flow

**Problems.**
- Electron checks for `org.kde.StatusNotifierWatcher` once at startup. If the
  tray daemon is not up yet, the app runs with no tray icon all session.
- Hyprland has no XDG autostart, so `~/.config/autostart/wispr-flow.desktop`
  never ran.
- The transparent "Status" overlay got blur, rounding and shadow, and swallowed
  clicks under Wayland.

**Apply.** Install Wispr Flow and turn on "Open at login" in the app, then
paste the `wispr-flow` block into `~/.config/hypr/user.lua`.

## 6. Mac Command as Super over VNC

**Problem.** macOS Screen Sharing sends the Command key as `Alt_L` and never
sends Option at all. wayvnc passes that on as Alt, so no Super binding fires
from the Mac. The fix gives wayvnc its own XKB rules: a copy of `symbols/pc`
in which `Alt_L` exists only on `<LWIN>`, and `<LWIN>` carries only `Mod4`.
wayvnc looks keysyms up in its own keymap, so the Mac's "Alt" now presses
Super. The laptop's own keyboard is untouched. Trade-off: there is no Alt
key over VNC from Screen Sharing.

**Check.** Connect from Screen Sharing, run `kitty +kitten show_key -m kitty`
and press ⌘. `LEFT_ALT` means the fix is needed; `LEFT_SUPER` means it is
applied or no longer needed.

**Apply.**

```sh
install -Dm644 fixes/xkb/rules/macvnc ~/.config/xkb/rules/macvnc
install -Dm644 fixes/xkb/symbols/macvnc_pc ~/.config/xkb/symbols/macvnc_pc
xkbcli compile-keymap --rules macvnc --layout us | grep -E 'key <(LALT|LWIN)>'
```

The last line should show `<LALT>` as `Meta_L` and `<LWIN>` as
`Super_L, Alt_L`. Then use the `wayvnc` block from `hypr/user-blocks.lua`
(it sets `XKB_DEFAULT_RULES=macvnc`) and restart wayvnc by logging out and
back in. `macvnc_pc` is a copy of `/usr/share/X11/xkb/symbols/pc` with five
lines changed; on a new xkeyboard-config, diff it against the system file
before installing.

**Undo.** Delete both xkb files and drop `XKB_DEFAULT_RULES=macvnc` from the
wayvnc block.

## 7. Wallpaper socket crash

**Problem.** Ryoku's `modules/wallpaper/Wallpaper.qml` sets
`connected = false` inside the ryogami `Socket`'s `onError` handler. When
ryogami restarts (login, or an update restarting session daemons), the
socket gets `PeerClosedError`. Setting `connected = false` there frees the
`QLocalSocket` while Quickshell 0.3.2's `Socket::onSocketError` is still
running. It then calls `deleteLater()` on null and the shell segfaults.
The log shows `QObject::disconnect: Unexpected nullptr parameter` right
before the crash. The patch defers the disconnect with `Qt.callLater`.

**Check.**

```sh
grep -n -A2 'onError' /usr/share/ryoku/config/quickshell/shell/modules/wallpaper/Wallpaper.qml
```

`connected = false` directly under `onError: {` means the bug is still
there. Also check the Quickshell version: a release newer than 0.3.2 may
null-check the socket in `onSocketError`.

**Apply.** Fork the file into the overlay so updates keep it, then patch
both the fork and the live copy. Quickshell reloads the shell by itself.

```sh
d=~/.config/ryoku/user_edits/quickshell/shell/modules/wallpaper
install -Dm644 /usr/share/ryoku/config/quickshell/shell/modules/wallpaper/Wallpaper.qml $d/Wallpaper.qml
patch -d ~/.config/ryoku/user_edits/quickshell/shell -p1 < fixes/quickshell/wallpaper-socket-crash.patch
cp $d/Wallpaper.qml ~/.config/quickshell/shell/modules/wallpaper/Wallpaper.qml
systemctl --user restart ryogami   # the shell must stay up
```

**Undo.** `ryoku reset ~/.config/quickshell/shell/modules/wallpaper/Wallpaper.qml`.

## 8. Tray icons

**Problem.** Electron apps (Slack, Wispr Flow) send their tray icon as a tiny
full-colour pixmap. Caelestia scales it up and, with "recolour" on, tints it
by its dominant colour, so it shows as a blurry blob next to the crisp
theme glyphs.

**Fix.** `tray-icons/icons/` holds one single-colour glyph per app, named
after the tray item's Id. `apply.sh` copies them to
`~/.config/caelestia/assets/tray-icons/` and adds a `bar.tray.iconSubs`
entry per Id to `~/.config/caelestia/shell.json`. Caelestia tints the glyph
with the theme, and app updates do not touch either file. It asks before
changing anything (`-y` skips the question) and is safe to re-run.

**Apply.** After `./install.sh`, with the apps installed:

```sh
fixes/tray-icons/apply.sh
```

**Add an app.** Find its Id while it runs, then drop a white-on-transparent
glyph (SVG, or a 44px PNG with the mark in the middle 30px) named
`<Id>.svg` or `<Id>.png` into `tray-icons/icons/` and re-run `apply.sh`.

```sh
busctl --user get-property org.kde.StatusNotifierWatcher /StatusNotifierWatcher \
    org.kde.StatusNotifierWatcher RegisteredStatusNotifierItems
busctl --user get-property <bus name> /StatusNotifierItem org.kde.StatusNotifierItem Id
```

The Slack glyph is the mark from Slack's own icon with every shape filled
white. An override replaces the app's icon in every state, so Slack's
unread badge no longer shows in the tray.

**Undo.** Remove the entries from `bar.tray.iconSubs` in `shell.json`.

## 9. rclone sleep

**Problem.** `rclone-gdrive` and `rclone-onedrive` are user services serving
FUSE mounts. On suspend, systemd freezes `user.slice` (rclone included) after
NetworkManager has dropped the network. Any process touching `~/GDrive` or
`~/OneDrive` then waits in D state on a server that cannot answer. The freeze
times out (`Failed to freeze unit 'user.slice': Connection timed out`), the
kernel freeze fails (`tasks refusing to freeze` in `fuse_dentry_revalidate`),
and `systemd-sleep` gives up with `Device or resource busy`. logind retries
about every 100s while the lid is shut, and each attempt leaves the session
frozen for most of that time. Opening the lid lands in one of those windows.

**Check.**

```sh
journalctl -b -1 | grep -E "Failed to freeze unit|refusing to freeze|fuse_"
```

**Apply.** The unit stops both mounts before `sleep.target` and starts them
again on resume. The mount services restart on failure until the network is
back.

```sh
sudo install -Dm644 fixes/sleep/rclone-sleep@.service /etc/systemd/system/rclone-sleep@.service
sudo systemctl daemon-reload && sudo systemctl enable rclone-sleep@$USER.service
```

Test with `systemctl suspend`. After resume, `journalctl -b -u rclone-sleep@$USER`
should show the stop and start, and `mount -t fuse.rclone` both mounts.

**Undo.** `sudo systemctl disable rclone-sleep@$USER.service` and delete the unit.

## 10. Ryo app windows

**Problem.** Ryoku's shipped `~/.config/hypr/modules/window_rules.lua` floats
its own apps at fixed sizes: Ryoku Settings (`Super+,`) at 99% x 96% of the
monitor, which covers the Caelestia bar and border, and Ryoport's SSH terminal
(`kitty --class ryoport-ssh`), Ryostore, ryovm and Welcome at small centred
sizes. Floating windows skip the tiling layout, so they get neither the gaps
nor the space the bar reserves.

**Fix.** The block in `user.lua` (loaded last, never touched by updates) tiles
the terminal-class windows (`dev.ryoku.ryoport_ssh`, `ryostore`, `ryoku-rashin-setup`).
The Quickshell apps cannot tile: each sets a `minimumSize` of 980-1180px, and
Hyprland keeps them floating even when asked to tile. They stay floating,
sized to the area a tiled window gets (`monitor_w - 110` x `monitor_h - 60`)
and centred inside the reserved area. Ryoku Settings caps its own height at
`(monitor_h - 56) * 0.99`, so it ends up 6px shorter than a tile.

**Check.** Open Ryoku Settings and a Ryoport SSH session, then compare them
with a normal tiled window in `hyprctl clients`. On this laptop (1920x1080,
gaps 18, border 2, bar reserving 60/10/10/10) a tile is 1810x1020 at (80,30).

**Apply.** Copy the `ryo-apps-tile` block from `hypr/user-blocks.lua` into
`~/.config/hypr/user.lua` and run `hyprctl reload`. Rules apply when a window
opens, so close and reopen the app (for the hub, make sure the `qs -c hub`
process has exited). If the bar width, `gaps_out` or `border_size` changes,
recompute the 110/60 margins. If an app floats at the wrong size after a Ryoku
update, Ryoku renamed its class or title: check `hyprctl clients` and update
the match.

**Ryoport workspaces.** The `ryoport-workspaces` block in `hypr/user-blocks.lua`
tiles Ryoport's SPICE/VNC/RDP windows and SSH terminals (Ryoku now names the SSH
class `dev.ryoku.ryoport_ssh`). A machine display opens on a fresh workspace and
switches to it; an SSH terminal joins the workspace of an open machine window,
else takes a fresh one. Copy it into `~/.config/hypr/user.lua` and `hyprctl reload`.

## 11. Clipboard in RDP/VM

**Problem.** The Ryoku shell daemon runs `wl-clip-persist --clipboard regular`,
which re-owns the Wayland clipboard whenever its owner changes, so a copy
survives the source app closing. FreeRDP (and SPICE) announce a copy to Wayland
without sending the data until something pastes. `wl-clip-persist` fetches it
at once and takes the selection over, which races with the guest's next
update: the first Ctrl+C is lost, a retry sometimes wins, and Ctrl+X deletes
the text before the copy has landed. Seen with `xfreerdp3 +clipboard`
(winpodx container) and virt-manager.

**Check.** Copy in a Windows RDP/VM app. If one Ctrl+C often fails to paste,
and `pgrep -a wl-clip-persist` shows a process, test by freezing it:
`kill -STOP $(pgrep wl-clip-persist)`. If copy then works, the fix applies.

**Apply.** The daemon starts the program by name and restarts it when it
dies, so killing it does not stick. `~/.local/bin` is first in its `PATH`, so a
stand-in that only sleeps works:

```sh
install -Dm755 fixes/clipboard/wl-clip-persist ~/.local/bin/wl-clip-persist
pkill -x wl-clip-persist   # the daemon restarts it, now as the stand-in
```

**Trade-off.** A copy no longer outlives the app it came from: copy, then
close the source app, and the paste is empty. Ryoku's clipboard history
(Super+V) is separate and still keeps entries.

**Undo.** `rm ~/.local/bin/wl-clip-persist`, then `systemctl --user restart ryoku-shell`.

## 12. Wallpaper auto-rotate

**Problem.** The auto-rotate button in the wallpaper picker's filter bar
(Super+W, or Ctrl+R inside the picker) looks like it does nothing. It is not
broken. The button asks the ryogami daemon (`wall.random_start`) to apply a
random wallpaper every `general.randomInterval` seconds, and the default is
300. So the first change comes 5 minutes after the click, not right away. A
second click stops it again (the button stays highlighted while it runs).
The button only starts rotation for the running daemon. The
"Rotate automatically" setting (`general.randomRotate`) is the saved switch.
This is not the iNiR "Shuffle wallpapers" option (`background.autoWallpaper`
in `shell.json`): the Ryoku shell (`qs -c shell`) does not use that option.

**Check.** Ask the daemon whether rotation is running:

```sh
python3 -I -c 'import socket,json; s=socket.socket(socket.AF_UNIX); s.connect("/run/user/1000/ryogami.sock"); s.sendall(json.dumps({"id":1,"method":"wall.rotation_status","params":{}}).encode()+b"\n"); print(s.recv(4096).decode())'
```

`"active":false` means rotation is off. While it runs, every wallpaper change
also rewrites `~/.cache/ryoku/colors.json`, so `ls -l --time-style=+%T`
on that file shows the time of the last change. With the test settings below,
changes came 30 s apart (tested 2026-10-30).

**Apply.** `~/.config/ryoku/ryogami.json` is a Ryoku store (`ryoku owner`),
so change it in the GUI, not by hand. Open the wallpaper picker's settings and
go to **Automation**. Under **Random rotation**:

- turn on **Rotate automatically**
- set **Interval** in seconds (minimum 10)
- keep at least one of **Include images / video / Wallpaper Engine** on. If all
  three are off, the button shows "Select at least one random source category"
  and does not start

To test, set Interval to 30 and watch for a change, then set it back.

**Stuck rotation.** Rotation can report `"active":true` and still never
change the wallpaper. On 2026-10-30 it stayed active for over 13 minutes on
the 300 s default with no change to `colors.json`, while both displays were
on and the screen was unlocked. The ryogami log showed no error. Stopping
and starting it again fixed it: the first change came exactly 300 s after
the restart. Clicking the button earlier had not fixed it, but this did:

```sh
fixes/wallpaper/restart-rotation.sh       # interval from settings (300 s default)
fixes/wallpaper/restart-rotation.sh 30    # test: a change every 30 s
```

It sends `wall.rotation_stop`, then `wall.random_start` with the same
interval and sources the button reads from **Automation**, then checks
that ryogami reports rotation active. Like the button, it lasts until logout
or a ryogami restart. Run it again after login if rotation sticks again.

What leaves it stuck is unknown. The manual-pause state below may be the
cause.

**Not verified.** Whether rotation started with the button survives a logout
or a `systemctl --user restart ryogami`, and whether picking a wallpaper by
hand pauses rotation. The daemon has a manual-pause state, so that pause is
likely. If rotation stops on its own, use the **Rotate automatically** setting,
not the button.

**Undo.** Turn off **Rotate automatically**, or click the button again.
