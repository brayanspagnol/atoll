import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import "apps.js" as A

// One app per role, for Atoll (scripts/open-app, which the shortcuts run) and for the system (xdg-mime) at once.
Page {
    id: pg
    title: Tr.t("Default apps")
    subtitle: Tr.t("Choose an app for each role. The choice applies to Atoll's shortcuts and to the files and links you open from any app.")
    readonly property string script: Quickshell.env("HOME") + "/.local/share/atoll/scripts/open-app"
    property var st: null // A.parseState of open-app --state
    property string openRole: ""
    property string pick: ""
    property string failed: ""
    readonly property var entries: [...DesktopEntries.applications.values].map(e => ({ id: e.id, name: e.name, icon: e.icon, generic: e.genericName, categories: Array.from(e.categories), noDisplay: e.noDisplay }))
    function entry(id) { return entries.find(e => e.id === id) ?? null }
    function nameOf(id) { return entry(id)?.name || id || Tr.t("None") }

    readonly property var labels: ({
        browser: Tr.t("Web browser"), terminal: Tr.t("Terminal"), files: Tr.t("File manager"), text: Tr.t("Text editor"),
        images: Tr.t("Image viewer"), video: Tr.t("Video player"), music: Tr.t("Music player"), email: Tr.t("Email")
    })
    readonly property var hints: ({
        browser: Tr.t("Super + B, links and web pages"), terminal: Tr.t("Super + Return"), files: Tr.t("Super + E and folders"),
        text: Tr.t("Text files (.txt)"), images: Tr.t("PNG, JPEG, WebP and GIF"), video: Tr.t("MP4, MKV and WebM"),
        music: Tr.t("MP3, FLAC and OGG"), email: Tr.t("Email links (mailto)")
    })
    function atollLine(id, name) {
        const keyed = { browser: Tr.t("Super + B opens %1"), terminal: Tr.t("Super + Return opens %1"), files: Tr.t("Super + E opens %1") }
        return (keyed[id] ?? Tr.t("Atoll saves %1 as its choice")).arg(name)
    }
    function systemLine(id, name) {
        const lines = {
            browser: Tr.t("Links and web pages open in %1"), files: Tr.t("Folders open in %1"), text: Tr.t("Text files open in %1"),
            images: Tr.t("Images open in %1"), video: Tr.t("Videos open in %1"), music: Tr.t("Music files open in %1"), email: Tr.t("Email links open in %1")
        }
        return lines[id]?.arg(name) ?? Tr.t("Nothing: terminals have no system default")
    }
    function toggle(role, current) {
        failed = ""
        if (openRole === role.id) { openRole = ""; return }
        openRole = role.id
        pick = current
    }
    function apply(role) {
        failed = ""
        setter.role = role.id
        setter.command = [script, "--set", role.id, pick].concat(role.types)
        setter.running = true
    }

    Process {
        id: loader
        running: true
        command: [pg.script, "--state"].concat(A.allTypes())
        stdout: StdioCollector { onStreamFinished: pg.st = A.parseState(text) }
    }
    Process {
        id: setter
        property string role: ""
        onExited: code => {
            if (code === 0) pg.openRole = ""
            else pg.failed = role
            loader.running = true
        }
    }

    // Filled, so it stays visible over light wallpapers.
    component Filled: Btn {
        color: pressed ? Theme.lineStrong : hovered ? Theme.line : Theme.raised
        border.color: activeFocus ? Theme.ink : Theme.lineStrong
    }
    component AppIcon: Item {
        property string icon: ""
        property int size: 28
        implicitWidth: size; implicitHeight: size
        Accessible.ignored: true
        IconImage { id: img; anchors.fill: parent; source: parent.icon ? Quickshell.iconPath(parent.icon, true) : ""; visible: status === Image.Ready }
        Ic { anchors.centerIn: parent; visible: !img.visible; name: "grid"; size: parent.size * 0.7; color: Theme.muted }
    }
    component Caps: Tx { size: 12; strong: true; dim: true; font.letterSpacing: 0.8; font.capitalization: Font.AllUppercase; Layout.fillWidth: true }

    ColumnLayout {
        Layout.fillWidth: true; Layout.topMargin: 8
        visible: pg.st !== null
        spacing: 6
        Repeater {
            model: A.roles
            Rectangle {
                id: row
                required property var modelData
                readonly property var role: modelData
                readonly property bool isOpen: pg.openRole === role.id
                readonly property string cur: pg.st ? A.current(role, pg.st) : ""
                readonly property var off: pg.st ? A.mismatch(role, pg.st) : null
                readonly property string pickName: pg.nameOf(pg.pick)
                Layout.fillWidth: true
                implicitHeight: col.implicitHeight + (isOpen ? 14 : 0)
                radius: 16
                color: isOpen ? Theme.raised : Theme.hover
                border.width: 1; border.color: isOpen ? Theme.accent : Theme.line
                Accessible.role: Accessible.Grouping
                Accessible.name: pg.labels[role.id]

                ColumnLayout {
                    id: col
                    anchors { left: parent.left; right: parent.right; top: parent.top }
                    spacing: 0
                    RowLayout {
                        Layout.fillWidth: true; Layout.preferredHeight: 60; Layout.leftMargin: 12; Layout.rightMargin: 12
                        spacing: 12
                        Rectangle {
                            implicitWidth: 34; implicitHeight: 34; radius: 17; color: Theme.raised
                            Ic { anchors.centerIn: parent; name: row.role.icon; size: 17; color: Theme.accent }
                        }
                        ColumnLayout {
                            Layout.fillWidth: true; spacing: 2
                            Tx { text: pg.labels[row.role.id]; size: 14; strong: true; Layout.fillWidth: true }
                            Tx { text: pg.hints[row.role.id]; size: 12; dim: true; Layout.fillWidth: true }
                        }
                        ColumnLayout {
                            spacing: 3
                            RowLayout {
                                Layout.alignment: Qt.AlignRight; spacing: 9
                                AppIcon { icon: pg.entry(row.cur)?.icon ?? "" }
                                Tx { text: pg.nameOf(row.cur); size: 14; strong: true; Layout.maximumWidth: 220 }
                            }
                            RowLayout {
                                visible: !!row.off
                                Layout.alignment: Qt.AlignRight; spacing: 6
                                Ic { name: "alert"; size: 14; color: Theme.warn }
                                Tx {
                                    size: 12; color: Theme.warn; Layout.maximumWidth: 320
                                    text: !row.off ? "" : (row.off.all ? Tr.t("The system opens these in %1") : Tr.t("The system opens some of these in %1")).arg(pg.nameOf(row.off.app))
                                }
                            }
                        }
                        Filled {
                            icon: row.isOpen ? "up" : ""
                            text: row.isOpen ? "" : row.off ? Tr.t("Resolve") : Tr.t("Change")
                            a11y: row.isOpen ? Tr.t("Close") : "%1: %2".arg(text).arg(pg.labels[row.role.id])
                            onClicked: pg.toggle(row.role, row.cur)
                        }
                    }

                    ColumnLayout {
                        visible: row.isOpen
                        Layout.fillWidth: true; Layout.leftMargin: 14; Layout.rightMargin: 14
                        spacing: 8
                        Caps { text: Tr.t("Installed apps") }
                        GridLayout {
                            id: grid
                            Layout.fillWidth: true
                            columns: Math.max(1, Math.floor((pg.bodyWidth - 28) / 220))
                            columnSpacing: 8; rowSpacing: 8
                            // From the page width, not the grid's own, which the cards would feed back into.
                            readonly property real cell: (pg.bodyWidth - 28 - columnSpacing * (columns - 1)) / columns
                            Repeater {
                                id: cands
                                model: row.isOpen ? A.candidates(row.role, pg.entries, pg.st.mimes, [row.cur, row.off?.app ?? ""]) : []
                                Rectangle {
                                    id: card
                                    required property var modelData
                                    readonly property bool chosen: pg.pick === modelData.id
                                    Layout.preferredWidth: grid.cell
                                    implicitHeight: 66; radius: Theme.radiusSmall
                                    color: chosen ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.2) : cm.containsMouse ? Theme.raised : Theme.hover
                                    border.width: activeFocus ? 2 : 1
                                    border.color: activeFocus ? Theme.ink : chosen ? Theme.accent : Theme.line
                                    activeFocusOnTab: true
                                    Accessible.role: Accessible.RadioButton
                                    Accessible.name: modelData.name
                                    Accessible.checked: chosen
                                    Accessible.onPressAction: pg.pick = modelData.id
                                    Keys.onSpacePressed: pg.pick = modelData.id
                                    Keys.onReturnPressed: pg.pick = modelData.id
                                    MouseArea { id: cm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: pg.pick = card.modelData.id }
                                    RowLayout {
                                        anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                                        spacing: 10
                                        Rectangle {
                                            implicitWidth: 16; implicitHeight: 16; radius: 8
                                            color: "transparent"; border.width: 2; border.color: card.chosen ? Theme.accent : Theme.lineStrong
                                            Rectangle { anchors.centerIn: parent; width: 8; height: 8; radius: 4; color: Theme.accent; visible: card.chosen }
                                        }
                                        AppIcon { icon: card.modelData.icon; size: 32 }
                                        ColumnLayout {
                                            Layout.fillWidth: true; spacing: 2
                                            RowLayout {
                                                Layout.fillWidth: true; spacing: 6
                                                Tx { text: card.modelData.name; size: 14; strong: true; Layout.fillWidth: true; Layout.maximumWidth: Math.ceil(implicitWidth) } // a fraction short of it elides
                                                Rectangle {
                                                    visible: card.modelData.id === row.cur
                                                    implicitWidth: badge.implicitWidth + 16; implicitHeight: 20; radius: 10; color: Theme.raised
                                                    Tx { id: badge; anchors.centerIn: parent; text: Tr.t("Current"); size: 12; strong: true }
                                                }
                                            }
                                            Tx { text: card.modelData.generic ?? ""; visible: !!text; size: 12; dim: true; Layout.fillWidth: true }
                                        }
                                    }
                                }
                            }
                        }
                        Tx { visible: cands.count === 0; text: Tr.t("No installed app can do this."); dim: true; Layout.fillWidth: true }

                        Caps { visible: !!pg.pick; text: Tr.t("What changes with %1").arg(row.pickName); Layout.topMargin: 6 }
                        GridLayout {
                            visible: !!pg.pick
                            Layout.fillWidth: true
                            columns: pg.bodyWidth > 640 ? 2 : 1
                            columnSpacing: 8; rowSpacing: 8
                            Repeater {
                                model: [
                                    { title: Tr.t("In Atoll"), icon: "grid", line: pg.atollLine(row.role.id, row.pickName) },
                                    { title: Tr.t("In the system, for every app"), icon: "monitor", line: pg.systemLine(row.role.id, row.pickName) }
                                ]
                                Rectangle {
                                    required property var modelData
                                    Layout.fillWidth: true; Layout.fillHeight: true; Layout.preferredWidth: 1
                                    implicitHeight: box.implicitHeight + 22
                                    radius: 12; color: Theme.field
                                    border.width: 1; border.color: Theme.line
                                    ColumnLayout {
                                        id: box
                                        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 11; leftMargin: 14; rightMargin: 14 }
                                        spacing: 7
                                        RowLayout {
                                            spacing: 8
                                            Ic { name: modelData.icon; size: 16; color: Theme.muted }
                                            Tx { text: modelData.title; size: 13; strong: true }
                                        }
                                        RowLayout {
                                            Layout.fillWidth: true; spacing: 8
                                            Ic { name: "check"; size: 14; color: Theme.good; Layout.alignment: Qt.AlignTop; Layout.topMargin: 2 }
                                            Tx { text: modelData.line; size: 13; wrapMode: Text.Wrap; elide: Text.ElideNone; Layout.fillWidth: true }
                                        }
                                    }
                                }
                            }
                        }
                        Tx { visible: pg.failed === row.role.id; text: Tr.t("Could not save the change."); color: Theme.danger; Layout.fillWidth: true }
                        RowLayout {
                            Layout.fillWidth: true; Layout.topMargin: 4; spacing: 8
                            Item { Layout.fillWidth: true }
                            Filled { text: Tr.t("Cancel"); onClicked: pg.openRole = "" }
                            Btn {
                                variant: "solid"
                                text: Tr.t("Use %1").arg(row.pickName)
                                // The same app again still fixes a disagreement with the system.
                                enabledB: !!pg.pick && (pg.pick !== row.cur || !!row.off || !pg.st.atoll[row.role.id]) && !setter.running
                                onClicked: pg.apply(row.role)
                            }
                        }
                    }
                }
            }
        }
    }
}
