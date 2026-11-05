import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets

// Workspaces in a strip, with the current one's windows spread out below. Super+O.
LazyLoader {
    active: Ui.overview && !!Ui.screen
    PanelWindow {
        id: win
        screen: Ui.screen
        anchors { top: true; bottom: true; left: true; right: true }
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        WlrLayershell.namespace: "atoll-overview"
        color: Theme.ground

        readonly property var mon: Hyprland.monitorFor(screen)
        readonly property real monW: (mon?.width ?? 1920) / (mon?.scale || 1)
        readonly property real monH: (mon?.height ?? 1080) / (mon?.scale || 1)
        readonly property int shown: mon?.activeWorkspace?.id ?? 1
        readonly property string wallpaper: (Cfg.v.wallpapers ?? {})[screen?.name] ?? Cfg.v.wallpaper
        property var clients: []
        property int dropId: -1 // the workspace under a dragged window

        // Workspaces of this screen, plus the free numbers up to 8, without those another screen holds.
        readonly property var slots: {
            const elsewhere = new Set(), here = new Set([1, 2, 3, 4, 5, 6, 7, 8])
            for (const w of Hyprland.workspaces.values) {
                if (w.id <= 0) continue
                if (w.monitor === mon) here.add(w.id)
                else elsewhere.add(w.id)
            }
            return [...here].filter(id => !elsewhere.has(id)).sort((a, b) => a - b)
        }
        function windowsOf(id) {
            return clients.filter(c => c.workspace.id === id && c.mapped && !c.hidden && c.monitor === mon?.id)
        }
        function toplevelOf(c) {
            const bare = c.address.replace(/^0x/, "")
            return Hyprland.toplevels.values.find(t => t.address === bare)?.wayland ?? null
        }
        function goTo(id) { Hyprland.dispatch(`hl.dsp.focus({ workspace = ${id} })`) }
        function focusWindow(c) {
            Hyprland.dispatch(`hl.dsp.focus({ window = "address:${c.address}" })`)
            Ui.overview = false
        }
        function moveWindow(c, id) {
            Hyprland.dispatch(`hl.dsp.window.move({ workspace = ${id}, follow = false, window = "address:${c.address}" })`)
            refresh.restart()
        }
        function step(delta) {
            const i = slots.indexOf(shown)
            goTo(slots[Math.max(0, Math.min(slots.length - 1, i + delta))])
        }

        Process {
            id: clientList
            running: true
            command: ["hyprctl", "-j", "clients"]
            stdout: StdioCollector { onStreamFinished: { try { win.clients = JSON.parse(text) } catch (e) { win.clients = [] } } }
        }
        Timer { id: refresh; interval: 120; onTriggered: { clientList.running = false; clientList.running = true } }
        Connections { target: Hyprland; function onRawEvent() { refresh.restart() } }
        Component.onCompleted: Hyprland.refreshToplevels()

        // One window, in the same place it has on the screen. k scales screen pixels to this view.
        component Mini: ClippingRectangle {
            id: mini
            required property var modelData
            property real k: 1
            property bool live: false
            x: (modelData.at[0] - (win.mon?.x ?? 0)) * k
            y: (modelData.at[1] - (win.mon?.y ?? 0)) * k
            width: modelData.size[0] * k
            height: modelData.size[1] * k
            radius: Math.max(4, 16 * k)
            color: Theme.raised
            readonly property var entry: DesktopEntries.heuristicLookup(modelData.class)
            IconImage {
                anchors.centerIn: parent
                implicitSize: Math.min(parent.width, parent.height) * 0.45
                source: mini.entry?.icon ? Quickshell.iconPath(mini.entry.icon, true) : ""
            }
            ScreencopyView {
                anchors.fill: parent
                captureSource: win.toplevelOf(mini.modelData)
                live: mini.live
            }
        }

        Image {
            anchors.fill: parent
            visible: !!win.wallpaper
            source: win.wallpaper ? "file://" + win.wallpaper : ""
            fillMode: Image.PreserveAspectCrop
            // Decoded very small and stretched: a blur for free.
            sourceSize: Qt.size(480, 270)
            asynchronous: true
            cache: false
        }
        Rectangle { anchors.fill: parent; color: Qt.rgba(8 / 255, 14 / 255, 22 / 255, 0.55) }
        MouseArea { anchors.fill: parent; onClicked: Ui.overview = false }

        Item {
            id: stage
            anchors.fill: parent
            focus: true
            NumberAnimation on opacity { from: 0; to: 1; duration: 140; easing.type: Easing.OutCubic }
            Keys.onEscapePressed: Ui.overview = false
            Keys.onReturnPressed: Ui.overview = false
            Keys.onLeftPressed: win.step(-1)
            Keys.onRightPressed: win.step(1)
            Keys.onPressed: event => {
                const n = event.key - Qt.Key_0
                if (n >= 1 && n <= 9 && win.slots.includes(n)) { win.goTo(n); Ui.overview = false; event.accepted = true }
            }

            Rectangle {
                anchors { top: parent.top; topMargin: 14; horizontalCenter: parent.horizontalCenter }
                implicitWidth: clockRow.implicitWidth + 36; implicitHeight: 46; radius: 23
                color: Qt.rgba(12 / 255, 18 / 255, 26 / 255, 0.62)
                border.width: 1; border.color: Theme.lineStrong
                SystemClock { id: clock; precision: SystemClock.Minutes }
                RowLayout {
                    id: clockRow
                    anchors.centerIn: parent; spacing: 12
                    Tx { text: Qt.formatTime(clock.date, "hh:mm"); strong: true; size: 17 }
                    Tx { text: Tr.date(clock.date, "ddd, MMM d").replace(/\./g, ""); dim: true }
                }
            }

            RowLayout {
                id: strip
                anchors { left: parent.left; right: parent.right; top: parent.top; topMargin: 76; leftMargin: 60; rightMargin: 60 }
                spacing: 12
                Repeater {
                    model: win.slots
                    Rectangle {
                        id: thumb
                        required property int modelData
                        readonly property var windows: win.windowsOf(modelData)
                        readonly property bool here: win.shown === modelData
                        readonly property bool target: win.dropId === modelData
                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
                        Layout.preferredHeight: width * win.monH / win.monW
                        radius: 14
                        clip: true
                        color: Qt.rgba(1, 1, 1, 0.08)
                        border.width: here || target || activeFocus ? 2 : 1
                        border.color: activeFocus ? Theme.ink : here || target ? Theme.accent : Theme.lineStrong
                        activeFocusOnTab: true
                        Accessible.role: Accessible.Button
                        Accessible.name: Tr.t("Workspace %1").arg(modelData) + (windows.length ? "" : ", " + Tr.t("empty"))
                        Keys.onSpacePressed: win.goTo(modelData)
                        Keys.onReturnPressed: { win.goTo(modelData); Ui.overview = false }
                        Repeater {
                            model: thumb.windows
                            Mini { k: thumb.width / win.monW }
                        }
                        Tx { visible: thumb.windows.length === 0; anchors.centerIn: parent; text: Tr.t("Empty"); dim: true; size: 13 }
                        Rectangle {
                            anchors { left: parent.left; bottom: parent.bottom; margins: 8 }
                            implicitWidth: Math.max(26, number.implicitWidth + 12); implicitHeight: 26; radius: 13
                            color: thumb.here ? Theme.accent : Qt.rgba(8 / 255, 14 / 255, 22 / 255, 0.82)
                            Tx { id: number; anchors.centerIn: parent; text: thumb.modelData; mono: true; strong: true; size: 13; color: thumb.here ? Theme.accentInk : Theme.ink }
                        }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: win.goTo(thumb.modelData) }
                    }
                }
            }

            Item {
                id: area
                anchors { left: parent.left; right: parent.right; top: strip.bottom; bottom: hints.top; margins: 60; topMargin: 24; bottomMargin: 18 }
                readonly property real k: Math.min(width / win.monW, height / win.monH)
                readonly property real ox: (width - win.monW * k) / 2
                readonly property real oy: (height - win.monH * k) / 2
                Tx { visible: win.windowsOf(win.shown).length === 0; anchors.centerIn: parent; text: Tr.t("No windows on this workspace"); dim: true; size: 18 }
                Repeater {
                    model: win.windowsOf(win.shown)
                    Item {
                        id: spread
                        required property var modelData
                        x: area.ox + (modelData.at[0] - (win.mon?.x ?? 0)) * area.k
                        y: area.oy + (modelData.at[1] - (win.mon?.y ?? 0)) * area.k
                        width: modelData.size[0] * area.k
                        height: modelData.size[1] * area.k
                        activeFocusOnTab: true
                        Accessible.role: Accessible.Button
                        Accessible.name: modelData.title
                        Keys.onReturnPressed: win.focusWindow(modelData)
                        Keys.onSpacePressed: win.focusWindow(modelData)
                        Mini { modelData: spread.modelData; k: area.k; x: 0; y: 0; live: true }
                        Rectangle {
                            anchors.fill: parent
                            radius: Math.max(4, 16 * area.k)
                            color: "transparent"
                            border.width: pick.containsMouse || spread.activeFocus ? 2 : 1
                            border.color: spread.activeFocus ? Theme.ink : pick.containsMouse ? Theme.accent : Theme.lineStrong
                        }
                        Rectangle {
                            anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: 8 }
                            implicitHeight: 34; radius: 12
                            color: Qt.rgba(8 / 255, 14 / 255, 22 / 255, 0.82)
                            Tx { anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 12; text: spread.modelData.title || spread.modelData.class; size: 14 }
                        }
                        MouseArea {
                            id: pick
                            anchors.fill: parent; hoverEnabled: true
                            cursorShape: pressed && ghost.visible ? Qt.ClosedHandCursor : Qt.PointingHandCursor
                            preventStealing: true
                            property point start
                            function inStage(mouse) { return mapToItem(stage, mouse.x, mouse.y) }
                            function thumbAt(p) {
                                const local = stage.mapToItem(strip, p.x, p.y)
                                const child = strip.childAt(local.x, local.y)
                                return child && child.modelData !== undefined ? child.modelData : -1
                            }
                            onPressed: mouse => start = inStage(mouse)
                            onPositionChanged: mouse => {
                                if (!pressed) return
                                const p = inStage(mouse)
                                if (!ghost.visible && Math.hypot(p.x - start.x, p.y - start.y) < 10) return
                                ghost.title = spread.modelData.title || spread.modelData.class
                                ghost.x = p.x - ghost.width / 2
                                ghost.y = p.y - ghost.height / 2
                                ghost.visible = true
                                win.dropId = thumbAt(p)
                            }
                            onReleased: {
                                const wasDrag = ghost.visible, to = win.dropId
                                ghost.visible = false
                                win.dropId = -1
                                if (!wasDrag) win.focusWindow(spread.modelData)
                                else if (to > 0 && to !== win.shown) win.moveWindow(spread.modelData, to)
                            }
                        }
                    }
                }
            }

            Row {
                id: hints
                anchors { bottom: parent.bottom; bottomMargin: 20; horizontalCenter: parent.horizontalCenter }
                spacing: 24
                Repeater {
                    model: [Tr.t("Drag a window to the strip"), Tr.t("Click a window to focus it"), Tr.t("1 to 9 go straight there"), Tr.t("Esc to close")]
                    Tx { required property string modelData; text: modelData; dim: true; size: 13 }
                }
            }

            Rectangle {
                id: ghost
                property string title: ""
                visible: false
                z: 10
                width: 280; height: 44; radius: 14
                color: Qt.rgba(12 / 255, 18 / 255, 26 / 255, 0.92)
                border.width: 1; border.color: Theme.accent
                Tx { anchors.fill: parent; anchors.margins: 12; text: ghost.title; size: 14 }
            }
        }
    }
}
