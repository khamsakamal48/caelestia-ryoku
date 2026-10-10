pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import "../../../../modules/nexus/common"
import "../../../../services"

// Nexus > Panels > Quick settings: Ryoku's quick-settings drawer (Super+Esc).
PageBase {
    id: root

    title: Tr.tr("Quick settings")
    isSubPage: true

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        SectionHeader {
            first: true
            text: Tr.tr("General")
        }

        ToggleRow {
            first: true
            last: true
            text: Tr.tr("Show on hover")
            subtext: Tr.tr("Reveal when the cursor reaches the right screen edge")
            checked: QuickSettings.settings.showOnHover
            onToggled: QuickSettings.settings.showOnHover = checked
        }
    }
}
