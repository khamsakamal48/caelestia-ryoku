pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import Caelestia.Blobs
import Caelestia.Config as CC
import Ryoku.Ui.Singletons
import shell.services as R
import "cae/services" as Cae
import "cae/components" as CaeC
import "cae/modules/bar" as Bar
import "cae/modules/bar/popouts" as BarPopouts
import "cae/modules/dashboard" as Dashboard
import "cae/modules/session" as Session
import "cae/modules/launcher" as Launcher
import "cae/modules/sidebar" as Sidebar

// Caelestia's shell frame for Ryoku.
//
// A port of caelestia-dots/shell's drawers window (modules/drawers/
// ContentWindow + Panels + Interactions + Regions): Caelestia's own bar, bar
// popouts, dashboard and session menu (vendored under cae/) inside its blob
// border, laid out and driven the way Caelestia does, plus its launcher,
// notification sidebar (fed by Ryoku's notification server) and Nexus
// settings app. Ryoku's Controls (Super+Escape) is hosted as a
// centred right-border drawer. Ryoku keeps what it owns: notifications, OSDs,
// keybinds, wallpaper and theme, and session actions (routed through Ryoku's
// session daemon).
Scope {
    id: root

    property var modelData

    readonly property bool fullscreen: Wm.outputHasFullscreen(root.modelData ? root.modelData.name : "")

    // Edge reservations, as Caelestia's drawers/Exclusions: the bar's zone on
    // the left, the border thickness elsewhere.
    component Exclusion: PanelWindow {
        required property int size
        screen: root.modelData
        color: "transparent"
        mask: Region {}
        exclusiveZone: root.fullscreen ? 0 : size
        implicitWidth: 1
        implicitHeight: 1
        WlrLayershell.namespace: "ryoku-caelestia-exclusion"
    }
    // Caelestia's shortcuts and IPC exist once, owned by the first screen's scene.
    LazyLoader {
        active: Quickshell.screens.length > 0 && Quickshell.screens[0] === root.modelData

        Shortcuts {}
    }

    Exclusion { size: bar.exclusiveZone; anchors { left: true; top: true; bottom: true } }
    Exclusion { size: win.borderThickness; anchors { top: true; left: true; right: true } }
    Exclusion { size: win.borderThickness; anchors { right: true; top: true; bottom: true } }
    Exclusion { size: win.borderThickness; anchors { bottom: true; left: true; right: true } }

    PanelWindow {
        id: win

        readonly property var screenState: Cae.ShellState.forScreen(root.modelData)
        readonly property real borderThickness: contentItem.CC.Config.border.thickness
        readonly property real borderRounding: contentItem.CC.Config.border.rounding
        readonly property color surfaceColour: Cae.Colours.tPalette.m3surface
        // Ryoku's Controls (Super+Escape); its own window stays hidden under this bar style.
        readonly property bool controlsOpen: R.SidebarState.isOpen(root.modelData)

        screen: root.modelData
        visible: !root.fullscreen && !!screenState
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        anchors { top: true; bottom: true; left: true; right: true }

        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.keyboardFocus: screenState?.launcher || screenState?.session || controlsOpen ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
        WlrLayershell.namespace: "ryoku-caelestia-bar"

        // Caelestia's drawers/Regions: input on the bar and border, and on each
        // panel while it shows; the screen inside the border clicks through.
        mask: Region {
            x: bar.clampedWidth
            y: win.contentItem.CC.Config.border.clampedThickness
            width: win.width - bar.clampedWidth - win.contentItem.CC.Config.border.clampedThickness
            height: win.height - win.contentItem.CC.Config.border.clampedThickness * 2
            intersection: Intersection.Xor

            PanelRegion {
                panel: dashboard
                y: 0
                height: panel.height * (1 - dashboard.offsetScale) + win.borderThickness
            }
            PanelRegion {
                panel: launcher
                y: win.height - height
                height: panel.height * (1 - launcher.offsetScale) + win.borderThickness
            }
            PanelRegion {
                id: sessionRegion
                panel: sessionWrapper
                x: win.width - width
                width: panel.width * (1 - session.offsetScale) + win.borderThickness + Math.max(sidebarRegion.width, controlsRegion.width)
            }
            PanelRegion {
                id: sidebarRegion
                panel: sidebar
                x: win.width - width
                width: panel.width * (1 - sidebar.offsetScale) + win.borderThickness
            }
            PanelRegion {
                id: controlsRegion
                panel: controls
                x: win.width - width
                width: panel.width * (1 - controls.offsetScale) + win.borderThickness
            }
            PanelRegion {
                panel: notifPopups
                x: win.width - width
                width: panel.width * (1 - notifPopups.offsetScale) + win.borderThickness
            }
            PanelRegion {
                panel: popoutsWrapper
                width: panel.width * (1 - popoutsWrapper.offsetScale)
            }
        }

        component PanelRegion: Region {
            required property Item panel
            x: panel.x + bar.implicitWidth
            y: panel.y + win.borderThickness
            width: panel.width
            height: panel.height
            intersection: Intersection.Subtract
        }

        // Clicking outside the launcher or session menu closes it, as in Caelestia.
        HyprlandFocusGrab {
            active: !!(win.screenState?.launcher || win.screenState?.session || win.screenState?.sidebar || win.controlsOpen)
            windows: [win]
            onCleared: {
                win.screenState.launcher = false;
                win.screenState.session = false;
                win.screenState.sidebar = false;
                R.SidebarState.close(root.modelData);
            }
        }

        // The notification sidebar and Controls share the right edge: one at a time.
        Connections {
            target: win.screenState
            function onSidebarChanged() {
                if (win.screenState.sidebar)
                    R.SidebarState.close(root.modelData);
            }
        }
        onControlsOpenChanged: if (controlsOpen && screenState)
            screenState.sidebar = false

        // Caelestia's border and panel backgrounds: one blob group, so panels
        // melt out of the border and wobble as they move.
        Item {
            anchors.fill: parent
            opacity: win.surfaceColour.a
            layer.enabled: true
            layer.effect: MultiEffect {
                shadowEnabled: true
                blurMax: 15
                shadowColor: Qt.alpha(Cae.Colours.palette.m3shadow, 0.7)
            }

            BlobGroup {
                id: blobGroup

                color: win.surfaceColour
                smoothing: win.contentItem.CC.Config.border.smoothing
            }

            BlobInvertedRect {
                anchors.fill: parent
                anchors.margins: -50 // Make border thicker to smooth out bulge from closed drawers
                group: blobGroup
                radius: win.borderRounding
                borderLeft: bar.implicitWidth - anchors.margins
                borderRight: win.borderThickness - anchors.margins
                borderTop: win.borderThickness - anchors.margins
                borderBottom: win.borderThickness - anchors.margins
            }

            PanelBg {
                id: dashBg

                panel: dashboard
                deformAmount: 0.1
            }

            PanelBg {
                id: launcherBg

                panel: launcher
                deformAmount: 0.1
            }

            PanelBg {
                id: sidebarBg

                panel: sidebar
                deformAmount: 0.03
                implicitHeight: panel.height * (1 / rawDeformMatrix.m22) + 2
            }

            PanelBg {
                id: notifBg

                panel: notifPopups
                deformAmount: 0.1
            }

            PanelBg {
                id: controlsBg

                panel: controls
                deformAmount: 0.1
            }

            PanelBg {
                id: sessionBg

                panel: sessionWrapper
                deformAmount: 0.2
                x: sessionWrapper.x + session.x + bar.implicitWidth
                implicitWidth: session.width
            }

            PanelBg {
                id: popoutBg

                // Extra width to prevent vertical movement deformation partially detaching panel from bar
                property real extraWidth: win.popouts.isDetached ? 0 : 0.2

                panel: popoutsWrapper
                deformAmount: win.popouts.isDetached ? 0.05 : win.popouts.hasCurrent ? 0.15 : 0.1
                x: popoutsWrapper.x + win.popouts.x + bar.implicitWidth - win.popouts.width * extraWidth
                implicitWidth: win.popouts.width * (1 + extraWidth)

                Behavior on extraWidth {
                    NumberAnimation {
                        duration: win.contentItem.CC.Tokens.anim.durations.expressiveDefaultSpatial
                    }
                }
            }
        }

        component PanelBg: BlobRect {
            required property Item panel
            property real deformAmount: 0.15

            group: blobGroup
            x: panel.x + bar.implicitWidth
            y: panel.y + win.borderThickness
            implicitWidth: panel.width
            implicitHeight: panel.height
            radius: win.contentItem.CC.Tokens.rounding.extraLarge
            deformScale: (deformAmount * win.contentItem.CC.Config.appearance.deformScale) / 10000
        }

        // Caelestia's drawers/Interactions, for the panels carried here: bar
        // popouts on hover, scroll actions on the bar, the dashboard from the
        // top edge. Panels and bar are its
        // children so their hover counts.
        MouseArea {
            id: interactions

            function withinPanelWidth(panel: Item, x: real): bool {
                const panelX = bar.implicitWidth + panel.x;
                return x >= panelX - win.borderRounding && x <= panelX + panel.width + win.borderRounding;
            }

            function withinPanelHeight(panel: Item, y: real): bool {
                const panelY = win.borderThickness + panel.y;
                return y >= panelY - win.borderRounding && y <= panelY + panel.height + win.borderRounding;
            }

            function inTopPanel(panel: Item, x: real, y: real): bool {
                const panelHeight = panel.height * (1 - (panel.offsetScale ?? 0));
                return y < Math.max(win.contentItem.CC.Config.border.minThickness, win.borderThickness + panelHeight) && withinPanelWidth(panel, x);
            }

            function inBottomPanel(panel: Item, x: real, y: real): bool {
                const panelHeight = panel.height * (1 - (panel.offsetScale ?? 0));
                return y > height - Math.max(win.contentItem.CC.Config.border.minThickness, win.borderThickness + panelHeight) && withinPanelWidth(panel, x);
            }

            function inLeftPanel(panel: Item, x: real, y: real): bool {
                return x < bar.implicitWidth + panel.x + panel.width && withinPanelHeight(panel, y);
            }

            function inRightPanel(panel: Item, x: real, y: real): bool {
                const panelWidth = panel.width * (1 - (panel.offsetScale ?? 0));
                return x > width - Math.max(win.contentItem.CC.Config.border.minThickness, win.borderThickness + panelWidth) && withinPanelHeight(panel, y);
            }

            function trayMenuOpen(): bool {
                return win.popouts.currentName.startsWith("traymenu") && ((win.popouts.current as StackView)?.depth ?? 0) > 1;
            }

            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.NoButton

            onWheel: event => {
                if (event.x < bar.implicitWidth)
                    bar.handleWheel(event.y, event.angleDelta);
            }

            onContainsMouseChanged: {
                if (containsMouse)
                    return;
                win.screenState.dashboard = false;
                if (!trayMenuOpen()) {
                    win.popouts.hasCurrent = false;
                    bar.closeTray();
                }
            }

            onPositionChanged: event => {
                if (win.popouts.isDetached)
                    return;

                const x = event.x;
                const y = event.y;

                win.screenState.dashboard = win.contentItem.CC.Config.dashboard.showOnHover && inTopPanel(dashboard, x, y);

                if (win.contentItem.CC.Config.launcher.showOnHover && !win.screenState.launcher && inBottomPanel(launcher, x, y))
                    win.screenState.launcher = true;

                // Right edge: the middle third opens Controls (Super+Escape), the top corner the notification sidebar (Super+G).
                if (x >= width - Math.max(win.contentItem.CC.Config.border.minThickness, win.borderThickness) - 1) {
                    if (y < 80 * Tokens.uiScaleFor(root.modelData.name)) {
                        if (!win.screenState.sidebar && !win.controlsOpen)
                            win.screenState.sidebar = true;
                    } else if (y > height / 3 && y < height * 2 / 3 && !win.controlsOpen && !win.screenState.sidebar) {
                        R.SidebarState.open(root.modelData);
                    }
                }

                if (x < bar.implicitWidth) {
                    bar.checkPopout(y);
                } else if (!trayMenuOpen() && !inLeftPanel(popoutsWrapper, x, y)) {
                    win.popouts.hasCurrent = false;
                    bar.closeTray();
                }
            }

            // Caelestia's drawers/Panels, inside the bar and the border.
            Item {
                id: panels

                readonly property alias dashboard: dashboard
                readonly property alias launcher: launcher
                readonly property alias bar: bar
                readonly property var popouts: win.popouts

                anchors.fill: parent
                anchors.margins: win.borderThickness
                anchors.leftMargin: bar.implicitWidth

                Item {
                    id: sessionWrapper

                    anchors.verticalCenter: parent.verticalCenter
                    anchors.right: parent.right
                    anchors.rightMargin: Math.max(sidebar.width * (1 - sidebar.offsetScale), controls.width * (1 - controls.offsetScale))
                    clip: sidebar.visible || controls.visible

                    implicitWidth: session.implicitWidth * (1 - session.offsetScale)
                    implicitHeight: session.implicitHeight

                    Session.Wrapper {
                        id: session

                        screenState: win.screenState
                        sidebarVisible: sidebar.visible || controls.visible

                        anchors.verticalCenter: parent.verticalCenter
                        anchors.right: parent.right
                        transform: Matrix4x4 {
                            matrix: sessionBg.deformMatrix
                        }
                    }
                }

                // Caelestia stacks this under its notification popups and above
                // its utilities panel; the utilities panel is not carried.
                Sidebar.Wrapper {
                    id: sidebar

                    screenState: win.screenState

                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    anchors.right: parent.right
                    transform: Matrix4x4 {
                        matrix: sidebarBg.deformMatrix
                    }
                }

                // Ryoku's Controls (Super+Escape), content untouched, hosted like the
                // session menu: centred on the right border, melting out of it.
                Item {
                    id: controls

                    readonly property bool shouldBeActive: win.controlsOpen
                    readonly property real s: Tokens.uiScaleFor(root.modelData.name)
                    property real offsetScale: shouldBeActive ? 0 : 1

                    anchors.verticalCenter: parent.verticalCenter
                    anchors.right: parent.right
                    anchors.rightMargin: (-implicitWidth - 5) * offsetScale
                    implicitWidth: Math.min(688 * s, parent.width - 40)
                    implicitHeight: Math.min(parent.height, controlsContent.item?.fittedHeight ?? 0)
                    visible: offsetScale < 1
                    opacity: 1 - offsetScale
                    transform: Matrix4x4 {
                        matrix: controlsBg.deformMatrix
                    }

                    Behavior on offsetScale {
                        CaeC.Anim {}
                    }

                    Loader {
                        id: controlsContent

                        anchors.fill: parent
                        active: controls.shouldBeActive || controls.visible
                        focus: controls.shouldBeActive
                        Keys.onEscapePressed: R.SidebarState.close(root.modelData)
                        Component.onCompleted: setSource(Quickshell.shellPath("modules/sidebar/SidebarChrome.qml"), {
                            screen: root.modelData,
                            s: Qt.binding(() => controls.s),
                            active: Qt.binding(() => controls.shouldBeActive)
                        })

                        Connections {
                            target: controlsContent.item
                            function onCloseRequested() {
                                R.SidebarState.close(root.modelData);
                            }
                        }
                    }
                }

                Dashboard.Wrapper {
                    id: dashboard

                    screenState: win.screenState

                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.top
                    transform: Matrix4x4 {
                        matrix: dashBg.deformMatrix
                    }
                }

                Launcher.Wrapper {
                    id: launcher

                    screen: root.modelData
                    screenState: win.screenState
                    panels: panels

                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    transform: Matrix4x4 {
                        matrix: launcherBg.deformMatrix
                    }
                }

                NotifPopups {
                    id: notifPopups

                    blocked: sidebar.visible || controls.visible

                    anchors.top: parent.top
                    anchors.right: parent.right
                    anchors.rightMargin: (-implicitWidth - 5) * offsetScale
                    transform: Matrix4x4 {
                        matrix: notifBg.deformMatrix
                    }
                }

                BarPopouts.ClipWrapper {
                    id: popoutsWrapper

                    screen: root.modelData
                    borderThickness: win.borderThickness
                }
            }

            Bar.BarWrapper {
                id: bar

                anchors.top: parent.top
                anchors.bottom: parent.bottom

                screen: root.modelData
                screenState: win.screenState
                popouts: win.popouts
                fullscreen: root.fullscreen
            }
        }

        readonly property alias popouts: popoutsWrapper.content
    }

}
