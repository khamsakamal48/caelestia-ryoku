import QtQuick
import Quickshell
import Quickshell.Io
import "cae/components/misc"
import "cae/services"
import "cae/modules/nexus"

// Caelestia's global shortcuts and IPC (modules/Shortcuts.qml), for the parts
// ported here: launcher, dashboard, session menu, notification sidebar, Ryoku's
// quick settings (as a Caelestia drawer) and Nexus. Bind them in
// Ryoku Hub > Keybinds as global `caelestia:<name>`, or call them with
// `qs -c shell ipc call drawers toggle launcher` / `... nexus open`.
// Created once (by the first screen's scene), not per monitor.
Scope {
    id: root

    readonly property bool hasFullscreen: Hypr.focusedWorkspace?.toplevels.values.some(t => t.lastIpcObject.fullscreen > 1) ?? false

    function toggle(drawer: string): void {
        if (root.hasFullscreen)
            return;
        const screenState = ShellState.forActive();
        if (screenState)
            screenState[drawer] = !screenState[drawer];
    }

    CustomShortcut {
        name: "nexus"
        description: "Open nexus"
        onPressed: WindowFactory.create()
    }

    CustomShortcut {
        name: "dashboard"
        description: "Toggle dashboard"
        onPressed: root.toggle("dashboard")
    }

    CustomShortcut {
        name: "session"
        description: "Toggle session menu"
        onPressed: root.toggle("session")
    }

    CustomShortcut {
        name: "sidebar"
        description: "Toggle sidebar"
        onPressed: root.toggle("sidebar")
    }

    CustomShortcut {
        name: "quicksettings"
        description: "Toggle Ryoku quick settings"
        onPressed: root.toggle("quicksettings")
    }

    // Caelestia toggles on release of a bare Super tap; bound to a chord
    // here (Super+Space), so it toggles on press.
    CustomShortcut {
        name: "launcher"
        description: "Toggle launcher"
        onPressed: root.toggle("launcher")
    }

    IpcHandler {
        function toggle(drawer: string): void {
            if (["launcher", "dashboard", "session", "sidebar", "quicksettings"].includes(drawer))
                root.toggle(drawer);
        }

        target: "drawers"
    }

    IpcHandler {
        function open(): void {
            WindowFactory.create();
        }

        target: "nexus"
    }
}
