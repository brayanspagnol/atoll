import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

// On every screen: the big number of "Identify", and the question after applying a layout.
// Its own window, because the control center may have been on a screen that just went away.
Scope {
    id: overlay
    required property var modelData
    LazyLoader {
        active: Displays.identifying || Displays.confirming
        PanelWindow {
            screen: overlay.modelData
            anchors { top: true; bottom: true; left: true; right: true }
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "atoll-central"
            WlrLayershell.keyboardFocus: Displays.confirming ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
            color: Displays.confirming ? Qt.rgba(6 / 255, 10 / 255, 16 / 255, 0.6) : "transparent"
            mask: Region { item: Displays.confirming ? fullArea : null }
            Item { id: fullArea; anchors.fill: parent }

            Frost {
                visible: Displays.identifying && !Displays.confirming
                anchors.centerIn: parent
                width: 260; height: 260; radius: 40
                Tx {
                    anchors.centerIn: parent; size: 150; strong: true
                    text: Displays.monitors.findIndex(m => m.name === overlay.modelData.name) + 1
                }
            }

            Frost {
                visible: Displays.confirming
                anchors.centerIn: parent
                width: 480; height: box.implicitHeight + 52
                focus: true
                Keys.onEscapePressed: Displays.undo()
                Keys.onReturnPressed: Displays.keep()
                ColumnLayout {
                    id: box
                    anchors { left: parent.left; right: parent.right; top: parent.top; margins: 26 }
                    spacing: 14
                    Tx { text: Tr.t("Keep these settings?"); size: 22; strong: true; Layout.fillWidth: true; Accessible.role: Accessible.AlertMessage; Accessible.name: text }
                    Tx { text: Tr.t("Going back to the previous ones in %1 s, in case a screen went dark.").arg(Displays.count); dim: true; wrapMode: Text.Wrap; Layout.fillWidth: true }
                    RowLayout {
                        Layout.alignment: Qt.AlignRight
                        spacing: 10
                        Btn { text: Tr.t("Go back now"); implicitHeight: 44; onClicked: Displays.undo() }
                        Btn { text: Tr.t("Keep"); variant: "solid"; implicitHeight: 44; onClicked: Displays.keep() }
                    }
                }
            }
        }
    }
}
