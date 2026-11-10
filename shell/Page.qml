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
        Tx { text: p.title; visible: !!text; size: 30; strong: true; width: parent.width; Accessible.role: Accessible.Heading; Accessible.name: p.title }
        Tx { text: p.subtitle; dim: true; visible: !!text; width: parent.width }
    }
    ColumnLayout {
        id: col
        y: head.y + head.height + 8; width: p.width - 14
        spacing: 8
    }

    // Scrolls to the item the control center's search picked, and marks it for a moment.
    function seek(item, text) {
        if (!item || !item.visible) return null
        if (item.text === text || item.title === text || item.label === text) return item
        for (const c of item.children) { const hit = seek(c, text); if (hit) return hit }
        return null
    }
    function reveal() {
        const hit = seek(col, Ui.revealLabel)
        if (!hit) return
        // A row's own label sits inside it: mark the whole row.
        const box = hit.parent && hit.parent !== col && hit.parent.width > hit.width * 1.5 ? hit.parent : hit
        const at = box.mapToItem(p.contentItem, 0, 0)
        scroll.to = Math.max(0, Math.min(p.contentHeight - p.height, at.y - 60))
        scroll.restart()
        mark.x = 0; mark.y = at.y - 6; mark.width = col.width; mark.height = box.height + 12
        pulse.restart()
    }
    NumberAnimation { id: scroll; target: p; property: "contentY"; duration: 320; easing.type: Easing.OutCubic }
    Rectangle {
        id: mark
        parent: p.contentItem
        radius: 12; opacity: 0
        color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.18)
        border.width: 1.5; border.color: Theme.accent
        SequentialAnimation on opacity {
            id: pulse; running: false
            PauseAnimation { duration: 200 }
            NumberAnimation { to: 1; duration: 180 }
            PauseAnimation { duration: 900 }
            NumberAnimation { to: 0; duration: 500 }
        }
    }
    // Waits for the page to lay out, and for the screen change animation.
    Timer { id: later; interval: 320; onTriggered: { p.reveal(); Ui.revealLabel = "" } }
    Component.onCompleted: if (Ui.revealLabel) later.restart()
    Connections { target: Ui; function onRevealCountChanged() { later.restart() } }
}
