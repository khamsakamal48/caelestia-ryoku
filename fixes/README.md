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
