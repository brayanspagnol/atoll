import QtQuick

// Floating glass. The blur comes from the Hyprland layer rule in hypr/look.lua; this only adds tint and sheen.
Rectangle {
    id: frost
    radius: Theme.radius
    color: Theme.surface
    Rectangle {
        anchors.fill: parent
        anchors.margins: 1
        radius: frost.radius - 1
        gradient: Gradient {
            GradientStop { position: 0; color: Theme.sheen }
            GradientStop { position: 0.45; color: Qt.rgba(1, 1, 1, 0) } // white so the fade stays white
        }
    }
}
