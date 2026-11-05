import QtQuick
import QtQuick.Layouts

// Interactive list row. Content goes inside; set clickable=false for display rows.
Rectangle {
    id: r
    property bool clickable: true
    property bool selected: false
    property string a11y: ""
    default property alias content: inner.data
    signal clicked()
    Layout.fillWidth: true
    implicitHeight: Math.max(52, inner.implicitHeight + 12)
    radius: Theme.radiusSmall
    color: selected ? Theme.raised : (clickable && ma.containsMouse) ? Theme.hover : "transparent"
    border.width: activeFocus ? 2 : 0; border.color: Theme.accent
    activeFocusOnTab: clickable
    Accessible.role: clickable ? Accessible.Button : Accessible.Row
    Accessible.name: a11y
    Keys.onSpacePressed: if (clickable) clicked()
    Keys.onReturnPressed: if (clickable) clicked()
    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        enabled: r.clickable
        cursorShape: r.clickable ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: r.clicked()
    }
    RowLayout {
        id: inner
        anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 12
        spacing: 12
    }
}
