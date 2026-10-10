pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import shell.services as R
import Caelestia.Config
import "../../../components/effects"
import "../../../services"
import "../../../utils"
MouseArea {
    id: root

    required property string modelData // the item's service
    readonly property var item: R.Tray.items.find(i => i.service === modelData) ?? null

    acceptedButtons: Qt.LeftButton | Qt.RightButton
    implicitWidth: Tokens.font.body.small.pointSize * 2
    implicitHeight: Tokens.font.body.small.pointSize * 2

    onClicked: event => {
        if (event.button === Qt.LeftButton)
            R.Tray.activate(root.modelData);
        else
            R.Tray.send("tray.secondaryActivate", {
                service: root.modelData
            });
    }

    ColouredIcon {
        id: icon

        anchors.fill: parent
        source: Icons.getTrayIcon(root.item?.id ?? "", root.item?.iconPath ? `file://${root.item.iconPath}` : Quickshell.iconPath(root.item?.iconName ?? "", true))
        colour: Colours.palette.m3secondary
        layer.enabled: Config.bar.tray.recolour
    }
}
