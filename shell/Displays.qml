pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import "displays.js" as D

// The Monitor screen's state: `monitors` is the draft on screen, `applied` what Hyprland is using.
Singleton {
    id: root
    readonly property string dir: Quickshell.env("HOME") + "/.config/atoll/"
    property var monitors: []
    property var applied: []
    property string selected: ""
    property string lid: "off"
    property string savedLid: "off"
    property var workspaces: ({})
    property var savedWorkspaces: ({})
    property bool confirming: false
    property int count: 15
    property bool identifying: false
    property var _rollback: []

    readonly property bool hasLaptop: monitors.some(m => m.laptop)
    readonly property bool dirty: JSON.stringify(monitors) !== JSON.stringify(applied) || lid !== savedLid || JSON.stringify(workspaces) !== JSON.stringify(savedWorkspaces)
    readonly property var current: monitors.find(m => m.name === selected) ?? monitors[0] ?? null
    readonly property int count_on: monitors.filter(m => m.on).length

    function refresh() { reader.running = false; reader.running = true }
    function isLaptop(name) { return /^(eDP|LVDS|DSI)/.test(name) }
    function labelOf(m) {
        if (isLaptop(m.name)) return Tr.t("Laptop screen")
        return ((m.make ?? "").split(" ")[0] + " " + (m.model ?? "")).trim() || m.name
    }
    function patch(name, change, settle) {
        const next = monitors.map(m => m.name === name ? Object.assign({}, m, change) : m)
        monitors = settle === false ? next : D.settle(next, name)
    }
    function setOn(name, on) {
        patch(name, { on })
        if (!on && selected === name) selected = monitors.find(m => m.on)?.name ?? name
    }
    function preset(kind) {
        const laptop = monitors.find(m => m.laptop), others = monitors.filter(m => !m.laptop)
        let next = monitors.map(m => Object.assign({}, m, { on: true, mirror: "" }))
        if (kind === "external") next.forEach(m => m.on = !m.laptop)
        if (kind === "laptop") next.forEach(m => m.on = m.laptop)
        if (kind === "mirror") next.forEach((m, i) => m.mirror = i ? next[0].name : "")
        monitors = D.row(next)
        if (!current?.on) selected = monitors.find(m => m.on)?.name ?? ""
    }
    function assign(ws, name) { // a workspace belongs to one screen at most
        const next = Object.assign({}, workspaces)
        if (next[ws] === name) delete next[ws]
        else next[ws] = name
        workspaces = next
    }

    function revert() { monitors = D.clone(applied); lid = savedLid; workspaces = D.clone(savedWorkspaces) }
    function apply() {
        const next = D.normalize(monitors)
        const code = D.applyCode(applied, next)
        monitors = next
        // Only a layout change can leave a screen black, so only that needs the question.
        if (!code) return save()
        _rollback = D.clone(applied)
        run(code)
        count = 15
        confirming = true
    }
    function keep() { confirming = false; save() }
    function undo() {
        confirming = false
        run(D.applyCode(monitors, _rollback))
        monitors = D.clone(_rollback)
        applied = D.clone(_rollback)
        lid = savedLid
        workspaces = D.clone(savedWorkspaces)
        delayed.restart()
    }
    function save() {
        applied = D.clone(monitors)
        savedLid = lid
        const moves = Object.keys(workspaces).filter(w => workspaces[w] !== savedWorkspaces[w])
            .map(w => `hl.workspace_rule({ workspace = ${JSON.stringify(w)}, monitor = ${JSON.stringify(workspaces[w])} }); hl.dispatch(hl.dsp.workspace.move({ workspace = ${JSON.stringify(w)}, monitor = ${JSON.stringify(workspaces[w])} }))`)
        // shortcut: a removed workspace rule stays active until the next login, because Hyprland cannot drop one at runtime.
        savedWorkspaces = D.clone(workspaces)
        if (moves.length) run(moves.join("; "))
        luaFile.setText(D.configFile(monitors, lid, workspaces))
        jsonFile.setText(JSON.stringify({ lid, workspaces, monitors }, null, 1))
        delayed.restart()
    }
    function run(code) { Quickshell.execDetached(["hyprctl", "eval", code]) }
    function identify() { identifying = true; identifyEnd.restart() }

    function load(live) {
        const saved = (() => { try { return JSON.parse(jsonFile.text()) } catch (e) { return {} } })()
        const list = live.map(m => {
            const old = (saved.monitors ?? []).find(o => o.name === m.name)
            const modes = D.parseModes(m.availableModes)
            const rate = Number(m.refreshRate).toFixed(2)
            const lit = !m.disabled && m.width > 0
            // The mode in use always counts, even if the monitor doesn't advertise it.
            if (lit && !modes.some(o => o.res === m.width + "x" + m.height)) modes.unshift({ res: m.width + "x" + m.height, rates: [rate] })
            const mode = lit ? modes.find(o => o.res === m.width + "x" + m.height) : modes[0]
            if (lit && !mode.rates.includes(rate)) mode.rates.unshift(rate)
            const [w, h] = (mode ? mode.res : "0x0").split("x").map(Number)
            const mirrored = m.mirrorOf !== "none" ? live.find(o => String(o.id) === String(m.mirrorOf))?.name ?? "" : ""
            // A closed laptop is parked far away by hypr/monitors.lua; its real place is the saved one.
            const parked = m.y <= -1000
            return { name: m.name, make: m.make, model: m.model, laptop: isLaptop(m.name), modes, w, h,
                rate: lit ? rate : mode?.rates[0] ?? rate,
                x: parked ? old?.x ?? 1000000 : m.x, y: parked ? old?.y ?? 0 : m.y, scale: m.scale, rot: m.transform % 4,
                on: !m.disabled, mirror: mirrored, vrr: !!m.vrr, bit: (m.currentFormat ?? "").includes("2101010"), parked }
        }).filter(m => m.modes.length || !m.disabled).sort((a, b) => a.laptop - b.laptop || a.name.localeCompare(b.name))
        // A parked panel with no saved place goes next to the others.
        const unplaced = list.find(m => m.x === 1000000)
        const ready = unplaced ? D.settle(list, unplaced.name) : list
        monitors = ready
        applied = D.clone(ready)
        lid = savedLid = saved.lid ?? "off"
        workspaces = saved.workspaces ?? {}
        savedWorkspaces = D.clone(workspaces)
        if (!list.some(m => m.name === selected)) selected = list.find(m => m.on)?.name ?? ""
    }

    Process {
        id: reader
        command: ["hyprctl", "-j", "monitors", "all"]
        stdout: StdioCollector { onStreamFinished: if (text.trim()) root.load(JSON.parse(text)) }
    }
    FileView { id: luaFile; path: root.dir + "monitors.lua"; atomicWrites: true; printErrors: false }
    FileView { id: jsonFile; path: root.dir + "monitors.json"; atomicWrites: true; blockLoading: true; printErrors: false }
    Timer { id: delayed; interval: 1200; onTriggered: root.refresh() }
    Timer { id: identifyEnd; interval: 1800; onTriggered: root.identifying = false }
    Timer {
        interval: 1000; repeat: true; running: root.confirming
        onTriggered: { root.count -= 1; if (root.count <= 0) root.undo() }
    }
    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (/^monitor(added|removed)/.test(event.name) && !root.confirming && !root.dirty) delayed.restart()
        }
    }
}
