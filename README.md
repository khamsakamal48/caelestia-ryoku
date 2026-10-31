# caelestia-ryoku

[Caelestia shell](https://github.com/caelestia-dots/shell) running on **Ryoku OS**, as a native Ryoku bar style.

Caelestia's real bar, dashboard, launcher, session menu, notification sidebar and Nexus settings app, adapted to Ryoku's own services. Ryoku keeps doing the things it already owns: colours/theme (Matugen), wallpaper, weather, notification popups, the system tray and session actions. One script installs everything.

## Why not just install Caelestia?

Upstream Caelestia needs `quickshell-git`, while Ryoku depends on the tagged `quickshell` release. They can't be installed side by side, and replacing Ryoku's shell breaks the desktop. This project vendors Caelestia's QML into a **Ryoku bar style** that runs inside Ryoku's own shell, and builds only Caelestia's C++ plugin (which works with the tagged Quickshell).

## Install

On a Ryoku OS machine, logged into the Ryoku desktop:

```sh
git clone https://github.com/khamsakamal48/caelestia-ryoku.git
cd caelestia-ryoku
./install.sh
```

It asks for your sudo password once. Re-running it is safe: use it to update, or to repair after a Ryoku/Qt update.

## What the installer does

1. **Packages**
   - Repo: `cmake ninja base-devel git patch qt6-shadertools qt6-imageformats aubio libpipewire libqalculate ddcutil brightnessctl lm_sensors networkmanager power-profiles-daemon swappy fish ttf-material-symbols-variable ttf-cascadia-code-nerd`
   - AUR (via `yay`, bootstrapped if missing): `qt6-m3shapes-git libcava ttf-rubik-vf`
   - Google Sans Flex, downloaded from google/fonts into `~/.local/share/fonts` (its AUR package points at a file Google renamed)
2. **Caelestia C++ plugin**: clones `caelestia-dots/shell` at the pinned commit the QML was vendored from, builds it with `-DENABLE_MODULES=plugin`, and installs it to `/usr/lib/qt6/qml/Caelestia`. It rebuilds automatically on re-run when Qt has been updated.
3. **Controls (Super+Escape)**: patches Ryoku's Controls window (a `user_edits` fork of `Sidebar.qml`, regenerated from the shipped file) to stay hidden under this bar style, because Caelestia draws Controls itself; and removes the quick-settings forks older versions of this installer made.
4. **Keybinds**: leaves `SUPER + Space` as Ryoku's own launcher (Spotlight; rebind it in Ryoku Hub > Keybinds) and clears the rebind older versions made, then adds a marked block to `~/.config/hypr/user.lua`:

   | Keys | Action |
   |---|---|
   | `SUPER + G` | Notification sidebar |
   | `SUPER + I` | Nexus (Caelestia settings) |
   | `SUPER + Escape` | Ryoku Controls (stays Ryoku's own bind) |

   Plus a float + centre window rule for the Nexus window.
5. **Caelestia settings**: copies starter `~/.config/caelestia/shell.json` and `ai-usage.json` only if you don't have them.
6. **Bar style**: runs `caelestia-bar.py install`, which copies the style to `~/.local/share/caelestia-ryoku/`, registers it as a built-in in a `user_edits` fork of Ryoku's `BarProducts.qml` (so Ryostore's catalog refresh can't drop it), runs `ryoku materialize`, reloads the shell and selects the style.

## Features and changes from upstream Caelestia

- **Bar, border and popouts**: Caelestia's bar with its blob border and panels (workspaces, active window, tray, status icons, clock, popouts for audio/network/bluetooth/battery).
- **Dashboard**: media (with lyrics), performance, weather, calendar, plus a new **AI usage** tab (Claude Code plan limits and daily tokens, fed by Ryoku's `ryoku-ai-usage` collector; toggle it in Nexus > Panels > Dashboard).
- **Lyrics for browser/YouTube tracks**: when Caelestia's lookup fails on messy metadata (channel name as artist, full video title), a cleaned-title LRCLIB search finds the synced lyrics; matches are cached in `~/.local/state/caelestia/lyrics_match.json`.
- **Launcher**: Caelestia's launcher with apps, calculator and actions. Wallpaper, scheme and variant pickers are removed (Ryoku owns those); session actions go through Ryoku; "Settings" opens Nexus.
- **Controls**: Ryoku's own Controls content (unchanged), hosted as a Caelestia drawer: centred on the right border, rounded and melting out of it like the dashboard. Opens on `SUPER + Escape`; Escape or a click outside closes it, and it swaps with the notification sidebar.
- **Session menu**: logout/shutdown/reboot go through Ryoku's session daemon; hibernate stays Caelestia's.
- **Notification sidebar**: mirrors Ryoku's notification server (no second server); Do Not Disturb is Ryoku's. Popups are drawn by Caelestia (`NotifPopups.qml`, wallpaper-driven colours) from Ryoku's popup list; `patches/Config.patch` stops Ryoku drawing its own.
- **Nexus settings**: trimmed of pages that do nothing on Ryoku (wallpaper & style, updates/plugins placeholders, utilities panel, weather location, colour engine, popup/toast settings). Its audio/bluetooth/network buttons open Ryoku's panels.
- **Adapters**: Caelestia's Colours follow Ryoku's live palette, Weather uses Ryoku's weather daemon, Players use MPRIS.
- **Hyprland**: Caelestia no longer injects Caps/Num Lock keybinds into Hyprland at runtime (it polls device state instead); Ryoku owns keybinds.

## Uninstall

```sh
python3 -I caelestia-bar.py uninstall
```

This restores your previous bar style and hands `BarProducts.qml` back to Ryoku. To remove the rest:

- delete the `caelestia-ryoku` block from `~/.config/hypr/user.lua`
- `ryoku reset quickshell/shell/modules/sidebar/Sidebar.qml` (the uninstall command does this)
- optionally `sudo rm -r /usr/lib/qt6/qml/Caelestia` and the AUR packages

## Troubleshooting

- **Bar fell back to Ryoku's default** after a Ryoku or Qt update: re-run `./install.sh` (add `--rebuild` to force a plugin rebuild).
- **`ryoku doctor` flags `BarProducts.qml`** after a Ryoku update: expected; re-run `./install.sh` to regenerate the fork from the new shipped file.

- **Controls show twice** (Ryoku's own panel plus Caelestia's): `patches/Sidebar.patch` no longer applies to this Ryoku version; Ryoku changed `Sidebar.qml`, so the patch needs re-porting.
- **Right/bottom edge of a window goes transparent**: capture `hyprctl clients -j | jq -c '.[]|select(.focusHistoryID==0)|[.class,.at,.size]'` and `hyprctl monitors -j | jq -c '.[0].reserved'` while it is happening. A tile of 80,30 1810x1020 with reserved `[60,10,10,10]` means the app did not redraw after a resize (the client's fault, not the frame).

## For maintainers: updating Caelestia

```sh
git clone https://github.com/caelestia-dots/shell.git caelestia-shell-src
python3 -I vendor-caelestia.py caelestia-shell-src
```

`vendor-caelestia.py` copies the Caelestia modules into `caelestia/cae/`, rewrites imports, and applies patches that each assert their target still matches, so an upstream change fails loudly. Then set `CAELESTIA_REV` in `install.sh` to the new commit.

## Layout

```
install.sh            one-shot installer
caelestia-bar.py      installs / uninstalls the bar style
vendor-caelestia.py   re-vendors Caelestia's QML (maintainers)
caelestia/            the bar style: Scene.qml, cae/ (vendored), cae-adapters/, cae-extras/
hypr/caelestia.lua    keybind block added to user.lua
patches/              Ryoku patches (Controls window hidden)
config/caelestia/     starter Caelestia settings
fixes/                this laptop's Ryoku fixes (clamshell, VNC, conda, Wispr Flow, SSH); manual, see fixes/README.md
```

## Credits and license

Caelestia shell by [soramanew and contributors](https://github.com/caelestia-dots/shell). Ryoku OS by its authors. This project is GPL-3.0, following upstream; see [LICENSE](LICENSE).
