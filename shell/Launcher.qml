import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import "parse.js" as P

// Apps, system screens, commands and emoji in one search. Super+R.
Scope {
    id: launcher
    // Outlives Ui.launcher by the closing animation; the window must exist to play it.
    property bool alive: false
    readonly property bool isOpen: Ui.launcher
    onIsOpenChanged: {
        if (isOpen) { closing.stop(); alive = true }
        else closing.restart()
    }
    Timer { id: closing; interval: 180; onTriggered: launcher.alive = false }

    LazyLoader {
    active: launcher.alive && !!Ui.screen
    PanelWindow {
        id: win
        screen: Ui.screen
        anchors { top: true; bottom: true; left: true; right: true }
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: Ui.launcher ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        WlrLayershell.namespace: "atoll-palette"
        color: "transparent"
        property int sel: 0
        property string emojiText: ""
        property string emojiLocalText: ""
        readonly property var emojis: emojiText ? P.emojiEntries(emojiText, emojiLocalText) : []
        property var recentEmoji: []
        property var recentApps: [] // desktop entry ids, newest first

        // Tabs. The clipboard has its own panel, so its tab opens that instead.
        readonly property var tabs: [
            { id: "", label: Tr.t("All"), icon: "grid" },
            { id: "apps", label: Tr.t("Apps"), icon: "window" },
            { id: "screens", label: Tr.t("Screens"), icon: "ajustes" },
            { id: "clip", label: Tr.t("Clipboard"), icon: "clipboard" },
            { id: "emoji", label: Tr.t("Emoji"), icon: "smile" },
            { id: "shots", label: Tr.t("Screenshots"), icon: "camera" }
        ]
        function pickTab(id) {
            if (id === "clip") { Ui.openClipboard(); return }
            Ui.launcherMode = id
        }
        function nextTab(delta) {
            const order = tabs.map(t => t.id).filter(id => id !== "clip")
            pickTab(order[(order.indexOf(Ui.launcherMode) + delta + order.length) % order.length])
        }

        // Runs a capture after this window is gone, so it isn't in the picture.
        function shoot(mode) {
            Ui.launcher = false
            Ui.sh("sleep 0.3; $HOME/.local/share/atoll/scripts/screenshot " + mode)
        }
        function copyEmoji(e) {
            recentEmoji = [e].concat(recentEmoji.filter(r => r !== e)).slice(0, 16)
            recentEmojiFile.setText(recentEmoji.join("\n") + "\n")
            Quickshell.execDetached(["wl-copy", e])
            Ui.launcher = false
        }
        function launch(app) {
            recentApps = [app.id].concat(recentApps.filter(id => id !== app.id)).slice(0, 12)
            recentAppsFile.setText(recentApps.join("\n") + "\n")
            app.execute()
            Ui.launcher = false
        }
        FileView {
            path: Ui.launcherMode === "emoji" ? Quickshell.shellPath("emoji.txt") : ""
            printErrors: false
            onLoaded: win.emojiText = text()
        }
        FileView {
            path: Ui.launcherMode === "emoji" ? Quickshell.shellPath("emoji/" + Tr.code.split("-")[0] + ".txt") : ""
            printErrors: false
            onLoaded: win.emojiLocalText = text()
            onLoadFailed: win.emojiLocalText = ""
        }
        FileView {
            id: recentEmojiFile
            path: Quickshell.env("HOME") + "/.local/state/atoll/emoji-recent"
            printErrors: false
            onLoaded: win.recentEmoji = text().split("\n").filter(Boolean)
        }
        FileView {
            id: recentAppsFile
            path: Quickshell.env("HOME") + "/.local/state/atoll/recent-apps"
            printErrors: false
            onLoaded: win.recentApps = text().split("\n").filter(Boolean)
        }

        readonly property var allApps: [...DesktopEntries.applications.values].filter(a => !a.noDisplay).sort((a, b) => a.name.localeCompare(b.name))
        // The apps launched from here lately, for the row of tiles above the results.
        readonly property var recentTiles: field.text.trim() || (Ui.launcherMode !== "" && Ui.launcherMode !== "apps") ? []
            : recentApps.map(id => allApps.find(a => a.id === id)).filter(Boolean).slice(0, 6)

        // Matches, best first, each with the group it is listed under.
        readonly property var results: {
            const q = field.text.trim().toLowerCase()
            const mode = Ui.launcherMode
            if (mode === "emoji") {
                const found = q ? P.emojiSearch(emojis, q)
                    : recentEmoji.map(r => emojis.find(e => e.glyph === r)).filter(Boolean).concat(emojis.filter(e => !recentEmoji.includes(e.glyph)))
                return found.slice(0, 60).map(e => ({ group: "", glyph: e.glyph, name: e.label, sub: "", run: () => win.copyEmoji(e.glyph) }))
            }
            const apps = mode === "" || mode === "apps" ? allApps.map(a => ({
                group: Tr.t("Apps"), app: a, name: a.name, sub: a.comment || a.genericName || "", kind: Tr.t("app"),
                hay: (a.name + " " + a.genericName + " " + a.keywords.join(" ")).toLowerCase(), run: () => win.launch(a)
            })) : []
            const screens = mode === "" || mode === "screens" ? Ui.pages.map(p => ({
                group: Tr.t("Screens"), icon: p.icon, name: p.label, sub: "", kind: Tr.t("screen"),
                hay: (p.label + " " + p.kw).toLowerCase(), run: () => Ui.show(p.id)
            })) : []
            const shots = [
                { name: Tr.t("Area screenshot"), sub: Tr.t("Saved to Pictures and copied"), words: "screenshot print capture area", run: () => win.shoot("region-file") },
                { name: Tr.t("Full screenshot"), sub: Tr.t("Saved to Pictures and copied"), words: "screenshot print capture screen full", run: () => win.shoot("full-file") },
                { name: Tr.t("Copy an area of the screen"), sub: Tr.t("Copied, not saved"), words: "screenshot print capture clipboard", run: () => win.shoot("region-clip") }
            ].map(c => Object.assign(c, { icon: "camera" }))
            const others = [
                { name: Tr.t("Workspace overview"), icon: "grid", sub: "", words: "overview workspaces windows expose", run: () => { Ui.launcher = false; Ui.overview = true } },
                { name: Tr.t("Clipboard history"), icon: "clipboard", sub: "", words: "clipboard paste copy history", run: () => Ui.openClipboard() },
                { name: Tr.t("Emoji"), icon: "smile", sub: "", words: "emoji smiley", run: () => Ui.launcherMode = "emoji" }
            ]
            const commands = (mode === "shots" ? shots : mode === "" ? others.concat(shots) : [])
                .map(c => Object.assign(c, { group: Tr.t("Commands"), kind: Tr.t("command"), hay: (c.name + " " + c.words).toLowerCase() }))
            const all = apps.concat(screens, commands)
            if (!q) return mode === "" ? screens.concat(commands, apps) : all
            // Name starts with it, then a word in the name does, then the name has it, then only the keywords do.
            const score = r => {
                const name = r.name.toLowerCase()
                return name.startsWith(q) ? 0 : name.split(/[\s\-_.]+/).some(w => w.startsWith(q)) ? 1 : name.includes(q) ? 2 : 3
            }
            const groupOrder = r => r.group === Tr.t("Apps") ? 0 : r.group === Tr.t("Screens") ? 1 : 2
            return all.filter(r => r.hay.includes(q)).sort((a, b) => groupOrder(a) - groupOrder(b) || score(a) - score(b)).slice(0, 40)
        }
        // The list as drawn: a heading where the group changes, then its items.
        readonly property var rows: {
            const out = []
            results.forEach((r, i) => {
                if (r.group && (i === 0 || results[i - 1].group !== r.group)) out.push({ heading: r.group })
                out.push(Object.assign({ index: i }, r))
            })
            return out
        }
        function run(r) { if (r) r.run() }
        function move(delta) {
            sel = Math.max(0, Math.min(results.length - 1, sel + delta))
            const row = rows.findIndex(r => r.index === sel)
            list.positionViewAtIndex(sel === 0 ? 0 : row, ListView.Contain)
        }

        MouseArea { anchors.fill: parent; enabled: Ui.launcher; onClicked: Ui.launcher = false }

        Frost {
            id: panel
            width: 820
            height: Math.min(win.height - 260, 680, 16 + 56 + 12 + 34 + 12 + (tiles.visible ? tiles.height + 12 : 0) + Math.max(80, list.contentHeight) + 16)
            anchors.horizontalCenter: parent.horizontalCenter
            y: 170
            radius: 26
            property bool shown: false
            Component.onCompleted: shown = Qt.binding(() => Ui.launcher)
            opacity: shown ? 1 : 0
            scale: shown ? 1 : 0.97
            transform: Translate { y: panel.shown ? 0 : -12; Behavior on y { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } } }
            Behavior on opacity { NumberAnimation { duration: 150 } }
            Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
            MouseArea { anchors.fill: parent }

            ColumnLayout {
                anchors.fill: parent; anchors.margins: 16; spacing: 12
                Rectangle {
                    Layout.fillWidth: true; implicitHeight: 56; radius: 16
                    color: Qt.rgba(1, 1, 1, 0.06)
                    border.width: 1.5; border.color: Theme.accent
                    RowLayout {
                        anchors.fill: parent; anchors.leftMargin: 18; anchors.rightMargin: 18; spacing: 12
                        Ic { name: "search"; size: 22; color: Theme.muted }
                        TextInput {
                            id: field
                            Layout.fillWidth: true
                            color: Theme.ink; selectionColor: Theme.accent; selectedTextColor: Theme.accentInk
                            font.family: Theme.sans; font.pixelSize: 19
                            focus: true
                            clip: true
                            Accessible.name: Tr.t("Search apps and commands")
                            Component.onCompleted: forceActiveFocus()
                            onTextChanged: { win.sel = 0; list.positionViewAtBeginning() }
                            Keys.onEscapePressed: Ui.launcher = false
                            Keys.onDownPressed: win.move(1)
                            Keys.onUpPressed: win.move(-1)
                            Keys.onTabPressed: win.nextTab(1)
                            Keys.onBacktabPressed: win.nextTab(-1)
                            Keys.onReturnPressed: win.run(win.results[win.sel])
                            Keys.onEnterPressed: win.run(win.results[win.sel])
                            Tx {
                                visible: !field.text; size: 19; dim: true; anchors.verticalCenter: parent.verticalCenter
                                text: Ui.launcherMode === "emoji" ? Tr.t("Search emoji…") : Tr.t("Open an app, a screen or a command…")
                            }
                            Connections { target: Ui; function onLauncherModeChanged() { field.text = ""; win.sel = 0; list.positionViewAtBeginning() } }
                        }
                    }
                }

                Row {
                    spacing: 6
                    Repeater {
                        model: win.tabs
                        Rectangle {
                            id: tab
                            required property var modelData
                            readonly property bool on: Ui.launcherMode === modelData.id
                            width: tabRow.implicitWidth + 24; height: 34; radius: 17
                            color: on ? Theme.accent : tabArea.containsMouse ? Theme.hover : Theme.raised
                            border.width: 1; border.color: on ? Theme.accent : Theme.line
                            Accessible.role: Accessible.PageTab
                            Accessible.name: modelData.label
                            Accessible.checked: on
                            RowLayout {
                                id: tabRow
                                anchors.centerIn: parent; spacing: 7
                                Ic { name: tab.modelData.icon; size: 16; color: tab.on ? Theme.accentInk : Theme.ink }
                                Tx { text: tab.modelData.label; size: 14; strong: true; color: tab.on ? Theme.accentInk : Theme.ink }
                            }
                            MouseArea { id: tabArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: win.pickTab(tab.modelData.id) }
                        }
                    }
                }

                // Recent apps, as tiles above the results.
                ColumnLayout {
                    id: tiles
                    visible: win.recentTiles.length > 0
                    Layout.fillWidth: true; spacing: 4
                    Tx { text: Tr.t("Recent").toUpperCase(); size: 12; strong: true; dim: true; font.letterSpacing: 1; Layout.leftMargin: 6 }
                    GridLayout {
                        Layout.fillWidth: true; columns: 6; columnSpacing: 4; rowSpacing: 4
                        Repeater {
                            model: win.recentTiles
                            Rectangle {
                                id: tile
                                required property var modelData
                                Layout.fillWidth: true; Layout.preferredWidth: 1
                                implicitHeight: 100; radius: 14
                                color: tileArea.containsMouse || activeFocus ? Theme.hover : "transparent"
                                border.width: activeFocus ? 2 : 0; border.color: Theme.ink
                                activeFocusOnTab: true
                                Accessible.role: Accessible.Button
                                Accessible.name: modelData.name
                                Keys.onReturnPressed: win.launch(modelData)
                                Keys.onSpacePressed: win.launch(modelData)
                                ColumnLayout {
                                    anchors.centerIn: parent; spacing: 8; width: parent.width - 8
                                    Rectangle {
                                        Layout.alignment: Qt.AlignHCenter
                                        implicitWidth: 56; implicitHeight: 56; radius: 16
                                        color: Theme.raised; border.width: 1; border.color: Theme.line
                                        IconImage { anchors.centerIn: parent; implicitSize: 34; source: Quickshell.iconPath(tile.modelData.icon, true) }
                                    }
                                    Tx { text: tile.modelData.name; size: 13; Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter }
                                }
                                MouseArea { id: tileArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: win.launch(tile.modelData) }
                            }
                        }
                    }
                }

                ListView {
                    id: list
                    Layout.fillWidth: true; Layout.fillHeight: true
                    clip: true; model: win.rows; spacing: 2
                    boundsBehavior: Flickable.StopAtBounds
                    delegate: Item {
                        id: it
                        required property var modelData
                        readonly property bool heading: modelData.heading !== undefined
                        readonly property bool selected: !heading && modelData.index === win.sel
                        width: ListView.view.width
                        height: heading ? 30 : 58
                        Tx {
                            visible: it.heading
                            anchors { left: parent.left; leftMargin: 6; bottom: parent.bottom; bottomMargin: 4 }
                            text: (it.modelData.heading ?? "").toUpperCase(); size: 12; strong: true; dim: true; font.letterSpacing: 1
                        }
                        Rectangle {
                            visible: !it.heading
                            anchors.fill: parent
                            radius: 14
                            color: it.selected ? Qt.rgba(140 / 255, 200 / 255, 245 / 255, 0.18) : rowArea.containsMouse ? Theme.hover : "transparent"
                            border.width: it.selected ? 1 : 0; border.color: Theme.accent
                            Accessible.role: Accessible.Button
                            Accessible.name: it.modelData.name ?? ""
                            RowLayout {
                                anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 14; spacing: 14
                                Rectangle {
                                    implicitWidth: 38; implicitHeight: 38; radius: 11
                                    color: Theme.raised; border.width: 1; border.color: Theme.line
                                    IconImage { visible: !!it.modelData.app; anchors.centerIn: parent; implicitSize: 24; source: it.modelData.app ? Quickshell.iconPath(it.modelData.app.icon, true) : "" }
                                    Ic { visible: !it.modelData.app && !!it.modelData.icon; anchors.centerIn: parent; name: it.modelData.icon ?? ""; size: 19 }
                                    Text { visible: !!it.modelData.glyph; anchors.centerIn: parent; text: it.modelData.glyph ?? ""; font.pixelSize: 22; textFormat: Text.PlainText }
                                }
                                ColumnLayout {
                                    Layout.fillWidth: true; spacing: 1
                                    Tx { text: it.modelData.name ?? ""; size: 16; strong: true; Layout.fillWidth: true }
                                    Tx { visible: !!it.modelData.sub; text: it.modelData.sub ?? ""; size: 13; dim: true; Layout.fillWidth: true }
                                }
                                Tx { visible: !it.selected && !!it.modelData.kind; text: it.modelData.kind ?? ""; size: 12; dim: true }
                            }
                            MouseArea { id: rowArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: win.run(it.modelData) }
                        }
                    }
                    Tx { anchors.centerIn: parent; visible: win.results.length === 0; text: Ui.launcherMode ? Tr.t("Nothing found.") : Tr.t("Nothing found. Try “wifi”, “volume” or “suspend”."); dim: true }
                }
            }
        }
    }
    }
}
