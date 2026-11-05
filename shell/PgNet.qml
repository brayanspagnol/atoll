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
    readonly property var conn: [Tr.t("Unknown"), Tr.t("No internet"), Tr.t("Login portal"), Tr.t("Limited"), Tr.t("Full access")]
    subtitle: wired?.connected ? Tr.t("Cable connected") : current ? "Wi-Fi: " + current.name : Tr.t("Disconnected")
    property string askFor: ""
    property string err: ""
    property var details: ({})
    property bool formOpen: false
    property bool formHidden: true
    property int formKind: 1 // 0 no password, 1 password, 2 enterprise
    property int formEap: 0
    property string armedVpn: ""
    Timer { running: pg.armedVpn !== ""; interval: 5000; onTriggered: pg.armedVpn = "" }
    Timer { interval: 5000; running: true; repeat: true; triggeredOnStart: true; onTriggered: Net.refreshVpns() }
    function openForm(name, hidden, kind) {
        Net.addErr = ""
        formOpen = true; formHidden = hidden; formKind = kind
        formSsid.text = name; formPass.text = ""; formUser.text = ""; formDomain.text = ""
        // The form sits below the list of networks.
        Qt.callLater(() => pg.contentY = Math.max(0, pg.contentHeight - pg.height))
        if (hidden) formSsid.forceActiveFocus(); else formUser.forceActiveFocus()
    }

    Connections {
        target: Net
        function onAddStateChanged() { if (!Net.addState && !Net.addErr) pg.formOpen = false }
    }
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
                    if (n.enterprise && !n.modelData.known) pg.openForm(n.modelData.name, false, 2)
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
    Btn { visible: Networking.wifiEnabled && !pg.formOpen; text: Tr.t("Other network…"); onClicked: pg.openForm("", true, 1) }
    ColumnLayout {
        visible: pg.formOpen
        Layout.fillWidth: true; spacing: 8
        Sec { title: pg.formHidden ? Tr.t("Other network") : Tr.t("Enterprise network") }
        Fld {
            id: formSsid
            visible: pg.formHidden
            Layout.fillWidth: true; placeholderText: Tr.t("Network name"); Accessible.name: Tr.t("Network name")
        }
        Tx { visible: !pg.formHidden; text: formSsid.text; strong: true }
        Seg {
            visible: pg.formHidden
            options: [Tr.t("No password"), Tr.t("Password"), Tr.t("Enterprise (802.1X)")]
            current: pg.formKind
            onPicked: i => pg.formKind = i
        }
        Seg { id: formEap; visible: pg.formKind === 2; options: ["PEAP", "TTLS"]; current: pg.formEap; onPicked: i => pg.formEap = i }
        Fld { id: formUser; visible: pg.formKind === 2; Layout.fillWidth: true; placeholderText: Tr.t("User"); Accessible.name: Tr.t("User") }
        Fld {
            id: formPass
            visible: pg.formKind !== 0
            Layout.fillWidth: true; placeholderText: Tr.t("Password"); Accessible.name: Tr.t("Password")
            echoMode: TextInput.Password
            onAccepted: if (formGo.enabledB) formGo.clicked()
        }
        Fld { id: formDomain; visible: pg.formKind === 2; Layout.fillWidth: true; placeholderText: Tr.t("Server domain (optional)"); Accessible.name: Tr.t("Server domain (optional)") }
        Tx { visible: pg.formKind === 2; text: Tr.t("Without a domain, the server's identity isn't checked, and a fake network could capture your password."); color: Theme.warn; size: 13; wrapMode: Text.Wrap; Layout.fillWidth: true }
        Tx { visible: !!Net.addState; text: Net.addState === "saving" ? Tr.t("Saving…") : Tr.t("Connecting…"); dim: true }
        Tx { visible: !!Net.addErr; text: Net.addErr; color: Theme.danger; wrapMode: Text.Wrap; Layout.fillWidth: true }
        RowLayout {
            spacing: 8
            Btn {
                id: formGo
                text: Tr.t("Connect"); variant: "solid"
                enabledB: !Net.addState && formSsid.text.trim().length > 0
                    && (pg.formKind === 0 || (pg.formKind === 1 && formPass.text.length >= 8) || (pg.formKind === 2 && formPass.text.length > 0 && formUser.text.trim().length > 0))
                onClicked: {
                    const hidden = pg.formHidden ? "yes" : "no", ssid = formSsid.text.trim()
                    if (pg.formKind === 2) Net.addWifi(["wifi-eap", ssid, hidden, pg.formEap === 0 ? "peap" : "ttls", formUser.text.trim()].concat(formDomain.text.trim() ? [formDomain.text.trim()] : []), formPass.text)
                    else Net.addWifi(["wifi", ssid, hidden, pg.formKind === 1 ? "psk" : "open"], pg.formKind === 1 ? formPass.text : "")
                    formPass.text = ""
                }
            }
            Btn { text: Tr.t("Cancel"); onClicked: pg.formOpen = false }
        }
    }

    Sec {
        title: "VPN"
        Btn { text: Tr.t("Import…"); onClicked: Net.importVpn() }
    }
    Tx { visible: !!Net.vpnErr; text: Net.vpnErr; color: Theme.danger; wrapMode: Text.Wrap; Layout.fillWidth: true }
    Tx { visible: Net.vpns.length === 0; text: Tr.t("No VPNs yet. Import a WireGuard (.conf) or OpenVPN (.ovpn) file."); dim: true; wrapMode: Text.Wrap; Layout.fillWidth: true }
    Repeater {
        model: Net.vpns
        Rowi {
            id: v
            required property var modelData
            readonly property bool sure: pg.armedVpn === modelData.uuid
            a11y: modelData.name
            selected: modelData.active
            clickable: false
            Ic { name: "lock"; color: v.modelData.active ? Theme.accent : Theme.muted; Layout.preferredWidth: 20 }
            Tx { text: v.modelData.name; Layout.fillWidth: true; strong: v.modelData.active }
            Tx { mono: true; size: 11; dim: true; text: v.modelData.type === "wireguard" ? "WireGuard" : "VPN" }
            Tx { visible: Net.vpnBusy === v.modelData.uuid; text: Tr.t("Connecting…"); dim: true; size: 12 }
            Btn { text: v.modelData.active ? Tr.t("Disconnect") : Tr.t("Connect"); onClicked: Net.vpn(v.modelData.active ? "vpn-down" : "vpn-up", v.modelData.uuid) }
            Btn {
                text: v.sure ? Tr.t("Confirm") : Tr.t("Forget"); variant: "danger"
                onClicked: {
                    if (v.sure) { pg.armedVpn = ""; Net.vpn("vpn-forget", v.modelData.uuid) }
                    else pg.armedVpn = v.modelData.uuid
                }
            }
        }
    }
}
