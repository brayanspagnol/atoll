import QtQuick
import Quickshell
import Quickshell.Widgets

// A pinned app's icon: a shell glyph, the app's own icon, or its first letter when it has neither.
Item {
    id: root
    required property var pin
    property int size: 40
    readonly property string source: pin.appIcon ? Quickshell.iconPath(pin.appIcon, true) : ""
    implicitWidth: size; implicitHeight: size
    Ic { anchors.centerIn: parent; visible: !!root.pin.icon; name: root.pin.icon ?? ""; size: root.size }
    IconImage { anchors.centerIn: parent; visible: !root.pin.icon && !!root.source; implicitSize: root.size; source: root.source }
    Tx { anchors.centerIn: parent; visible: !root.pin.icon && !root.source; text: (root.pin.label || "?").charAt(0).toUpperCase(); size: root.size * 0.75; strong: true }
}
