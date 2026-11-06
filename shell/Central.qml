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
        readonly property var files: ({ som: "PgSound.qml", rede: "PgNet.qml", bt: "PgBt.qml", perf: "PgPerf.qml", cal: "PgCal.qml", avisos: "PgNotif.qml", ajustes: "PgSettings.qml", energia: "PgPower.qml", monitor: "PgMonitor.qml", sobre: "PgAbout.qml" , visual: "PgLook.qml", atalhos: "PgShortcuts.qml", apps: "PgApps.qml", regras: "PgRules.qml", backup: "PgBackup.qml" })
        // Every label on every screen, read from the screens' own files, so the search finds any button or option.
        property var labels: ({})
        Process {
            running: true
            workingDirectory: Quickshell.shellPath("")
            command: ["grep", "-oH", 'Tr\\.t("[^"]*")'].concat(Object.keys(win.files).map(id => win.files[id]))
            stdout: StdioCollector { onStreamFinished: win.labels = F.labelsFrom(text, win.files) }
        }
        // A screen, or an item in one: open it, and for an item scroll there.
        function go(m) {
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
            avisos: Notifs.all.length ? Tr.t("Notifications: %1").arg(Notifs.all.length) : Tr.t("All caught up"),
            ajustes: Tr.t("Language, keyboard, idle"),
            visual: Tr.t("Profile, theme, wallpaper"),
            monitor: Tr.t("Screens: %1").arg(Displays.count_on),
            sobre: "Atoll " + Ui.version,
            atalhos: Tr.t("Keys and commands"),
            apps: Tr.t("Browser, terminal, files"),
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
                                Keys.onDownPressed: nav.currentIndex = Math.min(nav.count - 1, nav.currentIndex + 1)
                                Keys.onUpPressed: nav.currentIndex = Math.max(0, nav.currentIndex - 1)
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
                        clip: true; spacing: 4
                        boundsBehavior: Flickable.StopAtBounds
                        // Screens when empty; matches while typing. A new array each time, so it fades in again.
                        model: find.text.trim() ? F.search(Ui.pages, find.text, Tr.t, win.labels) : Ui.pages.map(p => ({ page: p.id, label: p.label, icon: p.icon, key: p.key, item: false }))
                        currentIndex: -1
                        highlightFollowsCurrentItem: false
                        ScrollBar.vertical: ScrollBar { policy: nav.contentHeight > nav.height ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff; width: 6 }
                        populate: Transition {
                            ParallelAnimation {
                                NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 160; easing.type: Easing.OutCubic }
                                NumberAnimation { property: "x"; from: -14; duration: 200; easing.type: Easing.OutCubic }
                            }
                        }
                        Tx { anchors.centerIn: parent; visible: nav.count === 0; text: Tr.t("Nothing found."); dim: true }
                        delegate: Rectangle {
                            id: row
                            required property var modelData
                            required property int index
                            readonly property bool sel: !modelData.item && Ui.page === modelData.page
                            readonly property bool cur: ListView.isCurrentItem
                            readonly property color fg: sel ? Theme.accentInk : Theme.ink
                            width: ListView.view.width - 8
                            height: 58; radius: 14
                            color: sel ? Theme.accent : cur || rm.containsMouse ? Theme.raisedHover : Theme.raised
                            border.width: cur && !sel ? 1 : activeFocus ? 2 : 0
                            border.color: activeFocus ? Theme.ink : Theme.accent
                            scale: rm.pressed ? 0.98 : 1
                            Behavior on color { ColorAnimation { duration: Theme.fast } }
                            Behavior on scale { NumberAnimation { duration: 120 } }
                            activeFocusOnTab: true
                            Accessible.role: Accessible.Button
                            Accessible.name: modelData.label + ", " + (modelData.item ? modelData.sub : win.status[modelData.page] ?? "")
                            Keys.onSpacePressed: win.go(modelData)
                            Keys.onReturnPressed: win.go(modelData)
                            RowLayout {
                                anchors.fill: parent; anchors.leftMargin: 14; anchors.rightMargin: 14; spacing: 12
                                Ic { name: row.modelData.icon; size: 22; color: row.fg }
                                ColumnLayout {
                                    Layout.fillWidth: true; spacing: 1
                                    Tx { text: row.modelData.label; strong: true; color: row.fg; Layout.fillWidth: true }
                                    Tx { text: row.modelData.item ? row.modelData.sub : win.status[row.modelData.page] ?? ""; size: 13; color: row.fg; opacity: 0.8; Layout.fillWidth: true }
                                }
                                Tx { visible: !!row.modelData.key; text: row.modelData.key; mono: true; size: 12; color: row.fg; opacity: 0.6 }
                                Ic { visible: row.modelData.item; name: "right"; size: 16; color: row.fg; opacity: 0.6 }
                            }
                            MouseArea { id: rm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: win.go(row.modelData) }
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
