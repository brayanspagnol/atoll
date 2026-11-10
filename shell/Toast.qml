import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Notifications
import Quickshell.Widgets

// New notification: a glass card of its own under the island.
Frost {
    id: c
    required property var modelData
    readonly property bool critical: modelData.urgency === NotificationUrgency.Critical
    readonly property string iconSource: Notifs.iconOf(modelData)
    implicitHeight: lay.implicitHeight + 28
    radius: 24
    border.width: critical ? 1 : 0
    border.color: Theme.danger
    transformOrigin: Item.Top
    // Here, not in the list's add transition: a second arrival interrupts that one and would strand the card.
    NumberAnimation on opacity { from: 0; to: 1; duration: 180 }
    NumberAnimation on scale { from: 0.9; to: 1; duration: 340; easing.type: Easing.OutBack; easing.overshoot: 1.3 }
    Accessible.role: Accessible.AlertMessage
    Accessible.name: modelData.summary + ". " + modelData.body

    HoverHandler { id: hover }
    Timer {
        // Critical stays until dismissed; -1/0 means "server decides": 6 s.
        running: !c.critical && !hover.hovered && !c.modelData.countdown
        interval: c.modelData.expireTimeout > 0 ? c.modelData.expireTimeout : 6000
        onTriggered: Notifs.drop(c.modelData)
    }
    // The shell's own toasts with a countdown (an undo) show the time left as a bar, which pauses under the pointer.
    Rectangle {
        visible: !!c.modelData.countdown
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom; leftMargin: 18; rightMargin: 18; bottomMargin: 6 }
        height: 3; radius: 1.5
        color: Theme.line
        Rectangle {
            property real share: 1 // "left" would clash with the anchor line of the same name
            width: parent.width * share; height: parent.height; radius: 1.5
            color: Theme.accent
            NumberAnimation on share {
                running: !!c.modelData.countdown
                paused: running && hover.hovered
                from: 1; to: 0
                duration: Math.max(1, c.modelData.expireTimeout) // a real notification may say -1; this bar only runs for countdowns
                onFinished: Notifs.drop(c.modelData)
            }
        }
    }
    TapHandler { onTapped: Notifs.drop(c.modelData) }

    RowLayout {
        id: lay
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 14 }
        spacing: 12
        ClippingRectangle {
            Layout.alignment: Qt.AlignTop
            implicitWidth: 44; implicitHeight: 44; radius: 12
            color: Theme.raised
            IconImage { anchors.centerIn: parent; implicitSize: c.iconSource.startsWith("image://icon") || c.iconSource.endsWith(".svg") ? 30 : 44; source: c.iconSource; visible: !!c.iconSource }
            Ic { anchors.centerIn: parent; visible: !!c.modelData.icon; name: c.modelData.icon ?? ""; size: 24; color: Theme.accent } // the shell's own cards
            Tx { anchors.centerIn: parent; visible: !c.iconSource && !c.modelData.icon; text: (c.modelData.appName || "?").charAt(0).toUpperCase(); size: 20; strong: true }
        }
        ColumnLayout {
            Layout.fillWidth: true; spacing: 1
            RowLayout {
                Layout.fillWidth: true; spacing: 6
                Tx { text: c.modelData.appName; dim: true; size: 12; Layout.fillWidth: true }
                Tx { text: c.critical ? Tr.t("important") : Tr.t("now"); size: 12; color: c.critical ? Theme.danger : Theme.muted; Layout.rightMargin: closeBtn.visible ? 26 : 0 }
            }
            Tx { text: c.modelData.summary; strong: true; Layout.fillWidth: true }
            Tx { text: c.modelData.body; visible: !!text; dim: true; wrapMode: Text.Wrap; maximumLineCount: 3; Layout.fillWidth: true }
            RowLayout {
                visible: c.modelData.actions.length > 0; Layout.topMargin: 8; spacing: 6
                Repeater {
                    model: c.modelData.actions
                    Btn { required property var modelData; text: modelData.text; onClicked: modelData.invoke() }
                }
            }
        }
    }
    Btn {
        id: closeBtn
        anchors { top: parent.top; right: parent.right; margins: 8 }
        visible: hover.hovered || c.critical
        variant: "quiet"; icon: "x"; iconSize: 16; implicitWidth: 30; implicitHeight: 30
        a11y: Tr.t("Dismiss")
        onClicked: c.modelData.dismiss()
    }
}
