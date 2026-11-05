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
    readonly property bool tls: Net.formKind === 2 && Net.formEap === 2
    property string armedVpn: ""
    Timer { running: pg.armedVpn !== ""; interval: 5000; onTriggered: pg.armedVpn = "" }
    Timer { interval: 5000; running: true; repeat: true; triggeredOnStart: true; onTriggered: Net.refreshVpns() }
    function openForm(name, hidden, kind) {
        Net.addErr = ""
        Net.formOpen = true; Net.formHidden = hidden; Net.formKind = kind
        Net.formSsid = name; formPass.text = ""; Net.formUser = ""; Net.formDomain = ""
        Net.formCert = ""; Net.formKey = ""; Net.formCa = ""
        toForm.restart()
        if (hidden) formSsid.forceActiveFocus(); else formUser.forceActiveFocus()
    }

    // The form sits below the list of networks, and the layout needs a moment to place it.
    Timer { id: toForm; interval: 100; onTriggered: pg.contentY = Math.max(0, pg.contentHeight - pg.height) }
    Component.onCompleted: if (Net.formOpen) toForm.start()
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


    component FileField: RowLayout {
        id: ff
        property string label: ""
        property string field: "" // the Net property holding the path
        visible: pg.tls
        Layout.fillWidth: true; spacing: 8
        Fld {
            Layout.fillWidth: true; placeholderText: ff.label; Accessible.name: ff.label
            text: Net[ff.field]
            onTextEdited: Net[ff.field] = text
        }
        Btn {
            text: Tr.t("Choose…"); a11y: ff.label + ": " + text
            // Cleared even if the page survives the picker, so what the user sees is always the same.
            onClicked: { formPass.text = ""; Net.pickFile(ff.field, ff.label) }
        }
    }

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
    Btn { visible: Networking.wifiEnabled && !Net.formOpen; text: Tr.t("Other network…"); onClicked: pg.openForm("", true, 1) }
    ColumnLayout {
        visible: Net.formOpen
        Layout.fillWidth: true; spacing: 8
        Sec { title: Net.formHidden ? Tr.t("Other network") : Tr.t("Enterprise network") }
        Fld {
            id: formSsid
            visible: Net.formHidden
            Layout.fillWidth: true; placeholderText: Tr.t("Network name"); Accessible.name: Tr.t("Network name")
            text: Net.formSsid
            onTextEdited: Net.formSsid = text
        }
        Tx { visible: !Net.formHidden; text: Net.formSsid; strong: true }
        Seg {
            visible: Net.formHidden
            options: [Tr.t("No password"), Tr.t("Password"), Tr.t("Enterprise (802.1X)")]
            current: Net.formKind
            onPicked: i => Net.formKind = i
        }
        Seg { visible: Net.formKind === 2; options: ["PEAP", "TTLS", "TLS"]; current: Net.formEap; onPicked: i => Net.formEap = i }
        Fld { id: formUser; visible: Net.formKind === 2; Layout.fillWidth: true; placeholderText: Tr.t("User"); Accessible.name: Tr.t("User"); text: Net.formUser; onTextEdited: Net.formUser = text }
        FileField { label: Tr.t("Client certificate"); field: "formCert" }
        FileField { label: Tr.t("Private key"); field: "formKey" }
        Fld {
            id: formPass
            visible: Net.formKind !== 0
            Layout.fillWidth: true
            placeholderText: pg.tls ? Tr.t("Key password (if it has one)") : Tr.t("Password")
            Accessible.name: placeholderText
            echoMode: TextInput.Password
            onAccepted: if (formGo.enabledB) formGo.clicked()
        }
        FileField { label: Tr.t("CA certificate (optional)"); field: "formCa" }
        Fld { visible: Net.formKind === 2; Layout.fillWidth: true; placeholderText: Tr.t("Server domain (optional)"); Accessible.name: Tr.t("Server domain (optional)"); text: Net.formDomain; onTextEdited: Net.formDomain = text }
        Tx {
            visible: Net.formKind === 2 && (!pg.tls || (!Net.formCa.trim() && !Net.formDomain.trim()))
            text: pg.tls ? Tr.t("Without a CA certificate or a domain, the server's identity isn't checked, and a fake network could pretend to be this one.") : Tr.t("Without a domain, the server's identity isn't checked, and a fake network could capture your password.")
            color: Theme.warn; size: 13; wrapMode: Text.Wrap; Layout.fillWidth: true
        }
        Tx { visible: !!Net.addState; text: Net.addState === "saving" ? Tr.t("Saving…") : Tr.t("Connecting…"); dim: true }
        Tx { visible: !!Net.addErr; text: Net.addErr; color: Theme.danger; wrapMode: Text.Wrap; Layout.fillWidth: true }
        RowLayout {
            spacing: 8
            Btn {
                id: formGo
                text: Tr.t("Connect"); variant: "solid"
                enabledB: !Net.addState && Net.formSsid.trim().length > 0
                    && (Net.formKind === 0 || (Net.formKind === 1 && formPass.text.length >= 8)
                        || (Net.formKind === 2 && Net.formUser.trim().length > 0
                            && (pg.tls ? Net.formCert.trim().length > 0 && Net.formKey.trim().length > 0 : formPass.text.length > 0)))
                onClicked: {
                    const hidden = Net.formHidden ? "yes" : "no", ssid = Net.formSsid.trim(), user = Net.formUser.trim(), domain = Net.formDomain.trim()
                    if (pg.tls) Net.addWifi(["wifi-eap", ssid, hidden, "tls", user, Net.formCert.trim(), Net.formKey.trim(), Net.formCa.trim(), domain], formPass.text)
                    else if (Net.formKind === 2) Net.addWifi(["wifi-eap", ssid, hidden, Net.formEap === 0 ? "peap" : "ttls", user].concat(domain ? [domain] : []), formPass.text)
                    else Net.addWifi(["wifi", ssid, hidden, Net.formKind === 1 ? "psk" : "open"], Net.formKind === 1 ? formPass.text : "")
                    formPass.text = ""
                }
            }
            Btn { text: Tr.t("Cancel"); onClicked: Net.formOpen = false }
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
