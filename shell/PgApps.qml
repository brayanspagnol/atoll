import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import "apps.js" as A

// One app per role, for Atoll (scripts/open-app, which the shortcuts run) and for the system (xdg-mime) at once.
Page {
    id: pg
    group: Tr.t("Applications")
    title: Tr.t("Default apps")
    subtitle: Tr.t("One app for each role.")
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
    function toggle(role, current) {
        failed = ""
        if (openRole === role.id) { openRole = ""; return }
        openRole = role.id
        pick = current
    }
    function choose(role, id) { pick = id; apply(role) }
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
                            Ic {
                                visible: !!row.off
                                Layout.alignment: Qt.AlignRight
                                name: "alert"; size: 14; color: Theme.warn
                                Accessible.role: Accessible.StaticText
                                Accessible.name: row.off ? Tr.t("The system uses %1").arg(pg.nameOf(row.off.app)) : ""
                            }
                        }
                        Filled {
                            icon: row.isOpen ? "up" : ""
                            text: row.isOpen ? "" : Tr.t("Change")
                            a11y: row.isOpen ? Tr.t("Close") : "%1: %2".arg(text).arg(pg.labels[row.role.id])
                            onClicked: pg.toggle(row.role, row.cur)
                        }
                    }

                    // The apps, right under the role: one click uses it, for Atoll and the system together.
                    ColumnLayout {
                        visible: row.isOpen
                        Layout.fillWidth: true; Layout.leftMargin: 58; Layout.rightMargin: 12
                        spacing: 2
                        Repeater {
                            id: cands
                            model: row.isOpen && pg.st ? A.candidates(row.role, pg.entries, pg.st.mimes, [row.cur, row.off?.app ?? ""]) : []
                            Rectangle {
                                id: opt
                                required property var modelData
                                readonly property bool chosen: modelData.id === row.cur && !row.off
                                readonly property bool system: row.role.types.length > 0 && modelData.id === (row.off ? row.off.app : row.cur)
                                Layout.fillWidth: true
                                implicitHeight: 52; radius: 12
                                color: chosen ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.18) : om.containsMouse ? Theme.raised : "transparent"
                                border.width: activeFocus ? 2 : chosen ? 1 : 0
                                border.color: activeFocus ? Theme.ink : Theme.accent
                                activeFocusOnTab: true
                                Accessible.role: Accessible.RadioButton
                                Accessible.name: modelData.name + (system ? ", " + Tr.t("System default") : "")
                                Accessible.checked: chosen
                                Accessible.onPressAction: pg.choose(row.role, modelData.id)
                                Keys.onSpacePressed: pg.choose(row.role, modelData.id)
                                Keys.onReturnPressed: pg.choose(row.role, modelData.id)
                                MouseArea { id: om; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; enabled: !setter.running; onClicked: pg.choose(row.role, opt.modelData.id) }
                                RowLayout {
                                    anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                                    spacing: 12
                                    AppIcon { icon: opt.modelData.icon; size: 32 }
                                    Tx { text: opt.modelData.name; size: 14; strong: true; Layout.fillWidth: true }
                                    Rectangle {
                                        visible: opt.system
                                        implicitWidth: sysTag.implicitWidth + 16; implicitHeight: 22; radius: 11; color: Theme.raised
                                        Tx { id: sysTag; anchors.centerIn: parent; text: Tr.t("System default"); size: 12; dim: true }
                                    }
                                    Ic { name: "check"; size: 20; color: Theme.accent; opacity: opt.chosen ? 1 : 0 }
                                }
                            }
                        }
                        Tx { visible: cands.count === 0; text: Tr.t("No installed app can do this."); dim: true; Layout.fillWidth: true }
                        Tx { visible: pg.failed === row.role.id; text: Tr.t("Could not save the change."); color: Theme.danger; Layout.fillWidth: true }
                    }
                }
            }
        }
    }
}
