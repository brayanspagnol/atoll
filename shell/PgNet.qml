import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Networking
import "parse.js" as P

Page {
    id: pg
    title: Tr.t("Internet")
    readonly property var wifi: Net.wifi
    readonly property var wired: Net.wired
    readonly property var nets: wifi ? [...wifi.networks.values].sort((a, b) => (b.connected - a.connected) || (b.known - a.known) || (b.signalStrength - a.signalStrength)) : []
    readonly property var current: nets.find(n => n.connected) ?? null
    readonly property var conn: [Tr.t("Unknown"), Tr.t("No internet"), Tr.t("Login portal"), Tr.t("Limited"), Tr.t("Full")]
    subtitle: wired?.connected ? Tr.t("Cable connected") : current ? "Wi-Fi: " + current.name : Tr.t("Disconnected")
    property string askFor: ""
    property string err: ""
    property var details: ({})

    Binding { target: pg.wifi; property: "scannerEnabled"; value: Networking.wifiEnabled; when: !!pg.wifi }

    Process {
        id: info
        running: true
        command: ["sh", "-c", "for d in $(nmcli -t -f DEVICE,STATE device | awk -F: '$2==\"connected\"{print $1}'); do [ $d = lo ] || nmcli -t -f GENERAL.DEVICE,IP4.ADDRESS,IP4.GATEWAY,IP4.DNS device show $d; done"]
        stdout: StdioCollector {
            onStreamFinished: {
                const o = {}
                text.split("\n").forEach(l => { const i = l.indexOf(":"); if (i > 0) { const k = l.slice(0, i).replace(/\[\d+\]/, ""); if (!o[k]) o[k] = l.slice(i + 1) } })
                pg.details = o
            }
        }
    }
    Timer { interval: 5000; running: true; repeat: true; onTriggered: info.running = true }


    component Fact: ColumnLayout {
        Layout.fillWidth: true
        property string k: ""; property string val: ""
        spacing: 1
        Tx { text: k; dim: true; size: 13 }
        Tx { text: val || "—"; mono: true; size: 15 }
    }

    Sec { title: Tr.t("Connection") }
    GridLayout {
        Layout.fillWidth: true; columns: 3; rowSpacing: 16; columnSpacing: 16; uniformCellWidths: true
        Fact { k: Tr.t("Internet"); val: pg.conn[Networking.connectivity] ?? "—" }
        Fact { k: Tr.t("IP address"); val: pg.details["IP4.ADDRESS"] ?? "" }
        Fact { k: Tr.t("Gateway"); val: pg.details["IP4.GATEWAY"] ?? "" }
        Fact { k: "DNS"; val: pg.details["IP4.DNS"] ?? "" }
        Fact { k: Tr.t("Receiving"); val: P.bytes(Sys.rxRate) + "/s" }
        Fact { k: Tr.t("Sending"); val: P.bytes(Sys.txRate) + "/s" }
    }

    Sec { visible: !!pg.wired; title: Tr.t("Cable") }
    Rowi {
        visible: !!pg.wired; clickable: false
        Ic { name: "eth"; color: pg.wired?.connected ? Theme.accent : Theme.muted; Layout.preferredWidth: 20 }
        Tx { text: pg.wired?.name ?? ""; mono: true }
        Tx {
            Layout.fillWidth: true; dim: true; horizontalAlignment: Text.AlignRight
            text: !pg.wired?.hasLink ? Tr.t("No cable") : pg.wired.connected ? Tr.t("Connected · %1 Mb/s").arg(pg.wired.linkSpeed) : Tr.t("Cable present, no connection")
        }
    }

    Sec {
        title: "Wi-Fi"
        Swt { a11y: "Wi-Fi"; checked: Networking.wifiEnabled; onToggled: Networking.wifiEnabled = checked }
    }
    Tx { visible: !Networking.wifiHardwareEnabled; text: Tr.t("Wi-Fi blocked in hardware (switch or airplane mode)"); color: Theme.warn }
    Tx { visible: pg.err; text: pg.err; color: Theme.danger; wrapMode: Text.Wrap; Layout.fillWidth: true }
    Tx { visible: Networking.wifiEnabled && pg.nets.length === 0; text: Tr.t("Searching for networks…"); dim: true }
    Repeater {
        model: Networking.wifiEnabled ? pg.nets : []
        ColumnLayout {
            id: n
            required property var modelData
            Layout.fillWidth: true; spacing: 4
            readonly property bool open: modelData.security === WifiSecurityType.Open || modelData.security === WifiSecurityType.Owe
            readonly property bool enterprise: [WifiSecurityType.Wpa2Eap, WifiSecurityType.WpaEap, WifiSecurityType.Wpa3SuiteB192, WifiSecurityType.DynamicWep, WifiSecurityType.Leap].includes(modelData.security)
            Connections {
                target: n.modelData
                function onConnectionFailed(reason) {
                    pg.err = Tr.t("Couldn't connect to %1: %2").arg(n.modelData.name).arg(reason === ConnectionFailReason.NoSecrets || reason === ConnectionFailReason.WifiClientFailed ? Tr.t("wrong password") : ConnectionFailReason.toString(reason))
                    if (!n.modelData.known && !n.open) pg.askFor = n.modelData.name
                }
            }
            Rowi {
                a11y: n.modelData.name
                selected: n.modelData.connected
                clickable: !n.modelData.connected
                onClicked: {
                    pg.err = ""
                    if (n.enterprise && !n.modelData.known) pg.err = Tr.t("Enterprise network (802.1X): set it up once with nmcli.")
                    else if (n.modelData.known || n.open) n.modelData.connect()
                    else pg.askFor = pg.askFor === n.modelData.name ? "" : n.modelData.name
                }
                Ic { name: ["wifi1", "wifi2", "wifi3", "wifi4"][Math.min(3, Math.floor(n.modelData.signalStrength * 4))]; color: n.modelData.connected ? Theme.accent : Theme.muted; Layout.preferredWidth: 20 }
                Tx { text: n.modelData.name; Layout.fillWidth: true; strong: n.modelData.connected }
                Tx { mono: true; size: 11; dim: true; text: Math.round(n.modelData.signalStrength * 100) + "%" }
                Ic { visible: !n.open; name: "lock"; size: 13; color: Theme.muted }
                Tx { dim: true; size: 12; text: n.modelData.stateChanging ? Tr.t("Connecting…") : n.modelData.connected ? Tr.t("Connected") : n.modelData.known ? Tr.t("Saved") : "" }
                Btn { visible: n.modelData.connected; text: Tr.t("Disconnect"); onClicked: n.modelData.disconnect() }
                Btn { visible: n.modelData.known; text: Tr.t("Forget"); variant: "danger"; onClicked: n.modelData.forget() }
            }
            RowLayout {
                visible: pg.askFor === n.modelData.name
                Layout.fillWidth: true; Layout.leftMargin: 40; Layout.bottomMargin: 6; spacing: 8
                Fld {
                    id: psk; Layout.fillWidth: true; placeholderText: Tr.t("Password for %1").arg(n.modelData.name)
                    echoMode: TextInput.Password
                    Accessible.name: Tr.t("Wi-Fi password")
                    onVisibleChanged: if (visible) forceActiveFocus(); else text = ""
                    onAccepted: go.clicked()
                }
                Btn {
                    id: go; text: Tr.t("Connect"); variant: "solid"; enabledB: psk.text.length >= 8
                    onClicked: { n.modelData.connectWithPsk(psk.text); pg.askFor = "" }
                }
            }
        }
    }
}
