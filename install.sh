#!/usr/bin/env bash
# Install Caelestia shell as a Ryoku bar style, with every tweak from this repo.
#
#   ./install.sh            install / update (safe to re-run)
#   ./install.sh --rebuild  also force a rebuild of the Caelestia C++ plugin
#
# Run it as your normal user from inside a running Ryoku (Hyprland) session.
set -euo pipefail

# Caelestia commit the QML in caelestia/cae/ was vendored from; the C++ plugin
# must come from the same commit.
CAELESTIA_REPO=https://github.com/caelestia-dots/shell.git
CAELESTIA_REV=5f1c59c0665aad66e94710f67e4bebaeb65c35f4

HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
CONFIG=${XDG_CONFIG_HOME:-$HOME/.config}
STATE=${XDG_STATE_HOME:-$HOME/.local/state}
CACHE=${XDG_CACHE_HOME:-$HOME/.cache}
SHIPPED=/usr/share/ryoku/config
EDITS=$CONFIG/ryoku/user_edits
REBUILD=0
[[ ${1:-} == --rebuild ]] && REBUILD=1

step() { printf '\n\033[1;35m==>\033[0m \033[1m%s\033[0m\n' "$*"; }
warn() { printf '\033[1;33mwarning:\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31merror:\033[0m %s\n' "$*" >&2; exit 1; }

# --- preflight -------------------------------------------------------------
[[ $EUID -ne 0 ]] || die "run as your normal user, not root (sudo is used where needed)"
for c in pacman ryoku ryoku-shell ryoku-hub python3; do
    command -v "$c" >/dev/null || die "'$c' not found: this script is for Ryoku OS"
done
[[ -d $SHIPPED ]] || die "$SHIPPED missing: this script is for Ryoku OS"
[[ -S ${XDG_RUNTIME_DIR:-/tmp}/ryoku-shell.sock ]] \
    || die "Ryoku shell is not running: run this from inside your Ryoku desktop session"
[[ -f $HERE/caelestia/Scene.qml ]] || die "run install.sh from a full checkout of the repo"

sudo -v || die "sudo is required to install packages and the Caelestia plugin"

# --- 1. packages -----------------------------------------------------------
step "Installing packages"
sudo pacman -S --needed --noconfirm \
    git base-devel cmake ninja patch \
    qt6-base qt6-declarative qt6-shadertools qt6-imageformats \
    aubio libpipewire libqalculate \
    ddcutil brightnessctl lm_sensors networkmanager power-profiles-daemon swappy fish \
    ttf-material-symbols-variable ttf-cascadia-code-nerd

if ! command -v yay >/dev/null; then
    step "Bootstrapping yay (AUR helper)"
    tmp=$(mktemp -d)
    git clone --depth 1 https://aur.archlinux.org/yay-bin.git "$tmp/yay-bin"
    (cd "$tmp/yay-bin" && makepkg -si --noconfirm)
    rm -rf "$tmp"
fi
step "Installing AUR packages"
yay -S --needed --noconfirm --answerdiff None --answerclean None --removemake \
    qt6-m3shapes-git libcava ttf-rubik-vf

# Google Sans Flex straight from google/fonts: the AUR package pins a file name
# Google has since renamed, so look the current .ttf up instead.
if [[ -z $(fc-list 'Google Sans Flex') ]]; then
    step "Installing Google Sans Flex"
    url=$(curl -fsSL https://api.github.com/repos/google/fonts/contents/ofl/googlesansflex \
        | python3 -Ic 'import json,sys; print(next(f["download_url"] for f in json.load(sys.stdin) if f["name"].endswith(".ttf")))') \
        || die "could not find Google Sans Flex in google/fonts"
    fonts=${XDG_DATA_HOME:-$HOME/.local/share}/fonts
    mkdir -p "$fonts"
    curl -fsSLg -o "$fonts/GoogleSansFlex.ttf" "$url" || die "could not download Google Sans Flex"
    fc-cache -f "$fonts"
fi

# --- 2. Caelestia C++ plugin (Caelestia.* QML modules) ---------------------
# Rebuilt whenever the pinned commit or Qt changes; a Qt update breaks it.
stamp_file=$STATE/caelestia-ryoku/plugin-stamp
stamp="$CAELESTIA_REV $(pacman -Q qt6-base qt6-declarative | tr '\n' ' ')"
if [[ $REBUILD == 1 || ! -f /usr/lib/qt6/qml/Caelestia/qmldir || "$(cat "$stamp_file" 2>/dev/null)" != "$stamp" ]]; then
    step "Building the Caelestia plugin (${CAELESTIA_REV:0:7})"
    src=$CACHE/caelestia-ryoku/shell
    if [[ ! -d $src/.git ]]; then
        rm -rf "$src"
        git clone "$CAELESTIA_REPO" "$src"
    fi
    git -C "$src" fetch --quiet origin
    git -C "$src" checkout --quiet --force "$CAELESTIA_REV"
    rm -rf "$src/build"
    cmake -S "$src" -B "$src/build" -G Ninja -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr \
        -DENABLE_MODULES=plugin -DGIT_REVISION="$CAELESTIA_REV"
    cmake --build "$src/build"
    sudo cmake --install "$src/build"
    mkdir -p "${stamp_file%/*}"
    printf '%s' "$stamp" > "$stamp_file"
else
    step "Caelestia plugin is up to date"
fi

# --- 3. Ryoku quick settings: module rail on the right edge ----------------
# user_edits forks, regenerated from the shipped files so they track Ryoku updates.
step "Patching Ryoku quick settings (rail on the right)"
for p in "$HERE"/patches/*.patch; do
    rel=$(sed -n 's|^--- a/||p' "$p" | head -1)
    dest=$EDITS/$rel
    mkdir -p "${dest%/*}"
    cp "$SHIPPED/$rel" "$dest.new"
    if patch --quiet --forward "$dest.new" "$p" >/dev/null; then
        mv "$dest.new" "$dest"
    else
        rm -f "$dest.new" "$dest.new.orig" "$dest.new.rej"
        warn "$(basename "$p") no longer applies to this Ryoku version; skipped (cosmetic)"
    fi
done
python3 -I - <<'EOF'
import json, os, socket
s = socket.socket(socket.AF_UNIX); s.settimeout(3)
s.connect(os.path.join(os.environ.get("XDG_RUNTIME_DIR", "/tmp"), "ryoku-shell.sock"))
s.sendall(("call settings.patch " + json.dumps({"path": "frameBars.menus.quick-settings.anchor", "value": "right"}) + "\n").encode())
s.recv(4096)
EOF

# --- 4. keybinds -------------------------------------------------------------
step "Setting keybinds"
ryoku-hub desktop set-rebind "SUPER + Space" "SUPER + SHIFT + Space"
userlua=$CONFIG/hypr/user.lua
[[ -f $userlua ]] || cp "$SHIPPED/hypr/user.lua" "$userlua"
# Replace a previous copy of the block, then append the current one.
sed -i '/^-- >>> caelestia-ryoku >>>$/,/^-- <<< caelestia-ryoku <<<$/d' "$userlua"
{ echo; cat "$HERE/hypr/caelestia.lua"; } >> "$userlua"
sed -i -e :a -e '/^\n*$/{$d;N;ba' -e '}' "$userlua"   # no trailing blank lines

# --- 5. Caelestia settings (only if you have none yet) ----------------------
step "Caelestia settings"
mkdir -p "$CONFIG/caelestia"
for f in "$HERE"/config/caelestia/*.json; do
    dest=$CONFIG/caelestia/$(basename "$f")
    if [[ -e $dest ]]; then echo "keeping existing $dest"; else cp "$f" "$dest"; echo "wrote $dest"; fi
done

# --- 6. the bar style itself ------------------------------------------------
step "Installing the Caelestia bar style"
python3 -I "$HERE/caelestia-bar.py" install
hyprctl reload >/dev/null || warn "hyprctl reload failed; log out and back in to load the keybinds"

step "Done"
cat <<'EOF'
  SUPER + Space          Caelestia launcher   (Ryoku launcher: SUPER + SHIFT + Space)
  SUPER + G              notification sidebar
  SUPER + I              Nexus (Caelestia settings)
  SUPER + Escape         quick settings drawer
If the bar ever falls back to Ryoku's default after an update, re-run ./install.sh.
Blurry Slack / Wispr Flow tray icons? Run fixes/tray-icons/apply.sh (asks first).
EOF
