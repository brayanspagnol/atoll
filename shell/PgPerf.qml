import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.UPower
import "parse.js" as P

Page {
    id: pg
    title: "Desempenho"
    subtitle: "Últimos 5 minutos"
    Component.onCompleted: Sys.procsActive = true
    Component.onDestruction: Sys.procsActive = false
    readonly property var bat: UPower.displayDevice
    readonly property var stateTxt: ({ [UPowerDeviceState.Charging]: "Carregando", [UPowerDeviceState.Discharging]: "Na bateria", [UPowerDeviceState.FullyCharged]: "Completa", [UPowerDeviceState.PendingCharge]: "Aguardando carga" })

    function hhmm(s) { const m = Math.round(s / 60); return m >= 60 ? Math.floor(m / 60) + " h " + (m % 60) + " min" : m + " min" }

    GridLayout {
        Layout.fillWidth: true; Layout.topMargin: 8
        columns: 3; rowSpacing: 20; columnSpacing: 20
        Spark { Layout.fillWidth: true; Layout.preferredWidth: 1; title: "Processador"; values: Sys.cpuHist; value: Math.round(Sys.cpu) + "%" }
        Spark { Layout.fillWidth: true; Layout.preferredWidth: 1; title: "Memória"; values: Sys.memHist; value: P.bytes(Sys.memInfo.used) + " / " + P.bytes(Sys.memInfo.total) }
        Spark { Layout.fillWidth: true; Layout.preferredWidth: 1; title: "Temperatura do processador"; values: Sys.tempHist; max: 100; fmt: v => Math.round(v) + " °C"; value: Math.round(Sys.temp) + " °C" }
        Spark { Layout.fillWidth: true; Layout.preferredWidth: 1; title: "Recebendo"; values: Sys.rxHist; max: 1048576; fmt: v => P.bytes(v) + "/s"; value: P.bytes(Sys.rxRate) + "/s" }
        Spark { Layout.fillWidth: true; Layout.preferredWidth: 1; title: "Enviando"; values: Sys.txHist; max: 1048576; fmt: v => P.bytes(v) + "/s"; value: P.bytes(Sys.txRate) + "/s" }
        ColumnLayout {
            Layout.fillWidth: true; Layout.preferredWidth: 1; Layout.alignment: Qt.AlignTop; spacing: 8
            Tx { text: "Disco do sistema"; dim: true; size: 13 }
            Tx { text: P.bytes(Sys.disk.used) + " / " + P.bytes(Sys.disk.size); mono: true; size: 14; strong: true }
            Rectangle {
                Layout.fillWidth: true; implicitHeight: 6; radius: 3; color: Theme.line
                Rectangle { height: 6; radius: 3; width: parent.width * Sys.disk.used / Sys.disk.size; color: Sys.disk.used / Sys.disk.size > 0.9 ? Theme.danger : Theme.accent }
            }
            Tx { visible: Sys.memInfo.swapTotal > 0; text: "Swap " + P.bytes(Sys.memInfo.swapUsed) + " / " + P.bytes(Sys.memInfo.swapTotal); dim: true; mono: true; size: 12 }
        }
    }

    Sec { title: Sys.cores.length + " núcleos" }
    Item {
        Layout.fillWidth: true; implicitHeight: 56
        Row {
            anchors.fill: parent; spacing: 4
            Repeater {
                model: Sys.cores
                Item {
                    required property real modelData
                    required property int index
                    width: (parent.width - 4 * (Sys.cores.length - 1)) / Sys.cores.length; height: 56
                    Accessible.role: Accessible.Indicator; Accessible.name: `Núcleo ${index}: ${Math.round(modelData)}%`
                    Rectangle { anchors { left: parent.left; right: parent.right; top: parent.top; bottom: lbl.top; bottomMargin: 4 } color: Theme.raised; radius: 3
                        Rectangle { anchors.bottom: parent.bottom; width: parent.width; radius: 3; height: Math.max(2, parent.height * parent.parent.modelData / 100); color: Theme.accent }
                    }
                    Tx { id: lbl; anchors.bottom: parent.bottom; anchors.horizontalCenter: parent.horizontalCenter; text: parent.index; mono: true; size: 10; dim: true }
                }
            }
        }
    }

    Sec { visible: pg.bat?.isLaptopBattery ?? false; title: "Bateria" }
    RowLayout {
        visible: pg.bat?.isLaptopBattery ?? false
        Layout.fillWidth: true; spacing: 24
        Tx { text: Math.round((pg.bat?.percentage ?? 0) * 100) + "%"; mono: true; size: 22; strong: true }
        Tx { text: pg.stateTxt[pg.bat?.state] ?? "—" }
        Tx { dim: true; text: pg.bat?.timeToEmpty > 0 ? "Restam " + pg.hhmm(pg.bat.timeToEmpty) : pg.bat?.timeToFull > 0 ? "Cheia em " + pg.hhmm(pg.bat.timeToFull) : "" }
        Tx { dim: true; mono: true; text: pg.bat?.changeRate ? pg.bat.changeRate.toFixed(1) + " W" : ""; Layout.fillWidth: true }
    }

    Sec {
        title: "Processos"
        Seg {
            options: ["Por CPU", "Por memória"]; current: Sys.procSort === "cpu" ? 0 : 1
            onPicked: i => Sys.procSort = i ? "mem" : "cpu"
        }
    }
    RowLayout {
        Layout.fillWidth: true; Layout.leftMargin: 12; Layout.rightMargin: 12; spacing: 12
        Tx { text: "Nome"; dim: true; size: 13; Layout.fillWidth: true }
        Tx { text: "PID"; dim: true; size: 13; Layout.preferredWidth: 64; horizontalAlignment: Text.AlignRight }
        Tx { text: "CPU"; dim: true; size: 13; Layout.preferredWidth: 56; horizontalAlignment: Text.AlignRight }
        Tx { text: "Mem"; dim: true; size: 13; Layout.preferredWidth: 56; horizontalAlignment: Text.AlignRight }
        Item { Layout.preferredWidth: 96 }
    }
    Tx { visible: Sys.procs.length === 0; text: "Medindo…"; dim: true }
    Repeater {
        model: Sys.procs
        Rowi {
            id: pr
            required property var modelData
            clickable: false
            implicitHeight: 44
            property bool sure: false
            Timer { running: pr.sure; interval: 4000; onTriggered: pr.sure = false }
            Tx { text: pr.modelData.name; Layout.fillWidth: true }
            Tx { text: pr.modelData.pid; mono: true; dim: true; size: 13; Layout.preferredWidth: 64; horizontalAlignment: Text.AlignRight }
            Tx { text: pr.modelData.cpu.toFixed(1); mono: true; size: 13; Layout.preferredWidth: 56; horizontalAlignment: Text.AlignRight }
            Tx { text: pr.modelData.mem.toFixed(1); mono: true; size: 13; Layout.preferredWidth: 56; horizontalAlignment: Text.AlignRight }
            Btn {
                Layout.preferredWidth: 96; implicitHeight: 34
                variant: "danger"; text: pr.sure ? "Confirmar" : "Encerrar"
                a11y: "Encerrar " + pr.modelData.name
                onClicked: { if (pr.sure) { Quickshell.execDetached(["kill", String(pr.modelData.pid)]); pr.sure = false } else pr.sure = true }
            }
        }
    }
}
