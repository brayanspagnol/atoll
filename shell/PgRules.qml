import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Widgets
import "rules.js" as R
import "displays.js" as D

// How an app's windows open. Saved to rules.json, written for Hyprland to rules.lua, and sent live with hyprctl eval.
Page {
    id: pg
    title: Tr.t("Window rules")
    subtitle: Tr.t("Choose how an app's windows open.")

    readonly property string dir: Quickshell.env("HOME") + "/.config/atoll/"
    property var rules: []
    property var draft: null // the rule on screen, unsaved
    property string origin: "" // the class the draft was loaded from, when it was a saved rule
    property var clients: []
    readonly property var openApps: R.openApps(clients)
    property int source: 0
    property string query: ""

    readonly property var effects: [
        { key: "float", icon: "winFloat", label: Tr.t("Float") },
        { key: "center", icon: "winCenter", label: Tr.t("Centered") },
        { key: "size", icon: "winSize", label: Tr.t("Fixed size") },
        { key: "pin", icon: "pin", label: Tr.t("Pin") },
        { key: "maximize", icon: "winMax", label: Tr.t("Maximized") },
        { key: "fullscreen", icon: "winFull", label: Tr.t("Full screen") },
        { key: "opacity", icon: "droplet", label: Tr.t("Transparent") },
        { key: "noFocus", icon: "noFocus", label: Tr.t("No focus") }
    ]
    function isOn(r, key) { return key === "size" ? !!r?.size : key === "opacity" ? (r?.opacity ?? null) !== null : !!r?.[key] }
    function hintOf(key) {
        const r = draft
        if (key === "size") return r?.size ? r.size[0] + " × " + r.size[1] + " px" : Tr.t("Off")
        if (key === "opacity") return r?.opacity ? Math.round(r.opacity * 100) + "%" : Tr.t("Off")
        return ({ float: Tr.t("Over the tiled windows"), center: Tr.t("In the middle of the screen"), pin: Tr.t("On every workspace, floating"),
            maximize: Tr.t("Fills the screen, keeps the bar"), fullscreen: Tr.t("Covers the whole screen"), noFocus: Tr.t("Opens without taking focus") })[key]
    }

    function entryOf(cls) { return cls ? DesktopEntries.heuristicLookup(cls) : null }
    function nameOf(cls) { return entryOf(cls)?.name || cls }
    function openSize(cls) { return openApps.find(o => o.class === cls)?.size ?? null }
    function pick(cls) {
        const saved = rules.find(r => r.class === cls)
        draft = saved ? R.normalize(saved) : R.blank(cls)
        origin = saved ? cls : ""
    }
    function set(change) { draft = Object.assign({}, draft, change) }
    // Pinned, centered and a fixed size only work on floating windows, so they bring floating with them.
    function toggle(key) {
        const on = !isOn(draft, key), c = {}
        if (key === "size") c.size = on ? (openSize(draft.class) ?? [800, 600]) : null
        else if (key === "opacity") c.opacity = on ? 0.9 : null
        else c[key] = on
        if (on && ["pin", "center", "size"].includes(key)) c.float = true
        if (!on && key === "float") Object.assign(c, { pin: false, center: false, size: null })
        if (on && key === "fullscreen") c.maximize = false
        if (on && key === "maximize") c.fullscreen = false
        set(c)
    }
    readonly property var clean: draft ? R.normalize(draft) : null
    readonly property bool canSave: !!clean && R.hasEffect(clean) && JSON.stringify(clean) !== JSON.stringify(rules.find(r => r.class === origin) ?? null)
    function save() {
        if (!canSave) return
        const r = clean
        if (origin && origin !== r.class) { rules = R.remove(rules, origin); run(R.removeCode(origin)) }
        rules = R.upsert(rules, r)
        write()
        run(R.liveCode(r))
        draft = r
        origin = r.class
    }
    function drop(cls) {
        rules = R.remove(rules, cls)
        write()
        run(R.removeCode(cls))
        if (origin === cls) { draft = null; origin = "" }
    }
    function write() { jsonFile.setText(R.jsonFile(rules)); luaFile.setText(R.configFile(rules)) }
    function run(code) { Quickshell.execDetached(["hyprctl", "eval", code]) }

    // Screens and workspaces, for the map of where the window opens.
    readonly property var screens: D.placed(Displays.monitors).filter(m => !m.parked)
    function workspacesOn(name) {
        const ids = new Set()
        for (const w of Hyprland.workspaces.values) if (w.id > 0 && w.monitor?.name === name) ids.add(w.id)
        for (const ws of Object.keys(Displays.workspaces)) if (Displays.workspaces[ws] === name) ids.add(Number(ws))
        return [...ids].sort((a, b) => a - b)
    }
    readonly property var shownWorkspaces: screens.reduce((all, m) => all.concat(workspacesOn(m.name)), [])
    function screenOfWorkspace(ws) { return Displays.workspaces[ws] ?? Hyprland.workspaces.values.find(w => String(w.id) === ws)?.monitor?.name ?? "" }
    readonly property string targetScreen: !draft ? "" : (draft.workspace ? screenOfWorkspace(draft.workspace) : draft.monitor) || (Hyprland.focusedMonitor?.name ?? "")
    function screenLabel(name) { const m = Displays.monitors.find(o => o.name === name); return m ? Displays.labelOf(m) : name }
    function placeOf(r) {
        if (r.workspace) {
            const on = screenOfWorkspace(r.workspace)
            return on ? Tr.t("Workspace %1 on %2").arg(r.workspace).arg(screenLabel(on)) : Tr.t("Workspace %1").arg(r.workspace)
        }
        return r.monitor ? screenLabel(r.monitor) : Tr.t("Where you are")
    }
    function summaryOf(r) { return [placeOf(r)].concat(effects.filter(e => isOn(r, e.key)).map(e => e.label)).join(" · ") }

    Component.onCompleted: {
        rules = R.parse(jsonFile.text())
        if (!Displays.dirty && !Displays.confirming) Displays.refresh()
    }
    FileView { id: jsonFile; path: pg.dir + "rules.json"; atomicWrites: true; blockLoading: true; printErrors: false }
    FileView { id: luaFile; path: pg.dir + "rules.lua"; atomicWrites: true; printErrors: false }
    Process {
        running: true
        command: ["hyprctl", "-j", "clients"]
        stdout: StdioCollector { onStreamFinished: { try { pg.clients = JSON.parse(text) } catch (e) { pg.clients = [] } } }
    }

    component AppIcon: Item {
        id: ai
        property string cls: ""
        property int size: 30
        readonly property var entry: pg.entryOf(cls)
        readonly property string path: entry?.icon ? Quickshell.iconPath(entry.icon, true) : ""
        implicitWidth: size; implicitHeight: size
        IconImage { anchors.fill: parent; visible: !!ai.path; source: ai.path; implicitSize: ai.size }
        Rectangle {
            anchors.fill: parent; visible: !ai.path
            radius: ai.size / 4; color: Theme.raised
            Tx { anchors.centerIn: parent; text: pg.nameOf(ai.cls).charAt(0).toUpperCase(); strong: true; size: ai.size / 2 }
        }
    }
    // A filled Btn: the plain ones are see-through, and get lost over light wallpapers.
    component Fill: Btn {
        color: variant === "solid" ? (pressed ? Qt.darker(Theme.accent, 1.15) : Theme.accent)
            : variant === "danger" ? (hovered ? Theme.danger : Qt.rgba(Theme.danger.r, Theme.danger.g, Theme.danger.b, 0.22))
            : pressed ? Theme.lineStrong : hovered ? Theme.line : Theme.raised
    }
    component Tile: Rectangle {
        id: tile
        required property var modelData
        readonly property var effect: modelData
        readonly property bool on: pg.isOn(pg.draft, effect.key)
        readonly property color fg: on ? Theme.accentInk : Theme.ink
        Layout.fillWidth: true; Layout.preferredWidth: 1
        implicitHeight: 104
        radius: 16
        color: on ? (tm.pressed ? Qt.darker(Theme.accent, 1.15) : Theme.accent) : tm.containsMouse ? Theme.line : Theme.raised
        border.width: activeFocus ? 2 : 0; border.color: Theme.ink
        activeFocusOnTab: true
        Accessible.role: Accessible.CheckBox
        Accessible.name: effect.label
        Accessible.description: pg.hintOf(effect.key)
        Accessible.checkable: true
        Accessible.checked: on
        Accessible.onToggleAction: pg.toggle(effect.key)
        Accessible.onPressAction: pg.toggle(effect.key)
        Keys.onSpacePressed: pg.toggle(effect.key)
        Keys.onReturnPressed: pg.toggle(effect.key)
        MouseArea { id: tm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: pg.toggle(tile.effect.key) }
        ColumnLayout {
            anchors.fill: parent; anchors.margins: 12
            spacing: 2
            RowLayout {
                Layout.fillWidth: true
                Ic { name: tile.effect.icon; size: 22; color: tile.fg }
                Item { Layout.fillWidth: true }
                Rectangle {
                    implicitWidth: 22; implicitHeight: 22; radius: 11
                    color: tile.on ? Theme.accentInk : Theme.field
                    border.width: tile.on ? 0 : 2; border.color: Theme.lineStrong
                    Ic { anchors.centerIn: parent; visible: tile.on; name: "check"; size: 14; color: Theme.accent }
                }
            }
            Item { Layout.fillHeight: true }
            Tx { text: tile.effect.label; strong: true; color: tile.fg; Layout.fillWidth: true }
            Tx { text: pg.hintOf(tile.effect.key); size: 12; color: tile.fg; Layout.fillWidth: true; wrapMode: Text.Wrap; maximumLineCount: 2 }
        }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 24

        // Saved rules, then the apps to add one for.
        ColumnLayout {
            Layout.preferredWidth: 270; Layout.maximumWidth: 270; Layout.alignment: Qt.AlignTop
            spacing: 6
            Sec { title: Tr.t("Your rules"); Layout.topMargin: 0 }
            Tx { visible: pg.rules.length === 0; text: Tr.t("No rules yet. Pick an app below."); dim: true; wrapMode: Text.Wrap; Layout.fillWidth: true }
            Repeater {
                model: pg.rules
                Rowi {
                    id: rr
                    required property var modelData
                    selected: pg.draft?.class === modelData.class
                    a11y: pg.nameOf(modelData.class) + ", " + pg.summaryOf(modelData)
                    onClicked: pg.pick(modelData.class)
                    AppIcon { cls: rr.modelData.class }
                    ColumnLayout {
                        Layout.fillWidth: true; spacing: 0
                        Tx { text: pg.nameOf(rr.modelData.class); strong: true; Layout.fillWidth: true }
                        Tx { text: pg.summaryOf(rr.modelData); dim: true; size: 12; Layout.fillWidth: true; wrapMode: Text.Wrap; maximumLineCount: 2 }
                    }
                    Fill {
                        icon: "trash"; variant: "danger"; implicitHeight: 34; implicitWidth: 34; iconSize: 17
                        a11y: Tr.t("Delete the rule for %1").arg(pg.nameOf(rr.modelData.class))
                        onClicked: pg.drop(rr.modelData.class)
                    }
                }
            }

            Sec { title: Tr.t("Add an app") }
            Seg {
                Layout.fillWidth: true
                options: [Tr.t("Open windows"), Tr.t("Installed")]
                current: pg.source
                onPicked: i => pg.source = i
            }
            Fld {
                Layout.fillWidth: true
                placeholderText: Tr.t("Search")
                Accessible.name: Tr.t("Search apps")
                onTextChanged: pg.query = text.trim().toLowerCase()
            }
            ListView {
                id: picker
                Layout.fillWidth: true
                implicitHeight: 320
                clip: true
                spacing: 2
                boundsBehavior: Flickable.StopAtBounds
                // Installed apps go by the class they say they open with, else by their desktop file name, as most Wayland apps do.
                model: (pg.source === 0
                    ? pg.openApps.map(o => ({ class: o.class, name: pg.nameOf(o.class), sub: o.class }))
                    : [...DesktopEntries.applications.values].filter(a => !a.noDisplay).map(a => ({ class: a.startupClass || a.id, name: a.name, sub: a.startupClass || a.id })))
                    .filter(a => !pg.query || (a.name + " " + a.class).toLowerCase().includes(pg.query))
                    .sort((a, b) => a.name.localeCompare(b.name))
                Tx {
                    anchors.top: parent.top; width: parent.width
                    visible: picker.count === 0
                    text: pg.source === 0 ? Tr.t("No open windows.") : Tr.t("No apps found.")
                    dim: true
                }
                delegate: Rowi {
                    id: ar
                    required property var modelData
                    width: ListView.view.width
                    implicitHeight: 48
                    selected: pg.draft?.class === modelData.class
                    a11y: Tr.t("Make a rule for %1").arg(modelData.name)
                    onClicked: pg.pick(modelData.class)
                    AppIcon { cls: ar.modelData.class; size: 26 }
                    ColumnLayout {
                        Layout.fillWidth: true; spacing: 0
                        Tx { text: ar.modelData.name; Layout.fillWidth: true }
                        Tx { text: ar.modelData.sub; visible: text !== ar.modelData.name; dim: true; mono: true; size: 11; Layout.fillWidth: true }
                    }
                    Ic { name: pg.rules.some(r => r.class === ar.modelData.class) ? "check" : "plus"; size: 18; color: Theme.muted }
                }
            }
        }

        Rectangle { Layout.fillHeight: true; implicitWidth: 1; color: Theme.line }

        // The rule for the chosen app.
        ColumnLayout {
            Layout.fillWidth: true; Layout.alignment: Qt.AlignTop
            spacing: 14
            Tx {
                visible: !pg.draft
                Layout.fillWidth: true; Layout.topMargin: 8
                text: Tr.t("Pick an app on the left to choose how its windows open.")
                dim: true; wrapMode: Text.Wrap
            }
            ColumnLayout {
                visible: !!pg.draft
                Layout.fillWidth: true
                spacing: 14
                RowLayout {
                    Layout.fillWidth: true; spacing: 14
                    AppIcon { cls: pg.draft?.class ?? ""; size: 52 }
                    ColumnLayout {
                        Layout.fillWidth: true; spacing: 0
                        Tx { text: pg.origin ? Tr.t("Rule") : Tr.t("New rule"); dim: true; size: 13; strong: true }
                        Tx { text: pg.nameOf(pg.draft?.class ?? ""); size: 26; strong: true; Layout.fillWidth: true; Accessible.role: Accessible.Heading; Accessible.name: text }
                    }
                }
                RowLayout {
                    Layout.fillWidth: true; spacing: 10
                    Tx { text: Tr.t("Window class"); dim: true; size: 13 }
                    Fld {
                        Layout.fillWidth: true
                        font.family: Theme.mono; font.pixelSize: 13
                        text: pg.draft?.class ?? ""
                        Accessible.name: Tr.t("Window class")
                        onTextEdited: pg.set({ class: text })
                    }
                }
                Tx {
                    visible: !!pg.draft && !pg.openApps.some(o => o.class === pg.draft.class)
                    text: Tr.t("No open window has this class. If the rule does nothing, open the app and pick it under Open windows.")
                    dim: true; size: 13; wrapMode: Text.Wrap; Layout.fillWidth: true
                }

                Tx { text: Tr.t("Whenever %1 opens, it should:").arg(pg.nameOf(pg.draft?.class ?? "")); size: 17; strong: true; Layout.fillWidth: true; wrapMode: Text.Wrap }
                GridLayout {
                    Layout.fillWidth: true; columns: 4; columnSpacing: 10; rowSpacing: 10
                    Repeater { model: pg.effects; Tile {} }
                }
                RowLayout {
                    visible: !!pg.draft?.size
                    Layout.fillWidth: true; spacing: 10
                    Tx { text: Tr.t("Size"); dim: true }
                    Repeater {
                        model: [0, 1]
                        RowLayout {
                            required property int index
                            spacing: 10
                            Tx { visible: index === 1; text: "×"; dim: true }
                            Fld {
                                implicitWidth: 86
                                font.family: Theme.mono
                                text: pg.draft?.size ? String(pg.draft.size[index]) : ""
                                validator: IntValidator { bottom: 50; top: 16384 }
                                Accessible.name: index === 0 ? Tr.t("Width in pixels") : Tr.t("Height in pixels")
                                onEditingFinished: { const s = pg.draft.size.slice(); s[index] = Number(text); pg.set({ size: s }) }
                            }
                        }
                    }
                    Tx { text: "px"; dim: true }
                    Item { Layout.fillWidth: true }
                    Fill {
                        text: Tr.t("Use the current size")
                        enabledB: !!pg.openSize(pg.draft?.class)
                        onClicked: pg.set({ size: pg.openSize(pg.draft.class) })
                    }
                }
                RowLayout {
                    visible: (pg.draft?.opacity ?? null) !== null
                    Layout.fillWidth: true; spacing: 10
                    Tx { text: Tr.t("Opacity"); dim: true }
                    Sld {
                        Layout.fillWidth: true
                        a11y: Tr.t("Opacity")
                        from: 0.3; to: 0.99; stepSize: 0.01
                        value: pg.draft?.opacity ?? 0.9
                        onMoved: pg.set({ opacity: Math.round(value * 100) / 100 })
                    }
                    Tx { text: Math.round((pg.draft?.opacity ?? 0) * 100) + "%"; mono: true; Layout.preferredWidth: 46; horizontalAlignment: Text.AlignRight }
                }

                // Where it opens: a workspace, a screen, or wherever the user is.
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: where.implicitHeight + 32
                    radius: 18
                    color: Theme.hover
                    border.width: 1; border.color: Theme.line
                    ColumnLayout {
                        id: where
                        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 16 }
                        spacing: 10
                        RowLayout {
                            Layout.fillWidth: true
                            Tx { text: Tr.t("Where to open"); size: 13; strong: true; dim: true; font.letterSpacing: 0.8; font.capitalization: Font.AllUppercase; Layout.fillWidth: true; Accessible.role: Accessible.Heading; Accessible.name: text }
                            Fill {
                                text: Tr.t("Where you are")
                                variant: !pg.draft?.workspace && !pg.draft?.monitor ? "solid" : "ghost"
                                onClicked: pg.set({ workspace: "", monitor: "" })
                            }
                        }
                        Item {
                            id: map
                            Layout.fillWidth: true
                            implicitHeight: 200
                            readonly property var fit: {
                                const list = pg.screens
                                if (!list.length) return { k: 1, ox: 0, oy: 0 }
                                const left = Math.min(...list.map(m => m.x)), top = Math.min(...list.map(m => m.y))
                                const right = Math.max(...list.map(m => m.x + D.sizeOf(m)[0])), bottom = Math.max(...list.map(m => m.y + D.sizeOf(m)[1]))
                                const k = Math.max(0, Math.min((width - 8) / (right - left), (height - 8) / (bottom - top)))
                                return { k, ox: (width - (right - left) * k) / 2 - left * k, oy: (height - (bottom - top) * k) / 2 - top * k }
                            }
                            Tx { anchors.centerIn: parent; visible: !pg.screens.length; text: Tr.t("No screens found."); dim: true }
                            Repeater {
                                model: pg.screens
                                Rectangle {
                                    id: scr
                                    required property var modelData
                                    readonly property bool target: modelData.name === pg.targetScreen
                                    readonly property var size: D.sizeOf(modelData)
                                    x: modelData.x * map.fit.k + map.fit.ox + 2
                                    y: modelData.y * map.fit.k + map.fit.oy + 2
                                    width: size[0] * map.fit.k - 4
                                    height: size[1] * map.fit.k - 4
                                    radius: 10
                                    color: Theme.field
                                    border.width: target || activeFocus ? 2 : 1
                                    border.color: activeFocus ? Theme.ink : target ? Theme.accent : Theme.lineStrong
                                    activeFocusOnTab: true
                                    Accessible.role: Accessible.Button
                                    Accessible.name: Tr.t("Screen %1").arg(Displays.labelOf(modelData))
                                    Accessible.onPressAction: pg.set({ monitor: modelData.name, workspace: "" })
                                    Keys.onSpacePressed: pg.set({ monitor: modelData.name, workspace: "" })
                                    Keys.onReturnPressed: pg.set({ monitor: modelData.name, workspace: "" })
                                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: pg.set({ monitor: scr.modelData.name, workspace: "" }) }
                                    // The window, roughly as it will open there.
                                    Rectangle {
                                        visible: scr.target
                                        readonly property var d: pg.draft ?? ({})
                                        readonly property real full: d.fullscreen ? 1 : d.maximize ? 0.92 : 0
                                        readonly property var px: d.size ? [d.size[0] * map.fit.k, d.size[1] * map.fit.k] : null
                                        width: full ? parent.width * full : px ? Math.min(px[0], parent.width - 8) : d.float ? parent.width * 0.45 : parent.width - 16
                                        height: full ? parent.height * full : px ? Math.min(px[1], parent.height - 8) : d.float ? parent.height * 0.5 : parent.height - 46
                                        anchors.centerIn: parent
                                        radius: 5
                                        color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.3)
                                        border.width: 2; border.color: Theme.accent
                                        opacity: d.opacity ?? 1
                                        Ic { visible: !!pg.draft?.pin; anchors { top: parent.top; right: parent.right; margins: 3 } name: "pin"; size: 12; color: Theme.accent }
                                    }
                                    Tx {
                                        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 8 }
                                        text: Displays.labelOf(scr.modelData) + "  " + scr.modelData.w + "×" + scr.modelData.h
                                        size: 12; strong: true
                                    }
                                    Flow {
                                        anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: 8 }
                                        spacing: 4
                                        Repeater {
                                            model: pg.workspacesOn(scr.modelData.name)
                                            Fill {
                                                required property int modelData
                                                text: String(modelData)
                                                implicitHeight: 28; implicitWidth: 30
                                                variant: pg.draft?.workspace === String(modelData) ? "solid" : "ghost"
                                                a11y: Tr.t("Workspace %1 on %2").arg(modelData).arg(Displays.labelOf(scr.modelData))
                                                onClicked: pg.set({ workspace: String(modelData), monitor: "" })
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        // Workspaces no screen holds yet open on the screen in use.
                        Flow {
                            Layout.fillWidth: true; spacing: 4
                            Tx { text: Tr.t("Other workspaces"); dim: true; size: 13; height: 28; rightPadding: 6 }
                            Repeater {
                                model: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10].filter(n => !pg.shownWorkspaces.includes(n))
                                Fill {
                                    required property int modelData
                                    text: String(modelData)
                                    implicitHeight: 28; implicitWidth: 30
                                    variant: pg.draft?.workspace === String(modelData) ? "solid" : "ghost"
                                    a11y: Tr.t("Workspace %1").arg(modelData)
                                    onClicked: pg.set({ workspace: String(modelData), monitor: "" })
                                }
                            }
                        }
                        Tx {
                            Layout.fillWidth: true; wrapMode: Text.Wrap
                            text: pg.draft ? (pg.draft.workspace || pg.draft.monitor ? Tr.t("Opens on: %1.").arg(pg.placeOf(pg.draft)) : Tr.t("Opens on the workspace you are using.")) : ""
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true; spacing: 10
                    Tx { text: Tr.t("Applies to windows opened from now on. Open windows are not changed."); dim: true; size: 13; wrapMode: Text.Wrap; Layout.fillWidth: true }
                    Fill { text: Tr.t("Cancel"); onClicked: { pg.draft = null; pg.origin = "" } }
                    Fill { text: Tr.t("Save rule"); icon: "check"; variant: "solid"; enabledB: pg.canSave; onClicked: pg.save() }
                }
            }
        }
    }
}
