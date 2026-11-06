import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Widgets

// Floating pieces under the island: volume, now playing, new notifications.
// The window keeps one size; only the panel inside animates, because resizing a layer every frame stutters.
PanelWindow {
    id: win
    required property var modelData
    screen: modelData
    readonly property bool target: (Quickshell.screens.includes(Ui.sheetScreen) ? Ui.sheetScreen : Ui.screen) === modelData
    readonly property bool mediaOpen: target && Ui.mediaOpen
    readonly property bool weatherOpen: target && Ui.weatherOpen
    readonly property bool hasToasts: target && Notifs.toasts.length > 0
    readonly property bool volumeOn: target && Osd.shown
    anchors.top: true
    margins.top: 78
    implicitWidth: 480
    implicitHeight: Math.min(modelData.height - 86, 1200)
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    visible: mediaOpen || weatherOpen || hasToasts || volumeOn || panel.height > 0.5
    // Pieces only, so the gaps around them stay clickable.
    mask: Region {
        Region { item: capsule; }
        Region { item: mediaBox }
        Region { item: list }
    }
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "atoll-sheet"
    // Never take the keyboard for a notification: only while the music or weather card is open.
    WlrLayershell.keyboardFocus: mediaOpen || weatherOpen ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    HyprlandFocusGrab {
        active: (win.mediaOpen || win.weatherOpen) && win.visible
        windows: Ui.sheetIsland ? [win, Ui.sheetIsland] : [win]
        onCleared: { Ui.mediaOpen = false; Ui.weatherOpen = false }
    }

    Item {
        id: panel
        width: parent.width
        height: volume.height + mediaBox.height + (mediaBox.height > 0 && list.height > 0 ? gap : 0) + list.height
        readonly property int gap: 8
        focus: true
        Keys.onEscapePressed: { Ui.mediaOpen = false; Ui.weatherOpen = false }

        Item {
            id: volume
            width: parent.width
            height: win.volumeOn ? 60 : 0
            Behavior on height { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
            Frost {
                id: capsule
                readonly property bool on: win.volumeOn
                readonly property real level: Osd.muted ? 0 : Math.min(1, Osd.volume)
                anchors.horizontalCenter: parent.horizontalCenter
                y: on ? 0 : -16
                width: 300; height: 52; radius: 26
                opacity: on ? 1 : 0
                scale: on ? 1 : 0.88
                transformOrigin: Item.Top
                Behavior on y { NumberAnimation { duration: 280; easing.type: Easing.OutBack; easing.overshoot: 1.2 } }
                Behavior on scale { NumberAnimation { duration: 280; easing.type: Easing.OutBack; easing.overshoot: 1.2 } }
                Behavior on opacity { NumberAnimation { duration: 160 } }
                RowLayout {
                    anchors.fill: parent; anchors.leftMargin: 16; anchors.rightMargin: 18
                    spacing: 12
                    Ic { name: Audio.icon; size: 22; color: Osd.muted ? Theme.muted : Theme.ink }
                    Item {
                        Layout.fillWidth: true; implicitHeight: 6
                        Rectangle { anchors.fill: parent; radius: 3; color: Theme.lineStrong }
                        Rectangle {
                            height: 6; radius: 3
                            width: Math.max(6, parent.width * capsule.level)
                            visible: capsule.level > 0
                            color: Osd.volume > 1 ? Theme.warn : Theme.ink
                            Behavior on width { NumberAnimation { duration: 90 } }
                        }
                    }
                    Tx {
                        text: Osd.muted ? Tr.t("Muted") : Math.round(Osd.volume * 100) + "%"
                        strong: true; font.features: { "tnum": 1 }
                        horizontalAlignment: Text.AlignRight
                        Layout.preferredWidth: 46
                        color: Osd.volume > 1 && !Osd.muted ? Theme.warn : Theme.ink
                    }
                }
            }
        }

        ClippingRectangle {
            id: mediaBox
            y: volume.height
            width: parent.width
            height: media.height + weather.height
            radius: Theme.radius
            color: Theme.surface
            border.width: 1
            border.color: Theme.lineStrong
            contentUnderBorder: true
            MediaCard {
                id: media
                width: parent.width
                open: win.mediaOpen
            }
            WeatherCard {
                id: weather
                y: media.height
                width: parent.width
                maxHeight: win.height - volume.height
                open: win.weatherOpen
            }
        }

        ListView {
            id: list
            y: volume.height + mediaBox.height + (mediaBox.height > 0 ? panel.gap : 0)
            anchors.horizontalCenter: parent.horizontalCenter
            width: 420
            height: win.target ? contentHeight : 0
            Behavior on height { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
            interactive: false
            spacing: 8
            model: ScriptModel { values: Notifs.toasts.slice(0, 4) }
            delegate: Toast { width: ListView.view.width }
            // New ones drop from under the island; old ones lift back toward it.
            add: Transition { NumberAnimation { property: "y"; from: -70; duration: 340; easing.type: Easing.OutBack; easing.overshoot: 1.1 } }
            remove: Transition {
                ParallelAnimation {
                    NumberAnimation { property: "y"; to: -50; duration: 220; easing.type: Easing.InCubic }
                    NumberAnimation { property: "opacity"; to: 0; duration: 180 }
                    NumberAnimation { property: "scale"; to: 0.92; duration: 220 }
                }
            }
            displaced: Transition { NumberAnimation { properties: "y"; duration: 280; easing.type: Easing.OutCubic } }
        }
    }
}
