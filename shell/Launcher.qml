import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets

// Apps and system screens in one search. Super+R.
LazyLoader {
    active: Ui.launcher && !!Ui.screen
    PanelWindow {
        id: win
        screen: Ui.screen
        anchors { top: true; bottom: true; left: true; right: true }
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        WlrLayershell.namespace: "atoll-palette"
        color: "transparent"
        property int sel: 0
        property var clips: []
        property var emojis: []
        property var recent: []
        // Runs a capture after this window is gone, so it isn't in the picture.
        function shoot(mode) {
            Ui.launcher = false
            Ui.sh("sleep 0.3; $HOME/.local/share/atoll/scripts/screenshot " + mode)
        }
        function copyEmoji(e) {
            recent = [e].concat(recent.filter(r => r !== e)).slice(0, 16)
            recentFile.setText(recent.join("\n") + "\n")
            Quickshell.execDetached(["wl-copy", e])
            Ui.launcher = false
        }
        Process {
            running: Ui.launcherMode === "clip"
            command: ["cliphist", "list"]
            stdout: StdioCollector {
                onStreamFinished: win.clips = text.split("\n").filter(Boolean).map(line => {
                    const tab = line.indexOf("\t")
                    return { id: line.slice(0, tab), text: line.slice(tab + 1) }
                })
            }
        }
        FileView {
            path: Ui.launcherMode === "emoji" ? Quickshell.shellPath("emoji.txt") : ""
            printErrors: false
            onLoaded: win.emojis = text().split("\n").filter(Boolean).map(line => {
                const space = line.indexOf(" ")
                return { glyph: line.slice(0, space), label: line.slice(space + 1) }
            })
        }
        FileView {
            id: recentFile
            path: Quickshell.env("HOME") + "/.local/state/atoll/emoji-recent"
            printErrors: false
            onLoaded: win.recent = text().split("\n").filter(Boolean)
        }
        readonly property var results: {
            const q = field.text.trim().toLowerCase()
            if (Ui.launcherMode === "clip") {
                return clips.filter(c => c.text.toLowerCase().includes(q)).slice(0, 60).map(c => ({
                    name: c.text, kind: "", icon: "copy",
                    run: () => {
                        Quickshell.execDetached(["sh", "-c", 'cliphist decode "$1" | wl-copy', "sh", c.id])
                        Ui.launcher = false
                    }
                }))
            }
            if (Ui.launcherMode === "emoji") {
                const found = q ? emojis.filter(e => e.label.includes(q))
                    : recent.map(r => emojis.find(e => e.glyph === r)).filter(Boolean).concat(emojis.filter(e => !recent.includes(e.glyph)))
                return found.slice(0, 60).map(e => ({ name: e.glyph + "  " + e.label, kind: "", run: () => win.copyEmoji(e.glyph) }))
            }
            const pages = Ui.pages.map(p => ({ name: p.label, kind: Tr.t("screen"), icon: p.icon, hay: (p.label + " " + p.kw).toLowerCase(), run: () => Ui.show(p.id) }))
            const apps = [...DesktopEntries.applications.values].filter(a => !a.noDisplay).sort((a, b) => a.name.localeCompare(b.name))
                .map(a => ({ name: a.name, kind: Tr.t("app"), app: a, hay: (a.name + " " + a.genericName + " " + a.keywords.join(" ")).toLowerCase(), run: () => { a.execute(); Ui.launcher = false } }))
            const commands = [
                { name: Tr.t("Workspace overview"), icon: "monitor", words: "overview workspaces windows expose", run: () => { Ui.launcher = false; Ui.overview = true } },
                { name: Tr.t("Clipboard history"), icon: "copy", words: "clipboard paste copy history", run: () => Ui.launcherMode = "clip" },
                { name: Tr.t("Emoji"), icon: "smile", words: "emoji smiley", run: () => Ui.launcherMode = "emoji" },
                { name: Tr.t("Area screenshot"), icon: "camera", words: "screenshot print capture area", run: () => win.shoot("region-file") },
                { name: Tr.t("Full screenshot"), icon: "camera", words: "screenshot print capture screen full", run: () => win.shoot("full-file") },
                { name: Tr.t("Copy an area of the screen"), icon: "camera", words: "screenshot print capture clipboard", run: () => win.shoot("region-clip") }
            ].map(c => Object.assign(c, { kind: Tr.t("command"), hay: (c.name + " " + c.words).toLowerCase() }))
            const all = pages.concat(commands, apps)
            if (!q) return all.slice(0, 40)
            const score = r => r.name.toLowerCase().startsWith(q) ? 0 : 1
            return all.filter(r => r.hay.includes(q)).sort((a, b) => score(a) - score(b)).slice(0, 40)
        }
        function run(r) { if (r) r.run() }
        MouseArea { anchors.fill: parent; onClicked: Ui.launcher = false }
        Frost {
            width: 760
            height: 12 + 52 + 8 + Math.max(60, Math.min(8, win.results.length) * 46) + 12
            anchors.horizontalCenter: parent.horizontalCenter
            y: 190
            MouseArea { anchors.fill: parent }
            ColumnLayout {
                anchors.fill: parent; anchors.margins: 12; spacing: 8
                Rectangle {
                    Layout.fillWidth: true; implicitHeight: 52; radius: Theme.radiusSmall; color: "transparent"
                    border.width: 1; border.color: Theme.accent
                    RowLayout {
                        anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 12; spacing: 10
                        Ic { name: "search"; color: Theme.muted }
                        TextInput {
                            id: field
                            Layout.fillWidth: true
                            color: Theme.ink; selectionColor: Theme.accent; selectedTextColor: Theme.accentInk
                            font.family: Theme.sans; font.pixelSize: 18
                            focus: true
                            Accessible.name: Tr.t("Search apps and commands")
                            Component.onCompleted: forceActiveFocus()
                            onTextChanged: { win.sel = 0; list.positionViewAtBeginning() }
                            Keys.onEscapePressed: Ui.launcher = false
                            Keys.onDownPressed: { win.sel = Math.min(win.sel + 1, win.results.length - 1); list.positionViewAtIndex(win.sel, ListView.Contain) }
                            Keys.onUpPressed: { win.sel = Math.max(win.sel - 1, 0); list.positionViewAtIndex(win.sel, ListView.Contain) }
                            Keys.onReturnPressed: win.run(win.results[win.sel])
                            Keys.onEnterPressed: win.run(win.results[win.sel])
                            Tx {
                                visible: !field.text; size: 18; dim: true; anchors.verticalCenter: parent.verticalCenter
                                text: Ui.launcherMode === "clip" ? Tr.t("Search the clipboard…") : Ui.launcherMode === "emoji" ? Tr.t("Search emoji…") : Tr.t("Open an app or setting…")
                            }
                            Connections { target: Ui; function onLauncherModeChanged() { field.text = ""; win.sel = 0; list.positionViewAtBeginning() } }
                        }
                    }
                }
                ListView {
                    id: list
                    Layout.fillWidth: true; Layout.fillHeight: true
                    clip: true; model: win.results; spacing: 2
                    delegate: Rowi {
                        id: it
                        required property var modelData
                        required property int index
                        width: ListView.view.width
                        implicitHeight: 44
                        selected: index === win.sel
                        a11y: modelData.name
                        activeFocusOnTab: false
                        onClicked: win.run(modelData)
                        Ic { visible: !it.modelData.app && !!it.modelData.icon; name: it.modelData.icon ?? ""; color: Theme.muted }
                        IconImage { visible: !!it.modelData.app; implicitSize: 20; source: it.modelData.app ? Quickshell.iconPath(it.modelData.app.icon, true) : "" }
                        Tx { text: it.modelData.name; Layout.fillWidth: true }
                        Tx { text: it.modelData.kind; dim: true; size: 13; mono: true }
                    }
                    Tx { anchors.centerIn: parent; visible: win.results.length === 0; text: Ui.launcherMode ? Tr.t("Nothing found.") : Tr.t("Nothing found. Try “wifi”, “volume” or “suspend”."); dim: true }
                }
            }
        }
    }
}
