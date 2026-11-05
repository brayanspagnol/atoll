import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.SystemTray
import Quickshell.Services.UPower
import Quickshell.Bluetooth
import Quickshell.Wayland
import Quickshell.Widgets

PanelWindow {
    id: win
    required property var modelData
    screen: modelData
    anchors.top: true
    margins.top: 14
    implicitWidth: pill.implicitWidth
    implicitHeight: 56
    exclusiveZone: 64
    color: "transparent"
    WlrLayershell.namespace: "atoll-island"
    readonly property var mon: Hyprland.monitorFor(modelData)

    Frost {
        id: pill
        anchors.fill: parent
        implicitWidth: row.implicitWidth + 16
        radius: 28
        RowLayout {
            id: row
            anchors.centerIn: parent
            spacing: 10
            RowLayout {
                spacing: 6
                Layout.leftMargin: 8
                Repeater {
                    model: Hyprland.workspaces.values.filter(w => w.id > 0 && w.monitor === win.mon).sort((a, b) => a.id - b.id)
                    Item {
                        id: ws
                        required property var modelData
                        readonly property bool active: modelData.id === win.mon?.activeWorkspace?.id
                        implicitWidth: dot.width; implicitHeight: 44
                        Accessible.role: Accessible.Button
                        Accessible.name: Tr.t("Workspace %1").arg(modelData.id)
                        Rectangle {
                            id: dot
                            anchors.verticalCenter: parent.verticalCenter
                            width: ws.active ? 28 : 10; height: 10; radius: 5
                            color: ws.active ? Theme.accent : Theme.muted
                            Behavior on width { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                        }
                        MouseArea { anchors.fill: parent; anchors.margins: -3; cursorShape: Qt.PointingHandCursor; onClicked: Hyprland.dispatch(`hl.dsp.focus({ workspace = ${ws.modelData.id} })`) }
                    }
                }
            }
            Rectangle { implicitWidth: 1; implicitHeight: 24; color: Theme.line }
            Rectangle {
                implicitWidth: clockRow.implicitWidth + 24; implicitHeight: 44; radius: Theme.radiusSmall
                color: cm.containsMouse ? Theme.raised : "transparent"
                Accessible.role: Accessible.Button
                Accessible.name: Tr.t("Calendar") + ", " + timeT.text + ", " + dateT.text
                SystemClock { id: clk; precision: SystemClock.Seconds }
                RowLayout {
                    id: clockRow; anchors.centerIn: parent; spacing: 10
                    Tx { id: timeT; text: Qt.formatTime(clk.date, "HH:mm"); size: 18; strong: true }
                    Tx { id: dateT; text: Tr.date(clk.date, "ddd, MMM d").replace(/\./g, ""); dim: true }
                }
                MouseArea { id: cm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Ui.toggle("cal") }
            }
            Rectangle {
                visible: !!Audio.player?.trackTitle
                implicitWidth: mediaRow.implicitWidth + 24; implicitHeight: 44; radius: Theme.radiusSmall
                color: Ui.mediaOpen || mm.containsMouse ? Theme.raised : "transparent"
                Accessible.role: Accessible.Button
                Accessible.name: Tr.t("Music: %1").arg(Audio.player?.trackTitle ?? "")
                RowLayout {
                    id: mediaRow; anchors.centerIn: parent; spacing: 8
                    Ic { name: Audio.player?.isPlaying ? "pause" : "music"; size: 16; color: Theme.muted }
                    Tx { text: Audio.player?.trackTitle ?? ""; dim: true; Layout.maximumWidth: 260 }
                }
                MouseArea { id: mm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Ui.toggleMedia(win.modelData, win) }
            }
            Repeater {
                model: SystemTray.items.values
                MouseArea {
                    required property var modelData
                    implicitWidth: 32; implicitHeight: 44
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    cursorShape: Qt.PointingHandCursor
                    Accessible.role: Accessible.Button
                    Accessible.name: modelData.tooltipTitle || modelData.title || modelData.id
                    IconImage { anchors.centerIn: parent; implicitSize: 18; source: parent.modelData.icon }
                    onClicked: m => {
                        if (m.button === Qt.RightButton || modelData.onlyMenu) {
                            const p = mapToItem(null, 0, height + 8)
                            modelData.display(win, p.x, p.y)
                        } else modelData.activate()
                    }
                }
            }
            Rectangle { implicitWidth: 1; implicitHeight: 24; color: Theme.line }
            RowLayout {
                spacing: 0
                Stat {
                    icon: Audio.icon; a11y: Tr.t("Sound"); target: "som"
                    onWheel: d => { if (Audio.sink?.audio) Audio.sink.audio.volume = Math.max(0, Math.min(1.5, Audio.sink.audio.volume + d * 0.05)) }
                }
                Stat { icon: Net.icon; a11y: Tr.t("Internet") + ": " + Net.status; target: "rede" }
                Stat {
                    readonly property var ad: Bluetooth.defaultAdapter
                    visible: !!ad
                    icon: !ad?.enabled ? "btOff" : ad.devices.values.some(d => d.connected) ? "btOn" : "bt"
                    a11y: "Bluetooth"; target: "bt"
                }
                Stat {
                    icon: Cfg.v.dnd ? "bellOff" : "avisos"
                    label: Notifs.all.length ? String(Notifs.all.length) : ""
                    a11y: Tr.t("Notifications"); target: "avisos"
                }
                Stat { icon: "energia"; a11y: Tr.t("Power"); target: "energia" }
                Stat {
                    readonly property var bat: UPower.displayDevice
                    readonly property bool plugged: bat?.state === UPowerDeviceState.Charging || bat?.state === UPowerDeviceState.FullyCharged
                    visible: bat?.isLaptopBattery ?? false
                    icon: plugged ? "charge" : (bat?.percentage ?? 1) < 0.15 ? "batLow" : "bat"
                    label: Math.round((bat?.percentage ?? 0) * 100) + ""
                    alert: !plugged && (bat?.percentage ?? 1) < 0.15
                    a11y: Tr.t("Battery"); target: "perf"
                }
            }
        }
    }
}
