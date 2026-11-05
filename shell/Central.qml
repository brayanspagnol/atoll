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
            som: Audio.sink?.audio ? Math.round(Audio.sink.audio.volume * 100) + "%" : "Sem saída",
            rede: Net.status,
            bt: !Bluetooth.defaultAdapter?.enabled ? "Desligado" : (Bluetooth.defaultAdapter.devices.values.filter(d => d.connected).length + " conectado(s)"),
            perf: "CPU " + Math.round(Sys.cpu) + "% · " + Math.round(Sys.temp) + " °C",
            cal: Qt.locale("pt_BR").toString(new Date(), "d 'de' MMM").replace(".", ""),
            avisos: Notifs.all.length ? Notifs.all.length + " aviso(s)" : "Tudo em dia",
            ajustes: "Cor, tela, ociosidade",
            energia: UPower.displayDevice?.isLaptopBattery ? "Bateria " + Math.round(UPower.displayDevice.percentage * 100) + "%" : "Desligar, suspender"
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
                        Tx { text: "Luz noturna"; Layout.fillWidth: true }
                        Swt { a11y: "Luz noturna"; checked: Cfg.v.nightOn; onToggled: { Cfg.v.nightOn = checked; Night.apply() } }
                    }
                    Rowi {
                        clickable: false
                        Tx { text: "Não perturbe"; Layout.fillWidth: true }
                        Swt { a11y: "Não perturbe"; checked: Cfg.v.dnd; onToggled: Cfg.v.dnd = checked }
                    }
                    Item { Layout.fillHeight: true }
                    Tx { text: "Esc para fechar"; dim: true; size: 13; Layout.leftMargin: 12 }
                }
                Rectangle { Layout.fillHeight: true; implicitWidth: 1; color: Theme.line }
                Loader {
                    Layout.fillWidth: true; Layout.fillHeight: true
                    Layout.topMargin: 26; Layout.bottomMargin: 26; Layout.leftMargin: 30; Layout.rightMargin: 16
                    source: ({ som: "PgSound.qml", rede: "PgNet.qml", bt: "PgBt.qml", perf: "PgPerf.qml", cal: "PgCal.qml", avisos: "PgNotif.qml", ajustes: "PgSettings.qml", energia: "PgPower.qml" })[Ui.page]
                }
            }
            Btn { anchors { top: parent.top; right: parent.right; margins: 18 } variant: "quiet"; icon: "x"; implicitHeight: 44; a11y: "Fechar painel"; onClicked: Ui.open = false }
        }
    }
}
}
