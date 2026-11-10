import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import "installed.js" as I
import "term.js" as T

// Installed apps, largest first, and uninstalling them (scripts/apps). A system package needs sudo, so its command
// runs in a terminal where the person types the password: the shell never sees it.
Page {
    id: pg
    group: Tr.t("Applications")
    title: Tr.t("Installed")
    readonly property string script: Quickshell.env("HOME") + "/.local/share/atoll/scripts/apps"
    property var apps: []
    property bool loaded: false
    property string source: "all"
    readonly property var counts: I.counts(apps)
    readonly property var shown: I.filter(apps, search.text, source)
    property var target: null // the app in the dialog
    property var argv: []     // its command, as scripts/apps uninstall-cmd printed it
    property bool failed: false
    property Item opener: null // gets the focus back when the dialog closes
    readonly property bool busy: runner.running || term.running

    readonly property var labels: ({ system: Tr.t("System"), flatpak: "Flatpak", appimage: "AppImage" })
    readonly property var reasons: ({ atoll: Tr.t("Atoll needs it"), default: Tr.t("Change the default first"), required: Tr.t("Other packages need it") })
    function sizeOf(app) { return I.size(app.size, Tr.locale.decimalPoint) }

    function refresh() { lister.running = false; lister.running = true }
    function ask(app, from) {
        target = app; argv = []; failed = false; opener = from
        asker.running = false
        asker.key = app.source + app.ref
        asker.command = [script, "uninstall-cmd", app.source, app.ref]
        asker.running = true
        pop.restart()
        cancel.forceActiveFocus()
    }
    function close() {
        if (runner.running) return
        target = null
        if (opener) opener.forceActiveFocus()
        opener = null
    }
    // Both in their own session, so leaving this screen never stops pacman or flatpak halfway.
    function uninstall() {
        if (!target || !argv.length || busy) return
        if (target.source === "system") {
            term.command = ["sh", "-c", 'setsid "$@" & wait $!', "sh"].concat(T.argv(argv, Tr.t("Press Enter to close.")))
            term.running = true
            close()
        } else {
            runner.command = ["sh", "-c", 'setsid "$@" & wait $!', "sh", script, "uninstall", target.source, target.ref]
            runner.running = true
        }
    }

    Process {
        id: lister
        running: true
        command: [pg.script, "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                const names = {} // in the person's language
                for (const e of DesktopEntries.applications.values) names[e.id] = e.name
                pg.apps = I.parse(text, names)
                pg.loaded = true
            }
        }
    }
    Process {
        id: asker
        property string key: "" // which app this answer is for: one asked before may still be answering
        readonly property bool current: !!pg.target && pg.target.source + pg.target.ref === key
        stdout: StdioCollector { onStreamFinished: if (asker.current) pg.argv = text.split("\n").filter(a => a) }
        onExited: code => { if (code !== 0 && asker.current) { pg.argv = []; pg.failed = true } }
    }
    Process {
        id: runner
        onExited: code => {
            if (code === 0) pg.close(); else pg.failed = true
            pg.refresh()
        }
    }
    // The terminal: the list is read again when it closes.
    Process { id: term; onExited: pg.refresh() }

    component AppIcon: Rectangle {
        property string icon: ""
        property string name: ""
        implicitWidth: 40; implicitHeight: 40; radius: 12
        color: img.visible ? "transparent" : Theme.accentSoft
        Accessible.ignored: true
        IconImage {
            id: img
            anchors.fill: parent
            source: !parent.icon ? "" : parent.icon.startsWith("/") ? "file://" + parent.icon : Quickshell.iconPath(parent.icon, true)
            visible: status === Image.Ready
        }
        Tx { anchors.centerIn: parent; visible: !img.visible; text: parent.name.charAt(0).toUpperCase(); size: 17; strong: true }
    }

    RowLayout {
        Layout.fillWidth: true; Layout.topMargin: 8
        spacing: 10
        Fld {
            id: search
            Layout.fillWidth: true
            implicitHeight: 46
            placeholderText: Tr.t("Search app")
            Accessible.name: Tr.t("Search app")
        }
        Repeater {
            model: [
                { id: "all", label: Tr.t("All %1") }, { id: "system", label: Tr.t("System %1") },
                { id: "flatpak", label: Tr.t("Flatpak %1") }, { id: "appimage", label: Tr.t("AppImage %1") }
            ].filter(c => c.id === "all" || pg.counts[c.id] > 0)
            Rectangle {
                id: chip
                required property var modelData
                readonly property bool on: pg.source === modelData.id
                implicitWidth: chipText.implicitWidth + 28; implicitHeight: 38; radius: 19
                color: on ? Theme.accentSoft : chipArea.containsMouse ? Theme.raisedHover : Theme.raised
                border.width: activeFocus ? 2 : 0; border.color: Theme.ink
                activeFocusOnTab: true
                Accessible.role: Accessible.RadioButton
                Accessible.name: chipText.text
                Accessible.checked: on
                Accessible.onPressAction: pg.source = modelData.id
                Keys.onSpacePressed: pg.source = modelData.id
                Keys.onReturnPressed: pg.source = modelData.id
                Tx { id: chipText; anchors.centerIn: parent; text: chip.modelData.label.arg(pg.counts[chip.modelData.id]); size: 14; strong: chip.on }
                MouseArea { id: chipArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: pg.source = chip.modelData.id }
            }
        }
    }

    ColumnLayout {
        Layout.fillWidth: true; Layout.topMargin: 6
        spacing: 6
        Tx { visible: pg.loaded && !pg.shown.length; text: Tr.t("Nothing found."); dim: true; Layout.fillWidth: true }
        Repeater {
            model: pg.shown
            Rectangle {
                id: row
                required property var modelData
                required property int index
                readonly property var app: modelData
                readonly property string meta: [pg.labels[app.source], pg.sizeOf(app)].concat(app.why === "atoll" ? [pg.reasons.atoll] : []).join(" · ")
                Layout.fillWidth: true
                implicitHeight: 64; radius: 16
                color: pg.target?.source === app.source && pg.target?.ref === app.ref ? Qt.rgba(Theme.danger.r, Theme.danger.g, Theme.danger.b, 0.1) : Theme.hover
                Accessible.role: Accessible.ListItem
                Accessible.name: app.name + ", " + meta
                // Rises into place, one row after the other.
                opacity: 0
                transform: Translate { id: shift; y: 10 }
                Component.onCompleted: rise.start()
                SequentialAnimation {
                    id: rise
                    PauseAnimation { duration: Math.min(row.index, 10) * 30 }
                    ParallelAnimation {
                        NumberAnimation { target: row; property: "opacity"; to: 1; duration: 260; easing.type: Easing.OutCubic }
                        NumberAnimation { target: shift; property: "y"; to: 0; duration: 260; easing.type: Easing.OutCubic }
                    }
                }

                RowLayout {
                    anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                    spacing: 14
                    AppIcon { icon: row.app.icon; name: row.app.name }
                    ColumnLayout {
                        Layout.fillWidth: true; spacing: 2
                        Tx { text: row.app.name; strong: true; Layout.fillWidth: true }
                        Tx { text: row.meta; size: 13; dim: true; Layout.fillWidth: true }
                    }
                    Btn {
                        id: remove
                        visible: !row.app.why
                        variant: "soft"
                        text: Tr.t("Uninstall")
                        a11y: "%1: %2".arg(text).arg(row.app.name)
                        enabledB: !pg.busy
                        activeFocusOnTab: true // busy comes and goes while it may hold the focus, which Qt refuses to drop
                        onClicked: pg.ask(row.app, remove)
                    }
                    RowLayout {
                        visible: !!row.app.why
                        spacing: 6
                        Accessible.role: Accessible.StaticText
                        Accessible.name: Tr.t("Protected") + ": " + (pg.reasons[row.app.why] ?? "")
                        Ic { name: "lock"; size: 15; color: Theme.muted }
                        // Atoll's own reason is already on the line under the name.
                        Tx { text: row.app.why === "atoll" ? Tr.t("Protected") : pg.reasons[row.app.why] ?? ""; size: 13; dim: true }
                    }
                }
            }
        }
    }

    // Over the page itself, not its scrolling content.
    Item {
        id: dialog
        parent: pg
        anchors.fill: parent
        z: 10
        visible: pg.target !== null
        Rectangle { anchors.fill: parent; color: Theme.scrim; radius: Theme.radiusSmall }
        MouseArea { anchors.fill: parent; hoverEnabled: true; onClicked: pg.close(); onWheel: wheel => wheel.accepted = true }
        Rectangle {
            id: card
            anchors.centerIn: parent
            width: Math.min(560, parent.width - 40)
            height: box.implicitHeight + 52
            radius: Theme.radius
            color: Theme.glassStrong
            border.width: 1; border.color: Theme.line
            Accessible.role: Accessible.Dialog
            Accessible.name: heading.text
            Keys.onEscapePressed: pg.close()
            ParallelAnimation {
                id: pop
                NumberAnimation { target: card; property: "opacity"; from: 0; to: 1; duration: 160; easing.type: Easing.OutCubic }
                NumberAnimation { target: card; property: "scale"; from: 0.96; to: 1; duration: 160; easing.type: Easing.OutCubic }
            }
            MouseArea { anchors.fill: parent } // a click on the card stays on it
            ColumnLayout {
                id: box
                anchors { left: parent.left; right: parent.right; top: parent.top; margins: 26 }
                spacing: 16
                ColumnLayout {
                    spacing: 2
                    Tx {
                        id: heading
                        text: Tr.t("Uninstall %1?").arg(pg.target?.name ?? "")
                        size: 21; strong: true; wrapMode: Text.Wrap; Layout.fillWidth: true
                        Accessible.role: Accessible.Heading; Accessible.name: text
                    }
                    Tx { text: pg.target ? Tr.t("Frees %1").arg(pg.sizeOf(pg.target)) : ""; dim: true; Layout.fillWidth: true }
                }
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: Math.max(44, command.implicitHeight + 24); radius: 12
                    color: Theme.field
                    Tx {
                        id: command
                        anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; margins: 14 }
                        text: I.commandLine(pg.argv)
                        mono: true; size: 14; wrapMode: Text.WrapAnywhere
                        Accessible.role: Accessible.StaticText; Accessible.name: text
                    }
                }
                Tx { visible: pg.failed; text: Tr.t("Could not uninstall."); color: Theme.danger; wrapMode: Text.Wrap; Layout.fillWidth: true }
                RowLayout {
                    Layout.alignment: Qt.AlignRight; Layout.topMargin: 4
                    spacing: 10
                    // Enter cancels: the focus starts here, so a stray key never uninstalls anything.
                    Btn {
                        id: cancel
                        text: Tr.t("Cancel")
                        implicitHeight: 46
                        color: pressed ? Theme.lineStrong : hovered ? Theme.raisedHover : Theme.raised
                        KeyNavigation.tab: go; KeyNavigation.backtab: go
                        onClicked: pg.close()
                    }
                    Btn {
                        id: go
                        text: pg.target?.source === "system" ? Tr.t("Open terminal and uninstall") : Tr.t("Uninstall")
                        variant: "solid"
                        color: pressed ? Qt.darker(Theme.danger, 1.15) : Theme.danger
                        border.color: activeFocus ? Theme.ink : Theme.danger
                        implicitHeight: 46
                        enabledB: pg.argv.length > 0 && !pg.busy
                        activeFocusOnTab: true
                        KeyNavigation.tab: cancel; KeyNavigation.backtab: cancel
                        onClicked: pg.uninstall()
                    }
                }
            }
        }
    }
}
