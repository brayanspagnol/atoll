import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Notifications
import Quickshell.Widgets

// Row in the Avisos history.
Rectangle {
    id: c
    required property var modelData
    readonly property bool critical: modelData.urgency === NotificationUrgency.Critical
    implicitHeight: lay.implicitHeight + 24
    radius: 18
    color: Theme.raised
    border.width: critical ? 1 : 0
    border.color: Theme.danger
    Accessible.role: Accessible.AlertMessage
    Accessible.name: modelData.summary + ". " + modelData.body
    RowLayout {
        id: lay
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12 }
        spacing: 12
        IconImage {
            Layout.alignment: Qt.AlignTop
            visible: source != ""
            implicitSize: 36
            source: Notifs.iconOf(c.modelData)
        }
        ColumnLayout {
            Layout.fillWidth: true; spacing: 1
            Tx { text: c.modelData.appName; dim: true; size: 12; Layout.fillWidth: true }
            Tx { text: c.modelData.summary; strong: true; Layout.fillWidth: true }
            Tx { text: c.modelData.body; visible: !!text; dim: true; wrapMode: Text.Wrap; maximumLineCount: 4; Layout.fillWidth: true }
            RowLayout {
                visible: c.modelData.actions.length > 0; Layout.topMargin: 6; spacing: 6
                Repeater {
                    model: c.modelData.actions
                    Btn { required property var modelData; text: modelData.text; onClicked: modelData.invoke() }
                }
            }
        }
        Btn { Layout.alignment: Qt.AlignTop; text: Tr.t("Dismiss"); onClicked: c.modelData.dismiss() }
    }
}
