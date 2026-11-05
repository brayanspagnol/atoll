import QtQuick
import QtQuick.Layouts

// variant: "ghost" | "solid" | "danger" | "quiet" (no border)
Rectangle {
    id: b
    property string text: ""
    property string icon: ""
    property color iconColor: fg
    property bool iconFilled: false
    property int iconSize: 20
    property string variant: "ghost"
    property bool enabledB: true
    property string a11y: text
    signal clicked()
    readonly property bool hovered: ma.containsMouse
    readonly property bool pressed: ma.pressed
    implicitHeight: 36
    implicitWidth: text ? row.implicitWidth + 28 : 44
    radius: Theme.radiusSmall
    opacity: enabledB ? 1 : 0.45
    activeFocusOnTab: enabledB
    color: {
        if (variant === "solid") return ma.pressed ? Qt.darker(Theme.accent, 1.15) : Theme.accent
        if (variant === "danger") return ma.containsMouse ? Theme.danger : "transparent"
        return ma.pressed ? Theme.line : ma.containsMouse ? Theme.raised : "transparent"
    }
    border.width: activeFocus ? 2 : variant === "quiet" ? 0 : 1
    border.color: activeFocus ? Theme.ink : variant === "solid" ? Theme.accent : variant === "danger" ? Theme.danger : Theme.line
    Behavior on color { ColorAnimation { duration: Theme.fast } }
    readonly property color fg: variant === "solid" ? Theme.accentInk : variant === "danger" ? (ma.containsMouse ? Theme.accentInk : Theme.danger) : Theme.ink
    Accessible.role: Accessible.Button
    Accessible.name: a11y
    Accessible.onPressAction: if (enabledB) clicked()
    Keys.onSpacePressed: if (enabledB) clicked()
    Keys.onReturnPressed: if (enabledB) clicked()
    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: 6
        Ic { visible: !!b.icon; name: b.icon; color: b.iconColor; size: b.text ? 18 : b.iconSize; filled: b.iconFilled }
        Tx { visible: !!b.text; text: b.text; color: b.fg; strong: true }
    }
    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: b.enabledB ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: if (b.enabledB) b.clicked()
    }
}
