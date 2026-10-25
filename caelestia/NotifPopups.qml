pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import shell.services as R
import "cae/components"
import "cae/services"

// Notification popups in Caelestia's look, fed by Ryoku's notification server
// (R.Notifs owns the popup list, timers and sound). Colours come from
// Colours.palette, which follows the wallpaper through Ryoku's Matugen.
Item {
    id: root

    // Held while the panel slides back out, so the cards don't vanish mid-exit.
    property var popups: []
    readonly property bool shouldBeActive: R.Notifs.popups.length > 0 && !blocked
    // The right-edge sidebar and Controls own that edge while open.
    property bool blocked: false
    property real offsetScale: shouldBeActive ? 0 : 1

    Binding {
        target: root
        property: "popups"
        value: R.Notifs.popups.slice(0, 4)
        when: R.Notifs.popups.length > 0
    }

    implicitWidth: 380 + Tokens.padding.large * 2
    implicitHeight: col.implicitHeight + Tokens.padding.large * 2
    visible: offsetScale < 1
    opacity: 1 - offsetScale

    Behavior on offsetScale {
        Anim {}
    }

    ColumnLayout {
        id: col

        anchors.fill: parent
        anchors.margins: Tokens.padding.large
        spacing: Tokens.spacing.medium

        Repeater {
            model: root.popups

            delegate: StyledRect {
                id: card

                required property var modelData
                required property int index
                readonly property bool critical: modelData.urgency === 2

                Layout.fillWidth: true
                implicitHeight: content.implicitHeight + Tokens.padding.medium * 2
                radius: Tokens.rounding.large
                // The panel's blob is the background; only critical ones get a card.
                color: critical ? Colours.palette.m3secondaryContainer : "transparent"

                // Divider between stacked notifications, centred in the gap above.
                Rectangle {
                    visible: card.index > 0
                    y: -Tokens.spacing.medium / 2
                    width: parent.width
                    height: 1
                    color: Colours.palette.m3outline
                }

                ColumnLayout {
                    id: content

                    anchors.fill: parent
                    anchors.margins: Tokens.padding.medium
                    spacing: Tokens.spacing.extraSmall

                    RowLayout {
                        Layout.fillWidth: true

                        StyledText {
                            Layout.fillWidth: true
                            text: card.modelData.appName
                            color: Colours.palette.m3outline
                            font: Tokens.font.body.small
                            elide: Text.ElideRight
                        }
                        MaterialIcon {
                            text: "close"
                            color: Colours.palette.m3outline

                            MouseArea {
                                anchors.fill: parent
                                anchors.margins: -Tokens.padding.small
                                cursorShape: Qt.PointingHandCursor
                                onClicked: R.Notifs.dismiss(card.modelData)
                            }
                        }
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: card.modelData.summary
                        color: card.critical ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurface
                        elide: Text.ElideRight
                    }

                    StyledText {
                        Layout.fillWidth: true
                        visible: text.length > 0
                        text: card.modelData.body
                        color: Colours.palette.m3outline
                        wrapMode: Text.WordWrap
                        maximumLineCount: 3
                        elide: Text.ElideRight
                    }

                    // One button per real action (the freedesktop "default" has no label).
                    Flow {
                        Layout.fillWidth: true
                        spacing: Tokens.spacing.small
                        visible: children.length > 0

                        Repeater {
                            model: (card.modelData.actions || []).filter(a => a.identifier !== "default" && a.text)

                            delegate: StyledRect {
                                required property var modelData

                                radius: Tokens.rounding.full
                                color: Colours.palette.m3secondaryContainer
                                implicitWidth: label.implicitWidth + Tokens.padding.large * 2
                                implicitHeight: label.implicitHeight + Tokens.padding.small * 2

                                StyledText {
                                    id: label

                                    anchors.centerIn: parent
                                    text: parent.modelData.text
                                    color: Colours.palette.m3onSecondaryContainer
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: parent.modelData.invoke()
                                }
                            }
                        }
                    }
                }

                // Clicking the body hides the popup; the notification stays in the sidebar.
                MouseArea {
                    anchors.fill: parent
                    z: -1
                    onClicked: R.Notifs.removePopup(card.modelData)
                }
            }
        }
    }
}
