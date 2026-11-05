import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "clip.js" as C

// Clipboard history from cliphist, with pins of Atoll's own that outlive it. Super+Shift+V.
Scope {
    id: clipboard
    // Outlives Ui.clipboard by the closing animation; the window must exist to play it.
    property bool alive: false
    readonly property bool isOpen: Ui.clipboard
    onIsOpenChanged: {
        if (isOpen) { closing.stop(); alive = true }
        else closing.restart()
    }
    Timer { id: closing; interval: 200; onTriggered: clipboard.alive = false }
    LazyLoader {
    active: clipboard.alive && !!Ui.screen
    PanelWindow {
        id: win
        screen: Ui.screen
        anchors { top: true; bottom: true; left: true; right: true }
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: Ui.clipboard ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        WlrLayershell.namespace: "atoll-clipboard"
        color: "transparent"

        // Pins live here, in a folder for this user only: clipboard content is private.
        readonly property string state: Quickshell.env("HOME") + "/.local/state/atoll"
        property var clips: []
        property var pins: [] // { file, id, preview }: a copy in state/pins, and the cliphist entry it came from
        property string chip: "all"
        property int sel: 0
        property bool wipeArmed: false
        property string tmp: "" // private folder for decoded images, removed with the window
        property int epoch: 0 // cliphist may reuse ids after a wipe, so decoded files are named per wipe
        property string full: ""
        property string shownImage: ""
        readonly property var pinItems: pins.map(p => Object.assign(C.classify(p.preview), p, { pinned: true }))
        readonly property var rows: C.filter(pinItems, field.text, chip)
            .concat(C.filter(clips.filter(c => !pins.some(p => p.id === c.id && p.preview === c.preview)), field.text, chip))
        readonly property var current: rows[sel] ?? null
        readonly property string currentKey: current ? (current.pinned ? "p" + current.file : "c" + current.id) : ""
        onRowsChanged: sel = Math.max(0, Math.min(sel, rows.length - 1))
        onSelChanged: list.positionViewAtIndex(sel, ListView.Contain)
        onCurrentKeyChanged: { full = ""; shownImage = current?.pinned && current.kind === "image" ? "file://" + pinPath(current) : "" }

        function pinPath(it) { return state + "/pins/" + it.file }
        function kindName(it) { return ({ text: Tr.t("Text"), link: Tr.t("Link"), color: Tr.t("Color"), image: Tr.t("Image") })[it.kind] }
        function label(it) { return it.kind === "image" ? [Tr.t("Image"), it.fmt.toUpperCase(), it.w + "×" + it.h].join(" · ") : it.preview }
        function meta(it) {
            if (it.kind === "image") return [Tr.t("Image"), it.fmt.toUpperCase(), it.size, it.w + "×" + it.h].join(" · ")
            return it.kind === "color" ? Tr.t("Color") + " · " + it.color : kindName(it)
        }
        function savePins(list) { pins = list; pinFile.setText(JSON.stringify(list)) }
        // One change at a time; the buttons wait while one runs.
        function run(cmd, then) {
            if (act.running) return
            act.then = then; act.command = cmd; act.running = true
        }
        function reload() { listProc.running = true }
        function copy(it) {
            if (!it) return
            if (it.pinned) Quickshell.execDetached(["sh", "-c", 'exec wl-copy --type "$2" < "$1"', "sh", pinPath(it), it.kind === "image" ? "image/" + it.fmt : "text/plain;charset=utf-8"])
            else if (/^\d+$/.test(it.id)) Quickshell.execDetached(["sh", "-c", 'cliphist decode "$1" | wl-copy', "sh", it.id])
            Ui.clipboard = false
        }
        function pin(it) {
            if (!it || it.pinned || !/^\d+$/.test(it.id)) return
            const name = Date.now().toString(36) + Math.random().toString(36).slice(2, 8)
            run(["sh", "-c", 'umask 077 && mkdir -p "$1/pins" && chmod 700 "$1" "$1/pins" && cliphist decode "$2" > "$1/pins/$3" || { rm -f "$1/pins/$3"; exit 1; }', "sh", state, it.id, name],
                code => { if (code === 0) { savePins([{ file: name, id: it.id, preview: it.preview }].concat(pins)); sel = 0 } })
        }
        function unpin(it) {
            if (!it?.pinned || !/^[a-z0-9]+$/.test(it.file)) return
            savePins(pins.filter(p => p.file !== it.file))
            Quickshell.execDetached(["rm", "-f", "--", pinPath(it)])
        }
        // A pinned item goes from both places: Atoll's copy and, if still there, its cliphist entry.
        function remove(it) {
            if (!it || act.running) return
            if (it.pinned) {
                unpin(it)
                if (!clips.some(c => c.id === it.id && c.preview === it.preview)) return
            }
            if (/^\d+$/.test(it.id)) run(["sh", "-c", 'printf "%s\\n" "$1" | cliphist delete', "sh", it.id], reload)
        }
        function wipe() {
            if (!wipeArmed) { wipeArmed = true; return }
            wipeArmed = false
            run(["cliphist", "wipe"], () => { epoch++; reload() })
        }

        Process {
            id: listProc
            running: true
            command: ["cliphist", "list"]
            stdout: StdioCollector { onStreamFinished: win.clips = C.parseList(text) }
        }
        Process {
            id: act
            property var then: null
            onExited: code => { const f = then; then = null; if (f) f(code) }
        }
        Process {
            running: true
            command: ["sh", "-c", 'mktemp -d "${XDG_RUNTIME_DIR:-/tmp}/atoll-clip.XXXXXX"']
            stdout: StdioCollector { onStreamFinished: win.tmp = text.trim() }
        }
        Component.onDestruction: if (/\/atoll-clip\.[A-Za-z0-9]+$/.test(tmp)) Quickshell.execDetached(["rm", "-rf", "--", tmp])
        FileView { id: pinFile; path: win.state + "/clipboard-pins.json"; blockLoading: true; printErrors: false; atomicWrites: true }
        Component.onCompleted: {
            try {
                pins = JSON.parse(pinFile.text() || "[]").filter(p => p && /^[a-z0-9]+$/.test(p.file) && typeof p.preview === "string")
                    .map(p => ({ file: p.file, id: String(p.id ?? ""), preview: p.preview }))
            } catch (e) { pins = [] }
        }
        Timer { running: win.wipeArmed; interval: 5000; onTriggered: win.wipeArmed = false }

        // The selected item's full content. A new process per selection, so a slow one can't overwrite a newer one.
        Instantiator {
            model: win.currentKey && win.tmp && !(win.current.pinned && win.current.kind === "image") && win.current.kind !== "color" ? [win.currentKey] : []
            delegate: Process {
                property var it: ({}) // taken once, so a later change to the list can't retarget this run
                Component.onCompleted: { it = win.current; running = true }
                readonly property string out: win.tmp + "/" + win.epoch + "-" + it.id + "." + it.fmt
                command: it.kind === "image" ? ["sh", "-c", '[ -s "$2" ] || cliphist decode "$1" > "$2"', "sh", it.id, out]
                    : it.pinned ? ["cat", "--", win.pinPath(it)] : ["cliphist", "decode", it.id]
                // shortcut: shows the first 100k characters only, since laying out megabytes of text stalls the shell.
                stdout: StdioCollector { onStreamFinished: if (it.kind !== "image") win.full = text.length > 100000 ? text.slice(0, 100000) + "…" : text }
                onExited: code => { if (it.kind === "image" && code === 0) win.shownImage = "file://" + out }
            }
        }

        MouseArea { anchors.fill: parent; enabled: Ui.clipboard; onClicked: Ui.clipboard = false }
        Frost {
            id: panel
            width: Math.min(1180, win.width - 48)
            height: Math.min(640, win.height - 48)
            anchors.horizontalCenter: parent.horizontalCenter
            y: Math.round((win.height - height) / 3)
            Keys.onEscapePressed: Ui.clipboard = false
            property bool shown: false
            Component.onCompleted: { shown = Qt.binding(() => Ui.clipboard); field.forceActiveFocus() }
            opacity: shown ? 1 : 0
            scale: shown ? 1 : 0.96
            transformOrigin: Item.Top
            Behavior on opacity { NumberAnimation { duration: 170 } }
            Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
            MouseArea { anchors.fill: parent } // keeps clicks from reaching the close area behind
            ColumnLayout {
                anchors.fill: parent; anchors.margins: 18; spacing: 12
                RowLayout {
                    Layout.fillWidth: true; spacing: 10
                    Fld {
                        id: field
                        Layout.fillWidth: true; implicitHeight: 40
                        placeholderText: Tr.t("Search the clipboard…")
                        Accessible.name: Tr.t("Search the clipboard…")
                        focus: true
                        onTextChanged: { win.sel = 0; list.positionViewAtBeginning() }
                        Keys.onEscapePressed: Ui.clipboard = false
                        Keys.onDownPressed: win.sel = Math.max(0, Math.min(win.sel + 1, win.rows.length - 1))
                        Keys.onUpPressed: win.sel = Math.max(win.sel - 1, 0)
                        Keys.onReturnPressed: win.copy(win.current)
                        Keys.onEnterPressed: win.copy(win.current)
                        // Delete still edits the search while there is text after the cursor.
                        Keys.onDeletePressed: event => {
                            if (cursorPosition < text.length) event.accepted = false
                            else win.remove(win.current)
                        }
                    }
                    Btn {
                        implicitHeight: 40
                        icon: "trash"; variant: "danger"
                        text: win.wipeArmed ? Tr.t("Click again to clear") : Tr.t("Clear history")
                        a11y: win.wipeArmed ? Tr.t("Click again within 5 s to confirm") : Tr.t("Clear history")
                        enabledB: !act.running && win.clips.length > 0
                        onClicked: win.wipe()
                    }
                }
                RowLayout {
                    Layout.fillWidth: true
                    Seg {
                        id: chips
                        readonly property var values: ["all", "text", "link", "image", "pinned"]
                        options: [Tr.t("All"), Tr.t("Text"), Tr.t("Links"), Tr.t("Images"), Tr.t("Pinned")]
                        current: values.indexOf(win.chip)
                        onPicked: i => { win.chip = values[i]; win.sel = 0 }
                    }
                    Item { Layout.fillWidth: true }
                    Tx { text: Tr.t("Items: %1").arg(win.rows.length); dim: true; size: 13 }
                }
                RowLayout {
                    Layout.fillWidth: true; Layout.fillHeight: true; spacing: 18
                    ListView {
                        id: list
                        Layout.preferredWidth: 520; Layout.fillHeight: true
                        clip: true; model: win.rows; spacing: 2
                        boundsBehavior: Flickable.StopAtBounds
                        Accessible.role: Accessible.List
                        Accessible.name: Tr.t("Clipboard history")
                        delegate: ColumnLayout {
                            id: row
                            required property var modelData
                            required property int index
                            readonly property bool first: index === 0 || !!win.rows[index - 1]?.pinned !== !!modelData.pinned
                            width: ListView.view.width; spacing: 2
                            Tx {
                                visible: row.first
                                Layout.topMargin: row.index ? 10 : 0; Layout.leftMargin: 12; Layout.bottomMargin: 2
                                text: row.modelData.pinned ? Tr.t("Pinned") : Tr.t("Recent")
                                size: 13; strong: true; dim: true; font.letterSpacing: 0.8; font.capitalization: Font.AllUppercase
                                Accessible.role: Accessible.Heading; Accessible.name: text
                            }
                            Rowi {
                                implicitHeight: 44
                                selected: row.index === win.sel
                                activeFocusOnTab: false
                                a11y: win.kindName(row.modelData) + ": " + win.label(row.modelData) + (row.modelData.pinned ? ", " + Tr.t("Pinned") : "")
                                onClicked: win.sel = row.index
                                Item {
                                    implicitWidth: 20; implicitHeight: 20
                                    Rectangle {
                                        visible: row.modelData.kind === "color"
                                        anchors.centerIn: parent; width: 18; height: 18; radius: 5
                                        color: row.modelData.color ?? "transparent"; border.width: 1; border.color: Theme.lineStrong
                                    }
                                    Ic {
                                        visible: row.modelData.kind !== "color"; anchors.centerIn: parent; color: Theme.muted
                                        name: ({ text: "note", link: "link", image: "image" })[row.modelData.kind] ?? "note"
                                    }
                                }
                                Tx { text: win.label(row.modelData); Layout.fillWidth: true }
                                Ic { visible: !!row.modelData.pinned; name: "pin"; size: 16; color: Theme.accent }
                            }
                        }
                        Tx {
                            anchors.centerIn: parent; visible: win.rows.length === 0; dim: true
                            text: win.clips.length || win.pins.length ? Tr.t("Nothing found.") : Tr.t("Nothing copied yet.")
                        }
                    }
                    Rectangle { Layout.fillHeight: true; implicitWidth: 1; color: Theme.line }
                    ColumnLayout {
                        Layout.fillWidth: true; Layout.fillHeight: true; spacing: 12
                        visible: !!win.current
                        Tx { text: win.current ? win.meta(win.current) : ""; dim: true; size: 13; Layout.fillWidth: true }
                        Rectangle {
                            Layout.fillWidth: true; Layout.fillHeight: true
                            radius: Theme.radiusSmall; color: Theme.field; border.width: 1; border.color: Theme.line
                            clip: true
                            Flickable {
                                id: flick
                                visible: win.current?.kind === "text" || win.current?.kind === "link"
                                anchors.fill: parent; anchors.margins: 14
                                contentWidth: width; contentHeight: fullText.implicitHeight
                                boundsBehavior: Flickable.StopAtBounds; clip: true
                                ScrollBar.vertical: ScrollBar { policy: flick.contentHeight > flick.height ? ScrollBar.AlwaysOn : ScrollBar.AlwaysOff; width: 6 }
                                Tx {
                                    id: fullText
                                    width: flick.width - 10
                                    text: win.full || win.current?.preview || ""
                                    wrapMode: Text.Wrap; elide: Text.ElideNone; verticalAlignment: Text.AlignTop
                                }
                            }
                            Image {
                                visible: win.current?.kind === "image"
                                anchors.fill: parent; anchors.margins: 14
                                source: visible ? win.shownImage : ""
                                fillMode: Image.PreserveAspectFit; asynchronous: true; cache: false
                                sourceSize { width: width; height: height }
                                Accessible.role: Accessible.Graphic
                                Accessible.name: win.current ? win.meta(win.current) : ""
                            }
                            Rectangle {
                                visible: win.current?.kind === "color"
                                anchors.centerIn: parent; width: 180; height: 180; radius: Theme.radius
                                color: win.current?.color ?? "transparent"; border.width: 1; border.color: Theme.lineStrong
                                Accessible.role: Accessible.Graphic
                                Accessible.name: win.current?.color ?? ""
                            }
                        }
                        RowLayout {
                            spacing: 10
                            Btn { text: Tr.t("Copy"); icon: "copy"; variant: "solid"; onClicked: win.copy(win.current) }
                            Btn {
                                readonly property bool pinned: !!win.current?.pinned
                                text: pinned ? Tr.t("Unpin") : Tr.t("Pin"); icon: pinned ? "pinOff" : "pin"
                                enabledB: !act.running
                                onClicked: pinned ? win.unpin(win.current) : win.pin(win.current)
                            }
                            Btn { text: Tr.t("Delete"); icon: "trash"; variant: "danger"; enabledB: !act.running; onClicked: win.remove(win.current) }
                        }
                    }
                }
            }
        }
    }
    }
}
