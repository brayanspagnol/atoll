import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import "overview.js" as O

// Workspaces in a strip, with the current one's windows spread out below. Super+O.
Scope {
    id: overview
    // Outlives Ui.overview by the closing animation; the window must exist to play it.
    property bool alive: false
    readonly property bool isOpen: Ui.overview
    onIsOpenChanged: {
        if (isOpen) { closing.stop(); alive = true }
        else closing.restart()
    }
    Timer { id: closing; interval: 260; onTriggered: overview.alive = false }
    LazyLoader {
    active: overview.alive && !!Ui.screen
    PanelWindow {
        id: win
        screen: Ui.screen
        anchors { top: true; bottom: true; left: true; right: true }
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: Ui.overview ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        WlrLayershell.namespace: "atoll-overview"
        color: "transparent"

        // 0 is the desktop as it is, 1 the overview. Windows travel between their real place and the spread.
        property real p: 0
        Behavior on p { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
        readonly property var mon: Hyprland.monitorFor(screen)
        readonly property real monW: (mon?.width ?? 1920) / (mon?.scale || 1)
        readonly property real monH: (mon?.height ?? 1080) / (mon?.scale || 1)
        readonly property int shown: mon?.activeWorkspace?.id ?? 1
        readonly property string wallpaper: (Cfg.v.wallpapers ?? {})[screen?.name] ?? Cfg.v.wallpaper
        property var clients: []
        readonly property var byAddress: clients.reduce((m, c) => { m[c.address] = c; return m }, {}) // no Object.fromEntries in QML
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
        // Titles change all the time (and the focused window's also sends activewindow), but nothing drawn here moves.
        readonly property var titleEvents: ["windowtitle", "windowtitlev2", "activewindow", "activewindowv2"]
        // Not restart(): a steady stream of events would keep pushing the refresh back.
        Connections { target: Hyprland; function onRawEvent(event) { if (!win.titleEvents.includes(event.name) && !refresh.running) refresh.start() } }
        Component.onCompleted: { Hyprland.refreshToplevels(); p = Qt.binding(() => Ui.overview ? 1 : 0) }

        // One window, in the same place it has on the screen. k scales screen pixels to this view.
        component Mini: ClippingRectangle {
            id: mini
            required property var modelData
            // ScriptModel leaves a moved entry's modelData stale, so the fresh one comes from its address.
            readonly property var c: win.byAddress[modelData.address] ?? modelData
            property real k: 1
            property bool live: false
            x: (c.at[0] - (win.mon?.x ?? 0)) * k
            y: (c.at[1] - (win.mon?.y ?? 0)) * k
            width: c.size[0] * k
            height: c.size[1] * k
            radius: Math.max(4, 16 * k)
            color: Theme.raised
            readonly property var entry: DesktopEntries.heuristicLookup(c.class)
            IconImage {
                anchors.centerIn: parent
                implicitSize: Math.min(parent.width, parent.height) * 0.45
                source: mini.entry?.icon ? Quickshell.iconPath(mini.entry.icon, true) : ""
            }
            ScreencopyView {
                anchors.fill: parent
                captureSource: win.toplevelOf(mini.c)
                live: mini.live
                opacity: hasContent ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 180 } }
            }
        }

        Item {
            anchors.fill: parent
            opacity: win.p
            Rectangle { anchors.fill: parent; color: Theme.ground }
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
            Rectangle { anchors.fill: parent; color: Theme.scrim }
        }
        MouseArea { anchors.fill: parent; enabled: Ui.overview; onClicked: Ui.overview = false }

        Item {
            id: stage
            anchors.fill: parent
            focus: true
            enabled: Ui.overview
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
                opacity: win.p
                color: Theme.surface
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
                opacity: win.p
                transform: Translate { y: -(strip.height + 90) * (1 - win.p) }
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
                        color: Theme.hover
                        border.width: here || target || activeFocus ? 2 : 1
                        border.color: activeFocus ? Theme.ink : here || target ? Theme.accent : Theme.lineStrong
                        activeFocusOnTab: true
                        Accessible.role: Accessible.Button
                        Accessible.name: Tr.t("Workspace %1").arg(modelData) + (windows.length ? "" : ", " + Tr.t("empty"))
                        Keys.onSpacePressed: win.goTo(modelData)
                        Keys.onReturnPressed: { win.goTo(modelData); Ui.overview = false }
                        Repeater {
                            model: ScriptModel { values: thumb.windows; objectProp: "address" }
                            Mini { k: thumb.width / win.monW }
                        }
                        Tx { visible: thumb.windows.length === 0; anchors.centerIn: parent; text: Tr.t("Empty"); dim: true; size: 13 }
                        Rectangle {
                            anchors { left: parent.left; bottom: parent.bottom; margins: 8 }
                            implicitWidth: Math.max(26, number.implicitWidth + 12); implicitHeight: 26; radius: 13
                            color: thumb.here ? Theme.accent : Theme.glassStrong
                            Tx { id: number; anchors.centerIn: parent; text: thumb.modelData; mono: true; strong: true; size: 13; color: thumb.here ? Theme.accentInk : Theme.ink }
                        }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: win.goTo(thumb.modelData) }
                    }
                }
            }

            Item {
                id: area
                anchors { left: parent.left; right: parent.right; top: strip.bottom; bottom: hints.top; margins: 60; topMargin: 24; bottomMargin: 18 }
                readonly property var windows: win.windowsOf(win.shown)
                readonly property var rects: O.spread(windows.map(c => ({ x: c.at[0] - (win.mon?.x ?? 0), y: c.at[1] - (win.mon?.y ?? 0), w: c.size[0], h: c.size[1] })), win.monW, win.monH, width, height, 24)
                Tx { visible: area.windows.length === 0; opacity: win.p; anchors.centerIn: parent; text: Tr.t("No windows on this workspace"); dim: true; size: 18 }
                // Keyed by address: a refresh updates the windows that stay, instead of rebuilding them mid-drag.
                Repeater {
                    model: ScriptModel { values: area.windows; objectProp: "address" }
                    Item {
                        id: spread
                        required property var modelData
                        required property int index
                        readonly property var c: win.byAddress[modelData.address] ?? modelData
                        readonly property var rect: area.rects[index] ?? { x: 0, y: 0, w: c.size[0], h: c.size[1] }
                        readonly property real zoom: 1 + (rect.w / c.size[0] - 1) * win.p
                        readonly property real realX: c.at[0] - (win.mon?.x ?? 0)
                        readonly property real realY: c.at[1] - (win.mon?.y ?? 0)
                        x: (realX - area.x) * (1 - win.p) + rect.x * win.p
                        y: (realY - area.y) * (1 - win.p) + rect.y * win.p
                        width: c.size[0] * zoom
                        height: c.size[1] * zoom
                        activeFocusOnTab: true
                        Accessible.role: Accessible.Button
                        Accessible.name: c.title
                        Keys.onReturnPressed: win.focusWindow(c)
                        Keys.onSpacePressed: win.focusWindow(c)
                        Mini { modelData: spread.c; k: spread.zoom; x: 0; y: 0; live: true }
                        Rectangle {
                            anchors.fill: parent
                            radius: Math.max(4, 16 * spread.zoom)
                            color: "transparent"
                            opacity: win.p
                            border.width: pick.containsMouse || spread.activeFocus ? 2 : 1
                            border.color: spread.activeFocus ? Theme.ink : pick.containsMouse ? Theme.accent : Theme.lineStrong
                        }
                        Rectangle {
                            anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: 8 }
                            implicitHeight: 34; radius: 12
                            opacity: win.p
                            color: Theme.glassStrong
                            Tx { anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 12; text: spread.c.title || spread.c.class; size: 14 }
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
                                ghost.title = spread.c.title || spread.c.class
                                ghost.x = p.x - ghost.width / 2
                                ghost.y = p.y - ghost.height / 2
                                ghost.visible = true
                                win.dropId = thumbAt(p)
                            }
                            onReleased: {
                                const wasDrag = ghost.visible, to = win.dropId
                                ghost.visible = false
                                win.dropId = -1
                                if (!wasDrag) win.focusWindow(spread.c)
                                else if (to > 0 && to !== win.shown) win.moveWindow(spread.c, to)
                            }
                        }
                    }
                }
            }

            Row {
                id: hints
                anchors { bottom: parent.bottom; bottomMargin: 20; horizontalCenter: parent.horizontalCenter }
                spacing: 24
                opacity: win.p
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
                color: Theme.glassStrong
                border.width: 1; border.color: Theme.accent
                Tx { anchors.fill: parent; anchors.margins: 12; text: ghost.title; size: 14 }
            }
        }
    }
    }
}
