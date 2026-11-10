import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland

// The assistant, grown out of the island. Super+A or the island's mascot.
// Built once and kept hidden: creating the window and its panel on the click made the opening stutter.
Scope {
    id: ask
    // Outlives Ui.askOpen by the closing animation; the window must exist to play it.
    property bool alive: false
    readonly property bool isOpen: Ui.askOpen
    onIsOpenChanged: {
        if (isOpen) { closing.stop(); alive = true }
        else closing.restart()
    }
    Timer { id: closing; interval: 480; onTriggered: ask.alive = false } // a little longer than AskPanel's leave

    PanelWindow {
        id: win
        visible: ask.alive && !!Ui.screen
        screen: Quickshell.screens.includes(Ui.askScreen) ? Ui.askScreen : Ui.screen
        anchors { top: true; bottom: true; left: true; right: true }
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: Ui.askOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        WlrLayershell.namespace: "atoll-ask"
        color: "transparent"
        // The bar and the conversation only, so the rest of the screen stays clickable.
        mask: Region {
            Region { item: panel.barItem }
            Region { item: panel.bodyItem }
        }
        // A click anywhere else closes it.
        HyprlandFocusGrab {
            active: Ui.askOpen && win.visible
            windows: [win]
            onCleared: Ui.askOpen = false
        }
        AskPanel {
            id: panel
            anchors.fill: parent
            Component.onCompleted: shown = Qt.binding(() => Ui.askOpen)
        }
    }
}
