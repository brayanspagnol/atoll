import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Services.UPower
import Quickshell.Wayland

// The control center, under the island. Lazy: costs nothing while closed.
Scope {
    id: central
    // Outlives Ui.open by the closing animation; the window must exist to play it.
    property bool alive: false
    readonly property bool isOpen: Ui.open
    onIsOpenChanged: {
        if (isOpen) { closing.stop(); alive = true }
        else closing.restart()
    }
    Timer { id: closing; interval: 200; onTriggered: central.alive = false }
    LazyLoader {
    active: central.alive && !!Ui.screen
    PanelWindow {
        id: win
        screen: Ui.screen
        anchors { top: true; bottom: true; left: true; right: true }
        // Starts below the island so its icons switch pages instead of hitting the click-to-close area.
        margins.top: 78
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: Ui.open ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
        WlrLayershell.namespace: "atoll-central"
        color: "transparent"
        readonly property var status: ({
            som: Audio.sink?.audio ? Math.round(Audio.sink.audio.volume * 100) + "%" : Tr.t("No output"),
            rede: Net.status,
            bt: !Bluetooth.defaultAdapter?.enabled ? Tr.t("Off") : Tr.t("Connected: %1").arg(Bluetooth.defaultAdapter.devices.values.filter(d => d.connected).length),
            perf: "CPU " + Math.round(Sys.cpu) + "% · " + Math.round(Sys.temp) + " °C",
            cal: Tr.date(new Date(), "MMM d").replace(".", ""),
            avisos: Notifs.all.length ? Tr.t("Notifications: %1").arg(Notifs.all.length) : Tr.t("All caught up"),
            ajustes: Tr.t("Profile, color, idle"),
            monitor: Tr.t("Screens: %1").arg(Displays.count_on),
            sobre: "Atoll " + Ui.version,
            energia: UPower.displayDevice?.isLaptopBattery ? Tr.t("Battery %1%").arg(Math.round(UPower.displayDevice.percentage * 100)) : Tr.t("Shut down, suspend")
        })
        MouseArea { anchors.fill: parent; enabled: Ui.open; onClicked: Ui.open = false }
        Frost {
            id: panel
            anchors.horizontalCenter: parent.horizontalCenter
            y: 4
            width: Math.min(1320, win.width - 48)
            height: Math.min(1180, win.height - 4 - 112)
            focus: true
            Keys.onEscapePressed: Ui.open = false
            property bool shown: false
            Component.onCompleted: { shown = Qt.binding(() => Ui.open); forceActiveFocus() }
            opacity: shown ? 1 : 0
            scale: shown ? 1 : 0.96
            transformOrigin: Item.Top
            transform: Translate { y: panel.shown ? 0 : -14; Behavior on y { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } } }
            Behavior on opacity { NumberAnimation { duration: 170 } }
            Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
            MouseArea { anchors.fill: parent } // keeps clicks from reaching the close area behind
            RowLayout {
                anchors.fill: parent
                spacing: 0
                ColumnLayout {
                    Layout.preferredWidth: 364; Layout.maximumWidth: 364; Layout.fillHeight: true; Layout.margins: 18
                    spacing: 12
                    GridLayout {
                        Layout.fillWidth: true; columns: 2; columnSpacing: 10; rowSpacing: 10
                        Repeater {
                            model: Ui.pages
                            Rectangle {
                                id: tile
                                required property var modelData
                                readonly property bool sel: Ui.page === modelData.id
                                readonly property color fg: sel ? Theme.accentInk : Theme.ink
                                Layout.fillWidth: true; Layout.preferredWidth: 1
                                implicitHeight: 104; radius: 16
                                color: sel ? Theme.accent : tm.containsMouse ? Qt.rgba(1, 1, 1, 0.16) : Theme.raised
                                border.width: activeFocus ? 2 : 0; border.color: Theme.ink
                                activeFocusOnTab: true
                                Accessible.role: Accessible.Button
                                Accessible.name: modelData.label + ", " + (win.status[modelData.id] ?? "")
                                Keys.onSpacePressed: Ui.page = modelData.id
                                Keys.onReturnPressed: Ui.page = modelData.id
                                Behavior on color { ColorAnimation { duration: Theme.fast } }
                                ColumnLayout {
                                    anchors.fill: parent; anchors.margins: 16; spacing: 6
                                    RowLayout {
                                        Ic { name: tile.modelData.icon; size: 24; color: tile.fg }
                                        Item { Layout.fillWidth: true }
                                        Tx { text: tile.modelData.key; mono: true; size: 12; color: tile.fg; opacity: 0.7 }
                                    }
                                    Item { Layout.fillHeight: true }
                                    Tx { text: tile.modelData.label; strong: true; color: tile.fg; Layout.fillWidth: true }
                                    Tx { text: win.status[tile.modelData.id] ?? ""; size: 13; color: tile.fg; opacity: 0.86; Layout.fillWidth: true }
                                }
                                MouseArea { id: tm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Ui.page = tile.modelData.id }
                            }
                        }
                    }
                    Rowi {
                        clickable: false
                        Tx { text: Tr.t("Night light"); Layout.fillWidth: true }
                        Swt { a11y: Tr.t("Night light"); checked: Cfg.v.nightOn; onToggled: { Cfg.v.nightOn = checked; Night.apply() } }
                    }
                    Rowi {
                        clickable: false
                        Tx { text: Tr.t("Do not disturb"); Layout.fillWidth: true }
                        Swt { a11y: Tr.t("Do not disturb"); checked: Cfg.v.dnd; onToggled: Cfg.v.dnd = checked }
                    }
                    Item { Layout.fillHeight: true }
                    Tx { text: Tr.t("Esc to close"); dim: true; size: 13; Layout.leftMargin: 12 }
                }
                Rectangle { Layout.fillHeight: true; implicitWidth: 1; color: Theme.line }
                Loader {
                    id: page
                    Layout.fillWidth: true; Layout.fillHeight: true
                    Layout.topMargin: 26; Layout.bottomMargin: 26; Layout.leftMargin: 30; Layout.rightMargin: 16
                    // Follows Ui.page only through the animation, so the old screen can leave first.
                    property string shown: ""
                    Component.onCompleted: shown = Ui.page
                    property int direction: 1
                    source: ({ som: "PgSound.qml", rede: "PgNet.qml", bt: "PgBt.qml", perf: "PgPerf.qml", cal: "PgCal.qml", avisos: "PgNotif.qml", ajustes: "PgSettings.qml", energia: "PgPower.qml", monitor: "PgMonitor.qml", sobre: "PgAbout.qml" })[shown]
                    transform: Translate { id: slide }
                    Connections {
                        target: Ui
                        function onPageChanged() {
                            const order = Ui.pages.map(p => p.id)
                            page.direction = order.indexOf(Ui.page) >= order.indexOf(page.shown) ? 1 : -1
                            swap.restart()
                        }
                    }
                    SequentialAnimation {
                        id: swap
                        ParallelAnimation {
                            NumberAnimation { target: page; property: "opacity"; to: 0; duration: 90 }
                            NumberAnimation { target: slide; property: "y"; to: -18 * page.direction; duration: 90; easing.type: Easing.InCubic }
                        }
                        ScriptAction { script: { page.shown = Ui.page; slide.y = 26 * page.direction } }
                        ParallelAnimation {
                            NumberAnimation { target: page; property: "opacity"; to: 1; duration: 200 }
                            NumberAnimation { target: slide; property: "y"; to: 0; duration: 260; easing.type: Easing.OutCubic }
                        }
                    }
                }
            }
            Btn { anchors { top: parent.top; right: parent.right; margins: 18 } variant: "quiet"; icon: "x"; implicitHeight: 44; a11y: Tr.t("Close panel"); onClicked: Ui.open = false }
        }
    }
}
}
