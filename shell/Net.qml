pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Networking
import "parse.js" as P

Singleton {
    id: root
    readonly property string script: Quickshell.env("HOME") + "/.local/share/atoll/scripts/net"
    property var vpns: []
    property string vpnBusy: ""
    property string vpnErr: ""
    property string addState: "" // "", "saving" or "connecting"
    property string addErr: ""

    function refreshVpns() { vpnList.running = true }
    function vpn(action, uuid) {
        vpnErr = ""
        vpnBusy = uuid
        run([action, uuid], "", () => { vpnBusy = ""; refreshVpns() }, reason => { vpnBusy = ""; vpnErr = reason; refreshVpns() })
    }
    // The picker is a normal window, and the control center would cover it, so it closes meanwhile.
    function importVpn() {
        vpnErr = ""
        Ui.open = false
        vpnPicker.running = true
    }
    // args come from the form; the secret goes to the script on stdin.
    function addWifi(args, secret) {
        addErr = ""
        addState = "saving"
        run(args, secret, uuid => {
            addState = "connecting"
            run(["connect-new", uuid], "", () => { addState = ""; refreshVpns() }, () => { addErr = Tr.t("Couldn't connect. Check the name and the password."); addState = "" })
        }, reason => { addErr = reason; addState = "" })
    }
    // One at a time: a VPN can take 30 seconds, and a second request must not take over the first one's callbacks.
    property var queue: []
    function run(args, secret, done, failed) {
        queue = queue.concat([{ args, secret, done, failed }])
        if (!task.running) next()
    }
    function next() {
        if (!queue.length) return
        const job = queue[0]
        queue = queue.slice(1)
        task.secret = job.secret
        task.done = job.done
        task.failed = job.failed
        task.command = [script].concat(job.args)
        task.running = true
    }
    Process {
        id: task
        property string secret: ""
        property var done: null
        property var failed: null
        stdinEnabled: true
        onStarted: { if (secret) write(secret + "\n"); secret = "" }
        stdout: StdioCollector { id: taskOut }
        stderr: StdioCollector { id: taskErr }
        onExited: code => {
            const then = code === 0 ? done : failed
            const result = code === 0 ? taskOut.text.trim() : taskErr.text.trim().split("\n").pop() || Tr.t("Something went wrong.")
            // A callback may queue more work, so the next job starts after it.
            if (then) then(result)
            root.next()
        }
    }
    Process {
        id: vpnList
        command: ["nmcli", "-t", "-f", "NAME,UUID,TYPE,ACTIVE", "connection", "show"]
        stderr: StdioCollector {}
        stdout: StdioCollector {
            onStreamFinished: root.vpns = P.nmcliRows(text).filter(r => r[2] === "vpn" || r[2] === "wireguard").map(r => ({ name: r[0], uuid: r[1], type: r[2], active: r[3] === "yes" }))
        }
    }
    Process {
        id: vpnPicker
        command: ["zenity", "--file-selection", "--title=" + Tr.t("Choose a VPN file"), "--filename=" + Quickshell.env("HOME") + "/", "--file-filter=VPN | *.conf *.ovpn"]
        stdout: StdioCollector { id: picked }
        onExited: {
            Ui.show("rede")
            const file = picked.text.trim()
            if (file) root.run(["vpn-import", file], "", () => root.refreshVpns(), reason => { root.vpnErr = reason })
        }
    }
    readonly property var wifi: Networking.devices.values.find(d => d.type === DeviceType.Wifi) ?? null
    readonly property var wired: Networking.devices.values.find(d => d.type === DeviceType.Wired) ?? null
    readonly property var current: wifi?.networks.values.find(n => n.connected) ?? null
    readonly property string icon: wired?.connected ? "eth" : !Networking.wifiEnabled ? "wifiOff" : !current ? "wifi0" : ["wifi1", "wifi2", "wifi3", "wifi4"][Math.min(3, Math.floor(current.signalStrength * 4))]
    readonly property string status: wired?.connected ? Tr.t("Cable connected") : current ? current.name : Networking.wifiEnabled ? Tr.t("Disconnected") : Tr.t("Wi-Fi off")
}
