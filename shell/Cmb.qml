import QtQuick
import QtQuick.Controls.Basic

ComboBox {
    id: c
    property string a11y: ""
    implicitHeight: 38
    implicitWidth: 260
    font.family: Theme.sans
    font.pixelSize: 15
    Accessible.name: a11y
    contentItem: Tx { leftPadding: 12; rightPadding: 28; text: c.displayText }
    indicator: Ic { x: c.width - 28; y: (c.height - 18) / 2; name: "down"; size: 18; color: Theme.muted }
    background: Rectangle {
        radius: Theme.radiusSmall
        color: Theme.field
        border.width: c.activeFocus ? 2 : 1
        border.color: c.activeFocus ? Theme.accent : Theme.line
    }
    delegate: ItemDelegate {
        id: row
        required property var modelData
        required property int index
        width: ListView.view.width
        height: 38
        highlighted: c.highlightedIndex === index
        background: Rectangle { radius: 8; color: row.highlighted ? Theme.raised : "transparent" }
        contentItem: Tx { text: row.modelData[c.textRole] ?? row.modelData }
    }
    popup: Popup {
        y: c.height + 4
        width: c.width
        height: Math.min(contentItem.implicitHeight + 12, 320)
        padding: 6
        contentItem: ListView {
            clip: true
            implicitHeight: contentHeight
            model: c.delegateModel
            currentIndex: c.highlightedIndex
        }
        background: Rectangle { radius: Theme.radiusSmall; color: Qt.rgba(13 / 255, 21 / 255, 31 / 255, 0.97); border.width: 1; border.color: Theme.lineStrong }
    }
}
