pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Networking

Singleton {
    readonly property var wifi: Networking.devices.values.find(d => d.type === DeviceType.Wifi) ?? null
    readonly property var wired: Networking.devices.values.find(d => d.type === DeviceType.Wired) ?? null
    readonly property var current: wifi?.networks.values.find(n => n.connected) ?? null
    readonly property string icon: wired?.connected ? "eth" : !Networking.wifiEnabled ? "wifiOff" : !current ? "wifi0" : ["wifi1", "wifi2", "wifi3", "wifi4"][Math.min(3, Math.floor(current.signalStrength * 4))]
    readonly property string status: wired?.connected ? Tr.t("Cable connected") : current ? current.name : Networking.wifiEnabled ? Tr.t("Disconnected") : Tr.t("Wi-Fi off")
}
