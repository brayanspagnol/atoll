import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Networking
import "parse.js" as P

Page {
    id: pg
    title: "Internet"
    readonly property var wifi: Net.wifi
    readonly property var wired: Net.wired
    readonly property var nets: wifi ? [...wifi.networks.values].sort((a, b) => (b.connected - a.connected) || (b.known - a.known) || (b.signalStrength - a.signalStrength)) : []
    readonly property var current: nets.find(n => n.connected) ?? null
    readonly property var conn: ["Desconhecida", "Sem internet", "Portal de login", "Limitada", "Completa"]
    subtitle: wired?.connected ? "Cabo conectado" : current ? "Wi-Fi: " + current.name : "Desconectado"
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

    Sec { title: "Conexão" }
    GridLayout {
        Layout.fillWidth: true; columns: 3; rowSpacing: 16; columnSpacing: 16; uniformCellWidths: true
        Fact { k: "Internet"; val: pg.conn[Networking.connectivity] ?? "—" }
        Fact { k: "Endereço IP"; val: pg.details["IP4.ADDRESS"] ?? "" }
        Fact { k: "Gateway"; val: pg.details["IP4.GATEWAY"] ?? "" }
        Fact { k: "DNS"; val: pg.details["IP4.DNS"] ?? "" }
        Fact { k: "Recebendo"; val: P.bytes(Sys.rxRate) + "/s" }
        Fact { k: "Enviando"; val: P.bytes(Sys.txRate) + "/s" }
    }

    Sec { visible: !!pg.wired; title: "Cabo" }
    Rowi {
        visible: !!pg.wired; clickable: false
        Ic { name: "eth"; color: pg.wired?.connected ? Theme.accent : Theme.muted; Layout.preferredWidth: 20 }
        Tx { text: pg.wired?.name ?? ""; mono: true }
        Tx {
            Layout.fillWidth: true; dim: true; horizontalAlignment: Text.AlignRight
            text: !pg.wired?.hasLink ? "Sem cabo" : pg.wired.connected ? "Conectado · " + pg.wired.linkSpeed + " Mb/s" : "Cabo presente, sem conexão"
        }
    }

    Sec {
        title: "Wi-Fi"
        Swt { a11y: "Wi-Fi"; checked: Networking.wifiEnabled; onToggled: Networking.wifiEnabled = checked }
    }
    Tx { visible: !Networking.wifiHardwareEnabled; text: "Wi-Fi bloqueado no hardware (botão ou modo avião)"; color: Theme.warn }
    Tx { visible: pg.err; text: pg.err; color: Theme.danger; wrapMode: Text.Wrap; Layout.fillWidth: true }
    Tx { visible: Networking.wifiEnabled && pg.nets.length === 0; text: "Procurando redes…"; dim: true }
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
                    pg.err = `Falha ao conectar em ${n.modelData.name}: ${reason === ConnectionFailReason.NoSecrets || reason === ConnectionFailReason.WifiClientFailed ? "senha incorreta" : ConnectionFailReason.toString(reason)}`
                    if (!n.modelData.known && !n.open) pg.askFor = n.modelData.name
                }
            }
            Rowi {
                a11y: n.modelData.name
                selected: n.modelData.connected
                clickable: !n.modelData.connected
                onClicked: {
                    pg.err = ""
                    if (n.enterprise && !n.modelData.known) pg.err = "Rede corporativa (802.1X): configure uma vez com nmcli."
                    else if (n.modelData.known || n.open) n.modelData.connect()
                    else pg.askFor = pg.askFor === n.modelData.name ? "" : n.modelData.name
                }
                Ic { name: ["wifi1", "wifi2", "wifi3", "wifi4"][Math.min(3, Math.floor(n.modelData.signalStrength * 4))]; color: n.modelData.connected ? Theme.accent : Theme.muted; Layout.preferredWidth: 20 }
                Tx { text: n.modelData.name; Layout.fillWidth: true; strong: n.modelData.connected }
                Tx { mono: true; size: 11; dim: true; text: Math.round(n.modelData.signalStrength * 100) + "%" }
                Ic { visible: !n.open; name: "lock"; size: 13; color: Theme.muted }
                Tx { dim: true; size: 12; text: n.modelData.stateChanging ? "Conectando…" : n.modelData.connected ? "Conectada" : n.modelData.known ? "Salva" : "" }
                Btn { visible: n.modelData.connected; text: "Desconectar"; onClicked: n.modelData.disconnect() }
                Btn { visible: n.modelData.known; text: "Esquecer"; variant: "danger"; onClicked: n.modelData.forget() }
            }
            RowLayout {
                visible: pg.askFor === n.modelData.name
                Layout.fillWidth: true; Layout.leftMargin: 40; Layout.bottomMargin: 6; spacing: 8
                Fld {
                    id: psk; Layout.fillWidth: true; placeholderText: "Senha de " + n.modelData.name
                    echoMode: TextInput.Password
                    Accessible.name: "Senha do Wi-Fi"
                    onVisibleChanged: if (visible) forceActiveFocus(); else text = ""
                    onAccepted: go.clicked()
                }
                Btn {
                    id: go; text: "Conectar"; variant: "solid"; enabledB: psk.text.length >= 8
                    onClicked: { n.modelData.connectWithPsk(psk.text); pg.askFor = "" }
                }
            }
        }
    }
}
