#!/usr/bin/env python3
"""Install, update or remove the Caelestia bar style on Ryoku.

  python3 -I caelestia-bar.py install     install ./caelestia and select it
  python3 -I caelestia-bar.py uninstall   remove it, restore the previous bar style

Ryoku loads a bar style either from Ryostore's index (rebuilt from store
receipts whenever the Hub opens or the store refreshes; it only keeps styles in
the online catalog) or from the shell's built-in table in
services/BarProducts.qml. A style outside the catalog therefore only persists as
a built-in, so this:

  1. copies the style to $XDG_DATA_HOME/caelestia-ryoku/<content-hash>/
     (a fresh path per version, so the shell never reuses a cached copy);
  2. writes a user_edits fork of BarProducts.qml, regenerated from the shipped
     file on every install, whose built-in table also maps "caelestia" to it;
  3. runs `ryoku materialize` to lay the fork into ~/.config, then
     `ryoku-shell reload` (the shell reads the table at startup);
  4. selects the style through the ryoku-shell settings daemon (settings.patch),
     as the Hub's Bar Studio does.

After a Ryoku update changes BarProducts.qml, `ryoku doctor` flags the fork; re-run
`install` to regenerate it from the new shipped file. `uninstall` hands the file
back to Ryoku (`ryoku reset`).
"""
import hashlib, json, os, shutil, socket, subprocess, sys, time
from pathlib import Path

ID = "caelestia"
HERE = Path(__file__).resolve().parent
SRC = HERE / ID
HOME = Path.home()
DATA = Path(os.environ.get("XDG_DATA_HOME") or HOME / ".local/share")
STATE = Path(os.environ.get("XDG_STATE_HOME") or HOME / ".local/state")
CACHE = Path(os.environ.get("XDG_CACHE_HOME") or HOME / ".cache")
CONFIG = Path(os.environ.get("XDG_CONFIG_HOME") or HOME / ".config")
INSTALL_ROOT = DATA / "caelestia-ryoku"
REL_PRODUCTS = "quickshell/shell/services/BarProducts.qml"
BASE_PRODUCTS = Path("/usr/share/ryoku/config") / REL_PRODUCTS
FORK_PRODUCTS = CONFIG / "ryoku/user_edits" / REL_PRODUCTS
BUILTINS_TAIL = '        "kairos": "barstyles/kairos/Scene.qml"\n    })'
PREV = STATE / "ryoku/caelestia-bar.previous"
SOCK = Path(os.environ.get("XDG_RUNTIME_DIR") or "/tmp") / "ryoku-shell.sock"
SHELL_JSON = CONFIG / "ryoku/shell.json"
# Left behind by earlier versions of this script (store index sideload).
OLD_VIEWS = STATE / "ryoku/store/barstyle-views" / ID
# Build-time helpers, not part of the style.
EXCLUDE_DIRS = {"cae-adapters"}


def set_bar_style(style):
    line = "call settings.patch " + json.dumps({"path": "barStyle", "value": style}) + "\n"
    with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as s:
        s.settimeout(3)
        s.connect(str(SOCK))
        s.sendall(line.encode())
        try:
            s.recv(4096)
        except socket.timeout:
            pass


def current_style():
    try:
        return json.loads(SHELL_JSON.read_text()).get("barStyle") or "qsbar"
    except (OSError, ValueError):
        return "qsbar"


def style_files():
    files = sorted(p for p in SRC.rglob("*")
                   if p.is_file() and not EXCLUDE_DIRS & set(p.relative_to(SRC).parts))
    if any(p.is_symlink() for p in files):
        sys.exit("symlinks are not allowed in a bar style")
    return files


def tree_hash(files):
    h = hashlib.sha256()
    for f in files:
        h.update(f.relative_to(SRC).as_posix().encode() + b"\0" + hashlib.sha256(f.read_bytes()).digest())
    return h.hexdigest()[:16]


def write_fork(scene: Path):
    base = BASE_PRODUCTS.read_text()
    assert BUILTINS_TAIL in base, f"{BASE_PRODUCTS} changed; update BUILTINS_TAIL in this script"
    entry = f'        "kairos": "barstyles/kairos/Scene.qml",\n' \
            f'        // Added by caelestia-bar.py (caelestia-ryoku); `ryoku reset {REL_PRODUCTS}` removes it.\n' \
            f'        "{ID}": "{scene.as_uri()}"\n    }})'
    FORK_PRODUCTS.parent.mkdir(parents=True, exist_ok=True)
    tmp = FORK_PRODUCTS.with_suffix(".qml.tmp")
    tmp.write_text(base.replace(BUILTINS_TAIL, entry, 1))
    os.replace(tmp, FORK_PRODUCTS)


def materialize():
    subprocess.run(["ryoku", "materialize"], check=True, stdout=subprocess.DEVNULL)
    live = CONFIG / REL_PRODUCTS
    if live.read_text() != FORK_PRODUCTS.read_text():
        sys.exit(f"ryoku materialize did not lay {FORK_PRODUCTS} at {live}")


def install():
    if not (SRC / "Scene.qml").is_file():
        sys.exit(f"missing {SRC}/Scene.qml")
    # Caelestia's own state/cache dirs (launcher app history, image cache);
    # its CLI normally creates them.
    for base in (STATE, CACHE):
        (base / "caelestia").mkdir(parents=True, exist_ok=True)

    files = style_files()
    target = INSTALL_ROOT / tree_hash(files)
    if not target.exists():
        tmp = target.with_name(target.name + ".tmp")
        shutil.rmtree(tmp, ignore_errors=True)
        for p in files:
            out = tmp / p.relative_to(SRC)
            out.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(p, out)
        os.replace(tmp, target)

    write_fork(target / "Scene.qml")
    materialize()
    # The shell reads its built-in table once at startup.
    subprocess.run(["ryoku-shell", "reload"], check=True, stdout=subprocess.DEVNULL)
    time.sleep(3)

    prev = current_style()
    if prev != ID:
        PREV.write_text(prev)
    set_bar_style(ID)

    # Older copies are unreferenced now.
    for old in INSTALL_ROOT.iterdir():
        if old != target:
            shutil.rmtree(old, ignore_errors=True)
    shutil.rmtree(OLD_VIEWS, ignore_errors=True)
    print(f"installed {ID} from {target} ({len(files)} files), was {prev}")


def uninstall():
    prev = PREV.read_text().strip() if PREV.exists() else "qsbar"
    if current_style() == ID:
        set_bar_style(prev)
        time.sleep(1)
    subprocess.run(["ryoku", "reset", REL_PRODUCTS, "-y"], check=True)
    shutil.rmtree(INSTALL_ROOT, ignore_errors=True)
    shutil.rmtree(OLD_VIEWS, ignore_errors=True)
    PREV.unlink(missing_ok=True)
    print(f"removed {ID}, bar style back to {prev}")


if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else ""
    if cmd == "install":
        install()
    elif cmd == "uninstall":
        uninstall()
    else:
        sys.exit(__doc__)
