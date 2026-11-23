import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.SystemTray
import Quickshell.Services.UPower
import Quickshell.Bluetooth
import Quickshell.Wayland
import Quickshell.Widgets
import "pins.js" as Pins
import "island.js" as I

// The island: a small pill at rest that grows into whatever is happening (island.js picks what) and opens in full under the pointer.
// The window keeps one size; only the shapes inside move, because resizing a layer every frame stutters. The mask leaves the rest click-through.
PanelWindow {
    id: win
    required property var modelData
    screen: modelData
    anchors.top: true
    margins.top: 14
    implicitWidth: Math.min(1100, (modelData?.width ?? 1140) - 40)
    implicitHeight: 200
    exclusiveZone: 64
    color: "transparent"
    mask: Region {
        Region { item: pill }
        Region { item: bubbles.visible ? bubbles : null }
    }
    WlrLayershell.namespace: "atoll-island"
    // Only while its menu is open, for the arrows, Enter and Esc there.
    WlrLayershell.keyboardFocus: menu.visible ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    readonly property var mon: Hyprland.monitorFor(modelData)
    // The width the pill is growing to: the assistant's bar grows out of it and shrinks back into it.
    readonly property real pillWidth: pill.goalW
    onPillWidthChanged: Ui.setIslandWidth(modelData.name, pillWidth)
    readonly property real pillDrop: pill.goalH - 56
    onPillDropChanged: Ui.setIslandDrop(modelData.name, pillDrop)
    Component.onCompleted: { Ui.setIslandWidth(modelData.name, pillWidth); Ui.setIslandDrop(modelData.name, pillDrop); lastBat = batState }

    // The assistant's chip is live while it works with the overlay closed, then says "Done" for a moment.
    property bool aiDone: false
    // A permission request keeps it up until answered: the work is waiting on a yes or no.
    readonly property bool aiWaiting: !Assistant.busy && (Assistant.pending?.length ?? 0) > 0
    readonly property bool aiLive: !Ui.askOpen && (Assistant.busy || aiDone || aiWaiting)
    readonly property string aiMood: aiWaiting && aiLive ? "waiting" : aiDone ? (Assistant.mood === "error" ? "error" : "done") : aiLive ? Assistant.mood : "idle"
    // What it is doing now: the last step of this turn.
    readonly property string aiStep: {
        const items = Assistant.items
        for (let i = items.length - 1; i >= 0 && items[i].kind !== "user"; i--) if (items[i].kind === "step") return items[i].text
        return ""
    }
    readonly property string aiText: aiWaiting ? Tr.t("Lagu needs your OK") : aiDone ? Tr.t("Done") : aiStep || Tr.t("Working…")
    Connections {
        target: Assistant
        function onBusyChanged() { if (!Assistant.busy && !Ui.askOpen && !win.aiWaiting) { win.aiDone = true; aiDoneTimer.restart() } }
    }
    Connections {
        target: Ui
        function onAskOpenChanged() { if (Ui.askOpen) win.aiDone = false }
    }
    Timer { id: aiDoneTimer; interval: 4000; onTriggered: win.aiDone = false }
    readonly property var bat: UPower.displayDevice
    readonly property bool plugged: bat?.state === UPowerDeviceState.Charging || bat?.state === UPowerDeviceState.FullyCharged
    readonly property bool batLow: !plugged && (bat?.percentage ?? 1) < 0.15
    readonly property int batPct: Math.round((bat?.percentage ?? 0) * 100)
    // Plugging the charger in plays a pulse once.
    readonly property string batState: bat?.state === UPowerDeviceState.Charging ? "charging" : bat?.state === UPowerDeviceState.Discharging ? "discharging" : "other"
    property string lastBat: ""
    property bool charging: false
    onBatStateChanged: {
        if (I.plugged(lastBat, batState) && (bat?.isLaptopBattery ?? false)) { charging = true; chargeTimer.restart() }
        lastBat = batState
    }
    Timer { id: chargeTimer; interval: 2600; onTriggered: win.charging = false }
    // Music stays in the island for a while after a pause, so a short one doesn't send it away.
    readonly property bool playing: Audio.player?.isPlaying ?? false
    property bool musicHeld: false
    onPlayingChanged: { musicHeld = !playing; if (!playing) musicHold.restart() }
    Timer { id: musicHold; interval: 30000; onTriggered: win.musicHeld = false }
    readonly property bool musicOn: !!Audio.player?.trackTitle && !Focus.hiding && (playing || musicHeld)

    // Notifications and the volume show on the screen in use, as the cards under the island do.
    readonly property bool target: (Quickshell.screens.includes(Ui.sheetScreen) ? Ui.sheetScreen : Ui.screen) === modelData
    readonly property var queue: I.queue(Notifs.toasts)
    readonly property var lay: I.layout({ notif: target && !!queue.current, osd: target && Osd.shown, charge: target && charging, lagu: aiLive, focus: Focus.running, music: musicOn })
    // Under the pointer (or with its menu open) the island opens in full, unless an event has it.
    property bool hot: false
    readonly property string view: (hot || menu.visible) && !I.events.includes(lay.main) ? "full" : lay.main
    readonly property Item shownView: ({ rest: restView, full: fullView, music: musicView, osd: osdView, notif: notifView, focus: focusView, lagu: laguView, charge: chargeView })[view]
    Timer { id: hotIn; interval: 180; onTriggered: win.hot = true }
    Timer { id: hotOut; interval: 600; onTriggered: win.hot = false }
    // A press held on the island: the music card if something plays, else the control center.
    property bool holding: false
    function hold() {
        holding = true
        if (Audio.player?.trackTitle) { if (!Ui.mediaOpen) Ui.toggleMedia(modelData, win) }
        else Ui.show(Ui.page)
    }
    SystemClock { id: clk; precision: SystemClock.Minutes }

    // The pinned items (pins.js) that have something to show, plus the ones that need attention now even unpinned.
    readonly property var has: ({
        lagu: !!Assistant.provider, weather: !!Weather.data, media: !!Audio.player?.trackTitle && !Focus.hiding,
        tray: SystemTray.items.values.length > 0, bluetooth: !!Bluetooth.defaultAdapter, battery: bat?.isLaptopBattery ?? false
    })
    readonly property var urgent: ({ lagu: aiLive, battery: batLow })
    readonly property var shown: Object.keys(urgent).filter(id => urgent[id]).reduce((list, id) => Pins.pin(list, id), Cfg.island).filter(id => has[id] ?? true)
    readonly property var chips: ["lagu", "weather", "media", "tray"] // the rest are icons, set apart by a line

    // Unpinned from the island itself: a toast offers it back for a few seconds.
    function unpin(id) {
        const place = Cfg.island.indexOf(id)
        Cfg.v.island = Pins.unpin(Cfg.island, id)
        const t = { id: 0, time: Date.now(), appName: Tr.t("On top"), icon: "pinOff", image: "", appIcon: "", urgency: 1, expireTimeout: 6000, countdown: true, pins: true,
            summary: Tr.t("%1 left the top").arg(Tr.t(Pins.item(id).label)), body: Tr.t("It stays in Applications › On top"), actions: [], dismiss: null }
        t.dismiss = () => Notifs.drop(t)
        t.actions = [{ text: Tr.t("Undo"), invoke: () => { Notifs.drop(t); Cfg.v.island = Pins.pin(Cfg.island, id, place) } }]
        Notifs.toasts.filter(o => o.pins).forEach(o => Notifs.drop(o))
        Notifs.pop(t)
    }
    function openMenu(slot) {
        menu.slot = slot
        const at = slot.mapToItem(win.contentItem, 0, 0)
        menu.anchor.rect.x = at.x + slot.lead - 8
        menu.anchor.rect.y = pill.y + 56 + 6
        menu.visible = true
        menuBox.first().forceActiveFocus()
    }
    function openCard(id) {
        if (id === "music") Ui.toggleMedia(modelData, win)
        else if (id === "focus") Ui.toggleFocus(modelData, win)
        else if (id === "lagu") Ui.toggleAsk(modelData)
    }

    // One state's content in the pill: it fades in while the pill takes its size.
    component View: Item {
        property bool on: false
        anchors.centerIn: parent
        width: implicitWidth; height: implicitHeight
        opacity: on ? 1 : 0
        visible: opacity > 0
        enabled: on
        Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.InOutQuad } }
    }
    // Sound bars that move only while playing.
    component Eq: Item {
        id: eq
        property bool playing: false
        property int bars: 4
        property real h: 18
        implicitWidth: bars * 6 - 3; implicitHeight: h
        Repeater {
            model: eq.bars
            Rectangle {
                id: bar
                required property int index
                property real f: [0.5, 0.85, 0.35, 0.7][index % 4]
                x: index * 6; y: eq.h - height
                width: 3; height: Math.max(3, eq.h * f); radius: 1.5
                color: Theme.accent
                SequentialAnimation on f {
                    running: eq.playing && eq.visible
                    loops: Animation.Infinite
                    NumberAnimation { to: 1; duration: 340 + bar.index * 70; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 0.25; duration: 400 + bar.index * 50; easing.type: Easing.InOutSine }
                }
            }
        }
    }
    // The track's cover, or a note without one.
    component Cover: ClippingRectangle {
        id: cv
        property int size: 32
        implicitWidth: size; implicitHeight: size; radius: Math.round(size * 0.28)
        color: Theme.raised
        Image {
            id: art
            anchors.fill: parent
            source: Audio.player?.trackArtUrl ?? ""
            fillMode: Image.PreserveAspectCrop
            sourceSize: Qt.size(cv.size * 2, cv.size * 2)
            asynchronous: true
            visible: status === Image.Ready
        }
        Ic { anchors.centerIn: parent; visible: !art.visible; name: "music"; size: Math.round(cv.size * 0.55); color: Theme.muted }
    }
    // A line of text that slides to show its end when it doesn't fit, then back.
    component Marquee: Item {
        id: mq
        property string text: ""
        property bool running: false
        property real maxWidth: 220
        readonly property real over: line.implicitWidth - width
        implicitWidth: Math.min(maxWidth, line.implicitWidth); implicitHeight: line.implicitHeight
        clip: true
        Tx { id: line; text: mq.text; strong: true }
        SequentialAnimation {
            running: mq.running && mq.over > 0 && mq.visible
            loops: Animation.Infinite
            onRunningChanged: if (!running) line.x = 0
            PauseAnimation { duration: 1600 }
            NumberAnimation { target: line; property: "x"; to: -mq.over; duration: Math.max(1, mq.over * 28); easing.type: Easing.InOutSine }
            PauseAnimation { duration: 1600 }
            NumberAnimation { target: line; property: "x"; to: 0; duration: 320; easing.type: Easing.InOutCubic }
        }
    }
    // Text with a light that runs across it while the work goes on.
    component Shimmer: Item {
        id: sh
        property string text: ""
        property color color: Theme.muted
        property bool running: false
        property real maxWidth: 280
        implicitWidth: Math.min(maxWidth, base.implicitWidth); implicitHeight: base.implicitHeight
        clip: true
        Tx { id: base; width: sh.width; text: sh.text; color: sh.color; strong: true }
        Item {
            id: band
            visible: sh.running
            width: 56; height: sh.height
            clip: true
            x: -width
            Tx { x: -band.x; width: sh.width; text: sh.text; color: Theme.ink; strong: true }
            NumberAnimation on x { running: sh.running && sh.visible; loops: Animation.Infinite; from: -56; to: sh.width; duration: 1800 }
        }
    }
    // The workspaces: small at rest, and buttons when the island is open.
    component Dots: RowLayout {
        id: dots
        property bool small: false
        property var mon: null
        spacing: small ? 5 : 6
        Repeater {
            model: Hyprland.workspaces.values.filter(w => w.id > 0 && w.monitor === dots.mon).sort((a, b) => a.id - b.id)
            Item {
                id: ws
                required property var modelData
                readonly property bool active: modelData.id === dots.mon?.activeWorkspace?.id
                implicitWidth: dot.width; implicitHeight: dots.small ? 10 : 44
                Accessible.role: Accessible.Button
                Accessible.name: Tr.t("Workspace %1").arg(modelData.id)
                Accessible.ignored: dots.small
                Rectangle {
                    id: dot
                    anchors.verticalCenter: parent.verticalCenter
                    width: ws.active ? (dots.small ? 20 : 28) : (dots.small ? 8 : 10); height: dots.small ? 8 : 10; radius: height / 2
                    color: ws.active ? Theme.accent : Theme.muted
                    Behavior on width { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                }
                MouseArea {
                    enabled: !dots.small
                    anchors.fill: parent; anchors.margins: -3; cursorShape: Qt.PointingHandCursor
                    onClicked: Hyprland.dispatch(`hl.dsp.focus({ workspace = ${ws.modelData.id} })`)
                }
            }
        }
    }

    Item {
        id: stage
        anchors.fill: parent
        // The assistant's bar grows from here and takes the island's place while open.
        opacity: Ui.askOpen && (Quickshell.screens.includes(Ui.askScreen) ? Ui.askScreen : Ui.screen) === win.modelData ? 0 : 1
        // Coming back, it waits for the bar to shrink into it, so the two never stack.
        // The bar shrinks into exactly this shape; then the two cross-fade, so the swap can't be seen.
        Behavior on opacity {
            SequentialAnimation {
                PauseAnimation { duration: stage.opacity < 0.5 ? 400 : 0 }
                NumberAnimation { duration: 180; easing.type: Easing.InOutQuad }
            }
        }

        Frost {
            id: pill
            readonly property real goalW: win.shownView.implicitWidth
            readonly property real goalH: Math.max(56, win.shownView.implicitHeight)
            x: Math.round((win.width - width) / 2)
            width: goalW; height: goalH
            radius: 28
            clip: true
            Behavior on width { NumberAnimation { duration: 420; easing.type: Easing.OutBack; easing.overshoot: 1.2 } }
            Behavior on height { NumberAnimation { duration: 380; easing.type: Easing.OutBack; easing.overshoot: 1.2 } }
            HoverHandler {
                id: hov
                onHoveredChanged: {
                    if (hovered) { hotOut.stop(); if (!win.hot) hotIn.restart() }
                    else { hotIn.stop(); hotOut.restart() }
                }
            }

            // The charger's glow, inside the pill: outside it the screen's top edge would cut it.
            Rectangle {
                id: glow
                anchors.fill: parent
                radius: pill.radius
                color: Qt.rgba(Theme.good.r, Theme.good.g, Theme.good.b, 0.16)
                border.width: 2; border.color: Theme.good
                opacity: 0
                visible: opacity > 0
                SequentialAnimation {
                    running: chargeView.on
                    loops: 2
                    onRunningChanged: if (!running) glow.opacity = 0
                    NumberAnimation { target: glow; property: "opacity"; to: 1; duration: 520; easing.type: Easing.OutQuad }
                    NumberAnimation { target: glow; property: "opacity"; to: 0; duration: 680; easing.type: Easing.InQuad }
                }
            }

            Item {
                id: views
                anchors.fill: parent
                // A held press cancels the click under it.
                enabled: !win.holding

                View {
                    id: restView
                    on: win.view === "rest"
                    implicitWidth: restRow.implicitWidth + 40; implicitHeight: 56
                    Accessible.role: Accessible.StaticText
                    Accessible.name: timeRest.text + (batRest.visible ? ", " + Tr.t("Battery") + " " + batRest.text : "")
                    RowLayout {
                        id: restRow
                        anchors.centerIn: parent
                        spacing: 14
                        Dots { small: true; mon: win.mon }
                        Tx { id: timeRest; text: Qt.formatTime(clk.date, "HH:mm"); size: 17; strong: true }
                        RowLayout {
                            id: batRest
                            readonly property string text: win.batPct + "%"
                            visible: win.has.battery
                            spacing: 2
                            Ic { visible: win.plugged; name: "charge"; size: 16; color: Theme.good }
                            Tx { text: batRest.text; size: 13; strong: true; color: win.batLow ? Theme.danger : Theme.muted }
                        }
                    }
                }

                View {
                    id: fullView
                    on: win.view === "full"
                    implicitWidth: row.implicitWidth + 16; implicitHeight: 56
                    RowLayout {
                        id: row
                        anchors.centerIn: parent
                        spacing: 10
                        Dots { mon: win.mon; Layout.leftMargin: 8 }
                        Rectangle { implicitWidth: 1; implicitHeight: 24; color: Theme.line }
                        Rectangle {
                            implicitWidth: clockRow.implicitWidth + 24; implicitHeight: 44; radius: Theme.radiusSmall
                            color: cm.containsMouse ? Theme.raised : "transparent"
                            Accessible.role: Accessible.Button
                            Accessible.name: Tr.t("Calendar") + ", " + timeT.text + ", " + dateT.text
                            RowLayout {
                                id: clockRow; anchors.centerIn: parent; spacing: 10
                                Tx { id: timeT; text: Qt.formatTime(clk.date, "HH:mm"); size: 18; strong: true }
                                Tx { id: dateT; text: Tr.date(clk.date, "ddd, MMM d").replace(/\./g, ""); dim: true }
                            }
                            MouseArea { id: cm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Ui.toggle("cal") }
                        }
                        // Focus mode's timer while it runs, pinned or not.
                        Rectangle {
                            visible: Focus.running
                            implicitWidth: focusRow.implicitWidth + 20; implicitHeight: 44; radius: 22
                            color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, Ui.focusOpen || fm.containsMouse ? 0.26 : 0.16)
                            Accessible.role: Accessible.Button
                            Accessible.name: Focus.label
                            RowLayout {
                                id: focusRow; anchors.centerIn: parent; spacing: 8
                                FocusRing { size: 26; stroke: 4; value: Focus.fraction; track: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.25) }
                                Tx { text: Focus.clock; mono: true; strong: true; color: Theme.accent }
                            }
                            MouseArea { id: fm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Ui.toggleFocus(win.modelData, win) }
                        }
                        // The pinned items. One that leaves shrinks and fades while the rest close the gap; one that comes grows in.
                        ListView {
                            id: pinList
                            visible: count > 0
                            orientation: ListView.Horizontal
                            interactive: false
                            cacheBuffer: 4000 // every item exists, so contentWidth is exact
                            implicitWidth: contentWidth; implicitHeight: 44
                            model: ScriptModel { values: win.shown }
                            move: Transition { NumberAnimation { property: "x"; duration: 220; easing.type: Easing.OutCubic } }
                            displaced: Transition { NumberAnimation { property: "x"; duration: 220; easing.type: Easing.OutCubic } }
                            delegate: Item {
                                id: slot
                                required property string modelData
                                required property int index
                                readonly property bool icon: !win.chips.includes(modelData)
                                readonly property bool afterIcon: index > 0 && !win.chips.includes(win.shown[index - 1] ?? "lagu")
                                // The gap before it: none between icons, a line where the icons start.
                                readonly property real lead: icon && afterIcon ? 0 : (index > 0 ? 10 : 0) + (icon ? 11 : 0)
                                property real grow: 0
                                Component.onCompleted: grow = 1
                                Behavior on grow { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
                                width: (lead + part.implicitWidth) * grow
                                height: 44
                                ListView.onRemove: leave.start()
                                SequentialAnimation {
                                    id: leave
                                    PropertyAction { target: slot; property: "ListView.delayRemove"; value: true }
                                    NumberAnimation { target: slot; property: "grow"; to: 0; duration: 260; easing.type: Easing.InOutCubic }
                                    PropertyAction { target: slot; property: "ListView.delayRemove"; value: false }
                                }
                                activeFocusOnTab: true
                                Keys.onMenuPressed: win.openMenu(slot)
                                Rectangle { visible: slot.icon && !slot.afterIcon; x: slot.lead - 11; anchors.verticalCenter: parent.verticalCenter; width: 1; height: 24; color: Theme.line; opacity: slot.grow }
                                Loader {
                                    id: part
                                    x: slot.lead
                                    anchors.verticalCenter: parent.verticalCenter
                                    opacity: slot.grow
                                    scale: 0.4 + 0.6 * slot.grow
                                    sourceComponent: ({ lagu: lagu, weather: weather, media: media, tray: tray, sound: sound, network: network, bluetooth: bluetooth,
                                        clipboard: clipboard, notifications: notifications, focus: focusIcon, power: power, battery: battery })[slot.modelData] ?? null
                                }
                                Rectangle {
                                    x: slot.lead; width: part.implicitWidth; height: 44; radius: Theme.radiusSmall
                                    visible: slot.activeFocus; color: "transparent"; border.width: 2; border.color: Theme.ink
                                }
                                // The tray's own icons keep their apps' menus.
                                TapHandler { enabled: slot.modelData !== "tray"; acceptedButtons: Qt.RightButton; onTapped: win.openMenu(slot) }
                            }
                        }
                    }
                }

                View {
                    id: musicView
                    on: win.view === "music"
                    implicitWidth: musicRow.implicitWidth + 24; implicitHeight: 56
                    Accessible.role: Accessible.Button
                    Accessible.name: Tr.t("Music: %1").arg(Audio.player?.trackTitle ?? "")
                    Accessible.onPressAction: win.openCard("music")
                    RowLayout {
                        id: musicRow
                        anchors.centerIn: parent
                        spacing: 12
                        Cover { size: 34 }
                        Marquee { text: (Audio.player?.trackTitle ?? "") + (Audio.player?.trackArtist ? " · " + Audio.player.trackArtist : ""); running: win.playing }
                        Eq { playing: win.playing; Layout.rightMargin: 6 }
                    }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: win.openCard("music") }
                }

                View {
                    id: osdView
                    on: win.view === "osd"
                    readonly property bool loud: Osd.kind === "volume" && Osd.level > 1
                    readonly property string value: Osd.kind === "volume" && Osd.muted ? Tr.t("Muted") : Math.round(Osd.level * 100) + "%"
                    implicitWidth: 340; implicitHeight: 56
                    Accessible.role: Accessible.StaticText
                    Accessible.name: (Osd.kind === "brightness" ? Tr.t("Brightness") : Tr.t("Volume")) + " " + value
                    RowLayout {
                        anchors.fill: parent; anchors.leftMargin: 20; anchors.rightMargin: 22
                        spacing: 12
                        Ic { name: Osd.kind === "brightness" ? "sun" : Audio.icon; size: 20; color: Osd.kind === "volume" && Osd.muted ? Theme.muted : Theme.ink }
                        Item {
                            Layout.fillWidth: true; implicitHeight: 6
                            Rectangle { anchors.fill: parent; radius: 3; color: Theme.lineStrong }
                            Rectangle {
                                height: 6; radius: 3
                                width: Math.max(6, parent.width * Math.min(1, Osd.level))
                                visible: Osd.level > 0
                                color: osdView.loud ? Theme.warn : Theme.ink
                                Behavior on width { NumberAnimation { duration: 90 } }
                            }
                        }
                        Tx {
                            text: osdView.value
                            strong: true
                            horizontalAlignment: Text.AlignRight
                            Layout.preferredWidth: 48
                            color: osdView.loud && !Osd.muted ? Theme.warn : Theme.ink
                        }
                    }
                }

                View {
                    id: notifView
                    on: win.view === "notif"
                    // The last one shown stays drawn while the pill shrinks away from it.
                    property var toast: null
                    readonly property var current: on ? win.queue.current : null
                    onCurrentChanged: if (current) toast = current
                    implicitWidth: 440; implicitHeight: Math.max(56, toastCol.implicitHeight)
                    Column {
                        id: toastCol
                        width: parent.width
                        Repeater {
                            model: ScriptModel { values: notifView.toast ? [notifView.toast] : [] }
                            delegate: Toast { width: toastCol.width; waiting: win.queue.waiting; paused: hov.hovered }
                        }
                    }
                }

                View {
                    id: focusView
                    on: win.view === "focus"
                    implicitWidth: focusLine.implicitWidth + 36; implicitHeight: 56
                    Accessible.role: Accessible.Button
                    Accessible.name: Focus.label
                    Accessible.onPressAction: win.openCard("focus")
                    RowLayout {
                        id: focusLine
                        anchors.centerIn: parent
                        spacing: 10
                        FocusRing { size: 28; stroke: 4; value: Focus.fraction; track: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.25) }
                        Tx { text: Focus.phase === "break" ? Tr.t("Break") : Tr.t("Focus"); strong: true }
                        Tx { text: Focus.clock; mono: true; strong: true; color: Theme.accent; Layout.leftMargin: 18 }
                    }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: win.openCard("focus") }
                }

                View {
                    id: laguView
                    on: win.view === "lagu"
                    implicitWidth: laguLine.implicitWidth + 32; implicitHeight: 56
                    Accessible.role: Accessible.Button
                    Accessible.name: "Lagu: " + win.aiText
                    Accessible.onPressAction: win.openCard("lagu")
                    RowLayout {
                        id: laguLine
                        anchors.centerIn: parent
                        spacing: 10
                        Lagu { size: 28; mood: win.aiMood; animate: laguView.on && win.aiLive }
                        Shimmer {
                            text: win.aiText
                            running: Assistant.busy
                            color: win.aiDone && Assistant.mood !== "error" ? Theme.good : Assistant.busy ? Theme.muted : Theme.ink
                        }
                    }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: win.openCard("lagu") }
                }

                View {
                    id: chargeView
                    on: win.view === "charge"
                    property real fill: 0
                    implicitWidth: 360; implicitHeight: 56
                    Accessible.role: Accessible.StaticText
                    Accessible.name: Tr.t("Charging") + " " + win.batPct + "%"
                    SequentialAnimation {
                        running: chargeView.on
                        PropertyAction { target: chargeView; property: "fill"; value: 0 }
                        PauseAnimation { duration: 200 }
                        NumberAnimation { target: chargeView; property: "fill"; to: Math.max(0.05, win.batPct / 100); duration: 900; easing.type: Easing.OutCubic }
                    }
                    RowLayout {
                        anchors.fill: parent; anchors.leftMargin: 22; anchors.rightMargin: 22
                        spacing: 12
                        Tx { text: Tr.t("Charging"); strong: true; color: Theme.good }
                        Rectangle {
                            Layout.fillWidth: true; implicitHeight: 16; radius: 5
                            color: "transparent"; border.width: 2; border.color: Theme.good
                            Rectangle { x: 3; y: 3; height: parent.height - 6; radius: 2; width: (parent.width - 6) * chargeView.fill; color: Theme.good }
                        }
                        Tx { text: win.batPct + "%"; mono: true; strong: true }
                    }
                }
            }
            // Above the content, without taking its clicks: a press held 450 ms.
            Item {
                anchors.fill: parent
                TapHandler {
                    acceptedButtons: Qt.LeftButton
                    longPressThreshold: 0.45
                    onLongPressed: win.hold()
                    onPressedChanged: if (!pressed) win.holding = false
                }
            }
        }

        // The other activities, as round bubbles beside the pill. One that comes stretches out of it and one that ends merges back.
        ListView {
            id: bubbles
            z: -1 // under the pill, so one comes out from beneath it
            x: pill.x + pill.width
            y: 6
            width: contentWidth
            height: Math.max(44, contentItem.childrenRect.height)
            orientation: ListView.Horizontal
            interactive: false
            opacity: win.view === "full" ? 0 : 1
            visible: opacity > 0 && count > 0
            Behavior on opacity { NumberAnimation { duration: 180 } }
            model: ScriptModel { values: win.lay.bubbles }
            delegate: Item {
                id: bub
                required property string modelData
                required property int index
                // 0 inside the pill, 1 out on its own.
                property real out: 0
                // The neck between it and the pill: thick while they touch, thinning until it lets go.
                property real pull: 0
                Component.onCompleted: { out = 1; pull = 1 }
                Behavior on out { NumberAnimation { duration: 460; easing.type: Easing.OutBack; easing.overshoot: 1.3 } }
                Behavior on pull { NumberAnimation { duration: 420; easing.type: Easing.InQuad } }
                ListView.onRemove: merge.start()
                SequentialAnimation {
                    id: merge
                    PropertyAction { target: bub; property: "ListView.delayRemove"; value: true }
                    PropertyAction { target: bub; property: "open"; value: false }
                    ParallelAnimation {
                        NumberAnimation { target: bub; property: "out"; to: 0; duration: 380; easing.type: Easing.InOutCubic }
                        NumberAnimation { target: bub; property: "pull"; to: 0; duration: 380; easing.type: Easing.OutQuad }
                    }
                    PropertyAction { target: bub; property: "ListView.delayRemove"; value: false }
                }
                readonly property real reach: Math.min(1, Math.max(0, out))
                width: (10 + ball.width) * reach
                height: ball.height
                // Hovered a moment, it grows into a small card of its activity.
                property bool open: false
                Timer { id: openIn; interval: 150; onTriggered: bub.open = true }
                Timer { id: openOut; interval: 300; onTriggered: bub.open = false }
                readonly property string label: ({ music: Tr.t("Music: %1").arg(Audio.player?.trackTitle ?? ""), focus: Focus.label, lagu: "Lagu: " + win.aiText })[modelData] ?? ""

                Rectangle {
                    readonly property real thin: 1 - bub.pull
                    visible: thin > 0.04
                    x: -30; width: Math.max(0, ball.x + 30 + 10)
                    height: 4 + 26 * thin; y: 22 - height / 2; radius: height / 2
                    color: Theme.surface
                }
                Frost {
                    id: ball
                    x: 10 - (1 - bub.out) * 54
                    width: bub.open ? card.implicitWidth : 44
                    height: bub.open ? card.implicitHeight : 44
                    radius: bub.open ? 26 : 22
                    opacity: Math.min(1, bub.reach * 1.6)
                    clip: true
                    Behavior on width { NumberAnimation { duration: 380; easing.type: Easing.OutBack; easing.overshoot: 1.2 } }
                    Behavior on height { NumberAnimation { duration: 340; easing.type: Easing.OutBack; easing.overshoot: 1.2 } }
                    Behavior on radius { NumberAnimation { duration: 240 } }
                    activeFocusOnTab: true
                    Accessible.role: Accessible.Button
                    Accessible.name: bub.label
                    Accessible.onPressAction: win.openCard(bub.modelData)
                    Keys.onReturnPressed: win.openCard(bub.modelData)
                    Keys.onSpacePressed: win.openCard(bub.modelData)
                    HoverHandler {
                        onHoveredChanged: {
                            if (hovered) { openOut.stop(); if (!bub.open) openIn.restart() }
                            else { openIn.stop(); openOut.restart() }
                        }
                    }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: win.openCard(bub.modelData) }
                    // The essential, in the round bubble.
                    Item {
                        width: 44; height: 44
                        opacity: bub.open ? 0 : 1
                        visible: opacity > 0
                        Behavior on opacity { NumberAnimation { duration: 140 } }
                        Eq { anchors.centerIn: parent; visible: bub.modelData === "music"; bars: 3; h: 16; playing: win.playing && !bub.open }
                        FocusRing { anchors.centerIn: parent; visible: bub.modelData === "focus"; size: 26; stroke: 4; value: Focus.fraction; track: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.25) }
                        Lagu { anchors.centerIn: parent; visible: bub.modelData === "lagu"; size: 28; mood: win.aiMood; animate: visible && win.aiLive && !bub.open }
                    }
                    Loader {
                        id: card
                        active: bub.open
                        sourceComponent: ({ music: musicCard, focus: focusCard, lagu: laguCard })[bub.modelData] ?? null
                    }
                    Rectangle { anchors.fill: parent; radius: parent.radius; visible: ball.activeFocus; color: "transparent"; border.width: 2; border.color: Theme.ink }
                }
            }
        }
    }

    // The bubbles' small cards.
    Component {
        id: musicCard
        Item {
            implicitWidth: 300; implicitHeight: 104
            NumberAnimation on opacity { from: 0; to: 1; duration: 200 }
            RowLayout {
                anchors.fill: parent; anchors.margins: 12
                spacing: 12
                Cover { size: 80 }
                ColumnLayout {
                    Layout.fillWidth: true; spacing: 0
                    Tx { text: Audio.player?.trackTitle ?? ""; strong: true; Layout.fillWidth: true }
                    Tx { text: Audio.player?.trackArtist ?? ""; dim: true; size: 13; Layout.fillWidth: true }
                    Item { Layout.fillHeight: true }
                    RowLayout {
                        spacing: 4
                        Btn { variant: "quiet"; icon: "fprev"; iconFilled: true; implicitWidth: 34; implicitHeight: 34; a11y: Tr.t("Previous"); onClicked: Audio.player?.previous() }
                        Btn { variant: "solid"; icon: win.playing ? "pauseFill" : "playFill"; iconFilled: true; implicitWidth: 34; implicitHeight: 34; radius: 17; a11y: win.playing ? Tr.t("Pause") : Tr.t("Play"); onClicked: Audio.player?.togglePlaying() }
                        Btn { variant: "quiet"; icon: "fnext"; iconFilled: true; implicitWidth: 34; implicitHeight: 34; a11y: Tr.t("Next"); onClicked: Audio.player?.next() }
                    }
                }
            }
        }
    }
    Component {
        id: focusCard
        Item {
            implicitWidth: 250; implicitHeight: 84
            NumberAnimation on opacity { from: 0; to: 1; duration: 200 }
            RowLayout {
                anchors.fill: parent; anchors.margins: 14
                spacing: 12
                FocusRing { size: 52; stroke: 6; value: Focus.fraction; track: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.25) }
                ColumnLayout {
                    Layout.fillWidth: true; spacing: 0
                    Tx { text: Focus.phase === "break" ? Tr.t("Break") : Tr.t("Focus"); dim: true; size: 13 }
                    Tx { text: Focus.clock; mono: true; strong: true; size: 22; color: Theme.accent }
                }
                Btn { text: Tr.t("Stop"); implicitHeight: 34; onClicked: Focus.stop() }
            }
        }
    }
    Component {
        id: laguCard
        Item {
            implicitWidth: 300; implicitHeight: 84
            NumberAnimation on opacity { from: 0; to: 1; duration: 200 }
            RowLayout {
                anchors.fill: parent; anchors.margins: 14
                spacing: 12
                Lagu { size: 52; mood: win.aiMood; animate: win.aiLive }
                Shimmer { Layout.fillWidth: true; maxWidth: 200; text: win.aiText; running: Assistant.busy; color: win.aiDone && Assistant.mood !== "error" ? Theme.good : Theme.ink }
            }
        }
    }

    Component {
        id: lagu
        Rectangle {
            id: ai
            implicitWidth: aiRow.implicitWidth + 18; implicitHeight: 44; radius: 22
            color: aim.containsMouse ? Theme.raised : "transparent"
            Behavior on implicitWidth { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
            Accessible.role: Accessible.Button
            Accessible.name: win.aiWaiting && !Ui.askOpen ? Tr.t("Lagu needs your OK") : win.aiDone ? Tr.t("Assistant: done") : win.aiLive ? Tr.t("Assistant: working") : Tr.t("Assistant")
            Accessible.onPressAction: Ui.toggleAsk(win.modelData)
            RowLayout {
                id: aiRow; anchors.centerIn: parent; spacing: 6
                Lagu {
                    size: 26
                    mood: win.aiWaiting && win.aiLive ? "waiting" : win.aiDone ? (Assistant.mood === "error" ? "error" : "done") : win.aiLive ? Assistant.mood : "idle"
                    animate: win.aiLive || aim.containsMouse
                }
                Tx { visible: win.aiDone; text: Tr.t("Done"); size: 14; strong: true }
            }
            MouseArea { id: aim; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Ui.toggleAsk(win.modelData) }
        }
    }
    Component {
        id: weather
        Rectangle {
            implicitWidth: weatherRow.implicitWidth + 24; implicitHeight: 44; radius: Theme.radiusSmall
            color: Ui.weatherOpen || wm.containsMouse ? Theme.raised : "transparent"
            Accessible.role: Accessible.Button
            Accessible.name: Tr.t("Weather: %1, %2").arg((Weather.data?.temp ?? "") + "°").arg(Tr.t(Weather.data?.label ?? ""))
            Accessible.onPressAction: Ui.toggleWeather(win.modelData, win)
            RowLayout {
                id: weatherRow; anchors.centerIn: parent; spacing: 6
                Ic { name: Weather.data?.icon ?? ""; size: 18 }
                Tx { text: (Weather.data?.temp ?? "") + "°"; strong: true }
            }
            MouseArea { id: wm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Ui.toggleWeather(win.modelData, win) }
        }
    }
    Component {
        id: media
        Rectangle {
            implicitWidth: mediaRow.implicitWidth + 24; implicitHeight: 44; radius: Theme.radiusSmall
            color: Ui.mediaOpen || mm.containsMouse ? Theme.raised : "transparent"
            Accessible.role: Accessible.Button
            Accessible.name: Tr.t("Music: %1").arg(Audio.player?.trackTitle ?? "")
            RowLayout {
                id: mediaRow; anchors.centerIn: parent; spacing: 8
                Ic { name: Audio.player?.isPlaying ? "pause" : "music"; size: 16; color: Theme.muted }
                Tx { text: Audio.player?.trackTitle ?? ""; dim: true; Layout.maximumWidth: 260 }
            }
            MouseArea { id: mm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Ui.toggleMedia(win.modelData, win) }
        }
    }
    Component {
        id: tray
        RowLayout {
            spacing: 10
            Repeater {
                model: SystemTray.items.values
                MouseArea {
                    required property var modelData
                    implicitWidth: 32; implicitHeight: 44
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    cursorShape: Qt.PointingHandCursor
                    Accessible.role: Accessible.Button
                    Accessible.name: modelData.tooltipTitle || modelData.title || modelData.id
                    IconImage { anchors.centerIn: parent; implicitSize: 18; source: parent.modelData.icon }
                    onClicked: m => {
                        if (m.button === Qt.RightButton || modelData.onlyMenu) {
                            const p = mapToItem(null, 0, height + 8)
                            modelData.display(win, p.x, p.y)
                        } else modelData.activate()
                    }
                }
            }
        }
    }
    Component {
        id: sound
        Stat {
            icon: Audio.icon; a11y: Tr.t("Sound"); target: "som"
            onWheel: d => { if (Audio.sink?.audio) Audio.sink.audio.volume = Math.max(0, Math.min(1.5, Audio.sink.audio.volume + d * 0.05)) }
        }
    }
    Component { id: network; Stat { icon: Net.icon; a11y: Tr.t("Internet") + ": " + Net.status; target: "rede" } }
    Component {
        id: bluetooth
        Stat {
            readonly property var ad: Bluetooth.defaultAdapter
            icon: !ad?.enabled ? "btOff" : ad.devices.values.some(d => d.connected) ? "btOn" : "bt"
            a11y: "Bluetooth"; target: "bt"
        }
    }
    Component { id: clipboard; Stat { icon: "clipboard"; a11y: Tr.t("Clipboard history"); onActivated: Ui.clipboard ? Ui.clipboard = false : Ui.openClipboard() } }
    Component {
        id: notifications
        Stat {
            icon: Cfg.v.dnd || Focus.hiding ? "bellOff" : "avisos"
            label: Notifs.all.length ? String(Notifs.all.length) : ""
            a11y: Tr.t("Notifications"); target: "avisos"
        }
    }
    Component { id: focusIcon; Stat { icon: "timer"; a11y: Tr.t("Focus"); onActivated: Ui.toggleFocus(win.modelData, win) } }
    Component { id: power; Stat { icon: "energia"; a11y: Tr.t("Power"); target: "energia" } }
    Component {
        id: battery
        Stat {
            icon: win.plugged ? "charge" : win.batLow ? "batLow" : "bat"
            label: Math.round((win.bat?.percentage ?? 0) * 100) + ""
            alert: win.batLow
            a11y: Tr.t("Battery"); target: "perf"
        }
    }

    // An item's menu, under it: open its screen, take it off (or put it back), or choose them all.
    component MenuRow: Rectangle {
        id: mr
        property string icon: ""
        property string text: ""
        property string key: ""
        property bool strong: false
        signal picked()
        implicitWidth: mrRow.implicitWidth + 24; implicitHeight: 46; radius: 12
        color: strong ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, mra.containsMouse || activeFocus ? 0.26 : 0.16) : mra.containsMouse || activeFocus ? Theme.raised : "transparent"
        border.width: activeFocus ? 2 : 0; border.color: Theme.ink
        activeFocusOnTab: visible
        Accessible.role: Accessible.MenuItem
        Accessible.name: text
        Accessible.onPressAction: picked()
        Keys.onReturnPressed: picked()
        Keys.onEnterPressed: picked()
        Keys.onSpacePressed: picked()
        Keys.onDownPressed: nextItemInFocusChain(true).forceActiveFocus()
        Keys.onUpPressed: nextItemInFocusChain(false).forceActiveFocus()
        RowLayout {
            id: mrRow
            anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 12; spacing: 12
            Ic { name: mr.icon; size: 18; color: mr.strong ? Theme.accent : Theme.muted }
            Tx { text: mr.text; strong: mr.strong; Layout.fillWidth: true }
            Tx { visible: !!mr.key; text: mr.key; mono: true; size: 12; dim: true }
        }
        MouseArea { id: mra; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: mr.picked() }
    }
    PopupWindow {
        id: menu
        property Item slot: null
        readonly property string pin: slot?.modelData ?? ""
        readonly property var page: Ui.pages.find(p => p.id === Pins.item(pin)?.page) ?? null
        readonly property bool pinned: Cfg.island.includes(pin)
        anchor.window: win
        implicitWidth: 300
        implicitHeight: menuBox.implicitHeight
        color: "transparent"
        visible: false
        // The popup's own grab: a click outside closes it. A HyprlandFocusGrab here took clicks on the popup itself as outside.
        grabFocus: true
        Rectangle {
            id: menuBox
            function first() { return [openRow, pinRow, chooseRow].find(r => r.visible) }
            width: parent.width
            implicitHeight: menuCol.implicitHeight + 16
            radius: 20
            color: Theme.glassStrong
            border.width: 1; border.color: Theme.line
            transformOrigin: Item.TopLeft
            scale: menu.visible ? 1 : 0.92
            opacity: menu.visible ? 1 : 0
            Behavior on scale { NumberAnimation { duration: 220; easing.type: Easing.OutBack; easing.overshoot: 1.4 } }
            Behavior on opacity { NumberAnimation { duration: 140 } }
            Accessible.role: Accessible.PopupMenu
            Accessible.name: Tr.t(Pins.item(menu.pin)?.label ?? "")
            Keys.onEscapePressed: menu.visible = false
            Keys.onMenuPressed: menu.visible = false
            ColumnLayout {
                id: menuCol
                x: 8; y: 8; width: parent.width - 16
                spacing: 2
                MenuRow {
                    id: openRow
                    Layout.fillWidth: true
                    visible: !!menu.page
                    icon: Pins.item(menu.pin)?.icon ?? ""
                    text: Tr.t("Open %1").arg(menu.page?.full ?? "")
                    key: menu.page?.key ?? ""
                    onPicked: { menu.visible = false; Ui.show(menu.page.id) }
                }
                MenuRow {
                    id: pinRow
                    Layout.fillWidth: true
                    strong: true
                    icon: menu.pinned ? "pinOff" : "pin"
                    text: menu.pinned ? Tr.t("Unpin from the top") : Tr.t("Pin to the top")
                    onPicked: {
                        const id = menu.pin
                        menu.visible = false
                        if (menu.pinned) win.unpin(id)
                        else Cfg.v.island = Pins.pin(Cfg.island, id)
                    }
                }
                Rectangle { Layout.fillWidth: true; Layout.leftMargin: 8; Layout.rightMargin: 8; Layout.topMargin: 4; Layout.bottomMargin: 4; implicitHeight: 1; color: Theme.line }
                MenuRow {
                    id: chooseRow
                    Layout.fillWidth: true
                    icon: "grid"
                    text: Tr.t("Choose what stays on top…")
                    onPicked: { menu.visible = false; Ui.show("topo") }
                }
            }
        }
    }
}
