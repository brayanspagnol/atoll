import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.UPower
import "parse.js" as P

Page {
    id: pg
    title: Tr.t("Performance")
    subtitle: Tr.t("Last 5 minutes")
    Component.onCompleted: Sys.procsActive = true
    Component.onDestruction: Sys.procsActive = false
    readonly property var bat: UPower.displayDevice
    readonly property var stateTxt: ({ [UPowerDeviceState.Charging]: Tr.t("Charging"), [UPowerDeviceState.Discharging]: Tr.t("On battery"), [UPowerDeviceState.FullyCharged]: Tr.t("Full"), [UPowerDeviceState.PendingCharge]: Tr.t("Pending charge") })

    function hhmm(s) { const m = Math.round(s / 60); return m >= 60 ? Math.floor(m / 60) + " h " + (m % 60) + " min" : m + " min" }

    GridLayout {
        Layout.fillWidth: true; Layout.topMargin: 8
        columns: 3; rowSpacing: 20; columnSpacing: 20
        Spark { Layout.fillWidth: true; Layout.preferredWidth: 1; title: Tr.t("Processor"); values: Sys.cpuHist; value: Math.round(Sys.cpu) + "%" }
        Spark { Layout.fillWidth: true; Layout.preferredWidth: 1; title: Tr.t("Memory"); values: Sys.memHist; value: P.bytes(Sys.memInfo.used) + " / " + P.bytes(Sys.memInfo.total) }
        Spark { Layout.fillWidth: true; Layout.preferredWidth: 1; title: Tr.t("Processor temperature"); values: Sys.tempHist; max: 100; fmt: v => Math.round(v) + " °C"; value: Math.round(Sys.temp) + " °C" }
        Spark { Layout.fillWidth: true; Layout.preferredWidth: 1; title: Tr.t("Receiving"); values: Sys.rxHist; max: 1048576; fmt: v => P.bytes(v) + "/s"; value: P.bytes(Sys.rxRate) + "/s" }
        Spark { Layout.fillWidth: true; Layout.preferredWidth: 1; title: Tr.t("Sending"); values: Sys.txHist; max: 1048576; fmt: v => P.bytes(v) + "/s"; value: P.bytes(Sys.txRate) + "/s" }
        ColumnLayout {
            Layout.fillWidth: true; Layout.preferredWidth: 1; Layout.alignment: Qt.AlignTop; spacing: 8
            Tx { text: Tr.t("System disk"); dim: true; size: 13 }
            Tx { text: P.bytes(Sys.disk.used) + " / " + P.bytes(Sys.disk.size); mono: true; size: 14; strong: true }
            Rectangle {
                Layout.fillWidth: true; implicitHeight: 6; radius: 3; color: Theme.line
                Rectangle { height: 6; radius: 3; width: parent.width * Sys.disk.used / Sys.disk.size; color: Sys.disk.used / Sys.disk.size > 0.9 ? Theme.danger : Theme.accent }
            }
            Tx { visible: Sys.memInfo.swapTotal > 0; text: "Swap " + P.bytes(Sys.memInfo.swapUsed) + " / " + P.bytes(Sys.memInfo.swapTotal); dim: true; mono: true; size: 12 }
        }
    }

    Sec { title: Tr.t("%1 cores").arg(Sys.cores.length) }
    Item {
        Layout.fillWidth: true; implicitHeight: 56
        Row {
            anchors.fill: parent; spacing: 4
            // By count, so a new reading every cycle updates the bars instead of rebuilding them.
            Repeater {
                model: Sys.cores.length
                Item {
                    id: core
                    required property int index
                    readonly property real load: Sys.cores[index] ?? 0
                    width: (parent.width - 4 * (Sys.cores.length - 1)) / Sys.cores.length; height: 56
                    Accessible.role: Accessible.Indicator; Accessible.name: Tr.t("Core %1: %2%").arg(index).arg(Math.round(load))
                    Rectangle { anchors { left: parent.left; right: parent.right; top: parent.top; bottom: lbl.top; bottomMargin: 4 } color: Theme.raised; radius: 3
                        Rectangle { anchors.bottom: parent.bottom; width: parent.width; radius: 3; height: Math.max(2, parent.height * core.load / 100); color: Theme.accent }
                    }
                    Tx { id: lbl; anchors.bottom: parent.bottom; anchors.horizontalCenter: parent.horizontalCenter; text: parent.index; mono: true; size: 10; dim: true }
                }
            }
        }
    }

    Sec { visible: pg.bat?.isLaptopBattery ?? false; title: Tr.t("Battery") }
    RowLayout {
        visible: pg.bat?.isLaptopBattery ?? false
        Layout.fillWidth: true; spacing: 24
        Tx { text: Math.round((pg.bat?.percentage ?? 0) * 100) + "%"; mono: true; size: 22; strong: true }
        Tx { text: pg.stateTxt[pg.bat?.state] ?? "—" }
        Tx { dim: true; text: pg.bat?.timeToEmpty > 0 ? Tr.t("%1 left").arg(pg.hhmm(pg.bat.timeToEmpty)) : pg.bat?.timeToFull > 0 ? Tr.t("Full in %1").arg(pg.hhmm(pg.bat.timeToFull)) : "" }
        Tx { dim: true; mono: true; text: pg.bat?.changeRate ? pg.bat.changeRate.toFixed(1) + " W" : ""; Layout.fillWidth: true }
    }

    Sec {
        title: Tr.t("Processes")
        Seg {
            options: [Tr.t("By CPU"), Tr.t("By memory")]; current: Sys.procSort === "cpu" ? 0 : 1
            onPicked: i => Sys.procSort = i ? "mem" : "cpu"
        }
    }
    RowLayout {
        Layout.fillWidth: true; Layout.leftMargin: 12; Layout.rightMargin: 12; spacing: 12
        Tx { text: Tr.t("Name"); dim: true; size: 13; Layout.fillWidth: true }
        Tx { text: "PID"; dim: true; size: 13; Layout.preferredWidth: 64; horizontalAlignment: Text.AlignRight }
        Tx { text: "CPU"; dim: true; size: 13; Layout.preferredWidth: 56; horizontalAlignment: Text.AlignRight }
        Tx { text: "Mem"; dim: true; size: 13; Layout.preferredWidth: 56; horizontalAlignment: Text.AlignRight }
        Item { Layout.preferredWidth: 96 }
    }
    Tx { visible: Sys.procs.length === 0; text: Tr.t("Measuring…"); dim: true }
    // Keyed by pid: a row outlives the refresh, and with it a pending "Confirm".
    Repeater {
        model: ScriptModel { values: Sys.procs; objectProp: "pid" }
        Rowi {
            id: pr
            required property var modelData
            // ScriptModel leaves a moved row's modelData stale, so the fresh reading comes from its pid.
            readonly property var proc: Sys.procs.find(p => p.pid === modelData.pid) ?? modelData
            clickable: false
            implicitHeight: 44
            property bool sure: false
            Timer { running: pr.sure; interval: 4000; onTriggered: pr.sure = false }
            Tx { text: pr.proc.name; Layout.fillWidth: true }
            Tx { text: pr.proc.pid; mono: true; dim: true; size: 13; Layout.preferredWidth: 64; horizontalAlignment: Text.AlignRight }
            Tx { text: pr.proc.cpu.toFixed(1); mono: true; size: 13; Layout.preferredWidth: 56; horizontalAlignment: Text.AlignRight }
            Tx { text: pr.proc.mem.toFixed(1); mono: true; size: 13; Layout.preferredWidth: 56; horizontalAlignment: Text.AlignRight }
            Btn {
                Layout.preferredWidth: 96; implicitHeight: 34
                variant: "danger"; text: pr.sure ? Tr.t("Confirm") : Tr.t("End process")
                a11y: Tr.t("End %1").arg(pr.proc.name)
                onClicked: { if (pr.sure) { Quickshell.execDetached(["kill", String(pr.proc.pid)]); pr.sure = false } else pr.sure = true }
            }
        }
    }
}
