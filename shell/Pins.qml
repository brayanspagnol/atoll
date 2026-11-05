pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "parse.js" as P

// The apps pinned to the dock, stored in settings.json.
Singleton {
    id: pins
    readonly property var list: Cfg.v.dock
    readonly property string scripts: Quickshell.env("HOME") + "/.local/share/atoll/scripts/"

    function idsOf(entry) {
        const ids = [entry.id.toLowerCase()]
        if (entry.startupClass) ids.push(entry.startupClass.toLowerCase())
        return ids
    }
    function indexOf(entry) {
        const ids = idsOf(entry)
        return list.findIndex(p => p.desktopId === entry.id || (p.ids ?? []).some(i => ids.includes(i)))
    }
    function has(entry) { return indexOf(entry) >= 0 }
    function toggle(entry) {
        const i = indexOf(entry)
        if (i >= 0) remove(i)
        else add({ label: entry.name, appIcon: entry.icon, desktopId: entry.id, ids: idsOf(entry), cmd: "" })
    }
    function add(pin) { Cfg.v.dock = list.concat([pin]) }
    function remove(index) { Cfg.v.dock = list.filter((_, i) => i !== index) }
    function move(index, delta) {
        const to = index + delta
        if (to < 0 || to >= list.length) return
        const next = list.slice()
        next[index] = list[to]
        next[to] = list[index]
        Cfg.v.dock = next
    }
    function hasFile(path) { return list.some(p => p.path === path) }
    function addFile(path) {
        if (hasFile(path)) return
        if (path.toLowerCase().endsWith(".desktop")) {
            info.path = path
            info.command = [scripts + "desktop-info", path]
            info.running = true
            return
        }
        const name = path.split("/").pop().replace(/\.appimage$/i, "")
        add({ label: name, appIcon: "", path, ids: [name.toLowerCase()], cmd: P.shQuote(path) })
    }
    function launch(pin) {
        const entry = pin.desktopId ? DesktopEntries.byId(pin.desktopId) : null
        if (entry) entry.execute()
        else if (pin.cmd) Ui.sh(pin.cmd)
    }
    Process {
        id: info
        property string path: ""
        stdout: StdioCollector {
            onStreamFinished: {
                const [name, icon, exec] = text.split("\n")
                const base = info.path.split("/").pop().replace(/\.desktop$/i, "")
                if (exec) pins.add({ label: name || base, appIcon: icon ?? "", path: info.path, ids: [base.toLowerCase()], cmd: exec })
            }
        }
    }
}
