import QtQuick
import QtQuick.Layouts
import Quickshell
import "pins.js" as Pins

// What the island shows after the clock (Cfg.island), in order: take off, put back, reorder.
Page {
    id: pg
    group: Tr.t("Applications")
    title: Tr.t("On top")
    subtitle: Tr.t("What the island shows. Right-clicking an item on the island also takes it off.")
    readonly property var list: Cfg.island
    readonly property var rest: Pins.ids.filter(id => !list.includes(id))
    readonly property var chips: ["lagu", "weather", "media", "tray"] // as on the island: the icons after them are set apart by a line
    function name(id) { return Tr.t(Pins.item(id)?.label ?? "") }
    function save(l) { Cfg.v.island = l }

    // The island as these choices make it, with what it always has: workspaces and the clock.
    Rectangle {
        Layout.fillWidth: true; Layout.topMargin: 8
        implicitHeight: 96; radius: 22
        color: Theme.field
        Accessible.role: Accessible.Graphic
        Accessible.name: Tr.t("Island preview") + ": " + pg.list.map(pg.name).join(", ")
        Frost {
            anchors.centerIn: parent
            width: Math.min(parent.width - 24, preview.implicitWidth + 28); height: 52; radius: 26
            Behavior on width { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
            clip: true
            RowLayout {
                id: preview
                anchors.centerIn: parent
                spacing: 10
                Row {
                    spacing: 6
                    Rectangle { width: 26; height: 9; radius: 4.5; color: Theme.accent }
                    Rectangle { width: 9; height: 9; radius: 4.5; color: Theme.muted }
                }
                Rectangle { implicitWidth: 1; implicitHeight: 22; color: Theme.line }
                Tx { text: Qt.formatTime(new Date(), "HH:mm"); size: 17; strong: true }
                Row {
                    spacing: 0
                    move: Transition { NumberAnimation { property: "x"; duration: 220; easing.type: Easing.OutCubic } }
                    add: Transition {
                        NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 200 }
                        NumberAnimation { property: "scale"; from: 0.4; to: 1; duration: 240; easing.type: Easing.OutBack }
                    }
                    Repeater {
                        model: ScriptModel { values: pg.list }
                        Row {
                            id: cell
                            required property string modelData
                            required property int index
                            readonly property bool icon: !pg.chips.includes(modelData)
                            readonly property bool line: icon && (index === 0 || pg.chips.includes(pg.list[index - 1]))
                            Item { visible: cell.line; width: 21; height: 36; Rectangle { anchors.centerIn: parent; width: 1; height: 22; color: Theme.line } }
                            Item {
                                width: cell.icon ? 31 : 40; height: 36
                                Ic { anchors.centerIn: parent; name: Pins.item(cell.modelData)?.icon ?? ""; size: 17 }
                            }
                        }
                    }
                }
            }
        }
    }

    GridLayout {
        Layout.fillWidth: true
        columns: pg.bodyWidth > 640 ? 2 : 1
        columnSpacing: 24; rowSpacing: 0

        ColumnLayout {
            Layout.fillWidth: true; Layout.preferredWidth: 1; Layout.alignment: Qt.AlignTop
            spacing: 8
            Sec { title: Tr.t("On top") }
            // A ListView, so a row keeps its focus and its drag while it moves.
            ListView {
                id: onTop
                Layout.fillWidth: true
                implicitHeight: contentHeight
                interactive: false
                spacing: 6
                model: ScriptModel { values: pg.list }
                move: Transition { NumberAnimation { property: "y"; duration: 200; easing.type: Easing.OutCubic } }
                displaced: Transition { NumberAnimation { property: "y"; duration: 200; easing.type: Easing.OutCubic } }
                delegate: Rectangle {
                    id: row
                    required property string modelData
                    required property int index
                    readonly property string label: pg.name(modelData)
                    function step(by) { pg.save(Pins.move(pg.list, modelData, by)) }
                    width: ListView.view.width
                    height: 50; radius: 14
                    color: grip.pressed ? Theme.raisedHover : Theme.raised
                    border.width: activeFocus ? 2 : 0; border.color: Theme.accent
                    z: grip.pressed ? 2 : 1
                    scale: grip.pressed ? 1.02 : 1
                    Behavior on scale { NumberAnimation { duration: 120 } }
                    activeFocusOnTab: true
                    Accessible.role: Accessible.ListItem
                    Accessible.name: Tr.t("%1, %2 of %3. Alt+Up or Alt+Down moves it.").arg(label).arg(index + 1).arg(pg.list.length)
                    Keys.onUpPressed: e => { if (e.modifiers & Qt.AltModifier) step(-1); else e.accepted = false }
                    Keys.onDownPressed: e => { if (e.modifiers & Qt.AltModifier) step(1); else e.accepted = false }
                    Keys.onDeletePressed: pg.save(Pins.unpin(pg.list, modelData))
                    RowLayout {
                        anchors.fill: parent; anchors.leftMargin: 4; anchors.rightMargin: 6; spacing: 8
                        // Drag to reorder: the row under the pointer is where it goes.
                        Item {
                            implicitWidth: 32; implicitHeight: 44
                            Ic { anchors.centerIn: parent; name: "menu"; size: 16; color: Theme.muted }
                            MouseArea {
                                id: grip
                                anchors.fill: parent
                                cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                                preventStealing: true
                                onPositionChanged: m => {
                                    const y = mapToItem(onTop.contentItem, m.x, m.y).y
                                    const to = Math.max(0, Math.min(pg.list.length - 1, Math.floor(y / (row.height + onTop.spacing))))
                                    if (to !== row.index) row.step(to - row.index)
                                }
                            }
                        }
                        Ic { name: Pins.item(row.modelData)?.icon ?? ""; size: 18 }
                        Tx { text: row.label; strong: true; Layout.fillWidth: true }
                        Btn { variant: "quiet"; icon: "up"; iconSize: 16; implicitWidth: 34; implicitHeight: 34; enabledB: row.index > 0; a11y: Tr.t("Move up") + ": " + row.label; onClicked: row.step(-1) }
                        Btn { variant: "quiet"; icon: "down"; iconSize: 16; implicitWidth: 34; implicitHeight: 34; enabledB: row.index < pg.list.length - 1; a11y: Tr.t("Move down") + ": " + row.label; onClicked: row.step(1) }
                        Btn { icon: "minus"; iconSize: 16; implicitWidth: 34; implicitHeight: 34; a11y: Tr.t("Take %1 off the top").arg(row.label); onClicked: pg.save(Pins.unpin(pg.list, row.modelData)) }
                    }
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true; Layout.preferredWidth: 1; Layout.alignment: Qt.AlignTop
            spacing: 6
            Sec { title: Tr.t("To pin") }
            Tx { visible: !pg.rest.length; text: Tr.t("Everything is on top."); dim: true }
            Repeater {
                model: pg.rest
                Rectangle {
                    id: spare
                    required property string modelData
                    readonly property string label: pg.name(modelData)
                    Layout.fillWidth: true
                    implicitHeight: 50; radius: 14
                    color: Theme.raised
                    Accessible.role: Accessible.ListItem
                    Accessible.name: label
                    RowLayout {
                        anchors.fill: parent; anchors.leftMargin: 14; anchors.rightMargin: 6; spacing: 8
                        Ic { name: Pins.item(spare.modelData)?.icon ?? ""; size: 18; color: Theme.muted }
                        Tx { text: spare.label; strong: true; Layout.fillWidth: true }
                        Btn {
                            icon: "plus"; iconSize: 16; implicitWidth: 34; implicitHeight: 34
                            color: Theme.accentSoft; iconColor: Theme.accent
                            a11y: Tr.t("Pin %1").arg(spare.label)
                            onClicked: pg.save(Pins.pin(pg.list, spare.modelData))
                        }
                    }
                }
            }
        }
    }

    Btn {
        Layout.topMargin: 16
        icon: "undo"; text: Tr.t("Reset to default")
        enabledB: JSON.stringify(pg.list) !== JSON.stringify(Pins.ids)
        onClicked: pg.save(Pins.ids.slice())
    }
}
