import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Io

Page {
    id: pg
    title: "Bluetooth"
    readonly property var ad: Bluetooth.defaultAdapter
    readonly property var devs: ad ? [...ad.devices.values].sort((a, b) => (b.connected - a.connected) || (b.paired - a.paired) || a.name.localeCompare(b.name)) : []
    readonly property var paired: devs.filter(d => d.paired)
    readonly property var nearby: devs.filter(d => !d.paired)
    subtitle: !ad ? Tr.t("No adapter") : !ad.enabled ? Tr.t("Off") : Tr.t("Connected: %1").arg(paired.filter(d => d.connected).length)
    property string pairing: ""
    property string err: ""

    // Scan only while this page is open; scanning burns radio and battery.
    Binding { target: pg.ad; property: "discovering"; value: true; when: !!pg.ad && pg.ad.enabled }
    Component.onDestruction: if (ad?.enabled) ad.discovering = false

    // bluetoothctl carries its own agent; Quickshell does not register one.
    Process {
        id: pairP
        property string mac: ""
        command: ["sh", "-c", `bluetoothctl --agent NoInputNoOutput --timeout 25 pair ${mac} && bluetoothctl trust ${mac} && bluetoothctl connect ${mac}`]
        onExited: code => {
            pg.err = code === 0 ? "" : Tr.t("Couldn't pair. If the device asks for a code (keyboards), use bluetoothctl in a terminal.")
            pg.pairing = ""
        }
    }

    Sec {
        title: Tr.t("Adapter")
        Swt { visible: !!pg.ad; a11y: "Bluetooth"; checked: pg.ad?.enabled ?? false; onToggled: pg.ad.enabled = checked }
    }
    Tx { visible: !pg.ad; text: Tr.t("No adapter. Is the bluetooth service running?"); dim: true }
    Tx { visible: pg.err; text: pg.err; color: Theme.danger; wrapMode: Text.Wrap; Layout.fillWidth: true }

    component Dev: Rowi {
        id: d
        required property var modelData
        a11y: modelData.name
        clickable: false
        Ic { name: /audio|head/.test(d.modelData.icon) ? "head" : /mouse/.test(d.modelData.icon) ? "mouse" : /keyboard/.test(d.modelData.icon) ? "keyboard" : /phone/.test(d.modelData.icon) ? "phone" : "bt"; color: d.modelData.connected ? Theme.accent : Theme.muted; Layout.preferredWidth: 20 }
        ColumnLayout {
            spacing: 0; Layout.fillWidth: true
            Tx { text: d.modelData.name || d.modelData.address; Layout.fillWidth: true; strong: d.modelData.connected }
            Tx { text: d.modelData.address; mono: true; size: 11; dim: true }
        }
        Tx { visible: d.modelData.batteryAvailable; mono: true; dim: true; text: Math.round(d.modelData.battery * 100) + "%" }
        Tx { visible: d.modelData.state === BluetoothDeviceState.Connecting; text: Tr.t("Connecting…"); dim: true }
        Btn {
            visible: d.modelData.paired
            text: d.modelData.connected ? Tr.t("Disconnect") : Tr.t("Connect")
            onClicked: d.modelData.connected ? d.modelData.disconnect() : d.modelData.connect()
        }
        Btn { visible: d.modelData.paired; text: Tr.t("Forget"); variant: "danger"; onClicked: d.modelData.forget() }
        Btn {
            visible: !d.modelData.paired
            text: pg.pairing === d.modelData.address ? Tr.t("Pairing…") : Tr.t("Pair")
            variant: "solid"
            enabledB: !pg.pairing
            onClicked: { pg.err = ""; pg.pairing = d.modelData.address; pairP.mac = d.modelData.address; pairP.running = true }
        }
    }

    Sec { visible: pg.ad?.enabled ?? false; title: Tr.t("Paired") }
    Repeater { model: pg.ad?.enabled ? pg.paired : []; Dev {} }
    Tx { visible: (pg.ad?.enabled ?? false) && pg.paired.length === 0; text: Tr.t("No paired devices"); dim: true }
    Sec { visible: pg.ad?.enabled ?? false; title: Tr.t("Nearby") }
    Repeater { model: pg.ad?.enabled ? pg.nearby : []; Dev {} }
    Tx { visible: (pg.ad?.enabled ?? false) && pg.nearby.length === 0; text: Tr.t("Searching…"); dim: true }
}
