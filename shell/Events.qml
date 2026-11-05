pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "cal.js" as Cal

Singleton {
    id: store
    readonly property var list: adapter.events
    property var _fired: ({})
    function save(ev) {
        const others = adapter.events.filter(e => e.id !== ev.id)
        if (!ev.id) ev.id = Date.now().toString(36)
        adapter.events = others.concat([ev])
    }
    function remove(id) { adapter.events = adapter.events.filter(e => e.id !== id) }
    FileView {
        path: Quickshell.env("HOME") + "/.local/share/atoll/events.json"
        onAdapterUpdated: writeAdapter()
        onLoadFailed: err => { if (err === FileViewError.FileNotFound) writeAdapter() }
        JsonAdapter { id: adapter; property var events: [] }
    }
    Timer { // reminders
        interval: 30000; running: true; repeat: true
        onTriggered: {
            const now = new Date(), day = Cal.key(now)
            for (const e of Cal.on(store.list, day)) {
                if (e.remind === undefined || e.remind < 0 || !e.start) continue
                const [h, m] = e.start.split(":").map(Number), at = new Date(now); at.setHours(h, m - e.remind, 0, 0)
                const id = e.id + day
                if (now >= at && now - at < 120000 && !store._fired[id]) {
                    store._fired[id] = true
                    Quickshell.execDetached(["notify-send", "-a", "Calendário", "-i", "x-office-calendar", e.title, e.start + (e.remind ? ` · em ${e.remind} min` : " · agora")])
                }
            }
        }
    }
}
