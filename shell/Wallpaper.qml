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
    Image {
        anchors.fill: parent
        visible: !!Cfg.v.wallpaper
        source: Cfg.v.wallpaper ? "file://" + Cfg.v.wallpaper : ""
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: false
        sourceSize: Qt.size(parent.width, parent.height)
    }
}
