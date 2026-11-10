pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "pins.js" as Pins

Singleton {
    id: root
    property alias v: adapter
    // False until the first profile has loaded (or turned out missing): until then v holds only the defaults.
    property bool ready: false
    // What the island shows after the clock (pins.js), checked: the file can hold anything.
    readonly property var island: Pins.valid(adapter.island)
    FileView {
        id: file
        path: Profiles.path
        watchChanges: true
        onFileChanged: reload()
        onAdapterUpdated: if (!completing) writeAdapter()
        // The adapter keeps its old value for a key the file lacks, which would leak one profile into another.
        // So the first load of each profile gives those keys their defaults and writes back a complete file.
        property string completed: ""
        property string defaults: ""
        property bool completing: false
        function complete(saved) {
            completed = path.toString()
            completing = true
            const fresh = JSON.parse(defaults)
            for (const key in fresh) if (saved?.[key] === undefined) adapter[key] = fresh[key]
            if (saved && saved.island === undefined) adapter.island = Pins.migrate(saved)
            completing = false
            writeAdapter()
            root.ready = true
        }
        onLoaded: {
            if (completed === path.toString()) return
            let saved = null
            try { saved = JSON.parse(text()) } catch (e) {} // unreadable counts as empty
            complete(saved)
        }
        onLoadFailed: err => { if (err === FileViewError.FileNotFound) complete(null) }
        JsonAdapter {
            id: adapter
            // Files load in the background, so this always runs before the first one replaces a value.
            Component.onCompleted: file.defaults = JSON.stringify(adapter)
            property string accent: "gelo"
            property string theme: "dark" // "dark", "light", or "auto" (see Theme.qml)
            property string wallpaper: ""
            property var wallpapers: ({}) // per screen, by output name; the others use wallpaper
            property bool dnd: false
            property string name: Quickshell.env("USER")
            property string photo: "" // this profile's picture; empty uses ~/.face
            property string language: "auto" // a code from Tr.languages, or "auto" for the system language
            property string holidays: "auto" // a country code, "off", or "auto" for the system locale's country
            // Pinned apps. ids are lowercase Wayland app ids; icon is a key from Icons.qml.
            property var dock: [
                { label: "Terminal", icon: "term", ids: ["kitty"], cmd: "kitty" },
                { label: "Browser", icon: "globe", ids: ["firefox", "brave-browser", "chromium", "google-chrome"], cmd: "xdg-open https://" },
                { label: "Code", icon: "code", ids: ["code", "code-oss"], cmd: "code" },
                { label: "Files", icon: "folder", ids: ["org.gnome.nautilus", "thunar", "org.kde.dolphin"], cmd: "xdg-open ~" },
                { label: "Discord", icon: "chat", ids: ["discord", "vesktop"], cmd: "discord || vesktop" },
                { label: "Spotify", icon: "music", ids: ["spotify", "spotify-qt"], cmd: "spotify || spotify-qt" }
            ]
            property bool nightOn: false
            property int nightK: 4500
            property bool nightAuto: false
            property string nightFrom: "20:00"
            property string nightTo: "07:00"
            // Minutes; 0 = never.
            property int lockAc: 5
            property int dpmsAc: 6
            property int sleepAc: 0
            property int lockBat: 1
            property int dpmsBat: 2
            property int sleepBat: 3
            // Weather: { name, admin1, country, latitude, longitude } from the city search; auto finds it by IP instead.
            property var weatherPlace: null
            property bool weatherAuto: false
            property string weatherUnit: "c" // "c" or "f"
            // Focus mode. Minutes: 25, 50, 60, or 0 for until turned off. focusAllow: app names whose notifications still show.
            property int focusMinutes: 25
            property bool focusPomodoro: false
            property bool focusHide: true
            property var focusAllow: []
            // Lagu, the assistant: which AI command-line tool it drives, and whether file edits wait for a yes.
            property string aiProvider: "claude" // "claude", "cursor" or "codex"
            property bool aiAsk: true
            // The island's pinned items, in order: ids from pins.js. Read it through Cfg.island, which checks it.
            property var island: Pins.ids
        }
    }
}
