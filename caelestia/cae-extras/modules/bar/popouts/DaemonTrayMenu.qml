pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Widgets
import Caelestia.Config
import Caelestia.I18n
import shell.services as R
import "../../../components"
import "../../../services"

// Caelestia's tray menu, drawn from the dbusmenu tree that Ryoku's tray daemon
// publishes (R.Tray) instead of Quickshell's SystemTray. Each level holds a menu
// id and re-reads the live tree, so a republish (e.g. aboutToShow filling a lazy
// submenu) re-renders it.
StackView {
    id: root

    required property PopoutState popouts
    required property string service

    readonly property var menu: R.Tray.items.find(i => i.service === service)?.menu ?? null

    function findNode(node: var, id: int): var {
        if (!node)
            return null;
        if (node.id === id)
            return node;
        for (const c of node.children ?? []) {
            const found = findNode(c, id);
            if (found)
                return found;
        }
        return null;
    }

    // dbusmenu labels carry '_' accelerators; show the plain text.
    function cleanLabel(s: var): string {
        return String(s ?? "").replace(/_([^_])/g, "$1").replace(/__/g, "_");
    }

    implicitWidth: (currentItem as SubMenu)?.hasChildren ? currentItem.implicitWidth : -Tokens.padding.large * 2
    implicitHeight: (currentItem as SubMenu)?.hasChildren ? currentItem.implicitHeight : -Tokens.padding.large * 2

    Component.onCompleted: R.Tray.aboutToShow(service)

    initialItem: SubMenu {
        nodeId: root.menu?.id ?? 0
    }

    pushEnter: NoAnim {}
    pushExit: NoAnim {}
    popEnter: NoAnim {}
    popExit: NoAnim {}

    Component {
        id: subMenuComp

        SubMenu {}
    }

    component NoAnim: Transition {
        NumberAnimation {
            duration: 0
        }
    }

    component SubMenu: Column {
        id: menu

        required property int nodeId
        readonly property var entries: (root.findNode(root.menu, nodeId)?.children ?? []).filter(e => e.visible !== false)
        readonly property bool hasChildren: entries.some(e => e.type !== "separator")
        property bool isSubMenu
        property bool shown

        padding: Tokens.padding.small
        spacing: Tokens.spacing.small

        opacity: shown ? 1 : 0
        scale: shown ? 1 : 0.8

        Component.onCompleted: shown = true
        StackView.onActivating: shown = true
        StackView.onDeactivating: shown = false
        StackView.onRemoved: destroy()

        Behavior on opacity {
            Anim {
                type: Anim.DefaultEffects
            }
        }

        Behavior on scale {
            Anim {}
        }

        Repeater {
            model: menu.entries

            StyledRect {
                id: item

                required property var modelData
                readonly property bool isSeparator: modelData.type === "separator"
                readonly property bool entryEnabled: modelData.enabled !== false
                readonly property bool entryHasChildren: (modelData.children?.length ?? 0) > 0
                readonly property string entryIcon: modelData.iconName ? Quickshell.iconPath(modelData.iconName, true) : ""

                implicitWidth: Tokens.sizes.bar.trayMenuWidth
                implicitHeight: isSeparator ? 1 : children.implicitHeight

                radius: Tokens.rounding.full
                color: isSeparator ? Colours.palette.m3outlineVariant : "transparent"

                Loader {
                    id: children

                    asynchronous: true
                    anchors.left: parent.left
                    anchors.right: parent.right

                    active: !item.isSeparator

                    sourceComponent: Item {
                        implicitHeight: label.implicitHeight

                        StateLayer {
                            anchors.margins: -Tokens.padding.extraSmall / 2
                            anchors.leftMargin: -Tokens.padding.small
                            anchors.rightMargin: -Tokens.padding.small

                            radius: item.radius
                            disabled: !item.entryEnabled

                            onClicked: {
                                if (item.entryHasChildren)
                                    root.push(subMenuComp.createObject(null, {
                                        nodeId: item.modelData.id,
                                        isSubMenu: true
                                    }));
                                else {
                                    R.Tray.menuEvent(root.service, item.modelData.id);
                                    root.popouts.hasCurrent = false;
                                }
                            }
                        }

                        Loader {
                            id: icon

                            asynchronous: true
                            anchors.left: parent.left

                            active: item.entryIcon !== ""

                            sourceComponent: IconImage {
                                asynchronous: true
                                implicitSize: label.implicitHeight

                                source: item.entryIcon
                            }
                        }

                        StyledText {
                            id: label

                            anchors.left: icon.right
                            anchors.leftMargin: icon.active ? Tokens.spacing.medium : 0

                            text: labelMetrics.elidedText
                            color: item.entryEnabled ? Colours.palette.m3onSurface : Colours.palette.m3outline
                        }

                        TextMetrics {
                            id: labelMetrics

                            text: root.cleanLabel(item.modelData.label)
                            font: label.font

                            elide: Text.ElideRight
                            elideWidth: root.Tokens.sizes.bar.trayMenuWidth - (icon.active ? icon.implicitWidth + label.anchors.leftMargin : 0) - (expand.active ? expand.implicitWidth + root.Tokens.spacing.medium : 0)
                        }

                        Loader {
                            id: expand

                            asynchronous: true
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.right: parent.right

                            active: item.entryHasChildren

                            sourceComponent: MaterialIcon {
                                text: "chevron_right"
                                color: item.entryEnabled ? Colours.palette.m3onSurface : Colours.palette.m3outline
                            }
                        }
                    }
                }
            }
        }

        Loader {
            asynchronous: true
            active: menu.isSubMenu

            sourceComponent: Item {
                implicitWidth: back.implicitWidth
                implicitHeight: back.implicitHeight + Tokens.spacing.extraSmall

                Item {
                    anchors.bottom: parent.bottom
                    implicitWidth: back.implicitWidth
                    implicitHeight: back.implicitHeight

                    StyledRect {
                        anchors.fill: parent
                        anchors.margins: -Tokens.padding.extraSmall / 2
                        anchors.leftMargin: -Tokens.padding.small
                        anchors.rightMargin: -Tokens.padding.large

                        radius: Tokens.rounding.full
                        color: Colours.palette.m3secondaryContainer

                        StateLayer {
                            radius: parent.radius
                            color: Colours.palette.m3onSecondaryContainer
                            onClicked: root.pop()
                        }
                    }

                    Row {
                        id: back

                        anchors.verticalCenter: parent.verticalCenter

                        MaterialIcon {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "chevron_left"
                            color: Colours.palette.m3onSecondaryContainer
                        }

                        StyledText {
                            anchors.verticalCenter: parent.verticalCenter
                            text: Tr.trCtx("Back", "button")
                            color: Colours.palette.m3onSecondaryContainer
                        }
                    }
                }
            }
        }
    }
}
