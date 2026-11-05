import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets

// Chooses what the dock shows. Apps come from the system list; anything else is searched for in files.
Scope {
    id: editor
    // Outlives Ui.dockEditor by the closing animation.
    property bool alive: false
    readonly property bool isOpen: Ui.dockEditor
    onIsOpenChanged: {
        if (isOpen) { closing.stop(); alive = true }
        else closing.restart()
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
            property var files: []
            property bool searching: false
            readonly property var apps: {
                const q = query.toLowerCase()
                return [...DesktopEntries.applications.values].filter(a => !a.noDisplay
                    && (!q || (a.name + " " + a.genericName + " " + a.keywords.join(" ")).toLowerCase().includes(q)))
                    .sort((a, b) => a.name.localeCompare(b.name))
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

            // A window shortcut, because clicking a row takes the focus away from the search field.
            Shortcut { sequence: "Escape"; onActivated: Ui.dockEditor = false }
            Connections {
                target: Pins
                function onListChanged() { search.forceActiveFocus() }
            }
            MouseArea { anchors.fill: parent; enabled: Ui.dockEditor; onClicked: Ui.dockEditor = false }
            Frost {
                id: panel
                anchors.horizontalCenter: parent.horizontalCenter
                y: Math.max(82, (win.height - height) / 2 - 40)
                width: Math.min(1000, win.width - 48)
                height: Math.min(780, win.height - 200)
                property bool shown: false
                Component.onCompleted: shown = Qt.binding(() => Ui.dockEditor)
                opacity: shown ? 1 : 0
                scale: shown ? 1 : 0.96
                Behavior on opacity { NumberAnimation { duration: 170 } }
                Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                MouseArea { anchors.fill: parent }

                ColumnLayout {
                    anchors.fill: parent; anchors.margins: 24; spacing: 14
                    RowLayout {
                        Layout.fillWidth: true
                        Tx { text: Tr.t("Customize dock"); size: 24; strong: true; Layout.fillWidth: true; Accessible.role: Accessible.Heading; Accessible.name: text }
                        Btn { variant: "quiet"; icon: "x"; implicitHeight: 44; a11y: Tr.t("Close panel"); onClicked: Ui.dockEditor = false }
                    }
                    RowLayout {
                        Layout.fillWidth: true; Layout.fillHeight: true; spacing: 24

                        // Pinned, in order
                        ColumnLayout {
                            Layout.preferredWidth: 1; Layout.fillWidth: true; Layout.fillHeight: true; spacing: 8
                            Sec { title: Tr.t("On the dock"); Layout.topMargin: 0 }
                            Tx { visible: Pins.list.length === 0; text: Tr.t("The dock is empty. Add apps from the list."); dim: true; wrapMode: Text.Wrap; Layout.fillWidth: true }
                            ListView {
                                Layout.fillWidth: true; Layout.fillHeight: true
                                clip: true; spacing: 2
                                model: Pins.list
                                delegate: Rowi {
                                    id: pinned
                                    required property var modelData
                                    required property int index
                                    width: ListView.view.width
                                    clickable: false
                                    a11y: Tr.t(modelData.label)
                                    PinIcon { pin: pinned.modelData; size: 24 }
                                    Tx { text: Tr.t(pinned.modelData.label); Layout.fillWidth: true }
                                    Btn { variant: "quiet"; icon: "up"; iconSize: 18; implicitWidth: 36; a11y: Tr.t("Move up"); enabledB: pinned.index > 0; onClicked: Pins.move(pinned.index, -1) }
                                    Btn { variant: "quiet"; icon: "down"; iconSize: 18; implicitWidth: 36; a11y: Tr.t("Move down"); enabledB: pinned.index < Pins.list.length - 1; onClicked: Pins.move(pinned.index, 1) }
                                    Btn { variant: "quiet"; icon: "x"; iconSize: 18; implicitWidth: 36; a11y: Tr.t("Remove %1").arg(Tr.t(pinned.modelData.label)); onClicked: Pins.remove(pinned.index) }
                                }
                            }
                        }

                        Rectangle { Layout.fillHeight: true; implicitWidth: 1; color: Theme.line }

                        // Available
                        ColumnLayout {
                            Layout.preferredWidth: 1; Layout.fillWidth: true; Layout.fillHeight: true; spacing: 8
                            Fld {
                                id: search
                                Layout.fillWidth: true
                                placeholderText: Tr.t("Search apps and files…")
                                Accessible.name: Tr.t("Search apps and files…")
                                Component.onCompleted: forceActiveFocus()
                            }
                            ListView {
                                id: available
                                Layout.fillWidth: true; Layout.fillHeight: true
                                clip: true; spacing: 2
                                model: win.apps
                                delegate: Rowi {
                                    id: app
                                    required property var modelData
                                    width: ListView.view.width
                                    readonly property bool on: Pins.has(modelData)
                                    a11y: modelData.name
                                    onClicked: Pins.toggle(modelData)
                                    IconImage { implicitSize: 24; source: Quickshell.iconPath(app.modelData.icon, true) }
                                    Tx { text: app.modelData.name; Layout.fillWidth: true }
                                    Ic { visible: app.on; name: "check"; color: Theme.accent }
                                }
                                footer: ColumnLayout {
                                    width: ListView.view.width; spacing: 2
                                    Sec { visible: win.query.length >= 2; title: Tr.t("Found in files") }
                                    Tx { visible: win.searching; text: Tr.t("Searching files…"); dim: true }
                                    Tx { visible: win.query.length >= 2 && !win.searching && win.files.length === 0; text: Tr.t("Nothing found."); dim: true }
                                    Tx { visible: win.query.length < 2 && win.apps.length > 0; text: Tr.t("Not on the list? Type its name to search your files too."); dim: true; wrapMode: Text.Wrap; Layout.fillWidth: true; Layout.topMargin: 8 }
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
                                    Item { implicitHeight: 8 }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
