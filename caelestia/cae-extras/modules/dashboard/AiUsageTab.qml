pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import "../../components"
import "../../components/controls"
import "../../services"
import "../../utils"

// Dashboard tab: Claude Code's 5-hour session and weekly plan limits, plus tokens
// per day for the last 7 days. Data and settings come from the AiUsage service.
ColumnLayout {
    id: root

    readonly property var usage: AiUsage.claude
    readonly property var days: usage?._recent_days ?? []
    readonly property real weekTokens: days.reduce((sum, d) => sum + (d.tokens || 0), 0)
    readonly property bool anyCard: AiUsage.settings.showSession || AiUsage.settings.showWeekly || AiUsage.settings.showDaily

    spacing: Tokens.spacing.medium

    RowLayout {
        Layout.fillWidth: true
        spacing: Tokens.spacing.small

        MaterialIcon {
            text: "smart_toy"
            fill: 1
            color: Colours.palette.m3primary
            fontStyle: Tokens.font.icon.builders.medium.weight(Font.DemiBold).build()
        }

        StyledText {
            text: Tr.tr("Claude Code")
            font: Tokens.font.title.medium
        }

        Item {
            Layout.fillWidth: true
        }

        StyledText {
            text: !root.usage ? Tr.tr("No data yet") : root.usage.updated_at ? Tr.tr("Updated %1").arg(root.usage.updated_at.slice(0, 5)) + (AiUsage.claudeStale ? ` · ${Tr.tr("last refresh failed")}` : "") : ""
            font: Tokens.font.body.small
            color: AiUsage.claudeStale ? Colours.palette.m3error : Colours.palette.m3onSurfaceVariant
        }

        IconButton {
            icon: "refresh"
            type: IconButton.Text
            isRound: true
            onClicked: AiUsage.refresh()
        }
    }

    RowLayout {
        spacing: Tokens.spacing.medium

        LimitCard {
            visible: AiUsage.settings.showSession
            title: Tr.tr("5-hour session")
            icon: "timer"
            value: AiUsage.pct(root.usage?.["5h-utilization"])
            resetTs: parseInt(root.usage?.["5h-reset"]) || 0
        }

        LimitCard {
            visible: AiUsage.settings.showWeekly
            title: Tr.tr("Weekly limit")
            icon: "date_range"
            value: AiUsage.pct(root.usage?.["7d-utilization"])
            resetTs: parseInt(root.usage?.["7d-reset"]) || 0
        }

        StyledRect {
            id: daily

            property int hovered: -1
            readonly property real maxTokens: Math.max(1, ...root.days.map(d => d.tokens || 0))

            visible: AiUsage.settings.showDaily
            Layout.fillHeight: true
            color: Colours.tPalette.m3surfaceContainer
            radius: Tokens.rounding.medium
            implicitWidth: dailyLayout.implicitWidth + Tokens.padding.extraLargeIncreased * 2
            implicitHeight: dailyLayout.implicitHeight + Tokens.padding.large * 2

            ColumnLayout {
                id: dailyLayout

                anchors.centerIn: parent
                spacing: Tokens.spacing.small

                StyledText {
                    text: Tr.tr("Last 7 days (UTC)")
                    font: Tokens.font.title.medium
                }

                // Hovering a day swaps the week total for that day's detail.
                StyledText {
                    readonly property var day: root.days[daily.hovered]

                    text: day ? `${Qt.formatDate(new Date(`${day.date}T12:00:00`), "ddd d MMM")} · ${Tr.tr("%1 tokens").arg(AiUsage.formatTokens(day.tokens || 0))}` : Tr.tr("%1 tokens this week").arg(AiUsage.formatTokens(root.weekTokens))
                    font: Tokens.font.body.small
                    color: Colours.palette.m3onSurfaceVariant
                }

                RowLayout {
                    Layout.topMargin: Tokens.spacing.small
                    spacing: Tokens.spacing.small

                    Repeater {
                        model: root.days

                        ColumnLayout {
                            id: dayCol

                            required property var modelData
                            required property int index
                            readonly property bool highlighted: daily.hovered === index || (daily.hovered < 0 && index === root.days.length - 1)

                            spacing: Tokens.spacing.extraSmall

                            Item {
                                implicitWidth: 22
                                implicitHeight: 110

                                StyledRect {
                                    anchors.bottom: parent.bottom
                                    width: parent.width
                                    height: Math.max(4, parent.height * (dayCol.modelData.tokens || 0) / daily.maxTokens)
                                    radius: Tokens.rounding.small
                                    color: dayCol.highlighted ? Colours.palette.m3primary : Colours.palette.m3secondaryContainer

                                    Behavior on height {
                                        Anim {}
                                    }
                                }
                            }

                            StyledText {
                                Layout.alignment: Qt.AlignHCenter
                                text: Qt.formatDate(new Date(`${dayCol.modelData.date}T12:00:00`), "ddd").slice(0, 2)
                                font: Tokens.font.body.small
                                color: dayCol.highlighted ? Colours.palette.m3primary : Colours.palette.m3onSurfaceVariant
                            }

                            HoverHandler {
                                onHoveredChanged: {
                                    if (hovered)
                                        daily.hovered = dayCol.index;
                                    else if (daily.hovered === dayCol.index)
                                        daily.hovered = -1;
                                }
                            }
                        }
                    }
                }
            }
        }

        StyledText {
            visible: !root.anyCard
            text: Tr.tr("Enable AI usage widgets in the dashboard settings")
            font: Tokens.font.body.medium
            color: Colours.palette.m3onSurfaceVariant
        }
    }

    // A plan limit as a gauge: red at the warning threshold, reset countdown below
    // (the exact reset time while hovered).
    component LimitCard: StyledRect {
        id: card

        required property string title
        required property string icon
        required property real value
        required property int resetTs
        readonly property color accent: Math.round(value * 100) >= AiUsage.settings.warnThreshold ? Colours.palette.m3error : Colours.palette.m3primary

        Layout.fillHeight: true
        color: Colours.tPalette.m3surfaceContainer
        radius: Tokens.rounding.medium
        implicitWidth: cardLayout.implicitWidth + Tokens.padding.extraLargeIncreased * 2
        implicitHeight: cardLayout.implicitHeight + Tokens.padding.large * 2

        HoverHandler {
            id: cardHover
        }

        ColumnLayout {
            id: cardLayout

            anchors.centerIn: parent
            spacing: Tokens.spacing.extraSmall

            RowLayout {
                Layout.leftMargin: -Tokens.padding.extraSmall
                spacing: Tokens.spacing.small

                MaterialIcon {
                    text: card.icon
                    fill: 1
                    color: card.accent
                    fontStyle: Tokens.font.icon.builders.medium.weight(Font.DemiBold).build()
                }

                StyledText {
                    text: card.title
                    font: Tokens.font.title.medium
                }
            }

            CircularProgress {
                Layout.topMargin: Tokens.spacing.large
                Layout.alignment: Qt.AlignHCenter
                implicitSize: usedColumn.implicitHeight + thickness + Tokens.padding.largeIncreased * 2
                startAngle: -225
                sweepAngle: 270

                fgColour: card.accent
                value: card.value

                Behavior on clampedVal {
                    Anim {}
                }

                ColumnLayout {
                    id: usedColumn

                    anchors.centerIn: parent
                    anchors.verticalCenterOffset: Tokens.padding.extraSmall
                    spacing: 0

                    StyledText {
                        Layout.alignment: Qt.AlignHCenter
                        text: Strings.percentOne(card.value)
                        font: Tokens.font.title.builders.large.width(90).build()
                        color: card.accent
                    }

                    StyledText {
                        Layout.alignment: Qt.AlignHCenter
                        text: Tr.trCtx("Used", "plan limit used")
                        font: Tokens.font.body.small
                        color: Colours.palette.m3onSurfaceVariant
                    }
                }
            }

            StyledText {
                readonly property string countdown: AiUsage.untilReset(card.resetTs)

                Layout.alignment: Qt.AlignHCenter
                visible: AiUsage.settings.showCountdown && card.resetTs > 0
                text: cardHover.hovered ? Tr.tr("Resets %1").arg(Qt.formatDateTime(new Date(card.resetTs * 1000), "ddd hh:mm")) : countdown ? Tr.tr("Resets in %1").arg(countdown) : Tr.tr("Reset due")
                font: Tokens.font.body.medium
            }
        }
    }
}
