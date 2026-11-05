pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Local list: MPRIS has no "like", so this does not reach Spotify or YouTube Music.
Singleton {
    id: likes
    readonly property var items: adapter.items
    readonly property string dir: Quickshell.env("HOME") + "/.local/share/atoll/likes"
    function has(title, artist) { return adapter.items.some(i => i.title === title && i.artist === artist) }
    function toggle(title, artist, art) {
        if (!title) return
        if (has(title, artist)) {
            adapter.items = adapter.items.filter(i => !(i.title === title && i.artist === artist))
            return
        }
        // Browsers keep covers in temp files that vanish with the track, so copy it before listing.
        if (art.startsWith("file://")) {
            const kept = dir + "/" + Qt.md5(title + "|" + artist)
            copy.item = { title, artist, art: "file://" + kept }
            copy.fallback = art
            copy.command = ["sh", "-c", 'mkdir -p "$(dirname "$2")" && cp "$1" "$2"', "sh", art.slice(7), kept]
            copy.running = true
        } else add({ title, artist, art })
    }
    function add(item) { adapter.items = [item].concat(adapter.items) }
    Process {
        id: copy
        property var item: null
        property string fallback: ""
        onExited: code => { if (code !== 0) item.art = fallback; likes.add(item) }
    }
    FileView {
        path: Quickshell.env("HOME") + "/.local/share/atoll/likes.json"
        onAdapterUpdated: writeAdapter()
        onLoadFailed: err => { if (err === FileViewError.FileNotFound) writeAdapter() }
        JsonAdapter { id: adapter; property var items: [] }
    }
}
