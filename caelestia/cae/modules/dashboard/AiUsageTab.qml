pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
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

        // Claude's mark (24x24 viewBox), tinted like the other panel icons.
        Shape {
            id: logo

            // The logo fills its box edge to edge, so it sits a little under the title's line height.
            readonly property real size: Math.round(title.implicitHeight * 0.8)

            Layout.preferredWidth: size
            Layout.preferredHeight: size
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                fillColor: Colours.palette.m3primary
                strokeColor: "transparent"
                scale: Qt.size(logo.size / 24, logo.size / 24)

                PathSvg {
                    path: "m4.7144 15.9555 4.7174-2.6471.079-.2307-.079-.1275h-.2307l-.7893-.0486-2.6956-.0729-2.3375-.0971-2.2646-.1214-.5707-.1215-.5343-.7042.0546-.3522.4797-.3218.686.0608 1.5179.1032 2.2767.1578 1.6514.0972 2.4468.255h.3886l.0546-.1579-.1336-.0971-.1032-.0972L6.973 9.8356l-2.55-1.6879-1.3356-.9714-.7225-.4918-.3643-.4614-.1578-1.0078.6557-.7225.8803.0607.2246.0607.8925.686 1.9064 1.4754 2.4893 1.8336.3643.3035.1457-.1032.0182-.0728-.164-.2733-1.3539-2.4467-1.445-2.4893-.6435-1.032-.17-.6194c-.0607-.255-.1032-.4674-.1032-.7285L6.287.1335 6.6997 0l.9957.1336.419.3642.6192 1.4147 1.0018 2.2282 1.5543 3.0296.4553.8985.2429.8318.091.255h.1579v-.1457l.1275-1.706.2368-2.0947.2307-2.6957.0789-.7589.3764-.9107.7468-.4918.5828.2793.4797.686-.0668.4433-.2853 1.8517-.5586 2.9021-.3643 1.9429h.2125l.2429-.2429.9835-1.3053 1.6514-2.0643.7286-.8196.85-.9046.5464-.4311h1.0321l.759 1.1293-.34 1.1657-1.0625 1.3478-.8804 1.1414-1.2628 1.7-.7893 1.36.0729.1093.1882-.0183 2.8535-.607 1.5421-.2794 1.8396-.3157.8318.3886.091.3946-.3278.8075-1.967.4857-2.3072.4614-3.4364.8136-.0425.0304.0486.0607 1.5482.1457.6618.0364h1.621l3.0175.2247.7892.522.4736.6376-.079.4857-1.2142.6193-1.6393-.3886-3.825-.9107-1.3113-.3279h-.1822v.1093l1.0929 1.0686 2.0035 1.8092 2.5075 2.3314.1275.5768-.3218.4554-.34-.0486-2.2039-1.6575-.85-.7468-1.9246-1.621h-.1275v.17l.4432.6496 2.3436 3.5214.1214 1.0807-.17.3521-.6071.2125-.6679-.1214-1.3721-1.9246L14.38 17.959l-1.1414-1.9428-.1397.079-.674 7.2552-.3156.3703-.7286.2793-.6071-.4614-.3218-.7468.3218-1.4753.3886-1.9246.3157-1.53.2853-1.9004.17-.6314-.0121-.0425-.1397.0182-1.4328 1.9672-2.1796 2.9446-1.7243 1.8456-.4128.164-.7164-.3704.0667-.6618.4008-.5889 2.386-3.0357 1.4389-1.882.929-1.0868-.0062-.1579h-.0546l-6.3385 4.1164-1.1293.1457-.4857-.4554.0608-.7467.2307-.2429 1.9064-1.3114Z"
                }
            }
        }

        StyledText {
            id: title

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
