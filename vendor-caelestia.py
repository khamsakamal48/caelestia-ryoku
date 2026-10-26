#!/usr/bin/env python3
"""Vendor Caelestia's bar, dashboard, session menu, launcher and Nexus into caelestia/cae/.

  python3 -I vendor-caelestia.py <caelestia-shell checkout>

Copies the MODULES below plus every shell component, service and util they
reach, rewrites `import qs.X` to relative directory imports (inside a Ryoku bar
style `qs` is Ryoku's own shell root), applies the PATCHES and CUTS (each
asserts its target still matches, so an upstream change fails loudly instead of
silently), and writes a qmldir per directory so the singletons resolve.

Services in ADAPTED are not copied: hand-written adapters in
caelestia/cae-adapters/ back them with Ryoku's services. Files in
caelestia/cae-extras/ are added at the same path under cae/ (new features, such
as the dashboard's AI usage tab; they may not replace an upstream file). Wallpaper and colour
scheme pickers (launcher >wallpaper/>scheme/>variant, Nexus "Wallpaper &
style") are left out: Ryoku's own app owns wallpaper and theme. Re-run after
pulling a newer Caelestia.
"""
import os, re, shutil, sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
OUT = HERE / "caelestia" / "cae"
ADAPTERS = HERE / "caelestia" / "cae-adapters"
EXTRAS = HERE / "caelestia" / "cae-extras"
MODULES = ["modules/dashboard", "modules/bar", "modules/windowinfo", "modules/session",
           "modules/launcher", "modules/nexus", "modules/sidebar"]
ADAPTED = {"Colours", "Players", "Weather", "Notifs"}
# Reached only through code we leave out; nothing shown needs them.
SKIP = {"Recorder", "Wallpapers"}
# Wallpaper / colour-scheme pickers, which drive Caelestia's CLI; Ryoku owns these.
EXCLUDE = {
    "modules/launcher/WallpaperList.qml",
    "modules/launcher/items/WallpaperItem.qml",
    "modules/launcher/items/SchemeItem.qml",
    "modules/launcher/items/VariantItem.qml",
    "modules/launcher/services/Schemes.qml",
    "modules/launcher/services/M3Variants.qml",
    "modules/nexus/pages/WallpaperAndStyle.qml",
    "modules/nexus/pages/wallandstyle/ColourSelect.qml",
    "modules/nexus/pages/wallandstyle/WallpaperCategory.qml",
    "modules/nexus/pages/wallandstyle/WallpaperSelect.qml",
    # Drawn from Ryoku's tray daemon instead (cae-extras/modules/bar/popouts/DaemonTrayMenu.qml).
    "modules/bar/popouts/TrayMenu.qml",
}
ASSETS = ["bongocat.gif", "logo.svg", "kurukuru.gif"]

# (file, old, new): exact replacements applied after the import rewrite.
PATCHES = [
    # Language & region keeps no weather settings (see NEXUS_CUTS).
    ("modules/nexus/PageRegistry.qml",
     'description: Tr.tr("UI language, weather location, display units")',
     'description: Tr.tr("UI language, display units")'),
    # Caelestia's root:/ is its own shell dir; here it is this vendored tree.
    ("utils/Paths.qml",
     '    readonly property string home: Quickshell.env("HOME")',
     '    readonly property string home: Quickshell.env("HOME")\n'
     '    // Vendored copy: Caelestia\'s root:/ is this tree, not the running shell.\n'
     '    readonly property string shellRoot: Qt.resolvedUrl("..")'),
    ("utils/Paths.qml",
     "return toLocalFile(path.replace(/~|(\\$({?)HOME(}?))+/, home));",
     "return toLocalFile(path.replace(/^root:\\//, root.shellRoot).replace(/~|(\\$({?)HOME(}?))+/, home));"),
    ("utils/SysInfo.qml",
     "Qt.resolvedUrl(`${Quickshell.shellDir}/assets/logo.svg`)",
     'Qt.resolvedUrl("../assets/logo.svg")'),
    # The bar and dashboard show the Arch logo where Caelestia's own would be.
    ("utils/SysInfo.qml",
     'property string osLogo: Qt.resolvedUrl("../assets/logo.svg")\n    property bool isDefaultLogo: true',
     'property string osLogo: "file:///usr/share/pixmaps/archlinux-logo.svg"\n    property bool isDefaultLogo: false'),
    ("utils/SysInfo.qml",
     'root.osLogo = Qt.resolvedUrl(`${Quickshell.shellDir}/assets/logo.svg`);\n                root.isDefaultLogo = true;',
     'root.osLogo = "file:///usr/share/pixmaps/archlinux-logo.svg";\n                root.isDefaultLogo = false;'),
    # Ryoku owns Hyprland keybinds: don't bind Caps/Num Lock at runtime to
    # refresh the lock indicators; poll the device state (one IPC call) instead.
    ("services/Hypr.qml",
     "    function reloadDynamicConfs(): void {\n        if (usingLua) {",
     "    function reloadDynamicConfs(): void {\n        return; // Ryoku owns keybinds; see deviceRefresh below\n        if (usingLua) {"),
    ("services/Hypr.qml",
     "    HyprExtras {\n        id: extras",
     "    Timer {\n        id: deviceRefresh\n\n        interval: 1000\n        running: true\n        repeat: true\n"
     "        onTriggered: extras.refreshDevices()\n    }\n\n    HyprExtras {\n        id: extras"),
    # Lyrics: Caelestia's lookup first, then a cleaned-title LRCLIB search for
    # browser/YouTube metadata (cae-adapters/LyricsMatch.qml).
    ("modules/dashboard/media/LyricList.qml",
     "            Lyrics.setTrack(p.trackArtist, p.trackTitle, p.trackAlbum, p.length);\n        else\n            Lyrics.clearTrack();",
     "            LyricsMatch.setTrack(p.trackArtist, p.trackTitle, p.trackAlbum, p.length);\n        else\n            LyricsMatch.clearTrack();"),
    # Nexus has no "appearance" page here (Wallpaper & style is left out).
    ("modules/bar/popouts/Wrapper.qml",
     '["appearance", "network", "bluetooth", "audio"].indexOf(root.queuedMode)',
     '["network", "bluetooth", "audio"].indexOf(root.queuedMode)'),
    # Session actions go through Ryoku's session daemon (it ends the Ryoku
    # session cleanly); hibernate, which Ryoku doesn't offer, stays Caelestia's.
    ("modules/session/Content.qml", "import Caelestia.Services\n", "import Caelestia.Services\nimport shell.services as R\n"),
    ("modules/session/Content.qml",
     "            if (!SessionManager.exec(command))\n                Quickshell.execDetached(command);",
     "            const ryoku = { logout: \"logout\", poweroff: \"shutdown\", reboot: \"reboot\" }[command[0]];\n"
     "            if (command.length === 1 && ryoku)\n                R.SessionActions.run(ryoku);\n"
     "            else if (!SessionManager.exec(command))\n                Quickshell.execDetached(command);"),
    # Launcher: no wallpaper list.
    ("modules/launcher/ContentList.qml",
     "    readonly property bool showWallpapers: search.text.startsWith(`${GlobalConfig.launcher.actionPrefix}wallpaper `)\n"
     "    readonly property var currentList: showWallpapers ? wallpaperList.item : appList.item",
     "    readonly property bool showWallpapers: false // Ryoku owns wallpapers\n"
     "    readonly property var currentList: appList.item"),
    # Launcher: no scheme / variant lists.
    ("modules/launcher/AppList.qml",
     'for (const action of ["calc", "scheme", "variant"])', 'for (const action of ["calc"])'),
    ("modules/launcher/AppList.qml",
     '        case "scheme":\n            return Schemes.query(text);\n        case "variant":\n            return M3Variants.query(text);\n', ""),
    # Launcher actions: drop the wallpaper/scheme/mode ones; route session
    # actions through Ryoku and "Settings" to the vendored Nexus.
    ("modules/launcher/services/Actions.qml", "import \"../../../utils\"\n", "import \"../../../utils\"\nimport \"../../nexus\"\nimport shell.services as R\n"),
    ("modules/launcher/services/Actions.qml",
     "            return GlobalConfig.launcher.actions.values.filter(a => a.enabled && (enableDangerous || !a.dangerous));",
     "            return GlobalConfig.launcher.actions.values.filter(a => a.enabled && (enableDangerous || !a.dangerous) && !root.ryokuOwned(a.command ?? []));"),
    ("modules/launcher/services/Actions.qml",
     "    list: variants.instances",
     "    // Wallpaper and colour scheme belong to Ryoku's own app.\n"
     "    function ryokuOwned(command: var): bool {\n"
     "        const c = Array.from(command);\n"
     "        return c[0] === \"setMode\" || (c[0] === \"caelestia\" && c[1] === \"wallpaper\")\n"
     "            || (c[0] === \"autocomplete\" && [\"scheme\", \"variant\", \"wallpaper\"].includes(c[1]));\n"
     "    }\n\n    list: variants.instances"),
    ("modules/launcher/services/Actions.qml",
     "                list.screenState.launcher = false;\n                if (!SessionManager.exec(command))\n                    Quickshell.execDetached(command);",
     "                list.screenState.launcher = false;\n"
     "                const ryoku = { logout: \"logout\", poweroff: \"shutdown\", reboot: \"reboot\" }[command[0]];\n"
     "                if (command.length === 1 && ryoku)\n                    R.SessionActions.run(ryoku);\n"
     "                else if (command.join(\" \") === \"caelestia shell nexus open\")\n                    WindowFactory.create();\n"
     "                else if (!SessionManager.exec(command))\n                    Quickshell.execDetached(command);"),
    # Utilities (Panels sub-page 5) is cut below, so the taskbar component sub-pages
    # after it each move up one index. Ascending order keeps each match unique.
    *(("modules/nexus/pages/panels/TaskbarPanel.qml",
       f"onClicked: root.nState.openSubPage({i})", f"onClicked: root.nState.openSubPage({i - 1})")
      for i in range(6, 11)),
    # Tray: Ryoku's daemon (R.Tray) is the StatusNotifier host, not Quickshell's SystemTray.
    # Its watcher announces items as ":1.x" but withdraws them as ":1.x/StatusNotifierItem",
    # which Quickshell's host never matches, so quit apps left stale icons. Models hold
    # item services; delegates look the live item up, so a republish updates in place.
    ("modules/bar/components/Tray.qml", "import Quickshell.Services.SystemTray\n", "import shell.services as R\n"),
    ("modules/bar/components/Tray.qml",
     "values: SystemTray.items.values.filter(i => i.status !== Status.Passive && !GlobalConfig.bar.tray.hiddenIcons.includes(i.id))",
     'values: R.Tray.items.filter(i => i.status !== "Passive" && !GlobalConfig.bar.tray.hiddenIcons.includes(i.id)).map(i => i.service)'),
    ("modules/bar/components/TrayItem.qml", "import Quickshell.Services.SystemTray\n", "import Quickshell\nimport shell.services as R\n"),
    ("modules/bar/components/TrayItem.qml",
     "    required property SystemTrayItem modelData\n",
     "    required property string modelData // the item's service\n"
     "    readonly property var item: R.Tray.items.find(i => i.service === modelData) ?? null\n"),
    ("modules/bar/components/TrayItem.qml",
     "            modelData.activate();\n        else\n            modelData.secondaryActivate();",
     "            R.Tray.activate(root.modelData);\n        else\n"
     "            R.Tray.send(\"tray.secondaryActivate\", {\n                service: root.modelData\n            });"),
    ("modules/bar/components/TrayItem.qml",
     "Icons.getTrayIcon(root.modelData.id, root.modelData.icon)",
     "Icons.getTrayIcon(root.item?.id ?? \"\", root.item?.iconPath ? `file://${root.item.iconPath}` : Quickshell.iconPath(root.item?.iconName ?? \"\", true))"),
    ("modules/bar/popouts/Content.qml", "import Quickshell.Services.SystemTray\n", "import shell.services as R\n"),
    ("modules/bar/popouts/Content.qml",
     "SystemTray.items.values.filter(i => i.status !== Status.Passive && !GlobalConfig.bar.tray.hiddenIcons.includes(i.id)).reduce((acc, item, i) => {\n        acc[item.id] = i;",
     "R.Tray.items.filter(i => i.status !== \"Passive\" && !GlobalConfig.bar.tray.hiddenIcons.includes(i.id)).reduce((acc, item, i) => {\n        acc[item.service] = i;"),
    ("modules/bar/popouts/Content.qml",
     "values: SystemTray.items.values.filter(i => i.hasMenu && i.status !== Status.Passive && !GlobalConfig.bar.tray.hiddenIcons.includes(i.id))",
     "values: R.Tray.items.filter(i => (i.menu?.children?.length ?? 0) > 0 && i.status !== \"Passive\" && !GlobalConfig.bar.tray.hiddenIcons.includes(i.id)).map(i => i.service)"),
    ("modules/bar/popouts/Content.qml",
     "                required property SystemTrayItem modelData\n\n                name: `traymenu${root.trayItemsToIndices[modelData.id]}`",
     "                required property string modelData // the item's service\n\n                name: `traymenu${root.trayItemsToIndices[modelData]}`"),
    ("modules/bar/popouts/Content.qml",
     "                    TrayMenu {\n                        popouts: root.popouts\n                        trayItem: trayMenu.modelData.menu // qmllint disable unresolved-type\n",
     "                    DaemonTrayMenu {\n                        popouts: root.popouts\n                        service: trayMenu.modelData\n"),
    # Dashboard media card: Claude usage tile (cae-extras/modules/dashboard/dash/AiUsageTile.qml) under it instead of the bongo-cat GIF;
    # the cover shrinks to fit the shorter card.
    ("modules/dashboard/dash/Media.qml", '\n    AnimatedImage {\n        id: bongocat\n\n        anchors.top: controls.bottom\n        anchors.bottom: parent.bottom\n        anchors.left: parent.left\n        anchors.right: parent.right\n        anchors.topMargin: Tokens.spacing.small\n        anchors.bottomMargin: Tokens.padding.large\n        anchors.margins: Tokens.padding.extraLargeIncreased\n\n        playing: Players.active?.isPlaying ?? false\n        speed: Audio.beatTracker.bpm / Config.general.mediaGifSpeedAdjustment // qmllint disable unresolved-type\n        source: Paths.absolutePath(Config.paths.mediaGif)\n        asynchronous: true\n        fillMode: AnimatedImage.PreserveAspectFit\n    }\n', ""),
    ("modules/dashboard/dash/Media.qml", '        anchors.top: parent.top\n        anchors.left: parent.left\n        anchors.right: parent.right\n        anchors.margins: Tokens.padding.medium + root.arcCoverGap + prog.thickness\n        implicitHeight: width\n', '        // Shrinks to leave room for the title, album, artist and controls when the card is short.\n        readonly property real inset: Tokens.padding.medium + root.arcCoverGap + prog.thickness\n\n        anchors.top: parent.top\n        anchors.horizontalCenter: parent.horizontalCenter\n        anchors.topMargin: inset\n        implicitWidth: Math.min(root.width - inset * 2, root.height - inset - title.implicitHeight - album.implicitHeight - artist.implicitHeight - controls.implicitHeight - Tokens.spacing.medium * 2 - Tokens.spacing.small * 2 - Tokens.padding.large * 2)\n        implicitHeight: implicitWidth\n'),
    ("modules/dashboard/Dash.qml", '    Rect {\n        Layout.row: 0\n        Layout.column: 5\n        Layout.rowSpan: 2\n        Layout.preferredWidth: media.implicitWidth\n        Layout.fillHeight: true\n\n        radius: Tokens.rounding.extraLarge * 2\n\n        Media {\n            id: media\n        }\n    }\n\n', '    // Media above, Claude usage below it, in one column.\n    ColumnLayout {\n        Layout.row: 0\n        Layout.column: 5\n        Layout.rowSpan: 2\n        Layout.preferredWidth: media.implicitWidth\n        Layout.fillHeight: true\n        spacing: root.rowSpacing\n\n        Rect {\n            Layout.fillWidth: true\n            Layout.fillHeight: true\n\n            radius: Tokens.rounding.extraLarge * 1.5\n\n            Media {\n                id: media\n            }\n        }\n\n        Rect {\n            visible: AiUsage.settings.showTile\n            Layout.fillWidth: true\n            Layout.preferredHeight: aiUsage.implicitHeight\n\n            radius: Tokens.rounding.extraLarge\n\n            AiUsageTile {\n                id: aiUsage\n\n                anchors.fill: parent\n            }\n        }\n    }\n\n'),
    ("utils/SysInfo.qml", 'root.uptimeShort = parts.slice(0, 2).join(sep);', '// Compact ("5 hrs. 2 min.") so the dashboard badge is not truncated.\n            root.uptimeShort = days > 0 ? `${days} ${days === 1 ? "day" : "days"} ${hours} ${hours === 1 ? "hr." : "hrs."}` : hours > 0 ? `${hours} ${hours === 1 ? "hr." : "hrs."} ${minutes} min.` : `${minutes} min.`;'),
    # Dashboard badge beside the photo: full name (passwd GECOS) or the window manager, per AiUsage.settings.showFullName.
    ("utils/SysInfo.qml", "    readonly property string shell:", "    // Real name from the passwd GECOS field; the login name when it is empty.\n    property string fullName: user\n    readonly property string shell:"),
    ("utils/SysInfo.qml", "    FileView {\n        id: osRelease",
     "    Process {\n        running: true\n        command: [\"getent\", \"passwd\", root.user]\n        stdout: StdioCollector {\n            onStreamFinished: root.fullName = text.split(\":\")[4]?.split(\",\")[0].trim() || root.user\n        }\n    }\n\n    FileView {\n        id: osRelease"),
    ("modules/dashboard/dash/User.qml", 'text: "select_window"', 'text: AiUsage.settings.showFullName ? "person" : "select_window"'),
    ("modules/dashboard/dash/User.qml", 'text: SysInfo.wm + "..."', 'text: (AiUsage.settings.showFullName ? SysInfo.fullName : SysInfo.wm) + "..."'),
    ("modules/nexus/pages/panels/DashboardPanel.qml",
     "        ToggleRow {\n            last: true\n            text: Tr.tr(\"Show clock seconds\")\n            subtext: Tr.tr(\"Display seconds for the clock in the main panel\")\n            checked: Config.dashboard.showClockSeconds\n            onToggled: GlobalConfig.dashboard.showClockSeconds = checked\n        }\n",
     "        ToggleRow {\n            text: Tr.tr(\"Show clock seconds\")\n            subtext: Tr.tr(\"Display seconds for the clock in the main panel\")\n            checked: Config.dashboard.showClockSeconds\n            onToggled: GlobalConfig.dashboard.showClockSeconds = checked\n        }\n\n"
     "        ToggleRow {\n            last: true\n            text: Tr.tr(\"Show full name\")\n            subtext: Tr.tr(\"Beside your photo, show your name instead of the window manager\")\n            checked: AiUsage.settings.showFullName\n            onToggled: AiUsage.settings.showFullName = checked\n        }\n"),
    # Dashboard "AI usage" tab (cae-extras/modules/dashboard/AiUsageTab.qml), last in the row.
    ("modules/dashboard/Content.qml", 'import "../../components/filedialog"\n', 'import "../../components/filedialog"\nimport "../../services"\n'),
    ("modules/dashboard/Content.qml",
     "                enabled: Config.dashboard.showWeather\n            }\n",
     "                enabled: Config.dashboard.showWeather\n            },\n"
     "            {\n                component: aiUsageComponent,\n                iconName: \"smart_toy\",\n"
     "                text: Tr.tr(\"AI usage\"),\n                enabled: AiUsage.settings.showTab\n            }\n"),
    ("modules/dashboard/Content.qml",
     "                WeatherTab {}\n            }\n",
     "                WeatherTab {}\n            }\n\n            Component {\n                id: aiUsageComponent\n\n"
     "                AiUsageTab {}\n            }\n"),
    # ...and its settings in Nexus > Panels > Dashboard (stored by the AiUsage service, not Caelestia's config).
    ("modules/nexus/pages/panels/DashboardPanel.qml", 'import "../../../../modules/nexus/common"\n',
     'import "../../../../modules/nexus/common"\nimport "../../../../services"\n'),
    ("modules/nexus/pages/panels/DashboardPanel.qml",
     "        ToggleRow {\n            last: true\n            text: Tr.tr(\"Weather\")\n            checked: Config.dashboard.showWeather\n",
     "        ToggleRow {\n            text: Tr.tr(\"Weather\")\n            checked: Config.dashboard.showWeather\n"),
    ("modules/nexus/pages/panels/DashboardPanel.qml",
     "            onToggled: GlobalConfig.dashboard.showWeather = checked\n        }\n",
     "            onToggled: GlobalConfig.dashboard.showWeather = checked\n        }\n\n"
     "        ToggleRow {\n            last: true\n            text: Tr.tr(\"AI usage\")\n"
     "            subtext: Tr.tr(\"Claude Code plan limits and daily tokens\")\n"
     "            checked: AiUsage.settings.showTab\n            onToggled: AiUsage.settings.showTab = checked\n        }\n"),
    ("modules/nexus/pages/panels/DashboardPanel.qml",
     "        // Behaviour\n",
     "        // AI usage\n        SectionHeader {\n            text: Tr.tr(\"AI usage\")\n        }\n\n"
     "        ToggleRow {\n            first: true\n            text: Tr.tr(\"5-hour session\")\n"
     "            subtext: Tr.tr(\"Usage of the rolling 5-hour limit\")\n"
     "            checked: AiUsage.settings.showSession\n            onToggled: AiUsage.settings.showSession = checked\n        }\n\n"
     "        ToggleRow {\n            text: Tr.tr(\"Weekly limit\")\n"
     "            subtext: Tr.tr(\"Usage of the 7-day plan limit\")\n"
     "            checked: AiUsage.settings.showWeekly\n            onToggled: AiUsage.settings.showWeekly = checked\n        }\n\n"
     "        ToggleRow {\n            text: Tr.tr(\"Last 7 days\")\n"
     "            subtext: Tr.tr(\"Tokens spent each day; hover a day for its total\")\n"
     "            checked: AiUsage.settings.showDaily\n            onToggled: AiUsage.settings.showDaily = checked\n        }\n\n"
     "        ToggleRow {\n            text: Tr.tr(\"Reset countdown\")\n"
     "            subtext: Tr.tr(\"Time until each limit resets; hover for the exact time\")\n"
     "            checked: AiUsage.settings.showCountdown\n            onToggled: AiUsage.settings.showCountdown = checked\n        }\n\n"
     "        ToggleRow {\n            text: Tr.tr(\"Dashboard tile\")\n"
     "            subtext: Tr.tr(\"5-hour and weekly usage as rings under the media player\")\n"
     "            checked: AiUsage.settings.showTile\n            onToggled: AiUsage.settings.showTile = checked\n        }\n\n"
     "        StepperRow {\n            last: true\n            label: Tr.tr(\"Warning threshold\")\n"
     "            subtext: Tr.tr(\"Percent used at which a limit turns red\")\n"
     "            value: AiUsage.settings.warnThreshold\n            from: 10\n            to: 100\n            stepSize: 5\n"
     "            onMoved: v => AiUsage.settings.warnThreshold = v\n        }\n\n"
     "        // Behaviour\n"),
]
# Blocks removed whole: (file, the text that starts it, the text that ends it).
CUTS = [
    ("modules/launcher/ContentList.qml", ',\n        State {\n            name: "wallpapers"\n', "\n        }"),
    ("modules/launcher/ContentList.qml", "    Loader {\n        id: wallpaperList\n", "\n    }\n"),
    ("modules/launcher/AppList.qml", ',\n        State {\n            name: "scheme"\n', "\n        }"),
    ("modules/launcher/AppList.qml", ',\n        State {\n            name: "variant"\n', "\n        }"),
    ("modules/launcher/AppList.qml", "    Component {\n        id: schemeItem\n", "\n    }\n"),
    ("modules/launcher/AppList.qml", "    Component {\n        id: variantItem\n", "\n    }\n"),
    ("modules/launcher/AppList.qml", '    onStateChanged: {\n        if (state === "scheme" || state === "variant")', "\n    }\n"),
    ("modules/nexus/PageRegistry.qml", '        {\n            label: Tr.tr("Wallpaper & style"),', "\n        },\n"),
    ("modules/nexus/PageCompRegistry.qml", "        Component {\n            // Wallpaper & style\n", "\n        },\n"),
]
# Nexus entries that do nothing on Ryoku, removed as whole QML blocks:
# (file, marker inside the block, the block's indent, optional end marker for a run of blocks).
NEXUS_CUTS = [
    # Upstream placeholders ("under construction").
    ("modules/nexus/PageRegistry.qml", 'label: Tr.tr("Updates")', 8, None),
    ("modules/nexus/PageRegistry.qml", 'label: Tr.tr("Plugins")', 8, None),
    ("modules/nexus/PageCompRegistry.qml", "PlaceholderComp {}", 8, None),
    ("modules/nexus/PageCompRegistry.qml", "PlaceholderComp {}", 8, None),
    # Caelestia's utilities panel (and its toasts) is not ported; TaskbarPanel's sub-page indices are shifted to match.
    ("modules/nexus/pages/PanelsPage.qml", 'text: Tr.tr("Utilities")', 8, None),
    ("modules/nexus/PageCompRegistry.qml", "UtilitiesPanel {}", 16, None),
    # Weather location and units are Ryoku's (its weather daemon).
    ("modules/nexus/pages/LanguageAndRegion.qml", 'text: Tr.tr("Weather")', 8, "Choose your weather location"),
    ("modules/nexus/pages/LanguageAndRegion.qml", "Units for weather temperatures", 8, None),
    # Caelestia's colour engine; Ryoku owns theme.
    ("modules/nexus/pages/ServicesPage.qml", "Derive theme mode and variant from the wallpaper", 8, None),
    # Launcher wallpaper / scheme / variant lists are left out.
    ("modules/nexus/pages/panels/LauncherPanel.qml", 'label: Tr.tr("Max wallpapers")', 8, None),
    ("modules/nexus/pages/panels/LauncherPanel.qml", 'text: Tr.tr("Schemes")', 8, None),
    ("modules/nexus/pages/panels/LauncherPanel.qml", 'text: Tr.tr("Variants")', 8, None),
    ("modules/nexus/pages/panels/LauncherPanel.qml", 'text: Tr.tr("Wallpapers")', 8, None),
    # Popups are Ryoku's and toasts aren't ported; grouping/expansion (the sidebar) stays.
    ("modules/nexus/pages/services/NotificationsPage.qml", "Whether notifications appear over fullscreen apps", 8, None),
    ("modules/nexus/pages/services/NotificationsPage.qml", "Dismiss notifications after their timeout", 8, None),
    ("modules/nexus/pages/services/NotificationsPage.qml", "Time before a notification dismisses", 8, None),
    ("modules/nexus/pages/services/NotificationsPage.qml", 'text: Tr.tr("Toasts")', 8, 'text: Tr.tr("Now playing")'),
    # No Caelestia CLI or Caelestia plugin loader here.
    ("modules/nexus/pages/AboutPage.qml", "the caelestia command line tool", 8, None),
    ("modules/nexus/pages/AboutPage.qml", "caelestia --version", 8, None),
    ("modules/nexus/pages/AboutPage.qml", 'text: Tr.tr("Plugins")', 8, 'label: Tr.tr("Loaded plugins")'),
]


def cut_qml_block(text, marker, indent, end_marker=None):
    """Remove the indent-level QML block containing marker (through the block
    containing end_marker, if given), matching braces, plus one blank line before it."""
    lines = text.split("\n")

    def block(m, start_at=0):
        i = next((k for k in range(start_at, len(lines)) if m in lines[k]), None)
        assert i is not None, f"marker not found: {m}"
        s = i
        while not (lines[s].startswith(" " * indent) and not lines[s].startswith(" " * (indent + 1))
                   and lines[s].rstrip().endswith("{")):
            s -= 1
        depth = 0
        for e in range(s, len(lines)):
            depth += lines[e].count("{") - lines[e].count("}")
            if depth == 0:
                return s, i, e
        raise AssertionError(f"unbalanced block at {m}")

    s, i, e = block(marker)
    if end_marker:
        e = block(end_marker, i)[2]
    if s > 0 and not lines[s - 1].strip():
        s -= 1
    return "\n".join(lines[:s] + lines[e + 1:])


# Applied to every vendored file: Caelestia's drawer-window re-parenting
# (Menu, Nexus PopupRow) becomes the plain window content item here.
GLOBAL_PATCHES = [
    (re.compile(r"^import \"[./]+/modules/drawers\"\n", re.M), "", "drawers import"),
    (re.compile(r"const contentWin = win as ContentWindow;[^\n]*\n\s*return contentWin \? contentWin\.interactionWrapper : \(win as QsWindow\)\.contentItem;"),
     "return (win as QsWindow).contentItem;", "ContentWindow reparent"),
    (re.compile(r"^import \"[./]+/modules/nexus/pages/wallandstyle\"\n", re.M), "", "wallandstyle import"),
]


def closure(src):
    index = {}
    for d in ("components", "services", "utils"):
        for f in sorted((src / d).rglob("*")):
            if f.suffix in (".qml", ".js"):
                index.setdefault(f.stem, f)
    start = [f for m in MODULES for f in sorted((src / m).rglob("*.qml"))
             if str(f.relative_to(src)) not in EXCLUDE]
    # Adapters and extras reach shell code too (Weather uses Icons); scan them, don't copy them here.
    seen, todo = set(start), start + sorted(ADAPTERS.glob("*.qml")) + sorted(EXTRAS.rglob("*.qml"))
    while todo:
        text = re.sub(r"//.*", "", todo.pop().read_text())
        for name in set(re.findall(r"\b([A-Z][A-Za-z0-9]+)\b", text)):
            f = index.get(name)
            if f and f not in seen and f.stem not in SKIP and f.stem not in ADAPTED:
                seen.add(f)
                todo.append(f)
    return sorted(seen)


def rewrite(text, rel_dir):
    up = os.path.relpath(".", rel_dir)

    def imp(m):
        return f'import "{up}/{m.group(1).replace(".", "/")}"{m.group(2) or ""}'
    return re.sub(r"^import qs\.([a-z.]+)( as \w+)?\s*$", imp, text, flags=re.M)


def main():
    src = Path(sys.argv[1]).resolve()
    shutil.rmtree(OUT, ignore_errors=True)
    for f in closure(src):
        rel = f.relative_to(src)
        dst = OUT / rel
        dst.parent.mkdir(parents=True, exist_ok=True)
        dst.write_text(rewrite(f.read_text(), rel.parent))

    # JS helpers are imported by path (e.g. utils/scripts/fzf.js), not by name.
    for f in list(OUT.rglob("*.qml")) + list(OUT.rglob("*.js")):
        for imp in re.findall(r'^import "([^"]+\.js)"', f.read_text(), flags=re.M):
            target = (f.parent / imp).resolve()
            source = src / target.relative_to(OUT.resolve())
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(source, target)

    hits = {name: 0 for _, _, name in GLOBAL_PATCHES}
    for f in OUT.rglob("*.qml"):
        text = f.read_text()
        for pattern, repl, name in GLOBAL_PATCHES:
            text, n = pattern.subn(repl, text)
            hits[name] += n
        f.write_text(text)
    assert all(hits.values()), f"a global patch no longer matches upstream: {hits}"

    for rel, old, new in PATCHES:
        p = OUT / rel
        text = p.read_text()
        assert old in text, f"{rel} changed upstream; update its patch:\n{old}"
        p.write_text(text.replace(old, new, 1))
    for rel, first, closing in CUTS:
        p = OUT / rel
        text = p.read_text()
        assert first in text, f"{rel} changed upstream; update its cut:\n{first}"
        start = text.index(first)
        end = text.index(closing, start + len(first)) + len(closing)
        p.write_text(text[:start] + text[end:])

    for rel, marker, indent, end_marker in NEXUS_CUTS:
        p = OUT / rel
        p.write_text(cut_qml_block(p.read_text(), marker, indent, end_marker))

    (OUT / "assets").mkdir(exist_ok=True)
    for a in ASSETS:
        shutil.copy2(src / "assets" / a, OUT / "assets" / a)
    shutil.copy2(src / "LICENSE", OUT / "LICENSE")
    for f in ADAPTERS.glob("*.qml"):
        shutil.copy2(f, OUT / "services" / f.name)
    for f in EXTRAS.rglob("*.qml"):
        dst = OUT / f.relative_to(EXTRAS)
        assert not dst.exists(), f"cae-extras would replace vendored {dst.relative_to(OUT)}; patch it instead"
        shutil.copy2(f, dst)

    for d in sorted({p.parent for p in OUT.rglob("*.qml")}):
        lines = ["# generated by vendor-caelestia.py"]
        for f in sorted(d.glob("*.qml")):
            single = "pragma Singleton" in f.read_text()
            lines.append(f"{'singleton ' if single else ''}{f.stem} {f.name}")
        (d / "qmldir").write_text("\n".join(lines) + "\n")

    # Every relative import must land on a directory we vendored, and nothing
    # left in may still name a file we excluded.
    excluded = {Path(e).stem for e in EXCLUDE}
    for f in OUT.rglob("*.qml"):
        text = f.read_text()
        for imp in re.findall(r'^import "([^"]+)"', text, flags=re.M):
            assert (f.parent / imp).exists(), f"{f.relative_to(OUT)} imports missing {imp}"
        code = re.sub(r"//.*", "", text)
        code = re.sub(r'"(?:\\.|[^"\\])*"', '""', code)  # labels may say "Schemes"
        for name in excluded:
            assert not re.search(rf"\b{name}\b", code), f"{f.relative_to(OUT)} still uses excluded {name}"
    n = sum(1 for _ in OUT.rglob("*.qml"))
    print(f"vendored {n} qml files into {OUT.relative_to(HERE)}")


if __name__ == "__main__":
    main()
