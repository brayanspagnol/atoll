import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets

PanelWindow {
    id: win
    required property var modelData
    screen: modelData
    anchors.bottom: true
    implicitWidth: pill.implicitWidth + 200
    implicitHeight: 96
    exclusionMode: ExclusionMode.Ignore // hidden by default: windows keep the full height
    color: "transparent"
    WlrLayershell.namespace: "atoll-dock"
    // Hidden, only the strip at the bottom edge takes input, inside the window gap.
    mask: Region { item: win.open ? pillArea : edge }

    readonly property bool peek: Ui.dockPeek && Ui.screen === modelData
    readonly property bool wanted: hover.hovered || peek
    property bool open: false
    onWantedChanged: {
        if (wanted) { hideTimer.stop(); open = true }
        else hideTimer.restart()
    }
    onOpenChanged: if (!open) tipWin.visible = false
    Timer { id: hideTimer; interval: 400; onTriggered: win.open = false }

    readonly property var pinned: Cfg.v.dock
    readonly property var windows: ToplevelManager.toplevels.values
    readonly property var extras: {
        const known = [].concat(...pinned.map(p => p.ids)), seen = new Set(), out = []
        for (const t of windows) {
            const id = t.appId.toLowerCase()
            if (!known.includes(id) && !seen.has(id)) { seen.add(id); out.push(t) }
        }
        return out
    }
    function windowsOf(ids) { return windows.filter(t => ids.includes(t.appId.toLowerCase())) }
    // Repeated clicks walk through an app's windows.
    function focusOrLaunch(ws, cmd) {
        if (!ws.length) return Ui.sh(cmd)
        const i = ws.findIndex(t => t.activated)
        ws[(i + 1) % ws.length].activate()
    }

    component Tile: Rectangle {
        id: tile
        property string label: ""
        property bool running: false
        property bool active: false
        default property alias content: slot.data
        signal clicked()
        implicitWidth: 60; implicitHeight: 60; radius: 16
        color: m.pressed ? Theme.lineStrong : m.containsMouse || active ? Qt.rgba(1, 1, 1, 0.16) : Theme.raised
        border.width: activeFocus ? 2 : 0; border.color: Theme.ink
        activeFocusOnTab: true
        Accessible.role: Accessible.Button
        Accessible.name: label + (running ? ", aberto" : "")
        Keys.onSpacePressed: clicked()
        Keys.onReturnPressed: clicked()
        Item { id: slot; anchors.centerIn: parent; anchors.verticalCenterOffset: -3; width: 26; height: 26 }
        Rectangle { visible: tile.running; anchors { bottom: parent.bottom; bottomMargin: 6; horizontalCenter: parent.horizontalCenter } width: 5; height: 5; radius: 3; color: Theme.accent }
        MouseArea {
            id: m; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
            onClicked: tile.clicked()
            onContainsMouseChanged: {
                if (containsMouse) { tip.text = tile.label; tip.x0 = tile.mapToItem(null, tile.width / 2, 0).x; tipWin.visible = true }
                else if (tip.text === tile.label) tipWin.visible = false
            }
        }
    }

    Item {
        anchors.fill: parent
        // On the pill's parent: a handler behind the tiles loses hover as soon as a tile takes it.
        HoverHandler { id: hover }
        Item { id: edge; anchors.bottom: parent.bottom; width: parent.width; height: 8 }
        Item { id: pillArea; anchors.fill: parent }

        Frost {
            id: pill
            property real offset: win.open ? 0 : 96
            Behavior on offset { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
            visible: offset < 96
            transform: Translate { y: pill.offset }
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 16
            implicitWidth: row.implicitWidth + 20
            implicitHeight: 80
            radius: 26
            RowLayout {
                id: row
                anchors.centerIn: parent
                spacing: 8
                Tile {
                    label: "Aplicativos e comandos"; color: Theme.accent
                    onClicked: { Ui.open = false; Ui.launcher = !Ui.launcher }
                    Ic { anchors.centerIn: parent; anchors.verticalCenterOffset: 3; name: "search"; size: 26; color: Theme.accentInk }
                }
                Repeater {
                    model: win.pinned
                    Tile {
                        id: pt
                        required property var modelData
                        readonly property var ws: win.windowsOf(modelData.ids)
                        label: modelData.label
                        running: ws.length > 0
                        active: ws.some(t => t.activated)
                        onClicked: win.focusOrLaunch(ws, modelData.cmd)
                        Ic { anchors.centerIn: parent; name: pt.modelData.icon; size: 26 }
                    }
                }
                Rectangle { visible: win.extras.length > 0; implicitWidth: 1; implicitHeight: 36; color: Theme.line }
                Repeater {
                    model: win.extras
                    Tile {
                        id: et
                        required property var modelData
                        readonly property string appId: modelData.appId
                        readonly property var entry: DesktopEntries.heuristicLookup(appId)
                        readonly property var ws: win.windows.filter(t => t.appId === appId)
                        label: entry?.name ?? modelData.title
                        running: true
                        active: ws.some(t => t.activated)
                        onClicked: win.focusOrLaunch(ws, "")
                        IconImage { visible: !!et.entry?.icon; anchors.centerIn: parent; implicitSize: 26; source: et.entry?.icon ? Quickshell.iconPath(et.entry.icon, true) : "" }
                        Tx { visible: !et.entry?.icon; anchors.centerIn: parent; text: et.appId.charAt(0).toUpperCase(); size: 20; strong: true }
                    }
                }
            }
        }
    }

    PopupWindow {
        id: tipWin
        anchor.window: win
        anchor.rect.x: tip.x0 - width / 2
        anchor.rect.y: -40
        implicitWidth: tipT.implicitWidth + 20
        implicitHeight: 30
        color: "transparent"
        Rectangle {
            id: tip
            property string text: ""
            property real x0: 0
            anchors.fill: parent; radius: 8; color: Qt.rgba(13 / 255, 21 / 255, 31 / 255, 0.94); border.width: 1; border.color: Theme.lineStrong
            Tx { id: tipT; anchors.centerIn: parent; text: tip.text; size: 13 }
        }
    }
}
