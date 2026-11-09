pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import "../../../../components"
import "../../../../services"
import "../../common"

// Dashboard panel, dario source only: a display name for each account in the
// proxy's pool, keyed by dario's alias and kept in the AiUsage settings (dario
// itself is not changed). An empty field shows the alias again; Reset forgets
// every name and lists dario's current aliases afresh.
ColumnLayout {
    id: root

    visible: AiUsage.useDario
    Layout.fillWidth: true
    spacing: Tokens.spacing.extraSmall / 2

    SectionHeader {
        text: Tr.tr("Account names")
    }

    ConnectedRect {
        visible: AiUsage.nameAliases.length === 0
        first: true
        Layout.fillWidth: true
        implicitHeight: hint.implicitHeight + Tokens.padding.medium * 2

        StyledText {
            id: hint

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.margins: Tokens.padding.largeIncreased
            text: AiUsage.darioError ? Tr.tr("No accounts to list: %1").arg(AiUsage.darioError) : Tr.tr("No accounts read from dario yet")
            font: Tokens.font.body.small
            color: Colours.palette.m3outline
            wrapMode: Text.Wrap
        }
    }

    Repeater {
        model: AiUsage.nameAliases

        TextFieldRow {
            required property string modelData
            required property int index
            readonly property var account: AiUsage.accounts.find(a => a.alias === modelData)

            first: index === 0
            label: modelData
            // Plan and masked email tell two seats apart; an alias dario no longer reports says so.
            subtext: account ? [account.tier, account.email].filter(Boolean).join(" · ") : Tr.tr("Not in dario's pool right now")
            value: AiUsage.settings.darioNames?.[modelData] ?? ""
            placeholderText: modelData
            onEditingFinished: v => AiUsage.setDarioName(modelData, v)
        }
    }

    RowButton {
        first: false
        last: true
        icon: "restart_alt"
        text: Tr.tr("Reset names")
        subtext: Tr.tr("Forget every custom name and list dario's current aliases again")
        disabled: !AiUsage.hasDarioNames
        onClicked: AiUsage.resetDarioNames()
    }
}
