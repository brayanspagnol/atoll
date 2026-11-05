import QtQuick
import QtQuick.Controls.Basic

TextField {
    id: f
    implicitHeight: 38
    color: Theme.ink
    placeholderTextColor: Theme.muted
    selectionColor: Theme.accent
    selectedTextColor: Theme.accentInk
    font.family: Theme.sans
    font.pixelSize: 15
    leftPadding: 10; rightPadding: 10
    background: Rectangle {
        radius: Theme.radiusSmall
        color: Theme.field
        border.width: f.activeFocus ? 2 : 1
        border.color: f.activeFocus ? Theme.accent : Theme.line
    }
}
