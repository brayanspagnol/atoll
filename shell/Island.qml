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

PanelWindow {
    id: win
    required property var modelData
    screen: modelData
    anchors.top: true
    margins.top: 14
    implicitWidth: pill.implicitWidth
    implicitHeight: 56
    exclusiveZone: 64
    color: "transparent"
    WlrLayershell.namespace: "atoll-island"
    // Only while its menu is open, for the arrows, Enter and Esc there.
    WlrLayershell.keyboardFocus: menu.visible ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    readonly property var mon: Hyprland.monitorFor(modelData)

    // The assistant's chip is live while it works with the overlay closed, then says "Done" for a moment.
    property bool aiDone: false
    // A permission request keeps it up until answered: the work is waiting on a yes or no.
    readonly property bool aiWaiting: !Assistant.busy && (Assistant.pending?.length ?? 0) > 0
    readonly property bool aiLive: !Ui.askOpen && (Assistant.busy || aiDone || aiWaiting)
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
        menu.anchor.rect.y = win.height + 6
        menu.visible = true
        menuBox.first().forceActiveFocus()
    }

    Frost {
        id: pill
        anchors.fill: parent
        implicitWidth: row.implicitWidth + 16
        radius: 28
        // The assistant's bar grows from here and takes the island's place while open.
        opacity: Ui.askOpen && (Quickshell.screens.includes(Ui.askScreen) ? Ui.askScreen : Ui.screen) === win.modelData ? 0 : 1
        // Coming back, it waits for the bar to shrink into it, so the two never stack.
        Behavior on opacity {
            SequentialAnimation {
                PauseAnimation { duration: pill.opacity < 0.5 ? 300 : 0 }
                NumberAnimation { duration: 200; easing.type: Easing.InOutCubic }
            }
        }
        RowLayout {
            id: row
            anchors.centerIn: parent
            spacing: 10
            RowLayout {
                spacing: 6
                Layout.leftMargin: 8
                Repeater {
                    model: Hyprland.workspaces.values.filter(w => w.id > 0 && w.monitor === win.mon).sort((a, b) => a.id - b.id)
                    Item {
                        id: ws
                        required property var modelData
                        readonly property bool active: modelData.id === win.mon?.activeWorkspace?.id
                        implicitWidth: dot.width; implicitHeight: 44
                        Accessible.role: Accessible.Button
                        Accessible.name: Tr.t("Workspace %1").arg(modelData.id)
                        Rectangle {
                            id: dot
                            anchors.verticalCenter: parent.verticalCenter
                            width: ws.active ? 28 : 10; height: 10; radius: 5
                            color: ws.active ? Theme.accent : Theme.muted
                            Behavior on width { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                        }
                        MouseArea { anchors.fill: parent; anchors.margins: -3; cursorShape: Qt.PointingHandCursor; onClicked: Hyprland.dispatch(`hl.dsp.focus({ workspace = ${ws.modelData.id} })`) }
                    }
                }
            }
            Rectangle { implicitWidth: 1; implicitHeight: 24; color: Theme.line }
            Rectangle {
                implicitWidth: clockRow.implicitWidth + 24; implicitHeight: 44; radius: Theme.radiusSmall
                color: cm.containsMouse ? Theme.raised : "transparent"
                Accessible.role: Accessible.Button
                Accessible.name: Tr.t("Calendar") + ", " + timeT.text + ", " + dateT.text
                SystemClock { id: clk; precision: SystemClock.Seconds }
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
