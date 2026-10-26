import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import "../../../components/filedialog"
import "../../../utils"
import "../common"

// Panels page: choose the image shown in the session menu (the power menu).
ColumnLayout {
    Layout.fillWidth: true
    spacing: Tokens.spacing.extraSmall / 2

    FileDialog {
        id: picker

        title: Tr.tr("Select a session menu image")
        filterLabel: Tr.tr("Image files")
        filters: ["gif", "png", "webp"]
        onAccepted: path => GlobalConfig.paths.sessionGif = path
    }

    SectionHeader {
        text: Tr.tr("Session menu")
    }

    RowButton {
        first: true
        last: true
        icon: "image"
        text: Tr.tr("Mascot image")
        // Shown in a square slot and fitted, never cropped; a GIF animates, a PNG stays still.
        subtext: Tr.tr("%1 - square GIF, PNG or WebP, 256-512 px").arg(Paths.shortenHome(Config.paths.sessionGif))
        onClicked: picker.open()
    }
}
