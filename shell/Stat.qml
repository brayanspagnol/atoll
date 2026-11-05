import QtQuick
import QtQuick.Layouts

Rectangle {
    id: s
    property string icon: ""
    property string label: ""
    property string a11y: ""
    property string target: ""
    property bool alert: false
    signal wheel(int delta)
    implicitWidth: label ? r.implicitWidth + 20 : 44
    implicitHeight: 44
    radius: Theme.radiusSmall
    color: (Ui.open && Ui.page === target) || m.containsMouse ? Theme.raised : "transparent"
    Accessible.role: Accessible.Button
    Accessible.name: a11y + (label ? " " + label : "")
    RowLayout {
        id: r; anchors.centerIn: parent; spacing: 6
        Ic { name: s.icon; color: s.alert ? Theme.danger : Theme.ink }
        Tx { visible: !!s.label; text: s.label; mono: true; size: 13; color: s.alert ? Theme.danger : Theme.ink }
    }
    MouseArea {
        id: m; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
        onClicked: Ui.toggle(s.target)
        onWheel: e => s.wheel(e.angleDelta.y > 0 ? 1 : -1)
    }
}
