import QtQuick
import QtQuick.Controls.Basic

Switch {
    id: s
    property string a11y: ""
    Accessible.name: a11y
    implicitWidth: 44; implicitHeight: 26
    padding: 0
    indicator: Rectangle {
        width: 44; height: 26; radius: 13
        color: s.checked ? Theme.accent : Theme.raised
        border.width: s.activeFocus ? 2 : 1
        border.color: s.activeFocus ? Theme.ink : Theme.line
        Behavior on color { ColorAnimation { duration: Theme.fast } }
        Rectangle {
            x: s.checked ? 22 : 4; y: 4; width: 18; height: 18; radius: 9
            color: s.checked ? Theme.accentInk : Theme.muted
            Behavior on x { NumberAnimation { duration: Theme.fast; easing.type: Easing.OutCubic } }
        }
    }
    contentItem: Item {}
}
