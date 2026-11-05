import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets

Rectangle {
    id: chip
    required property var profile
    readonly property bool selected: profile.id === Profiles.active
    readonly property string picture: profile.photo || (Quickshell.env("HOME") + "/.face")
    implicitWidth: row.implicitWidth + 24
    implicitHeight: 56
    radius: 28
    color: selected ? Theme.raised : m.containsMouse ? Theme.hover : "transparent"
    border.width: selected || activeFocus ? 2 : 1
    border.color: selected || activeFocus ? Theme.accent : Theme.line
    activeFocusOnTab: true
    Accessible.role: Accessible.RadioButton
    Accessible.name: profile.name
    Accessible.checked: selected
    Keys.onSpacePressed: Profiles.select(profile.id)
    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: 10
        ClippingRectangle {
            implicitWidth: 36; implicitHeight: 36; radius: 18; color: Theme.raised
            Tx { anchors.centerIn: parent; visible: photo.status !== Image.Ready; text: chip.profile.name.charAt(0).toUpperCase(); strong: true }
            Image { id: photo; anchors.fill: parent; source: "file://" + chip.picture; fillMode: Image.PreserveAspectCrop; sourceSize: Qt.size(72, 72); asynchronous: true; cache: false }
        }
        Tx { text: chip.profile.name }
    }
    MouseArea { id: m; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Profiles.select(chip.profile.id) }
}
