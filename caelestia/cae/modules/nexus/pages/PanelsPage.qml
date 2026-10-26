import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import "../../../modules/nexus/common"
import "../../../components/filedialog"
import "../../../utils"
PageBase {
    id: root

    title: Tr.tr("Panels")

    FileDialog {
        id: mascotPicker

        title: Tr.tr("Select a session menu image")
        filterLabel: Tr.tr("Image files")
        filters: ["gif", "png", "webp"]
        onAccepted: path => GlobalConfig.paths.sessionGif = path
    }

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        NavRow {
            first: true
            icon: "dashboard"
            text: Tr.tr("Dashboard")
            subtext: Config.dashboard.enabled ? Tr.trCtx("Enabled", "panel status") : Tr.trCtx("Disabled", "panel status")
            onClicked: root.nState.openSubPage(1)
        }

        NavRow {
            icon: "dock_to_bottom"
            text: Tr.tr("Taskbar")
            subtext: Config.bar.persistent ? Tr.tr("Always visible") : Config.bar.showOnHover ? Tr.tr("Reveal on hover") : Tr.tr("Reveal on drag")
            onClicked: root.nState.openSubPage(2)
        }

        NavRow {
            icon: "apps"
            text: Tr.tr("Launcher")
            subtext: Config.launcher.enabled ? Tr.trCtx("Enabled", "panel status") : Tr.trCtx("Disabled", "panel status")
            onClicked: root.nState.openSubPage(3)
        }

        NavRow {
            icon: "dock_to_right"
            text: Tr.tr("Sidebar")
            subtext: Config.sidebar.enabled ? Tr.trCtx("Enabled", "panel status") : Tr.trCtx("Disabled", "panel status")
            onClicked: root.nState.openSubPage(4)
        }

        SectionHeader {
            text: Tr.tr("Session menu")
        }

        RowButton {
            first: true
            last: true
            icon: "image"
            text: Tr.tr("Mascot image")
            // Square, 256-512 px (shown at button size, never cropped); a GIF animates, a PNG stays still.
            subtext: Tr.tr("%1 - square GIF, PNG or WebP, 256-512 px").arg(Paths.shortenHome(Config.paths.sessionGif))
            onClicked: mascotPicker.open()
        }
    }
}
