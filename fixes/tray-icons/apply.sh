#!/usr/bin/env bash
# Replace blurry app tray icons in the Caelestia bar with the glyphs in icons/.
#
# Each file in icons/ is named after the tray item's StatusNotifierItem Id
# (e.g. Slack_status_icon_1.svg). The file is copied to
# ~/.config/caelestia/assets/tray-icons/ and wired up through Caelestia's
# bar.tray.iconSubs, so app updates, which only change the app's own icon,
# leave it alone. Safe to re-run: existing entries for the same Id are replaced.
#
#   fixes/tray-icons/apply.sh        ask before changing anything
#   fixes/tray-icons/apply.sh -y     do not ask
set -euo pipefail

HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
CONFIG=${XDG_CONFIG_HOME:-$HOME/.config}
ASSETS=$CONFIG/caelestia/assets/tray-icons
SHELL_JSON=$CONFIG/caelestia/shell.json

[[ -f $SHELL_JSON ]] || { echo "error: $SHELL_JSON missing: install Caelestia first (./install.sh)" >&2; exit 1; }

shopt -s nullglob
icons=("$HERE"/icons/*)
(( ${#icons[@]} )) || { echo "no icons in $HERE/icons" >&2; exit 1; }

echo "Tray icons to override in $SHELL_JSON:"
for f in "${icons[@]}"; do b=$(basename "$f"); echo "  ${b%.*}"; done
if [[ ${1:-} != -y ]]; then
    read -rp "Apply? [y/N] " ans
    [[ $ans == [yY]* ]] || { echo "nothing changed"; exit 0; }
fi

mkdir -p "$ASSETS"
cp -f "${icons[@]}" "$ASSETS/"

python3 -I - "$SHELL_JSON" "$ASSETS" "${icons[@]}" <<'EOF'
import json, os, sys

shell_json, assets, *icons = sys.argv[1:]
with open(shell_json) as f:
    cfg = json.load(f)

tray = cfg.setdefault("bar", {}).setdefault("tray", {})
subs = {s.get("id"): s for s in tray.get("iconSubs", [])}
for icon in icons:
    name = os.path.basename(icon)
    subs[os.path.splitext(name)[0]] = {
        "id": os.path.splitext(name)[0],
        "image": "file://" + os.path.join(assets, name),
    }
tray["iconSubs"] = list(subs.values())

# Write beside the file and rename, so a crash never leaves a half-written config.
tmp = shell_json + ".tmp"
with open(tmp, "w") as f:
    json.dump(cfg, f, indent=4)
    f.write("\n")
os.replace(tmp, shell_json)
EOF

echo "done: the bar picks up the new icons on its own"
