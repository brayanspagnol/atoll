import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "finder.js" as F
import Quickshell.Bluetooth
import Quickshell.Services.UPower
import Quickshell.Wayland

// The control center, under the island. Lazy: costs nothing while closed.
Scope {
    id: central
    // Outlives Ui.open by the closing animation; the window must exist to play it.
    property bool alive: false
    readonly property bool isOpen: Ui.open
    onIsOpenChanged: {
        if (isOpen) { closing.stop(); alive = true }
        else closing.restart()
    }
    Timer { id: closing; interval: 200; onTriggered: central.alive = false }
    LazyLoader {
    active: central.alive && !!Ui.screen
    PanelWindow {
        id: win
        screen: Ui.screen
        anchors { top: true; bottom: true; left: true; right: true }
        // Starts below the island so its icons switch pages instead of hitting the click-to-close area.
        margins.top: 78
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: Ui.open ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
        WlrLayershell.namespace: "atoll-central"
        color: "transparent"
        readonly property var files: ({ som: "PgSound.qml", rede: "PgNet.qml", bt: "PgBt.qml", perf: "PgPerf.qml", cal: "PgCal.qml", avisos: "PgNotif.qml", ajustes: "PgSettings.qml", energia: "PgPower.qml", monitor: "PgMonitor.qml", sobre: "PgAbout.qml" , visual: "PgLook.qml", atalhos: "PgShortcuts.qml", apps: "PgApps.qml", topo: "PgTop.qml", instalados: "PgInstalled.qml", regras: "PgRules.qml", backup: "PgBackup.qml", clima: "PgWeather.qml", ia: "PgAssistant.qml" })
        // Every label on every screen, read from the screens' own files, so the search finds any button or option.
        property var labels: ({})
        Process {
            running: true
            workingDirectory: Quickshell.shellPath("")
            command: ["grep", "-osH", 'Tr\\.t("[^"]*")'].concat(Object.keys(win.files).map(id => win.files[id]))
            stdout: StdioCollector { onStreamFinished: win.labels = F.labelsFrom(text, win.files) }
        }
        // A group's card opens or closes it; opening shows the screen last used in it.
        property bool groupOpen: false
        function openIfInGroup() { if (Ui.pages.find(p => p.id === Ui.page)?.group) groupOpen = true }
        Component.onCompleted: openIfInGroup()
        Connections { target: Ui; function onPageChanged() { win.openIfInGroup() } }
        property real unfold: groupOpen ? 1 : 0
        Behavior on unfold { NumberAnimation { duration: 280; easing.type: Easing.OutCubic } }
        // A screen, or an item in one: open it, and for an item scroll there.
        function go(m) {
            if (m.head) { groupOpen = !groupOpen; if (groupOpen) Ui.page = Ui.resolve(m.group); return }
            find.text = ""
            if (m.item) Ui.reveal(m.page, m.label)
            else Ui.page = m.page
        }
        readonly property var status: ({
            som: Audio.sink?.audio ? Math.round(Audio.sink.audio.volume * 100) + "%" : Tr.t("No output"),
            rede: Net.status,
            bt: !Bluetooth.defaultAdapter?.enabled ? Tr.t("Off") : Tr.t("Connected: %1").arg(Bluetooth.defaultAdapter.devices.values.filter(d => d.connected).length),
            perf: "CPU " + Math.round(Sys.cpu) + "% · " + Math.round(Sys.temp) + " °C",
            cal: Tr.date(new Date(), "MMM d").replace(/\./g, ""),
            clima: Weather.data ? Weather.data.place + " · " + Weather.data.temp + "°" : Tr.t("Not set"),
            ia: Assistant.providers.find(p => p.id === Assistant.provider)?.name ?? Tr.t("Not set up"),
            avisos: Notifs.all.length ? Tr.t("Notifications: %1").arg(Notifs.all.length) : Tr.t("All caught up"),
            ajustes: Tr.t("Language, keyboard, idle"),
            visual: Tr.t("Profile, theme, wallpaper"),
            monitor: Tr.t("Screens: %1").arg(Displays.count_on),
            sobre: "Atoll " + Ui.version,
            atalhos: Tr.t("Keys and commands"),
            topo: Tr.t("%1 items").arg(Cfg.island.length),
            instalados: Tr.t("Uninstall apps"),
            apps: Tr.t("Browser, terminal"),
            regras: Tr.t("Per app"),
            backup: Tr.t("Export, import"),
            energia: UPower.displayDevice?.isLaptopBattery ? Tr.t("Battery %1%").arg(Math.round(UPower.displayDevice.percentage * 100)) : Tr.t("Shut down, suspend")
        })
        MouseArea { anchors.fill: parent; enabled: Ui.open; onClicked: Ui.open = false }
        Frost {
            id: panel
            anchors.horizontalCenter: parent.horizontalCenter
            y: 4
            width: Math.min(1320, win.width - 48)
            height: Math.min(1180, win.height - 4 - 112)
            focus: true
            Keys.onEscapePressed: Ui.open = false
            property bool shown: false
            Component.onCompleted: { shown = Qt.binding(() => Ui.open); forceActiveFocus() }
            opacity: shown ? 1 : 0
            scale: shown ? 1 : 0.96
            transformOrigin: Item.Top
            transform: Translate { y: panel.shown ? 0 : -14; Behavior on y { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } } }
            Behavior on opacity { NumberAnimation { duration: 170 } }
            Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
            MouseArea { anchors.fill: parent } // keeps clicks from reaching the close area behind
            RowLayout {
                anchors.fill: parent
                spacing: 0
                ColumnLayout {
                    Layout.preferredWidth: 364; Layout.maximumWidth: 364; Layout.fillHeight: true; Layout.margins: 18
                    spacing: 12
                    // Search: the screens and what is inside them, as you type.
                    Rectangle {
                        Layout.fillWidth: true; implicitHeight: 46; radius: 14
                        color: Theme.field
                        border.width: find.activeFocus ? 1.5 : 1
                        border.color: find.activeFocus ? Theme.accent : Theme.line
                        Behavior on border.color { ColorAnimation { duration: Theme.fast } }
                        RowLayout {
                            anchors.fill: parent; anchors.leftMargin: 14; anchors.rightMargin: 10; spacing: 10
                            Ic { name: "search"; size: 18; color: Theme.muted }
                            TextInput {
                                id: find
                                Layout.fillWidth: true
                                color: Theme.ink; selectionColor: Theme.accent; selectedTextColor: Theme.accentInk
                                font.family: Theme.sans; font.pixelSize: 15
                                clip: true
                                Accessible.role: Accessible.EditableText
                                Accessible.name: Tr.t("Search the control center")
                                Component.onCompleted: forceActiveFocus()
                                onTextChanged: nav.currentIndex = text ? 0 : -1
                                Keys.onEscapePressed: { if (text) text = ""; else Ui.open = false }
                                Keys.onDownPressed: nav.step(1)
                                Keys.onUpPressed: nav.step(-1)
                                Keys.onReturnPressed: if (nav.currentItem) win.go(nav.currentItem.modelData)
                                Keys.onEnterPressed: if (nav.currentItem) win.go(nav.currentItem.modelData)
                                Tx { visible: !find.text; text: Tr.t("Search the control center"); dim: true; anchors.verticalCenter: parent.verticalCenter }
                            }
                            Ic {
                                visible: !!find.text
                                name: "x"; size: 16; color: Theme.muted
                                MouseArea { anchors.fill: parent; anchors.margins: -8; cursorShape: Qt.PointingHandCursor; onClicked: find.text = "" }
                            }
                        }
                    }
                    ListView {
                        id: nav
                        Layout.fillWidth: true; Layout.fillHeight: true
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds
                        // Screens when empty; matches while typing. A new array each time, so it fades in again.
                        model: find.text.trim() ? F.search(Ui.pages, find.text, Tr.t, win.labels) : F.tree(Ui.pages, Ui.groups)
                        currentIndex: -1
                        highlightFollowsCurrentItem: false
                        // One row up or down, past a closed group's screens.
                        function step(d) {
                            let i = currentIndex
                            do i += d; while (i >= 0 && i < count && model[i].group && !model[i].head && !win.groupOpen)
                            if (i >= 0 && i < count) currentIndex = i
                        }
                        ScrollBar.vertical: ScrollBar { policy: nav.contentHeight > nav.height ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff; width: 6 }
                        populate: Transition {
                            ParallelAnimation {
                                NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 160; easing.type: Easing.OutCubic }
                                NumberAnimation { property: "x"; from: -14; duration: 200; easing.type: Easing.OutCubic }
                            }
                        }
                        Tx { anchors.centerIn: parent; visible: nav.count === 0; text: Tr.t("Nothing found."); dim: true }
                        // Rows carry their own gap below, so a closed group's screens take no room at all.
                        // A group's card is drawn by its header, under the screens that follow it.
                        delegate: Item {
                            id: row
                            required property var modelData
                            required property int index
                            readonly property bool head: !!modelData.head
                            readonly property bool child: !!modelData.group && !head
                            readonly property bool sel: !modelData.item && !head && Ui.page === modelData.page
                            readonly property bool cur: ListView.isCurrentItem
                            readonly property color fg: sel ? Theme.accentInk : Theme.ink
                            readonly property string line: modelData.sub || (win.status[modelData.page] ?? "")
                            width: ListView.view.width - 8
                            height: head ? 54 + 10 * (1 - win.unfold) : child ? 48 * win.unfold + (modelData.last ? 10 * win.unfold : 0) : 62
                            visible: height > 0.5
                            activeFocusOnTab: true
                            Accessible.role: Accessible.Button
                            Accessible.name: modelData.label + (line && !head ? ", " + line : "")
                            Accessible.expandable: head
                            Accessible.expanded: head && win.groupOpen
                            Accessible.onPressAction: win.go(modelData)
                            Keys.onSpacePressed: win.go(modelData)
                            Keys.onReturnPressed: win.go(modelData)
                            Keys.onDownPressed: { nav.currentIndex = index; nav.step(1); nav.currentItem.forceActiveFocus() }
                            Keys.onUpPressed: { nav.currentIndex = index; nav.step(-1); nav.currentItem.forceActiveFocus() }
                            Rectangle {
                                visible: row.head
                                width: parent.width; height: 60 + 48 * (row.modelData.count ?? 0) * win.unfold
                                radius: 16; color: Theme.raised
                            }
                            Rectangle {
                                id: box
                                x: row.head || row.child ? 6 : 0
                                y: row.head ? 6 : row.child ? 4 : 0
                                width: parent.width - 2 * x
                                height: row.head ? 48 : row.child ? 44 : 58
                                radius: row.head || row.child ? 12 : 14
                                // A group's screens fade in one after another as it opens.
                                opacity: row.child ? Math.max(0, Math.min(1, (win.unfold - row.modelData.nth * 0.15) / 0.55)) : 1
                                color: row.sel ? Theme.accent : row.cur || rm.containsMouse ? Theme.raisedHover : row.head || row.child ? "transparent" : Theme.raised
                                border.width: row.cur && !row.sel ? 1 : row.activeFocus ? 2 : 0
                                border.color: row.activeFocus ? Theme.ink : Theme.accent
                                scale: rm.pressed ? 0.98 : 1
                                Behavior on color { ColorAnimation { duration: Theme.fast } }
                                Behavior on scale { NumberAnimation { duration: 120 } }
                                RowLayout {
                                    anchors.fill: parent; anchors.leftMargin: row.child ? 22 : row.head ? 8 : 14; anchors.rightMargin: row.head ? 10 : 14; spacing: 12
                                    Ic { visible: !row.child; name: row.modelData.icon; size: 22; color: row.fg }
                                    ColumnLayout {
                                        Layout.fillWidth: true; spacing: 1
                                        Tx { text: row.modelData.label; strong: !row.child || row.sel; color: row.fg; Layout.fillWidth: true }
                                        Tx { visible: !row.head && !row.child; text: row.line; size: 13; color: row.fg; opacity: 0.8; Layout.fillWidth: true }
                                    }
                                    Tx { visible: row.child; text: row.line; size: 13; color: row.fg; opacity: 0.8 }
                                    Tx { visible: !!row.modelData.key; text: row.modelData.key; mono: true; size: 12; color: row.fg; opacity: 0.6 }
                                    Ic { visible: !!row.modelData.item; name: "right"; size: 16; color: row.fg; opacity: 0.6 }
                                    Ic { visible: row.head; name: "down"; size: 16; color: row.fg; opacity: 0.7; rotation: 180 * win.unfold }
                                }
                                MouseArea { id: rm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: win.go(row.modelData) }
                            }
                        }
                    }
                    Rowi {
                        clickable: false
                        Tx { text: Tr.t("Night light"); Layout.fillWidth: true }
                        Swt { a11y: Tr.t("Night light"); checked: Cfg.v.nightOn; onToggled: { Cfg.v.nightOn = checked; Night.apply() } }
                    }
                    Rowi {
                        clickable: false
                        Tx { text: Tr.t("Do not disturb"); Layout.fillWidth: true }
                        Swt { a11y: Tr.t("Do not disturb"); checked: Cfg.v.dnd; onToggled: Cfg.v.dnd = checked }
                    }
                    Tx { text: Tr.t("Esc to close"); dim: true; size: 13; Layout.leftMargin: 12 }
                }
                Rectangle { Layout.fillHeight: true; implicitWidth: 1; color: Theme.line }
                Loader {
                    id: page
                    Layout.fillWidth: true; Layout.fillHeight: true
                    Layout.topMargin: 26; Layout.bottomMargin: 26; Layout.leftMargin: 30; Layout.rightMargin: 16
                    // Follows Ui.page only through the animation, so the old screen can leave first.
                    property string shown: ""
                    Component.onCompleted: shown = Ui.page
                    property int direction: 1
                    source: win.files[shown]
                    transform: Translate { id: slide }
                    Connections {
                        target: Ui
                        function onPageChanged() {
                            const order = Ui.pages.map(p => p.id)
                            page.direction = order.indexOf(Ui.page) >= order.indexOf(page.shown) ? 1 : -1
                            swap.restart()
                        }
                    }
                    SequentialAnimation {
                        id: swap
                        ParallelAnimation {
                            NumberAnimation { target: page; property: "opacity"; to: 0; duration: 90 }
                            NumberAnimation { target: slide; property: "y"; to: -18 * page.direction; duration: 90; easing.type: Easing.InCubic }
                        }
                        ScriptAction { script: { page.shown = Ui.page; slide.y = 26 * page.direction } }
                        ParallelAnimation {
                            NumberAnimation { target: page; property: "opacity"; to: 1; duration: 200 }
                            NumberAnimation { target: slide; property: "y"; to: 0; duration: 260; easing.type: Easing.OutCubic }
                        }
                    }
                }
            }
            Btn { anchors { top: parent.top; right: parent.right; margins: 18 } variant: "quiet"; icon: "x"; implicitHeight: 44; a11y: Tr.t("Close panel"); onClicked: Ui.open = false }
        }
    }
}
}
