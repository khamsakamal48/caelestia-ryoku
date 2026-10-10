pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "../utils"

// Settings for Ryoku's quick-settings panel, hosted by Scene.qml as a
// right-edge Caelestia drawer. Stored in ~/.config/caelestia/quick-settings.json:
// Caelestia's own config schema is compiled into its plugin and cannot take new keys.
Singleton {
    readonly property alias settings: settingsAdapter

    FileView {
        path: `${Paths.config}/quick-settings.json`
        watchChanges: true
        onFileChanged: reload()
        onAdapterUpdated: writeAdapter()
        onLoadFailed: err => {
            if (err === FileViewError.FileNotFound)
                writeAdapter();
        }

        JsonAdapter {
            id: settingsAdapter

            // Open the drawer when the cursor reaches the right screen edge.
            property bool showOnHover: true
        }
    }
}
