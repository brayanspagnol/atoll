import QtQuick
import QtQuick.Layouts

// Segmented picker: options = [label...], or [{label, value}...]
Rectangle {
    id: seg
    property var options: []
    property int current: 0
    signal picked(int index)
    implicitHeight: 36
    implicitWidth: r.implicitWidth + 4
    radius: Theme.radiusSmall
    color: Theme.field
    border.width: 1; border.color: Theme.line
    RowLayout {
        id: r
        anchors.fill: parent; anchors.margins: 2
        spacing: 0
        Repeater {
            model: seg.options
            Rectangle {
                required property var modelData
                required property int index
                Layout.fillHeight: true; Layout.fillWidth: true
                implicitWidth: t.implicitWidth + 20
                radius: Theme.radiusSmall - 2
                color: index === seg.current ? Theme.raised : "transparent"
                border.width: activeFocus ? 2 : 0; border.color: Theme.accent
                activeFocusOnTab: true
                Accessible.role: Accessible.RadioButton
                Accessible.name: t.text
                Accessible.checked: index === seg.current
                Keys.onSpacePressed: seg.picked(index)
                Keys.onReturnPressed: seg.picked(index)
                Tx { id: t; anchors.centerIn: parent; text: parent.modelData.label ?? parent.modelData; dim: parent.index !== seg.current }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: seg.picked(parent.index) }
            }
        }
    }
}
