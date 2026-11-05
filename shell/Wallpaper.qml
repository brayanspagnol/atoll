import QtQuick
import Quickshell
import Quickshell.Wayland

// Drawn by the shell: replaces hyprpaper (49 SIGABRT dumps on this machine).
PanelWindow {
    required property var modelData
    screen: modelData
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Background
    WlrLayershell.namespace: "atoll-wallpaper"
    color: Theme.ground
    // The lock screen is a separate program and uses the main wallpaper on every screen.
    readonly property string path: (Cfg.v.wallpapers ?? {})[modelData.name] ?? Cfg.v.wallpaper
    Image {
        anchors.fill: parent
        visible: !!path
        source: path ? "file://" + path : ""
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: false
        sourceSize: Qt.size(parent.width, parent.height)
    }
}
