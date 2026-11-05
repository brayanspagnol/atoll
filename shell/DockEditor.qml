import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

// Launchpad for choosing the dock's apps, with the dock itself in edit mode at the bottom.
// Apps come from the system list; anything else is searched for in files.
Scope {
    id: editor
    // Outlives Ui.dockEditor by the closing animation.
    property bool alive: false
    readonly property bool isOpen: Ui.dockEditor
    onIsOpenChanged: {
        if (isOpen) { closing.stop(); alive = true }
        else { closing.restart(); Ui.dockPeek = true } // show the result on the real dock
    }
    Timer { id: closing; interval: 200; onTriggered: editor.alive = false }

    LazyLoader {
        active: editor.alive && !!Ui.screen
        PanelWindow {
            id: win
            screen: Ui.screen
            anchors { top: true; bottom: true; left: true; right: true }
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: Ui.dockEditor ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
            WlrLayershell.namespace: "atoll-central"
            color: "transparent"

            readonly property string query: search.text.trim()
            property int selected: -1
            property int dragFrom: -1
            property int dragTo: -1
            property real dragX: 0
            readonly property int slot: 80 // an icon plus the gap
            property var files: []
            property bool searching: false
            readonly property var apps: {
                const q = query.toLowerCase()
                return [...DesktopEntries.applications.values].filter(a => !a.noDisplay
                    && (!q || (a.name + " " + a.genericName + " " + a.keywords.join(" ")).toLowerCase().includes(q)))
                    .sort((a, b) => a.name.localeCompare(b.name))
            }
            function tapOutside() {
                if (selected >= 0) selected = -1
                else Ui.dockEditor = false
            }
            onQueryChanged: {
                finder.running = false
                files = []
                searching = query.length >= 2
                debounce.restart()
            }
            Timer {
                id: debounce; interval: 350
                onTriggered: if (win.query.length >= 2) {
                    finder.command = [Pins.scripts + "find-apps", win.query]
                    finder.running = true
                }
            }
            Process {
                id: finder
                stdout: StdioCollector {
                    onStreamFinished: {
                        win.files = text.split("\n").filter(Boolean)
                        win.searching = false
                    }
                }
            }
            // A window shortcut, because clicking an app takes the focus away from the search field.
            Shortcut { sequence: "Escape"; onActivated: Ui.dockEditor = false }
            Connections {
                target: Pins
                function onListChanged() { search.forceActiveFocus() }
            }

            Item {
                id: stage
                anchors.fill: parent
                Accessible.name: Tr.t("Customize dock")
                property bool shown: false
                Component.onCompleted: shown = Qt.binding(() => Ui.dockEditor)
                opacity: shown ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 170 } }

                // The blur itself comes from the layer rule in hypr/look.lua.
                Rectangle { anchors.fill: parent; color: Qt.rgba(8 / 255, 13 / 255, 20 / 255, 0.58) }
                MouseArea { anchors.fill: parent; enabled: Ui.dockEditor; onClicked: win.tapOutside() }

                ColumnLayout {
                    id: content
                    anchors { fill: parent; topMargin: 90; bottomMargin: 140 }
                    spacing: 40
                    scale: stage.shown ? 1 : 1.05
                    Behavior on scale { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

                    Rectangle {
                        Layout.alignment: Qt.AlignHCenter
                        implicitWidth: Math.min(760, win.width - 96); implicitHeight: 72; radius: 36
                        color: Qt.rgba(1, 1, 1, 0.1)
                        border.width: search.activeFocus ? 2 : 1
                        border.color: search.activeFocus ? Theme.accent : Theme.lineStrong
                        RowLayout {
                            anchors.fill: parent; anchors.leftMargin: 26; anchors.rightMargin: 26; spacing: 14
                            Ic { name: "search"; size: 28; color: Theme.muted }
                            TextInput {
                                id: search
                                Layout.fillWidth: true
                                color: Theme.ink; selectionColor: Theme.accent; selectedTextColor: Theme.accentInk
                                font.family: Theme.sans; font.pixelSize: 24
                                clip: true
                                Accessible.name: Tr.t("Search apps and files…")
                                Component.onCompleted: forceActiveFocus()
                                Keys.onReturnPressed: if (win.apps.length) Pins.toggle(win.apps[0])
                                Keys.onEnterPressed: if (win.apps.length) Pins.toggle(win.apps[0])
                                Tx { visible: !search.text; text: Tr.t("Search apps and files…"); size: 24; dim: true; anchors.verticalCenter: parent.verticalCenter }
                            }
                        }
                    }

                    GridView {
                        id: grid
                        Layout.fillWidth: true; Layout.fillHeight: true
                        Layout.leftMargin: side; Layout.rightMargin: side
                        readonly property int side: Math.max(48, win.width * 0.1)
                        readonly property int columns: Math.max(3, Math.min(8, Math.floor(width / 230)))
                        readonly property int iconSize: Math.min(176, cellWidth * 0.64)
                        clip: true
                        cellWidth: width / columns
                        cellHeight: iconSize + 100
                        boundsBehavior: Flickable.StopAtBounds
                        model: win.apps
                        ScrollBar.vertical: ScrollBar { policy: grid.contentHeight > grid.height ? ScrollBar.AlwaysOn : ScrollBar.AlwaysOff; width: 6 }
                        // The grid takes the clicks between and below its cells, so they must close the panel here too.
                        MouseArea {
                            parent: grid.contentItem
                            z: -1
                            width: grid.width
                            height: Math.max(grid.contentHeight, grid.height)
                            onClicked: win.tapOutside()
                        }

                        delegate: Item {
                            id: cell
                            required property var modelData
                            readonly property bool on: Pins.has(modelData)
                            width: GridView.view.cellWidth; height: GridView.view.cellHeight
                            activeFocusOnTab: true
                            Accessible.role: Accessible.CheckBox
                            Accessible.name: modelData.name
                            Accessible.checked: on
                            Keys.onSpacePressed: Pins.toggle(modelData)
                            Keys.onReturnPressed: Pins.toggle(modelData)
                            MouseArea {
                                id: hit
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: Pins.toggle(cell.modelData)
                            }
                            Rectangle {
                                visible: cell.activeFocus
                                anchors.fill: parent; anchors.margins: 4; radius: 20
                                color: "transparent"; border.width: 2; border.color: Theme.ink
                            }
                            Column {
                                anchors.centerIn: parent
                                spacing: 12
                                width: parent.width - 16
                                PinIcon {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    pin: ({ appIcon: cell.modelData.icon, label: cell.modelData.name })
                                    size: grid.iconSize
                                    opacity: cell.on || hit.containsMouse ? 1 : 0.86
                                    scale: hit.containsMouse ? 1.08 : 1
                                    transform: Translate { y: hit.containsMouse ? -6 : 0; Behavior on y { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } } }
                                    Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutBack; easing.overshoot: 2 } }
                                    Rectangle {
                                        visible: cell.on
                                        anchors { right: parent.right; top: parent.top; margins: -4 }
                                        width: 38; height: 38; radius: 19
                                        color: Theme.accent
                                        border.width: 2; border.color: Theme.ground
                                        Ic { anchors.centerIn: parent; name: "check"; size: 22; color: Theme.accentInk }
                                    }
                                }
                                Tx { width: parent.width; horizontalAlignment: Text.AlignHCenter; text: cell.modelData.name; size: 22 }
                            }
                        }

                        footer: ColumnLayout {
                            width: GridView.view.width
                            spacing: 6
                            ColumnLayout {
                                Layout.alignment: Qt.AlignHCenter
                                Layout.preferredWidth: Math.min(760, grid.width)
                                Layout.maximumWidth: Math.min(760, grid.width)
                                Layout.topMargin: 16
                                spacing: 6
                                visible: win.query.length >= 2
                                Sec { title: Tr.t("Found in files"); Layout.topMargin: 0 }
                                Tx { visible: win.searching; text: Tr.t("Searching files…"); dim: true }
                                Tx { visible: !win.searching && win.files.length === 0; text: Tr.t("Nothing found."); dim: true }
                                Repeater {
                                    model: win.files
                                    Rowi {
                                        id: file
                                        required property string modelData
                                        readonly property bool on: Pins.hasFile(modelData)
                                        a11y: modelData
                                        clickable: !on
                                        onClicked: Pins.addFile(modelData)
                                        ColumnLayout {
                                            Layout.fillWidth: true; spacing: 0
                                            Tx { text: file.modelData.split("/").pop(); Layout.fillWidth: true }
                                            Tx { text: file.modelData; dim: true; size: 12; mono: true; Layout.fillWidth: true; elide: Text.ElideMiddle }
                                        }
                                        Ic { visible: file.on; name: "check"; color: Theme.accent }
                                        Ic { visible: !file.on; name: "plus"; color: Theme.muted }
                                    }
                                }
                            }
                        }
                    }
                }

                // The dock in edit mode: same place as the real one, which hides while this is open.
                Frost {
                    anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 16 }
                    implicitWidth: pinRow.implicitWidth + 20
                    implicitHeight: 92
                    radius: 30
                    MouseArea { anchors.fill: parent; onClicked: win.selected = -1 }
                    RowLayout {
                        id: pinRow
                        anchors.centerIn: parent
                        spacing: 8
                        Rectangle {
                            implicitWidth: 72; implicitHeight: 72; radius: 20
                            color: Theme.accent
                            activeFocusOnTab: true
                            border.width: activeFocus ? 2 : 0; border.color: Theme.ink
                            Accessible.role: Accessible.Button
                            Accessible.name: Tr.t("Close panel")
                            Keys.onSpacePressed: Ui.dockEditor = false
                            Keys.onReturnPressed: Ui.dockEditor = false
                            Ic { anchors.centerIn: parent; name: "gear"; size: 36; color: Theme.accentInk }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Ui.dockEditor = false }
                        }
                        Rectangle { implicitWidth: 1; implicitHeight: 36; color: Theme.line; Layout.leftMargin: 4; Layout.rightMargin: 4 }
                        Tx { visible: Pins.list.length === 0; text: Tr.t("The dock is empty. Add apps from the list."); dim: true; Layout.rightMargin: 12 }
                        Repeater {
                            model: Pins.list
                            Rectangle {
                                id: pinned
                                required property var modelData
                                required property int index
                                readonly property bool sel: win.selected === index
                                readonly property bool held: win.dragFrom === index
                                // Icons stay in place while dragging and only look moved: changing the list would rebuild them mid-drag.
                                transform: Translate {
                                    x: pinned.held ? win.dragX
                                        : win.dragFrom >= 0 && pinned.index > win.dragFrom && pinned.index <= win.dragTo ? -win.slot
                                        : win.dragFrom >= 0 && pinned.index < win.dragFrom && pinned.index >= win.dragTo ? win.slot : 0
                                    Behavior on x { enabled: !pinned.held && win.dragFrom >= 0; NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
                                }
                                z: held ? 1 : 0
                                implicitWidth: 72; implicitHeight: 72; radius: 20
                                color: sel ? Qt.rgba(140 / 255, 200 / 255, 245 / 255, 0.25) : pm.containsMouse ? Qt.rgba(1, 1, 1, 0.2) : Theme.raised
                                border.width: sel || activeFocus ? 2 : 0
                                border.color: activeFocus ? Theme.ink : Theme.accent
                                activeFocusOnTab: true
                                Accessible.role: Accessible.Button
                                Accessible.name: Tr.t(modelData.label)
                                Keys.onSpacePressed: win.selected = sel ? -1 : index
                                Keys.onReturnPressed: win.selected = sel ? -1 : index
                                PinIcon { anchors.centerIn: parent; pin: pinned.modelData }
                                MouseArea {
                                    id: pm
                                    anchors.fill: parent; hoverEnabled: true; cursorShape: pinned.held ? Qt.ClosedHandCursor : Qt.PointingHandCursor
                                    preventStealing: true
                                    property real startX: 0
                                    // Measured on the row, because this area moves with the icon.
                                    function rowX(mouse) { return mapToItem(pinRow, mouse.x, 0).x }
                                    onPressed: mouse => startX = rowX(mouse)
                                    onPositionChanged: mouse => {
                                        if (!pressed) return
                                        const dx = rowX(mouse) - startX
                                        if (!pinned.held && Math.abs(dx) < 8) return
                                        win.selected = -1
                                        win.dragFrom = pinned.index
                                        win.dragX = dx
                                        win.dragTo = Math.max(0, Math.min(Pins.list.length - 1, pinned.index + Math.round(dx / win.slot)))
                                    }
                                    onReleased: {
                                        if (win.dragFrom < 0) return
                                        const from = win.dragFrom, to = win.dragTo
                                        win.dragFrom = -1; win.dragX = 0
                                        justDragged = true
                                        Pins.moveTo(from, to)
                                    }
                                    property bool justDragged: false
                                    onClicked: {
                                        if (justDragged) { justDragged = false; return }
                                        win.selected = pinned.sel ? -1 : pinned.index
                                    }
                                }
                                Rectangle {
                                    visible: pinned.sel
                                    anchors { bottom: parent.top; bottomMargin: 14; horizontalCenter: parent.horizontalCenter }
                                    implicitWidth: actions.implicitWidth + 12; implicitHeight: actions.implicitHeight + 12
                                    radius: 16
                                    color: Qt.rgba(10 / 255, 16 / 255, 24 / 255, 0.92)
                                    border.width: 1; border.color: Theme.lineStrong
                                    RowLayout {
                                        id: actions
                                        anchors.centerIn: parent
                                        spacing: 4
                                        Btn {
                                            variant: "quiet"; icon: "left"; implicitHeight: 44
                                            a11y: Tr.t("Move left"); enabledB: pinned.index > 0
                                            onClicked: { win.selected = pinned.index - 1; Pins.move(pinned.index, -1) }
                                        }
                                        Btn {
                                            variant: "quiet"; icon: "x"; iconColor: Theme.danger; implicitHeight: 44
                                            a11y: Tr.t("Remove %1").arg(Tr.t(pinned.modelData.label))
                                            onClicked: { const i = pinned.index; win.selected = -1; Pins.remove(i) }
                                        }
                                        Btn {
                                            variant: "quiet"; icon: "right"; implicitHeight: 44
                                            a11y: Tr.t("Move right"); enabledB: pinned.index < Pins.list.length - 1
                                            onClicked: { win.selected = pinned.index + 1; Pins.move(pinned.index, 1) }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
