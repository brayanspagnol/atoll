import QtQuick
import QtQuick.Layouts

ColumnLayout {
    property string title: ""
    default property alias extra: right.data
    Layout.fillWidth: true
    Layout.topMargin: 18
    spacing: 10
    RowLayout {
        Layout.fillWidth: true
        Layout.minimumHeight: 36
        Tx { text: title; size: 13; strong: true; dim: true; font.letterSpacing: 0.8; font.capitalization: Font.AllUppercase; Layout.fillWidth: true; Accessible.role: Accessible.Heading; Accessible.name: title }
        RowLayout { id: right; spacing: 8 }
    }
    Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Theme.line }
}
