import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import "shortcuts.js" as K
import "parse.js" as P

// Shortcut editor: an ABNT2 map per modifier layer. Defaults come from hypr/keys.lua, your changes go to
// ~/.config/atoll/shortcuts.lua and apply live through hyprctl eval; user.lua still loads last.
Page {
    id: pg
    title: Tr.t("Shortcuts")
    subtitle: Tr.t("Pick a key to see what it does. Changes apply right away.")
    readonly property string home: Quickshell.env("HOME")
    property var defaults: []
    property var changes: []
    property var live: null
    readonly property var entries: K.effective(defaults, changes, live)
    property int layerIndex: 0
    readonly property var mods: K.layers[layerIndex] // null: everything without Super
    property string query: ""
    property string sel: "" // keys of the picked key
    readonly property var selEntry: sel ? (K.conflicts(entries, sel, "")[0] ?? null) : null
    property var edit: null
    property bool recording: false
    property string armed: ""
    Timer { running: !!pg.armed; interval: 5000; onTriggered: pg.armed = "" }
    readonly property real u: Math.min(1.2, (bodyWidth - 34) / 866)

    readonly property var layerNames: ["Super", "Super + Shift", "Super + Alt", "Super + Ctrl", Tr.t("No Super")]
    readonly property var groupNames: ({ atoll: Tr.t("Atoll screens"), windows: Tr.t("Windows"), workspaces: Tr.t("Workspaces"), apps: Tr.t("Apps"), shots: Tr.t("Screenshots"), user: Tr.t("From user.lua") })
    // Group colors turn the accent's hue, so they follow the accent and the theme's lightness.
    function tint(i) { const a = Theme.accent; return Qt.hsla((Math.max(0, a.hslHue) + i / 5) % 1, Math.max(a.hslSaturation, 0.55), a.hslLightness, 1) }
    readonly property var groupColors: ({ atoll: Theme.accent, windows: tint(1), workspaces: tint(2), apps: tint(3), shots: tint(4), user: Theme.muted })
    function labelOf(e) {
        if (!e) return ""
        if (e.custom || e.state === "user") return e.label
        return e.arg ? Tr.t(e.label).arg(e.arg) : Tr.t(e.label)
    }
    function prettyOf(keys) { return keys ? K.pretty(keys).join(" + ") : Tr.t("Off") }
    function matches(e) {
        const q = query.trim().toLowerCase()
        return !q || (labelOf(e) + " " + prettyOf(e.keys) + " " + (groupNames[e.group] ?? "")).toLowerCase().includes(q)
    }
    // While the form is open, a key on the map becomes its combination.
    function pick(keys) {
        if (edit && !recording) edit = Object.assign({}, edit, { keys })
        sel = keys; armed = ""
        const i = K.layers.findIndex(l => K.inLayer(keys, l))
        if (i >= 0) layerIndex = i
    }

    FileView {
        path: pg.home + "/.config/atoll/hypr/keys.lua"
        printErrors: false
        onLoaded: pg.defaults = K.parseDefaults(text())
    }
    FileView {
        id: changesFile
        path: pg.home + "/.config/atoll/shortcuts.lua"
        atomicWrites: true
        printErrors: false
        watchChanges: true
        onFileChanged: reload()
        onLoaded: pg.changes = K.parseChanges(text())
        onLoadFailed: pg.changes = []
    }
    // What Hyprland has now, so binds from user.lua show up and are left alone.
    Process {
        id: liveList
        running: true
        command: ["hyprctl", "-j", "binds"]
        stdout: StdioCollector { onStreamFinished: pg.live = K.parseLive(text) }
    }
    Timer { id: refresh; interval: 400; onTriggered: { liveList.running = false; liveList.running = true } }
    function commit(next) {
        const code = K.liveCode(entries, K.effective(defaults, next, live))
        changesFile.setText(K.toLua(next))
        changes = next
        if (code) Quickshell.execDetached(["hyprctl", "eval", code])
        armed = ""
        refresh.restart()
    }

    // Recording: an empty Hyprland submap lets the keys reach this page instead of running their shortcuts.
    // Hyprland leaves it on its own after 8 s, so a crash here cannot leave shortcuts off.
    property var focusBefore: null
    function startRecording() {
        focusBefore = pg.Window.activeFocusItem
        recording = true
        Quickshell.execDetached(["hyprctl", "eval", K.recordCode])
        Quickshell.execDetached(["hyprctl", "dispatch", K.enterRecord])
        recordEnd.restart()
        recorder.forceActiveFocus()
    }
    function stopRecording() {
        if (!recording) return
        recording = false
        recordEnd.stop()
        Quickshell.execDetached(["hyprctl", "dispatch", K.leaveRecord])
        if (focusBefore) focusBefore.forceActiveFocus()
    }
    Timer { id: recordEnd; interval: 8000; onTriggered: pg.stopRecording() }
    Component.onDestruction: stopRecording()
    Item {
        id: recorder
        Keys.onPressed: event => {
            event.accepted = true
            if ([Qt.Key_Shift, Qt.Key_Control, Qt.Key_Alt, Qt.Key_Meta, Qt.Key_Super_L, Qt.Key_Super_R, Qt.Key_AltGr, Qt.Key_CapsLock, Qt.Key_Hyper_L, Qt.Key_Hyper_R].includes(event.key)) return
            const m = event.modifiers
            const mods = [[Qt.MetaModifier, "SUPER"], [Qt.ControlModifier, "CTRL"], [Qt.AltModifier, "ALT"], [Qt.ShiftModifier, "SHIFT"]].filter(([bit]) => m & bit).map(([, name]) => name)
            if (event.key === Qt.Key_Escape && !mods.length) { pg.stopRecording(); return }
            pg.edit = Object.assign({}, pg.edit, { keys: K.combo(mods, K.keyName(event.nativeScanCode)) })
            pg.stopRecording()
        }
    }

    // The form's state. kind: 0 app, 1 command, 2 Atoll screen; only new and custom shortcuts choose it.
    readonly property var apps: [...DesktopEntries.applications.values].filter(a => !a.noDisplay).sort((a, b) => a.name.localeCompare(b.name))
    function appCommand(a) { return a ? (a.runInTerminal ? "kitty -e " : "") + a.command.map(P.shQuote).join(" ") : "" }
    readonly property string screenPrefix: "qs -c atoll ipc call ui toggle "
    function startNew(keys) {
        stopRecording()
        edit = { id: K.newId(changes), isNew: true, custom: true, kind: 0, app: "", cmd: "", page: "", label: "", keys: keys || "" }
    }
    function startChange(e) {
        stopRecording()
        const page = e.custom && e.exec.startsWith(screenPrefix) ? e.exec.slice(screenPrefix.length) : ""
        edit = { id: e.id, isNew: false, custom: e.custom, kind: e.app ? 0 : page ? 2 : 1, app: e.app || "", cmd: e.exec || "", page, label: e.custom ? e.label : "", keys: e.keys }
    }
    readonly property var editApp: edit ? (apps.find(a => a.id === edit.app) ?? null) : null
    readonly property string editExec: !edit || !edit.custom ? "" : edit.kind === 0 ? appCommand(editApp) : edit.kind === 2 ? (edit.page ? screenPrefix + edit.page : "") : edit.cmd.trim()
    readonly property string editLabel: !edit || !edit.custom ? "" : edit.label.trim() || (edit.kind === 0 ? (editApp?.name ?? "") : edit.kind === 2 ? (Ui.pages.find(p => p.id === edit.page)?.full ?? "") : edit.cmd.trim())
    readonly property string editProblem: edit && edit.keys ? K.problem(edit.keys) : ""
    readonly property var editConflicts: edit && edit.keys && !editProblem ? K.conflicts(entries, edit.keys, edit.id) : []
    readonly property bool editBlocked: editConflicts.some(e => e.state === "user")
    readonly property bool canSave: !!edit && !!edit.keys && !editProblem && !editBlocked && !recording
        && (!edit.custom || (!!editExec && K.safeText(editExec) && K.safeText(editLabel)))
    function save() {
        const fields = edit.custom ? { label: editLabel, exec: editExec, group: edit.kind === 2 ? "atoll" : "apps" } : null
        if (fields && edit.kind === 0) fields.app = edit.app
        const keys = edit.keys
        commit(K.setKeys(defaults, changes, entries, edit.id, keys, fields))
        edit = null
        pick(keys)
    }
    // A default whose keys user.lua took back cannot be restored from here.
    function restoreBlocked(id) { return K.conflicts(entries, defaults.find(x => x.id === id)?.keys ?? "", id).some(e => e.state === "user") }
    function restore(id) {
        const d = defaults.find(x => x.id === id)
        const lost = K.conflicts(entries, d.keys, id)
        if (restoreBlocked(id)) return
        if (lost.length && armed !== id) { armed = id; return }
        commit(K.setKeys(defaults, changes, entries, id, d.keys, null))
    }

    component FBtn: Btn {
        color: variant === "solid" ? (pressed ? Qt.darker(Theme.accent, 1.15) : Theme.accent)
            : variant === "danger" ? (hovered ? Theme.danger : Qt.alpha(Theme.danger, 0.18))
            : pressed ? Theme.line : hovered ? Theme.lineStrong : Theme.raised
    }
    component Caption: Tx { size: 12; strong: true; dim: true; font.letterSpacing: 0.8; font.capitalization: Font.AllUppercase; Layout.fillWidth: true }
    // A combination drawn as keycaps.
    component Caps: Row {
        id: caps
        property string keys: ""
        property bool warn: false
        property int size: 15
        spacing: 6
        Accessible.role: Accessible.StaticText
        Accessible.name: pg.prettyOf(keys)
        Repeater {
            model: caps.keys ? K.pretty(caps.keys) : []
            Row {
                required property var modelData
                required property int index
                spacing: 6
                Tx { visible: index > 0; text: "+"; dim: true; strong: true; height: cap.height }
                Rectangle {
                    id: cap
                    width: Math.max(caps.size * 2.3, t.implicitWidth + caps.size * 1.4); height: caps.size * 2.3
                    radius: 8
                    color: caps.warn ? Qt.alpha(Theme.danger, 0.22) : Theme.raised
                    border.width: 1; border.color: caps.warn ? Theme.danger : Theme.lineStrong
                    Tx { id: t; anchors.centerIn: parent; text: modelData; mono: true; strong: true; size: caps.size }
                }
            }
        }
    }
    component Card: Rectangle {
        default property alias content: inner.data
        property bool hot: false
        Layout.fillWidth: true
        implicitHeight: inner.implicitHeight + 32
        radius: 20
        color: Theme.hover
        border.width: 1; border.color: hot ? Theme.accent : Theme.line
        ColumnLayout { id: inner; anchors.fill: parent; anchors.margins: 16; spacing: 12 }
    }
    component Swatch: Row {
        property string text: ""
        property color tone: Theme.accent
        property bool dashed: false
        spacing: 6
        Rectangle { visible: !parent.dashed; width: 10; height: 10; radius: 3; color: parent.tone; anchors.verticalCenter: parent.verticalCenter }
        Rectangle { visible: parent.dashed; width: 12; height: 10; radius: 3; color: "transparent"; border.width: 1; border.color: Theme.lineStrong; anchors.verticalCenter: parent.verticalCenter }
        Tx { text: parent.text; size: 13 }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 10
        Seg {
            options: pg.layerNames
            current: pg.layerIndex
            onPicked: i => { pg.layerIndex = i; pg.sel = "" }
            Accessible.name: Tr.t("Keys held")
        }
        Fld {
            Layout.fillWidth: true
            placeholderText: Tr.t("Search action or key")
            text: pg.query
            onTextEdited: pg.query = text
            Accessible.name: Tr.t("Search action or key")
        }
        FBtn {
            visible: pg.changes.length > 0
            icon: "undo"
            text: pg.armed === "all" ? Tr.t("Restore all?") : Tr.t("Restore defaults")
            variant: pg.armed === "all" ? "danger" : "ghost"
            onClicked: { if (pg.armed !== "all") pg.armed = "all"; else { pg.commit([]); pg.sel = "" } }
        }
    }

    Card {
        Layout.topMargin: 4
        RowLayout {
            Layout.fillWidth: true
            spacing: 16
            Caption { text: pg.mods ? pg.layerNames[pg.layerIndex] + " + …" : Tr.t("No Super"); Layout.fillWidth: false }
            Flow {
                Layout.fillWidth: true
                spacing: 12
                Repeater {
                    model: ["atoll", "windows", "workspaces", "apps", "shots"].concat(pg.entries.some(e => e.state === "user") ? ["user"] : [])
                    Swatch { required property string modelData; text: pg.groupNames[modelData]; tone: pg.groupColors[modelData] }
                }
                Swatch { text: Tr.t("Changed"); tone: Theme.ink }
                Swatch { text: Tr.t("Free"); dashed: true }
            }
        }
        Column {
            spacing: 4 * pg.u
            Repeater {
                model: K.rows
                Row {
                    required property var modelData
                    spacing: 4 * pg.u
                    Repeater {
                        model: parent.modelData
                        Rectangle {
                            id: kc
                            required property var modelData
                            readonly property string keys: modelData.name ? K.combo(pg.mods ?? [], modelData.name) : ""
                            readonly property var e: modelData.name ? K.onKey(pg.entries, pg.mods, modelData.code) : null
                            readonly property bool held: !!pg.mods && pg.mods.includes(modelData.holds)
                            readonly property bool usable: !!e || (!!keys && !!pg.mods)
                            readonly property bool picked: !!pg.sel && !!keys && K.norm(pg.sel) === K.norm(keys)
                            width: modelData.w * pg.u; height: 48 * pg.u
                            radius: 8
                            color: held ? Qt.alpha(Theme.accent, 0.3) : e ? Theme.raised : "transparent"
                            border.width: picked || activeFocus ? 2 : e || held ? 1 : 0
                            border.color: picked || activeFocus ? Theme.accent : Theme.lineStrong
                            opacity: pg.query && !(e && pg.matches(e)) ? 0.35 : 1
                            activeFocusOnTab: usable
                            Accessible.role: Accessible.Button
                            Accessible.name: keys ? pg.prettyOf(keys) + ": " + (e ? pg.labelOf(e) : Tr.t("Free")) : modelData.cap
                            Keys.onSpacePressed: if (usable) pg.pick(e ? e.keys : keys)
                            Keys.onReturnPressed: if (usable) pg.pick(e ? e.keys : keys)
                            Shape {
                                visible: !kc.e && !kc.held && kc.border.width === 0
                                anchors.fill: parent
                                ShapePath {
                                    strokeColor: Theme.line; strokeWidth: 1; fillColor: "transparent"
                                    strokeStyle: ShapePath.DashLine; dashPattern: [3, 3]
                                    PathRectangle { x: 0.5; y: 0.5; width: kc.width - 1; height: kc.height - 1; radius: 8 }
                                }
                            }
                            Rectangle { visible: !!kc.e; x: 3; y: 6; width: 4; height: parent.height - 12; radius: 2; color: kc.e ? pg.groupColors[kc.e.group] ?? Theme.muted : "transparent" }
                            Rectangle { visible: !!kc.e && (kc.e.state === "changed" || kc.e.custom); x: parent.width - 11; y: 5; width: 6; height: 6; radius: 3; color: Theme.ink }
                            Tx { x: 11; y: 4; text: kc.modelData.cap; mono: true; strong: !!kc.e; size: 12; dim: !kc.e && !kc.held }
                            Tx {
                                x: 11; width: parent.width - 14; anchors.bottom: parent.bottom; anchors.bottomMargin: 4
                                visible: !!kc.e; text: pg.labelOf(kc.e); size: 9; strong: true
                                wrapMode: Text.WordWrap; maximumLineCount: 2; lineHeight: 0.9
                            }
                            MouseArea { anchors.fill: parent; enabled: kc.usable; cursorShape: Qt.PointingHandCursor; onClicked: pg.pick(kc.e ? kc.e.keys : kc.keys) }
                        }
                    }
                }
            }
        }
        // Keys this layer uses that the map does not draw: Print, F keys, keys recorded by code.
        Flow {
            readonly property var others: K.offMap(pg.entries, pg.mods)
            visible: others.length > 0
            Layout.fillWidth: true
            spacing: 8
            Tx { text: Tr.t("Off the map:"); dim: true; size: 13; height: 32 }
            Repeater {
                model: parent.others
                FBtn { required property var modelData; implicitHeight: 32; text: pg.prettyOf(modelData.keys) + " · " + pg.labelOf(modelData); onClicked: pg.pick(modelData.keys) }
            }
        }
        Tx { text: Tr.t("Mouse buttons and media keys are not shown here. Change them in user.lua."); dim: true; size: 13; Layout.fillWidth: true; wrapMode: Text.WordWrap }
    }

    // Search finds shortcuts on every layer.
    Repeater {
        model: pg.query.trim() ? K.active(pg.entries).filter(e => pg.matches(e)).slice(0, 12) : []
        Rowi {
            id: hit
            required property var modelData
            a11y: pg.prettyOf(modelData.keys) + ": " + pg.labelOf(modelData)
            onClicked: pg.pick(modelData.keys)
            Rectangle { width: 4; height: 24; radius: 2; color: pg.groupColors[hit.modelData.group] ?? Theme.muted }
            Tx { text: pg.labelOf(hit.modelData); Layout.fillWidth: true }
            Caps { keys: hit.modelData.keys; size: 12 }
        }
    }
    Tx { visible: !!pg.query.trim() && !K.active(pg.entries).some(e => pg.matches(e)); text: Tr.t("No shortcut matches."); dim: true; Layout.fillWidth: true }

    // What the picked key does.
    Card {
        visible: !pg.edit
        RowLayout {
            visible: !pg.sel
            Layout.fillWidth: true
            Tx { text: Tr.t("Pick a key on the map to see what it does, or add your own."); dim: true; Layout.fillWidth: true; wrapMode: Text.WordWrap }
            FBtn { icon: "plus"; text: Tr.t("New shortcut"); variant: "solid"; onClicked: pg.startNew("") }
        }
        RowLayout {
            visible: !!pg.sel
            Layout.fillWidth: true
            spacing: 14
            Caps { keys: pg.sel }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                Tx { text: pg.selEntry ? pg.labelOf(pg.selEntry) : Tr.t("Free"); size: 18; strong: true; Layout.fillWidth: true }
                Tx {
                    Layout.fillWidth: true; wrapMode: Text.WordWrap; dim: true; size: 13
                    readonly property var e: pg.selEntry
                    text: !e ? Tr.t("Nothing uses this combination.")
                        : e.state === "user" ? Tr.t("Set in user.lua. Change it there.")
                        : [pg.groupNames[e.group]].concat(e.state === "changed" ? [Tr.t("Default: %1").arg(pg.prettyOf(e.def))] : e.custom ? [Tr.t("Added by you")] : []).join(" · ")
                }
            }
            FBtn { visible: !pg.selEntry; icon: "plus"; text: Tr.t("New shortcut"); variant: "solid"; onClicked: pg.startNew(pg.sel) }
            FBtn { visible: !!pg.selEntry && pg.selEntry.state !== "user"; icon: "keyboard"; text: Tr.t("Change"); onClicked: pg.startChange(pg.selEntry) }
            FBtn {
                visible: !!pg.selEntry && pg.selEntry.state === "changed"
                icon: "undo"
                text: pg.armed === pg.selEntry?.id ? Tr.t("Swap anyway") : Tr.t("Restore default")
                variant: pg.armed === pg.selEntry?.id ? "danger" : "ghost"
                enabledB: !!pg.selEntry && !pg.restoreBlocked(pg.selEntry.id)
                onClicked: pg.restore(pg.selEntry.id)
            }
            FBtn { visible: !!pg.selEntry && pg.selEntry.custom; icon: "trash"; a11y: Tr.t("Remove"); variant: "danger"; onClicked: { pg.commit(pg.changes.filter(c => c.id !== pg.selEntry.id)); pg.sel = "" } }
        }
    }

    // New shortcut, or new keys for one that exists.
    Card {
        visible: !!pg.edit
        hot: true
        RowLayout {
            Layout.fillWidth: true
            spacing: 10
            Ic { name: pg.edit?.isNew ? "plus" : "keyboard"; color: Theme.accent }
            Tx { text: pg.edit?.isNew ? Tr.t("New shortcut") : Tr.t("Change shortcut"); size: 18; strong: true; Layout.fillWidth: true }
            FBtn { text: Tr.t("Cancel"); onClicked: { pg.stopRecording(); pg.edit = null } }
            FBtn {
                text: pg.editConflicts.length && !pg.editBlocked ? Tr.t("Swap anyway") : Tr.t("Save")
                variant: pg.editConflicts.length && !pg.editBlocked ? "danger" : "solid"
                enabledB: pg.canSave
                onClicked: pg.save()
            }
        }
        GridLayout {
            Layout.fillWidth: true
            columns: pg.bodyWidth > 700 ? 2 : 1
            columnSpacing: 22; rowSpacing: 12
            ColumnLayout {
                Layout.fillWidth: true; Layout.preferredWidth: 1; Layout.alignment: Qt.AlignTop
                spacing: 8
                Caption { text: Tr.t("What it does") }
                Tx { visible: !!pg.edit && !pg.edit.custom; text: pg.labelOf(pg.entries.find(e => e.id === pg.edit?.id)); strong: true; Layout.fillWidth: true }
                Seg {
                    visible: !!pg.edit?.custom
                    Layout.fillWidth: true
                    options: [Tr.t("Open app"), Tr.t("Run command"), Tr.t("Atoll screen")]
                    current: pg.edit?.kind ?? 0
                    onPicked: i => pg.edit = Object.assign({}, pg.edit, { kind: i })
                }
                Caption { visible: !!pg.edit?.custom; text: [Tr.t("App"), Tr.t("Command"), Tr.t("Screen")][pg.edit?.kind ?? 0] }
                Cmb {
                    visible: !!pg.edit?.custom && pg.edit.kind === 0
                    Layout.fillWidth: true
                    a11y: Tr.t("App")
                    model: pg.apps
                    textRole: "name"
                    displayText: pg.editApp?.name ?? Tr.t("Choose an app")
                    currentIndex: pg.apps.indexOf(pg.editApp)
                    onActivated: i => pg.edit = Object.assign({}, pg.edit, { app: pg.apps[i].id })
                }
                Tx { visible: !!pg.edit?.custom && pg.edit.kind === 0 && !!pg.editExec; text: pg.editExec; mono: true; dim: true; size: 12; Layout.fillWidth: true }
                Fld {
                    visible: !!pg.edit?.custom && pg.edit.kind === 1
                    Layout.fillWidth: true
                    placeholderText: "notify-send hello"
                    text: pg.edit?.cmd ?? ""
                    onTextEdited: pg.edit = Object.assign({}, pg.edit, { cmd: text })
                    Accessible.name: Tr.t("Command")
                }
                Cmb {
                    visible: !!pg.edit?.custom && pg.edit.kind === 2
                    Layout.fillWidth: true
                    a11y: Tr.t("Screen")
                    model: Ui.pages
                    textRole: "full"
                    displayText: Ui.pages.find(p => p.id === pg.edit?.page)?.full ?? Tr.t("Choose a screen")
                    currentIndex: Ui.pages.findIndex(p => p.id === pg.edit?.page)
                    onActivated: i => pg.edit = Object.assign({}, pg.edit, { page: Ui.pages[i].id })
                }
                Caption { visible: !!pg.edit?.custom; text: Tr.t("Name in the list") }
                Fld {
                    visible: !!pg.edit?.custom
                    Layout.fillWidth: true
                    placeholderText: pg.editLabel
                    text: pg.edit?.label ?? ""
                    onTextEdited: pg.edit = Object.assign({}, pg.edit, { label: text })
                    Accessible.name: Tr.t("Name in the list")
                }
                Tx { visible: !!pg.edit?.custom && !!pg.editExec && !K.safeText(pg.editExec); text: Tr.t("Use one line, without control characters."); color: Theme.danger; size: 13; Layout.fillWidth: true }
            }
            ColumnLayout {
                Layout.fillWidth: true; Layout.preferredWidth: 1; Layout.alignment: Qt.AlignTop
                spacing: 8
                Caption { text: Tr.t("Combination") }
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10
                    Caps { visible: !pg.recording && !!pg.edit?.keys; keys: pg.edit?.keys ?? ""; warn: pg.editConflicts.length > 0 || !!pg.editProblem }
                    Tx {
                        visible: pg.recording || !pg.edit?.keys
                        text: pg.recording ? Tr.t("Press the new combination. Esc cancels.") : Tr.t("No keys yet.")
                        color: pg.recording ? Theme.accent : Theme.muted
                        strong: pg.recording
                        wrapMode: Text.WordWrap; Layout.fillWidth: true
                    }
                    Item { visible: !pg.recording && !!pg.edit?.keys; Layout.fillWidth: true }
                    FBtn {
                        icon: "record"
                        text: pg.recording ? Tr.t("Stop") : pg.edit?.keys ? Tr.t("Record again") : Tr.t("Record")
                        variant: pg.recording ? "solid" : "ghost"
                        onClicked: pg.recording ? pg.stopRecording() : pg.startRecording()
                    }
                }
                Tx { visible: pg.recording; text: Tr.t("Shortcuts are paused for up to 8 seconds while recording."); dim: true; size: 13; Layout.fillWidth: true; wrapMode: Text.WordWrap }
                Rectangle {
                    id: alert
                    readonly property string head: pg.editProblem === "typing" ? Tr.t("Hold Super, Ctrl or Alt with the key")
                        : pg.editProblem === "reserved" ? Tr.t("Super + Escape is kept for leaving the recording")
                        : pg.editProblem ? Tr.t("This key cannot be used")
                        : pg.editConflicts.length ? Tr.t("Already used by %1").arg(pg.labelOf(pg.editConflicts[0])) : ""
                    readonly property string body: pg.editProblem === "typing" ? Tr.t("Without one, the key would stop working in apps.")
                        : pg.editProblem ? ""
                        : pg.editBlocked ? Tr.t("It is set in user.lua. Change it there first.")
                        : pg.editConflicts.length ? Tr.t("%1. If you swap, it is left without a shortcut.").arg(pg.groupNames[pg.editConflicts[0].group] ?? "") : ""
                    visible: !!head && !pg.recording
                    Layout.fillWidth: true
                    implicitHeight: alertRow.implicitHeight + 20
                    radius: Theme.radiusSmall
                    color: Qt.alpha(Theme.danger, 0.16)
                    border.width: 1; border.color: Theme.danger
                    Accessible.role: Accessible.AlertMessage
                    Accessible.name: head + ". " + body
                    RowLayout {
                        id: alertRow
                        anchors.fill: parent; anchors.margins: 10; anchors.leftMargin: 14
                        spacing: 12
                        Ic { name: "alert"; color: Theme.danger }
                        ColumnLayout {
                            Layout.fillWidth: true; spacing: 2
                            Tx { text: alert.head; strong: true; Layout.fillWidth: true; wrapMode: Text.WordWrap }
                            Tx { visible: !!text; text: alert.body; size: 13; Layout.fillWidth: true; wrapMode: Text.WordWrap }
                        }
                    }
                }
                Caption {
                    readonly property var held: pg.edit?.keys && !pg.editProblem ? K.pretty(pg.edit.keys).slice(0, -1) : (pg.mods ? K.pretty(K.combo(pg.mods, "K")).slice(0, -1) : ["Super"])
                    text: Tr.t("Free with %1").arg(held.join(" + "))
                }
                Flow {
                    Layout.fillWidth: true
                    spacing: 8
                    readonly property var mods: pg.edit?.keys && !pg.editProblem ? pg.edit.keys.split(" + ").slice(0, -1) : (pg.mods ?? ["SUPER"])
                    Repeater {
                        model: K.free(pg.entries, parent.mods, 6)
                        Rectangle {
                            required property string modelData
                            width: 48; height: 40; radius: Theme.radiusSmall
                            color: fm.containsMouse ? Theme.lineStrong : Theme.raised
                            border.width: activeFocus ? 2 : 1; border.color: activeFocus ? Theme.accent : Theme.line
                            activeFocusOnTab: true
                            Accessible.role: Accessible.Button
                            Accessible.name: Tr.t("Use %1").arg(pg.prettyOf(modelData))
                            Keys.onSpacePressed: pg.edit = Object.assign({}, pg.edit, { keys: modelData })
                            Keys.onReturnPressed: pg.edit = Object.assign({}, pg.edit, { keys: modelData })
                            Tx { anchors.centerIn: parent; text: K.pretty(parent.modelData).slice(-1)[0]; mono: true; strong: true }
                            MouseArea { id: fm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: pg.edit = Object.assign({}, pg.edit, { keys: parent.modelData }) }
                        }
                    }
                }
            }
        }
    }

    // Everything you changed, with a way back.
    Sec { visible: pg.changes.length > 0; title: Tr.t("Your changes") }
    Repeater {
        model: pg.changes
        Rowi {
            id: row
            required property var modelData
            readonly property var e: pg.entries.find(x => x.id === modelData.id) ?? null
            readonly property bool isDefault: pg.defaults.some(d => d.id === modelData.id)
            a11y: pg.labelOf(e) + ": " + pg.prettyOf(modelData.keys)
            onClicked: if (modelData.keys) pg.pick(modelData.keys)
            Rectangle { width: 4; height: 24; radius: 2; color: row.e ? pg.groupColors[row.e.group] ?? Theme.muted : Theme.muted }
            ColumnLayout {
                Layout.fillWidth: true; spacing: 0
                Tx { text: row.e ? pg.labelOf(row.e) : (row.modelData.label || row.modelData.exec || row.modelData.id); Layout.fillWidth: true }
                Tx { visible: row.isDefault; text: Tr.t("Default: %1").arg(pg.prettyOf(pg.defaults.find(d => d.id === row.modelData.id)?.keys ?? "")); dim: true; size: 13; Layout.fillWidth: true }
            }
            Caps { visible: !!row.modelData.keys; keys: row.modelData.keys; size: 12 }
            Tx { visible: !row.modelData.keys; text: Tr.t("Off"); dim: true }
            FBtn {
                visible: row.isDefault
                icon: "undo"
                text: pg.armed === row.modelData.id ? Tr.t("Swap anyway") : Tr.t("Restore default")
                variant: pg.armed === row.modelData.id ? "danger" : "ghost"
                enabledB: !pg.restoreBlocked(row.modelData.id)
                onClicked: pg.restore(row.modelData.id)
            }
            FBtn { visible: !row.isDefault; icon: "trash"; a11y: Tr.t("Remove"); variant: "danger"; onClicked: pg.commit(pg.changes.filter(c => c.id !== row.modelData.id)) }
        }
    }
}
