import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Notifications
import Quickshell.Widgets

// A new notification, inside the island, which grows down into it. One at a time: the island keeps the rest waiting.
Item {
    id: c
    required property var modelData
    property int waiting: 0 // shown as +N
    property bool paused: false // the pointer is on the island
    readonly property bool critical: modelData.urgency === NotificationUrgency.Critical
    readonly property string iconSource: Notifs.iconOf(modelData)
    // Two buttons at most: its own actions first, then Dismiss.
    readonly property var buttons: {
        const own = (modelData.actions ?? []).slice(0, 2)
        return own.length < 2 ? own.concat([{ text: Tr.t("Dismiss"), invoke: () => c.modelData.dismiss(), quiet: true }]) : own
    }
    implicitWidth: 440
    implicitHeight: lay.implicitHeight + 30
    Accessible.role: Accessible.AlertMessage
    Accessible.name: modelData.summary + ". " + modelData.body

    Timer {
        // Critical stays until dismissed; -1/0 means "server decides": 5 s. Under the pointer it waits, and starts over after.
        running: !c.critical && !c.paused && !c.modelData.countdown
        interval: c.modelData.expireTimeout > 0 ? c.modelData.expireTimeout : 5000
        onTriggered: Notifs.drop(c.modelData)
    }
    // The shell's own toasts with a countdown (an undo) show the time left as a bar, which pauses under the pointer.
    Rectangle {
        visible: !!c.modelData.countdown
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom; leftMargin: 24; rightMargin: 24; bottomMargin: 7 }
        height: 3; radius: 1.5
        color: Theme.line
        Rectangle {
            property real share: 1 // "left" would clash with the anchor line of the same name
            width: parent.width * share; height: parent.height; radius: 1.5
            color: Theme.accent
            NumberAnimation on share {
                running: !!c.modelData.countdown
                paused: running && c.paused
                from: 1; to: 0
                duration: Math.max(1, c.modelData.expireTimeout) // a real notification may say -1; this bar only runs for countdowns
                onFinished: Notifs.drop(c.modelData)
            }
        }
    }
    // A click on it puts it away; the history keeps it.
    TapHandler { onTapped: Notifs.drop(c.modelData) }

    RowLayout {
        id: lay
        anchors { left: parent.left; right: parent.right; top: parent.top; leftMargin: 18; rightMargin: 18; topMargin: 15 }
        spacing: 12
        ClippingRectangle {
            Layout.alignment: Qt.AlignTop
            implicitWidth: 40; implicitHeight: 40; radius: 12
            color: Theme.raised
            IconImage { anchors.centerIn: parent; implicitSize: c.iconSource.startsWith("image://icon") || c.iconSource.endsWith(".svg") ? 28 : 40; source: c.iconSource; visible: !!c.iconSource }
            Ic { anchors.centerIn: parent; visible: !!c.modelData.icon; name: c.modelData.icon ?? ""; size: 22; color: Theme.accent } // the shell's own cards
            Tx { anchors.centerIn: parent; visible: !c.iconSource && !c.modelData.icon; text: (c.modelData.appName || "?").charAt(0).toUpperCase(); size: 18; strong: true }
        }
        ColumnLayout {
            Layout.fillWidth: true; spacing: 1
            RowLayout {
                Layout.fillWidth: true; spacing: 6
                Tx { text: c.modelData.appName; dim: true; size: 12; Layout.fillWidth: true }
                Tx { visible: c.critical; text: Tr.t("important"); size: 12; color: Theme.danger }
                Rectangle {
                    visible: c.waiting > 0
                    implicitWidth: more.implicitWidth + 14; implicitHeight: 20; radius: 10
                    color: Theme.raised
                    Accessible.role: Accessible.StaticText
                    Accessible.name: Tr.t("%1 waiting").arg(c.waiting)
                    Tx { id: more; anchors.centerIn: parent; text: "+" + c.waiting; size: 12; strong: true }
                }
            }
            Tx { text: c.modelData.summary; strong: true; Layout.fillWidth: true }
            Tx { text: c.modelData.body.replace(/\s+/g, " "); visible: !!text; dim: true; maximumLineCount: 1; Layout.fillWidth: true }
            RowLayout {
                Layout.topMargin: 8; spacing: 6
                Repeater {
                    model: c.buttons
                    Btn {
                        required property var modelData
                        required property int index
                        text: modelData.text
                        variant: index === 0 && !modelData.quiet ? "solid" : "ghost"
                        implicitHeight: 32
                        onClicked: modelData.invoke()
                    }
                }
            }
        }
    }
}
