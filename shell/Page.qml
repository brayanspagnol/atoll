import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts

Flickable {
    id: p
    property string title: ""
    property string subtitle: ""
    default property alias body: col.data
    readonly property int bodyWidth: col.width
    clip: true
    contentWidth: width
    contentHeight: col.y + col.implicitHeight + 24
    boundsBehavior: Flickable.StopAtBounds
    ScrollBar.vertical: ScrollBar { policy: p.contentHeight > p.height ? ScrollBar.AlwaysOn : ScrollBar.AlwaysOff; width: 6 }
    Column {
        id: head
        width: p.width - 60; spacing: 4
        Tx { text: p.title; size: 30; strong: true; width: parent.width; Accessible.role: Accessible.Heading; Accessible.name: p.title }
        Tx { text: p.subtitle; dim: true; visible: !!text; width: parent.width }
    }
    ColumnLayout {
        id: col
        y: head.y + head.height + 8; width: p.width - 14
        spacing: 8
    }
}
