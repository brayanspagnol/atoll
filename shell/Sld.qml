import QtQuick
import QtQuick.Controls.Basic

Slider {
    id: s
    property string a11y: ""
    property color fill: Theme.accent
    from: 0; to: 1
    implicitHeight: 28
    Accessible.name: a11y
    background: Rectangle {
        x: s.leftPadding; y: s.topPadding + s.availableHeight / 2 - height / 2
        width: s.availableWidth; height: 6; radius: 3; color: Theme.line
        Rectangle { width: s.visualPosition * parent.width; height: parent.height; radius: 3; color: s.fill }
    }
    handle: Rectangle {
        x: s.leftPadding + s.visualPosition * (s.availableWidth - width)
        y: s.topPadding + s.availableHeight / 2 - height / 2
        width: 18; height: 18; radius: 9
        color: s.fill
        border.width: s.activeFocus ? 2 : 0
        border.color: Theme.accent
    }
}
