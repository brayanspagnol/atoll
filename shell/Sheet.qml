import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Widgets

// The cards that drop from under the island: now playing, weather, focus. Volume and notifications show inside the island.
// The window keeps one size; only the panel inside animates, because resizing a layer every frame stutters.
PanelWindow {
    id: win
    required property var modelData
    screen: modelData
    readonly property bool target: (Quickshell.screens.includes(Ui.sheetScreen) ? Ui.sheetScreen : Ui.screen) === modelData
    readonly property bool mediaOpen: target && Ui.mediaOpen
    readonly property bool weatherOpen: target && Ui.weatherOpen
    readonly property bool focusOpen: target && Ui.focusOpen
    anchors.top: true
    margins.top: 78
    implicitWidth: 480
    implicitHeight: Math.min(modelData.height - 86, 1200)
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    visible: mediaOpen || weatherOpen || focusOpen || panel.height > 0.5
    // Pieces only, so the gaps around them stay clickable.
    mask: Region {
        Region { item: mediaBox }
        Region { item: focusBox }
    }
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "atoll-sheet"
    // The keyboard only while the music, weather or focus card is open.
    WlrLayershell.keyboardFocus: mediaOpen || weatherOpen || focusOpen ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    HyprlandFocusGrab {
        active: (win.mediaOpen || win.weatherOpen || win.focusOpen) && win.visible
        windows: Ui.sheetIsland ? [win, Ui.sheetIsland] : [win]
        onCleared: { Ui.mediaOpen = false; Ui.weatherOpen = false; Ui.focusOpen = false }
    }

    Item {
        id: panel
        width: parent.width
        // Below the island even while a notification makes it taller.
        y: Ui.islandDrops[win.modelData.name] ?? 0
        Behavior on y { NumberAnimation { duration: 380; easing.type: Easing.OutBack; easing.overshoot: 1.2 } }
        height: mediaBox.height + focusBox.height
        focus: true
        Keys.onEscapePressed: { Ui.mediaOpen = false; Ui.weatherOpen = false; Ui.focusOpen = false }

        ClippingRectangle {
            id: mediaBox
            width: parent.width
            height: media.height + weather.height
            radius: Theme.radius
            color: Theme.surface
            MediaCard {
                id: media
                width: parent.width
                open: win.mediaOpen
            }
            WeatherCard {
                id: weather
                y: media.height
                width: parent.width
                maxHeight: win.height - panel.y
                open: win.weatherOpen
            }
        }

        ClippingRectangle {
            id: focusBox
            y: mediaBox.height
            width: parent.width
            height: focusCard.height
            radius: Theme.radius
            color: Theme.surface
            FocusCard {
                id: focusCard
                width: parent.width
                open: win.focusOpen
            }
        }
    }
}
