pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import "../../../../components/controls"
import "../../../../modules/nexus/common"
import "../../../../services"
PageBase {
    id: root

    title: Tr.tr("Dashboard")
    isSubPage: true

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        // General
        SectionHeader {
            first: true
            text: Tr.tr("General")
        }

        ToggleRow {
            first: true
            text: Tr.trCtx("Enabled", "toggle label")
            checked: Config.dashboard.enabled
            onToggled: GlobalConfig.dashboard.enabled = checked
        }

        ToggleRow {
            text: Tr.tr("Show on hover")
            subtext: Tr.tr("Reveal when the cursor reaches the screen edge")
            checked: Config.dashboard.showOnHover
            onToggled: GlobalConfig.dashboard.showOnHover = checked
        }

        ToggleRow {
            text: Tr.tr("Show clock seconds")
            subtext: Tr.tr("Display seconds for the clock in the main panel")
            checked: Config.dashboard.showClockSeconds
            onToggled: GlobalConfig.dashboard.showClockSeconds = checked
        }

        ToggleRow {
            last: true
            text: Tr.tr("Show full name")
            subtext: Tr.tr("Beside your photo, show your name instead of the window manager")
            checked: AiUsage.settings.showFullName
            onToggled: AiUsage.settings.showFullName = checked
        }

        // Tabs
        SectionHeader {
            text: Tr.tr("Tabs")
        }

        ToggleRow {
            first: true
            text: Tr.tr("Dashboard")
            checked: Config.dashboard.showDashboard
            onToggled: GlobalConfig.dashboard.showDashboard = checked
        }

        ToggleRow {
            text: Tr.tr("Media")
            checked: Config.dashboard.showMedia
            onToggled: GlobalConfig.dashboard.showMedia = checked
        }

        ToggleRow {
            text: Tr.tr("Performance")
            checked: Config.dashboard.showPerformance
            onToggled: GlobalConfig.dashboard.showPerformance = checked
        }

        ToggleRow {
            text: Tr.tr("Weather")
            checked: Config.dashboard.showWeather
            onToggled: GlobalConfig.dashboard.showWeather = checked
        }

        ToggleRow {
            last: true
            text: Tr.tr("AI usage")
            subtext: Tr.tr("Claude plan limits and daily tokens, locally or through a proxy")
            checked: AiUsage.settings.showTab
            onToggled: AiUsage.settings.showTab = checked
        }

        // Performance widgets
        SectionHeader {
            text: Tr.tr("Performance widgets")
        }

        ToggleRow {
            first: true
            text: Tr.tr("Battery")
            checked: Config.dashboard.performance.showBattery
            onToggled: GlobalConfig.dashboard.performance.showBattery = checked
        }

        ToggleRow {
            text: Tr.tr("GPU")
            checked: Config.dashboard.performance.showGpu
            onToggled: GlobalConfig.dashboard.performance.showGpu = checked
        }

        ToggleRow {
            text: Tr.tr("CPU")
            checked: Config.dashboard.performance.showCpu
            onToggled: GlobalConfig.dashboard.performance.showCpu = checked
        }

        ToggleRow {
            text: Tr.tr("Memory")
            checked: Config.dashboard.performance.showMemory
            onToggled: GlobalConfig.dashboard.performance.showMemory = checked
        }

        ToggleRow {
            text: Tr.tr("Storage")
            checked: Config.dashboard.performance.showStorage
            onToggled: GlobalConfig.dashboard.performance.showStorage = checked
        }

        ToggleRow {
            last: true
            text: Tr.tr("Network")
            checked: Config.dashboard.performance.showNetwork
            onToggled: GlobalConfig.dashboard.performance.showNetwork = checked
        }

        // AI usage
        SectionHeader {
            text: Tr.tr("AI usage")
        }

        SelectRow {
            first: true
            label: Tr.tr("Source")
            subtext: AiUsage.useDario ? Tr.tr("Every account in the proxy's pool") : Tr.tr("This machine's Claude Code login")
            menuItems: [localSource, darioSource]
            active: AiUsage.useDario ? darioSource : localSource
            onSelected: item => AiUsage.settings.source = item.value

            MenuItem {
                id: localSource

                text: Tr.tr("Claude Code")
                icon: "computer"
                value: "local"
            }

            MenuItem {
                id: darioSource

                text: Tr.tr("Proxy")
                icon: "hub"
                value: "dario"
            }
        }

        TextFieldRow {
            visible: AiUsage.useDario
            label: Tr.tr("Proxy URL")
            subtext: AiUsage.darioError ? Tr.tr("Last read: %1").arg(AiUsage.darioError) : Tr.tr("Where the proxy listens")
            value: AiUsage.settings.darioUrl
            placeholderText: "http://localhost:3456"
            onEditingFinished: v => AiUsage.settings.darioUrl = v.trim()
        }

        TextFieldRow {
            visible: AiUsage.useDario
            label: Tr.tr("Token")
            subtext: Tr.tr("The proxy's DARIO_API_KEY; empty for an unkeyed proxy")
            value: AiUsage.settings.darioToken
            placeholderText: Tr.tr("API key")
            field.echoMode: TextInput.Password
            onEditingFinished: v => AiUsage.settings.darioToken = v.trim()
        }

        ToggleRow {
            visible: AiUsage.useDario
            text: Tr.tr("Pool activity")
            subtext: Tr.tr("Last hour's requests, cache hits, burn rate and API value")
            checked: AiUsage.settings.showPoolStats
            onToggled: AiUsage.settings.showPoolStats = checked
        }

        ToggleRow {
            visible: AiUsage.useDario
            text: Tr.tr("Accounts")
            subtext: Tr.tr("Each account's 5-hour and weekly use; hover for its email")
            checked: AiUsage.settings.showAccounts
            onToggled: AiUsage.settings.showAccounts = checked
        }

        SelectRow {
            visible: AiUsage.useDario && AiUsage.settings.showAccounts
            label: Tr.tr("Sort accounts")
            subtext: AiUsage.settings.accountSort === "headroom" ? Tr.tr("Most room left first, by the higher of 5-hour and weekly use") : Tr.tr("A to Z by the name shown")
            menuItems: [nameSort, headroomSort]
            active: AiUsage.settings.accountSort === "headroom" ? headroomSort : nameSort
            onSelected: item => AiUsage.settings.accountSort = item.value

            MenuItem {
                id: nameSort

                text: Tr.tr("Name")
                icon: "sort_by_alpha"
                value: "name"
            }

            MenuItem {
                id: headroomSort

                text: Tr.tr("Most headroom")
                icon: "battery_full"
                value: "headroom"
            }
        }

        ToggleRow {
            text: Tr.tr("5-hour session")
            subtext: Tr.tr("Usage of the rolling 5-hour limit")
            checked: AiUsage.settings.showSession
            onToggled: AiUsage.settings.showSession = checked
        }

        ToggleRow {
            text: Tr.tr("Weekly limit")
            subtext: Tr.tr("Usage of the 7-day plan limit")
            checked: AiUsage.settings.showWeekly
            onToggled: AiUsage.settings.showWeekly = checked
        }

        ToggleRow {
            text: Tr.tr("Last 7 days")
            subtext: Tr.tr("Tokens spent each day; hover a day for its total")
            checked: AiUsage.settings.showDaily
            onToggled: AiUsage.settings.showDaily = checked
        }

        ToggleRow {
            text: Tr.tr("Reset countdown")
            subtext: Tr.tr("Time until each limit resets; hover for the exact time")
            checked: AiUsage.settings.showCountdown
            onToggled: AiUsage.settings.showCountdown = checked
        }

        ToggleRow {
            text: Tr.tr("Dashboard tile")
            subtext: Tr.tr("5-hour and weekly usage as rings under the media player")
            checked: AiUsage.settings.showTile
            onToggled: AiUsage.settings.showTile = checked
        }

        StepperRow {
            last: true
            label: Tr.tr("Warning threshold")
            subtext: Tr.tr("Percent used at which a limit turns red")
            value: AiUsage.settings.warnThreshold
            from: 10
            to: 100
            stepSize: 5
            onMoved: v => AiUsage.settings.warnThreshold = v
        }

        DarioAccountNames {}

        // Behaviour
        SectionHeader {
            text: Tr.tr("Behaviour")
        }

        StepperRow {
            first: true
            last: true
            label: Tr.tr("Drag threshold")
            subtext: Tr.tr("Pixels dragged before the dashboard opens")
            value: Config.dashboard.dragThreshold
            from: 0
            to: 200
            stepSize: 5
            onMoved: v => GlobalConfig.dashboard.dragThreshold = v
        }
    }
}
